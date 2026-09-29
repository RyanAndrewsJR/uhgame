extends Ability
## Enemy test ability (ABILITIES AB13, champion "test"): a wall across the
## player's escape path. The AI lays the line across the caster -> target
## direction, centered on the target (get_ai_vector()); a line telegraph
## fills over the cast time, then everyone still on the line (in sight of its
## start) takes one hit. Put on the sandbox elite's W by
## SandboxAbilities.test_elite_w. Not part of any kit.

@export var telegraph_color: Color = Telegraph.THREAT_COLOR


func on_cast_started(caster: Unit, ctx: CastContext) -> void:
	var width := Units.to_px(get_effect_param(caster, &"vector_width", ctx))
	ctx.telegraph = Telegraph.line(caster, ctx.vector_start, ctx.vector_end, width, cast_time, telegraph_color)


func execute(caster: Unit, ctx: CastContext) -> void:
	if is_instance_valid(ctx.telegraph):
		ctx.telegraph.finish()
	var half := Units.to_px(get_effect_param(caster, &"vector_width", ctx)) * 0.5
	var units := filter_by_walls(ctx.vector_start, AbilityUtil.along_segment(caster, ctx.vector_start, ctx.vector_end, half))
	play_hit_feel(hit_units(caster, units, ctx))


## Across the caster -> target direction, centered on the target. The start
## is clamped to cast_range as at a press, so near the edge of its range the
## wall sits a little toward the caster.
func get_ai_vector(caster: Unit, target: Unit) -> Dictionary:
	var to_target := target.global_position - caster.global_position
	var across := to_target.orthogonal().normalized() if to_target.length() > 0.01 else Vector2.DOWN
	var half_length := Units.to_px(get_param(caster, &"vector_length")) * 0.5
	return {"start": target.global_position - across * half_length, "direction": across}
