#!/bin/sh
set -eu
F=/data/rc.local
[ -f "$F" ] || { echo '/data/rc.local missing; install hook manually' >&2; exit 1; }
# Never silently rewrite pre-existing hooks: the original system had duplicate enable.sh entries.
if grep -qE 'dbus-serialbattery/enable.sh|dyness_powerhaus_v0_2/startup.sh' "$F"; then
  echo 'Existing serialbattery/Dyness boot hook detected. Inspect /data/rc.local manually to avoid duplicates.' >&2
  exit 1
fi
cp -p "$F" "$F.before-dyness-rs485"
cat >> "$F" <<'HOOK'

# Dyness PowerHaus RS485 monitoring; CAN continues to be the controlling BMS.
( bash /data/apps/dbus-serialbattery/enable.sh > /data/apps/dbus-serialbattery/startup.log 2>&1; bash /data/apps/dyness_powerhaus_v0_2/startup.sh > /data/apps/dyness_powerhaus_v0_2/startup.log 2>&1 ) &
HOOK
printf '%s\n' 'Boot hook appended once; previous file in /data/rc.local.before-dyness-rs485.'
