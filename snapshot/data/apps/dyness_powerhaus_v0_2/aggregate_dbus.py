#!/usr/bin/env python3
"""Dyness dual PowerHaus read-only D-Bus aggregator with Node-RED-style TTE.

Requires 2 existing SerialBattery services; never touches ttyUSB2. This is
intentionally monitor-only, with 0-A DVCC control limits. Do not configure as
Controlling BMS until fail-safe tests and an armed version are validated.
"""
import logging
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, '/opt/victronenergy/dbus-systemcalc-py/ext/velib_python')
sys.path.insert(0, '/opt/victronenergy/velib_python')
from energy import time_estimates

import dbus
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib
from vedbus import VeDbusService

A = ('com.victronenergy.battery.ttyAMA0__0x02',
     'com.victronenergy.battery.ttyAMA0__0x03')
NAME = 'com.victronenergy.battery.dynesspowerhausbank'
SETTINGS = 'com.victronenergy.settings'
SYSTEM = 'com.victronenergy.system'
POLL_MS = 6000


def get(bus, service, path):
    try:
        item = bus.get_object(service, path, introspect=False)
        val = dbus.Interface(item, 'com.victronenergy.BusItem').GetValue(timeout=1)
        if isinstance(val, (tuple, list)) and len(val) == 0:
            return None
        return val
    except dbus.DBusException:
        return None


def numeric(bus, service, path):
    v = get(bus, service, path)
    try:
        v = float(v)
        return v if math.isfinite(v) else None
    except (TypeError, ValueError):
        return None


def ac_load(bus):
    # Preferred: Venus system calculated AC consumption on L1; if absent use
    # measured VE.Bus inverter output L1. Do not silently use PV/grid feed.
    p = numeric(bus, SYSTEM, '/Ac/Consumption/L1/Power')
    if p is not None:
        return p
    try:
        names = [str(n) for n in bus.list_names() if str(n).startswith('com.victronenergy.vebus.')]
    except dbus.DBusException:
        return None
    for name in names:
        p = numeric(bus, name, '/Ac/Out/L1/P')
        if p is not None:
            return p
    return None


class Bank:
    def __init__(self):
        self.bus = dbus.SystemBus()
        self.dbus = VeDbusService(NAME, bus=self.bus, register=False)
        self.dbus.add_mandatory_paths(__file__, 'v0.2', 'RS485 / two PowerHaus modules',
                                      40, 0xB510, 'Dyness PowerHaus bank (monitor only)',
                                      '0.2', '2x Dyness 5.12 kWh', 0)
        fields = {
            '/CustomName': 'Dyness PowerHaus 10.24 kWh',
            '/Dc/0/Voltage': None,
            '/Dc/0/Current': None,
            '/Dc/0/Power': None,
            '/Dc/0/Temperature': None,
            '/Soc': None,
            '/Soh': None,
            '/Capacity': None,
            '/InstalledCapacity': 200.0,
            '/ConsumedAmphours': None,
            '/TimeToGo': None,
            '/TimeToFull': None,
            '/Info/MaxChargeVoltage': None,
            '/Info/MaxChargeCurrent': 0.0,
            '/Info/MaxDischargeCurrent': 0.0,
            '/Info/BatteryLowVoltage': None,
            '/Io/AllowToCharge': 0,
            '/Io/AllowToDischarge': 0,
            '/Alarms/BmsCable': 0,
            '/Alarms/InternalFailure': 0,
            '/System/NrOfModulesOnline': 0,
            '/System/NrOfModulesOffline': 2,
            '/System/NrOfModulesBlockingCharge': 2,
            '/System/NrOfModulesBlockingDischarge': 2,
            '/Diagnostics/Mode': 'initializing',
            '/Diagnostics/TimeToGoSource': 'unavailable',
            '/Diagnostics/Module02Soc': None,
            '/Diagnostics/Module03Soc': None,
            '/Diagnostics/LastPoll': 0,
            '/Diagnostics/LastGoodPoll': 0,
            '/Diagnostics/LastInputError': '',
            '/Diagnostics/AcL1Power': None,
            '/Diagnostics/MinimumSocLimit': None,
        }
        for path, value in fields.items():
            self.dbus.add_path(path, value)
        self.dbus.register()

    def poll(self):
        self.dbus['/Diagnostics/LastPoll'] = GLib.get_monotonic_time() // 1000000
        try:
            return self._poll()
        except Exception:
            logging.exception('Aggregator poll rejected')
            self.offline('exception')
            return True

    def offline(self, why):
        with self.dbus as s:
            for path in ('/Dc/0/Voltage', '/Dc/0/Current', '/Dc/0/Power',
                         '/Dc/0/Temperature', '/Soc', '/Soh', '/ConsumedAmphours',
                         '/TimeToGo', '/TimeToFull', '/Diagnostics/Module02Soc',
                         '/Diagnostics/Module03Soc'):
                s[path] = None
            s['/Connected'] = 0
            s['/Alarms/BmsCable'] = 0
            s['/System/NrOfModulesOnline'] = 0
            s['/System/NrOfModulesOffline'] = 2
            s['/Diagnostics/Mode'] = why
            s['/Diagnostics/TimeToGoSource'] = 'unavailable'

    def _poll(self):
        modules = []
        for name in A:
            connected = numeric(self.bus, name, '/Connected')
            v = numeric(self.bus, name, '/Dc/0/Voltage')
            i = numeric(self.bus, name, '/Dc/0/Current')
            soc = numeric(self.bus, name, '/Soc')
            cap = numeric(self.bus, name, '/InstalledCapacity')
            # Retry connection status after reading other module values.
            if connected is None:
                connected = numeric(self.bus, name, '/Connected')
            # SerialBattery may publish /Capacity as either nominal or not;
            # check two 100-Ah modules before assigning a weighted SOC.
            if connected != 1 or None in (v, i, soc, cap):
                self.dbus['/Diagnostics/LastInputError'] = (
                    "%s C=%s V=%s I=%s SOC=%s CAP=%s"
                    % (name[-4:], connected, v, i, soc, cap)
                )
                self.offline('module-offline')
                return True
            if not (45 <= v <= 59 and -250 <= i <= 250 and 0 <= soc <= 100 and 95 <= cap <= 105):
                self.offline('module-range-invalid')
                return True
            modules.append((v, i, soc, cap))
        if abs(modules[0][0] - modules[1][0]) > 0.8:
            self.offline('voltage-mismatch')
            return True
        # SOH global from Dyness 0x61, decoded by the master.
        soh = numeric(self.bus, A[0], '/Diagnostics/GlobalSoh')
        total_ah = sum(x[3] for x in modules)
        soc = sum(x[2] * x[3] for x in modules) / total_ah
        v = sum(x[0] * x[3] for x in modules) / total_ah
        i = sum(x[1] for x in modules)
        power = sum(x[0] * x[1] for x in modules)
        min_soc = numeric(self.bus, SETTINGS, '/Settings/CGwacs/BatteryLife/MinimumSocLimit')
        acl1 = ac_load(self.bus)
        tte, ttf, mode = time_estimates(soc, v, power, acl1, min_soc, total_ah)
        with self.dbus as s:
            s['/Connected'] = 1
            s['/Diagnostics/LastGoodPoll'] = GLib.get_monotonic_time() // 1000000
            s['/Diagnostics/LastInputError'] = ''
            s['/Dc/0/Voltage'] = round(v, 3)
            s['/Dc/0/Current'] = round(i, 3)
            s['/Dc/0/Power'] = round(power, 2)
            s['/Soc'] = round(soc, 2)
            s['/Soh'] = round(soh, 1) if soh is not None else None
            s['/Capacity'] = round(total_ah * soc / 100, 3)
            s['/InstalledCapacity'] = round(total_ah, 1)
            s['/ConsumedAmphours'] = -round(total_ah * (100 - soc)/100, 3)
            s['/TimeToGo'] = tte
            s['/TimeToFull'] = ttf
            s['/System/NrOfModulesOnline'] = 2
            s['/System/NrOfModulesOffline'] = 0
            s['/Alarms/BmsCable'] = 0
            s['/Diagnostics/Mode'] = 'monitor-only'
            s['/Diagnostics/TimeToGoSource'] = mode
            s['/Diagnostics/MinimumSocLimit'] = min_soc
            s['/Diagnostics/AcL1Power'] = acl1
            s['/Diagnostics/Module02Soc'] = modules[0][2]
            s['/Diagnostics/Module03Soc'] = modules[1][2]
        return True


def main():
    logging.basicConfig(level=logging.INFO)
    DBusGMainLoop(set_as_default=True)
    bank = Bank()
    GLib.timeout_add(POLL_MS, bank.poll)
    bank.poll()
    GLib.MainLoop().run()


if __name__ == '__main__':
    main()
