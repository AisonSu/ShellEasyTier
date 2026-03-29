#!/bin/sh

[ -z "$APPDIR" ] && APPDIR=$(
    cd "$(dirname "$0")/../.."
    pwd
)
export APPDIR

. "$APPDIR/scripts/libs/get_config.sh"
. "$APPDIR/scripts/libs/logger.sh"
. "$APPDIR/scripts/libs/start_wait.sh"
. "$APPDIR/scripts/libs/compatibility.sh"

if start_wait; then
    if ! compat_post_start; then
        logger '防火墙/兼容规则应用失败，请检查兼容配置。' 33
    fi
    logger 'ShellEasytier 服务已启动。' 32
    exit 0
fi

logger 'ShellEasytier 服务启动超时。' 31
"$APPDIR/scripts/starts/start_error.sh"
exit 1
