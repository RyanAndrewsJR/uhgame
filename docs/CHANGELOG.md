# CHANGELOG.md: What Was Built and Measured

**Read when:** asked what was built or measured (test counts, measurements, what changed during a build step).
**Depends on:** nothing. **Used by:** nobody at build time: the system docs hold the specs.

## How to use
- One section per system, one entry per build step, **newest first**. Each entry: the step, its date, its status, and its build log (test counts, what was measured, what changed during the step).
- The system doc keeps only the spec, plus one line per step ("C8 built 2026-09-26, see CHANGELOG.md"). A rule found while building goes into the spec, not only here.
- Status: **Built (awaiting play test)** or **Passed** (Ryan's play test). When a play test passes, update the entry's status.
- Entries up to 2026-09-27 were moved here word for word from the system docs.

## Audio (AUDIO.md)

### A3 – Abilities and statuses: 2026-09-27, Built (awaiting play test)
**A3 – Abilities and statuses.** Ability cast/hit, the Telegraph wind-up, StatusEffect apply/expire/loop, low-health heartbeat, ultimate-ready ping, room cleared and death stingers.

`Ability.cast_sound` / `hit_sound` / `telegraph_sound` / `ready_sound`; `HitPipeline.from_ability()` copies `hit_sound` into the HitContext; `AbilityComponent` plays the cast sound at cast start, hands the telegraph its wind-up, and emits the new `cooldown_finished(slot, ability)` (with the ready sound) when a cooldown counts down to 0; `Telegraph.play_sound()` (stops at `finish()` or when freed); `StatusEffect.apply_sound` / `expire_sound` / `loop_sound`, played by CombatSounds on `Events.status_applied` / `status_removed`; `Player.low_health_sound` / `low_health_fraction` (0.25) on `health_changed`; `main.gd` `room_cleared_sound` / `player_died_sound`. Data: cast sounds on the four Knight abilities, Judgement's hit and ready ping, the slam's wind-up and hit, stun / slow / haste apply, the shield's apply and break (expire), the Knight's heartbeat in `player.tscn`, both stingers in `main.tscn` (so the sandbox gets them too). 16 more synthesized stand-in WAVs; the heartbeat is imported as a loop (`edit/loop_mode=2`, Forward, in its `.import`).

Audio test 109/109 (23 new A3 checks), three runs in a row: Cleave's cast sound at cast start, centered, and one hit sound for 3 targets; Judgement's cast sound, its own hit sound once instead of the tier's, and the stun it applies plays the stun sound on the dummy; Judgement has a ready sound; a 0.2 s-cooldown test ability emits `cooldown_finished` once and pings, a cancelled (refunded) cast doesn't; the slam's wind-up plays positional at the telegraph with 640 px, stops when the slam lands (its hit sound and the Knight's hurt play), when a stun interrupts it, and when the elite dies mid-cast; a 3-stack test status plays its apply sound 3 times and one loop, removing it stops the loop and plays its expire sound, a death stops the loop silently; the shield's apply sound on the Knight is centered and HIGH, 150 damage into it plays the absorb, the break and the hurt; the heartbeat doesn't play at 30%, starts once below 25% (centered), stops when healed, and a second Knight's stops when he dies. First run: one check failed because the test's Cleave had already hurt the dummy, so Judgement killed it (no stun); the test now heals it first. Combat test 450/450, stats test 172/172. Headless in-game check of the sandbox: standing by the elite plays its wind-up, the slam hit and the hurt; W then Q play their cast sounds and the haste's apply; killing every enemy plays one pack burst, one death sound and the "Room cleared!" stinger; the Knight at 20% starts the heartbeat, and his death stops it and plays the "You died" stinger. `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors or warnings.

### A2 – Combat sounds with placeholders: 2026-09-27, Passed
**A2 – Combat sounds with placeholders.** AttackSwing and HitFeel hooks, crit layer, dash, player hurt, shield absorb, enemy death and pack burst, the Events listener (CombatSounds).

`CombatSounds` (`scripts/audio/combat_sounds.gd`, a child of Audio); `AttackSwing.swing_sound` / `hit_sound` / `sound_pitch`, played at swing start by `AutoAttackComponent.try_swing()`; `HitContext.hit_sound` and `hit_sound_pitch` (new; the swing's pitch reaches its hit sound too), filled by `HitPipeline.basic_attack()`; `HitFeel.light_sound` / `heavy_sound` / `kill_sound` / `crit_sound` / `shield_absorb_sound`; `DashComponent.dash_sound`; `Unit.hurt_sound` / `death_sound`; `AudioMix.pack_burst_sound` / `pack_burst_count` / `pack_burst_window`; `Audio.stop_all()` resets CombatSounds. Data: 12 SoundEvents in `data/sounds/`, wired into `combo_knight.tres` (swings 1–2 `sound_knight_swing` at pitch 1.00 / 1.04, the finisher `sound_knight_swing_finisher`, the dash-strike the finisher's at 1.1), `hit_feel_default.tres`, `player.tscn` (dash, hurt), `slime.tscn` (death), `slime_elite.tscn` (`sound_slime_elite_death`: the slime's files at pitch 0.8), `audio_mix_default.tres` (pack burst). No CC0 files had been dropped in, so the 24 placeholder WAVs in `audio/sfx/` are synthesized stand-ins (noise, sines and filters from a Python script; listed in `audio/LICENSES.md` as CC0), under the names AUDIO.md lists.

Fixed while building: `Audio.play_on()` connected `tree_exiting` once per sound with a bound handle, but Godot ignores bound arguments when it checks for a duplicate connection, so a second `play_on()` on the same node failed with "already connected" (10 errors in the combat test, from swings and dashes on the Knight). Audio now keeps one connection per node and a list of its handles; the A1 owner-freed check now plays two sounds on one node.

Audio test 86/86 (24 new A2 checks), three runs in a row: a whiffed swing plays its sound centered at pitch 1.00, swing 2 at 1.04, the finisher its own, no hit sound; the dash is centered; a swing on 5 dummies hits all 5 with one hit sound (centered, HIGH); a crit swing on 5 adds one crit layer; a burn ticking 3+ times is silent; a slime hit on the Knight plays only his hurt (centered, HIGH), a hit into a shield only the shield sound; 3 kills in one frame play one pack burst in that same physics frame, no death sounds, and one kill sound; two deaths 0.2 s apart play two death sounds; deaths a frame apart play two death sounds then the burst, and a 4th inside the window is silent; the elite's death is its own sound, positional; with every sound field empty a hit and a death log nothing. Combat test 450/450, stats test 172/172. Headless in-game check in the sandbox: a chasing slime hitting the Knight plays one hurt sound; 4 swings kill a dummy with 3 swing sounds + the finisher's, 2 light hits, 1 heavy, 1 kill and 1 splat. `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors or warnings. Quitting in the middle of a sound prints Godot's leak warnings at exit (AUDIO.md, Godot behavior); not new errors in play.

**Passed** (Ryan's play test, 2026-09-27; merged to main). Ryan's follow-up commit removed `[audio] general/2d_panning_strength=0.5` from `project.godot` (the editor drops settings equal to their default); pan strength is still 0.5.

### A1 – Plumbing: 2026-09-27, Passed
**A1 – Plumbing.** Bus layout, SoundEvent, AudioMix, the Audio autoload (limits, priority, voice cap, real time, pause behavior, `stop_all()`, the log, `debug_draw`), Settings volumes and six pause-menu sliders, `Audio.stop_all()` before the restart, the `audio/` folders, `audio_test.tscn`.

`default_bus_layout.tres` (generated by Godot's own `AudioServer.generate_bus_layout()`: Master 0, Music −8 with a disabled 1200 Hz low-pass, SFX 0, UI −4, Ambience −12, Voice −2 dB), `project.godot` (Audio autoload last, after Settings and Reactions; `audio/general/2d_panning_strength` 0.5 written explicitly), `scripts/data/sound_event.gd`, `scripts/data/audio_mix.gd` + `data/audio_mixes/audio_mix_default.tres`, `scripts/autoload/audio.gd`, `Settings.get_volume()` / `set_volume()` / `get_volume_key()` / `VOLUME_BUSES` (saved as whole percents in `[audio]`), six volume rows in the pause menu (built in code under a new `%Volumes` container), `main.gd` calls `Audio.stop_all()` before `reload_current_scene()`, `audio/sfx|music|ambience/` and `audio/LICENSES.md` (no files yet), `data/sounds/` (empty). The pack burst fields join AudioMix in A2, with CombatSounds.

Audio test 62/62, three runs in a row (tones generated in code: SoundEvent wraps its files in a no-repeat AudioStreamRandomizer with random_pitch 1.05 and ±1 dB, cached and rebuilt when the jitter changes; the six buses, levels, sends, the Music low-pass off, pan strength 0.5; null plays nothing and logs nothing; an empty event is logged `no_audio` each time and warns once; 4 plays in a frame = 3 + 1 `instance_limit`, plays again 0.05 s of real time later, also at time scale 0.05 where one physics frame isn't enough; the Player's sounds centered, an enemy's positional at 480 px with linear falloff, a world sound positional, a non-positional event centered; `play_on()` follows an enemy; a one-shot beyond 480 px is `out_of_range` while a loop starts; `stop()`, `stop_all_on()`, a `play_on()` loop stopping when its node is freed (`owner_left_tree`), `no_owner`; `stop_all()` stops SFX and Ambience but not UI and Music and clears the limit history; with the cap at 4 a LOW and a NORMAL sound are dropped and a HIGH one steals the oldest NORMAL (`by high`); pitch 1.1 × 1.04 = 1.144 at time scale 0.05, `playback_speed_scale` 1; paused: SFX / Ambience / Voice players stop processing (`stream_paused` true), UI and Music keep going, Music −6 dB with its low-pass at 1200 Hz, all back after unpausing; SFX 50% = −6.02 dB and saved as 50, 0 mutes, values round to whole percents; the log keeps `log_size` entries; `debug_draw` lists played and dropped sounds and hides). The test sets the volumes to 100% and restores the saved ones at the end. Two of the first run's checks failed on test timing, not Audio: a SceneTreeTimer made mid-frame is charged that frame's whole delta (it fired after 0 ms), so the test waits on `Time.get_ticks_msec()`; and a `play_on()` position is only updated in Audio's next physics step.

Checked in Godot 4.7.2 (AUDIO.md, Godot behavior): the AudioStreamRandomizer, `max_polyphony`, AudioListener2D and panning names and defaults; the pause behavior of players; the Dummy driver runs streams to their end but reports 0 ms latency, so the real output latency comes from Ryan's machine (the audio test prints it). Not measurable headless: when a 2D sound becomes audible.

Combat test 450/450, stats test 172/172 (unchanged). A headless in-game check of `sandbox_main.tscn`: the pause menu has 6 sliders, the Music slider at 50 sets `Settings` to 0.5 and the Music bus, Resume unpauses. `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors or warnings.

**Passed** (Ryan's play test, 2026-09-27): audio test 62/62 on his machine; output latency 10 ms with WASAPI (15 ms requested). Merged to main.

## Combat (COMBAT.md)

### A swing counts once its hit has landed: 2026-09-27, Built (awaiting play test)
**Rule change** (Ryan, 2026-09-27; COMBAT.md, Basic attack): every cancel the player chooses after a swing's hit has landed (walking, a dash, an ability cutting the recovery) keeps the combo; the index advances as if the swing had finished and `combo_reset_time` counts from the cancel. Windup cancels and forced interruptions (stun, death) still reset it. Planned first, then built as its own small step.

`AutoAttackComponent.cancel_swing(keep_combo_if_landed = false)` and `_get_index_after_swing()` (shared with `_finish_swing()`); `DashComponent.try_dash()` passes true; `add_lock()` passes it only for the casting lock (`CASTING_LOCK`). Walking needed no change (it only ends the root; the swing still finishes). Combat test 450/450: 2 C2 checks updated (a dash or a Q in the recovery now leaves swing 2 next instead of swing 1) and 11 new checks (hit, dash in the recovery, click: swing 2; dash in the windup, click: swing 1; right after the dash swing 2 is next and 0.75 s later swing 1; a finisher dashed out of after its hit keeps its breather and swing 1 is next; dashing out of a landed dash-strike leaves the interrupted swing next; swing 1 hits, Q (AFTER_HIT) cuts its recovery, a click gives swing 2; an ANYTIME Q in swing 2's windup resets to swing 1; a stun after the hit still resets). Stats test 172/172; headless in-game check 43/43; `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors.

### C12 – Dash-strike: 2026-09-27, Built (awaiting play test)
**C12 – Dash-strike.** Decided in an interview first (DECISIONS.md, Combat): its own strong swing per champion, doesn't count as a combo hit, the Knight's 1.5 × AD with a 16 px step (other classes in CHAMPIONS.md), window 0.15 s.

`combo_knight.tres` gets a `dash_strike` swing (1.5 AD, 16 px step / 32 px pull, heavy feel, 0.35 s, 80° thrust, reach × 1.15, 16 px push, no breather); `AutoAttackComponent` runs it with index −1 (`is_dash_strike()`), tags its hits `dash_strike`, and resumes the combo where it was when it ends; `PlayerInput.dash_strike_window` 0.1 → 0.15 s; the Player's slash uses the finisher look for it. Combat test 439/439 (14 new C12 checks: the swing's numbers and the 0.15 s window; index −1 and `is_dash_strike()`; a 16 px step in the air; 96 damage tagged `basic_attack` + `dash_strike` with the heavy 0.06 s hitstop; a normal swing isn't tagged; through PlayerInput a click during the dash and one 0.13 s after it are dash-strikes, one 0.23 s after is a normal swing; swing 1, dash-strike, swing 2, dash-strike, swing 3 deal 64 / 96 / 64 / 96 / 102.4; after a reset it leaves the combo at swing 1; a cancelled dash-strike resets the combo). Stats test 172/172; headless in-game check 43/43; `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors. Left open for Ryan: a dash out of a landed swing's recovery still resets the combo (C2 rule; COMBAT.md, Open questions).

### C11 – Reaction rules: 2026-09-27, Built (awaiting play test)
**C11 – Reaction rules** (`HIT`, `UNIT_DIED`, `STATUS_APPLIED`; the four GameplayEffects). Decided in an interview first (DECISIONS.md, Combat): world rules and unit rules; chain length set per rule (`chain_limit`), capped at 5; system only, plus one sandbox demo.

`ReactionRule` (`scripts/data/reaction_rule.gd`; new fields `id`, `required_status_tags`, `effect_target`, `owner_role`, `chain_limit`, `MAX_CHAIN` 5), `GameplayEffect` and `ApplyStatusGameplayEffect` / `DealDamageGameplayEffect` / `KnockbackGameplayEffect` / `HealGameplayEffect` (`scripts/data/`), the `Reactions` autoload (`scripts/autoload/reactions.gd`: world rules from `data/reactions/world/` (empty) and `add_world_rule()`, unit rules from `Unit.add_reaction_rule()`, seedable `rng`, `get_chain_depth()`), `HitContext.target_tags` (the target's status tags before the hit). Demo: `data/reactions/reaction_shatter.tres` given to the player only in `sandbox.tscn` by a `SandboxReactions` node (`scripts/rooms/sandbox_reactions.gd`). Combat test 425/425 (26 new C11 checks: the Shatter data; no world rules and no rules on the Knight outside the sandbox; Shatter adds exactly one 30 MAGIC `shatter` proc to a swing on a stunned dummy, none on an unstunned one, none on Judgement's own stunning hit, one on the next Cleave, none once removed; "when I'm hit, heal" (AFFECTED) fires, a SOURCE rule on the one hit doesn't; "when I hit, heal me" (effect target OTHER); "on kill, heal me 20"; "kill a slowed enemy" reads the tags from before the hit although death clears them; a world "burning also slows" rule ignores a haste, slows for 0.8 s from the burn's applier, and removing it works; "on crit" fires only on crits; chance 0.5 fires 195 of 400 (seeded); chance × proc coefficient 0.25 fires 97 of 400 Cleaves; a DoT tick never triggers HIT rules; a self-re-applying rule gives 1 / 3 / 5 / 5 reactions at chain_limit 1 / 3 / 5 / 9 and the chain depth returns to 0; DealDamage 10 + 0.5 AD = 42 MAGIC proc that can't crit; ApplyStatus 0.5 s from the source; Heal 10 + 1% max = 62.8; Knockback 20 px away from the source). Two first-run test bugs fixed (the recorder hears the proc before the hit because Reactions listens first; 400 hits killed the chance dummy). Stats test 172/172; headless in-game check 43/43 twice (the sandbox Knight has exactly the Shatter rule and a swing on a stunned dummy deals 64 + 30; the room_01 Knight has no rules); `main.tscn` and `sandbox_main.tscn` run 600 frames with no errors.

### Telegraph fix – a caster that dies mid-cast: 2026-09-27, Passed
**Fix – Telegraph on caster death** (before C11; COMBAT.md, Known bugs).

Reproduced first in Godot 4.7.2 headless: the sandbox-style elite killed 0.1 s into its slam was freed by its death tween (0.33 s) before the 0.65 s cast time ended, its waiting `_do_cast()` never resumed (no error printed), and the telegraph was still on the floor, full, 2 s later. Fix: `AbilityComponent.interrupt_cast()` (new), called by `Unit._on_died()`: during the cast time it frees the telegraph, releases the cast's locks, refunds the cooldown for a living caster and emits `cast_finished`; a `NOTIFICATION_PREDELETE` guard frees the telegraph when a caster is freed without dying. `_cancel_cast()` and the cast flow are unchanged. Combat test 399/399 (12 new checks: killed 0.1 s in, the cast ends at once with one `cast_finished` and the telegraph is gone the next frame, nothing left after the elite is freed, no slam lands; killed 0.5 s in, the telegraph goes at once and `cast_finished` still fires only once after the cast time passes; freed mid-cast without dying, the telegraph goes with it; `interrupt_cast()` on a living caster refunds and removes the telegraph, and does nothing with no cast running). 8 of the 12 fail on the old code. Stats test 172/172. Headless sandbox check: the real `Elite1` casts on its own after 18 frames, is killed 4 frames in, its circle is gone 2 frames later and none are left 1.5 s later. `main.tscn` and `sandbox_main.tscn` run 300 frames with no errors.

**Passed** (Ryan's play test, 2026-09-27): telegraphs are removed when their caster dies. Merged to main.

### C10 – Shields: 2026-09-27, Built (awaiting play test)
**C10 – Shields** (shield statuses; absorb order: the one expiring soonest first, proposed).

`StatusEffect.shield_amount`, `StatusComponent.absorb_damage()` / `get_shield()` / `get_total_shield()`, `Unit.on_hit` takes shields before health, the shield number (`DamageNumberStyle.shield_color`, `DamageNumber.Kind.SHIELD`), `data/statuses/status_shield.tres`. Combat test 387/387 (23 new C10 checks: 80 into a 100 shield is all absorbed with one silver "80"; the next 80 splits 20 / 60 with two numbers and ends the shield; absorbing happens after armor; TRUE damage is absorbed; a fully absorbed hit can't kill; three shields empty soonest-expiring first, "until removed" last; stacked shields empty per stack; REFRESH_LONGER keeps the bigger shield; a swing into a shield still life-steals 32 and pushes; an absorbed hit still applies its statuses; a DoT tick is absorbed with a small shield number; a slime hit on a shielded Knight costs no health and still starts i-frames). Stats test 172/172; headless in-game check 40/40 on the third run: two runs each had a different timing miss (the slime hit, the elite circle), and the same elite miss shows up on the pre-C10 code (1 in 4 runs), so the throwaway check is flaky, not C10; room_01 and the sandbox run with no errors.

### C9 – Statuses: 2026-09-27, Built (awaiting play test)
**C9 – Statuses.** `StatusComponent`, `StatusEffect`, `status_stun` / `status_slow` / `status_haste`, the `apply_stun()` and `add_speed_modifier()` wrappers, tenacity, DoT with kill credit.

`StatusEffect` (`scripts/data/status_effect.gd`), `StatusComponent` (`scripts/components/status_component.gd`, on `player.tscn` and `slime.tscn`), `data/statuses/status_stun.tres` (cc / stun / debuff, blocks all four, REFRESH_LONGER, the stars VFX `scenes/vfx/stun_stars.tscn`), `status_slow.tres` (cc / slow / debuff, −30%, REFRESH, 1.5 s), `status_haste.tres` (haste / buff, +20%, REFRESH, 2 s); `Events.status_applied` / `status_removed`; the two wrappers; `HitContext.statuses` applied by `on_hit`. Combat test 364/364 (42 new C9 checks: the three status files; a stun blocks move / swing / cast / dash with the stars, keeps the longer time and ends after 1.0 s of game time; Judgement's stun is 0.75 s with the Knight as source; 50% tenacity halves the stun and a slow but not a haste or a burn; Iron Resolve is a 2 s `iron_resolve` haste at 739.6 speed, back to 560 after; a slow's same id replaces it, `remove_speed_modifier()` and "until removed" work; STACK (3 stacks, run out one by one, the shortest restarts at max), IGNORE, REFRESH; a 2 s / 0.5 s burn ticks 4 × 42 with AD snapshotted, tagged `dot` + `burning`, MAGIC, never crits, the first tick at 0.5 s; +50% vs burning works; 3 stacks tick 126; a DoT kill credits the applier; a freed applier's burn keeps ticking; a tick on the Knight starts no i-frames; a hit's `statuses` apply (not when blocked); status events; death clears everything). Stats test 172/172; headless in-game check 40/40 (Judgement stuns, Iron Resolve speeds up to 739.6, slimes and the elite unchanged); room_01 and the sandbox run with no errors.

### C8 – Crits and on-hit: 2026-09-26, Built (awaiting play test)
**C8 – Crits and on-hit.** Crit (1.75 default), `damage_increase` scopes, `incoming_damage`, the on-hit stats, `proc_coefficient`. Migrate the Knight's 4 abilities from `take_damage()` to `HitPipeline.from_ability()`, so ability hits get crits, `damage_increase`, on-hit and proper tags.

5 new stats (26 in the registry) and `crit_damage` 1.75; `damage_increase` with `hit:` / `target:` scopes (`StatsComponent.get_scoped_stat()`), crit (`HitPipeline.roll_crit()`), `incoming_damage` in `Unit.on_hit`, on-hit (`HitPipeline.apply_on_hit()`, `make_proc()`, `Unit.heal()`), `Unit.get_status_tags()` (the stun only until C9). Cleave, Lunge and Judgement hit through `HitPipeline.from_ability()` (Judgement's missing-health bonus is added to the base damage); Cleave's push and Judgement's stun skip blocked hits; Iron Resolve's bonus already rode the swing's pipeline hit. League-style enemy attacks are tagged `basic_attack`. After Ryan's review, crits switched from plain dice to PRD with one roll per swing or cast (11 more checks: the constants 0.0847 / 0.3021; 4000 seeded rolls at 25% give 25% with ~8.5% crit-after-crit and never more than 11 misses in a row; 4 real swings and 6 Cleaves on 2 dummies crit both or neither and move the counter once). Combat test 322/322 (311 before PRD) (42 new C8 checks: Cleave 124.8 / Lunge 82 / Judgement 214 and 414 with their tags and no crit; 100% crit: a swing 112 with a "112!" number, Cleave 218.4, `take_damage()` and procs never crit, +0.5 crit damage = 144, 0% = no crits, 25% ≈ 100 in 400 seeded rolls, crit chance scoped to basic attacks; +20% on basic attacks = 76.8 while Cleave stays 124.8, increase before crit = 134.4, +50% vs stunned = 187.2 on the stunned dummy only; two 20% `incoming_damage` reductions = × 0.64, after armor; 20 on-hit = a 20 MAGIC proc, 10 at proc coefficient 0.5, none for DoT ticks, `take_damage()` or blocked hits; life on hit, life steal (basic attacks only), resource on hit; an enemy's proc on the player isn't blocked by its own i-frames). Stats test 172/172; headless in-game check 40/40 (Cleave's real hit carries its tags, the real slime's hit is tagged `basic_attack`); room_01 runs with no errors.

### M1 – a one-room fight in the sandbox: 2026-09-26, Passed
Milestone: the Knight fights with the combo, slimes chip, one elite telegraphs a slam, and the player can die ("You died", Backspace restarts) and win ("Room cleared!").

**Passed** (Ryan's play test, 2026-09-26): combo, dashes and abilities fine (reads as a rogue/diver pace); swarm pressure felt too fair, so post-hit i-frames 0.5 → 0.3 s; the elite slam was readable but too easy to escape, so 40 → 72 px and 0.75 → 0.65 s; death and restart, and the room clear, work. Combat test 263/263 after the changes (plus a 2-hit and a 5-hit combo check).

### C7 – Line of sight: 2026-09-26, Built (awaiting play test)
**C7 – Line of sight.** The filter in swing hits and `AbilityUtil`, `ignores_walls` on Ability (`WorldQuery.has_line_of_sight()` already exists, built with the melee pull).

`Ability.ignores_walls` (default off), `Ability.filter_by_walls()` / `can_reach_through_walls()`, `AbilityUtil.in_sight()`. Walls now block: combo swings (feet to feet), League-style enemy attacks (a wall in between = a whiff), Cleave, Lunge (sight from the nearest point of its path), the elite slam (from the circle's center), and Judgement (a UNIT ability: out of sight counts like out of range, so it walks until it can see the target; a target that goes behind a wall during the cast is missed). Combat test 261/261 (11 new C7 checks, each with the target in reach so only the wall stops it); stats test 143/143; headless in-game check 38/38 (a swing and a Cleave at a dummy behind the sandbox pillar do nothing; the same swing hits in the open); room_01 runs with no errors.

### C6 – Damage numbers: 2026-09-26, Built (awaiting play test)
**C6 – Damage numbers.** 3 log-scale size steps, crit style (placeholder until the font), colors by type, the player's damage red, healing green, DoT merge, rise 12 px / fade 0.6 s.

combat test 250/250 (14 new C6 checks: the size steps; one number per swing; swing 1 "64" size 10 in the physical color, the finisher "102" a size bigger; magic blue and true white; a crit "64!" 3 sizes bigger; three DoT ticks within 0.3 s merge into one "30" at size 8 and a later tick starts a new number; a green "+15"; the player's damage red; no number for a blocked hit; it rises 12 px, fades and is gone after 0.6 s). Stats test 143/143; headless in-game check 35/35 (a swing on a sandbox dummy shows one orange number; the player's damage is red); room_01 runs with no errors. "Nothing overlaps unreadably with 5 slimes" needs Ryan's eyes.

### C5 – Elite: 2026-09-26, Built (awaiting play test)
**C5 – Elite.** `slime_elite.tscn` (inherits `slime.tscn`) + `data/units/slime_elite.tres` (starting values: 900 health, 100 damage = 15% of the Knight's 650), a telegraphed slam ability (0.75 s telegraph, about 40 px circle), `Telegraph`, the Enemy cast hook, one elite in the sandbox.

`scenes/enemies/slime_elite.tscn` (inherits `slime.tscn`: purple, ×1.4 body, 19 px collider, AbilityComponent with the slam) + `data/units/slime_elite.tres` (900 health, 30 basic attack damage = 4.6% (swarm band) with a 0.25 s windup, 260 move speed); `Elite1` in the sandbox's open top-right corner (784, 112). Combat test 225/225 (20 new C5 checks: the numbers; a telegraph where the Knight stands, half full at 0.37 s; 100 damage and a 20 px push at 0.75 s; the telegraph gone after; walking and dashing out; a stunned elite's slam doesn't go off, its telegraph is removed and its cooldown refunded; the elite AI casting the slam by itself). Stats test 143/143; headless in-game check 33/33 (the sandbox elite casts at the real player, its telegraph is on the room floor under the units, standing in it costs 100, walking out with a real key press avoids it); room_01 and the sandbox run with no errors.

### C4 – Getting hit: 2026-09-26, Built (awaiting play test)
**C4 – Getting hit.** Post-hit i-frames, 12 px knockback on the player (marked as hit knockback, which a dash replaces), enemy whiffs out of reach, stronger-knockback-wins, slime windup retuned into 0–0.3 s.

combat test 205/205 (32 new C4 checks: the numbers; the first of two same-frame hits lands and the second is blocked; i-frames last 0.5 s and the Knight blinks; a DoT tick starts none; a slime winds up 0.25 s, hits for 22 and pushes 12 px away; the push is dash-cancelable and a dash replaces it; teleporting out of reach mid-windup is a whiff; a 6 px push during a 20 px one is dropped, a 30 px one replaces a 6 px one; a swing during a stronger knockback leaves it alone); stats test 143/143; headless in-game check 27/27 (the real slime AI hits, pushes 12 px and starts 0.5 s of i-frames; walking away with a real key press during its windup makes it miss); room_01 runs with no errors.

### C3 – Hit feel: 2026-09-26, Built (awaiting play test)
**C3 – Hit feel.** Feel tiers from `HitContext.feel` (light / heavy / kill), longest-wins hitstop, 0.06 s flash, shake per tier.

combat test 173/173 (20 new C3 checks: the tier numbers; overlapping hitstops 0.03 → 0.08 → 0.02 end at 0.08 s; swings 1–2 freeze 0.03 s with no shake, the finisher 0.06 s with a 2 px shake, a kill 0.08 s with 3 px, a whiff nothing; `take_damage()` hits and a blocked hit play no feel; Cleave shakes only its own 3 px; the flash is white at the hit and gone after 0.06 s). The C2 swing-length check now measures game time, since a hit's hitstop adds physics frames but almost no game time. Stats test 143/143; headless in-game check 21/21; room_01 runs with no errors.

### Melee basic attacks (between C2 and C3): 2026-09-26, Built (awaiting play test)
**Melee basic attacks** (between C2 and C3): swing step, target pull with aim snap, walk-cancel of the recovery, `attack_style`, minimal `WorldQuery`.

combat test 153/153 (44 new checks: steps 6 / 6 / 10 px in the air, a slime 15° off and 95 px away aimed at with the aim snapped onto it, a capped 24 px pull that connects, a stretched 18.2 px step ending at 39.2 px, 6 px when already close, stopping at a touching slime's edge, no pull at 60°, a 20° max snap at 30°, the aim-line pick of two, no pull through a wall, dash and stun during the step, the root ending 6 frames after the hit with the combo continuing, RANGED); stats test 143/143; headless in-game check 21/21 (a real click 12° off a slime 97 px away pulls 24 px and connects; the sandbox's own pillar blocks the pull; enemies, abilities, i-frames and the HUD unchanged); room_01 runs with no errors.

### C2 – Knight combo: 2026-09-26, Built (awaiting play test)
**C2 – Knight combo.** `AttackSwing`, `AttackCombo`, `combo_knight.tres`, the combo mode, PlayerInput/Dash/Player changes, `cancels_swing`, `select` unbound, Iron Resolve through swings.

combat test 109/109 (59 new C2 checks: hit 5 frames after the click, swing 18 frames, 64 / 64 / 102.4 damage, the finisher's 20 px push, reach 70 / 78 px hit and 82 px miss, arc, reset after 0.6 s, a click 1 frame into a swing starts swing 2 right as it ends, dash / stun / Q / death cancels, Iron Resolve on two slimes, +50% attack speed = 12-frame swings); stats test 143/143; headless in-game check 15/15 (a real left click swings and hits for 64; the Knight's abilities, slimes chasing and hitting, i-frames and the HUD unchanged); room_01 runs with no errors.

### C1 – Hit pipeline: 2026-09-26, Built (awaiting play test)
**C1 – Hit pipeline.** `Events`, `HitContext`, `HitPipeline`, `Unit.on_hit`; `take_damage()` and `_on_hurtbox_hurt` wrapped; `damage_type` and `proc_coefficient` on Ability. A test scene `res://scenes/tests/combat_test.tscn` (script in `scripts/tests/`).

`combat_test.tscn` 50/50; stats test 143/143; a headless in-game check in the sandbox 11/11 (Cleave 124.8, Lunge 82, Judgement's damage and stun, Iron Resolve's haste, a slime chasing and hitting for 22 through `Events.unit_hit`, i-frames, the HUD); room_01 runs with no errors.

## Movement (MOVEMENT.md)

### F3 – Movement feedback (VFX only): 2026-09-25, Built (awaiting play test)
The step as planned, then as built (moved from MOVEMENT.md, Feel pass). Where the plan and the build differ, the build and MOVEMENT.md win.

- **Dash:** stretch the Body along the dash direction (1.25 × 0.8) for 0.06 s, then ease back; squash it slightly (0.9 × 1.1) for 0.05 s when the dash ends; spawn 3–4 afterimages about 0.03 s apart, each fading over 0.15 s; a small dust puff at the start.
- **Walking:** a 1 px bob at a rate tied to speed, and a dust puff on a sharp direction reversal (more than 135°).
- **Knockback:** any displaced unit stretches along the push direction, scaled by its current speed.
- **Structure:** one reusable node in `scripts/vfx/`, named per CONVENTIONS. It listens to MovementComponent and DashComponent signals, has an on/off toggle, and exports every value. It must work on today's Polygon2D placeholders and on 8-direction sprites later. The F3 plan says whether pixel snapping makes the squash look jittery at 640×360.
- **Done means:** the effects are visible but never hide where the player actually is, and turning the toggle off gives exactly today's visuals.
- **Built** (awaiting play test):
  - `MovementVFXComponent` (`scripts/vfx/movement_vfx_component.gd`), the last child of `player.tscn` and `slime.tscn`. `enabled` turns everything off; every number is an export (groups Dash, Walking, Displacement, Dust). VFX only: it reads the components' signals and public state and never changes gameplay state. Dust uses its own random generator, so slime wander rolls don't change.
  - **How the Body is deformed:** only while the frame is drawn. It applies the deformation on `RenderingServer.frame_pre_draw` and undoes it on `frame_post_draw`, so code that writes `body.scale` / `body.position` (player flip and bob, slime squash, death tweens) never sees it, and player.gd, enemy.gd and unit.gd are unchanged. While enabled, the Body's own physics interpolation is off, or the deformation only shows partly; the unit itself stays interpolated, so F1 smoothness is unchanged. Deformation pivots on the feet (`deform_pivot`), so the feet stay on the shadow. The Shadow and the sword are never deformed.
  - **Dash:** stretch 1.25 × 0.8 (along × across the dash) held 0.06 s, eases back over 0.08 s; squash 0.9 × 1.1 when the dash ends, held 0.05 s, eases back over 0.08 s. 4 afterimages 0.03 s apart (the first at the start point), each fading over 0.15 s. They're flat cyan silhouettes (`afterimage_color`, 50%) drawn as one shape (a CanvasGroup), so they can't be mistaken for the half see-through player; `afterimage_silhouette = false` gives tinted copies instead. Each is placed where the unit was at the start of its physics frame, so it never shows up ahead of the player. They're copies of the Body, so sprites work too (as a still frame). A dust puff (6 specks flying 14 px back, flattened ×0.5 onto the floor, 0.3 s) at the start.
  - **Walking:** a 1 px bob, one per 40 px walked (about 4.5 a second at 179 px/s, today's cadence; faster when hasted). While enabled it replaces player.gd's 2 px bob (`replace_existing_bob`). Reversal dust: a turn of more than 135°, after the old direction reached 90 px/s, within 0.1 s of walking it (so letting go and pressing the other way counts), at most every 0.15 s. With 8-way keys a full reversal counts; exactly 135° (right → down-left) doesn't.
  - **Knockback:** any displacement that isn't the unit's own dash (knockback, pulls, Lunge) stretches along the push by 1 + 0.0005 × speed (px/s), up to 1.3; across = 1 / along. Cleave's knockback (407 px/s peak) gives 1.2; Lunge starts at 1.3 and eases out with its speed. It reads `is_displaced()` and the unit's velocity every frame instead of a new signal (the stretch follows the speed anyway), so MovementComponent is unchanged.
  - **Slimes:** walk bob and reversal dust off (they have their own hop); knockback stretch on.
  - **Pixel snapping:** the squash doesn't jitter. `snap_2d_transforms_to_pixel` is off since F1, so the deformation scales smoothly (edges move in half-game-pixel steps at 1280×720). With 8-direction pixel sprites, a non-integer scale draws some art pixels one screen pixel wider than others for the ~0.15 s an effect lasts. That's the normal look of squash and stretch on pixel art and hard to see at that length; if it shows, pick stretch values that land on whole pixels or turn the deformation off for that unit.
  - Measured at 144 fps: the stretch holds 8 frames and is gone 0.13 s into the dash; the squash holds 7 frames and is gone 0.12 s after the dash; 4 afterimages and 1 dust puff, all gone 0.12 s after the dash ends. With `enabled` off, 859 frames (walk, dash, reversal, dash down, Cleave knockback, Lunge) are pixel-identical to before F3. Walking shake (F1 metric) 0.03 px (0.04 before). The Knight's abilities, chasing and the HUD checks pass.

### F4 – Camera aim lead rework (ran before F3): 2026-09-25, Built (awaiting play test)
The step as planned, then as built (moved from MOVEMENT.md, Feel pass). Where the plan and the build differ, the build and MOVEMENT.md win.

- **Problem (play testing):** the locked camera moves too much when the cursor moves. The lead should help aim at enemies slightly off screen, not follow every mouse movement. Causes in the current code:
  - No dead zone: any cursor movement shifts the camera.
  - The lead is 64 px on both axes, but the screen is 640×360, so vertically it's over a third of the half-screen.
  - The lead uses the same position smoothing (10) as the player follow, so it can't be slower without making the follow laggy.
  - The lead is measured in screen space, so when the camera leans, the world point under a still cursor slides.
- **Changes** (all `@export` on GameCamera, additive; `aim_lead` keeps its name and meaning as the horizontal maximum):
  1. **Dead zone:** no lead while the cursor is inside `aim_lead_dead_zone` = 0.35 of the half-screen, measured as an oval (x and y each divided by their own half-size).
  2. **Response:** from the dead zone edge to `aim_lead_full_at` = 0.9, the lead follows a Curve (`data/curves/curve_camera_lead.tres`, ease-in quad). Full lead beyond that.
  3. `aim_lead_y_scale` = 0.6 for the vertical lead.
  4. The lead eases toward its target at its own rate, `aim_lead_smoothing` = 4.0 per second (frame-rate independent). The follow smoothing stays at 10.
  5. **Context:** full lead while the player is aiming or casting an ability (and in ATTACK once COMBAT exists); `aim_lead_idle_scale` = 0.3 otherwise. Read through the Player's public state (`Player.state` / `is_in_state()`, `aiming_slot`). No new coupling beyond the camera's existing target.
  6. `move_lead_px` = 0 (off): an optional lean in the walking direction, blended the same way. Try 12–16.
  - Holding C still centers with no lead. Shake, bounds and `snap_to_target()` behave as now.
  - `debug_draw` on GameCamera: the dead zone oval, the target lead, and the current lead.
- **Done means:**
  - Moving the cursor inside the dead zone doesn't move the camera.
  - Flicking the cursor corner to corner moves the camera over about half a second, with no whip.
  - Walking without aiming barely leans; holding an aimed ability toward an off-screen dummy leans fully.
  - F1 smoothness is unchanged (no new stutter).
  - The Knight's abilities, enemies chasing and the HUD still work.
- **Built** (awaiting play test). Additions agreed with Ryan: `aim_lead_hold_time` = 0.75 s (full lean stays this long after the last aim or cast, so it doesn't swing back between casts, and so QUICK cast mode still gets it); `aim_lead_smoothing` stays 4.0.
- **Aim drift (accepted):** the world under a still cursor still slides whenever the lean changes. Full lean starts when you begin aiming, so while you hold an ability still, the spot under the cursor can move up to 80 px sideways / 48 px vertically over about 0.7 s (64 / 38 px when first measured), and a POINT ability like Lunge lands where the cursor is at release. Accepted because the indicator always shows the true landing spot (clarity), and the lean only grows outside the dead zone and while aiming. Revisit if play testing shows mis-aims.
- Measured at 144 fps with `aim_lead` = 64 px, before it was raised to 80 (camera movement = how far the world under a still cursor slides, game px; lean amounts now scale by 80/64 = 1.25, timings don't change):

  | Test | Today | F4 idle | F4 aiming |
  |---|---|---|---|
  | Cursor center → right edge, held still | 64 px, 90% in 0.23 s, peak 648 px/s | 19 px, 0.69 s, 72 px/s | 64 px, 0.68 s, 144 px/s |
  | Cursor center → bottom edge | 64 px, 0.22 s | 11.5 px, 0.67 s | 38 px, 0.68 s |
  | Small moves inside the dead zone | 12–16 px each | 0 | 0 |
  | Flick corner to corner | 128 px diagonal, 0.22 s, peak 1274 px/s | 31 px, 0.68 s | 105 px, 0.69 s, peak 260 px/s |
  | Walking shake (F1 metric) | 0.03 px | 0.03 px | – |

### F2 – Displacement curves: 2026-09-25, Built (awaiting play test)
The step as planned, then as built (moved from MOVEMENT.md, Feel pass). Where the plan and the build differ, the build and MOVEMENT.md win.

- **MovementComponent:** a displacement follows a progress `Curve` (x = time 0–1, y = share of the distance covered 0–1). Each physics frame it moves `total_offset × (p(now) − p(previous frame))` through `move_and_slide()`. The total distance stays exactly velocity × duration, so current distances don't change; only the speed profile does.
- **Additive API:** an optional `curve: Curve = null` parameter on `displace()` and `dash()`. `null` = linear, today's behavior.
- **Curves** are .tres files in `data/curves/` (`curve_dash.tres`, `curve_knockback.tres`), editable in the Inspector's curve editor. Starting shapes: dash = ease-out quad (peak speed about 2× average, roughly 1420 px/s on the first frame, easing to 0); knockback = ease-out cubic (hard burst, fast settle).
- **Knockback default:** MovementComponent gets a `knockback_curve` export, used when `displace()` is called without a curve. The F2 plan lists which existing callers that changes.
- **Lunge:** a curve export on its Ability, set to `curve_dash.tres`. The F2 plan says whether Lunge's hit logic depends on constant speed.
- **Dash exit:** a `carry_into_run` export on DashComponent (default true). If a direction is held when the dash ends, walking starts at full speed instead of ramping up from 0. The F2 plan recommends how this interacts with `end_lag` (0.05 s of locked walking after a dash).
- **Debug:** `debug_draw` on MovementComponent draws a graph of the last 1 s of speed (px/s) above the unit.
- Stuns, walls and `displacement_finished` behave exactly as they do now.
- **Done means:** the dash still covers exactly 128 px (the cracked tiles); the speed graph shows a burst and then an ease-out; there's no visible pause between the dash and running; knockback on slimes bursts and then settles.
- **Built** (awaiting play test):
  - `null` means different things on the two methods: `dash(..., curve = null)` = constant speed; `displace(..., curve = null)` = `knockback_curve`. So knockback eases by default and existing dash callers can opt in.
  - Progress is normalized (`(p(t) − p(0)) / (p(1) − p(0))`), so a hand-edited curve that doesn't run exactly 0 → 1 still covers the full distance.
  - Defaults are set in the scripts, so every unit gets them: `MovementComponent.knockback_curve` = `curve_knockback.tres` (ease-out cubic), `DashComponent.dash_curve` = `curve_dash.tres` (ease-out quad). Lunge's `dash_curve` is set in `knight_e_lunge.tres`.
  - Callers whose speed profile changes: Cleave's knockback (`cleave.gd`, 17 px over 0.1 s) and Hurtbox knockback (`Unit._on_hurtbox_hurt`, no Hitbox uses it yet) now use `knockback_curve`. The dash and Lunge use `curve_dash`. Distances are unchanged.
  - Lunge's hits don't depend on its speed: they're found along the segment from the start point to the end point after the dash. Only its afterimages (spawned every 2 physics frames) now bunch toward the slow end.
  - **Dash exit:** if a direction is held when the dash ends, walking starts at full speed and `end_lag` is skipped. If no direction is held, `end_lag` (0.05 s) still locks walking, which plants the stop.
  - **Speed graph:** `debug_draw` on MovementComponent draws the actual distance moved per physics frame (so walls show), over `debug_graph_time` = 1 s, scaled to `debug_graph_max_speed_px` = 1500 px/s.
  - Measured: the dash covers 128.0 px in 11 frames at 1356 → 1225 → 1093 → … → 171 → 42 px/s, then runs on at 179 px/s the very next frame. Cleave knocks a dummy 17 px at 407 → 269 → 160 → 79 → 27 → 3 px/s. Lunge still covers 128 px and hits. A dash into the pillar stops exactly as before.

### F1 – Smooth frames: 2026-09-25, Built (awaiting play test)
The step as planned, then as built (moved from MOVEMENT.md, Feel pass). Where the plan and the build differ, the build and MOVEMENT.md win.

- **Problem:** physics runs at 60 Hz with no physics interpolation, `snap_2d_transforms_to_pixel` is on, and the camera uses position smoothing (speed 10). At 179 px/s the player moves about 3 px per tick, which stutters, especially on monitors above 60 Hz.
- **Scope:** investigate and recommend one option among 2D physics interpolation, the camera's process callback, the physics tick rate, and pixel snapping.
- **Done means:** walking along the sandbox's long wall and dashing back and forth show no visible stutter at 60 Hz or at Ryan's monitor refresh rate (144 Hz), and the pixel art stays crisp.
- **Built** (awaiting play test):
  - `project.godot`: `physics/common/physics_interpolation` on; `rendering/2d/snap/snap_2d_transforms_to_pixel` off. Physics stays at 60 Hz. (Godot turns `physics_jitter_fix` off by itself when interpolation is on.)
  - Camera: `process_callback` = Physics on the Camera node in `main.tscn`. Godot forces this when interpolation is on and prints a warning otherwise. The follow logic in `game_camera.gd` stays in `_process`; moving it to `_physics_process` measured no smoother.
  - `GameCamera.snap_to_target()` calls `reset_physics_interpolation()` before `reset_smoothing()`, and again after the first physics tick. Without it the camera slides in from the top-left corner at every scene start.
  - **Teleports:** anything that moves a node instantly (respawn, blink) must call `reset_physics_interpolation()` on it, or it visibly slides to the new spot.
  - Measured with Godot's movie recorder, walking at full speed (on-screen shake of the player, screen px; 2 screen px = 1 game px): before 5.4 at 144 fps (the player moved on only 42% of frames); after 0.04 at 60, 75, 144, 165 and 240 fps. The world scrolls with about 0.2–0.9 px of unevenness, which is rounding to whole screen pixels. Keeping snapping on with interpolation left a 0.86 px shake at 144 fps.
  - Sprites can now sit half a game pixel off the tile grid. They stay sharp (nearest filtering; no blended colors in test captures).
  - Known limit: the screen shows each physics state up to one tick (≤16.7 ms) later than before.

### Feel pass intro (as planned)
Movement works but feels robotic: displacements run at constant speed and there's no on-screen feedback. Goal: closer to Hades. Dashes and knockback burst and then ease out, frames are smooth, and movement has visible weight. Every number here is a starting point and must be an `@export` or live in a .tres. Runs before step 8 (see Build order). For every F step, the Knight's 4 abilities, enemies chasing, and the HUD still work.

### Steps 1, 3–7: 2026-09-25, Built (awaiting play test)
1. **Built** (awaiting play test): input map + WASD walking, done together (after the input map alone the player had no walk input). PlayerInput, `set_input_direction()`, `use_steering = false` on the player, Knight 560 move speed, scaled soft cap exports, LoL threshold overrides on `slime.tscn`.
2. *(merged into step 1)*
3. **Built** (awaiting play test): facing and aim.
4. **Built** (awaiting play test): camera aim lead.
5. **Built** (awaiting play test): player states.
6. **Built** (awaiting play test): dash with charges, i-frames, end-lag and chaining.
7. **Built** (awaiting play test): input buffer, dash cancels (`Ability.dash_cancelable`), and the dash-strike hook.

## Stats (STATS.md)

### Step 6 – Scoped modifiers: 2026-09-26, Built (awaiting play test)
Scoped modifiers, `get_ability_param`, and `id`/`tags` on Ability. Route cooldowns through it. *(done: also `cast_range`, `base_damage`, `ad_ratio`; stats test 157/157 with a fake item (+30% Lunge range, −1.5 s Cleave cooldown, ×1.5 base damage on `area` abilities) that restores every param and stat exactly when removed; combat test 269/269 checks it on real casts)*

### Step 5 – ResourceComponent: 2026-09-25, Built (awaiting play test)
ResourceComponent, plus the new stat fields on UnitStats. *(done: neutral defaults; HealthComponent follows max_health and regens; ResourceComponent on the Knight only; tested in `stats_test.tscn`)*

### Step 4 – Migrate reads: 2026-09-25, Built (awaiting play test)
**Migrate reads.** *(done; checked headless against the old formulas for every Unit in the sandbox and room_01)* Every `stats.` read in the code before the migration:

| File | Reads | After step 4 |
|---|---|---|
| `units/unit.gd` `_ready()` | `max_health`, `move_speed` | `get_stat` |
| `units/unit.gd` `get_gameplay_radius_px()`, `get_pathing_radius_px()` | `gameplay_radius`, `pathing_radius` | stay on UnitStats (not stats) |
| `components/auto_attack_component.gd` `get_attack_speed()` | `base_attack_speed`, `attack_speed_cap` (+ its own `bonus_attack_speed`) | `get_stat(&"attack_speed")`; the cap is the stat's per-unit max |
| `components/auto_attack_component.gd` `get_windup_time()` | `attack_windup` | stays on UnitStats (not a stat) |
| `components/auto_attack_component.gd` `get_range_px()` | `attack_range` | `get_stat` |
| `components/auto_attack_component.gd` `_land_attack()` | `attack_damage` | `get_stat` |
| `components/ability_component.gd` `get_cooldown_duration()` | `ability_haste` | `get_stat` |
| `components/dash_component.gd` (max charges) | `dash_charges` | `get_stat` |
| `abilities/ability.gd` `get_damage()` | `attack_damage` | `get_stat` |
| `main.gd` `_process()` (HUD info line) | `player.stats.attack_damage`, `attack_range` | `get_stat` |

Also move MovementComponent's speed modifiers into StatsComponent (`add_speed_modifier` becomes a thin wrapper, so existing callers keep working). MovementComponent itself reads no `stats.` field; `Unit._ready()` calls `movement.set_stats_component()`, and MovementComponent reads `get_stat(&"move_speed")` live.

### Step 3 – StatsComponent on the scenes: 2026-09-25, Built (awaiting play test)
Add StatsComponent to player.tscn and slime.tscn. `Unit._ready()` wires it up. *(done: `Unit.stats_component`, a required child like HealthComponent)*

### Steps 1–2 – StatModifier, registry, StatsComponent: 2026-09-25, Built (awaiting play test)
1. StatModifier and the registry. *(done)*
2. StatsComponent with the math, move_speed rules, caching, and `stat_changed`. Include a test scene that adds/removes modifiers and prints the results. *(done: `res://scenes/tests/stats_test.tscn`, F6. It prints PASS/FAIL per check and includes move_speed parity checks against a real MovementComponent.)*

## World interaction (WORLD_INTERACTION.md)

No build steps of its own yet. `WorldQuery.has_line_of_sight()` was built with the melee target pull (Combat, Melee basic attacks) and used by every hit since Combat C7; stronger-knockback-wins was built in Combat C4.
