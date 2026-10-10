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


## Shakes the current camera: the 3D view's GameCamera3D (since the cleanup's
## C1), or a test's spy Camera3D, when it has a shake(). The 2D camera it
## used to fall back to went in the cleanup's C3.
## `direction` (FEEL2, sim px, ZERO = none) is passed on only to a camera
## whose shake() takes it; the camera uses it only with CameraLook's
## shake_directional on. Without one the call is today's.
func shake(amount: float, direction: Vector2 = Vector2.ZERO) -> void:
	var cam_3d := get_viewport().get_camera_3d()
	if cam_3d and cam_3d.has_method(&"shake"):
		if direction != Vector2.ZERO and cam_3d.get_method_argument_count(&"shake") >= 2:
			cam_3d.call(&"shake", amount, direction)
		else:
			cam_3d.call(&"shake", amount)


## Which way a hit pushes (sim px, normalized): from its knockback_from, else
## its source, to its target. ZERO when it has neither or they overlap.
static func get_hit_direction(ctx: HitContext) -> Vector2:
	var target := ctx.target as Node2D
	if target == null or not is_instance_valid(target):
		return Vector2.ZERO
	var from := ctx.knockback_from
	if from == Vector2.INF:
		if ctx.source == null or not is_instance_valid(ctx.source):
			return Vector2.ZERO
		from = ctx.source.global_position
	var d := target.global_position - from
	return d.normalized() if d.length() > 0.01 else Vector2.ZERO


## A hit's hitstop and shake by its tier (HitContext.feel; a kill uses the
## kill tier). Feel NONE plays nothing here: those callers keep their own.
## FEEL2: the shake carries the hit's direction (used only with CameraLook's
## shake_directional), and the hit-taken feel (HitFeel, off by default) runs
## first for any hit on the tracked player.
func play_hit_feel(ctx: HitContext) -> void:
	if ctx.blocked:
		return
	_play_hit_taken_feel(ctx)
	if ctx.feel == HitContext.Feel.NONE:
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
		shake(amount, get_hit_direction(ctx))


## True when `ctx` would play the hit-taken feel (HitFeel.hit_taken_feel_enabled
## aside): a hit on the tracked player that took health. Blocked hits (dash
## and post-hit i-frames, dead, untargetable) and deflects never get here or
## lose no health; a shield that absorbs all of it leaves health_lost 0. DoT
## ticks and on-hit extra hits don't count.
static func is_hit_taken(ctx: HitContext) -> bool:
	if ctx.blocked or ctx.deflected or ctx.health_lost <= 0.0:
		return false
	if ctx.has_tag(&"dot") or ctx.has_tag(&"proc"):
		return false
	var player := Progress.get_tracked_player()
	return player != null and ctx.target == player


## FEEL2 F3 (on in shipped config since preset 3 shipped, 2026-10-09): the
## tracked player losing health to a hit: a short hitstop and a shake pointing
## away from the attacker (HitFeel's taken_*). Off (hit_taken_feel_enabled): none.
func _play_hit_taken_feel(ctx: HitContext) -> void:
	if not hit_feel.hit_taken_feel_enabled or not is_hit_taken(ctx):
		return
	if hit_feel.taken_hitstop > 0.0:
		hitstop(hit_feel.taken_hitstop)
	if hit_feel.taken_shake > 0.0:
		shake(hit_feel.taken_shake, get_hit_direction(ctx))
