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
	_check("the slam's wind-up plays at the telegraph, positional, 640 px",
		[wind.size(), p2 != null and p2.global_position.distance_to(knight.global_position) < 1.0, p2.max_distance if p2 else 0.0], [1, true, 640.0])
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
