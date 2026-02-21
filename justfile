# ===== Configuration =====
repo_url   := "https://github.com/1jehuang/mermaid-rs-renderer"
commit     := "588fb9b01f08c5c77a24bfbf56394a0f2a18e4e7"
clone_dir  := "mermaid-rs-renderer"
patches    := "patches"
version    := `grep '^version' typst.toml | cut -d'"' -f2`
dist_dir   := "dist" / version

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
    echo "Applying $TOTAL patch(es) interactively..."
    echo ""
    cd "{{ clone_dir }}"
    for i in "${!PATCHES[@]}"; do
        PATCH="../${PATCHES[$i]}"
        PATCH_NAME=$(basename "${PATCHES[$i]}")
        echo "[$((i + 1))/$TOTAL] Applying $PATCH_NAME..."
        if git am "$PATCH" 2>/dev/null; then
            echo "  ✓ Applied successfully."
        else
            echo ""
            echo "  ✗ CONFLICT while applying $PATCH_NAME"
            echo "  Fix the conflicts in {{ clone_dir }}/, then:"
            echo "    1. Stage your fixes:  cd {{ clone_dir }} && git add -A"
            echo "    2. Press Enter here to continue"
            echo ""
            read -r -p "  Press Enter when resolved (or 'skip' to skip, 'abort' to abort)... " ACTION
            case "$ACTION" in
                skip)
                    echo "  Skipping patch."
                    git am --skip
                    ;;
                abort)
                    echo "  Aborting."
                    git am --abort
                    exit 1
                    ;;
                *)
                    git am --continue
                    echo "  ✓ Conflict resolved, patch applied."
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
    cargo build --release --target wasm32-unknown-unknown
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
