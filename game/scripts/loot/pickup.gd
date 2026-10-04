class_name Pickup
extends Area2D
## Loot on the ground (LOOT.md, Pickups; LOOT L7): one rolled item that a
## champion collects on proximity, with no key, no prompt and no stop (its
## PickupComponent masks layer 9, this node's only layer). It pops first: it
## hops from where it dropped to its landing spot over pop_time and becomes
## collectable when it lands (monitorable on), so the player sees what a
## melee kill dropped before taking it. The spot is decided at once
## (pick_landing()): the sim node stands there from the start, and its view
## (PickupView) draws the hop. It draws nothing itself (debug_draw: on the
## floor-drawing layer).
##
## Spawned by the Loot autoload (drop(), restore_ground_drops()) and collected
## through Loot.collect(), which frees it. COMPANIONS CO6 adds two more
## payloads (a dormant companion copy, kindling), one per pickup.
## An item the player dropped (L7b, Loot.drop_from_inventory()) is held for
## that unit: it can't take it back until its collect circle has left it.

## It landed: collectable from now on (its rarity's drop sound plays).
signal landed

## Collision layer 9, pickup (WORLD_INTERACTION.md).
const PICKUP_LAYER := 1 << 8
## What a landing spot must be walkable from the drop's origin across: walls
## (1), low obstacles (7) and ledges (11), the layers that block walking.
const WALK_BLOCKING_MASK := 1 | (1 << 6) | (1 << 10)
## Pits (6): a landing spot is never over one, nor across one (Ryan,
## 2026-10-04, at L-M: a pit between a corpse and its drop stops the hop).
const PIT_MASK := 1 << 5
## A landing spot is tried in this many random directions, else the origin.
const LANDING_TRIES := 4

## How long the hop lasts (s); collectable once it's over.
@export var pop_time: float = 0.3
## How far from the origin it lands (px, a random distance in between).
@export var pop_distance_min_px: float = 12.0
@export var pop_distance_max_px: float = 28.0
## Its 3D look (3D.md, The generic view mechanism; the group view_source).
## null = PickupView.
@export var view_scene: PackedScene
## Draws the landing spot and the collect circle on the floor (debug).
@export var debug_draw: bool = false

## Its payload: one rolled item (uid 0 until it's collected).
var item: Item

var _from := Vector2.INF
var _spot := Vector2.INF
var _hop_t := 0.0
var _landed := false
var _collected := false
var _held_for_id: int = 0   # the instance id of the unit it's held for (0 = none)


func _ready() -> void:
	add_to_group(&"view_source")   # its 3D look; nothing happens without a WorldView
	collision_layer = PICKUP_LAYER
	collision_mask = 0
	monitoring = false
	if _spot.is_finite():
		global_position = _spot
	if not _from.is_finite():
		_from = global_position
	monitorable = _landed
	if debug_draw:
		visibility_layer |= FloorOverlay.DRAWING_VISIBILITY_BIT   # a floor drawing in 3D
		queue_redraw()


## Before it enters the tree: it hops from `from` to `spot` (px, global) over
## pop_time, collectable when it lands there.
func hop(from: Vector2, spot: Vector2) -> void:
	_from = from
	_spot = spot
	_hop_t = 0.0
	_landed = false


## Before it enters the tree: it lies at `spot` (px, global), landed and
## collectable at once, with no hop and no drop sound (a ground drop put back).
func place(spot: Vector2) -> void:
	_from = spot
	_spot = spot
	_hop_t = pop_time
	_landed = true


## Before it enters the tree (L7b, an item the player dropped): `unit` can't
## collect it until its collect circle has left it. The hold ends when that
## circle reports it gone (PickupComponent, area_exited) or, checked every
## physics tick, no longer reaches it (the unit walked off while it hopped);
## and when the unit is freed. Any other collector takes it as usual.
func hold_for(unit: Unit) -> void:
	_held_for_id = unit.get_instance_id() if unit != null else 0


## True while `unit` can't collect it (it dropped it and hasn't left it yet).
func is_held_for(unit: Unit) -> bool:
	return unit != null and _held_for_id != 0 and unit.get_instance_id() == _held_for_id


## Ends the hold if it's `unit`'s.
func release_hold(unit: Unit) -> void:
	if is_held_for(unit):
		_held_for_id = 0


## A landing spot `pop_distance_min_px`–`pop_distance_max_px` from `origin`
## in a random direction that the player could walk to from the origin: no
## wall, fence, cliff edge or pit between them, and the pickup's circle clear
## of those. LANDING_TRIES directions, else `origin` itself. Uses
## only WorldQuery, so it works before the pickup is in the tree.
func pick_landing(origin: Vector2, rng: RandomNumberGenerator) -> Vector2:
	for i in LANDING_TRIES:
		var spot := origin + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(pop_distance_min_px, pop_distance_max_px)
		if is_good_landing(origin, spot):
			return spot
	return origin


## True when nothing lies between `origin` and `spot` that a player couldn't
## walk across (a wall, a fence, a cliff edge, a pit) and the pickup lies
## there clear of them.
func is_good_landing(origin: Vector2, spot: Vector2) -> bool:
	return WorldQuery.has_line_of_sight(origin, spot, WALK_BLOCKING_MASK | PIT_MASK) \
		and WorldQuery.is_point_free(spot, get_radius(), WALK_BLOCKING_MASK | PIT_MASK)


## Its collision circle's radius (px).
func get_radius() -> float:
	var shape := get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	var circle := shape.shape as CircleShape2D if shape != null else null
	return circle.radius if circle != null else 6.0


## Where it lies (px, global): its landing spot, even while it still hops.
func get_spot() -> Vector2:
	return _spot if not is_inside_tree() else global_position


## Where its hop started (px, global; its view's arc).
func get_hop_from() -> Vector2:
	return _from if _from.is_finite() else get_spot()


## 0–1 through the hop; 1 once it has landed.
func get_hop_progress() -> float:
	if _landed or pop_time <= 0.0:
		return 1.0
	return clampf(_hop_t / pop_time, 0.0, 1.0)


func is_landed() -> bool:
	return _landed


## True once Loot.collect() took it (or Loot.take_ground_drops()): it's being
## freed and nothing else can take it.
func is_collected() -> bool:
	return _collected


## Loot only: taken; it frees itself.
func mark_collected() -> void:
	_collected = true
	set_deferred(&"monitorable", false)
	queue_free()


## Its payload's rarity color (the view's gem and beam, the HUD line).
func get_color() -> Color:
	return item.get_color(Loot.table) if item != null else Color.WHITE


## The scene of its 3D view (view_scene, or PickupView's). Loaded only when a
## WorldView asks.
func get_view_scene() -> PackedScene:
	return view_scene if view_scene != null else load("res://scenes/view/pickup_view.tscn")


func _physics_process(delta: float) -> void:
	if _held_for_id != 0:
		_check_hold()
	if _landed or _collected:
		return
	_hop_t += delta
	if _hop_t >= pop_time:
		_land()


## The hold ends once its unit is gone or its collect circle no longer
## reaches this pickup's (half a pixel of slack: the physics overlap is
## exact, and a hold that outlived it would need a second walk away).
func _check_hold() -> void:
	var unit := instance_from_id(_held_for_id) as Unit
	var collector := unit.get_node_or_null(^"PickupComponent") as PickupComponent if unit != null else null
	if collector == null or not collector.is_inside_tree():
		_held_for_id = 0
	elif collector.global_position.distance_to(global_position) > collector.get_radius_px() + get_radius() + 0.5:
		_held_for_id = 0


func _land() -> void:
	_landed = true
	monitorable = true   # a PickupComponent around it collects it on the next step
	var def := Loot.table.get_rarity(item.rarity) if item != null and Loot.table != null else null
	if def != null and def.drop_sound != null:
		Audio.play_at(def.drop_sound, global_position)
	landed.emit()
	if debug_draw:
		queue_redraw()


func _draw() -> void:
	if not debug_draw:
		return
	var color := get_color()
	draw_arc(Vector2.ZERO, get_radius(), 0.0, TAU, 16, color, 1.0)
	if not _landed:
		draw_line(to_local(get_hop_from()), Vector2.ZERO, Color(color, 0.5), 1.0)
