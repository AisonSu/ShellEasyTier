#!/bin/sh

[ -z "$APPDIR" ] && APPDIR=$(
    cd "$(dirname "$0")/.."
    pwd
)
export APPDIR

. "$APPDIR/scripts/libs/get_config.sh"
. "$APPDIR/scripts/libs/set_config.sh"
. "$APPDIR/scripts/libs/set_profile.sh"
. "$APPDIR/scripts/libs/check_cmd.sh"
. "$APPDIR/scripts/libs/check_autostart.sh"
. "$APPDIR/scripts/libs/health_check.sh"
. "$APPDIR/scripts/libs/compatibility.sh"
. "$APPDIR/scripts/libs/logger.sh"

load_command_env() {
    [ -f "$APPDIR/configs/command.env" ] || return 1
    . "$APPDIR/configs/command.env"
}

run_command_string() {
    cmd_string="$1"
    [ -n "$cmd_string" ] || return 1
    eval "set -- $cmd_string" || return 1
    "$@"
}

exec_command_string() {
    cmd_string="$1"
    [ -n "$cmd_string" ] || return 1
    eval "set -- $cmd_string" || return 1
    exec "$@"
}

exec_core_command() {
    load_command_env || return 1
    exec_command_string "$COMMAND"
}

exec_web_command() {
    load_command_env || return 1
    [ -n "$WEB_COMMAND" ] || return 1
    exec_command_string "$WEB_COMMAND"
}

cleanup_profile_files() {
    for profile in /etc/profile /opt/etc/profile /jffs/configs/profile.add; do
        clear_profile "$profile"
    done
}

cleanup_startup_hooks() {
    disable_core_autostart
    disable_web_autostart
    cleanup_profile_files
    clear_command_shims

    for hook_file in "$initdir" /etc/storage/started_script.sh /jffs/.asusrouter /jffs/scripts/services-start /data/auto_start.sh; do
        [ -n "$hook_file" ] && sed -i '/ShellEasytier初始化脚本/d' "$hook_file" 2>/dev/null
    done

    rm -f /etc/init.d/shelleasytier /etc/init.d/shelleasytier-web
    rm -f /etc/systemd/system/shelleasytier.service /etc/systemd/system/shelleasytier-web.service
    rm -f /usr/lib/systemd/system/shelleasytier.service /usr/lib/systemd/system/shelleasytier-web.service
    rm -f /data/shelleasytier_init.sh

    uci delete firewall.ShellEasytier 2>/dev/null
    uci commit firewall 2>/dev/null

    ckcmd systemctl && systemctl daemon-reload >/dev/null 2>&1
}

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
        $_nohup setsid "$APPDIR/start.sh" core-run >> "$ET_CORE_RUN_LOG" 2>&1 &
    else
        $_nohup "$APPDIR/start.sh" core-run >> "$ET_CORE_RUN_LOG" 2>&1 &
    fi

    echo $! > "$ET_PIDFILE"
    afstart
}

run_web_command() {
    load_command_env || return 1
    [ -n "$WEB_COMMAND" ] || return 1

    mkdir -p "$TMPDIR" 2>/dev/null
    _nohup=''
    ckcmd nohup && _nohup='nohup'

    if ckcmd setsid; then
        $_nohup setsid "$APPDIR/start.sh" web-run >> "$ET_WEB_RUN_LOG" 2>&1 &
    else
        $_nohup "$APPDIR/start.sh" web-run >> "$ET_WEB_RUN_LOG" 2>&1 &
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
    compat-apply)
        load_config
        compat_apply_rules
        exit $?
        ;;
    compat-remove)
        compat_remove_rules
        compat_remove_firewall_hook
        exit 0
        ;;
    uninstall-cleanup)
        cleanup_startup_hooks
        compat_remove_rules >/dev/null 2>&1
        compat_remove_firewall_hook >/dev/null 2>&1
        exit 0
        ;;
    compat-status)
        load_config
        compat_status
        exit $?
        ;;
    daemon-run)
        bfstart || exit 1
        "$APPDIR/scripts/starts/afstart.sh" >/dev/null 2>&1 &
        exec_core_command
        ;;
    web-daemon-run)
        bfstart || exit 1
        exec_web_command
        ;;
    core-run)
        exec_core_command
        ;;
    web-run)
        exec_web_command
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
        load_command_env || exit 1
        run_command_string "$COMMAND"
        ;;
    *)
        "$1" "$2" "$3" "$4" "$5" "$6"
        ;;
esac
