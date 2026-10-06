class_name Hub
extends Control
## The hub (TALENTS T5, functional only; NPCS.md, UI.md and the art pass
## later): the champion's level, XP and talent points, the talent screen
## (TalentScreen), and Start run / Sandbox / Clear. The main scene (F5) since
## T5; the pause menu's Back to hub returns here. Built in code: placeholder
## text and buttons, no art. Since CHAMPIONS K1 a functional champion pick
## (one button per champion; the polished champion select is UI.md's).

## The champion whose talents this hub shows: the picked one.
@export var champion: ChampionData = preload("res://data/champions/knight.tres")
## The champions the pick offers (CHAMPIONS K1), in order. The pick goes to
## Progress.picked_champion, which Main gives to the run's Player.
@export var champions: Array[ChampionData] = [
	preload("res://data/champions/knight.tres"),
	preload("res://data/champions/korsavil.tres"),
]
## Where Start run and Sandbox go. A run plays room_01's layout since the 3D
## pivot's milestone (Ryan, P-M); main.tscn keeps the tile room_01.
@export_file("*.tscn") var run_scene: String = "res://scenes/main_layout.tscn"
@export_file("*.tscn") var sandbox_scene: String = "res://scenes/sandbox_main.tscn"
## Debug buttons (+1 level, +100 uses, +100 kills, unlock all, reset, and
## since LOOT L7b clear inventory), so play tests don't need dozens of runs.
## On in hub.tscn for now.
@export var debug_tools: bool = true
## How long Clear inventory waits for its second click (s; LOOT L7b).
@export var clear_confirm_time: float = 3.0

var _clear_asked_ms: int = -1

var talent_screen: TalentScreen
var _header: Label
var _detail: Label
var _pick_buttons: Dictionary = {}   # champion id -> its Button in the pick row

const HOVER_HINT := "Hover a talent to read it. Click to put it in or take it out."


func _ready() -> void:
	if Progress.picked_champion != null and champions.has(Progress.picked_champion):
		champion = Progress.picked_champion   # back from a run: the same pick
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 4)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 3)
	margin.add_child(root)

	if champions.size() > 1:
		var pick := HBoxContainer.new()
		pick.name = "ChampionPick"
		pick.add_theme_constant_override("separation", 4)
		root.add_child(pick)
		pick.add_child(_label(8, Color(0.6, 0.6, 0.65), "Champion:"))
		var group := ButtonGroup.new()
		for c in champions:
			var button := _button(c.display_name, pick_champion.bind(c), 8)
			button.toggle_mode = true
			button.button_group = group
			button.button_pressed = c == champion
			pick.add_child(button)
			_pick_buttons[c.id] = button

	_header = _label(11, Color(1, 1, 1))
	root.add_child(_header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	talent_screen = TalentScreen.new()
	talent_screen.name = "TalentScreen"
	scroll.add_child(talent_screen)
	talent_screen.setup(champion)
	talent_screen.talent_hovered.connect(_on_talent_screen_talent_hovered)
	talent_screen.loadout_changed.connect(refresh)

	_detail = _label(8, Color(0.85, 0.85, 0.9))
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(0, 20)
	_detail.text = HOVER_HINT if not champion.talents.is_empty() else _no_talents_text()
	root.add_child(_detail)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	root.add_child(buttons)
	buttons.add_child(_button("Start run", start_run))
	buttons.add_child(_button("Sandbox", start_sandbox))
	buttons.add_child(_button("Clear talents", clear_loadout))
	if debug_tools:
		var debug := HBoxContainer.new()
		debug.name = "DebugTools"
		debug.add_theme_constant_override("separation", 4)
		root.add_child(debug)
		debug.add_child(_label(8, Color(0.6, 0.6, 0.65), "Debug:"))
		debug.add_child(_button("+1 level", debug_add_level, 8))
		debug.add_child(_button("+100 uses", func() -> void: _debug(func() -> void: Progress.debug_add_ability_uses(champion, 100)), 8))
		debug.add_child(_button("+100 kills", func() -> void: _debug(func() -> void: Progress.debug_add_kills(champion, 100)), 8))
		debug.add_child(_button("Unlock all", func() -> void: _debug(func() -> void: Progress.debug_unlock_all(champion)), 8))
		debug.add_child(_button("Reset", func() -> void: _debug(func() -> void: Progress.reset(champion)), 8))
		debug.add_child(_button("Clear inventory", debug_clear_inventory, 8))
	refresh()


## Re-reads the record: the header and every talent.
func refresh() -> void:
	_header.text = get_header_text()
	talent_screen.refresh()


## "Knight   Level 4: 1200 / 1800 XP   Talents 2 / 2" ("Level 12 (max)" at the top).
func get_header_text() -> String:
	var record := Progress.get_progress(champion)
	var leveling := champion.get_leveling()
	var level_text := "Level %d (max)" % record.level if record.level >= leveling.get_max_level() \
		else "Level %d: %d / %d XP" % [record.level, record.xp, leveling.get_xp_to_next(record.level)]
	return "%s   %s   Talents %d / %d" % [champion.display_name, level_text, record.get_points_used(), record.get_talent_points(leveling)]


## Picks the champion Start run and Sandbox play as (CHAMPIONS K1): the
## header, the talent screen and the debug tools follow it; Main gives it to
## the run's Player (Progress.picked_champion, kept for the session).
func pick_champion(c: ChampionData) -> void:
	if c == null:
		return
	champion = c
	Progress.picked_champion = c
	_clear_asked_ms = -1
	talent_screen.setup(c)
	_detail.text = HOVER_HINT if not c.talents.is_empty() else _no_talents_text()
	for id: StringName in _pick_buttons:
		(_pick_buttons[id] as Button).set_pressed_no_signal(id == c.id)
	refresh()


func start_run() -> void:
	get_tree().change_scene_to_file(run_scene)


func start_sandbox() -> void:
	get_tree().change_scene_to_file(sandbox_scene)


## Respec: free (Ryan, 2026-09-30).
func clear_loadout() -> void:
	Progress.clear_loadout(champion)
	refresh()


## Debug: exactly enough XP for the next level.
func debug_add_level() -> void:
	var record := Progress.get_progress(champion)
	var leveling := champion.get_leveling()
	if record.level < leveling.get_max_level():
		Progress.add_xp(champion, leveling.get_xp_to_next(record.level) - record.xp)
	refresh()


## Debug (LOOT L7b): empties the champion's inventory for the looting
## milestone (Loot.reset(): no items, nothing worn, saved). The first click
## only asks, in the detail line; a second within clear_confirm_time empties
## it. Returns whether it emptied.
func debug_clear_inventory() -> bool:
	var count := Loot.get_inventory(champion).items.size()
	var asked := _clear_asked_ms >= 0 and Time.get_ticks_msec() - _clear_asked_ms < roundi(clear_confirm_time * 1000.0)
	if count == 0:
		_clear_asked_ms = -1
		_detail.text = "The %s's inventory is already empty." % champion.display_name
		return false
	if not asked:
		_clear_asked_ms = Time.get_ticks_msec()
		_detail.text = "Click Clear inventory again to empty the %s's inventory (%d items, for good)." % [champion.display_name, count]
		return false
	_clear_asked_ms = -1
	Loot.reset(champion)
	_detail.text = "Emptied the %s's inventory (%d items)." % [champion.display_name, count]
	return true


## The detail line's text now (tests read it).
func get_detail_text() -> String:
	return _detail.text


func _no_talents_text() -> String:
	return "%s has no talents yet." % champion.display_name


func _debug(action: Callable) -> void:
	action.call()
	refresh()


func _on_talent_screen_talent_hovered(talent: Talent) -> void:
	_detail.text = "%s: %s" % [talent.display_name, talent.description]


func _label(font_size: int, color: Color, text: String = "") -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, action: Callable, font_size: int = 10) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	button.pressed.connect(action)
	return button
