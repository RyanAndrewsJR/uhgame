# AUDIO.md: Sound Effects, Music and the Mix

**Read when:** the task involves any sound, music, the mix, or volume settings.
**Depends on:** CLAUDE.md, CONVENTIONS.md (reserved names), COMBAT.md (Events, HitContext, HitFeel, StatusEffect, Telegraph), MOVEMENT.md (Dash; the F3 walk bob for footsteps), DECISIONS.md (General: Settings and the pause menu).
**Used by:** COMBAT, ABILITIES, CHAMPIONS, LOOT, ENEMIES_AI, DUNGEONS, UI. Other docs only list their hooks and point here.

## How to read this doc
Same as COMBAT.md: MUST (never change without asking Ryan), TARGET (start value and allowed range), FREE (your call; tiebreaker: VISION.md's decision priorities).

## How to add a sound
Sounds are data: a file, a `SoundEvent` .tres around it, and a slot that holds the SoundEvent. Everything below is done in the Godot editor; nothing needs code unless the last bullet says so. (Variants and cues are A4: designed and approved 2026-10-04, not built yet; `consume_sound` was built early in CHAMPIONS K5b; Conditional audio below.)
1. **Import the file.** Drop it into `audio/sfx/` (short sounds: WAV, 16-bit 44.1 kHz, mono if it plays positioned in the world) or `audio/music/` / `audio/ambience/` (OGG Vorbis). Name it after the SoundEvent it will belong to, without `sound_`, plus a number: `audio/sfx/knight_ring_out_01.wav`. Add its row to `audio/LICENSES.md` (CC0 only for placeholders). **A loop:** click the file in the FileSystem dock → Import dock (next to Scene) → WAV: Loop Mode = Forward; OGG: Loop on → Reimport.
2. **Create the SoundEvent.** FileSystem dock → right-click `data/sounds/` → Create New → Resource… → type `SoundEvent` → Create → name it `sound_<category>_<name>.tres` (File layout, Naming; CONVENTIONS.md). In the Inspector: Variations → Add Element → drag the file(s) from the FileSystem dock (2–3 files for anything heard often).
3. **Set it up** (Inspector, same resource): `bus` (SFX for gameplay, UI for menus, Music, Ambience, Voice), `volume_db`, `pitch_scale`, `pitch_jitter` and `volume_jitter_db` (the variation), `priority` (HIGH for anything about the player's danger), `positional` and `max_distance_px` (the range; telegraphs 640), `max_instances` / `min_interval` (spam limits), `loop` (only with a looping file).
4. **Assign it to a slot.** Open the owner's .tres (an ability in `data/abilities/`, a status in `data/statuses/`, the combo in `data/combos/` → Swings → the swing, a HitFeel, a ChampionData) → the "Sounds" group → drag the SoundEvent onto the slot (`cast_sound`, `hit_sound`, `swing_sound`, `apply_sound`...; Hooks lists every slot). Run the sandbox (F6 on `sandbox_main.tscn`); the audition tool (Z, A5) plays it without a fight.
5. **Make it change with the game's state** (A4): on the SoundEvent → Variants → Add Element → New SoundVariant → `mode` (REPLACE plays instead of this sound, ADD plays on top) → `sound` (drag another SoundEvent) → Conditions → Add Element → New Condition → `kind` and its fields (the same `Condition` abilities use: ABILITIES.md, Conditions; e.g. SELF_HAS_STATUS, `status_tag` `edge`, `min_stacks` 10). **Timed to a motion** (A6, which replaced A4's cues; Sound triggers): a `SWING_START` or `CAST_START` trigger with `at_progress`. *(A4's text, superseded:)* the swing or ability → Sound Cues → Add Element → New SoundCue → `progress` (0–1 of the swing or cast) and `sound`.
6. **What needs code:** a new place a sound can fire (a new slot on a class, e.g. an impact on every `execute()`), a new `Condition` kind, or a new owner (a system with no sound slots yet). A new sound on an existing slot, a variant, a cue or a status's end sound never does.
7. **Choose exactly when, where and how it plays** (A6a, sound triggers): FileSystem dock → open the champion's `data/champions/<name>.tres` (or the enemy's `data/enemies/<name>.tres`) → Inspector → Sounds → `Sound Sheet`: drag its `data/sound_sheets/sound_sheet_<owner>.tres`, or click the empty slot → New SoundSheet → right-click it → Save As… → `data/sound_sheets/sound_sheet_<owner>.tres`. Open the sheet → Triggers → Add Element → New SoundTrigger → click it to expand: **Name**; **When**: Event, At Progress (SWING_START / CAST_START: 0–1 of the motion; −1 = at the event), Delay (seconds); **Which**: the filters for that event (Swing Number 1–N, Ability Id, Status Id, Stacks, End Reason, Hit Tags, Used Empower...) and Conditions; **Where**: Place; **How**: Sound (drag a SoundEvent), Volume Db, Pitch, Chance, Cooldown, Every Nth, Once Per Frame. Save (Ctrl+S) and run the sandbox. A Player's sounds stay centered whatever Place says, except a HIT_DEALT at the other unit (the impact). A trigger and a slot holding the same sound both play: keep it in one of them.

## Player experience
Every hit has a crunch you feel as much as see; the finisher and kills land heavier, and crits ring out. You hear an elite winding up before you see it, and a heartbeat tells you you're low without looking at the health bar. Packs die in one satisfying burst, not a wall of overlapping noise. The mix stays readable in chaos: what matters to you (your hits, your danger) is always on top.

## References
- Hades. Take: crunchy, punchy hit sounds that land during the hitstop; wind-up sounds on enemy attacks; a heavier finisher; music that lifts in combat and settles after a room clears.
- League of Legends. Take: every ability has its own cast sound (kit identity); a distinct crit sound; an "ultimate ready" ping. Don't take: constant voice lines.
- Diablo. Take: item drops that sound different by rarity; pack deaths that burst; positional sound that tells you where enemies are. Don't take: sound spam from dozens of identical hits.

## Principles
1. Audio never changes gameplay state (like VFX). Nothing waits on a sound.
2. Never audio-only: anything the player must know also has a visual. Audio makes it faster to read, not possible to read.
3. `play()` is called in the same frame as its event. No queuing, no delays of our own (Godot adds its output latency; see Godot behavior).
4. The player's own actions and threats to the player win the mix; enemy-on-enemy noise loses.
5. Variety beats repetition: every common sound has variations and slight pitch/volume jitter.
6. One way to play sounds: everything goes through the Audio autoload.

## Rules (MUST)
- Every sound is a SoundEvent resource (`data/sounds/sound_<category>_<name>.tres`; File layout, Naming). A null SoundEvent field = silent, never an error. A SoundEvent with no usable audio (a missing or empty file) warns once per SoundEvent and stays silent. (Godot's loader also prints its own error when a .tres points at a missing file; we can't suppress that one.)
- Owner components play the sounds on their own data (a swing's sound, a dash, an ability cast) through the Audio autoload, the same way they call GameFeel and VFX. Cross-system sounds (hits, deaths, statuses) come from an audio listener on Events (`unit_hit`, `unit_damaged`, `unit_died`, `status_applied`, `status_removed`): `CombatSounds`. Combat code never plays a hit or death sound itself; a swing's or ability's own hit sound reaches the listener through `HitContext.hit_sound`.
- There is no "play sound" GameplayEffect. A ReactionRule makes a sound only through what it creates: the status it applies plays that status's sound; a proc hit plays a hit sound.
- Sounds play in real time: `Engine.time_scale` (hitstop) never slows or pitches them, and instance limits are timed in real time (like GameFeel's hitstop).
- The pause menu pauses every sound on the SFX, Ambience and Voice buses (their players pause with the scene tree; Godot buses themselves can't pause) and ducks Music; UI sounds keep playing.
- Instance limits: no SoundEvent starts more than `max_instances` copies within any `min_interval` window (a sliding window, real time); extra starts are dropped. A global SFX voice cap drops the lowest-priority sound first.
- Player-relevant sounds (the player's hits, the player being hit, telegraphs, low health) get high priority; enemy hits on other units get low priority.
- The player's own sounds are non-positional (centered): anything played on or from the Player node (its swings, dash, hurt, heartbeat, statuses on it, and the hit sounds of its hits). Enemy, telegraph and world sounds are positional, with the listener on the camera.
- Telegraph wind-up sounds are owned by the Telegraph: when a cast is cancelled or interrupted and the telegraph is freed, its sound stops.
- Status loops (e.g. a burn crackle) start on apply and stop on remove, one loop per status per unit (not per stack).
- DoT ticks are silent by default; the apply sound and the loop carry them.
- Pack burst (built in A2): when 3 or more enemies die within 0.1 s, the death that makes 3 plays one "pack burst" sound instead of its own, and later deaths in that window are silent. Deaths in the same frame are counted together at the end of that frame (still the same frame), so a swing that kills a pack plays only the burst; the first two of a spread-out trio keep their own sounds.
- `hurt_sound` stays null on normal enemies (their hit sound is enough). It's for the player and, later, elites and bosses.
- Volume is the player's choice: Master, Music, SFX, UI, Ambience, Voice sliders live in the Settings autoload (saved to `user://settings.cfg`) and the Esc pause menu.
- Tests can check audio without hearing it: the Audio autoload keeps a log of what played, what was dropped and why.

### Conditional audio rules (A4; approved 2026-10-04, not built; Conditional audio below)
- Sounds are authored as data in the Inspector, never as code per sound: a sound that changes with the game's state is a `SoundVariant` on its SoundEvent, gated by the same `Condition` resource abilities, augments, reaction rules and the enemy AI use (ABILITIES.md, Conditions). No second condition system.
- **Audio reflects state and never decides it.** A variant reads conditions; it never applies a status, spends a resource or starts a cast. Whatever makes the state (a stack, an empower) is gameplay data elsewhere.
- **Every conditional state that matters in play has a visual tell too** (a status's `vfx`, a swing's `swing_vfx`, the HUD): never audio-only, as for every other sound (Principle 2). VFX and audio never change gameplay state (COMBAT.md).
- Variants and cues are sounds like any other: each one obeys its own SoundEvent's instance limits, priority and the SFX voice cap, and is logged.
- **Additive:** a SoundEvent with no variants, a swing or ability with no cues and a status with no `consume_sound` play exactly as before A4 (one exception, written into A4's data: the shield's break moves to `consume_sound`, so it still plays when the shield is used up).
- Tests check variants through the audio log ("given this condition, this variant played"), seeded, with no view (CONVENTIONS.md, Testing).

## Hooks
Optional fields on existing classes, all null (silent) by default. Every SoundEvent field on another class ends in `_sound`.

| Field | Fires | Played by | Bus / position |
|---|---|---|---|
| `AttackSwing.swing_sound` | swing start (`AutoAttackComponent.try_swing()`), whiffs included | AutoAttackComponent | SFX, centered for the player |
| `AttackSwing.hit_sound` | on landing: `HitPipeline.basic_attack()` copies it to `HitContext.hit_sound` → `Events.unit_hit` | CombatSounds | SFX, target (centered for the player's hits) |
| `AttackSwing.sound_pitch` (1.0) | multiplies both; copied to `HitContext.hit_sound_pitch`, which applies to whichever hit sound plays (its own or the tier's). The Knight's swings pitch up slightly across the combo; the finisher has its own heavier sounds | | |
| `HitFeel.light_sound` / `heavy_sound` / `kill_sound` | `Events.unit_hit` with no own sound, target not the player; the default for hits without their own (feel NONE uses the light one) | CombatSounds | SFX, target |
| `HitFeel.crit_sound` | `unit_hit` with `is_crit`: a layer on top of any crit | CombatSounds | SFX, target |
| `HitFeel.shield_absorb_sound` | `unit_hit` with `absorbed` > 0 (the moment the shield number shows) | CombatSounds | SFX, target |
| `DashComponent.dash_sound` | `DashComponent.try_dash()` | DashComponent | SFX, centered |
| `Unit.hurt_sound` (export group "Sounds") | `Events.unit_damaged` with `health_lost` > 0 | CombatSounds | SFX, centered for the player |
| `Unit.death_sound` (set in each enemy scene), `AudioMix.pack_burst_sound` | `Events.unit_died`, flushed at the end of the frame | CombatSounds | SFX, the unit |
| `Ability.cast_sound` | cast start (`AbilityComponent._do_cast()` at `cast_started`) | AbilityComponent | SFX, caster |
| `Ability.hit_sound` | on landing, not per target: `from_ability()` copies it to `HitContext.hit_sound` → `Events.unit_hit`; CombatSounds plays it once per (source, sound, frame), so once for everyone a cast hits in one frame (a projectile's hits in later frames each play it) | CombatSounds | SFX, target |
| `Ability.telegraph_sound` | a wind-up, after `Ability.on_cast_started()` sets `ctx.telegraph` (`Telegraph.play_sound(event)`) | Telegraph | SFX, telegraph, 640 px |
| `Ability.ready_sound` | `AbilityComponent.cooldown_finished(slot, ability)` (the Knight's R) | AbilityComponent | the event's bus, centered |
| `Ability.charge_sound` | a loop (the SoundEvent's `loop` on) on the caster from `charge_started` until release, cancel or interrupt (ABILITIES.md) | AbilityComponent (`play_on`, stopped by handle) | SFX, caster (centered for the player) |
| `StatusEffect.apply_sound` / `loop_sound` | `Events.status_applied` | CombatSounds | SFX, the unit (loop follows it) |
| `StatusEffect.expire_sound` | `Events.status_removed` (unit alive). From A4: `Events.status_ended` with reason EXPIRED, CLEANSED or REMOVED | CombatSounds | SFX, the unit |
| `StatusEffect.consume_sound` (A4's, built early in CHAMPIONS K5b) | `Events.status_ended` with reason CONSUMED: an empower used up by its swing or cast, a shield used up by damage. null = silent on a use-up. Until A4 moves `expire_sound` to `status_ended`, `expire_sound` also plays on a use-up | CombatSounds | SFX, the unit |
| ~~`AttackSwing.sound_cues` (A4, not built)~~ superseded 2026-10-10 by A6's `at_progress` (Ryan) | each cue as the swing's progress passes its `progress` (follows `attack_speed`) | AutoAttackComponent | SFX, the attacker |
| ~~`Ability.sound_cues` (A4, not built)~~ superseded 2026-10-10 by A6's `at_progress` (Ryan) | each cue as the cast's progress passes it (AB14; follows cast speed) | AbilityComponent | SFX, the caster |
| `SoundEvent.variants` (A4, not built) | wherever the SoundEvent plays: resolved by Audio from the caller's `SoundContext` | Audio | the variant's own |
| `ChampionData.sound_sheet`, `EnemyData.sound_sheet` (A6a) | each trigger's own event, progress point and delay (Sound triggers and the tuning panel) | SoundTriggers (Audio's child) | the trigger's place |
| `Player.low_health_sound`, `low_health_fraction` (0.25) | `HealthComponent.health_changed` | Player | SFX, centered, loop |
| `main.gd` `room_cleared_sound` / `player_died_sound` | `_on_enemy_died()` / `_on_player_died()` | main.gd | SFX, centered (FREE) |

Later hooks, per system: Build order, Later. Conditional sounds (variants, cues, a status's end reason): Conditional audio.

## Numbers (TARGET: start, range)
- Pitch jitter ±5% (0–10%); volume jitter ±1 dB (0–3).
- Per-sound `max_instances` 3 within `min_interval` 0.05 s (1–6; 0.03–0.1 s). Global SFX voice cap 32 (16–64).
- Combo pitch: swing 1 ×1.00, swing 2 ×1.04; the finisher uses its own sound.
- Positional: `max_distance_px` 480 (320–640; the screen is 640 wide); pan strength 0.5 (0–1), subtle, so sounds don't jump between ears. Pan strength is the project setting `audio/general/2d_panning_strength`; every player keeps its own `panning_strength` at 1.0.
- Telegraph sounds carry farther: `max_distance_px` 640 (480–800), so an off-screen elite is heard.
- **In the 3D view, distances scale with it (Ryan, P4, 2026-10-02):** these distances were set when "the screen is 640 wide". The 3D camera shows 28 m (896 px) across at its focus, so an unscaled 480 px would end well inside the screen (a sound at the screen's edge at 7% volume instead of 33%).
  - While the 3D camera's listener is current, `Audio.distance_scale` is the view's width over the screen's (896 / 640 = 1.4). Each positional sound's reach is `max_distance_px` × the scale, and its panning strength is 1 ÷ the scale. A sound at the screen's edge is as loud and as panned as in 2D.
  - The data keeps one set of numbers (still read as "for a 640 px screen"), the 2D game is unchanged, and the scale is 1 again when the camera leaves.
- Low-health heartbeat below 25% max health (15–35%).
- Pack burst: 3 deaths within 0.1 s (built; FREE to retune).
- Pause: Music −6 dB (0 to −12), low-pass FREE.
- Bus starting levels: Master 0, Music −8, SFX 0, UI −4, Ambience −12, Voice −2 dB (all FREE to retune).
- Latency: keep the project's audio output latency at the default or lower, and say what it is. The default `audio/driver/output_latency` is 15 ms and the project doesn't override it; the real value depends on the OS driver, so the audio test prints `AudioServer.get_output_latency()`.

## Current code
The audio code: the `Audio` autoload (registered last), its child `CombatSounds`, `SoundEvent`, `AudioMix` + `audio_mix_default.tres`, `default_bus_layout.tres`, 32 SoundEvents in `data/sounds/` over 44 synthesized placeholder WAVs in `audio/sfx/` (`audio/LICENSES.md`), `audio_test.tscn`. `project.godot` has no `[audio]` section: every audio setting is at its default.

What audio hooks into:

| Code | What audio uses |
|---|---|
| `Events` (`scripts/autoload/events.gd`) | `unit_hit(ctx)`: every hit that got through, even for 0 damage. `unit_damaged(ctx)`: `taken_damage` > 0. `unit_died(unit, ctx)`: a death from a hit. `status_applied(unit, status)`: every application, refresh and new stack. `status_removed(unit, status)`: ran out, removed, used up, or the death `clear()`. A blocked hit (i-frames) emits nothing. |
| `Unit.on_hit(ctx)` | In order: mitigation, shields (`ctx.absorbed`), health (`health_lost`, `killed`), number, flash, knockback, statuses, `GameFeel.play_hit_feel`, then `Events.unit_hit` / `unit_damaged` / `unit_died`, on-hit procs, post-hit i-frames. `ctx.source`, `target`, `feel`, `is_crit`, `tags` (`dot`, `proc`) are all set by the time the events fire. |
| `HitPipeline.basic_attack()` / `from_ability()` | Build every swing and ability hit; they copy `HitContext.hit_sound` from the swing or ability. |
| `GameFeel`, `HitFeel` (`data/hit_feels/hit_feel_default.tres`) | Hit tiers LIGHT / HEAVY / kill; feel NONE for abilities and League-style enemy attacks. Hitstop sets `Engine.time_scale` 0.05 and is timed with `Time.get_ticks_msec()`. |
| `AutoAttackComponent` | `try_swing()` starts a swing and emits `swing_started(index, direction, swing)` (whiffs included). `_land_swing()` resolves every target in one loop, then `swing_landed(index, targets)`. League mode (enemies): `windup_started`, `attack_landed`, `attack_whiffed`; no sound hooks yet. |
| `DashComponent.try_dash()` | Emits `dash_started(direction)`. Player only. |
| `AbilityComponent._do_cast()` | `cast_started(slot, ability, ctx)`, then `ability.on_cast_started()` (may set `ctx.telegraph`), the cast time (a game-time timer), `execute()`. A cancel or interrupt frees the telegraph (`_remove_telegraph()`). Cooldowns tick in `_physics_process`; `cooldown_finished(slot, ability)` fires when a slot goes from 0 charges to 1. |
| `StatusComponent` | `apply_status()`: a new status runs `_start()`; REFRESH runs `_stop()` + `_start()` on the same entry without `status_removed`; STACK and REFRESH_LONGER update in place. `remove_status()` emits `status_removed`. `clear()` on death runs after the unit is marked dead. A status's `vfx` is instanced as a child of the unit. |
| `Telegraph` (`scripts/vfx/telegraph.gd`) | A child of the room (under the units), not of the caster. `finish()` flashes 0.12 s and frees it. A caster that dies or is freed mid-cast frees it at once (`AbilityComponent.interrupt_cast()`, COMBAT.md). |
| `Unit._on_died()` | Marks the unit dead, cancels its attack, ends its cast (`interrupt_cast()`), clears its statuses, emits `died`, then `queue_free()` after `death_free_time` (0.33 s, game time; the 2D death tween's length until the 3D pivot's cleanup; the Player isn't freed). |
| `Player` | `on_hit` override (2 px shake). `health.health_changed(current, max)` (main.gd feeds the HUD from it; the heartbeat reads it). |
| `main.gd` | "Room cleared!" in `_on_enemy_died()` when none are left; "You died" in `_on_player_died()`; Backspace → `Audio.stop_all()` then `get_tree().reload_current_scene()` (autoloads survive a reload). |
| `Settings` | The dash direction, the cast mode and one volume per bus; `ConfigFile` at `user://settings.cfg`; `setting_changed(key, value)`. |
| `PauseMenu` (`scenes/ui/pause_menu.tscn`) | A CanvasLayer with process mode Always; `open()` sets `get_tree().paused`. Dash direction and cast mode buttons, six volume sliders, Resume. |
| `GameCamera3D` (3D.md) | The 3D view's camera, with the same follow smoothing (10), aim lean (up to 80 screen px) and shake as the 2D `GameCamera` (Camera2D, deleted in the 3D pivot's cleanup C3). Its `AudioListener2D` follows the focus, so what the player sees is where sounds are heard from (P4). |
| `project.godot` | Autoloads GameFeel, Events, WorldQuery, Settings, Reactions, Audio. |

## Data (Resources)
Names checked against CONVENTIONS.md: `Audio`, `SoundEvent`, `AudioMix` and `CombatSounds` are reserved there. A4–A5's names (`SoundVariant`, `SoundCue`, `SoundContext`, `StatusEffect.EndReason`, `Events.status_ended`, `SandboxAudio`; later `UISoundSet`) were approved by Ryan 2026-10-04 and are reserved there.

### SoundEvent (Resource, `res://scripts/data/sound_event.gd`; files `res://data/sounds/sound_<category>_<name>.tres`)
| Field | Type | Default | Notes |
|---|---|---|---|
| `variants` (A4, not built) | `Array[SoundVariant]` | `[]` | Sounds that play instead of this one (REPLACE) or on top (ADD) when their conditions pass (Conditional audio). Empty = as today. |
| `variations` | `Array[AudioStream]` | `[]` | One or more files. Wrapped once (cached) in an `AudioStreamRandomizer` with `PLAYBACK_RANDOM_NO_REPEATS`: never the same file twice in a row when there are 2+. Empty, or every entry null = no usable audio (warn once, silent). |
| `volume_db` | `float` | 0.0 | |
| `pitch_scale` | `float` | 1.0 | Base pitch; multiplied by the caller's pitch (combo pitch). |
| `pitch_jitter` | `float` | 0.05 | 0–0.1. The randomizer's `random_pitch` = 1 + this (a pitch between 1 / 1.05 and 1.05: −4.8% to +5%). |
| `volume_jitter_db` | `float` | 1.0 | 0–3. The randomizer's `random_volume_offset_db` (±). |
| `bus` | `SoundEvent.Bus` | `SFX` | `SFX`, `UI`, `MUSIC`, `AMBIENCE`, `VOICE` (an enum so a typo can't pick a missing bus). |
| `positional` | `bool` | true | false = always centered (UI, stingers, music). true = positional, except the player's own sounds (Rules). |
| `max_distance_px` | `float` | 480 | Positional only. Telegraph sounds 640. Falloff is linear (`attenuation` 1.0) to silence at this distance. |
| `priority` | `SoundEvent.Priority` | `NORMAL` | `LOW`, `NORMAL`, `HIGH`. CombatSounds overrides it for hits and statuses. |
| `max_instances` | `int` | 3 | 1–6. |
| `min_interval` | `float` | 0.05 | Seconds, real time (0.03–0.1). The sliding window for `max_instances`. |
| `loop` | `bool` | false | Plays until stopped (a kept handle or `play_on`). The file must also be imported with looping on (WAV: Loop Mode Forward; OGG: Loop); this flag doesn't make a file loop. |

Methods: `get_stream()` (the cached randomizer; null without usable audio; rebuilt only when the variations or the jitter change), `has_audio()`, `get_bus_name()`, `get_display_name()` (the file name, or `resource_name` for an unsaved event; logs and the debug list).

### AudioMix (Resource, `res://scripts/data/audio_mix.gd`; `res://data/audio_mixes/audio_mix_default.tres`, held by `Audio.mix`)
The mix-wide numbers, like HitFeel for GameFeel:
- `voice_cap` 32 (16–64)
- `pause_music_duck_db` −6 (0 to −12); `pause_low_pass` (true, FREE) and `pause_low_pass_hz` (FREE); `duck_fade_time` 0.15 s, real time (FREE)
- `pack_burst_sound` (`sound_death_pack_burst`; null = each death plays its own sound), `pack_burst_count` 3 (2–6), `pack_burst_window` 0.1 s (0.05–0.3)
- `log_size` 256, `debug_lines` 10, `debug_line_time` 3 s (FREE)

### Bus layout (`res://default_bus_layout.tres`, Godot's default path)
| Bus | Sends to | Start dB | Effects | While paused |
|---|---|---|---|---|
| Master | | 0 | FREE (a limiter if stacking clips) | |
| Music | Master | −8 | low-pass, off | keeps playing, ducked by `pause_music_duck_db`, low-pass on |
| SFX | Master | 0 | | pauses |
| UI | Master | −4 | | keeps playing |
| Ambience | Master | −12 | | pauses |
| Voice | Master | −2 | | pauses |

The levels are designer tuning (this file); the sliders are the player's (Settings) and apply on top.

### Placeholder sounds
Synthesized stand-ins under these names (`audio/LICENSES.md`); replace a file with a real CC0 one of the same name, or point the SoundEvent at new files. Assigned in `combo_knight.tres`, `hit_feel_default.tres`, `player.tscn`, `slime.tscn` / `slime_elite.tscn`, `audio_mix_default.tres`, the four Knight abilities, the slam, the status files and `main.tscn`.

Combat (A2):

| Sound event | Files | Should sound like |
|---|---|---|
| `sound_knight_swing` | 3 | a short sword whoosh (0.1–0.15 s), airy, no impact; swings 1–2 (pitch ×1.00 / ×1.04) |
| `sound_knight_swing_finisher` | 2 | a heavier, lower, longer whoosh (~0.25 s); the dash-strike swing uses it at pitch 1.1 |
| `sound_hit_light` | 3 | a crunchy flesh impact (≤ 0.15 s), sharp attack, fast decay; the most-heard sound |
| `sound_hit_heavy` | 2 | a bigger thump with low end (~0.2 s); the finisher |
| `sound_hit_kill` | 2 | a crunch plus a low thud (~0.3 s) |
| `sound_hit_crit` | 2 | a bright metallic ring (~0.3 s), high, sits above the crunch |
| `sound_knight_dash` | 2 | a quick air whoosh (~0.2 s), softer than the swings |
| `sound_knight_hurt` | 2 | a dull body thud or grunt (~0.2 s), clearly unlike the hits you deal |
| `sound_shield_absorb` | 2 | a glassy or metallic tink (~0.15 s) |
| `sound_slime_death` | 3 | a wet splat (~0.3 s); the elite reuses it as `sound_slime_elite_death` at pitch 0.8 |
| `sound_death_pack_burst` | 1 | one big layered wet burst (~0.5 s) |

Abilities and statuses (A3, 16 files): `sound_knight_cleave_cast`, `sound_knight_iron_resolve_cast`, `sound_knight_lunge_cast`, `sound_knight_judgement_cast`, `sound_knight_judgement_hit`, `sound_slime_elite_slam_telegraph` (a rising rumble ~0.65 s; 640 px, HIGH), `sound_slime_elite_slam_hit`, `sound_status_stun_apply`, `sound_status_slow_apply`, `sound_status_haste_apply`, `sound_status_shield_apply`, `sound_status_shield_break` (the shield's expire sound), `sound_knight_low_health` (a loop: its WAV is imported with Loop Mode Forward), `sound_ui_ultimate_ready` (UI bus), `sound_stinger_room_cleared`, `sound_stinger_player_died` (SFX, centered, HIGH).
- The wind-up plays at the telegraph, which is where the hit lands. The slam lands where the player stood, so its wind-up is always near the player; "heard from off screen" applies to telegraphs placed away from the player (up to 640 px).

Loot (LOOT L7, 3 files, synthesized in a GDScript tool, assigned in `loot_table_default.tres`): `sound_loot_drop` (a short glassy tink, ~0.35 s; a landing Uncommon–Exotic drop, −8 dB), `sound_loot_drop_legendary` (a rising three-note chime over a high shimmer, ~1.1 s; Legendary and Artifact, −4 dB, HIGH, 640 px), `sound_loot_pickup` (a soft rising blip, ~0.16 s; centered, −10 dB).

Enemies (ENEMIES_AI AI2, 1 file, synthesized in a GDScript tool, assigned in `enemy_ai_table_default.tres` as `alert_sound`): `sound_enemy_alert` (a short rough grunt rising then falling, ~0.28 s; −8 dB, pitch jitter 0.08, at most 2 at once), played on the enemy that notices you as its pack wakes, with its `alert` pose (never audio only).

Korsavil v2 (CHAMPIONS K5b, 3 files; Ryan, 2026-10-10: the passive has two sounds, and the empowered Q sounds different from the normal one). **Placeholders that reuse today's WAVs at other pitches**, no new audio files (no LICENSES.md rows): `sound_korsavil_demise_four` (`status_haste_apply_01.wav`, pitch 1.25, −4 dB) as `empower_demise`'s `consume_sound`, so it plays when the strike that uses his 4-stack empower hits (Ryan, 2026-10-10: on that hit, not when the 4th stack comes); `sound_korsavil_demise_six` (`ui_ultimate_ready_01.wav` on SFX, pitch 0.85, −3 dB) as `status_blade_singer_sweep`'s `apply_sound`, at 6; `sound_korsavil_sweep_cast` (`knight_judgement_cast_01.wav`, pitch 1.15) as the sweep's `cast_sound`. The dagger (Blade Singer) has no cast sound yet; when it gets one it stays different from the sweep's. Real files replace the placeholders in the same SoundEvents (How to add a sound, step 1).

## Architecture / contracts
### Audio (autoload, `res://scripts/autoload/audio.gd`)
Registered after Settings (it reads it in `_ready()`). Process mode Always, so its bookkeeping, fades and debug draw run while paused.

- Exports: `mix: AudioMix` (preloads `audio_mix_default.tres`); `debug_draw := false` (toggle it in the Remote scene tree while the game runs; the audio test turns it on).
- **Methods** (a handle is an `int` > 0; 0 = nothing played; `priority` −1 = the event's own):
  - `play(event, pitch, priority)`: a non-positional one-shot (or loop).
  - `play_at(event, position, source, pitch, priority)`: at a world point. Centered when `source` is the Player or the event isn't positional.
  - `play_on(event, node, pitch, priority)`: follows the node every physics frame and stops when the node leaves the tree (`tree_exiting`). Centered when the node is the Player or the event isn't positional. Every loop on a unit or telegraph uses it. A node that isn't in the tree plays nothing (logged dropped `no_owner`).
  - `stop(handle)`: stopping 0 or an ended handle does nothing. `stop_all_on(node)`. `stop_all()`: every SFX, Ambience and Voice sound; clears the instance-limit history and the pack burst window; Music and UI keep playing. `is_playing(handle)`.
  - (A4, not built) Each play method takes an optional last argument `context: SoundContext` (self, target, cast); the event's variants resolve before the play checks (Conditional audio).
  - (A6a) `play_triggered(event, position, positional, follow, pitch, volume_db, priority, trigger_name)`: a sound trigger's play, its place decided by SoundTriggers (`positional` false = centered); `get_sound_triggers()` (the SoundTriggers node); `rng` (a RandomNumberGenerator, randomized at start: triggers' chance; tests seed it). Every log entry has `trigger` ("" but for trigger plays).
  - `get_log()`, `clear_log()`, `get_player(handle)` (tests and debugging), `get_bus_base_db(bus)` (the layout level), `get_listener_position()` (the current AudioListener2D's position if there is one, the 3D camera's focus; else the screen center in world space); `distance_scale` (1; the 3D camera sets it, see Rules).
- **A play call, in order:**
  1. Null event: return 0, nothing logged.
  2. No usable audio: `push_warning()` once per SoundEvent, logged dropped `no_audio` every time.
  3. Instance limit: `max_instances` starts of this event already within the last `min_interval` (real time): dropped `instance_limit`.
  4. A positional one-shot farther than its `max_distance_px` (× `distance_scale`) from the listener (`get_listener_position()`): dropped `out_of_range`. Loops always start (they may come into range).
  5. Voice cap (SFX bus only): with `mix.voice_cap` SFX sounds playing, a new sound that outranks the lowest-priority one stops it (the oldest among equals; logged `stolen`); otherwise the new one is dropped `voice_cap`. A stolen loop stays stopped until its owner starts it again: a status loop restarts on that status's next application (CombatSounds, A3), the heartbeat on the next health change below the threshold (Player).
  6. Start: a pooled player (AudioStreamPlayer when centered, AudioStreamPlayer2D when positional; `max_polyphony` 1, `panning_strength` 1.0 ÷ `distance_scale`, `attenuation` 1.0, `max_distance` from the event × `distance_scale`), with the event's bus and `volume_db`, `pitch_scale` = event pitch × `pitch`. Logged `played`.
- **Real time:** limits and the pack burst window use `Time.get_ticks_msec()`; fades use real delta (`delta / Engine.time_scale`, like GameCamera3D's lean and pan). Nothing touches `AudioServer.playback_speed_scale`.
- **Pause:** players on SFX, Ambience and Voice are `PROCESS_MODE_PAUSABLE` (they pause with the tree and resume after); Music and UI players are `PROCESS_MODE_ALWAYS`. Audio watches `get_tree().paused` every frame: while paused, Music fades to `pause_music_duck_db` and its low-pass turns on; unpausing fades back. Any tree pause does this, not only the menu.
- **Volumes:** on `_ready()` and on `Settings.setting_changed`, each bus's dB = its layout level + `linear_to_db(Settings.get_volume(bus))`; a slider at 0 mutes the bus.
- **Log:** one entry per play, drop, stop and steal (a sound that ends on its own isn't an entry): `time_ms`, `frame`, `event` (resource path, or the name of an unsaved event), `sound` (the SoundEvent), `handle`, `result` (`played`, `dropped`, `stopped`, `stolen`), `reason`, `bus`, `priority`, `positional`, `position`; from A4 also `variant_of` and `mode` (Conditional audio). Keeps the last `mix.log_size`.
- **debug_draw:** a CanvasLayer list, top-left, of the last `mix.debug_lines` entries (`sound_hit_light  SFX  HIGH  played`); dropped and stolen ones in red with their reason; each line fades after `debug_line_time`.

### CombatSounds (Node, `res://scripts/audio/combat_sounds.gd`; a child of Audio, created in `Audio._ready()`)
Listens to Events; the only place hit, death and status sounds are played. `reset()` (called by `Audio.stop_all()`) forgets the pack burst window and this frame's pending deaths.
- **`unit_hit(ctx)`:**
  - Hits tagged `dot` are silent.
  - Hit sound: `ctx.hit_sound` if set. Otherwise, a hit on the Player plays nothing here (the hurt sound covers it); any other hit plays HitFeel's tier: `killed` → `kill_sound`, HEAVY → `heavy_sound`, LIGHT or NONE → `light_sound`.
  - Once per (source, sound, frame): later hits with the same key in the same frame are skipped, so a swing or cast plays one hit sound however many it hits. At the target's position; centered when the source is the Player.
  - Priority: HIGH if the source or the target is the Player, else LOW.
  - Crit layer: `ctx.is_crit` → `HitFeel.crit_sound`, same once-per key.
  - Shield: `ctx.absorbed` > 0 → `HitFeel.shield_absorb_sound` at the target (instance limits cap it).
- **`unit_damaged(ctx)`:** `ctx.health_lost` > 0 and the target has a `hurt_sound` → play it at the target (centered on the Player), HIGH. A hit a shield fully absorbed plays no hurt.
- **`unit_died(unit, ctx)`:** deaths are collected during the frame and flushed at its end (`call_deferred`). Enemies only count toward the pack burst. At the flush: count enemy deaths in the last `pack_burst_window` (real time), this frame's included. If that reaches `pack_burst_count` and no burst played in the window, `pack_burst_sound` plays once (at the average position of this frame's deaths) instead of this frame's death sounds; if a burst already played in the window, they're silent. Otherwise each unit's `death_sound` plays at its position. With no `pack_burst_sound` set, every death plays its own sound. The player's death plays its own `death_sound` (if set) and never counts.
- **`status_applied(unit, status)`:** `apply_sound` at the unit on every application (refresh and stack included; limits cap spam). `loop_sound`: if no loop is running for (unit, `status.id`), `Audio.play_on(loop_sound, unit)`, kept in a dictionary (a loop stolen by the voice cap starts again on the next application).
- **`status_removed(unit, status)`:** stops that loop; `expire_sound` only if the unit is alive (the death `clear()` is silent). A used-up shield ends through here, so the shield status's `expire_sound` is the shield break.
- Status sounds on the Player are HIGH; on anyone else the event's own priority.

### Owner calls (each owner plays its own data)
- **AutoAttackComponent** `try_swing()`: `Audio.play_on(swing.swing_sound, unit, swing.sound_pitch)` at swing start, whiffs included.
- **DashComponent** `try_dash()`: `Audio.play_on(dash_sound, unit)`.
- **AbilityComponent** `_do_cast()`: `Audio.play_on(ability.cast_sound, unit)` at `cast_started`; after `on_cast_started()`, if `ctx.telegraph` is valid, `ctx.telegraph.play_sound(ability.telegraph_sound)`. When a slot goes from 0 charges to 1: `cooldown_finished(slot, ability)` and `Audio.play(ability.ready_sound)`. A refunded cooldown (cancel, interrupt) doesn't ping.
- **Telegraph** `play_sound(event)`: `Audio.play_on(event, self)`. `finish()` stops it (the hit sound takes over); freeing stops it.
- **Player**: on `health.health_changed`, below `low_health_fraction` × max and alive with health above 0 → start the heartbeat (`Audio.play_on(low_health_sound, self)`) if it isn't running; at or above it, or dead → stop it.
- **main.gd**: `Audio.play(room_cleared_sound)` where "Room cleared!" shows, `Audio.play(player_died_sound)` where "You died" shows, and `Audio.stop_all()` right before `reload_current_scene()`.
- **Settings**: `get_volume(bus) -> float` (0–1), `set_volume(bus, value)`; keys `&"volume_master"`, `&"volume_music"`... emitted through `setting_changed`; saved as whole percents (0–100) in an `[audio]` section (the "words" rule is for enums).
- **PauseMenu**: six sliders (0–100, step 5) with their percent, one per bus, above Resume.

## Conditional audio (A4–A5; designed and approved 2026-10-04, not built)
Ryan's goal: a sound that changes with the game's state is data in the Inspector ("dials and switches"), never code per sound. Any ability, swing, status, and later UI element, can have one, gated by the same `Condition` resource abilities and augments use. Rules: Rules, Conditional audio rules. Ryan approved the design, its defaults and its names on 2026-10-04 (DECISIONS.md, Audio).

**What already works with no new code:** a combo of 3 swings with 3 sounds, or 4 swings with 4 sounds. Each combo step is its own `AttackSwing` (`AttackCombo.swings`), and each has its own `swing_sound` and `hit_sound` (A2). The Knight shares one swing sound between swings 1–2 at two pitches; another champion can give every step its own.

### SoundVariant (Resource, `res://scripts/data/sound_variant.gd`; inline in the SoundEvent that uses it)
| Field | Type | Default | Notes |
|---|---|---|---|
| `conditions` | `Array[Condition]` | `[]` | all must pass (AND, `Condition.all_met()`); an empty list always passes |
| `sound` | `SoundEvent` | null | what plays. A REPLACE variant with no sound silences the base in that state |
| `mode` | `SoundVariant.Mode` | `REPLACE` (the default; Ryan, 2026-10-04) | `REPLACE`: plays instead of the base sound. `ADD`: plays on top of whatever plays |

New field on **SoundEvent**: `variants: Array[SoundVariant]` (`[]`). Empty = the sound plays exactly as today.

**Resolution, when the sound starts** (in Audio, the one place sounds play):
1. The main sound: the first REPLACE variant, in list order, whose conditions all pass; none = the base SoundEvent.
2. Layers: every ADD variant whose conditions pass, in list order, on top of the main sound.
3. One level only (Ryan, 2026-10-04): a variant's own SoundEvent's `variants` aren't resolved (like Conditions: no nesting). Stack several variants on one sound instead.
4. Each resolved sound then goes through its own play checks (instance limit, range, voice cap; Architecture, A play call). A dropped main sound doesn't fall back to the base, and layers try on their own.
5. Loops resolve once, when they start. A loop doesn't switch variants mid-play when the state changes; its owner restarts it if it needs to (none does today).
6. The caller's pitch (the combo pitch) and priority apply to the main sound and every layer.
7. Handles: `play*()` returns the main sound's handle; the layers are tied to it, so `stop(handle)` stops them too, and a `play_on()` layer follows the same node.
8. Log: each entry also has `variant_of` (the base SoundEvent's name when a variant played, else empty) and `mode` (`base`, `replace`, `add`), so a test reads "given this condition, this variant played".

### SoundContext (RefCounted, `res://scripts/audio/sound_context.gd`)
A condition needs units to check (`Condition.is_met(self_unit, target, cast)`), so the owner says what it has: `self_unit: Unit`, `target: Unit`, `cast: CastContext` (any may be null). One context object, not a longer argument list (CONVENTIONS.md, Context objects at every seam). It's an optional last argument of `play()`, `play_at()` and `play_on()`; with none, only variants with no conditions apply (`is_met()` fails with no self unit). The brain's `SituationContext` is never passed, so RESPECT and the other situation kinds are false in a sound.

What each call site can give:

| Sound | self | target | cast |
|---|---|---|---|
| `AttackSwing.swing_sound` and the swing's cues | the attacker | the aimed enemy (the melee assist target), else null | null |
| hit sounds: `AttackSwing.hit_sound`, `Ability.hit_sound`, HitFeel's tier, the crit layer, `shield_absorb_sound` | `ctx.source` | the unit hit | `HitContext.cast` (null for swings) |
| `Ability.cast_sound`, the ability's cues, `charge_sound`, `telegraph_sound` | the caster | `ctx.target` (a UNIT target, or the condition target when the ability needs one) | the CastContext |
| `Ability.ready_sound`, `DashComponent.dash_sound` | the unit | null | null |
| `Unit.hurt_sound` | the hurt unit | `ctx.source` | `HitContext.cast` |
| `Unit.death_sound` | the dead unit (its statuses are already cleared at death) | `ctx.source` | null |
| `pack_burst_sound` | none (several units): only variants with no conditions | | |
| status `apply_sound`, `loop_sound`, `expire_sound`, `consume_sound` | the unit carrying the status | the status's source (who applied it), if alive | null |
| `Player.low_health_sound`, the stingers | the Player | null | null |
| loot and enemy sounds (LOOT L7, ENEMIES_AI AI2) | the dropping or alerted unit | null | null |
| UI sounds (later, UI.md) | the tracked Player | null | null |

**When a hit's variants are checked:** CombatSounds plays a hit sound on `Events.unit_hit`, after the hit's own statuses (`Unit.on_hit` applies them before the events) and after `Reactions` (connected to `unit_hit` before Audio, so its rules run first). A variant on a hit sound sees the state *after* that hit and its reaction rules.

### SoundCue (Resource, `res://scripts/data/sound_cue.gd`; inline)
> **Superseded 2026-10-10 (Ryan): folded into sound triggers** (A6: a `SWING_START` or `CAST_START` trigger's `at_progress` does this, by the same progress and cancel rules). Not built; kept as the reasoning behind `at_progress`.
| Field | Type | Default | Notes |
|---|---|---|---|
| `progress` | `float` | 0.0 | 0–1 of the swing or cast where it plays |
| `sound` | `SoundEvent` | null | variants resolve as for any sound |

- **Why cues:** the Knight's clips are positioned by progress (`UnitView` seeks a swing's `swing_anim` and a cast's `cast_anim` to the progress each tick: 3D.md; COMBAT.md, AttackSwing), not played, so call-method tracks on the animation can't be trusted to fire. Cues are timed on the same progress the clip follows.
- New fields: `AttackSwing.sound_cues: Array[SoundCue]` and `Ability.sound_cues: Array[SoundCue]` (`[]`, export group "Sounds"). `swing_sound` and `cast_sound` stay, as the cue at progress 0, so today's data needs no change.
- **Swings:** AutoAttackComponent plays each cue on the tick the swing's progress (`get_swing_progress()`: time since the swing started ÷ its length at its speed) reaches or passes its `progress`, in order. Swing progress follows `attack_speed` and the combo's `speed_scale`, and it runs in game time (hitstop slows it with the swing), so a cue stays on its frame of the motion. A cue at 0 plays at swing start, after `swing_sound`. The dash-strike swing has its own cues.
- **Casts:** AbilityComponent plays each cue as the cast's progress (AB14, `_advance_cast_time()`) passes it, so cues follow cast speed. A cast with no cast time (and a free cast, progress 1 at once) plays every cue at cast start, in order. CHARGE_UP and VECTOR count from release, like the progress. Each recast part plays its own ability's cues.
- **How many:** no cap; the audition tool warns past 4 cues on one swing or cast, so a motion doesn't turn into sound spam (Ryan, 2026-10-04).
- **Cancelled or interrupted** (a dash, a move cancel, a stun, death, a swing cut after its hit): cues not yet reached never play. One-shots already started play out. A cue whose SoundEvent loops stops when its swing or cast ends, however it ends.
- League-style enemy attacks aren't swings and have no cues (ENEMIES_AI.md).

### Why a status ended (A4)
`status_removed` fires the same way when a status times out, is used up, is cleansed, ends at death, or its source takes it back, so today `expire_sound` can't tell them apart. Every removal path in the code (checked 2026-10-04):

| Path | Reason |
|---|---|
| its time runs out (`StatusComponent._physics_process`) | `EXPIRED` |
| an empower used by its swing (`AutoAttackComponent._use_up_empowers()`) or cast (`AbilityComponent`, effect start); a shield's last stack used up by damage | `CONSUMED` |
| `remove_statuses_with_tags()`: a cleanse (`RemoveStatusesByTagGameplayEffect`), unstoppable ending every cc | `CLEANSED` |
| `clear()` at death | `DIED` |
| anything else: a speed modifier removed, leaving a perch, an item's bundle unequipped, a form replaced by another, an airborne that couldn't start | `REMOVED` |

- `StatusEffect.EndReason` (enum on StatusEffect, like `StackRule`): `EXPIRED`, `CONSUMED`, `CLEANSED`, `DIED`, `REMOVED`. Ryan's list plus `REMOVED`, because the code has removal paths that are none of the four.
- `StatusComponent.remove_status(id, reason := EndReason.REMOVED)`: an optional parameter, so every caller today keeps working; the paths above pass theirs.
- **A separate signal, not a changed one:** `StatusComponent.status_ended(effect, reason)` and `Events.status_ended(unit, status, reason)`, emitted right after `status_removed`, which stays exactly as it is.
  - Not new arguments on `status_removed`: changing a signal's argument count breaks every callable already connected to it (AutoAttackComponent, CombatSounds, the tests).
  - Not a field on the status: a `StatusEffect` is a shared Resource (one .tres for every unit that carries it), so a reason written there would be overwritten by another unit's removal in the same frame and is no one unit's state (CONVENTIONS.md, Components own their state).
  - Not a "last reason" field on StatusComponent: it would only be right during the emit; a listener running at the end of the frame (like the pack burst) would read the wrong one.
- CombatSounds keeps stopping the loop on `status_removed` and plays the end sound on `status_ended`: `CONSUMED` → `consume_sound`; `EXPIRED`, `CLEANSED`, `REMOVED` → `expire_sound` (as today); `DIED` → nothing (as today).
- New field `StatusEffect.consume_sound` (null). With no fallback to `expire_sound` (Ryan, 2026-10-04): an empower that rings and sheathes must be able to stay quiet when it's used up. The only status with an end sound today, the shield, gets `consume_sound` = `sound_status_shield_break` in A4's data, so its break still plays when it's used up (and on a timeout, through `expire_sound`).
- Later, if needed: a `cleanse_sound`, and a STATUS_ENDED reaction trigger with a reason filter (COMBAT.md, ReactionRule); not part of A4.
- **Built early in CHAMPIONS K5b (2026-10-10), for Korsavil's 4-stack sound:** `StatusEffect.EndReason`, `remove_status(id, reason)` with every path in the table passing its reason, `status_ended` on StatusComponent and Events, `StatusEffect.consume_sound`, and CombatSounds playing it on CONSUMED. **Still A4's:** `expire_sound` moving from `status_removed` to `status_ended` (EXPIRED, CLEANSED, REMOVED), and the shield's `consume_sound` in its data.

### Example: the ring-out (an illustration; the Knight's kit doesn't change)
Ryan's example, as data only, for a made-up champion with a 4-hit combo and a stacking status tagged `edge` (one stack per hit; the stacks are gameplay, granted by a HIT reaction rule as today):
1. **Four swings, four sounds:** `AttackCombo.swings` holds four AttackSwings, each with its own `swing_sound` and `hit_sound` (works today).
2. **The ring-out:** swing 4's `hit_sound` (`sound_x_finisher_hit`) has one SoundVariant: REPLACE, conditions [SELF_HAS_STATUS, `status_tag` `edge`, `min_stacks` 10], sound `sound_x_ring_out`. 10 or more stacks: the ring-out plays instead of the normal finisher hit.
3. **The empower that hit grants** is a status `status_x_ringing` (tags `empower`, `buff`; `empower_consumed_by` ABILITY_CAST, 4 s): `apply_sound` = the ring's start, `loop_sound` = the sword ringing while it's up, `expire_sound` = the sheath (it timed out: EXPIRED), `consume_sound` = the big impact (the next cast used it up: CONSUMED). Its `vfx` is the visual tell (the blade glowing).
4. **The big impact goes on `consume_sound`, not on a variant of the next ability's sound:**
   - A SELF_HAS_STATUS variant on the next ability's `hit_sound` would never pass: the cast uses up its empowers at the effect start, before its hits land (ABILITIES.md, Empowers).
   - On its `cast_sound` it would play at cast start, before the empower is used, so a dash-cancelled cast (which keeps the empower) would play the big impact for nothing. Audio would claim something that didn't happen.
   - `consume_sound` plays exactly when the empower is used up. If a variant on the ability's own sound is wanted later, it needs a new condition kind reading the cast's used empowers (`cast.empowers`; Open questions).
5. **Order on the 4th hit:** the ring-out's condition is checked after that hit's reaction rules (When a hit's variants are checked). If the rule that grants the empower also spends the 10 stacks, gate the ring-out on the empower instead (SELF_HAS_STATUS `ringing`, 1).
6. **Not audio, and not data today:** "the 4th hit grants the empower" needs a HIT reaction rule that knows which swing hit. An AttackSwing has no tags today, so that half needs a small COMBAT addition (proposed there: `AttackSwing.hit_tags`, e.g. `finisher`) or a script. Conflicts, and COMBAT.md, Open questions.

### UI sounds (for UI.md; Build order, Later)
- A sound set per UI element type (`UISoundSet`, a Resource; the name approved 2026-10-04, built with UI.md): `hover_sound`, `press_sound`, `open_sound`, `close_sound`, all SoundEvents on the UI bus (non-positional; they keep playing while paused). Variants work as anywhere, with the tracked Player as `self` (e.g. a different press sound when an ability can't be afforded).
- **Hover:** on `mouse_entered` the element plays `hover_sound` and keeps the handle; on `mouse_exited` or a press it calls `Audio.stop(handle)`. A press may play its own `press_sound`. Keyboard and controller focus come with UI.md.

### The audition tool (A5): SandboxAudio on Z
A sandbox-only node (`res://scripts/rooms/sandbox_audio.gd`, in `sandbox.tscn` and `sandbox_3d.tscn`, never room_01), in the style of the other sandbox tools: **Z** opens and closes a mouse panel like SandboxBrains' N panel. Z is free: it isn't an input action, no sandbox script reads it, and no doc plans it (M is the map, V the ally stance, Tab the companion slot). A click on the panel also swings, as on N's panel (MOVEMENT.md, Clicks on the HUD).
- Three lists: the SoundEvents in `data/sounds/`, the abilities in `data/abilities/`, the statuses in `data/statuses/`.
- A sound: its variants with their conditions in words, whether each passes now (self = the Knight, target = the enemy nearest the cursor), which one resolves (the REPLACE winner and the ADD layers), Play (the resolved sound on the Knight; Shift: at the nearest enemy) and Play base (no variants).
- An ability or a swing: its sound slots and cues, each with Play.
- A status: its four sounds with Play, Apply to the Knight, a **stack count** (0–20; it applies or removes stacks so SELF_HAS_STATUS variants can be heard at any count) and End as EXPIRED / CONSUMED / CLEANSED (so each end sound can be heard).
- A warning on any swing or ability with more than 4 cues.
- The last 8 entries of the audio log (with `variant_of`) at the bottom.
- It only calls Audio, StatusComponent and AbilityComponent's public methods; it never changes saved data.

## Sound triggers and the tuning panel (A6; designed 2026-10-10, approved by Ryan the same day with changes)
Ryan (2026-10-10, after hearing Korsavil's K5b sounds): "how can i make so i can manually change it exactly when and where and how it triggers?" His picks the same day: **sound triggers**, designed here first and built after his OK, **with a live tuning panel** in the sandbox. A4's variants stay planned; A4's cues are folded in here (Ryan, 2026-10-10). **Ryan's OK (2026-10-10), with his changes written in below:** the names; the cues folded in; a Player's sound placed at the enemy only for impact sounds; Korsavil's sounds moved in two steps; the panel's Save with guards; the order. The numbers and the rest of the reading stay *(proposed)*, tuned at each step's play test.

**Today's limit:** a sound sits in a fixed slot (`cast_sound`, `apply_sound`, `consume_sound`, a swing's `hit_sound`...) and plays at that slot's moment, on that slot's owner. A SoundEvent says how a sound sounds, never when or where. A6 adds the when, the where and the how as data.

**What a trigger is:** one row in a list, edited in the Inspector, that says:
- **when:** an event (a swing starting or landing, a hit dealt or taken, a cast starting or taking effect, a status gained or ended, stacks reaching a count, a kill, a dash, a deflect), optionally at a point of that swing or cast (`at_progress`), plus a `delay` in seconds;
- **which:** filters on that event (the swing's number in the chain, the ability, the status, the end reason, hit tags, the empower a hit used, crits or kills only), plus any `Condition`s (the same ones abilities use: no second condition system);
- **where:** on him (following him), where he stood, on the other unit (the enemy hit, the unit killed...), where it stood, at the cast's aim point, or centered (no position);
- **how:** the sound, a volume and pitch on top of the SoundEvent's, a chance, a cooldown, every Nth time, once per frame, on or off.

Triggers are additive: every slot keeps working exactly as today, and a unit with no sheet plays exactly as before.

### SoundSheet (Resource, `res://scripts/data/sound_sheet.gd`; files `res://data/sound_sheets/sound_sheet_<owner>.tres`)
One sheet per champion or enemy: all of its triggers in one file, one place to edit and the one file the panel saves.

| Field | Type | Default | Notes |
|---|---|---|---|
| `triggers` | `Array[SoundTrigger]` | `[]` | checked in list order; every matching trigger plays (no "first wins") |

Held by `ChampionData.sound_sheet` and `EnemyData.sound_sheet` (null = none). Later, if a kit needs it: items and talents adding triggers under their source id (as augments do).

### SoundTrigger (Resource, `res://scripts/data/sound_trigger.gd`; inline in its sheet)
Its fields sit in four Inspector groups, so it reads as When / Which / Where / How.

| Group | Field | Type | Default | Notes |
|---|---|---|---|---|
| | `name` | `String` | "" | shown in the panel and the audio log ("Demise 4: empowered hit") |
| | `enabled` | `bool` | true | the panel's on/off |
| When | `event` | `SoundTrigger.Event` | `HIT_DEALT` | the table below |
| When | `at_progress` | `float` | −1 | `SWING_START` and `CAST_START` only: plays when that swing's or cast's progress reaches it (0–1; −1 = at the event). Follows attack speed, cast speed and hitstop, like the motion; a swing or cast that ends first never plays it |
| When | `delay` | `float` | 0.0 | seconds after the event (or the progress point), real time like every sound |
| Which | `swing_number` | `int` | 0 | swing events: 0 = any, 1–N = that swing of the chain (1-based: "the 4th attack" is 4), −1 = the dash-strike |
| Which | `ability_id` | `StringName` | `&""` | cast and hit events: that ability (a REPLACE variant matches its own id; `korsavil_blade_singer` also matches its variants when `include_variants`) |
| Which | `include_variants` | `bool` | true | |
| Which | `part` | `int` | −1 | cast events: that recast part (0 = the first cast); −1 any |
| Which | `status_id` | `StringName` | `&""` | status events: that status (or use `status_tag`) |
| Which | `status_tag` | `StringName` | `&""` | |
| Which | `stacks` | `int` | 0 | `STACKS_REACHED`: the count, reached from below |
| Which | `end_reason` | `SoundTrigger.EndFilter` | `ANY` | `STATUS_ENDED`: `ANY`, or one `StatusEffect.EndReason` (EXPIRED, CONSUMED, CLEANSED, DIED, REMOVED) |
| Which | `hit_tags` | `Array[StringName]` | `[]` | hit events: every tag must be on the hit (`finisher`, `empowered`, `melee`, `proc`...) |
| Which | `used_empower` | `StringName` | `&""` | hit events: the hit used this empower (a swing's `HitContext.empowers_used`, new; a cast's `cast.empowers`) |
| Which | `crit_only`, `kill_only` | `bool` | false | hit events |
| Which | `conditions` | `Array[Condition]` | `[]` | all must pass: self = the sheet's unit, target = the event's other unit, cast = the event's cast |
| Where | `place` | `SoundTrigger.Place` | `DEFAULT` | the table below |
| How | `sound` | `SoundEvent` | null | null = the trigger does nothing (no error) |
| How | `volume_db` | `float` | 0.0 | added to the SoundEvent's |
| How | `pitch` | `float` | 1.0 | multiplies the SoundEvent's (as a swing's `sound_pitch` does) |
| How | `chance` | `float` | 1.0 | rolled on Audio's own seeded RNG (tests seed it) |
| How | `cooldown` | `float` | 0.0 | seconds, real time, per unit and trigger |
| How | `every_nth` | `int` | 1 | plays on every Nth match (3 = every third hit) |
| How | `once_per_frame` | `bool` | true | a swing or cast that hits five enemies in one frame plays it once |

**Events** (`SoundTrigger.Event`; the other unit is what `ON_OTHER` / `AT_OTHER` and a condition's target use):

| Event | Fires on | Other unit |
|---|---|---|
| `SWING_START` | `AutoAttackComponent.swing_started` (whiffs included) | the aimed enemy, if any |
| `SWING_LANDED` | `swing_landed` with at least one target | the first target |
| `SWING_WHIFF` | `swing_landed` with none | none |
| `HIT_DEALT` | `Events.unit_hit`, source = him (DoT ticks only with the hit tag `dot` in `hit_tags`) | the unit hit |
| `HIT_TAKEN` | `Events.unit_hit`, target = him | the source |
| `CAST_START` | `AbilityComponent.cast_started` | the cast's target |
| `CAST_EFFECT` | `Events.ability_cast` (the effect starts) | the cast's target |
| `STATUS_GAINED` | `Events.status_applied` on him (every application, stacks included) | the status's source |
| `STATUS_ENDED` | `Events.status_ended` on him | the status's source |
| `STACKS_REACHED` | his stacks of `status_id` go from under `stacks` to `stacks` or more | the status's source |
| `KILL` | `Events.unit_died`, killer = him | the unit killed |
| `DIED` | `Events.unit_died`, unit = him | the killer |
| `DASH` | `DashComponent.dash_started` | none |
| `DEFLECT` | `Events.hit_deflected`, defender = him | the attacker |

**Where** (`SoundTrigger.Place`):

| Place | Plays |
|---|---|
| `DEFAULT` | today's rule: centered for the Player, else on him (following) |
| `ON_SELF` | following him |
| `AT_SELF` | where he stood at the event; stays there |
| `ON_OTHER` | following the other unit (falls back to `AT_OTHER` if it's freed) |
| `AT_OTHER` | where the other unit stood at the event (for a hit: where the enemy was hit) |
| `AT_AIM` | the cast's aim point (`ctx.point`); cast events only, else `AT_SELF` |
| `CENTERED` | no position, the same in both ears |

**The Player's sounds and place** (Ryan, 2026-10-10: **an exception only for impact sounds**): Rules say anything played from the Player is centered (MUST). The one exception: a Player's `HIT_DEALT` trigger (the hit landing on an enemy) may use `ON_OTHER` or `AT_OTHER`, so its sound sits at the enemy hit. Every other event on the Player's sheet (swings, casts, statuses, stacks, kills, dashes, deflects) plays centered whatever its `place` says, `AT_AIM` included; SoundTriggers warns once per such trigger when the sheet is watched. An enemy's sheet uses every place on every event. In the 3D view the pan is gentle (Numbers: pan strength 0.5 ÷ 1.4), so an impact reads as "over there", not as a jump between ears.

### SoundTriggers (Node, `res://scripts/audio/sound_triggers.gd`; a child of Audio, beside CombatSounds)
The one place triggers play. It keeps the rule that a game rule never plays a sound (no "play sound" GameplayEffect): it listens, like CombatSounds.
- `watch(unit, sheet)`: the Player calls it when it loads its champion (`_apply_champion()`), an Enemy when it loads its data; `unwatch(unit)` when it leaves the tree. It connects that unit's component signals (swings, casts, dash) and keeps its per-trigger state (the cooldown clock, the Nth count, last stack counts for `STACKS_REACHED`, this frame's once-per-frame keys).
- Events (`unit_hit`, `unit_died`, `status_applied`, `status_ended`, `ability_cast`, `hit_deflected`) are read once and routed to the watched units they concern.
- A match: the filters, then the conditions, then chance, cooldown and Nth; then it plays now, at its progress point, or after its delay. Progress points are checked each physics tick against `get_swing_progress()` / `get_cast_progress()` while that swing or cast runs, and dropped when it ends (the A4 cue rule). Delays wait in real time and pause with the tree (the pause menu); a delayed sound whose unit has left the tree still plays at the place it was given (`AT_*`), or not at all (`ON_*`).
- Plays go through `Audio.play_at()` / `play_on()` / `play()` like any sound: instance limits, the voice cap, priority (HIGH when the Player is the sheet's unit or the other unit) and the log.
- The audio log's entries gain `trigger`: the trigger's `name` (empty for slot sounds), so a test reads "this trigger played".
- New on HitContext: `empowers_used: Array[StatusEffect]` (filled by `HitPipeline.add_empowers()`), for `used_empower` on a swing's hit.

### Korsavil's sheet (the first one, A6a)
`data/sound_sheets/sound_sheet_korsavil.tres`, three triggers for his K5b sounds, moved **in two steps** (Ryan, 2026-10-10: only after the sheet is verified to play them at the same moments as the old slots):
1. "Demise 4: empowered hit": `HIT_DEALT`, `used_empower` `empower_demise`, `once_per_frame`, place `DEFAULT` (an impact sound, so `AT_OTHER` may put it at the enemy hit), `sound_korsavil_demise_four`.
2. "Demise 6": `STACKS_REACHED`, `status_id` `demise`, `stacks` 6, `sound_korsavil_demise_six`.
3. "Sweep cast": `CAST_START`, `ability_id` `korsavil_blade_singer_sweep`, `at_progress` 0 (0.8 puts it near the lunge; centered either way: a cast), `sound_korsavil_sweep_cast`.

- **Step 1 (in A6a):** the sheet is built and verified, not yet his: a test gives a copy of his ChampionData the sheet and checks, from the audio log, that each trigger plays in the same physics frame as its old slot (the empowered hit's frame, the frame his stacks reach 6, the sweep's press) and at the same place (centered). His `korsavil.tres` doesn't point at it yet, so nothing plays twice.
- **Step 2 (its own step, after Ryan's play test of step 1):** `korsavil.tres` gets `sound_sheet`, and `empower_demise.consume_sound`, the sweep window's `apply_sound` and the sweep's `cast_sound` go back to empty. The SoundEvent files don't change.

### The tuning panel (A6b): in SandboxAudio, on Z
A5's panel (The audition tool) gets a **Triggers** view, built first; A5's lists join the same panel when A5 is built. Sandbox only, never room_01; a click on it also swings, as on N's panel.
- **The sheet:** the tracked champion's triggers, one row each: on/off, name, the event and its filters in words, the sound, and the live fields: `delay` and `at_progress` (number fields, 0.01 s and 0.01 steps), `place` (a dropdown), `volume_db`, `pitch`, `chance`, `cooldown`. A change applies at once to the loaded sheet: the next match uses it. **Fire** plays the row's sound now at its place (the other unit: the enemy nearest the cursor).
- **The timeline:** a strip of the last 3 s of real time, scrolling: markers for his swing starts and landings, hits dealt, cast starts and effects, status gains and ends, and each trigger that played (joined to the event that fired it, its delay drawn as a line). Hitstop shows as a shaded band. Hover a marker: its time in ms from the swing or cast it belongs to. **Freeze** stops the strip to read it.
- **Save** writes the sheet's .tres (`ResourceSaver.save()`), the only file the panel ever writes; **Revert** reloads it from disk. A change from A5's "never changes saved data", for this one file: Ryan's OK (2026-10-10) **with the guards of his concern 4** *(their text isn't in the docs yet: asked 2026-10-10, written in here when Ryan gives it)*. Close Godot's editor before saving from the panel, or Reload after (Known issues: an open editor writes its old copy back).
- It only calls Audio, SoundTriggers and the components' public methods.

### Edge cases (A6)
| Case | Handling *(proposed)* |
|---|---|
| A swing or cast cancelled before its `at_progress` | Not played (the A4 cue rule) |
| Hitstop between the event and a `delay` | The delay runs in real time (Rules: sounds play in real time); `at_progress` follows the motion, so it waits with it |
| The pause menu during a delay | The delay pauses with the tree |
| Two triggers match one event | Both play (each its own limits and log line) |
| A trigger and a slot on the same moment | Both play: move the sound to one or the other (the panel lists the slots' sounds too, A5) |
| The other unit freed before an `ON_OTHER` sound | Falls back to where it stood |
| A sheet edited in the panel while several units share it | All of them hear the change (one resource) |
| Chance in tests | Audio's RNG is seeded by the test, as Brains' is |

**Found while building A6a** (2026-10-10; Claude's readings, *(proposed)*):
- **Delays count the clock** (`Time.get_ticks_usec()`), not `_process`'s delta: dividing the delta by `Engine.time_scale` ran a 0.2 s delay out in 0.07 s during a hitstop. The pause doesn't count (the clock restarts on `NOTIFICATION_UNPAUSED`), and one long frame counts at most 0.25 s.
- **Progress points are checked once a physics tick**, so a point plays on the first tick at or past it: up to one tick (17 ms) after the exact point, as the motion's own clip is positioned. A swing that ends on its own (not cancelled) plays the points it hadn't reached yet at its end; a cast plays its points up to its effect (progress 1) and drops the rest when it's cancelled or interrupted.
- **A blocked hit is no hit** for triggers (i-frames, untargetable, a perched target: `HitContext.blocked`): no `HIT_DEALT`, no `HIT_TAKEN`.
- **`STACKS_REACHED`** reads the count after each application (one application adds one stack at most) and rereads it every physics tick, so stacks running out one by one (`STACK`) are seen; a status ending sets it to 0.
- **`STATUS_ENDED`'s other unit** is the source remembered when the status was applied (the status is gone when it ends).
- A unit is watched once it's ready (the Player's champion loads before `_ready()`): `watch()` waits for `ready` when it has to. An enemy is watched after its data's abilities, so its casts are heard.

## How each edge case is handled
| Edge case | Handling |
|---|---|
| A kill during hitstop | The hit resolves normally and `unit_died` fires at once, so the hit, crit and death sounds start that frame and play in real time through the freeze. The death tween runs in game time, so the sound lands up to 0.08 s before the body pops (Hades: sounds land during the hitstop). |
| 8 hits in one frame | One swing or cast: one hit sound and one crit layer (the once-per key; the crit roll is shared, so all crit or none); shield sounds capped by instance limits; 3+ kills play one pack burst and no death sounds. 8 sources at once: each source's sound once, then instance limits (3 in 0.05 s). On the player the first hit lands and the rest are blocked by post-hit i-frames: one hurt. |
| A cancelled cast with a telegraph | `_remove_telegraph()` frees the telegraph, so its wind-up stops (`play_on` owner left the tree). The cast sound is a short one-shot and plays out. An interrupt (stun) works the same way. |
| The caster dies mid-cast | The wind-up follows the telegraph exactly: `interrupt_cast()` frees the telegraph the same frame (a caster freed without dying frees it too), so the wind-up stops with it. |
| A status refreshed or stacked | `apply_sound` plays on each application (instance limits cap spam); the loop keeps running (one per status per unit, REFRESH's internal `_stop`/`_start` emits no `status_removed`). |
| A unit freed while its loop plays | `play_on` stops every sound owned by a node when it leaves the tree. Statuses are already cleared at death, so their loops stop then (without `expire_sound`). |
| The pause menu | SFX, Ambience and Voice players pause with the tree and resume where they were; Music ducks −6 dB (and low-passes) in real time; UI keeps playing. Nothing can start a gameplay sound while paused. |
| A scene restart (Backspace) | Autoloads survive the reload: main.gd calls `Audio.stop_all()` first, so no one-shot or loop from the old room carries over; Music and UI keep playing. Loops owned by old-room nodes would stop anyway when freed. |
| A hit blocked by i-frames | No event, no sound. |
| A swing that whiffs | `swing_sound` plays; no hit sound. |
| A null field | Silent, nothing logged. |
| A missing or empty file | Warns once per SoundEvent, logged dropped `no_audio`, silent. |
| A positional one-shot beyond `max_distance_px` | Not started, logged `out_of_range`; it takes no voice. |
| The voice cap is full | The lowest-priority, oldest SFX sound is stopped for a higher-priority one; otherwise the new one is dropped. Logged either way. |
| A variant whose sound is dropped (A4) | Its own limits apply; a dropped REPLACE winner doesn't fall back to the base, and ADD layers try on their own. Logged with `variant_of`. |
| A sound played with no context (A4) | Only variants with no conditions apply; every condition fails without a self unit. |
| A swing or cast cancelled before a cue (A4) | The cue never plays; one-shots already started play out; a looping cue stops with the swing or cast. |
| A cast with no cast time, or a free cast (A4) | Every cue plays at cast start, in progress order. |
| An empower used up vs timed out (A4) | `status_ended` says CONSUMED (`consume_sound`) or EXPIRED (`expire_sound`); the loop stops either way (`status_removed`). |
| A status ending at death (A4) | `status_ended` with DIED: no end sound, as today. |

## Godot behavior this relies on
Written from knowledge of Godot 4.0–4.5; checked where marked in Godot 4.7.2 headless (A1, A2). A difference goes into this section and DECISIONS.md.
- **AudioStreamRandomizer**: weighted streams; `playback_mode` `PLAYBACK_RANDOM_NO_REPEATS` (the default), `PLAYBACK_RANDOM`, `PLAYBACK_SEQUENTIAL`; `random_pitch` picks a pitch between 1/r and r; `random_volume_offset_db` ±dB. Checked. 4.7.2 also has `random_pitch_semitones` (default 0); SoundEvent doesn't use it.
- **`max_polyphony`** (checked: default 1, on AudioStreamPlayer, 2D and 3D): over the limit it cuts the oldest copy. Not used for our limits (no time window, cuts old instead of dropping new, per player instead of per event); pooled players keep 1.
- **AudioListener2D** (checked: `make_current()`, `clear_current()`, `is_current()`): with none current, 2D sounds are heard from the screen center, which is the camera's actual view (smoothing, lean and shake included). We add no listener node: that default is "the listener on the camera". A listener as a child of the Camera would sit at the camera node's position, which with position smoothing is its target, not what's on screen.
  - **In the 3D view (3D.md, P4) this changes:** the Camera2D no longer shows the screen, so "the screen center" would be wrong. An `AudioListener2D` (made current) follows the 3D camera's floor focus, in px, every tick, and `Audio.get_listener_position()` reads it when one is current. Panning stays right because the camera never rotates (screen left/right = sim x). Built in P4 (2026-10-02, see CHANGELOG.md): the listener is a child of `GameCamera3D`, and the distances scale with the view (Rules).
- **2D panning:** effective pan = `audio/general/2d_panning_strength` (checked: default 0.5; the Godot editor removes a setting equal to its default from `project.godot`, so it stays at the default there) × the player's `panning_strength` (checked: default 1.0). AudioStreamPlayer2D's `max_distance` defaults to 2000 px; Audio sets it per event.
- **A paused tree:** a player whose process mode stops when the tree pauses pauses its sound and resumes on unpause. Autoloads inherit Pausable from the root, so Audio sets each player's process mode by bus. Checked: while the tree is paused a pausable player reads `stream_paused` true and `can_process()` false, and unpausing sets `stream_paused` back to false (so it would also clear one set by hand; Audio never sets it). Players with process mode Always keep playing.
- **`Engine.time_scale`** doesn't change audio speed or pitch (the separate knob is `AudioServer.playback_speed_scale`). Anything timed in game time (timers, tweens, `delta`) does slow down, hence real-time limits and fades.
- **Start timing:** AudioStreamPlayer starts at the next audio mix; AudioStreamPlayer2D starts on its next physics tick (up to 16.7 ms later). Physics ticks keep coming at 60 Hz real time during hitstop (only their `delta` is scaled), so a hit sound during hitstop isn't delayed further. Not measurable headless (the dummy driver): a 2D player's `playing` reads true right after `play()`, but when it becomes audible needs the real driver. Still unverified.
- **End-of-frame batching:** a `call_deferred` made during a physics step runs when that step's message queue is flushed, still in the same frame (the pack burst relies on it). Checked in A2: the burst's log entry has the kills' physics frame.
- **Headless:** checked: the Dummy driver runs streams to their end (a 0.05 s one-shot ended and its voice was released), but reports 0 ms latency; tests check the log, never what was heard.
- **Output latency:** `audio/driver/output_latency` 15 ms by default; the driver may round it; `AudioServer.get_output_latency()` reports the real value. Measured on Ryan's machine (A1): 10 ms with WASAPI, under the 15 ms requested.
- **Signal connections ignore `bind()` arguments** (checked in A2): connecting the same method twice to one signal fails even with different bound values. Audio keeps one `tree_exiting` connection per `play_on()` node and a list of that node's handles.
- **Quitting while a sound plays** (checked in A2): any AudioStreamPlayer still playing at quit prints "ObjectDB instances were leaked" and "resources still in use" at exit (debug output only, harmless; a bare player without Audio does the same). A sound stopped a frame before quitting doesn't.

## File layout
```
game/
  default_bus_layout.tres          bus layout (Godot's default path)
  audio/
    LICENSES.md                    one row per third-party file
    sfx/                           short sounds, WAV (hit_light_01.wav ...; subfolders FREE)
    music/                         OGG
    ambience/                      OGG loops
  data/sounds/                     SoundEvents: sound_<category>_<name>.tres
  data/audio_mixes/                audio_mix_default.tres
  scripts/autoload/audio.gd        Audio
  scripts/audio/combat_sounds.gd   CombatSounds
  scripts/data/sound_event.gd, audio_mix.gd
  scenes/tests/audio_test.tscn + scripts/tests/audio_test.gd
```
- **Naming:** `sound_<category>_<name>` (`sound_hit_heavy`, `sound_knight_cleave_cast`, `sound_slime_death`, `sound_status_stun_apply`). Categories: `hit`, `death`, `shield`, `status`, `stinger`, `ui`, `music`, `ambience`, `loot` (LOOT.md: drops and pickups, from L7), or a champion or enemy name. Audio files take the SoundEvent's name without `sound_`, plus a variation number: `audio/sfx/hit_light_01.wav`.
- **Formats:** WAV (16-bit, 44.1 kHz) for short SFX, mono for anything positional; OGG Vorbis for music and ambience loops (imported with Loop on). Other import settings stay at their defaults.
- **Licenses:** every third-party file has a row in `audio/LICENSES.md` (file, source URL, author, license). Placeholders are CC0 only (e.g. Kenney). A file without a row isn't committed.

## Build order (one step per request)
Every step: with every sound field empty the game plays exactly as before, and the Knight's abilities, enemies chasing and the HUD still work. Build logs go in `docs/CHANGELOG.md` (an Audio section); this doc keeps one line per built step.

1. **A1 – Plumbing.** Built 2026-09-27, see CHANGELOG.md.
2. **A2 – Combat sounds with placeholders.** Built 2026-09-27, see CHANGELOG.md.
3. **A3 – Abilities and statuses** (the ability, telegraph, ready, status, heartbeat and stinger hooks; Data, Placeholder sounds). Built 2026-09-27, passed Ryan's play test 2026-09-30, see CHANGELOG.md.
   **Done means:** each Knight ability has its own cast sound; the elite's wind-up is heard from off screen, stops when the slam lands, and stops at once when the cast is interrupted; Judgement's stun plays its apply sound once; a status loop plays once per unit however many stacks; the heartbeat starts below 25% health and stops above it and at death; R pings when it comes off cooldown; "Room cleared!" and "You died" have stingers.
4. **A4 – Conditional audio** (approved 2026-10-04; not started): `SoundVariant`, `SoundEvent.variants`, `SoundContext` (the optional last argument of `play()` / `play_at()` / `play_on()`; every call site in the context table passes its own), resolution in Audio with layers tied to the main handle and `variant_of` / `mode` in the log; ~~`SoundCue`, `AttackSwing.sound_cues` (AutoAttackComponent) and `Ability.sound_cues` (AbilityComponent)~~ (folded into A6's `at_progress`, Ryan 2026-10-10); `StatusEffect.EndReason` (and the rest of the end reasons' slice, built early in CHAMPIONS K5b: only `expire_sound` moving to `status_ended` and the shield's data remain), `remove_status(id, reason)` with each removal path passing its reason, `StatusComponent.status_ended` and `Events.status_ended`, `StatusEffect.consume_sound`, CombatSounds' end sounds by reason; `status_shield.tres` gets `consume_sound` = its break. Placeholder data only for the tests (no champion's kit changes).
   **Done means:** with no variants, cues or `consume_sound` set, every sound plays exactly as before (audio test, combat test and every suite unchanged). The audio test covers: a REPLACE variant gated on SELF_HAS_STATUS with `min_stacks` 10 plays at 10 stacks and the base at 9; an ADD variant layers on top and stops with the main handle; the first passing REPLACE wins; a variant on a hit sound sees the hit's statuses; a sound with no context plays only condition-free variants; a variant's dropped sound doesn't fall back; ~~cues on a swing play at their progress, at double attack speed sooner, and a dash in the windup skips the rest; cues on a cast follow its progress and all play at once with no cast time;~~ (A6a's tests cover `at_progress` instead) a status ending by each reason plays the right end sound (EXPIRED expire, CONSUMED consume, CLEANSED expire, DIED nothing), an empower used by a cast plays `consume_sound` and one timing out `expire_sound`; the shield's break still plays when it's used up. Every check is seeded and reads the log. Ryan's play test: the sandbox sounds as before.
5. **A5 – The audition tool** (approved 2026-10-04; not started, after A4): `SandboxAudio` on Z (Conditional audio, The audition tool), in `sandbox.tscn` and `sandbox_3d.tscn`.
   **Done means:** Z opens the panel; every SoundEvent, ability and status is listed; a variant gated on a stack count resolves and plays as the stack control crosses its threshold; a status's four sounds play, and End as EXPIRED / CONSUMED / CLEANSED plays the matching end sound; the log lines show `variant_of`; Z closes it; nothing is saved. Ryan's play test: he hears every variant and end sound without a fight.
6. **A6a – Sound triggers** (designed and approved 2026-10-10; Sound triggers and the tuning panel; built with Claude's A6a / A6b cut, Ryan's slices not given). **Built 2026-10-10, see CHANGELOG.md (awaiting Ryan's play test).** `SoundTrigger` (its `Event`, `Place`, `EndFilter`), `SoundSheet`, `ChampionData.sound_sheet`, `EnemyData.sound_sheet`, `SoundTriggers` (Audio's child: `watch()`, `unwatch()`, the progress points, the delays), `HitContext.empowers_used`, the log's `trigger`; the Player's place rule (impact sounds only); Korsavil's sheet, step 1 (built and verified on a test copy, not yet his).
   **Done means:** with no sheet every sound plays exactly as before (every suite unchanged). The audio test covers each event once, each filter, each place, `at_progress` on a swing and a cast (and a cancel skipping it), a delay through a hitstop (real time) and through a pause (waits), chance (seeded), cooldown, every Nth, once per frame, conditions, a freed other unit; every check reads the log's `trigger`. A Player's swing or cast trigger with `AT_OTHER` plays centered (and warns), his `HIT_DEALT` with `AT_OTHER` plays at the enemy. Korsavil's sheet on a test copy: each trigger in the same physics frame and place as its old slot (the empowered hit, 6 stacks, the sweep's press; and at 0.8 of the wind-up when set). Ryan's play test: the game sounds as in K5b (his slots still play).
   **Then, its own step, after that play test:** `korsavil.tres` gets his sheet and the three old slots are emptied (Korsavil's sheet, step 2). **Done means:** his three sounds play once each, at the same moments as before, from the sheet; Ryan hears no change.
7. **A6b – The tuning panel** (after A6a): SandboxAudio on Z with the Triggers view (the sheet's live fields, Fire, the timeline, Freeze, Save, Revert).
   **Done means:** Z opens it on the tracked champion's sheet; changing a delay, a progress point or a place is heard on the next match without a restart; the timeline shows the swing, the hit and the sound with their times; Save writes only the sheet and Revert reloads it; nothing else is saved; Z closes it. Ryan's play test: he tunes Korsavil's three sounds by ear and saves them.
- **Later, per system** (each written into that system's build order, pointing here): CHAMPIONS / NPCS (voice lines; champion sounds onto ChampionData), ENEMIES_AI (enemy attack wind-ups for enemies without a telegraph, whiffs, aggro; the alert bark is built, AI2), WORLD_INTERACTION (impacts, hazard loops), DUNGEONS (music with explore and combat layers, room ambience, the room-clear transition), UI (hover, click, menu open and close, slider ticks: a sound set per element type, the hover stopped by its handle on mouse-exit or a press; Conditional audio, UI sounds), movement with sprites (footsteps on the F3 walk bob).

## Out of scope for now
The music system (adaptive layers), voice lines, footsteps, final audio assets. Placeholders only.

## Open questions
- Music style and who makes the audio (placeholders: CC0 packs only, e.g. Kenney).
- Adaptive music: explore vs combat layers (DUNGEONS.md).
- Should hitstop also briefly duck or low-pass the mix? (FREE to try.)
- Heartbeat as an option the player can turn off?
- Voice lines: how often, and which events (CHAMPIONS.md).
- **Voice-over for story scenes** (VISION.md, Pillar 5; 2026-10-02): how much is voiced is NARRATIVE.md's. Here: dialogue on the Voice bus; whether dialogue ducks Music, SFX and Ambience while it plays, and by how much; what happens when a line and combat overlap (and whether a line pauses with the tree like the rest of Voice).
- **Per-dungeon music** (2026-10-02): does each dungeon get its own music (its story's theme), on top of the explore and combat layers? (DUNGEONS.md, NARRATIVE.md.)
- ~~The champion sounds (hurt, death, low health) move onto ChampionData in CHAMPIONS CH1.~~ Done: CH1 (built 2026-09-29) holds `hurt_sound`, `death_sound` and `low_health_sound` on ChampionData and copies them onto Unit and Player at load (CHAMPIONS.md). `DashComponent.dash_sound` stays on the scene until a second champion needs its own.
- A sound for a hit the dash dodged? Blocked hits emit no event today.
- ~~Conditional audio (A4–A5): the default mode, nesting, cues per swing, the names, a consume fallback, the audition key.~~ Answered by Ryan 2026-10-04 (two rounds, each as proposed): REPLACE by default; no nesting (one level); no cap on cues, a warning past 4; every name approved; no fallback to `expire_sound` (the shield's break moves to `consume_sound` in A4); the big impact on the empower's `consume_sound`; the audition tool on Z; per-swing hit tags noted in COMBAT.md as proposed, not in A4.
- A condition kind reading what a cast used up (e.g. CAST_USED_EMPOWER with a status tag, reading `cast.empowers`), so a variant on an ability's own sound can follow an empower: not needed for the ring-out (it uses `consume_sound`); add it when a sound needs it (ABILITIES.md, Conditions).
- A missed slam is silent after its wind-up: `Ability.hit_sound` plays only when the cast lands on someone. An impact sound on every `execute()` (the slam hitting the ground) would need a new hook (ABILITIES.md).
- ~~**Sound triggers (A6), Claude's proposals for Ryan's OK (2026-10-10):**~~ **Answered by Ryan the same day:** 1 names OK; 2 cues folded in, OK; 3 OK only for impact sounds (a `HIT_DEALT` on an enemy), swings and casts stay centered (the MUST rule); 4 OK in two steps, after the sheet is verified to play them at the same moments; 5 OK with the guards of his concern 4; 6 OK, "using the slices above". **Still to come from Ryan:** concern 4's text (the Save guards) and the slices he refers to (how A6a and A6b are cut); neither is in the docs yet. His proposals as written then:
  1. The design and its names (`SoundTrigger`, `SoundSheet`, `SoundTriggers`, `sound_sheet`, the events and places, `HitContext.empowers_used`, `data/sound_sheets/`).
  2. **A4's cues fold into triggers** (`at_progress` on `SWING_START` / `CAST_START` does what `SoundCue` would): A4 keeps its variants and the end reasons, and drops `SoundCue`, `AttackSwing.sound_cues` and `Ability.sound_cues`. One way to time a sound to a motion, not two.
  3. **The Player's sounds may be placed** (`ON_OTHER`, `AT_OTHER`, `AT_AIM`...) per trigger, as an exception to the MUST rule that the Player's sounds are centered; `DEFAULT` keeps the rule.
  4. **Korsavil's three K5b sounds move onto his sheet** in A6a, their slots emptied.
  5. **The panel's Save** writes the sheet's .tres: the one exception to A5's "never changes saved data".
  6. Order: A6a and A6b before A4 and A5 (Ryan asked for this control now); A5's lists join A6b's panel later.
