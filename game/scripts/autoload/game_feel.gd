extends Node
## Global "juice" helpers: hit-stop and screen shake.
## Autoloaded as GameFeel, so any script can call GameFeel.shake(3.0).

var _hitstop_active := false


## Freezes the game for a split second to make hits feel heavy.
func hitstop(duration: float = 0.05) -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false


func shake(amount: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(amount)
