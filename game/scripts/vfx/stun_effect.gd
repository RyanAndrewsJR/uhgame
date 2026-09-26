extends Node2D
## Stun status: locks the unit's movement and attacks while it exists, and
## draws little spinning stars over its head. Added by Unit.apply_stun().

var time_left: float = 0.0
var _spin: float = 0.0
var _unit: Unit


func _ready() -> void:
	_unit = get_parent() as Unit
	z_index = 95
	_unit.movement.add_move_lock(&"stun")
	_unit.attack.add_lock(&"stun")


func extend(duration: float) -> void:
	time_left = maxf(time_left, duration)


func _physics_process(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		queue_free()


func _exit_tree() -> void:
	if is_instance_valid(_unit):
		_unit.movement.remove_move_lock(&"stun")
		_unit.attack.remove_lock(&"stun")


func _process(delta: float) -> void:
	_spin += delta * 6.0
	queue_redraw()


func _draw() -> void:
	for i in 3:
		var a := _spin + i * TAU / 3.0
		var p := Vector2(cos(a) * 9.0, sin(a) * 3.0)
		draw_circle(p, 2.0, Color(1, 0.9, 0.3))
