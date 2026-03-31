#!/usr/bin/env bash

set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DIST_DIR="$ROOT/dist"

mkdir -p "$DIST_DIR"

generate_script() {
    template="$1"
    output="$2"
    placeholder="$3"
    value="$4"

    sed "s/${placeholder}/${value}/g" "$template" > "$output"
    chmod 755 "$output"
}

generate_script "$ROOT/install.template.sh" "$DIST_DIR/install.sh" '__INSTALL_LANG__' chs
generate_script "$ROOT/install.template.sh" "$DIST_DIR/install_en.sh" '__INSTALL_LANG__' en
generate_script "$ROOT/uninstall.template.sh" "$DIST_DIR/uninstall.sh" '__UNINSTALL_LANG__' chs
generate_script "$ROOT/uninstall.template.sh" "$DIST_DIR/uninstall_en.sh" '__UNINSTALL_LANG__' en
