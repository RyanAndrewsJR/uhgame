extends Node2D
## PROTOTYPE test (Ryan, 2026-10-07): dash-deflect, riposte and enemy poise,
## tested on the Knight. Open res://scenes/tests/deflect_test.tscn and press
## F6. The real player.tscn and enemy scenes; hits built the way their
## sources build them (a League-style attack's make_attack_context(), an
## ability's HitPipeline.from_ability()) and resolved while the Knight dashes.
## Slice A: the flags off change nothing (the dash i-frames, a hit during a
## dash, the recharge, the swing); the window (a deflect blocks everything,
## the same hit after the window is only blocked, a non-deflectable one is
## only blocked); the streak, the refund and the chain window; the riposte
## (its damage, a whiff keeps it, it runs out, its snap toward the attacker);
## weak basic attacks (ARCHETYPES AR4, in place of the TEMP weak-auto lever's
## checks: a plain swing at half, empowered ones full, enemies untouched); a
## deflect on sources it wasn't written for.
## Slice B: poise (the flag off, the data, the meter and its decay, the break
## and what it cuts, blocks and boosts, tenacity and diminishing returns left
## out, the immunity, poise damage on hits and deflects, a pair plus a riposte
## breaking both 100-poise elites). Since ARCHETYPES AR3a the meter fills up
## to a break (D1), with its decay's low-health scale; the Archetype resource,
## the ranks' sizes and break times, and an archetype's meter running with
## the flag off (a regular breaking on a deflect pair, an elite on the pair
## plus the riposte, a boss needing 45 more). ARCHETYPES AR3b, the test
## Assassin's Riposte Stance with both flags off: its window, one deflect,
## the Knight rebuffed (his swing gone, his combo reset, 0.4 s), its riposte
## at once (twice its AD), what it deflects (swings; never Cleave, Lunge,
## Judgement), a stun cutting it, its whiff recovery, its own meter's drain;
## the Knight's test deflect breaking its meter. ARCHETYPES AR4: the stat's
## data (0.5 on every champion, 1 on every other unit) and the rotation
## simulation (only swings at least twice as slow to kill the elite slime and
## the test duelist as the kit). Slice C: the feel (hitstop, shake, the
## riposte's ring; empty slots) and SandboxDeflect (keys, the panel's rows
## applied live and to new enemies, its edits put back).
## The Knight's crit is held at 0 and his passive (Unbroken) is off, so
## damage checks are exact. Prints PASS/FAIL per check, then a total. Run
## headless and it quits with the number of failures as the exit code.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const SLIME_SCENE: PackedScene = preload("res://scenes/enemies/slime.tscn")
const BRUTE_SCENE: PackedScene = preload("res://scenes/enemies/test_brute.tscn")
const ELITE_SCENE: PackedScene = preload("res://scenes/enemies/slime_elite.tscn")
const DUELIST_SCENE: PackedScene = preload("res://scenes/enemies/test_duelist.tscn")
const KNIGHT: ChampionData = preload("res://data/champions/knight.tres")
const SLAM: Ability = preload("res://data/abilities/slime_elite_q_slam.tres")
const BIG_HIT: Ability = preload("res://data/abilities/slime_elite_e_big_hit.tres")
const STRIKE: Ability = preload("res://data/abilities/test_duelist_e_strike.tres")
const FINISHER: Ability = preload("res://data/abilities/test_duelist_r_finisher.tres")
const SNARE: Ability = preload("res://data/abilities/test_duelist_q_snare.tres")
const BOLT: Ability = preload("res://data/abilities/test_caster_q_bolt.tres")
const STATUS_SLOW: StatusEffect = preload("res://data/statuses/status_slow.tres")
const CLEAVE: Ability = preload("res://data/abilities/knight_q_cleave.tres")
const CLEAVE_WAVE: Ability = preload("res://data/abilities/knight_q_cleave_wave.tres")
const JUDGEMENT: Ability = preload("res://data/abilities/knight_r_judgement.tres")
const JUDGEMENT_LEAP: Ability = preload("res://data/abilities/knight_r_judgement_leap.tres")
const COMBO_KNIGHT: AttackCombo = preload("res://data/combos/combo_knight.tres")
const ELITE_DATA: EnemyData = preload("res://data/enemies/enemy_slime_elite.tres")
const DUELIST_DATA: EnemyData = preload("res://data/enemies/enemy_test_duelist.tres")
const SLIME_DATA: EnemyData = preload("res://data/enemies/enemy_slime.tres")
const BRUTE_DATA: EnemyData = preload("res://data/enemies/enemy_test_brute.tres")
const SKIRMISHER_DATA: EnemyData = preload("res://data/enemies/enemy_test_skirmisher.tres")
const CASTER_ELITE_DATA: EnemyData = preload("res://data/enemies/enemy_test_caster_elite.tres")
const STATUS_POISE_BROKEN: StatusEffect = preload("res://data/statuses/status_poise_broken.tres")
const STATUS_REBUFFED_PERILOUS: StatusEffect = preload("res://data/statuses/status_rebuffed_perilous.tres")
const STATUS_REBUFFED: StatusEffect = preload("res://data/statuses/status_rebuffed.tres")
const STATUS_STUN: StatusEffect = preload("res://data/statuses/status_stun.tres")
const ASSASSIN_SCENE: PackedScene = preload("res://scenes/enemies/test_assassin.tscn")
const LUNGE: Ability = preload("res://data/abilities/knight_e_lunge.tres")
const AURA_SCRIPT: Script = preload("res://scripts/vfx/aura.gd")
const FLAT := StatModifier.Type.FLAT
const BASELINE_SOURCE := &"test_baseline"
const ARENA := Vector2(-3000, 0)
## The Knight's swing reach (175 u = 56 px) and the brute's radius (70 u).
const KNIGHT_REACH_PX := 56.0
const BRUTE_RADIUS_PX := 22.4
## AR4: the source of a test's own unempowered_attack_damage modifiers.
const FULL_SWINGS_SOURCE := &"test_full_swings"
## AR4's rotation simulation: where its target stands, and the longest a run
## may take (s) before it counts as not killed.
const ROTATION_SPOT := ARENA + Vector2(0, 700)
const ROTATION_LIMIT := 120.0
## The test duelist's bar: today's 1.89x guarded, short of D12's 2x (Ryan,
## 2026-10-09: keep 0.5 and record the gap; ARCHETYPES.md, Open questions).
const DUELIST_ROTATION_BAR := 1.85

@onready var entities: Node2D = $Entities

var knight: Player
var deflect: DeflectComponent

var _passed: int = 0
var _failed: int = 0
var _deflects: Array = []   # [attacker, defender, ctx]
var _streaks: Array = []   # the Knight's streak events, in order
var _ripostes: Array = []   # [unit]
var _hits: Array[HitContext] = []
var _poise_breaks: Array = []    # [unit]
var _poise_changes: Array = []   # [unit, value, maximum]
var _shakes: Array = []   # GameFeel.shake() amounts (the spy camera)
var _feel_defaults: Array = []   # [deflect_hitstop, deflect_shake] as the scene has them
var _defaults: Dictionary = {}   # the DeflectComponent's exports as the scene has them
var _shipped: Array = []   # the flags and the lever as the scripts ship them


func _ready() -> void:
	print("\n=== Deflect test (PROTOTYPE: dash-deflect, riposte, poise) ===")
	_shipped = [DeflectComponent.deflect_test_enabled, AutoAttackComponent.prototype_unempowered_auto_mult, PoiseComponent.poise_test_enabled]
	Progress.get_progress(KNIGHT)   # the save guards latch off first (a test scene)
	Loot.get_inventory(KNIGHT)
	HitPipeline.crit_rng.seed = 20261007
	Events.hit_deflected.connect(func(a: Unit, d: Unit, ctx: HitContext) -> void: _deflects.append([a, d, ctx]))
	Events.deflect_streak_changed.connect(func(u: Unit, s: int) -> void:
		if u == knight:
			_streaks.append(s))
	Events.riposte_ready.connect(func(u: Unit) -> void: _ripostes.append(u))
	Events.unit_hit.connect(func(ctx: HitContext) -> void: _hits.append(ctx))
	Events.poise_broken.connect(func(u: Unit) -> void: _poise_breaks.append(u))
	Events.poise_changed.connect(func(u: Unit, v: float, m: float) -> void: _poise_changes.append([u, v, m]))
	_add_navigation()
	await _frames(3)
	knight = PLAYER_SCENE.instantiate()
	entities.add_child(knight)
	await get_tree().physics_frame
	_place(knight, ARENA)
	deflect = knight.deflect_component
	for p: String in ["deflect_window", "chain_window", "refund_lifetime", "deflect_test_charge_recharge",
			"riposte_ad_ratio", "riposte_window", "riposte_snap_range", "streak_persists"]:
		_defaults[p] = deflect.get(p)
	_feel_defaults = [deflect.deflect_hitstop, deflect.deflect_shake]
	_baseline()

	await _test_flags_off()
	_test_data()
	await _test_window()
	await _test_streak_and_refund()
	await _test_streak_persists()   # Ryan's follow-up: deflects bank
	await _test_riposte()
	await _test_riposte_snap()
	await _test_ar4_weak()   # ARCHETYPES AR4 (in place of the TEMP lever's checks)
	await _test_other_sources()
	await _test_perilous_deflect()   # ARCHETYPES AR2
	# Slice B: poise.
	await _test_poise_flags_off()
	_test_poise_data()
	await _test_poise_meter()
	await _test_poise_break()
	await _test_poise_sources()
	await _test_pair_and_riposte_break()
	_test_ar3a_data()   # ARCHETYPES AR3a
	await _test_ar3a_meter()
	await _test_ar3b_stance()   # ARCHETYPES AR3b
	await _test_ar3b_break()
	_test_ar4_data()   # ARCHETYPES AR4
	await _test_ar4_rotation()
	# Slice C: feel, readouts and the sandbox.
	await _test_feel()
	await _test_sandbox()

	DeflectComponent.deflect_test_enabled = false
	PoiseComponent.poise_test_enabled = false
	AutoAttackComponent.prototype_unempowered_auto_mult = 1.0
	Audio.stop_all()
	await _frames(10)
	print("=== %d passed, %d failed ===\n" % [_passed, _failed])
	if DisplayServer.get_name() == "headless":
		get_tree().quit(_failed)


## Exact numbers: no crit, no Unbroken (his AD stays 64 when hurt). His Fury
## on hit stays (the weak-auto checks read it).
func _baseline() -> void:
	var crit := knight.stats_component.get_base_value(&"crit_chance")
	if crit != 0.0:
		knight.stats_component.add_modifier(StatModifier.create(&"crit_chance", FLAT, -crit, BASELINE_SOURCE))
	if knight.champion != null and knight.champion.passive != null:
		knight.champion.passive.remove_from(knight, knight.champion.get_passive_source_id())


# --- Flags off --------------------------------------------------------------------

func _test_flags_off() -> void:
	_section("Flags off: nothing changes")
	DeflectComponent.deflect_test_enabled = false
	await _fresh()
	_check("flags are off as shipped (deflect off, the lever 1.0, poise off)", _shipped, [false, 1.0, false])
	_check("the dash recharge is its own 0.35 s", knight.dash.get_recharge_time(), 0.35)
	_check("no test recharge while off", deflect.get_test_recharge(), -1.0)
	var brute := _spawn(BRUTE_SCENE, ARENA + Vector2(0, 200))
	var health := knight.health.current
	knight.dash.try_dash(Vector2.RIGHT)
	_check("no window opens on a dash", deflect.is_window_open(), false)
	_check("the dash i-frames are on", knight.has_invulnerability(DashComponent.INVULNERABILITY_ID), true)
	var ctx := _brute_hit(brute)
	_check("a deflectable hit during a dash is blocked by the i-frames", [ctx.deflectable, ctx.blocked, ctx.deflected], [true, true, false])
	_check("...no damage, no deflect, no streak, no refund", [knight.health.current, _deflects.size(), _streaks.size(), knight.dash.has_refund()], [health, 0, 0, false])
	await _wait_until(func() -> bool: return not knight.dash.is_dashing(), 60)
	var frames := 0
	while knight.dash.get_charges() < knight.dash.get_max_charges() and frames < 120:
		await get_tree().physics_frame
		frames += 1
	_check("the charge comes back 0.35 s after the dash (21 ± 1 frames)", absi(frames - 21) <= 1, true)
	var ctx2 := _brute_hit(brute)
	_check("a hit outside a dash lands as before (26 from the brute)", [ctx2.blocked, ctx2.deflected, knight.health.current], [false, false, health - 26.0])
	await _wait_until(func() -> bool: return not knight.is_invulnerable(), 60)
	brute.queue_free()
	await get_tree().physics_frame


func _test_data() -> void:
	_section("Which hits are deflectable (data)")
	var brute := BRUTE_SCENE.instantiate() as Enemy
	var slime := SLIME_SCENE.instantiate() as Enemy
	_check("the test brute's basic attack", brute.get_node(^"AutoAttackComponent").get(&"deflectable"), true)
	_check("a slime's basic attack isn't", slime.get_node(^"AutoAttackComponent").get(&"deflectable"), false)
	_check("the elite slam, the duelist's strike and finisher", [SLAM.deflectable, STRIKE.deflectable, FINISHER.deflectable], [true, true, true])
	_check("the duelist's snare (a projectile) and Big hit (the test's non-deflectable heavy) aren't", [SNARE.deflectable, BIG_HIT.deflectable], [false, false])
	_check("Big hit's telegraph has its own tint (the threat color elsewhere)", [BIG_HIT.get(&"telegraph_color") != Telegraph.THREAT_COLOR, SLAM.get(&"telegraph_color")], [true, Telegraph.THREAT_COLOR])
	_check("an ability defaults to not deflectable", Ability.new().deflectable, false)
	_check("the hit carries it (from_ability, make_attack_context)", [HitPipeline.from_ability(null, SLAM, null).deflectable, HitPipeline.from_ability(null, BIG_HIT, null).deflectable], [true, false])
	brute.free()
	slime.free()


# --- The window -------------------------------------------------------------------

func _test_window() -> void:
	_section("The deflect window")
	DeflectComponent.deflect_test_enabled = true
	await _fresh()
	var elite := _spawn(ELITE_SCENE, ARENA + Vector2(0, 220))
	var health := knight.health.current
	knight.dash.try_dash(Vector2.RIGHT)
	_check("a dash opens it", [deflect.is_window_open(), deflect.get_window_left()], [true, 0.15])
	var serial := knight.movement.get_displacement_serial()
	var ctx := _slam_hit(elite)
	_check("a deflectable hit inside it is deflected", [ctx.deflected, ctx.blocked], [true, true])
	_check("...no damage, no knockback (the dash runs on), no status", [knight.health.current, knight.movement.get_displacement_serial(), knight.status_component.has_status(STATUS_SLOW.id)], [health, serial, false])
	_check("...no post-hit i-frames, no unit_hit", [knight.has_invulnerability(Unit.HIT_IFRAMES_ID), _hits.has(ctx)], [false, false])
	_check("...hit_deflected(attacker, defender, ctx)", _deflects.size() == 1 and _deflects[0][0] == elite and _deflects[0][1] == knight and _deflects[0][2] == ctx, true)
	var open := 0   # frames a hit would be deflected in, the dash's own first
	while deflect.is_window_open() and open < 60:
		open += 1
		await get_tree().physics_frame
	_check("it stays open 0.15 s (9 frames, from the dash's frame)", open, 9)

	await _fresh()
	deflect.deflect_window = 0.05
	knight.dash.try_dash(Vector2.RIGHT)
	await _frames(5)
	_check("after a 0.05 s window, still dashing with i-frames", [deflect.is_window_open(), knight.dash.is_dashing(), knight.has_invulnerability(DashComponent.INVULNERABILITY_ID)], [false, true, true])
	var late := _slam_hit(elite)
	_check("the same hit just after the window is blocked, not deflected", [late.blocked, late.deflected, _deflects.size(), knight.health.current], [true, false, 0, health])
	deflect.deflect_window = 0.15

	await _fresh()
	knight.dash.try_dash(Vector2.RIGHT)
	var heavy := HitPipeline.resolve(HitPipeline.from_ability(elite, BIG_HIT, knight))
	_check("a non-deflectable hit inside the window is blocked, not deflected", [heavy.blocked, heavy.deflected, _deflects.size()], [true, false, 0])
	_check("...no streak", [deflect.get_streak(), _streaks.size()], [0, 0])
	elite.queue_free()
	await get_tree().physics_frame


# --- Streak and refund -----------------------------------------------------------

func _test_streak_and_refund() -> void:
	_section("The streak, the refund, the chain window")
	DeflectComponent.deflect_test_enabled = true
	await _fresh()
	var brute := _spawn(BRUTE_SCENE, ARENA + Vector2(0, 200))
	deflect.refund_lifetime = 0.5
	deflect.deflect_test_charge_recharge = 1.0
	_check("the flag on: the dash recharges in the test time", knight.dash.get_recharge_time(), 1.0)
	knight.dash.try_dash(Vector2.RIGHT)
	_check("the dash spends its one charge", knight.dash.get_charges(), 0)
	_brute_hit(brute)
	_check("the first deflect: streak 1, the charge back, a refund", [deflect.get_streak(), knight.dash.get_charges(), knight.dash.has_refund(), knight.dash.get_refund_left()], [1, 1, true, 0.5])
	await _wait_until(func() -> bool: return not knight.dash.has_refund(), 120)
	_check("unused, the refund goes after refund_lifetime: the normal recharge runs", [knight.dash.get_charges(), deflect.get_streak()], [0, 1])
	await _seconds(0.9)
	_check("...not back yet at 0.9 s", knight.dash.get_charges(), 0)
	await _seconds(0.15)
	_check("...back at 1.0 s", knight.dash.get_charges(), 1)

	knight.dash.try_dash(Vector2.LEFT)
	await _wait_until(func() -> bool: return not knight.dash.is_dashing() and not deflect.is_window_open(), 60)
	await get_tree().physics_frame
	_check("a plain dash ends the streak", [deflect.get_streak(), _streaks], [0, [1, 0]])

	await _fresh()
	deflect.chain_window = 0.5
	knight.dash.try_dash(Vector2.RIGHT)
	_brute_hit(brute)
	await _seconds(0.4)
	_check("the streak holds inside the chain window", deflect.get_streak(), 1)
	await _seconds(0.2)
	_check("the chain window ends it", [deflect.get_streak(), _streaks], [0, [1, 0]])
	deflect.chain_window = 4.0

	await _fresh()
	deflect.refund_lifetime = 3.0
	deflect.deflect_test_charge_recharge = 1.0
	knight.dash.try_dash(Vector2.RIGHT)
	_brute_hit(brute)
	await _wait_until(func() -> bool: return not knight.dash.is_dashing(), 60)
	_check("the refund is there", [knight.dash.get_charges(), knight.dash.has_refund()], [1, true])
	knight.dash.try_dash(Vector2.LEFT)
	_check("a dash spends the refund", [knight.dash.get_charges(), knight.dash.has_refund()], [0, false])
	_brute_hit(brute)
	_check("the second deflect: no refund, the riposte, the streak starts over", [knight.dash.get_charges(), knight.dash.has_refund(), deflect.has_riposte(), deflect.get_streak()], [0, false, true, 0])
	_check("...riposte_ready, the streak events 1, 2, 0", [_ripostes, _streaks], [[knight], [1, 2, 0]])
	await _wait_until(func() -> bool: return not knight.dash.is_dashing(), 60)
	await _seconds(0.9)
	_check("...the normal recharge started with that dash (not back at 0.9 s)", knight.dash.get_charges(), 0)
	await _seconds(0.3)
	_check("...back by 1.2 s", knight.dash.get_charges(), 1)
	brute.queue_free()
	await get_tree().physics_frame


## Ryan's follow-up (2026-10-07): enemies attack too rarely for a 4 s chain,
## so deflects can bank instead (DeflectComponent.streak_persists).
func _test_streak_persists() -> void:
	_section("Deflects bank (streak_persists)")
	DeflectComponent.deflect_test_enabled = true
	await _fresh()
	_check("off as the scene has it (the chain rules above)", deflect.streak_persists, false)
	deflect.streak_persists = true
	deflect.chain_window = 0.5
	deflect.refund_lifetime = 0.3
	var brute := _spawn(BRUTE_SCENE, ARENA + Vector2(0, 200))
	knight.dash.try_dash(Vector2.RIGHT)
	_brute_hit(brute)
	_check("a deflect: streak 1 and the refund, as before", [deflect.get_streak(), knight.dash.has_refund()], [1, true])
	await _seconds(0.7)
	_check("past the chain window it stays", [deflect.get_streak(), deflect.get_chain_left()], [1, 0.0])
	await _wait_until(func() -> bool: return knight.dash.get_charges() > 0 and not knight.dash.is_dashing(), 90)
	knight.dash.try_dash(Vector2.LEFT)
	await _wait_until(func() -> bool: return not knight.dash.is_dashing() and not deflect.is_window_open(), 60)
	await get_tree().physics_frame
	_check("a dash that deflects nothing keeps it", [deflect.get_streak(), _streaks], [1, [1]])
	await _wait_until(func() -> bool: return knight.dash.get_charges() > 0, 90)
	knight.dash.try_dash(Vector2.RIGHT)
	_brute_hit(brute)
	var id := DeflectComponent.get_riposte_status_id()
	_check("the second deflect, however late: the riposte, banked (no time limit)", [deflect.has_riposte(), knight.status_component.get_time_left(id), _streaks], [true, -1.0, [1, 2, 0]])
	await _seconds(2.0)
	_check("...still there 2 s later (riposte_window is 1.5)", deflect.has_riposte(), true)
	await _wait_until(func() -> bool: return not knight.dash.is_dashing(), 60)
	_place(knight, ARENA)
	_place(brute, ARENA + Vector2(50, 0))
	var swing := await _swing(Vector2.RIGHT, brute)
	_check("...the next swing that lands uses it (256)", [swing.damage, deflect.has_riposte()], [256.0, false])
	brute.queue_free()
	await get_tree().physics_frame


# --- The riposte ------------------------------------------------------------------

func _test_riposte() -> void:
	_section("The riposte")
	DeflectComponent.deflect_test_enabled = true
	await _fresh()
	var brute := _spawn(BRUTE_SCENE, ARENA + Vector2(0, 200))
	await _deflect_pair(brute)
	var statuses := knight.status_component
	var id := DeflectComponent.get_riposte_status_id()
	var e := statuses.get_status(id)
	_check("an empower status, empower_riposte, tags empower and buff", [id, e != null and e.is_empower(), e != null and e.tags.size() == 2 and e.tags.has(&"empower") and e.tags.has(&"buff")], [&"empower_riposte", true, true])
	_check("...used up by a swing that hits, +3.0 AD ratio, 1.5 s", [e.empower_consumed_by, e.empower_ad_ratio, e.duration], [StatusEffect.EmpowerTrigger.BASIC_ATTACK_HIT, 3.0, 1.5])
	_place(knight, ARENA)
	_place(brute, ARENA + Vector2(50, 0))
	var swing := await _swing(Vector2.RIGHT, brute)
	_check("the next swing that hits deals 4x a swing (256)", swing.damage, 256.0)
	_check("...it's used up, the hit is tagged empowered", [statuses.has_status(id), swing.empowered], [false, true])
	print("  INFO  the riposte on the elite slime (900, 0 armor): %.0f%% of its health; a crit (x1.75): %.0f%%" % [256.0 / 900.0 * 100.0, 448.0 / 900.0 * 100.0])
	print("  INFO  on the duelist (2800, 30 armor): %.0f damage, %.1f%% of its health" % [256.0 * HitPipeline.get_mitigation_multiplier(30.0), 256.0 * HitPipeline.get_mitigation_multiplier(30.0) / 2800.0 * 100.0])

	await _fresh()
	await _deflect_pair(brute)
	_place(knight, ARENA)
	_place(brute, ARENA + Vector2(50, 0))
	var dash_strike := await _swing(Vector2.RIGHT, brute, true)
	_check("on a dash-strike swing the ratios add: (1.5 + 3.0) x 64 = 288", [dash_strike.damage, dash_strike.dash_strike], [288.0, true])
	print("  INFO  the riposte on a dash-strike: 288 (4.5x a swing, 1.125x a plain riposte); not absurd, no priority rule")

	await _fresh()
	await _deflect_pair(brute)
	_place(knight, ARENA)
	_place(brute, ARENA + Vector2(0, 300))
	var whiff := await _swing(Vector2.RIGHT, brute)
	_check("a swing that hits nothing keeps it", [whiff.damage, statuses.has_status(id)], [0.0, true])
	await _seconds(1.6)
	_check("it runs out after riposte_window", statuses.has_status(id), false)
	brute.queue_free()
	await get_tree().physics_frame


func _test_riposte_snap() -> void:
	_section("The riposte's snap toward the attacker")
	DeflectComponent.deflect_test_enabled = true
	await _fresh()
	var brute := _spawn(BRUTE_SCENE, ARENA + Vector2(0, 200))
	# Edge 110 px away: past the normal step (24 px) and reach (56 + 10%).
	var center := 110.0 + BRUTE_RADIUS_PX
	_place(knight, ARENA)
	_place(brute, ARENA + Vector2(center, 0))
	var plain := await _swing(Vector2.RIGHT, brute)
	_check("without the riposte a swing can't reach an edge 110 px away", plain.damage, 0.0)
	await _deflect_pair(brute)
	_place(knight, ARENA)
	_place(brute, ARENA + Vector2(center, 0))
	var snap_swing := await _swing(Vector2.UP, brute)
	_check("the riposte swing snaps to it (aim and step) and lands", [snap_swing.damage, snap_swing.moved > 60.0], [256.0, true])
	await _fresh()
	await _deflect_pair(brute)
	_place(knight, ARENA)
	_place(brute, ARENA + Vector2(170.0 + BRUTE_RADIUS_PX, 0))
	var far := await _swing(Vector2.RIGHT, brute)
	_check("past riposte_snap_range (3 m): no snap, a whiff, the riposte kept", [far.damage, deflect.has_riposte()], [0.0, true])
	DeflectComponent.deflect_test_enabled = false
	_place(knight, ARENA)
	_place(brute, ARENA + Vector2(center, 0))
	var off := await _swing(Vector2.RIGHT, brute)
	_check("the flag off: no snap even with the empower on", off.damage, 0.0)
	brute.queue_free()
	await get_tree().physics_frame


# --- Weak basic attacks (ARCHETYPES AR4) ----------------------------------------------

## AR4 (D12): a swing with no empower deals x its champion's
## unempowered_attack_damage (0.5): the Knight's plain swings and his
## dash-strike, an ally Knight's; the riposte and Iron Resolve's swing full;
## Fury per hit unchanged; an enemy's League-style attack untouched. The TEMP
## weak-auto lever it replaced stays at 1.0 (off; it goes with Ryan's OK).
## (Korsavil's three swings at half: the champions test.)
func _test_ar4_weak() -> void:
	_section("AR4: weak basic attacks (the TEMP lever off)")
	DeflectComponent.deflect_test_enabled = true
	await _fresh()
	_check("the TEMP lever is off (1.0); the Knight's stat is 0.5, live", [AutoAttackComponent.prototype_unempowered_auto_mult,
		knight.stats_component.get_stat(&"unempowered_attack_damage"), knight.attack.get_unempowered_attack_damage()], [1.0, 0.5, 0.5])
	var brute := _spawn(BRUTE_SCENE, ARENA + Vector2(50, 0))
	var decay := knight.resource_pool.decay_per_second
	knight.resource_pool.decay_per_second = 0.0   # Fury's decay would blur the +8 per hit
	var fury := knight.resource_pool.current
	var weak := await _swing(Vector2.RIGHT, brute)
	_check("a plain swing deals 32 (64 x 0.5), Fury unchanged (+8)", [weak.damage, weak.empowered, knight.resource_pool.current - fury], [32.0, false, 8.0])
	var weak_dash := await _swing(Vector2.RIGHT, brute, true)
	_check("...a dash-strike 48 (1.5 x 64 x 0.5)", [weak_dash.damage, weak_dash.dash_strike], [48.0, true])
	knight.stats_component.add_modifier(StatModifier.create(&"unempowered_attack_damage", FLAT, 0.5, FULL_SWINGS_SOURCE))
	var at_one := await _swing(Vector2.RIGHT, brute)
	_check("the stat at 1 gives the full swing (64)", at_one.damage, 64.0)
	knight.stats_component.add_modifier(StatModifier.create(&"unempowered_attack_damage", FLAT, 5.0, FULL_SWINGS_SOURCE))
	_check("...it's capped at 1 (a plain swing never deals more than a full one)", knight.stats_component.get_stat(&"unempowered_attack_damage"), 1.0)
	knight.stats_component.remove_modifiers_from(FULL_SWINGS_SOURCE)
	knight.resource_pool.decay_per_second = decay
	await _fresh()
	await _deflect_pair(brute)
	_place(knight, ARENA)
	_place(brute, ARENA + Vector2(50, 0))
	var riposte := await _swing(Vector2.RIGHT, brute)
	_check("the riposte is full (256)", [riposte.damage, riposte.empowered], [256.0, true])
	knight.resource_pool.restore(1000.0)
	knight.abilities.reset_cooldown(&"w")
	await get_tree().physics_frame
	var iron_bonus := knight.abilities.get_ability(&"w").get_damage(knight)
	_check("Iron Resolve casts", knight.cast_ability(&"w", knight.global_position + Vector2.RIGHT * 40.0), true)
	await _wait_until(func() -> bool: return not knight.abilities.casting, 60)
	var iron := await _swing(Vector2.RIGHT, brute)
	_check("an Iron Resolve swing is full (64 + its bonus)", [iron.damage, iron.empowered], [64.0 + iron_bonus, true])
	var after := await _swing(Vector2.RIGHT, brute)
	_check("...the swing after it plain again (32)", [after.damage, after.empowered], [32.0, false])

	var dummy := _spawn(SLIME_SCENE, ARENA + Vector2(0, 260))
	dummy.team = Unit.Team.PLAYER
	var hitter := _spawn(BRUTE_SCENE, ARENA + Vector2(30, 260))
	_check("an enemy keeps 1 (its basic attacks are its damage)", hitter.stats_component.get_stat(&"unempowered_attack_damage"), 1.0)
	hitter.attack.attack(dummy)
	var dummy_health := dummy.health.current
	await _wait_until(func() -> bool: return dummy.health.current < dummy_health, 120)
	_check("...its League-style attack is untouched (26)", dummy_health - dummy.health.current, 26.0)
	hitter.attack.cancel()

	var ally := PLAYER_SCENE.instantiate() as Player
	entities.add_child(ally)
	await get_tree().physics_frame
	Progress.track(knight, KNIGHT)   # the stand-in ally isn't the tracked player
	var ally_crit := ally.stats_component.get_base_value(&"crit_chance")
	ally.stats_component.add_modifier(StatModifier.create(&"crit_chance", FLAT, -ally_crit, BASELINE_SOURCE))
	_place(ally, ARENA + Vector2(0, -260))
	var ally_target := _spawn(BRUTE_SCENE, ARENA + Vector2(50, -260))
	var before := ally_target.health.current
	ally.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return ally_target.health.current < before, 30)
	_check("an ally Knight (not the tracked player) deals half too (32): the stat is the champion's", before - ally_target.health.current, 32.0)
	for n: Node in [brute, dummy, hitter, ally, ally_target]:
		n.queue_free()
	await _frames(2)


## AR4's data: the stat in the registry, 0.5 on every champion's UnitStats,
## 1 on every other unit's.
func _test_ar4_data() -> void:
	_section("AR4: the stat unempowered_attack_damage")
	var def := knight.stats_component.registry.get_definition(&"unempowered_attack_damage")
	_check("registered", def != null, true)
	if def == null:
		return
	_check("...default 1, limits 0 to 1, shown as a percent", [def.default_value, def.has_min, def.min_value, def.has_max, def.max_value, def.format],
		[1.0, true, 0.0, true, 1.0, StatDefinition.Format.PERCENT])
	var champion_stats: Dictionary = {}   # resource_path -> champion id
	for file in DirAccess.get_files_at("res://data/champions/"):
		var champion := load("res://data/champions/" + file.trim_suffix(".remap")) as ChampionData
		if champion != null and champion.stats != null:
			champion_stats[champion.stats.resource_path] = champion.id
	var champions: Dictionary = {}   # champion id -> its value
	var others: Array = []   # [file, value] of any other unit off 1
	for file in DirAccess.get_files_at("res://data/units/"):
		var path := "res://data/units/" + file.trim_suffix(".remap")
		var stats := load(path) as UnitStats
		if stats == null:
			continue
		if champion_stats.has(path):
			champions[champion_stats[path]] = stats.unempowered_attack_damage
		elif not is_equal_approx(stats.unempowered_attack_damage, 1.0):
			others.append([file, stats.unempowered_attack_damage])
	_check("every champion's UnitStats sets 0.5 (the Knight, Korsavil)", champions, {&"knight": 0.5, &"korsavil": 0.5})
	_check("every other unit keeps 1 (enemies)", others, [])


## AR4's check (D12): the rotation simulation. The Knight against a held
## target (passive and put back on its spot every tick: a training dummy, the
## same for both runs), from full health, Fury empty and every cooldown
## ready, his crit at 0 and Unbroken off (the suite's baseline). Only swings:
## a swing as soon as one can start. The kit: the same, plus each ability as
## soon as it's ready, cast between swings (_kit_cast()). Kill times in
## physics ticks; only swings must take at least twice as long as the kit
## against the elite slime (D12). Against the test duelist (2800 health, 30
## armor: a fight about four times as long, Judgement landing once) the kit
## measured 1.89x at 0.5 (1.95x at 0.45, 2.01x at 0.4), so its bar guards
## today's number, 1.85x, and the gap to 2x is ARCHETYPES' open question for
## the Knight's kit (Ryan, 2026-10-09: keep 0.5, record the gap).
func _test_ar4_rotation() -> void:
	_section("AR4: the rotation simulation (only swings at least 2x slower than the kit on the elite slime)")
	DeflectComponent.deflect_test_enabled = false
	PoiseComponent.poise_test_enabled = false
	var hitstop_scale := GameFeel.hitstop_time_scale
	GameFeel.hitstop_time_scale = 1.0   # a hitstop runs in real time: it would stretch the runs unevenly
	for entry: Array in [[ELITE_SCENE, "the elite slime", 2.0], [DUELIST_SCENE, "the test duelist", DUELIST_ROTATION_BAR]]:
		var swings: Dictionary = await _kill_time(entry[0], false)
		var kit: Dictionary = await _kill_time(entry[0], true)
		var s: float = swings.time
		var k: float = kit.time
		var bar: float = entry[2]
		print("    %s: only swings %.2f s, the kit %.2f s (x%.2f); casts %s" % [entry[1], s, k, s / maxf(k, 0.001), kit.casts])
		_check("%s: both runs kill it, never out of reach" % entry[1], [swings.killed, kit.killed, swings.replaced, kit.replaced], [true, true, 0, 0])
		_check("%s: only swings (%.1f s) at least %.2fx the kit (%.1f s)" % [entry[1], s, bar, k], k > 0.0 and s >= bar * k, true)
	GameFeel.hitstop_time_scale = hitstop_scale


## One run of the rotation simulation against a fresh `scene`: {time (s),
## killed, casts (per slot), replaced (times the Knight was put back in
## reach: 0 expected)}.
func _kill_time(scene: PackedScene, use_kit: bool) -> Dictionary:
	await _fresh()
	for slot: StringName in [&"q", &"w", &"e", &"r"]:
		knight.abilities.reset_cooldown(slot)
	knight.resource_pool.try_spend(knight.resource_pool.current)   # Fury empty, as a fight starts
	var target := _spawn(scene, ROTATION_SPOT)
	var gap := knight.get_gameplay_radius_px() + target.get_gameplay_radius_px() + 16.0
	_place(knight, ROTATION_SPOT - Vector2(gap, 0))
	await _frames(2)
	target.health.heal(100000.0)
	var casts := {&"q": 0, &"w": 0, &"e": 0, &"r": 0}
	var replaced := 0
	var ticks := 0
	var limit := roundi(ROTATION_LIMIT * Engine.physics_ticks_per_second)
	while is_instance_valid(target) and target.is_alive() and ticks < limit:
		_place(target, ROTATION_SPOT)   # held: its knockback undone
		var to := ROTATION_SPOT - knight.global_position
		var busy := knight.abilities.casting or knight.dash.is_dashing() or knight.movement.is_displaced()
		if not busy and knight.attack.can_swing() and to.length() > gap + KNIGHT_REACH_PX * 0.5:
			replaced += 1   # out of reach: put back (none expected; it would flatter the run)
			_place(knight, ROTATION_SPOT - to.normalized() * gap)
			to = ROTATION_SPOT - knight.global_position
		var direction := to.normalized() if to.length() > 0.01 else Vector2.RIGHT
		if use_kit and not knight.abilities.casting and (not knight.attack.is_swinging() or knight.attack.is_in_recovery()):
			var slot := _kit_cast(target, direction)
			if slot != &"":
				casts[slot] += 1
		if not knight.abilities.casting:
			knight.attack.try_swing(direction)
		await get_tree().physics_frame
		ticks += 1
	var killed := not is_instance_valid(target) or not target.is_alive()
	if is_instance_valid(target):
		target.queue_free()
	await _frames(2)
	return {"time": float(ticks) / Engine.physics_ticks_per_second, "killed": killed, "casts": casts, "replaced": replaced}


## The kit's next cast, if any, as a player using it would: Judgement once
## Fury reaches its 60 payoff (CHAMPIONS CH4), Iron Resolve when no swing
## empower is waiting, Lunge through the target, Cleave when its 20 Fury
## leaves Judgement's 60 while Judgement is ready. Returns the slot cast.
func _kit_cast(target: Unit, direction: Vector2) -> StringName:
	var a := knight.abilities
	var fury := knight.resource_pool.current
	var at := target.global_position
	if a.can_cast(&"r") and fury >= 60.0 and a.try_cast(&"r", at, target):
		return &"r"
	if a.can_cast(&"w") and not knight.attack.is_empowered() and a.try_cast(&"w", knight.global_position + direction * 40.0):
		return &"w"
	if a.can_cast(&"e") and a.try_cast(&"e", at + direction * target.get_gameplay_radius_px()):
		return &"e"
	var keep := 60.0 if a.is_ready(&"r") else 0.0
	if a.can_cast(&"q") and fury >= 20.0 + keep and a.try_cast(&"q", at):
		return &"q"
	return &""


# --- Sources it wasn't written for ------------------------------------------------

func _test_other_sources() -> void:
	_section("A deflect on sources it wasn't written for (the hook is on Unit)")
	DeflectComponent.deflect_test_enabled = true
	await _fresh()
	var slime := _spawn(SLIME_SCENE, ARENA + Vector2(0, 200))
	slime.attack.deflectable = true   # a source that never knew about deflects, marked deflectable
	knight.dash.try_dash(Vector2.RIGHT)
	var ctx := HitPipeline.resolve(slime.attack.make_attack_context(knight))
	_check("a slime's attack marked deflectable is deflected", [ctx.deflected, _deflects.size(), _deflects[0][0] if _deflects.size() > 0 else null], [true, 1, slime])
	await _fresh()
	var caster := _spawn(BRUTE_SCENE, ARENA + Vector2(0, 260))
	var bolt: Ability = BOLT.duplicate()
	bolt.deflectable = true
	knight.dash.try_dash(Vector2.RIGHT)
	var bolt_hit := HitPipeline.resolve(HitPipeline.from_ability(caster, bolt, knight))
	_check("a bolt copy marked deflectable is deflected", [bolt_hit.deflected, bolt_hit.blocked], [true, true])

	# Enemies don't deflect here, but a unit with the node can: a brute with one.
	var guard := BRUTE_SCENE.instantiate() as Enemy
	var node := DeflectComponent.new()
	node.name = "DeflectComponent"
	guard.add_child(node)
	guard.passive = true
	entities.add_child(guard)
	_place(guard, ARENA + Vector2(0, 330))
	await get_tree().physics_frame
	_check("a brute built with the node has it", guard.deflect_component == node, true)
	node.open_window()
	var from_knight := HitPipeline.from_ability(knight, SLAM, guard)
	from_knight.perilous = false   # a plain deflectable hit (the slam is perilous since AR2: a perilous deflect would rebuff the Knight)
	from_knight.tags.erase(&"perilous")
	from_knight = HitPipeline.resolve(from_knight)
	_check("its window deflects a deflectable hit from the Knight's side", [from_knight.deflected, guard.health.current], [true, guard.health.max_health])
	var cleave := HitPipeline.resolve(HitPipeline.from_ability(knight, knight.abilities.get_ability(&"q"), guard))
	_check("...but not a non-deflectable one (no i-frames: it lands)", [cleave.deflected, cleave.blocked], [false, false])
	for n: Node in [slime, caster, guard]:
		n.queue_free()
	await _frames(2)


# --- ARCHETYPES AR2: a perilous attack deflected -----------------------------------------

func _test_perilous_deflect() -> void:
	_section("ARCHETYPES AR2: a perilous attack deflected counts as two (straight to the riposte), its attacker rebuffed 1.0 s (not crowd control)")
	DeflectComponent.deflect_test_enabled = true
	await _fresh()
	var elite := _spawn(ELITE_SCENE, ARENA + Vector2(0, 220))
	var st := elite.status_component
	var rebuffed := STATUS_REBUFFED_PERILOUS.id
	var health := knight.health.current
	knight.dash.try_dash(Vector2.RIGHT)
	var ctx := _slam_hit(elite, true)
	_check("the slam's hit is perilous (HitContext.perilous, the hit tag)", [ctx.perilous, ctx.has_tag(&"perilous")], [true, true])
	_check("one deflect: deflected, no damage", [ctx.deflected, knight.health.current], [true, health])
	_check("...counts as two: the riposte at once (streak events 2, then 0), and the refund (the first of its streak)",
		[deflect.has_riposte(), _streaks, knight.dash.has_refund()], [true, [2, 0], true])
	_check("...its attacker rebuffed for 1.0 s (status_rebuffed_perilous, tags rebuffed and debuff)",
		[st.has_status(rebuffed), snappedf(st.get_time_left(rebuffed), 0.01), STATUS_REBUFFED_PERILOUS.tags], [true, 1.0, [&"rebuffed", &"debuff"]])
	_check("...it can't attack, cast or dash (Enemy.is_cc_blocked(): its string ends, its token goes), but it can walk",
		[elite.is_cc_blocked(), elite.is_cast_blocked(), elite.is_dash_blocked(), STATUS_REBUFFED_PERILOUS.blocks_move], [true, true, true, false])
	_check("...not crowd control: not cc, diminishing returns don't count it, no cleanse ends it",
		[STATUS_REBUFFED_PERILOUS.is_cc(), StatusComponent.counts_for_diminishing(STATUS_REBUFFED_PERILOUS), STATUS_REBUFFED_PERILOUS.cleansable], [false, false, false])
	await _seconds(1.05)
	_check("...gone after 1.0 s", st.has_status(rebuffed), false)

	await _fresh()
	knight.dash.try_dash(Vector2.RIGHT)
	_slam_hit(elite)
	await _wait_until(func() -> bool: return not knight.dash.is_dashing(), 60)
	knight.dash.try_dash(Vector2.LEFT)
	_slam_hit(elite, true)
	_check("after a plain deflect, a perilous one gives the riposte too (streak events 1, 3, 0), no second refund",
		[deflect.has_riposte(), _streaks, knight.dash.has_refund()], [true, [1, 3, 0], false])

	await _fresh()
	st.remove_status(rebuffed)   # the pair's own rebuff, still on
	DeflectComponent.deflect_test_enabled = false
	knight.dash.try_dash(Vector2.RIGHT)
	var off := _slam_hit(elite, true)
	_check("the flag off: a perilous hit during a dash is only blocked by the i-frames (no deflect, no rebuff)",
		[off.blocked, off.deflected, st.has_status(rebuffed)], [true, false, false])
	DeflectComponent.deflect_test_enabled = true
	elite.queue_free()
	await _frames(2)


# --- Poise (slice B) ----------------------------------------------------------------

func _test_poise_flags_off() -> void:
	_section("Poise: the flag off changes nothing")
	PoiseComponent.poise_test_enabled = false
	DeflectComponent.deflect_test_enabled = false
	await _fresh()
	_poise_breaks.clear()
	_poise_changes.clear()
	var elite := _spawn(ELITE_SCENE, ARENA + Vector2(55, 0))
	var p := elite.poise_component
	_check("the elite has its meter's 100 from its data, but off it acts as 0", [p != null, p.poise_max, p.get_max_poise(), p.get_poise()], [true, 100.0, 0.0, 0.0])
	p.take_poise_damage(1000.0, knight)
	_check("1000 poise damage: no break, no status, no events", [p.is_broken(), elite.status_component.has_status(STATUS_POISE_BROKEN.id), _poise_breaks.size(), _poise_changes.size()], [false, false, 0, 0])
	var swing := await _swing(Vector2.RIGHT, elite)
	var hit := _last_hit_on(elite)
	_check("a Knight swing deals its 32 as before (a plain swing, AR4); its 4 poise damage does nothing", [swing.damage, hit.poise_damage if hit else -1.0, p.get_poise(), _poise_changes.size()], [32.0, 4.0, 0.0, 0])
	elite.queue_free()
	await get_tree().physics_frame


func _test_poise_data() -> void:
	_section("Poise: who has it, and the sources (data)")
	_check("the elite slime and the duelist: 100 (the prototype's meters)", [ELITE_DATA.poise_max, DUELIST_DATA.poise_max], [100.0, 100.0])
	_check("fodder, regulars and the elite caster: −1, their rank's only if their archetype had a meter (none does)", [SLIME_DATA.poise_max, BRUTE_DATA.poise_max, SKIRMISHER_DATA.poise_max, CASTER_ELITE_DATA.poise_max], [-1.0, -1.0, -1.0, -1.0])
	_check("EnemyData defaults to −1 (AR3a); the player has no meter", [EnemyData.new().poise_max, knight.poise_component == null], [-1.0, true])
	var swings: Array = COMBO_KNIGHT.swings.map(func(swing: AttackSwing) -> float: return swing.poise_damage)
	swings.append(COMBO_KNIGHT.dash_strike.poise_damage)
	_check("the Knight's swings 4 each (the dash-strike too)", swings, [4.0, 4.0, 4.0, 4.0])
	_check("Cleave 20 (Cleave Wave too), Judgement 40 (its leap too)", [CLEAVE.poise_damage, CLEAVE_WAVE.poise_damage, JUDGEMENT.poise_damage, JUDGEMENT_LEAP.poise_damage], [20.0, 20.0, 40.0, 40.0])
	_check("enemy abilities carry none", [SLAM.poise_damage, FINISHER.poise_damage, AttackSwing.new().poise_damage], [0.0, 0.0, 0.0])
	_check("the deflects 25 and 50, the riposte 40", [deflect.deflect_poise_damage_first, deflect.deflect_poise_damage_second, deflect.riposte_poise_damage], [25.0, 50.0, 40.0])
	var p := PoiseComponent.new()
	var r := p.get_rules()
	_check("the meter's numbers (poise_rules_assassin.tres): 3 s delay, 15/s, ×0.5 below 40% health, +50%, 4 s immune; a 1.8 s break unless its rank says",
		[p.poise_max, r == PoiseComponent.DEFAULT_RULES, r.decay_delay, r.decay_rate, r.low_health, r.low_health_decay_scale, r.break_damage_bonus, r.break_immunity, p.poise_break_time],
		[0.0, true, 3.0, 15.0, 0.4, 0.5, 0.5, 4.0, 1.8])
	p.free()
	var s := STATUS_POISE_BROKEN
	_check("status_poise_broken: tags poise_broken + debuff, not cc, not counted", [s.id, s.tags.size() == 2 and s.tags.has(&"poise_broken") and s.tags.has(&"debuff"), s.is_cc(), StatusComponent.counts_for_diminishing(s)], [&"poise_broken", true, false, false])
	_check("...it blocks moving, attacking, casting and dashing; no cleanse", [s.blocks_move, s.blocks_attack, s.blocks_cast, s.blocks_dash, s.cleansable], [true, true, true, true, false])


func _test_poise_meter() -> void:
	_section("Poise: the meter fills up to a break (ARCHETYPES AR3a, D1)")
	PoiseComponent.poise_test_enabled = true
	DeflectComponent.deflect_test_enabled = false
	await _fresh()
	_poise_changes.clear()
	var elite := _spawn(ELITE_SCENE, ARENA + Vector2(0, 200))
	var p := elite.poise_component
	_check("on: it starts empty, its size 100", [p.get_max_poise(), p.get_poise()], [100.0, 0.0])
	p.take_poise_damage(25.0, knight)
	_check("poise damage fills it", p.get_poise(), 25.0)
	var last: Array = _poise_changes.back() if not _poise_changes.is_empty() else []
	_check("...Events.poise_changed(unit, 25, 100)", last, [elite, 25.0, 100.0])
	await _seconds(2.9)
	_check("it doesn't decay before the 3 s delay", p.get_poise(), 25.0)
	await _seconds(1.1)
	_check("then it decays at 15/s (about 10 at 4 s)", absf(p.get_poise() - 10.0) <= 0.6, true)
	await _seconds(1.0)
	_check("...down to 0, no less", p.get_poise(), 0.0)
	p.take_poise_damage(10.0, knight)
	await _seconds(2.0)
	p.take_poise_damage(10.0, knight)
	await _seconds(2.0)
	_check("new poise damage restarts the delay", p.get_poise(), 20.0)
	_check("at full health it decays at 15/s", p.get_decay_rate(), 15.0)
	elite.health.take_damage(elite.health.max_health * 0.7)
	_check("below 40% of its health (30%) at half the rate: 7.5/s (D1)", p.get_decay_rate(), 7.5)
	p.take_poise_damage(30.0, knight)
	await _seconds(4.0)
	_check("...so 50, one second past the delay, is about 42.5", absf(p.get_poise() - 42.5) <= 0.4, true)
	elite.health.heal(100000.0)
	var brute := _spawn(BRUTE_SCENE, ARENA + Vector2(0, 260))
	brute.poise_component.take_poise_damage(1000.0, knight)
	_check("a regular brute (a Bruiser, −1: no meter): nothing happens", [brute.poise_component.poise_max, brute.poise_component.get_poise(), brute.poise_component.is_broken(), brute.status_component.has_status(STATUS_POISE_BROKEN.id)], [0.0, 0.0, false, false])
	elite.queue_free()
	brute.queue_free()
	await get_tree().physics_frame


func _test_poise_break() -> void:
	_section("Poise: the break")
	PoiseComponent.poise_test_enabled = true
	DeflectComponent.deflect_test_enabled = false
	await _fresh()
	_poise_breaks.clear()
	var elite := _spawn(ELITE_SCENE, ARENA + Vector2(60, 0))
	var p := elite.poise_component
	var health := knight.health.current
	_check("the elite starts its slam at the Knight", elite.abilities.try_cast(&"q", knight.global_position, knight), true)
	await _frames(3)
	p.take_poise_damage(4.0, knight)
	_check("poise short of the maximum doesn't flinch it: still casting", [elite.abilities.casting, p.is_broken(), p.get_poise()], [true, false, 4.0])
	p.take_poise_damage(96.0, knight)
	_check("at the maximum it breaks: poise_broken, Events.poise_broken", [p.is_broken(), elite.status_component.has_status(STATUS_POISE_BROKEN.id), _poise_breaks], [true, true, [elite]])
	_check("...its cast is cut at once", elite.abilities.casting, false)
	_check("...its 20% elite tenacity doesn't shorten the elite rank's 1.8 s", [elite.stats_component.get_stat(&"tenacity"), p.poise_break_time, p.get_break_left()], [0.2, 1.8, 1.8])
	_check("...diminishing returns don't count it", elite.status_component.get_dr_count(), 0)
	_check("...no moving, casting, dashing; its brain rests (is_cc_blocked)", [elite.movement.can_move(), elite.is_cast_blocked(), elite.is_dash_blocked(), elite.is_cc_blocked()], [false, true, true, true])
	var before := elite.health.current
	elite.take_damage(100.0)
	_check("...it takes 50% more damage (100 -> 150)", before - elite.health.current, 150.0)
	p.take_poise_damage(50.0, knight)
	_check("...the meter reads full while broken; poise damage does nothing", [p.get_poise(), _poise_breaks.size()], [100.0, 1])
	await _seconds(1.0)
	_check("the slam never landed", knight.health.current, health)
	await _wait_until(func() -> bool: return not p.is_broken(), 120)
	_check("after the break: empty again, immune for 4 s", [p.get_poise(), p.is_immune(), absf(p.get_immunity_left() - 4.0) < 0.05], [0.0, true, true])
	before = elite.health.current
	elite.take_damage(100.0)
	_check("...the damage bonus is gone", before - elite.health.current, 100.0)
	p.take_poise_damage(1000.0, knight)
	_check("immune: no second break, poise stays empty", [p.is_broken(), p.get_poise(), _poise_breaks.size()], [false, 0.0, 1])
	await _seconds(4.05)
	p.take_poise_damage(30.0, knight)
	_check("after the immunity it takes poise damage again", [p.is_immune(), p.get_poise()], [false, 30.0])

	var dummy := _spawn(SLIME_SCENE, ARENA + Vector2(0, 260))
	dummy.team = Unit.Team.PLAYER
	var brute := _spawn(BRUTE_SCENE, ARENA + Vector2(30, 260))
	brute.poise_component.poise_max = 100.0   # a regular given a meter for this check
	brute.attack.attack(dummy)
	await _wait_until(func() -> bool: return brute.attack.is_winding_up(), 90)
	_check("a brute winds up its basic attack", brute.attack.is_winding_up(), true)
	var dummy_health := dummy.health.current
	brute.poise_component.take_poise_damage(100.0, knight)
	_check("a break cuts its windup", [brute.poise_component.is_broken(), brute.attack.is_winding_up()], [true, false])
	_check("...for the regular rank's 1.5 s", absf(brute.poise_component.get_break_left() - 1.5) < 0.02, true)
	await _seconds(1.0)
	_check("...and no hit lands while it's broken", dummy.health.current, dummy_health)
	brute.attack.cancel()
	for n: Node in [elite, dummy, brute]:
		n.queue_free()
	await _frames(2)


func _test_poise_sources() -> void:
	_section("Poise damage rides the hits (HitContext.poise_damage)")
	PoiseComponent.poise_test_enabled = true
	DeflectComponent.deflect_test_enabled = true
	await _fresh()
	var elite := _spawn(ELITE_SCENE, ARENA + Vector2(55, 0))
	var p := elite.poise_component
	await _swing(Vector2.RIGHT, elite)
	_check("a Knight swing: 4", p.get_poise(), 4.0)
	await _swing(Vector2.RIGHT, elite, true)
	_check("a dash-strike: 4", p.get_poise(), 8.0)
	HitPipeline.resolve(HitPipeline.from_ability(knight, CLEAVE, elite))
	_check("Cleave: 20", p.get_poise(), 28.0)
	HitPipeline.resolve(HitPipeline.from_ability(knight, JUDGEMENT, elite))
	_check("Judgement: 40", p.get_poise(), 68.0)
	elite.add_invulnerability(&"test")
	HitPipeline.resolve(HitPipeline.from_ability(knight, JUDGEMENT, elite))
	elite.remove_invulnerability(&"test")
	_check("a blocked hit carries none", p.get_poise(), 68.0)
	var fresh := _spawn(ELITE_SCENE, ARENA + Vector2(0, 220))
	knight.dash.try_dash(Vector2.RIGHT)
	_slam_hit(fresh)
	_check("the first deflect: 25 to the attacker", fresh.poise_component.get_poise(), 25.0)
	await _wait_until(func() -> bool: return not knight.dash.is_dashing(), 60)
	knight.dash.try_dash(Vector2.LEFT)
	_slam_hit(fresh)
	_check("the second: 50", fresh.poise_component.get_poise(), 75.0)
	var e := knight.status_component.get_status(DeflectComponent.get_riposte_status_id())
	_check("the riposte empower carries 40", e.empower_poise_damage if e else -1.0, 40.0)
	for n: Node in [elite, fresh]:
		n.queue_free()
	await _frames(2)


func _test_pair_and_riposte_break() -> void:
	_section("A deflect pair plus a riposte breaks a 100-poise elite (the starting numbers)")
	PoiseComponent.poise_test_enabled = true
	DeflectComponent.deflect_test_enabled = true
	for scene: PackedScene in [ELITE_SCENE, DUELIST_SCENE]:
		await _fresh()
		var enemy := _spawn(scene, ARENA + Vector2(0, 220))
		var p := enemy.poise_component
		knight.dash.try_dash(Vector2.RIGHT)
		_slam_hit(enemy)
		await _wait_until(func() -> bool: return not knight.dash.is_dashing(), 60)
		knight.dash.try_dash(Vector2.LEFT)
		_slam_hit(enemy)
		await _wait_until(func() -> bool: return not knight.dash.is_dashing(), 60)
		var label := "the elite slime" if scene == ELITE_SCENE else "the duelist"
		_check("%s: the pair fills 75 of 100, not broken" % label, [p.get_poise(), p.is_broken(), deflect.has_riposte()], [75.0, false, true])
		_place(knight, ARENA)
		_place(enemy, ARENA + Vector2(55, 0))
		var riposte := await _swing(Vector2.RIGHT, enemy)
		var hit := _last_hit_on(enemy)
		_check("...the riposte (40 + the swing's 4) breaks it", [hit.poise_damage if hit else -1.0, p.is_broken()], [44.0, true])
		var expected := 256.0 * HitPipeline.get_mitigation_multiplier(enemy.stats_component.get_stat(&"armor"))
		_check("...the riposte isn't boosted by its own break (%.0f)" % expected, roundi(riposte.damage * 100.0), roundi(expected * 100.0))
		print("  INFO  %s: the riposte dealt %.0f, %.1f%% of its %.0f health" % [label, riposte.damage, riposte.damage / enemy.health.max_health * 100.0, enemy.health.max_health])
		enemy.queue_free()
		await get_tree().physics_frame
	await _fresh()
	var elite := _spawn(ELITE_SCENE, ARENA + Vector2(0, 220))
	for i in 3:
		await _wait_until(func() -> bool: return knight.dash.get_charges() > 0 and not knight.dash.is_dashing(), 120)
		knight.dash.try_dash(Vector2.RIGHT if i % 2 == 0 else Vector2.LEFT)
		_slam_hit(elite)
	_check("three deflects in a row also break it (25 + 50 + 25)", [elite.poise_component.is_broken(), _deflects.size()], [true, 3])
	print("  INFO  deflects alone to break a 100-poise elite: 3 (25 + 50 + 25, inside the 3 s decay delay)")
	elite.queue_free()
	await get_tree().physics_frame


# --- ARCHETYPES AR3a: the Archetype resource and an archetype's meter ----------------

func _test_ar3a_data() -> void:
	_section("AR3a: the Archetype resource, the ranks' meters and break times (data)")
	var a := Archetype.of(&"assassin")
	_check("Archetype.of(&\"assassin\"): its file", [a != null, a.id if a else &"", a.display_name if a else "", a.resource_path if a else ""],
		[true, &"assassin", "Assassin", "res://data/archetypes/archetype_assassin.tres"])
	if a == null:
		return
	_check("...a meter, a deflect, its string (3–4 hits, 0.4 s apart), its dash (×1.25, a 1.2 s recharge), a 0.2 s window, poise_rules_assassin.tres, no layer",
		[a.poise_meter, a.deflects, a.string_hits_min, a.string_hits_max, a.string_spacing, a.dash_distance_scale, a.dash_recharge_time, a.deflect_window,
			a.poise_rules == PoiseComponent.DEFAULT_RULES, a.layer == null, a.get_source_id()],
		[true, true, 3, 4, 0.4, 1.25, 1.2, 0.2, true, true, &"archetype_assassin"])
	_check("loaded once; an id with no file has no archetype (the other five until AR8, an empty id)",
		[Archetype.of(&"assassin") == a, Archetype.of(&"bruiser"), Archetype.of(&"mage"), Archetype.of(&"skirmisher"), Archetype.of(&"basic"), Archetype.of(&"")],
		[true, null, null, null, null, null])
	_check("an enemy's archetype id: fodder basic; the brute preset bruiser (the brute, the elite slime, the duelist until AR8); skirmisher; the casters mage",
		[SLIME_DATA.get_archetype_id(), BRUTE_DATA.get_archetype_id(), ELITE_DATA.get_archetype_id(), DUELIST_DATA.get_archetype_id(),
			SKIRMISHER_DATA.get_archetype_id(), CASTER_ELITE_DATA.get_archetype_id(), EnemyData.new().get_archetype_id()],
		[&"basic", &"bruiser", &"bruiser", &"bruiser", &"skirmisher", &"mage", &"basic"])
	var sizes: Array = []
	var breaks: Array = []
	var ranks: Array[EnemyData.Rank] = [EnemyData.Rank.FODDER, EnemyData.Rank.REGULAR, EnemyData.Rank.ELITE, EnemyData.Rank.BOSS]
	for rank in ranks:
		var rules := Brains.table.get_rank_rules(rank)
		sizes.append(rules.poise_meter_max if rules else -1.0)
		breaks.append(rules.poise_break_time if rules else -1.0)
	_check("the ranks' meters (D8): fodder 0, regular 60, elite 100, boss 160", sizes, [0.0, 60.0, 100.0, 160.0])
	_check("...their break times: 0 (none), 1.5, 1.8, 1.4 s", breaks, [0.0, 1.5, 1.8, 1.4])


func _test_ar3a_meter() -> void:
	_section("AR3a: an archetype with a meter runs it with the flag off, sized and timed by its rank")
	PoiseComponent.poise_test_enabled = false
	DeflectComponent.deflect_test_enabled = true
	await _fresh()
	_poise_breaks.clear()
	var assassin := Archetype.of(&"assassin")
	# A brute (a regular) set up as an enemy Assassin would be at spawn (the
	# test Assassin itself comes in AR3b).
	var regular := _spawn(BRUTE_SCENE, ARENA + Vector2(0, 220))
	var rp := regular.poise_component
	_check("the brute as it spawns: a Bruiser has no meter (no archetype file, −1 -> 0)", [rp.archetype == null, rp.poise_max, rp.is_active()], [true, 0.0, false])
	rp.setup(assassin, -1.0, regular.get_rank_rules())
	_check("set up as an Assassin regular: its rank's 60 and 1.5 s, running with the flag off, on its archetype's rules, empty",
		[rp.has_archetype_meter(), rp.poise_max, rp.poise_break_time, rp.is_active(), rp.get_rules() == assassin.poise_rules, rp.get_poise()],
		[true, 60.0, 1.5, true, true, 0.0])
	knight.dash.try_dash(Vector2.RIGHT)
	_brute_hit(regular)
	_check("the first deflect: 25 of 60", [rp.get_poise(), rp.is_broken()], [25.0, false])
	await _wait_until(func() -> bool: return not knight.dash.is_dashing(), 60)
	knight.dash.try_dash(Vector2.LEFT)
	_brute_hit(regular)
	_check("a regular breaks on the second deflect (75 of 60), for 1.5 s", [rp.is_broken(), absf(rp.get_break_left() - 1.5) < 0.02, _poise_breaks], [true, true, [regular]])
	regular.queue_free()
	await _wait_until(func() -> bool: return not knight.dash.is_dashing(), 60)

	await _fresh()
	var elite := _spawn(ELITE_SCENE, ARENA + Vector2(0, 220))
	var ep := elite.poise_component
	ep.setup(assassin, -1.0, elite.get_rank_rules())
	_check("an Assassin elite: 100 and 1.8 s (its rank's), the flag off", [ep.poise_max, ep.poise_break_time, ep.is_active(), PoiseComponent.poise_test_enabled], [100.0, 1.8, true, false])
	knight.dash.try_dash(Vector2.RIGHT)
	_slam_hit(elite)
	await _wait_until(func() -> bool: return not knight.dash.is_dashing(), 60)
	knight.dash.try_dash(Vector2.LEFT)
	_slam_hit(elite)
	await _wait_until(func() -> bool: return not knight.dash.is_dashing(), 60)
	_check("...the deflect pair fills 75, not broken; the riposte is ready", [ep.get_poise(), ep.is_broken(), deflect.has_riposte()], [75.0, false, true])
	_place(knight, ARENA)
	_place(elite, ARENA + Vector2(55, 0))
	await _swing(Vector2.RIGHT, elite)
	_check("...the riposte (40 + the swing's 4) breaks it, for 1.8 s (AR3's done line)", [ep.is_broken(), absf(ep.get_break_left() - 1.8) < 0.05], [true, true])
	elite.queue_free()
	await get_tree().physics_frame

	var boss := _spawn(BRUTE_SCENE, ARENA + Vector2(0, 260))
	var bp := boss.poise_component
	bp.setup(assassin, -1.0, Brains.table.get_rank_rules(EnemyData.Rank.BOSS))
	_check("with a boss's rank rules: 160 and 1.4 s", [bp.poise_max, bp.poise_break_time], [160.0, 1.4])
	bp.take_poise_damage(25.0, knight)
	bp.take_poise_damage(50.0, knight)
	bp.take_poise_damage(40.0, knight)
	_check("...the pair and the riposte's 40 leave it short (115 of 160)", [bp.get_poise(), bp.is_broken()], [115.0, false])
	bp.take_poise_damage(45.0, knight)
	_check("...45 more break it, for 1.4 s", [bp.is_broken(), absf(bp.get_break_left() - 1.4) < 0.02], [true, true])
	boss.queue_free()
	await get_tree().physics_frame

	var other := _spawn(BRUTE_SCENE, ARENA + Vector2(0, 300))
	var op := other.poise_component
	var rules := other.get_rank_rules()
	op.setup(assassin, 0.0, rules)
	var none := [op.poise_max, op.is_active()]
	op.setup(assassin, 80.0, rules)
	var own := [op.poise_max, op.is_active()]
	op.setup(null, -1.0, rules)
	var no_archetype := [op.poise_max, op.is_active()]
	op.setup(null, 100.0, rules)
	var prototype_off := op.is_active()
	PoiseComponent.poise_test_enabled = true
	var prototype_on := op.is_active()
	PoiseComponent.poise_test_enabled = false
	_check("its data's size: 0 = none, 80 = that size; no archetype with −1: none; a size with no archetype meter runs only with the flag (the prototype's)",
		[none, own, no_archetype, prototype_off, prototype_on], [[0.0, false], [80.0, true], [0.0, false], false, true])
	other.queue_free()
	await get_tree().physics_frame


# --- ARCHETYPES AR3b: the test Assassin's Riposte Stance -------------------------------

func _test_ar3b_stance() -> void:
	_section("AR3b: the test Assassin's Riposte Stance: its archetype runs it (no flag), a 0.5 s window, one deflect, the champion rebuffed, its riposte at once, what it deflects, a stun cuts it, its whiff recovery, its own meter")
	DeflectComponent.deflect_test_enabled = false
	PoiseComponent.poise_test_enabled = false
	await _fresh()
	var r := STATUS_REBUFFED
	_check("status_rebuffed: tags rebuffed + debuff, 0.4 s, blocks only attacking; not cc, not counted, no cleanse, tenacity ignored",
		[r.id, r.tags.size() == 2 and r.tags.has(&"rebuffed") and r.tags.has(&"debuff"), r.duration, r.blocks_attack, r.blocks_move, r.blocks_cast, r.blocks_dash,
			r.is_cc(), StatusComponent.counts_for_diminishing(r), r.cleansable, r.ignores_tenacity],
		[&"rebuffed", true, 0.4, true, false, false, false, false, false, false, true])
	var a := _spawn(ASSASSIN_SCENE, ARENA + Vector2(55, 0))
	await get_tree().physics_frame
	var ad := a.deflect_component
	var ap := a.poise_component
	_check("the test Assassin, both flags off: its archetype runs its deflect and its meter (the elite's 100, empty); the Knight's deflect stays off",
		[ad != null, ad.has_archetype_deflect() if ad else false, ad.is_active() if ad else false, ap.has_archetype_meter(), ap.poise_max, ap.get_poise(), deflect.is_active()],
		[true, true, true, true, 100.0, 0.0, false])
	if ad == null:
		return
	knight.attack.cancel_swing()
	await _wait_until(func() -> bool: return knight.attack.can_swing(), 60)
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 60)
	var first_landed := _last_hit_on(a) != null
	var next_index := knight.attack.get_combo_index()
	a.health.heal(100000.0)
	_raise_stance(a)
	_check("the Knight's swing 1 lands (his combo moves on to %d); its stance (Q, no cast time): the window open 0.5 s, it stands still, casting, in its pose" % next_index,
		[first_landed, next_index > 0, ad.is_window_open(), absf(ad.get_window_left() - 0.5) < 0.02, a.movement.can_move(), a.abilities.casting, a.get_pose()],
		[true, true, true, true, false, true, &"riposte_stance"])
	var health := a.health.current
	_deflects.clear()
	_ripostes.clear()
	await _wait_until(func() -> bool: return knight.attack.can_swing(), 60)
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return not _deflects.is_empty(), 60)
	var deflected_at := Brains.get_time()
	var d: Array = _deflects.back() if not _deflects.is_empty() else [null, null, null]
	var ctx: HitContext = d[2]
	_check("his swing 2 is deflected: the Knight's hit, blocked, no damage; the window closes (one hit per stance)",
		[d[0] == knight, d[1] == a, ctx.deflected if ctx else false, ctx.blocked if ctx else false, a.health.current, ad.is_window_open(), ad.get_window_deflects()],
		[true, true, true, true, health, false, 1])
	var left := knight.status_component.get_time_left(STATUS_REBUFFED.id)
	await get_tree().physics_frame   # the swing's cancel (deferred out of its hit) and the stance's end
	_check("the Knight is rebuffed (0.4 s): his swing gone, his combo back to swing 1, no attacking",
		[left > 0.35 and left <= 0.4, knight.attack.is_swinging(), knight.attack.get_combo_index(), knight.attack.can_swing()], [true, false, 0, false])
	var empower := a.status_component.get_status(DeflectComponent.get_riposte_status_id())
	_check("its riposte: empower_riposte (+1.0 AD ratio on its next basic attack hit, 1 s), Events.riposte_ready; the stance over with no recovery; its basic attack on the Knight at once",
		[empower != null, empower.empower_ad_ratio if empower else -1.0, empower.duration if empower else -1.0, _ripostes == [a], a.abilities.casting, a.abilities.is_recovering(), a.attack.target == knight],
		[true, 1.0, 1.0, true, false, false, true])
	await _wait_until(func() -> bool: return _hit_by(a, knight) != null, 60)
	var riposte := _hit_by(a, knight)
	var took := Brains.get_time() - deflected_at
	_check("...it lands %.2f s after the deflect (its 0.25 s wind-up): twice its 40 AD (80 before armor), deflectable, the empower used" % took,
		[took > 0.2 and took < 0.36, riposte.raw_damage if riposte else -1.0, riposte.deflectable if riposte else false, a.status_component.has_status(DeflectComponent.get_riposte_status_id())],
		[true, 80.0, true, false])
	a.attack.cancel()
	await _wait_until(func() -> bool: return knight.attack.can_swing(), 60)
	_check("the rebuff over: the Knight swings again", knight.attack.can_swing(), true)

	_raise_stance(a)
	var c1 := _knight_hit(a)
	var c2 := _knight_hit(a)
	_check("one hit per stance: the first deflected, the window shut, the second hits", [c1.deflected, ad.is_window_open(), c2.deflected, c2.blocked], [true, false, false, false])
	a.attack.cancel()
	await _wait_until(func() -> bool: return not a.abilities.casting, 10)
	_raise_stance(a)
	var cleave := HitPipeline.resolve(HitPipeline.from_ability(knight, CLEAVE, a))
	var lunge := HitPipeline.resolve(HitPipeline.from_ability(knight, LUNGE, a))
	var judgement := HitPipeline.resolve(HitPipeline.from_ability(knight, JUDGEMENT, a))
	_check("what it deflects: never Cleave (an area), Lunge (a dash through a line) or Judgement (an ultimate): each lands through the stance, which stays up",
		[cleave.deflected, lunge.deflected, judgement.deflected, cleave.blocked, lunge.blocked, judgement.blocked, ad.is_window_open()],
		[false, false, false, false, false, false, true])
	a.status_component.apply_status(STATUS_STUN, knight, 0.3)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("a stun cuts it short: the window closes", [a.is_stunned(), ad.is_window_open(), a.get_pose() == &"riposte_stance"], [true, false, false])
	await _wait_until(func() -> bool: return not a.is_stunned() and not a.abilities.casting and not a.abilities.is_recovering(), 120)
	a.health.heal(100000.0)
	_deflects.clear()
	_raise_stance(a)
	await _swing(Vector2.RIGHT, a, true)
	_check("the dash-strike (a swing) is deflected too", [_deflects.size(), _deflects[0][1] == a if not _deflects.is_empty() else false], [1, true])
	a.attack.cancel()
	await _wait_until(func() -> bool: return not a.abilities.casting, 10)
	await _wait_until(func() -> bool: return knight.attack.can_swing(), 60)

	_raise_stance(a)
	await _seconds(0.55)
	var rec_left := a.abilities.get_recovery_left()
	_check("nothing comes: the window closes after 0.5 s and it recovers (%.2f s left of 0.6): no moving, attacking or casting, the player's opening" % rec_left,
		[ad.is_window_open(), a.abilities.is_recovering(), rec_left > 0.5 and rec_left <= 0.6, a.movement.can_move(), a.abilities.can_cast(&"e")],
		[false, true, true, false, false])
	await _wait_until(func() -> bool: return not a.abilities.is_recovering(), 60)
	ap.take_poise_damage(30.0, knight)
	var before := ap.get_poise()
	_raise_stance(a)
	_knight_hit(a)
	_check("its own deflect drains 15 from its meter (%.0f -> %.0f; the deflected hit carries none)" % [before, before - 15.0],
		[before >= 30.0, ap.get_poise()], [true, before - 15.0])
	a.attack.cancel()
	a.queue_free()
	knight.status_component.remove_status(STATUS_REBUFFED.id)
	await _frames(2)


func _test_ar3b_break() -> void:
	_section("AR3b: the Knight's test deflect against the test Assassin (AR3's done line): a deflect pair of its attacks plus the riposte breaks its meter (100: 75 + 44), 1.8 s")
	DeflectComponent.deflect_test_enabled = true
	PoiseComponent.poise_test_enabled = false
	await _fresh()
	var a := _spawn(ASSASSIN_SCENE, ARENA + Vector2(0, 220))
	await get_tree().physics_frame
	var p := a.poise_component
	await _deflect_pair(a)   # its basic attack: deflectable (its scene's)
	_check("the pair fills 75 of its 100, not broken; the Knight's riposte ready", [p.get_poise(), p.is_broken(), deflect.has_riposte()], [75.0, false, true])
	_place(knight, ARENA)
	_place(a, ARENA + Vector2(55, 0))
	await _swing(Vector2.RIGHT, a)
	_check("...his riposte (40 + the swing's 4) breaks it, for 1.8 s", [p.is_broken(), absf(p.get_break_left() - 1.8) < 0.05], [true, true])
	a.queue_free()
	DeflectComponent.deflect_test_enabled = false
	await _frames(2)


## The test Assassin raises its stance now (its Q, ready; no cast time).
func _raise_stance(a: Enemy) -> void:
	a.abilities.reset_cooldown(&"q")
	a.abilities.try_cast(&"q", a.global_position, null)


## A deflectable melee hit from the Knight on `target`, as his swing makes one.
func _knight_hit(target: Unit) -> HitContext:
	var ctx := knight.attack.make_attack_context(target)
	ctx.deflectable = true
	return HitPipeline.resolve(ctx)


## The last hit `source` got through on `target` (Events.unit_hit), or null.
func _hit_by(source: Unit, target: Unit) -> HitContext:
	for i in range(_hits.size() - 1, -1, -1):
		if _hits[i].source == source and _hits[i].target == target:
			return _hits[i]
	return null


# --- Feel, readouts and the sandbox (slice C) ----------------------------------------

func _test_feel() -> void:
	_section("Feel (presentation only; it never decides state)")
	DeflectComponent.deflect_test_enabled = true
	PoiseComponent.poise_test_enabled = true
	await _fresh()
	var probe := PoiseComponent.new()
	deflect.deflect_hitstop = _feel_defaults[0]
	deflect.deflect_shake = _feel_defaults[1]
	_check("a deflect's feel: 0.08 s hitstop, a small shake (1.5), a white flash on the attacker", [deflect.deflect_hitstop, deflect.deflect_shake, deflect.deflect_flash_color], [0.08, 1.5, Color(1, 1, 1, 1)])
	_check("the presentation slots start empty", [deflect.deflect_vfx == null, deflect.riposte_vfx == null, deflect.deflect_sound == null, deflect.riposte_sound == null, probe.poise_break_vfx == null, probe.poise_break_sound == null], [true, true, true, true, true, true])
	probe.free()
	var cam := _spy_camera()
	var brute := _spawn(BRUTE_SCENE, ARENA + Vector2(0, 200))
	await _hitstop_over()
	_shakes.clear()
	knight.dash.try_dash(Vector2.RIGHT)
	_brute_hit(brute)
	_check("a deflect plays the hitstop and the shake", [GameFeel.is_hitstop_active(), absf(GameFeel.get_hitstop_left() - 0.08) < 0.03, _shakes], [true, true, [1.5]])
	await _hitstop_over()
	await _wait_until(func() -> bool: return not knight.dash.is_dashing(), 60)
	_shakes.clear()
	deflect.deflect_window = 0.05
	knight.dash.try_dash(Vector2.LEFT)
	await _frames(5)
	var blocked := _brute_hit(brute)
	_check("a hit the i-frames only block plays none", [blocked.deflected, GameFeel.is_hitstop_active(), _shakes], [false, false, []])
	deflect.deflect_window = 0.15
	deflect.deflect_hitstop = 0.0
	deflect.deflect_shake = 0.0
	await _fresh()
	deflect.deflect_hitstop = 0.0
	await _deflect_pair(brute)
	_check("the riposte's cue: a ring (aura) under the Knight while it's ready", _auras_on(knight), 1)
	_place(knight, ARENA)
	_place(brute, ARENA + Vector2(50, 0))
	await _swing(Vector2.RIGHT, brute)
	await _frames(2)
	_check("...gone once it's used", _auras_on(knight), 0)
	cam.queue_free()
	brute.queue_free()
	await get_tree().physics_frame


func _test_sandbox() -> void:
	_section("SandboxDeflect: its keys, its panel, everything put back")
	DeflectComponent.deflect_test_enabled = false
	PoiseComponent.poise_test_enabled = false
	AutoAttackComponent.prototype_unempowered_auto_mult = 1.0
	await _fresh()
	var sd := SandboxDeflect.new()
	add_child(sd)
	await _frames(2)
	_check("in a test scene it leaves the flags and the lever alone", [DeflectComponent.deflect_test_enabled, PoiseComponent.poise_test_enabled, AutoAttackComponent.prototype_unempowered_auto_mult], [false, false, 1.0])
	_check("its starting values: both flags on, readouts on, deflects bank (since AR4 it never sets the TEMP lever)", [sd.deflect_test_enabled, sd.poise_test_enabled, sd.is_readouts_on(), sd.streak_persists, "prototype_unempowered_auto_mult" in sd], [true, true, true, true, false])
	_check("...a test scene's Knight keeps his own", deflect.streak_persists, false)
	sd.set_streak_persists(true)
	_check("its switch sets the Knight's, live", deflect.streak_persists, true)
	sd.set_streak_persists(false)
	_press(KEY_V, false)
	_check("V: the deflect flag on", DeflectComponent.deflect_test_enabled, true)
	_press(KEY_V, true)
	_check("Shift+V: the poise flag on", PoiseComponent.poise_test_enabled, true)
	_press(KEY_V, false)
	_check("V again: deflect off", DeflectComponent.deflect_test_enabled, false)
	DeflectComponent.deflect_test_enabled = true
	_press(KEY_M, false)
	_check("M: the panel", sd.is_panel_open(), true)
	var keys := sd.get_row_keys()
	var expected: Array[StringName] = [&"deflect_window", &"chain_window", &"refund_lifetime", &"deflect_test_charge_recharge",
		&"riposte_ad_ratio", &"riposte_window", &"riposte_snap_range", &"deflect_poise_damage_first", &"deflect_poise_damage_second",
		&"riposte_poise_damage", &"deflect_hitstop", &"deflect_shake", &"poise_max", &"poise_break_time", &"decay_delay",
		&"decay_rate", &"low_health_decay_scale", &"break_damage_bonus", &"break_immunity", &"swing_poise", &"cleave_poise",
		&"judgement_poise", &"unempowered_attack_damage"]
	_check("every tunable has a row (23: AR3a's meter reads PoiseRules and the elite rank's break time; AR4's stat in place of the TEMP lever)", keys == expected, true)
	_check("its rows read the live values", [sd.get_value(&"deflect_window"), sd.get_value(&"poise_max"), sd.get_value(&"poise_break_time"), sd.get_value(&"decay_rate"), sd.get_value(&"swing_poise"), sd.get_value(&"unempowered_attack_damage")], [0.15, 100.0, 1.8, 15.0, 4.0, 0.5])
	var elite := _spawn(ELITE_SCENE, ARENA + Vector2(0, 220))
	sd.set_value(&"deflect_window", 0.2)
	sd.set_value(&"decay_rate", 30.0)
	sd.set_value(&"poise_max", 150.0)
	sd.set_value(&"poise_break_time", 2.0)
	sd.set_value(&"swing_poise", 6.0)
	sd.set_value(&"cleave_poise", 25.0)
	sd.set_value(&"unempowered_attack_damage", 0.7)
	_check("a change applies at once: the Knight's window, a live elite's meter (its rules, its size, its break time)", [deflect.deflect_window, elite.poise_component.get_rules().decay_rate, elite.poise_component.poise_max, elite.poise_component.poise_break_time], [0.2, 30.0, 150.0, 2.0])
	var later := _spawn(DUELIST_SCENE, ARENA + Vector2(0, 280))
	_check("...and to an enemy spawned after (its data, its rank, the shared rules)", [later.poise_component.get_rules().decay_rate, later.poise_component.poise_max, later.poise_component.poise_break_time, _rd(DUELIST_DATA, &"poise_max")], [30.0, 150.0, 2.0, 150.0])
	_check("...the poise damage on the shared data", [_rd(COMBO_KNIGHT.swings[2], &"poise_damage"), _rd(COMBO_KNIGHT.dash_strike, &"poise_damage"), _rd(CLEAVE, &"poise_damage"), _rd(CLEAVE_WAVE, &"poise_damage")], [6.0, 6.0, 25.0, 25.0])
	_check("...the Knight's stat as one modifier of its own (the lever left at 1.0)", [knight.stats_component.get_stat(&"unempowered_attack_damage"),
		knight.stats_component.get_modifiers_from(SandboxDeflect.STAT_SOURCE).size(), sd.get_value(&"unempowered_attack_damage"), AutoAttackComponent.prototype_unempowered_auto_mult], [0.7, 1, 0.7, 1.0])
	sd.set_value(&"unempowered_attack_damage", 0.5)
	_check("...back to his own 0.5: no modifier left", [knight.stats_component.get_stat(&"unempowered_attack_damage"), knight.stats_component.get_modifiers_from(SandboxDeflect.STAT_SOURCE).size()], [0.5, 0])
	sd.set_value(&"unempowered_attack_damage", 0.8)
	sd.queue_free()
	await _frames(2)
	_check("gone: the shared data is put back", [_rd(ELITE_DATA, &"poise_max"), _rd(DUELIST_DATA, &"poise_max"), _rd(COMBO_KNIGHT.swings[0], &"poise_damage"), _rd(COMBO_KNIGHT.dash_strike, &"poise_damage"), _rd(CLEAVE, &"poise_damage"), _rd(CLEAVE_WAVE, &"poise_damage")], [100.0, 100.0, 4.0, 4.0, 20.0, 20.0])
	_check("...the Knight's stat too (0.5, its modifier gone)", [knight.stats_component.get_stat(&"unempowered_attack_damage"), knight.stats_component.get_modifiers_from(SandboxDeflect.STAT_SOURCE).size()], [0.5, 0])
	_check("...the rules and the elite rank's break time too", [_rd(PoiseComponent.DEFAULT_RULES, &"decay_rate"), _rd(Brains.table.get_rank_rules(EnemyData.Rank.ELITE), &"poise_break_time")], [15.0, 1.8])
	AutoAttackComponent.prototype_unempowered_auto_mult = 1.0
	DeflectComponent.deflect_test_enabled = false
	PoiseComponent.poise_test_enabled = false
	for n: Node in [elite, later]:
		n.queue_free()
	await _frames(2)


## A Camera3D recording GameFeel.shake() amounts (combat_test's spy).
func _spy_camera() -> Camera3D:
	var script := GDScript.new()
	script.source_code = "extends Camera3D\nvar on_shake: Callable\nfunc shake(amount: float) -> void:\n\ton_shake.call(amount)\n"
	script.reload()
	var cam := Camera3D.new()
	cam.set_script(script)
	cam.set("on_shake", func(amount: float) -> void: _shakes.append(amount))
	add_child(cam)
	cam.make_current()
	return cam


func _hitstop_over() -> void:
	while GameFeel.is_hitstop_active():
		await get_tree().create_timer(0.02, true, false, true).timeout


## The aura rings (VFX.aura()) on `unit` now.
func _auras_on(unit: Unit) -> int:
	var n := 0
	for child in unit.get_children():
		if child.get_script() == AURA_SCRIPT and not child.is_queued_for_deletion():
			n += 1
	return n


## `object`'s `property` read now: a read through a const chain
## (COMBO_KNIGHT.swings[0].poise_damage) is folded when the script compiles,
## so it would never see an edit made since.
func _rd(object: Object, property: StringName) -> Variant:
	return object.get(property)


## A raw key press, as the sandbox's keys read them (_unhandled_input).
func _press(keycode: Key, shift: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.keycode = keycode
	ev.shift_pressed = shift
	ev.pressed = true
	get_viewport().push_input(ev)


# --- Helpers ----------------------------------------------------------------------

## The last hit that got through to `unit` (Events.unit_hit), or null.
func _last_hit_on(unit: Unit) -> HitContext:
	for i in range(_hits.size() - 1, -1, -1):
		if _hits[i].target == unit:
			return _hits[i]
	return null


## Back to a clean state: dash over and recharged, no refund, no streak, no
## riposte, no i-frames, full health, the DeflectComponent's exports as the
## scene has them (a fast 0.1 s test recharge), the event logs cleared.
func _fresh() -> void:
	var flag := DeflectComponent.deflect_test_enabled
	for p: String in _defaults:
		deflect.set(p, _defaults[p])
	deflect.deflect_test_charge_recharge = 0.1
	# No deflect feel: a real-time hitstop would blur the frame counts (the feel
	# checks turn it back on).
	deflect.deflect_hitstop = 0.0
	deflect.deflect_shake = 0.0
	await _wait_until(func() -> bool: return not knight.dash.is_dashing(), 60)
	if knight.dash.has_refund():
		DeflectComponent.deflect_test_enabled = false
		await get_tree().physics_frame
		knight.dash.try_dash(Vector2.DOWN)
		await _wait_until(func() -> bool: return not knight.dash.is_dashing(), 60)
	DeflectComponent.deflect_test_enabled = false
	await _frames(2)
	knight.status_component.remove_status(DeflectComponent.get_riposte_status_id())
	knight.attack.cancel_swing()
	DeflectComponent.deflect_test_enabled = flag
	await _wait_until(func() -> bool: return knight.dash.get_charges() >= knight.dash.get_max_charges() and not knight.is_invulnerable(), 90)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging() and not knight.attack.is_in_pause(), 60)
	knight.health.heal(10000.0)
	_place(knight, ARENA)
	_deflects.clear()
	_streaks.clear()
	_ripostes.clear()
	_hits.clear()


## Two deflects of `attacker`'s attack in a row (two dashes): the riposte.
func _deflect_pair(attacker: Enemy) -> void:
	deflect.refund_lifetime = 3.0
	knight.dash.try_dash(Vector2.RIGHT)
	_brute_hit(attacker)
	await _wait_until(func() -> bool: return not knight.dash.is_dashing(), 60)
	knight.dash.try_dash(Vector2.LEFT)
	_brute_hit(attacker)
	await _wait_until(func() -> bool: return not knight.dash.is_dashing(), 60)


## The brute's League-style attack on the Knight, built as its windup lands it.
func _brute_hit(brute: Enemy) -> HitContext:
	return HitPipeline.resolve(brute.attack.make_attack_context(knight))


## The elite slam on the Knight as its script builds it (its push), plus a
## slow. Since ARCHETYPES AR2 the slam is perilous (a deflect of it counts as
## two: _test_perilous_deflect()); the single-deflect checks take it as a
## plain deflectable hit (`perilous` false clears the mark).
func _slam_hit(elite: Enemy, perilous: bool = false) -> HitContext:
	var ctx := HitPipeline.from_ability(elite, SLAM, knight)
	if not perilous:
		ctx.perilous = false
		ctx.tags.erase(&"perilous")
	ctx.knockback_px = 20.0
	ctx.knockback_from = elite.global_position
	ctx.statuses.append(STATUS_SLOW)
	return HitPipeline.resolve(ctx)


## One swing toward `direction` (the first of the combo, or the dash-strike):
## the damage `target` took, whether the hit was empowered or a dash-strike,
## how far the Knight moved.
func _swing(direction: Vector2, target: Unit, dash_strike: bool = false) -> Dictionary:
	knight.attack.cancel_swing()   # the combo starts over: swing 1
	await _wait_until(func() -> bool: return knight.attack.can_swing(), 60)
	var before := target.health.current
	var from := knight.global_position
	var hit_count := _hits.size()
	knight.attack.try_swing(direction, dash_strike)
	await _wait_until(func() -> bool: return knight.attack.is_in_recovery() or not knight.attack.is_swinging(), 30)
	await get_tree().physics_frame
	var empowered := false
	var tagged_dash := false
	for i in range(hit_count, _hits.size()):
		if _hits[i].target == target:
			empowered = _hits[i].has_tag(&"empowered")
			tagged_dash = _hits[i].has_tag(&"dash_strike")
	var result := {"damage": before - target.health.current, "empowered": empowered,
		"dash_strike": tagged_dash, "moved": knight.global_position.distance_to(from)}
	knight.attack.cancel_swing()
	target.health.heal(100000.0)
	return result


func _spawn(scene: PackedScene, pos: Vector2) -> Enemy:
	var e := scene.instantiate() as Enemy
	e.passive = true
	entities.add_child(e)
	_place(e, pos)
	return e


## One flat walkable rectangle around the arena, as a room's baked navigation
## would be (moves path on it).
func _add_navigation() -> void:
	var poly := NavigationPolygon.new()
	var r := Rect2(ARENA - Vector2(2500, 2500), Vector2(5000, 5000))
	poly.vertices = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	poly.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	var region := NavigationRegion2D.new()
	region.navigation_polygon = poly
	add_child(region)


func _place(node: Node2D, pos: Vector2) -> void:
	node.global_position = pos
	node.reset_physics_interpolation()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Waits about `seconds` of game time (physics frames at 60 Hz).
func _seconds(seconds: float) -> void:
	await _frames(roundi(seconds * Engine.physics_ticks_per_second))


func _wait_until(condition: Callable, max_frames: int) -> void:
	for i in max_frames:
		if condition.call():
			return
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
		print("  FAIL  %s (%s)" % [label, detail])
