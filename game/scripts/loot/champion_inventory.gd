class_name ChampionInventory
extends RefCounted
## One champion's inventory (LOOT.md, Inventory and saving): every item it
## has picked up, one unlimited pool used mid-run and at the hub alike, which
## items are equipped, and the reserved materials bucket. Held by the Loot
## autoload, saved to user://inventory.cfg as one ConfigFile section per
## champion id. Never shared between champions. LOOT L2.
##
## An item the data no longer knows (its base or rarity) isn't loaded but its
## raw entry is kept and written back unchanged, so a data fix brings it back;
## its uid stays taken.

var champion_id: StringName = &""
## The uid the next added item gets (always above every uid in the record).
var next_uid: int = 1
var items: Array[Item] = []
## Equipment slot (EquipmentComponent.SLOTS) -> the uid of the item in it.
var equipped: Dictionary = {}
## Reserved for LOOT v2's crafting currencies (material id -> count): saved,
## always empty, nothing reads or writes it yet (Ryan, 2026-10-01).
var materials: Dictionary[StringName, int] = {}

var _unreadable: Array = []   # raw saved entries it couldn't read, kept as they were


static func create(champion: ChampionData) -> ChampionInventory:
	var inv := ChampionInventory.new()
	inv.champion_id = champion.id
	return inv


## Adds `item` with a new uid and returns the uid.
func add(item: Item) -> int:
	item.uid = next_uid
	next_uid += 1
	items.append(item)
	return item.uid


func get_item(uid: int) -> Item:
	for item in items:
		if item.uid == uid:
			return item
	return null


## The item in equipment slot `slot`, or null.
func get_equipped_item(slot: StringName) -> Item:
	return get_item(equipped[slot]) if equipped.has(slot) else null


func set_equipped(slot: StringName, uid: int) -> void:
	equipped[slot] = uid


func clear_equipped(slot: StringName) -> void:
	equipped.erase(slot)


## The equipment slot whose saved uid is `uid`, or &"".
func get_equipped_slot(uid: int) -> StringName:
	for slot: StringName in equipped:
		if equipped[slot] == uid:
			return slot
	return &""


## How many saved entries couldn't be read (kept raw).
func get_unreadable_count() -> int:
	return _unreadable.size()


func write_to(cfg: ConfigFile) -> void:
	var section := String(champion_id)
	var saved: Array = []
	for item in items:
		saved.append(item.to_dict())
	saved.append_array(_unreadable)
	var slots := {}
	for slot: StringName in equipped:
		slots[String(slot)] = int(equipped[slot])
	var bucket := {}
	for id: StringName in materials:
		bucket[String(id)] = int(materials[id])
	cfg.set_value(section, "next_uid", next_uid)
	cfg.set_value(section, "items", saved)
	cfg.set_value(section, "equipped", slots)
	cfg.set_value(section, "materials", bucket)


## The record saved in `cfg` for `champion`, or null if it has none. A
## duplicate or missing uid gets a new one; an equipped slot that isn't an
## equipment slot, or names no loaded item, is dropped (a warning each).
static func read_from(cfg: ConfigFile, champion: ChampionData, table: LootTable) -> ChampionInventory:
	var section := String(champion.id)
	if not cfg.has_section(section):
		return null
	var inv := ChampionInventory.create(champion)
	var label := "Inventory '%s'" % section
	var highest := 0
	var loaded: Array[Item] = []
	var entries: Variant = cfg.get_value(section, "items", [])
	for entry: Variant in (entries if entries is Array else []):
		var item: Item = Item.from_dict(entry, table) if entry is Dictionary else null
		if item == null:
			push_warning("%s: an item it can't read (%s); kept in the save, not loaded" % [label, entry])
			inv._unreadable.append(entry)
			if entry is Dictionary:
				highest = maxi(highest, int((entry as Dictionary).get("uid", 0)))
			continue
		loaded.append(item)
		highest = maxi(highest, item.uid)
	inv.next_uid = maxi(int(cfg.get_value(section, "next_uid", 1)), highest + 1)
	var taken := {}
	for item in loaded:
		if item.uid <= 0 or taken.has(item.uid):
			var old := item.uid
			item.uid = inv.next_uid
			inv.next_uid += 1
			push_warning("%s: uid %d was missing or taken; the item is uid %d now" % [label, old, item.uid])
		taken[item.uid] = true
		inv.items.append(item)
	var slots: Variant = cfg.get_value(section, "equipped", {})
	if slots is Dictionary:
		for key: Variant in slots:
			var slot := StringName(str(key))
			var uid := int(slots[key])
			if not EquipmentComponent.SLOTS.has(slot) or inv.get_item(uid) == null:
				push_warning("%s: equipped %s = %d names no slot or no loaded item; dropped" % [label, slot, uid])
				continue
			inv.equipped[slot] = uid
	var bucket: Variant = cfg.get_value(section, "materials", {})
	if bucket is Dictionary:
		for key: Variant in bucket:
			inv.materials[StringName(str(key))] = int(bucket[key])
	return inv
