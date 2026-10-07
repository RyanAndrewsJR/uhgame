class_name ComboPlan
extends Resource
## A combo plan (ENEMIES_AI.md, Combo plans; AI-D2): ordered steps plus when
## it fits, inline in EnemyData.combo_plans (later ChampionData's, AI-D4). The
## brain picks one at a commit (ComboPlanner.pick_plan()) and runs its steps
## inside that commit; when it ends, the follow-through decides whether it
## stays on its target or resets.
## A plan whose first step's ability has no `opener` combo role opens blind:
## it fits only when the blind read passes (Ryan, 2026-10-07: its target low,
## its escapes or its ultimate down, or held by a crowd control).

@export var id: StringName = &""
@export var steps: Array[ComboStep] = []
## All must pass when it starts (read like use rules, with the situation).
@export var conditions: Array[Condition] = []
## Its weight among the plans that fit (× its opener's plan value).
@export var weight: float = 1.0
## Harder plans at higher difficulty tiers (Scaling).
@export var min_difficulty_tier: int = 1


## Its first step's slot (&"" = no steps).
func get_opener_slot() -> StringName:
	return steps[0].slot if not steps.is_empty() and steps[0] != null else &""
