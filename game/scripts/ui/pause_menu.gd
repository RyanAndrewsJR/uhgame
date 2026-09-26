class_name PauseMenu
extends CanvasLayer
## Esc pause menu: pauses the game and shows the player's options (Settings).
## main.gd opens it on Esc (unless that Esc cancelled an aimed ability);
## Esc again or Resume closes it. Runs while the game is paused
## (process_mode = Always in pause_menu.tscn).

@onready var _dash_button: Button = %DashButton
@onready var _resume_button: Button = %ResumeButton


func _ready() -> void:
	visible = false
	_dash_button.pressed.connect(_on_dash_button_pressed)
	_resume_button.pressed.connect(close)
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


func _on_settings_setting_changed(_key: StringName, _value: Variant) -> void:
	_refresh()


func _refresh() -> void:
	var cursor := Settings.get_dash_direction() == Settings.DashDirection.CURSOR
	_dash_button.text = "Dash direction: %s" % ("Cursor" if cursor else "Move keys (WASD)")
