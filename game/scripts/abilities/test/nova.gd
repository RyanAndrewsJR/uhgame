extends Ability
## Test ability (ABILITIES AB12, champion "test"): after its cast time, hits
## every enemy in a circle around the caster. The AB12 data in its .tres:
## - cast_conditions: only while the caster has a status tagged test_focus
##   (status_test_focus.tres), with a fail text;
## - a conditional bonus: +50% radius while 2 or more enemies are within
##   300 units, checked at the effect;
## - base_damage scales by the named input self_missing_health (half at full
##   health, full at 0).
## Reads its params with get_effect_param() (CONVENTIONS.md). Used by
## abilities_test and, through SandboxAbilities.test_q, in the sandbox. Not
## part of any kit.

## Circle radius around the caster, LoL units (a param: scoped modifiers and
## conditional bonuses change it).
@export var radius: float = 200.0


func execute(caster: Unit, ctx: CastContext) -> void:
	var r := Units.to_px(get_effect_param(caster, &"radius", ctx))
	var center := caster.global_position
	VFX.ring(caster.get_parent(), center, r * 0.4, r, icon_color, 0.2)
	hit_units(caster, filter_by_walls(center, AbilityUtil.in_circle(caster, center, r)), ctx)


## The circle at its plain radius (no bonus; the tooltip says when it grows).
func draw_indicator(canvas: Node2D, caster: Unit, _aim: Vector2) -> void:
	var r := Units.to_px(get_param(caster, &"radius"))
	canvas.draw_circle(Vector2.ZERO, r, Color(icon_color, 0.2))
	canvas.draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(icon_color, 0.8), 1.0)
