extends Node2D
## Pulsing ring drawn under a unit while a buff is active.
## Drawn on the floor but above the floor tiles: it's the unit's first child
## (so the unit's Body draws over it) at the default z_index. A negative
## z_index would put it under the TileMapLayer, where it never shows.

var color: Color = Color(1, 0.8, 0.3)
var is_active: Callable
var max_time: float = 10.0
var radius: float = 16.0

var _t: float = 0.0


func _ready() -> void:
	var unit := get_parent() as Unit
	if unit:
		radius = unit.get_gameplay_radius_px() * 0.8
		unit.move_child.call_deferred(self, 0)   # behind the Body, above the floor


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
