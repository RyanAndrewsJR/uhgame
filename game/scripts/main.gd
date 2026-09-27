extends Node2D
## Game root: loads a room, spawns the player, wires up the camera and HUD.
## To play a different room, drag another room scene into `room_scene`.

const ClickMarker := preload("res://scripts/ui/click_marker.gd")

@export var room_scene: PackedScene = preload("res://scenes/rooms/room_01.tscn")
@export var player_scene: PackedScene = preload("res://scenes/player/player.tscn")
@export var pause_menu_scene: PackedScene = preload("res://scenes/ui/pause_menu.tscn")
## Stingers (AUDIO.md): with "Room cleared!" and "You died". null = silent.
@export var room_cleared_sound: SoundEvent
@export var player_died_sound: SoundEvent

@onready var hud: CanvasLayer = $HUD
@onready var camera: Camera2D = $Camera

var room: Room
var player: Player
var pause_menu: PauseMenu
var _game_over := false


func _ready() -> void:
	room = room_scene.instantiate()
	add_child(room)
	move_child(room, 0)

	var entities: Node2D = room.get_node("Entities")
	var spawn: Marker2D = room.get_node("PlayerSpawn")

	player = player_scene.instantiate()
	player.global_position = spawn.global_position
	entities.add_child(player)

	player.health.health_changed.connect(hud.set_health)
	hud.set_health(player.health.current, player.health.max_health)
	player.died.connect(_on_player_died)
	player.move_commanded.connect(_on_move_commanded)
	player.attack_commanded.connect(_on_attack_commanded)
	player.attack_move_commanded.connect(func(p: Vector2): _spawn_marker(p, Color(1.0, 0.6, 0.2)))
	hud.setup_abilities(player)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		(enemy as Enemy).died.connect(_on_enemy_died)
	hud.set_enemies_left(get_tree().get_nodes_in_group("enemies").size())

	_setup_camera()

	pause_menu = pause_menu_scene.instantiate()
	add_child(pause_menu)


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	hud.set_info("AD %d   AS %.2f   MS %d   Range %d   |   Camera %s (Y)" % [
		roundi(player.stats_component.get_stat(&"attack_damage")),
		player.attack.get_attack_speed(),
		roundi(player.movement.get_move_speed()),
		roundi(player.stats_component.get_stat(&"attack_range")),
		"locked" if camera.locked else "free",
	])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		Audio.stop_all()   # autoloads survive the reload: no sound from the old room carries over
		get_tree().reload_current_scene()
	elif event.is_action_pressed("ui_cancel") and not pause_menu.is_open():
		# Esc pauses. An Esc that cancels an aimed ability never gets here:
		# Player handles it first (deeper in the tree) and marks it handled.
		pause_menu.open()


func _setup_camera() -> void:
	var tiles: TileMapLayer = room.get_node("Tiles")
	var rect := tiles.get_used_rect()
	var size := Vector2(tiles.tile_set.tile_size)
	camera.bounds = Rect2(Vector2(rect.position) * size, Vector2(rect.size) * size)
	camera.target = player
	camera.snap_to_target()


func _on_move_commanded(target: Vector2, is_new_click: bool) -> void:
	if is_new_click:
		_spawn_marker(target, Color(0.35, 1.0, 0.45))


func _on_attack_commanded(target: Unit, is_new_click: bool) -> void:
	if is_new_click:
		_spawn_marker(target.global_position, Color(1.0, 0.25, 0.2))


func _spawn_marker(pos: Vector2, color: Color) -> void:
	var marker := Node2D.new()
	marker.set_script(ClickMarker)
	marker.set("color", color)
	marker.global_position = pos
	# Insert below the Entities layer so the marker is drawn on the floor.
	room.add_child(marker)
	room.move_child(marker, room.get_node("Entities").get_index())


func _on_enemy_died(enemy: Enemy) -> void:
	var left := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != enemy and (e as Unit).is_alive():
			left += 1
	hud.set_enemies_left(left)
	if left == 0 and not _game_over:
		hud.show_message("Room cleared!  (Backspace to restart)")
		Audio.play(room_cleared_sound, 1.0, SoundEvent.Priority.HIGH)


func _on_player_died(_unit: Unit = null) -> void:
	_game_over = true
	hud.show_message("You died  -  press Backspace to restart")
	Audio.play(player_died_sound, 1.0, SoundEvent.Priority.HIGH)
