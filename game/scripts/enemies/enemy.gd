class_name Enemy
extends Unit
## Basic monster AI: wanders, aggros on sight (or when hit), then chases and
## auto-attacks with the same AutoAttackComponent the player uses.
## Tune stats in its UnitStats resource; tune behaviour here.
## ENEMIES_AI AI1: an enemy with `data` (EnemyData) loads it when ready
## (_apply_enemy_data(): its stats, abilities, twist, look, tenacity by rank)
## and, when its rank has one, gets a brain (EnemyBrain) that drives it while
## it's aggroed: the cast loop and the chase below stand down.
## ENEMIES_AI AI2 (Ryan, 2026-10-04: every enemy with data): an enemy with data
## is in a pack (its parent Pack, else a pack of one) and plays the pack
## rules (_physics_process_pack()): it notices any party member in sight
## (WorldQuery) within detect_range, shouts so its pack wakes 0.4 s later,
## picks its target by ALLIES' rules (the nearest by threat, sticky with a
## margin, taunt, stealth, downed), fights (its brain; fodder by its place in
## the ring around its target; with its brain off, the old chase and naive
## cast loop), and leashes with its pack: it walks home faster and heals there
## (AI.RETURN). An enemy with no data plays exactly as before (the old
## routine below: the player only, the 800 u leash).

enum AI { IDLE, WANDER, AGGRO, RETURN }

## The tells' capsule looks when neither the enemy's data nor its behavior
## names a pose set (ENEMIES_AI.md, Tells).
const DEFAULT_POSE_SET_PATH := "res://data/pose_sets/pose_set_default.tres"
## The tenacity an elite or a boss gets at spawn goes under this source id.
const RANK_SOURCE_ID := &"enemy_rank"
## Walking home after a leash is faster: its move speed bonus goes under this.
const RETURN_SOURCE_ID := &"enemy_return"
## Home, after a leash, once this close (px).
const RETURN_ARRIVE_PX := 6.0
## A fodder blocked short of its place in the ring this long (s), with its
## target in reach, attacks from where it stands.
const FODDER_BLOCKED_TIME := 1.0
## A fodder whose place is more than this far round the ring (degrees) walks
## round the outside of the ring to it.
const FODDER_DETOUR_DEG := 50.0
## Settled at its place, a fodder keeps swinging while its target stays within
## this share of its reach; pushed farther (hits push its target about), it
## steps back to its place first, or its swings would whiff at the edge.
const FODDER_FIRM_REACH_SHARE := 0.85

## Aggro range in LoL units (edge to edge).
@export var detect_range: float = 450.0
## Stop chasing once the target is this far away (LoL units).
@export var leash_range: float = 800.0
@export var wander_distance: float = 60.0
## Training dummy: never wanders, aggros or attacks, even when hit. It can
## still be damaged, knocked back, stunned and killed.
@export var passive: bool = false
## What kind of enemy this is (ENEMIES_AI.md, EnemyData; AI1): loaded when
## it's ready, in place of the scene's own stats, abilities and look. null =
## exactly today's behavior.
@export var data: EnemyData
## The naive cast loop (_try_cast_ability(), COMBAT C5): the first ready
## ability in range each tick. Off = this enemy only chases and attacks. An
## enemy whose brain runs never uses it (ENEMIES_AI.md, The brain); it's
## deleted after the milestone AI-M, with Ryan's OK.
@export var naive_casting: bool = true
## Off: no brain even with data whose rank has one (the old routine and the
## naive cast loop; the sandbox's tuning panel switches it).
@export var brain_enabled: bool = true

@onready var sight: RayCast2D = $Sight

var ai: AI = AI.IDLE
var _ai_timer: float = 0.0
var _home: Vector2
var _player: Unit
var _chase_repath: float = 0.0   # chasing an untargetable player (AB10)
var _brain: EnemyBrain
static var _default_pose_set: PoseSet
# The pack rules (AI2; enemies with data only).
var _pack: Pack
var _home_pending := false   # its home is its spot at its first tick (a test places it after add_child)
var _target: Unit            # the pick
var _known: Array[Unit] = [] # party members it noticed, was hit by, or was alerted to
var _switch_to: Unit         # a better target it's been seeing since _switch_since
var _switch_since := 0.0
var _pick_left := 0.0
var _alert_left := 0.0       # the alert pose
var _return_ignore_left := 0.0
var _return_repath := 0.0
var _recovering := false
var _recover_rate := 0.0
var _ring_spot := Vector2.INF
var _ring_repath := 0.0
var _ring_settled := false   # it reached its place; it attacks from where it stands while in reach
var _ring_blocked := 0.0     # seconds in reach, short of its place, not moving
var _ring_stuck := false     # settled where it was blocked (not at its place)
var _ring_last_pos := Vector2.INF
var _reach_target: Unit
var _reach_next := -INF
var _reachable := true
var _notice_reach: Dictionary = {}   # Unit -> [can reach, next check time] (noticing)


func _ready() -> void:
	team = Team.ENEMY
	if data != null:
		_apply_enemy_data_base()
	super._ready()
	add_to_group("enemies")
	_home = global_position
	damaged.connect(_on_damaged)
	if data != null:
		_apply_enemy_data()
		_join_pack()
	_enter_idle()


func _enter_tree() -> void:
	if data != null and _pack != null:
		Brains.register_enemy(self)   # back in the tree after a move


func _exit_tree() -> void:
	if data != null:
		Brains.unregister_enemy(self)


## Its pack (AI2): its parent Pack, else a pack of one of its own.
func _join_pack() -> void:
	_home_pending = true
	_pack = get_parent() as Pack
	if _pack == null:
		_pack = Pack.new()
		_pack.name = "Pack"
		add_child(_pack)
	_pack.add_member(self)
	Brains.register_enemy(self)


func _on_died() -> void:
	super._on_died()
	if data != null:
		Brains.release_token(self, false)   # it frees the same tick


## Before the Unit sets itself up: the stats and the look its view is built from.
func _apply_enemy_data_base() -> void:
	if data.stats != null:
		stats = data.stats
	if data.model_scene != null:
		model_scene = data.model_scene
	model_color = data.model_color
	detect_range = data.detect_range


## After: its abilities (those of the run's difficulty tier), its twist, its
## rank's tenacity, and its brain when its rank has one (ENEMIES_AI.md,
## Enemy). The scene needs an AbilityComponent for abilities.
func _apply_enemy_data() -> void:
	var by_slot := data.get_abilities_at(Brains.difficulty_tier)
	if not by_slot.is_empty():
		if abilities == null:
			push_warning("%s: EnemyData '%s' has abilities but the scene has no AbilityComponent" % [name, data.id])
		else:
			for slot: StringName in by_slot:
				abilities.set(slot, by_slot[slot])
	if data.twist != null:
		data.twist.apply_to(self, data.get_source_id())
	var rules := get_rank_rules()
	if rules != null and rules.tenacity > 0.0:
		stats_component.add_modifier(StatModifier.create(&"tenacity", StatModifier.Type.FLAT, rules.tenacity, RANK_SOURCE_ID))
	if brain_enabled:
		_add_brain()


func _add_brain() -> void:
	var rules := get_rank_rules()
	if data == null or data.behavior == null or rules == null or not rules.has_brain or _brain != null:
		return
	_brain = EnemyBrain.new()
	_brain.setup(data, rules)
	add_child(_brain)
	if ai == AI.AGGRO:
		Brains.wake(_brain)


## Its rank's rules (EnemyAITable), or null without data.
func get_rank_rules() -> RankRules:
	return Brains.table.get_rank_rules(data.rank) if data != null else null


## Its brain, or null (no data, fodder, or switched off).
func get_brain() -> EnemyBrain:
	return _brain


## Switches its brain on or off while it plays (the sandbox's tuning panel).
## Off, it plays the old routine: the chase, the attack and the naive cast loop.
func set_brain_enabled(on: bool) -> void:
	brain_enabled = on
	if on:
		_add_brain()
		return
	if _brain != null:
		_brain.queue_free()
		remove_child(_brain)
		_brain = null
		if ai == AI.AGGRO and is_alive() and is_instance_valid(_player):
			attack.attack(_player)


## True while its brain drives it: aggroed, alive, not a training dummy.
func is_brain_active() -> bool:
	return _brain != null and ai == AI.AGGRO and is_alive() and not passive


## Who its brain fights (alive), or null: its target (get_target()).
func get_brain_target() -> Unit:
	var t := get_target()
	if t == null or not t.is_alive():
		return null
	return t


## Who it fights: with data, its pick (ALLIES' rules: _update_pick(); while
## its only target is untargetable it keeps it and chases it, AB10); with no
## data, the player, as the old routine. null = none.
func get_target() -> Unit:
	if data != null:
		return _target if is_instance_valid(_target) else null
	return _player if is_instance_valid(_player) else null


## The pose it shows (&"" = none): the view reads it. `alert` as it wakes and
## `return` while it walks home (AI2, fodder too), else its brain's (its tell).
func get_pose() -> StringName:
	if _alert_left > 0.0 and is_alive():
		return &"alert"
	if ai == AI.RETURN and not _recovering and is_alive():
		return &"return"
	return _brain.get_pose() if is_brain_active() else &""


func get_pose_progress() -> float:
	if _alert_left > 0.0 or ai == AI.RETURN:
		return 1.0
	return _brain.get_pose_progress() if is_brain_active() else 0.0


## Its tells' looks: its data's set, else its behavior's, else the default.
func get_pose_set() -> PoseSet:
	if data != null and data.pose_set != null:
		return data.pose_set
	if data != null and data.behavior != null and data.behavior.pose_set != null:
		return data.behavior.pose_set
	if _default_pose_set == null:
		_default_pose_set = load(DEFAULT_POSE_SET_PATH)
	return _default_pose_set


## Where it faces while its brain runs (its target); Vector2.INF = the view
## faces its walk, as before.
func get_face_point() -> Vector2:
	return _brain.get_face_point() if is_brain_active() else Vector2.INF


func _physics_process(delta: float) -> void:
	if not is_alive() or passive:
		return
	if data != null:
		_physics_process_pack(delta)   # ENEMIES_AI AI2: the pack rules
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Unit

	_ai_timer -= delta
	match ai:
		AI.IDLE:
			if _can_see_player():
				_enter_aggro()
			elif _ai_timer <= 0.0:
				_enter_wander()
		AI.WANDER:
			if _can_see_player():
				_enter_aggro()
			elif _ai_timer <= 0.0 or not movement.has_order():
				_enter_idle()
		AI.AGGRO:
			if _player == null or not _player.is_alive() \
					or edge_distance_to(_player) > Units.to_px(leash_range):
				attack.cancel()
				movement.stop()
				_enter_idle()
			elif not _player.is_targetable():
				_chase_untargetable(delta)
			elif _brain != null:
				_brain.drive(delta)   # ENEMIES_AI AI1: the brain decides and acts
			elif naive_casting and _try_cast_ability():
				pass  # Casting (rooted); the chase resumes after.
			elif attack.target != _player:
				attack.attack(_player)


func _enter_idle() -> void:
	ai = AI.IDLE
	_ai_timer = randf_range(0.8, 2.0)


func _enter_wander() -> void:
	ai = AI.WANDER
	_ai_timer = randf_range(1.0, 2.0)
	var offset := Vector2.from_angle(randf() * TAU) * randf_range(wander_distance * 0.3, wander_distance)
	movement.move_to(_home + offset)


func _enter_aggro() -> void:
	ai = AI.AGGRO
	if _brain != null:
		Brains.wake(_brain)   # it thinks on the next tick; it doesn't charge in meanwhile
		return
	attack.attack(_player)


## The player is untargetable (ABILITIES AB10): keep aggro, stop attacking
## (a windup is cancelled) and keep chasing; attacking resumes the frame the
## player is targetable again. A cast already going finishes.
func _chase_untargetable(delta: float) -> void:
	if abilities != null and abilities.casting:
		return
	if attack.target != null or attack.is_winding_up():
		attack.cancel()
		_chase_repath = 0.0
	_chase_repath -= delta
	if _chase_repath <= 0.0:
		_chase_repath = 0.1
		movement.move_to(_player.global_position)


func _on_damaged(_amount: float, source: Unit) -> void:
	if passive:
		return
	if data != null:
		_on_damaged_pack(source)
		return
	if ai != AI.AGGRO and source and source == _player:
		_enter_aggro()


## Enemies with an AbilityComponent (elites) cast a ready ability when the
## player is within its cast_range (from the center) and in sight. Its cast
## time is the telegraph (COMBAT.md). Not during a basic attack windup. A
## VECTOR ability places its line with get_ai_vector() (ABILITIES AB13).
## A slot that can't be cast right now for any reason (get_fail_reason():
## a failing condition or cost included, AB12) is skipped, so it never
## blocks the slots after it and nothing emits cast_failed. Returns true
## while casting.
func _try_cast_ability() -> bool:
	if abilities == null:
		return false
	if abilities.casting:
		return true
	if attack.is_winding_up():
		return false
	abilities.set_aim_hint(_player.global_position)   # conditions look at the target (AB12)
	for slot in AbilityComponent.SLOTS:
		var ability := abilities.get_ability(slot)
		if ability == null or not abilities.can_cast(slot):
			continue
		if global_position.distance_to(_player.global_position) > Units.to_px(ability.get_param(self, &"cast_range")):
			continue
		if not _can_see_player():
			continue
		if ability.cast_style == Ability.CastStyle.VECTOR:
			# The ability lays its own line (ABILITIES AB13): no mouse to drag.
			var v := ability.get_ai_vector(self, _player)
			if abilities.get_fail_reason(slot, v.start) != "":
				continue
			return abilities.try_cast_vector(slot, v.start, v.direction)
		if abilities.get_fail_reason(slot, _player.global_position, _player) != "":
			continue
		return abilities.try_cast(slot, _player.global_position, _player)
	return false


func _can_see_player() -> bool:
	if _player == null or not _player.is_targetable():   # no new aggro on an untargetable player (AB10)
		return false
	if edge_distance_to(_player) > Units.to_px(detect_range):
		return false
	sight.target_position = sight.to_local(_player.global_position)
	sight.force_raycast_update()
	return not sight.is_colliding()


# --- The pack rules (ENEMIES_AI AI2; enemies with data) -------------------------------------

## Its pack (null without data).
func get_pack() -> Pack:
	return _pack


## Its pack's home: where the leash is measured from (its own spot when it's
## alone).
func get_pack_home() -> Vector2:
	return _pack.get_home() if _pack != null else _home


## Its own spot: where it walks back to after a leash.
func get_home() -> Vector2:
	return _home


## The party members it knows of (noticed, hit by, alerted to).
func get_known() -> Array[Unit]:
	return _known.duplicate()


## Seconds it still ignores new aggro on its walk home.
func get_return_ignore_left() -> float:
	return _return_ignore_left


## Home after a leash, healing.
func is_recovering() -> bool:
	return _recovering


## Its place in the ring around its target (fodder; Vector2.INF = none yet).
func get_ring_spot() -> Vector2:
	return _ring_spot


## Brains gives each fighting fodder its place in the ring; `crowded`: it
## stands too close to another, and it's the one farther from its place, so it
## walks to it even while it could hit.
func set_ring_spot(spot: Vector2, crowded: bool = false) -> void:
	_ring_spot = spot
	if crowded and global_position.distance_to(spot) > Brains.table.fodder_ring_tolerance_px:
		_ring_settled = false


## A fighting fodder with data: the ring places it (Brains).
func uses_fodder_ring() -> bool:
	return data != null and data.rank == EnemyData.Rank.FODDER and ai == AI.AGGRO and is_alive() \
		and not passive and is_instance_valid(_target) and _target.is_targetable()


## A status that blocks moving or attacking (a stun, a root...): a token
## holder lets its token go (ENEMIES_AI.md, Groups).
func is_cc_blocked() -> bool:
	if is_stunned():
		return true
	if status_component == null:
		return false
	for id in status_component.get_status_ids():
		var effect := status_component.get_status(id)
		if effect != null and (effect.blocks_move or effect.blocks_attack):
			return true
	return false


## Who taunts it (the source of a status tagged `taunt` on it), or null
## (ALLIES.md: the taunter is its target while it's a candidate).
func get_taunter() -> Unit:
	if status_component == null:
		return null
	for id in status_component.get_status_ids():
		var effect := status_component.get_status(id)
		if effect != null and effect.tags.has(&"taunt"):
			var source := status_component.get_source(id)
			if source != null and source.is_alive():
				return source
	return null


## A unit it could pick (ALLIES.md, rule 1): alive, targetable, on the other
## team, not stealthed or downed, and inside its pack's leash.
func can_pick(u: Unit) -> bool:
	if not is_instance_valid(u) or not u.is_alive() or not u.is_targetable() or not is_enemy_of(u):
		return false
	if _has_tag(u, &"stealth") or _has_tag(u, &"downed"):
		return false
	return is_inside_leash(u)


## `u` stands within leash_px of its pack's home.
func is_inside_leash(u: Unit) -> bool:
	return u.global_position.distance_to(get_pack_home()) <= Brains.table.leash_px


## Edge distance ÷ the unit's threat (ALLIES.md, rule 3): a champion with 1.5
## threat counts as a third closer.
func get_effective_distance(u: Unit) -> float:
	var threat := u.stats_component.get_stat(&"threat") if u.stats_component != null else 1.0
	return edge_distance_to(u) / maxf(threat, 0.1)


## ALLIES' margin (rule 4): a switch from a target at `current_eff` to one at
## `candidate_eff` (effective distances, px) only when the candidate is
## switch_ratio shorter and switch_px shorter (then held switch_hold_time s).
static func is_better_target(current_eff: float, candidate_eff: float, table: EnemyAITable) -> bool:
	return candidate_eff <= current_eff * (1.0 - table.switch_ratio) and current_eff - candidate_eff >= table.switch_px


## Its target can be reached: a path gets it within its reach (checked at
## most every reach_check_time s). With no navigation to judge by, true.
func is_target_reachable() -> bool:
	var t := get_target()
	if t == null:
		return false
	var now := Brains.get_time()
	if t == _reach_target and now < _reach_next:
		return _reachable
	_reach_target = t
	_reach_next = now + Brains.table.reach_check_time
	_reachable = _path_reaches(t)
	return _reachable


func _path_reaches(t: Unit) -> bool:
	var map := get_world_2d().navigation_map
	if NavigationServer2D.map_get_iteration_id(map) == 0 or NavigationServer2D.map_get_regions(map).is_empty():
		return true
	var path := NavigationServer2D.map_get_path(map, global_position, t.global_position, true)
	if path.is_empty():
		return true
	var reach := get_gameplay_radius_px() + t.get_gameplay_radius_px() + attack.get_range_px()
	return path[path.size() - 1].distance_to(t.global_position) <= reach


## For its pack's leash timer: it fights a target it can reach.
func has_target_in_reach() -> bool:
	return ai == AI.AGGRO and get_target() != null and is_target_reachable()


## It knows a living party member (not down) inside its pack's leash; the pack
## gives up at once when none of its fighting members does.
func knows_party_inside_leash() -> bool:
	for u: Variant in _known:
		if is_instance_valid(u) and (u as Unit).is_alive() and not _has_tag(u, &"downed") and is_inside_leash(u):
			return true
	return false


static func _has_tag(u: Unit, tag: StringName) -> bool:
	return u.status_component != null and u.status_component.has_tag(tag)


func _physics_process_pack(delta: float) -> void:
	if _home_pending:
		_home_pending = false
		_home = global_position
		_pack.get_home()
	_ai_timer -= delta
	_alert_left = maxf(_alert_left - delta, 0.0)
	match ai:
		AI.IDLE, AI.WANDER:
			var seen := _notice()
			if seen != null:
				_wake(seen, true)
			elif ai == AI.IDLE and _ai_timer <= 0.0:
				_enter_wander()
			elif ai == AI.WANDER and (_ai_timer <= 0.0 or not movement.has_order()):
				_enter_idle()
		AI.AGGRO:
			_update_pick(delta)
			_player = get_target()   # the old routine's helpers below read _player (the naive loop, the AB10 chase)
			if _player == null:
				if attack.target != null and not attack.is_winding_up():
					attack.cancel()
				if movement.has_order() and not (abilities != null and abilities.casting):
					movement.stop()
			elif not _player.is_targetable():
				_chase_untargetable(delta)
			elif _brain != null:
				_brain.drive(delta)
			elif data.rank == EnemyData.Rank.FODDER:
				_drive_fodder(delta)
			elif naive_casting and _try_cast_ability():
				pass  # its brain switched off: the old routine
			elif attack.target != _player:
				attack.attack(_player)
		AI.RETURN:
			_drive_return(delta)


## A party member it could pick, in sight (WorldQuery, layer 1: ledges don't
## block it) within detect_range (edge to edge), that it has a path to: the
## nearest, or null. Sight alone never wakes it on a champion it can't reach
## (found building AI2: on a perch with no way up, a pack would wake, give
## up after 6 s, walk home and wake again); a hit from there still does, and
## the leash then sends it home to heal.
func _notice() -> Unit:
	var best: Unit = null
	var best_d := INF
	var range_px := Units.to_px(detect_range)
	for u in Brains.get_party():
		if not can_pick(u):
			continue
		var d := edge_distance_to(u)
		if d > range_px or d >= best_d:
			continue
		if not WorldQuery.has_line_of_sight(global_position, u.global_position):
			continue
		if not _can_reach_unit(u):
			continue
		best = u
		best_d = d
	return best


## A path gets it within its reach of `u` (Enemy._path_reaches()), checked at
## most every reach_check_time s per unit.
func _can_reach_unit(u: Unit) -> bool:
	var now := Brains.get_time()
	var cached: Array = _notice_reach.get(u, [])
	if not cached.is_empty() and now < float(cached[1]):
		return cached[0]
	var ok := _path_reaches(u)
	_notice_reach[u] = [ok, now + Brains.table.reach_check_time]
	return ok


## It notices `target` (or is hit by it): aggroed at once, with its alert
## pose; with `shout`, its pack and the packs near it wake alert_delay s later
## (Brains.shout()). Already fighting, it only learns of `target`.
func _wake(target: Unit, shout: bool) -> void:
	if not is_instance_valid(target):
		return
	if not _known.has(target):
		_known.append(target)
	if ai == AI.AGGRO:
		return
	if ai == AI.RETURN:
		_end_return()
	ai = AI.AGGRO
	_alert_left = Brains.table.alert_pose_time
	if movement.has_order():
		movement.stop()
	_update_pick(0.0, true)
	if _brain != null:
		Brains.wake(_brain)
	if shout:
		Brains.shout(self, target)


## A shout reached it (Brains: its packmate's, or a pack's nearby): it wakes on
## `target` without shouting on. Walking home, it ignores a shout for
## return_ignore_time s, and always one about a target outside its leash.
func alert(target: Unit) -> void:
	if data == null or not is_alive() or passive or not is_instance_valid(target):
		return
	if ai == AI.RETURN and (_return_ignore_left > 0.0 or not is_inside_leash(target)):
		return
	_wake(target, false)


## A hit: it wakes on its attacker and shouts, or learns of it while fighting.
## Walking home, a hit turns it around only from inside the leash.
func _on_damaged_pack(source: Unit) -> void:
	if not is_instance_valid(source) or not is_alive() or not is_enemy_of(source):
		return
	if ai == AI.RETURN and not is_inside_leash(source):
		return
	_wake(source, true)


## ALLIES' target pick (ALLIES.md, How enemies pick a target), every think
## (10 a second) and at once when its target stops being one. The candidates:
## the party members it knows (and any it sees now) that it could pick
## (can_pick()). A taunt wins. Otherwise the nearest by effective distance
## (edge ÷ threat), sticky: a switch only past the margin (is_better_target())
## held switch_hold_time s, never mid-windup or mid-cast. Down, stealthed,
## dead or out of the leash: dropped at once. Only untargetable (AB10): kept
## and chased, not attacked, while nobody else is a candidate.
func _update_pick(delta: float, force: bool = false) -> void:
	_pick_left -= delta
	var current := get_target()
	var dropped := current != null and not can_pick(current) and not _is_chased(current)
	if not force and not dropped and _pick_left > 0.0:
		return
	var table := Brains.table
	_pick_left = 1.0 / maxf(table.think_rate, 0.01)
	var range_px := Units.to_px(detect_range)
	for u in Brains.get_party():
		if not _known.has(u) and can_pick(u) and edge_distance_to(u) <= range_px \
				and WorldQuery.has_line_of_sight(global_position, u.global_position):
			_known.append(u)
	var candidates: Array[Unit] = []
	for i in range(_known.size() - 1, -1, -1):
		var k: Variant = _known[i]
		if not is_instance_valid(k) or not (k as Unit).is_alive():
			_known.remove_at(i)
		elif can_pick(k):
			candidates.append(k)
	var taunter := get_taunter()
	if taunter != null and candidates.has(taunter):
		_set_target(taunter)
		return
	if current != null and not candidates.has(current):
		if not (candidates.is_empty() and _is_chased(current)):
			_set_target(null)
			current = null
	if candidates.is_empty():
		return
	var best: Unit = candidates[0]
	for u in candidates:
		if get_effective_distance(u) < get_effective_distance(best):
			best = u
	if current == null:
		_set_target(best)
		return
	if best == current or not is_better_target(get_effective_distance(current), get_effective_distance(best), table):
		_switch_to = null
		return
	var now := Brains.get_time()
	if _switch_to != best:
		_switch_to = best
		_switch_since = now
	elif now - _switch_since >= table.switch_hold_time - 0.0001 and not attack.is_winding_up() \
			and not (abilities != null and abilities.casting):
		_set_target(best)


## Its target turned untargetable (AB10): kept and chased, not attacked, while
## it's alive, not down or stealthed, and inside the leash.
func _is_chased(u: Unit) -> bool:
	return is_instance_valid(u) and u.is_alive() and not u.is_targetable() and not _has_tag(u, &"stealth") \
		and not _has_tag(u, &"downed") and is_inside_leash(u)


func _set_target(u: Unit) -> void:
	_switch_to = null
	var was := get_target()
	_target = u
	if u == was:
		return
	_player = u
	Brains.release_token(self, false)
	if attack.target != null and attack.target != u and not attack.is_winding_up():
		attack.cancel()
	if _brain != null:
		Brains.wake(_brain)


## Fodder (no brain; ENEMIES_AI.md, Groups): it walks to its place in the ring
## around its target (Brains, 5 times a second) and attacks once there and in
## reach; a place out of its reach (an outer ring) waits there. Settled, it
## attacks from where it stands while its target stays within
## FODDER_FIRM_REACH_SHARE of its reach (it doesn't chase its place for every
## small push), then walks to its place again (at the edge of its reach every
## swing would whiff as other hits push its target about). Blocked short of
## its place for FODDER_BLOCKED_TIME s with its target in reach, it settles
## where it is, until its target leaves its reach. Standing too close to another fodder (Brains' ring think), the
## one farther from its place walks to it. Before its first place (the first
## pack think) it chases as before. No tokens.
func _drive_fodder(delta: float) -> void:
	if attack.is_winding_up() or (abilities != null and abilities.casting):
		return
	var spot := _ring_spot
	var in_reach := attack.is_in_range(_target)
	if spot == Vector2.INF:
		if attack.target != _target:
			attack.attack(_target)
		return
	var at_spot := global_position.distance_to(spot) <= Brains.table.fodder_ring_tolerance_px
	var firm := edge_distance_to(_target) <= attack.get_range_px() * FODDER_FIRM_REACH_SHARE
	var stuck := global_position.distance_to(_ring_last_pos) < 0.5
	_ring_last_pos = global_position
	_ring_blocked = _ring_blocked + delta if not _ring_settled and in_reach and not at_spot and stuck else 0.0
	if at_spot:
		_ring_settled = true
		_ring_stuck = false
	elif _ring_blocked >= FODDER_BLOCKED_TIME:
		_ring_settled = true
		_ring_stuck = true
	elif not in_reach or (not _ring_stuck and not firm):
		_ring_settled = false   # pushed to the edge of its reach, its swings would whiff: back to its place
		_ring_stuck = false
	if _ring_settled and in_reach:
		if attack.target != _target:
			attack.attack(_target)
		return
	if attack.target != null:
		attack.cancel()
	if at_spot:
		if movement.has_order():
			movement.stop()
		return   # an outer ring's place: it waits there
	_ring_repath -= delta
	if _ring_repath <= 0.0:
		_ring_repath = Brains.table.hold_replan_time
		movement.move_to(_fodder_walk_goal(spot))


## Where a fodder walks toward its place: straight to it, or, when its place
## is more than FODDER_DETOUR_DEG round the ring, a step round the outside of
## the ring that way (a path straight through its target and the settled ones
## gets stuck).
func _fodder_walk_goal(spot: Vector2) -> Vector2:
	var center := _target.global_position
	var to_spot := spot - center
	var to_me := global_position - center
	var arc := wrapf(to_spot.angle() - to_me.angle(), -PI, PI)
	var detour := deg_to_rad(FODDER_DETOUR_DEG)
	if absf(arc) <= detour:
		return spot
	var outside := to_spot.length() + 2.0 * get_gameplay_radius_px() + Brains.table.fodder_ring_spacing_px
	return center + Vector2.from_angle(to_me.angle() + signf(arc) * detour) * outside


## The leash (its pack gave up; Ryan, I5): it drops the fight and walks home
## (a cast plays out first), return_speed_ratio × its speed.
func start_return() -> void:
	if data == null or not is_alive() or ai == AI.RETURN:
		return
	ai = AI.RETURN
	_target = null
	_player = null
	_known.clear()
	_switch_to = null
	_ring_spot = Vector2.INF
	_ring_settled = false
	_alert_left = 0.0
	Brains.release_token(self, false)
	attack.cancel()
	var table := Brains.table
	_return_ignore_left = table.return_ignore_time
	_return_repath = 0.0
	_recovering = false
	stats_component.remove_modifiers_from(RETURN_SOURCE_ID)
	stats_component.add_modifier(StatModifier.create(&"move_speed", StatModifier.Type.PERCENT_ADD, table.return_speed_ratio - 1.0, RETURN_SOURCE_ID))


## Walking home: new aggro is ignored for return_ignore_time s, then only a
## party member inside the leash wakes it (a hit from inside the leash does at
## any time: _on_damaged_pack()). Home, the statuses others put on it clear
## and it heals to full over recover_time s, then idles there.
func _drive_return(delta: float) -> void:
	_return_ignore_left = maxf(_return_ignore_left - delta, 0.0)
	if _return_ignore_left <= 0.0:
		var seen := _notice()
		if seen != null:
			_wake(seen, true)
			return
	if abilities != null and abilities.casting:
		return
	if _recovering:
		health.heal(minf(_recover_rate * delta, health.max_health - health.current))
		if health.current >= health.max_health - 0.001:
			_end_return()
			_enter_idle()
		return
	var to_home := global_position.distance_to(_home)
	if to_home <= RETURN_ARRIVE_PX or (to_home <= get_pathing_radius_px() * 3.0 and not movement.has_order()):
		_arrive_home()
		return
	_return_repath -= delta
	if _return_repath <= 0.0:
		_return_repath = 0.5
		movement.move_to(_home)


func _arrive_home() -> void:
	_recovering = true
	movement.stop()
	stats_component.remove_modifiers_from(RETURN_SOURCE_ID)
	if status_component != null:
		for id in status_component.get_status_ids():
			if status_component.get_source(id) != self:
				status_component.remove_status(id)
	var missing := health.max_health - health.current
	_recover_rate = missing / maxf(Brains.table.recover_time, 0.01)
	if missing <= 0.0:
		_end_return()
		_enter_idle()


func _end_return() -> void:
	_recovering = false
	_return_ignore_left = 0.0
	stats_component.remove_modifiers_from(RETURN_SOURCE_ID)
