extends Ability
## Test ability (ABILITIES AB8, champion "test"): after its cast time, hits
## every enemy in a circle at the aim point. Supports the FLAG augment
## &"test_strike_stuns" (each unit hit is also stunned). Used by
## abilities_test and, through SandboxAbilities.test_q, in the sandbox. Not
## part of any kit.

const STUN: StatusEffect = preload("res://data/statuses/status_stun.tres")

## Radius of the circle, px.
@export var radius_px: float = 40.0
## Stun length with the &"test_strike_stuns" flag, seconds.
@export var flag_stun_duration: float = 0.5


func execute(caster: Unit, ctx: CastContext) -> void:
	VFX.ring(caster.get_parent(), ctx.point, radius_px * 0.4, radius_px, icon_color, 0.2)
	var crit_roll := HitContext.CritRoll.new()   # one crit roll per cast
	for u in filter_by_walls(ctx.point, AbilityUtil.in_circle(caster, ctx.point, radius_px)):
		var hit := HitPipeline.from_ability(caster, self, u, ctx)
		hit.crit_roll = crit_roll
		HitPipeline.resolve(hit)
		if ctx.has_flag(&"test_strike_stuns") and not hit.blocked and u.is_alive():
			u.apply_stun(flag_stun_duration, caster)


func draw_indicator(canvas: Node2D, caster: Unit, aim: Vector2) -> void:
	var range_px := Units.to_px(get_param(caster, &"cast_range"))
	var p := canvas.to_local(aim).limit_length(range_px)
	canvas.draw_arc(Vector2.ZERO, range_px, 0.0, TAU, 64, Color(1, 1, 1, 0.25), 1.0)
	canvas.draw_circle(p, radius_px, Color(icon_color, 0.2))
	canvas.draw_arc(p, radius_px, 0.0, TAU, 32, Color(icon_color, 0.8), 1.0)
