extends Node
## The player's own preferences (the pause menu's options), saved to
## user://settings.cfg so they survive restarts. Autoloaded as Settings.
## Gameplay reads them through the getters and listens to setting_changed to
## apply a change at once, even mid-run.
##
## Designer tuning never lives here: that's exports and .tres files.

signal setting_changed(key: StringName, value: Variant)

## Which way the dash goes.
enum DashDirection {
	CURSOR,     ## Toward the cursor at the moment Space is pressed.
	MOVE_KEYS,  ## The held WASD direction, or facing if none.
}

const SAVE_PATH := "user://settings.cfg"
const DASH_DIRECTION := &"dash_direction"

# Saved as readable words, so a hand-edited or old file can't pick a wrong
# enum value. Unknown words fall back to the default.
const _DASH_DIRECTION_NAMES := {
	DashDirection.CURSOR: "cursor",
	DashDirection.MOVE_KEYS: "move_keys",
}

var _dash_direction: DashDirection = DashDirection.CURSOR


func _ready() -> void:
	load_settings()


# --- Queries ------------------------------------------------------------------

func get_dash_direction() -> DashDirection:
	return _dash_direction


# --- Commands -----------------------------------------------------------------

## Saves at once and emits setting_changed if the value changed.
func set_dash_direction(value: DashDirection) -> void:
	if value == _dash_direction:
		return
	_dash_direction = value
	save_settings()
	setting_changed.emit(DASH_DIRECTION, value)


## Reads SAVE_PATH. A missing or unreadable file keeps the defaults.
func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	var dash_name: String = str(cfg.get_value("controls", DASH_DIRECTION, ""))
	for value in _DASH_DIRECTION_NAMES:
		if _DASH_DIRECTION_NAMES[value] == dash_name:
			_dash_direction = value


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)   # Keep any other sections already in the file.
	cfg.set_value("controls", DASH_DIRECTION, _DASH_DIRECTION_NAMES[_dash_direction])
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("Settings: couldn't save %s (error %d)" % [SAVE_PATH, err])
