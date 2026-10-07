class_name ComboStep
extends Resource
## One step of a ComboPlan (ENEMIES_AI.md, Combo plans; AI-D2): an ability by
## slot, when it starts after the step before it, and how long it may wait.
## Inline in its plan (the EnemyData's .tres). The first step is the opener:
## its timing is the commit's (its tell, then its cast).

## When the step starts after the previous step:
enum Timing {
	AFTER_LANDED,   ## as the previous step's hit lands on the target
	AFTER_ENDED,    ## as the previous cast ends, landed or not
	AFTER_DELAY,    ## `delay` s after the previous cast ends
	ON_STATUS,      ## when the target carries a status tagged `status_tag` (`root`)
}

## Its ability's slot in the enemy's kit (&"q", &"w", &"e", &"r").
@export var slot: StringName = &"q"
@export var timing: Timing = Timing.AFTER_LANDED
## AFTER_DELAY: seconds after the previous cast ends.
@export var delay: float = 0.0
## ON_STATUS: the tag the target's status must carry.
@export var status_tag: StringName = &""
## It must start within this long of its trigger, else the plan ends (or, when
## optional, it's skipped).
@export var window: float = 1.0
## Skipped (not ending the plan) when its ability can't be cast, has no plan,
## or would waste its crowd control.
@export var optional: bool = false
