#!/bin/sh
set -eu
PORT=${1:-}
case "$PORT" in
 /dev/ttyUSB[0-9]*|/dev/ttyACM[0-9]*|/dev/ttyAMA[0-9]*|/dev/ttyS[0-9]*) ;;
 *) echo 'Usage: configure-port.sh /dev/ttyUSB0 (also ttyACM*, ttyAMA*, ttyS*)' >&2; exit 2 ;;
esac
# Permit only an ordinary numeric tty basename (never paths or shell metacharacters).
TTY=${PORT#/dev/}
case "$TTY" in *[!a-zA-Z0-9]*|'') echo 'Invalid device name' >&2; exit 2;; esac
case "$TTY" in ttyUSB*|ttyACM*|ttyAMA*|ttyS*) ;; *) exit 2;; esac
BASE=/data/apps/dyness_powerhaus_v0_2
[ -f "$BASE/aggregate_dbus.py" ] || { echo 'Install first' >&2; exit 1; }
if [ -f "$BASE/serial-port.conf" ]; then
  . "$BASE/serial-port.conf"
  OLD=${SERIAL_PORT#/dev/}
  if [ "$OLD" != "$TTY" ] && [ -e "/service/dbus-serialbattery.$OLD" ]; then
    echo "Old service /service/dbus-serialbattery.$OLD still registered; stop it and remove its service symlink before changing ports." >&2
    exit 1
  fi
fi
REPO=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SOURCE="$REPO/snapshot/data/apps/dyness_powerhaus_v0_2/aggregate_dbus.py"
[ -f "$SOURCE" ] || { echo 'Repository snapshot not found' >&2; exit 1; }
sed "s/ttyAMA0__0x/$TTY\_\_0x/g" "$SOURCE" > "$BASE/aggregate_dbus.py.new"
mv "$BASE/aggregate_dbus.py.new" "$BASE/aggregate_dbus.py"
printf 'SERIAL_PORT=%s\n' "$PORT" > "$BASE/serial-port.conf"
cp "$REPO/scripts/startup-port.sh" "$BASE/startup.sh"
chmod 755 "$BASE/startup.sh"
echo "Configured $PORT; run scripts/activate.sh to activate."
