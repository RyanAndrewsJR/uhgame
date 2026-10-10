class_name BrainScoring
extends RefCounted
## The enemy brain's pure functions (ENEMIES_AI.md, The brain; split out of
## EnemyBrain in R1, code unchanged): static, with no state and no brain, each
## a function of its arguments (the situation, the resolved behavior, the AI
## table, abilities and units) and, where it rolls, the brain's own seeded
## stream passed in. The intents and outcomes they name are EnemyBrain's
## constants. EnemyBrain keeps a forwarder for each one its contract names
## (res://scripts/tests/golden/brain_api.txt), so outside callers and the
## tests call EnemyBrain.decide() and the rest as before.


# --- What it sees coming (AI3) --------------------------------------------------------

## Seconds before `p` (a PartySnapshot projectile) reaches `unit`'s circle on
## its path, or −1 when it won't (it passed, it's too far off, or it runs out
## of range first).
static func get_projectile_time_to_hit(p: Dictionary, unit: Unit) -> float:
	var dir: Vector2 = p.direction
	var rel: Vector2 = unit.global_position - (p.position as Vector2)
	var r := unit.get_gameplay_radius_px()
	var along := rel.dot(dir)
	if along < -r or along - r > float(p.range_left_px):
		return -1.0
	if (rel - dir * along).length() > float(p.half_width_px) + r:
		return -1.0
	return maxf(along - r, 0.0) / maxf(float(p.speed_px), 0.01)


# --- Duels and odds (AI3b) ------------------------------------------------------------

## Its key ability's slot (ENEMIES_AI.md, Confidence): its first `ultimate`,
## else its ability with the highest respect value (authored or derived);
## a tie goes to the earlier slot (q, w, e, r). &"" = no abilities.
static func find_key_slot(abilities: AbilityComponent, table: EnemyAITable) -> StringName:
	if abilities == null:
		return &""
	var best: StringName = &""
	var best_value := -INF
	for slot in AbilityComponent.SLOTS:
		var ability := abilities.get_ability(slot)
		if ability == null:
			continue
		if ability.tags.has(&"ultimate"):
			return slot
		var value := table.get_respect_value(ability)
		if value > best_value + 0.0001:
			best = slot
			best_value = value
	return best


## Its own kit ready, read as a champion's is (the respect value of its
## ready slots ÷ that of all of them), while its key is ready; 0 while the
## key is down (Confidence).
static func get_own_ready_share(abilities: AbilityComponent, table: EnemyAITable, key_slot: StringName) -> float:
	if abilities == null or key_slot == &"" or not (abilities.is_ready(key_slot) and abilities.can_afford(key_slot)):
		return 0.0
	var total := 0.0
	var ready_value := 0.0
	for slot in AbilityComponent.SLOTS:
		var ability := abilities.get_ability(slot)
		if ability == null:
			continue
		var value := table.get_respect_value(ability)
		total += value
		if abilities.is_ready(slot) and abilities.can_afford(slot):
			ready_value += value
	return ready_value / total if total > 0.0 else 0.0


## Effective respect (ENEMIES_AI.md, Duels and odds): respect × its
## respect_weight × (1 − confidence × its own kit ready) × (1 − nerve × the
## press; AI3c), clamped 0–1.
static func get_effective_respect(s: SituationContext, b: EnemyBehavior) -> float:
	return clampf(s.respect * b.respect_weight * (1.0 - b.confidence * s.own_ready_share) * (1.0 - b.nerve * s.press), 0.0, 1.0)


## One crowded episode's roll (ENEMIES_AI.md, Crowded; pure, seeded), in
## order: cornered (the cornered stand wins); escape (a caster, or any role
## with a passing escape use); an answer ready: crowded_commit to go all in,
## and (AI-D1) when that roll fails, a peel if a `peel` use passes (its roll
## is the one that failed); else (no answer, or no peel) the mix, Ryan's: back
## up once with the chance 1 − aggression, otherwise stand and swing.
## {result, roll (the roll that decided it, −1 = none), answer (it had one)}.
## `stream` is the brain's rng.
static func roll_crowded(s: SituationContext, b: EnemyBehavior, stream: RandomNumberGenerator) -> Dictionary:
	var answer := s.has_answer()
	if s.cornered:
		return {"result": EnemyBrain.CORNERED, "roll": -1.0, "answer": answer}
	if wants_escape(s, b, s.has_use([EnemyBrain.ESCAPE] as Array[StringName])):
		return {"result": EnemyBrain.ESCAPE, "roll": -1.0, "answer": answer}
	if answer:
		var roll := stream.randf()
		if roll < b.crowded_commit:
			return {"result": EnemyBrain.ALL_IN, "roll": roll, "answer": true}
		if s.has_use([EnemyBrain.PEEL] as Array[StringName]):
			return {"result": EnemyBrain.PEEL, "roll": roll, "answer": true}
	var mix := stream.randf()
	return {"result": EnemyBrain.BACK_UP if mix < 1.0 - b.aggression else EnemyBrain.STAND, "roll": mix, "answer": answer}


## The right moment for its key, or "" (pure): its target crowd-controlled,
## below its finish threshold, every one of its defensive abilities on
## cooldown, crowded (being crowded is a right moment: it answers), or its
## key's area covering spend_min_champions champions. A punish window joins
## them in AI6.
static func get_right_moment(s: SituationContext, b: EnemyBehavior) -> String:
	if s.target_cc:
		return "crowd-controlled"
	if s.target_health_ratio < b.finish_threshold:
		return "low"
	if s.target_defensives > 0 and s.target_defensives_ready == 0:
		return "defensives down"
	if s.crowded:
		return "crowded"
	if s.key_area_champions >= s.spend_min_champions:
		return "%d in its area" % s.key_area_champions
	return ""


# --- The odds (AI3c) ------------------------------------------------------------------

## A hit by `ability` from `caster` on `target` is heavy (ENEMIES_AI.md, Odds;
## Ryan): worth at least heavy_hit_share of the target's max health by the
## caster's own numbers (Ability.get_damage_against(): before mitigation).
## Basic attacks never count (they aren't abilities), nor chip pokes.
static func is_heavy_hit(ability: Ability, caster: Unit, target: Unit, table: EnemyAITable) -> bool:
	if ability == null or target == null or target.health == null or target.health.max_health <= 0.0:
		return false
	return ability.get_damage_against(caster, target) >= table.heavy_hit_share * target.health.max_health - 0.0001


## Seconds until `ability`'s hit lands on `target` if it's cast now: its cast
## time, plus a projectile's flight from the caster.
static func get_time_to_land(ability: Ability, caster: Unit, target: Unit) -> float:
	var time := maxf(ability.get_param(caster, &"cast_time"), 0.0)
	if ability.tags.has(&"projectile") and ability.projectile_speed > 0.0:
		time += caster.global_position.distance_to(target.global_position) / Units.to_px(ability.projectile_speed)
	return time


# --- Combos: crowding, the opening, the peel and the setup (AI-D1) --------------------

## Its `opener`-role slots (Ability.combo_roles), in slot order.
static func find_opener_slots(abilities: AbilityComponent) -> Array[StringName]:
	var out: Array[StringName] = []
	if abilities == null:
		return out
	for slot in AbilityComponent.SLOTS:
		var ability := abilities.get_ability(slot)
		if ability != null and ability.combo_roles.has(EnemyBrain.OPENER_ROLE):
			out.append(slot)
	return out


# --- Combo plans (AI-D2) --------------------------------------------------------------

## Its follow-up slots: abilities with combo roles and none of them `opener`
## (kept for its plans unless the blind read passes).
static func find_follow_up_slots(abilities: AbilityComponent) -> Array[StringName]:
	var out: Array[StringName] = []
	if abilities == null:
		return out
	for slot in AbilityComponent.SLOTS:
		var ability := abilities.get_ability(slot)
		if ability != null and not ability.combo_roles.is_empty() and not ability.combo_roles.has(EnemyBrain.OPENER_ROLE):
			out.append(slot)
	return out


## Its own kit ready (the follow-through's lean): the share of its slots'
## respect value ready now, its key's included whether it's up or not.
static func get_own_kit_ready(abilities: AbilityComponent, table: EnemyAITable) -> float:
	if abilities == null:
		return 0.0
	var total := 0.0
	var ready_value := 0.0
	for slot in AbilityComponent.SLOTS:
		var ability := abilities.get_ability(slot)
		if ability == null:
			continue
		var value := table.get_respect_value(ability)
		total += value
		if abilities.is_ready(slot) and abilities.can_afford(slot):
			ready_value += value
	return ready_value / total if total > 0.0 else 0.0


## Seconds after `ability`'s cast ends during which its hit can still land on
## `target` (a plan step's miss time, before whiff_time): a projectile's
## flight past it (at most its range), a dash's dash_time, else 0.
static func get_travel_time(ability: Ability, caster: Unit, target: Unit) -> float:
	if ability == null:
		return 0.0
	if ability.tags.has(&"projectile") and ability.projectile_speed > 0.0:
		var range_px := Units.to_px(ability.get_param(caster, &"cast_range"))
		var distance := range_px
		if is_instance_valid(caster) and is_instance_valid(target):
			distance = minf(caster.global_position.distance_to(target.global_position) + target.get_gameplay_radius_px(), range_px)
		return distance / Units.to_px(ability.projectile_speed)
	var dash: Variant = ability.get(&"dash_time")
	return float(dash) if dash is float else 0.0


static func _has_use_for(ability: Ability, intents: Array[StringName]) -> bool:
	for use in ability.get_ai_uses():
		if use != null and intents.has(use.intent):
			return true
	return false


# --- Decide (pure) --------------------------------------------------------------------

## The decision (ENEMIES_AI.md, Scoring), a pure function of the situation,
## the resolved behavior and a seeded generator: nothing else is read. Every
## intent the situation allows gets its base score × the behavior's intent
## weight × (1 ± jitter); the current intent gets the hold bonus until
## min_intent_time; the highest wins. AI1: hold (always), poke (a poke use
## passes; a caster's scores higher), commit (patience full with its tokens
## (AI2: or none needed), a commit under way, or a taunt on its target). AI3:
## defend (a defend use passes: it's threatened), escape (wants_escape()),
## retreat (a FALL_BACK enemy below its retreat health, or a skirmisher's
## reset); while retreating it keeps poking. AI3b: smell blood (commit ×
## smell_blood_mult below its finish threshold, capped), the walk out (the
## kiting step, the cautious walk) as a retreat, a held key's uses left out
## (SituationContext.get_best_use()). AI-D1: peel (its episode rolled a peel
## and its peel use passes; like defend it answers something already
## happening), and a setup's commit opens with its best opener. AI-D2: an
## enemy with combo plans opens a commit with one when one fits
## (ComboPlanner.pick_plan(): weight, jitter, mixup), and its own hits leave
## out its follow-ups unless the blind read passes.
static func decide(s: SituationContext, b: EnemyBehavior, stream: RandomNumberGenerator) -> BrainDecision:
	var d := BrainDecision.new()
	if not s.has_target:
		d.reason = "no target"
		return d
	var raw := {}
	raw[EnemyBrain.HOLD] = float(s.intent_scores.get(EnemyBrain.HOLD, 0.0))
	var poke := s.get_best_use([EnemyBrain.POKE])
	if not poke.is_empty():
		raw[EnemyBrain.POKE] = s.caster_poke_score if b.role == EnemyBehavior.Role.CASTER else float(s.intent_scores.get(EnemyBrain.POKE, 0.0))
	var tokens_ok := s.has_token or not s.needs_token
	if s.target_reachable and (s.committing or s.taunted or (s.patience >= 1.0 and tokens_ok)):
		raw[EnemyBrain.COMMIT] = float(s.intent_scores.get(EnemyBrain.COMMIT, 0.0))
		if s.target_health_ratio < b.finish_threshold:
			raw[EnemyBrain.COMMIT] = minf(raw[EnemyBrain.COMMIT] * s.smell_blood_mult, s.smell_blood_cap)   # smell blood (AI3b)
	var defend := s.get_best_use([EnemyBrain.DEFEND])
	if not defend.is_empty():
		raw[EnemyBrain.DEFEND] = float(s.intent_scores.get(EnemyBrain.DEFEND, 0.0))
	var peel := s.get_best_use([EnemyBrain.PEEL])
	if s.peel_pending and not peel.is_empty():
		raw[EnemyBrain.PEEL] = float(s.intent_scores.get(EnemyBrain.PEEL, 0.0))   # AI-D1 (after defend: a tie keeps defend)
	var escape := s.get_best_use([EnemyBrain.ESCAPE])
	if wants_escape(s, b, not escape.is_empty()):
		raw[EnemyBrain.ESCAPE] = float(s.intent_scores.get(EnemyBrain.ESCAPE, 0.0))
	if s.resetting or s.walking_out or (b.low_health == EnemyBehavior.LowHealth.FALL_BACK and s.health_ratio < b.retreat_health):
		raw[EnemyBrain.RETREAT] = float(s.intent_scores.get(EnemyBrain.RETREAT, 0.0))
	var best: StringName = &""
	var best_score := -INF
	var urgent := raw.has(EnemyBrain.DEFEND)   # an attack coming breaks the no-flip-flop hold (The brain)
	for intent: StringName in raw:   # in the order above: a tie keeps the earlier
		var score: float = raw[intent] * b.get_intent_weight(intent) * (1.0 + stream.randf_range(-b.jitter, b.jitter))
		if intent == s.intent and s.intent_age < s.min_intent_time and not urgent:
			score += s.intent_hold_bonus
		elif intent == EnemyBrain.ESCAPE and s.escaping:
			score += s.intent_hold_bonus   # a walk away under way holds (AI3)
		d.scores[intent] = score
		if score > best_score:
			best = intent
			best_score = score
	d.intent = best
	match best:
		EnemyBrain.POKE:
			d.plan = poke.plan
		EnemyBrain.COMMIT:
			# AI-D2: an enemy with plans opens a commit with one when one fits
			# (a setup is such a commit; AI-D1 opened with its best opener);
			# the running plan's opener still to come keeps a fresh aim; its
			# later steps come from the drive.
			if s.has_plans and (not s.committing or s.commit_plan_open):
				var pick := ComboPlanner.pick_plan(s, b, stream)
				if not pick.is_empty():
					d.combo_plan = pick.plan
					d.plan = pick.opener
					d.plan_runner_up = pick.runner_up
					d.plan_delay = pick.delay if not s.committing else 0.0
					d.setup = s.setup and not s.committing
			elif s.plan_opener_pending:
				d.plan = s.plan_opener_plan
			if d.combo_plan == null and not s.plan_running:
				# Its hits: damage uses, and a gap-closer while out of its
				# reach; its follow-ups kept for its plans unless the blind
				# read passes (AI-D2).
				var intents: Array[StringName] = [&"damage"]
				if s.target_edge_distance_px > s.attack_reach_px:
					intents.append(&"gap_close")
				var use := s.get_best_use(intents, [] as Array[StringName], s.kept_slots)
				if not use.is_empty():
					d.plan = use.plan
		EnemyBrain.HOLD:
			var zone := s.get_best_use([&"zone"])
			if not zone.is_empty():
				d.plan = zone.plan
		EnemyBrain.DEFEND:
			d.plan = defend.plan
		EnemyBrain.PEEL:
			d.plan = peel.plan
		EnemyBrain.ESCAPE:
			if not escape.is_empty():
				d.plan = escape.plan   # else it walks away
		EnemyBrain.RETREAT:
			if not poke.is_empty():
				d.plan = poke.plan   # it keeps poking as it falls back
	if best in EnemyBrain.TELL_POSES and s.intent != best:
		d.pose = EnemyBrain.TELL_POSES[best]   # a new attack starts with its tell
	else:
		d.pose = get_intent_pose(best, b.role, s.cornered, s.resetting, s.press > 0.0)
	d.reason = "%s %.2f  patience %.2f  respect %.2f" % [best, best_score, s.patience, s.effective_respect]
	return d


## Escape (ENEMIES_AI.md, Cornered casters): its target inside its band's
## minimum, for a caster or anyone with an escape use; a walk away under way
## goes on; never while cornered or committing.
static func wants_escape(s: SituationContext, b: EnemyBehavior, has_escape_use: bool) -> bool:
	if s.cornered or s.committing:
		return false
	if s.escaping:
		return true
	if b.role != EnemyBehavior.Role.CASTER and not has_escape_use:
		return false
	return s.target_edge_distance_px < Units.to_px(b.range_band_min)


## The pose `intent` shows while it runs (ENEMIES_AI.md, Tells), by role:
## hold (a skirmisher's stalk; a cornered caster's cornered; AI3c: press while
## pressing), guard (defend), step_back (escaping on foot, a caster falling
## back), recoil (a skirmisher's reset); &"" = none (an attack's own look).
static func get_intent_pose(intent: StringName, role: EnemyBehavior.Role, cornered: bool = false, resetting: bool = false, pressing: bool = false) -> StringName:
	if cornered and (intent == EnemyBrain.HOLD or intent == EnemyBrain.POKE or intent == EnemyBrain.ESCAPE):
		return &"cornered"   # (an escape is cornered mid-walk; its next think picks again)
	match intent:
		EnemyBrain.HOLD, EnemyBrain.POKE:
			if pressing:
				return &"press"   # the press shows: a lean in, an amber rim (Odds)
			return &"stalk" if role == EnemyBehavior.Role.SKIRMISHER or role == EnemyBehavior.Role.ASSASSIN else &"hold"   # AR3b: an Assassin stalks
		EnemyBrain.DEFEND:
			return &"guard"
		EnemyBrain.ESCAPE:
			return &"step_back"
		EnemyBrain.RETREAT:
			return &"recoil" if resetting else &"step_back"
	return &""


## How fast patience fills (per second; ENEMIES_AI.md, The standoff): (1 −
## patience_respect_cut × effective respect) ÷ patience_time × (0.5 +
## aggression) × pressure. Pressure is 1, plus idle_pressure while the target
## has been idle idle_time s, plus low_pressure while it's below low_health.
## So with everything up it still fills, at a quarter of its speed: a brute
## (3 s, aggression 0.5) comes in 12 s at the latest.
## AI3b: while cautious (its key spent) × (1 − cautious_patience_cut ×
## confidence). AI3c: the odds' push (odds_pressure × the press) and low
## health's share one push, the larger (both count the target's health).
static func get_patience_rate(s: SituationContext, b: EnemyBehavior, table: EnemyAITable) -> float:
	var pressure := 1.0
	if s.target_idle_time >= table.idle_time:
		pressure += table.idle_pressure
	var low := table.low_pressure if s.target_health_ratio < table.low_health else 0.0
	pressure += maxf(low, table.odds_pressure * s.press)
	var rate := (1.0 - table.patience_respect_cut * s.effective_respect) / maxf(b.patience_time, 0.01) \
		* (0.5 + b.aggression) * pressure
	if s.cautious_left > 0.0:
		rate *= 1.0 - table.cautious_patience_cut * b.confidence
	return rate


## A string's length in hits (ARCHETYPES.md, Strings and the beat; D6, D8;
## AR1a), pure over the situation and the brain's seeded stream. Its rank's
## range: its short end (AttackCombo.get_string_hits_min(): a regular's
## length), up to its swings' count with string_full_range (an elite), plus
## string_extra_hits (a boss's 1). Effective respect at or above
## string_respect_short cuts it to string_short_hits; at or below
## string_respect_full, or its target under the table's low_health, it runs
## the range's top, and with string_full_range one hit more at a chance of
## its aggression; in between, a length rolled in the range. 0 = no string.
static func get_string_length(s: SituationContext, attack_string: AttackCombo, rules: RankRules, table: EnemyAITable,
		b: EnemyBehavior, stream: RandomNumberGenerator) -> int:
	if attack_string == null or attack_string.swings.is_empty():
		return 0
	var low := attack_string.get_string_hits_min()
	var high := low
	var full := rules != null and rules.string_full_range
	if full:
		high = maxi(attack_string.swings.size(), low)
	if rules != null:
		high += maxi(rules.string_extra_hits, 0)
	if s.effective_respect >= table.string_respect_short - 0.0001:
		return clampi(table.string_short_hits, 1, high)
	if s.effective_respect <= table.string_respect_full + 0.0001 or s.target_health_ratio < table.low_health:
		if full and b != null and stream.randf() < b.aggression:
			return high + 1
		return high
	return stream.randi_range(low, high)
