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
## AB6: charge-up (test_charged_line: the cost at charge start, the charge and
## cooldown at release, walking at 0.6, range and damage growing with the
## charge, a tap, overhold FIRE and CANCEL_REFUND, Esc, a stun and a dash
## cancelling with refunds, the Player's hold and release, a lost release, a
## buffered press whose key was let go firing as a tap).
## AB7: projectiles (WorldQuery.shape_sweep, test_bolt: travel time, pierce
## 0 and 2, walls and ignores_walls, range, +2 projectiles fanned out with one
## crit roll, only the other team is hit, a caster freed mid-flight).
## AB8: augments (FLAG with snapshot, tag scope, the exact-scope error, two
## sources; REPLACE mid-cooldown / mid-cast / mid-charge-up / mid-recast,
## a second one disabled, variant_of; EVENT rules once per id), ability_cast
## at the effect start, the four GameplayEffects, status rules, free casts
## (timing, no cost, no interruption, chain limits, the HIT loop), and a fake
## item that restores everything exactly when unequipped.
## AB13: VECTOR (test_vector_line: the start point with its range and wall
## clamps, a drag and a tap, vector_drag, the hold limit and the orange bar,
## every exit clearing the indicator, the Player's press and release, a
## buffered press, aimed recast parts, try_cast / try_cast_vector / a free
## cast / a hold-to-aim slot that became VECTOR; test_vector_wall on the elite:
## get_ai_vector(), Telegraph.line(), the hit, a stun mid-cast).
## AB-M: the augment playground's four fake items on the real Knight (Lunge
## stuns, Cleave Wave, a Judgement kill resetting it, Cleave also casting a
## free Lunge) and SandboxAugments (keys 1-4, unequipping restores exactly).
## Cleanup pass (2026-09-29): the enemy AI skipping a slot that fails its
## condition; a conditional bonus widening and lengthening a VECTOR line
## (get_effect_param()).
## AB14 / AB14b: every cast's effect on the frame its cast time's tick count
## gives (the nominal count, no extra tick, from each cast_time; a cast started at a frame's start, in the
## node pass and between frames, a cast chained from another's end); cast
## progress and the cast speed; telegraphs following their cast; the
## presentation hooks empty (nothing happens) and filled (a test hook scene:
## cast, impact, projectile, free cast, swing; blocked hits skipped); cast_anim
## and swing_anim positioned by progress, stopped by a cancel.
## The Knight's own crit_chance and life_steal are held at 0 by a test
## baseline, so damage checks are exact.
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
const CHARGED_LINE: Ability = preload("res://data/abilities/test_q_charged_line.tres")
## A looping SoundEvent to stand in for a charging sound (AB6 exits).
const LOOP_SOUND: SoundEvent = preload("res://data/sounds/sound_knight_low_health.tres")
const BOLT: Ability = preload("res://data/abilities/test_q_bolt.tres")
const STRIKE: Ability = preload("res://data/abilities/test_q_strike.tres")
const STATUS_SLOW: StatusEffect = preload("res://data/statuses/status_slow.tres")
const NOVA: Ability = preload("res://data/abilities/test_q_nova.tres")
const MARK_STRIKE: Ability = preload("res://data/abilities/test_q_mark_strike.tres")
const STATUS_FOCUS: StatusEffect = preload("res://data/statuses/status_test_focus.tres")
const STATUS_MARK: StatusEffect = preload("res://data/statuses/status_test_mark.tres")
const EXECUTE_RULE: ReactionRule = preload("res://data/reactions/reaction_test_execute.tres")
const VECTOR_LINE: Ability = preload("res://data/abilities/test_q_vector_line.tres")
const VECTOR_WALL: Ability = preload("res://data/abilities/test_w_vector_wall.tres")
const CLEAVE_WAVE: Ability = preload("res://data/abilities/knight_q_cleave_wave.tres")
const AUG_LUNGE_STUNS: AbilityAugment = preload("res://data/augments/augment_lunge_stuns.tres")
const AUG_CLEAVE_WAVE: AbilityAugment = preload("res://data/augments/augment_cleave_wave.tres")
const AUG_JUDGEMENT_RESET: AbilityAugment = preload("res://data/augments/augment_judgement_reset.tres")
const AUG_CLEAVE_CASTS_LUNGE: AbilityAugment = preload("res://data/augments/augment_cleave_casts_lunge.tres")
const SANDBOX_AUGMENTS: Script = preload("res://scripts/rooms/sandbox_augments.gd")
const HOOK_PROBE: Script = preload("res://scripts/tests/hook_vfx_probe.gd")
const COMBO_KNIGHT: AttackCombo = preload("res://data/combos/combo_knight.tres")
const ARENA := Vector2(-2000, 0)


## Runs `fn` once from its own _physics_process (AB14: a cast started in the
## node pass, after the units' components have run this frame).
class PhysicsCaller extends Node:
	var fn: Callable

	func _physics_process(_delta: float) -> void:
		if fn.is_valid():
			var f := fn
			fn = Callable()
			f.call()

var knight: Player

var _passed: int = 0
var _failed: int = 0
var _shakes: Array[float] = []   # GameFeel.shake() amounts seen by _spy_camera() (AB11)
var _finished: int = 0
var _cancelled: int = 0


func _ready() -> void:
	knight = PLAYER_SCENE.instantiate()
	add_child(knight)
	_place(knight, ARENA)
	knight.abilities.cast_finished.connect(func(_s: StringName, _a: Ability) -> void: _finished += 1)
	knight.abilities.cast_cancelled.connect(func(_s: StringName, _a: Ability) -> void: _cancelled += 1)
	await get_tree().physics_frame
	# The test baseline: the Knight's own crit_chance and life_steal
	# (knight.tres) back to 0, so damage checks are exact; a check that wants
	# crits adds them itself.
	for stat: StringName in [&"crit_chance", &"life_steal"]:
		var base := knight.stats_component.get_base_value(stat)
		if base != 0.0:
			knight.stats_component.add_modifier(StatModifier.create(stat, StatModifier.Type.FLAT, -base, &"test_baseline"))
	_pool_baseline(knight)

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
	print("\n=== Abilities test (ABILITIES AB6) ===")
	await _test_charge_up()
	await _test_charge_up_ends()
	await _test_charge_up_input()
	await _test_charge_up_exits()
	await _test_release_windup()
	print("\n=== Abilities test (ABILITIES AB7) ===")
	await _test_shape_sweep()
	await _test_projectiles()
	await _test_projectile_spread_and_teams()
	await _test_projectile_orphaned()
	print("\n=== Abilities test (ABILITIES AB8) ===")
	await _test_augment_flag()
	await _test_augment_replace()
	await _test_ability_cast_event()
	await _test_augment_event()
	await _test_gameplay_effects()
	await _test_free_casts()
	await _test_fake_item()
	await _test_forms()
	await _test_empower_basic_attack()
	await _test_empower_abilities()
	await _test_unstoppable()
	await _test_untargetable()
	await _test_untargetable_enemy_ai()
	await _test_ab11_cleave()
	await _test_ab11_lunge()
	await _test_ab11_judgement()
	await _test_ab11_iron_resolve()
	_test_ab11_scripts()
	_test_ab12_condition_kinds()
	await _test_ab12_cast_condition()
	await _test_ab12_bonus_and_input()
	await _test_ab12_condition_target()
	await _test_ab12_recast()
	await _test_ab12_reaction_condition()
	print("\n=== Abilities test (ABILITIES AB13) ===")
	await _reset_knight()
	_test_ab13_data()
	await _test_ab13_drag_and_tap()
	await _test_ab13_start_point()
	await _test_ab13_hold_limit()
	await _test_ab13_exits()
	await _test_ab13_player_input()
	await _test_ab13_recast()
	await _test_ab13_without_mouse()
	await _test_ab13_enemy()
	await _test_enemy_skips_failing_slot()
	await _test_bonus_widens_and_lengthens_vector()
	print("\n=== Abilities test (ABILITIES AB-M) ===")
	_test_abm_data()
	await _test_abm_lunge_stuns()
	await _test_abm_cleave_wave()
	await _test_abm_judgement_reset()
	await _test_abm_cleave_casts_lunge()
	await _test_abm_playground()
	print("\n=== Abilities test (ABILITIES AB14) ===")
	await _test_ab14_regression()
	await _test_ab14_chained_cast()
	await _test_ab14_progress()
	await _test_ab14_telegraph()
	await _test_ab14_hooks_empty()
	await _test_ab14_hooks_fire()
	await _test_ab14_anims()
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
	_check("the same as get_damage_against() and get_damage() + the term",
		[JUDGEMENT.get_damage_against(knight, dummy), JUDGEMENT.get_damage(knight) + term.ratio * term.get_amount(knight, dummy)],
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
	_check("Cleave (and its 80 base, not the old 70)", _template_line(CLEAVE.get_tooltip_plain(knight)),
		"Sweep your sword in a wide arc in front of you, dealing 125 physical damage (80 +70% AD) and knocking enemies back. Each cast that hits heals you for up to 55% of your missing health, more the lower your health.")
	_check("Iron Resolve (percents with {x%})", IRON_RESOLVE.get_tooltip_plain(knight),
		"Gain 35% movement speed for 2s. Your next attack within 4s deals 82 (50 +50% AD) bonus damage and slows the target by 40% for 1.5s.")
	_check("Lunge ({range})", _template_line(LUNGE.get_tooltip_plain(knight)),
		"Dash up to 400 units toward the target spot, passing through units and dealing 82 physical damage (50 +50% AD) to every enemy you cut through.")
	_check("Judgement (the target term as text)", _template_line(JUDGEMENT.get_tooltip_plain(knight)),
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
	probe.conditional_bonuses = []   # only the template (CH4 gave Cleave a bonus line)
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
	_check("costs in the data: Cleave 20 fury (CHAMPIONS CH3), the others 0",
		[CLEAVE.resource_cost, IRON_RESOLVE.resource_cost, LUNGE.resource_cost, JUDGEMENT.resource_cost, SLAM.resource_cost],
		[20.0, 0.0, 0.0, 0.0, 0.0])
	_check("the test baseline cancels Cleave's: it costs 0 here", knight.abilities.get_cost(CLEAVE), 0.0)
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
	probe.conditional_bonuses = []   # only the template (CH4 gave Cleave a bonus line)
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


# --- AB6 ------------------------------------------------------------------------

## The charged line on Q with a scoped 40 cost; returns the original Q.
func _setup_charged_line(ability: Ability) -> Ability:
	await _reset_knight()
	var original_q := knight.abilities.q
	knight.abilities.q = ability
	knight.stats_component.remove_modifiers_from(COST_SOURCE)
	_add_costs({&"test_charged_line": 40.0})
	await _wait_until(func() -> bool: return knight.abilities.can_cast(&"q"), 300)
	knight.resource_pool.restore(1000.0)
	return original_q


func _test_charge_up() -> void:
	_section("AB6: charge-up (test_charged_line)")
	var ab := knight.abilities
	var pool := knight.resource_pool
	_check("no Knight ability or the slam is a charge-up",
		[CLEAVE.cast_style, IRON_RESOLVE.cast_style, LUNGE.cast_style, JUDGEMENT.cast_style, SLAM.cast_style].has(Ability.CastStyle.CHARGE_UP), false)
	var s := ChargeScaling.new()
	s.min_fraction = 0.4
	_check("ChargeScaling 40%: x0.4 at a tap, x0.7 half way, x1 full", [s.get_multiplier(0.0), s.get_multiplier(0.5), s.get_multiplier(1.0)], [0.4, 0.7, 1.0])
	_check("the line: range 440 at a tap, 1100 full; damage 59.2 to 118.4 (AD 64)",
		[CHARGED_LINE.get_charged_param(knight, &"cast_range", 0.0), CHARGED_LINE.get_charged_param(knight, &"cast_range", 1.0),
			CHARGED_LINE.get_damage_against(knight, null, 0.0), CHARGED_LINE.get_damage_against(knight, null, 1.0)],
		[440.0, 1100.0, 59.2, 118.4])
	_check("its tooltip (min-max)", CHARGED_LINE.get_tooltip_plain(knight),
		"Hold to charge a line: 440-1100 units, 59-118 magic damage (80 +60% AD at full charge) to every enemy on it. Full charge takes 1.5s; held 2s longer, it fires on its own.")
	_check("the role and style tags", [CHARGED_LINE.get_role(), &"charge_up" in CHARGED_LINE.tags], [&"core", true])

	var original_q: Ability = await _setup_charged_line(CHARGED_LINE)
	var released: Array = []
	var on_released := func(slot: StringName, _a: Ability, charge: float) -> void:
		if slot == &"q":
			released.append(charge)
	ab.charge_released.connect(on_released)
	var hits: Array[HitContext] = []
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.ability != null and ctx.ability.id == &"test_charged_line":
			hits.append(ctx)
	Events.unit_hit.connect(on_hit)
	var far := _dummy_at(Vector2(200, 0))
	var aim := knight.global_position + Vector2(300, 0)

	_check("press: charging starts", ab.try_start_charge(&"q", aim), true)
	_check("casting and charging at 0; the 40 is paid now; no charge or cooldown taken yet",
		[ab.casting, ab.is_charging(), ab.get_charge(), pool.current, ab.get_charges(&"q"), ab.get_cooldown_left(&"q")],
		[true, true, 0.0, 260.0, 1, 0.0])
	_check("walking while charging: not rooted, at x0.6 (one move_speed modifier)",
		[knight.movement.can_move(), knight.stats_component.get_modifiers_from(AbilityComponent.CAST_MOVE_SPEED_SOURCE).size()], [true, 1])
	await _frames(45)
	_check_near("0.75 s held: half charged", ab.get_charge(), 0.5, 0.02)
	_check_near("the indicator's range grows with it (x0.7 = 770)", CHARGED_LINE.get_charged_param(knight, &"cast_range"), 770.0, 15.0)
	ab.release_charge(aim)
	var c: float = released[0] if not released.is_empty() else -1.0
	_check("release: the charge and the 3 s cooldown are taken; the 0.3 s release windup starts",
		[ab.casting, ab.is_charging(), ab.get_charges(&"q"), snappedf(ab.get_cooldown_left(&"q"), 0.01), hits.size()], [true, false, 0, 3.0, 0])
	await _wait_until(func() -> bool: return not ab.casting, 40)
	_check("after the windup the effect ran; the walking modifier is gone",
		[ab.casting, knight.stats_component.get_modifiers_from(AbilityComponent.CAST_MOVE_SPEED_SOURCE).size()], [false, 0])
	_check("the dummy 200 px away is hit (the line reaches ~246 px)", hits.size(), 1)
	if not hits.is_empty():
		_check_near("damage at that charge: 118.4 x (0.5 + 0.5 x charge)", hits[0].raw_damage, 118.4 * (0.5 + 0.5 * c), 0.01)
		_check("magic, tagged line and charge_up", [hits[0].damage_type, hits[0].has_tag(&"line"), hits[0].has_tag(&"charge_up")],
			[HitContext.DamageType.MAGIC, true, true])

	# A tap: charge 0, the short weak line.
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 300)
	hits.clear()
	var near := _dummy_at(Vector2(100, 40))
	ab.try_start_charge(&"q", aim)
	ab.release_charge(near.global_position)
	_check("a tap fires at charge 0", released.back(), 0.0)
	await _wait_until(func() -> bool: return not ab.casting, 40)
	_check("only the near dummy is hit (440 u = 141 px), for 59.2", [hits.size(), hits[0].raw_damage if hits.size() == 1 else -1.0, hits[0].target == near if hits.size() == 1 else false],
		[1, 59.2, true])

	ab.charge_released.disconnect(on_released)
	Events.unit_hit.disconnect(on_hit)
	far.queue_free()
	near.queue_free()
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 300)
	ab.q = original_q


func _test_charge_up_ends() -> void:
	_section("AB6: overhold, Esc, stun and dash")
	var ab := knight.abilities
	var pool := knight.resource_pool
	var original_q: Ability = await _setup_charged_line(CHARGED_LINE)
	var released: Array = []
	var on_released := func(_slot: StringName, _a: Ability, charge: float) -> void: released.append(charge)
	ab.charge_released.connect(on_released)
	var cancelled := [0]
	var on_cancelled := func(_slot: StringName, _a: Ability) -> void: cancelled[0] += 1
	ab.cast_cancelled.connect(on_cancelled)

	# Overhold FIRE: held 1.5 s + 2 s, it fires by itself at full charge.
	ab.try_start_charge(&"q", knight.global_position + Vector2(100, 0))
	await _frames(150)
	_check("after 2.5 s: full, still held, 1 s of overhold left",
		[ab.is_charging(), ab.get_charge(), snappedf(ab.get_overhold_left(), 0.05)], [true, 1.0, 1.0])
	await _frames(65)
	_check("after 3.5 s: fired by itself at full charge (FIRE)", [ab.is_charging(), released, ab.get_charges(&"q")], [false, [1.0], 0])

	# Overhold CANCEL_REFUND.
	var cancel_line: Ability = CHARGED_LINE.duplicate()
	cancel_line.overhold = Ability.Overhold.CANCEL_REFUND
	ab.q = cancel_line
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 300)
	pool.restore(1000.0)
	ab.try_start_charge(&"q", knight.global_position + Vector2(100, 0))
	await _frames(215)
	_check("CANCEL_REFUND: cancelled after 3.5 s, the 40 back, still ready, nothing fired",
		[ab.is_charging(), cancelled[0], pool.current, ab.is_ready(&"q"), released.size()], [false, 1, 300.0, true, 1])

	# Esc.
	ab.try_start_charge(&"q", knight.global_position + Vector2(100, 0))
	await _frames(10)
	_check("Esc (try_cancel_charge): cancelled, refunded, ready",
		[ab.try_cancel_charge(), ab.is_charging(), ab.casting, cancelled[0], ab.is_ready(&"q")], [true, false, false, 2, true])
	_check_near("mana back (+ a little regen)", pool.current, 300.0, 0.001)

	# A stun interrupts at once, refunded.
	ab.try_start_charge(&"q", knight.global_position + Vector2(100, 0))
	await _frames(10)
	knight.apply_stun(0.1)
	_check("stunned while charging: interrupted, refunded, ready",
		[ab.is_charging(), ab.casting, pool.current, ab.is_ready(&"q")], [false, false, 300.0, true])
	await _wait_until(func() -> bool: return not knight.is_stunned(), 30)

	# A dash cancels it (dash_cancelable), refunded.
	await _wait_until(func() -> bool: return knight.dash.can_dash(), 60)
	ab.try_start_charge(&"q", knight.global_position + Vector2(100, 0))
	await _frames(10)
	var dashed := knight.dash.try_dash(Vector2.DOWN)
	_check("a dash cancels it (dash_cancelable) and dashes; refunded",
		[dashed, ab.is_charging(), cancelled[0], pool.current, ab.is_ready(&"q")], [true, false, 3, 300.0, true])

	ab.charge_released.disconnect(on_released)
	ab.cast_cancelled.disconnect(on_cancelled)
	await _frames(20)
	ab.q = original_q


func _test_charge_up_input() -> void:
	_section("AB6: the Player's hold and release")
	var ab := knight.abilities
	var original_q: Ability = await _setup_charged_line(CHARGED_LINE)
	var released: Array = []
	var on_released := func(_slot: StringName, _a: Ability, charge: float) -> void: released.append(charge)
	ab.charge_released.connect(on_released)

	# Hold Q, let go: the cast mode doesn't matter for a charge-up.
	var mode := Settings.get_cast_mode()
	Settings.set_cast_mode(Player.CastMode.QUICK)
	Input.action_press(&"ability_q")
	knight._unhandled_input(_action(&"ability_q", true))
	_check("press Q: charging (quick cast mode or not)", [ab.is_charging(), knight.get_indicator_slot()], [true, &"q"])
	await _frames(30)
	_check("held 0.5 s: still charging", ab.is_charging(), true)
	Input.action_release(&"ability_q")
	knight._unhandled_input(_action(&"ability_q", false))
	_check("release Q: fired at ~1/3 charge", [ab.is_charging(), released.size(), absf(released[0] - 0.333) < 0.03 if released.size() == 1 else false],
		[false, 1, true])
	Settings.set_cast_mode(mode)

	# A release the game never saw (focus lost): the next frame releases it.
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 300)
	Input.action_press(&"ability_q")
	knight._unhandled_input(_action(&"ability_q", true))
	await _frames(5)
	Input.action_release(&"ability_q")   # no release event
	await _frames(2)
	_check("key no longer held: released by the next frame", [ab.is_charging(), released.size()], [false, 2])

	# "Not enough resource" fails at once, not buffered.
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 300)
	knight.resource_pool.try_spend(knight.resource_pool.current - 10.0)
	knight.request_charge(&"q")
	_check("10 mana, cost 40: no charge, not buffered", [ab.is_charging(), knight.player_input.get_buffered_action()], [false, &""])
	knight.resource_pool.restore(1000.0)

	# A press buffered during another cast whose key is let go before it fires: a tap.
	await _wait_until(func() -> bool: return ab.can_cast(&"e"), 600)
	ab.try_cast(&"e", knight.global_position + Vector2(0, 80))   # Lunge: a cast time and a dash
	knight.request_charge(&"q")
	_check("pressed during Lunge: buffered", knight.player_input.get_buffered_action(), &"q")
	await _wait_until(func() -> bool: return released.size() == 3, 60)
	_check("fired when Lunge ended, as a tap (charge 0; the key wasn't held)", [released.size(), released.back(), ab.is_charging()], [3, 0.0, false])

	ab.charge_released.disconnect(on_released)
	knight.stats_component.remove_modifiers_from(COST_SOURCE)
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 300)
	ab.q = original_q


## Every way a charge-up ends clears the indicator, the charge bar and the
## charging sound, through the one end-charge path (charge_ended once).
func _test_charge_up_exits() -> void:
	_section("AB6: every way a charge-up ends clears the indicator, the bar and the sound")
	var ab := knight.abilities
	var line: Ability = CHARGED_LINE.duplicate()   # same id: the scoped 40 cost applies
	line.charge_sound = LOOP_SOUND
	line.charge_time = 0.2
	line.overhold_time = 0.2
	var original_q: Ability = await _setup_charged_line(line)
	var hud: CanvasLayer = HUD_SCENE.instantiate()
	add_child(hud)
	hud.setup_abilities(knight)
	var bar: Control = hud.get_node("AbilityBar")
	var ended := [0]
	var on_ended := func(_slot: StringName, _a: Ability) -> void: ended[0] += 1
	ab.charge_ended.connect(on_ended)
	var aim := knight.global_position + Vector2(100, 0)

	# The exits. Each starts a charge, ends it one way (a method below), then checks.
	_exit_line = line
	_exit_aim = aim
	var exits := [
		["release (after its windup)", _exit_release],
		["overhold FIRE (after its windup)", _exit_overhold_fire],
		["overhold CANCEL_REFUND", _exit_overhold_cancel],
		["Esc", _exit_esc],
		["a stun", _exit_stun],
		["a dash", _exit_dash],
		["a move press (a channel charge-up)", _exit_move],
		["the slot swapped mid-charge (a REPLACE), then release", _exit_swap],
		["a lost key release (the Player's own charge)", _exit_lost_release],
	]
	for exit: Array in exits:
		var label: String = exit[0]
		await _wait_until(func() -> bool: return ab.can_cast(&"q") and not knight.is_stunned() and knight.dash.can_dash(), 400)
		knight.resource_pool.restore(1000.0)
		line.cancel_on_move = label.begins_with("a move press")
		if label.begins_with("a lost key"):
			Input.action_press(&"ability_q")
			knight._unhandled_input(_action(&"ability_q", true))
		else:
			ab.try_start_charge(&"q", aim)
		var handle: int = ab.get("_charge_sound_handle")
		await _frames(3)
		var showing := [ab.has_charge_indicator(), knight.get_indicator_slot(), knight._drawn_indicator_slot, bar._drawn_charge_bar_slot, Audio.is_playing(handle)]
		var before: int = ended[0]
		await (exit[1] as Callable).call()
		await _frames(2)
		_check("%s: shown while charging, then indicator, bar and sound gone, charge_ended once" % label,
			[showing, [ab.has_charge_indicator(), knight.get_indicator_slot(), knight._drawn_indicator_slot, bar._drawn_charge_bar_slot, Audio.is_playing(handle)], ended[0] - before],
			[[true, &"q", &"q", &"q", true], [false, &"", &"", &"", false], 1])
	line.cancel_on_move = false

	# Death (a second Knight, so this one lives on).
	var other: Player = PLAYER_SCENE.instantiate()
	add_child(other)
	_place(other, knight.global_position + Vector2(0, 300))
	await _frames(1)
	other.abilities.q = line
	var other_ended := [0]
	other.abilities.charge_ended.connect(func(_s: StringName, _a: Ability) -> void: other_ended[0] += 1)
	other.abilities.try_start_charge(&"q", other.global_position + Vector2(100, 0))
	var other_handle: int = other.abilities.get("_charge_sound_handle")
	await _frames(3)
	other.take_damage(100000.0)
	_check("death while charging: the charge ends at once, sound stopped, charge_ended once",
		[other.abilities.has_charge_indicator(), other.abilities.casting, Audio.is_playing(other_handle), other_ended[0]], [false, false, false, 1])

	ab.charge_ended.disconnect(on_ended)
	hud.queue_free()
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 300)
	ab.q = original_q


var _exit_line: Ability
var _exit_aim: Vector2


func _exit_release() -> void:
	knight.abilities.release_charge(_exit_aim)
	await _wait_until(func() -> bool: return not knight.abilities.casting, 40)


func _exit_overhold_fire() -> void:
	await _wait_until(func() -> bool: return not knight.abilities.casting, 60)


func _exit_overhold_cancel() -> void:
	_exit_line.overhold = Ability.Overhold.CANCEL_REFUND
	await _wait_until(func() -> bool: return not knight.abilities.casting, 60)
	_exit_line.overhold = Ability.Overhold.FIRE


func _exit_esc() -> void:
	knight._unhandled_input(_action(&"ui_cancel", true))


func _exit_stun() -> void:
	knight.apply_stun(0.1)
	await _wait_until(func() -> bool: return not knight.is_stunned(), 30)


func _exit_dash() -> void:
	knight.dash.try_dash(Vector2.UP)
	await _frames(20)


func _exit_move() -> void:
	knight.player_input._unhandled_input(_action(&"move_right", true))
	await _frames(1)
	knight.player_input._unhandled_input(_action(&"move_right", false))


func _exit_swap() -> void:
	knight.abilities.q = CLEAVE
	knight.abilities.release_charge(_exit_aim)
	await _wait_until(func() -> bool: return not knight.abilities.casting, 40)
	knight.abilities.q = _exit_line


func _exit_lost_release() -> void:
	Input.action_release(&"ability_q")   # no release event
	await _wait_until(func() -> bool: return not knight.abilities.casting, 40)

## CHARGE_UP's cast_time is the release windup: the aim and charge lock, the
## indicator stays (locked), the effect runs after it; a stun or dash in it
## refunds the cost and the cooldown.
func _test_release_windup() -> void:
	_section("AB6: the release windup (cast_time 0.3 s)")
	var ab := knight.abilities
	var pool := knight.resource_pool
	var original_q: Ability = await _setup_charged_line(CHARGED_LINE)
	_check("the test line's release windup is 0.3 s; every other ability's cast_time is unchanged",
		[CHARGED_LINE.cast_time, CLEAVE.cast_time], [0.3, 0.2])
	var hits: Array[HitContext] = []
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.ability != null and ctx.ability.id == &"test_charged_line":
			hits.append(ctx)
	Events.unit_hit.connect(on_hit)
	var started := [0]
	var on_started := func(slot: StringName, _a: Ability, _ctx: CastContext) -> void:
		if slot == &"q":
			started[0] += 1
	ab.cast_started.connect(on_started)
	var dummy := _dummy_at(Vector2(150, 0))
	var aim := knight.global_position + Vector2(300, 0)

	ab.try_start_charge(&"q", aim)
	await _frames(45)
	ab.set_charge_aim(aim)
	ab.release_charge(aim)
	var locked_charge := ab.get_charge()
	_check("release: cast_started now, the indicator stays, locked at the release aim",
		[started[0], ab.has_charge_indicator(), knight.get_indicator_slot(), ab.get_locked_charge_aim() == aim, knight.get_indicator_aim() == aim],
		[1, true, &"q", true, true])
	ab.set_charge_aim(aim + Vector2(0, 200))
	_check("the locked aim doesn't follow the cursor any more", ab.get_locked_charge_aim() == aim, true)
	_check_near("the indicator's range is the locked charge's", CHARGED_LINE.get_charged_param(knight, &"cast_range"),
		1100.0 * (0.4 + 0.6 * locked_charge), 0.5)
	_check("walking at x0.6 still applies in the windup", knight.stats_component.get_modifiers_from(AbilityComponent.CAST_MOVE_SPEED_SOURCE).size(), 1)
	await _frames(12)
	_check("0.2 s in: no hit yet", hits.size(), 0)
	await _wait_until(func() -> bool: return not ab.casting, 20)
	_check("after 0.3 s: the effect ran (hit), the indicator is gone", [hits.size(), ab.has_charge_indicator()], [1, false])

	# A stun in the windup: interrupted, cost and cooldown refunded.
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 300)
	pool.restore(1000.0)
	hits.clear()
	ab.try_start_charge(&"q", aim)
	await _frames(20)
	ab.release_charge(aim)
	await _frames(6)
	knight.apply_stun(0.1)
	_check("stunned in the windup: interrupted, the 40 and the charge back, no cooldown, no hit, indicator gone",
		[ab.casting, pool.current, ab.get_charges(&"q"), ab.get_cooldown_left(&"q"), hits.size(), ab.has_charge_indicator()],
		[false, 300.0, 1, 0.0, 0, false])
	await _wait_until(func() -> bool: return not knight.is_stunned() and knight.dash.can_dash(), 60)

	# A dash in the windup (dash_cancelable): cancelled, refunded.
	ab.try_start_charge(&"q", aim)
	await _frames(20)
	ab.release_charge(aim)
	await _frames(6)
	knight.dash.try_dash(Vector2.DOWN)
	await _frames(20)
	_check("a dash in the windup: cancelled, refunded, no hit, indicator gone",
		[ab.casting, pool.current, ab.get_charges(&"q"), hits.size(), ab.has_charge_indicator()], [false, 300.0, 1, 0, false])

	Events.unit_hit.disconnect(on_hit)
	ab.cast_started.disconnect(on_started)
	dummy.queue_free()
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 300)
	ab.q = original_q


# --- AB7 ------------------------------------------------------------------------

func _test_shape_sweep() -> void:
	_section("AB7: WorldQuery.shape_sweep()")
	var at := ARENA + Vector2(0, -600)
	var wall := _wall_at(at + Vector2(100, 0), Vector2(16, 100))
	await get_tree().physics_frame   # the wall joins the physics space
	var hit := WorldQuery.shape_sweep(at, at + Vector2(200, 0), 2.0)
	_check("a sweep through a wall stops where the circle touches it (x = 92 - 2)",
		[hit.is_empty(), snappedf(hit.get("position", Vector2.ZERO).x - at.x, 0.5)], [false, 90.0])
	_check("a clear sweep returns nothing", WorldQuery.shape_sweep(at, at + Vector2(0, 200), 2.0).is_empty(), true)
	wall.queue_free()


func _projectiles() -> Array[Projectile]:
	var out: Array[Projectile] = []
	for n in get_children():
		if n is Projectile and not n.is_queued_for_deletion():
			out.append(n)
	return out


func _test_projectiles() -> void:
	_section("AB7: projectiles (test_bolt)")
	await _reset_knight()
	var ab := knight.abilities
	var defaults := Ability.new()
	_check("defaults: 1200 u/s, 60 u wide, 1 projectile, 15 deg apart, pierce 0",
		[defaults.projectile_speed, defaults.projectile_width, defaults.projectile_count, defaults.projectile_spread_deg, defaults.projectile_pierce],
		[1200.0, 60.0, 1, 15.0, 0])
	_check("the bolt: a core projectile, and its tooltip", [BOLT.get_role(), BOLT.get_tooltip_plain(knight)],
		[&"core", "Fire a bolt up to 900 units: 82 physical damage (50 +50% AD) to the first enemy it hits. Walls stop it."])
	var original_q := ab.q
	ab.q = BOLT
	var hits: Array[HitContext] = []
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.ability != null and ctx.ability.id == &"test_bolt":
			hits.append(ctx)
	Events.unit_hit.connect(on_hit)
	var right := knight.global_position + Vector2(400, 0)

	# Travel time and pierce 0.
	var near := _dummy_at(Vector2(150, 0))
	var behind := _dummy_at(Vector2(220, 0))
	ab.try_cast(&"q", right)
	await _wait_until(func() -> bool: return not _projectiles().is_empty(), 20)
	_check("after the 0.1 s cast time: one bolt in flight, nothing hit yet", [_projectiles().size(), hits.size()], [1, 0])
	await _frames(8)
	_check("still flying (384 px/s)", [hits.size(), _projectiles().size()], [0, 1])
	await _wait_until(func() -> bool: return not hits.is_empty(), 40)
	_check("it hits the first dummy for 82 and stops (pierce 0); the one behind is safe",
		[hits.size(), hits[0].target == near if hits.size() > 0 else false, hits[0].raw_damage if hits.size() > 0 else 0.0],
		[1, true, 82.0])
	await _frames(2)
	_check("the bolt is gone", _projectiles().size(), 0)

	# Pierce 2 (a scoped item modifier): through both, then on to its range.
	var item := &"item_test_projectiles"
	knight.stats_component.add_modifier(StatModifier.create(&"projectile_pierce", StatModifier.Type.FLAT, 2.0, item, &"ability:test_bolt"))
	hits.clear()
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 120)
	ab.try_cast(&"q", right)
	await _wait_until(func() -> bool: return hits.size() >= 2, 60)
	_check("pierce 2: both dummies hit, the near one first", [hits.size(), hits[0].target == near, hits[1].target == behind], [2, true, true])
	_check("and it flies on", _projectiles().size(), 1)
	await _wait_until(func() -> bool: return _projectiles().is_empty(), 90)
	_check("gone at its range (900 u = 288 px)", _projectiles().size(), 0)
	knight.stats_component.remove_modifiers_from(item)
	near.queue_free()
	behind.queue_free()

	# Walls stop it; ignores_walls doesn't.
	var target := _dummy_at(Vector2(150, 0))
	var wall := _wall_at(knight.global_position + Vector2(80, 0), Vector2(16, 120))
	hits.clear()
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 120)
	ab.try_cast(&"q", right)
	await _wait_until(func() -> bool: return not _projectiles().is_empty(), 20)
	await _wait_until(func() -> bool: return _projectiles().is_empty(), 40)
	_check("a wall between: the bolt stops at it, no hit", hits.size(), 0)
	var ghost: Ability = BOLT.duplicate()
	ghost.ignores_walls = true
	ab.q = ghost
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 120)
	ab.try_cast(&"q", right)
	await _wait_until(func() -> bool: return not hits.is_empty(), 60)
	_check("ignores_walls: through the wall, the dummy is hit", hits.size(), 1)
	wall.queue_free()
	target.queue_free()

	# Out of range.
	ab.q = BOLT
	var far := _dummy_at(Vector2(340, 0))
	hits.clear()
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 120)
	ab.try_cast(&"q", right)
	await _wait_until(func() -> bool: return not _projectiles().is_empty(), 20)
	await _wait_until(func() -> bool: return _projectiles().is_empty(), 90)
	_check("a dummy beyond the range (340 px) isn't hit", hits.size(), 0)
	far.queue_free()

	Events.unit_hit.disconnect(on_hit)
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 120)
	ab.q = original_q


func _test_projectile_spread_and_teams() -> void:
	_section("AB7: +2 projectiles, one crit roll, only the other team")
	await _reset_knight()
	var ab := knight.abilities
	var original_q := ab.q
	ab.q = BOLT
	var hits: Array[HitContext] = []
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.ability != null and ctx.ability.id == &"test_bolt":
			hits.append(ctx)
	Events.unit_hit.connect(on_hit)
	var item := &"item_test_projectiles"
	knight.stats_component.add_modifier(StatModifier.create(&"projectile_count", StatModifier.Type.FLAT, 2.0, item, &"ability:test_bolt"))
	var dummies: Array[Enemy] = []
	for deg: float in [-15.0, 0.0, 15.0]:
		dummies.append(_dummy_at(Vector2.RIGHT.rotated(deg_to_rad(deg)) * 160.0))
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 120)
	ab.try_cast(&"q", knight.global_position + Vector2(400, 0))
	await _wait_until(func() -> bool: return not _projectiles().is_empty(), 20)
	var angles: Array[float] = []
	for p in _projectiles():
		angles.append(snappedf(rad_to_deg(p.direction.angle()), 0.1))
	angles.sort()
	_check("+2 projectiles: three bolts, 15 deg apart", angles, [-15.0, 0.0, 15.0] as Array[float])
	await _wait_until(func() -> bool: return hits.size() >= 3, 60)
	_check("each hits its dummy", hits.size(), 3)
	if hits.size() >= 3:
		_check("all three share one crit roll", [hits[0].crit_roll == hits[1].crit_roll, hits[1].crit_roll == hits[2].crit_roll, hits[0].crit_roll != null],
			[true, true, true])
	knight.stats_component.remove_modifiers_from(item)
	for d in dummies:
		d.queue_free()

	# An enemy's bolt passes its own team and hits the Knight.
	hits.clear()
	var elite: Enemy = ELITE_SCENE.instantiate()
	elite.passive = true
	add_child(elite)
	_place(elite, knight.global_position + Vector2(200, 0))
	var between := _dummy_at(Vector2(100, 0))
	await _frames(1)
	elite.abilities.q = BOLT
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	elite.abilities.try_cast(&"q", knight.global_position)
	await _wait_until(func() -> bool: return not hits.is_empty(), 60)
	_check("an enemy's bolt flies through the slime (its team) and hits the Knight",
		[hits.size(), hits[0].target == knight if hits.size() > 0 else false], [1, true])
	elite.queue_free()
	between.queue_free()
	knight.health.heal(10000.0)
	Events.unit_hit.disconnect(on_hit)
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 120)
	ab.q = original_q


func _test_projectile_orphaned() -> void:
	_section("AB7: the caster freed mid-flight")
	await _reset_knight()
	var hits: Array[HitContext] = []
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.ability != null and ctx.ability.id == &"test_bolt":
			hits.append(ctx)
	Events.unit_hit.connect(on_hit)
	var shooter: Player = PLAYER_SCENE.instantiate()
	add_child(shooter)
	_place(shooter, knight.global_position + Vector2(0, -300))
	await _frames(1)
	shooter.abilities.q = BOLT
	shooter.stats_component.add_modifier(StatModifier.create(&"crit_chance", StatModifier.Type.FLAT, 1.0, &"item_test_crit"))
	var dummy := _dummy_at(Vector2(250, -300))
	shooter.abilities.try_cast(&"q", dummy.global_position)
	await _wait_until(func() -> bool: return not _projectiles().is_empty(), 20)
	shooter.queue_free()
	await _wait_until(func() -> bool: return not hits.is_empty(), 60)
	_check("the bolt keeps flying and hits for the snapshot (82), with no source, no crit",
		[hits.size(), hits[0].raw_damage if hits.size() > 0 else 0.0, hits[0].source == null if hits.size() > 0 else false,
			hits[0].is_crit if hits.size() > 0 else true],
		[1, 82.0, true, false])
	Events.unit_hit.disconnect(on_hit)
	dummy.queue_free()


# --- AB8 ------------------------------------------------------------------------

func _augment(id: StringName, kind: AbilityAugment.Kind, scope: StringName, description: String = "") -> AbilityAugment:
	var a := AbilityAugment.new()
	a.id = id
	a.kind = kind
	a.scope = scope
	a.description = description
	return a


func _rule(trigger: ReactionRule.Trigger, effects: Array[GameplayEffect], effect_target := ReactionRule.EffectTarget.OTHER,
		chain_limit := 1) -> ReactionRule:
	var r := ReactionRule.new()
	r.trigger = trigger
	r.effects = effects
	r.effect_target = effect_target
	r.chain_limit = chain_limit
	return r


## Puts STRIKE on Q, ready, with a fresh dummy at +100; returns the old Q.
func _setup_strike() -> Ability:
	await _reset_knight()
	var original_q := knight.abilities.q
	knight.abilities.q = STRIKE
	knight.abilities.reset_cooldown(&"q")
	await _wait_until(func() -> bool: return knight.abilities.can_cast(&"q"), 200)
	return original_q


func _strike_at(target: Node2D) -> void:
	knight.abilities.reset_cooldown(&"q")
	knight.abilities.try_cast(&"q", target.global_position)
	await _wait_until(func() -> bool: return not knight.abilities.casting, 30)
	await _frames(1)


func _test_augment_flag() -> void:
	_section("AB8: FLAG augments")
	var ab := knight.abilities
	var original_q: Ability = await _setup_strike()
	var dummy := _dummy_at(Vector2(100, 0))
	_check("the strike supports test_strike_stuns; no augments: no flags", [STRIKE.supported_flags.has(&"test_strike_stuns"), ab.get_flags(STRIKE)],
		[true, [] as Array[StringName]])
	await _strike_at(dummy)
	_check("without the augment the strike doesn't stun", dummy.is_stunned(), false)

	var stuns := _augment(&"test_strike_stuns", AbilityAugment.Kind.FLAG, &"ability:test_strike", "Strike stuns for 0.5 s.")
	ab.add_augment(stuns, &"item_test_stunner")
	_check("equipped: the flag is on, listed on the slot", [ab.get_flags(STRIKE), ab.get_augments(&"q").has(stuns)],
		[[&"test_strike_stuns"] as Array[StringName], true])
	await _strike_at(dummy)
	_check("the strike now stuns", dummy.is_stunned(), true)
	await _wait_until(func() -> bool: return not dummy.is_stunned(), 60)

	# Removed mid-cast: the cast keeps what it read at its start.
	ab.reset_cooldown(&"q")
	ab.try_cast(&"q", dummy.global_position)
	await _frames(3)
	ab.remove_augments_from(&"item_test_stunner")
	await _wait_until(func() -> bool: return not ab.casting, 30)
	_check("removed mid-cast: that cast still stuns", dummy.is_stunned(), true)
	await _wait_until(func() -> bool: return not dummy.is_stunned(), 60)
	await _strike_at(dummy)
	_check("the next cast doesn't", dummy.is_stunned(), false)

	# A tag scope.
	var by_tag := _augment(&"test_strike_stuns", AbilityAugment.Kind.FLAG, &"tag:core")
	ab.add_augment(by_tag, &"item_test_core_stuns")
	_check("a tag:core FLAG reaches the strike (core); Cleave (core) doesn't support it: ignored, no error",
		[ab.get_flags(STRIKE), ab.get_flags(CLEAVE)], [[&"test_strike_stuns"] as Array[StringName], [] as Array[StringName]])
	ab.remove_augments_from(&"item_test_core_stuns")

	# An exact scope on an ability that doesn't support it.
	print("  (one expected error: an unsupported FLAG augment)")
	var bad := _augment(&"cleave_burns", AbilityAugment.Kind.FLAG, &"ability:knight_cleave")
	var original_w := ab.w
	ab.w = CLEAVE
	ab.add_augment(bad, &"item_test_bad")
	_check("an exact-scope FLAG Cleave doesn't support is ignored", ab.get_flags(CLEAVE), [] as Array[StringName])
	ab.remove_augments_from(&"item_test_bad")
	ab.w = original_w

	# Two sources: once.
	ab.add_augment(stuns, &"item_test_a")
	ab.add_augment(stuns, &"passive_test")
	_check("the same augment from two sources counts once", ab.get_augments(&"q").size(), 1)
	ab.remove_augments_from(&"item_test_a")
	_check("removing one source keeps it (the passive still grants it)", ab.get_flags(STRIKE), [&"test_strike_stuns"] as Array[StringName])
	ab.remove_augments_from(&"passive_test")
	_check("removing the last one takes it away", ab.get_flags(STRIKE), [] as Array[StringName])
	dummy.queue_free()
	ab.q = original_q


func _test_augment_replace() -> void:
	_section("AB8: REPLACE augments")
	var ab := knight.abilities
	var original_q: Ability = await _setup_strike()
	var variant: Ability = BOLT.duplicate()
	variant.id = &"test_strike_bolt"
	variant.variant_of = &"test_strike"
	variant.description = "The strike becomes a bolt."
	var replace := _augment(&"test_strike_becomes_bolt", AbilityAugment.Kind.REPLACE, &"ability:test_strike", "Strike fires a bolt.")
	replace.replacement = variant
	var dummy := _dummy_at(Vector2(100, 0))
	dummy.stats_component.add_modifier(StatModifier.create(&"max_health", StatModifier.Type.FLAT, 3000.0, &"test_tough"))

	ab.add_augment(replace, &"item_test_bolter")
	_check("equipped: the slot casts the variant, its own ability is unchanged",
		[ab.get_ability(&"q") == variant, ab.get_base_ability(&"q") == STRIKE, ab.q == STRIKE], [true, true, true])
	ab.reset_cooldown(&"q")
	ab.try_cast(&"q", dummy.global_position)
	await _wait_until(func() -> bool: return not _projectiles().is_empty(), 20)
	_check("casting it fires a bolt", _projectiles().size(), 1)
	await _wait_until(func() -> bool: return _projectiles().is_empty(), 60)
	knight.stats_component.add_modifier(StatModifier.create(&"cooldown", StatModifier.Type.FLAT, -0.5, &"item_test_cdr", &"ability:test_strike"))
	_check("a modifier on the strike reaches the variant (variant_of): cooldown 1 - 0.5", variant.get_param(knight, &"cooldown"), 0.5)
	knight.stats_component.remove_modifiers_from(&"item_test_cdr")
	_check("the tooltip has the augment's line", variant.get_tooltip_plain(knight).ends_with("\nStrike fires a bolt."), true)

	# A second REPLACE for the same ability: disabled, with a reason.
	var other: Ability = STRIKE.duplicate()
	other.id = &"test_strike_other"
	other.variant_of = &"test_strike"
	var replace2 := _augment(&"test_strike_other", AbilityAugment.Kind.REPLACE, &"ability:test_strike", "Strike is other.")
	replace2.replacement = other
	ab.add_augment(replace2, &"item_test_other")
	var disabled := ab.get_disabled_augments(&"q")
	_check("a second REPLACE is disabled (the first added wins), with its reason",
		[ab.get_ability(&"q") == variant, disabled.size(), disabled[0].augment == replace2 if disabled.size() == 1 else false],
		[true, 1, true])
	_check("the tooltip says why", variant.get_tooltip_plain(knight).contains("Strike is other. (disabled: another replacement is active)"), true)
	ab.remove_augments_from(&"item_test_bolter")
	_check("removing the first: the second takes over", ab.get_ability(&"q") == other, true)
	ab.remove_augments_from(&"item_test_other")
	_check("removing both: the strike is back", ab.get_ability(&"q") == STRIKE, true)

	# Mid-cooldown: the cooldown carries over.
	ab.reset_cooldown(&"q")
	ab.try_cast(&"q", dummy.global_position)
	await _wait_until(func() -> bool: return not ab.casting, 30)
	var left := ab.get_cooldown_left(&"q")
	ab.add_augment(replace, &"item_test_bolter")
	_check("equipped mid-cooldown: the variant waits for the same cooldown", [ab.get_ability(&"q") == variant, ab.is_ready(&"q"), ab.get_cooldown_left(&"q") == left],
		[true, false, true])
	ab.remove_augments_from(&"item_test_bolter")

	# Mid-cast: the cast finishes as the strike.
	var hits: Array[HitContext] = []
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.ability != null and ctx.source == knight:
			hits.append(ctx)
	Events.unit_hit.connect(on_hit)
	ab.reset_cooldown(&"q")
	ab.try_cast(&"q", dummy.global_position)
	await _frames(3)
	ab.add_augment(replace, &"item_test_bolter")
	await _wait_until(func() -> bool: return not ab.casting, 30)
	await _frames(1)
	_check("equipped mid-cast: that cast finishes as the strike (no bolt)",
		[hits.size(), hits[0].ability == STRIKE if hits.size() > 0 else false, _projectiles().size()], [1, true, 0])
	ab.remove_augments_from(&"item_test_bolter")
	Events.unit_hit.disconnect(on_hit)

	# Mid-charge-up: the release fires the charged ability.
	var line_replace := _augment(&"test_line_becomes_bolt", AbilityAugment.Kind.REPLACE, &"ability:test_charged_line")
	var line_bolt: Ability = BOLT.duplicate()
	line_bolt.variant_of = &"test_charged_line"
	line_replace.replacement = line_bolt
	ab.q = CHARGED_LINE
	ab.reset_cooldown(&"q")
	var released: Array = []
	var on_released := func(_s: StringName, a: Ability, _c: float) -> void: released.append(a)
	ab.charge_released.connect(on_released)
	ab.try_start_charge(&"q", dummy.global_position)
	await _frames(10)
	ab.add_augment(line_replace, &"item_test_line")
	ab.release_charge(dummy.global_position)
	_check("equipped mid-charge-up: the release fires the charged line", released, [CHARGED_LINE])
	await _wait_until(func() -> bool: return not ab.casting, 40)
	_check("and the slot shows the variant after", ab.get_ability(&"q") == line_bolt, true)
	ab.charge_released.disconnect(on_released)
	ab.remove_augments_from(&"item_test_line")

	# Mid-recast: the window stays with the ability that opened it.
	var step_replace := _augment(&"test_step_becomes_bolt", AbilityAugment.Kind.REPLACE, &"ability:test_triple_step")
	var step_bolt: Ability = BOLT.duplicate()
	step_bolt.variant_of = &"test_triple_step"
	step_replace.replacement = step_bolt
	ab.q = TRIPLE_STEP
	ab.reset_cooldown(&"q")
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 60)
	ab.try_cast(&"q", knight.global_position + Vector2(0, 100))
	await _wait_until(func() -> bool: return not ab.casting, 30)
	ab.add_augment(step_replace, &"item_test_step")
	_check("equipped mid-recast: the slot still casts Triple Step's next part", [ab.get_ability(&"q") == TRIPLE_STEP, ab.get_recast_part(&"q")], [true, 1])
	ab.try_cast(&"q", knight.global_position + Vector2(0, 100))
	await _wait_until(func() -> bool: return not ab.casting, 30)
	ab.try_cast(&"q", knight.global_position + Vector2(0, 100))
	await _wait_until(func() -> bool: return not ab.casting, 30)
	_check("once the sequence ends, the slot casts the variant", [ab.get_recast_part(&"q"), ab.get_ability(&"q") == step_bolt], [0, true])
	ab.remove_augments_from(&"item_test_step")

	dummy.queue_free()
	await _frames(20)
	ab.q = original_q


func _test_ability_cast_event() -> void:
	_section("AB8: Events.ability_cast fires when the effect starts")
	var ab := knight.abilities
	var original_q: Ability = await _setup_strike()
	var casts: Array = []   # [ability, part, is_free]
	var on_cast := func(u: Unit, a: Ability, ctx: CastContext) -> void:
		if u == knight:
			casts.append([a, ctx.part, ctx.is_free])
	Events.ability_cast.connect(on_cast)
	var dummy := _dummy_at(Vector2(100, 0))

	ab.try_cast(&"q", dummy.global_position)
	_check("not at cast start", casts.size(), 0)
	await _frames(6)
	_check("not during the cast time", casts.size(), 0)
	await _wait_until(func() -> bool: return not ab.casting, 30)
	_check("once, when the effect starts", casts, [[STRIKE, 0, false]])
	casts.clear()
	ab.reset_cooldown(&"q")
	ab.try_cast(&"q", dummy.global_position)
	await _frames(3)
	knight.apply_stun(0.1)
	await _frames(20)
	_check("a cast stunned before its effect: none", casts.size(), 0)
	await _wait_until(func() -> bool: return not knight.is_stunned(), 30)

	# Recast parts, a charge-up release, a free cast.
	ab.q = TRIPLE_STEP
	ab.reset_cooldown(&"q")
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 60)
	for i in 3:
		ab.try_cast(&"q", knight.global_position + Vector2(0, -100))
		await _wait_until(func() -> bool: return not ab.casting, 30)
	await _frames(2)   # the sequence's recharge starts the frame after it ends
	_check("one per recast part (0, 1, 2)", casts, [[TRIPLE_STEP, 0, false], [TRIPLE_STEP, 1, false], [TRIPLE_STEP, 2, false]])
	casts.clear()
	ab.q = CHARGED_LINE
	ab.reset_cooldown(&"q")
	ab.try_start_charge(&"q", dummy.global_position)
	await _frames(10)
	ab.release_charge(dummy.global_position)
	_check("not at a charge-up's release", casts.size(), 0)
	await _wait_until(func() -> bool: return not ab.casting, 40)
	_check("after its release windup", casts, [[CHARGED_LINE, 0, false]])
	casts.clear()
	ab.try_cast_free(STRIKE, dummy.global_position, null, &"passive_test")
	_check("a free cast: at once, marked free", casts, [[STRIKE, 0, true]])

	Events.ability_cast.disconnect(on_cast)
	dummy.queue_free()
	await _frames(20)
	ab.q = original_q


func _test_augment_event() -> void:
	_section("AB8: EVENT augments (reaction rules)")
	var ab := knight.abilities
	var pool := knight.resource_pool
	var original_q: Ability = await _setup_strike()
	var dummy := _dummy_at(Vector2(100, 0))
	var restore := RestoreResourceGameplayEffect.new()
	restore.amount = 20.0
	var on_cast_restore := _augment(&"test_strike_refunds", AbilityAugment.Kind.EVENT, &"ability:test_strike", "Strike restores 20 mana.")
	on_cast_restore.rules = [_rule(ReactionRule.Trigger.ABILITY_CAST, [restore] as Array[GameplayEffect])] as Array[ReactionRule]

	ab.add_augment(on_cast_restore, &"item_test_refund")
	ab.add_augment(on_cast_restore, &"passive_test")
	var entries := knight.get_reaction_rule_entries().filter(func(e: Array) -> bool: return e[1] == &"augment_test_strike_refunds")
	_check("its rule is added once (two sources), scoped to the strike", [entries.size(), (entries[0][0] as ReactionRule).required_ability_scope if entries.size() > 0 else &""],
		[1, &"ability:test_strike"])
	_check("the shared rule itself isn't changed", on_cast_restore.rules[0].required_ability_scope, &"")
	pool.try_spend(100.0)
	var before := pool.current
	await _strike_at(dummy)
	_check_near("casting the strike restores 20 (at its effect; + a little regen)", pool.current - before, 20.0, 2.0)

	# Stunned before the effect: nothing restored (and the cost refunded, as always).
	before = pool.current
	ab.reset_cooldown(&"q")
	ab.try_cast(&"q", dummy.global_position)
	await _frames(3)
	knight.apply_stun(0.1)
	await _frames(15)
	_check_near("stunned before its effect: no restore", pool.current - before, 0.0, 2.0)
	await _wait_until(func() -> bool: return not knight.is_stunned(), 30)

	# Another ability doesn't trigger it.
	ab.q = BOLT
	ab.reset_cooldown(&"q")
	before = pool.current
	ab.try_cast(&"q", dummy.global_position)
	await _wait_until(func() -> bool: return not ab.casting, 30)
	_check_near("the bolt doesn't restore", pool.current - before, 0.0, 1.0)
	await _wait_until(func() -> bool: return _projectiles().is_empty(), 60)   # it must not land during the kill test below
	ab.q = STRIKE
	ab.remove_augments_from(&"item_test_refund")
	ab.remove_augments_from(&"passive_test")
	_check("both sources gone: the rule is gone", knight.get_reaction_rule_entries().filter(
		func(e: Array) -> bool: return e[1] == &"augment_test_strike_refunds").size(), 0)

	# A kill resets the strike's cooldown (UNIT_DIED + ModifyCooldown RESET).
	var reset := ModifyCooldownGameplayEffect.new()
	reset.ability_scope = &"ability:test_strike"
	reset.mode = ModifyCooldownGameplayEffect.Mode.RESET
	var kill_reset := _augment(&"test_strike_kill_reset", AbilityAugment.Kind.EVENT, &"ability:test_strike")
	kill_reset.rules = [_rule(ReactionRule.Trigger.UNIT_DIED, [reset] as Array[GameplayEffect])] as Array[ReactionRule]
	ab.add_augment(kill_reset, &"item_test_reset")
	dummy.health.take_damage(dummy.health.current - 10.0)
	await _strike_at(dummy)
	_check("a strike kill resets its cooldown", [dummy.is_alive(), ab.is_ready(&"q")], [false, true])
	var dummy2 := _dummy_at(Vector2(100, 0))
	await _strike_at(dummy2)
	_check("a strike that doesn't kill: on cooldown", ab.is_ready(&"q"), false)
	ab.remove_augments_from(&"item_test_reset")
	dummy2.queue_free()
	await _frames(20)
	ab.q = original_q
	pool.restore(1000.0)


func _test_gameplay_effects() -> void:
	_section("AB8: ModifyCooldown, RestoreResource, RemoveStatusesByTag, status rules")
	var ab := knight.abilities
	var original_q: Ability = await _setup_strike()
	var aim := knight.global_position + Vector2(100, 0)
	var effect := ModifyCooldownGameplayEffect.new()
	effect.ability_scope = &"ability:test_strike"
	ab.try_cast(&"q", aim)
	await _wait_until(func() -> bool: return not ab.casting, 30)
	var left := ab.get_cooldown_left(&"q")
	effect.mode = ModifyCooldownGameplayEffect.Mode.REDUCE_SECONDS
	effect.amount = 0.5
	effect.apply(knight, knight, null)
	_check_near("REDUCE_SECONDS 0.5", ab.get_cooldown_left(&"q"), left - 0.5, 0.001)
	left = ab.get_cooldown_left(&"q")
	effect.mode = ModifyCooldownGameplayEffect.Mode.REDUCE_PERCENT
	effect.amount = 0.5
	effect.apply(knight, knight, null)
	_check_near("REDUCE_PERCENT 50% of the time left", ab.get_cooldown_left(&"q"), left * 0.5, 0.001)
	var readies := [0]
	var on_ready := func(slot: StringName, _a: Ability) -> void:
		if slot == &"q":
			readies[0] += 1
	ab.cooldown_finished.connect(on_ready)
	effect.mode = ModifyCooldownGameplayEffect.Mode.RESET
	effect.apply(knight, knight, null)
	_check("RESET: ready, with the ready signal", [ab.is_ready(&"q"), readies[0]], [true, 1])
	effect.ability_scope = &"ability:knight_lunge"
	ab.try_cast(&"q", aim)
	await _wait_until(func() -> bool: return not ab.casting, 30)
	effect.apply(knight, knight, null)
	_check("a scope that doesn't match leaves the strike alone", ab.is_ready(&"q"), false)
	effect.ability_scope = &"ability:test_strike"

	# With charges: RESET finishes the current recharge, not a full refill.
	knight.stats_component.add_modifier(StatModifier.create(&"max_charges", StatModifier.Type.FLAT, 1.0, &"item_test_charges", &"ability:test_strike"))
	effect.apply(knight, knight, null)
	await _wait_until(func() -> bool: return ab.get_charges(&"q") == 2, 200)
	ab.try_cast(&"q", aim)
	await _wait_until(func() -> bool: return not ab.casting, 30)
	ab.try_cast(&"q", aim)
	await _wait_until(func() -> bool: return not ab.casting, 30)
	_check("2 charges spent: 0 left", ab.get_charges(&"q"), 0)
	effect.apply(knight, knight, null)
	_check("RESET: +1 charge, the next one recharging", [ab.get_charges(&"q"), ab.get_cooldown_left(&"q") > 1.5], [1, true])
	knight.stats_component.remove_modifiers_from(&"item_test_charges")
	ab.cooldown_finished.disconnect(on_ready)

	# A recast window open: nothing.
	ab.q = TRIPLE_STEP
	ab.reset_cooldown(&"q")
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 60)
	ab.try_cast(&"q", knight.global_position + Vector2(0, 100))
	await _wait_until(func() -> bool: return not ab.casting, 30)
	var step_reset := ModifyCooldownGameplayEffect.new()
	step_reset.mode = ModifyCooldownGameplayEffect.Mode.RESET
	step_reset.apply(knight, knight, null)
	_check("RESET while a recast window is open: nothing (part 1 next, no charge back)", [ab.get_recast_part(&"q"), ab.get_charges(&"q")], [1, 0])
	await _wait_until(func() -> bool: return ab.get_recast_part(&"q") == 0, 240)

	# RestoreResource.
	var pool := knight.resource_pool
	pool.try_spend(200.0)
	var before := pool.current
	var restore := RestoreResourceGameplayEffect.new()
	restore.amount = 10.0
	restore.max_resource_ratio = 0.1
	restore.apply(knight, null, null)
	_check_near("RestoreResource: 10 + 10% of 300", pool.current - before, 40.0, 0.001)
	pool.restore(1000.0)

	# RemoveStatusesByTag (a cleanse).
	var dummy := _dummy_at(Vector2(200, 0))
	dummy.apply_stun(2.0)
	dummy.status_component.apply_status(STATUS_SLOW)
	var cleanse := RemoveStatusesByTagGameplayEffect.new()
	_check("the cleanse defaults to [cc]", cleanse.tags, [&"cc"] as Array[StringName])
	cleanse.apply(dummy, null, null)
	_check("the stun and the slow (both cc) are gone", [dummy.is_stunned(), dummy.status_component.has_tag(&"slow")], [false, false])

	# A status's reaction rules come and go with it.
	var buff := StatusEffect.new()
	buff.id = &"test_buff"
	buff.duration = 0.2
	buff.reaction_rules = [_rule(ReactionRule.Trigger.HIT, [restore] as Array[GameplayEffect])] as Array[Resource]
	knight.status_component.apply_status(buff)
	_check("a status's rule is on the unit while it lasts", knight.get_reaction_rule_entries().filter(
		func(e: Array) -> bool: return e[1] == &"status_test_buff").size(), 1)
	await _frames(20)
	_check("and gone when it ends", knight.get_reaction_rule_entries().filter(
		func(e: Array) -> bool: return e[1] == &"status_test_buff").size(), 0)
	dummy.queue_free()
	ab.q = original_q


func _test_free_casts() -> void:
	_section("AB8: CastAbility and free casts")
	var ab := knight.abilities
	var pool := knight.resource_pool
	var original_q: Ability = await _setup_strike()
	var dummy := _dummy_at(Vector2(100, 0))
	dummy.stats_component.add_modifier(StatModifier.create(&"max_health", StatModifier.Type.FLAT, 3000.0, &"test_tough"))   # survives the chains
	var free_bolt: Ability = BOLT.duplicate()
	free_bolt.id = &"test_free_bolt"
	var cast_bolt := CastAbilityGameplayEffect.new()
	cast_bolt.ability = free_bolt
	var also_bolt := _augment(&"test_strike_also_bolts", AbilityAugment.Kind.EVENT, &"ability:test_strike")
	also_bolt.rules = [_rule(ReactionRule.Trigger.ABILITY_CAST, [cast_bolt] as Array[GameplayEffect])] as Array[ReactionRule]
	var free_ctx: Array[CastContext] = []
	var on_cast := func(u: Unit, a: Ability, ctx: CastContext) -> void:
		if u == knight and ctx.is_free:
			free_ctx.append(ctx)
	Events.ability_cast.connect(on_cast)

	ab.add_augment(also_bolt, &"item_test_also")
	var charges := ab.get_charges(&"q")
	ab.try_cast(&"q", dummy.global_position)
	await _frames(6)
	_check("in the strike's cast time: no free bolt yet", _projectiles().size(), 0)
	await _wait_until(func() -> bool: return not _projectiles().is_empty(), 20)
	_check("at the strike's effect: the free bolt flies, aimed at the strike's point, from the item",
		[free_ctx.size(), free_ctx[0].point == ab.get("_cast_ctx").point if free_ctx.size() > 0 else false,
			free_ctx[0].source_id if free_ctx.size() > 0 else &""],
		[1, true, &"augment_test_strike_also_bolts"])
	_check("only the strike used a charge", ab.get_charges(&"q"), charges - 1)
	await _wait_until(func() -> bool: return _projectiles().is_empty(), 60)
	free_ctx.clear()
	ab.reset_cooldown(&"q")
	ab.try_cast(&"q", dummy.global_position)
	await _frames(3)
	knight.apply_stun(0.1)
	await _frames(20)
	_check("the strike stunned in its cast time: no free bolt", [free_ctx.size(), _projectiles().size()], [0, 0])
	await _wait_until(func() -> bool: return not knight.is_stunned(), 30)
	ab.remove_augments_from(&"item_test_also")

	# From a HIT: at once.
	var on_hit_bolt := _augment(&"test_strike_hit_bolts", AbilityAugment.Kind.EVENT, &"ability:test_strike")
	on_hit_bolt.rules = [_rule(ReactionRule.Trigger.HIT, [cast_bolt] as Array[GameplayEffect])] as Array[ReactionRule]
	ab.add_augment(on_hit_bolt, &"item_test_hit")
	free_ctx.clear()
	await _strike_at(dummy)
	_check("a strike hit casts a free bolt at once, aimed at the unit hit",
		[free_ctx.size(), free_ctx[0].target == dummy if free_ctx.size() > 0 else false], [1, true])
	ab.remove_augments_from(&"item_test_hit")
	await _wait_until(func() -> bool: return _projectiles().is_empty(), 60)

	# During another cast: it doesn't interrupt it, and costs nothing.
	knight.stats_component.add_modifier(StatModifier.create(&"resource_cost", StatModifier.Type.FLAT, 30.0, &"item_test_cost", &"ability:test_free_bolt"))
	pool.restore(1000.0)
	ab.reset_cooldown(&"q")
	ab.try_cast(&"q", dummy.global_position)
	await _frames(3)
	var free_ok := ab.try_cast_free(free_bolt, dummy.global_position, null, &"passive_test")
	_check("a free cast during the strike's cast time: accepted, the strike goes on, no cost",
		[free_ok, ab.casting, ab.casting_slot, pool.current], [true, true, &"q", 300.0])
	await _wait_until(func() -> bool: return not ab.casting, 30)
	_check("the strike still lands its effect", ab.is_ready(&"q"), false)
	knight.stats_component.remove_modifiers_from(&"item_test_cost")
	knight.apply_stun(0.2)
	_check("a stunned unit refuses a free cast", ab.try_cast_free(free_bolt, dummy.global_position, null, &"passive_test"), false)
	await _wait_until(func() -> bool: return not knight.is_stunned(), 30)

	# Chains: "casting anything also casts the strike".
	for limit: int in [1, 3]:
		var cast_strike := CastAbilityGameplayEffect.new()
		cast_strike.ability = STRIKE
		var echo := _augment(StringName("test_echo_%d" % limit), AbilityAugment.Kind.EVENT, &"tag:core")
		echo.rules = [_rule(ReactionRule.Trigger.ABILITY_CAST, [cast_strike] as Array[GameplayEffect], ReactionRule.EffectTarget.OTHER, limit)] as Array[ReactionRule]
		ab.add_augment(echo, &"item_test_echo")
		free_ctx.clear()
		await _strike_at(dummy)
		_check("an ability_cast rule casting the strike, chain_limit %d: %d free cast(s), then it stops" % [limit, limit],
			free_ctx.size(), limit)
		ab.remove_augments_from(&"item_test_echo")
		dummy.health.heal(10000.0)

	# A HIT -> free cast -> HIT loop stops at the chain limit.
	var cast_on_hit := CastAbilityGameplayEffect.new()
	cast_on_hit.ability = STRIKE
	var loop := _augment(&"test_hit_loop", AbilityAugment.Kind.EVENT, &"tag:core")
	loop.rules = [_rule(ReactionRule.Trigger.HIT, [cast_on_hit] as Array[GameplayEffect])] as Array[ReactionRule]
	ab.add_augment(loop, &"item_test_loop")
	free_ctx.clear()
	await _strike_at(dummy)
	await _frames(5)
	_check("a strike hit casts a free strike; its hit (one link deeper) casts nothing more", free_ctx.size(), 1)
	ab.remove_augments_from(&"item_test_loop")

	Events.ability_cast.disconnect(on_cast)
	dummy.queue_free()
	await _wait_until(func() -> bool: return _projectiles().is_empty(), 60)
	ab.q = original_q
	pool.restore(1000.0)


func _test_fake_item() -> void:
	_section("AB8: a fake item: equipping changes the Knight, unequipping restores him exactly")
	var ab := knight.abilities
	var original_q: Ability = await _setup_strike()
	var stuns := _augment(&"test_strike_stuns", AbilityAugment.Kind.FLAG, &"ability:test_strike", "Strike stuns for 0.5 s.")
	var restore := RestoreResourceGameplayEffect.new()
	restore.amount = 5.0
	var refund := _augment(&"test_strike_refunds", AbilityAugment.Kind.EVENT, &"ability:test_strike", "Strike restores 5 mana.")
	refund.rules = [_rule(ReactionRule.Trigger.ABILITY_CAST, [restore] as Array[GameplayEffect])] as Array[ReactionRule]
	var item := {
		"source": &"item_test_gauntlet",
		"modifiers": [StatModifier.create(&"cooldown", StatModifier.Type.FLAT, -0.5, &"item_test_gauntlet", &"ability:test_strike")],
		"augments": [stuns, refund],
	}
	var snapshot := func() -> Array:
		return [STRIKE.get_tooltip_plain(knight), ab.get_ability(&"q"), ab.get_flags(STRIKE), knight.get_reaction_rule_entries().size(),
			STRIKE.get_param(knight, &"cooldown"), ab.get_augments(&"q").size()]
	var before: Array = snapshot.call()
	for m: StatModifier in item.modifiers:
		knight.stats_component.add_modifier(m)
	for a: AbilityAugment in item.augments:
		ab.add_augment(a, item.source)
	var equipped: Array = snapshot.call()
	_check("equipped: the tooltip gains two lines, the flag is on, one rule, cooldown 1.5, two augments",
		[equipped[0].count("\n"), equipped[2], equipped[3] - before[3], equipped[4], equipped[5]],
		[2, [&"test_strike_stuns"] as Array[StringName], 1, 1.5, 2])
	knight.stats_component.remove_modifiers_from(item.source)
	ab.remove_augments_from(item.source)
	_check("unequipped: everything exactly as before", snapshot.call(), before)
	ab.q = original_q


# --- AB9 ------------------------------------------------------------------------

## A form status: tagged form, until removed, refreshed on re-apply.
func _form(id: StringName, augments: Array[Resource]) -> StatusEffect:
	var s := StatusEffect.new()
	s.id = id
	s.tags = [&"form", &"buff"]
	s.duration = -1.0
	s.stack_rule = StatusEffect.StackRule.REFRESH
	s.augments = augments
	return s


func _test_forms() -> void:
	_section("AB9: forms")
	var ab := knight.abilities
	var statuses := knight.status_component
	var original_q: Ability = await _setup_strike()
	var original_e := ab.e
	ab.e = LUNGE
	var q_variant: Ability = BOLT.duplicate()
	q_variant.id = &"test_form_bolt"
	q_variant.variant_of = &"test_strike"
	var e_variant: Ability = STRIKE.duplicate()
	e_variant.id = &"test_form_strike"
	e_variant.variant_of = LUNGE.id
	var swap_q := _augment(&"test_form_q", AbilityAugment.Kind.REPLACE, &"ability:test_strike")
	swap_q.replacement = q_variant
	var swap_e := _augment(&"test_form_e", AbilityAugment.Kind.REPLACE, StringName("ability:" + LUNGE.id))
	swap_e.replacement = e_variant
	var form := _form(&"test_form_a", [swap_q, swap_e])
	var dummy := _dummy_at(Vector2(100, 0))
	dummy.stats_component.add_modifier(StatModifier.create(&"max_health", StatModifier.Type.FLAT, 3000.0, &"test_tough"))
	var changes := [0]
	var on_changed := func(_slot: StringName) -> void: changes[0] += 1
	ab.augments_changed.connect(on_changed)
	var w_before := ab.get_ability(&"w")
	var r_before := ab.get_ability(&"r")

	statuses.apply_status(form, knight)
	_check("a form swaps Q and E; W, R and the q / e exports are unchanged",
		[ab.get_ability(&"q") == q_variant, ab.get_ability(&"e") == e_variant, ab.get_ability(&"w") == w_before,
			ab.get_ability(&"r") == r_before, ab.q == STRIKE, ab.e == LUNGE],
		[true, true, true, true, true, true])
	_check("the slots report the change, and the form's augments are on Q and E",
		[changes[0] > 0, ab.get_augments(&"q").has(swap_q), ab.get_augments(&"e").has(swap_e)], [true, true, true])

	# Cooldowns are per slot: they carry across.
	ab.try_cast(&"q", dummy.global_position)
	await _wait_until(func() -> bool: return not _projectiles().is_empty(), 20)
	_check("in the form, Q fires the bolt", _projectiles().size(), 1)
	await _wait_until(func() -> bool: return not ab.casting, 30)
	var left := ab.get_cooldown_left(&"q")
	statuses.remove_status(&"test_form_a")
	_check("removing the form restores Q and E exactly",
		[ab.get_ability(&"q") == STRIKE, ab.get_ability(&"e") == LUNGE, ab.get_augments(&"q").is_empty(), ab.get_augments(&"e").is_empty()],
		[true, true, true, true])
	_check("the cooldown carries across: the strike waits for the same time", [left > 0.0, ab.is_ready(&"q"), ab.get_cooldown_left(&"q") == left],
		[true, false, true])
	statuses.apply_status(form, knight)
	_check("and back into the form: still the same cooldown", [ab.get_ability(&"q") == q_variant, ab.get_cooldown_left(&"q") == left], [true, true])
	await _wait_until(func() -> bool: return _projectiles().is_empty(), 60)

	# One form at a time.
	var other_q: Ability = STRIKE.duplicate()
	other_q.id = &"test_form_other"
	other_q.variant_of = &"test_strike"
	var swap_q_b := _augment(&"test_form_b_q", AbilityAugment.Kind.REPLACE, &"ability:test_strike")
	swap_q_b.replacement = other_q
	var form_b := _form(&"test_form_b", [swap_q_b])
	statuses.apply_status(form_b, knight)
	_check("applying another form removes the first",
		[statuses.has_status(&"test_form_a"), statuses.has_status(&"test_form_b"), ab.get_ability(&"q") == other_q, ab.get_ability(&"e") == LUNGE],
		[false, true, true, true])
	_check("no REPLACE of the old form is left (none disabled)", ab.get_disabled_augments(&"q").size(), 0)
	statuses.apply_status(STATUS_SLOW, knight, 0.5)
	_check("a status that isn't a form leaves the form on", [statuses.has_status(&"test_form_b"), ab.get_ability(&"q") == other_q], [true, true])
	statuses.remove_status(STATUS_SLOW.id)
	statuses.remove_status(&"test_form_b")

	# Re-applying the same form refreshes it without a flicker.
	statuses.apply_status(form, knight)
	changes[0] = 0
	statuses.apply_status(form, knight)
	_check("re-applying the same form: still on, the slots never changed", [ab.get_ability(&"q") == q_variant, changes[0]], [true, 0])
	statuses.remove_status(&"test_form_a")
	_check("then removing it once restores everything", [ab.get_ability(&"q") == STRIKE, ab.get_ability(&"e") == LUNGE], [true, true])

	# A form that runs out, and one cleared (death clears every status).
	statuses.apply_status(form, knight, 0.2)
	await _frames(20)
	_check("a form that runs out restores the slots",
		[statuses.has_status(&"test_form_a"), ab.get_ability(&"q") == STRIKE, ab.get_ability(&"e") == LUNGE], [false, true, true])
	statuses.apply_status(form, knight)
	statuses.clear()
	_check("clearing statuses (death) restores the slots", [ab.get_ability(&"q") == STRIKE, ab.get_ability(&"e") == LUNGE], [true, true])

	# A form applied mid-cast: that cast finishes as the strike.
	var hits: Array[HitContext] = []
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.ability != null and ctx.source == knight:
			hits.append(ctx)
	Events.unit_hit.connect(on_hit)
	ab.reset_cooldown(&"q")
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 200)
	ab.try_cast(&"q", dummy.global_position)
	await _frames(3)
	statuses.apply_status(form, knight)
	await _wait_until(func() -> bool: return not ab.casting, 30)
	await _frames(1)
	_check("a form applied mid-cast: that cast finishes as the strike (no bolt)",
		[hits.size(), hits[0].ability == STRIKE if hits.size() > 0 else false, _projectiles().size()], [1, true, 0])
	_check("and the slot shows the form's ability after", ab.get_ability(&"q") == q_variant, true)
	Events.unit_hit.disconnect(on_hit)
	statuses.remove_status(&"test_form_a")

	# A unit without an AbilityComponent can carry a form (nothing to swap).
	_check("a unit without abilities takes a form without an error", [dummy.abilities == null, dummy.status_component.apply_status(form)], [true, true])
	dummy.status_component.remove_status(&"test_form_a")

	ab.augments_changed.disconnect(on_changed)
	dummy.queue_free()
	await _frames(20)
	ab.q = original_q
	ab.e = original_e


# --- AB10 -----------------------------------------------------------------------

func _tough(u: Unit) -> void:
	u.stats_component.add_modifier(StatModifier.create(&"max_health", StatModifier.Type.FLAT, 3000.0, &"test_tough"))


## The Knight's next combo swing's AD ratio (swings differ: 1.0 / 1.5 / 1.6).
func _next_swing_ratio() -> float:
	return knight.attack.combo.swings[knight.attack.get_combo_index()].ad_ratio


func _empower(id: StringName, trigger: StatusEffect.EmpowerTrigger, base_damage: float, scope: StringName = &"") -> StatusEffect:
	var s := StatusEffect.new()
	s.id = id
	s.tags = [&"empower", &"buff"]
	s.duration = -1.0
	s.stack_rule = StatusEffect.StackRule.REFRESH
	s.empower_consumed_by = trigger
	s.empower_base_damage = base_damage
	s.empower_scope = scope
	return s


func _status(id: StringName, tags: Array[StringName], duration: float) -> StatusEffect:
	var s := StatusEffect.new()
	s.id = id
	s.tags = tags
	s.duration = duration
	return s


func _test_empower_basic_attack() -> void:
	_section("AB10: basic attack empowers (Iron Resolve through the wrapper)")
	await _reset_knight()
	var ab := knight.abilities
	var sc := knight.status_component
	var a := _dummy_at(Vector2(50, -15))
	var b := _dummy_at(Vector2(50, 15))
	_tough(a)
	_tough(b)
	var normal_speed := a.movement.get_move_speed()
	var hits: Array[HitContext] = []
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.source == knight:
			hits.append(ctx)
	Events.unit_hit.connect(on_hit)

	ab.reset_cooldown(&"w")
	await _wait_until(func() -> bool: return ab.can_cast(&"w"), 200)
	knight.request_cast(&"w")
	await _frames(1)
	var e := sc.get_status(&"empower_iron_resolve")
	_check("Iron Resolve applies empower_iron_resolve (empower + buff, next swing that hits, 82, 4 s) next to its haste",
		[e != null, e.tags if e else [], e.empower_consumed_by if e else -1, e.empower_base_damage if e else 0.0,
			snappedf(sc.get_time_left(&"empower_iron_resolve"), 0.1), sc.has_status(&"iron_resolve")],
		[true, [&"empower", &"buff"], StatusEffect.EmpowerTrigger.BASIC_ATTACK_HIT, 82.0, 4.0, true])
	_check("the wrapper's queries still answer", [knight.attack.has_next_attack_modifier(&"iron_resolve"), knight.attack.is_empowered()], [true, true])

	# A swing that hits nothing keeps it.
	knight.attack.try_swing(Vector2.LEFT)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 40)
	_check("a swing that hits nothing doesn't use it up", [sc.has_status(&"empower_iron_resolve"), hits.size()], [true, 0])

	knight.stats_component.add_modifier(StatModifier.create(&"crit_chance", StatModifier.Type.FLAT, 1.0, &"item_test_crit"))
	var crit_mult := knight.stats_component.get_stat(&"crit_damage")
	await _frames(12)
	var ratio := _next_swing_ratio()
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 30)
	knight.stats_component.remove_modifiers_from(&"item_test_crit")
	var expected := (64.0 * ratio + 82.0) * crit_mult
	_check("the swing hits both for (its 64 x ratio + 82) and the bonus crits with it",
		[hits.size(), a.health.max_health - a.health.current, b.health.max_health - b.health.current], [2, expected, expected])
	_check("both hits are crits, tagged empowered",
		[hits.all(func(h: HitContext) -> bool: return h.is_crit and h.has_tag(&"empowered"))], [true])
	_check("both are slowed (on_hit per enemy), and the empower is used up",
		[a.movement.get_move_speed() < normal_speed, b.movement.get_move_speed() < normal_speed, sc.has_status(&"empower_iron_resolve"),
			knight.attack.is_empowered(), knight.attack.has_next_attack_modifier(&"iron_resolve")],
		[true, true, false, false, false])
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 40)
	hits.clear()
	var hp := a.health.current
	var plain := 64.0 * _next_swing_ratio()
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 30)
	_check("the next swing has no bonus and no tag", [snappedf(hp - a.health.current, 0.01), hits[0].has_tag(&"empowered") if hits.size() > 0 else true], [snappedf(plain, 0.01), false])
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 40)

	# Unused, it runs out after 4 s.
	ab.reset_cooldown(&"w")
	await _wait_until(func() -> bool: return ab.can_cast(&"w"), 200)
	knight.request_cast(&"w")
	await _frames(1)
	await _wait_until(func() -> bool: return not sc.has_status(&"empower_iron_resolve"), 300)
	_check("unused, it runs out after its 4 s window", [sc.has_status(&"empower_iron_resolve"), knight.attack.is_empowered()], [false, false])

	# The same empower from a fake passive: a unit rule under passive_test
	# grants it when the strike is cast.
	var passive_empower := _empower(&"test_passive_empower", StatusEffect.EmpowerTrigger.BASIC_ATTACK_HIT, 82.0)
	var grant := ApplyStatusGameplayEffect.new()
	grant.status = passive_empower
	var effects: Array[GameplayEffect] = [grant]
	var rule := _rule(ReactionRule.Trigger.ABILITY_CAST, effects)
	rule.required_ability_scope = &"ability:test_strike"
	knight.add_reaction_rule(rule, &"passive_test")
	var original_q := ab.q
	ab.q = STRIKE
	ab.reset_cooldown(&"q")
	ab.try_cast(&"q", knight.global_position + Vector2(-100, 0))   # away from the dummies
	await _wait_until(func() -> bool: return not ab.casting, 30)
	_check("passive_test's rule granted the empower when the strike was cast", sc.has_status(&"test_passive_empower"), true)
	ab.q = original_q
	await _frames(12)
	hits.clear()
	var ha := a.health.current
	var hb := b.health.current
	var with_bonus := 64.0 * _next_swing_ratio() + 82.0
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 30)
	_check("an empower from passive_test works the same: both take 64 + 82, tagged, used up",
		[snappedf(ha - a.health.current, 0.01), snappedf(hb - b.health.current, 0.01), hits.size() == 2 and hits.all(func(h: HitContext) -> bool: return h.has_tag(&"empowered")),
			sc.has_status(&"test_passive_empower")],
		[snappedf(with_bonus, 0.01), snappedf(with_bonus, 0.01), true, false])
	knight.remove_reaction_rules_from(&"passive_test")
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 40)

	# The League-style attack path (enemies) reads the same empowers.
	var slime := _dummy_at(Vector2(0, 40))
	slime.passive = false
	var slime_empower := _empower(&"test_slime_empower", StatusEffect.EmpowerTrigger.BASIC_ATTACK_HIT, 10.0)
	slime.status_component.apply_status(slime_empower, slime)
	var knight_hp := knight.health.current
	var slime_hits: Array[HitContext] = []
	var on_slime_hit := func(ctx: HitContext) -> void:
		if ctx.source == slime:
			slime_hits.append(ctx)
	Events.unit_hit.connect(on_slime_hit)
	slime.attack.attack(knight)
	await _wait_until(func() -> bool: return not slime_hits.is_empty(), 180)
	var slime_ad := slime.stats_component.get_stat(&"attack_damage")
	_check("an enemy's attack adds its empower (+10) and uses it up",
		[slime_hits.size() >= 1, slime_hits[0].raw_damage if slime_hits.size() > 0 else 0.0, slime_hits[0].has_tag(&"empowered") if slime_hits.size() > 0 else false,
			slime.status_component.has_status(&"test_slime_empower")],
		[true, slime_ad + 10.0, true, false])
	Events.unit_hit.disconnect(on_slime_hit)
	slime.queue_free()
	knight.health.heal(knight_hp)

	Events.unit_hit.disconnect(on_hit)
	a.queue_free()
	b.queue_free()
	await _frames(5)


func _test_empower_abilities() -> void:
	_section("AB10: ability empowers")
	var ab := knight.abilities
	var sc := knight.status_component
	var original_q: Ability = await _setup_strike()
	var original_e := ab.e
	ab.e = BOLT
	ab.reset_cooldown(&"e")
	var dummy := _dummy_at(Vector2(100, 0))
	_tough(dummy)
	var hits: Array[HitContext] = []
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.source == knight and ctx.ability != null:
			hits.append(ctx)
	Events.unit_hit.connect(on_hit)
	var emp := _empower(&"test_strike_empower", StatusEffect.EmpowerTrigger.ABILITY_CAST, 30.0, &"ability:test_strike")
	emp.empower_statuses = [STATUS_SLOW]
	sc.apply_status(emp, knight)

	ab.try_cast(&"e", dummy.global_position)
	await _wait_until(func() -> bool: return not hits.is_empty(), 60)
	_check("the bolt (outside its scope) doesn't use it: a plain 82 hit, the empower stays",
		[hits.size(), hits[0].raw_damage if hits.size() > 0 else 0.0, hits[0].has_tag(&"empowered") if hits.size() > 0 else true, sc.has_status(&"test_strike_empower")],
		[1, 82.0, false, true])
	await _wait_until(func() -> bool: return _projectiles().is_empty() and not ab.casting, 60)

	hits.clear()
	await _strike_at(dummy)
	_check("the next strike uses it: 72 + 30, tagged empowered, the target slowed, the empower gone",
		[hits.size(), hits[0].raw_damage if hits.size() > 0 else 0.0, hits[0].has_tag(&"empowered") if hits.size() > 0 else false,
			dummy.status_component.has_status(STATUS_SLOW.id), sc.has_status(&"test_strike_empower")],
		[1, 102.0, true, true, false])
	hits.clear()
	await _strike_at(dummy)
	_check("the strike after that is plain (72)", [hits.size(), hits[0].raw_damage if hits.size() > 0 else 0.0], [1, 72.0])

	# Free casts don't use up empowers.
	sc.apply_status(emp, knight)
	hits.clear()
	_check("a free strike runs", ab.try_cast_free(STRIKE, dummy.global_position, dummy, &"item_test_free"), true)
	await _wait_until(func() -> bool: return not hits.is_empty(), 30)
	_check("a free cast leaves the empower for the next real cast (its hit is plain 72)",
		[hits.size(), hits[0].raw_damage if hits.size() > 0 else 0.0, sc.has_status(&"test_strike_empower")], [1, 72.0, true])
	hits.clear()
	await _strike_at(dummy)
	_check("the next real cast uses it (102)", [hits[0].raw_damage if hits.size() > 0 else 0.0, sc.has_status(&"test_strike_empower")], [102.0, false])

	# Used up before ABILITY_CAST: a rule granting the next one on cast doesn't feed the same cast.
	var grant := ApplyStatusGameplayEffect.new()
	grant.status = emp
	var effects: Array[GameplayEffect] = [grant]
	var rule := _rule(ReactionRule.Trigger.ABILITY_CAST, effects)
	rule.required_ability_scope = &"ability:test_strike"
	knight.add_reaction_rule(rule, &"passive_test")
	hits.clear()
	await _strike_at(dummy)
	_check("a passive_test rule granting it on cast: this strike is plain, the next one is empowered",
		[hits[0].raw_damage if hits.size() > 0 else 0.0, sc.has_status(&"test_strike_empower")], [72.0, true])
	hits.clear()
	await _strike_at(dummy)
	_check("and the next strike uses it (102), and the rule grants another", [hits[0].raw_damage if hits.size() > 0 else 0.0, sc.has_status(&"test_strike_empower")], [102.0, true])
	knight.remove_reaction_rules_from(&"passive_test")
	sc.remove_status(&"test_strike_empower")

	# An empower with an empty scope: any ability.
	var any := _empower(&"test_any_empower", StatusEffect.EmpowerTrigger.ABILITY_CAST, 5.0)
	sc.apply_status(any, knight)
	hits.clear()
	ab.reset_cooldown(&"e")
	ab.try_cast(&"e", dummy.global_position)
	await _wait_until(func() -> bool: return not hits.is_empty(), 60)
	_check("an empty scope: the bolt uses it (82 + 5)", [hits[0].raw_damage if hits.size() > 0 else 0.0, sc.has_status(&"test_any_empower")], [87.0, false])
	await _wait_until(func() -> bool: return _projectiles().is_empty() and not ab.casting, 60)

	Events.unit_hit.disconnect(on_hit)
	dummy.queue_free()
	await _frames(20)
	ab.q = original_q
	ab.e = original_e


func _test_unstoppable() -> void:
	_section("AB10: unstoppable")
	await _reset_knight()
	var dummy := _dummy_at(Vector2(60, 0))
	_tough(dummy)
	var dsc := dummy.status_component
	var unstoppable := _status(&"test_unstoppable", [&"unstoppable", &"buff"], 1.0)
	dummy.apply_stun(1.0, knight)
	dsc.apply_status(STATUS_SLOW, knight)
	_check("stunned and slowed first", [dummy.is_stunned(), dsc.has_status(STATUS_SLOW.id)], [true, true])
	dsc.apply_status(unstoppable, dummy)
	_check("applying unstoppable removes every cc at once", [dummy.is_stunned(), dsc.has_status(STATUS_SLOW.id), dummy.is_unstoppable()], [false, false, true])
	var speed := dummy.movement.get_move_speed()
	dummy.apply_stun(1.0, knight)
	dummy.movement.add_speed_modifier(&"test_unstoppable_slow", 0.0, -0.4, 1.0)
	_check("new stuns and slows are refused", [dummy.is_stunned(), dsc.apply_status(STATUS_SLOW, knight), dummy.movement.get_move_speed()], [false, false, speed])
	dummy.movement.add_speed_modifier(&"test_unstoppable_haste", 0.0, 0.3, 1.0)
	_check("a haste (not cc) still applies", dsc.has_status(&"test_unstoppable_haste"), true)
	dsc.remove_status(&"test_unstoppable_haste")

	var swing: AttackSwing = knight.attack.combo.swings[0]
	var hp := dummy.health.current
	var hit := HitPipeline.basic_attack(knight, dummy, swing)
	hit.knockback_px = 40.0
	HitPipeline.resolve(hit)
	_check("a hit lands but doesn't knock it back", [hp - dummy.health.current > 0.0, dummy.movement.is_displaced()], [true, false])
	var kb := KnockbackGameplayEffect.new()
	kb.distance_px = 40.0
	kb.apply(dummy, knight, null)
	_check("KnockbackGameplayEffect is skipped too", dummy.movement.is_displaced(), false)

	dsc.remove_status(&"test_unstoppable")
	await _frames(12)   # the dummy's post-hit i-frames, if any
	hit = HitPipeline.basic_attack(knight, dummy, swing)
	hit.knockback_px = 40.0
	HitPipeline.resolve(hit)
	_check("once it ends: knockback again", dummy.movement.is_displaced(), true)
	dummy.apply_stun(0.5, knight)
	_check("and cc again", dummy.is_stunned(), true)

	# The cleanse (AB8's RemoveStatusesByTag) on the same statuses.
	dsc.apply_status(STATUS_SLOW, knight)
	var cleanse := RemoveStatusesByTagGameplayEffect.new()
	cleanse.apply(dummy, dummy, null)
	_check("the cleanse removes the stun and the slow", [dummy.is_stunned(), dsc.has_status(STATUS_SLOW.id)], [false, false])
	dummy.queue_free()
	await _frames(5)


func _test_untargetable() -> void:
	_section("AB10: untargetable")
	await _reset_knight()
	var ab := knight.abilities
	var dummy := _dummy_at(Vector2(80, 0))
	_tough(dummy)
	var dsc := dummy.status_component
	var burn := _status(&"test_burn", [&"burn", &"debuff"], 3.0)
	burn.tick_interval = 0.25
	burn.tick_damage = 5.0
	dsc.apply_status(burn, knight)
	var untargetable := _status(&"test_untargetable", [&"untargetable", &"buff"], -1.0)
	dsc.apply_status(untargetable, dummy)
	_check("untargetable: alive but not targetable", [dummy.is_alive(), dummy.is_targetable(), dummy.is_untargetable()], [true, false, true])
	_check("AbilityUtil.enemies_of() skips it", AbilityUtil.enemies_of(knight).has(dummy), false)

	ab.reset_cooldown(&"r")
	var fails: Array = []
	var on_fail := func(_slot: StringName, reason: String) -> void: fails.append(reason)
	ab.cast_failed.connect(on_fail)
	_check("Judgement on it: not picked under the cursor or by forgiveness, 'no target'",
		[knight.cast_ability(&"r", dummy.get_center()), fails], [false, [AbilityComponent.FAIL_NO_TARGET]])
	_check("given as the target directly: 'no target' too", ab.try_cast(&"r", dummy.global_position, dummy), false)
	ab.cast_failed.disconnect(on_fail)

	var hp := dummy.health.current
	var hit := HitPipeline.from_ability(knight, STRIKE, dummy)
	HitPipeline.resolve(hit)
	_check("a new hit is blocked", [hit.blocked, dummy.health.current], [true, hp])
	_check("a status from another unit is refused; its own and the environment's apply",
		[dsc.apply_status(STATUS_SLOW, knight), dsc.apply_status(_status(&"test_self_buff", [&"buff"], 1.0), dummy),
			dsc.apply_status(_status(&"test_env", [&"debuff"], 1.0), null)],
		[false, true, true])
	hp = dummy.health.current
	await _frames(40)
	_check("the burn applied before keeps ticking (DoT isn't blocked)", dummy.health.current <= hp - 5.0, true)

	knight.attack.attack(dummy)
	_check("it can't be made an attack target", knight.attack.target, null)
	dsc.remove_status(&"test_untargetable")
	knight.attack.attack(dummy)
	_check("targetable again: an attack target", knight.attack.target == dummy, true)
	dsc.apply_status(untargetable, dummy)
	await _frames(2)
	_check("turning untargetable drops it as the attack target", knight.attack.target, null)
	knight.attack.cancel()
	dsc.remove_status(&"test_untargetable")

	# The walk-into-range cast is dropped.
	var far := _dummy_at(Vector2(500, 0))
	ab.reset_cooldown(&"r")
	await _wait_until(func() -> bool: return ab.can_cast(&"r"), 200)
	_check("Judgement on a far dummy walks into range", [ab.try_cast(&"r", far.global_position, far), ab.has_pending()], [true, true])
	far.status_component.apply_status(untargetable, far)
	await _frames(2)
	_check("it turns untargetable: the walk-into-range cast is dropped", [ab.has_pending(), ab.casting], [false, false])
	knight.movement.stop()
	far.queue_free()

	# A projectile flies through it.
	dsc.apply_status(untargetable, dummy)
	var behind := _dummy_at(Vector2(160, 0))
	_tough(behind)
	var bolt_hits: Array[Unit] = []
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.source == knight and ctx.ability != null:
			bolt_hits.append(ctx.target)
	Events.unit_hit.connect(on_hit)
	var original_e := ab.e
	ab.e = BOLT
	ab.reset_cooldown(&"e")
	ab.try_cast(&"e", behind.global_position)
	await _wait_until(func() -> bool: return not bolt_hits.is_empty(), 60)
	_check("a bolt (pierce 0) flies through it and hits the dummy behind", bolt_hits, [behind])
	await _wait_until(func() -> bool: return _projectiles().is_empty() and not ab.casting, 60)
	Events.unit_hit.disconnect(on_hit)
	ab.e = original_e
	dsc.remove_status(&"test_untargetable")
	_check("removed: targetable again", [dummy.is_targetable(), AbilityUtil.enemies_of(knight).has(dummy)], [true, true])
	dummy.queue_free()
	behind.queue_free()
	await _frames(5)


func _test_untargetable_enemy_ai() -> void:
	_section("AB10: enemies and an untargetable player")
	await _reset_knight()
	var sc := knight.status_component
	var untargetable := _status(&"test_untargetable", [&"untargetable", &"buff"], -1.0)
	sc.apply_status(untargetable, knight)
	var slime := _dummy_at(Vector2(30, 0))   # in attack range: the test arena has no navigation mesh to walk on
	slime.passive = false
	await _frames(30)
	_check("an untargetable player isn't aggroed", slime.ai == Enemy.AI.AGGRO, false)
	sc.remove_status(&"test_untargetable")
	await _wait_until(func() -> bool: return slime.ai == Enemy.AI.AGGRO and slime.attack.target == knight, 60)
	_check("targetable: aggro and attacking", [slime.ai == Enemy.AI.AGGRO, slime.attack.target == knight], [true, true])
	await _wait_until(func() -> bool: return slime.attack.is_winding_up(), 120)
	var winding := slime.attack.is_winding_up()
	var hp := knight.health.current
	sc.apply_status(untargetable, knight)
	await _frames(2)
	_check("untargetable mid-windup: keeps aggro, the windup is cancelled, no attack target",
		[winding, slime.ai == Enemy.AI.AGGRO, slime.attack.is_winding_up(), slime.attack.target], [true, true, false, null])
	_place(knight, knight.global_position + Vector2(-80, 0))
	await _frames(30)
	_check("it keeps chasing (a move order to the player), without attacking",
		[slime.movement.has_order(), slime.attack.target, knight.health.current], [true, null, hp])
	_place(knight, knight.global_position + Vector2(80, 0))
	sc.remove_status(&"test_untargetable")
	await _wait_until(func() -> bool: return slime.attack.target == knight, 10)
	_check("targetable again: it attacks again", slime.attack.target == knight, true)
	slime.queue_free()
	await _frames(5)


# --- AB11 -----------------------------------------------------------------------

## A camera that records GameFeel.shake() amounts (as in combat_test).
func _spy_camera() -> Camera2D:
	var script := GDScript.new()
	script.source_code = "extends Camera2D\nvar on_shake: Callable\nfunc shake(amount: float) -> void:\n\ton_shake.call(amount)\n"
	script.reload()
	var cam := Camera2D.new()
	cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	cam.set_script(script)
	cam.set("on_shake", func(amount: float) -> void: _shakes.append(amount))
	add_child(cam)
	cam.make_current()
	return cam


func _hitstop_over() -> void:
	while GameFeel.is_hitstop_active():
		await get_tree().create_timer(0.02, true, false, true).timeout


## Waits until the knight's cast is over; returns whether a hitstop ran meanwhile.
func _cast_over_saw_hitstop() -> bool:
	var saw := [false]
	await _wait_until(func() -> bool:
		if GameFeel.is_hitstop_active():
			saw[0] = true
		return not knight.abilities.casting, 150)
	if GameFeel.is_hitstop_active():
		saw[0] = true
	return saw[0]


func _test_ab11_cleave() -> void:
	_section("AB11: Cleave from toolkit pieces (hit_units, hit_knockback_px, play_hit_feel)")
	await _reset_knight()
	await _hitstop_over()
	var ab := knight.abilities
	var cam := _spy_camera()
	var hits: Array[HitContext] = []
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.source == knight and ctx.ability != null:
			hits.append(ctx)
	Events.unit_hit.connect(on_hit)
	_check("the data: push 17 px over 0.1 s (170 px/s x 0.1 s), shake 3, hitstop 0.05",
		[CLEAVE.hit_knockback_px, CLEAVE.hit_knockback_duration, CLEAVE.hit_shake, CLEAVE.hit_hitstop], [17.0, 0.1, 3.0, 0.05])

	var dummy := _dummy_at(Vector2(50, 25))   # off the axis, so the direction is checked
	_tough(dummy)
	await _frames(2)
	var start := dummy.global_position
	var away := (start - knight.global_position).normalized()   # today's push direction: from the Knight to the target
	_shakes.clear()
	ab.reset_cooldown(&"q")
	ab.try_cast(&"q", dummy.global_position)
	var saw_hitstop := await _cast_over_saw_hitstop()
	await _wait_until(func() -> bool: return not dummy.movement.is_displaced(), 30)
	var moved := dummy.global_position - start
	_check("one hit for 124.8 (80 + 0.7 x 64), tags unchanged",
		[hits.size(), snappedf(hits[0].raw_damage, 0.01) if hits.size() > 0 else 0.0, hits[0].has_tag(&"cone") if hits.size() > 0 else false], [1, 124.8, true])
	_check_near("pushed 17 px", moved.length(), 17.0, 0.5)
	_check_near("in exactly today's direction (angle to Knight -> target, rad)", absf(moved.angle_to(away)), 0.0, 0.01)
	_check("its feel once: a 3 px shake, a hitstop", [_shakes, saw_hitstop], [[3.0], true])
	await _hitstop_over()

	# A unit the hit kills still slides 17 px the same way (as before AB11).
	await _wait_until(func() -> bool: return not dummy.movement.is_displaced(), 30)
	var victim := _dummy_at(Vector2(45, -30))
	await _frames(2)
	victim.health.take_damage(victim.health.current - 5.0)
	var v0 := victim.global_position
	var v_away := (v0 - knight.global_position).normalized()
	ab.reset_cooldown(&"q")
	ab.try_cast(&"q", victim.global_position)
	await _cast_over_saw_hitstop()
	await _frames(12)
	var slid := victim.global_position - v0 if is_instance_valid(victim) else Vector2.ZERO
	_check("a unit Cleave kills still slides 17 px in the same direction (as before)",
		[victim.is_alive() if is_instance_valid(victim) else false, snappedf(slid.length(), 0.1), absf(slid.angle_to(v_away)) < 0.01],
		[false, 17.0, true])
	await _hitstop_over()
	await _wait_until(func() -> bool: return not dummy.movement.is_displaced(), 30)

	# Unstoppable now blocks the push (it was a manual displace before AB11).
	_place(dummy, knight.global_position + Vector2(50, 25))
	await _frames(2)
	hits.clear()
	dummy.status_component.apply_status(_status(&"test_unstoppable", [&"unstoppable", &"buff"], -1.0), dummy)
	start = dummy.global_position
	ab.reset_cooldown(&"q")
	ab.try_cast(&"q", dummy.global_position)
	await _cast_over_saw_hitstop()
	await _frames(8)
	_check("an unstoppable target takes the hit but isn't pushed",
		[hits.size(), dummy.movement.is_displaced(), dummy.global_position.distance_to(start) < 0.5], [1, false, true])
	dummy.status_component.remove_status(&"test_unstoppable")
	await _hitstop_over()

	# An ability empower scoped to Cleave reaches its hit now (the cast's context).
	_place(dummy, knight.global_position + Vector2(50, 25))
	await _frames(2)
	hits.clear()
	knight.status_component.apply_status(_empower(&"test_cleave_empower", StatusEffect.EmpowerTrigger.ABILITY_CAST, 20.0, &"ability:knight_cleave"), knight)
	ab.reset_cooldown(&"q")
	ab.try_cast(&"q", dummy.global_position)
	await _cast_over_saw_hitstop()
	_check("an ability empower on Cleave adds to its hit: 124.8 + 20, tagged empowered",
		[snappedf(hits[0].raw_damage, 0.01) if hits.size() > 0 else 0.0, hits[0].has_tag(&"empowered") if hits.size() > 0 else false,
			knight.status_component.has_status(&"test_cleave_empower")], [144.8, true, false])
	await _hitstop_over()
	await _wait_until(func() -> bool: return not dummy.movement.is_displaced(), 30)

	# No feel when every hit is blocked (the dummy is in the cone: it was in reach before AB11 too).
	_place(dummy, knight.global_position + Vector2(50, 25))
	await _frames(2)
	var in_cone := AbilityUtil.in_cone(knight, knight.global_position, (dummy.global_position - knight.global_position).normalized(),
		Units.to_px(CLEAVE.get_param(knight, &"cast_range")), deg_to_rad(60.0)).has(dummy)
	_shakes.clear()
	hits.clear()
	dummy.add_invulnerability(&"test")
	ab.reset_cooldown(&"q")
	ab.try_cast(&"q", dummy.global_position)
	var blocked_hitstop := await _cast_over_saw_hitstop()
	dummy.remove_invulnerability(&"test")
	_check("every hit blocked (the dummy was in the cone): no shake, no hitstop", [in_cone, _shakes, blocked_hitstop], [true, [], false])

	Events.unit_hit.disconnect(on_hit)
	dummy.queue_free()
	cam.queue_free()
	await _frames(5)


func _test_ab11_lunge() -> void:
	_section("AB11: Lunge from toolkit pieces")
	await _reset_knight()
	await _hitstop_over()
	var ab := knight.abilities
	var cam := _spy_camera()
	var hits: Array[HitContext] = []
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.source == knight and ctx.ability != null:
			hits.append(ctx)
	Events.unit_hit.connect(on_hit)
	var dummy := _dummy_at(Vector2(60, 0))
	_tough(dummy)
	await _frames(2)
	var from := knight.global_position
	_shakes.clear()
	ab.reset_cooldown(&"e")
	ab.try_cast(&"e", from + Vector2(120, 0))
	var saw_hitstop := await _cast_over_saw_hitstop()
	await _wait_until(func() -> bool: return not knight.movement.is_displaced() and not hits.is_empty(), 60)
	_check("the Knight dashes 120 px; the dummy on the path takes 82 (50 + 0.5 x 64)",
		[snappedf(knight.global_position.distance_to(from), 1.0), hits.size(), snappedf(hits[0].raw_damage, 0.01) if hits.size() > 0 else 0.0],
		[120.0, 1, 82.0])
	_check("its feel: a 2.5 px shake, no hitstop (none in the data)", [_shakes, saw_hitstop, LUNGE.hit_hitstop], [[2.5], false, 0.0])

	# A free Lunge at chain depth 2: its hits keep the depth (the cast's context).
	hits.clear()
	_place(knight, dummy.global_position + Vector2(-60, 0))
	await _frames(2)
	var point := knight.global_position + Vector2(120, 0)
	Reactions.run_at_depth(2, func() -> void: ab.try_cast_free(LUNGE, point, null, &"item_test_free"))
	await _wait_until(func() -> bool: return not hits.is_empty(), 60)
	_check("a free Lunge's hits carry its chain depth (2)", [hits.size(), hits[0].chain_depth if hits.size() > 0 else -1], [1, 2])
	await _wait_until(func() -> bool: return not knight.movement.is_displaced(), 30)

	Events.unit_hit.disconnect(on_hit)
	dummy.queue_free()
	cam.queue_free()
	await _frames(5)


func _test_ab11_judgement() -> void:
	_section("AB11: Judgement from toolkit pieces")
	await _reset_knight()
	await _hitstop_over()
	var ab := knight.abilities
	var cam := _spy_camera()
	var hits: Array[HitContext] = []
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.source == knight and ctx.ability != null:
			hits.append(ctx)
	Events.unit_hit.connect(on_hit)
	var dummy := _dummy_at(Vector2(80, 0))
	_tough(dummy)
	await _frames(2)
	dummy.take_damage(1000.0)   # 1000 missing
	await _frames(2)
	var missing := dummy.health.max_health - dummy.health.current
	_shakes.clear()
	ab.reset_cooldown(&"r")
	_below_fury_bonus()
	ab.try_cast(&"r", dummy.global_position, dummy)
	var saw_hitstop := await _cast_over_saw_hitstop()
	var dsc := dummy.status_component
	_check("150 + 64 + 20% of the missing health, one hit",
		[hits.size(), snappedf(hits[0].raw_damage, 0.01) if hits.size() > 0 else 0.0], [1, snappedf(150.0 + 64.0 + 0.2 * missing, 0.01)])
	_check("the 0.75 s stun, from the Knight (a copy of status_stun: same id, tags, stars)",
		[dsc.has_status(&"stun"), dsc.get_time_left(&"stun") > 0.7 and dsc.get_time_left(&"stun") <= 0.75, dsc.get_source(&"stun") == knight,
			dsc.get_status(&"stun").tags if dsc.has_status(&"stun") else [], dsc.get_status(&"stun").vfx != null if dsc.has_status(&"stun") else false],
		[true, true, true, [&"cc", &"stun", &"debuff"], true])
	_check("its feel: a 6 px shake, a hitstop", [_shakes, saw_hitstop, JUDGEMENT.hit_hitstop], [[6.0], true, 0.09])
	await _hitstop_over()

	# Blocked: no stun, no feel.
	await _wait_until(func() -> bool: return not dsc.has_status(&"stun"), 90)
	_shakes.clear()
	hits.clear()
	ab.reset_cooldown(&"r")
	_below_fury_bonus()
	ab.try_cast(&"r", dummy.global_position, dummy)
	await _frames(30)
	dummy.add_invulnerability(&"test")
	var blocked_hitstop := await _cast_over_saw_hitstop()
	dummy.remove_invulnerability(&"test")
	_check("a blocked Judgement: no stun, no shake, no hitstop", [dsc.has_status(&"stun"), _shakes, blocked_hitstop], [false, [], false])
	knight.resource_pool.restore(1000.0)   # back to the full test pool

	Events.unit_hit.disconnect(on_hit)
	dummy.queue_free()
	cam.queue_free()
	await _frames(5)


func _test_ab11_iron_resolve() -> void:
	_section("AB11: Iron Resolve from toolkit pieces")
	await _reset_knight()
	await _hitstop_over()
	var ab := knight.abilities
	var sc := knight.status_component
	var cam := _spy_camera()
	var a := _dummy_at(Vector2(50, -15))
	var b := _dummy_at(Vector2(50, 15))
	_tough(a)
	_tough(b)
	await _frames(2)
	var speed := knight.movement.get_move_speed()
	ab.reset_cooldown(&"w")
	await _wait_until(func() -> bool: return ab.can_cast(&"w"), 200)
	knight.request_cast(&"w")
	await _frames(2)
	var haste := sc.get_status(&"iron_resolve")
	var empower := sc.get_status(&"empower_iron_resolve")
	var slow: StatusEffect = empower.empower_statuses[0] if empower != null and not empower.empower_statuses.is_empty() else null
	_check("the haste: status iron_resolve (haste + buff, +35% for 2 s), 375 -> 506.25",
		[haste != null, haste.tags if haste else [], snappedf(sc.get_time_left(&"iron_resolve"), 0.1), speed, snappedf(knight.movement.get_move_speed(), 0.01)],
		[true, [&"haste", &"buff"], 2.0, 375.0, 506.25])
	_check("the empower: empower_iron_resolve, 82 (snapshotted), 4 s, its slow iron_resolve_slow (cc + slow, -40%, 1.5 s)",
		[empower != null, empower.empower_base_damage if empower else 0.0, snappedf(sc.get_time_left(&"empower_iron_resolve"), 0.1),
			slow.id if slow else &"", slow.tags if slow else [], slow.modifiers[0].value if slow else 0.0, slow.duration if slow else 0.0],
		[true, 82.0, 4.0, &"iron_resolve_slow", [&"cc", &"slow", &"debuff"], -0.4, 1.5])
	var a_speed := a.movement.get_move_speed()
	var expected := 64.0 * _next_swing_ratio() + 82.0
	_shakes.clear()
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 30)
	_check("the swing: both take 64 x ratio + 82", [snappedf(a.health.max_health - a.health.current, 0.01), snappedf(b.health.max_health - b.health.current, 0.01)],
		[snappedf(expected, 0.01), snappedf(expected, 0.01)])
	_check("both slowed by iron_resolve_slow, now from the Knight (it had no source before)",
		[a.movement.get_move_speed() < a_speed, a.status_component.get_source(&"iron_resolve_slow") == knight, b.status_component.get_source(&"iron_resolve_slow") == knight],
		[true, true, true])
	_check("its per-enemy feel: a 2.5 px shake for each of the two", _shakes.count(2.5), 2)
	_check("used up", [sc.has_status(&"empower_iron_resolve"), knight.attack.is_empowered()], [false, false])
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 40)
	await _hitstop_over()
	a.queue_free()
	b.queue_free()
	cam.queue_free()
	await _frames(5)


func _test_ab11_scripts() -> void:
	_section("AB11: the Knight's scripts use toolkit pieces only")
	var offenders: Array[String] = []
	for path in ["res://scripts/abilities/knight/cleave.gd", "res://scripts/abilities/knight/iron_resolve.gd",
			"res://scripts/abilities/knight/lunge.gd", "res://scripts/abilities/knight/judgement.gd"]:
		var src := FileAccess.get_file_as_string(path)
		for call in ["displace(", "apply_stun(", "add_speed_modifier(", "add_next_attack_modifier(", "CritRoll.new(", "HitPipeline.resolve("]:
			if src.contains(call):
				offenders.append("%s: %s" % [path.get_file(), call])
	_check("no displace / apply_stun / add_speed_modifier / add_next_attack_modifier / own crit roll or resolve", offenders, [] as Array[String])


# --- AB12 -----------------------------------------------------------------------

func _cond(kind: Condition.Kind, props: Dictionary = {}) -> Condition:
	var c := Condition.new()
	c.kind = kind
	for key: String in props:
		c.set(key, props[key])
	return c


func _test_ab12_condition_kinds() -> void:
	_section("AB12: the Condition kinds")
	knight.heal(10000.0)
	var a := _dummy_at(Vector2(60, 0))
	var far := _dummy_at(Vector2(400, 0))
	a.status_component.apply_status(STATUS_MARK, knight)
	var stacking := _status(&"test_stacks", [&"test_stack"], 5.0)
	stacking.stack_rule = StatusEffect.StackRule.STACK
	stacking.max_stacks = 3
	a.status_component.apply_status(stacking)
	a.status_component.apply_status(stacking)
	_check("get_tag_stacks: stacks summed per tag (a status without stacks counts 1)",
		[a.status_component.get_tag_stacks(&"test_stack"), a.status_component.get_tag_stacks(&"test_mark"), a.status_component.get_tag_stacks(&"nope")], [2, 1, 0])
	var has := _cond(Condition.Kind.TARGET_HAS_STATUS, {"status_tag": &"test_stack", "min_stacks": 2})
	var has3 := _cond(Condition.Kind.TARGET_HAS_STATUS, {"status_tag": &"test_stack", "min_stacks": 3})
	_check("TARGET_HAS_STATUS: 2 stacks meet 2, not 3", [has.is_met(knight, a), has3.is_met(knight, a)], [true, false])
	var not_has := _cond(Condition.Kind.TARGET_HAS_STATUS, {"status_tag": &"test_stack", "negate": true})
	_check("negate flips it; with no target a TARGET_ kind fails even negated", [not_has.is_met(knight, a), not_has.is_met(knight, null), not_has.is_met(knight, far)], [false, false, true])
	var self_has := _cond(Condition.Kind.SELF_HAS_STATUS, {"status_tag": &"test_focus"})
	var before := self_has.is_met(knight, null)
	knight.status_component.apply_status(STATUS_FOCUS, knight)
	_check("SELF_HAS_STATUS: off, then on (needs no target)", [before, self_has.is_met(knight, null)], [false, true])
	knight.status_component.remove_status(STATUS_FOCUS.id)
	var hp := a.health.max_health
	a.health.take_damage(hp * 0.75)
	var low := _cond(Condition.Kind.TARGET_HEALTH_PERCENT, {"comparison": Condition.Comparison.LESS_THAN, "value": 0.3})
	var high := _cond(Condition.Kind.TARGET_HEALTH_PERCENT, {"value": 0.3})
	_check("TARGET_HEALTH_PERCENT at 25%: < 30% yes, >= 30% no", [low.is_met(knight, a), high.is_met(knight, a)], [true, false])
	var self_high := _cond(Condition.Kind.SELF_HEALTH_PERCENT, {"value": 0.9})
	_check("SELF_HEALTH_PERCENT: the Knight at full health is >= 90%", self_high.is_met(knight, null), true)
	var close := _cond(Condition.Kind.TARGET_DISTANCE, {"comparison": Condition.Comparison.LESS_THAN, "value": 300.0})
	_check("TARGET_DISTANCE < 300 u: the near dummy yes, the far one no", [close.is_met(knight, a), close.is_met(knight, far)], [true, false])
	var two_near := _cond(Condition.Kind.ENEMIES_IN_RANGE, {"count": 2, "radius": 300.0})
	var one_marked := _cond(Condition.Kind.ENEMIES_IN_RANGE, {"count": 1, "radius": 300.0, "status_tag": &"test_mark"})
	var two_far := _cond(Condition.Kind.ENEMIES_IN_RANGE, {"count": 2, "radius": 2000.0})
	_check("ENEMIES_IN_RANGE: 1 near (not 2), 1 marked near, 2 within 2000 u",
		[two_near.is_met(knight, null), one_marked.is_met(knight, null), two_far.is_met(knight, null)], [false, true, true])
	var mana := _cond(Condition.Kind.RESOURCE_AT_LEAST, {"value": 50.0})
	_check("RESOURCE_AT_LEAST 50: the Knight yes, a slime (no pool) no", [mana.is_met(knight, null), mana.is_met(a, null)], [true, false])
	var last_hit := _cond(Condition.Kind.LAST_PART_HIT)
	var ctx := CastContext.new()
	var outside := last_hit.is_met(knight, null, ctx)
	ctx.last_part_hit = true
	_check("LAST_PART_HIT reads the cast: false outside a sequence, true when set, false without a cast",
		[outside, last_hit.is_met(knight, null, ctx), last_hit.is_met(knight, null)], [false, true, false])
	var list: Array[Condition] = [self_high, close, has3]
	var empty: Array[Condition] = []
	has3.fail_text = "Needs 3 stacks"
	_check("all_met is AND (an empty list passes); first_failed gives the failing one's text",
		[Condition.all_met(list, knight, a), Condition.all_met(empty, knight, null), Condition.first_failed(list, knight, a).fail_text], [false, true, "Needs 3 stacks"])
	var cast := CastContext.new()
	cast.charge = 0.3
	cast.set_input(&"custom", 1.7)
	_check("CastContext: charge is a wrapper over inputs; set_input clamps to 0-1",
		[snappedf(cast.get_input(&"charge"), 0.01), snappedf(cast.charge, 0.01), cast.get_input(&"custom"), cast.get_input(&"missing", 0.25)], [0.3, 0.3, 1.0, 0.25])
	_check("every existing ChargeScaling reads charge (the default input)",
		CHARGED_LINE.charge_scalings.all(func(s: ChargeScaling) -> bool: return s.input == &"charge"), true)
	a.queue_free()
	far.queue_free()


func _test_ab12_cast_condition() -> void:
	_section("AB12: a cast condition (Nova needs Focus)")
	await _reset_knight()
	var ab := knight.abilities
	var original_q := ab.q
	ab.q = NOVA
	ab.reset_cooldown(&"q")
	knight.stats_component.add_modifier(StatModifier.create(&"resource_cost", StatModifier.Type.FLAT, 20.0, &"item_test_nova_cost", &"ability:test_nova"))
	var hud: CanvasLayer = HUD_SCENE.instantiate()
	add_child(hud)
	hud.setup_abilities(knight)
	await _frames(2)
	var bar: Control = hud.get_node("AbilityBar")
	var fails: Array = []
	var on_fail := func(_slot: StringName, reason: String) -> void: fails.append(reason)
	ab.cast_failed.connect(on_fail)
	var started := [0]
	var on_started := func(_s: StringName, _a: Ability, _c: CastContext) -> void: started[0] += 1
	ab.cast_started.connect(on_started)

	_check("without Focus: the fail reason is 'condition', with its fail text",
		[ab.get_fail_reason(&"q"), ab.get_condition_fail_text(&"q")], [AbilityComponent.FAIL_CONDITION, "Needs Focus"])
	_check("the slot is greyed", bar.is_condition_greyed(&"q"), true)
	var mana := knight.resource_pool.current
	knight.request_cast(&"q")
	_check("a press fails at once with 'condition', flashes the slot, spends nothing",
		[fails, bar.is_flashing(&"q"), knight.resource_pool.current == mana, ab.is_ready(&"q"), ab.get_charges(&"q")],
		[[AbilityComponent.FAIL_CONDITION], true, true, true, 1])
	_check("and isn't buffered", knight.player_input.get_buffered_action(), &"")
	knight.status_component.apply_status(STATUS_FOCUS, knight)
	_check("Focus applied: un-greyed the same frame, the reason clears", [bar.is_condition_greyed(&"q"), ab.get_fail_reason(&"q")], [false, ""])
	await _frames(10)
	_check("nothing fired later (the failed press wasn't kept)", started[0], 0)
	var dummy := _dummy_at(Vector2(40, 0))
	_tough(dummy)
	knight.request_cast(&"q")
	await _wait_until(func() -> bool: return not ab.casting, 30)
	_check("with Focus the press casts (cost paid, the dummy hit)",
		[started[0], snappedf(mana - knight.resource_pool.current, 1.0) >= 19.0, dummy.health.current < dummy.health.max_health], [1, true, true])
	knight.status_component.remove_status(STATUS_FOCUS.id)
	_check("Focus gone: greyed again (once ready)", [ab.is_ready(&"q"), bar.is_condition_greyed(&"q")], [false, false])
	await _wait_until(func() -> bool: return ab.is_ready(&"q"), 120)
	_check("ready again without Focus: greyed", bar.is_condition_greyed(&"q"), true)

	ab.cast_failed.disconnect(on_fail)
	ab.cast_started.disconnect(on_started)
	knight.stats_component.remove_modifiers_from(&"item_test_nova_cost")
	knight.resource_pool.restore(1000.0)
	hud.queue_free()
	dummy.queue_free()
	await _frames(3)
	ab.q = original_q


func _test_ab12_bonus_and_input() -> void:
	_section("AB12: a conditional bonus (checked at the effect) and a named input")
	await _reset_knight()
	var ab := knight.abilities
	var original_q := ab.q
	ab.q = NOVA
	ab.reset_cooldown(&"q")
	knight.status_component.apply_status(STATUS_FOCUS, knight)
	var hits: Array[HitContext] = []
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.source == knight and ctx.ability == NOVA:
			hits.append(ctx)
	Events.unit_hit.connect(on_hit)
	var slime_r := 55.0 * 0.32
	var edge := _dummy_at(Vector2(64.0 + slime_r + 12.0, 0))   # outside 200 u, inside 300 u
	_tough(edge)
	await _frames(2)
	_check("the tooltip lists the bonus", NOVA.get_tooltip_plain(knight).contains("+50% radius while 2 or more enemies are within 300 units."), true)

	ab.try_cast(&"q", knight.global_position)
	await _wait_until(func() -> bool: return not ab.casting, 30)
	_check("one enemy near: no bonus, the edge dummy (outside 200 u) isn't hit", hits.size(), 0)
	_check("(the radius as the effect reads it: 200 u)", NOVA.get_effect_param(knight, &"radius", null), 200.0)

	ab.reset_cooldown(&"q")
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 60)
	ab.try_cast(&"q", knight.global_position)
	var near := _dummy_at(Vector2(0, 30))   # joins during the cast time: checked at the effect, not at the press
	_tough(near)
	await _wait_until(func() -> bool: return not ab.casting, 30)
	_check("a second enemy arrives during the cast time: +50% radius at the effect, both hit",
		[hits.size(), hits.any(func(h: HitContext) -> bool: return h.target == edge)], [2, true])
	_check("(the radius with two enemies near: 300 u)", NOVA.get_effect_param(knight, &"radius", null), 300.0)

	# The named input self_missing_health scales base_damage (0.5 at full health).
	_check("at full health: 60 x 0.5 = 30", snappedf(hits[0].raw_damage, 0.01) if hits.size() > 0 else 0.0, 30.0)
	knight.health.take_damage(knight.health.max_health * 0.5)
	hits.clear()
	ab.reset_cooldown(&"q")
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 60)
	ab.try_cast(&"q", knight.global_position)
	await _wait_until(func() -> bool: return not ab.casting, 30)
	_check("at half health (input 0.5): 60 x lerp(0.5, 1, 0.5) = 45", snappedf(hits[0].raw_damage, 0.01) if hits.size() > 0 else 0.0, 45.0)
	_check("the tooltip shows the plain full value (60)", NOVA.get_tooltip_plain(knight).contains("up to 60 magic"), true)
	knight.heal(10000.0)

	Events.unit_hit.disconnect(on_hit)
	knight.status_component.remove_status(STATUS_FOCUS.id)
	edge.queue_free()
	near.queue_free()
	await _frames(3)
	ab.q = original_q


func _test_ab12_condition_target() -> void:
	_section("AB12: the condition target of a cast that doesn't pick one")
	await _reset_knight()
	var ab := knight.abilities
	var original_q := ab.q
	var needs_mark: Ability = STRIKE.duplicate()
	needs_mark.id = &"test_strike_needs_mark"
	var cond := _cond(Condition.Kind.TARGET_HAS_STATUS, {"status_tag": &"test_mark", "fail_text": "No mark"})
	var conds: Array[Condition] = [cond]
	needs_mark.cast_conditions = conds
	ab.q = needs_mark
	ab.reset_cooldown(&"q")
	var marked := _dummy_at(Vector2(80, -40))
	var plain := _dummy_at(Vector2(80, 40))
	marked.status_component.apply_status(STATUS_MARK, knight)
	await _frames(2)
	_check("aimed near the marked dummy: passes; near the unmarked one: 'condition'",
		[ab.get_fail_reason(&"q", marked.global_position), ab.get_fail_reason(&"q", plain.global_position)], ["", AbilityComponent.FAIL_CONDITION])
	var ctx_hits: Array = []
	var on_cast := func(_u: Unit, _a: Ability, c: CastContext) -> void: ctx_hits.append(c.target)
	Events.ability_cast.connect(on_cast)
	ab.try_cast(&"q", marked.global_position)
	await _wait_until(func() -> bool: return not ab.casting, 30)
	_check("the cast's ctx.target is that condition target (the enemy nearest the aim in range)", ctx_hits, [marked])
	Events.ability_cast.disconnect(on_cast)
	_place(marked, knight.global_position + Vector2(600, 0))
	_place(plain, knight.global_position + Vector2(620, 0))
	ab.reset_cooldown(&"q")
	await _frames(2)
	cond.negate = true
	_check("no enemy within cast range: a TARGET_ condition fails even negated", ab.get_fail_reason(&"q", knight.global_position + Vector2(80, 0)), AbilityComponent.FAIL_CONDITION)
	marked.queue_free()
	plain.queue_free()
	await _frames(3)
	ab.q = original_q


func _test_ab12_recast() -> void:
	_section("AB12: recast conditions (ENEMIES_IN_RANGE with a tag, LAST_PART_HIT)")
	await _reset_knight()
	var ab := knight.abilities
	var original_q := ab.q
	ab.q = MARK_STRIKE
	ab.reset_cooldown(&"q")
	var dummy := _dummy_at(Vector2(60, 0))
	_tough(dummy)
	await _frames(2)
	var hits: Array[HitContext] = []
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.source == knight and ctx.ability == MARK_STRIKE:
			hits.append(ctx)
	Events.unit_hit.connect(on_hit)
	var fails: Array = []
	var on_fail := func(_slot: StringName, reason: String) -> void: fails.append(reason)
	ab.cast_failed.connect(on_fail)

	# Part 0 hits and marks: the recast works.
	ab.try_cast(&"q", dummy.global_position)
	await _wait_until(func() -> bool: return not ab.casting, 30)
	_check("part 0 hits and marks the dummy; the window opens",
		[hits.size(), dummy.status_component.has_status(&"test_mark"), ab.get_recast_part(&"q")], [1, true, 1])
	_check("recast conditions pass (a marked enemy in range, part 0 hit)", ab.get_fail_reason(&"q"), "")
	ab.try_cast(&"q", dummy.global_position)
	await _wait_until(func() -> bool: return not ab.casting, 30)
	_check("part 1 strikes the marked dummy and removes the mark; the sequence ends",
		[hits.size(), hits[1].target == dummy if hits.size() > 1 else false, dummy.status_component.has_status(&"test_mark"), ab.get_recast_part(&"q")],
		[2, true, false, 0])

	# LAST_PART_HIT: part 0 misses while an old mark is still on the dummy.
	await _frames(2)   # the recharge starts the frame after a sequence ends
	ab.reset_cooldown(&"q")
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 60)
	dummy.status_component.apply_status(STATUS_MARK, knight)
	hits.clear()
	fails.clear()
	ab.try_cast(&"q", knight.global_position + Vector2(-60, 0))   # nobody there
	await _wait_until(func() -> bool: return not ab.casting, 30)
	_check("part 0 missed (a marked enemy is still in range): 'condition', text 'The first strike missed'",
		[hits.size(), ab.get_fail_reason(&"q"), ab.get_condition_fail_text(&"q")], [0, AbilityComponent.FAIL_CONDITION, "The first strike missed"])
	var left := ab.get_recast_time_left(&"q")
	ab.try_cast(&"q", dummy.global_position)
	_check("the press fails with 'condition'; the window stays open", [fails, ab.get_recast_part(&"q"), ab.get_recast_time_left(&"q") == left], [[AbilityComponent.FAIL_CONDITION], 1, true])
	await _wait_until(func() -> bool: return ab.get_recast_part(&"q") == 0, 240)
	_check("the window runs out normally, then the cooldown starts", [ab.get_recast_part(&"q"), ab.is_ready(&"q")], [0, false])

	# ENEMIES_IN_RANGE with the tag: part 0 hits, but the mark is gone.
	await _frames(2)
	ab.reset_cooldown(&"q")
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 60)
	dummy.status_component.remove_status(&"test_mark")
	ab.try_cast(&"q", dummy.global_position)
	await _wait_until(func() -> bool: return not ab.casting, 30)
	dummy.status_component.remove_status(&"test_mark")
	_check("part 0 hit but no marked enemy in range: 'condition', text 'No marked enemy in range'",
		[ab.get_fail_reason(&"q"), ab.get_condition_fail_text(&"q")], [AbilityComponent.FAIL_CONDITION, "No marked enemy in range"])
	dummy.status_component.apply_status(STATUS_MARK, knight)
	_check("marked again: the recast passes", ab.get_fail_reason(&"q"), "")

	Events.unit_hit.disconnect(on_hit)
	ab.cast_failed.disconnect(on_fail)
	dummy.queue_free()
	await _frames(3)
	ab.reset_cooldown(&"q")
	await _wait_until(func() -> bool: return ab.get_recast_part(&"q") == 0, 240)
	ab.q = original_q


func _test_ab12_reaction_condition() -> void:
	_section("AB12: a fake item with a Condition in its reaction rule (execute below 30%)")
	await _reset_knight()
	var dummy := _dummy_at(Vector2(60, 0))
	_tough(dummy)
	await _frames(2)
	knight.add_reaction_rule(EXECUTE_RULE, &"item_test_execute")
	var executes: Array[HitContext] = []
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.has_tag(&"execute"):
			executes.append(ctx)
	Events.unit_hit.connect(on_hit)
	HitPipeline.resolve(HitPipeline.from_ability(knight, STRIKE, dummy))
	_check("a hit on a healthy dummy: no execute", executes.size(), 0)
	dummy.health.take_damage(dummy.health.current - dummy.health.max_health * 0.25)
	HitPipeline.resolve(HitPipeline.from_ability(knight, STRIKE, dummy))
	_check("a hit on a dummy below 30%: one 30 execute proc (its own hit doesn't chain)",
		[executes.size(), executes[0].raw_damage if executes.size() > 0 else 0.0, executes[0].has_tag(&"proc") if executes.size() > 0 else false], [1, 30.0, true])
	knight.remove_reaction_rules_from(&"item_test_execute")
	executes.clear()
	HitPipeline.resolve(HitPipeline.from_ability(knight, STRIKE, dummy))
	_check("unequipped: no execute", executes.size(), 0)
	Events.unit_hit.disconnect(on_hit)
	dummy.queue_free()
	await _frames(3)


# --- AB13 -----------------------------------------------------------------------

func _setup_vector_line(ability: Ability) -> Ability:
	await _reset_knight()
	var original_q := knight.abilities.q
	knight.abilities.q = ability
	knight.stats_component.remove_modifiers_from(COST_SOURCE)
	_add_costs({&"test_vector_line": 40.0})
	await _wait_until(func() -> bool: return knight.abilities.can_cast(&"q"), 300)
	knight.resource_pool.restore(1000.0)
	return original_q


## The last q cast's context in `ctxs`, or an empty one (so a failed check
## reads as a FAIL, not a script error).
func _last_ctx(ctxs: Array[CastContext]) -> CastContext:
	return ctxs.back() if not ctxs.is_empty() else CastContext.new()


func _test_ab13_data() -> void:
	_section("AB13: VECTOR data")
	_check("VECTOR is added last in CastStyle", [Ability.CastStyle.VECTOR, Ability.CastStyle.keys().back()], [3, "VECTOR"])
	var plain := Ability.new()
	_check("defaults: vector_length 500, vector_width 75, vector_min_drag_px 8 (160 px long, 24 px wide)",
		[plain.vector_length, plain.vector_width, plain.vector_min_drag_px, snappedf(Units.to_px(plain.vector_length), 0.01), snappedf(Units.to_px(plain.vector_width), 0.01)],
		[500.0, 75.0, 8.0, 160.0, 24.0])
	var v := VECTOR_LINE
	_check("test_vector_line: VECTOR, POINT, start range 500, length 500, width 75, a tap under 8 px",
		[v.cast_style, v.targeting, v.cast_range, v.vector_length, v.vector_width, v.vector_min_drag_px],
		[Ability.CastStyle.VECTOR, Ability.Targeting.POINT, 500.0, 500.0, 75.0, 8.0])
	_check("its 0.2 s release windup, 2 s hold limit (FIRE), walking at x0.6 (not rooted), dash-cancelable, 3 s cooldown",
		[v.cast_time, v.overhold_time, v.overhold, v.roots_during_cast, v.cast_move_speed_multiplier, v.dash_cancelable, v.cooldown],
		[0.2, 2.0, Ability.Overhold.FIRE, false, 0.6, true, 3.0])
	_check("the role and style tags (core, line, vector) on both test abilities",
		[v.get_role(), &"line" in v.tags, &"vector" in v.tags, VECTOR_WALL.get_role(), &"line" in VECTOR_WALL.tags, &"vector" in VECTOR_WALL.tags],
		[&"core", true, true, &"core", true, true])
	var styles_match := true
	for a: Ability in [CLEAVE, IRON_RESOLVE, LUNGE, JUDGEMENT, SLAM, CHARGED_LINE, VECTOR_LINE, VECTOR_WALL]:
		styles_match = styles_match \
			and ((&"vector" in a.tags) == (a.cast_style == Ability.CastStyle.VECTOR)) \
			and ((&"charge_up" in a.tags) == (a.cast_style == Ability.CastStyle.CHARGE_UP)) \
			and ((&"channel" in a.tags) == (a.cast_style == Ability.CastStyle.CHANNEL))
	_check("style tags match cast_style (vector, charge_up, channel)", styles_match, true)
	_check("no Knight ability or the slam is VECTOR",
		[CLEAVE, IRON_RESOLVE, LUNGE, JUDGEMENT, SLAM].any(func(a: Ability) -> bool: return a.cast_style == Ability.CastStyle.VECTOR), false)
	_check("the wall: VECTOR, POINT, 0.7 s cast time, 100 physical, 6 s cooldown",
		[VECTOR_WALL.cast_style, VECTOR_WALL.targeting, VECTOR_WALL.cast_time, VECTOR_WALL.base_damage, VECTOR_WALL.damage_type, VECTOR_WALL.cooldown],
		[Ability.CastStyle.VECTOR, Ability.Targeting.POINT, 0.7, 100.0, HitContext.DamageType.PHYSICAL, 6.0])
	_check("its tooltip", v.get_tooltip_plain(knight),
		"Press to place the start up to 500 units away, drag to aim, release: a 500-unit line deals 92 magic damage (60 +50% AD) to every enemy on it. A tap lays it from you through the start. Held 2s, it fires on its own.")
	var c := CastContext.new()
	_check("CastContext's vector fields (defaults: start 0, direction right, end 0)",
		[c.vector_start, c.vector_direction, c.vector_end], [Vector2.ZERO, Vector2.RIGHT, Vector2.ZERO])


func _test_ab13_drag_and_tap() -> void:
	_section("AB13: a drag and a tap (test_vector_line)")
	var ab := knight.abilities
	var pool := knight.resource_pool
	var original_q: Ability = await _setup_vector_line(VECTOR_LINE)
	var ctxs: Array[CastContext] = []
	var on_started := func(slot: StringName, _a: Ability, ctx: CastContext) -> void:
		if slot == &"q":
			ctxs.append(ctx)
	ab.cast_started.connect(on_started)
	var hits: Array[HitContext] = []
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.ability != null and ctx.ability.id == &"test_vector_line":
			hits.append(ctx)
	Events.unit_hit.connect(on_hit)
	var k := knight.global_position
	var start := k + Vector2(100, 0)
	var below := _dummy_at(Vector2(100, 120))   # on a line dragged down from the start
	var beyond := _dummy_at(Vector2(200, 0))    # past the start, on the caster -> start line
	await _frames(1)

	_check("press: the aim starts", ab.try_start_charge(&"q", start), true)
	_check("the start point at the cursor; charge 1 from the press; the 40 paid; no charge or cooldown taken yet",
		[ab.is_charging(), ab.get_vector_start() == start, ab.get_charge(), pool.current, ab.get_charges(&"q"), ab.get_cooldown_left(&"q")],
		[true, true, 1.0, 260.0, 1, 0.0])
	_check("walking while aiming: not rooted, at x0.6 (one move_speed modifier)",
		[knight.movement.can_move(), knight.stats_component.get_modifiers_from(AbilityComponent.CAST_MOVE_SPEED_SOURCE).size()], [true, 1])
	await _frames(30)
	_check_near("0.5 s held: the hold limit counts from the press (1.5 s of 2 left)", ab.get_overhold_left(), 1.5, 0.05)

	ab.release_charge(start + Vector2(0, 100))
	var ctx := _last_ctx(ctxs)
	_check("release, dragged 100 px down: the line runs down from the start, 160 px long",
		[ctx.vector_start == start, ctx.vector_direction.is_equal_approx(Vector2.DOWN), ctx.vector_end.is_equal_approx(start + Vector2(0, 160))],
		[true, true, true])
	_check("point = the start, direction = caster -> start; vector_drag 100 / 160; charge 1",
		[ctx.point == start, ctx.direction.is_equal_approx(Vector2.RIGHT), snappedf(ctx.get_input(&"vector_drag"), 0.001), ctx.charge],
		[true, true, 0.625, 1.0])
	_check("the charge and the 3 s cooldown are taken at release; the windup starts; the indicator stays, locked",
		[ab.get_charges(&"q"), snappedf(ab.get_cooldown_left(&"q"), 0.01), hits.size(), ab.has_charge_indicator(), ab.get_vector_start() == start, ab.get_locked_charge_aim() == start + Vector2(0, 100)],
		[0, 3.0, 0, true, true, true])
	await _wait_until(func() -> bool: return not ab.casting, 30)
	_check("after the 0.2 s windup: only the dummy on the line is hit, for 92 magic (60 + 50% of 64 AD)",
		[hits.size(), hits[0].target == below if hits.size() == 1 else false, hits[0].raw_damage if hits.size() == 1 else -1.0, hits[0].damage_type if hits.size() == 1 else -1],
		[1, true, 92.0, HitContext.DamageType.MAGIC])
	_check("its hits carry vector and line; the indicator, the start point and the walking modifier are gone",
		[hits[0].has_tag(&"vector") if hits.size() == 1 else false, hits[0].has_tag(&"line") if hits.size() == 1 else false, ab.has_charge_indicator(), ab.get_vector_start(), knight.stats_component.get_modifiers_from(AbilityComponent.CAST_MOVE_SPEED_SOURCE).size()],
		[true, true, false, Vector2.INF, 0])

	# A tap: released under 8 px from the start.
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 300)
	pool.restore(1000.0)
	hits.clear()
	ab.try_start_charge(&"q", start)
	ab.release_charge(start + Vector2(5, 3))
	ctx = _last_ctx(ctxs)
	_check("a tap (released 6 px from the start): direction caster -> start, vector_drag 0",
		[ctx.vector_direction.is_equal_approx(Vector2.RIGHT), ctx.vector_end.is_equal_approx(start + Vector2(160, 0)), ctx.get_input(&"vector_drag")],
		[true, true, 0.0])
	await _wait_until(func() -> bool: return not ab.casting, 30)
	_check("only the dummy past the start is hit", [hits.size(), hits[0].target == beyond if hits.size() == 1 else false], [1, true])

	# vector_drag as a named input: base damage from 50% (a tap) to 100% (a full drag).
	var scaled: Ability = VECTOR_LINE.duplicate()   # same id: the scoped 40 cost applies
	var s := ChargeScaling.new()
	s.param = &"base_damage"
	s.input = &"vector_drag"
	s.min_fraction = 0.5
	var scalings: Array[ChargeScaling] = [s]
	scaled.charge_scalings = scalings
	ab.q = scaled
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 300)
	pool.restore(1000.0)
	hits.clear()
	ab.try_start_charge(&"q", start)
	ab.release_charge(start + Vector2(0, 100))
	await _wait_until(func() -> bool: return not ab.casting, 30)
	_check("a ChargeScaling on vector_drag: 60 x (0.5 + 0.5 x 0.625) + 32 = 80.75",
		[hits.size(), hits[0].raw_damage if hits.size() == 1 else -1.0], [1, 80.75])

	ab.cast_started.disconnect(on_started)
	Events.unit_hit.disconnect(on_hit)
	below.queue_free()
	beyond.queue_free()
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 300)
	ab.q = original_q


func _test_ab13_start_point() -> void:
	_section("AB13: the start point (range, walls, a tap on the caster)")
	var ab := knight.abilities
	var original_q: Ability = await _setup_vector_line(VECTOR_LINE)
	var k := knight.global_position
	ab.try_start_charge(&"q", k + Vector2(400, 0))
	_check("a cursor 400 px away: the start is clamped to cast_range (160 px)", ab.get_vector_start().is_equal_approx(k + Vector2(160, 0)), true)
	ab.try_cancel_charge()
	var wall := _wall_at(k + Vector2(60, 0), Vector2(10, 100))
	await _frames(2)
	ab.try_start_charge(&"q", k + Vector2(100, 0))
	_check_near("a wall in the way (its face at 55 px): the start stops at its face (53 px: the 2 px core)", ab.get_vector_start().x - k.x, 53.0, 0.5)
	ab.try_cancel_charge()
	ab.try_start_charge(&"q", k + Vector2(60, 0))
	_check_near("a cursor inside the wall: the same", ab.get_vector_start().x - k.x, 53.0, 0.5)
	ab.try_cancel_charge()
	var through: Ability = VECTOR_LINE.duplicate()
	through.ignores_walls = true
	ab.q = through
	ab.try_start_charge(&"q", k + Vector2(100, 0))
	_check("ignores_walls: the start stays at the cursor", ab.get_vector_start() == k + Vector2(100, 0), true)
	ab.try_cancel_charge()
	ab.q = VECTOR_LINE
	wall.queue_free()
	await _frames(2)

	# The start on the caster and a release on it: a tap along the facing.
	var ctxs: Array[CastContext] = []
	var on_started := func(slot: StringName, _a: Ability, ctx: CastContext) -> void:
		if slot == &"q":
			ctxs.append(ctx)
	ab.cast_started.connect(on_started)
	k = knight.global_position
	ab.try_start_charge(&"q", k)
	knight.facing = Vector2.UP
	ab.release_charge(k)
	var ctx := _last_ctx(ctxs)
	_check("start and release on the caster: a tap along the caster's facing (up)",
		[ctx.vector_start == k, ctx.vector_direction.is_equal_approx(Vector2.UP), ctx.vector_end.is_equal_approx(k + Vector2(0, -160)), ctx.get_input(&"vector_drag")],
		[true, true, true, 0.0])
	await _wait_until(func() -> bool: return not ab.casting, 30)
	ab.cast_started.disconnect(on_started)
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 300)
	ab.q = original_q


func _test_ab13_hold_limit() -> void:
	_section("AB13: the hold limit (overhold_time from the press) and the orange bar")
	var ab := knight.abilities
	var pool := knight.resource_pool
	var original_q: Ability = await _setup_vector_line(VECTOR_LINE)
	var hud: CanvasLayer = HUD_SCENE.instantiate()
	add_child(hud)
	hud.setup_abilities(knight)
	var bar: Control = hud.get_node("AbilityBar")
	var released: Array = []
	var on_released := func(_slot: StringName, _a: Ability, charge: float) -> void: released.append(charge)
	ab.charge_released.connect(on_released)
	var start := knight.global_position + Vector2(100, 0)

	ab.try_start_charge(&"q", start)
	_check("at the press: charge 1, the whole 2 s of hold limit left", [ab.get_charge(), snappedf(ab.get_overhold_left(), 0.01)], [1.0, 2.0])
	await _frames(60)
	_check("1 s held: still aiming, 1 s left, the charge bar shows (its orange part: the charge is 1)",
		[ab.is_charging(), snappedf(ab.get_overhold_left(), 0.05), bar._drawn_charge_bar_slot], [true, 1.0, &"q"])
	await _frames(65)
	_check("after 2 s: fired by itself (FIRE)", [ab.is_charging(), released, ab.get_charges(&"q")], [false, [1.0], 0])
	await _wait_until(func() -> bool: return not ab.casting, 30)

	var cancel_line: Ability = VECTOR_LINE.duplicate()
	cancel_line.overhold = Ability.Overhold.CANCEL_REFUND
	ab.q = cancel_line
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 300)
	pool.restore(1000.0)
	ab.try_start_charge(&"q", start)
	await _frames(125)
	_check("CANCEL_REFUND after 2 s: cancelled, the 40 back, still ready, nothing fired, the start point gone",
		[ab.is_charging(), ab.casting, pool.current, ab.is_ready(&"q"), released.size(), ab.get_vector_start()],
		[false, false, 300.0, true, 1, Vector2.INF])

	ab.charge_released.disconnect(on_released)
	hud.queue_free()
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 300)
	ab.q = original_q


## Every way a VECTOR aim ends clears the start marker and the line, the bar
## and the sound, through the one end-charge path (charge_ended once).
func _test_ab13_exits() -> void:
	_section("AB13: every way a vector aim ends clears the indicator, the bar and the sound")
	var ab := knight.abilities
	var line: Ability = VECTOR_LINE.duplicate()   # same id: the scoped 40 cost applies
	line.charge_sound = LOOP_SOUND
	line.overhold_time = 0.2
	var original_q: Ability = await _setup_vector_line(line)
	var hud: CanvasLayer = HUD_SCENE.instantiate()
	add_child(hud)
	hud.setup_abilities(knight)
	var bar: Control = hud.get_node("AbilityBar")
	var ended := [0]
	var on_ended := func(_slot: StringName, _a: Ability) -> void: ended[0] += 1
	ab.charge_ended.connect(on_ended)
	var start := knight.global_position + Vector2(100, 0)

	_exit_line = line
	_exit_aim = start + Vector2(0, 60)   # a drag down from the start
	var exits := [
		["release (after its windup)", _exit_release],
		["the hold limit, FIRE (after its windup)", _exit_overhold_fire],
		["the hold limit, CANCEL_REFUND", _exit_overhold_cancel],
		["Esc", _exit_esc],
		["a stun", _exit_stun],
		["a dash", _exit_dash],
		["a move press (a channel vector)", _exit_move],
		["the slot swapped mid-aim (a REPLACE), then release", _exit_swap],
		["a lost key release (the Player's own aim)", _exit_lost_release],
	]
	for exit: Array in exits:
		var label: String = exit[0]
		await _wait_until(func() -> bool: return ab.can_cast(&"q") and not knight.is_stunned() and knight.dash.can_dash(), 400)
		knight.resource_pool.restore(1000.0)
		line.cancel_on_move = label.begins_with("a move press")
		if label.begins_with("a lost key"):
			Input.action_press(&"ability_q")
			knight._unhandled_input(_action(&"ability_q", true))
		else:
			ab.try_start_charge(&"q", start)
		var handle: int = ab.get("_charge_sound_handle")
		await _frames(3)
		var showing := [ab.has_charge_indicator(), ab.get_vector_start() != Vector2.INF, knight.get_indicator_slot(), knight._drawn_indicator_slot,
			knight._drawn_vector_start != Vector2.INF, bar._drawn_charge_bar_slot, Audio.is_playing(handle)]
		var before: int = ended[0]
		await (exit[1] as Callable).call()
		await _frames(2)
		_check("%s: shown while aiming, then the start marker and line, bar and sound gone, charge_ended once" % label,
			[showing, [ab.has_charge_indicator(), ab.get_vector_start() != Vector2.INF, knight.get_indicator_slot(), knight._drawn_indicator_slot,
				knight._drawn_vector_start != Vector2.INF, bar._drawn_charge_bar_slot, Audio.is_playing(handle)], ended[0] - before],
			[[true, true, &"q", &"q", true, &"q", true], [false, false, &"", &"", false, &"", false], 1])
	line.cancel_on_move = false

	# Death (a second Knight, so this one lives on).
	var other: Player = PLAYER_SCENE.instantiate()
	add_child(other)
	_place(other, knight.global_position + Vector2(0, 300))
	await _frames(1)
	other.abilities.q = line
	var other_ended := [0]
	other.abilities.charge_ended.connect(func(_s: StringName, _a: Ability) -> void: other_ended[0] += 1)
	other.abilities.try_start_charge(&"q", other.global_position + Vector2(100, 0))
	var other_handle: int = other.abilities.get("_charge_sound_handle")
	await _frames(3)
	other.take_damage(100000.0)
	_check("death while aiming: the aim ends at once, the start point gone, sound stopped, charge_ended once",
		[other.abilities.has_charge_indicator(), other.abilities.get_vector_start(), other.abilities.casting, Audio.is_playing(other_handle), other_ended[0]],
		[false, Vector2.INF, false, false, 1])

	ab.charge_ended.disconnect(on_ended)
	hud.queue_free()
	other.queue_free()
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 300)
	ab.q = original_q


func _test_ab13_player_input() -> void:
	_section("AB13: the Player's press, drag and release; a buffered press")
	var ab := knight.abilities
	var original_q: Ability = await _setup_vector_line(VECTOR_LINE)
	var ctxs: Array[CastContext] = []
	var on_started := func(slot: StringName, _a: Ability, ctx: CastContext) -> void:
		if slot == &"q":
			ctxs.append(ctx)
	ab.cast_started.connect(on_started)

	# The cast mode doesn't apply to VECTOR: hold to aim or quick, it's aimed.
	var mode := Settings.get_cast_mode()
	Settings.set_cast_mode(Player.CastMode.QUICK_WITH_INDICATOR)
	Input.action_press(&"ability_q")
	knight._unhandled_input(_action(&"ability_q", true))
	var expected_start := knight.global_position + (knight.get_global_mouse_position() - knight.global_position).limit_length(Units.to_px(500.0))
	_check("press Q (in hold-to-aim mode too): a vector aim, not a hold-to-aim aim; the start at the cursor, clamped",
		[ab.is_charging(), knight.aiming_slot, knight.get_indicator_slot(), ab.get_vector_start().distance_to(expected_start) < 0.5],
		[true, &"", &"q", true])
	await _frames(20)
	_check("held: still aiming; the Player draws the vector indicator from its start point",
		[ab.is_charging(), knight._drawn_vector_start == ab.get_vector_start()], [true, true])
	Input.action_release(&"ability_q")
	knight._unhandled_input(_action(&"ability_q", false))
	_check("release Q: cast (its windup starts)", [ab.is_charging(), ab.casting, ctxs.size()], [false, true, 1])
	Settings.set_cast_mode(mode)
	await _wait_until(func() -> bool: return not ab.casting, 30)

	# A press buffered during Lunge whose key is let go before it fires: a tap.
	await _wait_until(func() -> bool: return ab.can_cast(&"q") and ab.can_cast(&"e"), 600)
	knight.resource_pool.restore(1000.0)
	ab.try_cast(&"e", knight.global_position + Vector2(0, 80))   # Lunge: a cast time and a dash
	knight.request_charge(&"q")
	_check("pressed during Lunge: buffered", knight.player_input.get_buffered_action(), &"q")
	await _wait_until(func() -> bool: return ctxs.size() == 2, 60)
	_check("fired when Lunge ended, as a tap at the cursor (the key wasn't held): vector_drag 0, not aiming",
		[ctxs.size(), _last_ctx(ctxs).get_input(&"vector_drag"), ab.is_charging()], [2, 0.0, false])

	ab.cast_started.disconnect(on_started)
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 300)
	ab.q = original_q


func _test_ab13_recast() -> void:
	_section("AB13: every VECTOR recast part is aimed")
	var ab := knight.abilities
	var pool := knight.resource_pool
	var two_part: Ability = VECTOR_LINE.duplicate()   # same id: the scoped 40 cost applies to part 0
	two_part.recast_count = 1
	two_part.recast_window = 3.0
	two_part.recast_resource_cost = 10.0
	var original_q: Ability = await _setup_vector_line(two_part)
	var ctxs: Array[CastContext] = []
	var on_started := func(slot: StringName, _a: Ability, ctx: CastContext) -> void:
		if slot == &"q":
			ctxs.append(ctx)
	ab.cast_started.connect(on_started)
	var start := knight.global_position + Vector2(100, 0)

	ab.try_start_charge(&"q", start)
	ab.release_charge(start + Vector2(0, 100))
	await _wait_until(func() -> bool: return not ab.casting, 30)
	_check("part 0 cast: the window for part 1 is open", [ab.get_recast_part(&"q"), ab.get_charges(&"q")], [1, 0])
	await _frames(1)
	var mana := pool.current
	Input.action_press(&"ability_q")
	knight._unhandled_input(_action(&"ability_q", true))
	var window_left := ab.get_recast_time_left(&"q")
	_check("press Q in the window: part 1 is aimed (its own start point), not cast at once; it costs 10",
		[ab.is_charging(), ab.get_vector_start() != Vector2.INF, ctxs.size(), snappedf(mana - pool.current, 0.01)], [true, true, 1, 10.0])
	await _frames(30)
	_check("the window doesn't run while part 1 is aimed", ab.get_recast_time_left(&"q"), window_left)
	Input.action_release(&"ability_q")
	knight._unhandled_input(_action(&"ability_q", false))
	_check("release: part 1 is cast", [ctxs.size(), _last_ctx(ctxs).part], [2, 1])
	await _wait_until(func() -> bool: return not ab.casting, 30)
	await _frames(2)
	_check("after the last part: the sequence is over and the cooldown runs", [ab.get_recast_part(&"q"), ab.get_cooldown_left(&"q") > 0.0], [0, true])

	ab.cast_started.disconnect(on_started)
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 300)
	ab.q = original_q


func _test_ab13_without_mouse() -> void:
	_section("AB13: without a mouse (try_cast, try_cast_vector, a free cast, a hold-to-aim slot that became VECTOR)")
	var ab := knight.abilities
	var original_q: Ability = await _setup_vector_line(VECTOR_LINE)
	var ctxs: Array[CastContext] = []
	var on_started := func(slot: StringName, _a: Ability, ctx: CastContext) -> void:
		if slot == &"q":
			ctxs.append(ctx)
	ab.cast_started.connect(on_started)
	var hits: Array[HitContext] = []
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.ability != null and ctx.ability.id == &"test_vector_line":
			hits.append(ctx)
	Events.unit_hit.connect(on_hit)
	var k := knight.global_position
	var start := k + Vector2(100, 0)
	var below := _dummy_at(Vector2(100, 120))
	var beyond := _dummy_at(Vector2(200, 0))
	await _frames(1)

	_check("try_cast() on a VECTOR ability: cast at once, no hold, no indicator",
		[ab.try_cast(&"q", start), ab.is_charging(), ab.has_charge_indicator(), ab.casting], [true, false, false, true])
	var ctx := _last_ctx(ctxs)
	_check("... as a tap: start = the aim, direction caster -> start, vector_drag 0",
		[ctx.vector_start == start, ctx.vector_direction.is_equal_approx(Vector2.RIGHT), ctx.get_input(&"vector_drag")], [true, true, 0.0])
	await _wait_until(func() -> bool: return not ab.casting, 30)
	_check("its line hits the dummy past the start", [hits.size(), hits[0].target == beyond if hits.size() == 1 else false], [1, true])

	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 300)
	knight.resource_pool.restore(1000.0)
	hits.clear()
	_check("try_cast_vector(start, down): cast at once", ab.try_cast_vector(&"q", start, Vector2.DOWN), true)
	ctx = _last_ctx(ctxs)
	_check("... with that start and direction; vector_drag 1 (no drag to measure); no indicator",
		[ctx.vector_start == start, ctx.vector_direction.is_equal_approx(Vector2.DOWN), ctx.vector_end.is_equal_approx(start + Vector2(0, 160)), ctx.get_input(&"vector_drag"), ab.has_charge_indicator()],
		[true, true, true, 1.0, false])
	await _wait_until(func() -> bool: return not ab.casting, 30)
	_check("its line hits the dummy below the start", [hits.size(), hits[0].target == below if hits.size() == 1 else false], [1, true])

	# A free cast (CastAbility): a tap at the aim, clamped as at a press.
	hits.clear()
	var free_ctxs: Array[CastContext] = []
	var on_cast := func(unit: Unit, _a: Ability, c: CastContext) -> void:
		if unit == knight and c.is_free:
			free_ctxs.append(c)
	Events.ability_cast.connect(on_cast)
	_check("a free cast runs at once", ab.try_cast_free(VECTOR_LINE, k + Vector2(400, 0), null, &"item_test_free"), true)
	var fc := _last_ctx(free_ctxs)
	_check("... as a tap from the aim clamped to 160 px: direction caster -> start, vector_drag 0; the dummy past the start is hit",
		[fc.vector_start.is_equal_approx(k + Vector2(160, 0)), fc.vector_direction.is_equal_approx(Vector2.RIGHT), fc.get_input(&"vector_drag"), hits.size()],
		[true, true, 0.0, 1])
	Events.ability_cast.disconnect(on_cast)

	# A hold-to-aim INSTANT aim whose slot became VECTOR: released, it casts the VECTOR ability as a tap.
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 300)
	knight.resource_pool.restore(1000.0)
	var mode := Settings.get_cast_mode()
	Settings.set_cast_mode(Player.CastMode.QUICK_WITH_INDICATOR)
	ab.q = STRIKE
	knight._unhandled_input(_action(&"ability_q", true))
	_check("hold-to-aim on Strike (INSTANT): aiming", knight.aiming_slot, &"q")
	ab.q = VECTOR_LINE   # the slot became VECTOR mid-aim
	var count := ctxs.size()
	knight._unhandled_input(_action(&"ability_q", false))
	_check("released after the slot became VECTOR: the VECTOR ability cast at once as a tap",
		[ctxs.size() - count, _last_ctx(ctxs).ability == VECTOR_LINE, _last_ctx(ctxs).get_input(&"vector_drag"), ab.is_charging()], [1, true, 0.0, false])
	Settings.set_cast_mode(mode)

	await _wait_until(func() -> bool: return not ab.casting, 30)
	ab.cast_started.disconnect(on_started)
	Events.unit_hit.disconnect(on_hit)
	below.queue_free()
	beyond.queue_free()
	knight.stats_component.remove_modifiers_from(COST_SOURCE)
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 300)
	ab.q = original_q


func _test_ab13_enemy() -> void:
	_section("AB13: an enemy VECTOR ability (test_vector_wall) with a line telegraph")
	await _reset_knight()
	var k := knight.global_position
	var t := Telegraph.line(knight, k, k + Vector2(0, 160), 24.0, 0.5)
	_check("Telegraph.line(): placed at the start, its line and width kept, empty at first",
		[t.global_position == k, t.line_vector == Vector2(0, 160), t.width_px, t.get_progress()], [true, true, 24.0, 0.0])
	t.queue_free()

	var elite: Enemy = ELITE_SCENE.instantiate()
	elite.passive = true
	add_child(elite)
	_place(elite, k + Vector2(120, 0))
	await _frames(1)
	var d := Ability.new().get_ai_vector(elite, knight)
	_check("the default get_ai_vector(): start at the target, direction caster -> target",
		[d.start == k, (d.direction as Vector2).is_equal_approx(Vector2.LEFT)], [true, true])
	var w := VECTOR_WALL.get_ai_vector(elite, knight)
	_check("the wall's: across the elite -> player direction, centered on the player (start 80 px to one side)",
		[is_zero_approx((w.direction as Vector2).dot(Vector2.LEFT)), ((w.start as Vector2) + (w.direction as Vector2) * 80.0).is_equal_approx(k)], [true, true])

	elite.abilities.q = null   # only the wall (the slam has its own tests)
	elite.abilities.w = VECTOR_WALL
	var ctxs: Array[CastContext] = []
	var on_started := func(slot: StringName, _a: Ability, c: CastContext) -> void:
		if slot == &"w":
			ctxs.append(c)
	elite.abilities.cast_started.connect(on_started)
	var hits: Array[HitContext] = []
	var on_hit := func(c: HitContext) -> void:
		if c.ability != null and c.ability.id == &"test_vector_wall":
			hits.append(c)
	Events.unit_hit.connect(on_hit)
	var hp := knight.health.current
	elite.passive = false
	await _wait_until(func() -> bool: return elite.abilities.casting, 60)
	var telegraph := _find_telegraph()
	var ctx := _last_ctx(ctxs)
	_check("the elite casts the wall (W) through try_cast_vector(): the line across the player, vector_drag 1",
		[elite.abilities.casting_slot, is_zero_approx(ctx.vector_direction.dot(Vector2.LEFT)), (ctx.vector_start + ctx.vector_direction * 80.0).distance_to(k) < 1.0, ctx.get_input(&"vector_drag")],
		[&"w", true, true, 1.0])
	_check("a line telegraph over the line (24 px wide) during the 0.7 s cast time",
		[telegraph != null, telegraph.line_vector.is_equal_approx(ctx.vector_end - ctx.vector_start) if telegraph != null else false, telegraph.width_px if telegraph != null else 0.0],
		[true, true, 24.0])
	await _wait_until(func() -> bool: return not elite.abilities.casting, 60)
	_check("after the cast time: the player on the line takes one 100 physical hit; the telegraph finishes",
		[hits.size(), hits[0].target == knight if hits.size() == 1 else false, hits[0].raw_damage if hits.size() == 1 else -1.0, knight.health.current < hp, not is_instance_valid(telegraph) or telegraph._finishing],
		[1, true, 100.0, true, true])

	# A stun mid-cast: interrupted, the telegraph goes that frame.
	var first: WeakRef = weakref(telegraph)
	await _wait_until(func() -> bool: return first.get_ref() == null, 30)   # the first one's flash is over
	elite.abilities.reset_cooldown(&"w")
	await _wait_until(func() -> bool: return elite.abilities.casting, 60)
	telegraph = _find_telegraph()
	await _frames(6)
	elite.apply_stun(0.1)
	_check("a stun mid-cast: interrupted at once, cooldown refunded, the telegraph goes that frame",
		[elite.abilities.casting, elite.abilities.is_ready(&"w"), telegraph != null and telegraph.is_queued_for_deletion()], [false, true, true])
	elite.passive = true
	elite.attack.cancel()
	hits.clear()
	await _frames(50)
	_check("no wall lands", hits.size(), 0)

	elite.abilities.cast_started.disconnect(on_started)
	Events.unit_hit.disconnect(on_hit)
	elite.queue_free()
	await _frames(1)


# --- Cleanup pass (2026-09-29) ----------------------------------------------------

## The enemy AI skips a slot whose cast would fail (a failing condition), so
## it neither blocks the slots after it nor emits cast_failed every frame.
func _test_enemy_skips_failing_slot() -> void:
	_section("Enemy AI: a slot that fails its condition doesn't block the next one")
	await _reset_knight()
	var needs_focus: Ability = STRIKE.duplicate()
	needs_focus.id = &"test_strike_needs_focus"
	var focus := Condition.new()
	focus.kind = Condition.Kind.SELF_HAS_STATUS
	focus.status_tag = &"test_focus"
	needs_focus.cast_conditions = [focus]
	var elite: Enemy = ELITE_SCENE.instantiate()
	elite.passive = true
	add_child(elite)
	_place(elite, knight.global_position + Vector2(60, 0))
	elite.abilities.q = needs_focus   # fails: the elite has no Focus
	elite.abilities.w = STRIKE        # works
	await _frames(1)
	_check("Q fails its condition, W can be cast",
		[elite.abilities.get_fail_reason(&"q", knight.global_position, knight), elite.abilities.get_fail_reason(&"w", knight.global_position, knight)],
		[AbilityComponent.FAIL_CONDITION, ""])
	var failed: Array = []
	var on_failed := func(slot: StringName, reason: String) -> void: failed.append([slot, reason])
	elite.abilities.cast_failed.connect(on_failed)
	elite.passive = false
	await _wait_until(func() -> bool: return elite.abilities.casting, 60)
	_check("the AI casts W (Q skipped) and nothing emits cast_failed",
		[elite.abilities.casting, elite.abilities.casting_slot, failed], [true, &"w", []])
	elite.passive = true
	elite.attack.cancel()
	await _wait_until(func() -> bool: return not elite.abilities.casting, 60)
	await _frames(10)
	_check("still no cast_failed after the cast (Q never tried)", failed, [])
	elite.abilities.cast_failed.disconnect(on_failed)
	elite.queue_free()
	await _frames(1)


## CONVENTIONS pattern 6: the vector's length (AbilityComponent) and width
## (the script) are read with get_effect_param(), so one conditional bonus
## lengthens and widens the line.
func _test_bonus_widens_and_lengthens_vector() -> void:
	_section("get_effect_param(): a conditional bonus widens and lengthens a VECTOR line")
	var wide: Ability = VECTOR_LINE.duplicate()
	var focus := Condition.new()
	focus.kind = Condition.Kind.SELF_HAS_STATUS
	focus.status_tag = &"test_focus"
	var bonus := ConditionalBonus.new()
	bonus.conditions = [focus]
	bonus.modifiers = [
		StatModifier.create(&"vector_width", StatModifier.Type.PERCENT_ADD, 1.0, &""),    # 75 -> 150 u (24 -> 48 px)
		StatModifier.create(&"vector_length", StatModifier.Type.PERCENT_ADD, 0.5, &""),   # 500 -> 750 u (160 -> 240 px)
	]
	wide.conditional_bonuses = [bonus]
	var ab := knight.abilities
	var original_q: Ability = await _setup_vector_line(wide)
	var ctxs: Array[CastContext] = []
	var on_started := func(slot: StringName, _a: Ability, ctx: CastContext) -> void:
		if slot == &"q":
			ctxs.append(ctx)
	ab.cast_started.connect(on_started)
	var hit_units: Array = []
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.ability == wide:
			hit_units.append(ctx.target)
	Events.unit_hit.connect(on_hit)
	var start := knight.global_position + Vector2(100, 0)
	# The line goes down from the start. `beside` is 36 px off it (inside only
	# the wide line: 36 - its 17.6 px radius > 12, <= 24); `past` is 220 px
	# along it (past the 160 px end, inside the 240 px one).
	var beside := _dummy_at(Vector2(136, 100))
	var past := _dummy_at(Vector2(100, 220))
	await _frames(1)

	_check("without the bonus: cast", ab.try_cast_vector(&"q", start, Vector2.DOWN), true)
	var ctx := _last_ctx(ctxs)
	_check("... the line is 160 px long", snappedf(ctx.vector_start.distance_to(ctx.vector_end), 0.01), 160.0)
	await _wait_until(func() -> bool: return not ab.casting, 30)
	_check("... neither the dummy beside the line nor the one past its end is hit", hit_units, [])

	ab.reset_cooldown(&"q")
	knight.resource_pool.restore(1000.0)
	knight.status_component.apply_status(STATUS_FOCUS, knight)
	_check("with the bonus (Focus): cast", ab.try_cast_vector(&"q", start, Vector2.DOWN), true)
	ctx = _last_ctx(ctxs)
	_check("... the line is 240 px long (vector_length +50%)", snappedf(ctx.vector_start.distance_to(ctx.vector_end), 0.01), 240.0)
	await _wait_until(func() -> bool: return not ab.casting, 30)
	_check("... and 48 px wide: both dummies are hit",
		[hit_units.size(), hit_units.has(beside), hit_units.has(past)], [2, true, true])

	knight.status_component.remove_status(STATUS_FOCUS.id)
	ab.cast_started.disconnect(on_started)
	Events.unit_hit.disconnect(on_hit)
	beside.queue_free()
	past.queue_free()
	knight.stats_component.remove_modifiers_from(COST_SOURCE)
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 300)
	ab.q = original_q


# --- AB-M -----------------------------------------------------------------------

func _test_abm_data() -> void:
	_section("AB-M: the four augments' data")
	_check("ids, kinds and scopes",
		[[AUG_LUNGE_STUNS.id, AUG_LUNGE_STUNS.kind, AUG_LUNGE_STUNS.scope], [AUG_CLEAVE_WAVE.id, AUG_CLEAVE_WAVE.kind, AUG_CLEAVE_WAVE.scope],
			[AUG_JUDGEMENT_RESET.id, AUG_JUDGEMENT_RESET.kind, AUG_JUDGEMENT_RESET.scope], [AUG_CLEAVE_CASTS_LUNGE.id, AUG_CLEAVE_CASTS_LUNGE.kind, AUG_CLEAVE_CASTS_LUNGE.scope]],
		[[&"lunge_stuns", AbilityAugment.Kind.FLAG, &"ability:knight_lunge"], [&"cleave_wave", AbilityAugment.Kind.REPLACE, &"ability:knight_cleave"],
			[&"judgement_reset", AbilityAugment.Kind.EVENT, &"ability:knight_judgement"], [&"cleave_casts_lunge", AbilityAugment.Kind.EVENT, &"ability:knight_cleave"]])
	_check("Lunge supports lunge_stuns (0.5 s); the wave replaces Cleave", [LUNGE.supported_flags.has(&"lunge_stuns"), LUNGE.get(&"flag_stun_duration"), AUG_CLEAVE_WAVE.replacement == CLEAVE_WAVE], [true, 0.5, true])
	var reset_rule: ReactionRule = AUG_JUDGEMENT_RESET.rules[0] if AUG_JUDGEMENT_RESET.rules.size() == 1 else ReactionRule.new()
	var reset_effect: ModifyCooldownGameplayEffect = reset_rule.effects[0] as ModifyCooldownGameplayEffect if reset_rule.effects.size() == 1 else null
	_check("the reset: UNIT_DIED, on the killer (OTHER), a RESET of knight_judgement's cooldown",
		[reset_rule.trigger, reset_rule.owner_role, reset_rule.effect_target, reset_effect != null, reset_effect.mode if reset_effect else -1, reset_effect.ability_scope if reset_effect else &""],
		[ReactionRule.Trigger.UNIT_DIED, ReactionRule.OwnerRole.SOURCE, ReactionRule.EffectTarget.OTHER, true, ModifyCooldownGameplayEffect.Mode.RESET, &"ability:knight_judgement"])
	var lunge_rule: ReactionRule = AUG_CLEAVE_CASTS_LUNGE.rules[0] if AUG_CLEAVE_CASTS_LUNGE.rules.size() == 1 else ReactionRule.new()
	var lunge_effect: CastAbilityGameplayEffect = lunge_rule.effects[0] as CastAbilityGameplayEffect if lunge_rule.effects.size() == 1 else null
	_check("the also-cast: ABILITY_CAST, on the caster (OTHER), a free Lunge",
		[lunge_rule.trigger, lunge_rule.effect_target, lunge_effect != null and lunge_effect.ability == LUNGE], [ReactionRule.Trigger.ABILITY_CAST, ReactionRule.EffectTarget.OTHER, true])
	_check("the wave: variant_of knight_cleave, core + projectile, 700 u, 150 u wide, pierce 20, 80 + 70% AD, Cleave's 3 s cooldown and 0.2 s cast",
		[CLEAVE_WAVE.variant_of, CLEAVE_WAVE.get_role(), &"projectile" in CLEAVE_WAVE.tags, CLEAVE_WAVE.cast_range, CLEAVE_WAVE.projectile_width, CLEAVE_WAVE.projectile_pierce,
			CLEAVE_WAVE.base_damage, CLEAVE_WAVE.ad_ratio, CLEAVE_WAVE.cooldown, CLEAVE_WAVE.cast_time],
		[&"knight_cleave", &"core", true, 700.0, 150.0, 20, 80.0, 0.7, CLEAVE.cooldown, CLEAVE.cast_time])


func _test_abm_lunge_stuns() -> void:
	_section("AB-M: Lunge stuns (FLAG)")
	await _reset_knight()
	var ab := knight.abilities
	var hits := [0]
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.source == knight and ctx.ability == LUNGE:
			hits[0] += 1
	Events.unit_hit.connect(on_hit)
	var dummy := _dummy_at(Vector2(60, 0))
	_tough(dummy)
	await _frames(2)
	ab.add_augment(AUG_LUNGE_STUNS, &"item_test_lunge_stuns")
	_check("equipped: Lunge has the flag; its tooltip gains the line",
		[ab.get_flags(LUNGE), LUNGE.get_tooltip_plain(knight).ends_with("\nLunge stuns every enemy it hits for 0.5 s.")], [[&"lunge_stuns"] as Array[StringName], true])
	ab.reset_cooldown(&"e")
	ab.try_cast(&"e", knight.global_position + Vector2(120, 0))
	await _wait_until(func() -> bool: return hits[0] == 1, 60)
	_check("the dummy on the path is hit and stunned (status_stun)", [hits[0], dummy.is_stunned(), dummy.status_component.has_status(&"stun")], [1, true, true])
	_check_near("for 0.5 s", dummy.status_component.get_time_left(&"stun"), 0.5, 0.04)
	await _wait_until(func() -> bool: return not dummy.is_stunned() and not knight.movement.is_displaced(), 60)

	ab.remove_augments_from(&"item_test_lunge_stuns")
	_place(knight, dummy.global_position + Vector2(-60, 0))
	await _frames(2)
	ab.reset_cooldown(&"e")
	ab.try_cast(&"e", knight.global_position + Vector2(120, 0))
	await _wait_until(func() -> bool: return hits[0] == 2, 60)
	_check("unequipped: no flag; the next Lunge hits without a stun", [ab.get_flags(LUNGE).is_empty(), hits[0], dummy.is_stunned()], [true, 2, false])

	await _wait_until(func() -> bool: return not knight.movement.is_displaced(), 30)
	Events.unit_hit.disconnect(on_hit)
	dummy.queue_free()
	ab.reset_cooldown(&"e")
	await _frames(3)


func _test_abm_cleave_wave() -> void:
	_section("AB-M: Cleave Wave (REPLACE)")
	await _reset_knight()
	var ab := knight.abilities
	_check("the Knight's Q is Cleave", ab.get_base_ability(&"q") == CLEAVE, true)
	var hits: Array[HitContext] = []
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.ability == CLEAVE_WAVE:
			hits.append(ctx)
	Events.unit_hit.connect(on_hit)
	var near := _dummy_at(Vector2(150, 0))   # beyond Cleave's 96 px reach
	var far := _dummy_at(Vector2(200, 10))
	_tough(near)
	_tough(far)
	await _frames(2)
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 300)
	ab.add_augment(AUG_CLEAVE_WAVE, &"item_test_cleave_wave")
	_check("equipped: Q casts the wave (the export stays Cleave); the wave's tooltip gains the augment line",
		[ab.get_ability(&"q") == CLEAVE_WAVE, ab.get_base_ability(&"q") == CLEAVE,
			CLEAVE_WAVE.get_tooltip_plain(knight).ends_with("\nCleave becomes a wave of force that travels 700 units, passing through enemies.")],
		[true, true, true])
	knight.stats_component.add_modifier(StatModifier.create(&"base_damage", StatModifier.Type.FLAT, 10.0, &"item_test_cleave_plus", &"ability:knight_cleave"))
	_check("Cleave's scoped modifiers reach the wave (variant_of): +10 base damage", CLEAVE_WAVE.get_param(knight, &"base_damage"), 90.0)
	knight.stats_component.remove_modifiers_from(&"item_test_cleave_plus")

	ab.try_cast(&"q", knight.global_position + Vector2(300, 0))
	await _wait_until(func() -> bool: return not _projectiles().is_empty(), 30)
	var waves := _projectiles()
	_check("after the 0.2 s cast time: one wave flies, its crescent on it",
		[waves.size(), waves[0].get_child_count() > 0 if waves.size() == 1 else false], [1, true])
	await _wait_until(func() -> bool: return _projectiles().is_empty(), 120)
	_check("it passes through both dummies: 124.8 each (80 + 0.7 x 64), tagged projectile",
		[hits.size(), hits.map(func(h: HitContext) -> float: return h.raw_damage), hits.all(func(h: HitContext) -> bool: return h.has_tag(&"projectile"))],
		[2, [124.8, 124.8], true])
	var cooldown := ab.get_cooldown_left(&"q")
	ab.remove_augments_from(&"item_test_cleave_wave")
	_check("unequipped: Q casts Cleave again; the slot's cooldown carried over",
		[ab.get_ability(&"q") == CLEAVE, ab.is_ready(&"q"), ab.get_cooldown_left(&"q") == cooldown, cooldown > 0.0], [true, false, true, true])

	Events.unit_hit.disconnect(on_hit)
	near.queue_free()
	far.queue_free()
	ab.reset_cooldown(&"q")
	await _frames(3)


func _test_abm_judgement_reset() -> void:
	_section("AB-M: a Judgement kill resets its cooldown (EVENT + ModifyCooldown)")
	await _reset_knight()
	var ab := knight.abilities
	var rules_before := knight.get_reaction_rule_entries().size()
	ab.add_augment(AUG_JUDGEMENT_RESET, &"item_test_judgement_reset")
	_check("equipped: one unit rule; Judgement's tooltip gains the line",
		[knight.get_reaction_rule_entries().size() - rules_before, JUDGEMENT.get_tooltip_plain(knight).ends_with("\nA Judgement kill resets its cooldown.")], [1, true])
	ab.reset_cooldown(&"r")
	var weak := _dummy_at(Vector2(60, 0))
	await _frames(2)
	weak.health.take_damage(weak.health.current - 1.0)
	ab.try_cast(&"r", weak.global_position, weak)
	await _wait_until(func() -> bool: return not ab.casting, 150)
	_check("Judgement kills the dummy: R is ready again at once", [weak.is_alive(), ab.is_ready(&"r"), ab.get_cooldown_left(&"r")], [false, true, 0.0])

	var tough := _dummy_at(Vector2(60, 30))
	_tough(tough)
	await _frames(2)
	ab.try_cast(&"r", tough.global_position, tough)
	await _wait_until(func() -> bool: return not ab.casting, 150)
	_check("a Judgement that doesn't kill: its cooldown runs", [tough.is_alive(), ab.is_ready(&"r")], [true, false])

	ab.remove_augments_from(&"item_test_judgement_reset")
	ab.reset_cooldown(&"r")
	var weak2 := _dummy_at(Vector2(60, -30))
	await _frames(2)
	weak2.health.take_damage(weak2.health.current - 1.0)
	ab.try_cast(&"r", weak2.global_position, weak2)
	await _wait_until(func() -> bool: return not ab.casting, 150)
	_check("unequipped: the rule is gone and a kill doesn't reset it",
		[knight.get_reaction_rule_entries().size(), weak2.is_alive(), ab.is_ready(&"r")], [rules_before, false, false])

	ab.reset_cooldown(&"r")
	for d in [weak, tough, weak2]:
		if is_instance_valid(d):
			d.queue_free()
	await _frames(3)


func _test_abm_cleave_casts_lunge() -> void:
	_section("AB-M: Cleave also casts a free Lunge (EVENT + CastAbility at Cleave's effect start)")
	await _reset_knight()
	var ab := knight.abilities
	await _wait_until(func() -> bool: return ab.can_cast(&"q"), 300)
	ab.reset_cooldown(&"e")
	ab.add_augment(AUG_CLEAVE_CASTS_LUNGE, &"item_test_cleave_casts_lunge")
	_check("equipped: Cleave's tooltip gains the line", CLEAVE.get_tooltip_plain(knight).ends_with("\nCasting Cleave also casts a free Lunge toward your aim."), true)
	var casts: Array[CastContext] = []
	var on_cast := func(unit: Unit, _a: Ability, c: CastContext) -> void:
		if unit == knight:
			casts.append(c)
	Events.ability_cast.connect(on_cast)
	var hit_abilities: Array[StringName] = []
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.source == knight and ctx.ability != null:
			hit_abilities.append(ctx.ability.id)
	Events.unit_hit.connect(on_hit)
	var dummy := _dummy_at(Vector2(40, 0))
	_tough(dummy)
	await _frames(2)
	var from := knight.global_position
	var e_charges := ab.get_charges(&"e")

	ab.try_cast(&"q", from + Vector2(100, 0))
	await _wait_until(func() -> bool: return casts.size() >= 2, 30)
	var lunges := casts.filter(func(c: CastContext) -> bool: return c.ability == LUNGE)
	var cleaves := casts.filter(func(c: CastContext) -> bool: return c.ability == CLEAVE)
	_check("at Cleave's effect start: Cleave's cast and a free Lunge from the augment's rule",
		[cleaves.size(), lunges.size(), lunges[0].is_free if lunges.size() == 1 else false, lunges[0].source_id if lunges.size() == 1 else &""],
		[1, 1, true, &"augment_cleave_casts_lunge"])
	await _wait_until(func() -> bool: return not ab.casting and not knight.movement.is_displaced() and hit_abilities.has(&"knight_lunge"), 60)   # Lunge hits the frame after its dash
	_check("the Knight lunged 100 px toward the aim; the dummy took Cleave's and Lunge's hits; E untouched (charges, ready)",
		[snappedf(knight.global_position.distance_to(from), 1.0), hit_abilities.has(&"knight_cleave"), hit_abilities.has(&"knight_lunge"), ab.get_charges(&"e"), ab.is_ready(&"e")],
		[100.0, true, true, e_charges, true])

	ab.remove_augments_from(&"item_test_cleave_casts_lunge")
	ab.reset_cooldown(&"q")
	casts.clear()
	from = knight.global_position
	ab.try_cast(&"q", from + Vector2(100, 0))
	await _wait_until(func() -> bool: return not ab.casting, 30)
	_check("unequipped: Cleave casts alone and doesn't move the Knight", [casts.size(), snappedf(knight.global_position.distance_to(from), 1.0)], [1, 0.0])

	Events.ability_cast.disconnect(on_cast)
	Events.unit_hit.disconnect(on_hit)
	dummy.queue_free()
	ab.reset_cooldown(&"q")
	await _frames(3)


func _test_abm_playground() -> void:
	_section("AB-M: SandboxAugments (keys 1-4; unequipping restores the Knight exactly)")
	await _reset_knight()
	var ab := knight.abilities
	var sa: Node = SANDBOX_AUGMENTS.new()
	var items: Array[AbilityAugment] = [AUG_LUNGE_STUNS, AUG_CLEAVE_WAVE, AUG_JUDGEMENT_RESET, AUG_CLEAVE_CASTS_LUNGE]
	sa.set(&"items", items)
	sa.set(&"show_list", false)
	add_child(sa)
	sa.call(&"_on_entity", knight)   # the test has no room: hand it the Knight
	var snapshot := func() -> Array:
		return [ab.get_ability(&"q"), ab.get_ability(&"e"), ab.get_ability(&"r"), ab.get_flags(LUNGE), knight.get_reaction_rule_entries().size(),
			CLEAVE.get_tooltip_plain(knight), LUNGE.get_tooltip_plain(knight), JUDGEMENT.get_tooltip_plain(knight),
			ab.get_augments(&"q").size(), ab.get_augments(&"e").size(), ab.get_augments(&"r").size()]
	var before: Array = snapshot.call()
	_check("each fake item's source id: item_test_<augment id>",
		items.map(func(a: AbilityAugment) -> StringName: return sa.call(&"get_source_id", a)),
		[&"item_test_lunge_stuns", &"item_test_cleave_wave", &"item_test_judgement_reset", &"item_test_cleave_casts_lunge"])
	var equipped: Array = []
	for i in 4:
		equipped.append(sa.call(&"toggle", i))
	var on: Array = snapshot.call()
	_check("1-4 equipped: Q casts the wave, Lunge has its flag, two unit rules, the tooltips gain their lines",
		[equipped, on[0] == CLEAVE_WAVE, on[3], on[4] - before[4], (on[6] as String).count("\n") - (before[6] as String).count("\n"),
			(on[7] as String).count("\n") - (before[7] as String).count("\n"), CLEAVE_WAVE.get_tooltip_plain(knight).contains("Casting Cleave also casts a free Lunge")],
		[[true, true, true, true], true, [&"lunge_stuns"] as Array[StringName], 2, 1, 1, true])
	var key := InputEventKey.new()
	key.physical_keycode = KEY_2
	key.pressed = true
	sa.call(&"_unhandled_input", key)
	_check("the 2 key: the wave is off, Q casts Cleave again", [sa.call(&"is_equipped", 1), ab.get_ability(&"q") == CLEAVE], [false, true])
	for i: int in [0, 2, 3]:
		sa.call(&"toggle", i)
	_check("all four unequipped: the Knight exactly as before", snapshot.call(), before)
	sa.queue_free()
	await _frames(2)


func _wall_at(pos: Vector2, size: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	wall.add_child(shape)
	add_child(wall)
	wall.global_position = pos
	return wall


## The test pool emptied, so Judgement's 60 Fury bonus (CHAMPIONS CH4) doesn't
## pass: these checks test the plain Judgement; the champions test covers the
## bonus. The pool's 6/s regen can't reach 60 within a check.
func _below_fury_bonus() -> void:
	knight.resource_pool.try_spend(knight.resource_pool.current)


## A tooltip's template line, without the bonus and augment lines after it.
func _template_line(tooltip: String) -> String:
	return tooltip.get_slice("\n", 0)


func _with_description(ability: Ability, text: String) -> Ability:
	var copy: Ability = ability.duplicate()
	copy.description = text
	copy.conditional_bonuses = []   # only the template (CH4 gave Cleave a bonus line)
	return copy


func _add_costs(costs: Dictionary) -> void:
	for id: StringName in costs:
		knight.stats_component.add_modifier(StatModifier.create(&"resource_cost",
			StatModifier.Type.FLAT, costs[id], COST_SOURCE, StringName("ability:" + id)))


# --- AB14 -----------------------------------------------------------------------

## How many physics frames after `start` runs its caster's next effect starts
## (Events.ability_cast). `phase` is where in a frame `start` runs: "physics"
## (the physics_frame signal, before every node's physics), "node" (a node's
## _physics_process after the units' own), "idle" (between physics frames,
## like an input event). -1 if nothing started within 240 frames.
func _ab14_effect_frames(start: Callable, caster: Unit, phase: String) -> int:
	var fired: Array[int] = [-1]
	var started: Array[int] = [-1]
	var on_cast := func(u: Unit, _a: Ability, _c: CastContext) -> void:
		if u == caster and fired[0] < 0 and started[0] >= 0:
			fired[0] = Engine.get_physics_frames()
	var run := func() -> void:
		started[0] = Engine.get_physics_frames()
		start.call()
	await _ab14_no_hitstop()   # a hitstop left from the last cast would slow this one (real-time, so not repeatable)
	Events.ability_cast.connect(on_cast)
	match phase:
		"node":
			var caller := PhysicsCaller.new()
			caller.fn = run
			add_child(caller)   # the last child: its physics runs after the units'
			await _wait_until(func() -> bool: return started[0] >= 0, 10)
			caller.queue_free()
		"idle":
			await get_tree().process_frame
			run.call()
		_:
			await get_tree().physics_frame
			run.call()
	await _wait_until(func() -> bool: return fired[0] >= 0, 240)
	Events.ability_cast.disconnect(on_cast)
	return fired[0] - started[0] if fired[0] >= 0 else -1


## Waits until no hitstop is running (GameFeel's is timed in real time).
func _ab14_no_hitstop() -> void:
	await _wait_until(func() -> bool: return not GameFeel.is_hitstop_active(), 120)


## How many physics ticks a cast time takes: the nominal count, rounded up
## (AB14b: an exact number of ticks takes exactly that many, 0.2 s = 12; the
## old timer's float residue took one more). Computed independently of
## AbilityComponent's countdown, so the checks test it.
func _ab14_timer_ticks(cast_time: float) -> int:
	if cast_time <= 0.0:
		return 0
	return ceili(cast_time * Engine.physics_ticks_per_second - 0.001)


## One cast's timing check, for each phase, after `prepare` (a coroutine): the
## effect lands on the frame the cast time's tick count gives (AB14b: the
## nominal count, no extra tick). A cast started in a frame (at its start or
## in the node pass) counts that frame, so the effect comes ticks - 1 frames
## later; one started between frames counts from the next, so ticks later; no
## cast time = the same frame.
func _ab14_timer_frame(label: String, caster: Unit, prepare: Callable, start: Callable, cast_time: float, phases: Array[String] = ["physics"]) -> void:
	var where := {"physics": "at a frame's start", "node": "in the node pass", "idle": "between frames"}
	var ticks := _ab14_timer_ticks(cast_time)
	for phase in phases:
		await prepare.call()
		var frames := await _ab14_effect_frames(start, caster, phase)
		var expected := 0 if ticks == 0 else (ticks if phase == "idle" else ticks - 1)
		_check("%s (%s s = %d ticks), cast %s: the effect %d frames later" % [label, cast_time, ticks, where[phase], expected], frames, expected)


func _test_ab14_regression() -> void:
	_section("AB14b: every cast's effect on the frame its tick count gives (no extra tick)")
	_check("tick counts: 0.05 / 0.1 / 0.2 / 0.3 / 0.65 / 0.7 / 1.5 s = 3 / 6 / 12 / 18 / 39 / 42 / 90", [0.05, 0.1, 0.2, 0.3, 0.65, 0.7, 1.5].map(_ab14_timer_ticks), [3, 6, 12, 18, 39, 42, 90])
	var ab := knight.abilities
	var original_q := ab.q
	var dummies: Array[Enemy] = []
	var fresh_dummy := func() -> void:
		for d in dummies:
			if is_instance_valid(d):
				d.queue_free()
		dummies.clear()
		dummies.append(_dummy_at(Vector2(60, 0)))
	var make_ready := func(slot: StringName) -> void:   # the Knight back in place, the slot castable, a fresh dummy
		await _reset_knight()
		ab.reset_cooldown(slot)
		fresh_dummy.call()
		await _frames(1)
	var in_front := func() -> Vector2: return knight.global_position + Vector2(60, 0)

	var cleave := func() -> void: ab.try_cast(&"q", in_front.call())
	await _ab14_timer_frame("Cleave", knight, make_ready.bind(&"q"), cleave, CLEAVE.cast_time, ["physics", "node", "idle"])
	var lunge := func() -> void: ab.try_cast(&"e", knight.global_position + Vector2(100, 0))
	await _ab14_timer_frame("Lunge", knight, make_ready.bind(&"e"), lunge, LUNGE.cast_time)
	var iron := func() -> void: ab.try_cast(&"w", knight.global_position)
	await _ab14_timer_frame("Iron Resolve", knight, make_ready.bind(&"w"), iron, IRON_RESOLVE.cast_time)
	var judgement := func() -> void: ab.try_cast(&"r", dummies[0].global_position, dummies[0])
	await _ab14_timer_frame("Judgement's channel", knight, make_ready.bind(&"r"), judgement, JUDGEMENT.cast_time, ["physics", "node"])

	ab.q = CHARGED_LINE
	var charged := func() -> void:
		ab.try_start_charge(&"q", in_front.call())
		ab.release_charge(in_front.call())
	await _ab14_timer_frame("the test Charged Line's release windup", knight, make_ready.bind(&"q"), charged, CHARGED_LINE.cast_time)
	ab.q = VECTOR_LINE
	var vector := func() -> void:
		ab.try_start_charge(&"q", in_front.call())
		ab.release_charge(knight.global_position + Vector2(60, 60))
	await _ab14_timer_frame("the test vector line's release windup", knight, make_ready.bind(&"q"), vector, VECTOR_LINE.cast_time)
	ab.q = MARK_STRIKE
	var mark_ready := func() -> void:   # part 0 marks the dummy; then part 1 is measured
		await make_ready.call(&"q")
		ab.try_cast(&"q", dummies[0].global_position)
		await _wait_until(func() -> bool: return ab.get_recast_part(&"q") == 1 and not ab.casting, 60)
	var mark := func() -> void: ab.try_cast(&"q", dummies[0].global_position)
	await _ab14_timer_frame("the test Mark Strike's recast part", knight, mark_ready, mark, MARK_STRIKE.cast_time)
	ab.q = original_q

	var elite: Enemy = ELITE_SCENE.instantiate()
	elite.passive = true
	add_child(elite)
	elite.abilities.w = VECTOR_WALL
	var elite_ready := func(slot: StringName) -> void:
		await _reset_knight()
		_place(elite, knight.global_position + Vector2(60, 0))
		elite.abilities.reset_cooldown(slot)
		await _frames(1)
	var slam := func() -> void: elite.abilities.try_cast(&"q", knight.global_position, knight)
	await _ab14_timer_frame("the elite's slam", elite, elite_ready.bind(&"q"), slam, SLAM.cast_time, ["physics", "node", "idle"])
	var wall := func() -> void: elite.abilities.try_cast_vector(&"w", knight.global_position + Vector2(0, -80), Vector2.DOWN)
	await _ab14_timer_frame("the test vector wall on the elite", elite, elite_ready.bind(&"w"), wall, VECTOR_WALL.cast_time)
	elite.queue_free()
	for d in dummies:
		if is_instance_valid(d):
			d.queue_free()
	await _reset_knight()


func _test_ab14_chained_cast() -> void:
	_section("AB14: a cast started by another cast's end counts from the next frame")
	var ab := knight.abilities
	await _reset_knight()
	ab.reset_cooldown(&"q")
	ab.reset_cooldown(&"e")
	await _ab14_no_hitstop()
	await _frames(1)
	var at: Array[int] = [-1, -1]
	var chain := func(slot: StringName, _a: Ability) -> void:
		if slot == &"q" and at[0] < 0:
			at[0] = Engine.get_physics_frames()
			ab.try_cast(&"e", knight.global_position + Vector2(100, 0))   # like a buffered press firing at the cast's end
	var on_cast := func(u: Unit, a: Ability, _c: CastContext) -> void:
		if u == knight and a == LUNGE and at[0] >= 0 and at[1] < 0:
			at[1] = Engine.get_physics_frames()
	ab.cast_finished.connect(chain)
	Events.ability_cast.connect(on_cast)
	ab.try_cast(&"q", knight.global_position + Vector2(60, 0))
	await _wait_until(func() -> bool: return at[1] >= 0, 120)
	ab.cast_finished.disconnect(chain)
	Events.ability_cast.disconnect(on_cast)
	var ticks := _ab14_timer_ticks(LUNGE.cast_time)
	_check("Lunge started in Cleave's cast_finished: its effect %d frames after (%d ticks)" % [ticks, ticks],
		at[1] - at[0] if at[1] >= 0 else -1, ticks)
	await _reset_knight()


func _test_ab14_progress() -> void:
	_section("AB14: cast progress and the cast speed")
	await _reset_knight()
	var ab := knight.abilities
	_check("get_cast_speed() is 1.0 (hardcoded: the slot for a future cast-speed stat)", ab.get_cast_speed(JUDGEMENT), 1.0)
	_check("nothing casting: progress 0", ab.get_cast_progress(), 0.0)
	ab.reset_cooldown(&"r")
	ab.reset_cooldown(&"w")
	var dummy := _dummy_at(Vector2(60, 0))
	await _frames(1)
	var ctxs: Array[CastContext] = []
	var grab := func(_s: StringName, _a: Ability, c: CastContext) -> void: ctxs.append(c)
	var at_effect: Array[float] = []
	var on_cast := func(u: Unit, _a: Ability, c: CastContext) -> void:
		if u == knight:
			at_effect.append(c.progress)
	ab.cast_started.connect(grab)
	Events.ability_cast.connect(on_cast)

	await _ab14_no_hitstop()
	ab.try_cast(&"r", dummy.global_position, dummy)   # Judgement: 0.75 s = 45 frames (CH4)
	_check("Judgement's cast starts at progress 0", [ctxs.size(), ctxs[0].progress if not ctxs.is_empty() else -1.0, ab.get_cast_progress()], [1, 0.0, 0.0])
	var total := _ab14_timer_ticks(JUDGEMENT.cast_time)
	var part := total / 3
	await _frames(part)
	_check_near("%d of its %d frames in: progress %d / %d" % [part, total, part, total], ab.get_cast_progress(), float(part) / total, 0.001)
	_check("the cast's context carries the same progress", not ctxs.is_empty() and ctxs[0].progress == ab.get_cast_progress(), true)
	await _wait_until(func() -> bool: return not at_effect.is_empty(), 60)
	_check("the effect starts at progress 1", at_effect.size() == 1 and at_effect[0] == 1.0, true)
	await _frames(1)
	_check("done: get_cast_progress() back to 0", ab.get_cast_progress(), 0.0)

	at_effect.clear()
	ctxs.clear()
	ab.try_cast(&"w", knight.global_position)   # Iron Resolve: no cast time
	_check("a cast with no cast time: progress 1 at once",
		[ctxs.size(), ctxs[0].progress if not ctxs.is_empty() else -1.0, at_effect.size(), at_effect[0] if not at_effect.is_empty() else -1.0], [1, 1.0, 1, 1.0])
	at_effect.clear()
	ab.try_cast_free(LUNGE, knight.global_position + Vector2(40, 0), null, &"test_ab14")
	_check("a free cast: progress 1", at_effect.size() == 1 and at_effect[0] == 1.0, true)
	ab.cast_started.disconnect(grab)
	Events.ability_cast.disconnect(on_cast)

	await _reset_knight()
	var original_q := ab.q
	ab.q = CHARGED_LINE
	ab.reset_cooldown(&"q")
	ab.try_start_charge(&"q", knight.global_position + Vector2(80, 0))
	await _frames(5)
	_check("holding a charge-up: no cast progress yet (its cast starts at release)", [ab.is_charging(), ab.get_cast_progress()], [true, 0.0])
	await _ab14_no_hitstop()
	ab.release_charge(knight.global_position + Vector2(80, 0))
	await _frames(9)
	_check_near("its release windup: 9 of 18 frames in, progress 0.5", ab.get_cast_progress(), 0.5, 0.001)
	ab.try_cancel_charge()
	_check("Esc in the windup: cancelled, progress 0", [ab.casting, ab.get_cast_progress()], [false, 0.0])
	ab.q = original_q
	dummy.queue_free()
	await _reset_knight()


func _test_ab14_telegraph() -> void:
	_section("AB14: a telegraph that belongs to a cast fills with its progress")
	await _reset_knight()
	var elite: Enemy = ELITE_SCENE.instantiate()
	elite.passive = true
	add_child(elite)
	_place(elite, knight.global_position + Vector2(60, 0))
	await _frames(1)
	var at_hit: Array = []
	var on_cast := func(u: Unit, _a: Ability, c: CastContext) -> void:
		if u == elite:
			at_hit.append([is_instance_valid(c.telegraph) and c.telegraph.is_driven(), c.telegraph.get_progress() if is_instance_valid(c.telegraph) else -1.0])
	Events.ability_cast.connect(on_cast)

	elite.abilities.try_cast(&"q", knight.global_position, knight)   # the slam: 0.65 s
	var t := _find_telegraph()
	_check("the slam's telegraph is driven by its cast from the start, empty", [t != null and t.is_driven(), t.get_progress() if t else -1.0], [true, 0.0])
	await _frames(20)
	_check("20 frames in: its fill is the cast's progress", t != null and t.get_progress() == elite.abilities.get_cast_progress() and t.get_progress() > 0.4, true)
	await _wait_until(func() -> bool: return not at_hit.is_empty(), 60)
	_check("at the hit: exactly full", at_hit, [[true, 1.0]])

	await _reset_knight()
	_place(elite, knight.global_position + Vector2(60, 0))
	at_hit.clear()
	elite.abilities.w = VECTOR_WALL
	elite.abilities.try_cast_vector(&"w", knight.global_position + Vector2(0, -80), Vector2.DOWN)
	await _wait_until(func() -> bool: return not at_hit.is_empty(), 60)
	_check("the vector wall's line telegraph: full exactly at the hit", at_hit, [[true, 1.0]])

	var loose := Telegraph.circle(knight, knight.global_position, 10.0, 0.5)
	_check("a telegraph with no cast isn't driven", loose.is_driven(), false)
	loose.queue_free()
	Events.ability_cast.disconnect(on_cast)
	elite.queue_free()
	await _reset_knight()


func _test_ab14_hooks_empty() -> void:
	_section("AB14: presentation hooks empty: nothing happens")
	var empty := true
	for a: Ability in [CLEAVE, IRON_RESOLVE, LUNGE, JUDGEMENT, SLAM, CLEAVE_WAVE, VECTOR_WALL]:
		empty = empty and a.cast_vfx == null and a.impact_vfx == null and a.cast_anim == &""
	_check("no ability in the data fills a hook yet (the art pass will)", empty, true)
	var swings: Array[AttackSwing] = []
	swings.append_array(COMBO_KNIGHT.swings)
	swings.append(COMBO_KNIGHT.dash_strike)
	var swings_empty := true
	for s in swings:
		swings_empty = swings_empty and s.swing_vfx == null and s.impact_vfx == null and s.swing_anim == &""
	_check("nor any swing of the Knight's combo (the dash-strike included)", swings_empty, true)
	await _reset_knight()
	var dummy := _dummy_at(Vector2(60, 0))
	_check("play_cast_vfx() and play_impact_vfx() with empty hooks: nothing",
		[CLEAVE.play_cast_vfx(knight, CastContext.new()), CLEAVE.play_impact_vfx(knight, dummy, null)], [null, null])
	_check("VFX.spawn_scene() with no scene: nothing", VFX.spawn_scene(null, knight, Vector2.ZERO, 0.0), null)
	dummy.queue_free()


func _ab14_probe_scene() -> PackedScene:
	var n := Node2D.new()
	n.set_script(HOOK_PROBE)
	var scene := PackedScene.new()
	scene.pack(n)
	n.free()
	return scene


## The test hook scenes spawned so far whose setup() got a `kind` second
## argument (CastContext, HitContext, AttackSwing).
func _ab14_probes(kind: String) -> Array[Node]:
	var found: Array[Node] = []
	for p in get_tree().get_nodes_in_group(HOOK_PROBE.GROUP):
		var args := _ab14_args(p)
		var second: Variant = args[1] if args.size() > 1 else null
		var match_kind := (kind == "cast" and second is CastContext) or (kind == "hit" and second is HitContext) \
			or (kind == "swing" and second is AttackSwing)
		if match_kind:
			found.append(p)
	return found


## What a test hook scene's setup() got: [caster or attacker, the context].
func _ab14_args(p: Node) -> Array:
	var args: Variant = p.get("args")
	return args if args is Array else []


func _ab14_clear_probes() -> void:
	for p in get_tree().get_nodes_in_group(HOOK_PROBE.GROUP):
		p.remove_from_group(HOOK_PROBE.GROUP)
		p.queue_free()


func _test_ab14_hooks_fire() -> void:
	_section("AB14: presentation hooks filled (a test hook scene): each fires once at its moment")
	await _reset_knight()
	_ab14_clear_probes()
	var ab := knight.abilities
	var original_q := ab.q
	var probe := _ab14_probe_scene()
	var hooked: Ability = CLEAVE.duplicate()
	hooked.cast_vfx = probe
	hooked.impact_vfx = probe
	ab.q = hooked
	ab.reset_cooldown(&"q")
	var dummies: Array[Enemy] = [_dummy_at(Vector2(60, 0)), _dummy_at(Vector2(55, 25)), _dummy_at(Vector2(60, -25))]
	dummies[2].add_invulnerability(&"test_ab14")   # its hit is blocked
	await _frames(1)
	var at_start: Array[int] = []
	var count_at_start := func(_s: StringName, _a: Ability, _c: CastContext) -> void: at_start.append(_ab14_probes("cast").size())
	ab.cast_started.connect(count_at_start)
	ab.try_cast(&"q", knight.global_position + Vector2(60, 0))
	ab.cast_started.disconnect(count_at_start)
	_check("cast_vfx: spawned at cast start, before cast_started", at_start.size() == 1 and at_start[0] == 1, true)
	var cast_probes := _ab14_probes("cast")
	var p0: Node2D = cast_probes[0] as Node2D if not cast_probes.is_empty() else null
	_check("at the Knight's feet, turned to the aim, setup(caster, the cast)",
		p0 != null and p0.global_position.is_equal_approx(knight.global_position) and is_zero_approx(p0.global_rotation) and _ab14_args(p0)[0] == knight, true)
	_check("no impact_vfx before the effect", _ab14_probes("hit").size(), 0)
	await _wait_until(func() -> bool: return not ab.casting, 30)
	var hit_probes := _ab14_probes("hit")
	var targets: Array = []
	var turned := true
	var from_knight := true
	for p in hit_probes:
		var n := p as Node2D
		targets.append((_ab14_args(p)[1] as HitContext).target)
		turned = turned and is_equal_approx(n.global_rotation, (n.global_position - knight.global_position).angle())
		from_knight = from_knight and _ab14_args(p)[0] == knight
	_check("impact_vfx: once per enemy hit, none for the blocked hit",
		[hit_probes.size(), targets.has(dummies[0]), targets.has(dummies[1]), targets.has(dummies[2])], [2, true, true, false])
	_check("each at its enemy, turned Knight -> enemy, setup(caster, the hit)", turned and from_knight, true)

	_ab14_clear_probes()
	ab.try_cast_free(hooked, knight.global_position + Vector2(60, 0), null, &"test_ab14")
	cast_probes = _ab14_probes("cast")
	_check("a free cast plays cast_vfx too", cast_probes.size() == 1 and (_ab14_args(cast_probes[0])[1] as CastContext).is_free, true)

	_ab14_clear_probes()
	for d in dummies:
		d.queue_free()
	await _reset_knight()
	var bolt: Ability = BOLT.duplicate()
	bolt.impact_vfx = probe
	ab.q = bolt
	ab.reset_cooldown(&"q")
	var target := _dummy_at(Vector2(120, 0))
	await _frames(1)
	ab.try_cast(&"q", target.global_position)
	await _wait_until(func() -> bool: return not _ab14_probes("hit").is_empty(), 90)
	hit_probes = _ab14_probes("hit")
	_check("a projectile's hit plays impact_vfx", hit_probes.size() == 1 and (_ab14_args(hit_probes[0])[1] as HitContext).target == target, true)
	ab.q = original_q
	target.queue_free()

	_ab14_clear_probes()
	await _reset_knight()
	var original_combo := knight.attack.combo
	var swing: AttackSwing = COMBO_KNIGHT.swings[0].duplicate()
	swing.swing_vfx = probe
	swing.impact_vfx = probe
	knight.attack.combo = _ab14_combo_with_first(swing)
	var front := _dummy_at(Vector2(40, 0))
	await _wait_until(func() -> bool: return knight.attack.can_swing(), 60)
	_check("a swing starts", knight.attack.try_swing(Vector2.RIGHT), true)
	var swing_probes := _ab14_probes("swing")
	_check("swing_vfx: spawned at swing start, setup(attacker, the swing)",
		swing_probes.size() == 1 and _ab14_args(swing_probes[0])[0] == knight and _ab14_args(swing_probes[0])[1] == swing, true)
	await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 30)
	hit_probes = _ab14_probes("hit")
	var swing_hit: HitContext = _ab14_args(hit_probes[0])[1] if hit_probes.size() == 1 else null
	_check("the swing's impact_vfx: once on the enemy it hit",
		swing_hit != null and swing_hit.target == front and swing_hit.has_tag(&"basic_attack"), true)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 30)
	knight.attack.combo = original_combo
	front.queue_free()
	_ab14_clear_probes()
	await _reset_knight()


## A copy of the Knight's combo whose first swing is `first` (AB14 hooks).
func _ab14_combo_with_first(first: AttackSwing) -> AttackCombo:
	var combo: AttackCombo = COMBO_KNIGHT.duplicate()
	var swings: Array[AttackSwing] = []
	swings.append_array(COMBO_KNIGHT.swings)
	swings[0] = first
	combo.swings = swings
	return combo


func _test_ab14_anims() -> void:
	_section("AB14: cast_anim and swing_anim follow progress")
	await _reset_knight()
	var ab := knight.abilities
	var original_q := ab.q
	var original_w := ab.w
	var original_r := ab.r
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	var lib := AnimationLibrary.new()
	var cast_anim := Animation.new()
	cast_anim.length = 1.0
	var swing_anim := Animation.new()
	swing_anim.length = 0.5
	lib.add_animation(&"test_cast", cast_anim)
	lib.add_animation(&"test_swing", swing_anim)
	player.add_animation_library(&"", lib)
	knight.body.add_child(player)

	var cleave: Ability = CLEAVE.duplicate()
	cleave.cast_anim = &"test_cast"
	ab.q = cleave
	ab.reset_cooldown(&"q")
	await _frames(1)
	var at_effect: Array[float] = []
	var on_cast := func(u: Unit, _a: Ability, _c: CastContext) -> void:
		if u == knight:
			at_effect.append(player.current_animation_position)
	Events.ability_cast.connect(on_cast)
	ab.try_cast(&"q", knight.global_position + Vector2(60, 0))
	var in_step := player.assigned_animation == "test_cast" and is_zero_approx(player.current_animation_position)
	var samples := 0
	while at_effect.is_empty() and samples < 30:
		await _frames(1)
		if at_effect.is_empty():
			var ok := player.assigned_animation == "test_cast" \
				and is_equal_approx(player.current_animation_position, ab.get_cast_progress() * cast_anim.length)
			if not ok:
				print("    tick %d: %s at %s, progress %s" % [samples, player.assigned_animation, player.current_animation_position, ab.get_cast_progress()])
			in_step = in_step and ok
			samples += 1
	_check("Cleave's cast_anim: its position = progress x its length every tick (%d ticks)" % samples, in_step and samples >= 10, true)
	_check("at the effect start it's at its last frame", at_effect.size() == 1 and at_effect[0] == 1.0, true)
	Events.ability_cast.disconnect(on_cast)

	await _reset_knight()
	var dummy := _dummy_at(Vector2(60, 0))
	var judgement: Ability = JUDGEMENT.duplicate()
	judgement.cast_anim = &"test_cast"
	ab.r = judgement
	ab.reset_cooldown(&"r")
	await _frames(1)
	ab.try_cast(&"r", dummy.global_position, dummy)
	await _frames(10)
	_check("mid-channel it's playing", [player.current_animation, player.current_animation_position > 0.0], [&"test_cast", true])
	knight.apply_stun(0.1)
	_check("a stun interrupts the cast: the cast_anim stops", player.is_playing(), false)
	ab.r = original_r
	dummy.queue_free()

	await _reset_knight()
	var iron: Ability = IRON_RESOLVE.duplicate()
	iron.cast_anim = &"test_cast"
	ab.w = iron
	ab.reset_cooldown(&"w")
	ab.try_cast(&"w", knight.global_position)
	_check("no cast time (Iron Resolve): it plays on its own at the cast speed",
		[player.is_playing(), player.current_animation, player.get_playing_speed()], [true, &"test_cast", 1.0])
	ab.w = original_w
	ab.q = original_q

	await _reset_knight()
	var original_combo := knight.attack.combo
	var swing: AttackSwing = COMBO_KNIGHT.swings[0].duplicate()
	swing.swing_anim = &"test_swing"
	knight.attack.combo = _ab14_combo_with_first(swing)
	await _wait_until(func() -> bool: return knight.attack.can_swing(), 60)
	knight.attack.try_swing(Vector2.RIGHT)
	in_step = player.assigned_animation == "test_swing"
	samples = 0
	while knight.attack.is_swinging() and samples < 40:
		await _frames(1)
		if knight.attack.is_swinging():
			in_step = in_step and is_equal_approx(player.current_animation_position, knight.attack.get_swing_progress() * swing_anim.length)
			samples += 1
	_check("the swing_anim: its position = swing progress x its length every tick (%d ticks)" % samples, in_step and samples >= 10, true)
	_check("the swing ended: at its last frame", is_equal_approx(player.current_animation_position, swing_anim.length), true)
	await _wait_until(func() -> bool: return knight.attack.can_swing(), 60)
	knight.attack.try_swing(Vector2.RIGHT)
	await _frames(2)
	knight.attack.cancel_swing()
	_check("a cancelled swing stops its swing_anim", player.is_playing(), false)
	knight.attack.combo = original_combo
	player.queue_free()
	await _reset_knight()


# --- Helpers ------------------------------------------------------------------

## The test baseline for costs (CHAMPIONS CH3): the cost checks test the
## machinery on a plain pool, the Knight's old placeholder: 300, 6/s regen,
## full, no decay; Cleave's own cost (20) cancelled and no fury from swings.
## The champions test covers the real Fury.
func _pool_baseline(p: Player) -> void:
	var pool := p.resource_pool
	pool.starts_empty = false
	pool.decay_per_second = 0.0
	if p.champion != null:
		p.stats_component.remove_modifiers_from(p.champion.get_champion_source_id())
	var mods: Array[StatModifier] = [
		StatModifier.create(&"max_resource", StatModifier.Type.FLAT, 300.0 - p.stats_component.get_base_value(&"max_resource"), &"test_baseline"),
		StatModifier.create(&"resource_regen", StatModifier.Type.FLAT, 6.0 - p.stats_component.get_base_value(&"resource_regen"), &"test_baseline"),
		StatModifier.create(&"resource_cost", StatModifier.Type.FLAT, -CLEAVE.resource_cost, &"test_baseline", &"ability:knight_cleave"),
	]
	p.stats_component.add_modifiers(mods)
	pool.restore(1000.0)


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
