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
## once the swing's hit has landed. Cutting a swing resets the combo.
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


## Damage this ability deals with the caster's current stats.
func get_damage(caster: Unit) -> float:
	return base_damage + ad_ratio * caster.stats_component.get_stat(&"attack_damage")


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
	var range_px := Units.to_px(cast_range)
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
