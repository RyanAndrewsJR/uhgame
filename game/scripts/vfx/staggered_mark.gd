extends Node2D
## Staggered's VFX (status_staggered.tres, CHAMPIONS CH4): a pale yellow
## cracked ring over the unit's head, so the player sees who a Cleave will
## hit harder. Visuals only; the StatusComponent adds and frees it.

const COLOR := Color(1.0, 0.92, 0.55, 0.9)

## Its 3D look (3D.md, The generic view mechanism; it's in the group
## view_source): the cracked ring over the unit's model. null = the default.
var view_scene: PackedScene

var _time: float = 0.0


## The scene of its 3D view. Loaded only when a WorldView asks.
func get_view_scene() -> PackedScene:
	return view_scene if view_scene != null else load("res://scenes/view/staggered_mark_view.tscn")


func _ready() -> void:
	add_to_group(&"view_source")   # nothing happens without a WorldView
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
