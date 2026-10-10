class_name CameraLook
extends Resource
## The 3D camera's look (docs/3D.md, Data): Ryan's picks after P0b
## (2026-10-02). Read by the camera (P3's stand-in in WorldView; GameCamera3D
## from P4) and by the fade. Since the cleanup's C1 (Ryan, 2026-10-03) it also
## holds the rest of the camera's tuning, which was GameCamera's exports: the
## follow, the aim lean, the pan and the shake (MOVEMENT.md, Architecture 4).
## The lean, pan and shake are in screen px of the 640x360 canvas, so the same
## share of the screen moves the 3D camera as moved the 2D one.

enum ProjectionMode { PERSPECTIVE, ORTHOGRAPHIC }

## PERSPECTIVE: a real camera (far things a little smaller). ORTHOGRAPHIC:
## every size the same everywhere on screen.
@export var projection: ProjectionMode = ProjectionMode.PERSPECTIVE
## Perspective only: the vertical field of view, in degrees (Camera3D.fov;
## the horizontal one follows from the window's shape).
@export_range(1.0, 90.0, 0.5) var fov_deg: float = 30.0
## How steeply the camera looks down, in degrees (90 = straight down). It
## never turns: it always looks north (up the screen = -z).
@export_range(10.0, 90.0, 0.5) var pitch_deg: float = 50.0
## The floor's width across the screen at the camera's focus, in meters. The
## distance (perspective) or size (orthographic) is recomputed from the
## window's aspect, so this width holds at any window shape.
@export var visible_width_m: float = 28.0
## A `fades` asset standing between the camera and the player fades to this
## opacity (dithered: it stays solid and keeps its shadow)...
@export_range(0.0, 1.0, 0.01) var fade_to: float = 0.25
## ...over this many seconds, and back over the same time.
@export var fade_time: float = 0.18

@export_group("Follow")
## How fast the focus catches up with its goal: a Camera2D smoothing speed
## (this many shares of the way a second, taken per physics tick), on game
## time, so hitstop freezes it (GameCamera3D.follow_rate_per_second(): 10 at
## 60 Hz is 10.94 a second). 0 = no smoothing.
@export var follow_smoothing_speed: float = 10.0

@export_group("Aim lean")
## How far (screen px) the locked camera leans toward the mouse at most.
## 0 = off. (GameCamera's `aim_lead`.)
@export var aim_lead_px: float = 80.0
## No lean while the cursor is inside this share of the half-screen,
## measured as an oval (x and y each divided by their own half-size).
@export var aim_lead_dead_zone: float = 0.35
## Share of the half-screen where the lean reaches full.
@export var aim_lead_full_at: float = 0.9
## Lean between the dead zone edge (x = 0) and aim_lead_full_at (x = 1).
## null = linear.
@export var aim_lead_curve: Curve = preload("res://data/curves/curve_camera_lead.tres")
## Vertical lean = aim_lead_px x this (the screen is 16:9).
@export var aim_lead_y_scale: float = 0.6
## How fast the lean eases toward its target, per second (frame-rate
## independent, real time). The follow keeps its own smoothing.
@export var aim_lead_smoothing: float = 4.0
## Lean scale while the player isn't aiming or casting.
@export var aim_lead_idle_scale: float = 0.5
## Keep the full lean this many seconds after the last aim or cast, so it
## doesn't swing back and forth between casts.
@export var aim_lead_hold_time: float = 0.75
## Extra lean (screen px) in the walking direction. 0 = off. Try 12-16.
@export var move_lead_px: float = 0.0

@export_group("Pan")
## Unlocked: how fast the arrows and the screen's edges pan (screen px a
## second, real time, so hitstop doesn't freeze it). (GameCamera's
## `edge_pan_speed`.)
@export var edge_pan_speed_px: float = 420.0
## Distance from the window's edge (screen px) that starts edge panning.
## (GameCamera's `edge_margin`.)
@export var edge_margin_px: float = 6.0

@export_group("Shake")
## GameFeel.shake()'s size (screen px) drops this much a second, real time.
## (GameCamera's `shake_decay`.) camera_look_default.tres: 16 since FEEL2
## shipped preset 3 (Ryan, 2026-10-09; 30 before).
@export var shake_decay_px: float = 30.0
## FEEL2 F1: the shake holds while a hitstop runs (no offset, no decay) and
## starts when it ends. On in camera_look_default.tres since preset 3
## shipped. Off: it decays during the freeze (a heavy hit's 2 px is 0.2 px
## when its 0.06 s hitstop ends).
@export var shake_after_hitstop: bool = false
## FEEL2 F1: a shake given a direction (GameFeel.shake(amount, direction):
## basic attack hits, kills, the hit-taken feel) leans along it: its mean
## offset points that way. On in camera_look_default.tres since preset 3
## shipped. Off: random in every direction.
@export var shake_directional: bool = false

@export_group("Debug")
## Draws on the screen: the lean's dead zone (white oval), the target lean
## (yellow) and the current lean (green), from the player.
@export var debug_draw: bool = false


## The camera's distance from its focus, in meters, for a viewport of this
## aspect (width / height). The orthographic camera sits at the same spot.
func get_distance_m(aspect: float) -> float:
	return visible_width_m / (2.0 * tan(deg_to_rad(fov_deg) * 0.5) * aspect)


## Where the camera sits, relative to its focus (south of it and above).
func get_offset_m(aspect: float) -> Vector3:
	var pitch := deg_to_rad(pitch_deg)
	return Vector3(0.0, sin(pitch), cos(pitch)) * get_distance_m(aspect)


## Sets `camera`'s projection, field of view or size, and transform, looking
## at `focus` (m) through a viewport of this aspect.
func apply(camera: Camera3D, focus: Vector3, aspect: float) -> void:
	if projection == ProjectionMode.ORTHOGRAPHIC:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = visible_width_m / aspect   # keep_aspect KEEP_HEIGHT: size is the height
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = fov_deg
	camera.global_transform = Transform3D(Basis.from_euler(Vector3(-deg_to_rad(pitch_deg), 0.0, 0.0)),
		focus + get_offset_m(aspect))
