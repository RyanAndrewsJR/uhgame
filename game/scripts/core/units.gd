class_name Units
## Converts League-of-Legends-style numbers (movement speed 345, attack
## range 550, etc.) into pixels, so champion stats can be written in the
## familiar units.
##
## At 0.32, a 345 MS champion crosses our 640 px screen in about 6 seconds,
## which is roughly how long crossing a LoL screen takes.

const PX_PER_UNIT := 0.32


static func to_px(units: float) -> float:
	return units * PX_PER_UNIT


static func to_units(px: float) -> float:
	return px / PX_PER_UNIT
