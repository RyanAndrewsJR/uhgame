class_name CameraLook
extends Resource
## The 3D camera's look (docs/3D.md, Data): Ryan's picks after P0b
## (2026-10-02). Read by the camera (P3's stand-in in WorldView; GameCamera3D
## from P4) and by the fade. Everything else the camera does (lean, lock,
## edge pan, shake) keeps GameCamera's exports.

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
