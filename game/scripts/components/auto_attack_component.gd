class_name AutoAttackComponent
extends Node
## League-of-Legends-style auto-attacks for a Unit.
##
## attack(target)       - chase the target until in range, then attack it
##                        repeatedly (like right-clicking an enemy).
## attack_move(point)   - walk toward a point, attacking the nearest enemy
##                        that comes within acquisition range (A-click).
## cancel()             - drop the attack order (moving does this).
##
## Each attack has a windup (the unit is rooted; moving now cancels the
## attack and refunds it) and then the hit. After the hit you are free to
## move while the attack timer counts down; that's what lets players
## "kite" / "orb walk". The attack timer starts when the windup starts, like
## LoL, so attack speed = attacks per second.
##
## Combo mode (COMBAT.md): with `combo` set, the unit instead swings on
## command, Hades-style: try_swing(direction) starts the next swing of the
## combo toward that direction. Each swing roots for its whole duration, hits
## everything in its arc at the end of its windup (through the hit pipeline),
## then recovers. The next swing continues the combo; combo_reset_time
## without attacking starts it over. cancel_swing() (dash, stun, a cast)
## stops a swing with no hit and resets the combo. The player uses this; the
## League-style orders above stay for enemies.

signal windup_started(target: Unit, windup_time: float)
signal attack_landed(target: Unit, damage: float)
signal windup_cancelled
## Combo mode: a swing started (index 0 = first swing of the combo).
signal swing_started(index: int, direction: Vector2, swing: AttackSwing)
## Combo mode: the swing's hit moment. `targets` is empty for a whiff.
signal swing_landed(index: int, targets: Array[Unit])
## Combo mode: a swing stopped early (dash, stun, cast, death). No hit if it
## was still winding up. The combo resets.
signal swing_cancelled
## Combo mode: a swing ran to the end of its recovery.
signal swing_finished

enum State { IDLE, CHASING, WINDUP, BACKSWING }

const BONUS_ATTACK_SPEED_SOURCE := &"bonus_attack_speed"
## Move lock held for the whole of a combo swing.
const SWING_LOCK := &"attack_swing"
## Swing timers count as done within this many seconds of 0, so float
## residue (0.3 - 18 x 1/60) doesn't add a physics frame.
const SWING_TIME_EPSILON := 0.0001

## Extra range (LoL units) beyond attack range in which attack-move will
## pick up targets.
@export var attack_move_acquire_bonus: float = 250.0
## How often to re-path while chasing a moving target (seconds).
@export var chase_repath_interval: float = 0.1
## Hades-style combo (COMBAT.md). Set = combo mode (the player); null = the
## League-style attack (enemies).
@export var combo: AttackCombo

var unit: Unit
var state: State = State.IDLE
var target: Unit
## Bonus attack speed as a fraction (0.3 = +30%). Kept as a thin wrapper:
## setting it replaces one PERCENT_ADD attack_speed modifier on the unit's
## StatsComponent (source BONUS_ATTACK_SPEED_SOURCE). New code adds its own
## StatModifiers instead (STATS.md).
var bonus_attack_speed: float = 0.0:
	set(value):
		bonus_attack_speed = value
		var stats := get_node_or_null(^"../StatsComponent") as StatsComponent
		if stats == null:
			return
		stats.remove_modifiers_from(BONUS_ATTACK_SPEED_SOURCE)
		if value != 0.0:
			stats.add_modifier(StatModifier.create(&"attack_speed", StatModifier.Type.PERCENT_ADD, value, BONUS_ATTACK_SPEED_SOURCE))

var _attack_timer: float = 0.0     # time until the next attack may start
var _windup_left: float = 0.0
var _repath_timer: float = 0.0
var _attack_moving: bool = false
var _attack_move_point: Vector2
var _locks: Dictionary = {}        # e.g. casting an ability
## Bonuses applied to the next attack that lands, then removed.
## id -> {bonus_damage, on_hit: Callable, time_left}
var _next_attack_mods: Dictionary = {}

# Combo mode
var _swing: AttackSwing                # the swing playing out, or null
var _swing_index: int = 0
var _swing_direction: Vector2 = Vector2.RIGHT
var _swing_landed: bool = false        # its hit has happened (recovery)
var _swing_windup_left: float = 0.0
var _swing_left: float = 0.0           # until the swing ends
var _swing_fresh: bool = false         # started this physics frame
var _next_swing_index: int = 0
var _combo_reset_left: float = 0.0


func _ready() -> void:
	unit = get_parent() as Unit
	assert(unit != null, "AutoAttackComponent must be a child of a Unit")


# --- Stats ----------------------------------------------------------------------

## Attacks per second: the attack_speed stat (base_attack_speed x (1 + bonus),
## capped by UnitStats.attack_speed_cap).
func get_attack_speed() -> float:
	return unit.stats_component.get_stat(&"attack_speed")


func get_attack_interval() -> float:
	return 1.0 / get_attack_speed()


func get_windup_time() -> float:
	return get_attack_interval() * unit.stats.attack_windup


func get_range_px() -> float:
	return Units.to_px(unit.stats_component.get_stat(&"attack_range"))


func is_in_range(other: Unit) -> bool:
	return unit.edge_distance_to(other) <= get_range_px()


func is_attacking() -> bool:
	return target != null or _attack_moving


func is_winding_up() -> bool:
	return state == State.WINDUP


# --- Combo mode -----------------------------------------------------------------

## A combo swing is playing out (windup or recovery).
func is_swinging() -> bool:
	return _swing != null


## The swing's hit has landed and it's recovering.
func is_in_recovery() -> bool:
	return _swing != null and _swing_landed


## A new swing may start now: combo mode, alive, not swinging, no locks
## (stun, casting).
func can_swing() -> bool:
	return combo != null and not combo.swings.is_empty() and unit.is_alive() \
		and _swing == null and _locks.is_empty()


## While swinging: the current swing's index. Otherwise: the index the next
## swing will use (0 once the combo has reset).
func get_combo_index() -> int:
	return _swing_index if _swing != null else _next_swing_index


## The swing playing out (null when not swinging). Still set when
## swing_landed is emitted.
func get_current_swing() -> AttackSwing:
	return _swing


## Where the current (or last) swing was aimed, locked at its start.
func get_swing_direction() -> Vector2:
	return _swing_direction


## Combo speed multiplier: attack_speed / base attack speed (1.0 at base;
## +20% bonus attack speed = 1.2). Every swing timing is divided by it.
func get_swing_speed() -> float:
	var base := unit.stats_component.get_base_value(&"attack_speed")
	if base <= 0.0:
		return 1.0
	return maxf(get_attack_speed() / base, 0.01)


## Reach of a swing in px (before hit forgiveness): the attack_range stat
## x the swing's reach_multiplier, from the feet to the target's edge.
func get_swing_reach_px(swing: AttackSwing) -> float:
	return get_range_px() * swing.reach_multiplier


## Starts the next swing of the combo toward `direction`. Returns false if a
## swing can't start now (see can_swing()). dash_strike picks the combo's
## dash_strike swing when it has one (COMBAT C12).
func try_swing(direction: Vector2, dash_strike: bool = false) -> bool:
	if not can_swing() or direction.length() < 0.01:
		return false
	var index := _next_swing_index if _combo_reset_left > 0.0 else 0
	var swing: AttackSwing = combo.swings[index]
	if dash_strike and combo.dash_strike != null:
		swing = combo.dash_strike
	var speed := get_swing_speed()
	_swing = swing
	_swing_index = index
	_swing_direction = direction.normalized()
	_swing_landed = false
	_swing_windup_left = swing.windup / speed
	_swing_left = maxf(swing.duration, swing.windup) / speed
	_swing_fresh = true
	_combo_reset_left = 0.0
	unit.movement.add_move_lock(SWING_LOCK)
	swing_started.emit(index, _swing_direction, swing)
	return true


## Stops the current swing (no hit if it hasn't landed yet), releases the
## root and resets the combo.
func cancel_swing() -> void:
	if _swing == null:
		return
	_end_swing()
	_next_swing_index = 0
	_combo_reset_left = 0.0
	swing_cancelled.emit()


# --- Orders ---------------------------------------------------------------------

func attack(new_target: Unit) -> void:
	if not _is_valid_target(new_target):
		return
	_attack_moving = false
	if new_target == target and state != State.IDLE:
		return  # Re-clicking the same target doesn't restart the attack.
	if state == State.WINDUP:
		_cancel_windup()
	target = new_target
	state = State.CHASING
	_repath_timer = 0.0


func attack_move(point: Vector2) -> void:
	if state == State.WINDUP:
		_cancel_windup()
	target = null
	_attack_moving = true
	_attack_move_point = point
	state = State.IDLE
	unit.movement.move_to(point)


func cancel() -> void:
	cancel_swing()
	if state == State.WINDUP:
		_cancel_windup()
	target = null
	_attack_moving = false
	state = State.IDLE


## Cancel the current windup but keep attacking the same target afterwards
## (used when casting an ability mid-windup).
func interrupt() -> void:
	if state == State.WINDUP:
		_cancel_windup()
		state = State.CHASING


## Auto-attack reset: the next attack can start right away.
func reset_attack_timer() -> void:
	_attack_timer = 0.0
	if state == State.BACKSWING:
		state = State.CHASING


## Empower the next auto-attack (e.g. "your next attack deals +50 damage and
## slows"). on_hit receives the target. duration < 0 = until used.
func add_next_attack_modifier(id: StringName, bonus_damage: float, on_hit: Callable = Callable(), duration: float = -1.0) -> void:
	_next_attack_mods[id] = {"bonus_damage": bonus_damage, "on_hit": on_hit, "time_left": duration}


func has_next_attack_modifier(id: StringName) -> bool:
	return _next_attack_mods.has(id)


func is_empowered() -> bool:
	return not _next_attack_mods.is_empty()


## A lock (stun, casting) stops attacking: it interrupts a windup and
## cancels a combo swing.
func add_lock(id: StringName) -> void:
	_locks[id] = true
	interrupt()
	cancel_swing()


func remove_lock(id: StringName) -> void:
	_locks.erase(id)


# --- Update ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	for id in _next_attack_mods.keys():
		var mod: Dictionary = _next_attack_mods[id]
		if mod.time_left >= 0.0:
			mod.time_left -= delta
			if mod.time_left <= 0.0:
				_next_attack_mods.erase(id)
	if not unit.is_alive():
		return
	if combo != null:
		_update_combo(delta)

	if target != null and not _is_valid_target(target):
		target = null
		if state == State.WINDUP:
			_cancel_windup()
		state = State.IDLE
		if _attack_moving:
			unit.movement.move_to(_attack_move_point)

	if _attack_moving and target == null:
		var found := _find_attack_move_target()
		if found:
			target = found
			state = State.CHASING
		elif not unit.movement.has_order():
			_attack_moving = false  # Arrived with nothing to hit.

	if target == null or not _locks.is_empty():
		return

	match state:
		State.CHASING, State.IDLE:
			if is_in_range(target):
				unit.movement.stop()
				if _attack_timer <= 0.0:
					_start_windup()
			else:
				_repath_timer -= delta
				if _repath_timer <= 0.0 or not unit.movement.has_order():
					_repath_timer = chase_repath_interval
					unit.movement.move_to(_approach_point())
		State.WINDUP:
			_windup_left -= delta
			if _windup_left <= 0.0:
				_land_attack()
		State.BACKSWING:
			if _attack_timer <= 0.0:
				state = State.CHASING


# --- Combo swings ---------------------------------------------------------------

func _update_combo(delta: float) -> void:
	if _swing == null:
		if _combo_reset_left > 0.0:
			_combo_reset_left -= delta
			if _combo_reset_left <= 0.0:
				_next_swing_index = 0
		return
	if _swing_fresh:
		_swing_fresh = false  # Don't count the frame it started in.
		return
	if not _swing_landed:
		_swing_windup_left -= delta
		if _swing_windup_left <= SWING_TIME_EPSILON:
			_land_swing()
	_swing_left -= delta
	if _swing_landed and _swing_left <= SWING_TIME_EPSILON:
		_finish_swing()


## The hit moment: every enemy in the arc (with hit forgiveness) takes a
## basic attack hit. The next-attack modifiers (Iron Resolve) are used up by
## the first swing that hits anything, and apply to every enemy it hits.
func _land_swing() -> void:
	_swing_landed = true
	var forgiveness := 1.0 + combo.hit_forgiveness
	var reach := get_swing_reach_px(_swing) * forgiveness
	var half_arc := deg_to_rad(_swing.arc_deg) * 0.5 * forgiveness
	var targets := AbilityUtil.in_cone(unit, unit.global_position, _swing_direction, reach, half_arc)
	var bonus := 0.0
	var on_hits: Array[Callable] = []
	var empowered := not targets.is_empty() and not _next_attack_mods.is_empty()
	if empowered:
		for mod in _next_attack_mods.values():
			bonus += mod.bonus_damage
			if mod.on_hit.is_valid():
				on_hits.append(mod.on_hit)
		_next_attack_mods.clear()
	for t in targets:
		var ctx := HitPipeline.basic_attack(unit, t, _swing)
		ctx.base_damage += bonus
		ctx.highlight = empowered
		HitPipeline.resolve(ctx)
		if not ctx.blocked:
			for f in on_hits:
				if is_instance_valid(t):
					f.call(t)
	swing_landed.emit(_swing_index, targets)


func _finish_swing() -> void:
	var count := combo.swings.size()
	_next_swing_index = (_swing_index + 1) % count
	_combo_reset_left = combo.combo_reset_time
	_end_swing()
	swing_finished.emit()


func _end_swing() -> void:
	_swing = null
	_swing_landed = false
	_swing_fresh = false
	unit.movement.remove_move_lock(SWING_LOCK)


func _start_windup() -> void:
	state = State.WINDUP
	_windup_left = get_windup_time()
	_attack_timer = get_attack_interval()
	unit.movement.add_move_lock(&"attack_windup")
	windup_started.emit(target, _windup_left)


func _land_attack() -> void:
	unit.movement.remove_move_lock(&"attack_windup")
	state = State.BACKSWING
	var dmg := unit.stats_component.get_stat(&"attack_damage")
	var hit := target
	var on_hits: Array[Callable] = []
	for mod in _next_attack_mods.values():
		dmg += mod.bonus_damage
		if mod.on_hit.is_valid():
			on_hits.append(mod.on_hit)
	var empowered := not _next_attack_mods.is_empty()
	_next_attack_mods.clear()
	attack_landed.emit(hit, dmg)
	hit.take_damage(dmg, unit, empowered)
	for f in on_hits:
		if is_instance_valid(hit):
			f.call(hit)


func _cancel_windup() -> void:
	unit.movement.remove_move_lock(&"attack_windup")
	_attack_timer = 0.0  # Cancelled attacks are refunded.
	state = State.IDLE
	windup_cancelled.emit()


## Where to walk to attack the target: a free spot just inside attack range,
## on our side of the target if possible, otherwise fanning out around it.
## This is what makes a group of melee units surround a target instead of
## queueing up behind each other.
func _approach_point() -> Vector2:
	var tpos := target.global_position
	var my_pos := unit.global_position
	var reach := get_range_px() + unit.get_gameplay_radius_px() + target.get_gameplay_radius_px()
	var dist := my_pos.distance_to(tpos)
	# Far away: just head for the target; pick a slot when we get close.
	if dist > reach + 60.0:
		return tpos
	var slot_dist := maxf(reach * 0.85, unit.get_pathing_radius_px() + target.get_pathing_radius_px() + 2.0)
	var base := (my_pos - tpos).angle() if dist > 0.01 else 0.0
	var map := unit.get_world_2d().navigation_map
	var map_ready := NavigationServer2D.map_get_iteration_id(map) > 0
	var others: Array = []
	for node in unit.get_tree().get_nodes_in_group("units"):
		var o := node as Unit
		if o != unit and o != target and o.is_alive():
			others.append(o)
	for step in 10:
		for side: float in ([1.0, -1.0] if step > 0 else [1.0]):
			var a: float = base + side * step * deg_to_rad(18.0)
			var p := tpos + Vector2.from_angle(a) * slot_dist
			# Skip spots inside walls.
			if map_ready and NavigationServer2D.map_get_closest_point(map, p).distance_to(p) > 2.0:
				continue
			var free := true
			for o: Unit in others:
				if o.global_position.distance_to(p) < unit.get_pathing_radius_px() + o.get_pathing_radius_px() + 1.0:
					free = false
					break
			if free:
				return p
	return tpos


func _is_valid_target(t: Unit) -> bool:
	return t != null and is_instance_valid(t) and t.is_alive() and unit.is_enemy_of(t)


func _find_attack_move_target() -> Unit:
	var best: Unit = null
	var best_dist := INF
	var reach := get_range_px() + Units.to_px(attack_move_acquire_bonus)
	for node in unit.get_tree().get_nodes_in_group("units"):
		var other := node as Unit
		if not _is_valid_target(other):
			continue
		var d := unit.edge_distance_to(other)
		if d <= reach and d < best_dist:
			best = other
			best_dist = d
	return best
