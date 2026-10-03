class_name WorldView
extends Node3D
## The 3D view (docs/3D.md): under Main when `Main.use_3d_view` is on, it
## will hold the environment, the key light, the camera, the room's look and
## every view, and keep them in step with the 2D sim. The view never changes
## gameplay state.
## P2: the empty shell (its place in the tree and its physics priority) and
## the floor pick. What it shows comes in P3–P9 (3D.md, Build order).

## Runs after every sim node (they're all at the default 0), so the views copy
## positions the sim has already moved this tick (3D.md, Core rules).
const PHYSICS_PRIORITY := 100
## The view-only 3D physics layer of the walkable ground (3D physics layer 1,
## "floor"): the floor pick and the height ray only.
const FLOOR_LAYER := 1
## The floor pick's second ray, a hair off the first, in screen px (P0a: one
## ray through a vertex shared by several triangles can slip through).
const SECOND_RAY_OFFSET := Vector2(0.013, 0.007)


func _init() -> void:
	name = "WorldView"
	process_physics_priority = PHYSICS_PRIORITY


## The floor pick (3D.md, The floor pick and aim): the point on the walkable
## ground under `screen_pos` (viewport canvas coordinates, the same space as
## `Viewport.get_mouse_position()`), seen through `camera`. Two rays a hair
## apart; the hit nearer the camera wins. Vector3.INF when neither hits.
static func pick_floor(camera: Camera3D, screen_pos: Vector2, mask: int = FLOOR_LAYER) -> Vector3:
	var space := camera.get_world_3d().direct_space_state
	var eye := camera.project_ray_origin(screen_pos)
	var best := Vector3.INF
	var best_d := INF
	for offset: Vector2 in [Vector2.ZERO, SECOND_RAY_OFFSET]:
		var from := camera.project_ray_origin(screen_pos + offset)
		var to := from + camera.project_ray_normal(screen_pos + offset) * camera.far
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, mask))
		if hit.is_empty():
			continue
		var p: Vector3 = hit["position"]
		var d := eye.distance_squared_to(p)
		if d < best_d:
			best = p
			best_d = d
	return best
