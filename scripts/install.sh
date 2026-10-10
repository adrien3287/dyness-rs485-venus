#!/bin/sh
set -eu
REPO=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PORT=/dev/ttyAMA0
if [ "$#" -gt 0 ]; then
  [ "$#" -eq 2 ] && [ "$1" = '--port' ] || { echo 'Usage: sh scripts/install.sh [--port /dev/ttyUSB0]' >&2; exit 2; }
  PORT=$2
fi
[ -f "$REPO/snapshot/data/apps/dbus-serialbattery/bms/dyness_powerhaus.py" ] || { echo 'Snapshot incomplete'; exit 1; }
[ -d /data/apps ] || { echo 'Not a Venus OS /data/apps system'; exit 1; }
case "$PORT" in /dev/ttyUSB[0-9]*|/dev/ttyACM[0-9]*|/dev/ttyAMA[0-9]*|/dev/ttyS[0-9]*) ;; *) echo "Unsupported port: $PORT" >&2; exit 2;; esac
TTY=${PORT#/dev/}
case "$TTY" in *[!a-zA-Z0-9]*|'') echo 'Invalid serial port' >&2; exit 2;; esac
for name in dbus-serialbattery dyness_powerhaus_v0_2 DynessDetails; do
  src="$REPO/snapshot/data/apps/$name"
  dst="/data/apps/$name"
  [ -d "$src" ] || { echo "Missing $src"; exit 1; }
  if [ -e "$dst" ]; then
    echo "EXISTING: $dst. Refusing to overwrite." >&2
    exit 1
  fi
done
for name in dbus-serialbattery dyness_powerhaus_v0_2 DynessDetails; do
  cp -a "$REPO/snapshot/data/apps/$name" "/data/apps/$name"
done
sh "$REPO/scripts/configure-port.sh" "$PORT"
mkdir -p /data/apps/available/SerialbatteryGui/gui-v2 /data/apps/enabled
cp "$REPO/snapshot/data/apps/available/SerialbatteryGui/gui-v2/SerialbatteryGui.json" /data/apps/available/SerialbatteryGui/gui-v2/SerialbatteryGui.json
printf '%s\n' "Installed with serial port $PORT. CAN, UART, rc.local and services NOT modified." 'Check the controlling CAN BMS, then run scripts/activate.sh.'
