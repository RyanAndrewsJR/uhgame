extends Ability
## Knight Q - Cleave: a wide sword sweep in front of you that damages and
## knocks back every enemy in the cone.
## Toolkit pieces (ABILITIES AB11): AbilityUtil.in_cone() + filter_by_walls()
## for who's inside, hit_units() for the hits (one crit roll, the cast's
## context, the push from hit_knockback_px in the .tres), play_hit_feel()
## for the shake and hitstop (hit_shake / hit_hitstop). The slash VFX and the
## cone indicator are Cleave's own.

@export var cone_half_angle_deg: float = 60.0


func execute(caster: Unit, ctx: CastContext) -> void:
	var half := deg_to_rad(cone_half_angle_deg)
	var reach := Units.to_px(get_param(caster, &"cast_range"))
	var origin := caster.global_position
	var side: float = caster.get("swing_side") if "swing_side" in caster else 1.0
	VFX.slash(caster.get_parent(), caster.get_center(), ctx.direction.angle(), 10.0, reach + 6.0, half,
		Color(1, 1, 1, 0.85), 0.13, side)

	var targets := filter_by_walls(origin, AbilityUtil.in_cone(caster, origin, ctx.direction, reach, half))
	play_hit_feel(hit_units(caster, targets, ctx))


func draw_indicator(canvas: Node2D, caster: Unit, aim: Vector2) -> void:
	var local := canvas.to_local(aim)
	var dir := local.normalized() if local.length() > 0.01 else Vector2.RIGHT
	var reach := Units.to_px(get_param(caster, &"cast_range"))
	var half := deg_to_rad(cone_half_angle_deg)
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in 17:
		pts.append(Vector2.from_angle(dir.angle() + lerpf(-half, half, i / 16.0)) * reach)
	canvas.draw_colored_polygon(pts, Color(icon_color, 0.22))
	pts.append(Vector2.ZERO)
	canvas.draw_polyline(pts, Color(icon_color, 0.8), 1.0)
