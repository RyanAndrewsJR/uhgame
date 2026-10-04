# LOOT.md: Items, Rarities, Affixes, Sigils, the Inventory, Drops and Pickups

**Read when:** the task involves items, item bases, affixes, rarities, sigils (the Unique and Exotic effects), the Knight's legendaries and artifact, equipping and unequipping, the inventory and its save, the materials bucket, drop tables, dungeon depth and magic find, pickups, dropping and trashing items, or the sandbox loot list.
**Depends on:** CLAUDE.md, VISION.md (pillar 6, Game structure), CONVENTIONS.md, STATS.md (StatModifier, scoped modifiers, `magic_find`, `pickup_radius`), ABILITIES.md (Augments: FLAG / EVENT / REPLACE; ReactionRule, GameplayEffects, recasts), COMBAT.md (HitContext, `Events.unit_died`), CHAMPIONS.md (ChampionData, the Knight's kit), TALENTS.md (talent FLAGs on item variants, `Progress`, the save pattern), WORLD_INTERACTION.md (collision layer 9 `pickup`, Kill credit), AUDIO.md (hooks), 3D.md (views, terrain and airborne, leaps), ALLIES.md (the ally's gear and kills), DUNGEONS.md (depth, chests, floors and their drops).
**Used by:** UI (the real inventory and equip screen, item tooltips), DUNGEONS (depth, run rewards, where drops land after a pit fall; hand-placed named gear, chest tables per content slot, difficulty tier loot quality: From the dungeon), ENEMIES_AI (which drop table an enemy uses), WORLD_INTERACTION (destructibles drop from a drop table), PROGRESSION (one save for everything), ACHIEVEMENTS (much later), COMPANIONS (the rarity ladder and roll bands, `Affix` for quirks, `ItemRoller.roll_rarity()`, `DropTable`, `Pickup`, the keep-current hold: its CO1 needs L1, CO2 L2's hold, CO6 L7), ALLIES (lending generic gear to the AI ally, named drops split between the party, party kills dropping; needs L2).

## How to read this doc
Same as TALENTS.md: MUST (never change without asking Ryan), TARGET (start value and allowed range), FREE (your call; tiebreaker: VISION.md's decision priorities). Ryan's spec of 2026-10-01 is MUST. Claude's proposals were answered by Ryan the same day: all approved, with two changes (an Exotic gets a second sigil instead of better rolls; an Artifact's affixes are always at their maximum) and a new word for the Unique / Exotic effect, **sigil** (Open questions). All numbers are TARGET placeholders until the play tests.
**Status:** L1 (items: data and rolling), L2 (equipping, the inventory and the save), L3 (SandboxLoot: equipping by hand), L4 (sigils) and L5 (named items, part 1: the framework and the FLAGs) passed, 2026-10-03; L6 (named items, part 2: the REPLACE variants, the leap) passed 2026-10-04, see CHANGELOG.md; Homeward Greaves' return is a blink since ABILITIES AB15 (built 2026-10-04); L7 (drops and pickups) passed 2026-10-04; L7b (dropping and trashing items, sorting; Ryan 2026-10-04) passed 2026-10-04; L-M in progress (Ryan's play sessions, started 2026-10-04; his inventory and progress backed up first, beside the saves in `backups/`). **Synced 2026-10-03** with the 3D pivot (its cleanup C3 deleted the 2D looks), COMPANIONS.md, ALLIES.md and DUNGEONS.md, with Ryan's four answers (leaps go over everything, ally kills drop everything, a wing's floors remember their ground drops, the drag lifts its target) and Claude's proposals, marked (LOOT sync) and approved by Ryan the same day, an ally's kill counting as the champion's kill (Open questions, The LOOT sync).

## Player experience
A slime dies and something pops out of it: a grey gem, a green one, now and then a blue one. A moment later it's yours, without breaking stride, the way Hades hands you obols: no key, no menu, no stopping. Most drops are numbers: a helm with more health, a ring with crit. Further up the ladder a purple item carries a sigil ("lightning strikes", "a burst of speed on a kill"), and a teal one carries two. Then, every few runs, an orange beam: a Knight-only legendary that changes an ability. Cleave becomes a wave, Lunge gets a way back, Judgement drags its target to you. One gold beam is the chase: an artifact, always perfect, that turns Judgement into a leap. Everything you pick up is kept, for that champion, forever, and you can put it on whenever you like, mid-fight included.

## References
- Diablo 2 / 4. Take: item bases, rarities, affixes rolled in ranges, "increased" vs "more", magic find raising the odds of better rarities with less effect on the top tiers (D2's diminishing returns), deeper = better drops, legendaries that change a skill (D4 aspects), named items with fixed affixes and rolled values (D4 uniques). Don't take: click-to-loot, inventory Tetris, an inventory cap, town portals.
- Hades. Take: currency pickups (Darkness, obols) collected on proximity, instantly, never interrupting movement. Don't take: a reward per room chosen from doors (that's DUNGEONS' call).
- World of Warcraft. Take: the rarity ladder topped by Artifact, and rarity colors players already read.
- League of Legends. Take: an item's passive that doesn't stack with itself ("UNIQUE"), the same rule our augments already follow.

## Principles
1. **Numbers below, behavior on top.** Common–Rare change numbers. Unique adds one sigil and Exotic two (each reacting to something that happens). Legendary and Artifact add one ability augment (changing what an ability does). Past Rare, each step up adds behavior, not bigger numbers, until the named tiers (pillar 2, build variety; pillar 6, looting).
2. **Built from what exists.** Stats are `StatModifier`s and STATS.md's scoped modifiers; sigils are EVENT augments holding one `ReactionRule`; legendaries are FLAG or REPLACE augments. No new stat architecture, no new GameplayEffect kind, no new reaction trigger (Ryan, 2026-10-01).
3. **Champion-specific only at the top.** Common–Exotic items fit any champion. Legendary and Artifact items belong to one champion and only drop for that champion (answers STATS.md's open question).
4. **Hades pickup, Diablo rules.** Getting loot never costs movement (pillar 3); what the loot is follows Diablo (VISION.md, What we take).
5. **Never lost.** An item picked up is saved at once, kept through death and leaving a run (VISION.md, Death). Only the player's own choice removes one: dropping it back on the ground or trashing it (Ryan, 2026-10-04; Dropping and trashing items).
6. **Swap any time, never a free heal.** Gear changes whenever the player wants, mid-run included; a swap can't be used to heal.
7. **Tuning is data.** Rarity weights, depth growth, magic find, affix ranges and drop chances live in .tres files (CLAUDE.md, Conventions).

## Current code
- Stats: `magic_find` (0, min 0) and `pickup_radius` (0, LoL units) are registered and are UnitStats fields; since L7 a kill's roll reads the killer's `magic_find` and `PickupComponent` reads `pickup_radius` (the Knight: 200 u, 64 px). `gold_find` too (no gold yet; nothing reads it).
- Augments (ABILITIES AB8): `AbilityComponent.add_augment(augment, source_id)` / `remove_augments_from(source_id)`. The same augment id from several sources counts once. EVENT augments add their rules as unit rules under `augment_<id>`; a rule with an empty `required_ability_scope` takes the augment's `scope` (an empty scope leaves it empty: the rule fires for every matching event, and no ability tooltip lists it). REPLACE: the first active one per ability wins. FLAG: the ability lists it in `supported_flags`.
- `StatsComponent.add_modifiers()` / `remove_modifiers_from(source_id)`; source ids for items are `item_<number>` (CONVENTIONS.md).
- `SandboxAugments` (sandbox only): four fake items (`item_test_<augment id>`) toggled with keys 1–4: `lunge_stuns`, `cleave_wave` (REPLACE → `knight_q_cleave_wave.tres`, which supports both Cleave talent FLAGs), `judgement_reset`, `cleave_casts_lunge`.
- `Progress` (TALENTS T4): the pattern to copy: records per champion, a `ConfigFile` at `user://progress.cfg` with one section per champion id, saving off by itself in a scene under `res://scenes/tests/`. `Progress.get_tracked_player()` is the Player whose casts and kills count.
- `Events.unit_died(unit, ctx)`: `ctx.source` is the killing hit's source. `Enemy.passive` marks a training dummy (no XP, no kill).
- `HealthComponent.set_max_health()`: a raised max adds the difference to current; a lowered max clamps. (So unequipping and re-equipping a health item would heal; see Equipping.)
- `Room` (`room.gd`): no depth (L3 adds it). Rooms put units under a y-sorted `Entities` node. A room built in 3D (`RoomLayout`, 3D.md) makes its `Room` at load (`build_sim()`), so an export set by hand on a Room only reaches tile rooms; Start run plays a room built in 3D (`main_layout.tscn`).
- Collision layers 1–7, 9 and 11 are named in `project.godot` (6 `pit`, 7 `low_obstacle`, 11 `ledge`; 9 `pickup` since L7, WORLD_INTERACTION.md).
- **The 3D view** (3D.md): the sim draws nothing on screen since the 3D pivot's cleanup C3. A sim node shows through its view (`view_scene`, `get_view_scene()`, the group `view_source`), or as a floor drawing (canvas layer 3, `FloorOverlay.DRAWING_VISIBILITY_BIT`, debug drawings included), or on `ScreenOverlay` (numbers, bars). The HUD is a CanvasLayer and shows as before.
- **Terrain** (3D.md, P8–P9): fences and rubble (layer 7) block walking and displacements, not dashes; ledges (layer 11) block walking, displacements and the ghosted dash (`GHOST_KEEP_MASK` = walls and ledges); pits (layer 6) are carved from the navigation. An **airborne** unit (`status_airborne`, a knock-up) that's displaced ignores 6, 7 and 11 (`AIRBORNE_IGNORED_MASK`; walls still stop it), lands through `WorldQuery.resolve_valid_position()` / `push_out()`, and its view arcs (`UnitView`). The leap is built since L6 (`MovementComponent.leap()`; Abilities and the toolkit).
- CONVENTIONS reserves `Events.item_equipped(unit, item)` and `item_unequipped(unit, item)`; `events.gd` doesn't declare them yet.
- **Built in L1 (2026-10-03):** `Item`, `ItemRarity`, `ItemBase`, `Affix`, `LootTable` (`loot_table_default.tres`), `DropTable` (regular, elite), `ItemRoller`, the 7 bases and 15 affixes, `loot_test.tscn`.
- **Built in L2 (2026-10-03):** `EquipmentComponent` on `player.tscn` (`Player.equipment`), `Events.item_equipped` / `item_unequipped`, `set_gain_on_max_raise()` on HealthComponent and ResourceComponent, `ChampionInventory`, the `Loot` autoload (`user://inventory.cfg`), the Player equipping its saved gear at load. Nothing puts items in an inventory or on a player in play yet (SandboxLoot is L3; drops L7), so the game plays as before.
- **Built in L3 (2026-10-03):** `SandboxLoot` in both sandboxes (the list; J / Shift+J, U, K, P, [ / ]), `Room.depth` and `RoomLayout.depth` (copied by `build_sim()`), `Loot.get_depth()`. Gear set in the sandbox is saved and worn in Start run; with an empty inventory the game plays as before.
- **Built in L4 (2026-10-03):** the sigil pool (`augment_sigil_storm_strike.tres`, `augment_sigil_bloodrush.tres`, `augment_sigil_expose.tres` in `loot_table_default.tres`), `status_bloodrush.tres`, `status_exposed.tres`, `AbilityAugment.name_suffix`, the " of <suffixes>" names, the sigil tooltip lines. Unique items roll one sigil, Exotic two different ones.
- **Built in L5 (2026-10-03):**
  - **Data:** `NamedItem` and its validation, `ChampionData.named_items` (`get_named_item()`), and the Knight's Tidebreaker, Oathbound Plate and Chains of Judgement (`data/items/`).
  - **Rolls:** Legendary and Artifact rolls from the champion's list, with the Exotic fallback (`ItemRoller.pick_named()`, `make_named()`).
  - **Saving and equipping:** items save by named id; a named item can be worn once; Loot gets `debug_grant_named_items()`, and SandboxLoot's P uses it.
  - **Undying:** `status_undying`, Iron Resolve's `iron_resolve_undying`, and the `undying` rule in `Unit.on_hit()`.
  - **The drag:** Judgement's `judgement_drag`, through the new toolkit `Ability.pull_airborne()`.
  - **Cleave Wave** now costs Cleave's 20 Fury.
- **Built in L6 (2026-10-04):**
  - **Data:** Homeward Greaves and The Last Verdict (`data/items/`; all five named items listed in `knight.tres`), their REPLACE augments `lunge_return` and `judgement_leap`, the variants `knight_e_lunge_return.tres` ("Homeward Lunge") and `knight_r_judgement_leap.tres` ("Judgement Leap"). The Knight's Artifact rolls are The Last Verdict.
  - **Code:** `CastContext.sequence`; Lunge's return part; `judgement_leap.gd`; `MovementComponent.leap()` and `get_leap_landing()` (the room's navigation); `UnitView`'s leap arc.
- **Built in L7 (2026-10-04):**
  - **Data:** layer 9 named `pickup`; `scenes/loot/pickup.tscn`; `PickupComponent` on `player.tscn`; `knight.tres` `pickup_radius` 200; `sound_loot_drop`, `sound_loot_drop_legendary`, `sound_loot_pickup` (synthesized placeholders) on the loot table's rarities and `pickup_sound`; `scenes/view/pickup_view.tscn`.
  - **Code:** `Pickup`, `PickupComponent`, `PickupView`; `Loot`'s drops (the kill listener, `drop()`, `collect()`, `item_picked_up`, `take_ground_drops()` / `restore_ground_drops()`, `drops_enabled`); the HUD's loot lines; SandboxLoot's K dropping pickups. Kills by the tracked player drop in play (Start run and both sandboxes).
- **Built in L7b (2026-10-04):** dropping and trashing items (`ChampionInventory.remove()`, `Loot.can_remove()` / `drop_from_inventory()` / `trash_item()` / `needs_trash_confirm()`, `item_dropped` / `item_trashed`, `LootTable.trash_confirm_from`, `Pickup`'s hold), SandboxLoot's L, X and O (sorting), the hub's Clear inventory.

## Rules
### Rarities (MUST: the ladder and what each has, Ryan 2026-10-01; counts and bands TARGET; colors FREE)
In order, lowest first:

| Rarity | Has | Affixes | Roll band | Color |
|---|---|---|---|---|
| Common | stats | 1 random | 0.00–0.35 | light grey `#c8c8c8` |
| Uncommon | stats | 2 random | 0.10–0.50 | green `#4cd04c` |
| Rare | stats | 3 random | 0.25–0.65 | blue `#4d8cff` |
| Unique | stats + 1 sigil | 3 random | 0.35–0.75 | purple `#b44dff` |
| Exotic | stats + 2 different sigils | 3 random | 0.35–0.75 | teal `#26d9c4` |
| Legendary | stats + 1 ability augment (FLAG or REPLACE), one champion's | 3 fixed | 0.55–0.95 | orange `#ff8c1a` |
| Artifact | stats + 1 ability augment (FLAG or REPLACE), one champion's | 4 fixed | always the maximum (no roll) | pale gold `#f0d890` |

- **Roll band**: each affix rolls a 0–1 roll, then its value is placed inside the rarity's band of the affix's range: `value = lerp(affix.min, affix.max, lerp(band_min, band_max, roll))`. Common to Rare: more affixes *and* higher values going up (Ryan's spec).
- **Unique vs Exotic** (Ryan, 2026-10-01): the same stats (affix count and band). An Exotic's step up is a **second sigil, different from its first**: two distinct effects, not bigger numbers. A sigil is the same on either.
- **Legendary vs Artifact** (Ryan, 2026-10-01): both are named items with one ability augment. A Legendary's affixes roll in its band. An **Artifact's affixes are always at their maximum**: no random number is drawn for them (band 1.00–1.00). An Artifact also has one more fixed affix and carries its champion's biggest ability change. Each champion has a few legendaries and one artifact.
- **Companions use this ladder** (COMPANIONS.md; Ryan, 2026-10-03): a companion copy's rarity sets only how many quirks it has (1 / 2 / 3 / 3 / 4 / 4 / 4) and their roll band, the bands above. No sigils, no named items.

### Stats: affixes and implicits (MUST: stat-only, StatModifier-based, Ryan 2026-10-01)
- An **affix** is one `StatModifier` (stat, type FLAT / PERCENT_ADD / PERCENT_MULT, scope) with a value range. STATS.md's math and limits apply unchanged; the item's modifiers go in under its source id like any other source.
- Scopes: plain stats, `hit:<tag>` / `target:<tag>` damage scopes, and `tag:<tag>` ability-param scopes ("increased core ability damage", "mobility cooldowns −10%"; VISION.md: scoped modifiers reward focusing on a tag). **Random affixes never use an `ability:<id>` scope**: that would make a Common champion-specific. Named items may (their own ability only).
- An affix lists the **item slots** it can roll on (`Affix.slots`; move speed only on boots). An item never rolls the same affix twice.
- An **implicit** is a fixed modifier every item of a base has, whatever the rarity (a sword's attack damage). Not rolled.
- Values round to the affix's `step` (1 for flat health or armor, 0.01 for percents) at roll time, so the tooltip number is the real number.
- **The roll is saved, not the value**: an item stores each affix's 0–1 roll (an Artifact's is always 1); the value is recomputed from the current data. A retune of an affix range or a band reaches every item already owned (the same reason TALENTS stores level + XP-into-level).
- **A roll is kept to 4 decimals** (`Item.ROLL_DECIMALS`, `Item.quantize_roll()`; found in L1): Godot writes a raw `randf()` value (float32) and some 17-digit doubles to text inexactly, so a roll reloaded from the save could differ in its last digits. A 4-decimal roll comes back exactly (measured over 200,000 rolls: 0 mismatches; 6 decimals: 8). Rolls are quantized when rolled and when read; 10,001 levels are far finer than any affix's step.
- **No sustain affixes and no ability power affix in the first pool**: COMBAT.md allows life on hit, life steal and regen from items, but the Knight's low-health judgment call (CLAUDE.md) isn't settled; they join the pool with ENEMIES_AI.md's enemies. An AP affix waits for a champion that uses AP (it would roll dead on the Knight).

### Sigils: Unique and Exotic (MUST shape, Ryan 2026-10-01)
- **Sigil** is the word for this effect (Ryan, 2026-10-01: never "proc", which keeps only COMBAT.md's meaning, a hit caused by another hit).
- A Unique has exactly one sigil; an Exotic has exactly two, always different. They're picked from the sigil pool at roll time. Start with three (The sigil pool, below); the pool stays at 2–4 until Ryan asks for more, and never below 2 (an Exotic needs two).
- A sigil **is an EVENT `AbilityAugment` holding one `ReactionRule`** (HIT, UNIT_DIED or STATUS_APPLIED, the triggers that are built), added with `add_augment(augment, item source id)`. Its rule goes on the unit under `augment_<sigil id>`, exactly as an EVENT augment's always has.
- A sigil **reacts to something happening; it never changes how an ability casts or behaves**. So it never uses a FLAG or a REPLACE, and it's champion-agnostic: its augment's `scope` is empty (any matching event) or a `tag:` scope, never `ability:<id>`.
- The same sigil from two items counts once (the augment rule). Two Storm Strike rings are one Storm Strike; an Exotic with Storm Strike and Bloodrush plus a Unique with Storm Strike give Storm Strike once and Bloodrush.
- A sigil's damage goes through `DealDamageGameplayEffect`, which makes COMBAT.md's `proc`-tagged hit (can't crit, `proc_coefficient` 0), so it never triggers a HIT rule or on-hit, and can't chain into itself.

### Ability augments: Legendary and Artifact (MUST shape, Ryan 2026-10-01)
- Exactly one augment per named item, **FLAG or REPLACE** (never EVENT: that's a sigil), scoped `ability:<id>` to one of its champion's four abilities. Unique and Exotic never touch an ability directly; Legendary and Artifact are the only tiers that do.
- Champion-specific: a named item names its champion. It drops only for that champion and only that champion can equip it.
- The Knight: 4 legendaries + 1 artifact, every ability with at least one (The Knight's named items).
- **A REPLACE variant from an item supports every talent FLAG of the ability it replaces**, with its own take (TALENTS.md's rule, unchanged); the talents test already checks every variant .tres.
- **A champion's named items for the same ability share one item slot**: then two of them can never be equipped together, so two REPLACEs (or a FLAG and a REPLACE that would need to know about each other) never fight over one ability. The Knight's two Judgement items are both Gloves.
- **A named item can be equipped once**: a second copy (another drop) can't go in the other ring slot at the same time. Moot for the Knight (no named rings), built anyway.
- Fixed affixes: a named item lists which affixes it has; a Legendary's values roll in its band, an Artifact's are their maximum. It may also carry fixed modifiers scoped to its own ability (Chains of Judgement's range).
- **As built (L5, 2026-10-03):**
  - **Affix slots and data.** A named item's fixed affixes ignore the pool's slot lists, because they're authored for the item: Oathbound Plate's tenacity is on a chest, and both Gloves have crit damage. Validation checks everything else on the NamedItem.
  - **The data wins over the save.** An item is saved with `"named": <id>`, and its base, rarity and affix list come from the NamedItem. Only the rolls come from the save, matched by affix id. An affix with no saved roll gets the band's middle (0.5); a saved affix the item no longer lists is dropped (a warning for each). An Artifact's rolls are always 1.
  - **Reading back.** `Item.from_dict(d, table, champion)` reads a named item only through its champion. Without the champion, or for one without that id, the entry stays raw in the save.
  - **Rolling a named rarity.** `ItemRoller.pick_named()` picks by `drop_weight` among the champion's named items of the rarity, in the slot when one is asked for, and falls back to an Exotic.
  - **Tooltips.** A named item's tooltip shows its fixed modifiers as "+50% Cast Range (Judgement)", then its augment as "Name: description", then its `flavor` in quotes. Flavor is empty for now (lore waits for NARRATIVE.md, Open questions).
  - **The second copy.** It's refused in another slot, but it may replace the first in that copy's own slot.
  - **Undying.** It caps the hit's `taken_damage` too, so the number shows what was really taken. Shields absorb first, and DoT ticks are capped like hits. While it lasts, a pale gold aura shows (`VFX.aura`, Iron Resolve's own).
  - **The drag.** It runs through the toolkit's `Ability.pull_airborne()` (the AB11 guard keeps `displace()` out of the Knight's scripts). Its gap is the two pathing radii plus 8 px, which match the bodies. The hit lands on a timer of the drag's time, and the cast stays in progress meanwhile, so the Knight is rooted 0.15 s longer. `judgement.gd`'s hit moved unchanged into `_strike()`.
  - **Cleave Wave's cost.** It had no cost, a leftover from before Cleave's Fury cost; L5 gave it Cleave's 20 Fury. Your 2026-09-29 call was "the same as Cleave", and TALENTS.md has Thrifty Edge reaching the wave.

### Item slots (MUST, Ryan 2026-10-01)
Weapon, Helm, Chest, Gloves, Boots, Ring (two equipment slots), Amulet: eight equipment slots, seven item kinds. A ring goes to the first empty ring slot, else replaces ring 1 (FREE).
- **Weapons don't change the combo in this build** (Ryan, 2026-10-01): the Weapon slot is a stat-and-augment slot like the others, and the champion's combo stays ChampionData's. "A champion's combo comes from its weapon, limited by its class" stays COMBAT.md's open question; every weapon base fits every class until it's answered.

### Inventory and saving (MUST shape, Ryan 2026-10-01)
- **One pool per champion**, unlimited, persistent. Not a run bag and a stash: the same list mid-run and at the hub. Never shared between champions (VISION.md, Roster). The one exception: the player lends generic gear to an AI ally for a run, and a lent item never leaves the lender's pool (With an AI ally, below; ALLIES.md).
- Items **can be equipped, unequipped and swapped any time, mid-run included** (unlike talents, fixed for the run).
- **Saved like TALENTS' progress**: a `ConfigFile` at `user://inventory.cfg` (its own file, so a corrupt or huge inventory never touches talent progress), one section per champion id: `next_uid`, `items` (one Dictionary each: `uid`, `base`, `rarity` as a word, `affixes` as [affix id, roll] pairs, `sigils` as ids, `named` id), `equipped` (equipment slot → uid), `materials`, and with ALLIES `ally_gear` (With an AI ally, below). Never a .tres (it can carry scripts).
- **The materials bucket** (Ryan, 2026-10-01): `materials: Dictionary[StringName, int]` (material id → count), in the record and the save, always empty. Reserved for LOOT v2's crafting currencies; nothing reads or writes it yet. Companion materials (kindling) never go here: they're account-wide, saved with the companions, and spent only on companions (COMPANIONS.md; Ryan, 2026-10-03), so gear crafting never shares power between champions.
- Saved when an item is added, equipped or unequipped, when the tracked player leaves the tree and when the window closes. A scene under `res://scenes/tests/` never reads or writes it (the `Progress` guard, reused).
- **A saved item the data no longer knows** (its base or named item deleted) is skipped at load with a warning, and its raw entry is written back unchanged, so a data fix brings it back. An unknown affix or sigil id drops that line only (warning).
- No selling or salvage in this build (LOOT v2). Picked-up items are never lost, unless the player drops or trashes one (L7b; Dropping and trashing items, below; Ryan, 2026-10-04). **Drops still on the ground** (Ryan, 2026-10-03): in a wing, each floor remembers them for the run, so a floor change, a rest, a death respawn or a fast travel (DUNGEONS.md's rebuilds) puts them back where they lay; leaving the run loses them (From the dungeon). Outside a wing (today's single rooms), leaving or restarting the room loses them.

### Equipping (MUST: the hooks, Ryan 2026-10-01)
- `EquipmentComponent.equip(item, slot)` applies the item through the hooks already in use, under the item's source id `item_<uid>`: its implicits and affixes as copies through `StatsComponent.add_modifiers()`, each of its augments (its sigils, or its named augment) through `AbilityComponent.add_augment(augment, source_id)`. `unequip(slot)` calls `remove_modifiers_from(source_id)` and `remove_augments_from(source_id)`: the unit is restored exactly.
- Equipping into a filled slot unequips the old item first (a swap). It fires `Events.item_equipped(unit, item)` / `item_unequipped(unit, item)` (reserved in CONVENTIONS).
- `can_equip(item, slot) -> String` (`""` = yes): wrong slot kind, another champion's named item, that named item already equipped. As built (L2): also no item, a slot that doesn't exist, the item already worn in another slot (a worn ring can't move to the other ring slot: unequip it first), and another worn item with the same uid (removing one by source id would strip both).
- **A live swap never heals or refills** (Ryan, 2026-10-01): a raised `max_health` adds the difference to current health, so taking a +80 health helm off and on at 300 / 730 would heal 80. During a live equip or unequip, current health and resource keep their value (clamped to the new max). At load (the Player spawning with its saved gear) the old rule applies, so a champion still starts full. As built (L2): a swap puts the new item on before taking the old one off, so the max never dips below current during it and a full-health swap keeps its health (only the switch would have lost it: a removal clamps first).
- Augments are read at cast start (ABILITIES.md): a swap mid-cast doesn't change that cast; a REPLACE's slot keeps its cooldown and charges; a status a cast already applied (Undying) runs out on its own.
- Mid-run equipping has no screen yet: the function is the contract, and `SandboxLoot` is the hand-driven entry point until UI.md builds the inventory screen (hub and pause menu).

### Dropping and trashing items (MUST: Ryan's four answers and sorting, 2026-10-04; the rest Claude's, approved when Ryan started L7b; built in L7b, 2026-10-04)
Ryan (2026-10-04): the player can drop an item and trash an item, to keep a big inventory tidy. Companion copies get the same later (COMPANIONS.md: its Release already lets a spare copy go for kindling).
- **Inventories stay unlimited** (MUST): nothing is ever refused for lack of room. Dropping and trashing are for tidying, not for making space.
- **Dropping puts the item back on the ground** (MUST): it leaves the inventory (saved at once) and becomes a `Pickup` at the player's feet. **It isn't picked back up until the player walks out of their pickup radius and comes back.** On the ground it's like any drop: lost when the player leaves the room or the run, kept by a wing's floor through its rebuilds (From the dungeon), taken back with a new uid.
- **Trashing removes the item for good** (MUST): out of the inventory and the save, with no undo. **Common to Rare go at once; Unique, Exotic, Legendary and Artifact need a second press** to confirm.
- **A worn item can't be dropped or trashed** (MUST for trashing; for dropping too, approved): unequip it first. The refusal says so ("Worn: unequip it first").
- **The drop pops like a kill's**: from the player's feet to a landing spot 12–28 px away by the same rule (walkable from there, never over a pit), with its rarity's drop sound when it lands, so the player sees where it went. The landing gives the dropper's collect circle no pickup: the pickup is **held** for that unit (`Pickup.held_for`) until its circle leaves the pickup (`area_exited`), and only then can it take it back. Any other collector could take it at once (none exists before ALLIES).
- **Dropping never asks to confirm**: the item can be picked back up until the player leaves; trashing is the final one.
- **The confirm**: the first press on a Unique-or-better item only asks ("Trash Tidebreaker (Legendary)? X again"); a second press on the same item within 3 s trashes it. Any other key, a cursor move or the 3 s running out cancels.
- **No HUD line and no sound** for dropping or trashing (SandboxLoot's result line says what happened); UI.md gives them their look and clicks with the inventory screen.
- **Where:** SandboxLoot (the only inventory screen until UI.md): **L** drops the highlighted item, **X** trashes it (both free: no input action and no sandbox script reads them, checked 2026-10-04). The hub's debug row gets **Clear inventory** (`Loot.reset()`, planned for "a later hub button" since L2), which needs a second click, so the milestone can start from an empty inventory (L-M).
- With an AI ally (ALLIES.md): a lent item can't be dropped or trashed while the ally wears it (ALLIES' step adds the check).
- **Sorting** (Ryan, 2026-10-04: with O): **O** in SandboxLoot cycles the list's order: the inventory's own (pickup order, oldest first), **by slot** (Weapon, Helm, Chest, Gloves, Boots, Ring, Amulet; the best rarity first within a slot), **by rarity** (best first; then by slot). Ties keep the pickup order. A view only: the inventory and its save keep their order. The cursor stays on the item it was on, and the header says the order ("   By slot").
- **As built (L7b, 2026-10-04):**
  - **The hold ends two ways:** when the unit's collect circle reports the pickup gone (`area_exited`), and, checked every physics tick, when that circle no longer reaches it (by distance, half a pixel of slack) or the unit is gone. The tick check is the one that matters when the player walks off while the drop still hops: it isn't collectable yet then, so no `area_exited` comes, and without the check the hold would outlive the walk away (measured: the drop then stayed untaken when he came back). A put-back ground drop isn't held (the hold isn't saved).
  - **The threshold is data:** `LootTable.trash_confirm_from` (Unique). `trash_item()` takes an optional `unit` for the worn check, like `can_remove()`; the record's `equipped` covers the tracked player either way.
  - **The waits are real time** (`Time.get_ticks_msec()`): SandboxLoot's `trash_confirm_time` and the hub's `clear_confirm_time` (both 3 s, exports). Any key but X cancels a waiting trash, also one SandboxLoot doesn't use (the result line says "Trash cancelled"), and so does a pickup moving the cursor.
  - **The hub's Clear inventory:** "Click Clear inventory again to empty the Knight's inventory (23 items, for good)." in the detail line, then "Emptied the Knight's inventory (23 items)."; an empty inventory only says so. `Loot.reset()`, so unreadable saved entries go too.
  - **Layout:** the keys line now wraps to two rows; the worst case (a named item worn and highlighted mid-list, sorted, with a refused trash as the result) ends at y 306, above the ability bar's 322.

### Drops (MUST shape, Ryan 2026-10-01; numbers TARGET)
- **Kill credit, for now**: a kill's drop goes to whoever landed the last hit, `Events.unit_died`'s `ctx.source`. When WORLD_INTERACTION's Kill credit is built (pits, wall slams, hazards crediting whoever caused them), drops move to it. Only kills by the tracked player, or by its AI ally (ALLIES.md), drop anything, and every drop goes to the player; a kill with no source drops nothing; a training dummy (`Enemy.passive`) drops nothing. **An ally's kill counts as the champion's kill** (Ryan, 2026-10-03): it drops everything a player's kill does (items, companions and kindling; COMPANIONS.md), and it counts for the player's champion like its own kill (ALLIES.md, XP, talents and gear; TALENTS' kill counter). The game still tracks that the ally landed it. L7 builds the check as "the tracked player" (no ally exists yet); ALLIES' step that adds the ally widens it (`Allies.is_party_member()`).
- **Which table**: a `DropTable` per kind of enemy. Until ENEMIES_AI.md decides where enemy data lives, a temporary `LootTable.drop_table_by_unit` maps the dead unit's UnitStats file name to its table (slime → regular, slime_elite → elite), the same stand-in TALENTS used for XP. A non-passive enemy not in it uses the regular table.
- **Depth**: until DUNGEONS.md defines runs, the depth is the `depth` export on the Room the kill happened in (default 1). (LOOT sync) A room built in 3D gets it from `RoomLayout.depth` (default 1), which `build_sim()` copies onto the Room it makes. Whether a space's depth offset lives on the Room or per space waits for the P-spike's answer (one sim Room per floor or per space; 3D.md, Wing scale): with one Room per floor, `Loot.get_depth(node)` asks the Room for the depth at the kill's point. DUNGEONS.md (written 2026-10-03) *(proposed there)*: in a wing the Room's depth is set at load from the wing's base depth, the space's offset and the difficulty tier's loot depth bonus (From the dungeon, below); the formulas here don't change.
- **The roll**, per kill: chance = `min(1, item_chance × (1 + chance_per_depth × (depth − 1)))`; on a hit, `item_count` items, each with its own rarity roll. Rarity weight = `rarity_weights[r] × (1 + rarity_growth[r] × (depth − 1)) × (1 + magic_find × magic_find_effect[r])`, where `magic_find` is the killer's stat (0.5 = +50%). Magic find changes only the rarity weights (Ryan's spec), never the drop chance.
- Then: Common–Exotic pick a base (weighted), their affixes (weighted among those the slot allows) and, for Unique / Exotic, their sigils (one / two different). Legendary / Artifact pick one of the killer's champion's named items of that rarity (weighted); a champion with none of that rarity gets an Exotic instead. **With an AI ally** the champion is either party champion, 50/50, whichever of them landed the kill (Ryan, 2026-10-03; With an AI ally, below).

| Number | Regular (slime) | Elite | Notes |
|---|---|---|---|
| `item_chance` | 0.10 (0.05–0.2) | 1.0 | |
| `chance_per_depth` | 0.05 | 0 | |
| `item_count` | 1 | 1 (1–2) | |
| Weights at depth 1: C / U / R / Un / Ex / L / A | 59.5 / 26 / 11 / 2 / 0.8 / 0.6 / 0.1 | 0 / 36 / 40 / 10 / 7 / 6 / 1 | each sums to 100 |
| `rarity_growth` per depth (both) | 0 / 0.05 / 0.1 / 0.15 / 0.2 / 0.2 / 0.25 | same | |
| `magic_find_effect` (per rarity) | 0 / 1 / 1 / 1 / 1 / 0.5 / 0.5 | | Diablo 2's smaller effect on the top tiers |

- **As built (L7, 2026-10-04):**
  - **When:** a kill is rolled at once (`Loot.roll_kill_drop()`), while the dead unit's table, room and killer are known. Its pickups are added at the end of the frame (`drop()`, deferred), because a death can come inside a physics callback (a hurtbox's overlap), where the space can't be queried and no Area2D can be added. A corpse's parent gone by then drops nothing.
  - **The credit** is `Loot.get_drop_credit(unit, ctx)`: the tracked player (`Loot.get_tracked_player()`, the same Player as Progress's), a unit of another team, not a training dummy, the player with a champion.
  - **Drops in tests:** `Loot.drops_enabled` is off by itself in a scene under `res://scenes/tests/` (`are_drops_enabled()`, decided at the first kill, the save guard's way), so the seven suites that kill slimes with a tracked Knight stay deterministic (a 10% drop would change their pickups and sound logs from run to run). A test that sets it, on or off, wins. `drop()` works either way.

Against TALENTS' assumed run (96 regular kills, 4 elites) at depth 1 with no magic find, that's about 13.6 items a run: 5.7 Common, 3.9 Uncommon, 2.7 Rare, 0.6 Unique, 0.36 Exotic, 0.3 Legendary (the first in about 3 runs; all four in about 28, close to the talents' 29) and 0.05 Artifact (about 20 runs). Deeper is faster. Re-measured when DUNGEONS.md defines a run. (DUNGEONS.md, 2026-10-03: a run is a wing of 45–90 minutes, 2–4.5 times the assumed 20-minute run, so at the same kill density these counts per run grow by that much while the rate per hour stays the same; re-measured in the slice wing.)

### Pickups (MUST: layer 9, proximity, instant, Ryan 2026-10-01; numbers TARGET)
- A dropped item is a small `Pickup` scene: an `Area2D` on collision layer 9 (`pickup`), masking nothing. It holds one rolled item. (COMPANIONS CO6 adds two other payloads: a dormant companion copy or an amount of kindling, collected the same way.)
- The player collects on proximity: a `PickupComponent` (an `Area2D` on the Player masking layer 9) whose circle radius follows the `pickup_radius` stat (the Knight: 200 u, 64 px, STATS.md's planned value; TARGET 100–250 u). Overlap = collected at once: no key, no prompt, no pause in movement (Hades' currency pickups).
- **It pops first** (Ryan, 2026-10-01): the pickup hops from the corpse to a spot 12–28 px away (a random direction; up to four tries, else the corpse's spot) over 0.3 s, and becomes collectable when it lands. Without it a melee kill inside the 64 px radius would vanish its drop the same frame, and the player would never see what dropped. The arc is VFX; the spot is decided at once. (LOOT sync) A spot is good if the player could walk to it from the corpse: nothing on layers 1, 7 or 11 between them (no wall, fence or cliff edge; a ray with `WorldQuery`'s line-of-sight check on that mask) and not over a pit (layer 6). A corpse over a pit (an enemy that fell, WORLD_INTERACTION.md) drops at the nearest walkable point outside the pit (`WorldQuery.push_out()`).
- Collecting: the item joins the champion's inventory (saved), the pickup is freed, the HUD shows a line in the rarity's color ("Rare: Iron Helm", "Legendary: Tidebreaker") for 2 s, and a pickup sound plays. Flying toward the player is a later feel pass (Ryan, 2026-10-01).
- **Look: its view** (3D.md; the 2D look planned here first can't show since the cleanup's C3). The `Pickup` stays a sim node (its Area2D on layer 9) and draws nothing; it declares a `view_scene`, and its look is a view that never changes gameplay state (View, below): a small gem in the rarity color with a slow bob; Legendary and Artifact also get a light beam in their color so they read across a room. The landing plays the rarity's drop sound (none for Common).
- Drops stay on the ground until collected. In a wing, a floor's rebuild (a floor change, a rest, a death respawn, a fast travel) puts them back where they lay; leaving the run loses them (Ryan, 2026-10-03; Inventory and saving, From the dungeon).
- **As built (L7, 2026-10-04):**
  - **The hop is the view's.** The sim pickup stands at its landing spot from the moment it drops (`Pickup.hop(from, spot)` before it enters the tree), with `monitorable` off until `pop_time` has passed; `PickupView` draws the arc. So a drop still hopping is already where it will lie (what `take_ground_drops()` reports), and `Loot.collect()` refuses a pickup that hasn't landed.
  - **The landing spot** (`Pickup.pick_landing()`, `is_good_landing()`): a ray from the origin to the spot on layers 1, 7 and 11 (`Pickup.WALK_BLOCKING_MASK`), and the pickup's 6 px circle clear of those and of pits. As written, a pit between them doesn't stop the hop; only landing over one is refused (Open questions).
  - **A corpse over a pit:** the drop's origin is the nearest walkable floor of its room, the closest point of the room's navigation (the leap's rule), which the pits carve, 12 px clear (`Loot.get_drop_origin()`). `WorldQuery.push_out()`, which the plan named, searches only out to twice the radius (14 px for a pickup), so a corpse in the middle of a 3 m pit would have dropped inside it. Outside a Room (or before its navigation is ready) it's `push_out()`, else the corpse's spot.
  - **The collector:** each Player gets its own circle (the scene's shape is shared), at least 1 px (`PickupComponent.MIN_RADIUS_PX`: a champion without a pickup radius still takes what it walks over). A dead unit takes nothing.
  - **Collected:** the pickup is marked taken and freed, the item goes in with a new uid (saved), then `item_picked_up`, then the pickup sound. `Loot.get_ground_pickups(node)` lists what's still on a room's ground.

### With an AI ally (MUST, Ryan 2026-10-03; ALLIES.md)
- **Every drop goes to the player**, who equips the ally.
- **Generic gear (Common to Exotic) is lent** from the player's inventory. A lent item stays in the player's pool (it's never moved, never shared), only one of the two champions wears it at a time, and the ally's set is remembered per champion pair: `ChampionInventory.ally_gear` (ally champion id → equipment slot → [owner, uid]; owner `lent` = an item of this inventory, `own` = one of the ally's named items), saved with the rest of the record. *(proposed, ALLIES.md)* Equipping a lent item on yourself takes it back from the ally, mid-run included, like any swap.
- **The ally's Legendary and Artifact items come from its own inventory** (its own named items: only that champion can equip them, as always).
- **A named drop is for either party champion, 50/50**, so the legendary rate per run stays the same, split between the two. The ally's go straight into its own inventory (saved), and the HUD line names whose they are. *(proposed, ALLIES.md)* A picked champion with no named item of that rarity passes the roll to the other, then to an Exotic.
- Magic find is the killer's. Every other rule here holds for the ally (a live swap never heals, augments read at cast start).

### From the dungeon (DUNGEONS.md; MUST: the three items below, Ryan 2026-10-03; the shapes *(proposed)*)
- **Hand-placed named gear** (MUST): a fixed named item at the end of a hard secret in a wing, **guaranteed** (always there, not rolled), going to the picking champion's inventory like any loot (a `Pickup`, or a chest that drops one). It powers only the champion who claims it, so the no-shared-power rule holds (VISION.md, Meta-progression). *(proposed)* Each champion can claim each one once (DUNGEONS.md's save marks it).
  - **Open:** today a named item is a Legendary or an Artifact that belongs to one champion, so one fixed chest can't hold "the" item for whoever opens it. *(proposed)* A new kind of named item for secrets that fits any champion: a named Unique or Exotic with a fixed name, fixed sigils and fixed affixes (rolled in its band), as a `NamedItem` with an empty `champion_id` and no ability augment. The other option: the chest holds a different named item per champion (content per champion per secret). Ryan decides (DUNGEONS.md, Also open).
- **Chests and content slots** (MUST: chest and loot rolls change each run): a chest rolls from its own `DropTable` (`drop_table_chest_<name>.tres`, the same resource) through `ItemRoller.roll_drop()` at the Room's depth and the opener's magic find. Which chest stands in a `CHEST` content slot is picked from the slot's pools at the run's start (DUNGEONS.md, Contents); the chest names its table.
- **Difficulty tier loot quality** (MUST: each tier improves loot quality): *(proposed)* a tier adds its loot depth bonus to the depth every drop and chest roll uses (DUNGEONS.md, Difficulty tiers: +0 / +2 / +4 / +6 / +8, TARGET), so `chance_per_depth` and `rarity_growth` carry it and no formula here changes.
- **Floor drops** (Ryan, 2026-10-03: remembered on the floor): a wing's floors keep the drops on their ground for the run, through every rebuild (a floor change, a rest, a death respawn, a fast travel), each where it lay; leaving the run loses them. (LOOT sync) Before a rebuild tears a floor down, `Loot.take_ground_drops(room) -> Array` hands DUNGEONS each drop still on the ground (`{"item": item.to_dict(), "pos": Vector2}`; a pickup still hopping counts at its landing spot); `WingRun.ground_drops` keeps them per floor id (with the run's resume data), and after the floor is built, `Loot.restore_ground_drops(room, drops)` puts each back as a landed, collectable `Pickup`. Built in L7 (tested on a room), called by DUNGEONS D1. As built: taking frees the pickups; putting back lays each in the room's `Entities` with no hop and no drop sound, reads its item for an optional `champion` (null = the tracked player's, for its named items), and skips an entry it can't read, with a warning.
- *(proposed)* **Bosses** use their own drop table (`drop_table_boss.tres`), and a wing's clear may open a boss chest. Numbers come with the slice.

### The sandbox equip entry point (MUST: exists in this build, Ryan 2026-10-01)
- `SandboxLoot` in `sandbox.tscn`, the same posture as `SandboxAugments` and `SandboxTalents`: a list on screen, raw keys read in that sandbox-only script (no input action). (LOOT sync) Also in the 3D sandbox (`sandbox_3d.tscn`, played from `sandbox_main_layout.tscn`), as the other two are since P8: the only sandbox with terrain, where The Last Verdict's leap and the drag get tried.
- Unlike `SandboxTalents`, it **changes the real save** (Ryan, 2026-10-01): it's the only equip screen until UI.md, so gear set there must carry into Start run. (LOOT sync) A scripted harness never writes it: it sets `Loot.saving_enabled = false` first, as it does for `Progress` and `Settings` (3D.md: scripted runs never save).

## The sigil pool (Unique and Exotic; numbers TARGET)
| Sigil (id) | Name suffix | What it does | Built from |
|---|---|---|---|
| Storm Strike (`sigil_storm_strike`) | Storms | Hits have a 15% chance (× the hit's `proc_coefficient`) to call lightning on the target: 30 + 40% AD magic damage | HIT, owner SOURCE, effect target AFFECTED, `chance` 0.15 → `DealDamageGameplayEffect` 30, `ad_ratio` 0.4, MAGIC, tag `lightning` |
| Bloodrush (`sigil_bloodrush`) | the Hunt | A kill gives +30% move speed for 2 s (refreshes) | UNIT_DIED, owner SOURCE, effect target OTHER → `ApplyStatusGameplayEffect` `status_bloodrush` (its own id, so it never overwrites Iron Resolve's haste) |
| Expose (`sigil_expose`) | Ruin | Crowd control you apply also Exposes the enemy for 3 s: +15% damage taken | STATUS_APPLIED, `required_status_tags` [`cc`], owner SOURCE, effect target AFFECTED → `status_exposed` (`incoming_damage` PERCENT_MULT +0.15; tags `exposed`, `debuff`, never `cc`, so it can't trigger itself) |

- Each is one `data/augments/augment_sigil_<name>.tres` (EVENT, empty scope). The Knight triggers all three: every hit (Storm Strike), kills (Bloodrush), Judgement's stun, Iron Resolve's slow and Tackle's stun (Expose; Staggered isn't `cc`, so Lunge alone doesn't).
- Item names (FREE): a base's name plus "of" and its sigils' suffixes: "Iron Helm of Storms" (Unique), "Band of the Hunt and Ruin" (Exotic). With three sigils there are three Exotic pairs.
- **As built (L4, 2026-10-03):**
  - A sigil's suffix is `AbilityAugment.name_suffix` (new, empty for every other augment), so a sigil is authored in one file. Validation needs one on every sigil in the pool.
  - An Exotic's name lists its suffixes in its sigils' rolled order ("Iron Helm of Ruin and the Hunt").
  - Each sigil is picked with the same odds.
  - A sigil's tooltip line is "Name: description" ("Bloodrush: A kill gives you +30% move speed for 2 s."). The descriptions are plain text, like every augment's, so a retune of their numbers edits the text too.
  - **Chain limit 2 on all three rules**, so a sigil answers what its wearer causes one link into a chain: a free cast's hits (Cleave's free Lunge), a kill by a Storm Strike bolt, crowd control applied by another reaction. None of them can feed itself: a bolt is a proc (coefficient 0), Bloodrush isn't crowd control, and neither is Exposed.
  - `status_bloodrush` plays Iron Resolve's haste sound when it lands (`sound_status_haste_apply`).
  - Neither the bolt nor Exposed has a look of its own yet. The bolt shows as its magic damage number, and Exposed shows only as bigger numbers. A look would be view work: a bolt pillar like `VFX.impact()`'s, an Exposed mark like Staggered's.
  - An item rolled before L4 keeps no sigils: the save keeps what was rolled, and sigils are never added later.

## The Knight's named items (names placeholder; numbers TARGET)
Five items, one per ability plus the artifact (approved by Ryan 2026-10-01). Each changes how its ability is used, not just its numbers. All keep the kit's shared pieces (Staggered, Cleave's heal, the Fury payoff), and each works with every Knight talent.

| Item (id) | Rarity, slot | Ability | Augment | What it does | Fixed affixes |
|---|---|---|---|---|---|
| Tidebreaker (`knight_tidebreaker`) | Legendary, Weapon | Q Cleave | REPLACE `cleave_wave` (exists) | Cleave becomes a piercing wave of force (AB-M's Cleave Wave): reach instead of the wide sweep. Whirling and Rending Cleave already have their wave takes | attack damage, core damage, crit chance |
| Oathbound Plate (`knight_oathbound_plate`) | Legendary, Chest | W Iron Resolve | FLAG `iron_resolve_undying` | Iron Resolve also makes the Knight **Undying** for 1.5 s (1–2.5): his health can't drop below 1. Iron Resolve becomes the button you save for the hit that would kill you | max health, armor, tenacity |
| Homeward Greaves (`knight_homeward_greaves`) | Legendary, Boots | E Lunge | REPLACE `lunge_return` | Lunge as before, then **recast within 2.5 s** to **blink** back to where it started, at once (over walls too, onto the nearest walkable floor; hits nothing; Ryan, 2026-10-04: a blink instead of L6's dash back, built in ABILITIES AB15 2026-10-04; refused while rooted, the window running on). In, Cleave, out. The trade: the cooldown starts only after the return or when the window ends | move speed, mobility cooldown, armor |
| Chains of Judgement (`knight_chains_of_judgement`) | Legendary, Gloves | R Judgement | FLAG `judgement_drag` + `cast_range` PERCENT_ADD +0.5 (`ability:knight_judgement`; 450 → 675 u, 144 → 216 px) | After the channel, the target is **dragged to the Knight** (0.15 s), lifted through the air like a knock-up so fences, cliffs and pits don't stop it (walls do; Ryan, 2026-10-03), then struck. Pull an elite out of its pack, or a sniper off its perch | attack damage, attack speed, crit damage |
| The Last Verdict (`knight_last_verdict`) | **Artifact**, Gloves | R Judgement | REPLACE `judgement_leap` | Judgement becomes a **leap**: target a point within 500 u (160 px), crouch 0.2 s, leap there (0.3 s through the air, over units, fences, cliffs, pits and walls, landing on the nearest walkable floor; 3D.md, Leaps; Ryan, 2026-10-03), and every enemy within 220 u (70 px) of the landing, in sight, takes Judgement's damage (150 + 100% AD + 20% of its missing health) and the 0.75 s stun. Trades the rooted channel on one target for a pack-wide execute that moves you | attack damage, crit chance, crit damage, ability haste (all at their maximum) |

The two Gloves are the same choice from opposite ends: bring the target to the Knight, or the Knight to the targets.

### With the Knight's talents
| Item | Talent | Result |
|---|---|---|
| Tidebreaker | all Cleave talents | As TALENTS.md, Cleave (Whirling Wave, Rending Wave; Thrifty Edge and Long Reach reach the wave). Wave casts count as Cleave casts |
| Oathbound Plate | Challenge / Bulwark | Undying is added on top of either (Challenge: Stagger + empower + Undying; Bulwark: haste + shield + Undying). Quick Recovery: Undying more often |
| Homeward Greaves | Tackle | Part 1 tackles the first enemy (stun), part 2 returns. Free from a lock-on to get back out |
| Homeward Greaves | Twin Lunge | Two charges, each with its return (shorter hops). ABILITIES' rule: with more than one charge, the recharge pauses during a sequence |
| Homeward Greaves | Long Lunge / Quick Footing | Reach both ways / cooldown, through `variant_of` |
| Chains of Judgement | Shockwave | The splash hits around the target where it lands: next to the Knight |
| Chains of Judgement | Executioner, Long Arm, Swift Verdict | Unchanged; Long Arm's +30% adds to the item's +50% (PERCENT_ADD: +80%) |
| The Last Verdict | Shockwave | Its take: a second ring out to 370 u (118 px) at 50% damage with a 0.5 s stun; the talent's data zeroes the missing-health term on every hit (Shockwave's trade) |
| The Last Verdict | Executioner | Data: 40% of missing health, no stun (the Fury bonus still adds 0.5 s), and `augment_judgement_reset` reaches the leap through `variant_of`: a kill on landing resets the cooldown (chain leaps) |
| The Last Verdict | Long Arm / Swift Verdict | Leap range / cooldown |

- **Fury payoff** on both Judgement items: The Last Verdict's .tres has Judgement's conditional bonus (RESOURCE_AT_LEAST 60: +30% damage, +0.5 s stun) and consumes the Fury once if any landing hit gets through, as `judgement.gd` does.
- **Undying and the low-health judgment call**: Oathbound Plate deepens the Knight's low-health rewards (CLAUDE.md, Open judgment call). Ryan kept it (2026-10-01): it's an item a player chooses, and its numbers wait for ENEMIES_AI.md like the rest.
- **New content the set needs**: 5 named item .tres; augments `iron_resolve_undying` (FLAG), `lunge_return` (REPLACE), `judgement_drag` (FLAG), `judgement_leap` (REPLACE); variants `knight_e_lunge_return.tres` (script `lunge.gd`, `variant_of` `knight_lunge`, `recast_count` 1, `recast_window` 2.5, `supported_flags` `lunge_stuns` + `lunge_tackle`) and `knight_r_judgement_leap.tres` (script `judgement_leap.gd`, `variant_of` `knight_judgement`, POINT, cast time 0.2 s, tags `ultimate` `area` `dash` ((LOOT sync) `leap` instead of `dash`: it goes through the air, not along the ground), `supported_flags` `judgement_shockwave`); `status_undying.tres` (tags `undying`, `buff`); code: the `undying` rule in `Unit.on_hit()`, Iron Resolve's flag, Lunge's return part, Judgement's drag (airborne), `judgement_leap.gd` and the leap itself (`MovementComponent.leap()`, 3D.md, Leaps), and `CastContext.sequence` (below).

## Item bases and the affix pool (numbers TARGET; names FREE)
| Base (id) | Slot | Implicit |
|---|---|---|
| Longsword (`item_base_longsword`) | Weapon | +6 attack damage |
| Iron Helm (`item_base_iron_helm`) | Helm | +40 max health |
| Mail Hauberk (`item_base_mail_hauberk`) | Chest | +10 armor |
| Leather Gloves (`item_base_leather_gloves`) | Gloves | +5% attack speed |
| Leather Boots (`item_base_leather_boots`) | Boots | +3% move speed |
| Band (`item_base_band`) | Ring | none |
| Pendant (`item_base_pendant`) | Amulet | none |

One base per slot to start; more bases per slot are content, not code.

| Affix (id) | Modifier | Range (roll 0 → 1) | Slots |
|---|---|---|---|
| `affix_max_health` | `max_health` FLAT | 20 → 100 | helm, chest, boots, ring, amulet |
| `affix_attack_damage` | `attack_damage` FLAT | 2 → 10 | weapon, gloves, ring, amulet |
| `affix_attack_speed` | `attack_speed` PERCENT_ADD | 0.03 → 0.15 | weapon, gloves, ring |
| `affix_crit_chance` | `crit_chance` FLAT | 0.02 → 0.08 | weapon, gloves, ring, amulet |
| `affix_crit_damage` | `crit_damage` FLAT | 0.08 → 0.35 | weapon, amulet |
| `affix_armor` | `armor` FLAT | 4 → 20 | helm, chest, gloves, boots |
| `affix_magic_resist` | `magic_resist` FLAT | 4 → 20 | helm, chest, boots, amulet |
| `affix_move_speed` | `move_speed` PERCENT_ADD | 0.02 → 0.08 | boots |
| `affix_ability_haste` | `ability_haste` FLAT | 3 → 15 | helm, ring, amulet |
| `affix_tenacity` | `tenacity` FLAT | 0.04 → 0.15 | helm, boots |
| `affix_damage` | `damage_increase` FLAT | 0.03 → 0.12 | weapon, ring, amulet |
| `affix_core_damage` | `damage_increase` FLAT, scope `hit:core` | 0.06 → 0.25 | weapon, gloves, amulet |
| `affix_basic_attack_damage` | `damage_increase` FLAT, scope `hit:basic_attack` | 0.06 → 0.25 | weapon, gloves, ring |
| `affix_mobility_cooldown` | `cooldown` PERCENT_ADD, scope `tag:mobility` | −0.04 → −0.15 | boots |
| `affix_magic_find` | `magic_find` FLAT | 0.05 → 0.25 | helm, ring, amulet |

## Data (Resources)
Names checked against CONVENTIONS.md (reserved names, vocabulary) and approved by Ryan 2026-10-01; CONVENTIONS gets them in L1. Resource scripts in `res://scripts/data/`.

### ItemRarity (Resource, `item_rarity.gd`; inline in the LootTable)
| Field | Type | Notes |
|---|---|---|
| `rarity` | `Item.Rarity` | `COMMON`, `UNCOMMON`, `RARE`, `UNIQUE`, `EXOTIC`, `LEGENDARY`, `ARTIFACT` |
| `display_name`, `color` | `String`, `Color` | the table above |
| `affix_count` | `int` | random affixes (Common–Exotic); 0 for named rarities (their list is fixed) |
| `roll_min`, `roll_max` | `float` | the band; equal = no random draw (Artifact: 1.0 / 1.0) |
| `sigil_count` | `int` | 0; Unique 1; Exotic 2 (always different) |
| `is_named` | `bool` | Legendary, Artifact: rolled as one of the champion's named items |
| `magic_find_effect` | `float` | × magic find on this rarity's weight |
| `drop_sound` | `SoundEvent` | played when a pickup of this rarity lands; null = silent (Common) |

### LootTable (Resource, `loot_table.gd`; `res://data/loot_tables/loot_table_default.tres`)
The global rules, held by `Loot.table`.
| Field | Type | Notes |
|---|---|---|
| `rarities` | `Array[ItemRarity]` | 7, in `Item.Rarity` order (validated) |
| `item_bases` | `Array[ItemBase]` | the 7 bases |
| `affixes` | `Array[Affix]` | the random affix pool |
| `sigils` | `Array[AbilityAugment]` | the sigil pool (3 EVENT augments; at least 2, each with a `name_suffix`, validated; filled in L4). An empty pool also validates: its Unique and Exotic items roll without sigils |
| `drop_table_by_unit` | `Dictionary` (StringName → DropTable) | **temporary, until ENEMIES_AI.md**: `{&"slime": regular, &"slime_elite": elite}` |
| `default_drop_table` | `DropTable` | a non-passive enemy not in the map |
| `pickup_sound` | `SoundEvent` | on collect |
Methods: `get_rarity(r) -> ItemRarity`, `get_base(id)`, `get_affix(id)`, `get_sigil(id)`, `get_drop_table(unit)`, `get_validation_errors()`.

### ItemBase (Resource, `item_base.gd`; `res://data/item_bases/item_base_<name>.tres`)
`id` (`&"item_base_longsword"`), `display_name`, `slot: Item.Slot` (`WEAPON`, `HELM`, `CHEST`, `GLOVES`, `BOOTS`, `RING`, `AMULET`), `implicits: Array[StatModifier]`, `drop_weight: float` (1).

### Affix (Resource, `affix.gd`; `res://data/affixes/affix_<name>.tres`)
| Field | Type | Notes |
|---|---|---|
| `id` | `StringName` | `&"affix_attack_damage"` |
| `stat`, `type`, `scope` | as `StatModifier` | the modifier it makes; `scope` never `ability:` (validated) |
| `min_value`, `max_value` | `float` | the range at roll 0 and roll 1 (min may be above max: −0.04 → −0.15) |
| `step` | `float` | rounding step of the value (1, 0.01) |
| `slots` | `Array[Item.Slot]` | where it can roll |
| `weight` | `float` | 1 |
| `text` | `String` | tooltip template with `{value}` / `{value%}` ("+{value%} core ability damage"); empty = built from the stat registry's name and format |
Methods: `get_value(band_min, band_max, roll) -> float`, `make_modifier(value, source_id) -> StatModifier`, `get_line(value) -> String`, `get_validation_error() -> String`.

### NamedItem (Resource, `named_item.gd`; `res://data/items/item_<champion>_<name>.tres`, as CONVENTIONS' example `item_grapplers_gauntlet.tres`)
| Field | Type | Notes |
|---|---|---|
| `id` | `StringName` | `<champion>_<name>` (`&"knight_tidebreaker"`) |
| `display_name`, `flavor` | `String` | |
| `rarity` | `Item.Rarity` | LEGENDARY or ARTIFACT |
| `champion_id` | `StringName` | `&"knight"` |
| `base` | `ItemBase` | the slot and the implicit |
| `affixes` | `Array[Affix]` | fixed list; rolled in the Legendary band, or at their maximum for an Artifact |
| `modifiers` | `Array[StatModifier]` | fixed, not rolled; may be scoped `ability:<its ability>` |
| `augment` | `AbilityAugment` | exactly one, FLAG or REPLACE, `ability:<id>` of one of its champion's abilities |
| `drop_weight` | `float` | 1 |
Methods: `get_validation_errors(champion) -> PackedStringArray`: the augment rules above, the champion's abilities, a FLAG listed in `supported_flags`, a REPLACE variant's `variant_of` and its support for every talent FLAG of its base, `ability:` modifiers only on its own ability, the shared-slot rule among the champion's named items.

### DropTable (Resource, `drop_table.gd`; `res://data/drop_tables/drop_table_<name>.tres`: `drop_table_regular.tres`, `drop_table_elite.tres`)
`item_chance`, `chance_per_depth`, `item_count`, `rarity_weights: Array[float]` (7), `rarity_growth: Array[float]` (7). Methods: `get_chance(depth)`, `get_weights(depth, magic_find, table) -> Array[float]`. Destructibles (WORLD_INTERACTION.md) will use the same resource.

### Additions to existing data
- `ChampionData.named_items: Array[NamedItem]` (export group "Loot"); the Knight lists his five. `get_named_item(id)`.
- `Room.depth: int` (1); DUNGEONS.md takes it over. (LOOT sync) `RoomLayout.depth: int` (1), copied by `build_sim()` onto the Room it makes.
- `knight.tres`: `pickup_radius` 200 (STATS.md's planned value).
- Statuses: `status_undying.tres`, `status_bloodrush.tres` (move_speed PERCENT_ADD +0.3, 2 s, REFRESH, tags `buff`), `status_exposed.tres` (3 s, REFRESH, tags `exposed`, `debuff`).

### Runtime classes (`res://scripts/loot/`)
- **`Item`** (RefCounted, `item.gd`): one rolled item. `uid: int`, `rarity: Item.Rarity`, `base: ItemBase`, `affix_rolls: Array` ([Affix, roll] pairs), `sigils: Array[AbilityAugment]` (Unique 1, Exotic 2), `named: NamedItem` (Legendary / Artifact). Enums `Item.Slot`, `Item.Rarity`. Methods: `get_source_id()` (`&"item_<uid>"`), `get_slot()`, `get_display_name()` (the named item's name; else the base's, plus " of " and its sigils' suffixes), `get_color(table)`, `get_modifiers(table) -> Array[StatModifier]` (implicits + affix values + a named item's fixed modifiers, source id set), `get_augments() -> Array[AbilityAugment]` (its sigils, or its named augment), `get_champion_id()` (`&""` = any), `get_tooltip_lines(table) -> PackedStringArray`, `to_dict()`, `static from_dict(d, table, champion) -> Item` (null if its base or named item is unknown).
- **`ItemRoller`** (static functions, `item_roller.gd`): `roll_rarity(drop_table, depth, magic_find, rng, table = null) -> Item.Rarity` (as built in L1: `table` gives each rarity's magic find effect; null = `LootTable.get_default()`), `roll_item(rarity, champion, table, rng, slot = any) -> Item` (uid 0 until added), `roll_drop(drop_table, depth, magic_find, champion, table, rng) -> Array[Item]`, `roll_in_band(rarity_def, rng)` (one affix's roll), `pick_weighted(weights, rng)`. Every random choice takes the `RandomNumberGenerator`, so tests seed it; a band with equal ends draws nothing. (LOOT sync) `make_named(named, table, rng) -> Item`: one specific named item, its affixes rolled in its band, for what gives a fixed item (DUNGEONS' hand-placed gear and its `NAMED_ITEM` rewards; `Loot.debug_grant_named_items()` uses it too). Built in L5.
- **`ChampionInventory`** (RefCounted, `champion_inventory.gd`): `champion_id`, `next_uid`, `items: Array[Item]`, `equipped: Dictionary` (equipment slot → uid), `materials: Dictionary[StringName, int]` (reserved, empty), the raw entries it couldn't read. `add(item) -> int` (gives the uid), `get_item(uid)`, `get_equipped_item(slot)`, `set_equipped(slot, uid)`, `clear_equipped(slot)`, `write_to(cfg)`, `static read_from(cfg, champion, table)`, `static create(champion)`.
  L7b: `remove(uid) -> Item` (out of `items`; null for an unknown uid; never touches `equipped`: the caller refuses a worn item first).

## Architecture / contracts
### Loot (autoload, `res://scripts/autoload/loot.gd`)
- Registered after `Progress`, before `Audio` (which stays last).
- Holds a `ChampionInventory` per champion id, read lazily from `user://inventory.cfg` at the first `get_inventory(champion)` (a fresh one when none is saved); `saving_enabled` off in a test scene (`Progress.is_test_scene()`); `save()`, `save_path`. As built (L2): `save()` runs the test-scene guard before it checks `saving_enabled`, so a save before any read in a test scene writes nothing. `track(player, champion)` (the Player calls it when its gear loads), `untrack()` (a save when the player leaves the tree), `get_tracked_player()`.
- `table: LootTable` (the default .tres), `rng: RandomNumberGenerator`.
- `add_item(champion, item) -> int` (into the record, then a save), `get_depth(node) -> int` (the nearest Room ancestor's `depth`, else 1; as built (L3): the node itself counts when it's the Room, and a depth below 1 counts as 1).
- Listens to `Events.unit_died`: kill credit = `ctx.source` (the last hit) and it must be `Progress.get_tracked_player()` or its AI ally (`Allies.is_party_member()`, ALLIES.md); not a passive enemy, not the player's team; then `ItemRoller.roll_drop()` with the unit's drop table, the depth and the killer's `magic_find`, and one `Pickup` per item at the corpse, under the corpse's parent (the room's y-sorted `Entities`).
- Listens to `Events.item_equipped` / `item_unequipped` for the tracked player: updates the record's `equipped`, saves.
- `collect(pickup, collector)`: the item into the collector's champion's record, a save, `item_picked_up` (its own signal, like `Progress`'s: `item_picked_up(champion_id, item)`), the HUD line, the pickup sound, the pickup freed.
- Debug: `debug_grant_named_items(champion)` (one of each, into the record), `reset(champion)` (an empty record; tests and a later hub button).
- **As built (L7):** `drops_enabled` (off by itself in a test scene, Drops) and `are_drops_enabled()`; `get_drop_credit(unit, ctx) -> Player` (the credit is checked against `Loot.get_tracked_player()`, the same Player as Progress's); `roll_kill_drop(unit, killer) -> Array[Item]`; `drop(items, at, parent) -> Array[Pickup]` (one pickup per item hopping from `get_drop_origin(at, parent)`; SandboxLoot's K uses it too); `get_drop_origin(at, near) -> Vector2` (Pickups); `collect(pickup, collector) -> bool`; `get_ground_pickups(node) -> Array[Pickup]`; `take_ground_drops(room) -> Array`; `restore_ground_drops(room, drops, champion = null) -> Array[Pickup]`. The pickup scene is loaded at `_ready()` with `load()` (`pickup.gd` names this autoload).
- **L7b** (Dropping and trashing items): `can_remove(champion, item, unit = null) -> String` (`""` = yes; "Worn: unequip it first", not in this inventory, no item); `drop_from_inventory(champion, item, unit) -> Pickup` (removed, saved, `item_dropped`, then one pickup through `drop()` from the unit's feet, held for that unit); `trash_item(champion, item) -> bool` (removed, saved, `item_trashed`; the confirm is the caller's); the signals `item_dropped(champion_id, item)` and `item_trashed(champion_id, item)` (like `item_picked_up`); `needs_trash_confirm(item) -> bool` (Unique and up).

### EquipmentComponent (`res://scripts/components/equipment_component.gd`, a child of `player.tscn`)
- Equipment slots `&"weapon"`, `&"helm"`, `&"chest"`, `&"gloves"`, `&"boots"`, `&"ring_1"`, `&"ring_2"`, `&"amulet"`.
- `can_equip(item, slot = &"") -> String`, `equip(item, slot = &"", keep_current = true) -> bool` (slot `&""` = the item's own, the first empty ring slot for a ring), `unequip(slot, keep_current = true) -> Item`, `get_item(slot)`, `get_slot_of(item) -> StringName`, `get_equipped() -> Dictionary`. As built (L2): `get_slots_for(kind)` (static), the `equipment_changed(slot)` signal, the `loot_table` export (null = the default); `Player.equipment` holds it.
- Applies and removes through `StatsComponent.add_modifiers()` / `remove_modifiers_from()` and `AbilityComponent.add_augment()` (each of `item.get_augments()`) / `remove_augments_from()` under `item.get_source_id()`; emits `Events.item_equipped` / `item_unequipped`.
- `keep_current`: around the change, the unit's HealthComponent and ResourceComponent don't add a raised max to current (new: `HealthComponent.set_gain_on_max_raise(on)` and the same on ResourceComponent; default on, so every other caller behaves as before). The Player's load passes false.
- `Player._attach_champion()`, after the talents: equips each item in the record's `equipped` (`keep_current` false). An equipped uid with no item, or an item `can_equip()` refuses, is cleared from `equipped` with a warning.

### Events (additions, reserved in CONVENTIONS)
`item_equipped(unit: Unit, item: Item)`, `item_unequipped(unit: Unit, item: Item)`.

### Pickup (`res://scripts/loot/pickup.gd` + `res://scenes/loot/pickup.tscn`, `class_name Pickup`, Area2D)
Layer 9, mask 0, a 6 px circle, `monitorable` off until it lands. `item: Item` (planned, COMPANIONS CO6: or a `Companion`, or a kindling amount; (LOOT sync) DUNGEONS adds a collectible the same way: a pickup holds one payload, and `Loot.collect()` hands each kind to its system), `pop_time` 0.3, `pop_distance_min_px` 12, `pop_distance_max_px` 28, `debug_draw` (the landing spot and the collect circle, on the floor-drawing layer: `FloorOverlay.DRAWING_VISIBILITY_BIT`). `land_at(point)` starts the hop; `get_hop_progress()` (0–1, 1 once landed) and `get_hop_from()` for its view. In the group `view_source` with `view_scene` (null = `PickupView`; View, below). Draws nothing itself.
As built (L7): `land_at(point)` became `hop(from, spot)` (called before the pickup enters the tree, so its view's first sync already knows the hop) and `place(spot)` (landed at once: a ground drop put back). Also `pick_landing(origin, rng)`, `is_good_landing(origin, spot)`, `WALK_BLOCKING_MASK`, `PIT_MASK`, `LANDING_TRIES` (4), `PICKUP_LAYER`, `get_spot()`, `get_radius()`, `is_landed()`, `is_collected()`, `mark_collected()` (Loot only), `get_color()`, the signal `landed` (the rarity's drop sound plays then).
L7b: `hold_for(unit)` before it enters the tree, `is_held_for(unit) -> bool`, `release_hold(unit)`: a dropped item isn't collected by the unit that dropped it until that unit's collect circle has left it.

### PickupComponent (`res://scripts/components/pickup_component.gd`, Area2D on `player.tscn`)
On no layer, mask 9; a circle whose radius is `Units.to_px(pickup_radius)`, updated on `stat_changed`. On `area_entered` with a `Pickup` → `Loot.collect(pickup, unit)` (a pickup that becomes collectable while already inside is reported by the physics server on the next step). `debug_draw` (the radius, on the floor-drawing layer). As built (L7): its own `CircleShape2D` per Player, at least `MIN_RADIUS_PX` (1), `get_radius_px()`; nothing is collected while its unit is dead. Measured: a growing circle takes a pickup it now covers on the next step, and the Knight walking at 120 px/s takes a drop when his circle's edge meets the pickup's (69 px) without losing a frame of speed.
L7b: `area_entered` skips a pickup held for its unit; `area_exited` releases that hold, so walking back in collects it.

### Abilities and the toolkit
- `CastContext.sequence: Dictionary`: shared by every part of one recast sequence (AbilityComponent keeps it with the sequence), so part 0 can leave something for later parts. Lunge's return reads the start point from it; any "go back" recast (Zed, LeBlanc) needs the same.
- `lunge.gd`: part 0 writes the start point; part 1 (only on a variant with `recast_count` 1) blinks back to it (`MovementComponent.blink()`, ABILITIES AB15; L6 built it as a ghosted dash), with no hits.
- `iron_resolve.gd`: FLAG `iron_resolve_undying` applies `status_undying` (a copy with `flag_undying_duration`) to the Knight.
- `Unit.on_hit()`: a unit with a status tagged `undying` never loses its last 1 health to a hit (the damage taken is capped at current − 1, the number shows what was taken, `killed` stays false). DoT ticks too. The pit fall's own "can't drop below 1" is unchanged.
- `judgement.gd`: FLAG `judgement_drag`: at the effect, before the hit, the target is displaced toward the Knight until `flag_drag_gap_px` (8) from his edge over `flag_drag_time` (0.15 s), **airborne** (Ryan, 2026-10-03): (LOOT sync) it gets `status_airborne` for the drag's time, so the drag uses the knock-up's movement (over fences, cliffs and pits; walls stop it), its landing rule and its view arc; the hit lands when the drag ends, wherever that is. Airborne is `cc`, so Expose fires on it. An unstoppable target isn't moved (it refuses airborne; the hit still lands where it stands).
- `judgement_leap.gd` (extends `judgement.gd`, reusing its hit, Fury and Shockwave code): POINT, a **leap** to the point (3D.md, Leaps; was `MovementComponent.dash()`, ghosted, before the sync), then `hit_units()` on every enemy in the landing circle (in sight from the landing point), each with its own missing-health term; `flag_shockwave_ring_radius` 370 u for the Shockwave take; the indicator draws the landing circle. (LOOT sync) The leap: `MovementComponent.leap(to_px, duration)`, a straight move to the point over `duration` (0.3 s) that collides with nothing (units, fences, ledges, pits and walls), with `is_airborne()` true while it runs; it lands through `WorldQuery.resolve_valid_position()` on the nearest walkable floor of the room (a point aimed inside a wall, a fence or past the room's floor ends there). The caster isn't crowd-controlled (no status) and keeps no i-frames; the cast roots it.
- **As built (L6, 2026-10-04):**
  - **The sequence:** AbilityComponent stores part 0's `ctx.sequence` with the recast sequence and gives later parts that same dictionary. A cast outside a sequence (no recasts, a free cast) has its own empty one.
  - **The return:** `lunge.gd` writes `sequence[&"start"]` on every part 0 (harmless without a recast). Part 1 dashed straight back at the Lunge's speed and curve, stopped by walls and ledges like the Lunge (AB15 makes it a blink: Ryan disliked the dash back's look, 2026-10-04). Recasts don't count as ability uses (Progress counts part 0 only), so Homeward Greaves doesn't speed up Lunge's talents.
  - **The landing reads the room's navigation** (the nearest walkable floor): `MovementComponent.get_leap_landing(to_px)` returns the aimed spot when the body fits there (nothing on `LEAP_BLOCKING_MASK`: walls, low obstacles, ledges, pits) and it's within `Room.nav_agent_radius` (12 px) of the unit's room's navigation region. Otherwise it returns that region's closest point (`NavigationServer2D.region_get_closest_point()`), freed by `WorldQuery.resolve_valid_position()`.
    - It asks its own room's region, so it never lands in another room.
    - Outside a Room, or before the navigation map has synced, it's `resolve_valid_position()` alone, back toward the unit.
    - The landing is picked when the leap starts; the move goes straight there at a steady speed, and on landing a spot that has become blocked is freed again.
  - **Nothing interrupts a leap:** `displace()` (a knockback) and `dash()` are refused while it runs; a stun mid-air doesn't stop it, and the landing still hits. `stop_displacement()` lands it where it is.
  - **Judgement Leap's landing:**
    - Every enemy within `landing_radius` (220 u) of where the Knight lands, its edge counting (`AbilityUtil.in_circle()`), in sight from there, takes the hit with its own stun (`get_effect_param()` per target).
    - With Shockwave, the ring (`flag_shockwave_ring_radius` 370 u, the circle's units excluded) is hit on every landing, at `flag_shockwave_damage_ratio` with `flag_shockwave_stun_duration` plus what the Fury adds.
    - One crit roll for the cast.
    - The Fury bonus is checked once at the landing, and the Fury is spent if any hit, circle or ring, gets through.
  - **The indicator** draws the range, a line to where the leap would really land (`get_leap_landing()`, so the circle sits on the floor it will use), the landing circle and, with Shockwave, the ring.
  - **Names** (FREE, placeholders): the variants "Homeward Lunge" and "Judgement Leap", and their augments' names.

### HUD and SandboxLoot
- `hud.gd`: `show_loot_line(text, color)` (2 s, stacks under a line still showing, like `show_progress_line()`), fed by `Loot.item_picked_up`.
- `SandboxLoot` (`res://scripts/rooms/sandbox_loot.gd`, in `sandbox.tscn` and (LOOT sync) `sandbox_3d.tscn`; keys FREE): a list on the right, (LOOT sync) under SandboxAugments' four lines (which sit in the top-right corner), not over them ("Inventory 23   Depth 1   MF +0%", then items as "> [Gloves] The Last Verdict  Artifact  ON" in rarity colors, scrolling around the cursor) and the highlighted item's tooltip lines under it. **J** moves the cursor down (Shift+J up), **U** equips or unequips the highlighted item, **K** rolls one drop from the elite table at the current depth and the Knight's magic find (straight into the inventory until drops exist, then as a pickup at the Knight's feet, the real path), **P** grants one of each of the champion's named items, **[** / **]** lower / raise the room's depth. All unbound elsewhere (checked 2026-10-03: no input action and no sandbox script reads them). ALLIES.md adds its key that equips the highlighted item on the ally, with its own step.
- As built (L3; the layout measured headless at 640×360): the list starts at y 66 (SandboxAugments' four lines end at 61) and shows **6 items** at a time (`visible_rows`), so the list and the longest tooltip stay above the ability bar (worst case: 19 rows of 12 px end at y 294; the bar starts at 322). The tooltip under the list starts at the item's **third tooltip line**, since its row already shows the name, slot and rarity. Above it is the keys line, below it the last key's result ("Equipped Iron Helm (swapped out Iron Helm)", "Rolled Rare Band (depth 2)", "Can't equip …: <reason>"). A held J repeats; no other key does. K rolls from the `drop_table` export (default elite). The label ignores the mouse, so clicks over it still attack. The list refreshes when the Player is ready (it enters Entities before its `_ready()`), and on every equip and unequip.
- As built (L7):
  - **The HUD's loot lines** ("Rare: Iron Helm", "Legendary: Tidebreaker", in the rarity's color) are centered 10 px above the ability bar and grow upward: the bottom-left corner is SandboxTalents' list. A new line goes under those still showing; six at most (a seventh pushes the oldest out); each fades after 2 s (0.3 s). `get_loot_lines()` and `get_loot_line_color(text)` for tests.
  - **K** drops its roll at the Knight's feet through `Loot.drop()`; he stands within his pickup radius, so each lands and is taken 0.3 s later (the result line still says "Rolled …"). Every pickup of the champion's (K's or a kill's) moves the cursor to the new item.
- L7b: **L** drops the highlighted item at the Knight's feet (`drop_item(index)`); **X** trashes it (`trash(index)`; for Unique and up the first press asks and a second within 3 s on the same item trashes; any other key, a cursor move or the time running out cancels: `get_pending_trash()`). Both refuse a worn item with the reason. The cursor stays on the same row (the next item moves up into it). The keys line gains "L drop, X trash". The hub's debug row gains **Clear inventory** (`Loot.reset()` for its champion; the first click asks in the detail line, "Click again to empty the Knight's inventory (23 items)", a second within 3 s empties it).

## View (3D.md)
Every look here is a view: it never changes gameplay state, and nothing is built without a WorldView (the tests). From the LOOT sync, approved by Ryan 2026-10-03 as **placeholders**: "fine for now; proper VFX when the art comes" (the art pass gives drops their real look).
- **`PickupView`** (`scripts/view/pickup_view.gd`, `scenes/view/pickup_view.tscn`; an `EntityView`), the `Pickup`'s default view:
  - a small gem (an octahedron about 0.25 m across) in its item's rarity color, 0.35 m over the ground under it, bobbing 0.05 m and turning slowly;
  - Legendary and Artifact add a light beam in their color, 1.25 m tall (the old plan's 40 px as meters), drawn with PillarView's shader (`pillar.gdshader`), held while the pickup lies there;
  - the hop: an arc from where the corpse stood to the landing spot over the pop's 0.3 s (`hop_apex_m` 0.6), following the ground's height at both ends (3D.md, Height in the view);
  - collected: gone at once (the HUD line and the pickup sound say so);
  - its rarity color reads the pickup's payload (an item's rarity; COMPANIONS' payloads bring their own look).
  - As built (L7): the gem glows a little (emission 0.6 of its color) so a dark room doesn't hide it, and is drawn from both sides; the bob is 0.6 Hz and the turn 60° a second (`bob_hz`, `turn_deg_per_s`); the beam starts at `beam_from_rarity` (Legendary), 0.08 m wide at its foot, 0.55 alpha, and isn't pulled toward the camera (`beam_pull_m` 0; PillarView's is 0.8). Mid-hop the view stands on the line between the two grounds plus the arc (0.6 m at the middle); on a plateau it hops over the top. WorldView loads its scene at setup with the other default views, so the first drop loads nothing.
- **The drag** (Chains of Judgement): the target's knock-up arc, `UnitView`'s, over the drag's 0.15 s (it's airborne).
- **The return** (Homeward Greaves; from ABILITIES AB15): a blink's look, an afterimage where the Knight was and a flash where he appears (3D.md, 1e).
- **The leap** (The Last Verdict; 3D.md, Leaps): `UnitView` arcs the caster over the leap's time, from the ground at its start to the ground at its landing (a plateau's top or the floor below a cliff), and plays the ability's `cast_anim`. As built (L6):
  - The view stands on the straight line between the two grounds (the landing's from the ground ray at the landing point), and the model rises `leap_apex_m` (2.5 m, so it clears the kit's 2.2 m walls) over it on `airborne_curve`.
  - The landing tick and the one after finish the line and the arc, so the model touches down with the sim.
  - A leap never plays the stun pose, and a cast clip holds its follow-through until the landing.
- **Debug drawings** (the landing spot, the collect circles) are floor drawings (canvas layer 3), as every debug drawing is since the 3D pivot's cleanup C2.
- **The HUD loot line** is the HUD's (a CanvasLayer): it shows as it would have in 2D. `ItemRarity.color` feeds both the line and the view.

## Audio hooks
Built with drops and pickups (L7), with synthesized placeholders like AUDIO.md's: `ItemRarity.drop_sound` (`sound_loot_drop` for Uncommon–Exotic, a brighter `sound_loot_drop_legendary` for Legendary and Artifact; SFX at the pickup) and `LootTable.pickup_sound` (`sound_loot_pickup`, SFX, centered). As built (L7): the drop sound plays when the pickup lands (−8 dB; the legendary one −4 dB, HIGH, heard to 640 px, no pitch jitter), the pickup sound when it's taken (−10 dB); a drop put back by `restore_ground_drops()` is silent. Later (UI.md): equip and unequip clicks. Undying's status sounds (apply, expire) and the leap's cast and landing sounds use the existing status and ability hooks; until then they're silent.

## How each edge case is handled
| Edge case | Handling |
|---|---|
| Two items with the same sigil | One sigil (the augment id counts once); unequipping either keeps it while the other is on. Their stats both apply |
| An Exotic's two sigils | Always different (the roller never picks one twice); both fire, each on its own trigger |
| A kill by a Storm Strike bolt; crowd control applied by another reaction; a free cast's hits | Bloodrush, Expose and Storm Strike still fire: one link into a chain is within their chain limit (2). Two links deep, they don't (L4) |
| A Unique or Exotic rolled before L4 | No sigils: the save keeps what was rolled; sigils are never added later (L4) |
| Storm Strike's lightning | A `proc`-tagged hit (COMBAT.md): can't crit, coefficient 0, so no HIT rule (Storm Strike included) and no on-hit fires from it |
| Expose on a status that isn't cc (Staggered) | Doesn't fire (`required_status_tags` [`cc`]). Exposed isn't cc, so it can't loop |
| Bloodrush with Iron Resolve's haste | Different status ids; both PERCENT_ADD move speed, summed (STATS.md) |
| Swap a health item mid-fight | Current health kept (clamped): no heal from a swap. At spawn the champion starts full |
| Swap during a cast | The cast keeps the augments it read at its start; the next cast uses the new ones |
| Unequip Oathbound Plate while Undying | The status runs out on its own (it came from a cast, not the item) |
| Undying and a killing blow | Health stops at 1; the number shows the damage taken; no death, no `unit_died` |
| Lunge Return's window runs out | No return; the cooldown starts (ABILITIES.md, recasts) |
| Lunge Return with a wall or a cliff in the way back | It blinks back over them (ABILITIES AB15; L6 built it as a ghosted dash, which walls and ledges stopped) |
| The Last Verdict aimed into a wall, a fence, past a cliff or out of the room | The leap goes over everything and lands on the nearest walkable floor of the room to the aimed point (Ryan, 2026-10-03); the landing hits around wherever the Knight lands |
| The Last Verdict onto a plateau or a perch | It lands on top (the leap crosses ledges); on a perch the Knight is `elevated` there, so his melee reaches perched enemies (3D.md, Terrain and height) |
| Chains of Judgement on an unstoppable target | No drag; the hit still lands (as knockback on an unstoppable target) |
| Chains of Judgement with a fence, a cliff or a pit between | The target is lifted over it (airborne for the drag; Ryan, 2026-10-03); a wall stops it, and the hit lands where it stops |
| An Artifact retuned (an affix's max changed) | Its value follows: its roll is 1, recomputed from the data |
| A named item's data changed (an affix added or removed) | Its list follows the data: a new affix gets the band's middle (0.5), a removed one is dropped, each with a warning; the other rolls stay (L5) |
| A second Judgement item (or any two named items for one ability) | Validation needs them in one item slot, so they can never be worn together (L5) |
| A named item for another champion (data changed) | `can_equip()` refuses; it stays in the inventory |
| Two copies of one named item | Allowed in the inventory; only one equipped at a time |
| A worn ring moved to the other ring slot | Refused ("already equipped"): unequip it first, then equip it there (L2) |
| Two worn items with the same uid | The second is refused: they would share one source id (L2) |
| A champion with no named item of the rolled rarity | That drop rolls as an Exotic (with an AI ally: the roll passes to the other party champion first; With an AI ally) |
| Magic find on Common | `magic_find_effect` 0: more magic find only lowers Common's share |
| A kill with no source, or by something other than the tracked player or its AI ally | No drop (until WORLD_INTERACTION's Kill credit) |
| A training dummy | No drop |
| A drop next to a wall, a fence, a cliff or a pit | (LOOT sync) Its landing spot must be walkable from the corpse (nothing on layers 1, 7 or 11 between) and not over a pit; four tries, then the corpse's spot |
| An enemy that fell into a pit | (LOOT sync) Its drops land at the nearest walkable point outside the pit (`WorldQuery.push_out()`) |
| A drop inside the pickup radius | Collected when it lands, 0.3 s later |
| A wing's floor rebuilt (floor change, rest, death respawn, fast travel) with drops on its ground | Put back where they lay, collectable (Ryan, 2026-10-03; From the dungeon) |
| Leaving the run (or, outside a wing, the room) with drops on the ground | Lost; ground drops live only in the run, never in the save |
| Death and checkpoint respawn | The inventory and the equipped gear are kept (saved on pickup and equip) |
| A saved item whose base or named item was deleted | Skipped at load with a warning, its raw entry written back unchanged |
| A saved item with an unknown affix or sigil id | That line dropped (warning); the rest of the item loads |
| An equipped uid that no longer exists | Cleared from `equipped` at load, with a warning |
| Dropping an item at your feet (L7b) | It pops 12–28 px away and stays there while you stand by it; walk out of your pickup radius and back to take it again (a new uid) |
| Leaving the room or the run after dropping an item (L7b) | Lost, like any drop on the ground; in a wing, the floor keeps it for the run |
| Trashing a Unique or better (L7b) | The first press asks; a second on the same item within 3 s trashes it, for good (no undo; Ryan, 2026-10-04) |
| Dropping or trashing a worn item (L7b) | Refused: unequip it first |
| Tests | `Loot.saving_enabled` off in a test scene; tests seed `Loot.rng`; the real inventory is never touched |
| A scripted harness (screenshots, frame times) in the sandbox | (LOOT sync) It sets `Loot.saving_enabled = false` first, as for `Progress` and `Settings` |

## Build order (one or a few steps per session)
Every step: the Knight's abilities, talents, enemies chasing and the HUD still work; with nothing equipped the game plays exactly as before. Build logs go in CHANGELOG.md (a Loot section); this doc keeps one line per built step. **SandboxLoot comes third, not last** (Ryan, 2026-10-01): the sigils and named items (L4–L6) need a way to equip them by hand for their play tests.

1. **L1 – Items: data and rolling.** `Item` (enums, modifiers, tooltip lines, `to_dict()` / `from_dict()`), `ItemRarity`, `LootTable` + `loot_table_default.tres` (the 7 rarities), `ItemBase` + the 7 bases, `Affix` + the 15 affixes, `DropTable` + regular and elite, `ItemRoller` (rarity with depth and magic find, base, affixes, rolls), validation; `res://scenes/tests/loot_test.tscn` + `scripts/tests/loot_test.gd`. Unique and Exotic roll without sigils until L4; no named items until L5 (a Legendary or Artifact roll falls back to Exotic). Docs: none left (CONVENTIONS' names and vocabulary, STATS' and VISION's open questions were done in the LOOT sync, 2026-10-03). Built 2026-10-03, see CHANGELOG.md.
   **Done means:** over 100,000 seeded rolls each rarity lands within 1% of its weight, and depth and magic find shift them as the formula says; every affix value sits inside its rarity's band and range and is rounded to its step; no item rolls an affix twice or one its slot forbids; an item's modifiers and its `to_dict()` round trip match; validation catches each broken rule; every existing test passes.
2. **L2 – Equipping, the inventory and the save.** `EquipmentComponent` on `player.tscn`, `Events.item_equipped` / `item_unequipped`, the keep-current hold on HealthComponent and ResourceComponent, `ChampionInventory`, the `Loot` autoload (records, `user://inventory.cfg`, the test guard, the equip listener), the Player equipping the saved gear at load. Built 2026-10-03, see CHANGELOG.md.
   **Done means:** an equipped item changes exactly its stats under `item_<uid>` and unequipping restores them exactly; a swap replaces; rings fill both slots; a swap at partial health doesn't heal and a spawn with gear starts full; a save and reload keeps items, uids, the equipped set and the empty materials bucket; an unreadable entry survives a save; tests never write the real file; with nothing equipped every suite is unchanged.
3. **L3 – SandboxLoot: equipping by hand.** The list, J / Shift+J, U, K (into the inventory), P (a no-op until L5), [ / ], the tooltip lines; `Room.depth` (and (LOOT sync) `RoomLayout.depth`; SandboxLoot in both sandboxes). Built 2026-10-03, see CHANGELOG.md.
   **Done means:** Ryan rolls a few items in the sandbox, equips and swaps them and feels the stats (crit, attack speed, move speed); the list shows what's on; quitting and relaunching keeps it; Start run plays with that gear.
4. **L4 – Sigils.** The three sigil augments, `status_bloodrush`, `status_exposed`, Unique rolling one sigil and Exotic two different ones, the " of <suffixes>" names, the sigil lines in tooltips. Built 2026-10-03, see CHANGELOG.md.
   **Done means:** each sigil does what its row says (a check each), never from a `proc`-tagged hit; an Exotic always has two different sigils and both fire; the same sigil from two items is one; unequipping removes it; Ryan's play test: each one is felt in the sandbox, and an Exotic reads as two effects.
5. **L5 – Named items, part 1: the framework and the FLAGs.** `NamedItem` + validation, `ChampionData.named_items`, Legendary and Artifact rolls from the champion's list (Exotic fallback; an Artifact's affixes at their maximum with no draw), the one-copy and shared-slot rules; Tidebreaker (the existing Cleave Wave), Oathbound Plate (`iron_resolve_undying`, `status_undying`, the `undying` rule in `Unit.on_hit()`), Chains of Judgement (`judgement_drag`, airborne); `ItemRoller.make_named()`; SandboxLoot's P. Built 2026-10-03, see CHANGELOG.md.
   **Done means:** each item validates and does what its row says with every Knight talent in its group; a Legendary's affixes vary inside its band and an Artifact's are always the maximum; Undying keeps the Knight at 1 health through a killing blow and ends on time; the drag brings the target to the Knight before the hit, over a fence and off a plateau (stopped by a wall), and skips an unstoppable one; Ryan's play test (the 3D sandbox's terrain corner for the drag): each feels like a different way to use its ability.
6. **L6 – Named items, part 2: the REPLACE variants.** `CastContext.sequence`; Homeward Greaves (`knight_e_lunge_return.tres`, `lunge.gd`'s return part); The Last Verdict (`judgement_leap.gd`, `knight_r_judgement_leap.tres`, its Shockwave take, the Fury payoff, the indicator); the leap (`MovementComponent.leap()`, its landing, `UnitView`'s arc for it; 3D.md, Leaps).
   **Done means:** the return goes back to the exact start, inside the window only, with Tackle and Twin Lunge as the table says; the leap lands where aimed, over units, fences, cliffs (up onto a plateau and down off it), pits and walls, and on the nearest walkable floor when aimed into a wall or out of the room; it hits and stuns everything in its circle in sight, consumes the Fury once, resets on a kill with Executioner; the talents test's variant check passes for both new variants; Ryan's play test. Built 2026-10-04 and passed Ryan's play test the same day, see CHANGELOG.md.
7. **L7 – Drops and pickups.** Layer 9 named `pickup` (editor steps), `Pickup` + `pickup.tscn`, `PickupComponent` on `player.tscn`, `knight.tres` `pickup_radius` 200, `Loot` on `Events.unit_died` (last-hit credit, the drop table by unit, depth, magic find), the pop and collect delay, the HUD loot line, the drop and pickup sounds; SandboxLoot's K switches to spawning a pickup. (LOOT sync) Also `PickupView` (View), the landing check against fences, ledges and pits, `Loot.take_ground_drops()` / `restore_ground_drops()` (DUNGEONS D1 calls them), and the kill credit as the tracked player (ALLIES adds the ally).
   **Done means:** slimes and the elite drop at about the table's rates (measured in the test with a seeded rng); a drop pops, lands off walls, fences, cliffs and pits, shows in 3D in its rarity color (Legendary and Artifact with their beam), and is collected on proximity without a key or a stop; ground drops taken and restored come back where they lay; it's in the inventory (and the save) at once and the HUD names it in its color; dummies drop nothing; Ryan's play test in the sandbox and in Start run. Built 2026-10-04, see CHANGELOG.md.
7b. **L7b – Dropping and trashing items** (Ryan, 2026-10-04; before L-M). `ChampionInventory.remove()`; `Loot.can_remove()`, `drop_from_inventory()`, `trash_item()`, `needs_trash_confirm()`, `item_dropped` / `item_trashed`; `Pickup`'s hold for the unit that dropped it and `PickupComponent` releasing it on `area_exited`; SandboxLoot's L and X with the confirm; the hub's Clear inventory (Dropping and trashing items).
   **Done means:** a dropped item leaves the inventory and the save at once, pops at the Knight's feet, isn't taken back while he stands there, and is taken back when he walks out of his radius and returns; it's lost when the room restarts and kept through `take_ground_drops()` / `restore_ground_drops()`; a trashed Common goes at once, a trashed Unique or better only after the second press (a cursor move, another key or 3 s cancel), and either is gone from the save; a worn item is refused for both; Clear inventory needs its second click and leaves an empty, saved inventory; tests never touch the real save; every existing test passes; Ryan's play test. Also O's sorting (Ryan, 2026-10-04). Built 2026-10-04 and passed Ryan's play test the same day, see CHANGELOG.md.

**Milestone L-M – A looting session** (after L7b): Ryan plays a few real sessions from an empty inventory (the hub's Clear inventory, L7b; the debug keys for the long tail): drops read (rarity colors, beams, the HUD line), pickups never break movement, a few swaps change how the Knight feels, and each legendary changes how its ability is used.
**Done means:** Ryan's play test: the ladder reads (numbers → a sigil → two sigils → an ability change) and gear changes how the Knight plays, not just his numbers.
Started 2026-10-04 (Ryan's inventory and progress backed up first, in `backups/` beside the saves). The open questions are best answered during these sessions: L7's pit between a corpse and its drop, L6's Shockwave line on Judgement Leap and the leap's look (Open questions), and ABILITIES AB15's return cast time and roots blocking dashes (ABILITIES.md, Open questions).

## Out of scope (deferred to LOOT v2, its own interview later; Ryan, 2026-10-01)
Sockets and gems; crafting and reforging (the materials bucket is reserved for its currencies; rekindling companions is COMPANIONS.md's, with its own materials); the gold economy and vendors (`gold_find` stays unused); trading; item power, item level and level requirements; League-style item recipes and item actives. Also not here: the real inventory and equip screen (UI.md), weapons changing the combo (COMBAT.md's open question), what a run and its depth are (DUNGEONS.md, written 2026-10-03: a run is a wing; depth *(proposed)* in From the dungeon), where enemy drop data lives (ENEMIES_AI.md), the fly-to-player pickup (a feel pass), salvage (dropping and trashing are L7b's; Ryan, 2026-10-04), sustain and AP affixes.

## Open questions
### Dropping and trashing items (2026-10-04; L7b)
**Answered by Ryan, 2026-10-04** (he asked to drop and trash items, companions later, "for inventories that get full or for sorting purposes"):
1. ~~A cap~~: inventories stay unlimited; dropping and trashing are for tidying.
2. ~~What dropping does~~: back on the ground at the player's feet, not taken back until they walk out of their pickup radius and return, lost on leaving like any ground drop.
3. ~~How safe trashing is~~: Common to Rare at once, Unique and up after a second press; a worn item must be unequipped first; gone from the save for good.
4. ~~When~~: the spec now, build step L7b next, then L-M.

**Claude's proposals, approved when Ryan started L7b (2026-10-04, with sorting added):**
5. A worn item can't be dropped either (unequip first), and dropping never asks to confirm.
6. The drop pops like a kill's (12–28 px, the walkable rule, the rarity's drop sound) and is held for the unit that dropped it until its circle leaves it.
7. The confirm: a second X on the same item within 3 s; any other key, a cursor move or the 3 s cancel.
8. No HUD line and no sound for dropping or trashing until UI.md (SandboxLoot's result line says it).
9. The keys **L** (drop) and **X** (trash) in SandboxLoot, and the hub's **Clear inventory** debug button (a second click within 3 s) to start L-M from an empty inventory.
10. The names: `ChampionInventory.remove()`, `Loot.can_remove()`, `drop_from_inventory()`, `trash_item()`, `needs_trash_confirm()`, the signals `item_dropped` and `item_trashed`, `Pickup.hold_for()` / `is_held_for()` / `release_hold()`; the verbs **drop** (an item from the inventory back on the ground; "a drop" stays what a kill leaves) and **trash** (gone for good).

**Answered when Ryan started L7b (2026-10-04):**
11. ~~**Sorting**~~: added on **O** (Ryan: "add sorting with O"; Dropping and trashing items, Sorting). The question was: SandboxLoot lists items in the order they were picked up. A sort key (by slot, then rarity, best first) would help when the list is long. Claude's proposal: **O** cycles pickup order / slot / rarity, a view only (the save keeps its order). Say if you want it in L7b.
12. **Companions:** COMPANIONS.md's Release (a spare copy for kindling, with a confirm, never a chosen copy) is already their trash. Dropping a copy on the ground would come with CO6, which builds companion pickups. Nothing for companions in L7b.

### Found while building L7 (2026-10-04; for Ryan, at his L7 play test)
1. **A pit between a corpse and its drop's landing spot** doesn't stop the hop: the rule names walls, fences and cliff edges between them, and only refuses a spot over a pit (measured: next to a 4 px pit, 64 of 300 drops hopped across it). Claude's proposal: keep it while pits don't block walking (the hop is in the air and the player can walk around); the pit step can add layer 6 to the ray when pits start blocking.

### Found while building L6 (2026-10-04; for Ryan, at his L6 play test)
1. **Shockwave's tooltip line on Judgement Leap** reads Judgement's text ("within 80 px of the target"), since a FLAG's line is its augment's description, shared by every ability it reaches. Claude's proposal: reword `augment_judgement_shockwave.tres` to fit both ("Also hits the enemies around the strike for 50% damage and a 0.5 s stun; no missing-health damage"). One data line; the talents test's tooltip checks would follow.
2. **The leap's look** (view data, TARGET): `leap_apex_m` 2.5 m over the line, on the knock-up's curve, and the cast clip (Judgement's chop) striking as the leap starts and holding its follow-through to the landing. A strike timed to the landing would need the clip to lead over the crouch and the flight; that's for the art pass.

### The LOOT sync (2026-10-03)
The doc predated the 3D pivot and the COMPANIONS, ALLIES and DUNGEONS docs; an audit found where they and the code had moved on.

**Answered by Ryan, 2026-10-03:**
1. ~~Leaps~~: they work. A champion can be airborne through its own abilities (Pantheon's or Galio's ultimate); there's just no jump key. A leap goes **over everything, walls included**, and lands on the nearest walkable floor of the room (3D.md, Leaps). The Last Verdict is one.
2. ~~Ally kills~~: they drop everything a player's kill does, companions and kindling included (COMPANIONS.md corrected).
3. ~~Drops on the ground at a rebuild~~: a wing's floors remember them for the run and put them back where they lay; leaving the run loses them.
4. ~~Chains of Judgement's drag over terrain~~: the target is lifted (airborne for the drag), so fences, cliffs and pits don't stop it; walls do.

**Claude's proposals, marked (LOOT sync) in the doc; answered by Ryan, 2026-10-03:**
5. ~~`PickupView`~~: a gem in the rarity color with a bob, a PillarView-style beam for Legendary and Artifact, the hop as an arc (View): fine for now, as a placeholder; drops get their proper VFX with the art pass.
6. ~~The landing spot~~: walkable from the corpse (no wall, fence or cliff edge between, not over a pit); a fallen enemy's drops land at the pit's edge (Pickups): approved.
7. ~~`RoomLayout.depth`~~, copied onto the Room by `build_sim()`; per-space depth waits for the P-spike (Drops, Depth): approved.
8. ~~SandboxLoot in the 3D sandbox~~, its list under SandboxAugments'; harnesses set `Loot.saving_enabled = false`: approved.
9. ~~L7 credits the tracked player; ALLIES adds the ally~~: changed by Ryan: **an ally's kill counts as the champion's kill**, for drops and for the player's champion's kill counter (XP is shared evenly anyway, and the ally's talents come only from its level), while the game still tracks that the ally landed it (ALLIES.md, TALENTS.md). L7 still builds the check as the tracked player, since no ally exists before ALLIES.
10. ~~The leap's shape~~ (`MovementComponent.leap()`, colliding with nothing, `is_airborne()` while it runs, no status and no i-frames on the caster, the tag `leap`; the drag's `status_airborne` for its 0.15 s): approved.
11. ~~Ground drops through `Loot.take_ground_drops()` / `restore_ground_drops()` and `WingRun.ground_drops`~~: approved.
12. ~~The hooks other docs expected~~ (one payload kind per pickup, `ItemRoller.make_named()` in L5, no `item_vfx`, ALLIES' own SandboxLoot key): approved.

Raised by VISION.md's 2026-10-02 update (nothing proposed yet):
- **Lore on legendaries and artifacts:** each dungeon has its own story (VISION.md, Pillar 5). Should a named item's `flavor` text (`NamedItem.flavor`, already in the data) carry dungeon or champion lore, and does finding one add an entry to the codex? With NARRATIVE.md; the "every legendary and artifact found" collection is a meta-progression candidate (VISION.md, Meta-progression; PROGRESSION.md).

Answered by Ryan, 2026-10-01 (Claude's proposals in the first draft):
1. ~~Unique vs Exotic, Legendary vs Artifact~~: changed by Ryan: an Exotic gets a second, different sigil instead of better rolls (two distinct effects, not bigger numbers; Exotic's stats equal Unique's). An Artifact carries the biggest ability change, has one more fixed affix, and its affixes are always at their maximum (no RNG); a Legendary still rolls a range.
2. ~~The word for the Unique / Exotic effect~~: never "proc", including "item proc" (Ryan). Claude's pick: **sigil** (`sigil_<name>`, `augment_sigil_<name>.tres`, `LootTable.sigils`, `Item.sigils`). "Proc" keeps only COMBAT.md's meaning.
3. ~~The Knight's five items~~: approved, Undying as Oathbound Plate's Iron Resolve effect included.
4. ~~Named items for one ability share an item slot; a named item equipped once~~: approved.
5. ~~Random affixes and sigils never `ability:`-scoped~~: approved.
6. ~~A live swap never heals or refills~~: approved.
7. ~~Weapons don't change the combo in this build~~: approved.
8. ~~No sustain or AP affixes in the first pool~~: approved.
9. ~~The roll saved, not the value; unreadable saved items kept raw~~: approved.
10. ~~`user://inventory.cfg`, a file of its own~~: approved.
11. ~~Depth from `Room.depth`; drop tables by unit until ENEMIES_AI.md~~: approved.
12. ~~The drop rates and weights~~: approved as TARGET.
13. ~~The 0.3 s pop before a drop can be collected; `pickup_radius` 200 u~~: approved.
14. ~~SandboxLoot changes the real save and comes at L3~~: approved.
15. ~~`CastContext.sequence`~~: approved.
16. ~~The names~~ (`Loot`, `Item`, `ItemBase`, `Affix`, `ItemRarity`, `LootTable`, `DropTable`, `NamedItem`, `ItemRoller`, `ChampionInventory`, `EquipmentComponent`, `PickupComponent`, `Pickup`, `SandboxLoot`; status tags `undying`, `exposed`; the vocabulary **sigil** and **named item**): approved; CONVENTIONS gets them in L1.
17. ~~The L1–L7 plan~~: approved as laid out.
