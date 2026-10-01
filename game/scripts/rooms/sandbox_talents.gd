class_name SandboxTalents
extends Node
## Sandbox only (TALENTS T1): try the champion's talents on the live Knight
## before the hub exists. Lists every talent in the player's ChampionData;
## G moves the cursor down the list (Shift+G up), T toggles the highlighted
## talent (raw keys read here, no input action: this is sandbox-only, like
## SandboxAugments' 1-4). It ignores locks, points and the tier rule and never
## changes a saved loadout; a talent that fails validation is refused (the
## Player logs why). room_01 has none of this.

## The on-screen list of the talents and their state.
@export var show_list: bool = true

var _player: Player
var _cursor: int = 0
var _label: Label


func _ready() -> void:
	if show_list:
		var layer := CanvasLayer.new()
		add_child(layer)
		_label = Label.new()
		_label.add_theme_font_size_override("font_size", 8)
		_label.anchor_top = 1.0
		_label.anchor_bottom = 1.0
		_label.offset_left = 6.0
		_label.offset_right = 260.0
		_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_label.offset_top = -60.0
		_label.offset_bottom = -60.0
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
		_cursor = 0
		_update_label()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_G:
			move_cursor(-1 if key.shift_pressed else 1)
			get_viewport().set_input_as_handled()
		KEY_T:
			toggle(_cursor)
			get_viewport().set_input_as_handled()


## The champion's talents, in ChampionData order (empty without a champion).
func get_talents() -> Array[Talent]:
	var out: Array[Talent] = []
	if is_instance_valid(_player) and _player.champion != null:
		for t in _player.champion.talents:
			if t != null:
				out.append(t)
	return out


func move_cursor(step: int) -> void:
	var count := get_talents().size()
	if count > 0:
		_cursor = posmod(_cursor + step, count)
	_update_label()


## Attaches or removes talent `index` on the live player. Returns whether it's
## now on.
func toggle(index: int) -> bool:
	var talents := get_talents()
	if index < 0 or index >= talents.size():
		return false
	var talent := talents[index]
	if _player.get_active_talents().has(talent):
		_player.remove_talent(talent)
	else:
		_player.add_talent(talent)
	_update_label()
	return _player.get_active_talents().has(talent)


func is_on(index: int) -> bool:
	var talents := get_talents()
	return index >= 0 and index < talents.size() and _player.get_active_talents().has(talents[index])


func _update_label() -> void:
	if _label == null:
		return
	var talents := get_talents()
	if talents.is_empty():
		_label.text = "Talents: none for this champion"
		return
	var lines: PackedStringArray = ["Talents (G / Shift+G move, T toggle)"]
	var groups := Talent.Group.keys()
	for i in talents.size():
		var t := talents[i]
		lines.append("%s %s%d  %s  %s" % [">" if i == _cursor else " ", groups[t.group], t.tier, t.display_name, "ON" if is_on(i) else "off"])
	_label.text = "\n".join(lines)
