class_name EntityView
extends Node3D
## The base of every view (3D.md, The generic view mechanism): a Node3D that
## follows one sim node. A sim node with a look is in the group view_source
## and has get_view_scene(). WorldView instances that scene under itself and
## calls setup(), then sync() on every physics tick after the sim moved, and
## on_sim_exited() when the sim node leaves the tree. A view only shows: it
## never changes gameplay state.

## The sim node this view shows. It can be freed before the view (a death
## finishing): check is_instance_valid() before using it, and never copy it
## into a typed variable once it may be freed (3D.md, Core rules).
var sim: Node2D
var world_view: WorldView

## How fast the view follows a change in the ground's height (m/s): faster than
## any walkable slope (a ramp at the Knight's speed climbs about 1.4 m/s), so
## only a cliff shows the limit.
var ground_speed_m_per_s: float = 8.0

var _sim_gone := false
var _last_px := Vector2.INF
var _ground_m := INF


## Called once by WorldView, right after the view entered the tree.
func setup(p_sim: Node2D, p_world_view: WorldView) -> void:
	sim = p_sim
	world_view = p_world_view
	name = "View_%s" % sim.name
	_on_setup()
	sync()
	reset_physics_interpolation()


## Follows the sim node (physics tick, after the sim): its position in meters
## at get_height_m(), snapped (not slid) after a teleport.
func sync() -> void:
	if _sim_gone or not is_instance_valid(sim) or not sim.is_inside_tree():
		return
	var px := _sim_position_px()
	position = Units.to_view(px, get_height_m())
	if _last_px != Vector2.INF and px.distance_to(_last_px) > WorldView.TELEPORT_PX:
		reset_physics_interpolation()
	_last_px = px
	_on_sync()


## How high this view stands, in meters: the walkable ground under it (P9,
## ground_height_m()). A subclass adds its own height over the ground.
func get_height_m() -> float:
	return ground_height_m()


## The walkable ground under the view (m; 3D.md, Terrain and height 1b):
## WorldView's downward ray, followed at up to ground_speed_m_per_s, so
## walking up a ramp or stairs follows it exactly while stepping off a cliff
## (a knock-up off a plateau) drops smoothly instead of popping. The first
## sync snaps. 0 without a WorldView.
func ground_height_m() -> float:
	if world_view == null:
		return 0.0
	var target := world_view.ground_height_m(_sim_position_px())
	if _ground_m == INF:
		_ground_m = target
	else:
		_ground_m = move_toward(_ground_m, target, ground_speed_m_per_s * get_physics_process_delta_time())
	return _ground_m


## The sim node left the tree (freed, or its status ended). The default frees
## the view; a unit finishes its death first, a projectile plays its impact.
func on_sim_exited() -> void:
	_sim_gone = true
	queue_free()


func is_sim_gone() -> bool:
	return _sim_gone or not is_instance_valid(sim)


## Where the view stands, in sim px. The sim node's position by default; a
## status VFX follows the unit it sits on.
func _sim_position_px() -> Vector2:
	return sim.global_position


## For subclasses: build the look (sim and world_view are set).
func _on_setup() -> void:
	pass


## For subclasses: more to copy each physics tick (after the position).
func _on_sync() -> void:
	pass
