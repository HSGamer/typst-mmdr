#!/usr/bin/env bash
set -e

# ===== Configuration =====
REPO_URL="https://github.com/1jehuang/mermaid-rs-renderer"
COMMIT_HASH="588fb9b01f08c5c77a24bfbf56394a0f2a18e4e7"
CLONE_DIR="mermaid-rs-renderer"
PATCHES_DIR="patches"

# ===== Functions =====

do_clone() {
    echo "Cloning $REPO_URL at commit $COMMIT_HASH..."
    rm -rf "$CLONE_DIR"
    git clone "$REPO_URL" "$CLONE_DIR"
    cd "$CLONE_DIR"
    git checkout "$COMMIT_HASH"
    cd ..
    echo "Done! Repository cloned into $CLONE_DIR at $COMMIT_HASH"
}

do_generate_patches() {
    if [ ! -d "$CLONE_DIR/.git" ]; then
        echo "Error: $CLONE_DIR is not a git repository. Run 'clone' first."
        exit 1
    fi

    mkdir -p "$PATCHES_DIR"
    # Remove old patches
    rm -f "$PATCHES_DIR"/*.patch

    cd "$CLONE_DIR"
    # Generate patches from all commits after the pinned commit
    PATCH_COUNT=$(git rev-list --count "$COMMIT_HASH"..HEAD)
    if [ "$PATCH_COUNT" -eq 0 ]; then
        echo "No commits to generate patches from."
        cd ..
        return
    fi
    git format-patch -o "../$PATCHES_DIR" "$COMMIT_HASH"..HEAD
    cd ..
    echo "Generated $PATCH_COUNT patch(es) in $PATCHES_DIR/"
    ls "$PATCHES_DIR"
}

do_apply_patches() {
    if [ ! -d "$CLONE_DIR/.git" ]; then
        echo "Error: $CLONE_DIR is not a git repository. Run 'clone' first."
        exit 1
    fi

    if [ ! -d "$PATCHES_DIR" ] || [ -z "$(ls -A "$PATCHES_DIR"/*.patch 2>/dev/null)" ]; then
        echo "No patches found in $PATCHES_DIR/"
        return
    fi

    cd "$CLONE_DIR"
    git am "../$PATCHES_DIR"/*.patch
    cd ..
    echo "All patches applied."
}

do_interactive_apply() {
    if [ ! -d "$CLONE_DIR/.git" ]; then
        echo "Error: $CLONE_DIR is not a git repository. Run 'clone' first."
        exit 1
    fi

    if [ ! -d "$PATCHES_DIR" ] || [ -z "$(ls -A "$PATCHES_DIR"/*.patch 2>/dev/null)" ]; then
        echo "No patches found in $PATCHES_DIR/"
        return
    fi

    PATCHES=("$PATCHES_DIR"/*.patch)
    TOTAL=${#PATCHES[@]}
    echo "Applying $TOTAL patch(es) interactively..."
    echo ""

    cd "$CLONE_DIR"
    for i in "${!PATCHES[@]}"; do
        PATCH="../${PATCHES[$i]}"
        PATCH_NAME=$(basename "${PATCHES[$i]}")
        echo "[$((i + 1))/$TOTAL] Applying $PATCH_NAME..."

        if git am "$PATCH" 2>/dev/null; then
            echo "  ✓ Applied successfully."
        else
            echo ""
            echo "  ✗ CONFLICT while applying $PATCH_NAME"
            echo "  Fix the conflicts in $CLONE_DIR/, then:"
            echo "    1. Stage your fixes:  cd $CLONE_DIR && git add -A"
            echo "    2. Press Enter here to continue"
            echo ""
            read -r -p "  Press Enter when conflicts are resolved (or 'skip' to skip, 'abort' to abort)... " ACTION
            case "$ACTION" in
                skip)
                    echo "  Skipping patch."
                    git am --skip
                    ;;
                abort)
                    echo "  Aborting."
                    git am --abort
                    cd ..
                    return 1
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
    do_generate_patches
    echo "Done! Clean patches saved in $PATCHES_DIR/"
}

do_rebuild_patches() {
    echo "Rebuilding: re-cloning at commit $COMMIT_HASH and reapplying patches..."
    do_clone
    do_interactive_apply
    echo "Rebuild complete."
}

# ===== Main =====

usage() {
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  clone              Clone the renderer repo at the pinned commit"
    echo "  generate-patches   Generate patches from local changes in the clone"
    echo "  apply-patches      Apply saved patches to the cloned repo"
    echo "  interactive-apply  Apply patches one by one, pause on conflicts, regenerate after"
    echo "  rebuild-patches    Re-clone and interactive-apply patches (use after updating COMMIT_HASH)"
    echo ""
    echo "Configuration (edit at the top of this script):"
    echo "  REPO_URL      = $REPO_URL"
    echo "  COMMIT_HASH   = $COMMIT_HASH"
    echo "  CLONE_DIR     = $CLONE_DIR"
    echo "  PATCHES_DIR   = $PATCHES_DIR"
}

case "${1:-}" in
    clone)
        do_clone
        ;;
    generate-patches)
        do_generate_patches
        ;;
    apply-patches)
        do_apply_patches
        ;;
    interactive-apply)
        do_interactive_apply
        ;;
    rebuild-patches)
        do_rebuild_patches
        ;;
    *)
        usage
        exit 1
        ;;
esac
