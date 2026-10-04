class_name SandboxLoot
extends Node
## Sandbox only (LOOT L3): equip items by hand until UI.md builds the
## inventory screen (LOOT.md, The sandbox equip entry point). A list on the
## right, under SandboxAugments' four lines: the keys, a header
## ("Inventory 23   Depth 1   MF +0%"), the champion's items in their rarity
## colors (scrolling around the cursor; ON = worn), the highlighted item's
## tooltip lines and what the last key did. Raw keys read here, no input
## action (sandbox-only, like SandboxAugments' 1-4 and SandboxTalents' G / T):
##   J / Shift+J   the cursor down / up (held: repeats)
##   U             equip or unequip the highlighted item (a swap when its
##                 slot is filled; a ring goes in the first empty ring slot)
##   K             roll one drop from drop_table at the room's depth with the
##                 champion's magic find, dropped at the champion's feet as
##                 pickups (the real path since LOOT L7: they pop, land and
##                 are collected, the champion standing within its pickup
##                 radius)
##   P             one of each of the champion's named items, into the
##                 inventory (LOOT L5; Loot.debug_grant_named_items())
##   L             drop the highlighted item back on the ground at the
##                 champion's feet (LOOT L7b; it can't take it back until it
##                 walks out of its pickup radius and returns)
##   X             trash the highlighted item for good (L7b; Unique and up ask
##                 first: X again on it within trash_confirm_time; any other
##                 key, a cursor move or the time running out cancels)
##   O             cycle the list's order: pickup order, by slot, by rarity
##                 (L7b; a view only, the save keeps its own order)
##   [ / ]         lower / raise the room's depth (Room.depth, at least 1)
## L and X refuse a worn item (unequip it first).
## Unlike SandboxTalents it changes the real save (Ryan, 2026-10-01): it's the
## only equip screen until UI.md, so gear set here carries into Start run.
## Rolls go in through Loot.drop() and the pickup (Loot.collect()), P's
## through Loot.add_item(), and equipping through the Player's
## EquipmentComponent, all saved by the Loot autoload. Every pickup (K's or a
## kill's) moves the cursor to the new item. A scripted harness sets
## Loot.saving_enabled = false first. room_01 has none of this.

## The list's plain text and its hints (the keys, scroll marks, the last result).
const TEXT_COLOR := Color(0.92, 0.92, 0.92)
const HINT_COLOR := Color(0.65, 0.65, 0.7)
## O cycles these (L7b): the inventory's own order (oldest first), by slot
## (then the best rarity first), by rarity (best first, then by slot). Ties
## keep the pickup order.
const SORTS: Array[StringName] = [&"picked_up", &"slot", &"rarity"]
const SORT_NAMES := {&"picked_up": "pickup order", &"slot": "slot", &"rarity": "rarity"}

## What K rolls from (the elite table: always one item, Uncommon or better).
@export var drop_table: DropTable = preload("res://data/drop_tables/drop_table_elite.tres")
## The on-screen list of the inventory.
@export var show_list: bool = true
## How many items the list shows at once (it scrolls around the cursor). 6
## keeps the list and a long tooltip above the ability bar.
@export var visible_rows: int = 6
## How long a trash waits for its second press (s; L7b).
@export var trash_confirm_time: float = 3.0

var _player: Player
var _cursor: int = 0
var _status: String = ""
var _label: RichTextLabel
var _sort: StringName = &"picked_up"
var _pending_trash: Item
var _pending_until_ms: int = 0


func _ready() -> void:
	if show_list:
		var layer := CanvasLayer.new()
		add_child(layer)
		_label = RichTextLabel.new()
		_label.bbcode_enabled = true
		_label.fit_content = true
		_label.scroll_active = false
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE   # never eats an attack click
		_label.add_theme_font_size_override("normal_font_size", 8)
		_label.anchor_left = 1.0
		_label.anchor_right = 1.0
		_label.offset_left = -266.0
		_label.offset_right = -6.0
		_label.offset_top = 66.0   # under SandboxAugments' four lines (they end at 61)
		layer.add_child(_label)
	set_process(false)   # only while a trash waits for its second press
	Events.item_equipped.connect(_on_item_changed)
	Events.item_unequipped.connect(_on_item_changed)
	Loot.item_picked_up.connect(_on_item_picked_up)
	var entities := get_parent().get_node_or_null("Entities")
	if entities != null:
		entities.child_entered_tree.connect(_on_entity)
		for child in entities.get_children():
			_on_entity(child)
	_update_label()


## A Player entering Entities (the first, or one after a restart). It enters
## before its _ready() sets up its stats and loads its gear, so the list
## waits for that.
func _on_entity(node: Node) -> void:
	if node is Player:
		_player = node
		_cursor = 0
		_status = ""
		_pending_trash = null
		set_process(false)
		if node.is_node_ready():
			_update_label()
		else:
			node.ready.connect(_update_label, CONNECT_ONE_SHOT)


func _on_item_changed(unit: Unit, _item: Item) -> void:
	if unit == _player:
		_update_label()


## A pickup of this champion's (K's or a kill's): the cursor on the new item.
func _on_item_picked_up(champion_id: StringName, item: Item) -> void:
	var champion := get_champion()
	if champion == null or champion.id != champion_id:
		return
	var index := get_items().find(item)
	if index >= 0 and index != _cursor:
		_cursor = index
		cancel_trash()   # the cursor moved off the item waiting to be trashed
	_update_label()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or (key.echo and key.physical_keycode != KEY_J):
		return
	# Any key but X cancels a trash waiting for its second press.
	if key.physical_keycode != KEY_X:
		cancel_trash()
	match key.physical_keycode:
		KEY_J:
			move_cursor(-1 if key.shift_pressed else 1)
		KEY_U:
			toggle(_cursor)
		KEY_K:
			roll_drop()
		KEY_P:
			grant_named_items()
		KEY_L:
			drop_item(_cursor)
		KEY_X:
			trash(_cursor)
		KEY_O:
			cycle_sort()
		KEY_BRACKETLEFT:
			change_depth(-1)
		KEY_BRACKETRIGHT:
			change_depth(1)
		_:
			return
	get_viewport().set_input_as_handled()


## A trash waiting for its second press runs out (trash_confirm_time).
func _process(_delta: float) -> void:
	if _pending_trash == null or Time.get_ticks_msec() >= _pending_until_ms:
		cancel_trash()


func get_champion() -> ChampionData:
	return _player.champion if is_instance_valid(_player) else null


## The champion's inventory in the list's order (O; the inventory's own
## order, oldest first, by default); empty without a champion.
func get_items() -> Array[Item]:
	var out: Array[Item] = []
	var champion := get_champion()
	if champion != null:
		out.append_array(Loot.get_inventory(champion).items)
	if _sort != &"picked_up" and out.size() > 1:
		var order := {}   # item -> its place in the inventory (the tie-break)
		for i in out.size():
			order[out[i]] = i
		out.sort_custom(func(a: Item, b: Item) -> bool: return _comes_before(a, b, order))
	return out


## The list's order now: &"picked_up", &"slot" or &"rarity".
func get_sort() -> StringName:
	return _sort


## O: the next order (pickup order → slot → rarity → pickup order). The
## cursor stays on the same item. Returns the order now.
func cycle_sort() -> StringName:
	var items := get_items()
	var keep: Item = items[_cursor] if _cursor < items.size() else null
	_sort = SORTS[(SORTS.find(_sort) + 1) % SORTS.size()]
	if keep != null:
		_cursor = maxi(0, get_items().find(keep))
	_status = "Sorted by %s" % SORT_NAMES[_sort]
	_update_label()
	return _sort


## The item waiting for X's second press (null when none).
func get_pending_trash() -> Item:
	return _pending_trash


func get_cursor() -> int:
	return _cursor


## What the last key did ("" before any).
func get_status() -> String:
	return _status


## The nearest Room above this node (the sandbox's own), or null.
func get_room() -> Room:
	var at := get_parent()
	while at != null and not (at is Room):
		at = at.get_parent()
	return at as Room


## The depth K rolls at (Loot.get_depth(): the room's).
func get_depth() -> int:
	return Loot.get_depth(self)


## The champion's live magic find (0.5 = +50%).
func get_magic_find() -> float:
	if not is_instance_valid(_player) or _player.stats_component == null:
		return 0.0
	return _player.stats_component.get_stat(&"magic_find")


func move_cursor(step: int) -> void:
	cancel_trash()
	var count := get_items().size()
	if count > 0:
		_cursor = posmod(_cursor + step, count)
	_update_label()


## U: equips or unequips item `index` on the live player (a swap when its
## slot is filled). Returns whether it's worn now.
func toggle(index: int) -> bool:
	var items := get_items()
	if index < 0 or index >= items.size() or _player.equipment == null:
		return false
	var item := items[index]
	var equipment := _player.equipment
	var worn_in := equipment.get_slot_of(item)
	if worn_in != &"":
		equipment.unequip(worn_in)
		_status = "Unequipped %s" % item.get_display_name()
	else:
		var reason := equipment.can_equip(item)
		if reason != "":
			_status = "Can't equip %s: %s" % [item.get_display_name(), reason]
		else:
			var before := equipment.get_equipped()
			equipment.equip(item)
			var old: Item = before.get(equipment.get_slot_of(item))
			_status = "Equipped %s" % item.get_display_name()
			if old != null:
				_status += " (swapped out %s)" % old.get_display_name()
	_update_label()
	return equipment.get_slot_of(item) != &""


## L (L7b): drops item `index` back on the ground at the champion's feet
## (Loot.drop_from_inventory(): out of the inventory and the save; it can't
## take it back until it walks out of its pickup radius and returns). The
## next item moves up into the cursor's row. Refuses a worn item. Returns
## whether it dropped.
func drop_item(index: int) -> bool:
	var items := get_items()
	var champion := get_champion()
	if champion == null or index < 0 or index >= items.size():
		return false
	var item := items[index]
	var reason := Loot.can_remove(champion, item, _player)
	var dropped := reason == "" and Loot.drop_from_inventory(champion, item, _player) != null
	if dropped:
		_status = "Dropped %s" % item.get_display_name()
	else:
		_status = "Can't drop %s: %s" % [item.get_display_name(), reason if reason != "" else "no floor here"]
	_update_label()
	return dropped


## X (L7b): trashes item `index` for good (Loot.trash_item()). Unique and up
## (Loot.needs_trash_confirm()) only ask on the first press; X again on the
## same item within trash_confirm_time trashes it. Refuses a worn item. The
## next item moves up into the cursor's row. Returns whether it trashed.
func trash(index: int) -> bool:
	var items := get_items()
	var champion := get_champion()
	if champion == null or index < 0 or index >= items.size():
		return false
	var item := items[index]
	var reason := Loot.can_remove(champion, item, _player)
	if reason != "":
		cancel_trash()
		_status = "Can't trash %s: %s" % [item.get_display_name(), reason]
		_update_label()
		return false
	var confirmed := _pending_trash == item and Time.get_ticks_msec() < _pending_until_ms
	if Loot.needs_trash_confirm(item) and not confirmed:
		_pending_trash = item
		_pending_until_ms = Time.get_ticks_msec() + roundi(trash_confirm_time * 1000.0)
		set_process(true)
		_status = "Trash %s (%s)? X again" % [item.get_display_name(), _rarity_name(item)]
		_update_label()
		return false
	_pending_trash = null
	set_process(false)
	Loot.trash_item(champion, item, _player)
	_status = "Trashed %s" % item.get_display_name()
	_update_label()
	return true


## Drops a trash waiting for its second press ("Trash cancelled"); nothing
## when none waits.
func cancel_trash() -> void:
	set_process(false)
	if _pending_trash == null:
		return
	_pending_trash = null
	_status = "Trash cancelled"
	_update_label()


## K: one roll of drop_table at the room's depth with the champion's magic
## find, dropped at the champion's feet as pickups (Loot.drop(), the real
## path since LOOT L7): each pops, lands 0.3 s later inside the champion's
## pickup radius and is collected (into the inventory, saved; the cursor
## moves to it then). Returns the rolled items, not yet in the inventory
## (none when the table's chance misses).
func roll_drop() -> Array[Item]:
	var out: Array[Item] = []
	var champion := get_champion()
	if champion == null or drop_table == null:
		return out
	out = ItemRoller.roll_drop(drop_table, get_depth(), get_magic_find(), champion, Loot.table, Loot.rng)
	var names: PackedStringArray = []
	for item in out:
		names.append("%s %s" % [_rarity_name(item), item.get_display_name()])
	if out.is_empty():
		_status = "Rolled nothing (depth %d)" % get_depth()
	else:
		Loot.drop(out, _player.global_position, _player.get_parent())
		_status = "Rolled %s (depth %d)" % [", ".join(names), get_depth()]
	_update_label()
	return out


## P: one of each of the champion's named items into its inventory
## (Loot.debug_grant_named_items(), LOOT L5; saved). The cursor moves to the
## last one. Returns how many were granted.
func grant_named_items() -> int:
	var champion := get_champion()
	if champion == null:
		return 0
	var granted := Loot.debug_grant_named_items(champion)
	if granted.is_empty():
		_status = "%s has no named items" % champion.display_name
	else:
		var names: PackedStringArray = []
		for item in granted:
			names.append(item.get_display_name())
		_cursor = get_items().size() - 1
		_status = "Granted %s" % ", ".join(names)
	_update_label()
	return granted.size()


## [ / ]: the room's depth by `step` (never below 1). Returns the depth now.
func change_depth(step: int) -> int:
	var room := get_room()
	if room == null:
		_status = "No room here: the depth stays 1"
	else:
		room.depth = maxi(1, room.depth + step)
		_status = "Depth %d" % room.depth
	_update_label()
	return get_depth()


## What the list shows, as [text, color] rows: the keys, the header, the
## items around the cursor (ON = worn), the highlighted item's tooltip lines
## and the last result.
func get_rows() -> Array:
	var rows: Array = [["Loot (J / Shift+J move, U equip, K roll, P named, L drop, X trash, O sort, [ / ] depth)", HINT_COLOR]]
	var champion := get_champion()
	if champion == null:
		rows.append(["No champion here", HINT_COLOR])
		return rows
	var items := get_items()
	var header := "Inventory %d   Depth %d   MF +%d%%" % [items.size(), get_depth(), roundi(get_magic_find() * 100.0)]
	if _sort != &"picked_up":
		header += "   By %s" % SORT_NAMES[_sort]
	rows.append([header, TEXT_COLOR])
	if items.is_empty():
		rows.append(["  Nothing yet: K rolls an item", HINT_COLOR])
	var first := clampi(_cursor - int(visible_rows / 2.0), 0, maxi(0, items.size() - visible_rows))
	var last := mini(items.size(), first + visible_rows)
	if first > 0:
		rows.append(["  (%d above)" % first, HINT_COLOR])
	for i in range(first, last):
		var item := items[i]
		var worn := _player.equipment != null and _player.equipment.get_slot_of(item) != &""
		rows.append(["%s [%s] %s  %s%s" % [">" if i == _cursor else " ", Item.get_slot_name(item.get_slot()),
			item.get_display_name(), _rarity_name(item), "  ON" if worn else ""], item.get_color(Loot.table)])
	if last < items.size():
		rows.append(["  (%d below)" % (items.size() - last), HINT_COLOR])
	if not items.is_empty():
		rows.append(["", TEXT_COLOR])
		# From the third line: its row already shows the name, slot and rarity.
		for line in items[_cursor].get_tooltip_lines(Loot.table).slice(2):
			rows.append(["    " + line, TEXT_COLOR])
	if _status != "":
		rows.append([_status, HINT_COLOR])
	return rows


func _rarity_name(item: Item) -> String:
	var def := Loot.table.get_rarity(item.rarity)
	return def.display_name if def != null else "?"


## The list's order for O (L7b): by slot then the best rarity first, or by
## rarity (best first) then slot; ties keep the inventory's order.
func _comes_before(a: Item, b: Item, order: Dictionary) -> bool:
	var ka: Array = [a.get_slot(), -a.rarity] if _sort == &"slot" else [-a.rarity, a.get_slot()]
	var kb: Array = [b.get_slot(), -b.rarity] if _sort == &"slot" else [-b.rarity, b.get_slot()]
	for i in ka.size():
		if ka[i] != kb[i]:
			return ka[i] < kb[i]
	return order[a] < order[b]


func _update_label() -> void:
	_cursor = clampi(_cursor, 0, maxi(0, get_items().size() - 1))
	if _label == null:
		return
	var parts: PackedStringArray = []
	for row: Array in get_rows():
		var text: String = row[0]
		var color: Color = row[1]
		parts.append("" if text == "" else "[color=#%s]%s[/color]" % [color.to_html(false), text.replace("[", "[lb]")])
	_label.text = "\n".join(parts)
