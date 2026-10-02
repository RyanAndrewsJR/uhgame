extends Node
## The player's own preferences (the pause menu's options), saved to
## user://settings.cfg so they survive restarts. Autoloaded as Settings.
## Gameplay reads them through the getters and listens to setting_changed to
## apply a change at once, even mid-run. Options: the dash direction
## (MOVEMENT.md), the cast mode (ABILITIES.md; Player applies it) and one
## volume per audio bus (AUDIO.md; Audio applies them).
##
## The file is read at the first query or change made while a scene is
## current. A scene under res://scenes/tests/ never reads or writes it: its
## settings start at the defaults and stay in memory (tests can't touch the
## player's settings), like Progress.
##
## Designer tuning never lives here: that's exports and .tres files.

signal setting_changed(key: StringName, value: Variant)

## Which way the dash goes.
enum DashDirection {
	CURSOR,     ## Toward the cursor at the moment Space is pressed.
	MOVE_KEYS,  ## The held WASD direction, or facing if none.
}

const SAVE_PATH := "user://settings.cfg"
const TEST_SCENES_DIR := "res://scenes/tests/"
const DASH_DIRECTION := &"dash_direction"
## How INSTANT abilities cast: Player.CastMode (ABILITIES.md, Cast mode).
const CAST_MODE := &"cast_mode"
## Every bus in default_bus_layout.tres, in order: the one bus list (Audio
## and the pause menu read it). One volume slider per bus (AUDIO.md); their
## keys are &"volume_<bus>" in lower case (&"volume_master"...), saved as
## whole percents in [audio].
const VOLUME_BUSES: Array[StringName] = [&"Master", &"Music", &"SFX", &"UI", &"Ambience", &"Voice"]

# Saved as readable words, so a hand-edited or old file can't pick a wrong
# enum value. Unknown words fall back to the default.
const _DASH_DIRECTION_NAMES := {
	DashDirection.CURSOR: "cursor",
	DashDirection.MOVE_KEYS: "move_keys",
}
const _CAST_MODE_NAMES := {
	Player.CastMode.QUICK: "quick",
	Player.CastMode.QUICK_WITH_INDICATOR: "quick_with_indicator",
}

## Off: nothing is read from or written to save_path (a test scene turns it
## off by itself at the first read).
var saving_enabled: bool = true
var save_path: String = SAVE_PATH

var _dash_direction: DashDirection = DashDirection.CURSOR
var _cast_mode: Player.CastMode = Player.CastMode.QUICK
var _volumes: Dictionary = {}   # bus -> 0..1 (1 = full, the default)
var _loaded: bool = false
var _warned_no_scene: bool = false


# --- Queries ------------------------------------------------------------------

func get_dash_direction() -> DashDirection:
	_ensure_loaded()
	return _dash_direction


## QUICK (cast at the cursor on press; the default) or QUICK_WITH_INDICATOR
## (hold to aim, release to cast). Only INSTANT abilities use it.
func get_cast_mode() -> Player.CastMode:
	_ensure_loaded()
	return _cast_mode


## The player's volume for a bus, 0..1 (1 = the bus's own level, 0 = muted).
func get_volume(bus: StringName) -> float:
	if not bus in VOLUME_BUSES:
		push_error("Settings: no volume for bus '%s'" % bus)
		return 1.0
	_ensure_loaded()
	return _volumes.get(bus, 1.0)


## True in a scene under res://scenes/tests/ (no file read or written).
func is_test_scene() -> bool:
	var scene := get_tree().current_scene if is_inside_tree() else null
	return scene != null and scene.scene_file_path.begins_with(TEST_SCENES_DIR)


## The setting_changed key for a bus's volume: &"volume_master", &"volume_sfx"...
static func get_volume_key(bus: StringName) -> StringName:
	return StringName("volume_" + String(bus).to_lower())


# --- Commands -----------------------------------------------------------------

## Saves at once and emits setting_changed if the value changed.
func set_dash_direction(value: DashDirection) -> void:
	_ensure_loaded()
	if value == _dash_direction:
		return
	_dash_direction = value
	save_settings()
	setting_changed.emit(DASH_DIRECTION, value)


## Saves at once and emits setting_changed if the value changed.
func set_cast_mode(value: Player.CastMode) -> void:
	_ensure_loaded()
	if value == _cast_mode:
		return
	_cast_mode = value
	save_settings()
	setting_changed.emit(CAST_MODE, value)


## 0..1, stored in whole percents. Saves at once and emits setting_changed
## (key get_volume_key(bus)) if the value changed.
func set_volume(bus: StringName, value: float) -> void:
	if not bus in VOLUME_BUSES:
		push_error("Settings: no volume for bus '%s'" % bus)
		return
	value = roundf(clampf(value, 0.0, 1.0) * 100.0) / 100.0
	if is_equal_approx(value, get_volume(bus)):
		return
	_volumes[bus] = value
	save_settings()
	setting_changed.emit(get_volume_key(bus), value)


## Reads save_path (nothing while saving is off). A missing or unreadable
## file keeps the defaults.
func load_settings() -> void:
	if not saving_enabled:
		return
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	var dash_name: String = str(cfg.get_value("controls", DASH_DIRECTION, ""))
	for value in _DASH_DIRECTION_NAMES:
		if _DASH_DIRECTION_NAMES[value] == dash_name:
			_dash_direction = value
	var cast_mode_name: String = str(cfg.get_value("controls", CAST_MODE, ""))
	for value in _CAST_MODE_NAMES:
		if _CAST_MODE_NAMES[value] == cast_mode_name:
			_cast_mode = value
	for bus in VOLUME_BUSES:
		var percent: Variant = cfg.get_value("audio", get_volume_key(bus), 100)
		if percent is int or percent is float:
			_volumes[bus] = clampf(float(percent) / 100.0, 0.0, 1.0)


## Writes save_path. Nothing while saving is off, or before the file has been
## read (no scene was current yet, so it isn't known whether this is a test).
func save_settings() -> void:
	if not saving_enabled or not _loaded:
		return
	var cfg := ConfigFile.new()
	cfg.load(save_path)   # Keep any other sections already in the file.
	cfg.set_value("controls", DASH_DIRECTION, _DASH_DIRECTION_NAMES[_dash_direction])
	cfg.set_value("controls", CAST_MODE, _CAST_MODE_NAMES[_cast_mode])
	for bus in VOLUME_BUSES:
		cfg.set_value("audio", get_volume_key(bus), roundi(get_volume(bus) * 100.0))
	var err := cfg.save(save_path)
	if err != OK:
		push_warning("Settings: couldn't save %s (error %d)" % [save_path, err])


## Reads the file once, at the first query or change made while a scene is
## current: the scene tells a test run apart. With no current scene it
## doesn't decide (or latch) yet: the defaults answer, nothing is read or
## saved, and the next call tries again. Godot 4.7.2 sets current_scene
## before the autoloads' _ready() (checked 2026-10-01), so Audio's first read
## already decides; the warning shows if that ever stops being true.
func _ensure_loaded() -> void:
	if _loaded:
		return
	if not is_inside_tree() or get_tree().current_scene == null:
		if not _warned_no_scene:
			_warned_no_scene = true
			push_warning("Settings: read before any scene was current; the defaults answer until one is")
		return
	_loaded = true
	if is_test_scene():
		saving_enabled = false
	load_settings()
