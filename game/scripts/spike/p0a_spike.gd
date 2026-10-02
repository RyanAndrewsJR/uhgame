extends Node3D
## P0a spike (throwaway, never merged; 3D_PIVOT.md, P0a). Runs the real
## sandbox (sandbox_main.tscn) as the hidden 2D sim and builds a 3D view that
## follows it: the room raised from its tiles plus a terrain patch (plateau,
## ramp, stairs, ledges on layer 11, a fence on layer 7), a grey capsule per
## unit synced on the physics tick (after every sim node), a Camera3D that
## follows the Knight, the floor pick driving the Knight's aim, and the 2D
## floor drawings (telegraphs) shown through a SubViewport sharing the sim's
## World2D, projected by a Decal.
##
## Keys: P = orthographic / perspective. O = telegraph display: terrain shader / flat
## quad / none. T = a test telegraph on the ramp.
## Measure runs (quit when done): `-- --p0a-measure-headless` (headless:
## criteria 1, 3, 4 analytic, 6) and `-- --p0a-measure-window` (windowed:
## criteria 2, 4 rendered, 5).

const SANDBOX_MAIN: PackedScene = preload("res://scenes/sandbox_main.tscn")
const Terrain := preload("res://scripts/spike/p0a_terrain.gd")
const Measure := preload("res://scripts/spike/p0a_measure.gd")

const PITCH_DEG := 60.0
const VIEW_WIDTH_M := 23.0
const PERSPECTIVE_FOV := 30.0
const SNAP_PX := 64.0          # a sim move bigger than this in one tick is a teleport
const LAYER_PICK_HEIGHTMAP := 2   # 3D physics layer bits (view only)
const LAYER_PICK_TRIMESH := 4
const VIS_SIM := 2             # canvas visibility layer 2: the hidden sim
const VIS_FLOOR := 4           # canvas visibility layer 3: floor drawings

enum FloorDraw { SHADER, QUAD, NONE }

const TERRAIN_SHADER := """
shader_type spatial;
uniform sampler2D overlay : source_color, filter_linear, repeat_disable;
uniform vec2 room_origin_m;
uniform vec2 room_size_m;
uniform float show_overlay = 1.0;
varying vec3 world_pos;
varying vec3 world_normal;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec2 uv = (world_pos.xz - room_origin_m) / room_size_m;
	vec4 ov = texture(overlay, uv);
	float a = ov.a * smoothstep(0.3, 0.6, world_normal.y) * show_overlay;
	ALBEDO = mix(COLOR.rgb, ov.rgb, a);
	EMISSION = ov.rgb * a * 0.5;
	ROUGHNESS = 0.9;
}
"""

var main: Node
var terrain_material: ShaderMaterial
var room: Node2D
var player: Player
var terrain: Terrain = Terrain.new()
var camera: Camera3D
var perspective: bool = true
var pick_mask: int = LAYER_PICK_TRIMESH
var overlay: SubViewport
var overlay_quad: MeshInstance3D
var floor_draw: FloorDraw = FloorDraw.SHADER
var views: Dictionary = {}     # Unit -> MeshInstance3D (the capsule)
var _last_sim: Dictionary = {} # Unit -> Vector2 (last synced sim position)
var _cam_focus: Vector3 = Vector3.ZERO
var _ready_done: bool = false
var no_view: bool = false
var overlay_scale: int = 1   # overlay texels per sim px


func _ready() -> void:
	process_physics_priority = 100   # sync after every sim node this tick
	main = SANDBOX_MAIN.instantiate()
	add_child(main)
	room = main.room
	player = main.player
	terrain.setup(room.get_node("Tiles"))
	_build_sim_terrain()
	var args := OS.get_cmdline_user_args()
	if args.has("--p0a-no-view"):   # today's 2D game plus the terrain's sim side: for comparing costs
		no_view = true
		get_tree().node_added.connect(_on_node_added)
		_ready_done = true
		var m0: Node = Measure.new()
		m0.spike = self
		m0.windowed = true
		m0.only_c5 = true
		add_child(m0)
		return
	_hide_2d_world()
	_build_view()
	for u in get_tree().get_nodes_in_group("units"):
		_add_view(u as Unit)
	get_tree().node_added.connect(_on_node_added)
	player.spike_aim = func() -> Vector2: return floor_pick(get_viewport().get_mouse_position())
	_cam_focus = _player_view_pos()
	_place_camera(_cam_focus)
	_ready_done = true
	if args.has("--p0a-measure-headless") or args.has("--p0a-measure-window"):
		var m: Node = Measure.new()
		m.spike = self
		m.windowed = args.has("--p0a-measure-window")
		add_child(m)


# --- Sim side (throwaway: ledges, fence, masks, navigation) ---------------------------

func _build_sim_terrain() -> void:
	for r in terrain.ledge_rects_px():
		_static_rect(r, Terrain.LAYER_LEDGE, "Ledge")
	_static_rect(terrain.fence_rect_px, Terrain.LAYER_FENCE, "Fence")
	for u in get_tree().get_nodes_in_group("units"):
		(u as Unit).collision_mask |= Terrain.LAYER_FENCE | Terrain.LAYER_LEDGE
	# Paths go around cliffs: the bake parses ledges and the fence too.
	var nav: NavigationRegion2D = room.nav_region
	nav.navigation_polygon.parsed_collision_mask = 1 | Terrain.LAYER_FENCE | Terrain.LAYER_LEDGE
	nav.bake_navigation_polygon(false)


func _static_rect(r: Rect2, layer: int, label: String) -> void:
	var body := StaticBody2D.new()
	body.name = label
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	body.add_child(shape)
	body.position = r.get_center()
	body.add_to_group(&"navigation_source")
	room.add_child(body)


func _hide_2d_world() -> void:
	# Every CanvasItem parent must share a layer with a viewport's mask: Main
	# (the room's parent) is on both, so the overlay can reach the room.
	(main as CanvasItem).visibility_layer = 1 | VIS_SIM
	room.visibility_layer = VIS_SIM
	room.get_node("Entities").visibility_layer = VIS_SIM
	get_viewport().canvas_cull_mask &= ~VIS_SIM


# --- View -------------------------------------------------------------------------

func _build_view() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.09, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.65)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	terrain_material = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = TERRAIN_SHADER
	terrain_material.shader = sh
	var mesh := terrain.build_mesh()
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	mi.material_override = terrain_material

	add_child(mi)
	var fence := MeshInstance3D.new()
	fence.mesh = terrain.build_fence_mesh()
	fence.material_override = mat
	add_child(fence)

	# View-only pick colliders: the 1 m heightmap and a trimesh of the floor mesh.
	var hb := StaticBody3D.new()
	hb.collision_layer = LAYER_PICK_HEIGHTMAP
	hb.collision_mask = 0
	var hs := CollisionShape3D.new()
	hs.shape = terrain.build_heightmap()
	hb.add_child(hs)
	hb.position = terrain.room_center_m()
	add_child(hb)
	var tb := StaticBody3D.new()
	tb.collision_layer = LAYER_PICK_TRIMESH
	tb.collision_mask = 0
	var ts := CollisionShape3D.new()
	var tri := mesh.create_trimesh_shape()
	tri.backface_collision = true
	ts.shape = tri
	tb.add_child(ts)
	add_child(tb)

	camera = Camera3D.new()
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # it follows in _process
	camera.near = 0.5
	camera.far = 200.0
	add_child(camera)
	_apply_projection()
	camera.make_current()

	_build_floor_overlay()


## The sim's floor drawings: a SubViewport that shares the root's World2D and
## renders only canvas layers 2 (the sim's room) and 3 (floor drawings), one
## texel per sim px. Shown by the terrain's own shader, which samples it at
## each surface point's x/z (a vertical projection, like a decal: a Decal
## refuses a ViewportTexture in 4.7.2), or on a flat quad.
func _build_floor_overlay() -> void:
	overlay_scale = 2 if OS.get_cmdline_user_args().has("--p0a-overlay-2x") else 1
	var size := Vector2i(terrain.rect.size) * int(Terrain.PX) * overlay_scale
	overlay = SubViewport.new()
	overlay.size = size
	overlay.canvas_transform = Transform2D().scaled(Vector2(overlay_scale, overlay_scale))
	overlay.transparent_bg = true
	overlay.world_2d = get_viewport().world_2d
	overlay.canvas_cull_mask = VIS_SIM | VIS_FLOOR
	overlay.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(overlay)
	var tex := overlay.get_texture()
	var size_m := Vector3(float(terrain.rect.size.x), 8.0, float(terrain.rect.size.y))
	terrain_material.set_shader_parameter(&"overlay", tex)
	terrain_material.set_shader_parameter(&"room_origin_m", Vector2(terrain.rect.position))
	terrain_material.set_shader_parameter(&"room_size_m", Vector2(terrain.rect.size))
	overlay_quad = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size_m.x, size_m.z)
	overlay_quad.mesh = plane
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.albedo_texture = tex
	overlay_quad.material_override = qm
	overlay_quad.position = terrain.room_center_m() + Vector3(0.0, 0.02, 0.0)
	add_child(overlay_quad)
	set_floor_draw(FloorDraw.SHADER)


func set_floor_draw(mode: FloorDraw) -> void:
	floor_draw = mode
	terrain_material.set_shader_parameter(&"show_overlay", 1.0 if mode == FloorDraw.SHADER else 0.0)
	overlay_quad.visible = mode == FloorDraw.QUAD


func _on_node_added(node: Node) -> void:
	if no_view:
		if node is Unit and _ready_done:
			(node as Unit).collision_mask |= Terrain.LAYER_FENCE | Terrain.LAYER_LEDGE
		return
	if node is Telegraph:
		(node as CanvasItem).visibility_layer = VIS_FLOOR
	if node is Unit and _ready_done:
		(node as Unit).collision_mask |= Terrain.LAYER_FENCE | Terrain.LAYER_LEDGE
		_add_view.call_deferred(node as Unit)   # after its _ready (position set)


func _add_view(u: Unit) -> void:
	if not is_instance_valid(u) or views.has(u):
		return
	var cap := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	var r := clampf(u.get_pathing_radius_px() / Terrain.PX, 0.2, 0.6)
	cm.radius = r
	cm.height = 1.0 if u is Player else 0.7
	cap.mesh = cm
	var m := StandardMaterial3D.new()
	if u is Player:
		m.albedo_color = Color(0.3, 0.55, 0.95)
	elif String(u.name).begins_with("Dummy"):
		m.albedo_color = Color(0.6, 0.6, 0.6)
	elif u.scene_file_path.contains("elite"):
		m.albedo_color = Color(0.95, 0.55, 0.2)
	else:
		m.albedo_color = Color(0.35, 0.8, 0.4)
	cap.material_override = m
	var nose := MeshInstance3D.new()
	var nb := BoxMesh.new()
	nb.size = Vector3(0.25, 0.12, 0.12)
	nose.mesh = nb
	nose.position = Vector3(r + 0.08, 0.15, 0.0)
	nose.material_override = m
	cap.add_child(nose)
	add_child(cap)
	views[u] = cap
	_last_sim[u] = u.global_position
	cap.global_position = _unit_view_pos(u)
	cap.reset_physics_interpolation()
	u.tree_exiting.connect(_on_unit_exiting.bind(u))


func _on_unit_exiting(u: Unit) -> void:
	var cap: Node = views.get(u)
	if is_instance_valid(cap):
		cap.queue_free()
	views.erase(u)
	_last_sim.erase(u)


func _unit_view_pos(u: Unit) -> Vector3:
	var cm := (views[u] as MeshInstance3D).mesh as CapsuleMesh
	return terrain.to_view(u.global_position, terrain.h_model(u.global_position) + cm.height * 0.5)


func _player_view_pos() -> Vector3:
	return terrain.to_view(player.global_position, terrain.h_model(player.global_position))


## The WorldView sync: after every sim node this tick (process_physics_priority).
func _physics_process(_delta: float) -> void:
	for u: Unit in views:
		if not is_instance_valid(u):
			continue
		var cap: MeshInstance3D = views[u]
		var p: Vector2 = u.global_position
		cap.global_position = _unit_view_pos(u)
		if p.distance_to(_last_sim[u]) > SNAP_PX:
			cap.reset_physics_interpolation()   # a teleport: no streak
		_last_sim[u] = p
		var dir := Vector2.ZERO
		if u is Player:
			dir = (u as Player).facing
		elif u.velocity.length() > 1.0:
			dir = u.velocity.normalized()
		if dir != Vector2.ZERO:
			cap.rotation.y = atan2(-dir.y, dir.x)


# --- Camera -------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_instance_valid(player) or not views.has(player):
		return
	var target: Vector3 = (views[player] as MeshInstance3D).get_global_transform_interpolated().origin
	target.y -= ((views[player] as MeshInstance3D).mesh as CapsuleMesh).height * 0.5
	_cam_focus = _cam_focus.lerp(target, 1.0 - exp(-10.0 * delta))
	_place_camera(_cam_focus)


func _apply_projection() -> void:
	var view_h := VIEW_WIDTH_M * 9.0 / 16.0
	if perspective:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = PERSPECTIVE_FOV
	else:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = view_h
	_place_camera(_cam_focus)


func camera_distance() -> float:
	var view_h := VIEW_WIDTH_M * 9.0 / 16.0
	return (view_h * 0.5) / tan(deg_to_rad(PERSPECTIVE_FOV) * 0.5)


func camera_offset() -> Vector3:
	var p := deg_to_rad(PITCH_DEG)
	var d := camera_distance()
	return Vector3(0.0, d * sin(p), d * cos(p))


func _place_camera(focus: Vector3) -> void:
	if camera == null:
		return
	camera.global_position = focus + camera_offset()
	camera.rotation = Vector3(-deg_to_rad(PITCH_DEG), 0.0, 0.0)


func set_perspective(on: bool) -> void:
	perspective = on
	_apply_projection()


## The floor pick: the mouse ray against the view-only terrain collider.
## Returns the sim point (px) under a screen point, or the player's position.
func floor_pick(screen: Vector2, mask: int = -1) -> Vector2:
	var hit := floor_pick_3d(screen, mask)
	return terrain.to_sim(hit) if hit != Vector3.INF else player.global_position


## Two rays a hair apart, the nearer hit wins: a single ray that passes
## exactly through a vertex shared by several triangles can slip through the
## surface (measured in P0a: it missed the plateau top and hit the cliff behind).
var pick_disagreements: int = 0


func floor_pick_3d(screen: Vector2, mask: int = -1, two_rays: bool = true) -> Vector3:
	var a := _ray(screen, mask)
	if not two_rays:
		return a
	var b := _ray(screen + Vector2(0.013, 0.007), mask)
	if a == Vector3.INF:
		if b != Vector3.INF:
			pick_disagreements += 1
		return b
	if b == Vector3.INF:
		return a
	var o := camera.project_ray_origin(screen)
	if a.distance_to(b) > 0.05:
		pick_disagreements += 1
	return a if a.distance_to(o) <= b.distance_to(o) else b


func _ray(screen: Vector2, mask: int) -> Vector3:
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 500.0, pick_mask if mask < 0 else mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else Vector3.INF


# --- Keys ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_P:
			set_perspective(not perspective)
			print("P0a: %s" % ("perspective" if perspective else "orthographic"))
		KEY_O:
			set_floor_draw(((floor_draw + 1) % 3) as FloorDraw)
			print("P0a: floor drawings: %s" % FloorDraw.keys()[floor_draw])
		KEY_T:
			Telegraph.circle(player, Vector2(128.0, 368.0), 72.0, 3.0)
