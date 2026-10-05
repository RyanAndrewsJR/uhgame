extends Ability
## The enemy ability library (ENEMIES_AI AI3d, Kits): Hop away. A quick dash
## to its point (clamped to cast_range), not through anyone: it stops at
## units and slides on walls. Its AI plan points it straight away from its
## target. An `escape` use; no damage, so no telegraph. A root stops it (it
## moves its caster: tagged `dash`).

## How long the hop takes, s.
@export var hop_time: float = 0.15


func execute(caster: Unit, ctx: CastContext) -> void:
	var offset := ctx.point - caster.global_position
	if offset.length() < 1.0:
		return
	var time := maxf(hop_time, 0.01)
	caster.movement.dash(offset / time, time, false)


## Its whole range straight away from its target.
func get_ai_plan(caster: Unit, situation: SituationContext) -> CastPlan:
	if situation == null or not is_instance_valid(caster) or not is_instance_valid(situation.target_unit):
		return null
	var target := situation.target_unit
	var away := caster.global_position - target.global_position
	away = away.normalized() if away.length() > 0.01 else Vector2.RIGHT
	var plan := CastPlan.new()
	plan.ability = self
	plan.target = target
	plan.direction = away
	plan.point = caster.global_position + away * Units.to_px(get_param(caster, &"cast_range"))
	plan.intents = get_passing_intents(caster, target, situation)
	if plan.intents.is_empty():
		return null
	plan.value = 1.0
	plan.reason = "hop straight away"
	return plan


## It lands on nobody.
func get_effect_area(_caster: Unit, _ctx: CastContext) -> Dictionary:
	return {"kind": &"none"}
