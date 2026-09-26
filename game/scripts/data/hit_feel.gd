class_name HitFeel
extends Resource
## Hit feel per tier (COMBAT.md, Numbers: "Feel per hit"). GameFeel.hit_feel
## holds the one in use (res://data/hit_feels/hit_feel_default.tres). A hit's
## tier is HitContext.feel (LIGHT / HEAVY); a kill upgrades it to the kill
## tier. Hits with feel NONE (abilities, enemy basic attacks) get only the
## flash; their callers keep their own hitstop and shake.

@export_group("Hitstop (seconds)")
@export_range(0.0, 0.05) var light_hitstop: float = 0.03
@export_range(0.04, 0.08) var heavy_hitstop: float = 0.06
@export_range(0.05, 0.10) var kill_hitstop: float = 0.08

@export_group("Shake (px)")
@export_range(0.0, 4.0) var light_shake: float = 0.0
@export_range(0.0, 4.0) var heavy_shake: float = 2.0
@export_range(0.0, 4.0) var kill_shake: float = 3.0

@export_group("Flash")
## Every hit that gets through flashes the target's body (all tiers,
## including NONE).
@export var flash_time: float = 0.06
## Body modulate at the start of the flash (above 1 = brighter than the art,
## reads as white on the placeholder polygons).
@export var flash_modulate: Color = Color(3, 3, 3, 1)
