class_name ScriptedController
extends UnitController
## A UnitController that plays a list of steps on a unit (ENEMIES_AI.md, Test
## and sandbox data; AI1): the headless tests' dummy player. ALLIES AL1's
## scripted test controller is this class. It drives the unit through the
## unit's own commands only: MovementComponent.move_to(), AbilityComponent's
## casts, AutoAttackComponent.try_swing().
## Each step is a Dictionary:
##   {op = &"walk_to", point = Vector2}    walk there (done on arrival, or after
##                                         `timeout` s, default 5)
##   {op = &"cast", slot = &"q", point = Vector2, target = Unit (optional)}
##   {op = &"swing", direction = Vector2}
##   {op = &"wait", time = float}
## A Player keeps its PlayerInput (which only reads the keyboard, so it sends
## nothing in a test): a walk is a move_to() order, which input of zero
## doesn't cancel.

signal finished

var _steps: Array[Dictionary] = []
var _index := 0
var _left := 0.0
var _started := false


## Plays `steps` from the first; replaces whatever was playing.
func play(steps: Array[Dictionary]) -> void:
	_steps = steps
	_index = 0
	_started = false
	set_physics_process(true)


func is_done() -> bool:
	return _index >= _steps.size()


func get_step_index() -> int:
	return _index


func _ready() -> void:
	set_physics_process(not _steps.is_empty())


func _physics_process(delta: float) -> void:
	var unit := get_unit()
	if unit == null or not unit.is_alive() or is_done():
		set_physics_process(false)
		return
	var step := _steps[_index]
	if not _started:
		_started = true
		_left = float(step.get("time", step.get("timeout", 5.0)))
		match step.op:
			&"walk_to":
				unit.movement.move_to(step.point)
			&"cast":
				if unit.abilities != null:
					unit.abilities.try_cast(step.slot, step.point, step.get("target"))
				_next()
				return
			&"swing":
				unit.attack.try_swing(step.direction)
				_next()
				return
	_left -= delta
	match step.op:
		&"walk_to":
			if not unit.movement.has_order() or _left <= 0.0:
				_next()
		&"wait":
			if _left <= 0.0:
				_next()
		_:
			_next()


func _next() -> void:
	_index += 1
	_started = false
	if is_done():
		set_physics_process(false)
		finished.emit()
