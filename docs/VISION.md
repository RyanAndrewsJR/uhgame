# VISION.md: What We're Making and Why

**Read when:** designing a new system or doc, making a design decision the docs don't cover, or when a request could be read more than one way.
**Not for:** technical rules (CLAUDE.md), naming (CONVENTIONS.md), or system specs (their own docs).
Items marked *(assumed)* are my best reading of the goals. Ryan should confirm or correct them.

## One sentence
A 3d stylized top down action looter where you pick a champion with a League-style kit, move and fight with Hades-level precision, and dive through Diablo-style dungeons collecting gear that changes *how your abilities play*, not just how big the numbers are. Gameplay requires tactical and methodical decision making in combat.

## Player fantasy
"I'm a skilled fighter with a distinct kit. I win through execution: dodging, aiming, comboing, and using the room itself as a weapon. Every run my gear pushes that kit in a new direction."

## The six pillars
Every system should serve at least one pillar and must not undermine another.

### 1. Skill and ability expression
The outcome depends on **player execution**, not just stats.
- Abilities are mostly aimed (skillshots, directional, placed), not auto-targeted.
- Timing matters: dash i-frames, cancel windows, input buffering, and precise windups.
- Abilities combine with each other and with the world (knock an enemy into a wall, pull one into a hazard).
- Enemies telegraph attacks clearly, so a good player can read and avoid them.
- The skill ceiling comes from mastering a kit, not from grinding stats.
- **"Tactical and methodical"** (One sentence; Ryan, 2026-10-02) means readable and decision-heavy: reading telegraphs, managing spacing, choosing when to spend a cooldown and where to stand. It does **not** mean slower movement: fast movement and the dash stay (pillars 3 and 4).
- (Details: ABILITIES.md, COMBAT.md.)

### 2. Build variety
The same champion should play very differently from build to build.
- Gear changes numbers (stat modifiers) **and** behavior (augments that alter abilities). See STATS.md.
- Scoped modifiers reward focusing on one ability or tag (e.g. "projectile" builds, "movement" builds).
- Several viable builds per champion. No single right answer. *(assumed)*
- Champions have different resource types (mana, energy, fury, none), and those change the play rhythm.
- **Ability slots are fixed** (decided 2026-09-29): a champion's abilities stay in their slots (Cleave is always Q). The player never reassigns which ability sits in which slot. Build variety comes from **talents** (per champion, set at the hub) and **item augments** (ABILITIES.md) reshaping the existing abilities. Augments a source applies (a REPLACE, a form) still work as ABILITIES.md describes; they're part of a build, not a player's slot choice.

### 3. Fluid movement
Hades-level responsiveness is the foundation. If movement feels bad, nothing else matters.
- Near-instant acceleration and stopping, dash-centric, heavy input buffering. (Numbers: MOVEMENT.md.)
- Movement abilities (dashes, blinks, grapples, swings) are core to champion identity, not just utility.

### 4. Fluid combat
Attacks feel weighty and immediate: hitstop, screen shake, knockback, clear feedback.
- Attacks and abilities flow into each other, and dash cancels keep the player in control.
- CC (stun, slow, knockback) is a tool the player uses, and a threat they avoid.
- (Details: COMBAT.md.)

### 5. Dungeon crawling
Runs through dungeons built from hand-made rooms stitched together.
- Rooms are designed spaces with walls, pits, and hazards to use tactically, not empty arenas.
- **A dungeon has 1–3 wings, and a wing is a run** (Ryan, 2026-10-03; DUNGEONS.md). Each wing has its own theme, quests, codex entries and boss. A wing is dense and hand-built: about 40–60 distinct spaces and 45–90 minutes of play, with floors up and down, caverns, pits, elevated sections, secrets, puzzles and collectibles. Its scale comes from height, long sightlines and backdrops, not from area.
- **Fixed layouts, shuffled contents:** the spaces are the same every run; which packs, elites, mini-bosses and optional events stand in them, the elites' modifiers, where chests stand and what they roll change each run, and higher difficulty tiers widen what can appear.
- ~~A run is one dungeon~~ (superseded 2026-10-03: a run is one wing). A run is played by a solo player as one champion, with an optional AI ally: another champion of the roster fighting beside them (see Game structure; ALLIES.md).
- Most of a wing is roaming packs that notice you as you come close (Diablo); a few set-piece arenas seal until cleared (Hades), bosses among them. Checkpoints are found in the wing and double as fast travel.
- each dungeon has its own deep story line and lore
  - Told through a codex, hub NPC dialogue, voiced scenes and environmental storytelling (the art itself).
  - The story can change with the champion played: shared core beats plus a champion lens, so content cost stays bounded. The same layout, enemies and main quests for everyone; codex entries, NPC dialogue and some scenes change per champion, and each champion has one short quest line of its own per wing (DUNGEONS.md).
  - How deep each story goes and how much of it is voiced: NARRATIVE.md (not written yet).
  - Codex entries unlock on find, for the whole account (a champion's own variant when that champion finds it), and no story beat ever blocks the main path (Ryan, 2026-10-03; DUNGEONS.md).
- ~~Difficulty and rewards increase with depth. *(assumed)*~~ Superseded 2026-10-03: each wing has **difficulty tiers**, unlocked by clears, raising enemy health and damage, adding elite modifiers and attack patterns and improving loot, with wing-wide modifiers at the top (DUNGEONS.md). *(proposed there)* Loot also improves deeper into a wing.
- A wing **recommends** some kits with real content (dark rooms reward a light-based champion), but it's never required: every champion can clear every wing.
- (Details: DUNGEONS.md, written 2026-10-03.)

### 6. Looting
Diablo-style randomized gear: item bases, rarities, affixes.
- Drops should be exciting because they can change how you play (augments), not only your numbers.
- Some items are champion-specific and modify that champion's abilities.
- Loot drops during a run, and loot picked up is never lost on death (see Game structure).
- (Details: LOOT.md.)

### Cross-cutting: world interactivity
The environment is both a **weapon** and a **traversal tool**.
- Weapon: knockback into walls, hazards like oil and fire, destructible objects, pits.
- Traversal: grapple and swing on walls (Akshan-style), dash over pits, blink past obstacles.
- Everything interacts through tags and reaction rules (CONVENTIONS.md), so new interactions are easy to add.
- **Height (3D.md, Terrain and height):** real terrain height (stairs, ramps, hills, plateaus) on a gameplay floor that stays flat. Cliffs stop walking and dashes, not projectiles or sight. Knock-ups carry enemies over ledges and into pits. A few special enemies stand on perches where melee can't reach them from below, and **no enemy is unanswerable**: each one has a walk-up route, a pull, a ranged answer or a dead zone, and every champion has at least one answer to each.

## What we take from each reference
| Game | Take | Don't take |
|---|---|---|
| **League of Legends** | champion identity (passive + abilities + ultimate), ability design vocabulary, stat names and units, ability haste, AD/AP split; adaptive damage and Tahm Kench's devour (companions, COMPANIONS.md) | point-and-click movement, lanes, PvP, the MOBA map, last-hitting |
| **Hades** | movement and combat feel, dash with i-frames, input buffering, readable enemy attacks, rooms as combat spaces; reactive dialogue (characters remark on what you just did and who you're playing), the reference for how the story is delivered (Pillar 5); a companion at your side on its own button (Hades II's familiars, Hades' companions; COMPANIONS.md) | roguelite permadeath and resetting your power every run |
| **Dark Souls** | checkpoints inside a run: death sends you back to the last one reached; checkpoints that are also fast travel, resting that brings ordinary enemies back while bosses stay dead, shortcuts, dense places that look down on where you've been (DUNGEONS.md) | dropping currency on death and having to recover it |
| **Diablo** | randomized loot, rarities and affixes, "increased" vs "more" modifiers, dungeon depth scaling, magic find; roaming packs, elites with rolled modifiers, difficulty tiers with dungeon-wide modifiers at the top, an auto-map (DUNGEONS.md) | slow click-to-attack combat, stat-check fights, procedural layouts |
| **Baldur's Gate 3** | environment and immersion: places that feel lived in and tell their own story (Pillar 5); companions with personality (Scratch, the owlbear cub) and a familiar that falls and comes back (COMPANIONS.md) | turn-based combat |
| **Pokemon** | companions (COMPANIONS.md): species with abilities of their own, eggs that hatch by playing, branching evolutions, a bond that grows by playing together, copies kept as individuals | a team of six, catching mid-fight, the pet fighting as a unit |

## Game structure (decided 2026-09-29)
The loop: **hub → pick a champion → set their talents → run a wing of a dungeon → back to the hub.** (A wing is a run since 2026-10-03; DUNGEONS.md. A different champion can be picked for the next wing.)

### Hub
- A home base between runs. There the player picks a champion, sets that champion's talent loadout, chooses a companion to take along (COMPANIONS.md; fixed for the run, none allowed), and launches a run: a dungeon, one of its open wings and an unlocked difficulty tier (DUNGEONS.md).
- Gear lives in each champion's own inventory: one unlimited list, the same at the hub and mid-run, with no separate stash (LOOT.md). Other hub features (NPCs, shops) aren't decided yet (NPCS.md, LOOT.md).

### Roster
- Every unlocked champion can be picked freely at the hub (League champ-select style). There is no single locked save-file character.
- Each champion has its own persistent progress, independent of the others.

### Runs
- ~~A run = entering a dungeon~~ (superseded 2026-10-03). **A run = entering one wing of a dungeon** as the chosen champion (DUNGEONS.md): a solo player, with an optional AI ally (another champion of the roster, picked at the hub; ALLIES.md).
- A dungeon's first wing starts it; once cleared, its other wings open in any order, and the final wing's boss waits until the others are cleared.
- Loot drops during the run (Diablo-style).
- A run ends when the wing is cleared (its boss; rewards, then back to the hub) or when the player leaves.
- The talent loadout is set at the hub before the run and can't change mid-run. A different champion can be picked for the next wing.

### Death
- Checkpoints inside a run (Dark Souls-style). Dying respawns the player at the last checkpoint reached. It's not roguelike permadeath, and it doesn't send the player back to the hub.
- Nothing is lost on death: loot already picked up and champion XP already earned this run are kept. There is no drop-and-recover risk.
- ~~Checkpoint placement, and whether cleared enemies between the checkpoint and the death point come back, are decided in DUNGEONS.md.~~ Decided 2026-10-03 (DUNGEONS.md, Checkpoints): checkpoints are found in the wing and are also fast-travel points. Bosses, elites and anything tied to a quest or puzzle stay dead. Ordinary enemies come back when you **rest** at a checkpoint, not when you die and retry. **Dying never undoes progress.** A checkpoint comes about every 8–12 minutes, at each floor's start and right outside every boss; resting is free and refills you; dying to a boss resets the boss, nothing else (Ryan, 2026-10-03, DUNGEONS.md's interview).

### Champion progression and talents
- Each champion has a persistent **champion level**, gained by playing that champion. It gates that champion's own talent points.
- Talent progress is fully separate per champion. No currency or points are shared between champions. (Companion materials are account-wide but buy only companions: Meta-progression, the companion exception.)
- Talents reshape the champion's existing abilities, built on the ABILITIES.md augment system (TALENTS.md). They never move abilities between slots (see Build variety).
- The champion level **only** gates talent points. It never touches combat stats and never calls `StatsComponent.set_level()`.
- There is no leveling inside a run. In-run power comes purely from loot.
- `set_level()` and per-level growth stay as built, unused by champions, reserved for enemy scaling (DUNGEONS.md).

## Meta-progression (account level)
What the player earns across all champions, beyond each champion's own progress. Its job: make players want to take every champion through the dungeons (Open questions, 4).
- **The rule (Ryan, 2026-10-02):** no power is shared between champions. Account-level rewards never make any champion stronger in combat; this is the same rule as "progress on one champion never makes another stronger" (Game structure). It has exactly one exception, companions (below).
- **The one exception: companions** (Ryan, 2026-10-02; COMPANIONS.md; DECISIONS.md, Game structure). Companions are account-wide collectibles, and the companion a champion takes along gives that champion its passives, quirks and command, whichever champion it is. The exception is narrow:
  - the power comes only from the one companion taken along on a run, through its own passives, quirks and command; owning more companions, the size of the collection and spare companion materials give none;
  - companion materials are account-wide but spent only on companions, never on gear or anything a champion owns;
  - a companion never changes a champion's abilities or passive;
  - **no other account-level reward may grant combat power** (achievements, mastery, collections, hub growth, difficulty unlocks, anything PROGRESSION.md picks).
- **Allowed rewards:** cosmetic, informational, convenience, story and difficulty.
- **Candidates** (none decided; PROGRESSION.md picks):
  - statistics pages, per champion and for the account;
  - achievements with titles and banners (ACHIEVEMENTS.md, later);
  - a codex and bestiary, and lore collections;
  - champion mastery cosmetics;
  - a story that rewards playing every champion (an epilogue or a true ending);
  - difficulty tiers unlocked by clears (decided 2026-10-03, DUNGEONS.md: five per wing, each champion climbing them itself; wing clears, which open a dungeon's wings, are per account);
  - daily seeded challenges with leaderboards;
  - collections: every legendary and artifact found, a cosmetic armory;
  - hub growth (the hub changes as the account progresses).

## Decision priorities (when goals conflict)
1. **Feel and responsiveness.** Control is never taken from the player without a clear reason.
2. **Clarity.** The player can read what's happening (telegraphs, feedback, tooltips that show real numbers).
3. **Skill expression** over stat checks.
4. **Build variety** over balance perfection. Strong and fun beats flat and "fair".
5. **Extensibility.** Prefer the data-driven option (tags, rules, Resources) over hard-coded logic.
6. Realism comes last.
*(Order assumed from our planning. Ryan can reorder it.)*

"Tactical and methodical" (One sentence; Pillar 1) lives in Clarity (2) and Skill expression (3): the decisions come from reading the fight, never from slowing the player down (1).

## Scope
- **In:** single-player, hand-painted stylized 3D at native resolution (League-style); UI and window designed for 1920×1080 and scaling to the player's monitor; multiple champions (Knight first), hand-made rooms stitched into dungeons, gear with affixes and augments.
- **Camera and world (3D_PIVOT.md, Givens):** a fixed-angle camera that follows the player and never rotates; no jumping; real terrain height (stairs, ramps, hills, plateaus) on a gameplay floor that stays flat; knock-ups; floors that overlap are separate rooms, joined by stairs or doors.
- **Out for now:** multiplayer/co-op, PvP, open world, procedural room geometry. *(assumed)* Shuffled contents in fixed, hand-made layouts are in (DUNGEONS.md): what stands in a space changes each run, the space never does. A wing's scale is dense, hand-built spaces, not an open world.
- **Out for now (decided):** gamepad. Keyboard and mouse only for now.

## Open questions (answer these before the matching doc is written)
The run structure, death, hub, roster, talent progress, ability slot and in-run leveling questions were answered 2026-09-29 (Game structure and Build variety above; DECISIONS.md, Game structure). What those answers left open:
1. ~~**Talent size:** does "up to 5" mean a small total tree (5 talents in all), or a larger pool with 5 active at once?~~ Answered 2026-09-30: a larger pool (about 15–20 per champion) with about 5 active at once, swapped at the hub (TALENTS.md; DECISIONS.md, Talents).
2. ~~**Gear after a run:** does gear picked up in a run stay with the champion afterwards (inventory, stash), and what does leaving a run early keep or forfeit?~~ Answered by LOOT.md (2026-10-01): items are never lost; they're kept through death and through leaving a run, in one unlimited inventory per champion (DECISIONS.md, Loot).
3. **Unlocking champions:** how many at launch, and how does a champion get unlocked?
4. ~~**Replayability across champions:** how do we make players want to take every champion through the dungeons? The rule and the candidate rewards are in Meta-progression above; which ones get built is PROGRESSION.md's (the story side, NARRATIVE.md's).~~ Answered 2026-10-03 (DUNGEONS.md): **difficulty tiers** per wing, unlocked by clears; **the champion lens** (codex entries, dialogue and scenes that change per champion, and one quest line per champion per wing with its own named reward); **guaranteed named gear** hand-placed at the end of hard secrets; and **companion hunting** (parts and clues found in wings, signature companions per dungeon). The other candidates in Meta-progression stay PROGRESSION.md's to pick.
5. **Story depth and voice scope:** how deep does each dungeon's story go, and how much of it is voiced (scenes, lines per champion)? NARRATIVE.md.
6. **Localization:** will the game ship in more than one language? It decides whether player-facing text goes through string tables from the start (CONVENTIONS.md) and how much voice gets recorded.
7. **Big fights vs "methodical":** the 3D interview set about 30 enemies in a big fight and 50 at the peak (3D_PIVOT.md, Q14), which pulls against readable, decision-heavy combat (Pillar 1). Are big fights mostly fodder plus a few tactical elites? ENEMIES_AI.md and DUNGEONS.md. (DUNGEONS.md, 2026-10-03: most of a wing is roaming packs you can take one at a time; big fights are a few set-piece arenas and bosses. The make-up of a big fight stays ENEMIES_AI.md's.)

## How Claude should use this doc
- When designing a system, check it against the pillars and priorities above, and say which pillar a choice serves.
- If a request conflicts with this vision, point it out; the vision may need updating.
- Don't fill in the open questions yourself. Ask Ryan when a task depends on one.
