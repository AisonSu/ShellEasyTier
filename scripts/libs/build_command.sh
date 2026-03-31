[ -n "$__IS_LIB_BUILD_COMMAND" ] && return
__IS_LIB_BUILD_COMMAND=1

. "$APPDIR/scripts/libs/set_config.sh"

core_supports_flag() {
    [ -x "$BINDIR/easytier-core" ] || return 1
    "$BINDIR/easytier-core" --help 2>&1 | grep -q -- "$1"
}

shell_quote_single() {
    printf "'"
    printf '%s' "$1" | sed "s/'/'\\''/g"
    printf "'"
}

append_literal_arg() {
    [ $# -gt 0 ] || return 0
    cmd="$cmd $(shell_quote_single "$1")"
}

append_flag_from_list() {
    flag="$1"
    file="$2"
    [ -f "$file" ] || return 0
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        case "$line" in
            \#*) continue ;;
        esac
        append_literal_arg "$flag"
        append_literal_arg "$line"
    done < "$file"
}

append_switch_flag() {
    value="$1"
    flag="$2"
    [ "$value" = ON ] || [ "$value" = 1 ] || [ "$value" = true ] || [ "$value" = TRUE ] || return 0
    append_literal_arg "$flag"
    append_literal_arg true
}

append_value_flag() {
    value="$1"
    flag="$2"
    [ -n "$value" ] || return 0
    append_literal_arg "$flag"
    append_literal_arg "$value"
}

resolve_config_server_value() {
    if [ -n "$config_server" ] && [ -n "$config_server_user" ]; then
        case "$config_server" in
            *://*/*)
                printf '%s\n' "$config_server"
                ;;
            *://*)
                printf '%s/%s\n' "$config_server" "$config_server_user"
                ;;
            *)
                printf '%s\n' "$config_server"
                ;;
        esac
    elif [ -n "$config_server" ]; then
        printf '%s\n' "$config_server"
    else
        printf '%s\n' "$config_server_user"
    fi
}

build_local_command() {
    cmd=''
    append_literal_arg "$BINDIR/easytier-core"
    append_literal_arg -c
    append_literal_arg "$TMPDIR/easytier.toml"
    if [ "$acl_enable" = ON ] && [ -s "$acl_config_path" ]; then
        append_literal_arg -c
        append_literal_arg "$acl_config_path"
    fi
    append_value_flag "$rpc_portal" '-r'
    append_value_flag "$rpc_portal_whitelist" '--rpc-portal-whitelist'
    append_value_flag "$hostname" '--hostname'
    append_value_flag "$machine_id" '--machine-id'
    append_value_flag "$config_dir" '--config-dir'
    append_switch_flag "$disable_env_parsing" '--disable-env-parsing'
    append_value_flag "$console_log_level" '--console-log-level'
    append_value_flag "$file_log_level" '--file-log-level'
    append_value_flag "$file_log_dir" '--file-log-dir'
    append_value_flag "$file_log_size" '--file-log-size'
    append_value_flag "$file_log_count" '--file-log-count'
    append_value_flag "$compression" '--compression'
    append_switch_flag "$bind_device" '--bind-device'
    append_value_flag "$socks5_port" '--socks5'
    append_value_flag "$vpn_portal" '--vpn-portal'
    append_value_flag "$quic_listen_port" '--quic-listen-port'
    append_value_flag "$encryption_algorithm" '--encryption-algorithm'
    append_value_flag "$tcp_whitelist" '--tcp-whitelist'
    append_value_flag "$udp_whitelist" '--udp-whitelist'
    append_flag_from_list '-e' "$APPDIR/configs/external_nodes.list"
    append_flag_from_list '--port-forward' "$APPDIR/configs/port_forward.list"
    append_flag_from_list '--manual-routes' "$APPDIR/configs/manual_routes.list"
    append_flag_from_list '--relay-network-whitelist' "$APPDIR/configs/relay_network_whitelist.list"
    append_flag_from_list '--stun-servers' "$APPDIR/configs/stun_servers.list"
    append_flag_from_list '--stun-servers-v6' "$APPDIR/configs/stun_servers_v6.list"
    append_switch_flag "$accept_dns" '--accept-dns'
    if { [ "$accept_dns" = ON ] || [ "$accept_dns" = 1 ] || [ "$accept_dns" = true ] || [ "$accept_dns" = TRUE ]; } && core_supports_flag '--tld-dns-zone'; then
        append_value_flag "$tld_dns_zone" '--tld-dns-zone'
    fi
    append_switch_flag "$private_mode" '--private-mode'
    append_switch_flag "$proxy_forward_by_system" '--proxy-forward-by-system'
    append_switch_flag "$multi_thread" '--multi-thread'
    append_switch_flag "$p2p_only" '--p2p-only'
    append_switch_flag "$no_listener" '--no-listener'
    append_switch_flag "$enable_kcp_proxy" '--enable-kcp-proxy'
    append_switch_flag "$disable_kcp_input" '--disable-kcp-input'
    append_switch_flag "$enable_quic_proxy" '--enable-quic-proxy'
    append_switch_flag "$disable_quic_input" '--disable-quic-input'
    append_switch_flag "$disable_tcp_hole_punching" '--disable-tcp-hole-punching'
    append_switch_flag "$disable_relay_kcp" '--disable-relay-kcp'
    append_switch_flag "$enable_relay_foreign_network_kcp" '--enable-relay-foreign-network-kcp'
    append_value_flag "$foreign_relay_bps_limit" '--foreign-relay-bps-limit'
    append_value_flag "$multi_thread_count" '--multi-thread-count'
    printf '%s\n' "$cmd"
}

build_remote_command() {
    config_server_value=$(resolve_config_server_value)
    cmd=''
    append_literal_arg "$BINDIR/easytier-core"
    append_value_flag "$config_server_value" '--config-server'
    append_value_flag "$config_dir" '--config-dir'
    append_switch_flag "$disable_env_parsing" '--disable-env-parsing'
    append_value_flag "$machine_id" '--machine-id'
    append_value_flag "$hostname" '--hostname'
    append_value_flag "$rpc_portal" '-r'
    append_value_flag "$rpc_portal_whitelist" '--rpc-portal-whitelist'
    append_value_flag "$console_log_level" '--console-log-level'
    append_value_flag "$file_log_level" '--file-log-level'
    append_value_flag "$file_log_dir" '--file-log-dir'
    append_value_flag "$file_log_size" '--file-log-size'
    append_value_flag "$file_log_count" '--file-log-count'
    printf '%s\n' "$cmd"
}

build_web_command() {
    if [ -x "$BINDIR/easytier-web-embed" ]; then
        cmd=''
        append_literal_arg "$BINDIR/easytier-web-embed"
        append_literal_arg --api-server-port
        append_literal_arg "$web_console_api_port"
        append_literal_arg --api-host
        append_literal_arg "http://127.0.0.1:$web_console_api_port"
        append_literal_arg --config-server-port
        append_literal_arg "$web_console_config_port"
        append_literal_arg --config-server-protocol
        append_literal_arg "$web_console_config_protocol"
        printf '%s\n' "$cmd"
    else
        printf '\n'
    fi
}

refresh_command_env() {
    [ "$et_mode" = remote ] && COMMAND=$(build_remote_command) || COMMAND=$(build_local_command)
    WEB_COMMAND=$(build_web_command)

    {
        printf 'TMPDIR="%s"\n' "$TMPDIR"
        printf 'BINDIR="%s"\n' "$BINDIR"
        printf 'COMMAND=%s\n' "$(shell_quote_single "$COMMAND")"
        printf 'WEB_COMMAND=%s\n' "$(shell_quote_single "$WEB_COMMAND")"
    } > "$APPDIR/configs/command.env"
}
