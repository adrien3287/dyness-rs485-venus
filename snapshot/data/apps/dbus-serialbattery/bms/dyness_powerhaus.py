# -*- coding: utf-8 -*-
"""Experimental Dyness PowerHaus RS485 driver for mr-manuel/dbus-serialbattery.

IMPORTANT: v0.1 is MONITOR-ONLY. DVCC current limits intentionally publish 0 A
until alarm handling, loss-of-communication and global limits are validated on
real hardware. Do not select this driver as Controlling BMS in Venus OS.
Two addresses 0x02/0x03 yield TWO parallel 16S module instances; use a
separate aggregator for battery-bank totals, never interpret them as 32S.
"""
import time

import serial
from battery import Battery, Cell
from utils import logger
from bms.dyness_powerhaus_protocol import (
    DynessProtocolError, make_request, parse_frame,
    module_42, module_44_basic, limits_92,
    global_61, global_62, limits_63,
)


class DynessPowerHaus(Battery):
    BATTERYTYPE = "Dyness PowerHaus RS485 EXPERIMENTAL"

    def __init__(self, port, baud, address):
        super().__init__(port, baud, address)
        self.type = self.BATTERYTYPE
        self.address_int = address[0] if isinstance(address, (bytes, bytearray)) and address else 2
        if self.address_int not in (2, 3):
            raise ValueError("PowerHaus tested addresses: 0x02 and 0x03 only")
        self.poll_interval = 6000
        self.cell_count = 16
        self.cells = [Cell(None) for _ in range(16)]
        self.capacity = None
        self.history.exclude_values_to_calculate = ["charge_cycles"]
        self.calculated_cell_16_mv = None
        self.measured_cells_mv = []
        self.raw_limits = None
        self.raw_alarm_payload = None
        self.raw_management_flags = None
        self.global_snapshot = None
        self.global_limits = None
        self.hardware_version = "PowerHaus RS485 addr %02X" % self.address_int

    def unique_identifier(self):
        # Without a hardware serial number, the address distinguishes both modules.
        return "DynessPowerHaus-RS485-%02X" % self.address_int

    def custom_name(self):
        return "PowerHaus RS485 %02X" % self.address_int

    def test_connection(self):
        try:
            return self.get_settings() and self.refresh_data()
        except (serial.SerialException, OSError, DynessProtocolError, ValueError) as exc:
            logger.warning("Dyness 0x%02X: detection failed: %s", self.address_int, exc)
            return False

    def get_settings(self):
        # Cell count is 16 series cells per physical module. The 16th is derived.
        self.cell_count = 16
        self.max_battery_voltage = 56.5
        self.min_battery_voltage = 48.0
        return True

    def _query(self, ser, cmd, info):
        tx = make_request(self.address_int, cmd, info)
        ser.reset_input_buffer()
        ser.write(tx)
        ser.flush()
        deadline = time.monotonic() + 1.6
        buf = bytearray()
        while time.monotonic() < deadline:
            data = ser.read(1)
            if not data:
                continue
            if data == b"~":
                buf = bytearray(b"~")
            elif buf:
                buf.extend(data)
                if data == b"\r":
                    return parse_frame(bytes(buf), self.address_int, cmd)
            if len(buf) > 1024:
                raise DynessProtocolError("Oversize response")
        raise DynessProtocolError("RS485 timeout for 0x%02X" % cmd)

    def refresh_data(self):
        # No partial updates: all reads are parsed and verified before publishing.
        try:
            with serial.Serial(self.port, baudrate=self.baud_rate or 9600,
                               bytesize=8, parity="N", stopbits=1,
                               timeout=0.12, write_timeout=1) as ser:
                info = bytes([self.address_int])
                analog = module_42(self._query(ser, 0x42, info))
                alarm44 = module_44_basic(self._query(ser, 0x44, info))
                frame92 = self._query(ser, 0x92, info)
                limits = limits_92(frame92)
                global_snapshot = None
                global_limits = None
                if self.address_int == 2:
                    global_snapshot = global_61(self._query(ser, 0x61, b""))
                    global_62(self._query(ser, 0x62, b""))
                    global_limits = limits_63(self._query(ser, 0x63, b""))

            self.voltage = analog.pack_mv / 1000
            self.current = analog.current_a
            self.capacity = analog.capacity_ah
            self.capacity_remain = analog.remaining_ah
            self.soc = analog.soc
            self.history.charge_cycles = analog.cycles
            self.calculated_cell_16_mv = analog.cell16_mv
            self.measured_cells_mv = list(analog.cells_mv)
            for i, val in enumerate(analog.cells_16_mv):
                self.cells[i].voltage = val / 1000
            for i in range(1, 5):
                setattr(self, "temperature_%d" % i,
                        analog.temperatures_c[i-1] if len(analog.temperatures_c) >= i else None)
            self.charge_fet = limits.can_charge
            self.discharge_fet = limits.can_discharge
            self.raw_limits = limits
            self.raw_alarm_payload = alarm44
            self.raw_management_flags = frame92.payload[9]
            self.global_snapshot = global_snapshot
            self.global_limits = global_limits
            self.max_battery_voltage = limits.cvl_v
            self.min_battery_voltage = limits.dvl_v

            # Explicitly prevent this development build becoming a charging
            # controller. Monitor-only until end-to-end fail-safe testing.
            self.max_battery_charge_current = 0.0
            self.max_battery_discharge_current = 0.0
            self.control_charge_current = 0.0
            self.control_discharge_current = 0.0
            return True
        except (serial.SerialException, OSError, DynessProtocolError, ValueError, IndexError) as exc:
            logger.error("Dyness PowerHaus %02X: data refresh rejected: %s", self.address_int, exc)
            # Don't return previously cached values as if fresh.
            self.control_charge_current = 0.0
            self.control_discharge_current = 0.0
            return False
