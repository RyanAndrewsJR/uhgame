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

var _sim_gone := false
var _last_px := Vector2.INF


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


## How high above the floor this view stands, in meters. The floor is flat
## until P9 (then: the terrain's height under it).
func get_height_m() -> float:
	return 0.0


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
