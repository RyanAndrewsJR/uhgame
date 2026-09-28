class_name Condition
extends Resource
## One check on unit state (ABILITIES.md, Conditions; AB12): the one condition
## system for the whole game. Abilities (cast_conditions, recast_conditions,
## conditional bonuses), reaction rules (ReactionRule.conditions), augments,
## passives, items and the enemy AI all use it. A list of conditions means all
## must pass (all_met(); an empty list passes); no OR, no nesting (scripts
## cover those). Inline in the .tres that uses it, or
## res://data/conditions/condition_<name>.tres when shared.
##
## "Self" is the unit the check is about (the caster; for a reaction rule the
## unit its effects come from); "target" is the condition target (a cast's
## target, the unit hit, a rule's effect target). A TARGET_ kind with no valid
## target is false, even when negated.

enum Kind {
	SELF_HAS_STATUS,        ## Self has >= min_stacks stacks of statuses tagged status_tag.
	TARGET_HAS_STATUS,      ## The target has >= min_stacks stacks of statuses tagged status_tag.
	SELF_HEALTH_PERCENT,    ## Self's current / max health compared with value (0-1).
	TARGET_HEALTH_PERCENT,  ## The target's current / max health compared with value (0-1).
	TARGET_DISTANCE,        ## Edge distance self -> target compared with value (LoL units).
	ENEMIES_IN_RANGE,       ## >= count living enemies of self within radius (tagged status_tag if set).
	RESOURCE_AT_LEAST,      ## Self's resource pool >= value; a unit without a pool fails.
	LAST_PART_HIT,          ## In a recast sequence, the previous part hit something (reads the cast).
}

enum Comparison {
	AT_LEAST,   ## >= : above, farther
	LESS_THAN,  ## <  : below, closer
}

@export var kind: Kind = Kind.SELF_HAS_STATUS
## The "not" toggle. It doesn't flip a TARGET_ kind with no target (that
## fails either way).
@export var negate: bool = false
## SELF_ / TARGET_HAS_STATUS, ENEMIES_IN_RANGE (empty there = any enemy).
## Stacks are summed over every status with the tag.
@export var status_tag: StringName = &""
## SELF_ / TARGET_HAS_STATUS.
@export var min_stacks: int = 1
## The *_HEALTH_PERCENT kinds and TARGET_DISTANCE.
@export var comparison: Comparison = Comparison.AT_LEAST
## *_HEALTH_PERCENT: 0-1 of max health. TARGET_DISTANCE: LoL units, edge to
## edge. RESOURCE_AT_LEAST: the amount.
@export var value: float = 0.0
## ENEMIES_IN_RANGE: at least this many.
@export var count: int = 1
## ENEMIES_IN_RANGE: LoL units from self's feet, each enemy's gameplay
## radius counted.
@export var radius: float = 300.0
## Short text for later UI ("No marked target"; UI.md).
@export var fail_text: String = ""


## The kind's check, then negate. `cast` is the CastContext when there is one
## (LAST_PART_HIT reads it); null otherwise.
func is_met(self_unit: Unit, target: Unit, cast: CastContext = null) -> bool:
	if not is_instance_valid(self_unit):
		return false
	if is_target_kind() and (not is_instance_valid(target) or not target.is_alive()):
		return false   # no target: false, even when negated
	return _check(self_unit, target, cast) != negate


## A kind that reads the target (TARGET_HAS_STATUS, TARGET_HEALTH_PERCENT,
## TARGET_DISTANCE).
func is_target_kind() -> bool:
	return kind == Kind.TARGET_HAS_STATUS or kind == Kind.TARGET_HEALTH_PERCENT or kind == Kind.TARGET_DISTANCE


## All of `conditions` pass (AND). An empty list passes.
static func all_met(conditions: Array[Condition], self_unit: Unit, target: Unit, cast: CastContext = null) -> bool:
	for c in conditions:
		if c != null and not c.is_met(self_unit, target, cast):
			return false
	return true


## The first of `conditions` that fails (for its fail_text), or null.
static func first_failed(conditions: Array[Condition], self_unit: Unit, target: Unit, cast: CastContext = null) -> Condition:
	for c in conditions:
		if c != null and not c.is_met(self_unit, target, cast):
			return c
	return null


## Any TARGET_ kind among `conditions`.
static func any_target_kind(conditions: Array[Condition]) -> bool:
	for c in conditions:
		if c != null and c.is_target_kind():
			return true
	return false


func _check(self_unit: Unit, target: Unit, cast: CastContext) -> bool:
	match kind:
		Kind.SELF_HAS_STATUS:
			return _stacks(self_unit) >= min_stacks
		Kind.TARGET_HAS_STATUS:
			return _stacks(target) >= min_stacks
		Kind.SELF_HEALTH_PERCENT:
			return _compare(_health_percent(self_unit))
		Kind.TARGET_HEALTH_PERCENT:
			return _compare(_health_percent(target))
		Kind.TARGET_DISTANCE:
			return _compare(Units.to_units(maxf(self_unit.edge_distance_to(target), 0.0)))
		Kind.ENEMIES_IN_RANGE:
			return _enemies_in_range(self_unit) >= count
		Kind.RESOURCE_AT_LEAST:
			return self_unit.resource_pool != null and self_unit.resource_pool.current >= value
		Kind.LAST_PART_HIT:
			return cast != null and cast.last_part_hit
	return false


func _compare(amount: float) -> bool:
	return amount >= value if comparison == Comparison.AT_LEAST else amount < value


func _stacks(u: Unit) -> int:
	if u == null or u.status_component == null or status_tag == &"":
		return 0
	return u.status_component.get_tag_stacks(status_tag)


func _health_percent(u: Unit) -> float:
	var max_health := u.health.max_health
	return u.health.current / max_health if max_health > 0.0 else 0.0


func _enemies_in_range(self_unit: Unit) -> int:
	var reach := Units.to_px(radius)
	var n := 0
	for u in AbilityUtil.enemies_of(self_unit):
		if self_unit.global_position.distance_to(u.global_position) - u.get_gameplay_radius_px() > reach:
			continue
		if status_tag != &"" and _stacks(u) <= 0:
			continue
		n += 1
	return n
