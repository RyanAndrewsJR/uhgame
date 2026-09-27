extends Ability
## Knight R - Judgement: strike a target enemy for heavy damage that grows
## with its missing health, and stun it.

## Extra damage as a fraction of the target's missing health.
@export var missing_health_ratio: float = 0.2
@export var stun_duration: float = 0.75


func get_damage_against(caster: Unit, target: Unit) -> float:
	return get_damage(caster) + get_missing_health_bonus(target)


## The extra damage from the target's missing health.
func get_missing_health_bonus(target: Unit) -> float:
	return (target.health.max_health - target.health.current) * missing_health_ratio


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
	# Through the hit pipeline (COMBAT C8): the missing-health bonus is part
	# of the base damage, so it crits and gets damage_increase too.
	var hit := HitPipeline.from_ability(caster, self, target)
	hit.base_damage += get_missing_health_bonus(target)
	HitPipeline.resolve(hit)
	if not hit.blocked:
		target.apply_stun(stun_duration, caster)
	GameFeel.shake(6.0)
	GameFeel.hitstop(0.09)
