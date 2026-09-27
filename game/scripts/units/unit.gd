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
const StunEffect := preload("res://scripts/vfx/stun_effect.gd")   # pre-C9 stun, used only without a StatusComponent
const STATUS_STUN: StatusEffect = preload("res://data/statuses/status_stun.tres")
## How long a Hurtbox hit's knockback lasts (seconds).
const HURTBOX_KNOCKBACK_TIME := 0.12
## Invulnerability id of the post-hit i-frames.
const HIT_IFRAMES_ID := &"hit_iframes"

@export var stats: UnitStats
@export var team: Team = Team.ENEMY
## Where the middle of the unit's body is, relative to its feet. Used for
## clicking on the unit and for health bar placement.
@export var body_center: Vector2 = Vector2(0, -14)
## Seconds of invulnerability after a hit gets through (COMBAT.md, "post-hit
## i-frames"; the player 0.5). 0 = none. Other hits in the same frame are
## blocked by it too. DoT ticks don't start it.
@export var post_hit_iframes: float = 0.0

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
## Status effects (COMBAT C9). Optional so old scenes still load; without it
## apply_stun() and add_speed_modifier() use their pre-C9 code.
@onready var status_component: StatusComponent = get_node_or_null("StatusComponent")

var hovered: bool = false:
	set(value):
		if hovered != value:
			hovered = value
			queue_redraw()

## Crit rolls since this unit's last crit (PRD, HitPipeline.roll_prd()).
var crit_misses: int = 0

var _alive: bool = true
var _dot_number: Label   # the latest DoT number, to merge the next tick into
var _invulnerable: Dictionary = {}   # id -> true (e.g. &"dash" i-frames)


func _ready() -> void:
	add_to_group("units")
	assert(stats != null, "%s has no UnitStats assigned" % name)
	stats_component.setup(stats, movement)
	health.set_stats_component(stats_component)
	health.died.connect(_on_died)
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


## While any invulnerability id is held, take_damage() and Hurtbox hits
## (damage and knockback) are ignored. Used for dash i-frames.
func add_invulnerability(id: StringName) -> void:
	_invulnerable[id] = true


func remove_invulnerability(id: StringName) -> void:
	_invulnerable.erase(id)


func is_invulnerable() -> bool:
	return not _invulnerable.is_empty()


func has_invulnerability(id: StringName) -> bool:
	return _invulnerable.has(id)


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

## `highlight` makes the damage number stand out (abilities, empowered hits).
## A thin wrapper over the hit pipeline (COMBAT.md): `amount` is already
## scaled, so it enters at mitigation as PHYSICAL damage that can't crit.
## New code builds a HitContext and calls HitPipeline.resolve() instead.
func take_damage(amount: float, source: Unit = null, highlight: bool = false) -> void:
	on_hit(make_hit_context(amount, source, highlight))


## The HitContext take_damage() uses: pre-scaled PHYSICAL damage, no crit,
## no feel of its own (callers keep their own shake and hitstop).
func make_hit_context(amount: float, source: Unit = null, highlight: bool = false) -> HitContext:
	var ctx := HitContext.new()
	ctx.source = source
	ctx.target = self
	ctx.base_damage = amount
	ctx.raw_damage = amount
	ctx.can_crit = false
	ctx.highlight = highlight
	ctx.add_tag(HitContext.get_damage_type_tag(ctx.damage_type))
	return ctx


## The defender's half of the hit pipeline (COMBAT.md, Architecture). Starts
## from ctx.raw_damage (HitPipeline.resolve() fills it in). In order:
## i-frames, mitigation, incoming_damage, shields, health, knockback,
## statuses, feel, events, the source's on-hit effects, post-hit i-frames. Interactables use the
## same method name.
func on_hit(ctx: HitContext) -> void:
	if not _alive or is_invulnerable():
		ctx.blocked = true
		return
	ctx.target = self
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
	if ctx.knockback_px > 0.0 and _alive:
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
	movement.displace(dir * ctx.knockback_px / duration, duration, ctx.knockback_curve, true)


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
	if not _alive:
		return
	if status_component:
		status_component.apply_status(STATUS_STUN, source, duration)
		return
	var fx := get_node_or_null("StunEffect")
	if fx == null:
		fx = Node2D.new()
		fx.set_script(StunEffect)
		fx.name = "StunEffect"
		fx.position = body_center + Vector2(0, -get_gameplay_radius_px() * 0.9)
		add_child(fx)
	fx.extend(duration)


## Any status tagged &"stun" (or the pre-C9 StunEffect).
func is_stunned() -> bool:
	if status_component and status_component.has_tag(&"stun"):
		return true
	return has_node("StunEffect")


## A status blocks casting (stun, silence).
func is_cast_blocked() -> bool:
	return is_stunned() or (status_component != null and status_component.blocks_cast())


## A status blocks dashing (stun, root).
func is_dash_blocked() -> bool:
	return is_stunned() or (status_component != null and status_component.blocks_dash())


## The tags of the unit's active status effects (&"target:<tag>" scopes,
## COMBAT C8). From the StatusComponent (C9); without one, only the stun.
func get_status_tags() -> Array[StringName]:
	if status_component:
		return status_component.get_tags()
	var result: Array[StringName] = []
	if is_stunned():
		result.append_array([&"cc", &"stun"])
	return result


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
	if is_invulnerable():
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
	var parent := get_parent() as Node2D
	var spread: float = (n.style as DamageNumberStyle).spread_px
	n.position = parent.to_local(get_center() + Vector2(randf_range(-spread, spread), -get_gameplay_radius_px() * 0.8))
	parent.add_child(n)


## The pre-C6 number (kept, unused since C6; delete after Ryan confirms C6).
func _spawn_damage_number(amount: float, highlight: bool = false) -> void:
	var n := Label.new()
	n.set_script(DamageNumber)
	var col := Color(1, 1, 1)
	if team == Team.PLAYER:
		col = Color(1, 0.35, 0.3)
	elif highlight:
		col = Color(1, 0.65, 0.2)
	n.set("color", col)
	n.set("big", highlight)
	n.text = str(roundi(amount))
	var parent := get_parent() as Node2D
	n.position = parent.to_local(get_center() + Vector2(randf_range(-6, 6), -get_gameplay_radius_px() * 0.8))
	parent.add_child(n)


# --- Death --------------------------------------------------------------------

func _on_died() -> void:
	_alive = false
	hovered = false
	attack.cancel()
	if abilities:
		abilities.cancel_pending()
		abilities.interrupt_cast()   # its telegraph goes now, not at the end of the cast time
	if has_node("StunEffect"):
		$StunEffect.queue_free()
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


## Override for custom death animations.
func _play_death() -> void:
	var tween := create_tween()
	tween.tween_interval(0.08)
	tween.tween_property(body, "scale", Vector2(1.5, 0.2), 0.15)
	tween.parallel().tween_property(body, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)


# --- Hover ring ---------------------------------------------------------------

func _draw() -> void:
	if not hovered:
		return
	var r := get_gameplay_radius_px()
	var col := Color(1, 0.25, 0.2, 0.9) if team == Team.ENEMY else Color(0.3, 1, 0.4, 0.9)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, col, 1.5)
