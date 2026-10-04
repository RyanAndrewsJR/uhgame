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
	print("\n=== Enemies test (ENEMIES_AI AI1) ===")
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
	_check("H cycles the six", [sb.next_scenario(), sb.next_scenario()], [&"all_ready", &"none_ready"])

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


# --- Helpers ----------------------------------------------------------------------------

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
