class_name DashComponent
extends Node2D
## Hades-style dash for a Unit (docs/MOVEMENT.md "Dash").
##
## - A fixed-length burst at constant speed, through units but not walls,
##   using MovementComponent.dash().
## - I-frames for the whole dash (Unit.add_invulnerability).
## - Charges from UnitStats.dash_charges. One charge comes back every
##   charge_recharge_time seconds, counted while not dashing.
## - The speed follows dash_curve (burst, then ease out); the distance is exact.
## - If a direction is held when the dash ends, the unit runs on at full
##   speed (carry_into_run). Otherwise walking is locked for end_lag seconds.
##   Another dash can chain in right away if a charge is left.
## - Can't start while stunned, already displaced (dashing, knockback), or
##   casting, unless the ability being cast is dash_cancelable (then the dash
##   cancels it). Starting a dash cancels a basic attack windup.

signal dash_started(direction: Vector2)
signal dash_ended
signal charges_changed(charges: int, max_charges: int)

const END_LAG_LOCK := &"dash_end_lag"
const INVULNERABILITY_ID := &"dash"

## Dash length in LoL units (400 = 128 px).
@export var dash_distance: float = 400.0
## How long the dash takes, in seconds (constant speed).
@export var dash_duration: float = 0.18
## Speed profile of the dash (MOVEMENT.md F2). null = constant speed.
@export var dash_curve: Curve = preload("res://data/curves/curve_dash.tres")
## If a direction is held when the dash ends, walking starts at full speed
## right away and end_lag is skipped, so the dash flows into running.
@export var carry_into_run: bool = true
## Seconds to get one charge back. Charges come back one at a time.
@export var charge_recharge_time: float = 0.35
## Seconds after a dash during which the unit can't walk. Only applies when
## no direction is held at the end (see carry_into_run).
@export var end_lag: float = 0.05
## Invulnerable for the whole dash.
@export var iframes: bool = true

@export_group("Debug")
## Draws the dash charges as pips under the unit.
@export var debug_draw: bool = false

var unit: Unit

var _charges: int = 1
var _recharge_left: float = 0.0
var _end_lag_left: float = 0.0
var _dashing: bool = false
var _direction: Vector2 = Vector2.ZERO
var _since_dash_end: float = INF


func _ready() -> void:
	unit = get_parent() as Unit
	assert(unit != null, "DashComponent must be a child of a Unit")
	_charges = get_max_charges()
	# Children are ready before their parent, so unit.movement (an @onready
	# on Unit) isn't set yet. Fetch the sibling directly.
	var movement := unit.get_node("MovementComponent") as MovementComponent
	movement.displacement_finished.connect(_on_displacement_finished)


# --- Queries --------------------------------------------------------------------

func get_max_charges() -> int:
	return maxi(unit.stats.dash_charges, 1)


func get_charges() -> int:
	return _charges


func is_dashing() -> bool:
	return _dashing


## Seconds since the last dash ended (INF if none yet, 0 while dashing).
## Used for the dash-strike window (MOVEMENT.md step 7).
func get_time_since_dash_end() -> float:
	return 0.0 if _dashing else _since_dash_end


## Direction of the current (or last) dash.
func get_dash_direction() -> Vector2:
	return _direction


func can_dash() -> bool:
	if not unit.is_alive() or unit.is_stunned() or _dashing or _charges <= 0:
		return false
	if unit.movement.is_displaced():
		return false
	if unit.abilities and unit.abilities.casting and not unit.abilities.can_cancel_cast():
		return false
	return true


# --- Commands -------------------------------------------------------------------

## Dash in `direction`. Returns false (and does nothing) if a dash isn't
## allowed right now or the direction is zero.
func try_dash(direction: Vector2) -> bool:
	if direction.length() < 0.01 or not can_dash():
		return false
	_direction = direction.normalized()
	_charges -= 1
	if _recharge_left <= 0.0:
		_recharge_left = charge_recharge_time
	if unit.abilities and unit.abilities.casting:
		unit.abilities.try_cancel_cast()
	_dashing = true
	_clear_end_lag()
	if unit.attack.is_winding_up():
		unit.attack.cancel()
	if iframes:
		unit.add_invulnerability(INVULNERABILITY_ID)
	var speed_px := Units.to_px(dash_distance) / maxf(dash_duration, 0.01)
	unit.movement.dash(_direction * speed_px, dash_duration, true, dash_curve)
	charges_changed.emit(_charges, get_max_charges())
	dash_started.emit(_direction)
	queue_redraw()
	return true


# --- Update ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not _dashing:
		_since_dash_end += delta
	if _end_lag_left > 0.0:
		_end_lag_left -= delta
		if _end_lag_left <= 0.0:
			_clear_end_lag()

	if _dashing or _charges >= get_max_charges():
		return
	_recharge_left -= delta
	if _recharge_left <= 0.0:
		_charges += 1
		if _charges < get_max_charges():
			_recharge_left = charge_recharge_time
		charges_changed.emit(_charges, get_max_charges())
		queue_redraw()


func _on_displacement_finished() -> void:
	if not _dashing:
		return
	_dashing = false
	_since_dash_end = 0.0
	unit.remove_invulnerability(INVULNERABILITY_ID)
	if carry_into_run and unit.movement.get_input_direction() != Vector2.ZERO:
		unit.movement.set_input_speed_to_max()
	elif end_lag > 0.0 and unit.is_alive():
		_end_lag_left = end_lag
		unit.movement.add_move_lock(END_LAG_LOCK)
	dash_ended.emit()


func _clear_end_lag() -> void:
	_end_lag_left = 0.0
	unit.movement.remove_move_lock(END_LAG_LOCK)


func _draw() -> void:
	if not debug_draw:
		return
	var n := get_max_charges()
	for i in n:
		var pos := Vector2((i - (n - 1) * 0.5) * 6.0, 8.0)
		var filled := i < _charges
		if filled:
			draw_circle(pos, 2.0, Color(0.5, 0.9, 1.0))
		else:
			draw_arc(pos, 2.0, 0.0, TAU, 12, Color(0.5, 0.9, 1.0, 0.6), 1.0)
