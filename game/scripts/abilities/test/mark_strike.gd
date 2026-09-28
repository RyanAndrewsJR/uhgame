extends Ability
## Test ability (ABILITIES AB12, champion "test"): a two-part recast in the
## Lee Sin Q style. Part 0 strikes a circle at the aim point and marks every
## enemy it hits (status_test_mark, through the hit). The recast (part 1)
## only works while a marked enemy is within range and part 0 hit something
## (recast_conditions: ENEMIES_IN_RANGE tagged test_mark, LAST_PART_HIT); it
## strikes the marked enemy nearest the aim and removes its mark. Used by
## abilities_test and, through SandboxAbilities.test_q, in the sandbox. Not
## part of any kit.

const STATUS_MARK: StatusEffect = preload("res://data/statuses/status_test_mark.tres")

## Radius of part 0's circle, px.
@export var radius_px: float = 40.0


func execute(caster: Unit, ctx: CastContext) -> void:
	if ctx.part == 0:
		VFX.ring(caster.get_parent(), ctx.point, radius_px * 0.4, radius_px, icon_color, 0.2)
		var marks: Array[StatusEffect] = [STATUS_MARK]
		hit_units(caster, filter_by_walls(ctx.point, AbilityUtil.in_circle(caster, ctx.point, radius_px)), ctx, marks)
		return
	var marked := _nearest_marked(caster, ctx.point, Units.to_px(get_effect_param(caster, &"cast_range", ctx)))
	if marked == null:
		return
	var targets: Array[Unit] = [marked]
	hit_units(caster, filter_by_walls(caster.global_position, targets), ctx)
	VFX.impact(marked.get_parent(), marked.global_position, Color(icon_color, 0.9), 40.0, 0.2)
	if is_instance_valid(marked) and marked.status_component != null:
		marked.status_component.remove_status(STATUS_MARK.id)


## The marked enemy nearest `point` within `range_px` (edge distance) of the caster.
func _nearest_marked(caster: Unit, point: Vector2, range_px: float) -> Unit:
	var best: Unit = null
	var best_d := INF
	for u in AbilityUtil.enemies_of(caster):
		if u.status_component == null or u.status_component.get_tag_stacks(&"test_mark") <= 0:
			continue
		if caster.edge_distance_to(u) > range_px:
			continue
		var d := point.distance_to(u.global_position)
		if d < best_d:
			best = u
			best_d = d
	return best


func draw_indicator(canvas: Node2D, caster: Unit, aim: Vector2) -> void:
	var range_px := Units.to_px(get_param(caster, &"cast_range"))
	var p := canvas.to_local(aim).limit_length(range_px)
	canvas.draw_arc(Vector2.ZERO, range_px, 0.0, TAU, 64, Color(1, 1, 1, 0.25), 1.0)
	canvas.draw_circle(p, radius_px, Color(icon_color, 0.2))
	canvas.draw_arc(p, radius_px, 0.0, TAU, 32, Color(icon_color, 0.8), 1.0)
