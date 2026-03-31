#!/bin/sh

[ -z "$APPDIR" ] && APPDIR=$(
    cd "$(dirname "$0")/../.."
    pwd
)
export APPDIR

. "$APPDIR/scripts/libs/get_config.sh"
. "$APPDIR/scripts/libs/set_profile.sh"

profile=/etc/profile

if [ -f "/etc/storage/started_script.sh" ]; then
    i=1
    while [ ! -w /etc/profile ] && [ "$i" -lt 10 ]; do
        sleep 3
        i=$((i + 1))
    done
    [ -w /opt/etc/profile ] && profile=/opt/etc/profile
elif [ -d "/jffs" ]; then
    sleep 30
    [ -w /jffs/configs/profile.add ] && profile=/jffs/configs/profile.add
fi

[ -n "$profile" ] && [ -w "$profile" ] && set_profile "$profile"

if [ ! -f "$APPDIR/.start_error" ] && [ ! -f "$APPDIR/.dis_startup_core" ]; then
    "$APPDIR/start.sh" start
fi

if [ "$install_web" = ON ] && [ "$web_autostart" = ON ] && [ ! -f "$APPDIR/.start_error" ] && [ ! -f "$APPDIR/.dis_startup_web" ]; then
    "$APPDIR/start.sh" web-start
fi
