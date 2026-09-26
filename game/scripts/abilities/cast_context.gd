class_name CastContext
extends RefCounted
## Everything an ability needs to know about how it was cast.

var slot: StringName
## Aim point in world space (already clamped to range for POINT abilities).
var point: Vector2
## Normalized direction from the caster toward the aim point.
var direction: Vector2 = Vector2.RIGHT
## The clicked unit, for UNIT abilities.
var target: Unit
