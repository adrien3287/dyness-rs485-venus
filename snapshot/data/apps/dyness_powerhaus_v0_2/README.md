# Dyness PowerHaus v0.2 — RS485 + bank aggregation + Time To Go

## Validated scope
- Tested Dyness address `0x02` + `0x03` through `/dev/ttyUSB2`, 9600 8N1.
- **16 cell values per module**, the 16th reconstructed from pack voltage and the first 15; displayed in ordinary Cell16 slot. The physical index remains an assumption, to be verified against cloud indexed telemetry. No safety decisions from reconstructed cell extrema.
- Module readouts: 0x42, 0x44, 0x92; group readouts from master: 0x61, 0x62, 0x63.
- BMS alarms other than the captured healthy frames are NOT exhaustively mapped; unknown alarm frames fail closed at the module driver.
- **Monitor-only**: 0 A advertised as control limits, aggregate has charge/discharge permission = 0. The 100 A/200 A global BMS figures have been decoded but MUST NOT be used yet as DVCC controlling limits. An active Controlling BMS selection could stop inverter operation. Never select this as controlling BMS.

## Time to Go based on prior Node-RED calculation
- Usable energy to **5 %** = `max(SOC - 5, 0) / 100 * 200 Ah * actual bank voltage` Wh.
- While **battery DC power < -10 W** and **SOC > ESS MinimumSocLimit**: `TimeToGo = energy / abs(battery DC power) * 3600` seconds.
- At/below ESS reserve and on charge/idle: use `abs(AC L1 power) * 1.10` instead. Source: `com.victronenergy.system /Ac/Consumption/L1/Power`, fallback VE.Bus `/Ac/Out/L1/P`.
- If consumed AC L1 power <=10 W, output invalid (`None`) rather than fabricated infinite autonomy.
- `/TimeToFull` = time to **95 %** SOC using DC charging power above 10 W; otherwise invalid.
- `/TimeToGo` D-Bus is in **seconds** (unlike the old Node-RED function input in minutes). Do not feed the old Node-RED virtual battery at the same time as this new bank if you want a single estimate.
- If `/Settings/CGwacs/BatteryLife/MinimumSocLimit` is unavailable, times are invalid until configured; no implicit threshold guessing.

## Install / upgrade (Venus OS)

Extract ZIP, copy project under `/data` or under your home directory. Existing SerialBattery v0.1 must already operate on 0x02 and 0x03 with correct cells.

```
cd /root/dyness_powerhaus_v0_2  # replace with actual extracted path
sh install.sh
```

Installer patches the registered driver without affecting other USB ports, makes a timestamped config backup, stops autodetection for ttyUSB2, then creates 2 supervised services under `/service` for **this boot**. Check:

```
svstat /service/dbus-serialbattery.ttyUSB2
svstat /service/dbus-dynesspowerhaus-bank
ls /var/log/dbus-*dyness* /var/log/dbus-serialbattery.ttyUSB2
# logs from /var/log/<service>/current, formatted by tai64nlocal
tail -n 50 /var/log/dbus-dynesspowerhaus-bank/current | tai64nlocal

dbus -y com.victronenergy.battery.dynesspowerhausbank /Soc GetValue
dbus -y com.victronenergy.battery.dynesspowerhausbank /TimeToGo GetValue
dbus -y com.victronenergy.battery.dynesspowerhausbank /TimeToFull GetValue
dbus -y com.victronenergy.battery.dynesspowerhausbank /Diagnostics/TimeToGoSource GetValue
```

**Important:** `/service` is ephemeral on Venus OS. We intentionally do NOT configure an automatic boot hook before reviewing actual service logs and safety behavior. There can also be a race with serial-starter on subsequent boots. Once tested, install a specific boot hook through a controlled next update.

## Rollback
```
svc -d /service/dbus-dynesspowerhaus-bank
svc -d /service/dbus-serialbattery.ttyUSB2
# restore config.ini from the timestamped config.ini.dyness-v02-* backup
# restore dbus-serialbattery.py from .dyness-backup only if desired;
# direct v0.1 registrations are compatible with this upgraded class.
```

The `dbus-dynesspowerhaus-bank` service aggregates **parallel** batteries (53 V, 200 Ah), not 32 serial cells. The 2 module services stay visible. Bank D-Bus default instance = 40; verify no other device already uses this instance before deciding on ESS/UI selection.
