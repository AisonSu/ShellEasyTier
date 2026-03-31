[ -n "$__IS_LIB_COMPATIBILITY" ] && return
__IS_LIB_COMPATIBILITY=1

. "$APPDIR/scripts/libs/check_cmd.sh"

COMPAT_FILTER_CHAIN='SHELLEASYTIER_FWD'
COMPAT_NAT_POST_CHAIN='SHELLEASYTIER_POST'
COMPAT_NAT_BYPASS_CHAIN='SHELLEASYTIER_BYPASS'
COMPAT_STATUS_FILE="${TMPDIR:-/tmp/ShellEasytier}/compatibility.status"
COMPAT_FWUSER_MARK='# ShellEasyTier compatibility hook'

compat_bool_on() {
    case "$1" in
        ON|1|true|TRUE|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

compat_iptables_ready() {
    ckcmd iptables
}

compat_iface_exists() {
    ip link show "$1" >/dev/null 2>&1
}

compat_shellcrash_detected() {
    [ -d /etc/ShellCrash ] && return 0
    iptables -t nat -S 2>/dev/null | grep -qi 'shellcrash'
}

compat_enabled() {
    compat_bool_on "$compat_enable" || return 1
    [ "$no_tun" = ON ] && return 1
    compat_iptables_ready || return 1
    return 0
}

compat_detect_lan_if() {
    [ -n "$compat_lan_if" ] && compat_iface_exists "$compat_lan_if" && {
        printf '%s\n' "$compat_lan_if"
        return 0
    }

    for iface in br-lan br0 lan; do
        compat_iface_exists "$iface" && {
            printf '%s\n' "$iface"
            return 0
        }
    done

    ip -4 route show scope link 2>/dev/null | awk '
        {
            dest=$1
            dev=""
            for(i=1;i<=NF;i++) if($i=="dev") dev=$(i+1)
            if(dev=="" || dev ~ /^(lo|tun|utun|wg|tailscale|docker|veth|virbr|pppoe|wan)/) next
            if(dest ~ /^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)/) { print dev; exit }
        }
    '
}

compat_collect_lan_subnets() {
    lan_if="$1"
    subnets=$(ip -4 route show dev "$lan_if" scope link 2>/dev/null | awk '
        $1 ~ /^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)/ { print $1 }
    ')

    [ -n "$subnets" ] || subnets=$(ip -o -4 addr show dev "$lan_if" 2>/dev/null | awk '{print $4}')
    printf '%s\n' "$subnets" | sed '/^$/d'
}

compat_detect_tun_if() {
    [ -n "$compat_tun_if" ] && compat_iface_exists "$compat_tun_if" && {
        printf '%s\n' "$compat_tun_if"
        return 0
    }

    [ -n "$dev_name" ] && compat_iface_exists "$dev_name" && {
        printf '%s\n' "$dev_name"
        return 0
    }

    compat_iface_exists tun0 && {
        printf 'tun0\n'
        return 0
    }

    ip -o link show 2>/dev/null | awk -F': ' '/^[0-9]+: tun[0-9]*/ { print $2; exit }'
}

compat_collect_tun_routes() {
    tun_if="$1"
    routes=$(ip -4 route show dev "$tun_if" 2>/dev/null | awk '$1 != "default" { print $1 }')
    [ -n "$routes" ] || routes=$(ip -o -4 addr show dev "$tun_if" 2>/dev/null | awk '{print $4}')
    printf '%s\n' "$routes" | sed '/^$/d' | awk '!x[$0]++'
}

compat_delete_rule() {
    table="$1"
    shift
    while iptables -t "$table" -D "$@" 2>/dev/null; do :; done
}

compat_reset_chain() {
    table="$1"
    chain="$2"
    iptables -t "$table" -N "$chain" 2>/dev/null || true
    iptables -t "$table" -F "$chain" 2>/dev/null || true
}

compat_drop_chain() {
    table="$1"
    chain="$2"
    iptables -t "$table" -F "$chain" 2>/dev/null || true
    iptables -t "$table" -X "$chain" 2>/dev/null || true
}

compat_delete_chain_references() {
    table="$1"
    chain="$2"

    iptables -t "$table" -S 2>/dev/null | while IFS= read -r rule; do
        case "$rule" in
            *"-j $chain"*)
                set -- $rule
                [ "$1" = "-A" ] || continue
                from_chain="$2"
                shift 2
                compat_delete_rule "$table" "$from_chain" "$@"
                ;;
        esac
    done
}

compat_fix_route_metrics() {
    tun_if="$1"
    compat_bool_on "$compat_fix_metric" || return 0

    compat_collect_tun_routes "$tun_if" | while IFS= read -r cidr; do
        [ -n "$cidr" ] || continue
        good_route=$(ip route show "$cidr" dev "$tun_if" 2>/dev/null | awk '!/metric 65535/ { print; exit }')
        ip route del "$cidr" dev "$tun_if" metric 65535 2>/dev/null || true
        ip route del "$cidr" dev "$tun_if" proto static metric 65535 2>/dev/null || true
        [ -n "$good_route" ] || ip route replace "$cidr" dev "$tun_if" metric 10 2>/dev/null || true
    done
}

compat_apply_forward_rules() {
    lan_if="$1"
    tun_if="$2"

    compat_reset_chain filter "$COMPAT_FILTER_CHAIN"
    iptables -t filter -A "$COMPAT_FILTER_CHAIN" -j ACCEPT

    compat_delete_rule filter FORWARD -i "$lan_if" -o "$tun_if" -j "$COMPAT_FILTER_CHAIN"
    compat_delete_rule filter FORWARD -i "$tun_if" -o "$lan_if" -j "$COMPAT_FILTER_CHAIN"

    iptables -t filter -I FORWARD 1 -i "$lan_if" -o "$tun_if" -j "$COMPAT_FILTER_CHAIN"
    iptables -t filter -I FORWARD 1 -i "$tun_if" -o "$lan_if" -j "$COMPAT_FILTER_CHAIN"
}

compat_apply_postrouting_rules() {
    tun_if="$1"
    compat_bool_on "$compat_masquerade" || {
        compat_delete_rule nat POSTROUTING -o "$tun_if" -j "$COMPAT_NAT_POST_CHAIN"
        compat_drop_chain nat "$COMPAT_NAT_POST_CHAIN"
        return 0
    }

    compat_reset_chain nat "$COMPAT_NAT_POST_CHAIN"
    compat_collect_lan_subnets "$2" | while IFS= read -r cidr; do
        [ -n "$cidr" ] || continue
        iptables -t nat -A "$COMPAT_NAT_POST_CHAIN" -s "$cidr" -o "$tun_if" -j MASQUERADE
    done

    compat_delete_rule nat POSTROUTING -o "$tun_if" -j "$COMPAT_NAT_POST_CHAIN"
    iptables -t nat -I POSTROUTING 1 -o "$tun_if" -j "$COMPAT_NAT_POST_CHAIN"
}

compat_apply_shellcrash_bypass() {
    compat_bool_on "$compat_shellcrash" || {
        compat_delete_rule nat PREROUTING -j "$COMPAT_NAT_BYPASS_CHAIN"
        compat_drop_chain nat "$COMPAT_NAT_BYPASS_CHAIN"
        return 0
    }

    compat_shellcrash_detected || {
        compat_delete_rule nat PREROUTING -j "$COMPAT_NAT_BYPASS_CHAIN"
        compat_drop_chain nat "$COMPAT_NAT_BYPASS_CHAIN"
        return 0
    }

    compat_reset_chain nat "$COMPAT_NAT_BYPASS_CHAIN"

    compat_collect_lan_subnets "$1" | while IFS= read -r lan_cidr; do
        [ -n "$lan_cidr" ] || continue
        compat_collect_tun_routes "$2" | while IFS= read -r tun_cidr; do
            [ -n "$tun_cidr" ] || continue
            iptables -t nat -A "$COMPAT_NAT_BYPASS_CHAIN" -s "$lan_cidr" -d "$tun_cidr" -j ACCEPT
        done
    done

    compat_delete_rule nat PREROUTING -j "$COMPAT_NAT_BYPASS_CHAIN"
    iptables -t nat -I PREROUTING 1 -j "$COMPAT_NAT_BYPASS_CHAIN"
}

compat_remove_rules() {
    compat_delete_chain_references filter "$COMPAT_FILTER_CHAIN"
    compat_delete_chain_references nat "$COMPAT_NAT_POST_CHAIN"
    compat_delete_chain_references nat "$COMPAT_NAT_BYPASS_CHAIN"

    compat_drop_chain filter "$COMPAT_FILTER_CHAIN"
    compat_drop_chain nat "$COMPAT_NAT_POST_CHAIN"
    compat_drop_chain nat "$COMPAT_NAT_BYPASS_CHAIN"
    rm -f "$COMPAT_STATUS_FILE"
}

compat_install_firewall_hook() {
    hook='/etc/firewall.d/99-shelleasytier-compat.sh'
    task_hook="$APPDIR/task/compat_firewall_hook.sh"

    mkdir -p "$APPDIR/task" 2>/dev/null || true
    cat > "$task_hook" <<EOF
#!/bin/sh
APPDIR="$APPDIR"
"$APPDIR/start.sh" status-code >/dev/null 2>&1 || {
    return 0 2>/dev/null || exit 0
}
(
    sleep 3
    "$APPDIR/start.sh" compat-apply >/dev/null 2>&1
) &
return 0 2>/dev/null || exit 0
EOF
    chmod 755 "$task_hook" 2>/dev/null || true

    if [ -d /etc/firewall.d ]; then
        cp -f "$task_hook" "$hook" 2>/dev/null || true
        chmod 755 "$hook" 2>/dev/null || true
        return 0
    fi

    fwuser=/etc/firewall.user
    touch "$fwuser" 2>/dev/null || return 0
    sed -i '/ShellEasyTier compatibility hook/d' "$fwuser" 2>/dev/null
    printf '/bin/sh "%s" >/dev/null 2>&1 & %s\n' "$task_hook" "$COMPAT_FWUSER_MARK" >> "$fwuser"
}

compat_remove_firewall_hook() {
    rm -f /etc/firewall.d/99-shelleasytier-compat.sh 2>/dev/null || true
    sed -i '/ShellEasyTier compatibility hook/d' /etc/firewall.user 2>/dev/null || true
    rm -f "$APPDIR/task/compat_firewall_hook.sh" 2>/dev/null || true
}

compat_write_status() {
    mkdir -p "$(dirname "$COMPAT_STATUS_FILE")" 2>/dev/null
    {
        printf 'compat_enable=%s\n' "$compat_enable"
        printf 'compat_shellcrash=%s\n' "$compat_shellcrash"
        printf 'compat_masquerade=%s\n' "$compat_masquerade"
        printf 'compat_fix_metric=%s\n' "$compat_fix_metric"
        printf 'lan_if=%s\n' "$1"
        printf 'tun_if=%s\n' "$2"
        printf 'shellcrash=%s\n' "$3"
        printf 'lan_subnets=%s\n' "$4"
        printf 'tun_routes=%s\n' "$5"
    } > "$COMPAT_STATUS_FILE"
}

compat_join_lines() {
    tr '\n' ',' | sed 's/,$//'
}

compat_rule_state() {
    table="$1"
    pattern="$2"
    iptables -t "$table" -S 2>/dev/null | grep -F -- "$pattern" >/dev/null 2>&1 && {
        printf 'ok\n'
        return 0
    }
    printf 'missing\n'
}

compat_metric_issue_routes() {
    tun_if="$1"
    ip route show dev "$tun_if" 2>/dev/null | grep 'metric 65535' | awk '{print $1}' | compat_join_lines
}

compat_status_raw() {
    lan_if=$(compat_detect_lan_if)
    tun_if=$(compat_detect_tun_if)
    lan_subnets=$(compat_collect_lan_subnets "$lan_if" 2>/dev/null | compat_join_lines)
    tun_routes=$(compat_collect_tun_routes "$tun_if" 2>/dev/null | compat_join_lines)
    compat_shellcrash_detected && sc='yes' || sc='no'

    if [ -n "$lan_if" ] && [ -n "$tun_if" ]; then
        fwd_lan_to_tun=$(compat_rule_state filter "-A FORWARD -i $lan_if -o $tun_if -j $COMPAT_FILTER_CHAIN")
        fwd_tun_to_lan=$(compat_rule_state filter "-A FORWARD -i $tun_if -o $lan_if -j $COMPAT_FILTER_CHAIN")
        postrouting_jump=$(compat_rule_state nat "-A POSTROUTING -o $tun_if -j $COMPAT_NAT_POST_CHAIN")
        stale_metric=$(compat_metric_issue_routes "$tun_if")
    else
        fwd_lan_to_tun='unknown'
        fwd_tun_to_lan='unknown'
        postrouting_jump='unknown'
        stale_metric=''
    fi

    compat_shellcrash_detected && bypass_state=$(compat_rule_state nat "-A PREROUTING -j $COMPAT_NAT_BYPASS_CHAIN") || bypass_state='not-needed'
    if [ -f /etc/firewall.d/99-shelleasytier-compat.sh ]; then
        firewall_hook='firewall.d'
    elif grep -q 'ShellEasyTier compatibility hook' /etc/firewall.user 2>/dev/null; then
        firewall_hook='firewall.user'
    else
        firewall_hook='absent'
    fi

    printf 'compat_enable=%s\n' "$compat_enable"
    printf 'compat_shellcrash=%s\n' "$compat_shellcrash"
    printf 'compat_masquerade=%s\n' "$compat_masquerade"
    printf 'compat_fix_metric=%s\n' "$compat_fix_metric"
    printf 'lan_if=%s\n' "$lan_if"
    printf 'tun_if=%s\n' "$tun_if"
    printf 'shellcrash_detected=%s\n' "$sc"
    printf 'lan_subnets=%s\n' "$lan_subnets"
    printf 'tun_routes=%s\n' "$tun_routes"
    printf 'forward_lan_to_tun=%s\n' "$fwd_lan_to_tun"
    printf 'forward_tun_to_lan=%s\n' "$fwd_tun_to_lan"
    printf 'postrouting_jump=%s\n' "$postrouting_jump"
    printf 'shellcrash_bypass=%s\n' "$bypass_state"
    printf 'firewall_hook=%s\n' "$firewall_hook"
    printf 'stale_metric_65535=%s\n' "${stale_metric:-none}"
}

compat_human_line() {
    label="$1"
    value="$2"
    printf '%s：%s\n' "$label" "$value"
}

compat_status() {
    lan_if=$(compat_detect_lan_if)
    tun_if=$(compat_detect_tun_if)
    lan_subnets=$(compat_collect_lan_subnets "$lan_if" 2>/dev/null | compat_join_lines)
    tun_routes=$(compat_collect_tun_routes "$tun_if" 2>/dev/null | compat_join_lines)
    compat_shellcrash_detected && sc='已检测到' || sc='未检测到'

    if [ -n "$lan_if" ] && [ -n "$tun_if" ]; then
        fwd_lan_to_tun=$(compat_rule_state filter "-A FORWARD -i $lan_if -o $tun_if -j $COMPAT_FILTER_CHAIN")
        fwd_tun_to_lan=$(compat_rule_state filter "-A FORWARD -i $tun_if -o $lan_if -j $COMPAT_FILTER_CHAIN")
        postrouting_jump=$(compat_rule_state nat "-A POSTROUTING -o $tun_if -j $COMPAT_NAT_POST_CHAIN")
        stale_metric=$(compat_metric_issue_routes "$tun_if")
    else
        fwd_lan_to_tun='unknown'
        fwd_tun_to_lan='unknown'
        postrouting_jump='unknown'
        stale_metric=''
    fi

    compat_shellcrash_detected && bypass_state=$(compat_rule_state nat "-A PREROUTING -j $COMPAT_NAT_BYPASS_CHAIN") || bypass_state='not-needed'
    if [ -f /etc/firewall.d/99-shelleasytier-compat.sh ]; then
        firewall_hook='firewall.d'
    elif grep -q 'ShellEasyTier compatibility hook' /etc/firewall.user 2>/dev/null; then
        firewall_hook='firewall.user'
    else
        firewall_hook='absent'
    fi

    printf 'ShellEasyTier 兼容状态\n'
    printf '%s\n' '----------------------------------------'
    compat_human_line '自动兼容增强' "$(compat_bool_on "$compat_enable" && echo 已启用 || echo 未启用)"
    compat_human_line 'ShellCrash 绕过' "$(compat_bool_on "$compat_shellcrash" && echo 已启用 || echo 未启用)"
    compat_human_line 'MASQUERADE' "$(compat_bool_on "$compat_masquerade" && echo 已启用 || echo 未启用)"
    compat_human_line '路由优先级修正' "$(compat_bool_on "$compat_fix_metric" && echo 已启用 || echo 未启用)"
    printf '%s\n' '----------------------------------------'
    compat_human_line '局域网接口' "${lan_if:-未识别}"
    compat_human_line 'EasyTier 接口' "${tun_if:-未识别}"
    compat_human_line 'ShellCrash' "$sc"
    compat_human_line '局域网网段' "${lan_subnets:-未识别}"
    compat_human_line 'EasyTier/远端网段' "${tun_routes:-未识别}"
    printf '%s\n' '----------------------------------------'
    compat_human_line 'LAN -> TUN 转发规则' "$( [ "$fwd_lan_to_tun" = ok ] && echo 正常 || echo 缺失 )"
    compat_human_line 'TUN -> LAN 转发规则' "$( [ "$fwd_tun_to_lan" = ok ] && echo 正常 || echo 缺失 )"
    compat_human_line 'NAT 回程规则' "$( [ "$postrouting_jump" = ok ] && echo 正常 || echo 缺失 )"
    case "$bypass_state" in
        ok) compat_human_line 'ShellCrash 绕过规则' '正常' ;;
        not-needed) compat_human_line 'ShellCrash 绕过规则' '当前无需应用' ;;
        *) compat_human_line 'ShellCrash 绕过规则' '缺失' ;;
    esac
    case "$firewall_hook" in
        firewall.d) compat_human_line '持久化恢复' '已挂载到 firewall.d' ;;
        firewall.user) compat_human_line '持久化恢复' '已挂载到 firewall.user' ;;
        *) compat_human_line '持久化恢复' '未挂载，防火墙重载后可能丢失' ;;
    esac
    if [ -n "$stale_metric" ]; then
        compat_human_line '旧路由残留' "$stale_metric (metric 65535)"
        printf '%s\n' '建议：执行一次 “立即重应用兼容规则”。'
    else
        compat_human_line '旧路由残留' '未发现'
    fi
}

compat_apply_rules() {
    compat_enabled || {
        compat_remove_rules
        compat_remove_firewall_hook
        return 0
    }

    lan_if=$(compat_detect_lan_if)
    tun_if=$(compat_detect_tun_if)
    [ -n "$lan_if" ] || return 0
    [ -n "$tun_if" ] || return 0

    compat_fix_route_metrics "$tun_if"
    compat_apply_forward_rules "$lan_if" "$tun_if" || return 1
    compat_apply_postrouting_rules "$tun_if" "$lan_if" || return 1
    compat_apply_shellcrash_bypass "$lan_if" "$tun_if" || return 1

    compat_shellcrash_detected && sc='yes' || sc='no'
    compat_write_status \
        "$lan_if" \
        "$tun_if" \
        "$sc" \
        "$(compat_collect_lan_subnets "$lan_if" | compat_join_lines)" \
        "$(compat_collect_tun_routes "$tun_if" | compat_join_lines)"

    compat_install_firewall_hook
    return 0
}

compat_post_start() {
    compat_apply_rules
}
