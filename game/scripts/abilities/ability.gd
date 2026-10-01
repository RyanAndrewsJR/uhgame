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

## What a CHARGE_UP ability does once it has been held at full charge for
## overhold_time.
enum Overhold {
	FIRE,           ## Fires at the cursor, as if released.
	CANCEL_REFUND,  ## Cancels with a full refund (cost; the cooldown never started).
}

## Whether pressing this ability can cut short a basic attack swing
## (COMBAT.md). Otherwise the press waits for the swing to end.
enum SwingCancel {
	NEVER,      ## Waits for the whole swing.
	AFTER_HIT,  ## Cuts the recovery once the swing's hit has landed.
	ANYTIME,    ## Cuts the swing at once, even before its hit.
}

## How the ability's key works (ABILITIES.md, Cast styles).
enum CastStyle {
	INSTANT,    ## Press to cast after the cast time (QUICK or hold-to-aim, the player's cast mode).
	CHARGE_UP,  ## Hold to charge, release to fire (ABILITIES AB6).
	CHANNEL,    ## Cast on press; stand still through the cast time, a new move press cancels it.
	VECTOR,     ## Press to drop a start point, drag to aim, release to cast along a line (ABILITIES AB13).
}

## The role tags (Diablo 4's categories, "basic" renamed): every ability has
## exactly one (ABILITIES.md, Standard tags).
const ROLE_TAGS: Array[StringName] = [&"generator", &"core", &"defensive", &"mobility", &"ultimate"]
## Tooltip damage colors come from the damage numbers' style (COMBAT C6).
## Loaded when needed (not preloaded) so Ability doesn't pull the style's
## script into its own compile.
const DAMAGE_NUMBER_STYLE_PATH := "res://data/damage_number_styles/damage_number_style_default.tres"

## <champion>_<ability>, no slot (CONVENTIONS.md), e.g. &"knight_lunge".
## Scoped modifiers target it as &"ability:knight_lunge" (STATS.md).
@export var id: StringName = &""
## Snake_case tags (&"core", &"area", &"movement"...): one role tag plus
## shape, style and element tags (CONVENTIONS.md, Standard ability tags).
## Scoped modifiers target every ability with a tag as &"tag:area"
## (STATS.md); hits carry them (COMBAT.md).
@export var tags: Array[StringName] = []
@export var display_name: String = "Ability"
## FLAG augments this ability's script checks (CastContext.has_flag()), e.g.
## &"lunge_stuns". An exact-scope (ability:<id>) FLAG it doesn't list is an
## error; a tag-scoped one is simply ignored here. ABILITIES AB8.
@export var supported_flags: Array[StringName] = []
## For a REPLACE variant: the id of the ability it replaces. Its scopes then
## include &"ability:<variant_of>", so modifiers on the base reach it.
@export var variant_of: StringName = &""
## The tooltip template (get_tooltip()): plain text with placeholders such
## as {damage}, {base_damage}, {ratios}, {cooldown}, {cost}, {charges}, {range}, {cast_time},
## or any param by name ({stun_duration}); {param%} shows it as a percent
## (0.35 -> 35%). Text without placeholders is shown as it is.
@export_multiline var description: String = ""
@export var icon_color: Color = Color(0.8, 0.8, 0.8)

@export_group("Casting")
## INSTANT (default), CHARGE_UP, CHANNEL or VECTOR. CHANNEL works exactly
## like cancel_on_move on (a cast that roots and is cancelled by a new move
## press); the cast mode setting (QUICK / hold to aim) only applies to
## INSTANT. VECTOR needs targeting POINT (AB13).
@export var cast_style: CastStyle = CastStyle.INSTANT
@export var targeting: Targeting = Targeting.DIRECTION
## Seconds.
@export var cooldown: float = 5.0
## Mana / energy / fury paid at cast start (a scoped param, so items can
## change it). Refunded if the cast is cancelled or interrupted before its
## effect. A unit without a resource pool pays nothing (ABILITIES.md, Costs).
@export var resource_cost: float = 0.0
## Stored casts (a scoped param, so items can add charges; min 1). Each
## charge recharges over the cooldown, one at a time. Not the same as a
## charge-up (holding the key). ABILITIES.md, Charges and recasts.
@export var max_charges: int = 1
## Extra parts after the first (0 = none): pressing the slot again inside
## recast_window casts the next part (CastContext.part). The cooldown starts
## when the last part is used or the window runs out (League style).
@export var recast_count: int = 0
## Seconds to press for the next part (a scoped param). Restarts after each
## part and doesn't run while a part is being cast.
@export var recast_window: float = 3.0
## Cost of every part after the first (a scoped param); the first part costs
## resource_cost.
@export var recast_resource_cost: float = 0.0

@export_group("Charge-up")
## CHARGE_UP only: seconds of holding to reach full charge (a scoped param).
@export var charge_time: float = 1.5
## CHARGE_UP only: seconds the key may stay held after full charge before
## the overhold behavior (a scoped param).
@export var overhold_time: float = 2.0
@export var overhold: Overhold = Overhold.FIRE
## The params that grow with the charge; the others are always full.
@export var charge_scalings: Array[ChargeScaling] = []
## A loop on the caster while charging (AUDIO.md). null = silent.
@export var charge_sound: SoundEvent
@export_group("Casting")
## Seconds rooted before the effect happens (LoL "cast time").
@export var cast_time: float = 0.25
## LoL units. DIRECTION/POINT: from the caster's center. UNIT: edge to edge.
## VECTOR: the start point's range (AB13).
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
## with the 375 Knight every multiplier below 1 is softened by the low cap
## (0.75 gives 319 u, 0.85x; 0.5 gives 272 u, 0.73x; 0 still walks at 178.5 u).
## Ignored for a channel (cancel_on_move or cast_style CHANNEL).
@export var cast_move_speed_multiplier: float = 1.0
## A movement key pressed after the cast starts cancels it during its cast
## time (cooldown refunded, like dash_cancelable). Keys already held when it
## started don't count. On: the cast roots for its cast time even if
## roots_during_cast is false (a channel: stand still, move to cancel).
## cast_style CHANNEL does the same; this flag is kept and still works.
@export var cancel_on_move: bool = false
## Can this cast cut short a basic attack swing? AFTER_HIT (default): only
## once the swing's hit has landed. Cutting a swing after its hit keeps the
## combo (the swing counts); cutting its windup resets it.
@export var cancels_swing: SwingCancel = SwingCancel.AFTER_HIT

@export_group("Damage")
@export var base_damage: float = 0.0
## Fraction of the caster's attack damage added to base_damage.
@export var ad_ratio: float = 0.0
## Fraction of the caster's ability power added to base_damage.
@export var ap_ratio: float = 0.0
## Every other ratio (bonus AD, % of the target's missing health...), one
## DamageScaling each; each ratio is a param items can raise (ABILITIES.md).
@export var scalings: Array[DamageScaling] = []
## PHYSICAL (armor), MAGIC (magic_resist) or TRUE (ignores both). COMBAT.md.
@export var damage_type: HitContext.DamageType = HitContext.DamageType.PHYSICAL
## Scales on-hit chances and effects (COMBAT C8). 1.0 = full; lower it for
## multi-hit or area abilities.
@export var proc_coefficient: float = 1.0
## Off (default): walls block this ability's hits, and a UNIT ability needs
## line of sight to its target to start the cast (it walks around until it
## has it). On: it hits through walls (e.g. a meteor shower). COMBAT C7.
@export var ignores_walls: bool = false
## Push on each unit hit_units() hits, px, away from where the caster stood
## (a scoped param). Unit.on_hit() applies it (like a swing's knockback), so
## a blocked hit and an unstoppable unit aren't pushed; a unit the hit kills
## still slides (hit_units()). ABILITIES AB11.
@export var hit_knockback_px: float = 0.0
## Seconds the push takes (the target's knockback_curve shapes it).
@export var hit_knockback_duration: float = 0.1

@export_group("Sustain")
## Heals the caster for this share of the damage taken by each unit a hit of
## this ability gets through to (a scoped param; CHAMPIONS CH5, Cleave's heal).
## Read at the hit through get_effect_param(), so named-input scalings (Cleave:
## self_missing_health) and conditional bonuses shape it. It rides the hit
## (HitContext.heal_on_hit_ratio) into HitPipeline.apply_on_hit(), next to
## life_steal: overkill included, never for a blocked hit or a dead caster,
## through Unit.heal(). 0 = no heal. Not the life_steal stat: a kit mechanic.
@export var heal_on_hit_ratio: float = 0.0
## Heals the caster for this share of their own missing health, once per cast:
## on the first hit of the cast that gets through (a scoped param; CHAMPIONS
## CH5b, Cleave's heal, Ryan 2026-09-30). Shaped like heal_on_hit_ratio
## (get_effect_param() at the hit: named-input scalings, bonuses); applied in
## HitPipeline.apply_on_hit() through Unit.heal(). 0 = no heal.
@export var heal_missing_health_ratio: float = 0.0

@export_group("Feel")
## Played once per cast by play_hit_feel() when at least one hit landed
## (ABILITIES AB11). Ability hits have no hit-feel tier of their own
## (HitContext.Feel.NONE), so this is their shake and hitstop. 0 = none.
@export var hit_shake: float = 0.0
## Seconds (GameFeel.hitstop(): the longest running one wins).
@export var hit_hitstop: float = 0.0

@export_group("Conditions")
## All must pass to start a cast (part 0; ABILITIES AB12). A failed press
## fails with "condition", spends nothing and isn't buffered; the slot greys.
@export var cast_conditions: Array[Condition] = []
## All must pass to use the next recast part. Failing doesn't end the window.
@export var recast_conditions: Array[Condition] = []
## "Bonus if…": checked at the effect (get_effect_param(), HitPipeline).
@export var conditional_bonuses: Array[ConditionalBonus] = []

@export_group("Projectile")
## Read only by abilities that fire projectiles (Projectile.fire(); ABILITIES
## AB7). Range is cast_range. All scoped params ("+1 projectile" is an item).
## LoL units per second (1200 = 384 px/s).
@export var projectile_speed: float = 1200.0
## Full width in LoL units (60 = 19 px).
@export var projectile_width: float = 60.0
## Projectiles per cast, fanned out projectile_spread_deg apart.
@export var projectile_count: int = 1
@export var projectile_spread_deg: float = 15.0
## Extra enemies a projectile passes through: 0 = it stops on the first hit.
@export var projectile_pierce: int = 0

@export_group("Vector")
## Read only by VECTOR abilities (ABILITIES AB13). The start range is
## cast_range. LoL units: the line's length from the start point (500 = 160
## px; a scoped param). The cursor beyond it only sets the direction.
@export var vector_length: float = 500.0
## LoL units: the line's full width (75 = 24 px), for the indicator and the
## shapes and ground areas that use the line.
@export var vector_width: float = 75.0
## px: a release closer than this to the start point is a tap (the direction
## is caster -> start point, League's default).
@export var vector_min_drag_px: float = 8.0

@export_group("Sounds")
## At cast start (AUDIO.md). null = silent.
@export var cast_sound: SoundEvent
## When the cast lands on someone (through HitContext.hit_sound): CombatSounds
## plays it once per (source, sound, frame), so once for everyone a cast hits
## in one frame; a projectile's hits in later frames each play it. null =
## HitFeel's sound for the hit's tier.
@export var hit_sound: SoundEvent
## The wind-up, owned by the cast's telegraph (plays at the telegraph, stops
## when it finishes or is freed). Use max_distance_px 640 so it carries.
@export var telegraph_sound: SoundEvent
## When the cooldown ends (AbilityComponent.cooldown_finished), e.g. the
## ultimate-ready ping. A refunded cooldown doesn't ping.
@export var ready_sound: SoundEvent

@export_group("Presentation")
## ABILITIES AB14 presentation hooks, empty until the art pass (which only
## fills these in). VFX only: they never change gameplay state.
## Played at cast start (at release for CHARGE_UP and VECTOR; each recast
## part; a free cast when it runs), at the caster's feet, rotated to the
## cast's direction (play_cast_vfx()). null = nothing.
@export var cast_vfx: PackedScene
## Played on each unit a hit of this ability gets through to (hit_units(),
## Projectile), rotated caster -> target (play_impact_vfx()). null = nothing.
@export var impact_vfx: PackedScene
## An animation on the caster's Body/AnimationPlayer, positioned each tick to
## the cast's progress x its length, so it ends exactly at the effect start
## (AbilityComponent). Empty, no such player or no such animation = nothing.
@export var cast_anim: StringName = &""

static var _placeholder_regex: RegEx
static var _base_params: Dictionary = {}   # StringName -> true (is_base_param())
var _role_warned: bool = false
var _warned_placeholders: Dictionary = {}   # placeholder key -> true (warned once)


## True for a channel: cast_style CHANNEL, or the older cancel_on_move flag
## (both mean: root for the cast time, a new move press cancels it).
func is_channel() -> bool:
	return cast_style == CastStyle.CHANNEL or cancel_on_move


## The units among `units` this ability can hit from `from`: all of them if
## it ignores walls, otherwise only those in line of sight (COMBAT C7).
func filter_by_walls(from: Vector2, units: Array[Unit]) -> Array[Unit]:
	return units if ignores_walls else AbilityUtil.in_sight(from, units)


## True if walls don't stop this ability from reaching `target` from `from`.
func can_reach_through_walls(from: Vector2, target: Unit) -> bool:
	return ignores_walls or WorldQuery.has_line_of_sight(from, target.global_position)


## The toolkit's hit (ABILITIES AB11): each of `units` takes this ability's
## hit through HitPipeline.from_ability(caster, self, u, ctx) (the cast's
## charge, empowers and chain depth), one crit roll shared by the whole
## cast, hit_knockback_px (get_effect_param() for that unit, so a conditional
## bonus can change it) away from where the caster stands now, `statuses`
## applied to each unit the hit gets through to (after the damage, from the
## caster), then resolve(). Returns every hit, blocked ones included.
## TALENTS T3 (Ryan, 2026-09-30), both optional, every older call unchanged:
## `damage_ratio` scales each hit's damage terms (base_damage, ad_ratio,
## ap_ratio: a share of the cast's damage, e.g. Shockwave's 50% splash);
## `crit_roll` shares a roll another call of the same cast already made (a
## second wave of hits still crits with the first), null = a new one.
func hit_units(caster: Unit, units: Array[Unit], ctx: CastContext, statuses: Array[StatusEffect] = [],
		damage_ratio: float = 1.0, crit_roll: HitContext.CritRoll = null) -> Array[HitContext]:
	var hits: Array[HitContext] = []
	if crit_roll == null:
		crit_roll = HitContext.CritRoll.new()
	var origin := caster.global_position
	for u in units:
		if not is_instance_valid(u):
			continue
		var push := get_effect_param(caster, &"hit_knockback_px", ctx, u)
		var hit := HitPipeline.from_ability(caster, self, u, ctx)
		hit.crit_roll = crit_roll
		if damage_ratio != 1.0:
			hit.base_damage *= damage_ratio
			hit.ad_ratio *= damage_ratio
			hit.ap_ratio *= damage_ratio
		if push > 0.0:
			hit.knockback_px = push
			hit.knockback_duration = hit_knockback_duration
			hit.knockback_from = origin
		hit.statuses.append_array(statuses)
		HitPipeline.resolve(hit)
		play_impact_vfx(caster, u, hit)   # AB14: nothing while impact_vfx is empty or the hit was blocked
		if push > 0.0 and hit.killed and is_instance_valid(u):
			# Unit.on_hit() doesn't push the dead; a kill still slides the body,
			# as Cleave's own push did before AB11 (the same velocity and curve).
			var time := maxf(hit_knockback_duration, 0.01)
			u.movement.displace((u.global_position - origin).normalized() * push / time, time)
		hits.append(hit)
	return hits


## The cast's feel, once: hit_hitstop and hit_shake if any of `hits` landed
## (wasn't blocked). Returns whether one did (ABILITIES AB11).
func play_hit_feel(hits: Array[HitContext]) -> bool:
	for h in hits:
		if not h.blocked:
			if hit_hitstop > 0.0:
				GameFeel.hitstop(hit_hitstop)
			if hit_shake > 0.0:
				GameFeel.shake(hit_shake)
			return true
	return false


## The cast_vfx hook (ABILITIES AB14): at the caster's feet, rotated to the
## cast's direction; setup(caster, ctx) on its root if it has one. Nothing
## (null) while cast_vfx is empty.
func play_cast_vfx(caster: Unit, ctx: CastContext) -> Node:
	if cast_vfx == null or not is_instance_valid(caster):
		return null
	var angle := ctx.direction.angle() if ctx != null else 0.0
	return VFX.spawn_scene(cast_vfx, caster, caster.global_position, angle, [caster, ctx])


## The impact_vfx hook (ABILITIES AB14), for a hit that got through: at the
## target's feet, rotated caster -> target (the caster may be gone: a
## projectile's orphaned hit); setup(caster, hit) on its root if it has one.
## Nothing (null) while impact_vfx is empty or for a blocked hit.
func play_impact_vfx(caster: Unit, target: Node2D, hit: HitContext) -> Node:
	if impact_vfx == null or not is_instance_valid(target) or (hit != null and hit.blocked):
		return null
	var from := caster.global_position if is_instance_valid(caster) else target.global_position
	var angle := (target.global_position - from).angle() if from != target.global_position else 0.0
	return VFX.spawn_scene(impact_vfx, target, target.global_position, angle, [caster, hit])


## A number of this ability (an @export param like &"cooldown",
## &"cast_range", &"base_damage", or a scaling term's param) after the
## caster's scoped modifiers (items, buffs; STATS.md). Without a caster: the
## plain value. Anything a named input or conditional bonus could change is
## read with get_effect_param() instead (CONVENTIONS.md, pattern 6).
func get_param(caster: Unit, param: StringName) -> float:
	if is_instance_valid(caster) and caster.stats_component != null:
		return caster.stats_component.get_ability_param(self, param)
	return get_base_param(param)


## A param before modifiers: the @export of that name, else the ratio of the
## scaling term with that param. Anything else is an error (0).
func get_base_param(param: StringName) -> float:
	var value: Variant = get(param)
	if value is float or value is int:
		return float(value)
	var term := get_scaling(param)
	if term != null:
		return term.ratio
	push_error("Ability '%s': no number param '%s'" % [id, param])
	return 0.0


## True if `param` is a number param of this ability (an @export of that
## name, a subclass's included, or a scaling term's param), without an error.
func has_param(param: StringName) -> bool:
	var value: Variant = get(param)
	return value is float or value is int or get_scaling(param) != null


## True if `param` is a number @export of the Ability base class itself
## (cooldown, cast_range, base_damage, vector_length...): a param every
## ability has. StatsComponent checks scoped modifier keys with it.
static func is_base_param(param: StringName) -> bool:
	if _base_params.is_empty():
		for p in (Ability as GDScript).get_script_property_list():
			if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and p.usage & PROPERTY_USAGE_EDITOR \
					and (p.type == TYPE_FLOAT or p.type == TYPE_INT):
				_base_params[StringName(p.name)] = true
	return _base_params.has(param)


## The scaling term whose ratio is `param`, or null.
func get_scaling(param: StringName) -> DamageScaling:
	for term in scalings:
		if term != null and term.param == param:
			return term
	return null


## A param at a charge-up's `charge` (0 = a tap, 1 = full): the full value
## (get_param()) times its ChargeScaling multiplier; a param without one is
## always full. charge -1 = the caster's current charge while it's charging
## this ability (or the charge locked at release, during the release
## windup), otherwise full (so indicators grow while held).
func get_charged_param(caster: Unit, param: StringName, charge: float = -1.0) -> float:
	var full := get_param(caster, param)
	var scaling := get_charge_scaling(param)
	if scaling == null:
		return full
	if charge < 0.0:
		charge = 1.0
		if is_instance_valid(caster) and caster.abilities != null and caster.abilities.get_charge_ability() == self:
			charge = caster.abilities.get_charge()
	return full * scaling.get_multiplier(charge)


## The charge ChargeScaling for `param` (input &"charge"), or null. Scalings
## on other named inputs are read by get_effect_param() only (AB12).
func get_charge_scaling(param: StringName) -> ChargeScaling:
	for s in charge_scalings:
		if s != null and s.param == param and s.input == &"charge":
			return s
	return null


## The scaling terms' damage against `target` (null = no target: the target
## terms count 0), each ratio after scoped modifiers and at `charge`. With a
## `cast` (AB12), each ratio is get_effect_param() for that target instead
## (named inputs and conditional bonuses).
func get_scaling_damage(caster: Unit, target: Node, charge: float = 1.0, cast: CastContext = null) -> float:
	var total := 0.0
	for term in scalings:
		if term == null:
			continue
		if term.param in self:
			push_error("Ability '%s': scaling param '%s' clashes with an @export" % [id, term.param])
			continue
		var ratio := get_effect_param(caster, term.param, cast, target) if cast != null \
			else get_charged_param(caster, term.param, charge)
		total += ratio * term.get_amount(caster, target)
	return total


# --- Conditions (ABILITIES AB12) -------------------------------------------------

## The script's one-off cast check, ANDed with cast_conditions (part 0) or
## recast_conditions (later parts, ctx.part). True by default. Override for
## logic data can't express (the escape hatch).
func can_cast_custom(_caster: Unit, _ctx: CastContext) -> bool:
	return true


## The fail text when can_cast_custom() fails (later UI). "" by default.
func get_custom_fail_text() -> String:
	return ""


## The conditions a press on `part` checks: cast_conditions for part 0,
## recast_conditions for a later part.
func get_conditions_for_part(part: int) -> Array[Condition]:
	return cast_conditions if part == 0 else recast_conditions


## True if a cast of this needs a condition target even when it doesn't pick
## one (not UNIT): a TARGET_ condition, any conditional bonus, or a named
## input scaling on target_distance. AbilityComponent then fills ctx.target
## with the enemy nearest the aim within cast range.
func needs_condition_target() -> bool:
	if not conditional_bonuses.is_empty():
		return true
	if Condition.any_target_kind(cast_conditions) or Condition.any_target_kind(recast_conditions):
		return true
	for s in charge_scalings:
		if s != null and s.input == &"target_distance":
			return true
	return false


## The conditional bonuses whose conditions pass now for `target` (null =
## the cast's target).
func get_active_bonuses(caster: Unit, cast: CastContext, target: Node = null) -> Array[ConditionalBonus]:
	var result: Array[ConditionalBonus] = []
	if conditional_bonuses.is_empty():
		return result
	var t: Unit = target as Unit
	if t == null and cast != null:
		t = cast.target
	for b in conditional_bonuses:
		if b != null and b.is_active(caster, t, cast):
			result.append(b)
	return result


## A param as the effect uses it (AB12): get_param() (scoped modifiers), times
## each of its named-input scalings (ChargeScaling with any input, the value
## from `cast`; target_missing_health from `target`), then every conditional
## bonus that passes now for `target` (null = the cast's target), its
## modifiers with the StatModifier formula. Never below 0. Without a cast,
## named inputs count full (1), like a cast without a charge.
func get_effect_param(caster: Unit, param: StringName, cast: CastContext, target: Node = null) -> float:
	var value := get_param(caster, param)
	var t: Unit = target as Unit
	if t == null and cast != null:
		t = cast.target
	for s in charge_scalings:
		if s != null and s.param == param:
			value *= s.get_multiplier(_input_value(s.input, cast, t))
	if conditional_bonuses.is_empty():
		return value
	var flat := 0.0
	var percent_add := 0.0
	var percent_mult := 1.0
	for b in get_active_bonuses(caster, cast, t):
		for mod in b.modifiers:
			if mod == null or mod.stat != param:
				continue
			match mod.type:
				StatModifier.Type.FLAT:
					flat += mod.value
				StatModifier.Type.PERCENT_ADD:
					percent_add += mod.value
				StatModifier.Type.PERCENT_MULT:
					percent_mult *= 1.0 + mod.value
	return maxf((value + flat) * (1.0 + percent_add) * percent_mult, 0.0)


## A named input's value (0-1): target_missing_health from the target (0
## with none); the others from the cast (full without a cast).
func _input_value(input_name: StringName, cast: CastContext, target: Unit) -> float:
	if input_name == &"target_missing_health":
		if not is_instance_valid(target) or target.health == null or target.health.max_health <= 0.0:
			return 0.0
		return clampf(1.0 - target.health.current / target.health.max_health, 0.0, 1.0)
	if cast == null:
		return 1.0
	return cast.get_input(input_name, 0.0)


## What a hit on `target` deals before damage_increase, crit and mitigation:
## base_damage, ad_ratio x AD, ap_ratio x AP and every scaling term, all after
## scoped modifiers and at `charge` (CHARGE_UP; 1 = full). target null = the
## target terms count 0 (tooltips).
func get_damage_against(caster: Unit, target: Unit, charge: float = 1.0) -> float:
	var total := get_charged_param(caster, &"base_damage", charge) + get_scaling_damage(caster, target, charge)
	if is_instance_valid(caster) and caster.stats_component != null:
		total += get_charged_param(caster, &"ad_ratio", charge) * caster.stats_component.get_stat(&"attack_damage")
		total += get_charged_param(caster, &"ap_ratio", charge) * caster.stats_component.get_stat(&"ability_power")
	return total


## The ability's one role tag (ROLE_TAGS), or &"" with a warning (once) if it
## has none or several.
func get_role() -> StringName:
	var roles: Array[StringName] = []
	for t in tags:
		if t in ROLE_TAGS:
			roles.append(t)
	if roles.size() == 1:
		return roles[0]
	if not _role_warned:
		_role_warned = true
		push_warning("Ability '%s': needs exactly one role tag %s, has %s" % [id, ROLE_TAGS, roles])
	return &""


## The scopes a modifier can use to reach this ability: &"ability:<id>" and
## &"tag:<tag>" for each tag.
func get_modifier_scopes() -> Array[StringName]:
	var scopes: Array[StringName] = [StringName("ability:" + id)]
	if variant_of != &"":
		scopes.append(StringName("ability:" + variant_of))
	for t in tags:
		scopes.append(StringName("tag:" + t))
	return scopes


## Damage this ability deals with the caster's current stats, without a
## target (base_damage and the ratios after scoped modifiers; target terms 0).
func get_damage(caster: Unit) -> float:
	return get_damage_against(caster, null)


# --- Tooltips -----------------------------------------------------------------

## The tooltip: `description` with its placeholders filled from the real
## numbers (scoped modifiers and ability haste applied), the damage colored by
## damage type (BBCode), then one line per augment the caster has on it
## (AB8). Where it's shown is UI.md's.
func get_tooltip(caster: Unit) -> String:
	return _fill_template(caster, true)


## get_tooltip() without BBCode (for plain draw_string text).
func get_tooltip_plain(caster: Unit) -> String:
	return _fill_template(caster, false)


func _fill_template(caster: Unit, bbcode: bool) -> String:
	if _placeholder_regex == null:
		_placeholder_regex = RegEx.create_from_string("\\{([a-z_]+)(%?)\\}")
	# A talent that reshapes this ability may replace its template while it's
	# active (TALENTS T3b: AbilityComponent.get_description_override()).
	var template := description
	if is_instance_valid(caster) and caster.abilities != null:
		var override := caster.abilities.get_description_override(self)
		if override != "":
			template = override
	var out := ""
	var last := 0
	for m in _placeholder_regex.search_all(template):
		out += template.substr(last, m.get_start() - last)
		out += _placeholder_text(caster, m.get_string(1), m.get_string(2) == "%", m.get_string(), bbcode)
		last = m.get_end()
	out += template.substr(last)
	# One line per conditional bonus, always (AB12; "only while active" is an
	# open question).
	for b in conditional_bonuses:
		if b != null and b.description != "":
			out += "\n" + b.description
	# One line per augment on this ability, and one per disabled one (AB8).
	if is_instance_valid(caster) and caster.abilities != null:
		for line in caster.abilities.get_augment_tooltip_lines(self):
			out += "\n" + line
	return out


func _placeholder_text(caster: Unit, key: String, percent: bool, raw: String, bbcode: bool) -> String:
	# {x_min}: a charge-scaled value at charge 0 (a tap), e.g. {range_min}-{range}.
	var charge := 1.0
	if key.ends_with("_min"):
		charge = 0.0
		key = key.trim_suffix("_min")
	match key:
		"damage":
			var text := str(roundi(get_damage_against(caster, null, charge)))
			if not bbcode:
				return text
			var style: DamageNumberStyle = load(DAMAGE_NUMBER_STYLE_PATH)
			var color := style.get_damage_type_color(damage_type)
			return "[color=#%s]%s[/color]" % [color.to_html(false), text]
		"ratios":
			return _ratios_text(caster)
		"cooldown":
			var cd := get_param(caster, &"cooldown")
			if is_instance_valid(caster) and caster.stats_component != null:
				cd = caster.stats_component.get_cooldown(cd)
			return _number_text(cd, percent)
		"range":
			return _number_text(get_charged_param(caster, &"cast_range", charge), percent)
		"cost":
			return _number_text(get_param(caster, &"resource_cost"), percent)
		"charges":
			return str(maxi(floori(get_param(caster, &"max_charges")), 1))
	var value: Variant = get(key)
	if value is float or value is int or get_scaling(StringName(key)) != null:
		return _number_text(get_charged_param(caster, StringName(key), charge), percent)
	if not _warned_placeholders.has(key):
		_warned_placeholders[key] = true
		push_warning("Ability '%s': unknown tooltip placeholder %s" % [id, raw])
	return raw


## "+70% AD +20% of the target's missing health": ad_ratio, ap_ratio, then
## each scaling term, with the ratios after scoped modifiers. Zero ratios are
## left out.
func _ratios_text(caster: Unit) -> String:
	var parts: PackedStringArray = []
	var ad := get_param(caster, &"ad_ratio")
	if ad != 0.0:
		parts.append("+%s AD" % _number_text(ad, true))
	var ap := get_param(caster, &"ap_ratio")
	if ap != 0.0:
		parts.append("+%s AP" % _number_text(ap, true))
	for term in scalings:
		if term != null:
			var ratio := get_param(caster, term.param)
			if ratio != 0.0:
				parts.append("+%s %s" % [_number_text(ratio, true), term.get_label()])
	return " ".join(parts)


## Up to 2 decimals, no trailing zeros (3, 2.5, 0.75); as a percent (1
## decimal at most) if asked.
static func _number_text(value: float, percent: bool) -> String:
	var v := snappedf(value * 100.0, 0.1) if percent else snappedf(value, 0.01)
	var text := str(int(roundf(v))) if is_equal_approx(v, roundf(v)) else str(v)
	return text + "%" if percent else text


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
	# The current charge's range while charging up (it grows), else the full one.
	var range_px := Units.to_px(get_charged_param(caster, &"cast_range"))
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


# --- VECTOR (ABILITIES AB13) ------------------------------------------------------

## The VECTOR aiming indicator, drawn instead of draw_indicator() from the
## press until the effect starts. `canvas` is the caster (local coordinates),
## `start` the start point and `aim` the cursor (locked at release), both in
## world space. The default: the start range, a start marker and the line
## vector_length x vector_width along the direction a release now would use
## (the tap fallback included). Override for custom shapes.
func draw_vector_indicator(canvas: Node2D, caster: Unit, start: Vector2, aim: Vector2) -> void:
	var range_px := Units.to_px(get_param(caster, &"cast_range"))
	var length_px := Units.to_px(get_param(caster, &"vector_length"))
	var half := Units.to_px(get_param(caster, &"vector_width")) * 0.5
	var fill := Color(icon_color, 0.22)
	var edge := Color(icon_color, 0.8)
	var a := canvas.to_local(start)
	var dir := get_vector_direction(caster, start, aim)
	var b := a + dir * length_px
	var side := dir.orthogonal() * half
	canvas.draw_arc(Vector2.ZERO, range_px, 0.0, TAU, 64, Color(1, 1, 1, 0.25), 1.0)
	canvas.draw_colored_polygon(PackedVector2Array([a + side, b + side, b - side, a - side]), fill)
	canvas.draw_polyline(PackedVector2Array([a + side, b + side, b - side, a - side, a + side]), edge, 1.0)
	canvas.draw_circle(a, 4.0, edge)


## The line's direction for a VECTOR cast from `start` released at `aim`:
## start -> aim when the drag is at least vector_min_drag_px, otherwise (a
## tap) get_vector_tap_direction().
func get_vector_direction(caster: Unit, start: Vector2, aim: Vector2) -> Vector2:
	var drag := aim - start
	if drag.length() >= vector_min_drag_px:
		return drag.normalized()
	return get_vector_tap_direction(caster, start)


## A tap's direction: caster -> start point; the caster's facing if the start
## is on the caster (a unit without one: right).
func get_vector_tap_direction(caster: Unit, start: Vector2) -> Vector2:
	var to_start := start - caster.global_position
	if to_start.length() > 0.01:
		return to_start.normalized()
	var facing: Variant = caster.get(&"facing")
	return facing if facing is Vector2 and facing != Vector2.ZERO else Vector2.RIGHT


## Where the enemy AI lays a VECTOR cast against `target`: {start, direction}
## (world space; AbilityComponent.try_cast_vector() clamps the start as at a
## press). The default: start at the target, direction caster -> target.
func get_ai_vector(caster: Unit, target: Unit) -> Dictionary:
	var to_target := target.global_position - caster.global_position
	return {
		"start": target.global_position,
		"direction": to_target.normalized() if to_target.length() > 0.01 else Vector2.RIGHT,
	}
