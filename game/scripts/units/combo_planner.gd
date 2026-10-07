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
## AI-D2 adds pick_plan(), next_step(), get_lean(), wants_stay() and the
## no-waste rule.

const CROWDING_TERMS: Array[StringName] = [&"near", &"closing", &"gap_closer", &"hits"]
const OPENING_TERMS: Array[StringName] = [&"escapes_down", &"cc_by_other", &"recovering", &"committed", &"cornered"]


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


static func _sum(raw: Dictionary, order: Array[StringName], weights: Dictionary, terms: Dictionary) -> float:
	terms.clear()
	var total := 0.0
	for term in order:
		var v: float = float(raw[term]) * float(weights.get(term, 0.0))
		terms[term] = v
		total += v
	return clampf(total, 0.0, 1.0)
