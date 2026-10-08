class_name CrowdControlRules
extends Resource
## Diminishing returns on crowd control (COMBAT.md, Status effects; ENEMIES_AI
## AI-D3; Ryan, 2026-10-05: every unit, the numbers as proposed, TARGET). A
## second crowd control on the same unit within dr_window of the first lasts
## dr_factor as long; a third is refused, and the unit is immune for
## dr_immune_time; then the count starts over. StatusComponent reads it
## (cc_rules; null = crowd_control_rules_default.tres).

## How long after the first crowd control a second one is halved (s).
@export_range(0.0, 30.0, 0.1) var dr_window: float = 4.0
## What the second one's duration is multiplied by (after tenacity).
@export_range(0.0, 1.0, 0.05) var dr_factor: float = 0.5
## How long a unit stays immune after its third is refused (s).
@export_range(0.0, 30.0, 0.1) var dr_immune_time: float = 3.0
## The immunity: a status tagged `cc_immune` (a ring at the unit's feet).
@export var immune_status: StatusEffect
