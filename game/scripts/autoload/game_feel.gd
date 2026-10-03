extends Node
## Global "juice" helpers: hit-stop and screen shake.
## Autoloaded as GameFeel, so any script can call GameFeel.shake(3.0).
##
## Hitstop: overlapping hitstops don't stack; the longest wins (a later call
## that ends later extends the running one, a shorter one changes nothing).
## play_hit_feel(ctx) plays a hit's tier from hit_feel (COMBAT.md).

## Feel per hit tier: hitstop, shake and the flash.
@export var hit_feel: HitFeel = preload("res://data/hit_feels/hit_feel_default.tres")
## Engine.time_scale during a hitstop (a near-freeze).
@export var hitstop_time_scale: float = 0.05

var _hitstop_active := false
var _hitstop_until_ms: int = 0   # real time (Time.get_ticks_msec())


## Freezes the game for a split second to make hits feel heavy. If a hitstop
## is already running, this one only extends it when it would end later.
func hitstop(duration: float = 0.05) -> void:
	var until := Time.get_ticks_msec() + int(roundf(duration * 1000.0))
	if until <= _hitstop_until_ms:
		return
	_hitstop_until_ms = until
	if _hitstop_active:
		return  # The running hitstop picks up the later end time.
	_hitstop_active = true
	Engine.time_scale = hitstop_time_scale
	while Time.get_ticks_msec() < _hitstop_until_ms:
		var left := (_hitstop_until_ms - Time.get_ticks_msec()) / 1000.0
		await get_tree().create_timer(left, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false


func is_hitstop_active() -> bool:
	return _hitstop_active


## Real seconds until the running hitstop ends (0 when none).
func get_hitstop_left() -> float:
	if not _hitstop_active:
		return 0.0
	return maxf(_hitstop_until_ms - Time.get_ticks_msec(), 0) / 1000.0


## Shakes the current camera: the 3D view's GameCamera3D when it shows the
## game (the cleanup's C1), else a current Camera2D with a shake() (the 2D
## game, and the tests' spy cameras).
func shake(amount: float) -> void:
	var cam_3d := get_viewport().get_camera_3d()
	if cam_3d and cam_3d.has_method(&"shake"):
		cam_3d.call(&"shake", amount)
		return
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(amount)


## A hit's hitstop and shake by its tier (HitContext.feel; a kill uses the
## kill tier). Feel NONE plays nothing here: those callers keep their own.
func play_hit_feel(ctx: HitContext) -> void:
	if ctx.blocked or ctx.feel == HitContext.Feel.NONE:
		return
	var stop := hit_feel.light_hitstop
	var amount := hit_feel.light_shake
	if ctx.killed:
		stop = hit_feel.kill_hitstop
		amount = hit_feel.kill_shake
	elif ctx.feel == HitContext.Feel.HEAVY:
		stop = hit_feel.heavy_hitstop
		amount = hit_feel.heavy_shake
	if stop > 0.0:
		hitstop(stop)
	if amount > 0.0:
		shake(amount)
