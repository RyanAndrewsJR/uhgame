class_name CombatSounds
extends Node
## Turns combat events into sounds (AUDIO.md, CombatSounds). A child of the
## Audio autoload, created in Audio._ready(). The only place hit and death
## sounds are played; combat code never plays them itself.
##
## - Events.unit_hit: the hit sound (the swing's or ability's own, else
##   HitFeel's tier; nothing on the player, whose hurt sound covers it), once
##   per source, sound and frame, so a swing or cast plays one however many it
##   hits. A crit layer, the shield absorb sound. DoT ticks are silent.
## - Events.unit_damaged: the target's hurt sound when it lost health.
## - Events.unit_died: death sounds, batched at the end of the frame. When
##   AudioMix.pack_burst_count enemies die within pack_burst_window (real
##   time), the death that makes the count plays the pack burst instead of its
##   own sound, and later deaths in the window are silent.
## - Events.status_applied / status_removed: the status's apply sound (every
##   application), one loop per unit and status (not per stack), and the
##   expire sound when it ends while the unit is alive (A3).
## Priority: HIGH when the Player is the source or the target, else LOW.

var _frame_key: String = ""
var _played: Dictionary = {}           # "<source>|<sound>" -> true, this frame
var _pending_deaths: Array = []        # [Unit, position, death_sound], this frame
var _recent_death_ms: Array[int] = []  # enemy deaths within the burst window
var _burst_ms: int = -1000000          # when the last pack burst played
var _status_loops: Dictionary = {}     # "<unit id>|<status id>" -> handle


func _ready() -> void:
	Events.unit_hit.connect(_on_events_unit_hit)
	Events.unit_damaged.connect(_on_events_unit_damaged)
	Events.unit_died.connect(_on_events_unit_died)
	Events.status_applied.connect(_on_events_status_applied)
	Events.status_removed.connect(_on_events_status_removed)


## Forgets the pack burst window and this frame's pending deaths (a scene
## restart; Audio.stop_all() calls it).
func reset() -> void:
	_pending_deaths.clear()
	_recent_death_ms.clear()
	_burst_ms = -1000000
	_played.clear()
	_status_loops.clear()


# --- Hits ---------------------------------------------------------------------

func _on_events_unit_hit(ctx: HitContext) -> void:
	if ctx.blocked or ctx.has_tag(&"dot"):
		return
	var target := ctx.target as Node2D
	if target == null:
		return
	var source: Unit = ctx.source if is_instance_valid(ctx.source) else null
	var priority := _hit_priority(source, target)
	var feel := GameFeel.hit_feel
	var sound := ctx.hit_sound
	if sound == null and not target is Player:
		if ctx.killed:
			sound = feel.kill_sound
		elif ctx.feel == HitContext.Feel.HEAVY:
			sound = feel.heavy_sound
		else:
			sound = feel.light_sound   # LIGHT and NONE
	_play_once(sound, source, target.global_position, ctx.hit_sound_pitch, priority)
	if ctx.is_crit:
		_play_once(feel.crit_sound, source, target.global_position, 1.0, priority)
	if ctx.absorbed > 0.0:
		Audio.play_at(feel.shield_absorb_sound, target.global_position, source, 1.0, priority)


func _on_events_unit_damaged(ctx: HitContext) -> void:
	var target := ctx.target as Unit
	if target == null or target.hurt_sound == null or ctx.health_lost <= 0.0:
		return
	Audio.play_at(target.hurt_sound, target.global_position, target, 1.0, SoundEvent.Priority.HIGH)


## One play per (source, sound) per frame: later hits of the same swing or
## cast are skipped.
func _play_once(sound: SoundEvent, source: Unit, position: Vector2, pitch: float, priority: int) -> void:
	if sound == null:
		return
	var frame := ("p%d" % Engine.get_physics_frames()) if Engine.is_in_physics_frame() else ("f%d" % Engine.get_process_frames())
	if frame != _frame_key:
		_frame_key = frame
		_played.clear()
	var key := "%d|%d" % [source.get_instance_id() if source != null else 0, sound.get_instance_id()]
	if _played.has(key):
		return
	_played[key] = true
	Audio.play_at(sound, position, source, pitch, priority)


func _hit_priority(source: Unit, target: Node) -> int:
	if source is Player or target is Player:
		return SoundEvent.Priority.HIGH
	return SoundEvent.Priority.LOW


# --- Deaths -------------------------------------------------------------------

func _on_events_unit_died(unit: Unit, _ctx: HitContext) -> void:
	if unit is Player:
		Audio.play_at(unit.death_sound, unit.global_position, unit, 1.0, SoundEvent.Priority.HIGH)
		return
	if unit.team != Unit.Team.ENEMY:
		Audio.play_at(unit.death_sound, unit.global_position, unit)
		return
	if _pending_deaths.is_empty():
		_flush_deaths.call_deferred()   # at the end of this frame, still this frame
	_pending_deaths.append([unit, unit.global_position, unit.death_sound])


func _flush_deaths() -> void:
	if _pending_deaths.is_empty():
		return
	var deaths := _pending_deaths.duplicate()
	_pending_deaths.clear()
	var mix := Audio.mix
	var now := Time.get_ticks_msec()
	var window_ms := mix.pack_burst_window * 1000.0
	for i in deaths.size():
		_recent_death_ms.append(now)
	_recent_death_ms = _recent_death_ms.filter(func(t: int) -> bool: return now - t < window_ms)

	if mix.pack_burst_sound != null:
		if now - _burst_ms < window_ms:
			return   # a burst just played: this frame's deaths are part of it
		if _recent_death_ms.size() >= mix.pack_burst_count:
			var center := Vector2.ZERO
			for d in deaths:
				center += d[1] as Vector2
			_burst_ms = now
			Audio.play_at(mix.pack_burst_sound, center / deaths.size())
			return
	for d in deaths:
		var unit: Unit = d[0] if is_instance_valid(d[0]) else null
		Audio.play_at(d[2] as SoundEvent, d[1] as Vector2, unit)


# --- Statuses -------------------------------------------------------------------

func _on_events_status_applied(unit: Unit, status: StatusEffect) -> void:
	var priority: int = SoundEvent.Priority.HIGH if unit is Player else -1
	Audio.play_at(status.apply_sound, unit.global_position, unit, 1.0, priority)
	if status.loop_sound == null:
		return
	var key := _status_key(unit, status)
	if not Audio.is_playing(_status_loops.get(key, 0)):   # a refresh or new stack keeps the running loop
		_status_loops[key] = Audio.play_on(status.loop_sound, unit, 1.0, priority)


func _on_events_status_removed(unit: Unit, status: StatusEffect) -> void:
	var key := _status_key(unit, status)
	Audio.stop(_status_loops.get(key, 0))
	_status_loops.erase(key)
	if is_instance_valid(unit) and unit.is_alive():   # the death clear() is silent
		var priority: int = SoundEvent.Priority.HIGH if unit is Player else -1
		Audio.play_at(status.expire_sound, unit.global_position, unit, 1.0, priority)


func _status_key(unit: Unit, status: StatusEffect) -> String:
	return "%d|%s" % [unit.get_instance_id(), status.id]
