class_name CastContext
extends RefCounted
## Everything an ability needs to know about how it was cast.

var slot: StringName
## The ability being cast (the variant if a REPLACE augment is active).
var ability: Ability
## The FLAG augments active on it at cast start (AB8): its script checks
## has_flag(). Removing an augment mid-cast doesn't change them.
var flags: Array[StringName] = []
## A free cast (CastAbilityGameplayEffect): no cost, cooldown, slot or cast time.
var is_free: bool = false
## Who granted a free cast (&"item_…", &"passive_…", &"augment_…"); &"" for a slot cast.
var source_id: StringName = &""
## The reaction chain depth a free cast counts at (its ability_cast event and
## its hits); 0 for a slot cast.
var chain_depth: int = 0
## The ABILITY_CAST empowers this cast used up at its effect start (AB10);
## HitPipeline.from_ability(…, cast) adds them to every hit. Always empty for
## a free cast (free casts don't use up empowers).
var empowers: Array[StatusEffect] = []
## Recast part: 0 = the first cast, 1 = the first recast... (ABILITIES AB5).
var part: int = 0
## Named 0-1 scaling inputs (ABILITIES AB12): ChargeScaling resources read
## them through Ability.get_effect_param(). AbilityComponent fills the
## built-ins when the cast starts (at release for CHARGE_UP and VECTOR):
## &"charge", &"self_missing_health", &"target_distance", &"vector_drag"
## (VECTOR: drag length ÷ vector_length; AB13); &"target_missing_health" is
## per target (computed at the hit). A script may set others (set_input()).
var inputs: Dictionary = {&"charge": 1.0}
## CHARGE_UP: how charged it was at release, 0 (a tap) to 1 (full). Every
## other cast is 1.0, so charged params are their full value (ABILITIES AB6).
## Since AB12 a thin wrapper over inputs[&"charge"]; every use is unchanged.
var charge: float:
	get:
		return inputs.get(&"charge", 1.0)
	set(value):
		inputs[&"charge"] = clampf(value, 0.0, 1.0)
## In a recast sequence: whether the previous part hit something
## (Condition LAST_PART_HIT; AB12). False for part 0 and outside a sequence.
var last_part_hit: bool = false
## VECTOR casts (ABILITIES AB13): the start point (world space, clamped to
## cast_range and to walls). `point` is the same spot and `direction` caster
## -> it, their usual meanings.
var vector_start: Vector2 = Vector2.ZERO
## VECTOR: the line's unit direction (start -> the release cursor, or the tap
## fallback: caster -> start).
var vector_direction: Vector2 = Vector2.RIGHT
## VECTOR: vector_start + vector_direction x vector_length (px).
var vector_end: Vector2 = Vector2.ZERO
## Aim point in world space (already clamped to range for POINT abilities).
var point: Vector2
## Normalized direction from the caster toward the aim point.
var direction: Vector2 = Vector2.RIGHT
## UNIT abilities: the chosen target (the enemy under the cursor, or the
## target_forgiveness pick). Other casts: the condition target (the enemy
## nearest the aim within cast_range) when the ability needs one (AB12), or
## a free cast's given target (the unit hit, the triggering cast's target).
var target: Unit
## Cast progress (ABILITIES AB14): the cast time from 0 (cast start; at
## release for CHARGE_UP and VECTOR) to 1 (the effect starts). 1 for a cast
## with no cast time and for a free cast. AbilityComponent advances it each
## physics tick by delta ÷ cast_time × the cast speed; scripts, the cast's
## telegraph and its cast_anim read it.
var progress: float = 0.0
## A floor warning shown during the cast time (Ability.on_cast_started()).
## AbilityComponent removes it if the cast is cancelled or interrupted;
## execute() usually calls finish() on it.
var telegraph: Telegraph


## A named input (0-1), or `default` if it isn't set (ABILITIES AB12).
func get_input(input_name: StringName, default: float = 0.0) -> float:
	return inputs.get(input_name, default)


## Sets a named input, clamped to 0-1 (a script's own, e.g. stacks / max).
func set_input(input_name: StringName, value: float) -> void:
	inputs[input_name] = clampf(value, 0.0, 1.0)


## True if the FLAG augment `flag` was active on this cast (ABILITIES AB8).
func has_flag(flag: StringName) -> bool:
	return flags.has(flag)
