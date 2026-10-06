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
## states. AI3b (Duels and odds) added its key ability and own kit, cautious,
## the spend hold, the crowded episode, the walk out, smell blood's numbers
## and the target's walk for aim lead. Later steps add dodging (AI4) and the
## punish window (AI6).

## The intents a held key ability isn't used for (Spending the key ability:
## a poke, a defend, an escape and a gap-closer are never held).
const HELD_INTENTS: Array[StringName] = [&"damage", &"cc", &"zone"]
## The intents an answer can come from when crowded (an escape is step 2's;
## a poke isn't one: ENEMIES_AI.md, Crowded).
const ANSWER_INTENTS: Array[StringName] = [&"cc", &"damage", &"zone", &"punish", &"finish"]

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

# --- Duels and odds (AI3b) ----------------------------------------------------------
## Its key ability's slot (its ultimate, else its highest respect_value, ties
## to the earlier slot; &"" = none) and whether it's ready.
var key_slot: StringName = &""
var key_ready: bool = false
## Its own kit ready, read like a champion's (0–1), while its key is ready;
## 0 while the key is down (Confidence).
var own_ready_share: float = 0.0
## Seconds of caution left after spending its key (0 = not cautious).
var cautious_left: float = 0.0
## A right moment for its key (the target crowd-controlled, below its
## finish threshold, every defensive down, it's crowded, two champions in
## the key's area), and which.
var right_moment: bool = false
var right_moment_reason: String = ""
## Its key held by spend_eagerness (no right moment, the last roll failed):
## that slot's damage, cc and zone uses aren't picked (get_best_use()).
var held_slot: StringName = &""
## A crowded episode is on (its target came inside its crowded range), and
## its roll: &"all_in", &"back_up", &"stand", &"escape", &"cornered", &"".
var crowded: bool = false
var crowded_roll: StringName = &""
## Walking back out (the crowded kiting step, or a cautious walk to its
## band's far edge after a commit): a retreat.
var walking_out: bool = false
## The target's walk (px/s, what's on screen over the last 0.2 s; zero while
## it dashes or is pushed) and this enemy's aim_lead, for the plans.
var target_walk_velocity: Vector2 = Vector2.ZERO
var aim_lead: float = 0.0
## Smell blood's numbers (EnemyAITable), copied in for decide().
var smell_blood_mult: float = 1.3
var smell_blood_cap: float = 0.89
## For the right moments: its target holds a crowd control (a `cc` status:
## on screen), how many `defensive` abilities it has and how many are ready,
## the champions its key's planned area covers, and the table's count for
## that right moment.
var target_cc: bool = false
var target_defensives: int = 0
var target_defensives_ready: int = 0
var key_area_champions: int = 0
var spend_min_champions: int = 2


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
## A held key's damage, cc and zone uses are left out (AI3b).
func get_best_use(intents: Array[StringName]) -> Dictionary:
	var best := {}
	var best_value := -INF
	for u in uses:
		if not intents.has(u.intent):
			continue
		if held_slot != &"" and u.slot == held_slot and HELD_INTENTS.has(u.intent):
			continue
		var plan: CastPlan = u.plan
		var value: float = (plan.value if plan != null else 0.0) * float(u.weight)
		if value > best_value:
			best_value = value
			best = u
	return best


func has_use(intents: Array[StringName]) -> bool:
	return not get_best_use(intents).is_empty()


## An answer to being crowded is ready (ENEMIES_AI.md, Crowded): a cc use, or
## a damage, zone, punish or finish use whose plan reaches the target from
## where it stands (a listed use has a plan, so it does). An escape is
## step 2's; a poke never answers.
func has_answer() -> bool:
	return has_use(ANSWER_INTENTS)


## Adds a castable use (tests and build_situation()).
func add_use(slot: StringName, intent: StringName, plan: CastPlan, weight: float = 1.0) -> void:
	uses.append({"slot": slot, "intent": intent, "weight": weight, "plan": plan})
