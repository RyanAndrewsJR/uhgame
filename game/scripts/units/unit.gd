class_name Unit
extends CharacterBody2D
## Shared base for champions and monsters: stats, health, movement,
## auto-attacks, damage numbers and hover highlighting.
##
## Expected children: StatsComponent, HealthComponent, AutoAttackComponent,
## MovementComponent, Body (Node2D with the visuals), optional Hurtbox,
## HealthBar, AbilityComponent, ResourceComponent and StatusComponent.
##
## `stats` is the base UnitStats; `stats_component` holds the live values
## (base + modifiers, STATS.md).

signal died(unit: Unit)
signal damaged(amount: float, source: Unit)

enum Team { PLAYER, ENEMY }

const DamageNumber := preload("res://scripts/ui/damage_number.gd")
const STATUS_STUN: StatusEffect = preload("res://data/statuses/status_stun.tres")
## How long a Hurtbox hit's knockback lasts (seconds).
const HURTBOX_KNOCKBACK_TIME := 0.12
## Invulnerability id of the post-hit i-frames.
const HIT_IFRAMES_ID := &"hit_iframes"

## The 2D game's own looks (the placeholder bodies and sword, their flashes,
## bobs and death tweens, the 2D movement effects, VFX.impact()'s 2D pillar,
## VFX.afterimage(), the 2D drawings of projectiles, auras, stun stars and
## marks, a unit's own HealthBar) don't run while this is true: the 3D view
## shows the game and hides the 2D world (WorldView.hide_sim() sets it and
## puts it back; 3D.md, the cleanup's C2). Floor drawings (VFX.slash(),
## VFX.ring(), Telegraph, the indicators, the hover ring) aren't 2D-only: they
## draw the 3D floor and keep running. It lives here, not on VFX, because the
## scripts that read it already depend on Unit; VFX depends on the view.
static var looks_2d_off: bool = false

@export var stats: UnitStats
@export var team: Team = Team.ENEMY
## Where the middle of the unit's body is, relative to its feet. Used for
## clicking on the unit and for health bar placement.
@export var body_center: Vector2 = Vector2(0, -14)
## Seconds of invulnerability after a hit gets through (COMBAT.md, "post-hit
## i-frames"; the player 0.3 since M1). 0 = none. Other hits in the same
## frame are blocked by it too. DoT ticks and procs don't start it.
@export var post_hit_iframes: float = 0.0
## Seconds from dying until the node is freed (game time, slowed by hitstop,
## as the 2D death animation it used to wait for). The 3D view's death goes
## on after (UnitView.death_linger). The Player isn't freed
## (Player._play_death()).
@export var death_free_time: float = 0.33

@export_group("Sounds")
## When a hit takes health (AUDIO.md; CombatSounds plays it). The player,
## later elites and bosses; null on normal enemies (their hit sound is enough).
@export var hurt_sound: SoundEvent
## When this unit dies (per enemy scene). Enemy deaths can merge into a pack burst.
@export var death_sound: SoundEvent

@export_group("View")
## The rigged 3D model the view shows (3D.md, Data, Models). null = a
## placeholder capsule sized from gameplay_radius. The Player takes its
## champion's at load (ChampionData.model_scene).
@export var model_scene: PackedScene
## The 3D view WorldView builds for this unit (3D.md, The generic view
## mechanism: the unit is in the group view_source). null = UnitView's scene.
## Nothing is built without a WorldView (the 2D game, every test).
@export var view_scene: PackedScene
## With no model_scene, the placeholder capsule's color, times the unit's
## modulate (the sandbox dummies' tint). It was the 2D body's main color
## until the cleanup's C2.
@export var model_color: Color = Color(0.75, 0.3, 0.3)

@onready var stats_component: StatsComponent = $StatsComponent
@onready var health: HealthComponent = $HealthComponent
@onready var attack: AutoAttackComponent = $AutoAttackComponent
@onready var movement: MovementComponent = $MovementComponent
@onready var body: Node2D = $Body
## Optional: only units with abilities have one.
@onready var abilities: AbilityComponent = get_node_or_null("AbilityComponent")
## Optional: mana/energy/fury (ResourceComponent). Named resource_pool so it
## isn't mixed up with Godot's Resource.
@onready var resource_pool: ResourceComponent = get_node_or_null("ResourceComponent")
## Status effects (COMBAT C9). Optional so old scenes still load; every Unit
## scene has one. Without it a unit can't be stunned (apply_stun() does
## nothing) and add_speed_modifier() uses its pre-C9 modifiers.
@onready var status_component: StatusComponent = get_node_or_null("StatusComponent")

var hovered: bool = false:
	set(value):
		if hovered != value:
			hovered = value
			queue_redraw()

## Crit rolls since this unit's last crit (PRD, HitPipeline.roll_prd()).
var crit_misses: int = 0

var _alive: bool = true
var _reaction_rules: Array = []   # [ReactionRule, source_id] (COMBAT C11)
var _dot_number: Label   # the latest DoT number, to merge the next tick into
var _last_number: Label   # the latest number, to stack the next one above (_stack_lift())
var _last_number_level: int = 0
var _invulnerable: Dictionary = {}   # id -> true (e.g. &"dash" i-frames)
var _stat_scalings: Array = []   # [StatScaling, source_id, its StatModifier copy] (CHAMPIONS CH2)
var _stat_scalings_dirty: bool = false


func _ready() -> void:
	add_to_group("units")
	add_to_group(&"view_source")   # its 3D look (3D.md); nothing happens without a WorldView
	# Its own drawing (the hover ring, the player's ability indicators) is a
	# floor drawing: under the 3D view it shows on the floor (FloorOverlay);
	# its children (the 2D body, the bar) don't. Nothing changes in 2D.
	visibility_layer |= FloorOverlay.DRAWING_VISIBILITY_BIT
	assert(stats != null, "%s has no UnitStats assigned" % name)
	stats_component.setup(stats, movement)
	health.set_stats_component(stats_component)
	health.died.connect(_on_died)
	health.health_changed.connect(_on_health_changed_for_stat_scalings)
	if resource_pool:
		resource_pool.set_stats_component(stats_component)
	movement.set_stats_component(stats_component)
	if status_component:
		movement.set_status_component(status_component)
	movement.set_radius(get_pathing_radius_px())
	if has_node("Hurtbox"):
		($Hurtbox as Hurtbox).hurt.connect(_on_hurtbox_hurt)


# --- Queries ------------------------------------------------------------------

func is_alive() -> bool:
	return _alive


## The scene of this unit's 3D view (view_scene, or UnitView's). Loaded only
## when a WorldView asks, so the 2D game and the tests never load views.
func get_view_scene() -> PackedScene:
	return view_scene if view_scene != null else load("res://scenes/view/unit_view.tscn")


## While any invulnerability id is held, every hit is blocked (on_hit():
## damage, knockback, statuses, on-hit; Hurtbox hits too). Used for the dash
## i-frames (&"dash") and the post-hit i-frames (HIT_IFRAMES_ID).
func add_invulnerability(id: StringName) -> void:
	_invulnerable[id] = true


func remove_invulnerability(id: StringName) -> void:
	_invulnerable.erase(id)


func is_invulnerable() -> bool:
	return not _invulnerable.is_empty()


func has_invulnerability(id: StringName) -> bool:
	return _invulnerable.has(id)


## Can be chosen as a target: alive and not &"untargetable" (ABILITIES AB10).
## Unit-targeted casts, the target picks, AbilityUtil.enemies_of(), enemy
## aggro and attack targets check it.
func is_targetable() -> bool:
	return _alive and not is_untargetable()


## A status tagged &"untargetable": new hits and statuses from other units
## are blocked; damage over time already applied keeps ticking (AB10).
func is_untargetable() -> bool:
	return status_component != null and status_component.has_tag(&"untargetable")


## A status tagged &"unstoppable": no new cc, no knockback (AB10).
func is_unstoppable() -> bool:
	return status_component != null and status_component.has_tag(&"unstoppable")


func is_enemy_of(other: Unit) -> bool:
	return other != null and other.team != team


func get_gameplay_radius_px() -> float:
	return Units.to_px(stats.gameplay_radius)


func get_pathing_radius_px() -> float:
	return Units.to_px(stats.pathing_radius)


func get_center() -> Vector2:
	return global_position + body_center


## Edge-to-edge distance to another unit, in pixels (how LoL measures range).
func edge_distance_to(other: Unit) -> float:
	return global_position.distance_to(other.global_position) - get_gameplay_radius_px() - other.get_gameplay_radius_px()


## True if a point (e.g. the mouse) is over this unit.
func contains_point(p: Vector2) -> bool:
	var r := get_gameplay_radius_px()
	return p.distance_to(get_center()) <= r or p.distance_to(global_position) <= r * 0.8


# --- Damage -------------------------------------------------------------------

## A thin wrapper over the hit pipeline (COMBAT.md): `amount` is already
## scaled, so it enters at mitigation as PHYSICAL damage that can't crit.
## New code builds a HitContext and calls HitPipeline.resolve() instead.
func take_damage(amount: float, source: Unit = null) -> void:
	on_hit(make_hit_context(amount, source))


## The HitContext take_damage() and Hurtbox hits use: pre-scaled PHYSICAL
## damage, no crit, no feel of its own (callers keep their own shake and
## hitstop).
func make_hit_context(amount: float, source: Unit = null) -> HitContext:
	var ctx := HitContext.new()
	ctx.source = source
	ctx.target = self
	ctx.base_damage = amount
	ctx.raw_damage = amount
	ctx.can_crit = false
	ctx.add_tag(HitContext.get_damage_type_tag(ctx.damage_type))
	return ctx


## The defender's half of the hit pipeline (COMBAT.md, Architecture). Starts
## from ctx.raw_damage (HitPipeline.resolve() fills it in). In order:
## i-frames (and untargetable), mitigation, incoming_damage, shields, health,
## the number and flash, knockback, statuses, feel, events, the source's
## on-hit effects, post-hit i-frames. Interactables use the same method name.
func on_hit(ctx: HitContext) -> void:
	if not _alive or is_invulnerable():
		ctx.blocked = true
		return
	if is_untargetable() and not ctx.has_tag(&"dot"):   # a DoT already applied keeps ticking (AB10)
		ctx.blocked = true
		return
	ctx.target = self
	ctx.target_tags = get_status_tags()   # before the hit (reaction rules, C11)
	ctx.taken_damage = HitPipeline.mitigate(ctx.raw_damage, ctx.damage_type, stats_component) \
		* stats_component.get_stat(&"incoming_damage")
	var to_health := ctx.taken_damage
	if status_component and to_health > 0.0:   # shields first (COMBAT C10)
		ctx.absorbed = status_component.absorb_damage(to_health)
		to_health -= ctx.absorbed
	var before := health.current
	health.take_damage(to_health)   # may die here (_on_died runs)
	ctx.health_lost = before - health.current
	ctx.killed = not _alive
	damaged.emit(ctx.taken_damage, ctx.source)
	_spawn_hit_number(ctx)
	_flash()
	if ctx.knockback_px > 0.0 and _alive and not is_unstoppable():   # unstoppable: the hit lands, no knockback (AB10)
		_apply_knockback(ctx)
	if _alive and status_component:   # statuses after the damage (COMBAT C9)
		for effect in ctx.statuses:
			status_component.apply_status(effect, ctx.source)
	GameFeel.play_hit_feel(ctx)   # hitstop and shake by tier (COMBAT C3)
	Events.unit_hit.emit(ctx)
	if ctx.taken_damage > 0.0:
		Events.unit_damaged.emit(ctx)
	if ctx.killed:
		Events.unit_died.emit(self, ctx)
	# On-hit (COMBAT C8) before the i-frames start, so its proc hit lands.
	HitPipeline.apply_on_hit(ctx)
	# DoT ticks and procs (part of the hit that caused them) don't start them.
	if _alive and post_hit_iframes > 0.0 and not ctx.has_tag(&"dot") and not ctx.has_tag(&"proc"):
		_start_hit_iframes()


## Pushes away from ctx.knockback_from (default: the source) by
## ctx.knockback_px over ctx.knockback_duration. A hit's knockback is
## dash-cancelable: a unit that can dash may dash out of it (COMBAT.md). The
## stronger displacement wins (MovementComponent.displace()).
func _apply_knockback(ctx: HitContext) -> void:
	var from := ctx.knockback_from
	if from == Vector2.INF:
		from = ctx.source.global_position if is_instance_valid(ctx.source) else global_position
	var duration := maxf(ctx.knockback_duration, 0.01)
	var dir := (global_position - from).normalized()
	movement.displace(dir * ctx.knockback_px / duration, duration, null, true)   # null: the unit's knockback_curve


## Post-hit i-frames: invulnerable for post_hit_iframes seconds of game time
## (the timer follows hitstop). No new hit can get through meanwhile, so it
## can't be restarted early.
func _start_hit_iframes() -> void:
	add_invulnerability(HIT_IFRAMES_ID)
	await get_tree().create_timer(post_hit_iframes, false, true).timeout
	if is_instance_valid(self):
		remove_invulnerability(HIT_IFRAMES_ID)


# --- Crowd control ------------------------------------------------------------

## Stun: can't move, attack, cast or dash. Re-stunning extends to the
## longer one. A thin wrapper (COMBAT C9): it applies status_stun for
## `duration` from `source` (tenacity shortens it).
func apply_stun(duration: float, source: Unit = null) -> void:
	if _alive and status_component:
		status_component.apply_status(STATUS_STUN, source, duration)


## Any status tagged &"stun".
func is_stunned() -> bool:
	return status_component != null and status_component.has_tag(&"stun")


## A status blocks casting (stun, silence).
func is_cast_blocked() -> bool:
	return is_stunned() or (status_component != null and status_component.blocks_cast())


## A status blocks dashing (stun, root).
func is_dash_blocked() -> bool:
	return is_stunned() or (status_component != null and status_component.blocks_dash())


## The tags of the unit's active status effects (&"target:<tag>" scopes,
## COMBAT C8), from the StatusComponent (none without one).
func get_status_tags() -> Array[StringName]:
	if status_component:
		return status_component.get_tags()
	var none: Array[StringName] = []
	return none


# --- Reaction rules -----------------------------------------------------------

## Gives this unit a reaction rule (COMBAT C11) under `source_id` (an item,
## a passive, a buff). The Reactions autoload fires it for what this unit
## does (owner_role SOURCE) or suffers (AFFECTED).
func add_reaction_rule(rule: ReactionRule, source_id: StringName) -> void:
	if rule != null:
		_reaction_rules.append([rule, source_id])


## Takes back every rule added under `source_id`.
func remove_reaction_rules_from(source_id: StringName) -> void:
	_reaction_rules = _reaction_rules.filter(func(e: Array) -> bool: return e[1] != source_id)


func get_reaction_rules() -> Array[ReactionRule]:
	var result: Array[ReactionRule] = []
	for e: Array in _reaction_rules:
		result.append(e[0])
	return result


## Every unit rule with the source id it was added under: [[rule, source_id]]
## (a copy). Reactions reads the source id for free casts (ABILITIES AB8).
func get_reaction_rule_entries() -> Array:
	return _reaction_rules.duplicate()


# --- Stat scalings -----------------------------------------------------------

## Gives this unit a StatScaling under `source_id` (a passive; CHAMPIONS CH2):
## one StatModifier copy in its StatsComponent, valued for the unit now.
## When health changes (max health too) the copies are refreshed once,
## deferred to after that physics frame's hits, so every hit of one swing
## or cast sees the same value.
func add_stat_scaling(scaling: StatScaling, source_id: StringName) -> void:
	if scaling == null or scaling.modifier == null:
		push_error("%s: a StatScaling needs a modifier" % name)
		return
	var copy := scaling.make_modifier(self, source_id)
	_stat_scalings.append([scaling, source_id, copy])
	stats_component.add_modifier(copy)


## Takes back every StatScaling added under `source_id` and its modifier.
func remove_stat_scalings_from(source_id: StringName) -> void:
	var copies: Array[StatModifier] = []
	var kept: Array = []
	for e: Array in _stat_scalings:
		if e[1] == source_id:
			copies.append(e[2])
		else:
			kept.append(e)
	if copies.is_empty():
		return
	_stat_scalings = kept
	var none: Array[StatModifier] = []
	stats_component.replace_modifiers(copies, none)


func get_stat_scalings() -> Array[StatScaling]:
	var result: Array[StatScaling] = []
	for e: Array in _stat_scalings:
		result.append(e[0])
	return result


func _on_health_changed_for_stat_scalings(_current: float, _maximum: float) -> void:
	if _stat_scalings.is_empty() or _stat_scalings_dirty:
		return
	_stat_scalings_dirty = true
	_refresh_stat_scalings.call_deferred()


## Revalues every scaling's copy in one StatsComponent change; stat_changed
## fires only for a stat whose value moved.
func _refresh_stat_scalings() -> void:
	_stat_scalings_dirty = false
	var old_mods: Array[StatModifier] = []
	var new_mods: Array[StatModifier] = []
	for e: Array in _stat_scalings:
		var scaling: StatScaling = e[0]
		var old_copy: StatModifier = e[2]
		var value := scaling.get_value(self)
		if is_equal_approx(value, old_copy.value):
			continue
		var new_copy := scaling.make_modifier(self, e[1])
		e[2] = new_copy
		old_mods.append(old_copy)
		new_mods.append(new_copy)
	if not new_mods.is_empty():
		stats_component.replace_modifiers(old_mods, new_mods)


# --- Healing ------------------------------------------------------------------

## Heals and shows the green number for what was actually healed (not above
## max health). Returns that amount. Nothing for a dead unit.
func heal(amount: float) -> float:
	if not _alive or amount <= 0.0:
		return 0.0
	var before := health.current
	health.heal(amount)
	var healed := health.current - before
	if healed >= 0.5:   # the number rounds; don't show "+0"
		show_heal_number(healed)
	return healed


## Hitbox overlaps go through the hit pipeline too (no scene has a Hitbox
## yet). Hitbox.knockback is a push speed held for HURTBOX_KNOCKBACK_TIME.
func _on_hurtbox_hurt(hitbox: Hitbox) -> void:
	if is_invulnerable() or is_untargetable():
		return
	var source := hitbox.owner as Unit
	if source and not source.is_enemy_of(self):
		return
	var ctx := make_hit_context(hitbox.damage, source)
	ctx.knockback_px = hitbox.knockback * HURTBOX_KNOCKBACK_TIME
	ctx.knockback_duration = HURTBOX_KNOCKBACK_TIME
	ctx.knockback_from = hitbox.get_source_position()
	on_hit(ctx)


## Every hit that gets through flashes the body white, then fades back over
## GameFeel.hit_feel.flash_time (COMBAT C3).
func _flash() -> void:
	if Unit.looks_2d_off:
		return   # the 3D view flashes the model (UnitView)
	var feel := GameFeel.hit_feel
	body.modulate = feel.flash_modulate
	create_tween().tween_property(body, "modulate", Color.WHITE, feel.flash_time)


## The number for a hit that got through (COMBAT.md, Damage numbers): size by
## amount (log steps), crits bigger with their own look, color by damage type
## (red on the player), DoT ticks smaller and merged per target. The part a
## shield absorbed is its own number in the shield color (COMBAT C10); a hit
## fully absorbed shows only that one.
func _spawn_hit_number(ctx: HitContext) -> void:
	var style: DamageNumberStyle = DamageNumber.DEFAULT_STYLE
	var is_dot := ctx.has_tag(&"dot")
	var to_health := ctx.taken_damage - ctx.absorbed
	if ctx.absorbed > 0.0:
		var s := _make_number(ctx.absorbed, style)
		s.kind = DamageNumber.Kind.SHIELD
		s.color = style.shield_color
		if is_dot:
			s.font_size = style.dot_font_size
		_add_number(s)
		if to_health < 0.5:
			return   # all of it (or all but a rounding sliver) went into the shield
	if is_dot and is_instance_valid(_dot_number) and not _dot_number.is_queued_for_deletion() \
			and _dot_number.get_age() < style.dot_merge_window:
		_dot_number.add_amount(to_health)
		return
	var n := _make_number(to_health, style)
	if is_dot:
		n.kind = DamageNumber.Kind.DOT
		_dot_number = n
	elif ctx.is_crit:
		n.kind = DamageNumber.Kind.CRIT
	if team == Team.PLAYER:
		n.color = style.player_damage_color
	else:
		n.color = style.get_damage_type_color(ctx.damage_type)
	_add_number(n)


## A green healing number above the unit (life steal, heals; C8 and later).
func show_heal_number(amount: float) -> void:
	var style: DamageNumberStyle = DamageNumber.DEFAULT_STYLE
	var n := _make_number(amount, style)
	n.kind = DamageNumber.Kind.HEAL
	n.color = style.heal_color
	_add_number(n)


func _make_number(amount: float, style: DamageNumberStyle) -> Label:
	var n := Label.new()
	n.set_script(DamageNumber)
	n.style = style
	n.amount = amount
	return n


func _add_number(n: Label) -> void:
	var lift := _stack_lift(n)
	# Under the 3D view the number goes on its screen overlay, over the model
	# (3D.md, ScreenOverlay); the path below is the 2D game's.
	var view := WorldView.of(self)
	if view != null and view.screen_overlay != null:
		view.screen_overlay.add_number(n, self, lift)
		return
	var parent := get_parent() as Node2D
	var spread: float = (n.style as DamageNumberStyle).spread_px
	n.position = parent.to_local(get_center() + Vector2(randf_range(-spread, spread), -get_gameplay_radius_px() * 0.8 - lift))
	parent.add_child(n)


## How much higher than usual a new number starts (COMBAT.md, Damage
## numbers): one stack_step_px above this unit's previous number while that
## one still shows, so hits in a row read as a column instead of a pile (Ryan,
## 2026-10-03). After stack_levels numbers the next starts at the bottom
## again.
func _stack_lift(n: Label) -> float:
	var style := n.style as DamageNumberStyle
	var level := 0
	if is_instance_valid(_last_number) and not _last_number.is_queued_for_deletion() \
			and _last_number.get_age() < style.lifetime:
		level = (_last_number_level + 1) % maxi(style.stack_levels, 1)
	_last_number = n
	_last_number_level = level
	return level * style.stack_step_px


# --- Death --------------------------------------------------------------------

func _on_died() -> void:
	_alive = false
	hovered = false
	attack.cancel()
	if abilities:
		abilities.cancel_pending()
		abilities.interrupt_cast()   # its telegraph goes now, not at the end of the cast time
	if status_component:
		status_component.clear()
	movement.stop()
	movement.add_move_lock(&"dead")
	movement.disable_avoidance()
	collision_layer = 0
	collision_mask = 0
	if has_node("Hurtbox"):
		$Hurtbox.set_deferred("monitoring", false)
	if has_node("HealthBar"):
		$HealthBar.visible = false
	died.emit(self)
	_play_death()


## Override for custom death animations. The unit is freed death_free_time
## after it dies whether the 2D body's animation runs or not (the cleanup's
## C2: the free used to wait for that animation's end, the same 0.33 s).
func _play_death() -> void:
	if not Unit.looks_2d_off:
		var tween := create_tween()
		tween.tween_interval(0.08)
		tween.tween_property(body, "scale", Vector2(1.5, 0.2), 0.15)
		tween.parallel().tween_property(body, "modulate:a", 0.0, 0.25)
	var free_after := create_tween()
	free_after.tween_interval(death_free_time)
	free_after.tween_callback(queue_free)


# --- Hover ring ---------------------------------------------------------------

func _draw() -> void:
	if not hovered:
		return
	var r := get_gameplay_radius_px()
	var col := Color(1, 0.25, 0.2, 0.9) if team == Team.ENEMY else Color(0.3, 1, 0.4, 0.9)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, VFX.floor_squash))   # 0.55; a true circle in 3D
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, col, 1.5)
