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
##
## Strings (enemies; ARCHETYPES.md, Strings and the beat; AR1a): a brain runs
## its enemy's string (EnemyData.attack_string, an AttackCombo) through
## run_string(): combo mode's swing code for that string's hits only, then the
## League-style attack again. See run_string().

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
## A string ended (AR1a): `completed` = every hit swung and the last swing's
## recovery is over; false = cut short (a lock: a stun, a break, a cast;
## cancel(); its target turned invalid). `swung` = the swings it started.
signal string_ended(completed: bool, swung: int)

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
## PROTOTYPE (deflect, 2026-10-07): a League-style attack's hit can be
## deflected by a dash's deflect window (HitContext.deflectable;
## DeflectComponent). Off = only the dash i-frames block it, as before.
@export var deflectable: bool = false
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
var _swing_total: float = 0.0          # the swing's whole length at its speed (swing progress)
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

# Strings (AR1a)
var _string: AttackCombo               # the string running, or null
var _string_target: Unit
var _string_hits: int = 0              # the hits it runs
var _string_next: int = 0              # the next hit (= the swings started)
var _string_opener_windup: float = -1.0   # its first hit's windup (the beat); −1 = the swing's own


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
	var windup := get_attack_interval() * unit.stats.attack_windup
	if _temp_test_mult > 1.0:   # TEMP: the windup floor (the test multiplier, below)
		windup = maxf(windup, minf(enemy_attack_test_min_windup, windup * _temp_test_mult))
	return windup


func get_range_px() -> float:
	return Units.to_px(unit.stats_component.get_stat(&"attack_range"))


## League-style attack reach (edge to edge): attack_range less
## enemy_hit_forgiveness. The windup starts, and the hit lands, only within it.
func is_in_range(other: Unit) -> bool:
	return unit.edge_distance_to(other) <= get_range_px() * (1.0 - enemy_hit_forgiveness)


## A League-style attack's windup, or (AR1a) a string's swing before its hit.
func is_winding_up() -> bool:
	return state == State.WINDUP or (_string != null and _swing != null and not _swing_landed)


# --- TEMP: the enemy attack speed test multiplier --------------------------------
# A temporary test aid until enemies have their abilities (2026-10-04;
# DECISIONS.md, Testing), not a design rule. Remove this block and its three
# uses (_physics_process(), get_windup_time(), make_attack_context()) with
# SandboxBrains' TEMP block in one commit.

## TEMP: the source of the attack_speed modifier it puts on each attacker.
const TEMP_TEST_SPEED_SOURCE := &"temp_test_enemy_speed"
const TEMP_TEST_MULT_MIN := 0.5
const TEMP_TEST_MULT_MAX := 3.0

## TEMP: every League-style attacker on the enemy team (brained, fodder, or
## with no data) attacks this many times faster: one PERCENT_MULT
## attack_speed modifier, clamped to 0.5–3 when applied. 1.0 = off (the
## shipped value). Never the player (combo mode) or a unit on the player's
## team. SandboxBrains sets it outside test scenes (its starting value, the
## N panel's TEMP row).
static var enemy_attack_speed_test_mult: float = 1.0
## TEMP: each of those hits deals its damage ÷ the multiplier, so damage per
## second stays the same (faster, lighter hits). Off: DPS rises with it.
static var enemy_attack_test_keep_dps: bool = true
## TEMP: above 1, a windup never drops under this (s), nor under its own
## length at 1 when that's shorter. The interval still shrinks, so the extra
## speed comes out of the recovery.
static var enemy_attack_test_min_windup: float = 0.25

var _temp_test_mult: float = 1.0   # TEMP: the multiplier on this unit now


## TEMP: the multiplier on this unit now (1.0: off, or not an enemy-team
## League-style attacker).
func get_temp_test_mult() -> float:
	return _temp_test_mult


## TEMP: keeps this unit's modifier in step with the multiplier (a live
## change, a unit moved to the player's team). Every physics tick.
func _update_temp_test_speed() -> void:
	var mult := 1.0
	if combo == null and unit.team == Unit.Team.ENEMY:
		mult = clampf(enemy_attack_speed_test_mult, TEMP_TEST_MULT_MIN, TEMP_TEST_MULT_MAX)
	if mult == _temp_test_mult or unit.stats_component == null:
		return
	_temp_test_mult = mult
	unit.stats_component.remove_modifiers_from(TEMP_TEST_SPEED_SOURCE)
	if mult != 1.0:
		unit.stats_component.add_modifier(StatModifier.create(&"attack_speed", StatModifier.Type.PERCENT_MULT, mult - 1.0, TEMP_TEST_SPEED_SOURCE))


# --- TEMP: the weak-auto lever (PROTOTYPE deflect, 2026-10-07) --------------------
# A test lever for "autos are weak unless something empowers them" (Ryan), not
# a design rule. To revert: set it back to 1.0 here (the one line below); to
# remove: this block and its use in _land_swing().
# OFF since ARCHETYPES AR4 (2026-10-09): the stat unempowered_attack_damage
# replaced it (get_unempowered_attack_damage()) and SandboxDeflect no longer
# sets it, so it stays at 1.0. It goes once Ryan confirms the stat (Change
# policy: disable before deleting); set off 1.0, it stacks with the stat.

## TEMP: the Knight's basic attack swings that carry no empower deal this much
## of their damage (their ad_ratio x it). 1.0 = off (the shipped value), range
## 0.2–1.0. Only the tracked player's swings while it's the Knight: empowered
## swings (Iron Resolve, the riposte), enemies (League-style attacks) and any
## other champion or ally are untouched; Fury from hits is untouched (it's per
## hit). Nothing sets it since AR4 (above).
static var prototype_unempowered_auto_mult: float = 1.0


## TEMP: this unit's unempowered swings are scaled by the lever now.
func _is_prototype_weak_auto() -> bool:
	if is_equal_approx(prototype_unempowered_auto_mult, 1.0) or unit != Progress.get_tracked_player():
		return false
	var champion: Variant = unit.get(&"champion")
	return champion is ChampionData and (champion as ChampionData).id == &"knight"


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


## Seconds until the running swing's hit (0 = none, or it landed).
func get_swing_windup_left() -> float:
	return maxf(_swing_windup_left, 0.0) if _swing != null and not _swing_landed else 0.0


## ABILITIES AB14: how far the running swing is, 0 (start) to 1 (it ends):
## the time since it started ÷ its length at the combo speed. 0 when not
## swinging. The 3D view positions the model's swing_anim by it (UnitView).
func get_swing_progress() -> float:
	if _swing == null or _swing_total <= 0.0:
		return 0.0
	return clampf(1.0 - _swing_left / _swing_total, 0.0, 1.0)


## Combo speed multiplier: attack_speed / base attack speed (1.0 at base;
## +20% bonus attack speed = 1.2), times the combo's speed_scale. Every
## swing timing is divided by it. AR1a: a string's is its speed_scale alone
## (the beat and its spacing are fixed reads, so attack speed doesn't change
## them; proposed).
func get_swing_speed() -> float:
	if _string != null:
		return maxf(_string.speed_scale, 0.01)
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
	_begin_swing(swing, index, direction, swing.windup / speed, maxf(swing.duration, swing.windup) / speed)
	return true


## Starts `swing` (index `index`) toward `direction`, winding up for `windup`
## s and lasting `total` s in all: the root, the melee step, the sound, the
## swing_vfx hook, swing_started. Combo mode's swings and a string's (AR1a).
func _begin_swing(swing: AttackSwing, index: int, direction: Vector2, windup: float, total: float) -> void:
	_swing = swing
	_swing_index = index
	_swing_direction = direction.normalized()
	_swing_landed = false
	_root_released = false
	_since_hit = 0.0
	_swing_windup_left = windup
	_swing_left = total
	_swing_total = _swing_left
	_swing_fresh = true
	_combo_reset_left = 0.0
	_assist_target = null
	_step_serial = -1
	unit.movement.add_move_lock(SWING_LOCK)
	if _get_swing_combo().attack_style == AttackCombo.AttackStyle.MELEE:
		_start_melee_step(swing, _swing_windup_left)
	Audio.play_on(swing.swing_sound, unit, swing.sound_pitch)   # whiffs included (AUDIO.md)
	# AB14 hook (nothing while empty): swing_vfx now. The 3D view positions the
	# model's swing_anim by swing progress (UnitView).
	VFX.spawn_scene(swing.swing_vfx, unit, unit.global_position, _swing_direction.angle(), [unit, swing])
	swing_started.emit(index, _swing_direction, swing)


## Stops the current swing (no hit if it hasn't landed yet) and releases
## the root. A swing counts once its hit has landed (COMBAT.md): with
## keep_combo_if_landed (a cancel the player chose: a dash, a cast) and the
## hit already landed, the combo moves on as if the swing had finished, and
## combo_reset_time counts from now. Otherwise (the windup, or a forced
## interruption: stun, death) the combo resets. A string's swing (AR1a):
## the string ends there, cut short.
func cancel_swing(keep_combo_if_landed: bool = false) -> void:
	if _swing == null:
		return
	if _string != null:
		_stop_step()
		_end_swing()
		swing_cancelled.emit()
		_end_string(false)
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
	if _string != null:
		_end_string(false)   # AR1a: a string still chasing, or between swings
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


## ARCHETYPES AR4 (D12, weak basic attacks): x the damage of a swing that
## carries no empower (its ad_ratio x it): the unit's unempowered_attack_damage
## stat, 0.5 on every champion and 1 on enemies. An empowered swing is full;
## the resource a hit gives (the Knight's Fury) is per hit, so it's unchanged.
func get_unempowered_attack_damage() -> float:
	return unit.stats_component.get_stat(&"unempowered_attack_damage") if unit.stats_component != null else 1.0


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
	if _string != null:
		_end_string(false)   # AR1a: a stun, a break or a cast cuts a string short


func remove_lock(id: StringName) -> void:
	_locks.erase(id)


# --- Strings (ARCHETYPES.md, Strings and the beat; AR1a) ---------------------------

## Runs `hits` hits of `attack_string` (an enemy's EnemyData.attack_string) at
## `new_target`, on combo mode's swing code (the windup, the melee step and
## pull, the swing's timings and knockback), in place of the League-style
## attack until it ends:
## - it chases until the target is within its first swing's reach (less
##   enemy_hit_forgiveness, like a League-style attack), then swings; a
##   RANGED string (AR1b, the Mage's volley) only until the target is within
##   its shot's range and in sight (is_string_in_reach()), and each hit
##   moment fires a shot (Projectile.fire_swing()) instead of the arc's hit;
## - each later hit starts as the swing before it ends (after its
##   pause_after), aimed at the target where it stands then; its hit lands
##   on whatever is in the swing's arc (reach and arc × (1 −
##   enemy_hit_forgiveness)). Hits past the string's last swing repeat it;
## - once its first swing starts it runs to its end: a dodge or a deflect
##   doesn't end it (D10; a commit can't be taken back);
## - its first swing winds up for `opener_windup` s when that's 0 or more (the
##   beat, EnemyAITable.beat), keeping the swing's own recovery (duration −
##   windup); every other timing is the swing's ÷ get_swing_speed();
## - a lock (a stun, a poise break, a cast), cancel(), death or its target
##   turning invalid (dead, untargetable) cuts it short.
## string_ended when it ends. False (nothing runs) in combo mode, under a
## lock, for no swings, hits under 1 or an invalid target.
func run_string(new_target: Unit, attack_string: AttackCombo, hits: int, opener_windup: float = -1.0) -> bool:
	if combo != null or attack_string == null or attack_string.swings.is_empty() or hits < 1 \
			or not _is_valid_target(new_target) or not _locks.is_empty() or not unit.is_alive():
		return false
	if _string != null:
		cancel_swing()
		_end_string(false)
	if state == State.WINDUP:
		_cancel_windup()
	target = null
	state = State.IDLE
	_string = attack_string
	_string_target = new_target
	_string_hits = hits
	_string_next = 0
	_string_opener_windup = opener_windup
	_pause_left = 0.0
	_repath_timer = 0.0
	return true


## A string is running (chasing for its first swing, swinging, or between
## swings).
func is_running_string() -> bool:
	return _string != null


## The running string's length in hits (0 = none).
func get_string_hits() -> int:
	return _string_hits if _string != null else 0


## The running string's swings started so far, the one under way included
## (0 = still chasing, or none).
func get_string_swung() -> int:
	return _string_next if _string != null else 0


func get_string_target() -> Unit:
	return _string_target if _string != null and is_instance_valid(_string_target) else null


## Seconds until the running string ends on its rhythm: the swing under way
## (or the pause before the next), then each hit left; before its first swing,
## its whole length (the chase not counted). 0 = none.
func get_string_time_left() -> float:
	if _string == null:
		return 0.0
	var left := maxf(_swing_left, 0.0) if _swing != null else 0.0
	if _swing != null and _string_next < _string_hits:
		left += _swing.pause_after / get_swing_speed()
	elif _swing == null and _string_next > 0:
		left += _pause_left
	for k in range(_string_next, _string_hits):
		left += get_string_hit_length(k)
		if k < _string_hits - 1:
			left += _get_string_swing(k).pause_after / get_swing_speed()
	return left


## Seconds until the running string's next hit lands (the swing under way's,
## else the next swing's; −1 = none, or still chasing).
func get_string_next_hit_in() -> float:
	if _string == null or (_swing == null and _string_next == 0):
		return -1.0
	if _swing != null and not _swing_landed:
		return maxf(_swing_windup_left, 0.0)
	if _string_next >= _string_hits:
		return -1.0
	var wait := 0.0
	if _swing != null:
		wait = maxf(_swing_left, 0.0) + _swing.pause_after / get_swing_speed()
	else:
		wait = _pause_left
	return wait + get_string_hit_windup(_string_next)


## Hit `k` of the running string: its windup (s; the opener's is the beat
## when run_string() got one).
func get_string_hit_windup(k: int) -> float:
	if _string == null:
		return 0.0
	if k == 0 and _string_opener_windup >= 0.0:
		return _string_opener_windup
	return _get_string_swing(k).windup / get_swing_speed()


## Hit `k` of the running string: its whole swing, windup and recovery (s).
func get_string_hit_length(k: int) -> float:
	if _string == null:
		return 0.0
	var swing := _get_string_swing(k)
	return get_string_hit_windup(k) + maxf(swing.duration - swing.windup, 0.0) / get_swing_speed()


## The swing hit `k` of the running string uses: its own, past the last one
## the last.
func _get_string_swing(k: int) -> AttackSwing:
	return _string.swings[clampi(k, 0, _string.swings.size() - 1)]


## The combo the swing code reads: the running string, else combo mode's.
func _get_swing_combo() -> AttackCombo:
	return _string if _string != null else combo


## The running string is RANGED (AR1b: a volley of shots).
func _is_ranged_string() -> bool:
	return _string != null and _string.attack_style == AttackCombo.AttackStyle.RANGED


## The running string's first swing may start on `t` from here: a melee
## string's within that swing's reach (less enemy_hit_forgiveness, as a
## League-style attack); a RANGED string's (AR1b) with `t` within its shot's
## range (from this unit's center to `t`'s edge, less enemy_hit_forgiveness)
## and in sight. False with no string.
func is_string_in_reach(t: Unit) -> bool:
	if _string == null:
		return false
	return is_in_reach_of_string(_string, t)


## `attack_string`'s first swing could start on `t` from here, by
## is_string_in_reach()'s rule, before that string runs (R0's quirk fix,
## 2026-10-08: the brain closes in on foot until then, so a cast that comes
## into reach first never cuts a string it started). False with no swings.
func is_in_reach_of_string(attack_string: AttackCombo, t: Unit) -> bool:
	if attack_string == null or attack_string.swings.is_empty() or not is_instance_valid(t):
		return false
	var swing := attack_string.swings[0]
	if attack_string.attack_style == AttackCombo.AttackStyle.RANGED:
		var reach := Units.to_px(swing.projectile_range) * (1.0 - enemy_hit_forgiveness)
		return unit.global_position.distance_to(t.global_position) - t.get_gameplay_radius_px() <= reach \
			and WorldQuery.has_line_of_sight(unit.global_position, t.global_position)
	return unit.edge_distance_to(t) <= get_swing_reach_px(swing) * (1.0 - enemy_hit_forgiveness)


## Closes in on `t` for `attack_string`'s first swing, as a running string
## chases (_update_string()), without attacking: the brain's walk-in before
## it starts its string (R0's quirk fix). Call it every physics tick of the
## walk-in.
func approach_for_string(attack_string: AttackCombo, t: Unit, delta: float) -> void:
	if attack_string == null or not is_instance_valid(t):
		return
	_repath_timer -= delta
	if _repath_timer <= 0.0 or not unit.movement.has_order():
		_repath_timer = chase_repath_interval
		if attack_string.attack_style == AttackCombo.AttackStyle.RANGED:
			unit.movement.move_to(t.global_position)   # straight in, until in range and in sight
		else:
			unit.movement.move_to(_approach_point_to(t))


## AR1b: a RANGED string's hit moment: one shot (Projectile.fire_swing()) at
## the string's target where it stands now.
func _fire_string_shot(swing: AttackSwing) -> void:
	if not is_instance_valid(_string_target):
		return
	var to := _string_target.global_position - unit.global_position
	var direction := to.normalized() if to.length() > 0.01 else _swing_direction
	_swing_direction = direction
	Projectile.fire_swing(unit, swing, unit.global_position, direction)


## Each physics tick while a string runs: it ends when its target turns
## invalid or its last swing is over; else the next hit starts as soon as no
## swing, pause or lock holds it (the first one once the target is in reach;
## until then it chases, like the League-style attack).
func _update_string(delta: float) -> void:
	if not _is_valid_target(_string_target):
		cancel_swing()   # a string's swing: ends it too
		_end_string(false)
		return
	if _swing != null:
		return
	if _string_next >= _string_hits:
		_end_string(true)
		return
	if not _locks.is_empty() or _pause_left > 0.0:
		return
	if _string_next == 0 and not is_string_in_reach(_string_target):
		_repath_timer -= delta
		if _repath_timer <= 0.0 or not unit.movement.has_order():
			_repath_timer = chase_repath_interval
			if _is_ranged_string():
				unit.movement.move_to(_string_target.global_position)   # AR1b: straight in, until in range and in sight
			else:
				unit.movement.move_to(_approach_point_to(_string_target))
		return
	var k := _string_next
	var to := _string_target.global_position - unit.global_position
	var direction := to.normalized() if to.length() > 0.01 else _swing_direction
	unit.movement.stop()
	_string_next += 1
	_begin_swing(_get_string_swing(k), k, direction, get_string_hit_windup(k), get_string_hit_length(k))
	# Started inside this tick's update (after _update_combo()), unlike a
	# player's swing, which starts before it: the next tick is its first, so
	# it isn't skipped (or every hit would come a tick late).
	_swing_fresh = false


## Ends the running string (string_ended). The caller stops its swing first.
func _end_string(completed: bool) -> void:
	if _string == null:
		return
	var swung := _string_next
	_string = null
	_string_target = null
	_string_hits = 0
	_string_next = 0
	_string_opener_windup = -1.0
	_pause_left = 0.0
	string_ended.emit(completed, swung)


# --- Update ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_update_temp_test_speed()   # TEMP: the enemy attack speed test multiplier
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	if not unit.is_alive():
		if _string != null:
			cancel_swing()
			_end_string(false)   # AR1a: death cuts a string short
		return
	if combo != null or _string != null:
		_update_combo(delta)
	if _string != null:
		_update_string(delta)   # AR1a: the League-style attack waits for the string's end
		return

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
	if _string != null:
		return   # AR1a: a string's swings run their whole length (no input walks them out)
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
	var c := _get_swing_combo()
	var reach := get_swing_reach_px(swing)
	var raw_aim := _swing_direction
	var assist := _find_assist_target(raw_aim, reach)
	var step_dir := raw_aim
	var step_len := swing.lunge_px
	var max_step := maxf(swing.lunge_max_px, swing.lunge_px)
	var snap_deg := c.assist_snap_deg
	# PROTOTYPE (deflect): a riposte swing snaps to the attacker it answers, aim
	# and all, a step of up to riposte_snap_range (DeflectComponent). Null when
	# the flag is off or there's no riposte: the step is exactly as before.
	var riposte := unit.deflect_component.get_riposte_snap_target(c.stop_at_reach_fraction * reach) \
		if unit.deflect_component != null else null
	if riposte != null:
		assist = riposte
		max_step = maxf(max_step, unit.deflect_component.get_riposte_snap_px())
		snap_deg = 180.0
	if assist:
		var to := assist.global_position - unit.global_position
		var snap := deg_to_rad(snap_deg)
		_swing_direction = raw_aim.rotated(clampf(raw_aim.angle_to(to), -snap, snap))
		if to.length() > 0.01:
			step_dir = to.normalized()
		var edge := to.length() - assist.get_gameplay_radius_px()
		var wanted := edge - c.stop_at_reach_fraction * reach
		if wanted > swing.lunge_px:
			step_len = minf(wanted, max_step)
		# Never into its body: stop at its edge.
		var room := to.length() - unit.get_pathing_radius_px() - assist.get_pathing_radius_px()
		step_len = clampf(step_len, 0.0, maxf(room, 0.0))
	_assist_target = assist
	# Rooted or stunned: the swing stays where it stands (roots are roots,
	# 2026-10-04); the aim still snaps to the target.
	if step_len > 0.01 and not unit.is_dash_blocked():
		var time := maxf(duration, 0.01)
		# A stronger displacement already running (a knockback) keeps going and
		# the step is dropped; then there's no step of ours to stop later.
		if unit.movement.displace(step_dir * step_len / time, time, step_curve, true):
			_step_serial = unit.movement.get_displacement_serial()
	if debug_draw:
		_debug_plan = {"from": unit.global_position, "raw_aim": raw_aim, "aim": _swing_direction,
			"range": reach + c.assist_range_bonus_px, "target": assist,
			"step": step_dir * step_len}
		_update_debug_draw()


## The enemy the swing is aimed at: its edge within reach +
## assist_range_bonus_px of the feet, within assist_angle_deg of the aim, in
## line of sight. Smallest angle off the aim wins; ties go to the nearer one.
func _find_assist_target(aim: Vector2, reach: float) -> Unit:
	var c := _get_swing_combo()
	var max_range := reach + c.assist_range_bonus_px
	var max_angle := deg_to_rad(c.assist_angle_deg)
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
		# Melee aim help never snaps to a target the swing can't hit (a perched
		# enemy from below; 3D.md, Terrain and height 2).
		if c.attack_style == AttackCombo.AttackStyle.MELEE and not AbilityUtil.can_reach(unit, other, [&"melee"] as Array[StringName]):
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
		_debug_node.visibility_layer |= FloorOverlay.DRAWING_VISIBILITY_BIT   # shows on the 3D floor (the cleanup's C2)
		_debug_node.draw.connect(_on_debug_node_draw)
		unit.add_child(_debug_node)
	_debug_node.queue_redraw()


func _on_debug_node_draw() -> void:
	if _debug_plan.is_empty():
		return
	var from: Vector2 = _debug_plan.from
	var raw_aim: Vector2 = _debug_plan.raw_aim
	var r: float = _debug_plan.range
	var c := _get_swing_combo()
	var half := deg_to_rad(c.assist_angle_deg if c != null else 0.0)
	var grey := Color(1, 1, 1, 0.35)
	_debug_node.draw_arc(from, r, raw_aim.angle() - half, raw_aim.angle() + half, 24, grey, 1.0)
	_debug_node.draw_line(from, from + raw_aim.rotated(-half) * r, grey, 1.0)
	_debug_node.draw_line(from, from + raw_aim.rotated(half) * r, grey, 1.0)
	_debug_node.draw_line(from, from + (_debug_plan.aim as Vector2) * r, Color(1, 1, 1, 0.8), 1.0)
	var plan_target: Unit = _debug_plan.target
	if is_instance_valid(plan_target):
		_debug_node.draw_arc(plan_target.global_position, plan_target.get_gameplay_radius_px(), 0.0, TAU, 24, Color(1, 0.3, 0.3), 1.5)
	_debug_node.draw_line(from, from + (_debug_plan.step as Vector2), Color(1, 0.9, 0.2), 2.0)


## The hit moment: every enemy in the arc (with hit forgiveness) takes a
## basic attack hit. Basic attack empowers (Iron Resolve's, AB10) are used up
## by the first swing that hits anything, and apply to every enemy it hits.
## A swing marked deflectable (AttackSwing.deflectable) gives its hits that
## mark (AR1a). The swing is read once: a hit that locks the attacker (a
## deflect that breaks its poise) cancels it mid-loop. A swing with no
## empower deals x get_unempowered_attack_damage() (AR4: weak basic attacks;
## the dash-strike too).
func _land_swing() -> void:
	_swing_landed = true
	var swing := _swing
	var index := _swing_index
	if _is_ranged_string():
		_fire_string_shot(swing)   # AR1b: a volley's bolt; its hit comes when it reaches someone
		swing_landed.emit(index, [] as Array[Unit])
		return
	var forgiveness := _get_hit_scale()
	var reach := get_swing_reach_px(swing) * forgiveness
	var half_arc := deg_to_rad(swing.arc_deg) * 0.5 * forgiveness
	var targets := AbilityUtil.in_sight(unit.global_position,
		AbilityUtil.in_cone(unit, unit.global_position, _swing_direction, reach, half_arc))   # no hits through walls
	var on_hits: Array[Callable] = []
	var empowers := _get_basic_attack_empowers()   # read at the hit moment (AB10)
	var empowered := not targets.is_empty() and not empowers.is_empty()
	if empowered:
		on_hits.append_array(_use_up_empowers(empowers))   # used up before the hits resolve
	var crit_roll := HitContext.CritRoll.new()   # one crit roll per swing
	var weak := not empowered and _is_prototype_weak_auto()   # TEMP: the weak-auto lever
	var unempowered := 1.0 if empowered else get_unempowered_attack_damage()   # AR4: weak basic attacks
	var landed := false   # CHAMPIONS K3: a hit got through (resource_on_land)
	for t in targets:
		var ctx := HitPipeline.basic_attack(unit, t, swing)
		ctx.deflectable = swing.deflectable   # AR1a
		ctx.crit_roll = crit_roll
		if _is_dash_strike:
			ctx.add_tag(&"dash_strike")   # hit:dash_strike bonuses, reaction rules (C12)
		if empowered:
			HitPipeline.add_empowers(ctx, empowers)
		else:
			ctx.ad_ratio *= unempowered   # AR4
			if weak:
				ctx.ad_ratio *= clampf(prototype_unempowered_auto_mult, 0.2, 1.0)   # TEMP
		HitPipeline.resolve(ctx)
		if not ctx.blocked:
			landed = true
			for f in on_hits:
				if is_instance_valid(t):
					f.call(t)
			if is_instance_valid(t):   # AB14 hook: nothing while impact_vfx is empty
				VFX.spawn_scene(swing.impact_vfx, t, t.global_position, (t.global_position - unit.global_position).angle(), [unit, ctx])
	if landed and swing.resource_on_land > 0.0 and unit.resource_pool != null and unit.is_alive():
		unit.resource_pool.restore(swing.resource_on_land)   # once per swing (CHAMPIONS K3)
	swing_landed.emit(index, targets)


## Reach and arc at a swing's hit: combo mode's × (1 + its hit_forgiveness:
## the player's attacks hit a bit beyond what they show); a string's (AR1a)
## × (1 − enemy_hit_forgiveness: a bit shorter, like a League-style attack).
func _get_hit_scale() -> float:
	if _string != null:
		return 1.0 - enemy_hit_forgiveness
	return 1.0 + combo.hit_forgiveness


func _finish_swing() -> void:
	_pause_left = _swing.pause_after / get_swing_speed()
	if _string != null:
		_end_swing()   # AR1a: the string's next hit comes from _update_string()
		return
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
	if _temp_test_mult != 1.0 and enemy_attack_test_keep_dps:
		ctx.ad_ratio /= _temp_test_mult   # TEMP: lighter hits, the same damage per second
	ctx.damage_type = HitContext.DamageType.PHYSICAL
	ctx.deflectable = deflectable   # PROTOTYPE (deflect)
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
	return _approach_point_to(target)


## _approach_point() for any target (AR1a: a string's chase uses it too).
func _approach_point_to(t: Unit) -> Vector2:
	var tpos := t.global_position
	var my_pos := unit.global_position
	var reach := get_range_px() + unit.get_gameplay_radius_px() + t.get_gameplay_radius_px()
	var dist := my_pos.distance_to(tpos)
	# Far away: just head for the target; pick a slot when we get close.
	if dist > reach + 60.0:
		return tpos
	var slot_dist := maxf(reach * 0.85, unit.get_pathing_radius_px() + t.get_pathing_radius_px() + 2.0)
	var base := (my_pos - tpos).angle() if dist > 0.01 else 0.0
	var map := unit.get_world_2d().navigation_map
	var map_ready := NavigationServer2D.map_get_iteration_id(map) > 0
	var others: Array = []
	for node in unit.get_tree().get_nodes_in_group("units"):
		var o := node as Unit
		if o != unit and o != t and o.is_alive():
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
