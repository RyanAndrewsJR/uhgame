extends Node2D
## COMBAT.md steps C1-C2 test: open res://scenes/tests/combat_test.tscn and press F6.
## Spawns the real player.tscn and passive slimes (training dummies) and
## runs hits through the hit pipeline: mitigation for all three damage types
## at 0 and 100 armor/magic_resist, stat scaling, the take_damage() and
## Hurtbox wrappers, i-frames, knockback, kills and the Events signals (C1).
## C2: the Knight's combo swings (timing, damage, reach and arc, root,
## combo and reset, the input buffer, dash / stun / ability cancels, Iron
## Resolve, attack speed). Melee basic attacks: the swing step, the target
## pull and aim snap (with a wall for line of sight), dash / stun during the
## step, walking out of the recovery, and RANGED turning it all off. The
## combo sections run last: they end by killing the Knight.
## Prints PASS/FAIL per check, then a total. Run headless and it quits with
## the number of failures as the exit code.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const SLIME_SCENE: PackedScene = preload("res://scenes/enemies/slime.tscn")
const CLEAVE: Ability = preload("res://data/abilities/knight_q_cleave.tres")
const FLAT := StatModifier.Type.FLAT
const PERCENT_ADD := StatModifier.Type.PERCENT_ADD
## Where the C2 swing tests happen, away from the C1 dummies.
const ARENA := Vector2(-2000, 0)
## Slime gameplay radius: 55 u = 17.6 px.
const SLIME_RADIUS_PX := 17.6
const MELEE := AttackCombo.AttackStyle.MELEE
const RANGED := AttackCombo.AttackStyle.RANGED

var knight: Player

var _next_dummy_y: float = 0.0
var _passed: int = 0
var _failed: int = 0
var _hits: Array[HitContext] = []
var _damaged: Array[HitContext] = []
var _deaths: Array = []   # [unit, ctx]
var _frame: int = 0
var _landed: Array = []   # [frame, index, targets.size()]


func _ready() -> void:
	Events.unit_hit.connect(func(ctx: HitContext) -> void: _hits.append(ctx))
	Events.unit_damaged.connect(func(ctx: HitContext) -> void: _damaged.append(ctx))
	Events.unit_died.connect(func(unit: Unit, ctx: HitContext) -> void: _deaths.append([unit, ctx]))
	knight = PLAYER_SCENE.instantiate()
	add_child(knight)
	await get_tree().physics_frame

	print("\n=== Combat test (COMBAT C1) ===")
	_test_mitigation_math()
	_test_mitigation_by_type()
	_test_scaling()
	_test_take_damage_wrapper()
	_test_invulnerability()
	await _test_knockback()
	_test_hurtbox_wrapper()
	_test_kill()
	_test_non_unit_target()
	await _test_combo()
	print("=== %d passed, %d failed ===\n" % [_passed, _failed])

	if DisplayServer.get_name() == "headless":
		get_tree().quit(_failed)


# --- Tests --------------------------------------------------------------------

func _test_mitigation_math() -> void:
	_section("Mitigation multiplier: 100 / (100 + r)")
	_check("0 resistance = x1", HitPipeline.get_mitigation_multiplier(0.0), 1.0)
	_check("100 resistance = x0.5", HitPipeline.get_mitigation_multiplier(100.0), 0.5)
	_check("300 resistance = x0.25", HitPipeline.get_mitigation_multiplier(300.0), 0.25)
	_check("-100 resistance = x1.5 (2 - 100/200)", HitPipeline.get_mitigation_multiplier(-100.0), 1.5)


func _test_mitigation_by_type() -> void:
	_section("Mitigation by damage type")
	for resist: float in [0.0, 100.0]:
		var dummy := _spawn_dummy()
		if resist > 0.0:
			dummy.stats_component.add_modifier(StatModifier.create(&"armor", FLAT, resist, &"test_resist"))
			dummy.stats_component.add_modifier(StatModifier.create(&"magic_resist", FLAT, resist, &"test_resist"))
		var expected := 80.0 * 100.0 / (100.0 + resist)
		var physical := _hit(dummy, 80.0, HitContext.DamageType.PHYSICAL)
		var magic := _hit(dummy, 80.0, HitContext.DamageType.MAGIC)
		var true_hit := _hit(dummy, 80.0, HitContext.DamageType.TRUE)
		_check("%d armor: PHYSICAL 80 -> %s taken" % [resist, expected], physical.taken_damage, expected)
		_check("%d magic_resist: MAGIC 80 -> %s taken" % [resist, expected], magic.taken_damage, expected)
		_check("%d both: TRUE 80 -> 80 taken" % resist, true_hit.taken_damage, 80.0)
		_check("%d: raw damage stays 80 (before mitigation)" % resist, physical.raw_damage, 80.0)
		_check("%d: health lost = sum of damage taken" % resist,
			dummy.health.max_health - dummy.health.current, expected * 2.0 + 80.0)
		_check("%d: damage type tags" % resist, [physical.has_tag(&"physical"), magic.has_tag(&"magic"), true_hit.has_tag(&"true")], [true, true, true])
		dummy.queue_free()


func _test_scaling() -> void:
	_section("Stat scaling (HitPipeline.from_ability)")
	var dummy := _spawn_dummy()
	var ctx := HitPipeline.resolve(HitPipeline.from_ability(knight, CLEAVE, dummy))
	_check("Cleave raw = 80 + 0.7 x 64 AD = 124.8", ctx.raw_damage, 124.8)
	_check("Cleave raw = Ability.get_damage() (numbers unchanged)", ctx.raw_damage, CLEAVE.get_damage(knight))
	_check("0 armor: taken = raw", ctx.taken_damage, ctx.raw_damage)
	_check("tags: ability + physical", [ctx.has_tag(&"ability"), ctx.has_tag(&"physical")], [true, true])
	_check("ctx.ability and source", [ctx.ability == CLEAVE, ctx.source == knight], [true, true])
	var env := HitContext.new()
	env.target = dummy
	env.base_damage = 40.0
	env.ad_ratio = 1.0
	HitPipeline.resolve(env)
	_check("no source (environment): ratios add nothing", env.raw_damage, 40.0)
	dummy.queue_free()


func _test_take_damage_wrapper() -> void:
	_section("take_damage() wrapper")
	var dummy := _spawn_dummy()
	var local: Array = []
	dummy.damaged.connect(func(amount: float, source: Unit) -> void: local.append([amount, source]))
	_clear_events()
	dummy.take_damage(50.0, knight, true)
	_check("health 280 -> 230", dummy.health.current, 230.0)
	_check("Unit.damaged still emits (amount, source)", local, [[50.0, knight]])
	_check("Events.unit_hit once", _hits.size(), 1)
	_check("Events.unit_damaged once", _damaged.size(), 1)
	if _hits.size() == 1:
		var ctx := _hits[0]
		_check("wrapped hit: PHYSICAL, can't crit, highlight kept",
			[ctx.damage_type, ctx.can_crit, ctx.highlight, ctx.source == knight],
			[HitContext.DamageType.PHYSICAL, false, true, true])
	_clear_events()
	dummy.take_damage(0.0, knight)
	_check("0 damage: unit_hit yes, unit_damaged no", [_hits.size(), _damaged.size()], [1, 0])
	dummy.queue_free()


func _test_invulnerability() -> void:
	_section("I-frames block the whole hit")
	var dummy := _spawn_dummy()
	dummy.add_invulnerability(&"test")
	_clear_events()
	dummy.take_damage(50.0, knight)
	var ctx := _hit(dummy, 50.0, HitContext.DamageType.TRUE, 20.0)
	_check("take_damage() blocked: health unchanged", dummy.health.current, 280.0)
	_check("pipeline hit blocked", [ctx.blocked, ctx.taken_damage], [true, 0.0])
	_check("no knockback", dummy.movement.is_displaced(), false)
	_check("no events", [_hits.size(), _damaged.size(), _deaths.size()], [0, 0, 0])
	dummy.remove_invulnerability(&"test")
	dummy.take_damage(50.0, knight)
	_check("after removing it, hits land again", dummy.health.current, 230.0)
	knight.add_invulnerability(&"dash")
	var on_knight := _hit(knight, 50.0, HitContext.DamageType.TRUE)
	_check("player dash i-frames block pipeline hits", [on_knight.blocked, knight.health.current], [true, knight.health.max_health])
	knight.remove_invulnerability(&"dash")
	dummy.queue_free()


func _test_knockback() -> void:
	_section("Knockback")
	var dummy := _spawn_dummy()
	var start := dummy.global_position
	var ctx := _hit(dummy, 10.0, HitContext.DamageType.PHYSICAL, 20.0)
	_check("knockback starts a displacement", dummy.movement.is_displaced(), true)
	for i in 20:
		await get_tree().physics_frame
	var moved := dummy.global_position - start
	_check_near("pushed 20 px", moved.length(), 20.0, 0.5)
	_check_near("away from the source", moved.normalized().dot((start - knight.global_position).normalized()), 1.0, 0.001)
	_check("the hit still dealt its damage", ctx.taken_damage, 10.0)
	dummy.queue_free()


func _test_hurtbox_wrapper() -> void:
	_section("Hurtbox wrapper")
	var dummy := _spawn_dummy()
	var hitbox := Hitbox.new()
	hitbox.damage = 30.0
	hitbox.knockback = 150.0
	add_child(hitbox)
	hitbox.global_position = dummy.global_position - Vector2(50, 0)
	_clear_events()
	dummy._on_hurtbox_hurt(hitbox)
	_check("health 280 -> 250", dummy.health.current, 250.0)
	_check("knockback started", dummy.movement.is_displaced(), true)
	_check("went through the pipeline (Events.unit_hit)", _hits.size(), 1)
	if _hits.size() == 1:
		_check("knockback 150 px/s x 0.12 s = 18 px", _hits[0].knockback_px, 18.0)
	hitbox.queue_free()
	dummy.queue_free()


func _test_kill() -> void:
	_section("Kills")
	var dummy := _spawn_dummy()
	var local_died: Array = []
	dummy.died.connect(func(u: Unit) -> void: local_died.append(u))
	_clear_events()
	var ctx := _hit(dummy, 1000.0, HitContext.DamageType.TRUE, 20.0)
	_check("ctx.killed", ctx.killed, true)
	_check("health_lost capped at the health left", ctx.health_lost, 280.0)
	_check("Unit.died still emits", local_died.size(), 1)
	_check("Events.unit_died once, with the unit", [_deaths.size(), _deaths.size() == 1 and _deaths[0][0] == dummy], [1, true])
	_check("kill credit = ctx.source", _deaths.size() == 1 and (_deaths[0][1] as HitContext).source == knight, true)
	_check("no knockback on a dead unit", dummy.movement.is_displaced(), false)
	var after := _hit(dummy, 10.0, HitContext.DamageType.TRUE)
	_check("hitting a dead unit is blocked", after.blocked, true)


func _test_non_unit_target() -> void:
	_section("Targets without on_hit()")
	var node := Node2D.new()
	add_child(node)
	var ctx := HitContext.new()
	ctx.source = knight
	ctx.target = node
	ctx.base_damage = 10.0
	HitPipeline.resolve(ctx)
	_check("blocked, no error", ctx.blocked, true)
	node.queue_free()


# --- C2: combo swings -------------------------------------------------------------

func _test_combo() -> void:
	knight.attack.swing_landed.connect(func(index: int, targets: Array[Unit]) -> void:
		_landed.append([_frame, index, targets.size()]))
	await _test_combo_data()
	await _test_swing_timing_and_damage()
	await _test_combo_chain_and_reset()
	await _test_reach_and_arc()
	await _test_buffered_press()
	await _test_swing_cancels()
	await _test_ability_during_swing()
	await _test_iron_resolve_swing()
	await _test_attack_speed()
	await _test_melee()
	await _test_death_mid_swing()


func _test_combo_data() -> void:
	_section("C2: combo data and input")
	var combo := knight.attack.combo
	_check("the Knight has combo_knight.tres, 3 swings", [combo != null, combo.swings.size() if combo else 0], [true, 3])
	if combo == null or combo.swings.size() != 3:
		return
	var s := combo.swings
	_check("windups 0.08", [s[0].windup, s[1].windup, s[2].windup], [0.08, 0.08, 0.08])
	_check("durations 0.3 / 0.3 / 0.4", [s[0].duration, s[1].duration, s[2].duration], [0.3, 0.3, 0.4])
	_check("damage 1.0 / 1.0 / 1.6 AD", [s[0].ad_ratio, s[1].ad_ratio, s[2].ad_ratio], [1.0, 1.0, 1.6])
	_check("arcs 110 / 110 / 140", [s[0].arc_deg, s[1].arc_deg, s[2].arc_deg], [110.0, 110.0, 140.0])
	_check("knockback 6 / 6 / 20 px", [s[0].knockback_px, s[1].knockback_px, s[2].knockback_px], [6.0, 6.0, 20.0])
	_check("combo_reset_time 0.6, forgiveness 0.1", [combo.combo_reset_time, combo.hit_forgiveness], [0.6, 0.1])
	_check("reach at base = 175 u = 56 px", knight.attack.get_swing_reach_px(s[0]), 56.0)
	_check("select is unbound (left mouse is attack only)", InputMap.action_get_events(&"select").is_empty(), true)
	_check("slimes have no combo (League-style attack)", _spawn_dummy().attack.can_swing(), false)
	_check("Knight abilities default to cancels_swing AFTER_HIT",
		[knight.abilities.q.cancels_swing, knight.abilities.w.cancels_swing, knight.abilities.e.cancels_swing, knight.abilities.r.cancels_swing],
		[Ability.SwingCancel.AFTER_HIT, Ability.SwingCancel.AFTER_HIT, Ability.SwingCancel.AFTER_HIT, Ability.SwingCancel.AFTER_HIT])


func _test_swing_timing_and_damage() -> void:
	_section("C2: one swing")
	await _reset_knight()
	var dummy := _dummy_at(Vector2(50, 0))
	_landed.clear()
	var start := _frame
	_check("try_swing starts a swing", knight.attack.try_swing(Vector2.RIGHT), true)
	_check("rooted while swinging", knight.movement.can_move(), false)
	_check("can't start another swing mid-swing", knight.attack.try_swing(Vector2.RIGHT), false)
	await _frames(1)
	_check("state ATTACK, facing locked to the swing", [knight.state, knight.facing], [Player.State.ATTACK, Vector2.RIGHT])
	await _wait_until(func() -> bool: return not _landed.is_empty(), 30)
	if _landed.is_empty():
		_report(false, "the swing landed", "never")
		return
	var frames: int = _landed[0][0] - start
	_check_near("hit lands ~0.08 s after the click (5 frames)", frames, 5.0, 1.0)
	_check("swing 1 hits the dummy for 1.0 x 64 AD", dummy.health.max_health - dummy.health.current, 64.0)
	_check("in recovery after the hit", knight.attack.is_in_recovery(), true)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 30)
	var total := _frame - start
	_check_near("the swing lasts 0.3 s (18 frames)", total, 18.0, 1.0)
	_check("root released after the swing", knight.movement.can_move(), true)
	_check("next swing is swing 2", knight.attack.get_combo_index(), 1)
	dummy.queue_free()


func _test_combo_chain_and_reset() -> void:
	_section("C2: combo chain and reset")
	await _reset_knight()
	var dummy := _dummy_at(Vector2(50, 0))
	var damage: Array = []
	for i in 3:
		dummy.health.heal(1000.0)
		var before := dummy.health.current
		var pos := dummy.global_position
		knight.attack.try_swing(Vector2.RIGHT)
		await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 40)
		damage.append(before - dummy.health.current)
		if i == 2:
			await _frames(10)
			_check_near("the finisher pushes 20 px", dummy.global_position.x - pos.x, 20.0, 1.0)
		_place(dummy, knight.global_position + Vector2(50, 0))
	_check("damage 64 / 64 / 102.4", damage, [64.0, 64.0, 102.4])
	_check("after the finisher the combo starts over", knight.attack.get_combo_index(), 0)
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 40)
	_check("next is swing 2 right after swing 1", knight.attack.get_combo_index(), 1)
	dummy.health.heal(1000.0)
	await _frames(40)   # 0.67 s > combo_reset_time
	_check("0.6 s without attacking resets the combo", knight.attack.get_combo_index(), 0)
	dummy.queue_free()


func _test_reach_and_arc() -> void:
	_section("C2: reach (feet to the target's edge, +10%) and arc (RANGED: no step or pull)")
	knight.attack.combo.attack_style = RANGED
	await _reset_knight()
	# 56 px reach x 1.1 = 61.6 px to the dummy's edge: center at 79.2 px.
	var cases := [
		["center 70 px ahead (in reach)", Vector2(70, 0), true],
		["center 78 px ahead (only thanks to +10%)", Vector2(78, 0), true],
		["center 82 px ahead (out of reach)", Vector2(82, 0), false],
		["behind the Knight", Vector2(-40, 0), false],
		["50 degrees off the aim (inside 55 degrees)", Vector2.from_angle(deg_to_rad(50.0)) * 50.0, true],
		["100 degrees off the aim", Vector2.from_angle(deg_to_rad(100.0)) * 60.0, false],
	]
	for c: Array in cases:
		var dummy := _dummy_at(c[1])
		await _frames(1)
		knight.attack.try_swing(Vector2.RIGHT)
		await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 40)
		_check("%s: %s" % [c[0], "hit" if c[2] else "miss"], dummy.health.current < dummy.health.max_health, c[2])
		dummy.queue_free()
		await _reset_knight()
	knight.attack.combo.attack_style = MELEE


func _test_buffered_press() -> void:
	_section("C2: a click during a swing queues the next one")
	await _reset_knight()
	var started: Array = []
	var record := func(index: int, _dir: Vector2, _swing: AttackSwing) -> void: started.append([_frame, index])
	knight.attack.swing_started.connect(record)
	knight.attack.try_swing(Vector2.RIGHT)
	await _frames(1)
	knight.player_input.buffer_action(&"attack")   # a click 1 frame into a 0.3 s swing
	await _wait_until(func() -> bool: return started.size() >= 2, 40)
	knight.attack.swing_started.disconnect(record)
	_check("the queued click started swing 2 (the buffer waited out the swing)", started.size() >= 2 and started[1][1] == 1, true)
	if started.size() >= 2:
		_check_near("right after swing 1 ended (~18 frames)", started[1][0] - started[0][0], 18.0, 2.0)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 40)


func _test_swing_cancels() -> void:
	_section("C2: dash and stun cancel a swing")
	await _reset_knight()
	var dummy := _dummy_at(Vector2(50, 0))
	knight.attack.try_swing(Vector2.RIGHT)
	await _frames(2)
	_check("dash during the windup", knight.dash.try_dash(Vector2.DOWN), true)
	_check("the swing is cancelled, root released", [knight.attack.is_swinging(), knight.movement.can_move()], [false, true])
	await _frames(20)
	_check("no hit", dummy.health.current, dummy.health.max_health)
	_check("the combo reset", knight.attack.get_combo_index(), 0)

	await _reset_knight()
	_place(dummy, knight.global_position + Vector2(50, 0))
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 20)
	var after_hit := dummy.health.current
	knight.dash.try_dash(Vector2.DOWN)
	_check("dash during the recovery cancels it", knight.attack.is_swinging(), false)
	_check("the hit already landed (64)", dummy.health.max_health - after_hit, 64.0)
	_check("and the combo reset", knight.attack.get_combo_index(), 0)

	await _reset_knight()
	_place(dummy, knight.global_position + Vector2(50, 0))
	var hp := dummy.health.current
	knight.attack.try_swing(Vector2.RIGHT)
	await _frames(2)
	knight.apply_stun(0.1)
	_check("stunned mid-windup: swing cancelled", knight.attack.is_swinging(), false)
	_check("can't swing while stunned", knight.attack.can_swing(), false)
	await _frames(20)
	_check("no hit, combo reset", [dummy.health.current, knight.attack.get_combo_index()], [hp, 0])
	dummy.queue_free()


func _test_ability_during_swing() -> void:
	_section("C2: Q/W/E/R during a swing (cancels_swing AFTER_HIT)")
	await _reset_knight()
	knight.attack.try_swing(Vector2.RIGHT)
	await _frames(1)
	_check("windup: Q may not interrupt", knight.can_interrupt_swing(&"q"), false)
	knight.abilities.q.cancels_swing = Ability.SwingCancel.ANYTIME
	_check("ANYTIME: Q may interrupt the windup", knight.can_interrupt_swing(&"q"), true)
	knight.abilities.q.cancels_swing = Ability.SwingCancel.NEVER
	await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 20)
	_check("NEVER: not even in the recovery", knight.can_interrupt_swing(&"q"), false)
	knight.abilities.q.cancels_swing = Ability.SwingCancel.AFTER_HIT
	_check("AFTER_HIT: Q may cut the recovery", knight.can_interrupt_swing(&"q"), true)
	knight.request_cast(&"q")
	_check("casting Q cancels the swing", [knight.abilities.casting, knight.attack.is_swinging()], [true, false])
	_check("and resets the combo", knight.attack.get_combo_index(), 0)
	await _wait_until(func() -> bool: return not knight.abilities.casting, 30)


func _test_iron_resolve_swing() -> void:
	_section("C2: Iron Resolve empowers the next swing (every enemy it hits)")
	await _reset_knight()
	var a := _dummy_at(Vector2(50, -15))
	var b := _dummy_at(Vector2(50, 15))
	var normal_speed := a.movement.get_move_speed()
	knight.request_cast(&"w")
	await _frames(1)
	_check("empowered", knight.attack.is_empowered(), true)
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 30)
	var bonus := 50.0 + 0.5 * 64.0
	_check("both take 64 + 82 bonus", [a.health.max_health - a.health.current, b.health.max_health - b.health.current], [64.0 + bonus, 64.0 + bonus])
	_check("both are slowed", [a.movement.get_move_speed() < normal_speed, b.movement.get_move_speed() < normal_speed], [true, true])
	_check("used up", knight.attack.is_empowered(), false)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 40)
	var hp := a.health.current
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 40)
	_check("the next swing has no bonus (64)", hp - a.health.current, 64.0)
	a.queue_free()
	b.queue_free()


func _test_attack_speed() -> void:
	_section("C2: attack speed speeds up the combo")
	await _reset_knight()
	_check("base: combo speed 1.0", knight.attack.get_swing_speed(), 1.0)
	knight.stats_component.add_modifier(StatModifier.create(&"attack_speed", PERCENT_ADD, 0.5, &"test_attack_speed"))
	_check("+50% bonus attack speed: combo speed 1.5", knight.attack.get_swing_speed(), 1.5)
	var start := _frame
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 40)
	_check_near("the swing lasts 0.3 / 1.5 = 0.2 s (12 frames)", _frame - start, 12.0, 1.0)
	knight.stats_component.remove_modifiers_from(&"test_attack_speed")


# --- Melee basic attacks ------------------------------------------------------------

func _test_melee() -> void:
	await _test_melee_data()
	await _test_step_in_the_air()
	await _test_pull()
	await _test_assist_picks()
	await _test_step_cancels()
	await _test_walk_out_of_recovery()
	await _test_ranged_style()


func _test_melee_data() -> void:
	_section("Melee: defaults")
	var combo := knight.attack.combo
	var s := combo.swings
	_check("the Knight's combo is MELEE", combo.attack_style, MELEE)
	_check("lunge_px 6 / 6 / 10", [s[0].lunge_px, s[1].lunge_px, s[2].lunge_px], [6.0, 6.0, 10.0])
	_check("lunge_max_px 24 / 24 / 32", [s[0].lunge_max_px, s[1].lunge_max_px, s[2].lunge_max_px], [24.0, 24.0, 32.0])
	_check("assist: +40 px, 35 deg, snap 20 deg, stop at 0.7 reach",
		[combo.assist_range_bonus_px, combo.assist_angle_deg, combo.assist_snap_deg, combo.stop_at_reach_fraction], [40.0, 35.0, 20.0, 0.7])
	_check("walk cancels recovery after 0.1 s", [combo.walk_cancels_recovery, combo.recovery_move_cancel_after], [true, 0.1])
	_check("unchanged: windup 0.08, 0.3 / 0.3 / 0.4 s", [s[0].windup, s[0].duration, s[1].duration, s[2].duration], [0.08, 0.3, 0.3, 0.4])


func _test_step_in_the_air() -> void:
	_section("Melee: every swing steps forward (empty air)")
	await _reset_knight()
	var steps: Array = []
	for i in 3:
		var from := knight.global_position
		knight.attack.try_swing(Vector2.RIGHT)
		_check("swing %d: the step is dash-cancelable" % (i + 1), knight.movement.is_displacement_dash_cancelable(), true)
		await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 40)
		steps.append(snappedf(knight.global_position.x - from.x, 0.01))
	_check("steps 6 / 6 / 10 px along the aim", steps, [6.0, 6.0, 10.0])
	_check("no sideways drift", knight.global_position.y, ARENA.y)


func _test_pull() -> void:
	_section("Melee: pull toward an aimed enemy")
	# Slime edge = center - 17.6. Stop point: edge at 0.7 x 56 = 39.2 px.
	await _reset_knight()
	var far := _dummy_at(Vector2.from_angle(deg_to_rad(15.0)) * 95.0)   # edge 77.4, out of reach
	await _frames(1)
	var from := knight.global_position
	knight.attack.try_swing(Vector2.RIGHT)
	_check("15 deg off the aim: it's the aimed enemy", knight.attack.get_assist_target() == far, true)
	_check_near("the aim snaps onto it (15 deg < 20 deg snap)", rad_to_deg(knight.attack.get_swing_direction().angle()), 15.0, 0.1)
	var hp := far.health.current
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 40)
	var moved := knight.global_position - from
	_check_near("pulled the capped 24 px (wanted 38.2)", moved.length(), 24.0, 0.3)
	_check_near("toward the slime", rad_to_deg(moved.angle()), 15.0, 0.5)
	_check("the swing connects from outside reach", far.health.current < hp, true)
	far.queue_free()

	await _reset_knight()
	var mid := _dummy_at(Vector2(75, 0))   # edge 57.4: wants 18.2 px
	await _frames(1)
	from = knight.global_position
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 40)
	# Measured from where the slime stood: the hit's 6 px knockback moves it after.
	var edge := (from + Vector2(75, 0)).distance_to(knight.global_position) - SLIME_RADIUS_PX
	_check_near("the step stretches 18.2 px, until its edge is 0.7 x reach away (39.2 px)", edge, 39.2, 0.3)
	mid.queue_free()

	await _reset_knight()
	var close := _dummy_at(Vector2(35, 0))   # edge 17.4: already closer
	await _frames(1)
	from = knight.global_position
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 40)
	_check_near("already closer: just lunge_px (6 px)", knight.global_position.x - from.x, 6.0, 0.3)
	close.queue_free()

	await _reset_knight()
	var touching := _dummy_at(Vector2(27, 0))   # bodies 11.2 + 14.4 px: 1.4 px of room
	await _frames(1)
	from = knight.global_position
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 40)
	_check("nearly touching: stops at its edge (<= 1.4 px)", knight.global_position.x - from.x <= 1.41, true)
	_check("the slime isn't pushed by the step", touching.global_position.x - (from.x + 27.0) <= 6.01, true)
	touching.queue_free()


func _test_assist_picks() -> void:
	_section("Melee: which enemy is aimed at")
	await _reset_knight()
	var side := _dummy_at(Vector2.from_angle(deg_to_rad(60.0)) * 60.0)
	await _frames(1)
	var from := knight.global_position
	knight.attack.try_swing(Vector2.RIGHT)
	_check("60 deg away: not aimed at", knight.attack.get_assist_target() == null, true)
	_check("aim not snapped", knight.attack.get_swing_direction(), Vector2.RIGHT)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 40)
	_check_near("plain 6 px step along the aim", knight.global_position.x - from.x, 6.0, 0.3)
	side.queue_free()

	await _reset_knight()
	var wide := _dummy_at(Vector2.from_angle(deg_to_rad(30.0)) * 60.0)
	await _frames(1)
	knight.attack.try_swing(Vector2.RIGHT)
	_check("30 deg off: aimed at", knight.attack.get_assist_target() == wide, true)
	_check_near("the aim snaps at most 20 deg", rad_to_deg(knight.attack.get_swing_direction().angle()), 20.0, 0.1)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 40)
	wide.queue_free()

	await _reset_knight()
	var near_wide := _dummy_at(Vector2.from_angle(deg_to_rad(25.0)) * 45.0)
	var far_line := _dummy_at(Vector2.from_angle(deg_to_rad(-5.0)) * 90.0)
	await _frames(1)
	knight.attack.try_swing(Vector2.RIGHT)
	_check("two in the cone: the one closest to the aim line wins", knight.attack.get_assist_target() == far_line, true)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 40)
	near_wide.queue_free()
	far_line.queue_free()

	await _reset_knight()
	var wall := _wall_at(knight.global_position + Vector2(40, 0), Vector2(8, 80))
	var hidden := _dummy_at(Vector2(90, 0))
	await _frames(2)
	_check("line of sight: blocked by the wall", WorldQuery.has_line_of_sight(knight.global_position, hidden.global_position), false)
	from = knight.global_position
	knight.attack.try_swing(Vector2.RIGHT)
	_check("a slime behind the pillar is never aimed at", knight.attack.get_assist_target() == null, true)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 40)
	_check("the step doesn't go through the wall", knight.global_position.x - from.x <= 6.01, true)
	hidden.queue_free()
	wall.queue_free()


func _test_step_cancels() -> void:
	_section("Melee: dash and stun during the step")
	await _reset_knight()
	var slime := _dummy_at(Vector2(95, 0))
	await _frames(1)
	knight.attack.try_swing(Vector2.RIGHT)
	_check("a dash is allowed during the step", knight.dash.can_dash(), true)
	_check("the dash replaces it and cancels the swing", [knight.dash.try_dash(Vector2.DOWN), knight.attack.is_swinging()], [true, false])
	await _frames(20)
	_check("the dash went down, not on toward the slime", knight.global_position.y - ARENA.y > 100.0, true)

	await _reset_knight()
	_place(slime, knight.global_position + Vector2(95, 0))
	await _frames(1)
	var from := knight.global_position
	knight.attack.try_swing(Vector2.RIGHT)
	await _frames(2)
	knight.apply_stun(0.1)
	_check("a stun ends the step", knight.movement.is_displaced(), false)
	await _frames(10)
	_check("the Knight stopped short of the planned 24 px", knight.global_position.x - from.x < 23.0, true)
	slime.queue_free()


func _test_walk_out_of_recovery() -> void:
	_section("Melee: walking ends the recovery's root")
	await _reset_knight()
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 20)
	var hit_frame := _frame
	Input.action_press(&"move_down")
	await _wait_until(func() -> bool: return not knight.attack.is_swing_rooted(), 30)
	_check_near("the root ends ~0.1 s after the hit (6 frames)", _frame - hit_frame, 6.0, 1.0)
	var y := knight.global_position.y
	await _frames(3)
	_check("the Knight walks at once", knight.global_position.y > y + 3.0, true)
	_check("the swing still runs out its duration", knight.attack.is_swinging(), true)
	_check("state MOVE while walking out", knight.state, Player.State.MOVE)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 30)
	_check("the combo continues (next is swing 2)", knight.attack.get_combo_index(), 1)
	knight.attack.try_swing(Vector2.RIGHT)
	_check("holding a direction: the next swing still roots its windup", knight.movement.can_move(), false)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 30)
	_check("walk -> swing -> walk -> swing reaches swing 3", knight.attack.get_combo_index(), 2)
	Input.action_release(&"move_down")
	await _frames(1)


func _test_ranged_style() -> void:
	_section("RANGED combo: no step, pull or snap (walk-cancel still works)")
	knight.attack.combo.attack_style = RANGED
	await _reset_knight()
	var slime := _dummy_at(Vector2.from_angle(deg_to_rad(15.0)) * 95.0)
	await _frames(1)
	var from := knight.global_position
	knight.attack.try_swing(Vector2.RIGHT)
	_check("no aimed enemy, no snap", [knight.attack.get_assist_target() == null, knight.attack.get_swing_direction()], [true, Vector2.RIGHT])
	await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 20)
	_check("no step", knight.global_position, from)
	Input.action_press(&"move_down")
	await _frames(8)
	_check("walking still ends the root", knight.attack.is_swing_rooted(), false)
	Input.action_release(&"move_down")
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 30)
	knight.attack.combo.attack_style = MELEE
	slime.queue_free()


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


func _test_death_mid_swing() -> void:
	_section("C2: the attacker dies mid-swing")
	await _reset_knight()
	var dummy := _dummy_at(Vector2(50, 0))
	knight.attack.try_swing(Vector2.RIGHT)
	await _frames(2)
	knight.take_damage(100000.0)
	await _frames(20)
	_check("dead Knight: swing cancelled, no hit", [knight.attack.is_swinging(), dummy.health.current], [false, dummy.health.max_health])


## Knight in the arena, not swinging, dash charges back, combo reset.
func _reset_knight() -> void:
	knight.attack.cancel_swing()
	await _frames(40)   # > combo_reset_time; dash recharge, knockback and casts settle
	_place(knight, ARENA)
	await _frames(1)


func _dummy_at(offset: Vector2) -> Enemy:
	var dummy := _spawn_dummy()
	_place(dummy, knight.global_position + offset)
	return dummy


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


func _physics_process(_delta: float) -> void:
	_frame += 1


# --- Helpers ------------------------------------------------------------------

## A passive slime in its own spot, 200 px right of the Knight and 100 px
## below the previous one, so dummies never overlap (freed ones linger until
## the frame ends).
func _spawn_dummy() -> Enemy:
	var dummy: Enemy = SLIME_SCENE.instantiate()
	dummy.passive = true
	dummy.position = Vector2(200, _next_dummy_y)
	_next_dummy_y += 100.0
	add_child(dummy)
	return dummy


func _hit(target: Unit, amount: float, type: HitContext.DamageType, knockback_px: float = 0.0) -> HitContext:
	var ctx := HitContext.new()
	ctx.source = knight
	ctx.target = target
	ctx.base_damage = amount
	ctx.damage_type = type
	ctx.knockback_px = knockback_px
	return HitPipeline.resolve(ctx)


func _clear_events() -> void:
	_hits.clear()
	_damaged.clear()
	_deaths.clear()


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
