extends Ability
## Test ability (ABILITIES AB13, champion "test"): a Viktor E-style line.
## Press to drop the start point, drag to aim, release: after the release
## windup every enemy along the line (vector_width wide) in sight of the start
## point takes one hit through hit_units(). A tap lays the line from the
## caster through the start point. Used by abilities_test and, through
## SandboxAbilities.test_q, in the sandbox. Not part of any kit.


func execute(caster: Unit, ctx: CastContext) -> void:
	var half := Units.to_px(get_effect_param(caster, &"vector_width", ctx)) * 0.5
	_flash(caster, ctx.vector_start, ctx.vector_end, half * 2.0)
	var units := filter_by_walls(ctx.vector_start, AbilityUtil.along_segment(caster, ctx.vector_start, ctx.vector_end, half))
	var hits := hit_units(caster, units, ctx)
	for h in hits:
		if not h.blocked and is_instance_valid(h.target):
			VFX.impact(h.target.get_parent(), h.target.global_position, Color(icon_color, 0.8), 30.0, 0.2)
	play_hit_feel(hits)


## A band along the line that fades out (visuals only).
func _flash(caster: Unit, from: Vector2, to: Vector2, width: float) -> void:
	var line := Line2D.new()
	line.width = width
	line.default_color = Color(icon_color, 0.7)
	line.add_point(from)
	line.add_point(to)
	line.visibility_layer |= FloorOverlay.DRAWING_VISIBILITY_BIT   # a floor drawing in 3D (the cleanup's C2)
	caster.get_parent().add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.25)
	tween.tween_callback(line.queue_free)
