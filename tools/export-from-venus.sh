#!/bin/sh
# Export read-only snapshot of a functioning Dyness RS485/Venus OS installation.
# No services are restarted, no CAN/DVCC settings are changed.
set -eu
STAMP=$(date '+%Y%m%d-%H%M%S')
OUT="/data/dyness-venus-export-$STAMP.tar.gz"
TMP=$(mktemp -d /data/.dyness-export.XXXXXX)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/apps" "$TMP/system"
: > "$TMP/MISSING.txt"

copy_file() {
    SRC="$1"
    DST="$TMP/$2"
    if [ -f "$SRC" ]; then
        mkdir -p "$(dirname "$DST")"
        cp -L "$SRC" "$DST"
    else
        printf '%s\n' "$SRC" >> "$TMP/MISSING.txt"
    fi
}

# Exact customized driver + relevant dbus-serialbattery startup files.
for NAME in \
    bms/dyness_powerhaus.py \
    bms/dyness_powerhaus_protocol.py \
    dbushelper.py \
    battery.py \
    start-serialbattery.sh \
    enable.sh
do
    copy_file "/data/apps/dbus-serialbattery/$NAME" \
              "apps/dbus-serialbattery/$NAME"
done

# Capture only source-like assets from Dyness aggregator and GUI applications.
# No log files, runtime state, caches, old .before_* backups, SSH keys, etc.
for APP in dyness_powerhaus_v0_2 DynessDetails; do
    DIR="/data/apps/$APP"
    if [ -d "$DIR" ]; then
        find "$DIR" -type f | while IFS= read -r FILE; do
            case "$FILE" in
                *.py|*.sh|*.qml|*.json|*.ini|*.txt|*.md|*/run)
                    REL=$(printf '%s\n' "$FILE" | sed 's#^/data/apps/##')
                    copy_file "$FILE" "apps/$REL"
                    ;;
            esac
        done
    else
        printf '%s\n' "$DIR" >> "$TMP/MISSING.txt"
    fi
done

# Snapshot the GUIv2 plugin known to work on this Venus release.
copy_file /data/apps/available/SerialbatteryGui/gui-v2/SerialbatteryGui.json \
          apps/SerialbatteryGui/gui-v2/SerialbatteryGui.json

# Copy the actual run scripts of the active services (symlinks followed).
for NAME in dbus-serialbattery.ttyAMA0 dbus-dynesspowerhaus-bank; do
    copy_file "/service/$NAME/run" "system/services/$NAME/run"
done

# Keep a sanitized example of runtime config; do not copy credentials.
python3 - "$TMP" <<'PY'
import pathlib, re, sys
out = pathlib.Path(sys.argv[1]) / 'apps/dbus-serialbattery/config.ini.REVIEW'
inp = pathlib.Path('/data/apps/dbus-serialbattery/config.ini')
if inp.is_file():
    out.parent.mkdir(parents=True, exist_ok=True)
    lines = []
    for line in inp.read_text(errors='replace').splitlines():
        if '=' in line and not line.lstrip().startswith(('#', ';')):
            k, v = line.split('=', 1)
            if re.search(r'pass(word|phrase)?|secret|token|api.?key|private|credential|mqtt|wifi|wlan', k, re.I):
                line = k + '= <REDACTED>'
        lines.append(line)
    out.write_text('\n'.join(lines) + '\n')
PY

# Capture only boot-related lines rather than complete host configuration.
if [ -f /u-boot/config.txt ]; then
    grep -Ei 'enable_uart|dtoverlay.*(mcp2515|miniuart|spi)|dtparam.*spi' \
        /u-boot/config.txt > "$TMP/system/uart-can-boot-lines.txt" || true
fi
if [ -f /etc/inittab ]; then
    grep -E 'ttyAMA0|ttyS0' /etc/inittab \
        > "$TMP/system/uart-inittab-lines.txt" || true
fi
if [ -f /data/rc.local ]; then
    grep -E 'dbus-serialbattery|dyness_powerhaus' /data/rc.local \
        > "$TMP/system/rc-local-dyness-lines.txt" || true
fi
{
    printf 'Snapshot: %s\n' "$STAMP"
    printf 'Venus OS:\n'
    sed -n '1,3p' /opt/victronenergy/version 2>/dev/null || true
    printf 'Hardware: Raspberry Pi + Waveshare RS485/CAN HAT\n'
    printf 'Actual CAN control and RS485 read-only supervision must be preserved.\n'
    printf 'Do not publish this archive without checking for secrets.\n'
} > "$TMP/EXPORT_INFO.txt"

(cd "$TMP" && find . -type f ! -name SHA256SUMS -exec sha256sum {} \; > SHA256SUMS)
tar -czf "$OUT" -C "$TMP" .
printf 'EXPORTED: %s\n' "$OUT"
printf 'FILES: %s\n' "$(find "$TMP" -type f | wc -l | tr -d ' ')"
printf 'NOTE: review the archive before any public GitHub publication.\n'
