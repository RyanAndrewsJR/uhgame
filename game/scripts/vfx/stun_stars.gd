extends Node2D
## The stun's VFX (status_stun.tres): little spinning stars over the unit's
## head. Visuals only; the StatusComponent adds and frees it.


## Its 3D look (3D.md, The generic view mechanism; it's in the group
## view_source): stars circling over the unit's model. null = the default.
var view_scene: PackedScene

var _spin: float = 0.0


## The scene of its 3D view. Loaded only when a WorldView asks.
func get_view_scene() -> PackedScene:
	return view_scene if view_scene != null else load("res://scenes/view/stun_stars_view.tscn")


func _ready() -> void:
	add_to_group(&"view_source")   # nothing happens without a WorldView
	z_index = 95
	var unit := get_parent() as Unit
	if unit:
		position = unit.body_center + Vector2(0, -unit.get_gameplay_radius_px() * 0.9)


func _process(delta: float) -> void:
	_spin += delta * 6.0
	queue_redraw()


func _draw() -> void:
	if Unit.looks_2d_off:
		return   # the 2D look; the 3D view shows its view (the cleanup's C2)
	for i in 3:
		var a := _spin + i * TAU / 3.0
		var p := Vector2(cos(a) * 9.0, sin(a) * 3.0)
		draw_circle(p, 2.0, Color(1, 0.9, 0.3))
