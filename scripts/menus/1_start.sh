#!/bin/sh

[ -n "$__IS_MODULE_1_START_LOADED" ] && return
__IS_MODULE_1_START_LOADED=1

. "$APPDIR/scripts/libs/start_wait.sh"

show_start_failure_details() {
    show_tail_file "$ET_CORE_RUN_LOG" "$MENU_START_FAIL_DETAIL" 20
}

start_service() {
    if ! "$APPDIR/start.sh" start; then
        msg_alert "\033[31m$MENU_SERVICE_START_FAIL\033[0m"
        show_start_failure_details
        return 1
    fi

    if start_wait; then
        msg_alert "\033[32m$MENU_SERVICE_START_OK\033[0m"
        return 0
    fi

    msg_alert "\033[31m$MENU_SERVICE_START_FAIL\033[0m"
    show_start_failure_details
    return 1
}

stop_service() {
    "$APPDIR/start.sh" stop
    sleep 1
    if "$APPDIR/start.sh" status-code >/dev/null 2>&1; then
        msg_alert "\033[31m$MENU_SERVICE_STOP_FAIL\033[0m"
        return 1
    fi
    msg_alert "\033[33m$MENU_SERVICE_STOP_OK\033[0m"
}

restart_service() {
    if ! "$APPDIR/start.sh" restart; then
        msg_alert "\033[31m$MENU_SERVICE_RESTART_FAIL\033[0m"
        show_start_failure_details
        return 1
    fi

    if start_wait; then
        msg_alert "\033[32m$MENU_SERVICE_RESTART_OK\033[0m"
        return 0
    fi

    msg_alert "\033[31m$MENU_SERVICE_RESTART_FAIL\033[0m"
    show_start_failure_details
    return 1
}
