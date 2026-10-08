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
## the `damaged` signal the 3D model's flash reads; abilities and enemy hits
## unchanged). The shake spy is a Camera3D (the 2D camera went in the 3D
## pivot's cleanup C3; the flash and blink themselves are view_test's).
## C4: getting hit (post-hit i-frames and the blink's period, a slime's 12 px push
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
## C10: shields (absorb after armor, the soonest-expiring first, used up =
## removed, stacks, numbers, knockback / life steal / i-frames still apply).
## C11: reaction rules (world and unit rules, the three triggers, owner roles
## and effect targets, tags, chance, chain limits capped at 5, the four
## GameplayEffects, the Shatter rule).
## C12: the dash-strike (its data, the 0.15 s window through PlayerInput,
## damage and tags, heavy feel, its step, the combo kept across it).
## A swing counts once its hit has landed: a dash or a cast out of its
## recovery keeps the combo; the windup, a stun or death resets it.
## Fix: a caster that dies or is freed mid-cast takes its telegraph with it
## at once (COMBAT.md, Known bugs).
## Cleanup pass (2026-09-29): League-style enemy attacks through
## HitPipeline.resolve() (damage_increase, crit, hit: scopes).
## The Knight's own crit_chance and life_steal are held at 0 by a test
## baseline (_zero_knight_extras()), so exact-number checks aren't random;
## the same baseline removes his passive (Unbroken, CHAMPIONS CH2), so his AD
## stays 64 after he takes damage (the champions test covers Unbroken).
## It also cancels Cleave's 20 fury cost (CH3), since the Knight starts at 0.
## Combo timings are read from the data (combo_knight.tres speed_scale, 1.266):
## a data check pins the tuning, timing checks derive from it
## (_swing_frames()), and a check that changes the shared combo puts back
## the value it found.
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
	_zero_knight_extras()

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
	await _test_perch_melee_rule()
	await _test_uppercut()
	print("=== %d passed, %d failed ===\n" % [_passed, _failed])

	if DisplayServer.get_name() == "headless":
		get_tree().quit(_failed)


## The test baseline: the Knight's own crit_chance and life_steal
## (knight.tres) taken back to 0 for the whole run (a FLAT minus each base
## value), so checks of exact numbers aren't random. Crit and life steal
## checks add their own on top (+0.25 gives exactly 25%); C8 checks the real
## values.
const BASELINE_SOURCE := &"test_baseline"


func _zero_knight_extras() -> void:
	for stat: StringName in [&"crit_chance", &"life_steal"]:
		var base := knight.stats_component.get_base_value(stat)
		if base != 0.0:
			knight.stats_component.add_modifier(StatModifier.create(stat, FLAT, -base, BASELINE_SOURCE))
	if knight.champion != null and knight.champion.passive != null:
		knight.champion.passive.remove_from(knight, knight.champion.get_passive_source_id())
	# No Fury from swings (CHAMPIONS CH3), so Judgement never reaches its 60 Fury
	# bonus (CH4) and hits as the plain checks expect.
	if knight.champion != null:
		knight.stats_component.remove_modifiers_from(knight.champion.get_champion_source_id())
	# Cleave's own 20 fury cost (CHAMPIONS CH3) cancelled: the Knight starts at 0.
	if CLEAVE.resource_cost > 0.0:
		knight.stats_component.add_modifier(StatModifier.create(&"resource_cost", FLAT, -CLEAVE.resource_cost, BASELINE_SOURCE, &"ability:knight_cleave"))


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
	dummy.take_damage(50.0, knight)
	_check("health 280 -> 230", dummy.health.current, 230.0)
	_check("Unit.damaged still emits (amount, source)", local, [[50.0, knight]])
	_check("Events.unit_hit once", _hits.size(), 1)
	_check("Events.unit_damaged once", _damaged.size(), 1)
	if _hits.size() == 1:
		var ctx := _hits[0]
		_check("wrapped hit: PHYSICAL, can't crit",
			[ctx.damage_type, ctx.can_crit, ctx.source == knight],
			[HitContext.DamageType.PHYSICAL, false, true])
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
	_test_combo_data()
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
	await _test_shields()
	await _test_reactions()
	await _test_dash_strike()
	await _test_cancels_after_hit()
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
	_check("left mouse is attack only (the LoL select action is gone)", InputMap.has_action(&"select"), false)
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
	_check_near("hit lands ~0.08 s / speed_scale after the click (%d frames)" % _swing_frames(0.08), frames, _swing_frames(0.08), 1.0)
	_check("swing 1 hits the dummy for 1.0 x 64 AD", dummy.health.max_health - dummy.health.current, 64.0)
	_check("in recovery after the hit", knight.attack.is_in_recovery(), true)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 30)
	# Game time: the hit's light hitstop (0.03 s at time_scale 0.05) adds
	# physics frames but almost no game time. The test's clock also counts
	# the frame the swing started in, which the swing itself skips (+1/60).
	# At speed_scale 1.266 (combo_knight.tres) a 0.3 s swing is 0.237 s: 15 frames.
	var swing_frames := _swing_frames(0.3)
	_check_near("the swing lasts 0.3 s / speed_scale of game time (%d frames at 1/60 s)" % swing_frames,
		_game_time - start_time, (swing_frames + 1) / 60.0, 0.004)
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
		_check_near("right after swing 1 ended (~%d frames)" % _swing_frames(0.3), started[1][0] - started[0][0], _swing_frames(0.3), 2.0)
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
	_check("and the combo moves on: swing 2 is next (a swing counts once its hit has landed)", knight.attack.get_combo_index(), 1)

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
	_check("after the hit, the combo moves on: swing 2 is next", knight.attack.get_combo_index(), 1)
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
	var base_scale := knight.attack.combo.speed_scale
	_check("get_attack_interval() = 1 / 0.7 attack speed", knight.attack.get_attack_interval(), 1.0 / 0.7)
	_check("base: combo speed = speed_scale (%s)" % base_scale, knight.attack.get_swing_speed(), base_scale)
	knight.stats_component.add_modifier(StatModifier.create(&"attack_speed", PERCENT_ADD, 0.5, &"test_attack_speed"))
	_check("+50% bonus attack speed: combo speed 1.5 x speed_scale", knight.attack.get_swing_speed(), 1.5 * base_scale)
	var start := _frame
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 40)
	var frames := _swing_frames(0.3 / 1.5)
	_check_near("the swing lasts 0.3 / (1.5 x speed_scale) s (%d frames)" % frames, _frame - start, frames, 1.0)
	knight.stats_component.remove_modifiers_from(&"test_attack_speed")


# --- Combo pace: speed_scale and pause_after ----------------------------------------

func _test_combo_pace() -> void:
	_section("Combo pace: the finisher's breather and the speed knob")
	var combo := knight.attack.combo
	var base_scale := combo.speed_scale
	_check("pause_after 0 / 0 / 0.25 s, speed_scale 1.266",
		[combo.swings[0].pause_after, combo.swings[1].pause_after, combo.swings[2].pause_after, combo.speed_scale], [0.0, 0.0, 0.25, 1.266])
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
	_check_near("the click fires when the 0.25 s / speed_scale breather ends", _game_time - t0, 0.25 / base_scale, 0.04)
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
	combo.speed_scale = base_scale   # back to the data's value (it's the shared combo_knight.tres), not to 1.0


## Physics frames a swing timing of `seconds` (at base attack speed) lasts at
## the Knight's combo speed_scale: the timer is done within
## AutoAttackComponent.SWING_TIME_EPSILON of 0.
func _swing_frames(seconds: float) -> int:
	var scaled := seconds / knight.attack.combo.speed_scale
	return ceili((scaled - AutoAttackComponent.SWING_TIME_EPSILON) * 60.0)


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
	_test_hit_feel_data()
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
	_check("combo feel: LIGHT / LIGHT / HEAVY",
		[knight.attack.combo.swings[0].feel, knight.attack.combo.swings[1].feel, knight.attack.combo.swings[2].feel],
		[HitContext.Feel.LIGHT, HitContext.Feel.LIGHT, HitContext.Feel.HEAVY])


func _test_longest_hitstop() -> void:
	_section("C3: overlapping hitstops: the longest wins")
	await _hitstop_over()
	GameFeel.hitstop(0.03)
	_check("a hitstop slows time to 0.05", Engine.time_scale, 0.05)
	GameFeel.hitstop(0.08)
	var t0 := Time.get_ticks_usec()
	_check_near("a longer one extends it to 0.08 s", GameFeel.get_hitstop_left(), 0.08, 0.005)
	GameFeel.hitstop(0.02)
	_check_near("a shorter one changes nothing", GameFeel.get_hitstop_left(), 0.08, 0.005)
	# Real time from here. A frame can run long on a busy machine, so the
	# checks use the time that actually passed, sampled every frame, and a
	# hitstop can only end on a frame boundary (its tolerance is in frames).
	var longest := 0.0   # the longest frame seen, real seconds
	var last := t0
	var left_at := -1.0   # time left at the first frame 0.04 s or more in
	var elapsed_at := 0.0
	while Time.get_ticks_usec() - t0 < 500000 and GameFeel.is_hitstop_active():
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		longest = maxf(longest, (now - last) / 1000000.0)
		last = now
		if left_at < 0.0 and now - t0 >= 40000:
			elapsed_at = (now - t0) / 1000000.0
			left_at = GameFeel.get_hitstop_left()
	var ended := (last - t0) / 1000000.0
	_check_near("%.3f s in: time left follows the 0.08 s end" % elapsed_at, left_at, maxf(0.08 - elapsed_at, 0.0), 0.005)
	_check("still frozen after the first (0.03 s) would have ended: it ended at %.3f s, not before 0.08 s" % ended,
		ended >= 0.075, true)
	_check("over within 3 frames of 0.08 s (the longest %.3f s), time back to normal" % longest,
		[ended <= 0.085 + 3.0 * longest, GameFeel.is_hitstop_active(), Engine.time_scale], [true, false, 1.0])


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


## The hit flash is the 3D model's (UnitView, on `damaged`; view_test checks
## it): every hit that gets through emits `damaged` once, a blocked hit none.
## (It flashed the 2D body until the 3D pivot's cleanup C3.)
func _test_flash() -> void:
	_section("C3: the hit flash's signal")
	await _hitstop_over()
	var dummy := _dummy_at(Vector2(40, 0))
	await _frames(1)
	var flashes := [0]
	dummy.damaged.connect(func(_amount: float, _source: Unit) -> void: flashes[0] += 1)
	dummy.take_damage(5.0, knight)
	_check("a hit that gets through emits damaged once (the model flashes on it)", flashes[0], 1)
	dummy.add_invulnerability(&"test")
	dummy.take_damage(5.0, knight)
	dummy.remove_invulnerability(&"test")
	_check("a blocked hit emits none: no flash", flashes[0], 1)
	dummy.queue_free()


## A camera that records GameFeel.shake() amounts: a Camera3D, as the 3D
## view's GameCamera3D is (GameFeel.shake() shakes the current Camera3D).
func _spy_camera() -> Camera3D:
	var script := GDScript.new()
	script.source_code = "extends Camera3D\nvar on_shake: Callable\nfunc shake(amount: float) -> void:\n\ton_shake.call(amount)\n"
	script.reload()
	var cam := Camera3D.new()
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
	_test_melee_data()
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
	var walled := _dummy_at(Vector2(90, 0))
	await _frames(2)
	_check("line of sight: blocked by the wall", WorldQuery.has_line_of_sight(knight.global_position, walled.global_position), false)
	from = knight.global_position
	knight.attack.try_swing(Vector2.RIGHT)
	_check("a slime behind the pillar is never aimed at", knight.attack.get_assist_target() == null, true)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 40)
	_check("the step doesn't go through the wall", knight.global_position.x - from.x <= 6.01, true)
	walled.queue_free()
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
	_test_getting_hit_data()
	await _test_post_hit_iframes()
	await _test_slime_hit_and_push()
	await _test_enemy_hit_pipeline()
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
	var t0 := _game_time
	while knight.has_invulnerability(Unit.HIT_IFRAMES_ID) and _game_time - t0 < 1.0:
		await get_tree().process_frame
	_check_near("they last 0.3 s", _game_time - t0, 0.3, 0.05)
	# The blink is the 3D model's (UnitView reads the period; view_test checks
	# it). It blinked the 2D body until the 3D pivot's cleanup C3.
	_check("the Knight's blink period: 0.1 s (the model shows 60% of it)", knight.hit_iframes_blink_period, 0.1)
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


## Cleanup pass (2026-09-29): a League-style enemy attack is built by
## AutoAttackComponent.make_attack_context() and goes through
## HitPipeline.resolve(), so the attacker's damage_increase, crit and hit:
## scopes apply to it like they do to the player's swings.
func _test_enemy_hit_pipeline() -> void:
	_section("Enemy basic attacks through HitPipeline.resolve() (damage_increase, crit, hit: scopes)")
	var scoped := func(stat: StringName, value: float, scope: StringName) -> StatModifier:
		return StatModifier.create(stat, FLAT, value, &"test_enemy_hit", scope)
	var cases := [
		["no modifiers: 22 (1.0 x 22 AD), unchanged", [], 22.0, false],
		["+50% damage_increase: 33", [scoped.call(&"damage_increase", 0.5, &"")], 33.0, false],
		["+50% on hit:basic_attack: 33", [scoped.call(&"damage_increase", 0.5, &"hit:basic_attack")], 33.0, false],
		["+50% on hit:ability only: still 22", [scoped.call(&"damage_increase", 0.5, &"hit:ability")], 22.0, false],
		["100% crit: 22 x 1.75 = 38.5", [scoped.call(&"crit_chance", 1.0, &"")], 38.5, true],
		["100% crit on hit:basic_attack only: 38.5", [scoped.call(&"crit_chance", 1.0, &"hit:basic_attack")], 38.5, true],
	]
	var slime := _spawn_dummy()
	for c: Array in cases:
		await _reset_knight()
		await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
		knight.health.heal(10000.0)
		_place(slime, knight.global_position + Vector2(45, 0))
		var mods: Array[StatModifier] = []
		mods.assign(c[1])
		slime.stats_component.add_modifiers(mods)
		await _frames(1)
		_hits.clear()
		slime.attack.attack(knight)
		await _wait_until(func() -> bool: return _hits.any(func(h: HitContext) -> bool: return h.source == slime), 60)
		slime.attack.cancel()
		slime.stats_component.remove_modifiers_from(&"test_enemy_hit")
		var found := _hits.filter(func(h: HitContext) -> bool: return h.source == slime)
		if found.is_empty():
			_report(false, c[0], "no hit")
			continue
		var hit: HitContext = found[0]
		_check("%s" % c[0], [hit.raw_damage, hit.is_crit, hit.has_tag(&"basic_attack"), hit.has_tag(&"physical")], [c[2], c[3], true, true])
	var hit_ctx := slime.attack.make_attack_context(knight)
	_check("its HitContext: 1.0 x AD, PHYSICAL, can crit, feel NONE, the slime's 12 px push",
		[hit_ctx.ad_ratio, hit_ctx.base_damage, hit_ctx.damage_type, hit_ctx.can_crit, hit_ctx.feel, hit_ctx.knockback_px],
		[1.0, 0.0, HitContext.DamageType.PHYSICAL, true, HitContext.Feel.NONE, 12.0])
	slime.queue_free()
	knight.health.heal(10000.0)


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
	_test_elite_data()
	await _test_slam_hits()
	await _test_slam_dodges()
	await _test_elite_ai()
	await _test_telegraph_on_death()


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
	# Since ABILITIES AB1 any stun interrupts at once; a short one is tested
	# in abilities_test.
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
	var elite := _spawn_elite(knight.global_position + Vector2(70, 0), false, true)
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


func _test_telegraph_on_death() -> void:
	_section("Fix: a caster that dies or is freed mid-cast")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	knight.health.heal(10000.0)
	var hp := knight.health.current

	# Killed early (0.1 s in): freed by its death tween long before the
	# 0.65 s cast time ends. This is the case that left the telegraph forever.
	var elite := _spawn_elite(knight.global_position + Vector2(60, 0), true)
	await _frames(1)
	var finished := [0]
	elite.abilities.cast_finished.connect(func(_s: StringName, _a: Ability) -> void: finished[0] += 1)
	elite.abilities.try_cast(&"q", knight.global_position, knight)
	var telegraph := _find_telegraph()
	await _frames(6)
	_check("the slam's telegraph is on the floor", telegraph != null and is_instance_valid(telegraph), true)
	elite.take_damage(100000.0)
	_check("killed mid-cast: the cast ends at once", [elite.is_alive(), elite.abilities.casting, finished[0]], [false, false, 1])
	await _frames(1)
	_check("its telegraph is gone the next frame", is_instance_valid(telegraph), false)
	await _frames(60)
	_check("the elite is freed and nothing is left on the floor", [is_instance_valid(elite), _find_telegraph() == null], [false, true])
	_check("no slam landed", knight.health.current, hp)

	# Killed late (0.5 s in): still in the tree when the cast time ends, so
	# the old path runs; it must see the cast is already over.
	elite = _spawn_elite(knight.global_position + Vector2(60, 0), true)
	await _frames(1)
	finished[0] = 0
	elite.abilities.cast_finished.connect(func(_s: StringName, _a: Ability) -> void: finished[0] += 1)
	elite.abilities.try_cast(&"q", knight.global_position, knight)
	telegraph = _find_telegraph()
	await _frames(30)
	elite.take_damage(100000.0)
	await _frames(1)
	_check("killed late in the cast: the telegraph is gone at once", is_instance_valid(telegraph), false)
	await _frames(12)   # past the end of the cast time, before the elite is freed
	_check("cast_finished fired once, and no slam landed", [finished[0], knight.health.current], [1, hp])
	await _frames(30)

	# Freed without dying (a room unloading, a test cleaning up).
	elite = _spawn_elite(knight.global_position + Vector2(60, 0), true)
	await _frames(1)
	elite.abilities.try_cast(&"q", knight.global_position, knight)
	telegraph = _find_telegraph()
	await _frames(6)
	elite.queue_free()
	await _frames(2)
	_check("freed mid-cast: its telegraph goes with it", is_instance_valid(telegraph), false)

	# interrupt_cast() on a living caster refunds, like a stun interrupt.
	elite = _spawn_elite(knight.global_position + Vector2(60, 0), true)
	await _frames(1)
	elite.abilities.try_cast(&"q", knight.global_position, knight)
	telegraph = _find_telegraph()
	await _frames(6)
	_check("interrupt_cast() on a living caster", [elite.abilities.interrupt_cast(), elite.abilities.casting, elite.abilities.is_ready(&"q")], [true, false, true])
	await _frames(1)
	_check("removes its telegraph too", is_instance_valid(telegraph), false)
	_check("with no cast running it does nothing", elite.abilities.interrupt_cast(), false)
	await _frames(45)
	_check("and no slam lands later", knight.health.current, hp)
	elite.queue_free()
	await _frames(2)


## `naive`: no EnemyData, so no brain: the old routine and its naive cast
## loop (ENEMIES_AI AI1; C5's checks are about that loop).
func _spawn_elite(pos: Vector2, passive: bool, naive: bool = false) -> Enemy:
	var elite: Enemy = ELITE_SCENE.instantiate()
	if naive:
		elite.data = null
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
		var before_swing := _numbers()
		knight.attack.try_swing(Vector2.RIGHT)
		await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 20)
		var new := _numbers().filter(func(n: Label) -> bool: return not before_swing.has(n))
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
	_hit(dummy, 30.0, HitContext.DamageType.TRUE)
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
	# A tick under 1 would show "0" (Inevitable Demise's, CHAMPIONS K2's fix):
	# it waits and adds into the unit's next DoT number.
	var small_ticks: Array = []
	for i in 5:
		await _frames(25)   # past the merge window
		before = _numbers()
		var small := dummy.make_hit_context(0.3, knight)
		small.add_tag(&"dot")
		dummy.on_hit(small)
		small_ticks.append(_numbers().filter(func(n: Label) -> bool: return not before.has(n)).map(func(n: Label) -> String: return n.text))
	_check("ticks of 0.3 show nothing until they reach 1: \"1\" on the 4th (1.2), never \"0\", then it starts over",
		small_ticks, [[], [], [], ["1"], []])

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

	# Stacking (Ryan, 2026-10-03): hits in a row read as a column, not a pile.
	await _wait_until(func() -> bool: return _numbers().is_empty(), 60)
	dummy.health.heal(1000.0)
	var starts: Array[float] = []
	for i in 5:
		before = _numbers()
		dummy.take_damage(40.0, knight)
		added = _numbers().filter(func(n: Label) -> bool: return not before.has(n))
		starts.append((added[0] as Label).position.y if added.size() == 1 else INF)
	var steps: Array[float] = []
	for i in range(1, 5):
		steps.append(snappedf(starts[i - 1] - starts[i], 0.01))
	_check("a unit's next number starts %.0f px above its previous one while that one shows, up to %d high, then at the bottom again" % [style.stack_step_px, style.stack_levels],
		steps, [style.stack_step_px, style.stack_step_px, style.stack_step_px, -3.0 * style.stack_step_px])
	await _wait_until(func() -> bool: return _numbers().is_empty(), 60)
	before = _numbers()
	dummy.take_damage(40.0, knight)
	added = _numbers().filter(func(n: Label) -> bool: return not before.has(n))
	_check("once its numbers are gone, the next starts at the bottom", added.size() == 1 and is_equal_approx((added[0] as Label).position.y, starts[0]), true)
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
	_check("knight.tres: crit_chance 0.25 (0 for this test: the baseline), life_steal 0 (zero sustain)",
		[knight.stats_component.get_base_value(&"crit_chance"), knight.stats_component.get_base_value(&"life_steal"),
			knight.stats_component.get_stat(&"crit_chance"), knight.stats_component.get_stat(&"life_steal")], [0.25, 0.0, 0.0, 0.0])
	_check("0% crit (the Knight's own 25% taken back by the test baseline): 0 crits in 200 rolls", _count_crits(nothing, 200), 0)
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
	# Back to an empty pool (the Knight's Fury starts at 0, CHAMPIONS CH3), so
	# Judgement later stays below its 60 Fury bonus (CH4).
	knight.resource_pool.try_spend(knight.resource_pool.current)

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
	await _test_k2_status_pieces()
	await _test_diminishing_returns()


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
	sc.cc_diminishing = false   # three stuns in a second: the stack rule, not diminishing returns (AI-D3's own checks below)
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
	sc.cc_diminishing = true
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
	_check("the haste: 375 -> 506.25 (+35%)", [base_speed, snappedf(knight.movement.get_move_speed(), 0.01)], [375.0, 506.25])
	_check("its modifier's source is status_iron_resolve", knight.stats_component.get_modifiers_from(&"status_iron_resolve").size(), 1)
	await _wait_until(func() -> bool: return not sc.has_status(&"iron_resolve"), 150)
	_check("gone after 2 s, speed back to 375", [sc.has_status(&"iron_resolve"), knight.movement.get_move_speed()], [false, 375.0])
	knight.attack.cancel_swing()
	sc.remove_status(AutoAttackComponent.get_empower_status_id(&"iron_resolve"))   # clear its empowered swing
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


# --- ENEMIES_AI AI-D3: diminishing returns on crowd control (COMBAT.md, Status effects) ---

const STATUS_ROOT: StatusEffect = preload("res://data/statuses/status_root.tres")
const STATUS_CC_IMMUNE: StatusEffect = preload("res://data/statuses/status_cc_immune.tres")
const STATUS_AIRBORNE: StatusEffect = preload("res://data/statuses/status_airborne.tres")
const CC_RULES_DEFAULT: CrowdControlRules = preload("res://data/statuses/crowd_control_rules_default.tres")
const RING_SCRIPT := preload("res://scripts/vfx/cc_immune_ring.gd")

## cc_applied / cc_refused on one unit: [&"applied", status id, from the
## source?, duration, step] and [&"refused", status id, from the source?,
## reason, duration].
var _cc_events: Array = []
var _cc_watched: Unit
var _cc_source: Unit


func _test_diminishing_returns() -> void:
	Events.cc_applied.connect(_on_cc_applied)
	Events.cc_refused.connect(_on_cc_refused)
	_test_aid3_data()
	await _test_aid3_rule()
	await _test_aid3_window()
	_test_aid3_tenacity_and_exceptions()
	await _test_aid3_knight_stuns_an_elite()
	Events.cc_applied.disconnect(_on_cc_applied)
	Events.cc_refused.disconnect(_on_cc_refused)


func _on_cc_applied(unit: Unit, source: Unit, status: StatusEffect, duration: float, dr_step: int) -> void:
	if unit == _cc_watched:
		_cc_events.append([&"applied", status.id, source == _cc_source, snappedf(duration, 0.001), dr_step])


func _on_cc_refused(unit: Unit, source: Unit, status: StatusEffect, reason: StringName, duration: float) -> void:
	if unit == _cc_watched:
		_cc_events.append([&"refused", status.id, source == _cc_source, reason, snappedf(duration, 0.001)])


## Starts recording `unit`'s crowd control events, `source` as the expected source.
func _watch_cc(unit: Unit, source: Unit) -> void:
	_cc_events.clear()
	_cc_watched = unit
	_cc_source = source


## Short numbers for the timing checks: a 0.5 s window, × 0.5, 0.3 s immune.
func _short_cc_rules() -> CrowdControlRules:
	var rules := CrowdControlRules.new()
	rules.dr_window = 0.5
	rules.dr_factor = 0.5
	rules.dr_immune_time = 0.3
	rules.immune_status = STATUS_CC_IMMUNE
	return rules


func _test_aid3_data() -> void:
	_section("AI-D3: diminishing returns' data (Ryan, 2026-10-05: every unit but fodder, the numbers as proposed)")
	_check("crowd_control_rules_default: a 4 s window, the second × 0.5, a third refused and 3 s immune (status_cc_immune)",
		[CC_RULES_DEFAULT.dr_window, CC_RULES_DEFAULT.dr_factor, CC_RULES_DEFAULT.dr_immune_time, CC_RULES_DEFAULT.immune_status == STATUS_CC_IMMUNE],
		[4.0, 0.5, 3.0, true])
	_check("status_cc_immune: tags cc_immune + buff, not crowd control itself, its look (the ring)",
		[STATUS_CC_IMMUNE.id, STATUS_CC_IMMUNE.tags, STATUS_CC_IMMUNE.is_cc(), STATUS_CC_IMMUNE.vfx != null],
		[&"cc_immune", [&"cc_immune", &"buff"], false, true])
	var sc := knight.status_component
	_check("the Knight's StatusComponent: diminishing returns on, poise off, the default rules",
		[sc.cc_diminishing, sc.poise, sc.get_cc_rules() == CC_RULES_DEFAULT], [true, false, true])
	var silence := _make_status(&"test_silence", [&"cc", &"silence", &"debuff"], 1.0)
	silence.blocks_cast = true
	var lock := _make_status(&"test_lock", [&"debuff"], 1.0)   # blocks moving, not tagged cc
	lock.blocks_move = true
	var mark := _make_status(&"test_cc_mark", [&"cc", &"debuff"], 1.0)   # cc that blocks nothing
	var counts: Array = []
	for e: StatusEffect in [STATUS_STUN, STATUS_ROOT, silence, STATUS_SLOW, STATUS_AIRBORNE, lock, mark]:
		counts.append(StatusComponent.counts_for_diminishing(e))
	_check("what counts: a stun, a root, a silence; not a slow, a knock-up (it ignores tenacity), a lock not tagged cc, a cc status that blocks nothing",
		counts, [true, true, true, false, false, false, false])
	_check("Events: cc_applied, cc_refused", [Events.has_signal("cc_applied"), Events.has_signal("cc_refused")], [true, true])


func _test_aid3_rule() -> void:
	_section("AI-D3: rooted twice in 4 s, the second lasts half as long; a third doesn't take and he's immune for 3 s, with a ring at his feet")
	await _reset_knight()
	await _hitstop_over()
	var sc := knight.status_component
	var source := _spawn_dummy()
	_watch_cc(knight, source)
	var first := sc.apply_status(STATUS_ROOT, source)
	var t1 := sc.get_time_left(&"root")
	sc.remove_status(&"root")
	await _frames(30)   # half a second later
	var second := sc.apply_status(STATUS_ROOT, source)
	var t2 := sc.get_time_left(&"root")
	_check("the first root takes in full (1 s); the second, half a second later, lasts 0.5 s", [first, t1, second, t2], [true, 1.0, true, 0.5])
	_check_near("the count is 2 and the window, from the first, has 3.5 s left", sc.get_dr_window_left(), 3.5, 0.02)
	_check("the next would be refused (get_dr_step() 2)", [sc.get_dr_count(), sc.get_dr_step()], [2, 2])
	sc.remove_status(&"root")
	var third := sc.apply_status(STATUS_STUN, source, 0.5)
	_check("a third (a stun: any counted crowd control counts) is refused; he gets status_cc_immune for 3 s, from himself; the count starts over",
		[third, sc.has_status(&"stun"), sc.has_tag(&"cc_immune"), sc.get_time_left(&"cc_immune"), sc.get_source(&"cc_immune") == knight, sc.get_dr_count()],
		[false, false, true, 3.0, true, 0])
	await _frames(1)
	var rings := knight.get_children().filter(func(n: Node) -> bool: return n.get_script() == RING_SCRIPT and not n.is_queued_for_deletion())
	_check("its look: one ring on the Knight, a floor drawing (FloorOverlay's layer), not an icon over his head",
		[rings.size(), rings.size() == 1 and ((rings[0] as CanvasItem).visibility_layer & FloorOverlay.DRAWING_VISIBILITY_BIT) != 0], [1, true])
	var while_immune := [sc.apply_status(STATUS_ROOT, source), sc.apply_status(STATUS_SLOW, source), sc.get_dr_step()]
	sc.remove_status(&"slow")
	_check("immune: a root is refused; a slow still takes (it doesn't count)", while_immune, [false, true, 2])
	_check("the events: root applied (1 s, step 0), root applied (0.5 s, step 1), the stun refused (immune; it would have been 0.5 s), the root refused (immune, 1 s); a slow tells nothing",
		_cc_events, [[&"applied", &"root", true, 1.0, 0], [&"applied", &"root", true, 0.5, 1],
			[&"refused", &"stun", true, StatusComponent.IMMUNE, 0.5], [&"refused", &"root", true, StatusComponent.IMMUNE, 1.0]])
	await _wait_until(func() -> bool: return not sc.has_tag(&"cc_immune"), 200)
	await _frames(1)
	rings = knight.get_children().filter(func(n: Node) -> bool: return n.get_script() == RING_SCRIPT and not n.is_queued_for_deletion())
	_check("3 s later the immunity and its ring are gone, and the next would take in full", [sc.has_tag(&"cc_immune"), rings.size(), sc.get_dr_step(), sc.get_dr_count()], [false, 0, 0, 0])
	source.queue_free()
	await _frames(2)


func _test_aid3_window() -> void:
	_section("AI-D3: the window counts from the first; after it, and after the immunity, the count starts over (short numbers: a 0.5 s window, 0.3 s immune)")
	var dummy := _spawn_dummy()
	var sc := dummy.status_component
	sc.cc_diminishing = true   # a slime is fodder: off at spawn
	sc.cc_rules = _short_cc_rules()
	sc.apply_status(STATUS_STUN, null, 1.0)   # the environment's crowd control counts too
	await _frames(12)
	sc.remove_status(&"stun")
	sc.apply_status(STATUS_STUN, null, 1.0)
	var halved := sc.get_time_left(&"stun")
	sc.remove_status(&"stun")
	await _frames(24)   # 0.6 s after the first
	var after := [sc.get_dr_count(), sc.apply_status(STATUS_STUN, null, 1.0), sc.get_time_left(&"stun")]
	sc.remove_status(&"stun")
	_check("0.2 s after the first a second is halved (0.5 s); at 0.6 s the window has closed and a third takes in full", [halved, after], [0.5, [0, true, 1.0]])
	sc.apply_status(STATUS_STUN, null, 1.0)
	sc.remove_status(&"stun")
	var refused := sc.apply_status(STATUS_STUN, null, 1.0)
	var immune_for := sc.get_time_left(&"cc_immune")
	await _wait_until(func() -> bool: return not sc.has_tag(&"cc_immune"), 60)
	var again := [sc.apply_status(STATUS_STUN, null, 1.0), sc.get_time_left(&"stun"), sc.get_dr_count()]
	_check("a second and a third at once: the third refused, immune 0.3 s (cc_rules.dr_immune_time); then a stun takes in full, the count at 1",
		[refused, snappedf(immune_for, 0.001), again], [false, 0.3, [true, 1.0, 1]])
	dummy.queue_free()
	await _frames(2)


func _test_aid3_tenacity_and_exceptions() -> void:
	_section("AI-D3: tenacity first, then the step; fodder, a unit's own crowd control, unstoppable, poise, IGNORE, death")
	var dummy := _spawn_dummy()
	var sc := dummy.status_component
	var full: Array = []
	for i in 3:
		full.append(sc.apply_status(STATUS_STUN, knight, 1.0))
		full.append(sc.get_time_left(&"stun"))
		sc.remove_status(&"stun")
	_check("a slime (fodder: RankRules.cc_diminishing off, given at spawn) takes three 1 s stuns in full, never immune",
		[sc.cc_diminishing, full, sc.has_tag(&"cc_immune")], [false, [true, 1.0, true, 1.0, true, 1.0], false])
	sc.cc_diminishing = true
	_watch_cc(dummy, knight)
	dummy.stats_component.add_modifier(StatModifier.create(&"tenacity", FLAT, 0.5, &"test_aid3"))
	sc.apply_status(STATUS_STUN, knight, 1.0)
	var t1 := sc.get_time_left(&"stun")
	sc.remove_status(&"stun")
	sc.apply_status(STATUS_STUN, knight, 1.0)
	var t2 := sc.get_time_left(&"stun")
	sc.remove_status(&"stun")
	_check("50% tenacity: a 1 s stun lasts 0.5 s, the second 0.25 s (× (1 − tenacity), then × 0.5); the events say so",
		[t1, t2, _cc_events], [0.5, 0.25, [[&"applied", &"stun", true, 0.5, 0], [&"applied", &"stun", true, 0.25, 1]]])
	dummy.stats_component.remove_modifiers_from(&"test_aid3")
	sc.clear()
	_check("death (clear()) starts the count over", [sc.get_dr_count(), sc.get_dr_window_left()], [0, 0.0])
	var own: Array = []
	for i in 3:
		own.append(sc.apply_status(STATUS_ROOT, dummy))
		sc.remove_status(&"root")
	_check("its own crowd control on itself is outside the rule: three roots take, the count stays 0", [own, sc.get_dr_count()], [[true, true, true], 0])
	sc.apply_status(STATUS_CC_IMMUNE, dummy, 1.0)
	var immune_rows := [sc.apply_status(STATUS_ROOT, dummy), sc.apply_status(STATUS_STUN, knight, 1.0)]
	sc.remove_status(&"root")
	sc.remove_status(&"cc_immune")
	_check("a cc_immune status from anything refuses another's stun, not its own root", immune_rows, [true, false])
	var unstoppable := _make_status(&"test_unstoppable", [&"unstoppable", &"buff"], 1.0)
	sc.apply_status(unstoppable, dummy)
	_watch_cc(dummy, knight)
	var stopped := sc.apply_status(STATUS_STUN, knight, 1.0)
	sc.remove_status(&"test_unstoppable")
	sc.poise = true
	dummy.stats_component.add_modifier(StatModifier.create(&"tenacity", FLAT, 0.4, &"test_aid3"))
	var poised := sc.apply_status(STATUS_STUN, knight, 1.0)
	sc.poise = false
	dummy.stats_component.remove_modifiers_from(&"test_aid3")
	_check("unstoppable refuses it (`unstoppable`); poise (the boss hook) refuses it (`poise`, with the 0.6 s it would have had after 40% tenacity); neither counts",
		[stopped, poised, sc.get_dr_count(), _cc_events],
		[false, false, 0, [[&"refused", &"stun", true, StatusComponent.UNSTOPPABLE, 1.0], [&"refused", &"stun", true, StatusComponent.POISE, 0.6]]])
	var hold := _make_status(&"test_hold", [&"cc", &"debuff"], 1.0)
	hold.blocks_move = true
	hold.stack_rule = StatusEffect.StackRule.IGNORE
	var hold_rows := [sc.apply_status(hold, knight), sc.apply_status(hold, knight), sc.get_dr_count()]
	_check("an IGNORE crowd control re-applied while active does nothing and isn't counted", hold_rows, [true, false, 1])
	_cc_watched = null
	dummy.queue_free()


func _test_aid3_knight_stuns_an_elite() -> void:
	_section("AI-D3: the Knight's own stuns on an elite: Judgement's 0.75 s, after its 20% tenacity 0.6 s; again within 4 s 0.3 s; a third is refused")
	await _reset_knight()
	await _hitstop_over()
	var elite := _spawn_elite(knight.global_position + Vector2(60, 0), true)
	await _frames(2)
	elite.stats_component.add_modifier(StatModifier.create(&"max_health", FLAT, 50000.0, &"test_tough"))
	elite.health.heal(100000.0)
	var sc := elite.status_component
	_check("the elite slime: diminishing returns on (its rank's), 20% tenacity", [sc.cc_diminishing, elite.stats_component.get_stat(&"tenacity")], [true, 0.2])
	var times: Array = []
	for i in 3:
		if knight.resource_pool != null:
			knight.resource_pool.try_spend(knight.resource_pool.current)   # under 60 Fury: no bonus stun
		await _cast(&"r", elite.global_position, elite)
		times.append(snappedf(sc.get_time_left(&"stun"), 0.001))
		sc.remove_status(&"stun")
		await _hitstop_over()
	_check("three Judgements: 0.6 s, 0.3 s, refused (immune)", [times, sc.has_tag(&"cc_immune")], [[0.6, 0.3, 0.0], true])
	elite.queue_free()
	await _frames(2)


# --- C10: shields ---------------------------------------------------------------------

const STATUS_SHIELD: StatusEffect = preload("res://data/statuses/status_shield.tres")


func _test_shields() -> void:
	_test_c10_data()
	_test_c10_absorb()
	_test_c10_order_and_stacks()
	await _test_c10_hit_still_lands()


func _test_c10_data() -> void:
	_section("C10: shield data")
	_check("status_shield: 100 shield, 3 s, tags shield + buff, refreshes",
		[STATUS_SHIELD.id, STATUS_SHIELD.shield_amount, STATUS_SHIELD.duration, STATUS_SHIELD.tags, STATUS_SHIELD.stack_rule, STATUS_SHIELD.is_shield()],
		[&"shield", 100.0, 3.0, [&"shield", &"buff"], StatusEffect.StackRule.REFRESH, true])


func _test_c10_absorb() -> void:
	_section("C10: a shield absorbs damage before health")
	var style: DamageNumberStyle = NUMBER_SCRIPT.DEFAULT_STYLE
	var dummy := _spawn_dummy()
	var sc := dummy.status_component
	sc.apply_status(STATUS_SHIELD, knight)
	var damaged_before := _damaged.size()
	var before := _numbers()
	var first := _hit(dummy, 80.0, HitContext.DamageType.PHYSICAL)
	var added := _numbers().filter(func(n: Label) -> bool: return not before.has(n))
	_check("80 into a 100 shield: absorbed 80, taken 80, no health lost, 20 shield left",
		[first.absorbed, first.taken_damage, first.health_lost, dummy.health.current == dummy.health.max_health, sc.get_shield(&"shield")], [80.0, 80.0, 0.0, true, 20.0])
	_check("unit_damaged still fires (taken 80)", _damaged.size() - damaged_before, 1)
	_check("one number: \"80\" in the shield color", added.map(func(n: Label) -> Array: return [n.text, n.color, n.kind]), [["80", style.shield_color, NUMBER_SCRIPT.Kind.SHIELD]])
	var removed: Array = []
	var on_removed := func(unit: Unit, status: StatusEffect) -> void: removed.append([unit, status.id])
	Events.status_removed.connect(on_removed)
	before = _numbers()
	var second := _hit(dummy, 80.0, HitContext.DamageType.PHYSICAL)
	added = _numbers().filter(func(n: Label) -> bool: return not before.has(n))
	Events.status_removed.disconnect(on_removed)
	_check("the next 80: 20 absorbed, 60 to health", [second.absorbed, second.health_lost], [20.0, 60.0])
	_check("used up: the shield status ends (status_removed)", [sc.has_status(&"shield"), removed], [false, [[dummy, &"shield"]]])
	_check("two numbers: \"20\" shield, \"60\" physical", added.map(func(n: Label) -> Array: return [n.text, n.color]), [["20", style.shield_color], ["60", style.physical_color]])

	dummy.health.heal(1000.0)
	sc.apply_status(STATUS_SHIELD, knight)
	dummy.stats_component.add_modifier(StatModifier.create(&"armor", FLAT, 100.0, &"test_c10"))
	var armored := _hit(dummy, 160.0, HitContext.DamageType.PHYSICAL)
	_check("after armor: 160 at 100 armor = 80 taken, all absorbed", [armored.taken_damage, armored.absorbed, armored.health_lost], [80.0, 80.0, 0.0])
	dummy.stats_component.remove_modifiers_from(&"test_c10")
	var true_hit := _hit(dummy, 30.0, HitContext.DamageType.TRUE)
	_check("TRUE damage is absorbed too (20 left, then 10 to health)", [true_hit.absorbed, true_hit.health_lost], [20.0, 10.0])
	sc.apply_status(STATUS_SHIELD, knight)
	dummy.health.take_damage(dummy.health.current - 5.0)
	var huge := _hit(dummy, 100.0, HitContext.DamageType.PHYSICAL)
	_check("a hit the shield fully takes can't kill (100 into 100 at 5 health)", [huge.killed, dummy.is_alive(), dummy.health.current], [false, true, 5.0])
	dummy.queue_free()


func _test_c10_order_and_stacks() -> void:
	_section("C10: absorb order (soonest to expire first) and stacks")
	var dummy := _spawn_dummy()
	var sc := dummy.status_component
	var soon := _make_status(&"test_shield_soon", [&"shield"], 1.0)
	soon.shield_amount = 50.0
	var later := _make_status(&"test_shield_later", [&"shield"], 3.0)
	later.shield_amount = 50.0
	var forever := _make_status(&"test_shield_forever", [&"shield"], -1.0)
	forever.shield_amount = 50.0
	sc.apply_status(forever)
	sc.apply_status(later)
	sc.apply_status(soon)
	_check("three 50 shields: 150 total", sc.get_total_shield(), 150.0)
	_hit(dummy, 70.0, HitContext.DamageType.TRUE)
	_check("70: the 1 s one used up first, then 20 from the 3 s one; the until-removed one untouched",
		[sc.has_status(&"test_shield_soon"), sc.get_shield(&"test_shield_later"), sc.get_shield(&"test_shield_forever")], [false, 30.0, 50.0])
	_hit(dummy, 60.0, HitContext.DamageType.TRUE)
	_check("60: the 3 s one ends, 30 from the until-removed one", [sc.has_status(&"test_shield_later"), sc.get_shield(&"test_shield_forever")], [false, 20.0])
	sc.remove_status(&"test_shield_forever")

	var stacking := _make_status(&"test_shield_stack", [&"shield"], 2.0)
	stacking.shield_amount = 40.0
	stacking.stack_rule = StatusEffect.StackRule.STACK
	stacking.max_stacks = 3
	sc.apply_status(stacking, null, 1.0)
	sc.apply_status(stacking)
	_hit(dummy, 50.0, HitContext.DamageType.TRUE)
	_check("2 stacked 40 shields, 50 damage: the 1 s stack is used up, the other has 30",
		[sc.get_stacks(&"test_shield_stack"), sc.get_shield(&"test_shield_stack"), sc.get_time_left(&"test_shield_stack")], [1, 30.0, 2.0])
	sc.remove_status(&"test_shield_stack")

	var longer := STATUS_SHIELD.duplicate() as StatusEffect
	longer.stack_rule = StatusEffect.StackRule.REFRESH_LONGER
	sc.apply_status(longer)
	_hit(dummy, 70.0, HitContext.DamageType.TRUE)
	var small := longer.duplicate() as StatusEffect
	small.shield_amount = 20.0
	sc.apply_status(small)
	_check("REFRESH_LONGER keeps the bigger shield (30 left beats a new 20)", sc.get_shield(&"shield"), 30.0)
	small.shield_amount = 90.0
	sc.apply_status(small)
	_check("and takes a bigger new one (90)", sc.get_shield(&"shield"), 90.0)
	sc.remove_status(&"shield")
	var timed := STATUS_SHIELD.duplicate() as StatusEffect
	sc.apply_status(timed, null, 0.0001 * 0.5)
	_check("(a zero-length shield isn't applied)", sc.has_status(&"shield"), false)
	dummy.queue_free()


func _test_c10_hit_still_lands() -> void:
	_section("C10: an absorbed hit still lands (knockback, statuses, life steal, i-frames)")
	await _reset_knight()
	await _hitstop_over()
	var dummy := _dummy_at(Vector2(50, 0))
	dummy.status_component.apply_status(STATUS_SHIELD, null, 10.0)
	knight.stats_component.add_modifier(StatModifier.create(&"life_steal", FLAT, 0.5, &"test_c10"))
	knight.health.take_damage(200.0)
	var hp := knight.health.current
	var start := dummy.global_position
	var hits := await _record_hits(func() -> void:
		await _reset_knight_in_place()
		knight.attack.try_swing(Vector2.RIGHT)
		await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 20)
		await _frames(8))
	_check("swing 1 into the shield: 64 absorbed, no health lost", hits.map(func(h: HitContext) -> Array: return [h.absorbed, h.health_lost]), [[64.0, 0.0]])
	_check("life steal still counts the absorbed damage: +32", knight.health.current - hp, 32.0)
	_check("its knockback still pushes the dummy", dummy.global_position.distance_to(start) > 3.0, true)
	knight.stats_component.remove_modifiers_from(&"test_c10")
	var ctx := HitContext.new()
	ctx.source = knight
	ctx.target = dummy
	ctx.base_damage = 5.0
	ctx.statuses = [STATUS_SLOW] as Array[StatusEffect]
	HitPipeline.resolve(ctx)
	_check("a fully absorbed hit still applies its statuses", [ctx.absorbed, dummy.status_component.has_status(&"slow")], [5.0, true])
	var burn := _make_status(&"test_burn", [&"dot", &"burning"], 0.6)
	burn.tick_interval = 0.5
	burn.tick_damage = 10.0
	var before := _numbers()
	dummy.status_component.apply_status(burn, knight)
	var shield_before := dummy.status_component.get_shield(&"shield")
	await _frames(32)
	var small := _numbers().filter(func(n: Label) -> bool: return not before.has(n) and n.kind == NUMBER_SCRIPT.Kind.SHIELD)
	_check("a DoT tick is absorbed too, with a small shield number",
		[shield_before - dummy.status_component.get_shield(&"shield"), small.map(func(n: Label) -> int: return n.font_size)], [10.0, [8]])
	dummy.queue_free()

	await _wait_until(func() -> bool: return not knight.is_invulnerable(), 60)
	knight.health.heal(10000.0)
	knight.status_component.apply_status(STATUS_SHIELD)
	var slime := _dummy_at(Vector2(0, 200))
	var enemy_hit := knight.make_hit_context(22.0, slime)
	enemy_hit.add_tag(&"basic_attack")
	knight.on_hit(enemy_hit)
	_check("a slime hit on a shielded Knight: no health lost, 78 shield left, post-hit i-frames still start",
		[knight.health.current == knight.health.max_health, knight.status_component.get_shield(&"shield"), knight.has_invulnerability(Unit.HIT_IFRAMES_ID)], [true, 78.0, true])
	knight.status_component.remove_status(&"shield")
	slime.queue_free()
	await _wait_until(func() -> bool: return not knight.is_invulnerable(), 60)
	await _hitstop_over()


# --- C11: reaction rules -----------------------------------------------------------

const SHATTER: ReactionRule = preload("res://data/reactions/reaction_shatter.tres")
const HIT := ReactionRule.Trigger.HIT


func _test_reactions() -> void:
	_test_c11_data()
	await _test_c11_shatter()
	_test_c11_roles_and_targets()
	_test_c11_died_and_status()
	_test_c11_tags_and_chance()
	_test_c11_chains()
	await _test_c11_effects()


func _test_c11_data() -> void:
	_section("C11: reaction data")
	var effect := SHATTER.effects[0] as DealDamageGameplayEffect
	_check("reaction_shatter: HIT, needs a stunned target, a 30 MAGIC proc tagged shatter, the attacker's rule, no chaining",
		[SHATTER.id, SHATTER.trigger, SHATTER.required_unit_tags, effect.base_damage, effect.damage_type, effect.tags, SHATTER.owner_role, SHATTER.effect_target, SHATTER.chain_limit],
		[&"shatter", HIT, [&"stun"], 30.0, HitContext.DamageType.MAGIC, [&"shatter"], ReactionRule.OwnerRole.SOURCE, ReactionRule.EffectTarget.AFFECTED, 1])
	_check("no world rules yet (data/reactions/world/ is empty); the Knight has no rules outside the sandbox",
		[Reactions.get_world_rules().size(), knight.get_reaction_rules().size()], [0, 0])


func _test_c11_shatter() -> void:
	_section("C11: Shatter as a unit rule on the Knight")
	await _reset_knight()
	await _hitstop_over()
	var dummy := _tough_dummy_at(Vector2(50, 0))
	await _frames(1)
	knight.add_reaction_rule(SHATTER, &"test_c11")
	var hits := await _record_hits(func() -> void: await _swing_once())
	_check("a swing on a dummy that isn't stunned: just the 64", hits.map(func(h: HitContext) -> float: return h.taken_damage), [64.0])
	dummy.apply_stun(5.0)
	hits = await _record_hits(func() -> void: await _swing_once())
	# The proc resolves inside the swing's unit_hit (Reactions listens first), so
	# this recorder hears it first; compare in a fixed order.
	var events := hits.map(func(h: HitContext) -> Array: return [h.taken_damage, h.damage_type, h.has_tag(&"shatter"), h.has_tag(&"proc")])
	events.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	_check("on a stunned dummy: the 64 swing and a 30 MAGIC proc tagged shatter (and nothing more)",
		events, [[64.0, HitContext.DamageType.PHYSICAL, false, false], [30.0, HitContext.DamageType.MAGIC, true, true]])
	_check("the proc's source is the Knight", hits.filter(func(h: HitContext) -> bool: return h.has_tag(&"shatter") and h.source == knight).size(), 1)
	dummy.status_component.remove_status(&"stun")
	hits = await _record_hits(func() -> void: await _cast(&"r", dummy.global_position, dummy))
	_check("Judgement's own hit doesn't shatter (the stun comes after the hit)", hits.size(), 1)
	hits = await _record_hits(func() -> void: _resolve_cleave(dummy))
	var amounts := hits.map(func(h: HitContext) -> float: return h.taken_damage)
	amounts.sort()
	_check("the next hit does: Cleave 124.8 + 30", amounts, [30.0, 124.8])
	knight.remove_reaction_rules_from(&"test_c11")
	hits = await _record_hits(func() -> void: _resolve_cleave(dummy))
	_check("rule removed: no shatter", hits.size(), 1)
	dummy.queue_free()
	await _hitstop_over()


func _test_c11_roles_and_targets() -> void:
	_section("C11: owner roles and effect targets")
	var dummy := _spawn_dummy()
	dummy.health.take_damage(100.0)
	var when_hit := _make_rule(HIT, [_heal_effect(10.0)])
	when_hit.owner_role = ReactionRule.OwnerRole.AFFECTED
	dummy.add_reaction_rule(when_hit, &"test_c11")
	var hp := dummy.health.current
	_hit(dummy, 20.0, HitContext.DamageType.TRUE)
	_check("a dummy's 'when I'm hit, heal 10' rule: -20 +10", dummy.health.current - hp, -10.0)
	dummy.remove_reaction_rules_from(&"test_c11")
	var as_source := _make_rule(HIT, [_heal_effect(10.0)])
	dummy.add_reaction_rule(as_source, &"test_c11")
	hp = dummy.health.current
	_hit(dummy, 20.0, HitContext.DamageType.TRUE)
	_check("an owner_role SOURCE rule doesn't fire when its owner is the one hit", dummy.health.current - hp, -20.0)
	dummy.remove_reaction_rules_from(&"test_c11")
	var heal_me := _make_rule(HIT, [_heal_effect(15.0)])
	heal_me.effect_target = ReactionRule.EffectTarget.OTHER
	knight.add_reaction_rule(heal_me, &"test_c11")
	knight.health.take_damage(100.0)
	var knight_hp := knight.health.current
	hp = dummy.health.current
	_hit(dummy, 20.0, HitContext.DamageType.TRUE)
	_check("the Knight's 'when I hit, heal me 15' (effect_target OTHER): the Knight +15, the dummy -20",
		[knight.health.current - knight_hp, dummy.health.current - hp], [15.0, -20.0])
	knight.remove_reaction_rules_from(&"test_c11")
	knight.health.heal(10000.0)
	dummy.queue_free()


func _test_c11_died_and_status() -> void:
	_section("C11: UNIT_DIED and STATUS_APPLIED")
	var on_kill := _make_rule(ReactionRule.Trigger.UNIT_DIED, [_heal_effect(20.0)])
	on_kill.effect_target = ReactionRule.EffectTarget.OTHER
	knight.add_reaction_rule(on_kill, &"test_c11")
	knight.health.take_damage(100.0)
	var hp := knight.health.current
	var victim := _spawn_dummy()
	_hit(victim, 10000.0, HitContext.DamageType.TRUE)
	_check("'on kill, heal me 20': the killer +20", knight.health.current - hp, 20.0)
	knight.remove_reaction_rules_from(&"test_c11")
	var slowed_death := _make_rule(ReactionRule.Trigger.UNIT_DIED, [_heal_effect(20.0)])
	slowed_death.effect_target = ReactionRule.EffectTarget.OTHER
	slowed_death.required_unit_tags = [&"slow"] as Array[StringName]
	knight.add_reaction_rule(slowed_death, &"test_c11")
	hp = knight.health.current
	var plain := _spawn_dummy()
	_hit(plain, 10000.0, HitContext.DamageType.TRUE)
	var slowed := _spawn_dummy()
	slowed.status_component.apply_status(STATUS_SLOW, knight)
	_hit(slowed, 10000.0, HitContext.DamageType.TRUE)
	_check("'kill a slowed enemy': only the slowed kill counts (its tags from just before the hit, though death clears them)",
		knight.health.current - hp, 20.0)
	knight.remove_reaction_rules_from(&"test_c11")
	knight.health.heal(10000.0)

	var spread := _make_rule(ReactionRule.Trigger.STATUS_APPLIED, [_status_effect(STATUS_SLOW, 0.8)])
	spread.required_status_tags = [&"burning"] as Array[StringName]
	Reactions.add_world_rule(spread, &"test_c11")
	var dummy := _spawn_dummy()
	var burn := _make_status(&"test_burn", [&"dot", &"burning"], 2.0)
	dummy.status_component.apply_status(STATUS_HASTE, knight)
	_check("a world rule 'burning also slows': a haste doesn't set it off", dummy.status_component.has_status(&"slow"), false)
	dummy.status_component.apply_status(burn, knight)
	_check("a burn does: slow for 0.8 s, from the burn's applier",
		[dummy.status_component.has_status(&"slow"), dummy.status_component.get_time_left(&"slow"), dummy.status_component.get_source(&"slow") == knight], [true, 0.8, true])
	Reactions.remove_world_rules_from(&"test_c11")
	_check("world rule removed", Reactions.get_world_rules().size(), 0)
	dummy.queue_free()


func _test_c11_tags_and_chance() -> void:
	_section("C11: hit tags and chance")
	var dummy := _tough_dummy_at(Vector2(0, 300))
	var on_crit := _make_rule(HIT, [_damage_effect(5.0)])
	on_crit.required_hit_tags = [&"crit"] as Array[StringName]
	knight.add_reaction_rule(on_crit, &"test_c11")
	var swing := knight.attack.combo.swings[0]
	var plain := _count_hits(dummy, func() -> void: HitPipeline.resolve(HitPipeline.basic_attack(knight, dummy, swing)))
	knight.stats_component.add_modifier(StatModifier.create(&"crit_chance", FLAT, 1.0, &"test_c11"))
	var crit := _count_hits(dummy, func() -> void: HitPipeline.resolve(HitPipeline.basic_attack(knight, dummy, swing)))
	knight.stats_component.remove_modifiers_from(&"test_c11")
	_check("'on crit': a plain hit 1 event, a crit 2 (the hit + the proc)", [plain, crit], [1, 2])
	knight.remove_reaction_rules_from(&"test_c11")

	var half := _make_rule(HIT, [_damage_effect(5.0)])
	half.chance = 0.5
	knight.add_reaction_rule(half, &"test_c11")
	Reactions.rng.seed = 11
	var fired := 0
	for i in 400:
		dummy.health.heal(100000.0)   # 400 hits would kill it
		fired += _count_hits(dummy, func() -> void: HitPipeline.resolve(HitPipeline.basic_attack(knight, dummy, swing))) - 1
	_report(fired >= 170 and fired <= 230, "chance 0.5: about 200 of 400 hits (%d)" % fired, "got %d" % fired)
	half.chance = 1.0
	knight.abilities.q.proc_coefficient = 0.25
	fired = 0
	for i in 400:
		dummy.health.heal(100000.0)
		fired += _count_hits(dummy, func() -> void: _resolve_cleave(dummy)) - 1
	knight.abilities.q.proc_coefficient = 1.0
	_report(fired >= 70 and fired <= 130, "HIT chance x proc coefficient: 1.0 x 0.25 = about 100 of 400 Cleaves (%d)" % fired, "got %d" % fired)
	dummy.health.heal(100000.0)
	var tick := dummy.make_hit_context(10.0, knight)
	tick.add_tag(&"dot")
	tick.proc_coefficient = 0.0
	_check("a DoT tick (proc coefficient 0) never triggers HIT rules", _count_hits(dummy, func() -> void: dummy.on_hit(tick)), 1)
	knight.remove_reaction_rules_from(&"test_c11")
	dummy.queue_free()


func _test_c11_chains() -> void:
	_section("C11: chain reactions (per-rule chain_limit, capped at 5)")
	var link := _make_status(&"test_link", [&"link"], 5.0)
	link.stack_rule = StatusEffect.StackRule.STACK
	link.max_stacks = 99
	var rule := _make_rule(ReactionRule.Trigger.STATUS_APPLIED, [_status_effect(link, -1.0)])
	rule.required_status_tags = [&"link"] as Array[StringName]
	Reactions.add_world_rule(rule, &"test_c11")
	var results: Array = []
	for limit in [1, 3, 5, 9]:
		rule.chain_limit = limit
		var dummy := _spawn_dummy()
		dummy.status_component.apply_status(link)
		results.append(dummy.status_component.get_stacks(&"test_link"))
		dummy.queue_free()
	_check("a rule that re-applies its own trigger: chain_limit 1 / 3 / 5 / 9 -> 1 + 1 / 3 / 5 / 5 reactions",
		results, [2, 4, 6, 6])
	_check("the chain depth is back to 0 afterwards", Reactions.get_chain_depth(), 0)
	Reactions.remove_world_rules_from(&"test_c11")


func _test_c11_effects() -> void:
	_section("C11: the four GameplayEffects")
	var dummy := _tough_dummy_at(Vector2(0, 360))
	await _frames(1)
	knight.stats_component.add_modifier(StatModifier.create(&"crit_chance", FLAT, 1.0, &"test_c11"))
	var damage := _damage_effect(10.0)
	damage.ad_ratio = 0.5
	damage.tags = [&"shatter"] as Array[StringName]
	var hits := await _record_hits(func() -> void: damage.apply(dummy, knight, null))
	_check("DealDamage 10 + 0.5 AD: 42 MAGIC, tagged proc + shatter, no crit even at 100%",
		hits.map(func(h: HitContext) -> Array: return [h.taken_damage, h.damage_type, h.has_tag(&"proc"), h.has_tag(&"shatter"), h.is_crit]),
		[[42.0, HitContext.DamageType.MAGIC, true, true, false]])
	knight.stats_component.remove_modifiers_from(&"test_c11")
	_status_effect(STATUS_SLOW, 0.5).apply(dummy, knight, null)
	_check("ApplyStatus: slow for 0.5 s from the source",
		[dummy.status_component.get_time_left(&"slow"), dummy.status_component.get_source(&"slow") == knight], [0.5, true])
	dummy.health.take_damage(500.0)
	var hp := dummy.health.current
	var heal := _heal_effect(10.0)
	heal.max_health_ratio = 0.01
	heal.apply(dummy, null, null)
	_check("Heal 10 + 1% max health (5280): +62.8", dummy.health.current - hp, 62.8)
	_place(dummy, knight.global_position + Vector2(60, 0))
	await _frames(1)
	var start := dummy.global_position
	var push := KnockbackGameplayEffect.new()
	push.distance_px = 20.0
	push.duration = 0.1
	push.apply(dummy, knight, null)
	await _frames(12)
	_check_near("Knockback: 20 px straight away from the source", dummy.global_position.x - start.x, 20.0, 1.0)
	dummy.queue_free()


# --- C12: dash-strike -------------------------------------------------------------

func _test_dash_strike() -> void:
	await _test_c12_data_and_hit()
	await _test_c12_window()
	await _test_c12_combo_kept()


func _test_c12_data_and_hit() -> void:
	_section("C12: the Knight's dash-strike swing")
	var ds := knight.attack.combo.dash_strike
	_check("combo_knight.tres dash_strike: 1.5 AD, 16 px step (max 32), heavy, 0.35 s, 80 deg, reach x1.15, 16 px push, no breather",
		[ds != null, ds.ad_ratio, ds.lunge_px, ds.lunge_max_px, ds.feel, ds.duration, ds.arc_deg, ds.reach_multiplier, ds.knockback_px, ds.pause_after],
		[true, 1.5, 16.0, 32.0, HitContext.Feel.HEAVY, 0.35, 80.0, 1.15, 16.0, 0.0])
	_check("PlayerInput's dash_strike_window is 0.15 s", knight.player_input.dash_strike_window, 0.15)
	await _reset_knight()
	await _hitstop_over()
	var from := knight.global_position
	knight.attack.try_swing(Vector2.RIGHT, true)
	_check("a dash-strike: index -1, is_dash_strike()", [knight.attack.get_combo_index(), knight.attack.is_dash_strike()], [-1, true])
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 60)
	_check_near("in the air it steps 16 px", knight.global_position.x - from.x, 16.0, 0.5)
	await _reset_knight()
	await _hitstop_over()
	var dummy := _tough_dummy_at(Vector2(60, 0))
	await _frames(1)
	var landed_before := _landed.size()
	# The hitstop is read as the swing lands (the hit's own frame), like C3:
	# read later, the real frames since the hit would be subtracted from it.
	_hitstop_at_hit = -1.0
	var read_hitstop := func(_index: int, _targets: Array[Unit]) -> void:
		_hitstop_at_hit = GameFeel.get_hitstop_left()
	knight.attack.swing_landed.connect(read_hitstop)
	var hits := await _record_hits(func() -> void:
		knight.attack.try_swing(Vector2.RIGHT, true)
		await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 20))
	knight.attack.swing_landed.disconnect(read_hitstop)
	_check("it hits for 64 x 1.5 = 96, tagged basic_attack + dash_strike, heavy feel",
		hits.map(func(h: HitContext) -> Array: return [h.taken_damage, h.has_tag(&"basic_attack"), h.has_tag(&"dash_strike"), h.feel]),
		[[96.0, true, true, HitContext.Feel.HEAVY]])
	_check("swing_landed reports index -1", _landed.size() > landed_before and _landed[-1][1] == -1, true)
	_check_near("heavy feel: 0.06 s hitstop (read as the swing lands)", _hitstop_at_hit, 0.06, 0.005)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 60)
	var normal := await _record_hits(func() -> void:
		await _reset_knight_in_place()
		knight.attack.try_swing(Vector2.RIGHT)
		await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 20))
	_check("a normal swing isn't tagged dash_strike", normal.map(func(h: HitContext) -> bool: return h.has_tag(&"dash_strike")), [false])
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 60)
	dummy.queue_free()
	await _hitstop_over()


func _test_c12_window() -> void:
	_section("C12: the 0.15 s window (through PlayerInput)")
	var results: Array = []
	for wait_frames in [-1, 8, 14]:   # -1 = a click during the dash
		await _reset_knight()
		await _hitstop_over()
		await _wait_until(func() -> bool: return knight.dash.can_dash(), 120)
		var flags: Array = []
		var record := func(dash_strike: bool) -> void: flags.append(dash_strike)
		knight.player_input.attack_pressed.connect(record)
		knight.dash.try_dash(Vector2.RIGHT)
		if wait_frames < 0:
			await _frames(2)
			knight.player_input.buffer_action(&"attack")
			await _wait_until(func() -> bool: return not flags.is_empty(), 60)
		else:
			await _wait_until(func() -> bool: return not knight.dash.is_dashing(), 60)
			await _frames(wait_frames)
			knight.player_input.buffer_action(&"attack")
			await _wait_until(func() -> bool: return not flags.is_empty(), 30)
		knight.player_input.attack_pressed.disconnect(record)
		results.append([flags, knight.attack.is_dash_strike()])
		await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 60)
	_check("a click during the dash fires as it ends: a dash-strike", results[0], [[true], true])
	_check("8 frames (0.13 s) after the dash: a dash-strike", results[1], [[true], true])
	_check("14 frames (0.23 s) after: a normal swing", results[2], [[false], false])


func _test_c12_combo_kept() -> void:
	_section("C12: the dash-strike doesn't count as a combo hit")
	await _reset_knight()
	await _hitstop_over()
	var dummy := _tough_dummy_at(Vector2(50, 0))
	await _frames(1)
	var damages: Array = []
	var record := func(ctx: HitContext) -> void:
		if ctx.target == dummy:
			damages.append(snappedf(ctx.taken_damage, 0.1))
	Events.unit_hit.connect(record)
	for dash_strike in [false, true, false, true, false]:
		_place(dummy, knight.global_position + Vector2(50, 0))
		knight.attack.try_swing(Vector2.RIGHT, dash_strike)
		await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 60)
		await _wait_until(func() -> bool: return not knight.attack.is_in_pause(), 30)
		await _hitstop_over()
	Events.unit_hit.disconnect(record)
	_check("swing 1, dash-strike, swing 2, dash-strike, swing 3 (the finisher): 64 / 96 / 64 / 96 / 102.4",
		damages, [64.0, 96.0, 64.0, 96.0, 102.4])
	await _reset_knight()
	knight.attack.try_swing(Vector2.RIGHT, true)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 60)
	_check("after the combo has reset, a dash-strike leaves it at swing 1", knight.attack.get_combo_index(), 0)
	await _reset_knight()
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 60)
	knight.attack.try_swing(Vector2.RIGHT, true)
	await _frames(2)
	knight.attack.cancel_swing()
	_check("a cancelled dash-strike resets the combo, like any cancelled swing", knight.attack.get_combo_index(), 0)
	dummy.queue_free()
	await _hitstop_over()


# --- A swing counts once its hit has landed ------------------------------------------

func _test_cancels_after_hit() -> void:
	_section("A swing counts once its hit has landed (player cancels keep the combo)")
	var dummy := _tough_dummy_at(Vector2(50, 0))
	var landed_index := func() -> int: return _landed[-1][1] if not _landed.is_empty() else -99

	# Hit, dash in the recovery, click: swing 2.
	await _reset_knight()
	await _hitstop_over()
	_place(dummy, knight.global_position + Vector2(50, 0))
	await _frames(1)
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 20)
	knight.dash.try_dash(Vector2.DOWN)
	await _wait_until(func() -> bool: return not knight.dash.is_dashing(), 60)
	_place(dummy, knight.global_position + Vector2(50, 0))
	await _hitstop_over()
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 20)
	_check("hit, dash in the recovery, click: swing 2 comes out", landed_index.call(), 1)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 60)

	# Dash in the windup, click: swing 1.
	await _reset_knight()
	await _hitstop_over()
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 20)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 60)
	await _wait_until(func() -> bool: return knight.dash.can_dash(), 120)
	knight.attack.try_swing(Vector2.RIGHT)   # swing 2, cut in its windup
	await _frames(2)
	knight.dash.try_dash(Vector2.DOWN)
	await _wait_until(func() -> bool: return not knight.dash.is_dashing(), 60)
	_place(dummy, knight.global_position + Vector2(50, 0))
	await _hitstop_over()
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 20)
	_check("dash in the windup, click: swing 1 (no hit, the combo resets)", landed_index.call(), 0)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 60)

	# The reset timer counts from the dash.
	await _reset_knight()
	await _hitstop_over()
	_place(dummy, knight.global_position + Vector2(50, 0))
	await _frames(1)
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 20)
	knight.dash.try_dash(Vector2.DOWN)
	_check("right after the dash: swing 2 is next, the reset timer is full (0.6 s)", knight.attack.get_combo_index(), 1)
	await _frames(45)   # 0.75 s > combo_reset_time
	_check("0.75 s after the dash: back to swing 1", knight.attack.get_combo_index(), 0)

	# The finisher dashed out of after its hit: breather, then swing 1.
	await _reset_knight()
	await _hitstop_over()
	for i in 2:
		_place(dummy, knight.global_position + Vector2(50, 0))
		knight.attack.try_swing(Vector2.RIGHT)
		await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 60)
		await _hitstop_over()
	await _wait_until(func() -> bool: return knight.dash.can_dash(), 120)
	_place(dummy, knight.global_position + Vector2(50, 0))
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 20)
	_check("(the finisher landed)", landed_index.call(), 2)
	knight.dash.try_dash(Vector2.DOWN)
	_check("the finisher dashed out of after its hit: its breather still runs, swing 1 is next",
		[knight.attack.is_in_pause(), knight.attack.get_combo_index()], [true, 0])
	await _hitstop_over()

	# Out of a landed dash-strike: the swing it interrupted.
	await _reset_knight()
	await _hitstop_over()
	_place(dummy, knight.global_position + Vector2(50, 0))
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 60)
	await _wait_until(func() -> bool: return knight.dash.can_dash(), 120)
	_place(dummy, knight.global_position + Vector2(60, 0))
	knight.attack.try_swing(Vector2.RIGHT, true)
	await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 20)
	knight.dash.try_dash(Vector2.DOWN)
	_check("dashing out of a landed dash-strike: the swing it interrupted (swing 2) is next", knight.attack.get_combo_index(), 1)
	await _hitstop_over()

	# Q cuts the recovery (AFTER_HIT): swing 2 after the cast.
	await _reset_knight()
	await _hitstop_over()
	await _wait_until(func() -> bool: return knight.abilities.is_ready(&"q"), 300)
	_place(dummy, knight.global_position + Vector2(50, 0))
	await _frames(1)
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 20)
	knight.request_cast(&"q")
	_check("(Q cut the recovery)", [knight.abilities.casting, knight.attack.is_swinging()], [true, false])
	await _wait_until(func() -> bool: return not knight.abilities.casting, 30)
	await _hitstop_over()
	_place(dummy, knight.global_position + Vector2(50, 0))
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 20)
	_check("swing 1 hits, Q cuts its recovery, a click: swing 2", landed_index.call(), 1)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 60)

	# An ANYTIME cast in the windup: the combo resets.
	await _reset_knight()
	await _hitstop_over()
	await _wait_until(func() -> bool: return knight.abilities.is_ready(&"q"), 300)
	knight.abilities.q.cancels_swing = Ability.SwingCancel.ANYTIME
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 20)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 60)
	knight.attack.try_swing(Vector2.RIGHT)   # swing 2
	await _frames(2)
	knight.request_cast(&"q")
	_check("an ANYTIME cast in swing 2's windup: the combo resets to swing 1",
		[knight.attack.is_swinging(), knight.attack.get_combo_index()], [false, 0])
	knight.abilities.q.cancels_swing = Ability.SwingCancel.AFTER_HIT
	await _wait_until(func() -> bool: return not knight.abilities.casting, 30)
	await _hitstop_over()

	# Forced interruptions still reset.
	await _reset_knight()
	await _hitstop_over()
	_place(dummy, knight.global_position + Vector2(50, 0))
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 20)
	knight.apply_stun(0.1)
	_check("a stun after the hit still resets the combo", [knight.attack.is_swinging(), knight.attack.get_combo_index()], [false, 0])
	await _frames(10)
	dummy.queue_free()
	await _hitstop_over()


func _make_rule(trigger: ReactionRule.Trigger, effects: Array) -> ReactionRule:
	var rule := ReactionRule.new()
	rule.trigger = trigger
	var typed: Array[GameplayEffect] = []
	for e in effects:
		typed.append(e)
	rule.effects = typed
	return rule


func _heal_effect(amount: float) -> HealGameplayEffect:
	var e := HealGameplayEffect.new()
	e.amount = amount
	return e


func _damage_effect(amount: float) -> DealDamageGameplayEffect:
	var e := DealDamageGameplayEffect.new()
	e.base_damage = amount
	return e


func _status_effect(status: StatusEffect, duration: float) -> ApplyStatusGameplayEffect:
	var e := ApplyStatusGameplayEffect.new()
	e.status = status
	e.duration = duration
	return e


## How many Events.unit_hit on `target` during `action` (not awaited).
func _count_hits(target: Node, action: Callable) -> int:
	var count := [0]
	var record := func(ctx: HitContext) -> void:
		if ctx.target == target:
			count[0] += 1
	Events.unit_hit.connect(record)
	action.call()
	Events.unit_hit.disconnect(record)
	return count[0]


## CHAMPIONS K2's toolkit pieces on statuses (Korsavil's Blades and Demise use
## them; ABILITIES.md, Later toolkit pieces): the STACK_SHARED rule, a DoT
## tick table by stack count, and StatScalings held by a status, following
## another status's stack count (`self_status_stacks`).
func _test_k2_status_pieces() -> void:
	_section("K2: STACK_SHARED (one timer for every stack)")
	var dummy := _spawn_dummy()
	var sc := dummy.status_component
	var shared := _make_status(&"test_shared", [&"debuff"], 1.0)
	shared.stack_rule = StatusEffect.StackRule.STACK_SHARED
	shared.max_stacks = 3
	shared.modifiers = [StatModifier.create(&"armor", FLAT, 10.0, &"")] as Array[StatModifier]
	sc.apply_status(shared)
	await _frames(30)
	sc.apply_status(shared)
	_check("a second application half a second later: 2 stacks, both back to 1 s, +10 armor each",
		[sc.get_stacks(&"test_shared"), sc.get_time_left(&"test_shared"), dummy.stats_component.get_stat(&"armor")], [2, 1.0, 20.0])
	sc.apply_status(shared)
	sc.apply_status(shared, null, 0.5)
	_check("at max 3 a 4th only restarts the shared timer (with its own duration)", [sc.get_stacks(&"test_shared"), sc.get_time_left(&"test_shared")], [3, 0.5])
	var seen: Array = []
	while sc.has_status(&"test_shared"):
		seen.append(sc.get_stacks(&"test_shared"))
		await _frames(1)
	_check("they end together: 3 stacks until the frame they all go (no one-by-one)", [seen.min(), seen.max(), dummy.stats_component.get_stat(&"armor")], [3, 3, 0.0])

	_section("K2: a DoT's tick by stack count (tick_by_stacks)")
	var tough := _tough_dummy_at(Vector2(0, 400))
	await _frames(1)
	var tiers := _make_status(&"test_tiers", [&"debuff"], 3.0)
	tiers.stack_rule = StatusEffect.StackRule.STACK_SHARED
	tiers.max_stacks = 5
	tiers.tick_interval = 0.5
	tiers.tick_damage = 10.0
	tiers.tick_by_stacks = [0.0, 0.5, 2.0] as Array[float]
	var ticks: Array = []
	var record := func(ctx: HitContext) -> void:
		if ctx.target == tough and ctx.has_tag(&"dot"):
			ticks.append(ctx.taken_damage)
	Events.unit_hit.connect(record)
	tough.status_component.apply_status(tiers)
	await _frames(32)
	_check("1 stack (multiplier 0): no tick at all (no hit, no number)", ticks, [])
	tough.status_component.apply_status(tiers)
	await _frames(30)
	tough.status_component.apply_status(tiers)
	await _frames(30)
	tough.status_component.apply_status(tiers)
	await _frames(30)
	Events.unit_hit.disconnect(record)
	_check("2 stacks x 0.5 = 5; 3 stacks x 2 = 20; 4 stacks past the table: the last entry, 20", ticks, [5.0, 20.0, 20.0])
	tough.status_component.remove_status(&"test_tiers")

	_section("K2: StatScalings on a status, following another status's stacks")
	var count := _make_status(&"test_count", [&"test_count"], -1.0)
	count.stack_rule = StatusEffect.StackRule.STACK
	count.max_stacks = 6
	var holder := _make_status(&"test_holder", [&"buff"], -1.0)
	holder.stack_rule = StatusEffect.StackRule.STACK
	holder.max_stacks = 3
	holder.modifiers = [StatModifier.create(&"magic_resist", FLAT, 5.0, &"")] as Array[StatModifier]
	var scaling := StatScaling.new()
	scaling.modifier = StatModifier.create(&"armor", FLAT, 40.0, &"")
	scaling.input = &"self_status_stacks"
	scaling.status_tag = &"test_count"
	scaling.max_stacks = 4
	holder.stat_scalings = [scaling] as Array[Resource]
	var stats := dummy.stats_component
	sc.apply_status(holder)
	_check("the holder on, no counted stacks: +0 armor (its copy under status_test_holder)", [stats.get_stat(&"armor"), stats.get_modifiers_from(&"status_test_holder").size()], [0.0, 2])
	sc.apply_status(count)
	sc.apply_status(count)
	await _frames(1)
	_check("2 of 4 counted stacks: +20 armor (refreshed after the status change)", stats.get_stat(&"armor"), 20.0)
	sc.apply_status(holder)
	await _frames(1)
	_check("a new stack of the holder itself keeps the scaling (+10 MR from its own modifiers, +20 armor)",
		[stats.get_stat(&"magic_resist"), stats.get_stat(&"armor")], [10.0, 20.0])
	for i in 4:
		sc.apply_status(count)
	await _frames(1)
	_check("6 counted stacks: capped at the full +40", stats.get_stat(&"armor"), 40.0)
	sc.remove_status(&"test_count")
	await _frames(1)
	_check("the counted status gone: +0 armor, the holder's own +10 MR stays", [stats.get_stat(&"armor"), stats.get_stat(&"magic_resist")], [0.0, 10.0])
	sc.apply_status(count)
	sc.remove_status(&"test_holder")
	await _frames(1)
	_check("the holder gone: nothing left under its source, armor and MR back to 0",
		[stats.get_modifiers_from(&"status_test_holder").size(), stats.get_stat(&"armor"), stats.get_stat(&"magic_resist"), dummy.get_stat_scalings().size()], [0, 0.0, 0.0, 0])
	sc.remove_status(&"test_count")
	tough.queue_free()
	dummy.queue_free()
	await _frames(1)


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
	@warning_ignore("redundant_await")   # an ability's own execute() may wait
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
# --- 3D pivot P9: the melee rule, the Uppercut ----------------------------------------

const STATUS_ELEVATED: StatusEffect = preload("res://data/statuses/status_elevated.tres")
const UPPERCUT: Ability = preload("res://data/abilities/test_w_uppercut.tres")


func _test_perch_melee_rule() -> void:
	_section("P9: the melee rule (a perched, elevated target; 3D.md, Terrain and height 2)")
	var lunge: Ability = load("res://data/abilities/knight_e_lunge.tres")
	var judgement: Ability = load("res://data/abilities/knight_r_judgement.tres")
	var wave: Ability = load("res://data/abilities/knight_q_cleave_wave.tres")
	_check("Cleave and Lunge are melee; Judgement and Cleave Wave aren't",
		[&"melee" in CLEAVE.tags, &"melee" in lunge.tags, &"melee" in judgement.tags, &"melee" in wave.tags], [true, true, false, false])
	await _fresh_knight()   # C2's last check left the Knight dead
	await _reset_knight()
	await _hitstop_over()
	var dummy := _dummy_at(Vector2(50, 0))
	await _frames(1)
	_check("the Knight's combo swings are melee hits (a MELEE combo)",
		HitPipeline.basic_attack(knight, dummy, knight.attack.combo.swings[0]).has_tag(&"melee"), true)
	dummy.status_component.apply_status(STATUS_ELEVATED)
	_check("can_reach(): a melee hit can't reach an elevated target from below",
		AbilityUtil.can_reach(knight, dummy, [&"melee"] as Array[StringName]), false)
	_check("a hit that isn't melee can (Judgement, Cleave Wave)", AbilityUtil.can_reach(knight, dummy, [&"ability"] as Array[StringName]), true)
	var before := dummy.health.current
	var blocked := HitPipeline.resolve(HitPipeline.basic_attack(knight, dummy, knight.attack.combo.swings[0]))
	_check("HitPipeline.resolve(), the last guard, blocks it: no damage", [blocked.blocked, dummy.health.current], [true, before])
	_check("the combo's aim help doesn't snap to it", knight.attack._find_assist_target(Vector2.RIGHT, knight.attack.get_swing_reach_px(knight.attack.combo.swings[0])) != dummy, true)
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 30)
	_check("a real swing from below doesn't land", dummy.health.current, before)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 60)
	await _hitstop_over()
	_hit(dummy, 30.0, HitContext.DamageType.MAGIC)
	_check("a hit without the melee tag lands", dummy.health.current < before, true)
	knight.status_component.apply_status(STATUS_ELEVATED)
	_check("from the perch (the attacker elevated too) a melee hit reaches", AbilityUtil.can_reach(knight, dummy, [&"melee"] as Array[StringName]), true)
	before = dummy.health.current
	await _frames(40)
	knight.attack.try_swing(Vector2.RIGHT)
	await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 30)
	_check("and a real swing lands", dummy.health.current < before, true)
	knight.status_component.remove_status(&"elevated")
	dummy.status_component.remove_status(&"elevated")
	dummy.queue_free()


## A new Knight in place of the old one, as _ready() makes it.
func _fresh_knight() -> void:
	if is_instance_valid(knight):
		knight.queue_free()
	await get_tree().process_frame
	knight = PLAYER_SCENE.instantiate()
	add_child(knight)
	await get_tree().physics_frame
	_zero_knight_extras()


func _test_uppercut() -> void:
	_section("P9: the test Uppercut (a knock-back-and-up; 3D.md, Airborne)")
	await _reset_knight()
	await _hitstop_over()
	var original_w := knight.abilities.w
	knight.abilities.w = UPPERCUT
	var dummy := _dummy_at(Vector2(40, 0))
	await _frames(1)
	var start := dummy.global_position
	knight.cast_ability(&"w", dummy.global_position)
	var left := 0.0
	for i in 40:
		await get_tree().physics_frame
		if dummy.status_component.has_status(&"airborne"):
			left = dummy.status_component.get_time_left(&"airborne")
			break
	_check_near("it knocks the dummy up for its 0.75 s", left, 0.75, 0.04)
	_check("airborne: a cc status that blocks moving, attacking, casting and dashing",
		[dummy.status_component.has_tag(&"cc"), dummy.is_stunned(), dummy.movement.can_move()], [true, false, false])
	await _frames(30)
	_check_near("and back 2 m (64 px), away from the Knight", dummy.global_position.x - start.x, 64.0, 3.0)
	await _wait_until(func() -> bool: return not dummy.status_component.has_status(&"airborne"), 60)
	_check("it lands when the status ends (0.75 s)", dummy.movement.is_airborne(), false)
	knight.abilities.w = original_w
	dummy.queue_free()


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
