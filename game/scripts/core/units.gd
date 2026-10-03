class_name Units
## Converts League-of-Legends-style numbers (movement speed 345, attack
## range 550, etc.) into pixels, so champion stats can be written in the
## familiar units.
##
## At 0.32, a 345 MS champion crosses our 640 px screen in about 6 seconds,
## which is roughly how long crossing a LoL screen takes.
##
## It also holds the 3D view's one mapping (docs/3D.md): sim px <-> view
## meters, 1 m = 1 tile = 32 px = 100 LoL units. No other code multiplies or
## divides by 32.

const PX_PER_UNIT := 0.32
## The 3D view's scale: one meter is one tile (docs/3D.md, Goal / feel).
const PX_PER_METER := 32.0


static func to_px(units: float) -> float:
	return units * PX_PER_UNIT


static func to_units(px: float) -> float:
	return px / PX_PER_UNIT


static func px_to_m(px: float) -> float:
	return px / PX_PER_METER


static func m_to_px(m: float) -> float:
	return m * PX_PER_METER


## A sim point (px) as a view point (m): sim x -> view x, sim y -> view z,
## at `height_m` above the floor.
static func to_view(p: Vector2, height_m: float = 0.0) -> Vector3:
	return Vector3(p.x / PX_PER_METER, height_m, p.y / PX_PER_METER)


## A view point (m) as a sim point (px): view x -> sim x, view z -> sim y.
## The height is dropped: the sim never reads height.
static func to_sim(p: Vector3) -> Vector2:
	return Vector2(p.x * PX_PER_METER, p.z * PX_PER_METER)
