class_name ComboPlanner
extends RefCounted
## The combo planner (ENEMIES_AI.md, Combos, crowd control and the test
## duelist; ComboPlanner): static and pure, like EnemyBrain.decide(), over a
## SituationContext. One code path for both brains: the enemy brain calls it
## now, ALLIES' AllyBrain with AI-D4 (beside UnitController because both
## controllers use it). The weights come in as arguments: EnemyAITable's for
## an enemy, AllyTable's for the ally.
## Built in AI-D1: the two reads, each a 0–1 sum clamped to 1 that also fills
## its terms (term -> weighted value) for the overlay.
## - get_crowding(): how hard its target pushes it (near, closing, a
##   gap-closer in, hits);
## - get_opening(): how open its target is to its crowd control and burst
##   (escapes down, crowd-controlled by another, recovering, committed,
##   cornered).
## Built in AI-D2: the plans.
## - get_blind_reason(): the blind read (Ryan, 2026-10-07): its target can't
##   answer a combo now (held, low, its escapes or an ultimate down);
## - plan_fits(), has_fitting_plan(), pick_plan(): which plan a commit runs
##   (fit, weight × its opener's plan value, jitter, then mixup);
## - next_step(): a running plan's next move (wait, start a step, skip one,
##   or end, and why);
## - get_lean() and wants_stay(): the follow-through after a plan;
## - can_crowd_control(): the no-waste rule.

const CROWDING_TERMS: Array[StringName] = [&"near", &"closing", &"gap_closer", &"hits"]
const OPENING_TERMS: Array[StringName] = [&"escapes_down", &"cc_by_other", &"recovering", &"committed", &"cornered"]
## The blind read's reasons, in the order they're checked (AI-D2).
const BLIND_READS: Array[StringName] = [&"held", &"low_health", &"escapes_down", &"ultimate_down"]
## next_step()'s actions.
const WAIT := &"wait"
const START := &"start"
const SKIP := &"skip"
const END := &"end"
## Why a plan ended (Events.combo_plan_ended).
const DONE := &"done"
const MISSED := &"missed"
const WINDOW := &"window"
const INTERRUPTED := &"interrupted"
const TOKEN_LOST := &"token_lost"
const TARGET_LOST := &"target_lost"
const LOW_HEALTH := &"low_health"
const ODDS := &"odds"


## Crowding (0–1): the sum, clamped to 1, of each term × its weight
## (`weights`: EnemyAITable.crowding_weights):
## - near: 1 inside its crowded range, falling to 0 at its band's minimum
##   (get_near());
## - closing: the target's walk toward it ÷ crowding_closing_full, while the
##   target is within its band's far edge;
## - gap_closer: 1 when the target dashed or cast an ability that moves it in
##   the last crowding_recent_time s and it ended inside its band's minimum;
## - hits: the party's hits on it in the last crowding_hit_window s ÷
##   crowding_hits_full.
## `terms` (optional) gets each term's weighted value.
static func get_crowding(s: SituationContext, weights: Dictionary, terms: Dictionary = {}) -> float:
	if not s.has_target:
		terms.clear()
		return 0.0
	var raw := {
		&"near": get_near(s.target_edge_distance_px, s.crowded_range_px, s.band_min_px),
		&"closing": clampf(s.target_closing_px / maxf(s.crowding_closing_full_px, 0.01), 0.0, 1.0) \
			if s.target_edge_distance_px <= s.band_max_px else 0.0,
		&"gap_closer": 1.0 if s.target_gap_closer_in else 0.0,
		&"hits": clampf(float(s.recent_hits) / float(maxi(s.crowding_hits_full, 1)), 0.0, 1.0),
	}
	return _sum(raw, CROWDING_TERMS, weights, terms)


## Crowding's near term: 1 inside `crowded_px` (edge to edge), falling
## linearly to 0 at `band_min_px` (a caster's two are the same: 1 or 0).
static func get_near(edge_px: float, crowded_px: float, band_min_px: float) -> float:
	if edge_px < crowded_px:
		return 1.0
	if band_min_px <= crowded_px:
		return 0.0
	return clampf((band_min_px - edge_px) / (band_min_px - crowded_px), 0.0, 1.0)


## The opening (0–1): the sum, clamped to 1, of each term × its weight
## (`weights`: EnemyAITable.opening_weights):
## - escapes_down: the share of its target's mobility and defensive respect
##   value on cooldown (0 with none);
## - cc_by_other: 1 when a crowd control from another unit has at least
##   opening_cc_min_left s left on it;
## - recovering: 1 while its punish window is open (AI6; 0 until then);
## - committed: 1 while it casts (a cast time, a channel, a held charge-up);
## - cornered: 1 with a wall or a ledge just behind it.
## A token is a gate, not a term: the setup's commit asks for its token as
## any commit does. `terms` (optional) gets each term's weighted value.
static func get_opening(s: SituationContext, weights: Dictionary, terms: Dictionary = {}) -> float:
	if not s.has_target:
		terms.clear()
		return 0.0
	var raw := {
		&"escapes_down": clampf(s.target_escapes_down, 0.0, 1.0),
		&"cc_by_other": 1.0 if s.target_cc_left >= s.opening_cc_min_left - 0.0001 and s.target_cc_left > 0.0 else 0.0,
		&"recovering": 1.0 if s.target_recovering else 0.0,
		&"committed": 1.0 if s.target_committed else 0.0,
		&"cornered": 1.0 if s.target_cornered else 0.0,
	}
	return _sum(raw, OPENING_TERMS, weights, terms)


## The term with the largest weighted value in `terms` ([name, value]; [&"",
## 0.0] when all are 0): the overlay's "biggest term".
static func get_biggest_term(terms: Dictionary) -> Array:
	var best: StringName = &""
	var best_value := 0.0
	for term: StringName in terms:
		var v: float = terms[term]
		if v > best_value + 0.0001:
			best = term
			best_value = v
	return [best, best_value]


## The blind read (AI-D2; Ryan, 2026-10-07: "they don't HAVE to wait for their
## opener to land ... they would just prefer to wait"): the first reason its
## target can't answer a combo now, or &"" (then it waits for its opener to
## land). In order, each while s.blind_reads has it on:
## - held: a crowd control on it (any source);
## - low_health: its health below `finish_threshold` (the enemy's slider);
## - escapes_down: it has mobility or defensive abilities and none is ready;
## - ultimate_down: one of its `ultimate` abilities is on cooldown.
static func get_blind_reason(s: SituationContext, finish_threshold: float) -> StringName:
	if not s.has_target:
		return &""
	for reason in BLIND_READS:
		if not s.blind_reads.get(reason, false):
			continue
		match reason:
			&"held":
				if s.target_cc:
					return reason
			&"low_health":
				if s.target_health_ratio < finish_threshold:
					return reason
			&"escapes_down":
				if s.target_escapes > 0 and s.target_escapes_ready <= 0:
					return reason
			&"ultimate_down":
				if s.target_ultimates > s.target_ultimates_ready:
					return reason
	return &""


## A plan option (SituationContext.plan_options) fits now: its conditions
## pass, every needed step's ability is ready, its opener can be cast with a
## plan, its opener's crowd control wouldn't be wasted, and (a blind plan:
## its opener has no `opener` role) the blind read passes. A plan whose
## opener is down simply doesn't fit: the enemy never waits for an ability.
static func plan_fits(option: Dictionary, s: SituationContext) -> bool:
	if not option.get("conditions_ok", false) or not option.get("ready", false) or not option.get("cc_ok", true):
		return false
	if option.get("opener") == null:
		return false
	return not option.get("blind", false) or s.blind_reason != &""


static func has_fitting_plan(s: SituationContext) -> bool:
	for o in s.plan_options:
		if plan_fits(o, s):
			return true
	return false


## The plan a commit runs (ENEMIES_AI.md, Picking a plan): among the options
## that fit, the highest weight × its opener's plan value × (1 ± jitter); then
## one mixup roll: with two or more fitting it takes the runner-up, with one
## it holds a beat (mixup_delay_min–max s) before starting. {plan, opener
## (CastPlan), runner_up, delay, roll}, or {} when none fits. `stream` is the
## brain's rng (decide()'s).
static func pick_plan(s: SituationContext, b: EnemyBehavior, stream: RandomNumberGenerator) -> Dictionary:
	var fits: Array = []   # [score, order, option]
	for o in s.plan_options:
		if not plan_fits(o, s):
			continue
		var plan: ComboPlan = o.plan
		var opener: CastPlan = o.opener
		var score := plan.weight * opener.value * (1.0 + stream.randf_range(-b.jitter, b.jitter))
		fits.append([score, fits.size(), o])
	if fits.is_empty():
		return {}
	fits.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0] or (x[0] == y[0] and x[1] < y[1]))
	var pick: Dictionary = fits[0][2]
	var runner_up := false
	var delay := 0.0
	var roll := stream.randf()
	if roll < b.mixup:
		if fits.size() >= 2:
			pick = fits[1][2]
			runner_up = true
		else:
			delay = stream.randf_range(s.mixup_delay_min, s.mixup_delay_max)
	return {"plan": pick.plan, "opener": pick.opener, "runner_up": runner_up, "delay": delay, "roll": roll}


## A running plan's next move (ENEMIES_AI.md, Combo plans): {action: WAIT /
## START / SKIP / END, index (the step), reason (END, SKIP), trigger (START:
## when its trigger came), carried / greed (set when a miss was decided now)}.
## `progress` (the brain keeps it): index (the next step), prev_end (s; −1 =
## the previous step's cast hasn't ended), prev_landed (s; −1 = not landed),
## prev_miss_at (s: by then a hit that hasn't landed is a miss), opener_landed,
## carried (it carried on after a miss), greed (its one roll; −1 = not
## rolled), finishers (the indexes of `finisher`-role steps), target_tags
## (the target's status tags now, for ON_STATUS).
## - Its own steps never wait for its reaction time: each starts on the tick
##   its trigger comes.
## - AFTER_LANDED waits for the previous hit to land (it prefers to); a miss
##   carries on when the blind read passes or it carried on before, else one
##   combo_greed roll a plan decides: a fail ends the plan (MISSED).
## - A step that can't start within its window after its trigger is skipped
##   when optional, else the plan ends (WINDOW).
## - No blind finisher: a finisher step needs its opener landed, a carry-on,
##   or the blind read; otherwise the plan ends (MISSED).
static func next_step(plan: ComboPlan, progress: Dictionary, s: SituationContext, b: EnemyBehavior, now: float,
		stream: RandomNumberGenerator) -> Dictionary:
	var index: int = progress.get("index", 0)
	if index >= plan.steps.size():
		return {"action": END, "reason": DONE, "index": index}
	var step := plan.steps[index]
	var out := {"action": WAIT, "index": index}
	var prev_end: float = progress.get("prev_end", -1.0)
	if prev_end < 0.0:
		return out   # the previous step's cast hasn't ended
	var trigger := -1.0
	match step.timing:
		ComboStep.Timing.AFTER_LANDED:
			var landed: float = progress.get("prev_landed", -1.0)
			var miss_at: float = progress.get("prev_miss_at", INF)
			if landed >= 0.0:
				trigger = maxf(landed, prev_end)
			elif now + 0.0001 >= miss_at:
				if s.blind_reason != &"" or progress.get("carried", false):
					out.carried = true
				else:
					var roll: float = progress.get("greed", -1.0)
					if roll < 0.0:
						roll = stream.randf()
						out.greed = roll
					if roll >= b.combo_greed:
						return {"action": END, "reason": MISSED, "index": index, "greed": roll}
					out.carried = true
				trigger = miss_at
			else:
				return out   # it prefers to wait for the land
		ComboStep.Timing.AFTER_ENDED:
			trigger = prev_end
		ComboStep.Timing.AFTER_DELAY:
			trigger = prev_end + step.delay
		ComboStep.Timing.ON_STATUS:
			var tags: Array = progress.get("target_tags", [])
			if tags.has(step.status_tag):
				trigger = maxf(float(progress.get("status_seen", now)), prev_end)
			elif now - prev_end > step.window + 0.0001:
				return {"action": SKIP if step.optional else END, "reason": WINDOW, "index": index}
			else:
				return out
	if now + 0.0001 < trigger:
		return out
	if now - trigger > step.window + 0.0001:
		return {"action": SKIP if step.optional else END, "reason": WINDOW, "index": index}
	var finishers: Array = progress.get("finishers", [])
	if finishers.has(index) and not progress.get("opener_landed", false) and not progress.get("carried", false) \
			and not out.get("carried", false) and s.blind_reason == &"":
		return {"action": END, "reason": MISSED, "index": index}
	out.action = START
	out.trigger = trigger
	return out


## The follow-through's lean (ENEMIES_AI.md, After the plan): (1 − effective
## respect) × (0.5 + 0.5 × its health) × (0.5 + 0.5 × its own kit ready).
static func get_lean(s: SituationContext) -> float:
	return (1.0 - clampf(s.effective_respect, 0.0, 1.0)) * (0.5 + 0.5 * clampf(s.health_ratio, 0.0, 1.0)) \
		* (0.5 + 0.5 * clampf(s.own_kit_ready, 0.0, 1.0))


## It stays on its target after a plan when its lean is at least 1 −
## `follow_through` (at 0 it always resets, at 1 it always stays); never
## without the token it needs.
static func wants_stay(s: SituationContext, follow_through: float) -> bool:
	if s.needs_token and not s.has_token:
		return false
	if follow_through <= 0.0:
		return false
	return get_lean(s) >= 1.0 - follow_through - 0.0001


## The no-waste rule (ENEMIES_AI.md, It never wastes crowd control): no
## crowd-control step on a target that is CC-immune, or held by a crowd
## control with more time left than the step's cast time.
static func can_crowd_control(s: SituationContext, cast_time: float) -> bool:
	if s.target_cc_immune:
		return false
	return s.target_held_left <= cast_time + 0.0001


static func _sum(raw: Dictionary, order: Array[StringName], weights: Dictionary, terms: Dictionary) -> float:
	terms.clear()
	var total := 0.0
	for term in order:
		var v: float = float(raw[term]) * float(weights.get(term, 0.0))
		terms[term] = v
		total += v
	return clampf(total, 0.0, 1.0)
