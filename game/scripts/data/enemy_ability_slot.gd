class_name EnemyAbilitySlot
extends Resource
## One of an enemy's abilities by slot (ENEMIES_AI.md, Data; AI1), inline in
## its EnemyData. Below its minimum difficulty tier the slot stays empty (the
## new attack patterns a tier adds; DUNGEONS.md).

## &"q", &"w", &"e" or &"r".
@export var slot: StringName = &"q"
@export var ability: Ability
## 1–5; the run's difficulty tier must be at least this (Brains.difficulty_tier
## stands in until DUNGEONS D8).
@export_range(1, 5) var min_difficulty_tier: int = 1
