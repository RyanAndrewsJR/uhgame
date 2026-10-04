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
## - the difficulty tier's stand-in (difficulty_tier) until DUNGEONS D8.
## AI2 adds the attack tokens and packs, AI6 the whiffs, AI7 sleeping.

const TABLE_PATH := "res://data/enemy_ai_tables/enemy_ai_table_default.tres"
## A champion counts as acting while it moves faster than this (px/s).
const IDLE_SPEED_PX := 5.0

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


func _physics_process(delta: float) -> void:
	_time += delta
	_tick += 1
	if _brains.is_empty():
		_urgent.clear()
		return
	_update_idle(delta)
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
## `party`), each once. Companions are never Units, so never here.
func get_party() -> Array[Unit]:
	var out: Array[Unit] = []
	for group: StringName in [&"player", &"party"]:
		for node in get_tree().get_nodes_in_group(group):
			var u := node as Unit
			if u != null and not out.has(u):
				out.append(u)
	return out


## The one shared read of the party for this physics tick, built the first
## time a brain asks in it.
func get_snapshot() -> PartySnapshot:
	var frame := Engine.get_physics_frames()
	if _snapshot == null or _snapshot.frame != frame:
		_snapshot = PartySnapshot.build(get_party(), table, _idle, frame)
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
