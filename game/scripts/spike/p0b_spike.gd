extends Node3D
## P0b feel spike (throwaway; branch spike/3d-p0b, never merged;
## docs/3D_PIVOT.md, P0b). One question: what should it look like?
## Plays the sandbox with its 2D world hidden from the screen (not from
## physics) and a 3D view following it, with the look toggles below. Open
## scenes/spike/p0b_spike.tscn and press F6. Backspace restarts and keeps the
## toggles. H hides the panel.

const SANDBOX := preload("res://scenes/sandbox_main.tscn")
const Look := preload("res://scripts/spike/p0b_look.gd")
const RoomView := preload("res://scripts/spike/p0b_room.gd")
const UnitView := preload("res://scripts/spike/p0b_unit_view.gd")
const AURA_SCRIPT := preload("res://scripts/vfx/aura.gd")
const PX_PER_M := 32.0
const VIS_SIM := 2       # canvas layer 2: the sim (hidden from the screen)
const VIS_FLOOR := 4     # canvas layer 3: floor drawings (the floor shader shows them)
const OVERLAY_SCALE := 2.0

const FOVS: Array[float] = [20.0, 30.0, 40.0]
const PITCHES: Array[float] = [50.0, 60.0, 70.0]
const WIDTHS: Array[float] = [20.0, 24.0, 28.0]
const WALLS: Array[float] = [0.6, 1.2, 2.4]
const FADE_MODES: Array[String] = ["solid", "fade", "cut-out circle"]
const KNIGHT_HEIGHTS: Array[float] = [1.4, 1.8, 2.2]

# The toggles survive Backspace (the scene reloads; statics stay).
static var perspective := true
static var fov_i := 1
static var pitch_i := 1
static var width_i := 1
static var wall_i := 1
static var fade_mode := 1
static var eight_dir := false
static var painted := true
static var torches_on := true
static var knight_i := 1
static var help_on := true

var main: Node2D
var room: Room
var player: Player
var look: Look
var room_view: RoomView
var camera: Camera3D

var _world: Node3D
var _env: Environment
var _sun: DirectionalLight3D
var _overlay: SubViewport
var _views: Dictionary = {}          # Unit -> view
var _projectiles: Array = []         # [Projectile, MeshInstance3D]
var _bars: Dictionary = {}           # view -> [bg ColorRect, fill ColorRect]
var _numbers: Array = []             # [Label, anchor Vector3, age]
var _rings: Dictionary = {}          # view -> MeshInstance3D (hover ring)
var _ui: CanvasLayer
var _panel: Label
var _focus := Vector3.ZERO
var _last_pick_px := Vector2.ZERO
var _frame_ms: Array[float] = []
var _last_usec := 0
var _time := 0.0
var _width_override := 0.0   # screenshot close-ups only


func is_eight_directions() -> bool:
	return eight_dir


## A unit's view, or null once it's gone. A dead enemy's entry stays in
## _views until the next physics tick, and copying a freed view into a typed
## variable errors, so every lookup goes through here.
func _view_of(u: Variant) -> UnitView:
	var v: Variant = _views.get(u)
	return v if is_instance_valid(v) else null


func _ready() -> void:
	process_physics_priority = 100   # after every sim node (they're at 0)
	main = SANDBOX.instantiate()
	add_child(main)
	room = main.get("room")
	player = main.get("player")
	_hide_2d()
	_world = Node3D.new()
	_world.name = "World3D"
	add_child(_world)
	look = Look.new()
	look.painted = painted
	_build_environment()
	room_view = RoomView.new()
	room_view.name = "RoomView"
	_world.add_child(room_view)
	room_view.build(room.get_node("Tiles"), look, WALLS[wall_i])
	_build_overlay()
	camera = Camera3D.new()
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.near = 0.3
	camera.far = 300.0
	_world.add_child(camera)
	camera.make_current()
	_build_ui()
	for node in get_tree().get_nodes_in_group("units"):
		_add_view(node as Unit)
	get_tree().node_added.connect(_on_node_added)
	player.spike_aim = _aim_point
	Events.unit_damaged.connect(_on_unit_damaged)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_apply_material_mode()
	_focus = Vector3.ZERO
	var pv := _view_of(player)
	if pv:
		_focus = pv.global_position
	var shots := _arg_value("--p0b-shots")
	if shots != "":
		_run_shots.call_deferred(shots)


func _arg_value(key: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return ""


# --- Hiding the 2D world (P0a's rule: every CanvasItem ancestor shares a layer with the mask) ---

func _hide_2d() -> void:
	main.visibility_layer = 1 | VIS_SIM
	room.visibility_layer = VIS_SIM
	room.get_node("Entities").visibility_layer = VIS_SIM
	player.visibility_layer = VIS_SIM   # its own drawing (the ability indicator) goes on the floor
	get_viewport().canvas_cull_mask &= ~VIS_SIM
	for node in room.find_children("*", "CanvasItem", true, false):
		_maybe_floor(node)


## Floor drawings: telegraphs, slashes, lines, auras (and their children).
func _maybe_floor(node: Node) -> void:
	var ci := node as CanvasItem
	if ci == null or ci.has_meta(&"p0b_floor"):
		return
	var parent := node.get_parent()
	var on_floor: bool = node is Telegraph or node.get_script() == AURA_SCRIPT
	if not on_floor and parent is CanvasItem and (parent as CanvasItem).has_meta(&"p0b_floor"):
		on_floor = true
	if not on_floor and parent != null and parent.name == &"Entities":
		on_floor = (node is Polygon2D and ci.z_index == 20) or node is Line2D
	if on_floor:
		ci.visibility_layer = VIS_FLOOR
		ci.set_meta(&"p0b_floor", true)


func _on_node_added(node: Node) -> void:
	if node is Unit:
		_add_view.call_deferred(node)
	elif node is Projectile:
		_add_projectile_view.call_deferred(node)
	_maybe_floor(node)


# --- Building ---------------------------------------------------------------------

func _build_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.035, 0.035, 0.045)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.glow_enabled = true
	_env.glow_intensity = 0.5
	_env.glow_bloom = 0.02
	_env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = _env
	_world.add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.name = "KeyLight"
	_sun.shadow_enabled = true
	_sun.shadow_blur = 1.5
	_sun.directional_shadow_max_distance = 50.0
	_world.add_child(_sun)
	# From the north-west, above: the top left of the screen.
	_sun.look_at_from_position(Vector3.ZERO, Vector3(0.75, -1.5, 0.85), Vector3.UP)


func _apply_material_mode() -> void:
	look.set_painted(painted)
	if painted:
		_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		_env.tonemap_exposure = 1.0
		_env.ambient_light_color = Color(0.66, 0.64, 0.7)
		_env.ambient_light_energy = 0.8
		_env.ssao_enabled = false
		_sun.light_color = Color(1.0, 0.95, 0.86)
		_sun.light_energy = 0.9
	else:
		_env.tonemap_mode = Environment.TONE_MAPPER_AGX
		_env.tonemap_exposure = 1.1
		_env.ambient_light_color = Color(0.5, 0.53, 0.62)
		_env.ambient_light_energy = 0.55
		_env.ssao_enabled = true
		_env.ssao_radius = 0.8
		_env.ssao_intensity = 1.6
		_sun.light_color = Color(1.0, 0.94, 0.84)
		_sun.light_energy = 2.4


## Floor drawings: a SubViewport sharing the sim's World2D at OVERLAY_SCALE
## texels per sim px; the floor's shader samples it (P0a's method).
func _build_overlay() -> void:
	var r: Rect2i = room_view.rect
	_overlay = SubViewport.new()
	_overlay.name = "GroundOverlay"
	_overlay.size = Vector2i(Vector2(r.size) * PX_PER_M * OVERLAY_SCALE)
	_overlay.transparent_bg = true
	_overlay.disable_3d = true
	_overlay.world_2d = get_viewport().world_2d
	_overlay.canvas_cull_mask = VIS_SIM | VIS_FLOOR
	_overlay.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_overlay)
	# After entering the tree (P0a: before it, Godot errors with canvas_map.has).
	_overlay.canvas_transform = Transform2D(0.0, Vector2.ONE * OVERLAY_SCALE, 0.0, -Vector2(r.position) * PX_PER_M * OVERLAY_SCALE)
	look.set_kind_param(&"floor", &"overlay", _overlay.get_texture())
	look.set_kind_param(&"floor", &"use_overlay", true)
	look.set_kind_param(&"floor", &"room_origin_m", room_view.room_origin_m())
	look.set_kind_param(&"floor", &"room_size_m", room_view.room_size_m())


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 5
	add_child(_ui)
	_panel = Label.new()
	_panel.add_theme_font_size_override(&"font_size", 7)
	_panel.add_theme_color_override(&"font_color", Color(1, 1, 0.9))
	_panel.add_theme_color_override(&"font_outline_color", Color(0, 0, 0))
	_panel.add_theme_constant_override(&"outline_size", 3)
	_panel.position = Vector2(get_viewport().get_visible_rect().size.x - 150.0, 66.0)
	_ui.add_child(_panel)


func _add_view(u: Unit) -> void:
	if not is_instance_valid(u) or _views.has(u) or not u.is_inside_tree():
		return
	var v: UnitView = UnitView.new()
	_world.add_child(v)
	v.setup(u, self, look, KNIGHT_HEIGHTS[knight_i])
	_views[u] = v
	if u is Enemy:
		var bg := ColorRect.new()
		bg.color = Color(0, 0, 0, 0.7)
		bg.size = Vector2(22, 3)
		var fill := ColorRect.new()
		fill.color = Color(0.9, 0.25, 0.2)
		fill.size = Vector2(20, 1)
		fill.position = Vector2(1, 1)
		bg.add_child(fill)
		_ui.add_child(bg)
		_bars[v] = [bg, fill]
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = v.radius_m * 0.95
		torus.outer_radius = v.radius_m * 1.08
		torus.rings = 32
		torus.ring_segments = 4
		ring.mesh = torus
		ring.scale = Vector3(1, 0.05, 1)
		ring.position.y = 0.03
		var rm := StandardMaterial3D.new()
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.albedo_color = Color(1, 0.3, 0.2)
		ring.material_override = rm
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.visible = false
		v.add_child(ring)
		_rings[v] = ring


func _add_projectile_view(p: Projectile) -> void:
	if not is_instance_valid(p) or not p.is_inside_tree():
		return
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = clampf(p.half_width_px / PX_PER_M, 0.1, 0.35)
	s.height = s.radius * 2.0
	mi.mesh = s
	var m := StandardMaterial3D.new()
	var c: Color = p.ability.icon_color if p.ability else Color.WHITE
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 2.0
	mi.material_override = m
	_world.add_child(mi)
	mi.global_position = Vector3(p.global_position.x / PX_PER_M, 0.6, p.global_position.y / PX_PER_M)
	mi.reset_physics_interpolation()
	_projectiles.append([p, mi])


# --- Physics tick: views follow the sim, after it ---------------------------------

func _physics_process(_delta: float) -> void:
	for u: Variant in _views.keys():
		var v := _view_of(u)
		if not is_instance_valid(v):
			_views.erase(u)
			continue
		v.sync_tick()
	var alive: Array = []
	for entry: Array in _projectiles:
		var p: Projectile = entry[0] if is_instance_valid(entry[0]) else null
		var mi: MeshInstance3D = entry[1]
		if p == null or not p.is_inside_tree():
			mi.queue_free()
			continue
		mi.global_position = Vector3(p.global_position.x / PX_PER_M, 0.6, p.global_position.y / PX_PER_M)
		alive.append(entry)
	_projectiles = alive


# --- Frame: camera, fades, overlays ---------------------------------------------------

func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_usec > 0:
		_frame_ms.append((now - _last_usec) / 1000.0)
		if _frame_ms.size() > 360:
			_frame_ms.remove_at(0)
	_last_usec = now
	_time += delta
	_update_camera()
	_update_tall_things(delta)
	room_view.update_torches(_time, torches_on)
	_update_bars_and_rings()
	_update_numbers(delta)
	_update_panel()


func _update_camera() -> void:
	var cam2d := main.get("camera") as Camera2D
	var pv := _view_of(player)
	var locked: bool = cam2d.get("locked")
	if pv and (locked or Input.is_action_pressed("camera_center")):
		var t := pv.get_global_transform_interpolated().origin
		var lead: Vector2 = cam2d.call("get_current_lead") if locked and not Input.is_action_pressed("camera_center") else Vector2.ZERO
		_focus = Vector3(t.x, 0.0, t.z) + _lead_m(lead)
	elif not locked:
		_focus = Vector3(cam2d.global_position.x / PX_PER_M, 0.0, cam2d.global_position.y / PX_PER_M)
	var pitch := deg_to_rad(PITCHES[pitch_i])
	var w: float = _width_override if _width_override > 0.0 else WIDTHS[width_i]
	var vis := get_viewport().get_visible_rect().size
	var aspect := vis.x / vis.y
	var back := Vector3(0.0, sin(pitch), cos(pitch))
	var dist := 40.0
	if perspective:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = FOVS[fov_i]
		dist = w / (2.0 * tan(deg_to_rad(camera.fov) * 0.5) * aspect)
	else:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = w / aspect
	camera.global_transform = Transform3D(Basis.from_euler(Vector3(-pitch, 0.0, 0.0)), _focus + back * dist)
	# GameFeel's shake moves the 2D camera's offset (screen px of the 640-wide canvas).
	camera.h_offset = cam2d.offset.x / vis.x * w
	camera.v_offset = -cam2d.offset.y / vis.y * (w / aspect)


## The 2D camera's lean (screen px of the 640x360 canvas) as the same share of
## the 3D screen, on the floor.
func _lead_m(lead_px: Vector2) -> Vector3:
	var vis := get_viewport().get_visible_rect().size
	var w: float = WIDTHS[width_i]
	var floor_h := w * vis.y / vis.x / sin(deg_to_rad(PITCHES[pitch_i]))
	return Vector3(lead_px.x / vis.x * w, 0.0, lead_px.y / vis.y * floor_h)


func _update_tall_things(delta: float) -> void:
	var pv := _view_of(player)
	if pv == null:
		return
	var feet := pv.get_global_transform_interpolated().origin
	var h: float = pv.height_m
	var forward := -camera.global_transform.basis.z
	for t: Dictionary in room_view.tall_things:
		var hide := false
		if fade_mode == 1:
			for y: float in [0.3, h * 0.55, h]:
				var p := feet + Vector3(0.0, y, 0.0)
				var from := camera.global_position if perspective else p - forward * 60.0
				if (t["aabb"] as AABB).intersects_segment(from, p):
					hide = true
		var target := 0.25 if hide else 1.0
		var f: float = move_toward(t["fade"], target, delta / 0.18)
		if f != t["fade"]:
			t["fade"] = f
			for geo: GeometryInstance3D in t["geos"]:
				geo.set_instance_shader_parameter(&"fade", f)
	look.set_tall_param(&"cut_on", fade_mode == 2)
	if fade_mode == 2:
		var vis := get_viewport().get_visible_rect().size
		var chest := feet + Vector3(0.0, h * 0.55, 0.0)
		var sp := camera.unproject_position(chest)
		var side := camera.unproject_position(chest + camera.global_transform.basis.x * 2.0)
		look.set_tall_param(&"cut_center_uv", sp / vis)
		look.set_tall_param(&"cut_radius", sp.distance_to(side) / vis.y)
		look.set_tall_param(&"cut_depth", -(camera.global_transform.affine_inverse() * chest).z - 0.4)


func _update_bars_and_rings() -> void:
	for v: Variant in _bars.keys():
		var parts: Array = _bars[v]
		var bg: ColorRect = parts[0]
		if not is_instance_valid(v) or not is_instance_valid(v.unit) or not v.unit.is_alive():
			bg.queue_free()
			_bars.erase(v)
			continue
		var top: Vector3 = v.get_global_transform_interpolated().origin + Vector3(0.0, v.height_m + 0.35, 0.0)
		bg.visible = not camera.is_position_behind(top)
		bg.position = camera.unproject_position(top) - bg.size * 0.5
		var hc: HealthComponent = v.unit.health
		(parts[1] as ColorRect).size.x = 20.0 * clampf(hc.current / maxf(hc.max_health, 1.0), 0.0, 1.0)
	for v: Variant in _rings.keys():
		if not is_instance_valid(v):
			_rings.erase(v)
			continue
		(_rings[v] as MeshInstance3D).visible = is_instance_valid(v.unit) and v.unit.hovered


func _on_unit_damaged(ctx: HitContext) -> void:
	var u := ctx.target as Unit
	var v := _view_of(u)
	if v == null or ctx.taken_damage <= 0.0:
		return
	var l := Label.new()
	l.text = str(roundi(ctx.taken_damage))
	l.add_theme_font_size_override(&"font_size", 12 if ctx.is_crit else 9)
	var c := Color(1, 0.3, 0.25) if u.team == Unit.Team.PLAYER else (Color(1, 0.85, 0.2) if ctx.is_crit else Color(1, 1, 1))
	l.add_theme_color_override(&"font_color", c)
	l.add_theme_color_override(&"font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override(&"outline_size", 3)
	_ui.add_child(l)
	var anchor: Vector3 = v.global_position + Vector3(randf_range(-0.3, 0.3), v.height_m + 0.2, 0.0)
	_numbers.append([l, anchor, 0.0])


func _update_numbers(delta: float) -> void:
	var alive: Array = []
	for n: Array in _numbers:
		var l: Label = n[0]
		n[2] += delta
		var age: float = n[2]
		if age > 0.7:
			l.queue_free()
			continue
		l.position = camera.unproject_position(n[1]) + Vector2(-l.size.x * 0.5, -10.0 - age * 26.0)
		l.modulate.a = clampf(1.0 - (age - 0.4) / 0.3, 0.0, 1.0)
		alive.append(n)
	_numbers = alive


# --- Aim: the floor pick, or the enemy under the cursor (its feet) ------------------

## Sim px under the cursor. An enemy whose model is under the cursor (in
## screen space) wins and gives its feet; otherwise the floor (flat, y = 0).
func _aim_point() -> Vector2:
	var mouse := get_viewport().get_mouse_position()
	var best: Unit = null
	var best_depth := INF
	for u: Variant in _views.keys():
		var v := _view_of(u)
		if not is_instance_valid(u) or not is_instance_valid(v) or not (u is Enemy) or not (u as Unit).is_targetable():
			continue
		var feet := v.global_position
		var a := camera.unproject_position(feet)
		var b := camera.unproject_position(feet + Vector3(0.0, v.height_m, 0.0))
		var r := a.distance_to(camera.unproject_position(feet + camera.global_transform.basis.x * v.radius_m * 0.8))
		if Geometry2D.get_closest_point_to_segment(mouse, a, b).distance_to(mouse) <= r:
			var depth := camera.global_position.distance_to(feet)
			if depth < best_depth:
				best = u
				best_depth = depth
	if best:
		return best.global_position
	var origin := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	if dir.y < -0.0001:
		var p := origin + dir * (-origin.y / dir.y)
		_last_pick_px = Vector2(p.x, p.z) * PX_PER_M
	return _last_pick_px


# --- Toggles ----------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var handled := true
	match key.physical_keycode:
		KEY_5:
			perspective = not perspective
		KEY_N:
			fov_i = (fov_i + 1) % FOVS.size()
		KEY_6:
			pitch_i = (pitch_i + 1) % PITCHES.size()
		KEY_7:
			width_i = (width_i + 1) % WIDTHS.size()
		KEY_8:
			wall_i = (wall_i + 1) % WALLS.size()
			room_view.rebuild_walls(WALLS[wall_i])
		KEY_9:
			fade_mode = (fade_mode + 1) % FADE_MODES.size()
		KEY_0:
			eight_dir = not eight_dir
		KEY_M:
			painted = not painted
			_apply_material_mode()
		KEY_L:
			torches_on = not torches_on
		KEY_B:
			knight_i = (knight_i + 1) % KNIGHT_HEIGHTS.size()
			var pv := _view_of(player)
			if pv:
				pv.set_knight_height(KNIGHT_HEIGHTS[knight_i])
		KEY_H:
			help_on = not help_on
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _update_panel() -> void:
	if not help_on:
		_panel.text = "H: P0b panel"
		return
	var sorted := _frame_ms.duplicate()
	sorted.sort()
	var avg := 0.0
	for ms: float in sorted:
		avg += ms
	avg /= maxf(sorted.size(), 1.0)
	var p99: float = sorted[int(sorted.size() * 0.99)] if sorted.size() > 10 else 0.0
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
	_panel.text = "\n".join([
		"P0b look spike  (H hides)",
		"5  projection   %s" % ("perspective" if perspective else "orthographic"),
		"N  field of view  %d°%s" % [FOVS[fov_i], "" if perspective else " (perspective only)"],
		"6  pitch   %d°" % PITCHES[pitch_i],
		"7  visible width   %d m" % WIDTHS[width_i],
		"8  walls   %.1f m" % WALLS[wall_i],
		"9  tall things   %s" % FADE_MODES[fade_mode],
		"0  turning   %s" % ("8 directions" if eight_dir else "smooth"),
		"M  material   %s" % ("painted (light ramp)" if painted else "fully lit PBR"),
		"L  torches   %s" % ("on" if torches_on else "off"),
		"B  Knight height   %.1f m" % KNIGHT_HEIGHTS[knight_i],
		"frame %.1f ms avg, %.1f p99   GPU %.2f ms" % [avg, p99, gpu],
	])


# --- Screenshot run (--p0b-shots=<dir>): every look, for checking --------------------

func _set_toggle(key: String, value: Variant) -> void:
	match key:
		"perspective": perspective = value
		"fov_i": fov_i = value
		"pitch_i": pitch_i = value
		"width_i": width_i = value
		"wall_i": wall_i = value
		"fade_mode": fade_mode = value
		"painted": painted = value
		"torches_on": torches_on = value


## A real input event (abilities read events, not just the held state).
func _send_action(action: String, pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	Input.parse_input_event(e)


func _run_shots(dir: String) -> void:
	# Scripted presses must never reach Ryan's real save (user://progress.cfg).
	Progress.saving_enabled = false
	DirAccess.make_dir_recursive_absolute(dir)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	help_on = false
	var spawn := player.global_position
	var shots := [
		{"name": "01_default_painted", "at": spawn, "help": true},
		{"name": "02_default_pbr", "at": spawn, "painted": false},
		{"name": "03_ortho", "at": spawn, "perspective": false},
		{"name": "04_pitch50", "at": spawn, "pitch_i": 0},
		{"name": "05_pitch70", "at": spawn, "pitch_i": 2},
		{"name": "06_width20", "at": spawn, "width_i": 0},
		{"name": "07_width28", "at": spawn, "width_i": 2},
		{"name": "08_walls06", "at": spawn, "wall_i": 0},
		{"name": "09_walls24", "at": spawn, "wall_i": 2},
		{"name": "10_house_solid", "at": Vector2(752, 208), "fade_mode": 0},
		{"name": "11_house_fade", "at": Vector2(752, 208), "fade_mode": 1},
		{"name": "12_house_cut", "at": Vector2(752, 208), "fade_mode": 2},
		{"name": "13_plateau_fade", "at": Vector2(624, 208), "fade_mode": 1},
		{"name": "14_pillar_fade", "at": Vector2(304, 176), "fade_mode": 1},
		{"name": "15_house_pbr", "at": Vector2(800, 400), "painted": false},
		{"name": "16_house_painted", "at": Vector2(800, 400)},
		{"name": "17_torches_off", "at": spawn, "torches_on": false},
		{"name": "18_knight_close_idle", "at": spawn, "width_m": 6.0},
		{"name": "19_knight_close_run", "at": spawn, "width_m": 6.0, "press": ["move_right"], "wait": 20},
		{"name": "20_knight_close_attack", "at": spawn, "width_m": 6.0, "press": ["attack"], "wait": 6},
		{"name": "21_knight_close_pbr", "at": spawn, "width_m": 6.0, "painted": false},
		{"name": "22_indicator_q", "at": spawn, "press": ["ability_q"], "wait": 8},
		{"name": "23_dash", "at": spawn, "width_m": 8.0, "press": ["dash"], "wait": 4},
		{"name": "24_after_kills", "at": spawn, "kill": true},
	]
	var defaults := {"perspective": true, "fov_i": 1, "pitch_i": 1, "width_i": 1, "wall_i": 1,
		"fade_mode": 1, "painted": true, "torches_on": true}
	var only := _arg_value("--p0b-only")
	for shot: Dictionary in shots:
		if only != "" and not String(shot["name"]).begins_with(only):
			continue
		for k: String in defaults:
			_set_toggle(k, shot.get(k, defaults[k]))
		room_view.rebuild_walls(WALLS[wall_i])
		_apply_material_mode()
		player.global_position = shot["at"]
		player.reset_physics_interpolation()
		_width_override = shot.get("width_m", 0.0)
		help_on = shot.get("help", false)
		if shot.get("kill", false):
			# Every enemy dies; their views outlive them, then free (the freed-view path).
			for e in get_tree().get_nodes_in_group("enemies"):
				(e as Unit).take_damage(1000000.0)
			var until := Time.get_ticks_msec() + 3000
			while Time.get_ticks_msec() < until:
				await get_tree().process_frame
			print("P0B kills: %d views left, %d bars left" % [_views.size(), _bars.size()])
		for i in 40:
			await get_tree().process_frame
		_frame_ms.clear()
		for i in 120:
			await get_tree().process_frame
		var sorted := _frame_ms.duplicate()
		sorted.sort()
		var gpu := RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
		print("P0B shot %s: frame median %.2f ms, p99 %.2f ms, GPU %.2f ms" % [shot["name"], sorted[sorted.size() / 2], sorted[int(sorted.size() * 0.99)], gpu])
		# Held input (the shot's "press"), captured "wait" physics ticks after the press.
		var presses: Array = shot.get("press", [])
		for action: String in presses:
			_send_action(action, true)
		for i in int(shot.get("wait", 0)):
			await get_tree().physics_frame
		get_viewport().get_texture().get_image().save_png(dir.path_join(shot["name"] + ".png"))
		for action: String in presses:
			_send_action(action, false)
		var pv := _view_of(player)
		if pv and shot.has("width_m"):
			print("P0B knight: base height %.3f, scale %.3f, anim %s at %.2f" % [pv.get("_knight_base_height"), pv.get("_knight").scale.x, pv.get("_anim").current_animation, pv.get("_anim").current_animation_position])
	_width_override = 0.0
	get_tree().quit()
