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
## C3: hit feel (hitstop and shake per tier, kills, longest-wins hitstops,
## the flash; abilities and enemy hits unchanged).
## C4: getting hit (post-hit i-frames and their blink, a slime's 12 px push
## that a dash can cut short, whiffs out of reach, the 0.25 s slime windup,
## the stronger knockback winning).
## C5: the elite slime's telegraphed slam (numbers, the telegraph, a hit,
## walking and dashing out, a stun, the AI casting it by itself).
## C6: damage numbers (log size steps, crit, colors by type, red on the
## player, DoT merging, heals, rise and fade, none for blocked hits).
## C7: line of sight (swings, enemy attacks, Cleave, Lunge, Judgement and the
## slam don't hit through walls; ignores_walls does).
## STATS step 6: a fake item with scoped modifiers changes the Knight's real
## casts (Cleave cooldown and damage, Lunge range, hit tags) and removing it
## restores them.
## C8: the Knight's abilities through HitPipeline.from_ability() (numbers
## unchanged, tags), crits (PRD, one roll per swing or cast), damage_increase with hit / target scopes,
## incoming_damage, on-hit damage, life on hit, life steal, resource on hit.
## C9: status effects (the stun, slow and haste .tres, the apply_stun() and
## add_speed_modifier() wrappers, stack rules, tenacity, DoT with snapshot
## and kill credit, statuses on hits, events, death).
## Prints PASS/FAIL per check, then a total. Run headless and it quits with
## the number of failures as the exit code.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const SLIME_SCENE: PackedScene = preload("res://scenes/enemies/slime.tscn")
const ELITE_SCENE: PackedScene = preload("res://scenes/enemies/slime_elite.tscn")
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
var _game_time: float = 0.0   # physics time; stands nearly still during hitstops
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
	await _test_combo_pace()
	await _test_combo_lengths()
	await _test_hit_feel()
	await _test_melee()
	await _test_getting_hit()
	await _test_elite()
	await _test_damage_numbers()
	await _test_line_of_sight()
	await _test_item_changes_abilities()
	await _test_crits_and_on_hit()
	await _test_statuses()
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
	var start_time := _game_time
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
	# Game time: the hit's light hitstop (0.03 s at time_scale 0.05) adds
	# physics frames but almost no game time. The test's clock also counts
	# the frame the swing started in, which the swing itself skips (+1/60).
	_check_near("the swing lasts 0.3 s of game time (18 frames at 1/60 s)", _game_time - start_time, 0.3 + 1.0 / 60.0, 0.004)
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
	await _wait_until(func() -> bool: return not knight.attack.is_in_pause(), 30)   # the finisher's breather
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


# --- Combo pace: speed_scale and pause_after ----------------------------------------

func _test_combo_pace() -> void:
	_section("Combo pace: the finisher's breather and the speed knob")
	var combo := knight.attack.combo
	_check("pause_after 0 / 0 / 0.25 s, speed_scale 1.0",
		[combo.swings[0].pause_after, combo.swings[1].pause_after, combo.swings[2].pause_after, combo.speed_scale], [0.0, 0.0, 0.25, 1.0])
	await _reset_knight()
	for i in 3:
		knight.attack.try_swing(Vector2.RIGHT)
		await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 40)
		if i < 2:
			_check("no pause after swing %d" % (i + 1), knight.attack.can_swing(), true)
	_check("after the finisher: a breather", [knight.attack.is_in_pause(), knight.attack.try_swing(Vector2.RIGHT)], [true, false])
	_check("moving isn't blocked by it", knight.movement.can_move(), true)
	_check("dashing isn't blocked by it", knight.dash.can_dash(), true)
	var t0 := _game_time
	knight.player_input.buffer_action(&"attack")   # a click during the breather
	await _wait_until(func() -> bool: return knight.attack.is_swinging(), 40)
	_check_near("the click fires when the 0.25 s breather ends", _game_time - t0, 0.25, 0.04)
	_check("starting the combo over", knight.attack.get_combo_index(), 0)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 40)

	await _reset_knight()
	for i in 2:
		knight.attack.try_swing(Vector2.RIGHT)
		await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 40)
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 20)
	knight.dash.try_dash(Vector2.DOWN)
	_check("dash-cancelling the finisher after its hit still leaves the breather", knight.attack.is_in_pause(), true)
	await _frames(20)

	await _reset_knight()
	combo.speed_scale = 2.0
	_check("speed_scale 2.0 doubles the combo speed", knight.attack.get_swing_speed(), 2.0)
	var start := _game_time
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 40)
	_check_near("a 0.3 s swing takes 0.15 s", _game_time - start, 0.15 + 1.0 / 60.0, 0.02)
	combo.speed_scale = 1.0


# --- Combo lengths: any number of swings --------------------------------------------

func _test_combo_lengths() -> void:
	_section("Combo length is data: a 2-hit and a 5-hit combo")
	var knight_combo := knight.attack.combo
	for count: int in [2, 5]:
		var combo := AttackCombo.new()
		for i in count:
			var swing := AttackSwing.new()
			swing.duration = 0.2
			swing.ad_ratio = 0.2 * (i + 1)   # 12.8, 25.6, 38.4... so each swing is recognizable
			combo.swings.append(swing)
		knight.attack.combo = combo
		await _reset_knight()
		var dummy := _dummy_at(Vector2(50, 0))
		await _frames(1)
		var damage: Array = []
		for i in count + 1:
			dummy.health.heal(10000.0)
			var before := dummy.health.current
			knight.attack.try_swing(Vector2.RIGHT)
			await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 40)
			damage.append(roundi((before - dummy.health.current) / 12.8))
			_place(dummy, knight.global_position + Vector2(50, 0))
			await _frames(1)
		var expected: Array = []
		for i in count:
			expected.append(i + 1)
		expected.append(1)
		_check("%d-hit combo: swings 1..%d, then it starts over" % [count, count], damage, expected)
		dummy.queue_free()
	knight.attack.combo = knight_combo
	await _reset_knight()


# --- C3: hit feel -------------------------------------------------------------------

var _shakes: Array[float] = []
var _hitstop_at_hit: float = 0.0   # GameFeel.get_hitstop_left() read as a swing lands


func _test_hit_feel() -> void:
	var cam := _spy_camera()
	var read_hitstop := func(_index: int, _targets: Array[Unit]) -> void:
		_hitstop_at_hit = GameFeel.get_hitstop_left()
	knight.attack.swing_landed.connect(read_hitstop)
	await _test_hit_feel_data()
	await _test_longest_hitstop()
	await _test_swing_feel_tiers()
	await _test_feel_unchanged_for_abilities()
	await _test_flash()
	knight.attack.swing_landed.disconnect(read_hitstop)
	cam.queue_free()


func _test_hit_feel_data() -> void:
	_section("C3: hit feel numbers (hit_feel_default.tres)")
	var f := GameFeel.hit_feel
	_check("hitstop light / heavy / kill = 0.03 / 0.06 / 0.08", [f.light_hitstop, f.heavy_hitstop, f.kill_hitstop], [0.03, 0.06, 0.08])
	_check("shake light / heavy / kill = 0 / 2 / 3 px", [f.light_shake, f.heavy_shake, f.kill_shake], [0.0, 2.0, 3.0])
	_check("flash 0.06 s", f.flash_time, 0.06)
	_check("combo feel: LIGHT / LIGHT / HEAVY",
		[knight.attack.combo.swings[0].feel, knight.attack.combo.swings[1].feel, knight.attack.combo.swings[2].feel],
		[HitContext.Feel.LIGHT, HitContext.Feel.LIGHT, HitContext.Feel.HEAVY])


func _test_longest_hitstop() -> void:
	_section("C3: overlapping hitstops: the longest wins")
	await _hitstop_over()
	GameFeel.hitstop(0.03)
	_check("a hitstop slows time to 0.05", Engine.time_scale, 0.05)
	GameFeel.hitstop(0.08)
	_check_near("a longer one extends it to 0.08 s", GameFeel.get_hitstop_left(), 0.08, 0.005)
	GameFeel.hitstop(0.02)
	_check_near("a shorter one changes nothing", GameFeel.get_hitstop_left(), 0.08, 0.005)
	await get_tree().create_timer(0.05, true, false, true).timeout
	_check("still frozen at 0.05 s (the first would have ended)", GameFeel.is_hitstop_active(), true)
	await get_tree().create_timer(0.05, true, false, true).timeout
	_check("over by 0.10 s, time back to normal", [GameFeel.is_hitstop_active(), Engine.time_scale], [false, 1.0])


func _test_swing_feel_tiers() -> void:
	_section("C3: swing feel by tier")
	await _reset_knight()
	await _hitstop_over()
	var dummy := _dummy_at(Vector2(50, 0))
	var feel: Array = []   # [hitstop left at the hit, shakes]
	for i in 3:
		dummy.health.heal(1000.0)
		_place(dummy, knight.global_position + Vector2(50, 0))
		await _frames(1)
		_shakes.clear()
		knight.attack.try_swing(Vector2.RIGHT)
		await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 20)
		feel.append([snappedf(_hitstop_at_hit, 0.01), _shakes.duplicate()])
		await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 60)
		await _hitstop_over()
	_check("swing 1: light freeze 0.03 s, no shake", feel[0], [0.03, []])
	_check("swing 2: light freeze 0.03 s, no shake", feel[1], [0.03, []])
	_check("finisher: heavy freeze 0.06 s, 2 px shake", feel[2], [0.06, [2.0]])

	await _reset_knight()
	dummy.health.heal(1000.0)
	dummy.health.take_damage(dummy.health.current - 10.0)   # 10 health left
	_place(dummy, knight.global_position + Vector2(50, 0))
	await _frames(1)
	_shakes.clear()
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 20)
	_check("a kill: freeze 0.08 s, 3 px shake", [snappedf(_hitstop_at_hit, 0.01), _shakes], [0.08, [3.0]])
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 60)
	await _hitstop_over()

	await _reset_knight()
	_shakes.clear()
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 20)
	_check("a whiff: no freeze, no shake", [GameFeel.is_hitstop_active(), _shakes], [false, []])
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 60)


func _test_feel_unchanged_for_abilities() -> void:
	_section("C3: abilities and enemy hits keep their own feel")
	await _reset_knight()
	await _hitstop_over()
	var dummy := _dummy_at(Vector2(40, 0))
	await _frames(1)
	_shakes.clear()
	var ctx := dummy.make_hit_context(10.0, knight)   # a take_damage() hit: feel NONE
	dummy.on_hit(ctx)
	_check("feel NONE (take_damage): no freeze, no shake", [GameFeel.is_hitstop_active(), _shakes], [false, []])
	knight.request_cast(&"q")
	await _wait_until(func() -> bool: return not knight.abilities.casting, 40)
	_check("Cleave: its own 3 px shake only", _shakes, [3.0])
	await _hitstop_over()
	_shakes.clear()
	var blocked := _hit(dummy, 10.0, HitContext.DamageType.TRUE)
	dummy.add_invulnerability(&"test")
	var ctx2 := HitPipeline.basic_attack(knight, dummy, knight.attack.combo.swings[2])
	HitPipeline.resolve(ctx2)
	dummy.remove_invulnerability(&"test")
	_check("a blocked hit: no feel", [ctx2.blocked, GameFeel.is_hitstop_active(), _shakes], [true, false, []])
	_check("(pipeline hits default to feel NONE)", blocked.feel, HitContext.Feel.NONE)
	dummy.queue_free()


func _test_flash() -> void:
	_section("C3: the hit flash")
	await _hitstop_over()
	var dummy := _dummy_at(Vector2(40, 0))
	await _frames(1)
	dummy.take_damage(5.0, knight)
	_check("white at the hit", dummy.body.modulate, GameFeel.hit_feel.flash_modulate)
	var t0 := _game_time
	await _wait_until(func() -> bool: return _game_time - t0 >= 0.07, 20)
	_check("back to normal after 0.06 s", dummy.body.modulate, Color.WHITE)
	dummy.queue_free()


## A camera that records GameFeel.shake() amounts.
func _spy_camera() -> Camera2D:
	var script := GDScript.new()
	script.source_code = "extends Camera2D\nvar on_shake: Callable\nfunc shake(amount: float) -> void:\n\ton_shake.call(amount)\n"
	script.reload()
	var cam := Camera2D.new()
	cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS   # what interpolation needs
	cam.set_script(script)
	cam.set("on_shake", func(amount: float) -> void: _shakes.append(amount))
	add_child(cam)
	cam.make_current()
	return cam


func _hitstop_over() -> void:
	while GameFeel.is_hitstop_active():
		await get_tree().create_timer(0.02, true, false, true).timeout


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


# --- C4: getting hit ---------------------------------------------------------------

func _test_getting_hit() -> void:
	await _test_getting_hit_data()
	await _test_post_hit_iframes()
	await _test_slime_hit_and_push()
	await _test_whiff()
	await _test_stronger_knockback()


func _test_getting_hit_data() -> void:
	_section("C4: numbers")
	var slime := _spawn_dummy()
	_check("the Knight: 0.3 s post-hit i-frames", knight.post_hit_iframes, 0.3)
	_check("slimes: 12 px push, attacks reach 10% short", [slime.attack.hit_knockback_px, slime.attack.enemy_hit_forgiveness], [12.0, 0.1])
	_check_near("slime windup 0.25 s (swarm band 0-0.3 s)", slime.attack.get_windup_time(), 0.25, 0.001)
	_check("slimes take no i-frames", slime.post_hit_iframes, 0.0)
	slime.queue_free()


func _test_post_hit_iframes() -> void:
	_section("C4: post-hit i-frames")
	await _reset_knight()
	await _hitstop_over()
	knight.health.heal(10000.0)
	var first := _hit(knight, 50.0, HitContext.DamageType.TRUE)
	var second := _hit(knight, 50.0, HitContext.DamageType.TRUE)
	_check("the first hit lands", [first.blocked, first.taken_damage], [false, 50.0])
	_check("a second hit in the same frame is blocked", second.blocked, true)
	_check("i-frames on", knight.has_invulnerability(Unit.HIT_IFRAMES_ID), true)
	var hidden_seen := false
	var t0 := _game_time
	while knight.has_invulnerability(Unit.HIT_IFRAMES_ID) and _game_time - t0 < 1.0:
		await get_tree().process_frame
		if not knight.body.visible:
			hidden_seen = true
	_check_near("they last 0.3 s", _game_time - t0, 0.3, 0.05)
	_check("the Knight blinks meanwhile", hidden_seen, true)
	await get_tree().process_frame
	_check("and shows again after", knight.body.visible, true)
	var third := _hit(knight, 50.0, HitContext.DamageType.TRUE)
	_check("then hits land again", third.blocked, false)
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	var dot := HitContext.new()
	dot.source = null
	dot.target = knight
	dot.base_damage = 5.0
	dot.add_tag(&"dot")
	HitPipeline.resolve(dot)
	_check("a DoT tick lands but starts no i-frames", [dot.blocked, knight.has_invulnerability(Unit.HIT_IFRAMES_ID)], [false, false])
	var slime := _spawn_dummy()
	_hit(slime, 10.0, HitContext.DamageType.TRUE)
	_check("slimes: every hit lands", _hit(slime, 10.0, HitContext.DamageType.TRUE).blocked, false)
	slime.queue_free()
	knight.health.heal(10000.0)


func _test_slime_hit_and_push() -> void:
	_section("C4: a slime hits the Knight")
	await _reset_knight()
	await _hitstop_over()
	knight.health.heal(10000.0)
	var slime := _dummy_at(Vector2(45, 0))   # edge 6.6 px: in reach
	await _frames(1)
	var start := knight.global_position
	var hp := knight.health.current
	var t0 := _game_time
	slime.attack.attack(knight)
	await _wait_until(func() -> bool: return knight.health.current < hp, 60)
	_check_near("windup to hit: 0.25 s", _game_time - t0, 0.25 + 1.0 / 60.0, 0.02)
	_check("22 damage", hp - knight.health.current, 22.0)
	_check("the push is dash-cancelable", knight.movement.is_displacement_dash_cancelable(), true)
	_check("a dash during the push is allowed", knight.dash.can_dash(), true)
	await _frames(10)
	_check_near("pushed 12 px, away from the slime", start.x - knight.global_position.x, 12.0, 0.5)
	slime.attack.cancel()

	await _reset_knight()
	knight.health.heal(10000.0)
	_place(slime, knight.global_position + Vector2(45, 0))
	await _frames(1)
	hp = knight.health.current
	slime.attack.attack(knight)
	await _wait_until(func() -> bool: return knight.health.current < hp, 60)
	_check("hit again (after the i-frames ran out)", knight.health.current < hp, true)
	_check("the dash replaces the push at once", knight.dash.try_dash(Vector2.DOWN), true)
	await _frames(20)
	_check("dashed down instead of being pushed", knight.global_position.y - ARENA.y > 100.0, true)
	slime.attack.cancel()
	slime.queue_free()


func _test_whiff() -> void:
	_section("C4: walking out of reach makes a slime miss")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	knight.health.heal(10000.0)
	var slime := _dummy_at(Vector2(45, 0))
	await _frames(1)
	var whiffs: Array = []
	slime.attack.attack_whiffed.connect(func(t: Unit) -> void: whiffs.append(t))
	var hp := knight.health.current
	slime.attack.attack(knight)
	await _wait_until(func() -> bool: return slime.attack.is_winding_up(), 10)
	_check("the slime winds up", slime.attack.is_winding_up(), true)
	_place(knight, knight.global_position + Vector2(-40, 0))   # edge 46.6 px > 31.7 px reach
	await _wait_until(func() -> bool: return not slime.attack.is_winding_up(), 30)
	await _frames(2)
	_check("a whiff: no damage", knight.health.current, hp)
	_check("attack_whiffed is emitted", whiffs.size(), 1)
	slime.attack.cancel()
	slime.queue_free()


func _test_stronger_knockback() -> void:
	_section("C4: two knockbacks: the stronger one wins")
	var a := _spawn_dummy()
	var from := a.global_position
	_check("a 20 px push starts", a.movement.displace(Vector2(200, 0), 0.1), true)
	_check("a 6 px push during it is dropped", a.movement.displace(Vector2(0, 60), 0.1), false)
	await _frames(12)
	_check_near("ends 20 px along the first push", (a.global_position - from).x, 20.0, 0.5)
	_check_near("no sideways part", (a.global_position - from).y, 0.0, 0.5)
	from = a.global_position
	a.movement.displace(Vector2(60, 0), 0.1)
	_check("a bigger push replaces a smaller one", a.movement.displace(Vector2(0, 300), 0.1), true)
	await _frames(12)
	_check_near("ends 30 px along the bigger push", (a.global_position - from).y, 30.0, 1.0)
	a.queue_free()

	await _reset_knight()
	knight.movement.displace(Vector2(-400, 0), 0.1)   # a 40 px knockback
	knight.attack.try_swing(Vector2.RIGHT)
	_check("a swing during a stronger knockback: its step is dropped", knight.movement.get_displacement_remaining_px() > 30.0, true)
	knight.attack.cancel_swing()
	_check("cancelling the swing leaves the knockback alone", knight.movement.is_displaced(), true)
	await _frames(12)


# --- C5: elite slime --------------------------------------------------------------

func _test_elite() -> void:
	await _test_elite_data()
	await _test_slam_hits()
	await _test_slam_dodges()
	await _test_elite_ai()


func _test_elite_data() -> void:
	_section("C5: the elite and its slam")
	var elite := _spawn_elite(Vector2(0, 0), true)
	var slam := elite.abilities.get_ability(&"q")
	_check("900 health, basic attack 30 (4.6%: swarm band)", [elite.health.max_health, elite.stats_component.get_stat(&"attack_damage")], [900.0, 30.0])
	_check_near("its basic attack winds up 0.25 s", elite.attack.get_windup_time(), 0.25, 0.001)
	_check("slam: 0.65 s telegraph, 72 px circle, 100 damage, 4 s cooldown",
		[slam.cast_time, slam.get("radius_px"), slam.base_damage, slam.cooldown], [0.65, 72.0, 100.0, 4.0])
	_check_near("100 = 15.4% of the Knight's 650 (elite band 12-20%)", slam.base_damage / knight.health.max_health, 0.154, 0.001)
	elite.queue_free()


func _test_slam_hits() -> void:
	_section("C5: standing in the slam")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	knight.health.heal(10000.0)
	var elite := _spawn_elite(knight.global_position + Vector2(60, 0), true)
	await _frames(1)
	var hp := knight.health.current
	var start := knight.global_position
	_check("the elite casts the slam at the Knight", elite.abilities.try_cast(&"q", knight.global_position, knight), true)
	var telegraph := _find_telegraph()
	_check("a telegraph appears where the Knight stands", telegraph != null and telegraph.global_position.distance_to(start) < 0.5, true)
	_check("the elite is rooted while casting", elite.movement.can_move(), false)
	await _frames(19)
	_check_near("it fills up (about half at 0.32 s)", telegraph.get_progress() if telegraph else -1.0, 0.5, 0.1)
	_check("no damage before the slam", knight.health.current, hp)
	var t0 := _game_time
	await _wait_until(func() -> bool: return knight.health.current < hp, 40)
	_check("100 damage at 0.65 s", hp - knight.health.current, 100.0)
	await _frames(12)
	_check_near("pushed 20 px away from the elite", start.x - knight.global_position.x, 20.0, 1.0)
	await _frames(10)
	_check("the telegraph is gone after the slam", is_instance_valid(telegraph), false)
	elite.queue_free()
	knight.health.heal(10000.0)


func _test_slam_dodges() -> void:
	_section("C5: getting out of the slam")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	var elite := _spawn_elite(knight.global_position + Vector2(60, 0), true)
	await _frames(1)
	var hp := knight.health.current
	elite.abilities.try_cast(&"q", knight.global_position, knight)
	await _frames(20)
	_place(knight, knight.global_position + Vector2(-120, 0))   # walked out (72 px circle)
	await _wait_until(func() -> bool: return not elite.abilities.casting, 60)
	await _frames(2)
	_check("walked out: no damage", knight.health.current, hp)

	await _reset_knight()
	_place(elite, knight.global_position + Vector2(60, 0))
	await _wait_until(func() -> bool: return elite.abilities.can_cast(&"q"), 300)
	elite.abilities.try_cast(&"q", knight.global_position, knight)
	await _frames(30)
	knight.dash.try_dash(Vector2.LEFT)
	await _wait_until(func() -> bool: return not elite.abilities.casting, 60)
	await _frames(2)
	_check("dashed out: no damage", knight.health.current, hp)

	await _reset_knight()
	_place(elite, knight.global_position + Vector2(60, 0))
	await _wait_until(func() -> bool: return elite.abilities.can_cast(&"q"), 300)
	elite.abilities.try_cast(&"q", knight.global_position, knight)
	var telegraph := _find_telegraph()
	await _frames(10)
	# Lasts past the cast's end: AbilityComponent checks for a stun when the
	# cast time is over (a stun that ends earlier doesn't interrupt; see
	# the report for C5).
	elite.apply_stun(1.0)
	await _wait_until(func() -> bool: return not elite.abilities.casting, 60)
	await _frames(2)
	_check("a stunned elite's slam doesn't go off", knight.health.current, hp)
	_check("its telegraph is removed", is_instance_valid(telegraph), false)
	_check("and the cooldown refunded", elite.abilities.is_ready(&"q"), true)
	elite.queue_free()


func _test_elite_ai() -> void:
	_section("C5: the elite AI casts the slam by itself")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	knight.health.heal(10000.0)
	var elite := _spawn_elite(knight.global_position + Vector2(70, 0), false)
	await _wait_until(func() -> bool: return elite.abilities.casting, 90)
	_check("it aggroes and casts the slam", elite.abilities.casting, true)
	var telegraph := _find_telegraph()
	_check("aimed at the Knight", telegraph != null and telegraph.global_position.distance_to(knight.global_position) < 1.0, true)
	var hp := knight.health.current
	_place(knight, knight.global_position + Vector2(-140, 0))
	await _wait_until(func() -> bool: return not elite.abilities.casting, 60)
	_check("the Knight walked out: no damage", knight.health.current, hp)
	elite.passive = true
	elite.attack.cancel()
	elite.queue_free()
	await _frames(2)


func _spawn_elite(pos: Vector2, passive: bool) -> Enemy:
	var elite: Enemy = ELITE_SCENE.instantiate()
	elite.passive = passive
	add_child(elite)
	_place(elite, pos)
	return elite


func _find_telegraph() -> Telegraph:
	for n in get_children():
		if n is Telegraph and not n.is_queued_for_deletion():
			return n
	return null


# --- C6: damage numbers -----------------------------------------------------------

const NUMBER_SCRIPT := preload("res://scripts/ui/damage_number.gd")


func _test_damage_numbers() -> void:
	var style: DamageNumberStyle = NUMBER_SCRIPT.DEFAULT_STYLE
	_section("C6: damage numbers")
	_check("size steps 10 / 12 / 14 at 0 / 100 / 1000 (log scale)",
		[style.get_font_size(22.0), style.get_font_size(64.0), style.get_font_size(102.4), style.get_font_size(1500.0)], [10, 10, 12, 14])
	await _reset_knight()
	await _hitstop_over()
	var dummy := _dummy_at(Vector2(50, 0))
	await _frames(1)
	var numbers: Array = []
	for i in 3:
		dummy.health.heal(1000.0)
		_place(dummy, knight.global_position + Vector2(50, 0))
		await _frames(1)
		var before := _numbers()
		knight.attack.try_swing(Vector2.RIGHT)
		await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 20)
		var new := _numbers().filter(func(n: Label) -> bool: return not before.has(n))
		numbers.append(new.map(func(n: Label) -> Array: return [n.text, n.font_size, n.color]))
		await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 60)
		await _wait_until(func() -> bool: return not knight.attack.is_in_pause(), 30)
		await _hitstop_over()
	_check("every swing shows one number", [numbers[0].size(), numbers[1].size(), numbers[2].size()], [1, 1, 1])
	if numbers[0].size() == 1 and numbers[2].size() == 1:
		_check("swing 1: \"64\", size 10, physical color", numbers[0][0], ["64", 10, style.physical_color])
		_check("the finisher's 102 is a size bigger", numbers[2][0].slice(0, 2), ["102", 12])

	dummy.health.heal(1000.0)
	var before := _numbers()
	var magic := HitContext.new()
	magic.source = knight
	magic.target = dummy
	magic.base_damage = 30.0
	magic.damage_type = HitContext.DamageType.MAGIC
	HitPipeline.resolve(magic)
	var true_hit := _hit(dummy, 30.0, HitContext.DamageType.TRUE)
	var added := _numbers().filter(func(n: Label) -> bool: return not before.has(n))
	_check("magic blue, true white", added.map(func(n: Label) -> Color: return n.color), [style.magic_color, style.true_color])

	before = _numbers()
	var crit := HitPipeline.basic_attack(knight, dummy, knight.attack.combo.swings[0])
	crit.raw_damage = 64.0
	crit.is_crit = true
	dummy.on_hit(crit)
	added = _numbers().filter(func(n: Label) -> bool: return not before.has(n))
	_check("a crit: \"64!\", 3 sizes bigger", added.map(func(n: Label) -> Array: return [n.text, n.font_size]), [["64!", 13]])

	before = _numbers()
	for i in 3:
		var tick := dummy.make_hit_context(10.0, knight)
		tick.add_tag(&"dot")
		dummy.on_hit(tick)
		await _frames(3)
	added = _numbers().filter(func(n: Label) -> bool: return not before.has(n))
	_check("DoT ticks within 0.3 s merge into one small number", added.map(func(n: Label) -> Array: return [n.text, n.font_size]), [["30", 8]])
	await _frames(25)
	before = _numbers()
	var late := dummy.make_hit_context(10.0, knight)
	late.add_tag(&"dot")
	dummy.on_hit(late)
	added = _numbers().filter(func(n: Label) -> bool: return not before.has(n))
	_check("a tick after the window starts a new number", added.size(), 1)

	before = _numbers()
	dummy.show_heal_number(15.0)
	added = _numbers().filter(func(n: Label) -> bool: return not before.has(n))
	_check("healing: green \"+15\"", added.map(func(n: Label) -> Array: return [n.text, n.color]), [["+15", style.heal_color]])

	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	before = _numbers()
	_hit(knight, 20.0, HitContext.DamageType.MAGIC)
	added = _numbers().filter(func(n: Label) -> bool: return not before.has(n))
	_check("damage the player takes is red (any type)", added.map(func(n: Label) -> Color: return n.color), [style.player_damage_color])
	before = _numbers()
	_hit(knight, 20.0, HitContext.DamageType.MAGIC)   # blocked by the i-frames
	_check("a blocked hit shows no number", _numbers().filter(func(n: Label) -> bool: return not before.has(n)).size(), 0)
	knight.health.heal(10000.0)

	before = _numbers()
	dummy.take_damage(40.0, knight)
	added = _numbers().filter(func(n: Label) -> bool: return not before.has(n))
	if added.size() == 1:
		var n: Label = added[0]
		var y0 := n.position.y
		var t0 := _game_time
		await _wait_until(func() -> bool: return _game_time - t0 >= 0.5, 60)
		_check_near("it rises 12 px", y0 - n.position.y, 12.0, 1.5)
		_check("and fades", n.modulate.a < 0.5, true)
		var ref: WeakRef = weakref(n)
		await _wait_until(func() -> bool: return ref.get_ref() == null, 20)
		_check("gone after 0.6 s", ref.get_ref() == null, true)
	dummy.queue_free()


func _numbers() -> Array:
	return get_children().filter(func(n: Node) -> bool:
		return n is Label and n.get_script() == NUMBER_SCRIPT and not n.is_queued_for_deletion())


# --- C7: line of sight -------------------------------------------------------------

func _test_line_of_sight() -> void:
	_section("C7: walls block hits")
	_check("abilities are blocked by walls by default",
		[knight.abilities.q.ignores_walls, knight.abilities.e.ignores_walls, knight.abilities.r.ignores_walls], [false, false, false])

	# Swing: a dummy in reach, behind a thin wall.
	await _reset_knight()
	await _hitstop_over()
	var wall := _wall_at(knight.global_position + Vector2(24, 0), Vector2(4, 80))
	var dummy := _dummy_at(Vector2(40, 0))
	await _frames(2)
	var hp := dummy.health.current
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 40)
	_check("a swing doesn't hit through a wall", dummy.health.current, hp)
	await _wait_until(func() -> bool: return not knight.attack.is_in_pause(), 30)

	# Cleave, with and without ignores_walls.
	await _reset_knight()
	_place(wall, knight.global_position + Vector2(24, 0))
	_place(dummy, knight.global_position + Vector2(50, 0))
	await _frames(2)
	hp = dummy.health.current
	knight.abilities.try_cast(&"q", knight.global_position + Vector2(100, 0))
	await _wait_until(func() -> bool: return not knight.abilities.casting, 40)
	_check("Cleave doesn't hit through a wall", dummy.health.current, hp)
	await _wait_until(func() -> bool: return knight.abilities.is_ready(&"q"), 240)
	knight.abilities.q.ignores_walls = true
	knight.abilities.try_cast(&"q", knight.global_position + Vector2(100, 0))
	await _wait_until(func() -> bool: return not knight.abilities.casting, 40)
	knight.abilities.q.ignores_walls = false
	_check("with ignores_walls it does", dummy.health.current < hp, true)
	await _hitstop_over()

	# Lunge: a dummy beside the path, across a wall that runs along it.
	await _reset_knight()
	dummy.health.heal(1000.0)
	_place(wall, knight.global_position + Vector2(60, 15))
	wall.rotation = PI / 2.0   # now 80 px long along the path, 4 px thick
	_place(dummy, knight.global_position + Vector2(60, 28))
	await _frames(2)
	hp = dummy.health.current
	var lunge_path_ok := WorldQuery.has_line_of_sight(knight.global_position, knight.global_position + Vector2(120, 0))
	var in_width := AbilityUtil.along_segment(knight, knight.global_position, knight.global_position + Vector2(120, 0),
		Units.to_px(knight.abilities.e.get("hit_width")) * 0.5).has(dummy)
	_check("(the dummy is inside Lunge's hit width: only the wall saves it)", in_width, true)
	knight.abilities.try_cast(&"e", knight.global_position + Vector2(120, 0))
	await _wait_until(func() -> bool: return not knight.abilities.casting, 60)
	_check("Lunge's path is clear", lunge_path_ok, true)
	_check("Lunge doesn't hit a dummy across a wall beside its path", dummy.health.current, hp)
	wall.rotation = 0.0

	# Judgement: a target in range but behind a wall.
	await _reset_knight()
	_place(wall, knight.global_position + Vector2(40, 0))
	wall.scale = Vector2(1, 3)   # 240 px tall: no quick way around
	_place(dummy, knight.global_position + Vector2(90, 0))
	await _frames(2)
	knight.abilities.try_cast(&"r", dummy.global_position, dummy)
	_check("Judgement behind a wall: no cast yet (walks to get a view)",
		[knight.abilities.casting, knight.abilities.has_pending()], [false, true])
	knight.abilities.cancel_pending()
	knight.movement.stop()
	knight.abilities.r.ignores_walls = true
	knight.abilities.try_cast(&"r", dummy.global_position, dummy)
	_check("with ignores_walls it casts at once", knight.abilities.casting, true)
	await _wait_until(func() -> bool: return not knight.abilities.casting, 120)
	knight.abilities.r.ignores_walls = false
	wall.scale = Vector2.ONE
	dummy.queue_free()
	await _hitstop_over()

	# An enemy basic attack across a wall.
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	knight.health.heal(10000.0)
	_place(wall, knight.global_position + Vector2(15, 0))
	var slime := _dummy_at(Vector2(33, 0))
	await _frames(2)
	hp = knight.health.current
	var whiffs: Array = []
	slime.attack.attack_whiffed.connect(func(t: Unit) -> void: whiffs.append(t))
	slime.attack.attack(knight)
	await _wait_until(func() -> bool: return whiffs.size() > 0 or knight.health.current < hp, 60)
	_check("a slime can't hit through a wall (whiff)", [knight.health.current, whiffs.size()], [hp, 1])
	slime.attack.cancel()
	slime.queue_free()

	# The elite slam: the Knight inside the circle but across a wall from its center.
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	var elite := _spawn_elite(knight.global_position + Vector2(90, 0), true)
	_place(wall, knight.global_position + Vector2(18, 0))
	await _frames(2)
	hp = knight.health.current
	elite.abilities.try_cast(&"q", knight.global_position + Vector2(32, 0), knight)   # center 32 px away
	await _wait_until(func() -> bool: return not elite.abilities.casting, 60)
	await _frames(2)
	_check("the slam doesn't hit through a wall", knight.health.current, hp)
	elite.queue_free()
	wall.queue_free()
	await _frames(2)


# --- STATS step 6: items change ability numbers ---------------------------------

func _test_item_changes_abilities() -> void:
	_section("STATS 6: a fake item changes the Knight's abilities")
	await _reset_knight()
	await _hitstop_over()
	await _wait_until(func() -> bool: return knight.abilities.is_ready(&"q") and knight.abilities.is_ready(&"e"), 600)
	var item: Array[StatModifier] = [
		StatModifier.create(&"cooldown", FLAT, -1.5, &"item_test", &"ability:knight_cleave"),
		StatModifier.create(&"base_damage", StatModifier.Type.PERCENT_MULT, 0.5, &"item_test", &"tag:area"),
		StatModifier.create(&"cast_range", PERCENT_ADD, 0.30, &"item_test", &"ability:knight_lunge"),
	]
	knight.stats_component.add_modifiers(item)
	var dummy := _dummy_at(Vector2(40, 0))
	await _frames(1)
	var hits: Array[HitContext] = []
	var record := func(ctx: HitContext) -> void: hits.append(ctx)
	Events.unit_hit.connect(record)
	var hp := dummy.health.current
	knight.abilities.try_cast(&"q", knight.global_position + Vector2(100, 0))
	_check("Cleave's cooldown: 3 -> 1.5 s", knight.abilities.get_cooldown_duration(knight.abilities.q), 1.5)
	await _wait_until(func() -> bool: return not knight.abilities.casting, 40)
	_check("Cleave deals 80 x 1.5 + 0.7 x 64 = 164.8", hp - dummy.health.current, 164.8)
	# Since C8 Cleave hits through HitPipeline.from_ability(), which adds the tags.
	_check("Cleave's real hit carries the ability's tags (area + ability) and the modded base damage",
		hits.map(func(h: HitContext) -> Array: return [h.has_tag(&"area"), h.has_tag(&"ability"), h.base_damage]), [[true, true, 120.0]])
	Events.unit_hit.disconnect(record)
	dummy.queue_free()
	await _hitstop_over()

	await _reset_knight()
	var from := knight.global_position
	knight.abilities.try_cast(&"e", from + Vector2(400, 0))
	await _wait_until(func() -> bool: return not knight.abilities.casting, 60)
	_check_near("Lunge reaches 520 u = 166.4 px (was 400 u = 128 px)", knight.global_position.x - from.x, 166.4, 0.5)

	knight.stats_component.remove_modifiers_from(&"item_test")
	_check("item removed: cooldown and range back",
		[knight.abilities.get_cooldown_duration(knight.abilities.q), knight.abilities.e.get_param(knight, &"cast_range")], [3.0, 400.0])
	_check("Cleave damage back to 124.8", knight.abilities.q.get_damage(knight), 124.8)
	await _frames(30)


# --- C8: crits and on-hit -----------------------------------------------------------

func _test_crits_and_on_hit() -> void:
	await _test_c8_abilities_unchanged()
	await _test_c8_crits()
	await _test_c8_damage_increase()
	_test_c8_incoming_damage()
	await _test_c8_on_hit()


func _test_c8_abilities_unchanged() -> void:
	_section("C8: the Knight's abilities through from_ability(): same numbers")
	await _reset_knight()
	await _hitstop_over()
	var dummy := _tough_dummy_at(Vector2(40, 0))
	await _frames(1)
	var hits := await _record_hits(func() -> void: await _cast(&"q", knight.global_position + Vector2(100, 0)))
	_check("Cleave: one hit, 124.8, no crit", hits.map(func(h: HitContext) -> Array: return [h.taken_damage, h.is_crit]), [[124.8, false]])
	if hits.size() == 1:
		_check("Cleave's hit: tags ability + area + physical, its ability and proc coefficient",
			[hits[0].has_tag(&"ability"), hits[0].has_tag(&"area"), hits[0].has_tag(&"physical"), hits[0].ability == knight.abilities.q, hits[0].proc_coefficient],
			[true, true, true, true, 1.0])
	await _hitstop_over()

	await _reset_knight()
	_place(dummy, knight.global_position + Vector2(60, 0))
	await _frames(2)
	hits = await _record_hits(func() -> void: await _cast(&"e", knight.global_position + Vector2(120, 0)))
	_check("Lunge: one hit, 82 (50 + 0.5 x 64), tagged movement",
		hits.map(func(h: HitContext) -> Array: return [h.taken_damage, h.has_tag(&"movement")]), [[82.0, true]])
	await _hitstop_over()

	await _reset_knight()
	dummy.health.heal(100000.0)
	_place(dummy, knight.global_position + Vector2(60, 0))
	await _frames(2)
	hits = await _record_hits(func() -> void: await _cast(&"r", dummy.global_position, dummy))
	_check("Judgement at full health: 214 (150 + 1.0 x 64), tagged ultimate, stuns",
		[hits.map(func(h: HitContext) -> Array: return [h.taken_damage, h.has_tag(&"ultimate")]), dummy.is_stunned()], [[[214.0, true]], true])
	dummy.health.take_damage(1000.0 - (dummy.health.max_health - dummy.health.current))   # 1000 missing
	hits = await _record_hits(func() -> void: await _cast(&"r", dummy.global_position, dummy))
	_check("Judgement with 1000 missing health: 214 + 20% x 1000 = 414 (= get_damage_against() before the hit)",
		hits.map(func(h: HitContext) -> float: return h.taken_damage), [414.0])
	dummy.add_invulnerability(&"test")
	dummy.status_component.remove_status(&"stun")
	await _cast(&"r", dummy.global_position, dummy)
	_check("a blocked Judgement doesn't stun", dummy.is_stunned(), false)
	dummy.queue_free()
	await _hitstop_over()


func _test_c8_crits() -> void:
	_section("C8: crits (crit_damage 1.75)")
	await _reset_knight()
	await _hitstop_over()
	var dummy := _tough_dummy_at(Vector2(50, 0))
	await _frames(1)
	knight.stats_component.add_modifier(StatModifier.create(&"crit_chance", FLAT, 1.0, &"test_c8"))
	var before := _numbers()
	var hits := await _record_hits(func() -> void: await _swing_once())
	_check("100% crit: swing 1 deals 64 x 1.75 = 112, tagged crit",
		hits.map(func(h: HitContext) -> Array: return [h.taken_damage, h.is_crit, h.has_tag(&"crit")]), [[112.0, true, true]])
	var added := _numbers().filter(func(n: Label) -> bool: return not before.has(n))
	_check("its number is the crit style: \"112!\"", added.map(func(n: Label) -> Array: return [n.text, n.kind]), [["112!", NUMBER_SCRIPT.Kind.CRIT]])
	await _reset_knight()
	_place(dummy, knight.global_position + Vector2(40, 0))
	await _frames(2)
	hits = await _record_hits(func() -> void: await _cast(&"q", knight.global_position + Vector2(100, 0)))
	_check("Cleave crits too: 124.8 x 1.75 = 218.4", hits.map(func(h: HitContext) -> Array: return [h.taken_damage, h.is_crit]), [[218.4, true]])
	await _hitstop_over()
	var wrapped := await _record_hits(func() -> void: dummy.take_damage(50.0, knight))
	_check("take_damage() never crits", wrapped.map(func(h: HitContext) -> Array: return [h.taken_damage, h.is_crit]), [[50.0, false]])
	var proc := HitPipeline.resolve(HitPipeline.make_proc(knight, dummy, 20.0))
	_check("a proc never crits", [proc.taken_damage, proc.is_crit], [20.0, false])
	knight.stats_component.add_modifier(StatModifier.create(&"crit_damage", FLAT, 0.5, &"test_c8"))
	var big := HitPipeline.resolve(HitPipeline.basic_attack(knight, dummy, knight.attack.combo.swings[0]))
	_check("+0.5 crit_damage: 64 x 2.25 = 144", big.taken_damage, 144.0)
	knight.stats_component.remove_modifiers_from(&"test_c8")

	var nothing := Node2D.new()   # no on_hit(): only the attacker's stages run
	add_child(nothing)
	_check("0% crit (the default): 0 crits in 200 rolls", _count_crits(nothing, 200), 0)
	knight.stats_component.add_modifier(StatModifier.create(&"crit_chance", FLAT, 0.25, &"test_c8"))
	HitPipeline.crit_rng.seed = 8
	var crits := _count_crits(nothing, 400)
	_report(crits >= 70 and crits <= 130, "25%% crit: about 100 crits in 400 rolls (%d)" % crits, "got %d" % crits)
	knight.stats_component.remove_modifiers_from(&"test_c8")

	_section("C8: PRD crits (one roll per swing)")
	_check_near("the PRD constant for 25% is 0.0847 (as in Dota)", HitPipeline.get_prd_constant(0.25), 0.0847, 0.0001)
	_check_near("and for 50% 0.3021", HitPipeline.get_prd_constant(0.5), 0.3021, 0.0001)
	knight.stats_component.add_modifier(StatModifier.create(&"crit_chance", FLAT, 0.25, &"test_c8"))
	knight.crit_misses = 0
	HitPipeline.crit_rng.seed = 21
	var rolls := _roll_stats(nothing, 4000)
	_check_near("4000 rolls at 25%: 25% crits", rolls.rate, 0.25, 0.02)
	_check_near("a crit right after a crit: ~8.5% (plain dice: 25%)", rolls.after_crit, 0.085, 0.03)
	_report(rolls.longest_dry <= 11, "never more than 11 misses in a row (%d)" % rolls.longest_dry, "got %d" % rolls.longest_dry)
	knight.crit_misses = 0
	var first := HitPipeline.roll_prd(knight, 0.25)
	_check("a miss moves the counter up by 1, a crit resets it", knight.crit_misses, 0 if first else 1)
	knight.stats_component.remove_modifiers_from(&"test_c8")

	knight.stats_component.add_modifier(StatModifier.create(&"crit_chance", FLAT, 0.5, &"test_c8"))
	var second := _tough_dummy_at(Vector2(50, 0))
	_place(dummy, knight.global_position + Vector2(50, 0))
	_place(second, knight.global_position + Vector2(50, 20))
	await _frames(2)
	var shared_ok := true
	var counter_ok := true
	var swings_hit_both := true
	for i in 4:
		var misses := knight.crit_misses
		var swing_hits := await _record_hits(func() -> void: await _swing_once())
		swings_hit_both = swings_hit_both and swing_hits.size() == 2
		if swing_hits.size() == 2:
			shared_ok = shared_ok and swing_hits[0].is_crit == swing_hits[1].is_crit
			counter_ok = counter_ok and knight.crit_misses == (0 if swing_hits[0].is_crit else misses + 1)
		_place(dummy, knight.global_position + Vector2(50, 0))
		_place(second, knight.global_position + Vector2(50, 20))
	_check("(4 real swings each hit both dummies)", swings_hit_both, true)
	_check("a swing crits both dummies or neither", shared_ok, true)
	_check("and moves the counter once per swing, not per dummy", counter_ok, true)
	shared_ok = true
	counter_ok = true
	for i in 6:
		var misses := knight.crit_misses
		var cast_hits := await _record_hits(func() -> void: await _cast(&"q", knight.global_position + Vector2(100, 10)))
		if cast_hits.size() == 2:
			shared_ok = shared_ok and cast_hits[0].is_crit == cast_hits[1].is_crit
			counter_ok = counter_ok and knight.crit_misses == (0 if cast_hits[0].is_crit else misses + 1)
		else:
			shared_ok = false
		_place(dummy, knight.global_position + Vector2(50, 0))
		_place(second, knight.global_position + Vector2(50, 20))
		await _hitstop_over()
	_check("Cleave on 2 dummies (6 casts): one shared roll per cast", [shared_ok, counter_ok], [true, true])
	knight.stats_component.remove_modifiers_from(&"test_c8")
	knight.stats_component.add_modifier(StatModifier.create(&"crit_chance", FLAT, 0.1, &"test_c8"))
	knight.crit_misses = 0
	var a := HitPipeline.resolve(HitPipeline.basic_attack(knight, nothing, knight.attack.combo.swings[0])).is_crit
	var b := HitPipeline.resolve(HitPipeline.basic_attack(knight, nothing, knight.attack.combo.swings[0])).is_crit
	_check("hits without a shared roll each roll: the counter moves per hit", knight.crit_misses, 0 if b else (1 if a else 2))
	knight.stats_component.remove_modifiers_from(&"test_c8")
	second.queue_free()

	knight.stats_component.add_modifier(StatModifier.create(&"crit_chance", FLAT, 1.0, &"test_c8", &"hit:basic_attack"))
	var swing := HitPipeline.resolve(HitPipeline.basic_attack(knight, dummy, knight.attack.combo.swings[0]))
	var cleave := HitPipeline.resolve(HitPipeline.from_ability(knight, knight.abilities.q, dummy))
	_check("crit_chance scoped to hit:basic_attack: swings crit, Cleave doesn't", [swing.is_crit, cleave.is_crit], [true, false])
	knight.stats_component.remove_modifiers_from(&"test_c8")
	nothing.queue_free()
	dummy.queue_free()
	await _hitstop_over()


func _test_c8_damage_increase() -> void:
	_section("C8: damage_increase (hit: and target: scopes)")
	await _reset_knight()
	await _hitstop_over()
	var dummy := _tough_dummy_at(Vector2(50, 0))
	var stunned := _tough_dummy_at(Vector2(50, 0))
	_place(stunned, knight.global_position + Vector2(0, 300))
	stunned.apply_stun(30.0)
	await _frames(1)
	var stats := knight.stats_component
	var swing := knight.attack.combo.swings[0]
	stats.add_modifier(StatModifier.create(&"damage_increase", FLAT, 0.2, &"test_c8", &"hit:basic_attack"))
	var hits := await _record_hits(func() -> void: await _swing_once())
	_check("+20% on basic attacks: a real swing deals 64 x 1.2 = 76.8", hits.map(func(h: HitContext) -> float: return h.taken_damage), [76.8])
	_check("Cleave isn't a basic attack: 124.8", _resolve_cleave(dummy).taken_damage, 124.8)
	stats.add_modifier(StatModifier.create(&"crit_chance", FLAT, 1.0, &"test_c8_crit"))
	_check("increase before crit: 64 x 1.2 x 1.75 = 134.4", HitPipeline.resolve(HitPipeline.basic_attack(knight, dummy, swing)).taken_damage, 134.4)
	stats.remove_modifiers_from(&"test_c8_crit")
	stats.remove_modifiers_from(&"test_c8")
	stats.add_modifier(StatModifier.create(&"damage_increase", FLAT, 0.5, &"test_c8", &"target:stun"))
	_check("+50% vs stunned: Cleave on a stunned dummy 187.2, on the other 124.8",
		[_resolve_cleave(stunned).taken_damage, _resolve_cleave(dummy).taken_damage], [187.2, 124.8])
	stats.add_modifier(StatModifier.create(&"damage_increase", FLAT, 0.1, &"test_c8_all"))
	_check("plus an unscoped +10%: 124.8 x 1.6 = 199.68 and 124.8 x 1.1 = 137.28",
		[_resolve_cleave(stunned).taken_damage, _resolve_cleave(dummy).taken_damage], [199.68, 137.28])
	stats.remove_modifiers_from(&"test_c8")
	stats.remove_modifiers_from(&"test_c8_all")
	_check("removed: back to 124.8", _resolve_cleave(stunned).taken_damage, 124.8)
	var tagged := HitPipeline.resolve(HitPipeline.from_ability(knight, knight.abilities.q, stunned))
	_check("the stunned dummy's status tags: cc + stun (+ debuff since C9)", stunned.get_status_tags(), [&"cc", &"stun", &"debuff"] as Array[StringName])
	_check("(the hit read them: raw 124.8)", tagged.raw_damage, 124.8)
	dummy.queue_free()
	stunned.queue_free()
	await _hitstop_over()


func _test_c8_incoming_damage() -> void:
	_section("C8: incoming_damage (after mitigation)")
	var dummy := _spawn_dummy()
	dummy.stats_component.add_modifier(StatModifier.create(&"incoming_damage", StatModifier.Type.PERCENT_MULT, -0.2, &"test_a"))
	dummy.stats_component.add_modifier(StatModifier.create(&"incoming_damage", StatModifier.Type.PERCENT_MULT, -0.2, &"test_b"))
	var physical := _hit(dummy, 80.0, HitContext.DamageType.PHYSICAL)
	_check("two 20% reductions: 80 -> 80 x 0.64 = 51.2 taken", physical.taken_damage, 51.2)
	_check("raw damage stays 80 (before mitigation)", physical.raw_damage, 80.0)
	var true_hit := _hit(dummy, 80.0, HitContext.DamageType.TRUE)
	_check("TRUE damage too: 51.2", true_hit.taken_damage, 51.2)
	dummy.stats_component.add_modifier(StatModifier.create(&"armor", FLAT, 100.0, &"test_a"))
	_check("100 armor, then x0.64: 80 x 0.5 x 0.64 = 25.6", _hit(dummy, 80.0, HitContext.DamageType.PHYSICAL).taken_damage, 25.6)
	dummy.stats_component.remove_modifiers_from(&"test_a")
	dummy.stats_component.remove_modifiers_from(&"test_b")
	_check("removed: 80 taken", _hit(dummy, 80.0, HitContext.DamageType.PHYSICAL).taken_damage, 80.0)
	var wrapped_hp := dummy.health.current
	dummy.stats_component.add_modifier(StatModifier.create(&"incoming_damage", StatModifier.Type.PERCENT_MULT, -0.5, &"test_a"))
	dummy.take_damage(40.0, knight)
	_check("take_damage() goes through it too: 40 -> 20", wrapped_hp - dummy.health.current, 20.0)
	dummy.queue_free()


func _test_c8_on_hit() -> void:
	_section("C8: on-hit (on_hit_damage, life_on_hit, life_steal, resource_on_hit)")
	await _reset_knight()
	await _hitstop_over()
	var stats := knight.stats_component
	var dummy := _tough_dummy_at(Vector2(50, 0))
	await _frames(1)
	stats.add_modifier(StatModifier.create(&"on_hit_damage", FLAT, 20.0, &"test_c8"))
	var hits := await _record_hits(func() -> void: await _swing_once())
	_check("20 on-hit damage: a swing = the 64 swing + one 20 MAGIC proc hit",
		hits.map(func(h: HitContext) -> Array: return [h.taken_damage, h.has_tag(&"basic_attack"), h.has_tag(&"proc"), h.damage_type]),
		[[64.0, true, false, HitContext.DamageType.PHYSICAL], [20.0, false, true, HitContext.DamageType.MAGIC]])
	_check("the proc: same target, no crit, proc coefficient 0 (it triggers nothing)",
		hits.map(func(h: HitContext) -> bool: return h.target == dummy) + [hits[-1].is_crit if not hits.is_empty() else true], [true, true, false])
	knight.abilities.q.proc_coefficient = 0.5
	hits = await _record_hits(func() -> void: _resolve_cleave(dummy))
	_check("Cleave at proc coefficient 0.5: a 10 proc", hits.map(func(h: HitContext) -> float: return h.taken_damage), [124.8, 10.0])
	knight.abilities.q.proc_coefficient = 1.0
	var tick := dummy.make_hit_context(10.0, knight)
	tick.add_tag(&"dot")
	tick.add_tag(&"ability")
	hits = await _record_hits(func() -> void: dummy.on_hit(tick))
	_check("a DoT tick triggers no on-hit", hits.size(), 1)
	hits = await _record_hits(func() -> void: dummy.take_damage(30.0, knight))
	_check("nor does take_damage() (no basic_attack / ability tag)", hits.size(), 1)
	dummy.add_invulnerability(&"test")
	hits = await _record_hits(func() -> void: HitPipeline.resolve(HitPipeline.basic_attack(knight, dummy, knight.attack.combo.swings[0])))
	_check("a blocked hit: no proc, no events", hits.size(), 0)
	dummy.remove_invulnerability(&"test")
	stats.remove_modifiers_from(&"test_c8")

	var second := _tough_dummy_at(Vector2(50, 0))
	_place(second, knight.global_position + Vector2(50, 20))
	await _frames(1)
	knight.health.take_damage(300.0)   # 350 / 650, straight to health (no i-frames)
	stats.add_modifier(StatModifier.create(&"life_on_hit", FLAT, 10.0, &"test_c8"))
	var hp := knight.health.current
	var before := _numbers()
	var swung := await _record_hits(func() -> void: await _swing_once())
	_check("(the swing hit both dummies)", swung.size(), 2)
	_check("10 life on hit x 2 dummies: +20 health", knight.health.current - hp, 20.0)
	var greens := _numbers().filter(func(n: Label) -> bool: return not before.has(n) and n.kind == NUMBER_SCRIPT.Kind.HEAL)
	_check("two green \"+10\" numbers on the Knight", greens.map(func(n: Label) -> String: return n.text), ["+10", "+10"])
	stats.remove_modifiers_from(&"test_c8")
	second.queue_free()

	stats.add_modifier(StatModifier.create(&"life_steal", FLAT, 0.5, &"test_c8"))
	hp = knight.health.current
	await _swing_once()
	_check("50% life steal on a 64 swing: +32", knight.health.current - hp, 32.0)
	hp = knight.health.current
	_resolve_cleave(dummy)
	_check("life steal is basic attacks only: Cleave heals 0", knight.health.current - hp, 0.0)
	stats.remove_modifiers_from(&"test_c8")

	knight.resource_pool.try_spend(100.0)
	var mana := knight.resource_pool.current
	stats.add_modifier(StatModifier.create(&"resource_on_hit", FLAT, 5.0, &"test_c8"))
	_resolve_cleave(dummy)
	_check("5 resource on hit: +5 mana", knight.resource_pool.current - mana, 5.0)
	stats.remove_modifiers_from(&"test_c8")
	knight.health.heal(10000.0)
	knight.resource_pool.restore(1000.0)

	# The player hit by an enemy with on-hit damage: the proc isn't blocked by
	# the i-frames its own hit starts, and it starts none of its own.
	await _wait_until(func() -> bool: return not knight.is_invulnerable(), 60)
	var slime := _dummy_at(Vector2(0, 200))
	slime.stats_component.add_modifier(StatModifier.create(&"on_hit_damage", FLAT, 10.0, &"test_c8"))
	var enemy_hit := knight.make_hit_context(22.0, slime)
	enemy_hit.add_tag(&"basic_attack")
	hp = knight.health.current
	knight.on_hit(enemy_hit)
	_check("a slime with 10 on-hit: the Knight loses 22 + 10, then has i-frames",
		[hp - knight.health.current, knight.has_invulnerability(Unit.HIT_IFRAMES_ID)], [32.0, true])
	slime.queue_free()
	dummy.queue_free()
	await _wait_until(func() -> bool: return not knight.is_invulnerable(), 60)
	await _hitstop_over()


# --- C9: status effects -------------------------------------------------------------

const STATUS_STUN: StatusEffect = preload("res://data/statuses/status_stun.tres")
const STATUS_SLOW: StatusEffect = preload("res://data/statuses/status_slow.tres")
const STATUS_HASTE: StatusEffect = preload("res://data/statuses/status_haste.tres")
const STARS_SCRIPT := preload("res://scripts/vfx/stun_stars.gd")


func _test_statuses() -> void:
	_test_c9_data()
	await _test_c9_stun()
	_test_c9_tenacity()
	await _test_c9_speed_wrapper()
	await _test_c9_stack_rules()
	await _test_c9_dot()
	await _test_c9_hit_statuses_and_events()


func _test_c9_data() -> void:
	_section("C9: status data")
	_check("status_stun: tags cc + stun + debuff, keeps the longer time, blocks move / attack / cast / dash, has VFX",
		[STATUS_STUN.id, STATUS_STUN.tags, STATUS_STUN.stack_rule, STATUS_STUN.blocks_move, STATUS_STUN.blocks_attack, STATUS_STUN.blocks_cast, STATUS_STUN.blocks_dash, STATUS_STUN.vfx != null],
		[&"stun", [&"cc", &"stun", &"debuff"], StatusEffect.StackRule.REFRESH_LONGER, true, true, true, true, true])
	_check("status_slow: cc + slow + debuff, 30% move_speed slow, refreshes",
		[STATUS_SLOW.tags, STATUS_SLOW.modifiers[0].stat, STATUS_SLOW.modifiers[0].value, STATUS_SLOW.stack_rule],
		[[&"cc", &"slow", &"debuff"], &"move_speed", -0.3, StatusEffect.StackRule.REFRESH])
	_check("status_haste: haste + buff, +20% move_speed", [STATUS_HASTE.tags, STATUS_HASTE.modifiers[0].value], [[&"haste", &"buff"], 0.2])
	_check("the Knight and slimes have a StatusComponent", [knight.status_component != null, _spawn_dummy().status_component != null], [true, true])


func _test_c9_stun() -> void:
	_section("C9: the stun is a status (apply_stun() wrapper)")
	await _reset_knight()
	await _hitstop_over()
	var sc := knight.status_component
	var removed_at := [-1.0]
	var on_removed := func(unit: Unit, status: StatusEffect) -> void:
		if unit == knight and status.id == &"stun":
			removed_at[0] = _game_time
	Events.status_removed.connect(on_removed)
	var start := _game_time
	knight.apply_stun(0.5)
	await _frames(1)
	_check("stunned: status 'stun', can't move, swing, cast or dash",
		[sc.has_status(&"stun"), knight.is_stunned(), knight.movement.can_move(), knight.attack.try_swing(Vector2.RIGHT), knight.abilities.can_cast(&"q"), knight.dash.can_dash()],
		[true, true, false, false, false, false])
	_check("the stars VFX is on the Knight", knight.get_children().any(func(n: Node) -> bool: return n.get_script() == STARS_SCRIPT), true)
	knight.apply_stun(0.2)
	_check_near("a shorter re-stun keeps the longer time (~0.48 s left)", sc.get_time_left(&"stun"), 0.483, 0.01)
	knight.apply_stun(1.0)
	_check_near("a longer one extends it to 1.0 s", sc.get_time_left(&"stun"), 1.0, 0.001)
	await _wait_until(func() -> bool: return not knight.is_stunned(), 120)
	_check_near("it ends 1.0 s of game time after the re-stun (1.017 s after the first)", removed_at[0] - start, 1.0 + 1.0 / 60.0, 0.02)
	await _frames(1)
	_check("after: can move and dash, stars gone",
		[knight.movement.can_move(), knight.dash.can_dash(), knight.get_children().any(func(n: Node) -> bool: return n.get_script() == STARS_SCRIPT and not n.is_queued_for_deletion())],
		[true, true, false])
	Events.status_removed.disconnect(on_removed)
	var dummy := _tough_dummy_at(Vector2(60, 0))
	await _frames(1)
	await _cast(&"r", dummy.global_position, dummy)
	_check("Judgement's stun: 0.75 s, the Knight as its source",
		[dummy.status_component.get_source(&"stun") == knight, snappedf(dummy.status_component.get_time_left(&"stun"), 0.01)], [true, 0.75])
	dummy.queue_free()
	await _hitstop_over()


func _test_c9_tenacity() -> void:
	_section("C9: tenacity shortens crowd control only")
	var dummy := _spawn_dummy()
	dummy.stats_component.add_modifier(StatModifier.create(&"tenacity", FLAT, 0.5, &"test_c9"))
	dummy.apply_stun(1.0)
	dummy.movement.add_speed_modifier(&"test_slow", 0.0, -0.4, 2.0)
	dummy.movement.add_speed_modifier(&"test_haste", 0.0, 0.2, 2.0)
	var burn := _make_status(&"test_burn", [&"dot", &"burning"], 2.0)
	burn.tick_interval = 0.5
	burn.tick_damage = 1.0
	dummy.status_component.apply_status(burn, knight)
	var sc := dummy.status_component
	_check("50% tenacity: stun 1.0 -> 0.5 s, slow 2.0 -> 1.0 s, haste and burn stay 2.0 s",
		[sc.get_time_left(&"stun"), sc.get_time_left(&"test_slow"), sc.get_time_left(&"test_haste"), sc.get_time_left(&"test_burn")], [0.5, 1.0, 2.0, 2.0])
	dummy.queue_free()


func _test_c9_speed_wrapper() -> void:
	_section("C9: add_speed_modifier() makes statuses (Iron Resolve)")
	await _reset_knight()
	await _wait_until(func() -> bool: return knight.abilities.is_ready(&"w"), 900)
	var sc := knight.status_component
	var base_speed := knight.movement.get_move_speed()
	knight.request_cast(&"w")
	await _frames(2)
	_check("Iron Resolve: a haste status 'iron_resolve' (haste + buff), 2 s",
		[sc.has_status(&"iron_resolve"), sc.get_status(&"iron_resolve").tags, snappedf(sc.get_time_left(&"iron_resolve"), 0.1)], [true, [&"haste", &"buff"], 2.0])
	_check("same speed as before C9: 560 -> 739.6", [base_speed, knight.movement.get_move_speed()], [560.0, 739.6])
	_check("its modifier's source is status_iron_resolve", knight.stats_component.get_modifiers_from(&"status_iron_resolve").size(), 1)
	await _wait_until(func() -> bool: return not sc.has_status(&"iron_resolve"), 150)
	_check("gone after 2 s, speed back to 560", [sc.has_status(&"iron_resolve"), knight.movement.get_move_speed()], [false, 560.0])
	knight.attack.cancel_swing()
	knight.attack.add_next_attack_modifier(&"iron_resolve", 0.0)   # clear its empowered swing
	knight.attack.cancel()

	var dummy := _spawn_dummy()
	var normal := dummy.movement.get_move_speed()
	dummy.movement.add_speed_modifier(&"test_slow", 0.0, -0.4, 1.0)
	var dsc := dummy.status_component
	var slowed := dummy.movement.get_move_speed()
	_check("a slow: status 'test_slow' tagged cc + slow, slower", [dsc.has_status(&"test_slow"), dsc.has_tag(&"slow"), dsc.has_tag(&"cc"), slowed < normal], [true, true, true, true])
	dummy.movement.add_speed_modifier(&"test_slow", 0.0, -0.2, 1.0)
	_check("the same id replaces it (-40% -> -20%)",
		[dsc.get_stacks(&"test_slow"), dummy.stats_component.get_modifiers_from(&"status_test_slow")[0].value, dummy.movement.get_move_speed() > slowed], [1, -0.2, true])
	dummy.movement.remove_speed_modifier(&"test_slow")
	_check("remove_speed_modifier() removes the status", [dsc.has_status(&"test_slow"), dummy.movement.get_move_speed()], [false, normal])
	dummy.movement.add_speed_modifier(&"test_forever", 20.0)
	await _frames(30)
	_check("no duration = until removed", [dsc.get_time_left(&"test_forever"), dsc.has_tag(&"haste")], [-1.0, true])
	dummy.movement.remove_speed_modifier(&"test_forever")
	_check("removed", dsc.has_status(&"test_forever"), false)
	dummy.queue_free()


func _test_c9_stack_rules() -> void:
	_section("C9: stack rules")
	var dummy := _spawn_dummy()
	var sc := dummy.status_component
	var stacking := _make_status(&"test_stack", [&"buff"], 1.0)
	stacking.stack_rule = StatusEffect.StackRule.STACK
	stacking.max_stacks = 3
	stacking.modifiers = [StatModifier.create(&"armor", FLAT, 10.0, &"")] as Array[StatModifier]
	sc.apply_status(stacking)
	sc.apply_status(stacking)
	sc.apply_status(stacking, null, 0.3)
	_check("STACK: 3 stacks (1.0, 1.0 and 0.3 s), +10 armor each", [sc.get_stacks(&"test_stack"), dummy.stats_component.get_stat(&"armor")], [3, 30.0])
	await _frames(25)
	_check("stacks run out one by one: after 0.42 s 2 left, +20 armor", [sc.get_stacks(&"test_stack"), dummy.stats_component.get_stat(&"armor")], [2, 20.0])
	sc.apply_status(stacking)
	sc.apply_status(stacking, null, 2.0)
	_check("at max 3, a 4th application restarts the stack closest to running out (0.58 s -> 2.0 s)",
		[sc.get_stacks(&"test_stack"), sc.get_time_left(&"test_stack"), dummy.stats_component.get_stat(&"armor")], [3, 2.0, 30.0])
	sc.remove_status(&"test_stack")
	_check("removed: armor back to 0", dummy.stats_component.get_stat(&"armor"), 0.0)

	var ignore := _make_status(&"test_ignore", [&"buff"], 1.0)
	ignore.stack_rule = StatusEffect.StackRule.IGNORE
	_check("IGNORE: the second application does nothing", [sc.apply_status(ignore), sc.apply_status(ignore, null, 5.0), sc.get_time_left(&"test_ignore")], [true, false, 1.0])
	var refresh := _make_status(&"test_refresh", [&"debuff"], 1.0)
	refresh.stack_rule = StatusEffect.StackRule.REFRESH
	sc.apply_status(refresh, knight)
	var other := _spawn_dummy()
	sc.apply_status(refresh, other, 0.3)
	_check("REFRESH: the new source and duration replace it (even a shorter one)",
		[sc.get_source(&"test_refresh") == other, sc.get_time_left(&"test_refresh")], [true, 0.3])
	_check("a status without an id isn't applied (one expected push_error)", [sc.apply_status(null)], [false])
	other.queue_free()
	dummy.queue_free()


func _test_c9_dot() -> void:
	_section("C9: damage over time")
	await _hitstop_over()
	var dummy := _tough_dummy_at(Vector2(0, 250))
	await _frames(1)
	var burn := _make_status(&"test_burn", [&"dot", &"burning", &"debuff"], 2.0)
	burn.tick_interval = 0.5
	burn.tick_damage = 10.0
	burn.tick_ad_ratio = 0.5
	knight.stats_component.add_modifier(StatModifier.create(&"crit_chance", FLAT, 1.0, &"test_c9"))
	var start := _game_time
	var hits: Array[HitContext] = []
	var times: Array[float] = []
	var record := func(ctx: HitContext) -> void:
		if ctx.target == dummy:
			hits.append(ctx)
			times.append(_game_time - start)
	Events.unit_hit.connect(record)
	dummy.status_component.apply_status(burn, knight)
	knight.stats_component.add_modifier(StatModifier.create(&"attack_damage", FLAT, 100.0, &"test_c9"))
	await _wait_until(func() -> bool: return not dummy.status_component.has_status(&"test_burn"), 160)
	Events.unit_hit.disconnect(record)
	_check("2 s at 0.5 s: 4 ticks of 10 + 0.5 x 64 = 42 (AD snapshotted when applied, not the +100 after)",
		hits.map(func(h: HitContext) -> float: return h.taken_damage), [42.0, 42.0, 42.0, 42.0])
	if times.size() == 4:
		_check_near("the first tick 0.5 s after it's applied", times[0], 0.5 + 1.0 / 60.0, 0.02)
	_check("ticks: dot + burning tags, MAGIC, the Knight as source, no crit even at 100%",
		hits.all(func(h: HitContext) -> bool: return h.has_tag(&"dot") and h.has_tag(&"burning") and h.damage_type == HitContext.DamageType.MAGIC and h.source == knight and not h.is_crit),
		true)
	knight.stats_component.remove_modifiers_from(&"test_c9")

	knight.stats_component.add_modifier(StatModifier.create(&"damage_increase", FLAT, 0.5, &"test_c9", &"target:burning"))
	dummy.status_component.apply_status(burn, knight)
	_check("+50% vs burning (target:burning) now works: Cleave 187.2 on a burning dummy", _resolve_cleave(dummy).taken_damage, 187.2)
	dummy.status_component.remove_status(&"test_burn")
	_check("and 124.8 once it's gone", _resolve_cleave(dummy).taken_damage, 124.8)
	knight.stats_component.remove_modifiers_from(&"test_c9")

	var stacking := burn.duplicate() as StatusEffect
	stacking.id = &"test_burn_stacks"
	stacking.stack_rule = StatusEffect.StackRule.STACK
	stacking.max_stacks = 3
	hits.clear()
	start = _game_time
	Events.unit_hit.connect(record)
	for i in 3:
		dummy.status_component.apply_status(stacking, knight)
	await _frames(32)
	Events.unit_hit.disconnect(record)
	_check("3 stacks tick for 3 x 42 = 126", hits.map(func(h: HitContext) -> float: return h.taken_damage), [126.0])
	dummy.status_component.remove_status(&"test_burn_stacks")

	# Kill credit and a freed source.
	var victim := _spawn_dummy()
	var slime := _spawn_dummy()
	victim.health.take_damage(victim.health.current - 30.0)
	var deaths_before := _deaths.size()
	victim.status_component.apply_status(burn, knight)
	await _frames(35)
	var credited: bool = _deaths.size() > deaths_before and _deaths[-1][0] == victim and _deaths[-1][1].source == knight and _deaths[-1][1].has_tag(&"dot")
	_check("a DoT kill: unit_died with the applier as the source (kill credit)", credited, true)
	var dummy2 := _spawn_dummy()
	dummy2.status_component.apply_status(burn, slime)
	var hp := dummy2.health.current
	slime.free()
	await _frames(35)
	_check("the applier freed: it keeps ticking (10 + its snapshotted 11), from the environment",
		[hp - dummy2.health.current, dummy2.status_component.get_source(&"test_burn")], [21.0, null])
	dummy2.queue_free()

	await _wait_until(func() -> bool: return not knight.is_invulnerable(), 60)
	knight.status_component.apply_status(burn, _spawn_dummy())
	hp = knight.health.current
	await _frames(32)
	_check("a DoT tick on the Knight: damage (red number) but no post-hit i-frames",
		[knight.health.current < hp, knight.has_invulnerability(Unit.HIT_IFRAMES_ID)], [true, false])
	knight.status_component.remove_status(&"test_burn")
	knight.health.heal(10000.0)
	dummy.queue_free()


func _test_c9_hit_statuses_and_events() -> void:
	_section("C9: statuses on hits, events, death")
	var dummy := _spawn_dummy()
	var applied: Array = []
	var removed: Array = []
	var on_applied := func(unit: Unit, status: StatusEffect) -> void: applied.append([unit, status.id])
	var on_removed := func(unit: Unit, status: StatusEffect) -> void: removed.append([unit, status.id])
	Events.status_applied.connect(on_applied)
	Events.status_removed.connect(on_removed)
	var ctx := HitContext.new()
	ctx.source = knight
	ctx.target = dummy
	ctx.base_damage = 10.0
	ctx.statuses = [STATUS_SLOW] as Array[StatusEffect]
	HitPipeline.resolve(ctx)
	_check("a hit carrying status_slow slows the target, from the hit's source",
		[dummy.status_component.has_status(&"slow"), dummy.status_component.get_source(&"slow") == knight], [true, true])
	_check("Events.status_applied(unit, status)", applied, [[dummy, &"slow"]])
	var guarded := _spawn_dummy()
	guarded.add_invulnerability(&"test")
	var blocked := HitContext.new()
	blocked.source = knight
	blocked.target = guarded
	blocked.statuses = [STATUS_SLOW] as Array[StatusEffect]
	HitPipeline.resolve(blocked)
	_check("a blocked hit applies no status", guarded.status_component.has_status(&"slow"), false)
	dummy.apply_stun(5.0)
	dummy.take_damage(100000.0)
	_check("death removes every status (2 status_removed events)", [dummy.status_component.get_status_ids(), removed.map(func(e: Array) -> StringName: return e[1])], [[], [&"slow", &"stun"]])
	_check("nothing applies to a dead unit", dummy.status_component.apply_status(STATUS_SLOW), false)
	Events.status_applied.disconnect(on_applied)
	Events.status_removed.disconnect(on_removed)
	guarded.queue_free()
	await _frames(2)


func _make_status(id: StringName, tags: Array[StringName], duration: float) -> StatusEffect:
	var effect := StatusEffect.new()
	effect.id = id
	effect.tags = tags
	effect.duration = duration
	return effect


## A passive slime with +5000 max health, so big hits don't kill it.
func _tough_dummy_at(offset: Vector2) -> Enemy:
	var dummy := _dummy_at(offset)
	dummy.stats_component.add_modifier(StatModifier.create(&"max_health", FLAT, 5000.0, &"test_tough"))
	return dummy


## Runs a Knight ability's effect directly (no cooldown, cast time or range
## check): for its numbers.
func _cast(slot: StringName, aim: Vector2, target: Unit = null) -> void:
	var ctx := CastContext.new()
	ctx.slot = slot
	ctx.point = aim
	ctx.direction = (aim - knight.global_position).normalized()
	ctx.target = target
	await knight.abilities.get_ability(slot).execute(knight, ctx)


func _resolve_cleave(target: Unit) -> HitContext:
	return HitPipeline.resolve(HitPipeline.from_ability(knight, knight.abilities.q, target))


## Swing 1 to the right, played out to the end (combo reset first).
func _swing_once() -> void:
	await _reset_knight_in_place()
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 20)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 60)
	await _hitstop_over()


## Combo reset without moving the Knight (the dummies stay in reach).
func _reset_knight_in_place() -> void:
	knight.attack.cancel_swing()
	await _frames(40)


## Every Events.unit_hit during `action` (awaited).
func _record_hits(action: Callable) -> Array[HitContext]:
	var hits: Array[HitContext] = []
	var record := func(ctx: HitContext) -> void: hits.append(ctx)
	Events.unit_hit.connect(record)
	await action.call()
	Events.unit_hit.disconnect(record)
	return hits


## PRD roll stats over `n` Knight basic attack hits on a target without
## on_hit(): crit rate, crit rate right after a crit, longest run of misses.
func _roll_stats(target: Node, n: int) -> Dictionary:
	var crits := 0
	var after := 0
	var crit_after := 0
	var dry := 0
	var longest := 0
	var previous := false
	for i in n:
		var crit := HitPipeline.resolve(HitPipeline.basic_attack(knight, target, knight.attack.combo.swings[0])).is_crit
		crits += 1 if crit else 0
		dry = 0 if crit else dry + 1
		longest = maxi(longest, dry)
		if previous:
			after += 1
			crit_after += 1 if crit else 0
		previous = crit
	return {"rate": float(crits) / n, "after_crit": float(crit_after) / maxf(after, 1.0), "longest_dry": longest}


## Crits in `n` Knight basic attack hits on a target without on_hit().
func _count_crits(target: Node, n: int) -> int:
	var crits := 0
	for i in n:
		if HitPipeline.resolve(HitPipeline.basic_attack(knight, target, knight.attack.combo.swings[0])).is_crit:
			crits += 1
	return crits


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


func _physics_process(delta: float) -> void:
	_frame += 1
	_game_time += delta


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
