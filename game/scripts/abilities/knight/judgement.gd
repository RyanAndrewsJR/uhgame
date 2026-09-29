extends Ability
## Knight R - Judgement: strike a target enemy for heavy damage that grows
## with its missing health, and stun it.
## The missing-health bonus is a DamageScaling term in the .tres (param
## &"target_missing_health_ratio", ABILITIES AB2), so HitPipeline.from_ability()
## adds it to the base damage (it crits too) and items can raise it.
## Toolkit pieces (ABILITIES AB11): hit_units() for the hit (the cast's
## context) with the stun as a status of the hit (applied after the damage,
## from the Knight, if the hit gets through), play_hit_feel() for the shake
## and hitstop (hit_shake / hit_hitstop in the .tres). The VFX are its own.

const STATUS_STUN: StatusEffect = preload("res://data/statuses/status_stun.tres")

@export var stun_duration: float = 0.75


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
	# The stun: status_stun for stun_duration (tenacity still shortens it).
	var stun: StatusEffect = STATUS_STUN.duplicate()
	stun.duration = get_param(caster, &"stun_duration")
	var targets: Array[Unit] = [target]
	var statuses: Array[StatusEffect] = [stun]
	play_hit_feel(hit_units(caster, targets, ctx, statuses))
