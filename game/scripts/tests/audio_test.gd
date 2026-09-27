extends Node2D
## AUDIO.md step A1 test: open res://scenes/tests/audio_test.tscn and press F6.
## Checks the Audio autoload without hearing it (through its log): SoundEvent
## data, the bus layout, null and empty sounds, the instance limit in real
## time (also at Engine.time_scale 0.05), centered vs positional, the
## listener range, handles and stop_all_on() / stop_all(), a play_on() loop
## stopping when its node is freed, the voice cap and priorities, the pause
## (SFX, Ambience and Voice pause; Music ducks and low-passes; UI plays on),
## the volume settings, the log size and debug_draw. Tones are generated in
## code (no files), quiet (-18 dB). Prints PASS/FAIL per check, then a total.
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
	_check("six buses in order", names, Audio.BUSES)
	var levels := []
	for bus in Audio.BUSES:
		levels.append(Audio.get_bus_base_db(bus))
	_check("starting levels 0 / -8 / 0 / -4 / -12 / -2 dB", levels, [0.0, -8.0, 0.0, -4.0, -12.0, -2.0])
	var sends := []
	for bus in Audio.BUSES.slice(1):
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
	var log := Audio.get_log()
	_check("an event without audio stays silent (logged no_audio twice; warned once, see the output)",
		[a, b, log.size(), log[0].reason if log.size() > 0 else &"", log[-1].reason if log.size() > 0 else &""],
		[0, 0, 2, &"no_audio", &"no_audio"])


func _test_instance_limit() -> void:
	_section("Instance limit (3 within 0.05 s, real time)")
	Audio.stop_all()
	Audio.clear_log()
	var ev := _event("limit", [_tone_short])
	var handles := []
	for i in 4:
		handles.append(Audio.play(ev))
	var log := Audio.get_log()
	_check("4 plays in one frame: 3 played, the 4th dropped",
		[handles[0] > 0, handles[1] > 0, handles[2] > 0, handles[3], log[-1].result, log[-1].reason],
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

	var owner := Node2D.new()
	add_child(owner)
	h = Audio.play_on(loop, owner)
	owner.queue_free()
	await get_tree().physics_frame
	last = Audio.get_log()[-1]
	_check("a play_on() loop stops when its node is freed", [Audio.is_playing(h), last.result, last.reason], [false, Audio.RESULT_STOPPED, &"owner_left_tree"])
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
	var log := Audio.get_log()
	_check("a HIGH one plays and steals the oldest NORMAL",
		[high > 0, Audio.is_playing(handles[0]), Audio.is_playing(handles[1]), log[-2].result, log[-2].handle, log[-2].reason, log[-1].result],
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
	var sfx := AudioServer.get_bus_index(&"SFX")
	var base := Audio.get_bus_base_db(&"SFX")
	var keys := []
	var on_changed := func(key: StringName, _value: Variant) -> void: keys.append(key)
	Settings.setting_changed.connect(on_changed)
	Settings.set_volume(&"SFX", 0.5)
	_check("50% = the bus level - 6 dB", snappedf(AudioServer.get_bus_volume_db(sfx) - base, 0.01), -6.02)
	_check("emitted as volume_sfx", keys, [&"volume_sfx"])
	var cfg := ConfigFile.new()
	cfg.load(Settings.SAVE_PATH)
	_check("saved as a whole percent in [audio]", cfg.get_value("audio", "volume_sfx", -1), 50)
	Settings.set_volume(&"SFX", 0.0)
	_check("0 mutes the bus", AudioServer.is_bus_mute(sfx), true)
	Settings.set_volume(&"SFX", 1.0)
	_check("100% = unmuted, at its layout level", [AudioServer.is_bus_mute(sfx), AudioServer.get_bus_volume_db(sfx)], [false, base])
	Settings.set_volume(&"Music", 0.333)
	_check("values round to whole percents", Settings.get_volume(&"Music"), 0.33)
	Settings.set_volume(&"Music", 1.0)
	Settings.setting_changed.disconnect(on_changed)
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
