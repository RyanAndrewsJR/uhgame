class_name WorldView
extends Node3D
## The 3D view (docs/3D.md): under Main when `Main.use_3d_view` is on, it
## holds the environment, the key light, the camera, the room's look and
## every view, and keeps them in step with the 2D sim. The view never changes
## gameplay state.
## P2: its place in the tree, its physics priority and the floor pick.
## P3: hides the 2D world from the screen, shows a tile room's look
## (RoomView) and fades `fades` assets between the camera and the player.
## P4: the camera is GameCamera3D (P3's plain stand-in camera is gone). Until
## P6 it also holds stand-ins (throwaway): a capsule per unit.

## Runs after every sim node (they're all at the default 0), so the views copy
## positions the sim has already moved this tick (3D.md, Core rules).
const PHYSICS_PRIORITY := 100
## The view-only 3D physics layer of the walkable ground (3D physics layer 1,
## "floor"): the floor pick and the height ray only.
const FLOOR_LAYER := 1
## The floor pick's second ray, a hair off the first, in screen px (P0a: one
## ray through a vertex shared by several triangles can slip through).
const SECOND_RAY_OFFSET := Vector2(0.013, 0.007)
## Canvas visibility layer 2, "sim" (its bit): the 2D world is drawn on it,
## and the root viewport's cull mask drops it.
const SIM_VISIBILITY_BIT := 1 << 1
## A view whose sim node moved farther than this in one tick is snapped, not
## slid: a teleport (the dash peaks near 23 px a tick).
const TELEPORT_PX := 64.0
## The fade looks from the camera to the player's feet, chest and head
## (m above the floor; the Knight is 1.8 m tall).
const FADE_SIGHT_HEIGHTS_M := [0.0, 0.9, 1.8]

## Stand-ins (P3 only, until P6's UnitView): capsules as wide as the unit's
## body collision circle, so they touch walls exactly when the body does.
const STAND_IN_PLAYER_HEIGHT_M := 1.8
const STAND_IN_ENEMY_HEIGHT_M := 1.0
const STAND_IN_PLAYER_COLOR := Color(0.25, 0.5, 1.0)
const STAND_IN_ENEMY_COLOR := Color(0.9, 0.25, 0.2)

## The camera's look (field of view, pitch, width) and the fade's numbers.
@export var look: CameraLook = preload("res://data/camera_looks/camera_look_default.tres")

## Runs its _process after GameCamera3D's (10): the fade looks from where the
## camera is this frame.
const PROCESS_PRIORITY := 20

## The tile room's look (null for a room without Tiles).
var room_view: RoomView
var camera: GameCamera3D
var player: Player

var _sim_hidden := false
var _cull_mask_before: int = 0
## Unit -> {"root": Node3D, "last_px": Vector2}. Keys can be freed units:
## read them untyped and check is_instance_valid() first (3D.md, Core rules).
var _stand_ins: Dictionary = {}
## The fading assets: {"geos": Array[GeometryInstance3D], "box": AABB, "fade": float}
var _fading: Array[Dictionary] = []


func _init() -> void:
	name = "WorldView"
	process_physics_priority = PHYSICS_PRIORITY
	process_priority = PROCESS_PRIORITY


## Main calls this once, right after adding the WorldView: hides the 2D world,
## builds the room's look, the stand-ins and the camera. `camera_2d` is Main's
## GameCamera: the 3D camera uses its lock, lean, shake, pan settings and room
## bounds (null: no lean, shake or bounds).
func setup(main: CanvasItem, room: Node2D, p_player: Player, camera_2d: GameCamera = null) -> void:
	player = p_player
	hide_sim(main, room)
	var tiles := room.get_node_or_null("Tiles") as TileMapLayer
	if tiles:
		room_view = RoomView.new()
		add_child(room_view)
		room_view.build(tiles)
	_collect_fading()
	for unit in get_tree().get_nodes_in_group(&"units"):
		_add_stand_in(unit as Unit)
	get_tree().node_added.connect(_on_node_added)

	camera = GameCamera3D.new()
	camera.look = look
	camera.source = camera_2d
	if camera_2d:
		camera.bounds_m = Rect2(camera_2d.bounds.position / Units.PX_PER_METER, camera_2d.bounds.size / Units.PX_PER_METER)
	if _stand_ins.has(player):
		camera.target = _stand_ins[player]["root"]
	add_child(camera)
	camera.make_current()
	camera.snap_to_target()


func _exit_tree() -> void:
	if _sim_hidden:
		get_viewport().canvas_cull_mask = _cull_mask_before
		_sim_hidden = false
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


## Hides the 2D world from the screen, not from physics (3D.md, The room's
## look): the room's root and its Entities go on the canvas visibility layer
## "sim" (2), Main on 1 and 2 (every CanvasItem ancestor of a drawing must
## share a layer with a viewport's mask; P7's FloorOverlay draws from layer
## 2), and this viewport's cull mask drops layer 2. Everything the sim spawns
## goes under the room, so it's hidden too. The HUD and menus are CanvasLayers
## and stay. Undone when the WorldView leaves the tree.
func hide_sim(main: CanvasItem, room: CanvasItem) -> void:
	main.visibility_layer = 1 | SIM_VISIBILITY_BIT
	room.visibility_layer = SIM_VISIBILITY_BIT
	var entities := room.get_node_or_null("Entities") as CanvasItem
	if entities:
		entities.visibility_layer = SIM_VISIBILITY_BIT
	var viewport := get_viewport()
	if not _sim_hidden:
		_cull_mask_before = viewport.canvas_cull_mask
		_sim_hidden = true
	viewport.canvas_cull_mask = _cull_mask_before & ~SIM_VISIBILITY_BIT


func _physics_process(_delta: float) -> void:
	for key: Variant in _stand_ins.keys():
		var entry: Dictionary = _stand_ins[key]
		var root: Node3D = entry["root"]
		if not is_instance_valid(key):
			root.queue_free()
			_stand_ins.erase(key)
			continue
		var px: Vector2 = (key as Node2D).global_position
		root.position = Units.to_view(px)
		if px.distance_to(entry["last_px"]) > TELEPORT_PX:
			root.reset_physics_interpolation()
		entry["last_px"] = px


func _process(delta: float) -> void:
	if camera == null:
		return
	var feet := _player_feet()
	var eye := camera.global_position
	for entry in _fading:
		var blocked := feet != Vector3.INF and blocks_view(entry["box"], eye, feet)
		var current: float = entry["fade"]
		var next := step_fade(current, blocked, delta, look)
		if next != current:
			entry["fade"] = next
			for geo: GeometryInstance3D in entry["geos"]:
				geo.set_instance_shader_parameter(&"fade", next)


## True when `box` stands between the camera's `eye` and the player: the
## segment from the eye to the player's feet, chest or head crosses it.
static func blocks_view(box: AABB, eye: Vector3, feet: Vector3) -> bool:
	for h: float in FADE_SIGHT_HEIGHTS_M:
		if box.intersects_segment(eye, feet + Vector3(0.0, h, 0.0)) != null:
			return true
	return false


## The fade one frame on: toward look.fade_to while blocked, back to 1 when
## not, over look.fade_time either way.
static func step_fade(current: float, blocked: bool, delta: float, p_look: CameraLook) -> float:
	var target := p_look.fade_to if blocked else 1.0
	if p_look.fade_time <= 0.0:
		return target
	return move_toward(current, target, delta * (1.0 - p_look.fade_to) / p_look.fade_time)


## The floor pick (3D.md, The floor pick and aim): the point on the walkable
## ground under `screen_pos` (viewport canvas coordinates, the same space as
## `Viewport.get_mouse_position()`), seen through `camera`. Two rays a hair
## apart; the hit nearer the camera wins. Vector3.INF when neither hits.
static func pick_floor(p_camera: Camera3D, screen_pos: Vector2, mask: int = FLOOR_LAYER) -> Vector3:
	var space := p_camera.get_world_3d().direct_space_state
	var eye := p_camera.project_ray_origin(screen_pos)
	var best := Vector3.INF
	var best_d := INF
	for offset: Vector2 in [Vector2.ZERO, SECOND_RAY_OFFSET]:
		var from := p_camera.project_ray_origin(screen_pos + offset)
		var to := from + p_camera.project_ray_normal(screen_pos + offset) * p_camera.far
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, mask))
		if hit.is_empty():
			continue
		var p: Vector3 = hit["position"]
		var d := eye.distance_squared_to(p)
		if d < best_d:
			best = p
			best_d = d
	return best


# --- Fading ---------------------------------------------------------------------

## Every `fades` asset under this WorldView, with its bounds (assets don't move).
func _collect_fading() -> void:
	_fading.clear()
	for node in get_tree().get_nodes_in_group(&"fades"):
		var root := node as Node3D
		if root == null or not is_ancestor_of(root):
			continue
		var geos: Array[GeometryInstance3D] = []
		var box := AABB()
		var candidates: Array = [root]
		candidates.append_array(root.find_children("*", "GeometryInstance3D", true, false))
		for n: Node in candidates:
			var geo := n as GeometryInstance3D
			if geo == null:
				continue
			var b: AABB = geo.global_transform * geo.get_aabb()
			box = b if geos.is_empty() else box.merge(b)
			geos.append(geo)
		if not geos.is_empty():
			_fading.append({"geos": geos, "box": box, "fade": 1.0})


# --- Stand-ins (P3 only) ------------------------------------------------------------

func _on_node_added(node: Node) -> void:
	var unit := node as Unit
	if unit == null:
		return
	if unit.is_node_ready():
		_add_stand_in(unit)
	else:
		unit.ready.connect(_add_stand_in.bind(unit), CONNECT_ONE_SHOT)


func _add_stand_in(unit: Unit) -> void:
	if unit == null or _stand_ins.has(unit):
		return
	var radius_px := unit.get_pathing_radius_px()
	var body := unit.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body and body.shape is CircleShape2D:
		radius_px = (body.shape as CircleShape2D).radius
	var radius := Units.px_to_m(radius_px)
	var height := maxf(STAND_IN_PLAYER_HEIGHT_M if unit is Player else STAND_IN_ENEMY_HEIGHT_M, radius * 2.0)
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = height
	var material := StandardMaterial3D.new()
	material.albedo_color = STAND_IN_PLAYER_COLOR if unit is Player else STAND_IN_ENEMY_COLOR
	capsule.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = capsule
	mesh.position.y = height * 0.5
	var root := Node3D.new()   # at the unit's feet
	root.name = "StandIn_%s" % unit.name
	root.add_child(mesh)
	add_child(root)
	root.position = Units.to_view(unit.global_position)
	root.reset_physics_interpolation()
	_stand_ins[unit] = {"root": root, "last_px": unit.global_position}
	unit.tree_exiting.connect(_remove_stand_in.bind(unit), CONNECT_ONE_SHOT)


func _remove_stand_in(unit: Unit) -> void:
	if not _stand_ins.has(unit):
		return
	(_stand_ins[unit]["root"] as Node3D).queue_free()
	_stand_ins.erase(unit)


## The player's feet in the view, interpolated (Vector3.INF once the player
## is gone: the camera holds where it was).
func _player_feet() -> Vector3:
	if not is_instance_valid(player) or not _stand_ins.has(player):
		return Vector3.INF
	return (_stand_ins[player]["root"] as Node3D).get_global_transform_interpolated().origin
