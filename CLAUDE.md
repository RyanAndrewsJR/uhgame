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
An action looter under a fixed-angle 3D camera (League/Diablo-style), played on a flat 2D sim underneath (docs/3D.md). Today the screen still shows the 2D placeholder game; the 3D view is being built behind a flag (3D pivot P2–P-M).
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
scenes/sandbox_main.tscn  test run: main + rooms/sandbox.tscn (open it, press F6); sandbox_main_3d.tscn: the same with the 3D view on
scenes/ui/hub.tscn      the hub: the main scene (F5) since TALENTS T5; Start run / Sandbox / talents
scenes/tests/           script-level test scenes (stats_test.tscn, combat_test.tscn, audio_test.tscn, abilities_test.tscn, view_test.tscn; F6; scripts in scripts/tests/)
data/stats/             stat_registry.tres (every stat's limits and format)
scripts/abilities/      ability.gd (base), cast_context.gd, ability_util.gd
scripts/abilities/<champion>/   one script per ability (knight/cleave.gd ...)
scripts/autoload/       singletons
scripts/camera/         game_camera.gd; game_camera_3d.gd (the 3D view's camera, 3D.md)
scripts/combat/         hit_context.gd, hit_pipeline.gd (COMBAT.md)
scripts/components/     Health, AutoAttack, Movement, Ability, Dash, Hitbox, Hurtbox
scripts/core/           units.gd (LoL units ↔ px)
scripts/data/           Resource class scripts (unit_stats.gd ...)
scripts/units/          unit.gd: shared base for Player and Enemy
scripts/player|enemies|rooms|ui|vfx|audio/   (audio/: combat_sounds.gd, AUDIO.md)
tilesets/
```
From the 3D pivot (3D.md): built, `scripts/view/` (P2) and `data/camera_looks/` (P3); planned, `scenes/view/`, `scenes/rooms/assets/`, `art/models/placeholder/` and `CREDITS.md` (third-party art licences).
New subfolders inside these are fine. Ask before adding a new top-level folder.

## Architecture (as it exists)
- The reference build started as a LoL prototype: Knight with 4 abilities, slime enemies, room_01, HUD, auto-attacks, hitstop and shake.
- `Unit` (CharacterBody2D) is the shared base. `Player` and `Enemy` extend it. **Don't go deeper:** champions are data plus ability scripts, never subclasses of Player.
- Behavior lives in child components: `HealthComponent`, `AutoAttackComponent` (League-style attacks for enemies; combo mode for the Knight, COMBAT.md), `MovementComponent`, `AbilityComponent`, `DashComponent` (player), `Hitbox`, `Hurtbox`.
- `UnitStats` Resource = base stats. `Ability` Resource subclasses = one script per ability plus a .tres for its numbers.
- `MovementComponent` already has move locks by id, speed modifiers, `displace()`, and `dash()` (passes through units; both use `move_and_slide()`, so they slide along walls instead of stopping).
- `StatsComponent` (`Unit.stats_component`) holds every unit's live stats: base from `UnitStats` (`Unit.stats`) plus source-tagged `StatModifier`s. Gameplay reads `stats_component.get_stat(&"x")`, never `unit.stats.x` (STATS.md).
- **The 3D view (3D.md; P2–P4 built behind the flag, the rest planned):** the 2D sim stays and is hidden from the screen; `WorldView` (under Main, behind `Main.use_3d_view`) shows it. Views follow their sim nodes on the physics tick (the `view_source` group), floor drawings come from `FloorOverlay`, the aim from the floor pick. Tests never build the view.

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
| `docs/LOOT.md` | items, item bases, affixes, rarities, sigils (the Unique/Exotic effects), the Knight's legendaries and artifact, equipping (`EquipmentComponent`), the inventory and its save (and the reserved materials bucket), drop tables, depth and magic find, pickups (layer 9), the sandbox loot list |
| `docs/3D.md` | anything the player sees in 3D: the sim/view split and the px ↔ m mapping, the camera (`CameraLook`), models and animation, views (`WorldView`, `EntityView`, `UnitView`), building rooms in 3D (`RoomLayout`, `Footprint`, `SimMarker`, the validator), floor drawings (`FloorOverlay`), damage numbers and bars (`ScreenOverlay`), the floor pick and aim, terrain height, ledges, knock-ups (airborne), perches (`elevated`), the 3D build order P2–P-M |
| `docs/3D_PIVOT.md` | only when asked how the 3D choice was made: the 2D baseline and inventory, the A1/A2 costing, the spikes' plans and results, the interview |
| `docs/CHANGELOG.md` | only when asked what was built or measured |
| `docs/_TEMPLATE.md` | writing a new doc |

## Current status
- **Now:** CHAMPIONS is done: CH1–CH6, CH5b and milestone CH-M passed (2026-09-30); the Knight ships. TALENTS.md is written (2026-09-30): the model, requirements, curve, hub screen, the kind-not-magnitude authoring rule and the Knight's 20 talents are decided; Ryan answered its proposals 2026-09-30; every proposal and name is approved. T1–T5 passed (with T3b; T5 2026-10-01, the hub is the main scene); next the milestone T-M (a Knight's talent career, Ryan's play test). `player.tscn`'s old exports can be cleared when Ryan OKs it (CHAMPIONS.md, Loading a champion). Play tests closed 2026-09-30: the audit cleanup pass, Feel pass F1–F4 at 144 Hz, AUDIO A3, AB13, "a swing counts once its hit has landed", COMBAT C9–C12, STATS steps 5–6. Still open: the play test of COMBAT C8 (crits and on-hit; not in the 2026-09-30 round), and corner forgiveness (MOVEMENT.md, proposed). The docs-cleanup world items (pits, hazards, knockback, triggers, destructibles, kill credit, 3/4 depth) were approved 2026-09-30; pits still need a place in a build order.
- **Open judgment call (revisit with ENEMIES_AI.md, not before):** whether the Knight's low-health rewards stacking (Unbroken's attack damage, Cleave's heal, Judgement's easier payoff) feel like real risk or too safe. Ryan's read after CH-M: a mix, depending on the fight; the sandbox's enemies (two slimes, one telegraphed elite) can't stress it. Don't tune it until real enemy content exists.
- **3D pivot (3D_PIVOT.md, 2026-10-01):** A1 chosen (the 2D sim stays, hidden; a 3D view follows it); Ryan answered the interview. "Before P0" (test isolation) passed: the baseline is 1,788/1,788. **P0a passed: GO** (spike on branch `spike/3d-p0a`, never merged). Ryan's screen is 180 Hz (frame budget 5.6 ms), not 144. **P0b passed (2026-10-02):** perspective with a 30° field of view, 50° pitch, 28 m wide; tall things fade; smooth turning; walls become 3D assets of variable height, some fading; the material (painted vs PBR) stays open until the art pass. **P1 (2026-10-02):** `docs/3D.md` written and approved by Ryan with his additions; rooms are built in 3D (Q7 changed); the doc edits applied (committed 2026-10-02). **P2 passed (2026-10-02):** the px ↔ m mapping in `Units`, an empty `WorldView` with the floor pick, `Main.use_3d_view` (off), `view_test`; the baseline is now 1,816/1,816 (7 suites). **P3 passed (2026-10-02):** the tile room's 3D look (`RoomView`), the key light and shadows, the fade, the 2D world hidden, `CameraLook`, stand-ins for the camera and units until P4 and P6, played from `scenes/sandbox_main_3d.tscn`; the baseline is now 1,867/1,867. **P4 built (2026-10-02), awaiting Ryan's check:** `GameCamera3D` and the listener, bounds keeping the focus on the room's floor, sounds scaled with the view; the baseline is now 1,897/1,897.
- **Last 3 done:**
  1. 3D pivot P4 (built 2026-10-02, awaiting Ryan's check): `GameCamera3D` (the CameraLook; GameCamera's lock, lean, centering, pan, shake and smoothing read from Main's GameCamera; bounds keep the focus on the room's floor) and its AudioListener2D (`Audio.distance_scale` 1.4 while it's on); `view_test` 109 checks; 1,897/1,897.
  2. 3D pivot P3 (passed 2026-10-02): `RoomView` (a floor and a fading box per wall cell, the environment, the key light with shadows), the dithered fade, the 2D world hidden (visibility layer 2), `CameraLook`, the stand-in camera and capsules, `sandbox_main_3d.tscn`; `view_test` 79 checks; 1,867/1,867.
  3. 3D pivot P2 (passed 2026-10-02): the px ↔ m mapping in `Units`, an empty `WorldView` with the two-ray floor pick (`pick_floor()`), `Main.use_3d_view` (off), `view_test` (28 checks); 1,816/1,816.
- **Next:** Ryan's check of 3D pivot P4 (`scenes/sandbox_main_3d.tscn`, F6; the camera checklist in MOVEMENT.md, Architecture 4, and sounds), then P5 (aim) on his OK. Until P5, aiming with the 3D view on reads the mouse through the 2D camera (a dash or Lunge toward a wall at the room's edge can go the opposite way). TALENTS milestone T-M (Ryan's play test) is still open: Ryan's interview answer (Q12) put it first, then he started P0a. AUDIO's later steps come with their systems; real CC0 files can replace the placeholders any time (same names). STATS step 7 (F3 overlay) whenever. LOOT.md is written and its proposals answered (2026-10-01); L1 (items: data and rolling) starts on Ryan's OK. Then the Future docs in their listed order (ENEMIES_AI.md next).

## Known issues (leave for now)
- A Godot editor left open while Claude writes files keeps its old in-memory copies and can write them back (project settings, open scenes and scripts). Close Godot before Claude writes, or reopen it afterwards; if Godot says files are newer on disk, choose Reload.
- HUD ability bar labels the W slot "W" though it's on right mouse (the label comes from the slot name).

## Decisions
All decisions, grouped by system with date and why, are in `docs/DECISIONS.md`.

## Future docs (write each one when you START that system)
1. ~~`COMBAT.md`~~: written 2026-09-26 (see Docs index).
2. ~~`ABILITIES.md`~~: written 2026-09-26 (see Docs index).
3. ~~`CHAMPIONS.md`~~: written 2026-09-29 (see Docs index).
4. ~~`TALENTS.md`~~: written 2026-09-30 (see Docs index); the Knight's set and the proposals are approved; T1–T5 passed (T5 2026-10-01).
5. ~~`LOOT.md`~~: written 2026-10-01 (see Docs index) from Ryan's spec; every proposal answered by Ryan 2026-10-01 (Exotic = a second sigil, Artifact affixes always at max, the word "sigil"); build steps L1–L7 and milestone L-M approved, not started.
6. `ENEMIES_AI.md`: behaviors, aggro, elites, spawning. Once harder enemies exist, revisit the Knight's low-health reward stacking (Current status, Open judgment call). From the 3D pivot (3D.md): elevated archers and snipers (perches, dead zones, target choice through `AbilityUtil.can_reach()`); "no unanswerable enemy" as a design check; `Sight` stays on layer 1, so ledges don't block it; ledges split the navmesh into islands (a perched unit with no route holds or repositions); the enemy sim's cost (50 extra slimes take 10–12 ms of physics step today, P0a), so steering and pathing need a budget.
7. `DUNGEONS.md`: room stitching, run structure, checkpoints (placement; whether cleared enemies come back on respawn). Rooms are built in 3D as layouts (3D.md, Rooms); overlapping floors are separate rooms joined by stairs or doors. Audio hooks: see AUDIO.md.
8. `NARRATIVE.md` (written with `NPCS.md`): each dungeon's story and lore, how it's told (codex, hub NPC dialogue, voiced scenes, environmental storytelling), the champion lens, story depth and voice scope (VISION.md, Pillar 5). `PROGRESSION.md`: account-level meta-progression (VISION.md, Meta-progression: no power shared between champions) and the one save the other docs point to. Their order with DUNGEONS.md: Ryan's pick (interview order proposed 2026-10-02). `UI.md` as needed: it takes over the Esc pause menu and the player options (`Settings`), now described in MOVEMENT.md (Dash) and DECISIONS.md (General); from the 3D pivot, the UI designed for 1920×1080, the screen overlay's numbers and bars (`ScreenOverlay`, 3D.md), and a 3D paper-doll preview (the champion's model in its own SubViewport and 3D world, at the hub and in the inventory). UI audio hooks: see AUDIO.md.
9. `ACHIEVEMENTS.md`: cross-system achievements and accolades. Written much later, once most other systems exist; nothing is designed or built for it now.
