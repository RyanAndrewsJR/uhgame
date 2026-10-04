extends Ability
## Knight Q variant (ABILITIES AB-M, the augment playground): Cleave as a wave
## of force. The REPLACE augment augment_cleave_wave puts it on Q while
## equipped; variant_of knight_cleave, so Cleave's scoped modifiers (costs,
## items) reach it and the slot's cooldown carries over.
## Toolkit pieces: Projectile.fire() for the wave (one crit roll per cast,
## blocked by walls, passes through projectile_pierce enemies, its hits
## through from_ability()). The slash is its own VFX; the 3D view shows the
## wave as the projectile's view (its 2D crescent went in the 3D pivot's
## cleanup C3).
## TALENTS T3: it supports Cleave's two talent FLAGs (every variant supports
## its base's talent FLAGs), and its take on each is pure data, in the talents'
## scoped modifiers, which reach it through variant_of: Whirling Cleave adds
## projectile_count +7 and projectile_spread_deg +30 (8 waves 45 degrees apart,
## all around the Knight) at 75% range and 85% damage; Rending Cleave narrows
## projectile_width to 40% at 140% range and +35% damage. So the flags need no
## code here: Projectile.fire() reads every one of those params.

## The slash's half-angle, degrees (visual only; it was the 2D crescent's too).
@export var crescent_half_angle_deg: float = 55.0


func execute(caster: Unit, ctx: CastContext) -> void:
	var side: float = caster.get("swing_side") if "swing_side" in caster else 1.0
	VFX.slash(caster.get_parent(), VFX.drawing_origin(caster), ctx.direction.angle(), 8.0, 22.0,
		deg_to_rad(crescent_half_angle_deg), Color(1, 1, 1, 0.85), 0.12, side)
	Projectile.fire(caster, self, ctx, caster.global_position, ctx.direction)
