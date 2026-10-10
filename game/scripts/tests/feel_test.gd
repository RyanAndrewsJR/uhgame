extends Node2D
## FEEL2 test (EXPERIMENT, the combat advisor's first feel pass): open
## res://scenes/tests/feel_test.tscn and press F6.
## Slice A: the latency probe and the press flash (off changes nothing; the
## segment times are non-negative and in order; the CSV is written; the flash
## shows for exactly one drawn frame). Headless draws no frames, so the test
## calls the probe's frame handler itself where a frame would be drawn.
## Slice B: the blind feel presets (preset 1 is today everywhere; the shake
## held through a hitstop; the directional shake's mean; the hit-taken feel
## only when health is lost; hitstop and the input buffer; the player's turn
## rate apart from enemies'; switching presets restores exactly). It prints
## REPORT lines: the shake left at each hitstop tier's end under presets 1
## and 2, and the model's yaw error at the first swing's hit at turn rates 20
## and 45. Real hitstops run here (60-80 ms each).
## Prints PASS/FAIL per check, then a total.
## Run headless and it quits with the number of failures as the exit code.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const SLIME_SCENE: PackedScene = preload("res://scenes/enemies/slime.tscn")
const LOOK: CameraLook = preload("res://data/camera_looks/camera_look_default.tres")
const SHIELD: StatusEffect = preload("res://data/statuses/status_shield.tres")
## GameFeel's script, for its static functions (the autoload is an instance).
const GAME_FEEL := preload("res://scripts/autoload/game_feel.gd")

## The probe's CSV in this test (deleted at the end; one per process, so two
## runs side by side never share it); never the sandbox's.
var _test_csv := "user://latency_probe_test_%d.csv" % OS.get_process_id()

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	print("\n=== Feel test (FEEL2) ===")
	await get_tree().physics_frame
	await _test_latency_probe()
	await _test_press_flash()
	await _test_sandbox_probe_keys()
	_test_shipped_defaults()
	await _test_shake_after_hitstop()
	await _test_directional_shake()
	await _test_hit_taken_feel()
	await _test_hitstop_and_buffer()
	await _test_turning()
	_test_presets_and_restore()
	print("=== %d passed, %d failed ===\n" % [_passed, _failed])

	if DisplayServer.get_name() == "headless":
		get_tree().quit(_failed)


# --- Slice A: latency ---------------------------------------------------------------

func _test_latency_probe() -> void:
	_section("Slice A: the latency probe")
	_remove_csv()
	var probe := LatencyProbe.new()
	probe.csv_path = _test_csv
	add_child(probe)
	_check("off at the start: the probe, the flash, its line and its square",
		[probe.is_enabled(), probe.is_flash_enabled(), (probe.get_node(^"Line") as CanvasItem).visible, probe.is_flash_visible()],
		[false, false, false, false])
	await _press(&"dash")
	probe._on_frame_post_draw()
	_check("off: a press logs nothing and shows nothing", [probe.records.size(), probe.is_flash_visible()], [0, false])
	_check("off: turning it off again writes no CSV", [probe.set_enabled(false), FileAccess.file_exists(_test_csv)], ["", false])

	probe.set_enabled(true)
	_check("on: its line shows", (probe.get_node(^"Line") as CanvasItem).visible, true)
	var actions: Array[StringName] = [&"dash", &"attack", &"ability_q", &"ability_r"]
	for action in actions:
		await _press(action)
		probe._on_frame_post_draw()
	_check("on: four presses timed, in the order pressed", probe.records.map(func(r: Dictionary) -> StringName: return r["action"]),
		[&"dash", &"attack", &"ability_q", &"ability_r"])
	var ordered := true
	for r in probe.records:
		ordered = ordered and int(r["event"]) >= 0 and int(r["event"]) <= int(r["tick"]) and int(r["tick"]) <= int(r["frame"])
	_check("each press: event <= tick <= frame, none negative", ordered, true)
	var seg := probe.get_segments_ms()
	var non_negative := true
	for key: String in seg:
		for v: float in seg[key]:
			non_negative = non_negative and v >= 0.0
	_check("every segment's time is >= 0 ms", non_negative, true)
	var sums_ok := true
	for i in probe.records.size():
		sums_ok = sums_ok and is_equal_approx(seg["event_to_tick"][i] + seg["tick_to_frame"][i], seg["event_to_frame"][i])
	_check("event>tick + tick>frame = event>frame", sums_ok, true)
	_check("the overlay line names the last press and the count", probe.get_summary_line().begins_with("ability_r") and "n 4" in probe.get_summary_line(), true)
	var s := LatencyProbe.summarize([3.0, 1.0, 2.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0, 20.0])
	_check("summary of 1..20: mean 10.5, p95 19 (nearest rank), max 20", [s["mean"], s["p95"], s["max"]], [10.5, 19.0, 20.0])
	_check("summary of nothing: zeros", LatencyProbe.summarize([]), {"mean": 0.0, "p95": 0.0, "max": 0.0})

	var written := probe.set_enabled(false)
	_check("off: the CSV is written to its path", [written, FileAccess.file_exists(_test_csv)], [_test_csv, true])
	var lines := FileAccess.get_file_as_string(_test_csv).strip_edges().split("\n")
	_check("the CSV: a header and one row per press",
		[lines.size(), lines[0], lines[1].begins_with("dash,") if lines.size() > 1 else false],
		[5, "action,event_usec,tick_usec,frame_usec,event_to_tick_ms,tick_to_frame_ms,event_to_frame_ms", true])
	_check("off: its line hides", (probe.get_node(^"Line") as CanvasItem).visible, false)
	_remove_csv()
	probe.free()


func _test_press_flash() -> void:
	_section("Slice A: the press flash (exactly one drawn frame)")
	var probe := LatencyProbe.new()
	probe.csv_path = _test_csv
	add_child(probe)
	probe.set_flash_enabled(true)
	await _press(&"attack")
	_check("a read press shows the square (top right)",
		[probe.is_flash_visible(), (probe.get_node(^"PressFlash") as Control).position.x + probe.flash_size_px], [true, 640.0])
	probe._on_frame_post_draw()
	_check("the frame drawn after it hides it", probe.is_flash_visible(), false)
	probe._on_frame_post_draw()
	_check("and it stays hidden", probe.is_flash_visible(), false)
	_check("the flash alone logs nothing (the probe is off)", probe.records.size(), 0)
	await _press(&"dash")
	probe.set_flash_enabled(false)
	_check("turned off: hidden at once", probe.is_flash_visible(), false)
	probe.free()


func _test_sandbox_probe_keys() -> void:
	_section("Slice A: SandboxFeel's keys (F9, Shift+F9)")
	var sandbox := SandboxFeel.new()
	add_child(sandbox)
	sandbox.probe.csv_path = _test_csv
	_check("nothing on at the start", [sandbox.probe.is_enabled(), sandbox.probe.is_flash_enabled()], [false, false])
	sandbox._unhandled_input(_key(KEY_F9))
	_check("F9: the probe on", sandbox.probe.is_enabled(), true)
	sandbox._unhandled_input(_key(KEY_F9, true))
	_check("Shift+F9: the press flash on", sandbox.probe.is_flash_enabled(), true)
	await _press(&"dash")
	sandbox.probe._on_frame_post_draw()
	sandbox._unhandled_input(_key(KEY_F9))
	_check("F9 again: off, and its CSV written", [sandbox.probe.is_enabled(), FileAccess.file_exists(_test_csv)], [false, true])
	sandbox._unhandled_input(_key(KEY_F9, true))
	_check("Shift+F9 again: the flash off", sandbox.probe.is_flash_enabled(), false)
	_remove_csv()
	sandbox.free()


# --- Slice B: blind feel presets -----------------------------------------------------

func _test_shipped_defaults() -> void:
	_section("Slice B: shipped config is today")
	var feel := GameFeel.hit_feel
	_check("CameraLook: decay 30, no hold through the hitstop, no direction",
		[LOOK.shake_decay_px, LOOK.shake_after_hitstop, LOOK.shake_directional], [30.0, false, false])
	_check("HitFeel: the tiers unchanged (hitstop 0.03 / 0.06 / 0.08 s, shake 0 / 2 / 3 px), the hit-taken feel off",
		[feel.light_hitstop, feel.heavy_hitstop, feel.kill_hitstop, feel.light_shake, feel.heavy_shake, feel.kill_shake, feel.hit_taken_feel_enabled],
		[0.03, 0.06, 0.08, 0.0, 2.0, 3.0, false])
	_check("UnitView: no player turn rate set (everyone's turn_rate), no swing yaw snap",
		[UnitView.player_turn_rate, UnitView.swing_yaw_snap], [-1.0, false])
	_check("preset 1 (feel_preset_today) holds today's values (player turn 20 = turn_rate)",
		SandboxFeel.PRESETS[0].to_array(), [30.0, false, false, 20.0, false, 0.06, 2.5])
	_check("preset 2: decay 16, after the hitstop, directional, player turn 45, no hit-taken feel",
		SandboxFeel.PRESETS[1].to_array(), [16.0, true, true, 45.0, false, 0.06, 2.5])
	_check("preset 3: preset 2 plus the hit-taken feel (0.06 s, 2.5 px)",
		SandboxFeel.PRESETS[2].to_array(), [16.0, true, true, 45.0, true, 0.06, 2.5])


func _test_shake_after_hitstop() -> void:
	_section("Slice B: the shake held through the hitstop (F1)")
	await _hitstop_over()
	var look_on := LOOK.duplicate() as CameraLook
	look_on.shake_after_hitstop = true
	look_on.shake_decay_px = 16.0
	var cam := _make_camera(look_on)
	cam.shake(2.0)
	GameFeel.hitstop(0.06)
	var zero := true
	for i in 12:
		cam._update_shake(0.005)
		zero = zero and cam.shake_offset_px == Vector2.ZERO
	_check("during the hitstop: no offset at all, and the shake keeps its full 2 px", [zero, cam.get_shake_amount()], [true, 2.0])
	await _hitstop_over()
	var before := cam.get_shake_amount()
	cam._update_shake(0.005)
	_check("when it ends: it starts (an offset) and decays", [cam.shake_offset_px != Vector2.ZERO, cam.get_shake_amount() < before], [true, true])

	# The REPORT numbers: the shake left when each tier's hitstop ends.
	var tiers := [["light", GameFeel.hit_feel.light_hitstop, GameFeel.hit_feel.light_shake],
		["heavy", GameFeel.hit_feel.heavy_hitstop, GameFeel.hit_feel.heavy_shake],
		["kill", GameFeel.hit_feel.kill_hitstop, GameFeel.hit_feel.kill_shake]]
	var left := {}
	for preset_index in [0, 1]:
		var look := LOOK.duplicate() as CameraLook
		SandboxFeel.PRESETS[preset_index].apply(look, GameFeel.hit_feel.duplicate() as HitFeel)
		cam.look = look
		for t: Array in tiers:
			cam.set(&"_shake_amount", 0.0)
			GameFeel.hitstop(t[1])
			cam.shake(t[2])
			for i in 48:
				cam._update_shake(float(t[1]) / 48.0)
			left["%d_%s" % [preset_index + 1, t[0]]] = cam.get_shake_amount()
			await _hitstop_over()
	UnitView.player_turn_rate = -1.0   # apply() set it; put today back
	for t: Array in tiers:
		print("  REPORT  shake left at the end of the %s hitstop (%.2f s, %.1f px): preset 1 %.2f px, preset 2 %.2f px (then gone in %.3f s at 16 px/s)" % [
			t[0], t[1], t[2], left["1_%s" % t[0]], left["2_%s" % t[0]], left["2_%s" % t[0]] / 16.0])
	_check_near("preset 1 (today): a heavy hit's 2 px is 0.2 px when its 0.06 s hitstop ends", left["1_heavy"], 0.2, 0.001)
	_check_near("preset 1: a kill's 3 px is 0.6 px when its 0.08 s hitstop ends", left["1_kill"], 0.6, 0.001)
	_check("preset 2: the full 2 px and 3 px are still there when the hitstop ends", [left["2_heavy"], left["2_kill"]], [2.0, 3.0])
	_check("the light tier shakes 0 px either way", [left["1_light"], left["2_light"]], [0.0, 0.0])
	cam.free()


func _test_directional_shake() -> void:
	_section("Slice B: the directional shake (F1)")
	var look_dir := LOOK.duplicate() as CameraLook
	look_dir.shake_directional = true
	var cam := _make_camera(look_dir)
	_check_near("its mean offset points along the direction: +x, about 0.375 x 2 px", _mean_offset(cam, Vector2(3.0, 0.0)).x, 0.75, 0.05)
	_check_near("and hardly across it", _mean_offset(cam, Vector2(3.0, 0.0)).y, 0.0, 0.05)
	var diag := Vector2(1.0, 1.0).normalized()
	var m := _mean_offset(cam, diag)
	_check_near("a diagonal one: along it", m.dot(diag), 0.75, 0.05)
	_check_near("a diagonal one: not across it", m.dot(Vector2(-diag.y, diag.x)), 0.0, 0.05)
	_check_near("no direction (the one-argument call): no lean (x)", _mean_offset(cam, Vector2.ZERO).x, 0.0, 0.07)
	look_dir.shake_directional = false
	_check_near("the flag off (today): a direction changes nothing (x)", _mean_offset(cam, Vector2.RIGHT).x, 0.0, 0.07)
	cam.set(&"_shake_amount", 0.0)
	cam.shake(1.0, Vector2.RIGHT)
	cam.shake(2.0)
	var a: Vector2 = cam.get(&"_shake_dir")
	cam.shake(2.0, Vector2.UP)
	var b: Vector2 = cam.get(&"_shake_dir")
	cam.shake(1.0, Vector2.LEFT)
	_check("the strongest shake wins with its direction (a stronger plain one clears it; a weaker one changes nothing)",
		[a, b, cam.get(&"_shake_dir"), cam.get_shake_amount()], [Vector2.ZERO, Vector2.UP, Vector2.UP, 2.0])

	var spy_script := GDScript.new()
	spy_script.source_code = "extends Camera3D\nvar got: Array = []\nfunc shake(amount: float) -> void:\n\tgot.append(amount)\n"
	spy_script.reload()
	var spy := Camera3D.new()
	spy.set_script(spy_script)
	add_child(spy)
	spy.make_current()
	GameFeel.shake(1.5, Vector2.RIGHT)
	GameFeel.shake(2.0)
	_check("GameFeel.shake(): a camera whose shake() takes one argument still gets both calls", spy.get(&"got"), [1.5, 2.0])
	spy.free()
	cam.make_current()

	await _hitstop_over()
	var target := Node2D.new()
	add_child(target)
	target.global_position = Vector2(200.0, 100.0)
	var ctx := HitContext.new()
	ctx.target = target
	ctx.knockback_from = Vector2(100.0, 100.0)
	ctx.feel = HitContext.Feel.HEAVY
	cam.set(&"_shake_amount", 0.0)
	GameFeel.play_hit_feel(ctx)
	_check("a heavy hit's shake carries its direction (from where it pushes from to its target)",
		[cam.get_shake_amount(), cam.get(&"_shake_dir")], [2.0, Vector2.RIGHT])
	await _hitstop_over()
	var none := HitContext.new()
	_check("a hit with no target has no direction", GAME_FEEL.get_hit_direction(none), Vector2.ZERO)
	target.free()
	cam.free()


func _test_hit_taken_feel() -> void:
	_section("Slice B: the hit-taken feel (F3)")
	_knight = PLAYER_SCENE.instantiate() as Player
	$Entities.add_child(_knight)
	_place(_knight, Vector2(300.0, 200.0))
	_slime = SLIME_SCENE.instantiate() as Enemy
	_slime.passive = true
	$Entities.add_child(_slime)
	_place(_slime, Vector2(200.0, 200.0))
	await get_tree().physics_frame
	_check("the Knight is the tracked player", Progress.get_tracked_player() == _knight, true)
	var cam := _make_camera(LOOK)
	var feel := GameFeel.hit_feel
	var was := [feel.hit_taken_feel_enabled, feel.taken_hitstop, feel.taken_shake]

	var r := await _hit_knight(cam)
	_check("off (today): a hit that takes health: no hitstop, the player's own 2 px shake",
		[r["lost"] > 0.0, r["hitstop"], r["shake"]], [true, false, 2.0])
	feel.hit_taken_feel_enabled = true
	r = await _hit_knight(cam)
	_check("on: health lost: a hitstop and a 2.5 px shake pointing away from the attacker",
		[r["lost"] > 0.0, r["hitstop"], r["shake"], r["dir"]], [true, true, 2.5, Vector2.RIGHT])
	_knight.add_invulnerability(&"dash")
	r = await _hit_knight(cam)
	_knight.remove_invulnerability(&"dash")
	_check("dash i-frames: blocked: no hit-taken feel, no shake", [r["blocked"], r["hitstop"], r["shake"]], [true, false, 0.0])
	_knight.add_invulnerability(Unit.HIT_IFRAMES_ID)
	r = await _hit_knight(cam, false)
	_knight.remove_invulnerability(Unit.HIT_IFRAMES_ID)
	_check("post-hit i-frames: blocked: none either", [r["blocked"], r["hitstop"]], [true, false])
	_knight.status_component.apply_status(SHIELD, _knight)
	r = await _hit_knight(cam)
	_knight.status_component.remove_status(&"shield")
	_check("a shield that absorbs it all: no health lost, no hit-taken feel (the player's 2 px shake only)",
		[r["lost"], r["hitstop"], r["shake"]], [0.0, false, 2.0])
	var ctx := _knight.make_hit_context(10.0, _slime)
	ctx.target = _knight
	ctx.health_lost = 10.0
	_check("is_hit_taken: a plain hit that took health counts", GAME_FEEL.is_hit_taken(ctx), true)
	ctx.deflected = true
	_check("a deflected one never counts", GAME_FEEL.is_hit_taken(ctx), false)
	ctx.deflected = false
	ctx.add_tag(&"dot")
	_check("a DoT tick doesn't", GAME_FEEL.is_hit_taken(ctx), false)
	var on_slime := _slime.make_hit_context(10.0, _knight)
	on_slime.target = _slime
	on_slime.health_lost = 10.0
	_check("a hit on an enemy doesn't", GAME_FEEL.is_hit_taken(on_slime), false)
	await _hitstop_over()
	_slime.on_hit(_slime.make_hit_context(5.0, _knight))
	_check("an enemy losing health plays no hit-taken hitstop", GameFeel.is_hitstop_active(), false)
	_slime.health.heal(1000.0)
	feel.hit_taken_feel_enabled = was[0]
	feel.taken_hitstop = was[1]
	feel.taken_shake = was[2]
	cam.free()


func _test_hitstop_and_buffer() -> void:
	_section("Slice B: hitstop and the input buffer (F3)")
	await _hitstop_over()
	var input := _knight.player_input
	_knight.abilities.start_cooldown(&"q")   # Q can't cast: its press waits in the buffer
	input.buffer_action(&"q")
	var start_left: float = input.get(&"_buffer_left")
	var last_left := start_left
	var ticks := 0
	var real_start := Time.get_ticks_usec()
	GameFeel.hitstop(0.08)
	while GameFeel.is_hitstop_active():
		await get_tree().physics_frame
		if GameFeel.is_hitstop_active():
			last_left = input.get(&"_buffer_left")
			ticks += 1
	var used := start_left - last_left
	print("  REPORT  a 0.08 s hitstop (%.1f ms real, %d physics ticks inside it) used %.4f s of the 0.15 s buffer" % [
		(Time.get_ticks_usec() - real_start) / 1000.0, ticks, used])
	# Game time: each tick inside the freeze counts 1/60 x 0.05 s. A real-time
	# timer would have used the whole 0.08 s.
	_check("the buffered press survives a 0.08 s hitstop, which uses only its ticks' game time (< 0.02 s of the 0.15 s)",
		[input.get_buffered_action(), used >= 0.0 and used < 0.02, used <= ticks / 60.0 * GameFeel.hitstop_time_scale + 0.002],
		[&"q", true, true])
	input.clear_buffer()
	await get_tree().physics_frame
	GameFeel.hitstop(0.08)
	input.buffer_action(&"dash")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("controls aren't locked: a dash pressed inside a hitstop fires on the next tick, still inside it",
		[_knight.dash.is_dashing() or _knight.dash.get_charges() < _knight.dash.get_max_charges(), GameFeel.is_hitstop_active()], [true, true])
	await _hitstop_over()


func _test_turning() -> void:
	_section("Slice B: the player's turn rate (F2)")
	_place(_slime, Vector2(300.0, 700.0))   # out of the swings' reach: no hit, no hitstop
	var view := WorldView.new()
	add_child(view)
	var target := Node3D.new()
	view.add_child(target)
	var cam := GameCamera3D.new()
	cam.target = target
	view.add_child(cam)
	cam.make_current()
	view.camera = cam
	view.watch_sim()
	var kv := view.view_of(_knight) as UnitView
	var sv := view.view_of(_slime) as UnitView
	_check("both units have a view", [kv != null, sv != null], [true, true])
	if kv == null or sv == null:
		view.free()
		return
	_check("today: both turn at 20", [kv.get_turn_rate(), sv.get_turn_rate()], [20.0, 20.0])
	UnitView.player_turn_rate = 45.0
	_check("a player turn rate of 45: the tracked player's model only; the slime keeps 20", [kv.get_turn_rate(), sv.get_turn_rate()], [45.0, 20.0])
	UnitView.player_turn_rate = -1.0
	_check("back to none: 20 again", kv.get_turn_rate(), 20.0)

	var swing := _knight.attack.combo.swings[0]
	var hit_time := swing.windup / maxf(_knight.attack.get_swing_speed(), 0.001)
	for rate: float in [20.0, 45.0]:
		for angle: float in [90.0, 180.0]:
			UnitView.player_turn_rate = rate
			var measured: Array = await _yaw_error_at_first_hit(kv, angle)
			var err: float = measured[0]
			var ticks: int = measured[1]
			var per_tick := angle * exp(-rate * ticks / 60.0)
			var continuous := angle * exp(-rate * hit_time)
			print("  REPORT  turn rate %d, a %d° turn: the model is %.1f° off the swing at its hit tick (%d view ticks; the hit %.3f s in; %.0f%% of the turn done; the advisor's continuous formula: %.1f°, %.0f%%)" % [
				rate, angle, err, ticks, hit_time, 100.0 * (1.0 - err / angle), continuous, 100.0 * (1.0 - continuous / angle)])
			_check_near("turn rate %d, %d°: the error is angle x e^(-rate x ticks / 60)" % [rate, angle], err, per_tick, 0.5)
	UnitView.player_turn_rate = -1.0

	UnitView.swing_yaw_snap = true
	_knight.facing = Vector2.RIGHT
	for i in 40:
		await get_tree().physics_frame
	await _wait_swing_ready()
	_knight.attack.try_swing(Vector2.DOWN, false)
	_check_near("swing yaw snap: the model faces the swing at once", rad_to_deg(absf(angle_difference(kv.get_yaw(), atan2(0.0, 1.0)))), 0.0, 0.01)
	UnitView.swing_yaw_snap = false
	_check("the slime's model never snapped or changed rate", sv.get_turn_rate(), 20.0)
	_knight.attack.cancel_swing()
	await _wait_swing_ready()
	view.free()


func _test_presets_and_restore() -> void:
	_section("Slice B: switching presets back and forth restores exactly")
	var look := LOOK.duplicate() as CameraLook
	var feel := GameFeel.hit_feel.duplicate() as HitFeel
	var start := FeelPreset.capture(look, feel).to_array()
	SandboxFeel.PRESETS[1].apply(look, feel)
	SandboxFeel.PRESETS[2].apply(look, feel)
	SandboxFeel.PRESETS[0].apply(look, feel)
	_check("2, then 3, then 1: today's values (the player's turn 20 = turn_rate)",
		FeelPreset.capture(look, feel).to_array(), [30.0, false, false, 20.0, false, 0.06, 2.5])
	_check("the tier values never move", [feel.heavy_hitstop, feel.kill_hitstop, feel.heavy_shake, feel.kill_shake], [0.06, 0.08, 2.0, 3.0])
	UnitView.player_turn_rate = -1.0

	var sandbox := SandboxFeel.new()
	sandbox.look = look
	sandbox.feel = feel
	add_child(sandbox)
	var label := sandbox.find_child("FeelLabel", true, false) as Label
	_check("before F10: nothing shown, today's values", [sandbox.get_shown_number(), label.visible, FeelPreset.capture(look, feel).to_array()],
		[0, false, start])
	var shown := []
	var truth := []
	for i in 3:
		sandbox._unhandled_input(_key(KEY_F10))
		shown.append(sandbox.get_shown_number())
		truth.append(sandbox.get_active_preset_number())
	var truth_sorted := truth.duplicate()
	truth_sorted.sort()
	_check("F10 three times: shown 1, 2, 3; behind them each preset once", [shown, truth_sorted], [[1, 2, 3], [1, 2, 3]])
	_check("the screen shows only the number", [label.text, label.visible], ["feel 3", true])
	_check("Shift+F10's mapping names today", "preset 1 (today)" in sandbox.print_mapping(), true)
	sandbox._unhandled_input(_key(KEY_F10, false, true))
	_check("Ctrl+F10: the swing yaw snap on", UnitView.swing_yaw_snap, true)
	sandbox.free()
	_check("leaving the sandbox puts every value back exactly (the player turn rate unset, no snap)",
		[FeelPreset.capture(look, feel).to_array(), UnitView.player_turn_rate, UnitView.swing_yaw_snap], [start, -1.0, false])
	var orders := {}
	for i in 12:
		var s := SandboxFeel.new()
		add_child(s)
		orders[str(s.shown_order)] = true
		s.free()
	_check("the shown order is shuffled per session (12 sessions, more than one order)", orders.size() > 1, true)


# --- Slice B helpers ------------------------------------------------------------------

var _knight: Player
var _slime: Enemy


func _make_camera(look: CameraLook) -> GameCamera3D:
	var cam := GameCamera3D.new()
	cam.look = look
	add_child(cam)
	cam.make_current()
	return cam


## The mean shake offset over 4000 frames of a fresh 2 px shake with `dir`.
func _mean_offset(cam: GameCamera3D, dir: Vector2) -> Vector2:
	var sum := Vector2.ZERO
	for i in 4000:
		cam.set(&"_shake_amount", 0.0)
		cam.shake(2.0, dir)
		cam._update_shake(0.0)
		sum += cam.shake_offset_px
	return sum / 4000.0


## Hits the Knight for 10 from the slime (no hitstop running first); what the
## feel did, read at once: {hitstop, shake, dir, lost, blocked}.
func _hit_knight(cam: GameCamera3D, clear_iframes: bool = true) -> Dictionary:
	await _hitstop_over()
	if clear_iframes:
		_knight.remove_invulnerability(Unit.HIT_IFRAMES_ID)
	cam.set(&"_shake_amount", 0.0)
	cam.set(&"_shake_dir", Vector2.ZERO)
	var ctx := _knight.make_hit_context(10.0, _slime)
	_knight.on_hit(ctx)
	var out := {"hitstop": GameFeel.is_hitstop_active(), "shake": cam.get_shake_amount(), "dir": cam.get(&"_shake_dir"),
		"lost": ctx.health_lost, "blocked": ctx.blocked}
	await _hitstop_over()
	_knight.health.heal(10000.0)
	return out


## [the model's yaw error (degrees) at the first swing's hit, the view ticks
## from the swing's start through its hit], the swing `angle_deg` from where
## the Knight faced. Measured on the physics tick (the drawn frames
## interpolate between the last two ticks).
func _yaw_error_at_first_hit(kv: UnitView, angle_deg: float) -> Array:
	await _wait_swing_ready()
	_knight.facing = Vector2.RIGHT
	for i in 40:
		await get_tree().physics_frame
	var dir := Vector2.RIGHT.rotated(deg_to_rad(angle_deg))
	var landed := [false]
	var on_landed := func(_i: int, _t: Array[Unit]) -> void: landed[0] = true
	_knight.attack.swing_landed.connect(on_landed)
	_knight.attack.try_swing(dir, false)
	var guard := 0
	while not landed[0] and guard < 60:
		await get_tree().physics_frame
		guard += 1
	_knight.attack.swing_landed.disconnect(on_landed)
	var err := rad_to_deg(absf(angle_difference(kv.get_yaw(), atan2(dir.x, dir.y))))
	_knight.attack.cancel_swing()
	return [err, guard]


func _wait_swing_ready() -> void:
	var guard := 0
	while (not _knight.attack.can_swing() or _knight.attack.get_combo_index() != 0) and guard < 240:
		await get_tree().physics_frame
		guard += 1


func _hitstop_over() -> void:
	while GameFeel.is_hitstop_active():
		await get_tree().process_frame


func _place(node: Node2D, pos: Vector2) -> void:
	node.global_position = pos
	node.reset_physics_interpolation()


# --- Helpers ------------------------------------------------------------------------

## Presses `action` through Input (as a real press arrives) and waits until a
## physics tick has read it, then releases it.
func _press(action: StringName) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func _key(code: Key, shift: bool = false, ctrl: bool = false) -> InputEventKey:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.pressed = true
	k.shift_pressed = shift
	k.ctrl_pressed = ctrl
	return k


func _remove_csv() -> void:
	if FileAccess.file_exists(_test_csv):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_test_csv))


func _section(title: String) -> void:
	print("-- %s" % title)


func _check(label: String, actual: Variant, expected: Variant) -> void:
	var ok: bool
	if actual is float or expected is float:
		ok = is_equal_approx(float(actual), float(expected))
	else:
		ok = actual == expected
	_report(ok, label, "got %s, expected %s" % [actual, expected])


func _check_near(label: String, actual: float, expected: float, tolerance: float) -> void:
	_report(absf(actual - expected) <= tolerance, label, "got %s, expected %s ± %s" % [actual, expected, tolerance])


func _report(ok: bool, label: String, detail: String) -> void:
	if ok:
		_passed += 1
		print("  PASS  %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s: %s" % [label, detail])
