[ -n "$__IS_LIB_HEALTH_CHECK" ] && return
__IS_LIB_HEALTH_CHECK=1

. "$APPDIR/scripts/libs/check_cmd.sh"

get_rpc_port() {
    case "$rpc_portal" in
        ''|0)
            return 1
            ;;
        *:*)
            port=${rpc_portal##*:}
            ;;
        *)
            port=$rpc_portal
            ;;
    esac

    [ -n "$port" ] || return 1
    [ "$port" = 0 ] && return 1
    printf '%s\n' "$port"
}

port_is_listening() {
    port="$1"
    [ -n "$port" ] || return 1

    if ckcmd ss; then
        ss -lnt 2>/dev/null | grep -qE "[\.:]${port}[[:space:]]"
        return $?
    fi

    if ckcmd netstat; then
        netstat -ntl 2>/dev/null | grep -qE "[\.:]${port}[[:space:]]"
        return $?
    fi

    return 1
}

cli_node_ready() {
    [ -x "$BINDIR/easytier-cli" ] || return 1
    [ -n "$rpc_cli_portal" ] || return 1

    mkdir -p "$TMPDIR" 2>/dev/null
    tmp_out="$TMPDIR/cli_ready.$$"

    "$BINDIR/easytier-cli" -p "$rpc_cli_portal" -o json node > "$tmp_out" 2>&1 &
    pid=$!
    i=1

    while kill -0 "$pid" 2>/dev/null && [ "$i" -le 3 ]; do
        sleep 1
        i=$((i + 1))
    done

    if kill -0 "$pid" 2>/dev/null; then
        kill -TERM "$pid" 2>/dev/null
        wait "$pid" 2>/dev/null
        rm -f "$tmp_out"
        return 1
    fi

    wait "$pid"
    rc=$?
    rm -f "$tmp_out"
    return "$rc"
}

service_is_ready() {
    pidof easytier-core >/dev/null 2>&1 || return 1

    port=$(get_rpc_port 2>/dev/null)
    [ -n "$port" ] || return 1
    port_is_listening "$port" || return 1

    cli_node_ready || return 1

    return 0
}

web_is_ready() {
    pidof easytier-web-embed >/dev/null 2>&1 || return 1

    [ -n "$web_console_api_port" ] || return 0
    [ "$web_console_api_port" = 0 ] && return 0

    port_is_listening "$web_console_api_port"
}
