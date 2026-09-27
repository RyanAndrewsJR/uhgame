extends Node2D
## ABILITIES.md test: open res://scenes/tests/abilities_test.tscn and press F6.
## Spawns the real player.tscn, passive slimes (training dummies) and the
## elite slime, and checks the ability framework step by step.
## AB1: cast styles (INSTANT default, CHANNEL = cancel_on_move), a stun or
## silence during a cast time interrupting it at once (refunded), an effect
## that has started not being interrupted, and the cast mode setting
## (saved, applied to the Player, INSTANT only).
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
