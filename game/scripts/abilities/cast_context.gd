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
## Recast part: 0 = the first cast, 1 = the first recast... (ABILITIES AB5).
var part: int = 0
## CHARGE_UP: how charged it was at release, 0 (a tap) to 1 (full). Every
## other cast is 1.0, so charged params are their full value (ABILITIES AB6).
var charge: float = 1.0
## Aim point in world space (already clamped to range for POINT abilities).
var point: Vector2
## Normalized direction from the caster toward the aim point.
var direction: Vector2 = Vector2.RIGHT
## The clicked unit, for UNIT abilities.
var target: Unit
## A floor warning shown during the cast time (Ability.on_cast_started()).
## AbilityComponent removes it if the cast is cancelled or interrupted;
## execute() usually calls finish() on it.
var telegraph: Telegraph


## True if the FLAG augment `flag` was active on this cast (ABILITIES AB8).
func has_flag(flag: StringName) -> bool:
	return flags.has(flag)
