class_name AbilityComponent
extends Node
## Holds a unit's Q/W/E/R abilities and runs them LoL-style:
## - cooldowns (reduced by ability haste: cd * 100 / (100 + haste))
## - cast time: the unit is rooted and can't auto-attack, but keeps its
##   move/attack order and carries on afterwards
## - casting cancels an auto-attack windup, and (by default) resets the
##   auto-attack timer so the next auto comes out immediately
## - targeted (UNIT) abilities walk into range first if you're too far
## - getting stunned during the cast time interrupts it (cooldown refunded)
## - per ability: walk during the cast at a speed multiplier, or cancel the
##   cast with a dash (dash_cancelable) or a new move press (cancel_on_move)

signal cast_started(slot: StringName, ability: Ability, ctx: CastContext)
signal cast_finished(slot: StringName, ability: Ability)
signal cast_failed(slot: StringName, reason: String)
## A cast was cancelled during its cast time (e.g. by a dash). cast_finished
## is emitted right after, so existing listeners still clean up.
signal cast_cancelled(slot: StringName, ability: Ability)

const SLOTS: Array[StringName] = [&"q", &"w", &"e", &"r"]
## Source id of the move_speed modifier from Ability.cast_move_speed_multiplier.
## One cast at a time, so one id.
const CAST_MOVE_SPEED_SOURCE := &"ability_casting"

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


func _ready() -> void:
	unit = get_parent() as Unit
	assert(unit != null, "AbilityComponent must be a child of a Unit")
	for s in SLOTS:
		_cooldown_left[s] = 0.0
		_cooldown_total[s] = 1.0


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


func get_cooldown_duration(ability: Ability) -> float:
	return unit.stats_component.get_cooldown(ability.cooldown)


func is_ready(slot: StringName) -> bool:
	return get_ability(slot) != null and get_cooldown_left(slot) <= 0.0


func can_cast(slot: StringName) -> bool:
	return is_ready(slot) and not casting and unit.is_alive() and not unit.is_stunned()


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
	if not can_cast(slot):
		cast_failed.emit(slot, "not ready" if not is_ready(slot) else "busy")
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
			ctx.point = origin + to_aim.limit_length(Units.to_px(ability.cast_range))
		Ability.Targeting.UNIT:
			if target_unit == null or not target_unit.is_alive() or not unit.is_enemy_of(target_unit):
				cast_failed.emit(slot, "no target")
				return false
			ctx.target = target_unit
			if unit.edge_distance_to(target_unit) > Units.to_px(ability.cast_range):
				_pending = {"slot": slot, "target": target_unit}
				_pending_repath = 0.0
				unit.attack.cancel()
				return true

	_pending.clear()
	_do_cast(slot, ability, ctx)
	return true


func cancel_pending() -> void:
	_pending.clear()


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
## cancelled by a new movement press (Ability.cancel_on_move).
func can_cancel_cast_on_move() -> bool:
	if not casting or _executing:
		return false
	var ability := get_ability(casting_slot)
	return ability != null and ability.cancel_on_move


## Cancels the current cast because the unit started moving, if its ability
## allows it. Works exactly like the dash cancel. Returns true if cancelled.
func try_cancel_cast_on_move() -> bool:
	if not can_cancel_cast_on_move():
		return false
	_cancel_cast()
	return true


func _cancel_cast() -> void:
	var slot := casting_slot
	var ability := get_ability(slot)
	_cast_serial += 1  # The _do_cast waiting on the cast time sees this and stops.
	if _cast_rooted:
		unit.movement.remove_move_lock(&"casting")
	unit.attack.remove_lock(&"casting")
	_remove_cast_move_speed()
	_cooldown_left[slot] = 0.0
	casting = false
	casting_slot = &""
	cast_cancelled.emit(slot, ability)
	cast_finished.emit(slot, ability)


func _physics_process(delta: float) -> void:
	for s in SLOTS:
		if _cooldown_left[s] > 0.0:
			_cooldown_left[s] = maxf(_cooldown_left[s] - delta, 0.0)

	if _pending.is_empty() or casting:
		return
	var target: Unit = _pending.target
	var slot: StringName = _pending.slot
	var ability := get_ability(slot)
	if not is_instance_valid(target) or not target.is_alive() or not unit.is_alive():
		_pending.clear()
		return
	if unit.edge_distance_to(target) <= Units.to_px(ability.cast_range):
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

	unit.attack.add_lock(&"casting")   # also cancels an auto-attack windup
	# cancel_on_move casts always root (a channel), whatever roots_during_cast says.
	var rooted := (ability.roots_during_cast or ability.cancel_on_move) and ability.cast_time > 0.0
	if rooted:
		unit.movement.add_move_lock(&"casting")
	if ability.cancel_on_move and ability.cast_time > 0.0:
		unit.movement.stop()
	_cast_rooted = rooted
	_add_cast_move_speed(ability)
	cast_started.emit(slot, ability, ctx)

	if ability.cast_time > 0.0:
		await unit.get_tree().create_timer(ability.cast_time, false, true).timeout
	if serial != _cast_serial:
		return  # Cancelled during the cast time; try_cancel_cast() cleaned up.

	var interrupted := not is_instance_valid(unit) or not unit.is_alive() or unit.is_stunned()
	if interrupted:
		if is_instance_valid(unit) and unit.is_alive():
			_cooldown_left[slot] = 0.0  # Refund interrupted casts.
	else:
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
	if ability.roots_during_cast or ability.cancel_on_move:
		return
	if is_equal_approx(ability.cast_move_speed_multiplier, 1.0):
		return
	unit.stats_component.add_modifier(StatModifier.create(&"move_speed",
		StatModifier.Type.PERCENT_MULT, ability.cast_move_speed_multiplier - 1.0, CAST_MOVE_SPEED_SOURCE))


func _remove_cast_move_speed() -> void:
	unit.stats_component.remove_modifiers_from(CAST_MOVE_SPEED_SOURCE)
