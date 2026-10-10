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
	RESPECT,                ## The brain's situation: its respect (0-1) compared with value (ENEMIES_AI AI1).
	THREATENED,             ## The brain's situation: an attack it sees coming at it lands within value s (0 = any time; ENEMIES_AI AI3). With status_tag set, only an attack whose ability carries that tag; &"major" = any of the table's major_tags (AI-D1).
	CROWDING,               ## The brain's situation: its crowding (0-1, how hard its target pushes it) compared with value (ENEMIES_AI AI-D1).
	OPENING,                ## The brain's situation: the opening (0-1, how open its target is to its crowd control and burst) compared with value (AI-D1).
	TARGET_ESCAPES_READY,   ## The brain's situation: at least count of its target's mobility and defensive abilities ready, as the HUD shows them (AI-D1).
	TARGET_CORNERED,        ## The brain's situation: a wall or a ledge just behind its target, seen from self (AI-D1).
	TARGET_CLOSED_IN,       ## The brain's situation: its target closed in on it (inside the table's riposte_stance_range, or a gap-closer of its ended inside its band's minimum), seen after its reaction time, never while it commits (ARCHETYPES AR3b: the Riposte Stance's use).
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
## Stacks are summed over every status with the tag. THREATENED (AI-D1): the
## incoming ability's tag (empty = any attack; &"major" = any of major_tags).
@export var status_tag: StringName = &""
## SELF_ / TARGET_HAS_STATUS.
@export var min_stacks: int = 1
## The *_HEALTH_PERCENT kinds, TARGET_DISTANCE, RESPECT, CROWDING and OPENING.
@export var comparison: Comparison = Comparison.AT_LEAST
## *_HEALTH_PERCENT: 0-1 of max health. TARGET_DISTANCE: LoL units, edge to
## edge. RESOURCE_AT_LEAST: the amount. RESPECT, CROWDING, OPENING: 0-1.
## THREATENED: seconds (0 = any attack coming, whenever it lands).
@export var value: float = 0.0
## ENEMIES_IN_RANGE and TARGET_ESCAPES_READY: at least this many.
@export var count: int = 1
## ENEMIES_IN_RANGE: LoL units from self's feet, each enemy's gameplay
## radius counted.
@export var radius: float = 300.0
## Short text for later UI ("No marked target"; UI.md).
@export var fail_text: String = ""


## The kind's check, then negate. `cast` is the CastContext when there is one
## (LAST_PART_HIT reads it); null otherwise. `situation` is an enemy brain's
## SituationContext when an AI use rule is checked (ENEMIES_AI AI1, AI3); the
## situation kinds (RESPECT, THREATENED; AI-D1: CROWDING, OPENING,
## TARGET_ESCAPES_READY, TARGET_CORNERED) read it, and without one they're
## false, even when negated (a cast condition, a reaction rule). The other
## kinds ignore it.
func is_met(self_unit: Unit, target: Unit, cast: CastContext = null, situation: SituationContext = null) -> bool:
	if not is_instance_valid(self_unit):
		return false
	if is_target_kind() and (not is_instance_valid(target) or not target.is_alive()):
		return false   # no target: false, even when negated
	if is_situation_kind():
		if situation == null:
			return false   # no situation: false, even when negated
		return _check_situation(situation) != negate
	return _check(self_unit, target, cast) != negate


## A kind that reads the target (TARGET_HAS_STATUS, TARGET_HEALTH_PERCENT,
## TARGET_DISTANCE).
func is_target_kind() -> bool:
	return kind == Kind.TARGET_HAS_STATUS or kind == Kind.TARGET_HEALTH_PERCENT or kind == Kind.TARGET_DISTANCE


## A kind that reads a brain's SituationContext (RESPECT, THREATENED; AI-D1's
## CROWDING, OPENING, TARGET_ESCAPES_READY, TARGET_CORNERED; ARCHETYPES AR3b's
## TARGET_CLOSED_IN; later TARGET_WHIFFED, ENEMIES_AI AI6).
func is_situation_kind() -> bool:
	return kind == Kind.RESPECT or kind == Kind.THREATENED or kind == Kind.CROWDING or kind == Kind.OPENING \
		or kind == Kind.TARGET_ESCAPES_READY or kind == Kind.TARGET_CORNERED or kind == Kind.TARGET_CLOSED_IN


## All of `conditions` pass (AND). An empty list passes.
static func all_met(conditions: Array[Condition], self_unit: Unit, target: Unit, cast: CastContext = null, situation: SituationContext = null) -> bool:
	for c in conditions:
		if c != null and not c.is_met(self_unit, target, cast, situation):
			return false
	return true


## The first of `conditions` that fails (for its fail_text), or null.
static func first_failed(conditions: Array[Condition], self_unit: Unit, target: Unit, cast: CastContext = null, situation: SituationContext = null) -> Condition:
	for c in conditions:
		if c != null and not c.is_met(self_unit, target, cast, situation):
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


## RESPECT: the party's respect as the situation saw it (0-1, before the
## enemy's respect_weight slider: the same for every enemy).
## THREATENED: an attack the brain has seen coming at it (after its reaction
## time: SituationContext.incoming) lands within `value` seconds; 0 = any.
## With status_tag, only one whose ability carries it (&"major": any of the
## situation's major_tags; AI-D1).
## AI-D1: CROWDING and OPENING compare the situation's reads (0-1);
## TARGET_ESCAPES_READY: at least `count` of the target's mobility and
## defensive abilities ready; TARGET_CORNERED: a wall or a ledge just behind
## the target. ARCHETYPES AR3b: TARGET_CLOSED_IN, its target closed in on it
## (SituationContext.target_closed_in).
func _check_situation(situation: SituationContext) -> bool:
	match kind:
		Kind.RESPECT:
			return _compare(situation.respect)
		Kind.THREATENED:
			return situation.is_threatened(value, status_tag)
		Kind.CROWDING:
			return _compare(situation.crowding)
		Kind.OPENING:
			return _compare(situation.opening)
		Kind.TARGET_ESCAPES_READY:
			return situation.has_target and situation.target_escapes_ready >= count
		Kind.TARGET_CORNERED:
			return situation.has_target and situation.target_cornered
		Kind.TARGET_CLOSED_IN:
			return situation.has_target and situation.target_closed_in
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
