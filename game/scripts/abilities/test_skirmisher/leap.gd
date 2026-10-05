extends Ability
## Test skirmisher Q - Leap (ENEMIES_AI AI3; Ryan, 2026-10-04: a real leap):
## its gap-closer. Through its cast time a circle fills where it will land
## (the telegraph; its brain's crouch tell comes before), then it leaps there
## over everything (MovementComponent.leap(), Judgement Leap's way) and hits
## everyone still inside on landing. Its AI plan lands it beside its target,
## not on it. A dash out of the circle answers it. Not part of any kit.

## The landing circle's radius, px.
@export var radius_px: float = 48.0
## How long the leap itself takes, s.
@export var leap_time: float = 0.4
## Enemy attack hitboxes are this much smaller than they look (COMBAT.md).
@export_range(0.0, 0.2) var enemy_hit_forgiveness: float = 0.10
@export var telegraph_color: Color = Telegraph.THREAT_COLOR


func on_cast_started(caster: Unit, ctx: CastContext) -> void:
	ctx.point = caster.movement.get_leap_landing(ctx.point)   # where it will really land
	ctx.telegraph = Telegraph.circle(caster, ctx.point, radius_px, cast_time, telegraph_color)


func execute(caster: Unit, ctx: CastContext) -> void:
	if is_instance_valid(ctx.telegraph):
		ctx.telegraph.finish()
	caster.movement.leap(ctx.point, leap_time)
	while caster.movement.is_leaping():
		await caster.get_tree().physics_frame
		if not is_instance_valid(caster):
			return
	if not caster.is_alive():
		return
	var center := caster.global_position
	VFX.ring(caster.get_parent(), center, radius_px * 0.4, radius_px, telegraph_color, 0.25, 3.0)
	var inside := filter_by_walls(center, AbilityUtil.in_circle(caster, center, radius_px * (1.0 - enemy_hit_forgiveness)))
	play_hit_feel(hit_units(caster, inside, ctx))


## The default plan (its target in range and in sight), landing beside its
## target: edge to edge, on the side it comes from.
func get_ai_plan(caster: Unit, situation: SituationContext) -> CastPlan:
	var plan := super.get_ai_plan(caster, situation)
	if plan == null or not is_instance_valid(plan.target):
		return plan
	var to_target := plan.target.global_position - caster.global_position
	var dist := to_target.length()
	if dist > 0.01:
		var stop := caster.get_gameplay_radius_px() + plan.target.get_gameplay_radius_px()
		plan.point = plan.target.global_position - to_target / dist * stop
	plan.reason = "leap beside it"
	return plan


func draw_indicator(canvas: Node2D, caster: Unit, aim: Vector2) -> void:
	var range_px := Units.to_px(get_param(caster, &"cast_range"))
	var landing := canvas.to_local(caster.movement.get_leap_landing(caster.global_position + (aim - caster.global_position).limit_length(range_px)))
	canvas.draw_arc(Vector2.ZERO, range_px, 0.0, TAU, 64, Color(1, 1, 1, 0.25), 1.0)
	canvas.draw_arc(landing, radius_px, 0.0, TAU, 48, Color(telegraph_color, 0.8), 1.0)
