class_name SoundEvent
extends Resource
## One sound (AUDIO.md, Data): its files, jitter, bus, position rules and
## limits. Files live in res://data/sounds/sound_<category>_<name>.tres.
## Sounds only ever play through the Audio autoload; a null SoundEvent field
## anywhere is silent.
##
## The variations are wrapped in Godot's AudioStreamRandomizer (no-repeat
## mode, pitch and volume jitter), built once and rebuilt only when the
## variations or the jitter change.

## The mix bus the sound plays on (an enum, so a typo can't pick a missing bus).
enum Bus { SFX, UI, MUSIC, AMBIENCE, VOICE }
## Who wins when the SFX voice cap is full. CombatSounds overrides it for
## hits and statuses (the player involved = HIGH).
enum Priority { LOW, NORMAL, HIGH }

const BUS_NAMES := {
	Bus.SFX: &"SFX",
	Bus.UI: &"UI",
	Bus.MUSIC: &"Music",
	Bus.AMBIENCE: &"Ambience",
	Bus.VOICE: &"Voice",
}

## One or more files; one of them plays at random, never the same one twice
## in a row when there are 2+. Empty (or every entry null) = no usable audio:
## Audio warns once and stays silent.
@export var variations: Array[AudioStream] = []
@export var volume_db: float = 0.0
## Base pitch, multiplied by the caller's pitch (e.g. the combo pitch).
@export var pitch_scale: float = 1.0
## ±share of random pitch: 0.05 = a pitch between 1 / 1.05 and 1.05.
@export_range(0.0, 0.1) var pitch_jitter: float = 0.05
## ±dB of random volume.
@export_range(0.0, 3.0) var volume_jitter_db: float = 1.0
@export var bus: Bus = Bus.SFX
## false = always centered (UI, stingers, music). true = positional, except
## the player's own sounds, which are always centered (AUDIO.md, Rules).
@export var positional: bool = true
## Positional only: silent beyond this distance from the listener (linear
## falloff). Telegraph sounds use 640.
@export var max_distance_px: float = 480.0
@export var priority: Priority = Priority.NORMAL
## At most this many copies start within any min_interval window.
@export_range(1, 6) var max_instances: int = 3
## Seconds, real time: the sliding window for max_instances.
@export_range(0.03, 0.1) var min_interval: float = 0.05
## Plays until stopped (a kept handle or Audio.play_on()). The file must
## also be imported with looping on; this flag doesn't make a file loop.
@export var loop: bool = false

var _stream: AudioStreamRandomizer
var _stream_key: Array = []


## The stream Audio plays: the cached randomizer, or null without usable audio.
func get_stream() -> AudioStream:
	var key := [variations.hash(), pitch_jitter, volume_jitter_db]
	if key != _stream_key:
		_stream_key = key
		_stream = _build_stream()
	return _stream


func has_audio() -> bool:
	return get_stream() != null


func get_bus_name() -> StringName:
	return BUS_NAMES[bus]


## A short name for logs and the debug list: the file name, or resource_name
## for a SoundEvent that was never saved (tests).
func get_display_name() -> String:
	if not resource_path.is_empty():
		return resource_path.get_file().get_basename()
	return resource_name if not resource_name.is_empty() else "<unnamed sound>"


func _build_stream() -> AudioStreamRandomizer:
	var usable: Array[AudioStream] = []
	for s in variations:
		if s != null:
			usable.append(s)
	if usable.is_empty():
		return null
	var r := AudioStreamRandomizer.new()
	r.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	r.random_pitch = 1.0 + pitch_jitter
	r.random_volume_offset_db = volume_jitter_db
	for s in usable:
		r.add_stream(-1, s)
	return r
