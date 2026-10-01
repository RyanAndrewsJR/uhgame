extends Node2D
## TALENTS.md test: open res://scenes/tests/talents_test.tscn and press F6.
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

const Q := Talent.Group.Q
const E := Talent.Group.E
const R := Talent.Group.R
const PASSIVE := Talent.Group.PASSIVE
const CLEAVE_SCOPE := &"ability:knight_cleave"

var _passed: int = 0
var _failed: int = 0
var _next_x: float = 0.0


func _ready() -> void:
	print("\n=== Talents test (TALENTS T1) ===")
	await _test_bundle_refactor()
	_test_talent_data()
	await _test_piece_kinds()
	_test_validation()
	await _test_passive_replace_and_add()
	await _test_loadout_at_load()
	await _test_empty_loadout()
	await _test_sandbox_talents()
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
	_check("the Knight's ChampionData has no talents yet (T2 adds them)", KNIGHT.talents.size(), 0)
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
