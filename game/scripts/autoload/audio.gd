extends Node
## The one way to play sounds (AUDIO.md). Autoloaded as Audio, after Settings.
##
## - play(): a centered one-shot. play_at(): at a world point (centered when
##   the source is the Player). play_on(): follows a node and stops when the
##   node leaves the tree (loops on units and telegraphs).
## - Every play returns an int handle (0 = nothing played) for stop().
## - Limits, in order: a SoundEvent starts at most max_instances copies within
##   any min_interval window (real time); a positional one-shot beyond its
##   max_distance_px isn't started; on the SFX bus, a full voice cap drops the
##   new sound unless it outranks the lowest-priority one, which it stops.
## - Real time: limits use Time.get_ticks_msec(), fades use real seconds, and
##   Engine.time_scale (hitstop) never slows or pitches a sound.
## - Pause: players on SFX, Ambience and Voice pause with the scene tree;
##   Music and UI keep playing, and Music ducks (and low-passes) while paused.
## - Volumes: each bus = its level in default_bus_layout.tres + the player's
##   slider in Settings (0 mutes).
## - Every play, drop, stop and steal is logged (get_log()) so tests can check
##   audio without hearing it; debug_draw lists the recent ones on screen.

## Every bus in default_bus_layout.tres, in order.
const BUSES: Array[StringName] = [&"Master", &"Music", &"SFX", &"UI", &"Ambience", &"Voice"]
## Buses whose players pause with the scene tree (AUDIO.md, Rules).
const PAUSABLE_BUSES: Array[StringName] = [&"SFX", &"Ambience", &"Voice"]

const RESULT_PLAYED := &"played"
const RESULT_DROPPED := &"dropped"
const RESULT_STOPPED := &"stopped"
const RESULT_STOLEN := &"stolen"

## The mix-wide numbers: voice cap, pause duck, log and debug sizes.
@export var mix: AudioMix = preload("res://data/audio_mixes/audio_mix_default.tres")
## Lists the recent sounds on screen (dropped and stolen ones in red). Toggle
## it in the Remote scene tree while the game runs.
@export var debug_draw: bool = false


## One sound that's playing.
class Voice:
	extends RefCounted
	var handle: int
	var event: SoundEvent
	var player: Node   # AudioStreamPlayer (centered) or AudioStreamPlayer2D
	var bus: StringName
	var priority: int
	var started_ms: int
	var follow: Node2D   # play_on(): followed, and the sound stops when it leaves the tree
	var follow_exit: Callable


var _voices: Dictionary = {}          # handle -> Voice
var _voice_by_player: Dictionary = {} # player -> Voice
var _next_handle: int = 1
var _starts: Dictionary = {}          # SoundEvent -> Array of start times (ms)
var _warned: Dictionary = {}          # SoundEvent -> true (no usable audio, warned once)
var _log: Array[Dictionary] = []
var _free_flat: Array[AudioStreamPlayer] = []
var _free_2d: Array[AudioStreamPlayer2D] = []
var _base_db: Dictionary = {}         # bus -> its level from the bus layout
var _duck_db: float = 0.0             # Music's current pause duck
var _music_low_pass: int = -1         # effect index on the Music bus
var _last_ticks_usec: int = 0
var _debug_layer: CanvasLayer
var _debug_text: RichTextLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # fades, bookkeeping and debug run while paused
	for bus in BUSES:
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			push_warning("Audio: bus '%s' is missing from default_bus_layout.tres" % bus)
			continue
		_base_db[bus] = AudioServer.get_bus_volume_db(index)
	_music_low_pass = _find_effect(&"Music", "AudioEffectLowPassFilter")
	Settings.setting_changed.connect(_on_settings_setting_changed)
	_last_ticks_usec = Time.get_ticks_usec()
	_apply_bus_volumes()


# --- Playing --------------------------------------------------------------------

## A centered sound. Returns its handle (0 = nothing played).
func play(event: SoundEvent, pitch: float = 1.0, priority: int = -1) -> int:
	return _play(event, Vector2.ZERO, false, null, pitch, priority)


## A sound at a world point. Centered when `source` is the Player or the
## event isn't positional. Returns its handle (0 = nothing played).
func play_at(event: SoundEvent, position: Vector2, source: Unit = null, pitch: float = 1.0, priority: int = -1) -> int:
	return _play(event, position, not _is_player(source), null, pitch, priority)


## A sound that follows `node` and stops when the node leaves the tree.
## Centered when the node is the Player or the event isn't positional.
## Returns its handle (0 = nothing played).
func play_on(event: SoundEvent, node: Node2D, pitch: float = 1.0, priority: int = -1) -> int:
	if event != null and (not is_instance_valid(node) or not node.is_inside_tree()):
		_add_log(_make_entry(event, Vector2.ZERO, false, _priority_of(event, priority)), RESULT_DROPPED, &"no_owner")
		return 0
	var position := node.global_position if node != null else Vector2.ZERO
	return _play(event, position, not _is_player(node), node, pitch, priority)


## Stops a sound. 0 or a sound that already ended does nothing.
func stop(handle: int) -> void:
	var voice: Voice = _voices.get(handle)
	if voice != null:
		_stop_voice(voice, RESULT_STOPPED, &"stop")


## Stops every sound played on `node` (play_on()).
func stop_all_on(node: Node) -> void:
	for voice: Voice in _voices.values():
		if voice.follow == node:
			_stop_voice(voice, RESULT_STOPPED, &"stop_all_on")


## Stops every sound on SFX, Ambience and Voice (a scene restart) and clears
## the instance-limit history. Music and UI keep playing.
func stop_all() -> void:
	for voice: Voice in _voices.values():
		if voice.bus in PAUSABLE_BUSES:
			_stop_voice(voice, RESULT_STOPPED, &"stop_all")
	_starts.clear()


# --- Queries --------------------------------------------------------------------

func is_playing(handle: int) -> bool:
	return _voices.has(handle)


## The player node behind a handle (for tests and debugging), or null.
func get_player(handle: int) -> Node:
	var voice: Voice = _voices.get(handle)
	return voice.player if voice != null else null


## Every play, drop, stop and steal, oldest first (the last mix.log_size).
## Each entry: time_ms, frame, event (resource path or name), sound (the
## SoundEvent), handle, result, reason, bus, priority, positional, position.
func get_log() -> Array[Dictionary]:
	return _log.duplicate()


func clear_log() -> void:
	_log.clear()


## A bus's level from default_bus_layout.tres (dB), before the player's
## volume and the pause duck.
func get_bus_base_db(bus: StringName) -> float:
	return _base_db.get(bus, 0.0)


## Where positional sounds are heard from: the screen center in world space
## (Godot's default with no AudioListener2D: the camera's actual view).
func get_listener_position() -> Vector2:
	var viewport := get_viewport()
	return viewport.get_canvas_transform().affine_inverse() * (viewport.get_visible_rect().size * 0.5)


# --- Update ---------------------------------------------------------------------

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real_delta := (now - _last_ticks_usec) / 1_000_000.0
	_last_ticks_usec = now
	_update_pause(real_delta)
	_update_debug_draw()


func _physics_process(_delta: float) -> void:
	for voice: Voice in _voices.values():
		if voice.follow != null and voice.player is AudioStreamPlayer2D and is_instance_valid(voice.follow):
			(voice.player as AudioStreamPlayer2D).global_position = voice.follow.global_position


# --- Internals ------------------------------------------------------------------

func _play(event: SoundEvent, position: Vector2, wants_position: bool, follow: Node2D, pitch: float, priority: int) -> int:
	if event == null:
		return 0
	var positional := wants_position and event.positional
	var prio := _priority_of(event, priority)
	var entry := _make_entry(event, position, positional, prio)

	var stream := event.get_stream()
	if stream == null:
		if not _warned.has(event):
			_warned[event] = true
			push_warning("Audio: %s has no usable audio (missing or empty files); it stays silent." % event.get_display_name())
		return _drop(entry, &"no_audio")

	var now := Time.get_ticks_msec()
	var window_ms := event.min_interval * 1000.0
	var starts: Array = (_starts.get(event, []) as Array).filter(func(t: int) -> bool: return now - t < window_ms)
	_starts[event] = starts
	if starts.size() >= event.max_instances:
		return _drop(entry, &"instance_limit")

	if positional and not event.loop and position.distance_to(get_listener_position()) > event.max_distance_px:
		return _drop(entry, &"out_of_range")

	var bus := event.get_bus_name()
	if bus == &"SFX" and _count_voices(&"SFX") >= mix.voice_cap:
		var lowest := _find_lowest(&"SFX")
		if lowest == null or prio <= lowest.priority:
			return _drop(entry, &"voice_cap")
		_stop_voice(lowest, RESULT_STOLEN, StringName("by " + event.get_display_name()))

	starts.append(now)
	var voice := Voice.new()
	voice.handle = _next_handle
	_next_handle += 1
	voice.event = event
	voice.bus = bus
	voice.priority = prio
	voice.started_ms = now
	voice.player = _start_player(event, stream, bus, positional, position, pitch)
	if follow != null:
		voice.follow = follow
		voice.follow_exit = _on_follow_tree_exiting.bind(voice.handle)
		follow.tree_exiting.connect(voice.follow_exit)
	_voices[voice.handle] = voice
	_voice_by_player[voice.player] = voice
	entry.handle = voice.handle
	_add_log(entry, RESULT_PLAYED, &"")
	return voice.handle


func _start_player(event: SoundEvent, stream: AudioStream, bus: StringName, positional: bool, position: Vector2, pitch: float) -> Node:
	var player: Node
	if positional:
		var p2 := _take_player_2d()
		p2.max_distance = event.max_distance_px
		p2.attenuation = 1.0
		p2.panning_strength = 1.0
		p2.global_position = position
		p2.stream = stream
		p2.bus = bus
		p2.volume_db = event.volume_db
		p2.pitch_scale = maxf(event.pitch_scale * pitch, 0.01)
		player = p2
	else:
		var p := _take_player_flat()
		p.stream = stream
		p.bus = bus
		p.volume_db = event.volume_db
		p.pitch_scale = maxf(event.pitch_scale * pitch, 0.01)
		player = p
	player.process_mode = Node.PROCESS_MODE_PAUSABLE if bus in PAUSABLE_BUSES else Node.PROCESS_MODE_ALWAYS
	player.call(&"play")
	return player


func _take_player_flat() -> AudioStreamPlayer:
	if not _free_flat.is_empty():
		return _free_flat.pop_back()
	var p := AudioStreamPlayer.new()
	p.finished.connect(_on_player_finished.bind(p))
	add_child(p)
	return p


func _take_player_2d() -> AudioStreamPlayer2D:
	if not _free_2d.is_empty():
		return _free_2d.pop_back()
	var p := AudioStreamPlayer2D.new()
	p.finished.connect(_on_player_finished.bind(p))
	add_child(p)
	return p


func _stop_voice(voice: Voice, result: StringName, reason: StringName) -> void:
	var entry := _make_entry(voice.event, Vector2.ZERO, voice.player is AudioStreamPlayer2D, voice.priority)
	entry.handle = voice.handle
	_release(voice)
	_add_log(entry, result, reason)


## Returns a voice's player to the pool. Not logged by itself (a sound that
## finished on its own isn't an entry).
func _release(voice: Voice) -> void:
	_voices.erase(voice.handle)
	_voice_by_player.erase(voice.player)
	if voice.follow != null and is_instance_valid(voice.follow) and voice.follow.tree_exiting.is_connected(voice.follow_exit):
		voice.follow.tree_exiting.disconnect(voice.follow_exit)
	voice.follow = null
	voice.player.call(&"stop")
	voice.player.set(&"stream", null)
	if voice.player is AudioStreamPlayer2D:
		_free_2d.append(voice.player)
	else:
		_free_flat.append(voice.player)


func _on_player_finished(player: Node) -> void:
	var voice: Voice = _voice_by_player.get(player)
	if voice == null:
		return
	if voice.event.loop:
		player.call(&"play")   # a loop whose file wasn't imported as a loop: start it again
	else:
		_release(voice)


func _on_follow_tree_exiting(handle: int) -> void:
	var voice: Voice = _voices.get(handle)
	if voice != null:
		_stop_voice(voice, RESULT_STOPPED, &"owner_left_tree")


func _count_voices(bus: StringName) -> int:
	var count := 0
	for voice: Voice in _voices.values():
		if voice.bus == bus:
			count += 1
	return count


## The lowest-priority voice on `bus`, the oldest among equals.
func _find_lowest(bus: StringName) -> Voice:
	var lowest: Voice = null
	for voice: Voice in _voices.values():
		if voice.bus != bus:
			continue
		if lowest == null or voice.priority < lowest.priority \
				or (voice.priority == lowest.priority and voice.started_ms < lowest.started_ms):
			lowest = voice
	return lowest


func _priority_of(event: SoundEvent, priority: int) -> int:
	return event.priority if priority < 0 else priority


func _is_player(node: Node) -> bool:
	return node is Player


# --- Log ------------------------------------------------------------------------

func _make_entry(event: SoundEvent, position: Vector2, positional: bool, priority: int) -> Dictionary:
	return {
		"time_ms": Time.get_ticks_msec(),
		"frame": Engine.get_physics_frames(),
		"event": event.resource_path if not event.resource_path.is_empty() else event.get_display_name(),
		"sound": event,
		"handle": 0,
		"result": &"",
		"reason": &"",
		"bus": event.get_bus_name(),
		"priority": priority,
		"positional": positional,
		"position": position,
	}


func _drop(entry: Dictionary, reason: StringName) -> int:
	_add_log(entry, RESULT_DROPPED, reason)
	return 0


func _add_log(entry: Dictionary, result: StringName, reason: StringName) -> void:
	entry.result = result
	entry.reason = reason
	_log.append(entry)
	while _log.size() > maxi(mix.log_size, 1):
		_log.pop_front()


# --- Buses and pause ------------------------------------------------------------

func _apply_bus_volumes() -> void:
	for bus in BUSES:
		_apply_bus_volume(bus)


## The bus's layout level + the player's volume (0 mutes) + the pause duck on Music.
func _apply_bus_volume(bus: StringName) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0 or not _base_db.has(bus):
		return
	var volume := Settings.get_volume(bus)
	AudioServer.set_bus_mute(index, volume <= 0.0)
	var db: float = _base_db[bus]
	if volume > 0.0:
		db += linear_to_db(volume)
	if bus == &"Music":
		db += _duck_db
	AudioServer.set_bus_volume_db(index, db)


func _update_pause(real_delta: float) -> void:
	var paused := get_tree().paused
	var target := mix.pause_music_duck_db if paused else 0.0
	if not is_equal_approx(_duck_db, target):
		var step := absf(mix.pause_music_duck_db) * real_delta / maxf(mix.duck_fade_time, 0.001)
		_duck_db = move_toward(_duck_db, target, step)
		_apply_bus_volume(&"Music")
	var music := AudioServer.get_bus_index(&"Music")
	if _music_low_pass >= 0 and music >= 0:
		var low_pass_on := paused and mix.pause_low_pass
		if AudioServer.is_bus_effect_enabled(music, _music_low_pass) != low_pass_on:
			var effect := AudioServer.get_bus_effect(music, _music_low_pass) as AudioEffectLowPassFilter
			if effect != null:
				effect.cutoff_hz = mix.pause_low_pass_hz
			AudioServer.set_bus_effect_enabled(music, _music_low_pass, low_pass_on)


## The index of the first effect of this class on `bus`, or -1.
func _find_effect(bus: StringName, effect_class: String) -> int:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return -1
	for i in AudioServer.get_bus_effect_count(index):
		if AudioServer.get_bus_effect(index, i).is_class(effect_class):
			return i
	return -1


func _on_settings_setting_changed(key: StringName, _value: Variant) -> void:
	if String(key).begins_with("volume_"):
		_apply_bus_volumes()


# --- Debug draw -----------------------------------------------------------------

func _update_debug_draw() -> void:
	if not debug_draw:
		if _debug_layer != null:
			_debug_layer.visible = false
		return
	if _debug_layer == null:
		_debug_layer = CanvasLayer.new()
		_debug_layer.layer = 99
		_debug_text = RichTextLabel.new()
		_debug_text.bbcode_enabled = true
		_debug_text.scroll_active = false
		_debug_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_debug_text.position = Vector2(4, 40)
		_debug_text.size = Vector2(320, 160)
		_debug_text.add_theme_font_size_override(&"normal_font_size", 8)
		_debug_layer.add_child(_debug_text)
		add_child(_debug_layer)
	_debug_layer.visible = true
	var now := Time.get_ticks_msec()
	var lines: PackedStringArray = []
	for i in range(_log.size() - 1, -1, -1):
		if lines.size() >= mix.debug_lines:
			break
		var e: Dictionary = _log[i]
		var age: float = (now - int(e.time_ms)) / 1000.0
		if age > mix.debug_line_time:
			break
		var color := "ffffff"
		if e.result == RESULT_DROPPED or e.result == RESULT_STOLEN:
			color = "ff6060"
		elif e.result == RESULT_STOPPED:
			color = "a0a0a0"
		var alpha := "%02x" % int(255.0 * clampf(1.0 - age / maxf(mix.debug_line_time, 0.01), 0.2, 1.0))
		var text := "%s  %s  %s  %s" % [(e.sound as SoundEvent).get_display_name(), e.bus,
			SoundEvent.Priority.keys()[clampi(int(e.priority), 0, 2)], e.result]
		if e.reason != &"":
			text += "  " + String(e.reason)
		lines.append("[color=#%s%s]%s[/color]" % [color, alpha, text])
	var joined := "\n".join(lines)
	if _debug_text.text != joined:
		_debug_text.text = joined
