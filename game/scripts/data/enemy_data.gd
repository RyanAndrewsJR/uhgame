class_name EnemyData
extends Resource
## One kind of enemy (ENEMIES_AI.md, Data; Ryan, I9): DUNGEONS' "a shared
## behavior plus its own data". Enemy.data points at it and
## Enemy._apply_enemy_data() loads it when the enemy is ready, the way
## Player._apply_champion() loads a ChampionData. An enemy with no data plays
## exactly as before (its scene's own exports, the naive cast loop).
## Files: res://data/enemies/enemy_<name>.tres.
## Built in AI1: the fields below. Still to come with their steps: boss_plan
## (AI6); xp, kill_tags, drop_table, kindling and the companion drop chance
## (AI7); attack_tags (with Claude's proposal 9, the `melee` tag, once Ryan
## answers it).

## The ladder (ENEMIES_AI.md, Roles and ranks): fodder has no brain, regulars
## some, elites the full one, bosses the most (a director on top, AI6).
enum Rank { FODDER, REGULAR, ELITE, BOSS }

## &"crypt_thrall"; its twist's source id is &"enemy_<id>".
@export var id: StringName = &""
@export var display_name: String = ""
@export var rank: Rank = Rank.REGULAR
## Its role preset (the archetype .tres); null for fodder (the fodder routine).
@export var behavior: EnemyBehavior
## A slider's value in place of the preset's (EnemyBehavior.SLIDERS names;
## the band's ends are range_band_min and range_band_max). At most 3: kind,
## not magnitude (the enemies test warns past that).
@export var overrides: Dictionary[StringName, float] = {}
## Its base stats (replaces the scene's UnitStats).
@export var stats: UnitStats
## Its abilities by slot; the scene needs an AbilityComponent for them.
@export var abilities: Array[EnemyAbilitySlot] = []
## What makes it this enemy (stat modifiers, unit reaction rules, statuses),
## applied under &"enemy_<id>"; TALENTS' shared bundle. null = none.
@export var twist: ToolkitBundle
## Its look: a model, or (null) a capsule in model_color.
@export var model_scene: PackedScene
@export var model_color: Color = Color(0.75, 0.3, 0.3)
## Its tells; null = its behavior's set, else pose_set_default.tres.
@export var pose_set: PoseSet
## Aggro range, LoL units edge to edge.
@export var detect_range: float = 450.0
## A duelist (ENEMIES_AI.md, Kits; AI3c; Ryan, 2026-10-04): rank ELITE in
## everything, but it thinks at the boss's rate. Read only at rank ELITE.
@export var duelist: bool = false
## Its combo plans (ENEMIES_AI.md, Combo plans; AI-D2): it sets up and runs
## plans only with some. Each names its steps' abilities by slot.
@export var combo_plans: Array[ComboPlan] = []
## Its poise meter's size (PoiseComponent.setup(), at spawn). ARCHETYPES AR3a
## (2026-10-08): −1 (the default) = its rank's (RankRules.poise_meter_max)
## when its archetype has a meter (Archetype.poise_meter: the Assassin), else
## none; 0 = none; above 0 = that size. PROTOTYPE (poise, 2026-10-07): the
## elite slime's and the test duelist's 100, a meter their archetype (Bruiser)
## doesn't have, which runs only while PoiseComponent.poise_test_enabled is on
## (AR6 sets them to 0).
@export var poise_max: float = -1.0
## ARCHETYPES AR1a: its string (D6): the chain of basic attack swings a commit
## with no combo plan runs (and a plan's STRING step), at its archetype's
## rhythm (AttackCombo: its swings' timings, string_hits_min). null = no
## string: fodder, and an enemy not yet given one keeps AI1's commit.
@export var attack_string: AttackCombo


## The source id its twist goes under.
func get_source_id() -> StringName:
	return StringName("enemy_" + String(id))


## Its archetype's id (ARCHETYPES AR3a; Archetype.of()): &"basic" for fodder
## or without a behavior, else its behavior's (EnemyBehavior.get_archetype_id()).
func get_archetype_id() -> StringName:
	if rank == Rank.FODDER or behavior == null:
		return &"basic"
	return behavior.get_archetype_id()


## Its combo plans that exist at `difficulty_tier` (AI-D2).
func get_plans_at(difficulty_tier: int) -> Array[ComboPlan]:
	var out: Array[ComboPlan] = []
	for plan in combo_plans:
		if plan != null and not plan.steps.is_empty() and difficulty_tier >= plan.min_difficulty_tier:
			out.append(plan)
	return out


## Its abilities that exist at `difficulty_tier` (slot -> Ability).
func get_abilities_at(difficulty_tier: int) -> Dictionary:
	var out := {}
	for entry in abilities:
		if entry != null and entry.ability != null and difficulty_tier >= entry.min_difficulty_tier:
			out[entry.slot] = entry.ability
	return out
