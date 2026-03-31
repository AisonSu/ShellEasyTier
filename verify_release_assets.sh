#!/usr/bin/env bash

set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
PKG_DIR="$ROOT/pkg"

ARCHES="x86_64 aarch64 arm armhf armv7 armv7hf mips mipsel"
WEB_ARCHES="x86_64 aarch64 arm armhf armv7 armv7hf"

require_file() {
    path="$1"
    [ -f "$path" ] || {
        printf 'ERROR: missing release asset source %s\n' "$path" >&2
        exit 1
    }
}

for arch in $ARCHES; do
    require_file "$PKG_DIR/$arch/easytier-core"
    require_file "$PKG_DIR/$arch/easytier-cli"
done

for arch in $WEB_ARCHES; do
    require_file "$PKG_DIR/$arch/easytier-web-embed"
done

printf 'release asset matrix verified\n'
