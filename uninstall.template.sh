#!/bin/sh
# Generated from this template by build_installers.sh.

[ -z "$language" ] && language='__UNINSTALL_LANG__'

if [ "$language" = en ]; then
    MSG_NOT_FOUND='ShellEasytier installation not found.'
    MSG_CANCEL='Uninstall cancelled.'
    MSG_CONFIRM='Confirm uninstall? (1/0) > '
    MSG_FIND='Detecting ShellEasytier install directory...'
    MSG_FOUND='Detected install directory:'
    MSG_INPUT='Enter install directory manually (empty to cancel) > '
else
    MSG_NOT_FOUND='未找到 ShellEasytier 安装目录。'
    MSG_CANCEL='已取消卸载。'
    MSG_CONFIRM='确认卸载？(1/0) > '
    MSG_FIND='正在检测 ShellEasytier 安装目录...'
    MSG_FOUND='检测到安装目录：'
    MSG_INPUT='请输入安装目录（留空取消）> '
fi

detect_appdir() {
    for path in \
        /etc/ShellEasytier \
        /usr/share/ShellEasytier \
        "$HOME/.local/share/ShellEasytier" \
        /etc/storage/ShellEasytier \
        /jffs/ShellEasytier \
        /data/ShellEasytier \
        /userdisk/ShellEasytier \
        /data/other_vol/ShellEasytier
    do
        [ -f "$path/scripts/uninstall.sh" ] && {
            printf '%s\n' "$path"
            return 0
        }
    done

    for profile in /etc/profile /opt/etc/profile /jffs/configs/profile.add; do
        [ -f "$profile" ] || continue
        appdir=$(grep -oE 'export APPDIR="[^"]*ShellEasytier"' "$profile" 2>/dev/null | head -1 | cut -d'"' -f2)
        [ -n "$appdir" ] && [ -f "$appdir/scripts/uninstall.sh" ] && {
            printf '%s\n' "$appdir"
            return 0
        }
    done

    return 1
}

main() {
    echo "$MSG_FIND"

    if [ -z "$APPDIR" ]; then
        APPDIR=$(detect_appdir 2>/dev/null || true)
    fi

    if [ -z "$APPDIR" ]; then
        printf '%s' "$MSG_INPUT"
        read -r APPDIR
    fi

    [ -n "$APPDIR" ] || {
        echo "$MSG_CANCEL"
        exit 1
    }

    [ -f "$APPDIR/scripts/uninstall.sh" ] || {
        echo "$MSG_NOT_FOUND"
        exit 1
    }

    echo "$MSG_FOUND $APPDIR"
    printf '%s' "$MSG_CONFIRM"
    read -r res
    [ "$res" = 1 ] || {
        echo "$MSG_CANCEL"
        exit 1
    }

    export APPDIR language
    exec /bin/sh "$APPDIR/scripts/uninstall.sh"
}

main "$@"
