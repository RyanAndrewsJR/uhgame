extends Node
## Every champion's inventory (LOOT.md): a ChampionInventory per champion id,
## saved to user://inventory.cfg (a ConfigFile, one section per champion; its
## own file, so a corrupt or huge inventory never touches talent progress).
## Autoloaded as Loot, after Progress and before Audio. LOOT L2; drops and
## pickups (L7) come here too.
##
## The Player tracks itself when its champion loads (track()) and equips its
## saved gear. Equipping and unequipping on the tracked player update its
## record (Events.item_equipped / item_unequipped); only items of the record
## are remembered.
##
## Saved when an item is added, an equipped slot changes, the tracked player
## leaves the tree and the window closes. A scene under res://scenes/tests/
## never reads or writes the save (Progress.is_test_scene(), the same guard):
## its records start fresh and stay in memory. A scripted harness sets
## saving_enabled = false first.

const SAVE_PATH := "user://inventory.cfg"

## Off: nothing is read from or written to save_path (a test scene turns it
## off by itself before the first record is made).
var saving_enabled: bool = true
var save_path: String = SAVE_PATH
## The rules every roll and value uses (the default LootTable).
var table: LootTable
## Drops' rolls (L7); tests seed it.
var rng := RandomNumberGenerator.new()

var _cfg := ConfigFile.new()
var _loaded: bool = false
var _records: Dictionary = {}   # champion id -> ChampionInventory
var _player: Player
var _champion: ChampionData


func _ready() -> void:
	table = LootTable.get_default()
	rng.randomize()
	Events.item_equipped.connect(_on_item_equipped)
	Events.item_unequipped.connect(_on_item_unequipped)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()


## The champion's inventory: the one in memory, else the saved one, else a
## fresh empty one.
func get_inventory(champion: ChampionData) -> ChampionInventory:
	_ensure_loaded()
	if _records.has(champion.id):
		return _records[champion.id]
	var record: ChampionInventory = ChampionInventory.read_from(_cfg, champion, table) if saving_enabled else null
	if record == null:
		record = ChampionInventory.create(champion)
	_records[champion.id] = record
	return record


## Remembers `player`'s equipping for `champion`'s record (the Player calls it
## when its champion loads) and saves when it leaves the tree. Returns the record.
func track(player: Player, champion: ChampionData) -> ChampionInventory:
	var record := get_inventory(champion)
	_player = player
	_champion = champion
	if not player.tree_exiting.is_connected(untrack):
		player.tree_exiting.connect(untrack.bind(player))
	return record


## Stops remembering `player` (it left the tree) and saves.
func untrack(player: Player) -> void:
	if _player != player:
		return
	save()
	_player = null
	_champion = null


func get_tracked_player() -> Player:
	return _player if is_instance_valid(_player) else null


## Adds `item` to the champion's inventory with a new uid, then saves.
## Returns the uid.
func add_item(champion: ChampionData, item: Item) -> int:
	var uid := get_inventory(champion).add(item)
	save()
	return uid


## Debug and tests: the champion back to an empty inventory (saved).
func reset(champion: ChampionData) -> void:
	_records[champion.id] = ChampionInventory.create(champion)
	save()


## Writes every record to save_path (nothing while saving is off). The
## test-scene guard runs first, so a save() or reset() that comes before any
## get_inventory() in a test scene still writes nothing.
func save() -> void:
	_ensure_loaded()
	if not saving_enabled:
		return
	for record: ChampionInventory in _records.values():
		record.write_to(_cfg)
	var err := _cfg.save(save_path)
	if err != OK:
		push_error("Loot: couldn't save %s (error %d)" % [save_path, err])


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if Progress.is_test_scene():
		saving_enabled = false
	if saving_enabled and FileAccess.file_exists(save_path):
		var err := _cfg.load(save_path)
		if err != OK:
			push_error("Loot: couldn't read %s (error %d); starting fresh" % [save_path, err])
			_cfg = ConfigFile.new()


func _on_item_equipped(unit: Unit, item: Item) -> void:
	var record := _tracked_record(unit, item)
	if record == null or _player.equipment == null:
		return
	var slot := _player.equipment.get_slot_of(item)
	if slot == &"" or record.equipped.get(slot, -1) == item.uid:
		return   # nothing new (the Player's own load re-equips what's saved)
	record.set_equipped(slot, item.uid)
	save()


func _on_item_unequipped(unit: Unit, item: Item) -> void:
	var record := _tracked_record(unit, item)
	if record == null:
		return
	var slot := record.get_equipped_slot(item.uid)
	if slot == &"":
		return
	record.clear_equipped(slot)
	save()


## The tracked champion's record when `unit` is the tracked player and `item`
## is one of that record's items; else null (a test's loose item isn't saved).
func _tracked_record(unit: Unit, item: Item) -> ChampionInventory:
	if unit == null or unit != get_tracked_player() or _champion == null or item == null:
		return null
	var record := get_inventory(_champion)
	return record if record.get_item(item.uid) == item else null
