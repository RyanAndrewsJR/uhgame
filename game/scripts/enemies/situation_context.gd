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
## and the target's walk for aim lead. AI3c added the odds and the press.
## AI-D1 (Combos) added crowding and the opening (ComboPlanner's two reads,
## their inputs and terms), the target's escapes, crowd control, cast and
## cornered, the peel and the setup. AI-D2 added the combo plans (the options,
## the plan under way, the blind read, its own kit ready, its follow-ups).
## Later steps add dodging (AI4) and the punish window (AI6).

## The intents a held key ability isn't used for (Spending the key ability:
## a poke, a defend, an escape and a gap-closer are never held).
const HELD_INTENTS: Array[StringName] = [&"damage", &"cc", &"zone"]
## The intents an answer can come from when crowded (an escape is step 2's;
## a poke isn't one: ENEMIES_AI.md, Crowded).
const ANSWER_INTENTS: Array[StringName] = [&"cc", &"damage", &"zone", &"punish", &"finish"]
## The uses a setup's opener can come from (AI-D1: its best `opener`-role
## ability's; a plan can open with crowd control, a strike or a poke).
const OPENER_INTENTS: Array[StringName] = [&"cc", &"damage", &"gap_close", &"poke"]

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
## its roll: &"all_in", &"back_up", &"stand", &"escape", &"cornered", &""
## (AI-D1: &"peel"; since AI-D1 crowding at its peel_threshold starts it).
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

# --- The odds (AI3c) ----------------------------------------------------------------
## The enemy side's strength ÷ the party's (Brains.get_odds(): one read per
## tick), and the press (0–1: how far past odds_threshold; 0 for a boss,
## which never presses).
var odds: float = 0.0
var press: float = 0.0

# --- Combos: crowding and the opening (AI-D1) ------------------------------------------
## Crowding (0–1; ComboPlanner.get_crowding()): how hard its target pushes it.
## Its inputs: its crowded range and band (px, edge to edge), the target's
## walk toward it (px/s), a gap-closer of the target's that ended inside its
## band's minimum within crowding_recent_time s, the party's hits on it in the
## last crowding_hit_window s; the table's two numbers, copied in. Its terms
## (term -> weighted value) for the overlay.
var crowding: float = 0.0
var crowding_terms: Dictionary = {}
var crowded_range_px: float = 0.0
var band_min_px: float = 0.0
var band_max_px: float = 0.0
var target_closing_px: float = 0.0
var target_gap_closer_in: bool = false
var recent_hits: int = 0
var crowding_closing_full_px: float = 128.0
var crowding_hits_full: int = 3
## The opening (0–1; ComboPlanner.get_opening()): how open its target is to
## its crowd control and burst. Its inputs: the target's mobility and
## defensive abilities (how many, how many ready, the share of their respect
## value on cooldown), the longest crowd control on it from another unit
## (seen after its reaction time) and who applied it, it casting (seen after
## its reaction time), its punish window (AI6), a wall or a ledge just behind
## it; the table's number, copied in. Its terms for the overlay.
var opening: float = 0.0
var opening_terms: Dictionary = {}
var target_escapes: int = 0
var target_escapes_ready: int = 0
var target_escapes_down: float = 0.0
var target_cc_left: float = 0.0
var target_cc_source: Unit
var target_committed: bool = false
var target_recovering: bool = false
var target_cornered: bool = false
var opening_cc_min_left: float = 0.5
## The attacks THREATENED's &"major" filter counts (EnemyAITable.major_tags).
var major_tags: Array[StringName] = []
## Its `opener`-role slots (it reads the opening and sets up only with one,
## until AI-D2's plans), and this think's setup: the opening at its
## opening_bar or more while it isn't crowded, an opener ready (its patience
## fills at once and it commits with that opener). setup_opener: the commit
## under way is a setup whose opener hasn't been cast yet.
var opener_slots: Array[StringName] = []
var setup: bool = false
var setup_opener: bool = false
## Its crowded episode's roll was a peel and its peel hasn't been cast yet.
var peel_pending: bool = false

# --- Combo plans (AI-D2) -------------------------------------------------------------
## It has combo plans (EnemyData.combo_plans at the run's tier): only then does
## it set up, pick plans and keep its follow-ups for them.
var has_plans: bool = false
## Each plan it could start now (built while it may start a commit): {plan:
## ComboPlan, opener: CastPlan (null = its opener can't be cast now), ready
## (every needed step's ability ready), conditions_ok, blind (its opener has
## no `opener` role: it fits only on the blind read), cc_ok (its opener's
## crowd control wouldn't be wasted)}. ComboPlanner.pick_plan() reads them.
var plan_options: Array[Dictionary] = []
## A plan runs in the commit under way; a fresh commit (still in its tell, no
## plan yet) may still pick one; the running plan's opener is still to cast,
## with its plan now (a fresh aim).
var plan_running: bool = false
var commit_plan_open: bool = false
var plan_opener_pending: bool = false
var plan_opener_plan: CastPlan
## The blind read (Ryan, 2026-10-07; ComboPlanner.get_blind_reason()): why its
## target can't answer a combo now (&"held", &"low_health", &"escapes_down",
## &"ultimate_down"; &"" = it can, so it waits for its opener to land). Its
## inputs: the target's ultimates (how many, how many ready), any crowd
## control on it (target_cc) and the longest one's time left, CC-immune; the
## table's switches, copied in.
var blind_reason: StringName = &""
var blind_reads: Dictionary = {}
var target_ultimates: int = 0
var target_ultimates_ready: int = 0
var target_held_left: float = 0.0
var target_cc_immune: bool = false
## Its own kit ready: the share of its slots' respect value ready now (not
## zeroed while its key is down, unlike own_ready_share): the follow-through's
## lean.
var own_kit_ready: float = 0.0
## Its follow-ups (abilities with combo roles but no `opener`): kept for its
## plans unless the blind read passes (kept_slots, what get_best_use() leaves
## out of a commit's own hits).
var follow_up_slots: Array[StringName] = []
var kept_slots: Array[StringName] = []
## mixup's held beat (EnemyAITable), copied in.
var mixup_delay_min: float = 0.4
var mixup_delay_max: float = 0.8


## An attack it has seen coming lands within `within` seconds (0 = any). With
## `tag` (AI-D1), only one whose ability carries it; &"major" = any of
## major_tags.
func is_threatened(within: float, tag: StringName = &"") -> bool:
	for a in incoming:
		if tag != &"" and not ability_has_tag(a.get("ability") as Ability, tag, major_tags):
			continue
		if within <= 0.0 or float(a.time_to_hit) <= within:
			return true
	return false


## `ability` carries `tag`; &"major" = any of `majors` (charge_up also
## matches a CHARGE_UP cast style).
static func ability_has_tag(ability: Ability, tag: StringName, majors: Array[StringName]) -> bool:
	if ability == null:
		return false
	if tag != &"major":
		return ability.tags.has(tag) or (tag == &"charge_up" and ability.cast_style == Ability.CastStyle.CHARGE_UP)
	for t in majors:
		if t != &"major" and ability_has_tag(ability, t, majors):
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
## A held key's damage, cc and zone uses are left out (AI3b). With `slots`
## (AI-D1: a setup's opener), only those slots' uses; `exclude` (AI-D2: its
## kept follow-ups) leaves those slots out.
func get_best_use(intents: Array[StringName], slots: Array[StringName] = [], exclude: Array[StringName] = []) -> Dictionary:
	var best := {}
	var best_value := -INF
	for u in uses:
		if not intents.has(u.intent):
			continue
		if not slots.is_empty() and not slots.has(u.slot):
			continue
		if exclude.has(u.slot):
			continue
		if held_slot != &"" and u.slot == held_slot and HELD_INTENTS.has(u.intent):
			continue
		var plan: CastPlan = u.plan
		var value: float = (plan.value if plan != null else 0.0) * float(u.weight)
		if value > best_value:
			best_value = value
			best = u
	return best


func has_use(intents: Array[StringName], slots: Array[StringName] = []) -> bool:
	return not get_best_use(intents, slots).is_empty()


## Its best setup opener now (AI-D1): the best opener-intent use of its
## `opener`-role slots, or {} (none, or none of them castable with a plan).
func get_opener_use() -> Dictionary:
	if opener_slots.is_empty():
		return {}
	return get_best_use(OPENER_INTENTS, opener_slots)


## An answer to being crowded is ready (ENEMIES_AI.md, Crowded): a cc use, or
## a damage, zone, punish or finish use whose plan reaches the target from
## where it stands (a listed use has a plan, so it does). An escape is
## step 2's; a poke never answers.
func has_answer() -> bool:
	return has_use(ANSWER_INTENTS)


## Adds a castable use (tests and build_situation()).
func add_use(slot: StringName, use_intent: StringName, plan: CastPlan, weight: float = 1.0) -> void:
	uses.append({"slot": slot, "intent": use_intent, "weight": weight, "plan": plan})
