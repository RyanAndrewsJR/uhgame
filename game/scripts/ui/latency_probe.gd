class_name LatencyProbe
extends CanvasLayer
## EXPERIMENT (FEEL2, Slice A; Ryan with his combat advisor, 2026-10-09): a
## press-to-screen latency probe. Instrument only: it reads input and time,
## never changes state, and does nothing while both of its switches are off
## (the default). SandboxFeel turns it on (F9) and the press flash (Shift+F9).
##
## For each press of an action PlayerInput or the Player reads (dash, attack,
## Q/W/E/R) it logs, in microseconds (Time.get_ticks_usec()):
##   event - the input event reached the scene tree (_input). Godot hands
##           events over once per frame, before the physics ticks.
##   tick  - the physics tick that read it: the first tick where
##           Input.is_action_just_pressed() is true, read just after
##           PlayerInput's own read (process_physics_priority -9 vs its -10).
##   frame - the end of the first frame drawn after that tick
##           (RenderingServer.frame_post_draw: the CPU side has submitted it).
## It can't see: the mouse or keyboard hardware and USB polling, the OS's
## input queue before Godot reads it, the GPU finishing the frame, the
## swapchain / compositor / V-Sync wait and the display's scan-out and pixel
## response. The press flash and a 240 fps film cover those.
##
## Overlay: one line with the last press and each segment's running mean /
## p95 / max (ms). Turning the probe off writes every press to csv_path.
## Press flash: a bright square in the top-right corner for exactly one
## drawn frame after a press is read (it shows in the frame drawn after that
## tick and hides when that frame is done).

## The actions it times (the input map's names).
const ACTIONS: Array[StringName] = [&"dash", &"attack", &"ability_q", &"ability_w", &"ability_e", &"ability_r"]
## Over the HUD (1), the pause menu (10) and the camera's debug (90).
const LAYER := 95
## A press nothing reads within this long (s, real time) is dropped.
const PENDING_TIMEOUT_USEC := 500000

## Where turning the probe off writes its presses (CSV).
@export var csv_path: String = "user://latency_probe.csv"
## The press flash's square (canvas px) and color.
@export var flash_size_px: float = 28.0
@export var flash_color: Color = Color(1, 1, 1, 1)

## Every finished press: {action, event, tick, frame} (µs).
var records: Array[Dictionary] = []

var _enabled := false
var _flash_enabled := false
var _pending: Array[Dictionary] = []   # pressed, not read by a tick yet
var _awaiting: Array[Dictionary] = []  # read by a tick, not drawn yet
var _flash_armed := false              # shown at a tick; hidden after the next drawn frame
var _line: Label
var _flash: ColorRect


func _init() -> void:
	name = "LatencyProbe"
	layer = LAYER
	process_physics_priority = -9   # right after PlayerInput (-10) reads this tick's presses


func _ready() -> void:
	_line = Label.new()
	_line.name = "Line"
	_line.add_theme_font_size_override(&"font_size", 8)
	_line.add_theme_color_override(&"font_color", Color(0.95, 0.95, 0.95))
	_line.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 1))
	_line.add_theme_constant_override(&"outline_size", 3)
	_line.position = Vector2(4.0, 348.0)
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line.visible = false
	add_child(_line)
	_flash = ColorRect.new()
	_flash.name = "PressFlash"
	_flash.color = flash_color
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.size = Vector2(flash_size_px, flash_size_px)
	_flash.position = Vector2(640.0 - flash_size_px, 0.0)
	_flash.visible = false
	add_child(_flash)
	RenderingServer.frame_post_draw.connect(_on_frame_post_draw)


func _exit_tree() -> void:
	if RenderingServer.frame_post_draw.is_connected(_on_frame_post_draw):
		RenderingServer.frame_post_draw.disconnect(_on_frame_post_draw)


# --- Switches ---------------------------------------------------------------------

func is_enabled() -> bool:
	return _enabled


func is_flash_enabled() -> bool:
	return _flash_enabled


## On: starts a fresh log. Off: writes the log to csv_path (when it has any
## press) and returns the path written ("" if none).
func set_enabled(on: bool) -> String:
	if on == _enabled:
		return ""
	_enabled = on
	_line.visible = on
	var written := ""
	if on:
		records.clear()
		_line.text = "latency probe on: press dash, attack or Q/W/E/R"
	else:
		written = write_csv()
	_clear_if_idle()
	return written


func set_flash_enabled(on: bool) -> void:
	_flash_enabled = on
	if not on:
		_flash.visible = false
		_flash_armed = false
	_clear_if_idle()


func is_flash_visible() -> bool:
	return _flash.visible


# --- Timing -----------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not (_enabled or _flash_enabled) or event.is_echo():
		return
	for action: StringName in ACTIONS:
		if event.is_action_pressed(action):
			_pending.append({"action": action, "event": Time.get_ticks_usec()})


func _physics_process(_delta: float) -> void:
	if _pending.is_empty():
		return
	var now := Time.get_ticks_usec()
	for i in range(_pending.size() - 1, -1, -1):
		var p: Dictionary = _pending[i]
		if Input.is_action_just_pressed(p["action"]):
			p["tick"] = now
			_awaiting.append(p)
			_pending.remove_at(i)
			if _flash_enabled:
				_flash.visible = true
				_flash_armed = true
		elif now - int(p["event"]) > PENDING_TIMEOUT_USEC:
			_pending.remove_at(i)


## The drawn frame after a tick that read presses: their frame time, and the
## press flash goes (it was in this one frame). Connected to
## RenderingServer.frame_post_draw; tests call it directly (headless draws no
## frames).
func _on_frame_post_draw() -> void:
	if _flash_armed:
		_flash_armed = false
		_flash.visible = false
	if _awaiting.is_empty():
		return
	var now := Time.get_ticks_usec()
	for p in _awaiting:
		p["frame"] = now
		if _enabled:
			records.append(p)
	_awaiting.clear()
	if _enabled:
		_line.text = get_summary_line()


func _clear_if_idle() -> void:
	if not _enabled and not _flash_enabled:
		_pending.clear()
		_awaiting.clear()


# --- Readout ------------------------------------------------------------------------

## Each segment's times (ms) over every finished press:
## {"event_to_tick": [...], "tick_to_frame": [...], "event_to_frame": [...]}.
func get_segments_ms() -> Dictionary:
	var out := {"event_to_tick": [], "tick_to_frame": [], "event_to_frame": []}
	for r in records:
		out["event_to_tick"].append((int(r["tick"]) - int(r["event"])) / 1000.0)
		out["tick_to_frame"].append((int(r["frame"]) - int(r["tick"])) / 1000.0)
		out["event_to_frame"].append((int(r["frame"]) - int(r["event"])) / 1000.0)
	return out


## {mean, p95, max} of a list of numbers (0s when empty). p95: the nearest
## rank.
static func summarize(values: Array) -> Dictionary:
	if values.is_empty():
		return {"mean": 0.0, "p95": 0.0, "max": 0.0}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for v: float in sorted:
		total += v
	var rank := clampi(ceili(0.95 * sorted.size()) - 1, 0, sorted.size() - 1)
	return {"mean": total / sorted.size(), "p95": float(sorted[rank]), "max": float(sorted[-1])}


func get_summary_line() -> String:
	if records.is_empty():
		return "latency probe on: no press yet"
	var last: Dictionary = records[-1]
	var seg := get_segments_ms()
	var parts := PackedStringArray()
	for key: String in ["event_to_tick", "tick_to_frame", "event_to_frame"]:
		var s := summarize(seg[key])
		parts.append("%s %.1f/%.1f/%.1f" % [key.replace("_to_", ">"), s["mean"], s["p95"], s["max"]])
	return "%s %.1f+%.1f ms | n %d mean/p95/max ms: %s" % [String(last["action"]),
		(int(last["tick"]) - int(last["event"])) / 1000.0, (int(last["frame"]) - int(last["tick"])) / 1000.0,
		records.size(), "  ".join(parts)]


## Writes every finished press to csv_path; returns the path ("" when there
## is nothing to write or it can't open the file).
func write_csv() -> String:
	if records.is_empty():
		return ""
	var f := FileAccess.open(csv_path, FileAccess.WRITE)
	if f == null:
		push_warning("LatencyProbe: can't write %s" % csv_path)
		return ""
	f.store_line("action,event_usec,tick_usec,frame_usec,event_to_tick_ms,tick_to_frame_ms,event_to_frame_ms")
	for r in records:
		var e := int(r["event"])
		var t := int(r["tick"])
		var fr := int(r["frame"])
		f.store_line("%s,%d,%d,%d,%.3f,%.3f,%.3f" % [r["action"], e, t, fr, (t - e) / 1000.0, (fr - t) / 1000.0, (fr - e) / 1000.0])
	f.close()
	print("LatencyProbe: %d presses written to %s (%s)" % [records.size(), csv_path, ProjectSettings.globalize_path(csv_path)])
	return csv_path
