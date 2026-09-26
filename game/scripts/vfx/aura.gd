extends Node2D
## Pulsing ring drawn under a unit while a buff is active.

var color: Color = Color(1, 0.8, 0.3)
var is_active: Callable
var max_time: float = 10.0
var radius: float = 16.0

var _t: float = 0.0


func _ready() -> void:
	z_index = -1
	var unit := get_parent() as Unit
	if unit:
		radius = unit.get_gameplay_radius_px() * 0.8


func _process(delta: float) -> void:
	_t += delta
	if _t > max_time or (is_active.is_valid() and not is_active.call()):
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 10.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
	draw_arc(Vector2.ZERO, radius + pulse * 2.0, 0.0, TAU, 32, Color(color, 0.5 + pulse * 0.4), 2.0)
