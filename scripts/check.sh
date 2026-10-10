#!/bin/sh
set -eu
printf '%s\n' '=== CAN BMS (control) ==='
dbus -y 2>/dev/null | grep 'com.victronenergy.battery.socketcan_can8' || true
printf '%s\n' '=== RS485 MODULES ==='
for id in 02 03; do
  b="com.victronenergy.battery.ttyAMA0__0x$id"
  echo "--- $id ---"
  for p in /Connected /Soc /Diagnostics/BmsChargeAllowed /Diagnostics/BmsDischargeAllowed /Diagnostics/BmsChargeMosOn /Diagnostics/BmsDischargeMosOn /Diagnostics/BmsFullyCharged /Alarms/BmsCable; do
    printf '%s = ' "$p"; dbus -y "$b" "$p" GetValue 2>/dev/null || echo unavailable
  done
done
printf '%s\n' '=== RS485 BANK ==='
b=com.victronenergy.battery.dynesspowerhausbank
for p in /Connected /Soc /Diagnostics/LastInputError; do
 printf '%s = ' "$p"; dbus -y "$b" "$p" GetValue 2>/dev/null || echo unavailable
done
printf '%s\n' '=== ACTIVE CONTROLLING BMS ==='
dbus -y com.victronenergy.system /ActiveBatteryService GetValue 2>/dev/null || echo unavailable
