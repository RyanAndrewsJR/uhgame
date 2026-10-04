extends Node2D
## Game root: loads a room, spawns the player, adds the 3D view and wires up
## the HUD. To play a different room, drag another room scene into
## `room_scene`.

@export var room_scene: PackedScene = preload("res://scenes/rooms/room_01.tscn")
@export var player_scene: PackedScene = preload("res://scenes/player/player.tscn")
@export var pause_menu_scene: PackedScene = preload("res://scenes/ui/pause_menu.tscn")
## Stingers (AUDIO.md): with "Room cleared!" and "You died". null = silent.
@export var room_cleared_sound: SoundEvent
@export var player_died_sound: SoundEvent

@onready var hud: CanvasLayer = $HUD

var room: Room
## The room built in 3D when room_scene is one (a RoomLayout, docs/3D.md,
## Rooms): the 3D view shows it, and `room` is the sim it made. null for a
## tile room.
var layout: RoomLayout
var player: Player
var pause_menu: PauseMenu
## The 3D view (docs/3D.md): it hides the 2D sim from the screen and shows
## the room through GameCamera3D. Always on since the 3D pivot's cleanup C3
## (the flag `use_3d_view` and the 2D game went then).
var world_view: WorldView
var _game_over := false


func _ready() -> void:
	var scene_root := room_scene.instantiate()
	layout = scene_root as RoomLayout
	room = layout.build_sim() if layout else scene_root as Room
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
	hud.setup_abilities(player)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		(enemy as Enemy).died.connect(_on_enemy_died)
	hud.set_enemies_left(get_tree().get_nodes_in_group("enemies").size())

	world_view = WorldView.new()
	add_child(world_view)
	world_view.setup(self, room, player, layout)

	pause_menu = pause_menu_scene.instantiate()
	add_child(pause_menu)


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var camera_locked: bool = world_view.camera != null and world_view.camera.locked
	hud.set_info("AD %d   AS %.2f   MS %d   Range %d   |   Camera %s (Y)" % [
		roundi(player.stats_component.get_stat(&"attack_damage")),
		player.attack.get_attack_speed(),
		roundi(player.movement.get_move_speed()),
		roundi(player.stats_component.get_stat(&"attack_range")),
		"locked" if camera_locked else "free",
	])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		Audio.stop_all()   # autoloads survive the reload: no sound from the old room carries over
		get_tree().reload_current_scene()
	elif event.is_action_pressed("ui_cancel") and not pause_menu.is_open():
		# Esc pauses. An Esc that cancels an aimed ability never gets here:
		# Player handles it first (deeper in the tree) and marks it handled.
		pause_menu.open()


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
