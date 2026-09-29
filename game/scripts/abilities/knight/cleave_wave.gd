extends Ability
## Knight Q variant (ABILITIES AB-M, the augment playground): Cleave as a wave
## of force. The REPLACE augment augment_cleave_wave puts it on Q while
## equipped; variant_of knight_cleave, so Cleave's scoped modifiers (costs,
## items) reach it and the slot's cooldown carries over.
## Toolkit pieces: Projectile.fire() for the wave (one crit roll per cast,
## blocked by walls, passes through projectile_pierce enemies, its hits
## through from_ability()). The slash and the crescent drawn on the wave are
## its own VFX.

## The crescent's half-angle, degrees (visual only).
@export var crescent_half_angle_deg: float = 55.0


func execute(caster: Unit, ctx: CastContext) -> void:
	var side: float = caster.get("swing_side") if "swing_side" in caster else 1.0
	VFX.slash(caster.get_parent(), caster.get_center(), ctx.direction.angle(), 8.0, 22.0,
		deg_to_rad(crescent_half_angle_deg), Color(1, 1, 1, 0.85), 0.12, side)
	for p in Projectile.fire(caster, self, ctx, caster.global_position, ctx.direction):
		p.add_child(_crescent(p.half_width_px, p.direction))


## A crescent the width of the wave, its front on the projectile, facing its
## direction (visual only).
func _crescent(half_width_px: float, direction: Vector2) -> Polygon2D:
	var half := deg_to_rad(crescent_half_angle_deg)
	var outer := half_width_px / sin(half)
	var inner := outer * 0.7
	var points := PackedVector2Array()
	for i in 13:
		points.append(Vector2.from_angle(lerpf(-half, half, i / 12.0)) * outer)
	for i in 13:
		points.append(Vector2.from_angle(lerpf(half, -half, i / 12.0)) * inner)
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = Color(icon_color, 0.55)
	poly.rotation = direction.angle()
	poly.position = -direction * outer + Vector2(0, -Projectile.DRAW_HEIGHT_PX)
	return poly
