class_name PlayerInput
extends Node
## Reads the new player actions every physics frame and turns them into an
## intent for the Player (docs/MOVEMENT.md, "PlayerInput").
##
## - move_dir (fed to MovementComponent.set_input_direction()) and aim_point.
## - Input buffer: dash, attack and Q/W/E/R presses that aren't allowed yet
##   wait up to buffer_time and fire as soon as they are. One buffered press
##   at a time: a newer press replaces an older one. The timer pauses while a
##   dash, a cast or a basic attack swing is playing out, so a press during
##   one fires when it ends.
## - Dash (Space): the held direction, or facing if none.
## - Attack (left mouse): the next swing of the basic attack combo toward the
##   cursor (AutoAttackComponent.try_swing(), COMBAT.md). A press during a
##   swing queues the next one. A legal press also emits
##   attack_pressed(dash_strike), where dash_strike means it came within
##   dash_strike_window seconds of a dash ending.
## - Q/W/E/R during a swing: only if the ability's cancels_swing allows it
##   right now (Player.can_interrupt_swing()); otherwise it waits.
## - A movement press that starts during a cast cancels it if the ability
##   has cancel_on_move (keys already held don't count).
## player.gd's own _unhandled_input still reads Q/W/E/R and routes them here
## through Player.request_cast() when they can't fire yet.

## A basic attack press became legal and a swing is starting. dash_strike:
## within dash_strike_window of a dash ending (the dash-strike swing is
## COMBAT C12).
signal attack_pressed(dash_strike: bool)

const DASH := &"dash"
const ATTACK := &"attack"
const MOVE_ACTIONS: Array[StringName] = [&"move_up", &"move_down", &"move_left", &"move_right"]

## How long an early press waits to become legal (seconds).
@export var buffer_time: float = 0.15
## An attack within this many seconds after a dash ends is a dash-strike.
@export var dash_strike_window: float = 0.1

## Held movement direction this frame (length 0..1, diagonals normalized).
var move_dir: Vector2 = Vector2.ZERO
## Where the player is aiming (the mouse, in world space).
var aim_point: Vector2 = Vector2.ZERO

var player: Player

var _buffered: StringName = &""   # DASH, ATTACK, or an ability slot (&"q"...)
var _buffer_left: float = 0.0
var _move_pressed_during_cast: bool = false


func _ready() -> void:
	player = get_parent() as Player
	assert(player != null, "PlayerInput must be a child of a Player")
	# Run before MovementComponent so this frame's input moves this frame.
	process_physics_priority = -10


## Notes a movement press that starts while a cast is already running, for
## Ability.cancel_on_move. Input events arrive in order, so a Q press then a
## D press in the same frame counts; a key held since before the cast sends
## no new press. The cancel itself happens in _physics_process.
func _unhandled_input(event: InputEvent) -> void:
	if not player.abilities.casting:
		return
	for action: StringName in MOVE_ACTIONS:
		if event.is_action_pressed(action):
			_move_pressed_during_cast = true
			return


# --- Buffer ---------------------------------------------------------------------

## Remember a press that isn't allowed yet. Replaces any older buffered press.
func buffer_action(action: StringName) -> void:
	_buffered = action
	_buffer_left = buffer_time


## The buffered press (DASH, ATTACK, an ability slot), or &"" if none.
func get_buffered_action() -> StringName:
	return _buffered


func clear_buffer() -> void:
	_buffered = &""
	_buffer_left = 0.0


# --- Update ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not player.is_alive():
		move_dir = Vector2.ZERO
		clear_buffer()
		_move_pressed_during_cast = false
		player.movement.set_input_direction(Vector2.ZERO)
		return

	move_dir = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	aim_point = player.get_aim_point()

	# A new movement press cancels a cancel_on_move cast (during its cast time).
	# This runs before MovementComponent, so the new key moves this same frame.
	if _move_pressed_during_cast:
		_move_pressed_during_cast = false
		player.abilities.try_cancel_cast_on_move()

	# Walking yourself cancels a queued targeted ability that was walking you
	# into range (like a move order in LoL).
	if move_dir != Vector2.ZERO and player.abilities.has_pending():
		player.abilities.cancel_pending()

	player.movement.set_input_direction(move_dir)

	if Input.is_action_just_pressed(DASH):
		buffer_action(DASH)
	if Input.is_action_just_pressed(ATTACK):
		buffer_action(ATTACK)
	_update_buffer(delta)


func _update_buffer(delta: float) -> void:
	if _buffered == &"":
		return
	if _is_legal(_buffered):
		var action := _buffered
		clear_buffer()
		_fire(action)
		return
	# A press during a dash, a cast or a swing waits for it to end.
	if player.dash.is_dashing() or player.abilities.casting or player.attack.is_swinging():
		return
	_buffer_left -= delta
	if _buffer_left <= 0.0:
		clear_buffer()


func _is_legal(action: StringName) -> bool:
	match action:
		DASH:
			return player.dash.can_dash()
		ATTACK:
			return not player.is_stunned() and not player.abilities.casting \
				and not player.dash.is_dashing() and player.attack.can_swing()
		_:
			return player.abilities.can_cast(action) and not player.dash.is_dashing() \
				and player.can_interrupt_swing(action)


func _fire(action: StringName) -> void:
	match action:
		DASH:
			var dir := move_dir if move_dir != Vector2.ZERO else player.facing
			if player.dash.try_dash(dir) and player.abilities.has_pending():
				# Dashing is your own move: drop a queued walk-into-range cast.
				player.abilities.cancel_pending()
				player.movement.stop()
		ATTACK:
			var dash_strike := player.dash.get_time_since_dash_end() <= dash_strike_window
			attack_pressed.emit(dash_strike)
			if player.attack.try_swing(player.get_aim_direction(), dash_strike) \
					and player.abilities.has_pending():
				# Attacking is your own move: drop a queued walk-into-range cast.
				player.abilities.cancel_pending()
				player.movement.stop()
		_:
			player.cast_ability(action)
