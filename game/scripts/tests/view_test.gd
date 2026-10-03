extends Node3D
## 3D pivot P2 test (docs/3D.md, Build order): open
## res://scenes/tests/view_test.tscn and press F6.
## Checks the 3D view's logic without drawing anything: the px <-> m mapping
## (Units), WorldView's physics priority, Main's use_3d_view switch (off by
## default and in both main scenes), and the floor pick on a fixed camera at
## the default look (perspective, 30° field of view, 50° pitch, 28 m wide)
## over a 1 m floor grid with a raised plateau: the screen center, round
## trips, the plateau top, the exact shared vertices that made a single ray
## slip through in P0a, a blocker on another layer, and a miss.
## Prints PASS/FAIL per check and a total; run headless, it quits with the
## number of failures as the exit code.

## Where the fixed camera looks (m).
const FOCUS := Vector3(10.0, 0.0, 8.0)
## The floor: a grid of 1 m quads from (0, 0) to these (m).
const FLOOR_SIZE := Vector2i(24, 18)
## The plateau: cells x 12..14, z 3..5, its top 1.5 m up.
const PLATEAU := Rect2i(12, 3, 3, 3)
const PLATEAU_TOP := 1.5
## A box on 3D layer 2 (not the floor's layer), standing in front of some floor.
const BLOCKER_CENTER := Vector3(8.0, 2.0, 12.0)
const BLOCKER_SIZE := Vector3(2.0, 4.0, 2.0)

var _passed: int = 0
var _failed: int = 0
var _camera: Camera3D


func _ready() -> void:
	print("\n=== View test (3D pivot) ===")
	_test_mapping()
	_test_world_view()
	_test_main_switch()
	await _test_floor_pick()
	print("=== %d passed, %d failed ===\n" % [_passed, _failed])

	if DisplayServer.get_name() == "headless":
		get_tree().quit(_failed)


# --- Mapping ------------------------------------------------------------------------

func _test_mapping() -> void:
	_section("Mapping (Units)")
	_check("PX_PER_METER is 32", Units.PX_PER_METER, 32.0)
	_check("32 px = 1 m", Units.px_to_m(32.0), 1.0)
	_check("1 m = 32 px", Units.m_to_px(1.0), 32.0)
	_check("100 LoL units = 1 m (the scale: 1 m = 1 tile = 32 px = 100 u)", Units.px_to_m(Units.to_px(100.0)), 1.0)
	_check("the Knight's 375 move speed = 3.75 m/s", Units.px_to_m(Units.to_px(375.0)), 3.75)
	_check("the dash's 128 px = 4 m", Units.px_to_m(128.0), 4.0)
	_check_exact("to_view: sim x -> view x, sim y -> view z, on the floor", Units.to_view(Vector2(64.0, 96.0)), Vector3(2.0, 0.0, 3.0))
	_check_exact("to_view: at a height", Units.to_view(Vector2(64.0, 96.0), 1.5), Vector3(2.0, 1.5, 3.0))
	_check_exact("to_sim: view x -> sim x, view z -> sim y, the height dropped", Units.to_sim(Vector3(2.0, 7.0, 3.0)), Vector2(64.0, 96.0))
	var sim_points: Array[Vector2] = [Vector2.ZERO, Vector2(144.0, 304.0), Vector2(-37.5, 812.25), Vector2(0.001, -0.001), Vector2(12345.6, -987.6)]
	var ok := true
	for p in sim_points:
		ok = ok and Units.to_sim(Units.to_view(p, 2.0)).is_equal_approx(p)
	_check("round trip sim -> view -> sim gives the same px (5 points, heights ignored)", ok, true)
	var view_points: Array[Vector3] = [Vector3(1.0, 0.0, 2.0), Vector3(-3.25, 4.0, 9.5), Vector3(0.5, -1.0, -0.125)]
	ok = true
	for v in view_points:
		ok = ok and Units.to_view(Units.to_sim(v)).is_equal_approx(Vector3(v.x, 0.0, v.z))
	_check("round trip view -> sim -> view keeps x and z, on the floor (3 points)", ok, true)


# --- WorldView and Main's switch ------------------------------------------------------------

func _test_world_view() -> void:
	_section("WorldView")
	var view := WorldView.new()
	var plain := Node.new()
	_check("its physics priority is 100", view.process_physics_priority, 100)
	_check("it runs after every sim node (they're at the default 0)", view.process_physics_priority > plain.process_physics_priority, true)
	_check("it's named WorldView", String(view.name), "WorldView")
	_check("the floor layer is 3D physics layer 1", WorldView.FLOOR_LAYER, 1)
	view.free()
	plain.free()


func _test_main_switch() -> void:
	_section("Main.use_3d_view")
	var script: Script = load("res://scripts/main.gd")
	_check("the export exists and is off by default", script.get_property_default_value(&"use_3d_view"), false)
	for path in ["res://scenes/main.tscn", "res://scenes/sandbox_main.tscn"]:
		var state := (load(path) as PackedScene).get_state()
		var turned_on := false
		for i in state.get_node_property_count(0):
			if state.get_node_property_name(0, i) == &"use_3d_view" and state.get_node_property_value(0, i) == true:
				turned_on = true
		_check("%s doesn't turn it on" % path.get_file(), turned_on, false)


# --- Floor pick -------------------------------------------------------------------------------

func _test_floor_pick() -> void:
	_section("Floor pick (fixed camera: perspective 30°, 50° pitch, 28 m wide)")
	_build_world()
	# Bodies join the physics space on the next physics step.
	await get_tree().physics_frame
	await get_tree().physics_frame

	var center := get_viewport().get_visible_rect().get_center()
	_check_near_v3("the screen center lands on the camera's focus", WorldView.pick_floor(_camera, center), FOCUS, 0.001)

	var flat_ok := 0
	var flat_points: Array[Vector3] = []
	for x: float in [2.0, 5.0, 18.0, 21.0]:
		for z: float in [9.0, 12.0, 15.0]:
			flat_points.append(Vector3(x + 0.37, 0.0, z + 0.29))
	var worst_px := 0.0
	for p in flat_points:
		var s := _camera.unproject_position(p)
		var hit := WorldView.pick_floor(_camera, s)
		var back_px := _camera.unproject_position(hit).distance_to(s) if hit != Vector3.INF else INF
		worst_px = maxf(worst_px, back_px)
		if hit != Vector3.INF and absf(hit.y) < 0.001 and back_px <= 0.05:
			flat_ok += 1
	_check("flat floor: 12 screen points pick the floor and project back within 0.05 px (worst %.4f px)" % worst_px, flat_ok, flat_points.size())

	var top_ok := 0
	var top_points: Array[Vector3] = [Vector3(13.3, PLATEAU_TOP, 4.4), Vector3(14.6, PLATEAU_TOP, 3.2), Vector3(12.2, PLATEAU_TOP, 5.8)]
	for q in top_points:
		if WorldView.pick_floor(_camera, _camera.unproject_position(q)).distance_to(q) <= 0.01:
			top_ok += 1
	_check("the plateau top: 3 points pick the top, not the floor behind or below", top_ok, top_points.size())

	# Exact shared vertices (P0a: one ray went wrong 6–12 times in 20 here,
	# slipping through the plateau top to the floor behind). The plateau top's
	# north edge (z 3) and east edge (x 15) are its outline from this camera
	# (west of it, to the south): the floor shows right behind them, so a
	# vertex there sits exactly between two surfaces (checked separately).
	var inside: Array[Vector3] = []
	var outline: Array[Vector3] = []
	for x in range(PLATEAU.position.x, PLATEAU.end.x + 1):
		for z in range(PLATEAU.position.y, PLATEAU.end.y + 1):
			var v := Vector3(x, PLATEAU_TOP, z)
			if x == PLATEAU.end.x or z == PLATEAU.position.y:
				outline.append(v)
			else:
				inside.append(v)
	inside.append_array([Vector3(11, 0, 7), Vector3(16, 0, 7), Vector3(10, 0, 10), Vector3(20, 0, 12)])
	var two_ray_ok := 0
	var one_ray_wrong := 0
	for v in inside:
		var s := _camera.unproject_position(v)
		if WorldView.pick_floor(_camera, s).distance_to(v) <= 0.02:
			two_ray_ok += 1
		if _single_ray(s).distance_to(v) > 0.02:
			one_ray_wrong += 1
	_check("13 exact shared vertices inside a surface (9 on the plateau top, 4 on open floor): every pick is exact", two_ray_ok, inside.size())
	print("        (for comparison, a single ray went wrong %d times in %d)" % [one_ray_wrong, inside.size()])
	var outline_ok := 0
	for v in outline:
		var s := _camera.unproject_position(v)
		var hit := WorldView.pick_floor(_camera, s)
		var on_top := hit.distance_to(v) <= 0.02
		var floor_behind := hit != Vector3.INF and absf(hit.y) < 0.001 and _camera.unproject_position(hit).distance_to(s) <= 0.05
		if on_top or floor_behind:
			outline_ok += 1
	_check("7 vertices on the plateau's outline: each picks the top there or the floor right behind it, on the same screen point", outline_ok, outline.size())

	var behind := Vector3(8.37, 0.0, 10.29)
	var s_behind := _camera.unproject_position(behind)
	_check("a box on layer 2 stands in front of this floor point (picked with layer 2 too, the box is hit)",
		WorldView.pick_floor(_camera, s_behind, 1 | 2).distance_to(behind) > 0.5, true)
	_check_near_v3("the floor pick ignores it (layer 1 only)", WorldView.pick_floor(_camera, s_behind), behind, 0.01)

	_check_exact("nothing under the ray (the top of the screen, past the floor's edge): Vector3.INF",
		WorldView.pick_floor(_camera, Vector2(center.x, 1.0)), Vector3.INF)
	_check_exact("nothing on the asked layer: Vector3.INF", WorldView.pick_floor(_camera, center, 1 << 2), Vector3.INF)

	var sim_ok := 0
	var sim_points: Array[Vector2] = [Vector2(76.0, 300.0), Vector2(600.0, 448.0), Vector2(160.0, 480.0), Vector2(704.5, 352.25)]
	for p in sim_points:
		var hit := WorldView.pick_floor(_camera, _camera.unproject_position(Units.to_view(p)))
		if hit != Vector3.INF and Units.to_sim(hit).distance_to(p) <= 0.1:
			sim_ok += 1
	_check("sim px -> view -> screen -> floor pick -> sim px: within 0.1 px (4 points)", sim_ok, sim_points.size())


## The floor (1 m quads, shared vertices) with the plateau on it, both on the
## floor layer; the blocker on layer 2; the camera at the default look.
func _build_world() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in FLOOR_SIZE.y:
		for x in FLOOR_SIZE.x:
			_quad(st, Vector3(x, 0, z), Vector3(x + 1, 0, z), Vector3(x + 1, 0, z + 1), Vector3(x, 0, z + 1))
	var h := PLATEAU_TOP
	for z in range(PLATEAU.position.y, PLATEAU.end.y):
		for x in range(PLATEAU.position.x, PLATEAU.end.x):
			_quad(st, Vector3(x, h, z), Vector3(x + 1, h, z), Vector3(x + 1, h, z + 1), Vector3(x, h, z + 1))
	for x in range(PLATEAU.position.x, PLATEAU.end.x):
		for z: int in [PLATEAU.position.y, PLATEAU.end.y]:
			_quad(st, Vector3(x, 0, z), Vector3(x + 1, 0, z), Vector3(x + 1, h, z), Vector3(x, h, z))
	for z in range(PLATEAU.position.y, PLATEAU.end.y):
		for x: int in [PLATEAU.position.x, PLATEAU.end.x]:
			_quad(st, Vector3(x, 0, z), Vector3(x, 0, z + 1), Vector3(x, h, z + 1), Vector3(x, h, z))
	var shape := st.commit().create_trimesh_shape()
	shape.backface_collision = true
	_add_body(shape, Vector3.ZERO, WorldView.FLOOR_LAYER)
	var box := BoxShape3D.new()
	box.size = BLOCKER_SIZE
	_add_body(box, BLOCKER_CENTER, 2)

	_camera = Camera3D.new()
	_camera.fov = 30.0
	_camera.near = 0.1
	_camera.far = 300.0
	add_child(_camera)
	_camera.make_current()
	var vis := get_viewport().get_visible_rect().size
	var pitch := deg_to_rad(50.0)
	var distance := 28.0 / (2.0 * tan(deg_to_rad(_camera.fov) * 0.5) * (vis.x / vis.y))
	_camera.global_transform = Transform3D(Basis.from_euler(Vector3(-pitch, 0.0, 0.0)),
		FOCUS + Vector3(0.0, sin(pitch), cos(pitch)) * distance)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for p in [a, b, c, a, c, d]:
		st.add_vertex(p)


func _add_body(shape: Shape3D, at: Vector3, layer: int) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)
	body.global_position = at


## One ray, for the comparison print only.
func _single_ray(screen: Vector2) -> Vector3:
	var from := _camera.project_ray_origin(screen)
	var to := from + _camera.project_ray_normal(screen) * _camera.far
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, WorldView.FLOOR_LAYER))
	return hit["position"] if not hit.is_empty() else Vector3.INF


# --- Helpers ------------------------------------------------------------------------------

func _section(title: String) -> void:
	print("-- %s" % title)


func _check(label: String, actual: Variant, expected: Variant) -> void:
	var ok: bool
	if actual is float or expected is float:
		ok = is_equal_approx(float(actual), float(expected))
	else:
		ok = actual == expected
	_report(ok, label, "got %s, expected %s" % [actual, expected])


func _check_exact(label: String, actual: Variant, expected: Variant) -> void:
	_report(actual == expected, label, "got %s, expected %s" % [actual, expected])


func _check_near_v3(label: String, actual: Vector3, expected: Vector3, tolerance: float) -> void:
	_report(actual.distance_to(expected) <= tolerance, label, "got %s, expected %s ± %s" % [actual, expected, tolerance])


func _report(ok: bool, label: String, detail: String) -> void:
	if ok:
		_passed += 1
		print("  PASS  %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s: %s" % [label, detail])
