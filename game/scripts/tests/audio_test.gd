extends Node2D
## AUDIO.md steps A1-A3 test: open res://scenes/tests/audio_test.tscn and press F6.
## Checks the Audio autoload without hearing it (through its log): SoundEvent
## data, the bus layout, null and empty sounds, the instance limit in real
## time (also at Engine.time_scale 0.05), centered vs positional, the
## listener range, handles and stop_all_on() / stop_all(), a play_on() loop
## stopping when its node is freed, the voice cap and priorities, the pause
## (SFX, Ambience and Voice pause; Music ducks and low-passes; UI plays on),
## pitch and playback speed staying real at Engine.time_scale 0.05, the
## volume settings, the log size and debug_draw. The A1 tones are generated
## in code (no files), quiet (-18 dB). At the end it prints the output
## latency (AudioServer.get_output_latency(); 0 ms headless).
## A2: combat sounds with the real data (the placeholder files): the Knight's
## swing sounds and combo pitch, one hit sound per swing, the crit layer,
## silent DoT ticks, hits on the player (hurt only, shield absorb), deaths and
## the pack burst (same frame, spread out, two apart), the elite's death, the
## dash, and silence with every sound field empty.
## A3: ability sounds (casts, one hit sound per cast, the ready ping, not on a
## refund), the elite's telegraph wind-up (positional, 640 px, stops when the
## slam lands, when a stun interrupts it and when the elite dies mid-cast),
## status sounds (apply on every application, one loop per unit however many
## stacks, expire only while alive, the shield's apply and break) and the
## Knight's low-health heartbeat.
## A6a: sound triggers (SoundTrigger, SoundSheet, SoundTriggers): every event,
## every filter, the places (the Player's sounds centered but his impact),
## at_progress on a cast and a swing (a cancel drops it), delays in real time
## (through a hitstop and a pause), once per frame, every Nth, cooldown,
## chance (seeded), off, no sound, volume and pitch; each read from the log's
## `trigger`.
## The Knight's own crit_chance is held at 0 by a test baseline, so a hit
## plays a crit layer only when a check adds crit itself.
## Prints PASS/FAIL per check, then a total.
## Run headless and it quits with the number of failures as the exit code.
## The volume checks save to user://settings.cfg and restore it at the end.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const SLIME_SCENE: PackedScene = preload("res://scenes/enemies/slime.tscn")

var knight: Player
var slime: Enemy

var _passed: int = 0
var _failed: int = 0
var _tone_short: AudioStreamWAV
var _tone_loop: AudioStreamWAV
var _saved_mix: AudioMix
var _saved_volumes: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps running through the pause checks
	_tone_short = _make_tone(0.05, 440.0, false)
	_tone_loop = _make_tone(0.2, 330.0, true)
	_saved_mix = Audio.mix
	Audio.mix = _saved_mix.duplicate()
	for bus in Settings.VOLUME_BUSES:
		_saved_volumes[bus] = Settings.get_volume(bus)
		Settings.set_volume(bus, 1.0)
	await get_tree().physics_frame
	var center := Audio.get_listener_position()
	knight = PLAYER_SCENE.instantiate()
	add_child(knight)
	_place(knight, center)
	slime = SLIME_SCENE.instantiate()
	slime.passive = true
	add_child(slime)
	_place(slime, center + Vector2(100, 0))
	await get_tree().physics_frame
	# The test baseline: the Knight's own crit_chance and life_steal
	# (knight.tres) back to 0, so a hit plays a crit layer only when a check
	# adds crit itself.
	for stat: StringName in [&"crit_chance", &"life_steal"]:
		var base := knight.stats_component.get_base_value(stat)
		if base != 0.0:
			knight.stats_component.add_modifier(StatModifier.create(stat, StatModifier.Type.FLAT, -base, &"test_baseline"))

	print("\n=== Audio test (AUDIO A1) ===")
	_test_data()
	_test_buses()
	_test_null_and_empty()
	await _test_instance_limit()
	await _test_positional()
	await _test_handles()
	_test_voice_cap()
	_test_real_time()
	await _test_pause()
	_test_volumes()
	await _test_log_and_debug()
	await _test_combat_sounds()
	await _test_sound_triggers()   # A6a
	await _measure()

	Audio.stop_all()
	Audio.mix = _saved_mix
	for bus in Settings.VOLUME_BUSES:
		Settings.set_volume(bus, _saved_volumes[bus])
	print("=== %d passed, %d failed ===\n" % [_passed, _failed])
	if DisplayServer.get_name() == "headless":
		get_tree().quit(_failed)


# --- Tests ----------------------------------------------------------------------

func _test_data() -> void:
	_section("SoundEvent and AudioMix data")
	var ev := _event("data", [_tone_short, _tone_loop])
	var stream := ev.get_stream() as AudioStreamRandomizer
	_check("the variations are wrapped in an AudioStreamRandomizer", stream != null, true)
	if stream:
		_check("no-repeat mode, 2 streams", [stream.playback_mode, stream.streams_count],
			[AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS, 2])
		_check_near("pitch jitter 5% = random_pitch 1.05", stream.random_pitch, 1.05, 0.0001)
		_check_near("volume jitter ±1 dB", stream.random_volume_offset_db, 1.0, 0.0001)
	_check("the stream is cached", ev.get_stream() == stream, true)
	ev.pitch_jitter = 0.08
	_check_near("and rebuilt when the jitter changes", (ev.get_stream() as AudioStreamRandomizer).random_pitch, 1.08, 0.0001)
	var defaults := SoundEvent.new()
	_check("SoundEvent defaults: SFX, positional, 480 px, NORMAL, 3 per 0.05 s, no loop",
		[defaults.get_bus_name(), defaults.positional, defaults.max_distance_px, defaults.priority, defaults.max_instances, defaults.min_interval, defaults.loop],
		[&"SFX", true, 480.0, SoundEvent.Priority.NORMAL, 3, 0.05, false])
	_check("no files or only null ones = no usable audio",
		[SoundEvent.new().has_audio(), _event("nulls", [null, null]).has_audio()], [false, false])
	var mix: AudioMix = load("res://data/audio_mixes/audio_mix_default.tres")
	_check("audio_mix_default: cap 32, duck -6 dB, low-pass on",
		[mix.voice_cap, mix.pause_music_duck_db, mix.pause_low_pass], [32, -6.0, true])


func _test_buses() -> void:
	_section("Bus layout (default_bus_layout.tres)")
	var names: Array[StringName] = []
	for i in AudioServer.bus_count:
		names.append(AudioServer.get_bus_name(i))
	_check("six buses in order", names, Settings.VOLUME_BUSES)
	var levels := []
	for bus in Settings.VOLUME_BUSES:
		levels.append(Audio.get_bus_base_db(bus))
	_check("starting levels 0 / -8 / 0 / -4 / -12 / -2 dB", levels, [0.0, -8.0, 0.0, -4.0, -12.0, -2.0])
	var sends := []
	for bus in Settings.VOLUME_BUSES.slice(1):
		sends.append(AudioServer.get_bus_send(AudioServer.get_bus_index(bus)))
	_check("every bus sends to Master", sends, [&"Master", &"Master", &"Master", &"Master", &"Master"])
	var music := AudioServer.get_bus_index(&"Music")
	_check("Music has a low-pass, off while not paused",
		[AudioServer.get_bus_effect(music, 0) is AudioEffectLowPassFilter, AudioServer.is_bus_effect_enabled(music, 0)], [true, false])
	_check_near("pan strength 0.5 (project setting)", ProjectSettings.get_setting("audio/general/2d_panning_strength"), 0.5, 0.0001)


func _test_null_and_empty() -> void:
	_section("Null and empty sounds")
	Audio.clear_log()
	_check("play(null) returns 0 and logs nothing", [Audio.play(null), Audio.play_at(null, Vector2.ZERO), Audio.play_on(null, knight), Audio.get_log().size()], [0, 0, 0, 0])
	var empty := _event("empty", [])
	var a := Audio.play(empty)
	var b := Audio.play(empty)
	var entries := Audio.get_log()
	_check("an event without audio stays silent (logged no_audio twice; warned once, see the output)",
		[a, b, entries.size(), entries[0].reason if entries.size() > 0 else &"", entries[-1].reason if entries.size() > 0 else &""],
		[0, 0, 2, &"no_audio", &"no_audio"])


func _test_instance_limit() -> void:
	_section("Instance limit (3 within 0.05 s, real time)")
	Audio.stop_all()
	Audio.clear_log()
	var ev := _event("limit", [_tone_short])
	var handles := []
	for i in 4:
		handles.append(Audio.play(ev))
	var entries := Audio.get_log()
	_check("4 plays in one frame: 3 played, the 4th dropped",
		[handles[0] > 0, handles[1] > 0, handles[2] > 0, handles[3], entries[-1].result, entries[-1].reason],
		[true, true, true, 0, Audio.RESULT_DROPPED, &"instance_limit"])
	await _real_wait(0.06)
	_check("it plays again after 0.05 s of real time", Audio.play(ev) > 0, true)

	Audio.stop_all()   # also clears the limit history
	Engine.time_scale = 0.05   # a hitstop
	for i in 3:
		Audio.play(ev)
	await get_tree().physics_frame   # about 1/60 s real, 1/1200 s of game time
	_check("at time scale 0.05 the window still counts real time: dropped", Audio.play(ev), 0)
	await _real_wait(0.06)
	_check("and it plays 0.05 s of real time later, though barely any game time passed", Audio.play(ev) > 0, true)
	Engine.time_scale = 1.0
	Audio.stop_all()


func _test_positional() -> void:
	_section("Centered and positional")
	Audio.clear_log()
	var ev := _event("pos", [_tone_short])
	ev.max_instances = 6
	var center := Audio.get_listener_position()
	var h := Audio.play_at(ev, knight.global_position, knight)
	_check("a sound from the Player is centered", Audio.get_player(h) is AudioStreamPlayer, true)
	h = Audio.play_at(ev, slime.global_position, slime)
	var p2 := Audio.get_player(h) as AudioStreamPlayer2D
	_check("an enemy's sound is positional, at its position", p2 != null and p2.global_position == slime.global_position, true)
	if p2:
		_check("480 px, linear falloff, panning_strength 1.0", [p2.max_distance, p2.attenuation, p2.panning_strength], [480.0, 1.0, 1.0])
	h = Audio.play_at(ev, slime.global_position)
	_check("no source (a world sound) is positional too", Audio.get_player(h) is AudioStreamPlayer2D, true)
	var flat := _event("flat", [_tone_short])
	flat.positional = false
	h = Audio.play_at(flat, slime.global_position, slime)
	_check("a non-positional event is centered even from an enemy", Audio.get_player(h) is AudioStreamPlayer, true)
	h = Audio.play_on(ev, knight)
	_check("play_on() the Player is centered", Audio.get_player(h) is AudioStreamPlayer, true)

	await _real_wait(0.06)
	var loop := _event("follow", [_tone_loop], true)
	h = Audio.play_on(loop, slime)
	_place(slime, slime.global_position + Vector2(0, 40))
	await get_tree().physics_frame   # Audio follows in its physics step, after this one resumes
	await get_tree().physics_frame
	p2 = Audio.get_player(h) as AudioStreamPlayer2D
	_check("play_on() an enemy follows it", p2 != null and p2.global_position.is_equal_approx(slime.global_position), true)
	Audio.stop(h)
	_place(slime, center + Vector2(100, 0))

	var far := center + Vector2(600, 0)
	_check("a one-shot beyond 480 px from the listener isn't started", Audio.play_at(ev, far), 0)
	_check("logged out_of_range", Audio.get_log()[-1].reason, &"out_of_range")
	h = Audio.play_at(loop, far)
	_check("a loop out there still starts (it may come into range)", h > 0, true)
	Audio.stop_all()


func _test_handles() -> void:
	_section("Handles, stop, stop_all_on, stop_all")
	Audio.clear_log()
	var loop := _event("loop", [_tone_loop], true)
	var h := Audio.play(loop)
	_check("a loop keeps playing", [h > 0, Audio.is_playing(h)], [true, true])
	Audio.stop(h)
	var last: Dictionary = Audio.get_log()[-1]
	_check("stop() ends it, logged stopped", [Audio.is_playing(h), last.result, last.reason, last.handle], [false, Audio.RESULT_STOPPED, &"stop", h])
	var size := Audio.get_log().size()
	Audio.stop(h)
	Audio.stop(0)
	_check("stopping it again, or 0, does nothing", Audio.get_log().size(), size)

	var a := Audio.play_on(loop, slime)
	var b := Audio.play_on(_event("loop2", [_tone_loop], true), knight)
	Audio.stop_all_on(slime)
	_check("stop_all_on() stops only that node's sounds", [Audio.is_playing(a), Audio.is_playing(b)], [false, true])
	Audio.stop(b)

	var holder := Node2D.new()
	add_child(holder)
	h = Audio.play_on(loop, holder)
	var h2 := Audio.play_on(_event("loop3", [_tone_loop], true), holder)   # two sounds on one node
	holder.queue_free()
	await get_tree().physics_frame
	last = Audio.get_log()[-1]
	_check("both play_on() loops on a node stop when it's freed",
		[Audio.is_playing(h), Audio.is_playing(h2), last.result, last.reason], [false, false, Audio.RESULT_STOPPED, &"owner_left_tree"])
	var loose := Node2D.new()
	_check("play_on() a node outside the tree plays nothing", [Audio.play_on(loop, loose), Audio.get_log()[-1].reason], [0, &"no_owner"])
	loose.free()

	var sfx := Audio.play(_event("sfx", [_tone_loop], true))
	var amb := Audio.play(_event("amb", [_tone_loop], true, SoundEvent.Bus.AMBIENCE))
	var ui := Audio.play(_event("ui", [_tone_loop], true, SoundEvent.Bus.UI))
	var music := Audio.play(_event("music", [_tone_loop], true, SoundEvent.Bus.MUSIC))
	Audio.stop_all()
	_check("stop_all(): SFX and Ambience stop, UI and Music play on",
		[Audio.is_playing(sfx), Audio.is_playing(amb), Audio.is_playing(ui), Audio.is_playing(music)], [false, false, true, true])
	Audio.stop(ui)
	Audio.stop(music)

	var once := _event("once", [_tone_short])
	var played := 0
	for i in 3:
		played += 1 if Audio.play(once) > 0 else 0
	Audio.stop_all()
	for i in 3:
		played += 1 if Audio.play(once) > 0 else 0
	_check("stop_all() clears the instance-limit history (3 + 3 in one frame)", played, 6)
	Audio.stop_all()


func _test_voice_cap() -> void:
	_section("Voice cap and priority (cap set to 4 for the test)")
	Audio.clear_log()
	Audio.mix.voice_cap = 4
	var handles := []
	for i in 4:
		handles.append(Audio.play(_event("cap%d" % i, [_tone_loop], true)))
	var ui := Audio.play(_event("cap_ui", [_tone_loop], true, SoundEvent.Bus.UI))
	_check("4 SFX loops play; a UI sound doesn't count toward the cap", [handles.all(func(h: int) -> bool: return h > 0), ui > 0], [true, true])
	_check("a LOW sound is dropped", [Audio.play(_event("low", [_tone_short], false, SoundEvent.Bus.SFX, SoundEvent.Priority.LOW)), Audio.get_log()[-1].reason], [0, &"voice_cap"])
	_check("a NORMAL one too (equal priority doesn't steal)", Audio.play(_event("normal", [_tone_short])), 0)
	var high := Audio.play(_event("high", [_tone_short], false, SoundEvent.Bus.SFX, SoundEvent.Priority.HIGH))
	var entries := Audio.get_log()
	_check("a HIGH one plays and steals the oldest NORMAL",
		[high > 0, Audio.is_playing(handles[0]), Audio.is_playing(handles[1]), entries[-2].result, entries[-2].handle, entries[-2].reason, entries[-1].result],
		[true, false, true, Audio.RESULT_STOLEN, handles[0], &"by high", Audio.RESULT_PLAYED])
	_check("priority can be raised per call", Audio.play(_event("boosted", [_tone_short]), 1.0, SoundEvent.Priority.HIGH) > 0, true)
	Audio.stop(ui)
	Audio.stop_all()
	Audio.mix.voice_cap = _saved_mix.voice_cap


func _test_real_time() -> void:
	_section("Real time: hitstop never slows or pitches a sound")
	Engine.time_scale = 0.05
	var ev := _event("pitch", [_tone_short])
	ev.pitch_scale = 1.1
	var h := Audio.play(ev, 1.04)
	_check_near("pitch = event × caller (1.1 × 1.04), whatever the time scale",
		(Audio.get_player(h) as AudioStreamPlayer).pitch_scale if h > 0 else 0.0, 1.144, 0.0001)
	_check("AudioServer.playback_speed_scale stays 1", AudioServer.playback_speed_scale, 1.0)
	Engine.time_scale = 1.0
	Audio.stop_all()


func _test_pause() -> void:
	_section("Pause: SFX, Ambience, Voice pause; Music ducks; UI plays on")
	var sfx := Audio.play(_event("p_sfx", [_tone_loop], true))
	var amb := Audio.play(_event("p_amb", [_tone_loop], true, SoundEvent.Bus.AMBIENCE))
	var voice := Audio.play(_event("p_voice", [_tone_loop], true, SoundEvent.Bus.VOICE))
	var ui := Audio.play(_event("p_ui", [_tone_loop], true, SoundEvent.Bus.UI))
	var music := Audio.play(_event("p_music", [_tone_loop], true, SoundEvent.Bus.MUSIC))
	var music_bus := AudioServer.get_bus_index(&"Music")
	var base := Audio.get_bus_base_db(&"Music")
	get_tree().paused = true
	await _real_wait(0.3)
	_check("paused: the SFX, Ambience and Voice players stop processing",
		[Audio.get_player(sfx).can_process(), Audio.get_player(amb).can_process(), Audio.get_player(voice).can_process()], [false, false, false])
	_check("the UI and Music players keep going", [Audio.get_player(ui).can_process(), Audio.get_player(music).can_process()], [true, true])
	_check("and every sound is still there (paused, not stopped)",
		[Audio.is_playing(sfx), Audio.is_playing(amb), Audio.is_playing(voice), Audio.is_playing(ui), Audio.is_playing(music)], [true, true, true, true, true])
	_check_near("Music ducks -6 dB", AudioServer.get_bus_volume_db(music_bus), base - 6.0, 0.01)
	var low_pass := AudioServer.get_bus_effect(music_bus, 0) as AudioEffectLowPassFilter
	_check("its low-pass turns on at 1200 Hz", [AudioServer.is_bus_effect_enabled(music_bus, 0), low_pass.cutoff_hz], [true, 1200.0])
	print("  (measured) SFX player stream_paused while the tree is paused: %s" % Audio.get_player(sfx).get(&"stream_paused"))
	get_tree().paused = false
	await _real_wait(0.3)
	_check_near("unpaused: Music back to its level", AudioServer.get_bus_volume_db(music_bus), base, 0.01)
	_check("the low-pass off, the SFX player processing again", [AudioServer.is_bus_effect_enabled(music_bus, 0), Audio.get_player(sfx).can_process()], [false, true])
	print("  (measured) SFX player stream_paused after unpausing: %s" % Audio.get_player(sfx).get(&"stream_paused"))
	for h in [sfx, amb, voice, ui, music]:
		Audio.stop(h)


func _test_volumes() -> void:
	_section("Volumes (Settings, saved to user://settings.cfg)")
	# A test scene never reads or writes the player's user://settings.cfg; the
	# save format is checked on a scratch file.
	_check("in a scene under res://scenes/tests/: Settings saving is off",
		[Settings.is_test_scene(), Settings.saving_enabled], [true, false])
	var path := "user://audio_test_settings.cfg"
	Settings.save_path = path
	Settings.saving_enabled = true
	var sfx := AudioServer.get_bus_index(&"SFX")
	var base := Audio.get_bus_base_db(&"SFX")
	var keys := []
	var on_changed := func(key: StringName, _value: Variant) -> void: keys.append(key)
	Settings.setting_changed.connect(on_changed)
	Settings.set_volume(&"SFX", 0.5)
	_check("50% = the bus level - 6 dB", snappedf(AudioServer.get_bus_volume_db(sfx) - base, 0.01), -6.02)
	_check("emitted as volume_sfx", keys, [&"volume_sfx"])
	var cfg := ConfigFile.new()
	cfg.load(Settings.save_path)
	_check("saved as a whole percent in [audio]", cfg.get_value("audio", "volume_sfx", -1), 50)
	Settings.saving_enabled = false
	Settings.save_path = Settings.SAVE_PATH
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Settings.set_volume(&"SFX", 0.0)
	_check("0 mutes the bus", AudioServer.is_bus_mute(sfx), true)
	Settings.set_volume(&"SFX", 1.0)
	_check("100% = unmuted, at its layout level", [AudioServer.is_bus_mute(sfx), AudioServer.get_bus_volume_db(sfx)], [false, base])
	Settings.set_volume(&"Music", 0.333)
	_check("values round to whole percents", Settings.get_volume(&"Music"), 0.33)
	Settings.set_volume(&"Music", 1.0)
	Settings.setting_changed.disconnect(on_changed)
	@warning_ignore("static_called_on_instance")   # Settings is an autoload with no class_name
	_check("the keys", [Settings.get_volume_key(&"Master"), Settings.get_volume_key(&"Ambience")], [&"volume_master", &"volume_ambience"])


func _test_log_and_debug() -> void:
	_section("Log size and debug_draw")
	Audio.clear_log()
	Audio.mix.log_size = 5
	var ev := _event("many", [_tone_short])
	ev.max_instances = 6
	for i in 8:
		Audio.play(ev)
	_check("the log keeps the last log_size entries", Audio.get_log().size(), 5)
	Audio.mix.log_size = _saved_mix.log_size
	Audio.debug_draw = true
	await get_tree().process_frame
	await get_tree().process_frame
	var labels := Audio.find_children("*", "RichTextLabel", true, false)
	var text: String = (labels[0] as RichTextLabel).get_parsed_text() if not labels.is_empty() else ""
	_check("debug_draw lists recent sounds, dropped ones with their reason",
		[text.contains("many  SFX  NORMAL  played"), text.contains("instance_limit")], [true, true])
	Audio.debug_draw = false
	await get_tree().process_frame
	_check("and hides again", labels.is_empty() or not (labels[0].get_parent() as CanvasLayer).visible, true)
	Audio.stop_all()


# --- A2: combat sounds ------------------------------------------------------------

func _test_combat_sounds() -> void:
	Audio.stop_all()
	await _test_swing_sounds()
	await _test_hit_sounds()
	await _test_player_hit_sounds()
	await _test_death_sounds()
	await _test_empty_fields()
	await _test_ability_sounds()
	await _test_telegraph_sounds()
	await _test_status_sounds()
	await _test_heartbeat()


func _test_swing_sounds() -> void:
	_section("A2: swing and dash sounds")
	await _ready_knight()
	Audio.clear_log()
	var aim := Vector2.LEFT   # the slime is to the right: these swings whiff
	knight.attack.try_swing(aim)
	var swings := _played("sound_knight_swing")
	_check("a swing plays its sound at swing start, even a whiff", swings.size(), 1)
	if swings.size() > 0:
		_check("centered (the Player's own)", swings[0].positional, false)
		_check_near("swing 1 at pitch 1.00", _pitch(swings[0]), 1.0, 0.0001)
	await _wait_until(func() -> bool: return knight.attack.can_swing(), 120)
	knight.attack.try_swing(aim)
	swings = _played("sound_knight_swing")
	_check_near("swing 2 at pitch 1.04", _pitch(swings[-1]) if swings.size() > 1 else 0.0, 1.04, 0.0001)
	await _wait_until(func() -> bool: return knight.attack.can_swing(), 120)
	knight.attack.try_swing(aim)
	_check("the finisher plays its own heavier swing", _played("sound_knight_swing_finisher").size(), 1)
	_check("whiffs play no hit sound", _played("sound_hit_").size(), 0)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 120)
	Audio.clear_log()
	knight.dash.try_dash(Vector2.UP)
	var dashes := _played("sound_knight_dash")
	_check("a dash plays its sound, centered", [dashes.size(), dashes[0].positional if dashes.size() > 0 else null], [1, false])
	await _wait_until(func() -> bool: return not knight.dash.is_dashing(), 60)
	_place(knight, Audio.get_listener_position())


func _test_hit_sounds() -> void:
	_section("A2: hit sounds")
	await _ready_knight()
	var dummies := _dummies_in_front(5)
	await get_tree().physics_frame
	var hits := [0]
	var count_hit := func(ctx: HitContext) -> void:
		if ctx.source == knight and not ctx.has_tag(&"dot"):
			hits[0] += 1
	Events.unit_hit.connect(count_hit)
	Audio.clear_log()
	knight.attack.try_swing(Vector2.LEFT)
	await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 60)
	_check("the swing hit all 5 dummies", hits[0], 5)
	var light := _played("sound_hit_light")
	_check("one hit sound for the swing, not one per target", light.size(), 1)
	if light.size() > 0:
		_check("the Player's hit: centered, HIGH", [light[0].positional, light[0].priority], [false, SoundEvent.Priority.HIGH])
	_check("no crit layer without a crit", _played("sound_hit_crit").size(), 0)

	await _ready_knight()
	knight.stats_component.add_modifier(StatModifier.create(&"crit_chance", StatModifier.Type.FLAT, 1.0, &"test_crit"))
	hits[0] = 0
	Audio.clear_log()
	knight.attack.try_swing(Vector2.LEFT)
	await _wait_until(func() -> bool: return knight.attack.is_in_recovery(), 60)
	knight.stats_component.remove_modifiers_from(&"test_crit")
	_check("a crit swing on 5: one hit sound and one crit layer",
		[hits[0], _played("sound_hit_light").size() + _played("sound_hit_heavy").size(), _played("sound_hit_crit").size()], [5, 1, 1])

	var burn := StatusEffect.new()
	burn.id = &"test_burn"
	burn.duration = 1.0
	burn.tick_interval = 0.2
	burn.tick_damage = 5.0
	burn.stack_rule = StatusEffect.StackRule.REFRESH
	var ticks := [0]
	var count_tick := func(ctx: HitContext) -> void:
		if ctx.has_tag(&"dot"):
			ticks[0] += 1
	Events.unit_hit.connect(count_tick)
	await _hitstop_over()
	Audio.clear_log()
	dummies[0].status_component.apply_status(burn, knight)
	await _game_wait(0.7)
	Events.unit_hit.disconnect(count_tick)
	Events.unit_hit.disconnect(count_hit)
	_check("DoT ticks are silent (3 ticks, no sound)", [ticks[0] >= 3, Audio.get_log().size()], [true, 0])
	for d in dummies:
		d.queue_free()
	await get_tree().physics_frame


func _test_player_hit_sounds() -> void:
	_section("A2: hits on the player")
	await _ready_knight()
	var slime_hit := slime.make_hit_context(22.0, slime)
	Audio.clear_log()
	knight.on_hit(slime_hit)
	var hurt := _played("sound_knight_hurt")
	_check("a slime hit plays only the Knight's hurt sound", [hurt.size(), _played("sound_hit_").size()], [1, 0])
	if hurt.size() > 0:
		_check("centered, HIGH", [hurt[0].positional, hurt[0].priority], [false, SoundEvent.Priority.HIGH])

	await _ready_knight()
	knight.status_component.apply_status(load("res://data/statuses/status_shield.tres"), knight)
	Audio.clear_log()
	knight.on_hit(slime.make_hit_context(22.0, slime))
	_check("into a shield: the shield sound and no hurt (no health lost)",
		[_played("sound_shield_absorb").size(), _played("sound_knight_hurt").size()], [1, 0])
	knight.status_component.remove_status(&"shield")
	await _ready_knight()


func _test_death_sounds() -> void:
	_section("A2: deaths and the pack burst")
	await _real_wait(0.2)
	var pack := _dummies_in_front(3)
	await get_tree().physics_frame
	Audio.clear_log()
	var kill_frame := Engine.get_physics_frames()
	for d in pack:
		d.take_damage(100000.0, knight)
	await get_tree().physics_frame
	var bursts := _played("sound_death_pack_burst")
	_check("3 kills in one frame: one pack burst and no death sounds", [bursts.size(), _played("sound_slime_death").size()], [1, 0])
	_check("the burst plays in the frame of the kills (end-of-frame batching)", bursts[0].frame if bursts.size() > 0 else -1, kill_frame)
	_check("the kills play one kill hit sound (one per source per frame)", _played("sound_hit_kill").size(), 1)

	await _real_wait(0.2)
	var two := _dummies_in_front(2)
	await get_tree().physics_frame
	Audio.clear_log()
	two[0].take_damage(100000.0, knight)
	await _real_wait(0.2)
	two[1].take_damage(100000.0, knight)
	await get_tree().physics_frame
	_check("two deaths 0.2 s apart: two death sounds, no burst", [_played("sound_slime_death").size(), _played("sound_death_pack_burst").size()], [2, 0])

	await _real_wait(0.2)
	var trio := _dummies_in_front(4)
	await get_tree().physics_frame
	Audio.clear_log()
	var start := Time.get_ticks_msec()
	for i in 4:
		trio[i].take_damage(100000.0, knight)
		await get_tree().physics_frame
	var spread_ms := Time.get_ticks_msec() - start
	_check("3 deaths a frame apart (%d ms for all 4): two death sounds, then the burst" % spread_ms,
		[_played("sound_slime_death").size(), _played("sound_death_pack_burst").size()], [2, 1])
	_check("and a 4th death inside the window is silent", Audio.get_log().filter(func(e: Dictionary) -> bool:
		return String(e.event).contains("death") and e.result == Audio.RESULT_PLAYED).size(), 3)

	await _real_wait(0.2)
	var elite: Enemy = load("res://scenes/enemies/slime_elite.tscn").instantiate()
	elite.passive = true
	add_child(elite)
	_place(elite, knight.global_position + Vector2(-60, 60))
	await get_tree().physics_frame
	Audio.clear_log()
	elite.take_damage(100000.0, knight)
	await get_tree().physics_frame
	var elite_death := _played("sound_slime_elite_death")
	_check("the elite has its own death sound (the slime's, pitched 0.8), positional",
		[elite_death.size(), elite_death[0].positional if elite_death.size() > 0 else null], [1, true])
	await get_tree().physics_frame


func _test_empty_fields() -> void:
	_section("A2: every sound field empty = silent")
	await _real_wait(0.2)
	var saved_feel := GameFeel.hit_feel
	GameFeel.hit_feel = HitFeel.new()   # no sounds
	var saved_burst := Audio.mix.pack_burst_sound
	Audio.mix.pack_burst_sound = null
	var dummy := _dummies_in_front(1)[0]
	dummy.death_sound = null
	await get_tree().physics_frame
	Audio.clear_log()
	HitPipeline.resolve(HitPipeline.basic_attack(knight, dummy, AttackSwing.new()))
	dummy.take_damage(100000.0, knight)
	await get_tree().physics_frame
	_check("a hit and a death with no sounds set log nothing", Audio.get_log().size(), 0)
	GameFeel.hit_feel = saved_feel
	Audio.mix.pack_burst_sound = saved_burst
	await _hitstop_over()


# --- A3: abilities, telegraphs, statuses, heartbeat ------------------------------

func _test_ability_sounds() -> void:
	_section("A3: ability sounds")
	await _ready_knight()
	var dummies := _dummies_in_front(3)
	await get_tree().physics_frame
	Audio.clear_log()
	knight.abilities.try_cast(&"q", knight.global_position + Vector2.LEFT * 60.0)
	var casts := _played("sound_knight_cleave_cast")
	_check("Cleave plays its cast sound at cast start, centered", [casts.size(), casts[0].positional if casts.size() > 0 else null], [1, false])
	await _wait_until(func() -> bool: return not knight.abilities.casting, 60)
	_check("Cleave hits 3 with one hit sound (no own hit sound: HitFeel's light)", _played("sound_hit_").size(), 1)

	await _ready_knight()
	Audio.clear_log()
	var target := dummies[1]
	target.health.heal(100000.0)   # Cleave hurt it; at full health (280) it survives Judgement (214) and gets stunned
	knight.abilities.try_cast(&"r", target.global_position, target)
	_check("Judgement's cast sound", _played("sound_knight_judgement_cast").size(), 1)
	await _wait_until(func() -> bool: return not knight.abilities.casting, 200)
	var hit := _played("sound_knight_judgement_hit")
	_check("its own hit sound, once, instead of the tier's", [hit.size(), _played("sound_hit_light").size()], [1, 0])
	var stun := _played("sound_status_stun_apply")
	_check("the stun it applies plays the stun sound, positional (on the dummy)", [stun.size(), stun[0].positional if stun.size() > 0 else null], [1, true])
	_check("Judgement pings when ready (data)", (load("res://data/abilities/knight_r_judgement.tres") as Ability).ready_sound != null, true)

	await _ready_knight()
	var saved_w := knight.abilities.w
	var quick := Ability.new()
	quick.targeting = Ability.Targeting.SELF
	quick.cooldown = 0.2
	quick.cast_time = 0.0
	quick.ready_sound = _event("ready", [_tone_short], false, SoundEvent.Bus.UI)
	knight.abilities.w = quick
	var finished: Array = []
	var on_ready := func(slot: StringName, _a: Ability) -> void: finished.append(slot)
	knight.abilities.cooldown_finished.connect(on_ready)
	Audio.clear_log()
	knight.abilities.try_cast(&"w", knight.global_position)
	await _game_wait(0.35)
	_check("a cooldown counting down to 0: cooldown_finished and the ready sound", [finished, _played("ready").size()], [[&"w"], 1])
	var slow := Ability.new()
	slow.targeting = Ability.Targeting.SELF
	slow.cooldown = 0.2
	slow.cast_time = 0.5
	slow.dash_cancelable = true
	slow.ready_sound = quick.ready_sound
	knight.abilities.w = slow
	finished.clear()
	Audio.clear_log()
	knight.abilities.try_cast(&"w", knight.global_position)
	await get_tree().physics_frame
	knight.abilities.try_cancel_cast()
	await _game_wait(0.35)
	_check("a refunded cooldown (cancelled cast) doesn't ping", [finished, _played("ready").size()], [[], 0])
	knight.abilities.cooldown_finished.disconnect(on_ready)
	knight.abilities.w = saved_w
	for d in dummies:
		if is_instance_valid(d):
			d.queue_free()
	await get_tree().physics_frame


func _test_telegraph_sounds() -> void:
	_section("A3: the elite's telegraph wind-up")
	await _ready_knight()
	var elite := _spawn_elite(knight.global_position + Vector2(60, 0))
	await get_tree().physics_frame
	Audio.clear_log()
	elite.abilities.try_cast(&"q", knight.global_position, knight)
	var wind := _played("sound_slime_elite_slam_telegraph")
	var handle: int = wind[0].handle if wind.size() > 0 else 0
	var p2 := Audio.get_player(handle) as AudioStreamPlayer2D
	_check("the slam's wind-up plays at the telegraph (around the elite itself since ARCHETYPES AR2), positional, 640 px",
		[wind.size(), p2 != null and p2.global_position.distance_to(elite.global_position) < 1.0, p2.max_distance if p2 else 0.0], [1, true, 640.0])
	await _wait_until(func() -> bool: return not elite.abilities.casting, 60)
	await get_tree().physics_frame
	_check("the slam lands on the Knight: its hit sound and his hurt, and the wind-up stops",
		[_played("sound_slime_elite_slam_hit").size(), _played("sound_knight_hurt").size(), Audio.is_playing(handle)], [1, 1, false])

	elite.queue_free()
	await _ready_knight()
	elite = _spawn_elite(knight.global_position + Vector2(60, 0))
	await get_tree().physics_frame
	Audio.clear_log()
	elite.abilities.try_cast(&"q", knight.global_position, knight)
	handle = _played("sound_slime_elite_slam_telegraph")[0].handle
	await get_tree().physics_frame
	elite.apply_stun(1.0)
	await _wait_until(func() -> bool: return not elite.abilities.casting, 60)
	await get_tree().physics_frame
	_check("a stun interrupts the slam: the telegraph goes and its wind-up stops, no slam sound",
		[Audio.is_playing(handle), _played("sound_slime_elite_slam_hit").size()], [false, 0])
	elite.queue_free()

	await _ready_knight()
	elite = _spawn_elite(knight.global_position + Vector2(60, 0))
	await get_tree().physics_frame
	Audio.clear_log()
	elite.abilities.try_cast(&"q", knight.global_position, knight)
	handle = _played("sound_slime_elite_slam_telegraph")[0].handle
	await _frames(6)
	elite.take_damage(100000.0, knight)
	await get_tree().physics_frame
	_check("the elite dies mid-cast: the wind-up stops at once", Audio.is_playing(handle), false)
	await _frames(10)


func _test_status_sounds() -> void:
	_section("A3: status sounds")
	await _ready_knight()
	var dummy := _dummies_in_front(1)[0]
	await get_tree().physics_frame
	var burn := StatusEffect.new()
	burn.id = &"test_burning"
	burn.duration = 5.0
	burn.stack_rule = StatusEffect.StackRule.STACK
	burn.max_stacks = 3
	burn.apply_sound = _event("burn_apply", [_tone_short])
	burn.expire_sound = _event("burn_expire", [_tone_short])
	burn.loop_sound = _event("burn_loop", [_tone_loop], true)
	Audio.clear_log()
	for i in 3:
		dummy.status_component.apply_status(burn, knight)
	_check("3 stacks: the apply sound each time, one loop", [_played("burn_apply").size(), _played("burn_loop").size()], [3, 1])
	var loop_handle: int = _played("burn_loop")[0].handle
	dummy.status_component.remove_status(&"test_burning")
	_check("removed: the loop stops and the expire sound plays", [Audio.is_playing(loop_handle), _played("burn_expire").size()], [false, 1])
	dummy.status_component.apply_status(burn, knight)
	loop_handle = _played("burn_loop")[-1].handle
	Audio.clear_log()
	dummy.take_damage(100000.0, knight)
	await get_tree().physics_frame
	_check("the unit dies: the loop stops, no expire sound", [Audio.is_playing(loop_handle), _played("burn_expire").size()], [false, 0])

	await _ready_knight()
	await _real_wait(0.1)
	Audio.clear_log()
	knight.status_component.apply_status(load("res://data/statuses/status_shield.tres"), knight)
	var apply := _played("sound_status_shield_apply")
	_check("a shield on the Knight: its apply sound, centered, HIGH",
		[apply.size(), apply[0].positional if apply.size() > 0 else null, apply[0].priority if apply.size() > 0 else -1], [1, false, SoundEvent.Priority.HIGH])
	Audio.clear_log()
	knight.on_hit(slime.make_hit_context(150.0, slime))
	_check("150 into the 100 shield: absorb, the shield's break (expire) and the hurt",
		[_played("sound_shield_absorb").size(), _played("sound_status_shield_break").size(), _played("sound_knight_hurt").size()], [1, 1, 1])
	await _ready_knight()


func _test_heartbeat() -> void:
	_section("A3: the low-health heartbeat")
	await _ready_knight()
	Audio.clear_log()
	var max_health := knight.health.max_health
	knight.health.take_damage(max_health * 0.7)
	_check("at 30% health: no heartbeat", _played("sound_knight_low_health").size(), 0)
	knight.health.take_damage(max_health * 0.1)
	var beat := _played("sound_knight_low_health")
	_check("below 25%: the heartbeat loops, centered", [beat.size(), beat[0].positional if beat.size() > 0 else null], [1, false])
	var handle: int = beat[0].handle if beat.size() > 0 else 0
	knight.health.take_damage(10.0)
	_check("more damage doesn't start a second one", _played("sound_knight_low_health").size(), 1)
	knight.health.heal(max_health)
	_check("healed above 25%: it stops", Audio.is_playing(handle), false)

	var other: Player = PLAYER_SCENE.instantiate()
	add_child(other)
	_place(other, knight.global_position + Vector2(0, 120))
	await get_tree().physics_frame
	other.health.take_damage(other.health.max_health * 0.9)
	var beats := _played("sound_knight_low_health")
	handle = beats[-1].handle if beats.size() > 1 else 0
	_check("another Knight at 10%: his heartbeat", Audio.is_playing(handle), true)
	other.take_damage(100000.0)
	_check("he dies: it stops", Audio.is_playing(handle), false)
	await _frames(40)


func _spawn_elite(pos: Vector2) -> Enemy:
	var elite: Enemy = load("res://scenes/enemies/slime_elite.tscn").instantiate()
	elite.passive = true
	add_child(elite)
	_place(elite, pos)
	return elite


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Passive slimes in a fan in front of the Knight (to his left), inside his
## swing's reach and arc.
func _dummies_in_front(count: int) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for i in count:
		var d: Enemy = SLIME_SCENE.instantiate()
		d.passive = true
		add_child(d)
		var angle := deg_to_rad(180.0 + (i - (count - 1) * 0.5) * 18.0)
		_place(d, knight.global_position + Vector2.from_angle(angle) * 36.0)
		out.append(d)
	return out


## The Knight idle, healed, not invulnerable, combo back at its first swing.
func _ready_knight() -> void:
	await _hitstop_over()
	await _wait_until(func() -> bool: return knight.attack.can_swing() and not knight.attack.is_swinging() \
		and knight.attack.get_combo_index() == 0 and not knight.is_invulnerable() and not knight.dash.is_dashing(), 240)
	knight.health.heal(100000.0)
	_place(knight, Audio.get_listener_position())


func _hitstop_over() -> void:
	while GameFeel.is_hitstop_active():
		await get_tree().process_frame


## Waits `seconds` of game time (physics frames).
func _game_wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time() * Engine.time_scale


func _wait_until(condition: Callable, max_frames: int) -> void:
	for i in max_frames:
		if condition.call():
			return
		await get_tree().physics_frame


## Played entries whose event name contains `part`.
func _played(part: String) -> Array[Dictionary]:
	return Audio.get_log().filter(func(e: Dictionary) -> bool:
		return String(e.event).contains(part) and e.result == Audio.RESULT_PLAYED)


func _pitch(entry: Dictionary) -> float:
	var player := Audio.get_player(int(entry.handle))
	return float(player.get(&"pitch_scale")) if player != null else 0.0


## Numbers for the build log, not checks.
func _measure() -> void:
	_section("Measured")
	print("  output latency: %.1f ms (requested %s ms; driver %s)" % [AudioServer.get_output_latency() * 1000.0,
		ProjectSettings.get_setting("audio/driver/output_latency"), AudioServer.get_driver_name() if AudioServer.has_method("get_driver_name") else "?"])
	var ev := _event("measure", [_tone_short])
	var h := Audio.play_at(ev, slime.global_position, slime)
	var p2 := Audio.get_player(h) as AudioStreamPlayer2D
	print("  AudioStreamPlayer2D right after play(): playing=%s" % (p2.playing if p2 else false))
	await get_tree().physics_frame
	print("  one physics frame later: playing=%s" % (p2.playing if p2 else false))
	await _real_wait(0.4)
	print("  a 0.05 s one-shot 0.4 s later: still held by Audio=%s (false = the driver ran it to the end)" % Audio.is_playing(h))


# --- A6a: sound triggers ----------------------------------------------------------

func _test_sound_triggers() -> void:
	Audio.stop_all()
	_test_trigger_data()
	await _test_trigger_events()
	await _test_trigger_filters()
	await _test_trigger_places()
	await _test_trigger_progress()
	await _test_trigger_delays()
	await _test_trigger_gates()
	Audio.stop_all()


func _test_trigger_data() -> void:
	_section("A6a: SoundTrigger and SoundSheet (data); the Player's place rule")
	var t := SoundTrigger.new()
	_check("a new trigger: HIT_DEALT at the event, no delay, every filter open, DEFAULT, chance 1, no cooldown, every match, once per frame, on",
		[t.event, t.at_progress, t.delay, t.swing_number, t.ability_id, t.include_variants, t.part, t.status_id, t.stacks, t.end_reason,
			t.hit_tags.size(), t.used_empower, t.crit_only, t.kill_only, t.place, t.chance, t.cooldown, t.every_nth, t.once_per_frame, t.enabled,
			t.volume_db, t.pitch, t.sound],
		[SoundTrigger.Event.HIT_DEALT, -1.0, 0.0, 0, &"", true, -1, &"", 0, SoundTrigger.EndFilter.ANY,
			0, &"", false, false, SoundTrigger.Place.DEFAULT, 1.0, 0.0, 1, true, true, 0.0, 1.0, null])
	_check("the events, in their stored order", SoundTrigger.Event.keys(),
		["SWING_START", "SWING_LANDED", "SWING_WHIFF", "HIT_DEALT", "HIT_TAKEN", "CAST_START", "CAST_EFFECT", "STATUS_GAINED",
			"STATUS_ENDED", "STACKS_REACHED", "KILL", "DIED", "DASH", "DEFLECT"])
	_check("the places and the end filter", [SoundTrigger.Place.keys(), SoundTrigger.EndFilter.keys()],
		[["DEFAULT", "ON_SELF", "AT_SELF", "ON_OTHER", "AT_OTHER", "AT_AIM", "CENTERED"], ["ANY", "EXPIRED", "CONSUMED", "CLEANSED", "DIED", "REMOVED"]])
	var placed := func(event: SoundTrigger.Event, place: SoundTrigger.Place, is_player: bool) -> SoundTrigger.Place:
		var x := SoundTrigger.new()
		x.event = event
		x.place = place
		return SoundTriggers.get_effective_place(x, is_player)
	var E: Dictionary = SoundTrigger.Event
	var P: Dictionary = SoundTrigger.Place
	_check("where: DEFAULT centered for the Player, on him for anyone else; the Player's HIT_DEALT may sit at the enemy (AT_ / ON_OTHER), never his swing, his cast's aim or his own spot; an enemy's anywhere",
		[placed.call(E.HIT_DEALT, P.DEFAULT, true), placed.call(E.HIT_DEALT, P.DEFAULT, false), placed.call(E.HIT_DEALT, P.AT_OTHER, true),
			placed.call(E.HIT_DEALT, P.ON_OTHER, true), placed.call(E.SWING_START, P.AT_OTHER, true), placed.call(E.CAST_START, P.AT_AIM, true),
			placed.call(E.HIT_DEALT, P.AT_SELF, true), placed.call(E.SWING_START, P.AT_OTHER, false), placed.call(E.CAST_START, P.AT_AIM, false)],
		[P.CENTERED, P.ON_SELF, P.AT_OTHER, P.ON_OTHER, P.CENTERED, P.CENTERED, P.CENTERED, P.AT_OTHER, P.AT_AIM])
	_check("a sheet starts empty; Audio has its SoundTriggers child", [SoundSheet.new().triggers.size(), Audio.get_sound_triggers() != null], [0, true])


func _test_trigger_events() -> void:
	_section("A6a: each event plays its trigger once (the log's `trigger`)")
	await _ready_knight()
	var sounds := Audio.get_sound_triggers()
	var dummy := _dummies_in_front(1)[0]
	await get_tree().physics_frame
	var sheet := SoundSheet.new()
	for key: String in SoundTrigger.Event.keys():
		var t := _trigger(SoundTrigger.Event[key], "ev_" + key.to_lower())
		t.once_per_frame = false
		sheet.triggers.append(t)
	sounds.watch(knight, sheet)
	_check("the Knight watched with the sheet", [sounds.is_watching(knight), sounds.get_sheet(knight) == sheet], [true, true])
	Audio.clear_log()
	knight.attack.try_swing(Vector2.LEFT)
	await _wait_until(func() -> bool: return _fired("ev_swing_landed").size() > 0, 60)
	_check("a swing that lands: SWING_START, SWING_LANDED and HIT_DEALT once each, no whiff",
		[_fired("ev_swing_start").size(), _fired("ev_swing_landed").size(), _fired("ev_hit_dealt").size(), _fired("ev_swing_whiff").size()], [1, 1, 1, 0])
	var swing_sound := _played("sound_knight_swing")
	_check("each entry names its trigger; a slot's sound names none",
		[_fired("ev_hit_dealt")[0].trigger if _fired("ev_hit_dealt").size() > 0 else "", swing_sound[0].trigger if swing_sound.size() > 0 else "?"],
		["ev_hit_dealt", ""])
	await _ready_knight()
	_place(dummy, knight.global_position + Vector2(0, 400))   # out of the aim snap's reach
	await get_tree().physics_frame
	Audio.clear_log()
	knight.attack.try_swing(Vector2.UP)   # nothing there (the suite's slime stands to his right)
	await _wait_until(func() -> bool: return _fired("ev_swing_whiff").size() > 0, 60)
	_check("a swing at nothing: SWING_WHIFF, no landing, no hit",
		[_fired("ev_swing_whiff").size(), _fired("ev_swing_landed").size(), _fired("ev_hit_dealt").size()], [1, 0, 0])
	await _ready_knight()
	Audio.clear_log()
	knight.on_hit(dummy.make_hit_context(5.0, dummy))
	_check("a hit on him: HIT_TAKEN", _fired("ev_hit_taken").size(), 1)
	var saved_w := knight.abilities.w
	var quick := Ability.new()
	quick.id = &"test_trigger_cast"
	quick.targeting = Ability.Targeting.SELF
	quick.cooldown = 0.1
	quick.cast_time = 0.1
	knight.abilities.w = quick
	await _ready_knight()
	Audio.clear_log()
	knight.abilities.try_cast(&"w", knight.global_position)
	_check("a cast starts: CAST_START, not yet its effect", [_fired("ev_cast_start").size(), _fired("ev_cast_effect").size()], [1, 0])
	await _wait_until(func() -> bool: return not knight.abilities.casting, 60)
	_check("its effect: CAST_EFFECT", _fired("ev_cast_effect").size(), 1)
	knight.abilities.w = saved_w
	var mark := _mark("test_trigger_mark", 5.0, 3)
	Audio.clear_log()
	knight.status_component.apply_status(mark, dummy)
	_check("a status on him: STATUS_GAINED, and its first stack STACKS_REACHED (stacks 0: every new stack)",
		[_fired("ev_status_gained").size(), _fired("ev_stacks_reached").size()], [1, 1])
	knight.status_component.remove_status(mark.id)
	_check("it ends: STATUS_ENDED", _fired("ev_status_ended").size(), 1)
	await _wait_until(func() -> bool: return knight.dash.get_charges() > 0 and not knight.dash.is_dashing(), 120)
	Audio.clear_log()
	knight.dash.try_dash(Vector2.UP)
	_check("a dash: DASH", _fired("ev_dash").size(), 1)
	await _wait_until(func() -> bool: return not knight.dash.is_dashing(), 60)
	Audio.clear_log()
	Events.hit_deflected.emit(dummy, knight, dummy.make_hit_context(5.0, dummy))
	_check("a deflect (Events.hit_deflected): DEFLECT", _fired("ev_deflect").size(), 1)
	var victim := _dummies_in_front(1)[0]
	await get_tree().physics_frame
	sounds.watch(victim, _sheet([_trigger(SoundTrigger.Event.DIED, "victim_died")]))
	Audio.clear_log()
	victim.on_hit(victim.make_hit_context(100000.0, knight))
	_check("he kills a watched slime: his KILL, its DIED", [_fired("ev_kill").size(), _fired("victim_died").size()], [1, 1])
	await _wait_until(func() -> bool: return not is_instance_valid(victim) or not sounds.is_watching(victim), 240)
	_check("it left the tree: no longer watched", is_instance_valid(victim) and sounds.is_watching(victim), false)
	sounds.unwatch(knight)
	await _ready_knight()
	Audio.clear_log()
	knight.attack.try_swing(Vector2.LEFT)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 60)
	_check("unwatched: nothing plays", [sounds.is_watching(knight), _fired("ev_swing_start").size(), _fired("ev_hit_dealt").size()], [false, 0, 0])
	if is_instance_valid(dummy):
		dummy.queue_free()
	await _frames(2)


func _test_trigger_filters() -> void:
	_section("A6a: filters: swing number, hit tags, ability (and variants), part, status, end reason, stacks, crits, kills, DoT ticks, the empower used, conditions")
	await _ready_knight()
	var sounds := Audio.get_sound_triggers()
	var dummies := _dummies_in_front(3)
	await get_tree().physics_frame
	var swing_2 := _trigger(SoundTrigger.Event.SWING_START, "f_swing_2")
	swing_2.swing_number = 2
	var basic := _trigger(SoundTrigger.Event.HIT_DEALT, "f_basic")
	basic.hit_tags = [&"basic_attack"]
	var finisher := _trigger(SoundTrigger.Event.HIT_DEALT, "f_finisher")
	finisher.hit_tags = [&"basic_attack", &"finisher"]
	var each := _trigger(SoundTrigger.Event.HIT_DEALT, "f_each")
	each.once_per_frame = false
	var cleave := _trigger(SoundTrigger.Event.HIT_DEALT, "f_cleave")
	cleave.ability_id = &"knight_cleave"
	var cleave_only := _trigger(SoundTrigger.Event.HIT_DEALT, "f_cleave_only")
	cleave_only.ability_id = &"knight_cleave"
	cleave_only.include_variants = false
	var crit := _trigger(SoundTrigger.Event.HIT_DEALT, "f_crit")
	crit.crit_only = true
	var kill := _trigger(SoundTrigger.Event.HIT_DEALT, "f_kill")
	kill.kill_only = true
	var dot := _trigger(SoundTrigger.Event.HIT_DEALT, "f_dot")
	dot.hit_tags = [&"dot"]
	dot.once_per_frame = false
	var empowered := _trigger(SoundTrigger.Event.HIT_DEALT, "f_empower")
	empowered.used_empower = &"test_trigger_empower"
	var swing_empower := _trigger(SoundTrigger.Event.SWING_START, "f_swing_empower")
	swing_empower.used_empower = &"test_trigger_empower"
	var land_empower := _trigger(SoundTrigger.Event.SWING_LANDED, "f_land_empower")
	land_empower.used_empower = &"test_trigger_empower"
	var whiff_empower := _trigger(SoundTrigger.Event.SWING_WHIFF, "f_whiff_empower")
	whiff_empower.used_empower = &"test_trigger_empower"
	var part_1 := _trigger(SoundTrigger.Event.CAST_START, "f_part_1")
	part_1.part = 1
	var by_id := _trigger(SoundTrigger.Event.STATUS_GAINED, "f_status_id")
	by_id.status_id = &"test_trigger_stack"
	by_id.once_per_frame = false
	var by_tag := _trigger(SoundTrigger.Event.STATUS_GAINED, "f_status_tag")
	by_tag.status_tag = &"test_trigger_tag"
	var expired := _trigger(SoundTrigger.Event.STATUS_ENDED, "f_expired")
	expired.end_reason = SoundTrigger.EndFilter.EXPIRED
	expired.status_tag = &"test_trigger_tag"
	var consumed := _trigger(SoundTrigger.Event.STATUS_ENDED, "f_consumed")
	consumed.end_reason = SoundTrigger.EndFilter.CONSUMED
	consumed.status_id = &"shield"
	var three := _trigger(SoundTrigger.Event.STACKS_REACHED, "f_three")
	three.status_id = &"test_trigger_stack"
	three.stacks = 3
	var focused := _trigger(SoundTrigger.Event.SWING_START, "f_condition")
	var cond := Condition.new()
	cond.kind = Condition.Kind.SELF_HAS_STATUS
	cond.status_tag = &"test_trigger_tag"
	focused.conditions = [cond]
	sounds.watch(knight, _sheet([swing_2, basic, finisher, each, cleave, cleave_only, crit, kill, dot, empowered, swing_empower, land_empower, whiff_empower, part_1, by_id, by_tag, expired, consumed, three, focused]))
	Audio.clear_log()
	for i in 2:
		await _wait_until(func() -> bool: return knight.attack.can_swing(), 120)
		knight.attack.try_swing(Vector2.LEFT)
		await _wait_until(func() -> bool: return knight.attack.is_in_recovery() or not knight.attack.is_swinging(), 60)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 60)
	_check("two swings into three slimes: swing_number 2 once; `basic_attack` once a swing (once per frame), three a swing without it; never `finisher` (the Knight's swings carry none), no ability",
		[_fired("f_swing_2").size(), _fired("f_basic").size(), _fired("f_each").size(), _fired("f_finisher").size(), _fired("f_cleave").size()], [1, 2, 6, 0, 0])
	_check("a condition (SELF_HAS_STATUS test_trigger_tag) he doesn't meet: nothing", _fired("f_condition").size(), 0)
	var d := dummies[0]
	Audio.clear_log()
	var hit := d.make_hit_context(1.0, knight)
	hit.ability = load("res://data/abilities/knight_q_cleave.tres")
	d.on_hit(hit)
	await get_tree().physics_frame
	var wave_hit := d.make_hit_context(1.0, knight)
	wave_hit.ability = load("res://data/abilities/knight_q_cleave_wave.tres")
	d.on_hit(wave_hit)
	_check("ability_id knight_cleave: Cleave's hit and its variant Cleave Wave's; with include_variants off, Cleave's only",
		[_fired("f_cleave").size(), _fired("f_cleave_only").size()], [2, 1])
	await get_tree().physics_frame
	Audio.clear_log()
	var crit_hit := d.make_hit_context(1.0, knight)
	crit_hit.is_crit = true
	d.on_hit(crit_hit)
	await get_tree().physics_frame
	var tick := d.make_hit_context(1.0, knight)
	tick.add_tag(&"dot")
	d.on_hit(tick)
	_check("a crit: crit_only; a DoT tick: only the trigger asking for `dot` (the others skip it)",
		[_fired("f_crit").size(), _fired("f_dot").size(), _fired("f_each").size()], [1, 1, 1])
	var empower := StatusEffect.new()
	empower.id = &"test_trigger_empower"
	empower.duration = 5.0
	empower.tags = [&"empower", &"buff"]
	empower.empower_consumed_by = StatusEffect.EmpowerTrigger.BASIC_ATTACK_HIT
	await _ready_knight()
	knight.status_component.apply_status(empower, knight)
	Audio.clear_log()
	knight.attack.try_swing(Vector2.LEFT)
	await _wait_until(func() -> bool: return _fired("f_basic").size() > 0, 60)
	_check("the swing that uses the empower: used_empower plays on its hit (HitContext.empowers_used), at its start (he held it) and at its landing (its hits used it), once each",
		[_fired("f_empower").size(), _fired("f_swing_empower").size(), _fired("f_land_empower").size()], [1, 1, 1])
	await _ready_knight()
	Audio.clear_log()
	knight.attack.try_swing(Vector2.LEFT)
	await _wait_until(func() -> bool: return _fired("f_basic").size() > 0, 60)
	_check("the next swing (no empower): none of them", [_fired("f_empower").size(), _fired("f_swing_empower").size(), _fired("f_land_empower").size()], [0, 0, 0])
	Audio.clear_log()
	var ctx_0 := CastContext.new()
	var ctx_1 := CastContext.new()
	ctx_1.part = 1
	knight.abilities.cast_started.emit(&"q", knight.abilities.q, ctx_0)
	knight.abilities.cast_started.emit(&"q", knight.abilities.q, ctx_1)
	_check("part 1: only the recast part", _fired("f_part_1").size(), 1)
	knight.abilities.cast_finished.emit(&"q", knight.abilities.q)
	Audio.clear_log()
	var stack := _mark("test_trigger_stack", 5.0, 5)
	var tagged := _mark("test_trigger_tagged", 1.0, 1)
	tagged.tags = [&"test_trigger_tag"]
	knight.status_component.apply_status(tagged, knight)
	var at: Array = []
	for i in 4:
		knight.status_component.apply_status(stack, knight)
		at.append(_fired("f_three").size())
	_check("by id and by tag; stacks 3: only as the 3rd stack comes (1, 2: no; 3: yes; 4: no)",
		[_fired("f_status_id").size(), _fired("f_status_tag").size(), at], [4, 1, [0, 0, 1, 1]])
	_check("the condition met (it holds a test_trigger_tag status): a swing plays it", await _swing_fires("f_condition"), 1)
	await _wait_until(func() -> bool: return not knight.status_component.has_status(&"test_trigger_tagged"), 120)
	_check("the tagged status ran out: EXPIRED, not CONSUMED", [_fired("f_expired").size(), _fired("f_consumed").size()], [1, 0])
	Audio.clear_log()
	knight.status_component.apply_status(load("res://data/statuses/status_shield.tres"), knight)
	knight.status_component.absorb_damage(1000.0)
	_check("a shield used up: CONSUMED, not EXPIRED", [_fired("f_consumed").size(), _fired("f_expired").size()], [1, 0])
	Audio.clear_log()
	var k_hit := d.make_hit_context(100000.0, knight)
	d.on_hit(k_hit)
	_check("a hit that kills: kill_only", _fired("f_kill").size(), 1)
	for x in dummies:
		if is_instance_valid(x) and x != d:
			_place(x, knight.global_position + Vector2(0, 400))   # out of the aim snap's reach
	await _ready_knight()
	knight.status_component.apply_status(empower, knight)
	Audio.clear_log()
	knight.attack.try_swing(Vector2.UP)
	await _wait_until(func() -> bool: return not knight.attack.is_swinging(), 60)
	_check("a whiff carrying the empower: its start plays, no landing, a SWING_WHIFF never; the empower stays",
		[_fired("f_swing_empower").size(), _fired("f_land_empower").size(), _fired("f_whiff_empower").size(), knight.status_component.has_status(&"test_trigger_empower")],
		[1, 0, 0, true])
	knight.status_component.remove_status(&"test_trigger_empower")
	knight.status_component.remove_status(&"test_trigger_stack")
	sounds.unwatch(knight)
	for x in dummies:
		if is_instance_valid(x):
			x.queue_free()
	await _frames(2)


func _test_trigger_places() -> void:
	_section("A6a: places: the Player's sounds centered but his impact; an enemy's anywhere")
	await _ready_knight()
	var sounds := Audio.get_sound_triggers()
	var dummy := _dummies_in_front(1)[0]
	await get_tree().physics_frame
	var default_hit := _trigger(SoundTrigger.Event.HIT_DEALT, "p_default")
	var impact := _trigger(SoundTrigger.Event.HIT_DEALT, "p_impact")
	impact.place = SoundTrigger.Place.AT_OTHER
	var impact_on := _trigger(SoundTrigger.Event.HIT_DEALT, "p_impact_on")
	impact_on.place = SoundTrigger.Place.ON_OTHER
	var swing_at := _trigger(SoundTrigger.Event.SWING_START, "p_swing_at")
	swing_at.place = SoundTrigger.Place.AT_OTHER
	sounds.watch(knight, _sheet([default_hit, impact, impact_on, swing_at]))
	Audio.clear_log()
	var hit_at := [Vector2.INF]
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.source == knight and hit_at[0] == Vector2.INF:
			hit_at[0] = (ctx.target as Node2D).global_position
	Events.unit_hit.connect(on_hit)
	knight.attack.try_swing(Vector2.LEFT)
	await _wait_until(func() -> bool: return _fired("p_impact").size() > 0, 60)
	Events.unit_hit.disconnect(on_hit)
	await get_tree().physics_frame
	var hit_pos: Vector2 = hit_at[0]
	var e_default := _first_fired("p_default")
	var e_impact := _first_fired("p_impact")
	var e_on := _first_fired("p_impact_on")
	var p_on := Audio.get_player(int(e_on.get("handle", 0))) as AudioStreamPlayer2D
	_check("his hit, DEFAULT: centered, HIGH", [e_default.get("positional"), e_default.get("priority")], [false, SoundEvent.Priority.HIGH])
	_check("his impact, AT_OTHER: positional, where the slime was hit", [e_impact.get("positional"), (e_impact.get("position", Vector2.INF) as Vector2).distance_to(hit_pos) < 2.0], [true, true])
	_check("his impact, ON_OTHER: positional, following the slime", [e_on.get("positional"), p_on != null and p_on.global_position.distance_to(dummy.global_position) < 2.0], [true, true])
	_check("his swing, AT_OTHER: centered anyway (warned once: see the output)", _first_fired("p_swing_at").get("positional"), false)
	sounds.unwatch(knight)
	var on_self := _trigger(SoundTrigger.Event.HIT_TAKEN, "e_default")
	var centered := _trigger(SoundTrigger.Event.HIT_TAKEN, "e_centered")
	centered.place = SoundTrigger.Place.CENTERED
	var at_aim := _trigger(SoundTrigger.Event.HIT_TAKEN, "e_aim")
	at_aim.place = SoundTrigger.Place.AT_AIM
	var at_other := _trigger(SoundTrigger.Event.HIT_TAKEN, "e_other")
	at_other.place = SoundTrigger.Place.AT_OTHER
	var gone := _trigger(SoundTrigger.Event.HIT_TAKEN, "e_gone")
	gone.place = SoundTrigger.Place.ON_OTHER
	gone.delay = 0.1
	sounds.watch(dummy, _sheet([on_self, centered, at_aim, at_other, gone]))
	var other := _dummies_in_front(1)[0]
	_place(other, dummy.global_position + Vector2(0, 40))
	await get_tree().physics_frame
	var other_pos := other.global_position
	Audio.clear_log()
	dummy.on_hit(dummy.make_hit_context(1.0, other))
	var e_self := _first_fired("e_default")
	var p_self := Audio.get_player(int(e_self.get("handle", 0))) as AudioStreamPlayer2D
	_check("a slime's DEFAULT: positional, following it; CENTERED: no position; AT_AIM with no cast: where it stood; AT_OTHER: where the hitter stood",
		[e_self.get("positional"), p_self != null and p_self.global_position.distance_to(dummy.global_position) < 2.0, _first_fired("e_centered").get("positional"),
			(_first_fired("e_aim").get("position", Vector2.INF) as Vector2).distance_to(dummy.global_position) < 2.0,
			(_first_fired("e_other").get("position", Vector2.INF) as Vector2).distance_to(other_pos) < 2.0],
		[true, true, false, true, true])
	other.queue_free()
	await _real_wait(0.2)
	var e_gone := _first_fired("e_gone")
	_check("ON_OTHER whose unit was freed before its 0.1 s delay: where it stood", [e_gone.get("positional"), (e_gone.get("position", Vector2.INF) as Vector2).distance_to(other_pos) < 2.0], [true, true])
	sounds.unwatch(dummy)
	dummy.queue_free()
	await _frames(2)


func _test_trigger_progress() -> void:
	_section("A6a: at_progress: a point of the cast or swing, following it; a cancel drops it (A4's cues, folded in)")
	await _ready_knight()
	var sounds := Audio.get_sound_triggers()
	var saved_w := knight.abilities.w
	var slow := Ability.new()
	slow.id = &"test_trigger_slow"
	slow.targeting = Ability.Targeting.SELF
	slow.cooldown = 0.1
	slow.cast_time = 0.5
	slow.dash_cancelable = true
	knight.abilities.w = slow
	var at_start := _trigger(SoundTrigger.Event.CAST_START, "pr_start")
	at_start.at_progress = 0.0
	var at_half := _trigger(SoundTrigger.Event.CAST_START, "pr_half")
	at_half.at_progress = 0.5
	var at_end := _trigger(SoundTrigger.Event.CAST_START, "pr_end")
	at_end.at_progress = 1.0
	var swing_half := _trigger(SoundTrigger.Event.SWING_START, "pr_swing")
	swing_half.at_progress = 0.5
	sounds.watch(knight, _sheet([at_start, at_half, at_end, swing_half]))
	Audio.clear_log()
	var f0 := Engine.get_physics_frames()
	knight.abilities.try_cast(&"w", knight.global_position)
	_check("0: at the press; not yet 0.5 or 1", [_fired("pr_start").size(), _fired("pr_half").size(), _fired("pr_end").size()], [1, 0, 0])
	await _wait_until(func() -> bool: return _fired("pr_half").size() > 0, 60)
	var half_frame: int = _first_fired("pr_half").get("frame", -100)
	_check_near("0.5 of a 0.5 s cast: 0.25 s in (15 physics frames)", half_frame - f0, 15.0, 2.0)
	await _wait_until(func() -> bool: return not knight.abilities.casting, 60)
	_check("1: at its effect", _fired("pr_end").size(), 1)
	await _game_wait(0.15)
	Audio.clear_log()
	knight.abilities.try_cast(&"w", knight.global_position)
	await _frames(5)
	knight.abilities.try_cancel_cast()
	await _frames(40)
	_check("cancelled 0.08 s in: 0 played, 0.5 and 1 never", [_fired("pr_start").size(), _fired("pr_half").size(), _fired("pr_end").size()], [1, 0, 0])
	var quick := Ability.new()
	quick.id = &"test_trigger_quick"
	quick.targeting = Ability.Targeting.SELF
	quick.cooldown = 0.1
	quick.cast_time = 0.0
	knight.abilities.w = quick
	await _game_wait(0.15)
	Audio.clear_log()
	knight.abilities.try_cast(&"w", knight.global_position)
	_check("a cast with no cast time: every point at the press", [_fired("pr_start").size(), _fired("pr_half").size(), _fired("pr_end").size()], [1, 1, 1])
	knight.abilities.w = saved_w
	await _ready_knight()
	Audio.clear_log()
	knight.attack.try_swing(Vector2.LEFT)
	var swing_progress := [-1.0]
	await _wait_until(func() -> bool:
		if _fired("pr_swing").size() > 0 and swing_progress[0] < 0.0:
			swing_progress[0] = knight.attack.get_swing_progress()
		return _fired("pr_swing").size() > 0, 60)
	_check_near("a swing's 0.5: mid-swing (its progress read the tick after: 0.5 plus at most two ticks)", swing_progress[0], 0.6, 0.1)
	await _ready_knight()
	Audio.clear_log()
	knight.attack.try_swing(Vector2.LEFT)
	await get_tree().physics_frame
	knight.attack.cancel_swing()
	await _frames(30)
	_check("a swing cancelled at its start: its 0.5 never plays", _fired("pr_swing").size(), 0)
	sounds.unwatch(knight)
	await _frames(2)


func _test_trigger_delays() -> void:
	_section("A6a: delay: real time (a hitstop doesn't stretch it); it waits through the pause")
	await _ready_knight()
	var sounds := Audio.get_sound_triggers()
	var later := _trigger(SoundTrigger.Event.STATUS_GAINED, "d_later")
	later.delay = 0.2
	sounds.watch(knight, _sheet([later]))
	var mark := _mark("test_trigger_delay", 5.0, 1)
	Audio.clear_log()
	Engine.time_scale = 0.05
	var t0 := Time.get_ticks_msec()
	knight.status_component.apply_status(mark, knight)
	var until := t0 + 1500
	while _fired("d_later").is_empty() and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	Engine.time_scale = 1.0
	var fired := _first_fired("d_later")
	_check_near("0.2 s at Engine.time_scale 0.05: 0.2 s of real time (ms), not 4 s", float(int(fired.get("time_ms", t0 + 99999)) - t0), 200.0, 60.0)
	Audio.clear_log()
	knight.status_component.apply_status(mark, knight)
	get_tree().paused = true
	await _real_wait(0.35)
	var while_paused := _fired("d_later").size()
	get_tree().paused = false
	await _real_wait(0.3)
	_check("paused 0.35 s: not played; unpaused: it plays", [while_paused, _fired("d_later").size()], [0, 1])
	Audio.clear_log()
	knight.status_component.apply_status(mark, knight)
	Audio.stop_all()
	await _real_wait(0.3)
	_check("Audio.stop_all() (a scene restart) drops a waiting delay", _fired("d_later").size(), 0)
	knight.status_component.remove_status(mark.id)
	sounds.unwatch(knight)


func _test_trigger_gates() -> void:
	_section("A6a: once per frame, every Nth, cooldown, chance (seeded), off, no sound, volume and pitch")
	await _ready_knight()
	var sounds := Audio.get_sound_triggers()
	var mark := _mark("test_trigger_gate", 5.0, 1)
	var once := _trigger(SoundTrigger.Event.STATUS_GAINED, "g_once")
	var nth := _trigger(SoundTrigger.Event.STATUS_GAINED, "g_nth")
	nth.once_per_frame = false
	nth.every_nth = 3
	var cooled := _trigger(SoundTrigger.Event.STATUS_GAINED, "g_cooldown")
	cooled.once_per_frame = false
	cooled.cooldown = 0.3
	var off := _trigger(SoundTrigger.Event.STATUS_GAINED, "g_off")
	off.enabled = false
	var silent := _trigger(SoundTrigger.Event.STATUS_GAINED, "g_silent")
	silent.sound = null
	var tuned := _trigger(SoundTrigger.Event.STATUS_GAINED, "g_tuned")
	tuned.volume_db = 6.0
	tuned.pitch = 1.5
	sounds.watch(knight, _sheet([once, nth, cooled, off, silent, tuned]))
	Audio.stop_all()
	Audio.clear_log()
	for i in 6:
		knight.status_component.apply_status(mark, knight)
	_check("6 applications in one frame: once per frame 1, every 3rd 2, cooldown 0.3 s 1, off 0, no sound nothing logged",
		[_fired("g_once").size(), _fired("g_nth").size(), _fired("g_cooldown").size(), _fired("g_off").size(),
			Audio.get_log().filter(func(e: Dictionary) -> bool: return e.trigger == "g_silent").size()], [1, 2, 1, 0, 0])
	var e_tuned := _first_fired("g_tuned")
	var player := Audio.get_player(int(e_tuned.get("handle", 0)))
	_check("volume +6 dB and pitch x1.5 on top of the SoundEvent's (-18 dB, 1.0)",
		[player.get(&"volume_db") if player else 0.0, player.get(&"pitch_scale") if player else 0.0], [-12.0, 1.5])
	await _real_wait(0.35)
	knight.status_component.apply_status(mark, knight)
	_check("0.35 s later: the cooldown is over", _fired("g_cooldown").size(), 2)
	sounds.unwatch(knight)
	var lucky := _trigger(SoundTrigger.Event.STATUS_GAINED, "g_chance")
	lucky.once_per_frame = false
	lucky.chance = 0.5
	sounds.watch(knight, _sheet([lucky]))
	var counts: Array = []
	for run in 2:
		Audio.stop_all()
		Audio.clear_log()
		Audio.rng.seed = 4242
		for i in 20:
			knight.status_component.apply_status(mark, knight)
		counts.append(_tried("g_chance").size())   # played or dropped by the instance limit: it matched
	var expected := 0
	var mirror := RandomNumberGenerator.new()
	mirror.seed = 4242
	for i in 20:
		if mirror.randf() < 0.5:
			expected += 1
	_check("chance 0.5 over 20, Audio.rng seeded: the same count twice, the seed's own (%d)" % expected, counts, [expected, expected])
	knight.status_component.remove_status(mark.id)
	sounds.unwatch(knight)
	Audio.stop_all()


## A trigger on `event` named `trigger_name`, with its own quiet test sound
## named after it.
func _trigger(event: SoundTrigger.Event, trigger_name: String) -> SoundTrigger:
	var t := SoundTrigger.new()
	t.event = event
	t.name = trigger_name
	t.sound = _event(trigger_name, [_tone_short])
	t.sound.max_instances = 6
	t.sound.min_interval = 0.03
	return t


func _sheet(triggers: Array) -> SoundSheet:
	var sheet := SoundSheet.new()
	for t in triggers:
		sheet.triggers.append(t)
	return sheet


## A plain test status: `max_stacks` stacks (STACK when above 1).
func _mark(id: String, duration: float, max_stacks: int) -> StatusEffect:
	var s := StatusEffect.new()
	s.id = StringName(id)
	s.duration = duration
	s.max_stacks = max_stacks
	s.stack_rule = StatusEffect.StackRule.STACK if max_stacks > 1 else StatusEffect.StackRule.REFRESH
	return s


## Played entries of the trigger named `trigger_name`.
func _fired(trigger_name: String) -> Array[Dictionary]:
	return Audio.get_log().filter(func(e: Dictionary) -> bool: return e.trigger == trigger_name and e.result == Audio.RESULT_PLAYED)


## Every entry of the trigger named `trigger_name` (played, dropped...).
func _tried(trigger_name: String) -> Array[Dictionary]:
	return Audio.get_log().filter(func(e: Dictionary) -> bool: return e.trigger == trigger_name)


func _first_fired(trigger_name: String) -> Dictionary:
	var entries := _fired(trigger_name)
	return entries[0] if not entries.is_empty() else {}


## Swings once at the slimes in front and returns how often `trigger_name` played.
func _swing_fires(trigger_name: String) -> int:
	await _wait_until(func() -> bool: return knight.attack.can_swing(), 120)
	var before := _fired(trigger_name).size()
	knight.attack.try_swing(Vector2.LEFT)
	await get_tree().physics_frame
	return _fired(trigger_name).size() - before


# --- Helpers ------------------------------------------------------------------

func _event(event_name: String, streams: Array, loop: bool = false, bus: SoundEvent.Bus = SoundEvent.Bus.SFX,
		priority: SoundEvent.Priority = SoundEvent.Priority.NORMAL) -> SoundEvent:
	var ev := SoundEvent.new()
	ev.resource_name = event_name
	var typed: Array[AudioStream] = []
	for s in streams:
		typed.append(s)
	ev.variations = typed
	ev.loop = loop
	ev.bus = bus
	ev.priority = priority
	ev.volume_db = -18.0
	return ev


## A quiet sine tone, 16-bit mono at 44.1 kHz.
func _make_tone(seconds: float, hz: float, loop: bool) -> AudioStreamWAV:
	var frames := int(seconds * 44100.0)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		data.encode_s16(i * 2, int(sin(TAU * hz * i / 44100.0) * 4000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = frames
	return wav


## Waits at least `seconds` of real time (Time.get_ticks_msec()). A timer
## isn't enough: one made mid-frame is charged that frame's whole delta.
func _real_wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(ceilf(seconds * 1000.0))
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _place(node: Node2D, pos: Vector2) -> void:
	node.global_position = pos
	node.reset_physics_interpolation()


func _section(title: String) -> void:
	print("-- %s" % title)


func _check(label: String, actual: Variant, expected: Variant) -> void:
	var ok: bool
	if actual is float or expected is float:
		ok = is_equal_approx(float(actual), float(expected))
	else:
		ok = actual == expected
	_report(ok, label, "got %s, expected %s" % [actual, expected])


func _check_near(label: String, actual: float, expected: float, tolerance: float) -> void:
	_report(absf(actual - expected) <= tolerance, label, "got %s, expected %s ± %s" % [actual, expected, tolerance])


func _report(ok: bool, label: String, detail: String) -> void:
	if ok:
		_passed += 1
		print("  PASS  %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s  (%s)" % [label, detail])
