extends Node2D
## The immunity's look (status_cc_immune.tres; COMBAT.md, Status effects;
## ENEMIES_AI AI-D3): a pale ring at the unit's feet, pulsing, the same on
## every unit, so the player sees a crowd control would be wasted. It's a
## floor drawing (the 3D view lays it on the floor, as the hover ring), not
## an icon over a head. Visuals only; the StatusComponent adds and frees it.

## The ring's radius, × the unit's gameplay radius (the hover ring is × 1).
@export var radius_scale: float = 1.35
@export var width: float = 2.0
@export var color: Color = Color(0.75, 0.92, 1.0, 0.9)
## Pulses a second.
@export var pulse_rate: float = 1.5

var _age := 0.0


func _ready() -> void:
	visibility_layer |= FloorOverlay.DRAWING_VISIBILITY_BIT


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func _draw() -> void:
	var unit := get_parent() as Unit
	if unit == null:
		return
	var r := unit.get_gameplay_radius_px() * radius_scale
	var pulse := 0.65 + 0.35 * sin(_age * TAU * pulse_rate)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, VFX.floor_squash))   # a true circle in 3D
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(color, color.a * pulse), width)
	draw_arc(Vector2.ZERO, r - width * 1.5, 0.0, TAU, 40, Color(color, color.a * pulse * 0.35), width * 0.5)
