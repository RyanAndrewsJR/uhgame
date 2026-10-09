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
## AI3c, the odds (ENEMIES_AI.md, Odds):
## - the press (Brains.get_odds(): the enemy side's strength ÷ the party's,
##   past odds_threshold): effective respect × (1 − nerve × press), patience's
##   push odds_pressure × press (shared with low health's: the larger), the
##   `press` pose in place of hold and stalk. A boss never presses (its
##   director owns its tempo);
## - one heavy hit at a time while pressing: a heavy ability (a hit worth
##   heavy_hit_share of its target's max health) whose hit would land within
##   heavy_hit_window of another on the same champion isn't started (its use
##   fails that think: it holds or swings); one it starts is noted in Brains;
## - think rates by rank (Brains: a regular 10, an elite 15, a boss and a
##   duelist elite 25 a second, scaled down past think_budget).
## AI-D1, combos' two reads (ENEMIES_AI.md, Combos, crowd control and the
## test duelist; ComboPlanner):
## - crowding (its target near, closing, gap-closing in, hitting it) at its
##   peel_threshold starts the crowded episode (at the role starts the target
##   inside crowded_range is enough on its own, as in AI3b); the episode ends
##   once crowding is below it and the target has stayed out
##   crowded_clear_time s;
## - a failed all-in roll peels when a `peel` use passes: it casts that use's
##   plan (no token), then takes the kiting step back to its band;
## - the opening (its target's escapes down, crowd-controlled by another,
##   casting, cornered), read only by an enemy with an `opener`-role ability:
##   at its opening_bar while it isn't crowded it sets up: its patience fills
##   at once and its commit (its tell, its token as usual) opens with its best
##   opener, whose end doesn't end the commit (combo plans come in AI-D2);
## - an ability's recovery (Ability.recovery_time) holds it still in the
##   `recover` pose.
## AI-D2, combo plans (ENEMIES_AI.md, Combo plans; ComboPlanner):
## - an enemy with combo plans (EnemyData.combo_plans) sets up when a plan
##   fits (not with an opener alone, as in AI-D1), and every commit of its
##   picks a plan when one fits (mixup: the runner-up, or a held beat first);
## - the plan runs inside the commit: its opener after the tell, then each
##   step on the tick its trigger comes (never a reaction time); it prefers
##   to wait for a hit to land, and a missed step carries on only on the blind
##   read (Ryan, 2026-10-07) or one combo_greed roll; no finisher after a
##   missed opener otherwise;
## - its token is kept to the plan's end (up to plan_max_time); the plan ends
##   when done, missed, out of its window, interrupted, its token or target
##   lost, its own health low (a fall-back role), or the odds turned;
## - then the follow-through: it stays on its target (a new commit at once,
##   its tell first) when its lean passes 1 − follow_through, else resets;
## - outside a plan it keeps its follow-ups (abilities with combo roles but
##   no `opener`) for its plans, unless the blind read passes.
## ARCHETYPES AR1a, strings (ARCHETYPES.md, Strings and the beat; D6):
## - an enemy with a string (EnemyData.attack_string) commits into it when no
##   plan runs: after its tell, its string (AutoAttackComponent.run_string())
##   closes in and swings, its first hit on the beat (EnemyAITable.beat), the
##   rest at its swings' rhythm. Until its first swing a gap-closer its
##   decision picks still goes first (it gets it there); a damage cast its
##   decision picks goes first, as in AI1 (its end ends the commit), or (the
##   mix, Ryan, 2026-10-08: one roll a commit at string_then_cast_chance)
##   waits and comes after the string as its finisher. Once it swings nothing
##   cuts into it (no cast), a deflect or a dodge doesn't end it, and its end
##   (or its finisher's) ends the commit (a skirmisher's reset after it); a
##   stun or a poise break cuts it (the commit breaks off, its token goes);
## - its length by respect (get_string_length()): 2 hits at high respect, its
##   full length (or one more) at low respect or against a low target, else
##   rolled in its rank's range;
## - its token is held for the whole string (from its first swing:
##   Brains.set_token_hold() to its end) and goes at its last swing's end;
## - a plan's STRING step (ComboStep.Kind.STRING) runs it as a step.
## ARCHETYPES AR1b, the Mage's volley:
## - a Mage's string is RANGED (AutoAttackComponent fires a bolt a release);
##   the caster preset commits (weight 1), so its commit is its volley;
## - while a commit's string swings, a think makes no new decision: a poke
##   scoring higher, a threat or low health takes nothing back (a stun, a
##   break, its token or target lost still end it).

signal intent_changed(intent: StringName)
signal pose_changed(pose: StringName)

const HOLD := &"hold"
const POKE := &"poke"
const COMMIT := &"commit"
const DEFEND := &"defend"
const ESCAPE := &"escape"
const RETREAT := &"retreat"
## Cast a crowd control to make space when crowded, then step back (AI-D1).
const PEEL := &"peel"
## A crowded episode's outcomes (AI3b; AI-D1: PEEL).
const ALL_IN := &"all_in"
const BACK_UP := &"back_up"
const STAND := &"stand"
const CORNERED := &"cornered"
## The combo role a setup opens with (AI-D1; Ability.combo_roles).
const OPENER_ROLE := &"opener"
## The combo role of a plan's last, heavy hit (AI-D2: no blind finisher).
const FINISHER_ROLE := &"finisher"
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
## A string's token is held this much past the string's end on its rhythm (s;
## AR1a), so Brains' timeout never takes it before the commit lets it go.
const STRING_HOLD_SLACK := 0.1

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
## The physics tick of its next scheduled think (Brains keeps it; AI3c).
var next_think_tick: float = 0.0
## How often Brains has called think() (tests: the schedule), and how many of
## those were scheduled (not urgent wakes; AI3c: think rates).
var think_calls: int = 0
var scheduled_thinks: int = 0
## Its peels cast and its setups started (AI-D1; tests, the overlay).
var peel_count: int = 0
var setup_count: int = 0
## Its combo plans started, and how they ended (reason -> count; AI-D2: tests,
## the overlay).
var plan_count: int = 0
var plan_ends: Dictionary = {}
## Its strings started, and the last one's length in hits (AR1a: tests, the
## overlay).
var string_count: int = 0
var last_string_hits: int = 0

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
@warning_ignore("unused_private_class_variable")
var _crowded_seen := -1.0        # when its target came inside (−1 = it isn't)
var _episode := false
var _episode_needs_roll := false
var _crowded_roll: StringName = &""
var _crowded_roll_value := -1.0  # the roll that decided it (the overlay)
var _crowded_answer := false
@warning_ignore("unused_private_class_variable")
var _outside_since := -1.0
var _walking_out_until := -1.0
var _walk_out_far := false
var _last_lead_px := 0.0
# AI-D1
var _opener_slots: Array[StringName] = []
var _setup_opener := false       # the commit under way is a setup whose opener isn't cast yet
var _setup_commit := false       # the commit under way is a setup (the overlay)
var _opener_cast := false        # the commit's cast under way is its setup's opener
var _setup_slot: StringName = &""   # the last setup's opener (the overlay)
var _peel_pending := false       # its episode's roll was a peel, not cast yet
var _peel_cast := false          # its peel's cast is under way
var _peel_slot: StringName = &""    # the peel's slot (the roll's, then the cast's)
var _seen_open: Dictionary = {}  # the opening's casts and crowd control: key -> when first seen
# AI-D2
var _plans: Array[ComboPlan] = []   # its plans at the run's difficulty tier
var _plan: ComboPlan                # the plan under way (null = none)
var _plan_target: Unit
@warning_ignore("unused_private_class_variable")
var _plan_started := 0.0
@warning_ignore("unused_private_class_variable")
var _plan_odds := 0.0               # the odds when it started
var _plan_runner_up := false
var _plan_delay_left := 0.0         # mixup's held beat before its tell
var _plan_step_casting := -1        # the step whose cast is under way (−1 = none)
var _plan_progress: Dictionary = {} # ComboPlanner.next_step()'s progress, plus landed_at per step
var _plan_damage := 0.0             # its damage on the target in the plan so far
var _commit_plan_open := false      # a fresh commit (in its tell) may still pick a plan
var _last_plan: ComboPlan           # the overlay: the last plan, how it ended, the follow-through
var _last_plan_reason: StringName = &""
var _last_plan_at := -INF
var _last_follow: StringName = &""   # &"stay" / &"reset"
var _last_lean := 0.0
var _last_carry: String = ""         # how a miss was decided: "blind (escapes_down)", "0.12 < 0.20", "end"
# AR1a
var _commit_string := false          # the commit under way has started its string
var _string_done := false            # ... and it ran to its end (the next think ends the commit)
var _string_done_at := -1.0          # when (the mix's finisher waits from then)
var _string_mix_rolled := false      # the commit rolled the mix (Ryan, 2026-10-08)
var _string_then_cast := false       # ... and its string comes first, its damage cast after it
var _string_step := -1               # the plan step running its string (−1 = none)
# R1: its code by job, in helpers that read and write the state above (the brain
# owns them; each holds it as `brain`). Godot counts a variable's uses per class,
# so the ones only the helpers use carry @warning_ignore.
var _brain_strings := BrainStrings.new(self)
var _brain_plans := BrainPlans.new(self)
var _brain_duel := BrainDuel.new(self)


func setup(p_data: EnemyData, p_rank_rules: RankRules) -> void:
	data = p_data
	rank_rules = p_rank_rules
	name = "EnemyBrain"


func _ready() -> void:
	_enemy = get_unit() as Enemy
	assert(_enemy != null, "EnemyBrain must be a child of an Enemy")
	resolve_behavior()
	_key_slot = BrainScoring.find_key_slot(_enemy.abilities, Brains.table)   # AI3b (each think finds it again)
	Brains.register(self)
	_strafe_dir = 1.0 if rng.randf() < 0.5 else -1.0
	_strafe_turn_left = _strafe_turn_time()
	_enemy.attack.attack_landed.connect(_on_attack_landed)
	_enemy.attack.swing_started.connect(_on_swing_started)   # AR1a: a string's first swing holds its token
	_enemy.attack.string_ended.connect(_on_string_ended)
	if _enemy.abilities != null:
		_enemy.abilities.cast_started.connect(_on_cast_started)
		_enemy.abilities.cast_finished.connect(_on_cast_ended)
		_enemy.abilities.cast_cancelled.connect(_on_cast_cancelled)   # AI-D2: first, so a plan's cut step ends it
		_enemy.abilities.cast_cancelled.connect(_on_cast_ended)
	Events.unit_damaged.connect(_on_unit_damaged)
	Events.unit_hit.connect(_on_unit_hit)   # AI-D2: its plan's steps landing
	_plans = data.get_plans_at(Brains.difficulty_tier) if data != null else []


func _exit_tree() -> void:
	Brains.unregister(self)
	if is_instance_valid(_enemy):
		Brains.release_token(_enemy, false)
	if Events.unit_damaged.is_connected(_on_unit_damaged):
		Events.unit_damaged.disconnect(_on_unit_damaged)
	if Events.unit_hit.is_connected(_on_unit_hit):
		Events.unit_hit.disconnect(_on_unit_hit)


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


## Its thinks a second by its rank (AI3c; a duelist elite the boss's), before
## the budget, and now (Brains.get_think_rate(): after it).
func get_base_think_rate() -> float:
	return Brains.table.get_think_rate_for(data)


func get_think_rate() -> float:
	return Brains.get_think_rate(self)


## Its rank always thinks at its full rate (RankRules.think_budget_exempt:
## elites and bosses, Ryan 2026-10-05).
func is_budget_exempt() -> bool:
	return rank_rules != null and rank_rules.think_budget_exempt


## Its enemy is in a fight (its thinks do work; the think budget counts it).
func is_awake() -> bool:
	return is_instance_valid(_enemy) and _enemy.is_brain_active()


## It pressed at its last think (AI3c: the odds on its side; never a boss).
func is_pressing() -> bool:
	return _situation != null and _situation.press > 0.0


## Its `opener`-role slots (AI-D1): it reads the opening and sets up only
## with one (until AI-D2's combo plans).
func get_opener_slots() -> Array[StringName]:
	return _opener_slots.duplicate()


## A peel under way (AI-D1): its episode's roll was a peel and its cast hasn't
## ended yet; and the peel's slot (&"" = none yet).
func is_peeling() -> bool:
	return _peel_pending or _peel_cast


func get_peel_slot() -> StringName:
	return _peel_slot


## Its last setup's opener slot (AI-D1; &"" = none yet), and whether the
## commit under way is a setup whose opener hasn't been cast yet.
func get_setup_slot() -> StringName:
	return _setup_slot


func is_setting_up() -> bool:
	return _committing and _setup_opener


## The commit under way is a setup (its opener cast or still to come).
func is_setup_commit() -> bool:
	return _committing and _setup_commit


## In an ability's recovery (AI-D1: Ability.recovery_time): it can't move,
## attack or cast (the `recover` pose).
func is_in_ability_recovery() -> bool:
	return is_instance_valid(_enemy) and _enemy.abilities != null and _enemy.abilities.is_recovering()


## Its combo plans at the run's difficulty tier (AI-D2).
func get_plans() -> Array[ComboPlan]:
	return _plans.duplicate()


## The plan under way (null = none), the step it's on (its next to start, or
## the one casting), whether that's mixup's runner-up, and mixup's beat left.
func get_plan() -> ComboPlan:
	return _plan


func get_plan_step() -> int:
	if _plan == null:
		return -1
	return _plan_step_casting if _plan_step_casting >= 0 else int(_plan_progress.get("index", 0))


func is_plan_runner_up() -> bool:
	return _plan != null and _plan_runner_up


func get_plan_delay_left() -> float:
	return _plan_delay_left if _plan != null else 0.0


## The running plan's progress (a copy; ComboPlanner.next_step()'s keys plus
## landed_at per step), its damage on the target so far.
func get_plan_progress() -> Dictionary:
	return _plan_progress.duplicate(true)


func get_plan_damage() -> float:
	return _plan_damage


## The last plan that ended (null = none yet), why, and when (game time).
func get_last_plan() -> ComboPlan:
	return _last_plan


func get_last_plan_reason() -> StringName:
	return _last_plan_reason


func get_last_plan_at() -> float:
	return _last_plan_at


## The last plan's follow-through (&"stay", &"reset", &"" = none: it ended
## another way) and its lean; how a missed step was decided in its last plan
## ("carry on (blind: escapes down)", "carry on (0.12 < 0.20)", "end (0.31 ≥
## 0.20)", "end"; "" = none missed).
func get_last_follow() -> StringName:
	return _last_follow


func get_last_lean() -> float:
	return _last_lean


func get_last_carry() -> String:
	return _last_carry


## It has a string to run (AR1a: EnemyData.attack_string with swings).
func has_attack_string() -> bool:
	return data != null and data.attack_string != null and not data.attack_string.swings.is_empty()


## Its string is running (its commit's or a plan step's; AR1a).
func is_stringing() -> bool:
	return is_instance_valid(_enemy) and _enemy.attack.is_running_string()


## The plan step running its string (−1 = none; AR1a).
func get_string_step() -> int:
	return _string_step


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
	_brain_plans._check_plan(s, now)   # AI-D2
	if not _committing:
		_patience = clampf(_patience + BrainScoring.get_patience_rate(s, behavior, Brains.table) * dt, 0.0, 1.0)
		if _patience > 1.0 - PATIENCE_EPSILON:
			_patience = 1.0   # summed float steps fall a hair short of 1
	if _episode_needs_roll:
		_brain_duel._roll_episode(s, now)
	_brain_duel._check_peel(s, now)   # AI-D1
	if s.setup:
		_patience = 1.0   # AI-D1: the setup fills it at once (then its token, as any commit)
	s.patience = _patience
	s.committing = _committing
	s.walking_out = is_walking_out()
	s.peel_pending = _peel_pending
	_ask_token(s)
	if _committing and _enemy.attack.is_running_string() and _enemy.attack.get_string_swung() > 0:
		# AR1a/AR1b: a string that swings is committed (a poke scoring higher, a
		# threat to defend from, low health: none of them takes it back); only
		# a stun, a break, its token or its target lost end it (above).
		_situation = s
		_think_usec = Time.get_ticks_usec() - t0
		return true
	var d := BrainScoring.decide(s, behavior, rng)
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
	_key_slot = BrainScoring.find_key_slot(_enemy.abilities, table)
	s.key_slot = _key_slot
	s.key_ready = _key_slot != &"" and _brain_duel._is_slot_ready(_key_slot)
	if s.key_ready:
		_cautious_until = -1.0   # its key is back: no longer cautious
	s.own_ready_share = BrainScoring.get_own_ready_share(_enemy.abilities, table, _key_slot)
	s.cautious_left = maxf(_cautious_until - now, 0.0)
	s.walking_out = now < _walking_out_until
	s.aim_lead = behavior.aim_lead
	s.smell_blood_mult = table.smell_blood_mult
	s.smell_blood_cap = table.smell_blood_cap
	s.spend_min_champions = table.spend_min_champions
	s.major_tags = table.major_tags   # AI-D1: THREATENED's major filter
	_opener_slots = BrainScoring.find_opener_slots(_enemy.abilities)
	s.opener_slots = _opener_slots
	s.setup_opener = _committing and _setup_opener
	var target := _enemy.get_brain_target()
	if target == null or not target.is_targetable():
		return s
	s.has_target = true
	s.target_unit = target
	s.target_position = target.global_position
	s.target_edge_distance_px = _enemy.edge_distance_to(target)
	s.target_cc = target.status_component != null and target.status_component.has_tag(&"cc")
	var snap := Brains.get_snapshot()
	var m := snap.get_member(target)
	_read_crowding(s, m, target, now)   # AI-D1: crowding starts the episode
	_brain_duel._update_episode(s, target, now)
	s.target_in_sight = WorldQuery.has_line_of_sight(_enemy.global_position, target.global_position)
	s.target_reachable = _enemy.is_target_reachable()
	s.taunted = _enemy.get_taunter() == target
	s.tokens_free = Brains.get_tokens_free(target)
	if _escaping and s.target_edge_distance_px >= Units.to_px(behavior.range_band_min):
		_escaping = false   # it got away
	s.escaping = _escaping
	s.party_size = snap.members.size()
	var target_share := 0.0
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
	var odds := Brains.get_odds()   # AI3c: one shared read per tick
	s.odds = float(odds.odds)
	s.press = 0.0 if data.rank == EnemyData.Rank.BOSS else float(odds.press)   # bosses don't press
	s.effective_respect = BrainScoring.get_effective_respect(s, behavior)
	_read_opening(s, m, target, now)   # AI-D1
	_perceive(s, snap, now)
	_gather_uses(s)
	_brain_duel._update_spend(s, snap, now)
	_brain_plans._read_plans(s, m, target)   # AI-D2
	s.setup = _brain_duel._wants_setup(s)   # AI-D1 (AI-D2: with a plan that fits)
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
		var t := BrainScoring.get_projectile_time_to_hit(p, _enemy)
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
	var abilities := _enemy.abilities
	if abilities == null:
		return
	var wanted: Array[StringName] = [POKE, &"zone"]
	if s.committing or s.patience >= 1.0 - PATIENCE_EPSILON or _patience_full_soon(s):
		wanted.append_array([&"damage", &"gap_close"] as Array[StringName])
	if s.crowded or s.target_edge_distance_px < Units.to_px(behavior.get_crowded_range()) \
			or s.crowding >= behavior.peel_threshold - 0.0001:
		for intent in SituationContext.ANSWER_INTENTS + [PEEL]:   # AI3b: its answers, for the crowded roll (AI-D1: its peels)
			if not wanted.has(intent):
				wanted.append(intent)
	if not s.opener_slots.is_empty() and (s.setup_opener or s.opening >= behavior.opening_bar - 0.0001):
		for intent in SituationContext.OPENER_INTENTS:   # AI-D1: a setup's opener
			if not wanted.has(intent):
				wanted.append(intent)
	if not s.incoming.is_empty() or s.crowding > 0.0:
		wanted.append(DEFEND)   # AI-D1: a defend use may read crowding (the duelist's guard)
	if not s.cornered and s.target_edge_distance_px < Units.to_px(behavior.range_band_min):
		wanted.append(ESCAPE)
	abilities.set_aim_hint(s.target_position)   # conditions look at the target (AB12)
	for slot in AbilityComponent.SLOTS:
		var ability := abilities.get_ability(slot)
		if ability == null or not abilities.can_cast(slot) or not BrainScoring._has_use_for(ability, wanted):
			continue
		var plan := ability.get_ai_plan(_enemy, s)
		if plan == null:
			continue
		plan.slot = slot
		var aim := plan.vector_start if plan.is_vector() else plan.point
		if abilities.get_fail_reason(slot, aim, plan.target) != "":
			continue
		if not _brain_duel._heavy_hit_allowed(ability, plan):
			continue   # AI3c: one heavy hit at a time while pressing (it holds or swings)
		for use in ability.get_ai_uses():
			if use != null and wanted.has(use.intent) and plan.intents.has(use.intent) and use.passes(_enemy, s.target_unit, s):
				s.add_use(slot, use.intent, plan, use.weight)


# --- Combos: crowding, the opening, the peel and the setup (AI-D1) ---------------------------

## Crowding's inputs and the read (ComboPlanner.get_crowding()): its crowded
## range and band, its target's walk toward it (the snapshot's walk), its
## target's last gap-closer if it ended inside its band's minimum within
## crowding_recent_time s, and the party's hits on it in the last
## crowding_hit_window s (Brains). `m` is its target's snapshot entry.
func _read_crowding(s: SituationContext, m: Dictionary, target: Unit, now: float) -> void:
	var table := Brains.table
	s.crowded_range_px = Units.to_px(behavior.get_crowded_range())
	s.band_min_px = Units.to_px(behavior.range_band_min)
	s.band_max_px = Units.to_px(behavior.range_band_max)
	s.crowding_closing_full_px = Units.to_px(table.crowding_closing_full)
	s.crowding_hits_full = table.crowding_hits_full
	var to_self := _enemy.global_position - target.global_position
	var walk: Vector2 = m.get("walk_velocity", Vector2.ZERO)
	s.target_closing_px = maxf(walk.dot(to_self.normalized()), 0.0) if to_self.length() > 0.01 else 0.0
	var gap: Dictionary = m.get("gap_closer", {})
	if not gap.is_empty() and now - float(gap.at) <= table.crowding_recent_time + 0.0001:
		var end: Vector2 = gap.position
		var edge := end.distance_to(_enemy.global_position) - _enemy.get_gameplay_radius_px() - target.get_gameplay_radius_px()
		s.target_gap_closer_in = edge < s.band_min_px
	s.recent_hits = Brains.get_recent_hits(_enemy, table.crowding_hit_window)
	s.crowding = ComboPlanner.get_crowding(s, table.crowding_weights, s.crowding_terms)


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
			if cc.source == _enemy:
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
	_seen_open = still
	s.target_recovering = false   # its punish window: AI6
	s.target_cornered = _target_cornered(target)
	s.opening = ComboPlanner.get_opening(s, table.opening_weights, s.opening_terms)


## `key` (a thing it reacts to) has been in view for its reaction time; the
## first sight asks Brains for a think then.
func _seen_long_enough(key: String, still: Dictionary, now: float) -> bool:
	var first: float = _seen_open.get(key, now)
	still[key] = first
	if not _seen_open.has(key):
		Brains.wake_at(self, now + behavior.reaction_time)
	return now - first + 0.0001 >= behavior.reaction_time


## A wall or a ledge within cornered_check_px behind its target's edge, on
## the line from this enemy through it (a WorldQuery sweep on the walls' and
## ledges' layers).
func _target_cornered(target: Unit) -> bool:
	var dir := target.global_position - _enemy.global_position
	if dir.length() < 0.01:
		return false
	var from := target.global_position
	var to := from + dir.normalized() * (target.get_gameplay_radius_px() + Brains.table.cornered_check_px)
	return not WorldQuery.shape_sweep(from, to, 2.0, MovementComponent.GHOST_KEEP_MASK).is_empty()


# --- Combo plans (AI-D2) --------------------------------------------------------------------

## A hit of its own on its plan's target (AI-D2): the step whose ability it
## was has landed (its opener's landing frees a finisher). AR1a: a basic
## attack hit while its STRING step runs is that step's landing.
func _on_unit_hit(ctx: HitContext) -> void:
	if _plan == null or ctx.source != _enemy or ctx.target != _plan_target:
		return
	var p := _plan_progress
	if _string_step >= 0 and ctx.ability == null and ctx.has_tag(&"basic_attack"):
		var string_landed: Array = p.landed_at
		if float(string_landed[_string_step]) < 0.0:
			string_landed[_string_step] = Brains.get_time()
		return
	if ctx.ability == null or _enemy.abilities == null:
		return
	var last: int = _plan_step_casting if _plan_step_casting >= 0 else int(p.index) - 1
	for i in range(mini(last, _plan.steps.size() - 1), -1, -1):
		if _plan.steps[i].kind == ComboStep.Kind.STRING or _enemy.abilities.get_ability(_plan.steps[i].slot) != ctx.ability:
			continue
		var landed_at: Array = p.landed_at
		if float(landed_at[i]) < 0.0:
			var now := Brains.get_time()
			landed_at[i] = now
			if i == 0:
				p.opener_landed = true
			if i == int(p.index) - 1 and _plan_step_casting < 0:
				p.prev_landed = now
		return


## Its tokens went while it committed (Brains: it's stunned or rooted, or it
## held them token_hold_time s; or its target changed): a stun breaks the
## commit off and keeps its patience (it asks again after its rest), anything
## else ends it (patience empties). A commit on a taunt holds no token: it
## ends when the taunt does.
func _check_token_lost(s: SituationContext) -> void:
	if not _committing or not s.needs_token or s.taunted or Brains.has_token(_enemy):
		return
	if _enemy.is_cc_blocked():
		_brain_plans._end_plan(ComboPlanner.INTERRUPTED)   # AI-D2: no follow-through
		_break_commit()
	else:
		_brain_plans._end_plan(ComboPlanner.TOKEN_LOST)
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
	var step := 1.0 / maxf(get_think_rate(), 0.01)   # AI3c: its own rate
	return s.patience + BrainScoring.get_patience_rate(s, behavior, Brains.table) * step >= 1.0 - PATIENCE_EPSILON


# --- Act (Enemy calls drive() every physics tick while aggroed) -------------------------

func _apply_decision(d: BrainDecision, now: float) -> void:
	if d.intent != _intent:
		var was := _intent
		_intent = d.intent
		_intent_started = now
		if not (d.intent in HOLD_INTENTS and was in HOLD_INTENTS):
			_hold_edge = -1.0   # a new hold measures its distance again (poke and defend keep hold's)
		if was == COMMIT and _committing:
			_brain_plans._end_plan(ComboPlanner.INTERRUPTED, false)   # AI-D2: something urgent came first (between steps)
			_committing = false   # broken off (not done): patience stays
			_tell_left = 0.0
			_plan_delay_left = 0.0
			_brain_strings._stop_string()   # AR1a: its string goes with it
		if d.intent == COMMIT:
			_start_commit(now)
			if d.combo_plan != null:
				_brain_plans._start_plan(d, now)
			if d.setup:
				_start_setup(d)
		intent_changed.emit(d.intent)
	elif d.intent == COMMIT and d.setup and not _committing:
		_start_commit(now)   # AI-D1: a setup on the think its last commit ended
		if d.combo_plan != null:
			_brain_plans._start_plan(d, now)
		_start_setup(d)
	elif d.intent == COMMIT and d.combo_plan != null and _committing and _plan == null:
		_brain_plans._start_plan(d, now)   # AI-D2: a fresh commit (a stay, or one that found none at first) picks one in its tell
	if d.intent == ESCAPE:
		if d.plan != null:
			_escaping = false   # its escape ability is the escape: a walk after it gets its own 2 s (AI3d)
		elif not _escaping:
			_start_escape_walk(now)
	_pending_plan = d.plan
	_decision = d
	_update_pose(now)


## A new commit is a setup (AI-D1): it opens with its opener (the decision's
## plan); that cast's end doesn't end the commit.
func _start_setup(d: BrainDecision) -> void:
	_setup_opener = true
	_setup_commit = true
	_setup_slot = d.plan.slot if d.plan != null else &""
	setup_count += 1


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
	if is_in_ability_recovery():
		_update_pose(Brains.get_time())   # AI-D1: still, in the recover pose
		return
	match _intent:
		COMMIT:
			_drive_commit(delta, target)
		HOLD, POKE, DEFEND:
			_drive_hold(delta, target)
		PEEL:
			_drive_peel()
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
## AI-D2: mixup's held beat comes before the tell (it holds its ground); a
## combo plan's steps start here, each on the tick its trigger comes.
## AR1a: with no plan, an enemy with a string runs it (D6) unless its
## decision's cast comes first (AI1's commit: a gap-closer gets it there, a
## damage cast's end ends the commit; _try_plan() may still cast while the
## string closes in); once it swings nothing cuts into it, and its end ends
## the commit (_on_string_ended()).
func _drive_commit(delta: float, target: Unit) -> void:
	if _plan_delay_left > 0.0:
		_plan_delay_left = maxf(_plan_delay_left - delta, 0.0)
		_enemy.movement.stop()
		if _enemy.attack.target != null and not _enemy.attack.is_winding_up():
			_enemy.attack.cancel()
		return
	if _tell_left > 0.0:
		_tell_left = maxf(_tell_left - delta, 0.0)
		_enemy.movement.stop()
		if _enemy.attack.target != null and not _enemy.attack.is_winding_up():
			_enemy.attack.cancel()
		return
	if _commit_engaged_at < 0.0 and _enemy.edge_distance_to(target) <= _enemy.attack.get_range_px():
		_commit_engaged_at = Brains.get_time()
	if _plan != null:
		_brain_plans._drive_plan(Brains.get_time(), target)
		if not _committing or _tell_left > 0.0 or (_enemy.abilities != null and _enemy.abilities.casting):
			return   # the plan ended (a reset, or a stay's tell) or a step started
	if _enemy.attack.is_running_string():
		return   # AR1a: its string plays out (the commit's, or a plan step's)
	if _plan == null and has_attack_string():
		if _committing and not _commit_string and not _string_done and (_pending_plan == null or _string_then_cast):
			_brain_strings._start_string(target)   # AR1a: no cast to make first (or the mix put its string first): the string
		return
	if _enemy.attack.target != target:
		_enemy.attack.attack(target)


## Peel (AI-D1): it stands for its peel's cast (decide()'s plan; _try_plan()
## casts it), no swing; the cast's end starts the kiting step.
func _drive_peel() -> void:
	if _enemy.movement.has_order():
		_enemy.movement.stop()
	if _enemy.attack.target != null and not _enemy.attack.is_winding_up():
		_enemy.attack.cancel()


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
	if _pending_plan == null or (_committing and (_tell_left > 0.0 or _plan_delay_left > 0.0)):
		return
	if _string_step >= 0 or _enemy.attack.get_string_swung() > 0:
		return   # AR1a: nothing cuts into a string once it swings (kept pending; its commit's end drops it)
	if _committing and _plan == null and has_attack_string():
		if _string_done:
			if not _string_then_cast or _commit_cast:
				return   # its commit ends at its next think (or its finisher is cast already)
		elif not _is_gap_close_plan(_pending_plan):
			# The mix (Ryan, 2026-10-08): one roll a commit, the first time a
			# damage cast could go before its string.
			if not _string_mix_rolled:
				_string_mix_rolled = true
				_string_then_cast = rng.randf() < Brains.table.string_then_cast_chance
			if _string_then_cast:
				return   # its string first; a damage cast after it is its finisher
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
	if not _brain_duel._heavy_hit_allowed(plan.ability, plan):
		return   # AI3c: another heavy hit got there first since the decision
	abilities.set_aim_hint(plan.point)
	_last_lead_px = plan.lead_px
	var cast: bool
	if plan.is_vector():
		cast = abilities.try_cast_vector(plan.slot, plan.vector_start, plan.vector_direction)
	else:
		cast = abilities.try_cast(plan.slot, plan.point, plan.target)
	if cast:
		_brain_duel._note_heavy_hit(plan)


## `plan` is its gap-closer now (AR1a): its ability has a gap_close use and
## its target is out of its reach (decide() picks a gap-closer only then). A
## gap-closer goes before its string whatever the mix rolls.
func _is_gap_close_plan(plan: CastPlan) -> bool:
	if plan == null or plan.ability == null or not BrainScoring._has_use_for(plan.ability, [&"gap_close"] as Array[StringName]):
		return false
	var target := _enemy.get_brain_target()
	return target != null and _enemy.edge_distance_to(target) > _enemy.attack.get_range_px()


func _start_commit(now: float) -> void:
	_committing = true
	_commit_started = now
	_commit_hits = 0
	_commit_ability_hits = 0
	_commit_cast = false
	_commit_cast_done = false
	_commit_engaged_at = -1.0
	_tell_left = Brains.table.tell_time
	_setup_opener = false
	_setup_commit = false
	_opener_cast = false
	_commit_plan_open = true   # AI-D2: in its tell it may still pick a plan
	_plan_delay_left = 0.0
	_commit_string = false   # AR1a
	_string_done = false
	_string_done_at = -1.0
	_string_mix_rolled = false
	_string_then_cast = false


## A commit is done after commit_max_time (the tell included), or:
## - a skirmisher (AI3): its first landed hit (its gap-closer's included), or
##   reset_time after it got to its target;
## - anyone else: its first cast ended (not a gap-closer's), or commit_hits
##   landed basic attacks.
## AI-D2: a commit running a plan ends with its plan (_check_plan()).
## AR1a: an enemy with a string (any role): its string's end ends it
## (_on_string_ended()), or commit_max_time while it hasn't swung yet; a cast
## commit (its decision's cast went first) its cast's end, as above. The mix
## (string first, then its cast): its finisher's end, or no finisher started
## within string_finisher_wait of the string's end.
func _is_commit_done(now: float) -> bool:
	if _plan != null:
		return false
	var table := Brains.table
	if has_attack_string():
		if _commit_string:
			if _string_done:
				if _string_then_cast and not _commit_cast_done \
						and (_commit_cast or now - _string_done_at < table.string_finisher_wait):
					return false   # the mix's finisher starts, or casts
				return true
			if _enemy.attack.get_string_swung() > 0:
				return false
		return now - _commit_started >= table.commit_max_time or (not _commit_string and _commit_cast_done)
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
	_brain_plans._end_plan(ComboPlanner.INTERRUPTED, false)   # AI-D2: none left running (its callers end it first)
	_committing = false
	_tell_left = 0.0
	_pending_plan = null
	_setup_opener = false
	_setup_commit = false
	_opener_cast = false
	_commit_plan_open = false
	_plan_delay_left = 0.0
	_brain_strings._stop_string()   # AR1a: one cut short (its token lost, commit_max_time while it chased)
	_back_off_left = table.back_off_time
	Brains.release_token(_enemy, true)
	if behavior.role == EnemyBehavior.Role.SKIRMISHER:
		_patience = table.reset_patience
		_resetting_until = Brains.get_time() + table.back_off_time
		_hop_out()
	else:
		_patience = 0.0
		if is_cautious() and behavior.confidence > 0.0:
			_brain_duel._start_walk_out(Brains.get_time(), true)


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
	_brain_plans._end_plan(ComboPlanner.INTERRUPTED, false)   # AI-D2: none left running (its callers end it first)
	_committing = false
	_tell_left = 0.0
	_pending_plan = null
	_setup_opener = false
	_setup_commit = false
	_opener_cast = false
	_commit_plan_open = false
	_plan_delay_left = 0.0
	_brain_strings._stop_string()   # AR1a


## AI-D2: a recovery shows first (a stay's tell waits for it), and mixup's
## held beat shows as a hold.
func _update_pose(now: float) -> void:
	var pose: StringName = &""
	if is_in_ability_recovery():
		pose = &"recover"   # AI-D1: the player's opening shows
	elif _committing and _plan_delay_left > 0.0 and behavior != null:
		pose = BrainScoring.get_intent_pose(HOLD, behavior.role, is_cornered(), is_resetting(), is_pressing())
	elif _committing and _tell_left > 0.0:
		pose = TELL_POSES.get(COMMIT, &"")
	elif behavior != null:
		pose = BrainScoring.get_intent_pose(_intent, behavior.role, is_cornered(), is_resetting(), is_pressing())
	if pose != _pose:
		_pose = pose
		_pose_started = now
		pose_changed.emit(pose)


## Out of the fight (de-aggroed, no target): everything back to the start.
func _reset() -> void:
	var had_intent := _intent != &""
	_brain_plans._end_plan(ComboPlanner.TARGET_LOST, false)   # AI-D2
	_commit_plan_open = false
	_plan_delay_left = 0.0
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
	_brain_duel._end_episode()
	_crowded_target = null
	_walking_out_until = -1.0
	_walk_out_far = false
	_setup_opener = false
	_setup_commit = false
	_opener_cast = false
	_peel_cast = false
	_seen_open.clear()
	if is_instance_valid(_enemy):
		_brain_strings._stop_string()   # AR1a
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


# --- Strings (ARCHETYPES AR1a) -----------------------------------------------------------
# Its string's handlers stay here, connected in _ready() in their order; their code
# is in BrainStrings (R1).

func _on_swing_started(index: int, _direction: Vector2, _swing: AttackSwing) -> void:
	_brain_strings._on_swing_started(index, _direction, _swing)


func _on_string_ended(completed: bool, swung: int) -> void:
	_brain_strings._on_string_ended(completed, swung)


## A hit its casts landed during its commit (its basic attacks count through
## attack_landed).
func _on_unit_damaged(ctx: HitContext) -> void:
	if _committing and _tell_left <= 0.0 and ctx.source == _enemy and not ctx.tags.has(&"basic_attack"):
		_commit_ability_hits += 1
	if _plan != null and ctx.source == _enemy and ctx.target == _plan_target:
		_plan_damage += ctx.taken_damage   # AI-D2: the overlay


## A cast cut short lands nothing: its heavy hit on its way is off (AI3c).
## AI-D2: a plan's step cut short ends the plan (connected before
## _on_cast_ended, so the plan is gone when that runs).
func _on_cast_cancelled(_slot: StringName, _ability: Ability) -> void:
	Brains.clear_heavy_hits(_enemy)
	if _plan != null and _plan_step_casting >= 0:
		_brain_plans._end_plan(ComboPlanner.INTERRUPTED)
		_break_commit()


## AI-D1: a setup's first cast is its opener (when it has the opener role;
## its end won't end the commit); a peel's cast starts (its end takes the
## kiting step).
func _on_cast_started(slot: StringName, ability: Ability, _ctx: CastContext) -> void:
	if _committing and _tell_left <= 0.0 and _plan != null:
		var i: int = _plan_progress.get("index", 0)   # AI-D2: its plan's step, when it's the one due
		if _plan_step_casting < 0 and i < _plan.steps.size() and _plan.steps[i].kind == ComboStep.Kind.ABILITY \
				and _plan.steps[i].slot == slot:
			_plan_step_casting = i
			if i == 0:
				_setup_opener = false
		return
	if _committing and _tell_left <= 0.0:
		_commit_cast = true
		if _setup_opener:
			_setup_opener = false
			_opener_cast = ability != null and ability.combo_roles.has(OPENER_ROLE)
	elif _peel_pending and _intent == PEEL:
		_peel_pending = false
		_peel_cast = true
		_peel_slot = slot


## A commit's first cast ending ends it, except a gap-closer's: it only got it
## there (AI3). AI3b: its key cast (landed or not; its cooldown running, so
## not refunded) makes it cautious for cautious_time. AI-D1: a setup's opener
## doesn't end it either; a peel's end (or its cut) starts the kiting step.
func _on_cast_ended(slot: StringName, ability: Ability) -> void:
	if slot == _key_slot and _key_slot != &"" and _enemy.abilities != null and not _enemy.abilities.is_ready(slot):
		_cautious_until = Brains.get_time() + Brains.table.cautious_time
		_spend_free = false
		_next_spend_roll = -1.0
	if _peel_cast and slot == _peel_slot:
		_peel_cast = false
		peel_count += 1
		_brain_duel._start_walk_out(Brains.get_time(), false)
		return
	if _plan != null:
		if _plan_step_casting >= 0 and slot == _plan.steps[_plan_step_casting].slot:
			_brain_plans._on_plan_step_ended(ability)
		return   # AI-D2: a plan's commit ends with its plan
	if not (_committing and _commit_cast):
		return
	if _opener_cast:
		_opener_cast = false
		_commit_cast = false
		return   # a setup's opener only opens it
	if ability != null and BrainScoring._has_use_for(ability, [&"gap_close"] as Array[StringName]):
		if _commit_engaged_at < 0.0:
			_commit_engaged_at = Brains.get_time()
		_commit_cast = false
		return
	_commit_cast_done = true


# --- Forwarders (R1) ----------------------------------------------------------------------
# The code of these is in the brain's helpers (R1: the split by job). Each keeps its
# name and signature here, so outside callers and the tests are unchanged (the
# contract: res://scripts/tests/golden/brain_api.txt).

# BrainScoring: the pure functions.

static func find_key_slot(abilities: AbilityComponent, table: EnemyAITable) -> StringName:
	return BrainScoring.find_key_slot(abilities, table)


static func get_own_ready_share(abilities: AbilityComponent, table: EnemyAITable, key_slot: StringName) -> float:
	return BrainScoring.get_own_ready_share(abilities, table, key_slot)


static func get_effective_respect(s: SituationContext, b: EnemyBehavior) -> float:
	return BrainScoring.get_effective_respect(s, b)


static func roll_crowded(s: SituationContext, b: EnemyBehavior, stream: RandomNumberGenerator) -> Dictionary:
	return BrainScoring.roll_crowded(s, b, stream)


static func get_right_moment(s: SituationContext, b: EnemyBehavior) -> String:
	return BrainScoring.get_right_moment(s, b)


static func is_heavy_hit(ability: Ability, caster: Unit, target: Unit, table: EnemyAITable) -> bool:
	return BrainScoring.is_heavy_hit(ability, caster, target, table)


static func get_time_to_land(ability: Ability, caster: Unit, target: Unit) -> float:
	return BrainScoring.get_time_to_land(ability, caster, target)


static func decide(s: SituationContext, b: EnemyBehavior, stream: RandomNumberGenerator) -> BrainDecision:
	return BrainScoring.decide(s, b, stream)


static func get_intent_pose(intent: StringName, role: EnemyBehavior.Role, cornered: bool = false, resetting: bool = false, pressing: bool = false) -> StringName:
	return BrainScoring.get_intent_pose(intent, role, cornered, resetting, pressing)


static func get_patience_rate(s: SituationContext, b: EnemyBehavior, table: EnemyAITable) -> float:
	return BrainScoring.get_patience_rate(s, b, table)


static func get_string_length(s: SituationContext, attack_string: AttackCombo, rules: RankRules, table: EnemyAITable,
		b: EnemyBehavior, stream: RandomNumberGenerator) -> int:
	return BrainScoring.get_string_length(s, attack_string, rules, table, b, stream)


# BrainDuel: the duel.

func _update_spend(s: SituationContext, snap: PartySnapshot, now: float) -> void:
	_brain_duel._update_spend(s, snap, now)
