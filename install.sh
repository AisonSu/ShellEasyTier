#!/bin/sh

echo '***********************************************'
echo '**             Welcome to / 欢迎使用          **'
echo '**               ShellEasytier                **'
echo '***********************************************'

[ -z "$language" ] && language=chs
[ -z "$url" ] && url='https://github.com/AisonSu/ShellEasyTier/releases/latest/download'

archive_name='ShellEasytier.tar.gz'
archive_url="$url/$archive_name"
REQ_SCRIPT_KB=1024

if [ "$language" = en ]; then
    MSG_CANCEL='Installation cancelled'
    MSG_INPUT='Enter choice'
    MSG_ALIAS='Please select an alias or enter a custom one:'
    MSG_ARCH='Detected architecture'
    MSG_TMP_FAIL='Not enough free space in /tmp to download release archive.'
    MSG_DOWN='Downloading installation package...'
    MSG_DOWN_FAIL='Failed to download installation package!'
    MSG_DIR_WARN='This package only installs ShellEasytier scripts. Runtime binaries will be downloaded on first start.'
    MSG_DIR_BAD='No write permission or not enough free space, please choose again!'
    MSG_CONFIRM='Confirm installation? (1/0) > '
    MSG_WEB='Current architecture supports easytier-web-embed. Install local web console component?'
    MSG_WEB_NO='Current architecture does not bundle easytier-web-embed. Local web menu will stay hidden.'
    MSG_BIN_STORE='Select runtime binary storage mode:'
    MSG_BIN_STORE_HINT='auto chooses based on free space; persistent keeps binaries under the install directory; tmp stores them under /tmp; custom lets you choose a base path.'
    MSG_BIN_STORE_PATH='Enter custom binary storage base path > '
    MSG_EXTRACT='Extracting selected files...'
    MSG_DONE='ShellEasytier installed successfully!'
    MSG_ALIAS_DONE='Use this command to manage ShellEasytier:'
    MSG_USER='Please use root when possible. Continue anyway? (1/0) > '
    MSG_PATH='Enter custom path > '
else
    MSG_CANCEL='安装已取消'
    MSG_INPUT='请输入相应数字'
    MSG_ALIAS='请选择一个别名，或使用自定义别名：'
    MSG_ARCH='检测到当前架构'
    MSG_TMP_FAIL='/tmp 可用空间不足，无法下载安装包。'
    MSG_DOWN='开始下载安装包...'
    MSG_DOWN_FAIL='安装包下载失败！'
    MSG_DIR_WARN='当前安装包只安装 ShellEasytier 脚本主体，运行时二进制会在首次启动时下载。'
    MSG_DIR_BAD='目录不可写或剩余空间不足，请重新选择！'
    MSG_CONFIRM='确认安装？(1/0) > '
    MSG_WEB='当前架构支持 easytier-web-embed，是否一并安装本地 Web 控制台组件？'
    MSG_WEB_NO='当前架构不包含 easytier-web-embed，本地 Web 菜单将自动隐藏。'
    MSG_BIN_STORE='请选择运行时二进制存放模式：'
    MSG_BIN_STORE_HINT='auto 按空间自动判断；persistent 固定保存在安装目录下；tmp 固定存放到 /tmp；custom 使用你指定的基础路径。'
    MSG_BIN_STORE_PATH='请输入自定义二进制基础路径 > '
    MSG_EXTRACT='开始解压所选文件...'
    MSG_DONE='ShellEasytier 已安装成功！'
    MSG_ALIAS_DONE='输入以下命令即可管理 ShellEasytier：'
    MSG_USER='请尽量使用 root 用户安装，仍要继续？(1/0) > '
    MSG_PATH='请输入自定义路径 > '
fi

cecho() {
    printf '%b\n' "$*"
}

dir_avail() {
    df -Pk "${1:-.}" 2>/dev/null | awk 'NR==2 {print $4}'
}

ckcmd() {
    if command -v sh >/dev/null 2>&1; then
        command -v "$1" >/dev/null 2>&1
    else
        type "$1" >/dev/null 2>&1
    fi
}

webget() {
    if ckcmd curl; then
        curl -kfsSL "$2" -o "$1"
    elif ckcmd wget; then
        wget --no-check-certificate -qO "$1" "$2"
    else
        return 1
    fi
}

remote_size_kb() {
    if ckcmd curl; then
        curl -kfsSI "$1" | awk '/[Cc]ontent-[Ll]ength:/ {print int($2/1024); exit}' | tr -d '\r'
    elif ckcmd wget; then
        wget --server-response --spider --no-check-certificate "$1" 2>&1 | awk '/[Cc]ontent-[Ll]ength:/ {print int($2/1024); exit}' | tr -d '\r'
    fi
}

check_arch() {
    machine=$(uname -m 2>/dev/null)
    case "$machine" in
        x86_64|amd64) et_arch=x86_64 ;;
        aarch64|arm64) et_arch=aarch64 ;;
        armv7*|armv8l)
            if grep -qiE 'vfp|half|neon' /proc/cpuinfo 2>/dev/null; then
                et_arch=armv7hf
            else
                et_arch=armv7
            fi
            ;;
        armv6*|armv5*|arm)
            if grep -qiE 'vfp|half|neon' /proc/cpuinfo 2>/dev/null; then
                et_arch=armhf
            else
                et_arch=arm
            fi
            ;;
        mipsel*|mipsle*) et_arch=mipsel ;;
        mips*) et_arch=mips ;;
        riscv64) et_arch=riscv64 ;;
        loongarch64) et_arch=loongarch64 ;;
        *)
            cecho "\033[31mUnsupported architecture: $machine\033[0m"
            exit 1
            ;;
    esac
}

check_systype() {
    [ -f '/etc/storage/started_script.sh' ] && systype=Padavan
    [ -d '/jffs' ] && systype=asusrouter
    [ -f '/data/etc/crontabs/root' ] && systype=mi_snapshot
    [ -w '/var/mnt/cfg/firewall' ] && systype=ng_snapshot
}

check_user() {
    if [ "$USER" != root ] && [ -z "$systype" ]; then
        read -r -p "$MSG_USER" res
        [ "$res" = 1 ] || exit 1
    fi
}

find_existing_installs() {
    EXISTING_INSTALLS=''
    for path in \
        /etc/ShellEasytier \
        /usr/share/ShellEasytier \
        "$HOME/.local/share/ShellEasytier" \
        /etc/storage/ShellEasytier \
        /jffs/ShellEasytier \
        /data/ShellEasytier \
        /userdisk/ShellEasytier \
        /data/other_vol/ShellEasytier
    do
        [ -d "$path" ] || continue
        [ -f "$path/scripts/start.sh" ] || continue
        EXISTING_INSTALLS="$EXISTING_INSTALLS\n$path"
    done
}

choose_existing_install() {
    find_existing_installs
    [ -n "$EXISTING_INSTALLS" ] || return 1

    while true; do
        echo '-----------------------------------------------'
        cecho '检测到已有 ShellEasytier 安装，是否执行升级安装？ / Existing ShellEasytier install detected.'
        echo '-----------------------------------------------'
        i=1
        printf '%b\n' "$EXISTING_INSTALLS" | sed '/^$/d' | while IFS= read -r path; do
            cecho " $i $path"
            i=$((i + 1))
        done
        cecho ' 0 Fresh install / 全新安装'
        echo '-----------------------------------------------'
        read -r -p "$MSG_INPUT > " num
        [ -z "$num" ] && num=0
        [ "$num" = 0 ] && return 1

        APPDIR=$(printf '%b\n' "$EXISTING_INSTALLS" | sed '/^$/d' | sed -n "${num}p")
        [ -n "$APPDIR" ] || continue
        upgrade_install=1
        [ -f "$APPDIR/configs/ShellEasytier.cfg" ] && . "$APPDIR/configs/ShellEasytier.cfg" 2>/dev/null
        [ -z "$need_kb" ] && need_kb=$REQ_SCRIPT_KB
        return 0
    done
}

arch_has_web_embed() {
    case "$et_arch" in
        x86_64|aarch64|arm|armhf|armv7|armv7hf)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

set_alias() {
    while true; do
        echo '-----------------------------------------------'
        cecho "$MSG_ALIAS"
        echo '-----------------------------------------------'
        cecho ' 1 【et】'
        cecho ' 2 【easytier】'
        cecho ' 3 【se】'
        cecho ' 0 Exit / 退出安装'
        echo '-----------------------------------------------'
        read -r -p "$MSG_INPUT > " res
        case "$res" in
            0) echo "$MSG_CANCEL"; exit 1 ;;
            1) my_alias=et ;;
            2) my_alias=easytier ;;
            3) my_alias=se ;;
            *) my_alias=$res ;;
        esac
        [ -n "$my_alias" ] || continue
        if command -v "$my_alias" >/dev/null 2>&1; then
            cecho "\033[33mAlias already exists, choose another one. / 别名已存在，请更换。\033[0m"
            sleep 1
            continue
        fi
        break
    done
}

set_usb_dir() {
    while true; do
        du -hL /mnt 2>/dev/null | awk '{print " "NR" "$2"  "$1}'
        read -r -p "$MSG_INPUT > " num
        dir=$(du -hL /mnt 2>/dev/null | awk '{print $2}' | sed -n "${num}p")
        [ -n "$dir" ] && break
    done
}

set_xiaomi_dir() {
    echo '-----------------------------------------------'
    [ -d /data ] && cecho " 1 /data ($(dir_avail /data) KB free)"
    [ -d /userdisk ] && cecho " 2 /userdisk ($(dir_avail /userdisk) KB free)"
    [ -d /data/other_vol ] && cecho " 3 /data/other_vol ($(dir_avail /data/other_vol) KB free)"
    cecho ' 4 Custom / 自定义路径'
    cecho ' 0 Exit / 退出安装'
    echo '-----------------------------------------------'
    read -r -p "$MSG_INPUT > " num
    case "$num" in
        1) dir=/data ;;
        2) dir=/userdisk ;;
        3) dir=/data/other_vol ;;
        4) set_cust_dir ;;
        *) exit 1 ;;
    esac
}

set_cust_dir() {
    while true; do
        echo '-----------------------------------------------'
        df -h 2>/dev/null | awk '{print $6,$4}' | sed 1d
        read -r -p "$MSG_PATH" dir
        [ -n "$dir" ] || continue
        break
    done
}

setdir() {
    while true; do
        echo '-----------------------------------------------'
        cecho "$MSG_DIR_WARN"
        case "$systype" in
            Padavan)
                dir=/etc/storage
                ;;
            mi_snapshot)
                set_xiaomi_dir
                ;;
            asusrouter)
                dir=/jffs
                ;;
            ng_snapshot)
                dir=/tmp/mnt
                ;;
            *)
                cecho ' 1 /etc'
                cecho ' 2 /usr/share'
                cecho ' 3 ~/.local/share'
                cecho ' 4 /mnt (external storage)'
                cecho ' 5 Custom / 自定义路径'
                cecho ' 0 Exit / 退出安装'
                echo '-----------------------------------------------'
                read -r -p "$MSG_INPUT > " num
                case "$num" in
                    1) dir=/etc ;;
                    2) dir=/usr/share ;;
                    3) dir=$HOME/.local/share ;;
                    4) set_usb_dir ;;
                    5) set_cust_dir ;;
                    *) echo "$MSG_CANCEL"; exit 1 ;;
                esac
                ;;
        esac

        free_kb=$(dir_avail "$dir")
        [ -w "$dir" ] || { cecho "\033[31m$MSG_DIR_BAD\033[0m"; sleep 1; continue; }
        [ -n "$free_kb" ] || free_kb=0
        [ "$free_kb" -ge "$need_kb" ] || { cecho "\033[31m$MSG_DIR_BAD\033[0m"; sleep 1; continue; }
        read -r -p "$MSG_CONFIRM" res
        if [ "$res" = 1 ]; then
            APPDIR="$dir/ShellEasytier"
            break
        fi
    done
}

check_tmp_space() {
    size_kb=$(remote_size_kb "$archive_url")
    [ -n "$size_kb" ] || return 0
    tmp_free=$(dir_avail /tmp)
    [ -n "$tmp_free" ] || tmp_free=0
    [ "$tmp_free" -ge $((size_kb + 8192)) ] || {
        cecho "\033[31m$MSG_TMP_FAIL\033[0m"
        exit 1
    }
}

choose_web_install() {
    install_web=OFF
    need_kb=$REQ_SCRIPT_KB
    if arch_has_web_embed; then
        cecho "$MSG_WEB"
        read -r -p '(1/0) > ' res
        if [ "$res" = 1 ]; then
            install_web=ON
        fi
    else
        cecho "$MSG_WEB_NO"
    fi
}

choose_binary_storage() {
    while true; do
        echo '-----------------------------------------------'
        cecho "$MSG_BIN_STORE"
        cecho "$MSG_BIN_STORE_HINT"
        [ -n "$binary_storage_mode" ] && cecho "Current / 当前: ${binary_storage_mode}${binary_storage_path:+ ($binary_storage_path)}"
        echo '-----------------------------------------------'
        cecho ' 1 auto'
        cecho ' 2 persistent'
        cecho ' 3 tmp'
        cecho ' 4 custom'
        cecho ' 0 Exit / 退出安装'
        echo '-----------------------------------------------'
        read -r -p "$MSG_INPUT > " num
        case "$num" in
            0)
                echo "$MSG_CANCEL"
                exit 1
                ;;
            1)
                binary_storage_mode=auto
                binary_storage_path=''
                return 0
                ;;
            2)
                binary_storage_mode=persistent
                binary_storage_path=''
                return 0
                ;;
            3)
                binary_storage_mode=tmp
                binary_storage_path=''
                return 0
                ;;
            4)
                binary_storage_mode=custom
                read -r -p "$MSG_BIN_STORE_PATH" binary_storage_path
                [ -n "$binary_storage_path" ] && return 0
                ;;
            *)
                ;;
        esac
    done
}

extract_project() {
    [ -d "$APPDIR" ] && "$APPDIR/start.sh" stop >/dev/null 2>&1
    mkdir -p "$(dirname "$APPDIR")"
    rm -rf "$APPDIR/scripts" "$APPDIR/menu.sh" "$APPDIR/start.sh" "$APPDIR/init.sh" "$APPDIR/version" "$APPDIR/pkg" "$APPDIR/public"

    echo '-----------------------------------------------'
    echo "$MSG_EXTRACT"
    tar -zxf "$archive_path" -C "$(dirname "$APPDIR")" || exit 1
}

install_main() {
    check_systype
    check_user
    check_arch
    cecho "$MSG_ARCH: \033[32m$et_arch\033[0m"

    check_tmp_space

    archive_path=/tmp/ShellEasytier.tar.gz
    echo '-----------------------------------------------'
    echo "$MSG_DOWN"
    webget "$archive_path" "$archive_url" || {
        cecho "\033[31m$MSG_DOWN_FAIL\033[0m"
        exit 1
    }

    if choose_existing_install; then
        choose_web_install
        choose_binary_storage
    else
        choose_web_install
        choose_binary_storage
        setdir
        set_alias
    fi

    extract_project

    export APPDIR url language my_alias install_web binary_storage_mode binary_storage_path
    . "$APPDIR/init.sh" >/dev/null 2>&1

    echo '-----------------------------------------------'
    echo "$MSG_DONE"
    cecho "$MSG_ALIAS_DONE \033[30;47m ${my_alias:-et} \033[0m"
    echo '-----------------------------------------------'
}

install_main
