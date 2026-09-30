extends Node2D
## CHAMPIONS.md test: open res://scenes/tests/champions_test.tscn and press F6.
## CH1: the Knight's ChampionData (data/champions/knight.tres), loading it
## onto the real player.tscn, a Player with no champion using its scene's own
## exports, the loaded Knight matching the old exports exactly, another
## champion's data replacing every copied field, and resource type NONE
## removing the pool.
## CH2: the passive framework (Passive, StatScaling, Unit.add_stat_scaling())
## and Unbroken: the Knight's AD following his missing health both ways,
## refreshed once after the frame's hits, and every piece removed exactly.
## Prints PASS/FAIL per check, then a total.
## Run headless and it quits with the number of failures as the exit code.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const KNIGHT: ChampionData = preload("res://data/champions/knight.tres")
const KNIGHT_STATS: UnitStats = preload("res://data/units/knight.tres")
const SLIME_STATS: UnitStats = preload("res://data/units/slime.tres")
const CLEAVE: Ability = preload("res://data/abilities/knight_q_cleave.tres")
const IRON_RESOLVE: Ability = preload("res://data/abilities/knight_w_iron_resolve.tres")
const LUNGE: Ability = preload("res://data/abilities/knight_e_lunge.tres")
const JUDGEMENT: Ability = preload("res://data/abilities/knight_r_judgement.tres")
const COMBO_KNIGHT: AttackCombo = preload("res://data/combos/combo_knight.tres")
const HURT_SOUND: SoundEvent = preload("res://data/sounds/sound_knight_hurt.tres")
const LOW_HEALTH_SOUND: SoundEvent = preload("res://data/sounds/sound_knight_low_health.tres")
const BOLT: Ability = preload("res://data/abilities/test_q_bolt.tres")
const NOVA: Ability = preload("res://data/abilities/test_q_nova.tres")
const STRIKE: Ability = preload("res://data/abilities/test_q_strike.tres")
const SLAM: Ability = preload("res://data/abilities/slime_elite_q_slam.tres")
const DASH_SOUND: SoundEvent = preload("res://data/sounds/sound_knight_dash.tres")
const UNBROKEN_CURVE: Curve = preload("res://data/curves/curve_knight_unbroken.tres")
const RULE_EXECUTE: Resource = preload("res://data/reactions/reaction_test_execute.tres")
const AUGMENT_LUNGE_STUNS: Resource = preload("res://data/augments/augment_lunge_stuns.tres")

const MANA := ResourceComponent.ResourceType.MANA
const ENERGY := ResourceComponent.ResourceType.ENERGY
const NONE := ResourceComponent.ResourceType.NONE

var _passed: int = 0
var _failed: int = 0
var _next_x: float = 0.0


func _ready() -> void:
	print("\n=== Champions test (CHAMPIONS CH1–CH2) ===")
	_test_knight_data()
	await _test_knight_loaded()
	await _test_no_champion()
	await _test_other_champion()
	await _test_resource_none()
	await _test_level_not_read()
	_test_unbroken_data()
	await _test_unbroken_follows_health()
	await _test_unbroken_max_health()
	await _test_passive_removed()
	await _test_passive_pieces()
	print("=== %d passed, %d failed ===\n" % [_passed, _failed])

	if DisplayServer.get_name() == "headless":
		get_tree().quit(_failed)


# --- Tests --------------------------------------------------------------------

func _test_knight_data() -> void:
	_section("The Knight's ChampionData (data/champions/knight.tres)")
	_check("identity: knight / Knight / bruiser", [KNIGHT.id, KNIGHT.display_name, KNIGHT.champion_class], [&"knight", "Knight", &"bruiser"])
	_check("stats: data/units/knight.tres", KNIGHT.stats == KNIGHT_STATS, true)
	_check("slots: Cleave, Iron Resolve, Lunge, Judgement", [KNIGHT.q, KNIGHT.w, KNIGHT.e, KNIGHT.r] == [CLEAVE, IRON_RESOLVE, LUNGE, JUDGEMENT], true)
	_check("combo: combo_knight.tres", KNIGHT.combo == COMBO_KNIGHT, true)
	_check("sounds: knight hurt, no death, knight low health", [KNIGHT.hurt_sound == HURT_SOUND, KNIGHT.death_sound == null, KNIGHT.low_health_sound == LOW_HEALTH_SOUND], [true, true, true])
	_check("resource type: MANA until CH3 makes it FURY", KNIGHT.resource_type, MANA)
	_check("champion level 1, 0 XP", [KNIGHT.champion_level, KNIGHT.champion_xp], [1, 0])
	_check("NONE is appended last (the saved MANA/ENERGY/FURY values keep their numbers)", [MANA, ENERGY, ResourceComponent.ResourceType.FURY, NONE], [0, 1, 2, 3])


func _test_knight_loaded() -> void:
	_section("player.tscn loads the Knight from it")
	var knight := await _spawn()
	_check("player.tscn's champion is the Knight's .tres", knight.champion == KNIGHT, true)
	_check_loaded(knight, KNIGHT, "Knight")
	_check("stats from knight.tres: 650 health, 64 AD, 300 max resource", [knight.health.max_health, knight.stats_component.get_stat(&"attack_damage"), knight.resource_pool.max_resource], [650.0, 64.0, 300.0])
	_check("pool starts full, as before", knight.resource_pool.current, 300.0)
	_check("the DashComponent's sound isn't a champion field (unchanged)", knight.dash.dash_sound == DASH_SOUND, true)
	# The same player as before CH1: every copied field equals the scene's
	# own exports, which player.tscn still holds.
	var plain := await _spawn(true)
	_check("with the champion cleared: the scene's own exports", plain.champion == null, true)
	_check("the Knight loaded = the scene's exports (stats)", knight.stats == plain.stats, true)
	_check("the Knight loaded = the scene's exports (slots)", [knight.abilities.q, knight.abilities.w, knight.abilities.e, knight.abilities.r] == [plain.abilities.q, plain.abilities.w, plain.abilities.e, plain.abilities.r], true)
	_check("the Knight loaded = the scene's exports (combo)", knight.attack.combo == plain.attack.combo, true)
	_check("the Knight loaded = the scene's exports (sounds)", [knight.hurt_sound == plain.hurt_sound, knight.death_sound == plain.death_sound, knight.low_health_sound == plain.low_health_sound], [true, true, true])
	_check("the Knight loaded = the scene's exports (resource type)", knight.resource_pool.resource_type, plain.resource_pool.resource_type)
	_check("the Knight loaded = the scene's exports (every live stat)", _all_values(knight), _all_values(plain))
	_check("the Knight loaded = the scene's exports (cooldowns and costs)", _slot_numbers(knight), _slot_numbers(plain))
	knight.queue_free()
	plain.queue_free()
	await _frames(1)


func _test_no_champion() -> void:
	_section("A Player with no champion uses its exports")
	var p: Player = PLAYER_SCENE.instantiate()
	p.champion = null
	p.stats = SLIME_STATS
	(p.get_node("AbilityComponent") as AbilityComponent).q = BOLT   # @onready isn't set before the tree
	add_child(p)
	_place(p)
	await _frames(1)
	_check("its own stats (slime.tres)", [p.stats == SLIME_STATS, p.health.max_health], [true, SLIME_STATS.max_health])
	_check("its own Q (Bolt); W/E/R from the scene", [p.abilities.q == BOLT, p.abilities.w == IRON_RESOLVE, p.abilities.e == LUNGE, p.abilities.r == JUDGEMENT], [true, true, true, true])
	_check("pool kept (MANA)", [p.resource_pool != null, p.resource_pool.resource_type], [true, MANA])
	p.queue_free()
	await _frames(1)


func _test_other_champion() -> void:
	_section("Another champion's data replaces every copied field")
	var other := _make_champion(&"test_other", ENERGY)
	var p := await _spawn(false, other)
	_check_loaded(p, other, "test champion")
	_check("stats from slime.tres", [p.health.max_health, p.stats_component.get_stat(&"attack_damage")], [SLIME_STATS.max_health, SLIME_STATS.attack_damage])
	_check("pool max follows its stats", p.resource_pool.max_resource, SLIME_STATS.max_resource)
	var reason := p.abilities.get_fail_reason(&"q", p.global_position + Vector2(80, 0), null)
	_check("its Q (Bolt) can cast", reason, "")
	await _frames(2)
	p.queue_free()
	await _frames(1)


func _test_resource_none() -> void:
	_section("Resource type NONE removes the pool")
	var costly: Ability = STRIKE.duplicate()
	costly.resource_cost = 50.0
	var none := _make_champion(&"test_none", NONE)
	none.q = costly
	none.stats = KNIGHT_STATS
	var p := await _spawn(false, none)
	_check("no resource_pool", p.resource_pool == null, true)
	_check("no ResourceComponent child", p.get_node_or_null("ResourceComponent") == null, true)
	_check("a slot with a cost is affordable (a unit without a pool pays nothing)", p.abilities.can_afford(&"q"), true)
	_check("health and stats still set up", p.health.max_health, KNIGHT_STATS.max_health)
	var hud: CanvasLayer = HUD_SCENE.instantiate()
	add_child(hud)
	hud.setup_abilities(p)
	_check("HUD: an ability bar and no resource bar", [hud.get_node_or_null("AbilityBar") != null, hud.get_node_or_null("ResourceBar") == null], [true, true])
	hud.queue_free()
	p.queue_free()
	await _frames(1)


func _test_level_not_read() -> void:
	_section("The champion level is plain storage")
	var leveled: ChampionData = KNIGHT.duplicate()
	leveled.champion_level = 7
	leveled.champion_xp = 123
	var p := await _spawn(false, leveled)
	_check("stats level untouched (1)", p.stats_component.get_level(), 1)
	_check("stats identical to a level 1 Knight", p.stats_component.get_stat(&"attack_damage"), 64.0)
	_check("loading doesn't change the fields", [leveled.champion_level, leveled.champion_xp], [7, 123])
	_check("loading doesn't change the Knight's .tres", [KNIGHT.champion_level, KNIGHT.champion_xp, KNIGHT.stats == KNIGHT_STATS], [1, 0, true])
	p.queue_free()
	await _frames(1)


func _test_unbroken_data() -> void:
	_section("CH2: Unbroken in the Knight's .tres")
	var p := KNIGHT.passive
	_check("a passive: Unbroken", [p != null, p.display_name if p else ""], [true, "Unbroken"])
	_check("its source id: passive_knight", KNIGHT.get_passive_source_id(), &"passive_knight")
	var s: StatScaling = p.stat_scalings[0] if p and p.stat_scalings.size() == 1 else null
	_check("one StatScaling: attack_damage PERCENT_ADD +0.40 on self_missing_health", [s != null, s.modifier.stat if s else &"", s.modifier.type if s else -1, s.modifier.value if s else 0.0, s.input if s else &""],
		[true, &"attack_damage", StatModifier.Type.PERCENT_ADD, 0.4, &"self_missing_health"])
	_check("its curve: curve_knight_unbroken.tres", s != null and s.curve == UNBROKEN_CURVE, true)
	_check("AD only: no modifiers, rules, statuses or augments", [p.modifiers.size(), p.reaction_rules.size(), p.statuses.size(), p.augments.size()], [0, 0, 0, 0])
	if s == null:
		return
	var fractions := []
	for x in [0.0, 0.25, 0.5, 0.7, 0.85, 1.0]:
		fractions.append(snappedf(s.get_fraction(x), 0.001))
	_check("curve: 0 / 25 / 50 / 70 / 85 / 100% missing = 0 / 0.357 / 0.714 / 1 / 1 / 1", fractions, [0.0, 0.357, 0.714, 1.0, 1.0, 1.0])
	_check("the tooltip text", p.description, "The lower your health, the harder you hit: up to +40% attack damage at 30% health or less.")


func _test_unbroken_follows_health() -> void:
	_section("CH2: the Knight's AD follows his missing health")
	var k := await _spawn()
	var ad := func() -> float: return k.stats_component.get_stat(&"attack_damage")
	_check("full health: 64 AD", ad.call(), 64.0)
	var mods := k.stats_component.get_modifiers_from(&"passive_knight")
	_check("one passive_knight modifier (value 0 at full health)", [mods.size(), mods[0].value if mods.size() > 0 else -1.0], [1, 0.0])
	var changes: Array = []
	var on_changed := func(key: StringName, old_value: float, new_value: float) -> void:
		if key == &"attack_damage":
			changes.append([snappedf(old_value, 0.01), snappedf(new_value, 0.01)])
	k.stats_component.stat_changed.connect(on_changed)
	_set_health(k, 0.75)
	_check("75% health, the same frame: still 64 (refreshed after the frame's hits)", ad.call(), 64.0)
	await _frames(1)
	_check_near("75% health: about 73 AD", ad.call(), 73.143, 0.01)
	_check("stat_changed once: 64 -> 73.14", changes, [[64.0, 73.14]])
	changes.clear()
	_set_health(k, 0.6)
	_set_health(k, 0.5)
	await _frames(1)
	_check_near("two health changes in one frame, then 50%: about 82 AD", ad.call(), 82.286, 0.01)
	_check("one refresh for both: stat_changed once", changes.size(), 1)
	_set_health(k, 0.3)
	await _frames(1)
	_check_near("30% health: 89.6 AD", ad.call(), 89.6, 0.01)
	changes.clear()
	_set_health(k, 0.1)
	await _frames(1)
	_check_near("10% health: 89.6 AD (flat after 70% missing)", ad.call(), 89.6, 0.01)
	_check("no stat_changed when the value doesn't move", changes.size(), 0)
	_set_health(k, 0.5)
	await _frames(1)
	_check_near("healed to 50%: back to about 82 AD", ad.call(), 82.286, 0.01)
	_set_health(k, 1.0)
	await _frames(1)
	_check("healed to full: 64 AD exactly", ad.call(), 64.0)
	_check("still one passive_knight modifier", k.stats_component.get_modifiers_from(&"passive_knight").size(), 1)
	k.stats_component.stat_changed.disconnect(on_changed)
	k.queue_free()
	await _frames(1)


func _test_unbroken_max_health() -> void:
	_section("CH2: a max health change re-evaluates Unbroken")
	var k := await _spawn()
	_set_health(k, 0.5)   # 325 / 650
	await _frames(1)
	k.stats_component.add_modifier(StatModifier.create(&"max_health", StatModifier.Type.FLAT, 350.0, &"item_test_max_health"))
	await _frames(1)
	# A raised max adds the difference to current: 675 / 1000, 32.5% missing.
	_check("675 / 1000 health", [k.health.current, k.health.max_health], [675.0, 1000.0])
	_check_near("AD follows the new max: 64 x (1 + 0.4 x 0.325 / 0.7)", k.stats_component.get_stat(&"attack_damage"), 64.0 * (1.0 + 0.4 * 0.325 / 0.7), 0.01)
	k.stats_component.remove_modifiers_from(&"item_test_max_health")
	await _frames(1)
	_check("max back to 650 clamps current to full: 64 AD", [k.health.current, k.stats_component.get_stat(&"attack_damage")], [650.0, 64.0])
	k.queue_free()
	await _frames(1)


func _test_passive_removed() -> void:
	_section("CH2: removing the passive restores every stat exactly")
	var plain := await _spawn(true)   # no champion, so no passive
	var k := await _spawn()
	_set_health(plain, 0.3)
	_set_health(k, 0.3)
	await _frames(1)
	_check_near("at 30% health the Knight has 89.6 AD", k.stats_component.get_stat(&"attack_damage"), 89.6, 0.01)
	KNIGHT.passive.remove_from(k, KNIGHT.get_passive_source_id())
	_check("removed: 64 AD at once (not deferred)", k.stats_component.get_stat(&"attack_damage"), 64.0)
	_check("no passive_knight modifiers or scalings left", [k.stats_component.get_modifiers_from(&"passive_knight").size(), k.get_stat_scalings().size()], [0, 0])
	_check("every live stat = a Knight without the passive at the same health", _all_values(k), _all_values(plain))
	_set_health(k, 0.1)
	await _frames(1)
	_check("a later health change doesn't bring it back", k.stats_component.get_stat(&"attack_damage"), 64.0)
	KNIGHT.passive.apply_to(k, KNIGHT.get_passive_source_id())
	_check_near("attached again at 10% health: 89.6 AD at once", k.stats_component.get_stat(&"attack_damage"), 89.6, 0.01)
	plain.queue_free()
	k.queue_free()
	await _frames(1)


func _test_passive_pieces() -> void:
	_section("CH2: a test passive with a modifier, a scaling, a rule, a status and an augment")
	var p := await _spawn(true)
	var state := StatusEffect.new()
	state.id = &"test_passive_state"
	state.duration = -1.0
	state.tags = [&"buff"]
	var passive := Passive.new()
	passive.display_name = "Test"
	passive.modifiers = [StatModifier.create(&"armor", StatModifier.Type.FLAT, 10.0, &"")]
	passive.stat_scalings = [_scaling(&"move_speed", StatModifier.Type.FLAT, 100.0)]
	passive.reaction_rules = [RULE_EXECUTE]
	passive.statuses = [state]
	passive.augments = [AUGMENT_LUNGE_STUNS]
	var before := _all_values(p)
	var source := &"passive_test"
	passive.apply_to(p, source)
	await _frames(1)
	_check("modifier: +10 armor (a copy under passive_test; the original untouched)", [p.stats_component.get_stat(&"armor") - before[&"armor"], p.stats_component.get_modifiers_from(source).size() >= 1, passive.modifiers[0].source_id], [10.0, true, &""])
	_check("scaling: attached (0 move speed at full health)", [p.get_stat_scalings().size(), p.stats_component.get_stat(&"move_speed")], [1, before[&"move_speed"]])
	_check("rule: added under passive_test", _rule_sources(p).has(source), true)
	_check("status: active", p.status_component.has_status(&"test_passive_state"), true)
	_check("augment: Lunge stuns on E", p.abilities.get_augments(&"e").has(AUGMENT_LUNGE_STUNS), true)
	await _frames(30)
	_check("the status is still there half a second later (duration -1)", p.status_component.has_status(&"test_passive_state"), true)
	passive.remove_from(p, source)
	await _frames(1)
	_check("removed: every live stat as before", _all_values(p), before)
	_check("removed: no rule, status, augment or scaling", [_rule_sources(p).has(source), p.status_component.has_status(&"test_passive_state"), p.abilities.get_augments(&"e").has(AUGMENT_LUNGE_STUNS), p.get_stat_scalings().size()], [false, false, false, 0])
	p.queue_free()
	await _frames(1)


# --- Helpers ------------------------------------------------------------------

## Moves the unit's health to `fraction` of its max (HealthComponent directly:
## no hit, no i-frames).
func _set_health(p: Player, fraction: float) -> void:
	var target := p.health.max_health * fraction
	if p.health.current > target:
		p.health.take_damage(p.health.current - target)
	elif p.health.current < target:
		p.health.heal(target - p.health.current)


func _scaling(stat: StringName, type: StatModifier.Type, value: float) -> StatScaling:
	var s := StatScaling.new()
	s.modifier = StatModifier.create(stat, type, value, &"")
	return s


func _rule_sources(p: Player) -> Array:
	return p.get_reaction_rule_entries().map(func(e: Array) -> StringName: return e[1])


func _check_near(label: String, actual: float, expected: float, tolerance: float) -> void:
	_report(absf(actual - expected) <= tolerance, label, "got %s, expected %s ± %s" % [actual, expected, tolerance])


## Checks every field _apply_champion() copies.
func _check_loaded(p: Player, c: ChampionData, label: String) -> void:
	_check("%s: stats" % label, p.stats == c.stats, true)
	_check("%s: Q/W/E/R" % label, [p.abilities.q, p.abilities.w, p.abilities.e, p.abilities.r] == [c.q, c.w, c.e, c.r], true)
	_check("%s: combo" % label, p.attack.combo == c.combo, true)
	_check("%s: sounds" % label, [p.hurt_sound == c.hurt_sound, p.death_sound == c.death_sound, p.low_health_sound == c.low_health_sound], [true, true, true])
	_check("%s: resource type" % label, p.resource_pool.resource_type, c.resource_type)


func _make_champion(champion_id: StringName, type: ResourceComponent.ResourceType) -> ChampionData:
	var c := ChampionData.new()
	c.id = champion_id
	c.display_name = "Test"
	c.champion_class = &"diver"
	c.stats = SLIME_STATS
	c.resource_type = type
	c.q = BOLT
	c.w = NOVA
	c.e = STRIKE
	c.r = SLAM
	c.combo = COMBO_KNIGHT
	c.hurt_sound = LOW_HEALTH_SOUND
	c.death_sound = HURT_SOUND
	c.low_health_sound = null
	return c


## A player.tscn in the tree, one physics frame later. clear = no champion
## (the scene's exports); champion = a replacement set before it enters.
func _spawn(clear: bool = false, champion: ChampionData = null) -> Player:
	var p: Player = PLAYER_SCENE.instantiate()
	if clear:
		p.champion = null
	elif champion != null:
		p.champion = champion
	add_child(p)
	_place(p)
	await _frames(1)
	return p


func _place(node: Node2D) -> void:
	_next_x += 400.0
	node.global_position = Vector2(_next_x, 0)
	node.reset_physics_interpolation()


func _all_values(p: Player) -> Dictionary:
	var out := {}
	for key in p.stats_component.registry.get_keys():
		out[key] = p.stats_component.get_stat(key)
	return out


func _slot_numbers(p: Player) -> Array:
	var out := []
	for slot: StringName in [&"q", &"w", &"e", &"r"]:
		out.append([p.abilities.get_slot_cost(slot), p.abilities.get_ability(slot).cooldown])
	return out


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
		print("  FAIL  %s  (%s)" % [label, detail])
