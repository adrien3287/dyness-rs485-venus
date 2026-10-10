#!/bin/bash
set -eu

BASE=/data/apps/dyness_powerhaus_v0_2
SERVICES="$BASE/services"

echo "[DYNESS] Starting RS485 supervision"

# Wait for the UART and runit service directory
for i in $(seq 1 30); do
    [ -c /dev/ttyAMA0 ] && [ -d /service ] && break
    sleep 2
done

if [ ! -c /dev/ttyAMA0 ]; then
    echo "[DYNESS] ERROR: ttyAMA0 unavailable"
    exit 1
fi

mkdir -p "$SERVICES/dbus-serialbattery.ttyAMA0"
mkdir -p "$SERVICES/dbus-dynesspowerhaus-bank"

# RS485 SerialBattery
cat > "$SERVICES/dbus-serialbattery.ttyAMA0/run" <<'RUN'
#!/bin/sh
exec 2>&1
exec bash /data/apps/dbus-serialbattery/start-serialbattery.sh ttyAMA0
RUN

# Dyness aggregation
cat > "$SERVICES/dbus-dynesspowerhaus-bank/run" <<'RUN'
#!/bin/sh
exec 2>&1
cd /data/apps/dyness_powerhaus_v0_2
exec python3 -u aggregate_dbus.py
RUN

chmod 755 "$SERVICES/dbus-serialbattery.ttyAMA0/run"
chmod 755 "$SERVICES/dbus-dynesspowerhaus-bank/run"

# Register services without creating duplicates
for NAME in dbus-serialbattery.ttyAMA0 dbus-dynesspowerhaus-bank; do
    if [ ! -e "/service/$NAME" ]; then
        ln -s "$SERVICES/$NAME" "/service/$NAME"
        echo "[DYNESS] Registered $NAME"
    else
        echo "[DYNESS] Already registered: $NAME"
    fi
done

# Allow services to start if previously disabled
svc -u /service/dbus-serialbattery.ttyAMA0
svc -u /service/dbus-dynesspowerhaus-bank

echo "[DYNESS] Startup completed"
