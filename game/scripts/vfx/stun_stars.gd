extends Node2D
## The stun's VFX (status_stun.tres): little spinning stars over the unit's
## head. Visuals only; the StatusComponent adds and frees it. (The pre-C9
## StunEffect drew the same stars and also held the locks.)


var _spin: float = 0.0


func _ready() -> void:
	z_index = 95
	var unit := get_parent() as Unit
	if unit:
		position = unit.body_center + Vector2(0, -unit.get_gameplay_radius_px() * 0.9)


func _process(delta: float) -> void:
	_spin += delta * 6.0
	queue_redraw()


func _draw() -> void:
	for i in 3:
		var a := _spin + i * TAU / 3.0
		var p := Vector2(cos(a) * 9.0, sin(a) * 3.0)
		draw_circle(p, 2.0, Color(1, 0.9, 0.3))
