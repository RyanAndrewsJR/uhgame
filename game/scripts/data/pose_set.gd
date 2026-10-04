class_name PoseSet
extends Resource
## An enemy's tells (ENEMIES_AI.md, Tells; Ryan, I7): pose name -> PoseLook.
## Files res://data/pose_sets/pose_set_<name>.tres; pose_set_default.tres
## gives every pose of the minimum set its capsule look. The brain picks the
## pose (sim); the view shows it (UnitView). View data.

@export var poses: Dictionary[StringName, PoseLook] = {}


## The look of `pose`, or null (no pose, or one this set doesn't have).
func get_look(pose: StringName) -> PoseLook:
	if pose == &"":
		return null
	return poses.get(pose)
