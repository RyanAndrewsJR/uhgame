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
scenes/player|enemies|rooms|ui/
scenes/sandbox_main.tscn  test run: main + rooms/sandbox.tscn (open it, press F6)
scenes/tests/           script-level test scenes (stats_test.tscn, combat_test.tscn; F6; scripts in scripts/tests/)
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
scripts/player|enemies|rooms|ui|vfx/
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
- `GameFeel` (`scripts/autoload/game_feel.gd`): `hitstop()`, `shake()`
- `Events` (`scripts/autoload/events.gd`): global signal bus. `unit_hit`, `unit_damaged`, `unit_died` (COMBAT.md)
- Planned: `WorldQuery` (docs/WORLD_INTERACTION.md; line of sight first, COMBAT C7)

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
| `docs/_TEMPLATE.md` | writing a new doc |

## Current status
<!-- OVERWRITE this whole section at the end of each session (Now / Last 3 done / Next). Never append. -->
- **Now:** Waiting on Ryan's play test of COMBAT C2 (left mouse = the Knight's 3-hit combo). Still open: play tests of STATS step 5, Feel pass F1–F4 at 144 Hz and movement steps 1 and 3–7, and the *(proposed)* items from the docs cleanup (pits (unscheduled), hazards, knockback, triggers, destructibles, kill credit, 3/4 depth, corner forgiveness).
- **Last 3 done:**
  1. COMBAT C2: the Knight's combo (`AttackSwing`, `AttackCombo`, `combo_knight.tres`, combo mode on AutoAttackComponent), rooted swings, dash / stun / ability (`Ability.cancels_swing`) cancels, the buffer waits out swings, Iron Resolve through swings, `select` unbound. Combat test 109/109, stats test 143/143, in-game check 15/15.
  2. COMBAT C1: `Events` autoload, `HitContext`, `HitPipeline`, `Unit.on_hit()`; `take_damage()` and Hurtbox hits wrapped; `damage_type` and `proc_coefficient` on Ability.
  3. COMBAT.md follow-ups: `incoming_damage` stat name, dash out of hit knockback, `cancels_swing` default AFTER_HIT, C8 ability migration, i-frame swarm question.
- **Next:** COMBAT C3 (hit feel) → C7 → milestone M1 (one-room fight in the sandbox) → STATS step 6 → COMBAT C8–C12. STATS step 7 (F3 overlay) after M1. Then the Future docs in their listed order.

## Known issues (leave for now)
- A Godot editor left open while Claude writes files keeps its old in-memory copies and can write them back (project settings, open scenes and scripts). Close Godot before Claude writes, or reopen it afterwards; if Godot says files are newer on disk, choose Reload.
- HUD ability bar labels the W slot "W" though it's on right mouse (the label comes from the slot name).
- Header comments in `game_camera.gd` ("Hold Space") and `player.gd` (right-click / A / S controls) describe the old keys.
- Lunge's afterimages (`VFX.afterimage`, `z_index` -1) draw under the floor tiles, so they never show.

## Decisions
All decisions, grouped by system with date and why, are in `docs/DECISIONS.md`.

## Future docs (write each one when you START that system)
1. ~~`COMBAT.md`~~: written 2026-09-26 (see Docs index).
2. `ABILITIES.md`: Ability framework, cooldowns, costs, recasts, augments (items changing ability behavior). Move the cast movement properties (`roots_during_cast`, `cast_move_speed_multiplier`, `cancel_on_move`, `dash_cancelable`) here from MOVEMENT.md, "Input buffering and cancels".
3. `CHAMPIONS.md`: ChampionData, passives, one section per champion (Knight first)
4. `LOOT.md`: item bases, rarities, affix pools, drop tables
5. `ENEMIES_AI.md`: behaviors, aggro, elites, spawning
6. `DUNGEONS.md`: room stitching, run structure
7. `NPCS.md`, `UI.md`, `PROGRESSION.md` as needed
