extends Node2D
## Staggered's VFX (status_staggered.tres, CHAMPIONS CH4): a pale yellow
## cracked ring over the unit's head, so the player sees who a Cleave will
## hit harder. Visuals only; the StatusComponent adds and frees it.

const COLOR := Color(1.0, 0.92, 0.55, 0.9)

var _time: float = 0.0


func _ready() -> void:
	z_index = 95
	var unit := get_parent() as Unit
	if unit:
		position = unit.body_center + Vector2(0, -unit.get_gameplay_radius_px() * 0.9 - 4.0)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 1.0 + 0.08 * sin(_time * 10.0)
	var r := 7.0 * pulse
	# Four arcs with gaps: a ring cracked in four places, flattened for the 3/4 view.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	for i in 4:
		var a := i * TAU / 4.0 + 0.25
		draw_arc(Vector2.ZERO, r, a, a + TAU / 4.0 - 0.5, 6, COLOR, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
