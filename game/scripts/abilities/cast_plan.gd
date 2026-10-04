class_name CastPlan
extends RefCounted
## One proposed cast (ALLIES.md, CastPlan; built in ENEMIES_AI AI1): what an
## ability's get_ai_plan() answers, for a brain to weigh and carry out.
## Abilities propose, brains decide.

var ability: Ability
## The slot it's cast from (the brain fills it in; &"" until then).
var slot: StringName = &""
## Where to aim (world px): the cast's aim point.
var point: Vector2 = Vector2.ZERO
## Caster -> aim.
var direction: Vector2 = Vector2.RIGHT
## A UNIT cast's target (and the condition target); null = none.
var target: Unit
## A VECTOR cast's line (world px; Vector2.INF = not a VECTOR plan).
var vector_start: Vector2 = Vector2.INF
var vector_direction: Vector2 = Vector2.RIGHT
## A CHARGE_UP cast's charge to release at (0–1).
var charge: float = 1.0
## The intent tags this cast serves (its passing ai_uses).
var intents: Array[StringName] = []
## How good (0–1 for the default; ALLIES' scoring helpers keep scripts comparable).
var value: float = 0.0
## Why, for the overlay and debug_draw.
var reason: String = ""


func is_vector() -> bool:
	return vector_start != Vector2.INF
