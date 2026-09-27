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
## - per ability: walk during the cast at a speed multiplier, or cancel the
##   cast with a dash (dash_cancelable) or a new move press (a channel:
##   cast_style CHANNEL or cancel_on_move)

signal cast_started(slot: StringName, ability: Ability, ctx: CastContext)
signal cast_finished(slot: StringName, ability: Ability)
## A cast was refused. reason: one of the FAIL_* strings (ABILITIES.md, HUD
## feedback); the HUD shows a cue per reason.
signal cast_failed(slot: StringName, reason: String)
## A cast was cancelled during its cast time (e.g. by a dash). cast_finished
## is emitted right after, so existing listeners still clean up.
signal cast_cancelled(slot: StringName, ability: Ability)
## A slot's cooldown counted down to 0 (not a refund). Plays the ability's
## ready_sound (AUDIO.md).
signal cooldown_finished(slot: StringName, ability: Ability)

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

@export var q: Ability
@export var w: Ability
@export var e: Ability
@export var r: Ability

var unit: Unit
var casting: bool = false
var casting_slot: StringName = &""

var _cooldown_left: Dictionary = {}   # slot -> seconds
var _cooldown_total: Dictionary = {}  # slot -> seconds (for the HUD sweep)
var _pending: Dictionary = {}         # queued targeted cast: {slot, target}
var _pending_repath: float = 0.0
var _cast_serial: int = 0        # bumped by each cast and by a cancel
var _cast_rooted: bool = false
var _executing: bool = false     # true while ability.execute() runs
var _cast_ctx: CastContext       # the cast in progress (for its telegraph)
var _cast_cost: float = 0.0      # what the cast in progress paid (refunded if it doesn't go off)


func _ready() -> void:
	unit = get_parent() as Unit
	assert(unit != null, "AbilityComponent must be a child of a Unit")
	for s in SLOTS:
		_cooldown_left[s] = 0.0
		_cooldown_total[s] = 1.0
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

func get_ability(slot: StringName) -> Ability:
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


func is_ready(slot: StringName) -> bool:
	return get_ability(slot) != null and get_cooldown_left(slot) <= 0.0


## Ready, not casting, alive and not blocked. Doesn't look at the cost:
## a press that can't be afforded fails at once instead of being buffered
## (can_afford(); ABILITIES.md, Costs).
func can_cast(slot: StringName) -> bool:
	return is_ready(slot) and not casting and unit.is_alive() and not unit.is_cast_blocked()


## The ability's resource_cost after scoped modifiers.
func get_cost(ability: Ability) -> float:
	return ability.get_param(unit, &"resource_cost")


## True if the unit can pay the slot's cost now. A unit without a resource
## pool (resource type NONE, enemies) always can: it pays nothing.
func can_afford(slot: StringName) -> bool:
	var ability := get_ability(slot)
	if ability == null:
		return false
	return unit.resource_pool == null or unit.resource_pool.can_afford(get_cost(ability))


## Why the slot can't be cast right now (a FAIL_* string), or "" if it can.
## Blocked (stunned, silenced) comes first, then not ready, then busy, then
## the cost.
func get_fail_reason(slot: StringName) -> String:
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
	return ""


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
	var reason := get_fail_reason(slot)
	if reason != "":
		cast_failed.emit(slot, reason)
		return false

	var ctx := CastContext.new()
	ctx.slot = slot
	var origin := unit.global_position
	var to_aim := aim - origin
	ctx.direction = to_aim.normalized() if to_aim.length() > 0.01 else Vector2.RIGHT
	ctx.point = aim

	match ability.targeting:
		Ability.Targeting.SELF:
			ctx.point = origin
		Ability.Targeting.POINT:
			ctx.point = origin + to_aim.limit_length(Units.to_px(ability.get_param(unit, &"cast_range")))
		Ability.Targeting.UNIT:
			if target_unit == null or not target_unit.is_alive() or not unit.is_enemy_of(target_unit):
				cast_failed.emit(slot, FAIL_NO_TARGET)
				return false
			ctx.target = target_unit
			# Out of range, or no line of sight (COMBAT C7): walk until both hold.
			if unit.edge_distance_to(target_unit) > Units.to_px(ability.get_param(unit, &"cast_range")) \
					or not ability.can_reach_through_walls(unit.global_position, target_unit):
				_pending = {"slot": slot, "target": target_unit}
				_pending_repath = 0.0
				unit.attack.cancel()
				return true

	_pending.clear()
	_do_cast(slot, ability, ctx)
	return true


func cancel_pending() -> void:
	_pending.clear()


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
	var ability := get_ability(casting_slot)
	return ability != null and ability.dash_cancelable


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
	var ability := get_ability(casting_slot)
	return ability != null and ability.is_channel()


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
	var ability := get_ability(slot)
	_remove_telegraph(_cast_ctx)
	_cast_serial += 1  # The _do_cast waiting on the cast time sees this and stops.
	if _cast_rooted:
		unit.movement.remove_move_lock(&"casting")
	unit.attack.remove_lock(&"casting")
	_remove_cast_move_speed()
	if unit.is_alive():
		_cooldown_left[slot] = 0.0  # Refund interrupted casts.
		_refund_cost()
	casting = false
	casting_slot = &""
	cast_finished.emit(slot, ability)
	return true


func _cancel_cast() -> void:
	var slot := casting_slot
	var ability := get_ability(slot)
	_remove_telegraph(_cast_ctx)
	_cast_serial += 1  # The _do_cast waiting on the cast time sees this and stops.
	if _cast_rooted:
		unit.movement.remove_move_lock(&"casting")
	unit.attack.remove_lock(&"casting")
	_remove_cast_move_speed()
	_cooldown_left[slot] = 0.0
	_refund_cost()
	casting = false
	casting_slot = &""
	cast_cancelled.emit(slot, ability)
	cast_finished.emit(slot, ability)


func _physics_process(delta: float) -> void:
	for s in SLOTS:
		if _cooldown_left[s] > 0.0:
			_cooldown_left[s] = maxf(_cooldown_left[s] - delta, 0.0)
			if _cooldown_left[s] <= 0.0:
				var ready_ability := get_ability(s)
				if ready_ability != null:
					Audio.play(ready_ability.ready_sound, 1.0, SoundEvent.Priority.HIGH)
				cooldown_finished.emit(s, ready_ability)

	if _pending.is_empty() or casting:
		return
	var target: Unit = _pending.target
	var slot: StringName = _pending.slot
	var ability := get_ability(slot)
	if not is_instance_valid(target) or not target.is_alive() or not unit.is_alive():
		_pending.clear()
		return
	if unit.edge_distance_to(target) <= Units.to_px(ability.get_param(unit, &"cast_range")) \
			and ability.can_reach_through_walls(unit.global_position, target):
		_pending.clear()
		unit.movement.stop()
		try_cast(slot, target.global_position, target)
	elif not unit.is_stunned():
		_pending_repath -= delta
		if _pending_repath <= 0.0:
			_pending_repath = 0.1
			unit.movement.move_to(target.global_position)


func _do_cast(slot: StringName, ability: Ability, ctx: CastContext) -> void:
	_cast_serial += 1
	var serial := _cast_serial
	casting = true
	casting_slot = slot
	_cooldown_total[slot] = get_cooldown_duration(ability)
	_cooldown_left[slot] = _cooldown_total[slot]
	# Pay at cast start (try_cast() checked it's affordable); refunded if the
	# cast is cancelled or interrupted before its effect.
	_cast_cost = 0.0
	if unit.resource_pool != null:
		var cost := get_cost(ability)
		if unit.resource_pool.try_spend(cost):
			_cast_cost = maxf(cost, 0.0)

	unit.attack.add_lock(&"casting")   # also cancels an auto-attack windup
	# Channels always root, whatever roots_during_cast says.
	var rooted := (ability.roots_during_cast or ability.is_channel()) and ability.cast_time > 0.0
	if rooted:
		unit.movement.add_move_lock(&"casting")
	if ability.is_channel() and ability.cast_time > 0.0:
		unit.movement.stop()
	_cast_rooted = rooted
	_add_cast_move_speed(ability)
	_cast_ctx = ctx
	Audio.play_on(ability.cast_sound, unit)
	cast_started.emit(slot, ability, ctx)
	ability.on_cast_started(unit, ctx)
	if is_instance_valid(ctx.telegraph):
		ctx.telegraph.play_sound(ability.telegraph_sound)   # stops with the telegraph (AUDIO.md)

	if ability.cast_time > 0.0:
		await unit.get_tree().create_timer(ability.cast_time, false, true).timeout
	if serial != _cast_serial:
		return  # Cancelled during the cast time; try_cancel_cast() cleaned up.

	var interrupted := not is_instance_valid(unit) or not unit.is_alive() or unit.is_cast_blocked()
	if interrupted:
		_remove_telegraph(ctx)
		if is_instance_valid(unit) and unit.is_alive():
			_cooldown_left[slot] = 0.0  # Refund interrupted casts.
			_refund_cost()
	else:
		_cast_cost = 0.0   # the effect starts: nothing is refunded from here
		_executing = true
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
	cast_finished.emit(slot, ability)


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


## Gives back what the cast in progress paid (a cancel or interrupt before
## its effect). The pool clamps at its max.
func _refund_cost() -> void:
	if _cast_cost > 0.0 and unit.resource_pool != null:
		unit.resource_pool.restore(_cast_cost)
	_cast_cost = 0.0


func _remove_cast_move_speed() -> void:
	unit.stats_component.remove_modifiers_from(CAST_MOVE_SPEED_SOURCE)
