extends Node3D
## 3D pivot P2 test (docs/3D.md, Build order): open
## res://scenes/tests/view_test.tscn and press F6.
## Checks the 3D view's logic without drawing anything: the px <-> m mapping
## (Units), WorldView's physics priority, Main always showing the view (the
## flag use_3d_view and the 2D camera gone since the cleanup's C3; the hub's
## run plays room_01's layout), and the floor
## pick on a fixed camera at the default look (perspective, 30° field of
## view, 50° pitch, 30 m wide) over a 1 m floor grid with a raised plateau:
## the screen center, round trips, the plateau top, the exact shared vertices
## that made a single ray slip through in P0a, a blocker on another layer,
## and a miss.
## P3: CameraLook (its numbers, and on a real camera the visible width in
## both projections), RoomView on a fixture tile room (walls, floor, the
## environment and key light), the fade (what blocks the view, the fade's
## pace) and hiding the 2D world (and restoring it).
## P4: GameCamera3D (the old GameCamera's lean, centering, pan and shake as
## the same share of the screen, bounds, the follow pace) and the listener (it follows
## the focus; Audio's reach and panning scale with the view, and go back).
## P5: the aim's view side: the plane past the floor, a model's box on screen,
## the unit under a screen point (by its model, nearest box wins, the accept
## filter), and a tile room's floor pick (its walkable trimesh on layer 1, the
## plane through a wall cell's gap and past the room).
## P6: the views: nothing without a WorldView; a unit's UnitView (where, the
## placeholder capsule, the hit flash, the physics-tick follow, the facing
## rule, the swing clip's timing, a death outliving its unit); the Knight's
## placeholder model (hidden gear, 1.8 m, every clip the view and the data
## name); the projectile's bolt and slab, the aura's ring, the stun stars and
## the staggered mark over the model, each gone with its sim node.
## P7: the floor drawings (FloorOverlay: its settings, the window at the
## default look and its texel size, kept in the room and on whole texels, a
## sim point landing on the texel the floor's shader reads, following the
## camera; what draws into it: telegraphs, rings, slashes, a unit's own
## drawing, and not its HealthBar; true circles under the view), WorldView's
## setup of both overlays, the screen overlay (a unit's health bar over its
## model, fed by its health, hidden at its death, gone with it; a damage
## number over the model that stays where it appeared, and the path without
## a view), and VFX.spawn_scene() with a Node3D root.
## P8: rooms built in 3D. On a fixture layout built here: build_sim() (each
## footprint's collider on its kind's layer, in px; a derived wall outline;
## the markers in Entities with their properties; the spawn; a helper node
## moved in; the bounds) and the navigation bake (walls, fences and pits
## carved out); the validator silent on it and flagging an unmarked solid
## mesh, an empty footprint, a hull over an archway and a mesh sticking out,
## while a boulder's derived outline passes; footprints drawn in play only
## with debug_draw; WorldView taking a layout as the room's look. The real
## layouts: the 3D sandbox (the tile sandbox's markers and helpers) and
## room_01's layout (every wall cell of the tile room under a wall footprint
## and nothing else, the same slimes and spawn), both silent; their play
## scenes; the walking masks (fences block, pits wait).
## P9: terrain and airborne. status_airborne (tags, blocks, tenacity, cleanse,
## unstoppable, i-frames, juggles) and status_elevated; on a fixture layout
## with a plateau and a ramp: the ground grid, the derived ledges (along the
## plateau, none where the ramp joins it or at the ramp's foot) and their
## collider; ledges stop walking and the dash, not projectiles or sight; a
## path to the top of a plateau with no way up ends below it (Judgement's
## walk into range); a knock-up carries a unit over a fence and a ledge,
## walls still stop it, and it lands back out of a fence; on the 3D sandbox's
## stairs and ramp, a landing off their middle is nudged onto them, not sent
## back along its push (the P9 fix); the perch gives
## elevated by the unit's feet; under the view, the ground's height under the
## floor, the top and the ramp, a unit's view standing on the plateau, the
## knock-up's arc, the floor drawings' window covering lower floor; the 3D
## sandbox's terrain corner; no enemy knocks up the player.
## P7's 2D-only looks (after P9): swing arcs center on the body without a
## view and on the feet under it, every VFX.slash() call through
## VFX.drawing_origin(); the view warms up the pillar's shader at setup;
## VFX.impact()'s PillarView standing on the ground, its height, its shader,
## its fade, gone after its duration; nothing without a view.
## The cleanup's C3 (the 2D looks deleted): no 2D look nodes or scripts left,
## the HealthBar only as the overlay's settings, swing_side, the debug
## drawings on the floor, death_free_time, model_color and the dash ghosts'
## numbers; on the Knight's model (moved here from combat_test and
## abilities_test): the post-hit i-frame blink, and the cast and swing clips
## positioned by progress (a stun, an instant cast, a cancelled swing).
## LOOT L7: a drop's PickupView (the gem in its rarity's color, the hop's arc
## over the floor and onto a plateau's top, the bob and the turn, a
## Legendary's beam once it lands and none for an Exotic, gone when taken).
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

const NUMBER_STYLE: DamageNumberStyle = preload("res://data/damage_number_styles/damage_number_style_default.tres")

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
	_test_game_camera_3d()
	_test_aim_on_screen()
	await _test_views()
	await _test_room_floor_pick()
	await _test_floor_pick()
	_test_floor_overlay()
	_test_floor_drawings_layers()
	await _test_overlays_in_setup()
	_test_spawn_scene_3d()
	await _test_layout_sim()
	_test_layout_validator()
	await _test_layout_in_view()
	_test_real_layouts()
	_test_airborne_status()
	await _test_ledges()
	await _test_airborne_moves()
	await _test_landing_off_center()
	await _test_perch()
	await _test_terrain_in_view()
	_test_terrain_sandbox()
	await _test_leap_terrain()
	await _test_leap_sandbox()
	await _test_leap_in_view()
	await _test_blink_terrain()
	await _test_blink_in_view()
	await _test_pickup_view()
	await _test_arcs_and_pillars()
	await _test_2d_looks_gone()
	await _test_model_blink_and_clips()
	_test_enemy_poses()
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
	_section("Main always shows the 3D view (the cleanup's C3: use_3d_view and the 2D camera went)")
	var script: Script = load("res://scripts/main.gd")
	var main_props: Array[String] = []
	for p in script.get_script_property_list():
		main_props.append(String(p["name"]))
	_check("main.gd has no use_3d_view and no 2D camera any more", [main_props.has("use_3d_view"), main_props.has("camera"), main_props.has("world_view")], [false, false, true])
	var main_state := (load("res://scenes/main.tscn") as PackedScene).get_state()
	var node_names: Array[String] = []
	for i in main_state.get_node_count():
		node_names.append(String(main_state.get_node_name(i)))
	_check("main.tscn has no Camera node (GameCamera's)", node_names.has("Camera"), false)
	var set_flag: Array[String] = []
	for path in ["res://scenes/main.tscn", "res://scenes/sandbox_main.tscn", "res://scenes/main_layout.tscn", "res://scenes/sandbox_main_layout.tscn"]:
		var state := (load(path) as PackedScene).get_state()
		for i in state.get_node_property_count(0):
			if state.get_node_property_name(0, i) == &"use_3d_view":
				set_flag.append(path.get_file())
	_check("no play scene sets the old flag (%s)" % [set_flag], set_flag.is_empty(), true)
	_check("sandbox_main_3d.tscn (the same as sandbox_main.tscn since P-M) is gone", ResourceLoader.exists("res://scenes/sandbox_main_3d.tscn"), false)
	var hub_script: Script = load("res://scripts/ui/hub.gd")
	_check("the hub's Start run plays room_01's layout, its Sandbox the tile sandbox (Ryan, P-M)",
		[hub_script.get_property_default_value(&"run_scene"), hub_script.get_property_default_value(&"sandbox_scene")],
		["res://scenes/main_layout.tscn", "res://scenes/sandbox_main.tscn"])
	var hub_state := (load("res://scenes/ui/hub.tscn") as PackedScene).get_state()
	var hub_overrides := false
	for i in hub_state.get_node_property_count(0):
		hub_overrides = hub_overrides or hub_state.get_node_property_name(0, i) in [&"run_scene", &"sandbox_scene"]
	_check("and hub.tscn doesn't override them", hub_overrides, false)


# --- P3: CameraLook, RoomView, the fade, hiding the 2D world -------------------------------------

func _test_camera_look() -> void:
	_section("CameraLook (Ryan's picks after P0b)")
	var look: CameraLook = load("res://data/camera_looks/camera_look_default.tres")
	_check_exact("perspective", look.projection, CameraLook.ProjectionMode.PERSPECTIVE)
	_check("a 30° field of view", look.fov_deg, 30.0)
	_check("a 50° pitch", look.pitch_deg, 50.0)
	_check("30 m wide (Ryan, 2026-10-04; it was 28)", look.visible_width_m, 30.0)
	_check("faded things fade to 0.25", look.fade_to, 0.25)
	_check("over 0.18 s", look.fade_time, 0.18)
	_check_near("16:9: the camera sits 31.5 m from its focus", look.get_distance_m(16.0 / 9.0), 31.489, 0.001)
	var offset := look.get_offset_m(16.0 / 9.0)
	_check_near("16:9: 24.1 m above it", offset.y, 24.122, 0.001)
	_check_near("16:9: 20.2 m south of it", offset.z, 20.241, 0.001)
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
		_check_near("%s: 15 m west of the focus is the left edge (x px)" % name_, cam.unproject_position(focus + Vector3(-15.0, 0.0, 0.0)).x, 0.0, 0.05)
		_check_near("%s: 15 m east of it is the right edge (x px)" % name_, cam.unproject_position(focus + Vector3(15.0, 0.0, 0.0)).x, vis.x, 0.05)
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


# --- P4: GameCamera3D and the listener --------------------------------------------------------

func _test_game_camera_3d() -> void:
	_section("GameCamera3D (its lock, lean, pan, shake and bounds, tuned on CameraLook since the cleanup's C1; the listener)")
	var look: CameraLook = load("res://data/camera_looks/camera_look_default.tres")
	var vis := get_viewport().get_visible_rect().size
	var center := vis * 0.5
	var k := GameCamera3D.meters_per_screen_px(look, vis.x)

	var probe := GameCamera3D.new()
	var view := WorldView.new()
	_check("physics interpolation off (placed by code every frame)", probe.physics_interpolation_mode, Node.PHYSICS_INTERPOLATION_MODE_OFF)
	_check("it runs before WorldView's fade",
		probe.process_priority > 0 and probe.process_priority < view.process_priority, true)
	probe.free()
	view.free()
	_check("CameraLook holds GameCamera's tuning, the same values (follow 10; lean 80 px, dead zone 0.35, full at 0.9, y 0.6, easing 4, idle 0.5, hold 0.75 s, walk lean off; pan 420 px/s, margin 6 px; shake decay 16, held through the hitstop, directional since FEEL2 shipped preset 3; debug off)",
		[look.follow_smoothing_speed, look.aim_lead_px, look.aim_lead_dead_zone, look.aim_lead_full_at, look.aim_lead_y_scale,
			look.aim_lead_smoothing, look.aim_lead_idle_scale, look.aim_lead_hold_time, look.move_lead_px,
			look.edge_pan_speed_px, look.edge_margin_px, look.shake_decay_px, look.shake_after_hitstop, look.shake_directional, look.aim_lead_curve.resource_path, look.debug_draw],
		[10.0, 80.0, 0.35, 0.9, 0.6, 4.0, 0.5, 0.75, 0.0, 420.0, 6.0, 16.0, true, true, "res://data/curves/curve_camera_lead.tres", false])
	_check("GameCamera is gone (the cleanup's C3): CameraLook is the one place these are tuned",
		ResourceLoader.exists("res://scripts/camera/game_camera.gd"), false)
	_check_near("follow smoothing: GameCamera's speed 10 at 60 ticks is 10.94 per second", GameCamera3D.follow_rate_per_second(10.0, 60), 10.9393, 0.0001)
	_check_near("30 m across a 640 px wide screen: 0.046875 m per screen px", GameCamera3D.meters_per_screen_px(look, 640.0), 0.046875, 0.000001)
	_check_near("sounds reach 1.5 times as far: the view's 960 px over the 640 px screen", GameCamera3D.view_distance_scale(look, 640.0), 1.5, 0.000001)
	var floor_m := Rect2(1.0, 1.0, 28.0, 18.0)
	_check_exact("bounds: a focus on the room's floor stays", GameCamera3D.clamp_focus(Vector3(5.0, 0.0, 6.0), floor_m), Vector3(5.0, 0.0, 6.0))
	_check_exact("bounds: past the east and south edges it stops on them, its height kept",
		GameCamera3D.clamp_focus(Vector3(31.0, 0.5, 25.0), floor_m), Vector3(29.0, 0.5, 19.0))
	_check_exact("no bounds: anywhere", GameCamera3D.clamp_focus(Vector3(-50.0, 0.0, 90.0), Rect2()), Vector3(-50.0, 0.0, 90.0))

	# A camera following a target at FOCUS, on a copy of the look with no
	# follow smoothing (the focus jumps to its goal on each _process()) and no
	# edge pan (headless, the mouse sits in the window's corner). Its player is
	# a Player outside the tree: only its aiming state is read.
	var target := Node3D.new()
	target.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(target)
	target.global_position = FOCUS
	var test_look := look.duplicate() as CameraLook
	test_look.follow_smoothing_speed = 0.0
	test_look.edge_margin_px = -100000.0
	var cam := GameCamera3D.new()
	cam.look = test_look
	cam.target = target
	add_child(cam)
	cam.snap_to_target()
	_check_near("snapped: the target is the screen's center (px off)", cam.unproject_position(FOCUS).distance_to(center), 0.0, 0.01)
	_check_near_v3("80 px sideways on screen is 3.75 m on the floor (the same share of the screen as in 2D)", cam.screen_to_floor(Vector2(80.0, 0.0)), Vector3(3.75, 0.0, 0.0), 0.001)
	var up := cam.screen_to_floor(Vector2(0.0, -48.0))
	_check("48 px up the screen is north, and more floor than 48 px sideways (perspective at 50°)", up.z < -48.0 * k and absf(up.x) < 0.0001, true)
	var round_ok := 0
	var offsets: Array[Vector2] = [Vector2(80.0, 48.0), Vector2(-80.0, -48.0), Vector2(40.0, 24.0), Vector2(-7.0, 150.0), Vector2(250.0, -160.0)]
	for o in offsets:
		if cam.unproject_position(FOCUS + cam.screen_to_floor(o)).distance_to(center + o) <= 0.05:
			round_ok += 1
	_check("5 screen offsets: each floor point found projects back onto its screen point", round_ok, offsets.size())

	# The lean, from the real mouse (headless, Viewport.get_mouse_position()
	# reads Input's last motion event).
	var mouse_before := get_viewport().get_mouse_position()
	var point_mouse := func(canvas_pos: Vector2) -> void:
		var motion := InputEventMouseMotion.new()
		motion.position = get_viewport().get_screen_transform() * canvas_pos
		motion.global_position = motion.position
		Input.parse_input_event(motion)
		Input.flush_buffered_events()
	point_mouse.call(center + Vector2(vis.x * 0.5, 0.0))   # the screen's right edge, half way down
	cam._process(10.0)
	_check_near("no player: no lean, wherever the mouse is (px off)", cam.unproject_position(FOCUS).distance_to(center), 0.0, 0.01)
	var knight := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	cam.player = knight
	_check("with one, the full lean toward the mouse at the right edge is 80 px right", cam.get_aim_lead().is_equal_approx(Vector2(80.0, 0.0)), true)
	cam._process(10.0)
	_check_near("locked, the player not aiming: half of it (idle 0.5), the target 40 px left of the center (px off)",
		cam.unproject_position(FOCUS).distance_to(center + Vector2(-40.0, 0.0)), 0.0, 0.05)
	knight.aiming_slot = &"q"
	cam._process(10.0)
	_check_near("aiming: the full lean, the target 80 px left of the center (px off)",
		cam.unproject_position(FOCUS).distance_to(center + Vector2(-80.0, 0.0)), 0.0, 0.05)
	knight.aiming_slot = &""
	cam._process(0.5)
	_check("for aim_lead_hold_time (0.75 s) after the aim, still the full lean", cam.get_current_lead().is_equal_approx(Vector2(80.0, 0.0)), true)
	cam._process(10.0)
	_check_near("then back to half", cam.get_current_lead().x, 40.0, 0.01)
	point_mouse.call(center + Vector2(0.0, vis.y * 0.5))   # the bottom edge
	cam._process(10.0)
	_check_near("toward the bottom edge: 80 x 0.6 x 0.5 = 24 px down, the target 24 px above the center (px off)",
		cam.unproject_position(FOCUS).distance_to(center + Vector2(0.0, -24.0)), 0.0, 0.05)
	point_mouse.call(center + Vector2(vis.x * 0.1, 0.0))
	cam._process(10.0)
	_check_near("inside the dead zone (0.2 of the half-screen < 0.35): no lean (px off)", cam.unproject_position(FOCUS).distance_to(center), 0.0, 0.05)
	point_mouse.call(center + Vector2(vis.x * 0.5, 0.0))
	cam._process(10.0)
	Input.action_press(&"camera_center")
	cam._process(0.016)
	Input.action_release(&"camera_center")
	_check_near("holding C: centered, no lean (px off)", cam.unproject_position(FOCUS).distance_to(center), 0.0, 0.01)
	cam.bounds_m = Rect2(0.0, 0.0, 11.0, 20.0)
	knight.aiming_slot = &"q"
	cam._process(10.0)
	_check_near_v3("the room's floor ends 1 m east of the target: the lean stops there", cam.get_focus(), Vector3(11.0, 0.0, 8.0), 0.0001)
	cam.bounds_m = Rect2()
	knight.aiming_slot = &""
	cam.player = null
	point_mouse.call(mouse_before)
	cam._process(0.016)

	# The shake (GameFeel.shake() reaches this camera when it's current).
	cam.make_current()
	GameFeel.shake(10.0)
	cam._process(0.0)
	var offset := cam.shake_offset_px
	_check("GameFeel.shake(10) shakes the current 3D camera: up to 10 px each way",
		offset != Vector2.ZERO and absf(offset.x) <= 10.0 and absf(offset.y) <= 10.0, true)
	_check_near("h_offset is its x in px of floor", cam.h_offset, offset.x * k, 0.000001)
	_check_near("v_offset its y, up", cam.v_offset, -offset.y * k, 0.000001)
	_check_near("the picture moves as in 2D: the target moves against the offset (px off)",
		cam.unproject_position(FOCUS).distance_to(center - offset), 0.0, 0.05)
	cam._process(0.2)
	_check("it decays at 16 px a second (FEEL2 preset 3; 30 before), real time: up to 6.8 px after 0.2 s",
		absf(cam.shake_offset_px.x) <= 6.8 and absf(cam.shake_offset_px.y) <= 6.8, true)
	cam._process(0.45)
	_check("and it's gone (10 px at 16 px/s: 0.625 s)", cam.shake_offset_px, Vector2.ZERO)

	# The lock (Y) and the pan.
	var toggle := InputEventAction.new()
	toggle.action = &"camera_toggle_lock"
	toggle.pressed = true
	cam._unhandled_input(toggle)
	_check("Y unlocks it", cam.locked, false)
	var before := cam.get_focus()
	Input.action_press(&"camera_right")
	cam._process(0.1)
	Input.action_release(&"camera_right")
	_check_near_v3("unlocked, the right arrow for 0.1 s: 420 px/s of screen, 42 px = 1.84 m east",
		cam.get_focus() - before, Vector3(42.0 * k, 0.0, 0.0), 0.001)
	cam._unhandled_input(toggle)
	_check("Y again locks it", cam.locked, true)
	knight.free()

	# The listener and Audio's scale.
	var view_scale := GameCamera3D.view_distance_scale(look, vis.x)
	_check("the listener is current", cam.listener != null and cam.listener.is_current(), true)
	_check_near("Audio hears from the camera's focus, in px (px off)", Audio.get_listener_position().distance_to(Units.to_sim(cam.get_focus())), 0.0, 0.001)
	_check_near("Audio's reach is scaled to the view", Audio.distance_scale, view_scale, 0.000001)
	var ev := SoundEvent.new()
	ev.resource_name = "view_test_tone"
	var streams: Array[AudioStream] = [load("res://audio/sfx/hit_crit_01.wav")]
	ev.variations = streams
	ev.volume_db = -80.0
	ev.max_distance_px = 480.0
	var heard_from := Audio.get_listener_position()
	var h := Audio.play_at(ev, heard_from + Vector2(480.0 * view_scale - 10.0, 0.0))
	_check("a sound past its 480 px but inside 480 px x the scale starts", h > 0, true)
	var p2 := Audio.get_player(h) as AudioStreamPlayer2D
	_check_near("its player's reach is 480 px x the scale", p2.max_distance if p2 else 0.0, 480.0 * view_scale, 0.001)
	_check_near("its panning strength is 1 / the scale", p2.panning_strength if p2 else 0.0, 1.0 / view_scale, 0.0001)
	_check("one beyond 480 px x the scale isn't started", Audio.play_at(ev, heard_from + Vector2(480.0 * view_scale + 10.0, 0.0)), 0)
	_check("logged out_of_range", Audio.get_log()[-1].reason, &"out_of_range")
	Audio.stop_all()
	remove_child(cam)
	_check("the camera gone: Audio's reach is the data's again (scale 1)", Audio.distance_scale, 1.0)
	_check("and no listener: sounds are heard from the screen center again", get_viewport().get_audio_listener_2d() == null, true)
	cam.free()
	target.free()


# --- P5: the aim's view side ----------------------------------------------------------------

## A GameCamera3D (no 2D source: locked, no lean) looking at a target placed
## at `focus`, under `parent` (the camera's `target`).
func _aim_camera(parent: Node, focus: Vector3) -> GameCamera3D:
	var target := Node3D.new()
	target.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parent.add_child(target)
	target.global_position = focus
	var cam := GameCamera3D.new()
	cam.target = target
	parent.add_child(cam)
	cam.make_current()
	cam.snap_to_target()
	return cam


func _test_aim_on_screen() -> void:
	_section("The aim on screen (P5: the plane, a model's box, the unit under a point)")
	var view := WorldView.new()
	add_child(view)
	view.camera = _aim_camera(view, FOCUS)
	var cam := view.camera
	var center := get_viewport().get_visible_rect().size * 0.5

	_check_near_v3("the plane: the screen's center meets it at the focus", WorldView.pick_plane(cam, center, 0.0), FOCUS, 0.001)
	var corner_hit := WorldView.pick_plane(cam, Vector2(1.0, 1.0), 0.0)
	_check("the screen's top corner meets it too (still 35° down there), north of the focus",
		corner_hit != Vector3.INF and corner_hit.z < FOCUS.z, true)
	_check_near("a plane point projects back onto its screen point (px off)",
		cam.unproject_position(WorldView.pick_plane(cam, center + Vector2(130.0, -90.0), 0.0)).distance_to(center + Vector2(130.0, -90.0)), 0.0, 0.05)

	# Three slimes: A at the focus, C 0.3 m north of it (their boxes overlap on
	# screen), B 2 m north. Their views (UnitView, P6): placeholder capsules from
	# their gameplay radius (0.55 m), 1.32 m tall, with a facing nub.
	var slime_scene: PackedScene = load("res://scenes/enemies/slime.tscn")
	var a := slime_scene.instantiate() as Unit
	var b := slime_scene.instantiate() as Unit
	var c := slime_scene.instantiate() as Unit
	for pair: Array in [[a, FOCUS], [b, FOCUS + Vector3(0.0, 0.0, -2.0)], [c, FOCUS + Vector3(0.0, 0.0, -0.3)]]:
		var u: Unit = pair[0]
		add_child(u)
		u.global_position = Units.to_sim(pair[1])
		view._add_view(u)
	var root_a: Node3D = view.view_of(a)
	var rect_a := WorldView.screen_rect_of(cam, root_a)
	var k := GameCamera3D.meters_per_screen_px(cam.look, center.x * 2.0)
	_check("A's box on screen holds its feet and its head",
		rect_a.grow(0.01).has_point(cam.unproject_position(FOCUS)) and rect_a.grow(0.01).has_point(cam.unproject_position(FOCUS + Vector3(0.0, 1.0, 0.0))), true)
	_check("about as wide as the capsule (1.1 m = %.1f px; a bit more for its depth): %.1f px" % [1.1 / k, rect_a.size.x],
		rect_a.size.x >= 1.1 / k - 0.5 and rect_a.size.x <= 1.1 / k + 3.0, true)
	var any := func(_u: Unit) -> bool: return true
	var mid_a := cam.unproject_position(FOCUS + Vector3(0.0, 0.5, 0.0))
	_check("the cursor on A's body (half way up, above its feet on screen): A", view.unit_at_screen_point(mid_a, any) == a, true)
	_check("the cursor at A's box's center, where C's box overlaps: A (the nearest box center)", view.unit_at_screen_point(rect_a.get_center(), any) == a, true)
	var rect_c := WorldView.screen_rect_of(cam, view.view_of(c))
	_check("at C's box's center: C", view.unit_at_screen_point(rect_c.get_center(), any) == c, true)
	_check("on B's body: B", view.unit_at_screen_point(cam.unproject_position(FOCUS + Vector3(0.0, 0.5, -2.0)), any) == b, true)
	_check("5 m above A (above B's box too): nobody", view.unit_at_screen_point(cam.unproject_position(FOCUS + Vector3(0.0, 5.0, 0.0)), any) == null, true)
	var not_a_or_c := func(u: Unit) -> bool: return u != a and u != c
	_check("on A's body, with A and C refused (dead, a friend): nobody (B is 2 m away)", view.unit_at_screen_point(mid_a, not_a_or_c) == null, true)
	var bare := WorldView.new()
	_check("without a camera: nobody", bare.unit_at_screen_point(mid_a, any) == null, true)
	bare.free()
	for u: Unit in [a, b, c]:
		u.free()
	view.free()


# --- P6: the views ------------------------------------------------------------------------------

func _test_views() -> void:
	_section("Views (P6: the mechanism, UnitView, the Knight's model, projectile, aura, status VFX)")
	var slime_scene: PackedScene = load("res://scenes/enemies/slime.tscn")

	var lone := slime_scene.instantiate() as Unit
	add_child(lone)
	_check("a unit is a view source (the group view_source, get_view_scene())", lone.is_in_group(&"view_source") and lone.has_method(&"get_view_scene"), true)
	_check("without a WorldView no view is built", find_children("View_*", "", true, false).is_empty(), true)
	lone.free()

	var view := WorldView.new()
	add_child(view)
	view.camera = _aim_camera(view, FOCUS)
	view.watch_sim()

	# A unit's UnitView.
	var s := slime_scene.instantiate() as Unit
	s.position = Units.to_sim(FOCUS + Vector3(1.0, 0.0, 0.0))
	add_child(s)
	var sv := view.view_of(s) as UnitView
	_check("a unit added while the WorldView watches gets a UnitView, under it, named after it",
		sv != null and sv.get_parent() == view and String(sv.name) == "View_" + s.name, true)
	if sv == null:
		view.free()
		s.free()
		return
	_check_near_v3("at the unit's feet, in meters", sv.position, FOCUS + Vector3(1.0, 0.0, 0.0), 0.0001)
	var capsule := sv.find_child("Capsule", true, false) as MeshInstance3D
	_check("no model_scene: a placeholder capsule as wide as its gameplay radius (55 u = 0.55 m)",
		capsule != null and is_equal_approx((capsule.mesh as CapsuleMesh).radius, 0.55), true)
	_check_near("1.32 m tall (2.4 x the radius): its model height", sv.model_height_m, 1.32, 0.0001)
	var overlays_ok := true
	for geo in sv.find_children("*", "GeometryInstance3D", true, false):
		var overlay := (geo as GeometryInstance3D).material_overlay as ShaderMaterial
		overlays_ok = overlays_ok and overlay != null and overlay.shader == UnitView.FLASH_SHADER
	_check("every mesh carries the hit-flash overlay", overlays_ok, true)
	s.damaged.emit(5.0, null)
	_check_near("a hit lights the flash (its instance value)", float(capsule.get_instance_shader_parameter(&"flash")), sv.flash_strength, 0.0001)
	s.global_position += Vector2(64.0, 32.0)
	view._physics_process(1.0 / 60.0)
	_check_near_v3("the physics tick moves the view after its unit (2 m east, 1 m south)", sv.position, FOCUS + Vector3(3.0, 0.0, 1.0), 0.0001)
	_check_near_v3("a glTF model faces +z: the yaw atan2(x, y) turns +z to a facing (east here)",
		Basis(Vector3.UP, atan2(1.0, 0.0)) * Vector3.BACK, Vector3.RIGHT, 0.0001)
	_check_near("a swing clip at progress 0 stands at its start (0.18 of it)", UnitView.action_clip_share(0.0, 0.27, 0.18, 0.42, 0.85), 0.18, 0.0001)
	_check_near("half way to the hit, half way to the strike", UnitView.action_clip_share(0.135, 0.27, 0.18, 0.42, 0.85), 0.30, 0.0001)
	_check_near("at the hit (the windup's share of the swing): the strike frame", UnitView.action_clip_share(0.27, 0.27, 0.18, 0.42, 0.85), 0.42, 0.0001)
	_check_near("at the swing's end: the clip's end (0.85)", UnitView.action_clip_share(1.0, 0.27, 0.18, 0.42, 0.85), 0.85, 0.0001)

	# A death outlives its unit; a unit just removed takes its view along.
	sv.death_linger = 0.1
	s.died.emit(s)
	s.free()
	_check("a dead unit freed: its view stays for its death", is_instance_valid(sv) and sv.is_sim_gone(), true)
	await get_tree().create_timer(0.25).timeout
	_check("then goes (death_linger)", is_instance_valid(sv), false)
	var s2 := slime_scene.instantiate() as Unit
	s2.position = Units.to_sim(FOCUS)
	add_child(s2)
	var gone := view.view_of(s2)
	remove_child(s2)
	s2.free()
	await get_tree().process_frame
	_check("a living unit removed: its view goes at once", is_instance_valid(gone), false)

	# The Knight's placeholder model (3D.md, Data, Models).
	var knight_data: ChampionData = load("res://data/champions/knight.tres")
	_check("the Knight's ChampionData points at the placeholder model",
		knight_data.model_scene != null and knight_data.model_scene.resource_path == "res://art/models/placeholder/kaykit_knight/kaykit_knight.tscn", true)
	var model := knight_data.model_scene.instantiate() as Node3D
	add_child(model)
	var hidden_ok := true
	for gear: String in ["1H_Sword_Offhand", "Rectangle_Shield", "Round_Shield", "Spike_Shield", "2H_Sword"]:
		var n := model.find_child(gear, true, false) as Node3D
		hidden_ok = hidden_ok and n != null and not n.visible
	_check("its spare weapons and three of four shields are hidden", hidden_ok, true)
	_check("it keeps its sword and its badge shield",
		(model.find_child("1H_Sword", true, false) as Node3D).visible and (model.find_child("Badge_Shield", true, false) as Node3D).visible, true)
	var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	anim.play(&"Idle")
	anim.seek(0.0, true)
	await get_tree().process_frame
	var helmet := model.find_child("Knight_Helmet", true, false) as MeshInstance3D
	_check_near("it's 1.8 m tall (its helmet's top, standing idle)", (helmet.global_transform * helmet.get_aabb()).end.y, 1.8, 0.02)
	var defaults := UnitView.new()
	var role_clips: Array[StringName] = [defaults.idle_clip, defaults.run_clip, defaults.dash_clip, defaults.hit_clip, defaults.stun_clip, defaults.death_clip]
	defaults.free()
	var data_clips: Array[StringName] = []
	for a: String in ["knight_q_cleave", "knight_q_cleave_wave", "knight_w_iron_resolve", "knight_e_lunge", "knight_r_judgement"]:
		data_clips.append((load("res://data/abilities/%s.tres" % a) as Ability).cast_anim)
	var combo: AttackCombo = load("res://data/combos/combo_knight.tres")
	for swing in combo.swings:
		data_clips.append(swing.swing_anim)
	data_clips.append(combo.dash_strike.swing_anim)
	var missing: Array[StringName] = []
	for clip in role_clips + data_clips:
		if not anim.has_animation(clip):
			missing.append(clip)
	_check("it has every clip UnitView's roles and the Knight's hooks name (missing: %s)" % [missing], missing.is_empty(), true)
	model.free()

	# A projectile's bolt.
	var lunge: Ability = load("res://data/abilities/knight_e_lunge.tres")
	var bolt := Projectile.new()
	bolt.ability = lunge
	bolt.direction = Vector2.RIGHT
	bolt.half_width_px = 4.0
	bolt.process_mode = Node.PROCESS_MODE_DISABLED   # no caster: it only has to be seen
	bolt.position = Units.to_sim(FOCUS)
	add_child(bolt)
	var bv := view.view_of(bolt)
	_check("a projectile gets its bolt", bv != null and bv.find_child("Bolt", true, false) != null, true)
	if bv:
		_check_near("at chest height (0.9 m)", bv.position.y, 0.9, 0.0001)
		_check_near("turned along its flight (east: yaw 90°)", rad_to_deg(bv.rotation.y), 90.0, 0.01)
		var bolt_mesh := bv.find_child("Bolt", true, false) as MeshInstance3D
		_check("tinted by its ability's icon_color", (bolt_mesh.material_override as StandardMaterial3D).albedo_color.is_equal_approx(lunge.icon_color), true)
	var wave := Projectile.new()
	wave.ability = lunge
	wave.direction = Vector2.DOWN
	wave.half_width_px = 32.0
	wave.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(wave)
	var wv := view.view_of(wave)
	var slab := wv.find_child("Bolt", true, false) as MeshInstance3D if wv else null
	_check("a wide one (a wave, 1 m half width) is a slab 2 m across its path",
		slab != null and slab.mesh is BoxMesh and is_equal_approx((slab.mesh as BoxMesh).size.x, 2.0), true)
	bolt.free()
	_check("a projectile gone: its view stays for the impact flash", is_instance_valid(bv), true)
	wave.free()

	# An aura and the status VFX, on a unit with a view.
	var host := slime_scene.instantiate() as Unit
	host.position = Units.to_sim(FOCUS)
	add_child(host)
	var host_view := view.view_of(host) as UnitView
	VFX.aura(host, Color(1.0, 0.78, 0.3), func() -> bool: return true, 10.0)
	var aura := host.get_child(host.get_child_count() - 1)
	var av := view.view_of(aura)
	_check("an aura gets its ring", av != null and av.find_child("Ring", true, false) != null, true)
	if av:
		var torus := (av.find_child("Ring", true, false) as MeshInstance3D).mesh as TorusMesh
		_check_near("as wide as the 2D ring (0.8 x the gameplay radius: 0.44 m)", (torus.inner_radius + torus.outer_radius) * 0.5, 0.44, 0.0001)
		_check_near_v3("on the floor under the unit", av.position, FOCUS, 0.0001)
	await get_tree().process_frame
	aura.free()
	await get_tree().process_frame
	_check("the aura gone: its ring goes", is_instance_valid(av), false)

	host.status_component.apply_status(load("res://data/statuses/status_stun.tres"), null, 5.0)
	var stars_node := host.find_child("StunStars", true, false)
	var stars := view.view_of(stars_node)
	_check("a stun's stars get their view", stars != null, true)
	if stars:
		_check_near("over the unit's model (its 1.32 m, + 0.2 m)", stars.position.y, host_view.model_height_m + 0.2, 0.0001)
		_check_near("above its feet (where the unit stands)", Vector2(stars.position.x, stars.position.z).distance_to(Vector2(FOCUS.x, FOCUS.z)), 0.0, 0.0001)
	host.status_component.apply_status(load("res://data/statuses/status_staggered.tres"), null, 5.0)
	var mark := view.view_of(host.find_child("StaggeredMark", true, false))
	_check("Staggered's mark gets its view, over the model (+ 0.3 m)", mark != null and is_equal_approx(mark.position.y, host_view.model_height_m + 0.3), true)
	host.status_component.clear()
	await get_tree().process_frame
	_check("the statuses gone: their views go", is_instance_valid(stars) or is_instance_valid(mark), false)
	host.free()
	view.free()


func _test_room_floor_pick() -> void:
	_section("A tile room's floor pick (P5: RoomView's walkable trimesh, the plane past it)")
	var main := _fixture_room()
	var room_view := RoomView.new()
	add_child(room_view)
	room_view.build(main.get_node("FixtureRoom/Tiles") as TileMapLayer)
	_check("the floor is walkable", room_view.floor_mesh.is_in_group(&"walkable"), true)
	_check("its pick body is on 3D layer 1 only, and collides with nothing",
		room_view.floor_body != null and room_view.floor_body.collision_layer == WorldView.FLOOR_LAYER and room_view.floor_body.collision_mask == 0, true)
	var view := WorldView.new()
	add_child(view)
	var room_center := Vector3(5.0, 0.0, 3.5)
	view.camera = _aim_camera(view, room_center)
	var cam := view.camera
	# Bodies join the physics space on the next physics step.
	await get_tree().physics_frame
	await get_tree().physics_frame

	var on_floor := Vector3(3.3, 0.0, 2.6)
	_check_near_v3("a floor cell under the cursor: the pick lands on it", WorldView.pick_floor(cam, cam.unproject_position(on_floor)), on_floor, 0.01)
	_check_near("in sim px too (px off)", view.floor_at_screen_px(cam.unproject_position(on_floor)).distance_to(Units.to_sim(on_floor)), 0.0, 0.5)
	var in_wall := Vector3(4.5, 0.0, 3.5)
	_check_exact("the inner wall's cell has no floor: the trimesh misses there", WorldView.pick_floor(cam, cam.unproject_position(in_wall)), Vector3.INF)
	_check_near("so the aim takes the plane: the wall cell's middle (px off)", view.floor_at_screen_px(cam.unproject_position(in_wall)).distance_to(Units.to_sim(in_wall)), 0.0, 0.5)
	var past_room := Vector3(17.0, 0.0, 3.5)
	_check_exact("past the room: the trimesh misses", WorldView.pick_floor(cam, cam.unproject_position(past_room)), Vector3.INF)
	_check_near("the aim still points there, on the plane (px off)", view.floor_at_screen_px(cam.unproject_position(past_room)).distance_to(Units.to_sim(past_room)), 0.0, 0.5)
	var bare := WorldView.new()
	_check_exact("without a camera: INF", bare.floor_at_screen_px(Vector2.ZERO), Vector2.INF)
	bare.free()
	view.free()
	room_view.free()
	main.free()


# --- Floor pick -------------------------------------------------------------------------------

func _test_floor_pick() -> void:
	_section("Floor pick (fixed camera: perspective 30°, 50° pitch, 30 m wide)")
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


# --- P7: floor drawings, the screen overlay, 3D hook scenes ---------------------------------------

func _test_floor_overlay() -> void:
	_section("FloorOverlay (P7: the floor drawings' window and its mapping)")
	_check("floor drawings are canvas visibility layer 3 (its bit: 4)", FloorOverlay.DRAWING_VISIBILITY_BIT, 4)
	var probe := FloorOverlay.new()
	_check("a transparent target, no 3D, redrawn every frame",
		probe.transparent_bg and probe.disable_3d and probe.render_target_update_mode == SubViewport.UPDATE_ALWAYS, true)
	_check("it draws layers 2 ('sim': the room's root and Entities, which draw nothing) and 3 only", probe.canvas_cull_mask, 2 | 4)
	_check("it moves its window after GameCamera3D has moved", probe.process_priority > GameCamera3D.PROCESS_PRIORITY, true)
	_check_near("2 texels per sim px: 64 per meter", probe.get_texels_per_m(), 64.0, 0.0)
	probe.free()

	# The game's 640x360 canvas (16:9). The headless test window is square, so
	# the camera gets a viewport of its own.
	var screen := SubViewport.new()
	screen.size = Vector2i(640, 360)
	screen.disable_3d = true   # projections only; nothing is drawn
	add_child(screen)
	var view := WorldView.new()
	screen.add_child(view)
	var cam := _aim_camera(view, FOCUS)
	var seen := FloorOverlay.seen_floor_around_focus_m(cam)
	var half := Vector2(320.0, 180.0)
	var bottom := cam.screen_to_floor(Vector2(half.x, half.y)) - cam.screen_to_floor(Vector2(-half.x, half.y))
	_check_near("the default look sees 24.5 m of floor across at the screen's bottom edge", bottom.x, 24.49, 0.05)
	_check_near("38.7 m across at its top edge (the widest)", seen.size.x, 38.70, 0.05)
	_check_near("from 9.0 m in front of the focus (south)", seen.end.y, 8.99, 0.05)
	_check_near("to 14.2 m beyond it (north): 23.2 m deep", -seen.position.y, 14.21, 0.05)
	_check_near("centered across the focus", seen.get_center().x, 0.0, 0.001)
	var with_margin := seen.grow(2.0).size
	_check_exact("with the 2 m margin (42.7 x 27.2 m): 2752 x 1792 texels, multiples of 64",
		FloorOverlay.window_size_texels(with_margin, 64.0, Rect2()), Vector2i(2752, 1792))
	_check_exact("in a 30 x 20 m room (smaller than the window): the room, 1920 x 1280",
		FloorOverlay.window_size_texels(with_margin, 64.0, Rect2(0.0, 0.0, 30.0, 20.0)), Vector2i(1920, 1280))

	var big := Rect2(0.0, 0.0, 100.0, 80.0)
	var size_m := Vector2(2624.0, 1664.0) / 64.0   # 41 x 26 m
	_check_exact("in a big room the window's corner goes where it's asked, on a whole texel (1/64 m)",
		FloorOverlay.window_origin_m(Vector2(20.013, 30.3), size_m, big, 64.0), Vector2(1281.0, 1939.0) / 64.0)
	_check_exact("past the room's west and north edges it stops on them",
		FloorOverlay.window_origin_m(Vector2(-5.0, -3.0), size_m, big, 64.0), Vector2.ZERO)
	_check_exact("past its east and south edges, the window's far side stops on them",
		FloorOverlay.window_origin_m(Vector2(90.0, 70.0), size_m, big, 64.0), Vector2(59.0, 54.0))
	_check_exact("a room smaller than the window: the room's corner, wherever the camera is",
		FloorOverlay.window_origin_m(Vector2(7.0, 9.0), Vector2(30.0, 20.0), Rect2(2.0, 3.0, 30.0, 20.0), 64.0), Vector2(2.0, 3.0))

	# The mapping: the canvas transform draws a sim point on the texel that the
	# floor's shader reads at that point's x/z (uv = (x/z - origin) / size).
	var corner := Vector2(12.5, 7.25)
	var xf := FloorOverlay.window_canvas_transform(corner, 2.0)
	var texels := Vector2(2624.0, 1664.0)
	var mapped_ok := true
	for p: Vector2 in [Vector2(400.0, 232.0), Vector2(1000.0, 700.0), Vector2(417.3, 251.9), Vector2(1500.0, 1000.0)]:
		var v := Units.to_view(p)
		var uv := (Vector2(v.x, v.z) - corner) / (texels / 64.0)
		mapped_ok = mapped_ok and (xf * p).is_equal_approx(uv * texels)
	_check("a sim point lands on the texel the floor's shader reads at its x/z (4 points): a drawing lies on its sim shape", mapped_ok, true)
	_check_exact("the window's corner, (12.5, 7.25) m = (400, 232) px, is texel (0, 0)", xf * Vector2(400.0, 232.0), Vector2.ZERO)
	_check_near("the elite slam's 40 px radius is 80 texels: 1.25 m on the floor, as in the sim", (xf * Vector2(440.0, 232.0)).x / 64.0, 1.25, 0.000001)

	# Live, on the camera.
	var overlay := FloorOverlay.new()
	overlay.world_2d = get_viewport().world_2d
	view.add_child(overlay)
	overlay.setup(cam, Rect2())
	_check_exact("set up on the camera: the texture is the window's size", overlay.size, Vector2i(2752, 1792))
	var material := ShaderMaterial.new()
	material.shader = RoomView.FLOOR_SHADER
	overlay.add_floor_material(material)
	_check("a floor material shows its texture, its corner and its size",
		material.get_shader_parameter(&"drawings") == overlay.get_texture()
		and (material.get_shader_parameter(&"drawings_origin_m") as Vector2).is_equal_approx(overlay.origin_m)
		and (material.get_shader_parameter(&"drawings_size_m") as Vector2).is_equal_approx(Vector2(43.0, 28.0)), true)
	var focus_xz := Vector2(FOCUS.x, FOCUS.z)
	_check("the window holds all the floor the camera sees",
		Rect2(overlay.origin_m, overlay.get_size_m()).encloses(Rect2(focus_xz + seen.position, seen.size)), true)
	var before := overlay.origin_m
	cam.target.global_position = FOCUS + Vector3(3.3, 0.0, -1.7)
	cam.snap_to_target()
	overlay.update_window()
	var moved := overlay.origin_m - before
	_check("the camera moved 3.3 m east, 1.7 m north: the window follows (to the texel)",
		absf(moved.x - 3.3) <= 0.5 / 64.0 + 0.00001 and absf(moved.y + 1.7) <= 0.5 / 64.0 + 0.00001, true)
	_check("still on whole texels", (overlay.origin_m * 64.0).is_equal_approx((overlay.origin_m * 64.0).round()), true)
	_check("its canvas transform and the floor's material moved with it",
		overlay.canvas_transform.is_equal_approx(FloorOverlay.window_canvas_transform(overlay.origin_m, 2.0))
		and (material.get_shader_parameter(&"drawings_origin_m") as Vector2).is_equal_approx(overlay.origin_m), true)
	_check_exact("the texture keeps its size (only the screen's shape changes it)", overlay.size, Vector2i(2752, 1792))
	var room_overlay := FloorOverlay.new()
	view.add_child(room_overlay)
	room_overlay.setup(cam, Rect2(0.0, 0.0, 30.0, 20.0))
	_check("in a 30 x 20 m room: the room's size, at its corner",
		room_overlay.size == Vector2i(1920, 1280) and room_overlay.origin_m == Vector2.ZERO, true)
	screen.free()


func _test_floor_drawings_layers() -> void:
	_section("What draws on the floor (P7: layer 3; true circles under the view)")
	var slime_scene: PackedScene = load("res://scenes/enemies/slime.tscn")
	var main := _fixture_room()
	var room: Node2D = main.get_node("FixtureRoom")
	var entities: Node2D = room.get_node("Entities")
	var view := WorldView.new()
	add_child(view)
	view.hide_sim(main, room)
	var probe := FloorOverlay.new()
	var mask := probe.canvas_cull_mask
	probe.free()
	var slime := slime_scene.instantiate() as Unit
	slime.position = Vector2(112.0, 80.0)
	entities.add_child(slime)

	var tele := Telegraph.circle(slime, slime.global_position, 40.0, 0.75)
	_check("a telegraph is a floor drawing (layers 1 and 3: still drawn in 2D)", tele.visibility_layer, 1 | 4)
	_check("on the room's floor, under the room's root (layer 2: drawn by the overlay, hidden from the screen)",
		tele.get_parent() == room and (room.visibility_layer & mask) != 0 and (room.visibility_layer & get_viewport().canvas_cull_mask) == 0, true)
	_check("every ancestor of a floor drawing passes the overlay's mask (Main, the room, Entities)",
		(main.visibility_layer & mask) != 0 and (entities.visibility_layer & mask) != 0, true)
	VFX.ring(entities, Vector2(112.0, 80.0), 4.0, 10.0, Color.WHITE)
	VFX.slash(entities, Vector2(112.0, 80.0), 0.0, 8.0, 30.0, 1.0)
	var ring := entities.find_children("*", "Line2D", false, false)
	var slash := entities.find_children("*", "Polygon2D", false, false)
	_check("VFX.ring() and VFX.slash() draw on the floor too (layers 1 and 3)",
		ring.size() == 1 and slash.size() == 1 and (ring[0] as CanvasItem).visibility_layer == 1 | 4 and (slash[0] as CanvasItem).visibility_layer == 1 | 4, true)
	_check("a unit's own drawing (its hover ring, the player's indicators) is a floor drawing", slime.visibility_layer, 1 | 4)
	_check("its HealthBar (the overlay's settings) isn't: the overlay culls it; it has no 2D body (the cleanup's C3)",
		((slime.get_node("HealthBar") as CanvasItem).visibility_layer & mask) == 0 and slime.get_node_or_null(^"Body") == null, true)

	_check_near("without the view, floor circles are squashed 0.55 (the 2D game's 3/4 look)", VFX.floor_squash, 0.55, 0.0)
	_check_near("so is a ring's outline", _ring_height(entities), 0.55, 0.0001)
	view.flatten_floor_drawings()
	_check_near("with it, true circles: the camera foreshortens the floor itself", VFX.floor_squash, 1.0, 0.0)
	_check_near("a ring's outline is round", _ring_height(entities), 1.0, 0.0001)
	view.free()
	_check_near("the view gone: the 2D squash is back", VFX.floor_squash, 0.55, 0.0)

	var rv := RoomView.new()
	add_child(rv)
	rv.build(main.get_node("FixtureRoom/Tiles") as TileMapLayer)
	_check("the room's floor lays the drawings on it (floor_drawings.gdshader, roughness 0.95 as before)",
		rv.floor_mesh.material_override == rv.floor_material and rv.floor_material.shader == RoomView.FLOOR_SHADER
		and is_equal_approx(float(rv.floor_material.get_shader_parameter(&"roughness")), 0.95), true)
	rv.free()
	main.free()


## A new VFX.ring()'s outline: its north-south extent over its east-west one.
func _ring_height(parent: Node) -> float:
	VFX.ring(parent, Vector2.ZERO, 1.0, 2.0, Color.WHITE)
	var line := parent.get_child(parent.get_child_count() - 1) as Line2D
	var top := 0.0
	var right := 0.0
	for p in line.points:
		top = maxf(top, absf(p.y))
		right = maxf(right, absf(p.x))
	return top / right


func _test_overlays_in_setup() -> void:
	_section("The overlays in WorldView.setup(), the screen overlay (P7)")
	var slime_scene: PackedScene = load("res://scenes/enemies/slime.tscn")
	var world_2d := Node2D.new()
	add_child(world_2d)
	var lone := slime_scene.instantiate() as Unit
	world_2d.add_child(lone)
	lone.show_heal_number(7.0)
	var labels := world_2d.find_children("*", "Label", false, false)
	_check("without a WorldView (WorldView.of(): null) a number takes the 2D path: next to its unit",
		WorldView.of(lone) == null and labels.size() == 1 and (labels[0] as Label).text == "+7", true)
	world_2d.free()

	var main := _fixture_room()
	var room: Node2D = main.get_node("FixtureRoom")
	var entities: Node2D = room.get_node("Entities")
	var slime := slime_scene.instantiate() as Unit
	slime.position = Vector2(112.0, 80.0)   # a floor cell
	entities.add_child(slime)
	var view := WorldView.new()
	main.add_child(view)
	view.setup(main, room, null)
	var cam := view.camera
	var screen := view.screen_overlay
	_check("WorldView.of() finds it from any sim node (the group world_view)", WorldView.of(slime) == view, true)
	_check("setup made the floor overlay, sharing the sim's World2D",
		view.floor_overlay != null and view.floor_overlay.get_parent() == view and view.floor_overlay.world_2d == get_viewport().world_2d, true)
	_check("the room's floor shows its drawings", view.room_view.floor_material.get_shader_parameter(&"drawings") == view.floor_overlay.get_texture(), true)
	_check("and the screen overlay, under the HUD (CanvasLayer 1), placed after the camera has moved",
		screen != null and screen.layer < 1 and screen.process_priority > GameCamera3D.PROCESS_PRIORITY, true)
	_check_near("floor circles are true circles while it shows the game", VFX.floor_squash, 1.0, 0.0)

	# The health bar.
	var bar := screen.bar_of(slime)
	var source := slime.get_node("HealthBar") as Node2D
	_check("a unit there at setup got its health bar: a copy of its HealthBar's settings (its width, its color)",
		bar != null and is_equal_approx(float(bar.get(&"width")), float(source.get(&"width"))) and bar.get(&"fill_color") == source.get(&"fill_color"), true)
	if bar == null:
		main.free()
		return
	slime.health.take_damage(5.0)
	_check_near("fed by the unit's HealthComponent", float(bar.get(&"_current")), slime.health.current, 0.0001)
	screen._process(0.0)
	var head := screen.point_over(slime, 1.0)
	_check_near("the head: the model's 1.32 m over its feet", head.y, 1.32, 0.0001)
	_check_near("the bar's bottom sits 3 px over the head on screen (px off)",
		bar.position.distance_to(cam.unproject_position(head) - Vector2(0.0, 3.0 + float(bar.get(&"height")))), 0.0, 0.001)
	source.visible = false
	screen._process(0.0)
	_check("the unit's HealthBar node hidden doesn't hide the copy (it follows the unit's death since the cleanup's C2)", bar.visible, true)
	source.visible = true
	var late := slime_scene.instantiate() as Unit
	late.position = Vector2(144.0, 80.0)
	entities.add_child(late)
	_check("a unit added later gets its bar with its view", screen.bar_of(late) != null, true)
	var late_bar := screen.bar_of(late)
	late.health.take_damage(late.health.max_health * 10.0)
	screen._process(0.0)
	_check("its death hides its copy", late_bar.visible if late_bar else true, false)
	late.free()
	await get_tree().process_frame
	_check("a unit gone: its bar goes", is_instance_valid(late_bar), false)

	# ARCHETYPES AR2: the perilous icon (the one icon over a head).
	Events.perilous_started.emit(slime, Ability.new())
	var icon := screen.get_perilous_icon(slime)
	_check("AR2: Events.perilous_started puts the perilous icon over its unit (the placeholder glyph, red)",
		icon != null and icon.text == screen.perilous_icon_text and icon.get_theme_color(&"font_color") == screen.perilous_icon_color, true)
	if icon != null:
		var extent := icon.get_combined_minimum_size()
		_check_near("...centered over the head, its bottom 12 px over the model's top (px off)",
			icon.position.distance_to(cam.unproject_position(head) - Vector2(extent.x * 0.5, 12.0 + extent.y)), 0.0, 0.001)
		_check("...above the health bar", icon.position.y + extent.y <= bar.position.y + 0.001, true)
	screen._process(0.3)
	_check("...still there at 0.3 s", screen.get_perilous_icon(slime) != null, true)
	screen._process(0.15)
	_check("...gone after its 0.4 s (the hit comes about 0.5 s later, on the beat)", screen.get_perilous_icon(slime), null)

	# A damage number.
	var entity_labels := entities.find_children("*", "Label", true, false).size()
	slime.show_heal_number(12.0)
	var holder := screen.get_node_or_null(^"Number") as Node2D
	var label: Label = holder.get_child(0) as Label if holder and holder.get_child_count() > 0 else null
	_check("under the view a number goes on the screen overlay", label != null and label.text == "+12", true)
	_check("not into the 2D world", entities.find_children("*", "Label", true, false).size(), entity_labels)
	if label == null:
		main.free()
		return
	var point := screen.point_over(slime, 0.8)
	_check_near("it appears over the unit, at 0.8 of its model's height (px off)", holder.position.distance_to(cam.unproject_position(point)), 0.0, 0.001)
	slime.show_heal_number(12.0)
	var stacked := screen.get_child(screen.get_child_count() - 1) as Node2D
	var stacked_label: Label = stacked.get_child(0) as Label if stacked != holder and stacked.get_child_count() > 0 else null
	_check("a second number while the first shows stacks one step above it (2D's rule, on the overlay)",
		stacked_label != null and is_equal_approx(label.position.y - stacked_label.position.y, NUMBER_STYLE.stack_step_px), true)
	stacked.free()
	var target := Node3D.new()
	target.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	view.add_child(target)
	target.global_position = cam.get_focus() + Vector3(2.0, 0.0, 1.0)
	cam.target = target
	cam.snap_to_target()
	var on_screen_before := holder.position
	screen._process(0.0)
	_check("the camera moved: the number stays at its spot in the world (it moved on screen, onto that spot)",
		holder.position.distance_to(on_screen_before) > 10.0 and holder.position.distance_to(cam.unproject_position(point)) < 0.001, true)
	label.free()
	screen._process(0.0)
	await get_tree().process_frame
	_check("the number gone: its holder goes", is_instance_valid(holder), false)

	main.free()
	_check_near("the view gone: the 2D squash is back", VFX.floor_squash, 0.55, 0.0)


func _test_spawn_scene_3d() -> void:
	_section("VFX.spawn_scene() with a Node3D root (P7)")
	var script := GDScript.new()
	script.source_code = "extends Node3D\nvar got: Array = []\nfunc setup(a, b) -> void:\n\tgot = [a, b]\n"
	script.reload()
	var root_3d := Node3D.new()
	root_3d.set_script(script)
	var scene_3d := PackedScene.new()
	scene_3d.pack(root_3d)
	root_3d.free()
	var root_2d := Node2D.new()
	var scene_2d := PackedScene.new()
	scene_2d.pack(root_2d)
	root_2d.free()

	var holder := Node2D.new()
	add_child(holder)
	var anchor := Node2D.new()
	holder.add_child(anchor)
	_check("without a WorldView: not spawned (null, nothing added)",
		VFX.spawn_scene(scene_3d, anchor, Vector2(64.0, 96.0), 0.0, [1, 2]) == null and holder.get_child_count() == 1, true)
	var view := WorldView.new()
	add_child(view)
	var node := VFX.spawn_scene(scene_3d, anchor, Vector2(64.0, 96.0), 0.0, [1, 2]) as Node3D
	_check("with one: under the WorldView", node != null and node.get_parent() == view, true)
	if node:
		_check_near_v3("on the floor at its sim point: (2, 0, 3) m", node.global_position, Vector3(2.0, 0.0, 3.0), 0.0001)
		_check_near_v3("its +Z along the 2D angle (0: east, +x)", node.global_basis.z, Vector3.RIGHT, 0.0001)
		_check("setup() got its arguments", node.get(&"got") == [1, 2], true)
	var south := VFX.spawn_scene(scene_3d, anchor, Vector2.ZERO, PI * 0.5, [3, 4]) as Node3D
	if south:
		_check_near_v3("at 90° (south in the sim): its +Z along +z", south.global_basis.z, Vector3.BACK, 0.0001)
	var flat := VFX.spawn_scene(scene_2d, anchor, Vector2(10.0, 20.0), 0.5) as Node2D
	_check("a Node2D root still goes next to its anchor, at its point, turned",
		flat != null and flat.get_parent() == holder and flat.global_position.is_equal_approx(Vector2(10.0, 20.0)) and is_equal_approx(flat.global_rotation, 0.5), true)
	view.free()
	holder.free()


# --- P8: rooms built in 3D -----------------------------------------------------------------

const FLOOR_STONE := "res://scenes/rooms/assets/materials/floor_stone.tres"
const WALL_STONE := "res://scenes/rooms/assets/materials/wall_stone.tres"


## A small layout built here: an 8 x 6 m floor (walkable, the kit's floor
## material), a 4 m wall at (1, 1) with a derived footprint (in `fades`), a
## 3 m fence at (1, 4) with a drawn low-obstacle footprint, a 1 x 1 m pit at
## (6, 1), pebbles (decoration), a dummy marker at (5.5, 4.5), the spawn at
## (2.5, 3) and a plain helper node.
func _fixture_layout() -> RoomLayout:
	var layout := RoomLayout.new()
	layout.name = "Fixture"
	var plane := PlaneMesh.new()
	plane.size = Vector2(8.0, 6.0)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	floor_mesh.mesh = plane
	floor_mesh.position = Vector3(4.0, 0.0, 3.0)
	floor_mesh.material_override = load(FLOOR_STONE)
	floor_mesh.add_to_group(&"walkable")
	layout.add_child(floor_mesh)
	var wall := _asset(layout, "Wall", Vector3(1.0, 0.0, 1.0))
	wall.add_to_group(&"fades")
	_asset_box(wall, Vector3(4.0, 2.2, 1.0), Vector3(2.0, 1.1, 0.5)).material_override = load(WALL_STONE)
	_asset_footprint(wall, Footprint.Kind.WALL)
	var fence := _asset(layout, "Fence", Vector3(1.0, 0.0, 4.0))
	_asset_box(fence, Vector3(3.0, 1.0, 0.2), Vector3(1.5, 0.5, 0.5))
	_asset_footprint(fence, Footprint.Kind.LOW_OBSTACLE, PackedVector2Array([Vector2(0, 0.4), Vector2(3, 0.4), Vector2(3, 0.6), Vector2(0, 0.6)]))
	var pit := _asset(layout, "Pit", Vector3(6.0, 0.0, 1.0))
	var bottom := PlaneMesh.new()
	bottom.size = Vector2(1.0, 1.0)
	var bottom_mesh := MeshInstance3D.new()
	bottom_mesh.mesh = bottom
	bottom_mesh.position = Vector3(0.5, -0.9, 0.5)
	pit.add_child(bottom_mesh)
	_asset_footprint(pit, Footprint.Kind.PIT, PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]))
	var pebbles := _asset(layout, "Pebbles", Vector3(7.0, 0.0, 5.0))
	pebbles.add_to_group(&"decoration")
	var pebble := MeshInstance3D.new()
	pebble.mesh = SphereMesh.new()
	pebbles.add_child(pebble)
	var marker := SimMarker.new()
	marker.name = "Dummy"
	marker.scene = load("res://scenes/enemies/slime.tscn")
	marker.properties = {"passive": true}
	marker.position = Vector3(5.5, 0.0, 4.5)
	layout.add_child(marker)
	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector3(2.5, 0.0, 3.0)
	layout.add_child(spawn)
	var helper := Node.new()
	helper.name = "Helper"
	layout.add_child(helper)
	return layout


func _asset(parent: Node, asset_name: String, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = asset_name
	root.position = at
	parent.add_child(root)
	return root


func _asset_box(asset: Node3D, size: Vector3, center: Vector3) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.position = center
	asset.add_child(mesh)
	return mesh


func _asset_footprint(asset: Node3D, kind: Footprint.Kind, polygon := PackedVector2Array()) -> Footprint:
	var fp := Footprint.new()
	fp.name = "Footprint%d" % asset.get_child_count()
	fp.kind = kind
	fp.polygon = polygon
	asset.add_child(fp)
	return fp


func _body_rect(room: Node, body_name: String) -> Rect2:
	var body := room.get_node_or_null("Footprints/" + body_name) as StaticBody2D
	if body == null:
		return Rect2()
	var poly := (body.get_child(0) as CollisionPolygon2D).polygon
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r


func _on_navmesh(nav: NavigationPolygon, p: Vector2) -> bool:
	var verts := nav.get_vertices()
	for i in nav.get_polygon_count():
		var poly := PackedVector2Array()
		for k in nav.get_polygon(i):
			poly.append(verts[k])
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


func _test_layout_sim() -> void:
	_section("RoomLayout.build_sim() (P8: footprints, markers, spawn, helpers, bounds, the bake)")
	var layout := _fixture_layout()
	_check("the fixture layout is silent in the validator", layout.validate(), [])
	var room := layout.build_sim()
	_check("it makes a Room named after the layout", room is Room and String(room.name) == "Fixture", true)
	_check_exact("the bounds: the walkable floor's extent, 8 x 6 m in px", room.bounds_px, Rect2(0.0, 0.0, 256.0, 192.0))
	var footprints := room.get_node_or_null("Footprints")
	_check("one collider per footprint, under Footprints (in navigation_source)",
		footprints != null and footprints.get_child_count() == 3 and footprints.is_in_group(&"navigation_source"), true)
	var layers := {}
	if footprints:
		for body in footprints.get_children():
			layers[String(body.name)] = [(body as StaticBody2D).collision_layer, (body as StaticBody2D).collision_mask]
	_check("on their kinds' layers, colliding with nothing: the wall 1, the fence 7 (bit 64), the pit 6 (bit 32)",
		layers, {"Wall_Footprint1": [1, 0], "Fence_Footprint1": [64, 0], "Pit_Footprint1": [32, 0]})
	_check("the wall's derived outline is its box's: 4 x 1 m at (1, 1) m, in px", _body_rect(room, "Wall_Footprint1").is_equal_approx(Rect2(32.0, 32.0, 128.0, 32.0)), true)
	var wall_body := footprints.get_node_or_null("Wall_Footprint1") if footprints else null
	_check_near("its area: 128 x 32 px (no slack from the hull)",
		absf(RoomLayout.polygon_area((wall_body.get_child(0) as CollisionPolygon2D).polygon)) if wall_body else 0.0, 4096.0, 0.5)
	_check("the fence's drawn outline, through its asset's place, in px", _body_rect(room, "Fence_Footprint1").is_equal_approx(Rect2(32.0, 140.8, 96.0, 6.4)), true)
	_check("the pit's", _body_rect(room, "Pit_Footprint1").is_equal_approx(Rect2(192.0, 32.0, 32.0, 32.0)), true)
	_check("each collider has a flat 2D look (the room plays without the view)", wall_body != null and wall_body.get_child(1) is Polygon2D, true)
	var dummy := room.get_node_or_null("Entities/Dummy")
	_check("the marker's scene is in Entities, named after the marker", dummy is Unit, true)
	if dummy:
		_check_exact("where the marker stands: (5.5, 4.5) m = (176, 144) px", (dummy as Node2D).position, Vector2(176.0, 144.0))
		_check("with its properties set (passive)", dummy.get(&"passive"), true)
	_check_exact("the spawn: (2.5, 3) m = (80, 96) px", (room.get_node("PlayerSpawn") as Node2D).position, Vector2(80.0, 96.0))
	_check("a plain helper node moves into the room", room.get_node_or_null("Helper") != null and layout.get_node_or_null("Helper") == null, true)

	var holder := Node2D.new()
	add_child(holder)
	holder.add_child(room)   # Room._ready() bakes the navigation
	await get_tree().physics_frame
	var nav := room.nav_region.navigation_polygon if room.nav_region else null
	_check("the navigation is baked", nav != null and nav.get_polygon_count() > 0, true)
	if nav:
		_check("open floor is on the navmesh", _on_navmesh(nav, Vector2(200.0, 150.0)), true)
		_check("the wall is carved out", _on_navmesh(nav, Vector2(96.0, 48.0)), false)
		_check("the fence too (low obstacles, layer 7)", _on_navmesh(nav, Vector2(80.0, 144.0)), false)
		_check("and the pit (layer 6): enemies path around it", _on_navmesh(nav, Vector2(208.0, 48.0)), false)
	_check("the bake carves walls, pits, low obstacles and ledges (layers 1, 6, 7, 11)", Room.NAV_BLOCKING_LAYERS, 1 | 32 | 64 | 1024)
	holder.free()
	layout.free()


func _test_layout_validator() -> void:
	_section("RoomLayout.validate() (P8: what looks wrong is flagged; a clean layout is silent)")
	var crate_layout := _fixture_layout()
	var crate := MeshInstance3D.new()
	crate.name = "Crate"
	crate.mesh = BoxMesh.new()
	crate_layout.add_child(crate)
	var found := crate_layout.validate()
	_check("an unmarked solid mesh is flagged (no footprint, not walkable, not decoration)",
		found.size() == 1 and found[0].contains("Crate") and found[0].contains("no footprint"), true)
	crate_layout.free()

	var empty_layout := _fixture_layout()
	var broken := _asset(empty_layout, "Broken", Vector3(5.0, 0.0, 3.0))
	_asset_box(broken, Vector3(1.0, 1.0, 1.0), Vector3(0.5, 0.5, 0.5))
	_asset_footprint(broken, Footprint.Kind.WALL, PackedVector2Array([Vector2(0, 0), Vector2(1, 0)]))
	var ghost := _asset(empty_layout, "Ghost", Vector3(3.0, 0.0, 5.0))
	_asset_footprint(ghost, Footprint.Kind.WALL)
	found = empty_layout.validate()
	_check("an empty footprint is flagged: 2 points", found.any(func(s: String) -> bool: return s.contains("Broken") and s.contains("empty footprint")), true)
	_check("and an empty polygon with no meshes to derive it from", found.any(func(s: String) -> bool: return s.contains("Ghost") and s.contains("nothing to derive")), true)
	empty_layout.free()

	var arch_layout := _fixture_layout()
	var arch := _asset(arch_layout, "Arch", Vector3(2.0, 0.0, 2.0))
	_asset_box(arch, Vector3(1.0, 2.2, 1.0), Vector3(0.5, 1.1, 0.5))
	_asset_box(arch, Vector3(1.0, 2.2, 1.0), Vector3(3.5, 1.1, 0.5))
	_asset_box(arch, Vector3(4.0, 0.6, 1.0), Vector3(2.0, 2.5, 0.5))
	_asset_footprint(arch, Footprint.Kind.WALL)   # derived: the hull closes the opening
	found = arch_layout.validate()
	_check("a hull over an archway is flagged (an invisible wall in the opening)",
		found.size() == 1 and found[0].contains("Arch") and found[0].contains("invisible wall"), true)
	var drawn_arch := _asset(arch_layout, "DrawnArch", Vector3(2.0, 0.0, 2.0))
	arch.free()
	_asset_box(drawn_arch, Vector3(1.0, 2.2, 1.0), Vector3(0.5, 1.1, 0.5))
	_asset_box(drawn_arch, Vector3(1.0, 2.2, 1.0), Vector3(3.5, 1.1, 0.5))
	_asset_box(drawn_arch, Vector3(4.0, 0.6, 1.0), Vector3(2.0, 2.5, 0.5))
	_asset_footprint(drawn_arch, Footprint.Kind.WALL, PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]))
	_asset_footprint(drawn_arch, Footprint.Kind.WALL, PackedVector2Array([Vector2(3, 0), Vector2(4, 0), Vector2(4, 1), Vector2(3, 1)]))
	_check("drawn as two footprints, one per pillar, it passes", arch_layout.validate(), [])
	arch_layout.free()

	var long_layout := _fixture_layout()
	var long_wall := _asset(long_layout, "Long", Vector3(2.0, 0.0, 2.0))
	_asset_box(long_wall, Vector3(4.0, 2.2, 1.0), Vector3(2.0, 1.1, 0.5))
	_asset_footprint(long_wall, Footprint.Kind.WALL, PackedVector2Array([Vector2(0, 0), Vector2(2, 0), Vector2(2, 1), Vector2(0, 1)]))
	found = long_layout.validate()
	_check("a mesh sticking out of its footprint is flagged (2 m past it)",
		found.size() == 1 and found[0].contains("Long") and found[0].contains("stick out") and found[0].contains("2.00 m"), true)
	long_layout.free()

	var rock_layout := _fixture_layout()
	var rock := _asset(rock_layout, "Rock", Vector3(5.0, 0.0, 3.0))
	var sphere := SphereMesh.new()
	sphere.radius = 0.8
	sphere.height = 1.5
	sphere.radial_segments = 7
	sphere.rings = 3
	var rock_mesh := MeshInstance3D.new()
	rock_mesh.mesh = sphere
	rock_mesh.position = Vector3(0.0, 0.55, 0.0)
	rock.add_child(rock_mesh)
	var rock_fp := _asset_footprint(rock, Footprint.Kind.WALL)
	_check("a boulder's derived outline passes (its middle is inside its cross-section)", rock_layout.validate(), [])
	_check("the derived outline is the boulder's widest ring: 7 sides, 0.8 m out",
		rock_fp.get_outline_local().size() in [7, 8] and absf(rock_fp.get_outline_local()[0].length() - 0.8) < 0.1, true)
	rock_layout.free()


func _test_layout_in_view() -> void:
	_section("A layout under the 3D view (P8: the room's look, its floor pick, floor drawings, fading)")
	var layout := _fixture_layout()
	var room := layout.build_sim()
	var main := Node2D.new()
	main.name = "FixtureMain"
	main.add_child(room)
	add_child(main)
	var view := WorldView.new()
	main.add_child(view)
	view.setup(main, room, null, layout)
	_check("the layout moves under the WorldView as the room's look (no RoomView)",
		layout.get_parent() == view and view.layout == layout and view.room_view == null, true)
	var pick := layout.get_node_or_null("FloorPick") as StaticBody3D
	_check("its walkable floor's pick body: 3D layer 1, colliding with nothing",
		pick != null and pick.collision_layer == WorldView.FLOOR_LAYER and pick.collision_mask == 0, true)
	_check("its floor's material shows the floor drawings",
		(load(FLOOR_STONE) as ShaderMaterial).get_shader_parameter(&"drawings") == view.floor_overlay.get_texture(), true)
	_check("its fades asset (the wall) fades", (view.get("_fading") as Array).size(), 1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var on_floor := Vector3(6.3, 0.0, 4.2)
	_check_near("the floor pick lands on its floor (px off)", view.floor_at_screen_px(view.camera.unproject_position(on_floor)).distance_to(Units.to_sim(on_floor)), 0.0, 0.5)
	await get_tree().process_frame
	await get_tree().process_frame
	var fp := layout.get_node("Wall").get_child(1) as Footprint
	_check("in play its footprints aren't drawn (debug_draw off)", fp.get_child_count(true), 0)
	main.free()

	var drawn := _fixture_layout()
	drawn.debug_draw = true
	add_child(drawn)
	await get_tree().process_frame
	await get_tree().process_frame
	var drawn_fp := drawn.get_node("Wall").get_child(1) as Footprint
	_check("with debug_draw they are: a preview mesh (a tool's, never part of the room)",
		drawn_fp.get_child_count(true) == 1 and drawn_fp.get_child(0, true).has_meta(RoomLayout.TOOL_META), true)
	_check("the layout's own lists leave the preview out (its 5 meshes)", drawn.get_meshes().size(), 5)
	drawn.free()

	var marker := SimMarker.new()
	marker.name = "Slime9"
	marker.scene = load("res://scenes/enemies/slime.tscn")
	add_child(marker)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("in play a SimMarker shows nothing (its look is the editor's)", marker.get_child_count(true), 0)
	marker._rebuild_preview()   # what the editor runs
	var preview := marker.get_child(0, true) if marker.get_child_count(true) == 1 else null
	var capsule := preview.find_children("*", "MeshInstance3D", true, false) if preview else []
	var label := preview.find_children("*", "Label3D", true, false) if preview else []
	_check("its editor look: a capsule as wide as the slime's gameplay radius (0.55 m), its name over it, marked a tool's",
		preview != null and preview.has_meta(RoomLayout.TOOL_META) and capsule.size() == 1
		and is_equal_approx(((capsule[0] as MeshInstance3D).mesh as CapsuleMesh).radius, 0.55)
		and label.size() == 1 and (label[0] as Label3D).text == "Slime9", true)
	marker.free()


func _test_real_layouts() -> void:
	_section("The real layouts (P8: the 3D sandbox, room_01's layout, their play scenes, walking masks)")
	var sandbox := (load("res://scenes/rooms/sandbox_3d.tscn") as PackedScene).instantiate() as RoomLayout
	_check("the 3D sandbox is a RoomLayout, silent in the validator", sandbox != null and sandbox.validate().is_empty(), true)
	var tile_sandbox := (load("res://scenes/rooms/sandbox.tscn") as PackedScene).instantiate()
	var same_markers := true
	var twins := 0
	for marker in sandbox.get_sim_markers():
		if String(marker.name) in ["Perch", "PerchDummy"]:
			continue   # P9's terrain corner (checked there)
		var twin := tile_sandbox.get_node_or_null("Entities/" + String(marker.name)) as Node2D
		twins += 1
		same_markers = same_markers and twin != null and Units.to_sim(RoomLayout.transform_in(marker, sandbox).origin).is_equal_approx(twin.position) \
			and marker.scene.resource_path == twin.scene_file_path and marker.properties.get("passive", false) == twin.get(&"passive")
	_check("its 6 markers (P9's perch aside) are the tile sandbox's dummies and enemies, at the same points (dummies passive)",
		same_markers and twins == 6, true)
	_check_exact("its spawn is the tile sandbox's", Units.to_sim((sandbox.get_node("PlayerSpawn") as Node3D).position), (tile_sandbox.get_node("PlayerSpawn") as Node2D).position)
	var helpers_ok := true
	for helper in ["SandboxReactions", "SandboxAbilities", "SandboxAugments", "SandboxTalents"]:
		var copy := sandbox.get_node_or_null(helper)
		helpers_ok = helpers_ok and copy != null and copy.get_script() == tile_sandbox.get_node(helper).get_script()
	_check("it carries the tile sandbox's four helper nodes", helpers_ok, true)
	var kinds := {}
	for fp in sandbox.get_footprints():
		kinds[fp.kind] = int(kinds.get(fp.kind, 0)) + 1
	_check("it has walls, a fence (low obstacle) and a pit", kinds.has(Footprint.Kind.WALL) and kinds.get(Footprint.Kind.LOW_OBSTACLE, 0) == 1 and kinds.get(Footprint.Kind.PIT, 0) == 1, true)
	tile_sandbox.free()
	sandbox.free()

	var layout := (load("res://scenes/rooms/room_01_layout.tscn") as PackedScene).instantiate() as RoomLayout
	_check("room_01's layout is silent in the validator", layout != null and layout.validate().is_empty(), true)
	var tile_room := (load("res://scenes/rooms/room_01.tscn") as PackedScene).instantiate()
	var tiles := tile_room.get_node("Tiles") as TileMapLayer
	var outlines: Array[PackedVector2Array] = []
	var only_walls := true
	for fp in layout.get_footprints():
		outlines.append(layout.footprint_outline_m(fp))
		only_walls = only_walls and fp.kind == Footprint.Kind.WALL
	var mismatches := 0
	var cells := 0
	for c in tiles.get_used_cells():
		var data := tiles.get_cell_tile_data(c)
		var is_wall := data != null and data.get_collision_polygons_count(0) > 0
		var center_m := Vector2(Units.px_to_m(tiles.map_to_local(c).x), Units.px_to_m(tiles.map_to_local(c).y))
		var covered := RoomLayout.distance_outside(center_m, outlines) == 0.0
		if covered != is_wall:
			mismatches += 1
		cells += 1
	_check("every one of the tile room's %d cells: a wall cell is under a wall footprint, a floor cell isn't (mismatches)" % cells, mismatches, 0)
	_check("its footprints are all walls", only_walls, true)
	var same := true
	for e in tile_room.get_node("Entities").get_children():
		var marker := layout.get_node_or_null("Markers/" + String(e.name)) as SimMarker
		same = same and marker != null and Units.to_sim(marker.position).is_equal_approx((e as Node2D).position) and marker.scene.resource_path == e.scene_file_path
	_check("its markers are the tile room's six slimes, at the same points", same and layout.get_sim_markers().size() == 6, true)
	_check_exact("its spawn is the tile room's", Units.to_sim((layout.get_node("PlayerSpawn") as Node3D).position), (tile_room.get_node("PlayerSpawn") as Node2D).position)
	tile_room.free()
	layout.free()

	for pair: Array in [["res://scenes/sandbox_main_layout.tscn", "res://scenes/rooms/sandbox_3d.tscn"], ["res://scenes/main_layout.tscn", "res://scenes/rooms/room_01_layout.tscn"]]:
		var state := (load(pair[0]) as PackedScene).get_state()
		var props := {}
		for i in state.get_node_property_count(0):
			props[state.get_node_property_name(0, i)] = state.get_node_property_value(0, i)
		var room_scene: PackedScene = props.get(&"room_scene")
		_check("%s plays %s (in 3D, as every Main does since the cleanup's C3)" % [String(pair[0]).get_file(), String(pair[1]).get_file()],
			not props.has(&"use_3d_view") and room_scene != null and room_scene.resource_path == pair[1], true)

	for path in ["res://scenes/player/player.tscn", "res://scenes/enemies/slime.tscn", "res://scenes/enemies/slime_elite.tscn"]:
		var unit := (load(path) as PackedScene).instantiate() as CollisionObject2D
		_check("%s walks into walls, units, fences and ledges (layers 1, 2, 3, 7; 11 since P9), not pits yet (6)" % path.get_file(),
			unit.collision_mask, 1 | 2 | 4 | 64 | 1024)
		unit.free()


# --- P9: terrain and airborne -----------------------------------------------------------------

const AIRBORNE_STATUS: StatusEffect = preload("res://data/statuses/status_airborne.tres")
const ELEVATED_STATUS: StatusEffect = preload("res://data/statuses/status_elevated.tres")


func _px(x_m: float, z_m: float) -> Vector2:
	return Vector2(Units.m_to_px(x_m), Units.m_to_px(z_m))


func _place(node: Node2D, pos: Vector2) -> void:
	node.global_position = pos
	node.reset_physics_interpolation()


## A layout with terrain: a 10 x 8 m floor; a 3 x 3 m plateau 1.5 m high at
## (2, 2) (its top walkable, its cliff decoration); a ramp from the plateau's
## east edge (x 5, 1.5 m) down to x 8, z 3..4 (unless no_ramp); a fence along
## z 6.4..6.6, x 1..4; a wall block x 9..10, z 5..7; the spawn.
func _terrain_layout(with_ramp: bool = true) -> RoomLayout:
	var layout := RoomLayout.new()
	layout.name = "Terrain"
	var plane := PlaneMesh.new()
	plane.size = Vector2(10.0, 8.0)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	floor_mesh.mesh = plane
	floor_mesh.position = Vector3(5.0, 0.0, 4.0)
	floor_mesh.material_override = load(FLOOR_STONE)
	floor_mesh.add_to_group(&"walkable")
	layout.add_child(floor_mesh)
	var plateau := _asset(layout, "Plateau", Vector3(2.0, 0.0, 2.0))
	var top := PlaneMesh.new()
	top.size = Vector2(3.0, 3.0)
	var top_mesh := MeshInstance3D.new()
	top_mesh.name = "Top"
	top_mesh.mesh = top
	top_mesh.position = Vector3(1.5, 1.5, 1.5)
	top_mesh.add_to_group(&"walkable")
	plateau.add_child(top_mesh)
	_asset_box(plateau, Vector3(3.0, 1.49, 3.0), Vector3(1.5, 0.745, 1.5)).add_to_group(&"decoration")
	if with_ramp:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for p: Vector3 in [Vector3(5, 1.5, 3), Vector3(8, 0, 3), Vector3(8, 0, 4), Vector3(5, 1.5, 3), Vector3(8, 0, 4), Vector3(5, 1.5, 4)]:
			st.add_vertex(p)
		st.generate_normals()
		var ramp := MeshInstance3D.new()
		ramp.name = "Ramp"
		ramp.mesh = st.commit()
		ramp.add_to_group(&"walkable")
		layout.add_child(ramp)
	var fence := _asset(layout, "Fence", Vector3(1.0, 0.0, 6.0))
	_asset_box(fence, Vector3(3.0, 1.0, 0.2), Vector3(1.5, 0.5, 0.5))
	_asset_footprint(fence, Footprint.Kind.LOW_OBSTACLE, PackedVector2Array([Vector2(0, 0.4), Vector2(3, 0.4), Vector2(3, 0.6), Vector2(0, 0.6)]))
	var wall := _asset(layout, "Wall", Vector3(9.0, 0.0, 5.0))
	_asset_box(wall, Vector3(1.0, 2.2, 2.0), Vector3(0.5, 1.1, 1.0))
	_asset_footprint(wall, Footprint.Kind.WALL)
	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector3(8.5, 0.0, 7.0)
	layout.add_child(spawn)
	return layout


func _grid_at(grid: Dictionary, p_m: Vector2) -> float:
	var cell := Vector2i(((p_m - (grid["origin"] as Vector2)) / float(grid["step"])).floor())
	var size: Vector2i = grid["size"]
	return (grid["heights"] as PackedFloat32Array)[cell.y * size.x + cell.x]


func _ledge_at(ledges: Array[Dictionary], p_m: Vector2) -> bool:
	for ledge in ledges:
		if (ledge["rect"] as Rect2).has_point(p_m):
			return true
	return false


## A room's sim in the tree (Room._ready() bakes), two physics frames later.
## The layout itself is freed: only its sim is used.
func _terrain_room(layout: RoomLayout) -> Node2D:
	var holder := Node2D.new()
	add_child(holder)
	holder.add_child(layout.build_sim())
	layout.free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	return holder


func _test_airborne_status() -> void:
	_section("status_airborne and status_elevated (P9; 3D.md, Airborne; Terrain and height 2)")
	_check("airborne: tags cc, airborne, debuff; blocks moving, attacking, casting and dashing",
		[AIRBORNE_STATUS.tags, AIRBORNE_STATUS.blocks_move, AIRBORNE_STATUS.blocks_attack, AIRBORNE_STATUS.blocks_cast, AIRBORNE_STATUS.blocks_dash],
		[[&"cc", &"airborne", &"debuff"] as Array[StringName], true, true, true, true])
	_check("REFRESH_LONGER (a juggle keeps the longer); tenacity doesn't shorten it; a cleanse doesn't end it",
		[AIRBORNE_STATUS.stack_rule == StatusEffect.StackRule.REFRESH_LONGER, AIRBORNE_STATUS.ignores_tenacity, AIRBORNE_STATUS.cleansable], [true, true, false])
	_check("elevated: the tag elevated, until removed, not cc",
		[ELEVATED_STATUS.tags, ELEVATED_STATUS.duration, ELEVATED_STATUS.is_cc()], [[&"elevated"] as Array[StringName], -1.0, false])
	var holder := Node2D.new()
	add_child(holder)
	var slime := (load("res://scenes/enemies/slime.tscn") as PackedScene).instantiate() as Unit
	holder.add_child(slime)
	var status := slime.status_component
	slime.stats_component.add_modifier(StatModifier.create(&"tenacity", StatModifier.Type.FLAT, 0.5, &"p9_test"))
	status.apply_status(load("res://data/statuses/status_stun.tres"), null, 1.0)
	status.apply_status(AIRBORNE_STATUS, null, 0.75)
	_check_near("50% tenacity halves a 1 s stun", status.get_time_left(&"stun"), 0.5, 0.001)
	_check_near("and leaves a 0.75 s knock-up whole", status.get_time_left(&"airborne"), 0.75, 0.001)
	status.remove_statuses_with_tags([&"cc"] as Array[StringName])
	_check("a cleanse ends the stun, not the knock-up", [status.has_status(&"stun"), status.has_status(&"airborne")], [false, true])
	var unstoppable := StatusEffect.new()
	unstoppable.id = &"p9_unstoppable"
	unstoppable.tags = [&"unstoppable"] as Array[StringName]
	unstoppable.duration = 1.0
	status.apply_status(unstoppable)
	_check("gaining unstoppable doesn't end it either", status.has_status(&"airborne"), true)
	status.remove_status(&"airborne")
	_check("but while unstoppable a new knock-up is refused (it's cc)", status.apply_status(AIRBORNE_STATUS, null, 0.75), false)
	status.remove_status(&"p9_unstoppable")
	slime.add_invulnerability(&"p9_test")
	var blocked := slime.make_hit_context(10.0, null)
	blocked.statuses.append(AIRBORNE_STATUS)
	slime.on_hit(blocked)
	_check("i-frames block the whole hit: no knock-up", status.has_status(&"airborne"), false)
	slime.remove_invulnerability(&"p9_test")
	var up := slime.make_hit_context(10.0, null)
	up.statuses.append(AIRBORNE_STATUS)
	slime.on_hit(up)
	var hp := slime.health.current
	slime.on_hit(slime.make_hit_context(10.0, null))
	_check("without them it's knocked up, and being airborne gives no i-frames (a juggle lands)",
		[status.has_status(&"airborne"), slime.health.current < hp], [true, true])
	holder.free()

	# LOOT L5: the toolkit's pull_airborne() (Ability) loads it too, and only
	# the Knight's Judgement calls that (Chains of Judgement's drag).
	var users := _files_mentioning("res://", "status_airborne.tres")
	users.sort()
	_check("only the test Uppercut and the toolkit's airborne pull use the knock-up (files: %s)" % [users],
		users, ["res://scripts/abilities/ability.gd", "res://scripts/abilities/test/uppercut.gd"])
	var pullers := _files_mentioning("res://", "pull_airborne(")
	pullers.sort()
	_check("and only the Knight's Judgement pulls: no enemy knocks up the player in v1 (files: %s)" % [pullers],
		pullers, ["res://scripts/abilities/ability.gd", "res://scripts/abilities/knight/judgement.gd"])
	# LOOT L6: a leap is the player's own (3D.md, Leaps): only The Last Verdict's
	# Judgement Leap calls MovementComponent.leap(). ENEMIES_AI AI3 (Ryan,
	# 2026-10-04): the test skirmisher's gap-closer is a real leap too.
	var leapers := _files_mentioning("res://scripts/", "movement.leap(")
	leapers.sort()
	_check("only the Knight's Judgement Leap and the test skirmisher's Leap leap (files: %s)" % [leapers], leapers,
		["res://scripts/abilities/knight/judgement_leap.gd", "res://scripts/abilities/test_skirmisher/leap.gd"])


## Every .gd, .tres and .tscn under `dir` (tests and the status itself left
## out) whose text contains `needle`.
func _files_mentioning(dir: String, needle: String) -> Array[String]:
	var out: Array[String] = []
	for sub in DirAccess.get_directories_at(dir):
		if sub.begins_with(".") or (dir == "res://scripts/" and sub == "tests"):
			continue
		out.append_array(_files_mentioning(dir.path_join(sub) + "/", needle))
	for file in DirAccess.get_files_at(dir):
		if not (file.ends_with(".gd") or file.ends_with(".tres") or file.ends_with(".tscn")):
			continue
		var path := dir.path_join(file)
		if path == "res://data/statuses/status_airborne.tres":
			continue
		if FileAccess.get_file_as_string(path).contains(needle):
			out.append(path)
	return out


func _test_ledges() -> void:
	_section("Derived ledges (P9; 3D.md, Terrain and height 1b)")
	var layout := _terrain_layout()
	_check("the terrain fixture is silent in the validator", layout.validate(), [])
	var grid := layout.ground_grid()
	_check_near("the ground grid: the floor at 0 m", _grid_at(grid, Vector2(1.1, 1.1)), 0.0, 0.001)
	_check_near("the plateau's top at 1.5 m", _grid_at(grid, Vector2(3.5, 3.5)), 1.5, 0.001)
	_check_near("half way down the ramp, about 0.75 m (the cell's center: 0.69)", _grid_at(grid, Vector2(6.5, 3.5)), 0.6875, 0.001)
	var ledges := layout.derive_ledges()
	_check("a ledge runs along the plateau's west edge, on its top side",
		_ledge_at(ledges, Vector2(2.1, 3.5)) and not _ledge_at(ledges, Vector2(1.9, 3.5)), true)
	_check("none where the ramp joins it (its east edge, z 3..4)", _ledge_at(ledges, Vector2(4.9, 3.5)), false)
	_check("north of the ramp the east edge is a cliff again", _ledge_at(ledges, Vector2(4.9, 2.3)), true)
	_check("the ramp's sides are cliffs where it's high (0.75 m)", _ledge_at(ledges, Vector2(6.5, 3.1)), true)
	_check("but not at its foot (under 0.3 m)", _ledge_at(ledges, Vector2(7.9, 3.1)), false)
	_check("nor in the plateau's middle or on the floor", [_ledge_at(ledges, Vector2(3.5, 3.5)), _ledge_at(ledges, Vector2(1.0, 1.0))], [false, false])
	var west_heights_ok := true
	for ledge in ledges:
		var r: Rect2 = ledge["rect"]
		if r.position.x < 2.3:
			west_heights_ok = west_heights_ok and is_equal_approx(float(ledge["height"]), 1.5)
	_check("the plateau's ledges stand at its top (1.5 m)", west_heights_ok, true)

	var holder := await _terrain_room(layout)
	var room := holder.get_child(0) as Room
	var ledge_body := room.get_node_or_null("Footprints/Ledges") as StaticBody2D
	_check("build_sim() adds them as one body on layer 11 (bit 1024), colliding with nothing, a box per run",
		ledge_body != null and ledge_body.collision_layer == 1024 and ledge_body.collision_mask == 0
		and ledge_body.find_children("*", "CollisionShape2D", false, false).size() == ledges.size(), true)
	var nav := room.nav_region.navigation_polygon
	_check("the bake carves them (the top's edge is off the navmesh, its middle on it)",
		[_on_navmesh(nav, _px(2.1, 3.5)), _on_navmesh(nav, _px(3.5, 3.5))], [false, true])

	var probe := CharacterBody2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 11.0
	var col := CollisionShape2D.new()
	col.shape = circle
	probe.add_child(col)
	holder.add_child(probe)
	await get_tree().physics_frame
	var walking := 1 | 2 | 4 | 64 | 1024
	var from_west := Transform2D(0.0, _px(1.4, 3.5))
	probe.collision_mask = walking
	var walk_blocked := probe.test_move(from_west, Vector2(40.0, 0.0))
	probe.collision_mask = walking & MovementComponent.GHOST_KEEP_MASK
	var dash_blocked := probe.test_move(from_west, Vector2(40.0, 0.0))
	probe.collision_mask = walking & 1
	var old_dash_blocked := probe.test_move(from_west, Vector2(40.0, 0.0))
	_check("walking into a cliff from below stops at its ledge", walk_blocked, true)
	_check("so does the dash (it keeps walls and ledges: GHOST_KEEP_MASK = 1 | 1024)", [dash_blocked, MovementComponent.GHOST_KEEP_MASK], [true, 1 | 1024])
	_check("(with walls only, as before P9, it would have climbed it)", old_dash_blocked, false)
	var from_south := Transform2D(0.0, _px(2.5, 7.4))
	probe.collision_mask = walking
	var fence_walk := probe.test_move(from_south, Vector2(0.0, -40.0))
	probe.collision_mask = walking & MovementComponent.GHOST_KEEP_MASK
	var fence_dash := probe.test_move(from_south, Vector2(0.0, -40.0))
	_check("a fence stops walking; the dash crosses it", [fence_walk, fence_dash], [true, false])
	_check("projectiles fly over a ledge (WorldQuery.shape_sweep, walls only)", WorldQuery.shape_sweep(_px(1.4, 3.5), _px(3.5, 3.5), 4.0).is_empty(), true)
	_check("and sight crosses it", WorldQuery.has_line_of_sight(_px(1.4, 3.5), _px(3.5, 3.5)), true)
	holder.free()

	# Judgement's walk into range (ABILITIES, UNIT targeting): it follows a path,
	# and a plateau with no way up is an island of the navmesh. On a map of its
	# own: maps sync asynchronously, so under load the shared map can still hold
	# the last fixture's region (its ramp leads up) for a few frames.
	var island := await _terrain_room(_terrain_layout(false))
	var island_room := island.get_child(0) as Room
	var map := NavigationServer2D.map_create()
	NavigationServer2D.map_set_cell_size(map, island_room.nav_region.navigation_polygon.cell_size)
	NavigationServer2D.map_set_active(map, true)
	island_room.nav_region.set_navigation_map(map)
	for i in 120:
		await get_tree().physics_frame
		if NavigationServer2D.map_get_iteration_id(map) > 0:
			break
	var path := NavigationServer2D.map_get_path(map, _px(1.0, 3.5), _px(3.5, 3.5), true)
	var path_end := Vector2(Units.px_to_m(path[path.size() - 1].x), Units.px_to_m(path[path.size() - 1].y)) if path.size() > 0 else Vector2.INF
	_check("a path to the top of a plateau with no way up ends at its foot, within 2 m, not on the island (what Judgement's walk into range follows), at %s" % path_end,
		path.size() > 0 and not Rect2(2.0, 2.0, 3.0, 3.0).has_point(path_end) and path_end.distance_to(Vector2(3.5, 3.5)) < 2.0, true)
	island.free()
	NavigationServer2D.free_rid(map)


func _test_airborne_moves() -> void:
	_section("A knock-up's movement (P9; 3D.md, Airborne)")
	var holder := await _terrain_room(_terrain_layout())
	var room := holder.get_child(0) as Room
	var slime := (load("res://scenes/enemies/slime.tscn") as PackedScene).instantiate() as Unit
	slime.set(&"passive", true)
	room.get_node("Entities").add_child(slime)
	var push := func(at: Vector2, by_px: Vector2, airborne: bool) -> Vector2:
		slime.status_component.remove_status(&"airborne")
		_place(slime, at)
		await get_tree().physics_frame
		if airborne:
			slime.status_component.apply_status(AIRBORNE_STATUS, null, 1.0)
		slime.movement.displace(by_px / 0.25, 0.25)
		for i in 25:
			await get_tree().physics_frame
		return slime.global_position
	var stopped: Vector2 = await push.call(_px(2.5, 7.4), Vector2(0.0, -64.0), false)
	_check("pushed north into the fence, not knocked up: it stops at the fence", Units.px_to_m(stopped.y) > 6.6, true)
	var over: Vector2 = await push.call(_px(2.5, 7.4), Vector2(0.0, -64.0), true)
	_check("knocked up, the push carries it over the fence", Units.px_to_m(over.y) < 6.0, true)
	var below: Vector2 = await push.call(_px(1.0, 3.5), Vector2(64.0, 0.0), false)
	_check("pushed east into the plateau's cliff: it stops at the ledge", Units.px_to_m(below.x) < 2.0, true)
	var onto: Vector2 = await push.call(_px(1.0, 3.5), Vector2(64.0, 0.0), true)
	_check("knocked up, over the ledge and onto the top", Units.px_to_m(onto.x) > 2.3, true)
	var wall: Vector2 = await push.call(_px(7.6, 6.0), Vector2(64.0, 0.0), true)
	_check("walls still stop a knock-up", Units.px_to_m(wall.x) < 9.0, true)
	var landed: Vector2 = await push.call(_px(2.5, 7.3), Vector2(0.0, -28.0), true)
	_check("a knock-up that would land inside the fence lands back out of it, on the side it came from",
		WorldQuery.is_point_free(landed, 11.0, 64) and Units.px_to_m(landed.y) > 6.6, true)
	holder.free()


## Ryan's P9 check (2026-10-03): a unit knocked onto the stairs or the ramp
## was sent back to where its push started. Their side ledges leave a 14 px
## slime's center a band 0.6 m wide; a landing outside it went back along the
## whole push line. Now the shortest move out (WorldQuery.push_out()).
func _test_landing_off_center() -> void:
	_section("A knock-up landing on stairs and a ramp (P9 fix; 3D.md, Airborne)")
	var sandbox := (load("res://scenes/rooms/sandbox_3d.tscn") as PackedScene).instantiate() as RoomLayout
	sandbox.get_node("Markers").free()   # the terrain alone: no units, no perch
	for helper in ["SandboxReactions", "SandboxAbilities", "SandboxAugments", "SandboxTalents"]:
		sandbox.get_node(helper).free()
	var holder := await _terrain_room(sandbox)
	var room := holder.get_child(0) as Room
	var slime := (load("res://scenes/enemies/slime.tscn") as PackedScene).instantiate() as Unit
	slime.set(&"passive", true)
	room.get_node("Entities").add_child(slime)
	var knock := func(at_m: Vector2, by_m: Vector2) -> Vector2:
		slime.status_component.remove_status(&"airborne")
		_place(slime, _px(at_m.x, at_m.y))
		await get_tree().physics_frame
		slime.status_component.apply_status(AIRBORNE_STATUS, null, 1.0)
		slime.movement.displace(_px(by_m.x, by_m.y) / 0.25, 0.25)
		for i in 25:
			await get_tree().physics_frame
		return Vector2(Units.px_to_m(slime.global_position.x), Units.px_to_m(slime.global_position.y))
	var free_there := func(at_m: Vector2) -> bool:
		return WorldQuery.is_point_free(_px(at_m.x, at_m.y), 14.0, MovementComponent.LANDING_BLOCKING_MASK)
	var stairs: Vector2 = await knock.call(Vector2(12.75, 4.5), Vector2(-0.33, 1.97))
	_check("knocked off the plateau onto the stairs a little west of their middle: it stays on the stairs, nudged sideways off their side's ledge (was: back up near its start), at %s" % stairs,
		stairs.y > 6.4 and stairs.x > 12.6 and stairs.x < 12.8 and free_there.call(stairs), true)
	var ramp: Vector2 = await knock.call(Vector2(15.8, 2.65), Vector2(2.0, 0.0))
	_check("onto the ramp a little north of its middle: on the ramp, moved a few px (was: back to its start), at %s" % ramp,
		ramp.x > 17.6 and ramp.y > 2.65 and ramp.y < 2.8 and free_there.call(ramp), true)
	var strip: Vector2 = await knock.call(Vector2(12.75, 4.5), Vector2(-0.6, 1.91))
	_check("its center inside the stairs' side ledge: it comes out onto the stairs, the side it came from, at %s" % strip,
		strip.y > 6.3 and strip.x > 12.65 and strip.x < 12.8 and free_there.call(strip), true)
	var rim_top: Vector2 = await knock.call(Vector2(15.0, 2.9), Vector2(0.0, 2.0))
	_check("pushed from the plateau's middle to its rim (center in the ledge): back on top, just inside it, at %s" % rim_top,
		rim_top.y > 4.0 and rim_top.y < 4.75 and free_there.call(rim_top), true)
	var rim_below: Vector2 = await knock.call(Vector2(15.0, 6.9), Vector2(0.0, -2.0))
	_check("pushed from below to the same rim: back below, at %s" % rim_below,
		rim_below.y > 5.0 and rim_below.y < 6.0 and free_there.call(rim_below), true)
	var off: Vector2 = await knock.call(Vector2(15.0, 4.3), Vector2(0.0, 2.0))
	_check_near("from the plateau's edge it still goes off the cliff, the full 2 m", off.y, 6.3, 0.02)
	holder.free()


func _test_perch() -> void:
	_section("The perch (P9; 3D.md, Terrain and height 2)")
	var holder := await _terrain_room(_terrain_layout())
	var room := holder.get_child(0) as Room
	var perch := (load("res://scenes/world/perch.tscn") as PackedScene).instantiate() as Perch
	perch.size_m = Vector2(3.0, 3.0)
	perch.position = _px(3.5, 3.5)
	room.get_node("Entities").add_child(perch)
	var slime := (load("res://scenes/enemies/slime.tscn") as PackedScene).instantiate() as Unit
	slime.set(&"passive", true)
	room.get_node("Entities").add_child(slime)
	var settle := func() -> void:
		for i in 3:
			await get_tree().physics_frame
	_place(slime, _px(3.5, 3.0))
	await settle.call()
	_check("a unit standing on the perch is elevated", slime.status_component.has_tag(&"elevated"), true)
	_place(slime, _px(1.0, 3.5))
	await settle.call()
	_check("off it, it isn't", slime.status_component.has_tag(&"elevated"), false)
	_place(slime, _px(1.75, 3.5))
	await settle.call()
	_check("pressed against the cliff below (its body reaching over the top's edge, its feet not): not elevated",
		slime.status_component.has_tag(&"elevated"), false)
	holder.free()


func _test_terrain_in_view() -> void:
	_section("Terrain under the 3D view (P9: the ground's height, a unit on a plateau, the arc, the window)")
	var layout := _terrain_layout()
	var room := layout.build_sim()
	var main := Node2D.new()
	main.add_child(room)
	add_child(main)
	var view := WorldView.new()
	main.add_child(view)
	view.setup(main, room, null, layout)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check_near("the ground under the floor: 0 m (a downward ray on the floor layer)", view.ground_height_m(_px(1.0, 1.0)), 0.0, 0.01)
	_check_near("on the plateau: 1.5 m", view.ground_height_m(_px(3.5, 3.5)), 1.5, 0.01)
	_check_near("half way down the ramp: 0.75 m", view.ground_height_m(_px(6.5, 3.5)), 0.75, 0.01)
	var slime := (load("res://scenes/enemies/slime.tscn") as PackedScene).instantiate() as Unit
	slime.set(&"passive", true)
	slime.position = _px(3.5, 3.5)
	room.get_node("Entities").add_child(slime)
	for i in 3:
		await get_tree().physics_frame
	var sv := view.view_of(slime) as UnitView
	_check_near("a unit's view stands on the plateau's top", sv.position.y if sv else -1.0, 1.5, 0.01)
	_check_near("what sits over its head starts at its model's top there", view.unit_top_m(slime), 1.5 + 1.32, 0.01)
	slime.status_component.apply_status(AIRBORNE_STATUS, null, 0.6)
	for i in 18:
		await get_tree().physics_frame
	await get_tree().process_frame
	var mid := sv.air_height_m if sv else 0.0
	_check("knocked up for 0.6 s, half way its model is near the apex (1.2 m over the ground): %.2f m" % mid, mid > 0.95 and mid < 1.25, true)
	for i in 30:
		await get_tree().physics_frame
	await get_tree().process_frame
	_check_near("and back on the ground when it ends", sv.air_height_m if sv else -1.0, 0.0, 0.01)
	_check("the floor drawings' window covers the floor 1.5 m below the top (it's seen farther)",
		is_equal_approx(view.floor_overlay.drop_m, 1.5)
		and FloorOverlay.seen_floor_around_focus_m(view.camera, 1.5).size.y > FloorOverlay.seen_floor_around_focus_m(view.camera).size.y, true)
	main.free()


func _test_terrain_sandbox() -> void:
	_section("The 3D sandbox's terrain corner (P9)")
	var sandbox := (load("res://scenes/rooms/sandbox_3d.tscn") as PackedScene).instantiate() as RoomLayout
	_check("still silent in the validator", sandbox.validate(), [])
	for piece in ["Props/Plateau", "Props/RampEast", "Props/StairsSouth"]:
		_check("it has %s" % piece.get_file(), sandbox.get_node_or_null(piece) != null, true)
	var grid := sandbox.ground_grid()
	_check_near("the plateau's top is 1.5 m up", _grid_at(grid, Vector2(14.0, 3.0)), 1.5, 0.001)
	_check_near("half way up the stairs (their hidden ramp), about 0.75 m", _grid_at(grid, Vector2(13.0, 6.5)), 0.75, 0.1)
	_check_near("half way up the ramp, about 0.75 m", _grid_at(grid, Vector2(18.0, 3.0)), 0.75, 0.1)
	var hidden := sandbox.get_node("Props/StairsSouth/HiddenRamp") as MeshInstance3D
	_check("the stairs walk on a hidden ramp; their steps are decoration",
		not hidden.visible and hidden.is_in_group(&"walkable") and sandbox.get_node("Props/StairsSouth/Steps").is_in_group(&"decoration"), true)
	var ledges := sandbox.derive_ledges()
	_check("ledges along the plateau's cliffs, none up the middle of the stairs or the ramp",
		_ledge_at(ledges, Vector2(12.1, 3.0)) and not _ledge_at(ledges, Vector2(13.0, 6.5)) and not _ledge_at(ledges, Vector2(18.0, 3.0)), true)
	var perch := sandbox.get_node_or_null("Markers/Perch") as SimMarker
	_check("a perch on the top (4 x 4 m) with its answers noted",
		perch != null and perch.scene.resource_path == "res://scenes/world/perch.tscn" and perch.properties.get("size_m") == Vector2(4, 4) and String(perch.properties.get("answers", "")).contains("Judgement"), true)
	var dummy := sandbox.get_node_or_null("Markers/PerchDummy") as SimMarker
	_check("a passive dummy on it", dummy != null and dummy.properties.get("passive") == true and Rect2(12, 1, 4, 4).has_point(Vector2(dummy.position.x, dummy.position.z)), true)
	_check("W is the test Uppercut there", (sandbox.get_node("SandboxAbilities").get(&"test_w") as Ability).id, &"test_uppercut")
	sandbox.free()


# --- Leaps (LOOT L6; 3D.md, Leaps) ----------------------------------------------------------

## The terrain fixture plus a thin wall (x 6..6.25, z 0.5..2.5) and a pit
## (x 6..7.5, z 5.5..7), for the leap.
func _leap_layout() -> RoomLayout:
	var layout := _terrain_layout()
	var thin := _asset(layout, "ThinWall", Vector3(6.0, 0.0, 0.5))
	_asset_box(thin, Vector3(0.25, 2.2, 2.0), Vector3(0.125, 1.1, 1.0))
	_asset_footprint(thin, Footprint.Kind.WALL)
	var pit := _asset(layout, "Pit", Vector3(6.0, 0.0, 5.5))
	_asset_footprint(pit, Footprint.Kind.PIT, PackedVector2Array([Vector2(0, 0), Vector2(1.5, 0), Vector2(1.5, 1.5), Vector2(0, 1.5)]))
	return layout


func _test_leap_terrain() -> void:
	_section("A leap over terrain (LOOT L6; 3D.md, Leaps): over cliffs, a fence, a wall and a pit; the nearest walkable floor")
	var holder := await _terrain_room(_leap_layout())
	var room := holder.get_child(0) as Room
	var slime := (load("res://scenes/enemies/slime.tscn") as PackedScene).instantiate() as Unit
	slime.set(&"passive", true)
	room.get_node("Entities").add_child(slime)
	var mask := slime.collision_mask
	var seen := {"airborne": true, "mask": 0}
	var leap := func(from_m: Vector2, to_m: Vector2) -> Vector2:
		_place(slime, _px(from_m.x, from_m.y))
		await get_tree().physics_frame
		slime.movement.leap(_px(to_m.x, to_m.y), 0.3)
		for i in 25:
			await get_tree().physics_frame
			if slime.movement.is_leaping():
				seen.airborne = seen.airborne and slime.movement.is_airborne()
				seen.mask = seen.mask | slime.collision_mask
		return Vector2(Units.px_to_m(slime.global_position.x), Units.px_to_m(slime.global_position.y))
	var free_there := func(at_m: Vector2) -> bool:
		return WorldQuery.is_point_free(_px(at_m.x, at_m.y), 14.0, MovementComponent.LEAP_BLOCKING_MASK)
	var up: Vector2 = await leap.call(Vector2(1.0, 3.5), Vector2(3.5, 3.5))
	_check("from the floor up onto the plateau (over its cliff): exactly where aimed, at %s" % up, up.distance_to(Vector2(3.5, 3.5)) < 0.01, true)
	var down: Vector2 = await leap.call(Vector2(3.5, 3.5), Vector2(3.5, 5.9))
	_check("and down off it: exactly where aimed, at %s" % down, down.distance_to(Vector2(3.5, 5.9)) < 0.01, true)
	var fence: Vector2 = await leap.call(Vector2(2.5, 7.4), Vector2(2.5, 5.7))
	_check("over the fence, at %s" % fence, fence.distance_to(Vector2(2.5, 5.7)) < 0.01, true)
	var wall: Vector2 = await leap.call(Vector2(5.5, 1.5), Vector2(7.0, 1.5))
	_check("over a wall, at %s" % wall, wall.distance_to(Vector2(7.0, 1.5)) < 0.01, true)
	var pit: Vector2 = await leap.call(Vector2(6.75, 7.6), Vector2(6.75, 4.8))
	_check("over a pit, at %s" % pit, pit.distance_to(Vector2(6.75, 4.8)) < 0.01, true)
	_check("airborne all the while, colliding with nothing; its mask back after", [seen.airborne, seen.mask, slime.collision_mask], [true, 0, mask])
	var into_pit: Vector2 = await leap.call(Vector2(6.75, 7.6), Vector2(6.75, 6.8))
	_check("aimed into the pit: on its nearer rim, clear of it (a pit isn't walkable floor), at %s" % into_pit,
		absf(into_pit.x - 6.75) < 0.05 and into_pit.y > 7.3 and into_pit.y < 7.55 and free_there.call(into_pit), true)
	var into_wall: Vector2 = await leap.call(Vector2(5.0, 1.5), Vector2(6.2, 1.5))
	_check("aimed into the thin wall nearer its far face: on the floor past it, not back toward the start, at %s" % into_wall,
		into_wall.x > 6.6 and into_wall.x < 6.8 and absf(into_wall.y - 1.5) < 0.05 and free_there.call(into_wall), true)
	var edge_wall: Vector2 = await leap.call(Vector2(8.0, 6.0), Vector2(9.6, 6.0))
	_check("aimed into the wall at the room's edge: in front of it, inside the room, at %s" % edge_wall,
		edge_wall.x > 8.45 and edge_wall.x < 8.65 and absf(edge_wall.y - 6.0) < 0.1 and free_there.call(edge_wall), true)
	var past: Vector2 = await leap.call(Vector2(5.0, 7.0), Vector2(5.0, 9.5))
	_check("aimed past the room's floor: at its edge, inside, at %s" % past, absf(past.x - 5.0) < 0.05 and past.y > 7.5 and past.y < 7.7, true)
	var rim: Vector2 = await leap.call(Vector2(1.0, 6.0), Vector2(3.5, 4.95))
	_check("aimed at the plateau's rim (its ledge strip): on the nearer ground, the floor below, clear of the ledge, at %s" % rim,
		absf(rim.x - 3.5) < 0.05 and rim.y > 5.35 and rim.y < 5.55 and free_there.call(rim), true)
	holder.free()


func _test_leap_sandbox() -> void:
	_section("A leap in the 3D sandbox's terrain corner (LOOT L6: where The Last Verdict gets tried)")
	var sandbox := (load("res://scenes/rooms/sandbox_3d.tscn") as PackedScene).instantiate() as RoomLayout
	sandbox.get_node("Markers").free()   # the terrain alone: no units, no perch
	for helper in ["SandboxReactions", "SandboxAbilities", "SandboxAugments", "SandboxTalents", "SandboxLoot"]:
		if sandbox.has_node(helper):
			sandbox.get_node(helper).free()
	var holder := await _terrain_room(sandbox)
	var room := holder.get_child(0) as Room
	var slime := (load("res://scenes/enemies/slime.tscn") as PackedScene).instantiate() as Unit
	slime.set(&"passive", true)
	room.get_node("Entities").add_child(slime)
	var leap := func(from_m: Vector2, to_m: Vector2) -> Vector2:
		_place(slime, _px(from_m.x, from_m.y))
		await get_tree().physics_frame
		slime.movement.leap(_px(to_m.x, to_m.y), 0.3)
		for i in 25:
			await get_tree().physics_frame
		return Vector2(Units.px_to_m(slime.global_position.x), Units.px_to_m(slime.global_position.y))
	var up: Vector2 = await leap.call(Vector2(10.5, 3.0), Vector2(14.0, 3.0))
	_check("from the floor west of the plateau onto its top: exactly where aimed, at %s" % up, up.distance_to(Vector2(14.0, 3.0)) < 0.01, true)
	var down: Vector2 = await leap.call(Vector2(14.0, 3.0), Vector2(15.0, 7.0))
	_check("and off it to the floor south of it, at %s" % down, down.distance_to(Vector2(15.0, 7.0)) < 0.01, true)
	holder.free()


func _test_leap_in_view() -> void:
	_section("A leap's arc (LOOT L6; 3D.md, Leaps): the line from the start's ground to the landing's, the arc over it")
	var layout := _terrain_layout()
	var room := layout.build_sim()
	var main := Node2D.new()
	main.add_child(room)
	add_child(main)
	var view := WorldView.new()
	main.add_child(view)
	view.setup(main, room, null, layout)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var slime := (load("res://scenes/enemies/slime.tscn") as PackedScene).instantiate() as Unit
	slime.set(&"passive", true)
	slime.position = _px(1.0, 3.5)
	room.get_node("Entities").add_child(slime)
	for i in 3:
		await get_tree().physics_frame
	var sv := view.view_of(slime) as UnitView
	_check_near("before it: on the floor", sv.position.y if sv else -1.0, 0.0, 0.01)
	slime.movement.leap(_px(3.5, 3.5), 0.6)
	for i in 18:
		await get_tree().physics_frame
	await get_tree().process_frame
	_check_near("half way (0.3 of 0.6 s): the view half way along the line, 0 m to the top's 1.5 m", sv.position.y if sv else -1.0, 0.75, 0.05)
	_check_near("and the model at the apex over it (leap_apex_m, 2.5 m)", sv.air_height_m if sv else -1.0, sv.leap_apex_m if sv else 2.5, 0.15)
	_check_near("what sits over its head rises with it", view.unit_top_m(slime), sv.position.y + sv.air_height_m + sv.model_height_m, 0.01)
	for i in 24:
		await get_tree().physics_frame
	await get_tree().process_frame
	_check("landed: on the plateau's top (1.5 m), the arc back to 0, no knock-up status",
		[absf(sv.position.y - 1.5) < 0.01, absf(sv.air_height_m) < 0.01, slime.status_component.has_status(&"airborne")], [true, true, false])
	main.free()


# --- Blinks (ABILITIES AB15; 3D.md, 1e) -------------------------------------------------------

func _test_blink_terrain() -> void:
	_section("A blink over terrain (ABILITIES AB15; 3D.md, 1e): over walls, or stopping at them; cliffs, fences")
	var holder := await _terrain_room(_leap_layout())
	var room := holder.get_child(0) as Room
	var slime := (load("res://scenes/enemies/slime.tscn") as PackedScene).instantiate() as Unit
	slime.set(&"passive", true)
	room.get_node("Entities").add_child(slime)
	var blink := func(from_m: Vector2, to_m: Vector2, through_walls: bool) -> Vector2:
		_place(slime, _px(from_m.x, from_m.y))
		await get_tree().physics_frame
		slime.movement.blink(_px(to_m.x, to_m.y), through_walls)
		await get_tree().physics_frame
		return Vector2(Units.px_to_m(slime.global_position.x), Units.px_to_m(slime.global_position.y))
	var up: Vector2 = await blink.call(Vector2(1.0, 3.5), Vector2(3.5, 3.5), true)
	_check("from the floor onto the plateau, at once: exactly where aimed, at %s" % up, up.distance_to(Vector2(3.5, 3.5)) < 0.01, true)
	var down: Vector2 = await blink.call(Vector2(3.5, 3.5), Vector2(3.5, 5.9), true)
	_check("and off it, at %s" % down, down.distance_to(Vector2(3.5, 5.9)) < 0.01, true)
	var over: Vector2 = await blink.call(Vector2(5.0, 1.5), Vector2(7.0, 1.5), true)
	_check("over the thin wall, at %s" % over, over.distance_to(Vector2(7.0, 1.5)) < 0.01, true)
	var short: Vector2 = await blink.call(Vector2(5.0, 1.5), Vector2(7.0, 1.5), false)
	_check("stopping at walls: on its near side, clear of it (x < 6 m less the body), at %s" % short,
		short.x > 5.45 and short.x < 5.6 and absf(short.y - 1.5) < 0.05, true)
	var cliff: Vector2 = await blink.call(Vector2(1.0, 3.5), Vector2(3.5, 3.5), false)
	_check("stopping at walls, it still goes up the cliff (a ledge isn't a wall), at %s" % cliff, cliff.distance_to(Vector2(3.5, 3.5)) < 0.01, true)
	var fence: Vector2 = await blink.call(Vector2(2.5, 7.4), Vector2(2.5, 5.7), false)
	_check("and over the fence, at %s" % fence, fence.distance_to(Vector2(2.5, 5.7)) < 0.01, true)
	holder.free()


func _test_blink_in_view() -> void:
	_section("A blink in the view (ABILITIES AB15; 3D.md, 1e): the snap, the ground, the afterimage, the flash")
	var layout := _terrain_layout()
	var room := layout.build_sim()
	var main := Node2D.new()
	main.add_child(room)
	add_child(main)
	var view := WorldView.new()
	main.add_child(view)
	view.setup(main, room, null, layout)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var slime := (load("res://scenes/enemies/slime.tscn") as PackedScene).instantiate() as Unit
	slime.set(&"passive", true)
	slime.position = _px(1.0, 3.5)
	room.get_node("Entities").add_child(slime)
	for i in 3:
		await get_tree().physics_frame
	var sv := view.view_of(slime) as UnitView
	var ghosts_before := _ghosts(view).size()
	slime.movement.blink(_px(3.5, 3.5))
	var ghosts := _ghosts(view)
	var ghost_at := Vector3.INF
	if ghosts.size() > ghosts_before:
		var mesh := ghosts[ghosts.size() - 1].get_child(0) as Node3D
		ghost_at = mesh.global_position if mesh else Vector3.INF
	_check("at once, an afterimage where the model was (1, 0, 3.5), at %s" % ghost_at,
		ghost_at.is_finite() and Vector2(ghost_at.x, ghost_at.z).distance_to(Vector2(1.0, 3.5)) < 0.05, true)
	await get_tree().physics_frame
	await get_tree().process_frame
	_check_near_v3("the next tick the view stands where it landed, on the plateau's top (no rise at 8 m/s)", sv.position, Vector3(3.5, 1.5, 3.5), 0.01)
	_check_near_v3("and it's drawn there (no slide from the start)", sv.get_global_transform_interpolated().origin, Vector3(3.5, 1.5, 3.5), 0.01)
	_check("the model flashes in blink_flash_color", [sv._flash > 0.5, sv._overlay.get_shader_parameter(&"flash_color") == sv.blink_flash_color], [true, true])
	for i in 20:
		await get_tree().physics_frame
	_check("the afterimage fades and goes (0.25 s)", _ghosts(view).size(), ghosts_before)
	# A short blink, under WorldView's own 64 px teleport snap: only UnitView's
	# reset keeps it from sliding. The drawn position is read from a real
	# _process (a test coroutine reads the plain transform; measured in AB15:
	# without the reset the model slid 0.7 m over one tick).
	var watcher := _drawn_watcher(sv)
	await get_tree().process_frame
	(watcher.get(&"drawn") as Array).clear()
	slime.movement.blink(_px(2.8, 3.5))
	for i in 4:
		await get_tree().physics_frame
	var drawn: Array = watcher.get(&"drawn")
	var between := drawn.filter(func(p: Vector3) -> bool: return absf(p.x - 3.5) > 0.01 and absf(p.x - 2.8) > 0.01)
	_check("a short blink (0.7 m) is never drawn between its ends (UnitView's own snap; %d frames drawn)" % drawn.size(),
		[drawn.size() >= 4, between.size(), absf((drawn.back() as Vector3).x - 2.8) < 0.01 if not drawn.is_empty() else false], [true, 0, true])
	watcher.free()
	slime.take_damage(1.0)
	_check("a hit afterwards flashes in the hit's flash_color again", sv._overlay.get_shader_parameter(&"flash_color") == sv.flash_color, true)
	main.free()


## A node recording `target`'s drawn (interpolated) position from its own
## _process, in `drawn`. get_global_transform_interpolated() read from a test
## coroutine returns the plain transform (measured in AB15).
func _drawn_watcher(target: Node3D) -> Node:
	var src := GDScript.new()
	src.source_code = "extends Node\nvar target: Node3D\nvar drawn: Array = []\nfunc _process(_delta: float) -> void:\n\tif is_instance_valid(target):\n\t\tdrawn.append(target.get_global_transform_interpolated().origin)\n"
	src.reload()
	var watcher := Node.new()
	watcher.set_script(src)
	add_child(watcher)
	watcher.set(&"target", target)
	return watcher


## The placeholder afterimages (UnitView._spawn_ghost()) under the view.
func _ghosts(view: WorldView) -> Array[Node]:
	var out: Array[Node] = []
	for child in view.get_children():
		if String(child.name).begins_with("Ghost") and not child.is_queued_for_deletion():
			out.append(child)
	return out


# --- Pickups (LOOT L7; LOOT.md, View) ------------------------------------------------------------

func _test_pickup_view() -> void:
	_section("A drop in the view (LOOT L7; LOOT.md, View): the gem in its rarity's color, the hop's arc, the beam, gone when taken")
	_check("PickupView's scene loads with the view (no load on the first drop)", WorldView.DEFAULT_VIEW_SCENES.has("res://scenes/view/pickup_view.tscn"), true)
	var layout := _terrain_layout()
	var room := layout.build_sim()
	var main := Node2D.new()
	main.add_child(room)
	add_child(main)
	var view := WorldView.new()
	main.add_child(view)
	view.setup(main, room, null, layout)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var table := LootTable.get_default()
	var entities := room.get_node("Entities")
	var rng := RandomNumberGenerator.new()
	rng.seed = 8001
	var common: Array[Item] = [ItemRoller.roll_item(Item.Rarity.COMMON, null, table, rng)]
	Loot.rng.seed = 8002
	var pickup: Pickup = Loot.drop(common, _px(7.0, 1.5), entities)[0]
	var pv := view.view_of(pickup) as PickupView
	_check("the drop gets its PickupView at once", pv != null, true)
	if pv == null:
		main.free()
		return
	_check("a small gem in the Common color; no beam below Legendary",
		[pv.get_color() == table.get_rarity(Item.Rarity.COMMON).color, pv.gem != null, pv.beam == null], [true, true, true])
	for i in 9:
		await get_tree().physics_frame
	var t := pickup.get_hop_progress()
	var along := pickup.get_hop_from().lerp(pickup.global_position, t)
	_check_near_v3("mid-hop (%.2f of it): along the line from where it dropped, the arc over the floor" % t,
		pv.position, Units.to_view(along, pv.hop_apex_m * 4.0 * t * (1.0 - t)), 0.01)
	_check("(the arc near its top, %.2f m)" % pv.position.y, pv.position.y > 0.5, true)
	for i in 12:
		await get_tree().physics_frame
	_check_near_v3("landed: on the floor at its spot", pv.position, Units.to_view(pickup.global_position, 0.0), 0.01)
	var heights: Array[float] = []
	var turns: Array[float] = []
	for i in 60:
		await get_tree().physics_frame
		heights.append(pv.pivot.position.y)
		turns.append(pv.pivot.rotation.y)
	_check("the gem hovers 0.35 m up, bobbing by up to 0.05 m (%.3f–%.3f m over 1 s)" % [heights.min(), heights.max()],
		[heights.min() >= 0.299, heights.max() <= 0.401, heights.max() - heights.min() > 0.03], [true, true, true])
	_check("and turns slowly", absf(turns[turns.size() - 1] - turns[0]) > 0.3, true)
	# A Legendary: its beam once it lands. An Exotic: none.
	var named: Array[Item] = [ItemRoller.make_named(load("res://data/items/item_knight_tidebreaker.tres"), table, rng)]
	var lp: Pickup = Loot.drop(named, _px(7.0, 3.0), entities)[0]
	var lv := view.view_of(lp) as PickupView
	_check("a Legendary: a beam, hidden while it hops", [lv != null and lv.beam != null, lv != null and lv.is_beam_shown()], [true, false])
	for i in 22:
		await get_tree().physics_frame
	if lv != null and lv.beam != null:
		var orange := table.get_rarity(Item.Rarity.LEGENDARY).color
		_check("landed: the beam shows, 1.25 m tall, orange at 0.55, drawn with PillarView's shader",
			[lv.is_beam_shown(), (lv.beam.mesh as CylinderMesh).height, lv.beam.get_instance_shader_parameter(&"color"),
			(lv.beam.material_override as ShaderMaterial).shader == preload("res://scripts/view/pillar.gdshader")],
			[true, 1.25, Color(orange, 0.55), true])
		_check("and the gem is orange", lv.get_color() == orange, true)
	var exotic: Array[Item] = [ItemRoller.roll_item(Item.Rarity.EXOTIC, null, table, rng)]
	var ep: Pickup = Loot.drop(exotic, _px(8.0, 1.5), entities)[0]
	for i in 22:
		await get_tree().physics_frame
	var ev := view.view_of(ep) as PickupView
	_check("an Exotic: no beam", ev != null and ev.beam == null and not ev.is_beam_shown(), true)
	# On the plateau: its arc over the top, landing on it.
	var up: Array[Item] = [ItemRoller.roll_item(Item.Rarity.RARE, null, table, rng)]
	var top_pickup: Pickup = Loot.drop(up, _px(3.5, 3.5), entities)[0]
	var tv := view.view_of(top_pickup) as PickupView
	for i in 9:
		await get_tree().physics_frame
	var tt := top_pickup.get_hop_progress()
	_check_near("a drop on the plateau: mid-hop over its top (1.5 m plus the arc)", tv.position.y if tv else -1.0,
		PLATEAU_TOP + (tv.hop_apex_m if tv else 0.6) * 4.0 * tt * (1.0 - tt), 0.01)
	for i in 12:
		await get_tree().physics_frame
	_check_near("landed on the top", tv.position.y if tv else -1.0, PLATEAU_TOP, 0.01)
	# Taken: gone at once.
	var views: Array = [pv, lv, ev, tv]
	Loot.take_ground_drops(room)
	await get_tree().physics_frame
	await get_tree().process_frame
	_check("taken: every drop's view is gone the next frame", views.all(func(v: Variant) -> bool: return not is_instance_valid(v)), true)
	main.free()


# --- P7's 2D-only looks (after P9) --------------------------------------------------------

func _test_arcs_and_pillars() -> void:
	_section("P7's 2D-only looks: swing arcs from the feet, VFX.impact()'s pillar (3D.md)")
	var calls := 0
	var through_origin := 0
	for path in _files_mentioning("res://scripts/", "VFX.slash("):
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if line.contains("VFX.slash(") and not line.strip_edges().begins_with("#"):
				calls += 1
				through_origin += 1 if line.contains("VFX.drawing_origin(") else 0
	_check("every VFX.slash() call centers on VFX.drawing_origin() (the Player's swings, Cleave, Cleave Wave, Judgement, the Uppercut; since ENEMIES_AI AI3d the enemy library's cleave arc)",
		[calls, through_origin], [6, 6])

	var layout := _terrain_layout()
	var room := layout.build_sim()
	var main := Node2D.new()
	main.add_child(room)
	add_child(main)
	var entities := room.get_node("Entities") as Node2D
	var slime := (load("res://scenes/enemies/slime.tscn") as PackedScene).instantiate() as Unit
	slime.set(&"passive", true)
	slime.position = _px(3.5, 3.5)
	entities.add_child(slime)
	await get_tree().physics_frame
	_check("without a view (the tests): swing arcs center on the body's center (the old 2D game's 3/4 look)",
		[VFX.drawings_at_feet, VFX.drawing_origin(slime)], [false, slime.get_center()])
	var children_before := entities.get_child_count()
	VFX.impact(entities, _px(3.5, 3.5), Color(1.0, 0.9, 0.4, 0.95), 90.0, 0.35)
	_check("without a view, VFX.impact() makes nothing (its 2D pillar went in the cleanup's C3)",
		[entities.get_child_count() - children_before, get_tree().get_nodes_in_group(&"world_view").size()], [0, 0])

	var view := WorldView.new()
	main.add_child(view)
	view.setup(main, room, null, layout)
	var warm_up := _pillars(view)
	_check("setting up the view draws one invisible pillar, so its shader compiles while the room loads (not on the first hit)",
		warm_up.size() == 1 and is_zero_approx((warm_up[0].call(&"get_color") as Color).a), true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("under the 3D view: they center on the feet, where the swing's cone starts",
		[VFX.drawings_at_feet, VFX.drawing_origin(slime)], [true, slime.global_position])
	for i in 30:
		if _pillars(view).is_empty():
			break
		await get_tree().physics_frame
	_check("the warm-up pillar goes at once (0.05 s)", _pillars(view).size(), 0)
	var color := Color(1.0, 0.9, 0.4, 0.95)
	VFX.impact(entities, _px(3.5, 3.5), color, 90.0, 0.35)
	VFX.impact(entities, _px(1.0, 1.0), color, 24.0, 0.35)
	var pillars := _pillars(view)
	_check("VFX.impact() raises a PillarView under the view (one per call)", pillars.size(), 2)
	if pillars.size() == 2:
		var top := pillars[0] as Node3D
		var floor_pillar := pillars[1] as Node3D
		_check_near_v3("it stands on the ground where it's hit: the plateau's top (3.5, 1.5, 3.5)", top.global_position, Vector3(3.5, 1.5, 3.5), 0.01)
		_check_near_v3("or the floor (1, 0, 1)", floor_pillar.global_position, Vector3(1.0, 0.0, 1.0), 0.01)
		var pivot := top.get(&"pivot") as Node3D
		_check_near("as tall as the 2D one, px as m: 90 px is 2.81 m", pivot.scale.y if pivot else 0.0, Units.px_to_m(90.0), 0.001)
		var beam := top.get(&"beam") as MeshInstance3D
		var mesh := beam.mesh as CylinderMesh if beam else null
		var material := beam.material_override as ShaderMaterial if beam else null
		_check("a tapered beam, 12 px (0.375 m) across at its foot and 4 px at its top, in the hit's color, casting no shadow",
			mesh != null and is_equal_approx(mesh.bottom_radius, 0.1875) and is_equal_approx(mesh.top_radius, 0.0625)
			and (top.call(&"get_color") as Color).is_equal_approx(color)
			and beam.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, true)
		_check("drawn by pillar.gdshader, 0.8 m nearer the camera (in front of the unit it stands in); one material and one beam mesh for all",
			material != null and material.shader.resource_path == "res://scripts/view/pillar.gdshader"
			and is_equal_approx(float(material.get_shader_parameter(&"pull_m")), 0.8)
			and material == (floor_pillar.get(&"beam") as MeshInstance3D).material_override
			and beam.mesh == (floor_pillar.get(&"beam") as MeshInstance3D).mesh, true)
		for i in 10:
			await get_tree().physics_frame
		await get_tree().process_frame
		var alpha := (top.call(&"get_color") as Color).a if is_instance_valid(top) else -1.0
		var width := pivot.scale.x if is_instance_valid(pivot) else -1.0
		_check("part way, it narrows and fades as the 2D one does (width %.2f, alpha %.2f)" % [width, alpha],
			width > 0.2 and width < 1.0 and alpha > 0.0 and alpha < 0.95, true)
	for i in 60:
		if _pillars(view).is_empty():
			break
		await get_tree().physics_frame
	_check("each frees itself when its 0.35 s are over", _pillars(view).size(), 0)
	main.free()
	_check("when the view goes, the drawings' no-view settings come back", [VFX.drawings_at_feet, VFX.floor_squash], [false, VFX.FLOOR_SQUASH_2D])


func _pillars(view: WorldView) -> Array[Node]:
	var out: Array[Node] = []
	for child in view.get_children():
		if child.scene_file_path == VFX.PILLAR_VIEW_SCENE:
			out.append(child)
	return out


# --- The cleanup's C3: the 2D looks deleted ------------------------------------------------

func _test_2d_looks_gone() -> void:
	_section("The cleanup's C3: the 2D looks deleted")
	var left: Array[String] = []
	for path in ["res://scenes/player/player.tscn", "res://scenes/enemies/slime.tscn", "res://scenes/enemies/slime_elite.tscn"]:
		var u := (load(path) as PackedScene).instantiate()
		for n: String in ["Body", "Shadow", "SwordPivot", "MovementVFXComponent"]:
			if u.get_node_or_null(NodePath(n)) != null:
				left.append("%s/%s" % [path.get_file(), n])
		u.free()
	_check("no unit scene has a 2D look node left: Body, Shadow, SwordPivot, MovementVFXComponent (left: %s)" % [left], left.is_empty(), true)
	_check("their scripts are gone: GameCamera, MovementVFXComponent",
		[ResourceLoader.exists("res://scripts/camera/game_camera.gd"), ResourceLoader.exists("res://scripts/vfx/movement_vfx_component.gd")], [false, false])
	var vfx_methods: Array[String] = []
	for m in (load("res://scripts/vfx/vfx.gd") as Script).get_script_method_list():
		vfx_methods.append(String(m["name"]))

	var holder := Node2D.new()
	add_child(holder)
	var slime := (load("res://scenes/enemies/slime.tscn") as PackedScene).instantiate() as Enemy
	slime.passive = true
	slime.position = Vector2(64.0, 64.0)
	holder.add_child(slime)
	var knight := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	knight.position = Vector2(240.0, 64.0)
	holder.add_child(knight)
	await get_tree().physics_frame
	_check("no Unit.body, no 2D flash in HitFeel, no VFX.afterimage()",
		[&"body" in slime, &"flash_time" in GameFeel.hit_feel, &"flash_modulate" in GameFeel.hit_feel, vfx_methods.has("afterimage")], [false, false, false, false])
	var unit_bar := slime.get_node(^"HealthBar")
	_check("a unit's HealthBar only holds the bar's settings (Ryan): it doesn't run or draw on its unit", unit_bar.call(&"_is_2d_bar_off"), true)
	var copy := unit_bar.duplicate()
	holder.add_child(copy)
	_check("its copy elsewhere (ScreenOverlay's) does", copy.call(&"_is_2d_bar_off"), false)
	copy.free()
	var side := knight.swing_side
	knight._swing_sword(0.1)
	_check("a swing still alternates swing_side (the floor drawings' slashes read it)", knight.swing_side, -side)
	var projectile := Projectile.new()
	projectile.debug_draw = true
	projectile.process_mode = Node.PROCESS_MODE_DISABLED   # no ability: only its _ready matters here
	holder.add_child(projectile)
	var move := MovementComponent.new()
	move.debug_draw_path = true
	var mover := CharacterBody2D.new()
	mover.add_child(move)
	holder.add_child(mover)
	var bit := FloorOverlay.DRAWING_VISIBILITY_BIT
	var path_line := move.get(&"_debug_line") as Line2D
	_check("debug drawings show on the 3D floor (Ryan's pick, C2): a projectile's sweep, the movement path (on the floor-drawing layer)",
		projectile.visibility_layer & bit != 0 and move.visibility_layer & bit != 0 and path_line != null and path_line.visibility_layer & bit != 0, true)
	projectile.free()
	_check("the slime's death_free_time is the old 2D squash's length, 0.33 s", slime.death_free_time, 0.33)
	slime.health.take_damage(slime.health.max_health * 10.0)
	for i in 10:
		await get_tree().physics_frame
	_check("a dead unit is still there before its death_free_time", is_instance_valid(slime), true)
	for i in 20:
		await get_tree().physics_frame
	_check("and freed after it", is_instance_valid(slime), false)
	holder.free()

	var green := (load("res://scenes/enemies/slime.tscn") as PackedScene).instantiate() as Unit
	var elite := (load("res://scenes/enemies/slime_elite.tscn") as PackedScene).instantiate() as Unit
	_check("the capsules' colors are data (model_color, C2): the slime green, the elite purple",
		[green.model_color, elite.model_color], [Color(0.35, 0.85, 0.4, 1.0), Color(0.62, 0.35, 0.85, 1.0)])
	var uv := (load("res://scenes/view/unit_view.tscn") as PackedScene).instantiate() as UnitView
	uv.unit = green
	green.modulate = Color(1.0, 0.5, 0.5)
	_check("UnitView's capsule takes it, times the unit's tint (the sandbox dummies')", uv._body_color(), Color(0.35, 0.85, 0.4, 1.0) * Color(1.0, 0.5, 0.5))
	_check("the dash ghosts' numbers are UnitView's own, the old 2D component's values (4, 0.03 s apart, 0.15 s fade, its color)",
		[uv.afterimage_count, uv.afterimage_interval, uv.afterimage_fade_time, uv.afterimage_color], [4, 0.03, 0.15, Color(0.55, 0.85, 1.0, 0.5)])
	uv.free()
	green.free()
	elite.free()


## On the Knight's model (UnitView): the post-hit i-frame blink (from
## combat_test) and the cast and swing clips positioned by progress (from
## abilities_test's AB14 checks, which positioned an AnimationPlayer under the
## 2D Body until the cleanup's C3).
func _test_model_blink_and_clips() -> void:
	_section("The cleanup's C3: the Knight's model blinks, and plays its cast and swing clips by progress")
	var view := WorldView.new()
	add_child(view)
	view.camera = _aim_camera(view, FOCUS)
	view.watch_sim()
	var holder := Node2D.new()
	add_child(holder)
	var knight := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	knight.position = Units.to_sim(FOCUS)
	holder.add_child(knight)
	var kv := view.view_of(knight) as UnitView
	var anim: AnimationPlayer = kv._anim if kv else null
	if anim == null:
		_check("the Knight's view has its model's AnimationPlayer", false, true)
		holder.free()
		view.free()
		return
	await get_tree().physics_frame

	# The post-hit i-frames' blink.
	knight.take_damage(10.0)
	var hidden_seen := false
	var t0 := Time.get_ticks_msec()
	while knight.has_invulnerability(Unit.HIT_IFRAMES_ID) and Time.get_ticks_msec() - t0 < 2000:
		await get_tree().process_frame
		if not kv._model.visible:
			hidden_seen = true
	_check("the model blinks during the post-hit i-frames", hidden_seen, true)
	await get_tree().process_frame
	_check("and shows again after", kv._model.visible, true)

	# Cleave's cast_anim: start to strike by the cast's progress, then the follow-through.
	var ab := knight.abilities
	var clip := ab.q.cast_anim
	knight.resource_pool.restore(1000.0)   # Fury starts empty
	var cast_ok := ab.try_cast(&"q", knight.global_position + Vector2(60.0, 0.0))
	var in_step := cast_ok and kv._phase == UnitView.Phase.LEAD_BY_PROGRESS
	var samples := 0
	var reached := 0.0
	while ab.casting and samples < 30:
		await get_tree().physics_frame
		if not ab.casting:
			break
		kv._update_clips(0.0)
		var share := anim.current_animation_position / anim.get_animation(clip).length
		var lo := lerpf(kv.action_start, kv.action_strike, kv._progress_prev)
		var hi := lerpf(kv.action_start, kv.action_strike, kv._progress_cur)
		in_step = in_step and anim.assigned_animation == clip and is_zero_approx(anim.get_playing_speed()) \
			and share >= lo - 0.0001 and share <= hi + 0.0001
		reached = maxf(reached, kv._progress_cur)
		samples += 1
	_check("Cleave's cast_anim: the model holds its clip and the view positions it by the cast's progress, start to strike (%d ticks)" % samples,
		in_step and samples >= 8 and reached > 0.5, true)
	for i in 3:
		await get_tree().process_frame
	var follow_share := anim.current_animation_position / anim.get_animation(clip).length
	_check("the effect starts: the clip follows through from its strike frame toward its end",
		kv._phase == UnitView.Phase.FOLLOW and follow_share >= kv.action_strike - 0.0001 and follow_share <= kv.action_end + 0.0001, true)
	await get_tree().create_timer(kv.cast_follow_through + 0.15).timeout
	_check("then the base clip again (idle)", [kv._phase, anim.current_animation], [UnitView.Phase.NONE, kv.idle_clip])

	ab.reset_cooldown(&"q")
	knight.resource_pool.restore(1000.0)
	var recast := ab.try_cast(&"q", knight.global_position + Vector2(60.0, 0.0))
	for i in 3:
		await get_tree().physics_frame
	var leading := ab.casting and kv._phase == UnitView.Phase.LEAD_BY_PROGRESS
	knight.apply_stun(1.0)
	await get_tree().create_timer(kv.cast_follow_through + 0.15).timeout
	_check("a stun interrupts the cast: its clip follows through, then the stun pose",
		[recast, leading, ab.casting, kv._phase, anim.current_animation], [true, true, false, UnitView.Phase.NONE, kv.stun_clip])
	knight.status_component.clear()

	knight.resource_pool.restore(1000.0)
	ab.try_cast(&"w", knight.global_position)
	_check("no cast time (Iron Resolve): its clip leads by time (instant_cast_lead), not progress",
		[kv._phase, anim.assigned_animation], [UnitView.Phase.LEAD_BY_TIME, ab.w.cast_anim])
	await get_tree().create_timer(kv.instant_cast_lead + kv.cast_follow_through + 0.15).timeout

	# The combo's first swing: start, strike at the hit, end, by swing progress.
	var t1 := Time.get_ticks_msec()
	while not knight.attack.can_swing() and Time.get_ticks_msec() - t1 < 2000:
		await get_tree().physics_frame
	var swing_clip := knight.attack.combo.swings[0].swing_anim
	var swing_ok := knight.attack.try_swing(Vector2.RIGHT)
	in_step = swing_ok and kv._phase == UnitView.Phase.LEAD_BY_PROGRESS and anim.assigned_animation == swing_clip
	samples = 0
	while knight.attack.is_swinging() and samples < 40:
		await get_tree().physics_frame
		if not knight.attack.is_swinging():
			break
		kv._update_clips(0.0)
		var share := anim.current_animation_position / anim.get_animation(swing_clip).length
		var lo := UnitView.action_clip_share(kv._progress_prev, kv._hit_share, kv.action_start, kv.action_strike, kv.action_end)
		var hi := UnitView.action_clip_share(kv._progress_cur, kv._hit_share, kv.action_start, kv.action_strike, kv.action_end)
		in_step = in_step and anim.assigned_animation == swing_clip and share >= lo - 0.0001 and share <= hi + 0.0001
		samples += 1
	_check("the swing_anim: positioned by swing progress, its strike frame on the hit (%d ticks)" % samples, in_step and samples >= 10, true)
	for i in 3:
		await get_tree().process_frame
	_check("the swing over: the base clip again", kv._phase, UnitView.Phase.NONE)
	t1 = Time.get_ticks_msec()
	while not knight.attack.can_swing() and Time.get_ticks_msec() - t1 < 2000:
		await get_tree().physics_frame
	knight.attack.try_swing(Vector2.RIGHT)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var swinging := kv._phase == UnitView.Phase.LEAD_BY_PROGRESS
	knight.attack.cancel_swing()
	_check("a cancelled swing ends its clip at once", [swinging, kv._phase, kv._clip], [true, UnitView.Phase.NONE, &""])

	# LOOT L6: a leaping cast (The Last Verdict's Judgement Leap) keeps its clip
	# until it lands, never the knock-up's stun pose.
	knight.abilities.add_augment(load("res://data/augments/augment_judgement_leap.tres"), &"view_test_leap")
	var leap_clip := ab.get_ability(&"r").cast_anim
	var leap_ok := ab.try_cast(&"r", knight.global_position + Vector2(120.0, 0.0))
	t1 = Time.get_ticks_msec()
	while not knight.movement.is_leaping() and Time.get_ticks_msec() - t1 < 2000:
		await get_tree().physics_frame
	var held := knight.movement.is_leaping()
	var stun_pose := false
	while knight.movement.is_leaping() and Time.get_ticks_msec() - t1 < 3000:
		await get_tree().process_frame
		held = held and kv._phase != UnitView.Phase.NONE and anim.assigned_animation == leap_clip
		stun_pose = stun_pose or anim.current_animation == kv.stun_clip
	_check("a leaping cast holds its cast_anim (%s) through the leap, never the stun pose" % leap_clip,
		[leap_ok, held, stun_pose], [true, true, false])

	# ABILITIES AB15: a blink leaves one of the rigged model's pooled afterimages.
	await get_tree().physics_frame
	var shown_before := kv._ghost_pool.filter(func(g: Dictionary) -> bool: return (g["root"] as Node3D).visible).size()
	var blinked := knight.movement.blink(knight.global_position + Vector2(80.0, 0.0))
	var shown := kv._ghost_pool.filter(func(g: Dictionary) -> bool: return (g["root"] as Node3D).visible).size()
	_check("the Knight's blink shows one pooled afterimage of his model", [blinked, shown - shown_before], [true, 1])
	holder.free()
	view.free()
	# A sound still playing at quit prints a harmless leak warning (AUDIO.md).
	Audio.stop_all()
	for i in 10:
		await get_tree().process_frame


# --- Enemy poses (ENEMIES_AI AI1; Tells) -----------------------------------------------------

## UnitView's pose hooks: an enemy's pose (its brain's tell) leans and
## squashes its capsule and shows its rim on the overlay's second channel,
## blended in over pose_blend_time; the hit flash wins over the rim; no pose,
## no look. The brain's pose is set by hand (no player here to fight), and the
## view's frame is called directly so the enemy's own tick doesn't run.
func _test_enemy_poses() -> void:
	_section("Enemy poses (ENEMIES_AI AI1): lean, squash, rim")
	var view := WorldView.new()
	add_child(view)
	view.camera = _aim_camera(view, FOCUS)
	view.watch_sim()
	var brute := (load("res://scenes/enemies/test_brute.tscn") as PackedScene).instantiate() as Enemy
	brute.position = Units.to_sim(FOCUS)
	add_child(brute)
	var bv := view.view_of(brute) as UnitView
	var body := bv.find_child("Body", true, false) as Node3D
	var capsule := bv.find_child("Capsule", true, false) as GeometryInstance3D
	var brain := brute.get_brain()
	_check("the brute has a view, a capsule and a brain", [bv != null, body != null, brain != null], [true, true, true])
	if bv == null or body == null or brain == null:
		view.free()
		brute.free()
		return
	_check("no pose: no look", [brute.get_pose(), bv.get_pose_look_now().lean_deg], [&"", 0.0])
	brute.ai = Enemy.AI.AGGRO   # its brain counts as running (the tick that would drop it doesn't run)
	brain.set(&"_pose", &"crouch")
	_check("the enemy shows its brain's pose, from its pose set", [brute.get_pose(), brute.get_pose_set().get_look(&"crouch").squash], [&"crouch", 0.8])
	bv._process(0.02)
	var partway: float = bv.get_pose_look_now().lean_deg
	_check("blended in: part way after 0.02 s", partway > 1.0 and partway < 14.0, true)
	for i in 30:
		bv._process(0.02)
	_check_near("crouch: leaning 15° toward its front", bv.get_pose_look_now().lean_deg, 15.0, 0.05)
	_check_near("the capsule tilts about its base", body.rotation.x, deg_to_rad(15.0), 0.002)
	_check_near("squashed to 0.8 tall", body.scale.y, 0.8, 0.01)
	_check_near("and wider (1.1)", body.scale.x, 1.1, 0.01)
	brain.set(&"_pose", &"draw_back")
	for i in 30:
		bv._process(0.02)
	var rim: Color = capsule.get_instance_shader_parameter(&"rim")
	_check("draw_back: an orange rim on the overlay (pulsing)", [rim.a > 0.0, rim.r > rim.b], [true, true])
	brute.damaged.emit(5.0, null)
	bv._process(0.01)
	rim = capsule.get_instance_shader_parameter(&"rim")
	_check("the hit flash wins: no rim while it plays", [float(capsule.get_instance_shader_parameter(&"flash")) > 0.0, rim.a], [true, 0.0])
	brain.set(&"_pose", &"")
	for i in 40:
		bv._process(0.02)
	rim = capsule.get_instance_shader_parameter(&"rim")
	_check_near("no pose again: upright", bv.get_pose_look_now().lean_deg, 0.0, 0.05)
	_check("and no rim", rim.a, 0.0)
	brute.ai = Enemy.AI.IDLE
	brute.free()
	view.free()


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
