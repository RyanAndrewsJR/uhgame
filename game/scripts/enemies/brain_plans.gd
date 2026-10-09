class_name BrainPlans
extends RefCounted
## An enemy brain's combo plans (ENEMIES_AI.md, Combo plans; AI-D2; split out
## of EnemyBrain in R1, code unchanged): the plans' reads into the situation,
## a plan's start in a commit, each step on its trigger (an ability's cast, or
## a STRING step's string: AR1a), the plan's end and the follow-through. The
## state stays on the brain (brain.<name>).

## The brain whose state it reads and writes (the brain owns this helper).
var brain: EnemyBrain


func _init(p_brain: EnemyBrain) -> void:
	brain = p_brain


## The combo plans' reads (AI-D2): the blind read and its inputs, its own kit
## ready, its follow-ups (kept unless the blind read passes), and, while it
## may start a commit (or its fresh commit is still in its tell), each plan's
## option; while its plan's opener is still to cast, that opener's plan now.
## `m` is its target's snapshot entry.
func _read_plans(s: SituationContext, m: Dictionary, target: Unit) -> void:
	var table := Brains.table
	s.has_plans = not brain._plans.is_empty()
	s.plan_running = brain._plan != null
	s.blind_reads = table.blind_reads
	s.mixup_delay_min = table.mixup_delay_min
	s.mixup_delay_max = table.mixup_delay_max
	s.own_kit_ready = BrainScoring.get_own_kit_ready(brain._enemy.abilities, table)
	s.target_cc_immune = target.status_component != null and target.status_component.has_tag(&"cc_immune")
	if not m.is_empty():
		s.target_ultimates = m.get("ultimates", 0)
		s.target_ultimates_ready = m.get("ultimates_ready", 0)
		for cc: Dictionary in m.get("ccs", []):
			s.target_held_left = maxf(s.target_held_left, float(cc.left) if float(cc.left) >= 0.0 else 999.0)
	s.blind_reason = ComboPlanner.get_blind_reason(s, brain.behavior.finish_threshold)
	if not s.has_plans:
		return
	s.follow_up_slots = BrainScoring.find_follow_up_slots(brain._enemy.abilities)
	if s.blind_reason == &"":
		s.kept_slots = s.follow_up_slots
	s.commit_plan_open = brain._committing and brain._commit_plan_open and brain._plan == null and brain._tell_left > 0.0
	if brain._plan == null and (not brain._committing or s.commit_plan_open):
		_build_plan_options(s)
	elif brain._plan != null and int(brain._plan_progress.get("index", 0)) == 0 and brain._plan_step_casting < 0:
		s.plan_opener_pending = true
		s.plan_opener_plan = _step_cast_plan(brain._plan.steps[0].slot, s)


## Each plan's option now (SituationContext.plan_options): its conditions, its
## needed steps' abilities ready, its opener's plan (one a slot a think: the
## one its gathered uses already have, else get_ai_plan()), its opener's crowd
## control not wasted, blind or not.
func _build_plan_options(s: SituationContext) -> void:
	var abilities := brain._enemy.abilities
	if abilities == null or not s.has_target:
		return
	var cached := {}   # slot -> CastPlan (null = none now)
	for u in s.uses:
		if not cached.has(u.slot) and u.plan != null:
			cached[u.slot] = u.plan
	for plan in brain._plans:
		var opener_slot := plan.get_opener_slot()
		var opener := abilities.get_ability(opener_slot)
		var o := {"plan": plan, "opener": null, "ready": true, "conditions_ok": true, "cc_ok": true,
			"blind": opener == null or not opener.combo_roles.has(EnemyBrain.OPENER_ROLE)}
		if plan.steps[0] != null and plan.steps[0].kind == ComboStep.Kind.STRING:
			o.ready = false   # AR1a: a string is never a plan's opener
		for step in plan.steps:
			if step == null or not o.ready:
				continue
			if step.kind == ComboStep.Kind.STRING:
				if not step.optional and not brain.has_attack_string():
					o.ready = false   # AR1a: a STRING step needs its string
			elif not step.optional and not brain._brain_duel._is_slot_ready(step.slot):
				o.ready = false
		o.conditions_ok = Condition.all_met(plan.conditions, brain._enemy, s.target_unit, null, s)
		if o.ready and o.conditions_ok and opener != null and abilities.can_cast(opener_slot):
			if not cached.has(opener_slot):
				cached[opener_slot] = _step_cast_plan(opener_slot, s)
			o.opener = cached[opener_slot]
			if o.opener != null and Brains.table.ability_applies_cc(opener):
				o.cc_ok = ComboPlanner.can_crowd_control(s, opener.get_param(brain._enemy, &"cast_time"))
		s.plan_options.append(o)


## `slot`'s ability's plan against its target now (Ability.get_ai_plan()), or
## null when it has none or its cast would fail at that aim.
func _step_cast_plan(slot: StringName, s: SituationContext) -> CastPlan:
	var abilities := brain._enemy.abilities
	var ability := abilities.get_ability(slot) if abilities != null else null
	if ability == null or s == null or not s.has_target:
		return null
	var plan := ability.get_ai_plan(brain._enemy, s)
	if plan == null:
		return null
	plan.slot = slot
	var aim := plan.vector_start if plan.is_vector() else plan.point
	if abilities.get_fail_reason(slot, aim, plan.target) != "":
		return null
	return plan


## A plan starts in the commit just started (AI-D2): its opener is the
## decision's cast, after its tell (and mixup's beat when it holds one); its
## token is kept to the plan's end, up to plan_max_time.
func _start_plan(d: BrainDecision, now: float) -> void:
	brain._plan = d.combo_plan
	brain._plan_target = brain._enemy.get_brain_target()
	brain._plan_started = now
	brain._plan_odds = float(Brains.get_odds().odds)
	brain._plan_runner_up = d.plan_runner_up
	brain._plan_delay_left = d.plan_delay
	brain._plan_step_casting = -1
	brain._plan_damage = 0.0
	brain._commit_plan_open = false
	brain._last_carry = ""
	var finishers: Array[int] = []
	var landed_at: Array[float] = []
	for i in brain._plan.steps.size():
		landed_at.append(-1.0)
		if brain._plan.steps[i].kind == ComboStep.Kind.STRING:
			continue   # AR1a: a string is never the finisher
		var ability := brain._enemy.abilities.get_ability(brain._plan.steps[i].slot) if brain._enemy.abilities != null else null
		if ability != null and ability.combo_roles.has(EnemyBrain.FINISHER_ROLE):
			finishers.append(i)
	brain._plan_progress = {"index": 0, "prev_end": -1.0, "prev_landed": -1.0, "prev_miss_at": INF, "opener_landed": false,
		"carried": false, "greed": -1.0, "finishers": finishers, "target_tags": [], "landed_at": landed_at}
	brain.plan_count += 1
	Brains.set_token_hold(brain._enemy, Brains.table.plan_max_time)
	Events.combo_plan_started.emit(brain._enemy, brain._plan_target, brain._plan)


## The plan's next move (the drive, every physics tick after the tell; never
## mid-cast): its opener goes through _try_plan() (the decision's cast) and
## ends the plan (WINDOW, the commit then plays as AI1's) if it can't start
## within its window; each later step starts on the tick ComboPlanner.next_step()
## says, is skipped, or the plan ends.
func _drive_plan(now: float, target: Unit) -> void:
	if brain._plan == null or brain._plan_step_casting >= 0 or brain._string_step >= 0:
		return   # a step's cast, or its string (AR1a), plays out
	var p := brain._plan_progress
	if int(p.index) == 0:
		if not p.has("opener_from"):
			p.opener_from = now
		elif now - float(p.opener_from) > brain._plan.steps[0].window + 0.0001:
			_end_plan(ComboPlanner.WINDOW, false)
		return
	if target != brain._plan_target or not is_instance_valid(brain._plan_target) or not brain._plan_target.is_targetable():
		_end_plan(ComboPlanner.TARGET_LOST)
		brain._end_commit()
		return
	p.target_tags = brain._plan_target.get_status_tags()
	var s := brain._situation if brain._situation != null else SituationContext.new()
	var r := ComboPlanner.next_step(brain._plan, p, s, brain.behavior, now, brain.rng)
	if r.has("greed"):
		p.greed = r.greed
	if r.get("carried", false) and not bool(p.carried):
		p.carried = true
		brain._last_carry = "carry on (blind: %s)" % String(s.blind_reason).replace("_", " ") if s.blind_reason != &"" else "carry on (%.2f < %.2f)" % [float(p.greed), brain.behavior.combo_greed]
	var action: StringName = r.action
	if action == ComboPlanner.START:
		_try_step(int(r.index), s)
	elif action == ComboPlanner.SKIP:
		_skip_step()
	elif action == ComboPlanner.END:
		if r.reason == ComboPlanner.MISSED:
			brain._last_carry = "end (%.2f ≥ %.2f)" % [float(r.greed), brain.behavior.combo_greed] if r.has("greed") else "end"
		_end_plan(r.reason)


## Step `i`'s trigger came: it starts now when it can (its ability ready, a
## crowd control that wouldn't be wasted, a plan now, the heavy-hit rule while
## pressing; a basic attack's windup is cut for it), else it tries again next
## tick, inside its window. An optional step whose ability is down, or whose
## crowd control would be wasted, is skipped.
func _try_step(i: int, s: SituationContext) -> void:
	var step := brain._plan.steps[i]
	if step.kind == ComboStep.Kind.STRING:
		_try_string_step(i, step)   # AR1a
		return
	var abilities := brain._enemy.abilities
	var ability := abilities.get_ability(step.slot) if abilities != null else null
	if ability == null or not abilities.is_ready(step.slot) or not abilities.can_afford(step.slot):
		if step.optional:
			_skip_step()
		return
	if Brains.table.ability_applies_cc(ability) and not ComboPlanner.can_crowd_control(s, ability.get_param(brain._enemy, &"cast_time")):
		if step.optional:
			_skip_step()
		return
	var plan := _step_cast_plan(step.slot, s)
	if plan == null or not brain._brain_duel._heavy_hit_allowed(ability, plan):
		return
	if brain._enemy.attack.is_winding_up():
		brain._enemy.attack.cancel()   # the step comes first (the windup is refunded)
	abilities.set_aim_hint(plan.point)
	brain._last_lead_px = plan.lead_px
	var cast: bool
	if plan.is_vector():
		cast = abilities.try_cast_vector(step.slot, plan.vector_start, plan.vector_direction)
	else:
		cast = abilities.try_cast(step.slot, plan.point, plan.target)
	if cast:
		brain._brain_duel._note_heavy_hit(plan)


## An optional step skipped: the next one triggers off the same previous cast.
func _skip_step() -> void:
	brain._plan_progress.index = int(brain._plan_progress.index) + 1
	if int(brain._plan_progress.index) >= brain._plan.steps.size():
		_end_plan(ComboPlanner.DONE)


## A STRING step's trigger came (AR1a): its string starts now on the plan's
## target (a basic attack's windup is cut for it), its length by respect;
## with no string the step is skipped (optional) or tried again next tick
## (inside its window).
func _try_string_step(i: int, step: ComboStep) -> void:
	if not brain.has_attack_string():
		if step.optional:
			_skip_step()
		return
	if brain._enemy.attack.is_winding_up():
		brain._enemy.attack.cancel()   # the step comes first (the windup is refunded)
	brain._brain_strings._start_string(brain._plan_target, i)


## A plan's string ended (AR1a): done, it's the step's end (the next step's
## miss time: whiff_time, as a melee hit has no travel); its last step ends
## the plan (DONE). Cut short, the plan ends at the frame's end
## (_resolve_string_cut()).
func _on_plan_string_ended(completed: bool) -> void:
	var i := brain._string_step
	brain._string_step = -1
	if brain._plan == null:
		return
	if not completed:
		brain._brain_strings._resolve_string_cut.call_deferred(true)
		return
	if i >= brain._plan.steps.size() - 1:
		_end_plan(ComboPlanner.DONE)
		return
	var now := Brains.get_time()
	var p := brain._plan_progress
	p.index = i + 1
	p.prev_end = now
	p.prev_landed = float((p.landed_at as Array)[i])
	p.prev_miss_at = now + Brains.table.whiff_time


## A plan step's cast ended: the last one ends the plan (DONE: its effect is
## out); otherwise the next step's trigger can come (its miss time: the
## travel, then whiff_time). A cast a stun cut ends it (INTERRUPTED).
func _on_plan_step_ended(ability: Ability) -> void:
	var i := brain._plan_step_casting
	brain._plan_step_casting = -1
	if not brain._enemy.is_alive() or brain._enemy.is_cast_blocked():
		_end_plan(ComboPlanner.INTERRUPTED)
		brain._break_commit()
		return
	if i >= brain._plan.steps.size() - 1:
		_end_plan(ComboPlanner.DONE)
		return
	var now := Brains.get_time()
	var p := brain._plan_progress
	p.index = i + 1
	p.prev_end = now
	p.prev_landed = float((p.landed_at as Array)[i])
	p.prev_miss_at = now + BrainScoring.get_travel_time(ability, brain._enemy, brain._plan_target) + Brains.table.whiff_time


## Ends the plan under way (AI-D2), with Events.combo_plan_ended. Done,
## missed, out of a window or the odds turned: the follow-through decides
## (unless `follow` is false). For the other reasons the caller ends or
## breaks the commit.
func _end_plan(reason: StringName, follow: bool = true) -> void:
	if brain._plan == null:
		return
	var plan := brain._plan
	var target := brain._plan_target
	brain._plan = null
	brain._plan_step_casting = -1
	brain._plan_delay_left = 0.0
	if brain._string_step >= 0:
		brain._brain_strings._stop_string()   # AR1a: a step's string goes with its plan
	brain._last_plan = plan
	brain._last_plan_reason = reason
	brain._last_plan_at = Brains.get_time()
	brain.plan_ends[reason] = int(brain.plan_ends.get(reason, 0)) + 1
	brain._last_follow = &""
	Events.combo_plan_ended.emit(brain._enemy, target, plan, reason)
	if follow and reason in [ComboPlanner.DONE, ComboPlanner.MISSED, ComboPlanner.WINDOW, ComboPlanner.ODDS]:
		_follow_through()


## After a plan (ENEMIES_AI.md, After the plan): it stays on its target when
## its lean (ComboPlanner.get_lean(): its last think's effective respect, its
## health and its own kit ready now) reaches 1 − follow_through and it still
## holds the token it needs: a new commit at once, its tell first, on the same
## token (its hold starts again), which may pick another plan in its tell.
## Otherwise it resets: the commit ends (patience empties, it walks out).
func _follow_through() -> void:
	if not brain._committing:
		return
	var s := SituationContext.new()
	s.effective_respect = brain._situation.effective_respect if brain._situation != null else 1.0
	var max_health := brain._enemy.health.max_health
	s.health_ratio = brain._enemy.health.current / max_health if max_health > 0.0 else 0.0
	s.own_kit_ready = BrainScoring.get_own_kit_ready(brain._enemy.abilities, Brains.table)
	s.needs_token = Brains.get_token_cost(brain._enemy) > 0
	s.has_token = Brains.has_token(brain._enemy)
	brain._last_lean = ComboPlanner.get_lean(s)
	if ComboPlanner.wants_stay(s, brain.behavior.follow_through):
		brain._last_follow = &"stay"
		brain._start_commit(Brains.get_time())
		brain._patience = 1.0
		Brains.set_token_hold(brain._enemy, Brains.table.token_hold_time)
	else:
		brain._last_follow = &"reset"
		brain._end_commit()


## A running plan's ends the situation shows (AI-D2): its target changed,
## crowd-controlled (a stun or a root: Brains takes its token too), its own
## health under retreat_health (a fall-back role), the odds turned (below
## (1 − plan_odds_drop) of their start), or plan_max_time past.
func _check_plan(s: SituationContext, now: float) -> void:
	if brain._plan == null:
		return
	var table := Brains.table
	if s.target_unit != brain._plan_target:
		_end_plan(ComboPlanner.TARGET_LOST)
		brain._end_commit()
	elif brain._enemy.is_cc_blocked():
		_end_plan(ComboPlanner.INTERRUPTED)
		brain._break_commit()
	elif brain._string_step >= 0:
		pass   # AR1a: a step's string runs to its end (its token is held for it)
	elif brain.behavior.low_health == EnemyBehavior.LowHealth.FALL_BACK and s.health_ratio < brain.behavior.retreat_health:
		_end_plan(ComboPlanner.LOW_HEALTH)
		brain._end_commit()
	elif brain._plan_odds > 0.0 and s.odds < brain._plan_odds * (1.0 - table.plan_odds_drop) - 0.0001:
		_end_plan(ComboPlanner.ODDS)
	elif now - brain._plan_started >= table.plan_max_time - 0.0001:
		_end_plan(ComboPlanner.TOKEN_LOST)
		brain._end_commit()
