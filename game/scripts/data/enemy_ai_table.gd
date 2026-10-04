class_name EnemyAITable
extends Resource
## The enemy AI's global rules (ENEMIES_AI.md, EnemyAITable; AI1), held by
## Brains.table (the pattern of LootTable): the ranks, the think rate, the
## respect and patience numbers, the tell, the hold's movement and the
## scores. res://data/enemy_ai_tables/enemy_ai_table_default.tres.
## Every number is a TARGET until the play tests. The groups' numbers (tokens,
## alert, leash), the target pick's, dodging's and the whiff's come with their
## steps (AI2, AI4, AI6).

## The four ranks (fodder, regular, elite, boss), each a RankRules.
@export var ranks: Array[RankRules] = []

@export_group("Thinking")
## Thinks a second per brain, staggered over the physics ticks.
@export var think_rate: float = 10.0
## An intent holds at least this long (s) unless something urgent breaks it:
## until then it scores intent_hold_bonus more (no flip-flopping).
@export var min_intent_time: float = 0.4
@export var intent_hold_bonus: float = 0.15
## A decision that starts an attack (commit; later punish, finish) holds its
## pose this long (s) before the move (Ryan, I7). On top of the ability's
## own telegraph.
@export var tell_time: float = 0.3
## No reaction is ever faster than this (s), whatever the rank, faction or
## difficulty tier (Ryan, I4).
@export var reaction_floor: float = 0.2
## Each intent's base score (0–1) when the situation allows it, before the
## behavior's intent weights and the jitter (ENEMIES_AI.md, Scoring).
@export var intent_scores: Dictionary[StringName, float] = {
	&"hold": 0.3, &"poke": 0.5, &"commit": 0.65,
}
## A caster's poke scores this instead (it pokes the whole time).
@export var caster_poke_score: float = 0.6

@export_group("Respect")
## An ability's derived respect value by its role tag (Ryan, I2).
@export var respect_by_role: Dictionary[StringName, float] = {
	&"ultimate": 4.0, &"core": 2.0, &"mobility": 2.0, &"defensive": 1.5,
	&"generator": 1.0, &"companion": 0.0,
}
## Added when its data applies a crowd control status (a stun, a slow).
@export var respect_cc_bonus: float = 1.0
## The other champion's ready kit counts this much while it's up and within
## ally_respect_range_px of the enemy (Ryan, I2: half, within 10 m).
@export var ally_respect_weight: float = 0.5
@export var ally_respect_range_px: float = 320.0

@export_group("Patience")
## Patience fills each second by (1 − patience_respect_cut × effective
## respect) ÷ patience_time × (0.5 + aggression) × pressure: with everything
## up it still fills at a quarter of its speed (the floor).
@export_range(0.0, 1.0) var patience_respect_cut: float = 0.75
## Pressure: + idle_pressure while the target has done nothing (no move,
## swing, dash or cast) for idle_time s; + low_pressure while it's below
## low_health of its health.
@export var idle_time: float = 1.5
@export var idle_pressure: float = 0.5
@export_range(0.0, 1.0) var low_health: float = 0.4
@export var low_pressure: float = 0.5

@export_group("Commit")
## A commit ends after this many landed basic attacks, after its first cast,
## or after commit_max_time s; patience empties then.
@export var commit_hits: int = 2
@export var commit_max_time: float = 4.0
## After its own commit a melee enemy walks back out to its band for up to
## this long (s); otherwise, when its target comes inside its band, it holds
## its ground and swings back once the target is in its reach.
@export var back_off_time: float = 2.0

@export_group("Holding")
## The hold's path is re-planned at most this often (s).
@export var hold_replan_time: float = 0.25
## How far along the circle around its target each re-plan aims (px).
@export var strafe_step_px: float = 40.0
## It turns its strafe around after this long (s; random between, jittered).
@export var strafe_turn_min: float = 2.0
@export var strafe_turn_max: float = 4.0

## Derived respect values, cached per ability (they read only data).
var _respect_cache: Dictionary = {}


## The rules of `rank`, or null.
func get_rank_rules(rank: EnemyData.Rank) -> RankRules:
	for r in ranks:
		if r != null and r.rank == rank:
			return r
	return null


## Base score of `intent` (0 when the table has none).
func get_intent_score(intent: StringName) -> float:
	return intent_scores.get(intent, 0.0)


## An ability's respect value (ENEMIES_AI.md, Respect; Ryan, I2): its
## authored `respect_value`, or (−1) the derived one: its role tag's value,
## plus respect_cc_bonus when its data applies a crowd control status. Only
## data the HUD shows matters, never damage numbers.
func get_respect_value(ability: Ability) -> float:
	if ability == null:
		return 0.0
	if ability.respect_value >= 0.0:
		return ability.respect_value
	if _respect_cache.has(ability):
		return _respect_cache[ability]
	# A companion's command has the planned `companion` tag as its role
	# (COMPANIONS.md), not yet one of Ability.ROLE_TAGS.
	var role := &"companion" if ability.tags.has(&"companion") else ability.get_role()
	var value: float = respect_by_role.get(role, 0.0)
	if value > 0.0 and applies_cc(ability):
		value += respect_cc_bonus
	_respect_cache[ability] = value
	return value


## True when the ability's data applies a status tagged `cc`: a StatusEffect
## (or a list of them) among its exports or its conditional bonuses' target
## statuses, or a `stun_duration` param above 0 (a stun its script applies).
static func applies_cc(ability: Ability) -> bool:
	if ability.has_param(&"stun_duration") and ability.get_base_param(&"stun_duration") > 0.0:
		return true
	for p in ability.get_property_list():
		if not (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		if _is_cc(ability.get(p.name)):
			return true
	for bonus in ability.conditional_bonuses:
		if bonus != null and _is_cc(bonus.target_statuses):
			return true
	return false


static func _is_cc(value: Variant) -> bool:
	if value is StatusEffect:
		return (value as StatusEffect).tags.has(&"cc")
	if value is Array:
		for v: Variant in value:
			if v is StatusEffect and (v as StatusEffect).tags.has(&"cc"):
				return true
	return false
