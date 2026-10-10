# CLAUDE.md: Project Root Brief
<!-- Read at the start of EVERY task. Keep it short (<150 lines). Only things true for every task go here.
     System details live in docs/. Decisions go in docs/DECISIONS.md.
     Current status: at most 3,500 characters; overwrite it, do not append; history goes to CHANGELOG.md. Whole file: at most 28,000 characters. -->

## Where things are
```
uhgame/
  CLAUDE.md        # this file
  PROMPTS.md       # Ryan's prompt playbook (for Ryan; don't read it unless asked)
  docs/            # one doc per system (see Docs index)
  docs/champion_board/  # offline champion concepting page (a tool, not a doc); see its README
  game/            # the Godot project. res:// = uhgame/game/
```
All paths in the docs are `res://` paths inside `game/`, unless they start with `docs/`.

## The game
An action looter under a fixed-angle 3D camera (League/Diablo-style), played on a flat 2D sim underneath (docs/3D.md). Since the 3D pivot's milestone (P-M) the game shows in 3D; since its cleanup's C3 always (the flag, the 2D placeholder visuals and the 2D camera are deleted).
- **Champions** have distinct identities and kits, like League of Legends: a passive, several abilities, an ultimate.
- **Movement and combat** feel like Hades: instant, precise, dash-centric, with heavy input buffering.
- **Dungeons and loot** work like Diablo: runs through hand-made rooms stitched together, randomized gear with rarities and affixes that change how a build plays.

When a request is ambiguous, prioritize responsiveness and feel over realism.

## Tech facts
- **Godot 4.7.2**, GDScript, statically typed. Use Godot 4 APIs only. If you're unsure whether an API changed in 4.7, say so.
- **Sim and view (3D.md):** the gameplay world (the sim) is 2D, in px, and stays the source of truth; the 3D view (meters: **1 m = 32 px = 100 League units**) follows it and never changes gameplay state. The sim never reads height.
- Today's settings: viewport **640×360** (window 1280×720, `canvas_items` stretch, so 3D renders at the window's resolution), nearest filtering for the 2D placeholders, no transform snapping, physics interpolation on (2D and 3D), physics at 60 Hz. The art direction is hand-painted 3D at native resolution, with the UI designed for 1920×1080 (VISION.md); the UI change comes with UI.md.
- Tiles are **32 px** (1 m). Today's rooms are tile rooms (`TileMapLayer`, `res://tilesets/dungeon_tileset.tres`); new rooms are built in 3D as layouts whose footprints make the sim (3D.md, Rooms).
- Single-player.
- Pathing for AI uses `NavigationServer2D` (in `MovementComponent`; `AutoAttackComponent` also queries it).
- **Stat data is in League of Legends units.** `Units.to_px()` / `Units.to_units()` (`res://scripts/core/units.gd`, 0.32 px per unit) convert them. Example: 345 move speed = 110 px/s, 175 attack range = 56 px. Docs give both where it matters.

## Project layout (inside game/)
```
art/                    textures, sprites
data/abilities/         Ability .tres (e.g. knight_q_cleave.tres); enemy/: the enemy ability library's templates (ENEMIES_AI.md, Kits)
data/units/             UnitStats .tres per champion/monster (knight.tres, slime.tres)
data/champions/         ChampionData .tres per champion (knight.tres, from CH1; CHAMPIONS.md)
data/curves/            Curve .tres for displacement speed profiles (curve_dash.tres, curve_knockback.tres)
data/combos/            AttackCombo .tres (combo_knight.tres: the Knight's basic attack; combo_test_<enemy>.tres: a test enemy's string, ARCHETYPES AR1a)
data/hit_feels/         HitFeel .tres (hit_feel_default.tres: hitstop/shake/flash per hit tier)
data/damage_number_styles/  DamageNumberStyle .tres (damage_number_style_default.tres: number sizes, colors, motion)
data/sounds/            SoundEvent .tres (sound_<category>_<name>.tres; AUDIO.md)
data/audio_mixes/       AudioMix .tres (audio_mix_default.tres: voice cap, pause duck, log and debug sizes)
data/enemies/           EnemyData .tres per enemy (enemy_slime.tres, enemy_slime_elite.tres, enemy_test_brute.tres; ENEMIES_AI.md)
data/enemy_behaviors/   EnemyBehavior .tres per role (enemy_behavior_brute.tres: the twelve sliders)
data/enemy_ai_tables/   EnemyAITable (enemy_ai_table_default.tres: the ranks, respect, patience, the hold)
data/pose_sets/         PoseSet .tres (pose_set_default.tres: enemy tells' capsule looks)
data/sound_sheets/       SoundSheet .tres (sound_sheet_korsavil.tres: a champion's or enemy's sound triggers; AUDIO A6a)
audio/                  audio files: sfx/ (WAV), music/ and ambience/ (OGG), LICENSES.md (CC0 placeholders only)
default_bus_layout.tres the audio buses: Master, Music, SFX, UI, Ambience, Voice
scenes/player|enemies|rooms|ui/
scenes/sandbox_main.tscn  test run: main + rooms/sandbox.tscn (open it, press F6); in 3D since P-M; sandbox_main_layout.tscn: the sandbox built in 3D (P8, the Uppercut on W); main_layout.tscn: room_01's layout (the run since P-M)
scenes/ui/hub.tscn      the hub: the main scene (F5) since TALENTS T5; Start run (main_layout.tscn) / Sandbox (sandbox_main.tscn) / talents
scenes/tests/           script-level test scenes (stats_test.tscn, combat_test.tscn, audio_test.tscn, abilities_test.tscn, view_test.tscn, enemies_test.tscn...; F6; scripts in scripts/tests/)
data/stats/             stat_registry.tres (every stat's limits and format)
scripts/abilities/      ability.gd (base), cast_context.gd, ability_util.gd
scripts/abilities/<champion>/   one script per ability (knight/cleave.gd ...)
scripts/autoload/       singletons
scripts/camera/         game_camera_3d.gd (the 3D view's camera, 3D.md; the 2D game_camera.gd went in the cleanup's C3)
scripts/combat/         hit_context.gd, hit_pipeline.gd (COMBAT.md)
scripts/components/     Health, AutoAttack, Movement, Ability, Dash, Hitbox, Hurtbox
scripts/core/           units.gd (LoL units ↔ px)
scripts/data/           Resource class scripts (unit_stats.gd ...)
scripts/units/          unit.gd: shared base for Player and Enemy
scripts/player|enemies|rooms|ui|vfx|audio/   (audio/: combat_sounds.gd, AUDIO.md)
tilesets/
```
From the 3D pivot (3D.md): built, `scripts/view/` (P2), `data/camera_looks/` (P3), `scenes/view/`, `art/models/placeholder/` (stand-in models) and `CREDITS.md` (third-party art licences; P6), `scenes/rooms/assets/` (the room kit; P8), `scenes/world/` and `scripts/world/` (the perch; P9).
New subfolders inside these are fine. Ask before adding a new top-level folder.

## Architecture (as it exists)
- The reference build started as a LoL prototype: Knight with 4 abilities, slime enemies, room_01, HUD, auto-attacks, hitstop and shake.
- `Unit` (CharacterBody2D) is the shared base. `Player` and `Enemy` extend it. **Don't go deeper:** champions are data plus ability scripts, never subclasses of Player.
- Behavior lives in child components: `HealthComponent`, `AutoAttackComponent` (League-style attacks for enemies; combo mode for the Knight, COMBAT.md), `MovementComponent`, `AbilityComponent`, `DashComponent` (player), `Hitbox`, `Hurtbox`.
- `UnitStats` Resource = base stats. `Ability` Resource subclasses = one script per ability plus a .tres for its numbers.
- `MovementComponent` already has move locks by id, speed modifiers, `displace()`, and `dash()` (passes through units; both use `move_and_slide()`, so they slide along walls instead of stopping), and since LOOT L6 `leap()` (over everything, onto the nearest walkable floor of the room), and since ABILITIES AB15 `blink()` (at once, over walls unless the ability stops at them, by the same landing rule).
- **Enemy brains (details: ENEMIES_AI.md, Architecture / contracts):** an `Enemy` with `data` (an `EnemyData`) loads it when ready and is in a `Pack`; ranks above fodder get an `EnemyBrain` (a `UnitController` child; since R1 it spans `enemy_brain.gd` and six helpers in `scripts/enemies/`: `brain_scoring.gd`, `brain_strings.gd`, `brain_plans.gd`, `brain_duel.gd`, `brain_perception.gd`, `brain_drive.gd`) that thinks through the `Brains` autoload (a pure `decide()` on a `SituationContext`): respect, patience, attack tokens, duels and odds, combo plans (`ComboPlanner`), strings (`EnemyData.attack_string`, `AutoAttackComponent.run_string()`). An enemy with no data, or with its brain off (`brain_enabled`), plays the old routine and the naive cast loop (`naive_casting`).
- `StatsComponent` (`Unit.stats_component`) holds every unit's live stats: base from `UnitStats` (`Unit.stats`) plus source-tagged `StatModifier`s. Gameplay reads `stats_component.get_stat(&"x")`, never `unit.stats.x` (STATS.md).
- **The 3D view (3D.md; P2–P-M built; always on since the cleanup's C3, no 2D rollback):** the 2D sim stays and is hidden from the screen, with no looks of its own; `WorldView` (always under Main) shows it. Views follow their sim nodes on the physics tick (the `view_source` group), floor drawings come from `FloorOverlay`, numbers and bars from `ScreenOverlay` (a unit's `HealthBar` node is only the bar's settings), the aim from the floor pick. Tests never build the view (view_test does).

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
- `Settings` (`scripts/autoload/settings.gd`): the player's own options, saved to `user://settings.cfg` (read at the first use while a scene is current); `setting_changed(key, value)`. A scene under `res://scenes/tests/` never reads or writes the file. Dash direction (MOVEMENT.md, Dash), cast mode (ABILITIES.md) and one volume per audio bus (AUDIO.md). Changed in the Esc pause menu (`PauseMenu`, `scenes/ui/pause_menu.tscn`).
- `Progress` (`scripts/autoload/progress.gd`, before Audio): every champion's persistent progress (TALENTS.md): a `ChampionProgress` per champion (level, XP, ability uses, kills, unlocks, the talent loadout), counted from Events for the tracked Player, saved to `user://progress.cfg`; `champion_leveled_up`, `talent_unlocked`. A scene under `res://scenes/tests/` never reads or writes the save
- `Loot` (`scripts/autoload/loot.gd`, after Progress, before Audio): every champion's inventory (LOOT.md): a `ChampionInventory` per champion (items, the equipped set, the reserved materials bucket), saved to `user://inventory.cfg`; `track()` by the Player, which equips its saved gear at load (`EquipmentComponent`). Since LOOT L7, drops: a kill by the tracked player rolls the dead unit's drop table into `Pickup`s (layer 9) that the Player's `PickupComponent` collects on proximity (`collect()`, `item_picked_up`, the HUD's loot line); `take_ground_drops()` / `restore_ground_drops()`; since L7b the player can drop an item back on the ground or trash it (`drop_from_inventory()`, `trash_item()`). A scene under `res://scenes/tests/` never reads or writes the save, and its kills drop nothing unless a test sets `drops_enabled`
- `Brains` (`scripts/autoload/brains.gd`, after Loot, before Audio): the enemy brains' shared services (ENEMIES_AI.md, AI1–AI2): `table` (EnemyAITable), `rng` (seedable), the staggered think schedule (`register()`, `wake()`), the one shared read of the party per tick (`get_snapshot()`, `get_party()`), `difficulty_tier` (a stand-in until DUNGEONS D8), think stats for the budget; since AI2 the enemies with data (`register_enemy()`), attack tokens (`request_token()`, `release_token()`, the queue, the rest, releases each tick), the shout (`shout()`), the fodder ring around each target
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
| `docs/WORLD_INTERACTION.md` | abilities touching the world, collision layers, tile tags, interactables (and their puzzle element rules), hazards, pits and pit-drops, destructibles, kill credit |
| `docs/COMBAT.md` | basic attacks, hits and damage, damage types, crit and mitigation, status effects and CC, i-frames, hitstop/shake/flash, damage numbers, reaction rules, enemy attack damage and telegraphs |
| `docs/STATS.md` | any stat, health/mana, champion base stats, modifiers from gear/buffs/levels, items changing ability numbers |
| `docs/ABILITIES.md` | abilities: casting, cast styles, charge-up, scalings, tooltips, tags, costs, cooldowns, charges, recasts, projectiles, augments, forms, empowers, conditions, blinks; Korsavil's ability sheets and the toolkit pieces she needs; Korsavil v2's sheets and pieces |
| `docs/CHAMPIONS.md` | ChampionData, passives, resource rhythms (Fury, Energy), the champion level field, the Knight's kit and its functional HUD (CH6), Korsavil's kit (Blades, Inevitable Demise, Vanish, Umbral Stalker) and her build steps (v1); Korsavil v2 (2026-10-09: his chain, Demise stacks, Blade Singer, Cloak & Dagger, Spectral Assault, Reckoning) and its K3–K10 |
| `docs/AUDIO.md` | any sound, music, the mix, volume settings, how to add a sound, conditional sounds (variants, cues, a status's end reason), the audition tool, sound triggers (when, where and how a sound plays) and the tuning panel (A6) |
| `docs/TALENTS.md` | talents, unlock requirements (`TalentRequirement`), the loadout and talent points, ability-use and kill counters, the XP curve, the hub's talent screen, the kind-not-magnitude rule, the Knight's set |
| `docs/LOOT.md` | items, bases, affixes, rarities, sigils, named items, equipping (`EquipmentComponent`), the inventory, its save and the materials bucket, drop tables, depth and magic find, pickups (layer 9), dropping and trashing |
| `docs/COMPANIONS.md` | companions: species, quirks, passives, bond, evolutions, the command on Tab (the fifth slot), consuming and the imprint, eggs, kindling, the hub screen, `user://companions.cfg`; the exception to VISION's no-shared-power rule |
| `docs/ALLIES.md` | the AI ally, controllers (`UnitController`: player input, enemy brain, ally brain), teams and smart cast, how enemies pick between champions (`threat`, taunt, stealth), downed and revive, party scaling, `get_ai_plan()`, stances |
| `docs/DUNGEONS.md` | dungeons and wings (a wing is a run), spaces, checkpoints, content slots and the shuffle, packs and arenas, bosses, puzzles, secrets, collectibles, quests, the codex, the map, difficulty tiers, the champion lens, the dungeon save |
| `docs/ENEMIES_AI.md` | enemy brains (intents, respect, patience), ranks and archetypes (formerly roles), kits (`ai_uses`), tokens, packs, dodging, tells, elites, the boss director, spawning, scaling, `EnemyData`, performance, the tuning toolkit, duels, combos, the Vampyr Shade (AI-V1–AI-V3) |
| `docs/ARCHETYPES.md` | archetypes shared by champions and enemies (Assassin, Mage, Skirmisher, Bruiser, Duelist; Basic) and rank × archetype; deflect and poise; enemy strings and the beat; perilous attacks; duel pressure; weak basic attacks; AR1–AR8 |
| `docs/3D.md` | what the player sees in 3D: sim/view, px ↔ m, the camera (`CameraLook`), models, views, rooms built in 3D (`RoomLayout`, `Footprint`, `SimMarker`), `FloorOverlay`, `ScreenOverlay`, aim, terrain, ledges, airborne, leaps, perches |
| `docs/3D_PIVOT.md` | only when asked how the 3D choice was made: the 2D baseline and inventory, the A1/A2 costing, the spikes' plans and results, the interview |
| `docs/CHANGELOG.md` | only when asked what was built or measured |
| `docs/_TEMPLATE.md` | writing a new doc |

## Current status
- **Now:**
  - The Knight ships; CHAMPIONS, TALENTS, LOOT, STATS and the 3D pivot (up to the P-spike) are done.
  - **Korsavil is redesigned (v2, Ryan's board, 2026-10-09; docs only):** K1–K2 passed; v2's K3–K10 replace the old K3–K6 (Ryan confirmed it before K3, 2026-10-09; CHAMPIONS.md, Korsavil v2). **K3–K5b passed; K5c (the empowered finisher, his sound sheet's step 2) built 2026-10-10, awaiting Ryan's play test** (4,525/4,525).
  - ENEMIES_AI: AI1–AI3, AI3b–AI3d and AI-D1–AI-D3 passed; R0 and R1 committed (4,095/4,095).
  - ARCHETYPES: AR1a–AR4 passed and committed (the test duelist at 1.89×, short of 2×: Open questions 20).
  - FEEL2: preset 3 shipped and passed (c2efc46). Sandbox-only, Ryan's read pending: F9 latency probe, F10 blind presets, F7 threat palettes, the N panel's "pose lean x" (CHANGELOG.md).
  - The Knight's deflect/poise prototype (flags off in shipped config; sandbox V, Shift+V, M) and the TEMP enemy attack speed multiplier **await his play test**; the TEMP weak-auto lever is off since AR4 and goes on his OK.
- **Last 3 done:**
  1. AUDIO A6a and its follow-up (2026-10-10, passed): sound triggers (`SoundSheet`), Korsavil's sheet, Demise 4 at the empowered swing's start.
  2. K5b (2026-10-10, passed): Q's 0.5 s recast and 0.6 s sweep wind-ups; the Demise and sweep sounds.
  3. K5 (2026-10-10, passed): Q's 6-stack sweep.
- **Next** (ARCHETYPES.md, Open questions 15, with Ryan's changes):
  1. Korsavil v2's K6–K9 (CHAMPIONS.md, Build order, Korsavil v2): K6 (W Cloak & Dagger) next.
  2. AR5 (his Assassin layer) and AR6, then K10 and K-M *(proposed)*.
  3. The Vampyr Shade, AI-V1–AI-V3 (ENEMIES_AI.md; Ryan: after K-M), then AR7, AR8 and AR-M (the duel).
  4. DUNGEONS' slice (D0–D9, D-M): AI7 before D1, AI5 before D3, AI6 before D4, AI-M after AI7 (no dodging).
  5. AI4 (dodging) and AI8 (the later roles); then the Future docs.
- **Pending** (each lives in the doc named):
  - Ryan's OK on AI-D1–AI-D3's names; Claude's other open proposals (ENEMIES_AI, COMPANIONS, DUNGEONS, CHAMPIONS).
  - COMBAT C8's play test, crits and on-hit (CHANGELOG.md).
  - Clearing `player.tscn`'s old exports, on Ryan's OK (CHAMPIONS.md, Loading a champion).
  - Corner forgiveness, proposed (MOVEMENT.md); the pit step, unscheduled (WORLD_INTERACTION.md).
  - DUNGEONS D1 waits for the P-spike and WORLD_INTERACTION's unscheduled pieces; AI-D4 for ALLIES AL6.
  - AUDIO A4 and A5: approved, not started; CC0 files can replace the placeholders any time (AUDIO.md).
  - AUDIO A6a and its follow-up passed (6385fc4, 8385b3f); Korsavil's sheet step 2 built in K5c; next A6b (the panel: needs his concern 4, the Save guards).
  - COMPANIONS CO1: any time, on Ryan's OK.
  - ALLIES' second champion (ranged/support, mana): still planned (ALLIES.md, Status).
  - Ryan's pre-L-M saves: `%APPDATA%/Godot/app_userdata/uhgame/backups/` (the 10:22 copy).
- **Open judgment call (revisit at AI-M, not before):** do the Knight's low-health rewards (Unbroken, Cleave's heal, Judgement's payoff) feel like real risk or too safe? Ryan after CH-M: a mix; the sandbox can't stress it. Don't tune it until real enemy content exists.

## Known issues (leave for now)
- A Godot editor left open while Claude writes files keeps its old in-memory copies and can write them back (project settings, open scenes and scripts). Close Godot before Claude writes, or reopen it afterwards; if Godot says files are newer on disk, choose Reload.
- HUD ability bar labels the W slot "W" though it's on right mouse (the label comes from the slot name).

## Decisions
All decisions, grouped by system with date and why, are in `docs/DECISIONS.md`.

## Future docs (write each one when you START that system)
Written (see Docs index): COMBAT, ABILITIES, CHAMPIONS, TALENTS, LOOT, COMPANIONS, ENEMIES_AI, DUNGEONS. Still to write:
- `NARRATIVE.md` (with `NPCS.md`): story and lore and how they're told, the champion lens, story depth and voice scope (VISION.md, Pillar 5).
- `PROGRESSION.md`: account meta-progression (VISION.md, Meta-progression) and the one save (`companions.cfg` and `dungeons.cfg` fold into it). It or NARRATIVE/NPCS first: Ryan's pick. Both have notes waiting in COMPANIONS.md and DUNGEONS.md (For other docs).
- `UI.md`, as needed: the pause menu and `Settings`, the 1920×1080 UI, `ScreenOverlay`, a 3D paper-doll preview (3D_PIVOT.md, Doc edits needed), and the screens LOOT, COMPANIONS, DUNGEONS and AUDIO (UI sounds) leave to it.
- `ACHIEVEMENTS.md`: cross-system achievements and accolades, last, much later; nothing designed or built for it now.
