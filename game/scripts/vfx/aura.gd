extends Node2D
## Pulsing ring drawn under a unit while a buff is active.
## Drawn on the floor but above the floor tiles: it's the unit's first child
## (so the unit's Body draws over it) at the default z_index. A negative
## z_index would put it under the TileMapLayer, where it never shows.

var color: Color = Color(1, 0.8, 0.3)
var is_active: Callable
var max_time: float = 10.0
var radius: float = 16.0

## Its 3D look (3D.md, The generic view mechanism; the aura is in the group
## view_source): a pulsing ring on the floor. null = the default.
var view_scene: PackedScene

var _t: float = 0.0


func _ready() -> void:
	add_to_group(&"view_source")   # nothing happens without a WorldView
	var unit := get_parent() as Unit
	if unit:
		radius = unit.get_gameplay_radius_px() * 0.8
		unit.move_child.call_deferred(self, 0)   # behind the Body, above the floor


## The scene of its 3D view. Loaded only when a WorldView asks.
func get_view_scene() -> PackedScene:
	return view_scene if view_scene != null else load("res://scenes/view/aura_view.tscn")


## Its age in seconds, for the 3D view's pulse.
func get_age() -> float:
	return _t


func _process(delta: float) -> void:
	_t += delta
	if _t > max_time or (is_active.is_valid() and not is_active.call()):
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if Unit.looks_2d_off:
		return   # the 2D look; the 3D view shows its view (the cleanup's C2)
	var pulse := 0.5 + 0.5 * sin(_t * 10.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
	draw_arc(Vector2.ZERO, radius + pulse * 2.0, 0.0, TAU, 32, Color(color, 0.5 + pulse * 0.4), 2.0)
