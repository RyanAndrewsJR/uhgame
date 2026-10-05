class_name AbilityComponent
extends Node
## Holds a unit's Q/W/E/R abilities and runs them LoL-style:
## - cooldowns (reduced by ability haste: cd * 100 / (100 + haste))
## - cast time: the unit is rooted and can't auto-attack, but keeps its
##   move/attack order and carries on afterwards
## - casting cancels an auto-attack windup, and (by default) resets the
##   auto-attack timer so the next auto comes out immediately
## - targeted (UNIT) abilities walk into range first if you're too far
## - a stun (any status that blocks casting) applied during the cast time
##   interrupts it at once (cooldown refunded; ABILITIES.md, AB1)
## - costs (resource_cost) are paid at cast start and refunded with the
##   cooldown if the cast doesn't go off; a unit without a resource pool
##   pays nothing (ABILITIES.md, AB3)
## - augments (AB8): FLAG / EVENT / REPLACE by source id; get_ability() is
##   what a press casts (a recast sequence's ability, a REPLACE variant, or
##   the slot's own); Events.ability_cast when an effect starts; free casts
## - per ability: walk during the cast at a speed multiplier, or cancel the
##   cast with a dash (dash_cancelable) or a new move press (a channel:
##   cast_style CHANNEL or cancel_on_move)
## - VECTOR (AB13) through the charge-up hold/release path: the press drops a
##   start point, the release sets the line's direction (VECTOR flow)
## - AB14: the cast time runs on cast progress (0 -> 1, advanced each physics
##   tick by delta x the cast speed); the cast's telegraph follows it, and the
##   3D view positions the model's cast_anim by it (UnitView); the
##   presentation hook cast_vfx fires at cast start

signal cast_started(slot: StringName, ability: Ability, ctx: CastContext)
signal cast_finished(slot: StringName, ability: Ability)
## A cast was refused. reason: one of the FAIL_* strings (ABILITIES.md, HUD
## feedback); the HUD shows a cue per reason.
signal cast_failed(slot: StringName, reason: String)
## A cast was cancelled during its cast time (e.g. by a dash). cast_finished
## is emitted right after, so existing listeners still clean up.
signal cast_cancelled(slot: StringName, ability: Ability)
## A slot went from 0 charges to 1 by recharging (not a refund): it's
## castable again. With max_charges 1 that's "its cooldown counted down to
## 0". Plays the ability's ready_sound (AUDIO.md).
signal cooldown_finished(slot: StringName, ability: Ability)
## A slot's stored charges changed (cast, recharge, refund, max changed).
signal charges_changed(slot: StringName, charges: int, max_charges: int)
## A recast window opened (after a part finished): `part` is the next part,
## `time` the seconds to press for it (ABILITIES AB5).
signal recast_window_started(slot: StringName, part: int, time: float)
## A recast sequence ended: its last part was used or the window ran out.
## The slot's recharge starts now.
signal recast_window_finished(slot: StringName)
## A CHARGE_UP ability started charging (its cost is paid now; ABILITIES AB6).
signal charge_started(slot: StringName, ability: Ability)
## A charge-up was released (or fired by its overhold) at `charge` 0-1; its
## cast starts right after (cast_started).
signal charge_released(slot: StringName, ability: Ability, charge: float)
## A charge-up is over, however it ended (its effect started after release,
## overhold, Esc, stun, dash, move, death...): the indicator, the charge bar
## and the charging sound go (AB6).
signal charge_ended(slot: StringName, ability: Ability)
## The augments on the slot's abilities changed (added or removed; AB8): the
## HUD and tooltips refresh.
signal augments_changed(slot: StringName)
## AB14: the cast time of the cast in progress is over: its progress reached
## 1, or it was cancelled or interrupted (the waiting _do_cast() resumes and
## checks its serial). Internal.
signal _cast_time_elapsed

const SLOTS: Array[StringName] = [&"q", &"w", &"e", &"r"]
## Source id of the move_speed modifier from Ability.cast_move_speed_multiplier.
## One cast at a time, so one id.
const CAST_MOVE_SPEED_SOURCE := &"ability_casting"
## cast_failed reasons.
const FAIL_NOT_READY := "not ready"
const FAIL_BUSY := "busy"
const FAIL_NO_TARGET := "no target"
const FAIL_NO_RESOURCE := "not enough resource"
const FAIL_SILENCED := "silenced"
## A cast or recast condition (or the script's custom check) fails (AB12).
## Also an ability that moves its caster while it's rooted (2026-10-04).
const FAIL_CONDITION := "condition"
## The fail text of an ability that moves its caster, pressed while rooted.
const ROOTED_FAIL_TEXT := "Rooted"
## A VECTOR start point is swept from the caster with this small core against
## walls (like a projectile's), so it stops at a wall's face (AB13).
const VECTOR_WALL_RADIUS_PX := 2.0
## A cast time counts as done within this many seconds of 0, so float residue
## (0.2 - 12 x 1/60) doesn't add a physics frame (AB14b; the swings'
## SWING_TIME_EPSILON). 0.2 s = 12 ticks, as written.
const CAST_TIME_EPSILON := 0.0001

@export var q: Ability
@export var w: Ability
@export var e: Ability
@export var r: Ability

var unit: Unit
var casting: bool = false
var casting_slot: StringName = &""

var _cooldown_left: Dictionary = {}   # slot -> seconds until the next charge (the recharge timer)
var _cooldown_total: Dictionary = {}  # slot -> seconds (for the HUD sweep)
var _charges: Dictionary = {}         # slot -> stored charges (set on first use: full)
var _cast_took_charge: bool = false   # the cast in progress took a charge (a refund gives it back)
var _cast_part: int = 0               # the recast part of the cast in progress
## The ability of the cast (or charge-up) in progress, kept from its start so
## a slot swap mid-cast doesn't change it.
var _cast_ability: Ability
## Charge-up (AB6): `casting` is true from the press to the end of the cast
## (no swings, the dash rules of a cast), casting_slot is its slot.
var _charge_phase: ChargePhase = ChargePhase.NONE
var _charge_ability: Ability
var _charge_hold: float = 0.0          # seconds held (game time)
var _charge_aim: Vector2 = Vector2.ZERO  # the cursor while holding (set_charge_aim()); locked at release
var _released_charge: float = 0.0      # the charge locked at release
var _charge_sound_handle: int = 0
## A VECTOR aim's start point (AB13), placed at the press; Vector2.INF when no
## VECTOR aim or release windup is going (_end_charge() forgets it).
var _vector_start: Vector2 = Vector2.INF
## Recast sequences: slot -> {next: the next part, left: window seconds,
## ability, last_part_hit, sequence: part 0's CastContext.sequence (LOOT L6),
## handed to every later part}. Created when a part 0 with recasts starts; its
## window only runs between parts; erased when the sequence ends.
var _recast: Dictionary = {}
var _pending: Dictionary = {}         # queued targeted cast: {slot, target}
var _pending_repath: float = 0.0
var _cast_serial: int = 0        # bumped by each cast and by a cancel
var _cast_rooted: bool = false
var _executing: bool = false     # true while ability.execute() runs
var _cast_ctx: CastContext       # the cast in progress (for its telegraph)
var _cast_cost: float = 0.0      # what the cast in progress paid (refunded if it doesn't go off)
## Augments (AB8): [AbilityAugment, source_id] in the order added. The same id
## from several sources counts once.
var _augments: Array = []
var _flag_errors: Dictionary = {}   # "<ability id>/<flag>" -> true (reported once)
## Tooltip templates that replace an ability's description while their
## source is on (TALENTS T3b): [ability id, template, source_id], in the order added.
var _description_overrides: Array = []
## Where conditions checked outside a press look (the HUD's grey preview):
## the Player sets the cursor every physics frame, the enemy AI its target (AB12).
var _aim_hint: Vector2 = Vector2.INF
## AB14 cast progress: the cast in progress (_cast_ctx) is in its cast time.
## _cast_time_left counts down like the old SceneTreeTimer did (the same
## float steps), except that it's done within CAST_TIME_EPSILON of 0, so a
## cast time that is an exact number of ticks doesn't take one more (AB14b);
## progress = 1 - left / total.
var _cast_time_running: bool = false
var _cast_time_left: float = 0.0
var _cast_time_total: float = 0.0
var _cast_speed_warned: bool = false


func _ready() -> void:
	unit = get_parent() as Unit
	assert(unit != null, "AbilityComponent must be a child of a Unit")
	for s in SLOTS:
		_cooldown_left[s] = 0.0
		_cooldown_total[s] = 1.0
	Events.unit_hit.connect(_on_events_unit_hit)   # LAST_PART_HIT (AB12)
	# Unit's @onready status_component is only set once the Unit itself is ready.
	if unit.is_node_ready():
		_on_unit_ready()
	else:
		unit.ready.connect(_on_unit_ready, CONNECT_ONE_SHOT)


func _on_unit_ready() -> void:
	if unit.status_component != null:
		unit.status_component.status_applied.connect(_on_status_component_status_applied)


## A status that blocks casting (stun, silence) interrupts a cast during its
## cast time at once, cooldown refunded (ABILITIES.md, Casting). A unit
## without a StatusComponent still gets the check at the end of the cast time.
func _on_status_component_status_applied(_effect: StatusEffect) -> void:
	if casting and not _executing and unit.is_cast_blocked():
		interrupt_cast()


# --- Queries --------------------------------------------------------------------

## The ability a press on the slot casts: the ability of a recast sequence
## still going (its window stays with the ability that opened it), else the
## active REPLACE variant (AB8), else the slot's own ability.
func get_ability(slot: StringName) -> Ability:
	var base := get_base_ability(slot)
	if base == null:
		return null
	if _recast.has(slot):
		return _recast[slot].ability
	var variant := _get_replacement(base)
	return variant if variant != null else base


## Every ability the unit holds: each slot's own ability and the REPLACE
## variants of its augments (active or not), each once. StatsComponent checks
## scoped modifier keys against them.
func get_all_abilities() -> Array[Ability]:
	var result: Array[Ability] = []
	for slot in SLOTS:
		var ability := get_base_ability(slot)
		if ability != null and not result.has(ability):
			result.append(ability)
	for e: Array in _augments:
		var augment: AbilityAugment = e[0]
		if augment.replacement != null and not result.has(augment.replacement):
			result.append(augment.replacement)
	return result


## The slot's own ability (the q / w / e / r export), whatever augments do.
func get_base_ability(slot: StringName) -> Ability:
	match slot:
		&"q": return q
		&"w": return w
		&"e": return e
		&"r": return r
	return null


func get_cooldown_left(slot: StringName) -> float:
	return _cooldown_left.get(slot, 0.0)


## 0 = ready, 1 = just cast.
func get_cooldown_fraction(slot: StringName) -> float:
	var total: float = _cooldown_total.get(slot, 1.0)
	return clampf(get_cooldown_left(slot) / maxf(total, 0.001), 0.0, 1.0)


## The ability's cooldown after scoped modifiers (items), then ability haste
## (STATS.md: the one place this happens).
func get_cooldown_duration(ability: Ability) -> float:
	return unit.stats_component.get_cooldown(ability.get_param(unit, &"cooldown"))


## AB14: the cast speed for `ability`: how fast its cast progress advances
## (1.0 = its cast_time in seconds). Hardcoded 1.0 for now: the one place a
## future cast-speed stat or cast-speed item plugs in. It's read every tick,
## so a change mid-cast applies from that tick. It never touches cooldowns
## (ability_haste does, in get_cooldown_duration()).
func get_cast_speed(_ability: Ability) -> float:
	return 1.0


## AB14: the cast in progress's cast progress, 0 (cast start) to 1 (its
## effect started). 0 when nothing is casting, and while a charge-up or a
## VECTOR aim is still held (its cast starts at release).
func get_cast_progress() -> float:
	if not casting or _cast_ctx == null:
		return 0.0
	return _cast_ctx.progress


## The cast (or charge-up) in progress: its ability, or null (ENEMIES_AI AI3:
## what an enemy sees coming at it).
func get_cast_ability() -> Ability:
	if not casting:
		return null
	return _cast_ability if _cast_ability != null else _charge_ability


## The cast in progress's context (its point, direction, target), or null
## (none, or a charge-up or VECTOR aim still held: its cast starts at release).
func get_cast_context() -> CastContext:
	return _cast_ctx if casting else null


## Seconds until the cast in progress's effect starts (its cast time left at
## its cast speed); 0 when nothing is casting or the effect has started.
func get_cast_time_left() -> float:
	if not casting or _cast_ctx == null or _cast_ctx.progress >= 1.0:
		return 0.0
	return maxf(_cast_time_left, 0.0) / maxf(_get_valid_cast_speed(_cast_ability), 0.01)


## The aim of the charge-up being held (Vector2.INF when none is held): where
## it would fire now.
func get_charge_aim() -> Vector2:
	return _charge_aim if _charge_phase == ChargePhase.HOLDING else Vector2.INF


## True if the slot has a charge (with max_charges 1: its cooldown is done)
## or a recast sequence is going (its next part needs no charge).
func is_ready(slot: StringName) -> bool:
	return get_ability(slot) != null and (get_charges(slot) > 0 or _recast.has(slot))


## The next recast part the slot would cast (1, 2...), or 0 when no recast
## sequence is going (a press casts part 0).
func get_recast_part(slot: StringName) -> int:
	return _recast[slot].next if _recast.has(slot) else 0


## Seconds left to press for the next part (0 when no sequence is going).
## It doesn't run while a part is being cast.
func get_recast_time_left(slot: StringName) -> float:
	return _recast[slot].left if _recast.has(slot) else 0.0


## The whole window for the slot's current sequence (for the HUD bar).
func get_recast_window(slot: StringName) -> float:
	var ability: Ability = _recast[slot].ability if _recast.has(slot) else get_ability(slot)
	return ability.get_param(unit, &"recast_window") if ability != null else 0.0


## Stored charges. A slot starts full the first time it's asked.
func get_charges(slot: StringName) -> int:
	if not _charges.has(slot):
		_charges[slot] = get_max_charges(slot)
	return _charges[slot]


## max_charges after scoped modifiers (items), at least 1.
func get_max_charges(slot: StringName) -> int:
	var ability := get_ability(slot)
	if ability == null:
		return 1
	return maxi(floori(ability.get_param(unit, &"max_charges")), 1)


## Ready, not casting, alive and not blocked. Doesn't look at the cost or the
## conditions: a press that can't be afforded or fails its conditions fails at
## once instead of being buffered (can_afford(), conditions_pass(); ABILITIES.md,
## Costs and Conditions). get_fail_reason() is the full check (the enemy AI
## uses it).
func can_cast(slot: StringName) -> bool:
	return is_ready(slot) and not casting and unit.is_alive() and not unit.is_cast_blocked()


## The ability's resource_cost after scoped modifiers.
func get_cost(ability: Ability) -> float:
	return ability.get_param(unit, &"resource_cost")


## What a press on the slot would cost now: resource_cost for a first cast,
## recast_resource_cost for a later part (after scoped modifiers).
func get_slot_cost(slot: StringName) -> float:
	var ability := get_ability(slot)
	if ability == null:
		return 0.0
	if get_recast_part(slot) > 0:
		return ability.get_param(unit, &"recast_resource_cost")
	return get_cost(ability)


## True if the unit can pay the slot's next cost now. A unit without a
## resource pool (resource type NONE, enemies) always can: it pays nothing.
func can_afford(slot: StringName) -> bool:
	if get_ability(slot) == null:
		return false
	return unit.resource_pool == null or unit.resource_pool.can_afford(get_slot_cost(slot))


## Why the slot can't be cast right now (a FAIL_* string), or "" if it can.
## Blocked (stunned, silenced) comes first, then not ready, then busy, then
## the cost, then the conditions (AB12: `aim` and `target` as for try_cast();
## without them the aim hint and the condition target near it).
func get_fail_reason(slot: StringName, aim: Vector2 = Vector2.INF, target: Unit = null) -> String:
	if get_ability(slot) == null or not unit.is_alive():
		return FAIL_BUSY
	if unit.is_cast_blocked():
		return FAIL_SILENCED
	if not is_ready(slot):
		return FAIL_NOT_READY
	if casting:
		return FAIL_BUSY
	if not can_afford(slot):
		return FAIL_NO_RESOURCE
	if not conditions_pass(slot, aim, target):
		return FAIL_CONDITION
	return ""


# --- Conditions (ABILITIES AB12) --------------------------------------------------

## Where conditions checked outside a press look: the Player sets the cursor
## every physics frame; the enemy AI its target's position before it asks.
func set_aim_hint(point: Vector2) -> void:
	_aim_hint = point


func get_aim_hint() -> Vector2:
	return _aim_hint if _aim_hint != Vector2.INF else unit.global_position


## True if a press on the slot now passes its conditions: cast_conditions for
## a first cast, recast_conditions for the next part, and the script's
## can_cast_custom(). `aim` (INF = the aim hint) and `target` (a UNIT cast's
## chosen target; null = the condition target near the aim) as for try_cast().
## An ability that moves its caster (Ability.moves_caster()) also fails while
## the caster is rooted or stunned (roots are roots; Ryan, 2026-10-04): the
## press fails at once with its cue and the slot greys, like any condition.
func conditions_pass(slot: StringName, aim: Vector2 = Vector2.INF, target: Unit = null) -> bool:
	var ability := get_ability(slot)
	if ability == null:
		return false
	if _rooted_out(ability):
		return false
	var ctx := _make_condition_context(slot, ability, aim, target)
	return Condition.all_met(ability.get_conditions_for_part(ctx.part), unit, ctx.target, ctx) \
		and ability.can_cast_custom(unit, ctx)


## The first failed condition's fail_text, else the script's custom fail
## text, else "" (for later UI; the slot's conditions at the aim hint).
func get_condition_fail_text(slot: StringName) -> String:
	var ability := get_ability(slot)
	if ability == null:
		return ""
	if _rooted_out(ability):
		return ROOTED_FAIL_TEXT
	var ctx := _make_condition_context(slot, ability, Vector2.INF, null)
	var failed := Condition.first_failed(ability.get_conditions_for_part(ctx.part), unit, ctx.target, ctx)
	if failed != null:
		return failed.fail_text
	if not ability.can_cast_custom(unit, ctx):
		return ability.get_custom_fail_text()
	return ""


## True when `ability` moves its caster and the caster is rooted or stunned.
func _rooted_out(ability: Ability) -> bool:
	return ability.moves_caster() and unit != null and unit.is_dash_blocked()


func _make_condition_context(slot: StringName, ability: Ability, aim: Vector2, target: Unit) -> CastContext:
	if aim == Vector2.INF:
		aim = get_aim_hint()
	if ability.cast_style == Ability.CastStyle.VECTOR and ability.needs_condition_target():
		aim = _clamp_vector_start(ability, aim)   # AB13: the condition target is near the start point
	var ctx := _make_context(slot, ability, aim, 1.0, target)
	if ability.targeting == Ability.Targeting.UNIT and not is_instance_valid(ctx.target):
		ctx.target = _condition_target(ability, aim)   # the HUD preview: the enemy near the aim
		_fill_inputs(ctx, ability)
	return ctx


## The condition target of a cast that doesn't pick one: the living enemy
## nearest the aim within the ability's cast range of the unit, or null.
## The range is get_effect_param() for `ctx` (its charge and inputs so far;
## no target yet), like every cast_range read here.
func _condition_target(ability: Ability, aim: Vector2, ctx: CastContext = null) -> Unit:
	return AbilityUtil.nearest_enemy_in_range(unit, aim, Units.to_px(ability.get_effect_param(unit, &"cast_range", ctx)))


## The built-in named inputs (charge is set already): self_missing_health
## and target_distance (edge distance to ctx.target ÷ cast range; 0 without
## one). target_missing_health is per target (Ability.get_effect_param()).
func _fill_inputs(ctx: CastContext, ability: Ability) -> void:
	var max_health := unit.health.max_health
	ctx.set_input(&"self_missing_health", 1.0 - unit.health.current / max_health if max_health > 0.0 else 0.0)
	var distance := 0.0
	var range_px := Units.to_px(ability.get_effect_param(unit, &"cast_range", ctx))
	if is_instance_valid(ctx.target) and range_px > 0.0:
		distance = maxf(unit.edge_distance_to(ctx.target), 0.0) / range_px
	ctx.set_input(&"target_distance", distance)


## At the effect start (flow step 10; CHAMPIONS CH5, Ryan 2026-09-29):
## self_missing_health is read again, so a hit taken during the cast time
## counts. One value per cast: every hit of the effect reads it. The other
## inputs keep their cast-start values.
func _refresh_effect_inputs(ctx: CastContext) -> void:
	var max_health := unit.health.max_health
	ctx.set_input(&"self_missing_health", 1.0 - unit.health.current / max_health if max_health > 0.0 else 0.0)


## Applies the self_statuses of every conditional bonus that passes at the
## effect start (flow step 10).
func _apply_bonus_self_statuses(ability: Ability, ctx: CastContext) -> void:
	if unit.status_component == null or ability.conditional_bonuses.is_empty():
		return
	for b in ability.get_active_bonuses(unit, ctx):
		for s in b.self_statuses:
			if s != null:
				unit.status_component.apply_status(s, unit)


## LAST_PART_HIT: a hit from this unit by a running recast sequence's
## ability marks that sequence (a projectile of the previous part that lands
## later still counts, until the next part starts).
func _on_events_unit_hit(ctx: HitContext) -> void:
	if ctx.source != unit or ctx.ability == null or _recast.is_empty():
		return
	for slot: StringName in _recast.keys():
		if _recast[slot].ability == ctx.ability:
			_recast[slot].last_part_hit = true


func has_pending() -> bool:
	return not _pending.is_empty()


# --- Casting --------------------------------------------------------------------

## Try to cast. `aim` is the cursor in world space; `target_unit` is the
## enemy under the cursor (needed for UNIT abilities). Returns true if the
## cast started or was queued (walking into range).
func try_cast(slot: StringName, aim: Vector2, target_unit: Unit = null) -> bool:
	var ability := get_ability(slot)
	if ability == null:
		return false
	var reason := get_fail_reason(slot, aim, target_unit)
	if reason != "":
		cast_failed.emit(slot, reason)
		return false

	var ctx := _make_cast_context(slot, ability, aim, target_unit)

	match ability.targeting:
		Ability.Targeting.UNIT:
			if target_unit == null or not target_unit.is_targetable() or not unit.is_enemy_of(target_unit):   # untargetable: no target (AB10)
				cast_failed.emit(slot, FAIL_NO_TARGET)
				return false
			ctx.target = target_unit
			# Out of range, or no line of sight (COMBAT C7): walk until both hold.
			if unit.edge_distance_to(target_unit) > Units.to_px(ability.get_effect_param(unit, &"cast_range", ctx, target_unit)) \
					or not ability.can_reach_through_walls(unit.global_position, target_unit):
				_pending = {"slot": slot, "target": target_unit}
				_pending_repath = 0.0
				unit.attack.cancel()
				return true

	_pending.clear()
	_do_cast(slot, ability, ctx)
	return true


## A cast's context for an aim: the slot, its recast part, the charge, and
## the aim by targeting (SELF: the caster; POINT: clamped to the range, read
## last with get_effect_param() so the charge, the inputs and conditional
## bonuses for the target count; DIRECTION / UNIT: toward the aim). UNIT's
## target is set by try_cast().
## AB12: `target` is a UNIT cast's chosen target (ctx.target); another cast
## gets the condition target (the enemy nearest the aim within cast range)
## when the ability needs one (Ability.needs_condition_target()). Then the
## built-in named inputs and, in a recast sequence, last_part_hit.
func _make_context(slot: StringName, ability: Ability, aim: Vector2, charge: float, target: Unit = null) -> CastContext:
	var ctx := CastContext.new()
	ctx.slot = slot
	ctx.ability = ability
	ctx.flags = get_flags(ability)   # read at cast start: removing an augment later doesn't change this cast
	ctx.part = get_recast_part(slot)   # 0, or the next part of a recast sequence
	ctx.charge = charge
	var origin := unit.global_position
	var to_aim := aim - origin
	ctx.direction = to_aim.normalized() if to_aim.length() > 0.01 else Vector2.RIGHT
	ctx.point = aim
	if ability.targeting == Ability.Targeting.UNIT:
		ctx.target = target if is_instance_valid(target) else null
	elif ability.needs_condition_target():
		ctx.target = _condition_target(ability, aim, ctx)
	if ctx.part > 0 and _recast.has(slot):
		ctx.last_part_hit = _recast[slot].last_part_hit
		ctx.sequence = _recast[slot].sequence   # LOOT L6: what part 0 left for the later parts
	_fill_inputs(ctx, ability)
	match ability.targeting:
		Ability.Targeting.SELF:
			ctx.point = origin
		Ability.Targeting.POINT:
			ctx.point = origin + to_aim.limit_length(Units.to_px(ability.get_effect_param(unit, &"cast_range", ctx)))
	return ctx


## The context of a cast that runs without a hold (try_cast(), a free cast):
## _make_context(), except a VECTOR ability casts as a tap (AB13): the start
## is the aim clamped as at a press, the direction caster -> start,
## vector_drag 0.
func _make_cast_context(slot: StringName, ability: Ability, aim: Vector2, target: Unit) -> CastContext:
	if ability.cast_style != Ability.CastStyle.VECTOR:
		return _make_context(slot, ability, aim, 1.0, target)
	var start := _clamp_vector_start(ability, aim)
	var ctx := _make_context(slot, ability, start, 1.0, target)
	_fill_vector(ctx, ability, start, start)
	return ctx


# --- VECTOR (ABILITIES AB13) -------------------------------------------------------

## The start point for an aim: clamped to cast_range (get_effect_param(),
## for `ctx` when there is one) from the unit, then (unless the ability
## ignores walls) to the last spot short of a wall on the line from the
## unit, so a cursor inside a wall or out of sight puts it at the wall's face.
func _clamp_vector_start(ability: Ability, aim: Vector2, ctx: CastContext = null) -> Vector2:
	var origin := unit.global_position
	var start := origin + (aim - origin).limit_length(Units.to_px(ability.get_effect_param(unit, &"cast_range", ctx)))
	if not ability.ignores_walls:
		var wall := WorldQuery.shape_sweep(origin, start, VECTOR_WALL_RADIUS_PX)
		if not wall.is_empty():
			start = wall.position
	return start


## Fills a VECTOR cast's line from its start point and the release aim: the
## direction (start -> aim, or a tap's fallback under vector_min_drag_px),
## the end (vector_length along it: get_effect_param(), so a conditional
## bonus can lengthen it) and vector_drag (drag length ÷ vector_length, 0
## for a tap). `point` = the start and `direction` = unit -> start, their
## usual meanings.
func _fill_vector(ctx: CastContext, ability: Ability, start: Vector2, aim: Vector2) -> void:
	var length_px := Units.to_px(ability.get_effect_param(unit, &"vector_length", ctx))
	var drag := (aim - start).length()
	ctx.vector_start = start
	ctx.vector_direction = ability.get_vector_direction(unit, start, aim)
	ctx.vector_end = start + ctx.vector_direction * length_px
	var tap := drag < ability.vector_min_drag_px
	ctx.set_input(&"vector_drag", 0.0 if tap or length_px <= 0.0 else drag / length_px)
	ctx.point = start
	ctx.direction = ability.get_vector_tap_direction(unit, start)


## The start point while a VECTOR aim (or its release windup) is going, else
## Vector2.INF. The Player draws the indicator from it.
func get_vector_start() -> Vector2:
	return _vector_start


## Casts the VECTOR ability in `slot` at once with a start point (clamped as
## at a press) and a direction, without a hold: for the enemy AI and tests.
## vector_drag is 1 (no drag to measure). The usual checks, cost and cast
## time. False if refused.
func try_cast_vector(slot: StringName, start: Vector2, direction: Vector2) -> bool:
	var ability := get_ability(slot)
	if ability == null:
		return false
	if ability.cast_style != Ability.CastStyle.VECTOR:
		push_error("Ability '%s': try_cast_vector() needs a VECTOR ability" % ability.id)
		return false
	var reason := get_fail_reason(slot, start)
	if reason != "":
		cast_failed.emit(slot, reason)
		return false
	var s := _clamp_vector_start(ability, start)
	var ctx := _make_context(slot, ability, s, 1.0)
	var length_px := Units.to_px(ability.get_effect_param(unit, &"vector_length", ctx))
	_fill_vector(ctx, ability, s, s + direction.normalized() * maxf(length_px, ability.vector_min_drag_px))
	_pending.clear()
	_do_cast(slot, ability, ctx)
	return true


func cancel_pending() -> void:
	_pending.clear()


# --- Charge-up (ABILITIES AB6) -------------------------------------------------------

## HOLDING: the key is held and the charge grows. RELEASED: let go, the aim
## and charge are locked and the cast is in its release windup (cast_time)
## until its effect starts. NONE otherwise.
enum ChargePhase { NONE, HOLDING, RELEASED }


## True while the key is held (the charge grows).
func is_charging() -> bool:
	return _charge_phase == ChargePhase.HOLDING


## True from the press until the effect starts or the charge-up ends any
## other way: while this is true the Player shows the ability's indicator
## (following the cursor while holding, locked during the release windup).
func has_charge_indicator() -> bool:
	return _charge_phase != ChargePhase.NONE


## The charge-up's ability (kept from the press, so a slot swap mid-charge
## doesn't change it), or null.
func get_charge_ability() -> Ability:
	return _charge_ability if _charge_phase != ChargePhase.NONE else null


## The charge so far while holding, 0 (just pressed) to 1 (full); the locked
## charge during the release windup; 0 otherwise.
func get_charge() -> float:
	match _charge_phase:
		ChargePhase.HOLDING:
			var time := _get_charge_full_time()
			return 1.0 if time <= 0.0 else clampf(_charge_hold / time, 0.0, 1.0)
		ChargePhase.RELEASED:
			return _released_charge
	return 0.0


## The aim locked at release (the release windup), or Vector2.INF while
## holding (the indicator follows the cursor) or with no charge-up.
func get_locked_charge_aim() -> Vector2:
	return _charge_aim if _charge_phase == ChargePhase.RELEASED else Vector2.INF


## Seconds left before the overhold behavior: the whole overhold_time until
## full charge, then counting down. 0 when not holding.
func get_overhold_left() -> float:
	if not is_charging():
		return 0.0
	var full_at := _get_charge_full_time()
	var overhold := _charge_ability.get_param(unit, &"overhold_time")
	return clampf(overhold - maxf(_charge_hold - full_at, 0.0), 0.0, overhold)


## Seconds from the press to full charge: charge_time (a scoped param); 0 for
## a VECTOR aim, whose charge is 1 from the press, so overhold_time is its
## hold limit (AB13).
func _get_charge_full_time() -> float:
	if _charge_ability.cast_style == Ability.CastStyle.VECTOR:
		return 0.0
	return _charge_ability.get_param(unit, &"charge_time")


## Where a charge-up fires if its overhold fires it (the Player keeps it on
## the cursor every frame; otherwise the aim it started with). Ignored once
## released (the aim is locked).
func set_charge_aim(aim: Vector2) -> void:
	if is_charging():
		_charge_aim = aim


## Press: start charging a CHARGE_UP ability. Checks like try_cast() (ready,
## not busy or blocked, affordable) and pays the cost now; the charge and
## cooldown are taken at release. The cast movement rules apply while
## charging and during the release windup (roots_during_cast,
## cast_move_speed_multiplier, a channel's move cancel, dash_cancelable).
## A VECTOR ability (AB13) is aimed the same way, every recast part too: the
## press also drops its start point (_clamp_vector_start()).
## Anything else (another cast style, a CHARGE_UP recast part) is an
## ordinary try_cast(). False if refused.
func try_start_charge(slot: StringName, aim: Vector2) -> bool:
	var ability := get_ability(slot)
	if ability == null:
		return false
	var part := get_recast_part(slot)
	var vector := ability.cast_style == Ability.CastStyle.VECTOR
	if not vector and (ability.cast_style != Ability.CastStyle.CHARGE_UP or part > 0):
		return try_cast(slot, aim)
	if vector and ability.targeting != Ability.Targeting.POINT:
		push_error("Ability '%s': VECTOR needs POINT targeting" % ability.id)
		return false
	if ability.targeting == Ability.Targeting.UNIT:
		push_error("Ability '%s': CHARGE_UP doesn't support UNIT targeting" % ability.id)
		return false
	var reason := get_fail_reason(slot, aim)
	if reason != "":
		cast_failed.emit(slot, reason)
		return false
	_pending.clear()
	casting = true
	casting_slot = slot
	_cast_ability = ability
	_charge_phase = ChargePhase.HOLDING
	_charge_ability = ability
	_charge_hold = 0.0
	_charge_aim = aim
	_released_charge = 0.0
	_vector_start = _clamp_vector_start(ability, aim) if vector else Vector2.INF
	_cast_ctx = null
	_cast_part = part
	_cast_took_charge = false
	_cast_cost = 0.0
	var cost := get_slot_cost(slot)
	if unit.resource_pool != null and unit.resource_pool.try_spend(cost):
		_cast_cost = maxf(cost, 0.0)
	_begin_cast_locks(ability, true)
	_charge_sound_handle = Audio.play_on(ability.charge_sound, unit)
	charge_started.emit(slot, ability)
	return true


## Release: fire the charge-up at `aim` with the charge reached (a tap = 0).
## The aim and charge lock, the charging sound stops, and its cast starts
## now: the charge and cooldown are taken, cast_sound, cast_started, the
## release windup (cast_time), then execute(). The indicator stays (locked)
## until the effect starts. False if nothing is holding.
## A VECTOR aim (AB13): charge 1; the line goes from its start point toward
## `aim` (_fill_vector()), and the condition target is near the start point.
func release_charge(aim: Vector2) -> bool:
	if not is_charging():
		return false
	var slot := casting_slot
	var ability := _charge_ability
	var charge := get_charge()
	_charge_phase = ChargePhase.RELEASED
	_charge_aim = aim
	_released_charge = charge
	_stop_charge_sound()
	var ctx: CastContext
	if ability.cast_style == Ability.CastStyle.VECTOR:
		ctx = _make_context(slot, ability, _vector_start, charge)
		_fill_vector(ctx, ability, _vector_start, aim)
	else:
		ctx = _make_context(slot, ability, aim, charge)
	charge_released.emit(slot, ability, charge)
	_do_cast(slot, ability, ctx, true)
	return true


## Esc while charging (or in the release windup): cancel with a full refund.
## False if no charge-up is going.
func try_cancel_charge() -> bool:
	if not has_charge_indicator() or _executing:
		return false
	_cancel_cast()
	return true


## The one way a charge-up ends, whatever ended it (its effect starting after
## release, the overhold, Esc, a stun, a dash, a move, death, a lost key
## release): the phase goes back to NONE, the charging sound stops, and
## charge_ended tells the HUD and the Player to clear the indicator and the
## charge bar. Does nothing if no charge-up is going.
func _end_charge() -> void:
	if _charge_phase == ChargePhase.NONE:
		return
	var slot := casting_slot
	var ability := _charge_ability
	_charge_phase = ChargePhase.NONE
	_charge_hold = 0.0
	_vector_start = Vector2.INF   # a VECTOR aim's start marker goes with it (AB13)
	_stop_charge_sound()
	charge_ended.emit(slot, ability)


func _stop_charge_sound() -> void:
	if _charge_sound_handle != 0:
		Audio.stop(_charge_sound_handle)
		_charge_sound_handle = 0


## Holding: count the hold (game time); after full charge + overhold_time,
## the overhold behavior: FIRE at the aim, or CANCEL_REFUND.
func _update_charge(delta: float) -> void:
	if not is_charging():
		return
	if not unit.is_alive() or unit.is_cast_blocked():
		interrupt_cast()   # safety net for a unit without a StatusComponent
		return
	_charge_hold += delta
	var limit := _get_charge_full_time() + _charge_ability.get_param(unit, &"overhold_time")
	if _charge_hold >= limit:
		if _charge_ability.overhold == Ability.Overhold.FIRE:
			release_charge(_charge_aim)
		else:
			_cancel_cast()


## Reports a press that won't cast (emits cast_failed), for callers that
## refuse it themselves: the Player's "not enough resource" (never buffered)
## and a buffered press that ran out (PlayerInput).
func fail_cast(slot: StringName, reason: String) -> void:
	cast_failed.emit(slot, reason)


## True during a cast's cast time (before its effect) if the ability allows
## cancelling it (Ability.dash_cancelable).
func can_cancel_cast() -> bool:
	if not casting or _executing:
		return false
	return _cast_ability != null and _cast_ability.dash_cancelable


## Cancels the current cast during its cast time if allowed. Releases the
## locks right away and refunds the cooldown. Returns true if cancelled.
func try_cancel_cast() -> bool:
	if not can_cancel_cast():
		return false
	_cancel_cast()
	return true


## True during a cast's cast time (before its effect) if the ability is
## cancelled by a new movement press (a channel: Ability.is_channel()).
func can_cancel_cast_on_move() -> bool:
	if not casting or _executing:
		return false
	return _cast_ability != null and _cast_ability.is_channel()


## Cancels the current cast because the unit started moving, if its ability
## allows it. Works exactly like the dash cancel. Returns true if cancelled.
func try_cancel_cast_on_move() -> bool:
	if not can_cancel_cast_on_move():
		return false
	_cancel_cast()
	return true


## Ends the current cast during its cast time as an interrupt (the caster
## died, or a stun or silence was applied): its telegraph goes at once, the
## locks are released and cast_finished is emitted. A living caster gets the
## cooldown and the cost back. The effect (execute()) can't be stopped once
## it starts. Returns true if a cast was ended.
func interrupt_cast() -> bool:
	if not casting or _executing:
		return false
	var slot := casting_slot
	var ability := _cast_ability
	_end_charge()   # a charge-up interrupted (stun, death) ends here, refunded like a cast
	_remove_telegraph(_cast_ctx)
	_cast_serial += 1  # The _do_cast waiting on the cast time sees this and stops.
	_stop_cast_time()   # AB14: resumes that _do_cast now (it stops)
	if _cast_rooted:
		unit.movement.remove_move_lock(&"casting")
	unit.attack.remove_lock(&"casting")
	_remove_cast_move_speed()
	if unit.is_alive():
		_restore_slot(slot)  # Refund interrupted casts (charge and cooldown).
		_refund_cost()
	casting = false
	casting_slot = &""
	cast_finished.emit(slot, ability)
	return true


func _cancel_cast() -> void:
	var slot := casting_slot
	var ability := _cast_ability
	_end_charge()   # a charge-up cancelled (Esc, overhold, dash, move) ends here
	_remove_telegraph(_cast_ctx)
	_cast_serial += 1  # The _do_cast waiting on the cast time sees this and stops.
	_stop_cast_time()   # AB14: resumes that _do_cast now (it stops)
	if _cast_rooted:
		unit.movement.remove_move_lock(&"casting")
	unit.attack.remove_lock(&"casting")
	_remove_cast_move_speed()
	_restore_slot(slot)
	_refund_cost()
	casting = false
	casting_slot = &""
	cast_cancelled.emit(slot, ability)
	cast_finished.emit(slot, ability)


func _physics_process(delta: float) -> void:
	# AB14: the cast time's tick runs after every node's _physics_process this
	# frame (deferred), where the old SceneTreeTimer was counted: a cast
	# started anywhere in this frame's node pass counts this tick.
	_advance_cast_time.call_deferred(delta)
	_update_charge(delta)
	_update_recast_windows(delta)
	for s in SLOTS:
		_update_recharge(s, delta)

	if _pending.is_empty() or casting:
		return
	var target: Unit = _pending.target
	var slot: StringName = _pending.slot
	var ability := get_ability(slot)
	if not is_instance_valid(target) or not target.is_targetable() or not unit.is_alive():   # untargetable: dropped (AB10)
		_pending.clear()
		return
	if unit.edge_distance_to(target) <= Units.to_px(ability.get_effect_param(unit, &"cast_range", null, target)) \
			and ability.can_reach_through_walls(unit.global_position, target):
		_pending.clear()
		unit.movement.stop()
		try_cast(slot, target.global_position, target)
	elif not unit.is_stunned():
		_pending_repath -= delta
		if _pending_repath <= 0.0:
			_pending_repath = 0.1
			unit.movement.move_to(target.global_position)


## The cast flow (ABILITIES.md, The cast flow). `precharged`: a released
## charge-up, which already paid its cost and set up its locks when charging
## started.
func _do_cast(slot: StringName, ability: Ability, ctx: CastContext, precharged: bool = false) -> void:
	_cast_serial += 1
	var serial := _cast_serial
	casting = true
	casting_slot = slot
	_cast_ability = ability
	_cast_part = ctx.part
	var cost := get_slot_cost(slot)   # read before a new sequence starts (part 0 pays resource_cost)
	if ctx.part == 0:
		# Take a charge; its recharge starts now unless one is already running
		# (charges come back one at a time). A cancel or interrupt gives it back.
		# With recasts the recharge waits for the sequence to end.
		_charges[slot] = get_charges(slot) - 1
		_cast_took_charge = true
		if ability.recast_count > 0:
			_recast[slot] = {"next": 1, "left": ability.get_param(unit, &"recast_window"), "ability": ability, "last_part_hit": false,
				"sequence": ctx.sequence}
		elif _cooldown_left[slot] <= 0.0 and _charges[slot] < get_max_charges(slot):
			_start_recharge(slot, ability)
		charges_changed.emit(slot, _charges[slot], get_max_charges(slot))
	else:
		_cast_took_charge = false   # a later part needs no charge
		if _recast.has(slot):
			_recast[slot].last_part_hit = false   # this part starts: LAST_PART_HIT now tracks it (AB12)
	if not precharged:
		# Pay at cast start (try_cast() checked it's affordable); refunded if the
		# cast is cancelled or interrupted before its effect. A charge-up paid
		# when charging started.
		_cast_cost = 0.0
		if unit.resource_pool != null and unit.resource_pool.try_spend(cost):
			_cast_cost = maxf(cost, 0.0)
		_begin_cast_locks(ability, false)
	var rooted := _cast_rooted
	_cast_ctx = ctx
	ctx.progress = 0.0 if ability.cast_time > 0.0 else 1.0   # AB14
	Audio.play_on(ability.cast_sound, unit)
	ability.play_cast_vfx(unit, ctx)   # AB14 hook: nothing while cast_vfx is empty
	cast_started.emit(slot, ability, ctx)
	ability.on_cast_started(unit, ctx)
	if is_instance_valid(ctx.telegraph):
		ctx.telegraph.play_sound(ability.telegraph_sound)   # stops with the telegraph (AUDIO.md)

	if ability.cast_time > 0.0:
		# AB14: cast progress, advanced by _advance_cast_time(); a cancel or
		# interrupt also emits _cast_time_elapsed (then the serial differs).
		_cast_time_total = ability.cast_time
		_cast_time_left = ability.cast_time
		_cast_time_running = true
		if is_instance_valid(ctx.telegraph):
			ctx.telegraph.set_progress(0.0)   # the telegraph follows the cast from now on
		await _cast_time_elapsed
	if serial != _cast_serial:
		return  # Cancelled during the cast time; try_cancel_cast() cleaned up.

	var interrupted := not is_instance_valid(unit) or not unit.is_alive() or unit.is_cast_blocked()
	if interrupted:
		_remove_telegraph(ctx)
		_end_charge()
		if is_instance_valid(unit) and unit.is_alive():
			_restore_slot(slot)  # Refund interrupted casts.
			_refund_cost()
	else:
		_cast_cost = 0.0   # the effect starts: nothing is refunded from here
		_cast_took_charge = false
		ctx.progress = 1.0
		_end_charge()   # a released charge-up: the effect starts, its indicator goes
		_executing = true
		_refresh_effect_inputs(ctx)   # CHAMPIONS CH5: self_missing_health as the effect starts
		_use_up_ability_empowers(ability, ctx)   # AB10: before ABILITY_CAST, so a rule can grant the next one
		_apply_bonus_self_statuses(ability, ctx)   # AB12: passing conditional bonuses' self statuses
		# The effect starts: ABILITY_CAST rules fire now (never for a cast
		# that was cancelled or interrupted before this point). AB8.
		_emit_ability_cast(ability, ctx)
		await ability.execute(unit, ctx)
		_executing = false

	if not is_instance_valid(unit):
		return
	if rooted:
		unit.movement.remove_move_lock(&"casting")
	unit.attack.remove_lock(&"casting")
	_remove_cast_move_speed()
	if ability.resets_auto_attack and not interrupted:
		unit.attack.reset_attack_timer()
	casting = false
	casting_slot = &""
	if not interrupted:
		_advance_recast(slot, ctx.part)
	cast_finished.emit(slot, ability)


## The cast's locks and walking rules: the &"casting" attack lock (it also
## cancels a swing or windup); a root (&"casting" move lock) if the ability
## roots or is a channel (a channel also stops the unit); otherwise the walk
## multiplier. A cast with no cast time doesn't root; a charge-up
## (`charging`) roots for the whole hold if it roots at all.
func _begin_cast_locks(ability: Ability, charging: bool) -> void:
	unit.attack.add_lock(&"casting")   # also cancels an auto-attack windup
	var has_time := charging or ability.cast_time > 0.0
	# Channels always root, whatever roots_during_cast says.
	var rooted := (ability.roots_during_cast or ability.is_channel()) and has_time
	if rooted:
		unit.movement.add_move_lock(&"casting")
	if ability.is_channel() and has_time:
		unit.movement.stop()
	_cast_rooted = rooted
	_add_cast_move_speed(ability)


## Walking during a non-rooting cast: cast_move_speed_multiplier as one
## PERCENT_MULT move_speed modifier (stacks with slows instead of competing
## with them). Nothing is added at 1.0.
func _add_cast_move_speed(ability: Ability) -> void:
	if ability.roots_during_cast or ability.is_channel():
		return
	if is_equal_approx(ability.cast_move_speed_multiplier, 1.0):
		return
	unit.stats_component.add_modifier(StatModifier.create(&"move_speed",
		StatModifier.Type.PERCENT_MULT, ability.cast_move_speed_multiplier - 1.0, CAST_MOVE_SPEED_SOURCE))


## A caster freed mid-cast without dying first takes its telegraph with it:
## once this node is gone, the _do_cast() waiting on the cast time never
## resumes, so nothing else would remove it.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and casting and not _executing:
		_remove_telegraph(_cast_ctx)


## A cast that doesn't go off (cancelled, stunned, dead) takes its telegraph
## with it.
func _remove_telegraph(ctx: CastContext) -> void:
	if ctx != null and is_instance_valid(ctx.telegraph):
		ctx.telegraph.queue_free()


# --- Cast progress and presentation hooks (ABILITIES AB14) -------------------------------

## One physics tick of the cast time (deferred from _physics_process(), so it
## runs after every node's physics this frame, like the old timer). The
## seconds left go down by delta x the cast speed, the same float steps the
## SceneTreeTimer took, so the effect lands on the same frame; progress =
## 1 - left / total. The cast's telegraph follows it (and the 3D view's
## cast_anim, UnitView). At 0 left the waiting _do_cast() resumes (the effect
## starts in this same frame).
func _advance_cast_time(delta: float) -> void:
	if not _cast_time_running or _cast_ctx == null or not can_process():
		return
	_cast_time_left -= delta * _get_valid_cast_speed(_cast_ability)
	var done := _cast_time_left <= CAST_TIME_EPSILON
	_cast_ctx.progress = 1.0 if done else clampf(1.0 - _cast_time_left / _cast_time_total, 0.0, 1.0)
	if is_instance_valid(_cast_ctx.telegraph):
		_cast_ctx.telegraph.set_progress(_cast_ctx.progress)
	if done:
		_cast_time_running = false
		_cast_time_elapsed.emit()


## A cancel or interrupt ends the cast time: the waiting _do_cast() resumes
## (its serial was already bumped, so it stops). Nothing if no cast time is
## running.
func _stop_cast_time() -> void:
	if _cast_time_running:
		_cast_time_running = false
		_cast_time_elapsed.emit()


## get_cast_speed(), guarded: a speed of 0 or less would hang the cast, so it
## counts as 1.0 (push_error once).
func _get_valid_cast_speed(ability: Ability) -> float:
	var speed := get_cast_speed(ability)
	if speed > 0.0:
		return speed
	if not _cast_speed_warned:
		_cast_speed_warned = true
		push_error("AbilityComponent: cast speed %s for '%s' is not above 0; using 1.0" % [speed, ability.id if ability else &""])
	return 1.0


# --- Augments (ABILITIES AB8) ---------------------------------------------------------

## Adds an augment under `source_id` (an item, a passive, a status). The same
## augment id from several sources counts once: its EVENT rules are added
## once, under AbilityAugment.get_rules_source_id(). An exact-scope FLAG an
## ability in a slot doesn't support is reported (push_error) once.
func add_augment(augment: AbilityAugment, source_id: StringName) -> void:
	if augment == null or augment.id == &"":
		push_error("AbilityComponent: an augment needs an id")
		return
	var before := _snapshot_slot_abilities()
	var was_active := _is_augment_active(augment.id)
	_augments.append([augment, source_id])
	if not was_active and augment.kind == AbilityAugment.Kind.EVENT:
		_add_event_rules(augment)
	if augment.kind == AbilityAugment.Kind.FLAG:
		for slot in SLOTS:
			for ability in [get_base_ability(slot), get_ability(slot)]:
				if ability != null:
					_check_flag_support(augment, ability)
	_after_augments_changed(before)


## Takes back every augment added under `source_id`. An augment another
## source still grants stays.
func remove_augments_from(source_id: StringName) -> void:
	var removed: Array = _augments.filter(func(e: Array) -> bool: return e[1] == source_id)
	if removed.is_empty():
		return
	var before := _snapshot_slot_abilities()
	_augments = _augments.filter(func(e: Array) -> bool: return e[1] != source_id)
	for e: Array in removed:
		var augment: AbilityAugment = e[0]
		if augment.kind == AbilityAugment.Kind.EVENT and not _is_augment_active(augment.id):
			unit.remove_reaction_rules_from(augment.get_rules_source_id())
	_after_augments_changed(before)


## Replaces the tooltip template of the ability with id `ability_id` (that
## exact id: a REPLACE variant keeps its own) while `source_id` has it
## (TALENTS T3b: a talent that reshapes the ability rewrites what it says).
## The template uses the same {placeholders} as Ability.description.
func set_description_override(ability_id: StringName, template: String, source_id: StringName) -> void:
	_description_overrides.append([ability_id, template, source_id])
	for slot in SLOTS:
		augments_changed.emit(slot)


## Takes back every description override added under `source_id`.
func remove_description_overrides_from(source_id: StringName) -> void:
	var before := _description_overrides.size()
	_description_overrides = _description_overrides.filter(func(e: Array) -> bool: return e[2] != source_id)
	if _description_overrides.size() != before:
		for slot in SLOTS:
			augments_changed.emit(slot)


## The template replacing `ability`'s description now ("" = none). The last
## one added wins.
func get_description_override(ability: Ability) -> String:
	if ability == null:
		return ""
	for i in range(_description_overrides.size() - 1, -1, -1):
		var e: Array = _description_overrides[i]
		if e[0] == ability.id:
			return e[1]
	return ""


## The sources whose description override is on `ability` now.
func _description_override_sources(ability: Ability) -> Array[StringName]:
	var out: Array[StringName] = []
	for e: Array in _description_overrides:
		if ability != null and e[0] == ability.id:
			out.append(e[2])
	return out


## True when every source granting augment `augment_id` has rewritten the
## ability's description: its tooltip line would only repeat it.
func _is_line_muted(augment_id: StringName, muting: Array[StringName]) -> bool:
	if muting.is_empty():
		return false
	for e: Array in _augments:
		if (e[0] as AbilityAugment).id == augment_id and not muting.has(e[1]):
			return false
	return true


## The augments active on the slot's ability (what a press would cast): its
## FLAGs and EVENTs (by scope) and the REPLACE that made it the slot's
## ability. Each id once.
func get_augments(slot: StringName) -> Array[AbilityAugment]:
	var result: Array[AbilityAugment] = []
	var ability := get_ability(slot)
	var base := get_base_ability(slot)
	if ability == null:
		return result
	for augment in _get_unique_augments():
		match augment.kind:
			AbilityAugment.Kind.REPLACE:
				if augment.replacement == ability and ability != base:
					result.append(augment)
			_:
				if _scope_matches(augment, ability):
					result.append(augment)
	return result


## REPLACE augments for the slot's ability that aren't used, each with why:
## [{augment, reason}]. Only one REPLACE per ability; the first added wins.
func get_disabled_augments(slot: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var base := get_base_ability(slot)
	if base == null:
		return result
	var winner := _get_replace_augment(base)
	for augment in _get_unique_augments():
		if augment.kind == AbilityAugment.Kind.REPLACE and augment != winner \
				and augment.scope == StringName("ability:" + base.id):
			result.append({"augment": augment, "reason": "another replacement is active"})
	return result


## The FLAG augments active on `ability` that it supports (its supported_flags).
func get_flags(ability: Ability) -> Array[StringName]:
	var flags: Array[StringName] = []
	if ability == null:
		return flags
	for augment in _get_unique_augments():
		if augment.kind == AbilityAugment.Kind.FLAG and _scope_matches(augment, ability) \
				and ability.supported_flags.has(augment.id) and not flags.has(augment.id):
			flags.append(augment.id)
	return flags


## Tooltip lines for `ability`: one per active augment on it, then one per
## disabled REPLACE for it (Ability.get_tooltip() appends them).
func get_augment_tooltip_lines(ability: Ability) -> PackedStringArray:
	var lines: PackedStringArray = []
	if ability == null or _augments.is_empty():
		return lines
	var replaced_id := ability.variant_of if ability.variant_of != &"" else ability.id
	# A source that rewrote the description already says what its augments do.
	var muting := _description_override_sources(ability)
	for augment in _get_unique_augments():
		match augment.kind:
			AbilityAugment.Kind.FLAG:
				if _scope_matches(augment, ability) and ability.supported_flags.has(augment.id) and not _is_line_muted(augment.id, muting):
					lines.append(augment.get_tooltip_line())
			AbilityAugment.Kind.EVENT:
				if _scope_matches(augment, ability) and not _is_line_muted(augment.id, muting):
					lines.append(augment.get_tooltip_line())
			AbilityAugment.Kind.REPLACE:
				if augment.replacement == ability:
					lines.append(augment.get_tooltip_line())
				elif augment.scope == StringName("ability:" + replaced_id):
					lines.append("%s (disabled: another replacement is active)" % augment.get_tooltip_line())
	return lines


func _get_unique_augments() -> Array[AbilityAugment]:
	var result: Array[AbilityAugment] = []
	var seen := {}
	for e: Array in _augments:
		var augment: AbilityAugment = e[0]
		if not seen.has(augment.id):
			seen[augment.id] = true
			result.append(augment)
	return result


func _is_augment_active(id: StringName) -> bool:
	for e: Array in _augments:
		if (e[0] as AbilityAugment).id == id:
			return true
	return false


func _scope_matches(augment: AbilityAugment, ability: Ability) -> bool:
	return augment.scope != &"" and ability.get_modifier_scopes().has(augment.scope)


## The winning REPLACE for `base`: the first added whose scope is its id.
func _get_replace_augment(base: Ability) -> AbilityAugment:
	var scope := StringName("ability:" + base.id)
	for augment in _get_unique_augments():
		if augment.kind == AbilityAugment.Kind.REPLACE and augment.scope == scope and augment.replacement != null:
			return augment
	return null


func _get_replacement(base: Ability) -> Ability:
	if _augments.is_empty():
		return null
	var augment := _get_replace_augment(base)
	return augment.replacement if augment != null else null


## One copy of each rule, under the augment's rules source id; a rule without
## an ability scope gets the augment's (the shared .tres isn't changed).
func _add_event_rules(augment: AbilityAugment) -> void:
	for rule in augment.rules:
		if rule == null:
			continue
		var copy: ReactionRule = rule.duplicate()
		if copy.required_ability_scope == &"":
			copy.required_ability_scope = augment.scope
		unit.add_reaction_rule(copy, augment.get_rules_source_id())


## An exact-scope FLAG on an ability that doesn't list it: an error, once.
## A tag-scoped FLAG is just ignored by abilities that don't support it.
func _check_flag_support(augment: AbilityAugment, ability: Ability) -> void:
	if augment.scope != StringName("ability:" + ability.id) or ability.supported_flags.has(augment.id):
		return
	var key := "%s/%s" % [ability.id, augment.id]
	if not _flag_errors.has(key):
		_flag_errors[key] = true
		push_error("Ability '%s' doesn't support the FLAG augment '%s'; it's ignored" % [ability.id, augment.id])


func _snapshot_slot_abilities() -> Dictionary:
	var result := {}
	for slot in SLOTS:
		result[slot] = get_ability(slot)
	return result


## After augments change: a walk-into-range cast whose slot now casts another
## ability is dropped; every slot reports the change.
func _after_augments_changed(before: Dictionary) -> void:
	if not _pending.is_empty() and before.get(_pending.slot) != get_ability(_pending.slot):
		_pending.clear()
	for slot in SLOTS:
		augments_changed.emit(slot)


# --- Cooldown changes (ModifyCooldownGameplayEffect; AB8) ----------------------------

## The slots whose ability (what a press casts) matches `scope`
## (&"ability:<id>" / &"tag:<tag>"); &"" = every slot with an ability.
func get_slots_matching(scope: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for slot in SLOTS:
		var ability := get_ability(slot)
		if ability != null and (scope == &"" or ability.get_modifier_scopes().has(scope)):
			result.append(slot)
	return result


## Takes `seconds` off the slot's running cooldown (recharge). Reaching 0
## finishes it (+1 charge). Nothing while no cooldown runs (ready, or a recast
## window open: its cooldown hasn't started).
func reduce_cooldown(slot: StringName, seconds: float) -> void:
	if not _is_recharging(slot) or seconds <= 0.0:
		return
	_cooldown_left[slot] = maxf(_cooldown_left[slot] - seconds, 0.0)
	if _cooldown_left[slot] <= 0.0:
		_finish_recharge(slot, get_ability(slot))


## Takes `fraction` (0.25 = 25%) of the running cooldown's time left.
func reduce_cooldown_percent(slot: StringName, fraction: float) -> void:
	if _is_recharging(slot):
		reduce_cooldown(slot, _cooldown_left[slot] * clampf(fraction, 0.0, 1.0))


## Finishes the running recharge: +1 charge (with 1 charge: the cooldown is
## done). Not a full refill. Nothing while no cooldown runs.
func reset_cooldown(slot: StringName) -> void:
	if _is_recharging(slot):
		_cooldown_left[slot] = 0.0
		_finish_recharge(slot, get_ability(slot))


## Spends every charge of the slot and starts its recharge, as if it had just
## been cast (no cast, no cost, no effect): a test hook for the enemies test
## and the sandbox's brain scenarios (ENEMIES_AI AI1). Nothing during a
## recast sequence.
func start_cooldown(slot: StringName) -> void:
	var ability := get_ability(slot)
	if ability == null or _recast.has(slot):
		return
	_charges[slot] = 0
	charges_changed.emit(slot, 0, get_max_charges(slot))
	_start_recharge(slot, ability)


func _is_recharging(slot: StringName) -> bool:
	return get_ability(slot) != null and not _recast.has(slot) \
		and get_charges(slot) < get_max_charges(slot) and _cooldown_left.get(slot, 0.0) > 0.0


# --- Free casts (CastAbilityGameplayEffect; AB8) -------------------------------------

## Casts `ability` for free at `aim` (and `target`), granted by `source_id`: no
## cost, no cooldown, no charge, no cast time, no slot, no locks, and a cast in
## progress isn't touched. Its effect runs at once: cast_sound, ability_cast
## (one reaction link deeper than whatever asked for it), execute(). Refused
## (false) for a dead or cast-blocked unit.
func try_cast_free(ability: Ability, aim: Vector2, target: Unit, source_id: StringName) -> bool:
	if ability == null or not unit.is_alive() or unit.is_cast_blocked():
		return false
	var ctx := _make_cast_context(&"", ability, aim, target)   # a VECTOR ability: a tap at the aim (AB13)
	if is_instance_valid(target):
		ctx.target = target   # the unit hit or the triggering cast's target (else the condition target, if any)
		_fill_inputs(ctx, ability)
	ctx.is_free = true
	ctx.source_id = source_id
	ctx.chain_depth = Reactions.get_chain_depth()   # a rule's effects run one link deeper already
	ctx.progress = 1.0   # AB14: no cast time
	Audio.play_on(ability.cast_sound, unit)
	ability.play_cast_vfx(unit, ctx)   # AB14 hook (no cast_anim: a free cast runs alongside the unit's own cast)
	_apply_bonus_self_statuses(ability, ctx)
	_emit_ability_cast(ability, ctx)
	ability.execute(unit, ctx)   # not awaited: it runs alongside anything else
	return true


## At a cast's effect start (ABILITIES AB10): the unit's ABILITY_CAST
## empowers whose scope matches the ability go into ctx.empowers and are
## removed. Only casts the player or the AI started (not free casts).
func _use_up_ability_empowers(ability: Ability, ctx: CastContext) -> void:
	if unit.status_component == null or ctx.is_free:
		return
	var scopes := ability.get_modifier_scopes()
	for e in unit.status_component.get_empowers(StatusEffect.EmpowerTrigger.ABILITY_CAST):
		if e.empower_scope == &"" or scopes.has(e.empower_scope):
			ctx.empowers.append(e)
			unit.status_component.remove_status(e.id)


## Events.ability_cast at the cast's chain depth (0 for a slot cast).
func _emit_ability_cast(ability: Ability, ctx: CastContext) -> void:
	if ctx.chain_depth > 0:
		Reactions.run_at_depth(ctx.chain_depth, func() -> void: Events.ability_cast.emit(unit, ability, ctx))
	else:
		Events.ability_cast.emit(unit, ability, ctx)


## One slot's recharge, each physics frame: while below max_charges, the
## timer counts one cooldown (duration taken when it starts), then +1 charge
## and, if still below max, the next one. At or above max nothing runs (a
## lowered max leaves extra charges until they're spent). Going from 0
## charges to 1 is "ready": cooldown_finished and the ready_sound.
func _update_recharge(slot: StringName, delta: float) -> void:
	var ability := get_ability(slot)
	var maximum := get_max_charges(slot)
	if ability == null or get_charges(slot) >= maximum:
		_cooldown_left[slot] = 0.0
		return
	if _recast.has(slot):
		return   # a recast sequence is going: the recharge waits (and pauses) until it ends
	if _cooldown_left[slot] <= 0.0:
		_start_recharge(slot, ability)   # below max with no timer: a raised max
		return
	_cooldown_left[slot] = maxf(_cooldown_left[slot] - delta, 0.0)
	if _cooldown_left[slot] > 0.0:
		return
	_finish_recharge(slot, ability)


## A recharge is done: +1 charge; going from 0 to 1 is "ready" (the ping and
## cooldown_finished); still below max, the next recharge starts.
func _finish_recharge(slot: StringName, ability: Ability) -> void:
	var maximum := get_max_charges(slot)
	_cooldown_left[slot] = 0.0
	_charges[slot] = get_charges(slot) + 1
	charges_changed.emit(slot, _charges[slot], maximum)
	if _charges[slot] == 1:
		Audio.play(ability.ready_sound, 1.0, SoundEvent.Priority.HIGH)
		cooldown_finished.emit(slot, ability)
	if _charges[slot] < maximum:
		_start_recharge(slot, ability)


## Starts the timer for the slot's next charge: one cooldown (scoped
## modifiers, then haste; get_cooldown_duration()).
func _start_recharge(slot: StringName, ability: Ability) -> void:
	_cooldown_total[slot] = get_cooldown_duration(ability)
	_cooldown_left[slot] = _cooldown_total[slot]


## Recast windows count down between parts (game time), never while one of
## the slot's parts is being cast. Running out ends the sequence.
func _update_recast_windows(delta: float) -> void:
	for slot: StringName in _recast.keys():
		if casting and casting_slot == slot:
			continue
		_recast[slot].left = maxf(_recast[slot].left - delta, 0.0)
		if _recast[slot].left <= 0.0:
			_end_recast(slot)


## A part finished (its effect ran): open the window for the next part, or
## end the sequence after the last one.
func _advance_recast(slot: StringName, part: int) -> void:
	if not _recast.has(slot):
		return
	var seq: Dictionary = _recast[slot]
	var ability: Ability = seq.ability
	if part >= ability.recast_count:
		_end_recast(slot)
		return
	seq.next = part + 1
	seq.left = ability.get_param(unit, &"recast_window")
	recast_window_started.emit(slot, seq.next, seq.left)


## The sequence is over: the slot's recharge can start (the next physics
## frame, _update_recharge()).
func _end_recast(slot: StringName) -> void:
	if _recast.erase(slot):
		recast_window_finished.emit(slot)


## A cancel or interrupt gives back the charge the cast took. Back at max,
## the recharge stops (with max_charges 1: the cooldown is refunded); below
## max, a recharge already running keeps its progress. A refund never pings.
## A first part refunded this way never started its sequence. A later part
## gives back only its cost (_refund_cost()); its window keeps the time it
## had (it doesn't run during a part).
func _restore_slot(slot: StringName) -> void:
	if not _cast_took_charge:
		return
	_cast_took_charge = false
	_recast.erase(slot)
	_charges[slot] = get_charges(slot) + 1
	if _charges[slot] >= get_max_charges(slot):
		_cooldown_left[slot] = 0.0
	charges_changed.emit(slot, _charges[slot], get_max_charges(slot))


## Gives back what the cast in progress paid (a cancel or interrupt before
## its effect). The pool clamps at its max.
func _refund_cost() -> void:
	if _cast_cost > 0.0 and unit.resource_pool != null:
		unit.resource_pool.restore(_cast_cost)
	_cast_cost = 0.0


func _remove_cast_move_speed() -> void:
	unit.stats_component.remove_modifiers_from(CAST_MOVE_SPEED_SOURCE)
