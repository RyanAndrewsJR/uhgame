extends "res://scripts/abilities/slime/slam.gd"
## The enemy ability library (ENEMIES_AI AI3d, Kits): Shockwave. The slam's
## circle centered on the caster itself (SELF): it fills under its own feet
## over the cast time, then bursts, and everyone still inside is hit and
## knocked away from it (knockback_px). A close `damage` use, and its crowded
## answer (a `cc` use, read in AI3b). Its AI plan needs its target inside the
## circle; walking out of it answers it.


func get_ai_plan(caster: Unit, situation: SituationContext) -> CastPlan:
	if situation == null or not is_instance_valid(caster) or not is_instance_valid(situation.target_unit):
		return null
	var target := situation.target_unit
	var reach := radius_px * (1.0 - enemy_hit_forgiveness) + target.get_gameplay_radius_px()
	if caster.global_position.distance_to(target.global_position) > reach:
		return null
	var plan := super.get_ai_plan(caster, situation)
	if plan != null:
		plan.reason = "its target inside the circle"
	return plan


## The circle around where it stands (the default reads a SELF cast as none).
func get_effect_area(caster: Unit, ctx: CastContext) -> Dictionary:
	if ctx == null or not is_instance_valid(caster):
		return {"kind": &"none"}
	return {"kind": &"circle", "center": caster.global_position, "radius": radius_px}
