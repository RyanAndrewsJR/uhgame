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
## AI3, the skirmisher and the caster:
## - it sees attacks coming at it (the party's casts in progress by their
##   Ability.get_effect_area(), charge-ups, projectiles in flight), each
##   perceived once its reaction time has passed (SituationContext.incoming;
##   Brains wakes it then);
## - defend: a defend use (its rule THREATENED) beats everything but its
##   target leaving;
## - escape: its target inside its band's minimum, for a caster (or anyone with
##   an escape use): its escape ability, else it walks away for up to
##   escape_walk_time; blocked, slowed, rooted or out of time, it's cornered:
##   it squares up and fights (its basic attack, its pokes) and doesn't run
##   again for cornered_time;
## - retreat: a caster below its retreat health falls back behind its nearest
##   melee packmate and keeps poking; a skirmisher's reset after its hit;
## - a caster holds behind or beside its melee packmates, 2 m from other
##   casters; a caster never commits (its preset's commit weight is 0);
## - a skirmisher's commit ends at its first landed hit (its gap-closer's
##   included), or reset_time after it got to its target; then it hops back,
##   keeps half its patience and walks out to its band.
## AI3b, the duel (ENEMIES_AI.md, Duels and odds):
## - its key ability (its ultimate, else its highest respect value, ties to the
##   earlier slot): while it's ready the enemy reads its own kit as it reads
##   yours, and effective respect × (1 − confidence × its own kit ready); once
##   it's spent it's cautious for cautious_time (or until the key is ready):
##   patience fills slower and its commit's end walks it out to its band's far
##   edge (a retreat, step_back);
## - spend_eagerness: outside a right moment (its target crowd-controlled,
##   below its finish threshold, every defensive down, crowded, two champions
##   in the key's area) the key's damage, cc and zone uses are held unless a
##   roll every spend_roll_time s frees it; a poke is never held;
## - crowded: its target coming inside its crowded_range (seen after its
##   reaction time, never while it commits) starts an episode with one roll:
##   cornered and escape first, else with an answer ready crowded_commit all
##   in (patience full at once), else the mix (Ryan): back up once (the
##   kiting step, chance 1 − aggression) or stand and swing; it lasts until
##   the target has stayed out crowded_clear_time s;
## - smell blood: below its finish threshold commit × smell_blood_mult,
##   capped; the target's ready defensives keep their full respect value then;
## - aim lead: the situation carries the target's walk and its aim_lead for
##   the plans (Ability.get_led_point()).

signal intent_changed(intent: StringName)
signal pose_changed(pose: StringName)

const HOLD := &"hold"
const POKE := &"poke"
const COMMIT := &"commit"
const DEFEND := &"defend"
const ESCAPE := &"escape"
const RETREAT := &"retreat"
## A crowded episode's outcomes (AI3b).
const ALL_IN := &"all_in"
const BACK_UP := &"back_up"
const STAND := &"stand"
const CORNERED := &"cornered"
## The pose an attack intent holds for tell_time before its move (the tell;
## Ryan, I7). AI6 adds punish's and finish's.
const TELL_POSES := {&"commit": &"crouch"}
## The brute's pose for each intent while it runs (AI1; get_intent_pose() has
## every role's).
const INTENT_POSES := {&"hold": &"hold", &"poke": &"hold"}
## The intents that move like a hold (its distance in the band, kept from one
## to the next).
const HOLD_INTENTS: Array[StringName] = [&"hold", &"poke", &"defend"]
## A hold's distance changes only when the target moves this much (px).
const HOLD_SLACK_PX := 8.0
## Patience this close to 1 is full.
const PATIENCE_EPSILON := 0.0001
## Falling back, it stands this far behind its melee packmate (px, edge to edge).
const FALL_BACK_GAP_PX := 16.0
## Walking away, it counts as blocked once it has barely moved for this long (s).
const ESCAPE_STUCK_TIME := 0.3

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
var _commit_ability_hits := 0    # hits its casts landed during the commit (AI3)
var _commit_cast := false        # a cast started during the commit (after its tell)
var _commit_cast_done := false   # ... and ended (a gap-closer's doesn't count)
var _commit_engaged_at := -1.0   # when it got to its target in the commit (−1 = not yet)
var _pending_plan: CastPlan
var _replan_left := 0.0
var _strafe_dir := 1.0
var _strafe_turn_left := 0.0
var _back_off_left := 0.0
var _hold_edge := -1.0   # the hold's distance to its target, edge to edge (px); −1 = not set
var _think_usec := 0
# AI3
var _seen: Dictionary = {}       # an attack's key -> the game time it was first seen
var _cornered_until := -1.0
var _escaping := false
var _escape_until := 0.0
var _escape_stuck := 0.0
var _escape_last_pos := Vector2.INF
var _resetting_until := -1.0
# AI3b
var _key_slot: StringName = &""
var _cautious_until := -1.0
var _spend_free := false         # the last spend roll freed its key
var _next_spend_roll := -1.0     # −1 = roll at the next think that holds it
var _crowded_target: Unit
var _crowded_seen := -1.0        # when its target came inside (−1 = it isn't)
var _episode := false
var _episode_needs_roll := false
var _crowded_roll: StringName = &""
var _crowded_roll_value := -1.0  # the roll that decided it (the overlay)
var _crowded_answer := false
var _outside_since := -1.0
var _walking_out_until := -1.0
var _walk_out_far := false
var _last_lead_px := 0.0


func setup(p_data: EnemyData, p_rank_rules: RankRules) -> void:
	data = p_data
	rank_rules = p_rank_rules
	name = "EnemyBrain"


func _ready() -> void:
	_enemy = get_unit() as Enemy
	assert(_enemy != null, "EnemyBrain must be a child of an Enemy")
	resolve_behavior()
	_key_slot = find_key_slot(_enemy.abilities, Brains.table)   # AI3b (each think finds it again)
	Brains.register(self)
	_strafe_dir = 1.0 if rng.randf() < 0.5 else -1.0
	_strafe_turn_left = _strafe_turn_time()
	_enemy.attack.attack_landed.connect(_on_attack_landed)
	if _enemy.abilities != null:
		_enemy.abilities.cast_started.connect(_on_cast_started)
		_enemy.abilities.cast_finished.connect(_on_cast_ended)
		_enemy.abilities.cast_cancelled.connect(_on_cast_ended)
	Events.unit_damaged.connect(_on_unit_damaged)


func _exit_tree() -> void:
	Brains.unregister(self)
	if is_instance_valid(_enemy):
		Brains.release_token(_enemy, false)
	if Events.unit_damaged.is_connected(_on_unit_damaged):
		Events.unit_damaged.disconnect(_on_unit_damaged)


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


## Cornered (a caster squared up, AI3): it fights and doesn't run.
func is_cornered() -> bool:
	return Brains.get_time() < _cornered_until


## Walking away from its target on foot (an escape with no escape ability).
func is_escaping() -> bool:
	return _escaping


## A skirmisher's reset after its hit (it retreats out to its band).
func is_resetting() -> bool:
	return Brains.get_time() < _resetting_until


## Its key ability's slot (AI3b; &"" = none).
func get_key_slot() -> StringName:
	return _key_slot


## Cautious after spending its key (AI3b), and for how long still (s).
func is_cautious() -> bool:
	return Brains.get_time() < _cautious_until


func get_cautious_left() -> float:
	return maxf(_cautious_until - Brains.get_time(), 0.0)


## Its key held by spend_eagerness at the last think (AI3b).
func is_key_held() -> bool:
	return _situation != null and _situation.held_slot != &""


## Seconds before its next spend roll (0 = at the next think that holds it).
func get_spend_roll_left() -> float:
	return maxf(_next_spend_roll - Brains.get_time(), 0.0)


## A crowded episode is on (AI3b), and its roll (&"" = none yet).
func is_crowded() -> bool:
	return _episode


func get_crowded_roll() -> StringName:
	return _crowded_roll


## The roll that decided the episode (−1 = none: cornered or escaping), and
## whether it had an answer ready (the overlay).
func get_crowded_roll_value() -> float:
	return _crowded_roll_value


func had_crowded_answer() -> bool:
	return _crowded_answer


## How far its last cast's aim led its target (px; AI3b, aim_lead).
func get_last_lead_px() -> float:
	return _last_lead_px


## Walking back out (AI3b: the crowded kiting step, or a cautious walk to its
## band's far edge after a commit).
func is_walking_out() -> bool:
	return Brains.get_time() < _walking_out_until


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
	if _episode_needs_roll:
		_roll_episode(s, now)
	s.patience = _patience
	s.committing = _committing
	s.walking_out = is_walking_out()
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
## the attacks it sees coming (AI3), and each castable slot's passing uses
## with their plans.
func build_situation() -> SituationContext:
	var table := Brains.table
	var now := Brains.get_time()
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
	s.intent_age = now - _intent_started
	s.committing = _committing
	s.min_intent_time = table.min_intent_time
	s.intent_hold_bonus = table.intent_hold_bonus
	s.intent_scores = table.intent_scores
	s.caster_poke_score = table.caster_poke_score
	s.home_position = _enemy.get_pack_home()
	s.home_distance_px = _enemy.global_position.distance_to(s.home_position)
	s.needs_token = Brains.get_token_cost(_enemy) > 0
	s.has_token = Brains.has_token(_enemy)
	s.cornered = now < _cornered_until
	s.resetting = now < _resetting_until
	# AI3b: its key ability and its own kit; cautious; the numbers decide() reads.
	_key_slot = find_key_slot(_enemy.abilities, table)
	s.key_slot = _key_slot
	s.key_ready = _key_slot != &"" and _is_slot_ready(_key_slot)
	if s.key_ready:
		_cautious_until = -1.0   # its key is back: no longer cautious
	s.own_ready_share = get_own_ready_share(_enemy.abilities, table, _key_slot)
	s.cautious_left = maxf(_cautious_until - now, 0.0)
	s.walking_out = now < _walking_out_until
	s.aim_lead = behavior.aim_lead
	s.smell_blood_mult = table.smell_blood_mult
	s.smell_blood_cap = table.smell_blood_cap
	s.spend_min_champions = table.spend_min_champions
	var target := _enemy.get_brain_target()
	if target == null or not target.is_targetable():
		return s
	s.has_target = true
	s.target_unit = target
	s.target_position = target.global_position
	s.target_edge_distance_px = _enemy.edge_distance_to(target)
	s.target_cc = target.status_component != null and target.status_component.has_tag(&"cc")
	_update_episode(s, target, now)
	s.target_in_sight = WorldQuery.has_line_of_sight(_enemy.global_position, target.global_position)
	s.target_reachable = _enemy.is_target_reachable()
	s.taunted = _enemy.get_taunter() == target
	s.tokens_free = Brains.get_tokens_free(target)
	if _escaping and s.target_edge_distance_px >= Units.to_px(behavior.range_band_min):
		_escaping = false   # it got away
	s.escaping = _escaping
	var snap := Brains.get_snapshot()
	s.party_size = snap.members.size()
	var target_share := 0.0
	var m := snap.get_member(target)
	if not m.is_empty():
		s.target_health_ratio = m.health_ratio
		s.target_kit_ready = m.kit_ready
		s.target_idle_time = m.idle_time
		target_share = PartySnapshot.get_share_for(m, behavior.finish_threshold)   # AI3b: a panic button still counts
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
		if _enemy.global_position.distance_to(o.position) <= table.ally_respect_range_px:
			others.append(PartySnapshot.get_share_for(o, behavior.finish_threshold))
	s.respect = PartySnapshot.combine_respect(target_share, others, table.ally_respect_weight)
	s.effective_respect = get_effective_respect(s, behavior)
	_perceive(s, snap, now)
	_gather_uses(s)
	_update_spend(s, snap, now)
	return s


## The attacks it sees coming at it (ENEMIES_AI.md, Knowledge; AI3): each
## party cast in progress whose effect area covers it (a point-and-click on
## it, a cone, a circle, a line) with its cast time left, each charge-up held
## aimed through it, and each projectile in flight whose path will cross it
## with its time to get there. An attack is perceived once reaction_time has
## passed since it was first seen (no input reading: it reacts to what it
## sees, a beat late); Brains wakes it then.
func _perceive(s: SituationContext, snap: PartySnapshot, now: float) -> void:
	var reaction := behavior.reaction_time
	var still: Dictionary = {}
	for m in snap.members:
		var cast: Dictionary = m.get("cast", {})
		if cast.is_empty() or not (m.unit as Unit).is_enemy_of(_enemy):
			continue
		if not Ability.covers_unit(cast.area, _enemy):
			continue
		_note_attack(s, cast.key, still, now, reaction, {
			"source": m.unit, "ability": cast.ability, "kind": cast.kind, "area": cast.area,
			"time_to_hit": float(cast.time_left), "dodgeable": false})
	for p in snap.projectiles:
		if int(p.team) == _enemy.team:
			continue
		var t := get_projectile_time_to_hit(p, _enemy)
		if t < 0.0:
			continue
		_note_attack(s, p.key, still, now, reaction, {
			"source": p.caster, "ability": p.ability, "kind": &"projectile",
			"area": {"kind": &"segment", "from": p.position, "to": p.position + (p.direction as Vector2) * float(p.range_left_px),
				"half_width": p.half_width_px},
			"time_to_hit": t, "dodgeable": false})
	_seen = still


func _note_attack(s: SituationContext, key: String, still: Dictionary, now: float, reaction: float, attack: Dictionary) -> void:
	var first: float = _seen.get(key, now)
	still[key] = first
	if not _seen.has(key):
		Brains.wake_at(self, now + reaction)   # it reacts once its reaction time has passed
	var age := now - first
	if age + 0.0001 < reaction:
		return
	attack.age = age
	s.incoming.append(attack)


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


## Each castable slot (ready, not casting, not blocked, the cost and the
## conditions passing at the plan's aim) whose ability proposes a plan: one
## entry per passing use. Only uses the brain could pick now are gathered
## (asking for plans is most of a think's cost): poke and zone always, its
## hits (damage, gap_close) only while a commit is possible, defend while it
## sees an attack coming, escape while its target is inside its band's
## minimum (AI3).
func _gather_uses(s: SituationContext) -> void:
	var abilities := _enemy.abilities
	if abilities == null:
		return
	var wanted: Array[StringName] = [POKE, &"zone"]
	if s.committing or s.patience >= 1.0 - PATIENCE_EPSILON or _patience_full_soon(s):
		wanted.append_array([&"damage", &"gap_close"] as Array[StringName])
	if s.crowded or s.target_edge_distance_px < Units.to_px(behavior.get_crowded_range()):
		for intent in SituationContext.ANSWER_INTENTS:   # AI3b: its answers, for the crowded roll
			if not wanted.has(intent):
				wanted.append(intent)
	if not s.incoming.is_empty():
		wanted.append(DEFEND)
	if not s.cornered and s.target_edge_distance_px < Units.to_px(behavior.range_band_min):
		wanted.append(ESCAPE)
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


# --- Duels and odds (AI3b) ----------------------------------------------------------

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
## respect_weight × (1 − confidence × its own kit ready), clamped 0–1. AI3c
## adds × (1 − nerve × the press).
static func get_effective_respect(s: SituationContext, b: EnemyBehavior) -> float:
	return clampf(s.respect * b.respect_weight * (1.0 - b.confidence * s.own_ready_share), 0.0, 1.0)


func _is_slot_ready(slot: StringName) -> bool:
	var abilities := _enemy.abilities
	return abilities != null and abilities.get_ability(slot) != null and abilities.is_ready(slot) and abilities.can_afford(slot)


## The crowded episode (ENEMIES_AI.md, Crowded): it starts once its target
## has been inside its crowded range for its reaction time (it's reacting to
## you; never while it commits or walks back out after a commit: its own
## dive brings it close), with one roll
## (think() rolls it, once the uses are gathered). It lasts until the target
## has stayed crowded_clear_px outside it for crowded_clear_time s; a new
## target ends it.
func _update_episode(s: SituationContext, target: Unit, now: float) -> void:
	var table := Brains.table
	if target != _crowded_target:
		_end_episode()
		_crowded_target = target
	var crowded_px := Units.to_px(behavior.get_crowded_range())
	if s.target_edge_distance_px < crowded_px:
		_outside_since = -1.0
		if not _episode:
			if _committing or _back_off_left > 0.0:
				_crowded_seen = -1.0   # its own dive (or its walk out after one) brought it close
			elif _crowded_seen < 0.0:
				_crowded_seen = now
				Brains.wake_at(self, now + behavior.reaction_time)
			elif now - _crowded_seen + 0.0001 >= behavior.reaction_time:
				_episode = true
				_episode_needs_roll = true
	else:
		if not _episode:
			_crowded_seen = -1.0
		elif s.target_edge_distance_px >= crowded_px + table.crowded_clear_px:
			if _outside_since < 0.0:
				_outside_since = now
			elif now - _outside_since + 0.0001 >= table.crowded_clear_time:
				_end_episode()
		else:
			_outside_since = -1.0
	s.crowded = _episode
	s.crowded_roll = _crowded_roll


func _end_episode() -> void:
	_episode = false
	_episode_needs_roll = false
	_crowded_roll = &""
	_crowded_roll_value = -1.0
	_crowded_answer = false
	_crowded_seen = -1.0
	_outside_since = -1.0


## The episode's one roll, carried out: all in fills patience at once (a melee
## role then commits, its tell first, on its token; with none free it holds
## its ground and swings, first in the queue); backing up starts the kiting
## step. Standing, escaping and the cornered stand need nothing more: the
## rules already built play them.
func _roll_episode(s: SituationContext, now: float) -> void:
	_episode_needs_roll = false
	var r := roll_crowded(s, behavior, rng)
	_crowded_roll = r.result
	_crowded_roll_value = r.roll
	_crowded_answer = r.answer
	s.crowded_roll = _crowded_roll
	match _crowded_roll:
		ALL_IN:
			if behavior.role != EnemyBehavior.Role.CASTER:
				_patience = 1.0
		BACK_UP:
			_start_walk_out(now, false)


## One crowded episode's roll (ENEMIES_AI.md, Crowded; pure, seeded), in
## order: cornered (the cornered stand wins); escape (a caster, or any role
## with a passing escape use); an answer ready: crowded_commit to go all in;
## else (no answer, or that roll failed) the mix, Ryan's: back up once with
## the chance 1 − aggression, otherwise stand and swing. {result, roll (the
## roll that decided it, −1 = none), answer (it had one)}. `stream` is the
## brain's rng.
static func roll_crowded(s: SituationContext, b: EnemyBehavior, stream: RandomNumberGenerator) -> Dictionary:
	var answer := s.has_answer()
	if s.cornered:
		return {"result": CORNERED, "roll": -1.0, "answer": answer}
	if wants_escape(s, b, s.has_use([ESCAPE] as Array[StringName])):
		return {"result": ESCAPE, "roll": -1.0, "answer": answer}
	if answer:
		var roll := stream.randf()
		if roll < b.crowded_commit:
			return {"result": ALL_IN, "roll": roll, "answer": true}
	var mix := stream.randf()
	return {"result": BACK_UP if mix < 1.0 - b.aggression else STAND, "roll": mix, "answer": answer}


## Walking back out (a retreat, step_back): the crowded kiting step toward its
## band, or (far) a cautious walk to its band's far edge after a commit, for
## back_off_time s; then it holds its ground (AI1's rule).
func _start_walk_out(now: float, far: bool) -> void:
	var table := Brains.table
	_walking_out_until = now + table.back_off_time
	_walk_out_far = far
	_back_off_left = table.back_off_time
	_hold_edge = -1.0
	Brains.wake(self)


## Spending the key ability (ENEMIES_AI.md): at a right moment it's free;
## otherwise a roll against spend_eagerness every spend_roll_time s while it
## holds the key frees it (until the next roll) or holds it: then its key's
## damage, cc and zone uses aren't picked (SituationContext.held_slot). Its
## key down: the roll waits until it's ready again.
func _update_spend(s: SituationContext, snap: PartySnapshot, now: float) -> void:
	if s.key_slot == &"" or not s.key_ready:
		_spend_free = false
		_next_spend_roll = -1.0
		return
	s.key_area_champions = _key_area_champions(s, snap)
	s.right_moment_reason = get_right_moment(s, behavior)
	s.right_moment = s.right_moment_reason != ""
	if s.right_moment:
		return
	if _next_spend_roll < 0.0 or now >= _next_spend_roll - 0.0001:
		_spend_free = rng.randf() < behavior.spend_eagerness
		_next_spend_roll = now + Brains.table.spend_roll_time
	if not _spend_free:
		s.held_slot = s.key_slot


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


## The champions its key's gathered plan would cover (0 with one champion,
## or no plan for it gathered).
func _key_area_champions(s: SituationContext, snap: PartySnapshot) -> int:
	if snap.members.size() < s.spend_min_champions:
		return 0
	for u in s.uses:
		if u.slot != s.key_slot or u.plan == null:
			continue
		var plan: CastPlan = u.plan
		var ctx := CastContext.new()
		ctx.ability = plan.ability
		ctx.point = plan.point
		ctx.direction = plan.direction
		ctx.target = plan.target
		var area := plan.ability.get_effect_area(_enemy, ctx)
		var n := 0
		for m in snap.members:
			if m.up and Ability.covers_unit(area, m.unit):
				n += 1
		return n
	return 0


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
## (AI2: or none needed), a commit under way, or a taunt on its target). AI3:
## defend (a defend use passes: it's threatened), escape (wants_escape()),
## retreat (a FALL_BACK enemy below its retreat health, or a skirmisher's
## reset); while retreating it keeps poking. AI3b: smell blood (commit ×
## smell_blood_mult below its finish threshold, capped), the walk out (the
## kiting step, the cautious walk) as a retreat, a held key's uses left out
## (SituationContext.get_best_use()).
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
		if s.target_health_ratio < b.finish_threshold:
			raw[COMMIT] = minf(raw[COMMIT] * s.smell_blood_mult, s.smell_blood_cap)   # smell blood (AI3b)
	var defend := s.get_best_use([DEFEND])
	if not defend.is_empty():
		raw[DEFEND] = float(s.intent_scores.get(DEFEND, 0.0))
	var escape := s.get_best_use([ESCAPE])
	if wants_escape(s, b, not escape.is_empty()):
		raw[ESCAPE] = float(s.intent_scores.get(ESCAPE, 0.0))
	if s.resetting or s.walking_out or (b.low_health == EnemyBehavior.LowHealth.FALL_BACK and s.health_ratio < b.retreat_health):
		raw[RETREAT] = float(s.intent_scores.get(RETREAT, 0.0))
	var best: StringName = &""
	var best_score := -INF
	var urgent := raw.has(DEFEND)   # an attack coming breaks the no-flip-flop hold (The brain)
	for intent: StringName in raw:   # in the order above: a tie keeps the earlier
		var score: float = raw[intent] * b.get_intent_weight(intent) * (1.0 + rng.randf_range(-b.jitter, b.jitter))
		if intent == s.intent and s.intent_age < s.min_intent_time and not urgent:
			score += s.intent_hold_bonus
		elif intent == ESCAPE and s.escaping:
			score += s.intent_hold_bonus   # a walk away under way holds (AI3)
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
		DEFEND:
			d.plan = defend.plan
		ESCAPE:
			if not escape.is_empty():
				d.plan = escape.plan   # else it walks away
		RETREAT:
			if not poke.is_empty():
				d.plan = poke.plan   # it keeps poking as it falls back
	if best in TELL_POSES and s.intent != best:
		d.pose = TELL_POSES[best]   # a new attack starts with its tell
	else:
		d.pose = get_intent_pose(best, b.role, s.cornered, s.resetting)
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
## hold (a skirmisher's stalk; a cornered caster's cornered), guard (defend),
## step_back (escaping on foot, a caster falling back), recoil (a
## skirmisher's reset); &"" = none (an attack's own look).
static func get_intent_pose(intent: StringName, role: EnemyBehavior.Role, cornered: bool = false, resetting: bool = false) -> StringName:
	if cornered and (intent == HOLD or intent == POKE or intent == ESCAPE):
		return &"cornered"   # (an escape is cornered mid-walk; its next think picks again)
	match intent:
		HOLD, POKE:
			return &"stalk" if role == EnemyBehavior.Role.SKIRMISHER else &"hold"
		DEFEND:
			return &"guard"
		ESCAPE:
			return &"step_back"
		RETREAT:
			return &"recoil" if resetting else &"step_back"
	return &""


## How fast patience fills (per second; ENEMIES_AI.md, The standoff): (1 −
## patience_respect_cut × effective respect) ÷ patience_time × (0.5 +
## aggression) × pressure. Pressure is 1, plus idle_pressure while the target
## has been idle idle_time s, plus low_pressure while it's below low_health.
## So with everything up it still fills, at a quarter of its speed: a brute
## (3 s, aggression 0.5) comes in 12 s at the latest.
## AI3b: while cautious (its key spent) × (1 − cautious_patience_cut ×
## confidence).
static func get_patience_rate(s: SituationContext, b: EnemyBehavior, table: EnemyAITable) -> float:
	var pressure := 1.0
	if s.target_idle_time >= table.idle_time:
		pressure += table.idle_pressure
	if s.target_health_ratio < table.low_health:
		pressure += table.low_pressure
	var rate := (1.0 - table.patience_respect_cut * s.effective_respect) / maxf(b.patience_time, 0.01) \
		* (0.5 + b.aggression) * pressure
	if s.cautious_left > 0.0:
		rate *= 1.0 - table.cautious_patience_cut * b.confidence
	return rate


# --- Act (Enemy calls drive() every physics tick while aggroed) -------------------------

func _apply_decision(d: BrainDecision, now: float) -> void:
	if d.intent != _intent:
		var was := _intent
		_intent = d.intent
		_intent_started = now
		if not (d.intent in HOLD_INTENTS and was in HOLD_INTENTS):
			_hold_edge = -1.0   # a new hold measures its distance again (poke and defend keep hold's)
		if was == COMMIT and _committing:
			_committing = false   # broken off (not done): patience stays
			_tell_left = 0.0
		if d.intent == COMMIT:
			_start_commit(now)
		intent_changed.emit(d.intent)
	if d.intent == ESCAPE:
		if d.plan != null:
			_escaping = false   # its escape ability is the escape: a walk after it gets its own 2 s (AI3d)
		elif not _escaping:
			_start_escape_walk(now)
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
		HOLD, POKE, DEFEND:
			_drive_hold(delta, target)
		ESCAPE:
			if _escaping:
				_drive_escape(delta, target)
		RETREAT:
			if is_resetting() or is_walking_out():
				_drive_hold(delta, target)   # its back off walks it out to its band (AI3b: or its far edge)
			else:
				_drive_fall_back(delta, target)
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
	if _commit_engaged_at < 0.0 and _enemy.edge_distance_to(target) <= _enemy.attack.get_range_px():
		_commit_engaged_at = Brains.get_time()
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
## A caster (AI3) strafes only to stand behind or beside its melee packmates
## and to keep 2 m from other casters (get_caster_strafe()).
func _drive_hold(delta: float, target: Unit) -> void:
	var table := Brains.table
	var edge := _enemy.edge_distance_to(target)
	if is_cornered():
		_drive_cornered(target, edge)
		return
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
	if _back_off_left > 0.0 and _walk_out_far and is_walking_out():
		_hold_edge = band_max   # cautious: out to its band's far edge (AI3b)
	elif _back_off_left > 0.0:
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
	var strafe := _strafe_dir
	if behavior.role == EnemyBehavior.Role.CASTER:
		strafe = get_caster_strafe(_enemy, target, _packmates(), table)
	angle += strafe * table.strafe_step_px / radius
	_enemy.movement.move_to(target.global_position + Vector2.from_angle(angle) * radius)


## Which way a caster strafes round its target while it holds (ENEMIES_AI.md,
## Movement and positioning; AI3): away from another caster within
## caster_spacing_px; else toward cover, so its nearest melee packmate stands
## between it and its target or within cover_angle_deg of that line; else
## it stands (0). `packmates`: its living packmates.
static func get_caster_strafe(caster: Enemy, target: Unit, packmates: Array[Enemy], table: EnemyAITable) -> float:
	var center := target.global_position
	var mine := (caster.global_position - center).angle()
	var melee: Enemy = null
	for m in packmates:
		if is_caster(m):
			if m.global_position.distance_to(caster.global_position) < table.caster_spacing_px:
				var d := angle_difference((m.global_position - center).angle(), mine)
				return 1.0 if d >= 0.0 else -1.0   # apart
		elif melee == null or m.global_position.distance_to(center) < melee.global_position.distance_to(center):
			melee = m
	if melee == null:
		return 0.0
	var toward := angle_difference(mine, (melee.global_position - center).angle())
	if absf(toward) <= deg_to_rad(table.cover_angle_deg):
		return 0.0
	return signf(toward)


## `e` is a caster (its brain's role); fodder and every other role are melee.
static func is_caster(e: Enemy) -> bool:
	var brain := e.get_brain()
	return brain != null and brain.behavior != null and brain.behavior.role == EnemyBehavior.Role.CASTER


func _packmates() -> Array[Enemy]:
	var out: Array[Enemy] = []
	var pack := _enemy.get_pack()
	if pack == null:
		return out
	for m in pack.get_members():
		if m != _enemy:
			out.append(m)
	return out


## Falling back (a caster below its retreat health; ENEMIES_AI.md, Low
## health): to just behind its nearest living melee packmate, as seen from
## its target; with none, away from its target to its band's far edge. It
## keeps poking (decide() gives it its poke plan).
func _drive_fall_back(delta: float, target: Unit) -> void:
	if _enemy.attack.target != null and not _enemy.attack.is_winding_up():
		_enemy.attack.cancel()
	_replan_left -= delta
	if _replan_left > 0.0 and _enemy.movement.has_order():
		return
	_replan_left = Brains.table.hold_replan_time
	_enemy.movement.move_to(get_fall_back_spot(_enemy, target, _packmates(), behavior))


## Where a caster falls back to (see _drive_fall_back()).
static func get_fall_back_spot(caster: Enemy, target: Unit, packmates: Array[Enemy], b: EnemyBehavior) -> Vector2:
	var melee: Enemy = null
	for m in packmates:
		if is_caster(m):
			continue
		if melee == null or m.global_position.distance_to(caster.global_position) < melee.global_position.distance_to(caster.global_position):
			melee = m
	var center := target.global_position
	if melee != null:
		var behind := melee.global_position - center
		behind = behind.normalized() if behind.length() > 0.01 else Vector2.RIGHT
		return melee.global_position + behind * (melee.get_gameplay_radius_px() + caster.get_gameplay_radius_px() + FALL_BACK_GAP_PX)
	var away := caster.global_position - center
	away = away.normalized() if away.length() > 0.01 else Vector2.RIGHT
	return center + away * (Units.to_px(b.range_band_max) + caster.get_gameplay_radius_px() + target.get_gameplay_radius_px())


## Escaping on foot (no escape ability ready; ENEMIES_AI.md, Cornered
## casters): it walks straight away from its target for up to
## escape_walk_time. Out of time, blocked (a wall or a ledge: it barely moves),
## slowed or rooted, it's cornered. The walk's clock runs from its start
## until it gets away (its target outside its band's minimum), is cornered or
## leaves the fight, whatever it does meanwhile (a shield, a poke).
func _start_escape_walk(now: float) -> void:
	_escaping = true
	_escape_until = now + Brains.table.escape_walk_time
	_escape_stuck = 0.0
	_escape_last_pos = _enemy.global_position
	_replan_left = 0.0


func _drive_escape(delta: float, target: Unit) -> void:
	var now := Brains.get_time()
	var moved := _enemy.global_position.distance_to(_escape_last_pos)
	_escape_last_pos = _enemy.global_position
	_escape_stuck = _escape_stuck + delta if moved < 0.3 else 0.0
	var slowed := _enemy.status_component != null and _enemy.status_component.has_tag(&"slow")
	if now >= _escape_until or _escape_stuck >= ESCAPE_STUCK_TIME or slowed or _enemy.is_cc_blocked():
		_corner(now)
		return
	if _enemy.attack.target != null and not _enemy.attack.is_winding_up():
		_enemy.attack.cancel()
	_replan_left -= delta
	if _replan_left > 0.0 and _enemy.movement.has_order():
		return
	_replan_left = Brains.table.hold_replan_time
	var away := _enemy.global_position - target.global_position
	away = away.normalized() if away.length() > 0.01 else Vector2.RIGHT
	_enemy.movement.move_to(_enemy.global_position + away * Brains.table.escape_step_px)


## Cornered, it stands its ground: it swings at its target once it's within
## cornered_reach_ratio × its reach (a step in, never away), else it stands
## and its pokes go off (decide()'s plan).
func _drive_cornered(target: Unit, edge: float) -> void:
	if edge <= _enemy.attack.get_range_px() * Brains.table.cornered_reach_ratio:
		if _enemy.attack.target != target:
			_enemy.attack.attack(target)
		return
	if _enemy.attack.target != null and not _enemy.attack.is_winding_up():
		_enemy.attack.cancel()
	if _enemy.movement.has_order():
		_enemy.movement.stop()


## Cornered: it squares up for cornered_time (its pose; it fights with its
## basic attack and its pokes from where it stands, and doesn't run).
func _corner(now: float) -> void:
	_escaping = false
	_cornered_until = now + Brains.table.cornered_time
	_hold_edge = -1.0
	_enemy.movement.stop()
	Brains.wake(self)


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
	_last_lead_px = plan.lead_px
	if plan.is_vector():
		abilities.try_cast_vector(plan.slot, plan.vector_start, plan.vector_direction)
	else:
		abilities.try_cast(plan.slot, plan.point, plan.target)


func _start_commit(now: float) -> void:
	_committing = true
	_commit_started = now
	_commit_hits = 0
	_commit_ability_hits = 0
	_commit_cast = false
	_commit_cast_done = false
	_commit_engaged_at = -1.0
	_tell_left = Brains.table.tell_time


## A commit is done after commit_max_time (the tell included), or:
## - a skirmisher (AI3): its first landed hit (its gap-closer's included), or
##   reset_time after it got to its target;
## - anyone else: its first cast ended (not a gap-closer's), or commit_hits
##   landed basic attacks.
func _is_commit_done(now: float) -> bool:
	var table := Brains.table
	if now - _commit_started >= table.commit_max_time:
		return true
	if behavior.role == EnemyBehavior.Role.SKIRMISHER:
		if _commit_hits + _commit_ability_hits >= 1:
			return true
		return _commit_engaged_at >= 0.0 and now - _commit_engaged_at >= table.reset_time
	return _commit_cast_done or _commit_hits >= table.commit_hits


## A commit that's done empties patience, and it walks back out to its band.
## Its tokens go, and it rests token_rest_time s before it may ask again. A
## skirmisher (AI3) hops back reset_hop_px, keeps reset_patience of its
## patience and retreats (its reset) for back_off_time. AI3b: cautious (its
## key spent) with confidence above 0, it walks out to its band's far edge
## instead (a retreat; a skirmisher's reset already walks it out).
func _end_commit() -> void:
	var table := Brains.table
	_committing = false
	_tell_left = 0.0
	_pending_plan = null
	_back_off_left = table.back_off_time
	Brains.release_token(_enemy, true)
	if behavior.role == EnemyBehavior.Role.SKIRMISHER:
		_patience = table.reset_patience
		_resetting_until = Brains.get_time() + table.back_off_time
		_hop_out()
	else:
		_patience = 0.0
		if is_cautious() and behavior.confidence > 0.0:
			_start_walk_out(Brains.get_time(), true)


## A skirmisher's hop out at its reset: a quick dash straight back from its
## target (not through anyone), unless it can't dash.
func _hop_out() -> void:
	var target := _enemy.get_brain_target()
	if target == null or _enemy.is_dash_blocked() or _enemy.movement.is_displaced():
		return
	var away := _enemy.global_position - target.global_position
	away = away.normalized() if away.length() > 0.01 else Vector2.RIGHT
	var table := Brains.table
	var time := maxf(table.reset_hop_time, 0.01)
	if _enemy.attack.target != null and not _enemy.attack.is_winding_up():
		_enemy.attack.cancel()
	_enemy.movement.dash(away * table.reset_hop_px / time, time, false)


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
	elif behavior != null:
		pose = get_intent_pose(_intent, behavior.role, is_cornered(), is_resetting())
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
	_seen.clear()
	_escaping = false
	_cornered_until = -1.0
	_resetting_until = -1.0
	_cautious_until = -1.0
	_spend_free = false
	_next_spend_roll = -1.0
	_end_episode()
	_crowded_target = null
	_walking_out_until = -1.0
	_walk_out_far = false
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


## A hit its casts landed during its commit (its basic attacks count through
## attack_landed).
func _on_unit_damaged(ctx: HitContext) -> void:
	if _committing and _tell_left <= 0.0 and ctx.source == _enemy and not ctx.tags.has(&"basic_attack"):
		_commit_ability_hits += 1


func _on_cast_started(_slot: StringName, _ability: Ability, _ctx: CastContext) -> void:
	if _committing and _tell_left <= 0.0:
		_commit_cast = true


## A commit's first cast ending ends it, except a gap-closer's: it only got it
## there (AI3). AI3b: its key cast (landed or not; its cooldown running, so
## not refunded) makes it cautious for cautious_time.
func _on_cast_ended(slot: StringName, ability: Ability) -> void:
	if slot == _key_slot and _key_slot != &"" and _enemy.abilities != null and not _enemy.abilities.is_ready(slot):
		_cautious_until = Brains.get_time() + Brains.table.cautious_time
		_spend_free = false
		_next_spend_roll = -1.0
	if not (_committing and _commit_cast):
		return
	if ability != null and _has_use_for(ability, [&"gap_close"] as Array[StringName]):
		if _commit_engaged_at < 0.0:
			_commit_engaged_at = Brains.get_time()
		_commit_cast = false
		return
	_commit_cast_done = true
