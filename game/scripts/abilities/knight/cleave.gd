extends Ability
## Knight Q - Cleave: a wide sword sweep in front of you that damages and
## knocks back every enemy in the cone.
## Toolkit pieces (ABILITIES AB11): AbilityUtil.in_cone() + filter_by_walls()
## for who's inside, hit_units() for the hits (one crit roll, the cast's
## context, the push from hit_knockback_px in the .tres), play_hit_feel()
## for the shake and hitstop (hit_shake / hit_hitstop). The slash VFX and the
## cone indicator are Cleave's own.
## TALENTS T3, two shape FLAGs (supported_flags in the .tres). Their numbers
## (reach, damage, knockback) are the talents' own scoped modifiers, so the
## tooltip and the indicator show them; the flag only changes the shape:
## - &"cleave_whirl" (Whirling Cleave): a circle all around the Knight, radius
##   = the reach, instead of the aimed cone.
## - &"cleave_rend" (Rending Cleave): the cone narrows to
##   flag_rend_half_angle_deg.

@export var cone_half_angle_deg: float = 60.0
## With &"cleave_rend": the narrow cone's half-angle, degrees.
@export var flag_rend_half_angle_deg: float = 25.0


func execute(caster: Unit, ctx: CastContext) -> void:
	var reach := Units.to_px(get_param(caster, &"cast_range"))
	var origin := caster.global_position
	var targets: Array[Unit]
	if ctx.has_flag(&"cleave_whirl"):
		VFX.ring(caster.get_parent(), origin, reach * 0.4, reach + 4.0, Color(1, 1, 1, 0.85), 0.18, 3.0)
		targets = filter_by_walls(origin, AbilityUtil.in_circle(caster, origin, reach))
	else:
		var half := deg_to_rad(_half_angle_deg(ctx.flags))
		var side: float = caster.get("swing_side") if "swing_side" in caster else 1.0
		VFX.slash(caster.get_parent(), VFX.drawing_origin(caster), ctx.direction.angle(), 10.0, reach + 6.0, half,
			Color(1, 1, 1, 0.85), 0.13, side)
		targets = filter_by_walls(origin, AbilityUtil.in_cone(caster, origin, ctx.direction, reach, half))
	play_hit_feel(hit_units(caster, targets, ctx))


func draw_indicator(canvas: Node2D, caster: Unit, aim: Vector2) -> void:
	var reach := Units.to_px(get_param(caster, &"cast_range"))
	var flags: Array[StringName] = caster.abilities.get_flags(self) if caster.abilities != null else []
	if flags.has(&"cleave_whirl"):
		canvas.draw_circle(Vector2.ZERO, reach, Color(icon_color, 0.22))
		canvas.draw_arc(Vector2.ZERO, reach, 0.0, TAU, 48, Color(icon_color, 0.8), 1.0)
		return
	var local := canvas.to_local(aim)
	var dir := local.normalized() if local.length() > 0.01 else Vector2.RIGHT
	var half := deg_to_rad(_half_angle_deg(flags))
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in 17:
		pts.append(Vector2.from_angle(dir.angle() + lerpf(-half, half, i / 16.0)) * reach)
	canvas.draw_colored_polygon(pts, Color(icon_color, 0.22))
	pts.append(Vector2.ZERO)
	canvas.draw_polyline(pts, Color(icon_color, 0.8), 1.0)


## The cone it will sweep, or the circle all around with Whirling Cleave
## (ENEMIES_AI AI3: what an enemy sees coming at it).
func get_effect_area(caster: Unit, ctx: CastContext) -> Dictionary:
	if ctx == null or not is_instance_valid(caster):
		return {"kind": &"none"}
	var reach := Units.to_px(get_param(caster, &"cast_range"))
	if ctx.has_flag(&"cleave_whirl"):
		return {"kind": &"circle", "center": caster.global_position, "radius": reach}
	return {"kind": &"cone", "origin": caster.global_position, "direction": ctx.direction, "range": reach,
		"half_angle": deg_to_rad(_half_angle_deg(ctx.flags))}


func _half_angle_deg(flags: Array[StringName]) -> float:
	return flag_rend_half_angle_deg if flags.has(&"cleave_rend") else cone_half_angle_deg
