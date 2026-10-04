extends Node
## Every champion's inventory (LOOT.md): a ChampionInventory per champion id,
## saved to user://inventory.cfg (a ConfigFile, one section per champion; its
## own file, so a corrupt or huge inventory never touches talent progress).
## Autoloaded as Loot, after Progress and before Audio. LOOT L2 (get_depth():
## L3; drops and pickups: L7).
##
## The Player tracks itself when its champion loads (track()) and equips its
## saved gear. Equipping and unequipping on the tracked player update its
## record (Events.item_equipped / item_unequipped); only items of the record
## are remembered.
##
## Drops (L7): a kill by the tracked player (the last hit, Events.unit_died's
## ctx.source; ALLIES widens it to its AI ally) of an enemy that isn't a
## training dummy rolls the dead unit's drop table at the room's depth with
## the killer's magic find, and each item pops out of the corpse as a Pickup
## (drop()). The champion collects it on proximity (PickupComponent ->
## collect()): into the inventory, saved, item_picked_up (the HUD's loot line),
## the pickup sound. Ground drops can be taken off a room and put back where
## they lay (take_ground_drops() / restore_ground_drops(), DUNGEONS D1's
## floor rebuilds).
##
## Saved when an item is added, an equipped slot changes, the tracked player
## leaves the tree and the window closes. A scene under res://scenes/tests/
## never reads or writes the save (Progress.is_test_scene(), the same guard):
## its records start fresh and stay in memory, and its kills drop nothing
## unless a test turns drops_enabled on. A scripted harness sets
## saving_enabled = false first.

## A pickup was collected: `item` is in `champion_id`'s inventory now (saved).
signal item_picked_up(champion_id: StringName, item: Item)

const SAVE_PATH := "user://inventory.cfg"
const PICKUP_SCENE_PATH := "res://scenes/loot/pickup.tscn"

## Off: nothing is read from or written to save_path (a test scene turns it
## off by itself before the first record is made).
var saving_enabled: bool = true
var save_path: String = SAVE_PATH
## Off: kills drop nothing (drop() still works). A scene under
## res://scenes/tests/ turns it off by itself at its first kill, so no other
## suite's kills change; a test of drops sets it (on or off), which wins.
var drops_enabled: bool = true:
	set(value):
		drops_enabled = value
		_drops_decided = true
## The rules every roll and value uses (the default LootTable).
var table: LootTable
## Drops' rolls (the items and where each lands); tests seed it.
var rng := RandomNumberGenerator.new()

var _cfg := ConfigFile.new()
var _loaded: bool = false
var _records: Dictionary = {}   # champion id -> ChampionInventory
var _player: Player
var _champion: ChampionData
var _drops_decided: bool = false
var _pickup_scene: PackedScene


func _ready() -> void:
	table = LootTable.get_default()
	rng.randomize()
	# load(), not preload(): pickup.gd names this autoload.
	_pickup_scene = load(PICKUP_SCENE_PATH)
	Events.item_equipped.connect(_on_item_equipped)
	Events.item_unequipped.connect(_on_item_unequipped)
	Events.unit_died.connect(_on_unit_died)


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


## The depth drops at `node` roll at (LOOT.md, Drops): the nearest Room
## above it (or itself), its `depth`; else 1. DUNGEONS.md takes it over.
func get_depth(node: Node) -> int:
	var at := node
	while at != null and not (at is Room):
		at = at.get_parent()
	return maxi(1, (at as Room).depth) if at != null else 1


# --- Drops and pickups (L7) -----------------------------------------------------

## Whether kills drop now: drops_enabled, which a test scene turns off by
## itself unless a test has set it.
func are_drops_enabled() -> bool:
	if not _drops_decided:
		drops_enabled = not Progress.is_test_scene()   # the setter marks it decided
	return drops_enabled


## Who a kill's drops go to (LOOT.md, Drops: the kill credit, for now): the
## tracked player when it landed the last hit (`ctx.source`) on a unit of
## another team that isn't a training dummy; else null (no drop). ALLIES
## widens it to the player's AI ally (Allies.is_party_member()).
func get_drop_credit(unit: Unit, ctx: HitContext) -> Player:
	var player := get_tracked_player()
	if player == null or unit == null or ctx == null or ctx.source != player or player.champion == null:
		return null
	if unit.team == player.team or (unit is Enemy and (unit as Enemy).passive):
		return null
	return player


## One kill's roll: the dead unit's drop table (LootTable.get_drop_table()) at
## the depth where it died, with the killer's magic find, for the killer's
## champion (its named items). Empty when the table's chance misses.
func roll_kill_drop(unit: Unit, killer: Player) -> Array[Item]:
	var drop_table := table.get_drop_table(unit)
	if drop_table == null or killer == null:
		return []
	var magic_find := killer.stats_component.get_stat(&"magic_find") if killer.stats_component != null else 0.0
	return ItemRoller.roll_drop(drop_table, get_depth(unit), magic_find, killer.champion, table, rng)


## One Pickup per item under `parent` (a room's Entities), each hopping from
## `at` (px, global; over a pit: get_drop_origin()) to its own landing spot
## (Pickup.pick_landing(), rolled with rng). Returns them.
func drop(items: Array[Item], at: Vector2, parent: Node) -> Array[Pickup]:
	var out: Array[Pickup] = []
	if parent == null or not parent.is_inside_tree():
		return out
	var origin := get_drop_origin(at, parent)
	for item in items:
		if item == null:
			continue
		var pickup := _make_pickup(item)
		pickup.hop(origin, pickup.pick_landing(origin, rng))
		parent.add_child(pickup)
		out.append(pickup)
	return out


## Where drops at `at` hop from: `at`, unless it's over a pit (a unit that
## died there). Then the nearest walkable floor of the room `near` is in (its
## navigation's closest point, which the pits carve, as a leap's landing);
## outside a Room, or before its navigation is ready, the nearest point
## outside the pit (WorldQuery.push_out()), else `at`.
func get_drop_origin(at: Vector2, near: Node) -> Vector2:
	if WorldQuery.is_point_free(at, 0.5, Pickup.PIT_MASK):
		return at
	var room := _room_of(near)
	if room != null and room.nav_region != null and room.is_inside_tree():
		var map := room.get_world_2d().navigation_map
		if map.is_valid() and NavigationServer2D.map_get_iteration_id(map) > 0:
			return NavigationServer2D.region_get_closest_point(room.nav_region.get_rid(), at)
	var out := WorldQuery.push_out(at, at, 6.0, Pickup.PIT_MASK)
	return out if out.is_finite() else at


## A landed pickup collected by `collector` (its PickupComponent): the item
## into the collector's champion's inventory (a new uid, saved),
## item_picked_up (the HUD's loot line), the pickup sound, the pickup freed.
## False when there's nothing to take (already taken, still hopping, no
## champion).
func collect(pickup: Pickup, collector: Unit) -> bool:
	if pickup == null or not is_instance_valid(pickup) or pickup.is_collected() or not pickup.is_landed():
		return false
	var player := collector as Player
	var champion := player.champion if player != null else null
	if champion == null or pickup.item == null:
		return false
	var item := pickup.item
	pickup.mark_collected()
	add_item(champion, item)
	item_picked_up.emit(champion.id, item)
	if table.pickup_sound != null:
		Audio.play(table.pickup_sound)
	return true


## The pickups still on the ground under `node` (a room), not yet collected.
func get_ground_pickups(node: Node) -> Array[Pickup]:
	var out: Array[Pickup] = []
	if node != null:
		_find_pickups(node, out)
	return out


## Takes every drop still on `room`'s ground off it (freed) and returns them
## for DUNGEONS to keep (WingRun.ground_drops): {"item": item.to_dict(),
## "pos": Vector2}, one each, where it lies (a pickup still hopping counts at
## its landing spot). Called before a rebuild tears a floor down.
func take_ground_drops(room: Node) -> Array:
	var out: Array = []
	for pickup in get_ground_pickups(room):
		if pickup.item == null:
			continue
		out.append({"item": pickup.item.to_dict(), "pos": pickup.get_spot()})
		pickup.mark_collected()
	return out


## Puts drops taken by take_ground_drops() back on `room`'s ground (its
## Entities), each where it lay, landed and collectable at once, with no hop
## and no sound. Items are read for `champion` (its named items; null = the
## tracked player's); one the data no longer knows is skipped with a warning.
## Returns the pickups.
func restore_ground_drops(room: Node, drops: Array, champion: ChampionData = null) -> Array[Pickup]:
	var out: Array[Pickup] = []
	if room == null:
		return out
	var parent := room.get_node_or_null(^"Entities")
	if parent == null:
		parent = room
	var reader := champion if champion != null else _champion
	for entry: Variant in drops:
		var d: Dictionary = entry if entry is Dictionary else {}
		var item := Item.from_dict(d.get("item", {}), table, reader) if d.get("item") is Dictionary else null
		if item == null or not (d.get("pos") is Vector2):
			push_warning("Loot: a ground drop couldn't be put back (%s); skipped" % [entry])
			continue
		var pickup := _make_pickup(item)
		pickup.place(d["pos"])
		parent.add_child(pickup)
		out.append(pickup)
	return out


## Debug (SandboxLoot's P, LOOT L5): one of each of the champion's named
## items into its inventory (ItemRoller.make_named(), rolled with rng), then
## one save. Returns them (in ChampionData order).
func debug_grant_named_items(champion: ChampionData) -> Array[Item]:
	var out: Array[Item] = []
	var record := get_inventory(champion)
	for named in champion.named_items:
		if named != null:
			var item := ItemRoller.make_named(named, table, rng)
			record.add(item)
			out.append(item)
	if not out.is_empty():
		save()
	return out


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


## A kill (LOOT.md, Drops): rolled at once, while the dead unit's table,
## room and killer are known; its pickups are added at the end of the frame,
## since a death can come inside a physics callback, where neither the space
## nor a new Area2D can be touched.
func _on_unit_died(unit: Unit, ctx: HitContext) -> void:
	if not are_drops_enabled():
		return
	var killer := get_drop_credit(unit, ctx)
	if killer == null:
		return
	var items := roll_kill_drop(unit, killer)
	if not items.is_empty():
		_drop_later.call_deferred(items, unit.global_position, unit.get_parent())


## drop(), unless the corpse's parent went in the meantime (untyped: a freed
## parent can't pass as a Node).
func _drop_later(items: Array[Item], at: Vector2, parent: Variant) -> void:
	if is_instance_valid(parent) and parent is Node:
		drop(items, at, parent as Node)


func _make_pickup(item: Item) -> Pickup:
	var pickup: Pickup = _pickup_scene.instantiate()
	pickup.item = item
	return pickup


func _find_pickups(node: Node, out: Array[Pickup]) -> void:
	for child in node.get_children():
		if child is Pickup:
			if not (child as Pickup).is_collected():
				out.append(child)
		else:
			_find_pickups(child, out)


func _room_of(node: Node) -> Room:
	var at := node
	while at != null and not (at is Room):
		at = at.get_parent()
	return at as Room
