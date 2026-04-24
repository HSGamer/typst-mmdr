# ===== Configuration =====
repo_url      := "https://github.com/1jehuang/mermaid-rs-renderer"
commit        := "7db87acf21bfdfa34a45c80e179104e394f5feb1"
clone_dir     := "mermaid-rs-renderer"
patches       := "patches"
name          := `grep '^name' typst.toml | cut -d'"' -f2`
version       := `grep '^version' typst.toml | cut -d'"' -f2`
dist_dir      := "dist" / version
packages_fork := "git@github.com:HSGamer/typst-packages.git"
packages_dir  := "typst-packages"

# List available recipes
default:
    @just --list

# ===== Renderer Management =====

# Clone the renderer repo at the pinned commit
clone:
    rm -rf {{ clone_dir }}
    git clone {{ repo_url }} {{ clone_dir }}
    cd {{ clone_dir }} && git checkout {{ commit }}

# Generate patches from local commits in the clone
generate-patches:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -d "{{ clone_dir }}/.git" ]; then
        echo "Error: {{ clone_dir }} is not a git repository. Run 'just clone' first."
        exit 1
    fi
    mkdir -p "{{ patches }}"
    rm -f "{{ patches }}"/*.patch
    cd "{{ clone_dir }}"
    PATCH_COUNT=$(git rev-list --count "{{ commit }}"..HEAD)
    if [ "$PATCH_COUNT" -eq 0 ]; then
        echo "No commits to generate patches from."
        exit 0
    fi
    git format-patch -o "../{{ patches }}" "{{ commit }}"..HEAD
    cd ..
    echo "Generated $PATCH_COUNT patch(es) in {{ patches }}/"
    ls "{{ patches }}"

# Apply saved patches to the cloned repo
apply-patches:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -d "{{ clone_dir }}/.git" ]; then
        echo "Error: {{ clone_dir }} is not a git repository. Run 'just clone' first."
        exit 1
    fi
    if [ ! -d "{{ patches }}" ] || [ -z "$(ls -A "{{ patches }}"/*.patch 2>/dev/null)" ]; then
        echo "No patches found in {{ patches }}/"
        exit 0
    fi
    cd "{{ clone_dir }}"
    git am "../{{ patches }}"/*.patch
    echo "All patches applied."

# Apply patches one by one, pause on conflicts, regenerate after
interactive-apply:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -d "{{ clone_dir }}/.git" ]; then
        echo "Error: {{ clone_dir }} is not a git repository. Run 'just clone' first."
        exit 1
    fi
    if [ ! -d "{{ patches }}" ] || [ -z "$(ls -A "{{ patches }}"/*.patch 2>/dev/null)" ]; then
        echo "No patches found in {{ patches }}/"
        exit 0
    fi
    PATCHES=("{{ patches }}"/*.patch)
    TOTAL=${#PATCHES[@]}
    echo "Processing $TOTAL patch(es) interactively..."
    echo ""
    cd "{{ clone_dir }}"
    APPLY_ALL=0
    for i in "${!PATCHES[@]}"; do
        PATCH="../${PATCHES[$i]}"
        PATCH_NAME=$(basename "${PATCHES[$i]}")
        
        if [ "$APPLY_ALL" -eq 0 ]; then
            echo ""
            echo "[$((i + 1))/$TOTAL] Next patch: $PATCH_NAME"
            read -r -p "Options: [n]ext, [a]ll, [s]kip, [q]uit? " ACTION
            case "$ACTION" in
                a*) APPLY_ALL=1 ;;
                s*) echo "Skipping $PATCH_NAME."; continue ;;
                q*) echo "Quitting."; exit 0 ;;
                n*) ;;
                *) echo "Invalid option. Defaulting to 'next'." ;;
            esac
        fi

        echo "Applying $PATCH_NAME..."
        if git am "$PATCH" 2>/dev/null; then
            echo "  ✓ Applied successfully."
            if [ "$APPLY_ALL" -eq 0 ]; then
                read -r -p "  [a]mend with manual changes or [c]ontinue? " POST_ACTION
                if [[ "$POST_ACTION" == a* ]]; then
                    echo "  Make your changes in {{ clone_dir }}/"
                    echo "  Once finished, press Enter to review and amend."
                    read -r
                    echo "  Changes staged for amending:"
                    git add -A
                    git status --short
                    read -r -p "  Confirm amend? [y/N] " CONFIRM
                    if [[ "$CONFIRM" == y* ]]; then
                        git commit --amend --no-edit
                        echo "  ✓ Patch amended."
                    else
                        echo "  ! Amend cancelled (changes remain in working tree)."
                    fi
                fi
            fi
        else
            echo ""
            echo "  ✗ CONFLICT while applying $PATCH_NAME"
            echo "  Fix the conflicts in {{ clone_dir }}/"
            echo ""
            read -r -p "Options: [r]esolved, [s]kip, [a]bort? " ACTION
            case "$ACTION" in
                r*)
                    git add -A
                    git am --continue
                    echo "  ✓ Conflict resolved, patch applied."
                    ;;
                s*)
                    echo "  Skipping patch."
                    git am --skip
                    ;;
                a*)
                    echo "  Aborting."
                    git am --abort
                    exit 1
                    ;;
                *)
                    echo "  Invalid option. Defaulting to abort."
                    git am --abort
                    exit 1
                    ;;
            esac
        fi
    done
    cd ..
    echo ""
    echo "All patches applied. Regenerating clean patches..."
    just generate-patches
    echo "Done! Clean patches saved in {{ patches }}/"

# Re-clone and interactive-apply patches (use after updating commit hash)
rebuild-patches:
    just clone
    just interactive-apply

# ===== Build =====

# Build WASM, package into dist/
build:
    @echo "Building WASM..."
    RUSTFLAGS="-C target-feature=-reference-types" cargo build --release --target wasm32-unknown-unknown
    @echo "Optimizing WASM..."
    wasm-opt --enable-bulk-memory --enable-nontrapping-float-to-int --enable-sign-ext -Oz --strip-debug target/wasm32-unknown-unknown/release/typst_mmdr.wasm -o target/wasm32-unknown-unknown/release/typst_mmdr.wasm
    @mkdir -p {{ dist_dir }}
    @echo "Copying files to {{ dist_dir }}..."
    cp typst.toml {{ dist_dir }}/
    sed 's|target/wasm32-unknown-unknown/release/||g' lib.typ > {{ dist_dir }}/lib.typ
    cp target/wasm32-unknown-unknown/release/typst_mmdr.wasm {{ dist_dir }}/
    cp README.md {{ dist_dir }}/ 2>/dev/null || true
    cp LICENSE {{ dist_dir }}/ 2>/dev/null || true
    @echo "Done! Package is ready in {{ dist_dir }}"

# Build and check (dev mode, no release optimization)
check:
    cargo check --target wasm32-unknown-unknown

# ===== Setup =====

# Clone + apply patches + build (full setup from scratch)
setup:
    just clone
    just apply-patches
    just build

# ===== Publish =====

# Publish to typst/packages: sparse-clone fork, copy dist, commit and push
publish:
    #!/usr/bin/env bash
    set -euo pipefail
    BRANCH="packages/{{ name }}/{{ version }}"
    PKG_PATH="packages/preview/{{ name }}/{{ version }}"

    if [ ! -d "{{ dist_dir }}" ]; then
        echo "Error: {{ dist_dir }} does not exist. Run 'just build' first."
        exit 1
    fi

    echo "Cloning {{ packages_fork }} (sparse)..."
    rm -rf "{{ packages_dir }}"
    git clone --depth 1 --sparse --filter=blob:none "{{ packages_fork }}" "{{ packages_dir }}"

    cd "{{ packages_dir }}"
    # Delete remote branch if it exists from a previous attempt
    git push origin --delete "$BRANCH" 2>/dev/null || true
    git checkout -b "$BRANCH"
    git sparse-checkout set "$PKG_PATH"

    echo "Copying {{ dist_dir }} → $PKG_PATH..."
    mkdir -p "$PKG_PATH"
    cp -r "../{{ dist_dir }}/." "$PKG_PATH/"

    git add "$PKG_PATH"
    git commit -m "{{ name }}:{{ version }}"
    git push -u origin "$BRANCH"

    cd ..
    rm -rf "{{ packages_dir }}"
    echo "Done! Branch '$BRANCH' pushed to {{ packages_fork }}"
    echo "Open a PR at https://github.com/typst/packages to publish."

