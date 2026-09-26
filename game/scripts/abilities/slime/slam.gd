extends Ability
## Elite slime Q - Slam: marks a circle on the floor where the target stood,
## fills it over the cast time (the telegraph), then slams it. Everyone still
## inside takes a big hit and is pushed away. Walking or dashing out avoids
## it (COMBAT.md, Enemies: elite band 12-20%, telegraph 0.6-0.9 s).

## Radius of the telegraphed circle, px.
@export var radius_px: float = 40.0
## Enemy attack hitboxes are this much smaller than they look (COMBAT.md).
@export_range(0.0, 0.2) var enemy_hit_forgiveness: float = 0.10
@export var knockback_px: float = 20.0
@export var telegraph_color: Color = Telegraph.THREAT_COLOR
@export var hitstop: float = 0.06
@export var shake: float = 3.0


func on_cast_started(caster: Unit, ctx: CastContext) -> void:
	ctx.telegraph = Telegraph.circle(caster, ctx.point, radius_px, cast_time, telegraph_color)


func execute(caster: Unit, ctx: CastContext) -> void:
	if is_instance_valid(ctx.telegraph):
		ctx.telegraph.finish()
	var parent := caster.get_parent()
	VFX.ring(parent, ctx.point, radius_px * 0.4, radius_px, telegraph_color, 0.25, 3.0)
	var landed := false
	var crit_roll := HitContext.CritRoll.new()   # one crit roll per cast
	# Walls block it: someone on the far side of a wall inside the circle is safe.
	for u in filter_by_walls(ctx.point, AbilityUtil.in_circle(caster, ctx.point, radius_px * (1.0 - enemy_hit_forgiveness))):
		var hit := HitPipeline.from_ability(caster, self, u)
		hit.knockback_px = knockback_px
		hit.knockback_from = caster.global_position
		hit.crit_roll = crit_roll
		HitPipeline.resolve(hit)
		landed = landed or not hit.blocked
	if landed:
		GameFeel.hitstop(hitstop)
		GameFeel.shake(shake)


## The aiming indicator (unused by enemies; kept for a player version).
func draw_indicator(canvas: Node2D, _caster: Unit, aim: Vector2) -> void:
	var p := canvas.to_local(aim)
	canvas.draw_arc(p, radius_px, 0.0, TAU, 48, Color(telegraph_color, 0.8), 1.0)
