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
## AB4: charges (max_charges 1 = the old cooldown, a scoped +1 gives two casts
## back to back, one recharge at a time, the ready ping only at 0 -> 1, a
## lowered max keeping extra charges, refunds giving the charge back).
## AB5: recasts (test_triple_step: parts 0-1-2, the window restarting after
## each part and not running during one, the cooldown starting after the
## last part or when the window runs out, part costs, refunds, a recast
## pressed during a cast time firing from the buffer).
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
const TRIPLE_STEP: Ability = preload("res://data/abilities/test_q_triple_step.tres")
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
	print("\n=== Abilities test (ABILITIES AB4) ===")
	await _test_charges()
	print("\n=== Abilities test (ABILITIES AB5) ===")
	await _test_recasts()
	await _test_recast_edges()
	print("=== %d passed, %d failed ===\n" % [_passed, _failed])

	# A sound still playing at quit prints a harmless leak warning (AUDIO.md).
	Audio.stop_all()
	await _frames(10)
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


# --- AB4 ------------------------------------------------------------------------

func _test_charges() -> void:
	_section("AB4: charges")
	await _reset_knight()
	var ab := knight.abilities
	_check("every ability has 1 charge by default",
		[CLEAVE.max_charges, IRON_RESOLVE.max_charges, LUNGE.max_charges, JUDGEMENT.max_charges, SLAM.max_charges], [1, 1, 1, 1, 1])
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 240)
	_check("the Knight's Q: 1 of 1", [ab.get_charges(&"q"), ab.get_max_charges(&"q")], [1, 1])

	# A quick test ability on Q: 0.5 s cooldown, no cast time.
	var quick: Ability = CLEAVE.duplicate()
	quick.id = &"test_charges"
	quick.cooldown = 0.5
	quick.cast_time = 0.0
	var original_q := ab.q
	ab.q = quick
	var ready_count := [0]
	var changes: Array = []
	var on_ready := func(slot: StringName, _a: Ability) -> void:
		if slot == &"q":
			ready_count[0] += 1
	var on_changed := func(slot: StringName, charges: int, maximum: int) -> void:
		if slot == &"q":
			changes.append([charges, maximum])
	ab.cooldown_finished.connect(on_ready)
	ab.charges_changed.connect(on_changed)
	var aim := knight.global_position + Vector2(40, 0)

	# max_charges 1 works exactly like the old cooldown.
	ab.try_cast(&"q", aim)
	_check("1 charge: cast -> 0, not ready, a 0.5 s timer",
		[ab.get_charges(&"q"), ab.is_ready(&"q"), snappedf(ab.get_cooldown_left(&"q"), 0.001)], [0, false, 0.5])
	var frames := 0
	while not ab.is_ready(&"q") and frames < 60:
		await get_tree().physics_frame
		frames += 1
	_check("ready again after 0.5 s (30-31 frames), one cooldown_finished", [frames >= 30 and frames <= 31, ready_count[0]], [true, 1])
	_check("charges_changed: 0, then 1", changes, [[0, 1], [1, 1]])

	# +1 charge from a scoped modifier (like an item).
	var item := &"item_test_charges"
	knight.stats_component.add_modifier(StatModifier.create(&"max_charges", StatModifier.Type.FLAT, 1.0, item, &"ability:test_charges"))
	_check("+1 max_charges: 1 of 2, and the second charge starts recharging",
		[ab.get_charges(&"q"), ab.get_max_charges(&"q")], [1, 2])
	await _frames(32)
	_check("0.5 s later: 2 of 2, no ready ping (it wasn't at 0)", [ab.get_charges(&"q"), ready_count[0]], [2, 1])
	_check("{charges} in a tooltip", _with_description(quick, "{charges} charges").get_tooltip_plain(knight), "2 charges")

	# Two casts back to back; charges come back one at a time.
	ab.try_cast(&"q", aim)
	_check("first cast: 1 left, still ready", [ab.get_charges(&"q"), ab.is_ready(&"q")], [1, true])
	ab.try_cast(&"q", aim)
	_check("second cast right after: 0 left, the running timer isn't restarted",
		[ab.get_charges(&"q"), ab.is_ready(&"q"), snappedf(ab.get_cooldown_left(&"q"), 0.001)], [0, false, 0.5])
	await _frames(31)
	_check("0.5 s: one charge back (0 -> 1 pings once), the next one recharging",
		[ab.get_charges(&"q"), ready_count[0], ab.get_cooldown_left(&"q") > 0.4], [1, 2, true])
	await _frames(31)
	_check("1 s: both back, no second ping", [ab.get_charges(&"q"), ready_count[0], ab.get_cooldown_left(&"q")], [2, 2, 0.0])

	# Removing the item leaves the extra charge until it's spent.
	knight.stats_component.remove_modifiers_from(item)
	await _frames(1)
	_check("item removed at 2 charges: max 1, the 2 stay, nothing recharges",
		[ab.get_max_charges(&"q"), ab.get_charges(&"q"), ab.get_cooldown_left(&"q")], [1, 2, 0.0])
	ab.try_cast(&"q", aim)
	_check("spend one: 1 left (at max: no timer)", [ab.get_charges(&"q"), ab.get_cooldown_left(&"q")], [1, 0.0])
	ab.try_cast(&"q", aim)
	_check("spend the other: 0, the recharge starts", [ab.get_charges(&"q"), snappedf(ab.get_cooldown_left(&"q"), 0.001)], [0, 0.5])
	await _wait_until(func() -> bool: return ab.is_ready(&"q"), 60)

	# Refunds give the charge back.
	var slow: Ability = quick.duplicate()
	slow.cast_time = 0.3
	ab.q = slow
	knight.stats_component.add_modifier(StatModifier.create(&"max_charges", StatModifier.Type.FLAT, 1.0, item, &"ability:test_charges"))
	await _wait_until(func() -> bool: return ab.get_charges(&"q") == 2, 60)
	var pings: int = ready_count[0]
	ab.try_cast(&"q", aim)
	await _frames(3)
	knight.apply_stun(0.1)
	_check("full, cast, stunned in the cast time: back to 2, no timer, no ping",
		[ab.get_charges(&"q"), ab.get_cooldown_left(&"q"), ready_count[0]], [2, 0.0, pings])
	await _wait_until(func() -> bool: return not knight.is_stunned(), 30)
	ab.try_cast(&"q", aim)
	await _wait_until(func() -> bool: return not ab.casting, 30)   # 1 left, recharging
	await _frames(6)
	var left := ab.get_cooldown_left(&"q")
	ab.try_cast(&"q", aim)
	await _frames(3)
	knight.apply_stun(0.1)
	_check("1 left and recharging, cast, stunned: 1 again, the recharge kept its progress",
		[ab.get_charges(&"q"), ab.get_cooldown_left(&"q") < left, ab.get_cooldown_left(&"q") > 0.0], [1, true, true])

	knight.stats_component.remove_modifiers_from(item)
	ab.cooldown_finished.disconnect(on_ready)
	ab.charges_changed.disconnect(on_changed)
	await _wait_until(func() -> bool: return not knight.is_stunned(), 30)
	await _wait_until(func() -> bool: return ab.get_charges(&"q") >= 1, 60)
	ab.q = original_q


# --- AB5 ------------------------------------------------------------------------

func _test_recasts() -> void:
	_section("AB5: recasts (test_triple_step)")
	await _reset_knight()
	var ab := knight.abilities
	_check("no ability has recasts by default",
		[CLEAVE.recast_count, IRON_RESOLVE.recast_count, LUNGE.recast_count, JUDGEMENT.recast_count, SLAM.recast_count], [0, 0, 0, 0, 0])
	_check("Triple Step: 2 recasts, 3 s window, 4 s cooldown, a mobility role",
		[TRIPLE_STEP.recast_count, TRIPLE_STEP.recast_window, TRIPLE_STEP.cooldown, TRIPLE_STEP.get_role()], [2, 3.0, 4.0, &"mobility"])
	_check("its tooltip", TRIPLE_STEP.get_tooltip_plain(knight),
		"Step 150 units toward the cursor. Recast up to 2 times within 3s each; the last step goes farther.")
	var original_q := ab.q
	ab.q = TRIPLE_STEP
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 300)
	var parts: Array[int] = []
	var windows: Array = []
	var finished := [0]
	var on_started := func(slot: StringName, _a: Ability, ctx: CastContext) -> void:
		if slot == &"q":
			parts.append(ctx.part)
	var on_window := func(slot: StringName, part: int, time: float) -> void:
		if slot == &"q":
			windows.append([part, time])
	var on_finished := func(slot: StringName) -> void:
		if slot == &"q":
			finished[0] += 1
	ab.cast_started.connect(on_started)
	ab.recast_window_started.connect(on_window)
	ab.recast_window_finished.connect(on_finished)

	var start := knight.global_position
	var aim := start + Vector2(300, 0)
	ab.try_cast(&"q", aim)
	_check("part 0 takes the charge; the cooldown doesn't start yet",
		[ab.get_charges(&"q"), ab.get_cooldown_left(&"q"), ab.get_recast_part(&"q")], [0, 0.0, 1])
	await _wait_until(func() -> bool: return not ab.casting, 30)
	_check_near("stepped 48 px", knight.global_position.x - start.x, 48.0, 1.0)
	_check("the window opens for part 1 (3 s)", [windows, ab.is_ready(&"q")], [[[1, 3.0]], true])
	await _frames(30)
	_check_near("0.5 s later it has 2.5 s left", ab.get_recast_time_left(&"q"), 2.5, 0.02)
	_check("still no cooldown running", ab.get_cooldown_left(&"q"), 0.0)
	var x1 := knight.global_position.x
	ab.try_cast(&"q", knight.global_position + Vector2(300, 0))
	await _wait_until(func() -> bool: return not ab.casting, 30)
	_check_near("part 1 steps 48 px", knight.global_position.x - x1, 48.0, 1.0)
	_check("the window restarts for part 2", windows.back(), [2, 3.0])
	var x2 := knight.global_position.x
	ab.try_cast(&"q", knight.global_position + Vector2(300, 0))
	await _wait_until(func() -> bool: return not ab.casting, 30)
	_check_near("part 2 (the last) steps 72 px", knight.global_position.x - x2, 72.0, 1.0)
	_check("parts 0, 1, 2", parts, [0, 1, 2] as Array[int])
	await _frames(1)
	_check("the sequence ends once: no window, the 4 s cooldown starts",
		[finished[0], ab.get_recast_part(&"q"), ab.is_ready(&"q"), ab.get_cooldown_left(&"q") > 3.9], [1, 0, false, true])

	# The window running out also ends it.
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 300)
	ab.try_cast(&"q", knight.global_position + Vector2(-300, 0))
	await _wait_until(func() -> bool: return not ab.casting, 30)
	await _frames(185)
	_check("3 s without a press: the sequence ends, the cooldown runs",
		[finished[0], ab.get_recast_part(&"q"), ab.is_ready(&"q"), ab.get_cooldown_left(&"q") > 0.0], [2, 0, false, true])

	ab.cast_started.disconnect(on_started)
	ab.recast_window_started.disconnect(on_window)
	ab.recast_window_finished.disconnect(on_finished)
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 300)
	ab.q = original_q


func _test_recast_edges() -> void:
	_section("AB5: recast costs, refunds, the paused window, a buffered recast")
	await _reset_knight()
	var ab := knight.abilities
	var pool := knight.resource_pool
	var slow: Ability = TRIPLE_STEP.duplicate()
	slow.cast_time = 0.3
	slow.recast_window = 1.0
	slow.resource_cost = 30.0
	slow.recast_resource_cost = 10.0
	var original_q := ab.q
	ab.q = slow
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 300)
	pool.restore(1000.0)
	var aim := knight.global_position + Vector2(300, 0)

	# Part 0 interrupted: charge and cost back, no sequence.
	ab.try_cast(&"q", aim)
	_check("part 0 costs resource_cost (30)", pool.current, 270.0)
	await _frames(3)
	knight.apply_stun(0.1)
	_check("stunned in part 0's cast time: charge and 30 back, no window",
		[ab.get_charges(&"q"), ab.get_recast_part(&"q"), pool.current], [1, 0, 300.0])
	await _wait_until(func() -> bool: return not knight.is_stunned(), 30)

	# Part 0 done; the window doesn't run during part 1's cast time.
	ab.try_cast(&"q", aim)
	await _wait_until(func() -> bool: return not ab.casting, 60)
	await _frames(12)   # 0.2 s of the 1 s window
	var before := pool.current
	ab.try_cast(&"q", aim)
	_check_near("part 1 costs recast_resource_cost (10)", pool.current, before - 10.0, 0.05)
	var after_pay := pool.current
	var left := ab.get_recast_time_left(&"q")
	await _frames(12)
	_check("during part 1's 0.3 s cast time the window doesn't run", ab.get_recast_time_left(&"q"), left)
	knight.apply_stun(0.1)
	_check_near("stunned in part 1: its 10 back (+ 0.2 s of regen)", pool.current - after_pay, 11.2, 0.05)
	_check("the sequence stays at part 1 with the time it had",
		[ab.get_recast_part(&"q"), ab.get_recast_time_left(&"q"), ab.get_charges(&"q")], [1, left, 0])
	await _wait_until(func() -> bool: return not knight.is_stunned(), 30)

	# A recast pressed during the cast time fires from the buffer.
	ab.try_cast(&"q", aim)   # part 1 again
	await _frames(3)
	knight.request_cast(&"q")
	_check("pressed during part 1's cast time: buffered", knight.player_input.get_buffered_action(), &"q")
	await _wait_until(func() -> bool: return ab.get_recast_part(&"q") == 0, 90)
	_check("it fired as part 2 when part 1 finished; the sequence is over", [ab.get_recast_part(&"q"), ab.is_ready(&"q")], [0, false])

	await _wait_until(func() -> bool: return not ab.casting and ab.can_cast(&"q"), 300)
	ab.q = original_q
	pool.restore(1000.0)


func _with_description(ability: Ability, text: String) -> Ability:
	var copy: Ability = ability.duplicate()
	copy.description = text
	return copy


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
