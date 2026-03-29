#!/bin/sh

[ -z "$APPDIR" ] && APPDIR=$(
    cd "$(dirname "$0")/.."
    pwd
)
export APPDIR

. "$APPDIR/scripts/libs/get_config.sh"
. "$APPDIR/scripts/libs/set_config.sh"
. "$APPDIR/scripts/libs/check_cmd.sh"
. "$APPDIR/scripts/libs/health_check.sh"
. "$APPDIR/scripts/libs/compatibility.sh"
. "$APPDIR/scripts/libs/logger.sh"

bfstart() {
    "$APPDIR/scripts/starts/bfstart.sh"
}

afstart() {
    "$APPDIR/scripts/starts/afstart.sh"
}

start_legacy() {
    bfstart || return 1

    mkdir -p "$TMPDIR" 2>/dev/null
    _nohup=''
    ckcmd nohup && _nohup='nohup'

    if ckcmd setsid; then
        $_nohup setsid sh -c '. "$1"; eval "exec $COMMAND"' sh "$APPDIR/configs/command.env" >> "$ET_CORE_RUN_LOG" 2>&1 &
    else
        $_nohup sh -c '. "$1"; eval "exec $COMMAND"' sh "$APPDIR/configs/command.env" >> "$ET_CORE_RUN_LOG" 2>&1 &
    fi

    echo $! > "$ET_PIDFILE"
    afstart
}

run_web_command() {
    . "$APPDIR/configs/command.env"
    [ -n "$WEB_COMMAND" ] || return 1

    mkdir -p "$TMPDIR" 2>/dev/null
    _nohup=''
    ckcmd nohup && _nohup='nohup'

    if ckcmd setsid; then
        $_nohup setsid sh -c '. "$1"; eval "exec $WEB_COMMAND"' sh "$APPDIR/configs/command.env" >> "$ET_WEB_RUN_LOG" 2>&1 &
    else
        $_nohup sh -c '. "$1"; eval "exec $WEB_COMMAND"' sh "$APPDIR/configs/command.env" >> "$ET_WEB_RUN_LOG" 2>&1 &
    fi

    echo $! > "$ET_WEB_PIDFILE"
}

case "$1" in
    start)
        pidof easytier-core >/dev/null 2>&1 && "$0" stop
        rm -f "$APPDIR/.start_error"
        start_legacy
        ;;
    stop)
        logger 'ShellEasytier 服务即将关闭......' 33
        compat_remove_rules >/dev/null 2>&1
        if [ -f "$ET_PIDFILE" ]; then
            kill -TERM "$(cat "$ET_PIDFILE")" 2>/dev/null
            rm -f "$ET_PIDFILE"
        elif [ "$USER" = root ] && ckcmd systemctl && grep -q 'systemd' /proc/1/comm 2>/dev/null; then
            systemctl stop shelleasytier.service >/dev/null 2>&1
        elif [ -f /etc/rc.common ] && grep -q 'procd' /proc/1/comm 2>/dev/null; then
            /etc/init.d/shelleasytier stop >/dev/null 2>&1
        elif rc-status -r >/dev/null 2>&1; then
            rc-service shelleasytier stop >/dev/null 2>&1
        fi
        killall easytier-core 2>/dev/null
        ;;
    restart)
        "$0" stop
        "$0" start
        ;;
    status)
        if service_is_ready; then
            logger 'ShellEasytier 正在运行。' 32
            exit 0
        fi
        logger 'ShellEasytier 未运行。' 31
        exit 1
        ;;
    status-code)
        service_is_ready
        exit $?
        ;;
    daemon-run)
        bfstart || exit 1
        . "$APPDIR/configs/command.env"
        eval "exec $COMMAND"
        ;;
    web-daemon-run)
        bfstart || exit 1
        . "$APPDIR/configs/command.env"
        [ -n "$WEB_COMMAND" ] || exit 1
        eval "exec $WEB_COMMAND"
        ;;
    web-start)
        bfstart || exit 1
        if run_web_command; then
            logger '本地 Web 控制台已启动。' 32
        else
            logger '当前架构未安装 web-embed 或本地 Web 未启用。' 31
            exit 1
        fi
        ;;
    web-stop)
        if [ -f "$ET_WEB_PIDFILE" ]; then
            kill -TERM "$(cat "$ET_WEB_PIDFILE")" 2>/dev/null
            rm -f "$ET_WEB_PIDFILE"
        fi
        killall easytier-web-embed 2>/dev/null
        ;;
    init)
        . "$APPDIR/scripts/starts/general_init.sh"
        ;;
    debug)
        bfstart || exit 1
        . "$APPDIR/configs/command.env"
        eval "$COMMAND"
        ;;
    *)
        "$1" "$2" "$3" "$4" "$5" "$6"
        ;;
esac
