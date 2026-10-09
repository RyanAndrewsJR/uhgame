class_name ScreenOverlay
extends CanvasLayer
## Damage numbers and health bars over the 3D view (docs/3D.md,
## ScreenOverlay; 3D pivot P7): the DamageNumber Label a unit makes
## (Unit._add_number() hands it here while a WorldView shows the game) and a
## copy of the unit's HealthBar node, which holds the bar's settings and never
## draws on the unit (the cleanup's C3). They're drawn in the 640x360 canvas
## like the HUD, so they keep the old 2D game's size, and each is placed
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

@export_group("The perilous icon (ARCHETYPES AR2)")
## The one icon over a head (DECISIONS.md, Enemies, 2026-10-07): shown over a
## unit for perilous_icon_time s from its perilous attack's windup
## (Events.perilous_started). A placeholder look (Sekiro's glyph) until the
## art pass.
@export var perilous_icon_text: String = "危"
@export var perilous_icon_color: Color = Color(0.95, 0.12, 0.1, 1.0)
@export var perilous_icon_font_size: int = 22
## Its bottom sits this far above the top of its unit's model (canvas px;
## clear of the health bar).
@export var perilous_icon_gap_px: float = 12.0
## Seconds it shows (ARCHETYPES.md: 0.4, then the hit about 0.5 s later).
@export var perilous_icon_time: float = 0.4

var world_view: WorldView
var camera: Camera3D

## Each number on screen: {"holder": Node2D, "point": Vector3}. The holder
## (the Label inside it) stays where the number appeared in the world, as a
## number in the 2D world does.
var _numbers: Array[Dictionary] = []
## Unit -> {"bar": Node2D (the copy), "source": CanvasItem (the unit's HealthBar)}. Keys
## can be freed nodes: read them untyped and check is_instance_valid() first.
var _bars: Dictionary = {}
## The perilous icons showing: Unit -> {"label": Label, "left": seconds}.
## Keys can be freed nodes, as _bars'.
var _icons: Dictionary = {}


func _init() -> void:
	name = "ScreenOverlay"
	layer = 0   # under the HUD (1) and the pause menu (10)
	process_priority = PROCESS_PRIORITY


func _ready() -> void:
	Events.perilous_started.connect(_on_perilous_started)


func _exit_tree() -> void:
	if Events.perilous_started.is_connected(_on_perilous_started):
		Events.perilous_started.disconnect(_on_perilous_started)


## Shows the perilous icon over `unit` for perilous_icon_time s (a new one
## starts it over).
func show_perilous_icon(unit: Unit) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	var entry: Variant = _icons.get(unit)
	if entry is Dictionary and is_instance_valid(entry["label"]):
		entry["left"] = perilous_icon_time
		_place_icon(unit, entry)
		return
	var label := Label.new()
	label.name = "PerilousIcon"
	label.text = perilous_icon_text
	label.add_theme_font_size_override(&"font_size", perilous_icon_font_size)
	label.add_theme_color_override(&"font_color", perilous_icon_color)
	label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override(&"outline_size", 4)
	add_child(label)
	_icons[unit] = {"label": label, "left": perilous_icon_time}
	_place_icon(unit, _icons[unit])


## The perilous icon showing over `unit`, or null (tests).
func get_perilous_icon(unit: Node) -> Label:
	var entry: Variant = _icons.get(unit)
	if entry is Dictionary and is_instance_valid(entry["label"]):
		return entry["label"] as Label
	return null


func _on_perilous_started(unit: Unit, _ability: Ability) -> void:
	show_perilous_icon(unit)


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


## Shows `unit`'s health bar over its view: a copy of its HealthBar node (its
## settings: width, height, color, ticks), fed by its HealthComponent, shown
## while the unit is alive, gone with the unit. A unit without a HealthBar
## gets none.
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


func _process(delta: float) -> void:
	_update_icons(delta)
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
	# Hidden from the death on (it read the 2D bar's visible until the
	# cleanup's C2).
	if camera == null or not unit.is_alive() or camera.is_position_behind(head):
		bar.visible = false
		return
	bar.visible = true
	var bar_height: float = bar.get(&"height")
	bar.position = camera.unproject_position(head) - Vector2(0.0, bar_gap_px + bar_height)


## Each perilous icon counts down and follows its unit's head; it goes when
## its time is up or its unit dies or goes.
func _update_icons(delta: float) -> void:
	for unit: Variant in _icons.keys():
		var entry: Dictionary = _icons[unit]
		var label: Variant = entry["label"]
		entry["left"] = float(entry["left"]) - delta
		if not is_instance_valid(unit) or not (unit as Unit).is_alive() or float(entry["left"]) <= 0.0 or not is_instance_valid(label):
			if is_instance_valid(label):
				(label as Node).queue_free()
			_icons.erase(unit)
			continue
		_place_icon(unit as Unit, entry)


## Centers the icon over `unit`'s head, perilous_icon_gap_px above its model.
func _place_icon(unit: Unit, entry: Dictionary) -> void:
	var label: Label = entry["label"]
	var head := point_over(unit, 1.0)
	if camera == null or camera.is_position_behind(head):
		label.visible = false
		return
	label.visible = true
	var size := label.get_combined_minimum_size()
	label.position = camera.unproject_position(head) - Vector2(size.x * 0.5, perilous_icon_gap_px + size.y)
