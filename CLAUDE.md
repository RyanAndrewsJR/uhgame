# CLAUDE.md: Project Root Brief
<!-- Read at the start of EVERY task. Keep it short (<150 lines). Only things true for every task go here.
     System details live in docs/. Overwrite "Current status" after each session. Decisions go in docs/DECISIONS.md. -->

## Where things are
```
uhgame/
  CLAUDE.md        # this file
  docs/            # one doc per system (see Docs index)
  game/            # the Godot project. res:// = uhgame/game/
```
All paths in the docs are `res://` paths inside `game/`, unless they start with `docs/`.

## The game
A 2D top-down action looter.
- **Champions** have distinct identities and kits, like League of Legends: a passive, several abilities, an ultimate.
- **Movement and combat** feel like Hades: instant, precise, dash-centric, with heavy input buffering.
- **Dungeons and loot** work like Diablo: runs through hand-made rooms stitched together, randomized gear with rarities and affixes that change how a build plays.

When a request is ambiguous, prioritize responsiveness and feel over realism.

## Tech facts
- **Godot 4.7.2**, GDScript, statically typed. Use Godot 4 APIs only. If you're unsure whether an API changed in 4.7, say so.
- 2D top-down 3/4 view. Pixel art: viewport **640×360** (window 1280×720, `canvas_items` stretch), nearest filtering, no transform snapping, 2D physics interpolation on, physics at 60 Hz.
- Tiles are **32 px**. Rooms use `TileMapLayer` with `res://tilesets/dungeon_tileset.tres`.
- Single-player.
- Pathing for AI uses `NavigationServer2D` (in `MovementComponent`).
- **Stat data is in League of Legends units.** `Units.to_px()` / `Units.to_units()` (`res://scripts/core/units.gd`, 0.32 px per unit) convert them. Example: 345 move speed = 110 px/s, 175 attack range = 56 px. Docs give both where it matters.

## Project layout (inside game/)
```
art/                    textures, sprites
data/abilities/         Ability .tres (e.g. knight_q_cleave.tres)
data/units/             UnitStats .tres per champion/monster (knight.tres, slime.tres)
data/curves/            Curve .tres for displacement speed profiles (curve_dash.tres, curve_knockback.tres)
data/combos/            AttackCombo .tres (combo_knight.tres: the Knight's basic attack)
data/hit_feels/         HitFeel .tres (hit_feel_default.tres: hitstop/shake/flash per hit tier)
data/damage_number_styles/  DamageNumberStyle .tres (damage_number_style_default.tres: number sizes, colors, motion)
data/sounds/            SoundEvent .tres (sound_<category>_<name>.tres; AUDIO.md)
data/audio_mixes/       AudioMix .tres (audio_mix_default.tres: voice cap, pause duck, log and debug sizes)
audio/                  audio files: sfx/ (WAV), music/ and ambience/ (OGG), LICENSES.md (CC0 placeholders only)
default_bus_layout.tres the audio buses: Master, Music, SFX, UI, Ambience, Voice
scenes/player|enemies|rooms|ui/
scenes/sandbox_main.tscn  test run: main + rooms/sandbox.tscn (open it, press F6)
scenes/tests/           script-level test scenes (stats_test.tscn, combat_test.tscn, audio_test.tscn, abilities_test.tscn; F6; scripts in scripts/tests/)
data/stats/             stat_registry.tres (every stat's limits and format)
scripts/abilities/      ability.gd (base), cast_context.gd, ability_util.gd
scripts/abilities/<champion>/   one script per ability (knight/cleave.gd ...)
scripts/autoload/       singletons
scripts/camera/         game_camera.gd
scripts/combat/         hit_context.gd, hit_pipeline.gd (COMBAT.md)
scripts/components/     Health, AutoAttack, Movement, Ability, Dash, Hitbox, Hurtbox
scripts/core/           units.gd (LoL units ↔ px)
scripts/data/           Resource class scripts (unit_stats.gd ...)
scripts/units/          unit.gd: shared base for Player and Enemy
scripts/player|enemies|rooms|ui|vfx|audio/   (audio/: combat_sounds.gd, AUDIO.md)
tilesets/
```
New subfolders inside these are fine. Ask before adding a new top-level folder.

## Architecture (as it exists)
- The reference build started as a LoL prototype: Knight with 4 abilities, slime enemies, room_01, HUD, auto-attacks, hitstop and shake.
- `Unit` (CharacterBody2D) is the shared base. `Player` and `Enemy` extend it. **Don't go deeper:** champions are data plus ability scripts, never subclasses of Player.
- Behavior lives in child components: `HealthComponent`, `AutoAttackComponent` (League-style attacks for enemies; combo mode for the Knight, COMBAT.md), `MovementComponent`, `AbilityComponent`, `DashComponent` (player), `Hitbox`, `Hurtbox`.
- `UnitStats` Resource = base stats. `Ability` Resource subclasses = one script per ability plus a .tres for its numbers.
- `MovementComponent` already has move locks by id, speed modifiers, `displace()`, and `dash()` (passes through units; both use `move_and_slide()`, so they slide along walls instead of stopping).
- `StatsComponent` (`Unit.stats_component`) holds every unit's live stats: base from `UnitStats` (`Unit.stats`) plus source-tagged `StatModifier`s. Gameplay reads `stats_component.get_stat(&"x")`, never `unit.stats.x` (STATS.md).

## Conventions
- **Data lives in Resources** (.tres); logic lives in scripts. Tuning never needs code edits. Every tunable is `@export`.
- **Signals go up, calls go down.** Cross-system events go through the `Events` autoload (reserved names only, CONVENTIONS.md).
- Gameplay motion happens in `_physics_process`. Physics interpolation is on, so a teleport (respawn, blink) must call `reset_physics_interpolation()` on the moved node.
- `snake_case` files and functions, `PascalCase` classes and nodes, `StringName` ids (`&"move_speed"`).
- Debug visuals sit behind an `@export var debug_draw: bool` (existing code uses `debug_draw_path` in MovementComponent; that's fine).

## Autoloads
- `GameFeel` (`scripts/autoload/game_feel.gd`): `hitstop()` (longest wins), `shake()`, `play_hit_feel(ctx)` (tiers from `hit_feel_default.tres`)
- `Events` (`scripts/autoload/events.gd`): global signal bus. `unit_hit`, `unit_damaged`, `unit_died` (COMBAT.md)
- `WorldQuery` (`scripts/autoload/world_query.gd`): spatial queries: `has_line_of_sight()`, used by every hit (docs/WORLD_INTERACTION.md, COMBAT C7), and `shape_sweep()` (projectiles, ABILITIES AB7)
- `Reactions` (`scripts/autoload/reactions.gd`): fires reaction rules on `unit_hit`, `unit_died`, `status_applied`; world rules from `data/reactions/world/`, unit rules via `Unit.add_reaction_rule()` (COMBAT C11)
- `Settings` (`scripts/autoload/settings.gd`): the player's own options, saved to `user://settings.cfg`; `setting_changed(key, value)`. Dash direction (MOVEMENT.md, Dash), cast mode (ABILITIES.md) and one volume per audio bus (AUDIO.md). Changed in the Esc pause menu (`PauseMenu`, `scenes/ui/pause_menu.tscn`).
- `Audio` (`scripts/autoload/audio.gd`, registered last): the one way to play sounds. `play()`, `play_at()`, `play_on()` return int handles; `stop()`, `stop_all_on()`, `stop_all()`; instance limits, the SFX voice cap, pause behavior, bus volumes from Settings, a log for tests, `debug_draw`. Its child `CombatSounds` plays hit, death and status sounds from Events (AUDIO.md)

## Change policy (important)
The game in `game/` is the **reference build**. It works, and changes build on it.
- **Additive by default.** Extend existing classes and components, and add new files. Don't rewrite working code.
- **Remove or replace only when existing code directly blocks what we're building.** Before doing it, tell me what and why, and wait for my OK.
- **Disable before deleting.** Unbind a key, or add a flag, rather than deleting code. Delete only after the replacement works and I confirm.
- **Don't rename** existing classes, files, input actions, or ability slots just for tidiness.
- After each change, existing features (Knight abilities, enemies chasing, HUD) must still work.
- The input map and the status of each LoL-era system (kept, dormant, replaced) are in docs/MOVEMENT.md, "Input and legacy systems".

## How to answer me
- Give complete files, or complete functions with clear placement. Never partial snippets with "..." in them.
- Only touch the files I name or the files the current build step lists. Ask before creating or editing others.
- For editor work (nodes, input actions, collision layers, TileSet data layers), give me exact click-by-click steps.
- Keep explanations short: what changed, why, and how to test it.
- If my request conflicts with a doc, or a doc conflicts with the code, say so instead of silently picking one.
- Follow the Change policy. If a step needs to remove or replace existing code, stop and ask first.
- Before naming anything new, check docs/CONVENTIONS.md (naming, vocabulary, reserved names). Don't invent synonyms.
- When a decision gets made, add it to docs/DECISIONS.md (date, decision, why) in the right system section. If it changes how a system works, update that system's doc too.
- After a build step, write its results (test counts, what was measured, what changed during the step) to docs/CHANGELOG.md, newest first, not to the system doc. The system doc gets one line ("C8 built 2026-09-26, see CHANGELOG.md"); any rule found while building goes into its spec.
- Before a build step, ask me to run `git status` and confirm the working tree is clean. If it isn't, tell me to commit first. After a step passes my play test, suggest a one-line commit message.

## Docs index (read only what the task needs)
| Doc | Read when the task involves |
|---|---|
| `docs/VISION.md` | designing a new system or doc, a design decision the docs don't cover, or a request that could be read more than one way |
| `docs/CONVENTIONS.md` | creating any new class, script, Resource, .tres, signal, autoload, tag, input action, or collision layer, or connecting two systems |
| `docs/DECISIONS.md` | before proposing changes to an existing design, or when asked why something works the way it does |
| `docs/MOVEMENT.md` | player movement, dash, input map, buffering, facing/aim, camera follow, LoL-era systems WASD replaced |
| `docs/WORLD_INTERACTION.md` | abilities touching the world, collision layers, tile tags, interactables |
| `docs/COMBAT.md` | basic attacks, hits and damage, damage types, crit and mitigation, status effects and CC, i-frames, hitstop/shake/flash, damage numbers, reaction rules, enemy attack damage and telegraphs |
| `docs/STATS.md` | any stat, health/mana, champion base stats, modifiers from gear/buffs/levels, items changing ability numbers |
| `docs/ABILITIES.md` | anything about abilities, casting, cast styles, charge-up, damage scalings, tooltips, ability tags, costs, cooldowns, charges, recasts, projectiles, augments, forms, empowers, conditions |
| `docs/AUDIO.md` | any sound, music, the mix, volume settings |
| `docs/CHANGELOG.md` | only when asked what was built or measured |
| `docs/_TEMPLATE.md` | writing a new doc |

## Current status
- **Now:** Waiting on Ryan's play test of the damage number cleanup (the unused pre-C6 path deleted: `Unit._spawn_damage_number()` and `damage_number.gd`'s `big`; numbers look exactly as before). Also waiting on AUDIO A3 (ability casts, Judgement's hit and ready ping, the elite's wind-up and slam, status sounds, the shield's break, the low-health heartbeat, the room cleared and "You died" stingers; all synthesized placeholders) and of "a swing counts once its hit has landed" and COMBAT C12. Still open: play tests of STATS steps 5–6, COMBAT C8–C11, Feel pass F1–F4 at 144 Hz and movement steps 1 and 3–7, and the *(proposed)* items from the docs cleanup (pits (unscheduled), hazards, knockback, triggers, destructibles, kill credit, 3/4 depth, corner forgiveness).
- **Last 3 done:**
  1. Cleanup: the pre-C6 damage number path deleted (`Unit._spawn_damage_number()`, `DamageNumber.big`). Abilities test 398/398, combat 449/450 (the known flaky hitstop check), stats 172/172, audio 109/109.
  2. ABILITIES docs: the VECTOR cast style planned as AB13; TOGGLE and SUSTAINED not planned.
  3. ABILITIES AB12 (passed Ryan's play test): conditions.
- **Next:** ABILITIES build order: AB13 (VECTOR cast style), then milestone AB-M (augment playground). AUDIO's later steps come with their systems; real CC0 files can replace the placeholders any time (same names). STATS step 7 (F3 overlay) whenever. Then the Future docs in their listed order (CHAMPIONS.md next).

## Known issues (leave for now)
- A Godot editor left open while Claude writes files keeps its old in-memory copies and can write them back (project settings, open scenes and scripts). Close Godot before Claude writes, or reopen it afterwards; if Godot says files are newer on disk, choose Reload.
- HUD ability bar labels the W slot "W" though it's on right mouse (the label comes from the slot name).
- Header comments in `game_camera.gd` ("Hold Space") and `player.gd` (right-click / A / S controls) describe the old keys.
- Lunge's afterimages (`VFX.afterimage`, `z_index` -1) draw under the floor tiles, so they never show.

## Decisions
All decisions, grouped by system with date and why, are in `docs/DECISIONS.md`.

## Future docs (write each one when you START that system)
1. ~~`COMBAT.md`~~: written 2026-09-26 (see Docs index).
2. ~~`ABILITIES.md`~~: written 2026-09-26 (see Docs index).
3. `CHAMPIONS.md`: ChampionData, passives, one section per champion (Knight first). Passives: stat modifiers, unit reaction rules, statuses, empowers and an optional script under a source id, built on the ABILITIES.md toolkit. Also decides the Knight's resource type, role tags, and Judgement's cast time and cooldown (ABILITIES.md, Numbers). Audio hooks: see AUDIO.md.
4. `LOOT.md`: item bases, rarities, affix pools, drop tables. Audio hooks: see AUDIO.md.
5. `ENEMIES_AI.md`: behaviors, aggro, elites, spawning
6. `DUNGEONS.md`: room stitching, run structure. Audio hooks: see AUDIO.md.
7. `NPCS.md`, `UI.md`, `PROGRESSION.md` as needed. `UI.md` takes over the Esc pause menu and the player options (`Settings`), now described in MOVEMENT.md (Dash) and DECISIONS.md (General). UI audio hooks: see AUDIO.md.
