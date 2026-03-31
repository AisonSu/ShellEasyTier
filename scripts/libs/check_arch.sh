[ -n "$__IS_LIB_CHECK_ARCH" ] && return
__IS_LIB_CHECK_ARCH=1

check_et_arch() {
    machine=$(uname -m 2>/dev/null)
    et_arch=""

    case "$machine" in
        x86_64|amd64)
            et_arch="x86_64"
            ;;
        aarch64|arm64)
            et_arch="aarch64"
            ;;
        armv7*|armv8l)
            if grep -qiE 'vfp|half|neon' /proc/cpuinfo 2>/dev/null; then
                et_arch="armv7hf"
            else
                et_arch="armv7"
            fi
            ;;
        armv6*|armv5*|arm)
            if grep -qiE 'vfp|half|neon' /proc/cpuinfo 2>/dev/null; then
                et_arch="armhf"
            else
                et_arch="arm"
            fi
            ;;
        mipsel*|mipsle*)
            et_arch="mipsel"
            ;;
        mips*)
            et_arch="mips"
            ;;
    esac

    [ -n "$et_arch" ] || return 1
    export et_arch
    return 0
}
