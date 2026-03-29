#!/bin/sh

[ -z "$APPDIR" ] && APPDIR=$(
    cd "$(dirname "$0")/.."
    pwd
)
export APPDIR

INSTALL_URL_OVERRIDE=$url
INSTALL_LANG_OVERRIDE=$language
INSTALL_ALIAS_OVERRIDE=$my_alias
INSTALL_WEB_OVERRIDE=$install_web
INSTALL_BINARY_STORAGE_MODE_OVERRIDE=$binary_storage_mode
INSTALL_BINARY_STORAGE_PATH_OVERRIDE=$binary_storage_path

. "$APPDIR/scripts/libs/set_config.sh"
. "$APPDIR/scripts/libs/set_profile.sh"
. "$APPDIR/scripts/libs/check_cmd.sh"
. "$APPDIR/scripts/libs/get_config.sh"
. "$APPDIR/scripts/libs/check_autostart.sh"
. "$APPDIR/scripts/libs/check_arch.sh"
. "$APPDIR/scripts/libs/prepare_runtime.sh"
. "$APPDIR/scripts/libs/build_command.sh"

[ -f "/etc/storage/started_script.sh" ] && {
    systype=Padavan
    initdir='/etc/storage/started_script.sh'
}
[ -d "/jffs" ] && {
    systype=asusrouter
    [ -f "/jffs/.asusrouter" ] && initdir='/jffs/.asusrouter'
    [ -d "/jffs/scripts" ] && initdir='/jffs/scripts/services-start'
}
[ -f "/data/etc/crontabs/root" ] && systype=mi_snapshot
[ -w "/var/mnt/cfg/firewall" ] && systype=ng_snapshot
grep -qE '/(docker|lxc|kubepods|crio|containerd)/' /proc/1/cgroup 2>/dev/null || [ -f /run/.containerenv ] || [ -f /.dockerenv ] && systype=container

mkdir -p "$APPDIR/configs" "$APPDIR/task" "$APPDIR/bin" 2>/dev/null

CFG_PATH="$APPDIR/configs/ShellEasytier.cfg"
[ -f "$CFG_PATH" ] || cp -f "$APPDIR/configs/ShellEasytier.cfg.example" "$CFG_PATH"
load_config

[ -z "$my_alias" ] && my_alias=et
[ -z "$TMPDIR" ] && TMPDIR=/tmp/ShellEasytier

for file in peers.list listeners.list mapped_listeners.list proxy_networks.list manual_routes.list exit_nodes.list port_forward.list stun_servers.list stun_servers_v6.list external_nodes.list relay_network_whitelist.list; do
    touch "$APPDIR/configs/$file"
done

[ -f "$APPDIR/configs/acl.toml" ] || {
    {
        printf '# EasyTier ACL config\n'
        printf '# Enable with acl_enable=ON in ShellEasytier.cfg\n'
    } > "$APPDIR/configs/acl.toml"
}

[ -n "$INSTALL_URL_OVERRIDE" ] && setconfig update_url "$INSTALL_URL_OVERRIDE"
[ -n "$INSTALL_LANG_OVERRIDE" ] && printf '%s\n' "$INSTALL_LANG_OVERRIDE" > "$APPDIR/configs/i18n.cfg"
[ -n "$INSTALL_ALIAS_OVERRIDE" ] && {
    my_alias=$INSTALL_ALIAS_OVERRIDE
    setconfig my_alias "$INSTALL_ALIAS_OVERRIDE"
}
[ -n "$INSTALL_WEB_OVERRIDE" ] && {
    install_web=$INSTALL_WEB_OVERRIDE
    setconfig install_web "$INSTALL_WEB_OVERRIDE"
}
[ -n "$INSTALL_BINARY_STORAGE_MODE_OVERRIDE" ] && {
    binary_storage_mode=$INSTALL_BINARY_STORAGE_MODE_OVERRIDE
    setconfig binary_storage_mode "$INSTALL_BINARY_STORAGE_MODE_OVERRIDE"
}
[ -n "$INSTALL_BINARY_STORAGE_PATH_OVERRIDE" ] && {
    binary_storage_path=$INSTALL_BINARY_STORAGE_PATH_OVERRIDE
    setconfig binary_storage_path "$INSTALL_BINARY_STORAGE_PATH_OVERRIDE"
}
[ -n "$core_autostart" ] || {
    core_autostart=ON
    setconfig core_autostart ON
}
[ -n "$web_autostart" ] || {
    web_autostart=OFF
    setconfig web_autostart OFF
}
setconfig systype "$systype"

[ -z "$machine_id" ] && {
    [ -f /etc/machine-id ] && machine_id=$(cat /etc/machine-id 2>/dev/null)
    [ -z "$machine_id" ] && machine_id=$(hostname 2>/dev/null)
    [ -n "$machine_id" ] && setconfig machine_id "$machine_id"
}

[ "$rpc_portal" = '127.0.0.1:15888' ] && {
    rpc_portal='0.0.0.0:15888'
    setconfig rpc_portal "$rpc_portal"
}

[ -z "$rpc_portal_whitelist" ] && {
    rpc_portal_whitelist='127.0.0.1,::1/128'
    setconfig rpc_portal_whitelist "$rpc_portal_whitelist"
}

check_et_arch >/dev/null 2>&1 || true
choose_runtime_layout >/dev/null 2>&1 || true
refresh_command_env >/dev/null 2>&1 || true

command -v bash >/dev/null 2>&1 && shtype=bash
[ -x /bin/ash ] && shtype=ash
[ -z "$shtype" ] && shtype=sh

[ -w /opt/etc/profile ] && [ "$systype" = "Padavan" ] && profile=/opt/etc/profile
[ -w /jffs/configs/profile.add ] && profile=/jffs/configs/profile.add
[ -z "$profile" ] && profile=/etc/profile

if [ -n "$profile" ] && [ -w "$profile" ]; then
    set_profile "$profile"
fi

[ -w /usr/lib/systemd/system ] && sysdir=/usr/lib/systemd/system
[ -w /etc/systemd/system ] && sysdir=/etc/systemd/system

if [ -f /etc/rc.common ] && grep -q 'procd' /proc/1/comm 2>/dev/null; then
    cp -f "$APPDIR/scripts/starts/shelleasytier.procd" /etc/init.d/shelleasytier
    cp -f "$APPDIR/scripts/starts/shelleasytier-web.procd" /etc/init.d/shelleasytier-web
    sed -i "s#/etc/ShellEasytier#$APPDIR#g" /etc/init.d/shelleasytier
    sed -i "s#/etc/ShellEasytier#$APPDIR#g" /etc/init.d/shelleasytier-web
    chmod 755 /etc/init.d/shelleasytier
    chmod 755 /etc/init.d/shelleasytier-web
    setconfig start_old OFF
elif [ -n "$sysdir" ] && [ "$USER" = "root" ] && grep -q 'systemd' /proc/1/comm 2>/dev/null; then
    cp -f "$APPDIR/scripts/starts/shelleasytier.service" "$sysdir/shelleasytier.service"
    cp -f "$APPDIR/scripts/starts/shelleasytier-web.service" "$sysdir/shelleasytier-web.service"
    sed -i "s#/etc/ShellEasytier#$APPDIR#g" "$sysdir/shelleasytier.service"
    sed -i "s#/etc/ShellEasytier#$APPDIR#g" "$sysdir/shelleasytier-web.service"
    systemctl daemon-reload >/dev/null 2>&1
    setconfig start_old OFF
elif rc-status -r >/dev/null 2>&1; then
    cp -f "$APPDIR/scripts/starts/shelleasytier.openrc" /etc/init.d/shelleasytier
    cp -f "$APPDIR/scripts/starts/shelleasytier-web.openrc" /etc/init.d/shelleasytier-web
    sed -i "s#/etc/ShellEasytier#$APPDIR#g" /etc/init.d/shelleasytier
    sed -i "s#/etc/ShellEasytier#$APPDIR#g" /etc/init.d/shelleasytier-web
    chmod 755 /etc/init.d/shelleasytier
    chmod 755 /etc/init.d/shelleasytier-web
    setconfig start_old OFF
else
    setconfig start_old ON
fi

[ -n "$initdir" ] && {
    touch "$initdir"
    sed -i '/ShellEasytier初始化脚本/d' "$initdir" 2>/dev/null
    echo "$APPDIR/scripts/starts/general_init.sh & #ShellEasytier初始化脚本" >> "$initdir"
    chmod 755 "$APPDIR/scripts/starts/general_init.sh" 2>/dev/null
    setconfig initdir "$initdir"
}

[ "$core_autostart" = ON ] && enable_core_autostart || disable_core_autostart
[ "$web_autostart" = ON ] && enable_web_autostart || disable_web_autostart

printf '\033[32mShellEasytier 初始化完成，请输入\033[30;47m %s \033[0;33m开始使用！\033[0m\n' "${my_alias:-et}"
