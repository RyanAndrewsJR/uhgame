extends Ability
## Korsavil v2 Q at 6 Demise stacks, the sweep (CHAMPIONS.md and ABILITIES.md,
## Korsavil v2; built in CHAMPIONS K5). A REPLACE variant of Blade Singer
## (variant_of korsavil_blade_singer): status_blade_singer_sweep (3.5 s, which
## his passive's script gives when his Demise reaches 6) holds the augment
## augment_blade_singer_sweep that makes it Q's ability. A REPLACE keeps the
## slot's cooldown, so the sweep needs Q off cooldown (Ryan).
## DIRECTION: at the effect it spends every Demise stack and its own window
## (so Q is the dagger again), lunges cast_range (300 u) toward the aim, then
## hits every enemy in a half circle of arc_radius in front of where he
## stopped, in sight of that spot, and every enemy along the lunge's path
## (his width, in sight of the path): 40 + 110% AD each, and the wound
## (status_blade_singer_wound, its conditional bonus with no conditions).
## Each enemy once. The `dash` tag refuses a press while he's rooted.
## K5b (Ryan, 2026-10-10: "a charged up skill shot"): a 0.6 s wind-up, rooted,
## aimed at the press; the half circle where the lunge will stop shows on the
## floor through it (a Telegraph that fills with the cast) and flashes as the
## effect starts. Its own cast_sound, not the dagger's.

## The lunge's speed (LoL units a second); its length is cast_range.
@export var lunge_speed: float = 2000.0
## The half circle in front of where he stops: its radius (LoL units) and
## half-angle (degrees; 90 = a half circle).
@export var arc_radius: float = 350.0
@export var arc_half_angle_deg: float = 90.0
## What the effect spends: his Demise stacks (status_demise's id) and the
## window that made Q the sweep (status_blade_singer_sweep's id). Ids, not the
## files: the window's file holds this ability through its REPLACE.
@export var demise_status_id: StringName = &"demise"
@export var window_status_id: StringName = &"blade_singer_sweep"


## The half circle where the lunge will stop, filling with the wind-up.
func on_cast_started(caster: Unit, ctx: CastContext) -> void:
	var area := get_effect_area(caster, ctx)
	if area.get("kind", &"none") != &"cone":
		return
	ctx.telegraph = Telegraph.cone(caster, area.origin, area.direction, area.range, area.half_angle,
		get_cast_time_for_part(ctx.part), Color(icon_color, 0.9))


func execute(caster: Unit, ctx: CastContext) -> void:
	if is_instance_valid(ctx.telegraph):
		ctx.telegraph.finish()
	_spend(caster)
	var dir := ctx.direction if ctx.direction.length() > 0.001 else Vector2.RIGHT
	var start := caster.global_position
	var dist := Units.to_px(get_effect_param(caster, &"cast_range", ctx))
	var speed := Units.to_px(get_effect_param(caster, &"lunge_speed", ctx))
	if dist >= 1.0 and speed > 0.0:
		caster.movement.dash(dir * speed, dist / speed, true)
		while caster.movement.is_displaced():
			await caster.get_tree().physics_frame
			if not is_instance_valid(caster):
				return
	if not caster.is_alive():
		return
	var end := caster.global_position
	var reach := Units.to_px(get_effect_param(caster, &"arc_radius", ctx))
	var half := deg_to_rad(arc_half_angle_deg)
	var side: float = caster.get("swing_side") if "swing_side" in caster else 1.0
	VFX.slash(caster.get_parent(), VFX.drawing_origin(caster), dir.angle(), 10.0, reach + 6.0, half,
		Color(icon_color, 0.85), 0.16, side)
	play_hit_feel(hit_units(caster, _swept(caster, start, end, dir, reach, half), ctx))


## Every Demise stack and the window go as the effect starts (Ryan: the sweep
## spends them), so the slot is the dagger again.
func _spend(caster: Unit) -> void:
	if caster.status_component == null:
		return
	caster.status_component.remove_status(demise_status_id)
	caster.status_component.remove_status(window_status_id)


## The half circle in front of `end` (in sight of `end`), then the lunge's
## path start -> end at his width (in sight of the path's nearest point), each
## enemy once.
func _swept(caster: Unit, start: Vector2, end: Vector2, dir: Vector2, reach: float, half: float) -> Array[Unit]:
	var out := filter_by_walls(end, AbilityUtil.in_cone(caster, end, dir, reach, half))
	if start.distance_to(end) < 1.0:
		return out
	for u in AbilityUtil.along_segment(caster, start, end, caster.get_gameplay_radius_px()):
		if out.has(u):
			continue
		var near := Geometry2D.get_closest_point_to_segment(u.global_position, start, end)
		if ignores_walls or WorldQuery.has_line_of_sight(near, u.global_position):
			out.append(u)
	return out


## The lunge's line to where he stops, and the half circle there.
func draw_indicator(canvas: Node2D, caster: Unit, aim: Vector2) -> void:
	var local := canvas.to_local(aim)
	var dir := local.normalized() if local.length() > 0.01 else Vector2.RIGHT
	var end := dir * Units.to_px(get_param(caster, &"cast_range"))
	var reach := Units.to_px(get_param(caster, &"arc_radius"))
	var half := deg_to_rad(arc_half_angle_deg)
	var pts := PackedVector2Array([end])
	for i in 17:
		pts.append(end + Vector2.from_angle(dir.angle() + lerpf(-half, half, i / 16.0)) * reach)
	canvas.draw_line(Vector2.ZERO, end, Color(icon_color, 0.8), 1.5)
	canvas.draw_colored_polygon(pts, Color(icon_color, 0.22))
	pts.append(end)
	canvas.draw_polyline(pts, Color(icon_color, 0.8), 1.0)


## The half circle where the lunge will stop if nothing stops it (ENEMIES_AI
## AI3: what an enemy sees coming at it).
func get_effect_area(caster: Unit, ctx: CastContext) -> Dictionary:
	if ctx == null or not is_instance_valid(caster):
		return {"kind": &"none"}
	var end := caster.global_position + ctx.direction * Units.to_px(get_param(caster, &"cast_range"))
	return {"kind": &"cone", "origin": end, "direction": ctx.direction, "range": Units.to_px(get_param(caster, &"arc_radius")),
		"half_angle": deg_to_rad(arc_half_angle_deg)}
