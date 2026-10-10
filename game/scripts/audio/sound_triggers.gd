class_name SoundTriggers
extends Node
## Plays sound triggers (AUDIO.md, Sound triggers and the tuning panel; built
## in A6a): the SoundTriggers in a unit's SoundSheet. A child of Audio beside
## CombatSounds, so a game rule never plays a sound itself: this listens.
## - watch(unit, sheet): a Player at its champion's load, an Enemy at its
##   data's (or a test); unwatch(unit) when it leaves the tree (watch()
##   connects that). Its swings, casts and dash per unit; Events once for all.
## - A match: the event's filters, the conditions, once per frame, every Nth,
##   the cooldown (real time), the chance (Audio.rng); then it plays now, at
##   its progress point (checked each physics tick while that swing or cast
##   runs; a cancel or an interrupt drops it) or after its delay (real time,
##   paused with the tree: this node is PAUSABLE).
## - Places: SoundTrigger.Place. The Player's sounds are centered (AUDIO.md,
##   Rules) but a HIT_DEALT at the other unit (Ryan, 2026-10-10); any other
##   place on a Player's sheet plays centered, warned once per trigger.
## - Plays go through Audio.play_triggered(): limits, the voice cap, priority
##   (HIGH when the Player is the unit or the other unit) and the log's
##   `trigger`.

## A watched unit and its per-trigger state.
class Watch:
	extends RefCounted
	var unit: Unit
	var sheet: SoundSheet
	var is_player: bool = false
	var links: Array = []            # [Signal, Callable], disconnected by unwatch()
	var last_ms: Dictionary = {}     # SoundTrigger -> its last match that played (real ms)
	var counts: Dictionary = {}      # SoundTrigger -> matches so far (every_nth)
	var frames: Dictionary = {}      # SoundTrigger -> physics frame of its last match
	var tracks_stacks: bool = false  # the sheet has a STACKS_REACHED trigger
	var stacks: Dictionary = {}      # status id -> stacks last seen
	var sources: Dictionary = {}     # status id -> who applied it (for STATUS_ENDED)
	var swing_cancelled: bool = false
	var empowers_frame: int = -1     # the physics frame of empowers_used
	var empowers_used: Dictionary = {}  # empower id -> true: used by his hits that frame (a swing's landing)


## What an event gives a trigger: who, where, which cast. Positions are
## taken at the event (refreshed at a progress point).
class Fire:
	extends RefCounted
	var unit: Unit
	var is_player: bool = false
	var other: Unit
	var other_is_player: bool = false
	var cast: CastContext
	var self_pos: Vector2 = Vector2.INF
	var other_pos: Vector2 = Vector2.INF
	var aim: Vector2 = Vector2.INF


## A match waiting for its swing's or cast's progress point, or its delay.
class Pending:
	extends RefCounted
	var trigger: SoundTrigger
	var watch: Watch
	var fire: Fire
	var swing: AttackSwing
	var cast: CastContext
	var left: float = 0.0   # delay left, real seconds

var _watches: Dictionary = {}               # Unit -> Watch
var _progress: Array[Pending] = []
var _delays: Array[Pending] = []
var _warned: Dictionary = {}                # SoundTrigger -> true
var _last_usec: int = 0                     # the last _process (real time, for delays)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE   # delays wait through the pause (Audio itself is ALWAYS)
	Events.unit_hit.connect(_on_events_unit_hit)
	Events.unit_died.connect(_on_events_unit_died)
	Events.status_applied.connect(_on_events_status_applied)
	Events.status_ended.connect(_on_events_status_ended)
	Events.ability_cast.connect(_on_events_ability_cast)
	Events.hit_deflected.connect(_on_events_hit_deflected)


# --- Watching -------------------------------------------------------------------

## Plays `sheet`'s triggers for `unit` from now on (replacing a sheet it
## had). A unit not ready yet is watched once it is.
func watch(unit: Unit, sheet: SoundSheet) -> void:
	if unit == null or sheet == null:
		return
	if not unit.is_node_ready():
		unit.ready.connect(watch.bind(unit, sheet), CONNECT_ONE_SHOT)
		return
	unwatch(unit)
	var w := Watch.new()
	w.unit = unit
	w.sheet = sheet
	w.is_player = unit is Player
	_link(w, unit.tree_exiting, unwatch.bind(unit))
	if unit.attack != null:
		_link(w, unit.attack.swing_started, _on_swing_started.bind(w))
		_link(w, unit.attack.swing_landed, _on_swing_landed.bind(w))
		_link(w, unit.attack.swing_cancelled, _on_swing_cancelled.bind(w))
	if unit.abilities != null:
		_link(w, unit.abilities.cast_started, _on_cast_started.bind(w))
		_link(w, unit.abilities.cast_finished, _on_cast_finished.bind(w))
	var dash: DashComponent = unit.get(&"dash") as DashComponent
	if dash != null:
		_link(w, dash.dash_started, _on_dash_started.bind(w))
	for t in sheet.triggers:
		if t != null and t.event == SoundTrigger.Event.STACKS_REACHED:
			w.tracks_stacks = true
	if w.is_player:
		_warn_player_places(sheet)
	_watches[unit] = w


## Stops playing `unit`'s triggers. Its progress points go; its delays stay
## (an AT_ place still plays; ON_SELF doesn't, its unit gone).
func unwatch(unit: Unit) -> void:
	var w: Watch = _watches.get(unit)
	if w == null:
		return
	for link: Array in w.links:
		var sig: Signal = link[0]
		if not sig.is_null() and sig.is_connected(link[1]):
			sig.disconnect(link[1])
	_watches.erase(unit)
	_progress = _progress.filter(func(p: Pending) -> bool: return p.watch != w)


func is_watching(unit: Unit) -> bool:
	return _watches.has(unit)


## The sheet `unit` plays, or null.
func get_sheet(unit: Unit) -> SoundSheet:
	var w: Watch = _watches.get(unit)
	return w.sheet if w != null else null


## Drops every waiting progress point and delay (Audio.stop_all(): a scene
## restart).
func reset() -> void:
	_progress.clear()
	_delays.clear()


func _link(w: Watch, sig: Signal, callable: Callable) -> void:
	sig.connect(callable)
	w.links.append([sig, callable])


## A Player's trigger placed anywhere but its impact plays centered: said
## once per trigger (AUDIO.md, Rules).
func _warn_player_places(sheet: SoundSheet) -> void:
	for t in sheet.triggers:
		if t == null or _warned.has(t):
			continue
		if t.place != SoundTrigger.Place.DEFAULT and t.place != SoundTrigger.Place.CENTERED and not t.is_placed_impact():
			_warned[t] = true
			push_warning("SoundTrigger '%s': on a Player's sheet it plays centered; only a HIT_DEALT may sit at the other unit (AUDIO.md)" % t.get_label())


# --- Unit signals ---------------------------------------------------------------

func _on_swing_started(index: int, _direction: Vector2, swing: AttackSwing, w: Watch) -> void:
	_end_swing_waits(w, true)   # a new swing: the last one ran to its end
	w.swing_cancelled = false
	var other: Unit = w.unit.attack.get_assist_target()
	var carried := {}   # used_empower: the empowers this swing would use (their scope admits it: CHAMPIONS K5c)
	for e in w.unit.attack.get_swing_empowers(swing, index < 0):
		carried[e.id] = true
	_match(w, SoundTrigger.Event.SWING_START, _fire(w, other), {"swing_index": index, "carried": carried}, swing, null)


func _on_swing_landed(index: int, targets: Array[Unit], w: Watch) -> void:
	if targets.is_empty():
		_match(w, SoundTrigger.Event.SWING_WHIFF, _fire(w, null), {"swing_index": index})
	else:
		var used: Dictionary = w.empowers_used if w.empowers_frame == Engine.get_physics_frames() else {}
		_match(w, SoundTrigger.Event.SWING_LANDED, _fire(w, targets[0]), {"swing_index": index, "used": used})


func _on_swing_cancelled(w: Watch) -> void:
	w.swing_cancelled = true
	_end_swing_waits(w, false)


func _on_cast_started(_slot: StringName, ability: Ability, ctx: CastContext, w: Watch) -> void:
	var fire := _fire(w, ctx.target if is_instance_valid(ctx.target) else null, ctx)
	_match(w, SoundTrigger.Event.CAST_START, fire, {"ability": ability, "part": ctx.part}, null, ctx)


## The cast is over: a progress point it reached plays (its effect started:
## progress 1), one it didn't (cancelled, interrupted) is dropped.
func _on_cast_finished(slot: StringName, ability: Ability, w: Watch) -> void:
	for p: Pending in _progress.duplicate():
		if p.watch == w and p.cast != null and p.cast.slot == slot and p.cast.ability == ability:
			_progress.erase(p)
			if p.cast.progress >= p.trigger.at_progress:
				_reached(p)


func _on_dash_started(_direction: Vector2, w: Watch) -> void:
	_match(w, SoundTrigger.Event.DASH, _fire(w, null), {})


# --- Events -----------------------------------------------------------------------

func _on_events_unit_hit(ctx: HitContext) -> void:
	var target := ctx.target as Unit
	var source_watch: Watch = _watches.get(ctx.source) if is_instance_valid(ctx.source) else null
	if source_watch != null and not ctx.empowers_used.is_empty():   # for SWING_LANDED's used_empower (blocked hits too: the empower is spent)
		var frame := Engine.get_physics_frames()
		if source_watch.empowers_frame != frame:
			source_watch.empowers_frame = frame
			source_watch.empowers_used = {}
		for e in ctx.empowers_used:
			if e != null:
				source_watch.empowers_used[e.id] = true
	if ctx.blocked:
		return
	if source_watch != null:
		_match(source_watch, SoundTrigger.Event.HIT_DEALT, _fire(source_watch, target, ctx.cast), {"hit": ctx})
	var target_watch: Watch = _watches.get(target) if is_instance_valid(target) else null
	if target_watch != null:
		var source: Unit = ctx.source if is_instance_valid(ctx.source) else null
		_match(target_watch, SoundTrigger.Event.HIT_TAKEN, _fire(target_watch, source, ctx.cast), {"hit": ctx})


func _on_events_unit_died(unit: Unit, ctx: HitContext) -> void:
	var killer: Unit = ctx.source if ctx != null and is_instance_valid(ctx.source) else null
	var killer_watch: Watch = _watches.get(killer) if killer != null else null
	if killer_watch != null:
		_match(killer_watch, SoundTrigger.Event.KILL, _fire(killer_watch, unit), {})
	var own: Watch = _watches.get(unit)
	if own != null:
		_match(own, SoundTrigger.Event.DIED, _fire(own, killer), {})


func _on_events_status_applied(unit: Unit, status: StatusEffect) -> void:
	var w: Watch = _watches.get(unit)
	if w == null or unit.status_component == null:
		return
	var source := unit.status_component.get_source(status.id)
	w.sources[status.id] = source
	_match(w, SoundTrigger.Event.STATUS_GAINED, _fire(w, source), {"status": status})
	if w.tracks_stacks:
		var now := unit.status_component.get_stacks(status.id)
		var before: int = w.stacks.get(status.id, maxi(now - 1, 0))   # one application adds one stack at most
		w.stacks[status.id] = now
		_match(w, SoundTrigger.Event.STACKS_REACHED, _fire(w, source), {"status": status, "before": before, "now": now})


func _on_events_status_ended(unit: Unit, status: StatusEffect, reason: StatusEffect.EndReason) -> void:
	var w: Watch = _watches.get(unit)
	if w == null:
		return
	var source: Unit = w.sources.get(status.id)
	w.sources.erase(status.id)
	if w.tracks_stacks:
		w.stacks[status.id] = 0
	_match(w, SoundTrigger.Event.STATUS_ENDED, _fire(w, source if is_instance_valid(source) else null),
		{"status": status, "reason": reason})


func _on_events_ability_cast(unit: Unit, ability: Ability, ctx: CastContext) -> void:
	var w: Watch = _watches.get(unit)
	if w == null:
		return
	var target: Unit = ctx.target if ctx != null and is_instance_valid(ctx.target) else null
	_match(w, SoundTrigger.Event.CAST_EFFECT, _fire(w, target, ctx), {"ability": ability, "part": ctx.part if ctx != null else 0})


func _on_events_hit_deflected(attacker: Unit, defender: Unit, _ctx: HitContext) -> void:
	var w: Watch = _watches.get(defender)
	if w != null:
		_match(w, SoundTrigger.Event.DEFLECT, _fire(w, attacker if is_instance_valid(attacker) else null), {})


# --- Matching ---------------------------------------------------------------------

func _fire(w: Watch, other: Unit, cast: CastContext = null) -> Fire:
	var f := Fire.new()
	f.unit = w.unit
	f.is_player = w.is_player
	f.self_pos = w.unit.global_position
	if is_instance_valid(other):
		f.other = other
		f.other_is_player = other is Player
		f.other_pos = other.global_position
	f.cast = cast
	if cast != null and cast.point != Vector2.INF:
		f.aim = cast.point
	return f


## Every enabled trigger of `event` on the sheet whose filters and
## conditions pass, then once per frame, every Nth, the cooldown and the
## chance, in that order.
func _match(w: Watch, event: SoundTrigger.Event, fire: Fire, info: Dictionary, swing: AttackSwing = null, cast: CastContext = null) -> void:
	for t in w.sheet.triggers:
		if t == null or not t.enabled or t.event != event:
			continue
		if not _passes(t, info):
			continue
		if not t.conditions.is_empty() and not Condition.all_met(t.conditions, w.unit, fire.other, fire.cast):
			continue
		var frame := Engine.get_physics_frames()
		if t.once_per_frame and w.frames.get(t, -1) == frame:
			continue
		w.frames[t] = frame
		var count: int = w.counts.get(t, 0) + 1
		w.counts[t] = count
		if t.every_nth > 1 and count % t.every_nth != 0:
			continue
		var now := Time.get_ticks_msec()
		if t.cooldown > 0.0 and w.last_ms.has(t) and now - int(w.last_ms[t]) < roundi(t.cooldown * 1000.0):
			continue
		if t.chance < 1.0 and Audio.rng.randf() >= t.chance:
			continue
		w.last_ms[t] = now
		_schedule(t, w, fire, swing, cast)


func _passes(t: SoundTrigger, info: Dictionary) -> bool:
	match t.event:
		SoundTrigger.Event.SWING_START, SoundTrigger.Event.SWING_LANDED, SoundTrigger.Event.SWING_WHIFF:
			var index: int = info.get("swing_index", 0)
			if t.swing_number == -1 and index != -1:
				return false
			if t.swing_number > 0 and index != t.swing_number - 1:
				return false
			if t.used_empower != &"":   # a swing start: this swing carries it (he holds it and its scope admits the swing); a landing: its hits used it; a whiff: never
				match t.event:
					SoundTrigger.Event.SWING_START:
						if not (info.get("carried", {}) as Dictionary).has(t.used_empower):
							return false
					SoundTrigger.Event.SWING_LANDED:
						if not (info.get("used", {}) as Dictionary).has(t.used_empower):
							return false
					_:
						return false
		SoundTrigger.Event.CAST_START, SoundTrigger.Event.CAST_EFFECT:
			if not _ability_matches(t, info.get("ability")):
				return false
			if t.part >= 0 and int(info.get("part", 0)) != t.part:
				return false
		SoundTrigger.Event.HIT_DEALT, SoundTrigger.Event.HIT_TAKEN:
			var hit: HitContext = info.hit
			if hit.has_tag(&"dot") and not t.hit_tags.has(&"dot"):
				return false   # DoT ticks only when asked for
			if not _ability_matches(t, hit.ability):
				return false
			for tag in t.hit_tags:
				if not hit.has_tag(tag):
					return false
			if t.used_empower != &"" and not _used_empower(hit, t.used_empower):
				return false
			if (t.crit_only and not hit.is_crit) or (t.kill_only and not hit.killed):
				return false
		SoundTrigger.Event.STATUS_GAINED, SoundTrigger.Event.STATUS_ENDED, SoundTrigger.Event.STACKS_REACHED:
			var status: StatusEffect = info.status
			if t.status_id != &"" and status.id != t.status_id:
				return false
			if t.status_tag != &"" and not status.tags.has(t.status_tag):
				return false
			if t.event == SoundTrigger.Event.STATUS_ENDED and t.end_reason != SoundTrigger.EndFilter.ANY \
					and int(info.reason) + 1 != int(t.end_reason):
				return false
			if t.event == SoundTrigger.Event.STACKS_REACHED:
				var before: int = info.before
				var now: int = info.now
				if now <= before:
					return false
				if t.stacks > 0 and not (before < t.stacks and now >= t.stacks):
					return false
	return true


func _ability_matches(t: SoundTrigger, ability: Variant) -> bool:
	if t.ability_id == &"":
		return true
	var a := ability as Ability
	if a == null:
		return false
	return a.id == t.ability_id or (t.include_variants and a.variant_of == t.ability_id)


## The hit used empower `id`: a swing's HitContext.empowers_used, a cast's
## CastContext.empowers.
func _used_empower(hit: HitContext, id: StringName) -> bool:
	for e in hit.empowers_used:
		if e != null and e.id == id:
			return true
	if hit.cast != null:
		for e in hit.cast.empowers:
			if e != null and e.id == id:
				return true
	return false


# --- Timing -----------------------------------------------------------------------

func _schedule(t: SoundTrigger, w: Watch, fire: Fire, swing: AttackSwing, cast: CastContext) -> void:
	if t.at_progress >= 0.0 and (swing != null or cast != null):
		var reached := (cast != null and cast.progress >= t.at_progress) or (swing != null and t.at_progress <= 0.0)
		if not reached:
			var p := Pending.new()
			p.trigger = t
			p.watch = w
			p.fire = fire
			p.swing = swing
			p.cast = cast
			_progress.append(p)
			return
	_after_point(t, fire)


## Its progress point (or the event): now, or after its delay.
func _after_point(t: SoundTrigger, fire: Fire) -> void:
	if t.delay > 0.0:
		var p := Pending.new()
		p.trigger = t
		p.fire = fire
		p.left = t.delay
		_delays.append(p)
		return
	_play(t, fire)


## A progress point reached: positions as they are now, then its delay.
func _reached(p: Pending) -> void:
	if is_instance_valid(p.fire.unit):
		p.fire.self_pos = p.fire.unit.global_position
	if is_instance_valid(p.fire.other):
		p.fire.other_pos = p.fire.other.global_position
	_after_point(p.trigger, p.fire)


## The swing's waits end: `ran_out` (it ended on its own, so it reached
## every point) plays them, a cancel drops them.
func _end_swing_waits(w: Watch, ran_out: bool) -> void:
	for p: Pending in _progress.duplicate():
		if p.watch == w and p.swing != null:
			_progress.erase(p)
			if ran_out:
				_reached(p)


func _notification(what: int) -> void:
	if what == NOTIFICATION_UNPAUSED:
		_last_usec = Time.get_ticks_usec()   # the pause doesn't count


func _physics_process(_delta: float) -> void:
	for w: Watch in _watches.values():
		if w.tracks_stacks and is_instance_valid(w.unit) and w.unit.status_component != null:
			for id: StringName in w.stacks.keys():   # stacks that ran out one by one
				w.stacks[id] = w.unit.status_component.get_stacks(id)
	for p: Pending in _progress.duplicate():
		if not is_instance_valid(p.watch.unit):
			_progress.erase(p)
			continue
		if p.cast != null:
			if p.cast.progress >= p.trigger.at_progress:
				_progress.erase(p)
				_reached(p)
			continue
		var attack: AutoAttackComponent = p.watch.unit.attack
		if attack.is_swinging() and attack.get_current_swing() == p.swing:
			if attack.get_swing_progress() >= p.trigger.at_progress:
				_progress.erase(p)
				_reached(p)
		elif not attack.is_swinging() and not p.watch.swing_cancelled:
			_progress.erase(p)   # it ended on its own: every point reached
			_reached(p)


## Delays count real time from the clock (like Audio's limits), so a hitstop
## doesn't stretch them; the pause stops this node, and the clock restarts on
## unpause (NOTIFICATION_UNPAUSED), so the pause doesn't count.
func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real := minf((now - _last_usec) / 1_000_000.0, 0.25) if _last_usec > 0 else 0.0   # a long hitch counts at most 0.25 s
	_last_usec = now
	if _delays.is_empty():
		return
	for p: Pending in _delays.duplicate():
		p.left -= real
		if p.left <= 0.0:
			_delays.erase(p)
			_play(p.trigger, p.fire)


# --- Playing ----------------------------------------------------------------------

## Where `t` plays for this event: DEFAULT is centered for the Player, else
## on him; a Player's sound is centered but a HIT_DEALT at the other unit.
static func get_effective_place(t: SoundTrigger, is_player: bool) -> SoundTrigger.Place:
	if t.place == SoundTrigger.Place.DEFAULT:
		return SoundTrigger.Place.CENTERED if is_player else SoundTrigger.Place.ON_SELF
	if is_player and t.place != SoundTrigger.Place.CENTERED and not t.is_placed_impact():
		return SoundTrigger.Place.CENTERED
	return t.place


func _play(t: SoundTrigger, fire: Fire) -> void:
	if t.sound == null:
		return
	var priority: int = SoundEvent.Priority.HIGH if fire.is_player or fire.other_is_player else -1
	var label := t.get_label()
	var unit_here := is_instance_valid(fire.unit) and fire.unit.is_inside_tree()
	var other_here := is_instance_valid(fire.other) and fire.other.is_inside_tree()
	match get_effective_place(t, fire.is_player):
		SoundTrigger.Place.CENTERED:
			Audio.play_triggered(t.sound, Vector2.ZERO, false, null, t.pitch, t.volume_db, priority, label)
		SoundTrigger.Place.ON_SELF:
			if unit_here:   # its unit gone: not at all
				Audio.play_triggered(t.sound, fire.unit.global_position, true, fire.unit, t.pitch, t.volume_db, priority, label)
		SoundTrigger.Place.AT_SELF:
			Audio.play_triggered(t.sound, fire.self_pos, true, null, t.pitch, t.volume_db, priority, label)
		SoundTrigger.Place.ON_OTHER:
			if other_here:
				Audio.play_triggered(t.sound, fire.other.global_position, true, fire.other, t.pitch, t.volume_db, priority, label)
			else:
				Audio.play_triggered(t.sound, fire.other_pos if fire.other_pos != Vector2.INF else fire.self_pos, true, null, t.pitch, t.volume_db, priority, label)
		SoundTrigger.Place.AT_OTHER:
			Audio.play_triggered(t.sound, fire.other_pos if fire.other_pos != Vector2.INF else fire.self_pos, true, null, t.pitch, t.volume_db, priority, label)
		SoundTrigger.Place.AT_AIM:
			Audio.play_triggered(t.sound, fire.aim if fire.aim != Vector2.INF else fire.self_pos, true, null, t.pitch, t.volume_db, priority, label)
