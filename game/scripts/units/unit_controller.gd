class_name UnitController
extends Node
## What drives a Unit (ALLIES.md, UnitController; built in ENEMIES_AI AI1,
## where the enemy brain is the first controller other than the human's): a
## Node child of the Unit. It drives the unit only through the unit's existing
## commands (AbilityComponent's casts, AutoAttackComponent's attack and swing,
## MovementComponent's move_to() and input direction, the dash), never by
## reaching into them. EnemyBrain is the first subclass; ScriptedController
## (tests) the second; ALLIES AL1 makes PlayerInput one and adds AllyBrain.


## The unit this controller drives (its parent).
func get_unit() -> Unit:
	return get_parent() as Unit


## Where it aims (world px). Vector2.INF = no aim of its own.
func get_aim_point() -> Vector2:
	return Vector2.INF


## The direction it walks by itself (length 0–1); zero when it walks by
## move_to() orders or stands.
func get_move_direction() -> Vector2:
	return Vector2.ZERO


## True only for the human's controller (PlayerInput, from ALLIES AL1).
func is_human() -> bool:
	return false
