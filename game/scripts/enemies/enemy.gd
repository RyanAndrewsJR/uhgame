class_name Enemy
extends Unit
## Basic monster AI: wanders, aggros on sight (or when hit), then chases and
## auto-attacks with the same AutoAttackComponent the player uses.
## Tune stats in its UnitStats resource; tune behaviour here.
## ENEMIES_AI AI1: an enemy with `data` (EnemyData) loads it when ready
## (_apply_enemy_data(): its stats, abilities, twist, look, tenacity by rank)
## and, when its rank has one, gets a brain (EnemyBrain) that drives it while
## it's aggroed: the cast loop and the chase below stand down. Noticing the
## player, wandering and the leash stay this script's (AI2 replaces the leash
## for packs). An enemy with no data plays exactly as before.

enum AI { IDLE, WANDER, AGGRO }

## The tells' capsule looks when neither the enemy's data nor its behavior
## names a pose set (ENEMIES_AI.md, Tells).
const DEFAULT_POSE_SET_PATH := "res://data/pose_sets/pose_set_default.tres"
## The tenacity an elite or a boss gets at spawn goes under this source id.
const RANK_SOURCE_ID := &"enemy_rank"

## Aggro range in LoL units (edge to edge).
@export var detect_range: float = 450.0
## Stop chasing once the target is this far away (LoL units).
@export var leash_range: float = 800.0
@export var wander_distance: float = 60.0
## Training dummy: never wanders, aggros or attacks, even when hit. It can
## still be damaged, knocked back, stunned and killed.
@export var passive: bool = false
## What kind of enemy this is (ENEMIES_AI.md, EnemyData; AI1): loaded when
## it's ready, in place of the scene's own stats, abilities and look. null =
## exactly today's behavior.
@export var data: EnemyData
## The naive cast loop (_try_cast_ability(), COMBAT C5): the first ready
## ability in range each tick. Off = this enemy only chases and attacks. An
## enemy whose brain runs never uses it (ENEMIES_AI.md, The brain); it's
## deleted after the milestone AI-M, with Ryan's OK.
@export var naive_casting: bool = true
## Off: no brain even with data whose rank has one (the old routine and the
## naive cast loop; the sandbox's tuning panel switches it).
@export var brain_enabled: bool = true

@onready var sight: RayCast2D = $Sight

var ai: AI = AI.IDLE
var _ai_timer: float = 0.0
var _home: Vector2
var _player: Unit
var _chase_repath: float = 0.0   # chasing an untargetable player (AB10)
var _brain: EnemyBrain
static var _default_pose_set: PoseSet


func _ready() -> void:
	team = Team.ENEMY
	if data != null:
		_apply_enemy_data_base()
	super._ready()
	add_to_group("enemies")
	_home = global_position
	damaged.connect(_on_damaged)
	if data != null:
		_apply_enemy_data()
	_enter_idle()


## Before the Unit sets itself up: the stats and the look its view is built from.
func _apply_enemy_data_base() -> void:
	if data.stats != null:
		stats = data.stats
	if data.model_scene != null:
		model_scene = data.model_scene
	model_color = data.model_color
	detect_range = data.detect_range


## After: its abilities (those of the run's difficulty tier), its twist, its
## rank's tenacity, and its brain when its rank has one (ENEMIES_AI.md,
## Enemy). The scene needs an AbilityComponent for abilities.
func _apply_enemy_data() -> void:
	var by_slot := data.get_abilities_at(Brains.difficulty_tier)
	if not by_slot.is_empty():
		if abilities == null:
			push_warning("%s: EnemyData '%s' has abilities but the scene has no AbilityComponent" % [name, data.id])
		else:
			for slot: StringName in by_slot:
				abilities.set(slot, by_slot[slot])
	if data.twist != null:
		data.twist.apply_to(self, data.get_source_id())
	var rules := get_rank_rules()
	if rules != null and rules.tenacity > 0.0:
		stats_component.add_modifier(StatModifier.create(&"tenacity", StatModifier.Type.FLAT, rules.tenacity, RANK_SOURCE_ID))
	if brain_enabled:
		_add_brain()


func _add_brain() -> void:
	var rules := get_rank_rules()
	if data == null or data.behavior == null or rules == null or not rules.has_brain or _brain != null:
		return
	_brain = EnemyBrain.new()
	_brain.setup(data, rules)
	add_child(_brain)
	if ai == AI.AGGRO:
		Brains.wake(_brain)


## Its rank's rules (EnemyAITable), or null without data.
func get_rank_rules() -> RankRules:
	return Brains.table.get_rank_rules(data.rank) if data != null else null


## Its brain, or null (no data, fodder, or switched off).
func get_brain() -> EnemyBrain:
	return _brain


## Switches its brain on or off while it plays (the sandbox's tuning panel).
## Off, it plays the old routine: the chase, the attack and the naive cast loop.
func set_brain_enabled(on: bool) -> void:
	brain_enabled = on
	if on:
		_add_brain()
		return
	if _brain != null:
		_brain.queue_free()
		remove_child(_brain)
		_brain = null
		if ai == AI.AGGRO and is_alive() and is_instance_valid(_player):
			attack.attack(_player)


## True while its brain drives it: aggroed, alive, not a training dummy.
func is_brain_active() -> bool:
	return _brain != null and ai == AI.AGGRO and is_alive() and not passive


## Who its brain fights: the player, as the old routine (AI2 builds the
## target pick: nearest by threat, sticky, taunt, stealth).
func get_brain_target() -> Unit:
	if _player == null or not is_instance_valid(_player) or not _player.is_alive():
		return null
	return _player


## The pose its brain shows (its tell; &"" = none): the view reads it.
func get_pose() -> StringName:
	return _brain.get_pose() if is_brain_active() else &""


func get_pose_progress() -> float:
	return _brain.get_pose_progress() if is_brain_active() else 0.0


## Its tells' looks: its data's set, else its behavior's, else the default.
func get_pose_set() -> PoseSet:
	if data != null and data.pose_set != null:
		return data.pose_set
	if data != null and data.behavior != null and data.behavior.pose_set != null:
		return data.behavior.pose_set
	if _default_pose_set == null:
		_default_pose_set = load(DEFAULT_POSE_SET_PATH)
	return _default_pose_set


## Where it faces while its brain runs (its target); Vector2.INF = the view
## faces its walk, as before.
func get_face_point() -> Vector2:
	return _brain.get_face_point() if is_brain_active() else Vector2.INF


func _physics_process(delta: float) -> void:
	if not is_alive() or passive:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Unit

	_ai_timer -= delta
	match ai:
		AI.IDLE:
			if _can_see_player():
				_enter_aggro()
			elif _ai_timer <= 0.0:
				_enter_wander()
		AI.WANDER:
			if _can_see_player():
				_enter_aggro()
			elif _ai_timer <= 0.0 or not movement.has_order():
				_enter_idle()
		AI.AGGRO:
			if _player == null or not _player.is_alive() \
					or edge_distance_to(_player) > Units.to_px(leash_range):
				attack.cancel()
				movement.stop()
				_enter_idle()
			elif not _player.is_targetable():
				_chase_untargetable(delta)
			elif _brain != null:
				_brain.drive(delta)   # ENEMIES_AI AI1: the brain decides and acts
			elif naive_casting and _try_cast_ability():
				pass  # Casting (rooted); the chase resumes after.
			elif attack.target != _player:
				attack.attack(_player)


func _enter_idle() -> void:
	ai = AI.IDLE
	_ai_timer = randf_range(0.8, 2.0)


func _enter_wander() -> void:
	ai = AI.WANDER
	_ai_timer = randf_range(1.0, 2.0)
	var offset := Vector2.from_angle(randf() * TAU) * randf_range(wander_distance * 0.3, wander_distance)
	movement.move_to(_home + offset)


func _enter_aggro() -> void:
	ai = AI.AGGRO
	if _brain != null:
		Brains.wake(_brain)   # it thinks on the next tick; it doesn't charge in meanwhile
		return
	attack.attack(_player)


## The player is untargetable (ABILITIES AB10): keep aggro, stop attacking
## (a windup is cancelled) and keep chasing; attacking resumes the frame the
## player is targetable again. A cast already going finishes.
func _chase_untargetable(delta: float) -> void:
	if abilities != null and abilities.casting:
		return
	if attack.target != null or attack.is_winding_up():
		attack.cancel()
		_chase_repath = 0.0
	_chase_repath -= delta
	if _chase_repath <= 0.0:
		_chase_repath = 0.1
		movement.move_to(_player.global_position)


func _on_damaged(_amount: float, source: Unit) -> void:
	if passive:
		return
	if ai != AI.AGGRO and source and source == _player:
		_enter_aggro()


## Enemies with an AbilityComponent (elites) cast a ready ability when the
## player is within its cast_range (from the center) and in sight. Its cast
## time is the telegraph (COMBAT.md). Not during a basic attack windup. A
## VECTOR ability places its line with get_ai_vector() (ABILITIES AB13).
## A slot that can't be cast right now for any reason (get_fail_reason():
## a failing condition or cost included, AB12) is skipped, so it never
## blocks the slots after it and nothing emits cast_failed. Returns true
## while casting.
func _try_cast_ability() -> bool:
	if abilities == null:
		return false
	if abilities.casting:
		return true
	if attack.is_winding_up():
		return false
	abilities.set_aim_hint(_player.global_position)   # conditions look at the target (AB12)
	for slot in AbilityComponent.SLOTS:
		var ability := abilities.get_ability(slot)
		if ability == null or not abilities.can_cast(slot):
			continue
		if global_position.distance_to(_player.global_position) > Units.to_px(ability.get_param(self, &"cast_range")):
			continue
		if not _can_see_player():
			continue
		if ability.cast_style == Ability.CastStyle.VECTOR:
			# The ability lays its own line (ABILITIES AB13): no mouse to drag.
			var v := ability.get_ai_vector(self, _player)
			if abilities.get_fail_reason(slot, v.start) != "":
				continue
			return abilities.try_cast_vector(slot, v.start, v.direction)
		if abilities.get_fail_reason(slot, _player.global_position, _player) != "":
			continue
		return abilities.try_cast(slot, _player.global_position, _player)
	return false


func _can_see_player() -> bool:
	if _player == null or not _player.is_targetable():   # no new aggro on an untargetable player (AB10)
		return false
	if edge_distance_to(_player) > Units.to_px(detect_range):
		return false
	sight.target_position = sight.to_local(_player.global_position)
	sight.force_raycast_update()
	return not sight.is_colliding()
