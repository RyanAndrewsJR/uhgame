extends "res://scripts/abilities/test/blink.gd"
## Test caster E - Blink away (ENEMIES_AI AI3): the test blink
## (MovementComponent.blink(); this one stops at walls: through_walls off in
## its .tres), used to escape. Its AI plan blinks it away from its target:
## the one of five directions (straight away, ±35°, ±70°) where it would
## really land (get_blink_landing()) farthest from its target; none gaining
## at least min_gain_px = no plan (it walks away instead, then is cornered).
## Not part of any kit.

const ESCAPE_ANGLES_DEG: Array[float] = [0.0, 35.0, -35.0, 70.0, -70.0]

## A blink that doesn't get it at least this much farther from its target
## (px) isn't worth casting.
@export var min_gain_px: float = 48.0


func get_ai_plan(caster: Unit, situation: SituationContext) -> CastPlan:
	if situation == null or not is_instance_valid(caster):
		return null
	var target := situation.target_unit
	if not is_instance_valid(target):
		return null
	var intents := get_passing_intents(caster, target, situation)
	if intents.is_empty():
		return null
	var range_px := Units.to_px(get_param(caster, &"cast_range"))
	var away := caster.global_position - target.global_position
	away = away.normalized() if away.length() > 0.01 else Vector2.RIGHT
	var now_dist := caster.global_position.distance_to(target.global_position)
	var best := Vector2.INF
	var best_dist := now_dist + min_gain_px
	for deg in ESCAPE_ANGLES_DEG:
		var point := caster.global_position + away.rotated(deg_to_rad(deg)) * range_px
		var dist := caster.movement.get_blink_landing(point, through_walls).distance_to(target.global_position)
		if dist > best_dist:
			best = point
			best_dist = dist
	if best == Vector2.INF:
		return null
	var plan := CastPlan.new()
	plan.ability = self
	plan.point = best
	plan.direction = (best - caster.global_position).normalized()
	plan.intents = intents
	plan.value = clampf((best_dist - now_dist) / maxf(range_px, 1.0), 0.0, 1.0)
	plan.reason = "blink away"
	return plan
