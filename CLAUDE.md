# CLAUDE.md: Project Root Brief
<!-- Read at the start of EVERY task. Keep it short (<150 lines). Only things true for every task go here.
     System details live in docs/. Overwrite "Current status" after each session. Decisions go in docs/DECISIONS.md. -->

## Where things are
```
uhgame/
  CLAUDE.md        # this file
  PROMPTS.md       # Ryan's prompt playbook (for Ryan; don't read it unless asked)
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
data/champions/         ChampionData .tres per champion (knight.tres, from CH1; CHAMPIONS.md)
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
- The input map and the status of each LoL-era system (kept, replaced, deleted) are in docs/MOVEMENT.md, "Input and legacy systems".

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
| `docs/CHAMPIONS.md` | ChampionData, passives, a champion's resource rhythm (fury), the champion level field, the Knight's kit (Unbroken, Fury, Staggered, Cleave's heal, Judgement's payoff), the kit's functional HUD (CH6: passive slot, Fury threshold tick, live-bonus outline) |
| `docs/AUDIO.md` | any sound, music, the mix, volume settings |
| `docs/TALENTS.md` | talents, unlock requirements (`TalentRequirement`), the loadout and talent points, ability-use and kill counters, the champion level XP curve, the hub's talent screen, writing talent content (the kind-not-magnitude rule), the Knight's talent set |
| `docs/CHANGELOG.md` | only when asked what was built or measured |
| `docs/_TEMPLATE.md` | writing a new doc |

## Current status
- **Now:** CHAMPIONS is done: CH1–CH6, CH5b and milestone CH-M passed (2026-09-30); the Knight ships. TALENTS.md is written (2026-09-30): the model, requirements, curve, hub screen, the kind-not-magnitude authoring rule and the Knight's 20 talents are decided; Ryan answered its proposals 2026-09-30; every proposal and name is approved. T1 passed; T2 built (awaiting play test); next T3. `player.tscn`'s old exports can be cleared when Ryan OKs it (CHAMPIONS.md, Loading a champion). Play tests closed 2026-09-30: the audit cleanup pass, Feel pass F1–F4 at 144 Hz, AUDIO A3, AB13, "a swing counts once its hit has landed", COMBAT C9–C12, STATS steps 5–6. Still open: the play test of COMBAT C8 (crits and on-hit; not in the 2026-09-30 round), and corner forgiveness (MOVEMENT.md, proposed). The docs-cleanup world items (pits, hazards, knockback, triggers, destructibles, kill credit, 3/4 depth) were approved 2026-09-30; pits still need a place in a build order.
- **Open judgment call (revisit with ENEMIES_AI.md, not before):** whether the Knight's low-health rewards stacking (Unbroken's attack damage, Cleave's heal, Judgement's easier payoff) feel like real risk or too safe. Ryan's read after CH-M: a mix, depending on the fight; the sandbox's enemies (two slimes, one telegraphed elite) can't stress it. Don't tune it until real enemy content exists.
- **Last 3 done:**
  1. TALENTS T2 (built, awaiting play test): the Knight's first 14 talents (all tier 1, plus Twin Lunge, Executioner, Battle Trance, Stalwart) in `data/talents/`, listed in `knight.tres`; try them with SandboxTalents (G / T). Talents test 155/155.
  2. TALENTS T1 (passed): `ToolkitBundle` (Passive's bundle, shared with `Talent`), `Talent`, `TalentRequirement`, validation, the loadout attached at load (`Player.talent_loadout` until T4), PASSIVE replace-and-add with the passive slot's lines, `SandboxTalents` (G / T). Talents test 70/70.
  3. CHAMPIONS milestone CH-M passed: the Knight's whole kit in the sandbox; its numbers are no longer placeholders.
- **Next:** TALENTS T1–T5 and milestone T-M (TALENTS.md, Build order), T1 passed, T2 built; next T3 (the six FLAG talents). AUDIO's later steps come with their systems; real CC0 files can replace the placeholders any time (same names). STATS step 7 (F3 overlay) whenever. Then the Future docs in their listed order (LOOT.md next).

## Known issues (leave for now)
- A Godot editor left open while Claude writes files keeps its old in-memory copies and can write them back (project settings, open scenes and scripts). Close Godot before Claude writes, or reopen it afterwards; if Godot says files are newer on disk, choose Reload.
- HUD ability bar labels the W slot "W" though it's on right mouse (the label comes from the slot name).

## Decisions
All decisions, grouped by system with date and why, are in `docs/DECISIONS.md`.

## Future docs (write each one when you START that system)
1. ~~`COMBAT.md`~~: written 2026-09-26 (see Docs index).
2. ~~`ABILITIES.md`~~: written 2026-09-26 (see Docs index).
3. ~~`CHAMPIONS.md`~~: written 2026-09-29 (see Docs index).
4. ~~`TALENTS.md`~~: written 2026-09-30 (see Docs index); the Knight's set and the proposals are approved T1 passed and T2 built 2026-09-30.
5. `LOOT.md`: item bases, rarities, affix pools, drop tables. Audio hooks: see AUDIO.md.
6. `ENEMIES_AI.md`: behaviors, aggro, elites, spawning. Once harder enemies exist, revisit the Knight's low-health reward stacking (Current status, Open judgment call).
7. `DUNGEONS.md`: room stitching, run structure, checkpoints (placement; whether cleared enemies come back on respawn). Audio hooks: see AUDIO.md.
8. `NPCS.md`, `UI.md`, `PROGRESSION.md` as needed. `UI.md` takes over the Esc pause menu and the player options (`Settings`), now described in MOVEMENT.md (Dash) and DECISIONS.md (General). UI audio hooks: see AUDIO.md.
9. `ACHIEVEMENTS.md`: cross-system achievements and accolades. Written much later, once most other systems exist; nothing is designed or built for it now.
