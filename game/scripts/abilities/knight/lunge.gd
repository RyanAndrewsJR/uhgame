extends Ability
## Knight E - Lunge: dash toward the target spot, passing through units and
## damaging every enemy you cut through.

## Dash speed in LoL units per second.
@export var dash_speed: float = 1400.0
## Width of the damaging path in LoL units.
@export var hit_width: float = 80.0
## Speed profile of the lunge (MOVEMENT.md F2). null = constant speed.
## The distance and the hit path don't depend on it.
@export var dash_curve: Curve


func execute(caster: Unit, ctx: CastContext) -> void:
	var start := caster.global_position
	var offset := ctx.point - start
	var dist := offset.length()
	if dist < 1.0:
		return
	var speed := Units.to_px(dash_speed)
	var duration := dist / speed
	caster.movement.dash(offset / dist * speed, duration, true, dash_curve)

	# Afterimage trail while dashing.
	var frame := 0
	while caster.movement.is_displaced():
		if frame % 2 == 0:
			VFX.afterimage(caster, Color(icon_color, 0.45))
		frame += 1
		await caster.get_tree().physics_frame
		if not is_instance_valid(caster):
			return

	var end := caster.global_position
	var dmg := get_damage(caster)
	var hits := AbilityUtil.along_segment(caster, start, end, Units.to_px(hit_width) * 0.5)
	for u in hits:
		u.take_damage(dmg, caster, true)
		VFX.impact(u.get_parent(), u.global_position, Color(icon_color, 0.8), 36.0, 0.2)
	if not hits.is_empty():
		GameFeel.shake(2.5)
