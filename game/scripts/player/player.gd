class_name Player
extends Unit
## LoL-style controls.
##   Right-click ground  - move there (paths around walls and units)
##   Right-click enemy   - chase it and auto-attack it
##   Hold right-click    - keep re-targeting whatever is under the cursor
##   A, then left-click  - attack-move (right-click or Esc cancels)
##   S                   - stop (also cancels an attack windup)
##   Q / W / E / R       - abilities (see cast_mode)

enum CastMode {
	## Hold the key to see the indicator, release to cast. Right-click cancels.
	QUICK_WITH_INDICATOR,
	## Cast instantly at the cursor when the key is pressed.
	QUICK,
}

## What the player is doing, derived each physics frame from the components
## (MOVEMENT.md "Player states"). Priority: STUNNED > DASH > CASTING >
## ATTACK (a rooted combo swing, whose melee step is a displacement) >
## DISPLACED > ATTACK (League-style windup) > MOVE > IDLE.
enum State {
	IDLE,       ## Standing still, free to act.
	MOVE,       ## Walking (WASD, or a path such as R walking into range).
	DASH,       ## The player's own dash (added in movement step 6).
	ATTACK,     ## Basic attack windup.
	CASTING,    ## An ability is being cast (includes Lunge's dash).
	STUNNED,    ## Stunned: can't move, attack or cast.
	DISPLACED,  ## Pushed by something else (knockback, pull); can't walk.
}

## is_new_click is false while right-click is being held and dragged.
signal move_commanded(target: Vector2, is_new_click: bool)
signal attack_commanded(target: Unit, is_new_click: bool)
signal attack_move_commanded(point: Vector2)
signal state_changed(from: State, to: State)

const ABILITY_ACTIONS := {&"q": "ability_q", &"w": "ability_w", &"e": "ability_e", &"r": "ability_r"}

@export var cast_mode: CastMode = CastMode.QUICK_WITH_INDICATOR
## How often the order updates while right-click is held (seconds).
@export var hold_repath_interval: float = 0.05
## How close (px) the cursor must be to an enemy for targeted abilities.
@export var target_forgiveness: float = 14.0
## Shows the current State name above the player.
@export var debug_draw: bool = false

@onready var sword_pivot: Node2D = $SwordPivot
@onready var sword: Polygon2D = $SwordPivot/Sword
@onready var dash: DashComponent = $DashComponent
@onready var player_input: PlayerInput = $PlayerInput

var attack_move_armed: bool = false:
	set(value):
		attack_move_armed = value
		queue_redraw()

## Which ability is being aimed (QUICK_WITH_INDICATOR), or &"".
var aiming_slot: StringName = &""
## Alternates each swing so consecutive slashes go opposite ways.
var swing_side: float = 1.0
## Current State (read-only for other code; see _update_state()).
var state: State = State.IDLE
## Which way the player looks (unit vector). Units don't rotate; the
## animation layer will pick one of 8 sprites from this (MOVEMENT.md).
var facing: Vector2 = Vector2.RIGHT

var _hold_timer: float = 0.0
var _hovered_enemy: Unit
var _walk_time: float = 0.0
## Where the current cast was aimed, locked at cast start (INF = none).
var _cast_face_point: Vector2 = Vector2.INF
## The sword pull-back tween of the current swing's windup.
var _swing_tween: Tween


func _ready() -> void:
	team = Team.PLAYER
	super._ready()
	add_to_group("player")
	attack.windup_started.connect(_on_windup_started)
	attack.attack_landed.connect(_on_attack_landed)
	attack.windup_cancelled.connect(_on_windup_cancelled)
	attack.swing_started.connect(_on_swing_started)
	attack.swing_landed.connect(_on_swing_landed)
	attack.swing_cancelled.connect(_on_swing_cancelled)
	abilities.cast_started.connect(_on_cast_started)
	abilities.cast_finished.connect(_on_cast_finished)
	dash.dash_started.connect(_on_dash_started)
	dash.dash_ended.connect(_on_dash_ended)


# --- Input ----------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not is_alive():
		return

	for slot: StringName in ABILITY_ACTIONS:
		var action: String = ABILITY_ACTIONS[slot]
		if event.is_action_pressed(action):
			_on_ability_pressed(slot)
			return
		if event.is_action_released(action):
			_on_ability_released(slot)
			return

	if event.is_action_pressed("move"):
		if aiming_slot != &"":
			aiming_slot = &""  # Right-click cancels the aim, like LoL.
			queue_redraw()
			return
		attack_move_armed = false
		_issue_right_click(true)
		_hold_timer = hold_repath_interval
	elif event.is_action_pressed("attack_move"):
		attack_move_armed = true
	elif event.is_action_pressed("ui_cancel"):
		attack_move_armed = false
		if aiming_slot != &"":
			aiming_slot = &""
			queue_redraw()
			# This Esc only cancels the aim; it doesn't open the pause menu.
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("select") and attack_move_armed:
		attack_move_armed = false
		var enemy := _enemy_under_mouse()
		abilities.cancel_pending()
		if enemy:
			attack.attack(enemy)
			attack_commanded.emit(enemy, true)
		else:
			attack.attack_move(get_global_mouse_position())
			attack_move_commanded.emit(movement.get_destination())
	elif event.is_action_pressed("stop"):
		abilities.cancel_pending()
		attack.cancel()
		movement.stop()


func _on_ability_pressed(slot: StringName) -> void:
	var ability := abilities.get_ability(slot)
	if ability == null:
		return
	var instant := cast_mode == CastMode.QUICK or ability.targeting == Ability.Targeting.SELF
	if instant:
		request_cast(slot)
	else:
		aiming_slot = slot
		queue_redraw()


func _on_ability_released(slot: StringName) -> void:
	if aiming_slot == slot:
		aiming_slot = &""
		queue_redraw()
		request_cast(slot)


## Input path for Q/W/E/R: casts now if allowed, otherwise buffers the press
## in PlayerInput so it fires as soon as it's allowed (MOVEMENT.md step 7).
## No casting while dashing. During a basic attack swing only if the
## ability's cancels_swing allows it (the cast then cancels the swing).
func request_cast(slot: StringName) -> void:
	if abilities.can_cast(slot) and not dash.is_dashing() and can_interrupt_swing(slot):
		cast_ability(slot)
	else:
		player_input.buffer_action(slot)


## True if the ability in `slot` may start now as far as a basic attack
## swing is concerned (Ability.cancels_swing, COMBAT.md): always when not
## swinging; AFTER_HIT once the swing's hit has landed; ANYTIME always.
func can_interrupt_swing(slot: StringName) -> bool:
	if not attack.is_swinging():
		return true
	var ability := abilities.get_ability(slot)
	if ability == null:
		return false
	match ability.cancels_swing:
		Ability.SwingCancel.ANYTIME:
			return true
		Ability.SwingCancel.AFTER_HIT:
			return attack.is_in_recovery()
	return false


## Cast an ability at the cursor (also used by tests).
func cast_ability(slot: StringName, aim: Vector2 = Vector2.INF) -> bool:
	if aim == Vector2.INF:
		aim = get_global_mouse_position()
	var target := _enemy_under_point(aim)
	if target == null:
		target = AbilityUtil.nearest_enemy_to(self, aim, target_forgiveness)
	return abilities.try_cast(slot, aim, target)


func _issue_right_click(is_new_click: bool) -> void:
	abilities.cancel_pending()
	var enemy := _enemy_under_mouse()
	if enemy:
		attack.attack(enemy)
		attack_commanded.emit(enemy, is_new_click)
	else:
		attack.cancel()
		movement.move_to(get_global_mouse_position())
		move_commanded.emit(movement.get_destination(), is_new_click)


func _enemy_under_mouse() -> Unit:
	return _enemy_under_point(get_global_mouse_position())


func _enemy_under_point(point: Vector2) -> Unit:
	var best: Unit = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("units"):
		var u := node as Unit
		if u == null or not u.is_alive() or not is_enemy_of(u):
			continue
		if u.contains_point(point):
			var d := point.distance_to(u.get_center())
			if d < best_d:
				best = u
				best_d = d
	return best


# --- Update ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not is_alive():
		return
	_update_facing()
	_update_state()
	# Holding right-click keeps re-issuing the order, like LoL.
	if Input.is_action_pressed("move") and aiming_slot == &"":
		_hold_timer -= delta
		if _hold_timer <= 0.0:
			_hold_timer = hold_repath_interval
			_issue_right_click(false)


func _process(delta: float) -> void:
	if not is_alive():
		return
	# Hover highlight + cursor.
	var enemy := _enemy_under_mouse()
	if enemy != _hovered_enemy:
		if is_instance_valid(_hovered_enemy):
			_hovered_enemy.hovered = false
		_hovered_enemy = enemy
		if enemy:
			enemy.hovered = true
	var targeting := enemy != null or attack_move_armed or aiming_slot != &""
	var want_cursor := Input.CURSOR_CROSS if targeting else Input.CURSOR_ARROW
	if Input.get_current_cursor_shape() != want_cursor:
		Input.set_default_cursor_shape(want_cursor)

	if aiming_slot != &"":
		queue_redraw()

	# Facing and a little walk bob.
	var dir := movement.get_move_direction()
	var busy := abilities.casting or attack.is_winding_up() or attack.is_swing_rooted()
	if not busy and dir != Vector2.ZERO:
		sword_pivot.rotation = dir.angle()
		if absf(dir.x) > 0.05:
			body.scale.x = signf(dir.x)
	# While aiming an ability, the sword points at the cursor (matches facing).
	if aiming_slot != &"":
		face(get_aim_point())
	if dir != Vector2.ZERO:
		_walk_time += delta * 14.0
		body.position.y = -absf(sin(_walk_time)) * 2.0
	else:
		_walk_time = 0.0
		body.position.y = move_toward(body.position.y, 0.0, delta * 20.0)

	# Sword glows while an empowered attack is ready.
	sword.color = Color(1, 0.85, 0.4) if attack.is_empowered() else Color(0.85, 0.85, 0.9)


func _draw() -> void:
	super._draw()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if attack_move_armed:
		# Attack range indicator, like holding A in LoL.
		var r := attack.get_range_px() + get_gameplay_radius_px()
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(1, 1, 1, 0.35), 1.0)
	if aiming_slot != &"":
		var ability := abilities.get_ability(aiming_slot)
		if ability:
			ability.draw_indicator(self, self, get_global_mouse_position())
	if debug_draw:
		draw_string(ThemeDB.fallback_font, Vector2(-30, -52), State.keys()[state],
			HORIZONTAL_ALIGNMENT_CENTER, 60, 8, Color(1, 1, 0.6))


# --- States -----------------------------------------------------------------------

func is_in_state(s: State) -> bool:
	return state == s


## Works out the state from the components, highest priority first, and
## emits state_changed when it changes.
func _update_state() -> void:
	var next := State.IDLE
	if is_stunned():
		next = State.STUNNED
	elif dash.is_dashing():
		next = State.DASH
	elif abilities.casting:
		next = State.CASTING
	elif attack.is_swing_rooted():
		next = State.ATTACK  # Over DISPLACED: a melee swing steps (displace()).
	elif movement.is_displaced():
		next = State.DISPLACED
	elif attack.is_winding_up():
		next = State.ATTACK
	elif movement.get_move_direction() != Vector2.ZERO or movement.get_input_direction() != Vector2.ZERO:
		# Holding a direction counts as moving, so there's no one-frame IDLE
		# while the walk ramps back up after a cast.
		next = State.MOVE
	if next != state:
		var from := state
		state = next
		state_changed.emit(from, next)
		if debug_draw:
			queue_redraw()


# --- Facing and aim ---------------------------------------------------------------

## Where the player is aiming, in world space (the mouse).
func get_aim_point() -> Vector2:
	return get_global_mouse_position()


## Unit vector from the player's feet (the point abilities cast from) toward
## the aim point. Falls back to facing when the cursor is on the player.
func get_aim_direction() -> Vector2:
	var to_aim := get_aim_point() - global_position
	return to_aim.normalized() if to_aim.length() > 0.01 else facing


## Facing as one of 8 directions for directional sprites: 0 = right, then
## clockwise (2 = down, 4 = left, 6 = up).
func get_facing_octant() -> int:
	return posmod(roundi(facing.angle() / (TAU / 8.0)), 8)


## Facing priority: casting (the cast's aim, locked at cast start) >
## attacking (a combo swing's aim, locked at swing start; or a League-style
## windup's target) > dashing (the dash direction) > aiming an ability
## (the cursor) > walking (the move direction). Standing still keeps the last
## facing.
func _update_facing() -> void:
	var look := Vector2.ZERO
	if abilities.casting and _cast_face_point != Vector2.INF:
		look = _cast_face_point - global_position
	elif attack.is_swing_rooted():
		look = attack.get_swing_direction()
	elif attack.is_winding_up() and is_instance_valid(attack.target):
		look = attack.target.global_position - global_position
	elif dash.is_dashing():
		look = dash.get_dash_direction()
	elif aiming_slot != &"":
		look = get_aim_point() - global_position
	else:
		look = movement.get_move_direction()
	if look.length() > 0.01:
		facing = look.normalized()


# --- Visuals ----------------------------------------------------------------------

func face(point: Vector2) -> void:
	var aim := point - sword_pivot.global_position
	if aim.length() < 0.01:
		return
	sword_pivot.rotation = aim.angle()
	if absf(aim.x) > 0.05:
		body.scale.x = signf(aim.x)


func _on_windup_started(target: Unit, windup_time: float) -> void:
	face(target.get_center())
	# Pull the sword back during the windup.
	var tween := create_tween()
	tween.tween_property(sword, "rotation", -0.9 * swing_side, windup_time * 0.8)


func _on_attack_landed(target: Unit, _damage: float) -> void:
	face(target.get_center())
	sword.rotation = 0.0
	_swing_sword(0.1)
	VFX.slash(get_parent(), sword_pivot.global_position, sword_pivot.rotation, 14.0, 40.0,
		deg_to_rad(55.0), Color(1, 1, 1, 0.7), 0.1, swing_side)


func _on_windup_cancelled() -> void:
	sword.rotation = 0.0


## Combo swing visuals (visual only): pull the sword back during the windup,
## then slash across the swing's arc at the hit.
func _on_swing_started(_index: int, direction: Vector2, swing: AttackSwing) -> void:
	face(sword_pivot.global_position + direction * 16.0)
	if _swing_tween:
		_swing_tween.kill()
	_swing_tween = create_tween()
	_swing_tween.tween_property(sword, "rotation", -0.9 * swing_side,
		swing.windup / attack.get_swing_speed() * 0.8)


func _on_swing_landed(index: int, _targets: Array[Unit]) -> void:
	if _swing_tween:
		_swing_tween.kill()
	var swing := attack.get_current_swing()
	var direction := attack.get_swing_direction()
	var finisher := index == attack.combo.swings.size() - 1
	sword.rotation = 0.0
	_swing_sword(0.1)
	VFX.slash(get_parent(), get_center(), direction.angle(), 8.0, attack.get_swing_reach_px(swing),
		deg_to_rad(swing.arc_deg) * 0.5, Color(1, 1, 1, 0.95 if finisher else 0.75),
		0.16 if finisher else 0.11, swing_side)


func _on_swing_cancelled() -> void:
	if _swing_tween:
		_swing_tween.kill()
	sword.rotation = 0.0


func _on_cast_started(_slot: StringName, ability: Ability, ctx: CastContext) -> void:
	match ability.targeting:
		Ability.Targeting.DIRECTION, Ability.Targeting.POINT:
			_cast_face_point = ctx.point
			face(ctx.point)
		Ability.Targeting.UNIT:
			if is_instance_valid(ctx.target):
				_cast_face_point = ctx.target.global_position
				face(ctx.target.get_center())
	if ability.targeting != Ability.Targeting.SELF:
		_swing_sword(maxf(ability.cast_time, 0.1))


func _on_cast_finished(_slot: StringName, _ability: Ability) -> void:
	_cast_face_point = Vector2.INF


## I-frames read as a see-through body while dashing (visual only).
func _on_dash_started(_direction: Vector2) -> void:
	body.modulate.a = 0.5


func _on_dash_ended() -> void:
	body.modulate.a = 1.0


## Sword swing animation (visual only).
func _swing_sword(duration: float) -> void:
	swing_side = -swing_side
	var tween := create_tween()
	sword.rotation = -1.2 * swing_side
	tween.tween_property(sword, "rotation", 1.2 * swing_side, duration)
	tween.tween_property(sword, "rotation", 0.0, 0.08)


# --- Damage / death -------------------------------------------------------------

## Getting hit shakes the screen. take_damage() comes through here too.
func on_hit(ctx: HitContext) -> void:
	super.on_hit(ctx)
	if not ctx.blocked:
		GameFeel.shake(2.0)  # Blocked (dash i-frames, dead): no shake.


func _on_died() -> void:
	attack_move_armed = false
	aiming_slot = &""
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	super._on_died()


func _play_death() -> void:
	var tween := create_tween()
	tween.tween_property(body, "rotation", deg_to_rad(90.0), 0.25)
	tween.parallel().tween_property(body, "modulate", Color(1, 0.3, 0.3, 0.6), 0.25)
