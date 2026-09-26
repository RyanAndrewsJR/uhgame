extends Node2D
## COMBAT.md step C1 test: open res://scenes/tests/combat_test.tscn and press F6.
## Spawns the real player.tscn and passive slimes (training dummies) and
## runs hits through the hit pipeline: mitigation for all three damage types
## at 0 and 100 armor/magic_resist, stat scaling, the take_damage() and
## Hurtbox wrappers, i-frames, knockback, kills and the Events signals.
## Prints PASS/FAIL per check, then a total. Run headless and it quits with
## the number of failures as the exit code.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const SLIME_SCENE: PackedScene = preload("res://scenes/enemies/slime.tscn")
const CLEAVE: Ability = preload("res://data/abilities/knight_q_cleave.tres")
const FLAT := StatModifier.Type.FLAT

var knight: Player

var _next_dummy_y: float = 0.0
var _passed: int = 0
var _failed: int = 0
var _hits: Array[HitContext] = []
var _damaged: Array[HitContext] = []
var _deaths: Array = []   # [unit, ctx]


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
