extends Node2D
## ENEMIES_AI.md step AI1 test: open res://scenes/tests/enemies_test.tscn and
## press F6. The tooling and the brain skeleton:
## - data: the AI table and its four ranks (tenacity, ability counts, the
##   rank adjusts), the brute preset's twelve sliders, every EnemyData (its
##   ability count under its rank's, at most three overrides: a warning), the
##   default pose set, the slimes on data with today's numbers;
## - EnemyBehavior.resolve(): overrides, adjusts, limits;
## - respect: each ability's derived value (role tag, +1 for crowd control),
##   the authored override, the Knight's kit (10.5), kit ready and share from
##   the shared snapshot, the ally's half weight within 10 m;
## - the RESPECT condition kind and the situation argument;
## - patience: its fill, its floor, pressure;
## - decide(): an ultimate ready at 5 m holds, spent it commits, a poke, the
##   no-flip-flop bonus, intent weights, the same seed giving the same
##   decisions (thousands of seeded runs);
## - the default get_ai_plan() and Ability.ai_uses;
## - the think schedule (staggered, urgent wakes, one snapshot per tick);
## - enemies on data (brains by rank, tenacity, difficulty tier slots, the
##   brain switch, the naive cast loop gated);
## - the test brute against the Knight: it holds in its band with his kit up,
##   crouches for the tell and commits once Lunge and Judgement are down, and
##   its hold always ends within 12 s;
## - ScriptedController; SandboxBrains (the overlay's text, the scenarios,
##   the panel's live change, no saving in a test scene).
## Step AI2, groups:
## - the table's group numbers and the threat stat; the fodder ring's places
##   (Pack.get_ring_spots()); decide() with tokens and a taunt;
## - attack tokens: costs by rank, a pool per champion by difficulty tier,
##   the queue (patience, then the nearest), the rest, the timeout, a stunned
##   or dead holder, a dead target;
## - noticing through WorldQuery (any party member); the shout (the pack 0.4 s
##   later, through walls; other packs within 6 m in sight; no chain);
## - ALLIES' target pick: nearest, sticky with the margin, threat, stealth,
##   taunt, downed, an untargetable target chased;
## - the leash (12 m from home, or 6 s with nothing in reach), the walk home
##   (faster, ignoring sight, a hit only from inside the leash) and recovery;
## - a stunned holder; five test brutes never more than two on the Knight,
##   rotating; fodder in a ring around him with no tokens; the pack scenarios.
## Brains.rng is seeded. Prints PASS/FAIL per check, then a total. Run
## headless and it quits with the number of failures as the exit code.

const KNIGHT: ChampionData = preload("res://data/champions/knight.tres")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const SLIME_SCENE: PackedScene = preload("res://scenes/enemies/slime.tscn")
const ELITE_SCENE: PackedScene = preload("res://scenes/enemies/slime_elite.tscn")
const BRUTE_SCENE: PackedScene = preload("res://scenes/enemies/test_brute.tscn")
const BRUTE_BEHAVIOR: EnemyBehavior = preload("res://data/enemy_behaviors/enemy_behavior_brute.tres")
const BRUTE_DATA: EnemyData = preload("res://data/enemies/enemy_test_brute.tres")
const SLIME_DATA: EnemyData = preload("res://data/enemies/enemy_slime.tres")
const ELITE_DATA: EnemyData = preload("res://data/enemies/enemy_slime_elite.tres")
const POSE_SET: PoseSet = preload("res://data/pose_sets/pose_set_default.tres")
const CLEAVE: Ability = preload("res://data/abilities/knight_q_cleave.tres")
const IRON_RESOLVE: Ability = preload("res://data/abilities/knight_w_iron_resolve.tres")
const LUNGE: Ability = preload("res://data/abilities/knight_e_lunge.tres")
const JUDGEMENT: Ability = preload("res://data/abilities/knight_r_judgement.tres")
const SMASH: Ability = preload("res://data/abilities/test_brute_q_smash.tres")
const SLAM: Ability = preload("res://data/abilities/slime_elite_q_slam.tres")
const VECTOR_WALL: Ability = preload("res://data/abilities/test_w_vector_wall.tres")
const STATUS_SLOW: StatusEffect = preload("res://data/statuses/status_slow.tres")
const ENEMY_DATA_DIR := "res://data/enemies/"
## Where the fights happen, away from the origin.
const ARENA := Vector2(3000, 0)

@onready var entities: Node2D = $Entities

var knight: Player
var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	print("\n=== Enemies test (ENEMIES_AI AI1–AI2) ===")
	Progress.get_progress(KNIGHT)   # the save guards latch off first (a test scene)
	Loot.get_inventory(KNIGHT)
	Brains.rng.seed = 20261004
	_add_navigation()   # move orders path on it (without one they'd head for the origin)
	await _frames(3)
	knight = PLAYER_SCENE.instantiate()
	entities.add_child(knight)
	await get_tree().physics_frame
	_place(knight, ARENA)

	_test_table()
	_test_brute_preset()
	_test_enemy_data_files()
	_test_pose_set()
	_test_resolve()
	_test_respect_values()
	await _test_snapshot()
	_test_condition_respect()
	_test_patience()
	_test_decide()
	_test_decide_seeded()
	await _test_cast_plan()
	await _test_enemies_on_data()
	await _test_schedule()
	await _test_naive_gate()
	await _test_brute_holds_then_commits()
	await _test_hold_ends_within_12s()
	await _test_scripted_controller()
	await _test_sandbox_brains()

	# AI2: groups.
	_test_ai2_data()
	_test_ring_spots()
	_test_decide_tokens()
	await _test_tokens()
	await _test_sight()
	await _test_pack_alert()
	await _test_target_pick()
	await _test_leash()
	await _test_unreachable()
	await _test_stunned_holder()
	await _test_five_brutes()
	await _test_fodder_ring()
	await _test_sandbox_packs()

	Audio.stop_all()
	await _frames(120)   # stop_all() leaves the UI bus: let the ultimate-ready pings (reset_cooldown()) finish
	print("=== %d passed, %d failed ===\n" % [_passed, _failed])
	if DisplayServer.get_name() == "headless":
		get_tree().quit(_failed)


# --- Data ---------------------------------------------------------------------------

func _test_table() -> void:
	_section("The AI table and its four ranks")
	var t := Brains.table
	_check("the table loads with four ranks", [t != null, t.ranks.size()], [true, 4])
	var rows: Array = []
	for rank in [EnemyData.Rank.FODDER, EnemyData.Rank.REGULAR, EnemyData.Rank.ELITE, EnemyData.Rank.BOSS]:
		var r := t.get_rank_rules(rank)
		rows.append([r.has_brain, r.can_dodge, r.token_cost, r.tenacity, r.max_abilities])
	_check("fodder / regular / elite / boss: brain, dodge, token cost, tenacity (I8), max abilities",
		rows, [[false, false, 0, 0.0, 0], [true, false, 1, 0.0, 2], [true, true, 2, 0.2, 3], [true, true, 0, 0.4, -1]])
	var regular := t.get_rank_rules(EnemyData.Rank.REGULAR).brain_adjust
	var boss := t.get_rank_rules(EnemyData.Rank.BOSS).brain_adjust
	_check("the regular's adjust: reaction × 1.3, jitter × 1.5, punish greed × 0.5",
		[regular.reaction_time, regular.jitter, regular.punish_greed, regular.aggression], [1.3, 1.5, 0.5, 1.0])
	_check("the boss's: reaction × 0.85, jitter × 0.7", [boss.reaction_time, boss.jitter, boss.punish_greed], [0.85, 0.7, 1.0])
	_check("the elite's: none (× 1)", t.get_rank_rules(EnemyData.Rank.ELITE).brain_adjust, null)
	_check("think rate 10, min intent 0.4 s, tell 0.3 s, reaction floor 0.2 s",
		[t.think_rate, t.min_intent_time, t.tell_time, t.reaction_floor], [10.0, 0.4, 0.3, 0.2])
	_check("respect by role: ultimate 4, core 2, mobility 2, defensive 1.5, generator 1, companion 0; cc +1",
		[t.respect_by_role[&"ultimate"], t.respect_by_role[&"core"], t.respect_by_role[&"mobility"], t.respect_by_role[&"defensive"],
			t.respect_by_role[&"generator"], t.respect_by_role[&"companion"], t.respect_cc_bonus], [4.0, 2.0, 2.0, 1.5, 1.0, 0.0, 1.0])
	_check("the ally counts half within 10 m (I2)", [t.ally_respect_weight, t.ally_respect_range_px, Units.px_to_m(t.ally_respect_range_px)], [0.5, 320.0, 10.0])
	_check("pressure: idle 1.5 s +0.5, below 40% +0.5", [t.idle_time, t.idle_pressure, t.low_health, t.low_pressure], [1.5, 0.5, 0.4, 0.5])
	_check("the think period at 60 Hz: 6 ticks", Brains.get_think_period(), 6)


func _test_brute_preset() -> void:
	_section("The brute preset: the twelve sliders (I1)")
	var b := BRUTE_BEHAVIOR
	_check("role BRUTE, fights to the death, uses tokens", [b.role, b.low_health, b.uses_tokens], [EnemyBehavior.Role.BRUTE, EnemyBehavior.LowHealth.FIGHT_ON, true])
	var values: Array = []
	for s in EnemyBehavior.SLIDERS:
		values.append(b.get_slider(s))
	_check("aggression .5, respect 1, patience 3, band 350–500, reaction .35, dodge .4 / 6, greed .6, finish .3, pressure 12, breather 5, jitter .15",
		values, [0.5, 1.0, 3.0, 350.0, 500.0, 0.35, 0.4, 6.0, 0.6, 0.3, 12.0, 5.0, 0.15])
	_check("13 fields, 12 sliders (the band is one, with two ends)", [EnemyBehavior.SLIDERS.size(), EnemyBehavior.LIMITS.size()], [13, 13])
	var in_limits := true
	for s in EnemyBehavior.SLIDERS:
		var lim: Array = EnemyBehavior.LIMITS[s]
		in_limits = in_limits and b.get_slider(s) >= lim[0] and b.get_slider(s) <= lim[1]
	_check("every value inside its limits", in_limits, true)
	_check("a missing intent weight counts 1", b.get_intent_weight(&"commit"), 1.0)


func _test_enemy_data_files() -> void:
	_section("Every EnemyData: abilities under its rank's count, at most 3 overrides")
	var dir := DirAccess.open(ENEMY_DATA_DIR)
	var files: Array[String] = []
	for f in dir.get_files():
		if f.ends_with(".tres"):
			files.append(f)
	_check("the AI1 enemies exist", files.has("enemy_slime.tres") and files.has("enemy_slime_elite.tres") and files.has("enemy_test_brute.tres"), true)
	var problems: Array[String] = []
	for f in files:
		var data: EnemyData = load(ENEMY_DATA_DIR + f)
		var rules := Brains.table.get_rank_rules(data.rank)
		var count := data.get_abilities_at(5).size()
		if rules.max_abilities >= 0 and count > rules.max_abilities:
			problems.append("%s: %d abilities, rank allows %d" % [f, count, rules.max_abilities])
		if rules.has_brain != (data.behavior != null):
			problems.append("%s: a brain rank needs a behavior, fodder none" % f)
		if data.stats == null or data.id == &"":
			problems.append("%s: no stats or id" % f)
		if data.overrides.size() > 3:
			print("  WARN  %s has %d overrides (at most 3: kind, not magnitude)" % [f, data.overrides.size()])
	_check("no problems in %d files" % files.size(), problems, [])
	_check("the slime: fodder, no behavior, slime.tres, its green",
		[SLIME_DATA.rank, SLIME_DATA.behavior, SLIME_DATA.stats.resource_path, SLIME_DATA.model_color],
		[EnemyData.Rank.FODDER, null, "res://data/units/slime.tres", Color(0.35, 0.85, 0.4, 1)])
	_check("the elite slime: an elite brute with the slam",
		[ELITE_DATA.rank, ELITE_DATA.behavior == BRUTE_BEHAVIOR, ELITE_DATA.get_abilities_at(1).get(&"q") == SLAM, ELITE_DATA.stats.resource_path],
		[EnemyData.Rank.ELITE, true, true, "res://data/units/slime_elite.tres"])
	_check("the test brute: a regular brute with the smash",
		[BRUTE_DATA.rank, BRUTE_DATA.behavior == BRUTE_BEHAVIOR, BRUTE_DATA.get_abilities_at(1).get(&"q") == SMASH, BRUTE_DATA.get_source_id()],
		[EnemyData.Rank.REGULAR, true, true, &"enemy_test_brute"])
	_check("the smash: POINT, 0.7 s telegraph, 250 range, 80 damage (12% of 650: the elite band's lower part)",
		[SMASH.targeting, SMASH.cast_time, SMASH.cast_range, SMASH.base_damage, SMASH.get_role()],
		[Ability.Targeting.POINT, 0.7, 250.0, 80.0, &"core"])


func _test_pose_set() -> void:
	_section("The default pose set (I7)")
	var names := ["hold", "crouch", "draw_back", "stalk", "recoil", "guard", "step_back", "cornered", "sidestep", "pressure", "breather", "finish", "alert", "return"]
	var missing: Array = []
	for n in names:
		if POSE_SET.get_look(StringName(n)) == null:
			missing.append(n)
	_check("every pose of the minimum set has a look", missing, [])
	var hold := POSE_SET.get_look(&"hold")
	var crouch := POSE_SET.get_look(&"crouch")
	var draw := POSE_SET.get_look(&"draw_back")
	_check("hold: upright, leaning back 5°", [hold.lean_deg, hold.squash, hold.rim_color.a], [-5.0, 1.0, 0.0])
	_check("crouch: squash 0.8, lean in 15°", [crouch.lean_deg, crouch.squash], [15.0, 0.8])
	_check("draw_back: lean back 15°, stretch 1.1, an orange rim pulse", [draw.lean_deg, draw.squash, draw.rim_color.a > 0.0, draw.pulse_hz > 0.0], [-15.0, 1.1, true, true])
	_check("no pose: no look", POSE_SET.get_look(&""), null)


func _test_resolve() -> void:
	_section("EnemyBehavior.resolve(): overrides, adjusts, limits")
	var t := Brains.table
	var regular := t.get_rank_rules(EnemyData.Rank.REGULAR).brain_adjust
	var adjusts: Array[BrainAdjust] = [regular]
	var r := BRUTE_BEHAVIOR.resolve({}, adjusts)
	_check("a regular brute: reaction 0.455, jitter 0.225, greed 0.3, the rest as the preset",
		[snappedf(r.reaction_time, 0.0001), snappedf(r.jitter, 0.0001), snappedf(r.punish_greed, 0.0001), r.patience_time, r.range_band_min], [0.455, 0.225, 0.3, 3.0, 350.0])
	var o := BRUTE_BEHAVIOR.resolve({&"patience_time": 5.0, &"range_band_max": 600.0}, adjusts)
	_check("an override replaces the preset's value", [o.patience_time, o.range_band_max, o.range_band_min], [5.0, 600.0, 350.0])
	var fast := BrainAdjust.new()
	fast.reaction_time = 0.1
	fast.range_band = 2.0
	fast.jitter = 10.0
	var both: Array[BrainAdjust] = [regular, fast]
	var c := BRUTE_BEHAVIOR.resolve({}, both)
	_check("adjusts multiply, then the limits clamp (reaction ≥ 0.2, jitter ≤ 0.5)", [c.reaction_time, c.jitter], [0.2, 0.5])
	_check("the band's multiplier moves both ends", [c.range_band_min, c.range_band_max], [700.0, 1000.0])
	var flipped := BRUTE_BEHAVIOR.resolve({&"range_band_min": 900.0, &"range_band_max": 400.0}, [] as Array[BrainAdjust])
	_check("the band's max stays at least its min", [flipped.range_band_min, flipped.range_band_max], [900.0, 900.0])
	_check("the preset itself is untouched", [BRUTE_BEHAVIOR.reaction_time, BRUTE_BEHAVIOR.patience_time], [0.35, 3.0])
	_check("the kind is shared, not copied", r.intent_weights == BRUTE_BEHAVIOR.intent_weights, true)


func _test_respect_values() -> void:
	_section("Respect values (I2): the role tag, +1 for crowd control, the authored override")
	var t := Brains.table
	_check("the Knight: Cleave 2, Iron Resolve 1.5, Lunge 2, Judgement 4 + 1 (its stun)",
		[t.get_respect_value(CLEAVE), t.get_respect_value(IRON_RESOLVE), t.get_respect_value(LUNGE), t.get_respect_value(JUDGEMENT)], [2.0, 1.5, 2.0, 5.0])
	_check("the whole kit is 10.5", t.get_respect_value(CLEAVE) + t.get_respect_value(IRON_RESOLVE) + t.get_respect_value(LUNGE) + t.get_respect_value(JUDGEMENT), 10.5)
	_check("Judgement's stun is read from its stun_duration; Iron Resolve's slow lives in its script (no +1)",
		[EnemyAITable.applies_cc(JUDGEMENT), EnemyAITable.applies_cc(IRON_RESOLVE), EnemyAITable.applies_cc(CLEAVE)], [true, false, false])
	var authored: Ability = CLEAVE.duplicate()
	authored.respect_value = 0.5
	_check("an authored respect_value wins (−1 = derived)", [t.get_respect_value(authored), CLEAVE.respect_value], [0.5, -1.0])
	var generator := Ability.new()
	generator.tags = [&"generator"]
	var companion := Ability.new()
	companion.tags = [&"companion"]
	_check("a generator 1, a companion's command 0", [t.get_respect_value(generator), t.get_respect_value(companion)], [1.0, 0.0])
	var slows := Ability.new()
	slows.tags = [&"core"]
	var bonus := ConditionalBonus.new()
	bonus.target_statuses = [STATUS_SLOW]
	slows.conditional_bonuses = [bonus]
	_check("a slow among its data's statuses: +1", t.get_respect_value(slows), 3.0)
	_check("no ability: 0", t.get_respect_value(null), 0.0)


func _test_snapshot() -> void:
	_section("The shared snapshot: kit ready, share, the ally's half")
	await _reset_knight()
	var snap := Brains.get_snapshot()
	var m := snap.get_member(knight)
	_check("the Knight is in it; companions never are (not Units)", [not m.is_empty(), snap.members.size()], [true, 1])
	knight.resource_pool.try_spend(knight.resource_pool.current)
	await _frames(1)
	m = Brains.get_snapshot().get_member(knight)
	_check("no Fury: Cleave can't be paid (the HUD's tint), so it isn't ready: 8.5 / 10.5",
		[snappedf(m.kit_ready, 0.0001), m.slots[&"q"].ready], [snappedf(8.5 / 10.5, 0.0001), false])
	knight.resource_pool.restore(1000.0)
	await _frames(1)
	m = Brains.get_snapshot().get_member(knight)
	_check("everything ready: kit 1, share 1 at full health", [m.kit_ready, m.share], [1.0, 1.0])
	knight.abilities.start_cooldown(&"e")
	knight.abilities.start_cooldown(&"r")
	knight.health.take_damage(knight.health.max_health * 0.5)
	await _frames(1)
	m = Brains.get_snapshot().get_member(knight)
	_check("Lunge and Judgement down: kit 3.5 / 10.5; at half health its share is 0.25 (the doc's example)",
		[snappedf(m.kit_ready, 0.0001), snappedf(m.share, 0.0001)], [snappedf(3.5 / 10.5, 0.0001), 0.25])
	_check("PartySnapshot.get_share(): kit × (0.5 + 0.5 × health)", [PartySnapshot.get_share(1.0, 0.0), PartySnapshot.get_share(0.6, 1.0)], [0.5, 0.6])
	var others: Array[float] = [0.6]
	_check("combine_respect(): the target's share + half the ally's, clamped", [PartySnapshot.combine_respect(0.4, others, 0.5),
		PartySnapshot.combine_respect(0.9, [1.0] as Array[float], 0.5), PartySnapshot.combine_respect(0.3, [] as Array[float], 0.5)], [0.7, 1.0, 0.3])
	var builds := Brains.get_snapshot_builds()
	var a := Brains.get_snapshot()
	var b := Brains.get_snapshot()
	_check("one read per tick: asked twice in one tick, built once", [a == b, Brains.get_snapshot_builds() - builds <= 1], [true, true])

	# The ally's half within 10 m, through a brain's situation: a friendly in
	# the group `party` with a kit (a passive slime elite: its slam, core 2).
	await _reset_knight()
	var brute := _spawn(BRUTE_SCENE, knight.global_position + Vector2(170, 0), false)   # aggroed: it has a target
	var friend := ELITE_SCENE.instantiate() as Enemy
	friend.data = null
	friend.passive = true
	entities.add_child(friend)
	_place(friend, knight.global_position + Vector2(170, 100))
	friend.add_to_group(&"party")
	await _frames(2)
	knight.abilities.start_cooldown(&"e")
	knight.abilities.start_cooldown(&"r")
	await _frames(1)
	var near := brute.get_brain().build_situation()
	_place(friend, knight.global_position + Vector2(170 + 400, 0))
	await _frames(1)
	var far := brute.get_brain().build_situation()
	var target_share := snappedf(3.5 / 10.5, 0.0001)
	_check("the ally (share 1) within 10 m adds half; beyond, nothing",
		[snappedf(near.respect, 0.0001), snappedf(far.respect, 0.0001)], [snappedf(3.5 / 10.5 + 0.5, 0.0001), target_share])
	friend.remove_from_group(&"party")
	brute.passive = true
	brute.queue_free()
	friend.queue_free()
	await _frames(2)


func _test_condition_respect() -> void:
	_section("The RESPECT condition kind and the situation argument")
	var s := SituationContext.new()
	s.respect = 0.6
	var at_least := Condition.new()
	at_least.kind = Condition.Kind.RESPECT
	at_least.value = 0.5
	var less := Condition.new()
	less.kind = Condition.Kind.RESPECT
	less.comparison = Condition.Comparison.LESS_THAN
	less.value = 0.5
	var negated := Condition.new()
	negated.kind = Condition.Kind.RESPECT
	negated.value = 0.9
	negated.negate = true
	_check("respect 0.6: ≥ 0.5 true, < 0.5 false, not ≥ 0.9 true",
		[at_least.is_met(knight, null, null, s), less.is_met(knight, null, null, s), negated.is_met(knight, null, null, s)], [true, false, true])
	_check("without a situation it's false, even negated (a cast condition, a reaction rule)",
		[at_least.is_met(knight, null), negated.is_met(knight, null)], [false, false])
	_check("a situation kind, not a target kind", [at_least.is_situation_kind(), at_least.is_target_kind()], [true, false])
	var health := Condition.new()
	health.kind = Condition.Kind.SELF_HEALTH_PERCENT
	health.value = 0.1
	_check("the old kinds ignore the situation", [health.is_met(knight, null, null, s), health.is_met(knight, null)], [true, true])
	var list: Array[Condition] = [health, at_least]
	_check("all_met() and first_failed() pass it on", [Condition.all_met(list, knight, null, null, s), Condition.all_met(list, knight, null),
		Condition.first_failed(list, knight, null) == at_least, Condition.first_failed(list, knight, null, null, s)], [true, false, true, null])
	var use := AIUse.make(&"poke", [less] as Array[Condition])
	s.respect = 0.3
	_check("an AIUse's rules see the situation", [use.passes(knight, null, s), AIUse.make(&"poke").passes(knight, null, null)], [true, true])


func _situation(respect: float, patience: float, intent: StringName = &"hold", intent_age: float = 1.0) -> SituationContext:
	var t := Brains.table
	var s := SituationContext.new()
	s.has_target = true
	s.respect = respect
	s.effective_respect = respect
	s.patience = patience
	s.intent = intent
	s.intent_age = intent_age
	s.target_edge_distance_px = Units.to_px(500.0)   # 5 m
	s.attack_reach_px = Units.to_px(125.0)
	s.min_intent_time = t.min_intent_time
	s.intent_hold_bonus = t.intent_hold_bonus
	s.intent_scores = t.intent_scores
	s.caster_poke_score = t.caster_poke_score
	return s


func _plan(slot: StringName, value: float = 1.0) -> CastPlan:
	var p := CastPlan.new()
	p.slot = slot
	p.value = value
	return p


func _regular_brute() -> EnemyBehavior:
	var adjusts: Array[BrainAdjust] = [Brains.table.get_rank_rules(EnemyData.Rank.REGULAR).brain_adjust]
	return BRUTE_BEHAVIOR.resolve({}, adjusts)


func _test_patience() -> void:
	_section("Patience: its fill, its floor, pressure")
	var t := Brains.table
	var b := BRUTE_BEHAVIOR
	var s := _situation(1.0, 0.0)
	_check("everything up (respect 1): a quarter speed, 1/12 a second: a brute comes in 12 s", EnemyBrain.get_patience_rate(s, b, t), 1.0 / 12.0)
	s.effective_respect = 0.0
	_check("nothing up: 1/3 a second (3 s)", EnemyBrain.get_patience_rate(s, b, t), 1.0 / 3.0)
	s.effective_respect = 1.0
	s.target_idle_time = 2.0
	_check("the target idle 1.5 s: × 1.5", EnemyBrain.get_patience_rate(s, b, t), 1.5 / 12.0)
	s.target_health_ratio = 0.3
	_check("and below 40%: × 2", EnemyBrain.get_patience_rate(s, b, t), 2.0 / 12.0)
	var eager: EnemyBehavior = b.duplicate()
	eager.aggression = 1.0
	s.target_idle_time = 0.0
	s.target_health_ratio = 1.0
	_check("aggression 1: × 1.5", EnemyBrain.get_patience_rate(s, eager, t), 1.5 / 12.0)
	var p := 0.0
	var steps := 0
	s = _situation(1.0, 0.0)
	while p < 1.0 - EnemyBrain.PATIENCE_EPSILON and steps < 1000:
		p = minf(p + EnemyBrain.get_patience_rate(s, b, t) * 0.1, 1.0)
		steps += 1
	_check("filled in 0.1 s steps with everything up: full after 12 s (its floor)", steps, 120)


func _test_decide() -> void:
	_section("decide(): hold, commit, poke")
	var b := _regular_brute()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var holds := 0
	var commits := 0
	for i in 2000:
		var d := EnemyBrain.decide(_situation(1.0, 0.2), b, rng)
		holds += int(d.intent == &"hold")
	for i in 2000:
		var d := EnemyBrain.decide(_situation(0.25, 1.0), b, rng)
		commits += int(d.intent == &"commit")
	_check("an ultimate ready at 5 m (respect 1, patience 0.2): hold, 2,000 times out of 2,000", holds, 2000)
	_check("spent (patience full): commit, 2,000 of 2,000", commits, 2000)
	var going := _situation(0.9, 0.0, &"commit")
	going.committing = true
	_check("a commit under way goes on (patience was emptied at its start)", EnemyBrain.decide(going, b, rng).intent, &"commit")
	var young := _situation(1.0, 1.0, &"hold", 0.1)
	var d2 := EnemyBrain.decide(young, b, rng)
	_check("the current intent scores +0.15 until 0.4 s (no flip-flopping)", d2.scores[&"hold"] >= 0.3 * (1.0 - b.jitter) + 0.15 - 0.0001, true)
	var poke := _situation(1.0, 0.0)
	poke.add_use(&"q", &"poke", _plan(&"q"))
	var d3 := EnemyBrain.decide(poke, b, rng)
	_check("a poke use: poke (0.5) over hold (0.3), with its plan", [d3.intent, d3.plan != null and d3.plan.slot == &"q"], [&"poke", true])
	var caster: EnemyBehavior = b.duplicate()
	caster.role = EnemyBehavior.Role.CASTER
	caster.jitter = 0.0
	_check("a caster's poke scores 0.6", EnemyBrain.decide(poke, caster, rng).scores[&"poke"], 0.6)
	var hits := _situation(0.0, 1.0)
	hits.add_use(&"q", &"damage", _plan(&"q", 0.5))
	hits.add_use(&"e", &"gap_close", _plan(&"e", 0.9))
	var d4 := EnemyBrain.decide(hits, b, rng)
	_check("a commit out of reach takes the best of its damage and gap-closer uses", [d4.intent, d4.plan.slot], [&"commit", &"e"])
	hits.target_edge_distance_px = 10.0
	var d5 := EnemyBrain.decide(hits, b, rng)
	_check("in reach: damage uses only", [d5.intent, d5.plan.slot], [&"commit", &"q"])
	_check("a new commit shows its tell pose (crouch); hold shows hold", [d5.pose, EnemyBrain.decide(_situation(1.0, 0.0), b, rng).pose], [&"crouch", &"hold"])
	var shy: EnemyBehavior = b.duplicate()
	shy.intent_weights = {&"commit": 0.0}
	_check("an intent weight of 0 never commits", EnemyBrain.decide(_situation(0.0, 1.0), shy, rng).intent, &"hold")
	var none := SituationContext.new()
	_check("no target: no intent", EnemyBrain.decide(none, b, rng).intent, &"")
	var unreachable := _situation(0.0, 1.0)
	unreachable.target_reachable = false
	_check("an unreachable target: no commit", EnemyBrain.decide(unreachable, b, rng).intent, &"hold")
	_check("the scores the overlay shows: the top three, best first", EnemyBrain.decide(poke, b, rng).get_top_scores(3).size(), 2)


func _test_decide_seeded() -> void:
	_section("The same seed gives the same decisions")
	var b := _regular_brute()
	var runs: Array = []
	for run in 2:
		var rng := RandomNumberGenerator.new()
		rng.seed = 424242
		var out: Array = []
		for i in 3000:
			var s := _situation(fmod(i * 0.137, 1.0), fmod(i * 0.071, 1.1), [&"hold", &"commit", &"poke"][i % 3], fmod(i * 0.05, 0.8))
			if i % 4 == 0:
				s.add_use(&"q", &"poke", _plan(&"q"))
			var d := EnemyBrain.decide(s, b, rng)
			out.append([d.intent, snappedf(float(d.scores.get(d.intent, 0.0)), 0.000001)])
		runs.append(out)
	_check("3,000 decisions, two runs, one seed: identical", runs[0] == runs[1], true)
	var other := RandomNumberGenerator.new()
	other.seed = 99
	var differs := false
	for i in 50:
		var d := EnemyBrain.decide(_situation(0.5, 0.5), b, other)
		differs = differs or snappedf(float(d.scores[&"hold"]), 0.000001) != runs[0][0][1]
	_check("another seed jitters differently", differs, true)


func _test_cast_plan() -> void:
	_section("The default get_ai_plan() and Ability.ai_uses")
	await _reset_knight()
	var brute := _spawn(BRUTE_SCENE, knight.global_position + Vector2(60, 0), true)
	await _frames(1)
	var s := SituationContext.new()
	s.target_unit = knight
	s.respect = 0.5
	var plan := SMASH.get_ai_plan(brute, s)
	_check("the smash (no ai_uses: one damage use): at the Knight where he stands, value 1",
		[plan != null, plan.point == knight.global_position if plan else false, plan.target == knight if plan else false, plan.intents if plan else [], plan.value if plan else 0.0, plan.is_vector() if plan else true],
		[true, true, true, [&"damage"], 1.0, false])
	_check("get_ai_uses(): the default damage use, no rules", [SMASH.get_ai_uses().size(), SMASH.get_ai_uses()[0].intent, SMASH.get_ai_uses()[0].conditions.size()], [1, &"damage", 0])
	_place(brute, knight.global_position + Vector2(Units.to_px(SMASH.cast_range) + 2.0, 0))
	_check("beyond its cast range (center to center): no plan", SMASH.get_ai_plan(brute, s), null)
	_place(brute, knight.global_position + Vector2(60, 0))
	var wall := _wall_at(knight.global_position + Vector2(30, 0), Vector2(6, 120))
	await _frames(2)
	_check("a wall between: no plan", SMASH.get_ai_plan(brute, s), null)
	wall.queue_free()
	await _frames(2)
	var vector := VECTOR_WALL.get_ai_plan(brute, s)
	var v := VECTOR_WALL.get_ai_vector(brute, knight)
	_check("a VECTOR ability wraps get_ai_vector()", [vector != null, vector.is_vector() if vector else false, vector.vector_start == v.start if vector else false], [true, true, true])
	var rule := Condition.new()
	rule.kind = Condition.Kind.RESPECT
	rule.comparison = Condition.Comparison.LESS_THAN
	rule.value = 0.3
	var picky: Ability = SMASH.duplicate()
	picky.ai_uses = [AIUse.make(&"punish", [rule] as Array[Condition], 2.0)]
	_check("its only use fails (respect 0.5, rule < 0.3): no plan", picky.get_ai_plan(brute, s), null)
	s.respect = 0.2
	var p2 := picky.get_ai_plan(brute, s)
	_check("it passes: the plan carries that use's intent", p2.intents if p2 else [], [&"punish"])
	var self_cast := IRON_RESOLVE.get_ai_plan(brute, s)
	_check("a SELF ability aims at its caster", self_cast.point == brute.global_position if self_cast else false, true)
	_check("no situation: no plan", SMASH.get_ai_plan(brute, null), null)
	brute.queue_free()
	await _frames(2)


func _test_enemies_on_data() -> void:
	_section("Enemies on data: brains by rank, tenacity, slots by difficulty tier, the brain switch")
	await _reset_knight()
	var slime := _spawn(SLIME_SCENE, knight.global_position + Vector2(0, 300), true)
	var elite := _spawn(ELITE_SCENE, knight.global_position + Vector2(0, -300), true)
	var brute := _spawn(BRUTE_SCENE, knight.global_position + Vector2(300, 300), true)
	var bare := ELITE_SCENE.instantiate() as Enemy
	bare.data = null
	bare.passive = true
	entities.add_child(bare)
	_place(bare, knight.global_position + Vector2(-300, 300))
	await _frames(1)
	_check("the slime (fodder): its data, no brain, today's numbers and look",
		[slime.data == SLIME_DATA, slime.get_brain(), slime.health.max_health, slime.model_color, slime.get_rank_rules().has_brain],
		[true, null, 280.0, Color(0.35, 0.85, 0.4, 1), false])
	_check("the elite slime: a brain, its slam on Q, 900 health, tenacity 0.2 under enemy_rank",
		[elite.get_brain() != null, elite.abilities.q == SLAM, elite.health.max_health, elite.stats_component.get_stat(&"tenacity")],
		[true, true, 900.0, 0.2])
	_check("the test brute: a brain, the smash, no tenacity, a regular's reaction (0.455)",
		[brute.get_brain() != null, brute.abilities.q == SMASH, brute.stats_component.get_stat(&"tenacity"), snappedf(brute.get_brain().behavior.reaction_time, 0.0001)],
		[true, true, 0.0, 0.455])
	_check("an enemy with no data: no brain, exactly as before", [bare.get_brain(), bare.abilities.q == SLAM, bare.health.max_health], [null, true, 900.0])
	_check("a training dummy's brain stays inactive", [elite.is_brain_active(), elite.get_pose(), elite.get_face_point()], [false, &"", Vector2.INF])
	_check("the brain is a UnitController child, not human", [elite.get_brain() is UnitController, elite.get_brain().get_unit() == elite, elite.get_brain().is_human()], [true, true, false])
	elite.set_brain_enabled(false)
	await _frames(1)
	_check("switched off: no brain (the old routine)", elite.get_brain(), null)
	elite.set_brain_enabled(true)
	_check("switched on again", elite.get_brain() != null, true)
	var off := BRUTE_SCENE.instantiate() as Enemy
	off.brain_enabled = false
	off.passive = true
	entities.add_child(off)
	_check("brain_enabled off from the start: none", off.get_brain(), null)

	# Slots by difficulty tier.
	var tiered: EnemyData = BRUTE_DATA.duplicate()
	var slot := EnemyAbilitySlot.new()
	slot.slot = &"w"
	slot.ability = VECTOR_WALL
	slot.min_difficulty_tier = 3
	tiered.abilities = [BRUTE_DATA.abilities[0], slot]
	var low := BRUTE_SCENE.instantiate() as Enemy
	low.data = tiered
	low.passive = true
	entities.add_child(low)
	Brains.difficulty_tier = 3
	var high := BRUTE_SCENE.instantiate() as Enemy
	high.data = tiered
	high.passive = true
	entities.add_child(high)
	Brains.difficulty_tier = 1
	_check("a slot with a minimum tier: empty below it, filled at it", [low.abilities.w, high.abilities.w == VECTOR_WALL, low.abilities.q == SMASH], [null, true, true])
	for e in [slime, elite, brute, bare, off, low, high]:
		e.queue_free()
	await _frames(2)


func _test_schedule() -> void:
	_section("The think schedule: staggered, urgent wakes, one snapshot per tick")
	await _reset_knight()
	var spawned: Array[Enemy] = []
	var ring := knight.global_position + Vector2(0, 1000)   # a ring of 12 around a spot the Knight walks to later
	for i in 12:
		spawned.append(_spawn(BRUTE_SCENE, ring + Vector2.from_angle(TAU * i / 12.0) * 170.0, true))
	await _frames(1)
	var counts: Array[int] = [0, 0, 0, 0, 0, 0]
	for e in spawned:
		counts[e.get_brain().think_slot] += 1
	_check("12 brains over 6 tick slots: 2 each", counts, [2, 2, 2, 2, 2, 2] as Array[int])
	var before: Array[int] = []
	for e in spawned:
		before.append(e.get_brain().think_calls)
	await _frames(6)
	var each_once := true
	for i in spawned.size():
		each_once = each_once and spawned[i].get_brain().think_calls - before[i] == 1
	_check("in 6 ticks each brain thinks exactly once", each_once, true)
	var b := spawned[0].get_brain()
	await _frames(1)
	var calls := b.think_calls
	Brains.wake(b)
	await _frames(1)
	_check("wake(): it thinks on the next tick, whatever its slot", b.think_calls - calls >= 1, true)
	knight.resource_pool.restore(1000.0)
	_place(knight, ring)
	for e in spawned:
		e.passive = false   # aggroed brains build situations (and ask for snapshots)
	await _frames(10)
	var active := 0
	for e in spawned:
		active += int(e.is_brain_active())
	_check("all 12 noticed the Knight in their middle", active, 12)
	var builds := Brains.get_snapshot_builds()
	Brains.reset_think_stats()
	await _frames(30)
	var stats := Brains.get_think_stats()
	_check("aggroed: at most one snapshot per tick for 12 brains", Brains.get_snapshot_builds() - builds <= 30, true)
	_check("about 10 thinks a second each: 12 brains × 30 ticks ÷ 6 = 60 (± wakes)", stats.count >= 60 and stats.count <= 72, true)
	print("  INFO  think cost (headless, 12 brutes): mean %.1f µs, p99 %d µs" % [stats.mean_usec, stats.p99_usec])
	for e in spawned:
		e.queue_free()
	await _frames(2)


func _test_naive_gate() -> void:
	_section("The naive cast loop: gated, and kept for an enemy with no brain")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	knight.resource_pool.restore(1000.0)
	var gated := ELITE_SCENE.instantiate() as Enemy
	gated.data = null
	gated.naive_casting = false
	entities.add_child(gated)
	_place(gated, knight.global_position + Vector2(70, 0))
	var slams := [0]
	gated.abilities.cast_started.connect(func(_s: StringName, _a: Ability, _c: CastContext) -> void: slams[0] += 1)
	await _frames(90)
	_check("naive_casting off: it chases and attacks but never casts", slams[0], 0)
	gated.queue_free()
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	knight.resource_pool.restore(1000.0)
	var brained := _spawn(ELITE_SCENE, knight.global_position + Vector2(70, 0), false)
	var brained_slams := [0]
	brained.abilities.cast_started.connect(func(_s: StringName, _a: Ability, _c: CastContext) -> void: brained_slams[0] += 1)
	await _frames(90)
	_check("with its brain and the Knight's kit up: no slam (the loop never runs; it holds)", [brained_slams[0], brained.get_brain().get_intent()], [0, &"hold"])
	brained.set_brain_enabled(false)
	await _wait_until(func() -> bool: return brained.abilities.casting, 90)
	_check("its brain switched off: it slams as before (the naive loop)", brained.abilities.casting, true)
	brained.passive = true
	brained.attack.cancel()
	brained.queue_free()
	await _frames(60)


## The step's "Done means": the brute holds and circles at 350–500 u while the
## Knight's kit is up, crouches for its tell and dives once Lunge and
## Judgement are down.
func _test_brute_holds_then_commits() -> void:
	_section("The test brute: holds with the kit up, the tell, commits when it's down")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	knight.resource_pool.restore(1000.0)
	var hp := knight.health.current
	var brute := _spawn(BRUTE_SCENE, knight.global_position + Vector2(180, 0), false)
	var brain := brute.get_brain()
	var start := brute.global_position
	var band_ok := true
	var held := true
	var min_edge := INF
	for i in 180:
		await get_tree().physics_frame
		knight.resource_pool.restore(1000.0)
		if i > 30:
			var edge := Units.to_units(brute.edge_distance_to(knight))
			min_edge = minf(min_edge, edge)
			band_ok = band_ok and edge >= 330.0 and edge <= 520.0
			held = held and brain.get_intent() == &"hold"
	_check("aggroed with everything up: it holds for 3 s", [brute.ai, held], [Enemy.AI.AGGRO, true])
	_check("in its band (350–500 u, a little slack) the whole time", band_ok, true)
	_check("it circles (it moved) and faces the Knight", [brute.global_position.distance_to(start) > 20.0, brute.get_face_point() == knight.global_position], [true, true])
	_check("its pose is hold; no hit landed", [brute.get_pose(), knight.health.current], [&"hold", hp])
	var patience_before := brain.get_patience()
	_check("its patience filled slowly (respect 1: about a quarter speed)", patience_before > 0.15 and patience_before < 0.6, true)

	knight.abilities.start_cooldown(&"e")
	knight.abilities.start_cooldown(&"r")
	var crouch_at := -1
	var move_at := -1
	var crouch_pos := Vector2.ZERO
	var still := true
	for i in 480:
		await get_tree().physics_frame
		if brute.get_pose() == &"crouch" and crouch_at < 0:
			crouch_at = i
			crouch_pos = brute.global_position
		if crouch_at >= 0 and move_at < 0:
			if brute.get_pose() == &"crouch":
				still = still and brute.global_position.distance_to(crouch_pos) < 1.0
			else:
				move_at = i
		if move_at >= 0 and knight.health.current < hp:
			break
	_check("Lunge and Judgement down: it crouches (its tell) within 4 s", crouch_at >= 0 and crouch_at < 240, true)
	_check("the tell lasts 0.3 s (18 ticks ± 1), standing still", [absi((move_at - crouch_at) - 18) <= 1, still], [true, true])
	_check("then it commits and hits the Knight", [brain.get_intent() == &"commit" or not brain.is_committing(), knight.health.current < hp], [true, true])
	await _wait_until(func() -> bool: return not brain.is_committing(), 300)
	_check("its commit ends; patience empties", [brain.is_committing(), brain.get_patience() < 0.2], [false, true])
	brute.passive = true
	brute.attack.cancel()
	brute.queue_free()
	await _frames(60)


## "Its hold always ends within 12 s (4 × its 3 s patience_time)": everything
## up and no pressure (idle pressure off for this check).
func _test_hold_ends_within_12s() -> void:
	_section("A hold always ends within 12 s")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	var idle_time := Brains.table.idle_time
	Brains.table.idle_time = 1000.0
	knight.resource_pool.restore(1000.0)
	var brute := _spawn(BRUTE_SCENE, knight.global_position + Vector2(180, 0), false)
	var brain := brute.get_brain()
	var aggro_at := -1
	var commit_at := -1
	var min_edge := INF
	var max_edge := 0.0
	var hp := knight.health.current
	for i in 900:
		await get_tree().physics_frame
		knight.resource_pool.restore(1000.0)
		if aggro_at < 0 and brain.get_intent() != &"":
			aggro_at = i
		if brain.is_committing():
			commit_at = i
			break
		if aggro_at >= 0 and i - aggro_at > 30:
			var edge := Units.to_units(brute.edge_distance_to(knight))
			min_edge = minf(min_edge, edge)
			max_edge = maxf(max_edge, edge)
	var seconds := float(commit_at - aggro_at) / Engine.physics_ticks_per_second
	_check("it commits after about 12 s, never later (got %.2f s)" % seconds, commit_at > 0 and seconds <= 12.2 and seconds >= 11.5, true)
	_check("circling all that time, it stays in its band (no spiral in; got %d–%d u)" % [roundi(min_edge), roundi(max_edge)],
		[min_edge >= 330.0, max_edge <= 520.0, knight.health.current], [true, true, hp])
	Brains.table.idle_time = idle_time
	brute.passive = true
	brute.attack.cancel()
	brute.queue_free()
	await _frames(30)


func _test_scripted_controller() -> void:
	_section("ScriptedController: walk, wait, cast")
	await _reset_knight()
	knight.resource_pool.restore(1000.0)
	var c := ScriptedController.new()
	knight.add_child(c)
	var to := knight.global_position + Vector2(64, 0)
	var steps: Array[Dictionary] = [
		{"op": &"walk_to", "point": to},
		{"op": &"wait", "time": 0.2},
		{"op": &"cast", "slot": &"w", "point": to},
	]
	c.play(steps)
	_check("a UnitController, not human", [c is UnitController, c.is_human(), c.get_unit() == knight], [true, false, true])
	await _wait_until(func() -> bool: return c.get_step_index() >= 1, 90)
	_check("walk_to: it arrives", knight.global_position.distance_to(to) < 2.0, true)
	await _wait_until(func() -> bool: return c.is_done(), 60)
	_check("then waits and casts W (Iron Resolve on cooldown)", [c.is_done(), knight.abilities.is_ready(&"w")], [true, false])
	c.queue_free()
	await _frames(2)


func _test_sandbox_brains() -> void:
	_section("SandboxBrains: the overlay, the scenarios, the panel (no saving here)")
	await _reset_knight()
	var sb := SandboxBrains.new()
	add_child(sb)
	await _frames(2)
	var brute := sb.run_scenario(&"all_ready")
	await _frames(2)
	_check("all_ready: the test brute 5 m away, the Knight's kit and Fury full",
		[brute != null and brute.data == BRUTE_DATA, absf(brute.global_position.distance_to(knight.global_position) - 160.0) < 2.0,
			knight.abilities.is_ready(&"r"), knight.resource_pool.current > knight.resource_pool.max_resource - 5.0], [true, true, true, true])
	await _wait_until(func() -> bool: return brute.get_brain().get_intent() != &"", 30)
	var text := sb.get_overlay_text(brute)
	_check("the overlay's text: intent and pose, scores, respect, patience", [text.begins_with("hold · hold"), text.contains("respect"), text.contains("patience")], [true, true, true])
	sb.set_overlay(true)
	await _frames(2)
	_check("I: on and off", [sb.is_overlay_on(), Brains.debug_draw], [true, true])
	sb.set_overlay(false)
	brute = sb.run_scenario(&"none_ready")
	await _frames(1)
	var none_ready := true
	for slot in AbilityComponent.SLOTS:
		none_ready = none_ready and not knight.abilities.is_ready(slot)
	_check("none_ready: no slot ready, no Fury, the last scenario's brute gone", [none_ready, knight.resource_pool.current, sb.get_brained_enemies().size()], [true, 0.0, 1])
	sb.run_scenario(&"low_health")
	await _frames(1)
	_check("low_health: the Knight at 25%", snappedf(knight.health.current / knight.health.max_health, 0.01), 0.25)
	sb.run_scenario(&"ally")
	await _frames(1)
	var friends := get_tree().get_nodes_in_group(&"party")
	_check("ally: a friendly stand-in on the player's team in the group party", [friends.size(), (friends[0] as Unit).team if friends.size() > 0 else -1,
		(friends[0] as Node).is_in_group(&"enemies") if friends.size() > 0 else true], [1, Unit.Team.PLAYER, false])
	sb.run_scenario(&"whiff")
	await _frames(1)
	_check("whiff: Judgement spent, the rest ready", [knight.abilities.is_ready(&"r"), knight.abilities.is_ready(&"q")], [false, true])
	var casts: Array = []
	var on_cast := func(u: Unit, a: Ability, _c: CastContext) -> void: casts.append([u, a])
	Events.ability_cast.connect(on_cast)
	brute = sb.run_scenario(&"incoming_shot")
	await _frames(2)
	Events.ability_cast.disconnect(on_cast)
	_check("incoming_shot: the Knight fires the test bolt at it", casts.size() == 1 and casts[0][0] == knight and casts[0][1] == sb.test_bolt, true)
	_check("H cycles the eight (AI2 added the two packs)", [sb.next_scenario(), sb.next_scenario(), sb.next_scenario()], [&"pack", &"fodder", &"all_ready"])

	# The panel: a live change for every enemy sharing the data; no saving here.
	brute = sb.run_scenario(&"all_ready")
	var second := _spawn(BRUTE_SCENE, knight.global_position + Vector2(0, 240), true)
	await _frames(2)
	var original := BRUTE_DATA.overrides.duplicate()
	sb.set_panel(true)
	sb.pick(brute)
	sb.set_slider(&"patience_time", 6.0)
	_check("a slider change applies at once to it and to every enemy sharing its data",
		[brute.get_brain().behavior.patience_time, second.get_brain().behavior.patience_time, BRUTE_BEHAVIOR.patience_time], [6.0, 6.0, 3.0])
	_check("the panel shows its base value", sb.get_slider_base(brute, &"patience_time"), 6.0)
	_check("no saving in a test scene: nothing written", [sb.can_save(), sb.save_edits(false), sb.save_edits(true)], [false, ERR_UNAVAILABLE, ERR_UNAVAILABLE])
	sb.cycle_pick(1)
	_check(", and . cycle the picked enemy", sb.get_picked() == second, true)
	BRUTE_DATA.set(&"overrides", original)
	brute.get_brain().resolve_behavior()
	second.get_brain().resolve_behavior()
	_check("(the test puts the data back)", brute.get_brain().behavior.patience_time, 3.0)
	sb.set_panel(false)
	sb.clear_scenario()
	second.queue_free()
	sb.queue_free()
	await _frames(2)


# --- AI2: groups ----------------------------------------------------------------------------

func _test_ai2_data() -> void:
	_section("AI2 data: tokens, the fodder ring, the pick, the alert, the leash; the threat stat")
	var t := Brains.table
	_check("tokens per champion by tier 1–5: 2, 2, 2, 3, 3 (I3), clamped past 5",
		[t.tokens_per_target, t.get_tokens_per_target(1), t.get_tokens_per_target(4), t.get_tokens_per_target(9)],
		[[2, 2, 2, 3, 3] as Array[int], 2, 3, 3])
	_check("a holder keeps its token at most 4 s, then rests 1.5 s (I3)", [t.token_hold_time, t.token_rest_time], [4.0, 1.5])
	_check("fodder: 5 pack thinks a second, 19 px (0.6 m) apart in the ring (I6), at half its reach",
		[t.pack_think_rate, t.fodder_ring_spacing_px, t.fodder_ring_reach_share], [5.0, 19.0, 0.5])
	_check("the pick: 25% and 1.5 m closer, held 0.5 s (ALLIES)", [t.switch_ratio, t.switch_px, Units.px_to_m(t.switch_px), t.switch_hold_time], [0.25, 48.0, 1.5, 0.5])
	_check("the shout: 6 m, 0.4 s (I5); the alert pose 0.4 s, with a sound",
		[Units.px_to_m(t.alert_radius_px), t.alert_delay, t.alert_pose_time, t.alert_sound != null], [6.0, 0.4, 0.4, true])
	_check("the leash: 12 m from home or 6 s out of reach; home 30% faster, ignoring aggro 2 s, healed over 1.5 s (I5)",
		[Units.px_to_m(t.leash_px), t.leash_out_of_reach_time, t.return_speed_ratio, t.return_ignore_time, t.recover_time], [12.0, 6.0, 1.3, 2.0, 1.5])
	var def := knight.stats_component.registry.get_definition(&"threat")
	_check("the threat stat (ALLIES' name, approved 2026-10-04): default 1, limits 0.1–10; the Knight's is 1",
		[def != null, def.default_value if def else 0.0, def.min_value if def else 0.0, def.max_value if def else 0.0, knight.stats_component.get_stat(&"threat")],
		[true, 1.0, 0.1, 10.0, 1.0])
	_check("the margin (Enemy.is_better_target()): 25% shorter and 48 px shorter, both",
		[Enemy.is_better_target(200.0, 100.0, t), Enemy.is_better_target(200.0, 151.0, t), Enemy.is_better_target(80.0, 50.0, t), Enemy.is_better_target(300.0, 225.0, t)],
		[true, false, false, true])


func _test_ring_spots() -> void:
	_section("The fodder ring (Pack.get_ring_spots()): side by side 0.6 m apart, never stacked (I6)")
	var c := Vector2(100, 100)
	var r := 50.0
	var gap := 2.0 * 10.0 + 19.0   # two members of radius 10, 19 px apart: 39 px center to center
	var three: Array[Vector2] = [c + Vector2.from_angle(0.3) * 200.0, c + Vector2.from_angle(-0.2) * 180.0, c + Vector2.from_angle(0.05) * 220.0]
	var spots := Pack.get_ring_spots(c, three, r, 10.0, 19.0)
	var on_ring := spots.size() == 3
	for s in spots:
		on_ring = on_ring and absf(s.distance_to(c) - r) < 0.01
	_check("three fodder: a place each on the ring", on_ring, true)
	var apart := INF
	for i in 3:
		for j in range(i + 1, 3):
			apart = minf(apart, spots[i].distance_to(spots[j]))
	_check("seven places fit (neighbors ≥ 39 px: 0.6 m edge to edge), spread evenly: 43.4 px apart; theirs differ (got %.2f)" % apart,
		snappedf(apart, 0.01) >= snappedf(2.0 * r * sin(PI / 7.0), 0.01), true)
	_check("the ring's angle is the nearest's (no anchor given): its place is straight in toward the center",
		absf(wrapf((spots[0] - c).angle() - 0.3, -PI, PI)) < 0.0001, true)
	_check("at its place, each keeps it (arrived, nothing changes)", Pack.get_ring_spots(c, spots, r, 10.0, 19.0, 0.3) == spots, true)
	var moved: Array[Vector2] = []
	for s in spots:
		moved.append(s + Vector2(30, -20))
	var shifted := Pack.get_ring_spots(c + Vector2(30, -20), moved, r, 10.0, 19.0, 0.3)
	_check("the target steps aside: the places move with it, without turning",
		shifted[0].is_equal_approx(spots[0] + Vector2(30, -20)) and shifted[1].is_equal_approx(spots[1] + Vector2(30, -20)) and shifted[2].is_equal_approx(spots[2] + Vector2(30, -20)), true)
	var ten: Array[Vector2] = []
	for i in 10:
		ten.append(c + Vector2.from_angle(i * 0.1) * (100.0 + i * 10.0))   # nearest first
	var many := Pack.get_ring_spots(c, ten, r, 10.0, 19.0)
	var inner := 0
	var outer := 0
	var first_seven := true
	for i in 10:
		var d := many[i].distance_to(c)
		if absf(d - r) < 0.01:
			inner += 1
			first_seven = first_seven and i < 7
		elif absf(d - (r + gap)) < 0.01:
			outer += 1
	_check("ten: the seven nearest fill the first ring (as many as fit), the rest the next ring out", [inner, outer, first_seven], [7, 3, true])
	var min_d := INF
	for i in 10:
		for j in range(i + 1, 10):
			min_d = minf(min_d, many[i].distance_to(many[j]))
	_check("no two closer than 39 px (got %.2f)" % min_d, min_d >= gap - 0.01, true)
	var seven: Array[Vector2] = []
	for i in 7:
		seven.append(ten[i])
	var full := Pack.get_ring_spots(c, seven, r, 10.0, 19.0)
	var even := true
	var step := full[0].distance_to(full[1])
	for i in 7:
		var nearest := INF
		for j in 7:
			if i != j:
				nearest = minf(nearest, full[i].distance_to(full[j]))
		even = even and absf(nearest - step) < 0.01
	_check("a full ring spreads evenly", [even, step >= gap], [true, true])


func _test_decide_tokens() -> void:
	_section("decide() with tokens: none held, no commit; held, commit; out of reach, never; a taunt commits")
	var b := _regular_brute()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var s := _situation(0.0, 1.0)
	s.needs_token = true
	_check("patience full but no token: it holds (first in the queue)", EnemyBrain.decide(s, b, rng).intent, &"hold")
	s.has_token = true
	_check("with its token: it commits", EnemyBrain.decide(s, b, rng).intent, &"commit")
	s.target_reachable = false
	_check("out of reach: never commits, token or not", EnemyBrain.decide(s, b, rng).intent, &"hold")
	var taunt := _situation(1.0, 0.0)
	taunt.needs_token = true
	taunt.taunted = true
	_check("taunted, patience empty, no token: it commits on its taunter", EnemyBrain.decide(taunt, b, rng).intent, &"commit")
	_check("a hand-built situation needs no token (AI1's checks hold)", EnemyBrain.decide(_situation(0.0, 1.0), b, rng).intent, &"commit")


func _test_tokens() -> void:
	_section("Attack tokens: a pool per champion, costs by rank, the queue, the rest, releases (I3)")
	await _reset_knight()
	var base := knight.global_position
	var brutes: Array[Enemy] = []
	for i in 5:
		brutes.append(_spawn(BRUTE_SCENE, base + Vector2(200 + i * 60, 600), true))   # passive: they never notice
	var elite := _spawn(ELITE_SCENE, base + Vector2(0, 700), true)
	var slime := _spawn(SLIME_SCENE, base + Vector2(-200, 700), true)
	await _frames(1)
	var a := brutes[0]
	var b := brutes[1]
	var c := brutes[2]
	var d := brutes[3]
	var e := brutes[4]
	_check("costs: a regular 1, an elite 2, fodder none (I3)", [Brains.get_token_cost(a), Brains.get_token_cost(elite), Brains.get_token_cost(slime)], [1, 2, 0])
	_check("tier 1: a pool of 2 on the Knight", [Brains.get_tokens_per_target(), Brains.get_tokens_free(knight)], [2, 2])
	_check("two ask and get one each; the third waits", [Brains.request_token(a, knight), Brains.request_token(b, knight), Brains.request_token(c, knight)], [true, true, false])
	_check("the holders, none free, the third in the queue",
		[Brains.get_token_holders(knight) == ([a, b] as Array[Enemy]), Brains.get_tokens_free(knight), Brains.is_waiting_for_token(c), Brains.request_token(a, knight)], [true, 0, true, true])
	Brains.release_token(a)
	_check("a commit ends: its token frees and it rests 1.5 s",
		[Brains.get_tokens_free(knight), Brains.has_token(a), snappedf(Brains.get_token_rest_left(a), 0.01), Brains.request_token(a, knight)], [1, false, 1.5, false])
	_check("the one waiting gets it", Brains.request_token(c, knight), true)
	_check("full again: d and e wait", [Brains.request_token(d, knight), Brains.request_token(e, knight)], [false, false])
	Brains.release_token(b, false)
	_check("a token frees: e asks first, but d (as patient, nearer) is ahead of it", [Brains.request_token(e, knight), Brains.request_token(d, knight)], [false, true])
	_check("full: b (patience 0.9, nearer) and e (1.0) wait", [Brains.request_token(b, knight, 0.9), Brains.request_token(e, knight, 1.0)], [false, false])
	Brains.release_token(c, false)
	_check("a token frees: the most patient first, whoever is nearer", [Brains.request_token(b, knight, 0.9), Brains.request_token(e, knight, 1.0)], [false, true])
	Brains.difficulty_tier = 4
	_check("tier 4: 3 per champion (one free with two held)", [Brains.get_tokens_per_target(), Brains.get_tokens_free(knight)], [3, 1])
	Brains.difficulty_tier = 1
	Brains.release_token(d, false)
	Brains.release_token(e, false)
	_check("an elite takes 2: the whole pool at tier 1", [Brains.request_token(elite, knight), Brains.get_tokens_free(knight)], [true, 0])
	_check("fodder needs none: it asks and holds nothing", [Brains.request_token(slime, knight), Brains.has_token(slime), Brains.get_tokens_free(knight)], [true, false, 0])
	Brains.release_token(elite, false)
	var hold := Brains.table.token_hold_time
	Brains.table.token_hold_time = 0.25
	Brains.request_token(b, knight)
	await _frames(20)
	_check("held past token_hold_time: Brains takes it back and it rests", [Brains.has_token(b), Brains.get_token_rest_left(b) > 1.0], [false, true])
	Brains.table.token_hold_time = hold
	await _wait_until(func() -> bool: return Brains.get_token_rest_left(b) <= 0.0, 120)
	_check("its rest over, it may ask again", Brains.request_token(b, knight), true)
	b.apply_stun(0.5)
	await _frames(1)
	_check("a holder stunned: its token frees the next tick, and it rests", [Brains.has_token(b), Brains.get_token_rest_left(b) > 1.0], [false, true])
	Brains.request_token(c, knight)
	c.health.take_damage(100000.0)
	_check("a holder dies: its token frees the same tick", [c.is_alive(), Brains.has_token(c), Brains.get_tokens_free(knight)], [false, false, 2])
	var dummy := _friend(base + Vector2(0, -600))
	await _frames(1)
	_check("another champion has its own pool", [Brains.request_token(d, dummy), Brains.get_tokens_free(dummy), Brains.get_tokens_free(knight)], [true, 1, 2])
	dummy.health.take_damage(100000.0)
	await _frames(1)
	_check("its target dies: its pool empties", [Brains.has_token(d), Brains.get_token_holders(dummy).size()], [false, 0])
	for x in [a, b, c, d, e, elite, slime, dummy]:
		if is_instance_valid(x):
			x.queue_free()
	await _frames(2)


func _test_sight() -> void:
	_section("Noticing (AI2): any party member in sight within 450 u, through WorldQuery")
	await _reset_knight()
	var spot := knight.global_position + Vector2(0, -1500)
	var slime := _spawn(SLIME_SCENE, spot, false)
	var wall := _wall_at(spot + Vector2(-60, 0), Vector2(8, 200))
	await _frames(3)
	_place(knight, spot + Vector2(-130, 0))   # 91.6 px edge to edge: in range, behind the wall
	await _frames(20)
	_check("a wall between them: it doesn't notice", slime.ai != Enemy.AI.AGGRO, true)
	wall.queue_free()
	await _frames(5)
	_check("the wall gone: it notices and picks him", [slime.ai, slime.get_target() == knight], [Enemy.AI.AGGRO, true])
	slime.passive = true
	slime.attack.cancel()
	await _reset_knight()
	var other := _spawn(SLIME_SCENE, knight.global_position + Vector2(0, 1500), false)
	await _frames(3)
	var dummy := _friend(other.global_position + Vector2(100, 0))
	await _frames(5)
	_check("any party member: a friendly dummy (team PLAYER, group party) is noticed", [other.ai, other.get_target() == dummy], [Enemy.AI.AGGRO, true])
	for x in [slime, other, dummy]:
		x.queue_free()
	await _frames(2)


## The step's "Done means": one pack member noticing wakes its pack 0.4 s
## later; packmates wake through walls, other packs only with the shouter in
## sight within 6 m; nobody they wake shouts on.
func _test_pack_alert() -> void:
	_section("The shout: the pack wakes 0.4 s after one member notices (I5)")
	await _reset_knight()
	var q := knight.global_position + Vector2(0, 1200)
	var pack := Pack.new()
	pack.name = "TestPack"
	var a := SLIME_SCENE.instantiate() as Enemy
	var b := SLIME_SCENE.instantiate() as Enemy
	var c := SLIME_SCENE.instantiate() as Enemy
	b.position = Vector2(40, 0)
	c.position = Vector2(60, 60)
	pack.add_child(a)
	pack.add_child(b)
	pack.add_child(c)
	entities.add_child(pack)
	_place(pack, q)
	var wall := _wall_at(q + Vector2(40, 32), Vector2(220, 6))   # c behind it: no sight of a, b or the Knight
	var near := _spawn(SLIME_SCENE, q + Vector2(150, -40), false)    # another pack: 6 m of a, in sight
	var hidden := _spawn(SLIME_SCENE, q + Vector2(100, 100), false)  # within 6 m of a, behind the wall
	var far := _spawn(SLIME_SCENE, q + Vector2(0, -260), false)      # in sight, past 6 m
	var alerted: Array = []
	var on_alert := func(p: Node, t: Unit) -> void: alerted.append([p, t])
	Events.pack_alerted.connect(on_alert)
	await _frames(3)
	_check("its members and its home", [pack.get_members().size(), a.get_pack() == pack, c.get_pack() == pack, pack.get_home().distance_to(q) < 0.5, near.get_pack() != pack], [3, true, true, true, true])
	_place(knight, q + Vector2(-150, 0))   # only a (111.6 px) notices him
	var woke := {}
	var tick := 0
	var alert_pose := false
	while tick < 60:
		await get_tree().physics_frame
		tick += 1
		for x in [a, b, c, near, hidden, far]:
			if not woke.has(x) and x.ai == Enemy.AI.AGGRO:
				woke[x] = tick
				if x == b:
					alert_pose = b.get_pose() == &"alert"
	Events.pack_alerted.disconnect(on_alert)
	var t0: int = woke.get(a, -1)
	var lag := func(x: Enemy) -> int: return woke.get(x, 1000) - t0
	_check("a notices him; it shows its alert pose", [t0 > 0, a.get_known().has(knight)], [true, true])
	_check("its packmates wake 0.4 s later (24 ticks ± 1)", [absi(lag.call(b) - 24) <= 1, absi(lag.call(c) - 24) <= 1], [true, true])
	_check("c woke behind the wall (packmates know), in its alert pose", [woke.has(c), alert_pose], [true, true])
	_check("another pack within 6 m with a in sight wakes with them", absi(lag.call(near) - 24) <= 1, true)
	_check("one within 6 m behind a wall, and one past 6 m, stay asleep (no chain)", [woke.has(hidden), woke.has(far)], [false, false])
	_check("Events.pack_alerted: a's pack and the other, on the Knight",
		[alerted.size(), alerted.size() > 0 and alerted[0][0] == pack and alerted[0][1] == knight, alerted.size() > 1 and alerted[1][0] == near.get_pack()], [2, true, true])
	for x in [a, b, c, near, hidden, far]:
		x.passive = true
		x.attack.cancel()
	pack.queue_free()
	for x in [near, hidden, far]:
		x.queue_free()
	wall.queue_free()
	await _frames(2)


## ALLIES' target pick against a second PLAYER-team dummy: the nearest,
## sticky with the margin, threat, stealth, taunt, downed, and an untargetable
## target chased (AB10).
func _test_target_pick() -> void:
	_section("The target pick (ALLIES): nearest by threat, sticky with the margin, taunt, stealth, downed")
	await _reset_knight()
	var p := knight.global_position + Vector2(-1500, 0)
	var e := _spawn(SLIME_SCENE, p, false)
	e.status_component.apply_status(_tag_status(&"test_root", [&"cc", &"root"] as Array[StringName], true))   # it stays put
	var dummy := _friend(p + Vector2(0, 70))        # 34.8 px edge to edge
	_place(knight, p + Vector2(-150, 0))             # 111.6 px
	await _frames(4)
	_check("it notices both and picks the nearest (the dummy)", [e.ai, e.get_target() == dummy, e.get_known().has(knight)], [Enemy.AI.AGGRO, true, true])
	_place(dummy, p + Vector2(0, 175))               # 139.8 px: the Knight is nearer, not by the margin
	await _frames(45)
	_check("sticky: the Knight a little nearer (111.6 vs 139.8 px) changes nothing", e.get_target() == dummy, true)
	_place(knight, p + Vector2(-120, 0))             # 81.6 px: 25% and 48 px nearer
	await _frames(24)
	var early := e.get_target() == dummy
	await _frames(24)
	_check("past the margin it switches, after 0.5 s (not at 0.4 s)", [early, e.get_target() == knight], [true, true])
	var threat := StatModifier.create(&"threat", StatModifier.Type.FLAT, 4.0, &"test_threat")
	dummy.stats_component.add_modifier(threat)
	await _frames(48)
	_check("threat 5: the dummy at 139.8 px counts as 28 px, and draws it",
		[snappedf(e.get_effective_distance(dummy), 0.1), e.get_target() == dummy], [snappedf((175.0 - 35.2) / 5.0, 0.1), true])
	dummy.stats_component.remove_modifiers_from(&"test_threat")
	var stealth := _tag_status(&"test_stealth", [&"stealth", &"buff"] as Array[StringName])
	dummy.status_component.apply_status(stealth)
	await _frames(2)
	_check("its target stealthed: dropped at its next pick", e.get_target() == knight, true)
	_place(dummy, p + Vector2(0, 60))
	await _frames(45)
	_check("a stealthed dummy right beside it is never picked", e.get_target() == knight, true)
	dummy.status_component.remove_status(stealth.id)
	_place(dummy, p + Vector2(0, 175))
	await _frames(2)
	var taunt := _tag_status(&"test_taunt", [&"cc", &"taunt", &"debuff"] as Array[StringName])
	e.status_component.apply_status(taunt, dummy)
	await _frames(7)
	_check("taunted by the farther dummy: its target at once (the taunt wins)", [e.get_taunter() == dummy, e.get_target() == dummy], [true, true])
	e.status_component.remove_status(taunt.id)
	await _frames(48)
	_check("the taunt over: back to the rules (the Knight is past the margin again)", e.get_target() == knight, true)
	var downed := _tag_status(&"test_downed", [&"downed"] as Array[StringName])
	knight.status_component.apply_status(downed)
	await _frames(2)
	_check("its target downed: dropped at once, the other picked", e.get_target() == dummy, true)
	knight.status_component.remove_status(downed.id)
	dummy.queue_free()
	await _frames(8)
	_check("the dummy gone: the Knight again", e.get_target() == knight, true)
	var hidden := _tag_status(&"test_untargetable", [&"untargetable"] as Array[StringName])
	knight.status_component.apply_status(hidden)
	await _frames(10)
	_check("its only target untargetable: kept and chased, not attacked (AB10)", [e.get_target() == knight, e.attack.target], [true, null])
	knight.status_component.remove_status(hidden.id)
	e.passive = true
	e.attack.cancel()
	e.queue_free()
	await _frames(2)


## The step's "Done means": walking 12 m away sends the pack home to heal.
func _test_leash() -> void:
	_section("The leash: 12 m from home or 6 s out of reach; home 30% faster, healed over 1.5 s (I5)")
	await _reset_knight()
	var home := knight.global_position + Vector2(0, -900)
	var pack := Pack.new()
	pack.name = "LeashPack"
	var s1 := SLIME_SCENE.instantiate() as Enemy
	var s2 := SLIME_SCENE.instantiate() as Enemy
	s2.position = Vector2(40, 0)
	pack.add_child(s1)
	pack.add_child(s2)
	entities.add_child(pack)
	_place(pack, home)
	await _frames(3)
	var s1_home := s1.get_home()
	_place(knight, home + Vector2(-140, 0))
	await _wait_until(func() -> bool: return s1.ai == Enemy.AI.AGGRO and s2.ai == Enemy.AI.AGGRO, 90)
	_check("they notice him and fight; the pack's home is where it was placed",
		[s1.ai, s2.ai, pack.is_fighting(), pack.get_home().distance_to(home) < 0.5, s1_home.distance_to(home) < 0.5], [Enemy.AI.AGGRO, Enemy.AI.AGGRO, true, true, true])
	s1.health.take_damage(150.0)
	var mark := _tag_status(&"test_mark", [&"debuff"] as Array[StringName])
	s1.status_component.apply_status(mark, knight)
	_place(knight, home + Vector2(-352, 0))   # 11 m from home
	await _wait_until(func() -> bool: return s1.global_position.distance_to(home) > 250.0 and s2.global_position.distance_to(home) > 250.0, 480)
	_check("at 11 m from home they keep after him", [s1.ai, s2.ai, s2.global_position.distance_to(home) > 250.0], [Enemy.AI.AGGRO, Enemy.AI.AGGRO, true])
	_place(knight, home + Vector2(-420, 0))   # 13 m: out of the leash
	await _wait_until(func() -> bool: return s1.ai == Enemy.AI.RETURN, 10)
	var mods := s1.stats_component.get_modifiers_from(Enemy.RETURN_SOURCE_ID)
	_check("past 12 m the pack gives up at once and walks home", [s1.ai, s2.ai], [Enemy.AI.RETURN, Enemy.AI.RETURN])
	_check("30% faster, in its return pose, no target", [mods.size(), snappedf(mods[0].value, 0.0001) if mods.size() > 0 else 0.0, s1.get_pose(), s1.get_target()], [1, 0.3, &"return", null])
	s1.take_damage(1.0, knight)
	await _frames(1)
	_check("a hit from outside the leash doesn't turn it around", s1.ai, Enemy.AI.RETURN)
	_place(knight, s2.global_position + (home - s2.global_position).normalized() * 100.0)   # inside the leash, in its sight
	await _frames(20)
	_check("for 2 s it ignores what it sees on the way", s2.ai, Enemy.AI.RETURN)
	_place(knight, home + Vector2(-700, 0))
	await _wait_until(func() -> bool: return s1.is_recovering(), 480)
	_check("home: the status the Knight put on it is gone; it heals", [s1.is_recovering(), s1.status_component.has_status(mark.id), s1.global_position.distance_to(s1_home) < 45.0], [true, false, true])
	var hp0 := s1.health.current
	await _frames(45)
	var hp_mid := s1.health.current
	await _wait_until(func() -> bool: return s1.ai == Enemy.AI.IDLE, 90)
	_check("to full over about 1.5 s (part way at 0.75 s: %d → %d), then it idles at home" % [roundi(hp0), roundi(hp_mid)],
		[hp_mid > hp0 + 30.0 and hp_mid < s1.health.max_health - 20.0, s1.health.current, s1.ai, s1.stats_component.get_modifiers_from(Enemy.RETURN_SOURCE_ID).size()],
		[true, s1.health.max_health, Enemy.AI.IDLE, 0])
	await _wait_until(func() -> bool: return s2.ai == Enemy.AI.IDLE, 120)

	# No target in reach for 6 s (here the Knight stealthed, inside the leash).
	var lone := _spawn(SLIME_SCENE, home + Vector2(600, 0), false)
	await _frames(3)
	_place(knight, lone.global_position + Vector2(-130, 0))
	await _wait_until(func() -> bool: return lone.ai == Enemy.AI.AGGRO, 30)
	var stealth := _tag_status(&"test_stealth", [&"stealth", &"buff"] as Array[StringName])
	knight.status_component.apply_status(stealth)
	var t0 := Brains.get_time()
	await _wait_until(func() -> bool: return lone.ai == Enemy.AI.RETURN, 480)
	var waited := Brains.get_time() - t0
	_check("nothing it can reach for 6 s: home (got %.2f s)" % waited, [lone.ai, waited >= 5.85 and waited <= 6.3], [Enemy.AI.RETURN, true])
	knight.status_component.remove_status(stealth.id)
	for x in [s1, s2, lone]:
		x.passive = true
		x.attack.cancel()
	pack.queue_free()
	lone.queue_free()
	await _frames(2)


## Found building AI2: sight never wakes an enemy on a champion it has no path
## to (a perch with no way up); a hit does, the leash sends it home after 6 s,
## and it doesn't wake again by sight (no wake, leash, wake loop).
func _test_unreachable() -> void:
	_section("A champion it can't reach: not noticed by sight; a hit wakes it, 6 s later it goes home and stays")
	await _reset_knight()
	var edge := ARENA + Vector2(2500, 0)   # the navigation's east edge
	var slime := _spawn(SLIME_SCENE, edge + Vector2(-50, 0), false)
	await _frames(3)
	_place(knight, edge + Vector2(100, 0))   # 111.6 px away, in sight, 100 px off the walkable floor
	await _frames(30)
	_check("in sight within 450 u but unreachable: it doesn't wake", slime.ai != Enemy.AI.AGGRO, true)
	slime.take_damage(1.0, knight)
	await _frames(2)
	_check("a hit wakes it; its target is out of reach", [slime.ai, slime.get_target() == knight, slime.is_target_reachable()], [Enemy.AI.AGGRO, true, false])
	await _wait_until(func() -> bool: return slime.ai == Enemy.AI.RETURN, 420)
	_check("6 s with nothing in reach: home", slime.ai, Enemy.AI.RETURN)
	await _wait_until(func() -> bool: return slime.ai == Enemy.AI.IDLE, 300)
	await _frames(150)
	_check("home and healed, it doesn't wake again on what it can't reach", [slime.ai != Enemy.AI.AGGRO, slime.health.current, slime.get_target()], [true, slime.health.max_health, null])
	slime.passive = true
	slime.queue_free()
	await _frames(2)


## The step's "Done means": a stunned holder frees its token at once.
func _test_stunned_holder() -> void:
	_section("A stunned holder frees its token at once, keeps its patience, and asks again after its rest")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	_spend_kit()
	var brute := _spawn(BRUTE_SCENE, knight.global_position + Vector2(170, 0), false)
	var brain := brute.get_brain()
	await _wait_until(func() -> bool: return Brains.has_token(brute), 400)
	_check("its patience full, it asks, gets its token and commits", [Brains.has_token(brute), brain.is_committing(), brain.get_token_state()], [true, true, "held"])
	brute.apply_stun(1.0)
	await _frames(2)
	_check("stunned: no token, its commit broken off, its patience kept, resting",
		[Brains.has_token(brute), brain.is_committing(), brain.get_patience() > 0.99, Brains.get_token_rest_left(brute) > 1.0, brain.get_token_state()], [false, false, true, true, "rest"])
	await _wait_until(func() -> bool: return Brains.has_token(brute), 300)
	_check("after the stun and its rest it asks again and gets it", Brains.has_token(brute), true)
	brute.passive = true
	brute.attack.cancel()
	brute.queue_free()
	await _frames(30)


## The step's "Done means": five test brutes never put more than two on the
## Knight at tier 1, and they rotate.
func _test_five_brutes() -> void:
	_section("Five test brutes at tier 1: never more than two on the Knight at once, and they rotate")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	_spend_kit()
	var brutes: Array[Enemy] = []
	for i in 5:
		brutes.append(_spawn(BRUTE_SCENE, knight.global_position + Vector2.from_angle(TAU * i / 5.0) * 150.0, false))
	var max_holders := 0
	var max_committing := 0
	var stray := 0
	var streak := 0
	var holders_seen := {}
	var hits := [0]
	var on_damaged := func(ctx: HitContext) -> void:
		if ctx.target == knight:
			hits[0] += 1
	Events.unit_damaged.connect(on_damaged)
	var start := Brains.get_time()
	var frames := 0
	while Brains.get_time() - start < 15.0 and frames < 1800:
		await get_tree().physics_frame
		frames += 1
		knight.health.heal(100000.0)
		if frames % 30 == 0:
			_spend_kit()
		var holders := Brains.get_token_holders(knight)
		max_holders = maxi(max_holders, holders.size())
		for h in holders:
			holders_seen[h] = true
		var committing := 0
		var bad := false
		for b in brutes:
			if b.get_brain().is_committing():
				committing += 1
				bad = bad or not Brains.has_token(b)
		max_committing = maxi(max_committing, committing)
		streak = streak + 1 if bad else 0
		if streak > 1:
			stray += 1
	Events.unit_damaged.disconnect(on_damaged)
	_check("all five aggroed on him", brutes.all(func(b: Enemy) -> bool: return b.ai == Enemy.AI.AGGRO and b.get_target() == knight), true)
	_check("never more than two tokens held, never more than two committing (15 s; got %d / %d)" % [max_holders, max_committing],
		[max_holders, max_committing <= 2], [2, true])
	_check("no commit without its token (beyond a tick's hand-over)", stray, 0)
	_check("they rotate: at least four of the five held a token (got %d); they hit him" % holders_seen.size(), [holders_seen.size() >= 4, hits[0] > 0], [true, true])
	for b in brutes:
		b.passive = true
		b.attack.cancel()
		b.queue_free()
	await _frames(60)


## The step's "Done means": fodder surrounds the Knight, with no tokens.
func _test_fodder_ring() -> void:
	_section("Fodder surrounds its target in a ring, 0.6 m apart, with no tokens (I6)")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	# First the ring itself: the Knight unstoppable, so their hits don't push
	# him about (AB10).
	var steady := _tag_status(&"test_unstoppable", [&"unstoppable"] as Array[StringName])
	knight.status_component.apply_status(steady)
	var slimes: Array[Enemy] = []
	for i in 6:
		slimes.append(_spawn(SLIME_SCENE, knight.global_position + Vector2.from_angle(deg_to_rad(-30.0 + i * 12.0)) * 120.0, false))
	# A full ring (six places for six): the last one's place can be on his far
	# side, so it walks around the others; give them up to 7 s.
	var tolerance := Brains.table.fodder_ring_tolerance_px
	var placed := func() -> bool:
		knight.health.heal(100000.0)
		return slimes.all(func(s: Enemy) -> bool: return s.get_ring_spot() != Vector2.INF and s.global_position.distance_to(s.get_ring_spot()) <= tolerance + 1.0)
	var start := Brains.get_time()
	await _wait_until(placed, 420)
	var took := Brains.get_time() - start
	var reach_frames: Array[int] = [0, 0, 0, 0, 0, 0]
	for i in 30:
		await get_tree().physics_frame
		knight.health.heal(100000.0)
		for k in slimes.size():
			reach_frames[k] += int(slimes[k].attack.is_in_range(knight))
	var member_r := slimes[0].get_gameplay_radius_px()
	var radius := knight.get_gameplay_radius_px() + member_r + slimes[0].attack.get_range_px() * Brains.table.fodder_ring_reach_share
	var on_ring := true
	var at_place := true
	var in_reach := true
	var min_d := INF
	for k in slimes.size():
		var s := slimes[k]
		on_ring = on_ring and absf(s.get_ring_spot().distance_to(knight.global_position) - radius) < 0.5
		at_place = at_place and s.global_position.distance_to(s.get_ring_spot()) <= Brains.table.fodder_ring_tolerance_px + 1.0
		in_reach = in_reach and reach_frames[k] == 30
	for i in slimes.size():
		for j in range(i + 1, slimes.size()):
			min_d = minf(min_d, slimes[i].global_position.distance_to(slimes[j].global_position))
	_check("all six have their place in one ring around him (%.1f px, half their reach), stand at it (after %.1f s), and stay in reach (frames of 30: %s)" % [radius, took, reach_frames],
		[on_ring, at_place, in_reach], [true, true, true])
	# Their places are 0.6 m apart edge to edge (a full ring of six: a little
	# more); each stands within the tolerance of its own (6 px).
	_check("side by side, not stacked: about 0.6 m between them, edge to edge (got %.1f px)" % (min_d - 2.0 * member_r),
		min_d >= 2.0 * member_r + Brains.table.fodder_ring_spacing_px - 2.0 * Brains.table.fodder_ring_tolerance_px - 2.0, true)
	_check("no tokens (fodder swarms)", [Brains.get_token_holders(knight).size(), Brains.get_token_cost(slimes[0])], [0, 0])
	# Then the real fight: their hits push him about; each keeps hitting him.
	knight.status_component.remove_status(steady.id)
	var landed: Array[int] = [0, 0, 0, 0, 0, 0]
	for k in slimes.size():
		slimes[k].attack.attack_landed.connect(func(_t: Unit, _d: float) -> void: landed[k] += 1)
	for i in 240:
		await get_tree().physics_frame
		knight.health.heal(100000.0)
	_check("pushed about by their hits for 4 s, every one of them keeps hitting him (hits each: %s)" % [landed], landed.all(func(n: int) -> bool: return n >= 1), true)
	for s in slimes:
		s.passive = true
		s.attack.cancel()
		s.queue_free()
	await _frames(30)


func _test_sandbox_packs() -> void:
	_section("SandboxBrains (AI2): the pack scenarios; the overlay's token")
	await _reset_knight()
	var sb := SandboxBrains.new()
	add_child(sb)
	await _frames(2)
	var first := sb.run_scenario(&"pack")
	await _frames(2)
	var pack: Pack = first.get_pack() if first != null else null
	_check("pack: five test brutes in one Pack 9 m away, idle",
		[pack != null and pack.get_members().size() == 5, first != null and first.data == BRUTE_DATA,
			pack != null and absf(pack.get_home().distance_to(knight.global_position) - 288.0) < 2.0, first != null and first.ai != Enemy.AI.AGGRO],
		[true, true, true, true])
	if pack != null:
		_place(knight, pack.get_home() + Vector2(-90, 0))
		await _wait_until(func() -> bool: return pack.get_members().all(func(m: Enemy) -> bool: return m.ai == Enemy.AI.AGGRO), 90)
		_check("walk up to it: one notices, and the pack wakes", pack.get_members().all(func(m: Enemy) -> bool: return m.ai == Enemy.AI.AGGRO), true)
		await _wait_until(func() -> bool: return first.get_brain().get_intent() != &"", 30)
		_check("the overlay shows its token", sb.get_overlay_text(first).contains("token "), true)
	var slime := sb.run_scenario(&"fodder")
	await _frames(2)
	_check("fodder: eight slimes in one Pack; the brutes' pack gone",
		[slime != null and slime.get_pack().get_members().size() == 8, slime != null and slime.data == SLIME_DATA, not is_instance_valid(pack)], [true, true, true])
	sb.clear_scenario()
	sb.queue_free()
	await _frames(2)


# --- Helpers ----------------------------------------------------------------------------

## The Knight's kit all spent (every slot on cooldown, no Fury): respect 0.
func _spend_kit() -> void:
	for slot in AbilityComponent.SLOTS:
		if knight.abilities.get_ability(slot) != null:
			knight.abilities.start_cooldown(slot)
	if knight.resource_pool != null:
		knight.resource_pool.try_spend(knight.resource_pool.current)


## A friendly dummy (ALLIES' second champion's stand-in): a passive slime with
## no data on the player's team, in the group `party`.
func _friend(pos: Vector2) -> Enemy:
	var f := SLIME_SCENE.instantiate() as Enemy
	f.data = null
	f.passive = true
	entities.add_child(f)
	f.team = Unit.Team.PLAYER
	f.remove_from_group(&"enemies")
	f.add_to_group(&"party")
	_place(f, pos)
	return f


## A status with these tags that lasts until removed (blocks moving with
## `root`).
func _tag_status(id: StringName, tags: Array[StringName], root: bool = false) -> StatusEffect:
	var s := StatusEffect.new()
	s.id = id
	s.tags = tags
	s.duration = -1.0
	s.blocks_move = root
	s.blocks_dash = root
	return s


## One flat walkable rectangle around the arena on the world's navigation map,
## as a room's baked navigation would be.
func _add_navigation() -> void:
	var poly := NavigationPolygon.new()
	var r := Rect2(ARENA - Vector2(2500, 2500), Vector2(5000, 5000))
	poly.vertices = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	poly.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	var region := NavigationRegion2D.new()
	region.navigation_polygon = poly
	add_child(region)


func _spawn(scene: PackedScene, pos: Vector2, passive: bool) -> Enemy:
	var e := scene.instantiate() as Enemy
	e.passive = passive
	entities.add_child(e)
	_place(e, pos)
	return e


func _wall_at(pos: Vector2, size: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	wall.add_child(shape)
	add_child(wall)
	wall.global_position = pos
	return wall


func _reset_knight() -> void:
	knight.abilities.interrupt_cast()
	knight.abilities.cancel_pending()
	knight.attack.cancel_swing()
	knight.movement.stop()
	await _wait_until(func() -> bool: return not knight.is_stunned() and not knight.movement.is_displaced(), 120)
	await _frames(2)
	_place(knight, ARENA)
	knight.health.heal(100000.0)
	for slot in AbilityComponent.SLOTS:
		for i in knight.abilities.get_max_charges(slot):
			knight.abilities.reset_cooldown(slot)
	await _frames(1)


func _place(node: Node2D, pos: Vector2) -> void:
	node.global_position = pos
	node.reset_physics_interpolation()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


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
		print("  FAIL  %s: %s" % [label, detail])
