extends Ability
## The enemy ability library (ENEMIES_AI AI3d, Kits): Cleave arc. Through its
## cast time a cone fills in front of the caster, toward where its target
## stood (the telegraph; it can't turn while it casts), then it sweeps: every
## champion still inside takes the hit and the ability's small push
## (hit_knockback_px). The cone reaches cast_range from the caster's center.
## Stepping out of it, or behind the caster, avoids it; walls block it. A
## `damage` use, and a `zone` use with two champions in it (its .tres).

## Half the cone's angle, degrees (60 = a 120° cone).
@export_range(5.0, 180.0) var half_angle_deg: float = 60.0
## Enemy attack hitboxes are this much smaller than they look (COMBAT.md).
@export_range(0.0, 0.2) var enemy_hit_forgiveness: float = 0.10
@export var telegraph_color: Color = Telegraph.THREAT_COLOR


func on_cast_started(caster: Unit, ctx: CastContext) -> void:
	ctx.telegraph = Telegraph.cone(caster, caster.global_position, ctx.direction, _reach_px(caster),
		deg_to_rad(half_angle_deg), cast_time, telegraph_color)


func execute(caster: Unit, ctx: CastContext) -> void:
	if is_instance_valid(ctx.telegraph):
		ctx.telegraph.finish()
	var origin := caster.global_position
	var reach := _reach_px(caster)
	var half := deg_to_rad(half_angle_deg)
	VFX.slash(caster.get_parent(), VFX.drawing_origin(caster), ctx.direction.angle(), reach * 0.3, reach, half, Color(telegraph_color, 0.8))
	var inside := AbilityUtil.in_cone(caster, origin, ctx.direction, reach * (1.0 - enemy_hit_forgiveness), half)
	play_hit_feel(hit_units(caster, filter_by_walls(origin, inside), ctx))


## The cone from where it stands, along the cast's direction.
func get_effect_area(caster: Unit, ctx: CastContext) -> Dictionary:
	if ctx == null or not is_instance_valid(caster):
		return {"kind": &"none"}
	return {"kind": &"cone", "origin": caster.global_position, "direction": ctx.direction,
		"range": _reach_px(caster), "half_angle": deg_to_rad(half_angle_deg)}


func _reach_px(caster: Unit) -> float:
	return Units.to_px(get_param(caster, &"cast_range"))


## The aiming indicator (unused by enemies; kept for a player version).
func draw_indicator(canvas: Node2D, caster: Unit, aim: Vector2) -> void:
	var reach := _reach_px(caster)
	var dir := (aim - caster.global_position).angle()
	var half := deg_to_rad(half_angle_deg)
	canvas.draw_arc(Vector2.ZERO, reach, dir - half, dir + half, 24, Color(telegraph_color, 0.8), 1.0)
	canvas.draw_line(Vector2.ZERO, Vector2.from_angle(dir - half) * reach, Color(telegraph_color, 0.8), 1.0)
	canvas.draw_line(Vector2.ZERO, Vector2.from_angle(dir + half) * reach, Color(telegraph_color, 0.8), 1.0)
