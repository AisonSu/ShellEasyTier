#!/bin/sh

APPDIR=/etc/ShellEasytier
export APPDIR

LOCKDIR=/tmp/ShellEasytier/snapshot_init.lock

acquire_lock() {
    mkdir -p /tmp/ShellEasytier 2>/dev/null
    mkdir "$LOCKDIR" 2>/dev/null || return 1
    trap 'rmdir "$LOCKDIR" 2>/dev/null' EXIT INT TERM
}

wait_config_ready() {
    i=0
    while [ ! -f "$APPDIR/configs/ShellEasytier.cfg" ]; do
        [ "$i" -gt 20 ] && return 1
        i=$((i + 1))
        sleep 3
    done
}

load_runtime_context() {
    . "$APPDIR/scripts/libs/get_config.sh"
    . "$APPDIR/scripts/libs/set_profile.sh"
}

wait_boot_ready() {
    i=0
    while [ "$i" -lt 12 ]; do
        ip -4 route show scope link 2>/dev/null | grep -Eq '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)' && return 0
        ip -4 route show scope link 2>/dev/null | grep -Eq ' dev (br-lan|br0|lan)( |$)' && return 0
        i=$((i + 1))
        sleep 5
    done
    return 0
}

restore_profile() {
    [ -w /etc/profile ] && set_profile /etc/profile
}

restore_services() {
    cp -f "$APPDIR/scripts/starts/shelleasytier.procd" /etc/init.d/shelleasytier || return 1
    cp -f "$APPDIR/scripts/starts/shelleasytier-web.procd" /etc/init.d/shelleasytier-web || return 1

    sed -i "s#/etc/ShellEasytier#$APPDIR#g" /etc/init.d/shelleasytier
    sed -i "s#/etc/ShellEasytier#$APPDIR#g" /etc/init.d/shelleasytier-web
    chmod 755 /etc/init.d/shelleasytier /etc/init.d/shelleasytier-web
}

schedule_compat_apply() {
    [ "$compat_enable" = ON ] || return 0
    [ -f "$APPDIR/.start_error" ] && return 0

    (
        sleep 5
        "$APPDIR/start.sh" compat-apply >/dev/null 2>&1
    ) &
}

sync_core_autostart() {
    if [ "$core_autostart" = ON ] && [ ! -f "$APPDIR/.dis_startup_core" ] && [ ! -f "$APPDIR/.start_error" ]; then
        /etc/init.d/shelleasytier enable >/dev/null 2>&1
        "$APPDIR/start.sh" status-code >/dev/null 2>&1 || /etc/init.d/shelleasytier start >/dev/null 2>&1
    else
        /etc/init.d/shelleasytier disable >/dev/null 2>&1
        /etc/init.d/shelleasytier stop >/dev/null 2>&1
    fi
}

sync_web_autostart() {
    if [ "$install_web" = ON ] && [ "$web_autostart" = ON ] && [ ! -f "$APPDIR/.dis_startup_web" ] && [ ! -f "$APPDIR/.start_error" ]; then
        /etc/init.d/shelleasytier-web enable >/dev/null 2>&1
        "$APPDIR/start.sh" web-status-code >/dev/null 2>&1 || /etc/init.d/shelleasytier-web start >/dev/null 2>&1
    else
        /etc/init.d/shelleasytier-web disable >/dev/null 2>&1
        /etc/init.d/shelleasytier-web stop >/dev/null 2>&1
    fi
}

init() {
    acquire_lock || exit 0
    wait_config_ready || exit 1
    load_runtime_context
    wait_boot_ready
    restore_profile
    restore_services || exit 1
    sync_core_autostart
    sync_web_autostart
    schedule_compat_apply
}

case "$1" in
    init)
        init
        ;;
    *)
        /bin/sh "$0" init >/dev/null 2>&1 &
        ;;
esac
