class_name SandboxAugments
extends Node
## Sandbox only (ABILITIES AB-M, the augment playground): four fake items,
## each one augment on the Knight under its own source id
## (&"item_test_<augment id>"), like a real item would add it. The number keys
## 1-4 equip and unequip them (raw keys read here, no input action: this is
## sandbox-only). A small list at the top right shows which are on.
## room_01 has none of this.

## Keys 1-4 toggle these, in order.
@export var items: Array[AbilityAugment] = []
## The on-screen list of the items and their keys.
@export var show_list: bool = true

var _player: Player
var _equipped: Array[bool] = []
var _label: Label


func _ready() -> void:
	_equipped.resize(items.size())
	_equipped.fill(false)
	if show_list:
		var layer := CanvasLayer.new()
		add_child(layer)
		_label = Label.new()
		_label.add_theme_font_size_override("font_size", 8)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_label.anchor_left = 1.0
		_label.anchor_right = 1.0
		_label.offset_left = -220.0
		_label.offset_right = -6.0
		_label.offset_top = 4.0
		layer.add_child(_label)
	var entities := get_parent().get_node_or_null("Entities")
	if entities != null:
		entities.child_entered_tree.connect(_on_entity)
		for child in entities.get_children():
			_on_entity(child)
	_update_label()


func _on_entity(node: Node) -> void:
	if node is Player:
		_player = node
		_equipped.fill(false)   # a new Knight starts with nothing equipped
		_update_label()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var index := int(key.physical_keycode) - int(KEY_1)
	if index >= 0 and index < items.size():
		toggle(index)
		get_viewport().set_input_as_handled()


## Equips or unequips item `index` (0-3) on the Knight. Returns whether it's
## now equipped.
func toggle(index: int) -> bool:
	if not is_instance_valid(_player) or index < 0 or index >= items.size() or items[index] == null:
		return false
	var augment := items[index]
	var source := get_source_id(augment)
	if _equipped[index]:
		_player.abilities.remove_augments_from(source)
	else:
		_player.abilities.add_augment(augment, source)
	_equipped[index] = not _equipped[index]
	_update_label()
	return _equipped[index]


## The fake item's source id: &"item_test_<augment id>".
static func get_source_id(augment: AbilityAugment) -> StringName:
	return StringName("item_test_" + augment.id)


func is_equipped(index: int) -> bool:
	return index >= 0 and index < _equipped.size() and _equipped[index]


func _update_label() -> void:
	if _label == null:
		return
	var lines: PackedStringArray = []
	for i in items.size():
		if items[i] != null:
			lines.append("%d  %s  %s" % [i + 1, items[i].display_name, "ON" if _equipped[i] else "off"])
	_label.text = "\n".join(lines)
