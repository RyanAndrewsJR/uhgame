class_name BrainDrive
extends RefCounted
## An enemy brain's drive (ENEMIES_AI.md, The brain: act; split out of
## EnemyBrain in R1, code unchanged): drive(), which Enemy calls every physics
## tick while it's aggroed (through EnemyBrain.drive()), carrying the intent
## out through the enemy's own components: the commit (its tell, a plan's
## steps, its string), the hold and its strafe, the peel, the escape walk and
## the cornered stand, the fall back, the decision's cast, and the pose. The
## state stays on the brain (brain.<name>); EnemyBrain keeps a forwarder for
## drive().

## The brain whose state it reads and writes (the brain owns this helper).
var brain: EnemyBrain


func _init(p_brain: EnemyBrain) -> void:
	brain = p_brain


## Carries out the current intent: its movement and presses (cheap, every
## tick), then the decision's cast. Nothing while a cast plays out or while
## stunned.
func drive(delta: float) -> void:
	brain._back_off_left = maxf(brain._back_off_left - delta, 0.0)
	var target := brain._enemy.get_brain_target()
	if target == null or brain._intent == &"":
		return
	if brain._enemy.is_stunned() or (brain._enemy.abilities != null and brain._enemy.abilities.casting):
		return
	if brain.is_in_ability_recovery():
		_update_pose(Brains.get_time())   # AI-D1: still, in the recover pose
		return
	match brain._intent:
		EnemyBrain.COMMIT:
			_drive_commit(delta, target)
		EnemyBrain.HOLD, EnemyBrain.POKE, EnemyBrain.DEFEND:
			_drive_hold(delta, target)
		EnemyBrain.PEEL:
			_drive_peel()
		EnemyBrain.ESCAPE:
			if brain._escaping:
				_drive_escape(delta, target)
		EnemyBrain.RETREAT:
			if brain.is_resetting() or brain.is_walking_out():
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
	if brain._plan_delay_left > 0.0:
		brain._plan_delay_left = maxf(brain._plan_delay_left - delta, 0.0)
		brain._enemy.movement.stop()
		if brain._enemy.attack.target != null and not brain._enemy.attack.is_winding_up():
			brain._enemy.attack.cancel()
		return
	if brain._tell_left > 0.0:
		brain._tell_left = maxf(brain._tell_left - delta, 0.0)
		brain._enemy.movement.stop()
		if brain._enemy.attack.target != null and not brain._enemy.attack.is_winding_up():
			brain._enemy.attack.cancel()
		return
	if brain._commit_engaged_at < 0.0 and brain._enemy.edge_distance_to(target) <= brain._enemy.attack.get_range_px():
		brain._commit_engaged_at = Brains.get_time()
	if brain._plan != null:
		brain._brain_plans._drive_plan(Brains.get_time(), target)
		if not brain._committing or brain._tell_left > 0.0 or (brain._enemy.abilities != null and brain._enemy.abilities.casting):
			return   # the plan ended (a reset, or a stay's tell) or a step started
	if brain._enemy.attack.is_running_string():
		return   # AR1a: its string plays out (the commit's, or a plan step's)
	if brain._plan == null and brain.has_attack_string():
		if brain._committing and not brain._commit_string and not brain._string_done and (brain._pending_plan == null or brain._string_then_cast):
			brain._brain_strings._start_string(target)   # AR1a: no cast to make first (or the mix put its string first): the string
		return
	if brain._enemy.attack.target != target:
		brain._enemy.attack.attack(target)


## Peel (AI-D1): it stands for its peel's cast (decide()'s plan; _try_plan()
## casts it), no swing; the cast's end starts the kiting step.
func _drive_peel() -> void:
	if brain._enemy.movement.has_order():
		brain._enemy.movement.stop()
	if brain._enemy.attack.target != null and not brain._enemy.attack.is_winding_up():
		brain._enemy.attack.cancel()


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
	var edge := brain._enemy.edge_distance_to(target)
	if brain.is_cornered():
		_drive_cornered(target, edge)
		return
	if brain._back_off_left <= 0.0 and edge <= brain._enemy.attack.get_range_px():
		if brain._enemy.attack.target != target:
			brain._enemy.attack.attack(target)
		return
	if brain._enemy.attack.target != null and not brain._enemy.attack.is_winding_up():
		brain._enemy.attack.cancel()
	brain._replan_left -= delta
	if brain._replan_left > 0.0 and brain._enemy.movement.has_order():
		return
	brain._replan_left = table.hold_replan_time
	brain._strafe_turn_left -= table.hold_replan_time
	if brain._strafe_turn_left <= 0.0:
		brain._strafe_dir = -brain._strafe_dir
		brain._strafe_turn_left = _strafe_turn_time()
	var band_min := Units.to_px(brain.behavior.range_band_min)
	var band_max := Units.to_px(brain.behavior.range_band_max)
	var to_self := brain._enemy.global_position - target.global_position
	var pressing := target.velocity.dot(to_self.normalized()) > Brains.IDLE_SPEED_PX if to_self.length() > 0.01 else false
	if brain._hold_edge < 0.0:
		brain._hold_edge = clampf(edge, band_min, band_max)
	if brain._back_off_left > 0.0 and brain._walk_out_far and brain.is_walking_out():
		brain._hold_edge = band_max   # cautious: out to its band's far edge (AI3b)
	elif brain._back_off_left > 0.0:
		brain._hold_edge = maxf(brain._hold_edge, band_min)
	elif edge > band_max:
		brain._hold_edge = band_max
	elif pressing and edge < brain._hold_edge - EnemyBrain.HOLD_SLACK_PX:
		brain._hold_edge = edge   # it walked in: hold the ground here
	elif edge > brain._hold_edge + EnemyBrain.HOLD_SLACK_PX:
		brain._hold_edge = clampf(edge, band_min, band_max)   # it walked away: follow, in the band
	var radii := brain._enemy.get_gameplay_radius_px() + target.get_gameplay_radius_px()
	var radius := maxf(brain._hold_edge + radii, radii + 1.0)
	var from_target := brain._enemy.global_position - target.global_position
	var angle := from_target.angle() if from_target.length() > 0.01 else brain.rng.randf() * TAU
	var strafe := brain._strafe_dir
	if brain.behavior.role == EnemyBehavior.Role.CASTER:
		strafe = EnemyBrain.get_caster_strafe(brain._enemy, target, _packmates(), table)
	angle += strafe * table.strafe_step_px / radius
	brain._enemy.movement.move_to(target.global_position + Vector2.from_angle(angle) * radius)


func _packmates() -> Array[Enemy]:
	var out: Array[Enemy] = []
	var pack := brain._enemy.get_pack()
	if pack == null:
		return out
	for m in pack.get_members():
		if m != brain._enemy:
			out.append(m)
	return out


## Falling back (a caster below its retreat health; ENEMIES_AI.md, Low
## health): to just behind its nearest living melee packmate, as seen from
## its target; with none, away from its target to its band's far edge. It
## keeps poking (decide() gives it its poke plan).
func _drive_fall_back(delta: float, target: Unit) -> void:
	if brain._enemy.attack.target != null and not brain._enemy.attack.is_winding_up():
		brain._enemy.attack.cancel()
	brain._replan_left -= delta
	if brain._replan_left > 0.0 and brain._enemy.movement.has_order():
		return
	brain._replan_left = Brains.table.hold_replan_time
	brain._enemy.movement.move_to(EnemyBrain.get_fall_back_spot(brain._enemy, target, _packmates(), brain.behavior))


## Escaping on foot (no escape ability ready; ENEMIES_AI.md, Cornered
## casters): it walks straight away from its target for up to
## escape_walk_time. Out of time, blocked (a wall or a ledge: it barely moves),
## slowed or rooted, it's cornered. The walk's clock runs from its start
## until it gets away (its target outside its band's minimum), is cornered or
## leaves the fight, whatever it does meanwhile (a shield, a poke).
func _start_escape_walk(now: float) -> void:
	brain._escaping = true
	brain._escape_until = now + Brains.table.escape_walk_time
	brain._escape_stuck = 0.0
	brain._escape_last_pos = brain._enemy.global_position
	brain._replan_left = 0.0


func _drive_escape(delta: float, target: Unit) -> void:
	var now := Brains.get_time()
	var moved := brain._enemy.global_position.distance_to(brain._escape_last_pos)
	brain._escape_last_pos = brain._enemy.global_position
	brain._escape_stuck = brain._escape_stuck + delta if moved < 0.3 else 0.0
	var slowed := brain._enemy.status_component != null and brain._enemy.status_component.has_tag(&"slow")
	if now >= brain._escape_until or brain._escape_stuck >= EnemyBrain.ESCAPE_STUCK_TIME or slowed or brain._enemy.is_cc_blocked():
		_corner(now)
		return
	if brain._enemy.attack.target != null and not brain._enemy.attack.is_winding_up():
		brain._enemy.attack.cancel()
	brain._replan_left -= delta
	if brain._replan_left > 0.0 and brain._enemy.movement.has_order():
		return
	brain._replan_left = Brains.table.hold_replan_time
	var away := brain._enemy.global_position - target.global_position
	away = away.normalized() if away.length() > 0.01 else Vector2.RIGHT
	brain._enemy.movement.move_to(brain._enemy.global_position + away * Brains.table.escape_step_px)


## Cornered, it stands its ground: it swings at its target once it's within
## cornered_reach_ratio × its reach (a step in, never away), else it stands
## and its pokes go off (decide()'s plan).
func _drive_cornered(target: Unit, edge: float) -> void:
	if edge <= brain._enemy.attack.get_range_px() * Brains.table.cornered_reach_ratio:
		if brain._enemy.attack.target != target:
			brain._enemy.attack.attack(target)
		return
	if brain._enemy.attack.target != null and not brain._enemy.attack.is_winding_up():
		brain._enemy.attack.cancel()
	if brain._enemy.movement.has_order():
		brain._enemy.movement.stop()


## Cornered: it squares up for cornered_time (its pose; it fights with its
## basic attack and its pokes from where it stands, and doesn't run).
func _corner(now: float) -> void:
	brain._escaping = false
	brain._cornered_until = now + Brains.table.cornered_time
	brain._hold_edge = -1.0
	brain._enemy.movement.stop()
	Brains.wake(brain)


## Casts the decision's plan once (after a commit's tell; never mid-windup or
## mid-cast), checked again first so a plan that went stale fails quietly.
func _try_plan() -> void:
	if brain._pending_plan == null or (brain._committing and (brain._tell_left > 0.0 or brain._plan_delay_left > 0.0)):
		return
	if brain._string_step >= 0 or brain._enemy.attack.get_string_swung() > 0:
		return   # AR1a: nothing cuts into a string once it swings (kept pending; its commit's end drops it)
	if brain._committing and brain._plan == null and brain.has_attack_string():
		if brain._string_done:
			if not brain._string_then_cast or brain._commit_cast:
				return   # its commit ends at its next think (or its finisher is cast already)
		elif not _is_gap_close_plan(brain._pending_plan):
			# The mix (Ryan, 2026-10-08): one roll a commit, the first time a
			# damage cast could go before its string.
			if not brain._string_mix_rolled:
				brain._string_mix_rolled = true
				brain._string_then_cast = brain.rng.randf() < Brains.table.string_then_cast_chance
			if brain._string_then_cast:
				return   # its string first; a damage cast after it is its finisher
	var abilities := brain._enemy.abilities
	if abilities == null or abilities.casting or brain._enemy.attack.is_winding_up():
		return
	var plan := brain._pending_plan
	brain._pending_plan = null
	if plan.target != null and not is_instance_valid(plan.target):
		return
	var aim := plan.vector_start if plan.is_vector() else plan.point
	if abilities.get_fail_reason(plan.slot, aim, plan.target) != "":
		return
	if not brain._brain_duel._heavy_hit_allowed(plan.ability, plan):
		return   # AI3c: another heavy hit got there first since the decision
	abilities.set_aim_hint(plan.point)
	brain._last_lead_px = plan.lead_px
	var cast: bool
	if plan.is_vector():
		cast = abilities.try_cast_vector(plan.slot, plan.vector_start, plan.vector_direction)
	else:
		cast = abilities.try_cast(plan.slot, plan.point, plan.target)
	if cast:
		brain._brain_duel._note_heavy_hit(plan)


## `plan` is its gap-closer now (AR1a): its ability has a gap_close use and
## its target is out of its reach (decide() picks a gap-closer only then). A
## gap-closer goes before its string whatever the mix rolls.
func _is_gap_close_plan(plan: CastPlan) -> bool:
	if plan == null or plan.ability == null or not BrainScoring._has_use_for(plan.ability, [&"gap_close"] as Array[StringName]):
		return false
	var target := brain._enemy.get_brain_target()
	return target != null and brain._enemy.edge_distance_to(target) > brain._enemy.attack.get_range_px()


## AI-D2: a recovery shows first (a stay's tell waits for it), and mixup's
## held beat shows as a hold.
func _update_pose(now: float) -> void:
	var pose: StringName = &""
	if brain.is_in_ability_recovery():
		pose = &"recover"   # AI-D1: the player's opening shows
	elif brain._committing and brain._plan_delay_left > 0.0 and brain.behavior != null:
		pose = BrainScoring.get_intent_pose(EnemyBrain.HOLD, brain.behavior.role, brain.is_cornered(), brain.is_resetting(), brain.is_pressing())
	elif brain._committing and brain._tell_left > 0.0:
		pose = EnemyBrain.TELL_POSES.get(EnemyBrain.COMMIT, &"")
	elif brain.behavior != null:
		pose = BrainScoring.get_intent_pose(brain._intent, brain.behavior.role, brain.is_cornered(), brain.is_resetting(), brain.is_pressing())
	if pose != brain._pose:
		brain._pose = pose
		brain._pose_started = now
		brain.pose_changed.emit(pose)


func _strafe_turn_time() -> float:
	var table := Brains.table
	return brain.rng.randf_range(table.strafe_turn_min, table.strafe_turn_max)
