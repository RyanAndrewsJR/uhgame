# COMPANIONS.md: Companions, Quirks, Bond, Evolutions, the Command (Tab) and Consuming the Companion
<!-- Written 2026-10-03 from Ryan's idea (2026-10-02) and his interview answers (2026-10-03). A plan: nothing is built. -->

**Read when:** the task involves companions: what one is, its passives, quirks and rarity, bond and evolutions, its command on Tab, abilities that consume the companion and the imprint, how companions are found, hatched or rekindled, kindling (companion materials), the companion screen at the hub, the companion save, or a companion's 3D look.
**Depends on:** CLAUDE.md, VISION.md (Meta-progression: the companion exception), CONVENTIONS.md, STATS.md (StatModifier, scopes), ABILITIES.md (AbilityComponent, the cast flow, conditions, DamageScaling, augments), CHAMPIONS.md (`ToolkitBundle` through Passive, the Knight's kit), TALENTS.md (`Progress`, its save pattern and test guard, kill credit, `xp_by_unit`), LOOT.md (the rarity ladder, `Affix`, roll bands, `ItemRoller`, `DropTable`, `Pickup`, the keep-current hold), 3D.md (views, teleports, the floor pick), MOVEMENT.md (the input map, the buffer), AUDIO.md (hooks).
**Used by:** DUNGEONS (each dungeon's signature companions, what a clear is, checkpoints), NARRATIVE (the lore, the codex, secrets and lore puzzles, the champion-linked companion), UI (the polished companion screen, the menagerie, a 3D preview), NPCS (the trainer), PROGRESSION (one save), ENEMIES_AI (which enemies drop companions), future champions (abilities that consume the companion), ACHIEVEMENTS (much later).
**Status:** interview done 2026-10-03. Ryan's idea (2026-10-02) and his answers (2026-10-03) are MUST, and so are Claude's five readings he confirmed the same day (quirk counts, quirks as stat lines, what "Tab can't be modified at the hub" means, the adaptive details, "imprint") and the conflict fixes he had applied across the docs (the names below, the `companion` role tag, the fifth slot). Items still marked *(proposed)* are Claude's picks that Ryan hasn't answered; each one is also in Open questions. Nothing is built.

## How to read this doc
Same as LOOT.md: MUST (never change without asking Ryan), TARGET (start value and allowed range), FREE (your call; tiebreaker: VISION.md's decision priorities). Every number is a TARGET placeholder until the play tests. Species named in examples (the Ember Fox) are illustrations, not launch content: the launch companions are picked with the content (Ryan, 2026-10-03).

## Player experience
An elite slime bursts, and among the loot sits a cocoon, glowing blue. It's dormant; back at the hub it wakes on the companion screen: a Rare Ember Fox with three quirks of its own ("+5% move speed", "+9% damage to burning enemies"...). You take it along. It trails a step behind the Knight, never in the way, never hit, and when the Knight crosses a cliff it blinks to catch up. Its passive is always on. Every 40 seconds or so, Tab is the big button: the fox flares where it stands, scorching and slowing everything around it, and the Knight cleaves into the gap. The more you play with any Ember Fox, the closer your bond: at bond 5 it gains a second passive; at bond 10 you feed it kindling and it evolves into one of two shapes, each with a third passive of its own. One day a champion's ultimate devours an elite, or, aimed at the fox, devours the fox: a shield, a heal and haste for ten seconds, and the fox is an imprint for 45 seconds before it comes back. It's never required, and it never happens by accident.

## References
- **Hades II's familiars and Hades' companions** (the companion keepsakes you summon with Call). Take: one helper at a time, each with its own personality and perks; a helper on its own button for big moments. Don't take: a few uses per escape (a long cooldown instead).
- **Pokemon.** Take: species with abilities of their own; eggs that hatch by playing; branching evolutions (Eevee); friendship that grows by playing together; duplicates kept as individuals. Don't take: a team of six, catching mid-fight, the pet fighting as a unit.
- **League of Legends.** Take: old Tahm Kench's W (devour an enemy or an ally; the aim decides); adaptive force (scale from the higher of AD and AP). Don't take: pets with health bars that enemies can kill.
- **Diablo IV.** Take: the Codex of Power (you only craft what you've found once); enchanting (reroll one line for a cost); the Necromancer's Book of the Dead (giving up a minion for power). Don't take: minion armies.
- **Baldur's Gate 3.** Take: Scratch and the owlbear cub (a companion with personality that tags along); Find Familiar (a spirit that falls and comes back). Don't take: controlling the pet turn by turn.

## Principles
1. **One at a time, never a Unit.** A companion follows its champion, takes no hits and is never targeted by anyone else. Its command is the champion's cast.
2. **As unique as a champion** (Ryan, 2026-10-03). Each species has its own passives, its own command and its own quirk list; nothing is shared between companions.
3. **Never touches the champion's kit** (Ryan, 2026-10-03). A companion changes no champion ability and not the champion's passive.
4. **The one power exception, kept narrow** (VISION.md, Meta-progression). The companion taken along powers whichever champion takes it; nothing else account-wide gives power.
5. **Consuming is a choice.** No ability needs the companion; giving it up is offered, never required, never by accident.
6. **Built from what exists.** `ToolkitBundle` for passives, LOOT's `Affix` and roll bands for quirks, AbilityComponent for the command, a condition and a status for the consume, Progress's save pattern, 3D.md's views.
7. **Never lost.** A copy is saved the moment it's found, and kept through death and leaving a run (VISION.md, Death).
8. **Tuning is data.** Quirk counts, bands, bond, costs and drop chances live in .tres files.

## Current code
- Nothing about companions exists. What it builds on:
- `ToolkitBundle` (`res://scripts/data/toolkit_bundle.gd`, TALENTS T1): the bundle `Passive` and `Talent` extend; `apply_to(unit, source_id, left_out_stats)` and `remove_from(unit, source_id)` restore a unit exactly.
- `AbilityComponent` (`res://scripts/components/ability_component.gd`): four slots, `const SLOTS = [q, w, e, r]` with the exports `q`–`r`; `get_cooldown_duration()` applies `ability_haste` (`StatsComponent.get_cooldown()`). `Ability.get_modifier_scopes()` returns `ability:<id>`, `ability:<variant_of>` and one `tag:<tag>` per tag. `Player.ABILITY_ACTIONS` maps the slots to `ability_q`…`ability_r`, read in `_unhandled_input`.
- Targeting: every target query goes through the `units` group (`Unit._ready()`; `AbilityUtil.enemies_of()`), so a node that isn't a Unit is never found, hit or aimed at by anything.
- The toolkit pieces the consume needs exist: conditions (`SELF_HAS_STATUS` … `LAST_PART_HIT`), `ConditionalBonus.self_statuses`, `HealGameplayEffect`, `status_shield.tres`, `status_haste.tres`.
- `Progress` (`res://scripts/autoload/progress.gd`): `user://progress.cfg`, read lazily; `is_test_scene()` turns saving off under `res://scenes/tests/`; `get_tracked_player()`; kill XP from `ChampionLeveling.get_kill_xp()` (the temporary `xp_by_unit`: slime 5, elite 40).
- The hub (`hub.tscn`, `hub.gd`, `TalentScreen`): functional, 640×360; its buttons take no focus.
- 3D view: `WorldView` snaps a view whose sim node moved more than 64 px in one tick (`TELEPORT_PX`); `unit_at_screen_point()` picks enemies only (P5). P6 (built 2026-10-03, awaiting Ryan's check) built the generic view mechanism: a sim node joins `view_source` in its `_ready()` and answers `get_view_scene()` (an export `view_scene`; null = its default, loaded with `load()` only when a WorldView asks, since a sim script never preloads a view scene); WorldView preloads the defaults it lists (`DEFAULT_VIEW_SCENES`); views extend `EntityView` (`setup()`, `sync()`, `on_sim_exited()`); `UnitView` places action clips by progress (`action_start` / `action_strike` / `action_end`); status VFX views sit over their unit's model (`WorldView.unit_height_m()`).
- LOOT.md is written but not built: `Affix`, `Item.Rarity`, the roll bands, `ItemRoller`, `DropTable`, `Pickup`, the keep-current hold (`set_gain_on_max_raise()`), and a materials bucket reserved per champion.
- Input: **Tab is free.** None of the 18 actions in `project.godot` uses it and no script reads it. Godot's built-in `ui_focus_next` uses Tab to move focus in menus; the pause menu grabs focus when it opens; the hub's and the talent screen's buttons take no focus.

## Goal / feel
| What | Number (TARGET) | Why |
|---|---|---|
| Follow spot | 40 px (1.25 m) behind the champion's last walking direction, 16 px (0.5 m) to its side | close, out of the aim's usual path *(proposed)* |
| Catch-up | eases toward its spot (rate 10/s), at most 1.5 × the champion's move speed (180 px/s for the Knight) | settles about 0.7 s after a 128 px dash *(proposed)* |
| Teleport | beyond 256 px (8 m), or when walls or a ledge have blocked the line to the champion for 0.4 s | never left behind; crosses cliffs and doors *(proposed)* |
| Command cooldown | **25–50 s** per companion, no ability haste | Ryan, 2026-10-03 |
| Imprint | the consuming ability's `companion_imprint_time`, about 45 s (30–60) | Ryan, 2026-10-03 |
| Bond | 10 levels: the second passive at bond 5 (about 4.4 runs), evolving at bond 10 (about 14 runs) | *(proposed)* |
| Quirks | 1–4 per copy, by rarity | Ryan, 2026-10-03 (LOOT's rules) |
| Companion drop | 3% per elite kill (1–5%) | *(proposed)* |
| Kindling | about 17 a run | *(proposed)* |
| Eggs | hatch after 3 counted runs | *(proposed)* |

## Rules
### What a companion is (MUST; Ryan 2026-10-02 and 2026-10-03)
- A **companion** is a bound spirit that follows the champion, one at a time. It never fights as a unit: no health, no stats, no collision, no pathing, and it isn't a `Unit`. So nothing can hit, target, push, slow or kill it.
- It's untargetable by anyone but its own champion, and only its champion can make it leave, by consuming it (Consuming the companion). Enemies, hazards, pits and knock-ups never touch it.
- A **species** is a kind of companion (a `CompanionData`): its own passives, its own command, its own quirk list, two evolutions, its look. A **copy** is one companion you own: its species, rarity, quirks and evolution. You can own several copies of one species.
- Companions are **account-wide collectibles**: every copy can go with every champion.
- **A kit as unique as a champion's** (Ryan, 2026-10-03: "the same level of uniqueness as champions, just no abilities and stats"): a base passive, a second passive at bond 5, a third from its evolution, and its own command on Tab. No passive pool is shared between companions.
- **It never changes a champion's abilities or passive** (Ryan, 2026-10-03): no augment on a champion's ability, no `ability:` or `tag:` scope on the champion's ability numbers, nothing left out of or added to the champion's passive.
- **The power exception** (Ryan, 2026-10-02; VISION.md, Meta-progression): a companion's passives, quirks and command work for whichever champion takes it along. It's the only account-level thing that gives combat power.
- **No companion** is allowed. A champion can go without one, and then the game plays exactly as it does today.

### Rarity and quirks (MUST: its own list, LOOT's ladder, count and rolls only, the counts below; Ryan 2026-10-03)
- A **quirk** is one rolled line on a copy (Ryan's word, 2026-10-03; CONVENTIONS keeps "trait" off talents, so it isn't used). Each species has its own quirk list, written for it and never shared; a copy's quirks come only from its species' list.
- A copy has a rarity from LOOT's ladder (Common → Artifact; LOOT's names and colors). Rarity decides **only** how many quirks a copy has and how high they roll, in LOOT's roll bands. It never changes the passives, the command or the evolutions.

| Rarity | Quirks | Roll band (LOOT.md) |
|---|---|---|
| Common | 1 | 0.00–0.35 |
| Uncommon | 2 | 0.10–0.50 |
| Rare | 3 | 0.25–0.65 |
| Unique | 3 | 0.35–0.75 |
| Exotic | 4 | 0.35–0.75 |
| Legendary | 4 | 0.55–0.95 |
| Artifact | 4 | always the maximum (no roll) |

  Why these counts (confirmed by Ryan, 2026-10-03): LOOT's own counts (1, 2, 3, 3, 3, 3 fixed, 4 fixed) would make a Unique copy and an Exotic copy identical: on gear the step between them is the second sigil, and companions have none. So the Exotic step adds a fourth quirk, and Legendary keeps four with its higher band.
- **A quirk is a stat line** (confirmed by Ryan, 2026-10-03): one `Affix` (LOOT.md) applied to the champion, themed to the species ("+3–8% move speed", "+5–12% damage to burning enemies"): a plain stat, or a `hit:` / `target:` damage scope. Never `ability:` or `tag:` (principle 3), and no sustain (life on hit, life steal, regen: LOOT's rule until ENEMIES_AI.md). Quirks that tune a passive's own numbers (a longer burn) come when a species first needs one (Open questions).
- A copy never has the same quirk twice. A species' list has at least 4 quirks, so an Exotic or better copy can have 4 different ones (validated).
- The roll is saved, not the value (LOOT's rule): a retune reaches every copy already owned. Values round to the affix's `step` at roll time.

### Passives (MUST shape, Ryan 2026-10-03; size TARGET)
- Three per species: the **base passive** (from bond 1, so from the first copy), the **bond passive** (from bond 5) and the **evolved passive** (its chosen evolution's; Evolutions).
- A passive is a `CompanionPassive`, a `ToolkitBundle` like a champion's passive, holding only:
  - stat modifiers and StatScalings on plain stats or `hit:` / `target:` damage scopes (move speed, health, crit, magic find, pickup radius...);
  - reaction rules ("when X happens, do Y", like LOOT's sigils: on a kill, a hit, a crowd control you apply, a cast), and the statuses those rules apply. A rule's `required_ability_scope` may filter by tag ("when you cast a mobility ability"): it reads an event and changes no ability;
  - always-on statuses on the champion;
  - **its own command only:** modifiers scoped `ability:<its command id>`, and FLAG or EVENT augments scoped to it ("its Flare also roots") (Ryan, 2026-10-03: passives may power up the companion's own command).
- Never: a REPLACE; an augment or an `ability:` / `tag:` scope on a champion's ability; any change to the champion's passive. Validated by `CompanionPassive.get_validation_errors()`; a passive that fails it `push_error`s and isn't attached.
- A passive's damage goes through `DealDamageGameplayEffect`, a `proc`-tagged hit (LOOT's sigil rule): it can't crit, trigger on-hit or chain into itself.
- **Size** (TARGET): the three passives at bond 10 together are worth about one Exotic item (Ryan, 2026-10-03). Quirks come on top, each smaller than the matching gear affix *(proposed: about 60% of its range)*.
- The two evolutions' passives differ in kind, not size *(proposed: TALENTS' authoring rule, applied here)*: two ways to play the companion, never a bigger one and a smaller one.

### The command (Tab) (MUST, Ryan 2026-10-02 and 2026-10-03; numbers TARGET)
- Each species has one **command**, an `Ability` cast with Tab. It's fixed: talents, items, sigils, quirks and rerolls never change it, and no hub screen edits it. Only its own companion's passives may power it up (above). "The Tab ability can't be modified at the hub" means no hub choice targets the command directly; a passive unlocked by bond, or by the evolution picked, may power it up (confirmed by Ryan, 2026-10-03).
- It can be anything a champion's ability can be (Ryan, 2026-10-03): damage, crowd control, a shield, swapping places, a field where the companion stands. Every cast style and targeting works.
- **Cooldown 25–50 s** (Ryan, 2026-10-03): "not as impactful as an ult, but great utility and opportunity for bigger damage windows if used correctly". **Ability haste never shortens it** (Ryan, 2026-10-03), and no item, talent or sigil reaches it. Its cooldown is the companion's own, the same on every build.
- **Adaptive damage** (Ryan, 2026-10-03): a command's damage scales from the higher of the champion's attack damage and ability power (League's adaptive force), through a new `DamageScaling` kind, `CASTER_ADAPTIVE`. It compares the final values (confirmed by Ryan, 2026-10-03) (the Knight: 64 AD against 0 AP, so AD) and a tie goes to AD; the damage type follows (PHYSICAL from AD, MAGIC from AP).
- **The caster is the champion.** The command's hits are the champion's: kill credit, crit, plain damage stats such as `damage_increase`. The command may act from the companion's point (a field around it, a projectile from it, swapping places with it); its script reads the point from the champion's `CompanionComponent`.
- **Recasts, per companion** (Ryan, 2026-10-03; League's Zed W): a command may have recast parts. It uses the recasts ABILITIES.md already has (built: `recast_count`, `recast_window`, `CastContext.part`, `recast_conditions`, `LAST_PART_HIT`, the Tab slot's gold window bar): pressing Tab again inside the window casts the next part, and the 25–50 s cooldown starts when the last part is used or the window ends (ABILITIES.md, Charges and recasts). A Zed-style command: part 0 sends the companion to a point, where it waits (**stationed**, Following); part 1, inside the window, swaps the champion and the companion. What it needs that isn't built yet: stationing (CompanionComponent, CO3) and `MovementComponent.blink()` for the champion's half of the swap (ABILITIES.md's "later" movement method, first needed here; a teleport, so it resets physics interpolation). A part that needs where an earlier part started (a "go back" command) reads `CastContext.sequence`, built in LOOT L6.
- It can only be cast while the companion is out: every command has the cast condition `SELF_HAS_STATUS companion` with the fail text "Your companion is an imprint", and a command with recasts has it in its `recast_conditions` too (validated). A press during the imprint fails with the usual "condition" cue and isn't buffered.
- Its one role tag is a new sixth role, `companion` (with the conflict fixes, Ryan 2026-10-03; ABILITIES.md, Standard tags), and it carries no other tag except a style tag its cast style needs. Its modifier scopes are only `ability:<its id>`, so a `tag:` modifier (an item's "mobility cooldown −10%") never reaches it.
- Cast mode, the input buffer, cast progress, the presentation hooks and the sound hooks work as for Q/W/E/R.

### Consuming the companion (MUST, Ryan 2026-10-02 and 2026-10-03)
- Some champions' abilities can **consume** the companion. Ryan's example: an ultimate that devours an enemy for damage, or devours your companion for a shield, healing and +30 ability haste for 10 s.
- **Never mandatory** (Ryan, 2026-10-02): an ability that can consume the companion has its full use without it, and no champion ability needs a companion to be cast. A champion's kit plays fully with no companion chosen. *(proposed)* A champion's ability may read the companion's presence for a bonus (`SELF_HAS_STATUS companion` in a conditional bonus), never in its cast conditions.
- **Not the Knight** (Ryan, 2026-10-03): his kit passed CH-M and ships as it is. The framework is built and tested with a sandbox test ability (`test_devour`); its first real user is a future champion designed around it.
- **The aim decides** (Ryan, 2026-10-03; old Tahm Kench's W): cast on an enemy, it's the enemy; cast with the cursor on your companion, it consumes the companion. Never automatic. *(proposed)* With the cursor over an enemy and the companion at once, the enemy wins; while such an ability is aimed at the companion, a ring around the companion shows it's the target (a floor drawing).
- **Consumed at the effect**, not at cast start (`CastContext.consumes_companion`, read at the cast flow's step 10): a cast cancelled or interrupted before its effect leaves the companion untouched, so a cancel never costs it. *(proposed)* Consuming ignores cast range (the companion is always near; its view rushes to the champion during the cast time).
- The payoff is data: a `ConditionalBonus` with the new condition `CONSUMES_COMPANION` and its `self_statuses` (a shield, +30 ability haste for 10 s), plus whatever the ability's script does (a heal through `Unit.heal()`).
- **Only the player can kill it** (Ryan, 2026-10-02): consuming is the only way a companion leaves.

### The imprint (MUST, Ryan 2026-10-03)
- A consumed companion isn't destroyed: it's an **imprint** until it comes back (Lore). For how long is the consuming ability's `companion_imprint_time` (about 45 s, TARGET 30–60), in game time.
- While it's an imprint: its passives are quiet (removed by their source ids), and so are its quirks *(proposed)*; the command can't be cast; the Tab slot shows the time left, like a cooldown. The command's own cooldown keeps running.
- No bond is lost, and none is gained while it's an imprint.
- When the time is up it comes back next to the champion. A checkpoint respawn, a new run, a restart or the hub bring it back at once.
- Coming back never heals: a returning max-health passive keeps the current health (LOOT's keep-current hold), as a live gear swap does.

### Following (MUST: a light sim point, Ryan 2026-10-03; numbers TARGET)
- The companion is a point in the sim: a `CompanionComponent`, a `Node2D` child of the Player (`top_level`), with no body, no collision and no pathing. The 3D view follows it like any sim node, and tests can check where it is.
- Each physics tick it eases in a straight line toward its follow spot (Goal / feel), through anything. The spot is kept out of walls (a shape sweep from the champion's feet).
- It **teleports** to its spot, with `reset_physics_interpolation()` (CLAUDE.md), when it's more than 256 px away, or when walls (layer 1) or a ledge (layer 11) have blocked the line between it and the champion for 0.4 s (`WorldQuery.has_line_of_sight()`). So it crosses cliffs (3D.md, ledges), doors and corners. *(proposed, an accepted look)* A spirit may drift through a wall corner for a moment before the line counts as blocked.
- **Stationed** (for recast commands like Zed's W; Ryan, 2026-10-03): a command can send the companion to a point (`station(point, travel_time)`), where it stays. While stationed it doesn't follow, and neither the leash nor the blocked line teleports it. It ends when the command's last part is used, when the recast window ends (`AbilityComponent.recast_window_finished` for the companion slot) or when the command's script releases it; then it eases back to its spot, teleporting if it's beyond the leash. It travels to the point in a straight line through anything (it isn't a Unit). *(proposed)* The point is the last valid spot short of a wall or a ledge on the line from the companion (a shape sweep on layers 1 and 11, like a VECTOR's start point), so a swap never crosses a wall or a cliff.
- While it's out, the champion carries `status_companion` (tag `companion`, applied by the champion to itself, until removed). Unique state is a status, so conditions can read it (ABILITIES.md, Data or script).

### Bond (MUST: per species and account-wide, Ryan 2026-10-03; numbers TARGET *(proposed)*)
- Bond belongs to the species, not the copy: every Ember Fox you own shares it, whichever champion plays. Switching to a better-rolled copy keeps your bond.
- Earned only while the companion is out (not an imprint), wherever the champion plays (the sandbox too, like TALENTS' counters):
  - each kill credited to the champion (TALENTS' kill credit): that kill's champion XP (`ChampionLeveling.get_kill_xp()`: slime 5, elite 40);
  - time in combat: 1 bond per 2 s while the champion has dealt or taken a hit that got through in the last 3 s (CHAMPIONS.md's "in combat"). Out of combat earns nothing, so standing still farms nothing.
- Against TALENTS' assumed run (100 kills, about 12 minutes in combat) that's about 1000 bond a run.

| Bond | To next | Total | Runs (≈1000) | Unlocks |
|---|---|---|---|---|
| 1 | 800 | 0 | 0 | the base passive |
| 2 | 1000 | 800 | 0.8 | |
| 3 | 1200 | 1800 | 1.8 | |
| 4 | 1400 | 3000 | 3 | |
| 5 | 1600 | 4400 | 4.4 | the bond passive |
| 6 | 1800 | 6000 | 6 | |
| 7 | 2000 | 7800 | 7.8 | |
| 8 | 2200 | 9800 | 9.8 | |
| 9 | 2400 | 12000 | 12 | |
| 10 (max) | — | 14400 | 14.4 | evolving (the evolved passive) |

- Saved as level plus bond into the level (TALENTS' rule), so a retune never takes a level away. Bond is never lost. *(proposed)* A bond passive reached mid-run attaches at once (the companion growing, not a hub choice), without a heal.

### Evolutions (MUST, Ryan 2026-10-03; costs TARGET)
- Each species has exactly two **evolutions** (Eevee-style). At bond 10, feeding kindling at the hub evolves a copy into one of them. An evolution sets the copy's look and its third passive; the command never changes.
- Per copy: two Ember Foxes can evolve differently. Changing a copy's evolution later costs kindling.
- The word is **evolution**, not "form": a form is ABILITIES.md's status that swaps a champion's slots.

### Getting companions (MUST: all four ways in the launch scope, Ryan 2026-10-03)
- **Drops.** Elites (and bosses, once they exist) can drop a dormant copy: a cocoon, an egg or a relic core (its species' `dormant_kind`). It's a pickup like loot (LOOT.md, Pickups) and joins the collection, saved, the moment it's collected. *(proposed)* 3% per elite kill (1–5%); its rarity rolled like an elite item's (LOOT's elite weights, the depth and the killer's magic find); its species from the dungeon's signature list (each dungeon has its own; DUNGEONS.md: `DungeonData.signature_companions`, *proposed*), until then from a temporary list on the companion table. Only kills by the tracked player or its AI ally drop anything (LOOT's kill credit; Ryan, 2026-10-03: an ally's kill drops companions and kindling too).
- **Eggs.** An egg is a dormant copy that hatches after its species' `hatch_runs` (3) counted runs. It waits on the companion screen with the runs left (Ryan, 2026-10-03; the nursery as a place comes later). *(proposed)* Until DUNGEONS.md defines a clear, a counted run is going back to the hub from `main.tscn` after at least 20 kills in that visit. The sandbox never counts. (DUNGEONS.md, 2026-10-03: a run is a wing of 45–90 minutes and a clear is its boss's death; *(proposed there)* a wing clear is a counted run. Three counted runs are then 2–4.5 hours of play, so `hatch_runs` is re-measured with the slice wing.)
- **Secrets and story.** Hidden companions, lore puzzles and a champion-linked companion in each champion's story give a copy through `Companions.acquire(species, rarity, origin)`. The content is DUNGEONS.md's and NARRATIVE.md's.
- **Crafting parts and clues as collectibles** (DUNGEONS.md, Rewards; Ryan 2026-10-03): secrets and collectibles in a wing can give **companion crafting parts** and **clues**, account-wide (the companion exception). *(proposed, DUNGEONS.md)* Parts are kindling caches now (a `Reward` of kind `KINDLING`, into this account bucket) and per-dungeon material kinds later (Kindling, below: "more kinds per dungeon come later"); a clue is a found hint (a codex-style entry) that points to a hidden companion's secret, so finding companions is something to hunt across the wings. A found collectible is never found twice (DUNGEONS.md's save).
- **Rekindling** (crafting; below).
- A cocoon or a relic core is awakened at the hub (free, at once), an egg once it has hatched. A dormant copy can't be taken along.
- *(proposed)* **A starter egg**: a new account gets one egg at the hub that hatches after its first counted run, so every player meets the system early.

### Rekindling, rerolling and releasing (MUST: known species only, Ryan 2026-10-03; costs TARGET *(proposed)*)
- **Rekindle** a new copy of any species you've found at least once, by any path, dormant copies included (Diablo IV's Codex of Power). Pay kindling and choose its rarity; for an extra cost per line, choose which quirks from its list it gets. Their values still roll in the rarity's band.
- **Reroll** one quirk of a copy: the new one comes from the species' list (never one the copy already has) and rolls in its band; the other quirks keep theirs (Diablo IV's enchanting).
- **Release** a spare copy for kindling. Never a copy a champion has chosen, and the screen asks to confirm.

| Kindling | Common | Uncommon | Rare | Unique | Exotic | Legendary | Artifact |
|---|---|---|---|---|---|---|---|
| Rekindle (quirks rolled) | 10 | 20 | 40 | 70 | 110 | 180 | drops only *(proposed)* |
| Each quirk picked instead of rolled | +3 | +5 | +10 | +18 | +28 | +45 | — |
| Reroll one quirk | 3 | 5 | 10 | 18 | 28 | 45 | 45 |
| Release a copy | 2 | 4 | 8 | 15 | 25 | 40 | 80 |

Evolving: 60. Changing a copy's evolution: 60.

### Kindling: companion materials (MUST: their own account bucket, Ryan 2026-10-03; the name and numbers *(proposed)*)
- Companion materials are saved with the companions, account-wide, apart from LOOT's per-champion materials bucket (Ryan, 2026-10-03). Any champion's runs fill it, and it's spent only on companions (rekindling, rerolling, evolving), so gear crafting (LOOT v2) never shares power between champions through it.
- One material at launch, **kindling** (placeholder name, from "rekindle"). Sources: 3 per elite kill, 1 per regular kill at a 5% chance, 15 per boss (later), releasing copies, and caches found as collectibles in wings (DUNGEONS.md, Rewards; amounts with the content). About 17 a run against TALENTS' assumed run (a wing of 45–90 minutes gives 2–4.5 times that at the same kill density). More kinds (per dungeon) come later.

### Choosing (MUST: at the hub only, Ryan 2026-10-03)
- The companion is chosen at the hub before a run and is fixed for the run, like the talent loadout. One at a time; none is allowed.
- *(proposed)* The choice is per champion: each champion remembers its own, and one copy can be every champion's choice (single player: only one plays at a time).

### Saving (MUST shape)
- Account-wide, in its own file: `user://companions.cfg` (a `ConfigFile`, never a .tres, which can carry scripts). One section, `account`: `next_uid`; the copies (one Dictionary each: `uid`, `species`, `rarity` as a word, `quirks` as [quirk id, roll] pairs, `evolution`, `state` (dormant, egg, awake), `runs_left`, `origin`); `bond` (species id → [level, bond into the level]); `known` (species ids); `materials` (material id → count); `chosen` (champion id → uid).
- Saved when a copy is acquired, awakened, rekindled, rerolled, evolved or released, when a choice changes, on a bond level-up, when the tracked player leaves the tree and when the window closes.
- **The test guard:** a scene under `res://scenes/tests/` never reads or writes it (`Progress.is_test_scene()`, the guard LOOT reuses). A scripted run outside the tests sets `Companions.saving_enabled = false` first (3D.md, Core rules).
- A saved copy whose species no longer exists is skipped at load with a warning, and its raw entry is written back unchanged, so a data fix brings it back (LOOT's rule). An unknown quirk id drops that line; an unknown evolution goes back to none; a chosen uid with no awake copy is cleared. Each with a warning. Bond for a deleted species is kept.
- PROGRESSION.md later folds this file into the one save.

### Lore (working lore: Ryan's draft of 2026-10-02 with his edit of 2026-10-03; NARRATIVE.md refines it)
- Companions are **bound spirits**. Looted ones are **dormant** (a cocoon, an egg, a relic core) and **awaken** at the hub. Crafted ones are **rekindled** from materials.
- A consumed companion isn't destroyed: it falls back to its **imprint** and returns from it (Ryan's word, 2026-10-03, replacing "reform"; the reading confirmed the same day: the imprint is the state a consumed companion is in until it returns). That's why it always comes back.

### Cosmetics and money (MUST, Ryan 2026-10-03)
- No dyes or skins at launch beyond the two evolutions' looks. Mutated variants from higher difficulties, other cosmetics and any monetization are decided later. Whatever comes stays look-only.

## Data (Resources)
Names approved with the conflict fixes (Ryan, 2026-10-03) and listed in CONVENTIONS.md (reserved names and vocabulary, planned until built). Resource scripts in `res://scripts/data/`.

### CompanionData (`companion_data.gd`; `res://data/companions/companion_<name>.tres`)
A species. `Data` suffix: a bundle of other resources, like `ChampionData`.

| Field | Type | Notes |
|---|---|---|
| `id` | `StringName` | `&"ember_fox"`; unique among species and champions (validated). Source ids `companion_<id>_base`, `companion_<id>_bond`, `companion_<id>_<evolution id>` |
| `display_name`, `lore` | `String` | the name; a line of flavor (NARRATIVE.md writes the real text) |
| `command` | `Ability` | the Tab command: role tag `companion`, the condition `SELF_HAS_STATUS companion` in its cast conditions (and its recast conditions when `recast_count` > 0), cooldown 25–50 s (validated) |
| `base_passive` | `CompanionPassive` | from bond 1 |
| `bond_passive` | `CompanionPassive` | from `CompanionTable.bond_passive_level` (5) |
| `evolutions` | `Array[CompanionEvolution]` | exactly 2 |
| `quirks` | `Array[Affix]` | its own list, inline (never shared files), at least 4; ids `<species>_<quirk>`; scopes plain, `hit:` or `target:` only; `slots` empty (validated) |
| `dormant_kind` | `CompanionData.DormantKind` | `COCOON`, `EGG`, `RELIC_CORE`: how a found copy arrives; an EGG hatches after `hatch_runs` |
| `hatch_runs` | `int` | 3 (EGG only) |
| `model_scene` | `PackedScene` | its 3D model; empty = a placeholder |
| `hover_height_m` | `float` | 0 = walks on the floor; above 0, floats (view only) |
| `icon_color` | `Color` | the HUD's and the screen's placeholder color |

Methods: `get_passives(bond_level, evolution_id) -> Array[CompanionPassive]`, `get_evolution(id)`, `get_quirk(id)`, `get_validation_errors(table) -> PackedStringArray`.

### CompanionPassive (`companion_passive.gd`; inline)
`CompanionPassive extends ToolkitBundle`: the same fields and attach code as a champion's passive, plus `get_validation_errors(companion) -> PackedStringArray` (the Passives rules: scopes, augments only FLAG or EVENT on its own command, no REPLACE). Not a `Passive`: CONVENTIONS' "passive" is a champion's, and the rules differ.

### CompanionEvolution (`companion_evolution.gd`; inline, exactly two per species)
`id` (`&"pyre"`), `display_name`, `description`, `model_scene` (empty = the species' model), `passive: CompanionPassive`.

### CompanionTable (`companion_table.gd`; `res://data/companion_tables/companion_table_default.tres`)
The global rules, held by `Companions.table`.

| Field | Type | Notes |
|---|---|---|
| `loot_table` | `LootTable` | LOOT's: the rarities' names, colors and roll bands (one source for the bands) |
| `quirk_counts` | `Array[int]` | 7, in `Item.Rarity` order: `[1, 2, 3, 3, 4, 4, 4]` |
| `bond_to_next` | `Array[int]` | `[800, 1000, 1200, 1400, 1600, 1800, 2000, 2200, 2400]`; its size + 1 = the max bond (10) |
| `bond_passive_level`, `evolve_level` | `int` | 5, 10 |
| `bond_per_combat_second` | `float` | 0.5 |
| `bond_kill_scale` | `float` | 1.0 × the kill's champion XP |
| `rekindle_costs`, `quirk_pick_costs`, `reroll_costs`, `release_yields` | `Array[int]` | 7 each (Rekindling); −1 = not allowed (Artifact rekindle) |
| `evolve_cost`, `change_evolution_cost` | `int` | 60, 60 |
| `material_id` | `StringName` | `&"kindling"` |
| `species` | `Array[CompanionData]` | every species (the save looks them up; validated) |
| `drop_table` | `DropTable` | LOOT's resource: `drop_table_companion_elite.tres` (`item_chance` read as the companion chance, 0.03; LOOT's elite rarity weights) |
| `drop_species` | `Array[CompanionData]` | **temporary, until DUNGEONS.md** gives each dungeon its signature list |
| `kindling_by_unit` | `Dictionary` | **temporary, until ENEMIES_AI.md**: unit file name → [chance, amount] (`slime` [0.05, 1], `slime_elite` [1.0, 3]), LOOT's stand-in pattern. ENEMIES_AI.md (2026-10-03) *(proposed there)* moves it onto each enemy's `EnemyData` (`kindling_chance`, `kindling_amount`) in its AI7; until then this table stands in, and CO6 reads `EnemyData` first when an enemy has one |
| `egg_run_min_kills` | `int` | 20 (the counted-run stand-in) |
| `starter_species` | `CompanionData` | the starter egg *(proposed)*; null = none |

Methods: `get_quirk_count(rarity)`, `get_band(rarity) -> Vector2`, `get_bond_to_next(level)`, `get_validation_errors()`.

### Additions to existing data
| Where | Addition | Default | Notes |
|---|---|---|---|
| `Ability` | `can_consume_companion: bool` | false | the cast may be aimed at the caster's own companion |
| `Ability` | `companion_imprint_time: float` | 45 | seconds a companion it consumes stays an imprint (TARGET 30–60) |
| `CastContext` | `consumes_companion: bool` | false | set by the aim; read at the effect |
| `DamageScaling.Of` | `CASTER_ADAPTIVE` (appended) | | ratio × the higher of the caster's `attack_damage` and `ability_power` |
| `Condition.Kind` | `CONSUMES_COMPANION` (appended) | | true when the cast is consuming the caster's companion (reads `cast`); false without a cast |
| `AbilityComponent` | export `companion: Ability`, slot `&"companion"` | null | the command's slot; set by CompanionComponent |
| statuses | `data/statuses/status_companion.tres` | | id `companion`, tag `companion` only (never `buff`, so no cleanse touches it), duration −1 |
| tags | role tag `companion` | | commands only (CONVENTIONS' standard tags) |
| input map | `ability_companion` | Tab | the command's key |

### Test and sandbox data
- `companion_test_wisp.tres` (COCOON) and `companion_test_moth.tres` (EGG): placeholder species, 4 quirks each, a passive of each piece kind, two evolutions, a command each: `test_wisp_tab_swap.tres` (Zed W-style, two parts: POINT, `cast_range` 500 u (160 px), `recast_count` 1, `recast_window` 4 s; part 0 stations the wisp at the point over 0.15 s, part 1 swaps the Knight and the wisp with `blink()`) and `test_moth_tab_flare.tres` (one part: an area at the companion's point, adaptive damage and a slow). Scripts in `scripts/abilities/test/`.
- `test_devour` (`test/devour.gd`, `test_r_devour.tres`): UNIT on enemies (120 + 80% AD), `can_consume_companion`; a conditional bonus `CONSUMES_COMPANION` → `self_statuses` a `status_shield` copy (150 for 3 s) and `status_devour_haste` (+30 `ability_haste`, 10 s); a heal of 15% max health in the script; `companion_imprint_time` 45. Put on the sandbox's Q through `SandboxAbilities.test_q`.

## Architecture / contracts
### Companions (autoload, `res://scripts/autoload/companions.gd`)
- Registered after `Progress` (and `Loot`), before `Audio` (which stays last).
- Holds the account's `CompanionCollection`, read lazily from `user://companions.cfg` at first use (Progress' pattern); `table: CompanionTable`; `rng: RandomNumberGenerator` (tests seed it); `saving_enabled`, `save()`.
- `acquire(species, rarity, origin) -> Companion`, `awaken(copy)`, `rekindle(species, rarity, picked_quirk_ids) -> Companion`, `reroll_quirk(copy, index)`, `evolve(copy, evolution_id)`, `release(copy)`, `choose(champion, copy)` (null = none), `get_chosen(champion) -> Companion`, `get_bond_level(species)`, `add_bond(species, amount)`, `get_material(id)`, `add_material(id, amount)`. Each action has `get_<action>_fail_reason(...) -> String` (`""` = allowed: "unknown species", "not enough kindling", "needs bond 10", "chosen"...), which the screen shows.
- Listens to `Events.unit_died`: bond for the tracked player's companion while it's out (CO2); kindling and companion drops (CO6). Counts runs for eggs (the stand-in).
- Signals, its own (like Progress'): `companion_acquired(copy)`, `bond_leveled_up(species_id, level)`.
- Debug: `debug_add_bond_level(species)`, `debug_add_material(amount)`, `debug_grant_all()`, `debug_hatch_all()`, `reset()`.

### Runtime classes (`res://scripts/companions/`)
- **`Companion`** (RefCounted, `companion.gd`): one copy. `uid`, `species: CompanionData`, `rarity: Item.Rarity`, `quirk_rolls` ([Affix, roll] pairs), `evolution: StringName` (`&""` = none), `state` (`DORMANT`, `EGG`, `AWAKE`), `runs_left`, `origin` (`DROP`, `EGG`, `REKINDLED`, `SECRET`, `STORY`, `STARTER`). `get_source_id()` (`&"companion_<uid>"`, its quirks), `get_quirk_modifiers(table) -> Array[StatModifier]`, `get_display_name()`, `get_tooltip_lines(table)`, `to_dict()`, `static from_dict(d, table) -> Companion` (null when its species is unknown).
- **`CompanionCollection`** (RefCounted, `companion_collection.gd`): `next_uid`, `copies`, `bond`, `known`, `materials`, `chosen`, the raw entries it couldn't read. `add(copy) -> int`, `get_copy(uid)`, `write_to(cfg)`, `static read_from(cfg, table)`.
- **`CompanionRoller`** (static functions, `companion_roller.gd`): `roll_quirks(species, rarity, table, rng, picked := [])` (picked ids first, the rest drawn without repeats, every value in the band; a band with equal ends draws nothing, LOOT's rule), `roll_drop(...)`. Rarity rolls reuse `ItemRoller.roll_rarity()`.

### CompanionComponent (`res://scripts/components/companion_component.gd`, a `Node2D` child of `player.tscn`)
- `top_level` (its position is its own). P6's view rule: it joins `view_source` in its `_ready()` and answers `get_view_scene()` (an export `view_scene`; null = `res://scenes/view/companion_view.tscn`, loaded with `load()` only when a WorldView asks, never preloaded); WorldView's `DEFAULT_VIEW_SCENES` gets that scene.
- `Player._attach_champion()`, after the talents and the gear, calls `setup(Companions.get_chosen(champion))`. None: nothing happens (no point, no slot, no status). Otherwise it places itself at its spot, applies `status_companion`, attaches the passives its species' bond and the copy's evolution allow (`ToolkitBundle.apply_to()` under their source ids), adds the quirks' modifiers under `companion_<uid>`, and puts the command in AbilityComponent's `companion` slot.
- `is_present()`, `get_point() -> Vector2`, `get_copy()`, `consume(imprint_time) -> bool` (false when not out), `bring_back()` (at once: checkpoints, debug), `get_imprint_time_left()`. Stationing: `station(point, travel_time) -> Vector2` (the clamped point it goes to), `release_station()`, `is_stationed()`; it listens to its AbilityComponent's `recast_window_finished` and `cast_finished` for the companion slot to end a station. Signals: `consumed`, `returned`, `teleported(from, to)`, `stationed(point)`, `station_released`.
- Following and teleporting as in Rules, Following, every physics tick in game time (hitstop freezes it).
- Bond: each physics tick while it's out and the champion is in combat (its own clock on `Events.unit_hit`, CHAMPIONS' rule), it adds to the species' bond through `Companions.add_bond()`. On `Companions.bond_leveled_up` for its species it attaches the newly reached passive at once.
- Attaching or removing passives while the champion is alive holds current health and resource (`set_gain_on_max_raise(false)`, LOOT L2's hold): a return or a level-up never heals. At load the old rule applies, so the champion still starts full.
- Exports: `follow_back_px` 40, `follow_side_px` 16, `follow_rate` 10, `max_speed_scale` 1.5, `leash_px` 256, `blocked_teleport_time` 0.4, `combat_window` 3.0, `pick_radius_px` 16, `debug_draw`.

### AbilityComponent and the Player
- A fifth slot, `companion` (export `companion: Ability`), with the same per-slot state, cast flow, buffer and fail cues as Q/W/E/R (ABILITIES.md, AbilityComponent). `SLOTS` stays the champion's four, so code that means the champion's slots keeps meaning them (the talents' groups, the resource bar's thresholds); a new `ALL_SLOTS` adds `companion` where every slot is meant (cooldowns, casting, `get_all_abilities()` for StatsComponent's key check, `get_slots_matching()`).
- `get_cooldown_duration()`: an ability whose role is `companion` takes its `cooldown` param without ability haste.
- `Ability.get_modifier_scopes()`: an ability whose role is `companion` returns only `ability:<id>`.
- `ModifyCooldownGameplayEffect` with an empty `ability_scope` ("every slot") skips the companion slot (with the conflict fixes, Ryan 2026-10-03).
- `Player.ABILITY_ACTIONS` gets `&"companion": "ability_companion"`.
- **The consume aim:** for an ability with `can_consume_companion`, the Player's press picks the companion when the cursor is over its view (3D: its view's box on screen, as P5 picks enemies) or, without a view, within `pick_radius_px` of its point. An enemy under the cursor wins. Then `ctx.consumes_companion` is true, and a UNIT ability needs no unit target and doesn't walk into range.
- **At the effect start** (ABILITIES.md, the cast flow's step 10), before the conditional bonuses' `self_statuses`: if `ctx.consumes_companion`, `CompanionComponent.consume(companion_imprint_time)`; if it isn't out any more, `ctx.consumes_companion` turns false (so the bonus doesn't pass).

### HUD
- A fifth slot on the ability bar, right of R with a gap, labeled "Tab" (from a label table, not the slot name: CLAUDE.md's known W-label issue): the command's initials and cooldown; during the imprint, the time left in a pale tint. Its tooltip: the command's tooltip, then the companion's name and rarity (in its color), its quirk lines and its passives with "Now:" lines (the passive slot's style). Shown only while a companion is chosen. Functional, no art (CHAMPIONS CH6's spirit).

### The companion screen (hub)
- `CompanionScreen` (`res://scripts/ui/companion_screen.gd`) in `hub.tscn`, behind a **Companions** button; the hub shows either it or the talent screen (both don't fit at 640×360). Functional placeholder text, like TalentScreen.
- It lists every copy: species, rarity (in its color), quirks with their values, evolution, its species' bond ("Bond 6: 1200 / 1800"), and the state (dormant, an egg with runs left, chosen by which champion). Kindling at the top.
- Actions, each greyed with its reason when not allowed: **Take along** (for the hub's champion; again on the chosen one = none), **Awaken**, **Rekindle** (a known species, a rarity and optional quirk picks, with the cost), **Reroll** a quirk, **Evolve** (bond 10; pick one of two, each showing its passive) and **Change evolution**, **Release** (asks to confirm).
- `debug_tools` (on in the hub scene, like the talents'): +1 bond for a species, +100 kindling, grant one of each species, hatch every egg, reset.

### SandboxCompanions (sandbox only; keys FREE)
`res://scripts/rooms/sandbox_companions.gd` in `sandbox.tscn`, like `SandboxTalents`: a small list. **N** cycles the live Knight's companion through every species, none included (Shift+N goes back), **B** adds a bond level to its species (debug), **I** consumes it or brings it back. It never changes the save: the hub's screen is the real one. N, B and I are unbound elsewhere.

### Drops (CO6)
- `Companions` on `Events.unit_died` (a kill by the tracked player or its AI ally, not a training dummy; the ally with ALLIES' step, as in LOOT): kindling from `kindling_by_unit` (from the dead enemy's `EnemyData` once it has one: ENEMIES_AI.md), and a companion at the `drop_table`'s chance (rarity by `ItemRoller.roll_rarity()` with the depth and the killer's magic find, a species from `drop_species`).
- A drop is LOOT's `Pickup` carrying a `Companion` or an amount of kindling instead of an `Item` (an addition to LOOT's Pickup, made in CO6): layer 9, the pop, collected on proximity by `PickupComponent`. `Companions.collect()` adds it (saved; its species becomes known) and the HUD shows a line in its rarity's color ("Rare Ember Fox (cocoon)", "+3 kindling").

## View
- `CompanionComponent` declares its `view_scene`: `CompanionView` (`res://scripts/view/companion_view.gd`, extends `EntityView`, 3D.md P6). It shows the copy's model (its evolution's `model_scene`, else the species', else a 0.4 m placeholder sphere in `icon_color`) at the terrain height plus `hover_height_m`, turning toward where it moves (toward the champion's facing when still), with idle and move clips named by exports, like `UnitView`'s.
- The command's `cast_anim` plays on the companion's model, positioned by cast progress the way `UnitView` places action clips (`action_start` / `action_strike` / `action_end`, P6; ABILITIES AB14's hook) *(proposed: the champion's model plays nothing for a command)*. Its `cast_vfx` and `impact_vfx` work as for any ability; a projectile fired from the companion starts at its view's height.
- A teleport plays a puff at both ends (VFX); WorldView already snaps any view whose sim node moved more than 64 px in a tick.
- Consumed: it rushes into the champion over the cast time, then hides. Returning: it fades in at its spot.
- The consume aim: WorldView picks the companion's box on screen (P5's `screen_rect_of()`), and a ring around it is drawn on the floor (`FloorOverlay`, P7) while it's the aimed target.
- Dormant pickups: the cocoon, the egg and the relic core as the `Pickup`'s view (LOOT.md), in the rarity's color.
- The hub: none at launch (the screen is text). The menagerie and a 3D preview are UI.md's, later.
- `debug_draw` on CompanionComponent: the follow spot, the leash circle, the line to the champion (red while blocked) and the pick radius.

## Audio hooks
Audio hooks: see AUDIO.md. The command uses the ability hooks (`cast_sound`, `hit_sound`, `ready_sound`). New ones to add when built (synthesized placeholders until real files): consumed, returned, a quiet teleport puff, a companion drop landing (LOOT's drop sounds by rarity), awaken and hatch, a bond level-up, evolving (the hub's UI sounds, UI.md).

## How each edge case is handled
| Edge case | Handling |
|---|---|
| No companion chosen | Nothing changes: no point, no Tab slot, no status; the game plays exactly as today |
| An enemy ability, a hazard, a pit, a knock-up, an untargetable champion | Never touches the companion: it isn't a Unit and has no body |
| Enemy AI | Never sees it (not in the `units` group) |
| The champion dashes across a ledge or through a door | The line is blocked for 0.4 s, so it teleports to its spot (a puff) |
| The champion is teleported (a respawn) | It teleports along, with `reset_physics_interpolation()` |
| The cursor is over an enemy and the companion at once | The enemy wins: consuming is never the default |
| A consume cast cancelled (dash, Esc, a move) or interrupted (stun, death) | The companion is untouched: it's only consumed at the effect |
| Aiming at where an imprint was | Nothing to pick there: the cast goes to enemies as usual |
| Tab during the imprint | Fails with the "condition" cue ("Your companion is an imprint"), not buffered; the slot shows the time left |
| A command projectile in flight when the companion is consumed | It keeps flying: it's the champion's projectile |
| A recast command's window ends without the recast | The station ends and the companion eases back (teleports past the leash); the cooldown starts (ABILITIES.md's rule) |
| The champion walks past the leash while the companion is stationed | No teleport: it stays at its point until the station ends |
| The companion is consumed during a recast window | It leaves from its stationed point; the next part fails its recast condition (the "condition" cue); the window runs out as usual and the cooldown starts |
| A checkpoint respawn or a restart during a window | It comes back at its spot, not stationed (a new sequence) |
| The swap with a stationed companion | The champion lands on the station point, which was clamped short of walls and ledges *(proposed)*, so it's always floor the champion can stand on; `blink()` resets physics interpolation |
| The champion has 50 ability haste | Every Q/W/E/R cooldown is shorter; the command's isn't |
| An item's `tag:mobility` cooldown affix and a mobility-shaped command | Never reaches it (its only scope is `ability:<id>`) |
| An empty-scope `ModifyCooldownGameplayEffect` ("reset every cooldown") | Skips the command |
| Adaptive damage with AD equal to AP | AD, PHYSICAL |
| Kills by the command | The champion's: they count for kills, champion XP, drops and bond |
| Progress' ability-use counter | Counts the command's casts under its id; nothing reads them (no talent group) |
| A bond level reached mid-run | The bond passive attaches at once, without a heal *(proposed)* |
| The companion returns with a max-health passive | Current health kept (the keep-current hold): never a heal |
| A kill while it's an imprint | No bond |
| Checkpoint respawn, restart, a new run, the hub | Back at once; the imprint ends |
| A room change inside a run | The imprint carries on *(proposed; DUNGEONS.md, 2026-10-03: a floor change is a fade inside the run, and it proposes the same)* |
| Two copies of one species | They share the bond; each keeps its own rarity, quirks and evolution |
| Releasing the chosen copy | Not allowed (the screen says why) |
| A copy's species deleted from the data | Skipped at load with a warning, raw entry kept; its bond kept; a choice of it cleared |
| A quirk's range retuned | The value follows (the roll is saved) |
| A quirk removed from its species' list | That line dropped at load (warning) |
| An Artifact copy | Its quirks are at their maximum (no roll); not rekindled *(proposed)* |
| An egg | Hatches after its counted runs; can't be taken along until awake |
| Training dummies | No kill, so no bond or kindling; hitting them still counts as in combat (as TALENTS' counters count casts on them) |
| Alt+Tab to switch windows | Must not cast the command: CO3 checks it on Ryan's machine |
| Tests | Saving off in a test scene (`Progress.is_test_scene()`); tests seed `Companions.rng` |

## Build order (one step per request)
Every step: the Knight's abilities, talents, enemies chasing and the HUD still work, and with no companion chosen the game plays exactly as before. Build logs go in CHANGELOG.md (a Companions section); this doc keeps one line per built step.

**Before CO1:** LOOT L1 (`Affix`, `Item.Rarity`, the bands, `ItemRoller`). **Before CO2:** 3D P6 (views; passed 2026-10-03) and LOOT L2's keep-current hold (or CO2 builds the hold exactly as LOOT.md specifies it). **For CO4's ring:** P7 (`FloorOverlay`). **Before CO6:** LOOT L7 (`Pickup`).

1. **CO1 – Data, rules and the save.** `CompanionData`, `CompanionPassive` (with its validation), `CompanionEvolution`, `CompanionTable` + `companion_table_default.tres`, `Companion`, `CompanionCollection`, `CompanionRoller`, the `Companions` autoload (the save, the test guard, acquire, awaken, rekindle, reroll, evolve, release, choose, bond levels, kindling, the egg run stand-in), the two test species; `res://scenes/tests/companions_test.tscn` + `scripts/tests/companions_test.gd`. Docs: CONVENTIONS' companion rows go from planned to built.
   **Done means:** over seeded rolls every rarity gets its quirk count and every value sits in its band and range, rounded to its step; no copy has a quirk twice or one off its species' list; rekindling only works for known species and charges the table's costs; rerolling changes one line only; evolving needs bond 10; validation catches each broken rule (a REPLACE, a champion-ability scope, a `tag:` quirk, fewer than 4 quirks, not exactly two evolutions, a command without the role tag or the condition, a cooldown out of range); a save and reload keeps copies, bond, known species, kindling, eggs and choices; an unreadable entry survives a save; tests never write the real file; every existing suite passes.
2. **CO2 – The follower.** `CompanionComponent` (the point, following, teleports, `status_companion`, passives and quirks by bond and evolution, the keep-current hold, the imprint state with `consume()` / `bring_back()`, bond from kills and time in combat), the Player attaching the chosen copy, `CompanionView` with a placeholder model, `SandboxCompanions`, `debug_draw`.
   **Done means:** in the sandbox (2D and 3D) the test wisp trails the Knight at its spot and settles about 0.7 s after a dash; nothing hits, blocks or pushes it; crossing the wall gap makes it teleport within 0.4 s; at bond 1, 5 and 10 with an evolution the right passives sit under their source ids, and consuming it (I) restores every stat exactly; coming back doesn't heal; bond rises with kills and fighting, not while idle or an imprint; with no companion every suite is unchanged; Ryan's check at 180 Hz: no stutter, no pop except the teleport's puff.
3. **CO3 – The command (Tab).** The `ability_companion` action on Tab (editor steps), AbilityComponent's `companion` slot, no haste and the `ability:`-only scopes, the role tag `companion`, `CASTER_ADAPTIVE`, the condition-gated cast and recast, stationing (`station()` / `release_station()`), `MovementComponent.blink()`, the test commands (the two-part swap, the flare), the HUD's Tab slot and its tooltip.
   **Done means:** Tab sends the wisp to the aimed point (short of walls and ledges), it waits there through the window even when the Knight walks past the leash, Tab again inside the window swaps them with no slide, and the cooldown starts after the swap or when the window ends (then the wisp eases back), with the gold window bar on the Tab slot; the moth's flare hits around it; the flare's damage follows the higher of AD and AP (a test unit with more AP deals MAGIC); its cooldown is the .tres value with 50 ability haste on the Knight; an item's `tag:` modifier and an empty-scope cooldown reset never touch it; during an imprint Tab fails with the condition cue and the slot shows the time left; Alt+Tab doesn't cast it; with no companion the bar is as before; Ryan's play test.
4. **CO4 – Consuming the companion.** `Ability.can_consume_companion` and `companion_imprint_time`, `CastContext.consumes_companion`, `Condition.Kind.CONSUMES_COMPANION`, the consume aim (2D radius, 3D screen pick, the floor ring), the consume at the effect start, `test_devour` on the sandbox's Q.
   **Done means:** on an enemy, `test_devour` damages it and the companion stays; with the cursor on the companion it's consumed at the effect (shield 150, +30 ability haste for 10 s shown in the cooldowns, the heal), Tab shows a 45 s imprint, the passives are off, then it comes back next to the Knight; a cancelled or interrupted cast leaves it untouched; an enemy next to it under the cursor wins; a restart brings it back at once; Ryan's play test: it never happens by accident.
5. **CO5 – The companion screen.** `CompanionScreen` in the hub, the Companions button, every action with its reason and cost, the eggs' runs left, the debug row; the starter egg if approved.
   **Done means:** at the hub every copy shows its rarity, quirks, evolution, bond and state; Take along works per champion and Start run takes it along; awaken, rekindle, reroll, evolve, change evolution and release follow the rules and costs, and the kindling count follows; quitting and relaunching keeps everything; tests never touch the file.
6. **CO6 – Drops.** The companion drop table, `kindling_by_unit`, `drop_species`, LOOT's `Pickup` carrying a companion or kindling, `Companions.collect()`, the HUD line, the drop sounds.
   **Done means:** seeded tests: elites drop a companion at about 3% and kindling as the table says, slimes kindling at 5%, dummies nothing; a drop pops, lands and is collected on proximity, is in the collection (saved) with a line in its rarity's color, and its species becomes known; counted runs hatch eggs; Ryan's play test in Start run.

**Milestone CO-M – A companion career** (after CO6): from a reset account, Ryan hatches the starter egg (or is granted a copy), takes a companion past bond 5, evolves a copy, rekindles a second copy with picked quirks, rerolls a quirk, and consumes a companion with `test_devour`.
**Done means:** Ryan's play test: where the companion is, when Tab is ready and when it's an imprint all read at a glance; it never gets in the way of movement; the command opens windows for bigger damage; bond and evolution feel worth chasing.

**Then (content, with DUNGEONS.md):** the three launch companions: their species, commands, passives, quirk lists, two evolutions each and models, and which way each is found (Ryan, 2026-10-03: decided with the content).

## Out of scope
The nursery as a place in the hub, the menagerie, the trainer NPC and codex entries (UI.md, NPCS.md, NARRATIVE.md); dyes, skins, mutated variants and monetization (later, look-only); each dungeon's signature list and boss drops (DUNGEONS.md, ENEMIES_AI.md); the secrets' and stories' content (DUNGEONS.md, NARRATIVE.md); more material kinds; nicknames; a 3D preview; achievements (ACHIEVEMENTS.md); the polished screens and art (UI.md, the art pass); the launch companions themselves (content).

## Open questions
Claude's proposals still open (written in above as *(proposed)*; Ryan can overrule any):
1. **Quirk size:** each quirk about 60% of the matching gear affix's range.
2. **The imprint also quiets the quirks**, not only the passives.
3. **Consuming ignores cast range; the enemy wins under the cursor;** a floor ring marks the companion as the target. A champion ability may read `SELF_HAS_STATUS companion` for a bonus, never as a cast condition.
4. **Following numbers:** 40 px behind and 16 px aside, rate 10/s, 1.5 × move speed, a 256 px leash, 0.4 s blocked; drifting through a wall corner for a moment is accepted.
5. **Bond:** kill XP plus 1 per 2 s in combat, the curve 800 → 2400 (bond 5 in about 4.4 runs, bond 10 in about 14), counting in the sandbox; bond passives attach at once mid-run.
6. **Kindling:** the name, the sources (3 per elite, 5% × 1 per regular kill, releases) and the cost table; Artifact copies come only from drops.
7. **Drops and eggs:** 3% per elite kill with LOOT's elite rarity weights; the counted-run stand-in (back to the hub with 20+ kills); eggs hatch in 3.
8. **A starter egg** for a new account.
9. **The choice is per champion,** saved in the companion file.
10. **Evolutions differ in kind, not size** (TALENTS' authoring rule applied to the two evolved passives).
11. **The champion's model plays nothing for a command;** the companion's model plays the command's clip.
12. **A station point stops short of walls and ledges,** so a Zed-style swap never crosses a wall or a cliff. (The other way: let the station point cross them, so the swap is a way over terrain, like a blink.)

Not planned unless Ryan asks: a companion copying the champion's casts, as Zed's shadow copies his abilities. It would reach into the champion's kit (Rules, What a companion is).

Confirmed by Ryan, 2026-10-03 (Claude's readings, written in above):
1. ~~Quirk counts~~: 1 / 2 / 3 / 3 / 4 / 4 / 4 from Common to Artifact (a straight copy of LOOT's counts would make Unique and Exotic copies identical).
2. ~~Quirks are stat lines~~: an `Affix` from its own list, on plain stats or `hit:` / `target:` scopes. Quirks that tune a passive's own numbers come when a species needs one.
3. ~~"Tab can't be modified at the hub"~~: no hub choice targets the command directly; a passive reached by bond, or the evolution's, may power it up.
4. ~~Adaptive~~: compares the final AD and AP, a tie goes to AD, and the damage type follows. (League compares bonus AD with AP and uses a per-champion preference at 0 / 0; a champion field could do the same if a champion ever needs it.)
5. ~~"Imprint"~~: the lore word for the state a consumed companion is in until it returns (replacing "reform").

Applied with the conflict fixes (Ryan, 2026-10-03): the `companion` role tag (the sixth role) with only `ability:<id>` as a command's scope; the fifth AbilityComponent slot; an empty-scope cooldown effect skipping the command; the consume pick as P5's one exception; kindling apart from LOOT's bucket; `Pickup`'s companion and kindling payloads; Tab in MOVEMENT's input map; and the names and words, now in CONVENTIONS.md: `Companions` (autoload), `Companion`, `CompanionData`, `CompanionPassive`, `CompanionEvolution`, `CompanionTable`, `CompanionCollection`, `CompanionRoller`, `CompanionComponent`, `CompanionView`, `CompanionScreen`, `SandboxCompanions`, `status_companion`, `CONSUMES_COMPANION`, `CASTER_ADAPTIVE`, `ability_companion`, the `companion` slot and role tag; **companion**, **species**, **copy**, **quirk**, **command**, **bond**, **evolution**, **dormant** / **awaken** / **hatch**, **rekindle**, **imprint**, **consume**, **release**, **kindling**, **known species**; `data/companions/companion_<name>.tres`, commands `<companion>_tab_<command>.tres` with ids `<companion>_<command>`.

For other docs (nothing proposed yet):
- **DUNGEONS.md** (written 2026-10-03): each dungeon's signature companions (`DungeonData.signature_companions`, proposed there); what a clear is (a wing's boss dies; a clear as the counted run, proposed there); boss drop chances (with the slice); whether the imprint carries across floors (proposed there: yes); checkpoints bring the companion back (decided here); companion crafting parts and clues as collectibles (Getting companions).
- **NARRATIVE.md:** the lore (spirits, dormant, rekindle, imprint), codex entries, secrets and lore puzzles that give companions, and the champion-linked companion in each champion's story.
- **UI.md / NPCS.md:** the polished companion screen, the nursery and menagerie as places, the trainer, a 3D preview of the companion.
- **PROGRESSION.md:** folding `user://companions.cfg` into the one save; companion statistics.
- **ENEMIES_AI.md** (written 2026-10-03; applied there, *proposed*): which enemies drop companions and kindling moves onto `EnemyData` (`kindling_chance` and `kindling_amount`, and `companion_drop_chance`, where −1 keeps this doc's rate for the enemy's rank: elites 3%), replacing `kindling_by_unit` in its AI7. Enemies never see companions: they're never in the enemy brain's snapshot or a target, and the command's slot doesn't count toward the respect enemies give a champion. Sustain quirks still wait: LOOT's rule holds until ENEMIES_AI's milestone settles the Knight's low-health judgment call.
- **Later:** mutated variants from higher difficulties, dyes and skins (look-only), monetization.

Answered in the interview (Ryan, 2026-10-03):
1. ~~How "completely unique" coexists with random traits~~: each species has its own list, with LOOT's rarity rules.
2. ~~What a command may do to enemies~~: anything ("the same level of uniqueness as champions, just no abilities and stats").
3. ~~The command's cooldown~~: 25–50 s; ability haste doesn't shorten it.
4. ~~Where the companion stands~~: a light sim point.
5. ~~What rarity changes~~: quirk count and rolls only; companions never change a champion's abilities or passive.
6. ~~Acquisition at launch~~: drops, crafting, eggs, secrets and story, all of them.
7. ~~Crafting~~: rekindle a known species, choosing rarity and quirks; rerolls cost materials.
8. ~~Command damage~~: adaptive (the higher of AD and AP).
9. ~~Passives~~: stats and reactions; they may power up the companion's own command; about one Exotic item at bond 10.
10. ~~Bond~~: per species, account-wide.
11. ~~Evolution~~: the look and the third passive, per copy.
12. ~~Duplicates~~: each copy is kept; spares can be released for materials.
13. ~~The Knight~~: no consume ability; a sandbox test ability tests the framework.
14. ~~Choosing what to consume~~: the aim (the cursor on the companion).
15. ~~A consumed companion~~: gone until it returns (a timer from the ability, about 45 s); passives quiet, Tab unavailable, no bond lost; checkpoints, new runs and the hub bring it back.
16. ~~Swapping~~: at the hub only.
17. ~~Hub features in this build~~: the companion screen only; eggs hatch on it.
18. ~~Materials~~: their own account-wide bucket.
19. ~~Cosmetics~~: none at launch beyond the evolutions.
20. ~~The three launch companions~~: picked with the content.
21. ~~The word for a rolled line~~: **quirk**.
22. ~~The lore frame~~: kept, with "imprint".
