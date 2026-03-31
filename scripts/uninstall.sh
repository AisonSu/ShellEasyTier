#!/bin/sh

[ -z "$APPDIR" ] && APPDIR=$(
    cd "$(dirname "$0")/.."
    pwd
)
export APPDIR

. "$APPDIR/scripts/libs/get_config.sh"

if [ "$language" = en ]; then
    MSG_TITLE1='-----------------------------------------------'
    MSG_TITLE2='ShellEasytier will be fully removed.'
    MSG_TITLE3='This removes startup hooks, aliases, services, runtime cache, and the install directory.'
    MSG_CONFIRM='Confirm uninstall? (1/0) > '
    MSG_NOT_FOUND='Install directory not found.'
    MSG_CANCEL='Uninstall cancelled.'
    MSG_DONE='ShellEasytier has been removed.'
    MSG_HINT='If the current shell still keeps old aliases, reopen the session.'
else
    MSG_TITLE1='-----------------------------------------------'
    MSG_TITLE2='即将完整卸载 ShellEasytier。'
    MSG_TITLE3='将移除开机启动钩子、别名、服务、运行时缓存以及安装目录。'
    MSG_CONFIRM='确认卸载？(1/0) > '
    MSG_NOT_FOUND='安装目录不存在。'
    MSG_CANCEL='已取消卸载。'
    MSG_DONE='ShellEasytier 已卸载。'
    MSG_HINT='如果当前终端仍保留旧别名，请重新打开终端会话。'
fi

msg() {
    printf '%s\n' "$*"
}

confirm_uninstall() {
    msg "$MSG_TITLE1"
    msg "$MSG_TITLE2"
    msg "$MSG_TITLE3"
    msg "$MSG_TITLE1"
    printf '%s' "$MSG_CONFIRM"
    read -r res
    [ "$res" = 1 ]
}

remove_runtime_dirs() {
    if [ -n "$BINDIR" ]; then
        case "$BINDIR" in
            /|"$APPDIR"|"$APPDIR"/*) ;;
            *) rm -rf "$BINDIR" 2>/dev/null ;;
        esac
    fi

    [ -n "$TMPDIR" ] && [ "$TMPDIR" != / ] && rm -rf "$TMPDIR" 2>/dev/null
}

main() {
    [ -d "$APPDIR" ] || {
        msg "$MSG_NOT_FOUND"
        exit 1
    }

    confirm_uninstall || {
        msg "$MSG_CANCEL"
        exit 1
    }

    "$APPDIR/start.sh" web-stop >/dev/null 2>&1 || true
    "$APPDIR/start.sh" stop >/dev/null 2>&1 || true
    "$APPDIR/start.sh" uninstall-cleanup >/dev/null 2>&1 || true

    remove_runtime_dirs

    [ "$APPDIR" != / ] && rm -rf "$APPDIR"

    msg "$MSG_DONE"
    msg "$MSG_HINT"
}

main "$@"
