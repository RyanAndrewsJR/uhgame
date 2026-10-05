class_name StatScaling
extends Resource
## A stat modifier whose value follows a 0-1 input through a curve
## (CHAMPIONS.md, Passives): "stronger the more health you're missing".
## A passive has no cast, so it can't read a CastContext's named inputs; the
## unit reads the input itself. Added with Unit.add_stat_scaling(), which
## keeps one StatModifier copy in the StatsComponent and refreshes its value
## when the unit's health changes. Lives inline (in a Passive).

## The full-strength modifier: its stat, type and value (scope allowed). Its
## source_id is ignored: the holder's source id is used.
@export var modifier: StatModifier
## The 0-1 input: &"self_missing_health" (1 - health / max health), or since
## CHAMPIONS K2 &"self_status_stacks" (the holder's stacks of statuses tagged
## status_tag ÷ max_stacks, at most 1). An unknown input is reported and
## counts 0.
@export var input: StringName = &"self_missing_health"
## x = the input 0-1, y = the fraction of the modifier's value 0-1.
## null = linear (the fraction is the input).
@export var curve: Curve
## &"self_status_stacks" only: the status tag whose stacks are counted
## (StatusComponent.get_tag_stacks()) and the count that gives 1.
@export var status_tag: StringName = &""
@export var max_stacks: int = 1

static var _reported: Dictionary = {}   # unknown input -> true (reported once)


## The modifier's value for `unit` now: value x curve(input).
func get_value(unit: Unit) -> float:
	if modifier == null:
		return 0.0
	return modifier.value * get_fraction(read_own_input(unit))


## This scaling's input for `unit` now (0-1): the stack count for
## &"self_status_stacks", else the shared built-ins (read_input()).
func read_own_input(unit: Unit) -> float:
	if input == &"self_status_stacks":
		if unit.status_component == null or max_stacks <= 0:
			return 0.0
		return minf(float(unit.status_component.get_tag_stacks(status_tag)) / float(max_stacks), 1.0)
	return read_input(unit, input)


## The share of the full value at `x` (the input, 0-1).
func get_fraction(x: float) -> float:
	var t := clampf(x, 0.0, 1.0)
	if curve != null:
		t = clampf(curve.sample(t), 0.0, 1.0)
	return t


## A copy of the modifier with the value for `unit` now, under `source_id`.
func make_modifier(unit: Unit, source_id: StringName) -> StatModifier:
	return StatModifier.create(modifier.stat, modifier.type, get_value(unit), source_id, modifier.scope)


## The built-in inputs a StatScaling can read (0-1).
static func read_input(unit: Unit, input_name: StringName) -> float:
	match input_name:
		&"self_missing_health":
			var max_health := unit.health.max_health
			return 1.0 - unit.health.current / max_health if max_health > 0.0 else 0.0
	if not _reported.has(input_name):
		_reported[input_name] = true
		push_error("StatScaling: unknown input '%s' (counts 0)" % input_name)
	return 0.0
