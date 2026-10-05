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
## CH3: Fury (the Knight's rhythm and +8 per enemy a basic attack hits in the
## data; empty at start, built by swings only, drained 20/s after 3 s out of
## combat; Cleave's 20 cost; the other abilities cast from 0).
## CH4: Staggered (Lunge applies it, its marker, 2 s), Cleave and Cleave Wave
## +50% against it, Judgement's 60 Fury bonus consumed by its hit, its 0.75 s
## channel and 30 s cooldown.
## CH5 / CH5b: Cleave's heal (Ryan 2026-09-30: a share of the missing health, once
## per cast that hits; its ratio shaped by missing health through the curve,
## all read from the data; kills
## count, blocked hits and max health heal nothing, missing health read at the
## effect start), the same on Cleave Wave, no other ability heals; the
## damage-based heal_on_hit_ratio still works on a test copy.
## CH6: the readable kit HUD (the passive slot and its live tooltip line, the
## Fury bar's tick at 60 and glow, R's live-bonus outline; nothing for a
## champion without a passive or thresholds).
## K1 (Korsavil, 2026-10-04): her ChampionData, stats and Energy, the passive's
## second dash, her 3-swing cycle (only the last swing's hits carry the
## `finisher` hit tag, AttackSwing.hit_tags), her empty slots, and the hub's
## champion pick (Progress.picked_champion).
## K2: Q Bladesinger's and her statuses' data; the orbit (a Blade a second,
## 5% damage reduction and speed per Blade only while it lasts, Blades kept
## after it, "No Blades" at 0); the recast (one Blade per Blade held, 80–110%
## AD each, a Demise stack per hit, Umbral Stalker when all 4 hit); Inevitable
## Demise's tiers and its shared 5 s timer.
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
const SLIME_SCENE: PackedScene = preload("res://scenes/enemies/slime.tscn")
const SANDBOX_SCENE: PackedScene = preload("res://scenes/rooms/sandbox.tscn")
const STAGGERED: StatusEffect = preload("res://data/statuses/status_staggered.tres")
const CLEAVE_WAVE: Ability = preload("res://data/abilities/knight_q_cleave_wave.tres")
const CLEAVE_HEAL_CURVE: Curve = preload("res://data/curves/curve_knight_cleave_heal.tres")
const KORSAVIL: ChampionData = preload("res://data/champions/korsavil.tres")
const KORSAVIL_STATS: UnitStats = preload("res://data/units/korsavil.tres")
const COMBO_KORSAVIL: AttackCombo = preload("res://data/combos/combo_korsavil.tres")
const HUB_SCENE: PackedScene = preload("res://scenes/ui/hub.tscn")
const BLADESINGER: Ability = preload("res://data/abilities/korsavil_q_bladesinger.tres")
const STATUS_BLADE: StatusEffect = preload("res://data/statuses/status_blade.tres")
const STATUS_ORBIT: StatusEffect = preload("res://data/statuses/status_bladesinger.tres")
const STATUS_DEMISE: StatusEffect = preload("res://data/statuses/status_inevitable_demise.tres")
const STATUS_STALKER: StatusEffect = preload("res://data/statuses/status_umbral_stalker.tres")

const MANA := ResourceComponent.ResourceType.MANA
const FURY := ResourceComponent.ResourceType.FURY
const ENERGY := ResourceComponent.ResourceType.ENERGY
const NONE := ResourceComponent.ResourceType.NONE

var _passed: int = 0
var _failed: int = 0
var _next_x: float = 0.0


func _ready() -> void:
	print("\n=== Champions test (CHAMPIONS CH1–CH6) ===")
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
	_test_fury_data()
	await _test_fury_loaded()
	await _test_fury_gain_and_decay()
	await _test_fury_costs()
	_test_combo_data()
	await _test_lunge_staggers()
	await _test_cleave_on_staggered()
	await _test_judgement_fury()
	_test_heal_data()
	await _test_cleave_heals()
	await _test_heal_edges()
	await _test_readable_hud()
	_test_korsavil_data()
	await _test_korsavil_loaded()
	await _test_korsavil_swings()
	await _test_korsavil_hub_pick()
	_test_bladesinger_data()
	await _test_bladesinger_orbit()
	await _test_bladesinger_recast()
	await _test_demise()
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
	_check("resource type: FURY (CH3)", KNIGHT.resource_type, FURY)
	_check("champion level 1, 0 XP", [KNIGHT.champion_level, KNIGHT.champion_xp], [1, 0])
	_check("NONE is appended last (the saved MANA/ENERGY/FURY values keep their numbers)", [MANA, ENERGY, ResourceComponent.ResourceType.FURY, NONE], [0, 1, 2, 3])


func _test_knight_loaded() -> void:
	_section("player.tscn loads the Knight from it")
	var knight := await _spawn()
	_check("player.tscn's champion is the Knight's .tres", knight.champion == KNIGHT, true)
	_check_loaded(knight, KNIGHT, "Knight")
	_check("stats from knight.tres: 650 health, 64 AD, 100 max resource", [knight.health.max_health, knight.stats_component.get_stat(&"attack_damage"), knight.resource_pool.max_resource], [650.0, 64.0, 100.0])
	_check("pool starts empty (fury, CH3)", knight.resource_pool.current, 0.0)
	_check("the DashComponent's sound isn't a champion field (unchanged)", knight.dash.dash_sound == DASH_SOUND, true)
	# The same player as before CH1: every copied field equals the scene's
	# own exports, which player.tscn still holds.
	var plain := await _spawn(true)
	_check("with the champion cleared: the scene's own exports", plain.champion == null, true)
	_check("the Knight loaded = the scene's exports (stats)", knight.stats == plain.stats, true)
	_check("the Knight loaded = the scene's exports (slots)", [knight.abilities.q, knight.abilities.w, knight.abilities.e, knight.abilities.r] == [plain.abilities.q, plain.abilities.w, plain.abilities.e, plain.abilities.r], true)
	_check("the Knight loaded = the scene's exports (combo)", knight.attack.combo == plain.attack.combo, true)
	_check("the Knight loaded = the scene's exports (sounds)", [knight.hurt_sound == plain.hurt_sound, knight.death_sound == plain.death_sound, knight.low_health_sound == plain.low_health_sound], [true, true, true])
	_check("resource type from the champion (FURY), not the scene's MANA", [knight.resource_pool.resource_type, plain.resource_pool.resource_type], [FURY, MANA])
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


func _test_fury_data() -> void:
	_section("CH3: Fury in the data")
	_check("the Knight's rhythm: starts empty, decays 20/s after 3 s", [KNIGHT.resource_starts_empty, KNIGHT.resource_decay_per_second, KNIGHT.resource_decay_delay], [true, 20.0, 3.0])
	var mod: StatModifier = KNIGHT.modifiers[0] if KNIGHT.modifiers.size() == 1 else null
	_check("one champion modifier: resource_on_hit FLAT +8 scoped hit:basic_attack", [mod != null, mod.stat if mod else &"", mod.type if mod else -1, mod.value if mod else 0.0, mod.scope if mod else &""],
		[true, &"resource_on_hit", StatModifier.Type.FLAT, 8.0, &"hit:basic_attack"])
	_check("its source id: champion_knight", KNIGHT.get_champion_source_id(), &"champion_knight")
	_check("knight.tres: max 100, no regen", [KNIGHT_STATS.max_resource, KNIGHT_STATS.resource_regen], [100.0, 0.0])
	_check("costs: Cleave 20, Iron Resolve / Lunge / Judgement 0", [CLEAVE.resource_cost, IRON_RESOLVE.resource_cost, LUNGE.resource_cost, JUDGEMENT.resource_cost], [20.0, 0.0, 0.0, 0.0])
	var sandbox: Node = SANDBOX_SCENE.instantiate()
	_check("sandbox.tscn: the cost demo is off", sandbox.get_node("SandboxAbilities").get("demo_costs"), false)
	sandbox.free()


func _test_fury_loaded() -> void:
	_section("CH3: the loaded Knight's Fury")
	var k := await _spawn()
	var pool := k.resource_pool
	_check("empty at start: 0 / 100", [pool.current, pool.max_resource], [0.0, 100.0])
	_check("the rhythm copied onto the pool", [pool.starts_empty, pool.decay_per_second, pool.decay_delay], [true, 20.0, 3.0])
	_check("the +8 is under champion_knight", k.stats_component.get_modifiers_from(&"champion_knight").size(), 1)
	var basic: Array[StringName] = [&"hit:basic_attack"]
	var ability: Array[StringName] = [&"hit:ability"]
	_check("resource_on_hit: 8 for a basic attack hit, 0 otherwise", [k.stats_component.get_scoped_stat(&"resource_on_hit", basic), k.stats_component.get_scoped_stat(&"resource_on_hit", ability), k.stats_component.get_stat(&"resource_on_hit")], [8.0, 0.0, 0.0])
	_check("not in combat yet", [pool.is_in_combat(), pool.get_time_since_combat() == INF], [false, true])
	k.stats_component.add_modifier(StatModifier.create(&"max_resource", StatModifier.Type.FLAT, 50.0, &"item_test_max_fury"))
	_check("a raised max doesn't fill an empty-start pool: 0 / 150", [pool.current, pool.max_resource], [0.0, 150.0])
	k.stats_component.remove_modifiers_from(&"item_test_max_fury")
	k.queue_free()
	await _frames(1)


func _test_fury_gain_and_decay() -> void:
	_section("CH3: swings build Fury, it drains out of combat")
	var k := await _spawn()
	var pool := k.resource_pool
	var dummies: Array[Enemy] = []
	for offset: Vector2 in [Vector2(30, -14), Vector2(36, 0), Vector2(30, 14)]:
		dummies.append(_dummy(k.global_position + offset))
	await _frames(1)
	var landed: Array = []
	var on_landed := func(_i: int, targets: Array[Unit]) -> void: landed.append(targets.size())
	k.attack.swing_landed.connect(on_landed)
	var depleted := [0]
	pool.depleted.connect(func() -> void: depleted[0] += 1)
	k.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return not landed.is_empty(), 60)
	var hit_count: int = landed[0] if not landed.is_empty() else 0
	_check("the swing hit all three dummies", hit_count, 3)
	_check("+8 per enemy hit: 24", pool.current, 8.0 * hit_count)
	_check("in combat right after", pool.is_in_combat(), true)
	var after_swing := pool.current
	await _wait_until(func() -> bool: return pool.get_time_since_combat() >= 2.8, 240)
	_check("no decay for 3 s after the last hit (2.8 s: unchanged)", pool.current, after_swing)
	await _wait_until(func() -> bool: return pool.get_time_since_combat() >= 3.5, 120)
	var drained := 20.0 * (pool.get_time_since_combat() - 3.0)
	_check_near("then 20/s: 24 - 20 x (time out of combat - 3 s)", pool.current, maxf(after_swing - drained, 0.0), 0.4)
	_check("out of combat", pool.is_in_combat(), false)
	await _wait_until(func() -> bool: return pool.is_empty(), 120)
	_check("drained to 0 and stays there", pool.current, 0.0)
	await _frames(5)
	_check("decay isn't spending: depleted never emitted", [pool.current, depleted[0]], [0.0, 0])

	pool.restore(50.0)
	await _frames(3)
	_check("out of combat: 50 starts draining at once", pool.current < 50.0, true)
	var before_hit := pool.current
	k.take_damage(1.0, dummies[0])
	await _frames(10)
	_check("taking a hit puts him back in combat: no decay, and no Fury gained", [pool.is_in_combat(), pool.current], [true, before_hit])
	k.attack.swing_landed.disconnect(on_landed)
	for d in dummies:
		d.queue_free()
	k.queue_free()
	await _frames(1)


func _test_fury_costs() -> void:
	_section("CH3: Cleave costs 20, the rest cast from 0")
	var k := await _spawn()
	var pool := k.resource_pool
	var dummy := _dummy(k.global_position + Vector2(60, 0))
	await _frames(1)
	var aim := dummy.global_position
	_check("0 Fury: Iron Resolve, Lunge and Judgement can cast", [k.abilities.get_fail_reason(&"w", k.global_position, null), k.abilities.get_fail_reason(&"e", aim, null), k.abilities.get_fail_reason(&"r", aim, dummy)], ["", "", ""])
	pool.restore(19.0)
	_check("19 Fury: Cleave fails with 'not enough resource'", [k.abilities.can_afford(&"q"), k.abilities.get_fail_reason(&"q", aim, null)], [false, AbilityComponent.FAIL_NO_RESOURCE])
	pool.restore(1.0)
	_check("20 Fury: Cleave casts and pays 20 at cast start", [k.abilities.try_cast(&"q", aim), pool.current], [true, 0.0])
	await _wait_until(func() -> bool: return not k.abilities.casting, 60)
	_check("Cleave's hits build no Fury", pool.current, 0.0)
	var hits := [0]
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.source == k and ctx.has_tag(&"ability") and not ctx.blocked:
			hits[0] += 1
	Events.unit_hit.connect(on_hit)
	await _wait_until(func() -> bool: return k.abilities.can_cast(&"e"), 30)
	k.abilities.try_cast(&"e", k.global_position + Vector2(120, 0))
	await _wait_until(func() -> bool: return not k.abilities.casting, 60)
	Events.unit_hit.disconnect(on_hit)
	_check("Lunge from 0 hits the dummy and builds no Fury", [hits[0] >= 1, pool.current], [true, 0.0])
	dummy.queue_free()
	k.queue_free()
	await _frames(1)


func _test_combo_data() -> void:
	_section("CH4: Staggered, the combo and Judgement's payoff in the data")
	_check("status_staggered: id, tags staggered + debuff, not cc", [STAGGERED.id, STAGGERED.tags.has(&"staggered"), STAGGERED.tags.has(&"debuff"), STAGGERED.is_cc()], [&"staggered", true, true, false])
	_check("2 s, REFRESH, a marker VFX", [STAGGERED.duration, STAGGERED.stack_rule, STAGGERED.vfx != null], [2.0, StatusEffect.StackRule.REFRESH, true])
	var lunge_bonus: ConditionalBonus = LUNGE.conditional_bonuses[0] if LUNGE.conditional_bonuses.size() == 1 else null
	_check("Lunge: one bonus, no conditions, applies Staggered", [lunge_bonus != null, lunge_bonus.conditions.size() if lunge_bonus else -1, lunge_bonus.target_statuses == [STAGGERED] if lunge_bonus else false], [true, 0, true])
	for ability: Ability in [CLEAVE, CLEAVE_WAVE]:
		var b: ConditionalBonus = ability.conditional_bonuses[0] if ability.conditional_bonuses.size() == 1 else null
		var c: Condition = b.conditions[0] if b and b.conditions.size() == 1 else null
		_check("%s: TARGET_HAS_STATUS staggered -> base_damage and ad_ratio +50%%" % ability.display_name,
			[c != null and c.kind == Condition.Kind.TARGET_HAS_STATUS and c.status_tag == &"staggered", _bonus_mods(b)],
			[true, [[&"base_damage", StatModifier.Type.PERCENT_ADD, 0.5], [&"ad_ratio", StatModifier.Type.PERCENT_ADD, 0.5]]])
	var jb: ConditionalBonus = JUDGEMENT.conditional_bonuses[0] if JUDGEMENT.conditional_bonuses.size() == 1 else null
	var jc: Condition = jb.conditions[0] if jb and jb.conditions.size() == 1 else null
	_check("Judgement: RESOURCE_AT_LEAST 60 -> stun +0.5 s, base_damage and ad_ratio +30%",
		[jc != null and jc.kind == Condition.Kind.RESOURCE_AT_LEAST and is_equal_approx(jc.value, 60.0), _bonus_mods(jb)],
		[true, [[&"stun_duration", StatModifier.Type.FLAT, 0.5], [&"base_damage", StatModifier.Type.PERCENT_ADD, 0.3], [&"ad_ratio", StatModifier.Type.PERCENT_ADD, 0.3]]])
	_check("Judgement: 0.75 s channel, 30 s cooldown, 0.75 s stun, consumes Fury", [JUDGEMENT.cast_time, JUDGEMENT.cooldown, JUDGEMENT.get("stun_duration"), JUDGEMENT.get("consume_resource_on_bonus")], [0.75, 30.0, 0.75, true])


func _test_lunge_staggers() -> void:
	_section("CH4: Lunge staggers every enemy it cuts through")
	var k := await _spawn()
	var on_path := [_dummy(k.global_position + Vector2(60, 0)), _dummy(k.global_position + Vector2(100, 4))]
	var off_path := _dummy(k.global_position + Vector2(60, 90))
	await _frames(1)
	k.abilities.try_cast(&"e", k.global_position + Vector2(125, 0))
	await _wait_until(func() -> bool: return not k.abilities.casting, 60)
	var staggered := on_path.map(func(d: Enemy) -> bool: return d.status_component.has_status(&"staggered"))
	_check("both enemies on the path are Staggered", staggered, [true, true])
	_check("the one off the path isn't", off_path.status_component.has_status(&"staggered"), false)
	_check_near("for 2 s", on_path[0].status_component.get_time_left(&"staggered"), 2.0, 0.1)
	_check("it shows the marker", _has_child_with_script(on_path[0], "staggered_mark.gd"), true)
	_check("from the Knight", on_path[0].status_component.get_source(&"staggered") == k, true)
	await _wait_until(func() -> bool: return not on_path[0].status_component.has_status(&"staggered"), 150)
	_check("it runs out, and the marker goes with it", [on_path[0].status_component.has_status(&"staggered"), _has_child_with_script(on_path[0], "staggered_mark.gd")], [false, false])
	for d: Enemy in on_path + [off_path]:
		d.queue_free()
	k.queue_free()
	await _frames(1)


func _test_cleave_on_staggered() -> void:
	_section("CH4: Cleave hits Staggered enemies 50% harder")
	var k := await _spawn()
	_no_crits(k)
	var plain := _dummy(k.global_position + Vector2(40, -14))
	var marked := _dummy(k.global_position + Vector2(40, 14))
	await _frames(1)
	marked.status_component.apply_status(STAGGERED, k)
	var damage := {}
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.source == k and ctx.ability == CLEAVE and not ctx.blocked:
			damage[ctx.target] = ctx.taken_damage
	Events.unit_hit.connect(on_hit)
	k.resource_pool.restore(20.0)
	k.abilities.try_cast(&"q", k.global_position + Vector2(40, 0))
	await _wait_until(func() -> bool: return damage.size() >= 2, 60)
	Events.unit_hit.disconnect(on_hit)
	var ratio: float = damage.get(marked, 0.0) / damage.get(plain, 1.0) if damage.has(plain) else 0.0
	_check("both hit", damage.size(), 2)
	_check_near("the Staggered one takes x1.5 (80 + 70% AD, both +50%)", ratio, 1.5, 0.001)
	_check("Cleave doesn't consume Staggered", marked.status_component.has_status(&"staggered"), true)
	_check("the tooltips list the bonus lines", [CLEAVE.get_tooltip_plain(k).contains("+50% damage to Staggered enemies."), LUNGE.get_tooltip_plain(k).contains("Staggers enemies hit for 2s."), JUDGEMENT.get_tooltip_plain(k).contains("At 60+ Fury: +30% damage and +0.5s stun, and it consumes your Fury.")], [true, true, true])
	plain.queue_free()
	marked.queue_free()
	k.queue_free()
	await _frames(1)


func _test_judgement_fury() -> void:
	_section("CH4: Judgement at 60+ Fury hits harder, stuns longer and consumes the Fury")
	var results := []
	for fury: float in [59.0, 70.0]:
		var k := await _spawn()
		_no_crits(k)
		k.resource_pool.decay_per_second = 0.0   # hold the Fury through the channel (decay is checked below)
		var dummy := _dummy(k.global_position + Vector2(60, 0))
		await _frames(1)
		k.resource_pool.restore(fury)
		var hit := {}
		var on_hit := func(ctx: HitContext) -> void:
			if ctx.source == k and ctx.ability == JUDGEMENT and not ctx.blocked:
				hit["damage"] = ctx.taken_damage
				hit["stun"] = dummy.status_component.get_time_left(&"stun")
		Events.unit_hit.connect(on_hit)
		await _wait_until(func() -> bool: return not GameFeel.is_hitstop_active(), 120)   # real-time hitstop slows game time
		var started := Engine.get_physics_frames()
		k.abilities.try_cast(&"r", dummy.global_position, dummy)
		await _wait_until(func() -> bool: return hit.has("damage"), 90)
		var frames := Engine.get_physics_frames() - started
		Events.unit_hit.disconnect(on_hit)
		results.append([hit.get("damage", 0.0), hit.get("stun", 0.0), k.resource_pool.current, frames, k.abilities.get_cooldown_left(&"r")])
		dummy.queue_free()
		k.queue_free()
		await _frames(1)
	var low: Array = results[0]
	var high: Array = results[1]
	_check_near("59 Fury: the plain 0.75 s stun", low[1], 0.75, 0.05)
	_check("59 Fury: nothing consumed", low[2], 59.0)
	_check_near("70 Fury: a 1.25 s stun", high[1], 1.25, 0.05)
	_check_near("70 Fury: x1.3 damage (150 + 100% AD, both +30%; the dummy at full health)", high[0] / low[0] if low[0] > 0.0 else 0.0, 1.3, 0.001)
	_check("70 Fury: all of it consumed by the hit", high[2], 0.0)
	_check("the 0.75 s channel (45 ticks): the hit 44 or 45 frames after the press (which one: where in the frame it lands, the AB14 checks)", low[3] == 44 or low[3] == 45, true)
	_check_near("the 30 s cooldown started", high[4], 30.0, 1.0)

	# Out of combat the Fury decays during the channel: 60 at the press is below 60 at the hit.
	var k2 := await _spawn()
	_no_crits(k2)
	var d2 := _dummy(k2.global_position + Vector2(60, 0))
	await _frames(1)
	k2.resource_pool.restore(60.0)
	var stun := [0.0]
	var on_hit2 := func(ctx: HitContext) -> void:
		if ctx.source == k2 and ctx.ability == JUDGEMENT and not ctx.blocked:
			stun[0] = d2.status_component.get_time_left(&"stun")
	Events.unit_hit.connect(on_hit2)
	k2.abilities.try_cast(&"r", d2.global_position, d2)
	await _wait_until(func() -> bool: return stun[0] > 0.0, 90)
	Events.unit_hit.disconnect(on_hit2)
	_check_near("60 at the press, decayed below 60 by the hit: no bonus (checked at the effect)", stun[0], 0.75, 0.05)
	_check("and nothing consumed beyond the decay", k2.resource_pool.current > 40.0, true)
	d2.queue_free()
	k2.queue_free()
	await _frames(1)


func _test_heal_data() -> void:
	_section("CH5b: Cleave's heal from missing health in the data (read from the data, so tuning never breaks it)")
	var ratio := CLEAVE.heal_missing_health_ratio
	for ability: Ability in [CLEAVE, CLEAVE_WAVE]:
		var s: ChargeScaling = null
		for cs in ability.charge_scalings:
			if cs != null and cs.param == &"heal_missing_health_ratio":
				s = cs
		_check("%s: a share of missing health (Cleave's %.2f; no damage-based heal), scaled by self_missing_health (min 0) through curve_knight_cleave_heal" % [ability.display_name, ratio],
			[ratio > 0.0, is_equal_approx(ability.heal_missing_health_ratio, ratio), ability.heal_on_hit_ratio, s != null, s.input if s else &"", s.min_fraction if s else -1.0, s != null and s.curve == CLEAVE_HEAL_CURVE],
			[true, true, 0.0, true, &"self_missing_health", 0.0, true])
	_check("no other Knight ability heals; both heal fields default to 0",
		[IRON_RESOLVE.heal_missing_health_ratio, LUNGE.heal_missing_health_ratio, JUDGEMENT.heal_missing_health_ratio, IRON_RESOLVE.heal_on_hit_ratio, LUNGE.heal_on_hit_ratio, JUDGEMENT.heal_on_hit_ratio, Ability.new().heal_missing_health_ratio, Ability.new().heal_on_hit_ratio],
		[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	# The curve's shape, whatever its numbers: nothing at full health, never
	# more than the full ratio, never less as more health is missing.
	var in_range := true
	var rising := true
	var last := 0.0
	for i in 21:
		var y := CLEAVE_HEAL_CURVE.sample(i / 20.0)
		in_range = in_range and y >= -0.001 and y <= 1.001
		rising = rising and y >= last - 0.001
		last = y
	_check("the curve: 0 at full health, within 0-1, never lower as more health is missing",
		[absf(CLEAVE_HEAL_CURVE.sample(0.0)) < 0.001, in_range, rising], [true, true, true])
	_check("the tooltip says up to %d%% of your missing health" % roundi(ratio * 100.0),
		CLEAVE.get_tooltip_plain(null).contains("Each cast that hits heals you for up to %d%% of your missing health" % roundi(ratio * 100.0)), true)


func _test_cleave_heals() -> void:
	_section("CH5b: a Cleave that hits heals a share of the missing health, once")
	for health_share: float in [1.0, 0.5, 0.25, 0.1]:
		var r := await _cleave_heal_run(health_share, 1)
		var missing := 650.0 * (1.0 - health_share)
		var expected := _expected_heal(health_share)
		_check_near("%d%% health (%d missing): heals %.1f" % [roundi(health_share * 100.0), roundi(missing), expected], r.healed, expected, 0.05)
	var one := await _cleave_heal_run(0.1, 1)
	var three := await _cleave_heal_run(0.1, 3)
	_check("10% health into three slimes: three hits, one heal", [three.ratios.size(), three.heals], [3, 1])
	_check_near("the same amount as into one slime", three.healed, one.healed, 0.05)
	_check_near("which is the data's heal at 10%% health (%.2f)" % _expected_heal(0.1), one.healed, _expected_heal(0.1), 0.05)
	var air := await _cleave_heal_run(0.1, 0)
	_check("a Cleave that hits nothing heals nothing", air.healed, 0.0)


func _test_heal_edges() -> void:
	_section("CH5b: killing blows, blocked hits, max health, missing health read at the effect")
	# A killing blow is a hit: it heals.
	var k := await _spawn()
	_no_crits(k)
	var victim := _dummy(k.global_position + Vector2(40, 0))
	await _frames(1)
	victim.health.take_damage(victim.health.max_health - 10.0)
	_set_health(k, 0.1)
	await _frames(1)
	var before := k.health.current
	k.resource_pool.restore(20.0)
	k.abilities.try_cast(&"q", victim.global_position)
	await _wait_until(func() -> bool: return not victim.is_alive(), 60)
	await _frames(1)
	_check_near("a killing blow heals: the data's heal at 10%% health (%.2f)" % _expected_heal(0.1), k.health.current - before, _expected_heal(0.1), 0.05)
	k.queue_free()
	await _frames(1)

	# A blocked hit (an invulnerable enemy) heals nothing.
	var kb := await _spawn()
	var shielded := _dummy(kb.global_position + Vector2(40, 0))
	await _frames(1)
	shielded.add_invulnerability(&"test")
	_set_health(kb, 0.1)
	await _frames(1)
	var before_b := kb.health.current
	kb.resource_pool.restore(20.0)
	kb.abilities.try_cast(&"q", shielded.global_position)
	await _wait_until(func() -> bool: return not kb.abilities.casting, 60)
	await _frames(1)
	_check("a blocked hit heals nothing", kb.health.current, before_b)
	shielded.queue_free()
	kb.queue_free()
	await _frames(1)

	# At max health nothing is healed (a flat 100% test ratio, so the curve isn't what stops it).
	var k2 := await _spawn()
	var flat: Ability = CLEAVE.duplicate()
	flat.charge_scalings = []
	flat.heal_missing_health_ratio = 1.0
	flat.resource_cost = 0.0
	k2.abilities.q = flat
	var d2 := _dummy(k2.global_position + Vector2(40, 0))
	await _frames(1)
	k2.abilities.try_cast(&"q", d2.global_position)
	await _wait_until(func() -> bool: return not k2.abilities.casting, 60)
	_check("at max health with a 100% ratio: still exactly max health", k2.health.current, k2.health.max_health)
	d2.queue_free()
	k2.queue_free()
	await _frames(1)

	# Missing health is read when the effect starts: a hit taken during the 0.2 s cast time counts.
	var k3 := await _spawn()
	_no_crits(k3)
	var d3 := _dummy(k3.global_position + Vector2(40, 0))
	await _frames(1)
	var ratio := [-1.0]
	var on_hit3 := func(c: HitContext) -> void:
		if c.source == k3 and c.ability == CLEAVE and not c.blocked:
			ratio[0] = c.heal_missing_health_ratio
	Events.unit_hit.connect(on_hit3)
	k3.resource_pool.restore(20.0)
	k3.abilities.try_cast(&"q", d3.global_position)
	await _frames(3)
	_set_health(k3, 0.1)   # at full health when pressed, 10% by the effect
	var before3 := k3.health.current
	await _wait_until(func() -> bool: return ratio[0] >= 0.0, 60)
	await _frames(1)
	Events.unit_hit.disconnect(on_hit3)
	_check_near("pressed at full health, hit to 10%% in the cast time: the 10%% ratio (%.3f)" % _heal_share(0.1), ratio[0], _heal_share(0.1), 0.0005)
	_check_near("and it heals the data's heal at 10% health", k3.health.current - before3, _expected_heal(0.1), 0.05)
	d3.queue_free()
	k3.queue_free()
	await _frames(1)

	# The damage-based heal (CH5's general heal_on_hit_ratio) still works for any ability.
	var k4 := await _spawn()
	_no_crits(k4)
	var by_damage: Ability = CLEAVE.duplicate()
	by_damage.charge_scalings = []
	by_damage.heal_missing_health_ratio = 0.0
	by_damage.heal_on_hit_ratio = 0.5
	by_damage.resource_cost = 0.0
	k4.abilities.q = by_damage
	var pair := [_dummy(k4.global_position + Vector2(40, -14)), _dummy(k4.global_position + Vector2(40, 14))]
	await _frames(1)
	_set_health(k4, 0.5)
	await _frames(1)
	var taken := [0.0]
	var on_hit4 := func(c: HitContext) -> void:
		if c.source == k4 and c.ability == by_damage and not c.blocked:
			taken[0] += c.taken_damage
	Events.unit_hit.connect(on_hit4)
	var before4 := k4.health.current
	k4.abilities.try_cast(&"q", k4.global_position + Vector2(40, 0))
	await _wait_until(func() -> bool: return not k4.abilities.casting, 60)
	await _frames(1)
	Events.unit_hit.disconnect(on_hit4)
	_check_near("heal_on_hit_ratio 0.5 on a test copy: half the damage taken by both enemies", k4.health.current - before4, 0.5 * taken[0], 0.05)
	for d in pair:
		d.queue_free()
	k4.queue_free()
	await _frames(1)


## Cleave's heal share of missing health at `health_share` of max health, from
## the data (its ratio x the curve at the missing share).
func _heal_share(health_share: float) -> float:
	return CLEAVE.heal_missing_health_ratio * clampf(CLEAVE_HEAL_CURVE.sample(1.0 - health_share), 0.0, 1.0)


## What one Cleave that hits heals the Knight at `health_share` of max health.
func _expected_heal(health_share: float) -> float:
	return _heal_share(health_share) * KNIGHT_STATS.max_health * (1.0 - health_share)


## One Cleave by a fresh Knight at `health_share` of max health into `count`
## dummies (0 = into the air): the hits' missing-health ratios, how many
## times the Knight was healed, and how much.
func _cleave_heal_run(health_share: float, count: int) -> Dictionary:
	var k := await _spawn()
	_no_crits(k)
	var dummies: Array[Enemy] = []
	for i in count:
		dummies.append(_dummy(k.global_position + Vector2(40, -16 + 16 * i)))
	await _frames(1)
	_set_health(k, health_share)
	await _frames(1)   # Unbroken settles for this health
	var ratios: Array[float] = []
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.source == k and ctx.ability == CLEAVE and not ctx.blocked:
			ratios.append(ctx.heal_missing_health_ratio)
	Events.unit_hit.connect(on_hit)
	var heals := [0]
	var last := [k.health.current]
	var on_health := func(current: float, _m: float) -> void:
		if current > last[0] + 0.001:
			heals[0] += 1
		last[0] = current
	k.health.health_changed.connect(on_health)
	var before := k.health.current
	k.resource_pool.restore(20.0)
	k.abilities.try_cast(&"q", k.global_position + Vector2(40, 0))
	await _wait_until(func() -> bool: return not k.abilities.casting, 60)
	await _frames(1)
	Events.unit_hit.disconnect(on_hit)
	var result := {"ratios": ratios, "heals": heals[0], "healed": k.health.current - before}
	for d in dummies:
		d.queue_free()
	k.queue_free()
	await _frames(1)
	return result


func _test_readable_hud() -> void:
	_section("CH6: the readable kit HUD (passive slot, Fury tick, live bonus)")
	var k := await _spawn()
	var hud: CanvasLayer = HUD_SCENE.instantiate()
	add_child(hud)
	hud.setup_abilities(k)
	await _frames(2)
	var slot: Control = hud.get_node_or_null("PassiveSlot")
	var bar: Control = hud.get_node_or_null("AbilityBar")
	var res: Control = hud.get_node_or_null("ResourceBar")
	_check("a passive slot for the Knight", slot != null, true)
	if slot == null or bar == null or res == null:
		hud.queue_free()
		k.queue_free()
		return
	var slot_rect := slot.get_global_rect()
	var bar_rect := bar.get_global_rect()
	_check("left of Q, one gap away, the same size and row", [is_equal_approx(slot_rect.end.x + 4.0, bar_rect.position.x), is_equal_approx(slot_rect.position.y, bar_rect.position.y), slot_rect.size], [true, true, Vector2(30, 30)])
	_check("Unbroken's color", KNIGHT.passive.icon_color, Color(0.95, 0.5, 0.35, 1))
	var lines: PackedStringArray = slot.call("get_tooltip_lines")
	_check("tooltip: the name, the description, the live bonus at full health", lines,
		PackedStringArray(["Unbroken", KNIGHT.passive.description, "Now: +0% attack damage"]))
	_set_health(k, 0.5)
	await _frames(1)
	_check("at 50% health: Now: +29% attack damage", slot.call("get_tooltip_lines")[2], "Now: +29% attack damage")
	_set_health(k, 0.2)
	await _frames(1)
	_check("at 20% health: Now: +40% attack damage", slot.call("get_tooltip_lines")[2], "Now: +40% attack damage")
	_set_health(k, 1.0)

	var pool := k.resource_pool
	_check("the Fury bar's thresholds: 60 (Judgement's bonus)", _plain(res.call("get_thresholds")), [60.0])
	_check("0 Fury: no glow, no live bonus on R", [res.call("is_glowing"), bar.call("has_live_bonus", &"r")], [false, false])
	pool.restore(60.0)
	_check("60 Fury: the bar glows and R has the gold outline", [res.call("is_glowing"), bar.call("has_live_bonus", &"r")], [true, true])
	_check("Q (a target condition) and E (no conditions) never show a live bonus", [bar.call("has_live_bonus", &"q"), bar.call("has_live_bonus", &"e"), bar.call("has_live_bonus", &"w")], [false, false, false])
	pool.try_spend(1.0)
	_check("59 Fury: both off again", [res.call("is_glowing"), bar.call("has_live_bonus", &"r")], [false, false])
	hud.queue_free()
	k.queue_free()
	await _frames(1)

	# A champion without a passive or thresholds: the HUD as before.
	var other := _make_champion(&"test_plain", ENERGY)
	var p := await _spawn(false, other)
	var hud2: CanvasLayer = HUD_SCENE.instantiate()
	add_child(hud2)
	hud2.setup_abilities(p)
	await _frames(1)
	var res2: Control = hud2.get_node_or_null("ResourceBar")
	var bar2: Control = hud2.get_node_or_null("AbilityBar")
	p.resource_pool.restore(1000.0)
	_check("no passive: no passive slot", hud2.get_node_or_null("PassiveSlot") == null, true)
	_check("no RESOURCE_AT_LEAST anywhere: no ticks, no glow even when full", [_plain(res2.call("get_thresholds")), res2.call("is_glowing")], [[], false])
	_check("no live bonus on any slot", [&"q", &"w", &"e", &"r"].map(func(s: StringName) -> bool: return bar2.call("has_live_bonus", s)), [false, false, false, false])
	hud2.queue_free()
	p.queue_free()
	await _frames(1)


## A typed array as a plain one (typed and untyped arrays never compare equal).
func _plain(a: Array) -> Array:
	var out := []
	for x in a:
		out.append(x)
	return out


func _test_korsavil_data() -> void:
	_section("K1: Korsavil's ChampionData (data/champions/korsavil.tres)")
	_check("identity: korsavil / Korsavil / assassin", [KORSAVIL.id, KORSAVIL.display_name, KORSAVIL.champion_class], [&"korsavil", "Korsavil", &"assassin"])
	var s := KORSAVIL.stats
	_check("stats: data/units/korsavil.tres", s == KORSAVIL_STATS, true)
	_check("the placeholders (Ryan, 2026-10-04): 500 health, 60 AD, 0.7 attack speed, 390 move speed, 150 range, 0.25 crit",
		[s.max_health, s.attack_damage, s.base_attack_speed, s.move_speed, s.attack_range, s.crit_chance],
		[500.0, 60.0, 0.7, 390.0, 150.0, 0.25])
	_check("armor and magic resist 0; dash_charges 1 on the stats (the second is the passive's); the Knight's pickup radius",
		[s.armor, s.magic_resist, s.dash_charges, s.pickup_radius], [0.0, 0.0, 1, KNIGHT_STATS.pickup_radius])
	_check("Energy: 100 max, 10 a second", [s.max_resource, s.resource_regen], [100.0, 10.0])
	_check("ENERGY, starts full, no decay", [KORSAVIL.resource_type, KORSAVIL.resource_starts_empty, KORSAVIL.resource_decay_per_second, KORSAVIL.resource_decay_delay],
		[ENERGY, false, 0.0, 0.0])
	_check("Q is Bladesinger (K2); W, E and R empty until K3–K5", [KORSAVIL.q == BLADESINGER, KORSAVIL.w, KORSAVIL.e, KORSAVIL.r], [true, null, null, null])
	_check("no own modifiers, talents or named items; the shared leveling; no model (a capsule)",
		[KORSAVIL.modifiers.size(), KORSAVIL.talents.size(), KORSAVIL.named_items.size(), KORSAVIL.leveling == null, KORSAVIL.model_scene == null],
		[0, 0, 0, true, true])
	var p := KORSAVIL.passive
	var mods: Array = []
	if p != null:
		for m in p.modifiers:
			mods.append([m.stat, m.type, m.value, m.scope])
	_check("the passive: one FLAT +1 dash_charges, nothing else yet", [mods, p.stat_scalings.size(), p.reaction_rules.size(), p.statuses.size(), p.augments.size()],
		[[[&"dash_charges", StatModifier.Type.FLAT, 1.0, &""]], 0, 0, 0, 0])
	_check("combo: combo_korsavil.tres, MELEE, 3 swings, reset 0.6 s, no speed scale",
		[KORSAVIL.combo == COMBO_KORSAVIL, COMBO_KORSAVIL.attack_style, COMBO_KORSAVIL.swings.size(), COMBO_KORSAVIL.combo_reset_time, COMBO_KORSAVIL.speed_scale],
		[true, AttackCombo.AttackStyle.MELEE, 3, 0.6, 1.0])
	var sw := COMBO_KORSAVIL.swings
	_check("windups 0.06 / 0.06 / 0.08 s", [sw[0].windup, sw[1].windup, sw[2].windup], [0.06, 0.06, 0.08])
	_check("roots 0.22 / 0.22 / 0.32 s, a 0.2 s breather after the finisher only",
		[sw[0].duration, sw[1].duration, sw[2].duration, sw[0].pause_after, sw[1].pause_after, sw[2].pause_after], [0.22, 0.22, 0.32, 0.0, 0.0, 0.2])
	_check("damage 0.9 / 0.9 / 1.4 x AD, arcs 90 / 90 / 120", [sw[0].ad_ratio, sw[1].ad_ratio, sw[2].ad_ratio, sw[0].arc_deg, sw[1].arc_deg, sw[2].arc_deg],
		[0.9, 0.9, 1.4, 90.0, 90.0, 120.0])
	_check("only swing 3 is the finisher (its hit tags)", [_plain(sw[0].hit_tags), _plain(sw[1].hit_tags), _plain(sw[2].hit_tags)], [[], [], [&"finisher"]])
	_check("the dash-strike: 1.3 x AD, not a finisher", [COMBO_KORSAVIL.dash_strike.ad_ratio, COMBO_KORSAVIL.dash_strike.hit_tags.size()], [1.3, 0])
	var knight_tags := COMBO_KNIGHT.dash_strike.hit_tags.size()
	for x in COMBO_KNIGHT.swings:
		knight_tags += x.hit_tags.size()
	_check("the Knight's combo has no hit tags (unchanged)", knight_tags, 0)


func _test_korsavil_loaded() -> void:
	_section("K1: player.tscn loads Korsavil")
	var k := await _spawn(false, KORSAVIL)
	_check("live: 500 health, 60 AD, 0.7 attack speed, 390 move speed, 150 range, 0.25 crit",
		[k.health.max_health, k.stats_component.get_stat(&"attack_damage"), k.stats_component.get_stat(&"attack_speed"),
			k.movement.get_move_speed(), k.stats_component.get_stat(&"attack_range"), k.stats_component.get_stat(&"crit_chance")],
		[500.0, 60.0, 0.7, 390.0, 150.0, 0.25])
	_check("the pool: ENERGY, full (100 of 100), no decay", [k.resource_pool.resource_type, k.resource_pool.max_resource, k.resource_pool.current, k.resource_pool.decay_per_second],
		[ENERGY, 100.0, 100.0, 0.0])
	_check("Q Bladesinger, W / E / R empty, her combo hers, no model (a capsule)",
		[k.abilities.q == BLADESINGER, k.abilities.w, k.abilities.e, k.abilities.r, k.attack.combo == COMBO_KORSAVIL, k.model_scene == null], [true, null, null, null, true, true])
	_check("dash_charges 2: the passive's +1 under passive_korsavil", [int(k.stats_component.get_stat(&"dash_charges")), k.dash.get_max_charges(), k.stats_component.get_modifiers_from(&"passive_korsavil").size()],
		[2, 2, 1])
	await _wait_until(func() -> bool: return k.dash.get_charges() >= 2, 60)
	_check("both dash charges ready shortly after load (0.35 s for the second)", k.dash.get_charges(), 2)
	k.resource_pool.try_spend(50.0)
	await _frames(60)
	_check_near("Energy comes back at 10 a second (50 → 60 in 60 physics frames)", k.resource_pool.current, 60.0, 0.5)
	_check("a press on an empty slot (W) casts nothing", [k.abilities.try_cast(&"w", k.global_position + Vector2.RIGHT * 50.0), k.abilities.casting], [false, false])
	var hud: CanvasLayer = HUD_SCENE.instantiate()
	add_child(hud)
	hud.setup_abilities(k)
	await _frames(2)
	_check("HUD: the ability bar, the Energy bar and her passive slot", [hud.get_node_or_null("AbilityBar") != null, hud.get_node_or_null("ResourceBar") != null, hud.get_node_or_null("PassiveSlot") != null],
		[true, true, true])
	hud.queue_free()
	k.queue_free()
	await _frames(1)


func _test_korsavil_swings() -> void:
	_section("K1: her 3-swing cycle: only the finisher's hits carry `finisher`")
	var k := await _spawn(false, KORSAVIL)
	var no_crit := StatModifier.new()
	no_crit.stat = &"crit_chance"
	no_crit.value = -10.0
	no_crit.source_id = &"test_no_crit"
	k.stats_component.add_modifier(no_crit)
	var d := _dummy(k.global_position + Vector2(36, 0))
	await _frames(1)
	var hits: Array = []   # [the finisher tag, the melee tag, raw damage] per hit of hers
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.source == k and ctx.has_tag(&"basic_attack"):
			hits.append([ctx.has_tag(&"finisher"), ctx.has_tag(&"melee"), roundi(ctx.raw_damage)])
	Events.unit_hit.connect(on_hit)
	for i in 3:
		await _wait_until(func() -> bool: return k.attack.can_swing(), 120)
		var before := hits.size()
		k.attack.try_swing(Vector2.RIGHT)
		await _wait_until(func() -> bool: return hits.size() > before, 60)
	Events.unit_hit.disconnect(on_hit)
	_check("three swings: 54 / 54 / 84 raw (0.9 / 0.9 / 1.4 x 60 AD), all melee, only the third tagged `finisher`",
		hits, [[false, true, 54], [false, true, 54], [true, true, 84]])
	var knight := await _spawn()
	var tags := HitPipeline.basic_attack(knight, d, COMBO_KNIGHT.swings[2]).tags
	_check("the Knight's finisher hit: no `finisher` tag (his data unchanged)", tags.has(&"finisher"), false)
	d.queue_free()
	k.queue_free()
	knight.queue_free()
	Audio.stop_all()   # the finisher's heavy hit sound would still play at quit
	await _frames(10)


func _test_korsavil_hub_pick() -> void:
	_section("K1: the hub's champion pick (Progress.picked_champion)")
	Progress.picked_champion = null
	var hub: Hub = HUB_SCENE.instantiate()
	add_child(hub)
	await _frames(1)
	_check("a pick row: the Knight (picked) and Korsavil", _pick_row(hub), [["Knight", true], ["Korsavil", false]])
	_check("with no pick: the Knight's hub", [hub.champion == KNIGHT, hub.get_header_text().begins_with("Knight   ")], [true, true])
	hub.pick_champion(KORSAVIL)
	await _frames(1)
	_check("picking Korsavil: Progress keeps it; the header, the buttons and the talent screen follow",
		[Progress.picked_champion == KORSAVIL, hub.get_header_text(), _pick_row(hub), hub.talent_screen.champion == KORSAVIL],
		[true, "Korsavil   Level 1: 0 / 600 XP   Talents 0 / 1", [["Knight", false], ["Korsavil", true]], true])
	_check("her talent screen has no talents, and says so",
		[hub.talent_screen.find_children("*", "Button", true, false).size(), hub.get_detail_text()], [0, "Korsavil has no talents yet."])
	var q_uses := Progress.get_progress(KORSAVIL).get_ability_uses(&"korsavil_bladesinger")
	hub._debug(func() -> void: Progress.debug_add_ability_uses(KORSAVIL, 100))
	_check("+100 uses: only her Q counts (W, E, R empty, no error)",
		[Progress.get_progress(KORSAVIL).get_ability_uses(&"korsavil_bladesinger") - q_uses, Progress.get_progress(KORSAVIL).ability_uses.keys()],
		[100, [&"korsavil_bladesinger"]])
	hub.queue_free()
	await _frames(1)
	var again: Hub = HUB_SCENE.instantiate()
	add_child(again)
	await _frames(1)
	_check("back at the hub (a new one): still Korsavil", [again.champion == KORSAVIL, _pick_row(again)], [true, [["Knight", false], ["Korsavil", true]]])
	again.pick_champion(KNIGHT)
	await _frames(1)
	_check("picking the Knight back: his talents and the hover hint", [again.get_header_text().begins_with("Knight   "), again.talent_screen.find_children("*", "Button", true, false).size(), again.get_detail_text()],
		[true, KNIGHT.talents.size(), "Hover a talent to read it. Click to put it in or take it out."])
	again.queue_free()
	Progress.picked_champion = null
	await _frames(1)


func _test_bladesinger_data() -> void:
	_section("K2: Q Bladesinger's data (korsavil_q_bladesinger.tres) and her statuses")
	var q := BLADESINGER
	_check("id, tags core + projectile, SELF, INSTANT", [q.id, _plain(q.tags), q.targeting, q.cast_style],
		[&"korsavil_bladesinger", [&"core", &"projectile"], Ability.Targeting.SELF, Ability.CastStyle.INSTANT])
	_check("25 Energy (its recast 0), 10 s cooldown, 0.25 s cast, one recast in a 6 s window",
		[q.resource_cost, q.recast_resource_cost, q.cooldown, q.cast_time, q.recast_count, q.recast_window], [25.0, 0.0, 10.0, 0.25, 1, 6.0])
	_check("Blades: 600 u (6 m), 1500 u/s, 60 u wide, 4 at most, 30° apart (90° for 4), pierce 0; she walks while casting",
		[q.cast_range, q.projectile_speed, q.projectile_width, q.projectile_count, q.projectile_spread_deg, q.projectile_pierce, q.roots_during_cast],
		[600.0, 1500.0, 60.0, 4, 30.0, 0, false])
	_check("each Blade: 110% AD at 4 Blades, PHYSICAL", [q.base_damage, q.ad_ratio, q.damage_type], [0.0, 1.1, HitContext.DamageType.PHYSICAL])
	var cond: Condition = q.recast_conditions[0] if q.recast_conditions.size() == 1 else null
	_check("the recast needs a Blade: SELF_HAS_STATUS blade, at least 1, \"No Blades\"; part 0 has no condition",
		[cond != null and cond.kind == Condition.Kind.SELF_HAS_STATUS, cond.status_tag if cond else &"", cond.min_stacks if cond else 0, cond.fail_text if cond else "", q.cast_conditions.size()],
		[true, &"blade", 1, "No Blades", 0])
	var bonus: ConditionalBonus = q.conditional_bonuses[0] if q.conditional_bonuses.size() == 1 else null
	_check("every Blade that hits marks Inevitable Demise (a bonus with no conditions)",
		[bonus != null and bonus.conditions.is_empty(), _plain(bonus.target_statuses) if bonus else []], [true, [STATUS_DEMISE]])
	var by_param := {}
	for s in q.charge_scalings:
		by_param[s.param] = [s.input, roundi(s.min_fraction * 10000.0), s.curve == null]
	_check("ad_ratio and projectile_count follow the `blades` input, linear (7/11 and 0 at none)",
		by_param, {&"ad_ratio": [&"blades", 6364, true], &"projectile_count": [&"blades", 0, true]})
	_check("the script's statuses, a Blade a second, all 4 for Stalker",
		[q.get("orbit_status") == STATUS_ORBIT, q.get("blade_status") == STATUS_BLADE, q.get("stalker_status") == STATUS_STALKER, q.get("blade_interval"), q.get("stalker_hits")],
		[true, true, true, 1.0, 4])
	_check("Blade: 0–4, until spent (STACK, max 4, −1), tags blade + buff",
		[STATUS_BLADE.id, STATUS_BLADE.duration, STATUS_BLADE.stack_rule, STATUS_BLADE.max_stacks, _plain(STATUS_BLADE.tags), STATUS_BLADE.modifiers.size()],
		[&"blade", -1.0, StatusEffect.StackRule.STACK, 4, [&"blade", &"buff"], 0])
	var scalings: Array = []
	for s in STATUS_ORBIT.stat_scalings:
		var sc := s as StatScaling
		scalings.append([sc.modifier.stat, sc.modifier.type, sc.modifier.value, sc.input, sc.status_tag, sc.max_stacks, sc.curve == null])
	_check("the orbit: 6 s, REFRESH, tags bladesinger + buff, two scalings on blade ÷ 4 (incoming_damage −20% \"more\", move_speed +20% at 4)",
		[STATUS_ORBIT.id, STATUS_ORBIT.duration, STATUS_ORBIT.stack_rule, _plain(STATUS_ORBIT.tags), STATUS_ORBIT.modifiers.size(), scalings],
		[&"bladesinger", 6.0, StatusEffect.StackRule.REFRESH, [&"bladesinger", &"buff"], 0, [
			[&"incoming_damage", StatModifier.Type.PERCENT_MULT, -0.2, &"self_status_stacks", &"blade", 4, true],
			[&"move_speed", StatModifier.Type.PERCENT_ADD, 0.2, &"self_status_stacks", &"blade", 4, true]]])
	_check("Demise: STACK_SHARED, 8, 5 s, a tick every 0.5 s of 1% AD x the table, PHYSICAL, not cc, tags inevitable_demise + debuff",
		[STATUS_DEMISE.id, STATUS_DEMISE.stack_rule, STATUS_DEMISE.max_stacks, STATUS_DEMISE.duration, STATUS_DEMISE.tick_interval, STATUS_DEMISE.tick_ad_ratio,
			_plain(STATUS_DEMISE.tick_by_stacks), STATUS_DEMISE.tick_damage_type, STATUS_DEMISE.is_cc(), _plain(STATUS_DEMISE.tags)],
		[&"inevitable_demise", StatusEffect.StackRule.STACK_SHARED, 8, 5.0, 0.5, 0.01, [0.0, 0.5, 0.5, 0.8, 0.8, 1.0, 1.0, 1.2],
			HitContext.DamageType.PHYSICAL, false, [&"inevitable_demise", &"debuff"]])
	_check("its tiers per 5 s at 1–8 stacks (Ryan): 0 / 5 / 5 / 8 / 8 / 10 / 10 / 12% AD",
		STATUS_DEMISE.tick_by_stacks.map(func(m: float) -> int: return roundi(m * STATUS_DEMISE.tick_ad_ratio * 10.0 * 100.0)),
		[0, 5, 5, 8, 8, 10, 10, 12])
	_check("Umbral Stalker: 10 s, tags form + buff, REFRESH (its REPLACE of R comes in K5)",
		[STATUS_STALKER.id, STATUS_STALKER.duration, _plain(STATUS_STALKER.tags), STATUS_STALKER.stack_rule, STATUS_STALKER.augments.size()],
		[&"umbral_stalker", 10.0, [&"form", &"buff"], StatusEffect.StackRule.REFRESH, 0])


func _test_bladesinger_orbit() -> void:
	_section("K2: Q's orbit: a Blade a second; damage taken and speed follow them while it lasts")
	var k := await _spawn(false, KORSAVIL)
	var sc := k.status_component
	var stats := k.stats_component
	var aim := k.global_position + Vector2.RIGHT * 100.0
	k.abilities.set_aim_hint(aim)
	_check("cast: 25 Energy spent", [k.abilities.try_cast(&"q", aim), k.resource_pool.current], [true, 75.0])
	await _wait_until(func() -> bool: return sc.has_status(&"bladesinger"), 30)
	_check_near("after its 0.25 s cast: the orbit on her for 6 s", sc.get_time_left(&"bladesinger"), 6.0, 0.02)
	_check("the recast window open, no Blade yet", [k.abilities.get_recast_part(&"q"), sc.get_stacks(&"blade")], [1, 0])
	_check("the recast with 0 Blades fails: \"condition\", \"No Blades\"; the window keeps running",
		[k.abilities.get_fail_reason(&"q", aim), k.abilities.get_condition_fail_text(&"q"), k.abilities.try_cast(&"q", aim), k.abilities.get_recast_part(&"q")],
		["condition", "No Blades", false, 1])
	_check("no Blades: damage taken x1, move speed 390", [stats.get_stat(&"incoming_damage"), stats.get_stat(&"move_speed")], [1.0, 390.0])
	var frames := 0
	while sc.get_stacks(&"blade") < 1 and frames < 90:
		await _frames(1)
		frames += 1
	_check_near("the first Blade 1 s into the orbit (60 physics frames)", frames, 60.0, 1.5)
	await _frames(1)
	_check("1 Blade: 5% less damage taken, 5% faster (390 → 409.5)",
		[roundi(stats.get_stat(&"incoming_damage") * 10000.0), roundi(stats.get_stat(&"move_speed") * 100.0)], [9500, 40950])
	await _wait_until(func() -> bool: return sc.get_stacks(&"blade") >= 4, 240)
	await _frames(1)
	_check("4 Blades by 4 s: x0.8 damage taken, +20% speed (468)",
		[sc.get_stacks(&"blade"), roundi(stats.get_stat(&"incoming_damage") * 10000.0), roundi(stats.get_stat(&"move_speed") * 100.0)], [4, 8000, 46800])
	var before := k.health.current
	k.take_damage(100.0)
	_check("a 100 physical hit takes 80", before - k.health.current, 80.0)
	await _wait_until(func() -> bool: return not sc.has_status(&"bladesinger"), 200)
	await _frames(1)
	_check("the orbit ends at 6 s: the Blades stay (4), damage taken and speed back (x1, 390)",
		[sc.get_stacks(&"blade"), stats.get_stat(&"incoming_damage"), stats.get_stat(&"move_speed")], [4, 1.0, 390.0])
	await _frames(3)
	_check("the window closed with it, and the 10 s cooldown runs", [k.abilities.get_recast_part(&"q"), k.abilities.get_cooldown_left(&"q") > 9.0], [0, true])
	k.queue_free()
	await _frames(1)


func _test_bladesinger_recast() -> void:
	_section("K2: Q's recast: every Blade at the aim, a Demise stack per hit, Umbral Stalker when all 4 hit")
	var k := await _spawn(false, KORSAVIL)
	k.stats_component.add_modifier(StatModifier.create(&"crit_chance", StatModifier.Type.FLAT, -10.0, &"test_no_crit"))
	var sc := k.status_component
	var dummies: Array[Enemy] = []
	for deg: float in [-45.0, -15.0, 15.0, 45.0]:
		dummies.append(_dummy(k.global_position + Vector2.RIGHT.rotated(deg_to_rad(deg)) * 100.0))
	await _frames(1)
	for i in 5:
		sc.apply_status(STATUS_BLADE, k)
	_check("5 Blades given: she holds 4 (a gain past 4 is lost)", sc.get_stacks(&"blade"), 4)
	var hits: Array = []
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.source == k and ctx.ability == BLADESINGER:
			hits.append([ctx.target, roundi(ctx.raw_damage)])
	Events.unit_hit.connect(on_hit)
	var aim := k.global_position + Vector2.RIGHT * 100.0
	k.abilities.set_aim_hint(aim)
	k.abilities.try_cast(&"q", aim)
	await _wait_until(func() -> bool: return k.abilities.get_recast_part(&"q") == 1 and not k.abilities.casting, 30)
	_check("Q while holding 4: the orbit starts at full (x0.8 damage taken next frame); the recast is ready", [k.abilities.try_cast(&"q", aim)], [true])
	await _wait_until(func() -> bool: return hits.size() >= 4, 90)
	await _frames(2)
	var targets := hits.map(func(h: Array) -> Object: return h[0])
	_check("4 Blades, 30° apart toward the aim: each dummy hit once, 66 raw each (110% of 60 AD)",
		[hits.size(), dummies.all(func(d: Enemy) -> bool: return targets.count(d) == 1), hits.map(func(h: Array) -> int: return h[1])], [4, true, [66, 66, 66, 66]])
	_check("each dummy: 1 Demise stack, from her",
		dummies.map(func(d: Enemy) -> Array: return [d.status_component.get_stacks(&"inevitable_demise"), d.status_component.get_source(&"inevitable_demise") == k]),
		[[1, true], [1, true], [1, true], [1, true]])
	_check("the Blades spent, the orbit over; all 4 hit: Umbral Stalker on her for 10 s",
		[sc.get_stacks(&"blade"), sc.has_status(&"bladesinger"), sc.has_status(&"umbral_stalker"), sc.get_time_left(&"umbral_stalker") > 9.5], [0, false, true, true])
	await _wait_until(func() -> bool: return k.abilities.get_recast_part(&"q") == 0, 30)
	await _frames(2)
	k.abilities.reset_cooldown(&"q")
	sc.remove_status(&"umbral_stalker")
	for d in dummies:
		d.status_component.remove_status(&"inevitable_demise")
	sc.apply_status(STATUS_BLADE, k)
	sc.apply_status(STATUS_BLADE, k)
	hits.clear()
	k.abilities.try_cast(&"q", aim)
	await _wait_until(func() -> bool: return k.abilities.get_recast_part(&"q") == 1 and not k.abilities.casting, 30)
	k.abilities.try_cast(&"q", aim)
	await _wait_until(func() -> bool: return hits.size() >= 2, 90)
	await _frames(30)
	Events.unit_hit.disconnect(on_hit)
	targets = hits.map(func(h: Array) -> Object: return h[0])
	_check("2 Blades: 2 fly, 15° each side of the aim, 54 raw each (90% of 60 AD); no Stalker",
		[hits.size(), targets.has(dummies[1]) and targets.has(dummies[2]), hits.map(func(h: Array) -> int: return h[1]), sc.has_status(&"umbral_stalker")],
		[2, true, [54, 54], false])
	for d in dummies:
		d.queue_free()
	k.queue_free()
	Audio.stop_all()
	await _frames(10)


func _test_demise() -> void:
	_section("K2: Inevitable Demise: a tier by stacks, one shared 5 s timer")
	var k := await _spawn(false, KORSAVIL)
	var d := _dummy(k.global_position + Vector2(300, 0))
	d.stats_component.add_modifier(StatModifier.create(&"max_health", StatModifier.Type.FLAT, 5000.0, &"test_tough"))
	await _frames(1)
	var ticks: Array[HitContext] = []
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.target == d and ctx.has_tag(&"dot"):
			ticks.append(ctx)
	Events.unit_hit.connect(on_hit)
	var dsc := d.status_component
	dsc.apply_status(STATUS_DEMISE, k)
	await _frames(32)
	_check("1 stack: no tick (the first tier is at 2)", ticks.size(), 0)
	var per_tick: Array = []
	for n in 7:
		dsc.apply_status(STATUS_DEMISE, k)
		var before := ticks.size()
		await _wait_until(func() -> bool: return ticks.size() > before, 40)
		per_tick.append(roundi(ticks[-1].raw_damage * 1000.0) if ticks.size() > before else -1)
	_check("a tick every 0.5 s at 2–8 stacks: 0.3 / 0.3 / 0.48 / 0.48 / 0.6 / 0.6 / 0.72 (1% of 60 AD x the table)",
		per_tick, [300, 300, 480, 480, 600, 600, 720])
	var last: HitContext = ticks[-1] if not ticks.is_empty() else HitContext.new()
	_check("its ticks: dot + inevitable_demise, PHYSICAL, from her, no crit",
		[last.has_tag(&"dot"), last.has_tag(&"inevitable_demise"), last.damage_type, last.source == k, last.is_crit], [true, true, HitContext.DamageType.PHYSICAL, true, false])
	dsc.apply_status(STATUS_DEMISE, k)
	_check("a 9th Blade: still 8 stacks, the shared 5 s restarted", [dsc.get_stacks(&"inevitable_demise"), dsc.get_time_left(&"inevitable_demise")], [8, 5.0])
	var seen: Array = []
	var frames := 0
	while dsc.has_status(&"inevitable_demise") and frames < 400:
		seen.append(dsc.get_stacks(&"inevitable_demise"))
		await _frames(1)
		frames += 1
	Events.unit_hit.disconnect(on_hit)
	_check_near("with no new Blade, all 8 go together 5 s later (300 frames)", frames, 300.0, 2.0)
	_check("8 stacks the whole time, though they came over 3 s (no stack runs out on its own)", [seen.min(), seen.max()], [8, 8])
	d.queue_free()
	k.queue_free()
	await _frames(1)


## The hub's pick row as [button text, pressed] per champion.
func _pick_row(hub: Hub) -> Array:
	var out: Array = []
	var row := hub.find_child("ChampionPick", true, false)
	if row != null:
		for b in row.find_children("*", "Button", true, false):
			out.append([(b as Button).text, (b as Button).button_pressed])
	return out


# --- Helpers ------------------------------------------------------------------

## A bonus's modifiers as [stat, type, value] (for data checks).
func _bonus_mods(b: ConditionalBonus) -> Array:
	var out := []
	if b == null:
		return out
	for m in b.modifiers:
		out.append([m.stat, m.type, snappedf(m.value, 0.001)])
	return out


## The Knight's own crit chance cancelled (exact damage checks).
func _no_crits(p: Player) -> void:
	var base := p.stats_component.get_base_value(&"crit_chance")
	if base != 0.0:
		p.stats_component.add_modifier(StatModifier.create(&"crit_chance", StatModifier.Type.FLAT, -base, &"test_baseline"))


func _has_child_with_script(node: Node, script_file: String) -> bool:
	for c in node.get_children():
		var s: Script = c.get_script()
		if s != null and s.resource_path.ends_with(script_file) and not c.is_queued_for_deletion():
			return true
	return false


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
