extends Node2D
## FEEL2 test (EXPERIMENT, the combat advisor's first feel pass): open
## res://scenes/tests/feel_test.tscn and press F6.
## Slice A: the latency probe and the press flash (off changes nothing; the
## segment times are non-negative and in order; the CSV is written; the flash
## shows for exactly one drawn frame). Headless draws no frames, so the test
## calls the probe's frame handler itself where a frame would be drawn.
## Prints PASS/FAIL per check, then a total.
## Run headless and it quits with the number of failures as the exit code.

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


func _key(code: Key, shift: bool = false) -> InputEventKey:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.pressed = true
	k.shift_pressed = shift
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
