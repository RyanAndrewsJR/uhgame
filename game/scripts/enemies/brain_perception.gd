class_name BrainPerception
extends RefCounted
## An enemy brain's perception (ENEMIES_AI.md, SituationContext, Knowledge;
## split out of EnemyBrain in R1, code unchanged): build_situation(), a new
## SituationContext each think, and its reads: the attacks it sees coming
## (after its reaction time), crowding, the opening, and the uses it could
## pick now with their plans. The state stays on the brain (brain.<name>);
## EnemyBrain keeps a forwarder for build_situation().

## The brain whose state it reads and writes (the brain owns this helper).
var brain: EnemyBrain


func _init(p_brain: EnemyBrain) -> void:
	brain = p_brain


## The situation now (ENEMIES_AI.md, SituationContext): itself, its target
## (Enemy.get_brain_target()), the party's respect from the shared snapshot,
## the attacks it sees coming (AI3), and each castable slot's passing uses
## with their plans.
func build_situation() -> SituationContext:
	var table := Brains.table
	var now := Brains.get_time()
	var s := SituationContext.new()
	s.self_unit = brain._enemy
	s.rank = brain.data.rank
	s.role = brain.behavior.role
	s.position = brain._enemy.global_position
	var max_health := brain._enemy.health.max_health
	s.health_ratio = brain._enemy.health.current / max_health if max_health > 0.0 else 0.0
	s.attack_reach_px = brain._enemy.attack.get_range_px()
	s.casting = brain._enemy.abilities != null and brain._enemy.abilities.casting
	s.move_blocked = brain._enemy.is_dash_blocked()
	s.cast_blocked = brain._enemy.is_cast_blocked()
	s.patience = brain._patience
	s.intent = brain._intent
	s.intent_age = now - brain._intent_started
	s.committing = brain._committing
	s.min_intent_time = table.min_intent_time
	s.intent_hold_bonus = table.intent_hold_bonus
	s.intent_scores = table.intent_scores
	s.caster_poke_score = table.caster_poke_score
	s.home_position = brain._enemy.get_pack_home()
	s.home_distance_px = brain._enemy.global_position.distance_to(s.home_position)
	s.needs_token = Brains.get_token_cost(brain._enemy) > 0
	s.has_token = Brains.has_token(brain._enemy)
	s.cornered = now < brain._cornered_until
	s.resetting = now < brain._resetting_until
	# AI3b: its key ability and its own kit; cautious; the numbers decide() reads.
	brain._key_slot = BrainScoring.find_key_slot(brain._enemy.abilities, table)
	s.key_slot = brain._key_slot
	s.key_ready = brain._key_slot != &"" and brain._brain_duel._is_slot_ready(brain._key_slot)
	if s.key_ready:
		brain._cautious_until = -1.0   # its key is back: no longer cautious
	s.own_ready_share = BrainScoring.get_own_ready_share(brain._enemy.abilities, table, brain._key_slot)
	s.cautious_left = maxf(brain._cautious_until - now, 0.0)
	s.walking_out = now < brain._walking_out_until
	s.aim_lead = brain.behavior.aim_lead
	s.smell_blood_mult = table.smell_blood_mult
	s.smell_blood_cap = table.smell_blood_cap
	s.spend_min_champions = table.spend_min_champions
	s.major_tags = table.major_tags   # AI-D1: THREATENED's major filter
	brain._opener_slots = BrainScoring.find_opener_slots(brain._enemy.abilities)
	s.opener_slots = brain._opener_slots
	s.setup_opener = brain._committing and brain._setup_opener
	var target := brain._enemy.get_brain_target()
	if target == null or not target.is_targetable():
		return s
	s.has_target = true
	s.target_unit = target
	s.target_position = target.global_position
	s.target_edge_distance_px = brain._enemy.edge_distance_to(target)
	s.target_cc = target.status_component != null and target.status_component.has_tag(&"cc")
	var snap := Brains.get_snapshot()
	var m := snap.get_member(target)
	_read_crowding(s, m, target, now)   # AI-D1: crowding starts the episode
	_read_closed_in(s, now)   # ARCHETYPES AR3b: the Riposte Stance's read
	brain._brain_duel._update_episode(s, target, now)
	s.target_in_sight = WorldQuery.has_line_of_sight(brain._enemy.global_position, target.global_position)
	s.target_reachable = brain._enemy.is_target_reachable()
	s.taunted = brain._enemy.get_taunter() == target
	s.tokens_free = Brains.get_tokens_free(target)
	if brain._escaping and s.target_edge_distance_px >= Units.to_px(brain.behavior.range_band_min):
		brain._escaping = false   # it got away
	s.escaping = brain._escaping
	s.party_size = snap.members.size()
	var target_share := 0.0
	if not m.is_empty():
		s.target_health_ratio = m.health_ratio
		s.target_kit_ready = m.kit_ready
		s.target_idle_time = m.idle_time
		target_share = PartySnapshot.get_share_for(m, brain.behavior.finish_threshold)   # AI3b: a panic button still counts
		s.target_defensives = m.get("defensives", 0)
		s.target_defensives_ready = m.get("defensives_ready", 0)
		s.target_walk_velocity = m.get("walk_velocity", Vector2.ZERO)
	else:
		var target_max := target.health.max_health
		s.target_health_ratio = target.health.current / target_max if target_max > 0.0 else 0.0
	var others: Array[float] = []
	for o in snap.members:
		if o.unit == target or not o.up:
			continue
		if brain._enemy.global_position.distance_to(o.position) <= table.ally_respect_range_px:
			others.append(PartySnapshot.get_share_for(o, brain.behavior.finish_threshold))
	s.respect = PartySnapshot.combine_respect(target_share, others, table.ally_respect_weight)
	var odds := Brains.get_odds()   # AI3c: one shared read per tick
	s.odds = float(odds.odds)
	s.press = 0.0 if brain.data.rank == EnemyData.Rank.BOSS else float(odds.press)   # bosses don't press
	s.effective_respect = BrainScoring.get_effective_respect(s, brain.behavior)
	_read_opening(s, m, target, now)   # AI-D1
	_perceive(s, snap, now)
	_gather_uses(s)
	brain._brain_duel._update_spend(s, snap, now)
	brain._brain_plans._read_plans(s, m, target)   # AI-D2
	s.setup = brain._brain_duel._wants_setup(s)   # AI-D1 (AI-D2: with a plan that fits)
	return s


## The attacks it sees coming at it (ENEMIES_AI.md, Knowledge; AI3): each
## party cast in progress whose effect area covers it (a point-and-click on
## it, a cone, a circle, a line) with its cast time left, each charge-up held
## aimed through it, and each projectile in flight whose path will cross it
## with its time to get there. An attack is perceived once reaction_time has
## passed since it was first seen (no input reading: it reacts to what it
## sees, a beat late); Brains wakes it then.
func _perceive(s: SituationContext, snap: PartySnapshot, now: float) -> void:
	var reaction := brain.behavior.reaction_time
	var still: Dictionary = {}
	for m in snap.members:
		var cast: Dictionary = m.get("cast", {})
		if cast.is_empty() or not (m.unit as Unit).is_enemy_of(brain._enemy):
			continue
		if not Ability.covers_unit(cast.area, brain._enemy):
			continue
		_note_attack(s, cast.key, still, now, reaction, {
			"source": m.unit, "ability": cast.ability, "kind": cast.kind, "area": cast.area,
			"time_to_hit": float(cast.time_left), "dodgeable": false})
	for p in snap.projectiles:
		if int(p.team) == brain._enemy.team:
			continue
		var t := BrainScoring.get_projectile_time_to_hit(p, brain._enemy)
		if t < 0.0:
			continue
		_note_attack(s, p.key, still, now, reaction, {
			"source": p.caster, "ability": p.ability, "kind": &"projectile",
			"area": {"kind": &"segment", "from": p.position, "to": p.position + (p.direction as Vector2) * float(p.range_left_px),
				"half_width": p.half_width_px},
			"time_to_hit": t, "dodgeable": false})
	brain._seen = still


func _note_attack(s: SituationContext, key: String, still: Dictionary, now: float, reaction: float, attack: Dictionary) -> void:
	var first: float = brain._seen.get(key, now)
	still[key] = first
	if not brain._seen.has(key):
		Brains.wake_at(brain, now + reaction)   # it reacts once its reaction time has passed
	var age := now - first
	if age + 0.0001 < reaction:
		return
	attack.age = age
	s.incoming.append(attack)


## Each castable slot (ready, not casting, not blocked, the cost and the
## conditions passing at the plan's aim) whose ability proposes a plan: one
## entry per passing use. Only uses the brain could pick now are gathered
## (asking for plans is most of a think's cost): poke and zone always, its
## hits (damage, gap_close) only while a commit is possible, defend while it
## sees an attack coming, escape while its target is inside its band's
## minimum (AI3). AI-D1: its answers and peels while crowding is at its
## peel_threshold, its openers' uses while the opening is at its opening_bar
## (or its setup's opener is still to come), defend while anything crowds it.
func _gather_uses(s: SituationContext) -> void:
	var abilities := brain._enemy.abilities
	if abilities == null:
		return
	var wanted: Array[StringName] = [EnemyBrain.POKE, &"zone"]
	if s.committing or s.patience >= 1.0 - EnemyBrain.PATIENCE_EPSILON or _patience_full_soon(s):
		wanted.append_array([&"damage", &"gap_close"] as Array[StringName])
	if s.crowded or s.target_edge_distance_px < Units.to_px(brain.behavior.get_crowded_range()) \
			or s.crowding >= brain.behavior.peel_threshold - 0.0001:
		for intent in SituationContext.ANSWER_INTENTS + [EnemyBrain.PEEL]:   # AI3b: its answers, for the crowded roll (AI-D1: its peels)
			if not wanted.has(intent):
				wanted.append(intent)
	if not s.opener_slots.is_empty() and (s.setup_opener or s.opening >= brain.behavior.opening_bar - 0.0001):
		for intent in SituationContext.OPENER_INTENTS:   # AI-D1: a setup's opener
			if not wanted.has(intent):
				wanted.append(intent)
	if not s.incoming.is_empty() or s.crowding > 0.0 or s.target_closed_in:
		wanted.append(EnemyBrain.DEFEND)   # AI-D1: a defend use may read crowding (the duelist's guard); AR3b: or its target closing in (the Riposte Stance)
	if not s.cornered and s.target_edge_distance_px < Units.to_px(brain.behavior.range_band_min):
		wanted.append(EnemyBrain.ESCAPE)
	abilities.set_aim_hint(s.target_position)   # conditions look at the target (AB12)
	for slot in AbilityComponent.SLOTS:
		var ability := abilities.get_ability(slot)
		if ability == null or not abilities.can_cast(slot) or not BrainScoring._has_use_for(ability, wanted):
			continue
		if not brain._brain_duel._perilous_allowed(ability):
			continue   # ARCHETYPES AR2: the perilous gate (before its plan: asking for one costs)
		var plan := ability.get_ai_plan(brain._enemy, s)
		if plan == null:
			continue
		plan.slot = slot
		var aim := plan.vector_start if plan.is_vector() else plan.point
		if abilities.get_fail_reason(slot, aim, plan.target) != "":
			continue
		if not brain._brain_duel._heavy_hit_allowed(ability, plan):
			continue   # AI3c: one heavy hit at a time while pressing (it holds or swings)
		for use in ability.get_ai_uses():
			if use != null and wanted.has(use.intent) and plan.intents.has(use.intent) and use.passes(brain._enemy, s.target_unit, s):
				s.add_use(slot, use.intent, plan, use.weight)


## Crowding's inputs and the read (ComboPlanner.get_crowding()): its crowded
## range and band, its target's walk toward it (the snapshot's walk), its
## target's last gap-closer if it ended inside its band's minimum within
## crowding_recent_time s, and the party's hits on it in the last
## crowding_hit_window s (Brains). `m` is its target's snapshot entry.
func _read_crowding(s: SituationContext, m: Dictionary, target: Unit, now: float) -> void:
	var table := Brains.table
	s.crowded_range_px = Units.to_px(brain.behavior.get_crowded_range())
	s.band_min_px = Units.to_px(brain.behavior.range_band_min)
	s.band_max_px = Units.to_px(brain.behavior.range_band_max)
	s.crowding_closing_full_px = Units.to_px(table.crowding_closing_full)
	s.crowding_hits_full = table.crowding_hits_full
	var to_self := brain._enemy.global_position - target.global_position
	var walk: Vector2 = m.get("walk_velocity", Vector2.ZERO)
	s.target_closing_px = maxf(walk.dot(to_self.normalized()), 0.0) if to_self.length() > 0.01 else 0.0
	var gap: Dictionary = m.get("gap_closer", {})
	if not gap.is_empty() and now - float(gap.at) <= table.crowding_recent_time + 0.0001:
		var end: Vector2 = gap.position
		var edge := end.distance_to(brain._enemy.global_position) - brain._enemy.get_gameplay_radius_px() - target.get_gameplay_radius_px()
		s.target_gap_closer_in = edge < s.band_min_px
	s.recent_hits = Brains.get_recent_hits(brain._enemy, table.crowding_hit_window)
	s.crowding = ComboPlanner.get_crowding(s, table.crowding_weights, s.crowding_terms)


## ARCHETYPES AR3b: its target closed in on it (SituationContext
## .target_closed_in): inside the table's riposte_stance_range, edge to edge,
## or a gap-closer of its ended inside its band's minimum (crowding's read),
## seen for its reaction time (from the moment it first was; Brains wakes it
## then). Never while it commits: its own swings close the gap (D4: the stance
## answers the player closing in). Read only by an enemy whose kit has a use
## that reads it (no other brain thinks differently).
func _read_closed_in(s: SituationContext, now: float) -> void:
	var inside := s.target_edge_distance_px < Units.to_px(Brains.table.riposte_stance_range) or s.target_gap_closer_in
	if not inside or s.committing or not _reads_closed_in():
		brain._closed_in_since = -1.0
		return
	var reaction := brain.behavior.reaction_time
	if brain._closed_in_since < 0.0:
		brain._closed_in_since = now
		Brains.wake_at(brain, now + reaction)
	s.target_closed_in = now - brain._closed_in_since + 0.0001 >= reaction


## One of its abilities has an AI use with a TARGET_CLOSED_IN rule (AR3b).
func _reads_closed_in() -> bool:
	var abilities := brain._enemy.abilities
	if abilities == null:
		return false
	for slot in AbilityComponent.SLOTS:
		var ability := abilities.get_ability(slot)
		if ability == null:
			continue
		for use in ability.get_ai_uses():
			for c in use.conditions:
				if c != null and c.kind == Condition.Kind.TARGET_CLOSED_IN:
					return true
	return false


## The opening's inputs and the read (ComboPlanner.get_opening()): its
## target's escapes (cooldowns: read at once), the longest crowd control on
## it from another unit and its cast in progress (things it reacts to: each
## counts once its reaction time has passed since it first saw it; Brains
## wakes it then), a wall or a ledge just behind it. Its punish window
## (recovering) waits for AI6.
func _read_opening(s: SituationContext, m: Dictionary, target: Unit, now: float) -> void:
	var table := Brains.table
	s.opening_cc_min_left = table.opening_cc_min_left
	var still: Dictionary = {}
	if not m.is_empty():
		s.target_escapes = m.get("escapes", 0)
		s.target_escapes_ready = m.get("escapes_ready", 0)
		var total: float = m.get("escape_value", 0.0)
		s.target_escapes_down = 1.0 - float(m.get("escape_ready_value", 0.0)) / total if total > 0.0 else 0.0
		for cc: Dictionary in m.get("ccs", []):
			if cc.source == brain._enemy:
				continue   # its own crowd control isn't another's
			if not _seen_long_enough(cc.key, still, now):
				continue
			var left: float = cc.left if float(cc.left) >= 0.0 else 999.0   # until removed
			if left > s.target_cc_left:
				s.target_cc_left = left
				s.target_cc_source = cc.source
		var cast: Dictionary = m.get("cast", {})
		if not cast.is_empty():
			s.target_committed = _seen_long_enough("open:" + String(cast.key), still, now)
	brain._seen_open = still
	s.target_recovering = false   # its punish window: AI6
	s.target_cornered = _target_cornered(target)
	s.opening = ComboPlanner.get_opening(s, table.opening_weights, s.opening_terms)


## `key` (a thing it reacts to) has been in view for its reaction time; the
## first sight asks Brains for a think then.
func _seen_long_enough(key: String, still: Dictionary, now: float) -> bool:
	var first: float = brain._seen_open.get(key, now)
	still[key] = first
	if not brain._seen_open.has(key):
		Brains.wake_at(brain, now + brain.behavior.reaction_time)
	return now - first + 0.0001 >= brain.behavior.reaction_time


## A wall or a ledge within cornered_check_px behind its target's edge, on
## the line from this enemy through it (a WorldQuery sweep on the walls' and
## ledges' layers).
func _target_cornered(target: Unit) -> bool:
	var dir := target.global_position - brain._enemy.global_position
	if dir.length() < 0.01:
		return false
	var from := target.global_position
	var to := from + dir.normalized() * (target.get_gameplay_radius_px() + Brains.table.cornered_check_px)
	return not WorldQuery.shape_sweep(from, to, 2.0, MovementComponent.GHOST_KEEP_MASK).is_empty()


## Patience fills by the next think (so the commit's plans are ready on the
## think it fires).
func _patience_full_soon(s: SituationContext) -> bool:
	var step := 1.0 / maxf(brain.get_think_rate(), 0.01)   # AI3c: its own rate
	return s.patience + BrainScoring.get_patience_rate(s, brain.behavior, Brains.table) * step >= 1.0 - EnemyBrain.PATIENCE_EPSILON
