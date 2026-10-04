extends Node2D
## The stun's VFX (status_stun.tres): the 3D view shows little stars circling
## over the unit's model (StunStarsView). Visuals only; the StatusComponent
## adds and frees it. (Its 2D drawing went in the 3D pivot's cleanup C3.)


## Its 3D look (3D.md, The generic view mechanism; it's in the group
## view_source): stars circling over the unit's model. null = the default.
var view_scene: PackedScene


## The scene of its 3D view. Loaded only when a WorldView asks.
func get_view_scene() -> PackedScene:
	return view_scene if view_scene != null else load("res://scenes/view/stun_stars_view.tscn")


func _ready() -> void:
	add_to_group(&"view_source")   # nothing happens without a WorldView
