class_name AutoAttackComponent
extends Node
## A Unit's basic attacks (COMBAT.md). Two modes:
##
## League-style (enemies; `combo` null):
## attack(target)       - chase the target until in range, then attack it
##                        repeatedly.
## cancel()             - drop the attack order.
##
## Each attack has a windup (the unit is rooted; a lock cancels the attack
## and refunds it) and then the hit, through the hit pipeline
## (HitPipeline.resolve(): damage_increase, crit and hit: scopes apply). After
## the hit the unit is free to move while the attack timer counts down. The
## attack timer starts when the windup starts, like LoL, so attack speed =
## attacks per second.
##
## Combo mode (the player; COMBAT.md): with `combo` set, the unit swings on
## command, Hades-style: try_swing(direction) starts the next swing of the
## combo toward that direction. Each swing roots for its whole duration, hits
## everything in its arc at the end of its windup (through the hit pipeline),
## then recovers. The next swing continues the combo; combo_reset_time
## without attacking starts it over. cancel_swing() (dash, stun, a cast)
## stops a swing; a swing counts once its hit has landed, so a cancel the
## player chose after the hit keeps the combo and anything else resets it.
##
## MELEE combos (COMBAT.md, Melee basic attacks): at swing start the unit
## looks for an aimed enemy (within reach + assist_range_bonus_px and
## assist_angle_deg of the aim, in line of sight). The aim snaps toward it by
## up to assist_snap_deg, and during the windup the unit steps: toward that
## enemy until its edge is stop_at_reach_fraction x reach away (capped by
## lunge_max_px), or lunge_px straight along the aim when nothing is aimed
## at. The step is a dash-cancelable displace(), so walls and bodies stop it
## and a dash replaces it. Any combo: after the hit, moving ends the root
## (walk_cancels_recovery), but the next swing still waits for the swing's
## full duration.

signal windup_started(target: Unit, windup_time: float)
## League-style attack: the hit is about to resolve. `damage` is the hit's
## damage before damage_increase, crit and mitigation.
signal attack_landed(target: Unit, damage: float)
signal windup_cancelled
## League-style attack: the windup ended but the target was out of reach
## (it walked or dashed away), so the attack missed (COMBAT.md, Enemies).
signal attack_whiffed(target: Unit)
## Combo mode: a swing started (index 0 = first swing of the combo, -1 = the
## dash-strike, COMBAT C12).
signal swing_started(index: int, direction: Vector2, swing: AttackSwing)
## Combo mode: the swing's hit moment. `targets` is empty for a whiff.
signal swing_landed(index: int, targets: Array[Unit])
## Combo mode: a swing stopped early (dash, stun, cast, death). No hit if it
## was still winding up. The combo resets unless the hit had landed and the
## player chose the cancel (cancel_swing(true)).
signal swing_cancelled

enum State { IDLE, CHASING, WINDUP, BACKSWING }

## The attack lock AbilityComponent adds while casting (see add_lock()).
const CASTING_LOCK := &"casting"
const BONUS_ATTACK_SPEED_SOURCE := &"bonus_attack_speed"
## Move lock held for the whole of a combo swing.
const SWING_LOCK := &"attack_swing"
## Swing timers count as done within this many seconds of 0, so float
## residue (0.3 - 18 x 1/60) doesn't add a physics frame.
const SWING_TIME_EPSILON := 0.0001

## How often to re-path while chasing a moving target (seconds).
@export var chase_repath_interval: float = 0.1
## League-style attack: the hit pushes the target this far, px (slime 12).
## A hit's knockback can be dashed out of (COMBAT.md).
@export var hit_knockback_px: float = 0.0
@export var hit_knockback_duration: float = 0.1
## League-style attack: the attack reaches only attack_range x (1 - this),
## both to start the windup and when it lands, so it's a bit shorter than it
## looks (COMBAT.md: enemy attack hitboxes -10%). Out of reach when it lands
## = a whiff.
@export_range(0.0, 0.2) var enemy_hit_forgiveness: float = 0.10
## Hades-style combo (COMBAT.md). Set = combo mode (the player); null = the
## League-style attack (enemies).
@export var combo: AttackCombo
## Speed profile of a melee swing step (ease-out, MOVEMENT.md F2).
@export var step_curve: Curve = preload("res://data/curves/curve_dash.tres")
## Draws the melee assist of the last swing: the assist cone (grey), the
## aimed enemy (red) and the planned step (yellow).
@export var debug_draw: bool = false

var unit: Unit
var state: State = State.IDLE
var target: Unit
## Bonus attack speed as a fraction (0.3 = +30%). Kept as a thin wrapper:
## setting it replaces one PERCENT_ADD attack_speed modifier on the unit's
## StatsComponent (source BONUS_ATTACK_SPEED_SOURCE). New code adds its own
## StatModifiers instead (STATS.md).
var bonus_attack_speed: float = 0.0:
	set(value):
		bonus_attack_speed = value
		var stats := get_node_or_null(^"../StatsComponent") as StatsComponent
		if stats == null:
			return
		stats.remove_modifiers_from(BONUS_ATTACK_SPEED_SOURCE)
		if value != 0.0:
			stats.add_modifier(StatModifier.create(&"attack_speed", StatModifier.Type.PERCENT_ADD, value, BONUS_ATTACK_SPEED_SOURCE))

var _attack_timer: float = 0.0     # time until the next attack may start
var _windup_left: float = 0.0
var _repath_timer: float = 0.0
var _locks: Dictionary = {}        # e.g. casting an ability
## add_next_attack_modifier()'s on_hit per empower status id, called per
## target when that empower is used up (AB10).
var _empower_callbacks: Dictionary = {}

# Combo mode
var _swing: AttackSwing                # the swing playing out, or null
var _swing_index: int = 0
var _swing_direction: Vector2 = Vector2.RIGHT
var _swing_landed: bool = false        # its hit has happened (recovery)
var _swing_windup_left: float = 0.0
var _swing_left: float = 0.0           # until the swing ends
var _swing_fresh: bool = false         # started this physics frame
var _next_swing_index: int = 0
## The swing running is the combo's dash_strike (COMBAT C12). Its index is
## -1; the combo position it interrupted is kept in _dash_strike_resume.
var _is_dash_strike: bool = false
var _dash_strike_resume: int = 0
var _combo_reset_left: float = 0.0
var _root_released: bool = false       # walking ended the root early
var _pause_left: float = 0.0           # breather after a swing (pause_after)
var _since_hit: float = 0.0
var _step_serial: int = -1             # MovementComponent serial of our step
var _assist_target: Unit               # the last swing's aimed enemy, or null
var _debug_plan: Dictionary = {}       # the last swing's assist, for debug_draw
var _debug_node: Node2D


func _ready() -> void:
	unit = get_parent() as Unit
	assert(unit != null, "AutoAttackComponent must be a child of a Unit")


# --- Stats ----------------------------------------------------------------------

## Attacks per second: the attack_speed stat (base_attack_speed x (1 + bonus),
## capped by UnitStats.attack_speed_cap).
func get_attack_speed() -> float:
	return unit.stats_component.get_stat(&"attack_speed")


func get_attack_interval() -> float:
	return 1.0 / get_attack_speed()


func get_windup_time() -> float:
	return get_attack_interval() * unit.stats.attack_windup


func get_range_px() -> float:
	return Units.to_px(unit.stats_component.get_stat(&"attack_range"))


## League-style attack reach (edge to edge): attack_range less
## enemy_hit_forgiveness. The windup starts, and the hit lands, only within it.
func is_in_range(other: Unit) -> bool:
	return unit.edge_distance_to(other) <= get_range_px() * (1.0 - enemy_hit_forgiveness)


func is_winding_up() -> bool:
	return state == State.WINDUP


# --- Combo mode -----------------------------------------------------------------

## A combo swing is playing out (windup or recovery).
func is_swinging() -> bool:
	return _swing != null


## The swing's hit has landed and it's recovering.
func is_in_recovery() -> bool:
	return _swing != null and _swing_landed


## A new swing may start now: combo mode, alive, not swinging, no locks
## (stun, casting).
func can_swing() -> bool:
	return combo != null and not combo.swings.is_empty() and unit.is_alive() \
		and _swing == null and _locks.is_empty() and _pause_left <= 0.0


## The breather after a swing (AttackSwing.pause_after) is running: the next
## swing waits, but nothing else does.
func is_in_pause() -> bool:
	return _pause_left > 0.0


## While swinging: the current swing's index. Otherwise: the index the next
## swing will use (0 once the combo has reset).
func get_combo_index() -> int:
	return _swing_index if _swing != null else _next_swing_index


## True while the running swing is the dash-strike (COMBAT C12).
func is_dash_strike() -> bool:
	return _swing != null and _is_dash_strike


## A swing is playing out and still roots the unit (walking hasn't ended
## its recovery early).
func is_swing_rooted() -> bool:
	return _swing != null and not _root_released


## The enemy the last melee swing was aimed at (target pull), or null.
func get_assist_target() -> Unit:
	return _assist_target if is_instance_valid(_assist_target) else null


## The swing playing out (null when not swinging). Still set when
## swing_landed is emitted.
func get_current_swing() -> AttackSwing:
	return _swing


## Where the current (or last) swing was aimed, locked at its start.
func get_swing_direction() -> Vector2:
	return _swing_direction


## Combo speed multiplier: attack_speed / base attack speed (1.0 at base;
## +20% bonus attack speed = 1.2), times the combo's speed_scale. Every
## swing timing is divided by it.
func get_swing_speed() -> float:
	var scale := combo.speed_scale if combo != null else 1.0
	var base := unit.stats_component.get_base_value(&"attack_speed")
	if base <= 0.0:
		return scale
	return maxf(get_attack_speed() / base * scale, 0.01)


## Reach of a swing in px (before hit forgiveness): the attack_range stat
## x the swing's reach_multiplier, from the feet to the target's edge.
func get_swing_reach_px(swing: AttackSwing) -> float:
	return get_range_px() * swing.reach_multiplier


## Starts the next swing of the combo toward `direction`. Returns false if a
## swing can't start now (see can_swing()). dash_strike picks the combo's
## dash_strike swing when it has one (COMBAT C12): its own swing (index -1)
## that doesn't count as a combo hit, so the swing after it continues the
## combo where it was (a new combo_reset_time window starts when it ends).
func try_swing(direction: Vector2, dash_strike: bool = false) -> bool:
	if not can_swing() or direction.length() < 0.01:
		return false
	var index := _next_swing_index if _combo_reset_left > 0.0 else 0
	var swing: AttackSwing = combo.swings[index]
	_is_dash_strike = dash_strike and combo.dash_strike != null
	if _is_dash_strike:
		swing = combo.dash_strike
		_dash_strike_resume = index
		index = -1
	var speed := get_swing_speed()
	_swing = swing
	_swing_index = index
	_swing_direction = direction.normalized()
	_swing_landed = false
	_root_released = false
	_since_hit = 0.0
	_swing_windup_left = swing.windup / speed
	_swing_left = maxf(swing.duration, swing.windup) / speed
	_swing_fresh = true
	_combo_reset_left = 0.0
	_assist_target = null
	_step_serial = -1
	unit.movement.add_move_lock(SWING_LOCK)
	if combo.attack_style == AttackCombo.AttackStyle.MELEE:
		_start_melee_step(swing, _swing_windup_left)
	Audio.play_on(swing.swing_sound, unit, swing.sound_pitch)   # whiffs included (AUDIO.md)
	swing_started.emit(index, _swing_direction, swing)
	return true


## Stops the current swing (no hit if it hasn't landed yet) and releases
## the root. A swing counts once its hit has landed (COMBAT.md): with
## keep_combo_if_landed (a cancel the player chose: a dash, a cast) and the
## hit already landed, the combo moves on as if the swing had finished, and
## combo_reset_time counts from now. Otherwise (the windup, or a forced
## interruption: stun, death) the combo resets.
func cancel_swing(keep_combo_if_landed: bool = false) -> void:
	if _swing == null:
		return
	var landed := _swing_landed
	if landed:
		_pause_left = _swing.pause_after / get_swing_speed()   # its hit happened
	var next := _get_index_after_swing()
	_stop_step()
	_end_swing()
	if landed and keep_combo_if_landed:
		_next_swing_index = next
		_combo_reset_left = combo.combo_reset_time
	else:
		_next_swing_index = 0
		_combo_reset_left = 0.0
	swing_cancelled.emit()


# --- Orders ---------------------------------------------------------------------

func attack(new_target: Unit) -> void:
	if not _is_valid_target(new_target):
		return
	if new_target == target and state != State.IDLE:
		return  # Re-clicking the same target doesn't restart the attack.
	if state == State.WINDUP:
		_cancel_windup()
	target = new_target
	state = State.CHASING
	_repath_timer = 0.0


func cancel() -> void:
	cancel_swing()
	if state == State.WINDUP:
		_cancel_windup()
	target = null
	state = State.IDLE


## Cancel the current windup but keep attacking the same target afterwards
## (used when casting an ability mid-windup).
func interrupt() -> void:
	if state == State.WINDUP:
		_cancel_windup()
		state = State.CHASING


## Auto-attack reset: the next attack can start right away.
func reset_attack_timer() -> void:
	_attack_timer = 0.0
	if state == State.BACKSWING:
		state = State.CHASING


## Empower the next auto-attack (e.g. "your next attack deals +50 damage and
## slows"). on_hit receives the target. duration < 0 = until used.
## A thin wrapper (ABILITIES AB10): it applies an empower status
## &"empower_<id>" (tags empower + buff, BASIC_ATTACK_HIT, the bonus as
## empower_base_damage, refreshed by a new call) and calls on_hit per enemy
## the swing hits when it's used up. Nothing on a unit without a
## StatusComponent (every Unit scene has one).
func add_next_attack_modifier(id: StringName, bonus_damage: float, on_hit: Callable = Callable(), duration: float = -1.0) -> void:
	var statuses := unit.status_component
	if statuses == null:
		return
	var effect := StatusEffect.new()
	effect.id = get_empower_status_id(id)
	effect.display_name = String(id)
	effect.tags = [&"empower", &"buff"]
	effect.duration = duration if duration >= 0.0 else -1.0
	effect.stack_rule = StatusEffect.StackRule.REFRESH   # a new call replaces it, as before
	effect.empower_consumed_by = StatusEffect.EmpowerTrigger.BASIC_ATTACK_HIT
	effect.empower_base_damage = bonus_damage
	if statuses.apply_status(effect, unit):
		set_empower_on_hit(effect.id, on_hit)


## A per-target callback for the basic attack empower `status_id` (ABILITIES
## AB11): when a swing uses it up, `on_hit` is called with each enemy whose
## hit got through (feel and VFX that belong to the ability's script, like
## Iron Resolve's). Forgotten when the status ends. An invalid Callable
## clears it; nothing happens if the status isn't on the unit.
func set_empower_on_hit(status_id: StringName, on_hit: Callable) -> void:
	var statuses := unit.status_component
	if statuses == null or not statuses.has_status(status_id) or not on_hit.is_valid():
		_empower_callbacks.erase(status_id)
		return
	if not statuses.status_removed.is_connected(_on_status_removed):
		statuses.status_removed.connect(_on_status_removed)
	_empower_callbacks[status_id] = on_hit


func has_next_attack_modifier(id: StringName) -> bool:
	return unit.status_component != null and unit.status_component.has_status(get_empower_status_id(id))


## The next swing that hits has a bonus (any basic attack empower).
func is_empowered() -> bool:
	return not _get_basic_attack_empowers().is_empty()


## The status id add_next_attack_modifier(id) uses: &"empower_<id>" (so it
## never replaces another status with the same id, like Iron Resolve's haste).
static func get_empower_status_id(id: StringName) -> StringName:
	return StringName("empower_" + id)


func _get_basic_attack_empowers() -> Array[StatusEffect]:
	if unit.status_component == null:
		return []
	return unit.status_component.get_empowers(StatusEffect.EmpowerTrigger.BASIC_ATTACK_HIT)


## Removes `empowers` (used up by the swing landing) and returns their
## on_hit callbacks.
func _use_up_empowers(empowers: Array[StatusEffect]) -> Array[Callable]:
	var on_hits: Array[Callable] = []
	for e in empowers:
		var f: Callable = _empower_callbacks.get(e.id, Callable())
		if f.is_valid():
			on_hits.append(f)
		unit.status_component.remove_status(e.id)
	return on_hits


func _on_status_removed(effect: StatusEffect) -> void:
	_empower_callbacks.erase(effect.id)


## A lock (stun, casting) stops attacking: it interrupts a windup and
## cancels a combo swing. The casting lock is the player's own choice, so a
## cast that cuts a landed swing's recovery keeps the combo; any other lock
## (a stun or another status) resets it.
func add_lock(id: StringName) -> void:
	_locks[id] = true
	interrupt()
	cancel_swing(id == CASTING_LOCK)


func remove_lock(id: StringName) -> void:
	_locks.erase(id)


# --- Update ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	if not unit.is_alive():
		return
	if combo != null:
		_update_combo(delta)

	if target != null and not _is_valid_target(target):
		target = null
		if state == State.WINDUP:
			_cancel_windup()
		state = State.IDLE

	if target == null or not _locks.is_empty():
		return

	match state:
		State.CHASING, State.IDLE:
			if is_in_range(target):
				unit.movement.stop()
				if _attack_timer <= 0.0:
					_start_windup()
			else:
				_repath_timer -= delta
				if _repath_timer <= 0.0 or not unit.movement.has_order():
					_repath_timer = chase_repath_interval
					unit.movement.move_to(_approach_point())
		State.WINDUP:
			_windup_left -= delta
			if _windup_left <= 0.0:
				_land_attack()
		State.BACKSWING:
			if _attack_timer <= 0.0:
				state = State.CHASING


# --- Combo swings ---------------------------------------------------------------

func _update_combo(delta: float) -> void:
	if _pause_left > 0.0:
		_pause_left = maxf(_pause_left - delta, 0.0)
	if _swing == null:
		if _combo_reset_left > 0.0:
			_combo_reset_left -= delta
			if _combo_reset_left <= 0.0:
				_next_swing_index = 0
		return
	if _swing_fresh:
		_swing_fresh = false  # Don't count the frame it started in.
		return
	if not _swing_landed:
		_swing_windup_left -= delta
		if _swing_windup_left <= SWING_TIME_EPSILON:
			_land_swing()
	else:
		_since_hit += delta
		_update_walk_cancel()
	_swing_left -= delta
	if _swing_landed and _swing_left <= SWING_TIME_EPSILON:
		_finish_swing()


## After the hit, moving (a new press or a held direction) ends the root once
## recovery_move_cancel_after has passed. The swing itself runs on, so the
## next swing still waits for its full duration and the combo continues.
func _update_walk_cancel() -> void:
	if _root_released or not combo.walk_cancels_recovery:
		return
	if _since_hit + SWING_TIME_EPSILON < combo.recovery_move_cancel_after:
		return
	if unit.movement.get_input_direction() == Vector2.ZERO:
		return
	_root_released = true
	unit.movement.remove_move_lock(SWING_LOCK)


# --- Melee swing step and target pull -------------------------------------------

## Picks the aimed enemy, snaps the aim toward it, and starts the step for
## the swing's windup (`duration`). COMBAT.md, Melee basic attacks.
func _start_melee_step(swing: AttackSwing, duration: float) -> void:
	var reach := get_swing_reach_px(swing)
	var raw_aim := _swing_direction
	var target := _find_assist_target(raw_aim, reach)
	var step_dir := raw_aim
	var step_len := swing.lunge_px
	if target:
		var to := target.global_position - unit.global_position
		var snap := deg_to_rad(combo.assist_snap_deg)
		_swing_direction = raw_aim.rotated(clampf(raw_aim.angle_to(to), -snap, snap))
		if to.length() > 0.01:
			step_dir = to.normalized()
		var edge := to.length() - target.get_gameplay_radius_px()
		var wanted := edge - combo.stop_at_reach_fraction * reach
		if wanted > swing.lunge_px:
			step_len = minf(wanted, maxf(swing.lunge_max_px, swing.lunge_px))
		# Never into its body: stop at its edge.
		var room := to.length() - unit.get_pathing_radius_px() - target.get_pathing_radius_px()
		step_len = clampf(step_len, 0.0, maxf(room, 0.0))
	_assist_target = target
	if step_len > 0.01:
		var time := maxf(duration, 0.01)
		# A stronger displacement already running (a knockback) keeps going and
		# the step is dropped; then there's no step of ours to stop later.
		if unit.movement.displace(step_dir * step_len / time, time, step_curve, true):
			_step_serial = unit.movement.get_displacement_serial()
	if debug_draw:
		_debug_plan = {"from": unit.global_position, "raw_aim": raw_aim, "aim": _swing_direction,
			"range": reach + combo.assist_range_bonus_px, "target": target,
			"step": step_dir * step_len}
		_update_debug_draw()


## The enemy the swing is aimed at: its edge within reach +
## assist_range_bonus_px of the feet, within assist_angle_deg of the aim, in
## line of sight. Smallest angle off the aim wins; ties go to the nearer one.
func _find_assist_target(aim: Vector2, reach: float) -> Unit:
	var max_range := reach + combo.assist_range_bonus_px
	var max_angle := deg_to_rad(combo.assist_angle_deg)
	var best: Unit = null
	var best_angle := INF
	var best_dist := INF
	for other in AbilityUtil.enemies_of(unit):
		var to := other.global_position - unit.global_position
		var dist := to.length()
		if dist - other.get_gameplay_radius_px() > max_range:
			continue
		var angle := absf(aim.angle_to(to)) if dist > 0.01 else 0.0
		if angle > max_angle:
			continue
		if not WorldQuery.has_line_of_sight(unit.global_position, other.global_position):
			continue
		if angle < best_angle - 0.001 or (absf(angle - best_angle) <= 0.001 and dist < best_dist):
			best = other
			best_angle = angle
			best_dist = dist
	return best


## Ends our step if it's still the running displacement (a stun, death or a
## cast cancels the swing). A knockback or dash that replaced it stays.
func _stop_step() -> void:
	if _step_serial >= 0 and unit.movement.get_displacement_serial() == _step_serial:
		unit.movement.stop_displacement()
	_step_serial = -1


func _update_debug_draw() -> void:
	if _debug_node == null:
		_debug_node = Node2D.new()
		_debug_node.name = "SwingAssistDebug"
		_debug_node.top_level = true
		_debug_node.z_index = 100
		_debug_node.draw.connect(_on_debug_node_draw)
		unit.add_child(_debug_node)
	_debug_node.queue_redraw()


func _on_debug_node_draw() -> void:
	if _debug_plan.is_empty():
		return
	var from: Vector2 = _debug_plan.from
	var raw_aim: Vector2 = _debug_plan.raw_aim
	var r: float = _debug_plan.range
	var half := deg_to_rad(combo.assist_angle_deg)
	var grey := Color(1, 1, 1, 0.35)
	_debug_node.draw_arc(from, r, raw_aim.angle() - half, raw_aim.angle() + half, 24, grey, 1.0)
	_debug_node.draw_line(from, from + raw_aim.rotated(-half) * r, grey, 1.0)
	_debug_node.draw_line(from, from + raw_aim.rotated(half) * r, grey, 1.0)
	_debug_node.draw_line(from, from + (_debug_plan.aim as Vector2) * r, Color(1, 1, 1, 0.8), 1.0)
	var target: Unit = _debug_plan.target
	if is_instance_valid(target):
		_debug_node.draw_arc(target.global_position, target.get_gameplay_radius_px(), 0.0, TAU, 24, Color(1, 0.3, 0.3), 1.5)
	_debug_node.draw_line(from, from + (_debug_plan.step as Vector2), Color(1, 0.9, 0.2), 2.0)


## The hit moment: every enemy in the arc (with hit forgiveness) takes a
## basic attack hit. Basic attack empowers (Iron Resolve's, AB10) are used up
## by the first swing that hits anything, and apply to every enemy it hits.
func _land_swing() -> void:
	_swing_landed = true
	var forgiveness := 1.0 + combo.hit_forgiveness
	var reach := get_swing_reach_px(_swing) * forgiveness
	var half_arc := deg_to_rad(_swing.arc_deg) * 0.5 * forgiveness
	var targets := AbilityUtil.in_sight(unit.global_position,
		AbilityUtil.in_cone(unit, unit.global_position, _swing_direction, reach, half_arc))   # no hits through walls
	var on_hits: Array[Callable] = []
	var empowers := _get_basic_attack_empowers()   # read at the hit moment (AB10)
	var empowered := not targets.is_empty() and not empowers.is_empty()
	if empowered:
		on_hits.append_array(_use_up_empowers(empowers))   # used up before the hits resolve
	var crit_roll := HitContext.CritRoll.new()   # one crit roll per swing
	for t in targets:
		var ctx := HitPipeline.basic_attack(unit, t, _swing)
		ctx.crit_roll = crit_roll
		if _is_dash_strike:
			ctx.add_tag(&"dash_strike")   # hit:dash_strike bonuses, reaction rules (C12)
		if empowered:
			HitPipeline.add_empowers(ctx, empowers)
		HitPipeline.resolve(ctx)
		if not ctx.blocked:
			for f in on_hits:
				if is_instance_valid(t):
					f.call(t)
	swing_landed.emit(_swing_index, targets)


func _finish_swing() -> void:
	_pause_left = _swing.pause_after / get_swing_speed()
	_next_swing_index = _get_index_after_swing()
	_combo_reset_left = combo.combo_reset_time
	_end_swing()


## The combo index after the current swing: the next swing (after the last
## one, the first), or for the dash-strike the swing it interrupted (it's not
## a combo hit, COMBAT C12).
func _get_index_after_swing() -> int:
	if _is_dash_strike:
		return _dash_strike_resume
	return (_swing_index + 1) % combo.swings.size()


func _end_swing() -> void:
	_swing = null
	_is_dash_strike = false
	_swing_landed = false
	_swing_fresh = false
	_root_released = false
	_step_serial = -1
	unit.movement.remove_move_lock(SWING_LOCK)


func _start_windup() -> void:
	state = State.WINDUP
	_windup_left = get_windup_time()
	_attack_timer = get_attack_interval()
	unit.movement.add_move_lock(&"attack_windup")
	windup_started.emit(target, _windup_left)


func _land_attack() -> void:
	unit.movement.remove_move_lock(&"attack_windup")
	state = State.BACKSWING
	var hit := target
	if not is_in_range(hit) or not WorldQuery.has_line_of_sight(unit.global_position, hit.global_position):
		attack_whiffed.emit(hit)   # Out of reach, or a wall in between: a miss.
		return
	var ctx := make_attack_context(hit)
	var empowers := _get_basic_attack_empowers()   # AB10: the same empowers as a swing
	HitPipeline.add_empowers(ctx, empowers)
	var on_hits := _use_up_empowers(empowers)
	attack_landed.emit(hit, HitPipeline.get_scaled_damage(ctx))
	HitPipeline.resolve(ctx)   # damage_increase, crit and hit:/target: scopes, like a swing
	if ctx.blocked:
		return  # I-frames block on-hit effects too.
	for f in on_hits:
		if is_instance_valid(hit):
			f.call(hit)


## The League-style attack's hit on `hit` (before empowers): 1.0 x the
## attack_damage stat, PHYSICAL, tagged basic_attack, can crit, feel NONE,
## the hit_knockback_px push away from the attacker. Pass it to
## HitPipeline.resolve().
func make_attack_context(hit: Unit) -> HitContext:
	var ctx := HitContext.new()
	ctx.source = unit
	ctx.target = hit
	ctx.ad_ratio = 1.0
	ctx.damage_type = HitContext.DamageType.PHYSICAL
	ctx.add_tag(&"basic_attack")   # on-hit and hit:basic_attack scopes (C8)
	ctx.knockback_px = hit_knockback_px
	ctx.knockback_duration = hit_knockback_duration
	ctx.knockback_from = unit.global_position
	return ctx


func _cancel_windup() -> void:
	unit.movement.remove_move_lock(&"attack_windup")
	_attack_timer = 0.0  # Cancelled attacks are refunded.
	state = State.IDLE
	windup_cancelled.emit()


## Where to walk to attack the target: a free spot just inside attack range,
## on our side of the target if possible, otherwise fanning out around it.
## This is what makes a group of melee units surround a target instead of
## queueing up behind each other.
func _approach_point() -> Vector2:
	var tpos := target.global_position
	var my_pos := unit.global_position
	var reach := get_range_px() + unit.get_gameplay_radius_px() + target.get_gameplay_radius_px()
	var dist := my_pos.distance_to(tpos)
	# Far away: just head for the target; pick a slot when we get close.
	if dist > reach + 60.0:
		return tpos
	var slot_dist := maxf(reach * 0.85, unit.get_pathing_radius_px() + target.get_pathing_radius_px() + 2.0)
	var base := (my_pos - tpos).angle() if dist > 0.01 else 0.0
	var map := unit.get_world_2d().navigation_map
	var map_ready := NavigationServer2D.map_get_iteration_id(map) > 0
	var others: Array = []
	for node in unit.get_tree().get_nodes_in_group("units"):
		var o := node as Unit
		if o != unit and o != target and o.is_alive():
			others.append(o)
	for step in 10:
		for side: float in ([1.0, -1.0] if step > 0 else [1.0]):
			var a: float = base + side * step * deg_to_rad(18.0)
			var p := tpos + Vector2.from_angle(a) * slot_dist
			# Skip spots inside walls.
			if map_ready and NavigationServer2D.map_get_closest_point(map, p).distance_to(p) > 2.0:
				continue
			var free := true
			for o: Unit in others:
				if o.global_position.distance_to(p) < unit.get_pathing_radius_px() + o.get_pathing_radius_px() + 1.0:
					free = false
					break
			if free:
				return p
	return tpos


func _is_valid_target(t: Unit) -> bool:
	return t != null and is_instance_valid(t) and t.is_targetable() and unit.is_enemy_of(t)   # untargetable: dropped (AB10)
