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
## The most abilities an enemy of this rank may have (fodder 0, regular 2,
## elite 3; −1 = any). The enemies test checks every EnemyData.
@export var max_abilities: int = 2
## Its slider multipliers (a regular: reaction × 1.3, jitter × 1.5, punish
## greed × 0.5; a boss: reaction × 0.85, jitter × 0.7). null = none.
@export var brain_adjust: BrainAdjust
