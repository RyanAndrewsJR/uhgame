class_name BrainStrings
extends RefCounted
## An enemy brain's strings (ARCHETYPES AR1a; ENEMIES_AI.md, The brain; split
## out of EnemyBrain in R1, code unchanged): starting its string and stopping
## it, its first swing holding its token, its end, and a string cut short
## settled at the frame's end. The state stays on the brain (brain.<name>);
## EnemyBrain keeps the two handlers, connected in its _ready(), which call
## these.

## The brain whose state it reads and writes (the brain owns this helper).
var brain: EnemyBrain


func _init(p_brain: EnemyBrain) -> void:
	brain = p_brain


## Starts its string on `target` (its length by respect: get_string_length()
## over its last think's situation), its first hit on the beat. `step` >= 0:
## the plan step it runs; else the commit's string. False when it can't run
## (AutoAttackComponent.run_string()).
func _start_string(target: Unit, step: int = -1) -> bool:
	var s := brain._situation if brain._situation != null else SituationContext.new()
	var hits := BrainScoring.get_string_length(s, brain.data.attack_string, brain.rank_rules, Brains.table, brain.behavior, brain.rng)
	if not brain._enemy.attack.run_string(target, brain.data.attack_string, hits, Brains.table.beat):
		return false
	brain.string_count += 1
	brain.last_string_hits = hits
	if step >= 0:
		brain._string_step = step
	else:
		brain._commit_string = true
	return true


## Stops its string if one runs, its commit's or a plan step's (the commit
## ended or broke off first, so string_ended changes nothing).
func _stop_string() -> void:
	brain._commit_string = false
	brain._string_step = -1
	if is_instance_valid(brain._enemy) and brain._enemy.attack.is_running_string():
		brain._enemy.attack.cancel()


## A string's first swing: its token is held to the string's end on its
## rhythm (D6), or longer when it already holds it longer (a plan's).
func _on_swing_started(index: int, _direction: Vector2, _swing: AttackSwing) -> void:
	if index != 0 or not brain._enemy.attack.is_running_string() or not Brains.has_token(brain._enemy):
		return
	var hold := brain._enemy.attack.get_string_time_left() + EnemyBrain.STRING_HOLD_SLACK
	Brains.set_token_hold(brain._enemy, maxf(Brains.get_token_hold_left(brain._enemy), hold))


## Its string ended. A plan step's: _on_plan_string_ended(). The commit's: done,
## its next think (woken for the next tick) ends the commit and decides at
## once, as a commit's end always does (its token goes, it walks out; a
## skirmisher resets); cut before its first swing by a cast of its own (a cast
## may go first while the string only closes in: a gap-closer, a damage use
## now in reach), the commit goes on by AI1's rules; cut short otherwise (a
## stun, a break, its target gone), it's settled at the frame's end, once the
## status that cut it is on (_resolve_string_cut()).
func _on_string_ended(completed: bool, swung: int) -> void:
	if brain._string_step >= 0:
		brain._on_plan_string_ended(completed)
		return
	if not (brain._committing and brain._commit_string):
		return
	if completed:
		brain._string_done = true
		brain._string_done_at = Brains.get_time()
		if brain._string_then_cast:
			Brains.set_token_hold(brain._enemy, Brains.table.token_hold_time)   # the mix: its token kept for its finisher
		Brains.wake(brain)
	elif swung == 0 and brain._enemy.abilities != null and brain._enemy.abilities.casting:
		brain._commit_string = false   # its cast went first while it closed in: the commit goes on by AI1's rules (a gap-closer's end lets the string start)
	else:
		_resolve_string_cut.call_deferred(false)


## A string cut short, settled: stunned, broken or dead, the commit breaks off
## (its patience stays; Brains takes its token); otherwise (its target gone)
## the commit ends. `in_plan`: a plan step's string: the plan ends too
## (INTERRUPTED or TARGET_LOST).
func _resolve_string_cut(in_plan: bool) -> void:
	if not is_instance_valid(brain._enemy):
		return
	var held := not brain._enemy.is_alive() or brain._enemy.is_cc_blocked()
	if in_plan:
		if brain._plan == null:
			return
		brain._end_plan(ComboPlanner.INTERRUPTED if held else ComboPlanner.TARGET_LOST)
	elif not (brain._committing and brain._commit_string) or brain._string_done or brain._enemy.attack.is_running_string():
		return
	if held:
		brain._break_commit()
	else:
		brain._end_commit()
	Brains.wake(brain)
