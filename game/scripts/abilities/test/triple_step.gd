extends Ability
## Test ability (ABILITIES AB5, champion "test"): a short step toward the aim,
## recast twice inside the window (recast_count 2). The last part steps
## farther. Used by abilities_test and, through SandboxAbilities.test_q, in
## the sandbox. Not part of any kit.

## Step speed in LoL units per second.
@export var step_speed: float = 1200.0
## The last part's distance, x cast_range.
@export var last_part_multiplier: float = 1.5
## Speed profile of the step (MOVEMENT.md F2). null = constant speed.
@export var step_curve: Curve


func execute(caster: Unit, ctx: CastContext) -> void:
	var dist := Units.to_px(get_param(caster, &"cast_range"))
	if ctx.part >= recast_count:
		dist *= last_part_multiplier
	var speed := Units.to_px(step_speed)
	caster.movement.dash(ctx.direction * speed, dist / speed, true, step_curve)
	VFX.ring(caster.get_parent(), caster.global_position, 4.0, 14.0 + 4.0 * ctx.part, icon_color, 0.2)
	while caster.movement.is_displaced():
		await caster.get_tree().physics_frame
		if not is_instance_valid(caster):
			return
