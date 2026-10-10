#!/bin/sh
set -eu
REPO=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
[ -f "$REPO/snapshot/data/apps/dbus-serialbattery/bms/dyness_powerhaus.py" ] || { echo 'Snapshot incomplete'; exit 1; }
[ -d /data/apps ] || { echo 'Not a Venus OS /data/apps system'; exit 1; }
for name in dbus-serialbattery dyness_powerhaus_v0_2 DynessDetails; do
  src="$REPO/snapshot/data/apps/$name"
  dst="/data/apps/$name"
  [ -d "$src" ] || { echo "Missing $src"; exit 1; }
  if [ -e "$dst" ]; then
    echo "EXISTING: $dst. Refusing to overwrite. Use an empty Venus OS install or restore manually after backup." >&2
    exit 1
  fi
done
# Prepare directories and copy only after all checks above.
for name in dbus-serialbattery dyness_powerhaus_v0_2 DynessDetails; do
  cp -a "$REPO/snapshot/data/apps/$name" "/data/apps/$name"
done
mkdir -p /data/apps/available/SerialbatteryGui/gui-v2 /data/apps/enabled
cp "$REPO/snapshot/data/apps/available/SerialbatteryGui/gui-v2/SerialbatteryGui.json" /data/apps/available/SerialbatteryGui/gui-v2/SerialbatteryGui.json
printf '%s\n' 'Installed source files. CAN, UART, rc.local and services NOT modified.' 'Next: verify CAN controlling BMS and UART RS485, then run scripts/activate.sh.'
