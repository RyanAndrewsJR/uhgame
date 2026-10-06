extends Node
## The enemy brains' shared services (ENEMIES_AI.md, Brains; AI1), autoloaded
## as Brains after Progress and Loot, before Audio:
## - the global rules: `table` (EnemyAITable);
## - the think schedule: brains register; each physics tick, in game time
##   (hitstop slows it, the pause stops it), the brains whose tick slot comes
##   up think, so at 60 Hz and 10 thinks a second a sixth of them think on
##   each tick; wake() makes one think on the next tick (urgent);
## - the one shared read of the party per tick (get_snapshot()), and each
##   champion's idle time;
## - `rng`, seedable: each brain draws its own stream from it when it
##   registers, so the same seed gives the same decisions;
## - the difficulty tier's stand-in (difficulty_tier) until DUNGEONS D8;
## - (AI2) every enemy with data (register_enemy()), the attack tokens (each
##   champion's pool, the queue, the timeouts and releases), the shout
##   (shout(): a pack wakes alert_delay s after its first member notices) and
##   the fodder ring around each target (pack_think_rate times a second).
## - (AI3b) each champion's walk velocity for aim lead (get_walk_velocity()):
##   what's on screen over the last walk_velocity_time s, counted only since
##   its last dash, push, leap or blink (a dash is never led).
## AI6 adds the whiffs, AI7 sleeping.

const TABLE_PATH := "res://data/enemy_ai_tables/enemy_ai_table_default.tres"
## A champion counts as acting while it moves faster than this (px/s).
const IDLE_SPEED_PX := 5.0
## A champion that moved farther than this in one tick blinked or teleported:
## its walk starts again (px).
const WALK_JUMP_PX := 24.0

## The global rules.
var table: EnemyAITable
## Seeded once at start (randomize()); a test seeds it before spawning brains.
var rng := RandomNumberGenerator.new()
## The run's difficulty tier (1–5): which ability slots exist
## (EnemyAbilitySlot.min_difficulty_tier). A stand-in until DUNGEONS D8.
var difficulty_tier: int = 1
## Draws each brain's floor drawings (band, target line) in the sandbox's
## overlay (SandboxBrains reads it).
var debug_draw: bool = false

var _brains: Array[EnemyBrain] = []
var _urgent: Array[EnemyBrain] = []
var _next_slot := 0
var _tick := 0
var _time := 0.0
var _snapshot: PartySnapshot
var _snapshot_builds := 0
var _idle: Dictionary = {}   # champion Unit -> idle seconds
## Think costs since the last reset_think_stats() (the performance budget).
var _think_count := 0
var _think_usec := 0
var _think_usec_samples: PackedInt32Array = PackedInt32Array()
var _party: Array[Unit] = []
var _party_frame := -1
var _enemies: Array[Enemy] = []   # every enemy with data (AI2)
## Attack tokens (AI2): target Unit -> Array of {enemy, cost, since}.
var _tokens: Dictionary = {}
## The token queue: target Unit -> Array of {enemy, patience, distance, at}.
var _token_queue: Dictionary = {}
## Enemy -> the game time it may ask for a token again.
var _token_rest: Dictionary = {}
## Shouts on their way: {enemy, target, at}.
var _alerts: Array[Dictionary] = []
## Each target's fodder ring angle (target Unit -> radians), kept while it
## has fodder on it.
var _ring_anchor: Dictionary = {}
## Thinks asked for at a game time: [brain, time] (wake_at()).
var _timed_wakes: Array = []
## Each champion's walk (AI3b): Unit -> Array of [game time, position] since
## its last dash or push, and Unit -> its walk velocity (px/s).
var _walk: Dictionary = {}
var _walk_velocity: Dictionary = {}


func _ready() -> void:
	table = load(TABLE_PATH)
	rng.randomize()


## Game time (s): the physics deltas summed (hitstop slows it; paused, it stops).
func get_time() -> float:
	return _time


## Physics ticks between two thinks of one brain (6 at 60 Hz and 10 a second).
func get_think_period() -> int:
	var tps := Engine.physics_ticks_per_second
	return maxi(1, roundi(tps / maxf(table.think_rate, 0.01)))


func register(brain: EnemyBrain) -> void:
	if brain == null or _brains.has(brain):
		return
	brain.rng.seed = rng.randi()
	brain.think_slot = _next_slot % get_think_period()
	_next_slot += 1
	_brains.append(brain)


func unregister(brain: EnemyBrain) -> void:
	_brains.erase(brain)
	_urgent.erase(brain)


func get_brains() -> Array[EnemyBrain]:
	return _brains.duplicate()


## `brain` thinks on the next physics tick (something urgent: its enemy
## aggroed, its target went, a stun ended...).
func wake(brain: EnemyBrain) -> void:
	if brain != null and not _urgent.has(brain):
		_urgent.append(brain)


## `brain` thinks on the first physics tick at or after game time `time`
## (AI3: an attack it saw coming, once its reaction time has passed).
func wake_at(brain: EnemyBrain, time: float) -> void:
	if brain != null:
		_timed_wakes.append([brain, time])


func _physics_process(delta: float) -> void:
	_time += delta
	_tick += 1
	_update_tokens()
	_deliver_alerts()
	if _tick % get_pack_think_period() == 0:
		_update_fodder_rings()
	if _brains.is_empty():
		_urgent.clear()
		_timed_wakes.clear()
		return
	for i in range(_timed_wakes.size() - 1, -1, -1):
		var w: Array = _timed_wakes[i]
		if not is_instance_valid(w[0]):
			_timed_wakes.remove_at(i)
		elif float(w[1]) <= _time + 0.0001:
			wake(w[0])
			_timed_wakes.remove_at(i)
	_update_idle(delta)
	_update_walk()
	var period := get_think_period()
	var slot := _tick % period
	var due: Array[EnemyBrain] = []
	for b in _brains:
		if b.think_slot == slot or _urgent.has(b):
			due.append(b)
	_urgent.clear()
	for b in due:
		if not is_instance_valid(b) or not b.think():
			continue
		_think_count += 1
		_think_usec += b.get_think_usec()
		if _think_usec_samples.size() < 100000:
			_think_usec_samples.append(b.get_think_usec())


# --- The party ----------------------------------------------------------------------

## The champions the brains read: the groups `player` and `party` (ALLIES adds
## `party`), each once. Companions are never Units, so never here. Read once
## per physics tick (every enemy asks: noticing, the pick); don't change the
## array it returns.
func get_party() -> Array[Unit]:
	var frame := Engine.get_physics_frames()
	if frame == _party_frame:
		return _party
	_party_frame = frame
	var out: Array[Unit] = []
	for group: StringName in [&"player", &"party"]:
		for node in get_tree().get_nodes_in_group(group):
			var u := node as Unit
			if u != null and not out.has(u):
				out.append(u)
	_party = out
	return out


## The one shared read of the party for this physics tick, built the first
## time a brain asks in it.
func get_snapshot() -> PartySnapshot:
	var frame := Engine.get_physics_frames()
	if _snapshot == null or _snapshot.frame != frame:
		_snapshot = PartySnapshot.build(get_party(), table, _idle, frame, get_tree().get_nodes_in_group(Projectile.GROUP), _walk_velocity)
		_snapshot_builds += 1
	return _snapshot


## How many snapshots were built so far (tests: one per tick at most).
func get_snapshot_builds() -> int:
	return _snapshot_builds


## Seconds since `unit` last moved, swung, dashed or cast (0 if not tracked).
func get_idle_time(unit: Node) -> float:
	return _idle.get(unit, 0.0)


## Each champion's idle time, every tick while brains exist.
func _update_idle(delta: float) -> void:
	var party := get_party()
	for u: Variant in _idle.keys():
		if not is_instance_valid(u) or not party.has(u):
			_idle.erase(u)
	for u in party:
		var acting: bool = u.velocity.length() > IDLE_SPEED_PX or u.attack.is_swinging() \
			or u.attack.is_winding_up() or (u.abilities != null and u.abilities.casting)
		_idle[u] = 0.0 if acting else float(_idle.get(u, 0.0)) + delta


## `unit`'s walk velocity (px/s; AI3b, aim lead): its average over the last
## walk_velocity_time s, counted only since its last dash, push, leap or
## blink. Zero while it dashes or is pushed, and until it has walked 0.05 s.
func get_walk_velocity(unit: Node) -> Vector2:
	return _walk_velocity.get(unit, Vector2.ZERO)


## Each champion's walk, every tick while brains exist (AI3b).
func _update_walk() -> void:
	var party := get_party()
	for u: Variant in _walk.keys():
		if not is_instance_valid(u) or not party.has(u):
			_walk.erase(u)
			_walk_velocity.erase(u)
	for u in party:
		var history: Array = _walk.get_or_add(u, [])
		var pos := u.global_position
		var own_walk := u.movement == null or not (u.movement.is_displaced() or u.movement.is_airborne())
		if not own_walk or (not history.is_empty() and pos.distance_to(history[-1][1]) > WALK_JUMP_PX):
			history.clear()
		if not own_walk:
			_walk_velocity[u] = Vector2.ZERO
			continue
		history.append([_time, pos])
		while history.size() > 2 and _time - float(history[1][0]) >= table.walk_velocity_time - 0.0001:
			history.pop_front()
		var dt: float = float(history[-1][0]) - float(history[0][0])
		_walk_velocity[u] = ((history[-1][1] as Vector2) - (history[0][1] as Vector2)) / dt if dt >= 0.05 else Vector2.ZERO


# --- Enemies with data (AI2) ---------------------------------------------------------------

func register_enemy(enemy: Enemy) -> void:
	if enemy != null and not _enemies.has(enemy):
		_enemies.append(enemy)


func unregister_enemy(enemy: Enemy) -> void:
	_enemies.erase(enemy)
	release_token(enemy, false)
	_token_rest.erase(enemy)
	for i in range(_alerts.size() - 1, -1, -1):
		if _alerts[i].enemy == enemy:
			_alerts.remove_at(i)


func get_enemies() -> Array[Enemy]:
	return _enemies.duplicate()


# --- Attack tokens (ENEMIES_AI.md, Groups; AI2) -------------------------------------------

## Tokens in each champion's pool now: by the difficulty tier (Ryan, I3).
## ALLIES' second champion brings a second pool (one per target).
func get_tokens_per_target() -> int:
	return table.get_tokens_per_target(difficulty_tier)


## The tokens `enemy` needs to commit: its rank's cost (a regular 1, an elite
## 2), 0 when its rank or role takes none (fodder swarms; bosses have the
## director).
func get_token_cost(enemy: Enemy) -> int:
	if enemy == null or enemy.data == null or enemy.data.behavior == null or not enemy.data.behavior.uses_tokens:
		return 0
	var rules := enemy.get_rank_rules()
	return rules.token_cost if rules != null else 0


func get_tokens_free(target: Unit) -> int:
	var used := 0
	for entry: Dictionary in _tokens.get(target, []):
		used += int(entry.cost)
	return get_tokens_per_target() - used


## The champion whose token `enemy` holds (null = none).
func get_token_target(enemy: Enemy) -> Unit:
	for target: Variant in _tokens:
		for entry: Dictionary in _tokens[target]:
			if entry.enemy == enemy:
				return target as Unit if is_instance_valid(target) else null
	return null


func has_token(enemy: Enemy) -> bool:
	return get_token_target(enemy) != null


## The enemies holding tokens on `target`, oldest first.
func get_token_holders(target: Unit) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for entry: Dictionary in _tokens.get(target, []):
		if is_instance_valid(entry.enemy):
			out.append(entry.enemy)
	return out


## True while `enemy` is in a token queue (it asked and is waiting its turn).
func is_waiting_for_token(enemy: Enemy) -> bool:
	for target: Variant in _token_queue:
		for entry: Dictionary in _token_queue[target]:
			if entry.enemy == enemy:
				return true
	return false


## Seconds before `enemy` may ask again (0 = now).
func get_token_rest_left(enemy: Enemy) -> float:
	return maxf(float(_token_rest.get(enemy, -INF)) - _time, 0.0)


## `enemy` (patience full) asks for its tokens on `target`. True when it
## holds them now (or needs none). The queue: the highest patience asks first,
## ties to the nearest; the first one waits until enough tokens are free, and
## the ones behind it wait too. After a token it can't ask again for
## token_rest_time s. A request is good for one think: a brain that stops
## asking (its patience dropped, it died) leaves the queue.
func request_token(enemy: Enemy, target: Unit, patience: float = 1.0) -> bool:
	if enemy == null or target == null or not is_instance_valid(target):
		return false
	var cost := get_token_cost(enemy)
	if cost <= 0:
		return true
	var held := get_token_target(enemy)
	if held == target:
		return true
	if held != null:
		release_token(enemy, false)
	if get_token_rest_left(enemy) > 0.0:
		return false
	_leave_other_queues(enemy, target)
	var queue: Array = _token_queue.get_or_add(target, [])
	var mine: Dictionary = {}
	for entry: Dictionary in queue:
		if entry.enemy == enemy:
			mine = entry
	if mine.is_empty():
		mine = {"enemy": enemy}
		queue.append(mine)
	mine.patience = patience
	mine.distance = enemy.edge_distance_to(target)
	mine.at = _time
	_prune_queue(target)
	queue.sort_custom(_queue_before)
	if queue.is_empty() or queue[0].enemy != enemy or get_tokens_free(target) < cost:
		return false
	queue.remove_at(0)
	(_tokens.get_or_add(target, []) as Array).append({"enemy": enemy, "cost": cost, "since": _time})
	return true


## `enemy` lets its tokens go (its commit ended, it was stunned, it died...).
## With `rest` it can't ask again for token_rest_time s (the rotation).
func release_token(enemy: Enemy, rest: bool = true) -> void:
	_leave_other_queues(enemy, null)
	for target: Variant in _tokens.keys():
		var list: Array = _tokens[target]
		for i in range(list.size() - 1, -1, -1):
			if list[i].enemy == enemy:
				list.remove_at(i)
				if rest:
					_token_rest[enemy] = _time + table.token_rest_time
		if list.is_empty():
			_tokens.erase(target)


static func _queue_before(a: Dictionary, b: Dictionary) -> bool:
	if not is_equal_approx(float(a.patience), float(b.patience)):
		return float(a.patience) > float(b.patience)
	return float(a.distance) < float(b.distance)


func _leave_other_queues(enemy: Enemy, keep: Unit) -> void:
	for target: Variant in _token_queue.keys():
		if target == keep:
			continue
		var queue: Array = _token_queue[target]
		for i in range(queue.size() - 1, -1, -1):
			if queue[i].enemy == enemy:
				queue.remove_at(i)
		if queue.is_empty():
			_token_queue.erase(target)


## Drops queue entries that weren't asked again lately (two thinks) or whose
## enemy is gone.
func _prune_queue(target: Variant) -> void:
	var queue: Array = _token_queue.get(target, [])
	var stale := 2.5 / maxf(table.think_rate, 0.01)
	for i in range(queue.size() - 1, -1, -1):
		var e: Variant = queue[i].enemy
		if not is_instance_valid(e) or not (e as Enemy).is_alive() or _time - float(queue[i].at) > stale:
			queue.remove_at(i)
	if queue.is_empty():
		_token_queue.erase(target)


## Each tick: tokens free the moment a holder dies or goes, its target dies
## or turns untargetable, it's stunned or rooted (anything that blocks moving
## or attacking: it rests), or it held them token_hold_time s (it rests).
## A brain that lost its token thinks on the next tick.
func _update_tokens() -> void:
	for target: Variant in _tokens.keys():
		var list: Array = _tokens[target]
		var target_gone: bool = not is_instance_valid(target) or not (target as Unit).is_alive() or not (target as Unit).is_targetable()
		for i in range(list.size() - 1, -1, -1):
			var entry: Dictionary = list[i]
			var e: Variant = entry.enemy
			var gone: bool = not is_instance_valid(e) or not (e as Enemy).is_alive()
			var rest := false
			if not gone and not target_gone:
				if _time - float(entry.since) >= table.token_hold_time - 0.0001 or (e as Enemy).is_cc_blocked():
					rest = true
				else:
					continue
			list.remove_at(i)
			if not gone:
				if rest:
					_token_rest[e] = _time + table.token_rest_time
				var brain := (e as Enemy).get_brain()
				if brain != null:
					wake(brain)
		if list.is_empty():
			_tokens.erase(target)
	for target: Variant in _token_queue.keys():
		if not is_instance_valid(target):
			_token_queue.erase(target)
		else:
			_prune_queue(target)
	for e: Variant in _token_rest.keys():
		if not is_instance_valid(e) or float(_token_rest[e]) <= _time:
			_token_rest.erase(e)


# --- The shout (ENEMIES_AI.md, Aggro, packs and the leash; AI2) ------------------------------

## `shouter` noticed `target` (Ryan, I5): the rest of its pack wakes
## alert_delay s later (through walls: packmates know), and so do the packs
## of the enemies within alert_radius_px of it (edge to edge) that have it in
## sight. Nobody they wake shouts on (one shout, no chain across a floor).
## Its sound plays at the shouter; Events.pack_alerted for each pack woken.
func shout(shouter: Enemy, target: Unit) -> void:
	if shouter == null or target == null:
		return
	var at := _time + table.alert_delay
	var packs: Array[Pack] = []
	var own := shouter.get_pack()
	if own != null:
		packs.append(own)
	for e in _enemies:
		if not is_instance_valid(e) or e == shouter or not e.is_alive() or e.passive:
			continue
		var pack := e.get_pack()
		if pack == null or packs.has(pack):
			continue
		if e.edge_distance_to(shouter) <= table.alert_radius_px \
				and WorldQuery.has_line_of_sight(e.global_position, shouter.global_position):
			packs.append(pack)
	for pack in packs:
		for m in pack.get_members():
			if m != shouter and not _is_alert_pending(m):
				_alerts.append({"enemy": m, "target": target, "at": at})
		Events.pack_alerted.emit(pack, target)
	if table.alert_sound != null:
		Audio.play_on(table.alert_sound, shouter)


func _is_alert_pending(enemy: Enemy) -> bool:
	for a in _alerts:
		if a.enemy == enemy:
			return true
	return false


func _deliver_alerts() -> void:
	if _alerts.is_empty():
		return
	var due: Array[Dictionary] = []
	for i in range(_alerts.size() - 1, -1, -1):
		if float(_alerts[i].at) <= _time + 0.0001:
			due.push_front(_alerts[i])
			_alerts.remove_at(i)
	for a in due:
		if is_instance_valid(a.enemy) and is_instance_valid(a.target):
			(a.enemy as Enemy).alert(a.target)


# --- The fodder ring (ENEMIES_AI.md, Groups; Ryan, I6; AI2) ---------------------------------

## Physics ticks between two pack thinks (12 at 60 Hz and 5 a second).
func get_pack_think_period() -> int:
	var tps := Engine.physics_ticks_per_second
	return maxi(1, roundi(tps / maxf(table.pack_think_rate, 0.01)))


## Gives every fighting fodder its place in the ring around its target: all
## the fodder on one target share one ring, whatever their pack (Pack.
## get_ring_spots()), nearest first. A target's ring keeps the angle it got
## when it formed (the first fodder's), so its places never turn.
func _update_fodder_rings() -> void:
	var by_target: Dictionary = {}
	for e in _enemies:
		if is_instance_valid(e) and e.uses_fodder_ring():
			(by_target.get_or_add(e.get_target(), []) as Array).append(e)
	for target: Variant in _ring_anchor.keys():
		if not by_target.has(target):
			_ring_anchor.erase(target)
	for target: Variant in by_target:
		_place_ring(target as Unit, by_target[target])


func _place_ring(target: Unit, fodder: Array) -> void:
	var tpos := target.global_position
	fodder.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return a.global_position.distance_squared_to(tpos) < b.global_position.distance_squared_to(tpos))
	var member_r := 0.0
	var reach := INF
	var positions: Array[Vector2] = []
	for e: Enemy in fodder:
		member_r = maxf(member_r, e.get_gameplay_radius_px())
		reach = minf(reach, e.attack.get_range_px())
		positions.append(e.global_position)
	var radius := target.get_gameplay_radius_px() + member_r + reach * table.fodder_ring_reach_share
	if not _ring_anchor.has(target):
		_ring_anchor[target] = (positions[0] - tpos).angle()
	var spots := Pack.get_ring_spots(tpos, positions, radius, member_r, table.fodder_ring_spacing_px, _ring_anchor[target])
	# Crowded: two closer than half the spacing (edge to edge; a settled one
	# stays put while its target is pushed about): the one farther from its
	# place walks to it.
	var crowded: Array[bool] = []
	crowded.resize(fodder.size())
	crowded.fill(false)
	var too_close := 2.0 * member_r + table.fodder_ring_spacing_px * 0.5
	for i in fodder.size():
		for j in range(i + 1, fodder.size()):
			if positions[i].distance_to(positions[j]) < too_close:
				var far_i := positions[i].distance_squared_to(spots[i]) >= positions[j].distance_squared_to(spots[j])
				crowded[i if far_i else j] = true
	for i in fodder.size():
		(fodder[i] as Enemy).set_ring_spot(spots[i], crowded[i])


# --- Measuring (Performance) --------------------------------------------------------------

## {count, mean_usec, p99_usec, max_usec} of the thinks since the last reset.
func get_think_stats() -> Dictionary:
	var samples := Array(_think_usec_samples)
	samples.sort()
	var n := samples.size()
	return {
		"count": _think_count,
		"mean_usec": float(_think_usec) / maxf(float(_think_count), 1.0),
		"p99_usec": samples[mini(n - 1, int(n * 0.99))] if n > 0 else 0,
		"max_usec": samples[n - 1] if n > 0 else 0,
	}


func reset_think_stats() -> void:
	_think_count = 0
	_think_usec = 0
	_think_usec_samples.clear()
