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
	CHARGE_UP,  ## Hold to charge, release to fire (ABILITIES AB6; until then it casts like INSTANT).
	CHANNEL,    ## Cast on press; stand still through the cast time, a new move press cancels it.
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
## The tooltip template (get_tooltip()): plain text with placeholders such
## as {damage}, {base_damage}, {ratios}, {cooldown}, {cost}, {charges}, {range}, {cast_time},
## or any param by name ({stun_duration}); {param%} shows it as a percent
## (0.35 -> 35%). Text without placeholders is shown as it is.
@export_multiline var description: String = ""
@export var icon_color: Color = Color(0.8, 0.8, 0.8)

@export_group("Casting")
## INSTANT (default), CHARGE_UP or CHANNEL. CHANNEL works exactly like
## cancel_on_move on (a cast that roots and is cancelled by a new move press);
## the cast mode setting (QUICK / hold to aim) only applies to INSTANT.
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

@export_group("Sounds")
## At cast start (AUDIO.md). null = silent.
@export var cast_sound: SoundEvent
## When the cast lands on someone, once per cast however many it hits
## (through HitContext.hit_sound). null = HitFeel's sound for the hit's tier.
@export var hit_sound: SoundEvent
## The wind-up, owned by the cast's telegraph (plays at the telegraph, stops
## when it finishes or is freed). Use max_distance_px 640 so it carries.
@export var telegraph_sound: SoundEvent
## When the cooldown ends (AbilityComponent.cooldown_finished), e.g. the
## ultimate-ready ping. A refunded cooldown doesn't ping.
@export var ready_sound: SoundEvent

static var _placeholder_regex: RegEx
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


## A number of this ability (an @export param like &"cooldown",
## &"cast_range", &"base_damage", or a scaling term's param) after the
## caster's scoped modifiers (items, buffs; STATS.md). Without a caster: the
## plain value.
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


## The ChargeScaling for `param`, or null.
func get_charge_scaling(param: StringName) -> ChargeScaling:
	for s in charge_scalings:
		if s != null and s.param == param:
			return s
	return null


## The scaling terms' damage against `target` (null = no target: the target
## terms count 0), each ratio after scoped modifiers and at `charge`.
func get_scaling_damage(caster: Unit, target: Node, charge: float = 1.0) -> float:
	var total := 0.0
	for term in scalings:
		if term == null:
			continue
		if term.param in self:
			push_error("Ability '%s': scaling param '%s' clashes with an @export" % [id, term.param])
			continue
		total += get_charged_param(caster, term.param, charge) * term.get_amount(caster, target)
	return total


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
## damage type (BBCode). Where it's shown is UI.md's.
func get_tooltip(caster: Unit) -> String:
	return _fill_template(caster, true)


## get_tooltip() without BBCode (for plain draw_string text).
func get_tooltip_plain(caster: Unit) -> String:
	return _fill_template(caster, false)


func _fill_template(caster: Unit, bbcode: bool) -> String:
	if _placeholder_regex == null:
		_placeholder_regex = RegEx.create_from_string("\\{([a-z_]+)(%?)\\}")
	var out := ""
	var last := 0
	for m in _placeholder_regex.search_all(description):
		out += description.substr(last, m.get_start() - last)
		out += _placeholder_text(caster, m.get_string(1), m.get_string(2) == "%", m.get_string(), bbcode)
		last = m.get_end()
	return out + description.substr(last)


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
			parts.append("+%s %s" % [_number_text(get_param(caster, term.param), true), term.get_label()])
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
