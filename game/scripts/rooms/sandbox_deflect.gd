class_name SandboxDeflect
extends Node
## Sandbox only. PROTOTYPE (Ryan, 2026-10-07): the dash-deflect, riposte and
## enemy poise prototype, tested on the Knight. Its flags are off in shipped
## config; this node turns them on while the sandbox runs (never in a test
## scene) and puts back what it found when it leaves. Raw keys, read here (no
## input action, like SandboxBrains'):
##   V        the deflect flag (DeflectComponent.deflect_test_enabled) on/off
##   Shift+V  the poise flag (PoiseComponent.poise_test_enabled) on/off
## The TEMP weak-auto lever (AutoAttackComponent.prototype_unempowered_auto_mult)
## starts at its export here. It never touches the player's saves.

## The deflect flag this sandbox starts with.
@export var deflect_test_enabled: bool = true
## The poise flag this sandbox starts with.
@export var poise_test_enabled: bool = true
## TEMP: the weak-auto lever this sandbox starts with (1.0 = off).
@export_range(0.2, 1.0, 0.05) var prototype_unempowered_auto_mult: float = 0.5

var _previous: Array = []   # [deflect flag, poise flag, weak-auto lever] as found


func _ready() -> void:
	_previous = [DeflectComponent.deflect_test_enabled, PoiseComponent.poise_test_enabled,
		AutoAttackComponent.prototype_unempowered_auto_mult]
	if Progress.is_test_scene():
		return   # a test sets its own
	DeflectComponent.deflect_test_enabled = deflect_test_enabled
	PoiseComponent.poise_test_enabled = poise_test_enabled
	AutoAttackComponent.prototype_unempowered_auto_mult = prototype_unempowered_auto_mult
	print("SandboxDeflect: ", get_status_text(), " (V: deflect, Shift+V: poise)")


func _exit_tree() -> void:
	if _previous.is_empty() or Progress.is_test_scene():
		return
	DeflectComponent.deflect_test_enabled = _previous[0]
	PoiseComponent.poise_test_enabled = _previous[1]
	AutoAttackComponent.prototype_unempowered_auto_mult = _previous[2]


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_V:
			if key.shift_pressed:
				set_poise_enabled(not PoiseComponent.poise_test_enabled)
			else:
				set_deflect_enabled(not DeflectComponent.deflect_test_enabled)
		_:
			return
	get_viewport().set_input_as_handled()


func set_deflect_enabled(on: bool) -> void:
	DeflectComponent.deflect_test_enabled = on
	print("SandboxDeflect: ", get_status_text())


func set_poise_enabled(on: bool) -> void:
	PoiseComponent.poise_test_enabled = on
	print("SandboxDeflect: ", get_status_text())


## One line: the flags and the lever now.
func get_status_text() -> String:
	return "deflect %s, poise %s, weak autos x%.2f" % ["ON" if DeflectComponent.deflect_test_enabled else "off",
		"ON" if PoiseComponent.poise_test_enabled else "off", AutoAttackComponent.prototype_unempowered_auto_mult]
