[ -n "$__IS_LIB_GET_CONFIG" ] && return
__IS_LIB_GET_CONFIG=1

load_config() {
    cfg_path="$APPDIR/configs/ShellEasytier.cfg"
    cfg_example="$APPDIR/configs/ShellEasytier.cfg.example"

    [ -f "$cfg_path" ] || {
        [ -f "$cfg_example" ] && cp -f "$cfg_example" "$cfg_path" 2>/dev/null
    }

    [ -f "$APPDIR/configs/command.env" ] && . "$APPDIR/configs/command.env" >/dev/null 2>&1
    [ -f "$cfg_path" ] && . "$cfg_path" 2>/dev/null

    [ -z "$et_mode" ] && et_mode=local
    [ -z "$instance_name" ] && instance_name=default
    [ -z "$network_name" ] && network_name=default
    [ -z "$rpc_portal" ] && rpc_portal='0.0.0.0:15888'
    [ -z "$rpc_portal_whitelist" ] && rpc_portal_whitelist='127.0.0.1,::1/128'
    [ -z "$default_protocol" ] && default_protocol=udp
    [ -z "$compression" ] && compression=none
    [ -z "$multi_thread_count" ] && multi_thread_count=2
    [ -z "$tld_dns_zone" ] && tld_dns_zone='et.net.'
    [ -z "$enable_exit_node" ] && enable_exit_node=OFF
    [ -z "$bind_device" ] && bind_device=OFF
    [ -z "$binary_storage_mode" ] && binary_storage_mode=auto
    [ -z "$proxy_forward_by_system" ] && proxy_forward_by_system=OFF
    [ -z "$no_listener" ] && no_listener=OFF
    [ -z "$disable_env_parsing" ] && disable_env_parsing=OFF
    [ -z "$core_autostart" ] && core_autostart=ON
    [ -z "$web_console_api_port" ] && web_console_api_port=11211
    [ -z "$web_console_config_port" ] && web_console_config_port=22020
    [ -z "$web_console_config_protocol" ] && web_console_config_protocol=udp
    [ -z "$web_autostart" ] && web_autostart=OFF
    [ -z "$console_log_level" ] && console_log_level=info
    [ -z "$file_log_level" ] && file_log_level=info
    [ -z "$file_log_size" ] && file_log_size=100
    [ -z "$file_log_count" ] && file_log_count=10

    [ -z "$BINDIR" ] && BINDIR="$APPDIR/bin/current"
    [ -z "$TMPDIR" ] && TMPDIR=/tmp/ShellEasytier
    [ -z "$file_log_dir" ] && file_log_dir="$TMPDIR/logs"
    [ -z "$acl_enable" ] && acl_enable=OFF
    [ -z "$acl_config_path" ] && acl_config_path="$APPDIR/configs/acl.toml"

    ET_CFG_PATH="$APPDIR/configs/ShellEasytier.cfg"
    ET_PIDFILE="$TMPDIR/easytier.pid"
    ET_WEB_PIDFILE="$TMPDIR/easytier-web.pid"
    ET_TOML_FILE="$TMPDIR/easytier.toml"
    ET_CORE_RUN_LOG="$TMPDIR/easytier-core.run.log"
    ET_WEB_RUN_LOG="$TMPDIR/easytier-web.run.log"

    export ET_CFG_PATH ET_PIDFILE ET_WEB_PIDFILE ET_TOML_FILE ET_CORE_RUN_LOG ET_WEB_RUN_LOG
}

load_config
