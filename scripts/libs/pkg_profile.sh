[ -n "$__IS_LIB_PKG_PROFILE" ] && return
__IS_LIB_PKG_PROFILE=1

[ -n "$APPDIR" ] && . "$APPDIR/scripts/libs/check_arch.sh"

ET_CORE_MIN_KB=12288
ET_WEB_MIN_KB=32768
ET_FULL_MIN_KB=49152

get_runtime_need_kb() {
    if [ "$install_web" = ON ] && [ "$ET_HAS_WEB_EMBED" = 1 ]; then
        printf '%s\n' "$ET_WEB_MIN_KB"
    else
        printf '%s\n' "$ET_CORE_MIN_KB"
    fi
}

get_storage_check_path() {
    path="$1"
    if [ -d "$path" ]; then
        printf '%s\n' "$path"
    else
        dirname "$path"
    fi
}

arch_supports_web_embed() {
    case "$1" in
        x86_64|aarch64|arm|armhf|armv7|armv7hf)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

get_path_free_kb() {
    df -Pk "$1" 2>/dev/null | awk 'NR==2 {print $4}'
}

detect_pkg_support() {
    [ -n "$et_arch" ] || check_et_arch || return 1

    ET_PKGDIR="$APPDIR/pkg/$et_arch"
    ET_HAS_CORE=0
    ET_HAS_CLI=0
    ET_HAS_WEB_EMBED=0

    [ -n "$update_url" ] && ET_BIN_BASE_URL="$update_url" || ET_BIN_BASE_URL=""

    [ -n "$ET_BIN_BASE_URL" ] && ET_HAS_CORE=1
    [ -n "$ET_BIN_BASE_URL" ] && ET_HAS_CLI=1
    arch_supports_web_embed "$et_arch" && ET_HAS_WEB_EMBED=1

    export ET_PKGDIR ET_HAS_CORE ET_HAS_CLI ET_HAS_WEB_EMBED ET_BIN_BASE_URL
    [ "$ET_HAS_CORE" = 1 ] && [ "$ET_HAS_CLI" = 1 ]
}

choose_runtime_layout() {
    detect_pkg_support || return 1

    tmp_base="${TMPDIR:-/tmp/ShellEasytier}"
    need_kb=$(get_runtime_need_kb)
    crash_free=$(get_path_free_kb "$APPDIR")
    tmp_free=$(get_path_free_kb "${TMPDIR:-/tmp}")
    custom_base=""
    custom_free=""

    if [ -n "$binary_storage_path" ]; then
        custom_base="$binary_storage_path"
        custom_check=$(get_storage_check_path "$custom_base")
        custom_free=$(get_path_free_kb "$custom_check")
    fi

    ET_LAYOUT=""
    ET_BINDIR=""
    ET_ALLOW_WEB=0

    case "$binary_storage_mode" in
        persistent)
            if [ -n "$crash_free" ] && [ "$crash_free" -ge "$need_kb" ]; then
                ET_LAYOUT="persistent-manual"
                ET_BINDIR="$APPDIR/bin/$et_arch"
            else
                return 1
            fi
            ;;
        tmp)
            if [ -n "$tmp_free" ] && [ "$tmp_free" -ge "$need_kb" ]; then
                ET_LAYOUT="tmp-manual"
                ET_BINDIR="$tmp_base/bin/$et_arch"
            else
                return 1
            fi
            ;;
        custom)
            [ -n "$custom_base" ] || return 1
            if [ -n "$custom_free" ] && [ "$custom_free" -ge "$need_kb" ]; then
                ET_LAYOUT="custom-manual"
                ET_BINDIR="$custom_base/$et_arch"
            else
                return 1
            fi
            ;;
        *)
            if [ -n "$crash_free" ] && [ "$crash_free" -ge "$need_kb" ]; then
                ET_LAYOUT="persistent-auto"
                ET_BINDIR="$APPDIR/bin/$et_arch"
            elif [ -n "$tmp_free" ] && [ "$tmp_free" -ge "$need_kb" ]; then
                ET_LAYOUT="tmp-auto"
                ET_BINDIR="$tmp_base/bin/$et_arch"
            else
                return 1
            fi
            ;;
    esac

    if [ "$install_web" = ON ] && [ "$ET_HAS_WEB_EMBED" = 1 ]; then
        ET_ALLOW_WEB=1
    fi

    export ET_LAYOUT ET_BINDIR ET_ALLOW_WEB
    return 0
}

can_offer_local_web_menu() {
    [ "$install_web" = ON ] || return 1

    choose_runtime_layout || return 1

    [ "$ET_ALLOW_WEB" = 1 ] || return 1

    [ "$ET_HAS_WEB_EMBED" = 1 ]
}
