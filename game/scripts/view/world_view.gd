class_name WorldView
extends Node3D
## The 3D view (docs/3D.md): under Main when `Main.use_3d_view` is on, it
## holds the environment, the key light, the camera, the room's look and
## every view, and keeps them in step with the 2D sim. The view never changes
## gameplay state.
## P2: its place in the tree, its physics priority and the floor pick.
## P3: hides the 2D world from the screen, shows a tile room's look
## (RoomView) and fades `fades` assets between the camera and the player.
## P4: the camera is GameCamera3D (P3's plain stand-in camera is gone).
## P5: the aim. The player reads the floor under the cursor and the enemy
## under it (picked on screen by its model) from here (Player.world_view).
## P6: the generic view mechanism (3D.md): every sim node in the group
## view_source gets its view (get_view_scene(), an EntityView) under this
## node, synced each physics tick after the sim; P3's stand-in capsules are
## gone (UnitView shows the units).
## P7: the floor drawings (FloorOverlay: telegraphs, ability indicators, the
## hover ring, swing arcs and rings, drawn on the floor's shader), damage
## numbers and health bars (ScreenOverlay), presentation-hook scenes with a
## Node3D root (add_scene_at(), from VFX.spawn_scene()). Sim code finds the
## view through WorldView.of() (the group world_view).
## P8: a room built in 3D (RoomLayout) is its own look: it moves under this
## node with its floor pick; its walkable floors' materials take the floor
## drawings, and its `fades` assets fade.

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
## The ground ray (ground_height_m()) runs from this high down to this deep (m).
const GROUND_RAY_M := 50.0
## The fade looks from the camera to the player's feet, chest and head
## (m above the floor; the Knight is 1.8 m tall).
const FADE_SIGHT_HEIGHTS_M := [0.0, 0.9, 1.8]
## The default view scenes, loaded once when the view starts, so the first
## stun, aura or projectile of a fight doesn't load one from disk on that
## frame (P6: 19–24 ms each). Loaded with load(), not preload(): their
## scripts name WorldView, and a preload here would be a cycle.
const DEFAULT_VIEW_SCENES := [
	"res://scenes/view/unit_view.tscn",
	"res://scenes/view/projectile_view.tscn",
	"res://scenes/view/aura_view.tscn",
	"res://scenes/view/stun_stars_view.tscn",
	"res://scenes/view/staggered_mark_view.tscn",
]

## The camera's look (field of view, pitch, width) and the fade's numbers.
@export var look: CameraLook = preload("res://data/camera_looks/camera_look_default.tres")

## Runs its _process after GameCamera3D's (10): the fade looks from where the
## camera is this frame.
const PROCESS_PRIORITY := 20

## The tile room's look (null for a room without Tiles).
var room_view: RoomView
## The room built in 3D, its own look (P8; null for a tile room).
var layout: RoomLayout
var camera: GameCamera3D
var player: Player
## The floor drawings (P7).
var floor_overlay: FloorOverlay
## Damage numbers and health bars (P7).
var screen_overlay: ScreenOverlay

var _sim_hidden := false
var _flat_floor_drawings := false
var _cull_mask_before: int = 0
## Sim node -> its EntityView. Keys can be freed nodes: read them untyped and
## check is_instance_valid() first (3D.md, Core rules).
var _views: Dictionary = {}
## The fading assets: {"geos": Array[GeometryInstance3D], "box": AABB, "fade": float}
var _fading: Array[Dictionary] = []
## Holds the default view scenes loaded (DEFAULT_VIEW_SCENES).
var _loaded_view_scenes: Array[PackedScene] = []


func _init() -> void:
	name = "WorldView"
	process_physics_priority = PHYSICS_PRIORITY
	process_priority = PROCESS_PRIORITY
	add_to_group(&"world_view")


## The WorldView showing the game `node` is in, or null (the 2D game, and
## every test that doesn't build one): how sim code reaches the view (a
## damage number, a 3D presentation-hook scene).
static func of(node: Node) -> WorldView:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(&"world_view") as WorldView


## Main calls this once, right after adding the WorldView: hides the 2D world,
## builds the room's look, every view and the camera, and gives the player
## its aim through this view. `camera_2d` is Main's GameCamera: the 3D camera
## uses its lock, lean, shake, pan settings and room bounds (null: no lean,
## shake or bounds). `p_layout` is the room built in 3D whose sim `room` is
## (P8): it moves under this view as the room's look, with its floor pick;
## null for a tile room, whose look RoomView makes from its Tiles.
func setup(main: CanvasItem, room: Node2D, p_player: Player, camera_2d: GameCamera = null, p_layout: RoomLayout = null) -> void:
	player = p_player
	if player:
		player.world_view = self
	hide_sim(main, room)
	layout = p_layout
	if layout:
		if layout.get_parent():
			layout.get_parent().remove_child(layout)
		add_child(layout)
		layout.add_child(layout.build_floor_pick())
	else:
		var tiles := room.get_node_or_null("Tiles") as TileMapLayer
		if tiles:
			room_view = RoomView.new()
			add_child(room_view)
			room_view.build(tiles)
	_collect_fading()
	# Before the views, so each unit's health bar comes with its view (P7).
	screen_overlay = ScreenOverlay.new()
	screen_overlay.world_view = self
	add_child(screen_overlay)
	watch_sim()

	camera = GameCamera3D.new()
	camera.look = look
	camera.source = camera_2d
	if camera_2d:
		camera.bounds_m = Rect2(camera_2d.bounds.position / Units.PX_PER_METER, camera_2d.bounds.size / Units.PX_PER_METER)
	camera.target = view_of(player)
	add_child(camera)
	camera.make_current()
	camera.snap_to_target()
	screen_overlay.camera = camera

	# The floor drawings (P7): the sim's World2D, drawn into a window around
	# the camera and laid on the room's floor.
	floor_overlay = FloorOverlay.new()
	floor_overlay.world_2d = get_viewport().world_2d
	if layout:
		var heights := layout.get_height_range_m()
		floor_overlay.drop_m = heights.y - heights.x   # P9: lower floor is seen farther
	add_child(floor_overlay)
	floor_overlay.setup(camera, camera.bounds_m)
	if room_view and room_view.floor_material:
		floor_overlay.add_floor_material(room_view.floor_material)
	if layout:
		for material in layout.get_floor_materials():
			floor_overlay.add_floor_material(material)
	flatten_floor_drawings()
	VFX.warm_up_pillar(self, player.global_position if player else Vector2.ZERO)


func _exit_tree() -> void:
	if _sim_hidden:
		get_viewport().canvas_cull_mask = _cull_mask_before
		_sim_hidden = false
	if _flat_floor_drawings:
		VFX.floor_squash = VFX.FLOOR_SQUASH_2D
		VFX.drawings_at_feet = false
		_flat_floor_drawings = false
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


## Floor circles drawn by 2D nodes (the hover ring, VFX.ring()) become true
## circles while this view shows the game: the 2D game squashes them for its
## 3/4 look, and here the camera foreshortens the floor itself
## (VFX.floor_squash). Swing arcs center on a unit's feet, not its 2D body's
## center (VFX.drawings_at_feet). Undone when the WorldView leaves the tree.
func flatten_floor_drawings() -> void:
	VFX.floor_squash = 1.0
	VFX.drawings_at_feet = true
	_flat_floor_drawings = true


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
	for view: Variant in _views.values():
		if is_instance_valid(view):
			(view as EntityView).sync()


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


## Where a ray under `screen_pos` meets the flat plane at `height_m`.
## Vector3.INF if it never does (the ray points level or up).
static func pick_plane(p_camera: Camera3D, screen_pos: Vector2, height_m: float) -> Vector3:
	var origin := p_camera.project_ray_origin(screen_pos)
	var normal := p_camera.project_ray_normal(screen_pos)
	if normal.y > -0.0001:
		return Vector3.INF
	return origin + normal * ((height_m - origin.y) / normal.y)


# --- The aim (P5) -------------------------------------------------------------------

## The floor under the cursor, in sim px (3D.md, The floor pick and aim).
## Vector2.INF without a camera.
func floor_under_cursor_px() -> Vector2:
	return floor_at_screen_px(get_viewport().get_mouse_position())


## The floor under a screen point (canvas px), in sim px: the walkable
## ground's pick, or past it (the void beyond a room's floor, a wall cell's
## gap) the plane at the camera focus's height, so an aim there still points
## the right way. Vector2.INF without a camera.
func floor_at_screen_px(screen_pos: Vector2) -> Vector2:
	if camera == null:
		return Vector2.INF
	var hit := pick_floor(camera, screen_pos)
	if hit == Vector3.INF:
		hit = pick_plane(camera, screen_pos, camera.get_focus().y)
	return Units.to_sim(hit) if hit != Vector3.INF else Vector2.INF


## The unit under the cursor among those `accept` lets through, picked on
## screen (unit_at_screen_point()).
func unit_under_cursor(accept: Callable) -> Unit:
	return unit_at_screen_point(get_viewport().get_mouse_position(), accept)


## The unit whose view covers `screen_pos` (canvas px): its meshes' bounds,
## projected, so the model's height and width count, not just its feet.
## Among those `accept` lets through, the one whose box's center is nearest
## the point wins; null if none.
func unit_at_screen_point(screen_pos: Vector2, accept: Callable) -> Unit:
	if camera == null:
		return null
	var best: Unit = null
	var best_d := INF
	for key: Variant in _views.keys():
		if not is_instance_valid(key) or not is_instance_valid(_views[key]):
			continue
		var unit := key as Unit
		if unit == null or not accept.call(unit):
			continue
		var rect := screen_rect_of(camera, _views[key])
		if rect.has_area() and rect.has_point(screen_pos):
			var d := rect.get_center().distance_to(screen_pos)
			if d < best_d:
				best = unit
				best_d = d
	return best


## A view's box on screen (canvas px): the bounds of every mesh under `root`,
## where it's drawn this frame (interpolated), projected through `p_camera`.
## An empty Rect2 if nothing is in front of the camera.
static func screen_rect_of(p_camera: Camera3D, root: Node3D) -> Rect2:
	var to_drawn := root.get_global_transform_interpolated() * root.global_transform.affine_inverse()
	var rect := Rect2()
	var first := true
	var geos: Array = [root]
	geos.append_array(root.find_children("*", "GeometryInstance3D", true, false))
	for n: Node in geos:
		var geo := n as GeometryInstance3D
		if geo == null:
			continue
		var box: AABB = (to_drawn * geo.global_transform) * geo.get_aabb()
		for i in 8:
			var corner := box.get_endpoint(i)
			if p_camera.is_position_behind(corner):
				continue
			var s := p_camera.unproject_position(corner)
			if first:
				rect = Rect2(s, Vector2.ZERO)
				first = false
			else:
				rect = rect.expand(s)
	return rect


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


# --- The generic view mechanism (P6) ------------------------------------------------------

## Views every sim node already in the group view_source, and from now on
## each one added (once it's ready: nodes join the group in their _ready()).
func watch_sim() -> void:
	if _loaded_view_scenes.is_empty():
		for path: String in DEFAULT_VIEW_SCENES:
			_loaded_view_scenes.append(load(path))
	for node in get_tree().get_nodes_in_group(&"view_source"):
		_add_view(node)
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)


## The view of a sim node, or null (none, or it's gone).
func view_of(node: Node) -> EntityView:
	if node == null or not _views.has(node):
		return null
	var view: Variant = _views[node]
	return view as EntityView if is_instance_valid(view) else null


## How tall a unit's model stands (m), for what sits over its head; 1.5 m if
## it has no UnitView.
func unit_height_m(node: Node) -> float:
	var view := view_of(node) as UnitView
	return view.model_height_m if view else 1.5


## The top of a unit's model where it's drawn (m): the ground under it, its
## knock-up arc and its model's height (P9). For what sits over its head.
func unit_top_m(node: Node) -> float:
	var view := view_of(node) as UnitView
	if view == null:
		var n2d := node as Node2D
		return (ground_height_m(n2d.global_position) if n2d else 0.0) + 1.5
	return view.position.y + view.air_height_m + view.model_height_m


## The walkable ground's height under a sim point (m; 3D.md, Terrain and
## height 1b): a downward ray on the view-only floor layer (the floor pick's
## bodies). 0 where there's no ground. During a physics frame, as views sync.
func ground_height_m(px: Vector2) -> float:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return 0.0
	var query := PhysicsRayQueryParameters3D.create(Units.to_view(px, GROUND_RAY_M), Units.to_view(px, -GROUND_RAY_M), FLOOR_LAYER)
	var hit := space.intersect_ray(query)
	return (hit["position"] as Vector3).y if not hit.is_empty() else 0.0


func _on_node_added(node: Node) -> void:
	if not (node is Node2D) or not node.has_method(&"get_view_scene"):
		return
	if node.is_node_ready():
		_add_view(node)
	else:
		node.ready.connect(_add_view.bind(node), CONNECT_ONE_SHOT)


func _add_view(node: Node) -> void:
	var sim := node as Node2D
	if sim == null or _views.has(sim) or not sim.is_inside_tree() or not sim.is_in_group(&"view_source"):
		return
	var scene: PackedScene = sim.call(&"get_view_scene")
	var view := scene.instantiate() as EntityView if scene else null
	if view == null:
		push_warning("WorldView: %s's view scene has no EntityView root; no view" % sim.name)
		return
	add_child(view)
	_views[sim] = view
	view.setup(sim, self)
	sim.tree_exiting.connect(_on_sim_exiting.bind(sim), CONNECT_ONE_SHOT)
	if view is UnitView and screen_overlay:
		screen_overlay.add_bar(sim as Unit)


## A presentation-hook scene whose root is a Node3D (VFX.spawn_scene(), P7):
## under this view, its origin on the floor at `pos_px`, turned so its +Z
## points along the 2D `angle` (the way a model faces its facing: the yaw
## atan2(x, y)). The root's own transform in its scene is kept, relative to
## that. It stands on the ground there (ground_height_m(): a plateau's top,
## half way up a ramp; P7's 2D-only looks step, for P9's terrain).
func add_scene_at(node: Node3D, pos_px: Vector2, angle: float) -> void:
	var local := node.transform
	add_child(node)
	var dir := Vector2.from_angle(angle)
	node.global_transform = Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.y)), Units.to_view(pos_px, ground_height_m(pos_px))) * local
	node.reset_physics_interpolation()


func _on_sim_exiting(sim: Node) -> void:
	var view: Variant = _views.get(sim)
	_views.erase(sim)
	if is_instance_valid(view):
		(view as EntityView).on_sim_exited()


## The player's feet in the view, interpolated (Vector3.INF once the player
## is gone: the camera holds where it was).
func _player_feet() -> Vector3:
	var view := view_of(player)
	if view == null or not is_instance_valid(player):
		return Vector3.INF
	return view.get_global_transform_interpolated().origin
