class_name StatusComponent
extends Node
## Every status effect on a unit (COMBAT.md, Status effects): stuns, slows,
## hastes, damage over time. A child of the Unit (Unit.status_component).
##
## Applying one adds its StatModifiers (source &"status_<id>"), its move and
## attack locks (lock id = the status id), its VFX, and starts its timer and
## DoT ticks. Removing it (timer, remove_status(), death) takes all of that
## back. Timers run in game time (_physics_process), so they follow hitstop
## and pausing.
##
## Re-applying follows the status's stack_rule. Tenacity shortens &"cc"
## statuses. DoT ticks are &"dot" hits through HitPipeline with the applier
## as the source (kill credit); their damage is snapshotted when applied.

signal status_applied(effect: StatusEffect)
signal status_removed(effect: StatusEffect)

## Timers at or below this are done (float residue, like combo swings).
const EPSILON := 0.0001


## One status on the unit.
class ActiveStatus:
	extends RefCounted
	var effect: StatusEffect
	## Who applied it (kill credit for DoT). May be freed later.
	var source: Unit
	## Remaining seconds per stack; -1 = until removed.
	var stack_times: Array[float] = []
	var tick_left: float = 0.0
	## DoT damage per stack per tick, snapshotted when applied.
	var tick_amount: float = 0.0
	var vfx: Node

	func get_time_left() -> float:
		var longest := 0.0
		for t in stack_times:
			if t < 0.0:
				return -1.0
			longest = maxf(longest, t)
		return longest


var unit: Unit

var _active: Dictionary = {}   # StringName id -> ActiveStatus


func _ready() -> void:
	unit = get_parent() as Unit


# --- Commands -----------------------------------------------------------------

## Applies `effect` from `source` (null = the environment). duration_override
## >= 0 replaces the effect's duration. Tenacity shortens &"cc" statuses.
## Returns false if nothing was applied (dead unit, IGNORE while active, a
## zero duration).
func apply_status(effect: StatusEffect, source: Unit = null, duration_override: float = -1.0) -> bool:
	if effect == null or effect.id == &"":
		push_error("StatusComponent: tried to apply a status without an id")
		return false
	if unit == null or not unit.is_alive():
		return false
	var duration := duration_override if duration_override >= 0.0 else effect.duration
	if duration > 0.0 and effect.is_cc():
		duration *= 1.0 - _get_tenacity()
	if duration >= 0.0 and duration <= EPSILON:
		return false
	var active: ActiveStatus = _active.get(effect.id)
	if active == null:
		active = ActiveStatus.new()
		active.stack_times.append(duration)
		_start(active, effect, source)
		_active[effect.id] = active
	else:
		match active.effect.stack_rule:
			StatusEffect.StackRule.IGNORE:
				return false
			StatusEffect.StackRule.REFRESH_LONGER:
				var left := active.get_time_left()
				if duration < 0.0 or (left >= 0.0 and duration > left):
					active.stack_times[0] = duration
			StatusEffect.StackRule.REFRESH:
				_stop(active)
				active.stack_times = [duration]
				_start(active, effect, source)
			StatusEffect.StackRule.STACK:
				if active.stack_times.size() < maxi(active.effect.max_stacks, 1):
					active.stack_times.append(duration)
				else:
					active.stack_times[_shortest_stack(active)] = duration
				if is_instance_valid(source):
					active.source = source
				active.tick_amount = _snapshot_tick(effect, source)
				_sync_modifiers(active)
	status_applied.emit(active.effect)
	Events.status_applied.emit(unit, active.effect)
	return true


## Removes a status and everything it added. Returns false if it wasn't there.
func remove_status(id: StringName) -> bool:
	var active: ActiveStatus = _active.get(id)
	if active == null:
		return false
	_active.erase(id)
	_stop(active)
	status_removed.emit(active.effect)
	if is_instance_valid(unit):
		Events.status_removed.emit(unit, active.effect)
	return true


## Removes every status (death).
func clear() -> void:
	for id: StringName in _active.keys():
		remove_status(id)


# --- Queries ------------------------------------------------------------------

func has_status(id: StringName) -> bool:
	return _active.has(id)


func has_tag(tag: StringName) -> bool:
	for active: ActiveStatus in _active.values():
		if active.effect.tags.has(tag):
			return true
	return false


## Every tag of every active status, once each.
func get_tags() -> Array[StringName]:
	var result: Array[StringName] = []
	for active: ActiveStatus in _active.values():
		for t in active.effect.tags:
			if not result.has(t):
				result.append(t)
	return result


func get_status_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in _active.keys():
		result.append(id)
	return result


## The active StatusEffect with this id, or null.
func get_status(id: StringName) -> StatusEffect:
	var active: ActiveStatus = _active.get(id)
	return active.effect if active else null


## Seconds left (the longest stack); -1 = until removed; 0 = not active.
func get_time_left(id: StringName) -> float:
	var active: ActiveStatus = _active.get(id)
	return active.get_time_left() if active else 0.0


func get_stacks(id: StringName) -> int:
	var active: ActiveStatus = _active.get(id)
	return active.stack_times.size() if active else 0


## Who applied it (null = the environment, or freed since).
func get_source(id: StringName) -> Unit:
	var active: ActiveStatus = _active.get(id)
	if active == null or not is_instance_valid(active.source):
		return null
	return active.source


func blocks_cast() -> bool:
	for active: ActiveStatus in _active.values():
		if active.effect.blocks_cast:
			return true
	return false


func blocks_dash() -> bool:
	for active: ActiveStatus in _active.values():
		if active.effect.blocks_dash:
			return true
	return false


# --- Update -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	for id: StringName in _active.keys():
		var active: ActiveStatus = _active.get(id)
		if active == null:
			continue   # removed by an earlier tick (death)
		if active.effect.is_dot():
			active.tick_left -= delta
			while active.tick_left <= EPSILON and _active.get(id) == active and unit.is_alive():
				_tick(active)
				active.tick_left += active.effect.tick_interval
		if _active.get(id) != active:
			continue
		var expired := false
		for i in range(active.stack_times.size() - 1, -1, -1):
			if active.stack_times[i] < 0.0:
				continue
			active.stack_times[i] -= delta
			if active.stack_times[i] <= EPSILON:
				active.stack_times.remove_at(i)
				expired = true
		if active.stack_times.is_empty():
			remove_status(id)
		elif expired:
			_sync_modifiers(active)


# --- Internals ----------------------------------------------------------------

## Adds what the status gives: modifiers, locks, VFX, DoT snapshot.
func _start(active: ActiveStatus, effect: StatusEffect, source: Unit) -> void:
	active.effect = effect
	active.source = source
	active.tick_amount = _snapshot_tick(effect, source)
	active.tick_left = effect.tick_interval
	_sync_modifiers(active)
	if effect.blocks_move:
		unit.movement.add_move_lock(effect.id)
	if effect.blocks_attack:
		unit.attack.add_lock(effect.id)   # also cancels a windup or swing
	if effect.vfx != null:
		active.vfx = effect.vfx.instantiate()
		unit.add_child(active.vfx)


## Takes back what _start() added.
func _stop(active: ActiveStatus) -> void:
	var effect := active.effect
	if is_instance_valid(unit) and unit.stats_component != null:
		unit.stats_component.remove_modifiers_from(effect.get_source_id())
	if is_instance_valid(unit):
		if effect.blocks_move:
			unit.movement.remove_move_lock(effect.id)
		if effect.blocks_attack:
			unit.attack.remove_lock(effect.id)
	if is_instance_valid(active.vfx):
		active.vfx.queue_free()
	active.vfx = null


## The status's modifiers, once per stack, under its source id.
func _sync_modifiers(active: ActiveStatus) -> void:
	var stats := unit.stats_component
	if stats == null:
		return
	var source_id := active.effect.get_source_id()
	stats.remove_modifiers_from(source_id)
	var mods: Array[StatModifier] = []
	for i in active.stack_times.size():
		for template in active.effect.modifiers:
			var mod := StatModifier.create(template.stat, template.type, template.value, source_id, template.scope)
			mods.append(mod)
	if not mods.is_empty():
		stats.add_modifiers(mods)


## One DoT tick: a &"dot" hit (plus the status's tags) through the pipeline,
## from the applier. Can't crit, triggers no on-hit, starts no i-frames.
func _tick(active: ActiveStatus) -> void:
	var ctx := HitContext.new()
	ctx.source = active.source if is_instance_valid(active.source) else null
	ctx.target = unit
	ctx.base_damage = active.tick_amount * active.stack_times.size()
	ctx.damage_type = active.effect.tick_damage_type
	ctx.can_crit = false
	ctx.proc_coefficient = 0.0
	ctx.add_tag(&"dot")
	for t in active.effect.tags:
		ctx.add_tag(t)
	HitPipeline.resolve(ctx)


## DoT damage per tick from the applier's stats now (snapshot).
func _snapshot_tick(effect: StatusEffect, source: Unit) -> float:
	var amount := effect.tick_damage
	if effect.tick_ad_ratio != 0.0 and is_instance_valid(source) and source.stats_component != null:
		amount += effect.tick_ad_ratio * source.stats_component.get_stat(&"attack_damage")
	return amount


func _shortest_stack(active: ActiveStatus) -> int:
	var index := 0
	for i in active.stack_times.size():
		var t := active.stack_times[i]
		if t >= 0.0 and (active.stack_times[index] < 0.0 or t < active.stack_times[index]):
			index = i
	return index


func _get_tenacity() -> float:
	if unit.stats_component == null:
		return 0.0
	return unit.stats_component.get_stat(&"tenacity")
