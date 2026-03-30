#!/usr/bin/env bash

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
REPO_NAME="$(basename "$REPO_ROOT")"
OUT_FILE="$REPO_ROOT/ShellEasytier.tar.gz"
TMP_FILE="${TMPDIR:-/tmp}/ShellEasytier.$$.tar.gz"

rm -f "$OUT_FILE"
rm -f "$TMP_FILE"

tar -czf "$TMP_FILE" \
    --exclude="$REPO_NAME/ShellEasytier.tar.gz" \
    --exclude="$REPO_NAME/pkg" \
    --exclude="$REPO_NAME/public" \
    --exclude="$REPO_NAME/bin" \
    --exclude="$REPO_NAME/.git" \
    --exclude="$REPO_NAME/dist" \
    -C "$(dirname "$REPO_ROOT")" \
    "$REPO_NAME"

mv -f "$TMP_FILE" "$OUT_FILE"

printf 'created %s\n' "$OUT_FILE"
