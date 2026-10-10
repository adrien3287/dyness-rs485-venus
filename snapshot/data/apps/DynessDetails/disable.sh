#!/bin/sh
set -eu
if [ -L /data/apps/enabled/DynessDetails ]; then rm /data/apps/enabled/DynessDetails; fi
if [ -d /service/flashmq ]; then svc -t /service/flashmq; fi
echo 'DynessDetails desactive ; plugin dbus-serialbattery conserve.'
