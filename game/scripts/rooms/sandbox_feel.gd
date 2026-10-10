class_name SandboxFeel
extends Node
## Sandbox only. EXPERIMENT (FEEL2; Ryan with his combat advisor, 2026-10-09):
## the combat feel pass's tools. Everything here is presentation or
## measurement; nothing changes a gameplay number, and every switch starts
## off. Raw keys, read here (no input action, like SandboxDeflect's):
##   F9        the latency probe (LatencyProbe) on/off; off writes its CSV
##             (user://latency_probe.csv)
##   Shift+F9  the press flash on/off (a white square, top right, for one
##             drawn frame after each press is read: film it at 240 fps)
##   F10       the next feel preset, blind: the screen shows only "feel 1",
##             "feel 2" or "feel 3", shuffled each session (FeelPreset; the
##             files in res://data/feel_presets/). Before the first F10 it's
##             today's feel and shows nothing.
##   Shift+F10 prints which shown number is which preset (the console only)
##   Ctrl+F10  the swing yaw snap on/off (UnitView.swing_yaw_snap; in no preset)
## Leaving the sandbox puts every value back as it found it. It never
## touches the player's saves, and does nothing in a test scene unless a
## test calls it.

## The presets in their true order: 1 = today, exactly.
const PRESETS: Array[FeelPreset] = [
	preload("res://data/feel_presets/feel_preset_today.tres"),
	preload("res://data/feel_presets/feel_preset_shake_turn.tres"),
	preload("res://data/feel_presets/feel_preset_hit_taken.tres"),
]

var probe: LatencyProbe
## The look and feel the presets write into (the shared files in memory).
var look: CameraLook = preload("res://data/camera_looks/camera_look_default.tres")
var feel: HitFeel = GameFeel.hit_feel

## shown_order[i] = the preset index shown as "feel i+1" (shuffled per session).
var shown_order: Array[int] = [0, 1, 2]

var _shown := -1   # the shown number's index now; -1 = none (today, untouched)
var _found: FeelPreset   # the values as found, put back on exit
var _found_snap := false
var _label_layer: CanvasLayer
var _label: Label


func _ready() -> void:
	probe = LatencyProbe.new()
	add_child(probe)
	_found = FeelPreset.capture(look, feel)
	_found_snap = UnitView.swing_yaw_snap
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(shown_order.size() - 1, 0, -1):   # Fisher-Yates
		var j := rng.randi_range(0, i)
		var t := shown_order[i]
		shown_order[i] = shown_order[j]
		shown_order[j] = t
	_label_layer = CanvasLayer.new()
	_label_layer.layer = LatencyProbe.LAYER
	add_child(_label_layer)
	_label = Label.new()
	_label.name = "FeelLabel"
	_label.add_theme_font_size_override(&"font_size", 8)
	_label.add_theme_color_override(&"font_color", Color(0.95, 0.95, 0.95))
	_label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 1))
	_label.add_theme_constant_override(&"outline_size", 3)
	_label.position = Vector2(596.0, 30.0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = false
	_label_layer.add_child(_label)
	if Progress.is_test_scene():
		return
	print("SandboxFeel: F9 latency probe, Shift+F9 press flash, F10 next feel preset (blind), Shift+F10 print the mapping, Ctrl+F10 swing yaw snap")


func _exit_tree() -> void:
	restore_found()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_F9:
			if key.shift_pressed:
				set_press_flash(not probe.is_flash_enabled())
			else:
				set_probe(not probe.is_enabled())
		KEY_F10:
			if key.ctrl_pressed:
				set_swing_yaw_snap(not UnitView.swing_yaw_snap)
			elif key.shift_pressed:
				print_mapping()
			else:
				next_preset()
		_:
			return
	get_viewport().set_input_as_handled()


# --- Slice A: latency ---------------------------------------------------------------

## The latency probe on or off. Off writes its CSV (the path, or "").
func set_probe(on: bool) -> String:
	var written := probe.set_enabled(on)
	print("SandboxFeel: latency probe %s%s" % ["ON" if on else "off", (" (wrote %s)" % written) if written != "" else ""])
	return written


func set_press_flash(on: bool) -> void:
	probe.set_flash_enabled(on)
	print("SandboxFeel: press flash %s" % ("ON" if on else "off"))


# --- Slice B: blind feel presets ------------------------------------------------------

## Applies the next shown number's preset (1, 2, 3, 1...); returns the shown
## number (1-3).
func next_preset() -> int:
	_shown = (_shown + 1) % shown_order.size()
	PRESETS[shown_order[_shown]].apply(look, feel)
	_label.text = "feel %d" % (_shown + 1)
	_label.visible = true
	return _shown + 1


## The shown number now (1-3), or 0 before the first F10.
func get_shown_number() -> int:
	return _shown + 1


## The true preset (1 = today) behind the shown number now, or 0.
func get_active_preset_number() -> int:
	return shown_order[_shown] + 1 if _shown >= 0 else 0


## Prints the mapping to the console (never on screen) and returns it.
func print_mapping() -> String:
	var parts := PackedStringArray()
	for i in shown_order.size():
		var p := PRESETS[shown_order[i]]
		parts.append("feel %d = preset %d (%s)" % [i + 1, shown_order[i] + 1, p.display_name])
	var text := "SandboxFeel mapping: " + "; ".join(parts)
	print(text)
	return text


func set_swing_yaw_snap(on: bool) -> void:
	UnitView.swing_yaw_snap = on
	print("SandboxFeel: swing yaw snap %s" % ("ON" if on else "off"))


## Puts back every value as the sandbox found it (on exit).
func restore_found() -> void:
	if _found != null:
		_found.apply(look, feel)
	UnitView.swing_yaw_snap = _found_snap
	_shown = -1
	if _label != null:
		_label.visible = false
