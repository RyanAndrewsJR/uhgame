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
## L2: equipping, the inventory and the save. The keep-current switch on
## HealthComponent and ResourceComponent; EquipmentComponent on the Knight
## (exact stats under item_<uid>, events, swaps, both ring slots, every
## can_equip() refusal, augments on and off, no heal from a live swap, a load
## that starts full); ChampionInventory (uids, the record, the save's round
## trip through a ConfigFile's text, unreadable entries kept raw, the empty
## materials bucket); the Loot autoload (the test-scene guard, the equip
## listener, a save to a scratch file, the real file untouched); the Player
## equipping its saved gear at load.
## L3: SandboxLoot. Room.depth and RoomLayout.depth (copied by build_sim()),
## Loot.get_depth(); SandboxLoot in both sandboxes; on a live Knight in a
## room: the list (header, rarity colors, ON, scrolling, the tooltip lines),
## J / Shift+J, U (equip, swap, unequip, rings), K (one roll at the room's
## depth with the Knight's magic find, into the inventory), P (the named items,
## since L5), [ / ] (depth, never below 1), the keys through the viewport; a
## respawned Knight wearing what was set; K and U saving at once (a scratch
## file).
## L4: sigils. The three sigil augments and their rules, status_bloodrush and
## status_exposed; Unique rolling one sigil and Exotic two different ones
## (3,000 each), the " of <suffix>" names, the sigil tooltip lines, the save
## keeping sigil ids. On a live Knight: Storm Strike's rate (x the proc
## coefficient; never from a proc hit or another unit's hit) and its bolt;
## Bloodrush on a kill (summed with Iron Resolve's haste, refreshed, one link
## into a chain but not two); Expose from the Knight's stun and slow and a
## real Judgement (x1.15 damage taken), not from Staggered or another unit's
## stun; the same sigil from two items as one; an Exotic's two both firing;
## unequipping removing each.
## L5: named items, part 1. The Knight's three (Tidebreaker, Oathbound Plate,
## Chains of Judgement) and their data, status_undying, the new FLAGs;
## NamedItem validation catching each broken rule; Legendary rolls from the
## Knight's list (a band, rolled), an Artifact at its maximum with no draw (a
## fixture until L6), the Exotic fallbacks; names, tooltips, the save by
## named id (the data wins); worn once, its champion's only. On a live
## Knight: Tidebreaker with every Cleave talent, Undying (Unit.on_hit()),
## Oathbound Plate with every W talent, Chains of Judgement's range (with Long
## Arm and Swift Verdict) and its drag (airborne, before the hit, over a fence
## and a ledge, stopped by a wall, none on an unstoppable target, Shockwave
## around the landing, Executioner).
## L6: named items, part 2. Homeward Greaves and The Last Verdict, their
## variants (Homeward Lunge, Judgement Leap) and data; Legendary rolls among
## four, the Artifact roll; CastContext.sequence shared by a sequence's parts.
## On a live Knight: the return (to the exact start, through a unit, hitting
## nothing, inside the window only, after walking away; the cooldown after
## the sequence) with Tackle, Twin Lunge (the recharge paused during a
## sequence), Long Lunge and Quick Footing; the leap (where aimed, 0.3 s,
## rooted for the 0.2 s crouch, airborne with no status and no i-frames, over
## a unit, a fence, a ledge, a wall and a pit; nothing interrupts it), its
## hits (the circle, in sight, each target's missing health, the stun, the
## Fury bonus spent once, Shockwave's ring, Executioner's reset on a kill,
## Long Arm and Swift Verdict), and in a Room with its navigation: the nearest
## walkable floor when aimed into a wall, a pit, a fence or past the edge.
## ABILITIES AB15: Homeward Greaves' return is a blink (at the start by the
## cast's 3 frames, never in between, over a wall; a rooted recast fails with
## its cue and the window keeps running); its Stagger line is Lunge's.
## L7: drops and pickups. Layer 9, pickup.tscn, the Knight's PickupComponent and
## pickup_radius, the sounds on the loot table; kills' rates (a slime 10%, at
## depth 5 12%, the elite always one item, magic find shifting only the
## rarities); the kill credit (the tracked player's last hit; not a dummy, the
## same team, another unit or no source; drops off by themselves in a test
## scene); the pop (12–28 px, collectable after 0.3 s, taken within two steps,
## the drop and pickup sounds, the save at once); walking through a drop with
## no stop; the radius following the stat, each Knight's own circle, a dead
## Knight taking nothing; landing spots by a wall, a fence, a ledge and a pit,
## walled in, a corpse over a pit (the room's navigation; push_out() outside a
## Room); ground drops taken and put back; the HUD's loot lines. K drops
## pickups at the Knight's feet (the L3 checks wait for them).
## L7b: dropping and trashing items, sorting. ChampionInventory.remove(), what
## can't leave (no item, a stranger, a worn item), what asks first (Unique and
## up); a drop out of the inventory and the save at once, held for the Knight
## while he stands by it, taken back when he walks away and returns (also when
## he walks off during the hop), a ground drop like any; a trash gone for
## good, the second press and every way it's cancelled; L, X and O through
## the viewport; the sorts (by slot, by rarity, a view only, the cursor kept);
## the hub's Clear inventory and its second click.
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
const SIGIL_STORM_STRIKE: AbilityAugment = preload("res://data/augments/augment_sigil_storm_strike.tres")
const SIGIL_BLOODRUSH: AbilityAugment = preload("res://data/augments/augment_sigil_bloodrush.tres")
const SIGIL_EXPOSE: AbilityAugment = preload("res://data/augments/augment_sigil_expose.tres")
const STATUS_BLOODRUSH: StatusEffect = preload("res://data/statuses/status_bloodrush.tres")
const STATUS_EXPOSED: StatusEffect = preload("res://data/statuses/status_exposed.tres")
const STATUS_STUN: StatusEffect = preload("res://data/statuses/status_stun.tres")
const STATUS_SLOW: StatusEffect = preload("res://data/statuses/status_slow.tres")
const STATUS_STAGGERED: StatusEffect = preload("res://data/statuses/status_staggered.tres")
const STATUS_UNDYING: StatusEffect = preload("res://data/statuses/status_undying.tres")
const STATUS_SHIELD: StatusEffect = preload("res://data/statuses/status_shield.tres")
const TIDEBREAKER: NamedItem = preload("res://data/items/item_knight_tidebreaker.tres")
const OATHBOUND_PLATE: NamedItem = preload("res://data/items/item_knight_oathbound_plate.tres")
const CHAINS_OF_JUDGEMENT: NamedItem = preload("res://data/items/item_knight_chains_of_judgement.tres")
const HOMEWARD_GREAVES: NamedItem = preload("res://data/items/item_knight_homeward_greaves.tres")
const LAST_VERDICT: NamedItem = preload("res://data/items/item_knight_last_verdict.tres")
const LUNGE_RETURN: Ability = preload("res://data/abilities/knight_e_lunge_return.tres")
const JUDGEMENT_LEAP: Ability = preload("res://data/abilities/knight_r_judgement_leap.tres")
const AUGMENT_LUNGE_RETURN: AbilityAugment = preload("res://data/augments/augment_lunge_return.tres")
const AUGMENT_JUDGEMENT_LEAP: AbilityAugment = preload("res://data/augments/augment_judgement_leap.tres")
const CLEAVE_WAVE: Ability = preload("res://data/abilities/knight_q_cleave_wave.tres")
const IRON_RESOLVE: Ability = preload("res://data/abilities/knight_w_iron_resolve.tres")
const JUDGEMENT: Ability = preload("res://data/abilities/knight_r_judgement.tres")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const KNIGHT: ChampionData = preload("res://data/champions/knight.tres")
const REAL_SAVE := "user://inventory.cfg"
const SCRATCH_SAVE := "user://loot_test_scratch.cfg"
const PICKUP_SCENE: PackedScene = preload("res://scenes/loot/pickup.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const SOUND_LOOT_DROP: SoundEvent = preload("res://data/sounds/sound_loot_drop.tres")
const SOUND_LOOT_DROP_LEGENDARY: SoundEvent = preload("res://data/sounds/sound_loot_drop_legendary.tres")
const SOUND_LOOT_PICKUP: SoundEvent = preload("res://data/sounds/sound_loot_pickup.tres")

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
var _next_x: float = 0.0
var _dummy_offset: float = 0.0
var _dummies: Array[Node] = []


## An item that belongs to another champion (named items come in L5).
class ForeignItem extends Item:
	func get_champion_id() -> StringName:
		return &"mage"


func _ready() -> void:
	print("\n=== Loot test (LOOT L1–L7b) ===")
	# First, before anything touches either autoload: a window's close request
	# saves, and Progress.save() once checked saving_enabled before its lazy
	# test-scene guard, so a windowed run closed before anything touched
	# Progress wrote an empty progress.cfg (2026-10-03, the L1 run; fixed in
	# L2). Checked against scratch files, never the real ones. Then latch both
	# guards off for the rest of the run.
	_section("Save guards: a close request comes first")
	_check_close_request(Progress, "Progress")
	_check_close_request(Loot, "Loot")
	Progress.get_progress(KNIGHT)
	Loot.get_inventory(KNIGHT)
	var real_before := _file_stamp(REAL_SAVE)
	var progress_before := _file_stamp("user://progress.cfg")
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
	# L2
	_test_gain_switch()
	await _test_equip_basics()
	await _test_swaps_and_rings()
	await _test_can_equip()
	await _test_equip_augments()
	await _test_no_heal()
	_test_inventory_record()
	_test_inventory_save()
	await _test_loot_autoload()
	await _test_player_loads_gear()
	# L3
	_test_room_depth()
	_test_sandbox_scenes()
	await _test_sandbox_loot()
	await _test_sandbox_loot_keys()
	await _test_sandbox_loot_saves()
	# L4
	_test_sigil_data()
	_test_sigil_rolls()
	await _test_storm_strike()
	await _test_bloodrush()
	await _test_expose()
	await _test_sigil_stacking()
	# L5
	_test_named_data()
	_test_named_validation()
	_test_named_rolls()
	await _test_named_items()
	await _test_tidebreaker()
	await _test_undying()
	await _test_oathbound_plate()
	await _test_chains_of_judgement()
	# L6
	_test_l6_data()
	await _test_homeward_greaves()
	await _test_homeward_blink()
	await _test_homeward_talents()
	await _test_last_verdict()
	await _test_leap_hits()
	await _test_leap_in_room()
	# L7
	_test_l7_data()
	await _test_drop_rates()
	await _test_kill_drops()
	await _test_pickup_pop()
	await _test_pickup_walk()
	await _test_pickup_radius()
	await _test_landing_terrain()
	await _test_drop_over_pit()
	await _test_ground_drops()
	await _test_hud_loot_line()
	# L7b
	await _test_l7b_rules()
	await _test_drop_item()
	await _test_trash_item()
	await _test_sort()
	await _test_hub_clear_inventory()
	Audio.stop_all()
	Loot.reset(KNIGHT)
	_check("the real inventory file was never written", _file_stamp(REAL_SAVE), real_before)
	_check("nor the real progress file", _file_stamp("user://progress.cfg"), progress_before)
	_check("both saves are off in this test scene", [Progress.saving_enabled, Loot.saving_enabled], [false, false])
	# A sound still playing at quit leaks its stream (L5: Judgement's hit):
	# stop them and let the players go, as abilities_test does.
	Audio.stop_all()
	await _frames(10)
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
	_check("the sigil pool (L4): Storm Strike, Bloodrush, Expose", _table.sigils, [SIGIL_STORM_STRIKE, SIGIL_BLOODRUSH, SIGIL_EXPOSE])


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
	_section("Validation: the sigil pool")
	var t := _copy_table()
	t.sigils = [_sigil(&"sigil_a"), _sigil(&"sigil_b")]
	_check("two EVENT sigils with one rule and a name suffix each are valid", t.get_validation_errors(), PackedStringArray())
	t.sigils = []
	_check("an empty pool is valid (Unique and Exotic roll without sigils)", t.get_validation_errors(), PackedStringArray())
	var nameless := _sigil(&"sigil_n")
	nameless.name_suffix = " "
	t.sigils = [nameless, _sigil(&"sigil_b")]
	_check_error("a sigil without a name suffix (L4)", _join(t.get_validation_errors()), "needs a name_suffix")
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
			other_ok = other_ok and item.rarity == r and item.uid == 0 and item.sigils.size() == def.sigil_count
			other_ok = other_ok and (item.sigils.size() < 2 or item.sigils[0] != item.sigils[1])
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
		_check("%s: rarity kept, uid 0, %d sigil(s), never the same twice" % [label, def.sigil_count], other_ok, true)
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
	_check("no augments (a Rare has no sigils)", item.get_augments().size(), 0)
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


# --- L2: equipping, the inventory, the save ----------------------------------

func _test_gain_switch() -> void:
	_section("L2: the keep-current switch (HealthComponent, ResourceComponent)")
	var hc := HealthComponent.new()
	add_child(hc)
	hc.setup(100.0)
	hc.take_damage(60.0)
	hc.set_max_health(150.0)
	_check("on (the default): a raised max adds to current (40 -> 90)", hc.current, 90.0)
	hc.set_gain_on_max_raise(false)
	hc.set_max_health(200.0)
	_check("off: a raised max leaves current (90)", hc.current, 90.0)
	hc.set_max_health(80.0)
	_check("off: a lowered max still clamps (80)", hc.current, 80.0)
	hc.set_gain_on_max_raise(true)
	hc.set_max_health(100.0)
	_check("back on: gains again (80 -> 100)", hc.current, 100.0)
	hc.free()
	var rc := ResourceComponent.new()
	add_child(rc)
	rc.setup(100.0)
	rc.try_spend(60.0)
	rc.set_max_resource(150.0)
	_check("resource, on: gains (40 -> 90)", rc.current, 90.0)
	rc.set_gain_on_max_raise(false)
	rc.set_max_resource(200.0)
	_check("resource, off: no gain (90)", rc.current, 90.0)
	rc.set_gain_on_max_raise(true)
	rc.set_max_resource(250.0)
	_check("resource, back on: gains (90 -> 140)", rc.current, 140.0)
	rc.free()


func _test_equip_basics() -> void:
	_section("L2: equipping and unequipping")
	Loot.reset(KNIGHT)
	var p := await _spawn_knight()
	_check("player.tscn has an EquipmentComponent", p.equipment != null, true)
	_check("8 equipment slots", EquipmentComponent.SLOTS.size(), 8)
	_check("an empty inventory: nothing worn at spawn", p.equipment.get_equipped().size(), 0)
	var before := _all_values(p.stats_component)
	var helm := _item(&"item_base_iron_helm", R.RARE, [[&"affix_max_health", 0.5], [&"affix_armor", 0.5], [&"affix_ability_haste", 0.5]], 7)
	var seen := _listen()
	_check("equip() succeeds", p.equipment.equip(helm), true)
	_check("it's in the helm slot", [p.equipment.get_item(&"helm") == helm, p.equipment.get_slot_of(helm)], [true, &"helm"])
	var mods := p.stats_component.get_modifiers_from(&"item_7")
	_check("its 4 modifiers (implicit + 3 affixes) are on, under item_7", mods.size(), 4)
	var expected := before.duplicate()
	for mod in helm.get_modifiers(_table):
		expected[mod.stat] = expected[mod.stat] + mod.value
	_check("max health, armor and ability haste rose by exactly its values",
		[p.stats_component.get_stat(&"max_health"), p.stats_component.get_stat(&"armor"), p.stats_component.get_stat(&"ability_haste")],
		[expected[&"max_health"], expected[&"armor"], expected[&"ability_haste"]])
	_check("Events.item_equipped(unit, item)", _log_rows(seen, p), [["on", 7]])
	var off := p.equipment.unequip(&"helm")
	_check("unequip() returns it", off == helm, true)
	_check("every stat back exactly", _all_values(p.stats_component), before)
	_check("nothing left under item_7", p.stats_component.get_modifiers_from(&"item_7").size(), 0)
	_check("Events.item_unequipped(unit, item)", _log_rows(seen, p), [["on", 7], ["off", 7]])
	_check("unequipping an empty slot returns null, no event", [p.equipment.unequip(&"helm") == null, seen.size()], [true, 2])
	_unlisten(seen)
	await _free(p)


func _test_swaps_and_rings() -> void:
	_section("L2: swaps and the two ring slots")
	var p := await _spawn_knight()
	var before := _all_values(p.stats_component)
	var helm_a := _item(&"item_base_iron_helm", R.COMMON, [[&"affix_armor", 0.2]], 11)
	var helm_b := _item(&"item_base_iron_helm", R.RARE, [[&"affix_armor", 0.9], [&"affix_magic_find", 0.4], [&"affix_tenacity", 0.1]], 12)
	p.equipment.equip(helm_a)
	var seen := _listen()
	_check("equipping a second helm swaps", p.equipment.equip(helm_b), true)
	_check("the helm slot holds the new one", p.equipment.get_item(&"helm") == helm_b, true)
	_check("the old one's modifiers are gone, the new one's on",
		[p.stats_component.get_modifiers_from(&"item_11").size(), p.stats_component.get_modifiers_from(&"item_12").size()], [0, 4])
	_check("events: the old one off, then the new one on", _log_rows(seen, p), [["off", 11], ["on", 12]])
	var rings: Array[Item] = []
	for uid in [21, 22, 23]:
		rings.append(_item(&"item_base_band", R.UNCOMMON, [[&"affix_attack_damage", 0.5], [&"affix_crit_chance", 0.5]], uid))
	p.equipment.equip(rings[0])
	p.equipment.equip(rings[1])
	_check("two rings fill ring_1 and ring_2", [p.equipment.get_slot_of(rings[0]), p.equipment.get_slot_of(rings[1])], [&"ring_1", &"ring_2"])
	p.equipment.equip(rings[2])
	_check("a third ring replaces ring 1", [p.equipment.get_slot_of(rings[2]), p.equipment.get_slot_of(rings[0])], [&"ring_1", &""])
	var count := seen.size()
	_check("equipping a worn ring again changes nothing", [p.equipment.equip(rings[1]), p.equipment.get_slot_of(rings[1]), seen.size()], [true, &"ring_2", count])
	_check("a worn ring can't move to the other ring slot", p.equipment.can_equip(rings[1], &"ring_1"), "already equipped (ring_2)")
	_check("an unworn ring can be put in ring 2 by name (a swap)", [p.equipment.equip(rings[0], &"ring_2"), p.equipment.get_slot_of(rings[1])], [true, &""])
	_unlisten(seen)
	for slot in EquipmentComponent.SLOTS:
		p.equipment.unequip(slot)
	_check("everything off: every stat back exactly", _all_values(p.stats_component), before)
	await _free(p)


func _test_can_equip() -> void:
	_section("L2: can_equip() refusals")
	var p := await _spawn_knight()
	var helm := _item(&"item_base_iron_helm", R.COMMON, [[&"affix_armor", 0.5]], 31)
	var ring := _item(&"item_base_band", R.COMMON, [[&"affix_attack_damage", 0.5]], 32)
	var twin := _item(&"item_base_leather_boots", R.COMMON, [[&"affix_armor", 0.5]], 31)
	var foreign := ForeignItem.new()
	foreign.uid = 33
	foreign.rarity = R.RARE
	foreign.base = _table.get_base(&"item_base_pendant")
	_check("no item", p.equipment.can_equip(null), "no item")
	_check("a helm in the boots slot", p.equipment.can_equip(helm, &"boots"), "a Helm can't go in the boots slot")
	_check("a ring in the amulet slot", p.equipment.can_equip(ring, &"amulet"), "a Ring can't go in the amulet slot")
	_check("a slot that doesn't exist", p.equipment.can_equip(helm, &"belt"), "no equipment slot 'belt'")
	_check("another champion's item", p.equipment.can_equip(foreign), "Mage only")
	p.equipment.equip(helm)
	_check("another worn item with the same uid", p.equipment.can_equip(twin), "another equipped item has uid 31")
	_check("a refused equip() returns false and changes nothing",
		[p.equipment.equip(helm, &"boots"), p.equipment.equip(foreign), p.equipment.equip(twin), p.equipment.get_equipped().size()], [false, false, false, 1])
	_check("a fitting item: no reason", p.equipment.can_equip(ring), "")
	await _free(p)


func _test_equip_augments() -> void:
	_section("L2: an item's augments go on and off with it")
	var p := await _spawn_knight()
	# The sigil pool is L4's; any EVENT and FLAG augment shows the hook works.
	var item := _item(&"item_base_pendant", R.EXOTIC, [], 41)
	item.sigils = [AUGMENT_JUDGEMENT_RESET, AUGMENT_LUNGE_STUNS]
	var lunge := p.abilities.get_ability(&"e")
	p.equipment.equip(item)
	_check("its EVENT augment's rule is on the unit", _rule_sources(p).has(&"augment_judgement_reset"), true)
	_check("its FLAG is on Lunge", p.abilities.get_flags(lunge).has(&"lunge_stuns"), true)
	p.equipment.unequip(&"amulet")
	_check("unequipped: the rule is gone", _rule_sources(p).has(&"augment_judgement_reset"), false)
	_check("unequipped: the FLAG is gone", p.abilities.get_flags(lunge).has(&"lunge_stuns"), false)
	await _free(p)


func _test_no_heal() -> void:
	_section("L2: a live swap never heals; a load starts full")
	var p := await _spawn_knight()
	var base_max := p.health.max_health
	var helm := _item(&"item_base_iron_helm", R.RARE, [[&"affix_max_health", 0.5]], 51)
	var bonus := 40.0 + helm.get_affix_value(0, _table)
	p.health.take_damage(p.health.current - 300.0)
	p.equipment.equip(helm)
	_check("equip at 300: the max rises, health stays 300", [p.health.max_health, p.health.current], [base_max + bonus, 300.0])
	p.equipment.unequip(&"helm")
	p.equipment.equip(helm)
	_check("off and on again: still 300 (no heal from a swap)", p.health.current, 300.0)
	p.health.heal(10000.0)
	var full := p.health.current
	var bigger := _item(&"item_base_iron_helm", R.RARE, [[&"affix_max_health", 1.0]], 52)
	p.equipment.equip(bigger)
	_check("a full-health swap to more health: health kept, not raised", [p.health.current, p.health.max_health > full], [full, true])
	var smaller := _item(&"item_base_iron_helm", R.COMMON, [[&"affix_armor", 0.5]], 53)
	p.equipment.equip(smaller)
	_check("a swap to less health: clamped to the new max", p.health.current, base_max + 40.0)
	p.equipment.unequip(&"helm")
	_check("unequipped at full: clamped to the bare max", p.health.current, base_max)
	p.equipment.equip(helm)
	_check("and putting one back doesn't refill", p.health.current, base_max)
	var raise := StatModifier.create(&"max_health", StatModifier.Type.FLAT, 10.0, &"test_raise")
	p.stats_component.add_modifier(raise)
	_check("after a swap the switch is back on: another source's raise still adds", p.health.current, base_max + 10.0)
	p.stats_component.remove_modifiers_from(&"test_raise")
	p.equipment.unequip(&"helm")
	p.health.take_damage(p.health.current - 300.0)
	p.equipment.equip(helm, &"", false)
	_check("keep_current false (a load): the raise adds to current", p.health.current, 300.0 + bonus)
	await _free(p)


func _test_inventory_record() -> void:
	_section("L2: ChampionInventory")
	var inv := ChampionInventory.create(KNIGHT)
	_check("a new record: champion, next uid, empty lists", [inv.champion_id, inv.next_uid, inv.items.size(), inv.equipped.size()], [&"knight", 1, 0, 0])
	_check("the materials bucket: empty and typed (StringName -> int)", [inv.materials.size(), inv.materials.is_typed()], [0, true])
	var rng := _rng(1111)
	var uids: Array = []
	for i in 3:
		uids.append(inv.add(ItemRoller.roll_item(R.RARE, KNIGHT, _table, rng)))
	_check("add() hands out uids 1, 2, 3", [uids, inv.next_uid], [[1, 2, 3], 4])
	_check("get_item()", [inv.get_item(2) == inv.items[1], inv.get_item(9) == null], [true, true])
	inv.set_equipped(&"helm", 2)
	_check("set_equipped / get_equipped_item / get_equipped_slot", [inv.get_equipped_item(&"helm") == inv.items[1], inv.get_equipped_slot(2)], [true, &"helm"])
	inv.clear_equipped(&"helm")
	_check("clear_equipped", [inv.get_equipped_item(&"helm") == null, inv.get_equipped_slot(2)], [true, &""])


func _test_inventory_save() -> void:
	_section("L2: the inventory save (ConfigFile text)")
	var inv := ChampionInventory.create(KNIGHT)
	var rng := _rng(2222)
	for i in 20:
		inv.add(ItemRoller.roll_item((i % 5) as Item.Rarity, KNIGHT, _table, rng))
	inv.set_equipped(&"weapon", 3)
	inv.set_equipped(&"ring_2", 5)
	var back := _through_text(inv)
	var same := back != null and back.items.size() == 20
	for i in mini(inv.items.size(), back.items.size() if back != null else 0):
		same = same and back.items[i].to_dict() == inv.items[i].to_dict() and _mod_rows(back.items[i]) == _mod_rows(inv.items[i])
	_check("20 items come back with their uids, rolls and values", same, true)
	_check("next uid and the equipped set", [back.next_uid, back.equipped], [21, {&"weapon": 3, &"ring_2": 5}])
	_check("the materials bucket comes back empty", [back.materials.size(), back.materials.is_typed()], [0, true])
	var cfg := ConfigFile.new()
	inv.write_to(cfg)
	_check("the save holds next_uid, items, equipped and materials", cfg.get_section_keys("knight"), PackedStringArray(["next_uid", "items", "equipped", "materials"]))
	_check("no section: null", ChampionInventory.read_from(ConfigFile.new(), KNIGHT, _table) == null, true)
	# Entries the data no longer knows (expect warnings).
	var good := _item(&"item_base_band", R.COMMON, [[&"affix_attack_damage", 0.3]], 1).to_dict()
	var gone := {"uid": 9, "base": "item_base_gone", "rarity": "rare", "affixes": [], "sigils": []}
	var broken := ConfigFile.new()
	broken.set_value("knight", "next_uid", 2)
	broken.set_value("knight", "items", [good, gone, "garbage"])
	broken.set_value("knight", "equipped", {"helm": 9, "belt": 1, "chest": 1})
	broken.set_value("knight", "materials", {})
	var read := ChampionInventory.read_from(broken, KNIGHT, _table)
	_check("an unknown base or a non-item entry isn't loaded but is kept raw", [read.items.size(), read.get_unreadable_count()], [1, 2])
	_check("its uid stays taken (next uid 10)", read.next_uid, 10)
	_check("equipped: an unreadable item and a bad slot dropped, a real one kept", read.equipped, {&"chest": 1})
	var again := ConfigFile.new()
	read.write_to(again)
	var written: Array = again.get_value("knight", "items")
	_check("the raw entries are written back unchanged", [written.has(gone), written.has("garbage"), written.size()], [true, true, 3])
	var dup := ConfigFile.new()
	dup.set_value("knight", "items", [good, good])
	var deduped := ChampionInventory.read_from(dup, KNIGHT, _table)
	_check("a duplicate uid gets a new one", [deduped.items[0].uid, deduped.items[1].uid, deduped.next_uid], [1, 2, 3])


func _test_loot_autoload() -> void:
	_section("L2: the Loot autoload")
	Loot.reset(KNIGHT)
	_check("a test scene turned saving off", Loot.saving_enabled, false)
	var record := Loot.get_inventory(KNIGHT)
	_check("get_inventory() returns the same record", Loot.get_inventory(KNIGHT) == record, true)
	var p := await _spawn_knight()
	_check("the Knight is tracked", Loot.get_tracked_player() == p, true)
	var helm := ItemRoller.roll_item(R.RARE, KNIGHT, _table, _rng(3333), Item.Slot.HELM)
	var uid := Loot.add_item(KNIGHT, helm)
	_check("add_item() puts it in the record with a uid", [uid, record.get_item(uid) == helm], [1, true])
	p.equipment.equip(helm)
	_check("equipping a record's item saves the slot", record.equipped, {&"helm": uid})
	p.equipment.unequip(&"helm")
	_check("unequipping clears it", record.equipped, {})
	var loose := _item(&"item_base_iron_helm", R.COMMON, [], 999)
	p.equipment.equip(loose)
	_check("an item not in the record isn't remembered", record.equipped, {})
	p.equipment.unequip(&"helm")
	p.equipment.equip(helm)
	# A save to a scratch file, then read back the way a new session would.
	Loot.save_path = SCRATCH_SAVE
	Loot.saving_enabled = true
	Loot.save()
	Loot.saving_enabled = false
	Loot.save_path = Loot.SAVE_PATH
	var cfg := ConfigFile.new()
	var err := cfg.load(SCRATCH_SAVE)
	var read := ChampionInventory.read_from(cfg, KNIGHT, _table) if err == OK else null
	_check("Loot.save() writes the record (read back from a scratch file)",
		[err, read != null and read.items.size() == 1 and read.items[0].to_dict() == helm.to_dict(), read.equipped if read != null else null],
		[OK, true, {&"helm": uid}])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_SAVE))
	Loot.reset(KNIGHT)
	_check("reset() empties the record", Loot.get_inventory(KNIGHT).items.size(), 0)
	await _free(p)
	_check("the Knight freed: no tracked player", Loot.get_tracked_player() == null, true)


func _test_player_loads_gear() -> void:
	_section("L2: the Player equips its saved gear at load")
	Loot.reset(KNIGHT)
	var record := Loot.get_inventory(KNIGHT)
	var rng := _rng(4444)
	var helm := ItemRoller.roll_item(R.RARE, KNIGHT, _table, rng, Item.Slot.HELM)
	var ring := ItemRoller.roll_item(R.UNCOMMON, KNIGHT, _table, rng, Item.Slot.RING)
	record.add(helm)
	record.add(ring)
	record.set_equipped(&"helm", helm.uid)
	record.set_equipped(&"ring_2", ring.uid)
	record.set_equipped(&"boots", ring.uid)   # a ring in the boots slot (expect a warning)
	record.set_equipped(&"gloves", 999)       # no such item (expect a warning)
	var bare := await _spawn_knight_with_empty_record()
	var bare_max := bare.health.max_health
	await _free(bare)
	var p := await _spawn_knight()
	_check("the saved helm and ring are worn", [p.equipment.get_item(&"helm") == helm, p.equipment.get_item(&"ring_2") == ring], [true, true])
	_check("slots the gear refuses are left empty", [p.equipment.get_item(&"boots"), p.equipment.get_item(&"gloves")], [null, null])
	_check("and dropped from the record", record.equipped, {&"helm": helm.uid, &"ring_2": ring.uid})
	var helm_health := 0.0
	for mod in helm.get_modifiers(_table):
		if mod.stat == &"max_health":
			helm_health += mod.value
	_check("the champion spawns full, with the helm's health in the max",
		[p.health.max_health, p.health.current], [bare_max + helm_health, bare_max + helm_health])
	await _free(p)


# --- L3: SandboxLoot ------------------------------------------------------------

func _test_room_depth() -> void:
	_section("L3: Room.depth, RoomLayout.depth, Loot.get_depth()")
	var room := Room.new()
	var layout := RoomLayout.new()
	_check("a Room and a RoomLayout start at depth 1", [room.depth, layout.depth], [1, 1])
	layout.free()
	room.depth = 4
	var child := Node2D.new()
	var grandchild := Node.new()
	room.add_child(child)
	child.add_child(grandchild)
	_check("get_depth(): the nearest Room's, from the room, a child or a grandchild",
		[Loot.get_depth(room), Loot.get_depth(child), Loot.get_depth(grandchild)], [4, 4, 4])
	room.depth = 0
	_check("a depth below 1 counts as 1", Loot.get_depth(grandchild), 1)
	var loose := Node.new()
	_check("no Room above (or no node): depth 1", [Loot.get_depth(loose), Loot.get_depth(null)], [1, 1])
	loose.free()
	room.free()
	var sandbox := (load("res://scenes/rooms/sandbox_3d.tscn") as PackedScene).instantiate() as RoomLayout
	sandbox.depth = 3
	var built := sandbox.build_sim()
	_check("build_sim() copies the layout's depth onto the Room", built.depth, 3)
	_check("and moves SandboxLoot into the Room", built.get_node_or_null("SandboxLoot") is SandboxLoot, true)
	built.free()
	sandbox.free()


func _test_sandbox_scenes() -> void:
	_section("L3: SandboxLoot in both sandboxes")
	var tile_sandbox := (load("res://scenes/rooms/sandbox.tscn") as PackedScene).instantiate() as Room
	var node := tile_sandbox.get_node_or_null("SandboxLoot") as SandboxLoot
	_check("sandbox.tscn has a SandboxLoot node; the room is at depth 1", [node != null, tile_sandbox.depth], [true, 1])
	_check("K rolls from the elite table by default", node != null and node.drop_table == ELITE, true)
	tile_sandbox.free()
	var sandbox := (load("res://scenes/rooms/sandbox_3d.tscn") as PackedScene).instantiate() as RoomLayout
	_check("sandbox_3d.tscn has one too (not a Node3D, so build_sim() moves it); the layout is at depth 1",
		[sandbox.get_node_or_null("SandboxLoot") is SandboxLoot, sandbox.depth], [true, 1])
	sandbox.free()


func _test_sandbox_loot() -> void:
	_section("L3: SandboxLoot on a live Knight (the list, U, K, P, [ / ])")
	Loot.reset(KNIGHT)
	var setup := await _sandbox_room()
	var room: Room = setup[0]
	var sl: SandboxLoot = setup[1]
	var p: Player = setup[2]
	_check("it finds the Knight in Entities", sl.get_champion() == KNIGHT, true)
	_check("an empty inventory: the header and a hint", _row_texts(sl).slice(1, 3),
		["Inventory 0   Depth 1   MF +0%", "  Nothing yet: K rolls an item"])
	var label := _find_label(sl)
	_check("the list is a RichTextLabel that never takes the mouse (attack clicks pass)",
		label != null and label.mouse_filter == Control.MOUSE_FILTER_IGNORE, true)

	# K (since L7 a drop at the Knight's feet, taken when it lands)
	Loot.rng.seed = 3030
	var first := sl.roll_drop()
	var record := Loot.get_inventory(KNIGHT)
	var on_ground := Loot.get_ground_pickups(room)
	_check("K: one item from the elite table, dropped at the Knight's feet as a pickup (not in the inventory yet)",
		[first.size(), on_ground.size(), on_ground[0].item == first[0] if on_ground.size() == 1 else false, on_ground[0].get_hop_from() == p.global_position if on_ground.size() == 1 else false, record.items.size()],
		[1, 1, true, true, 0])
	_check("the result said", sl.get_status().begins_with("Rolled "), true)
	await _wait_until(func() -> bool: return record.items.size() == 1, 30)
	_check("it lands and the Knight takes it: in the inventory with uid 1", [record.items.size(), first[0].uid], [1, 1])
	_check("the cursor on it", sl.get_cursor(), 0)
	for i in 5:
		sl.roll_drop()
	await _wait_until(func() -> bool: return record.items.size() == 6, 30)
	var rarities_ok := true
	for item in record.items:
		rarities_ok = rarities_ok and item.rarity >= R.UNCOMMON and (item.rarity <= R.EXOTIC or (item.named != null and item.named.champion_id == KNIGHT.id))
	_check("six rolls: six items, Uncommon or better (the elite table has no Common); a Legendary is one of the Knight's named items (L5)",
		[record.items.size(), rarities_ok], [6, true])
	_check("the cursor follows the newest", sl.get_cursor(), 5)

	# K at the room's depth with the Knight's magic find.
	var half := DropTable.new()
	half.item_chance = 0.5
	half.chance_per_depth = 1.0
	sl.drop_table = half
	Loot.rng.seed = 7070
	var hits_1 := 0
	for i in 40:
		hits_1 += sl.roll_drop().size()
	sl.change_depth(1)
	var hits_2 := 0
	for i in 40:
		hits_2 += sl.roll_drop().size()
	_check("K uses the room's depth (chance 0.5 at depth 1: some of 40 miss; 1.0 at depth 2: none)",
		[hits_1 > 0 and hits_1 < 40, hits_2], [true, 40])
	var never := DropTable.new()
	never.item_chance = 0.0
	sl.drop_table = never
	_check("a table that never drops: nothing, said so", [sl.roll_drop().size(), sl.get_status()], [0, "Rolled nothing (depth 2)"])
	sl.change_depth(-1)
	var split := DropTable.new()
	split.item_chance = 1.0
	split.rarity_weights = [1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	sl.drop_table = split
	Loot.rng.seed = 8080
	var plain := _count_rolled(sl, 40, R.UNCOMMON)
	p.stats_component.add_modifiers([StatModifier.create(&"magic_find", StatModifier.Type.FLAT, 9.0, &"loot_test_mf")])
	_check("the header shows the Knight's magic find", _row_texts(sl)[1].ends_with("MF +900%"), true)
	Loot.rng.seed = 8080
	var found := _count_rolled(sl, 40, R.UNCOMMON)
	_check("K uses the Knight's magic find (Uncommon of 40, Common / Uncommon 1:1, then +900% magic find: 1:10)",
		[plain < 30, found >= 30], [true, true])
	p.stats_component.remove_modifiers_from(&"loot_test_mf")
	sl.drop_table = ELITE
	Loot.take_ground_drops(room)   # the rate checks' drops, before they land

	# U
	Loot.reset(KNIGHT)
	record = Loot.get_inventory(KNIGHT)
	var helm_a := _item(&"item_base_iron_helm", R.RARE, [[&"affix_max_health", 0.5], [&"affix_armor", 0.5]], 0)
	var helm_b := _item(&"item_base_iron_helm", R.UNCOMMON, [[&"affix_magic_find", 1.0]], 0)
	var ring_x := _item(&"item_base_band", R.COMMON, [[&"affix_attack_damage", 0.2]], 0)
	var ring_y := _item(&"item_base_band", R.COMMON, [[&"affix_crit_chance", 0.4]], 0)
	var ring_z := _item(&"item_base_band", R.COMMON, [[&"affix_attack_speed", 0.6]], 0)
	for item in [helm_a, helm_b, ring_x, ring_y, ring_z]:
		Loot.add_item(KNIGHT, item)
	sl.move_cursor(-sl.get_cursor())
	var bare := _all_values(p.stats_component)
	_check("U on a helm: worn and remembered", [sl.toggle(0), p.equipment.get_item(&"helm") == helm_a, record.equipped.get(&"helm")],
		[true, true, helm_a.uid])
	_check("the list marks it ON, in the Rare color",
		_row_color(sl, "[Helm] Iron Helm  Rare  ON"), _table.get_rarity(R.RARE).color)
	_check("and the label shows it (the bracket escaped)", label.get_parsed_text().contains("[Helm] Iron Helm  Rare  ON"), true)
	_check("U on the other helm: a swap, said so", [sl.toggle(1), p.equipment.get_item(&"helm") == helm_b, sl.get_status()],
		[true, true, "Equipped Iron Helm (swapped out Iron Helm)"])
	_check("the first helm's pieces are gone", p.stats_component.get_modifiers_from(helm_a.get_source_id()).size(), 0)
	_check("U again: unequipped, the Knight exactly as before", [sl.toggle(1), p.equipment.get_item(&"helm"), record.equipped.has(&"helm")],
		[false, null, false])
	_check("(every stat back)", _all_values(p.stats_component) == bare, true)
	sl.toggle(1)
	_check("the header shows the helm's magic find", _row_texts(sl)[1].ends_with("MF +%d%%" % roundi(helm_b.get_affix_value(0, _table) * 100.0)), true)
	sl.toggle(2)
	sl.toggle(3)
	_check("two rings: both ring slots", [p.equipment.get_item(&"ring_1") == ring_x, p.equipment.get_item(&"ring_2") == ring_y], [true, true])
	_check("a third ring swaps out ring 1", [sl.toggle(4), p.equipment.get_item(&"ring_1") == ring_z, sl.get_status()],
		[true, true, "Equipped Band (swapped out Band)"])
	_check("the record remembers the worn set", record.equipped, {&"helm": helm_b.uid, &"ring_1": ring_z.uid, &"ring_2": ring_y.uid})
	_check("three rows marked ON", _row_texts(sl).filter(func(t: String) -> bool: return t.ends_with("  ON")).size(), 3)

	# J, the scrolling and the tooltip.
	sl.visible_rows = 3
	sl.move_cursor(-sl.get_cursor())
	var texts := _row_texts(sl)
	_check("cursor at the top: the first 3 items, then how many below",
		[texts.has("> [Helm] Iron Helm  Rare"), texts.has("  (2 below)"), _row_with(sl, "above")], [true, true, false])
	sl.move_cursor(-1)
	texts = _row_texts(sl)
	_check("up from the top wraps to the last item; the list scrolls with it",
		[sl.get_cursor(), texts.has("> [Ring] Band  Common  ON"), texts.has("  (2 above)"), _row_with(sl, "below")], [4, true, true, false])
	var tooltip := ring_z.get_tooltip_lines(_table)
	var tooltip_ok := true
	for line in tooltip.slice(2):
		tooltip_ok = tooltip_ok and texts.has("    " + line)
	_check("the highlighted item's tooltip lines are under the list (past its name and rarity, already on its row)",
		[tooltip_ok, texts.has("    " + tooltip[0]), texts.has("    " + tooltip[1])], [true, false, false])
	sl.visible_rows = 6

	# P and [ / ].
	_check("P: one of each of the Knight's named items into the inventory, named (L5)", [sl.grant_named_items(), record.items.size(), sl.get_status()],
		[KNIGHT.named_items.size(), 5 + KNIGHT.named_items.size(), "Granted " + ", ".join(KNIGHT.named_items.map(func(n: NamedItem) -> String: return n.display_name))])
	_check("]: depth 2", [sl.change_depth(1), room.depth], [2, 2])
	_check("[ twice: back to 1, never below", [sl.change_depth(-1), sl.change_depth(-1), room.depth], [1, 1, 1])

	# A new Knight (a restart) wears what was set.
	await _free(p)
	var p2 := await _spawn_in(room)
	_check("a new Knight: found, the cursor back at the top", [sl.get_champion() == KNIGHT, sl.get_cursor(), sl.get_status()], [true, 0, ""])
	_check("it wears what was set (the helm, both rings)",
		[p2.equipment.get_item(&"helm") == helm_b, p2.equipment.get_item(&"ring_1") == ring_z, p2.equipment.get_item(&"ring_2") == ring_y],
		[true, true, true])
	room.queue_free()
	await _frames(1)


func _test_sandbox_loot_keys() -> void:
	_section("L3: SandboxLoot's keys (through the viewport)")
	Loot.reset(KNIGHT)
	var setup := await _sandbox_room()
	var room: Room = setup[0]
	var sl: SandboxLoot = setup[1]
	var p: Player = setup[2]
	Loot.rng.seed = 5050
	for i in 3:
		_press(KEY_K)
	var items := Loot.get_inventory(KNIGHT).items
	_check("K three times: three drops at the Knight's feet", Loot.get_ground_pickups(room).size(), 3)
	await _wait_until(func() -> bool: return items.size() == 3, 30)
	_check("they land and he takes them: three items, the cursor on the last", [items.size(), sl.get_cursor()], [3, 2])
	_press(KEY_J)
	_check("J: down (wraps to the top)", sl.get_cursor(), 0)
	_press(KEY_J, true)
	_check("Shift+J: up (wraps to the bottom)", sl.get_cursor(), 2)
	_press(KEY_J, false, true)
	_check("a held J repeats", sl.get_cursor(), 0)
	_press(KEY_U)
	_check("U: the highlighted item worn", p.equipment.get_slot_of(items[0]) != &"", true)
	_press(KEY_U, false, true)
	_check("a held U doesn't repeat", p.equipment.get_slot_of(items[0]) != &"", true)
	_press(KEY_U)
	_check("U again: off", p.equipment.get_slot_of(items[0]), &"")
	_press(KEY_BRACKETRIGHT)
	_press(KEY_BRACKETRIGHT)
	_check("] twice: depth 3", room.depth, 3)
	_press(KEY_BRACKETLEFT)
	_check("[: depth 2", room.depth, 2)
	_press(KEY_P)
	_check("P: grants the named items", [sl.get_status().begins_with("Granted "), Loot.get_inventory(KNIGHT).items.size()], [true, 3 + KNIGHT.named_items.size()])
	room.queue_free()
	await _frames(1)


func _test_sandbox_loot_saves() -> void:
	_section("L3: K and U save at once (to a scratch file, never the real one)")
	Loot.reset(KNIGHT)
	var setup := await _sandbox_room()
	var room: Room = setup[0]
	var sl: SandboxLoot = setup[1]
	var p: Player = setup[2]
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_SAVE))
	Loot.save_path = SCRATCH_SAVE
	Loot.saving_enabled = true
	Loot.rng.seed = 6060
	var rolled := sl.roll_drop()
	await _wait_until(func() -> bool: return Loot.get_inventory(KNIGHT).items.size() == 1, 30)
	var after_roll := _read_scratch()
	sl.toggle(0)
	var after_equip := _read_scratch()
	Loot.saving_enabled = false
	Loot.save_path = Loot.SAVE_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_SAVE))
	_check("K: the new item is in the file", after_roll != null and after_roll.items.size() == 1
		and after_roll.items[0].to_dict() == rolled[0].to_dict(), true)
	_check("U: the worn slot is in the file", after_equip.equipped if after_equip != null else null,
		{p.equipment.get_slot_of(rolled[0]): rolled[0].uid})
	room.queue_free()
	await _frames(1)


# --- L4: sigils -----------------------------------------------------------------

func _test_sigil_data() -> void:
	_section("L4: the three sigils and their statuses (LOOT.md, The sigil pool)")
	var rows := [
		# sigil, name, suffix, trigger, effect target, chance, required status tags
		[SIGIL_STORM_STRIKE, "Storm Strike", "Storms", ReactionRule.Trigger.HIT, ReactionRule.EffectTarget.AFFECTED, 0.15, []],
		[SIGIL_BLOODRUSH, "Bloodrush", "the Hunt", ReactionRule.Trigger.UNIT_DIED, ReactionRule.EffectTarget.OTHER, 1.0, []],
		[SIGIL_EXPOSE, "Expose", "Ruin", ReactionRule.Trigger.STATUS_APPLIED, ReactionRule.EffectTarget.AFFECTED, 1.0, [&"cc"]],
	]
	for row: Array in rows:
		var sigil: AbilityAugment = row[0]
		var rule: ReactionRule = sigil.rules[0] if sigil.rules.size() == 1 else null
		_check("%s: an EVENT augment, empty scope (any champion), named %s, suffix '%s', described, one rule" % [sigil.id, row[1], row[2]],
			[sigil.kind, sigil.scope, sigil.display_name, sigil.name_suffix, sigil.description != "", rule != null],
			[AbilityAugment.Kind.EVENT, &"", row[1], row[2], true, true])
		if rule == null:
			continue
		_check("%s's rule: its trigger, the owner's own events (SOURCE), its effect target, chance, status tags, any ability, chain limit 2" % sigil.id,
			[rule.trigger, rule.owner_role, rule.effect_target, rule.chance, _plain(rule.required_status_tags), rule.required_ability_scope, rule.chain_limit],
			[row[3], ReactionRule.OwnerRole.SOURCE, row[4], row[5], row[6], &"", 2])
	var bolt := SIGIL_STORM_STRIKE.rules[0].effects[0] as DealDamageGameplayEffect
	_check("Storm Strike's lightning: 30 + 40% AD, magic, tagged lightning",
		[bolt.base_damage, bolt.ad_ratio, bolt.damage_type, _plain(bolt.tags)] if bolt != null else [],
		[30.0, 0.4, HitContext.DamageType.MAGIC, [&"lightning"]])
	var rush := SIGIL_BLOODRUSH.rules[0].effects[0] as ApplyStatusGameplayEffect
	var expose := SIGIL_EXPOSE.rules[0].effects[0] as ApplyStatusGameplayEffect
	_check("Bloodrush applies status_bloodrush, Expose status_exposed (each for its own duration)",
		[rush != null and rush.status == STATUS_BLOODRUSH and rush.duration < 0.0, expose != null and expose.status == STATUS_EXPOSED and expose.duration < 0.0],
		[true, true])
	_check("status_bloodrush: its own id (never Iron Resolve's), a 2 s buff, refreshed",
		[STATUS_BLOODRUSH.id, _plain(STATUS_BLOODRUSH.tags), STATUS_BLOODRUSH.duration, STATUS_BLOODRUSH.stack_rule],
		[&"bloodrush", [&"buff"], 2.0, StatusEffect.StackRule.REFRESH])
	_check("... +30% move speed (increased)", _status_mod_rows(STATUS_BLOODRUSH), [[&"move_speed", StatModifier.Type.PERCENT_ADD, 0.3, &""]])
	_check("status_exposed: a 3 s debuff tagged exposed, never cc (so it can't Expose itself), refreshed",
		[STATUS_EXPOSED.id, _plain(STATUS_EXPOSED.tags), STATUS_EXPOSED.duration, STATUS_EXPOSED.stack_rule, STATUS_EXPOSED.is_cc()],
		[&"exposed", [&"exposed", &"debuff"], 3.0, StatusEffect.StackRule.REFRESH, false])
	_check("... +15% damage taken (more)", _status_mod_rows(STATUS_EXPOSED), [[&"incoming_damage", StatModifier.Type.PERCENT_MULT, 0.15, &""]])


func _test_sigil_rolls() -> void:
	_section("L4: Unique and Exotic roll their sigils; names, tooltips, the save")
	var rng := _rng(4404)
	var counts := {}
	var unique_ok := true
	for i in 3000:
		var item := ItemRoller.roll_item(R.UNIQUE, null, _table, rng)
		unique_ok = unique_ok and item.sigils.size() == 1
		if item.sigils.size() == 1:
			counts[item.sigils[0].id] = int(counts.get(item.sigils[0].id, 0)) + 1
	_check("3,000 Uniques: one sigil each", unique_ok, true)
	var even := counts.size() == 3
	for id: StringName in counts:
		even = even and absf(counts[id] / 3000.0 - 1.0 / 3.0) < 0.03
	_report(even, "each sigil on about a third of them (the same odds)", str(counts))
	var pairs := {}
	var exotic_ok := true
	for i in 3000:
		var item := ItemRoller.roll_item(R.EXOTIC, null, _table, rng)
		exotic_ok = exotic_ok and item.sigils.size() == 2 and item.sigils[0] != item.sigils[1]
		if item.sigils.size() == 2:
			var ids: Array = [String(item.sigils[0].id), String(item.sigils[1].id)]
			ids.sort()
			pairs["+".join(ids)] = true
	_check("3,000 Exotics: two different sigils each", exotic_ok, true)
	_check("all three pairs come up", pairs.size(), 3)
	var helm := _item(&"item_base_iron_helm", R.UNIQUE, [[&"affix_max_health", 0.5]], 1)
	helm.sigils = [SIGIL_STORM_STRIKE]
	var band := _item(&"item_base_band", R.EXOTIC, [[&"affix_crit_chance", 0.5]], 2)
	band.sigils = [SIGIL_BLOODRUSH, SIGIL_EXPOSE]
	_check("a Unique's name: its base of its sigil's suffix", helm.get_display_name(), "Iron Helm of Storms")
	_check("an Exotic's: both suffixes, in its sigils' order", band.get_display_name(), "Band of the Hunt and Ruin")
	_check("a Rare's: its base alone", _manual_item().get_display_name(), "Longsword")
	var lines := band.get_tooltip_lines(_table)
	_check("the tooltip: the name first, then one line per sigil last (name: description)",
		[lines[0], lines[lines.size() - 2], lines[lines.size() - 1]],
		["Band of the Hunt and Ruin", "Bloodrush: " + SIGIL_BLOODRUSH.description, "Expose: " + SIGIL_EXPOSE.description])
	_check("its augments are its sigils", band.get_augments(), [SIGIL_BLOODRUSH, SIGIL_EXPOSE])
	var d := band.to_dict()
	var back := Item.from_dict(d, _table)
	_check("saved as sigil ids, read back as the same sigils and name",
		[d["sigils"], back != null and back.sigils == band.sigils, back.get_display_name() if back != null else ""],
		[["sigil_bloodrush", "sigil_expose"], true, "Band of the Hunt and Ruin"])


func _test_storm_strike() -> void:
	_section("L4: Storm Strike (the Knight's hits: 15% x the proc coefficient; a 30 + 40% AD magic bolt)")
	Loot.reset(KNIGHT)
	_dummy_offset = 0.0
	var p := await _spawn_knight()
	var dummy := _dummy_near(p)
	var helm := _item(&"item_base_iron_helm", R.UNIQUE, [], 101)
	helm.sigils = [SIGIL_STORM_STRIKE]
	p.equipment.equip(helm)
	_check("worn: its rule is on the Knight once, under augment_sigil_storm_strike", _rule_sources(p).count(&"augment_sigil_storm_strike"), 1)
	Reactions.rng.seed = 4141
	var bolts := _bolts_from(p, dummy, 1000, 1.0)
	_report(absi(bolts.size() - 150) <= 45, "1,000 hits (coefficient 1): about 15% call a bolt", "got %d" % bolts.size())
	var bolt: HitContext = bolts[0] if not bolts.is_empty() else null
	_check("a bolt: from the Knight onto the hit enemy, 30 + 40% AD, magic",
		[bolt.source == p, bolt.target == dummy, bolt.base_damage, bolt.ad_ratio, bolt.damage_type] if bolt != null else [],
		[true, true, 30.0, 0.4, HitContext.DamageType.MAGIC])
	_check("a proc: tagged proc and lightning, can't crit, coefficient 0 (so a bolt never calls a bolt)",
		[bolt.has_tag(&"proc"), bolt.has_tag(&"lightning"), bolt.can_crit, bolt.proc_coefficient] if bolt != null else [],
		[true, true, false, 0.0])
	var half := _bolts_from(p, dummy, 1000, 0.5)
	_report(absi(half.size() - 75) <= 32, "1,000 hits at coefficient 0.5: about 7.5%", "got %d" % half.size())
	_check("300 proc-tagged hits from the Knight (on-hit damage, a bolt itself): never", _bolts_from(p, dummy, 300, 0.0, true).size(), 0)
	var other := _dummy_near(p)
	_check("300 hits from another unit: never (only the wearer's own hits)", _bolts_from(other, dummy, 300, 1.0).size(), 0)
	p.equipment.unequip(&"helm")
	_check("unequipped: the rule is gone", _rule_sources(p).has(&"augment_sigil_storm_strike"), false)
	_check("and 300 hits call nothing", _bolts_from(p, dummy, 300, 1.0).size(), 0)
	await _free_dummies()
	await _free(p)


func _test_bloodrush() -> void:
	_section("L4: Bloodrush (a kill: +30% move speed for 2 s, refreshed)")
	Loot.reset(KNIGHT)
	_dummy_offset = 0.0
	var p := await _spawn_knight()
	var statuses := p.status_component
	var ring := _item(&"item_base_band", R.UNIQUE, [], 102)
	ring.sigils = [SIGIL_BLOODRUSH]
	var base_speed := p.stats_component.get_stat(&"move_speed")
	_kill(p, _dummy_near(p, false))
	_check("without it a kill gives nothing", statuses.has_status(&"bloodrush"), false)
	p.equipment.equip(ring)
	_kill(p, _dummy_near(p, false))
	var rushed := p.stats_component.get_stat(&"move_speed")
	_check("worn: a kill puts Bloodrush on the Knight, 2 s left", [statuses.has_status(&"bloodrush"), statuses.get_time_left(&"bloodrush")], [true, 2.0])
	_check("its +30% move speed (increased) under status_bloodrush, and the Knight is faster",
		[_mod_rows_from(p, &"status_bloodrush"), rushed > base_speed], [[[&"move_speed", StatModifier.Type.PERCENT_ADD, 0.3, &""]], true])
	# With Iron Resolve's haste (a real cast): two ids, both kept, summed.
	p.resource_pool.restore(1000.0)
	p.abilities.try_cast(&"w", p.global_position, null)
	for i in 30:
		if statuses.has_status(&"iron_resolve"):
			break
		await _frames(1)
	var both := p.stats_component.get_stat(&"move_speed")
	statuses.remove_status(&"bloodrush")
	var haste_only := p.stats_component.get_stat(&"move_speed")
	_check("with Iron Resolve's haste (cast for real): both on, their bonuses summed",
		[statuses.has_status(&"iron_resolve"), is_equal_approx(both - base_speed, (rushed - base_speed) + (haste_only - base_speed))], [true, true])
	statuses.remove_status(&"iron_resolve")
	# Refreshed by the next kill.
	_kill(p, _dummy_near(p, false))
	await _wait_hitstop()
	await _frames(30)
	var waned := statuses.get_time_left(&"bloodrush")
	_kill(p, _dummy_near(p, false))
	_check("the next kill refreshes it to 2 s", [waned < 1.9, statuses.get_time_left(&"bloodrush")], [true, 2.0])
	# A kill a reaction caused (a bolt's, one link deep) counts; two links deep doesn't.
	statuses.remove_status(&"bloodrush")
	var victim := _dummy_near(p, false)
	Reactions.run_at_depth(1, func() -> void: _kill(p, victim))
	_check("a kill one link into a chain (a sigil's bolt) still rushes (chain limit 2)", statuses.has_status(&"bloodrush"), true)
	statuses.remove_status(&"bloodrush")
	var deeper := _dummy_near(p, false)
	Reactions.run_at_depth(2, func() -> void: _kill(p, deeper))
	_check("two links deep: no", statuses.has_status(&"bloodrush"), false)
	_kill(_dummy_near(p), _dummy_near(p, false))
	_check("another unit's kill: nothing for the Knight", statuses.has_status(&"bloodrush"), false)
	p.equipment.unequip(&"ring_1")
	_kill(p, _dummy_near(p, false))
	_check("unequipped: a kill gives nothing", statuses.has_status(&"bloodrush"), false)
	await _free_dummies()
	await _free(p)


func _test_expose() -> void:
	_section("L4: Expose (crowd control the Knight applies: Exposed for 3 s, +15% damage taken)")
	Loot.reset(KNIGHT)
	_dummy_offset = 0.0
	var p := await _spawn_knight()
	var amulet := _item(&"item_base_pendant", R.UNIQUE, [], 103)
	amulet.sigils = [SIGIL_EXPOSE]
	var plain := _dummy_near(p)
	plain.status_component.apply_status(STATUS_STUN, p)
	_check("without it a stun doesn't Expose", plain.status_component.has_status(&"exposed"), false)
	p.equipment.equip(amulet)
	var applied := [0]
	var count := func(_unit: Unit, status: StatusEffect) -> void:
		if status.id == &"exposed":
			applied[0] += 1
	Events.status_applied.connect(count)
	var d := _dummy_near(p)
	d.status_component.apply_status(STATUS_STUN, p)
	Events.status_applied.disconnect(count)
	_check("worn: the Knight's stun Exposes, for 3 s, from the Knight",
		[d.status_component.has_status(&"exposed"), d.status_component.get_time_left(&"exposed"), d.status_component.get_source(&"exposed") == p],
		[true, 3.0, true])
	_check("once (Exposed isn't cc, so it never Exposes again)", applied[0], 1)
	_check("the enemy's incoming damage x1.15", d.stats_component.get_stat(&"incoming_damage"), 1.15)
	var exposed_hit := _hit_from(p, d, 100.0).taken_damage
	d.status_component.remove_status(&"exposed")
	var same_hit := _hit_from(p, d, 100.0).taken_damage
	_check_near("the same hit on it, still stunned: 15% more while Exposed", exposed_hit / same_hit if same_hit > 0.0 else 0.0, 1.15, 0.0001)
	var slowed := _dummy_near(p)
	slowed.status_component.apply_status(STATUS_SLOW, p)
	_check("the Knight's slow (cc): Exposed", slowed.status_component.has_status(&"exposed"), true)
	var staggered := _dummy_near(p)
	staggered.status_component.apply_status(STATUS_STAGGERED, p)
	_check("Staggered (not cc): not Exposed", staggered.status_component.has_status(&"exposed"), false)
	var theirs := _dummy_near(p)
	theirs.status_component.apply_status(STATUS_STUN, _dummy_near(p))
	var nobody := _dummy_near(p)
	nobody.status_component.apply_status(STATUS_STUN, null)
	_check("another unit's stun, or one from no one: not Exposed",
		[theirs.status_component.has_status(&"exposed"), nobody.status_component.has_status(&"exposed")], [false, false])
	# A real Judgement: its stun Exposes.
	var judged := _dummy_near(p)
	judged.global_position = p.global_position + Vector2(60, 0)
	judged.reset_physics_interpolation()
	await _frames(1)
	p.resource_pool.restore(1000.0)
	await _wait_hitstop()
	p.abilities.try_cast(&"r", judged.global_position, judged)
	for i in 200:
		if judged.status_component.has_status(&"stun"):
			break
		await _frames(1)
	_check("a real Judgement: its stun lands and Exposes",
		[judged.status_component.has_status(&"stun"), judged.status_component.has_status(&"exposed")], [true, true])
	p.equipment.unequip(&"amulet")
	var after := _dummy_near(p)
	after.status_component.apply_status(STATUS_STUN, p)
	_check("unequipped: a stun doesn't Expose", after.status_component.has_status(&"exposed"), false)
	await _free_dummies()
	await _free(p)


func _test_sigil_stacking() -> void:
	_section("L4: the same sigil twice is one; an Exotic's two both fire; unequipping removes")
	Loot.reset(KNIGHT)
	_dummy_offset = 0.0
	var p := await _spawn_knight()
	var helm := _item(&"item_base_iron_helm", R.UNIQUE, [], 111)
	helm.sigils = [SIGIL_STORM_STRIKE]
	var ring := _item(&"item_base_band", R.UNIQUE, [], 112)
	ring.sigils = [SIGIL_STORM_STRIKE]
	p.equipment.equip(helm)
	p.equipment.equip(ring)
	_check("two items with Storm Strike: its rule once (the augment id counts once)", _rule_sources(p).count(&"augment_sigil_storm_strike"), 1)
	Reactions.rng.seed = 4242
	var bolts := _bolts_from(p, _dummy_near(p), 1000, 1.0)
	_report(absi(bolts.size() - 150) <= 45, "still about 15% of 1,000 hits, not 30%", "got %d" % bolts.size())
	p.equipment.unequip(&"helm")
	_check("one taken off: the other keeps it", _rule_sources(p).count(&"augment_sigil_storm_strike"), 1)
	p.equipment.unequip(&"ring_1")
	_check("both off: gone", _rule_sources(p).count(&"augment_sigil_storm_strike"), 0)
	var exotic := _item(&"item_base_pendant", R.EXOTIC, [], 113)
	exotic.sigils = [SIGIL_BLOODRUSH, SIGIL_EXPOSE]
	p.equipment.equip(exotic)
	_check("an Exotic: both its sigils' rules on",
		[_rule_sources(p).count(&"augment_sigil_bloodrush"), _rule_sources(p).count(&"augment_sigil_expose")], [1, 1])
	var stunned := _dummy_near(p)
	stunned.status_component.apply_status(STATUS_STUN, p)
	_kill(p, _dummy_near(p, false))
	_check("both fire, each on its own trigger (a stun Exposes, a kill rushes)",
		[stunned.status_component.has_status(&"exposed"), p.status_component.has_status(&"bloodrush")], [true, true])
	p.equipment.unequip(&"amulet")
	_check("unequipped: both rules gone",
		[_rule_sources(p).has(&"augment_sigil_bloodrush"), _rule_sources(p).has(&"augment_sigil_expose")], [false, false])
	await _free_dummies()
	await _free(p)


# --- L5: named items, part 1 ------------------------------------------------------

func _test_named_data() -> void:
	_section("L5: the Knight's named items, part 1 (LOOT.md, The Knight's named items)")
	_check("the Knight lists his five, in the table's order (L6 added Homeward Greaves and The Last Verdict)",
		KNIGHT.named_items, [TIDEBREAKER, OATHBOUND_PLATE, HOMEWARD_GREAVES, CHAINS_OF_JUDGEMENT, LAST_VERDICT])
	var rows := [
		# item, name, slot, augment id, kind, ability, affix ids
		[TIDEBREAKER, "Tidebreaker", S.WEAPON, &"cleave_wave", AbilityAugment.Kind.REPLACE, &"knight_cleave",
			[&"affix_attack_damage", &"affix_core_damage", &"affix_crit_chance"]],
		[OATHBOUND_PLATE, "Oathbound Plate", S.CHEST, &"iron_resolve_undying", AbilityAugment.Kind.FLAG, &"knight_iron_resolve",
			[&"affix_max_health", &"affix_armor", &"affix_tenacity"]],
		[CHAINS_OF_JUDGEMENT, "Chains of Judgement", S.GLOVES, &"judgement_drag", AbilityAugment.Kind.FLAG, &"knight_judgement",
			[&"affix_attack_damage", &"affix_attack_speed", &"affix_crit_damage"]],
	]
	for row: Array in rows:
		var named: NamedItem = row[0]
		_check("%s: Legendary, the Knight's, its slot, its augment on its ability, its 3 fixed affixes, weight 1" % row[1],
			[named.display_name, named.rarity, named.champion_id, named.base.slot, named.augment.id, named.augment.kind,
				named.get_ability_id(), named.affixes.map(func(a: Affix) -> StringName: return a.id), named.drop_weight],
			[row[1], R.LEGENDARY, &"knight", row[2], row[3], row[4], row[5], row[6], 1.0])
		_check("%s validates" % row[1], named.get_validation_errors(KNIGHT), PackedStringArray())
	_check("Chains of Judgement's fixed modifier: +50% Judgement range; the others have none",
		[_named_mod_rows(CHAINS_OF_JUDGEMENT), TIDEBREAKER.modifiers.size(), OATHBOUND_PLATE.modifiers.size()],
		[[[&"cast_range", StatModifier.Type.PERCENT_ADD, 0.5, &"ability:knight_judgement"]], 0, 0])
	_check("Tidebreaker is the existing Cleave Wave", TIDEBREAKER.augment.replacement == CLEAVE_WAVE, true)
	_check("Cleave Wave costs Cleave's 20 Fury (L5: it was free)", [CLEAVE_WAVE.resource_cost, CLEAVE.resource_cost], [20.0, 20.0])
	_check("get_named_item(): by id; an unknown id: null",
		[KNIGHT.get_named_item(&"knight_tidebreaker") == TIDEBREAKER, KNIGHT.get_named_item(&"knight_nope")], [true, null])
	_check("status_undying: a 1.5 s buff tagged undying, refreshed, never cc",
		[STATUS_UNDYING.id, _plain(STATUS_UNDYING.tags), STATUS_UNDYING.duration, STATUS_UNDYING.stack_rule, STATUS_UNDYING.is_cc()],
		[&"undying", [&"undying", &"buff"], 1.5, StatusEffect.StackRule.REFRESH, false])
	_check("Iron Resolve supports iron_resolve_undying (1.5 s); Judgement judgement_drag (8 px from his edge, 0.15 s)",
		[IRON_RESOLVE.supported_flags.has(&"iron_resolve_undying"), IRON_RESOLVE.get(&"flag_undying_duration"),
			JUDGEMENT.supported_flags.has(&"judgement_drag"), JUDGEMENT.get(&"flag_drag_gap_px"), JUDGEMENT.get(&"flag_drag_time")],
		[true, 1.5, true, 8.0, 0.15])


func _test_named_validation() -> void:
	_section("L5: NamedItem validation catches each broken rule")
	var bogus_flag := AbilityAugment.new()
	bogus_flag.id = &"judgement_bogus"
	bogus_flag.scope = &"ability:knight_judgement"
	var foreign_ability := AbilityAugment.new()
	foreign_ability.id = &"fireball_twice"
	foreign_ability.scope = &"ability:mage_fireball"
	var bare_replace := AbilityAugment.new()
	bare_replace.id = &"judgement_nothing"
	bare_replace.kind = AbilityAugment.Kind.REPLACE
	bare_replace.scope = &"ability:knight_judgement"
	var wrong_variant: AbilityAugment = bare_replace.duplicate()
	wrong_variant.replacement = CLEAVE_WAVE
	var flagless_wave: Ability = CLEAVE_WAVE.duplicate()
	flagless_wave.supported_flags = [&"cleave_whirl"]
	var flagless: AbilityAugment = TIDEBREAKER.augment.duplicate()
	flagless.replacement = flagless_wave
	var cases := [
		["an id without the champion's prefix", func(n: NamedItem) -> void: n.id = &"tidebreaker", "must start with knight_"],
		["no name", func(n: NamedItem) -> void: n.display_name = " ", "no display_name"],
		["a Rare", func(n: NamedItem) -> void: n.rarity = R.RARE, "Legendary or Artifact"],
		["another champion's", func(n: NamedItem) -> void: n.champion_id = &"mage", "isn't knight"],
		["no base", func(n: NamedItem) -> void: n.base = null, "no base"],
		["a drop weight of 0", func(n: NamedItem) -> void: n.drop_weight = 0.0, "drop_weight"],
		["an affix twice", func(n: NamedItem) -> void: n.affixes = [n.affixes[0], n.affixes[0]], "twice"],
		["no augment", func(n: NamedItem) -> void: n.augment = null, "no augment"],
		["a sigil (EVENT) as its augment", func(n: NamedItem) -> void: n.augment = SIGIL_STORM_STRIKE, "is an EVENT"],
		["an augment on none of the Knight's abilities", func(n: NamedItem) -> void: n.augment = foreign_ability, "not ability:<one of knight"],
		["a FLAG the ability doesn't support", func(n: NamedItem) -> void: n.augment = bogus_flag, "isn't in knight_judgement's supported_flags"],
		["a REPLACE with no variant", func(n: NamedItem) -> void: n.augment = bare_replace, "no replacement"],
		["a REPLACE whose variant replaces another ability", func(n: NamedItem) -> void: n.augment = wrong_variant, "not 'knight_judgement'"],
		["a REPLACE variant missing a talent FLAG (Rending Cleave's)", func(n: NamedItem) -> void: n.augment = flagless, "talent FLAG 'cleave_rend'"],
		["an ability: modifier on another ability", func(n: NamedItem) -> void:
			n.modifiers = [StatModifier.create(&"cast_range", StatModifier.Type.PERCENT_ADD, 0.5, &"", &"ability:knight_cleave")], "only on its own ability"],
		["a param the ability doesn't have", func(n: NamedItem) -> void:
			n.modifiers = [StatModifier.create(&"no_such_param", StatModifier.Type.FLAT, 1.0, &"", &"ability:knight_judgement")], "isn't a param of knight_judgement"],
		["an unknown stat", func(n: NamedItem) -> void:
			n.modifiers = [StatModifier.create(&"no_such_stat", StatModifier.Type.FLAT, 1.0, &"")], "unknown stat"],
	]
	for c: Array in cases:
		var n: NamedItem = CHAINS_OF_JUDGEMENT.duplicate()
		(c[1] as Callable).call(n)
		_check_error(c[0], _join(n.get_validation_errors(KNIGHT)), c[2])
	# Its siblings: named items for one ability share an item slot; ids are unique.
	var helm_chains: NamedItem = CHAINS_OF_JUDGEMENT.duplicate()
	helm_chains.id = &"knight_helm_chains"
	helm_chains.base = _table.get_base(&"item_base_iron_helm")
	var same_id: NamedItem = OATHBOUND_PLATE.duplicate()
	var more_chains: NamedItem = CHAINS_OF_JUDGEMENT.duplicate()
	more_chains.id = &"knight_more_chains"
	var champ := _knight_with([helm_chains, same_id, more_chains])
	_check_error("two named items for Judgement in different item slots", _join(helm_chains.get_validation_errors(champ)), "aren't in one item slot")
	_check_error("two named items with one id", _join(same_id.get_validation_errors(champ)), "has the id 'knight_oathbound_plate'")
	_check("another Judgement item in the Gloves is fine (the two can never be worn together)",
		more_chains.get_validation_errors(_knight_with([more_chains])), PackedStringArray())
	_check("named affixes may ignore the pool's slot lists (tenacity on a chest)", _table.get_affix(&"affix_tenacity").slots.has(S.CHEST), false)


func _test_named_rolls() -> void:
	_section("L5: Legendary and Artifact rolls (the champion's named items; the Exotic fallback)")
	var rng := _rng(5505)
	var def := _table.get_rarity(R.LEGENDARY)
	var counts := {}
	var shape_ok := true
	var band_ok := true
	var rolls := {}
	for i in 600:
		var item := ItemRoller.roll_item(R.LEGENDARY, KNIGHT, _table, rng)
		shape_ok = shape_ok and item != null and item.named != null and item.rarity == R.LEGENDARY and item.sigils.is_empty() \
			and item.base == item.named.base and item.get_champion_id() == &"knight" \
			and item.affix_rolls.map(func(p: Array) -> StringName: return (p[0] as Affix).id) == item.named.affixes.map(func(a: Affix) -> StringName: return a.id)
		if item == null or item.named == null:
			continue
		counts[item.named.id] = int(counts.get(item.named.id, 0)) + 1
		for k in item.affix_rolls.size():
			var affix: Affix = item.affix_rolls[k][0]
			var span := affix.get_band_range(def.roll_min, def.roll_max)
			var value := item.get_affix_value(k, _table)
			band_ok = band_ok and value >= span.x - affix.step * 0.5 - 0.000001 and value <= span.y + affix.step * 0.5 + 0.000001
			rolls[item.affix_rolls[k][1]] = true
	_check("600 Legendaries for the Knight: each one of his named items, its base, its affixes in order, no sigils", shape_ok, true)
	var even := counts.size() == 4
	for id: StringName in counts:
		even = even and absf(counts[id] / 600.0 - 1.0 / 4.0) < 0.06
	_report(even, "each about a quarter of them (drop weight 1 each; four since L6)", str(counts))
	_check("their values inside the Legendary band (0.55–0.95) of each range", band_ok, true)
	_check("and rolled, not fixed (many different rolls)", rolls.size() > 100, true)
	var artifact := ItemRoller.roll_item(R.ARTIFACT, KNIGHT, _table, rng)
	_check("an Artifact for the Knight: The Last Verdict (since L6), no sigils", [artifact.rarity, artifact.named, artifact.sigils.size()], [R.ARTIFACT, LAST_VERDICT, 0])
	var no_artifact := ItemRoller.roll_item(R.ARTIFACT, _knight_without(LAST_VERDICT), _table, rng)
	_check("for a champion with no Artifact: an Exotic, with its two sigils", [no_artifact.rarity, no_artifact.named, no_artifact.sigils.size()], [R.EXOTIC, null, 2])
	var nobody := ItemRoller.roll_item(R.LEGENDARY, null, _table, rng)
	_check("a Legendary with no champion: an Exotic", [nobody.rarity, nobody.named], [R.EXOTIC, null])
	_check("a Legendary for the Chest slot: Oathbound Plate", ItemRoller.roll_item(R.LEGENDARY, KNIGHT, _table, rng, S.CHEST).named, OATHBOUND_PLATE)
	var helm := ItemRoller.roll_item(R.LEGENDARY, KNIGHT, _table, rng, S.HELM)
	_check("a Legendary for the Helm slot (the Knight has none): an Exotic helm", [helm.rarity, helm.named, helm.base.slot], [R.EXOTIC, null, S.HELM])
	# An Artifact: always its maximum, with no draw (The Last Verdict since L6).
	var verdict := LAST_VERDICT
	var max_ok := true
	for i in 50:
		var item := ItemRoller.roll_item(R.ARTIFACT, KNIGHT, _table, rng)
		max_ok = max_ok and item.named == verdict and item.affix_rolls.all(func(p: Array) -> bool: return p[1] == 1.0)
	_check("50 Artifacts (The Last Verdict): every affix roll 1", max_ok, true)
	var state_before := rng.state
	var made := ItemRoller.make_named(verdict, _table, rng)
	_check("make_named() of an Artifact draws nothing", rng.state, state_before)
	var at_max := true
	for k in made.affix_rolls.size():
		var affix: Affix = made.affix_rolls[k][0]
		at_max = at_max and is_equal_approx(made.get_affix_value(k, _table), affix.get_value(0.0, 1.0, 1.0))
	_check("its values are each affix's maximum", at_max, true)
	var legend := ItemRoller.make_named(TIDEBREAKER, _table, _rng(77))
	_check("make_named(): that item, uid 0, its rarity and base, its 3 affixes",
		[legend.named, legend.uid, legend.rarity, legend.base, legend.affix_rolls.size()], [TIDEBREAKER, 0, R.LEGENDARY, TIDEBREAKER.base, 3])


func _test_named_items() -> void:
	_section("L5: a named item's name, tooltip and save; worn once; its champion's only")
	var tide := ItemRoller.make_named(TIDEBREAKER, _table, _rng(81))
	tide.uid = 7
	var lines := tide.get_tooltip_lines(_table)
	_check("Tidebreaker: its own name, in the Legendary color, a Legendary Weapon",
		[tide.get_display_name(), tide.get_color(_table), lines[1]], ["Tidebreaker", _table.get_rarity(R.LEGENDARY).color, "Legendary Weapon"])
	_check("its tooltip: the implicit, its 3 affixes, then its augment",
		[lines.size(), lines[2], lines[6]], [7, "+6 Attack Damage", "Cleave Wave: " + TIDEBREAKER.augment.description])
	_check("its augment is given to its wearer", tide.get_augments(), [TIDEBREAKER.augment])
	var chains := ItemRoller.make_named(CHAINS_OF_JUDGEMENT, _table, _rng(82))
	chains.uid = 8
	var chain_lines := chains.get_tooltip_lines(_table)
	_check("Chains of Judgement's tooltip ends with its fixed modifier (naming Judgement) and its augment",
		[chain_lines[chain_lines.size() - 2], chain_lines[chain_lines.size() - 1]],
		["+50% Cast Range (Judgement)", "Chains: " + CHAINS_OF_JUDGEMENT.augment.description])
	var mods := _mod_rows(chains)
	_check("its modifiers: the implicit, the 3 affixes, then the fixed one, all under item_8",
		[mods.size(), mods[mods.size() - 1]], [5, [&"cast_range", StatModifier.Type.PERCENT_ADD, 0.5, &"ability:knight_judgement", &"item_8"]])
	# The save: by its named id, read back through its champion.
	var d := tide.to_dict()
	_check("saved with its named id", [d.get("named"), d["base"], d["rarity"]], ["knight_tidebreaker", "item_base_longsword", "legendary"])
	var back := Item.from_dict(d, _table, KNIGHT)
	_check("read back through the Knight: the same item, rolls and all",
		back != null and back.named == TIDEBREAKER and back.to_dict() == d and _mod_rows(back) == _mod_rows(tide), true)
	_check("without its champion, or for a champion without it: unreadable (kept raw)",
		[Item.from_dict(d, _table), Item.from_dict(d, _table, _knight_with_none())], [null, null])
	var drifted := d.duplicate(true)
	drifted["base"] = "item_base_band"
	drifted["rarity"] = "common"
	drifted["affixes"] = [d["affixes"][0], ["affix_gone", 0.4]]
	var fixed := Item.from_dict(drifted, _table, KNIGHT)
	_check("the named item's data wins: its base, rarity and affix list; a missing roll is the band's middle, an unknown one dropped (expect 3 warnings)",
		[fixed.base, fixed.rarity, fixed.affix_rolls.map(func(p: Array) -> StringName: return (p[0] as Affix).id), fixed.affix_rolls.map(func(p: Array) -> float: return p[1])],
		[TIDEBREAKER.base, R.LEGENDARY, [&"affix_attack_damage", &"affix_core_damage", &"affix_crit_chance"], [d["affixes"][0][1], 0.5, 0.5]])
	var verdict_champ := _knight_with([_fixture_artifact()])
	var art := ItemRoller.make_named(verdict_champ.get_named_item(&"knight_test_verdict"), _table, _rng(1))
	var ad := art.to_dict()
	ad["affixes"][0][1] = 0.3
	_check("an Artifact's saved roll reads back as 1 (always its maximum)", Item.from_dict(ad, _table, verdict_champ).affix_rolls[0][1], 1.0)
	var inv := ChampionInventory.create(KNIGHT)
	inv.add(ItemRoller.make_named(OATHBOUND_PLATE, _table, _rng(3)))
	inv.add(_item(&"item_base_band", R.RARE, [[&"affix_crit_chance", 0.5]], 0))
	var read := _through_text(inv)
	_check("an inventory through a ConfigFile's text keeps it", read != null and read.items.size() == 2 and read.items[0].named == OATHBOUND_PLATE
		and read.items[0].to_dict() == inv.items[0].to_dict(), true)
	var other_inv := ChampionInventory.create(KNIGHT)
	other_inv.add(art)
	var cfg := ConfigFile.new()
	other_inv.write_to(cfg)
	var lost := ChampionInventory.read_from(cfg, KNIGHT, _table)   # expect a warning
	var cfg_again := ConfigFile.new()
	lost.write_to(cfg_again)
	_check("a named item its champion no longer has: kept raw and written back (expect a warning)",
		[lost.items.size(), lost.get_unreadable_count(), cfg_again.encode_to_text().contains("knight_test_verdict")], [0, 1, true])
	# Equipping: its champion's only; worn once.
	Loot.reset(KNIGHT)
	var p := await _spawn_knight()
	var foreign_named: NamedItem = TIDEBREAKER.duplicate()
	foreign_named.champion_id = &"mage"
	var foreign := ItemRoller.make_named(foreign_named, _table, _rng(4))
	foreign.uid = 601
	_check("another champion's named item: refused", p.equipment.can_equip(foreign), "Mage only")
	var ring_named: NamedItem = OATHBOUND_PLATE.duplicate()
	ring_named.id = &"knight_test_ring"
	ring_named.base = _table.get_base(&"item_base_band")
	var first := ItemRoller.make_named(ring_named, _table, _rng(5))
	first.uid = 602
	var second := ItemRoller.make_named(ring_named, _table, _rng(6))
	second.uid = 603
	p.equipment.equip(first)
	_check("a second copy of a worn named item (a fixture ring): refused in the other ring slot",
		p.equipment.can_equip(second, &"ring_2"), "Oathbound Plate is already equipped (ring_1)")
	_check("and by equip() (which picks the empty ring slot)", [p.equipment.equip(second), p.equipment.get_item(&"ring_2")], [false, null])
	_check("it may replace the first copy in its own slot", [p.equipment.equip(second, &"ring_1"), p.equipment.get_item(&"ring_1") == second], [true, true])
	p.equipment.unequip(&"ring_1")
	await _free(p)


func _test_tidebreaker() -> void:
	_section("L5: Tidebreaker (Q becomes Cleave Wave; with every Cleave talent)")
	Loot.reset(KNIGHT)
	var p := await _spawn_knight()
	p.resource_pool.restore(1000.0)
	_equip_named(p, TIDEBREAKER, 701)
	_check("worn: Q casts Cleave Wave, for Cleave's 20 Fury", [p.abilities.get_ability(&"q"), p.abilities.get_slot_cost(&"q")], [CLEAVE_WAVE, 20.0])
	var reach := CLEAVE_WAVE.get_param(p, &"cast_range")
	var thrifty := KNIGHT.get_talent(&"knight_thrifty_edge")
	p.add_talent(thrifty)
	_check("Thrifty Edge reaches the wave: 15 Fury", p.abilities.get_slot_cost(&"q"), 15.0)
	p.remove_talent(thrifty)
	var long_reach := KNIGHT.get_talent(&"knight_long_reach")
	p.add_talent(long_reach)
	_check_near("Long Reach reaches it: +25% range (700 → 875)", CLEAVE_WAVE.get_param(p, &"cast_range"), reach * 1.25, 0.01)
	p.remove_talent(long_reach)
	var uses_before := Progress.get_progress(KNIGHT).get_ability_uses(&"knight_cleave")
	for pair: Array in [[&"knight_whirling_cleave", &"cleave_whirl"], [&"knight_rending_cleave", &"cleave_rend"]]:
		var talent := KNIGHT.get_talent(pair[0])
		p.add_talent(talent)
		var cast := await _cast_and_watch(p, &"q", p.global_position + Vector2(100, 0), null)
		_check("%s: the wave is cast with its FLAG (%s)" % [talent.display_name, pair[1]],
			[cast.get("ability") == CLEAVE_WAVE, cast.get("flag_" + String(pair[1]), false)], [true, true])
		p.remove_talent(talent)
		p.abilities.reset_cooldown(&"q")
	_check("each wave counts as a Cleave cast (2 more)", Progress.get_progress(KNIGHT).get_ability_uses(&"knight_cleave") - uses_before, 2)
	p.equipment.unequip(&"weapon")
	_check("taken off: Q is Cleave again", p.abilities.get_ability(&"q"), CLEAVE)
	await _free(p)


func _test_undying() -> void:
	_section("L5: Undying (status_undying keeps the last 1 health; Unit.on_hit())")
	Loot.reset(KNIGHT)
	_dummy_offset = 0.0
	var p := await _spawn_knight()
	var died := [0]
	var on_died := func(unit: Unit, _ctx: HitContext) -> void:
		if unit == p:
			died[0] += 1
	Events.unit_died.connect(on_died)
	var hitter := _dummy_near(p)
	p.status_component.apply_status(STATUS_UNDYING, p)
	var before := p.health.current
	var blow := _hit_from(hitter, p, 1000000.0)
	_check("a killing blow while Undying: 1 health left, alive, not killed", [p.health.current, p.is_alive(), blow.killed], [1.0, true, false])
	_check("its number is what was taken (all but the last 1)", blow.taken_damage, before - 1.0)
	await _wait_vulnerable(p)
	var again := _hit_from(hitter, p, 500.0)
	_check("another hit at 1 health: nothing taken, still 1", [again.taken_damage, p.health.current], [0.0, 1.0])
	await _wait_vulnerable(p)
	var tick := HitContext.new()
	tick.source = hitter
	tick.target = p
	tick.base_damage = 500.0
	tick.can_crit = false
	tick.add_tag(&"dot")
	HitPipeline.resolve(tick)
	_check("a DoT tick too: still 1, no death", [p.health.current, p.is_alive(), died[0]], [1.0, true, 0])
	p.health.heal(99.0)
	var shield: StatusEffect = STATUS_SHIELD.duplicate()
	shield.shield_amount = 50.0
	p.status_component.apply_status(shield, p)
	await _wait_vulnerable(p)
	var shielded := _hit_from(hitter, p, 1000000.0)
	_check("with a shield: the shield takes its 50 first, then all but 1 health", [shielded.absorbed, p.health.current, shielded.taken_damage], [50.0, 1.0, 149.0])
	p.status_component.apply_status(STATUS_UNDYING, p, 0.5)
	await _wait_hitstop()
	await _frames(40)
	_check("it ends on time (0.5 s here)", p.status_component.has_status(&"undying"), false)
	await _wait_vulnerable(p)
	_hit_from(hitter, p, 1000000.0)
	_check("then a killing blow kills", [p.is_alive(), died[0]], [false, 1])
	Events.unit_died.disconnect(on_died)
	await _free_dummies()
	await _free(p)


func _test_oathbound_plate() -> void:
	_section("L5: Oathbound Plate (Iron Resolve also makes the Knight Undying; with every W talent)")
	var plain := await _iron_resolve_case(&"", false)
	_check("without it: Iron Resolve gives no Undying", plain.undying, false)
	var base := await _iron_resolve_case(&"", true)
	_check("worn: Iron Resolve makes the Knight Undying for 1.5 s, on top of its haste and empower",
		[base.undying, base.undying_left_ok, base.haste, base.empower], [true, true, true, true])
	var challenge := await _iron_resolve_case(&"knight_challenge", true)
	_check("with Challenge: Undying, and the enemy nearby Staggered (no haste)",
		[challenge.undying, challenge.staggered, challenge.haste], [true, true, false])
	var bulwark := await _iron_resolve_case(&"knight_bulwark", true)
	_check("with Bulwark: Undying, the shield and the haste (no empower)",
		[bulwark.undying, bulwark.shield > 0.0, bulwark.haste, bulwark.empower], [true, true, true, false])
	var quick := await _iron_resolve_case(&"knight_quick_recovery", true)
	_check_near("with Quick Recovery: Undying, on a 6.5 s cooldown (more often)", quick.cooldown_left, 6.5, 0.1)
	_check("(Undying)", quick.undying, true)
	var cry := await _iron_resolve_case(&"knight_battle_cry", true)
	_check("with Battle Cry: Undying, and its 15 Fury", [cry.undying, cry.fury_gained >= 14.0], [true, true])


func _test_chains_of_judgement() -> void:
	_section("L5: Chains of Judgement (+50% range; the drag through the air, before the hit)")
	Loot.reset(KNIGHT)
	var p := await _spawn_knight()
	var plain_range := JUDGEMENT.get_param(p, &"cast_range")
	_equip_named(p, CHAINS_OF_JUDGEMENT, 901)
	_check("Judgement's range: 450 → 675 with it", [plain_range, JUDGEMENT.get_param(p, &"cast_range")], [450.0, 675.0])
	var long_arm := KNIGHT.get_talent(&"knight_long_arm")
	p.add_talent(long_arm)
	_check("with Long Arm: +80% (the two add): 810", JUDGEMENT.get_param(p, &"cast_range"), 810.0)
	p.remove_talent(long_arm)
	var swift := KNIGHT.get_talent(&"knight_swift_verdict")
	p.add_talent(swift)
	_check("with Swift Verdict: its 24 s cooldown, unchanged by the item", JUDGEMENT.get_param(p, &"cooldown"), 24.0)
	p.remove_talent(swift)
	await _free(p)
	var gap := Units.to_px(35.0) + Units.to_px(45.0) + 8.0   # the Knight's and the slime's pathing radii, then the gap
	var open := await _drag_case(Vector2(180, 0))
	_check("cast at 180 px (in range only with the item): the target is airborne during the drag", [open.cast, open.airborne_seen], [true, true])
	_check_near("the hit lands with it next to the Knight, 8 px from his edge", open.get("distance", 0.0), gap, 1.5)
	_report(open.frames >= 8 and open.frames <= 11, "the hit lands when the drag ends (0.15 s: 9 frames)", "got %d" % open.frames)
	_check("and stuns it", open.stunned, true)
	var fence_push := await _push_case(7)
	var ledge_push := await _push_case(11)
	_check("(control: pushed along the ground, not lifted, a slime stops at the same fence and ledge)",
		[fence_push > 90.0, ledge_push > 90.0], [true, true])
	var fence := await _drag_case(Vector2(180, 0), [[7, Rect2(Vector2(90, 0) - Vector2(4, 60), Vector2(8, 120))]])
	_check_near("over a fence (layer 7) in between: lifted over it, next to the Knight", fence.get("distance", 0.0), gap, 1.5)
	var ledge := await _drag_case(Vector2(180, 0), [[11, Rect2(Vector2(90, 0) - Vector2(4, 60), Vector2(8, 120))]])
	_check_near("off a plateau (a ledge, layer 11, in between): lifted over it", ledge.get("distance", 0.0), gap, 1.5)
	var slit := await _drag_case(Vector2(180, 0), [[1, Rect2(Vector2(86, -62), Vector2(8, 60))], [1, Rect2(Vector2(86, 2), Vector2(8, 60))]])
	_report(slit.cast and slit.get("hit", false) and slit.get("distance", 0.0) > 90.0 and slit.get("distance", 0.0) < 130.0 and slit.moved > 40.0,
		"a wall with a slit the sight passes but the body can't: stopped at the wall, and the hit lands there",
		"cast %s, hit %s, distance %s, moved %s" % [slit.cast, slit.get("hit", false), slit.get("distance", 0.0), slit.moved])
	var still := await _drag_case(Vector2(120, 0), [], &"", true)
	_check("an unstoppable target: not lifted, not moved; the hit still lands",
		[still.airborne_seen, still.moved < 1.0, still.get("hit", false), still.get("taken", 0.0) > 0.0], [false, true, true, true])
	var shock := await _drag_case(Vector2(180, 0), [], &"knight_shockwave", false, true, Vector2(0, 60))
	_check("with Shockwave: the splash hits around where the target lands (next to the Knight)",
		[shock.get("hit", false), shock.bystander_hit], [true, true])
	var execute := await _drag_case(Vector2(180, 0), [], &"knight_executioner")
	_check_near("with Executioner: dragged all the same", execute.get("distance", 0.0), gap, 1.5)
	var none := await _drag_case(Vector2(120, 0), [], &"", false, false)
	_check("without it: no drag (the target stays where it is)", [none.get("hit", false), none.airborne_seen, none.moved < 1.0], [true, false, true])


# --- L6: named items, part 2 -------------------------------------------------------

func _test_l6_data() -> void:
	_section("L6: Homeward Greaves and The Last Verdict (data; CastContext.sequence)")
	var rows := [
		# item, name, rarity, slot, augment id, ability, variant, affix ids
		[HOMEWARD_GREAVES, "Homeward Greaves", R.LEGENDARY, S.BOOTS, &"lunge_return", &"knight_lunge", LUNGE_RETURN,
			[&"affix_move_speed", &"affix_mobility_cooldown", &"affix_armor"]],
		[LAST_VERDICT, "The Last Verdict", R.ARTIFACT, S.GLOVES, &"judgement_leap", &"knight_judgement", JUDGEMENT_LEAP,
			[&"affix_attack_damage", &"affix_crit_chance", &"affix_crit_damage", &"affix_ability_haste"]],
	]
	for row: Array in rows:
		var named: NamedItem = row[0]
		_check("%s: %s, the Knight's, its slot, a REPLACE of %s by its variant, its fixed affixes, no fixed modifier, weight 1" % [row[1], Item.rarity_to_word(row[2]), row[5]],
			[named.display_name, named.rarity, named.champion_id, named.base.slot, named.augment.id, named.augment.kind,
				named.get_ability_id(), named.augment.replacement, named.affixes.map(func(a: Affix) -> StringName: return a.id),
				named.modifiers.size(), named.drop_weight],
			[row[1], row[2], &"knight", row[3], row[4], AbilityAugment.Kind.REPLACE, row[5], row[6], row[7], 0, 1.0])
		_check("%s validates" % row[1], named.get_validation_errors(KNIGHT), PackedStringArray())
	_check("Homeward Lunge: Lunge's script, a variant of it with one recast in a 2.5 s window, Lunge's flags and tags plus blink (AB15: the return is one)",
		[LUNGE_RETURN.id, LUNGE_RETURN.get_script() == LUNGE.get_script(), LUNGE_RETURN.variant_of, LUNGE_RETURN.recast_count,
			LUNGE_RETURN.recast_window, _plain(LUNGE_RETURN.supported_flags), _plain(LUNGE_RETURN.tags)],
		[&"knight_lunge_return", true, &"knight_lunge", 1, 2.5, [&"lunge_stuns", &"lunge_tackle"], _plain(LUNGE.tags) + [&"blink"]])
	_check("and Lunge's numbers (POINT, 400 range, 8 s, 50 + 50% AD, 0.05 s cast, its speed, its Stagger bonus)",
		[LUNGE_RETURN.targeting, LUNGE_RETURN.cast_range, LUNGE_RETURN.cooldown, LUNGE_RETURN.base_damage, LUNGE_RETURN.ad_ratio,
			LUNGE_RETURN.cast_time, LUNGE_RETURN.get(&"dash_speed"), LUNGE_RETURN.conditional_bonuses.size()],
		[LUNGE.targeting, LUNGE.cast_range, LUNGE.cooldown, LUNGE.base_damage, LUNGE.ad_ratio, LUNGE.cast_time, LUNGE.get(&"dash_speed"), 1])
	_check("Judgement Leap: its script extends Judgement's; a variant of Judgement, POINT, 500 range, a 0.2 s rooting cast (not a channel), 30 s",
		[JUDGEMENT_LEAP.id, (JUDGEMENT_LEAP.get_script() as Script).get_base_script() == JUDGEMENT.get_script(), JUDGEMENT_LEAP.variant_of,
			JUDGEMENT_LEAP.targeting, JUDGEMENT_LEAP.cast_range, JUDGEMENT_LEAP.cast_time, JUDGEMENT_LEAP.roots_during_cast,
			JUDGEMENT_LEAP.is_channel(), JUDGEMENT_LEAP.cooldown],
		[&"knight_judgement_leap", true, &"knight_judgement", Ability.Targeting.POINT, 500.0, 0.2, true, false, 30.0])
	_check("tagged ultimate, area and leap (not dash, not melee); supports Shockwave",
		[_plain(JUDGEMENT_LEAP.tags), _plain(JUDGEMENT_LEAP.supported_flags)], [[&"ultimate", &"area", &"leap"], [&"judgement_shockwave"]])
	var fury_rows := func(a: Ability) -> Array:
		var out: Array = []
		for b in a.conditional_bonuses:
			out.append([b.conditions.map(func(c: Condition) -> Array: return [c.kind, c.value]),
				b.modifiers.map(func(m: StatModifier) -> Array: return [m.stat, m.type, m.value])])
		return out
	_check("Judgement's hit: 150 + 100% AD + 20% of missing health, a 0.75 s stun, Judgement's Fury bonus (60+: +0.5 s, +30%), spent on a hit",
		[JUDGEMENT_LEAP.base_damage, JUDGEMENT_LEAP.ad_ratio, JUDGEMENT_LEAP.get_base_param(&"target_missing_health_ratio"),
			JUDGEMENT_LEAP.get(&"stun_duration"), fury_rows.call(JUDGEMENT_LEAP), JUDGEMENT_LEAP.get(&"consume_resource_on_bonus")],
		[150.0, 1.0, 0.2, 0.75, fury_rows.call(JUDGEMENT), true])
	_check("the leap 0.3 s; the landing circle 220 u; Shockwave's ring 370 u at 50% with a 0.5 s stun",
		[JUDGEMENT_LEAP.get(&"leap_time"), JUDGEMENT_LEAP.get(&"landing_radius"), JUDGEMENT_LEAP.get(&"flag_shockwave_ring_radius"),
			JUDGEMENT_LEAP.get(&"flag_shockwave_damage_ratio"), JUDGEMENT_LEAP.get(&"flag_shockwave_stun_duration")],
		[0.3, 220.0, 370.0, 0.5, 0.5])
	_check("a new CastContext's sequence: an empty dictionary of its own",
		[CastContext.new().sequence, is_same(CastContext.new().sequence, CastContext.new().sequence)], [{}, false])


func _test_homeward_greaves() -> void:
	_section("L6: Homeward Greaves (the return to the exact start; the cooldown after the sequence)")
	Loot.reset(KNIGHT)
	_dummy_offset = 0.0
	var p := await _spawn_knight()
	_equip_named(p, HOMEWARD_GREAVES, 1001)
	_check("worn, E casts Homeward Lunge; its tooltip has the augment's line",
		[p.abilities.get_ability(&"e"), LUNGE_RETURN.get_tooltip_plain(p).contains("\nRecast Lunge within 2.5 s to blink back")], [LUNGE_RETURN, true])
	var origin := p.global_position
	var d := _dummy_near(p)
	d.global_position = origin + Vector2(60, 0)
	d.reset_physics_interpolation()
	await _frames(2)
	var casts: Array[CastContext] = []
	var hit_targets: Array = []
	var on_cast := func(unit: Unit, _ability: Ability, ctx: CastContext) -> void:
		if unit == p:
			casts.append(ctx)
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.source == p and ctx.ability == LUNGE_RETURN:
			hit_targets.append(ctx.target)
	Events.ability_cast.connect(on_cast)
	Events.unit_hit.connect(on_hit)
	await _wait_hitstop()
	p.abilities.try_cast(&"e", origin + Vector2(120, 0), null)
	await _wait_until(func() -> bool: return casts.size() == 1 and not p.abilities.casting, 60)
	await _wait_hitstop()
	_check_near("part 0 is the Lunge: to the aim, 120 px", (p.global_position - origin).x, 120.0, 0.5)
	_check("it hit the unit in its path, once", hit_targets, [d])
	_check("then the window: part 1 next, about 2.5 s to press, E still castable, no cooldown running yet",
		[p.abilities.get_recast_part(&"e"), p.abilities.get_recast_time_left(&"e") > 2.3, p.abilities.is_ready(&"e"), p.abilities.get_cooldown_left(&"e")],
		[1, true, true, 0.0])
	var start: Variant = casts[0].sequence.get(&"start")
	_check("part 0 left its start point in the sequence", start is Vector2 and (start as Vector2).distance_to(origin) < 0.01, true)
	await _frames(30)
	_check("half a second into the window: still no cooldown", p.abilities.get_cooldown_left(&"e"), 0.0)
	var health_before := d.health.current
	p.abilities.try_cast(&"e", origin + Vector2(200, 50), null)   # the aim doesn't matter
	await _wait_until(func() -> bool: return casts.size() == 2 and not p.abilities.casting, 60)
	_check("the recast is part 1, given part 0's sequence (the same dictionary)",
		[casts[1].part, is_same(casts[1].sequence, casts[0].sequence)], [1, true])
	_check_near("it blinked back to the exact start (AB15), past the unit on the way", p.global_position.distance_to(origin), 0.0, 0.5)
	_check("hitting nothing (the unit took nothing more)", [hit_targets.size(), d.health.current == health_before], [1, true])
	await _frames(1)
	var full := p.abilities.get_cooldown_duration(LUNGE_RETURN)
	_check("the sequence is over and the cooldown starts now (8 s less the item's mobility cooldown: %.2f s)" % full,
		[p.abilities.get_recast_part(&"e"), p.abilities.get_cooldown_left(&"e") > full - 0.1, full < 8.0], [0, true, true])
	_check("so a third press isn't ready", p.abilities.try_cast(&"e", origin + Vector2(50, 0), null), false)
	Events.ability_cast.disconnect(on_cast)
	Events.unit_hit.disconnect(on_hit)
	await _free_dummies()
	await _free(p)

	# The window running out: no return, the cooldown starts then.
	var q := await _spawn_knight()
	q.abilities.add_augment(AUGMENT_LUNGE_RETURN, &"loot_test_return")
	var q_origin := q.global_position
	await _wait_hitstop()
	q.abilities.try_cast(&"e", q_origin + Vector2(100, 0), null)
	await _wait_until(func() -> bool: return q.abilities.get_recast_part(&"e") == 1 and not q.abilities.casting, 60)
	await _frames(140)
	_check("2.33 s after the Lunge: the window is still open", [q.abilities.get_recast_part(&"e"), q.abilities.get_cooldown_left(&"e")], [1, 0.0])
	await _frames(20)
	_check("past 2.5 s it closed: the cooldown runs (its whole 8 s, less the few frames since), he stays where the Lunge took him",
		[q.abilities.get_recast_part(&"e"), q.abilities.get_cooldown_left(&"e") > 7.5, q.global_position.distance_to(q_origin + Vector2(100, 0)) < 0.5],
		[0, true, true])
	_check("and a press now isn't ready (no return)", q.abilities.try_cast(&"e", q_origin, null), false)
	await _free(q)

	# Moved during the window: the return still goes straight to the start.
	var w := await _spawn_knight()
	w.abilities.add_augment(AUGMENT_LUNGE_RETURN, &"loot_test_return")
	var w_origin := w.global_position
	await _wait_hitstop()
	w.abilities.try_cast(&"e", w_origin + Vector2(100, 0), null)
	await _wait_until(func() -> bool: return w.abilities.get_recast_part(&"e") == 1 and not w.abilities.casting, 60)
	w.movement.displace(Vector2(0.0, 50.0) / 0.25, 0.25)
	await _wait_until(func() -> bool: return not w.movement.is_displaced(), 60)
	_check_near("pushed 50 px aside during the window", w.global_position.distance_to(w_origin + Vector2(100, 50)), 0.0, 1.0)
	w.abilities.try_cast(&"e", w_origin, null)
	await _wait_until(func() -> bool: return w.abilities.get_recast_part(&"e") == 0 and not w.abilities.casting, 60)
	_check_near("the return still goes straight back to the start", w.global_position.distance_to(w_origin), 0.0, 0.5)
	await _free(w)


## ABILITIES AB15 (Ryan, 2026-10-04): the return is a blink.
func _test_homeward_blink() -> void:
	_section("AB15: Homeward Greaves' return is a blink (instant, over walls; refused while rooted)")
	_check("Homeward Lunge's Stagger line is Lunge's (L6 had overwritten it with the ability's description)",
		LUNGE_RETURN.conditional_bonuses[0].description, LUNGE.conditional_bonuses[0].description)
	Loot.reset(KNIGHT)
	var p := await _spawn_knight()
	p.abilities.add_augment(AUGMENT_LUNGE_RETURN, &"loot_test_return")
	var origin := p.global_position
	await _wait_hitstop()
	p.abilities.try_cast(&"e", origin + Vector2(100, 0), null)
	await _wait_until(func() -> bool: return p.abilities.get_recast_part(&"e") == 1 and not p.abilities.casting, 60)
	var out_at := p.global_position
	var wall := _blocker(Rect2(origin + Vector2(46, -60), Vector2(8, 120)), 1)
	await _frames(1)
	var blinks: Array = []
	var on_blink := func(a: Vector2, b: Vector2) -> void: blinks.append([a, b])
	p.movement.blinked.connect(on_blink)
	var path: Array[Vector2] = []
	p.abilities.try_cast(&"e", origin, null)
	for i in 8:
		await _frames(1)
		path.append(p.global_position)
	p.movement.blinked.disconnect(on_blink)
	var arrived := path.find_custom(func(v: Vector2) -> bool: return v.distance_to(origin) < 0.5)
	var never_between := path.all(func(v: Vector2) -> bool: return v.distance_to(origin) < 0.5 or v.distance_to(out_at) < 0.5)
	_check("over a wall between him and the start: at the start, by the cast's 0.05 s (3 frames), never in between (one blink)",
		[arrived >= 0 and arrived <= 3, never_between, blinks.size()], [true, true, 1])
	wall.queue_free()
	await _free(p)

	# Rooted in the window: the recast fails with its cue, and the window keeps running.
	var r := await _spawn_knight()
	r.abilities.add_augment(AUGMENT_LUNGE_RETURN, &"loot_test_return")
	var r_origin := r.global_position
	await _wait_hitstop()
	r.abilities.try_cast(&"e", r_origin + Vector2(100, 0), null)
	await _wait_until(func() -> bool: return r.abilities.get_recast_part(&"e") == 1 and not r.abilities.casting, 60)
	var root := StatusEffect.new()
	root.id = &"loot_test_root"
	root.tags = [&"cc", &"root", &"debuff"] as Array[StringName]
	root.blocks_move = true
	root.blocks_dash = true
	root.duration = 5.0
	r.status_component.apply_status(root, null)
	var reasons: Array = []
	var on_fail := func(_slot: StringName, reason: String) -> void: reasons.append(reason)
	r.abilities.cast_failed.connect(on_fail)
	var left_before := r.abilities.get_recast_time_left(&"e")
	var pressed := r.abilities.try_cast(&"e", r_origin, null)
	r.abilities.cast_failed.disconnect(on_fail)
	await _frames(12)
	_check("rooted: the recast fails with its cue (a condition: \"Rooted\"); he stays out",
		[pressed, reasons, r.global_position.distance_to(r_origin + Vector2(100, 0)) < 0.5], [false, [AbilityComponent.FAIL_CONDITION], true])
	_check("and the window keeps running (part 1 still next, its time going down)",
		[r.abilities.get_recast_part(&"e"), r.abilities.get_recast_time_left(&"e") < left_before - 0.1], [1, true])
	r.status_component.remove_status(root.id)
	r.abilities.try_cast(&"e", r_origin, null)
	await _wait_until(func() -> bool: return r.abilities.get_recast_part(&"e") == 0 and not r.abilities.casting, 60)
	_check_near("the root gone, inside the window: back to the start", r.global_position.distance_to(r_origin), 0.0, 0.5)
	await _free(r)


func _test_homeward_talents() -> void:
	_section("L6: Homeward Greaves with Tackle, Twin Lunge, Long Lunge and Quick Footing")
	Loot.reset(KNIGHT)
	_dummy_offset = 0.0
	# Tackle: part 0 tackles the first enemy (stunned), part 1 returns.
	var t := await _spawn_knight()
	t.add_talent(KNIGHT.get_talent(&"knight_tackle"))
	t.abilities.add_augment(AUGMENT_LUNGE_RETURN, &"loot_test_return")
	var t_origin := t.global_position
	var td := _dummy_near(t)
	td.global_position = t_origin + Vector2(70, 0)
	td.reset_physics_interpolation()
	await _frames(2)
	await _wait_hitstop()
	t.abilities.try_cast(&"e", t_origin + Vector2(120, 0), null)
	await _wait_until(func() -> bool: return t.abilities.get_recast_part(&"e") == 1 and not t.abilities.casting, 60)
	_check_near("with Tackle, part 0 stops at the enemy's edge", (t.global_position - t_origin).x,
		70.0 - td.get_gameplay_radius_px() - t.get_gameplay_radius_px(), 0.5)
	_check("and stuns it (Tackle's 0.75 s)", td.status_component.has_status(&"stun"), true)
	await _wait_hitstop()
	t.abilities.try_cast(&"e", t_origin, null)
	await _wait_until(func() -> bool: return t.abilities.get_recast_part(&"e") == 0 and not t.abilities.casting, 60)
	_check_near("part 1 gets him back out, to the start", t.global_position.distance_to(t_origin), 0.0, 0.5)
	await _free_dummies()
	await _free(t)

	# Twin Lunge: two charges, each with its return; the recharge waits out a sequence.
	var tw := await _spawn_knight()
	tw.add_talent(KNIGHT.get_talent(&"knight_twin_lunge"))
	tw.abilities.add_augment(AUGMENT_LUNGE_RETURN, &"loot_test_return")
	await _frames(1)
	tw.abilities.reset_cooldown(&"e")   # a talent added mid-run doesn't refill: its second charge now
	var tw_origin := tw.global_position
	_check("Twin Lunge reaches the variant through variant_of: 2 charges, 35% shorter (260)",
		[tw.abilities.get_max_charges(&"e"), LUNGE_RETURN.get_param(tw, &"cast_range")], [2, 260.0])
	await _wait_hitstop()
	tw.abilities.try_cast(&"e", tw_origin + Vector2(200, 0), null)
	await _wait_until(func() -> bool: return tw.abilities.get_recast_part(&"e") == 1 and not tw.abilities.casting, 60)
	_check_near("the first hop: 260 u (83.2 px)", (tw.global_position - tw_origin).x, Units.to_px(260.0), 0.5)
	_check("one charge left, the recharge not started during the sequence", [tw.abilities.get_charges(&"e"), tw.abilities.get_cooldown_left(&"e")], [1, 0.0])
	tw.abilities.try_cast(&"e", tw_origin, null)
	await _wait_until(func() -> bool: return tw.abilities.get_recast_part(&"e") == 0 and not tw.abilities.casting, 60)
	_check_near("its return: back at the start", tw.global_position.distance_to(tw_origin), 0.0, 0.5)
	await _frames(2)
	_check("the recharge started after it", tw.abilities.get_cooldown_left(&"e") > 0.0, true)
	tw.abilities.try_cast(&"e", tw_origin + Vector2(0, 200), null)
	await _wait_until(func() -> bool: return tw.abilities.get_recast_part(&"e") == 1 and not tw.abilities.casting, 60)
	var paused_at := tw.abilities.get_cooldown_left(&"e")
	await _frames(30)
	_check("the second charge's sequence: no charges, and the running recharge pauses during it (ABILITIES' rule)",
		[tw.abilities.get_charges(&"e"), is_equal_approx(tw.abilities.get_cooldown_left(&"e"), paused_at), (tw.global_position - tw_origin).y > 80.0],
		[0, true, true])
	tw.abilities.try_cast(&"e", tw_origin, null)
	await _wait_until(func() -> bool: return tw.abilities.get_recast_part(&"e") == 0 and not tw.abilities.casting, 60)
	_check_near("its own return: back at the start again", tw.global_position.distance_to(tw_origin), 0.0, 0.5)
	await _frames(10)
	_check("and the recharge runs again", tw.abilities.get_cooldown_left(&"e") < paused_at - 0.1, true)
	await _free(tw)

	# Long Lunge and Quick Footing: reach both ways, the cooldown.
	var ll := await _spawn_knight()
	ll.add_talent(KNIGHT.get_talent(&"knight_long_lunge"))
	ll.add_talent(KNIGHT.get_talent(&"knight_quick_footing"))
	ll.abilities.add_augment(AUGMENT_LUNGE_RETURN, &"loot_test_return")
	var ll_origin := ll.global_position
	_check("Long Lunge and Quick Footing reach it through variant_of: 500 range, 6 s",
		[LUNGE_RETURN.get_param(ll, &"cast_range"), LUNGE_RETURN.get_param(ll, &"cooldown")], [500.0, 6.0])
	await _wait_hitstop()
	ll.abilities.try_cast(&"e", ll_origin + Vector2(0, -300), null)
	await _wait_until(func() -> bool: return ll.abilities.get_recast_part(&"e") == 1 and not ll.abilities.casting, 60)
	_check_near("out the longer 500 u (160 px)", (ll_origin - ll.global_position).y, 160.0, 0.5)
	ll.abilities.try_cast(&"e", ll_origin, null)
	await _wait_until(func() -> bool: return ll.abilities.get_recast_part(&"e") == 0 and not ll.abilities.casting, 60)
	await _frames(1)
	_check("and all the way back; then the 6 s cooldown",
		[ll.global_position.distance_to(ll_origin) < 0.5, ll.abilities.get_cooldown_left(&"e") > 5.9, ll.abilities.get_cooldown_left(&"e") <= 6.0], [true, true, true])
	await _free(ll)


func _test_last_verdict() -> void:
	_section("L6: The Last Verdict: the leap (where aimed, 0.3 s, over everything, nothing interrupts it)")
	Loot.reset(KNIGHT)
	var p := await _spawn_knight()
	_equip_named(p, LAST_VERDICT, 1100)
	_check("worn, R casts Judgement Leap; its tooltip has the augment's line",
		[p.abilities.get_ability(&"r"), JUDGEMENT_LEAP.get_tooltip_plain(p).contains("\nJudgement becomes a leap: over anything")], [JUDGEMENT_LEAP, true])
	var long_arm := KNIGHT.get_talent(&"knight_long_arm")
	p.add_talent(long_arm)
	_check("Long Arm reaches the leap through variant_of: 650", JUDGEMENT_LEAP.get_param(p, &"cast_range"), 650.0)
	p.remove_talent(long_arm)
	var swift := KNIGHT.get_talent(&"knight_swift_verdict")
	p.add_talent(swift)
	_check("Swift Verdict too: a 24 s cooldown", JUDGEMENT_LEAP.get_param(p, &"cooldown"), 24.0)
	p.remove_talent(swift)
	await _free(p)
	var item_leap := await _leap_case(Vector2(120, 0), [], [], &"", 0.0, -1, false, true)
	_check_near("with the item itself: he lands where aimed", (item_leap.landed as Vector2).distance_to(Vector2(120, 0)), 0.0, 0.5)
	var open := await _leap_case(Vector2(120, 0))
	_check("cast at a spot 120 px away", open.cast, true)
	_check_near("he lands exactly there", (open.landed as Vector2).distance_to(Vector2(120, 0)), 0.0, 0.5)
	_report(open.frames >= 17 and open.frames <= 19, "0.3 s in the air (18 frames)", "got %d" % open.frames)
	_check("rooted for the 0.2 s crouch before it", [open.rooted, open.crouch_moved < 0.01], [true, true])
	_check("airborne while it runs, with no status (it isn't crowd control) and no i-frames", [open.airborne, open.status, open.invulnerable], [true, false, false])
	_check("colliding with nothing on the way (mask 0); his mask back when he lands", [open.mask_during, open.mask_restored], [0, true])
	var over := await _leap_case(Vector2(140, 0), [Vector2(40, 0)], [
		[7, Rect2(Vector2(24, -60), Vector2(6, 120))], [11, Rect2(Vector2(56, -60), Vector2(8, 120))],
		[1, Rect2(Vector2(76, -60), Vector2(8, 120))], [6, Rect2(Vector2(94, -60), Vector2(20, 120))]])
	_check_near("over a unit, a fence, a ledge, a wall and a pit at once: he lands exactly where aimed",
		(over.landed as Vector2).distance_to(Vector2(140, 0)), 0.0, 0.5)
	var hop := await _leap_case(Vector2.ZERO)
	_check("aimed at his own feet: a hop in place, 0.3 s", [(hop.landed as Vector2).length() < 0.5, hop.frames >= 17 and hop.frames <= 19], [true, true])

	# Nothing interrupts it: a push and a stun mid-air.
	var k := await _spawn_knight()
	k.abilities.add_augment(AUGMENT_JUDGEMENT_LEAP, &"loot_test_leap")
	var k_origin := k.global_position
	await _wait_hitstop()
	k.abilities.try_cast(&"r", k_origin + Vector2(120, 0), null)
	await _wait_until(func() -> bool: return k.movement.is_leaping(), 60)
	await _frames(4)
	var pushed := k.movement.displace(Vector2(0.0, 600.0), 0.2)
	k.status_component.apply_status(STATUS_STUN, null, 1.0)
	k.movement.dash(Vector2(-900.0, 0.0), 0.1)
	await _wait_until(func() -> bool: return not k.movement.is_leaping(), 60)
	await _frames(2)
	_check("a push mid-air is dropped, a stun or a dash doesn't stop it: he lands where aimed",
		[pushed, (k.global_position - k_origin).distance_to(Vector2(120, 0)) < 0.5], [false, true])
	await _free(k)


func _test_leap_hits() -> void:
	_section("L6: The Last Verdict: the landing (the circle in sight, missing health, the stun, the Fury, Shockwave, Executioner)")
	# Landing at (100, 0): a dummy 30 px off, a wounded one 60 px off, one 100 px off, one 50 px off behind a wall.
	var base := await _leap_case(Vector2(100, 0), [Vector2(130, 0), Vector2(100, 60), Vector2(200, 0), Vector2(100, -50)],
		[[1, Rect2(Vector2(80, -30), Vector2(40, 6))]], &"", 0.0, 1)
	_check("every enemy within 220 u (70 px) of the landing, in sight, is hit: not the one beyond, nor the one behind a wall",
		[base.taken[0] > 0.0, base.taken[1] > 0.0, base.taken[2], base.taken[3]], [true, true, -1.0, -1.0])
	_check("each takes its own missing-health term (the wounded one far more)", base.taken[1] > base.taken[0] * 20.0, true)
	_check("each is stunned 0.75 s", [base.stun[0], base.stun[1]], [0.75, 0.75])
	var full := 30.0
	_check("the cooldown runs (30 s from the cast start) and no Fury was there to spend", [base.cooldown_left > full - 1.0, base.ready, base.fury_after], [true, false, 0.0])
	var fury := await _leap_case(Vector2(100, 0), [Vector2(130, 0), Vector2(100, 60)], [], &"", 100.0)
	_check_near("at 60+ Fury: +30% damage", fury.taken[0] / base.taken[0], 1.3, 0.01)
	_check("and a 1.25 s stun on each; the Fury spent once", [fury.stun[0], fury.stun[1], fury.fury_after < 1.0], [1.25, 1.25, true])
	var empty := await _leap_case(Vector2(100, 0), [Vector2(300, 0)], [], &"", 100.0)
	_check("nothing in the circle: nothing hit, the Fury kept", [empty.taken[0], empty.fury_after], [-1.0, 100.0])
	var low := await _leap_case(Vector2(100, 0), [Vector2(130, 0)], [], &"", 50.0)
	_check("at 50 Fury: no bonus (the base damage and stun), the Fury kept",
		[is_equal_approx(low.taken[0], base.taken[0]), low.stun[0], low.fury_after], [true, 0.75, 50.0])

	# Shockwave's take: the ring out to 370 u at 50% and a 0.5 s stun; no missing-health term.
	var shock := await _leap_case(Vector2(100, 0), [Vector2(130, 0), Vector2(200, 0), Vector2(250, 0), Vector2(100, 40)],
		[], &"knight_shockwave", 0.0, 3)
	_check("with Shockwave: the circle as before; the ring (100 px off) hit too; 150 px off not",
		[shock.taken[0] > 0.0, shock.taken[1] > 0.0, shock.taken[2]], [true, true, -1.0])
	_check_near("the ring takes 50% of the circle's damage", shock.taken[1] / shock.taken[0], 0.5, 0.01)
	_check_near("no missing-health term (Shockwave's trade): the wounded one takes the same", shock.taken[3] / shock.taken[0], 1.0, 0.01)
	_check("stuns: 0.75 s in the circle, 0.5 s in the ring", [shock.stun[0], shock.stun[1]], [0.75, 0.5])
	var shock_fury := await _leap_case(Vector2(100, 0), [Vector2(130, 0), Vector2(200, 0)], [], &"knight_shockwave", 100.0)
	_check("with 60+ Fury the bonus reaches both (1.25 s and 1.0 s); the Fury spent once",
		[shock_fury.stun[0], shock_fury.stun[1], shock_fury.fury_after < 1.0], [1.25, 1.0, true])

	# Executioner: 40% missing health, no stun (0.5 s with the Fury), a kill resets the cooldown.
	var exe := await _leap_case(Vector2(100, 0), [Vector2(130, 0), Vector2(100, 60)], [], &"knight_executioner", 0.0, 1)
	_check_near("with Executioner: twice the missing-health damage (40%)",
		(exe.taken[1] - exe.taken[0]) / (base.taken[1] - base.taken[0]), 2.0, 0.02)
	_check("no stun; no kill, so the cooldown runs", [exe.stun[0], exe.stun[1], exe.ready], [0.0, 0.0, false])
	var exe_fury := await _leap_case(Vector2(100, 0), [Vector2(130, 0)], [], &"knight_executioner", 100.0)
	_check("with 60+ Fury: the Fury's 0.5 s stun", exe_fury.stun[0], 0.5)
	var exe_kill := await _leap_case(Vector2(100, 0), [Vector2(130, 0)], [], &"knight_executioner", 0.0, -1, true)
	_check("a kill on landing resets the cooldown (augment_judgement_reset through variant_of): chain leaps",
		[exe_kill.killed[0], exe_kill.ready], [true, true])
	var kill := await _leap_case(Vector2(100, 0), [Vector2(130, 0)], [], &"", 0.0, -1, true)
	_check("(control: the same kill without Executioner leaves the cooldown running)", [kill.killed[0], kill.ready], [true, false])


func _test_leap_in_room() -> void:
	_section("L6: The Last Verdict in a Room: the nearest walkable floor of the room (its navigation)")
	Loot.reset(KNIGHT)
	# The room: 400 x 240 px around the Knight; a wall 48 px thick east of him,
	# a pit west, a fence south. The navigation keeps 12 px from all of it.
	var pair := await _leap_room([[1, Rect2(60, -40, 48, 80)], [6, Rect2(-100, -10, 40, 20)], [7, Rect2(-50, 70, 100, 6)]])
	var room: Room = pair[0]
	var p: Player = pair[1]
	var origin := p.global_position
	var land := func(aim: Vector2) -> Vector2:
		return p.movement.get_leap_landing(origin + aim) - origin
	var free_at := func(at: Vector2) -> bool:
		return WorldQuery.is_point_free(origin + at, 11.0, MovementComponent.LEAP_BLOCKING_MASK)
	var open: Vector2 = land.call(Vector2(-30, -60))
	_check_near("open floor: exactly where aimed", open.distance_to(Vector2(-30, -60)), 0.0, 0.01)
	var wall: Vector2 = land.call(Vector2(100, 0))
	_check("aimed inside the thick wall, nearer its far side: on the floor past it (the nearest walkable floor, not back toward him), at %s" % wall,
		wall.x > 116.0 and wall.x < 124.0 and absf(wall.y) < 3.0 and free_at.call(wall), true)
	var pit: Vector2 = land.call(Vector2(-80, 0))
	_check("aimed into the pit: on its nearest rim, clear of it, at %s" % pit,
		absf(pit.x + 80.0) < 3.0 and absf(pit.y) > 19.0 and absf(pit.y) < 26.0 and free_at.call(pit), true)
	var fence: Vector2 = land.call(Vector2(0, 75))
	_check("aimed onto the fence: just past its nearer side, clear of it, at %s" % fence,
		absf(fence.x) < 3.0 and fence.y > 84.0 and fence.y < 92.0 and free_at.call(fence), true)
	var edge: Vector2 = land.call(Vector2(0, -150))
	_check("aimed past the room's floor: inside the room, at its edge, at %s" % edge,
		absf(edge.x) < 3.0 and edge.y > -110.0 and edge.y < -104.0, true)
	# A real cast into the wall.
	p.abilities.add_augment(AUGMENT_JUDGEMENT_LEAP, &"loot_test_leap")
	await _wait_hitstop()
	p.abilities.try_cast(&"r", origin + Vector2(100, 0), null)
	await _wait_until(func() -> bool: return p.movement.is_leaping(), 60)
	await _wait_until(func() -> bool: return not p.movement.is_leaping(), 60)
	await _frames(2)
	_check("cast into the wall, he lands past it: %s" % (p.global_position - origin),
		(p.global_position - origin).distance_to(wall) < 0.5, true)
	room.queue_free()
	await _frames(2)


## The Last Verdict's leap by a fresh Knight (the augment alone, or the item
## when `with_item`; no crits, `talent_id`, `fury`) aimed at `aim` (relative
## to him), with dummies at `dummies` (relative; tough, or at 1 health when `frail`; the one
## at index `wounded` at half health) and `blockers` ([layer, Rect2 relative]).
## What happened: "landed" (relative), "frames" (physics frames leaping),
## "rooted" and "crouch_moved" (during the cast time), "airborne", "status"
## (status_airborne) and "invulnerable" (seen while leaping), "mask_during",
## "mask_restored", per dummy "taken" (-1 = not hit), "stun" (the stun its hit
## carried, 0 = none) and "killed", "fury_after", "cooldown_left", "ready".
func _leap_case(aim: Vector2, dummies: Array = [], blockers: Array = [], talent_id: StringName = &"",
		fury: float = 0.0, wounded: int = -1, frail: bool = false, with_item: bool = false) -> Dictionary:
	Loot.reset(KNIGHT)
	_dummy_offset = 0.0
	var p := await _spawn_knight()
	if talent_id != &"":
		p.add_talent(KNIGHT.get_talent(talent_id))
	if with_item:
		_equip_named(p, LAST_VERDICT, 1101)
	else:
		p.abilities.add_augment(AUGMENT_JUDGEMENT_LEAP, &"loot_test_leap")
	p.stats_component.add_modifier(StatModifier.create(&"crit_chance", StatModifier.Type.FLAT, -10.0, &"loot_test_no_crit"))
	p.resource_pool.decay_per_second = 0.0
	if fury > 0.0:
		p.resource_pool.restore(fury)
	var origin := p.global_position
	var targets: Array[Enemy] = []
	for at: Vector2 in dummies:
		var d := _dummy_near(p, not frail)
		d.global_position = origin + at
		d.reset_physics_interpolation()
		targets.append(d)
	if wounded >= 0:
		targets[wounded].health.take_damage(targets[wounded].health.max_health * 0.5)
	if frail:
		for d in targets:
			d.health.take_damage(d.health.max_health - 1.0)   # 1 health left: any hit kills
	var bodies: Array[Node] = []
	for b: Array in blockers:
		var rect: Rect2 = b[1]
		bodies.append(_blocker(Rect2(origin + rect.position, rect.size), b[0]))
	await _frames(2)
	await _wait_hitstop()
	var mask_before := p.collision_mask
	var out := {"airborne": false, "status": false, "invulnerable": false, "frames": 0, "rooted": false,
		"crouch_moved": 0.0, "mask_during": -1}
	var taken := {}
	var stuns := {}
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.source != p or ctx.ability != JUDGEMENT_LEAP or ctx.blocked:
			return
		var k := targets.find(ctx.target)
		taken[k] = float(taken.get(k, 0.0)) + ctx.taken_damage
		var stun := 0.0
		for s in ctx.statuses:
			if s != null and s.id == &"stun":
				stun = s.duration
		stuns[k] = stun
	Events.unit_hit.connect(on_hit)
	out["cast"] = p.abilities.try_cast(&"r", origin + aim, null)
	var started := false
	for i in 120:
		await _frames(1)
		out["status"] = out["status"] or p.status_component.has_status(&"airborne")
		if p.movement.is_leaping():
			started = true
			out["frames"] += 1
			out["airborne"] = out["airborne"] or p.movement.is_airborne()
			out["invulnerable"] = out["invulnerable"] or p.is_invulnerable()
			out["mask_during"] = p.collision_mask
		elif not started:
			if p.abilities.casting:
				out["rooted"] = not p.movement.can_move()
			out["crouch_moved"] = maxf(out["crouch_moved"], p.global_position.distance_to(origin))
		elif not p.abilities.casting:
			break
	await _frames(2)
	Events.unit_hit.disconnect(on_hit)
	out["landed"] = p.global_position - origin
	out["mask_restored"] = p.collision_mask == mask_before
	var taken_list: Array[float] = []
	var stun_list: Array[float] = []
	var killed_list: Array[bool] = []
	for k in targets.size():
		taken_list.append(float(taken.get(k, -1.0)))
		stun_list.append(float(stuns.get(k, 0.0)))
		killed_list.append(not is_instance_valid(targets[k]) or not targets[k].is_alive())
	out["taken"] = taken_list
	out["stun"] = stun_list
	out["killed"] = killed_list
	out["fury_after"] = p.resource_pool.current
	out["cooldown_left"] = p.abilities.get_cooldown_left(&"r")
	out["ready"] = p.abilities.is_ready(&"r")
	for body in bodies:
		body.queue_free()
	await _free_dummies()
	await _free(p)
	return out


## A Room (400 x 240 px around its origin, depth 1) whose Footprints hold
## `blockers` ([layer, Rect2 local]), baked into its navigation as a real
## room's are, with a Knight from player.tscn at its origin, once the
## navigation map has synced: [room, knight].
func _leap_room(blockers: Array) -> Array:
	var room := Room.new()
	room.bounds_px = Rect2(-200, -120, 400, 240)
	var entities := Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	room.add_child(entities)
	var footprints := Node2D.new()
	footprints.name = "Footprints"
	footprints.add_to_group(&"navigation_source")
	room.add_child(footprints)
	for b: Array in blockers:
		var rect: Rect2 = b[1]
		var body := StaticBody2D.new()
		body.collision_layer = 1 << (int(b[0]) - 1)
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		body.add_child(shape)
		body.position = rect.get_center()
		footprints.add_child(body)
	_next_x += 600.0
	room.position = Vector2(_next_x, 1000.0)
	add_child(room)
	var p := await _spawn_in(room)
	var map := p.get_world_2d().navigation_map
	for i in 60:
		if NavigationServer2D.map_get_iteration_id(map) > 0:
			break
		await _frames(1)
	await _frames(2)
	return [room, p]


## Waits up to `max_frames` physics frames for `condition`; true if it held.
func _wait_until(condition: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


# --- L7: drops and pickups --------------------------------------------------------

func _test_l7_data() -> void:
	_section("L7: layer 9, the pickup, the collector, the Knight's radius, the sounds")
	_check("collision layer 9 is named pickup", ProjectSettings.get_setting("layer_names/2d_physics/layer_9", ""), "pickup")
	var pickup: Pickup = PICKUP_SCENE.instantiate()
	var shape := pickup.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var circle := shape.shape as CircleShape2D if shape != null else null
	_check("pickup.tscn: on layer 9 only, masking nothing, not monitoring, not collectable before it lands, a 6 px circle",
		[pickup.collision_layer, pickup.collision_mask, pickup.monitoring, pickup.monitorable, circle.radius if circle else -1.0],
		[256, 0, false, false, 6.0])
	_check("it pops 12–28 px over 0.3 s; its view is PickupView's scene",
		[pickup.pop_time, pickup.pop_distance_min_px, pickup.pop_distance_max_px, pickup.get_view_scene().resource_path],
		[0.3, 12.0, 28.0, "res://scenes/view/pickup_view.tscn"])
	pickup.free()
	var player: Player = PLAYER_SCENE.instantiate()
	var pc := player.get_node_or_null("PickupComponent") as PickupComponent
	_check("player.tscn has a PickupComponent: on no layer, masking layer 9 only, never collectable itself",
		[pc != null, pc.collision_layer if pc else -1, pc.collision_mask if pc else -1, pc.monitorable if pc else true],
		[true, 0, 256, false])
	player.free()
	_check("knight.tres: pickup_radius 200 u (64 px)", [KNIGHT_STATS.pickup_radius, Units.to_px(KNIGHT_STATS.pickup_radius)], [200.0, 64.0])
	var drop_sounds: Array = []
	for r in 7:
		drop_sounds.append(_table.get_rarity(r as Item.Rarity).drop_sound)
	_check("the drop sounds: none for Common, sound_loot_drop for Uncommon–Exotic, the brighter one for Legendary and Artifact",
		drop_sounds == [null, SOUND_LOOT_DROP, SOUND_LOOT_DROP, SOUND_LOOT_DROP, SOUND_LOOT_DROP, SOUND_LOOT_DROP_LEGENDARY, SOUND_LOOT_DROP_LEGENDARY], true)
	_check("the pickup sound: sound_loot_pickup, centered, on SFX",
		[_table.pickup_sound == SOUND_LOOT_PICKUP, SOUND_LOOT_PICKUP.positional, SOUND_LOOT_PICKUP.bus], [true, false, SoundEvent.Bus.SFX])
	_check("both drop sounds are positional, on SFX",
		[SOUND_LOOT_DROP.positional, SOUND_LOOT_DROP.bus, SOUND_LOOT_DROP_LEGENDARY.positional, SOUND_LOOT_DROP_LEGENDARY.bus],
		[true, SoundEvent.Bus.SFX, true, SoundEvent.Bus.SFX])
	var files_ok := true
	for sound: SoundEvent in [SOUND_LOOT_DROP, SOUND_LOOT_DROP_LEGENDARY, SOUND_LOOT_PICKUP]:
		files_ok = files_ok and sound.variations.size() == 1 and sound.variations[0] is AudioStreamWAV
	_check("each has its one synthesized file (audio/sfx/loot_*_01.wav)", files_ok, true)
	_check("the loot table still validates", _join(_table.get_validation_errors()), "")


func _test_drop_rates() -> void:
	_section("L7: how often kills drop (a kill's own roll, seeded): the tables' rates")
	var p := await _spawn_knight()
	var slime: Enemy = SLIME_SCENE.instantiate()
	var elite: Enemy = SLIME_ELITE_SCENE.instantiate()
	var deep := Room.new()
	deep.depth = 5
	var deep_slime: Enemy = SLIME_SCENE.instantiate()
	deep.add_child(deep_slime)
	var n := 20000
	Loot.rng.seed = 7001
	var hits := 0
	for i in n:
		hits += 0 if Loot.roll_kill_drop(slime, p).is_empty() else 1
	_check_rate("a slime's kill drops at the regular table's 10% (20,000 kills, depth 1)", hits, n, 0.1)
	hits = 0
	for i in n:
		hits += 0 if Loot.roll_kill_drop(deep_slime, p).is_empty() else 1
	_check_rate("in a Room at depth 5: 10% x (1 + 0.05 x 4) = 12%", hits, n, 0.12)
	var always := true
	var uncommon_up := true
	for i in 2000:
		var got := Loot.roll_kill_drop(elite, p)
		always = always and got.size() == 1
		uncommon_up = uncommon_up and (got.is_empty() or got[0].rarity >= R.UNCOMMON)
	_check("the elite's kill always drops one item, Uncommon or better (2,000 kills)", [always, uncommon_up], [true, true])
	# Magic find is the killer's: the rarities shift, the chance doesn't.
	p.stats_component.add_modifiers([StatModifier.create(&"magic_find", StatModifier.Type.FLAT, 9.0, &"loot_test_mf")])
	Loot.rng.seed = 7002
	hits = 0
	var better := 0
	for i in n:
		var got := Loot.roll_kill_drop(slime, p)
		if not got.is_empty():
			hits += 1
			better += 1 if got[0].rarity > R.COMMON else 0
	_check_rate("the killer's +900% magic find leaves the chance at 10%", hits, n, 0.1)
	var weights := REGULAR.get_weights(1, 9.0, _table)
	var share := 1.0 - weights[0] / _sum(weights)
	_check_rate("and shifts the rarities: %.1f%% Uncommon or better (40.5%% without)" % (share * 100.0), better, hits, share)
	p.stats_component.remove_modifiers_from(&"loot_test_mf")
	slime.free()
	elite.free()
	deep.free()
	await _free(p)


func _test_kill_drops() -> void:
	_section("L7: a kill drops through the kill credit (the tracked player's last hit)")
	Loot.reset(KNIGHT)
	_check("drops are off by themselves in a test scene", Loot.are_drops_enabled(), false)
	Loot.drops_enabled = true
	_check("a test turns them on", Loot.are_drops_enabled(), true)
	var setup := await _sandbox_room()
	var room: Room = setup[0]
	var p: Player = setup[2]
	var entities := room.get_node("Entities")
	var elite := _enemy_in(room, SLIME_ELITE_SCENE, Vector2(120, 0))
	var at := elite.global_position
	Loot.rng.seed = 7101
	var ctx := _kill(p, elite)
	_check("the Knight's hit kills the elite", ctx.killed, true)
	_check("no pickup inside the hit itself (it's added at the end of the frame)", Loot.get_ground_pickups(room).size(), 0)
	await _wait_until(func() -> bool: return not Loot.get_ground_pickups(room).is_empty(), 5)
	var pickups := Loot.get_ground_pickups(room)
	_check("then one pickup (the elite table drops one item), in the room's Entities",
		[pickups.size(), pickups[0].get_parent() == entities if pickups.size() > 0 else false], [1, true])
	if pickups.size() > 0:
		_check("it hops from the corpse; its item is Uncommon or better",
			[pickups[0].get_hop_from().distance_to(at) < 0.01, pickups[0].item.rarity >= R.UNCOMMON], [true, true])
	Loot.take_ground_drops(room)
	var dummy_kill := _kill(p, _enemy_in(room, SLIME_ELITE_SCENE, Vector2(-120, 0), true))
	await _frames(3)
	_check("a training dummy (an elite) killed by the Knight: no drop", [dummy_kill.killed, Loot.get_ground_pickups(room).size()], [true, 0])
	# Who gets the credit, case by case, through the listener on
	# Events.unit_died (each an elite: a credited kill always drops).
	var friend := _enemy_in(room, SLIME_ELITE_SCENE, Vector2(0, 120))
	friend.team = p.team
	var other := _enemy_in(room, SLIME_SCENE, Vector2(0, -120))
	var target := _enemy_in(room, SLIME_ELITE_SCENE, Vector2(120, 120))
	var cases := [
		["a unit of the Knight's own team, killed by him", friend, p],
		["a kill by another unit (a slime's hit)", target, other],
		["a kill with no source", target, null],
	]
	for c: Array in cases:
		var kill := _death(c[2], c[1])
		Events.unit_died.emit(c[1], kill)
		await _frames(2)
		_check("no drop: %s" % c[0], [Loot.get_drop_credit(c[1], kill), Loot.get_ground_pickups(room).size()], [null, 0])
	var credited := _death(p, target)
	_check("the same elite killed by the Knight: his credit", Loot.get_drop_credit(target, credited) == p, true)
	Loot.drops_enabled = false
	Events.unit_died.emit(target, credited)
	await _frames(2)
	_check("with drops off: nothing", Loot.get_ground_pickups(room).size(), 0)
	Loot.drops_enabled = true
	Events.unit_died.emit(target, credited)
	await _wait_until(func() -> bool: return not Loot.get_ground_pickups(room).is_empty(), 5)
	_check("on again: its drop", Loot.get_ground_pickups(room).size(), 1)
	Loot.drops_enabled = false
	room.queue_free()
	await _frames(1)


func _test_pickup_pop() -> void:
	_section("L7: a drop pops, lands 0.3 s later, and the Knight standing there takes it")
	Loot.reset(KNIGHT)
	var setup := await _sandbox_room()
	var room: Room = setup[0]
	var p: Player = setup[2]
	var entities := room.get_node("Entities")
	var record := Loot.get_inventory(KNIGHT)
	var item := _item(&"item_base_iron_helm", R.RARE, [[&"affix_armor", 0.5]], 0)
	var at := p.global_position
	Loot.rng.seed = 7201
	Audio.clear_log()
	var picked: Array = []
	var on_pick := func(champion_id: StringName, it: Item) -> void: picked.append([champion_id, it])
	Loot.item_picked_up.connect(on_pick)
	var start := Engine.get_physics_frames()
	var dropped := Loot.drop(_items([item]), at, entities)
	var pickup: Pickup = dropped[0] if dropped.size() == 1 else null
	var landings := [0]
	pickup.landed.connect(func() -> void: landings[0] += 1)
	var spot := pickup.global_position
	var away := spot.distance_to(at)
	_check("one pickup, standing at its landing spot at once, %.1f px from where it dropped (12–28)" % away,
		[dropped.size(), away >= 12.0 and away <= 28.0], [1, true])
	_check("it hops from the drop point and isn't collectable yet (progress 0, monitorable off)",
		[pickup.get_hop_from() == at, pickup.get_hop_progress(), pickup.is_landed(), pickup.monitorable], [true, 0.0, false, false])
	await _frames(12)
	_check("0.2 s in: still hopping, inside the Knight's 64 px and untouched",
		[is_instance_valid(pickup), pickup.is_landed(), record.items.size()], [true, false, 0])
	var took := await _wait_until(func() -> bool: return not picked.is_empty(), 30)
	var frames := Engine.get_physics_frames() - start
	_check("it lands at 0.3 s and is taken within two physics steps (%d frames; 18–21)" % frames, [took, frames >= 18 and frames <= 21], [true, true])
	_check("its landed signal, once", landings[0], 1)
	Loot.item_picked_up.disconnect(on_pick)
	_check("into the Knight's inventory at once, uid 1",
		[record.items.size(), record.items[0] == item if record.items.size() > 0 else false, item.uid], [1, true, 1])
	_check("item_picked_up once, with the Knight's id and the item", picked, [[&"knight", item]])
	await _frames(1)
	_check("the pickup is gone", is_instance_valid(pickup), false)
	_check("the sounds: the Rare's drop sound where it landed, then the pickup sound, centered", _loot_sounds(spot),
		[["sound_loot_drop.tres", true, true], ["sound_loot_pickup.tres", false, true]])
	# A Common lands silently; a Legendary with the brighter sound.
	Audio.clear_log()
	var common := _item(&"item_base_band", R.COMMON, [[&"affix_attack_damage", 0.5]], 0)
	var legendary := ItemRoller.make_named(TIDEBREAKER, _table, _rng(7202))
	Loot.drop(_items([common, legendary]), at, entities)
	await _wait_until(func() -> bool: return record.items.size() == 3, 30)
	var drops := _loot_sounds(Vector2.INF).filter(func(row: Array) -> bool: return String(row[0]).begins_with("sound_loot_drop"))
	_check("a Common lands silently, a Legendary with sound_loot_drop_legendary", drops.map(func(row: Array) -> String: return row[0]),
		["sound_loot_drop_legendary.tres"])
	_check("both taken", record.items.size(), 3)
	# In the save at once.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_SAVE))
	Loot.save_path = SCRATCH_SAVE
	Loot.saving_enabled = true
	var saved := _item(&"item_base_pendant", R.UNCOMMON, [[&"affix_magic_find", 0.3], [&"affix_damage", 0.6]], 0)
	Loot.drop(_items([saved]), at, entities)
	await _wait_until(func() -> bool: return record.items.size() == 4, 30)
	var after := _read_scratch()
	Loot.saving_enabled = false
	Loot.save_path = Loot.SAVE_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_SAVE))
	_check("a pickup is in the save at once (a scratch file)",
		after != null and after.items.size() == 4 and after.items[3].to_dict() == saved.to_dict(), true)
	room.queue_free()
	await _frames(1)


func _test_pickup_walk() -> void:
	_section("L7: walking past a drop takes it, with no key and no stop")
	Loot.reset(KNIGHT)
	var setup := await _sandbox_room()
	var room: Room = setup[0]
	var p: Player = setup[2]
	var item := _item(&"item_base_leather_boots", R.UNCOMMON, [[&"affix_move_speed", 0.5], [&"affix_armor", 0.5]], 0)
	Loot.rng.seed = 7301
	var pickup: Pickup = Loot.drop(_items([item]), p.global_position + Vector2(130, 0), room.get_node("Entities"))[0]
	await _frames(25)
	_check("landed 130 px off (outside the 64 px circle): not taken",
		[is_instance_valid(pickup), pickup.is_landed(), Loot.get_inventory(KNIGHT).items.size()], [true, true, 0])
	var spot := pickup.global_position
	var seen := {"frame": -1, "gap": INF}
	var on_pick := func(_id: StringName, _it: Item) -> void:
		seen.frame = Engine.get_physics_frames()
		seen.gap = p.global_position.distance_to(spot)
	Loot.item_picked_up.connect(on_pick)
	var speeds := {}   # physics frame -> the Knight's speed
	Input.action_press(&"move_right")
	for i in 90:
		await get_tree().physics_frame
		speeds[Engine.get_physics_frames()] = p.velocity.length()
		if seen.frame >= 0 and Engine.get_physics_frames() > seen.frame + 6:
			break
	Input.action_release(&"move_right")
	Loot.item_picked_up.disconnect(on_pick)
	_check("walking right, the Knight takes it on his way", [seen.frame >= 0, Loot.get_inventory(KNIGHT).items.has(item)], [true, true])
	_check("when his circle reaches it: %.1f px off (64 px plus its own 6)" % seen.gap, seen.gap <= 70.5 and seen.gap >= 60.0, true)
	var around: Array[float] = []
	for frame: int in speeds:
		if absi(frame - int(seen.frame)) <= 5:
			around.append(speeds[frame])
	var walk := Units.to_px(KNIGHT_STATS.move_speed)
	var steady := not around.is_empty() and around.all(func(s: float) -> bool: return absf(s - walk) < 0.5)
	_check("no stop: his speed stays %.0f px/s from 5 frames before it to 5 after (%s)" % [walk, around], steady, true)
	_check("no move lock and no status from it", [p.movement.can_move(), p.status_component.get_status_ids()], [true, [] as Array[StringName]])
	room.queue_free()
	await _frames(1)


func _test_pickup_radius() -> void:
	_section("L7: the collect circle is the pickup_radius stat, followed live; a dead champion takes nothing")
	Loot.reset(KNIGHT)
	var other := await _spawn_knight()
	var setup := await _sandbox_room()
	var room: Room = setup[0]
	var p: Player = setup[2]
	var pc := p.get_node("PickupComponent") as PickupComponent
	_check_near("the Knight: 64 px (200 u)", pc.get_radius_px(), 64.0, 0.001)
	var band := _item(&"item_base_band", R.COMMON, [[&"affix_crit_chance", 0.5]], 0)
	Loot.restore_ground_drops(room, [{"item": band.to_dict(), "pos": p.global_position + Vector2(-85, 0)}])
	await _frames(3)
	_check("a landed drop 85 px off: out of reach", [Loot.get_ground_pickups(room).size(), Loot.get_inventory(KNIGHT).items.size()], [1, 0])
	p.stats_component.add_modifier(StatModifier.create(&"pickup_radius", StatModifier.Type.FLAT, 100.0, &"loot_test_reach"))
	_check_near("+100 u: 96 px at once", pc.get_radius_px(), 96.0, 0.001)
	await _frames(3)
	_check("and the grown circle takes it", [Loot.get_ground_pickups(room).size(), Loot.get_inventory(KNIGHT).items.size()], [0, 1])
	_check_near("another Knight keeps his own 64 px (each has its own circle)", (other.get_node("PickupComponent") as PickupComponent).get_radius_px(), 64.0, 0.001)
	p.stats_component.remove_modifiers_from(&"loot_test_reach")
	_check_near("removed: 64 px again", pc.get_radius_px(), 64.0, 0.001)
	p.health.take_damage(p.health.current + 10.0)
	await _frames(1)
	Loot.restore_ground_drops(room, [{"item": band.to_dict(), "pos": p.global_position + Vector2(10, 0)}])
	await _frames(5)
	_check("the Knight dead: a drop at his feet stays on the ground",
		[p.is_alive(), Loot.get_ground_pickups(room).size(), Loot.get_inventory(KNIGHT).items.size()], [false, 1, 1])
	room.queue_free()
	await _free(other)


func _test_landing_terrain() -> void:
	_section("L7: a drop lands where the player could walk to it: not past or against a wall, a fence or a cliff's edge, never over a pit")
	var probe: Pickup = PICKUP_SCENE.instantiate()
	# A strip 8–12 px right of the drop point, 200 px tall: a landing 12–28 px
	# away to the right would be against it (its 6 px circle) or past it.
	for row: Array in [[1, "a wall"], [7, "a fence"], [11, "a ledge (a cliff's edge)"], [6, "a pit"]]:
		_next_x += 400.0
		var origin := Vector2(_next_x, -3000.0)
		var strip := _blocker(Rect2(origin + Vector2(8.0, -100.0), Vector2(4.0, 200.0)), row[0])
		await _frames(2)
		var rng := _rng(7400 + int(row[0]))
		var against := 0
		var past := 0
		var open := 0
		for i in 300:
			var x := probe.pick_landing(origin, rng).x - origin.x
			if x >= 12.0 + 6.0:
				past += 1
			elif x > 8.0 - 6.0:
				against += 1
			elif x != 0.0:
				open += 1
		if row[0] == 6:
			_check("next to %s: 300 drops, none over it (%d); one may hop across it (%d did: only walls, fences and cliff edges block the way); %d on the open side" % [row[1], against, past, open],
				[against, past > 0, open > 150], [0, true, true])
		else:
			_check("next to %s: 300 drops, none against it (%d) nor past it (%d); %d on the open side, the rest where they dropped" % [row[1], against, past, open],
				[against, past, open > 200], [0, 0, true])
		strip.queue_free()
	# Walled in 8 px around: every try fails, so it lands where it dropped.
	_next_x += 400.0
	var boxed := Vector2(_next_x, -3000.0)
	var walls: Array[Node] = [
		_blocker(Rect2(boxed + Vector2(-12, -12), Vector2(24, 4)), 1), _blocker(Rect2(boxed + Vector2(-12, 8), Vector2(24, 4)), 1),
		_blocker(Rect2(boxed + Vector2(-12, -8), Vector2(4, 16)), 1), _blocker(Rect2(boxed + Vector2(8, -8), Vector2(4, 16)), 1)]
	await _frames(2)
	var rng := _rng(7450)
	var home := true
	for i in 50:
		home = home and probe.pick_landing(boxed, rng) == boxed
	_check("walled in 8 px around: 50 drops, each where it dropped (four tries, then the origin)", home, true)
	for w in walls:
		w.queue_free()
	# Loot.drop() itself picks by these rules.
	_next_x += 400.0
	var origin := Vector2(_next_x, -3000.0)
	var wall := _blocker(Rect2(origin + Vector2(8.0, -100.0), Vector2(4.0, 200.0)), 1)
	await _frames(2)
	Loot.rng.seed = 7460
	var many: Array[Item] = []
	for i in 40:
		many.append(_item(&"item_base_band", R.COMMON, [[&"affix_attack_damage", 0.5]], 0))
	var dropped := Loot.drop(many, origin, self)
	var ok := dropped.size() == 40
	for pk in dropped:
		ok = ok and pk.global_position.x - origin.x <= 2.0
	_check("Loot.drop(): 40 drops by a wall, all on the open side", ok, true)
	for pk in dropped:
		pk.queue_free()
	wall.queue_free()
	probe.free()
	await _frames(1)


func _test_drop_over_pit() -> void:
	_section("L7: a unit that died over a pit drops on the floor outside it")
	var setup := await _leap_room([[6, Rect2(-48, -48, 96, 96)]])   # a 3 m pit in the room's middle
	var room: Room = setup[0]
	var p: Player = setup[1]
	_place_unit(p, room.global_position + Vector2(160, 100))   # far, so nothing's taken
	await _frames(2)
	var center := room.global_position
	var pit := Rect2(center + Vector2(-48, -48), Vector2(96, 96))
	var origin := Loot.get_drop_origin(center, room)
	_check("from the pit's middle, the drops start on the room's nearest walkable floor: past the navigation's 12 px margin, at %s" % (origin - center),
		[pit.grow(10.0).has_point(origin), pit.grow(14.0).has_point(origin)], [false, true])
	Loot.rng.seed = 7501
	var many: Array[Item] = []
	for i in 20:
		many.append(_item(&"item_base_band", R.COMMON, [[&"affix_attack_damage", 0.5]], 0))
	var dropped := Loot.drop(many, center, room.get_node("Entities"))
	var over := 0
	var from_edge := true
	for pk in dropped:
		over += 0 if WorldQuery.is_point_free(pk.global_position, pk.get_radius(), Pickup.PIT_MASK) else 1
		from_edge = from_edge and pk.get_hop_from() == origin
	_check("20 drops: none over the pit, each hopping from that spot", [dropped.size(), over, from_edge], [20, 0, true])
	room.queue_free()
	# Outside a Room: the nearest point outside the pit (WorldQuery.push_out()).
	_next_x += 400.0
	var loose := _blocker(Rect2(Vector2(_next_x, -4000.0), Vector2(64, 64)), 6)
	await _frames(2)
	var inside := loose.global_position + Vector2(28, 0)   # 4 px inside its right edge
	var out := Loot.get_drop_origin(inside, self)
	_check("outside a Room, 4 px inside a pit's edge: out to the nearest point a pickup clears it (%.1f px)" % out.distance_to(inside),
		[WorldQuery.is_point_free(out, 6.0, Pickup.PIT_MASK), out.distance_to(inside) <= 11.0], [true, true])
	_check("a drop point not over a pit stays", Loot.get_drop_origin(inside + Vector2(40, 0), self), inside + Vector2(40, 0))
	loose.queue_free()
	await _frames(1)


func _test_ground_drops() -> void:
	_section("L7: ground drops taken off a room and put back where they lay (DUNGEONS D1's rebuilds)")
	Loot.reset(KNIGHT)
	var setup := await _sandbox_room()
	var room: Room = setup[0]
	var p: Player = setup[2]
	_place_unit(p, room.global_position + Vector2(150, 150))   # out of reach
	await _frames(2)
	var entities := room.get_node("Entities")
	var rare := _item(&"item_base_iron_helm", R.RARE, [[&"affix_armor", 0.4], [&"affix_max_health", 0.7], [&"affix_tenacity", 0.2]], 0)
	var named := ItemRoller.make_named(TIDEBREAKER, _table, _rng(7601))
	var exotic := ItemRoller.roll_item(R.EXOTIC, KNIGHT, _table, _rng(7602))
	Loot.rng.seed = 7603
	var first := Loot.drop(_items([rare, named]), room.global_position + Vector2(-60, 0), entities)
	await _frames(25)
	var hopping: Pickup = Loot.drop(_items([exotic]), room.global_position + Vector2(60, 0), entities)[0]
	var spots := [first[0].global_position, first[1].global_position, hopping.global_position]
	_check("two landed, one still hopping", [first[0].is_landed(), first[1].is_landed(), hopping.is_landed()], [true, true, false])
	var drops := Loot.take_ground_drops(room)
	_check("taken: one entry each, its item's dict and where it lies (the hopping one at its landing spot)",
		drops.map(func(d: Dictionary) -> Array: return [d.item, d.pos]),
		[[rare.to_dict(), spots[0]], [named.to_dict(), spots[1]], [exotic.to_dict(), spots[2]]])
	_check("none left on the ground", Loot.get_ground_pickups(room).size(), 0)
	await _frames(1)
	_check("the pickups are freed", [is_instance_valid(first[0]), is_instance_valid(first[1]), is_instance_valid(hopping)], [false, false, false])
	Audio.clear_log()
	var back := Loot.restore_ground_drops(room, drops)
	_check("put back: three pickups in the room's Entities, each where it lay",
		back.map(func(pk: Pickup) -> Array: return [pk.get_parent() == entities, pk.global_position]),
		[[true, spots[0]], [true, spots[1]], [true, spots[2]]])
	_check("landed and collectable at once (no hop)",
		back.map(func(pk: Pickup) -> Array: return [pk.is_landed(), pk.monitorable, pk.get_hop_progress()]),
		[[true, true, 1.0], [true, true, 1.0], [true, true, 1.0]])
	_check("the same items (the named one read through the Knight, the sigils kept)",
		back.map(func(pk: Pickup) -> Dictionary: return pk.item.to_dict()), [rare.to_dict(), named.to_dict(), exotic.to_dict()])
	await _frames(25)
	_check("put back silently (no drop sound)", _loot_sounds(Vector2.INF).size(), 0)
	for spot: Vector2 in spots:   # (one stand can reach two: they're freed as he goes)
		_place_unit(p, spot)
		await _frames(3)
	_check("the Knight walks over them and takes each", Loot.get_inventory(KNIGHT).items.size(), 3)
	var none := Loot.restore_ground_drops(room, [{"item": {"base": "item_base_nope", "rarity": "rare"}, "pos": Vector2.ZERO}, {"item": rare.to_dict()}, "junk"])
	_check("an item the data doesn't know, an entry without a spot, junk: each skipped (warnings)", [none.size(), Loot.get_ground_pickups(room).size()], [0, 0])
	room.queue_free()
	await _frames(1)


func _test_hud_loot_line() -> void:
	_section("L7: the HUD's loot line: the rarity and the name in the rarity's color, 2 s")
	var hud: Node = HUD_SCENE.instantiate()
	add_child(hud)
	await _frames(1)
	var rare := _item(&"item_base_iron_helm", R.RARE, [[&"affix_armor", 0.5]], 0)
	var named := ItemRoller.make_named(TIDEBREAKER, _table, _rng(7701))
	Loot.item_picked_up.emit(KNIGHT.id, rare)
	_check("a pickup: \"Rare: Iron Helm\", in the Rare color",
		[hud.call(&"get_loot_lines"), hud.call(&"get_loot_line_color", "Rare: Iron Helm")],
		[PackedStringArray(["Rare: Iron Helm"]), _table.get_rarity(R.RARE).color])
	Loot.item_picked_up.emit(KNIGHT.id, named)
	_check("a second goes under it: \"Legendary: Tidebreaker\", in orange",
		[hud.call(&"get_loot_lines"), hud.call(&"get_loot_line_color", "Legendary: Tidebreaker")],
		[PackedStringArray(["Rare: Iron Helm", "Legendary: Tidebreaker"]), _table.get_rarity(R.LEGENDARY).color])
	for i in 6:
		hud.call(&"show_loot_line", "Line %d" % i, Color.WHITE)
	_check("six at most: the oldest go", hud.call(&"get_loot_lines"),
		PackedStringArray(["Line 0", "Line 1", "Line 2", "Line 3", "Line 4", "Line 5"]))
	await _frames(160)
	_check("gone after 2 s and the fade", (hud.call(&"get_loot_lines") as PackedStringArray).size(), 0)
	hud.queue_free()
	await _frames(1)


# --- L7b: dropping and trashing items, sorting ---------------------------------------

func _test_l7b_rules() -> void:
	_section("L7b: removing an item from the record; what can't leave; what asks first")
	var inv := ChampionInventory.create(KNIGHT)
	var a := _item(&"item_base_band", R.COMMON, [[&"affix_attack_damage", 0.5]], 0)
	var b := _item(&"item_base_iron_helm", R.RARE, [[&"affix_armor", 0.5]], 0)
	inv.add(a)
	inv.add(b)
	inv.set_equipped(&"helm", b.uid)
	_check("ChampionInventory.remove(): the item out, returned; the uid isn't reused",
		[inv.remove(a.uid) == a, inv.items.size(), inv.items[0] == b, inv.next_uid], [true, 1, true, 3])
	_check("an unknown uid: null, nothing changes", [inv.remove(99), inv.items.size()], [null, 1])
	_check("it never touches equipped (the caller refuses a worn item first)", inv.equipped, {&"helm": b.uid})
	_check("LootTable.trash_confirm_from: Unique", _table.trash_confirm_from, R.UNIQUE)
	var asks: Array = []
	for r in 7:
		asks.append(Loot.needs_trash_confirm(_item(&"item_base_band", r as Item.Rarity, [], 0)))
	_check("trashing asks first from Unique up", asks, [false, false, false, true, true, true, true])
	Loot.reset(KNIGHT)
	var p := await _spawn_knight()
	var mine := _item(&"item_base_band", R.COMMON, [[&"affix_crit_chance", 0.5]], 0)
	var worn := _item(&"item_base_iron_helm", R.RARE, [[&"affix_armor", 0.5]], 0)
	Loot.add_item(KNIGHT, mine)
	Loot.add_item(KNIGHT, worn)
	p.equipment.equip(worn)
	var stranger := _item(&"item_base_band", R.COMMON, [[&"affix_crit_chance", 0.5]], 0)
	_check("can_remove(): yes for a carried item, no for none, a stranger, a worn one (by the record and by the unit)",
		[Loot.can_remove(KNIGHT, mine, p), Loot.can_remove(KNIGHT, null), Loot.can_remove(KNIGHT, stranger),
		Loot.can_remove(KNIGHT, worn), Loot.can_remove(KNIGHT, worn, p)],
		["", "No item", "Not in Knight's inventory", "Worn: unequip it first", "Worn: unequip it first"])
	_check("a worn item: neither trashed nor dropped, still carried and worn",
		[Loot.trash_item(KNIGHT, worn, p), Loot.drop_from_inventory(KNIGHT, worn, p), Loot.get_inventory(KNIGHT).items.has(worn), p.equipment.get_slot_of(worn)],
		[false, null, true, &"helm"])
	await _free(p)


func _test_drop_item() -> void:
	_section("L7b: dropping an item: back on the ground, not taken back until the Knight walks away")
	Loot.reset(KNIGHT)
	var setup := await _sandbox_room()
	var room: Room = setup[0]
	var p: Player = setup[2]
	var entities := room.get_node("Entities")
	var record := Loot.get_inventory(KNIGHT)
	var item := _item(&"item_base_leather_gloves", R.UNIQUE, [[&"affix_attack_speed", 0.5], [&"affix_armor", 0.4], [&"affix_crit_chance", 0.3]], 0)
	Loot.add_item(KNIGHT, item)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_SAVE))
	Loot.save_path = SCRATCH_SAVE
	Loot.saving_enabled = true
	var seen: Array = []
	var on_drop := func(champion_id: StringName, it: Item) -> void: seen.append([champion_id, it])
	Loot.item_dropped.connect(on_drop)
	Loot.rng.seed = 7801
	var feet := p.global_position
	var pickup := Loot.drop_from_inventory(KNIGHT, item, p)
	var saved := _read_scratch()
	Loot.saving_enabled = false
	Loot.save_path = Loot.SAVE_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_SAVE))
	Loot.item_dropped.disconnect(on_drop)
	_check("out of the inventory and the save at once; item_dropped once",
		[record.items.has(item), saved != null and saved.items.is_empty(), seen], [false, true, [[&"knight", item]]])
	var away := pickup.global_position.distance_to(feet) if pickup != null else -1.0
	_check("a pickup in the room's Entities, popping from his feet to %.1f px off (12–28), held for him" % away,
		[pickup != null and pickup.get_parent() == entities, pickup.get_hop_from() == feet if pickup else false, away >= 12.0 and away <= 28.0, pickup.is_held_for(p) if pickup else false],
		[true, true, true, true])
	await _frames(30)
	_check("landed inside his 64 px: not taken back while he stands there",
		[is_instance_valid(pickup) and pickup.is_landed(), record.items.size(), pickup.is_held_for(p) if is_instance_valid(pickup) else false], [true, 0, true])
	_place_unit(p, feet + Vector2(150, 0))
	await _frames(3)
	_check("he walks away: the hold ends; nothing taken", [pickup.is_held_for(p), record.items.size()], [false, 0])
	_place_unit(p, feet)
	await _frames(3)
	_check("he comes back: taken, with a new uid", [record.items.has(item), item.uid, is_instance_valid(pickup) and not pickup.is_queued_for_deletion()], [true, 2, false])
	# Walking off while it still hops (no area_exited: it never became collectable around him).
	Loot.rng.seed = 7802
	var hopper := Loot.drop_from_inventory(KNIGHT, item, p)
	_place_unit(p, feet + Vector2(150, 0))
	await _frames(3)
	var released := not hopper.is_held_for(p)
	await _frames(25)
	_check("walked off during the hop: the hold ends then, and it lands untaken", [released, hopper.is_landed(), record.items.has(item)], [true, true, false])
	_place_unit(p, feet)
	await _frames(3)
	_check("back over it: taken", record.items.has(item), true)
	# Kept through a floor's rebuild; put back without the hold.
	Loot.rng.seed = 7803
	Loot.drop_from_inventory(KNIGHT, item, p)
	await _frames(25)
	var drops := Loot.take_ground_drops(room)
	_check("a dropped item is a ground drop like any (taken off the room)", [drops.size(), drops[0].item if drops.size() > 0 else {}], [1, item.to_dict()])
	_place_unit(p, feet + Vector2(150, 0))
	await _frames(2)
	var back := Loot.restore_ground_drops(room, drops)
	_check("put back: not held (the hold isn't saved)", [back.size(), back[0].is_held_for(p) if back.size() > 0 else true], [1, false])
	Loot.take_ground_drops(room)
	# SandboxLoot's L.
	var sl: SandboxLoot = setup[1]
	Loot.reset(KNIGHT)
	_place_unit(p, feet)
	await _frames(2)
	var first := _item(&"item_base_band", R.COMMON, [[&"affix_attack_damage", 0.1]], 0)
	var second := _item(&"item_base_band", R.UNCOMMON, [[&"affix_attack_damage", 0.2], [&"affix_crit_chance", 0.2]], 0)
	var third := _item(&"item_base_iron_helm", R.RARE, [[&"affix_armor", 0.3]], 0)
	for it in [first, second, third]:
		Loot.add_item(KNIGHT, it)
	p.equipment.equip(third)
	sl.move_cursor(-sl.get_cursor())
	_check("L on the first: dropped, said so; the next moves up into the cursor's row",
		[sl.drop_item(0), sl.get_status(), _plain(sl.get_items()), sl.get_cursor()], [true, "Dropped Band", [second, third], 0])
	_check("L on a worn item: refused, said so",
		[sl.drop_item(1), sl.get_status(), sl.get_items().has(third)], [false, "Can't drop Iron Helm: Worn: unequip it first", true])
	sl.move_cursor(-sl.get_cursor())
	_press(KEY_L)
	_check("L through the viewport drops the highlighted item", [_plain(sl.get_items()), sl.get_status()], [[third], "Dropped Band"])
	Loot.take_ground_drops(room)
	room.queue_free()
	await _frames(1)


func _test_trash_item() -> void:
	_section("L7b: trashing an item: gone for good; Unique and up ask first")
	Loot.reset(KNIGHT)
	var setup := await _sandbox_room()
	var room: Room = setup[0]
	var sl: SandboxLoot = setup[1]
	var p: Player = setup[2]
	var record := Loot.get_inventory(KNIGHT)
	var common := _item(&"item_base_band", R.COMMON, [[&"affix_attack_damage", 0.5]], 0)
	var unique := _item(&"item_base_leather_gloves", R.UNIQUE, [[&"affix_attack_speed", 0.5], [&"affix_armor", 0.4], [&"affix_crit_chance", 0.3]], 0)
	var legendary := ItemRoller.make_named(TIDEBREAKER, _table, _rng(7901))
	var rare := _item(&"item_base_iron_helm", R.RARE, [[&"affix_armor", 0.5]], 0)
	for it in [common, unique, legendary, rare]:
		Loot.add_item(KNIGHT, it)
	p.equipment.equip(rare)
	# Loot.trash_item() itself: no asking (the caller's job).
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_SAVE))
	Loot.save_path = SCRATCH_SAVE
	Loot.saving_enabled = true
	var seen: Array = []
	var on_trash := func(champion_id: StringName, it: Item) -> void: seen.append([champion_id, it])
	Loot.item_trashed.connect(on_trash)
	var spare := _item(&"item_base_pendant", R.UNCOMMON, [[&"affix_magic_find", 0.5], [&"affix_damage", 0.5]], 0)
	Loot.add_item(KNIGHT, spare)
	var done := Loot.trash_item(KNIGHT, spare, p)
	var saved := _read_scratch()
	Loot.saving_enabled = false
	Loot.save_path = Loot.SAVE_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_SAVE))
	_check("Loot.trash_item(): gone from the inventory and the save at once; item_trashed once; no pickup",
		[done, record.items.has(spare), saved != null and not saved.items.any(func(i: Item) -> bool: return i.to_dict() == spare.to_dict()), seen, Loot.get_ground_pickups(room).size()],
		[true, false, true, [[&"knight", spare]], 0])
	seen.clear()
	# X: a Common at once.
	sl.move_cursor(-sl.get_cursor())
	_check("X on a Common: trashed at once, said so", [sl.trash(0), record.items.has(common), sl.get_status(), sl.get_pending_trash()],
		[true, false, "Trashed Band", null])
	# X on a Unique: asks, then trashes.
	_check("X on a Unique: only asks; still carried", [sl.trash(0), record.items.has(unique), sl.get_status(), sl.get_pending_trash() == unique],
		[false, true, "Trash %s (Unique)? X again" % unique.get_display_name(), true])
	_check("X again on it: trashed", [sl.trash(0), record.items.has(unique), sl.get_status(), sl.get_pending_trash()], [true, false, "Trashed %s" % unique.get_display_name(), null])
	# Cancels: a cursor move, another key, the time running out.
	var idx := sl.get_items().find(legendary)
	sl.trash(idx)
	sl.move_cursor(1)
	_check("a Legendary asked, then the cursor moved: cancelled, said so", [sl.get_pending_trash(), sl.get_status(), record.items.has(legendary)], [null, "Trash cancelled", true])
	sl.move_cursor(-sl.get_cursor() + idx)
	_press(KEY_X)
	_press(KEY_H)
	_check("X, then an unrelated key (H): cancelled", [sl.get_pending_trash(), sl.get_status(), record.items.has(legendary)], [null, "Trash cancelled", true])
	sl.trash_confirm_time = 0.1
	_press(KEY_X)
	await _frames(12)
	_check("X, then 0.2 s with trash_confirm_time 0.1: cancelled by itself", [sl.get_pending_trash(), sl.get_status()], [null, "Trash cancelled"])
	sl.trash_confirm_time = 3.0
	_press(KEY_X)
	_check("so the next X asks again", [sl.get_pending_trash() == legendary, record.items.has(legendary)], [true, true])
	_press(KEY_X)
	_check("X again through the viewport: the Legendary trashed", [record.items.has(legendary), sl.get_status()], [false, "Trashed Tidebreaker"])
	_check("X on a worn item: refused, said so",
		[sl.trash(sl.get_items().find(rare)), record.items.has(rare), sl.get_status()], [false, true, "Can't trash Iron Helm: Worn: unequip it first"])
	Loot.item_trashed.disconnect(on_trash)
	_check("item_trashed for each trashed item", seen.map(func(e: Array) -> Item: return e[1]), [common, unique, legendary])
	room.queue_free()
	await _frames(1)


func _test_sort() -> void:
	_section("L7b: O sorts the list (pickup order, by slot, by rarity); a view only")
	Loot.reset(KNIGHT)
	var setup := await _sandbox_room()
	var room: Room = setup[0]
	var sl: SandboxLoot = setup[1]
	var record := Loot.get_inventory(KNIGHT)
	var ring_c := _item(&"item_base_band", R.COMMON, [[&"affix_attack_damage", 0.1]], 0)
	var helm_r := _item(&"item_base_iron_helm", R.RARE, [[&"affix_armor", 0.1]], 0)
	var sword_u := _item(&"item_base_longsword", R.UNCOMMON, [[&"affix_attack_damage", 0.1], [&"affix_crit_chance", 0.1]], 0)
	var ring_r := _item(&"item_base_band", R.RARE, [[&"affix_attack_damage", 0.2]], 0)
	var helm_c := _item(&"item_base_iron_helm", R.COMMON, [[&"affix_armor", 0.2]], 0)
	var ring_r2 := _item(&"item_base_band", R.RARE, [[&"affix_attack_damage", 0.3]], 0)
	var picked := [ring_c, helm_r, sword_u, ring_r, helm_c, ring_r2]
	for it in picked:
		Loot.add_item(KNIGHT, it)
	_check("by default: pickup order", [sl.get_sort(), _plain(sl.get_items())], [&"picked_up", picked])
	sl.move_cursor(-sl.get_cursor() + 3)   # ring_r
	_check("O: by slot (weapon, helm, ... ring), the best first, ties in pickup order",
		[sl.cycle_sort(), _plain(sl.get_items())], [&"slot", [sword_u, helm_r, helm_c, ring_r, ring_r2, ring_c]])
	_check("the cursor stays on the same item; the header and the result say so",
		[sl.get_items()[sl.get_cursor()] == ring_r, _row_texts(sl)[1].ends_with("   By slot"), sl.get_status()], [true, true, "Sorted by slot"])
	_press(KEY_O)
	_check("O again (through the viewport): by rarity, best first, then by slot",
		[sl.get_sort(), _plain(sl.get_items())], [&"rarity", [helm_r, ring_r, ring_r2, sword_u, helm_c, ring_c]])
	_check("(the cursor still on it)", sl.get_items()[sl.get_cursor()] == ring_r, true)
	_check("O a third time: pickup order again, no sort in the header", [sl.cycle_sort(), _plain(sl.get_items()), _row_texts(sl)[1].contains("By ")], [&"picked_up", picked, false])
	sl.cycle_sort()
	_check("a view only: the inventory keeps its order", record.items, picked)
	var newest := _item(&"item_base_longsword", R.RARE, [[&"affix_attack_damage", 0.3]], 0)
	Loot.restore_ground_drops(room, [{"item": newest.to_dict(), "pos": (setup[2] as Player).global_position}])
	await _frames(3)
	var taken: Item = record.items.back()
	_check("sorted by slot, a new pickup takes its place and the cursor follows it",
		[sl.get_items().find(taken), sl.get_cursor()], [0, 0])
	room.queue_free()
	await _frames(1)


func _test_hub_clear_inventory() -> void:
	_section("L7b: the hub's Clear inventory (for L-M): a second click empties it")
	Loot.reset(KNIGHT)
	for i in 3:
		Loot.add_item(KNIGHT, _item(&"item_base_band", R.COMMON, [[&"affix_attack_damage", 0.5]], 0))
	var hub := (load("res://scenes/ui/hub.tscn") as PackedScene).instantiate() as Hub
	add_child(hub)
	await _frames(1)
	var button: Button = null
	for b in hub.find_children("*", "Button", true, false):
		if (b as Button).text == "Clear inventory":
			button = b
	_check("the debug row has Clear inventory", button != null and button.get_parent().name == "DebugTools", true)
	_check("the first click only asks", [hub.debug_clear_inventory(), Loot.get_inventory(KNIGHT).items.size(), hub.get_detail_text()],
		[false, 3, "Click Clear inventory again to empty the Knight's inventory (3 items, for good)."])
	_check("the second empties it", [hub.debug_clear_inventory(), Loot.get_inventory(KNIGHT).items.size(), hub.get_detail_text()],
		[true, 0, "Emptied the Knight's inventory (3 items)."])
	_check("empty: nothing to ask", [hub.debug_clear_inventory(), hub.get_detail_text()], [false, "The Knight's inventory is already empty."])
	Loot.add_item(KNIGHT, _item(&"item_base_band", R.COMMON, [[&"affix_attack_damage", 0.5]], 0))
	hub.clear_confirm_time = 0.1
	hub.debug_clear_inventory()
	await _frames(12)
	_check("a second click after clear_confirm_time asks again", [hub.debug_clear_inventory(), Loot.get_inventory(KNIGHT).items.size()], [false, 1])
	if button != null:
		button.pressed.emit()
	_check("the button itself (the second click in time): emptied", Loot.get_inventory(KNIGHT).items.size(), 0)
	hub.queue_free()
	await _frames(1)


## A typed list of items (Loot.drop() takes Array[Item]).
func _items(list: Array) -> Array[Item]:
	var out: Array[Item] = []
	for item: Item in list:
		out.append(item)
	return out


## An enemy from `scene` in `room`'s Entities, `offset` from the room's origin
## (`passive`: a training dummy).
func _enemy_in(room: Room, scene: PackedScene, offset: Vector2, passive: bool = false) -> Enemy:
	var e: Enemy = scene.instantiate()
	e.passive = passive
	room.get_node("Entities").add_child(e)
	_place_unit(e, room.global_position + offset)
	return e


## A killing hit's context from `source` (null: none) on `target`, for
## Events.unit_died.
func _death(source: Variant, target: Unit) -> HitContext:
	var ctx := HitContext.new()
	ctx.source = source
	ctx.target = target
	ctx.killed = true
	return ctx


func _place_unit(unit: Node2D, at: Vector2) -> void:
	unit.global_position = at
	unit.reset_physics_interpolation()


## The loot sounds in Audio's log, oldest first: [file, positional, played at
## `spot` (always true when not positional)].
func _loot_sounds(spot: Vector2) -> Array:
	var rows: Array = []
	for e: Dictionary in Audio.get_log():
		var file := String(e.event).get_file()
		if not file.begins_with("sound_loot"):
			continue
		var positional: bool = e.positional
		rows.append([file, positional, not positional or (spot.is_finite() and (e.position as Vector2).distance_to(spot) < 0.5)])
	return rows


# --- Helpers ------------------------------------------------------------------

## A Knight from player.tscn in the tree (its saved gear equipped at load).
func _spawn_knight() -> Player:
	var p: Player = PLAYER_SCENE.instantiate()
	add_child(p)
	_next_x += 400.0
	p.global_position = Vector2(_next_x, 0)
	p.reset_physics_interpolation()
	await _frames(2)
	return p


## A Knight spawned while its record is set aside (the bare max health).
func _spawn_knight_with_empty_record() -> Player:
	var record := Loot.get_inventory(KNIGHT)
	var kept := record.equipped.duplicate()
	record.equipped.clear()
	var p := await _spawn_knight()
	record.equipped = kept
	return p


## A Room (depth 1) holding Entities and a SandboxLoot, with a Knight from
## player.tscn spawned in it: [room, sandbox loot, player].
func _sandbox_room() -> Array:
	var room := Room.new()
	room.bounds_px = Rect2(-160, -160, 320, 320)
	var entities := Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	room.add_child(entities)
	var sl := SandboxLoot.new()
	sl.name = "SandboxLoot"
	room.add_child(sl)
	_next_x += 400.0
	room.position = Vector2(_next_x, 0)
	add_child(room)
	var p := await _spawn_in(room)
	return [room, sl, p]


## A Knight from player.tscn in `room`'s Entities.
func _spawn_in(room: Room) -> Player:
	var p: Player = PLAYER_SCENE.instantiate()
	room.get_node("Entities").add_child(p)
	p.reset_physics_interpolation()
	await _frames(2)
	return p


## A passive slime (a training dummy) near `p`, each in its own spot. `tough`:
## a million more health, so no test hit kills it. _free_dummies() frees them.
func _dummy_near(p: Unit, tough: bool = true) -> Enemy:
	var d: Enemy = SLIME_SCENE.instantiate()
	d.passive = true
	add_child(d)
	_dummy_offset += 36.0
	d.global_position = p.global_position + Vector2(_dummy_offset, 90.0)
	d.reset_physics_interpolation()
	if tough:
		d.stats_component.add_modifier(StatModifier.create(&"max_health", StatModifier.Type.FLAT, 1000000.0, &"loot_test_tough"))
	_dummies.append(d)
	return d


func _free_dummies() -> void:
	for d in _dummies:
		if is_instance_valid(d):
			d.queue_free()
	_dummies.clear()
	await _frames(1)


## A plain hit of `amount` (physical, no crit, proc coefficient 1).
func _hit_from(source: Unit, target: Unit, amount: float) -> HitContext:
	var ctx := HitContext.new()
	ctx.source = source
	ctx.target = target
	ctx.base_damage = amount
	ctx.damage_type = HitContext.DamageType.PHYSICAL
	ctx.can_crit = false
	return HitPipeline.resolve(ctx)


## A hit that kills anything not tough.
func _kill(source: Unit, target: Unit) -> HitContext:
	return _hit_from(source, target, 1000000.0)


## `n` hits of 1 from `source` on `target` at proc coefficient `coefficient`
## (or proc-tagged hits, `as_procs`): the lightning bolts they called.
func _bolts_from(source: Unit, target: Unit, n: int, coefficient: float, as_procs: bool = false) -> Array[HitContext]:
	var bolts: Array[HitContext] = []
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.has_tag(&"lightning"):
			bolts.append(ctx)
	Events.unit_hit.connect(on_hit)
	for i in n:
		var ctx: HitContext
		if as_procs:
			ctx = HitPipeline.make_proc(source, target, 1.0)
		else:
			ctx = HitContext.new()
			ctx.source = source
			ctx.target = target
			ctx.base_damage = 1.0
			ctx.can_crit = false
			ctx.proc_coefficient = coefficient
		HitPipeline.resolve(ctx)
	Events.unit_hit.disconnect(on_hit)
	return bolts


## Waits (up to 2 s) for GameFeel's real-time hitstop to end, so game time runs.
func _wait_hitstop() -> void:
	for i in 120:
		if not GameFeel.is_hitstop_active():
			return
		await get_tree().physics_frame


func _status_mod_rows(status: StatusEffect) -> Array:
	var rows: Array = []
	for mod in status.modifiers:
		rows.append([mod.stat, mod.type, mod.value, mod.scope])
	return rows


## The unit's modifiers under `source_id`, as [stat, type, value, scope] rows.
func _mod_rows_from(unit: Unit, source_id: StringName) -> Array:
	var rows: Array = []
	for mod in unit.stats_component.get_modifiers_from(source_id):
		rows.append([mod.stat, mod.type, mod.value, mod.scope])
	return rows


## `named` made (rolled with a seed from `uid`), given `uid` and worn by `p`.
func _equip_named(p: Player, named: NamedItem, uid: int) -> Item:
	var item := ItemRoller.make_named(named, _table, _rng(uid))
	item.uid = uid
	p.equipment.equip(item)
	return item


## A copy of the Knight whose named items are his own plus `extra`.
func _knight_with(extra: Array) -> ChampionData:
	var c: ChampionData = KNIGHT.duplicate()
	var list: Array[NamedItem] = []
	list.append_array(KNIGHT.named_items)
	for n: NamedItem in extra:
		list.append(n)
	c.named_items = list
	return c


## A copy of the Knight without `named` (LOOT L6: a champion with no Artifact).
func _knight_without(named: NamedItem) -> ChampionData:
	var c: ChampionData = KNIGHT.duplicate()
	var list: Array[NamedItem] = []
	for n in KNIGHT.named_items:
		if n != named:
			list.append(n)
	c.named_items = list
	return c


## A copy of the Knight with no named items.
func _knight_with_none() -> ChampionData:
	var c: ChampionData = KNIGHT.duplicate()
	c.named_items = [] as Array[NamedItem]
	return c


## An Artifact for the Knight's Judgement in the Gloves, with 4 affixes (a
## fixture until L6's The Last Verdict).
func _fixture_artifact() -> NamedItem:
	var n: NamedItem = CHAINS_OF_JUDGEMENT.duplicate()
	n.id = &"knight_test_verdict"
	n.display_name = "Test Verdict"
	n.rarity = R.ARTIFACT
	n.modifiers = [] as Array[StatModifier]
	n.affixes = [_table.get_affix(&"affix_attack_damage"), _table.get_affix(&"affix_crit_chance"),
		_table.get_affix(&"affix_crit_damage"), _table.get_affix(&"affix_ability_haste")] as Array[Affix]
	return n


func _named_mod_rows(named: NamedItem) -> Array:
	var rows: Array = []
	for mod in named.modifiers:
		rows.append([mod.stat, mod.type, mod.value, mod.scope])
	return rows


## Waits (up to 2 s) until `u`'s post-hit i-frames are over.
func _wait_vulnerable(u: Unit) -> void:
	for i in 120:
		if not u.is_invulnerable():
			return
		await get_tree().physics_frame


## Presses `slot` and waits (up to 1 s) for its effect to start: the cast
## ability and, for each FLAG it supports, "flag_<id>": whether the cast had it.
func _cast_and_watch(p: Player, slot: StringName, aim: Vector2, target: Unit) -> Dictionary:
	var out := {}
	var on_cast := func(unit: Unit, ability: Ability, ctx: CastContext) -> void:
		if unit == p and not out.has("ability"):
			out["ability"] = ability
			for flag in ability.supported_flags:
				out["flag_" + String(flag)] = ctx.has_flag(flag)
	Events.ability_cast.connect(on_cast)
	await _wait_hitstop()
	p.abilities.try_cast(slot, aim, target)
	for i in 60:
		if out.has("ability"):
			break
		await _frames(1)
	await _frames(1)
	Events.ability_cast.disconnect(on_cast)
	return out


## Iron Resolve cast by a fresh Knight (with `talent_id` and Oathbound Plate
## when `with_item`), a dummy 40 px away: what it left.
func _iron_resolve_case(talent_id: StringName, with_item: bool) -> Dictionary:
	Loot.reset(KNIGHT)
	_dummy_offset = 0.0
	var p := await _spawn_knight()
	var near := _dummy_near(p)
	near.global_position = p.global_position + Vector2(40, 0)
	near.reset_physics_interpolation()
	if talent_id != &"":
		p.add_talent(KNIGHT.get_talent(talent_id))
	if with_item:
		_equip_named(p, OATHBOUND_PLATE, 801)
	p.resource_pool.restore(50.0)
	await _frames(1)
	var fury_before := p.resource_pool.current
	var cast := await _cast_and_watch(p, &"w", p.global_position, null)
	var statuses := p.status_component
	var out := {
		"cast": cast.get("ability") == IRON_RESOLVE,
		"undying": statuses.has_status(&"undying"),
		"undying_left_ok": absf(statuses.get_time_left(&"undying") - 1.5) < 0.05,
		"haste": statuses.has_status(&"iron_resolve"),
		"empower": statuses.has_status(AutoAttackComponent.get_empower_status_id(&"iron_resolve")),
		"shield": statuses.get_total_shield(),
		"staggered": near.status_component.has_status(&"staggered"),
		"cooldown_left": p.abilities.get_cooldown_left(&"w"),
		"fury_gained": p.resource_pool.current - fury_before,
	}
	await _free_dummies()
	await _free(p)
	return out


## Judgement cast by a fresh Knight (with `talent_id`, and Chains of Judgement
## when `with_item`) on a tough dummy at `offset`, with `blockers` ([layer,
## Rect2 relative to the Knight]) and an optional `bystander` dummy: what
## happened. "distance": the target from the Knight when the hit landed;
## "frames": from the first frame it was airborne to the hit; "moved": how far
## the target went.
func _drag_case(offset: Vector2, blockers: Array = [], talent_id: StringName = &"", unstoppable: bool = false,
		with_item: bool = true, bystander_at: Vector2 = Vector2.INF) -> Dictionary:
	Loot.reset(KNIGHT)
	_dummy_offset = 0.0
	var p := await _spawn_knight()
	if talent_id != &"":
		p.add_talent(KNIGHT.get_talent(talent_id))
	if with_item:
		_equip_named(p, CHAINS_OF_JUDGEMENT, 902)
	var target := _dummy_near(p)
	target.global_position = p.global_position + offset
	target.reset_physics_interpolation()
	var bystander: Enemy = null
	if bystander_at != Vector2.INF:
		bystander = _dummy_near(p)
		bystander.global_position = p.global_position + bystander_at
		bystander.reset_physics_interpolation()
	var bodies: Array[Node] = []
	for b: Array in blockers:
		var rect: Rect2 = b[1]
		bodies.append(_blocker(Rect2(p.global_position + rect.position, rect.size), b[0]))
	if unstoppable:
		var u := StatusEffect.new()
		u.id = &"test_unstoppable"
		u.tags = [&"unstoppable", &"buff"] as Array[StringName]
		u.duration = 10.0
		target.status_component.apply_status(u, target)
	await _frames(2)
	await _wait_hitstop()
	var start := target.global_position
	var out := {"airborne_seen": false, "bystander_hit": false}
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.source != p or ctx.ability == null or ctx.ability.id != &"knight_judgement" or ctx.blocked:
			return
		if ctx.target == target and not out.has("hit"):
			out["hit"] = true
			out["distance"] = target.global_position.distance_to(p.global_position)
			out["hit_frame"] = Engine.get_physics_frames()
			out["taken"] = ctx.taken_damage
		elif ctx.target == bystander:
			out["bystander_hit"] = true
	Events.unit_hit.connect(on_hit)
	out["cast"] = p.abilities.try_cast(&"r", target.global_position, target)
	var drag_start := -1
	for i in 200:
		if target.status_component.has_status(&"airborne"):
			out["airborne_seen"] = true
			if drag_start < 0:
				drag_start = Engine.get_physics_frames()
		if out.has("hit"):
			break
		await _frames(1)
	await _frames(2)
	Events.unit_hit.disconnect(on_hit)
	out["frames"] = int(out.get("hit_frame", 0)) - drag_start if drag_start >= 0 else -1
	out["stunned"] = target.status_component.has_status(&"stun")
	out["moved"] = target.global_position.distance_to(start)
	for body in bodies:
		body.queue_free()
	await _free_dummies()
	await _free(p)
	return out


## The drag checks' control: a slime 180 px out pushed (displace(), not
## airborne) as far as the drag would take it, with a blocker on `layer`
## across the way at 86–94 px. Returns where it ends, px from the origin.
func _push_case(layer: int) -> float:
	_next_x += 400.0
	var origin := Vector2(_next_x, 0)
	var d: Enemy = SLIME_SCENE.instantiate()
	d.passive = true
	add_child(d)
	d.global_position = origin + Vector2(180, 0)
	d.reset_physics_interpolation()
	var body := _blocker(Rect2(origin + Vector2(86, -60), Vector2(8, 120)), layer)
	await _frames(2)
	var gap := Units.to_px(35.0) + Units.to_px(45.0) + 8.0
	d.movement.displace(Vector2(-(180.0 - gap) / 0.15, 0.0), 0.15)
	await _frames(15)
	var distance := d.global_position.distance_to(origin)
	body.queue_free()
	d.queue_free()
	await _frames(1)
	return distance


## A StaticBody2D filling `rect` (global) on collision layer `layer` (1 =
## walls, 7 = low obstacles, 11 = ledges), colliding with nothing itself.
func _blocker(rect: Rect2, layer: int) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1 << (layer - 1)
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	body.global_position = rect.get_center()
	return body


## One key press pushed through the viewport, as a player's arrives.
func _press(keycode: Key, shift: bool = false, echo: bool = false) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.keycode = keycode
	ev.pressed = true
	ev.echo = echo
	ev.shift_pressed = shift
	get_viewport().push_input(ev)


func _row_texts(sl: SandboxLoot) -> Array:
	return sl.get_rows().map(func(row: Array) -> String: return row[0])


func _row_with(sl: SandboxLoot, needle: String) -> bool:
	return _row_texts(sl).any(func(text: String) -> bool: return text.contains(needle))


## The color of the first row containing `needle` (null if none).
func _row_color(sl: SandboxLoot, needle: String) -> Variant:
	for row: Array in sl.get_rows():
		var text: String = row[0]
		if text.contains(needle):
			return row[1]
	return null


func _find_label(sl: SandboxLoot) -> RichTextLabel:
	for child in sl.get_children():
		if child is CanvasLayer and child.get_child_count() > 0:
			return child.get_child(0) as RichTextLabel
	return null


## How many of `n` K rolls' items are of `rarity`.
func _count_rolled(sl: SandboxLoot, n: int, rarity: Item.Rarity) -> int:
	var count := 0
	for i in n:
		for item in sl.roll_drop():
			if item.rarity == rarity:
				count += 1
	return count


## The scratch save read back the way a new session would (null if unreadable).
func _read_scratch() -> ChampionInventory:
	var cfg := ConfigFile.new()
	if cfg.load(SCRATCH_SAVE) != OK:
		return null
	return ChampionInventory.read_from(cfg, KNIGHT, _table)


func _free(node: Node) -> void:
	node.queue_free()
	await _frames(1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## An item from ids: `affixes` is [[affix id, roll], ...].
func _item(base_id: StringName, rarity: Item.Rarity, affixes: Array, uid: int) -> Item:
	var item := Item.new()
	item.uid = uid
	item.rarity = rarity
	item.base = _table.get_base(base_id)
	for pair: Array in affixes:
		item.affix_rolls.append([_table.get_affix(pair[0]), pair[1]])
	return item


## Starts recording Events.item_equipped / item_unequipped: [kind, unit, item].
func _listen() -> Array:
	var seen: Array = []
	var on := func(unit: Unit, item: Item) -> void: seen.append(["on", unit, item])
	var off := func(unit: Unit, item: Item) -> void: seen.append(["off", unit, item])
	Events.item_equipped.connect(on)
	Events.item_unequipped.connect(off)
	set_meta(&"listen_on", on)
	set_meta(&"listen_off", off)
	return seen


func _unlisten(_log: Array) -> void:
	Events.item_equipped.disconnect(get_meta(&"listen_on"))
	Events.item_unequipped.disconnect(get_meta(&"listen_off"))


## The recorded events for `unit` as [kind, uid].
func _log_rows(seen: Array, unit: Unit) -> Array:
	var rows: Array = []
	for e: Array in seen:
		if e[1] == unit:
			rows.append([e[0], (e[2] as Item).uid])
	return rows


func _rule_sources(unit: Unit) -> Array:
	return unit.get_reaction_rule_entries().map(func(e: Array) -> StringName: return e[1])


## The record written to a ConfigFile, as text, and read back.
func _through_text(inv: ChampionInventory) -> ChampionInventory:
	var cfg := ConfigFile.new()
	inv.write_to(cfg)
	var cfg2 := ConfigFile.new()
	cfg2.parse(cfg.encode_to_text())
	return ChampionInventory.read_from(cfg2, KNIGHT, _table)


## A close request sent to `autoload` (Progress or Loot) while its save path
## points at a scratch file with content: the test-scene guard must stop the
## save, so the file keeps its bytes.
func _check_close_request(autoload: Node, label: String) -> void:
	var scratch := "user://loot_test_%s_scratch.cfg" % label.to_lower()
	var content := "[keep]\n\nlevel=12\n"
	var f := FileAccess.open(scratch, FileAccess.WRITE)
	f.store_string(content)
	f.close()
	var real_path: String = autoload.get(&"save_path")
	autoload.set(&"save_path", scratch)
	autoload.notification(NOTIFICATION_WM_CLOSE_REQUEST)
	autoload.set(&"save_path", real_path)
	var kept := FileAccess.get_file_as_string(scratch)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
	_check("%s: a close request in a test scene, before anything else, writes nothing" % label, kept, content)
	_check("%s: and turns its saving off" % label, autoload.get(&"saving_enabled"), false)


## Whether a file exists and when it was last written ([] = no file).
func _file_stamp(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	return [FileAccess.get_modified_time(path)]


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
	s.name_suffix = String(id).trim_prefix("sigil_").capitalize()
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
