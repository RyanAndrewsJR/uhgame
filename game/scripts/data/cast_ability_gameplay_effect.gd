class_name CastAbilityGameplayEffect
extends GameplayEffect
## The target casts `ability` for free (ABILITIES AB8; Diablo's "also casts"):
## no cost, no cooldown, no charge, no cast time, no slot, no locks, and it
## doesn't interrupt a cast in progress. It aims at what triggered the rule:
## the triggering cast's aim point and target (ABILITY_CAST), the unit hit
## (HIT, UNIT_DIED), otherwise the caster's current aim. A dead or
## cast-blocked unit refuses it. Chain-limited like any reaction: its own
## ability_cast event (and its hits) count one link deeper.

@export var ability: Ability


func apply(target: Unit, _source: Unit, trigger_ctx: RefCounted) -> void:
	if ability == null or not is_instance_valid(target) or target.abilities == null:
		return
	var aim := _default_aim(target)
	var aim_target: Unit = null
	if trigger_ctx is CastContext:
		aim = (trigger_ctx as CastContext).point
		aim_target = (trigger_ctx as CastContext).target
	elif trigger_ctx is HitContext:
		var hit_unit := (trigger_ctx as HitContext).target as Unit
		if is_instance_valid(hit_unit):
			aim = hit_unit.global_position
			aim_target = hit_unit
	target.abilities.try_cast_free(ability, aim, aim_target, Reactions.get_current_source_id())


## The caster's current aim: the cursor for the Player, otherwise straight
## ahead of its facing (or right).
static func _default_aim(caster: Unit) -> Vector2:
	if caster.has_method(&"get_aim_point"):
		return caster.call(&"get_aim_point")
	var facing: Variant = caster.get(&"facing")
	var dir: Vector2 = facing if facing is Vector2 else Vector2.RIGHT
	return caster.global_position + dir * 100.0
