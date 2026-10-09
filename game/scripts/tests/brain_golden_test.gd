extends Node2D
## The enemy brain's safety net (R0, 2026-10-08; Ryan and his advisor), built
## before enemy_brain.gd is split by job (R1) so the split can show it changed
## nothing. Three parts:
##   - the golden recording: a fixed list of seeded scenarios (the fixtures of
##     enemies_test and the sandbox's H keys, at the shipped config), each run
##     headless and recorded think by think; the recording is compared with
##     its file in res://scripts/tests/golden/ (plain text, one per scenario).
##     Every scenario runs twice in this process and the two recordings must
##     match (determinism). A mutation check changes one decision number in a
##     copy of the AI table, in memory only, and the comparison must fail.
##   - the contract: every name outside enemy_brain.gd uses on EnemyBrain
##     (golden/brain_api.txt) must still exist on it.
##   - the think-time baseline: get_think_usec() per rank, printed, with a
##     loose ceiling (twice the p95 measured at R0).
## Run with the user argument --write-golden to rewrite the golden files (never
## on a normal run):
##   <godot> --headless --path . res://scenes/tests/brain_golden_test.tscn -- --write-golden
## Determinism, done here without touching gameplay code (R0's report lists
## each source):
##   - every generator seeded at each scenario's start: Brains.rng (each brain
##     draws its stream from it), the global one (Enemy's wander, damage
##     numbers), HitPipeline.crit_rng, Reactions.rng, Loot.rng;
##   - Brains' clock, tick and think-slot counter (_time, _tick, _next_slot)
##     set to the same values at each scenario's start, so both runs do the
##     same float arithmetic and get the same think slots;
##   - GameFeel.hitstop_time_scale at 1 for the run: a hitstop (an enemy
##     ability's, the slam's, a deflect's) slows game time for a stretch of
##     real time, which differs from run to run;
##   - a fresh Knight per scenario, the prototype flags at their shipped values
##     (checked), every unit freed between scenarios.
## Per tick the log holds the events in the order they came (lines with ~),
## then each recorded brain's think (when it thought); fodder has no brain, so
## a slime's ring spot is logged every 6 ticks instead.

const GOLDEN_DIR := "res://scripts/tests/golden/"
const API_PATH := GOLDEN_DIR + "brain_api.txt"
const WRITE_ARG := "--write-golden"
const SEED := 20261008
const ARENA := Vector2(-2000, 0)
## Brains' clock and tick at each scenario's start (any fixed pair works).
const START_TIME := 1000.0
const START_TICK := 60000
## Ticks between the Knight's spawn and the enemies' (t = 0).
const SETTLE_TICKS := 3
## A log over this many bytes is written with repeated lines folded (xN).
const COMPRESS_OVER := 300 * 1024
## Lines of context printed around a mismatch.
const CONTEXT_LINES := 5
## The think-time ceiling: twice the p95 measured at R0 (µs, headless; the
## highest of four runs, alone and with the other ten suites in parallel:
## regular 793–938, elite 811–887, boss 707–886, duelist 1080–1170), per rank.
## A machine difference doesn't fail it.
const THINK_P95_R0 := {&"regular": 940, &"elite": 890, &"boss": 890, &"duelist": 1170}

const KNIGHT: ChampionData = preload("res://data/champions/knight.tres")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const SLIME_SCENE: PackedScene = preload("res://scenes/enemies/slime.tscn")
const ELITE_SCENE: PackedScene = preload("res://scenes/enemies/slime_elite.tscn")
const BRUTE_SCENE: PackedScene = preload("res://scenes/enemies/test_brute.tscn")
const SKIRMISHER_SCENE: PackedScene = preload("res://scenes/enemies/test_skirmisher.tscn")
const CASTER_SCENE: PackedScene = preload("res://scenes/enemies/test_caster.tscn")
const CASTER_ELITE_SCENE: PackedScene = preload("res://scenes/enemies/test_caster_elite.tscn")
const DUELIST_SCENE: PackedScene = preload("res://scenes/enemies/test_duelist.tscn")
const BRUTE_DATA: EnemyData = preload("res://data/enemies/enemy_test_brute.tres")

## The scenarios, in order (the order is part of each file's seed). `ticks`:
## how long it runs after the enemies spawn (60 a second).
const SCENARIOS := [
	{"id": "fodder_ring", "ticks": 300, "title": "six slimes ring the Knight (fodder: no brain; enemies_test's ring fixture, him unstoppable)"},
	{"id": "brute_string", "ticks": 720, "title": "the test brute 180 px off: it holds 3 s with his kit up, then Lunge and Judgement go down: tell, commit, string"},
	{"id": "five_brutes", "ticks": 600, "title": "five test brutes round him, his kit spent: tokens shared (the shipped press on)"},
	{"id": "skirmisher", "ticks": 480, "title": "the test skirmisher 170 px off: it stalks 2 s, then his kit goes: the dive, its string, the reset hop"},
	{"id": "caster_volley", "ticks": 600, "title": "the test caster 230 px off: pokes 3 s with his kit up, then his kit spent: its commit is its 3-bolt volley"},
	{"id": "caster_fall_back", "ticks": 420, "title": "a pack of the test brute and the elite caster; the caster at 30% health falls back behind the brute (his kit up)"},
	{"id": "elite_caster", "ticks": 480, "title": "the elite test caster 220 px off, his kit ready: its snare and its bolts (pokes)"},
	{"id": "duelist_plans", "ticks": 720, "title": "the test duelist 170 px off: his escapes down 6 s (snare_first), then his whole kit down (its string)"},
	{"id": "duelist_strike_first", "ticks": 480, "title": "the test duelist with only strike_first (enemies_test's one-plan fixture), his whole kit down: a blind plan"},
	{"id": "duelist_strike_finish", "ticks": 480, "title": "the test duelist with only strike_finish, his whole kit down: a blind plan"},
	{"id": "duelist_peel", "ticks": 420, "title": "the test duelist (crowded_commit 0) with him walked into its face at t=120: the crowded episode's peel"},
	{"id": "duelist_all_in", "ticks": 420, "title": "the test duelist (crowded_commit 1) with him walked into its face at t=120: the crowded episode's all-in"},
	{"id": "elite_slime", "ticks": 900, "title": "the elite slime 140 px off, his kit spent, its big hit down at the start (12 s), 15 s: its strings, shockwave, slam and big hit (the slam on its default damage use)"},
	{"id": "cornered_caster", "ticks": 360, "title": "the test caster, him on it at t=60 (its blink), then sticking to it t=76-255: the walk away and the cornered stand"},
	{"id": "press", "ticks": 600, "title": "three test brutes and the elite slime on him, his kit spent: the press"},
	{"id": "mix_string_first", "ticks": 480, "title": "the cast-or-string mix forced to its string first (string_then_cast_chance 1): a brute with its smash and cleave arc ready"},
	{"id": "mix_cast_first", "ticks": 480, "title": "the mix forced to its cast first (string_then_cast_chance 0): the same brute"},
	{"id": "deflect_string", "ticks": 600, "title": "the test deflect on (V): a brute's strings, his deflect window opened before each hit"},
	{"id": "boss_brute", "ticks": 600, "title": "the test brute's data at boss rank: thinks 25 a second, no press, its string's extra hit"},
]
## The scenario the mutation check runs again with a changed table.
const MUTATION_SCENARIO := "brute_string"

@onready var entities: Node2D = $Entities

var knight: Player
var _passed: int = 0
var _failed: int = 0
var _write := false
var _hitstop_scale_saved := 0.05
var _region: NavigationRegion2D

# --- The recording ------------------------------------------------------------------
var _recording := false
var _rec_tick := 0
var _scenario_id := ""
var _entries: Array[Dictionary] = []
var _lines := PackedStringArray()
var _kinds: Dictionary = {}          # kind -> [count, first t, last t]
var _damage := 0.0
var _think_usec: Dictionary = {}     # rank label -> Array[int]
var _anomalies := PackedStringArray()
var _note_anomalies := true          # only the first run's are reported


func _ready() -> void:
	print("\n=== Brain golden test (R0: the recording, the contract, the think-time baseline) ===")
	Progress.get_progress(KNIGHT)   # the save guards latch off first (a test scene)
	Loot.get_inventory(KNIGHT)
	process_physics_priority = 100000   # its recording runs after every node's physics this tick
	_write = OS.get_cmdline_user_args().has(WRITE_ARG)
	_add_navigation()
	Events.unit_damaged.connect(_on_unit_damaged)
	Events.hit_deflected.connect(_on_hit_deflected)
	await _frames(3)
	_test_shipped_config()
	_hitstop_scale_saved = GameFeel.hitstop_time_scale
	GameFeel.hitstop_time_scale = 1.0

	var first := {}
	var index := 0
	for sc: Dictionary in SCENARIOS:
		var text_1: String = await _run_scenario(sc, index)
		_note_anomalies = false
		var text_2: String = await _run_scenario(sc, index)
		_note_anomalies = true
		first[sc.id] = text_1
		_compare_golden(sc, text_1)
		_compare("%s: a second run in this process records the same (determinism)" % sc.id, text_1, text_2)
		index += 1
	await _test_mutation(first)
	_test_contract()
	_test_think_time()
	_print_anomalies()

	GameFeel.hitstop_time_scale = _hitstop_scale_saved
	await _clear_world()
	Audio.stop_all()
	await _frames(10)
	print("=== %d passed, %d failed ===\n" % [_passed, _failed])
	if DisplayServer.get_name() == "headless":
		get_tree().quit(_failed)


## The prototype flags and TEMP levers at their shipped values: every
## scenario runs on the shipped config (one turns the test deflect on).
func _test_shipped_config() -> void:
	_section("The shipped config")
	_check("the deflect and poise prototypes off, the TEMP levers at 1, the mix at 0.5, no hitstop running",
		[DeflectComponent.deflect_test_enabled, PoiseComponent.poise_test_enabled, AutoAttackComponent.enemy_attack_speed_test_mult,
			AutoAttackComponent.prototype_unempowered_auto_mult, Brains.table.string_then_cast_chance, Engine.time_scale],
		[false, false, 1.0, 1.0, 0.5, 1.0])


# --- Running one scenario --------------------------------------------------------------

## Clears the world, resets every generator and Brains' clock, spawns a fresh
## Knight, then (SETTLE_TICKS later) the scenario's enemies, and records its
## ticks. Returns the recording's text.
func _run_scenario(sc: Dictionary, salt: int) -> String:
	await _clear_world()
	_reset_globals(salt)
	_scenario_id = sc.id
	_entries.clear()
	_lines = PackedStringArray()
	_kinds.clear()
	_damage = 0.0
	knight = PLAYER_SCENE.instantiate() as Player
	knight.position = ARENA
	entities.add_child(knight)
	knight.reset_physics_interpolation()
	_rec_tick = 0
	_recording = true
	var ticks: int = sc.ticks
	while _rec_tick < SETTLE_TICKS + ticks:
		await get_tree().physics_frame
		_rec_tick += 1
		if is_instance_valid(knight) and knight.is_alive():
			knight.health.heal(100000.0)
		if _rec_tick == 1:
			_place(knight, ARENA)
		elif _rec_tick == SETTLE_TICKS:
			call("_setup_" + String(sc.id))
		elif _rec_tick > SETTLE_TICKS and has_method("_tick_" + String(sc.id)):
			call("_tick_" + String(sc.id), _rec_tick - SETTLE_TICKS)
	await get_tree().physics_frame   # the last tick's recording ran in it
	_recording = false
	_end_anomalies()
	if has_method("_teardown_" + String(sc.id)):
		call("_teardown_" + String(sc.id))
	return _build_text(sc, salt)


## Frees every unit (the Knight too) and waits for Brains to let them go.
func _clear_world() -> void:
	_recording = false
	for child in entities.get_children():
		child.queue_free()
	knight = null
	await _frames(10)


## Every generator seeded, Brains' clock, tick and think-slot counter set to
## the same values (runtime state, set from here: no code changes).
func _reset_globals(salt: int) -> void:
	var s := SEED + salt
	seed(s)
	Brains.rng.seed = s
	HitPipeline.crit_rng.seed = s
	Reactions.rng.seed = s
	Loot.rng.seed = s
	Brains.set(&"_time", START_TIME)
	Brains.set(&"_tick", START_TICK)
	Brains.set(&"_next_slot", 0)


# --- The scenarios' setups (t = 0) and their per-tick scripts (t >= 1) -----------------

func _setup_fodder_ring() -> void:
	_unstoppable()
	for i in 6:
		_spawn(SLIME_SCENE, ARENA + Vector2.from_angle(deg_to_rad(-30.0 + i * 12.0)) * 120.0, "slime%d" % i)


func _setup_brute_string() -> void:
	knight.resource_pool.restore(1000.0)
	_spawn(BRUTE_SCENE, ARENA + Vector2(180, 0), "brute")


func _tick_brute_string(t: int) -> void:
	if t < 180:
		knight.resource_pool.restore(1000.0)
	elif t == 180:
		knight.abilities.start_cooldown(&"e")   # Lunge and Judgement down (enemies_test's fixture)
		knight.abilities.start_cooldown(&"r")


func _setup_five_brutes() -> void:
	_unstoppable()
	_spend_kit()
	for i in 5:
		_spawn(BRUTE_SCENE, ARENA + Vector2.from_angle(TAU * i / 5.0) * 150.0, "brute%d" % i)


func _tick_five_brutes(t: int) -> void:
	if t % 30 == 0:
		_spend_kit()


func _setup_skirmisher() -> void:
	knight.resource_pool.restore(1000.0)
	_spawn(SKIRMISHER_SCENE, ARENA + Vector2(170, 0), "skirmisher")


func _tick_skirmisher(t: int) -> void:
	if t < 120:
		knight.resource_pool.restore(1000.0)
	elif t % 30 == 0:
		_spend_kit()


func _setup_caster_volley() -> void:
	knight.resource_pool.restore(1000.0)
	_spawn(CASTER_SCENE, ARENA + Vector2(230, 0), "caster")


func _tick_caster_volley(t: int) -> void:
	if t < 180:
		knight.resource_pool.restore(1000.0)
	elif t % 30 == 0:
		_spend_kit()


func _setup_caster_fall_back() -> void:
	knight.resource_pool.restore(1000.0)   # his kit up: the brute holds
	var pack := Pack.new()
	pack.name = "FallBackPack"
	var brute := BRUTE_SCENE.instantiate() as Enemy
	var caster := CASTER_ELITE_SCENE.instantiate() as Enemy
	caster.position = Vector2(60, -80)
	pack.add_child(brute)
	pack.add_child(caster)
	entities.add_child(pack)
	_place(pack, ARENA + Vector2(170, 0))
	for e: Enemy in [brute, caster]:
		e.reset_physics_interpolation()
	_track(brute, "brute")
	_track(caster, "caster_elite")


func _tick_caster_fall_back(t: int) -> void:
	knight.resource_pool.restore(1000.0)
	if t == 90:
		var caster := _unit("caster_elite")
		if caster != null:
			caster.health.take_damage(caster.health.max_health * 0.7)


func _setup_elite_caster() -> void:
	_spawn(CASTER_ELITE_SCENE, ARENA + Vector2(-220, 0), "caster_elite")


func _setup_duelist_plans() -> void:
	_spend_escapes()
	_spawn(DUELIST_SCENE, ARENA + Vector2(170, 0), "duelist")


func _tick_duelist_plans(t: int) -> void:
	if t % 30 == 0:
		if t < 360:
			_spend_escapes()
		else:
			_spend_kit()


func _setup_duelist_strike_first() -> void:
	_one_plan_duelist(&"strike_first")


func _tick_duelist_strike_first(t: int) -> void:
	if t % 30 == 0:
		_spend_kit()


func _setup_duelist_strike_finish() -> void:
	_one_plan_duelist(&"strike_finish")


func _tick_duelist_strike_finish(t: int) -> void:
	if t % 30 == 0:
		_spend_kit()


## The duelist with only plan `id` (enemies_test's plan-step fixture sets its
## _plans the same way), his whole kit down: escapes down passes the blind read.
func _one_plan_duelist(id: StringName) -> void:
	_spend_kit()
	var e := _spawn(DUELIST_SCENE, ARENA + Vector2(170, 0), "duelist")
	var brain := e.get_brain()
	var only: Array[ComboPlan] = []
	for plan in brain.get_plans():
		if plan.id == id:
			only.append(plan)
	brain.set(&"_plans", only)


func _setup_duelist_peel() -> void:
	_crowded_duelist(0.0)


func _tick_duelist_peel(t: int) -> void:
	_walk_into_duelist(t)


func _setup_duelist_all_in() -> void:
	_crowded_duelist(1.0)


func _tick_duelist_all_in(t: int) -> void:
	_walk_into_duelist(t)


## enemies_test's peel fixture: the duelist's crowded roll forced by its
## crowded_commit (in memory, this enemy's resolved behavior only), no setup
## (opening_bar 1), a slow patience so no new commit cuts its step back short.
func _crowded_duelist(crowded_commit: float) -> void:
	_unstoppable()
	var e := _spawn(DUELIST_SCENE, ARENA + Vector2(160, 0), "duelist")
	var b := e.get_brain().behavior
	b.crowded_commit = crowded_commit
	b.opening_bar = 1.0
	b.patience_time = 10.0


func _walk_into_duelist(t: int) -> void:
	if t != 120:
		return
	var e := _unit("duelist")
	if e == null:
		return
	var away := (knight.global_position - e.global_position).normalized()
	var radii := knight.get_gameplay_radius_px() + e.get_gameplay_radius_px()
	_place(knight, e.global_position + away * (radii + Units.to_px(80.0)))


func _setup_elite_slime() -> void:
	_spend_kit()
	var e := _spawn(ELITE_SCENE, ARENA + Vector2(0, -140), "slime_elite")
	e.abilities.start_cooldown(&"e")   # its big hit down first, so its shockwave is its damage cast


func _tick_elite_slime(t: int) -> void:
	if t % 30 == 0:
		_spend_kit()


func _setup_cornered_caster() -> void:
	knight.resource_pool.restore(1000.0)
	_spawn(CASTER_SCENE, ARENA + Vector2(230, 0), "caster")


func _tick_cornered_caster(t: int) -> void:
	var caster := _unit("caster")
	if caster == null:
		return
	if t == 60 or (t >= 76 and t <= 255):
		_place(knight, caster.global_position + Vector2(-50, 0))   # he walked in on it, then sticks to it


func _setup_press() -> void:
	_unstoppable()
	_spend_kit()
	for i in 3:
		_spawn(BRUTE_SCENE, ARENA + Vector2.from_angle(TAU * i / 4.0) * 150.0, "brute%d" % i)
	_spawn(ELITE_SCENE, ARENA + Vector2.from_angle(TAU * 0.75) * 150.0, "slime_elite")


func _tick_press(t: int) -> void:
	if t % 30 == 0:
		_spend_kit()


var _mix_saved := -1.0


func _setup_mix_string_first() -> void:
	_mix_brute(1.0)


func _setup_mix_cast_first() -> void:
	_mix_brute(0.0)


func _teardown_mix_string_first() -> void:
	_restore_mix()


func _teardown_mix_cast_first() -> void:
	_restore_mix()


## enemies_test's mix fixture: the brute with its smash and cleave arc ready
## (its charge down), his kit spent, the mix forced in memory.
func _mix_brute(chance: float) -> void:
	_mix_saved = Brains.table.string_then_cast_chance
	Brains.table.string_then_cast_chance = chance
	_unstoppable()
	_spend_kit()
	var e := _spawn(BRUTE_SCENE, ARENA + Vector2(140, 0), "brute")
	for slot in AbilityComponent.SLOTS:
		if e.abilities.get_ability(slot) != null:
			e.abilities.start_cooldown(slot)
	e.abilities.reset_cooldown(&"q")
	e.abilities.reset_cooldown(&"w")


func _restore_mix() -> void:
	if _mix_saved >= 0.0:
		Brains.table.string_then_cast_chance = _mix_saved
		_mix_saved = -1.0


var _deflected_swing := -1


func _setup_deflect_string() -> void:
	DeflectComponent.deflect_test_enabled = true
	_deflected_swing = -1
	_unstoppable()
	_spend_kit()
	var e := _spawn(BRUTE_SCENE, ARENA + Vector2(140, 0), "brute")
	for slot in AbilityComponent.SLOTS:
		if e.abilities.get_ability(slot) != null:
			e.abilities.start_cooldown(slot)


## The Knight as a scripted target: his deflect window opens once before each
## string hit, 0.1 s or less before it lands (enemies_test's deflect pair).
func _tick_deflect_string(t: int) -> void:
	if t % 30 == 0:
		_spend_kit()
	var e := _unit("brute")
	if e == null or not e.attack.is_running_string():
		return
	var swung := e.attack.get_string_swung()
	var next := e.attack.get_string_next_hit_in()
	if swung > 0 and swung != _deflected_swing and next >= 0.0 and next <= 0.1:
		_deflected_swing = swung
		knight.deflect_component.open_window()


func _teardown_deflect_string() -> void:
	DeflectComponent.deflect_test_enabled = false


func _setup_boss_brute() -> void:
	knight.resource_pool.restore(1000.0)
	var boss_data: EnemyData = BRUTE_DATA.duplicate()
	boss_data.rank = EnemyData.Rank.BOSS
	var e := BRUTE_SCENE.instantiate() as Enemy
	e.data = boss_data
	e.position = ARENA + Vector2(180, 0)
	entities.add_child(e)
	e.reset_physics_interpolation()
	_track(e, "brute_boss")


func _tick_boss_brute(t: int) -> void:
	if t < 120:
		knight.resource_pool.restore(1000.0)
	elif t % 30 == 0:
		_spend_kit()


# --- Fixtures ---------------------------------------------------------------------------

func _spawn(scene: PackedScene, pos: Vector2, label: String) -> Enemy:
	var e := scene.instantiate() as Enemy
	e.position = pos
	entities.add_child(e)
	e.reset_physics_interpolation()
	_track(e, label)
	return e


func _unit(label: String) -> Enemy:
	for entry in _entries:
		if entry.label == label and is_instance_valid(entry.unit):
			return entry.unit
	return null


## The Knight unstoppable (no knockback from their hits: AB10), as the
## fixtures that keep him in place have him.
func _unstoppable() -> void:
	var s := StatusEffect.new()
	s.id = &"test_unstoppable"
	s.tags = [&"unstoppable"] as Array[StringName]
	s.duration = -1.0
	knight.status_component.apply_status(s)


## The Knight's kit all spent (every slot on cooldown, no Fury): respect 0.
func _spend_kit() -> void:
	for slot in AbilityComponent.SLOTS:
		if knight.abilities.get_ability(slot) != null:
			knight.abilities.start_cooldown(slot)
	if knight.resource_pool != null:
		knight.resource_pool.try_spend(knight.resource_pool.current)


## His escapes down (the sandbox's escapes_down): his mobility and defensive
## abilities (Lunge, Iron Resolve) on cooldown, the rest ready.
func _spend_escapes() -> void:
	for slot in AbilityComponent.SLOTS:
		var ability := knight.abilities.get_ability(slot)
		if ability != null and (ability.tags.has(&"mobility") or ability.tags.has(&"defensive")):
			knight.abilities.start_cooldown(slot)


func _add_navigation() -> void:
	var poly := NavigationPolygon.new()
	var r := Rect2(ARENA - Vector2(2500, 2500), Vector2(5000, 5000))
	poly.vertices = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	poly.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	_region = NavigationRegion2D.new()
	_region.navigation_polygon = poly
	add_child(_region)


# --- Recording ----------------------------------------------------------------------------

## Starts recording `e` under `label`: its brain's signals, its casts, swings,
## windups and string ends as events; its thinks at each tick's end.
func _track(e: Enemy, label: String) -> void:
	var brain := e.get_brain()
	var entry := {"unit": e, "label": label, "brain": brain, "rank": _rank_label(e), "situation": null, "decision": null,
		"committing": false, "token": false, "strings": 0, "stringing": false, "string_from": -1, "flips": 0, "flip_noted": false,
		"last_intent": &"", "idle_token_from": -1, "token_noted": false, "string_noted": false, "thinks": 0}
	_entries.append(entry)
	if brain != null:
		brain.intent_changed.connect(_on_intent.bind(entry))
		brain.pose_changed.connect(_on_pose.bind(entry))
	if e.abilities != null:
		e.abilities.cast_started.connect(_on_cast.bind(entry))
	e.attack.swing_started.connect(_on_swing.bind(entry))
	e.attack.string_ended.connect(_on_string_ended.bind(entry))
	e.attack.windup_started.connect(_on_windup.bind(entry))


## The entry's brain, or null (fodder, or freed).
static func _brain_of(entry: Dictionary) -> EnemyBrain:
	var b: Variant = entry.brain
	if b == null or not is_instance_valid(b):
		return null
	return b as EnemyBrain


static func _rank_label(e: Enemy) -> StringName:
	if e.data == null:
		return &"none"
	if e.data.duelist:
		return &"duelist"
	match e.data.rank:
		EnemyData.Rank.FODDER:
			return &"fodder"
		EnemyData.Rank.REGULAR:
			return &"regular"
		EnemyData.Rank.ELITE:
			return &"elite"
	return &"boss"


func _t() -> int:
	return _rec_tick - SETTLE_TICKS


func _event(entry: Dictionary, text: String, kind: String = "") -> void:
	if not _recording:
		return
	_lines.append("t=%04d %s ~%s" % [_t(), entry.label, text])
	if kind != "":
		_count(kind)


func _count(kind: String) -> void:
	var k: Array = _kinds.get(kind, [0, _t(), _t()])
	k[0] = int(k[0]) + 1
	k[2] = _t()
	_kinds[kind] = k


func _on_intent(intent: StringName, entry: Dictionary) -> void:
	_event(entry, "intent %s" % intent)


func _on_pose(pose: StringName, entry: Dictionary) -> void:
	_event(entry, "pose %s" % pose)


func _on_cast(slot: StringName, ability: Ability, _ctx: CastContext, entry: Dictionary) -> void:
	_event(entry, "cast %s %s" % [slot, ability.id if ability != null else &""], "casts")


func _on_swing(index: int, _direction: Vector2, _swing: AttackSwing, entry: Dictionary) -> void:
	_event(entry, "swing %d" % index, "swings")


func _on_string_ended(completed: bool, swung: int, entry: Dictionary) -> void:
	_event(entry, "string_end %s %d" % ["done" if completed else "cut", swung], "strings_done" if completed else "strings_cut")


func _on_windup(_target: Unit, windup_time: float, entry: Dictionary) -> void:
	_event(entry, "windup %.3f" % windup_time, "windups")


func _on_unit_damaged(ctx: HitContext) -> void:
	if _recording and is_instance_valid(knight) and ctx.target == knight:
		_damage += ctx.taken_damage
		_count("damage_to_knight")


## The Knight's deflect (the prototype, on in deflect_string): an event on the
## attacker's line.
func _on_hit_deflected(attacker: Unit, _defender: Unit, _ctx: HitContext) -> void:
	for entry in _entries:
		if entry.unit == attacker:
			_event(entry, "deflected", "deflects")
			return


## Each tick's end (after every node's physics): each tracked brain's think,
## its commit and token edges; a fodder's ring spot every 6 ticks.
func _physics_process(_delta: float) -> void:
	if not _recording or _t() < 0:
		return
	for entry in _entries:
		if not is_instance_valid(entry.unit):
			continue
		var e: Enemy = entry.unit
		var brain := _brain_of(entry)
		if brain == null:
			if _t() % 6 == 0:
				var spot := e.get_ring_spot()
				_lines.append("t=%04d %s spot=%s ai=%d atk=%d" % [_t(), entry.label,
					"-" if spot == Vector2.INF else "%.1f,%.1f" % [spot.x, spot.y], e.ai, int(e.attack.target != null)])
			continue
		_record_edges(entry, e, brain)
		var s := brain.get_situation()
		if s != null and s != entry.situation:
			entry.situation = s
			_record_think(entry, e, brain)


func _record_edges(entry: Dictionary, e: Enemy, brain: EnemyBrain) -> void:
	var committing := brain.is_committing()
	if committing != entry.committing:
		entry.committing = committing
		_event(entry, "commit %s" % ("start" if committing else "end"), "commits_started" if committing else "commits_ended")
	var token := Brains.has_token(e)
	if token != entry.token:
		entry.token = token
		_event(entry, "token %s" % ("taken" if token else "freed"), "tokens_taken" if token else "tokens_freed")
	if brain.string_count != entry.strings:
		entry.strings = brain.string_count
		_count("strings_started")
	# Anomalies (reported, never failed): a string running over 6 s; a token
	# held over 1 s while not committing.
	var stringing := brain.is_stringing()
	if stringing and not entry.stringing:
		entry.string_from = _t()
	entry.stringing = stringing
	if stringing and _t() - int(entry.string_from) > 360 and not entry.string_noted:
		entry.string_noted = true
		_anomaly("%s %s: a string running for over 6 s (from t=%d)" % [_scenario_id, entry.label, entry.string_from])
	if token and not committing:
		if int(entry.idle_token_from) < 0:
			entry.idle_token_from = _t()
		elif _t() - int(entry.idle_token_from) > 60 and not entry.token_noted:
			entry.token_noted = true
			_anomaly("%s %s: its token held over 1 s while not committing (from t=%d)" % [_scenario_id, entry.label, entry.idle_token_from])
	else:
		entry.idle_token_from = -1


## One think: tick, intent, pose, committing, patience, token, string (running,
## plan step, swung), plan and step, the move order; a fresh decision adds its
## cast slot, top three scores and reason (a swinging string's think makes
## none: d=same).
func _record_think(entry: Dictionary, e: Enemy, brain: EnemyBrain) -> void:
	entry.thinks = int(entry.thinks) + 1
	_count("thinks")
	var samples: Array = _think_usec.get(entry.rank, [])
	samples.append(brain.get_think_usec())
	_think_usec[entry.rank] = samples
	var d := brain.get_last_decision()
	var fresh: bool = d != null and d != entry.decision
	entry.decision = d
	var plan := brain.get_plan()
	var parts := PackedStringArray()
	parts.append("t=%04d %s" % [_t(), entry.label])
	parts.append("i=%s p=%s com=%d pat=%.3f" % [brain.get_intent(), brain.get_pose(), int(brain.is_committing()), brain.get_patience()])
	parts.append("tok=%s str=%d/%d/%d" % [brain.get_token_state(), int(brain.is_stringing()), brain.get_string_step(), e.attack.get_string_swung()])
	parts.append("plan=%s/%d" % [String(plan.id) if plan != null else "-", brain.get_plan_step()])
	var dest := e.movement.get_destination()
	parts.append("m=%s" % ("%.1f,%.1f" % [dest.x, dest.y] if e.movement.has_order() else "-"))
	if fresh:
		parts.append("c=%s" % (String(d.plan.slot) if d.plan != null else "-"))
		parts.append("s=%s" % _top_scores(d.scores))
		parts.append("r=%s" % d.reason)
	else:
		parts.append("d=same")
	_lines.append(" ".join(parts))
	# An intent that flips every think (4 in a row): reported.
	var intent := brain.get_intent()
	if fresh and intent != entry.last_intent and entry.last_intent != &"":
		entry.flips = int(entry.flips) + 1
	elif fresh:
		entry.flips = 0
	entry.last_intent = intent
	if int(entry.flips) >= 4 and not entry.flip_noted:
		entry.flip_noted = true
		_anomaly("%s %s: its intent changed on 4 thinks in a row (to t=%d)" % [_scenario_id, entry.label, _t()])


## The three best intents and their scores (3 places), best first.
static func _top_scores(scores: Dictionary) -> String:
	var rows: Array = []
	for k: StringName in scores:
		rows.append([String(k), float(scores[k])])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1] or (a[1] == b[1] and a[0] < b[0]))
	var out := PackedStringArray()
	for r: Array in rows.slice(0, 3):
		out.append("%s:%.3f" % [r[0], r[1]])
	return ",".join(out)


func _anomaly(text: String) -> void:
	if _note_anomalies and not _anomalies.has(text):
		_anomalies.append(text)


## At a scenario's end: a string still running past 6 s, or a token held while
## not committing past 1 s, counts too.
func _end_anomalies() -> void:
	for entry in _entries:
		if entry.stringing and _t() - int(entry.string_from) > 360 and not entry.string_noted:
			_anomaly("%s %s: a string still running at the end, from t=%d" % [_scenario_id, entry.label, entry.string_from])


## The recording's text: a header, the log (folded when big), the totals.
func _build_text(sc: Dictionary, salt: int) -> String:
	var out := PackedStringArray()
	out.append("# brain_golden %s: %s" % [sc.id, sc.title])
	out.append("# seed %d, physics 60 Hz (1/60 s a tick), %d ticks from the enemies' spawn (t=0); rewrite with --write-golden" % [SEED + salt, sc.ticks])
	out.append("# per tick: its events in the order they came (~), then each brain's think; fodder: its ring spot every 6 ticks")
	out.append("== log")
	var body := _lines
	var size := 0
	for l in body:
		size += l.length() + 1
	if size > COMPRESS_OVER:
		body = _fold(body)
		out.append("# (folded: runs of lines the same but for their tick read t=first..last xN)")
	out.append_array(body)
	out.append("== totals")
	var kinds: Array = _kinds.keys()
	kinds.sort()
	for k: String in kinds:
		var v: Array = _kinds[k]
		out.append("%s %d (t=%04d..%04d)" % [k, v[0], v[1], v[2]])
	out.append("damage_to_knight_total %.1f" % _damage)
	for entry in _entries:
		var brain := _brain_of(entry)
		if brain == null:
			out.append("%s (no brain)" % entry.label)
			continue
		var ends: Array = brain.plan_ends.keys()
		ends.sort()
		var end_text := PackedStringArray()
		for r: StringName in ends:
			end_text.append("%s %d" % [r, brain.plan_ends[r]])
		out.append("%s thinks %d strings %d (last %d hits) plans %d [%s] peels %d setups %d" % [entry.label, entry.thinks,
			brain.string_count, brain.last_string_hits, brain.plan_count, ", ".join(end_text), brain.peel_count, brain.setup_count])
	return "\n".join(out) + "\n"


## Runs of lines the same but for their tick, folded into one: t=first..last xN.
static func _fold(lines: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	var i := 0
	while i < lines.size():
		var head := lines[i].substr(0, 6)
		var rest := lines[i].substr(6)
		var j := i + 1
		while j < lines.size() and lines[j].substr(6) == rest:
			j += 1
		if j - i > 1:
			out.append("%s..%s x%d%s" % [head, lines[j - 1].substr(2, 4), j - i, rest])
		else:
			out.append(lines[i])
		i = j
	return out


# --- Comparing --------------------------------------------------------------------------

func _golden_path(id: String) -> String:
	return GOLDEN_DIR + id + ".txt"


## Compares a recording with its golden file, or (--write-golden) writes it.
func _compare_golden(sc: Dictionary, text: String) -> void:
	var path := _golden_path(sc.id)
	if _write:
		var f := FileAccess.open(path, FileAccess.WRITE)
		_check("%s: golden file written (%d bytes)" % [sc.id, text.length()], f != null, true)
		if f != null:
			f.store_string(text)
			f.close()
		return
	if not FileAccess.file_exists(path):
		_report(false, "%s: matches its golden file" % sc.id, "no golden file at %s (run with -- %s once)" % [path, WRITE_ARG])
		return
	var golden := FileAccess.get_file_as_string(path).replace("\r", "")
	_compare("%s: matches its golden file" % sc.id, golden, text)


## One check: `actual` the same as `expected`, line by line; on a mismatch the
## first differing line with its context and the count of differing lines.
func _compare(label: String, expected: String, actual: String) -> bool:
	var d := _diff(expected, actual)
	if d.first < 0:
		_report(true, label, "")
		return true
	_report(false, label, "%d lines differ; the first at line %d" % [d.count, d.first + 1])
	var a := expected.split("\n")
	var b := actual.split("\n")
	for i in range(maxi(int(d.first) - CONTEXT_LINES, 0), int(d.first) + CONTEXT_LINES + 1):
		var x := a[i] if i < a.size() else "<none>"
		var y := b[i] if i < b.size() else "<none>"
		if x == y:
			print("        %5d   %s" % [i + 1, x])
		else:
			print("        %5d - %s" % [i + 1, x])
			print("        %5d + %s" % [i + 1, y])
	return false


## {first: the first differing line (−1 = the same), count: lines that differ}.
static func _diff(expected: String, actual: String) -> Dictionary:
	var a := expected.split("\n")
	var b := actual.split("\n")
	var first := -1
	var count := absi(a.size() - b.size())
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			count += 1
			if first < 0:
				first = i
	if first < 0 and a.size() != b.size():
		first = mini(a.size(), b.size())
	return {"first": first, "count": count}


# --- The mutation check ----------------------------------------------------------------

## One decision number changed (the table's patience_respect_cut, on a copy of
## the AI table in memory, never saved): the scenario's recording must differ
## from its golden file. Then the real table is back, unchanged.
func _test_mutation(first: Dictionary) -> void:
	_section("The mutation check: a changed decision number must fail the comparison")
	var sc: Dictionary = {}
	var salt := 0
	for i in SCENARIOS.size():
		if SCENARIOS[i].id == MUTATION_SCENARIO:
			sc = SCENARIOS[i]
			salt = i
	var real := Brains.table
	var cut := real.patience_respect_cut
	var changed: EnemyAITable = real.duplicate()
	changed.patience_respect_cut = cut * 0.5
	Brains.table = changed
	_note_anomalies = false
	var text: String = await _run_scenario(sc, salt)
	_note_anomalies = true
	Brains.table = real
	var expected: String = first.get(sc.id, "")
	if not _write and FileAccess.file_exists(_golden_path(sc.id)):
		expected = FileAccess.get_file_as_string(_golden_path(sc.id)).replace("\r", "")
	var d := _diff(expected, text)
	_check("%s with patience_respect_cut %.2f → %.2f (a copy in memory): its recording differs (%d lines; the first at line %d)" % [
			sc.id, cut, cut * 0.5, d.count, int(d.first) + 1], d.first >= 0, true)
	_check("the real table is back, unchanged (%.2f), and the copy was never saved (no path)" % real.patience_respect_cut,
		[Brains.table == real, is_equal_approx(real.patience_respect_cut, cut), changed.resource_path, real.resource_path],
		[true, true, "", Brains.TABLE_PATH])


# --- The contract ------------------------------------------------------------------------

## Every name in golden/brain_api.txt still exists on EnemyBrain: a class
## extending UnitController, its constants, properties, methods, static
## functions (EnemyBrain.x()) and signals.
func _test_contract() -> void:
	_section("The contract: every name outside enemy_brain.gd uses on EnemyBrain (golden/brain_api.txt)")
	var text := FileAccess.get_file_as_string(API_PATH).replace("\r", "")
	var script := _brain_script()
	_check("brain_api.txt loads; EnemyBrain is a global class extending UnitController", [text != "", script != null, _global_base(&"EnemyBrain")],
		[true, true, &"UnitController"])
	if text == "" or script == null:
		return
	var brain: Object = script.new()
	var props := {}
	for p in brain.get_property_list():
		props[String(p.name)] = true
	var statics := {}
	for m in script.get_script_method_list():
		if int(m.flags) & METHOD_FLAG_STATIC:
			statics[String(m.name)] = true
	var consts := {}
	for k: Variant in script.get_script_constant_map():
		consts[String(k)] = true
	var names := 0
	for line in text.split("\n"):
		if line.strip_edges() == "" or line.begins_with("#"):
			continue
		var cols := line.split("\t")
		if cols.size() < 3:
			_report(false, "brain_api.txt: a line with name, kind and files", line)
			continue
		var n := cols[0]
		var kind := cols[1]
		var ok := false
		match kind:
			"class":
				ok = _global_base(StringName(n)) == &"UnitController"
			"const":
				ok = consts.has(n)
			"var":
				ok = props.has(n)
			"func":
				ok = brain.has_method(n)
			"static_func":
				ok = statics.has(n)
			"signal":
				ok = brain.has_signal(n)
		names += 1
		_check("%s %s (used by %s)" % [kind, n, cols[2]], ok, true)
	(brain as Node).free()
	print("  (%d names checked)" % names)


func _brain_script() -> Script:
	for c in ProjectSettings.get_global_class_list():
		if c.class == &"EnemyBrain":
			return load(c.path)
	return null


static func _global_base(class_id: StringName) -> StringName:
	for c in ProjectSettings.get_global_class_list():
		if c.class == class_id:
			return c.base
	return &""


# --- The think-time baseline --------------------------------------------------------------

## get_think_usec() over every recorded think, per rank: mean, p95, max
## (printed); the p95 under twice R0's.
func _test_think_time() -> void:
	_section("The think-time baseline (µs a think; a measurement: the ceiling is twice R0's p95)")
	for rank: StringName in [&"regular", &"elite", &"boss", &"duelist"]:
		var samples: Array = _think_usec.get(rank, [])
		if samples.is_empty():
			_report(false, "%s: thinks recorded" % rank, "none")
			continue
		samples.sort()
		var total := 0
		for v: int in samples:
			total += v
		var mean := float(total) / samples.size()
		var p95: int = samples[mini(int(samples.size() * 0.95), samples.size() - 1)]
		var top: int = samples[-1]
		var ceiling: int = int(THINK_P95_R0.get(rank, 0)) * 2
		print("  THINK %s: %d thinks, mean %.0f, p95 %d, max %d" % [rank, samples.size(), mean, p95, top])
		_check("%s: p95 %d µs under twice R0's (%d µs)" % [rank, p95, ceiling], p95 <= ceiling, true)


func _print_anomalies() -> void:
	_section("Anomalies seen in the recording (reported, not failed)")
	if _anomalies.is_empty():
		print("  NOTE  none")
	for a in _anomalies:
		print("  NOTE  %s" % a)


# --- Helpers --------------------------------------------------------------------------------

func _place(node: Node2D, pos: Vector2) -> void:
	node.global_position = pos
	node.reset_physics_interpolation()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _section(title: String) -> void:
	print("-- %s" % title)


func _check(label: String, actual: Variant, expected: Variant) -> void:
	var ok: bool
	if actual is float or expected is float:
		ok = is_equal_approx(float(actual), float(expected))
	else:
		ok = actual == expected
	_report(ok, label, "got %s, expected %s" % [actual, expected])


func _report(ok: bool, label: String, detail: String) -> void:
	if ok:
		_passed += 1
		print("  PASS  %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s: %s" % [label, detail])
