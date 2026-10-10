#!/bin/sh
set -eu
BASE=/data/apps/dyness_powerhaus_v0_2
. "$BASE/serial-port.conf"
case "$SERIAL_PORT" in /dev/ttyUSB[0-9]*|/dev/ttyACM[0-9]*|/dev/ttyAMA[0-9]*|/dev/ttyS[0-9]*) ;; *) echo "Invalid SERIAL_PORT: $SERIAL_PORT" >&2; exit 1;; esac
TTY=${SERIAL_PORT#/dev/}
[ -c "$SERIAL_PORT" ] || { echo "Serial device missing: $SERIAL_PORT" >&2; exit 1; }
[ -d /service ] || { echo '/service missing' >&2; exit 1; }
NAME="dbus-serialbattery.$TTY"
DIR="$BASE/services/$NAME"
mkdir -p "$DIR" "$BASE/services/dbus-dynesspowerhaus-bank"
cat > "$DIR/run" <<EOF
#!/bin/sh
exec 2>&1
exec bash /data/apps/dbus-serialbattery/start-serialbattery.sh "$TTY"
EOF
cat > "$BASE/services/dbus-dynesspowerhaus-bank/run" <<'EOF'
#!/bin/sh
exec 2>&1
cd /data/apps/dyness_powerhaus_v0_2
exec python3 -u aggregate_dbus.py
EOF
chmod 755 "$DIR/run" "$BASE/services/dbus-dynesspowerhaus-bank/run"
for S in "$NAME" dbus-dynesspowerhaus-bank; do
  [ -e "/service/$S" ] || ln -s "$BASE/services/$S" "/service/$S"
  svc -u "/service/$S"
done
echo "Dyness RS485 running on $SERIAL_PORT"
