extends Ability
## Test ability (ABILITIES AB15, champion "test"): blinks to the aim point
## (POINT, clamped to cast_range) through MovementComponent.blink(): at once,
## onto the nearest walkable floor of the room, over walls unless
## through_walls is off. No damage. In both sandboxes on B (over walls) and
## Shift+B (test_q_blink_sight.tres: stops at walls), cast for free by
## SandboxAbilities. Not part of any kit.

## Off: it stops at the last free spot short of a wall in the way (ABILITIES,
## Blinks); fences, ledges and pits are still crossed.
@export var through_walls: bool = true


func execute(caster: Unit, ctx: CastContext) -> void:
	caster.movement.blink(ctx.point, through_walls)


## A blink is refused while rooted or stunned: the press fails with its cue.
func can_cast_custom(caster: Unit, _ctx: CastContext) -> bool:
	return not caster.movement.is_blink_blocked()


func get_custom_fail_text() -> String:
	return "Rooted"


## The range, and the unit's circle where the blink would really land
## (MovementComponent.get_blink_landing()).
func draw_indicator(canvas: Node2D, caster: Unit, aim: Vector2) -> void:
	var range_px := Units.to_px(get_param(caster, &"cast_range"))
	var point := caster.global_position + (aim - caster.global_position).limit_length(range_px)
	var landing := canvas.to_local(caster.movement.get_blink_landing(point, through_walls))
	var radius := caster.get_gameplay_radius_px()
	canvas.draw_arc(Vector2.ZERO, range_px, 0.0, TAU, 64, Color(1, 1, 1, 0.25), 1.0)
	canvas.draw_line(Vector2.ZERO, landing, Color(icon_color, 0.5), 1.0)
	canvas.draw_circle(landing, radius, Color(icon_color, 0.22))
	canvas.draw_arc(landing, radius, 0.0, TAU, 32, Color(icon_color, 0.8), 1.0)
