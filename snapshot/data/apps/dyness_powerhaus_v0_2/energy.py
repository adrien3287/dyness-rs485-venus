"""Dyness bank time calculations, isolated from DBus for unit testing.

Reproduces the previously agreed Node-RED behaviour:
- Time to Empty always to 5% SOC (not to ESS min SOC)
- If battery is discharging *above* MinimumSocLimit, use DC battery power
- Otherwise (charging/idle or at/below min SOC) use AC L1 load * 1.10
- <=10 W is ignored (no reliable time estimate)
- Time to Full uses DC charge power up to 95%.
Units: seconds, W, V, Ah, SOC percentage.
"""
import math

CAPACITY_AH = 200.0
FLOOR_SOC = 5.0
TARGET_FULL_SOC = 95.0
DEADBAND_W = 10.0
LOSS_FACTOR = 1.10


def _num(x):
    try:
        n = float(x)
        return n if math.isfinite(n) else None
    except (ValueError, TypeError):
        return None


def time_estimates(soc, voltage, dc_power, ac_l1_power, min_soc, capacity_ah=CAPACITY_AH):
    """Positive times in seconds; None when input/power is unavailable."""
    soc, voltage, dc_power, ac_l1_power, min_soc, capacity_ah = map(
        _num, (soc, voltage, dc_power, ac_l1_power, min_soc, capacity_ah)
    )
    if soc is None or voltage is None or dc_power is None or capacity_ah is None:
        return None, None, 'invalid-input'
    if not (0 <= soc <= 100 and 40 <= voltage <= 60 and capacity_ah > 0):
        return None, None, 'invalid-range'
    if min_soc is None or not (0 <= min_soc <= 100):
        return None, None, 'minimum-soc-unavailable'
    remaining_wh = max(soc - FLOOR_SOC, 0) / 100 * capacity_ah * voltage
    if soc <= FLOOR_SOC:
        to_empty = 0
        mode = 'floor-reached'
    elif dc_power < -DEADBAND_W and soc > min_soc:
        to_empty = int(round(remaining_wh / abs(dc_power) * 3600))
        mode = 'battery-discharge'
    else:
        # Earlier Node-RED fallback: forecast autonomy from load even when ESS
        # is holding the reserve; using DC charging power would be incorrect.
        if ac_l1_power is None or abs(ac_l1_power) <= DEADBAND_W:
            to_empty = None
            mode = 'ac-load-unavailable'
        else:
            to_empty = int(round(remaining_wh / (abs(ac_l1_power) * LOSS_FACTOR) * 3600))
            mode = 'ac-load-fallback'
    if soc >= TARGET_FULL_SOC:
        to_full = 0
    elif dc_power > DEADBAND_W:
        required_wh = (TARGET_FULL_SOC - soc) / 100 * capacity_ah * voltage
        to_full = int(round(required_wh / dc_power * 3600))
    else:
        to_full = None
    return to_empty, to_full, mode
