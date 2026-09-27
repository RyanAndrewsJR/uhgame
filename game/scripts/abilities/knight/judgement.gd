extends Ability
## Knight R - Judgement: strike a target enemy for heavy damage that grows
## with its missing health, and stun it.
## The missing-health bonus is a DamageScaling term in the .tres (param
## &"target_missing_health_ratio", ABILITIES AB2), so HitPipeline.from_ability()
## adds it to the base damage (it crits too) and items can raise it.

@export var stun_duration: float = 0.75


## The extra damage from the target's missing health (the scaling term, base
## ratio). Kept as a wrapper for existing callers.
func get_missing_health_bonus(target: Unit) -> float:
	var term := get_scaling(&"target_missing_health_ratio")
	return 0.0 if term == null else term.ratio * term.get_amount(null, target)


func execute(caster: Unit, ctx: CastContext) -> void:
	var target := ctx.target
	if not is_instance_valid(target) or not target.is_alive():
		return
	if not can_reach_through_walls(caster.global_position, target):
		return  # It went behind a wall during the cast: a miss (COMBAT C7).
	var parent := target.get_parent()
	VFX.impact(parent, target.global_position, Color(icon_color, 0.95), 90.0, 0.35)
	VFX.slash(parent, target.get_center(), (target.global_position - caster.global_position).angle() + PI * 0.5,
		4.0, 26.0, deg_to_rad(70.0), Color(icon_color, 0.95), 0.12)
	VFX.ring(parent, target.global_position, 8.0, 44.0, icon_color, 0.4, 3.0)
	# Through the hit pipeline (COMBAT C8): the missing-health bonus is a
	# scaling term, part of the base damage, so it crits and gets
	# damage_increase too.
	var hit := HitPipeline.from_ability(caster, self, target)
	HitPipeline.resolve(hit)
	if not hit.blocked:
		target.apply_stun(stun_duration, caster)
	GameFeel.shake(6.0)
	GameFeel.hitstop(0.09)
