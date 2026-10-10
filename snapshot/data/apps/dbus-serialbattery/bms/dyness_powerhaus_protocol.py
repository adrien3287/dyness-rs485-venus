"""Read-only Dyness PowerHaus RS485 protocol (observed on 2 x 5.12 kWh).

Only the following request commands are allowed: 0x42, 0x44, 0x92, 0x61,
0x62, 0x63. 0x42 on the observed firmware checksums *exclude* the last
six capacity bytes. These bytes are NOT checksum-protected and are validated
by separate plausibility checks.
"""

from dataclasses import dataclass
from typing import List, Optional

READ_COMMANDS = frozenset((0x42, 0x44, 0x92, 0x61, 0x62, 0x63))


class DynessProtocolError(ValueError):
    pass


@dataclass
class Frame:
    address: int
    code: int
    payload: bytes
    vendor_42_checksum: bool = False


def checksum_ascii(value):
    return (-sum(value)) & 0xFFFF


def make_request(address: int, command: int, info: bytes = b"") -> bytes:
    if not 2 <= address <= 0x0F or command not in READ_COMMANDS:
        raise DynessProtocolError("Address or read command not allowed")
    if command in (0x42, 0x44, 0x92):
        if info != bytes([address]):
            raise DynessProtocolError("This command requires matching one-byte INFO")
    elif info:
        raise DynessProtocolError("Unexpected INFO for a group read")
    size = len(info) * 2  # number of ASCII-hex characters
    nibble_sum = sum((size >> (4 * n)) & 0xF for n in range(3))
    lenid = (((-nibble_sum) & 0xF) << 12) | size
    body = (f"20{address:02X}46{command:02X}{lenid:04X}" + info.hex().upper()).encode("ascii")
    return b"~" + body + f"{checksum_ascii(body):04X}".encode("ascii") + b"\r"


def parse_frame(raw: bytes, expected_address: int, command: int) -> Frame:
    if not (raw.startswith(b"~") and raw.endswith(b"\r")):
        raise DynessProtocolError("Missing frame delimiters")
    try:
        text = raw[1:-1].decode("ascii")
        int(text, 16)
    except (UnicodeError, ValueError):
        raise DynessProtocolError("Frame contains non-hex characters")
    if len(text) < 16 or text[:2] != "20" or text[4:6] != "46":
        raise DynessProtocolError("Unsupported protocol/header")
    address = int(text[2:4], 16)
    if address != expected_address:
        raise DynessProtocolError("Incorrect response address")
    code = int(text[6:8], 16)
    lenid = int(text[8:12], 16)
    size = lenid & 0x0FFF
    nibble_sum = sum((size >> (4 * n)) & 0xF for n in range(3))
    if ((lenid >> 12) + nibble_sum) & 0x0F:
        raise DynessProtocolError("Invalid LENID nibble checksum")
    payload_ascii = text[12:-4]
    if size != len(payload_ascii) or size % 2:
        raise DynessProtocolError("Invalid payload size")
    expected = int(text[-4:], 16)
    checked = text[:-4].encode("ascii")
    vendor = False
    if expected != checksum_ascii(checked):
        if command != 0x42 or len(payload_ascii) < 12 or expected != checksum_ascii(checked[:-12]):
            raise DynessProtocolError("Response checksum mismatch")
        vendor = True
    if code != 0:
        raise DynessProtocolError(f"BMS returned error code 0x{code:02X}")
    return Frame(address, code, bytes.fromhex(payload_ascii), vendor)


@dataclass
class ModuleData:
    address: int
    cells_mv: List[int]
    cell16_mv: int
    pack_mv: int
    temperatures_c: List[float]
    current_a: float
    remaining_ah: Optional[float]
    capacity_ah: Optional[float]
    soc: Optional[float]
    cycles: int

    @property
    def cells_16_mv(self):
        # The physical index of the omitted measurement is not verified.
        # Expose as cell 16 as provisionally chosen by the owner.
        return self.cells_mv + [self.cell16_mv]


def module_42(frame: Frame) -> ModuleData:
    b = frame.payload
    p = 0

    def take(n):
        nonlocal p
        if p + n > len(b):
            raise DynessProtocolError("Truncated analog data")
        out = b[p:p+n]
        p += n
        return out

    flag = take(1)[0]
    address = take(1)[0]
    n = take(1)[0]
    if flag != 0 or address != frame.address or n != 15:
        raise DynessProtocolError("Unexpected module header or cell count")
    cells = [int.from_bytes(take(2), "big") for _ in range(n)]
    tempcount = take(1)[0]
    if not 1 <= tempcount <= 8:
        raise DynessProtocolError("Invalid number of thermistors")
    temps = [int.from_bytes(take(2), "big") / 10 - 273.15 for _ in range(tempcount)]
    current = int.from_bytes(take(2), "big", signed=True) / 10
    pack_mv = int.from_bytes(take(2), "big")
    _remaining_short = int.from_bytes(take(2), "big")
    _user_flag = take(1)[0]
    _capacity_short = int.from_bytes(take(2), "big")
    cycles = int.from_bytes(take(2), "big")
    rest = take(len(b)-p)
    if len(rest) != 6:
        raise DynessProtocolError("Expected 6-byte capacity extension")
    remaining_mAh = int.from_bytes(rest[:3], "big")
    total_mAh = int.from_bytes(rest[3:], "big")
    if not 10000 <= total_mAh <= 250000 or not 0 <= remaining_mAh <= total_mAh:
        raise DynessProtocolError("Implausible capacity extension")
    soc = remaining_mAh / total_mAh * 100
    cell16_mv = pack_mv - sum(cells)
    if not all(2200 <= x <= 3800 for x in cells) or not 2200 <= cell16_mv <= 3800:
        raise DynessProtocolError("Implausible cell voltage")
    if not 40000 <= pack_mv <= 60000 or not all(-40 <= t <= 90 for t in temps):
        raise DynessProtocolError("Implausible pack measurement")
    return ModuleData(address, cells, cell16_mv, pack_mv, temps, current,
                      remaining_mAh/1000, total_mAh/1000, soc, cycles)


@dataclass
class Limits:
    cvl_v: float
    dvl_v: float
    ccl_a: float
    dcl_a: float
    can_charge: bool
    can_discharge: bool


def limits_92(frame: Frame) -> Limits:
    b = frame.payload
    if len(b) != 10 or b[0] != frame.address:
        raise DynessProtocolError("Invalid module limits response")
    u16 = lambda i: int.from_bytes(b[i:i+2], "big")
    s16 = lambda i: int.from_bytes(b[i:i+2], "big", signed=True)
    cvl, dvl = u16(1)/1000, u16(3)/1000
    ccl, dcl = s16(5)/10, -s16(7)/10
    if not (50 <= cvl <= 59 and 40 <= dvl <= 53 and 0 <= ccl <= 150 and 0 <= dcl <= 200):
        raise DynessProtocolError("Implausible module limits")
    return Limits(cvl, dvl, ccl, dcl, bool(b[9] & 0x80), bool(b[9] & 0x40))


def limits_63(frame: Frame) -> Limits:
    b = frame.payload
    if len(b) != 9:
        raise DynessProtocolError("Invalid global limits response")
    u16 = lambda i: int.from_bytes(b[i:i+2], "big")
    s16 = lambda i: int.from_bytes(b[i:i+2], "big", signed=True)
    cvl, dvl = u16(0)/1000, u16(2)/1000
    ccl, dcl = s16(4)/10, -s16(6)/10
    if not (50 <= cvl <= 59 and 40 <= dvl <= 53 and 0 <= ccl <= 300 and 0 <= dcl <= 400):
        raise DynessProtocolError("Implausible global limits")
    return Limits(cvl, dvl, ccl, dcl, bool(b[8] & 0x80), bool(b[8] & 0x40))


def module_44_basic(frame: Frame) -> bytes:
    """Validate structure and preserve every alarm/status byte."""
    b = frame.payload
    if (len(b) != 32 or b[0] != 0
            or b[1] != frame.address
            or b[2] != 15 or b[18] != 5):
        raise DynessProtocolError("Unexpected alarm frame layout")
    return bytes(b)


def global_62(frame: Frame) -> None:
    if len(frame.payload) != 4 or frame.payload != b"\x00\x00\x00\x00":
        raise DynessProtocolError("Global BMS alarm / unknown flag")


def global_61(frame: Frame):
    b=frame.payload
    if len(b)!=49: raise DynessProtocolError("Invalid global snapshot")
    voltage=int.from_bytes(b[:2],"big")/1000
    soc=b[4]
    soh=b[9]
    max_cell=int.from_bytes(b[11:13],"big")
    min_cell=int.from_bytes(b[15:17],"big")
    if not (40<=voltage<=60 and 0<=soc<=100 and 0<=soh<=100 and 2000<=min_cell<=max_cell<=3800):
        raise DynessProtocolError("Invalid global values")
    return {"voltage_v":voltage,"soc_pct":soc,"soh_pct":soh,"min_cell_mv":min_cell,"max_cell_mv":max_cell}
