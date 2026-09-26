extends Node2D
## COMBAT.md steps C1-C2 test: open res://scenes/tests/combat_test.tscn and press F6.
## Spawns the real player.tscn and passive slimes (training dummies) and
## runs hits through the hit pipeline: mitigation for all three damage types
## at 0 and 100 armor/magic_resist, stat scaling, the take_damage() and
## Hurtbox wrappers, i-frames, knockback, kills and the Events signals (C1).
## C2: the Knight's combo swings (timing, damage, reach and arc, root,
## combo and reset, the input buffer, dash / stun / ability cancels, Iron
## Resolve, attack speed). The C2 section runs last: it ends by killing the
## Knight.
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
	_section("C2: reach (feet to the target's edge, +10%) and arc")
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
