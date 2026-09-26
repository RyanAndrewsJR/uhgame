class_name Unit
extends CharacterBody2D
## Shared base for champions and monsters: stats, health, movement,
## auto-attacks, damage numbers and hover highlighting.
##
## Expected children: StatsComponent, HealthComponent, AutoAttackComponent,
## MovementComponent, Body (Node2D with the visuals), optional Hurtbox,
## HealthBar, AbilityComponent and ResourceComponent.
##
## `stats` is the base UnitStats; `stats_component` holds the live values
## (base + modifiers, STATS.md).

signal died(unit: Unit)
signal damaged(amount: float, source: Unit)

enum Team { PLAYER, ENEMY }

const DamageNumber := preload("res://scripts/ui/damage_number.gd")
const StunEffect := preload("res://scripts/vfx/stun_effect.gd")
## How long a Hurtbox hit's knockback lasts (seconds).
const HURTBOX_KNOCKBACK_TIME := 0.12

@export var stats: UnitStats
@export var team: Team = Team.ENEMY
## Where the middle of the unit's body is, relative to its feet. Used for
## clicking on the unit and for health bar placement.
@export var body_center: Vector2 = Vector2(0, -14)

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

var hovered: bool = false:
	set(value):
		if hovered != value:
			hovered = value
			queue_redraw()

var _alive: bool = true
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
## i-frames, mitigation, health, knockback, events. Interactables use the
## same method name.
func on_hit(ctx: HitContext) -> void:
	if not _alive or is_invulnerable():
		ctx.blocked = true
		return
	ctx.target = self
	ctx.taken_damage = HitPipeline.mitigate(ctx.raw_damage, ctx.damage_type, stats_component)
	var before := health.current
	health.take_damage(ctx.taken_damage)   # may die here (_on_died runs)
	ctx.health_lost = before - health.current
	ctx.killed = not _alive
	damaged.emit(ctx.taken_damage, ctx.source)
	_spawn_damage_number(ctx.taken_damage, ctx.highlight)
	_flash()
	if ctx.knockback_px > 0.0 and _alive:
		_apply_knockback(ctx)
	GameFeel.play_hit_feel(ctx)   # hitstop and shake by tier (COMBAT C3)
	Events.unit_hit.emit(ctx)
	if ctx.taken_damage > 0.0:
		Events.unit_damaged.emit(ctx)
	if ctx.killed:
		Events.unit_died.emit(self, ctx)


## Pushes away from ctx.knockback_from (default: the source) by
## ctx.knockback_px over ctx.knockback_duration.
func _apply_knockback(ctx: HitContext) -> void:
	var from := ctx.knockback_from
	if from == Vector2.INF:
		from = ctx.source.global_position if is_instance_valid(ctx.source) else global_position
	var duration := maxf(ctx.knockback_duration, 0.01)
	var dir := (global_position - from).normalized()
	movement.displace(dir * ctx.knockback_px / duration, duration, ctx.knockback_curve)


# --- Crowd control ------------------------------------------------------------

## Stun: can't move, attack or cast. Re-stunning extends to the longer one.
func apply_stun(duration: float) -> void:
	if not _alive:
		return
	var fx := get_node_or_null("StunEffect")
	if fx == null:
		fx = Node2D.new()
		fx.set_script(StunEffect)
		fx.name = "StunEffect"
		fx.position = body_center + Vector2(0, -get_gameplay_radius_px() * 0.9)
		add_child(fx)
	fx.extend(duration)


func is_stunned() -> bool:
	return has_node("StunEffect")


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
	if has_node("StunEffect"):
		$StunEffect.queue_free()
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
