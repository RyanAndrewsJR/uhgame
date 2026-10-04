class_name EnemyBrain
extends UnitController
## An enemy's brain (ENEMIES_AI.md, The brain; AI1): a UnitController child of
## an Enemy whose rank has one, added by Enemy._apply_enemy_data(). Each think
## (about 10 a second, staggered by the Brains autoload) it builds its
## SituationContext (perceive), fills its patience, asks the pure decide() for
## an intent (score), and keeps the decision; every physics tick, while its
## enemy is aggroed, Enemy calls drive(), which carries the intent out through
## the enemy's own components (act): AbilityComponent's casts,
## AutoAttackComponent's attack and MovementComponent's move_to().
## AI1 builds the brute's intents: hold (stand in its range band, circling,
## facing its target), commit (a 0.3 s tell, then go in: its basic attack and
## its damage and gap-closer uses) and poke (cast a poke use from range).
## Fodder has no brain. While a brain runs, the enemy's naive cast loop never
## does (Enemy.naive_casting).
## AI2: a commit needs its attack tokens (Brains: a regular 1, an elite 2 of
## its target's pool); at full patience it asks each think and holds until
## it gets them. It lets them go when its commit ends (then rests
## token_rest_time s), when it doesn't commit after all, or when its target
## is out of reach; Brains takes them back when it's stunned or rooted (its
## commit breaks off, patience kept) or after token_hold_time s. A taunted
## brain commits on its taunter without patience or a token. Its target is
## its enemy's pick (Enemy.get_target(): ALLIES' rules).

signal intent_changed(intent: StringName)
signal pose_changed(pose: StringName)

const HOLD := &"hold"
const POKE := &"poke"
const COMMIT := &"commit"
## The pose an attack intent holds for tell_time before its move (the tell;
## Ryan, I7). AI6 adds punish's and finish's.
const TELL_POSES := {&"commit": &"crouch"}
## The pose each intent shows while it runs (&"" = none: the attack's own look).
const INTENT_POSES := {&"hold": &"hold", &"poke": &"hold"}
## A hold's distance changes only when the target moves this much (px).
const HOLD_SLACK_PX := 8.0
## Patience this close to 1 is full.
const PATIENCE_EPSILON := 0.0001

var data: EnemyData
var rank_rules: RankRules
## The behavior it reads: the preset with this enemy's overrides and every
## adjust applied (EnemyBehavior.resolve()); resolve_behavior() rebuilds it.
var behavior: EnemyBehavior
## Its own random stream, seeded from Brains.rng when it registers, so the
## same seed gives the same decisions.
var rng := RandomNumberGenerator.new()
## Its tick in the think schedule (Brains sets it).
var think_slot: int = 0
## How often Brains has called think() (tests: the schedule).
var think_calls: int = 0

var _enemy: Enemy
var _patience := 0.0
var _intent: StringName = &""
var _intent_started := 0.0
var _last_think := -1.0
var _decision: BrainDecision
var _situation: SituationContext
var _pose: StringName = &""
var _pose_started := 0.0
var _tell_left := 0.0
var _committing := false
var _commit_started := 0.0
var _commit_hits := 0
var _commit_cast := false        # a cast started during the commit (after its tell)
var _commit_cast_done := false   # ... and ended
var _pending_plan: CastPlan
var _replan_left := 0.0
var _strafe_dir := 1.0
var _strafe_turn_left := 0.0
var _back_off_left := 0.0
var _hold_edge := -1.0   # the hold's distance to its target, edge to edge (px); −1 = not set
var _think_usec := 0


func setup(p_data: EnemyData, p_rank_rules: RankRules) -> void:
	data = p_data
	rank_rules = p_rank_rules
	name = "EnemyBrain"


func _ready() -> void:
	_enemy = get_unit() as Enemy
	assert(_enemy != null, "EnemyBrain must be a child of an Enemy")
	resolve_behavior()
	Brains.register(self)
	_strafe_dir = 1.0 if rng.randf() < 0.5 else -1.0
	_strafe_turn_left = _strafe_turn_time()
	_enemy.attack.attack_landed.connect(_on_attack_landed)
	if _enemy.abilities != null:
		_enemy.abilities.cast_started.connect(_on_cast_started)
		_enemy.abilities.cast_finished.connect(_on_cast_ended)
		_enemy.abilities.cast_cancelled.connect(_on_cast_ended)


func _exit_tree() -> void:
	Brains.unregister(self)
	if is_instance_valid(_enemy):
		Brains.release_token(_enemy, false)


## Rebuilds the behavior it reads from its data (the tuning panel calls it
## after a change): the preset's sliders, its overrides, its rank's adjust
## (later the faction's, the difficulty tier's and its elite modifiers'), and
## never a reaction under the floor.
func resolve_behavior() -> void:
	if data == null or data.behavior == null:
		return
	var adjusts: Array[BrainAdjust] = []
	if rank_rules != null and rank_rules.brain_adjust != null:
		adjusts.append(rank_rules.brain_adjust)
	behavior = data.behavior.resolve(data.overrides, adjusts)
	behavior.reaction_time = maxf(behavior.reaction_time, Brains.table.reaction_floor)


# --- Queries (the view, the overlay, tests) ------------------------------------------

func get_intent() -> StringName:
	return _intent


func get_pose() -> StringName:
	return _pose


## The pose's progress (0–1): through the tell for a tell pose, else 1.
func get_pose_progress() -> float:
	if _committing and _tell_left > 0.0:
		var tell := maxf(Brains.table.tell_time, 0.001)
		return clampf(1.0 - _tell_left / tell, 0.0, 1.0)
	return 1.0


func get_last_decision() -> BrainDecision:
	return _decision


func get_situation() -> SituationContext:
	return _situation


func get_patience() -> float:
	return _patience


func is_committing() -> bool:
	return _committing


## Seconds left of the tell before a commit's move (0 = none).
func get_tell_left() -> float:
	return _tell_left if _committing else 0.0


## The last think's cost (microseconds).
func get_think_usec() -> int:
	return _think_usec


## Its attack token, for the overlay: "held", "waiting" (in the queue),
## "rest" (it can't ask yet), "-" (none), or "none needed" (its rank or role
## takes none).
func get_token_state() -> String:
	if not is_instance_valid(_enemy) or Brains.get_token_cost(_enemy) <= 0:
		return "none needed"
	if Brains.has_token(_enemy):
		return "held"
	if Brains.is_waiting_for_token(_enemy):
		return "waiting"
	if Brains.get_token_rest_left(_enemy) > 0.0:
		return "rest"
	return "-"


## Where its enemy faces while the brain runs: its target (Vector2.INF = no
## target: the view faces its walk).
func get_face_point() -> Vector2:
	if _intent == &"":
		return Vector2.INF
	var target := _enemy.get_brain_target()
	return target.global_position if target != null else Vector2.INF


func get_aim_point() -> Vector2:
	return get_face_point()


# --- Think (Brains calls it on its tick) ---------------------------------------------

## Perceive, fill patience, decide, keep the decision. Nothing while its
## enemy isn't aggroed (or is dead, passive, or has no target). True when it
## thought (Brains counts those thinks' cost).
func think() -> bool:
	think_calls += 1
	if not is_instance_valid(_enemy) or behavior == null:
		return false
	if not _enemy.is_brain_active():
		if _intent != &"" or _last_think >= 0.0:
			_reset()
		return false
	var t0 := Time.get_ticks_usec()
	var now := Brains.get_time()
	var dt := now - _last_think if _last_think >= 0.0 else 0.0
	_last_think = now
	if _committing and _is_commit_done(now):
		_end_commit()
	var s := build_situation()
	if not s.has_target:
		_reset()
		_situation = s
		return false
	_check_token_lost(s)
	if not _committing:
		_patience = clampf(_patience + get_patience_rate(s, behavior, Brains.table) * dt, 0.0, 1.0)
		if _patience > 1.0 - PATIENCE_EPSILON:
			_patience = 1.0   # summed float steps fall a hair short of 1
	s.patience = _patience
	s.committing = _committing
	_ask_token(s)
	var d := decide(s, behavior, rng)
	if d.intent != COMMIT and Brains.has_token(_enemy):
		Brains.release_token(_enemy, false)   # it didn't go in after all: no rest
		s.has_token = false
	_apply_decision(d, now)
	_situation = s
	_think_usec = Time.get_ticks_usec() - t0
	return true


## The situation now (ENEMIES_AI.md, SituationContext): itself, its target
## (Enemy.get_brain_target()), the party's respect from the shared snapshot,
## and each castable slot's passing uses with their plans.
func build_situation() -> SituationContext:
	var table := Brains.table
	var s := SituationContext.new()
	s.self_unit = _enemy
	s.rank = data.rank
	s.role = behavior.role
	s.position = _enemy.global_position
	var max_health := _enemy.health.max_health
	s.health_ratio = _enemy.health.current / max_health if max_health > 0.0 else 0.0
	s.attack_reach_px = _enemy.attack.get_range_px()
	s.casting = _enemy.abilities != null and _enemy.abilities.casting
	s.move_blocked = _enemy.is_dash_blocked()
	s.cast_blocked = _enemy.is_cast_blocked()
	s.patience = _patience
	s.intent = _intent
	s.intent_age = Brains.get_time() - _intent_started
	s.committing = _committing
	s.min_intent_time = table.min_intent_time
	s.intent_hold_bonus = table.intent_hold_bonus
	s.intent_scores = table.intent_scores
	s.caster_poke_score = table.caster_poke_score
	s.home_position = _enemy.get_pack_home()
	s.home_distance_px = _enemy.global_position.distance_to(s.home_position)
	s.needs_token = Brains.get_token_cost(_enemy) > 0
	s.has_token = Brains.has_token(_enemy)
	var target := _enemy.get_brain_target()
	if target == null or not target.is_targetable():
		return s
	s.has_target = true
	s.target_unit = target
	s.target_position = target.global_position
	s.target_edge_distance_px = _enemy.edge_distance_to(target)
	s.target_in_sight = WorldQuery.has_line_of_sight(_enemy.global_position, target.global_position)
	s.target_reachable = _enemy.is_target_reachable()
	s.taunted = _enemy.get_taunter() == target
	s.tokens_free = Brains.get_tokens_free(target)
	var snap := Brains.get_snapshot()
	s.party_size = snap.members.size()
	var target_share := 0.0
	var m := snap.get_member(target)
	if not m.is_empty():
		s.target_health_ratio = m.health_ratio
		s.target_kit_ready = m.kit_ready
		s.target_idle_time = m.idle_time
		target_share = m.share
	else:
		var target_max := target.health.max_health
		s.target_health_ratio = target.health.current / target_max if target_max > 0.0 else 0.0
	var others: Array[float] = []
	for o in snap.members:
		if o.unit == target or not o.up:
			continue
		if _enemy.global_position.distance_to(o.position) <= table.ally_respect_range_px:
			others.append(o.share)
	s.respect = PartySnapshot.combine_respect(target_share, others, table.ally_respect_weight)
	s.effective_respect = clampf(s.respect * behavior.respect_weight, 0.0, 1.0)
	_gather_uses(s)
	return s


## Each castable slot (ready, not casting, not blocked, the cost and the
## conditions passing at the plan's aim) whose ability proposes a plan: one
## entry per passing use. Only uses the brain could pick now are gathered
## (asking for plans is most of a think's cost): poke and zone always, its
## hits (damage, gap_close) only while a commit is possible.
func _gather_uses(s: SituationContext) -> void:
	var abilities := _enemy.abilities
	if abilities == null:
		return
	var wanted: Array[StringName] = [POKE, &"zone"]
	if s.committing or s.patience >= 1.0 - PATIENCE_EPSILON or _patience_full_soon(s):
		wanted.append_array([&"damage", &"gap_close"] as Array[StringName])
	abilities.set_aim_hint(s.target_position)   # conditions look at the target (AB12)
	for slot in AbilityComponent.SLOTS:
		var ability := abilities.get_ability(slot)
		if ability == null or not abilities.can_cast(slot) or not _has_use_for(ability, wanted):
			continue
		var plan := ability.get_ai_plan(_enemy, s)
		if plan == null:
			continue
		plan.slot = slot
		var aim := plan.vector_start if plan.is_vector() else plan.point
		if abilities.get_fail_reason(slot, aim, plan.target) != "":
			continue
		for use in ability.get_ai_uses():
			if use != null and wanted.has(use.intent) and plan.intents.has(use.intent) and use.passes(_enemy, s.target_unit, s):
				s.add_use(slot, use.intent, plan, use.weight)


static func _has_use_for(ability: Ability, intents: Array[StringName]) -> bool:
	for use in ability.get_ai_uses():
		if use != null and intents.has(use.intent):
			return true
	return false


## Its tokens went while it committed (Brains: it's stunned or rooted, or it
## held them token_hold_time s; or its target changed): a stun breaks the
## commit off and keeps its patience (it asks again after its rest), anything
## else ends it (patience empties). A commit on a taunt holds no token: it
## ends when the taunt does.
func _check_token_lost(s: SituationContext) -> void:
	if not _committing or not s.needs_token or s.taunted or Brains.has_token(_enemy):
		return
	if _enemy.is_cc_blocked():
		_break_commit()
	else:
		_end_commit()
	s.has_token = false


## Patience full (and not committing yet): it asks for its tokens on its
## target each think (Brains' queue). Out of reach, it lets them go (Groups).
func _ask_token(s: SituationContext) -> void:
	if not s.needs_token:
		return
	if not s.target_reachable:
		if Brains.has_token(_enemy):
			Brains.release_token(_enemy, false)
		s.has_token = false
	elif not s.has_token and not _committing and not s.taunted and _patience >= 1.0:
		s.has_token = Brains.request_token(_enemy, s.target_unit, _patience)
	s.waiting_for_token = Brains.is_waiting_for_token(_enemy)
	s.tokens_free = Brains.get_tokens_free(s.target_unit)


## Patience fills by the next think (so the commit's plans are ready on the
## think it fires).
func _patience_full_soon(s: SituationContext) -> bool:
	var step := 1.0 / maxf(Brains.table.think_rate, 0.01)
	return s.patience + get_patience_rate(s, behavior, Brains.table) * step >= 1.0 - PATIENCE_EPSILON


# --- Decide (pure) ------------------------------------------------------------------

## The decision (ENEMIES_AI.md, Scoring), a pure function of the situation,
## the resolved behavior and a seeded generator: nothing else is read. Every
## intent the situation allows gets its base score × the behavior's intent
## weight × (1 ± jitter); the current intent gets the hold bonus until
## min_intent_time; the highest wins. AI1: hold (always), poke (a poke use
## passes; a caster's scores higher), commit (patience full with its tokens
## (AI2: or none needed), a commit under way, or a taunt on its target).
static func decide(s: SituationContext, b: EnemyBehavior, rng: RandomNumberGenerator) -> BrainDecision:
	var d := BrainDecision.new()
	if not s.has_target:
		d.reason = "no target"
		return d
	var raw := {}
	raw[HOLD] = float(s.intent_scores.get(HOLD, 0.0))
	var poke := s.get_best_use([POKE])
	if not poke.is_empty():
		raw[POKE] = s.caster_poke_score if b.role == EnemyBehavior.Role.CASTER else float(s.intent_scores.get(POKE, 0.0))
	var tokens_ok := s.has_token or not s.needs_token
	if s.target_reachable and (s.committing or s.taunted or (s.patience >= 1.0 and tokens_ok)):
		raw[COMMIT] = float(s.intent_scores.get(COMMIT, 0.0))
	var best: StringName = &""
	var best_score := -INF
	for intent: StringName in raw:   # hold, poke, commit: a tie keeps the earlier
		var score: float = raw[intent] * b.get_intent_weight(intent) * (1.0 + rng.randf_range(-b.jitter, b.jitter))
		if intent == s.intent and s.intent_age < s.min_intent_time:
			score += s.intent_hold_bonus
		d.scores[intent] = score
		if score > best_score:
			best = intent
			best_score = score
	d.intent = best
	match best:
		POKE:
			d.plan = poke.plan
		COMMIT:
			# Its hits: damage uses, and a gap-closer while out of its reach.
			var intents: Array[StringName] = [&"damage"]
			if s.target_edge_distance_px > s.attack_reach_px:
				intents.append(&"gap_close")
			var use := s.get_best_use(intents)
			if not use.is_empty():
				d.plan = use.plan
		HOLD:
			var zone := s.get_best_use([&"zone"])
			if not zone.is_empty():
				d.plan = zone.plan
	if best in TELL_POSES and s.intent != best:
		d.pose = TELL_POSES[best]   # a new attack starts with its tell
	else:
		d.pose = INTENT_POSES.get(best, &"")
	d.reason = "%s %.2f  patience %.2f  respect %.2f" % [best, best_score, s.patience, s.effective_respect]
	return d


## How fast patience fills (per second; ENEMIES_AI.md, The standoff): (1 −
## patience_respect_cut × effective respect) ÷ patience_time × (0.5 +
## aggression) × pressure. Pressure is 1, plus idle_pressure while the target
## has been idle idle_time s, plus low_pressure while it's below low_health.
## So with everything up it still fills, at a quarter of its speed: a brute
## (3 s, aggression 0.5) comes in 12 s at the latest.
static func get_patience_rate(s: SituationContext, b: EnemyBehavior, table: EnemyAITable) -> float:
	var pressure := 1.0
	if s.target_idle_time >= table.idle_time:
		pressure += table.idle_pressure
	if s.target_health_ratio < table.low_health:
		pressure += table.low_pressure
	return (1.0 - table.patience_respect_cut * s.effective_respect) / maxf(b.patience_time, 0.01) \
		* (0.5 + b.aggression) * pressure


# --- Act (Enemy calls drive() every physics tick while aggroed) -------------------------

func _apply_decision(d: BrainDecision, now: float) -> void:
	if d.intent != _intent:
		var was := _intent
		_intent = d.intent
		_intent_started = now
		if not (d.intent in INTENT_POSES and was in INTENT_POSES):
			_hold_edge = -1.0   # a new hold measures its distance again (poke keeps hold's)
		if was == COMMIT and _committing:
			_committing = false   # broken off (not done): patience stays
			_tell_left = 0.0
		if d.intent == COMMIT:
			_start_commit(now)
		intent_changed.emit(d.intent)
	_pending_plan = d.plan
	_decision = d
	_update_pose(now)


## Carries out the current intent: its movement and presses (cheap, every
## tick), then the decision's cast. Nothing while a cast plays out or while
## stunned.
func drive(delta: float) -> void:
	_back_off_left = maxf(_back_off_left - delta, 0.0)
	var target := _enemy.get_brain_target()
	if target == null or _intent == &"":
		return
	if _enemy.is_stunned() or (_enemy.abilities != null and _enemy.abilities.casting):
		return
	match _intent:
		COMMIT:
			_drive_commit(delta, target)
		HOLD, POKE:
			_drive_hold(delta, target)
	_try_plan()
	_update_pose(Brains.get_time())


## Commit: stand in the tell for tell_time, then go in with the basic attack
## (AutoAttackComponent chases and swings); its casts come from the plans.
func _drive_commit(delta: float, target: Unit) -> void:
	if _tell_left > 0.0:
		_tell_left = maxf(_tell_left - delta, 0.0)
		_enemy.movement.stop()
		if _enemy.attack.target != null and not _enemy.attack.is_winding_up():
			_enemy.attack.cancel()
		return
	if _enemy.attack.target != target:
		_enemy.attack.attack(target)


## Hold: a spot in its range band around the target, strafing one way and
## turning after strafe_turn_min–max s, facing the target (the view). It keeps
## a hold distance (edge to edge): its distance when the hold starts, kept in
## the band; from farther than the band it closes to the band's far edge;
## when the target walks away it follows, back into the band; after its own
## commit it walks back out to the band (back_off_time); when its target
## walks in on it, it doesn't run: it holds its ground at that distance and
## swings back once the target is in its reach. Each re-plan aims at the
## circle of that distance, so strafing along chords never spirals it in.
func _drive_hold(delta: float, target: Unit) -> void:
	var table := Brains.table
	var edge := _enemy.edge_distance_to(target)
	if _back_off_left <= 0.0 and edge <= _enemy.attack.get_range_px():
		if _enemy.attack.target != target:
			_enemy.attack.attack(target)
		return
	if _enemy.attack.target != null and not _enemy.attack.is_winding_up():
		_enemy.attack.cancel()
	_replan_left -= delta
	if _replan_left > 0.0 and _enemy.movement.has_order():
		return
	_replan_left = table.hold_replan_time
	_strafe_turn_left -= table.hold_replan_time
	if _strafe_turn_left <= 0.0:
		_strafe_dir = -_strafe_dir
		_strafe_turn_left = _strafe_turn_time()
	var band_min := Units.to_px(behavior.range_band_min)
	var band_max := Units.to_px(behavior.range_band_max)
	var to_self := _enemy.global_position - target.global_position
	var pressing := target.velocity.dot(to_self.normalized()) > Brains.IDLE_SPEED_PX if to_self.length() > 0.01 else false
	if _hold_edge < 0.0:
		_hold_edge = clampf(edge, band_min, band_max)
	if _back_off_left > 0.0:
		_hold_edge = maxf(_hold_edge, band_min)
	elif edge > band_max:
		_hold_edge = band_max
	elif pressing and edge < _hold_edge - HOLD_SLACK_PX:
		_hold_edge = edge   # it walked in: hold the ground here
	elif edge > _hold_edge + HOLD_SLACK_PX:
		_hold_edge = clampf(edge, band_min, band_max)   # it walked away: follow, in the band
	var radii := _enemy.get_gameplay_radius_px() + target.get_gameplay_radius_px()
	var radius := maxf(_hold_edge + radii, radii + 1.0)
	var from_target := _enemy.global_position - target.global_position
	var angle := from_target.angle() if from_target.length() > 0.01 else rng.randf() * TAU
	angle += _strafe_dir * table.strafe_step_px / radius
	_enemy.movement.move_to(target.global_position + Vector2.from_angle(angle) * radius)


## Casts the decision's plan once (after a commit's tell; never mid-windup or
## mid-cast), checked again first so a plan that went stale fails quietly.
func _try_plan() -> void:
	if _pending_plan == null or (_committing and _tell_left > 0.0):
		return
	var abilities := _enemy.abilities
	if abilities == null or abilities.casting or _enemy.attack.is_winding_up():
		return
	var plan := _pending_plan
	_pending_plan = null
	if plan.target != null and not is_instance_valid(plan.target):
		return
	var aim := plan.vector_start if plan.is_vector() else plan.point
	if abilities.get_fail_reason(plan.slot, aim, plan.target) != "":
		return
	abilities.set_aim_hint(plan.point)
	if plan.is_vector():
		abilities.try_cast_vector(plan.slot, plan.vector_start, plan.vector_direction)
	else:
		abilities.try_cast(plan.slot, plan.point, plan.target)


func _start_commit(now: float) -> void:
	_committing = true
	_commit_started = now
	_commit_hits = 0
	_commit_cast = false
	_commit_cast_done = false
	_tell_left = Brains.table.tell_time


## A commit is done after its first cast ended, commit_hits landed basic
## attacks, or commit_max_time (the tell included).
func _is_commit_done(now: float) -> bool:
	var table := Brains.table
	return _commit_cast_done or _commit_hits >= table.commit_hits or now - _commit_started >= table.commit_max_time


## A commit that's done empties patience, and it walks back out to its band.
## Its tokens go, and it rests token_rest_time s before it may ask again.
func _end_commit() -> void:
	_committing = false
	_patience = 0.0
	_tell_left = 0.0
	_pending_plan = null
	_back_off_left = Brains.table.back_off_time
	Brains.release_token(_enemy, true)


## A commit broken off (stunned: its token went): patience stays, so it asks
## again once its rest is over.
func _break_commit() -> void:
	_committing = false
	_tell_left = 0.0
	_pending_plan = null


func _update_pose(now: float) -> void:
	var pose: StringName = &""
	if _committing and _tell_left > 0.0:
		pose = TELL_POSES.get(COMMIT, &"")
	else:
		pose = INTENT_POSES.get(_intent, &"")
	if pose != _pose:
		_pose = pose
		_pose_started = now
		pose_changed.emit(pose)


## Out of the fight (de-aggroed, no target): everything back to the start.
func _reset() -> void:
	var had_intent := _intent != &""
	_intent = &""
	_committing = false
	_patience = 0.0
	_tell_left = 0.0
	_pending_plan = null
	_back_off_left = 0.0
	_hold_edge = -1.0
	_last_think = -1.0
	_decision = null
	if is_instance_valid(_enemy):
		Brains.release_token(_enemy, false)
	if had_intent:
		intent_changed.emit(_intent)
	_update_pose(Brains.get_time())


func _strafe_turn_time() -> float:
	var table := Brains.table
	return rng.randf_range(table.strafe_turn_min, table.strafe_turn_max)


func _on_attack_landed(_target: Unit, _damage: float) -> void:
	if _committing and _tell_left <= 0.0:
		_commit_hits += 1


func _on_cast_started(_slot: StringName, _ability: Ability, _ctx: CastContext) -> void:
	if _committing and _tell_left <= 0.0:
		_commit_cast = true


func _on_cast_ended(_slot: StringName, _ability: Ability) -> void:
	if _committing and _commit_cast:
		_commit_cast_done = true
