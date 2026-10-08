class_name RankRules
extends Resource
## One rank's rules (ENEMIES_AI.md, Scaling and RankRules; AI1), inline in the
## EnemyAITable: whether it has a brain, dodges, what an attack token costs it,
## its tenacity (Ryan, I8), how many abilities it may have, and its slider
## adjust.

@export var rank: EnemyData.Rank = EnemyData.Rank.REGULAR
## Fodder has none: it keeps enemy.gd's own routine.
@export var has_brain: bool = true
## Elites and bosses sidestep dodgeable attacks (AI4).
@export var can_dodge: bool = false
## Attack tokens a commit takes (regular 1, elite 2; 0 = none: fodder swarms,
## a boss has its director). AI2.
@export var token_cost: int = 1
## A FLAT `tenacity` modifier given at spawn under &"enemy_rank" (elite 0.2,
## boss 0.4: 20% and 40% shorter crowd control; Ryan, I8). 0 = none.
@export_range(0.0, 1.0) var tenacity: float = 0.0
## The most abilities an enemy of this rank may have (−1 = any). The enemies
## test checks every EnemyData. Since AI3d (Ryan, 2026-10-04: Kits): fodder
## 0, regular 3, elite 5, boss 6 (AI1's were 0, 2, 3, any).
@export var max_abilities: int = 2
## The fewest it should have (AI3d: fodder 0, regular 2, elite 3, boss 4);
## the enemies test warns about an EnemyData below it.
@export var min_abilities: int = 0
## Its slider multipliers (a regular: reaction × 1.3, jitter × 1.5, punish
## greed × 0.5; a boss: reaction × 0.85, jitter × 0.7). null = none.
@export var brain_adjust: BrainAdjust
## Thinks a second for its brains (AI3c; Ryan, 2026-10-04: fodder none,
## regular 10, elite 15, boss 25; a duelist elite takes the boss's). −1 = the
## table's think_rate. Brains scales every rate down evenly past the table's
## think_budget.
@export var think_rate: float = -1.0
## Its brains always think at their full rate, whatever the budget (Ryan,
## 2026-10-05: elites, of any role, and bosses). Their thinks still count:
## they come off the budget first, and the other ranks share what's left.
@export var think_budget_exempt: bool = false
## Diminishing returns on crowd control (AI-D3; Ryan, 2026-10-05), given to
## the enemy's StatusComponent at spawn. Fodder false: it takes every crowd
## control in full.
@export var cc_diminishing: bool = true
## The poise hook (ENEMIES_AI.md, Enemies being combo'd): refuses crowd
## control with the reason &"poise". Off for every rank until poise is built
## (bosses, later).
@export var poise: bool = false
