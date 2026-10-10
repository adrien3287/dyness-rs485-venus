"""Idempotent patch against a local dbus-serialbattery directory.

Usage: python3 register_driver.py /data/apps/dbus-serialbattery
This creates backups, registers the Dyness class, and copies driver files.
Run only after reviewing README and installing upstream SerialBattery.
"""
import pathlib
import shutil
import sys


def main():
    if len(sys.argv) != 2:
        sys.exit("Usage: python3 register_driver.py /data/apps/dbus-serialbattery")
    root = pathlib.Path(sys.argv[1]).resolve()
    script = root / "dbus-serialbattery.py"
    if not script.is_file() or not (root / "bms").is_dir():
        sys.exit("Not a dbus-serialbattery install directory")
    original = script.read_text()
    changed = original
    imp = "from bms.dyness_powerhaus import DynessPowerHaus\n"
    if imp not in changed:
        anchor = "from bms.daren_485 import Daren485\n"
        if anchor not in changed:
            sys.exit("Unknown upstream import layout; manual review required")
        changed = changed.replace(anchor, anchor + imp, 1)
    entry = '    {"bms": DynessPowerHaus, "baud": 9600, "address": b"\\x02"},\n'
    if entry not in changed:
        anchor = '    {"bms": Daren485, "baud": 9600, "address": b"\\x01"},\n'
        if anchor not in changed:
            sys.exit("Unknown upstream BMS list layout; manual review required")
        changed = changed.replace(anchor, anchor + entry, 1)
    if changed != original:
        backup = script.with_suffix(script.suffix + ".dyness-backup")
        if not backup.exists():
            shutil.copy2(script, backup)
        script.write_text(changed)
    for name in ("dyness_powerhaus.py", "dyness_powerhaus_protocol.py"):
        source = pathlib.Path(__file__).parent / "bms" / name
        target = root / "bms" / name
        shutil.copy2(source, target)
    print("Registered DynessPowerHaus (monitor-only); no services started.")
    print("Edit config.ini: BMS_TYPE = DynessPowerHaus")
    print("Edit config.ini: BATTERY_ADDRESSES = 0x02, 0x03")
    print("Do NOT select as Controlling BMS in v0.1.")


if __name__ == "__main__":
    main()
