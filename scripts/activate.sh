#!/bin/sh
set -eu
[ -c /dev/ttyAMA0 ] || { echo 'ERROR /dev/ttyAMA0 missing; not activating' >&2; exit 1; }
[ -f /data/apps/dbus-serialbattery/bms/dyness_powerhaus.py ] || { echo 'Driver missing' >&2; exit 1; }
[ -d /service ] || { echo '/service missing' >&2; exit 1; }
# This check only looks for the known CAN service, not DVCC or complete CAN bus health.
dbus -y 2>/dev/null | grep -q 'com.victronenergy.battery.socketcan_can8' || {
 echo 'CAN can8 BMS service not detected: refusing to activate; check CAN first.' >&2; exit 1; }
# Serialbattery enable installs dependencies / service defaults. Run ONCE; it may stop serial services.
bash /data/apps/dbus-serialbattery/enable.sh
bash /data/apps/dyness_powerhaus_v0_2/startup.sh
mkdir -p /data/apps/available/DynessDetails/gui-v2 /data/apps/enabled
cp /data/apps/DynessDetails/DynessDetails.json /data/apps/available/DynessDetails/gui-v2/DynessDetails.json
ln -sfn /data/apps/available/DynessDetails /data/apps/enabled/DynessDetails
ln -sfn /data/apps/available/SerialbatteryGui /data/apps/enabled/SerialbatteryGui
[ ! -d /service/flashmq ] || svc -t /service/flashmq
printf '%s\n' 'RS485 supervision activated; verify with scripts/check.sh.'
