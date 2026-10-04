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
## CHAMPIONS CH4: its Fury bonus (a conditional bonus RESOURCE_AT_LEAST 60 in the
## .tres: more damage and a longer stun) is checked at the hit, and a hit that
## lands with it consumes all the caster's Fury (consume_resource_on_bonus).
## FLAG &"judgement_shockwave" (TALENTS T3, Shockwave): once the target's hit
## lands, every other enemy within flag_shockwave_radius of the target (in
## sight from it) takes flag_shockwave_damage_ratio of Judgement's damage (the
## cast's crit roll, the Fury bonus checked per hit) and a
## flag_shockwave_stun_duration stun, plus whatever the bonus adds to the
## target's stun. The talent also zeroes target_missing_health_ratio (data).
## The Fury is consumed once, by the target's hit, as before.
## LOOT L5, an item FLAG (Chains of Judgement): &"judgement_drag": at the
## effect, before the hit, the target is dragged toward the Knight until
## flag_drag_gap_px from his edge (the pathing radii) over flag_drag_time,
## airborne for the drag (status_airborne from the Knight), so the knock-up's
## movement carries it over fences, cliffs and pits (walls stop it), its
## landing rule sets it down and its view arcs it. The hit, the stun and
## everything after land when the drag ends, wherever the target is (Shockwave
## splashes around it there). An unstoppable target isn't moved (it refuses
## airborne); the hit lands where it stands.

const STATUS_STUN: StatusEffect = preload("res://data/statuses/status_stun.tres")

@export var stun_duration: float = 0.75
## A hit that lands while a bonus with a RESOURCE_AT_LEAST condition is active
## spends the caster's whole resource pool (the Fury payoff is a spend, not a
## free buff for holding 60).
@export var consume_resource_on_bonus: bool = true
## With &"judgement_shockwave": the splash radius around the target, LoL
## units (250 = 80 px), its share of the damage and its stun, seconds.
@export var flag_shockwave_radius: float = 250.0
@export var flag_shockwave_damage_ratio: float = 0.5
@export var flag_shockwave_stun_duration: float = 0.5
## With &"judgement_drag" (Chains of Judgement): the gap left between the
## Knight's edge and the target's, px, and how long the drag takes, seconds.
@export var flag_drag_gap_px: float = 8.0
@export var flag_drag_time: float = 0.15


func execute(caster: Unit, ctx: CastContext) -> void:
	var target := ctx.target
	if not is_instance_valid(target) or not target.is_alive():
		return
	if not can_reach_through_walls(caster.global_position, target):
		return  # It went behind a wall during the cast: a miss (COMBAT C7).
	if ctx.has_flag(&"judgement_drag"):
		var drag_time := get_effect_param(caster, &"flag_drag_time", ctx)
		if _drag(caster, ctx, target, drag_time):
			await caster.get_tree().create_timer(drag_time, false, true).timeout
			if not is_instance_valid(caster) or not caster.is_alive() or not is_instance_valid(target) or not target.is_alive():
				return
	_strike(caster, ctx, target)


## Chains of Judgement: pulls `target` through the air toward the Knight, to
## the gap from his edge (the toolkit's pull_airborne()). False when it isn't
## moved: unstoppable or untargetable (it refuses airborne), already within
## the gap, or a stronger displacement running.
func _drag(caster: Unit, ctx: CastContext, target: Unit, drag_time: float) -> bool:
	var to_caster := caster.global_position - target.global_position
	var gap := caster.get_pathing_radius_px() + target.get_pathing_radius_px() + get_effect_param(caster, &"flag_drag_gap_px", ctx)
	var distance := to_caster.length() - gap
	if distance <= 0.5:
		return false
	return pull_airborne(caster, target, target.global_position + to_caster.normalized() * distance, drag_time)


## The hit (as before LOOT L5): the stun, the Fury bonus, Shockwave, the Fury spent.
func _strike(caster: Unit, ctx: CastContext, target: Unit) -> void:
	var parent := target.get_parent()
	VFX.impact(parent, target.global_position, Color(icon_color, 0.95), 90.0, 0.35)
	VFX.slash(parent, VFX.drawing_origin(target), (target.global_position - caster.global_position).angle() + PI * 0.5,
		4.0, 26.0, deg_to_rad(70.0), Color(icon_color, 0.95), 0.12)
	VFX.ring(parent, target.global_position, 8.0, 44.0, icon_color, 0.4, 3.0)
	# The stun: status_stun for stun_duration, conditional bonuses included
	# (tenacity still shortens it).
	var stun: StatusEffect = STATUS_STUN.duplicate()
	stun.duration = get_effect_param(caster, &"stun_duration", ctx, target)
	# Checked with the same inputs as the hit's own bonus check (same frame, before it).
	var resource_bonus := _has_resource_bonus(caster, ctx, target)
	var targets: Array[Unit] = [target]
	var statuses: Array[StatusEffect] = []
	# A 0 s stun is no stun (TALENTS T2: Executioner multiplies it by 0).
	if stun.duration > 0.0:
		statuses.append(stun)
	var hits := hit_units(caster, targets, ctx, statuses)
	var landed := play_hit_feel(hits)
	if landed and ctx.has_flag(&"judgement_shockwave"):
		# The stun the Fury bonus adds to the target's, if any, adds to the splash's too.
		var bonus_stun := stun.duration - get_param(caster, &"stun_duration")
		_shockwave(caster, ctx, target, hits[0].crit_roll, bonus_stun)
	if landed and resource_bonus and consume_resource_on_bonus and caster.resource_pool != null:
		caster.resource_pool.try_spend(caster.resource_pool.current)


## Shockwave: every other enemy near the target, in sight from it, takes a
## share of the hit and a short stun. Resolved before the Fury is consumed,
## so the bonus reaches every hit.
func _shockwave(caster: Unit, ctx: CastContext, target: Unit, crit_roll: HitContext.CritRoll, bonus_stun: float) -> void:
	var center := target.global_position
	var radius := Units.to_px(get_effect_param(caster, &"flag_shockwave_radius", ctx))
	var ratio := get_effect_param(caster, &"flag_shockwave_damage_ratio", ctx)
	var stun_time := get_effect_param(caster, &"flag_shockwave_stun_duration", ctx) + maxf(bonus_stun, 0.0)
	VFX.ring(target.get_parent(), center, 10.0, radius, Color(icon_color, 0.9), 0.35, 3.0)
	var splash := filter_by_walls(center, AbilityUtil.in_circle(caster, center, radius)).filter(
		func(u: Unit) -> bool: return u != target)
	var statuses: Array[StatusEffect] = []
	if stun_time > 0.0:
		var stun: StatusEffect = STATUS_STUN.duplicate()
		stun.duration = stun_time
		statuses.append(stun)
	hit_units(caster, splash, ctx, statuses, ratio, crit_roll)


## True if a bonus with a RESOURCE_AT_LEAST condition passes for this hit.
func _has_resource_bonus(caster: Unit, ctx: CastContext, target: Unit) -> bool:
	for b in get_active_bonuses(caster, ctx, target):
		for c in b.conditions:
			if c != null and c.kind == Condition.Kind.RESOURCE_AT_LEAST:
				return true
	return false
