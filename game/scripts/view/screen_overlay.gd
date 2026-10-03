class_name ScreenOverlay
extends CanvasLayer
## Damage numbers and health bars over the 3D view (docs/3D.md,
## ScreenOverlay; 3D pivot P7). They're the 2D game's own: the DamageNumber
## Label a unit makes (Unit._add_number() hands it here while a WorldView
## shows the game) and a copy of the unit's 2D HealthBar. They're drawn in the
## 640x360 canvas like the HUD, so they keep their 2D size, and each is placed
## every frame where its 3D point shows on screen
## (Camera3D.unproject_position(), the same canvas space). Under the HUD.

## After GameCamera3D (10) has moved, and WorldView's fade (20).
const PROCESS_PRIORITY := 30

## A health bar's bottom sits this far above the top of its unit's model
## (canvas px).
@export var bar_gap_px: float = 3.0
## A damage number appears at this share of its unit's model height (in the
## 2D game, a little below the top of the body) and rises from there.
@export_range(0.0, 2.0, 0.05) var number_height_share: float = 0.8
## Damage numbers' size against the 2D game's (1: the same canvas px).
@export_range(0.25, 4.0, 0.05) var number_scale: float = 1.0

var world_view: WorldView
var camera: Camera3D

## Each number on screen: {"holder": Node2D, "point": Vector3}. The holder
## (the Label inside it) stays where the number appeared in the world, as a
## number in the 2D world does.
var _numbers: Array[Dictionary] = []
## Unit -> {"bar": Node2D (the copy), "source": CanvasItem (the 2D bar)}. Keys
## can be freed nodes: read them untyped and check is_instance_valid() first.
var _bars: Dictionary = {}


func _init() -> void:
	name = "ScreenOverlay"
	layer = 0   # under the HUD (1) and the pause menu (10)
	process_priority = PROCESS_PRIORITY


## Shows a damage number for `unit` (Unit._add_number()'s path under the 3D
## view): where the unit is drawn now, number_height_share of its model's
## height up, spread sideways like the 2D game's, `lift_px` higher when it
## stacks over the unit's previous number (Unit._stack_lift()). It pops,
## rises and fades on its own (DamageNumber); its holder goes with it.
func add_number(n: Label, unit: Unit, lift_px: float = 0.0) -> void:
	var style := n.get(&"style") as DamageNumberStyle
	var spread: float = style.spread_px if style else 0.0
	var holder := Node2D.new()
	holder.name = "Number"
	holder.scale = Vector2.ONE * number_scale
	n.position = Vector2(randf_range(-spread, spread), -lift_px)
	holder.add_child(n)
	var point := point_over(unit, number_height_share)
	_numbers.append({"holder": holder, "point": point})
	add_child(holder)
	_place(holder, point)


## Shows `unit`'s health bar over its view: a copy of its 2D HealthBar (the
## same look and exports), fed by its HealthComponent, shown while the 2D bar
## is (Unit hides it at death), gone with the unit. A unit without a
## HealthBar gets none.
func add_bar(unit: Unit) -> void:
	if unit == null or _bars.has(unit) or unit.health == null:
		return
	var source := unit.get_node_or_null(^"HealthBar") as Node2D
	if source == null:
		return
	var bar := source.duplicate() as Node2D
	bar.name = "Bar_%s" % unit.name
	bar.set(&"health", unit.health)
	add_child(bar)
	_bars[unit] = {"bar": bar, "source": source}
	unit.tree_exiting.connect(remove_bar.bind(unit), CONNECT_ONE_SHOT)
	_place_bar(unit, _bars[unit])


func remove_bar(unit: Node) -> void:
	var entry: Variant = _bars.get(unit)
	_bars.erase(unit)
	if entry is Dictionary and is_instance_valid(entry["bar"]):
		(entry["bar"] as Node).queue_free()


## The overlay's copy of a unit's health bar, or null.
func bar_of(unit: Node) -> Node2D:
	var entry: Variant = _bars.get(unit)
	if entry is Dictionary and is_instance_valid(entry["bar"]):
		return entry["bar"] as Node2D
	return null


func _process(_delta: float) -> void:
	for i in range(_numbers.size() - 1, -1, -1):
		var holder: Variant = _numbers[i]["holder"]
		if not is_instance_valid(holder) or (holder as Node).get_child_count() == 0:
			if is_instance_valid(holder):
				(holder as Node).queue_free()
			_numbers.remove_at(i)
			continue
		_place(holder as Node2D, _numbers[i]["point"])
	for unit: Variant in _bars.keys():
		if is_instance_valid(unit):
			_place_bar(unit as Unit, _bars[unit])


## The point `share` of `unit`'s model height above its feet, where the model
## is drawn this frame (m).
func point_over(unit: Unit, share: float) -> Vector3:
	var view: EntityView = world_view.view_of(unit) if world_view else null
	var feet: Vector3 = view.get_global_transform_interpolated().origin if view else Units.to_view(unit.global_position)
	var height: float = world_view.unit_height_m(unit) if world_view else 1.5
	return feet + Vector3(0.0, height * share, 0.0)


## Puts `node` where `point` shows on screen; hidden while it's behind the
## camera.
func _place(node: CanvasItem, point: Vector3) -> void:
	if camera == null or camera.is_position_behind(point):
		node.visible = false
		return
	node.visible = true
	(node as Node2D).position = camera.unproject_position(point)


func _place_bar(unit: Unit, entry: Dictionary) -> void:
	var bar: Node2D = entry["bar"]
	var source: CanvasItem = entry["source"]
	if not is_instance_valid(bar) or not is_instance_valid(source):
		return
	var head := point_over(unit, 1.0)
	if camera == null or not source.visible or camera.is_position_behind(head):
		bar.visible = false
		return
	bar.visible = true
	var bar_height: float = bar.get(&"height")
	bar.position = camera.unproject_position(head) - Vector2(0.0, bar_gap_px + bar_height)
