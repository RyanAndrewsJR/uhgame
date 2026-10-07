class_name BrainDecision
extends RefCounted
## What EnemyBrain.decide() chose at one think (ENEMIES_AI.md, BrainDecision;
## AI1): the intent, the cast to make (if any), the pose, and why (the scores
## the overlay shows).

## The chosen intent (&"" = none: no target).
var intent: StringName = &""
## The cast to make now; null = none.
var plan: CastPlan
## Where to move (world px); Vector2.INF = the intent's own movement.
var move_to: Vector2 = Vector2.INF
## The pose it shows (its tell; &"" = none).
var pose: StringName = &""
## Intent -> final score (after the weights, the jitter and the hold bonus).
var scores: Dictionary = {}
var reason: String = ""
## AI-D1: a new commit that is a setup (it opens with its best opener; the
## brain keeps that until the opener is cast).
var setup: bool = false


## The top `count` scores, best first: [[intent, score], ...].
func get_top_scores(count: int = 3) -> Array:
	var pairs: Array = []
	for k: StringName in scores:
		pairs.append([k, float(scores[k])])
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	return pairs.slice(0, count)
