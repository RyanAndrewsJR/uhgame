extends Node2D
## CHAMPIONS.md test: open res://scenes/tests/champions_test.tscn and press F6.
## CH1: the Knight's ChampionData (data/champions/knight.tres), loading it
## onto the real player.tscn, a Player with no champion using its scene's own
## exports, the loaded Knight matching the old exports exactly, another
## champion's data replacing every copied field, and resource type NONE
## removing the pool.
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

const MANA := ResourceComponent.ResourceType.MANA
const ENERGY := ResourceComponent.ResourceType.ENERGY
const NONE := ResourceComponent.ResourceType.NONE

var _passed: int = 0
var _failed: int = 0
var _next_x: float = 0.0


func _ready() -> void:
	print("\n=== Champions test (CHAMPIONS CH1) ===")
	_test_knight_data()
	await _test_knight_loaded()
	await _test_no_champion()
	await _test_other_champion()
	await _test_resource_none()
	await _test_level_not_read()
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


# --- Helpers ------------------------------------------------------------------

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
