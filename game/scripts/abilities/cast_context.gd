class_name CastContext
extends RefCounted
## Everything an ability needs to know about how it was cast.

var slot: StringName
## Recast part: 0 = the first cast, 1 = the first recast... (ABILITIES AB5).
var part: int = 0
## Aim point in world space (already clamped to range for POINT abilities).
var point: Vector2
## Normalized direction from the caster toward the aim point.
var direction: Vector2 = Vector2.RIGHT
## The clicked unit, for UNIT abilities.
var target: Unit
## A floor warning shown during the cast time (Ability.on_cast_started()).
## AbilityComponent removes it if the cast is cancelled or interrupted;
## execute() usually calls finish() on it.
var telegraph: Telegraph
