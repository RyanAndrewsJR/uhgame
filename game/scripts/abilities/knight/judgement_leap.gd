extends "res://scripts/abilities/knight/judgement.gd"
## Knight R, The Last Verdict's variant (LOOT L6; REPLACE judgement_leap,
## variant_of knight_judgement): Judgement becomes a leap. POINT: the cast
## time is the crouch (it roots), then MovementComponent.leap() carries the
## Knight to the point over leap_time, over units, fences, cliffs, pits and
## walls, landing on the nearest walkable floor of the room (3D.md, Leaps).
## Where he lands, every enemy within landing_radius, in sight from there,
## takes Judgement's hit (judgement.gd's numbers: its damage with each
## target's own missing-health term, its stun, one crit roll for the cast).
## The Fury bonus (RESOURCE_AT_LEAST 60 in the .tres) is checked once at the
## landing, and a landing hit that gets through spends the Fury once
## (consume_resource_on_bonus, as judgement.gd).
## Executioner reaches it through variant_of: its data (40% missing health,
## no stun but the Fury's 0.5 s), and its reset rule (a kill on landing
## resets the cooldown).
## FLAG &"judgement_shockwave" (Shockwave's take): a second ring, from
## landing_radius out to flag_shockwave_ring_radius, takes
## flag_shockwave_damage_ratio of the damage and a flag_shockwave_stun_duration
## stun plus whatever the Fury bonus adds to the stun; the talent's data zeroes
## the missing-health term on every hit. Resolved before the Fury is spent, so
## the bonus reaches every hit.

## The time in the air, seconds.
@export var leap_time: float = 0.3
## Enemies within this of the landing take the hit, LoL units (220 = 70 px).
@export var landing_radius: float = 220.0
## With &"judgement_shockwave": the outer ring's radius, LoL units (370 = 118 px).
@export var flag_shockwave_ring_radius: float = 370.0


func execute(caster: Unit, ctx: CastContext) -> void:
	caster.movement.leap(ctx.point, get_effect_param(caster, &"leap_time", ctx))
	while caster.movement.is_leaping():
		await caster.get_tree().physics_frame
		if not is_instance_valid(caster):
			return
	if caster.is_alive():
		_landing(caster, ctx)


## The landing: the circle's hits, Shockwave's ring, the feel, the Fury spent.
func _landing(caster: Unit, ctx: CastContext) -> void:
	var center := caster.global_position
	var parent := caster.get_parent()
	var radius := Units.to_px(get_effect_param(caster, &"landing_radius", ctx))
	VFX.impact(parent, center, Color(icon_color, 0.95), 90.0, 0.35)
	VFX.ring(parent, center, 8.0, radius, icon_color, 0.4, 3.0)
	# Checked once, as the landing starts (the same inputs as each hit's own check).
	var resource_bonus := _has_resource_bonus(caster, ctx, null)
	var crit_roll := HitContext.CritRoll.new()
	var hits: Array[HitContext] = []
	var inside := filter_by_walls(center, AbilityUtil.in_circle(caster, center, radius))
	for u in inside:
		# Each target's own stun (a bonus could read the target).
		var one: Array[Unit] = [u]
		hits.append_array(hit_units(caster, one, ctx, _stun_for(get_effect_param(caster, &"stun_duration", ctx, u)), 1.0, crit_roll))
	if ctx.has_flag(&"judgement_shockwave"):
		var ring_radius := Units.to_px(get_effect_param(caster, &"flag_shockwave_ring_radius", ctx))
		VFX.ring(parent, center, radius, ring_radius, Color(icon_color, 0.9), 0.35, 3.0)
		var ring := filter_by_walls(center, AbilityUtil.in_circle(caster, center, ring_radius)).filter(
			func(u: Unit) -> bool: return not inside.has(u))
		# The stun the Fury bonus adds to the circle's, if any, adds to the ring's too.
		var bonus_stun := get_effect_param(caster, &"stun_duration", ctx) - get_param(caster, &"stun_duration")
		var ring_stun := get_effect_param(caster, &"flag_shockwave_stun_duration", ctx) + maxf(bonus_stun, 0.0)
		hits.append_array(hit_units(caster, ring, ctx, _stun_for(ring_stun),
			get_effect_param(caster, &"flag_shockwave_damage_ratio", ctx), crit_roll))
	var landed := play_hit_feel(hits)
	if landed and resource_bonus and consume_resource_on_bonus and caster.resource_pool != null:
		caster.resource_pool.try_spend(caster.resource_pool.current)


## A stun of `seconds` as a status of the hit; none for 0 s (Executioner).
func _stun_for(seconds: float) -> Array[StatusEffect]:
	var statuses: Array[StatusEffect] = []
	if seconds > 0.0:
		var stun: StatusEffect = STATUS_STUN.duplicate()
		stun.duration = seconds
		statuses.append(stun)
	return statuses


## The range, the line to where the Knight would land (the nearest walkable
## floor to the aim: MovementComponent.get_leap_landing()) and the landing
## circle there; with Shockwave, its outer ring.
func draw_indicator(canvas: Node2D, caster: Unit, aim: Vector2) -> void:
	var range_px := Units.to_px(get_param(caster, &"cast_range"))
	var radius := Units.to_px(get_param(caster, &"landing_radius"))
	var faint := Color(1, 1, 1, 0.25)
	var fill := Color(icon_color, 0.22)
	var edge := Color(icon_color, 0.8)
	var point := caster.global_position + (aim - caster.global_position).limit_length(range_px)
	var landing := canvas.to_local(caster.movement.get_leap_landing(point))
	canvas.draw_arc(Vector2.ZERO, range_px, 0.0, TAU, 64, faint, 1.0)
	canvas.draw_line(Vector2.ZERO, landing, edge, 1.5)
	canvas.draw_circle(landing, radius, fill)
	canvas.draw_arc(landing, radius, 0.0, TAU, 48, edge, 1.0)
	if caster.abilities != null and caster.abilities.get_flags(self).has(&"judgement_shockwave"):
		canvas.draw_arc(landing, Units.to_px(get_param(caster, &"flag_shockwave_ring_radius")), 0.0, TAU, 64, Color(icon_color, 0.45), 1.0)
