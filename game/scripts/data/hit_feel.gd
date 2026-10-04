class_name HitFeel
extends Resource
## Hit feel per tier (COMBAT.md, Numbers: "Feel per hit"). GameFeel.hit_feel
## holds the one in use (res://data/hit_feels/hit_feel_default.tres). A hit's
## tier is HitContext.feel (LIGHT / HEAVY); a kill upgrades it to the kill
## tier. Hits with feel NONE (abilities, enemy basic attacks) get no hitstop
## or shake here; their callers keep their own. (Every hit that gets through
## flashes the 3D model, UnitView; the 2D flash's flash_time and
## flash_modulate went in the 3D pivot's cleanup C3.)

@export_group("Hitstop (seconds)")
@export_range(0.0, 0.05) var light_hitstop: float = 0.03
@export_range(0.04, 0.08) var heavy_hitstop: float = 0.06
@export_range(0.05, 0.10) var kill_hitstop: float = 0.08

@export_group("Shake (px)")
@export_range(0.0, 4.0) var light_shake: float = 0.0
@export_range(0.0, 4.0) var heavy_shake: float = 2.0
@export_range(0.0, 4.0) var kill_shake: float = 3.0

@export_group("Sounds")
## The hit sound for hits without their own (AUDIO.md; CombatSounds plays
## them, once per swing or cast). LIGHT and NONE hits use the light sound.
@export var light_sound: SoundEvent
@export var heavy_sound: SoundEvent
## A kill, when the hit has no sound of its own.
@export var kill_sound: SoundEvent
## A layer on top of any crit.
@export var crit_sound: SoundEvent
## The moment a shield absorbs damage (the silver shield number).
@export var shield_absorb_sound: SoundEvent
