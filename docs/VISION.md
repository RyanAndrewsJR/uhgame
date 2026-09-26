# VISION.md: What We're Making and Why

**Read when:** designing a new system or doc, making a design decision the docs don't cover, or when a request could be read more than one way.
**Not for:** technical rules (CLAUDE.md), naming (CONVENTIONS.md), or system specs (their own docs).
Items marked *(assumed)* are my best reading of the goals. Ryan should confirm or correct them.

## One sentence
A 2D pixel-art action looter where you pick a champion with a League-style kit, move and fight with Hades-level precision, and dive through Diablo-style dungeons collecting gear that changes *how your abilities play*, not just how big the numbers are.

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
- (Details: ABILITIES.md, COMBAT.md, not written yet.)

### 2. Build variety
The same champion should play very differently from build to build.
- Gear changes numbers (stat modifiers) **and** behavior (augments that alter abilities). See STATS.md.
- Scoped modifiers reward focusing on one ability or tag (e.g. "projectile" builds, "movement" builds).
- Several viable builds per champion. No single right answer. *(assumed)*
- Champions have different resource types (mana, energy, fury, none), and those change the play rhythm.

### 3. Fluid movement
Hades-level responsiveness is the foundation. If movement feels bad, nothing else matters.
- Near-instant acceleration and stopping, dash-centric, heavy input buffering. (Numbers: MOVEMENT.md.)
- Movement abilities (dashes, blinks, grapples, swings) are core to champion identity, not just utility.

### 4. Fluid combat
Attacks feel weighty and immediate: hitstop, screen shake, knockback, clear feedback.
- Attacks and abilities flow into each other, and dash cancels keep the player in control.
- CC (stun, slow, knockback) is a tool the player uses, and a threat they avoid.
- (Details: COMBAT.md, not written yet.)

### 5. Dungeon crawling
Runs through dungeons built from hand-made rooms stitched together.
- Rooms are designed spaces with walls, pits, and hazards to use tactically, not empty arenas.
- Difficulty and rewards increase with depth. *(assumed)*
- (Details: DUNGEONS.md, not written yet.)

### 6. Looting
Diablo-style randomized gear: item bases, rarities, affixes.
- Drops should be exciting because they can change how you play (augments), not only your numbers.
- Some items are champion-specific and modify that champion's abilities.
- (Details: LOOT.md, not written yet.)

### Cross-cutting: world interactivity
The environment is both a **weapon** and a **traversal tool**.
- Weapon: knockback into walls, hazards like oil and fire, destructible objects, pits.
- Traversal: grapple and swing on walls (Akshan-style), dash over pits, blink past obstacles.
- Everything interacts through tags and reaction rules (CONVENTIONS.md), so new interactions are easy to add.

## What we take from each reference
| Game | Take | Don't take |
|---|---|---|
| **League of Legends** | champion identity (passive + abilities + ultimate), ability design vocabulary, stat names and units, ability haste, AD/AP split | point-and-click movement, lanes, PvP, the MOBA map, last-hitting |
| **Hades** | movement and combat feel, dash with i-frames, input buffering, readable enemy attacks, rooms as combat spaces | *(open question: roguelite run structure, see below)* |
| **Diablo** | randomized loot, rarities and affixes, "increased" vs "more" modifiers, dungeon depth scaling, magic find | slow click-to-attack combat, stat-check fights |

## Decision priorities (when goals conflict)
1. **Feel and responsiveness.** Control is never taken from the player without a clear reason.
2. **Clarity.** The player can read what's happening (telegraphs, feedback, tooltips that show real numbers).
3. **Skill expression** over stat checks.
4. **Build variety** over balance perfection. Strong and fun beats flat and "fair".
5. **Extensibility.** Prefer the data-driven option (tags, rules, Resources) over hard-coded logic.
6. Realism comes last.
*(Order assumed from our planning. Ryan can reorder it.)*

## Scope
- **In:** single-player, 2D pixel art at 640×360, multiple champions (Knight first), hand-made rooms stitched into dungeons, gear with affixes and augments.
- **Out for now:** multiplayer/co-op, PvP, open world, procedural room geometry. *(assumed)*
- **Out for now (decided):** gamepad. Keyboard and mouse only for now.

## Big open questions (answer these before the matching doc is written)
1. **Run structure:** a Hades-style roguelite (gear and power reset each run, with meta-progression between runs), Diablo-style persistent character (you keep gear and level forever), or a hybrid? This affects LOOT, DUNGEONS, PROGRESSION, and STATS (leveling).
2. **Death:** what's lost when you die?
3. **Hub:** is there a town or hub between runs (NPCs, shops, stash, champion select)?
4. **Champion roster:** how many at launch? Do you choose per run, or unlock them?
5. **Ability slots:** 3 abilities + ultimate + basic attack + dash is the current assumption. Can items or progression add or swap slots?

## How Claude should use this doc
- When designing a system, check it against the pillars and priorities above, and say which pillar a choice serves.
- If a request conflicts with this vision, point it out; the vision may need updating.
- Don't fill in the open questions yourself. Ask Ryan when a task depends on one.
