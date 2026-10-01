extends Node2D
## TALENTS.md test: open res://scenes/tests/talents_test.tscn and press F6.
## T2: the Knight's first 14 talents: their data (groups, tiers, requirements
## as in TALENTS.md, siblings never sharing a stat), each number talent's
## param, Battle Cry's Fury, Twin Lunge's charges, Executioner's stun and
## reset, and Unbroken's four talents at low and full health.
## T3: the six FLAG talents: every REPLACE variant supporting its base's talent
## FLAGs, Whirling and Rending Cleave (who they hit, reach, damage, knockback)
## and their Cleave Wave takes, Challenge and Bulwark, Tackle, Shockwave (the
## splash's share, stuns, the Fury payoff).
## T3b: rewritten ability tooltips (Talent.ability_description).
## T4: ChampionLeveling, ChampionProgress (XP, levels, unlocks, the loadout
## rules, sanitizing, the save round trip), the Progress autoload (the
## test-scene save guard, counting casts and kills live), the HUD lines, the
## Player reading its loadout from the record. Runs last: it changes the
## Knight's in-memory record (reset at the end).
## T1: the talent framework. ToolkitBundle (the bundle moved out of Passive,
## Unbroken unchanged), Talent and TalentRequirement data, each piece kind
## (modifier, StatScaling, rule, FLAG, EVENT) attaching and detaching exactly
## by its source id, validation catching every broken group rule, PASSIVE
## talents that replace, add, or both (and the passive slot showing it), the
## loadout attached at load, an empty loadout changing nothing, and
## SandboxTalents toggling talents on the live player.
## Prints PASS/FAIL per check, then a total.
## Run headless and it quits with the number of failures as the exit code.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const SANDBOX_SCENE: PackedScene = preload("res://scenes/rooms/sandbox.tscn")
const KNIGHT: ChampionData = preload("res://data/champions/knight.tres")
const CLEAVE: Ability = preload("res://data/abilities/knight_q_cleave.tres")
const LUNGE: Ability = preload("res://data/abilities/knight_e_lunge.tres")
const UNBROKEN_CURVE: Curve = preload("res://data/curves/curve_knight_unbroken.tres")
const AUGMENT_LUNGE_STUNS: AbilityAugment = preload("res://data/augments/augment_lunge_stuns.tres")
const AUGMENT_JUDGEMENT_RESET: AbilityAugment = preload("res://data/augments/augment_judgement_reset.tres")
const AUGMENT_CLEAVE_WAVE: AbilityAugment = preload("res://data/augments/augment_cleave_wave.tres")
const STATUS_HASTE: StatusEffect = preload("res://data/statuses/status_haste.tres")
const IRON_RESOLVE: Ability = preload("res://data/abilities/knight_w_iron_resolve.tres")
const JUDGEMENT: Ability = preload("res://data/abilities/knight_r_judgement.tres")
const CLEAVE_WAVE: Ability = preload("res://data/abilities/knight_q_cleave_wave.tres")
const SLIME_SCENE: PackedScene = preload("res://scenes/enemies/slime.tscn")

const Q := Talent.Group.Q
const E := Talent.Group.E
const R := Talent.Group.R
const PASSIVE := Talent.Group.PASSIVE
const CLEAVE_SCOPE := &"ability:knight_cleave"

var _passed: int = 0
var _failed: int = 0
var _next_x: float = 0.0


func _ready() -> void:
	print("\n=== Talents test (TALENTS T1–T5) ===")
	await _test_bundle_refactor()
	_test_talent_data()
	await _test_piece_kinds()
	_test_validation()
	await _test_passive_replace_and_add()
	await _test_loadout_at_load()
	await _test_empty_loadout()
	await _test_sandbox_talents()
	_test_knight_set_data()
	await _test_knight_numbers()
	await _test_battle_cry()
	await _test_twin_lunge()
	await _test_executioner()
	await _test_unbroken_talents()
	_test_variant_flags()
	await _test_whirling_cleave()
	await _test_rending_cleave()
	await _test_cleave_wave_flags()
	await _test_challenge_and_bulwark()
	await _test_tackle()
	await _test_shockwave()
	await _test_description_overrides()
	# T4 last: it changes the Knight's in-memory progress record.
	_test_leveling_data()
	_test_record_xp_and_unlocks()
	_test_record_loadout_rules()
	_test_record_sanitize_and_save()
	await _test_progress_saving_guard()
	await _test_counting_live()
	await _test_level_and_unlock_lines()
	await _test_loadout_from_record()
	await _test_hub()
	Progress.reset(KNIGHT)
	# The last check ends on a Judgement hit sound; stop it so nothing plays at exit.
	Audio.stop_all()
	await _frames(2)
	print("=== %d passed, %d failed ===\n" % [_passed, _failed])

	if DisplayServer.get_name() == "headless":
		get_tree().quit(_failed)


# --- Tests --------------------------------------------------------------------

func _test_bundle_refactor() -> void:
	_section("ToolkitBundle: the bundle moved out of Passive")
	_check("Passive and Talent are ToolkitBundles", [Passive.new() is ToolkitBundle, Talent.new() is ToolkitBundle], [true, true])
	var unbroken := KNIGHT.passive
	_check("knight.tres's inline Unbroken loads as before: name, one scaling, no other pieces",
		[unbroken.display_name, unbroken.stat_scalings.size(), unbroken.modifiers.size(), unbroken.reaction_rules.size(), unbroken.statuses.size(), unbroken.augments.size()],
		["Unbroken", 1, 0, 0, 0, 0])
	_check("its stats: attack_damage", _plain(unbroken.get_stats()), [&"attack_damage"])
	var k := await _spawn(KNIGHT)
	_set_health(k, 0.2)
	await _frames(2)
	_check("the loaded Knight at 20% health: 64 x 1.4 = 89.6 AD (as before T1)", k.stats_component.get_stat(&"attack_damage"), 89.6)
	await _free(k)


func _test_talent_data() -> void:
	_section("Talent and TalentRequirement data")
	var champ := _champion([])
	var t := _talent(&"knight_test_q", Q, 1)
	_check("source id talent_<id>", t.get_source_id(), &"talent_knight_test_q")
	_check("Q group: slot q, ability Cleave", [t.get_group_slot(), t.get_group_ability(champ) == CLEAVE], [&"q", true])
	var p := _talent(&"knight_test_p", PASSIVE, 1)
	_check("PASSIVE group: no slot, no ability", [p.get_group_slot(), p.get_group_ability(champ) == null], [&"", true])
	_check("defaults: tier 1, exclusive, no requirements, replaces nothing", [t.tier, t.exclusive, t.requirements.size(), t.replaces_passive_stats.size()], [1, true, 0, 0])
	var sibling := _talent(&"knight_test_q2", Q, 1)
	var deeper := _talent(&"knight_test_q3", Q, 2)
	_check("siblings: same group and tier only", [t.is_sibling_of(sibling), t.is_sibling_of(deeper), t.is_sibling_of(t), t.is_sibling_of(p)], [true, false, false, false])
	_check("labels: level, Cleave casts, kills, tagged kills",
		[_req(TalentRequirement.Kind.CHAMPION_LEVEL, 2).get_label(t, champ), _req(TalentRequirement.Kind.ABILITY_USES, 200).get_label(t, champ),
			_req(TalentRequirement.Kind.KILLS, 150).get_label(p, champ), _req(TalentRequirement.Kind.KILLS, 5, &"elite").get_label(p, champ)],
		["Champion level", "Cleave casts", "Kills", "Elite kills"])


func _test_piece_kinds() -> void:
	_section("Each piece kind attaches and detaches exactly by its source id")
	var mod_t := _talent(&"knight_test_mod", Q, 1)
	mod_t.modifiers = [StatModifier.create(&"cooldown", StatModifier.Type.FLAT, -1.0, &"", CLEAVE_SCOPE)]
	var scale_t := _talent(&"knight_test_scaling", Q, 1)
	var scaling := StatScaling.new()
	scaling.modifier = StatModifier.create(&"cast_range", StatModifier.Type.PERCENT_ADD, 0.5, &"", CLEAVE_SCOPE)
	scale_t.stat_scalings = [scaling]
	var rule_t := _talent(&"knight_test_rule", Q, 2)
	var rule := ReactionRule.new()
	rule.id = &"test_talent_rule"
	rule.trigger = ReactionRule.Trigger.ABILITY_CAST
	rule.required_ability_scope = CLEAVE_SCOPE
	rule_t.reaction_rules = [rule]
	var flag_t := _talent(&"knight_test_flag", E, 2)
	flag_t.augments = [AUGMENT_LUNGE_STUNS]
	var event_t := _talent(&"knight_test_event", R, 2)
	event_t.augments = [AUGMENT_JUDGEMENT_RESET]
	var all: Array[Talent] = [mod_t, scale_t, rule_t, flag_t, event_t]
	for t in all:
		_check("valid: %s" % t.id, Array(t.get_validation_errors(_champion(all))), [])
	var k := await _spawn(_champion(all))
	var before := _all_values(k)
	var cooldown_before := CLEAVE.get_param(k, &"cooldown")
	var range_before := CLEAVE.get_param(k, &"cast_range")

	_check("modifier: added", k.add_talent(mod_t), true)
	_check("modifier: Cleave's cooldown 3 -> 2 (under talent_knight_test_mod)", [CLEAVE.get_param(k, &"cooldown"), k.stats_component.get_modifiers_from(&"talent_knight_test_mod").size()], [cooldown_before - 1.0, 1])
	_check("modifier: the .tres original untouched", mod_t.modifiers[0].source_id, &"")
	k.add_talent(scale_t)
	_set_health(k, 0.1)
	await _frames(2)
	_check_near("StatScaling: at 10% health Cleave's range +45% (0.9 x 0.5)", CLEAVE.get_param(k, &"cast_range"), range_before * 1.45, 0.01)
	k.add_talent(rule_t)
	_check("rule: added under talent_knight_test_rule", _rule_sources(k).has(&"talent_knight_test_rule"), true)
	k.add_talent(flag_t)
	_check("FLAG: Lunge stuns (on E)", [k.abilities.get_augments(&"e").has(AUGMENT_LUNGE_STUNS), k.abilities.get_flags(LUNGE).has(&"lunge_stuns")], [true, true])
	k.add_talent(event_t)
	_check("EVENT: Judgement's reset on R, its rule under augment_judgement_reset", [k.abilities.get_augments(&"r").has(AUGMENT_JUDGEMENT_RESET), _rule_sources(k).has(&"augment_judgement_reset")], [true, true])
	_check("adding one twice is refused", k.add_talent(mod_t), false)
	_check("five active, in the order added", k.get_active_talents(), all)

	for t in all:
		k.remove_talent(t)
	_set_health(k, 1.0)
	await _frames(2)
	_check("all removed: every live stat as before", _all_values(k), before)
	_check("all removed: Cleave's cooldown and range as before", [CLEAVE.get_param(k, &"cooldown"), CLEAVE.get_param(k, &"cast_range")], [cooldown_before, range_before])
	_check("all removed: no talent rule, augment or scaling left",
		[_rule_sources(k).has(&"talent_knight_test_rule"), _rule_sources(k).has(&"augment_judgement_reset"), k.abilities.get_augments(&"e").size(), k.abilities.get_augments(&"r").size(), k.get_stat_scalings().size()],
		[false, false, 0, 0, 1])
	_check("removing one that isn't on is refused", k.remove_talent(mod_t), false)
	await _free(k)


func _test_validation() -> void:
	_section("Validation catches every broken group rule")
	var champ := _champion([])
	var unscoped := _talent(&"t_unscoped", Q, 1)
	unscoped.modifiers = [StatModifier.create(&"attack_damage", StatModifier.Type.FLAT, 10.0, &"")]
	_expect_error("an unscoped modifier in Q", unscoped, champ, "scoped ''")
	var other_scope := _talent(&"t_other_scope", Q, 1)
	other_scope.modifiers = [StatModifier.create(&"cooldown", StatModifier.Type.FLAT, -1.0, &"", &"ability:knight_lunge")]
	_expect_error("another ability's scope in Q", other_scope, champ, "ability:knight_lunge")
	var tag_scope := _talent(&"t_tag_scope", Q, 1)
	var tag_scaling := StatScaling.new()
	tag_scaling.modifier = StatModifier.create(&"cooldown", StatModifier.Type.FLAT, -1.0, &"", &"tag:core")
	tag_scope.stat_scalings = [tag_scaling]
	_expect_error("a tag: scope on a StatScaling in Q", tag_scope, champ, "tag:core")
	var replace := _talent(&"t_replace", Q, 2)
	replace.augments = [AUGMENT_CLEAVE_WAVE]
	_expect_error("a REPLACE augment", replace, champ, "REPLACE")
	var wrong_flag := _talent(&"t_wrong_flag", Q, 2)
	var flag := AUGMENT_LUNGE_STUNS.duplicate() as AbilityAugment
	flag.scope = CLEAVE_SCOPE
	wrong_flag.augments = [flag]
	_expect_error("a FLAG the ability doesn't support", wrong_flag, champ, "supported_flags")
	var rule_scope := _talent(&"t_rule_scope", Q, 2)
	var rule := ReactionRule.new()
	rule.id = &"t_rule"
	rule_scope.reaction_rules = [rule]
	_expect_error("a rule without the ability's scope in Q", rule_scope, champ, "required_ability_scope")
	var status_t := _talent(&"t_status", Q, 1)
	status_t.statuses = [STATUS_HASTE]
	_expect_error("an always-on status in Q", status_t, champ, "always-on statuses")
	var replaces_in_q := _talent(&"t_replaces_q", Q, 1)
	replaces_in_q.replaces_passive_stats = [&"attack_damage"]
	_expect_error("replaces_passive_stats outside PASSIVE", replaces_in_q, champ, "outside the PASSIVE group")
	var uses_in_p := _talent(&"t_uses_p", PASSIVE, 1)
	uses_in_p.requirements = [_req(TalentRequirement.Kind.ABILITY_USES, 10)]
	_expect_error("ABILITY_USES in PASSIVE", uses_in_p, champ, "ABILITY_USES")
	var aug_in_p := _talent(&"t_aug_p", PASSIVE, 1)
	aug_in_p.augments = [AUGMENT_LUNGE_STUNS]
	_expect_error("an augment in PASSIVE", aug_in_p, champ, "augments in a PASSIVE")
	var reach_p := _talent(&"t_reach_p", PASSIVE, 1)
	reach_p.modifiers = [StatModifier.create(&"cooldown", StatModifier.Type.FLAT, -1.0, &"", CLEAVE_SCOPE)]
	_expect_error("an ability: scope in PASSIVE", reach_p, champ, "can't reach into")
	var lacks := _talent(&"t_lacks", PASSIVE, 1)
	lacks.replaces_passive_stats = [&"armor"]
	_expect_error("replacing a stat the passive doesn't have", lacks, champ, "doesn't have")
	var tag_on_level := _talent(&"t_tag_level", Q, 1)
	tag_on_level.requirements = [_req(TalentRequirement.Kind.CHAMPION_LEVEL, 2, &"elite")]
	_expect_error("enemy_tag on a non-KILLS requirement", tag_on_level, champ, "KILLS only")
	var no_id := _talent(&"", Q, 1)
	_expect_error("no id", no_id, champ, "no id")
	var good := _talent(&"t_good", Q, 1)
	good.modifiers = [StatModifier.create(&"resource_cost", StatModifier.Type.FLAT, -5.0, &"", CLEAVE_SCOPE)]
	good.requirements = [_req(TalentRequirement.Kind.CHAMPION_LEVEL, 2), _req(TalentRequirement.Kind.ABILITY_USES, 200)]
	_check("a valid Q talent with requirements: no errors", Array(good.get_validation_errors(champ)), [])
	var good_p := _talent(&"t_good_p", PASSIVE, 2)
	good_p.replaces_passive_stats = [&"attack_damage"]
	good_p.requirements = [_req(TalentRequirement.Kind.KILLS, 1500), _req(TalentRequirement.Kind.KILLS, 10, &"elite")]
	_check("a valid PASSIVE talent (replaces AD, kill requirements): no errors", Array(good_p.get_validation_errors(champ)), [])


func _test_passive_replace_and_add() -> void:
	_section("PASSIVE talents: replace, add, or both (and the passive slot)")
	var add_t := _talent(&"knight_test_add", PASSIVE, 1)
	add_t.display_name = "Test Add"
	add_t.stat_scalings = [_unbroken_scaling(&"attack_damage", StatModifier.Type.PERCENT_ADD, 0.15)]
	var replace_t := _talent(&"knight_test_replace", PASSIVE, 2)
	replace_t.display_name = "Test Replace"
	replace_t.replaces_passive_stats = [&"attack_damage"]
	var both_t := _talent(&"knight_test_both", PASSIVE, 2)
	both_t.display_name = "Test Both"
	both_t.replaces_passive_stats = [&"attack_damage"]
	both_t.stat_scalings = [_unbroken_scaling(&"attack_speed", StatModifier.Type.PERCENT_ADD, 0.5)]
	var k := await _spawn(_champion([add_t, replace_t, both_t]))
	var hud: CanvasLayer = HUD_SCENE.instantiate()
	add_child(hud)
	hud.setup_abilities(k)
	var slot: Control = hud.get_node("PassiveSlot")
	var base_speed := k.stats_component.get_stat(&"attack_speed")
	_set_health(k, 0.2)
	await _frames(2)
	_check("no talents at 20% health: 89.6 AD (Unbroken +40%)", k.stats_component.get_stat(&"attack_damage"), 89.6)

	k.add_talent(add_t)
	await _frames(2)
	_check("add: 64 x 1.55 = 99.2 AD", k.stats_component.get_stat(&"attack_damage"), 99.2)
	_check("add: the slot shows Unbroken's line and the talent's",
		slot.call("get_tooltip_lines"), PackedStringArray(["Unbroken", KNIGHT.passive.description, "Now: +40% attack damage", "Test Add (talent)", "Now: +15% attack damage"]))
	k.remove_talent(add_t)

	k.add_talent(replace_t)
	await _frames(2)
	_check("replace: Unbroken's AD left out: 64 AD at 20% health", k.stats_component.get_stat(&"attack_damage"), 64.0)
	_check("replace: the passive's scaling isn't attached, its source has no modifier", [k.get_stat_scalings().size(), k.stats_component.get_modifiers_from(KNIGHT.get_passive_source_id()).size()], [0, 0])
	_check("replace: the slot shows no +40% and says what's replaced",
		slot.call("get_tooltip_lines"), PackedStringArray(["Unbroken", KNIGHT.passive.description, "Test Replace (talent)", "Replaces Unbroken's attack damage"]))
	k.remove_talent(replace_t)
	await _frames(2)
	_check("replace removed: Unbroken re-attached: 89.6 AD", k.stats_component.get_stat(&"attack_damage"), 89.6)

	k.add_talent(both_t)
	await _frames(2)
	_check("both: 64 AD, attack speed x 1.5", [k.stats_component.get_stat(&"attack_damage"), k.stats_component.get_stat(&"attack_speed")], [64.0, base_speed * 1.5])
	k.add_talent(add_t)
	await _frames(2)
	_check("both + an add on the replaced stat: only Unbroken's own +40% is left out (64 x 1.15 = 73.6)", k.stats_component.get_stat(&"attack_damage"), 73.6)
	_set_health(k, 1.0)
	await _frames(2)
	_check("at full health: 64 AD, base attack speed (the curve's 0)", [k.stats_component.get_stat(&"attack_damage"), k.stats_component.get_stat(&"attack_speed")], [64.0, base_speed])
	k.remove_talent(both_t)
	k.remove_talent(add_t)
	_set_health(k, 0.2)
	await _frames(2)
	_check("all removed: 89.6 AD, base attack speed, one scaling", [k.stats_component.get_stat(&"attack_damage"), k.stats_component.get_stat(&"attack_speed"), k.get_stat_scalings().size()], [89.6, base_speed, 1])
	_check("all removed: the slot as before T1", slot.call("get_tooltip_lines"), PackedStringArray(["Unbroken", KNIGHT.passive.description, "Now: +40% attack damage"]))
	hud.queue_free()
	await _free(k)


func _test_loadout_at_load() -> void:
	_section("The loadout attaches at load (Player.talent_loadout, until T4)")
	var cheap := _talent(&"knight_test_cheap", Q, 1)
	cheap.modifiers = [StatModifier.create(&"resource_cost", StatModifier.Type.FLAT, -5.0, &"", CLEAVE_SCOPE)]
	var broken := _talent(&"knight_test_broken", Q, 1)
	broken.modifiers = [StatModifier.create(&"attack_damage", StatModifier.Type.FLAT, 100.0, &"")]
	var replace_t := _talent(&"knight_test_replace", PASSIVE, 1)
	replace_t.replaces_passive_stats = [&"attack_damage"]
	var champ := _champion([cheap, broken, replace_t])
	var k := await _spawn(champ, [&"knight_test_cheap", &"knight_test_missing", &"knight_test_broken", &"knight_test_replace"])
	_check("active: the valid ones, in loadout order (a missing id and an invalid talent skipped)", k.get_active_talents(), [cheap, replace_t])
	_check("Cleave costs 15", k.abilities.get_slot_cost(&"q"), 15.0)
	_check("the broken talent's +100 AD never attached", k.stats_component.get_modifiers_from(&"talent_knight_test_broken").size(), 0)
	_set_health(k, 0.2)
	await _frames(2)
	_check("the passive attached without the replaced AD: 64 at 20% health", k.stats_component.get_stat(&"attack_damage"), 64.0)
	await _free(k)


func _test_empty_loadout() -> void:
	_section("An empty loadout changes nothing")
	var k := await _spawn(KNIGHT)
	_check("player.tscn: an empty talent_loadout, no active talents, nothing left out", [k.talent_loadout.size(), k.get_active_talents().size(), k.get_left_out_passive_stats().size()], [0, 0, 0])
	_check("the passive's scaling attached as before", k.get_stat_scalings().size(), 1)
	var plain := await _spawn(KNIGHT)
	_check("two Knights: the same live stats", _all_values(k), _all_values(plain))
	await _free(k)
	await _free(plain)


func _test_sandbox_talents() -> void:
	_section("SandboxTalents: toggles talents on the live player")
	var sandbox: Node = SANDBOX_SCENE.instantiate()
	var node: Node = sandbox.get_node_or_null("SandboxTalents")
	_check("sandbox.tscn has a SandboxTalents node", node is SandboxTalents, true)
	sandbox.free()
	var cheap := _talent(&"knight_test_cheap", Q, 1)
	cheap.display_name = "Cheap"
	cheap.modifiers = [StatModifier.create(&"resource_cost", StatModifier.Type.FLAT, -5.0, &"", CLEAVE_SCOPE)]
	var broken := _talent(&"knight_test_broken", Q, 1)
	broken.modifiers = [StatModifier.create(&"attack_damage", StatModifier.Type.FLAT, 100.0, &"")]
	var room := Node2D.new()
	var entities := Node2D.new()
	entities.name = "Entities"
	room.add_child(entities)
	add_child(room)
	var p: Player = PLAYER_SCENE.instantiate()
	p.champion = _champion([cheap, broken])
	entities.add_child(p)
	_place(p)
	var st := SandboxTalents.new()
	room.add_child(st)
	await _frames(1)
	_check("it lists the champion's talents", st.get_talents(), [cheap, broken])
	_check("toggle 0: on, Cleave costs 15", [st.toggle(0), p.abilities.get_slot_cost(&"q")], [true, 15.0])
	_check("toggle 0 again: off, Cleave costs 20", [st.toggle(0), p.abilities.get_slot_cost(&"q")], [false, 20.0])
	_check("an invalid talent is refused (stays off)", [st.toggle(1), st.is_on(1)], [false, false])
	st.move_cursor(1)
	st.move_cursor(1)
	_check("the cursor wraps", st._cursor, 0)
	room.queue_free()
	await _frames(1)


# --- T2: the Knight's set, part 1 -----------------------------------------------

## id -> [group, tier, champion level, requirement kind, amount] (TALENTS.md,
## The Knight's talents): all 20 since T3.
const KNIGHT_T2 := {
	&"knight_thrifty_edge": [Q, 1, 2, TalentRequirement.Kind.ABILITY_USES, 200],
	&"knight_long_reach": [Q, 1, 2, TalentRequirement.Kind.ABILITY_USES, 200],
	&"knight_whirling_cleave": [Q, 2, 6, TalentRequirement.Kind.ABILITY_USES, 1800],
	&"knight_rending_cleave": [Q, 2, 6, TalentRequirement.Kind.ABILITY_USES, 1800],
	&"knight_quick_recovery": [Talent.Group.W, 1, 2, TalentRequirement.Kind.ABILITY_USES, 75],
	&"knight_battle_cry": [Talent.Group.W, 1, 2, TalentRequirement.Kind.ABILITY_USES, 75],
	&"knight_challenge": [Talent.Group.W, 2, 6, TalentRequirement.Kind.ABILITY_USES, 750],
	&"knight_bulwark": [Talent.Group.W, 2, 6, TalentRequirement.Kind.ABILITY_USES, 750],
	&"knight_long_lunge": [E, 1, 2, TalentRequirement.Kind.ABILITY_USES, 90],
	&"knight_quick_footing": [E, 1, 2, TalentRequirement.Kind.ABILITY_USES, 90],
	&"knight_tackle": [E, 2, 6, TalentRequirement.Kind.ABILITY_USES, 900],
	&"knight_twin_lunge": [E, 2, 6, TalentRequirement.Kind.ABILITY_USES, 900],
	&"knight_swift_verdict": [R, 1, 2, TalentRequirement.Kind.ABILITY_USES, 20],
	&"knight_long_arm": [R, 1, 2, TalentRequirement.Kind.ABILITY_USES, 20],
	&"knight_executioner": [R, 2, 6, TalentRequirement.Kind.ABILITY_USES, 180],
	&"knight_shockwave": [R, 2, 6, TalentRequirement.Kind.ABILITY_USES, 180],
	&"knight_bloodrage": [PASSIVE, 1, 2, TalentRequirement.Kind.KILLS, 150],
	&"knight_thick_skin": [PASSIVE, 1, 2, TalentRequirement.Kind.KILLS, 150],
	&"knight_battle_trance": [PASSIVE, 2, 6, TalentRequirement.Kind.KILLS, 1500],
	&"knight_stalwart": [PASSIVE, 2, 6, TalentRequirement.Kind.KILLS, 1500],
}


func _test_knight_set_data() -> void:
	_section("T2–T3: the Knight's 20 talents in the data")
	_check("knight.tres lists all 20 talents", KNIGHT.talents.size(), KNIGHT_T2.size())
	var ids := []
	for t in KNIGHT.talents:
		ids.append(t.id)
	ids.sort()
	var expected_ids := KNIGHT_T2.keys()
	expected_ids.sort()
	_check("their ids", ids, expected_ids)
	for t in KNIGHT.talents:
		var row: Array = KNIGHT_T2.get(t.id, [])
		if row.is_empty():
			continue
		var reqs := t.requirements
		var shape := [t.group, t.tier, t.exclusive, reqs.size(),
			reqs[0].kind if reqs.size() > 0 else -1, reqs[0].amount if reqs.size() > 0 else -1,
			reqs[1].kind if reqs.size() > 1 else -1, reqs[1].amount if reqs.size() > 1 else -1]
		_check("%s: group, tier, exclusive, level %d + %d" % [t.id, row[2], row[4]], shape,
			[row[0], row[1], true, 2, TalentRequirement.Kind.CHAMPION_LEVEL, row[2], row[3], row[4]])
		_check("%s: valid, named, described, file talent_%s.tres" % [t.id, t.id], [Array(t.get_validation_errors(KNIGHT)), t.display_name != "", t.description != "", t.resource_path.get_file()],
			[[], true, true, "talent_%s.tres" % t.id])
	# Every tier is a pick of one of two, and the siblings differ in kind: two
	# number-only siblings never change the same stat (the authoring rule). A
	# sibling with an augment or a passive replacement is a shape change; its
	# numbers may overlap (Whirling and Rending Cleave both retune the reach).
	for t in KNIGHT.talents:
		var siblings := KNIGHT.talents.filter(func(o: Talent) -> bool: return t.is_sibling_of(o))
		_check("%s: one sibling" % t.id, siblings.size(), 1)
		if siblings.size() == 1 and _numbers_only(t) and _numbers_only(siblings[0]):
			var mine := t.get_stats()
			var theirs: Array[StringName] = siblings[0].get_stats()
			_check("%s: no stat in common with its number-only sibling" % t.id, mine.filter(func(s: StringName) -> bool: return theirs.has(s)), [])
	# Every tier 2 changes what the ability does, not only its numbers.
	for t in KNIGHT.talents:
		if t.tier == 2:
			_check("%s (tier 2): a FLAG, an EVENT, a rule, a passive replacement or a trade-off modifier" % t.id, not _numbers_only(t) or _has_trade_off(t), true)


## A talent made only of stat modifiers and scalings (no augment, rule or
## passive replacement).
func _numbers_only(t: Talent) -> bool:
	return t.augments.is_empty() and t.reaction_rules.is_empty() and t.replaces_passive_stats.is_empty()


## A number-only talent with a cost: one of its modifiers lowers something.
func _has_trade_off(t: Talent) -> bool:
	for m in t.modifiers:
		if m != null and m.value < 0.0:
			return true
	return false


func _test_knight_numbers() -> void:
	_section("T2: each number talent does what its row says")
	# [id, slot, param, expected value, or a multiplier of the current value when the last entry is true]
	var cases := [
		[&"knight_thrifty_edge", &"q", &"resource_cost", 15.0, false],
		[&"knight_long_reach", &"q", &"cast_range", 375.0, false],
		[&"knight_quick_recovery", &"w", &"cooldown", 6.5, false],
		[&"knight_long_lunge", &"e", &"cast_range", 1.25, true],
		[&"knight_quick_footing", &"e", &"cooldown", 6.0, false],
		[&"knight_swift_verdict", &"r", &"cooldown", 24.0, false],
		[&"knight_long_arm", &"r", &"cast_range", 1.3, true],
	]
	var k := await _spawn(KNIGHT)
	for c: Array in cases:
		var talent := KNIGHT.get_talent(c[0])
		var ability := k.abilities.get_ability(c[1])
		var before := ability.get_param(k, c[2])
		k.add_talent(talent)
		var after := ability.get_param(k, c[2])
		k.remove_talent(talent)
		var expected: float = before * c[3] if c[4] else c[3]
		_check("%s: %s %s %s -> %s, back after removal" % [c[0], ability.id, c[2], before, expected], [after, ability.get_param(k, c[2])], [expected, before])
	k.add_talent(KNIGHT.get_talent(&"knight_thrifty_edge"))
	_check("Thrifty Edge: the slot costs 15 Fury", k.abilities.get_slot_cost(&"q"), 15.0)
	k.remove_talent(KNIGHT.get_talent(&"knight_thrifty_edge"))
	k.add_talent(KNIGHT.get_talent(&"knight_long_reach"))
	_check("Long Reach reaches an item's Cleave Wave too (700 -> 875)", CLEAVE_WAVE.get_param(k, &"cast_range"), 875.0)
	k.remove_talent(KNIGHT.get_talent(&"knight_long_reach"))
	await _free(k)


func _test_battle_cry() -> void:
	_section("T2: Battle Cry: Iron Resolve restores 15 Fury")
	var k := await _spawn(KNIGHT)
	k.resource_pool.decay_per_second = 0.0
	k.add_talent(KNIGHT.get_talent(&"knight_battle_cry"))
	_check("its line in Iron Resolve's tooltip", IRON_RESOLVE.get_tooltip_plain(k).contains("Restores 15 Fury on cast."), true)
	k.abilities.try_cast(&"w", k.global_position, null)
	await _frames(3)
	_check("cast from 0 Fury: 15", k.resource_pool.current, 15.0)
	k.remove_talent(KNIGHT.get_talent(&"knight_battle_cry"))
	await _wait_until(func() -> bool: return k.abilities.is_ready(&"w"), 600)
	k.abilities.try_cast(&"w", k.global_position, null)
	await _frames(3)
	_check("removed: the next cast restores nothing", k.resource_pool.current, 15.0)
	await _free(k)


func _test_twin_lunge() -> void:
	_section("T2: Twin Lunge: 2 charges, each 35% shorter")
	var k := await _spawn(KNIGHT)
	var base_range := LUNGE.get_param(k, &"cast_range")
	_check("without it: 1 charge (the sandbox's charge demo is off too)", k.abilities.get_max_charges(&"e"), 1)
	k.add_talent(KNIGHT.get_talent(&"knight_twin_lunge"))
	await _frames(1)
	_check("2 charges, range x 0.65", [k.abilities.get_max_charges(&"e"), LUNGE.get_param(k, &"cast_range")], [2, base_range * 0.65])
	k.add_talent(KNIGHT.get_talent(&"knight_long_lunge"))
	_check("with Long Lunge (tier 1 carries): range x 1.25 x 0.65", LUNGE.get_param(k, &"cast_range"), base_range * 1.25 * 0.65)
	k.abilities.try_cast(&"e", k.global_position + Vector2(40, 0), null)
	await _frames(20)
	k.abilities.try_cast(&"e", k.global_position + Vector2(-40, 0), null)
	await _frames(2)
	_check("two Lunges back to back: both charges used", k.abilities.get_charges(&"e"), 0)
	var sandbox: Node = SANDBOX_SCENE.instantiate()
	_check("sandbox.tscn: SandboxAbilities' charge demo is off", sandbox.get_node("SandboxAbilities").get("demo_charges"), false)
	sandbox.free()
	await _free(k)


func _test_executioner() -> void:
	_section("T2: Executioner: 40% missing health, a kill resets, no stun (0.5 s at 60+ Fury)")
	var talent := KNIGHT.get_talent(&"knight_executioner")
	var results := []
	for fury: float in [0.0, 70.0]:
		var k := await _spawn(KNIGHT)
		k.resource_pool.decay_per_second = 0.0
		_no_crits(k)   # a crit would kill the 280-health dummy (no stun on the dead)
		k.add_talent(talent)
		var dummy := _dummy(k.global_position + Vector2(60, 0))
		await _frames(1)
		k.resource_pool.restore(fury)
		var hit := {}
		var on_hit := func(ctx: HitContext) -> void:
			if ctx.source == k and ctx.ability == JUDGEMENT and not ctx.blocked:
				hit["stun"] = dummy.status_component.get_time_left(&"stun")
		Events.unit_hit.connect(on_hit)
		await _wait_until(func() -> bool: return not GameFeel.is_hitstop_active(), 120)
		k.abilities.try_cast(&"r", dummy.global_position, dummy)
		await _wait_until(func() -> bool: return hit.has("stun"), 90)
		Events.unit_hit.disconnect(on_hit)
		results.append([hit.get("stun", -1.0), JUDGEMENT.get_param(k, &"target_missing_health_ratio"), k.abilities.get_augments(&"r").has(AUGMENT_JUDGEMENT_RESET)])
		dummy.queue_free()
		await _free(k)
	_check("the ratio 0.4 and the reset augment on R", [results[0][1], results[0][2]], [0.4, true])
	_check_near("below 60 Fury: no stun", results[0][0], 0.0, 0.001)
	_check_near("at 70 Fury: the bonus's 0.5 s stun", results[1][0], 0.5, 0.05)

	# A kill resets the cooldown (the existing judgement_reset augment).
	var k2 := await _spawn(KNIGHT)
	k2.add_talent(talent)
	var weak := _dummy(k2.global_position + Vector2(60, 0))
	await _frames(1)
	weak.health.take_damage(weak.health.current - 1.0)
	k2.abilities.try_cast(&"r", weak.global_position, weak)
	await _wait_until(func() -> bool: return not weak.is_alive(), 90)
	await _frames(1)
	_check("a Judgement kill: R ready again", [weak.is_alive(), k2.abilities.is_ready(&"r")], [false, true])
	await _free(k2)


func _test_unbroken_talents() -> void:
	_section("T2: Unbroken's talents at 20% health (full value) and full health (none)")
	var k := await _spawn(KNIGHT)
	var base_as := k.stats_component.get_stat(&"attack_speed")
	var base_armor := k.stats_component.get_stat(&"armor")
	var base_ten := k.stats_component.get_stat(&"tenacity")
	# id -> [AD, attack speed, armor, tenacity] at 20% health
	var cases := {
		&"knight_bloodrage": [99.2, base_as, base_armor, base_ten],
		&"knight_thick_skin": [89.6, base_as, base_armor + 30.0, base_ten],
		&"knight_battle_trance": [64.0, base_as * 1.5, base_armor, base_ten],
		&"knight_stalwart": [64.0, base_as, base_armor + 60.0, base_ten + 0.3],
	}
	for id: StringName in cases:
		var talent := KNIGHT.get_talent(id)
		k.add_talent(talent)
		_set_health(k, 0.2)
		await _frames(2)
		var low := [k.stats_component.get_stat(&"attack_damage"), k.stats_component.get_stat(&"attack_speed"), k.stats_component.get_stat(&"armor"), k.stats_component.get_stat(&"tenacity")]
		_set_health(k, 1.0)
		await _frames(2)
		var full := [k.stats_component.get_stat(&"attack_damage"), k.stats_component.get_stat(&"attack_speed"), k.stats_component.get_stat(&"armor"), k.stats_component.get_stat(&"tenacity")]
		k.remove_talent(talent)
		await _frames(1)
		_check_all("%s at 20%%: AD, attack speed, armor, tenacity" % id, low, cases[id])
		_check_all("%s at full health: nothing" % id, full, [64.0, base_as, base_armor, base_ten])
	k.add_talent(KNIGHT.get_talent(&"knight_bloodrage"))
	k.add_talent(KNIGHT.get_talent(&"knight_battle_trance"))
	_set_health(k, 0.2)
	await _frames(2)
	_check_all("Battle Trance + Bloodrage (tier 1 carries): +15% AD, +50% attack speed", [k.stats_component.get_stat(&"attack_damage"), k.stats_component.get_stat(&"attack_speed")], [73.6, base_as * 1.5])
	_set_health(k, 1.0)
	await _free(k)


# --- T3: the six FLAG talents ---------------------------------------------------

func _test_variant_flags() -> void:
	_section("T3: every REPLACE variant supports its base's talent FLAGs")
	var checked := 0
	for file in DirAccess.get_files_at("res://data/abilities"):
		if not file.ends_with(".tres"):
			continue
		var variant := load("res://data/abilities/" + file) as Ability
		if variant == null or variant.variant_of == &"":
			continue
		var wanted: Array[StringName] = []
		for t in KNIGHT.talents:
			var base := t.get_group_ability(KNIGHT)
			if base == null or base.id != variant.variant_of:
				continue
			for aug_res in t.augments:
				var aug := aug_res as AbilityAugment
				if aug != null and aug.kind == AbilityAugment.Kind.FLAG:
					wanted.append(aug.id)
		var missing := wanted.filter(func(f: StringName) -> bool: return not variant.supported_flags.has(f))
		_check("%s (variant of %s) supports %s" % [variant.id, variant.variant_of, wanted], missing, [])
		checked += 1
	_check("at least one variant checked (Cleave Wave)", checked >= 1, true)


func _test_whirling_cleave() -> void:
	_section("T3: Whirling Cleave: all around, 72 px, 85% damage, no knockback")
	var base := await _cleave_run(null, [Vector2(50, 0), Vector2(-50, 0), Vector2(125, 0)])
	var whirl := await _cleave_run(KNIGHT.get_talent(&"knight_whirling_cleave"), [Vector2(50, 0), Vector2(-50, 0), Vector2(125, 0)])
	_check("without it: the one in front (the 96 px cone counts the slime's 17.6 px radius), not behind, not at 125 px", base.hit, [true, false, false])
	_check("with it: in front and behind, not the one at 125 px", whirl.hit, [true, true, false])
	_check("reach 300 -> 225 u (72 px)", whirl.reach, 225.0)
	_check_near("85% of the damage", whirl.damage[0] / base.damage[0] if base.damage[0] > 0.0 else 0.0, 0.85, 0.001)
	_check("no knockback: the front dummy didn't move (the plain Cleave's did)", [whirl.moved[0], base.moved[0]], [false, true])


func _test_rending_cleave() -> void:
	_section("T3: Rending Cleave: 25°, 40% more reach, 35% more damage")
	var points := [Vector2(50, 0), Vector2.from_angle(deg_to_rad(55)) * 70.0, Vector2(140, 0)]
	var base := await _cleave_run(null, points)
	var rend := await _cleave_run(KNIGHT.get_talent(&"knight_rending_cleave"), points)
	_check("without it: in front and 55° off the aim, not at 140 px", base.hit, [true, true, false])
	_check("with it: in front and at 140 px, not 55° off the aim", rend.hit, [true, false, true])
	_check("reach 300 -> 420 u (134 px)", rend.reach, 420.0)
	_check_near("x1.35 damage", rend.damage[0] / base.damage[0] if base.damage[0] > 0.0 else 0.0, 1.35, 0.001)
	var k := await _spawn(KNIGHT)
	k.add_talent(KNIGHT.get_talent(&"knight_rending_cleave"))
	k.add_talent(KNIGHT.get_talent(&"knight_long_reach"))
	_check("with Long Reach (tier 1 carries): 300 x 1.25 x 1.4 = 525 u", CLEAVE.get_param(k, &"cast_range"), 525.0)
	_check("the flag is on Cleave", k.abilities.get_flags(CLEAVE), [&"cleave_rend"])
	await _free(k)


func _test_cleave_wave_flags() -> void:
	_section("T3: with an item's Cleave Wave: Whirling Wave and Rending Wave")
	var k := await _spawn(KNIGHT)
	k.abilities.add_augment(AUGMENT_CLEAVE_WAVE, &"item_test_cleave_wave")
	k.add_talent(KNIGHT.get_talent(&"knight_whirling_cleave"))
	_check("Whirling: the wave has the flag, 8 waves 45° apart, range 525 u", [k.abilities.get_flags(CLEAVE_WAVE), CLEAVE_WAVE.get_param(k, &"projectile_count"), CLEAVE_WAVE.get_param(k, &"projectile_spread_deg"), CLEAVE_WAVE.get_param(k, &"cast_range")],
		[[&"cleave_whirl"], 8.0, 45.0, 525.0])
	_no_crits(k)
	k.resource_pool.decay_per_second = 0.0
	k.resource_pool.restore(100.0)
	var behind := _dummy(k.global_position + Vector2(-100, 0))
	await _frames(1)
	var hits := await _cast_hits(k, &"q", k.global_position + Vector2(100, 0), null, 60)
	_check("a dummy 100 px behind the Knight is hit by a wave", hits.has(behind), true)
	behind.queue_free()
	k.remove_talent(KNIGHT.get_talent(&"knight_whirling_cleave"))
	k.add_talent(KNIGHT.get_talent(&"knight_rending_cleave"))
	_check("Rending: the wave has the flag", k.abilities.get_flags(CLEAVE_WAVE), [&"cleave_rend"])
	_check_all("Rending: one wave, 60 u wide, range 980 u", [CLEAVE_WAVE.get_param(k, &"projectile_count"), CLEAVE_WAVE.get_param(k, &"projectile_width"), CLEAVE_WAVE.get_param(k, &"cast_range")], [1.0, 60.0, 980.0])
	await _free(k)


func _test_challenge_and_bulwark() -> void:
	_section("T3: Challenge (Staggers around, no haste) and Bulwark (a shield, no empower)")
	var empower_id := AutoAttackComponent.get_empower_status_id(&"iron_resolve")
	var k := await _spawn(KNIGHT)
	k.add_talent(KNIGHT.get_talent(&"knight_challenge"))
	var near := _dummy(k.global_position + Vector2(60, 0))
	var far := _dummy(k.global_position + Vector2(150, 0))
	await _frames(1)
	k.abilities.try_cast(&"w", k.global_position, null)
	await _frames(3)
	_check("Challenge: the dummy at 60 px is Staggered, the one at 150 px isn't", [near.status_component.has_tag(&"staggered"), far.status_component.has_tag(&"staggered")], [true, false])
	_check("Challenge: no haste, the empowered swing kept", [k.status_component.has_status(&"iron_resolve"), k.status_component.has_status(empower_id)], [false, true])
	near.queue_free()
	far.queue_free()
	await _free(k)
	var k2 := await _spawn(KNIGHT)
	k2.add_talent(KNIGHT.get_talent(&"knight_bulwark"))
	k2.abilities.try_cast(&"w", k2.global_position, null)
	await _frames(3)
	_check("Bulwark: a 120 shield, the haste kept, no empowered swing", [k2.status_component.get_shield(&"shield"), k2.status_component.has_status(&"iron_resolve"), k2.status_component.has_status(empower_id)], [120.0, true, false])
	await _free(k2)


func _test_tackle() -> void:
	_section("T3: Tackle: stops at the first enemy, hits only it, stuns it 0.75 s")
	var k := await _spawn(KNIGHT)
	k.add_talent(KNIGHT.get_talent(&"knight_tackle"))
	var first := _dummy(k.global_position + Vector2(60, 0))
	var second := _dummy(k.global_position + Vector2(110, 0))
	await _frames(1)
	var start_x := k.global_position.x
	var stun := {}
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.source == k and not ctx.blocked and ctx.target is Unit:
			stun[ctx.target] = (ctx.target as Unit).status_component.get_time_left(&"stun")
	Events.unit_hit.connect(on_hit)
	k.abilities.try_cast(&"e", k.global_position + Vector2(200, 0), null)
	await _frames(30)
	Events.unit_hit.disconnect(on_hit)
	_check("only the first enemy is hit", [stun.has(first), stun.has(second)], [true, false])
	_check_near("its stun: 0.75 s", stun.get(first, 0.0), 0.75, 0.02)
	_check("still Staggered (Lunge's own bonus)", first.status_component.has_tag(&"staggered"), true)
	_check("the Knight stopped short of it (its edge, not past it)", [k.global_position.x < first.global_position.x, k.global_position.x - start_x > 10.0], [true, true])
	first.queue_free()
	second.queue_free()
	await _free(k)
	var k2 := await _spawn(KNIGHT)
	k2.add_talent(KNIGHT.get_talent(&"knight_tackle"))
	var from := k2.global_position
	k2.abilities.try_cast(&"e", from + Vector2(300, 0), null)
	await _frames(30)
	_check_near("nobody in the path: the full Lunge (400 u = 128 px)", k2.global_position.x - from.x, 128.0, 2.0)
	await _free(k2)


func _test_shockwave() -> void:
	_section("T3: Shockwave: 50% damage and a 0.5 s stun around the target, no missing-health damage")
	var results := []
	for fury: float in [0.0, 70.0]:
		var k := await _spawn(KNIGHT)
		_no_crits(k)
		k.resource_pool.decay_per_second = 0.0
		k.add_talent(KNIGHT.get_talent(&"knight_shockwave"))
		var target := _dummy(k.global_position + Vector2(60, 0))
		var splash := _dummy(k.global_position + Vector2(60, 45))
		var far := _dummy(k.global_position + Vector2(60, 130))
		await _frames(1)
		if fury == 0.0:
			target.health.take_damage(target.health.max_health * 0.1)   # 28 missing: a plain Judgement would add 20% of it
		k.resource_pool.restore(fury)
		var seen := {}
		var on_hit := func(ctx: HitContext) -> void:
			if ctx.source == k and ctx.ability == JUDGEMENT and not ctx.blocked and ctx.target is Unit:
				seen[ctx.target] = [ctx.taken_damage, (ctx.target as Unit).status_component.get_time_left(&"stun")]
		Events.unit_hit.connect(on_hit)
		await _wait_until(func() -> bool: return not GameFeel.is_hitstop_active(), 120)
		k.abilities.try_cast(&"r", target.global_position, target)
		await _wait_until(func() -> bool: return seen.has(target), 90)
		await _frames(1)
		Events.unit_hit.disconnect(on_hit)
		results.append([seen.get(target, [0.0, 0.0]), seen.get(splash, [0.0, 0.0]), seen.has(far), k.resource_pool.current])
		for d in [target, splash, far]:
			d.queue_free()
		await _free(k)
	var plain: Array = results[0]
	var fury_run: Array = results[1]
	_check("the target is hit; the dummy 45 px from it too; the one 130 px away isn't", [plain[0][0] > 0.0, plain[1][0] > 0.0, plain[2]], [true, true, false])
	_check_near("the splash: 50% of the target's damage", plain[1][0] / plain[0][0] if plain[0][0] > 0.0 else 0.0, 0.5, 0.001)
	_check_near("no missing-health damage: the target at 90% health takes 150 + 100% AD = 214 (a plain Judgement: 219.6)", plain[0][0], 214.0, 0.5)
	_check_near("the target's stun: 0.75 s", plain[0][1], 0.75, 0.02)
	_check_near("the splash's stun: 0.5 s", plain[1][1], 0.5, 0.02)
	_check_near("at 70 Fury: the target's stun 1.25 s", fury_run[0][1], 1.25, 0.02)
	_check_near("at 70 Fury: the splash's stun 1.0 s (the bonus's +0.5 s too)", fury_run[1][1], 1.0, 0.02)
	_check_near("at 70 Fury: the splash still 50%, both +30%", fury_run[1][0] / fury_run[0][0] if fury_run[0][0] > 0.0 else 0.0, 0.5, 0.001)
	_check("at 70 Fury: the Fury consumed once (0 left)", fury_run[3], 0.0)


func _test_description_overrides() -> void:
	_section("T3b: a talent that reshapes its ability rewrites the ability's tooltip")
	var k := await _spawn(KNIGHT)
	var plain_w := IRON_RESOLVE.get_tooltip_plain(k)
	k.add_talent(KNIGHT.get_talent(&"knight_bulwark"))
	var bulwark_w := IRON_RESOLVE.get_tooltip_plain(k)
	_check("Bulwark: the empowered-swing text is gone, the shield and the haste are there",
		[plain_w.contains("Your next attack"), bulwark_w.contains("next attack"), bulwark_w.contains("120 shield"), bulwark_w.contains("35% movement speed")], [true, false, true, true])
	_check("Bulwark: its augment line isn't repeated under the new text", bulwark_w.contains("instead of the empowered swing"), false)
	k.remove_talent(KNIGHT.get_talent(&"knight_bulwark"))
	_check("removed: Iron Resolve's own text back", IRON_RESOLVE.get_tooltip_plain(k), plain_w)
	k.add_talent(KNIGHT.get_talent(&"knight_shockwave"))
	var r := JUDGEMENT.get_tooltip_plain(k)
	_check("Shockwave: the splash in the text, no '+0% of the target's missing health'", [r.contains("250 units"), r.contains("50% of that"), r.contains("missing health")], [true, true, false])
	k.remove_talent(KNIGHT.get_talent(&"knight_shockwave"))
	_check("without it: Judgement's missing-health term shown", JUDGEMENT.get_tooltip_plain(k).contains("missing health"), true)
	# Every rewritten text resolves all its placeholders.
	for t in KNIGHT.talents:
		if t.ability_description == "":
			continue
		k.add_talent(t)
		var text := k.abilities.get_base_ability(t.get_group_slot()).get_tooltip_plain(k)
		k.remove_talent(t)
		_check("%s: the rewritten tooltip has no unresolved placeholder" % t.id, text.contains("{"), false)
	_check("the seven talents that change what their ability does carry a text", KNIGHT.talents.filter(func(t: Talent) -> bool: return t.ability_description != "").map(func(t: Talent) -> StringName: return t.id),
		[&"knight_whirling_cleave", &"knight_rending_cleave", &"knight_challenge", &"knight_bulwark", &"knight_tackle", &"knight_executioner", &"knight_shockwave"])
	# A REPLACE variant keeps its own text; the talent's line explains the change there.
	k.abilities.add_augment(AUGMENT_CLEAVE_WAVE, &"item_test_cleave_wave")
	k.add_talent(KNIGHT.get_talent(&"knight_whirling_cleave"))
	var wave_text := CLEAVE_WAVE.get_tooltip_plain(k)
	_check("Whirling Cleave with Cleave Wave: the wave's own text, plus the talent's line", [wave_text.begins_with("Send a wave"), wave_text.contains("Hits all around you")], [true, true])
	_check("…and Cleave itself shows the rewritten text", CLEAVE.get_tooltip_plain(k).begins_with("Spin your sword"), true)
	var bad := _talent(&"t_desc_p", PASSIVE, 1)
	bad.ability_description = "x"
	_expect_error("ability_description in PASSIVE", bad, KNIGHT, "ability_description")
	await _free(k)


# --- T4: progress (counters, XP, levels, unlocks, the loadout rules, saving) -----

const LEVELING: ChampionLeveling = preload("res://data/champion_levelings/champion_leveling_default.tres")
const ELITE_SCENE: PackedScene = preload("res://scenes/enemies/slime_elite.tscn")


func _test_leveling_data() -> void:
	_section("T4: the default leveling (TALENTS.md, the curve)")
	_check("XP to next: 600 + 400 x (level - 1), 11 steps; max level 12", [_plain(LEVELING.xp_to_next), LEVELING.get_max_level()],
		[[600, 1000, 1400, 1800, 2200, 2600, 3000, 3400, 3800, 4200, 4600], 12])
	var total := 0
	for x in LEVELING.xp_to_next:
		total += x
	_check("28600 XP to the max level (about 29 runs of 1000)", total, 28600)
	_check("points at levels 1 / 3 / 6 / 9 / 12: 1 / 2 / 3 / 4 / 5", [1, 3, 6, 9, 12].map(func(l: int) -> int: return LEVELING.get_talent_points(l)), [1, 2, 3, 4, 5])
	_check("points never drop between levels", range(1, 13).all(func(l: int) -> bool: return LEVELING.get_talent_points(l + 1) >= LEVELING.get_talent_points(l)), true)
	_check("XP to next at the max level: 0", LEVELING.get_xp_to_next(12), 0)
	_check("the Knight uses the default (no leveling of his own)", [KNIGHT.leveling == null, KNIGHT.get_leveling() == LEVELING], [true, true])


func _test_record_xp_and_unlocks() -> void:
	_section("T4: ChampionProgress: XP, levels and unlocks")
	var p := ChampionProgress.create(KNIGHT)
	_check("a fresh record: level 1, 0 XP, nothing counted, nothing unlocked", [p.level, p.xp, p.kills, p.unlocked.size(), p.loadout.size()], [1, 0, 0, 0, 0])
	_check("599 XP: still level 1", [p.add_xp(599, LEVELING), p.level, p.xp], [0, 1, 599])
	_check("+1: level 2, 0 into it", [p.add_xp(1, LEVELING), p.level, p.xp], [1, 2, 0])
	_check("one big gain: several levels at once (1000 + 1400 + 50 -> level 4, 50 in)", [p.add_xp(2450, LEVELING), p.level, p.xp], [2, 4, 50])
	p.add_xp(100000, LEVELING)
	_check("at the max level XP keeps adding up and grants nothing", [p.level, p.xp > 0, p.add_xp(10, LEVELING)], [12, true, 0])

	var q := ChampionProgress.create(KNIGHT)
	q.level = 2
	for i in 199:
		q.add_ability_use(&"knight_cleave")
	_check("level 2, 199 Cleave casts: nothing unlocks", q.refresh_unlocks(KNIGHT), [])
	q.add_ability_use(&"knight_cleave")
	var fresh := q.refresh_unlocks(KNIGHT)
	fresh.sort()
	_check("the 200th: Long Reach and Thrifty Edge unlock (siblings share requirements)", fresh, [&"knight_long_reach", &"knight_thrifty_edge"])
	_check("…and nothing else", q.unlocked.size(), 2)
	for i in 150:
		q.add_kill([])
	_check("150 kills at level 2: Bloodrage and Thick Skin", q.refresh_unlocks(KNIGHT).size(), 2)
	_check("the requirement's own reading: Cleave casts 200, kills 150, level 2",
		[_req_current(q, &"knight_thrifty_edge", 1), _req_current(q, &"knight_bloodrage", 1), _req_current(q, &"knight_thrifty_edge", 0)], [200, 150, 2])
	# Unlocks are kept: a retune that raises a requirement doesn't relock.
	var retuned: ChampionData = KNIGHT.duplicate()
	var harder: Talent = KNIGHT.get_talent(&"knight_thrifty_edge").duplicate(true)
	harder.requirements[1].amount = 5000
	var pool: Array[Talent] = []
	for t in KNIGHT.talents:
		pool.append(harder if t.id == &"knight_thrifty_edge" else t)
	retuned.talents = pool
	q.refresh_unlocks(retuned)
	_check("a retune to 5000 casts: Thrifty Edge stays unlocked", q.is_unlocked(&"knight_thrifty_edge"), true)
	var fresh_q := ChampionProgress.create(retuned)
	fresh_q.level = 2
	fresh_q.ability_uses = {&"knight_cleave": 200}
	fresh_q.refresh_unlocks(retuned)
	_check("…while a new record needs the 5000", fresh_q.is_unlocked(&"knight_thrifty_edge"), false)
	_check("kills by tag counted (none used by the Knight yet)", [q.get_kills(&"elite"), _with_tagged_kill(q)], [0, 1])


func _test_record_loadout_rules() -> void:
	_section("T4: the loadout rules (points, siblings, the tier rule, respec)")
	var p := ChampionProgress.create(KNIGHT)
	for t in KNIGHT.talents:
		p.unlocked.append(t.id)
	var thrifty := KNIGHT.get_talent(&"knight_thrifty_edge")
	var reach := KNIGHT.get_talent(&"knight_long_reach")
	var whirl := KNIGHT.get_talent(&"knight_whirling_cleave")
	var rend := KNIGHT.get_talent(&"knight_rending_cleave")
	var footing := KNIGHT.get_talent(&"knight_quick_footing")
	_check("level 1: 1 point; Thrifty Edge goes in", [p.get_talent_points(LEVELING), p.add_to_loadout(thrifty, KNIGHT, LEVELING)], [1, true])
	_check("a second talent: no points", p.get_loadout_fail_reason(footing, KNIGHT, LEVELING), "no points")
	_check("its sibling swaps it out, even with no point free", [p.add_to_loadout(reach, KNIGHT, LEVELING), _plain(p.loadout)], [true, [&"knight_long_reach"]])
	p.level = 6
	_check("level 6: 3 points; a tier 2 with its tier 1 in", [p.get_talent_points(LEVELING), p.add_to_loadout(whirl, KNIGHT, LEVELING)], [3, true])
	_check("its tier 2 sibling swaps it", [p.add_to_loadout(rend, KNIGHT, LEVELING), _plain(p.loadout)], [true, [&"knight_long_reach", &"knight_rending_cleave"]])
	_check("a tier 2 without its group's tier 1: needs tier 1", p.get_loadout_fail_reason(KNIGHT.get_talent(&"knight_tackle"), KNIGHT, LEVELING), "needs tier 1")
	p.remove_from_loadout(&"knight_long_reach", KNIGHT)
	_check("taking the tier 1 out takes the tier 2 with it", _plain(p.loadout), [])
	var q := ChampionProgress.create(KNIGHT)
	_check("a locked talent: locked", q.get_loadout_fail_reason(thrifty, KNIGHT, LEVELING), "locked")
	p.add_to_loadout(reach, KNIGHT, LEVELING)
	p.add_to_loadout(footing, KNIGHT, LEVELING)
	p.clear_loadout()
	_check("respec: clear empties it", p.get_points_used(), 0)


func _test_record_sanitize_and_save() -> void:
	_section("T4: a saved loadout the data no longer allows, and the save round trip")
	var p := ChampionProgress.create(KNIGHT)
	p.level = 3   # 2 points
	for t in KNIGHT.talents:
		if t.id != &"knight_stalwart":
			p.unlocked.append(t.id)
	# unknown, locked, kept, a sibling of the kept one, a tier 2 with no tier 1 of
	# its group anywhere, kept, kept (over the 2 points), a sibling of a kept one
	p.loadout = [&"knight_gone", &"knight_stalwart", &"knight_thrifty_edge", &"knight_long_reach", &"knight_tackle", &"knight_swift_verdict", &"knight_bloodrage", &"knight_long_arm"]
	var warnings := p.sanitize_loadout(KNIGHT, LEVELING)
	_check("unknown, locked, two second siblings, the orphan tier 2, then the tail over 2 points dropped",
		_plain(p.loadout), [&"knight_thrifty_edge", &"knight_swift_verdict"])
	_check("one warning per change (6)", warnings.size(), 6)
	var q := ChampionProgress.create(KNIGHT)
	q.level = 6
	for t in KNIGHT.talents:
		q.unlocked.append(t.id)
	q.loadout = [&"knight_tackle", &"knight_long_lunge"]
	_check("a tier 2 listed before its tier 1 is fine (the rule is about the loadout, not the order)", [q.sanitize_loadout(KNIGHT, LEVELING).size(), _plain(q.loadout)], [0, [&"knight_tackle", &"knight_long_lunge"]])

	var r := ChampionProgress.create(KNIGHT)
	r.level = 7
	r.xp = 123
	r.ability_uses = {&"knight_cleave": 42, &"knight_lunge": 7}
	r.kills = 99
	r.kills_by_tag = {&"elite": 3}
	r.unlocked = [&"knight_thrifty_edge", &"knight_long_reach"]
	r.loadout = [&"knight_thrifty_edge"]
	var cfg := ConfigFile.new()
	r.write_to(cfg)
	var path := "user://talents_test_progress.cfg"
	cfg.save(path)
	var cfg2 := ConfigFile.new()
	cfg2.load(path)
	var back := ChampionProgress.read_from(cfg2, KNIGHT)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_check("a save and reload keeps everything", [back.level, back.xp, back.ability_uses, back.kills, back.kills_by_tag, _plain(back.unlocked), _plain(back.loadout)],
		[7, 123, {&"knight_cleave": 42, &"knight_lunge": 7}, 99, {&"elite": 3}, [&"knight_thrifty_edge", &"knight_long_reach"], [&"knight_thrifty_edge"]])
	_check("no section for a champion: null (a fresh record is made)", ChampionProgress.read_from(ConfigFile.new(), KNIGHT) == null, true)


func _test_progress_saving_guard() -> void:
	_section("T4: test scenes never read or write the real save")
	await _frames(1)
	Progress.get_progress(KNIGHT)
	_check("in a scene under res://scenes/tests/: saving is off", [Progress.is_test_scene(), Progress.saving_enabled], [true, false])
	var path := "user://talents_test_guard.cfg"
	var old_path := Progress.save_path
	Progress.save_path = path
	Progress.save()
	_check("save() with saving off writes nothing", FileAccess.file_exists(path), false)
	Progress.saving_enabled = true
	Progress.save()
	var written := FileAccess.file_exists(path)
	Progress.saving_enabled = false
	Progress.save_path = old_path
	if written:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_check("with saving on (a test path) it writes", written, true)
	_check("the real path stays user://progress.cfg", Progress.save_path, "user://progress.cfg")


func _test_counting_live() -> void:
	_section("T4: counting from Events: casts, free casts, variants, kills, XP")
	Progress.reset(KNIGHT)
	var rec := Progress.get_progress(KNIGHT)
	var k := await _spawn(KNIGHT)
	_check("the Player tracks itself", Progress.get_tracked_player() == k, true)
	k.resource_pool.decay_per_second = 0.0
	k.resource_pool.restore(100.0)
	k.abilities.try_cast(&"q", k.global_position + Vector2(50, 0), null)
	await _frames(20)
	_check("a Cleave cast: 1 Cleave use", rec.get_ability_uses(&"knight_cleave"), 1)
	k.abilities.try_cast_free(LUNGE, k.global_position + Vector2(40, 0), null, &"item_test")
	await _frames(20)
	_check("a free Lunge: no Lunge use", rec.get_ability_uses(&"knight_lunge"), 0)
	k.abilities.try_cast(&"r", k.global_position + Vector2(200, 0), null)
	await _frames(2)
	k.abilities.interrupt_cast()
	await _frames(2)
	_check("an interrupted cast: no use", rec.get_ability_uses(&"knight_judgement"), 0)
	k.abilities.add_augment(AUGMENT_CLEAVE_WAVE, &"item_test_cleave_wave")
	await _wait_until(func() -> bool: return k.abilities.is_ready(&"q"), 300)
	k.abilities.try_cast(&"q", k.global_position + Vector2(50, 0), null)
	await _frames(20)
	_check("a Cleave Wave cast counts as Cleave (2)", [rec.get_ability_uses(&"knight_cleave"), rec.get_ability_uses(&"knight_cleave_wave")], [2, 0])
	var kill := DealDamageGameplayEffect.new()
	kill.base_damage = 100000.0
	var slime: Enemy = SLIME_SCENE.instantiate()
	add_child(slime)
	slime.global_position = k.global_position + Vector2(300, 0)
	var elite: Enemy = ELITE_SCENE.instantiate()
	add_child(elite)
	elite.global_position = k.global_position + Vector2(300, 80)
	var dummy := _dummy(k.global_position + Vector2(-300, 0))
	var stray: Enemy = SLIME_SCENE.instantiate()
	add_child(stray)
	stray.global_position = k.global_position + Vector2(-300, 80)
	await _frames(1)
	var xp_before := rec.xp
	kill.apply(slime, k, null)
	_check("a slime kill: 1 kill, 5 XP", [rec.kills, rec.xp - xp_before], [1, 5])
	kill.apply(elite, k, null)
	_check("an elite kill: 2 kills, +40 XP", [rec.kills, rec.xp - xp_before], [2, 45])
	kill.apply(dummy, k, null)
	_check("a training dummy (passive): no kill, no XP", [rec.kills, rec.xp - xp_before], [2, 45])
	kill.apply(stray, null, null)
	_check("a kill with no source: nothing", [rec.kills, rec.xp - xp_before], [2, 45])
	await _free(k)
	_check("the Player left the tree: untracked", Progress.get_tracked_player() == null, true)


func _test_level_and_unlock_lines() -> void:
	_section("T4: level-ups and unlocks: the signals and the HUD lines")
	Progress.reset(KNIGHT)
	var k := await _spawn(KNIGHT)
	var hud: CanvasLayer = HUD_SCENE.instantiate()
	add_child(hud)
	hud.setup_abilities(k)
	var levels := []
	var record_level := func(_id: StringName, level: int) -> void: levels.append(level)
	Progress.champion_leveled_up.connect(record_level)
	Progress.add_xp(KNIGHT, 1600)
	Progress.champion_leveled_up.disconnect(record_level)
	_check("1600 XP from level 1: two signals, levels 2 and 3", levels, [2, 3])
	_check("the HUD line: level 2 (no new point), then level 3 (+1 talent point)", hud.call("get_progress_line"), "Knight reached level 2\nKnight reached level 3: +1 talent point")
	await _wait_until(func() -> bool: return hud.call("get_progress_line") == "", 200)
	_check("the line clears after 2 s", hud.call("get_progress_line"), "")
	var rec := Progress.get_progress(KNIGHT)
	for i in 199:
		rec.add_ability_use(&"knight_cleave")
	var unlocked := []
	var record_unlock := func(_id: StringName, talent_id: StringName) -> void: unlocked.append(talent_id)
	Progress.talent_unlocked.connect(record_unlock)
	k.resource_pool.decay_per_second = 0.0
	k.resource_pool.restore(100.0)
	k.abilities.try_cast(&"q", k.global_position + Vector2(50, 0), null)
	await _frames(20)
	Progress.talent_unlocked.disconnect(record_unlock)
	unlocked.sort()
	_check("the 200th Cleave mid-run unlocks Cleave's tier 1 (signals)", unlocked, [&"knight_long_reach", &"knight_thrifty_edge"])
	_check("…and the HUD says so", hud.call("get_progress_line").contains("Talent unlocked: "), true)
	hud.queue_free()
	await _free(k)


func _test_loadout_from_record() -> void:
	_section("T4: the Player reads its loadout from the record")
	Progress.reset(KNIGHT)
	var rec := Progress.get_progress(KNIGHT)
	rec.unlocked.append(&"knight_thrifty_edge")
	rec.unlocked.append(&"knight_quick_footing")
	_check("Progress.add_to_loadout: within the rules", [Progress.add_to_loadout(KNIGHT, KNIGHT.get_talent(&"knight_thrifty_edge")), Progress.add_to_loadout(KNIGHT, KNIGHT.get_talent(&"knight_quick_footing"))], [true, false])
	var k := await _spawn(KNIGHT)
	_check("player.tscn (no override): the record's loadout attached; Cleave costs 15", [k.get_active_talents().map(func(t: Talent) -> StringName: return t.id), k.abilities.get_slot_cost(&"q")], [[&"knight_thrifty_edge"], 15.0])
	await _free(k)
	var k2 := await _spawn(KNIGHT, [&"knight_long_reach"])
	_check("a Player's own talent_loadout replaces it (tests)", k2.get_active_talents().map(func(t: Talent) -> StringName: return t.id), [&"knight_long_reach"])
	await _free(k2)
	Progress.clear_loadout(KNIGHT)
	var k3 := await _spawn(KNIGHT)
	_check("respec: an empty record loadout, no talents", k3.get_active_talents().size(), 0)
	await _free(k3)


# --- T5: the hub (functional) -----------------------------------------------------

const HUB_SCENE: PackedScene = preload("res://scenes/ui/hub.tscn")
const PAUSE_MENU_SCENE: PackedScene = preload("res://scenes/ui/pause_menu.tscn")


func _test_hub() -> void:
	_section("T5: the hub: header, talent states and lines, clicks, respec, debug tools")
	_check("the main scene (F5) is the hub", ProjectSettings.get_setting("application/run/main_scene"), "res://scenes/ui/hub.tscn")
	var menu: PauseMenu = PAUSE_MENU_SCENE.instantiate()
	_check("the pause menu has Back to hub, going to the hub", [menu.get_node_or_null("%HubButton") != null, menu.hub_scene], [true, "res://scenes/ui/hub.tscn"])
	menu.free()
	Progress.reset(KNIGHT)
	var hub: Hub = HUB_SCENE.instantiate()
	add_child(hub)
	await _frames(1)
	var screen := hub.talent_screen
	_check("Start run and Sandbox go to scenes that exist", [ResourceLoader.exists(hub.run_scene), ResourceLoader.exists(hub.sandbox_scene)], [true, true])
	_check("debug tools on in hub.tscn", hub.find_child("DebugTools", true, false) != null, true)
	_check("header at a fresh start", hub.get_header_text(), "Knight   Level 1: 0 / 600 XP   Talents 0 / 1")
	_check("all 20 talents shown, all locked", KNIGHT.talents.map(func(t: Talent) -> String: return screen.get_state(t.id)).count("locked"), 20)
	_check("a locked talent lists each requirement with its live count",
		screen.get_lines(&"knight_thrifty_edge"), PackedStringArray(["Thrifty Edge  [LOCKED]", "Champion level 1 / 2", "Cleave casts 0 / 200"]))
	_check("clicking a locked talent does nothing", screen.press(&"knight_thrifty_edge"), false)

	hub.debug_add_level()
	_check("+1 level: level 2", hub.get_header_text(), "Knight   Level 2: 0 / 1000 XP   Talents 0 / 1")
	_check("a met requirement is marked", screen.get_lines(&"knight_thrifty_edge")[1], "Champion level 2 / 2 — met")
	Progress.debug_add_ability_uses(KNIGHT, 200)
	hub.refresh()
	_check("+200 uses: Cleave's tier 1 available, its tier 2 still locked", [screen.get_state(&"knight_thrifty_edge"), screen.get_state(&"knight_long_reach"), screen.get_state(&"knight_whirling_cleave")], ["available", "available", "locked"])
	_check("click: in the loadout, the header counts it", [screen.press(&"knight_thrifty_edge"), screen.get_state(&"knight_thrifty_edge"), hub.get_header_text().ends_with("Talents 1 / 1")], [true, "active", true])
	_check("another group's tier 1 with no point left: blocked, and why", screen.get_lines(&"knight_quick_footing"), PackedStringArray(["Quick Footing  [BLOCKED]", "No talent points left"]))
	_check("its sibling still swaps in", [screen.press(&"knight_long_reach"), screen.get_state(&"knight_long_reach"), screen.get_state(&"knight_thrifty_edge")], [true, "active", "available"])
	_check("the record saw it (the run will attach it)", _plain(Progress.get_progress(KNIGHT).loadout), [&"knight_long_reach"])

	Progress.debug_unlock_all(KNIGHT)
	for i in 4:
		hub.debug_add_level()
	_check("unlock all, level 6: 3 points", hub.get_header_text(), "Knight   Level 6: 0 / 2600 XP   Talents 1 / 3")
	_check("a tier 2 with its tier 1 in: available; one without: blocked, and why",
		[screen.get_state(&"knight_whirling_cleave"), screen.get_lines(&"knight_tackle")], ["available", PackedStringArray(["Tackle  [BLOCKED]", "Needs a tier 1 Lunge talent"])])
	screen.press(&"knight_whirling_cleave")
	screen.press(&"knight_long_reach")
	_check("taking the tier 1 out takes its tier 2 too", [screen.get_state(&"knight_long_reach"), screen.get_state(&"knight_whirling_cleave")], ["available", "blocked"])
	screen.press(&"knight_long_lunge")
	screen.press(&"knight_bloodrage")
	hub.clear_loadout()
	_check("Clear talents: nothing active", KNIGHT.talents.filter(func(t: Talent) -> bool: return screen.get_state(t.id) == "active").size(), 0)
	screen.talent_hovered.emit(KNIGHT.get_talent(&"knight_bulwark"))
	_check("hovering a talent shows its description", hub._detail.text, "Bulwark: " + KNIGHT.get_talent(&"knight_bulwark").description)
	Progress.debug_add_kills(KNIGHT, 100)
	_check("+100 kills", Progress.get_progress(KNIGHT).kills, 100)
	for i in 8:
		hub.debug_add_level()
	_check("at the top: Level 12 (max), 5 points", hub.get_header_text(), "Knight   Level 12 (max)   Talents 0 / 5")
	hub.find_child("DebugTools", true, false)
	Progress.reset(KNIGHT)
	hub.refresh()
	_check("Reset: back to a fresh record", hub.get_header_text(), "Knight   Level 1: 0 / 600 XP   Talents 0 / 1")
	hub.queue_free()
	await _frames(1)


func _req_current(p: ChampionProgress, talent_id: StringName, index: int) -> int:
	var t := KNIGHT.get_talent(talent_id)
	return t.requirements[index].get_current(p, t, KNIGHT)


func _with_tagged_kill(p: ChampionProgress) -> int:
	var tags: Array[StringName] = [&"elite"]
	p.add_kill(tags)
	return p.get_kills(&"elite")


## One plain or talented Cleave from a fresh Knight, aimed right, at dummies
## placed at `points` (relative to the Knight). Returns which were hit, the
## damage each took, whether each moved, and Cleave's reach param.
func _cleave_run(talent: Talent, points: Array) -> Dictionary:
	var k := await _spawn(KNIGHT)
	_no_crits(k)
	k.resource_pool.decay_per_second = 0.0
	k.resource_pool.restore(100.0)
	if talent != null:
		k.add_talent(talent)
	var dummies: Array[Enemy] = []
	for p: Vector2 in points:
		dummies.append(_dummy(k.global_position + p))
	await _frames(1)
	var starts := dummies.map(func(d: Enemy) -> Vector2: return d.global_position)
	var hits := await _cast_hits(k, &"q", k.global_position + Vector2(100, 0), null, 30)
	var out := {
		"hit": dummies.map(func(d: Enemy) -> bool: return hits.has(d)),
		"damage": dummies.map(func(d: Enemy) -> float: return hits[d].taken_damage if hits.has(d) else 0.0),
		"moved": [],
		"reach": CLEAVE.get_param(k, &"cast_range"),
	}
	for i in dummies.size():
		out["moved"].append(dummies[i].global_position.distance_to(starts[i]) > 1.0)
		dummies[i].queue_free()
	await _free(k)
	return out


## Casts `slot` and collects every hit from the caster that got through, by unit.
func _cast_hits(k: Player, slot: StringName, aim: Vector2, target: Unit, frames: int) -> Dictionary:
	var hits := {}
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.source == k and not ctx.blocked and ctx.target is Unit:
			hits[ctx.target] = ctx
	Events.unit_hit.connect(on_hit)
	k.abilities.try_cast(slot, aim, target)
	await _frames(frames)
	Events.unit_hit.disconnect(on_hit)
	return hits


## The Knight's own crit chance cancelled (exact damage checks).
func _no_crits(p: Player) -> void:
	var base := p.stats_component.get_base_value(&"crit_chance")
	if base != 0.0:
		p.stats_component.add_modifier(StatModifier.create(&"crit_chance", StatModifier.Type.FLAT, -base, &"test_baseline"))


# --- Helpers ------------------------------------------------------------------

func _talent(talent_id: StringName, group: Talent.Group, tier: int) -> Talent:
	var t := Talent.new()
	t.id = talent_id
	t.group = group
	t.tier = tier
	t.display_name = String(talent_id)
	return t


func _req(kind: TalentRequirement.Kind, amount: int, tag: StringName = &"") -> TalentRequirement:
	var r := TalentRequirement.new()
	r.kind = kind
	r.amount = amount
	r.enemy_tag = tag
	return r


func _unbroken_scaling(stat: StringName, type: StatModifier.Type, value: float) -> StatScaling:
	var s := StatScaling.new()
	s.modifier = StatModifier.create(stat, type, value, &"")
	s.curve = UNBROKEN_CURVE
	return s


## A copy of the Knight's ChampionData with `talents` as its pool.
func _champion(talents: Array[Talent]) -> ChampionData:
	var c: ChampionData = KNIGHT.duplicate()
	c.talents = talents
	return c


func _expect_error(label: String, talent: Talent, champ: ChampionData, fragment: String) -> void:
	var errors := talent.get_validation_errors(champ)
	var found := false
	for e in errors:
		if e.contains(fragment):
			found = true
	_report(found, "caught: %s" % label, "errors %s, wanted one containing '%s'" % [errors, fragment])


## A player.tscn with `champion` (and `loadout`) in the tree, one frame later.
func _spawn(champion: ChampionData, loadout: Array[StringName] = []) -> Player:
	var p: Player = PLAYER_SCENE.instantiate()
	p.champion = champion
	p.talent_loadout = loadout
	add_child(p)
	_place(p)
	await _frames(1)
	return p


## A passive slime (a training dummy) at `pos`.
func _dummy(pos: Vector2) -> Enemy:
	var d: Enemy = SLIME_SCENE.instantiate()
	d.passive = true
	add_child(d)
	d.global_position = pos
	d.reset_physics_interpolation()
	return d


func _wait_until(condition: Callable, max_frames: int) -> void:
	for i in max_frames:
		if condition.call():
			return
		await get_tree().physics_frame


## Element-wise approximate check of two float lists.
func _check_all(label: String, actual: Array, expected: Array) -> void:
	var ok := actual.size() == expected.size()
	for i in mini(actual.size(), expected.size()):
		ok = ok and is_equal_approx(float(actual[i]), float(expected[i]))
	_report(ok, label, "got %s, expected %s" % [actual, expected])


func _free(node: Node) -> void:
	node.queue_free()
	await _frames(1)


func _place(node: Node2D) -> void:
	_next_x += 400.0
	node.global_position = Vector2(_next_x, 0)
	node.reset_physics_interpolation()


## Moves the unit's health to `fraction` of its max (no hit, no i-frames).
func _set_health(p: Player, fraction: float) -> void:
	var target := p.health.max_health * fraction
	if p.health.current > target:
		p.health.take_damage(p.health.current - target)
	elif p.health.current < target:
		p.health.heal(target - p.health.current)


func _all_values(p: Player) -> Dictionary:
	var out := {}
	for key in p.stats_component.registry.get_keys():
		out[key] = p.stats_component.get_stat(key)
	return out


func _rule_sources(p: Player) -> Array:
	return p.get_reaction_rule_entries().map(func(e: Array) -> StringName: return e[1])


## A typed array as a plain one (typed and untyped arrays never compare equal).
func _plain(a: Array) -> Array:
	var out := []
	for x in a:
		out.append(x)
	return out


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _section(title: String) -> void:
	print("-- %s" % title)


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
