extends Node3D
## 3D pivot P2 test (docs/3D.md, Build order): open
## res://scenes/tests/view_test.tscn and press F6.
## Checks the 3D view's logic without drawing anything: the px <-> m mapping
## (Units), WorldView's physics priority, Main's use_3d_view switch (off by
## default and in both main scenes, on in the 3D sandbox scene), and the floor
## pick on a fixed camera at the default look (perspective, 30° field of
## view, 50° pitch, 28 m wide) over a 1 m floor grid with a raised plateau:
## the screen center, round trips, the plateau top, the exact shared vertices
## that made a single ray slip through in P0a, a blocker on another layer,
## and a miss.
## P3: CameraLook (its numbers, and on a real camera the visible width in
## both projections), RoomView on a fixture tile room (walls, floor, the
## environment and key light), the fade (what blocks the view, the fade's
## pace) and hiding the 2D world (and restoring it).
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
	_test_camera_look()
	_test_room_view()
	_test_fade()
	_test_hide_sim()
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
	_check("sandbox_main_3d.tscn (the 3D sandbox to play, P3) turns it on", _turns_3d_on("res://scenes/sandbox_main_3d.tscn"), true)


func _turns_3d_on(path: String) -> bool:
	var state := (load(path) as PackedScene).get_state()
	for i in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == &"use_3d_view" and state.get_node_property_value(0, i) == true:
			return true
	return false


# --- P3: CameraLook, RoomView, the fade, hiding the 2D world -------------------------------------

func _test_camera_look() -> void:
	_section("CameraLook (Ryan's picks after P0b)")
	var look: CameraLook = load("res://data/camera_looks/camera_look_default.tres")
	_check_exact("perspective", look.projection, CameraLook.ProjectionMode.PERSPECTIVE)
	_check("a 30° field of view", look.fov_deg, 30.0)
	_check("a 50° pitch", look.pitch_deg, 50.0)
	_check("28 m wide", look.visible_width_m, 28.0)
	_check("faded things fade to 0.25", look.fade_to, 0.25)
	_check("over 0.18 s", look.fade_time, 0.18)
	_check_near("16:9: the camera sits 29.4 m from its focus", look.get_distance_m(16.0 / 9.0), 29.389, 0.001)
	var offset := look.get_offset_m(16.0 / 9.0)
	_check_near("16:9: 22.5 m above it", offset.y, 22.513, 0.001)
	_check_near("16:9: 18.9 m south of it", offset.z, 18.891, 0.001)
	_check_near("16:9: not east or west of it (the camera never turns)", offset.x, 0.0, 0.0)

	# The look on a camera: the focus lands on the screen's center, and 14 m
	# east and west of it on the screen's right and left edges. Physics
	# interpolation off, like every camera moved by code outside the physics
	# tick: an interpolated Camera3D projects from its interpolated transform
	# (3D.md, Engine facts), which lags a transform just set.
	var cam := Camera3D.new()
	cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(cam)
	var vis := get_viewport().get_visible_rect().size
	var focus := Vector3(10.0, 0.0, 8.0)
	for projection: CameraLook.ProjectionMode in [CameraLook.ProjectionMode.PERSPECTIVE, CameraLook.ProjectionMode.ORTHOGRAPHIC]:
		var each := look.duplicate() as CameraLook
		each.projection = projection
		each.apply(cam, focus, vis.x / vis.y)
		var name_ := "perspective" if projection == CameraLook.ProjectionMode.PERSPECTIVE else "orthographic"
		_check_near("%s: the focus is the screen's center (px off)" % name_, cam.unproject_position(focus).distance_to(vis * 0.5), 0.0, 0.01)
		_check_near("%s: 14 m west of the focus is the left edge (x px)" % name_, cam.unproject_position(focus + Vector3(-14.0, 0.0, 0.0)).x, 0.0, 0.05)
		_check_near("%s: 14 m east of it is the right edge (x px)" % name_, cam.unproject_position(focus + Vector3(14.0, 0.0, 0.0)).x, vis.x, 0.05)
	cam.free()


## A tile room's Tiles (the game's TileSet), offset 2 m east and 1 m south,
## 6 x 5 cells: walls around the edge and one inside at cell (2, 2), the two
## floor tiles mixed. 19 wall cells, 11 floor cells. Under a Node2D "room"
## with an Entities child, under a Node2D "main"; all in the tree.
func _fixture_room() -> Node2D:
	var main := Node2D.new()
	main.name = "FixtureMain"
	var room := Node2D.new()
	room.name = "FixtureRoom"
	var entities := Node2D.new()
	entities.name = "Entities"
	var tiles := TileMapLayer.new()
	tiles.name = "Tiles"
	tiles.tile_set = load("res://tilesets/dungeon_tileset.tres")
	tiles.position = Vector2(64.0, 32.0)
	for y in 5:
		for x in 6:
			var edge := x == 0 or y == 0 or x == 5 or y == 4
			var atlas := Vector2i(2, 0) if edge or Vector2i(x, y) == Vector2i(2, 2) else Vector2i((x + y) % 2, 0)
			if Vector2i(x, y) == Vector2i(5, 4):
				atlas = Vector2i(3, 0)   # the other wall tile
			tiles.set_cell(Vector2i(x, y), 0, atlas)
	room.add_child(tiles)
	room.add_child(entities)
	main.add_child(room)
	add_child(main)
	return main


func _test_room_view() -> void:
	_section("RoomView (a tile room's look: walls, floor, environment, key light)")
	var main := _fixture_room()
	var tiles: TileMapLayer = main.get_node("FixtureRoom/Tiles")
	var view := RoomView.new()
	add_child(view)
	view.build(tiles)

	_check("19 wall cells: 19 wall boxes", view.walls.size(), 19)
	_check("11 floor cells: 11 floor quads", view.floor_cell_count, 11)
	var inner := view.get_node_or_null("Wall_2_2") as MeshInstance3D
	_check("the inner wall cell (2, 2) has a box", inner != null, true)
	if inner:
		_check_near_v3("its box stands on the cell, through the Tiles' offset and Units: (4.5, 1.1, 3.5) m", inner.position, Vector3(4.5, 1.1, 3.5), 0.0001)
	var sizes_ok := true
	var fades_ok := true
	var shader_ok := true
	for wall in view.walls:
		sizes_ok = sizes_ok and (wall.mesh as BoxMesh).size.is_equal_approx(Vector3(1.0, 2.2, 1.0))
		fades_ok = fades_ok and wall.is_in_group(&"fades")
		shader_ok = shader_ok and (wall.material_override as ShaderMaterial).shader == RoomView.FADE_SHADER
	_check("every wall box is 1 x 2.2 x 1 m (a cell wide, Ryan's 2.2 m tall)", sizes_ok, true)
	_check("every wall box is in the fades group", fades_ok, true)
	_check("every wall box uses the dithered fade shader", shader_ok, true)

	_check("the floor exists", view.floor_mesh != null, true)
	if view.floor_mesh:
		var aabb := view.floor_mesh.get_aabb()
		_check_near_v3("the floor covers cells 1..4 x 1..3: from (3, 0, 2) m", aabb.position, Vector3(3.0, 0.0, 2.0), 0.0001)
		_check_near_v3("4 m by 3 m, flat", aabb.size, Vector3(4.0, 0.0, 3.0), 0.0001)
		var arrays := view.floor_mesh.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var up_ok := normals.size() == verts.size()
		for n in normals:
			up_ok = up_ok and n.dot(Vector3.UP) > 0.9999   # normals are stored compressed: (0, 1, -0.000015)
		var front_ok := verts.size() == 11 * 6
		for i in range(0, verts.size(), 3):
			# Clockwise seen from above (Godot's front face): the cross points down.
			front_ok = front_ok and (verts[i + 1] - verts[i]).cross(verts[i + 2] - verts[i]).y < 0.0
		_check("its normals all point up", up_ok, true)
		_check("its 22 triangles all face up (clockwise from above)", front_ok, true)

	_check("the environment has a plain background", view.environment != null and view.environment.environment.background_mode == Environment.BG_COLOR, true)
	_check("the key light casts shadows", view.key_light != null and view.key_light.shadow_enabled, true)
	if view.key_light:
		var shine := -view.key_light.global_basis.z
		_check("the key light shines down, from the north-west (toward +x, -y, +z)", shine.y < 0.0 and shine.x > 0.0 and shine.z > 0.0, true)
	view.free()
	main.free()


func _test_fade() -> void:
	_section("Fade (dithered; whatever stands between the camera and the player)")
	var look: CameraLook = load("res://data/camera_looks/camera_look_default.tres")
	var feet := Vector3(10.0, 0.0, 8.0)
	var eye := feet + look.get_offset_m(16.0 / 9.0)
	var wall_h := 2.2
	_check("a 2.2 m wall cell right south of the player (toward the camera) blocks the view",
		WorldView.blocks_view(AABB(Vector3(9.5, 0.0, 8.5), Vector3(1.0, wall_h, 1.0)), eye, feet), true)
	_check("the next cell south blocks it too",
		WorldView.blocks_view(AABB(Vector3(9.5, 0.0, 9.5), Vector3(1.0, wall_h, 1.0)), eye, feet), true)
	_check("the one after doesn't: the camera sees over a 2.2 m wall 2.5 m away",
		WorldView.blocks_view(AABB(Vector3(9.5, 0.0, 10.5), Vector3(1.0, wall_h, 1.0)), eye, feet), false)
	_check("a 6 m pillar there does",
		WorldView.blocks_view(AABB(Vector3(9.5, 0.0, 10.5), Vector3(1.0, 6.0, 1.0)), eye, feet), true)
	_check("a wall north of the player (behind them) doesn't",
		WorldView.blocks_view(AABB(Vector3(9.5, 0.0, 6.5), Vector3(1.0, wall_h, 1.0)), eye, feet), false)
	_check("a wall touching the player's east side doesn't",
		WorldView.blocks_view(AABB(Vector3(10.34, 0.0, 7.5), Vector3(1.0, wall_h, 1.0)), eye, feet), false)
	# Only the head's line: a beam 1.9–2.5 m up, 0.4–0.6 m south of the player.
	# There the feet's line runs 0.5–0.7 m up, the chest's 1.4–1.6 m and the
	# head's 2.2–2.5 m.
	var beam := AABB(Vector3(9.5, 1.9, 8.4), Vector3(1.0, 0.6, 0.2))
	_check("a beam only the head's line crosses blocks the view (feet, chest and head all count)",
		WorldView.blocks_view(beam, eye, feet), true)

	var f := WorldView.step_fade(1.0, true, 0.09, look)
	_check_near("blocked: half the fade time goes half the way (1 -> 0.625)", f, 0.625, 0.0001)
	f = WorldView.step_fade(f, true, 0.09, look)
	_check_near("the whole fade time reaches 0.25", f, 0.25, 0.0001)
	f = WorldView.step_fade(f, true, 1.0, look)
	_check_near("and stays there", f, 0.25, 0.0001)
	f = WorldView.step_fade(f, false, 0.09, look)
	f = WorldView.step_fade(f, false, 0.09, look)
	_check_near("not blocked: back to 1 over the same 0.18 s", f, 1.0, 0.0001)
	var instant := look.duplicate() as CameraLook
	instant.fade_time = 0.0
	_check_near("a fade time of 0 jumps", WorldView.step_fade(1.0, true, 0.001, instant), 0.25, 0.0)


func _test_hide_sim() -> void:
	_section("Hiding the 2D world (visibility layer 2 'sim', the root's cull mask)")
	var main := _fixture_room()
	var room: Node2D = main.get_node("FixtureRoom")
	var viewport := get_viewport()
	var before := viewport.canvas_cull_mask
	var view := WorldView.new()
	add_child(view)
	view.hide_sim(main, room)
	_check("the room's root is on layer 2 only", room.visibility_layer, 2)
	_check("its Entities too", (room.get_node("Entities") as CanvasItem).visibility_layer, 2)
	_check("Main on layers 1 and 2", main.visibility_layer, 1 | 2)
	_check("the viewport no longer draws layer 2", viewport.canvas_cull_mask & 2, 0)
	_check("it still draws every other layer (layer 1: the HUD, menus)", viewport.canvas_cull_mask, before & ~2)
	_check("the Tiles keep their own layer (hidden through their parent)", (room.get_node("Tiles") as CanvasItem).visibility_layer, 1)
	remove_child(view)
	_check("the WorldView leaving the tree restores the viewport's mask", viewport.canvas_cull_mask, before)
	view.free()
	main.free()


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


func _check_near(label: String, actual: float, expected: float, tolerance: float) -> void:
	_report(absf(actual - expected) <= tolerance, label, "got %s, expected %s ± %s" % [actual, expected, tolerance])


func _check_near_v3(label: String, actual: Vector3, expected: Vector3, tolerance: float) -> void:
	_report(actual.distance_to(expected) <= tolerance, label, "got %s, expected %s ± %s" % [actual, expected, tolerance])


func _report(ok: bool, label: String, detail: String) -> void:
	if ok:
		_passed += 1
		print("  PASS  %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s: %s" % [label, detail])
