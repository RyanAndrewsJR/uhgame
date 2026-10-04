extends Node2D
## LOOT.md test: open res://scenes/tests/loot_test.tscn and press F6.
## L1: items, data and rolling. The default LootTable (the seven rarities:
## names, colors, affix counts, bands, sigil counts, named flags, magic find
## effects), the 7 item bases and their implicits, the 15 affixes, the regular
## and elite drop tables; validation catching each broken rule; the weight and
## chance formulas; rarity shares over 100,000 seeded rolls (depth and magic
## find shifting them as the formula says); rolled items (affix counts, slots,
## bands, rounding, no repeats, the Legendary / Artifact fallback to Exotic
## until L5, the Artifact's band drawing nothing); an item's modifiers
## (accepted by a real StatsComponent, removed exactly), its tooltip lines and
## its to_dict() round trip; the drop table by unit.
## Prints PASS/FAIL per check, then a total.
## Run headless and it quits with the number of failures as the exit code.

const REGULAR: DropTable = preload("res://data/drop_tables/drop_table_regular.tres")
const ELITE: DropTable = preload("res://data/drop_tables/drop_table_elite.tres")
const KNIGHT_STATS: UnitStats = preload("res://data/units/knight.tres")
const LUNGE: Ability = preload("res://data/abilities/knight_e_lunge.tres")
const CLEAVE: Ability = preload("res://data/abilities/knight_q_cleave.tres")
const SLIME_SCENE: PackedScene = preload("res://scenes/enemies/slime.tscn")
const SLIME_ELITE_SCENE: PackedScene = preload("res://scenes/enemies/slime_elite.tscn")
const AUGMENT_LUNGE_STUNS: AbilityAugment = preload("res://data/augments/augment_lunge_stuns.tres")
const AUGMENT_JUDGEMENT_RESET: AbilityAugment = preload("res://data/augments/augment_judgement_reset.tres")

const ROLLS := 100000
const R := Item.Rarity
const S := Item.Slot

## LOOT.md, Rarities: name, affixes, band, sigils, named, magic find effect, color.
const RARITY_ROWS := [
	["Common", 1, 0.0, 0.35, 0, false, 0.0, "c8c8c8"],
	["Uncommon", 2, 0.1, 0.5, 0, false, 1.0, "4cd04c"],
	["Rare", 3, 0.25, 0.65, 0, false, 1.0, "4d8cff"],
	["Unique", 3, 0.35, 0.75, 1, false, 1.0, "b44dff"],
	["Exotic", 3, 0.35, 0.75, 2, false, 1.0, "26d9c4"],
	["Legendary", 0, 0.55, 0.95, 0, true, 0.5, "ff8c1a"],
	["Artifact", 0, 1.0, 1.0, 0, true, 0.5, "f0d890"],
]

## LOOT.md, Item bases: id, name, slot, implicit [stat, type, value] or [].
const BASE_ROWS := [
	[&"item_base_longsword", "Longsword", S.WEAPON, [&"attack_damage", StatModifier.Type.FLAT, 6.0]],
	[&"item_base_iron_helm", "Iron Helm", S.HELM, [&"max_health", StatModifier.Type.FLAT, 40.0]],
	[&"item_base_mail_hauberk", "Mail Hauberk", S.CHEST, [&"armor", StatModifier.Type.FLAT, 10.0]],
	[&"item_base_leather_gloves", "Leather Gloves", S.GLOVES, [&"attack_speed", StatModifier.Type.PERCENT_ADD, 0.05]],
	[&"item_base_leather_boots", "Leather Boots", S.BOOTS, [&"move_speed", StatModifier.Type.PERCENT_ADD, 0.03]],
	[&"item_base_band", "Band", S.RING, []],
	[&"item_base_pendant", "Pendant", S.AMULET, []],
]

## LOOT.md, The affix pool: id, stat, type, scope, min, max, step, slots.
const AFFIX_ROWS := [
	[&"affix_max_health", &"max_health", 0, &"", 20.0, 100.0, 1.0, [S.HELM, S.CHEST, S.BOOTS, S.RING, S.AMULET]],
	[&"affix_attack_damage", &"attack_damage", 0, &"", 2.0, 10.0, 1.0, [S.WEAPON, S.GLOVES, S.RING, S.AMULET]],
	[&"affix_attack_speed", &"attack_speed", 1, &"", 0.03, 0.15, 0.01, [S.WEAPON, S.GLOVES, S.RING]],
	[&"affix_crit_chance", &"crit_chance", 0, &"", 0.02, 0.08, 0.01, [S.WEAPON, S.GLOVES, S.RING, S.AMULET]],
	[&"affix_crit_damage", &"crit_damage", 0, &"", 0.08, 0.35, 0.01, [S.WEAPON, S.AMULET]],
	[&"affix_armor", &"armor", 0, &"", 4.0, 20.0, 1.0, [S.HELM, S.CHEST, S.GLOVES, S.BOOTS]],
	[&"affix_magic_resist", &"magic_resist", 0, &"", 4.0, 20.0, 1.0, [S.HELM, S.CHEST, S.BOOTS, S.AMULET]],
	[&"affix_move_speed", &"move_speed", 1, &"", 0.02, 0.08, 0.01, [S.BOOTS]],
	[&"affix_ability_haste", &"ability_haste", 0, &"", 3.0, 15.0, 1.0, [S.HELM, S.RING, S.AMULET]],
	[&"affix_tenacity", &"tenacity", 0, &"", 0.04, 0.15, 0.01, [S.HELM, S.BOOTS]],
	[&"affix_damage", &"damage_increase", 0, &"", 0.03, 0.12, 0.01, [S.WEAPON, S.RING, S.AMULET]],
	[&"affix_core_damage", &"damage_increase", 0, &"hit:core", 0.06, 0.25, 0.01, [S.WEAPON, S.GLOVES, S.AMULET]],
	[&"affix_basic_attack_damage", &"damage_increase", 0, &"hit:basic_attack", 0.06, 0.25, 0.01, [S.WEAPON, S.GLOVES, S.RING]],
	[&"affix_mobility_cooldown", &"cooldown", 1, &"tag:mobility", -0.04, -0.15, 0.01, [S.BOOTS]],
	[&"affix_magic_find", &"magic_find", 0, &"", 0.05, 0.25, 0.01, [S.HELM, S.RING, S.AMULET]],
]

var _passed: int = 0
var _failed: int = 0
var _table: LootTable


func _ready() -> void:
	print("\n=== Loot test (LOOT L1) ===")
	_table = LootTable.get_default()
	_test_rarities()
	_test_bases()
	_test_affixes()
	_test_drop_tables()
	_test_validation_default()
	_test_validation_affixes()
	_test_validation_table()
	_test_validation_drop_tables()
	_test_validation_sigils()
	_test_weights_formula()
	_test_rarity_shares()
	_test_drop_chance()
	_test_item_rolls()
	_test_fixed_band()
	_test_item_values()
	await _test_modifiers_on_stats_component()
	_test_tooltip_lines()
	_test_round_trip()
	_test_drop_table_by_unit()
	print("=== %d passed, %d failed ===\n" % [_passed, _failed])

	if DisplayServer.get_name() == "headless":
		get_tree().quit(_failed)


# --- Data ---------------------------------------------------------------------

func _test_rarities() -> void:
	_section("The rarity ladder (LootTable.rarities)")
	_check("the default table loads", _table != null, true)
	_check("7 rarities", _table.rarities.size(), 7)
	for i in RARITY_ROWS.size():
		var row: Array = RARITY_ROWS[i]
		var def := _table.get_rarity(i as Item.Rarity)
		var got := [def.rarity, def.display_name, def.affix_count, def.roll_min, def.roll_max,
			def.sigil_count, def.is_named, def.magic_find_effect, def.color.to_html(false)]
		var want := [i, row[0], row[1], row[2], row[3], row[4], row[5], row[6], row[7]]
		_check("%s: rarity, name, affixes, band, sigils, named, magic find, color" % row[0], _same_list(got, want), true)
	var unique := _table.get_rarity(R.UNIQUE)
	var exotic := _table.get_rarity(R.EXOTIC)
	_check("Exotic's stats equal Unique's (count and band; Ryan, 2026-10-01)",
		[exotic.affix_count, exotic.roll_min, exotic.roll_max], [unique.affix_count, unique.roll_min, unique.roll_max])
	_check("Exotic has one more sigil than Unique", exotic.sigil_count - unique.sigil_count, 1)
	var fixed: Array = []
	for def in _table.rarities:
		fixed.append(def.has_fixed_roll())
	_check("only the Artifact's band is fixed", fixed, [false, false, false, false, false, false, true])
	_check("the sigil pool is empty until L4", _table.sigils.size(), 0)


func _test_bases() -> void:
	_section("Item bases")
	_check("7 bases", _table.item_bases.size(), 7)
	for row: Array in BASE_ROWS:
		var base := _table.get_base(row[0])
		if base == null:
			_report(false, "base %s exists" % row[0], "missing")
			continue
		var implicit: Array = []
		for mod in base.implicits:
			implicit = [mod.stat, mod.type, mod.value]
		_check("%s: name, slot, implicit" % row[0], _same_list([base.display_name, base.slot, base.implicits.size()] + implicit,
			[row[1], row[2], 1 if not (row[3] as Array).is_empty() else 0] + row[3]), true)
	for slot: int in S.values():
		_check("one base for the %s slot" % Item.get_slot_name(slot as Item.Slot), _table.get_bases_for(slot).size(), 1)


func _test_affixes() -> void:
	_section("The affix pool")
	_check("15 affixes", _table.affixes.size(), 15)
	for row: Array in AFFIX_ROWS:
		var a := _table.get_affix(row[0])
		if a == null:
			_report(false, "affix %s exists" % row[0], "missing")
			continue
		var got := [a.stat, a.type, a.scope, a.min_value, a.max_value, a.step, _plain(a.slots)]
		var want := [row[1], row[2], row[3], row[4], row[5], row[6], row[7]]
		_check("%s: stat, type, scope, range, step, slots" % row[0], _same_list(got, want), true)
	var sizes: Array = []
	for slot: int in S.values():
		sizes.append(_table.get_affixes_for(slot as Item.Slot).size())
	_check("affixes per slot (weapon, helm, chest, gloves, boots, ring, amulet)", sizes, [7, 6, 3, 6, 6, 8, 9])


func _test_drop_tables() -> void:
	_section("Drop tables")
	_check("regular: chance, per depth, count", [REGULAR.item_chance, REGULAR.chance_per_depth, REGULAR.item_count], [0.1, 0.05, 1])
	_check("regular: weights", _same_list(REGULAR.rarity_weights, [59.5, 26.0, 11.0, 2.0, 0.8, 0.6, 0.1]), true)
	_check("elite: chance, per depth, count", [ELITE.item_chance, ELITE.chance_per_depth, ELITE.item_count], [1.0, 0.0, 1])
	_check("elite: weights", _same_list(ELITE.rarity_weights, [0.0, 36.0, 40.0, 10.0, 7.0, 6.0, 1.0]), true)
	var growth := [0.0, 0.05, 0.1, 0.15, 0.2, 0.2, 0.25]
	_check("both: growth per depth", _same_list(REGULAR.rarity_growth, growth) and _same_list(ELITE.rarity_growth, growth), true)
	_check_near("regular's weights sum to 100", _sum(REGULAR.rarity_weights), 100.0, 0.0001)
	_check_near("elite's weights sum to 100", _sum(ELITE.rarity_weights), 100.0, 0.0001)
	_check("default drop table is the regular one", _table.default_drop_table == REGULAR, true)


# --- Validation ---------------------------------------------------------------

func _test_validation_default() -> void:
	_section("Validation: the shipped data")
	var errors := _table.get_validation_errors()
	_check("the default LootTable is valid", errors, PackedStringArray())
	for row: Array in AFFIX_ROWS:
		_check("%s is valid" % row[0], _table.get_affix(row[0]).get_validation_error(), "")


func _test_validation_affixes() -> void:
	_section("Validation: affixes")
	_check_error("an unknown stat", _affix(&"not_a_stat").get_validation_error(), "unknown stat")
	_check_error("an ability: scope", _affix(&"cast_range", &"ability:knight_lunge").get_validation_error(), "ability: scope")
	_check_error("a tag: scope on a param not every ability has", _affix(&"radius", &"tag:area").get_validation_error(), "isn't a number param")
	_check_error("an unknown scope kind", _affix(&"armor", &"slot:helm").get_validation_error(), "unknown scope")
	_check("a tag: scope on a base param (cooldown) is fine", _affix(&"cooldown", &"tag:core").get_validation_error(), "")
	_check("a hit: scope on a stat is fine", _affix(&"damage_increase", &"hit:core").get_validation_error(), "")
	_check("a target: scope on a stat is fine", _affix(&"damage_increase", &"target:burning").get_validation_error(), "")
	var no_id := _affix(&"armor")
	no_id.id = &""
	_check_error("no id", no_id.get_validation_error(), "no id")
	var bad_step := _affix(&"armor")
	bad_step.step = -1.0
	_check_error("a step below 0", bad_step.get_validation_error(), "step")
	var base := ItemBase.new()
	base.id = &"item_base_test"
	base.implicits = [StatModifier.create(&"cast_range", StatModifier.Type.FLAT, 50.0, &"", &"ability:knight_lunge")]
	_check_error("an item base with an ability:-scoped implicit", base.get_validation_error(), "ability: scope")
	base.id = &""
	_check_error("an item base with no id", base.get_validation_error(), "no id")


func _test_validation_table() -> void:
	_section("Validation: the table")
	var t := _copy_table()
	var orphan := _affix(&"armor")
	t.affixes.append(orphan)
	_check_error("an affix that rolls on no slot", _join(t.get_validation_errors()), "rolls on no slot")
	t = _copy_table()
	t.affixes.append(_table.affixes[0])
	_check_error("two affixes with one id", _join(t.get_validation_errors()), "two affixes")
	t = _copy_table()
	t.affixes.append(_affix(&"cast_range", &"ability:knight_lunge", [S.WEAPON]))
	_check_error("an ability:-scoped affix in the pool", _join(t.get_validation_errors()), "ability: scope")
	t = _copy_table()
	t.rarities.remove_at(6)
	_check_error("6 rarities", _join(t.get_validation_errors()), "needs 7 rarities")
	t = _copy_table()
	var first := t.rarities[0]
	t.rarities[0] = t.rarities[1]
	t.rarities[1] = first
	_check_error("rarities out of order", _join(t.get_validation_errors()), "order")
	t = _copy_table()
	var wide: ItemRarity = t.rarities[2].duplicate()
	wide.roll_max = 1.2
	t.rarities[2] = wide
	_check_error("a band past 1", _join(t.get_validation_errors()), "band")
	t = _copy_table()
	var flipped: ItemRarity = t.rarities[2].duplicate()
	flipped.roll_min = 0.7
	t.rarities[2] = flipped
	_check_error("a band whose low end is above its high end", _join(t.get_validation_errors()), "band")
	t = _copy_table()
	var named: ItemRarity = t.rarities[5].duplicate()
	named.affix_count = 2
	t.rarities[5] = named
	_check_error("a named rarity with random affixes", _join(t.get_validation_errors()), "named rarity")
	t = _copy_table()
	t.item_bases.remove_at(6)
	_check_error("a slot with no base", _join(t.get_validation_errors()), "no item base for the Amulet slot")
	t = _copy_table()
	t.item_bases.append(_table.item_bases[0])
	_check_error("two bases with one id", _join(t.get_validation_errors()), "two item bases")
	t = _copy_table()
	var greedy: ItemRarity = t.rarities[2].duplicate()
	greedy.affix_count = 4
	t.rarities[2] = greedy
	_check_error("a rarity rolling more affixes than the chest offers (3)", _join(t.get_validation_errors()), "the Chest slot has 3 affixes")
	t = _copy_table()
	t.default_drop_table = null
	_check_error("no default drop table", _join(t.get_validation_errors()), "no default_drop_table")


func _test_validation_drop_tables() -> void:
	_section("Validation: drop tables")
	_check("regular is valid", REGULAR.get_validation_errors(), PackedStringArray())
	_check("elite is valid", ELITE.get_validation_errors(), PackedStringArray())
	var d: DropTable = REGULAR.duplicate()
	d.rarity_weights = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
	_check_error("6 weights", _join(d.get_validation_errors()), "needs 7")
	d = REGULAR.duplicate()
	d.rarity_weights = [-1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
	_check_error("a negative weight", _join(d.get_validation_errors()), "weight below 0")
	d = REGULAR.duplicate()
	d.rarity_weights = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	_check_error("weights summing to 0", _join(d.get_validation_errors()), "sum to 0")
	d = REGULAR.duplicate()
	d.item_count = 0
	_check_error("item_count 0", _join(d.get_validation_errors()), "item_count")
	d = REGULAR.duplicate()
	d.rarity_growth = [0.0, -0.1, 0.0, 0.0, 0.0, 0.0, 0.0]
	_check_error("a negative growth", _join(d.get_validation_errors()), "growth below 0")
	var t := _copy_table()
	var broken: DropTable = REGULAR.duplicate()
	broken.item_count = 0
	t.drop_table_by_unit[&"slime"] = broken
	_check_error("the table checks its drop tables", _join(t.get_validation_errors()), "item_count")


func _test_validation_sigils() -> void:
	_section("Validation: the sigil pool (checked now, filled in L4)")
	var t := _copy_table()
	t.sigils = [_sigil(&"sigil_a"), _sigil(&"sigil_b")]
	_check("two EVENT sigils with one rule each are valid", t.get_validation_errors(), PackedStringArray())
	t.sigils = [_sigil(&"sigil_a")]
	_check_error("one sigil for an Exotic's two", _join(t.get_validation_errors()), "fewer than the 2")
	t.sigils = [AUGMENT_LUNGE_STUNS, _sigil(&"sigil_b")]
	var errors := _join(t.get_validation_errors())
	_check_error("a FLAG augment as a sigil", errors, "EVENT augment")
	_check_error("an ability:-scoped sigil", errors, "scope must be empty or tag:")
	_check_error("a sigil id without sigil_", errors, "must start with sigil_")
	var tagged := _sigil(&"sigil_t")
	tagged.scope = &"tag:core"
	t.sigils = [tagged, _sigil(&"sigil_b")]
	_check("a tag:-scoped sigil is fine", t.get_validation_errors(), PackedStringArray())
	var two_rules := _sigil(&"sigil_c")
	two_rules.rules = [ReactionRule.new(), ReactionRule.new()]
	t.sigils = [two_rules, _sigil(&"sigil_b")]
	_check_error("a sigil with two rules", _join(t.get_validation_errors()), "exactly one reaction rule")
	t.sigils = [_sigil(&"sigil_b"), _sigil(&"sigil_b")]
	_check_error("two sigils with one id", _join(t.get_validation_errors()), "two sigils")
	_check("Judgement's reset (an ability-scoped EVENT) can't be a sigil",
		_join(_table_with_sigils([AUGMENT_JUDGEMENT_RESET, _sigil(&"sigil_b")]).get_validation_errors()).contains("scope must be empty or tag:"), true)


# --- Formulas -----------------------------------------------------------------

func _test_weights_formula() -> void:
	_section("Weights and chance (LOOT.md, Drops)")
	_check("regular, depth 1, no magic find: the table's weights", _same_list(REGULAR.get_weights(1, 0.0, _table), REGULAR.rarity_weights), true)
	# weight x (1 + growth x (depth - 1)): depth 5 is 4 steps.
	_check("regular, depth 5", _same_list(REGULAR.get_weights(5, 0.0, _table), [59.5, 26.0 * 1.2, 11.0 * 1.4, 2.0 * 1.6, 0.8 * 1.8, 0.6 * 1.8, 0.1 * 2.0]), true)
	# x (1 + magic find x effect): Common 0, Uncommon–Exotic 1, Legendary / Artifact 0.5.
	_check("regular, depth 1, +50% magic find", _same_list(REGULAR.get_weights(1, 0.5, _table), [59.5, 26.0 * 1.5, 11.0 * 1.5, 2.0 * 1.5, 0.8 * 1.5, 0.6 * 1.25, 0.1 * 1.25]), true)
	_check("depth and magic find multiply", _same_list(ELITE.get_weights(3, 1.0, _table), [0.0, 36.0 * 1.1 * 2.0, 40.0 * 1.2 * 2.0, 10.0 * 1.3 * 2.0, 7.0 * 1.4 * 2.0, 6.0 * 1.4 * 1.5, 1.0 * 1.5 * 1.5]), true)
	_check("depth 0 counts as 1", _same_list(REGULAR.get_weights(0, 0.0, _table), REGULAR.rarity_weights), true)
	_check("negative magic find counts as 0", _same_list(REGULAR.get_weights(1, -2.0, _table), REGULAR.rarity_weights), true)
	_check_near("regular chance at depth 1", REGULAR.get_chance(1), 0.1, 0.000001)
	_check_near("regular chance at depth 5 (x 1.2)", REGULAR.get_chance(5), 0.12, 0.000001)
	_check_near("elite chance at depth 9", ELITE.get_chance(9), 1.0, 0.000001)
	var steep: DropTable = REGULAR.duplicate()
	steep.item_chance = 0.9
	steep.chance_per_depth = 1.0
	_check_near("the chance never passes 1", steep.get_chance(5), 1.0, 0.000001)


func _test_rarity_shares() -> void:
	_section("Rarity shares over %d seeded rolls (within 1 point and 4 sigma)" % ROLLS)
	var regular_1 := _shares(REGULAR, 1, 0.0, 101)
	_check_shares("regular, depth 1", regular_1, REGULAR.get_weights(1, 0.0, _table))
	var elite_1 := _shares(ELITE, 1, 0.0, 202)
	_check_shares("elite, depth 1", elite_1, ELITE.get_weights(1, 0.0, _table))
	var regular_5 := _shares(REGULAR, 5, 0.0, 303)
	_check_shares("regular, depth 5", regular_5, REGULAR.get_weights(5, 0.0, _table))
	var regular_mf := _shares(REGULAR, 1, 1.0, 404)
	_check_shares("regular, depth 1, +100% magic find", regular_mf, REGULAR.get_weights(1, 1.0, _table))
	_check("depth 5 drops more Legendaries than depth 1", regular_5[R.LEGENDARY] > regular_1[R.LEGENDARY], true)
	_check("depth 5 drops fewer Commons than depth 1", regular_5[R.COMMON] < regular_1[R.COMMON], true)
	_check("magic find lowers Common's share", regular_mf[R.COMMON] < regular_1[R.COMMON], true)
	_check("magic find raises Rare's share", regular_mf[R.RARE] > regular_1[R.RARE], true)
	_check("the elite never drops a Common", elite_1[R.COMMON], 0.0)
	# Against TALENTS' assumed run: 96 regular kills (10% drop) and 4 elites.
	var per_run: Array = []
	for r in 7:
		per_run.append(snappedf(96.0 * 0.1 * regular_1[r] + 4.0 * elite_1[r], 0.01))
	print("     measured items per assumed run (C/U/R/Un/Ex/L/A): %s" % [per_run])
	_check_near("about 0.3 Legendary rolls per assumed run (LOOT.md)", per_run[R.LEGENDARY], 0.298, 0.03)
	_check_near("about 0.05 Artifact rolls per assumed run (LOOT.md)", per_run[R.ARTIFACT], 0.0496, 0.01)


func _test_drop_chance() -> void:
	_section("roll_drop(): how often a kill drops")
	var rng := _rng(1)
	var drops := 0
	var sizes_ok := true
	var n := ROLLS
	for i in n:
		var items := ItemRoller.roll_drop(REGULAR, 1, 0.0, null, _table, rng)
		if not items.is_empty():
			drops += 1
			sizes_ok = sizes_ok and items.size() == 1
	_check_rate("a slime drops 10% of the time", drops, n, 0.1)
	_check("a drop is one item", sizes_ok, true)
	drops = 0
	for i in n:
		if not ItemRoller.roll_drop(REGULAR, 5, 0.0, null, _table, rng).is_empty():
			drops += 1
	_check_rate("at depth 5, 12% of the time", drops, n, 0.12)
	var always := true
	for i in 2000:
		always = always and ItemRoller.roll_drop(ELITE, 1, 0.0, null, _table, rng).size() == 1
	_check("the elite always drops one item", always, true)
	var never: DropTable = REGULAR.duplicate()
	never.item_chance = 0.0
	var none := true
	for i in 2000:
		none = none and ItemRoller.roll_drop(never, 1, 0.0, null, _table, rng).is_empty()
	_check("a 0% table never drops", none, true)
	var pair: DropTable = ELITE.duplicate()
	pair.item_count = 2
	_check("item_count 2 gives two items", ItemRoller.roll_drop(pair, 1, 0.0, null, _table, rng).size(), 2)


# --- Items --------------------------------------------------------------------

func _test_item_rolls() -> void:
	_section("Rolled items")
	var rng := _rng(606)
	var seen_bases := {}
	var seen_pairs := {}   # "<affix id>/<slot>"
	for r in [R.COMMON, R.UNCOMMON, R.RARE, R.UNIQUE, R.EXOTIC]:
		var def := _table.get_rarity(r)
		var counts_ok := true
		var distinct_ok := true
		var slots_ok := true
		var band_ok := true
		var step_ok := true
		var other_ok := true
		var detail := ""
		for i in 4000:
			var item := ItemRoller.roll_item(r, null, _table, rng)
			seen_bases[item.base.id] = true
			other_ok = other_ok and item.rarity == r and item.uid == 0 and item.sigils.is_empty()
			counts_ok = counts_ok and item.affix_rolls.size() == def.affix_count
			var ids := {}
			for k in item.affix_rolls.size():
				var affix: Affix = item.affix_rolls[k][0]
				distinct_ok = distinct_ok and not ids.has(affix.id)
				ids[affix.id] = true
				slots_ok = slots_ok and affix.slots.has(item.base.slot)
				seen_pairs["%s/%d" % [affix.id, item.base.slot]] = true
				var value := item.get_affix_value(k, _table)
				var span := affix.get_band_range(def.roll_min, def.roll_max)
				if value < span.x - affix.step * 0.5 - 0.000001 or value > span.y + affix.step * 0.5 + 0.000001:
					band_ok = false
					detail = "%s %s outside %s" % [affix.id, value, span]
				step_ok = step_ok and is_equal_approx(value / affix.step, roundf(value / affix.step))
		var label := def.display_name
		_check("%s: %d affixes on every item" % [label, def.affix_count], counts_ok, true)
		_check("%s: never the same affix twice" % label, distinct_ok, true)
		_check("%s: only affixes the slot allows" % label, slots_ok, true)
		_report(band_ok, "%s: every value inside its band (%s–%s) of its range" % [label, def.roll_min, def.roll_max], detail)
		_check("%s: every value a multiple of its step" % label, step_ok, true)
		_check("%s: rarity kept, uid 0, no sigils (L4)" % label, other_ok, true)
	_check("every base was rolled", seen_bases.size(), 7)
	var pairs := 0
	for row: Array in AFFIX_ROWS:
		pairs += (row[7] as Array).size()
	_check("every affix rolled on every slot it allows (%d pairs)" % pairs, seen_pairs.size(), pairs)
	for r in [R.LEGENDARY, R.ARTIFACT]:
		var item := ItemRoller.roll_item(r, null, _table, rng)
		_check("%s falls back to Exotic until L5" % _table.get_rarity(r).display_name,
			[item.rarity, item.affix_rolls.size()], [R.EXOTIC, 3])
	var boots_only := true
	var boots_pool := _table.get_affixes_for(S.BOOTS)
	for i in 500:
		var item := ItemRoller.roll_item(R.RARE, null, _table, rng, S.BOOTS)
		boots_only = boots_only and item.base.slot == S.BOOTS
		for pair: Array in item.affix_rolls:
			boots_only = boots_only and boots_pool.has(pair[0])
	_check("a slot filter rolls only that slot's base and affixes", boots_only, true)
	var a := _rng(77)
	var b := _rng(77)
	var same := true
	for i in 50:
		same = same and ItemRoller.roll_item(R.EXOTIC, null, _table, a).to_dict() == ItemRoller.roll_item(R.EXOTIC, null, _table, b).to_dict()
	_check("the same seed rolls the same items", same, true)


func _test_fixed_band() -> void:
	_section("The Artifact's band: always the maximum, no draw")
	var rng := _rng(808)
	var before := rng.state
	var roll := ItemRoller.roll_in_band(_table.get_rarity(R.ARTIFACT), rng)
	_check("an Artifact roll is 1.0", roll, 1.0)
	_check("and draws no random number", rng.state == before, true)
	ItemRoller.roll_in_band(_table.get_rarity(R.LEGENDARY), rng)
	_check("a Legendary roll draws one", rng.state != before, true)
	var maxed := true
	for affix in _table.affixes:
		for r in [0.0, 0.37, 1.0]:
			maxed = maxed and is_equal_approx(affix.get_value(1.0, 1.0, r), snappedf(affix.max_value, affix.step))
	_check("every affix in the Artifact's band is its maximum, whatever the roll", maxed, true)


func _test_item_values() -> void:
	_section("An item's values and modifiers")
	var item := _manual_item()
	var mods := item.get_modifiers(_table)
	_check("source id", item.get_source_id(), &"item_42")
	_check("slot", item.get_slot(), S.WEAPON)
	_check("an implicit and three affixes", mods.size(), 4)
	var rows: Array = []
	for mod in mods:
		rows.append([mod.stat, mod.type, snappedf(mod.value, 0.0001), mod.scope, mod.source_id])
	# Rare band 0.25–0.65. AD roll 0.5 -> t 0.45 -> 2 + 8 x 0.45 = 5.6 -> 6.
	# Crit roll 1 -> t 0.65 -> 0.059 -> 0.06. Core roll 0 -> t 0.25 -> 0.1075 -> 0.11.
	_check("the modifiers (implicit, then affixes in their rolled order)", _same_list(rows, [
		[&"attack_damage", StatModifier.Type.FLAT, 6.0, &"", &"item_42"],
		[&"attack_damage", StatModifier.Type.FLAT, 6.0, &"", &"item_42"],
		[&"crit_chance", StatModifier.Type.FLAT, 0.06, &"", &"item_42"],
		[&"damage_increase", StatModifier.Type.FLAT, 0.11, &"hit:core", &"item_42"],
	]), true)
	var base_mod: StatModifier = item.base.implicits[0]
	_check("the implicit is a copy (the base's own is untouched)", mods[0] != base_mod and base_mod.source_id == &"", true)
	_check("no augments (no sigils yet)", item.get_augments().size(), 0)
	_check("fits any champion", item.get_champion_id(), &"")
	# The roll is saved, not the value: a retune reaches an item already owned.
	var retuned: Affix = _table.get_affix(&"affix_attack_damage").duplicate()
	var owned := Item.new()
	owned.rarity = R.RARE
	owned.base = item.base
	owned.affix_rolls = [[retuned, 0.5]]
	var was := owned.get_affix_value(0, _table)
	retuned.max_value = 20.0
	# Max 10 -> 20: 2 + 18 x 0.45 = 10.1 -> 10.
	_check("a retuned range changes an owned item's value (6 -> 10)", [was, owned.get_affix_value(0, _table)], [6.0, 10.0])


func _test_modifiers_on_stats_component() -> void:
	_section("Every affix's modifier on a real StatsComponent")
	var stats: StatsComponent = StatsComponent.new()
	add_child(stats)
	stats.setup(KNIGHT_STATS)
	var before := _all_values(stats)
	var cooldown_before := stats.get_ability_param(LUNGE, &"cooldown")
	var cleave_before := stats.get_ability_param(CLEAVE, &"cooldown")
	var accepted := true
	var uid := 100
	for affix in _table.affixes:
		uid += 1
		var item := Item.new()
		item.uid = uid
		item.rarity = R.RARE
		item.base = _table.get_bases_for(affix.slots[0])[0]
		item.affix_rolls = [[affix, 0.5]]
		var mods := item.get_modifiers(_table)
		stats.add_modifiers(mods)
		accepted = accepted and stats.get_modifiers_from(item.get_source_id()).size() == mods.size()
	_check("all 15 affixes (and their bases' implicits) are accepted", accepted, true)
	_check("the mobility cooldown affix shortens Lunge's cooldown", stats.get_ability_param(LUNGE, &"cooldown") < cooldown_before, true)
	_check("and not Cleave's", stats.get_ability_param(CLEAVE, &"cooldown"), cleave_before)
	_check("the core damage affix counts only for core hits", [stats.get_scoped_stat(&"damage_increase", [&"hit:core"]) > stats.get_stat(&"damage_increase")], [true])
	_check("move speed went up", stats.get_stat(&"move_speed") > before[&"move_speed"], true)
	for i in range(101, uid + 1):
		stats.remove_modifiers_from(StringName("item_%d" % i))
	_check("removing every item restores every stat exactly", _all_values(stats), before)
	_check("and Lunge's cooldown", stats.get_ability_param(LUNGE, &"cooldown"), cooldown_before)
	stats.queue_free()
	await get_tree().physics_frame


func _test_tooltip_lines() -> void:
	_section("Tooltip lines")
	_check("a Rare Longsword", _plain(_manual_item().get_tooltip_lines(_table)),
		["Longsword", "Rare Weapon", "+6 Attack Damage", "+6 Attack Damage", "+6% Crit Chance", "+11% damage with core abilities"])
	var cases := [
		[&"affix_max_health", 40.0, "+40 Max Health"],
		[&"affix_attack_speed", 0.08, "+8% Attack Speed"],
		[&"affix_crit_chance", 0.05, "+5% Crit Chance"],
		[&"affix_crit_damage", 0.2, "+20% Crit Damage"],
		[&"affix_armor", 12.0, "+12 Armor"],
		[&"affix_magic_resist", 7.0, "+7 Magic Resist"],
		[&"affix_move_speed", 0.03, "+3% Move Speed"],
		[&"affix_ability_haste", 8.0, "+8 Ability Haste"],
		[&"affix_tenacity", 0.1, "+10% Tenacity"],
		[&"affix_damage", 0.05, "+5% damage"],
		[&"affix_basic_attack_damage", 0.12, "+12% basic attack damage"],
		[&"affix_mobility_cooldown", -0.1, "-10% cooldown on mobility abilities"],
		[&"affix_magic_find", 0.15, "+15% Magic Find"],
	]
	for c: Array in cases:
		_check("%s at %s" % [c[0], c[1]], _table.get_affix(c[0]).get_line(c[1]), c[2])
	_check("an implicit (gloves)", Affix.describe(&"attack_speed", StatModifier.Type.PERCENT_ADD, 0.05), "+5% Attack Speed")
	_check("a \"more\" modifier", Affix.describe(&"attack_damage", StatModifier.Type.PERCENT_MULT, 0.1), "+10% more Attack Damage")
	_check("an Exotic Band's second line names its rarity and slot",
		ItemRoller.roll_item(R.EXOTIC, null, _table, _rng(9), S.RING).get_tooltip_lines(_table)[1], "Exotic Ring")


func _test_round_trip() -> void:
	_section("to_dict() / from_dict()")
	var rng := _rng(909)
	var same := true
	var through_text := true
	var mods_same := true
	var four_decimals := true
	var saved: Array = []
	var items: Array[Item] = []
	for i in 300:
		var item := ItemRoller.roll_item((i % 5) as Item.Rarity, null, _table, rng)
		item.uid = i + 1
		items.append(item)
		for pair: Array in item.affix_rolls:
			four_decimals = four_decimals and is_equal_approx(pair[1] * 10000.0, roundf(pair[1] * 10000.0))
		var d := item.to_dict()
		saved.append(d)
		var back := Item.from_dict(d, _table)
		same = same and back != null and back.to_dict() == d
		mods_same = mods_same and back != null and _mod_rows(back) == _mod_rows(item)
		var reread: Variant = str_to_var(var_to_str(d))
		var again := Item.from_dict(reread, _table)
		through_text = through_text and again != null and again.to_dict() == d
	_check("rolls are kept to 4 decimals", four_decimals, true)
	_check("300 items survive the round trip", same, true)
	_check("with the same modifiers", mods_same, true)
	_check("and through var_to_str() / str_to_var()", through_text, true)
	# The way L2's inventory save will store them: a ConfigFile, as text.
	var cfg := ConfigFile.new()
	cfg.set_value("knight", "items", saved)
	var cfg2 := ConfigFile.new()
	cfg2.parse(cfg.encode_to_text())
	var loaded: Array = cfg2.get_value("knight", "items", [])
	var through_cfg := loaded.size() == items.size()
	for i in mini(loaded.size(), items.size()):
		var again := Item.from_dict(loaded[i], _table)
		through_cfg = through_cfg and again != null and again.to_dict() == saved[i] and _mod_rows(again) == _mod_rows(items[i])
	_check("and through a ConfigFile's text, values and all", through_cfg, true)
	var d := _manual_item().to_dict()
	_check("saved: uid, base id, rarity as a word, [affix id, roll] pairs, sigil ids", d, {
		"uid": 42, "base": "item_base_longsword", "rarity": "rare",
		"affixes": [["affix_attack_damage", 0.5], ["affix_crit_chance", 1.0], ["affix_core_damage", 0.0]],
		"sigils": [],
	})
	var unknown_base := d.duplicate(true)
	unknown_base["base"] = "item_base_gone"
	_check("an unknown base reads as null", Item.from_dict(unknown_base, _table) == null, true)
	var unknown_rarity := d.duplicate(true)
	unknown_rarity["rarity"] = "mythic"
	_check("an unknown rarity reads as null", Item.from_dict(unknown_rarity, _table) == null, true)
	var unknown_affix := d.duplicate(true)
	unknown_affix["affixes"][1] = ["affix_gone", 0.3]
	var kept := Item.from_dict(unknown_affix, _table)
	_check("an unknown affix drops that line only (expect a warning)", kept != null and kept.affix_rolls.size() == 2, true)
	var wild := d.duplicate(true)
	wild["affixes"] = [["affix_attack_damage", 1.7]]
	_check("a roll outside 0–1 is clamped", Item.from_dict(wild, _table).affix_rolls[0][1], 1.0)
	_check("rarity words", [Item.rarity_to_word(R.COMMON), Item.rarity_to_word(R.ARTIFACT), Item.word_to_rarity("exotic"), Item.word_to_rarity("nope")], ["common", "artifact", R.EXOTIC, -1])


func _test_drop_table_by_unit() -> void:
	_section("The drop table by unit (until ENEMIES_AI.md)")
	var slime: Unit = SLIME_SCENE.instantiate()
	var elite: Unit = SLIME_ELITE_SCENE.instantiate()
	var other: Unit = SLIME_SCENE.instantiate()
	other.stats = KNIGHT_STATS
	_check("a slime uses the regular table", _table.get_drop_table(slime) == REGULAR, true)
	_check("the elite uses the elite table", _table.get_drop_table(elite) == ELITE, true)
	_check("a unit not in the map uses the default", _table.get_drop_table(other) == REGULAR, true)
	_check("no unit: the default", _table.get_drop_table(null) == REGULAR, true)
	slime.free()
	elite.free()
	other.free()


# --- Helpers ------------------------------------------------------------------

## A Rare Longsword (uid 42): AD roll 0.5, crit chance roll 1.0, core damage roll 0.0.
func _manual_item() -> Item:
	var item := Item.new()
	item.uid = 42
	item.rarity = R.RARE
	item.base = _table.get_base(&"item_base_longsword")
	item.affix_rolls = [
		[_table.get_affix(&"affix_attack_damage"), 0.5],
		[_table.get_affix(&"affix_crit_chance"), 1.0],
		[_table.get_affix(&"affix_core_damage"), 0.0],
	]
	return item


func _affix(stat: StringName, scope: StringName = &"", slots: Array = []) -> Affix:
	var a := Affix.new()
	a.id = StringName("affix_test_%s" % stat)
	a.stat = stat
	a.scope = scope
	for s: int in slots:
		a.slots.append(s as Item.Slot)
	return a


func _sigil(id: StringName) -> AbilityAugment:
	var s := AbilityAugment.new()
	s.id = id
	s.kind = AbilityAugment.Kind.EVENT
	s.rules = [ReactionRule.new()]
	return s


func _table_with_sigils(sigils: Array) -> LootTable:
	var t := _copy_table()
	t.sigils.assign(sigils)
	return t


## A new table sharing the default's entries, with its own lists to change.
func _copy_table() -> LootTable:
	var t := LootTable.new()
	t.rarities = _table.rarities.duplicate()
	t.item_bases = _table.item_bases.duplicate()
	t.affixes = _table.affixes.duplicate()
	t.sigils = _table.sigils.duplicate()
	t.drop_table_by_unit = _table.drop_table_by_unit.duplicate()
	t.default_drop_table = _table.default_drop_table
	return t


func _shares(table: DropTable, depth: int, magic_find: float, seed_value: int) -> Array[float]:
	var rng := _rng(seed_value)
	var counts: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for i in ROLLS:
		counts[ItemRoller.roll_rarity(table, depth, magic_find, rng, _table)] += 1.0
	for r in 7:
		counts[r] /= float(ROLLS)
	return counts


## Each share within 1 percentage point of its weight's share (LOOT L1's
## Done means) and within 4 sigma of it (much tighter for the rare tiers).
func _check_shares(label: String, shares: Array[float], weights: Array[float]) -> void:
	var total := _sum(weights)
	for r in 7:
		var p := weights[r] / total
		var sigma := sqrt(p * (1.0 - p) / float(ROLLS))
		var diff := absf(shares[r] - p)
		var ok := diff <= 0.01 and diff <= 4.0 * sigma + 0.0000001
		_report(ok, "%s: %s %.3f%% (expected %.3f%%)" % [label, _table.get_rarity(r as Item.Rarity).display_name, shares[r] * 100.0, p * 100.0],
			"off by %.4f points, 4 sigma = %.4f" % [diff * 100.0, 4.0 * sigma * 100.0])


func _check_rate(label: String, hits: int, n: int, p: float) -> void:
	var rate := float(hits) / float(n)
	var sigma := sqrt(p * (1.0 - p) / float(n))
	_report(absf(rate - p) <= 4.0 * sigma, "%s (got %.2f%%)" % [label, rate * 100.0], "expected %.2f%% ± %.2f" % [p * 100.0, 4.0 * sigma * 100.0])


func _mod_rows(item: Item) -> Array:
	var rows: Array = []
	for mod in item.get_modifiers(_table):
		rows.append([mod.stat, mod.type, mod.value, mod.scope, mod.source_id])
	return rows


func _all_values(stats: StatsComponent) -> Dictionary:
	var out := {}
	for key in stats.registry.get_keys():
		out[key] = stats.get_stat(key)
	return out


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _sum(values: Array) -> float:
	var total := 0.0
	for v in values:
		total += float(v)
	return total


func _join(errors: PackedStringArray) -> String:
	return " | ".join(errors)


## Element-wise equality, floats approximately.
func _same_list(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for i in actual.size():
		var a: Variant = actual[i]
		var e: Variant = expected[i]
		if a is float or e is float:
			if not is_equal_approx(float(a), float(e)):
				return false
		elif a is Array and e is Array:
			if not _same_list(a, e):
				return false
		elif a != e:
			return false
	return true


## A typed array as a plain one (typed and untyped arrays never compare equal).
func _plain(a: Variant) -> Array:
	var out := []
	for x: Variant in a:
		out.append(x)
	return out


func _section(title: String) -> void:
	print("-- %s" % title)


func _check_error(label: String, errors: String, needle: String) -> void:
	_report(errors.contains(needle), "caught: %s" % label, "errors: '%s', looking for '%s'" % [errors, needle])


func _check_near(label: String, actual: float, expected: float, tolerance: float) -> void:
	_report(absf(actual - expected) <= tolerance, label, "got %s, expected %s ± %s" % [actual, expected, tolerance])


func _check(label: String, actual: Variant, expected: Variant) -> void:
	var ok: bool
	if actual is float or expected is float:
		ok = is_equal_approx(float(actual), float(expected))
	elif actual is Array and expected is Array:
		ok = _plain(actual) == _plain(expected)
	else:
		ok = actual == expected
	_report(ok, label, "got %s, expected %s" % [actual, expected])


func _report(ok: bool, label: String, detail: String) -> void:
	if ok:
		_passed += 1
		print("  PASS  %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s  (%s)" % [label, detail])
