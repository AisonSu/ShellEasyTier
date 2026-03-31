#!/bin/sh

[ -z "$APPDIR" ] && APPDIR=$(
    cd "$(dirname "$0")/.."
    pwd
)
export APPDIR

. "$APPDIR/scripts/libs/get_config.sh"
. "$APPDIR/scripts/libs/check_cmd.sh"
. "$APPDIR/scripts/libs/check_autostart.sh"
. "$APPDIR/scripts/libs/compatibility.sh"
. "$APPDIR/scripts/libs/i18n.sh"
. "$APPDIR/scripts/menus/common.sh"
. "$APPDIR/scripts/menus/1_start.sh"
. "$APPDIR/scripts/menus/running_status.sh"

[ -z "$tui_type" ] && tui_type=tui_layout
[ "$1" = '-l' ] && tui_type=tui_lite
. "$APPDIR/scripts/menus/$tui_type.sh"

load_lang common
load_lang menu

web_menu_enabled() {
    . "$APPDIR/scripts/libs/pkg_profile.sh"
    can_offer_local_web_menu
}

core_tools_enabled() {
    "$APPDIR/start.sh" status-code >/dev/null 2>&1
}

snapshot_core_runtime_config() {
    cat \
        "$APPDIR/configs/ShellEasytier.cfg" \
        "$APPDIR/configs/peers.list" \
        "$APPDIR/configs/listeners.list" \
        "$APPDIR/configs/mapped_listeners.list" \
        "$APPDIR/configs/proxy_networks.list" \
        "$APPDIR/configs/manual_routes.list" \
        "$APPDIR/configs/exit_nodes.list" \
        "$APPDIR/configs/port_forward.list" \
        "$APPDIR/configs/relay_network_whitelist.list" \
        "$APPDIR/configs/stun_servers.list" \
        "$APPDIR/configs/stun_servers_v6.list" \
        "$APPDIR/configs/external_nodes.list" 2>/dev/null

    [ "$acl_enable" = ON ] && [ -f "$acl_config_path" ] && cat "$acl_config_path" 2>/dev/null
}

snapshot_web_runtime_config() {
    cat "$APPDIR/configs/ShellEasytier.cfg" 2>/dev/null
}

prompt_restart_core_if_changed() {
    before_snapshot="$1"
    after_snapshot=$(snapshot_core_runtime_config)
    [ "$before_snapshot" = "$after_snapshot" ] && return 0
    "$APPDIR/start.sh" status-code >/dev/null 2>&1 || return 0

    if [ "$et_mode" = remote ] && [ -z "$config_server" ]; then
        msg_alert "\033[33m$MENU_RESTART_CORE_BLOCKED\033[0m"
        return 0
    fi

    line_break
    separator_line '='
    content_line "$MENU_RESTART_CORE_PROMPT"
    separator_line '='
    read -r -p "$MENU_RESTART_INPUT" restart_now
    [ "$restart_now" = 1 ] || return 0
    restart_service
}

prompt_restart_web_if_changed() {
    before_snapshot="$1"
    after_snapshot=$(snapshot_web_runtime_config)
    [ "$before_snapshot" = "$after_snapshot" ] && return 0
    "$APPDIR/start.sh" web-status-code >/dev/null 2>&1 || return 0

    line_break
    separator_line '='
    content_line "$MENU_RESTART_WEB_PROMPT"
    separator_line '='
    read -r -p "$MENU_RESTART_INPUT" restart_now
    [ "$restart_now" = 1 ] || return 0
    "$APPDIR/start.sh" web-stop >/dev/null 2>&1
    "$APPDIR/start.sh" web-start >/dev/null 2>&1
}

menu_header() {
    versionsh=$(cat "$APPDIR/version" 2>/dev/null)
    running_status
    core_running=0
    core_tools_enabled && core_running=1

    if check_autostart; then
        auto_status="\033[32m$MENU_AUTOSTART_ON\033[0m"
    else
        auto_status="\033[31m$MENU_AUTOSTART_OFF\033[0m"
    fi

    if [ "$core_running" = 1 ]; then
        top_box "\033[30;43m$MENU_WELCOME\033[0m  Ver: ${versionsh:-unknown}" \
            "$MENU_MODE: $et_mode   $MENU_STATUS: $RUN_STATUS"
    else
        top_box "\033[30;43m$MENU_WELCOME\033[0m  Ver: ${versionsh:-unknown}" \
            "$MENU_MODE: $et_mode"
    fi
    separator_line '-'
    content_line "$MENU_RUNTIME: ${BINDIR:-unknown}"
    if [ "$core_running" = 1 ]; then
        content_line "$MENU_AUTOSTART: $auto_status   $MENU_WEB_STATUS: $RUN_WEB_STATUS"
    else
        content_line "$MENU_AUTOSTART: $auto_status"
    fi
    separator_line '='
}

mode_menu() {
    while true; do
        comp_box "$MENU_MODE_TITLE" "1) $MENU_MODE_LOCAL" "2) $MENU_MODE_REMOTE" "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
            0|'') return ;;
            1) setconfig et_mode local ; load_config ; return ;;
            2) setconfig et_mode remote ; load_config ; return ;;
            *) errornum ;;
        esac
    done
}

remote_menu() {
    while true; do
        comp_box "$MENU_REMOTE_TITLE" \
            "1) $MENU_SET_CONFIG_SERVER: $(value_or_empty "$config_server")" \
            "2) $MENU_SET_MACHINE_ID: $(value_or_empty "$machine_id")" \
            "3) $MENU_SET_HOSTNAME: $(value_or_empty "$hostname")" \
            "4) $MENU_SET_INSTANCE: $(value_or_empty "$instance_name")" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
            0|'') return ;;
            1) edit_simple_value config_server "$MENU_INPUT_CONFIG_SERVER" ;;
            2) edit_simple_value machine_id "$MENU_INPUT_MACHINE_ID" ;;
            3) edit_simple_value hostname "$MENU_INPUT_HOSTNAME" ;;
            4) edit_simple_value instance_name "$MENU_INPUT_INSTANCE" ;;
            *) errornum ;;
        esac
    done
}

remote_advanced_menu() {
    while true; do
        comp_box "$MENU_REMOTE_ADVANCED_TITLE" \
            "1) $MENU_ADVANCED_RUNTIME_TITLE" \
            "2) $MENU_ADVANCED_COMPAT_TITLE" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
            0|'') return ;;
            1) advanced_runtime_menu ;;
            2) advanced_compat_menu ;;
            *) errornum ;;
        esac
    done
}

network_menu() {
    while true; do
        comp_box "$MENU_NETWORK_TITLE" \
            "1) $MENU_SET_NETWORK_NAME: $(value_or_empty "$network_name")" \
            "2) $MENU_SET_NETWORK_SECRET: $(mask_secret_value "$network_secret")" \
            "3) $MENU_SET_HOSTNAME: $(value_or_empty "$hostname")" \
            "4) $MENU_TOGGLE_DHCP: $(switch_status_text "$dhcp")" \
            "5) $MENU_SET_IPV4: $(value_or_empty "$ipv4")" \
            "6) $MENU_SET_IPV6: $(value_or_empty "$ipv6")" \
            "7) $MENU_TOGGLE_NO_TUN: $(switch_status_text "$no_tun")" \
            "8) $MENU_EDIT_PEERS: $(list_count_text "$APPDIR/configs/peers.list")" \
            "9) $MENU_EDIT_LISTENERS: $(list_count_text "$APPDIR/configs/listeners.list")" \
            "10) $MENU_EDIT_EXTERNAL_NODES: $(list_count_text "$APPDIR/configs/external_nodes.list")" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
            0|'') return ;;
            1) edit_simple_value network_name "$MENU_INPUT_NETWORK_NAME" ;;
            2) edit_simple_value network_secret "$MENU_INPUT_NETWORK_SECRET" ;;
            3) edit_simple_value hostname "$MENU_INPUT_HOSTNAME" ;;
            4) toggle_simple_value dhcp ;;
            5) edit_simple_value ipv4 "$MENU_INPUT_IPV4" ;;
            6) edit_simple_value ipv6 "$MENU_INPUT_IPV6" ;;
            7) toggle_simple_value no_tun ;;
            8) edit_list_file "$MENU_EDIT_PEERS" "$APPDIR/configs/peers.list" ;;
            9) edit_list_file "$MENU_EDIT_LISTENERS" "$APPDIR/configs/listeners.list" ;;
            10) edit_list_file "$MENU_EDIT_EXTERNAL_NODES" "$APPDIR/configs/external_nodes.list" ;;
            *) errornum ;;
        esac
    done
}

access_menu() {
    while true; do
        comp_box "$MENU_ACCESS_TITLE" \
            "1) $MENU_EDIT_PROXY_NETWORKS: $(list_count_text "$APPDIR/configs/proxy_networks.list")" \
            "2) $MENU_EDIT_EXIT_NODES: $(list_count_text "$APPDIR/configs/exit_nodes.list")" \
            "3) $MENU_EDIT_MANUAL_ROUTES: $(list_count_text "$APPDIR/configs/manual_routes.list")" \
            "4) $MENU_SET_SOCKS5: $(value_or_empty "$socks5_port")" \
            "5) $MENU_SET_VPN_PORTAL: $(value_or_empty "$vpn_portal")" \
            "6) $MENU_TOGGLE_ACCEPT_DNS: $(switch_status_text "$accept_dns")" \
            "7) $MENU_SET_TLD_DNS_ZONE: $(value_or_empty "$tld_dns_zone")" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
            0|'') return ;;
            1) edit_list_file "$MENU_EDIT_PROXY_NETWORKS" "$APPDIR/configs/proxy_networks.list" ;;
            2) edit_list_file "$MENU_EDIT_EXIT_NODES" "$APPDIR/configs/exit_nodes.list" ;;
            3) edit_list_file "$MENU_EDIT_MANUAL_ROUTES" "$APPDIR/configs/manual_routes.list" ;;
            4) edit_simple_value socks5_port "$MENU_INPUT_SOCKS5_PORT" ;;
            5) edit_simple_value vpn_portal "$MENU_INPUT_VPN_PORTAL" ;;
            6) toggle_simple_value accept_dns ;;
            7) edit_simple_value tld_dns_zone "$MENU_INPUT_TLD_DNS_ZONE" ;;
            *) errornum ;;
        esac
    done
}

advanced_listener_menu() {
    while true; do
        comp_box "$MENU_ADVANCED_LISTENER_TITLE" \
            "1) $MENU_SET_DEFAULT_PROTOCOL: $(value_or_empty "$default_protocol")" \
            "2) $MENU_EDIT_MAPPED_LISTENERS: $(list_count_text "$APPDIR/configs/mapped_listeners.list")" \
            "3) $MENU_TOGGLE_NO_LISTENER: $(switch_status_text "$no_listener")" \
            "4) $MENU_EDIT_STUN_SERVERS: $(list_count_text "$APPDIR/configs/stun_servers.list")" \
            "5) $MENU_EDIT_STUN_SERVERS_V6: $(list_count_text "$APPDIR/configs/stun_servers_v6.list")" \
            "6) $MENU_TOGGLE_BIND_DEVICE: $(switch_status_text "$bind_device")" \
            "7) $MENU_SET_DEV_NAME: $(value_or_empty "$dev_name")" \
            "8) $MENU_SET_MTU: $(value_or_empty "$mtu")" \
            "9) $MENU_SET_QUIC_LISTEN_PORT: $(value_or_empty "$quic_listen_port")" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
            0|'') return ;;
            1) edit_simple_value default_protocol "$MENU_INPUT_DEFAULT_PROTOCOL" ;;
            2) edit_list_file "$MENU_EDIT_MAPPED_LISTENERS" "$APPDIR/configs/mapped_listeners.list" ;;
            3) toggle_simple_value no_listener ;;
            4) edit_list_file "$MENU_EDIT_STUN_SERVERS" "$APPDIR/configs/stun_servers.list" ;;
            5) edit_list_file "$MENU_EDIT_STUN_SERVERS_V6" "$APPDIR/configs/stun_servers_v6.list" ;;
            6) toggle_simple_value bind_device ;;
            7) edit_simple_value dev_name "$MENU_INPUT_DEV_NAME" ;;
            8) edit_simple_value mtu "$MENU_INPUT_MTU" ;;
            9) edit_simple_value quic_listen_port "$MENU_INPUT_QUIC_LISTEN_PORT" ;;
            *) errornum ;;
        esac
    done
}

advanced_routing_menu() {
    while true; do
        comp_box "$MENU_ADVANCED_ROUTING_TITLE" \
            "1) $MENU_EDIT_PORT_FORWARD: $(list_count_text "$APPDIR/configs/port_forward.list")" \
            "2) $MENU_TOGGLE_PROXY_FORWARD_BY_SYSTEM: $(switch_status_text "$proxy_forward_by_system")" \
            "3) $MENU_EDIT_RELAY_NETWORK_WHITELIST: $(list_count_text "$APPDIR/configs/relay_network_whitelist.list")" \
            "4) $MENU_SET_FOREIGN_RELAY_BPS_LIMIT: $(value_or_empty "$foreign_relay_bps_limit")" \
            "5) $MENU_TOGGLE_ENABLE_EXIT_NODE: $(switch_status_text "$enable_exit_node")" \
            "6) $MENU_SET_TCP_WHITELIST: $(value_or_empty "$tcp_whitelist")" \
            "7) $MENU_SET_UDP_WHITELIST: $(value_or_empty "$udp_whitelist")" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
            0|'') return ;;
            1) edit_list_file "$MENU_EDIT_PORT_FORWARD" "$APPDIR/configs/port_forward.list" ;;
            2) toggle_simple_value proxy_forward_by_system ;;
            3) edit_list_file "$MENU_EDIT_RELAY_NETWORK_WHITELIST" "$APPDIR/configs/relay_network_whitelist.list" ;;
            4) edit_simple_value foreign_relay_bps_limit "$MENU_INPUT_FOREIGN_RELAY_BPS_LIMIT" ;;
            5) toggle_simple_value enable_exit_node ;;
            6) edit_simple_value tcp_whitelist "$MENU_INPUT_TCP_WHITELIST" ;;
            7) edit_simple_value udp_whitelist "$MENU_INPUT_UDP_WHITELIST" ;;
            *) errornum ;;
        esac
    done
}

advanced_transport_menu() {
    while true; do
        comp_box "$MENU_ADVANCED_TRANSPORT_TITLE" \
            "1) $MENU_SET_COMPRESSION: $(value_or_empty "$compression")" \
            "2) $MENU_TOGGLE_MULTI_THREAD: $(switch_status_text "$multi_thread")" \
            "3) $MENU_SET_MULTI_THREAD_COUNT: $(value_or_empty "$multi_thread_count")" \
            "4) $MENU_TOGGLE_LATENCY_FIRST: $(switch_status_text "$latency_first")" \
            "5) $MENU_TOGGLE_USE_SMOLTCP: $(switch_status_text "$use_smoltcp")" \
            "6) $MENU_TOGGLE_KCP_PROXY: $(switch_status_text "$enable_kcp_proxy")" \
            "7) $MENU_TOGGLE_KCP_INPUT: $(switch_status_text "$disable_kcp_input")" \
            "8) $MENU_TOGGLE_QUIC_PROXY: $(switch_status_text "$enable_quic_proxy")" \
            "9) $MENU_TOGGLE_QUIC_INPUT: $(switch_status_text "$disable_quic_input")" \
            "10) $MENU_TOGGLE_DISABLE_RELAY_KCP: $(switch_status_text "$disable_relay_kcp")" \
            "11) $MENU_TOGGLE_ENABLE_FOREIGN_RELAY_KCP: $(switch_status_text "$enable_relay_foreign_network_kcp")" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
            0|'') return ;;
            1) edit_simple_value compression "$MENU_INPUT_COMPRESSION" ;;
            2) toggle_simple_value multi_thread ;;
            3) edit_simple_value multi_thread_count "$MENU_INPUT_MULTI_THREAD_COUNT" ;;
            4) toggle_simple_value latency_first ;;
            5) toggle_simple_value use_smoltcp ;;
            6) toggle_simple_value enable_kcp_proxy ;;
            7) toggle_simple_value disable_kcp_input ;;
            8) toggle_simple_value enable_quic_proxy ;;
            9) toggle_simple_value disable_quic_input ;;
            10) toggle_simple_value disable_relay_kcp ;;
            11) toggle_simple_value enable_relay_foreign_network_kcp ;;
            *) errornum ;;
        esac
    done
}

advanced_security_menu() {
    while true; do
        comp_box "$MENU_ADVANCED_SECURITY_TITLE" \
            "1) $MENU_TOGGLE_PRIVATE_MODE: $(switch_status_text "$private_mode")" \
            "2) $MENU_TOGGLE_DISABLE_ENCRYPTION: $(switch_status_text "$disable_encryption")" \
            "3) $MENU_SET_ENCRYPTION_ALGORITHM: $(value_or_empty "$encryption_algorithm")" \
            "4) $MENU_TOGGLE_DISABLE_IPV6: $(switch_status_text "$disable_ipv6")" \
            "5) $MENU_TOGGLE_DISABLE_P2P: $(switch_status_text "$disable_p2p")" \
            "6) $MENU_TOGGLE_P2P_ONLY: $(switch_status_text "$p2p_only")" \
            "7) $MENU_TOGGLE_DISABLE_TCP_HOLE: $(switch_status_text "$disable_tcp_hole_punching")" \
            "8) $MENU_TOGGLE_DISABLE_UDP_HOLE: $(switch_status_text "$disable_udp_hole_punching")" \
            "9) $MENU_TOGGLE_DISABLE_SYM_HOLE: $(switch_status_text "$disable_sym_hole_punching")" \
            "10) $MENU_TOGGLE_RELAY_ALL_RPC: $(switch_status_text "$relay_all_peer_rpc")" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
            0|'') return ;;
            1) toggle_simple_value private_mode ;;
            2) toggle_simple_value disable_encryption ;;
            3) edit_simple_value encryption_algorithm "$MENU_INPUT_ENCRYPTION_ALGORITHM" ;;
            4) toggle_simple_value disable_ipv6 ;;
            5) toggle_simple_value disable_p2p ;;
            6) toggle_simple_value p2p_only ;;
            7) toggle_simple_value disable_tcp_hole_punching ;;
            8) toggle_simple_value disable_udp_hole_punching ;;
            9) toggle_simple_value disable_sym_hole_punching ;;
            10) toggle_simple_value relay_all_peer_rpc ;;
            *) errornum ;;
        esac
    done
}

advanced_runtime_menu() {
    while true; do
        comp_box "$MENU_ADVANCED_RUNTIME_TITLE" \
            "1) $MENU_SET_BINARY_STORAGE_MODE: $(value_or_empty "$binary_storage_mode")" \
            "2) $MENU_SET_BINARY_STORAGE_PATH: $(value_or_empty "$binary_storage_path")" \
            "3) $MENU_SET_RPC_PORTAL: $(value_or_empty "$rpc_portal")" \
            "4) $MENU_SET_RPC_WHITELIST: $(value_or_empty "$rpc_portal_whitelist")" \
            "5) $MENU_SET_CONSOLE_LOG_LEVEL: $(value_or_empty "$console_log_level")" \
            "6) $MENU_SET_FILE_LOG_LEVEL: $(value_or_empty "$file_log_level")" \
            "7) $MENU_SET_FILE_LOG_DIR: $(value_or_empty "$file_log_dir")" \
            "8) $MENU_SET_FILE_LOG_SIZE: $(value_or_empty "$file_log_size")" \
            "9) $MENU_SET_FILE_LOG_COUNT: $(value_or_empty "$file_log_count")" \
            "10) $MENU_SET_CONFIG_DIR: $(value_or_empty "$config_dir")" \
            "11) $MENU_TOGGLE_DISABLE_ENV_PARSING: $(switch_status_text "$disable_env_parsing")" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
            0|'') return ;;
            1) edit_simple_value binary_storage_mode "$MENU_INPUT_BINARY_STORAGE_MODE" ;;
            2) edit_simple_value binary_storage_path "$MENU_INPUT_BINARY_STORAGE_PATH" ;;
            3) edit_simple_value rpc_portal "$MENU_INPUT_RPC_PORTAL" ;;
            4) edit_simple_value rpc_portal_whitelist "$MENU_INPUT_RPC_WHITELIST" ;;
            5) edit_simple_value console_log_level "$MENU_INPUT_CONSOLE_LOG_LEVEL" ;;
            6) edit_simple_value file_log_level "$MENU_INPUT_FILE_LOG_LEVEL" ;;
            7) edit_simple_value file_log_dir "$MENU_INPUT_FILE_LOG_DIR" ;;
            8) edit_simple_value file_log_size "$MENU_INPUT_FILE_LOG_SIZE" ;;
            9) edit_simple_value file_log_count "$MENU_INPUT_FILE_LOG_COUNT" ;;
            10) edit_simple_value config_dir "$MENU_INPUT_CONFIG_DIR" ;;
            11) toggle_simple_value disable_env_parsing ;;
            *) errornum ;;
        esac
    done
}

advanced_acl_menu() {
    while true; do
        comp_box "$MENU_ADVANCED_ACL_TITLE" \
            "1) $MENU_TOGGLE_ACL_ENABLE: $(switch_status_text "$acl_enable")" \
            "2) $MENU_SET_ACL_PATH: $(value_or_empty "$acl_config_path")" \
            "3) $MENU_SHOW_ACL_FILE" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
            0|'') return ;;
            1) toggle_simple_value acl_enable ;;
            2) edit_simple_value acl_config_path "$MENU_INPUT_ACL_PATH" ;;
            3) show_text_file "$acl_config_path" "$MENU_SHOW_ACL_FILE" ;;
            *) errornum ;;
        esac
    done
}

advanced_compat_menu() {
    while true; do
        comp_box "$MENU_ADVANCED_COMPAT_TITLE" \
            "1) $MENU_TOGGLE_COMPAT_ENABLE: $(switch_status_text "$compat_enable")" \
            "2) $MENU_TOGGLE_COMPAT_SHELLCRASH: $(switch_status_text "$compat_shellcrash")" \
            "3) $MENU_TOGGLE_COMPAT_MASQUERADE: $(switch_status_text "$compat_masquerade")" \
            "4) $MENU_TOGGLE_COMPAT_FIX_METRIC: $(switch_status_text "$compat_fix_metric")" \
            "5) $MENU_SET_COMPAT_LAN_IF: $(value_or_empty "$compat_lan_if")" \
            "6) $MENU_SET_COMPAT_TUN_IF: $(value_or_empty "$compat_tun_if")" \
            "7) $MENU_SHOW_COMPAT_STATUS" \
            "8) $MENU_APPLY_COMPAT_NOW" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
            0|'') return ;;
            1) toggle_simple_value compat_enable ;;
            2) toggle_simple_value compat_shellcrash ;;
            3) toggle_simple_value compat_masquerade ;;
            4) toggle_simple_value compat_fix_metric ;;
            5) edit_simple_value compat_lan_if "$MENU_INPUT_COMPAT_LAN_IF" ;;
            6) edit_simple_value compat_tun_if "$MENU_INPUT_COMPAT_TUN_IF" ;;
            7) run_cli_shell_command '"'$APPDIR'/start.sh" compat-status' ;;
            8) "$APPDIR/start.sh" compat-apply >/dev/null 2>&1; run_cli_shell_command '"'$APPDIR'/start.sh" compat-status' ;;
            *) errornum ;;
        esac
    done
}

advanced_menu() {
    while true; do
        comp_box "$MENU_ADVANCED_TITLE" \
            "1) $MENU_ADVANCED_LISTENER_TITLE" \
            "2) $MENU_ADVANCED_ROUTING_TITLE" \
            "3) $MENU_ADVANCED_TRANSPORT_TITLE" \
            "4) $MENU_ADVANCED_SECURITY_TITLE" \
            "5) $MENU_ADVANCED_RUNTIME_TITLE" \
            "6) $MENU_ADVANCED_ACL_TITLE" \
            "7) $MENU_ADVANCED_COMPAT_TITLE" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
            0|'') return ;;
            1) advanced_listener_menu ;;
            2) advanced_routing_menu ;;
            3) advanced_transport_menu ;;
            4) advanced_security_menu ;;
            5) advanced_runtime_menu ;;
            6) advanced_acl_menu ;;
            7) advanced_compat_menu ;;
            *) errornum ;;
        esac
    done
}

service_menu() {
    while true; do
        load_config
        running_status
        if "$APPDIR/start.sh" status-code >/dev/null 2>&1; then
            service_action_label="$MENU_SERVICE_STOP"
            service_action=stop
            show_restart=1
        else
            service_action_label="$MENU_SERVICE_START"
            service_action=start
            show_restart=0
        fi

        if check_core_autostart; then
            auto_label="$MENU_CORE_AUTOSTART_OFF"
            auto_action=disable
        else
            auto_label="$MENU_CORE_AUTOSTART_ON"
            auto_action=enable
        fi

        if [ "$show_restart" = 1 ]; then
            comp_box "$MENU_SERVICE_TITLE" \
                "$MENU_STATUS: $RUN_STATUS" \
                "$MENU_AUTOSTART: $(check_core_autostart && printf '%s' "$MENU_AUTOSTART_ON" || printf '%s' "$MENU_AUTOSTART_OFF")" \
                "1) $MENU_SERVICE_INIT" \
                "2) $service_action_label" \
                "3) $MENU_SERVICE_RESTART" \
                "4) $auto_label" \
                "0) $COMMON_BACK"
        else
            comp_box "$MENU_SERVICE_TITLE" \
                "$MENU_STATUS: $RUN_STATUS" \
                "$MENU_AUTOSTART: $(check_core_autostart && printf '%s' "$MENU_AUTOSTART_ON" || printf '%s' "$MENU_AUTOSTART_OFF")" \
                "1) $MENU_SERVICE_INIT" \
                "2) $service_action_label" \
                "3) $auto_label" \
                "0) $COMMON_BACK"
        fi

        read -r -p "$COMMON_INPUT> " num
        if [ "$show_restart" = 1 ]; then
            case "$num" in
                0|'') return ;;
                1) . "$APPDIR/init.sh" ;;
                2) stop_service ;;
                3) restart_service ;;
                4)
                    [ "$auto_action" = enable ] && enable_core_autostart || disable_core_autostart
                    ;;
                *) errornum ;;
            esac
        else
            case "$num" in
                0|'') return ;;
                1) . "$APPDIR/init.sh" ;;
                2) start_service ;;
                3)
                    [ "$auto_action" = enable ] && enable_core_autostart || disable_core_autostart
                    ;;
                *) errornum ;;
            esac
        fi
    done
}

web_menu() {
    . "$APPDIR/scripts/libs/pkg_profile.sh"
    can_offer_local_web_menu || {
        msg_alert "\033[33m$MENU_WEB_UNAVAILABLE\033[0m"
        return
    }

    if check_web_autostart; then
        web_auto_label="$MENU_WEB_AUTOSTART_OFF"
    else
        web_auto_label="$MENU_WEB_AUTOSTART_ON"
    fi

    while true; do
        load_config
        running_status
        if "$APPDIR/start.sh" web-status-code >/dev/null 2>&1; then
            web_action_label="$MENU_WEB_STOP"
            web_action=stop
        else
            web_action_label="$MENU_WEB_START"
            web_action=start
        fi

        comp_box "$MENU_WEB_TITLE" \
            "$MENU_WEB_STATUS: $RUN_WEB_STATUS" \
            "$MENU_AUTOSTART: $(check_web_autostart && printf '%s' "$MENU_AUTOSTART_ON" || printf '%s' "$MENU_AUTOSTART_OFF")" \
            "1) $web_action_label" \
            "2) $MENU_WEB_SET_PORT: $(value_or_empty "$web_console_api_port")" \
            "3) $MENU_WEB_SET_CONFIG_PORT: $(value_or_empty "$web_console_config_port")" \
            "4) $web_auto_label" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
            0|'') return ;;
            1)
                [ "$web_action" = start ] && "$APPDIR/start.sh" web-start || "$APPDIR/start.sh" web-stop
                ;;
            2) edit_simple_value web_console_api_port "$MENU_INPUT_WEB_PORT" ;;
            3) edit_simple_value web_console_config_port "$MENU_INPUT_WEB_CONFIG_PORT" ;;
            4)
                if check_web_autostart; then
                    setconfig web_autostart OFF
                    disable_web_autostart
                    web_auto_label="$MENU_WEB_AUTOSTART_ON"
                else
                    setconfig web_autostart ON
                    enable_web_autostart
                    web_auto_label="$MENU_WEB_AUTOSTART_OFF"
                fi
                load_config
                ;;
            *) errornum ;;
        esac
    done
}

tools_menu() {
    while true; do
        if [ "$et_mode" = remote ]; then
            comp_box "$MENU_TOOLS_TITLE" \
                "1) $MENU_SHOW_CONFIG_SERVER" \
                "2) $MENU_SHOW_MACHINE_ID" \
                "3) $MENU_SHOW_CORE_RUN_LOG" \
                "4) $MENU_SHOW_LOG_PATH" \
                "5) $MENU_SET_UPDATE_URL" \
                "0) $COMMON_BACK"
        else
            if [ "$acl_enable" = ON ]; then
                comp_box "$MENU_TOOLS_TITLE" \
                    "1) $MENU_SHOW_NODE" \
                    "2) $MENU_SHOW_PEER" \
                    "3) $MENU_SHOW_ROUTE" \
                    "4) $MENU_SHOW_ACL_STATS" \
                    "5) $MENU_SHOW_LOG_PATH" \
                    "6) $MENU_SET_UPDATE_URL" \
                    "0) $COMMON_BACK"
            else
                comp_box "$MENU_TOOLS_TITLE" \
                    "1) $MENU_SHOW_NODE" \
                    "2) $MENU_SHOW_PEER" \
                    "3) $MENU_SHOW_ROUTE" \
                    "4) $MENU_SHOW_LOG_PATH" \
                    "5) $MENU_SET_UPDATE_URL" \
                    "0) $COMMON_BACK"
            fi
        fi
        read -r -p "$COMMON_INPUT> " num
        if [ "$et_mode" = remote ]; then
            case "$num" in
                0|'') return ;;
                1) msg_alert "$config_server" ;;
                2) msg_alert "$machine_id" ;;
                3) show_text_file "$ET_CORE_RUN_LOG" "$MENU_SHOW_CORE_RUN_LOG" ;;
                4) msg_alert "$TMPDIR/ShellEasytier.log" ;;
                5) edit_simple_value_keep_previous update_url "$MENU_INPUT_UPDATE_URL" ;;
                *) errornum ;;
            esac
        else
            if [ "$acl_enable" = ON ]; then
                case "$num" in
                    0|'') return ;;
                    1) run_cli_args node_info node info ;;
                    2) run_cli_query peer ;;
                    3) run_cli_query route ;;
                    4) run_cli_args acl_stats acl stats ;;
                    5) msg_alert "$TMPDIR/ShellEasytier.log" ;;
                    6) edit_simple_value_keep_previous update_url "$MENU_INPUT_UPDATE_URL" ;;
                    *) errornum ;;
                esac
            else
                case "$num" in
                    0|'') return ;;
                    1) run_cli_args node_info node info ;;
                    2) run_cli_query peer ;;
                    3) run_cli_query route ;;
                    4) msg_alert "$TMPDIR/ShellEasytier.log" ;;
                    5) edit_simple_value_keep_previous update_url "$MENU_INPUT_UPDATE_URL" ;;
                    *) errornum ;;
                esac
            fi
        fi
    done
}

main_menu() {
    while true; do
        load_config
        menu_header
        if core_tools_enabled; then
            show_tools=1
        else
            show_tools=0
        fi
        if web_menu_enabled; then
            show_web=1
        else
            show_web=0
        fi

        if [ "$et_mode" = remote ]; then
            if [ "$show_web" = 1 ]; then
                if [ "$show_tools" = 1 ]; then
                    btm_box \
                        "1) $MENU_MODE_TITLE" \
                        "2) $MENU_REMOTE_TITLE" \
                        "3) $MENU_REMOTE_ADVANCED_TITLE" \
                        "4) $MENU_SERVICE_TITLE" \
                        "5) $MENU_WEB_TITLE" \
                        "6) $MENU_TOOLS_TITLE" \
                        '' \
                        "0) $MENU_EXIT"
                else
                    btm_box \
                        "1) $MENU_MODE_TITLE" \
                        "2) $MENU_REMOTE_TITLE" \
                        "3) $MENU_REMOTE_ADVANCED_TITLE" \
                        "4) $MENU_SERVICE_TITLE" \
                        "5) $MENU_WEB_TITLE" \
                        '' \
                        "0) $MENU_EXIT"
                fi
            else
                if [ "$show_tools" = 1 ]; then
                    btm_box \
                        "1) $MENU_MODE_TITLE" \
                        "2) $MENU_REMOTE_TITLE" \
                        "3) $MENU_REMOTE_ADVANCED_TITLE" \
                        "4) $MENU_SERVICE_TITLE" \
                        "5) $MENU_TOOLS_TITLE" \
                        '' \
                        "0) $MENU_EXIT"
                else
                    btm_box \
                        "1) $MENU_MODE_TITLE" \
                        "2) $MENU_REMOTE_TITLE" \
                        "3) $MENU_REMOTE_ADVANCED_TITLE" \
                        "4) $MENU_SERVICE_TITLE" \
                        '' \
                        "0) $MENU_EXIT"
                fi
            fi
        else
            if [ "$show_web" = 1 ]; then
                if [ "$show_tools" = 1 ]; then
                    btm_box \
                        "1) $MENU_MODE_TITLE" \
                        "2) $MENU_NETWORK_TITLE" \
                        "3) $MENU_ACCESS_TITLE" \
                        "4) $MENU_ADVANCED_TITLE" \
                        "5) $MENU_SERVICE_TITLE" \
                        "6) $MENU_WEB_TITLE" \
                        "7) $MENU_TOOLS_TITLE" \
                        '' \
                        "0) $MENU_EXIT"
                else
                    btm_box \
                        "1) $MENU_MODE_TITLE" \
                        "2) $MENU_NETWORK_TITLE" \
                        "3) $MENU_ACCESS_TITLE" \
                        "4) $MENU_ADVANCED_TITLE" \
                        "5) $MENU_SERVICE_TITLE" \
                        "6) $MENU_WEB_TITLE" \
                        '' \
                        "0) $MENU_EXIT"
                fi
            else
                if [ "$show_tools" = 1 ]; then
                    btm_box \
                        "1) $MENU_MODE_TITLE" \
                        "2) $MENU_NETWORK_TITLE" \
                        "3) $MENU_ACCESS_TITLE" \
                        "4) $MENU_ADVANCED_TITLE" \
                        "5) $MENU_SERVICE_TITLE" \
                        "6) $MENU_TOOLS_TITLE" \
                        '' \
                        "0) $MENU_EXIT"
                else
                    btm_box \
                        "1) $MENU_MODE_TITLE" \
                        "2) $MENU_NETWORK_TITLE" \
                        "3) $MENU_ACCESS_TITLE" \
                        "4) $MENU_ADVANCED_TITLE" \
                        "5) $MENU_SERVICE_TITLE" \
                        '' \
                        "0) $MENU_EXIT"
                fi
            fi
        fi
        read -r -p "$COMMON_INPUT> " num
        if [ "$et_mode" = remote ]; then
            if [ "$show_web" = 1 ]; then
                if [ "$show_tools" = 1 ]; then
                    case "$num" in
                        0|'') exit 0 ;;
                        1)
                            before_snapshot=$(snapshot_core_runtime_config)
                            mode_menu
                            prompt_restart_core_if_changed "$before_snapshot"
                            ;;
                        2)
                            before_snapshot=$(snapshot_core_runtime_config)
                            remote_menu
                            prompt_restart_core_if_changed "$before_snapshot"
                            ;;
                        3)
                            before_snapshot=$(snapshot_core_runtime_config)
                            remote_advanced_menu
                            prompt_restart_core_if_changed "$before_snapshot"
                            ;;
                        4) service_menu ;;
                        5)
                            before_snapshot=$(snapshot_web_runtime_config)
                            web_menu
                            prompt_restart_web_if_changed "$before_snapshot"
                            ;;
                        6) tools_menu ;;
                        *) errornum ;;
                    esac
                else
                    case "$num" in
                        0|'') exit 0 ;;
                        1)
                            before_snapshot=$(snapshot_core_runtime_config)
                            mode_menu
                            prompt_restart_core_if_changed "$before_snapshot"
                            ;;
                        2)
                            before_snapshot=$(snapshot_core_runtime_config)
                            remote_menu
                            prompt_restart_core_if_changed "$before_snapshot"
                            ;;
                        3)
                            before_snapshot=$(snapshot_core_runtime_config)
                            remote_advanced_menu
                            prompt_restart_core_if_changed "$before_snapshot"
                            ;;
                        4) service_menu ;;
                        5)
                            before_snapshot=$(snapshot_web_runtime_config)
                            web_menu
                            prompt_restart_web_if_changed "$before_snapshot"
                            ;;
                        *) errornum ;;
                    esac
                fi
            else
                if [ "$show_tools" = 1 ]; then
                    case "$num" in
                        0|'') exit 0 ;;
                        1)
                            before_snapshot=$(snapshot_core_runtime_config)
                            mode_menu
                            prompt_restart_core_if_changed "$before_snapshot"
                            ;;
                        2)
                            before_snapshot=$(snapshot_core_runtime_config)
                            remote_menu
                            prompt_restart_core_if_changed "$before_snapshot"
                            ;;
                        3)
                            before_snapshot=$(snapshot_core_runtime_config)
                            remote_advanced_menu
                            prompt_restart_core_if_changed "$before_snapshot"
                            ;;
                        4) service_menu ;;
                        5) tools_menu ;;
                        *) errornum ;;
                    esac
                else
                    case "$num" in
                        0|'') exit 0 ;;
                        1)
                            before_snapshot=$(snapshot_core_runtime_config)
                            mode_menu
                            prompt_restart_core_if_changed "$before_snapshot"
                            ;;
                        2)
                            before_snapshot=$(snapshot_core_runtime_config)
                            remote_menu
                            prompt_restart_core_if_changed "$before_snapshot"
                            ;;
                        3)
                            before_snapshot=$(snapshot_core_runtime_config)
                            remote_advanced_menu
                            prompt_restart_core_if_changed "$before_snapshot"
                            ;;
                        4) service_menu ;;
                        *) errornum ;;
                    esac
                fi
            fi
        else
            if [ "$show_web" = 1 ]; then
                if [ "$show_tools" = 1 ]; then
                    case "$num" in
                        0|'') exit 0 ;;
                        1)
                            before_snapshot=$(snapshot_core_runtime_config)
                            mode_menu
                            prompt_restart_core_if_changed "$before_snapshot"
                            ;;
                        2)
                            before_snapshot=$(snapshot_core_runtime_config)
                            network_menu
                            prompt_restart_core_if_changed "$before_snapshot"
                            ;;
                        3)
                            before_snapshot=$(snapshot_core_runtime_config)
                            access_menu
                            prompt_restart_core_if_changed "$before_snapshot"
                            ;;
                        4)
                            before_snapshot=$(snapshot_core_runtime_config)
                            advanced_menu
                            prompt_restart_core_if_changed "$before_snapshot"
                            ;;
                        5) service_menu ;;
                        6)
                            before_snapshot=$(snapshot_web_runtime_config)
                            web_menu
                            prompt_restart_web_if_changed "$before_snapshot"
                            ;;
                        7) tools_menu ;;
                        *) errornum ;;
                    esac
                else
                    case "$num" in
                        0|'') exit 0 ;;
                        1)
                            before_snapshot=$(snapshot_core_runtime_config)
                            mode_menu
                            prompt_restart_core_if_changed "$before_snapshot"
                            ;;
                        2)
                            before_snapshot=$(snapshot_core_runtime_config)
                            network_menu
                            prompt_restart_core_if_changed "$before_snapshot"
                            ;;
                        3)
                            before_snapshot=$(snapshot_core_runtime_config)
                            access_menu
                            prompt_restart_core_if_changed "$before_snapshot"
                            ;;
                        4)
                            before_snapshot=$(snapshot_core_runtime_config)
                            advanced_menu
                            prompt_restart_core_if_changed "$before_snapshot"
                            ;;
                        5) service_menu ;;
                        6)
                            before_snapshot=$(snapshot_web_runtime_config)
                            web_menu
                            prompt_restart_web_if_changed "$before_snapshot"
                            ;;
                        *) errornum ;;
                    esac
                fi
            else
                if [ "$show_tools" = 1 ]; then
                    case "$num" in
                        0|'') exit 0 ;;
                        1)
                            before_snapshot=$(snapshot_core_runtime_config)
                            mode_menu
                            prompt_restart_core_if_changed "$before_snapshot"
                            ;;
                        2)
                            before_snapshot=$(snapshot_core_runtime_config)
                            network_menu
                            prompt_restart_core_if_changed "$before_snapshot"
                            ;;
                        3)
                            before_snapshot=$(snapshot_core_runtime_config)
                            access_menu
                            prompt_restart_core_if_changed "$before_snapshot"
                            ;;
                        4)
                            before_snapshot=$(snapshot_core_runtime_config)
                            advanced_menu
                            prompt_restart_core_if_changed "$before_snapshot"
                            ;;
                        5) service_menu ;;
                        6) tools_menu ;;
                        *) errornum ;;
                    esac
                else
                    case "$num" in
                        0|'') exit 0 ;;
                        1)
                            before_snapshot=$(snapshot_core_runtime_config)
                            mode_menu
                            prompt_restart_core_if_changed "$before_snapshot"
                            ;;
                        2)
                            before_snapshot=$(snapshot_core_runtime_config)
                            network_menu
                            prompt_restart_core_if_changed "$before_snapshot"
                            ;;
                        3)
                            before_snapshot=$(snapshot_core_runtime_config)
                            access_menu
                            prompt_restart_core_if_changed "$before_snapshot"
                            ;;
                        4)
                            before_snapshot=$(snapshot_core_runtime_config)
                            advanced_menu
                            prompt_restart_core_if_changed "$before_snapshot"
                            ;;
                        5) service_menu ;;
                        *) errornum ;;
                    esac
                fi
            fi
        fi
    done
}

main_menu
