extends Node
## STATS.md step 2 test: open res://scenes/tests/stats_test.tscn and press F6.
## Adds and removes modifiers on StatsComponents set up from knight.tres and
## slime.tres and prints PASS/FAIL per check, then a total.
##
## The move_speed parity checks put the same speed modifiers into a real
## MovementComponent (add_speed_modifier) and into StatsComponent, and the
## two results must match. That guards the step 4 migration.
##
## The last section wires the Knight's MovementComponent to its
## StatsComponent (as Unit does) and checks the add_speed_modifier() wrapper
## (STATS.md step 4), including a timed slow running out.
##
## Two push_errors in the output are expected (the unknown stat checks).
## Run headless and it quits with the number of failures as the exit code.

const KNIGHT_STATS: UnitStats = preload("res://data/units/knight.tres")
const SLIME_STATS: UnitStats = preload("res://data/units/slime.tres")
const FLAT := StatModifier.Type.FLAT
const PERCENT_ADD := StatModifier.Type.PERCENT_ADD
const PERCENT_MULT := StatModifier.Type.PERCENT_MULT
const CLEAVE: Ability = preload("res://data/abilities/knight_q_cleave.tres")
const LUNGE: Ability = preload("res://data/abilities/knight_e_lunge.tres")
const SLAM: Ability = preload("res://data/abilities/slime_elite_q_slam.tres")

@onready var knight_movement: MovementComponent = $KnightBody/MovementComponent
@onready var knight_stats: StatsComponent = $KnightBody/StatsComponent
@onready var slime_movement: MovementComponent = $SlimeBody/MovementComponent
@onready var slime_stats: StatsComponent = $SlimeBody/StatsComponent

var _passed: int = 0
var _failed: int = 0
var _signals: Array = []   # [key, old, new] per stat_changed


func _ready() -> void:
	# Same hand-off as Unit._ready().
	knight_movement.base_move_speed = KNIGHT_STATS.move_speed
	slime_movement.base_move_speed = SLIME_STATS.move_speed
	knight_stats.setup(KNIGHT_STATS, knight_movement)
	slime_stats.setup(SLIME_STATS, slime_movement)
	knight_stats.stat_changed.connect(_on_stats_stat_changed)

	print("\n=== StatsComponent test ===")
	_test_registry()
	_test_base_values()
	_test_formula_and_exact_restore()
	_test_clamps_and_rounding()
	_test_attack_speed_cap()
	_test_move_speed()
	_test_move_speed_parity()
	_test_signals()
	_test_levels()
	_test_helpers()
	_test_unknown_keys()
	_test_scoped_modifiers()
	await _test_speed_modifier_wrapper()
	await _test_health_and_resource_pools()
	print("=== %d passed, %d failed ===\n" % [_passed, _failed])

	if DisplayServer.get_name() == "headless":
		get_tree().quit(_failed)


# --- Tests --------------------------------------------------------------------

## STATS step 6: ability params with scoped modifiers.
func _test_scoped_modifiers() -> void:
	_section("Scoped modifiers (ability params)")
	_check("ids: knight_cleave / knight_lunge / slime_elite_slam", [CLEAVE.id, LUNGE.id, SLAM.id], [&"knight_cleave", &"knight_lunge", &"slime_elite_slam"])
	_check("tags: cleave [area], lunge [movement]", [CLEAVE.tags, LUNGE.tags], [[&"area"], [&"movement"]])
	_check("no modifiers: the plain values", [knight_stats.get_ability_param(CLEAVE, &"cooldown"), knight_stats.get_ability_param(LUNGE, &"cast_range")], [3.0, 400.0])
	var before := _all_values(knight_stats)
	_signals.clear()
	var item: Array[StatModifier] = [
		_mod(&"cast_range", PERCENT_ADD, 0.30, &"item_test", &"ability:knight_lunge"),
		_mod(&"cooldown", FLAT, -1.5, &"item_test", &"ability:knight_cleave"),
		_mod(&"base_damage", PERCENT_MULT, 0.5, &"item_test", &"tag:area"),
		_mod(&"attack_speed", PERCENT_ADD, 0.10, &"item_test"),
	]
	knight_stats.add_modifiers(item)
	_check("+30% Lunge range: 400 -> 520", knight_stats.get_ability_param(LUNGE, &"cast_range"), 520.0)
	_check("-1.5 s Cleave cooldown: 3 -> 1.5", knight_stats.get_ability_param(CLEAVE, &"cooldown"), 1.5)
	_check("x1.5 base damage on every 'area' ability: Cleave 80 -> 120, Slam 100 -> 150",
		[knight_stats.get_ability_param(CLEAVE, &"base_damage"), knight_stats.get_ability_param(SLAM, &"base_damage")], [120.0, 150.0])
	_check("other abilities and params untouched",
		[knight_stats.get_ability_param(LUNGE, &"cooldown"), knight_stats.get_ability_param(CLEAVE, &"cast_range"), knight_stats.get_ability_param(LUNGE, &"base_damage")], [8.0, 300.0, 50.0])
	_check("the unscoped part is a normal stat (+10% attack speed)", knight_stats.get_stat(&"attack_speed"), 0.77)
	_check("scoped modifiers change no stat", _signals.map(func(e: Array) -> StringName: return e[0]), [&"attack_speed"])
	_check("the resources themselves are untouched", [LUNGE.cast_range, CLEAVE.cooldown], [400.0, 3.0])
	_check("slimes don't get the Knight's item", slime_stats.get_ability_param(CLEAVE, &"cooldown"), 3.0)
	knight_stats.add_modifier(_mod(&"cooldown", FLAT, -10.0, &"item_big", &"ability:knight_cleave"))
	_check("never below 0", knight_stats.get_ability_param(CLEAVE, &"cooldown"), 0.0)
	knight_stats.remove_modifiers_from(&"item_big")
	knight_stats.remove_modifiers_from(&"item_test")
	_check("removing the item restores the params exactly",
		[knight_stats.get_ability_param(LUNGE, &"cast_range"), knight_stats.get_ability_param(CLEAVE, &"cooldown"), knight_stats.get_ability_param(CLEAVE, &"base_damage")], [400.0, 3.0, 80.0])
	_check_exact("and every stat exactly", _all_values(knight_stats), before)
	_signals.clear()

func _test_registry() -> void:
	_section("Registry")
	var keys := knight_stats.registry.get_keys()
	_check("21 stats registered", keys.size(), 21)
	for key in keys:
		var def := knight_stats.registry.get_definition(key)
		var field := def.get_base_field()
		if field in KNIGHT_STATS:
			_check("%s reads UnitStats.%s" % [key, field], knight_stats.get_base_value(key), float(KNIGHT_STATS.get(field)))
		else:
			_check("%s uses the registry default" % key, knight_stats.get_base_value(key), def.default_value)


func _test_base_values() -> void:
	_section("Base values (knight.tres)")
	_check("max_health", knight_stats.get_stat(&"max_health"), 650.0)
	_check("attack_damage", knight_stats.get_stat(&"attack_damage"), 64.0)
	_check("attack_speed = base_attack_speed", knight_stats.get_stat(&"attack_speed"), 0.7)
	_check("attack_range", knight_stats.get_stat(&"attack_range"), 175.0)
	_check("move_speed 560 (inside the soft caps)", knight_stats.get_stat(&"move_speed"), 560.0)
	_check("dash_charges", knight_stats.get_stat(&"dash_charges"), 1.0)
	_check("armor: neutral default 0", knight_stats.get_stat(&"armor"), 0.0)
	_check("crit_damage: neutral default 1 (no extra damage)", knight_stats.get_stat(&"crit_damage"), 1.0)
	_check("max_resource 300 (knight.tres)", knight_stats.get_stat(&"max_resource"), 300.0)
	_check("resource_regen 6 (knight.tres)", knight_stats.get_stat(&"resource_regen"), 6.0)
	_check("health_regen 0 (knight.tres)", knight_stats.get_stat(&"health_regen"), 0.0)
	_check("slime max_resource 0 (neutral default)", slime_stats.get_stat(&"max_resource"), 0.0)
	_check("slime move_speed 285", slime_stats.get_stat(&"move_speed"), 285.0)


func _test_formula_and_exact_restore() -> void:
	_section("Formula and exact restore")
	var before := _all_values(knight_stats)
	var item_a: Array[StatModifier] = [
		_mod(&"attack_damage", FLAT, 10.0, &"item_a"),
		_mod(&"attack_damage", PERCENT_ADD, 0.2, &"item_a"),
		_mod(&"armor", FLAT, 25.0, &"item_a"),
	]
	var item_b: Array[StatModifier] = [
		_mod(&"attack_damage", PERCENT_ADD, 0.3, &"item_b"),
		_mod(&"attack_damage", PERCENT_MULT, 0.1, &"item_b"),
	]
	knight_stats.add_modifiers(item_a)
	knight_stats.add_modifiers(item_b)
	knight_stats.add_modifier(_mod(&"attack_damage", PERCENT_MULT, 0.5, &"status_rage"))
	# (64 + 10) x (1 + 0.2 + 0.3) x 1.1 x 1.5
	_check("AD = (64+10) x 1.5 x 1.1 x 1.5", knight_stats.get_stat(&"attack_damage"), 183.15)
	_check("armor 0 + 25", knight_stats.get_stat(&"armor"), 25.0)
	_check("get_modifiers_from(item_a) has 3", knight_stats.get_modifiers_from(&"item_a").size(), 3)

	knight_stats.remove_modifiers_from(&"item_b")
	_check("remove item_b: AD = 74 x 1.2 x 1.5", knight_stats.get_stat(&"attack_damage"), 133.2)
	knight_stats.remove_modifiers_from(&"item_a")
	knight_stats.remove_modifiers_from(&"status_rage")
	knight_stats.remove_modifiers_from(&"item_never_added")
	_check_exact("every stat back to exactly its old value", _all_values(knight_stats), before)


func _test_clamps_and_rounding() -> void:
	_section("Clamps and integer rounding")
	knight_stats.add_modifier(_mod(&"crit_chance", FLAT, 1.5, &"item_crit"))
	_check("crit_chance 1.5 clamps to max 1", knight_stats.get_stat(&"crit_chance"), 1.0)
	knight_stats.remove_modifiers_from(&"item_crit")
	knight_stats.add_modifier(_mod(&"crit_chance", FLAT, -0.5, &"item_crit"))
	_check("crit_chance -0.5 clamps to min 0", knight_stats.get_stat(&"crit_chance"), 0.0)
	knight_stats.remove_modifiers_from(&"item_crit")

	knight_stats.add_modifier(_mod(&"dash_charges", FLAT, 1.6, &"item_dash"))
	_check("dash_charges 1 + 1.6 rounds to 3", knight_stats.get_stat(&"dash_charges"), 3.0)
	knight_stats.add_modifier(_mod(&"dash_charges", FLAT, 10.0, &"item_dash"))
	_check("dash_charges clamps to max 5", knight_stats.get_stat(&"dash_charges"), 5.0)
	knight_stats.remove_modifiers_from(&"item_dash")
	knight_stats.add_modifier(_mod(&"dash_charges", FLAT, -3.0, &"item_dash"))
	_check("dash_charges clamps to min 1", knight_stats.get_stat(&"dash_charges"), 1.0)
	knight_stats.remove_modifiers_from(&"item_dash")

	knight_stats.add_modifier(_mod(&"tenacity", FLAT, 0.95, &"item_tenacity"))
	_check("tenacity clamps to max 0.8", knight_stats.get_stat(&"tenacity"), 0.8)
	knight_stats.remove_modifiers_from(&"item_tenacity")

	knight_stats.add_modifier(_mod(&"max_health", FLAT, -5000.0, &"item_cursed"))
	_check("max_health clamps to min 1", knight_stats.get_stat(&"max_health"), 1.0)
	knight_stats.remove_modifiers_from(&"item_cursed")
	_check("max_health restored", knight_stats.get_stat(&"max_health"), 650.0)


func _test_attack_speed_cap() -> void:
	_section("attack_speed")
	knight_stats.add_modifier(_mod(&"attack_speed", PERCENT_ADD, 0.5, &"item_as"))
	_check("0.7 x (1 + 50% bonus AS)", knight_stats.get_stat(&"attack_speed"), 1.05)
	knight_stats.add_modifier(_mod(&"attack_speed", PERCENT_ADD, 2.5, &"item_as"))
	_check("0.7 x 4 = 2.8 capped by attack_speed_cap 2.5", knight_stats.get_stat(&"attack_speed"), 2.5)
	knight_stats.remove_modifiers_from(&"item_as")
	knight_stats.add_modifier(_mod(&"attack_speed", PERCENT_MULT, -0.9, &"status_chill"))
	_check("0.7 x 0.1 clamps to min 0.2", knight_stats.get_stat(&"attack_speed"), 0.2)
	knight_stats.remove_modifiers_from(&"status_chill")
	_check("attack_speed restored", knight_stats.get_stat(&"attack_speed"), 0.7)


func _test_move_speed() -> void:
	_section("move_speed rules")
	knight_stats.add_modifier(_mod(&"move_speed", PERCENT_ADD, -0.3, &"status_slow_a"))
	knight_stats.add_modifier(_mod(&"move_speed", PERCENT_ADD, -0.5, &"status_slow_b"))
	# Strongest slow only: 560 x 0.5 = 280, below the low cap 357:
	# 357 - (357 - 280) x 0.5 = 318.5
	_check("only the strongest slow (50%), then the low soft cap", knight_stats.get_stat(&"move_speed"), 318.5)
	knight_stats.remove_modifiers_from(&"status_slow_b")
	# 560 x 0.7 = 392, inside the caps.
	_check("remove it: the 30% slow applies", knight_stats.get_stat(&"move_speed"), 392.0)
	knight_stats.remove_modifiers_from(&"status_slow_a")

	knight_stats.add_modifier(_mod(&"move_speed", PERCENT_ADD, 0.5, &"status_haste"))
	# 840 > 795: 674 + (795 - 674) x 0.8 = 770.8, + (840 - 795) x 0.5 = 793.3
	_check("+50%: 840 soft capped to 793.3", knight_stats.get_stat(&"move_speed"), 793.3)
	knight_stats.add_modifier(_mod(&"move_speed", PERCENT_ADD, -0.2, &"status_slow_a"))
	# 560 x 1.5 x 0.8 = 672, just under the high cap.
	_check("haste and slow: 560 x 1.5 x 0.8", knight_stats.get_stat(&"move_speed"), 672.0)
	knight_stats.remove_modifiers_from(&"status_haste")
	knight_stats.remove_modifiers_from(&"status_slow_a")
	_check("move_speed restored", knight_stats.get_stat(&"move_speed"), 560.0)

	for raw: float in [100.0, 219.0, 300.0, 450.0, 600.0, 900.0]:
		slime_stats.add_modifier(_mod(&"move_speed", FLAT, raw - 285.0, &"test_raw"))
		_check("slime thresholds match LoL apply_soft_caps(%d)" % raw, slime_stats.get_stat(&"move_speed"), MovementComponent.apply_soft_caps(raw))
		slime_stats.remove_modifiers_from(&"test_raw")


func _test_move_speed_parity() -> void:
	_section("move_speed parity with MovementComponent")
	# Each case: list of [flat, percent] speed modifiers.
	var cases: Array = [
		[],
		[[100.0, 0.0]],
		[[0.0, 0.4]],
		[[0.0, -0.3], [0.0, -0.6]],
		[[50.0, 0.25], [0.0, -0.2]],
		[[0.0, 1.0]],
		[[0.0, 3.0]],
		[[0.0, -0.99]],
		[[-400.0, 0.0]],
		[[30.0, 0.1], [20.0, 0.15], [0.0, -0.45], [0.0, -0.1]],
	]
	for pair in [[knight_movement, knight_stats, "knight"], [slime_movement, slime_stats, "slime"]]:
		var movement: MovementComponent = pair[0]
		var stats: StatsComponent = pair[1]
		for i in cases.size():
			var mods: Array = cases[i]
			for j in mods.size():
				var id := StringName("parity_%d" % j)
				movement.add_speed_modifier(id, mods[j][0], mods[j][1])
				if mods[j][0] != 0.0:
					stats.add_modifier(_mod(&"move_speed", FLAT, mods[j][0], id))
				if mods[j][1] != 0.0:
					stats.add_modifier(_mod(&"move_speed", PERCENT_ADD, mods[j][1], id))
			_check("%s case %d %s" % [pair[2], i, str(mods)], stats.get_stat(&"move_speed"), movement.get_move_speed())
			for j in mods.size():
				var id := StringName("parity_%d" % j)
				movement.remove_speed_modifier(id)
				stats.remove_modifiers_from(id)


func _test_signals() -> void:
	_section("stat_changed")
	_signals.clear()
	knight_stats.add_modifier(_mod(&"attack_damage", FLAT, 6.0, &"item_sword"))
	_check_signals("add +6 AD", [[&"attack_damage", 64.0, 70.0]])
	knight_stats.remove_modifiers_from(&"item_sword")
	_check_signals("remove it", [[&"attack_damage", 70.0, 64.0]])

	var item_two_stats: Array[StatModifier] = [
		_mod(&"armor", FLAT, 10.0, &"item_plate"),
		_mod(&"armor", PERCENT_ADD, 0.1, &"item_plate"),
		_mod(&"max_health", FLAT, 100.0, &"item_plate"),
	]
	knight_stats.add_modifiers(item_two_stats)
	_check_signals("item with 2 stats: one signal per stat", [[&"armor", 0.0, 11.0], [&"max_health", 650.0, 750.0]])
	knight_stats.remove_modifiers_from(&"item_plate")
	_signals.clear()

	knight_stats.add_modifier(_mod(&"move_speed", PERCENT_ADD, -0.4, &"status_slow_a"))
	_signals.clear()
	knight_stats.add_modifier(_mod(&"move_speed", PERCENT_ADD, -0.2, &"status_slow_b"))
	_check_signals("weaker second slow: no signal", [])
	knight_stats.remove_modifiers_from(&"status_slow_a")
	knight_stats.remove_modifiers_from(&"status_slow_b")
	_signals.clear()

	knight_stats.add_modifier(_mod(&"attack_speed", PERCENT_ADD, 5.0, &"item_as"))
	_signals.clear()
	knight_stats.add_modifier(_mod(&"attack_speed", PERCENT_ADD, 1.0, &"item_as_2"))
	_check_signals("already at the attack_speed cap: no signal", [])
	knight_stats.remove_modifiers_from(&"item_as")
	knight_stats.remove_modifiers_from(&"item_as_2")
	_signals.clear()

	knight_stats.add_modifier(_mod(&"cast_range", PERCENT_ADD, 0.3, &"item_lunge", &"ability:knight_lunge"))
	_check_signals("scoped modifier: no stat signal", [])
	_check("scoped modifier stored", knight_stats.get_modifiers_from(&"item_lunge").size(), 1)
	knight_stats.remove_modifiers_from(&"item_lunge")
	_check_signals("removing it: no stat signal", [])


func _test_levels() -> void:
	_section("Levels")
	var stats: StatsComponent = StatsComponent.new()
	add_child(stats)
	stats.setup(KNIGHT_STATS, null, {&"attack_damage": 3.0, &"max_health": 90.0})
	_signals.clear()
	stats.stat_changed.connect(_on_stats_stat_changed)
	_check("level 1: no growth", stats.get_stat(&"attack_damage"), 64.0)
	stats.set_level(5)
	_check("level 5 AD = 64 + 3 x 4", stats.get_stat(&"attack_damage"), 76.0)
	_check("level 5 max_health = 650 + 90 x 4", stats.get_stat(&"max_health"), 1010.0)
	_check("stat without growth unchanged", stats.get_stat(&"armor"), 0.0)
	_check("set_level emitted 2 signals", _signals.size(), 2)
	stats.add_modifier(_mod(&"attack_damage", PERCENT_ADD, 0.5, &"item_sword"))
	_check("modifiers apply on top of growth: 76 x 1.5", stats.get_stat(&"attack_damage"), 114.0)
	stats.set_level(0)
	_check("set_level(0) clamps to level 1", stats.get_level(), 1)
	_check("back at level 1: 64 x 1.5", stats.get_stat(&"attack_damage"), 96.0)
	_check("no soft caps without a MovementComponent", stats.get_stat(&"move_speed"), 560.0)
	stats.queue_free()


func _test_helpers() -> void:
	_section("Helpers")
	_check("get_attack_interval = 1 / 0.7", knight_stats.get_attack_interval(), 1.0 / 0.7)
	_check("get_cooldown(10) with 0 haste", knight_stats.get_cooldown(10.0), 10.0)
	knight_stats.add_modifier(_mod(&"ability_haste", FLAT, 25.0, &"item_haste"))
	_check("get_cooldown(10) with 25 haste = 8", knight_stats.get_cooldown(10.0), 8.0)
	knight_stats.remove_modifiers_from(&"item_haste")


func _test_unknown_keys() -> void:
	_section("Unknown keys (2 errors expected above the results)")
	var before := _all_values(knight_stats)
	_check("get_stat(&\"not_a_stat\") returns 0 after push_error", knight_stats.get_stat(&"not_a_stat"), 0.0)
	knight_stats.add_modifier(_mod(&"not_a_stat", FLAT, 5.0, &"item_typo"))
	_check("modifier for an unknown stat is rejected", knight_stats.get_modifiers_from(&"item_typo").size(), 0)
	_check_exact("nothing else changed", _all_values(knight_stats), before)


func _test_speed_modifier_wrapper() -> void:
	_section("add_speed_modifier wrapper (MovementComponent with a StatsComponent)")
	knight_movement.add_speed_modifier(&"test_early", 0.0, 0.1)
	knight_movement.set_stats_component(knight_stats)
	_check("a modifier added before wiring moves over", knight_stats.get_modifiers_from(&"test_early").size(), 1)
	_check("get_move_speed reads the stat: 560 x 1.1", knight_movement.get_move_speed(), 616.0)
	knight_movement.remove_speed_modifier(&"test_early")

	knight_movement.add_speed_modifier(&"iron_resolve", 0.0, 0.2)
	_check("stored in StatsComponent under its id", knight_stats.get_modifiers_from(&"iron_resolve").size(), 1)
	_check("560 x 1.2", knight_movement.get_move_speed(), 672.0)
	knight_movement.add_speed_modifier(&"iron_resolve", 50.0, 0.1)
	_check("same id replaces it (now flat + %)", knight_stats.get_modifiers_from(&"iron_resolve").size(), 2)
	_check("(560 + 50) x 1.1", knight_movement.get_move_speed(), 671.0)
	knight_movement.remove_speed_modifier(&"iron_resolve")
	_check("remove_speed_modifier removes it", knight_stats.get_modifiers_from(&"iron_resolve").size(), 0)
	_check("move_speed back to 560", knight_movement.get_move_speed(), 560.0)

	knight_movement.add_speed_modifier(&"iron_resolve_slow", 0.0, -0.3, 0.1)
	_check("timed 30% slow applies: 560 x 0.7", knight_movement.get_move_speed(), 392.0)
	for i in 12:   # 0.2 s at 60 Hz
		await get_tree().physics_frame
	_check("timed slow removed after its duration", knight_stats.get_modifiers_from(&"iron_resolve_slow").size(), 0)
	_check("move_speed back to 560 after it", knight_movement.get_move_speed(), 560.0)


func _test_health_and_resource_pools() -> void:
	_section("HealthComponent and ResourceComponent following stats (step 5)")
	var stats: StatsComponent = StatsComponent.new()
	add_child(stats)
	stats.setup(KNIGHT_STATS)
	var health: HealthComponent = HealthComponent.new()
	add_child(health)
	health.set_stats_component(stats)
	var pool: ResourceComponent = ResourceComponent.new()
	add_child(pool)
	pool.set_stats_component(stats)
	var depleted_count := [0]
	pool.depleted.connect(func() -> void: depleted_count[0] += 1)

	_check("health starts full at max_health 650", health.current, 650.0)
	_check("mana starts full at max_resource 300", pool.current, 300.0)

	health.take_damage(100.0)
	stats.add_modifier(_mod(&"max_health", FLAT, 200.0, &"item_heart"))
	_check("max_health +200: max 850", health.max_health, 850.0)
	_check("current rises by the same 200: 550 -> 750", health.current, 750.0)
	stats.remove_modifiers_from(&"item_heart")
	_check("item removed: max back to 650", health.max_health, 650.0)
	_check("current 750 clamped to 650", health.current, 650.0)
	health.take_damage(400.0)
	stats.add_modifier(_mod(&"max_health", FLAT, -100.0, &"item_cursed"))
	_check("max down to 550 with current 250 below it: current stays 250", health.current, 250.0)
	stats.remove_modifiers_from(&"item_cursed")
	_check("max back up 100: current 250 -> 350", health.current, 350.0)

	await _physics_frames(30)
	_check("health_regen 0: no regen", health.current, 350.0)
	stats.add_modifier(_mod(&"health_regen", FLAT, 30.0, &"status_regen"))
	await _physics_frames(30)
	_check_near("health_regen 30/s for 0.5 s: about +15", health.current, 365.0, 0.6)
	stats.remove_modifiers_from(&"status_regen")

	_check("try_spend(100) succeeds", pool.try_spend(100.0), true)
	_check("mana 300 -> 200", pool.current, 200.0)
	_check("can_afford(250) is false", pool.can_afford(250.0), false)
	_check("try_spend(250) fails", pool.try_spend(250.0), false)
	_check("failed spend leaves mana at 200", pool.current, 200.0)
	await _physics_frames(30)
	_check_near("resource_regen 6/s for 0.5 s: about +3", pool.current, 203.0, 0.15)
	stats.add_modifier(_mod(&"max_resource", FLAT, 100.0, &"item_tome"))
	_check("max_resource +100: max 400", pool.max_resource, 400.0)
	_check_near("current rises by the same 100", pool.current, 303.0, 0.15)
	stats.remove_modifiers_from(&"item_tome")
	_check_near("max back to 300: current 303 clamped", pool.current, 300.0, 0.001)
	_check("spend everything", pool.try_spend(pool.current), true)
	_check("depleted emitted once", depleted_count[0], 1)
	_check("is_empty", pool.is_empty(), true)
	pool.restore(1000.0)
	_check("restore clamps to max", pool.current, 300.0)

	stats.add_modifier(_mod(&"health_regen", FLAT, 30.0, &"status_regen"))
	health.take_damage(10000.0)
	await _physics_frames(30)
	_check("no regen while dead", health.current, 0.0)
	stats.add_modifier(_mod(&"max_health", FLAT, 200.0, &"item_heart"))
	_check("a raised max doesn't revive", health.current, 0.0)
	_check("but the max still follows", health.max_health, 850.0)

	for node: Node in [stats, health, pool]:
		node.queue_free()


# --- Helpers ------------------------------------------------------------------

func _physics_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check_near(label: String, actual: float, expected: float, tolerance: float) -> void:
	_report(absf(actual - expected) <= tolerance, label, "got %s, expected %s ± %s" % [actual, expected, tolerance])


func _mod(stat: StringName, type: StatModifier.Type, value: float, source_id: StringName, scope: StringName = &"") -> StatModifier:
	return StatModifier.create(stat, type, value, source_id, scope)


func _all_values(stats: StatsComponent) -> Dictionary:
	var values := {}
	for key in stats.registry.get_keys():
		values[key] = stats.get_stat(key)
	return values


func _section(title: String) -> void:
	print("-- %s" % title)


func _check(label: String, actual: Variant, expected: Variant) -> void:
	var ok: bool
	if actual is float or expected is float:
		ok = is_equal_approx(float(actual), float(expected))
	else:
		ok = actual == expected
	_report(ok, label, "got %s, expected %s" % [actual, expected])


## Exact equality, no tolerance (used for "restores exactly").
func _check_exact(label: String, actual: Variant, expected: Variant) -> void:
	_report(actual == expected, label, "got %s, expected %s" % [actual, expected])


func _check_signals(label: String, expected: Array) -> void:
	var ok := _signals.size() == expected.size()
	if ok:
		for i in expected.size():
			ok = ok and _signals[i][0] == expected[i][0] \
				and is_equal_approx(_signals[i][1], expected[i][1]) \
				and is_equal_approx(_signals[i][2], expected[i][2])
	_report(ok, label, "got %s, expected %s" % [_signals, expected])
	_signals.clear()


func _report(ok: bool, label: String, detail: String) -> void:
	if ok:
		_passed += 1
		print("  PASS  %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s: %s" % [label, detail])


func _on_stats_stat_changed(key: StringName, old_value: float, new_value: float) -> void:
	_signals.append([key, old_value, new_value])
