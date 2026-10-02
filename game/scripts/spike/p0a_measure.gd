extends Node
## P0a spike (throwaway): the go/no-go measurements (3D_PIVOT.md, P0a).
## Headless: criteria 1, 3, 4 (analytic) and 6. Windowed: 2, 4 (rendered), 5.
## Prints a report and quits.

const BOLT: Ability = preload("res://data/abilities/test_q_bolt.tres")
const SLIME_SCENE: PackedScene = preload("res://scenes/enemies/slime.tscn")

var spike   # p0a_spike.gd (untyped: the spike preloads this script)
var windowed: bool = false
var only_c5: bool = false   # --p0a-no-view: C5 on the 2D game alone

var _lines: PackedStringArray = []
var _sampling: bool = false
var _samples: Array = []   # per rendered frame: [usec, player view pos, screen pos, time_scale]
var _track: Node3D = null  # an extra view node sampled per frame (teleport check)
var _track_samples: Array = []


func _ready() -> void:
	process_priority = 1000
	_run.call_deferred()


func _run() -> void:
	await _frames(5)
	if only_c5:
		_say("=== P0a: C5 on today's 2D game (no 3D view; the 2D world drawn as usual) ===")
		_clear_enemies()
		await _frames(5)
		await _c5()
	elif OS.get_cmdline_user_args().has("--p0a-screenshot"):
		await _screenshots()
	elif OS.get_cmdline_user_args().has("--p0a-c4-only"):
		_say("=== P0a: C4 rendered only, overlay %dx ===" % spike.overlay_scale)
		_clear_enemies()
		await _frames(5)
		await _c4_rendered()
	elif windowed:
		await _windowed()
	else:
		await _headless()
	print("\n".join(_lines))
	get_tree().quit()


func _say(s: String) -> void:
	_lines.append(s)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _draws(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw


func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.free()


func _place_player(p: Vector2) -> void:
	var pl: Player = spike.player
	pl.movement.stop_displacement()
	pl.movement.stop()
	pl.velocity = Vector2.ZERO
	pl.global_position = p
	pl.reset_physics_interpolation()
	await _frames(40)   # input speed decays, dash end lag clears


func _hold(actions: Array, frames: int) -> void:
	for a: StringName in actions:
		Input.action_press(a)
	await _frames(frames)
	for a: StringName in actions:
		Input.action_release(a)


# =====================================================================================
# Headless
# =====================================================================================

func _headless() -> void:
	_say("=== P0a headless (Godot %s) ===" % Engine.get_version_info().string)
	_clear_enemies()
	await _frames(2)
	await _c1()
	await _c6()
	_c3()
	_c4_analytic()


# --- C1 ------------------------------------------------------------------------------

func _set_2d(mode: String) -> void:
	var room: Node2D = spike.room
	room.visible = true
	if mode == "visible":
		get_viewport().canvas_cull_mask |= spike.VIS_SIM
	elif mode == "layer-hidden":
		get_viewport().canvas_cull_mask &= ~spike.VIS_SIM
	else:   # "visible=false"
		get_viewport().canvas_cull_mask |= spike.VIS_SIM
		room.visible = false


func _c1() -> void:
	_say("\n-- C1: a hidden CharacterBody2D still collides (150 frames sliding along the long wall)")
	# The first run is a warm-up (it starts from a different state); then each
	# mode, and "visible" again at the end, all from the same state.
	var modes := ["warm-up (visible)", "visible", "layer-hidden", "visible=false", "visible (again)"]
	var runs: Array = []
	for mode: String in modes:
		_set_2d("visible" if mode.begins_with("warm-up") else mode.split(" ")[0])
		await _place_player(Vector2(80, 470))
		var pos: Array[Vector2] = []
		Input.action_press(&"move_right")
		Input.action_press(&"move_down")
		for i in 150:
			await get_tree().physics_frame
			pos.append(spike.player.global_position)
		Input.action_release(&"move_right")
		Input.action_release(&"move_down")
		runs.append(pos)
		_say("  %s: ends at %s" % [mode, pos[-1]])
	_set_2d("layer-hidden")
	for k in [2, 3, 4]:
		var worst := 0.0
		for i in 150:
			worst = maxf(worst, (runs[1][i] as Vector2).distance_to(runs[k][i]))
		_say("  visible vs %s: max difference over 150 frames = %.6f px  %s" % [modes[k], worst, "PASS" if worst < 0.001 else "FAIL"])
	var last: Vector2 = runs[2][-1]
	_say("  slid along the wall (y stays at the wall, x moved east): y=%.2f x=%.1f  %s" % [last.y, last.x, "PASS" if absf(last.y - 501.0) < 1.0 and last.x > 250.0 else "FAIL"])


# --- C6 ------------------------------------------------------------------------------

func _c6() -> void:
	_say("\n-- C6: terrain proof (plateau x 5..8 y 10..12 at 1.5 m; ramp (3..4, 11); stairs (6..7, 13..14); ledges layer 11; fence layer 7)")
	var t = spike.terrain
	_say("  ledge colliders: %d; fence: 1" % t.ledge_rects_px().size())
	var pl: Player = spike.player
	# Walking into the north cliff.
	await _place_player(Vector2(220, 296))
	await _hold([&"move_down"], 60)
	_say("  walk south into the plateau's north cliff: stops at y=%.1f (cliff at 320)  %s" % [pl.global_position.y, "PASS" if pl.global_position.y < 312.0 else "FAIL"])
	await _place_player(Vector2(220, 296))
	var dashed := pl.dash.try_dash(Vector2.DOWN)
	await _frames(25)
	_say("  dash south into it (started %s): stops at y=%.1f  %s" % [dashed, pl.global_position.y, "PASS" if dashed and pl.global_position.y < 312.0 else "FAIL"])
	# The fence: blocks walking, not the dash.
	await _place_player(Vector2(112, 430))
	await _hold([&"move_down"], 60)
	_say("  walk south into the fence (y 461..467): stops at y=%.1f  %s" % [pl.global_position.y, "PASS" if pl.global_position.y < 456.0 else "FAIL"])
	await _place_player(Vector2(112, 430))
	dashed = pl.dash.try_dash(Vector2.DOWN)
	await _frames(25)
	_say("  dash south across the fence (started %s): ends at y=%.1f  %s" % [dashed, pl.global_position.y, "PASS" if dashed and pl.global_position.y > 470.0 else "FAIL"])
	# Up the ramp and up the stairs: the model height follows with no pop.
	await _walk_heights("ramp: walk east from (48, 368)", Vector2(48, 368), &"move_right", 110, func(p: Vector2) -> bool: return p.x > 165.0)
	await _walk_heights("stairs: walk north from (224, 490)", Vector2(224, 490), &"move_up", 90, func(p: Vector2) -> bool: return p.y < 410.0)
	# Projectiles and line of sight cross a ledge.
	var a := Vector2(220, 290)
	var b := Vector2(220, 380)
	_say("  WorldQuery.shape_sweep across the north ledge: %s  %s" % ["clear" if WorldQuery.shape_sweep(a, b, 2.0).is_empty() else "blocked", "PASS" if WorldQuery.shape_sweep(a, b, 2.0).is_empty() else "FAIL"])
	_say("  WorldQuery.has_line_of_sight across it: %s  %s" % [WorldQuery.has_line_of_sight(a, b), "PASS" if WorldQuery.has_line_of_sight(a, b) else "FAIL"])
	await _place_player(Vector2(220, 296))
	pl.abilities.q = BOLT
	var seen: Array = []   # [projectile, max y]
	var watch := func(n: Node) -> void:
		if n is Projectile:
			seen.append(n)
	get_tree().node_added.connect(watch)
	var cast := pl.abilities.try_cast(&"q", Vector2(220, 560))
	var max_y := 0.0
	for i in 60:
		await get_tree().physics_frame
		for pr in seen:
			if is_instance_valid(pr):
				max_y = maxf(max_y, (pr as Node2D).global_position.y)
	get_tree().node_added.disconnect(watch)
	_say("  the Bolt test ability fired south across the ledge (cast %s, %d projectile): reached y=%.1f (the ledge is at 320)  %s" % [cast, seen.size(), max_y, "PASS" if max_y > 340.0 else "FAIL"])
	# Navigation goes around the cliff.
	var map: RID = pl.get_world_2d().navigation_map
	var path := NavigationServer2D.map_get_path(map, Vector2(220, 296), Vector2(224, 360), true)
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	_say("  a path from below the north cliff to the plateau top: %.0f px (straight: 64 px), via %s  %s" % [length, path, "PASS" if length > 150.0 else "FAIL"])


func _walk_heights(label: String, start: Vector2, action: StringName, frames: int, arrived: Callable) -> void:
	var t = spike.terrain
	var pl: Player = spike.player
	await _place_player(start)
	Input.action_press(action)
	var last_h: float = t.h_model(pl.global_position)
	var worst := 0.0
	var top := 0.0
	for i in frames:
		await get_tree().physics_frame
		var h: float = t.h_model(pl.global_position)
		worst = maxf(worst, absf(h - last_h))
		top = maxf(top, h)
		last_h = h
	Input.action_release(action)
	var ok: bool = arrived.call(pl.global_position)
	_say("  %s: arrives on the plateau %s (at %s), model height up to %.2f m, largest change in one tick %.3f m (smooth if <= 0.06)  %s" % [label, ok, pl.global_position, top, worst, "PASS" if ok and worst <= 0.06 and top >= 1.49 else "FAIL"])


# --- C3 ------------------------------------------------------------------------------

func _place_marker_at(p: Vector3, s: Vector2) -> void:
	var cam: Camera3D = spike.camera
	spike._place_camera(p)
	var o := cam.project_ray_origin(s)
	var d := cam.project_ray_normal(s)
	var t0 := (p - o).length()
	cam.global_position += p - (o + d * t0)


func _c3() -> void:
	_say("\n-- C3: floor pick, marker -> screen -> pick -> sim px (error in sim px)")
	var t = spike.terrain
	var vp := get_viewport().get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0.0:
		win = vp * 2.0
	_say("  viewport %s, window %s" % [vp, win])
	# Off the tile grid by a fraction of a px (a cursor almost never sits on an
	# exact tile corner); the exact-corner case is tested on its own below.
	var off := Vector2(0.37, 0.29)
	var markers := {
		"flat floor (80, 300)": Vector2(80, 300) + off,
		"ramp middle (128, 368)": Vector2(128, 368) + off,
		"stairs, mid-step (224, 446)": Vector2(224, 446) + off,
		"stairs, at a step's edge (224, 437.33)": Vector2(224, 437.333) + off,
		"plateau center (224, 352)": Vector2(224, 352) + off,
		"plateau near its south edge (200, 410)": Vector2(200, 410) + off,
		"floor at the south cliff's base (176, 425)": Vector2(176, 425) + off,
		"floor at the east cliff's base (296, 352)": Vector2(296, 352) + off,
		"floor right behind the north cliff (224, 314)": Vector2(224, 314) + off,
	}
	var targets := {"center": vp * 0.5, "top-left": vp * Vector2(0.1, 0.1), "top-right": vp * Vector2(0.9, 0.1),
		"bottom-left": vp * Vector2(0.1, 0.9), "bottom-right": vp * Vector2(0.9, 0.9)}
	for persp in [true, false]:
		spike.set_perspective(persp)
		_say("  [%s]" % ("perspective, fov 30" if persp else "orthographic"))
		for label: String in markers:
			var sim: Vector2 = markers[label]
			var p: Vector3 = t.to_view(sim, t.h_top(sim.x / 32.0, sim.y / 32.0))
			var worst := {"trimesh": 0.0, "heightmap": 0.0}
			var hidden := false
			var px_per_window_px := 0.0
			for tgt: String in targets:
				var s: Vector2 = targets[tgt]
				_place_marker_at(p, s)
				var back: Vector2 = spike.camera.unproject_position(p)
				if back.distance_to(s) > 0.01:
					_say("    (placement off by %.3f)" % back.distance_to(s))
				for which in ["trimesh", "heightmap"]:
					var mask: int = spike.LAYER_PICK_TRIMESH if which == "trimesh" else spike.LAYER_PICK_HEIGHTMAP
					var hit: Vector3 = spike.floor_pick_3d(s, mask)
					var err := INF if hit == Vector3.INF else (t.to_sim(hit) as Vector2).distance_to(sim)
					worst[which] = maxf(worst[which], err)
					if err > 1.0 and OS.get_cmdline_user_args().has("--p0a-debug"):
						_say("      debug %s %s %s: s=%s cam=%s origin=%s dir=%s marker=%s hit=%s" % [label, tgt, which, s, spike.camera.global_position, spike.camera.project_ray_origin(s), spike.camera.project_ray_normal(s), p, hit])
					if which == "trimesh" and hit != Vector3.INF and hit.distance_to(spike.camera.global_position) < p.distance_to(spike.camera.global_position) - 0.02:
						hidden = true
				# One window pixel, in sim px, at this spot (the cursor's own resolution).
				var step := vp.x / maxf(win.x, 1.0)
				var h1: Vector3 = spike.floor_pick_3d(s + Vector2(step, 0.0), spike.LAYER_PICK_TRIMESH)
				var h2: Vector3 = spike.floor_pick_3d(s + Vector2(0.0, step), spike.LAYER_PICK_TRIMESH)
				var h0: Vector3 = spike.floor_pick_3d(s, spike.LAYER_PICK_TRIMESH)
				if h0 != Vector3.INF and h1 != Vector3.INF and h2 != Vector3.INF:
					px_per_window_px = maxf(px_per_window_px, maxf((t.to_sim(h1) as Vector2).distance_to(t.to_sim(h0)), (t.to_sim(h2) as Vector2).distance_to(t.to_sim(h0))))
			var verdict := "hidden by geometry in front (expected)" if hidden else ("PASS" if worst["trimesh"] < 1.0 else "FAIL")
			_say("    %-46s trimesh max %8.3f px | heightmap max %8.3f px | 1 window px = %.2f sim px  %s" % [label, worst["trimesh"], worst["heightmap"], px_per_window_px, verdict])
		# Exact tile corners (a vertex shared by several triangles): one ray vs two.
		var corners := [Vector2(224, 352), Vector2(224, 448), Vector2(160, 320), Vector2(192, 416)]
		var single_bad := 0
		var double_bad := 0
		var cases := 0
		for sim: Vector2 in corners:
			var p2: Vector3 = t.to_view(sim, t.h_top(sim.x / 32.0 + 0.001, sim.y / 32.0 + 0.001))
			for tgt: String in targets:
				var s2: Vector2 = targets[tgt]
				_place_marker_at(p2, s2)
				cases += 1
				var one: Vector3 = spike.floor_pick_3d(s2, spike.LAYER_PICK_TRIMESH, false)
				var two: Vector3 = spike.floor_pick_3d(s2, spike.LAYER_PICK_TRIMESH, true)
				if one == Vector3.INF or (t.to_sim(one) as Vector2).distance_to(sim) > 1.0:
					single_bad += 1
				if two == Vector3.INF or (t.to_sim(two) as Vector2).distance_to(sim) > 1.0:
					double_bad += 1
		_say("    exact tile corners (%d cases): one ray wrong or missing %d times; two rays (nearer wins) %d times  %s" % [cases, single_bad, double_bad, "PASS" if double_bad == 0 else "FAIL"])
	spike.set_perspective(true)


# --- C4 analytic ---------------------------------------------------------------------

func _c4_analytic() -> void:
	_say("\n-- C4 (analytic): the slam's circle (r 72 px) centered on the ramp (128, 368); drawn edge vs true edge, in window px")
	var t = spike.terrain
	var vp := get_viewport().get_visible_rect().size
	var scale := Vector2(DisplayServer.window_get_size()).x / vp.x
	if scale <= 0.0:
		scale = 2.0
	var c := Vector2(128, 368)
	var r := 72.0
	var hc: float = t.h_top(c.x / 32.0, c.y / 32.0)
	for persp in [true, false]:
		spike.set_perspective(persp)
		spike._place_camera(t.to_view(c, hc))
		var cam: Camera3D = spike.camera
		var quad_err := 0.0
		var quad_hidden := 0
		var mesh_err := 0.0
		var mesh_bad := 0
		var n := 64
		var verts: Array[Vector3] = []
		for i in n:
			var a := TAU * float(i) / float(n)
			var q := c + Vector2(cos(a), sin(a)) * r
			verts.append(t.to_view(q, t.h_top(q.x / 32.0, q.y / 32.0) + 0.02))
		for i in n:
			for k in 8:
				var f := float(k) / 8.0
				var a := TAU * (float(i) + f) / float(n)
				var q := c + Vector2(cos(a), sin(a)) * r
				var truth: Vector3 = t.to_view(q, t.h_top(q.x / 32.0, q.y / 32.0))
				var st := cam.unproject_position(truth)
				var drawn_q: Vector3 = t.to_view(q, hc)
				if truth.y > hc + 0.01:
					quad_hidden += 1
				else:
					quad_err = maxf(quad_err, cam.unproject_position(drawn_q).distance_to(st) * scale)
				var drawn_m: Vector3 = verts[i].lerp(verts[(i + 1) % n], f)
				var st_lift := cam.unproject_position(truth + Vector3(0.0, 0.02, 0.0))   # the ring sits 2 cm up
				var e := cam.unproject_position(drawn_m).distance_to(st_lift) * scale
				mesh_err = maxf(mesh_err, e)
				if e > 1.0:
					mesh_bad += 1
		_say("  [%s] terrain shader: 0 by construction (each surface point samples the overlay at its own x/z; see the rendered check)" % ("perspective" if persp else "orthographic"))
		_say("  [%s] flat quad at the center's height: max %.1f window px where visible; hidden under higher ground at %d of %d samples  %s" % [("perspective" if persp else "orthographic"), quad_err, quad_hidden, n * 8, "PASS" if quad_err <= 1.0 and quad_hidden == 0 else "FAIL"])
		_say("  [%s] mesh following the heights (64 segments): max %.1f window px; %d of %d samples over 1 px (where a segment crosses a cliff)  %s" % [("perspective" if persp else "orthographic"), mesh_err, mesh_bad, n * 8, "PASS" if mesh_err <= 1.0 else "FAIL"])
	spike.set_perspective(true)


# =====================================================================================
# Windowed
# =====================================================================================

func _windowed() -> void:
	_say("=== P0a windowed (Godot %s) ===" % Engine.get_version_info().string)
	_say("  screen refresh %.1f Hz, vsync mode %d, window %s, viewport %s, renderer %s" % [
		DisplayServer.screen_get_refresh_rate(), DisplayServer.window_get_vsync_mode(),
		DisplayServer.window_get_size(), get_viewport().get_visible_rect().size,
		RenderingServer.get_current_rendering_method()])
	_clear_enemies()
	await _frames(5)
	await _c2()
	_c3()   # again, at the real window's 16:9 shape
	await _c4_rendered()
	await _decal_copy_cost()
	await _c5()


## Saves two frames (perspective, orthographic) of the terrain patch with a
## telegraph on the ramp, the Knight on the plateau, to the folder after
## --p0a-screenshot (absolute path).
func _screenshots() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[args.find("--p0a-screenshot") + 1]
	await _place_player(Vector2(250, 360))
	Telegraph.circle(spike.player, Vector2(128, 368), 72.0, 20.0)
	await get_tree().create_timer(1.0).timeout
	for persp in [true, false]:
		spike.set_perspective(persp)
		await get_tree().create_timer(0.5).timeout
		await _draws(2)
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(dir.path_join("p0a_%s.png" % ("perspective" if persp else "orthographic")))
	_say("saved to %s" % dir)


## A Decal refuses a ViewportTexture in 4.7.2 (it says to copy get_image()
## instead). What one copy of the room's overlay per frame would cost.
func _decal_copy_cost() -> void:
	var tex: ViewportTexture = spike.overlay.get_texture()
	await _draws(2)
	var times: Array[float] = []
	for i in 20:
		var t0 := Time.get_ticks_usec()
		var img := tex.get_image()
		var it := ImageTexture.create_from_image(img)
		times.append(float(Time.get_ticks_usec() - t0) / 1000.0)
		await RenderingServer.frame_post_draw
	times.sort()
	_say("\n-- The Decal workaround (copy the overlay with get_image() every frame, %s): median %.2f ms, max %.2f ms per copy, on the CPU" % [spike.overlay.size, _pct(times, 0.5), times[-1]])


func _process(delta: float) -> void:
	if _sampling and spike.views.has(spike.player):
		var cap: Node3D = spike.views[spike.player]
		var p := cap.get_global_transform_interpolated().origin
		_samples.append([Time.get_ticks_usec(), p, spike.camera.unproject_position(p), Engine.time_scale, delta])
	if is_instance_valid(_track):
		_track_samples.append(_track.get_global_transform_interpolated().origin)


# --- C2 ------------------------------------------------------------------------------

func _c2() -> void:
	_say("\n-- C2: smoothness at the screen's refresh rate, vsync on (walk along the long wall, a dash, a 0.06 s hitstop, a teleport)")
	var pl: Player = spike.player
	await _place_player(Vector2(80, 470))
	_samples.clear()
	_sampling = true
	Input.action_press(&"move_right")
	Input.action_press(&"move_down")
	await _frames(70)
	var mark_dash := _samples.size()
	pl.dash.try_dash(Vector2.RIGHT)
	await _frames(40)
	var mark_stop := _samples.size()
	GameFeel.hitstop(0.06)
	await _frames(40)
	Input.action_release(&"move_right")
	Input.action_release(&"move_down")
	_sampling = false
	# Per-frame displacement (xz) vs the frame's own time, outside the dash and the hitstop.
	var ratios: Array[float] = []
	var back := 0
	var dts: Array[float] = []
	var screen_jumps: Array[float] = []
	var speeds: Array[float] = []
	for i in range(1, _samples.size()):
		var dt := float(_samples[i][0] - _samples[i - 1][0]) / 1000000.0
		dts.append(dt)
		var d: Vector3 = _samples[i][1] - _samples[i - 1][1]
		d.y = 0.0
		if i < mark_dash - 1 or (i > mark_dash + 45 and i < mark_stop - 1):
			var edt: float = _samples[i][4]   # the engine's own frame delta (what the interpolation used)
			if edt > 0.0 and i > 15:
				speeds.append(d.length() / edt)
		if d.x < -0.0005:
			back += 1
		screen_jumps.append((_samples[i][2] as Vector2).distance_to(_samples[i - 1][2]))
	speeds.sort()
	var med := speeds[speeds.size() / 2] if not speeds.is_empty() else 0.0
	for s in speeds:
		ratios.append(s / med if med > 0.0 else 0.0)
	ratios.sort()
	dts.sort()
	_say("  frames sampled %d; frame time median %.2f ms, p99 %.2f ms, max %.2f ms" % [_samples.size(), _pct(dts, 0.5) * 1000.0, _pct(dts, 0.99) * 1000.0, dts[-1] * 1000.0])
	_say("  walking speed per frame (steady walking frames, %d): median %.3f m/s (expected 3.75 along the wall at full speed); min %.2fx, max %.2fx of the median  %s" % [speeds.size(), med, ratios[0], ratios[-1], "PASS" if ratios[0] > 0.8 and ratios[-1] < 1.2 else "CHECK"])
	_say("  frames where the model stepped back (west): %d  %s" % [back, "PASS" if back == 0 else "FAIL"])
	# The hitstop: no pop when it ends (no frame moves much more than the median).
	var after: Array[float] = []
	for i in range(mark_stop, mini(mark_stop + 30, _samples.size())):
		var dt2 := float(_samples[i][0] - _samples[i - 1][0]) / 1000000.0
		var d2: Vector3 = _samples[i][1] - _samples[i - 1][1]
		d2.y = 0.0
		after.append(d2.length() / maxf(dt2, 0.0001) / maxf(med, 0.001))
	var after_max := 0.0
	for x in after:
		after_max = maxf(after_max, x)
	_say("  around the hitstop: the fastest frame moved %.2fx the median speed (a pop would be > 1.5x)  %s" % [after_max, "PASS" if after_max < 1.5 else "FAIL"])
	# A teleport: no frame shows the model between the old and the new spot.
	var slime: Unit = SLIME_SCENE.instantiate()
	spike.room.get_node("Entities").add_child(slime)
	slime.global_position = Vector2(700, 300)
	slime.reset_physics_interpolation()
	await _frames(10)
	_track = spike.views.get(slime)
	_track_samples.clear()
	await _draws(3)
	var old := slime.global_position
	slime.global_position = old + Vector2(256, 0)
	slime.reset_physics_interpolation()
	await _draws(12)
	_track = null
	var between := 0
	for p: Vector3 in _track_samples:
		var x := p.x * 32.0
		if x > old.x + 24.0 and x < old.x + 232.0:
			between += 1
	_say("  a slime teleported 256 px: %d of %d frames showed it in between  %s" % [between, _track_samples.size(), "PASS" if between == 0 else "FAIL"])
	slime.queue_free()


func _pct(sorted: Array[float], q: float) -> float:
	if sorted.is_empty():
		return 0.0
	return sorted[clampi(int(q * float(sorted.size() - 1)), 0, sorted.size() - 1)]


# --- C4 rendered -----------------------------------------------------------------------

func _c4_rendered() -> void:
	_say("\n-- C4 (rendered): the slam's circle (r 72 px) on the ramp; the drawn edge found in the frame vs the true edge (window px)")
	var t = spike.terrain
	var c := Vector2(128, 368)
	var r := 72.0
	await _place_player(Vector2(48, 300))
	var tel := Telegraph.circle(spike.player, c, r, 60.0)
	await _frames(2)
	# Is the telegraph in the shared-World2D SubViewport at all?
	await _draws(2)
	var ov: Image = spike.overlay.get_texture().get_image()
	var texel := ov.get_pixelv(Vector2i((c + Vector2(r - 0.5, 0.0)) * float(spike.overlay_scale)))
	var texel_out := ov.get_pixelv(Vector2i((c + Vector2(r + 6.0, 0.0)) * float(spike.overlay_scale)))
	_say("  the SubViewport sharing the sim's World2D draws the telegraph: edge texel %s, outside %s  %s" % [texel, texel_out, "PASS" if texel.a > 0.5 and texel_out.a < 0.05 else "FAIL"])
	var ring := _ring_mesh(t, c, r)
	add_child(ring)
	for persp in [true, false]:
		spike.set_perspective(persp)
		for method in ["terrain shader", "flat quad", "mesh"]:
			spike.set_process(false)   # hold the camera on the circle
			spike._place_camera(t.to_view(c, t.h_top(c.x / 32.0, c.y / 32.0)))
			_show(method, ring)
			await _draws(3)
			var on: Image = get_viewport().get_texture().get_image()
			_show("none", ring)
			await _draws(3)
			var off: Image = get_viewport().get_texture().get_image()
			_report_edge("%s, %s" % [("perspective" if persp else "orthographic"), method], on, off, t, c, r)
	# Does the terrain shader follow the telegraph live (its fill grows)?
	_show("terrain shader", ring)
	await _draws(3)
	var a1: Image = get_viewport().get_texture().get_image()
	await get_tree().create_timer(1.5).timeout
	await _draws(2)
	var a2: Image = get_viewport().get_texture().get_image()
	var changed := _diff_count(a1, a2, spike.camera.unproject_position(t.to_view(c, 0.75)), 40)
	_say("  the terrain shader updates live (the fill grows over 1.5 s): %d changed pixels near the center  %s" % [changed, "PASS" if changed > 20 else "FAIL"])
	spike.set_process(true)
	spike.set_perspective(true)
	spike.set_floor_draw(spike.FloorDraw.SHADER)
	ring.queue_free()
	tel.queue_free()


func _show(method: String, ring: MeshInstance3D) -> void:
	ring.visible = method == "mesh"
	if method == "terrain shader":
		spike.set_floor_draw(spike.FloorDraw.SHADER)
	elif method == "flat quad":
		spike.set_floor_draw(spike.FloorDraw.QUAD)
		spike.overlay_quad.position.y = 0.75 + 0.02   # at the circle center's height
	else:
		spike.set_floor_draw(spike.FloorDraw.NONE)
	if method != "flat quad":
		spike.overlay_quad.position.y = 0.02


func _ring_mesh(t, c: Vector2, r: float) -> MeshInstance3D:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := 64
	for i in n + 1:
		var a := TAU * float(i) / float(n)
		var dir := Vector2(cos(a), sin(a))
		for rr in [r - 0.5, r + 0.5]:   # 1 px wide, centered on the edge
			var q: Vector2 = c + dir * rr
			im.surface_add_vertex(t.to_view(q, t.h_top(q.x / 32.0, q.y / 32.0) + 0.02))
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Telegraph.THREAT_COLOR
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.visible = false
	return mi


func _report_edge(label: String, on: Image, off: Image, t, c: Vector2, r: float) -> void:
	var cam: Camera3D = spike.camera
	var vp := get_viewport().get_visible_rect().size
	var img_scale := Vector2(on.get_size()) / vp
	var found := 0
	var hidden := 0
	var errs: Array[float] = []
	var n := 32
	for i in n:
		var dir := Vector2(cos(TAU * float(i) / float(n)), sin(TAU * float(i) / float(n)))
		# The true edge must be visible (not behind the plateau) to be judged.
		var q_edge := c + dir * r
		var p_edge: Vector3 = t.to_view(q_edge, t.h_top(q_edge.x / 32.0, q_edge.y / 32.0))
		if not _visible(p_edge):
			hidden += 1
			continue
		# The outline's center: the strongest change between "on" and "off"
		# along the radial line, over visible samples only.
		var edge_r := -1.0
		var best := 0.06
		var rr := r - 8.0
		while rr <= r + 8.0:
			var q := c + dir * rr
			var p3: Vector3 = t.to_view(q, t.h_top(q.x / 32.0, q.y / 32.0))
			if _visible(p3):
				var sp := cam.unproject_position(p3) * img_scale
				var ip := Vector2i(sp.round())
				if ip.x >= 0 and ip.y >= 0 and ip.x < on.get_width() and ip.y < on.get_height():
					var a := on.get_pixelv(ip)
					var b := off.get_pixelv(ip)
					var diff := absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
					if diff > best + 0.02:
						best = diff
						edge_r = rr
			rr += 0.25
		if edge_r < 0.0:
			continue
		found += 1
		var q_true := c + dir * r
		var q_found := c + dir * edge_r
		var s_true := cam.unproject_position(t.to_view(q_true, t.h_top(q_true.x / 32.0, q_true.y / 32.0))) * img_scale
		var s_found := cam.unproject_position(t.to_view(q_found, t.h_top(q_found.x / 32.0, q_found.y / 32.0))) * img_scale
		errs.append(s_found.distance_to(s_true))
	errs.sort()
	var visible_rays := n - hidden
	if errs.is_empty():
		_say("  [%s] outline found on 0 of %d visible rays (%d hidden behind the plateau)  FAIL" % [label, visible_rays, hidden])
		return
	var within := 0
	for e in errs:
		if e <= 1.0:
			within += 1
	_say("  [%s] outline found on %d of %d visible rays (%d hidden behind the plateau); its center vs the true edge: median %.2f, max %.2f window px; %d within 1 px  %s" % [
		label, found, visible_rays, hidden, _pct(errs, 0.5), errs[-1], within, "PASS" if found == visible_rays and errs[-1] <= 1.0 else "FAIL"])


## True if nothing stands between the camera and this point (the trimesh pick lands on it).
func _visible(p: Vector3) -> bool:
	var s: Vector2 = spike.camera.unproject_position(p)
	var hit: Vector3 = spike.floor_pick_3d(s, spike.LAYER_PICK_TRIMESH)
	return hit != Vector3.INF and hit.distance_to(p) < 0.05


func _diff_count(a: Image, b: Image, center: Vector2, radius: int) -> int:
	var vp := get_viewport().get_visible_rect().size
	var cs := Vector2i(center * Vector2(a.get_size()) / vp)
	var count := 0
	for y in range(cs.y - radius, cs.y + radius):
		for x in range(cs.x - radius, cs.x + radius):
			if x < 0 or y < 0 or x >= a.get_width() or y >= a.get_height():
				continue
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			if absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) > 0.04:
				count += 1
	return count


# --- C5 ------------------------------------------------------------------------------

func _c5() -> void:
	_say("\n-- C5: frame time with vsync off (target: under 6.9 ms, 144 Hz)")
	var pl: Player = spike.player
	pl.add_invulnerability(&"p0a_stress")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var vp_rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	await _place_player(Vector2(144, 300))
	var floor_cells: Array[Vector2i] = []
	for cell: Vector2i in spike.terrain.kinds:
		if spike.terrain.kind_at(cell) == 0 and (Vector2(cell) * 32.0).distance_to(pl.global_position) > 200.0:
			floor_cells.append(cell)
	var spawned := 0
	for target in [0, 30, 50]:
		while spawned < target:
			var s: Unit = SLIME_SCENE.instantiate()
			spike.room.get_node("Entities").add_child(s)
			var cell: Vector2i = floor_cells[(spawned * 37) % floor_cells.size()]
			s.global_position = Vector2(cell) * 32.0 + Vector2(16, 16)
			s.reset_physics_interpolation()
			spawned += 1
		Input.action_press(&"move_right")
		await get_tree().create_timer(1.5).timeout
		var dts: Array[float] = []
		var gpu: Array[float] = []
		var cpu: Array[float] = []
		var phys: Array[float] = []
		var last := Time.get_ticks_usec()
		var end := last + 4000000
		var flip := 0
		while Time.get_ticks_usec() < end:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			dts.append(float(now - last) / 1000.0)
			last = now
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp_rid))
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp_rid))
			phys.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
			flip += 1
			if flip % 240 == 0:   # walk back and forth so the camera moves
				if Input.is_action_pressed(&"move_right"):
					Input.action_release(&"move_right")
					Input.action_press(&"move_left")
				else:
					Input.action_release(&"move_left")
					Input.action_press(&"move_right")
		Input.action_release(&"move_right")
		Input.action_release(&"move_left")
		dts.sort()
		gpu.sort()
		cpu.sort()
		phys.sort()
		var units := get_tree().get_nodes_in_group("units").size()
		_say("  %2d extra slimes (%d units): frame %d samples, median %.2f ms, p99 %.2f ms, max %.2f ms | GPU p99 %.2f ms | render CPU p99 %.2f ms | physics step p99 %.2f ms  %s" % [
			target, units, dts.size(), _pct(dts, 0.5), _pct(dts, 0.99), dts[-1], _pct(gpu, 0.99), _pct(cpu, 0.99), _pct(phys, 0.99), "PASS" if _pct(dts, 0.99) < 6.9 else "FAIL"])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	pl.remove_invulnerability(&"p0a_stress")
