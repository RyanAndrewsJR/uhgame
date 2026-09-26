class_name PlayerInput
extends Node
## Reads the new player actions every physics frame and turns them into an
## intent for the Player (docs/MOVEMENT.md, "PlayerInput").
##
## - move_dir (fed to MovementComponent.set_input_direction()) and aim_point.
## - Input buffer: dash, attack and Q/W/E/R presses that aren't allowed yet
##   wait up to buffer_time and fire as soon as they are. One buffered press
##   at a time: a newer press replaces an older one. The timer pauses while a
##   dash or a cast is playing out, so a press during one fires when it ends.
## - Dash (Space): the held direction, or facing if none.
## - Attack (left mouse): nothing attacks yet (COMBAT.md). A legal press emits
##   attack_pressed(dash_strike), where dash_strike means it came within
##   dash_strike_window seconds of a dash ending.
## player.gd's own _unhandled_input still reads Q/W/E/R and routes them here
## through Player.request_cast() when they can't fire yet.

## A basic attack press became legal. dash_strike: within dash_strike_window
## of a dash ending. Hook for COMBAT.md; nothing listens yet.
signal attack_pressed(dash_strike: bool)

const DASH := &"dash"
const ATTACK := &"attack"

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


func _ready() -> void:
	player = get_parent() as Player
	assert(player != null, "PlayerInput must be a child of a Player")
	# Run before MovementComponent so this frame's input moves this frame.
	process_physics_priority = -10


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
		player.movement.set_input_direction(Vector2.ZERO)
		return

	move_dir = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	aim_point = player.get_aim_point()

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
	# A press during a dash or a cast waits for it to end.
	if player.dash.is_dashing() or player.abilities.casting:
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
				and not player.dash.is_dashing()
		_:
			return player.abilities.can_cast(action) and not player.dash.is_dashing()


func _fire(action: StringName) -> void:
	match action:
		DASH:
			var dir := move_dir if move_dir != Vector2.ZERO else player.facing
			if player.dash.try_dash(dir) and player.abilities.has_pending():
				# Dashing is your own move: drop a queued walk-into-range cast.
				player.abilities.cancel_pending()
				player.movement.stop()
		ATTACK:
			attack_pressed.emit(player.dash.get_time_since_dash_end() <= dash_strike_window)
		_:
			player.cast_ability(action)
