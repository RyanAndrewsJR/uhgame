extends Ability
## Test ability (3D pivot P9, champion "test"): a short cone in front of the
## caster that knocks every enemy in it up (status_airborne, for
## airborne_duration) and back hit_knockback_px. A knock-back-and-up is one
## hit carrying both (3D.md, Airborne): while airborne and pushed, an enemy
## crosses fences and cliffs and lands on free floor. Melee, so it can't
## reach a perched enemy from below. Used by view_test and, through
## SandboxAbilities.test_w, in the 3D sandbox. Not part of any kit.

const STATUS_AIRBORNE: StatusEffect = preload("res://data/statuses/status_airborne.tres")

## How long the knock-up lasts, seconds (it comes from the hit; tenacity
## doesn't shorten it).
@export var airborne_duration: float = 0.75
## The cone's half-angle, degrees.
@export var cone_half_angle_deg: float = 50.0


func execute(caster: Unit, ctx: CastContext) -> void:
	var reach := Units.to_px(get_effect_param(caster, &"cast_range", ctx))
	var origin := caster.global_position
	var half := deg_to_rad(cone_half_angle_deg)
	VFX.slash(caster.get_parent(), caster.get_center(), ctx.direction.angle(), 8.0, reach, half, Color(icon_color, 0.85), 0.14)
	var airborne: StatusEffect = STATUS_AIRBORNE.duplicate()
	airborne.duration = airborne_duration
	var targets := filter_by_walls(origin, AbilityUtil.in_cone(caster, origin, ctx.direction, reach, half))
	play_hit_feel(hit_units(caster, targets, ctx, [airborne] as Array[StatusEffect]))


func draw_indicator(canvas: Node2D, caster: Unit, aim: Vector2) -> void:
	var reach := Units.to_px(get_param(caster, &"cast_range"))
	var local := canvas.to_local(aim)
	var dir := local.normalized() if local.length() > 0.01 else Vector2.RIGHT
	var half := deg_to_rad(cone_half_angle_deg)
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in 17:
		pts.append(Vector2.from_angle(dir.angle() + lerpf(-half, half, i / 16.0)) * reach)
	canvas.draw_colored_polygon(pts, Color(icon_color, 0.22))
	pts.append(Vector2.ZERO)
	canvas.draw_polyline(pts, Color(icon_color, 0.8), 1.0)
