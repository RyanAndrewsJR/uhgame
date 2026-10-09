class_name BrainDuel
extends RefCounted
## An enemy brain's duel (ENEMIES_AI.md, Duels and odds, Combos; AI3b, AI3c,
## AI-D1; split out of EnemyBrain in R1, code unchanged): the crowded
## episode and its roll, the walk out (the kiting step, the cautious walk),
## spending its key ability, the one heavy hit at a time while pressing, the
## setup and a peel that no longer passes. The state stays on the brain
## (brain.<name>); EnemyBrain keeps a forwarder for _update_spend() (the tests
## call it by name).

## The brain whose state it reads and writes (the brain owns this helper).
var brain: EnemyBrain


func _init(p_brain: EnemyBrain) -> void:
	brain = p_brain


func _is_slot_ready(slot: StringName) -> bool:
	var abilities := brain._enemy.abilities
	return abilities != null and abilities.get_ability(slot) != null and abilities.is_ready(slot) and abilities.can_afford(slot)


## The crowded episode (ENEMIES_AI.md, Crowded): it starts once its target
## has been inside its crowded range for its reaction time (it's reacting to
## you; never while it commits or walks back out after a commit: its own
## dive brings it close), with one roll
## (think() rolls it, once the uses are gathered). It lasts until the target
## has stayed crowded_clear_px outside it for crowded_clear_time s; a new
## target ends it.
## AI-D1: "inside" is its crowding at its peel_threshold or more (at the role
## starts the target inside its crowded range is enough on its own; a Lunge
## in or a string of hits near the edge brings it forward), and the target
## stays out only while its crowding is also below it.
func _update_episode(s: SituationContext, target: Unit, now: float) -> void:
	var table := Brains.table
	if target != brain._crowded_target:
		_end_episode()
		brain._crowded_target = target
	var crowded_px := Units.to_px(brain.behavior.get_crowded_range())
	if s.crowding >= brain.behavior.peel_threshold - 0.0001:
		brain._outside_since = -1.0
		if not brain._episode:
			if brain._committing or brain._back_off_left > 0.0:
				brain._crowded_seen = -1.0   # its own dive (or its walk out after one) brought it close
			elif brain._crowded_seen < 0.0:
				brain._crowded_seen = now
				Brains.wake_at(brain, now + brain.behavior.reaction_time)
			elif now - brain._crowded_seen + 0.0001 >= brain.behavior.reaction_time:
				brain._episode = true
				brain._episode_needs_roll = true
	else:
		if not brain._episode:
			brain._crowded_seen = -1.0
		elif s.target_edge_distance_px >= crowded_px + table.crowded_clear_px:
			if brain._outside_since < 0.0:
				brain._outside_since = now
			elif now - brain._outside_since + 0.0001 >= table.crowded_clear_time:
				_end_episode()
		else:
			brain._outside_since = -1.0
	s.crowded = brain._episode
	s.crowded_roll = brain._crowded_roll


func _end_episode() -> void:
	brain._episode = false
	brain._episode_needs_roll = false
	brain._crowded_roll = &""
	brain._crowded_roll_value = -1.0
	brain._crowded_answer = false
	brain._crowded_seen = -1.0
	brain._outside_since = -1.0
	brain._peel_pending = false   # AI-D1: a peel still to cast isn't needed any more (one under way finishes)


## The episode's one roll, carried out: all in fills patience at once (a melee
## role then commits, its tell first, on its token; with none free it holds
## its ground and swings, first in the queue); backing up starts the kiting
## step. Standing, escaping and the cornered stand need nothing more: the
## rules already built play them. AI-D1: a peel waits for its cast (decide()
## picks `peel` while it's pending; its end starts the kiting step).
func _roll_episode(s: SituationContext, now: float) -> void:
	brain._episode_needs_roll = false
	var r := BrainScoring.roll_crowded(s, brain.behavior, brain.rng)
	brain._crowded_roll = r.result
	brain._crowded_roll_value = r.roll
	brain._crowded_answer = r.answer
	s.crowded_roll = brain._crowded_roll
	match brain._crowded_roll:
		EnemyBrain.ALL_IN:
			if brain.behavior.role != EnemyBehavior.Role.CASTER:
				brain._patience = 1.0
		EnemyBrain.BACK_UP:
			_start_walk_out(now, false)
		EnemyBrain.PEEL:
			brain._peel_pending = true
			brain._peel_slot = s.get_best_use([EnemyBrain.PEEL] as Array[StringName]).get("slot", &"")


## Walking back out (a retreat, step_back): the crowded kiting step toward its
## band, or (far) a cautious walk to its band's far edge after a commit, for
## back_off_time s; then it holds its ground (AI1's rule).
func _start_walk_out(now: float, far: bool) -> void:
	var table := Brains.table
	brain._walking_out_until = now + table.back_off_time
	brain._walk_out_far = far
	brain._back_off_left = table.back_off_time
	brain._hold_edge = -1.0
	Brains.wake(brain)


## Spending the key ability (ENEMIES_AI.md): at a right moment it's free;
## otherwise a roll against spend_eagerness every spend_roll_time s while it
## holds the key frees it (until the next roll) or holds it: then its key's
## damage, cc and zone uses aren't picked (SituationContext.held_slot). Its
## key down: the roll waits until it's ready again.
func _update_spend(s: SituationContext, snap: PartySnapshot, now: float) -> void:
	if s.key_slot == &"" or not s.key_ready:
		brain._spend_free = false
		brain._next_spend_roll = -1.0
		return
	s.key_area_champions = _key_area_champions(s, snap)
	s.right_moment_reason = BrainScoring.get_right_moment(s, brain.behavior)
	s.right_moment = s.right_moment_reason != ""
	if s.right_moment:
		return
	if brain._next_spend_roll < 0.0 or now >= brain._next_spend_roll - 0.0001:
		brain._spend_free = brain.rng.randf() < brain.behavior.spend_eagerness
		brain._next_spend_roll = now + Brains.table.spend_roll_time
	if not brain._spend_free:
		s.held_slot = s.key_slot


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
		var area := plan.ability.get_effect_area(brain._enemy, ctx)
		var n := 0
		for m in snap.members:
			if m.up and Ability.covers_unit(area, m.unit):
				n += 1
		return n
	return 0


## The champion a plan's hit lands on: its target, else (a cast around itself)
## its brain's.
func _plan_hit_target(plan: CastPlan) -> Unit:
	if plan.target != null and is_instance_valid(plan.target):
		return plan.target
	return brain._enemy.get_brain_target()


## One heavy hit at a time (Odds, Fairness limits): while the enemies press,
## a heavy hit that would land within heavy_hit_window s of another on the
## same champion isn't started. True when it may start.
func _heavy_hit_allowed(ability: Ability, plan: CastPlan) -> bool:
	if Brains.get_press() <= 0.0:
		return true   # outside a press, AI2's rule: no limit
	var target := _plan_hit_target(plan)
	if target == null or not BrainScoring.is_heavy_hit(ability, brain._enemy, target, Brains.table):
		return true
	return Brains.can_land_heavy_hit(target, Brains.get_time() + BrainScoring.get_time_to_land(ability, brain._enemy, target))


## A heavy hit it started is noted in Brains (with or without a press, so a
## press that starts while it's on its way sees it).
func _note_heavy_hit(plan: CastPlan) -> void:
	var target := _plan_hit_target(plan)
	if target != null and BrainScoring.is_heavy_hit(plan.ability, brain._enemy, target, Brains.table):
		Brains.note_heavy_hit(brain._enemy, target, Brains.get_time() + BrainScoring.get_time_to_land(plan.ability, brain._enemy, target))


## The perilous gate (ARCHETYPES AR2): a perilous ability starts only when
## Brains.can_start_perilous() passes (none in a fight's first 6 s, one live
## at a time on the enemy side, two with a boss); checked as its uses are
## gathered, and again before it's cast (a decision's, a plan step's). True
## when it may start (any other ability always).
func _perilous_allowed(ability: Ability) -> bool:
	return ability == null or not ability.perilous or Brains.can_start_perilous(brain._enemy)


## The setup (ENEMIES_AI.md, Peel and setup): an enemy with combo plans (AI-D2;
## in AI-D1 an opener), not crowded (no episode, crowding under its
## peel_threshold), not committing or walking out, its target reachable, the
## opening at its opening_bar or more, and a plan that fits now. Never under
## its alert pose (found building AI-D1: Enemy.get_pose() shows `alert` first
## for its 0.4 s, so a setup on the think it woke hid its tell).
func _wants_setup(s: SituationContext) -> bool:
	if not s.has_plans or not s.has_target or brain._committing or s.crowded or s.walking_out or not s.target_reachable:
		return false
	if brain._enemy.get_pose() == &"alert":
		return false
	if s.crowding >= brain.behavior.peel_threshold - 0.0001 or s.opening < brain.behavior.opening_bar - 0.0001:
		return false
	return ComboPlanner.has_fitting_plan(s)


## A peel rolled but not cast whose use no longer passes (its target walked
## out of its range, the ability went down) takes the kiting step without it.
func _check_peel(s: SituationContext, now: float) -> void:
	if not brain._peel_pending or brain._peel_cast or s.casting or s.cast_blocked or brain.is_in_ability_recovery():
		return
	if not s.has_use([EnemyBrain.PEEL] as Array[StringName]):
		brain._peel_pending = false
		_start_walk_out(now, false)
