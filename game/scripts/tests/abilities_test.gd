extends Node2D
## ABILITIES.md test: open res://scenes/tests/abilities_test.tscn and press F6.
## Spawns the real player.tscn, passive slimes (training dummies) and the
## elite slime, and checks the ability framework step by step.
## AB1: cast styles (INSTANT default, CHANNEL = cancel_on_move), a stun or
## silence during a cast time interrupting it at once (refunded), an effect
## that has started not being interrupted, and the cast mode setting
## (saved, applied to the Player, INSTANT only).
## AB2: damage scalings (DamageScaling terms, ap_ratio, Judgement's missing
## health in data with the same numbers, scoped modifiers raising a ratio),
## tooltips from the description template, and the standard tags.
## AB3: costs (paid at cast start, refunded on a cancel or interrupt, not once
## the effect starts; a unit without a pool pays nothing), "not enough
## resource" failing at once and never buffered, the fail reasons, a
## buffered press that runs out reporting why, and the HUD cues (the
## resource bar and the slot flashes).
## Prints PASS/FAIL per check, then a total. Run headless and it quits with
## the number of failures as the exit code.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const SLIME_SCENE: PackedScene = preload("res://scenes/enemies/slime.tscn")
const ELITE_SCENE: PackedScene = preload("res://scenes/enemies/slime_elite.tscn")
const CLEAVE: Ability = preload("res://data/abilities/knight_q_cleave.tres")
const IRON_RESOLVE: Ability = preload("res://data/abilities/knight_w_iron_resolve.tres")
const LUNGE: Ability = preload("res://data/abilities/knight_e_lunge.tres")
const JUDGEMENT: Ability = preload("res://data/abilities/knight_r_judgement.tres")
const SLAM: Ability = preload("res://data/abilities/slime_elite_q_slam.tres")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const COST_SOURCE := &"item_test_costs"
const ARENA := Vector2(-2000, 0)

var knight: Player

var _passed: int = 0
var _failed: int = 0
var _finished: int = 0
var _cancelled: int = 0


func _ready() -> void:
	knight = PLAYER_SCENE.instantiate()
	add_child(knight)
	_place(knight, ARENA)
	knight.abilities.cast_finished.connect(func(_s: StringName, _a: Ability) -> void: _finished += 1)
	knight.abilities.cast_cancelled.connect(func(_s: StringName, _a: Ability) -> void: _cancelled += 1)
	await get_tree().physics_frame

	print("\n=== Abilities test (ABILITIES AB1) ===")
	_test_cast_styles()
	await _test_stun_interrupts_at_once()
	await _test_elite_stunned_mid_slam()
	await _test_silence_interrupts()
	await _test_other_status_does_not_interrupt()
	await _test_effect_not_interrupted()
	await _test_channel_cancel_on_move()
	await _test_cast_mode()
	print("\n=== Abilities test (ABILITIES AB2) ===")
	await _test_scalings()
	_test_tooltips()
	_test_tags()
	print("\n=== Abilities test (ABILITIES AB3) ===")
	await _test_costs()
	await _test_fail_cues()
	await _test_hud_cues()
	print("=== %d passed, %d failed ===\n" % [_passed, _failed])

	# A sound still playing at quit prints a harmless leak warning (AUDIO.md).
	Audio.stop_all()
	await _frames(1)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(_failed)


# --- AB1 ------------------------------------------------------------------------

func _test_cast_styles() -> void:
	_section("AB1: cast styles")
	_check("INSTANT is the default", Ability.new().cast_style, Ability.CastStyle.INSTANT)
	_check("Cleave, Iron Resolve, Lunge and the slam are INSTANT",
		[CLEAVE.cast_style, IRON_RESOLVE.cast_style, LUNGE.cast_style, SLAM.cast_style],
		[Ability.CastStyle.INSTANT, Ability.CastStyle.INSTANT, Ability.CastStyle.INSTANT, Ability.CastStyle.INSTANT])
	_check("Judgement is a CHANNEL (cancel_on_move still on)",
		[JUDGEMENT.cast_style, JUDGEMENT.cancel_on_move, JUDGEMENT.is_channel()], [Ability.CastStyle.CHANNEL, true, true])
	var style_only := Ability.new()
	style_only.cast_style = Ability.CastStyle.CHANNEL
	var flag_only := Ability.new()
	flag_only.cancel_on_move = true
	_check("is_channel(): CHANNEL alone, cancel_on_move alone, neither",
		[style_only.is_channel(), flag_only.is_channel(), CLEAVE.is_channel()], [true, true, false])


func _test_stun_interrupts_at_once() -> void:
	_section("AB1: a stun during Judgement's cast time interrupts it at once")
	await _reset_knight()
	var dummy := _dummy_at(Vector2(80, 0))
	var hp := dummy.health.current
	_check("Judgement starts (1.5 s channel)", knight.abilities.try_cast(&"r", dummy.global_position, dummy), true)
	await _frames(6)
	_check("0.1 s in: still casting, cooldown running", [knight.abilities.casting, knight.abilities.is_ready(&"r")], [true, false])
	var finished_before := _finished
	var cancelled_before := _cancelled
	knight.apply_stun(0.2)   # ends long before the 1.5 s cast time would
	_check("the cast ends in the same frame", knight.abilities.casting, false)
	_check("cooldown refunded", knight.abilities.is_ready(&"r"), true)
	_check("cast_finished once, no cast_cancelled (an interrupt)",
		[_finished - finished_before, _cancelled - cancelled_before], [1, 0])
	await _frames(100)
	_check("no hit and no stun on the target later", [dummy.health.current, dummy.is_stunned()], [hp, false])
	_check("the Knight can move again once the stun ends", knight.movement.can_move(), true)
	dummy.queue_free()


func _test_elite_stunned_mid_slam() -> void:
	_section("AB1: a short stun on the elite mid-slam")
	await _reset_knight()
	var hp := knight.health.current
	var elite: Enemy = ELITE_SCENE.instantiate()
	elite.passive = true
	add_child(elite)
	_place(elite, knight.global_position + Vector2(60, 0))
	await _frames(1)
	elite.abilities.try_cast(&"q", knight.global_position, knight)
	var telegraph := _find_telegraph()
	await _frames(6)
	_check("the telegraph is on the floor", telegraph != null and not telegraph.is_queued_for_deletion(), true)
	elite.apply_stun(0.1)   # over well before the 0.65 s cast time ends
	_check("interrupted at once, cooldown refunded", [elite.abilities.casting, elite.abilities.is_ready(&"q")], [false, true])
	_check("its telegraph goes that frame", telegraph == null or telegraph.is_queued_for_deletion(), true)
	await _frames(1)
	_check("and is freed by the next frame", is_instance_valid(telegraph), false)
	await _frames(50)
	_check("no slam lands", knight.health.current, hp)
	elite.queue_free()
	await _frames(1)


func _test_silence_interrupts() -> void:
	_section("AB1: any status that blocks casting interrupts (a test silence)")
	await _reset_knight()
	var dummy := _dummy_at(Vector2(40, 0))
	var hp := dummy.health.current
	var silence := StatusEffect.new()
	silence.id = &"test_silence"
	silence.tags = [&"cc", &"silence", &"debuff"] as Array[StringName]
	silence.blocks_cast = true
	silence.duration = 0.1
	knight.abilities.try_cast(&"q", dummy.global_position)
	await _frames(2)
	_check("Cleave is in its 0.2 s cast time", knight.abilities.casting, true)
	knight.status_component.apply_status(silence)
	_check("silenced: interrupted at once, refunded", [knight.abilities.casting, knight.abilities.is_ready(&"q")], [false, true])
	await _frames(20)
	_check("Cleave never hit", dummy.health.current, hp)
	dummy.queue_free()


func _test_other_status_does_not_interrupt() -> void:
	_section("AB1: a status that doesn't block casting leaves the cast alone")
	await _reset_knight()
	var dummy := _dummy_at(Vector2(80, 0))
	knight.abilities.try_cast(&"r", dummy.global_position, dummy)
	await _frames(3)
	knight.movement.add_speed_modifier(&"test_slow", 0.0, -0.3, 0.5)   # a status_slow copy
	_check("slowed: still casting", knight.abilities.casting, true)
	knight.abilities.interrupt_cast()
	dummy.queue_free()


func _test_effect_not_interrupted() -> void:
	_section("AB1: a stun once the effect has started changes nothing (Lunge's dash)")
	await _reset_knight()
	var start := knight.global_position
	knight.abilities.try_cast(&"e", start + Vector2(120, 0))
	await _wait_until(func() -> bool: return knight.movement.is_displaced(), 10)
	_check("Lunge's dash is running (its effect)", knight.movement.is_displaced(), true)
	knight.apply_stun(0.1)
	_check("stunned mid-dash: the cast isn't interrupted", knight.abilities.casting, true)
	await _wait_until(func() -> bool: return not knight.abilities.casting, 60)
	_check_near("the dash reached its end (120 px)", knight.global_position.x - start.x, 120.0, 2.0)
	_check("cooldown not refunded", knight.abilities.is_ready(&"e"), false)


func _test_channel_cancel_on_move() -> void:
	_section("AB1: CHANNEL works like cancel_on_move")
	await _reset_knight()
	var channel: Ability = CLEAVE.duplicate()
	channel.cast_style = Ability.CastStyle.CHANNEL
	channel.cancel_on_move = false
	channel.roots_during_cast = false
	channel.cast_time = 0.5
	var instant: Ability = CLEAVE.duplicate()
	instant.cast_time = 0.5
	var original_q := knight.abilities.q

	knight.abilities.q = channel
	knight.abilities.try_cast(&"q", knight.global_position + Vector2(50, 0))
	await _frames(1)
	_check("a channel roots even with roots_during_cast off", knight.movement.can_move(), false)
	var cancelled_before := _cancelled
	knight.player_input._unhandled_input(_action(&"move_right", true))
	await _frames(1)
	_check("a new move press cancels it, cooldown refunded",
		[knight.abilities.casting, knight.abilities.is_ready(&"q"), _cancelled - cancelled_before], [false, true, 1])
	knight.player_input._unhandled_input(_action(&"move_right", false))

	knight.abilities.q = instant
	knight.abilities.try_cast(&"q", knight.global_position + Vector2(50, 0))
	await _frames(1)
	knight.player_input._unhandled_input(_action(&"move_right", true))
	await _frames(1)
	_check("an INSTANT cast ignores the move press", knight.abilities.casting, true)
	knight.player_input._unhandled_input(_action(&"move_right", false))
	knight.abilities.interrupt_cast()
	knight.abilities.q = original_q


func _test_cast_mode() -> void:
	_section("AB1: the cast mode setting")
	await _reset_knight()
	var original := Settings.get_cast_mode()
	var keys := []
	var on_changed := func(key: StringName, _value: Variant) -> void: keys.append(key)
	Settings.setting_changed.connect(on_changed)

	Settings.set_cast_mode(Player.CastMode.QUICK_WITH_INDICATOR)
	Settings.set_cast_mode(Player.CastMode.QUICK)
	_check("emitted as cast_mode", keys, [Settings.CAST_MODE, Settings.CAST_MODE])
	_check("the Player follows it", knight.cast_mode, Player.CastMode.QUICK)
	var cfg := ConfigFile.new()
	cfg.load(Settings.SAVE_PATH)
	_check("saved as a word in [controls]", cfg.get_value("controls", "cast_mode", ""), "quick")
	Settings.set_cast_mode(Player.CastMode.QUICK_WITH_INDICATOR)
	cfg.load(Settings.SAVE_PATH)
	_check("hold to aim saved", cfg.get_value("controls", "cast_mode", ""), "quick_with_indicator")
	Settings.load_settings()
	_check("loads back", [Settings.get_cast_mode(), knight.cast_mode],
		[Player.CastMode.QUICK_WITH_INDICATOR, Player.CastMode.QUICK_WITH_INDICATOR])

	# Hold to aim: an INSTANT ability aims on press and casts on release.
	knight._unhandled_input(_action(&"ability_e", true))
	_check("hold to aim: E (INSTANT) aims on press", [knight.aiming_slot, knight.abilities.casting], [&"e", false])
	knight._unhandled_input(_action(&"ability_e", false))
	_check("and casts on release", [knight.aiming_slot, knight.abilities.is_ready(&"e")], [&"", false])
	await _wait_until(func() -> bool: return not knight.abilities.casting, 60)
	# CHANNEL casts on press whatever the mode.
	knight._unhandled_input(_action(&"ability_r", true))
	_check("hold to aim: R (CHANNEL) doesn't aim; it's cast on press", knight.aiming_slot, &"")
	knight._unhandled_input(_action(&"ability_r", false))
	knight.abilities.interrupt_cast()
	knight.abilities.cancel_pending()

	# Quick: cast on press.
	Settings.set_cast_mode(Player.CastMode.QUICK)
	knight._unhandled_input(_action(&"ability_q", true))
	_check("quick: Q casts on press", [knight.aiming_slot, knight.abilities.casting_slot], [&"", &"q"])
	knight._unhandled_input(_action(&"ability_q", false))
	await _wait_until(func() -> bool: return not knight.abilities.casting, 60)

	Settings.setting_changed.disconnect(on_changed)
	Settings.set_cast_mode(original)


# --- AB2 ------------------------------------------------------------------------

func _test_scalings() -> void:
	_section("AB2: damage scalings")
	await _reset_knight()
	var ad := knight.stats_component.get_stat(&"attack_damage")
	_check("the Knight's AD is 64 (the numbers below use it)", ad, 64.0)
	var dummy := _dummy_at(Vector2(80, 0))
	var max_hp := dummy.health.max_health

	# Judgement: the missing-health bonus is now a scaling term, same numbers.
	var term := JUDGEMENT.get_scaling(&"target_missing_health_ratio")
	_check("Judgement has the term: 20% of the target's missing health",
		[term != null, term.ratio if term else 0.0, term.of if term else -1], [true, 0.2, DamageScaling.Of.TARGET_MISSING_HEALTH])
	_check("the old missing_health_ratio export is gone (deleted after AB2 passed)", JUDGEMENT.get("missing_health_ratio"), null)
	var full := HitPipeline.get_scaled_damage(HitPipeline.from_ability(knight, JUDGEMENT, dummy))
	_check("full health: 150 + 64 = 214", full, 214.0)
	dummy.health.take_damage(max_hp * 0.5)
	var missing := dummy.health.max_health - dummy.health.current
	var old_formula := 150.0 + ad + 0.2 * missing
	var half := HitPipeline.from_ability(knight, JUDGEMENT, dummy)
	_check("half health: 214 + 20% of the missing health (the old formula)", HitPipeline.get_scaled_damage(half), old_formula)
	_check("the same as get_damage_against() and the old wrappers",
		[JUDGEMENT.get_damage_against(knight, dummy), JUDGEMENT.get_damage(knight) + JUDGEMENT.get_missing_health_bonus(dummy)],
		[old_formula, old_formula])
	_check("the bonus rides base_damage (so it crits); ad_ratio stays a ratio",
		[half.base_damage, half.ad_ratio], [150.0 + 0.2 * missing, 1.0])

	# A scoped modifier raises the ratio like any param.
	var item := &"item_test_executioner"
	knight.stats_component.add_modifier(StatModifier.create(&"target_missing_health_ratio",
		StatModifier.Type.FLAT, 0.1, item, &"ability:knight_judgement"))
	_check("+0.1 scoped: the ratio param is 0.3", JUDGEMENT.get_param(knight, &"target_missing_health_ratio"), 0.3)
	_check("and the hit gets 30% of the missing health",
		HitPipeline.get_scaled_damage(HitPipeline.from_ability(knight, JUDGEMENT, dummy)), 150.0 + ad + 0.3 * missing)
	knight.stats_component.remove_modifiers_from(item)
	_check("removed: back to 20%", JUDGEMENT.get_damage_against(knight, dummy), old_formula)
	_check("without a caster the param is the plain ratio", JUDGEMENT.get_param(null, &"target_missing_health_ratio"), 0.2)

	# The other term kinds, and ap_ratio.
	var bonus := &"item_test_bonus_ad"
	knight.stats_component.add_modifier(StatModifier.create(&"attack_damage", StatModifier.Type.FLAT, 20.0, bonus))
	var kinds: Array[float] = []
	for of: DamageScaling.Of in [DamageScaling.Of.CASTER_STAT, DamageScaling.Of.CASTER_BONUS_STAT,
			DamageScaling.Of.TARGET_MAX_HEALTH, DamageScaling.Of.TARGET_MISSING_HEALTH, DamageScaling.Of.TARGET_CURRENT_HEALTH]:
		var t := DamageScaling.new()
		t.of = of
		t.stat = &"attack_damage"
		kinds.append(t.get_amount(knight, dummy))
	_check("amounts: AD 84, bonus AD 20, target max / missing / current",
		kinds, [84.0, 20.0, max_hp, missing, dummy.health.current])
	var labels: Array[String] = []
	for of: DamageScaling.Of in [DamageScaling.Of.CASTER_STAT, DamageScaling.Of.CASTER_BONUS_STAT, DamageScaling.Of.TARGET_MISSING_HEALTH]:
		var t := DamageScaling.new()
		t.of = of
		t.stat = &"attack_damage"
		labels.append(t.get_label())
	_check("labels", labels, ["AD", "bonus AD", "of the target's missing health"])
	var test_ability: Ability = CLEAVE.duplicate()
	test_ability.id = &"test_scaled"
	test_ability.ap_ratio = 0.5
	var bonus_term := DamageScaling.new()
	bonus_term.param = &"bonus_ad_ratio"
	bonus_term.ratio = 0.6
	bonus_term.of = DamageScaling.Of.CASTER_BONUS_STAT
	bonus_term.stat = &"attack_damage"
	test_ability.scalings = [bonus_term] as Array[DamageScaling]
	knight.stats_component.add_modifier(StatModifier.create(&"ability_power", StatModifier.Type.FLAT, 100.0, bonus))
	_check("80 + 70% of 84 AD + 50% of 100 AP + 60% of 20 bonus AD = 200.8",
		[test_ability.get_damage(knight), HitPipeline.get_scaled_damage(HitPipeline.from_ability(knight, test_ability, dummy))],
		[200.8, 200.8])
	knight.stats_component.remove_modifiers_from(bonus)
	_check("Cleave is unchanged: 80 + 0.7 x 64 = 124.8", CLEAVE.get_damage(knight), 124.8)
	dummy.queue_free()


func _test_tooltips() -> void:
	_section("AB2: tooltips from the description template")
	_check("Cleave (and its 80 base, not the old 70)", CLEAVE.get_tooltip_plain(knight),
		"Sweep your sword in a wide arc in front of you, dealing 125 physical damage (80 +70% AD) and knocking enemies back.")
	_check("Iron Resolve (percents with {x%})", IRON_RESOLVE.get_tooltip_plain(knight),
		"Gain 35% movement speed for 2s. Your next attack within 4s deals 82 (50 +50% AD) bonus damage and slows the target by 40% for 1.5s.")
	_check("Lunge ({range})", LUNGE.get_tooltip_plain(knight),
		"Dash up to 400 units toward the target spot, passing through units and dealing 82 physical damage (50 +50% AD) to every enemy you cut through.")
	_check("Judgement (the target term as text)", JUDGEMENT.get_tooltip_plain(knight),
		"Strike an enemy for 214 physical damage (150 +100% AD +20% of the target's missing health), and stun it for 0.75s. Channel: moving cancels it. Walks into range if needed.")
	_check("the slam, without a caster", SLAM.get_tooltip_plain(null),
		"Marks a 72 px circle where the target stands, fills it over 0.65 s, then slams: 100 physical damage and a 20 px push to everyone inside.")
	var bb := CLEAVE.get_tooltip(knight)
	var style: DamageNumberStyle = load(Ability.DAMAGE_NUMBER_STYLE_PATH)
	var color := style.get_damage_type_color(HitContext.DamageType.PHYSICAL).to_html(false)
	_check("BBCode: the damage colored by type (physical)", bb.contains("[color=#%s]125[/color]" % color), true)

	var src := &"item_test_tooltip"
	knight.stats_component.add_modifier(StatModifier.create(&"attack_damage", StatModifier.Type.FLAT, 36.0, src))
	knight.stats_component.add_modifier(StatModifier.create(&"ability_haste", StatModifier.Type.FLAT, 100.0, src))
	knight.stats_component.add_modifier(StatModifier.create(&"ad_ratio", StatModifier.Type.FLAT, 0.1, src, &"ability:knight_cleave"))
	var probe: Ability = CLEAVE.duplicate()
	probe.description = "cd {cooldown} range {range} cast {cast_time}"
	_check("with +36 AD and +10% AD scoped: 80 + 80% of 100 = 160, the ratio shows 80%",
		CLEAVE.get_tooltip_plain(knight).contains("dealing 160 physical damage (80 +80% AD)"), true)
	_check("{cooldown} after haste (3 s at 100 haste = 1.5), {range}, {cast_time}",
		probe.get_tooltip_plain(knight), "cd 1.5 range 300 cast 0.2")
	knight.stats_component.remove_modifiers_from(src)
	_check("removed: back to 125", CLEAVE.get_tooltip_plain(knight).contains("dealing 125 physical"), true)
	probe.description = "left {not_a_param} alone"
	print("  (one expected warning: unknown tooltip placeholder)")
	_check("an unknown placeholder stays as written", probe.get_tooltip_plain(knight), "left {not_a_param} alone")
	probe.description = "no placeholders"
	_check("plain text stays as it is", probe.get_tooltip_plain(knight), "no placeholders")


func _test_tags() -> void:
	_section("AB2: standard tags")
	var abilities: Array[Ability] = [CLEAVE, IRON_RESOLVE, LUNGE, JUDGEMENT, SLAM]
	var roles: Array[StringName] = []
	for a in abilities:
		roles.append(a.get_role())
	_check("one role each: core, defensive, mobility, ultimate, core", roles,
		[&"core", &"defensive", &"mobility", &"ultimate", &"core"] as Array[StringName])
	var styles_match := true
	for a in abilities:
		styles_match = styles_match \
			and ((&"channel" in a.tags) == (a.cast_style == Ability.CastStyle.CHANNEL)) \
			and ((&"charge_up" in a.tags) == (a.cast_style == Ability.CastStyle.CHARGE_UP))
	_check("style tags match cast_style (Judgement: channel)", styles_match, true)
	_check("the old tags stay (area, buff, movement)",
		[&"area" in CLEAVE.tags, &"buff" in IRON_RESOLVE.tags, &"movement" in LUNGE.tags, &"area" in SLAM.tags], [true, true, true, true])
	var dummy := _dummy_at(Vector2(300, 0))
	var hit := HitPipeline.from_ability(knight, CLEAVE, dummy)
	_check("Cleave's hits carry core, cone and area", [hit.has_tag(&"core"), hit.has_tag(&"cone"), hit.has_tag(&"area")], [true, true, true])
	var src := &"item_test_core"
	knight.stats_component.add_modifier(StatModifier.create(&"base_damage", StatModifier.Type.FLAT, 10.0, src, &"tag:core"))
	_check("+10 base damage to core abilities: Cleave and the slam yes, Lunge no",
		[CLEAVE.get_param(knight, &"base_damage"), SLAM.get_param(knight, &"base_damage"), LUNGE.get_param(knight, &"base_damage")],
		[90.0, 110.0, 50.0])
	knight.stats_component.remove_modifiers_from(src)
	dummy.queue_free()


# --- AB3 ------------------------------------------------------------------------

func _test_costs() -> void:
	_section("AB3: costs")
	await _reset_knight()
	var pool := knight.resource_pool
	_check("every ability costs 0 by default (room_01 plays as before)",
		[CLEAVE.resource_cost, IRON_RESOLVE.resource_cost, LUNGE.resource_cost, JUDGEMENT.resource_cost, SLAM.resource_cost],
		[0.0, 0.0, 0.0, 0.0, 0.0])
	pool.restore(1000.0)
	_check("the Knight has 300 mana", [pool.current, pool.max_resource], [300.0, 300.0])
	await _wait_until(func() -> bool: return knight.abilities.can_cast(&"q"), 240)
	knight.abilities.try_cast(&"q", knight.global_position + Vector2(40, 0))
	_check("a free cast spends nothing", pool.current, 300.0)
	await _wait_until(func() -> bool: return not knight.abilities.casting, 60)

	_add_costs({&"knight_cleave": 40.0, &"knight_lunge": 50.0, &"knight_judgement": 80.0})
	_check("scoped costs: Cleave 40, Lunge 50, Judgement 80",
		[knight.abilities.get_cost(CLEAVE), knight.abilities.get_cost(LUNGE), knight.abilities.get_cost(JUDGEMENT)], [40.0, 50.0, 80.0])
	var probe: Ability = CLEAVE.duplicate()
	probe.description = "costs {cost}"
	_check("{cost} in a tooltip", probe.get_tooltip_plain(knight), "costs 40")

	var dummy := _dummy_at(Vector2(80, 0))
	pool.restore(1000.0)
	knight.abilities.try_cast(&"r", dummy.global_position, dummy)
	_check("paid at cast start: 300 - 80 = 220", pool.current, 220.0)
	await _frames(6)
	knight.apply_stun(0.1)
	_check_near("stunned in the cast time: the 80 comes back", pool.current, 300.0, 0.001)
	await _wait_until(func() -> bool: return not knight.is_stunned(), 30)
	pool.try_spend(100.0)
	var before := pool.current
	knight.abilities.try_cast(&"r", dummy.global_position, dummy)
	await _frames(3)
	knight.abilities.try_cancel_cast_on_move()
	_check_near("a move cancel refunds it too", pool.current, before + 0.3, 0.2)   # + 3 frames of regen (6/s)
	await _wait_until(func() -> bool: return knight.abilities.can_cast(&"e"), 600)   # Lunge's 8 s cooldown from AB1
	pool.restore(1000.0)
	_check("Lunge casts (50 paid)", [knight.abilities.try_cast(&"e", knight.global_position + Vector2(100, 0)), pool.current], [true, 250.0])
	await _wait_until(func() -> bool: return knight.movement.is_displaced(), 10)
	knight.apply_stun(0.1)
	await _wait_until(func() -> bool: return not knight.abilities.casting, 60)
	_check("stunned once Lunge's effect started: no refund", pool.current < 260.0, true)

	# A unit without a resource pool pays nothing.
	var elite: Enemy = ELITE_SCENE.instantiate()
	elite.passive = true
	add_child(elite)
	_place(elite, knight.global_position + Vector2(0, 150))
	await _frames(1)
	elite.stats_component.add_modifier(StatModifier.create(&"resource_cost", StatModifier.Type.FLAT, 50.0, COST_SOURCE, &"ability:slime_elite_slam"))
	_check("the elite has no pool, so it can afford a 50 cost", [elite.resource_pool == null, elite.abilities.can_afford(&"q")], [true, true])
	_check("and casts it", elite.abilities.try_cast(&"q", elite.global_position + Vector2(20, 0)), true)
	elite.abilities.interrupt_cast()
	elite.queue_free()
	dummy.queue_free()
	await _reset_knight()


func _test_fail_cues() -> void:
	_section("AB3: not enough resource, fail reasons")
	await _reset_knight()
	var pool := knight.resource_pool
	var fails: Array = []
	var record := func(slot: StringName, reason: String) -> void: fails.append([slot, reason])
	knight.abilities.cast_failed.connect(record)
	await _wait_until(func() -> bool: return knight.abilities.can_cast(&"q"), 240)

	pool.try_spend(pool.current - 20.0)
	_check("20 mana: Cleave (40) can't be afforded", [knight.abilities.can_afford(&"q"), knight.abilities.get_fail_reason(&"q")],
		[false, AbilityComponent.FAIL_NO_RESOURCE])
	knight.request_cast(&"q")
	_check("the press fails at once with 'not enough resource'", fails, [[&"q", AbilityComponent.FAIL_NO_RESOURCE]])
	_check("and isn't buffered, nothing cast, nothing spent",
		[knight.player_input.get_buffered_action(), knight.abilities.casting], [&"", false])
	_check_near("mana still ~20", pool.current, 20.0, 0.2)
	fails.clear()
	_check("try_cast() refuses it the same way", knight.abilities.try_cast(&"q", knight.global_position + Vector2(40, 0)), false)
	_check("with the same reason", fails, [[&"q", AbilityComponent.FAIL_NO_RESOURCE]])

	# Blocked comes first: a stunned press is buffered (as before) and its cue is 'silenced'.
	fails.clear()
	knight.apply_stun(0.5)
	_check("stunned: the reason is 'silenced'", knight.abilities.get_fail_reason(&"q"), AbilityComponent.FAIL_SILENCED)
	knight.request_cast(&"q")
	_check("the press is buffered", knight.player_input.get_buffered_action(), &"q")
	await _frames(12)
	_check("the buffer runs out (0.15 s): cue 'silenced'", [fails, knight.player_input.get_buffered_action()],
		[[[&"q", AbilityComponent.FAIL_SILENCED]], &""])
	await _wait_until(func() -> bool: return not knight.is_stunned(), 60)

	# A press on cooldown: buffered, then 'not ready' when it runs out.
	pool.restore(1000.0)
	knight.abilities.try_cast(&"q", knight.global_position + Vector2(40, 0))
	await _wait_until(func() -> bool: return not knight.abilities.casting, 60)
	fails.clear()
	knight.request_cast(&"q")
	await _frames(12)
	_check("on cooldown: buffered, then cue 'not ready'", fails, [[&"q", AbilityComponent.FAIL_NOT_READY]])
	knight.abilities.cast_failed.disconnect(record)


func _test_hud_cues() -> void:
	_section("AB3: the HUD resource bar and slot cues")
	var hud: CanvasLayer = HUD_SCENE.instantiate()
	add_child(hud)
	hud.setup_abilities(knight)
	await _frames(1)
	var bar: Control = hud.get_node_or_null("AbilityBar")
	var resource_bar: Control = hud.get_node_or_null("ResourceBar")
	_check("the HUD has an ability bar and a resource bar (the Knight has mana)", [bar != null, resource_bar != null], [true, true])
	if bar == null or resource_bar == null:
		return
	knight.abilities.fail_cast(&"q", AbilityComponent.FAIL_NO_RESOURCE)
	_check("'not enough resource': the resource bar flashes, the slot doesn't",
		[resource_bar.is_flashing(), bar.is_flashing(&"q")], [true, false])
	knight.abilities.fail_cast(&"e", AbilityComponent.FAIL_NOT_READY)
	_check("'not ready': the slot flashes", bar.is_flashing(&"e"), true)
	await _frames(14)
	_check("both flashes are over after 0.2 s", [resource_bar.is_flashing(), bar.is_flashing(&"e")], [false, false])
	hud.queue_free()
	knight.stats_component.remove_modifiers_from(COST_SOURCE)
	knight.resource_pool.restore(1000.0)


func _add_costs(costs: Dictionary) -> void:
	for id: StringName in costs:
		knight.stats_component.add_modifier(StatModifier.create(&"resource_cost",
			StatModifier.Type.FLAT, costs[id], COST_SOURCE, StringName("ability:" + id)))


# --- Helpers ------------------------------------------------------------------

func _reset_knight() -> void:
	knight.abilities.interrupt_cast()
	knight.abilities.cancel_pending()
	knight.attack.cancel_swing()
	await _wait_until(func() -> bool: return not knight.is_stunned() and not knight.movement.is_displaced(), 120)
	await _frames(2)
	_place(knight, ARENA)
	knight.health.heal(10000.0)
	await _frames(1)


func _dummy_at(offset: Vector2) -> Enemy:
	var dummy: Enemy = SLIME_SCENE.instantiate()
	dummy.passive = true
	add_child(dummy)
	_place(dummy, knight.global_position + offset)
	return dummy


func _find_telegraph() -> Telegraph:
	for n in get_children():
		if n is Telegraph and not n.is_queued_for_deletion():
			return n
	return null


func _action(action: StringName, pressed: bool) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	return ev


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


func _check_near(label: String, actual: float, expected: float, tolerance: float) -> void:
	_report(absf(actual - expected) <= tolerance, label, "got %s, expected %s ± %s" % [actual, expected, tolerance])


func _report(ok: bool, label: String, detail: String) -> void:
	if ok:
		_passed += 1
		print("  PASS  %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s  (%s)" % [label, detail])
