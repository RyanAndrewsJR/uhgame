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
## It never touches the player's saves, and does nothing in a test scene
## unless a test calls it.

var probe: LatencyProbe


func _ready() -> void:
	probe = LatencyProbe.new()
	add_child(probe)
	if Progress.is_test_scene():
		return
	print("SandboxFeel: F9 latency probe, Shift+F9 press flash")


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
