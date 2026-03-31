[ -n "$__IS_MODULE_COMMON_LOADED" ] && return
__IS_MODULE_COMMON_LOADED=1

. "$APPDIR/scripts/libs/set_config.sh"

msg_alert() {
    _sleep_time=1
    if [ "$1" = '-t' ] && [ -n "$2" ]; then
        _sleep_time="$2"
        shift 2
    fi
    line_break
    separator_line '='
    for line in "$@"; do
        content_line "$line"
    done
    separator_line '='
    sleep "$_sleep_time"
}

comp_box() {
    line_break
    separator_line '='
    for line in "$@"; do
        content_line "$line"
    done
    separator_line '='
}

top_box() {
    line_break
    separator_line '='
    for line in "$@"; do
        content_line "$line"
    done
}

btm_box() {
    for line in "$@"; do
        content_line "$line"
    done
    separator_line '='
}

common_back() {
    content_line "0) $COMMON_BACK"
    separator_line '='
}

errornum() {
    msg_alert "\033[31m$COMMON_ERR_NUM\033[0m"
}

ensure_list_file() {
    [ -f "$1" ] || touch "$1"
}

value_or_empty() {
    [ -n "$1" ] && printf '%s' "$1" || printf '%s' "$COMMON_EMPTY"
}

safe_config_key() {
    case "$1" in
        ''|*[!A-Za-z0-9_]*|[0-9]*)
            return 1
            ;;
    esac
}

current_effective_value() {
    key="$1"
    safe_config_key "$key" || {
        printf '%s' "$COMMON_EMPTY"
        return 1
    }
    eval "value=\${$key}"
    printf '%s' "$value"
}

mask_secret_value() {
    value="$1"
    [ -n "$value" ] || {
        printf '%s' "$COMMON_EMPTY"
        return 0
    }

    length=$(printf '%s' "$value" | wc -c | awk '{print $1}')
    if [ "$length" -le 4 ]; then
        printf '****'
    else
        prefix=$(printf '%s' "$value" | cut -c 1-2)
        suffix=$(printf '%s' "$value" | rev | cut -c 1-2 | rev)
        printf '%s****%s' "$prefix" "$suffix"
    fi
}

switch_status_text() {
    case "$1" in
        ON|1|true|TRUE)
            printf '%s' "$MENU_AUTOSTART_ON"
            ;;
        *)
            printf '%s' "$MENU_AUTOSTART_OFF"
            ;;
    esac
}

list_count_text() {
    file="$1"
    ensure_list_file "$file"
    count=$(grep -vE '^$|^#' "$file" 2>/dev/null | wc -l | awk '{print $1}')
    [ -n "$count" ] || count=0
    printf '%s' "$count"
}

trim_comments_to_tmp() {
    input="$1"
    output="$2"
    ensure_list_file "$input"
    grep -vE '^$|^#' "$input" > "$output" 2>/dev/null || :
}

edit_simple_value() {
    key="$1"
    prompt="$2"
    safe_config_key "$key" || return 1
    current=$(current_effective_value "$key")
    comp_box "$prompt" "当前值: ${current:-<empty>}"
    read -r -p "$COMMON_INPUT> " value
    setconfig "$key" "$value"
    load_config
}

edit_simple_value_keep_previous() {
    key="$1"
    prompt="$2"
    safe_config_key "$key" || return 1
    current=$(current_effective_value "$key")
    comp_box "$prompt" "当前值: ${current:-<empty>}"
    read -r -p "$COMMON_INPUT> " value
    [ -z "$value" ] && value="$current"
    setconfig "$key" "$value"
    load_config
}

toggle_simple_value() {
    key="$1"
    safe_config_key "$key" || return 1
    current=$(grep "^$key=" "$APPDIR/configs/ShellEasytier.cfg" 2>/dev/null | sed "s/^$key=//")
    [ "$current" = ON ] && setconfig "$key" OFF || setconfig "$key" ON
    load_config
}

toggle_by_key() {
    toggle_simple_value "$1"
}

remove_list_index() {
    file="$1"
    idx="$2"
    tmp="$TMPDIR/list_edit.tmp"
    awk -v i="$idx" 'NR!=i {print $0}' "$file" > "$tmp" && mv -f "$tmp" "$file"
}

run_cli_query() {
    subcmd="$1"
    tmp_out="$TMPDIR/cli_${subcmd}.out"
    pid=''
    i=1

    [ -x "$BINDIR/easytier-cli" ] || {
        msg_alert "$MENU_RUN_FIRST"
        return 1
    }

    mkdir -p "$TMPDIR" 2>/dev/null
    rm -f "$tmp_out"

    "$BINDIR/easytier-cli" -p "$rpc_cli_portal" "$subcmd" > "$tmp_out" 2>&1 &
    pid=$!

    while kill -0 "$pid" 2>/dev/null && [ "$i" -le 5 ]; do
        sleep 1
        i=$((i + 1))
    done

    if kill -0 "$pid" 2>/dev/null; then
        kill -TERM "$pid" 2>/dev/null
        wait "$pid" 2>/dev/null
        msg_alert "$MENU_CLI_TIMEOUT"
        rm -f "$tmp_out"
        return 1
    fi

    wait "$pid"
    line_break
    separator_line '='
    if [ -s "$tmp_out" ]; then
        while IFS= read -r line; do
            content_line "$line"
        done < "$tmp_out"
    else
        content_line "$MENU_CLI_EMPTY"
    fi
    separator_line '='
    read -r -p "$MENU_PRESS_ENTER" _dummy
    rm -f "$tmp_out"
}

run_cli_args() {
    label="$1"
    shift

    tmp_out="$TMPDIR/cli_${label}.out"
    pid=''
    i=1

    [ -x "$BINDIR/easytier-cli" ] || {
        msg_alert "$MENU_RUN_FIRST"
        return 1
    }

    mkdir -p "$TMPDIR" 2>/dev/null
    rm -f "$tmp_out"

    "$BINDIR/easytier-cli" -p "$rpc_cli_portal" "$@" > "$tmp_out" 2>&1 &
    pid=$!

    while kill -0 "$pid" 2>/dev/null && [ "$i" -le 5 ]; do
        sleep 1
        i=$((i + 1))
    done

    if kill -0 "$pid" 2>/dev/null; then
        kill -TERM "$pid" 2>/dev/null
        wait "$pid" 2>/dev/null
        msg_alert "$MENU_CLI_TIMEOUT"
        rm -f "$tmp_out"
        return 1
    fi

    wait "$pid"
    line_break
    separator_line '='
    if [ -s "$tmp_out" ]; then
        while IFS= read -r line; do
            content_line "$line"
        done < "$tmp_out"
    else
        content_line "$MENU_CLI_EMPTY"
    fi
    separator_line '='
    read -r -p "$MENU_PRESS_ENTER" _dummy
    rm -f "$tmp_out"
}

show_text_file() {
    file="$1"
    title="$2"

    line_break
    separator_line '='
    content_line "$title"
    separator_line '-'
    if [ -s "$file" ]; then
        while IFS= read -r line; do
            content_line "$line"
        done < "$file"
    else
        content_line "$MENU_CLI_EMPTY"
    fi
    separator_line '='
    read -r -p "$MENU_PRESS_ENTER" _dummy
}

show_tail_file() {
    file="$1"
    title="$2"
    lines="$3"

    line_break
    separator_line '='
    content_line "$title"
    separator_line '-'
    if [ -s "$file" ]; then
        tail -n "$lines" "$file" | while IFS= read -r line; do
            content_line "$line"
        done
    else
        content_line "$MENU_CLI_EMPTY"
    fi
    separator_line '='
    read -r -p "$MENU_PRESS_ENTER" _dummy
}

edit_list_file() {
    title="$1"
    file="$2"
    ensure_list_file "$file"

    while true; do
        comp_box "$title"
        if [ -s "$file" ]; then
            nl -ba "$file" | while read -r idx text; do
                content_line "$idx) $text"
            done
        else
            content_line "$COMMON_EMPTY"
        fi
        btm_box '1) 添加' '2) 删除' '3) 清空' '0) 返回'
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
            0|'')
                return
                ;;
            1)
                read -r -p '输入内容 > ' line
                [ -n "$line" ] && printf '%s\n' "$line" >> "$file"
                ;;
            2)
                read -r -p '输入要删除的序号 > ' idx
                [ -n "$idx" ] && remove_list_index "$file" "$idx"
                ;;
            3)
                : > "$file"
                ;;
            *)
                errornum
                ;;
        esac
    done
}
