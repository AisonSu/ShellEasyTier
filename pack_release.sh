#!/usr/bin/env bash

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
REPO_NAME="$(basename "$REPO_ROOT")"
DIST_DIR="$REPO_ROOT/dist"
OUT_FILE="$DIST_DIR/ShellEasytier.tar.gz"
TMP_FILE="${TMPDIR:-/tmp}/ShellEasytier.$$.tar.gz"

mkdir -p "$DIST_DIR"
rm -f "$OUT_FILE"
rm -f "$TMP_FILE"

tar -czf "$TMP_FILE" \
    --exclude="$REPO_NAME/ShellEasytier.tar.gz" \
    --exclude="$REPO_NAME/pkg" \
    --exclude="$REPO_NAME/public" \
    --exclude="$REPO_NAME/bin" \
    --exclude="$REPO_NAME/.git" \
    --exclude="$REPO_NAME/dist" \
    --exclude="$REPO_NAME/AGENTS.md" \
    --exclude="$REPO_NAME/CURRENT-STATUS.md" \
    --exclude="$REPO_NAME/SELF.md" \
    --exclude="$REPO_NAME/SELF-DEV-AGENT.md" \
    --exclude="$REPO_NAME/install.template.sh" \
    --exclude="$REPO_NAME/uninstall.template.sh" \
    --exclude="$REPO_NAME/build_installers.sh" \
    -C "$(dirname "$REPO_ROOT")" \
    "$REPO_NAME"

mv -f "$TMP_FILE" "$OUT_FILE"

if command -v sha256sum >/dev/null 2>&1; then
    rm -f "$OUT_FILE.sha256"
    sha256sum "$OUT_FILE" > "$OUT_FILE.sha256"
    find "$DIST_DIR" -maxdepth 1 -type f ! -name '*.sha256' ! -name 'ShellEasytier.tar.gz' | while IFS= read -r asset; do
        sha256sum "$asset" > "$asset.sha256"
    done
fi

printf 'created %s\n' "$OUT_FILE"
