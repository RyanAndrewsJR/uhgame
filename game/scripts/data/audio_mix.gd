class_name AudioMix
extends Resource
## The mix-wide numbers (AUDIO.md, Data), like HitFeel for GameFeel.
## Audio.mix holds the one in use (res://data/audio_mixes/audio_mix_default.tres).
## The bus levels themselves live in res://default_bus_layout.tres; the
## player's volume sliders live in Settings.

## At most this many sounds play on the SFX bus at once. A new sound that
## outranks the lowest-priority one stops it; otherwise it's dropped.
@export_range(16, 64) var voice_cap: int = 32

@export_group("Pause")
## Music's volume change while the game is paused (dB).
@export_range(-12.0, 0.0) var pause_music_duck_db: float = -6.0
## Turn on the Music bus's low-pass filter while paused.
@export var pause_low_pass: bool = true
## The low-pass cutoff while paused (Hz).
@export var pause_low_pass_hz: float = 1200.0
## Seconds (real time) for the duck to fade in or out.
@export var duck_fade_time: float = 0.15

@export_group("Log and debug")
## How many entries Audio.get_log() keeps.
@export var log_size: int = 256
## Lines in the on-screen list (Audio.debug_draw).
@export var debug_lines: int = 10
## Seconds a line stays in the on-screen list.
@export var debug_line_time: float = 3.0
