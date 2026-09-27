extends Ability
## Test ability (ABILITIES AB6, champion "test"): a Xerath-style line. Hold to
## charge (the line's range and damage grow, charge_scalings in the .tres),
## release to fire along the aim. Hits every enemy on the line in sight of
## the caster, one crit roll. Used by abilities_test and, through
## SandboxAbilities.test_q, in the sandbox. Not part of any kit.

## Width of the line in LoL units.
@export var line_width: float = 80.0


func execute(caster: Unit, ctx: CastContext) -> void:
	var origin := caster.global_position
	var reach := Units.to_px(get_charged_param(caster, &"cast_range", ctx.charge))
	var end := origin + ctx.direction * reach
	_flash(caster, origin, end)
	var hits := filter_by_walls(origin, AbilityUtil.along_segment(caster, origin, end, Units.to_px(line_width) * 0.5))
	var crit_roll := HitContext.CritRoll.new()   # one crit roll per cast
	for u in hits:
		var hit := HitPipeline.from_ability(caster, self, u, ctx)   # the charge sets the damage
		hit.crit_roll = crit_roll
		HitPipeline.resolve(hit)
		VFX.impact(u.get_parent(), u.global_position, Color(icon_color, 0.8), 30.0, 0.2)
	if not hits.is_empty():
		GameFeel.shake(1.5 + 2.0 * ctx.charge)


## A beam that fades out (visuals only).
func _flash(caster: Unit, from: Vector2, to: Vector2) -> void:
	var line := Line2D.new()
	line.width = Units.to_px(line_width) * 0.5
	line.default_color = Color(icon_color, 0.8)
	line.add_point(from)
	line.add_point(to)
	caster.get_parent().add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.2)
	tween.tween_callback(line.queue_free)
