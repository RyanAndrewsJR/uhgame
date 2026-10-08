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
## the TEMP weak-auto lever; a deflect on sources it wasn't written for.
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
const FLAT := StatModifier.Type.FLAT
const BASELINE_SOURCE := &"test_baseline"
const ARENA := Vector2(-3000, 0)
## The Knight's swing reach (175 u = 56 px) and the brute's radius (70 u).
const KNIGHT_REACH_PX := 56.0
const BRUTE_RADIUS_PX := 22.4

@onready var entities: Node2D = $Entities

var knight: Player
var deflect: DeflectComponent

var _passed: int = 0
var _failed: int = 0
var _deflects: Array = []   # [attacker, defender, ctx]
var _streaks: Array = []   # the Knight's streak events, in order
var _ripostes: Array = []   # [unit]
var _hits: Array[HitContext] = []
var _defaults: Dictionary = {}   # the DeflectComponent's exports as the scene has them
var _shipped: Array = []   # the flags and the lever as the scripts ship them


func _ready() -> void:
	print("\n=== Deflect test (PROTOTYPE: dash-deflect, riposte, poise) ===")
	_shipped = [DeflectComponent.deflect_test_enabled, AutoAttackComponent.prototype_unempowered_auto_mult]
	Progress.get_progress(KNIGHT)   # the save guards latch off first (a test scene)
	Loot.get_inventory(KNIGHT)
	HitPipeline.crit_rng.seed = 20261007
	Events.hit_deflected.connect(func(a: Unit, d: Unit, ctx: HitContext) -> void: _deflects.append([a, d, ctx]))
	Events.deflect_streak_changed.connect(func(u: Unit, s: int) -> void:
		if u == knight:
			_streaks.append(s))
	Events.riposte_ready.connect(func(u: Unit) -> void: _ripostes.append(u))
	Events.unit_hit.connect(func(ctx: HitContext) -> void: _hits.append(ctx))
	_add_navigation()
	await _frames(3)
	knight = PLAYER_SCENE.instantiate()
	entities.add_child(knight)
	await get_tree().physics_frame
	_place(knight, ARENA)
	deflect = knight.deflect_component
	for p: String in ["deflect_window", "chain_window", "refund_lifetime", "deflect_test_charge_recharge",
			"riposte_ad_ratio", "riposte_window", "riposte_snap_range"]:
		_defaults[p] = deflect.get(p)
	_baseline()

	await _test_flags_off()
	await _test_data()
	await _test_window()
	await _test_streak_and_refund()
	await _test_riposte()
	await _test_riposte_snap()
	await _test_weak_autos()
	await _test_other_sources()

	DeflectComponent.deflect_test_enabled = false
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
	_check("flags are off as shipped (deflect off, the lever 1.0)", _shipped, [false, 1.0])
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
	var snapped := await _swing(Vector2.UP, brute)
	_check("the riposte swing snaps to it (aim and step) and lands", [snapped.damage, snapped.moved > 60.0], [256.0, true])
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


# --- The weak-auto lever (TEMP) -----------------------------------------------------

func _test_weak_autos() -> void:
	_section("The weak-auto lever (TEMP)")
	DeflectComponent.deflect_test_enabled = true
	await _fresh()
	var brute := _spawn(BRUTE_SCENE, ARENA + Vector2(50, 0))
	var decay := knight.resource_pool.decay_per_second
	knight.resource_pool.decay_per_second = 0.0   # Fury's decay would blur the +8 per hit
	AutoAttackComponent.prototype_unempowered_auto_mult = 1.0
	var fury := knight.resource_pool.current
	var full := await _swing(Vector2.RIGHT, brute)
	_check("1.0 changes nothing: a swing deals 64, +8 Fury", [full.damage, knight.resource_pool.current - fury], [64.0, 8.0])
	AutoAttackComponent.prototype_unempowered_auto_mult = 0.5
	fury = knight.resource_pool.current
	var weak := await _swing(Vector2.RIGHT, brute)
	_check("0.5: an unempowered swing deals 32, Fury unchanged (+8)", [weak.damage, knight.resource_pool.current - fury], [32.0, 8.0])
	var weak_dash := await _swing(Vector2.RIGHT, brute, true)
	_check("...a dash-strike 48 (1.5 x 64 x 0.5)", weak_dash.damage, 48.0)
	AutoAttackComponent.prototype_unempowered_auto_mult = 0.1
	var floor_hit := await _swing(Vector2.RIGHT, brute)
	_check("...clamped to 0.2 at least (12.8)", floor_hit.damage, 12.8)
	knight.resource_pool.decay_per_second = decay
	AutoAttackComponent.prototype_unempowered_auto_mult = 0.5
	await _fresh()
	await _deflect_pair(brute)
	_place(knight, ARENA)
	_place(brute, ARENA + Vector2(50, 0))
	var riposte := await _swing(Vector2.RIGHT, brute)
	_check("the riposte is untouched (256)", riposte.damage, 256.0)
	knight.resource_pool.restore(1000.0)
	knight.abilities.reset_cooldown(&"w")
	await get_tree().physics_frame
	var iron_bonus := knight.abilities.get_ability(&"w").get_damage(knight)
	_check("Iron Resolve casts", knight.cast_ability(&"w", knight.global_position + Vector2.RIGHT * 40.0), true)
	await _wait_until(func() -> bool: return not knight.abilities.casting, 60)
	var iron := await _swing(Vector2.RIGHT, brute)
	_check("an Iron Resolve swing is untouched (64 + its bonus)", [iron.damage, iron.empowered], [64.0 + iron_bonus, true])

	var dummy := _spawn(SLIME_SCENE, ARENA + Vector2(0, 260))
	dummy.team = Unit.Team.PLAYER
	var hitter := _spawn(BRUTE_SCENE, ARENA + Vector2(30, 260))
	hitter.attack.attack(dummy)
	var dummy_health := dummy.health.current
	await _wait_until(func() -> bool: return dummy.health.current < dummy_health, 120)
	_check("an enemy's League-style attack is untouched (26)", dummy_health - dummy.health.current, 26.0)
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
	_check("an ally Knight (not the tracked player) is untouched (64 at 0.5)", before - ally_target.health.current, 64.0)
	AutoAttackComponent.prototype_unempowered_auto_mult = 1.0
	for n: Node in [brute, dummy, hitter, ally, ally_target]:
		n.queue_free()
	await _frames(2)


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
	from_knight = HitPipeline.resolve(from_knight)
	_check("its window deflects a deflectable hit from the Knight's side", [from_knight.deflected, guard.health.current], [true, guard.health.max_health])
	var cleave := HitPipeline.resolve(HitPipeline.from_ability(knight, knight.abilities.get_ability(&"q"), guard))
	_check("...but not a non-deflectable one (no i-frames: it lands)", [cleave.deflected, cleave.blocked], [false, false])
	for n: Node in [slime, caster, guard]:
		n.queue_free()
	await _frames(2)


# --- Helpers ----------------------------------------------------------------------

## Back to a clean state: dash over and recharged, no refund, no streak, no
## riposte, no i-frames, full health, the DeflectComponent's exports as the
## scene has them (a fast 0.1 s test recharge), the event logs cleared.
func _fresh() -> void:
	var flag := DeflectComponent.deflect_test_enabled
	for p: String in _defaults:
		deflect.set(p, _defaults[p])
	deflect.deflect_test_charge_recharge = 0.1
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


## The elite slam on the Knight as slam.gd builds it (its push), plus a slow.
func _slam_hit(elite: Enemy) -> HitContext:
	var ctx := HitPipeline.from_ability(elite, SLAM, knight)
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
