extends Node
## Every champion's persistent progress (TALENTS.md): a ChampionProgress per
## champion id (level, XP, ability uses, kills, unlocks, loadout), counted live
## from Events and saved to user://progress.cfg (a ConfigFile, one section per
## champion) until PROGRESSION.md exists. Autoloaded as Progress, before Audio.
##
## The Player tracks itself when its champion loads (track()); only that
## unit's casts and kills count. Ability uses: Events.ability_cast, not a free
## cast, the first part of a recast, a REPLACE variant counting for the
## ability it replaces. Kills: Events.unit_died with the tracked unit as the
## kill credit and an enemy (another team) as the dead; a passive enemy (a
## training dummy) gives no kill and no XP. XP per kill: the champion's
## ChampionLeveling.
##
## Saved when a level is gained, a talent unlocks, the loadout changes, the
## tracked player leaves the tree (a scene change or restart) and the window
## closes. A scene under res://scenes/tests/ never reads or writes the save:
## its records start fresh and stay in memory (tests can't touch real progress).

signal champion_leveled_up(champion_id: StringName, level: int)
signal talent_unlocked(champion_id: StringName, talent_id: StringName)

const SAVE_PATH := "user://progress.cfg"
const TEST_SCENES_DIR := "res://scenes/tests/"

## Off: nothing is read from or written to save_path (a test scene turns it
## off by itself before the first record is made).
var saving_enabled: bool = true
var save_path: String = SAVE_PATH

var _cfg := ConfigFile.new()
var _loaded: bool = false
var _records: Dictionary = {}     # champion id -> ChampionProgress
var _champions: Dictionary = {}   # champion id -> ChampionData (seen this session)
var _player: Player
var _champion: ChampionData


func _ready() -> void:
	Events.ability_cast.connect(_on_ability_cast)
	Events.unit_died.connect(_on_unit_died)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()


## The champion's record: the one in memory, else the saved one, else a fresh
## one from the ChampionData's starting values. A saved loadout the data no
## longer allows is fixed (with a warning per change) and unlocks are
## refreshed when the record is first made.
func get_progress(champion: ChampionData) -> ChampionProgress:
	_ensure_loaded()
	var id := champion.id
	if _records.has(id):
		_champions[id] = champion
		return _records[id]
	var record: ChampionProgress = ChampionProgress.read_from(_cfg, champion) if saving_enabled else null
	if record == null:
		record = ChampionProgress.create(champion)
	_records[id] = record
	_champions[id] = champion
	record.refresh_unlocks(champion)
	for w in record.sanitize_loadout(champion, champion.get_leveling()):
		push_warning("Progress: %s's saved loadout: %s; dropped" % [id, w])
	return record


## The ChampionData last seen for `champion_id` this session, or null.
func get_champion(champion_id: StringName) -> ChampionData:
	return _champions.get(champion_id)


## Starts counting `player`'s casts and kills for `champion` (the Player calls
## it when its champion loads). Returns the champion's record.
func track(player: Player, champion: ChampionData) -> ChampionProgress:
	var record := get_progress(champion)
	_player = player
	_champion = champion
	if not player.tree_exiting.is_connected(untrack):
		player.tree_exiting.connect(untrack.bind(player))
	return record


## Stops counting `player` (it left the tree) and saves.
func untrack(player: Player) -> void:
	if _player != player:
		return
	save()
	_player = null
	_champion = null


func get_tracked_player() -> Player:
	return _player if is_instance_valid(_player) else null


## Puts a talent in the champion's loadout (the hub, T5) within the rules,
## then saves. False if the rules refuse it (ChampionProgress.get_loadout_fail_reason()).
func add_to_loadout(champion: ChampionData, talent: Talent) -> bool:
	var ok := get_progress(champion).add_to_loadout(talent, champion, champion.get_leveling())
	if ok:
		save()
	return ok


func remove_from_loadout(champion: ChampionData, talent_id: StringName) -> void:
	get_progress(champion).remove_from_loadout(talent_id, champion)
	save()


## Respec (free).
func clear_loadout(champion: ChampionData) -> void:
	get_progress(champion).clear_loadout()
	save()


## Debug: the champion back to a fresh record (the hub's debug tools).
func reset(champion: ChampionData) -> void:
	_records[champion.id] = ChampionProgress.create(champion)
	save()


## Adds XP to the champion's record, emits one champion_leveled_up per level
## gained, refreshes unlocks and saves on a level. Returns the levels gained.
func add_xp(champion: ChampionData, amount: int) -> int:
	var record := get_progress(champion)
	var gained := record.add_xp(amount, champion.get_leveling())
	for i in gained:
		champion_leveled_up.emit(champion.id, record.level - gained + 1 + i)
	_refresh_unlocks(champion)
	if gained > 0:
		save()
	return gained


## Debug (the hub's debug tools, T5): `amount` uses of each of the champion's
## four abilities, then unlocks and a save.
func debug_add_ability_uses(champion: ChampionData, amount: int) -> void:
	var record := get_progress(champion)
	for ability in [champion.q, champion.w, champion.e, champion.r]:
		if ability != null:
			record.ability_uses[ability.id] = record.get_ability_uses(ability.id) + amount
	_refresh_unlocks(champion)
	save()


## Debug: `amount` kills (no XP, no tags), then unlocks and a save.
func debug_add_kills(champion: ChampionData, amount: int) -> void:
	get_progress(champion).kills += amount
	_refresh_unlocks(champion)
	save()


## Debug: every talent of the champion unlocked.
func debug_unlock_all(champion: ChampionData) -> void:
	var record := get_progress(champion)
	for t in champion.talents:
		if t != null and not record.is_unlocked(t.id):
			record.unlocked.append(t.id)
	save()


## The tags a kill of `unit` counts toward (kills by tag). None until
## ENEMIES_AI.md decides where an enemy's tags live (Ryan, 2026-09-30).
func get_kill_tags(_unit: Unit) -> Array[StringName]:
	return []


## Writes every record to save_path (nothing while saving is off). The
## test-scene guard runs first (LOOT L2, 2026-10-03): checked before it, a
## save() that came before any get_progress() in a test scene, such as the
## close request of a windowed test that never touched Progress, wrote an
## empty config over the real file.
func save() -> void:
	_ensure_loaded()
	if not saving_enabled:
		return
	for record: ChampionProgress in _records.values():
		record.write_to(_cfg)
	var err := _cfg.save(save_path)
	if err != OK:
		push_error("Progress: couldn't save %s (error %d)" % [save_path, err])


## True in a scene under res://scenes/tests/ (no save read or written).
func is_test_scene() -> bool:
	var scene := get_tree().current_scene if is_inside_tree() else null
	return scene != null and scene.scene_file_path.begins_with(TEST_SCENES_DIR)


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if is_test_scene():
		saving_enabled = false
	if saving_enabled and FileAccess.file_exists(save_path):
		var err := _cfg.load(save_path)
		if err != OK:
			push_error("Progress: couldn't read %s (error %d); starting fresh" % [save_path, err])
			_cfg = ConfigFile.new()


func _on_ability_cast(unit: Unit, ability: Ability, ctx: CastContext) -> void:
	if unit == null or unit != get_tracked_player() or ability == null:
		return
	if ctx != null and (ctx.is_free or ctx.part != 0):
		return
	var id := ability.variant_of if ability.variant_of != &"" else ability.id
	get_progress(_champion).add_ability_use(id)
	_refresh_unlocks(_champion)


func _on_unit_died(unit: Unit, ctx: HitContext) -> void:
	var player := get_tracked_player()
	if player == null or unit == null or ctx == null or ctx.source != player:
		return
	if unit.team == player.team or (unit is Enemy and (unit as Enemy).passive):
		return
	get_progress(_champion).add_kill(get_kill_tags(unit))
	add_xp(_champion, _champion.get_leveling().get_kill_xp(unit))


func _refresh_unlocks(champion: ChampionData) -> void:
	var fresh := get_progress(champion).refresh_unlocks(champion)
	for id in fresh:
		talent_unlocked.emit(champion.id, id)
	if not fresh.is_empty():
		save()
