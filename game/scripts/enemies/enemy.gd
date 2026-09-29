class_name Enemy
extends Unit
## Basic monster AI: wanders, aggros on sight (or when hit), then chases and
## auto-attacks with the same AutoAttackComponent the player uses.
## Tune stats in its UnitStats resource; tune behaviour here.

enum AI { IDLE, WANDER, AGGRO }

## Aggro range in LoL units (edge to edge).
@export var detect_range: float = 450.0
## Stop chasing once the target is this far away (LoL units).
@export var leash_range: float = 800.0
@export var wander_distance: float = 60.0
## Training dummy: never wanders, aggros or attacks, even when hit. It can
## still be damaged, knocked back, stunned and killed.
@export var passive: bool = false

@onready var sight: RayCast2D = $Sight

var ai: AI = AI.IDLE
var _ai_timer: float = 0.0
var _bob_time: float = 0.0
var _home: Vector2
var _player: Unit
var _chase_repath: float = 0.0   # chasing an untargetable player (AB10)


func _ready() -> void:
	team = Team.ENEMY
	super._ready()
	add_to_group("enemies")
	_home = global_position
	_bob_time = randf() * TAU
	damaged.connect(_on_damaged)
	attack.windup_started.connect(_on_windup_started)
	attack.attack_landed.connect(_on_attack_landed)
	attack.attack_whiffed.connect(_on_attack_whiffed)
	_enter_idle()


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
			elif _try_cast_ability():
				pass  # Casting (rooted); the chase resumes after.
			elif attack.target != _player:
				attack.attack(_player)


func _process(delta: float) -> void:
	if not is_alive():
		return
	# Squishy hop while moving.
	var moving := movement.get_move_direction() != Vector2.ZERO
	_bob_time += delta * (12.0 if moving else 4.0)
	var squash := sin(_bob_time) * (0.12 if moving else 0.05)
	if not attack.is_winding_up():
		body.scale = Vector2(1.0 + squash, 1.0 - squash)
	var dir := movement.get_move_direction()
	if absf(dir.x) > 0.1:
		$Body/Eyes.position.x = signf(dir.x) * 2.0


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


func _on_windup_started(_target: Unit, windup_time: float) -> void:
	# Crouch before lunging.
	var tween := create_tween()
	tween.tween_property(body, "scale", Vector2(1.25, 0.75), windup_time)


## A missed attack (the target got out of reach) still lunges.
func _on_attack_whiffed(target: Unit) -> void:
	if is_instance_valid(target):
		_on_attack_landed(target, 0.0)


func _on_attack_landed(target: Unit, _damage: float) -> void:
	var dir := (target.global_position - global_position).normalized()
	body.scale = Vector2(0.85, 1.2)
	var tween := create_tween()
	tween.tween_property(body, "position", dir * 6.0, 0.05)
	tween.tween_property(body, "position", Vector2.ZERO, 0.12)
	tween.parallel().tween_property(body, "scale", Vector2.ONE, 0.12)
