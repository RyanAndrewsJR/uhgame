class_name Player
extends Unit
## The player's champion (MOVEMENT.md, Input map):
##   WASD                - walk (PlayerInput)
##   Space               - dash toward the cursor (DashComponent)
##   Left mouse          - the basic attack combo toward the cursor (PlayerInput)
##   Q / right mouse (W) / E / R - abilities (see cast_mode)
##   Esc                 - cancels an aim or a charge-up, else the pause menu

## How INSTANT abilities cast (ABILITIES.md, Cast mode). The player picks it
## in the pause menu (Settings); CHANNEL and SELF abilities always cast on press.
enum CastMode {
	## Hold the key to see the indicator, release to cast. Esc cancels.
	QUICK_WITH_INDICATOR,
	## Cast instantly at the cursor when the key is pressed (the default).
	QUICK,
}

## What the player is doing, derived each physics frame from the components
## (MOVEMENT.md "Player states"). Priority: STUNNED > DASH > CASTING >
## ATTACK (a rooted combo swing, whose melee step is a displacement) >
## DISPLACED > MOVE > IDLE.
enum State {
	IDLE,       ## Standing still, free to act.
	MOVE,       ## Walking (WASD, or a path such as R walking into range).
	DASH,       ## The player's own dash (added in movement step 6).
	ATTACK,     ## A basic attack swing while it roots (windup and recovery).
	CASTING,    ## An ability is being cast (includes Lunge's dash).
	STUNNED,    ## Stunned: can't move, attack or cast.
	DISPLACED,  ## Pushed by something else (knockback, pull); can't walk.
}

signal state_changed(from: State, to: State)

const ABILITY_ACTIONS := {&"q": "ability_q", &"w": "ability_w", &"e": "ability_e", &"r": "ability_r"}

## The champion this player is (CHAMPIONS.md). Its stats, slots, combo,
## sounds and resource type replace this scene's own exports at load
## (_apply_champion()). null = the scene's exports, exactly as before. Set it
## before the Player enters the tree (the hub, later).
@export var champion: ChampionData

## Set from Settings at start and whenever the player changes it in the
## pause menu, so an Inspector value only lasts until then.
@export var cast_mode: CastMode = CastMode.QUICK
## How close (px) the cursor must be to an enemy for targeted abilities.
@export var target_forgiveness: float = 14.0
## Shows the current State name above the player.
@export var debug_draw: bool = false
## Post-hit i-frames read as a blink: the body shows for 60% of each period
## (seconds). Visual only.
@export var hit_iframes_blink_period: float = 0.1

@export_group("Low health")
## Loops while health is below low_health_fraction of max (AUDIO.md). The
## health bar shows it too (never audio-only). null = silent.
@export var low_health_sound: SoundEvent
@export_range(0.15, 0.35) var low_health_fraction: float = 0.25
@export_group("")

@onready var sword_pivot: Node2D = $SwordPivot
@onready var sword: Polygon2D = $SwordPivot/Sword
@onready var dash: DashComponent = $DashComponent
@onready var player_input: PlayerInput = $PlayerInput

## Which ability is being aimed (QUICK_WITH_INDICATOR), or &"".
var aiming_slot: StringName = &""
## A charge-up started by the player's own key press (so letting the key go,
## even unseen, releases it; ABILITIES AB6).
var _charge_from_input: bool = false
## The indicator slot the last _draw() drew (&"" = none); tests read it.
var _drawn_indicator_slot: StringName = &""
## The VECTOR start point the last _draw() drew (INF = none; AB13); tests read it.
var _drawn_vector_start: Vector2 = Vector2.INF
## Alternates each swing so consecutive slashes go opposite ways.
var swing_side: float = 1.0
## Current State (read-only for other code; see _update_state()).
var state: State = State.IDLE
## Which way the player looks (unit vector). Units don't rotate; the
## animation layer will pick one of 8 sprites from this (MOVEMENT.md).
var facing: Vector2 = Vector2.RIGHT

var _hovered_enemy: Unit
var _walk_time: float = 0.0
## Where the current cast was aimed, locked at cast start (INF = none).
var _cast_face_point: Vector2 = Vector2.INF
var _blink_time: float = 0.0
var _low_health_handle: int = 0
## The sword pull-back tween of the current swing's windup.
var _swing_tween: Tween


func _ready() -> void:
	team = Team.PLAYER
	if champion != null:
		_apply_champion()
	super._ready()
	if champion != null:
		_attach_champion()
	add_to_group("player")
	attack.swing_started.connect(_on_swing_started)
	attack.swing_landed.connect(_on_swing_landed)
	attack.swing_cancelled.connect(_on_swing_cancelled)
	abilities.cast_started.connect(_on_cast_started)
	abilities.cast_finished.connect(_on_cast_finished)
	dash.dash_started.connect(_on_dash_started)
	dash.dash_ended.connect(_on_dash_ended)
	health.health_changed.connect(_on_health_health_changed)
	cast_mode = Settings.get_cast_mode()
	Settings.setting_changed.connect(_on_settings_setting_changed)
	abilities.charge_ended.connect(_on_abilities_charge_ended)


## Copies the champion onto this unit and its nodes (CHAMPIONS.md, Loading a
## champion). Runs before Unit._ready(), which sets up stats, health and the
## resource pool from them. The children's _ready() has already run, but none
## of them reads these exports there. The champion level is never read here.
func _apply_champion() -> void:
	stats = champion.stats
	abilities.q = champion.q
	abilities.w = champion.w
	abilities.e = champion.e
	abilities.r = champion.r
	attack.combo = champion.combo
	hurt_sound = champion.hurt_sound
	death_sound = champion.death_sound
	low_health_sound = champion.low_health_sound
	if resource_pool == null:
		return
	if champion.resource_type == ResourceComponent.ResourceType.NONE:
		# No resource: no pool node, so no costs and no resource bar.
		remove_child(resource_pool)
		resource_pool.queue_free()
		resource_pool = null
	else:
		resource_pool.resource_type = champion.resource_type
		resource_pool.starts_empty = champion.resource_starts_empty
		resource_pool.decay_per_second = champion.resource_decay_per_second
		resource_pool.decay_delay = champion.resource_decay_delay


## After Unit._ready() (the StatsComponent is set up): the champion's own
## modifiers under champion_<id> (CH3), then its passive under passive_<id> (CH2).
func _attach_champion() -> void:
	var copies: Array[StatModifier] = []
	for mod in champion.modifiers:
		if mod != null:
			var copy: StatModifier = mod.duplicate()
			copy.source_id = champion.get_champion_source_id()
			copies.append(copy)
	if not copies.is_empty():
		stats_component.add_modifiers(copies)
	if champion.passive != null:
		champion.passive.apply_to(self, champion.get_passive_source_id())


func _on_settings_setting_changed(key: StringName, _value: Variant) -> void:
	if key == Settings.CAST_MODE:
		# An aim in progress finishes as it started (release casts); the new
		# mode applies from the next press.
		cast_mode = Settings.get_cast_mode()


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

	if event.is_action_pressed("ui_cancel"):
		if aiming_slot != &"":
			aiming_slot = &""
			queue_redraw()
			# This Esc only cancels the aim; it doesn't open the pause menu.
			get_viewport().set_input_as_handled()
		elif abilities.try_cancel_charge():
			# Esc cancels a charge-up (full refund) and doesn't pause either.
			_charge_from_input = false
			queue_redraw()
			get_viewport().set_input_as_handled()


func _on_ability_pressed(slot: StringName) -> void:
	var ability := abilities.get_ability(slot)
	if ability == null:
		return
	# The cast mode only applies to INSTANT abilities: channels always cast on
	# press, CHARGE_UP always holds and releases (ABILITIES.md, Cast mode).
	# A press inside a recast window casts the next part at once, whatever the
	# style (ABILITIES AB5), except a VECTOR part: every part is aimed (AB13).
	var vector := ability.cast_style == Ability.CastStyle.VECTOR
	if abilities.get_recast_part(slot) > 0 and not vector:
		request_cast(slot)
		return
	if ability.cast_style == Ability.CastStyle.CHARGE_UP or vector:
		request_charge(slot)
		return
	var instant := cast_mode == CastMode.QUICK or ability.targeting == Ability.Targeting.SELF \
		or ability.is_channel()
	if instant:
		request_cast(slot)
	else:
		aiming_slot = slot
		queue_redraw()


func _on_ability_released(slot: StringName) -> void:
	if abilities.is_charging() and abilities.casting_slot == slot:
		_release_charge()
		return
	if aiming_slot == slot:
		aiming_slot = &""
		queue_redraw()
		request_cast(slot)


## Input path for a CHARGE_UP or VECTOR press: start holding now if allowed (the same
## rules as request_cast(): a swing is cut per cancels_swing, no charging
## while dashing, "not enough resource" fails at once), otherwise buffer the
## press (PlayerInput fires it through start_buffered_ability()).
func request_charge(slot: StringName) -> void:
	if abilities.is_ready(slot) and not is_cast_blocked() and not abilities.can_afford(slot):
		abilities.fail_cast(slot, AbilityComponent.FAIL_NO_RESOURCE)
	elif abilities.is_ready(slot) and not is_cast_blocked() and not abilities.conditions_pass(slot, get_global_mouse_position()):
		abilities.fail_cast(slot, AbilityComponent.FAIL_CONDITION)   # AB12: not buffered
	elif abilities.can_cast(slot) and not dash.is_dashing() and can_interrupt_swing(slot):
		_start_charge(slot)
	else:
		player_input.buffer_action(slot)


## A buffered Q/W/E/R press that became legal (PlayerInput). A CHARGE_UP
## press starts charging; if its key was already let go, it fires at once as
## a tap (charge 0; ABILITIES.md, Open questions, proposed). A VECTOR press
## (any part) does the same: its start point goes where the cursor is now,
## and a let-go key makes it a tap (AB13).
func start_buffered_ability(slot: StringName) -> void:
	var ability := abilities.get_ability(slot)
	if ability != null and (ability.cast_style == Ability.CastStyle.VECTOR \
			or (ability.cast_style == Ability.CastStyle.CHARGE_UP and abilities.get_recast_part(slot) == 0)):
		if _start_charge(slot) and not Input.is_action_pressed(ABILITY_ACTIONS[slot]):
			# A VECTOR tap releases on its own start point (no drag); a
			# charge-up (no start point: INF) at the cursor.
			_release_charge(abilities.get_vector_start())
		return
	cast_ability(slot)


func _start_charge(slot: StringName) -> bool:
	if not abilities.try_start_charge(slot, get_global_mouse_position()):
		return false
	_charge_from_input = true
	queue_redraw()
	return true


## Releases the hold at `aim` (INF = the cursor).
func _release_charge(aim: Vector2 = Vector2.INF) -> void:
	_charge_from_input = false
	abilities.release_charge(aim if aim != Vector2.INF else get_global_mouse_position())
	queue_redraw()


## The ability whose indicator shows: the one being aimed (hold to aim), or
## the charge-up, from its press until its effect starts (ABILITIES AB6).
## &"" if none.
func get_indicator_slot() -> StringName:
	if aiming_slot != &"":
		return aiming_slot
	if abilities.has_charge_indicator():
		return abilities.casting_slot
	return &""


## Where the indicator points: the aim a charge-up locked at release (its
## release windup), otherwise the cursor.
func get_indicator_aim() -> Vector2:
	var locked := abilities.get_locked_charge_aim()
	return locked if locked != Vector2.INF else get_global_mouse_position()


## Any way a charge-up ends (AbilityComponent's one end-charge path): the
## indicator must be redrawn away, even when nothing else asks for a redraw.
func _on_abilities_charge_ended(_slot: StringName, _ability: Ability) -> void:
	_charge_from_input = false
	queue_redraw()


## Input path for Q/W/E/R: casts now if allowed, otherwise buffers the press
## in PlayerInput so it fires as soon as it's allowed (MOVEMENT.md step 7).
## No casting while dashing. During a basic attack swing only if the
## ability's cancels_swing allows it (the cast then cancels the swing).
## A ready ability you can't afford fails at once with its cue and is never
## buffered, so it doesn't go off later when the resource comes back
## (ABILITIES.md, Costs).
func request_cast(slot: StringName) -> void:
	if abilities.is_ready(slot) and not is_cast_blocked() and not abilities.can_afford(slot):
		abilities.fail_cast(slot, AbilityComponent.FAIL_NO_RESOURCE)
	elif abilities.is_ready(slot) and not is_cast_blocked() and not abilities.conditions_pass(slot, get_global_mouse_position(), _condition_target_for(slot)):
		abilities.fail_cast(slot, AbilityComponent.FAIL_CONDITION)   # AB12: fails at once, not buffered
	elif abilities.can_cast(slot) and not dash.is_dashing() and can_interrupt_swing(slot):
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


## A UNIT ability's target for a press at the cursor (the same pick as
## cast_ability()), or null for other abilities (AB12: the press's conditions).
func _condition_target_for(slot: StringName) -> Unit:
	var ability := abilities.get_ability(slot)
	if ability == null or ability.targeting != Ability.Targeting.UNIT:
		return null
	var aim := get_global_mouse_position()
	var target := _enemy_under_point(aim)
	return target if target != null else AbilityUtil.nearest_enemy_to(self, aim, target_forgiveness)


## Cast an ability at the cursor (also used by tests).
func cast_ability(slot: StringName, aim: Vector2 = Vector2.INF) -> bool:
	if aim == Vector2.INF:
		aim = get_global_mouse_position()
	var target := _enemy_under_point(aim)
	if target == null:
		target = AbilityUtil.nearest_enemy_to(self, aim, target_forgiveness)
	return abilities.try_cast(slot, aim, target)


func _enemy_under_mouse() -> Unit:
	return _enemy_under_point(get_global_mouse_position())


func _enemy_under_point(point: Vector2) -> Unit:
	var best: Unit = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("units"):
		var u := node as Unit
		if u == null or not u.is_targetable() or not is_enemy_of(u):   # untargetable: not picked (ABILITIES AB10)
			continue
		if u.contains_point(point):
			var d := point.distance_to(u.get_center())
			if d < best_d:
				best = u
				best_d = d
	return best


# --- Update ---------------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if not is_alive():
		return
	abilities.set_aim_hint(get_global_mouse_position())   # conditions checked outside a press (AB12)
	_update_charge_input()
	_update_facing()
	_update_state()


## While charging: keep the charge's aim on the cursor (its overhold fires
## there), and release it if the key isn't held any more (a release lost to a
## focus change). A charge that ended some other way (cancel, stun) clears
## the flag.
func _update_charge_input() -> void:
	if not abilities.is_charging():
		_charge_from_input = false
		return
	abilities.set_charge_aim(get_global_mouse_position())
	if _charge_from_input and not Input.is_action_pressed(ABILITY_ACTIONS[abilities.casting_slot]):
		_release_charge()


func _process(delta: float) -> void:
	if not is_alive():
		return
	# Post-hit i-frames blink (visual only).
	if has_invulnerability(HIT_IFRAMES_ID):
		_blink_time += delta
		body.visible = fmod(_blink_time, hit_iframes_blink_period) < hit_iframes_blink_period * 0.6
	elif _blink_time > 0.0:
		_blink_time = 0.0
		body.visible = true
	# Hover highlight + cursor.
	var enemy := _enemy_under_mouse()
	if enemy != _hovered_enemy:
		if is_instance_valid(_hovered_enemy):
			_hovered_enemy.hovered = false
		_hovered_enemy = enemy
		if enemy:
			enemy.hovered = true
	var indicator_slot := get_indicator_slot()   # aiming, or charging up
	var targeting := enemy != null or indicator_slot != &""
	var want_cursor := Input.CURSOR_CROSS if targeting else Input.CURSOR_ARROW
	if Input.get_current_cursor_shape() != want_cursor:
		Input.set_default_cursor_shape(want_cursor)

	# Redraw while an indicator shows, and once more the frame it goes away,
	# so it never stays on screen (a safety net next to charge_ended).
	if indicator_slot != &"" or _drawn_indicator_slot != &"":
		queue_redraw()

	# Facing and a little walk bob.
	var dir := movement.get_move_direction()
	var busy := abilities.casting or attack.is_swing_rooted()
	if not busy and dir != Vector2.ZERO:
		sword_pivot.rotation = dir.angle()
		if absf(dir.x) > 0.05:
			body.scale.x = signf(dir.x)
	# While aiming (or charging up) an ability, the sword points at the cursor
	# (matches facing); during a charge-up's release windup, at the locked aim.
	if indicator_slot != &"":
		face(get_indicator_aim())
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
	# The indicator: while aiming, and always during a charge-up (it grows with
	# the charge: draw_indicator() reads the charged range; locked at the
	# release aim during the release windup).
	var indicator_slot := get_indicator_slot()
	_drawn_indicator_slot = indicator_slot
	_drawn_vector_start = Vector2.INF
	if indicator_slot != &"":
		var ability := abilities.get_ability(indicator_slot)
		var vector_start := Vector2.INF
		if aiming_slot == &"" and abilities.has_charge_indicator():
			ability = abilities.get_charge_ability()   # the charge-up's own, even if the slot was swapped
			vector_start = abilities.get_vector_start()
		if ability and vector_start != Vector2.INF:
			# A VECTOR aim (AB13): the start marker and the line, from the press
			# until the effect starts.
			_drawn_vector_start = vector_start
			ability.draw_vector_indicator(self, self, vector_start, get_indicator_aim())
		elif ability:
			ability.draw_indicator(self, self, get_indicator_aim())
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
## attacking (a combo swing's aim, locked at swing start) > dashing (the dash
## direction) > aiming an ability (the cursor) > walking (the move
## direction). Standing still keeps the last facing.
func _update_facing() -> void:
	var look := Vector2.ZERO
	if abilities.casting and _cast_face_point != Vector2.INF:
		look = _cast_face_point - global_position
	elif attack.is_swing_rooted():
		look = attack.get_swing_direction()
	elif dash.is_dashing():
		look = dash.get_dash_direction()
	elif get_indicator_slot() != &"":   # aiming, or charging up
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
	var finisher := index == attack.combo.swings.size() - 1 or index < 0   # the dash-strike (-1) looks heavy too
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
	body.visible = true  # In case it died mid-blink.
	aiming_slot = &""
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	Audio.stop(_low_health_handle)
	_low_health_handle = 0
	super._on_died()


## The low-health heartbeat: starts below low_health_fraction of max, stops
## at or above it and at death.
func _on_health_health_changed(current: float, maximum: float) -> void:
	var low := is_alive() and current > 0.0 and current < maximum * low_health_fraction
	if low and not Audio.is_playing(_low_health_handle):
		_low_health_handle = Audio.play_on(low_health_sound, self, 1.0, SoundEvent.Priority.HIGH)
	elif not low and _low_health_handle != 0:
		Audio.stop(_low_health_handle)
		_low_health_handle = 0


func _play_death() -> void:
	var tween := create_tween()
	tween.tween_property(body, "rotation", deg_to_rad(90.0), 0.25)
	tween.parallel().tween_property(body, "modulate", Color(1, 0.3, 0.3, 0.6), 0.25)
