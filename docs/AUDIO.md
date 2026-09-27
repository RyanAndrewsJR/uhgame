# AUDIO.md: Sound Effects, Music and the Mix

**Read when:** the task involves any sound, music, the mix, or volume settings.
**Depends on:** CLAUDE.md, CONVENTIONS.md (reserved names), COMBAT.md (Events, HitContext, HitFeel, StatusEffect, Telegraph), MOVEMENT.md (Dash; the F3 walk bob for footsteps), DECISIONS.md (General: Settings and the pause menu).
**Used by:** COMBAT, ABILITIES, CHAMPIONS, LOOT, ENEMIES_AI, DUNGEONS, UI. Other docs only list their hooks and point here.

## How to read this doc
Same as COMBAT.md: MUST (never change without asking Ryan), TARGET (start value and allowed range), FREE (your call; tiebreaker: VISION.md's decision priorities).

## Player experience
Every hit has a crunch you feel as much as see; the finisher and kills land heavier, and crits ring out. You hear an elite winding up before you see it, and a heartbeat tells you you're low without looking at the health bar. Packs die in one satisfying burst, not a wall of overlapping noise. The mix stays readable in chaos: what matters to you (your hits, your danger) is always on top.

## References
- Hades. Take: crunchy, punchy hit sounds that land during the hitstop; wind-up cues on enemy attacks; a heavier finisher; music that lifts in combat and settles after a room clears.
- League of Legends. Take: every ability has its own cast sound (kit identity); a distinct crit sound; an "ultimate ready" cue. Don't take: constant voice lines.
- Diablo. Take: item drops that sound different by rarity; pack deaths that burst; positional sound that tells you where enemies are. Don't take: sound spam from dozens of identical hits.

## Principles
1. Audio never changes gameplay state (like VFX). Nothing waits on a sound.
2. Never audio-only: anything the player must know also has a visual. Audio makes it faster to read, not possible to read.
3. `play()` is called in the same frame as its event. No queuing, no delays of our own (Godot adds its output latency; see Godot behavior).
4. The player's own actions and threats to the player win the mix; enemy-on-enemy noise loses.
5. Variety beats repetition: every common sound has variations and slight pitch/volume jitter.
6. One way to play sounds: everything goes through the Audio autoload.

## Rules (MUST)
- Every sound is a SoundEvent resource (`data/sounds/sound_<name>.tres`). A null SoundEvent field = silent, never an error. A SoundEvent with no usable audio (a missing or empty file) warns once per SoundEvent and stays silent. (Godot's loader also prints its own error when a .tres points at a missing file; we can't suppress that one.)
- Owner components play the sounds on their own data (a swing's sound, a dash, an ability cast) through the Audio autoload, the same way they call GameFeel and VFX today. Cross-system sounds (hits, deaths, statuses) come from an audio listener on Events (`unit_hit`, `unit_damaged`, `unit_died`, `status_applied`, `status_removed`): `CombatSounds`. Combat code never plays a hit or death sound itself; a swing's or ability's own hit sound reaches the listener through `HitContext.hit_sound`.
- There is no "play sound" GameplayEffect (COMBAT C11 must not add one). A ReactionRule makes a sound only through what it creates: the status it applies plays that status's sound; a proc hit plays a hit sound.
- Sounds play in real time: `Engine.time_scale` (hitstop) never slows or pitches them, and instance limits are timed in real time (like GameFeel's hitstop).
- The pause menu pauses every sound on the SFX, Ambience and Voice buses (their players pause with the scene tree; Godot buses themselves can't pause) and ducks Music; UI sounds keep playing.
- Instance limits: no SoundEvent starts more than `max_instances` copies within any `min_interval` window (a sliding window, real time); extra starts are dropped. A global SFX voice cap drops the lowest-priority sound first.
- Player-relevant sounds (the player's hits, the player being hit, telegraphs, low health) get high priority; enemy hits on other units get low priority.
- The player's own sounds are non-positional (centered). Enemy and world sounds are positional, with the listener on the camera.
- Telegraph wind-up sounds are owned by the Telegraph: when a cast is cancelled or interrupted and the telegraph is freed, its sound stops.
- Status loops (e.g. a burn crackle) start on apply and stop on remove, one loop per status per unit (not per stack).
- DoT ticks are silent by default; the apply sound and the loop carry them.
- Pack burst (proposed): when 3 or more enemies die within 0.1 s, the death that makes 3 plays one "pack burst" sound instead of its own, and later deaths in that window are silent. Deaths in the same frame are counted together at the end of that frame (still the same frame), so a swing that kills a pack plays only the burst; the first two of a spread-out trio keep their own sounds.
- `hurt_sound` stays null on normal enemies (their hit sound is enough). It's for the player and, later, elites and bosses.
- Volume is the player's choice: Master, Music, SFX, UI, Ambience, Voice sliders live in the Settings autoload (saved to `user://settings.cfg`) and the Esc pause menu.
- Tests can check audio without hearing it: the Audio autoload keeps a log of what played, what was dropped and why.

## Hooks (optional SoundEvent fields; null = silent)
- AttackSwing: `swing_sound` (at swing start, plays even on a whiff), `hit_sound` (on landing, through `HitContext.hit_sound`). The Knight's swings pitch up slightly across the combo (`sound_pitch`); the finisher has its own heavier hit.
- HitFeel: light, heavy and kill hit sounds (the default for hits without their own; feel NONE uses the light one), plus a crit layer on top of any crit, and the shield absorb sound.
- Ability: `cast_sound` (cast start), `hit_sound` (per cast that lands, not per target), `telegraph_sound` (a wind-up owned by the Telegraph), `ready_sound` (when its cooldown ends; the Knight's R), `charge_sound` (a loop on the caster while a CHARGE_UP ability charges; stops on release, cancel or interrupt; ABILITIES.md AB6).
- StatusEffect: `apply_sound`, `expire_sound`, `loop_sound`.
- Shield absorb (`HitFeel.shield_absorb_sound`, the moment C10's shield number shows).
- Dash start (`DashComponent.dash_sound`). Player hurt (`Unit.hurt_sound`). Enemy death, per enemy type (`Unit.death_sound`, set in each enemy scene). Low-health heartbeat (`Player.low_health_sound`).
- Ultimate (R) ready ping (`Ability.ready_sound` + `AbilityComponent.cooldown_finished`). Room cleared and "You died" stingers (main.gd).
- Later, per system: item drop by rarity and pickup (LOOT), voice lines (CHAMPIONS/NPCS), music and room ambience (DUNGEONS), UI hover/click (UI), footsteps tied to the F3 walk bob (with sprites), enemy attack wind-ups for enemies without a telegraph (ENEMIES_AI), impacts and hazard loops (WORLD_INTERACTION).

## Numbers (TARGET: start, range)
- Pitch jitter ±5% (0–10%); volume jitter ±1 dB (0–3).
- Per-sound `max_instances` 3 within `min_interval` 0.05 s (1–6; 0.03–0.1 s). Global SFX voice cap 32 (16–64).
- Combo pitch: swing 1 ×1.00, swing 2 ×1.04; the finisher uses its own sound.
- Positional: `max_distance_px` 480 (320–640; the screen is 640 wide); pan strength 0.5 (0–1), subtle, so sounds don't jump between ears. Pan strength is the project setting `audio/general/2d_panning_strength`; every player keeps its own `panning_strength` at 1.0.
- Telegraph sounds carry farther: `max_distance_px` 640 (480–800), so an off-screen elite is heard.
- Low-health heartbeat below 25% max health (15–35%).
- Pack burst: 3 deaths within 0.1 s (proposed; FREE to retune).
- Pause: Music −6 dB (0 to −12), low-pass FREE.
- Bus starting levels: Master 0, Music −8, SFX 0, UI −4, Ambience −12, Voice −2 dB (all FREE to retune).
- Latency: keep the project's audio output latency at the default or lower, and say what it is. The default `audio/driver/output_latency` is 15 ms and the project doesn't override it; the real value depends on the OS driver, so A1's test prints `AudioServer.get_output_latency()`.

## Current code
What exists today that audio hooks into. **There's no audio code yet** (checked 2026-09-27): no AudioStreamPlayer anywhere, no bus layout, no audio files, no `[audio]` section in `project.godot` (every audio setting is at its default).

| Code | What audio uses |
|---|---|
| `Events` (`scripts/autoload/events.gd`) | `unit_hit(ctx)`: every hit that got through, even for 0 damage. `unit_damaged(ctx)`: `taken_damage` > 0. `unit_died(unit, ctx)`: a death from a hit. `status_applied(unit, status)`: every application, refresh and new stack. `status_removed(unit, status)`: ran out, removed, used up, or the death `clear()`. A blocked hit (i-frames) emits nothing. |
| `Unit.on_hit(ctx)` | In order: mitigation, shields (`ctx.absorbed`), health (`health_lost`, `killed`), number, flash, knockback, statuses, `GameFeel.play_hit_feel`, then `Events.unit_hit` / `unit_damaged` / `unit_died`, on-hit procs, post-hit i-frames. `ctx.source`, `target`, `feel`, `is_crit`, `tags` (`dot`, `proc`) are all set by the time the events fire. |
| `HitPipeline.basic_attack()` / `from_ability()` | Build every swing and ability hit; where `HitContext.hit_sound` gets copied from the swing or ability. |
| `GameFeel`, `HitFeel` (`data/hit_feels/hit_feel_default.tres`) | Hit tiers LIGHT / HEAVY / kill; feel NONE for abilities and League-style enemy attacks. Hitstop sets `Engine.time_scale` 0.05 and is timed with `Time.get_ticks_msec()`. |
| `AutoAttackComponent` | `try_swing()` starts a swing and emits `swing_started(index, direction, swing)` (whiffs included). `_land_swing()` resolves every target in one loop, then `swing_landed(index, targets)`. League mode (enemies): `windup_started`, `attack_landed`, `attack_whiffed`; no hooks yet. |
| `DashComponent.try_dash()` | Emits `dash_started(direction)`. Player only. |
| `AbilityComponent._do_cast()` | `cast_started(slot, ability, ctx)`, then `ability.on_cast_started()` (may set `ctx.telegraph`), the cast time (a game-time timer), `execute()`. A cancel or interrupt frees the telegraph (`_remove_telegraph()`). Cooldowns tick in `_physics_process`; nothing is emitted when one ends (the HUD polls). |
| `StatusComponent` | `apply_status()`: a new status runs `_start()`; REFRESH runs `_stop()` + `_start()` on the same entry without `status_removed`; STACK and REFRESH_LONGER update in place. `remove_status()` emits `status_removed`. `clear()` on death runs after the unit is marked dead. A status's `vfx` is instanced as a child of the unit. |
| `Telegraph` (`scripts/vfx/telegraph.gd`) | A child of the room (under the units), not of the caster. `finish()` flashes 0.12 s and frees it. A caster that dies or is freed mid-cast frees it at once (`AbilityComponent.interrupt_cast()`, COMBAT.md). |
| `Unit._on_died()` | Marks the unit dead, cancels its attack, clears its statuses, emits `died`, then a death tween in game time (0.08 s wait + 0.25 s) and `queue_free()`. |
| `Player` | `on_hit` override (2 px shake). `health.health_changed(current, max)` (main.gd feeds the HUD from it). |
| `main.gd` | "Room cleared!" in `_on_enemy_died()` when none are left; "You died" in `_on_player_died()`; Backspace → `get_tree().reload_current_scene()` (autoloads survive a reload). |
| `Settings` | Only the dash direction so far; `ConfigFile` at `user://settings.cfg`; `setting_changed(key, value)`. |
| `PauseMenu` (`scenes/ui/pause_menu.tscn`) | A CanvasLayer with process mode Always; `open()` sets `get_tree().paused`. One option button (dash direction) and Resume. |
| `GameCamera` | Camera2D with position smoothing (10), an aim lean up to 80 px, shake through `offset`. The screen center is what the player sees. |
| `project.godot` | Autoloads GameFeel, Events, WorldQuery, Settings. No audio settings. |

## Data (Resources)
Names checked against CONVENTIONS.md: `Audio`, `SoundEvent`, `AudioMix` and `CombatSounds` are reserved there. Every SoundEvent field on another class ends in `_sound`.

### SoundEvent (Resource, `res://scripts/data/sound_event.gd`; files `res://data/sounds/sound_<category>_<name>.tres`)
| Field | Type | Default | Notes |
|---|---|---|---|
| `variations` | `Array[AudioStream]` | `[]` | One or more files. Wrapped once (cached) in an `AudioStreamRandomizer` with `PLAYBACK_RANDOM_NO_REPEATS`: never the same file twice in a row when there are 2+. Empty, or every entry null = no usable audio (warn once, silent). |
| `volume_db` | `float` | 0.0 | |
| `pitch_scale` | `float` | 1.0 | Base pitch; multiplied by the caller's pitch (combo pitch). |
| `pitch_jitter` | `float` | 0.05 | 0–0.1. The randomizer's `random_pitch` = 1 + this (a pitch between 1 / 1.05 and 1.05: −4.8% to +5%). |
| `volume_jitter_db` | `float` | 1.0 | 0–3. The randomizer's `random_volume_offset_db` (±). |
| `bus` | `SoundEvent.Bus` | `SFX` | `SFX`, `UI`, `MUSIC`, `AMBIENCE`, `VOICE` (maps to the bus names; an enum so a typo can't pick a missing bus). |
| `positional` | `bool` | true | false = always centered (UI, stingers, music). true = positional, except the player's own sounds (Rules). |
| `max_distance_px` | `float` | 480 | Positional only. Telegraph sounds 640. Falloff is linear (`attenuation` 1.0) to silence at this distance. |
| `priority` | `SoundEvent.Priority` | `NORMAL` | `LOW`, `NORMAL`, `HIGH`. CombatSounds overrides it for hits and statuses (Architecture). |
| `max_instances` | `int` | 3 | 1–6. |
| `min_interval` | `float` | 0.05 | Seconds, real time (0.03–0.1). The sliding window for `max_instances`. |
| `loop` | `bool` | false | Plays until stopped (a kept handle or `play_on`). The file must also be imported with looping on (WAV: Loop Mode Forward; OGG: Loop); this flag doesn't make a file loop. |

Methods: `get_stream() -> AudioStream` (the cached randomizer; null without usable audio; rebuilt only when the variations or the jitter change), `has_audio() -> bool`, `get_bus_name() -> StringName`, `get_display_name() -> String` (the file name, or `resource_name` for an unsaved event; logs and the debug list).

### AudioMix (Resource, `res://scripts/data/audio_mix.gd`; `res://data/audio_mixes/audio_mix_default.tres`, held by `Audio.mix`)
The mix-wide numbers, like HitFeel for GameFeel:
- `voice_cap` 32 (16–64)
- `pause_music_duck_db` −6 (0 to −12); `pause_low_pass` (true, FREE) and `pause_low_pass_hz` (FREE); `duck_fade_time` 0.15 s, real time (FREE)
- `pack_burst_sound` (`sound_death_pack_burst`; null = each death plays its own sound), `pack_burst_count` 3 (2–6), `pack_burst_window` 0.1 s (0.05–0.3)
- `log_size` 256, `debug_lines` 10, `debug_line_time` 3 s (FREE)

### Hook fields on existing classes (additive; all null by default)
| Class | Field(s) | Step |
|---|---|---|
| `AttackSwing` | `swing_sound`, `hit_sound`, `sound_pitch` (1.0; multiplies both) | A2 |
| `HitContext` | `hit_sound` (copied by `HitPipeline.basic_attack()` in A2, `from_ability()` in A3), `hit_sound_pitch` (the swing's `sound_pitch`; applies to whichever hit sound plays, its own or the tier's) | A2 |
| `HitFeel` | `light_sound`, `heavy_sound`, `kill_sound`, `crit_sound`, `shield_absorb_sound` | A2 |
| `DashComponent` | `dash_sound` | A2 |
| `Unit` (export group "Sounds") | `hurt_sound` (player; later elites and bosses), `death_sound` (per enemy scene) | A2 |
| `Ability` | `cast_sound`, `hit_sound`, `telegraph_sound`, `ready_sound` | A3 |
| `Ability` | `charge_sound` (a loop; the SoundEvent's `loop` on) | ABILITIES AB6 |
| `StatusEffect` | `apply_sound`, `expire_sound`, `loop_sound` | A3 |
| `Player` | `low_health_sound`, `low_health_fraction` (0.25) | A3 |
| `main.gd` | `room_cleared_sound`, `player_died_sound` | A3 |
| `AbilityComponent` | signal `cooldown_finished(slot, ability)` | A3 |
| `Telegraph` | `play_sound(event)` | A3 |

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

## Architecture / contracts
### Audio (autoload, `res://scripts/autoload/audio.gd`)
Registered after Settings (it reads it in `_ready()`). Process mode Always, so its bookkeeping, fades and debug draw run while paused.

- Exports: `mix: AudioMix = preload("res://data/audio_mixes/audio_mix_default.tres")`; `debug_draw := false` (toggle it in the Remote scene tree while the game runs; the audio test turns it on).
- **Methods** (a handle is an `int` > 0; 0 = nothing played):
  - `play(event: SoundEvent, pitch := 1.0, priority := -1) -> int`: a non-positional one-shot (or loop).
  - `play_at(event: SoundEvent, position: Vector2, source: Unit = null, pitch := 1.0, priority := -1) -> int`: at a world point. Centered when `source` is the Player or the event isn't positional.
  - `play_on(event: SoundEvent, node: Node2D, pitch := 1.0, priority := -1) -> int`: follows the node every physics frame and stops when the node leaves the tree (`tree_exiting`). Centered when the node is the Player or the event isn't positional. Every loop on a unit or telegraph uses it.
  - `stop(handle)`: stopping 0 or an ended handle does nothing. `stop_all_on(node)`. `stop_all()`: every SFX, Ambience and Voice sound; clears the instance-limit history and the pack burst window; Music and UI keep playing. `is_playing(handle) -> bool`.
  - `get_log() -> Array[Dictionary]`, `clear_log()`.
  - `get_player(handle) -> Node` (for tests and debugging), `get_bus_base_db(bus) -> float` (the layout level), `get_listener_position() -> Vector2` (the screen center in world space).
  - `priority` −1 = the event's own.
  - `play_on()` a node that isn't in the tree plays nothing (logged dropped `no_owner`).
- **A play call, in order:**
  1. Null event: return 0, nothing logged.
  2. No usable audio: `push_warning()` once per SoundEvent, logged dropped `no_audio` every time.
  3. Instance limit: `max_instances` starts of this event already within the last `min_interval` (real time): dropped `instance_limit`.
  4. A positional one-shot farther than its `max_distance_px` from the listener (the screen center): dropped `out_of_range`. Loops always start (they may come into range).
  5. Voice cap (SFX bus only): with `mix.voice_cap` SFX sounds playing, a new sound that outranks the lowest-priority one stops it (the oldest among equals; logged `stolen`); otherwise the new one is dropped `voice_cap`. A stolen loop stays stopped (FREE whether it resumes later).
  6. Start: a pooled player (AudioStreamPlayer when centered, AudioStreamPlayer2D when positional; `max_polyphony` 1, `panning_strength` 1.0, `attenuation` 1.0, `max_distance` from the event), with the event's bus and `volume_db`, `pitch_scale` = event pitch × `pitch`. Logged `played`.
- **Real time:** limits and the pack burst window use `Time.get_ticks_msec()`; fades use real delta (`delta / Engine.time_scale`, like GameCamera). Nothing touches `AudioServer.playback_speed_scale`.
- **Pause:** players on SFX, Ambience and Voice are `PROCESS_MODE_PAUSABLE` (they pause with the tree and resume after); Music and UI players are `PROCESS_MODE_ALWAYS`. Audio watches `get_tree().paused` every frame: while paused, Music fades to `pause_music_duck_db` and its low-pass turns on; unpausing fades back. Any tree pause does this, not only the menu.
- **Volumes:** on `_ready()` and on `Settings.setting_changed`, each bus's dB = its layout level + `linear_to_db(Settings.get_volume(bus))`; a slider at 0 mutes the bus.
- **Log:** one entry per play, drop, stop and steal (a sound that ends on its own isn't an entry): `time_ms`, `frame`, `event` (resource path, or the name of an unsaved event), `sound` (the SoundEvent), `handle`, `result` (`played`, `dropped`, `stopped`, `stolen`), `reason`, `bus`, `priority`, `positional`, `position`. Keeps the last `mix.log_size`.
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
- **`status_applied(unit, status)`:** `apply_sound` at the unit on every application (refresh and stack included; limits cap spam). `loop_sound`: if no loop is running for (unit, `status.id`), `Audio.play_on(loop_sound, unit)`, kept in a dictionary.
- **`status_removed(unit, status)`:** stops that loop; `expire_sound` only if the unit is alive (the death `clear()` is silent). A used-up shield ends through here, so the shield status's `expire_sound` is the shield break.
- Status sounds on the Player are HIGH; on anyone else the event's own priority.

### Owner calls (each owner plays its own data)
- **AutoAttackComponent** `try_swing()`: `Audio.play_on(swing.swing_sound, unit, swing.sound_pitch)` at swing start, whiffs included.
- **DashComponent** `try_dash()`: `Audio.play_on(dash_sound, unit)`.
- **AbilityComponent** `_do_cast()`: `Audio.play_on(ability.cast_sound, unit)` at `cast_started`; after `on_cast_started()`, if `ctx.telegraph` is valid, `ctx.telegraph.play_sound(ability.telegraph_sound)`. When a slot's cooldown counts down to 0 in `_physics_process`: `cooldown_finished(slot, ability)` and `Audio.play(ability.ready_sound)`. A refunded cooldown (cancel, interrupt) doesn't ping.
- **Telegraph** `play_sound(event)`: `Audio.play_on(event, self)`. `finish()` stops it (the hit sound takes over); freeing stops it.
- **Player**: on `health.health_changed`, below `low_health_fraction` × max and alive → start the heartbeat (`Audio.play_on(low_health_sound, self)`) if it isn't running; at or above it, or dead → stop it.
- **main.gd**: `Audio.play(room_cleared_sound)` where "Room cleared!" shows, `Audio.play(player_died_sound)` where "You died" shows, and `Audio.stop_all()` right before `reload_current_scene()`.
- **Settings**: `get_volume(bus: StringName) -> float` (0–1), `set_volume(bus, value)`; keys `&"volume_master"`, `&"volume_music"`... emitted through `setting_changed`; saved as whole percents (0–100) in an `[audio]` section (the "words" rule is for enums).
- **PauseMenu**: six sliders (0–100, step 5) with their percent, one per bus, above Resume.

"The player's own sounds" = anything played on or from the Player node: its swings, dash, hurt, heartbeat, statuses on it, and the hit sounds of its hits. Enemy sounds, telegraphs and world sounds are positional.

## Where each hook fires
| Hook | Fires in | Played by | Bus / position | Step |
|---|---|---|---|---|
| `AttackSwing.swing_sound` | `AutoAttackComponent.try_swing()` | AutoAttackComponent | SFX, centered for the player | A2 |
| `AttackSwing.hit_sound` | `HitPipeline.basic_attack()` → `Events.unit_hit` | CombatSounds | SFX, target (centered for the player's hits) | A2 |
| HitFeel light / heavy / kill | `Events.unit_hit` (no own sound, target not the player) | CombatSounds | SFX, target | A2 |
| `HitFeel.crit_sound` | `Events.unit_hit` with `is_crit` | CombatSounds | SFX, target | A2 |
| `HitFeel.shield_absorb_sound` | `Events.unit_hit` with `absorbed` > 0 | CombatSounds | SFX, target | A2 |
| `DashComponent.dash_sound` | `DashComponent.try_dash()` | DashComponent | SFX, centered | A2 |
| `Unit.hurt_sound` | `Events.unit_damaged` with `health_lost` > 0 | CombatSounds | SFX, centered for the player | A2 |
| `Unit.death_sound`, pack burst | `Events.unit_died`, flushed at the end of the frame | CombatSounds | SFX, the unit | A2 |
| `Ability.cast_sound` | `AbilityComponent._do_cast()` at `cast_started` | AbilityComponent | SFX, caster | A3 |
| `Ability.hit_sound` | `HitPipeline.from_ability()` → `Events.unit_hit` | CombatSounds | SFX, target | A3 |
| `Ability.telegraph_sound` | after `Ability.on_cast_started()` sets `ctx.telegraph` | Telegraph | SFX, telegraph, 640 px | A3 |
| `Ability.ready_sound` | `AbilityComponent.cooldown_finished` | AbilityComponent | the event's bus, centered | A3 |
| `Ability.charge_sound` | `AbilityComponent` from `charge_started` until release, cancel or interrupt (`play_on` the caster, stopped by handle) | AbilityComponent | SFX, caster (centered for the player), loop | ABILITIES AB6 |
| `StatusEffect.apply_sound` / `loop_sound` | `Events.status_applied` | CombatSounds | SFX, the unit (loop follows it) | A3 |
| `StatusEffect.expire_sound` | `Events.status_removed` (unit alive) | CombatSounds | SFX, the unit | A3 |
| `Player.low_health_sound` | `HealthComponent.health_changed` | Player | SFX, centered, loop | A3 |
| Room cleared / "You died" stingers | `main.gd` `_on_enemy_died()` / `_on_player_died()` | main.gd | SFX, centered (FREE) | A3 |

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

## Godot behavior this relies on
Written from knowledge of Godot 4.0–4.5; A1 checked what it could in Godot 4.7.2 headless (marked "checked"). A difference goes into this section and DECISIONS.md.
- **AudioStreamRandomizer**: weighted streams; `playback_mode` `PLAYBACK_RANDOM_NO_REPEATS` (the default), `PLAYBACK_RANDOM`, `PLAYBACK_SEQUENTIAL`; `random_pitch` picks a pitch between 1/r and r; `random_volume_offset_db` ±dB. Checked in 4.7.2 (A1). 4.7.2 also has `random_pitch_semitones` (default 0); SoundEvent doesn't use it.
- **`max_polyphony`** (checked: default 1, on AudioStreamPlayer, 2D and 3D): over the limit it cuts the oldest copy. Not used for our limits (no time window, cuts old instead of dropping new, per player instead of per event); pooled players keep 1.
- **AudioListener2D** (checked: `make_current()`, `clear_current()`, `is_current()`): with none current, 2D sounds are heard from the screen center, which is the camera's actual view (smoothing, lean and shake included). We add no listener node: that default is "the listener on the camera". A listener as a child of the Camera would sit at the camera node's position, which with position smoothing is its target, not what's on screen.
- **2D panning:** effective pan = `audio/general/2d_panning_strength` (checked: default 0.5; A1 wrote it into `project.godot`, and the Godot editor removes a setting equal to its default, so it stays at the default there) × the player's `panning_strength` (checked: default 1.0). AudioStreamPlayer2D's `max_distance` defaults to 2000 px; Audio sets it per event.
- **A paused tree:** a player whose process mode stops when the tree pauses pauses its sound and resumes on unpause. Autoloads inherit Pausable from the root, so Audio sets each player's process mode by bus. Checked in 4.7.2: while the tree is paused a pausable player reads `stream_paused` true and `can_process()` false, and unpausing sets `stream_paused` back to false (so it would also clear one set by hand; Audio never sets it). Players with process mode Always keep playing.
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
- **Naming:** `sound_<category>_<name>` (`sound_hit_heavy`, `sound_knight_cleave_cast`, `sound_slime_death`, `sound_status_stun_apply`). Categories: `hit`, `death`, `shield`, `status`, `stinger`, `ui`, `music`, `ambience`, or a champion or enemy name. Audio files take the SoundEvent's name without `sound_`, plus a variation number: `audio/sfx/hit_light_01.wav`.
- **Formats:** WAV (16-bit, 44.1 kHz) for short SFX, mono for anything positional; OGG Vorbis for music and ambience loops (imported with Loop on). Other import settings stay at their defaults.
- **Licenses:** every third-party file has a row in `audio/LICENSES.md` (file, source URL, author, license). Placeholders are CC0 only (e.g. Kenney). A file without a row isn't committed.

## Build order (one step per request)
Every step: with every sound field empty the game plays exactly as before, and the Knight's abilities, enemies chasing and the HUD still work. Build logs go in `docs/CHANGELOG.md` (an Audio section); this doc keeps one line per built step.

1. **A1 – Plumbing.** `default_bus_layout.tres` (six buses, starting levels, Music low-pass off), `project.godot` (Audio autoload after Settings; `2d_panning_strength` stays at its default 0.5), `SoundEvent`, `AudioMix` + `audio_mix_default.tres`, the Audio autoload (pool, limits, priority, voice cap, real time, pause behavior, `stop_all()`, the log, `debug_draw`), `Settings` volumes, six sliders in the pause menu, `Audio.stop_all()` before the restart in `main.gd`, the `audio/` folders with `LICENSES.md`, `audio_test.tscn`. CLAUDE.md gets Audio under Autoloads and the new folders under Project layout.
   **Done means:** the audio test passes with tones generated in code (no files): a null event is silent and unlogged; an empty one warns once; 4 plays in one frame = 3 played + 1 `instance_limit`, and it plays again after 0.05 s real time, also with `Engine.time_scale` 0.05; a full voice cap drops a LOW sound and a HIGH one steals the lowest; a sound from the Player is centered and an enemy's positional; beyond `max_distance_px` = `out_of_range`; `stop()`, `stop_all_on()`, `stop_all()`; a `play_on` loop stops when its node is freed; SFX players are pausable and UI and Music players aren't, and pausing ducks Music −6 dB and restores it; volumes reach the buses and 0 mutes; the six buses exist with their levels. It prints the output latency. In play nothing sounds and nothing changes; the sliders change volume at once and survive a restart; Esc still pauses.
   A1 built 2026-09-27, see CHANGELOG.md.
2. **A2 – Combat sounds with placeholders.** `AttackSwing.swing_sound` / `hit_sound` / `sound_pitch`, `HitContext.hit_sound` (from `basic_attack()`), HitFeel's five sounds, `DashComponent.dash_sound`, `Unit.hurt_sound` / `death_sound`, `AudioMix.pack_burst_sound`, CombatSounds (hits, crit layer, shield absorb, hurt, deaths, pack burst). Data: `combo_knight.tres`, `hit_feel_default.tres`, `player.tscn`, `slime.tscn` / `slime_elite.tscn`, `audio_mix_default.tres`. Placeholder files (CC0), about 20 WAVs. Built with synthesized stand-ins under these names (`audio/LICENSES.md`); replace a file with a real CC0 one of the same name, or point the SoundEvent at new files. The dash-strike swing uses the finisher's swing sound at pitch 1.1:

   | Sound event | Files | Should sound like |
   |---|---|---|
   | `sound_knight_swing` | 3 | a short sword whoosh (0.1–0.15 s), airy, no impact; swings 1–2 (pitch ×1.00 / ×1.04) |
   | `sound_knight_swing_finisher` | 2 | a heavier, lower, longer whoosh (~0.25 s) |
   | `sound_hit_light` | 3 | a crunchy flesh impact (≤ 0.15 s), sharp attack, fast decay; the most-heard sound |
   | `sound_hit_heavy` | 2 | a bigger thump with low end (~0.2 s); the finisher |
   | `sound_hit_kill` | 2 | a crunch plus a low thud (~0.3 s) |
   | `sound_hit_crit` | 2 | a bright metallic ring (~0.3 s), high, sits above the crunch |
   | `sound_knight_dash` | 2 | a quick air whoosh (~0.2 s), softer than the swings |
   | `sound_knight_hurt` | 2 | a dull body thud or grunt (~0.2 s), clearly unlike the hits you deal |
   | `sound_shield_absorb` | 2 | a glassy or metallic tink (~0.15 s) |
   | `sound_slime_death` | 3 | a wet splat (~0.3 s); the elite reuses it as `sound_slime_elite_death` at pitch 0.8 |
   | `sound_death_pack_burst` | 1 | one big layered wet burst (~0.5 s) |

   **Done means:** the audio test also covers: a swing on 5 dummies = one hit sound; a crit adds one crit layer; DoT ticks are silent; a hit on the player plays only its hurt (none when a shield takes it all, which plays the shield sound); a Cleave killing 3 slimes plays one pack burst and no death sounds, and two deaths 0.2 s apart play two death sounds. In play: swings whoosh and rise in pitch, hits crunch, the finisher and kills land heavier, crits ring, the dash whooshes, getting hit sounds different from hitting, slimes splat, and a pack dies in one burst. With every field empty, nothing sounds.
   A2 built 2026-09-27, see CHANGELOG.md.
3. **A3 – Abilities and statuses.** `Ability.cast_sound` / `hit_sound` / `telegraph_sound` / `ready_sound`, `HitContext.hit_sound` from `from_ability()`, `AbilityComponent.cooldown_finished`, `Telegraph.play_sound()`, `StatusEffect.apply_sound` / `expire_sound` / `loop_sound` in CombatSounds, the low-health heartbeat on Player, the room cleared and "You died" stingers in `main.gd`. Data: the four Knight abilities, the slam, the status files, `player.tscn`, `main.tscn`. Placeholders: a cast sound per Knight ability, Judgement's hit, the slam's wind-up (a rising rumble ~0.65 s) and hit, stun / slow / haste apply, shield apply and break, a heartbeat loop, the ultimate-ready ping, two stingers. Built with 16 synthesized stand-ins (`audio/LICENSES.md`): `sound_knight_cleave_cast`, `sound_knight_iron_resolve_cast`, `sound_knight_lunge_cast`, `sound_knight_judgement_cast`, `sound_knight_judgement_hit`, `sound_slime_elite_slam_telegraph` (640 px, HIGH), `sound_slime_elite_slam_hit`, `sound_status_stun_apply`, `sound_status_slow_apply`, `sound_status_haste_apply`, `sound_status_shield_apply`, `sound_status_shield_break` (the shield's expire sound), `sound_knight_low_health` (a loop: its WAV is imported with Loop Mode Forward), `sound_ui_ultimate_ready` (UI bus), `sound_stinger_room_cleared`, `sound_stinger_player_died` (SFX, centered, HIGH).
   - The wind-up plays at the telegraph, which is where the hit lands. The slam lands where the player stood, so its wind-up is always near the player; "heard from off screen" applies to telegraphs placed away from the player (up to 640 px).
   **Done means:** each Knight ability has its own cast sound; the elite's wind-up is heard from off screen, stops when the slam lands, and stops at once when the cast is interrupted; Judgement's stun plays its apply sound once; a status loop plays once per unit however many stacks; the heartbeat starts below 25% health and stops above it and at death; R pings when it comes off cooldown; "Room cleared!" and "You died" have stingers.
   A3 built 2026-09-27, see CHANGELOG.md.
- **Later, per system** (each written into that system's build order, pointing here): LOOT (drop by rarity, pickup), CHAMPIONS (voice lines; champion sounds onto ChampionData), ENEMIES_AI (enemy attack wind-ups and whiffs, aggro), WORLD_INTERACTION (impacts, hazard loops), DUNGEONS (music with explore and combat layers, room ambience, the room-clear transition), UI (hover, click, menu open and close, slider ticks), movement with sprites (footsteps on the F3 walk bob).

## Out of scope for now
The music system (adaptive layers), voice lines, footsteps, final audio assets. Placeholders only.

## Open questions
- Music style and who makes the audio (placeholders: CC0 packs only, e.g. Kenney).
- Adaptive music: explore vs combat layers (DUNGEONS.md).
- Should hitstop also briefly duck or low-pass the mix? (FREE to try.)
- Heartbeat as an option the player can turn off?
- Voice lines: how often, and which events (CHAMPIONS.md).
- When ChampionData exists, the champion sounds (hurt, death, low health) move onto it (CHAMPIONS.md). Until then they're exports on Unit and Player, set in `player.tscn`.
- A sound for a hit the dash dodged? Blocked hits emit no event today.
- A missed slam is silent after its wind-up: `Ability.hit_sound` plays only when the cast lands on someone. An impact sound on every `execute()` (the slam hitting the ground) would need a new hook (ABILITIES.md).
