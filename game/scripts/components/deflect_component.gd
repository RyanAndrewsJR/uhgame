class_name DeflectComponent
extends Node
## PROTOTYPE (Ryan, 2026-10-07; tuning expected): a well-timed dash deflects
## an incoming attack instead of only dodging it, and two deflects in a row
## turn the next basic attack into a riposte. A child of a Unit (the player's,
## beside its DashComponent; Unit.deflect_component). Everything here sits
## behind deflect_test_enabled, off in shipped config: then no window opens,
## nothing is deflected, and the dash recharges as before.
##
## - The window: when the unit's dash starts (its DashComponent's
##   dash_started; any other dash can call open_window()), a window of
##   deflect_window seconds opens, a timer of its own beside the dash
##   i-frames. A hit marked deflectable (HitContext.deflectable, from
##   Ability.deflectable or a League-style attack's
##   AutoAttackComponent.deflectable) that reaches Unit.on_hit() inside it is
##   deflected (try_deflect()): ctx.deflected and ctx.blocked, so nothing of it
##   happens (no damage, knockback, statuses, on-hit, post-hit i-frames).
##   Outside the window, or any other hit: the dash i-frames block it as
##   before. A dash is still a dodge; a deflect is a dodge with timing.
## - The streak: +1 per deflect. Back to 0 when a dash's chance is over (it
##   ended, and its window closed) with nothing deflected, when chain_window
##   passes after the last deflect, and once the riposte is given. With
##   streak_persists (Ryan's test) only the riposte starts it over, and the
##   riposte waits until a swing lands.
## - The first deflect of a streak gives the dash its charge back
##   (DashComponent.add_refund_charge(): for refund_lifetime, then the normal
##   recharge; any dash spends it) and deals deflect_poise_damage_first to the
##   attacker (PoiseComponent). The second deals deflect_poise_damage_second,
##   gives no charge back and gives the riposte: an empower status
##   (empower_riposte, tags empower and buff, BASIC_ATTACK_HIT, +
##   riposte_ad_ratio of attack damage, + riposte_poise_damage, riposte_window s),
##   used up by the next swing that hits (a whiff keeps it). That swing snaps
##   toward the attacker when the step can't reach it, up to
##   riposte_snap_range (get_riposte_snap_target(); AutoAttackComponent).
## - While the flag is on, the unit's dash recharges in
##   deflect_test_charge_recharge s (DashComponent.get_recharge_time()), so a
##   refund matters (the dash's own 0.35 s would make it pointless).
## Enemies don't deflect in this prototype (they have no DashComponent; their
## dashes are abilities). A unit with this node whose dash calls open_window()
## could.

## The riposte's empower: AutoAttackComponent.get_empower_status_id(RIPOSTE_ID).
const RIPOSTE_ID := &"riposte"
## Timers at or below this are done (float residue).
const EPSILON := 0.0001

## PROTOTYPE flag, off in shipped config. The sandbox turns it on while it
## runs (SandboxDeflect, V); tests set it and put it back.
static var deflect_test_enabled: bool = false

@export_group("Window and streak")
## Seconds the window stays open from the dash's start (the dash itself lasts
## 0.18 s; its i-frames are separate).
@export_range(0.05, 0.30, 0.01) var deflect_window: float = 0.15
## The streak ends this many seconds after the last deflect.
@export var chain_window: float = 4.0
## Seconds the first deflect's refunded charge waits unused before it's taken
## back (then the normal recharge).
@export var refund_lifetime: float = 3.0
## While the flag is on, the dash recharges in this many seconds.
@export var deflect_test_charge_recharge: float = 1.5
## Ryan's test (2026-10-07: enemies attack too rarely for a 4 s chain). Off =
## the rules above: the streak ends chain_window after the last deflect or on
## a dash that deflects nothing, and the riposte lasts riposte_window. On =
## deflects bank: no chain window, a plain dash keeps them, and the riposte
## waits until a swing lands (no time limit). SandboxDeflect starts it on.
@export var streak_persists: bool = false

@export_group("Riposte")
## Added to the riposte swing's ad_ratio (a swing is 1.0: about four times a swing).
@export var riposte_ad_ratio: float = 3.0
## Seconds the riposte waits for a swing that hits.
@export var riposte_window: float = 1.5
## LoL units (300 = 3 m): the riposte swing's step toward the attacker can
## be this long. 0 = no snap.
@export var riposte_snap_range: float = 300.0

@export_group("Poise damage")
## To the attacker on the first deflect of a streak (PoiseComponent).
@export var deflect_poise_damage_first: float = 25.0
## To the attacker on the second.
@export var deflect_poise_damage_second: float = 50.0
## Added to the riposte swing's hits (its empower's empower_poise_damage, on
## top of the swing's own).
@export var riposte_poise_damage: float = 40.0

@export_group("Feel (presentation only)")
## Placeholders: none of these decide state (COMBAT's rule). The hit
## pipeline's feel on a deflect: a hitstop (s; GameFeel.hitstop(), the
## longest running one wins), 0 = none...
@export var deflect_hitstop: float = 0.08
## ...a small camera shake (GameFeel.shake(); a light swing has 0, a heavy 2), 0 = none...
@export var deflect_shake: float = 1.5
## ...and a flash on the attacker's model (UnitView reads it on
## Events.hit_deflected); alpha 0 = none.
@export var deflect_flash_color: Color = Color(1, 1, 1, 1)
## The "RIPOSTE" cue: a ring under the unit while it's ready (VFX.aura());
## alpha 0 = none.
@export var riposte_aura_color: Color = Color(1.0, 0.82, 0.35, 1.0)
## At the unit on each deflect (VFX.spawn_scene(): setup(unit, attacker)).
## null = nothing.
@export var deflect_vfx: PackedScene
## On each enemy the riposte swing lands on (setup(unit, target)). null = nothing.
@export var riposte_vfx: PackedScene
## On each deflect (Audio; a ring-out clang later). null = silent.
@export var deflect_sound: SoundEvent
## When the riposte lands. null = silent.
@export var riposte_sound: SoundEvent

var unit: Unit

var _dash: DashComponent
var _window_left: float = 0.0
var _dash_on: bool = false          # its dash is running
var _dash_pending: bool = false     # a dash's chance isn't over (it runs, or its window is open)
var _dash_deflected: bool = false   # that dash deflected something
var _streak: int = 0
var _chain_left: float = 0.0
var _riposte_target: Unit           # who the riposte answers


func _ready() -> void:
	unit = get_parent() as Unit
	assert(unit != null, "DeflectComponent must be a child of a Unit")
	# Before PlayerInput (-10) and every unit (0): a hit resolved anywhere in a
	# frame sees the window as of that frame, whatever the node order.
	process_physics_priority = -20
	_dash = unit.get_node_or_null(^"DashComponent") as DashComponent
	if _dash != null:
		_dash.dash_started.connect(_on_dash_started)
		_dash.dash_ended.connect(_on_dash_ended)


# --- Queries --------------------------------------------------------------------

## The prototype runs for this unit: the flag is on and it's alive.
func is_active() -> bool:
	return deflect_test_enabled and unit.is_alive()


## A deflectable hit now would be deflected (the flag on, the window open).
func is_window_open() -> bool:
	return is_active() and _window_left > EPSILON


func get_window_left() -> float:
	return _window_left if deflect_test_enabled else 0.0


## Deflects in a row (0–1: the second gives the riposte and starts over).
func get_streak() -> int:
	return _streak


## Seconds until the streak ends (0 = no streak).
func get_chain_left() -> float:
	return _chain_left


## The dash recharge while the flag is on (deflect_test_charge_recharge), or
## -1: off, the dash keeps its own (DashComponent.get_recharge_time()).
func get_test_recharge() -> float:
	return deflect_test_charge_recharge if deflect_test_enabled else -1.0


## The riposte empower's status id: &"empower_riposte".
static func get_riposte_status_id() -> StringName:
	return AutoAttackComponent.get_empower_status_id(RIPOSTE_ID)


## The riposte is ready (its empower is on the unit).
func has_riposte() -> bool:
	return unit.status_component != null and unit.status_component.has_status(get_riposte_status_id())


## Who the riposte answers (the second deflect's attacker), or null.
func get_riposte_target() -> Unit:
	return _riposte_target if is_instance_valid(_riposte_target) else null


## The riposte snap's longest step, px.
func get_riposte_snap_px() -> float:
	return Units.to_px(riposte_snap_range)


## The unit a swing starting now should snap to (AutoAttackComponent's melee
## step), or null: the flag on, the riposte ready, its attacker alive,
## targetable, in sight, and its edge no farther than `stop_px` (where the
## step stops short of it) plus riposte_snap_range.
func get_riposte_snap_target(stop_px: float) -> Unit:
	if not is_active() or riposte_snap_range <= 0.0 or not has_riposte():
		return null
	var target := get_riposte_target()
	if target == null or not target.is_targetable() or not unit.is_enemy_of(target):
		return null
	var edge := unit.global_position.distance_to(target.global_position) - target.get_gameplay_radius_px()
	if edge - stop_px > get_riposte_snap_px():
		return null
	if not WorldQuery.has_line_of_sight(unit.global_position, target.global_position) \
			or not AbilityUtil.can_reach(unit, target, [&"melee"] as Array[StringName]):
		return null
	return target


# --- Commands -------------------------------------------------------------------

## Opens the deflect window (deflect_window s) for a dash starting now. The
## unit's DashComponent calls it through dash_started; nothing while the flag
## is off. A dash before it whose chance wasn't over and that deflected
## nothing ends the streak first.
func open_window() -> void:
	if not is_active():
		return
	_close_dash_chance()
	_window_left = deflect_window
	_dash_pending = true
	_dash_deflected = false


## Unit.on_hit() asks first: true if `ctx` is deflected (the flag on, the
## window open, a deflectable hit from an enemy or the environment). Then it's
## blocked and marked deflected, and the streak moves on.
func try_deflect(ctx: HitContext) -> bool:
	if not ctx.deflectable or not is_window_open():
		return false
	if is_instance_valid(ctx.source) and not ctx.source.is_enemy_of(unit):
		return false
	ctx.target = unit
	ctx.deflected = true
	ctx.blocked = true
	_on_deflected(ctx)
	return true


# --- Update ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not deflect_test_enabled:
		if _streak != 0 or _window_left > 0.0 or _dash_pending:   # turned off: everything stops
			_window_left = 0.0
			_dash_pending = false
			_chain_left = 0.0
			_set_streak(0)
		return
	if _window_left > 0.0:
		_window_left = maxf(_window_left - delta, 0.0)
	if _dash_pending and not _dash_on and _window_left <= EPSILON:
		_close_dash_chance()
	if streak_persists:
		_chain_left = 0.0   # deflects bank: no chain window
	elif _chain_left > 0.0:
		_chain_left -= delta
		if _chain_left <= EPSILON:
			_chain_left = 0.0
			_set_streak(0)


func _on_dash_started(_direction: Vector2) -> void:
	_dash_on = true
	open_window()


func _on_dash_ended() -> void:
	_dash_on = false


## A dash's chance is over: with nothing deflected, the streak ends (not
## while streak_persists).
func _close_dash_chance() -> void:
	if not _dash_pending:
		return
	_dash_pending = false
	if not _dash_deflected and not streak_persists:
		_chain_left = 0.0
		_set_streak(0)


func _on_deflected(ctx: HitContext) -> void:
	var attacker: Unit = ctx.source if is_instance_valid(ctx.source) else null
	_dash_deflected = true
	_chain_left = 0.0 if streak_persists else chain_window
	_streak += 1
	if _streak == 1 and _dash != null:
		_dash.add_refund_charge(refund_lifetime)   # the second gives none: the normal recharge
	Events.hit_deflected.emit(attacker, unit, ctx)
	Events.deflect_streak_changed.emit(unit, _streak)
	_play_deflect_feel(attacker)
	if attacker != null and attacker.poise_component != null:   # the deflect itself is the source
		attacker.poise_component.take_poise_damage(deflect_poise_damage_first if _streak == 1 else deflect_poise_damage_second, unit)
	if _streak >= 2:
		_give_riposte(attacker)
		_chain_left = 0.0
		_set_streak(0)   # the payoff: the streak starts over


## The riposte: a basic attack empower status (ABILITIES AB10), refreshed by
## a new one, answering `attacker`.
func _give_riposte(attacker: Unit) -> void:
	_riposte_target = attacker
	if unit.status_component == null:
		return
	var empower := StatusEffect.new()
	empower.id = get_riposte_status_id()
	empower.display_name = "Riposte"
	empower.tags = [&"empower", &"buff"]
	empower.duration = -1.0 if streak_persists else riposte_window   # banked: until a swing lands
	empower.stack_rule = StatusEffect.StackRule.REFRESH
	empower.empower_consumed_by = StatusEffect.EmpowerTrigger.BASIC_ATTACK_HIT
	empower.empower_ad_ratio = riposte_ad_ratio
	empower.empower_poise_damage = riposte_poise_damage
	if not unit.status_component.apply_status(empower, unit):
		return
	unit.attack.set_empower_on_hit(empower.id, _on_riposte_landed)   # its feel, per enemy it lands on
	if riposte_aura_color.a > 0.0:
		var statuses := unit.status_component
		var id := empower.id
		VFX.aura(unit, riposte_aura_color, func() -> bool: return statuses.has_status(id), INF if streak_persists else riposte_window + 0.1)
	Events.riposte_ready.emit(unit)


## A deflect's feel (presentation only): hitstop, shake, sound, VFX. The
## attacker's flash is UnitView's (Events.hit_deflected).
func _play_deflect_feel(attacker: Unit) -> void:
	if deflect_hitstop > 0.0:
		GameFeel.hitstop(deflect_hitstop)
	if deflect_shake > 0.0:
		GameFeel.shake(deflect_shake)
	Audio.play_on(deflect_sound, unit)
	var angle := (attacker.global_position - unit.global_position).angle() if attacker != null else 0.0
	VFX.spawn_scene(deflect_vfx, unit, unit.global_position, angle, [unit, attacker])


## The riposte landed on `target` (AutoAttackComponent's empower callback):
## its sound and VFX.
func _on_riposte_landed(target: Unit) -> void:
	Audio.play_on(riposte_sound, unit)
	var angle := (target.global_position - unit.global_position).angle()
	VFX.spawn_scene(riposte_vfx, target, target.global_position, angle, [unit, target])


func _set_streak(value: int) -> void:
	if value == _streak:
		return
	_streak = value
	Events.deflect_streak_changed.emit(unit, _streak)
