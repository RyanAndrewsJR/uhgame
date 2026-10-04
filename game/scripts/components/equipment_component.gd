class_name EquipmentComponent
extends Node
## The items a unit wears (LOOT.md, Equipping): eight equipment slots, each
## holding at most one Item. Equipping applies the item through the hooks
## already in use, under its source id item_<uid>: its modifiers through
## StatsComponent.add_modifiers(), its augments (sigils, a named item's
## augment) through AbilityComponent.add_augment(). Unequipping takes them
## back with remove_modifiers_from() / remove_augments_from(), so the unit is
## restored exactly. Callable any time, mid-run included. LOOT L2.
##
## A live swap never heals or refills (keep_current, the default): around the
## change the unit's health and resource pool don't add a raised max to
## current, and a swap puts the new item on before taking the old one off,
## so current health ends at min(what it was, the new max). The Player's load
## passes keep_current false, so a champion spawns full with its gear.
## Fires Events.item_equipped / item_unequipped (the inventory's save listens).

## A slot's item changed (equipped, unequipped or swapped).
signal equipment_changed(slot: StringName)

const SLOTS: Array[StringName] = [&"weapon", &"helm", &"chest", &"gloves", &"boots", &"ring_1", &"ring_2", &"amulet"]

## Where affix values come from (null = the default LootTable, which is also
## Loot.table).
@export var loot_table: LootTable

@onready var unit: Unit = get_parent() as Unit

var _items: Dictionary = {}   # equipment slot -> Item


## The equipment slots an item of `kind` can go in (a ring: both ring slots).
static func get_slots_for(kind: Item.Slot) -> Array[StringName]:
	match kind:
		Item.Slot.WEAPON:
			return [&"weapon"]
		Item.Slot.HELM:
			return [&"helm"]
		Item.Slot.CHEST:
			return [&"chest"]
		Item.Slot.GLOVES:
			return [&"gloves"]
		Item.Slot.BOOTS:
			return [&"boots"]
		Item.Slot.RING:
			return [&"ring_1", &"ring_2"]
		Item.Slot.AMULET:
			return [&"amulet"]
	return []


func get_table() -> LootTable:
	return loot_table if loot_table != null else LootTable.get_default()


func get_item(slot: StringName) -> Item:
	return _items.get(slot)


## The slot `item` is in, or &"".
func get_slot_of(item: Item) -> StringName:
	for slot: StringName in _items:
		if _items[slot] == item:
			return slot
	return &""


## Equipment slot -> Item, for every filled slot (a copy).
func get_equipped() -> Dictionary:
	return _items.duplicate()


## "" when `item` can go in `slot` (&"" = the slot equip() would pick), else
## why not: no item, a slot it doesn't fit, another champion's item, already
## worn in another slot, or another worn item with its uid (removing one by
## source id would take the other's pieces too).
func can_equip(item: Item, slot: StringName = &"") -> String:
	if item == null or item.base == null:
		return "no item"
	var target := slot if slot != &"" else _pick_slot(item)
	if not SLOTS.has(target):
		return "no equipment slot '%s'" % target
	if not get_slots_for(item.get_slot()).has(target):
		return "a %s can't go in the %s slot" % [Item.get_slot_name(item.get_slot()), target]
	var owner_id := item.get_champion_id()
	if owner_id != &"" and owner_id != _get_champion_id():
		return "%s only" % String(owner_id).capitalize()
	var worn_in := get_slot_of(item)
	if worn_in != &"" and worn_in != target:
		return "already equipped (%s)" % worn_in
	for other: Item in _items.values():
		if other != item and other.uid == item.uid:
			return "another equipped item has uid %d" % item.uid
	return ""


## Puts `item` in `slot` (&"" = its own slot; for a ring the first empty ring
## slot, else ring 1), swapping out what's there. False when can_equip()
## refuses. Equipping an item into the slot it's already in changes nothing.
func equip(item: Item, slot: StringName = &"", keep_current: bool = true) -> bool:
	if can_equip(item, slot) != "":
		return false
	var target := slot if slot != &"" else _pick_slot(item)
	var old: Item = _items.get(target)
	if old == item:
		return true
	_set_hold(keep_current, true)
	_add_pieces(item)   # first, so a swap never dips the max below current
	if old != null:
		_remove_pieces(old)
	_set_hold(keep_current, false)
	_items[target] = item
	if old != null:
		Events.item_unequipped.emit(unit, old)
	Events.item_equipped.emit(unit, item)
	equipment_changed.emit(target)
	return true


## Takes the item out of `slot` and returns it (null if the slot was empty).
func unequip(slot: StringName, keep_current: bool = true) -> Item:
	var item: Item = _items.get(slot)
	if item == null:
		return null
	_set_hold(keep_current, true)
	_remove_pieces(item)
	_set_hold(keep_current, false)
	_items.erase(slot)
	Events.item_unequipped.emit(unit, item)
	equipment_changed.emit(slot)
	return item


func _pick_slot(item: Item) -> StringName:
	var worn_in := get_slot_of(item)
	if worn_in != &"":
		return worn_in
	var slots := get_slots_for(item.get_slot())
	for slot in slots:
		if not _items.has(slot):
			return slot
	return slots[0] if not slots.is_empty() else &""


func _add_pieces(item: Item) -> void:
	var source := item.get_source_id()
	var mods := item.get_modifiers(get_table())
	if not mods.is_empty():
		unit.stats_component.add_modifiers(mods)
	var augments := item.get_augments()
	if augments.is_empty():
		return
	if unit.abilities == null:
		push_warning("EquipmentComponent: %s has no AbilityComponent; %s's augments are skipped" % [unit.name, item.get_display_name()])
		return
	for augment in augments:
		unit.abilities.add_augment(augment, source)


func _remove_pieces(item: Item) -> void:
	var source := item.get_source_id()
	unit.stats_component.remove_modifiers_from(source)
	if unit.abilities != null:
		unit.abilities.remove_augments_from(source)


## keep_current: while on, a raised max health or max resource doesn't add
## to current (a swap never heals).
func _set_hold(keep_current: bool, on: bool) -> void:
	if not keep_current:
		return
	if unit.health != null:
		unit.health.set_gain_on_max_raise(not on)
	if unit.resource_pool != null:
		unit.resource_pool.set_gain_on_max_raise(not on)


func _get_champion_id() -> StringName:
	var champion: Variant = unit.get(&"champion")
	return (champion as ChampionData).id if champion is ChampionData else &""
