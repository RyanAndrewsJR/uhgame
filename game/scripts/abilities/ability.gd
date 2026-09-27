class_name Ability
extends Resource
## Base class for a champion ability (Q/W/E/R). Each ability is a script
## that extends this, plus a .tres in res://data/abilities/ so numbers can be
## tuned in the Inspector.
##
## Override execute() for what the ability does. It may `await` (dashes,
## delayed hits). The AbilityComponent handles cooldowns, cast time, locks,
## range checks and the auto-attack reset around it.

enum Targeting {
	SELF,       ## No aim, e.g. buffs.
	DIRECTION,  ## Aimed toward the cursor, e.g. skillshots and cones.
	POINT,      ## A spot on the ground, clamped to range, e.g. dashes.
	UNIT,       ## Must click an enemy; walks into range first if needed.
}

## Whether pressing this ability can cut short a basic attack swing
## (COMBAT.md). Otherwise the press waits for the swing to end.
enum SwingCancel {
	NEVER,      ## Waits for the whole swing.
	AFTER_HIT,  ## Cuts the recovery once the swing's hit has landed.
	ANYTIME,    ## Cuts the swing at once, even before its hit.
}

## <champion>_<ability>, no slot (CONVENTIONS.md), e.g. &"knight_lunge".
## Scoped modifiers target it as &"ability:knight_lunge" (STATS.md).
@export var id: StringName = &""
## Snake_case tags (&"area", &"movement"...). Scoped modifiers target
## every ability with a tag as &"tag:area" (STATS.md); hits carry them
## (COMBAT.md).
@export var tags: Array[StringName] = []
@export var display_name: String = "Ability"
@export_multiline var description: String = ""
@export var icon_color: Color = Color(0.8, 0.8, 0.8)

@export_group("Casting")
@export var targeting: Targeting = Targeting.DIRECTION
## Seconds.
@export var cooldown: float = 5.0
## Seconds rooted before the effect happens (LoL "cast time").
@export var cast_time: float = 0.25
## LoL units. DIRECTION/POINT: from the caster's center. UNIT: edge to edge.
@export var cast_range: float = 300.0
## Casting this lets your next auto-attack start immediately.
@export var resets_auto_attack: bool = true
## If false, you can keep walking during the cast time (at
## cast_move_speed_multiplier).
@export var roots_during_cast: bool = true
## Dashing during the cast time cancels the cast (and refunds the cooldown).
## Off: dash presses wait until the cast is done (MOVEMENT.md step 7).
@export var dash_cancelable: bool = false
## Walking speed during the cast when roots_during_cast is false (0.5 = half).
## Applied as a move_speed StatModifier, so the soft caps still apply after it:
## with the Knight, 0.75 is exact but 0.5 gives ~0.57x and 0 still walks.
## Ignored while cancel_on_move is on.
@export var cast_move_speed_multiplier: float = 1.0
## A movement key pressed after the cast starts cancels it during its cast
## time (cooldown refunded, like dash_cancelable). Keys already held when it
## started don't count. On: the cast roots for its cast time even if
## roots_during_cast is false (a channel: stand still, move to cancel).
@export var cancel_on_move: bool = false
## Can this cast cut short a basic attack swing? AFTER_HIT (default): only
## once the swing's hit has landed. Cutting a swing after its hit keeps the
## combo (the swing counts); cutting its windup resets it.
@export var cancels_swing: SwingCancel = SwingCancel.AFTER_HIT

@export_group("Damage")
@export var base_damage: float = 0.0
## Fraction of the caster's attack damage added to base_damage.
@export var ad_ratio: float = 0.0
## PHYSICAL (armor), MAGIC (magic_resist) or TRUE (ignores both). COMBAT.md.
@export var damage_type: HitContext.DamageType = HitContext.DamageType.PHYSICAL
## Scales on-hit chances and effects (COMBAT C8). 1.0 = full; lower it for
## multi-hit or area abilities.
@export var proc_coefficient: float = 1.0
## Off (default): walls block this ability's hits, and a UNIT ability needs
## line of sight to its target to start the cast (it walks around until it
## has it). On: it hits through walls (e.g. a meteor shower). COMBAT C7.
@export var ignores_walls: bool = false


## The units among `units` this ability can hit from `from`: all of them if
## it ignores walls, otherwise only those in line of sight (COMBAT C7).
func filter_by_walls(from: Vector2, units: Array[Unit]) -> Array[Unit]:
	return units if ignores_walls else AbilityUtil.in_sight(from, units)


## True if walls don't stop this ability from reaching `target` from `from`.
func can_reach_through_walls(from: Vector2, target: Unit) -> bool:
	return ignores_walls or WorldQuery.has_line_of_sight(from, target.global_position)


## A number of this ability (an @export param like &"cooldown",
## &"cast_range", &"base_damage") after the caster's scoped modifiers
## (items, buffs; STATS.md). Without a caster: the plain value.
func get_param(caster: Unit, param: StringName) -> float:
	if is_instance_valid(caster) and caster.stats_component != null:
		return caster.stats_component.get_ability_param(self, param)
	return float(get(param))


## The scopes a modifier can use to reach this ability: &"ability:<id>" and
## &"tag:<tag>" for each tag.
func get_modifier_scopes() -> Array[StringName]:
	var scopes: Array[StringName] = [StringName("ability:" + id)]
	for t in tags:
		scopes.append(StringName("tag:" + t))
	return scopes


## Damage this ability deals with the caster's current stats (base_damage
## and ad_ratio after scoped modifiers, then attack_damage).
func get_damage(caster: Unit) -> float:
	return get_param(caster, &"base_damage") \
		+ get_param(caster, &"ad_ratio") * caster.stats_component.get_stat(&"attack_damage")


## What the ability does. Override in each ability script.
func execute(_caster: Unit, _ctx: CastContext) -> void:
	pass


## Called when the cast starts, before the cast time. Override to show a
## telegraph (set ctx.telegraph so a cancelled or interrupted cast removes it).
func on_cast_started(_caster: Unit, _ctx: CastContext) -> void:
	pass


## Draws the aiming indicator. `canvas` is the caster (local coordinates),
## `aim` is the cursor in world space. Override for custom shapes.
func draw_indicator(canvas: Node2D, caster: Unit, aim: Vector2) -> void:
	var range_px := Units.to_px(get_param(caster, &"cast_range"))
	var faint := Color(1, 1, 1, 0.25)
	var fill := Color(icon_color, 0.22)
	var edge := Color(icon_color, 0.8)
	var local_aim := canvas.to_local(aim)
	match targeting:
		Targeting.SELF:
			pass
		Targeting.DIRECTION:
			var dir := local_aim.normalized() if local_aim.length() > 0.01 else Vector2.RIGHT
			var end := dir * range_px
			var side := dir.orthogonal() * 10.0
			canvas.draw_colored_polygon(PackedVector2Array([side, end + side, end - side, -side]), fill)
			canvas.draw_polyline(PackedVector2Array([side, end + side, end - side, -side, side]), edge, 1.0)
		Targeting.POINT:
			var p := local_aim.limit_length(range_px)
			canvas.draw_arc(Vector2.ZERO, range_px, 0.0, TAU, 64, faint, 1.0)
			canvas.draw_line(Vector2.ZERO, p, edge, 1.5)
			canvas.draw_circle(p, 6.0, fill)
			canvas.draw_arc(p, 6.0, 0.0, TAU, 16, edge, 1.0)
		Targeting.UNIT:
			canvas.draw_arc(Vector2.ZERO, range_px + caster.get_gameplay_radius_px(), 0.0, TAU, 64, edge, 1.0)
