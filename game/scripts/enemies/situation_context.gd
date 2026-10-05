class_name SituationContext
extends RefCounted
## What one enemy brain sees at one think (ENEMIES_AI.md, SituationContext;
## AI1): pure data, filled by EnemyBrain.build_situation() or by hand in a
## test, read by the pure EnemyBrain.decide(). CONVENTIONS' context-object
## pattern: new fields are added here, never as new arguments.
## The live nodes (self_unit, target_unit) ride along for the act step and
## for the use rules and plans gathered while building it; decide() never
## reads them.
## Built in AI1: self, the target, respect, patience, the commit and the
## castable uses. AI2 added the tokens, the taunt, reachability and home.
## AI3 added the incoming attacks and the cornered, escaping and resetting
## states. Later steps add dodging (AI4) and the punish window (AI6).

# --- Self ---------------------------------------------------------------------
var rank: EnemyData.Rank = EnemyData.Rank.REGULAR
var role: EnemyBehavior.Role = EnemyBehavior.Role.BRUTE
var position: Vector2 = Vector2.ZERO
var health_ratio: float = 1.0
## Its basic attack's reach (px, edge to edge).
var attack_reach_px: float = 0.0
## A cast (or charge-up) is running.
var casting: bool = false
## Stunned or rooted: it can't move itself.
var move_blocked: bool = false
## Stunned or silenced: it can't cast.
var cast_blocked: bool = false
## 0–1 (The standoff); the brain fills it before deciding.
var patience: float = 0.0
## Its current intent and how long it has held it (s).
var intent: StringName = &""
var intent_age: float = 0.0
## A commit is under way and not yet done (its tell included).
var committing: bool = false
## The table's no-flip-flop numbers (EnemyAITable): copied in, so decide()
## reads nothing but this, the behavior and the generator.
var min_intent_time: float = 0.4
var intent_hold_bonus: float = 0.15
## Each intent's base score (EnemyAITable.intent_scores) and the caster's poke.
var intent_scores: Dictionary = {}
var caster_poke_score: float = 0.6

# --- Target -------------------------------------------------------------------
var has_target: bool = false
var target_position: Vector2 = Vector2.ZERO
## Edge to edge (px).
var target_edge_distance_px: float = INF
var target_health_ratio: float = 1.0
## Its ready kit's share of its whole kit (0–1; Respect).
var target_kit_ready: float = 0.0
## It can get to the target: a path gets it within its reach (AI2;
## Enemy.is_target_reachable()). Out of reach it never commits.
var target_reachable: bool = true
## Its target taunts it (ALLIES.md): it commits without patience or a token.
var taunted: bool = false
var target_in_sight: bool = false
## Seconds since the target last moved, swung, dashed or cast.
var target_idle_time: float = 0.0

# --- The party ----------------------------------------------------------------
## The party's respect (0–1): the target's share plus the other champion's
## at ally_respect_weight while it's up and close (Respect). Use rules read
## this one (Condition RESPECT).
var respect: float = 0.0
## respect × this enemy's respect_weight slider, clamped 0–1: what its
## patience and choices use.
var effective_respect: float = 0.0
## Champions in the snapshot.
var party_size: int = 0

# --- Tokens and home (AI2) ----------------------------------------------------
## Its rank and role take attack tokens to commit (Groups); false = it needs
## none (a hand-built situation's default).
var needs_token: bool = false
## It holds its tokens on its target (a commit may start).
var has_token: bool = false
## It asked and waits its turn in the queue.
var waiting_for_token: bool = false
## Tokens free in its target's pool.
var tokens_free: int = 0
## Its pack's home and its distance to it (px).
var home_position: Vector2 = Vector2.ZERO
var home_distance_px: float = 0.0

# --- Incoming attacks and its own states (AI3) ----------------------------------
## The attacks it sees coming at it, each perceived once its reaction time
## has passed since it first saw it (ENEMIES_AI.md, Knowledge):
## {source: Unit, ability: Ability, kind: &"cast" / &"charge_up" /
## &"projectile", area: Dictionary (Ability.get_effect_area()), time_to_hit
## (s), age (s since first seen), dodgeable (false until AI4)}.
var incoming: Array[Dictionary] = []
## Cornered (a caster caught with no way out): it squares up and fights, and
## doesn't run again until it's over (Cornered casters).
var cornered: bool = false
## Walking away from its target on foot (an escape with no escape ability).
var escaping: bool = false
## A skirmisher's reset after its hit: it hops out and retreats to its band.
var resetting: bool = false


## An attack it has seen coming lands within `within` seconds (0 = any).
func is_threatened(within: float) -> bool:
	for a in incoming:
		if within <= 0.0 or float(a.time_to_hit) <= within:
			return true
	return false

# --- What it can cast ---------------------------------------------------------
## Each castable slot's passing uses: {slot, intent, weight, plan: CastPlan}.
## Only uses with a plan are listed (get_ai_plan() found a good use now).
var uses: Array[Dictionary] = []

# --- Live nodes (the act step only) -------------------------------------------
var self_unit: Unit
var target_unit: Unit


## The listed use with the best plan value × weight among `intents`, or {}.
func get_best_use(intents: Array[StringName]) -> Dictionary:
	var best := {}
	var best_value := -INF
	for u in uses:
		if not intents.has(u.intent):
			continue
		var plan: CastPlan = u.plan
		var value: float = (plan.value if plan != null else 0.0) * float(u.weight)
		if value > best_value:
			best_value = value
			best = u
	return best


func has_use(intents: Array[StringName]) -> bool:
	return not get_best_use(intents).is_empty()


## Adds a castable use (tests and build_situation()).
func add_use(slot: StringName, intent: StringName, plan: CastPlan, weight: float = 1.0) -> void:
	uses.append({"slot": slot, "intent": intent, "weight": weight, "plan": plan})
