# DUNGEONS.md: Dungeons, Wings, Checkpoints, Contents, Puzzles, Quests and Difficulty Tiers
<!-- Written 2026-10-03 from Ryan's decisions (his interview with the advisor, the same day). A plan: nothing is built. -->

**Read when:** the task involves a dungeon or a wing (its structure, floors, spaces, scale or authoring budget), a run from the hub to a clear, checkpoints (finding, resting, respawning, fast travel), what's shuffled each run (content slots, pools, packs, elites, events, chests), arenas and doors, bosses as set pieces, the puzzle framework (puzzle elements, world states), secrets and collectibles and their rewards, quests and the quest list, where codex entries sit and how they unlock, the map, difficulty tiers and wing modifiers, what a wing favors ("recommended for"), a theme's signature hazards and lighting, the champion lens and champion quest lines, or the dungeon save.
**Depends on:** CLAUDE.md, VISION.md (Pillar 5, Game structure, Meta-progression), CONVENTIONS.md (tags plus rules, context objects, Events), 3D.md (rooms built in 3D: `RoomLayout`, `SimMarker`, overlapping floors as separate rooms, terrain; Wing scale), WORLD_INTERACTION.md (interactables, hazards, destructibles, pits, kill credit, layers 6–10), COMBAT.md (ReactionRule, GameplayEffect, Events), ABILITIES.md (Condition, ability tags), STATS.md (StatModifier), LOOT.md (DropTable, ItemRoller, Pickup, NamedItem, depth), TALENTS.md (Progress, XP, the save pattern and test guard), COMPANIONS.md (drops, eggs, kindling, the imprint), ALLIES.md (party scaling, downed and revive), CHAMPIONS.md (ChampionData, `champion_class`), AUDIO.md (hooks), ENEMIES_AI.md (not written: rosters, behaviors, packs, elites).
**Used by:** ENEMIES_AI (a roster per dungeon on shared behaviors, packs vs arena enemies, elite modifiers, the attack patterns a tier adds), NARRATIVE and NPCS (codex content, the champion lens, quest writing, NPC dialogue), PROGRESSION (one save: clears, tiers, finds), UI (the hub's wing pick, the map, the quest list, the codex screen), LOOT (chest tables, hand-placed named gear, tier loot quality, depth), COMPANIONS (signature companions, counted runs, parts and clues), ALLIES (checkpoints, party scaling with tiers, pair recommendations), CHAMPIONS (champion quest lines), AUDIO (music and ambience per wing), ACHIEVEMENTS (much later).
**Status:** written 2026-10-03. Ryan's decisions (his interview with the advisor, 2026-10-03) are MUST. Items marked *(proposed)* are Claude's picks Ryan hasn't answered; each is also in Open questions. The interview is done: Ryan answered all ten items (I1–I10) in five rounds on 2026-10-03; his answers are MUST, written into the sections below (marked I1–I10) and listed under Open questions, Interview. Nothing is built.

## How to read this doc
Same as ALLIES.md: MUST (never change without asking Ryan), TARGET (start value and allowed range), FREE (your call; tiebreaker: VISION.md's decision priorities). Every number is a TARGET placeholder until the slice wing is built and played. Themes in examples (a vampire's crypts, an enchantress's castle) are illustrations, not launch content.

## Player experience
At the hub you pick the Knight, set his talents and open the Enchantress's Castle. Only its first wing, the Outer Ward, is open. Its card says it favors ranged kits and fire; the Knight can clear it anyway. You enter at difficulty tier 1. The ward is a run of hand-built spaces: a gate yard, a broken bridge with the moat far below, a chapel, a cellar floor reached by a ladder. Packs of thralls loiter in the yard and turn as you come close; you take them one pack at a time. A brazier by a sealed door won't light from a sword, but a burning thrall knocked into it does, and there's a lit torch on the wall for anyone without fire. Behind a cracked wall where a draft stirs the dust, a short, hard secret ends at a chest with a named ring in it, always there. You light a lantern on a plinth: a checkpoint. Resting there brings the yard's thralls back; dying doesn't, and the elite you killed stays dead either way. The corner map fills in as you walk. Your quest list holds the main goal, a ghost's request, and one line that is only the Knight's: an old squire's letter that leads to a hidden door. At the end the throne room's doors seal behind you and the Warden fights in three phases. When it falls, the castle's other two wings open, in any order, and tier 2 opens for the ward. Next time you can take another champion.

## References
- **Dark Souls.** Take: checkpoints you find that are also fast-travel points; resting brings ordinary enemies back while bosses stay dead; shortcuts that loop back; dense, hand-built places where later parts look down on earlier ones. Don't take: dropping currency on death, long runbacks (dying never undoes progress here).
- **Diablo II and IV.** Take: roaming packs that notice you as you come close; elites with rolled modifiers; world tiers and Nightmare-dungeon affixes (difficulty that raises numbers, adds elite modifiers and better loot, with dungeon-wide modifiers at the top); an auto-map, a corner minimap and quest markers; chest and loot rolls. Don't take: procedural layouts (fixed here), open zones.
- **Hades.** Take: set-piece arenas that seal until cleared; bosses as arenas with phases; reactive dialogue that changes with who you are (the champion lens). Don't take: random room order.
- **Baldur's Gate 3.** Take: puzzles that use your kit and the room (fire on a brazier, shoving onto a switch), secrets behind a cracked wall with a clue first, places that tell their own story, quests found in the world (a note, an NPC, an object), a short journal. Don't take: turn-based play, long conversations in the middle of a fight.
- **League of Legends.** Take: matchups that favor some kits without locking any out (a good pick, never a hard counter): the model for "recommended for". Don't take: anything that makes a champion unplayable somewhere.

## Principles
1. **Fixed places, fresh contents.** Every space is hand-built and the same every run; what stands in it (packs, elites, events, chest rolls) is rolled into authored slots. No procedural geometry (VISION.md, Scope).
2. **A wing is a run.** One wing, one champion, one loadout, from the entrance to the clear (or leaving). A dungeon is its wings together.
3. **Dying never undoes progress.** Nothing is lost on death (VISION.md, Death); what was killed for good, solved or found stays so.
4. **Recommended, never required.** A wing favors some kits with real content, and every champion can clear every wing (the wing-level "no unanswerable enemy").
5. **Scale from density, not area.** A wing is counted in distinct spaces, play time and measured authoring cost; it feels big through height, sightlines and backdrops.
6. **Built from what exists.** Puzzles are tags, ReactionRules, Conditions and Events; contents are `SimMarker`-style markers drawing from pools; loot is LOOT's tables; enemies are ENEMIES_AI's rosters. New code only for a new trigger, a new effect kind or a new node.
7. **Bounded content cost.** The champion lens changes words and a few scenes, never layouts; each champion gets one short quest line per wing, inside existing space.
8. **Tuning is data.** Wings, slots, pools, tiers, modifiers, favors, quests and codex entries are .tres files and layout markers.

## Current code
- `Main` (`res://scripts/main.gd`, `main.tscn`) plays one room: `room_scene` (a tile room, or since 3D P8 a `RoomLayout` built with `build_sim()`), the player at `PlayerSpawn`, "Room cleared!" when every enemy is dead (`room_cleared_sound`), "You died – press Backspace to restart", and `restart` (Backspace) reloads the scene. No runs, floor changes, checkpoints or saved room state exist.
- The hub (`hub.tscn`, TALENTS T5) is the main scene: Start run plays `main_layout.tscn` (room_01 built in 3D; `main.tscn` until the 3D pivot's P-M), Sandbox plays `sandbox_main.tscn`. Both play in 3D since P-M (always since the cleanup's C3, which deleted the flag `Main.use_3d_view`).
- Rooms built in 3D (3D.md, Rooms; P8–P9): `RoomLayout`, `Footprint`, `SimMarker` (`scene`, `properties`), `build_sim()`, the validator, `ground_grid()` and derived ledges, the placeholder kit, `lighting_default`. A layout's sim is one `Room` with `bounds_px`, `Entities`, `PlayerSpawn` and its navigation bake. `Room` has no depth (LOOT plans `Room.depth`).
- What the puzzles reuse: `ReactionRule` (8 triggers, 4 built: `HIT`, `UNIT_DIED`, `STATUS_APPLIED`, `ABILITY_CAST`), world rules (`Reactions.add_world_rule()` / `remove_world_rules_from()`, built), `Condition` (AB12), the `GameplayEffect` subclasses, `Events` (`unit_hit`, `unit_damaged`, `unit_died`, `status_applied`, `status_removed`, `ability_cast`). `HitContext.target` is typed `Node`, and `HitPipeline` calls the target's `on_hit()`, so a hit can reach something that isn't a Unit (Reactions only reads Units).
- Approved but not built (WORLD_INTERACTION.md): interactables (layer 8, `interaction_tags`, `on_hit()`, `on_interact()`; the `interact` action on F exists and nothing reads it), Hazards (layer 10; the "while inside" option is built only for perches), the `IMPACT` trigger and `ImpactContext`, destructibles, `SurfaceTags`, kill credit, pits (no build slot). Pickups (layer 9) and drop tables are LOOT's (not built).
- `Progress` (TALENTS T4) is the save pattern (`user://progress.cfg`, read lazily, never written by a scene under `res://scenes/tests/`). `StatsComponent.set_level()` and per-level growth are built and unused, reserved for enemy scaling.
- Nothing about dungeons, wings, checkpoints, quests, the codex, the map or difficulty exists.

## Goal / feel
| What | Number | Why |
|---|---|---|
| A wing's play time | 45–90 min, a first clear at tier 1 | Ryan (MUST) |
| Spaces per wing | about 40–60, a planning range; the slice's count comes from D0's measured cost | Ryan with the advisor (MUST shape) |
| Wings per dungeon | 1–3 | Ryan (MUST) |
| Releases | slice: 1 wing; first public release: 1 dungeon of 2–3 wings; later 8+ dungeons | Ryan (MUST) |
| Difficulty tiers | 5 per wing at launch | Ryan (I4, 2026-10-03) |
| Champion quest line | about 10–15 min, one per champion per wing | Ryan (MUST) |
| Floor change | a brief fade: 0.25 s out, the load (under 0.5 s), 0.25 s in | *(proposed)*; the P-spike measures the load |
| Checkpoint spacing | about every 8–12 min of first-time play, plus one at the start of each floor and one just outside every boss arena: about 5–8 a wing | Ryan (I2, 2026-10-03) |
| Map reveal | a 12 m (384 px) circle around the player, on a 1 m grid | *(proposed)* |
| Quest list | at most 4 lines on screen: the main goal, then up to 3 tracked side quests | Ryan (I6, 2026-10-03) |
| Frame budget | 5.6 ms at 180 Hz with a wing's floor loaded | 3D.md; the P-spike |

## Rules
### Structure: dungeons, wings, floors, spaces (MUST; Ryan 2026-10-03)
- A **dungeon** has 1–3 **wings**. Each wing has its own environment and theme (a vampire's crypts; an enchantress's castle with indoor and outdoor sections), its own quests, its own codex entries and its own boss. The dungeon also has its own dungeon-level quests and codex entries, spanning its wings.
- **A wing is a run.** This replaces VISION's "a run is one dungeon". The loop: hub → pick a champion → set its talents → enter a wing → clear it or leave → hub. Talents stay locked during the wing. A different champion can be picked for the next wing.
- **Wing order:** the first wing starts the dungeon. Once it's cleared, the others open, in any order. **Wing clears are per account** (I1, 2026-10-03): once any champion clears the first wing, every champion can enter the others (the Knight clears the Outer Ward, then another champion starts the next wing). The final wing's boss stays locked until every other wing has been cleared, by anyone; the final wing itself can be played before that, its boss door shut with a line saying why.
- **Floors:** a wing can have floors, up and down. Floors connect by **stairs, ladders, lifts or pit-drops**, with a brief fade. Each floor is its own space in the sim (3D.md, Terrain and height 1c: overlapping floors are separate rooms). No seamless streaming between floors in v1.
- **Space:** one distinct authored area: a hall, a bridge, a courtyard, a cavern, a stair tower, an arena. A wing's size, budget and pacing are counted in spaces. *(proposed)* A space is built from the kit as a layout (3D.md, Rooms). Whether a floor is one sim Room holding all its spaces or each space is its own Room joined by doorways is the P-spike's answer (3D.md, Wing scale).
- **Wing content:** caverns, pits, elevated sections, secret areas, puzzles and collectibles. Pits need WORLD_INTERACTION's pit step first (Build order).
- The word **floor** here is a wing's storey ("the cellar floor", "floor 2"), as 3D.md 1c already uses it; the walkable ground keeps "the floor" in "floor pick" and "floor drawing" *(proposed; Open questions)*.

### Scale (MUST: counted in spaces, time and measured cost; Ryan with the advisor 2026-10-03)
- A wing is **dense and hand-built**. It's defined by its number of distinct spaces (plan around **40–60**), its intended play time (**45–90 min**) and a **measured** authoring cost. Never by area: one square kilometre is over 4,000 Hades-sized chambers (about 15 × 15 m each), which no one can build by hand.
- The sense of scale comes from **verticality** (floors, plateaus, drops), **long sightlines** (a bridge, a courtyard, a shaft) and **backdrops** that show earlier sections: fighting on a high bridge with the castle you came through visible below. Backdrops are view-only (3D.md, Wing scale).
- **The slice wing is sized from the real cost** of building spaces with the P8 kit, measured in D0 (Build order). No space count or schedule for the slice is set before that measurement.

### Authoring: spaces and prefabs (MUST; Ryan, I9 2026-10-03)
- **The unit of design is the space:** one layout (a hall, a bridge, an arena), the thing a level builder makes, tests and counts.
- **Inside spaces, builders reuse prefabs:** chunks made from kit pieces and saved as their own scenes (a stair tower, a doorway with its door, a row of pillars, a brazier corner). *(proposed)* They live in `scenes/rooms/prefabs/`; each asset inside keeps its own footprint (a footprint belongs to its asset's root: 3D.md, Rooms), so the validator checks a prefab like any asset.
- **Stretches and floors are just groups of spaces**, not things a builder places.
- **The slice's budget is a total-hours cap** that Ryan sets once D0 has measured the hours per space. The slice's space count is that budget divided by the measured cost. If 40 spaces don't fit, the slice is a shorter wing (about 45 minutes), never a rushed one.

### A run, start to end (MUST shape; the details *(proposed)*)
- At the hub the player picks a champion, its talents, an ally and a companion (ALLIES.md, COMPANIONS.md), then a dungeon, an open wing and an unlocked difficulty tier. **A new run starts at the wing's entrance** (I2): checkpoints lit in an earlier run don't carry over.
- The wing's contents are rolled once, at the start, from the run's **seed** (Contents), and the difficulty tier is fixed for the run.
- **The clear:** the wing is cleared when its boss dies (its main goal). The clear unlocks the next difficulty tier of this wing for the champion who cleared it, and the first wing's clear opens the dungeon's other wings for every champion (I1, Difficulty tiers). *(proposed)* After the boss an exit opens; the wing stays open to explore (secrets, quests) until the player takes it or leaves.
- **Leaving:** the pause menu's Back to hub ends the run. Nothing found is lost (VISION.md, Death).
- **Quitting the game mid-wing** (I2, the advisor's default): the run is kept, and relaunching resumes it at the last checkpoint reached, with its kills, puzzles, finds and seed. Nothing else is saved: not your exact spot, not a fight in progress (enemies alive go back to their posts, as after a death). *(proposed)* The run's record is saved as it changes, so a quit loses no kill made since the last checkpoint; resuming is a death respawn without the death.
- *(proposed)* A clear gives clear XP (`WingData.clear_xp`; TALENTS' planned clear bonus) and is a **counted run** for eggs (COMPANIONS.md).

### Checkpoints (MUST: found, fast travel, the hybrid respawn rule; Ryan 2026-10-03)
- A **checkpoint** is found in the wing (lit the first time you reach it). Every found checkpoint is also a **fast-travel point**: from a checkpoint you can travel to any other found one in this wing, on any floor.
- **Death** respawns the party at the last checkpoint reached (VISION.md, Death). Nothing is lost: loot picked up, XP earned, quest steps done, secrets found.
- **The hybrid respawn rule** (Ryan):
  - **Dead for good** (for the run): bosses, elites, and anything tied to a quest or a puzzle. Neither death nor rest brings them back.
  - **Ordinary fodder** between you and the next checkpoint comes back when you **rest** at a checkpoint, and **not** when you die and retry.
  - **Dying never undoes progress.**
- **Resting is free and refills** (I2): resting refills health and resource (Fury empties: CHAMPIONS.md's proposal), revives a downed ally (ALLIES.md), brings a consumed companion back (COMPANIONS.md), and is where fast travel starts. Its only cost is that the checkpoint's stretch of ordinary enemies comes back. You can't rest mid-fight (CHAMPIONS' "in combat": a hit dealt or taken within `decay_delay`).
- *(proposed)* **The stretch:** each space belongs to one checkpoint's stretch: the spaces from that checkpoint up to the next ones. Resting at a checkpoint brings back the fodder killed in its stretch, the same packs (the seed doesn't reroll).
- *(proposed)* Enemies still alive when you die go back to their posts at full health; the kills stay.
- **Placement and density** (I2): about every 8–12 minutes of first-time play, at the start of each floor, and always right outside a boss arena: about 5–8 in a wing.
- **Bosses** (I8): dying to a boss resets it (Bosses).

### Contents: fixed layout, shuffled contents (MUST; Ryan 2026-10-03; the slot data *(proposed)*)
- **Fixed, the same every run:** the layout (every space, floor and link), puzzles and their solutions, secret locations, collectibles, checkpoints, the wing's boss, quest NPCs and quest objects, hand-placed named gear (it never moves).
- **Shuffled each run:** which enemy packs, elites and optional events appear in which authored slots, and chest and loot rolls (Ryan). And (I3, 2026-10-03):
  - **elite modifiers** are rolled fresh each run, never tied to a slot;
  - **slots can stay empty**, so a space's density varies (two packs in a hall one run, three the next) while its layout doesn't;
  - **chest positions shuffle** among a few chest slots, not only their contents;
  - **mini-bosses vary**: a side area's mini-boss is picked from 2–3 candidates each run.
- **A higher difficulty tier widens the pools** (I3): the layout stays, but tougher packs unlock in the pools, some slots fill only from a given tier, and elites show up more often. Tier 4 is a nastier version of the same place.
- **Content slots** (the authored-slot system): a **content slot** is a marker the level builder places in a space. It lists the **pools** it may draw from, and at the run's start the run picks one entry from them, or nothing, with the run's seed. Always "content slot" in full: "slot" alone means an ability slot or an equipment slot.
  - Kinds: `PACK` (a roaming pack), `ELITE` (an elite, its elite modifiers rolled at spawn), `MINI_BOSS` (one of 2–3 candidates, never empty), `EVENT` (an optional event: an ambush, a shrine, a caged prisoner, a cursed chest), `CHEST` (a chest whose contents roll from its table; a few chest slots share a group so the chest's position moves).
  - A content slot has `pools` (the allowed pools), `empty_weight` (its chance to stay empty, weighed against the pools' entries), `min_difficulty_tier` (it fills only from that tier up), `group` and `group_count` (slots sharing a group fill exactly `group_count` of them: "an ambush in the hall or in the crypt, not both"), and a stable id (so the run remembers what it rolled and what died there).
  - A **pool** is a weighted list of entries, each a scene (a pack, an elite, an event, a chest) with a `weight` and a tier range. Pools belong to the dungeon (they draw on its roster) and its wings share them.
  - Fixed things are plain `SimMarker`s, never content slots.
- A **pack** is a scene of enemies placed together, which notice the player by proximity and fight together. What makes them a pack (noticing, calling each other, leashing) is ENEMIES_AI's.

### Fights: packs and arenas (MUST; Ryan 2026-10-03)
- **Roaming packs** placed in the space notice the player by proximity (Diablo). **Most of a wing is packs.**
- **Arenas** are a few set pieces that lock their doors until cleared (Hades): bosses and set-piece fights.
- *(proposed)* An **arena** (a sim node placed with a marker) has a region, its doors and its waves. When the party is inside the region (or `seal_delay` after the player enters), its doors seal (bodies on layer 1: walking, dashes, projectiles and sight all stop) and wave 1 spawns in with a telegraph. Each wave fills its own content slots or fixed markers; the next starts when the last enemy of a wave dies (or when fewer than `next_wave_at` are left). When the last wave dies, the doors open, the arena is **cleared** for the run (a world state, `arena_<id>_cleared`), and its reward opens. *(proposed, following I8's boss rule)* Dying inside re-arms the arena whole: its doors open, its living enemies leave, and the next entry starts at wave 1. An arena isn't progress until it's cleared, as a boss isn't until it's dead; every kill outside it, find and puzzle is kept.
- How enemies notice, chase, leash and spawn in is ENEMIES_AI's; this doc places them.

### Bosses (MUST; Ryan 2026-10-03)
- Each wing ends in its own **boss set piece** (an arena with a boss). Side areas may hold optional **mini-bosses** and elites. A side area's mini-boss is picked from 2–3 candidates each run (I3: a `MINI_BOSS` content slot); the wing's boss is always the same. *(proposed)* A mini-boss counts as a boss for the respawn rule: dead for good.
- The final wing's boss is the dungeon's **finale**, locked until the other wings are cleared.
- **Dying to a boss** (I8, 2026-10-03): a checkpoint always stands right outside the boss arena. Dying resets the boss to full health and re-arms its arena; every kill, find and puzzle in the run is kept. A boss isn't progress until it's dead (Dark Souls, Hades), so "dying never undoes progress" holds.
- *(proposed)* A boss at a higher difficulty tier gets the tier's enemy modifiers like any enemy, and its new attack patterns come from the same tier gate (ENEMIES_AI.md).

### Enemies: a roster per dungeon on shared behaviors (MUST; Ryan 2026-10-03; ENEMIES_AI.md builds it)
- Each dungeon has its **own enemy roster**, built on **shared behaviors** (charger, ranged, summoner, shielded...), each with a new look and a twist.
- The requirement for ENEMIES_AI.md: **behaviors are reusable data, rosters are content.** A dungeon's roster names its enemies; each is a shared behavior plus its own data (stats, abilities, look, twist). DUNGEONS' pools draw from the roster.
- Elite modifiers and the attack patterns a difficulty tier adds are ENEMIES_AI's data; the tier only says how many (Difficulty tiers).

### Navigation (MUST; Ryan 2026-10-03)
- An **auto-map** fills in as you explore; a **minimap** sits in a corner; **quest markers** show where quest steps point; **checkpoint travel** opens at a checkpoint. The map handles **multiple floors**.
- *(proposed)* The map is drawn from each floor's sim outline (its walls and walkable ground, `RoomLayout.ground_grid()`), never painted by hand. Fog lifts in a 12 m circle around the player. The full map is on a new input action, `map` (M, unbound), and pauses the game like the pause menu; the minimap never does. The full map shows one floor at a time, with its floor links marked and keys to switch floors. Whether what's revealed is kept past the run: Open questions.

### Quests (MUST: found inside, a short list, optional except the main goal; Ryan 2026-10-03)
- Quests are **found inside the wing**: from NPCs, notes and objects. They're tracked in a **short UI list**. All are optional except the wing's **main goal** (reach and defeat its boss).
- Each wing has its own set, and each dungeon has its own set spanning its wings.
- **The list** (I6, 2026-10-03): up to 4 lines on screen: the main goal always first, then up to 3 side quests the player tracks. A champion's own quest line carries **that champion's crest and color**. The full list lives on the map screen (M).
- **No quest fails** (I6): a quest can be untracked (hidden from the list), never failed or lost. **Progress carries over:** a side quest's progress is kept to the next run of that wing (Diablo IV-style), so a 45–90 minute wing needn't be finished in one go; a champion's own line keeps its progress per champion. *(proposed reading)* Wing and dungeon quests' progress is per account, like wing clears. The main goal is the run's own: it's done when this run's boss dies.
- *(proposed)* A quest's progress is saved per step; a world state a later step needs (a door it opened) is a `saved` state, so the next run doesn't undo it.
- *(proposed)* The data shape (Data, Quest): a `Quest` of steps, each done when its Conditions on world states pass.

### Puzzles and secrets: one framework (MUST: all four kinds, built on tags, ReactionRules and Events, no parallel system; Ryan 2026-10-03; the shape *(proposed)*)
The four kinds, all in:
1. **Combat-linked:** your kit and the room: knock an enemy onto a switch, dash across a collapsing bridge, light a brazier with a fire ability.
2. **Switches, levers, keys and plates.**
3. **Hidden areas and breakable walls**, always with a small clue first (a crack, a draft, a stain, a note).
4. **Lore and observation puzzles** tied to the codex: an entry tells the order, the room asks for it.

**The framework:**
- **Puzzle elements are interactables** (WORLD_INTERACTION.md, Interactables): a brazier, a lever, a plate, a cracked wall, a collapsing bridge, a statue, a locked door. Each has `interaction_tags` (`ignitable`, `breakable`, `pressable`...) and a **state** (`&"off"`, `&"lit"`, `&"broken"`...).
- **What changes an element is data: element rules.** An element holds `ReactionRule`s, matched against the element's own events by the matcher that world and unit rules already use (a third kind of rule, next to world and unit rules):
  - `HIT` with `required_hit_tags`: a `fire` hit lights a brazier; any hit on a `breakable` wall counts toward `hits_to_break` (WORLD_INTERACTION's destructibles);
  - `IMPACT` with `min_impact_speed_px`: a body knocked into a switch;
  - `HAZARD_ENTERED` / `HAZARD_EXITED`: a unit on a plate (a plate is a Hazard-style area with the "while inside" option); `required_unit_tags` can ask for an enemy (`displaced`, so only a knocked enemy counts);
  - one new trigger, **`INTERACTED`**: F on the element (the other unit is whoever pressed).
  - Their `conditions` (the shared `Condition`) can require other states: "only while the moon gate is open".
- **What an element does is effects:** existing GameplayEffects for anything on Units (a trap's damage, a status), and one new effect kind, **`SetWorldStateGameplayEffect`**, which sets a world state.
- **World state:** a named value of the run (`&"crypt_gate_open"` = 1). Set by that effect; read by one new `Condition` kind, **`WORLD_STATE`** (the state, a comparison, a value). Everything that waits on a puzzle reads it through Conditions: a door opens while its conditions pass, a bridge extends, a chest unlocks, a content slot fills, a quest step completes, a codex entry unlocks. **`Events.world_state_changed(id, value)`** tells them (and the quest list, the map, a solved chime) to check again; nothing polls every frame.
- **Kills feed it too:** a quest target or a puzzle's enemy gets a unit rule through its marker's `properties` (`UNIT_DIED`, `owner_role` AFFECTED → `SetWorldStateGameplayEffect`). Counting ("ten ghouls") is the effect's ADD mode with a `WORLD_STATE` at-least check.
- **Persistence:** a world state lasts the run. One marked `saved` (a shortcut opened, a secret found, a state a quest's later step needs) is kept in the dungeon save, *(proposed)* per account, like wing clears and quest progress. A solved puzzle stays solved through death and rest (the hybrid rule); a puzzle can author its own reset (a wrong lever order resets the row).
- **Clues before secrets:** every breakable wall and hidden door has a clue in sight of it. A lore puzzle's answer is in a codex entry found in the same wing, and a lore puzzle only ever guards an optional secret, never the main path (I7).
- **Never kit-locked:** a combat-linked puzzle on the main path always has a way every champion can do (a torch to carry fire from, a lever beside the plate); a matching kit does it faster or with style (Recommended for). *(proposed)* The same holds for every secret, so every champion can reach every reward.
- **The new code is only:** the `INTERACTED` trigger, `SetWorldStateGameplayEffect`, `Condition.Kind.WORLD_STATE`, element rules on the interactable, `world_state_changed`, and the elements themselves (WORLD_INTERACTION's interactables, hazards and destructibles). CONVENTIONS' rule holds: code only for a new trigger or a new GameplayEffect type.

### Difficulty tiers (MUST; Ryan 2026-10-03, with his I1 and I4 answers)
- Each wing has **difficulty tiers**, unlocked after a clear. Each tier **raises enemy health and damage**, **adds elite modifiers** and **a few new attack patterns**, and **improves loot quality**; the top tiers add **wing-wide modifiers**. **Five at launch** (I4).
- **The unlock** (I4): clearing a wing at tier N unlocks tier N+1 **of that wing only**; each wing is climbed on its own (like Hades' Heat, per weapon). Tier 1 is open whenever the wing is.
- **Per champion** (I1): each champion climbs every wing's tiers itself. A higher tier drops better loot, and loot is power, so better loot is only ever earned by the champion who wears it: the no-shared-power rule holds (VISION.md, Meta-progression). (Which wings are open is per account: Structure.)
- **Party scaling** (ALLIES.md) already accounts for party size and stacks with the tier; companions never count. *(proposed)* With an ally along, the run's tier is one the player's champion has unlocked; the ally's own tier progress doesn't matter, and a clear unlocks the next tier for the player's champion only.
- Always "difficulty tier" in full: "tier" alone is a talent's depth (TALENTS.md) and "elite" and "boss" are enemy tiers (CONVENTIONS.md).
- Tiers are difficulty, never power: unlocking one grants no combat power.
- *(proposed)* A tier is data (`DifficultyTier`, Data): enemy stat modifiers applied at spawn next to `PartyScaling.apply_to()` (source `&"difficulty_tier"`), how many elite modifiers an elite rolls, a tier range on pool entries and enemy abilities (the new attack patterns and tougher packs), a loot depth bonus (LOOT's formulas unchanged), and the wing modifiers.
- *(proposed)* A **wing modifier** is a bundle of world rules (`Reactions.add_world_rule()` under `&"wing_modifier_<id>"`), enemy stat modifiers and statuses given at spawn: "enemies burst into flame on death", "elites are shielded", "darkness: fewer lights". It never lowers the champion's own stats: harder fights, not a weaker you.

| Difficulty tier (five: Ryan, I4; the numbers TARGET, *proposed*) | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Enemy health (PERCENT_MULT) | +0% | +60% | +150% | +250% | +400% |
| Enemy damage (`outgoing_damage` PERCENT_MULT) | +0% | +25% | +50% | +80% | +120% |
| Elite modifiers per elite | 1 | 2 | 2 | 3 | 3 |
| New attack patterns | none | from here | more | more | more |
| Loot depth bonus | +0 | +2 | +4 | +6 | +8 |
| Wing modifiers | none | none | none | 1 | 2 |

### Recommended for: what a wing favors (MUST; Ryan 2026-10-03)
- "Recommended for" champions or champion+ally combos is **real design, not a hint label**: a wing contains enemies, hazards and puzzles that favor certain kits (dark rooms reward a light-based champion; long corridors favor ranged). It is **never required**: every champion can clear every wing, and "no unanswerable enemy" holds (3D.md, Terrain and height 3).
- **A wing declares what it favors in a small data field** on the wing, not code: `WingData.favors`, a list of `KitFavor`s *(proposed names)*. Each has a `tag` (a champion class such as `marksman`, or an ability tag such as `projectile`, `fire`, `holy`, `mobility`), a `reason` ("Long corridors: range keeps you safe here") and a `weight`. A champion matches a favor when its `champion_class` is the tag or any of its four abilities carries it; a pair matches when either champion does.
- *(proposed)* Kit-favoring mechanics are sim, never view-only: "dark rooms" are areas that give enemies inside a status (`shrouded`: harder to target) which a light removes (a lit brazier, an ability tagged `holy` or `fire`); the darkness you see is the view of that.
- **How it's shown** (I5, 2026-10-03): the wing's card at the hub lists what it favors, each with its reason ("Long corridors: ranged kits shine"), and marks which champions and which champion + ally pairs match, like a pick hint in League. Nothing extra shows inside the wing.
- **Pairs come from the tags** (I5): a wing lists kit tags only, and any pair whose two kits cover them shows as a good pair. No wing names a specific pair, so adding a champion needs no update to any wing.

### The champion lens and champion quest lines (MUST; Ryan 2026-10-03)
- **The same for everyone:** the layout, the enemies, the main quests.
- **Changes per champion:** codex entries, NPC dialogue and some scenes. NARRATIVE.md writes them; the data carries per-champion variants over a shared text.
- **One champion quest line per wing** for each champion, "medium-small": about 10–15 minutes. It **reuses wing space**: an existing room, a hidden door, a special encounter or a small puzzle; at most a small new alcove. It pays out a **one-of-a-kind named reward** (not the Unique rarity) plus codex entries.
- Quest lines are written **only for champions that exist**. A champion added later adds its lines as an update.
- **The content cost, per champion** (the counting is fixed; the hours per line are measured in the slice, D9):
  - one line per wing: **2–3 lines per champion at the first release** (one dungeon), about **24** at 8 dungeons of 3 wings;
  - each line: one `Quest` of 3–5 steps; one special encounter or small puzzle in an existing space; at most one alcove; 2–3 codex entries; one named reward; its dialogue lines (NARRATIVE.md);
  - so a new wing costs one line per existing champion, and a new champion costs one line per existing wing.
- **The cap** *(proposed)*: one line per champion per wing, never more; 15 minutes at most; no new geometry beyond one alcove of at most 6 × 6 m; one named reward per line; a line never gates the main goal or another champion's content.

### Rewards from secrets and collectibles (MUST; Ryan 2026-10-03)
Secrets and collectibles give three kinds of thing:
1. **No-power rewards:** lore (codex entries), cosmetics, titles, statistics (VISION.md, Meta-progression).
2. **Guaranteed named gear:** a hand-placed named item at the end of a hard secret, always there, going to the picking champion's inventory like any loot (LOOT.md, From the dungeon). *(proposed)* Each champion can claim each one once.
3. **Companion crafting parts and clues**, account-wide (the companion exception; COMPANIONS.md): kindling now, per-dungeon parts later, and clues that lead to a hidden companion.
- Collectibles also include **keys, shortcuts and checkpoint unlocks** that open parts of a wing, with no power effect.
- *(proposed)* A **collectible** is a hand-placed find: a `Collectible` sim node, picked up like loot (LOOT's `Pickup`) or opened like a chest (an interactable). A found one is marked in the dungeon save, so it isn't found twice (scopes in Data, Saving).

### The codex (placement and unlocks here; content NARRATIVE.md)
- Each wing and each dungeon has its own codex entries, and entries change with the champion (the lens).
- **Unlocked on find, account-wide** (I7, 2026-10-03): an entry unlocks when you find its source (a note, a collectible, a quest step, the first kill of a kind of enemy) and stays unlocked for the account. A champion's own variant of an entry unlocks when that champion finds it, so replaying with other champions reveals their takes (Hades-style). *(proposed)* The source is the entry's `unlock_when` Conditions (a world state, mostly).
- **No story beat ever blocks the main path** (I7): no conversation, scene or lore puzzle stands between the player and the boss. Scenes are short and skippable; lore puzzles guard only optional secrets.

### Themes: hazards and environment (MUST; Ryan, I10 2026-10-03)
- **Each theme has 2–3 signature hazards** on the shared Hazard system (WORLD_INTERACTION.md, Hazards), plus the shared basics (fire, oil, pits): a vampire's crypts might have blood pools that heal enemies and sunlight shafts that burn them; the enchantress's castle, glyph traps and collapsing floors. A signature hazard is data (its tags, its status, its reaction rules), not code per wing, and it reads with a telegraph during its `arm_time` like every hazard.
- **Lighting per space:** each theme has its lighting assets (like today's `lighting_default`: the environment and key light), and each space places one, so indoor and outdoor spaces sit in the same wing.
- **Weather is look only:** rain, snow and mist are view-only. Darkness or weather that changes play is a sim hazard with a status (the "dark rooms" of Recommended for), never a view effect.
- **Readability first** (VISION.md, decision priority 2): telegraphs and enemies read in every light; floor drawings are unlit on the floor (3D.md), so a dark space never hides a telegraph.

### Allies and companions in a wing
- Checkpoints revive everyone, and a wipe respawns the party at the last checkpoint (ALLIES.md). Party scaling and the difficulty tier both apply at spawn.
- *(proposed)* A floor change brings the ally along, next to the player; a downed ally comes along still downed.
- The companion comes back at a checkpoint (COMPANIONS.md). *(proposed)* Its imprint carries on across a floor change. Companion drops use the dungeon's signature list (`DungeonData.signature_companions`, replacing COMPANIONS' temporary `drop_species`).

### Loot in a wing (LOOT.md)
- Kills drop as LOOT.md says. *(proposed)* **Depth:** a kill's depth is the wing's `base_depth` + the space's `depth_offset` (higher deeper into the wing) + the difficulty tier's loot depth bonus, set on the sim Room at load (it replaces LOOT's `Room.depth` stand-in).
- **Chests** roll from their own `DropTable` (`drop_table_chest_<name>.tres`) through `ItemRoller.roll_drop()` at the same depth. A chest content slot's pool picks the chest; the chest names its table.
- **Hand-placed named gear** (Rewards, 2) is LOOT's (From the dungeon).
- *(proposed)* Bosses drop from their own table (`drop_table_boss.tres`), and a clear may open a boss chest; numbers come with the slice.
- *(proposed)* Drops on a floor's ground are kept while the run lasts: a floor you leave keeps them until you come back. It amends LOOT's "leaving a room loses the drops on its floor" for the floors of a wing.

### Scope (MUST; Ryan 2026-10-03)
- **Vertical slice:** one wing, polished.
- **First public release:** one dungeon with 2–3 wings.
- **Later updates** add dungeons (8+ eventually).
- Procedural room geometry stays out (VISION.md, Scope); shuffled contents in fixed layouts are in.

## Data (Resources)
Names are *(proposed)* and checked against CONVENTIONS.md (reserved names, vocabulary); they go into CONVENTIONS when Ryan approves them. Resource scripts in `res://scripts/data/`; runtime scripts in `res://scripts/dungeons/` (a new subfolder).

### DungeonData (`dungeon_data.gd`; `res://data/dungeons/dungeon_<name>.tres`)
| Field | Type | Notes |
|---|---|---|
| `id`, `display_name` | `StringName`, `String` | `&"enchantress_castle"` |
| `wings` | `Array[WingData]` | 1–3 |
| `first_wing`, `final_wing` | `WingData` | the first opens the others; the final's boss waits for the other clears (one wing: both the same) |
| `quests`, `codex_entries` | `Array[Quest]`, `Array[CodexEntry]` | dungeon-level |
| `roster` | ENEMIES_AI's type | the dungeon's enemies |
| `pools` | `Array[ContentPool]` | what its wings' content slots draw from |
| `signature_companions` | `Array[CompanionData]` | replaces COMPANIONS' temporary `drop_species` |
| `music`, `ambience` | `SoundEvent` | AUDIO hooks |

### WingData (`wing_data.gd`; `res://data/wings/wing_<name>.tres`)
| Field | Type | Notes |
|---|---|---|
| `id`, `display_name`, `theme` | `StringName`, `String`, `StringName` | the theme names its lighting assets and signature hazards (I10) |
| `floors` | `Array[WingFloor]` (inline) | each: `id`, `display_name`, `index` (0 the entrance floor, +1 up, −1 down), the scene(s) that build it (the P-spike decides one per floor or one per space) |
| `entrance` | `StringName` | the floor and marker where a run starts |
| `boss_arena` | `StringName` | the arena whose clear is the main goal |
| `base_depth` | `int` | loot depth at the entrance |
| `difficulty_tiers` | `Array[DifficultyTier]` | 5, this wing's own (I4) |
| `favors` | `Array[KitFavor]` | what it recommends |
| `quests` | `Array[Quest]` | the main goal first |
| `champion_quests` | `Array[Quest]` | one per champion (`Quest.champion_id`) |
| `codex_entries` | `Array[CodexEntry]` | |
| `clear_xp` | `int` | champion XP on a clear |
| `music`, `ambience` | `SoundEvent` | |

### Placed in a space (by the level builder)
| Piece | What | Fields |
|---|---|---|
| `ContentSlot` (Marker3D, extends `SimMarker`) | a rolled placement | `kind` (`PACK`, `ELITE`, `MINI_BOSS`, `EVENT`, `CHEST`), `pools`, `empty_weight`, `min_difficulty_tier`, `group`, `group_count`; its id from its path in the space |
| `SimMarker` (exists) | a fixed placement | bosses, quest NPCs, puzzle elements, collectibles, checkpoints, doors, arenas, floor links, named-gear chests. Gains a stable `marker_id` (its path) so the run can remember it dead or used |
| `Checkpoint` (sim scene, interactable) | find, rest, travel | `id`, `display_name`; each space names its checkpoint (`stretch`) |
| `Arena` (sim scene) | a set piece | its region, `doors`, `waves` (`ArenaWave`: content slots or markers, `next_wave_at`), `seal_delay`, its reward |
| `Door` (sim scene, interactable) | shut until its conditions pass | `open_when: Array[Condition]`; a body on layer 1 while shut; the navigation updates as a destructible's does |
| `FloorLink` (sim scene) | stairs, ladder, lift, pit-drop | `kind` (`STAIRS`, `LADDER`, `LIFT`, `DROP`), `to_floor`, `to_marker`, `open_when` |
| `Collectible` (sim scene) | a fixed find | `id`, `reward: Reward`, `saved` |
| Puzzle elements (interactables) | braziers, levers, plates, walls, bridges | `interaction_tags`, `state`, `rules: Array[ReactionRule]` |
| Backdrops | view-only | group `decoration` (3D.md, Wing scale) |

### ContentPool (`content_pool.gd`; `res://data/content_pools/content_pool_<name>.tres`)
`entries: Array[PoolEntry]` (inline: `scene: PackedScene`, `weight` 1, `min_difficulty_tier` 1, `max_difficulty_tier` 0 = none). A pack is a scene of its members (ENEMIES_AI.md); an elite entry's modifiers are rolled at spawn.

### DifficultyTier (`difficulty_tier.gd`; inline in the wing)
`index`, `display_name`, `enemy_modifiers: Array[StatModifier]` (source `&"difficulty_tier"`), `elite_modifier_count`, `loot_depth_bonus`, `wing_modifiers: Array[WingModifier]`, `party_scaling: PartyScaling` (null = the AllyTable's). Method `apply_to(enemy: Unit)`, called at spawn with `PartyScaling.apply_to()`.

### WingModifier (`wing_modifier.gd`; `res://data/wing_modifiers/wing_modifier_<name>.tres`)
`id`, `display_name`, `description`, `world_rules: Array[ReactionRule]`, `enemy_modifiers: Array[StatModifier]`, `enemy_statuses: Array[StatusEffect]`.

### KitFavor (`kit_favor.gd`; inline in the wing)
`tag: StringName`, `reason: String`, `weight: float` (1). If a favor ever needs a tag no class or ability carries, `ChampionData` gets `kit_tags` then.

### Quest (`quest.gd`; `res://data/quests/quest_<name>.tres`)
`id`, `title`, `kind` (`MAIN`, `WING`, `DUNGEON`, `CHAMPION`), `champion_id` (CHAMPION only), `starts_when: Array[Condition]` (found: a world state an NPC, a note or an object sets), `steps: Array[QuestStep]` (inline: `text`, `done_when: Array[Condition]`, `marker_id` for the map), `rewards: Array[Reward]`. No fail state (I6). A CHAMPION quest's crest and color come from its champion's `ChampionData` (Additions to existing data).

### Reward (`reward.gd`; inline)
One payload, shared by collectibles, quests and fixed chests: `kind` (`CODEX`, `COSMETIC`, `TITLE`, `NAMED_ITEM`, `KINDLING`, `CLUE`, `WORLD_STATE`), with its field (`codex_entry`, `named_item`, `amount`, `state`...).

### CodexEntry (`codex_entry.gd`; `res://data/codex/codex_<name>.tres`)
`id`, `title`, `text`, `scope` (`DUNGEON`, `WING`), `unlock_when: Array[Condition]`, `lens: Dictionary` (champion id → that champion's text; missing = `text`). Unlocked per account; each lens variant unlocks for its champion when that champion finds the entry (I7). NARRATIVE.md may grow it.

### Additions to existing data
| Where | Addition | Notes |
|---|---|---|
| `ReactionRule.Trigger` | `INTERACTED` | the ninth trigger: F on an interactable |
| GameplayEffect | `SetWorldStateGameplayEffect` (`state`, `value`, `mode` SET or ADD) | |
| `Condition.Kind` | `WORLD_STATE` (`state`, `comparison`, `value`) | the dungeon seeds `wing_<id>_cleared` states at a run's start, so the final boss's door reads the same kind |
| `SimMarker` | `marker_id` | a stable id per placement |
| `Room` | `depth` (LOOT's), set from the wing | |
| `ChampionData` | `crest_icon: Texture2D`, `crest_color: Color` | marks the champion's own quest line in the list and on the map (I6); placeholders until the art pass |
| input map | `map` | M, unbound today |
| Events | `world_state_changed(id, value)`, `checkpoint_reached(checkpoint)`, `checkpoint_rested(checkpoint)`, `floor_entered(floor_id)`, `arena_sealed(arena)`, `arena_cleared(arena)`, `wing_cleared(wing, tier)`, `quest_updated(quest, step)`, `codex_unlocked(entry)`, `collectible_found(collectible)` | reserved names |
| statuses | per content (`status_shrouded`...) | only with the content that needs them |

### Saving (`user://dungeons.cfg`; folds into PROGRESSION's one save)
- A `ConfigFile` (never a .tres), the `Progress` guard reused (a scene under `res://scenes/tests/` never reads or writes it). Per dungeon: the wings cleared (per account, I1), the highest difficulty tier each champion has cleared in each wing (per champion, I1), saved world states, collectibles found, quest progress (the step reached; kept between runs, I6; per account *(proposed reading)*), champion quest line progress (per champion, I6), the tracked quests, codex entries unlocked (per account) and their lens variants unlocked (per champion; I7), and the run in progress (I2: one per account, its `WingRun.to_dict()`, resumed at its last checkpoint).

| Find | Kept | Scope |
|---|---|---|
| Codex entries | forever | the account; a champion's variant, that champion (I7) |
| Lore pages, cosmetics, titles | forever | the account *(proposed)* |
| Statistics | forever | the account and each champion *(proposed)* |
| Hand-placed named gear | forever | each champion once *(proposed)* |
| Companion parts, clues | forever | the account, the companion bucket (Ryan: account-wide) |
| Shortcuts opened | forever | the account *(proposed)* |
| Keys, checkpoint unlocks | the run | *(proposed)*: a new run starts at the entrance (I2) |

### Runtime classes (`res://scripts/dungeons/`)
- **`WingRun`** (RefCounted): one run. `dungeon`, `wing`, `difficulty_tier`, `seed`, `rng`, `slot_picks` (content slot id → scene or empty), `dead` (ids dead for good), `fodder_dead` (content slot id → its stretch), `states` (world states), `found_checkpoints`, `last_checkpoint`, `floor_id`, `revealed` (the map per floor), quest progress, the party, (LOOT sync, approved 2026-10-03) `ground_drops` (floor id → the drops still on its ground: LOOT's `Loot.take_ground_drops()` / `restore_ground_drops()`). `to_dict()` / `from_dict()` for a resume.
- **`DungeonProgress`** (RefCounted): the saved record for one dungeon.

## Architecture / contracts
### Dungeons (autoload, `res://scripts/autoload/dungeons.gd`) *(proposed)*
- Registered after `Progress`, `Loot`, `Companions` and `Allies`, before `Audio` (which stays last).
- `start_run(dungeon, wing, tier)`, `get_run() -> WingRun`, `end_run(reason)` (`CLEARED`, `LEFT`), `is_wing_open(wing)` (per account), `get_unlocked_tiers(wing, champion)` (per champion), `get_state(id)`, `set_state(id, value)` (emits `world_state_changed`), `rest(checkpoint)`, `travel_to(checkpoint)`, `respawn()`, `change_floor(link)`, `saving_enabled`.
- Listens to `Events.unit_died` (marks kills for good and fodder kills in the run), `world_state_changed` (quests, codex), and the boss arena's clear (the clear: unlocks, clear XP, the counted run).

### Main and floors
- `Main` plays a floor of the current run instead of one fixed room: it builds the floor's sim from its layout(s) with the run's content slot picks and dead list applied (a dead marker or content slot spawns nothing), and places the party at the arrival point (the entrance, a checkpoint, a floor link's end). With no run (the sandbox, the tests, Start run until D1) it plays `room_scene` exactly as today.
- **One rebuild for every return:** a floor change, a rest, a death respawn and a fast travel are the same operation: fade out, build the floor from its layout plus the run's state, place the party, `reset_physics_interpolation()` on everything moved, fade in.
- `RoomLayout.build_sim()` gains a hook: a `ContentSlot` asks the run for its pick, and a marker the run lists dead is skipped.

### Puzzle pieces
- The interactable base (WORLD_INTERACTION's; *proposed* class `Interactable`, `res://scripts/interactables/interactable.gd`): `interaction_tags`, `state`, `rules`; `on_hit(ctx)`, `on_interact(player)` (WORLD_INTERACTION's signature) and, when impacts and hazards exist, their events, each passed to the matcher `Reactions` already runs, opened up for one element's rules. Effects aimed at Units go to the event's other unit.
- `SetWorldStateGameplayEffect.apply()` calls `Dungeons.set_state()`. Without a run (the sandbox) it uses a local table, so sandbox puzzles work.
- `Door`, `FloorLink`, content slots, quest steps and codex entries check their Conditions on `world_state_changed`, never every frame.

### HUD and the hub (functional, no art; UI.md polishes)
- The HUD: the quest list (top right: the main goal, then up to 3 tracked side quests, a champion line with its crest; I6), the minimap (a corner), the full map on M, a line when a checkpoint is found, the floor's name on a floor change, the difficulty tier, the fade.
- The hub: Start run opens a wing pick: dungeon → wings (locked, open, cleared; tiers unlocked; the wing's card with its favors, their reasons and which champions and pairs match; I5) → difficulty tier → Start.

## View
- **Spaces** are layouts and are their own look (3D.md, Rooms). A theme comes from its kit pieces and its lighting assets, like `lighting_default`; each space places one, so indoor and outdoor spaces share a wing (I10).
- **Backdrops** are view-only geometry in the `decoration` group: never in the sim, never `walkable` (so never under the floor pick or the height ray), never under a footprint. They may reuse kit pieces and art from earlier spaces, usually a cheaper copy, never another space's `RoomLayout` (its markers and footprints would enter the sim). See 3D.md, Wing scale.
- **Sim nodes with a view** (the generic mechanism: `view_scene`): `Checkpoint` (unlit, lit, a glow when rested), `Door` (shut, open, sealing), the arena's seal, `FloorLink` (the stairs are layout art; the link's view marks it: a lift platform, a ladder's glint), puzzle elements (a brazier's flame, a lever's position, a pressed plate, a bridge crumbling, a wall breaking), `Collectible` (a Pickup's view, a chest), and whatever a content slot spawns.
- **Floor drawings** (canvas layer 3, FloorOverlay): an arena's seal line and its spawn telegraphs (`Telegraph`), a plate's outline, a collapsing bridge's warning.
- **Screen overlay and HUD:** quest markers over their targets on screen, and at the screen's edge when off it (ScreenOverlay). The quest list, the minimap and the map are UI, drawn from sim data (the floor's outline from `ground_grid()` and its footprints), never from the 3D scene.
- **The fade** (floor changes, rests, respawns, travel) is a full-screen UI fade.
- **Environment** (I10): weather (rain, snow, mist) is view-only particles and lighting. Darkness or weather that changes play is a sim hazard with a status (Recommended for), whose look is its view. A theme's signature hazards get their looks through the view mechanism like any Hazard.
- `debug_draw` (on `Dungeons`): content slot ids and picks, stretches, world states, arena regions, the map grid.

## Audio hooks
Audio hooks: see AUDIO.md. To add when built (synthesized placeholders until real files): music and ambience per wing (AUDIO's open questions: per-dungeon music, explore and combat layers), a checkpoint found and a rest, a door sealing and opening, the arena's start and clear stingers (`main.gd`'s `room_cleared_sound` becomes the arena clear), boss music, a puzzle solved, a secret found, a collectible picked up, the floor-change whoosh, a quest updated (UI bus), the map opening and closing. Never audio-only (DECISIONS.md, Audio): each has a visual.

## How each edge case is handled
| Edge case | Handling |
|---|---|
| You die after killing fodder since your last rest | It stays dead; you respawn at the last checkpoint |
| You rest | Fodder killed in that checkpoint's stretch comes back, the same packs *(proposed)*; elites, bosses and quest or puzzle enemies don't |
| An enemy alive and hurt when you die | Back at its post at full health *(proposed)* |
| You die inside an arena | It re-arms whole: it starts at wave 1 next time *(proposed, following I8)* |
| You die to a boss | The boss resets to full and the arena re-arms; you respawn at the checkpoint outside; everything else is kept (I8) |
| A wipe with an ally | Both respawn at the checkpoint at full health (ALLIES.md) |
| A puzzle half done when you die | Its states stay; a puzzle may author its own reset |
| Resting with enemies on you | Not allowed while in combat (I2) |
| Drops on the ground when you change floors | Kept for the run, each where it lay (Ryan, 2026-10-03; LOOT.md) |
| Drops on the ground when you die, rest or fast travel | The rebuild puts them back where they lay (Ryan, 2026-10-03: the run remembers each floor's ground drops; leaving the run loses them; LOOT.md) |
| A pit-drop vs a pit | A pit-drop is a `FloorLink` (kind DROP): the party goes down with a fade, no damage *(proposed)*. A pit footprint keeps WORLD_INTERACTION's fall rule, and an enemy knocked into a drop falls as into a pit |
| The ally downed at a floor change | Comes along, still downed, next to the player *(proposed)* |
| The companion consumed at a floor change | The imprint carries on *(proposed)* |
| Back to hub mid-wing | The run ends; items, XP, saved states and finds are kept |
| Quitting the game mid-wing | Relaunching resumes the run at the last checkpoint with its kills, puzzles, finds and seed; enemies alive go back to their posts (I2) |
| A new run of a wing you've played before | Starts at the entrance with a new seed; checkpoints lit before don't carry over (I2) |
| The final wing played before the others are cleared | Playable; its boss door stays shut with a line saying why |
| A champion that matches none of a wing's favors | Plays and clears the wing; every main-path obstacle has an answer for every kit |
| A side quest unfinished when the run ends | Kept: the next run of that wing picks it up where it was (I6) |
| Untracking a quest | It leaves the on-screen list and stays on the map screen; it can't fail (I6) |
| A content slot whose pools have nothing for this tier | Stays empty (a validation warning) |
| A content slot group | Exactly `group_count` of its slots fill |
| The same seed | The same picks: a resume or a rest never rerolls |
| Tests | `Dungeons.saving_enabled` off in a test scene; seeded rng; a small fixture wing |

## Build order (proposed; one step per request)
**Before D1:**
- 3D pivot P-M (the view on by default; passed 2026-10-03), and the **P-spike** (3D.md, Wing scale), which decides one sim Room per floor or per space.
- WORLD_INTERACTION's approved pieces that have no build slot yet: interactables (layer 8), Hazards (layer 10 and the hazard triggers), `IMPACT` and `ImpactContext`, destructibles, `SurfaceTags` on footprints, and the pit step (every wing has pits).
- ENEMIES_AI's first steps (aggro and packs); LOOT L1–L7 (chests, drops and pickups).

Every step: the Knight's abilities, talents, enemies chasing and the HUD still work, and the sandbox and today's Start run play as before until D1 moves Start run to the wing pick. Logs go in CHANGELOG.md (the Dungeons section); this doc keeps one line per built step.

0. **D0 – Authoring cost (a measurement, no code).** A few spaces of each kind built with the P8 kit (a corridor, a hall, an arena, a vertical space with a plateau and stairs), each timed from empty to validated and playable. **Done means:** hours per space by kind (and per prefab), in CHANGELOG.md; Ryan sets the slice's total-hours cap, and its space count follows (I9).
1. **D1 – Wing data and floors.** `DungeonData`, `WingData`, floors, the `Dungeons` autoload and `WingRun`, Main playing a run's floors, `FloorLink` and the fade, each floor's state kept across floor changes (its ground drops too, through LOOT L7's `take_ground_drops()` / `restore_ground_drops()`), the hub's functional wing pick; `res://scenes/tests/dungeons_test.tscn` + `scripts/tests/dungeons_test.gd` and a fixture wing (two floors, three spaces). **Done means:** a run starts from the hub; stairs and a pit-drop change floors with a fade; what you killed is still dead when you come back; Back to hub ends the run; every other suite is unchanged.
2. **D2 – Checkpoints.** `Checkpoint` (find, rest, travel), the hybrid respawn rule and stretches, the death respawn, the ally and companion hooks, quitting mid-wing (I2). **Done means:** death keeps every kill; a rest brings back exactly its stretch's fodder; elites and bosses stay dead; travel goes to any found checkpoint on any floor; a wipe brings the ally back.
3. **D3 – Content slots and the shuffle.** `ContentSlot`, `ContentPool`, the seed, packs, elites, events, chests with their tables (LOOT.md), the depth. **Done means:** seeded tests: the same seed gives the same picks; picks match the weights within 1% over many rolls; groups fill exactly; tier ranges hold; a rest doesn't reroll.
4. **D4 – Arenas, doors and bosses.** `Arena`, `Door`, waves, sealing and clearing, the boss set-piece hooks, the final-wing lock, the clear (unlocks, clear XP, the counted run). **Done means:** an arena seals, runs its waves and opens; dying inside follows I8; a boss clear opens the wings and the next tier.
5. **D5 – The puzzle framework.** World states, `SetWorldStateGameplayEffect`, `Condition.Kind.WORLD_STATE`, `INTERACTED`, element rules, `world_state_changed`; the four kinds in a test space (a brazier lit by fire and by a carried torch, a plate pressed by a knocked enemy, a lever and a key door, a breakable wall with its clue, a lore order puzzle). **Done means:** each works by data alone after the framework; solved states survive death and rest; no code per puzzle.
6. **D6 – Quests, the codex, collectibles and secrets.** `Quest`, `CodexEntry`, `Reward`, `Collectible`, the quest list, a functional codex screen, hand-placed named gear (LOOT.md), companion parts and clues (COMPANIONS.md), keys and shortcuts, the save.
7. **D7 – The map.** The auto-map, fog, the minimap, floors, markers, travel from the map.
8. **D8 – Difficulty tiers and recommendations.** `DifficultyTier`, `WingModifier`, unlocks, stacking with party scaling, the loot depth bonus, `KitFavor` and the wing's hub card with its match marks (I5).
9. **D9 – The champion lens and quest lines.** The lens data (codex and dialogue variants), the champion quest line framework, the Knight's line in the slice wing; the hours one line takes are measured.

**Milestone D-M – The vertical slice** (after D9): one wing, polished, built by Ryan with the kit to D0's budget. Ryan plays it end to end at tier 1, then at tier 2.
**Done means:** Ryan's play test: the wing feels big and dense, packs and arenas read, checkpoints never cost progress, puzzles and secrets land, and a second run feels fresh.

## Out of scope
Procedural geometry (VISION.md, Scope); seamless streaming between floors (v1); the enemies themselves (ENEMIES_AI.md); the writing of codex entries, quests, dialogue and scenes (NARRATIVE.md, NPCS.md); the polished hub, map, quest and codex screens (UI.md); the one save (PROGRESSION.md); daily seeded challenges (a meta-progression candidate the run seed makes possible); co-op; the launch dungeon's content (after the slice).

## Open questions
### Interview (Ryan, five rounds, 2026-10-03: all answered)
1. ~~**I1 – Per champion or per account?** Is "wing cleared" (and so the wings it opens) and difficulty tier progress tracked per champion or per account?~~ Answered (Ryan, 2026-10-03): **wing clears per account** (any champion's clear of the first wing opens the others for all; the final boss opens once every other wing is cleared by anyone); **difficulty tier unlocks per champion** (better loot stays earned by the champion who wears it).
2. ~~**I2 – Checkpoints.** Placement and density; what resting does; whether resting costs anything; what happens on quitting mid-wing; whether a later run may start at a checkpoint found before.~~ Answered (Ryan, 2026-10-03): about **every 8–12 minutes**, at the start of each floor and right outside every boss arena (about 5–8 a wing); resting is **free** and refills health and resource, revives the ally, brings the companion back and opens travel, its only cost the stretch's fodder coming back, never mid-fight; quitting **resumes at the last checkpoint** (the advisor's default); a new run starts at the entrance.
3. ~~**I3 – The shuffle.** Exactly what's shuffled each run and what's fixed, and whether a difficulty tier changes the shuffle.~~ Answered (Ryan, 2026-10-03): besides which pack, elite or event fills a slot and chest rolls, **elite modifiers reroll**, **slots can stay empty**, **chest positions shuffle** and **mini-bosses vary** (2–3 candidates per side area); **higher tiers widen the pools** (tougher packs, slots that fill only from a tier, more elites).
4. ~~**I4 – Difficulty tiers.** How many; what unlocks each (a clear only, or something else); per wing or per dungeon.~~ Answered (Ryan, 2026-10-03): **five** per wing; clearing a wing at tier N unlocks tier N+1 **of that wing only** (a clear alone; no extra challenge).
5. ~~**I5 – Recommendations.** How a wing's recommendation is shown to the player, and whether a wing can name a recommended ally pairing.~~ Answered (Ryan, 2026-10-03): **the wing's hub card** lists its favors with their reasons and marks the matching champions and pairs; nothing extra in the wing; **pairs are derived from the tags**, never named by a wing.
6. ~~**I6 – Quests.** The quest data shape and the UI list (how champion quests are marked), and how a quest fails or is abandoned, if at all.~~ Answered (Ryan, 2026-10-03): **the main goal plus up to 3 tracked side quests** on screen, a champion's line with **its crest and color**, the full list on the map screen; **no quest fails**, one can be untracked, and **progress carries over** to the next run (a champion's line per champion). The data shape stays Claude's proposal (Data, Quest).
7. ~~**I7 – The codex.** How the codex unlocks, and whether any story beat ever blocks progress.~~ Answered (Ryan, 2026-10-03): an entry **unlocks on find, account-wide**, and a champion's own variant when that champion finds it; **no story beat ever blocks the main path** (short, skippable scenes; lore puzzles guard optional secrets only).
8. ~~**I8 – Bosses.** How a boss encounter meets checkpoints, arenas, difficulty tiers and "dying never undoes progress".~~ Answered (Ryan, 2026-10-03): a checkpoint right outside every boss arena; dying **resets the boss** to full and re-arms the arena; everything else the run earned is kept. A boss isn't progress until it's dead.
9. ~~**I9 – The authoring unit.** The smallest reusable thing a level builder places, and the authoring budget the slice wing is held to.~~ Answered (Ryan, 2026-10-03): **the space, with prefabs inside it** (stretches and floors are groups of spaces); the slice is held to **a total-hours cap** Ryan sets after D0, its space count following from the measured cost (a shorter wing rather than a rushed one).
10. ~~**I10 – Themes.** Hazard identity per theme, and how a wing's environment (indoor or outdoor, lighting, weather) ties into the 3D look.~~ Answered (Ryan, 2026-10-03): **2–3 signature hazards per theme** on the shared Hazard system, plus the shared basics; **lighting assets per theme, picked per space**; **weather is look only**, and darkness or weather that changes play is a sim hazard with a status.

### Claude's other proposals (written in above as *(proposed)*; Ryan can overrule any)
1. **Names:** `DungeonData`, `WingData`, `WingFloor`, `Dungeons` (autoload), `DungeonProgress`, `WingRun`, `ContentSlot`, `ContentPool`, `PoolEntry`, `Arena`, `ArenaWave`, `Door`, `FloorLink`, `Checkpoint`, `Collectible`, `Reward`, `Quest`, `QuestStep`, `CodexEntry`, `DifficultyTier`, `WingModifier`, `KitFavor`, `Interactable`; `SetWorldStateGameplayEffect`, `Condition.Kind.WORLD_STATE`, `ReactionRule.Trigger.INTERACTED`; the Events listed in Data; the `map` action on M; `user://dungeons.cfg`; source ids `difficulty_tier`, `wing_modifier_<id>`. Vocabulary: **wing**, **floor** (a wing's storey), **space**, **prefab** (Ryan's I9 answer; the word to confirm), **content slot**, **pool**, **pack**, **arena**, **stretch**, **rest**, **fast travel**, **clear**, **difficulty tier**, **wing modifier**, **world state**, **puzzle element**, **element rule**, **collectible**, **secret**, **clue**, **backdrop**, **champion quest line**, **main goal**, **seed**.
2. **After the boss**, an exit opens and the wing stays open to explore. (The start at the entrance: answered, I2.)
3. **The stretch** decides which fodder a rest brings back; enemies alive at your death (or a quit) go back to full; the run's record saved as it changes. (What resting does: answered, I2.)
4. **Arena waves**, and an arena re-arming whole when you die inside it, following I8's boss rule.
5. **The map** drawn from the sim outline, a 12 m reveal, M pausing.
6. **Content slot kinds** (PACK, ELITE, MINI_BOSS, EVENT, CHEST), groups and tier gates; packs as scenes; a mini-boss dead for good like a boss; prefabs in `scenes/rooms/prefabs/`. (What's shuffled: answered, I3.)
7. **The puzzle framework's shape**: element rules on interactables, `INTERACTED`, world states read through `Condition`, saved states; every secret reachable by every champion.
8. **The difficulty tier table** (TARGET) and wing modifiers never lowering the champion's own stats.
9. **`KitFavor`** matched on `champion_class` and ability tags; kit-favoring mechanics are sim.
10. **The champion quest line cap** (one per wing, 15 min, one alcove of at most 6 × 6 m, one named reward).
11. **Depth** = the wing's base + the space's offset + the tier's bonus; chest tables; a boss table and chest; floor drops kept for the run.
12. **Each champion claims each hand-placed named item once.**
13. **A pit-drop is a floor link**, not a pit.
14. **Clear XP** and **a clear as the counted run** for eggs.
15. **The ally and the companion at floor changes** (comes along downed; the imprint carries on).
16. **A tier with an ally** is one the player's champion has unlocked, and a clear unlocks the next tier for the player's champion only.
17. **A boss at a higher tier** takes the tier's modifiers and its tier-gated attack patterns like any enemy.
18. **Quest progress** saved per step, per account for wing and dungeon quests (the champion's own line per champion, as Ryan said); world states a later step needs are saved states; `ChampionData.crest_icon` and `crest_color` for the champion's mark.
19. **Save scopes** (Data, Saving): lore pages, cosmetics, titles and shortcuts per account; statistics per account and per champion; keys and checkpoint unlocks for the run only; saved world states per account.

### Also open (not in this interview)
- **Hand-placed named gear vs LOOT's named items.** LOOT's named items are Legendary or Artifact and belong to one champion, but a secret's chest holds one fixed item and "goes to the picking champion". Options: (a) the chest holds a different named item per champion (content cost per champion per secret); (b) *(proposed)* a new kind of named item that fits any champion: a named Unique or Exotic with a fixed name, fixed sigils and fixed affixes (`NamedItem` with no `champion_id`), so every champion finds the same thing there.
- **Leaps and gating** (3D.md, Leaps; Ryan, 2026-10-03: a leap goes over walls): a wall thinner than a champion's leap range (the Knight's artifact: 5 m) doesn't keep that champion out, so a secret or a locked door's far side that must hold is a separate room or space, or farther than any leap reaches. Which (per secret, or a rule for every gate) is decided with the layouts.
- **The champion quest line's "one-of-a-kind named reward"** (written "unique named reward" before the LOOT sync; "Unique" is a rarity): a named item of that champion's (power for that champion only, allowed), or a named cosmetic or title? At 8 dungeons of 3 wings, items would be about 24 per champion, against the Knight's 5 today.
- **The pacing in runs:** TALENTS' assumed run (about 20 minutes, 100 kills) set "every talent in about 29 runs", LOOT's "a legendary every 3 runs", COMPANIONS' eggs (3 runs) and bond (about 4.4 runs to bond 5). A wing is 45–90 minutes, 2–4.5 times that. Per-kill rates keep the hours the same if kill density matches, but the run counts shrink; every "runs" number should be re-measured against a wing in the slice.
- **What's revealed on the map:** kept per run, or kept forever (per account or per champion)?
- **Doors, room locking and room transitions** (WORLD_INTERACTION.md, Open questions) are answered here (doors, arenas, floor links); WORLD_INTERACTION.md can point to this doc.

### For other docs
- **ENEMIES_AI.md:** a roster per dungeon on shared behaviors (behaviors are reusable data, rosters content); roaming packs (proximity notice, a pack aggroing together, leashes) versus arena enemies (spawning in with a telegraph, aggro at once); elite modifiers and their pool (a difficulty tier says how many); attack patterns gated by difficulty tier; mini-bosses and bosses as set pieces with phases; which enemy attacks are `melee`; kill tags for quest counters and the bestiary; the sleep distance from the P-spike.
- **NARRATIVE.md / NPCS.md:** the codex's content and its per-champion lens; quest writing (wing, dungeon and champion lines); NPC dialogue with per-champion variants; the scenes that change per champion; voice scope; lore puzzles' answers.
- **PROGRESSION.md:** `user://dungeons.cfg` folds into the one save; clears and difficulty tiers (I1); the codex as an account collection; the statistics pages; the run in progress (I2).
- **UI.md:** the hub's wing pick, the map and minimap, the quest list, the codex screen, the "Recommended for" display (I5), the fade.
- **WORLD_INTERACTION.md** (applied 2026-10-03): interactables gain element rules and a state (Interactables, Puzzle elements); plates and signature hazards are Hazards; pit-drop links next to the pit rule; secrets behind destructibles; its doors question answered here; a build slot for interactables, Hazards, impacts, destructibles, `SurfaceTags` and pits before D1 (open, Ryan's call).
- **STATS.md** (applied 2026-10-03): its open question (enemy scaling by depth through `&"dungeon_scaling"`) now carries this doc's proposal: `&"difficulty_tier"` modifiers, depth changing loot only.
- **TALENTS.md, LOOT.md, COMPANIONS.md:** the per-run pacing numbers re-measured against a wing.
