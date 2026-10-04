extends Node2D
## A buff's pulsing ring under a unit while it's active (VFX.aura()). The 3D
## view draws it (AuraView, from its color, radius and age); this node keeps
## its lifetime. (Its 2D drawing went in the 3D pivot's cleanup C3.)

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
