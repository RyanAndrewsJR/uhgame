class_name PauseMenu
extends CanvasLayer
## Esc pause menu: pauses the game and shows the player's options (Settings).
## main.gd opens it on Esc (unless that Esc cancelled an aimed ability, a
## charge-up or a vector aim: the Player marks those handled);
## Esc again or Resume closes it. Runs while the game is paused
## (process_mode = Always in pause_menu.tscn).
## Options: the dash direction, the cast mode (ABILITIES.md), and one volume
## slider per audio bus (Settings.VOLUME_BUSES, built in code under %Volumes;
## AUDIO.md).

## Font size of the volume rows (matches the buttons).
const VOLUME_FONT_SIZE := 10

@onready var _dash_button: Button = %DashButton
@onready var _cast_mode_button: Button = %CastModeButton
@onready var _resume_button: Button = %ResumeButton
@onready var _volumes: VBoxContainer = %Volumes

var _volume_sliders: Dictionary = {}   # bus -> HSlider
var _volume_labels: Dictionary = {}    # bus -> Label (the percent)


func _ready() -> void:
	visible = false
	_dash_button.pressed.connect(_on_dash_button_pressed)
	_cast_mode_button.pressed.connect(_on_cast_mode_button_pressed)
	_resume_button.pressed.connect(close)
	_build_volume_rows()
	Settings.setting_changed.connect(_on_settings_setting_changed)
	_refresh()


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	visible = true
	get_tree().paused = true
	_refresh()
	_resume_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	# Don't leave a hidden button focused: Space (dash) is also ui_accept.
	get_viewport().gui_release_focus()
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		# Main would otherwise see the same Esc and open the menu again.
		get_viewport().set_input_as_handled()


func _on_dash_button_pressed() -> void:
	var cursor := Settings.get_dash_direction() == Settings.DashDirection.CURSOR
	Settings.set_dash_direction(Settings.DashDirection.MOVE_KEYS if cursor else Settings.DashDirection.CURSOR)


func _on_cast_mode_button_pressed() -> void:
	var quick := Settings.get_cast_mode() == Player.CastMode.QUICK
	Settings.set_cast_mode(Player.CastMode.QUICK_WITH_INDICATOR if quick else Player.CastMode.QUICK)


func _on_settings_setting_changed(_key: StringName, _value: Variant) -> void:
	_refresh()


func _refresh() -> void:
	var cursor := Settings.get_dash_direction() == Settings.DashDirection.CURSOR
	_dash_button.text = "Dash direction: %s" % ("Cursor" if cursor else "Move keys (WASD)")
	var quick := Settings.get_cast_mode() == Player.CastMode.QUICK
	_cast_mode_button.text = "Cast mode: %s" % ("Quick" if quick else "Hold to aim")
	for bus: StringName in _volume_sliders:
		var percent := roundi(Settings.get_volume(bus) * 100.0)
		(_volume_sliders[bus] as HSlider).set_value_no_signal(percent)
		(_volume_labels[bus] as Label).text = "%d%%" % percent


## One row per bus: name, a 0-100 slider (steps of 5), the percent.
func _build_volume_rows() -> void:
	for bus in Settings.VOLUME_BUSES:
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = String(bus)
		name_label.custom_minimum_size = Vector2(56, 0)
		name_label.add_theme_font_size_override(&"font_size", VOLUME_FONT_SIZE)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.step = 5.0
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value_changed.connect(_on_volume_slider_value_changed.bind(bus))
		var percent_label := Label.new()
		percent_label.custom_minimum_size = Vector2(32, 0)
		percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		percent_label.add_theme_font_size_override(&"font_size", VOLUME_FONT_SIZE)
		row.add_child(name_label)
		row.add_child(slider)
		row.add_child(percent_label)
		_volumes.add_child(row)
		_volume_sliders[bus] = slider
		_volume_labels[bus] = percent_label


func _on_volume_slider_value_changed(value: float, bus: StringName) -> void:
	Settings.set_volume(bus, value / 100.0)
