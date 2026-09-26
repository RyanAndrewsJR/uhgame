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

signal windup_started(target: Unit, windup_time: float)
signal attack_landed(target: Unit, damage: float)
signal windup_cancelled

enum State { IDLE, CHASING, WINDUP, BACKSWING }

## Extra range (LoL units) beyond attack range in which attack-move will
## pick up targets.
@export var attack_move_acquire_bonus: float = 250.0
## How often to re-path while chasing a moving target (seconds).
@export var chase_repath_interval: float = 0.1

var unit: Unit
var state: State = State.IDLE
var target: Unit
## Bonus attack speed as a fraction (0.3 = +30%). Items and buffs add to this.
var bonus_attack_speed: float = 0.0

var _attack_timer: float = 0.0     # time until the next attack may start
var _windup_left: float = 0.0
var _repath_timer: float = 0.0
var _attack_moving: bool = false
var _attack_move_point: Vector2
var _locks: Dictionary = {}        # e.g. casting an ability
## Bonuses applied to the next attack that lands, then removed.
## id -> {bonus_damage, on_hit: Callable, time_left}
var _next_attack_mods: Dictionary = {}


func _ready() -> void:
	unit = get_parent() as Unit
	assert(unit != null, "AutoAttackComponent must be a child of a Unit")


# --- Stats ----------------------------------------------------------------------

func get_attack_speed() -> float:
	var s := unit.stats
	return minf(s.base_attack_speed * (1.0 + bonus_attack_speed), s.attack_speed_cap)


func get_attack_interval() -> float:
	return 1.0 / get_attack_speed()


func get_windup_time() -> float:
	return get_attack_interval() * unit.stats.attack_windup


func get_range_px() -> float:
	return Units.to_px(unit.stats.attack_range)


func is_in_range(other: Unit) -> bool:
	return unit.edge_distance_to(other) <= get_range_px()


func is_attacking() -> bool:
	return target != null or _attack_moving


func is_winding_up() -> bool:
	return state == State.WINDUP


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


func add_lock(id: StringName) -> void:
	_locks[id] = true
	interrupt()


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


func _start_windup() -> void:
	state = State.WINDUP
	_windup_left = get_windup_time()
	_attack_timer = get_attack_interval()
	unit.movement.add_move_lock(&"attack_windup")
	windup_started.emit(target, _windup_left)


func _land_attack() -> void:
	unit.movement.remove_move_lock(&"attack_windup")
	state = State.BACKSWING
	var dmg := unit.stats.attack_damage
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
