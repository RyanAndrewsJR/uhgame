# TALENTS.md: Per-Champion Talents, Unlock Requirements, the Champion Level and the Knight's Talent Set

**Read when:** the task involves talents, a talent's unlock requirements, the talent loadout and talent points, the per-champion counters (ability uses, kills), the champion level and champion XP, the hub's talent screen, writing talent content for any champion, or the Knight's talent set.
**Depends on:** CLAUDE.md, VISION.md (Game structure: hub, champion level, fixed slots), CONVENTIONS.md, CHAMPIONS.md (ChampionData, Passive, `champion_level` / `champion_xp`, the Knight's kit, the passive slot), ABILITIES.md (augments, FLAGs, scoped params, reaction rules, GameplayEffects, `Events.ability_cast`), STATS.md (scoped modifiers, StatScaling), COMBAT.md (`Events.unit_died`, kill credit).
**Used by:** UI (the polished hub and talent screen), PROGRESSION (saving, once it exists), ENEMIES_AI (enemy tags for the kill counter, XP per enemy), DUNGEONS (XP for clearing a run, what a "run" is for the pacing numbers), LOOT (items and talents granting the same augment; item REPLACEs and talent FLAGs on one ability), COMPANIONS (bond reads the same kill XP and kill credit; the companion's command fires `ability_cast` too).

## How to read this doc
Same as CHAMPIONS.md: MUST (never change without asking Ryan), TARGET (start value and allowed range), FREE (your call; tiebreaker: VISION.md's decision priorities). Items marked *(proposed)* are Claude's picks that Ryan hasn't answered yet; each one is also in Open questions. A tier marked **⚑** is one where the authoring rule couldn't be fully met (Authoring rule, below); none are open now.

## Player experience
At the hub, the Knight has a page of talents: four each for Cleave, Iron Resolve, Lunge, Judgement and Unbroken. Only five can be active at once. Each tier is a pick of one of two. The first tier tunes an ability your way: cheaper or longer, more often or farther. The second changes what it is: Cleave becomes a spin that hits all around you, or a narrow, heavy cut that reaches far. Most talents start locked, and each lock says what it wants: "Cleave casts 143 / 200", "Champion level 4 / 6". You unlock Cleave's talents by casting Cleave and Lunge's by lunging. After about 29 runs all five points are yours and the build is online, with the whole endgame still ahead. Before a run you set your five, and changing them back at the hub is free. Mid-run they're fixed.

## References
- Diablo 4's skill tree. Take: a skill's upgrades are its own (Cleave's talents only touch Cleave); an "enhanced" step first, then one of two upgrades that change the skill's behavior. Don't take: points spent permanently, gold to refund.
- League of Legends runes. Take: a row is a real choice; swap freely between games at no cost. Don't take: rune pages shared across champions (talent progress is per champion, VISION.md).
- Hades' Mirror of Night and weapon aspects. Take: a pick per row, free to swap at the hub; an aspect changes how a weapon plays, not just its numbers. Don't take: a shared currency.
- Call of Duty weapon challenges / League champion mastery. Take: progress unlocked by *using* the thing, so a talent's lock says what to do to earn it.

## Principles
1. **Talents reshape, never add.** Every talent changes something the champion already has: one ability (Q/W/E/R) or the passive. No talent-granted forms, no multi-slot REPLACE, no keystone that isn't tied to one ability or the passive (decided 2026-09-30).
2. **Groups are islands.** Each of Q, W, E, R and the passive has its own group. A talent's pieces only touch its group's ability (or the passive), and its requirements only read its own group's counter. Groups never reference each other (decided 2026-09-30).
3. **Built from the toolkit, without REPLACE.** A talent is the same bundle a passive is (both extend one base class, `ToolkitBundle`; Ryan, 2026-09-30) (scoped stat modifiers, StatScalings, unit reaction rules, FLAG and EVENT augments) under one source id. Talents never use REPLACE augments: every ability replacement comes from items (Ryan, 2026-09-30). No new Condition kind and no new GameplayEffect kind (decided 2026-09-30). The new pieces are `TalentRequirement` (it reads counters that last a champion's whole lifetime) and one passive hook (a PASSIVE talent can leave out a passive's own bonus, for "instead of" talents; Ryan, 2026-09-30).
4. **Kind, not magnitude.** A pick between options of the same shape and different sizes is a disguised rank, and the game has no ranks (ABILITIES.md, Ability ranks). Options in an exclusive tier must suit different ways of playing (decided 2026-09-30; Authoring rule).
5. **A real choice each time.** A pool bigger than the loadout (about 20 talents, 5 active); siblings in a tier usually exclude each other (decided 2026-09-30). Serves build variety (pillar 2) without stat-checking.
6. **Slow on purpose.** All five talent points take about 29 runs: the build comes online with the whole endgame still ahead (Ryan, 2026-09-30). The numbers are TARGETs calibrated to an *assumed* run until DUNGEONS.md defines one.
7. **Free to change, fixed in a run.** The loadout is edited at the hub only, and respec is free (decided 2026-09-30; no currency exists).

## Current code
- `ChampionData` (`res://scripts/data/champion_data.gd`) has `champion_level` (1) and `champion_xp` (0): plain storage, nothing reads them (CHAMPIONS.md, Champion level).
- `Passive` (`res://scripts/data/passive.gd`): a bundle of `modifiers`, `stat_scalings`, `reaction_rules`, `statuses`, `augments` with `apply_to(unit, source_id)` / `remove_from(unit, source_id)`. The pattern talents reuse. `PassiveSlot` (`res://scripts/ui/passive_slot.gd`) shows the passive's name, description and one "Now:" line per StatScaling.
- `Player._attach_champion()` adds `ChampionData.modifiers` under `champion_<id>` and attaches the passive under `passive_<id>`, after `super._ready()`.
- `Events.ability_cast(unit, ability, ctx)` fires at the effect start (never for a cancelled or interrupted cast; also for free casts, with `ctx.is_free`). `Events.unit_died(unit, ctx)` fires on a kill (`ctx.source` = kill credit).
- FLAGs work as built in AB8: the ability lists the flags it supports (`supported_flags`); an exact-scope flag on an ability that doesn't list it `push_error`s once and is ignored. A REPLACE variant's `variant_of` adds `ability:<base id>` to its scopes, so a Cleave-scoped augment also reaches Cleave Wave.
- The pieces the Knight's set reuses exist: `augment_judgement_reset.tres` (EVENT), `RestoreResourceGameplayEffect`, `status_shield.tres` (100, 3 s), `status_staggered.tres`, `AbilityUtil.in_circle()`. `judgement.gd` reads `stun_duration` through `get_effect_param()`; Lunge's `flag_stun_duration` is the pattern for a FLAG's own number.
- Nothing about talents, counters, XP, saving progress or a hub exists. `user://` is only used by `Settings` (`user://settings.cfg`). The main scene is `res://scenes/main.tscn`.

## Rules
### The model (MUST; decided 2026-09-30, answers VISION.md open question 1)
- Each champion has a **pool** of talents bigger than what can be active: about 15–20 exist, about 5 are active at once (the **loadout**). The Knight: 20 talents, 5 active.
- Talents are **unlocked** permanently by meeting their requirements, and **activated** by putting them in the loadout at the hub. Unlocking is progress; the loadout is a choice.
- The loadout is set at the hub before a run and never changes mid-run (VISION.md, Runs). Respec is free: at the hub the loadout can be cleared and rebuilt any time.

### Groups and tiers (MUST; decided 2026-09-30)
- Five groups per champion: Q, W, E, R and PASSIVE (`Talent.group`). A group's ability is whatever ability the champion's ChampionData has in that slot (the Knight's Q group: `knight_cleave`).
- Inside a group, talents sit in **tiers** (`Talent.tier`, 1, 2...). Talents in the same group and tier are **siblings**.
- **Exclusivity:** an `exclusive` talent (the default) can't be in the loadout with any sibling. A non-exclusive talent (`exclusive` false) can sit beside its siblings; the Knight's set has none, the flag exists for "usually".
- **The tier rule:** a tier N talent (N ≥ 2) can only be in the loadout while a tier N − 1 talent of the same group is in it (Diablo 4's "enhanced first"). So 5 points buy depth (Cleave tier 1 + tier 2) or breadth (five tier 1s).

### Authoring rule: kind, not magnitude (MUST; Ryan, 2026-09-30; governs every champion's talents)
- **Within an exclusive tier, the options differ in kind, not just magnitude.** "+15% heal / +20% heal / +25% heal" is not a choice: never write a tier like that. Each option suits a different way of playing the ability, so the right pick depends on the build or the situation, not on arithmetic.
- **By depth:**
  - The first tier or two of a group may be small, mostly numeric bumps (StatModifier-based). They match the slow early pacing and don't need to be hard choices yet, but siblings still bump *different things* (cost vs reach, not 15 vs 20 Fury).
  - Past that, exclusive tiers lean on talents that change what the ability does, not how big it is (FLAG and EVENT; talents have no REPLACE, so a FLAG that changes the ability's shape plays that part). Prefer options with a real tradeoff over pure upside.
  - A shape change should usually cost the ability's old identity in exchange for a new one, the way Cleave Wave trades the cone and the knockback for a piercing projectile, not add effects on top for free. For a passive, the "instead of" hook does this (What a talent can change).
- **Flag, don't fake.** When a tier has no two genuinely different-shaped options, the doc marks it **⚑** and says why, rather than forcing a fake option in.
- Working rules under it (Claude's, made rules by Ryan 2026-09-30):
  - A tier 1 bump uses a number every tier 2 option of its group still uses (cost, cooldown, `cast_range`, a resource gain, a scaling that isn't replaced), so no lower-tier pick turns dead under a higher one. A tier 1 that a tier 2 option would void is a ⚑.
  - A shape-changing FLAG keeps the *kit's* shared pieces: they sit on the ability's .tres (Cleave's Staggered bonus and heal, Judgement's Fury payoff), so they stay unless the talent says otherwise. The champion stays the same champion.

### What a talent can change (MUST)
A talent is a bundle of toolkit pieces attached under its source id `talent_<talent id>` (`&"talent_knight_long_reach"`), exactly like a passive:
- **Q / W / E / R groups:** every piece is scoped to the group's ability: StatModifiers and StatScaling modifiers with scope `ability:<id>` (cooldown, cost, range, a ratio, a script's export...), FLAG and EVENT augments with scope `ability:<id>`, reaction rules with `required_ability_scope` `ability:<id>` (an EVENT augment's rules get its scope, ABILITIES.md). No unscoped stat modifiers, no `tag:` / `hit:` / `target:` scopes (they'd reach other abilities or the basic attack), no always-on statuses.
- **No REPLACE** (Ryan, 2026-09-30): a talent never carries a REPLACE augment. Replacements are items' (Cleave Wave). So an item's REPLACE always works with any loadout.
- **Talent FLAGs and an item's variant** (Ryan, 2026-09-30): a talent FLAG on an ability also reaches every REPLACE variant of it (through `variant_of`), so **every variant supports every talent FLAG of the ability it replaces**, with its own take on it (Cleave Wave: Whirling = a ring of waves, Rending = one narrow, heavy wave; The Knight's talents, Cleave). A talent's choice never goes dead because of loot. ABILITIES' FLAG rule is unchanged (an unsupported exact-scope flag is still an error); the talents test checks every variant .tres against its base's talent FLAGs, so a new variant without them fails. Tier 1 bumps on cost and range reach the variant too.
- **PASSIVE group:** pieces that extend the passive in its own theme: StatScalings on the passive's input, stat modifiers, unit reaction rules, the statuses those rules apply. No `ability:` or `tag:` scopes and no augments (that would be reaching into Q/W/E/R).
- **Replace and add, modular** (PASSIVE only; Ryan, 2026-09-30): a PASSIVE talent changes its passive in two independent ways, used alone or together:
  - **Add**: its own pieces (StatScalings, modifiers, rules) go on top of the passive's. The default; Bloodrage and Thick Skin only add.
  - **Replace**, by stat: `Talent.replaces_passive_stats` lists stats (`[&"attack_damage"]`). While the talent is in the loadout, the champion's passive attaches *without* its own modifiers and StatScalings on those stats. Each listed stat must be one the passive actually has (validation).
  - Both at once: Battle Trance replaces Unbroken's attack damage and adds its own attack speed. A talent may also replace a stat and add its own piece on that same stat (a different curve or value for the passive's AD).
  - Only the passive's own pieces are ever left out: another talent's piece on that stat (Bloodrage) still applies. The passive slot shows what's replaced and what's added.
- **The tooltip says what the ability does now** (T3b, Ryan 2026-09-30; clarity, VISION.md priority 2): a Q / W / E / R talent that changes what its ability does (a shape FLAG, a trade such as "no stun") carries `ability_description`, a full replacement for the ability's tooltip template with the same `{placeholders}`, used while the talent is on. The talent's own augment lines are then left out (the new text already says it). Number-only talents keep the ability's text (its numbers update by themselves). The replacement is for the slot's own ability only: an item's REPLACE variant keeps its own text, and the talent's augment line explains the change there. The Knight's seven: Whirling and Rending Cleave, Challenge, Bulwark, Tackle, Executioner, Shockwave.
- **Enforced:** `Talent.get_validation_errors(champion)` checks every rule above; the talents test runs it over every talent .tres, and attaching a talent that fails it `push_error`s and skips it.
- The champion's resource rhythm (Fury generation and decay), the basic attack combo and the dash have no group: no talent touches them, except as part of its own ability's behavior ("Iron Resolve restores 15 Fury" is Iron Resolve's).

### Unlocking: requirements (MUST; decided 2026-09-30; numbers TARGET)
- A talent has a list of `TalentRequirement`s; all must be met (AND; an empty list = unlocked from the start).
- One resource with a `kind` and an `amount`:
  - `CHAMPION_LEVEL`: the champion level is at least `amount`.
  - `ABILITY_USES`: the group's own ability has been used at least `amount` times. There is no ability field: it always means the talent's group's ability, so a requirement can't point at another group. Invalid in the PASSIVE group.
  - `KILLS`: the champion has at least `amount` kills; with `enemy_tag` set, only kills of enemies carrying that tag. The by-tag counter is built now; the Knight's set doesn't use the tag (no enemy tags exist until ENEMIES_AI.md).
- Not a Condition: `Condition` checks unit state in a fight; a requirement reads lifetime counters from the champion's progress record. They never mix (decided 2026-09-30).
- **Unlocks are kept:** once all its requirements are met, a talent is recorded as unlocked and stays unlocked, even if a later retune raises a requirement (the same reason the champion level is stored as level + XP-into-level, CHAMPIONS.md).
- Checked whenever a counter, the level or the data changes (at load, after each counted cast or kill, at the hub). A talent unlocked mid-run can only be put in the loadout back at the hub.

### The loadout and talent points (MUST shape; numbers TARGET)
- **Talent points** = how many talents can be active. Each talent costs 1 point (Ryan, 2026-09-30). The champion level sets the points (VISION.md: the champion level only gates talent points): 1 at level 1, 5 at level 12 (the table below).
- A talent can be put in the loadout when: it's unlocked, a point is free, no exclusive sibling is in the loadout (the hub swaps them: picking one takes the sibling out), and the tier rule holds.
- Taking a tier 1 talent out of the loadout also takes out its group's tier 2 talent when no other tier 1 of that group is left.
- **Respec** is free: the hub's "Clear" empties the loadout; any talent can be taken out any time at the hub.

### Counters (MUST)
Per champion, kept for its whole lifetime, never shared:
- **Ability uses**, per ability id: +1 on `Events.ability_cast` when the unit is the player's champion, the cast is not free (`ctx.is_free` false; a free Lunge from an item isn't a Lunge you cast), and it's the first part (`ctx.part` 0: a three-part recast is one use) (Ryan, 2026-09-30). A REPLACE variant counts for the ability it replaces (`variant_of`): a Cleave Wave is a Cleave cast. Cancelled and interrupted casts never fire `ability_cast`, so they never count. A companion's command (COMPANIONS.md) is counted under its own id too; no talent group reads it, so it unlocks nothing.
- **Kills**: +1 on `Events.unit_died` when `ctx.source` is the player's champion and the dead unit is an enemy (a different team). Procs, reaction damage and DoTs the champion applied count (their source is the champion); a kill with no source (a hazard, a projectile whose caster was freed) doesn't. **Kills by tag**: +1 for each of the dead enemy's kill tags. The counter and its save are built now; where an enemy's tags live waits for ENEMIES_AI.md (Ryan, 2026-09-30), so until then `Progress.get_kill_tags(unit)` returns none and only the total counts.
- Counters only go up. Dying keeps them (VISION.md, Death). They count wherever the champion plays, the sandbox included.

### Champion level and XP (TARGET; the pace decided 2026-09-30)
- **The goal:** all five talent points at about 29 runs, so the build is online while the whole endgame is still ahead (Ryan, 2026-09-30).
- XP comes from kills, under the same kill credit as the kill counter. Where an enemy's XP lives waits for ENEMIES_AI.md (Ryan, 2026-09-30); until then a small table in the leveling .tres gives it (Data, ChampionLeveling: `xp_by_unit`). Later: a bonus for clearing a dungeon (DUNGEONS.md). Nothing else gives XP for now. Companion bond (COMPANIONS.md) reads the same per-kill XP (`ChampionLeveling.get_kill_xp()`), so ENEMIES_AI's replacement for `xp_by_unit` serves both.
- Level-up: while `champion_xp` ≥ the XP to the next level, subtract it and add a level (several at once if needed). At the max level, XP keeps adding up in `champion_xp` (so raising the max later grants the levels at once) and grants nothing.
- The level is never lost and never touches combat stats (VISION.md). It's not `StatsComponent.set_level()`.
- **The assumed run** (to be measured once DUNGEONS.md defines runs): about 20 minutes, about 100 kills (96 regular, 4 elites), about 1000 XP. The Knight casts about 120 Cleaves, 50 Iron Resolves, 60 Lunges and 12 Judgements in it.
- **The curve** (placeholder, as drafted; Ryan 2026-09-30): XP to the next level = 600 + 400 × (level − 1); max level 12.

| Level | XP to next | Total XP | Runs (≈1000 XP) | Talent points |
|---|---|---|---|---|
| 1 | 600 | 0 | 0 | 1 |
| 2 | 1000 | 600 | 0.6 | 1 |
| 3 | 1400 | 1600 | 1.6 | 2 |
| 4 | 1800 | 3000 | 3 | 2 |
| 5 | 2200 | 4800 | 5 | 2 |
| 6 | 2600 | 7000 | 7 | 3 |
| 7 | 3000 | 9600 | 10 | 3 |
| 8 | 3400 | 12600 | 13 | 3 |
| 9 | 3800 | 16000 | 16 | 4 |
| 10 | 4200 | 19800 | 20 | 4 |
| 11 | 4600 | 24000 | 24 | 4 |
| 12 (max) | — | 28600 | 29 | 5 |

- XP per kill (TARGET): regular enemy 5 (3–8), elite 40 (25–60), boss 200 (later). The sandbox's slimes: 5, the elite: 40. A passive enemy (the sandbox's training dummies) gives no kill and no XP (T4, as built).
- Unlock requirements are paced against the same run: tier 1 in about 1–2 runs (champion level 2 plus about 1.5 runs of using that ability), tier 2 in about 15 (level 6 plus about 15 runs of use). A player who never uses Iron Resolve never unlocks its tier 2: that's intended.

### Saving (Ryan, 2026-09-30; until PROGRESSION.md)
- Progress has to outlive the game session, or "dozens of runs" can't happen. Until PROGRESSION.md exists, TALENTS saves its own record: `user://progress.cfg` (a `ConfigFile`, like `Settings`; never a .tres, which can carry scripts), one section per champion id: level, XP, ability uses, kills, kills by tag, unlocked ids, loadout ids.
- Saved when a level is gained, when a talent unlocks, when the loadout changes, when the tracked player leaves the tree (a scene change, a restart, Back to hub in T5) and when the window closes. As built (T4): a scene under `res://scenes/tests/` never reads or writes the save: `Progress` turns `saving_enabled` off by itself before its first record, so every test starts from fresh in-memory records and a test can never touch real progress, with no change to the older suites.
- `ChampionData.champion_level` / `champion_xp` (CHAMPIONS.md) become a new record's starting values (1 / 0); the live values live in the record. This changes CHAMPIONS.md ("the fields hold the value while the game runs"), which points here.

## The Knight's talents (approved by Ryan 2026-09-30; numbers TARGET)
Twenty talents, two tiers of two per group, every one exclusive with its sibling. **Tier 1** bumps something every tier 2 option still uses; its two options bump different things. **Tier 2** changes what the ability does, each option trading something away. Siblings share their requirements: tier 1 = champion level 2 + about 1.5 runs of use, tier 2 = champion level 6 + about 15 runs of use.

### Q: Cleave (`knight_cleave`)
| Tier | Talent (id) | Plays as | What it does | Built from | Unlock |
|---|---|---|---|---|---|
| 1 | Thrifty Edge (`knight_thrifty_edge`) | Cleave often | Costs 15 Fury (was 20) | `resource_cost` FLAT −5 | level 2, Cleave casts 200 |
| 1 | Long Reach (`knight_long_reach`) | Cleave from the edge | Reach +25% (96 → 120 px; carries into either tier 2) | `cast_range` PERCENT_ADD +0.25 | level 2, Cleave casts 200 |
| 2 | Whirling Cleave (`knight_whirling_cleave`) | Surrounded brawler | A spin all around the Knight instead of an aimed arc: radius 75% of the reach (72 px; 90 with Long Reach), 85% damage, **no knockback** (enemies stay in reach). Loses the aim, the reach and the push; gains every side at once | FLAG `cleave_whirl` in `cleave.gd` (the shape: `in_circle()` around the caster, radius = the reach; the indicator draws the circle) + the talent's scoped modifiers (the numbers): `cast_range`, `base_damage`, `ad_ratio` PERCENT_MULT −0.25 / −0.15 / −0.15, `hit_knockback_px` PERCENT_MULT −1, and for the wave `projectile_count` FLAT +7, `projectile_spread_deg` FLAT +30 | level 6, Cleave casts 1800 |
| 2 | Rending Cleave (`knight_rending_cleave`) | Elite duelist | A narrow, long cut: half-angle 25° (was 60°), reach ×1.4 (96 → 134 px), +35% damage. Loses the wide sweep; gains reach and weight on one target | FLAG `cleave_rend` in `cleave.gd` (the shape: `flag_rend_half_angle_deg` 25; the indicator draws the narrow cone) + the talent's scoped modifiers: `cast_range`, `base_damage`, `ad_ratio` PERCENT_MULT +0.4 / +0.35 / +0.35, and for the wave `projectile_width` PERCENT_MULT −0.6 | level 6, Cleave casts 1800 |

As built (T3): each Cleave FLAG changes only the shape; its numbers are the talent's own scoped modifiers, so the tooltip, the indicator and `get_param()` show the real reach and damage (ABILITIES principle 2), and they reach Cleave Wave through `variant_of`. Both tier 2s keep the Staggered bonus and the heal (they're on Cleave's .tres). **With an item's Cleave Wave** in the slot, each has the wave's own take (Ryan, 2026-09-30); `cleave_wave.gd` lists both flags in `supported_flags` and needs no code for them, since `Projectile.fire()` reads every number:
- **Whirling Wave**: 8 waves fired evenly all around the Knight (45° apart) instead of one forward, each at 75% of the range (700 → 525 u, 224 → 168 px; the plan said 60%: one range modifier serves both shapes), 85% damage. The same trade: the aim for every side.
- **Rending Wave**: one narrow, long, heavy wave: width 150 → 60 u (48 → 19 px), range ×1.4 (700 → 980 u, 224 → 314 px), +35% damage. The same trade: the sweep for reach and weight.
- Thrifty Edge and Long Reach apply to the wave as to Cleave (cost, `cast_range`). The waves keep the wave's Staggered bonus and heal (on its .tres since AB-M / CH5b).

### W: Iron Resolve (`knight_iron_resolve`)
| Tier | Talent (id) | Plays as | What it does | Built from | Unlock |
|---|---|---|---|---|---|
| 1 | Quick Recovery (`knight_quick_recovery`) | Resolve often | Cooldown 6.5 s (was 8) | `cooldown` FLAT −1.5 | level 2, Iron Resolve casts 75 |
| 1 | Battle Cry (`knight_battle_cry`) | Resolve fuels Cleave | Restores 15 Fury on cast | EVENT augment: an ABILITY_CAST rule, effect target OTHER (the caster) → `RestoreResourceGameplayEffect` 15 | level 2, Iron Resolve casts 75 |
| 2 | Challenge (`knight_challenge`) | Set up the combo (offense) | Staggers every enemy within 96 px (in sight) for the usual 2 s **instead of the haste**, so the next Cleave hits them for +50%. Loses the speed to reposition; gains a Lunge-free setup for Cleave | FLAG `iron_resolve_challenge` in `iron_resolve.gd` (`flag_challenge_radius` 300 u; `in_circle()` + `in_sight()`, `status_staggered` applied from the Knight; the haste is skipped) | level 6, Iron Resolve casts 750 |
| 2 | Bulwark (`knight_bulwark`) | Absorb burst (defense) | A 120 shield for 3 s **instead of the empowered swing** (and so no slow); the haste stays | FLAG `iron_resolve_bulwark` in `iron_resolve.gd` (`flag_shield_amount` 120, a `status_shield` copy) | level 6, Iron Resolve casts 750 |

The tier 2 pair is offense vs defense (Ryan, 2026-09-30, replacing the earlier unstoppable pick, which made both options defensive).

### E: Lunge (`knight_lunge`)
| Tier | Talent (id) | Plays as | What it does | Built from | Unlock |
|---|---|---|---|---|---|
| 1 | Long Lunge (`knight_long_lunge`) | Engage from farther | Reach +25% | `cast_range` PERCENT_ADD +0.25 | level 2, Lunge casts 90 |
| 1 | Quick Footing (`knight_quick_footing`) | Lunge more often | Cooldown 6 s (was 8) | `cooldown` FLAT −2 | level 2, Lunge casts 90 |
| 2 | Tackle (`knight_tackle`) | Lock one target | The dash **stops at the first enemy** in its path, hits only it, and stuns it 0.75 s (still Staggered). Loses the cut through a pack; gains a sure single-target lock | FLAG `lunge_tackle` in `lunge.gd` (`flag_tackle_stun_duration` 0.75) | level 6, Lunge casts 900 |
| 2 | Twin Lunge (`knight_twin_lunge`) | Hop and reposition | 2 charges, **each 35% shorter**. Loses one long engage; gains two short hops (two packs Staggered, or in and out) | `max_charges` FLAT +1, `cast_range` PERCENT_MULT −0.35 | level 6, Lunge casts 900 |

### R: Judgement (`knight_judgement`)
| Tier | Talent (id) | Plays as | What it does | Built from | Unlock |
|---|---|---|---|---|---|
| 1 | Swift Verdict (`knight_swift_verdict`) | Judge more often | Cooldown 24 s (was 30) | `cooldown` FLAT −6 | level 2, Judgement casts 20 |
| 1 | Long Arm (`knight_long_arm`) | Judge from safety | Range +30% | `cast_range` PERCENT_ADD +0.3 | level 2, Judgement casts 20 |
| 2 | Executioner (`knight_executioner`) | Finish elites | 40% of the target's missing health (was 20%), and a kill resets the cooldown, but **no stun** (0.5 s with the Fury bonus, which adds its +0.5 s on top) | `target_missing_health_ratio` FLAT +0.2, `stun_duration` PERCENT_MULT −1 (`judgement.gd` skips a 0 s stun), the existing `augment_judgement_reset.tres` (EVENT) | level 6, Judgement casts 180 |
| 2 | Shockwave (`knight_shockwave`) | Control packs | Judgement also hits every enemy within 80 px of its target (in sight from it) for 50% damage and stuns them 0.5 s, but **no missing-health damage** on anyone. Loses the execute; gains crowd control | FLAG `judgement_shockwave` in `judgement.gd` (`flag_shockwave_radius` 250 u, `flag_shockwave_damage_ratio` 0.5, `flag_shockwave_stun_duration` 0.5; the splash through `hit_units()` with its `damage_ratio` and the target hit's crit roll) + `target_missing_health_ratio` PERCENT_MULT −1; the Fury payoff reaches every hit (the splash's stun gets the bonus's +0.5 s too), and the Fury is consumed once | level 6, Judgement casts 180 |

### Passive: Unbroken (`passive_knight`)
| Tier | Talent (id) | Plays as | What it does | Built from | Unlock |
|---|---|---|---|---|---|
| 1 | Bloodrage (`knight_bloodrage`) | Hit harder when low | Up to +15% more attack damage on top of Unbroken (+55% in all) | StatScaling `attack_damage` PERCENT_ADD 0.15, input `self_missing_health`, `curve_knight_unbroken.tres` | level 2, kills 150 |
| 1 | Thick Skin (`knight_thick_skin`) | Last longer when low | Unbroken also gives up to +30 armor | StatScaling `armor` FLAT 30, same input and curve | level 2, kills 150 |
| 2 | Battle Trance (`knight_battle_trance`) | Swing faster when low | Unbroken gives up to +50% attack speed **instead of** its +40% attack damage: faster swings, more Fury, lighter hits | `replaces_passive_stats` [`attack_damage`] + StatScaling `attack_speed` PERCENT_ADD 0.5, same input and curve | level 6, kills 1500 |
| 2 | Stalwart (`knight_stalwart`) | Hold on when low | Unbroken gives up to +60 armor and +30% tenacity **instead of** its +40% attack damage | `replaces_passive_stats` [`attack_damage`] + StatScalings `armor` FLAT 60 and `tenacity` FLAT 0.3, same input and curve | level 6, kills 1500 |

Bloodrage carries into both tier 2s: they leave out Unbroken's own +40%, not Bloodrage's +15% (so Battle Trance with Bloodrage is +50% attack speed and +15% AD at the brink). Thick Skin's armor stacks with Stalwart's (+90 at the brink).

### Notes on the set
- **Every tier 1 carries:** cost, cooldown, `cast_range`, a Fury gain and the tier 1 scalings all still apply under either tier 2 of their group (Long Reach widens Whirling Cleave and lengthens Rending Cleave; Long Lunge lengthens Twin Lunge's hops; Long Arm and Swift Verdict work with both Judgement picks).
- **Items:** talents have no REPLACE, so an item's REPLACE (Cleave Wave) always works with any loadout, and the Cleave tier 2 FLAGs have their own wave versions on it (Rules, Talent FLAGs and an item's variant). Item FLAGs still work with talents (`lunge_stuns` with Tackle: two stuns, the longer one wins, as always).
- **The low-health judgment call** (CLAUDE.md, Current status): every Unbroken talent changes the Knight's low-health rewards (Bloodrage, Thick Skin and Stalwart deepen them; Battle Trance reshapes them). Their numbers stay placeholders until ENEMIES_AI.md's enemies can stress them. No talent touches Cleave's heal, for the same reason.
- **Ideas not used** (for later champions or items): a CHARGE_UP heavy Cleave and an area-at-a-point Judgement (both need a REPLACE, so they'd be items now); Stand Firm (Iron Resolve: unstoppable instead of the haste); Defiance (unstoppable when a hit drops the Knight below 30%) and Momentum (a speed burst on low-health kills).
- **New content the set needs:** 20 talent .tres (and their 6 FLAG augment .tres in `data/augments/`); 6 FLAGs in the scripts: `cleave_whirl` and `cleave_rend` (`cleave.gd`; listed by `cleave_wave.gd`, whose take is data), `iron_resolve_challenge` and `iron_resolve_bulwark` (`iron_resolve.gd`), `lunge_tackle` (`lunge.gd`), `judgement_shockwave` (`judgement.gd`); a 0 s stun skipped in `judgement.gd`; `Ability.hit_units()`'s optional `damage_ratio` and `crit_roll` (Ryan, 2026-09-30: the splash stays toolkit-only, AB11). No new statuses.

## Data (Resources)
Names checked against CONVENTIONS.md (reserved names, vocabulary).

### ToolkitBundle (Resource, `res://scripts/data/toolkit_bundle.gd`) (the shared base and its name approved by Ryan 2026-09-30)
The bundle of toolkit pieces attached under one source id, pulled out of `Passive` so `Passive` and `Talent` both extend it (Ryan's pick over `Talent extends Passive`: a talent isn't a passive). Its approval covers the change policy for this refactor of `passive.gd`: the code moves, behavior doesn't.
- Fields (moved from `Passive`, same names and defaults): `display_name`, `description`, `icon_color`, `modifiers`, `stat_scalings`, `reaction_rules`, `statuses`, `augments`.
- Methods (moved): `apply_to(unit, source_id, left_out_stats: Array[StringName] = [])`, `remove_from(unit, source_id)`, virtual `_on_added()` / `_on_removed()`. New: `left_out_stats` (the default changes nothing): modifiers and StatScalings whose stat is listed aren't added (the replace half of Replace and add).
- `Passive` becomes `class_name Passive extends ToolkitBundle` with nothing of its own for now. Its property names don't change, so `knight.tres`'s inline Unbroken and every test load as before; the champions test's passive checks must pass unchanged.

### Talent (Resource, `res://scripts/data/talent.gd`; files `res://data/talents/talent_<champion>_<name>.tres`)
`Talent extends ToolkitBundle`: the same bundle, attach code and "Now:" tooltip lines as a passive. Added fields:
| Field | Type | Default | Notes |
|---|---|---|---|
| `id` | `StringName` | `&""` | `<champion>_<name>` (`&"knight_long_reach"`). Source id: `talent_<id>` (`get_source_id()`) |
| `group` | `Talent.Group` | `Q` | `Q`, `W`, `E`, `R`, `PASSIVE` |
| `tier` | `int` | 1 | 1, 2, ... |
| `exclusive` | `bool` | true | excludes its siblings (same group and tier) from the loadout |
| `requirements` | `Array[TalentRequirement]` | `[]` | all must be met to unlock; empty = unlocked from the start |
| `replaces_passive_stats` | `Array[StringName]` | `[]` | PASSIVE only: the passive attaches without its own modifiers and StatScalings on these stats while this talent is active (replace); the talent's own pieces always attach (add). Empty = add only |
| `ability_description` | `String` (multiline) | `""` | Q / W / E / R only (T3b): replaces the group ability's tooltip template while the talent is on; its own augment lines are then left out. Empty = the ability's own text |
Methods: `get_source_id()`, `get_group_ability(champion) -> Ability` (null for PASSIVE), `get_validation_errors(champion) -> PackedStringArray` (Rules, What a talent can change).

### TalentRequirement (Resource, `res://scripts/data/talent_requirement.gd`; inline in the talent)
| Field | Type | Default | Notes |
|---|---|---|---|
| `kind` | `TalentRequirement.Kind` | `CHAMPION_LEVEL` | `CHAMPION_LEVEL`, `ABILITY_USES`, `KILLS` |
| `amount` | `int` | 1 | the level, uses or kills needed |
| `enemy_tag` | `StringName` | `&""` | `KILLS` only: count only enemies with this kill tag (empty = every kill) |
Methods: `get_validation_error(talent)` (T1), `get_current(progress, talent, champion) -> int` (the counter it reads; T4, with the record), `is_met(...)` (T4), `get_label(talent, champion) -> String` ("Cleave casts", "Champion level", "Kills").

### ChampionLeveling (Resource, `res://scripts/data/champion_leveling.gd`; `res://data/champion_levelings/champion_leveling_default.tres`) (name approved 2026-09-30)
| Field | Type | Notes |
|---|---|---|
| `xp_to_next` | `Array[int]` | index 0 = level 1 → 2: `[600, 1000, 1400, 1800, 2200, 2600, 3000, 3400, 3800, 4200, 4600]`. Its size + 1 = the max level (12) |
| `talent_points` | `Array[int]` | index 0 = level 1: `[1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5]` |
| `xp_by_unit` | `Dictionary` (StringName → int) | **Temporary, until ENEMIES_AI.md** decides where enemy data lives (Ryan, 2026-09-30): XP per kill, keyed by the dead unit's UnitStats file name without the extension: `{&"slime": 5, &"slime_elite": 40}`. A unit not in it gives 0 (dummies, the Knight). In a .tres rather than in code, so tuning never needs a code edit (CLAUDE.md, Conventions) |
Methods: `get_max_level()`, `get_xp_to_next(level)` (0 at max), `get_talent_points(level)`, `get_kill_xp(unit) -> int`.

### ChampionData additions
| Field | Type | Knight | Notes |
|---|---|---|---|
| `talents` | `Array[Talent]` | the 20 talent .tres | export group "Talents" |
| `leveling` | `ChampionLeveling` | null | null = `champion_leveling_default.tres` |
`champion_level` / `champion_xp` stay, as a new record's starting values (Saving).

### Enemy XP and kill tags (wait for ENEMIES_AI.md; Ryan, 2026-09-30)
- No new field on UnitStats or Enemy now. XP comes from `ChampionLeveling.xp_by_unit` (temporary); kill tags from `Progress.get_kill_tags(unit)`, which returns none. ENEMIES_AI.md decides where both live and replaces these two stand-ins.

### ChampionProgress (RefCounted, `res://scripts/talents/champion_progress.gd`) (name approved 2026-09-30)
The live record of one champion: `champion_id`, `level`, `xp`, `ability_uses: Dictionary` (ability id → int), `kills: int`, `kills_by_tag: Dictionary` (tag → int), `unlocked: Array[StringName]`, `loadout: Array[StringName]`.
Methods: `add_xp(amount, leveling) -> int` (levels gained), `get_talent_points(leveling)`, `get_points_used()`, `is_unlocked(id)`, `refresh_unlocks(champion) -> Array[StringName]` (newly unlocked), `get_loadout_fail_reason(talent, champion) -> String` (`""` = can add; `"locked"`, `"no points"`, `"needs tier <n>"`), `add_to_loadout(talent, champion) -> bool` (takes an exclusive sibling out first), `remove_from_loadout(id, champion)` (and a higher tier that loses its last lower tier), `clear_loadout()`, `to_dict()` / `from_dict()`.

## Architecture / contracts
### Progress (autoload, `res://scripts/autoload/progress.gd`) (name approved 2026-09-30)
- Holds a `ChampionProgress` per champion id, loaded from `user://progress.cfg` at start. `get_progress(champion: ChampionData) -> ChampionProgress` creates a fresh one from the ChampionData's starting values when none is saved.
- `track(player, champion)`: the Player calls it in `_attach_champion()`; `untrack()` when it leaves the tree. Only the tracked unit's casts and kills count; enemies never do.
- Listens to `Events.ability_cast` (uses) and `Events.unit_died` (kills, kills by tag, XP), per the Counters rules; then `refresh_unlocks()`. Signals (its own, not on Events): `champion_leveled_up(champion_id, level)`, `talent_unlocked(champion_id, talent_id)`.
- `save()`, `saving_enabled` (tests turn it off), `reset(champion)` (debug).
- Registered before `Audio` (which stays last).
- As built (T4, 2026-09-30): the save is read lazily, at the first `get_progress()`, so `is_test_scene()` (the current scene under `res://scenes/tests/`) can turn saving off first. A record is made on first use (saved, else fresh from ChampionData), then `refresh_unlocks()` and `sanitize_loadout()` run once (one warning per change). Also: `get_champion(id)` (the ChampionData last seen), `get_tracked_player()`, `add_xp(champion, amount)` (levels, one `champion_leveled_up` per level, unlocks, a save on a level), `add_to_loadout()` / `remove_from_loadout()` / `clear_loadout()` (the record's rules, then a save: T5's hub calls them). The Player's `talent_loadout` export, when not empty, replaces the record's loadout for that Player only (tests; never saved).
- The HUD (`hud.gd`): `show_progress_line(text)` (a small gold line under the top bar for 2 s; a second line while one shows goes underneath), fed by `champion_leveled_up` ("Knight reached level 3: +1 talent point"; no point part when the level adds none) and `talent_unlocked` ("Talent unlocked: Long Reach"). `get_progress_line()` for tests.

### Attaching the loadout
- `Player._attach_champion()`: first the loadout's talents are looked up (each id → the matching `Talent` in `ChampionData.talents`; an unknown id is dropped from the loadout with a warning; validation errors → `push_error` and skip). The passive then attaches with the union of their `replaces_passive_stats` as `left_out_stats`. Then each talent, in loadout order: `talent.apply_to(self, talent.get_source_id())`.
- Talents attach once, at load. Taking one out (`remove_from()`) restores the unit exactly, by source id (tests and the sandbox toggle); a PASSIVE talent with `replaces_passive_stats` also re-attaches the passive without the left-out list (remove the passive by its source id, attach it again).
- As built (T1, 2026-09-30): the loadout comes from `Player.talent_loadout` (an `Array[StringName]` export, empty in `player.tscn`) until T4 reads it from the record. The Player keeps the attached talents (`get_active_talents()`, `get_left_out_passive_stats()`) and offers `add_talent(talent)` / `remove_talent(talent)` for the sandbox and tests: they ignore locks, points and the tier rule, refuse a talent that fails validation or is already on, and re-attach the passive when the talent replaces passive stats. Validation runs on every attach (`_is_attachable()`, `push_error` with the reasons).
- Ability tooltips already show augment lines and the modified numbers, the variant's included; nothing new there.
- **The passive slot** (CHAMPIONS CH6's `PassiveSlot`): it shows "Now:" lines for the passive's attached scalings only (a replaced one shows no line), then per PASSIVE talent in the loadout: "<name> (talent)", one "Replaces Unbroken's attack damage" line per replaced stat, and its "Now:" lines (what it adds). "Now:" lines are gold, the talent lines pale blue. So the slot never shows a bonus the Knight doesn't have.
- Cleave's indicator follows its flags: `cleave.gd`'s `draw_indicator()` reads the caster's active flags (`AbilityComponent.get_flags()`) and draws the circle or the narrow cone (what you see is what you get, ABILITIES principle 2).

### The hub (functional; decided 2026-09-30: everything visible, live counters)
Bare and functional, in CH6's spirit: placeholder text and squares, no art.
- `res://scenes/ui/hub.tscn` + `res://scripts/ui/hub.gd`: the champion's name, level and XP ("Level 4: 1200 / 1800 XP"), points ("Talents 2 / 2"), then the talent screen, then buttons: **Start run** (`main.tscn`; since the 3D pivot's P-M `main_layout.tscn`, room_01 built in 3D), **Sandbox** (`sandbox_main.tscn`), **Clear** (respec).
- The talent screen (`res://scripts/ui/talent_screen.gd`, `TalentScreen`): five columns (Q, W, E, R, Passive, each headed by the ability's or the passive's name), each listing its tiers top to bottom, siblings side by side. Every talent is shown, locked or not. Each one: name, description, and its state:
  - **Active** (highlighted): in the loadout.
  - **Available**: unlocked, can be added (click).
  - **Locked** (greyed): one line per requirement with its live count ("Cleave casts 1312 / 1800"); lines already met get a tick ("✓ Champion level 6 / 6").
  - **Blocked**: unlocked but the tier rule or the points stop it, with the reason as a line ("Needs a tier 1 Cleave talent", "No talent points left").
  Clicking toggles a talent in or out (`add_to_loadout()` / `remove_from_loadout()`), swapping an exclusive sibling.
- `debug_tools` export (on in the hub scene for now): buttons +1 level, +100 uses for each ability, +100 kills, unlock all, reset this champion. So play tests don't need dozens of runs.
- The pause menu gets **Back to hub** (saves, then changes scene). The hub becomes the main scene (F5) (Ryan, 2026-09-30); `sandbox_main.tscn` (F6) still works on its own and uses the saved loadout.
- A level-up mid-run shows a short HUD line ("Knight reached level 3: +1 talent point", 2 s); a talent unlocked mid-run shows "Talent unlocked: Long Reach". No sound until AUDIO.md adds hooks.
- As built (T5, 2026-09-30), changed from the plan to fit 640×360 (checked in a rendered frame): siblings are **stacked** under a "Tier 1 — pick one" label, not side by side (a 124 px column can't hold two readable boxes); a talent's **description shows in a detail line under the grid on hover**, not inside its box (twenty descriptions don't fit). Each box: the name with its tag ([ON] gold, plain white, [LOCKED] grey with one line per requirement, [BLOCKED] rust with the reason). A met requirement reads "Champion level 2 / 2 — met": the default font (Open Sans) has no ✓. Buttons: **Start run** (`main.tscn`), **Sandbox** (`sandbox_main.tscn`), **Clear talents**; the debug row (`Hub.debug_tools`, on in `hub.tscn`) calls `Progress.debug_add_ability_uses()` / `debug_add_kills()` / `debug_unlock_all()` / `reset()` and `Hub.debug_add_level()` (exactly the XP to the next level). `TalentScreen.get_state()` / `get_lines()` / `press()` and `Hub.get_header_text()` are what the tests read. The champion is a `Hub.champion` export (the Knight); champion select stays UI.md's.

### The sandbox
- `SandboxTalents` node in `sandbox.tscn` (`res://scripts/rooms/sandbox_talents.gd`), like `SandboxAugments`: lists the champion's talents and toggles them on the live Knight with keys (test only; it ignores locks, points and the tier rule, and never changes the saved loadout). So the Knight's set can be play-tested before the hub exists. As built (T1): a list at the bottom left ("> Q1  Long Reach  ON"); **G** moves the cursor down (Shift+G up), **T** toggles the highlighted talent (raw keys in this sandbox-only script, like SandboxAugments' 1–4; G and T are unbound elsewhere). It reads `champion.talents`, so it shows "none" until T2 fills the Knight's.

## Audio hooks
None built. For later (AUDIO.md adds them when wanted): level up, talent unlocked, a hub click when a talent goes in or out. The shape-changing FLAGs (Whirling and Rending Cleave, Challenge, Shockwave) may want their own cast or hit sounds; until then they use the ability's own.

## How each edge case is handled
| Edge case | Handling |
|---|---|
| An item's REPLACE (Cleave Wave) with Cleave talents | The wave always takes the slot (talents have no REPLACE). Thrifty Edge and Long Reach reach it through `variant_of`; Whirling and Rending Cleave become Whirling Wave and Rending Wave (`cleave_wave.gd` supports both flags). Wave casts count as Cleave casts. |
| A future variant of an ability with talent FLAGs | It must support every talent FLAG of the ability it replaces, with its own take; the talents test fails on a variant .tres that doesn't. |
| A talent and an item grant the same augment | It counts once (the same id from several sources is one augment); removing either source keeps it while the other has it. |
| A free cast (`cleave_casts_lunge`) | Not a use (`ctx.is_free`). It still gets Lunge's talents (scoped to the ability), Tackle and Twin Lunge's shorter range included. |
| A recast ability (later champions) | One use per sequence (part 0). |
| A cast cancelled or interrupted | Never fires `ability_cast`: not a use. |
| Executioner with the Fury bonus | Its stun is 0 × the scoped value, then the bonus adds +0.5 s on top (conditional bonuses apply after scoped modifiers): a 0.5 s stun at 60+ Fury. Written in its tooltip. |
| Shockwave and the Fury payoff | Every hit (the target and the splash) gets the bonus, checked per hit; the Fury is consumed once, after the target's hit lands (`judgement.gd`'s existing rule). |
| Challenge on an untargetable enemy | Refused (statuses from other units, AB10), as Lunge's Staggered is. |
| Tackle hits nothing | The dash runs its full length, as Lunge does; nothing is stunned. |
| Battle Trance or Stalwart with Bloodrage | Only Unbroken's own `attack_damage` scaling is left out; Bloodrage's stays (+15%). The passive slot shows both. |
| A PASSIVE talent lists a stat the passive doesn't have | Validation error; skipped at attach. |
| Dying, checkpoint respawn | Counters, XP and unlocks are kept (VISION.md, Death). |
| Several levels from one big XP gain | `add_xp()` loops; one level-up line per level. |
| XP at the max level | Adds up in `champion_xp`, grants nothing. |
| A retune raises a requirement | Unlocked talents stay unlocked (stored). |
| A retune lowers the points | The level is never lost; a saved loadout over the points is trimmed from the end at load, with a warning. |
| A saved loadout with two siblings, or a tier 2 without its tier 1 (the data changed) | Fixed at load in order: the first sibling stays; an orphaned higher tier is dropped. |
| A saved id that no longer exists | Dropped with a warning. |
| A kill with no source (hazard, freed projectile) | No kill, no XP (the same kill credit as COMBAT.md; its open kill-credit item may widen it later). |
| A training dummy or the Knight himself dying | Dummies give 0 XP; a non-enemy (same team) never counts. |
| A Player with no champion | No talents, no counters, nothing tracked. |
| A talent .tres that breaks the group rules (a REPLACE, another ability's scope...) | `push_error`, skipped at attach; the talents test fails on it. |
| Tests | `Progress.saving_enabled` false; each test builds its own `ChampionProgress`; the real save is never touched. |

## Build order (one step per request)
Every step: the Knight's abilities, enemies chasing and the HUD still work; with an empty loadout the game plays exactly as before. Build logs go in CHANGELOG.md (a Talents section); this doc keeps one line per built step.

1. **T1 – Talent framework.** `toolkit_bundle.gd` (the bundle moved out of `passive.gd`, which now extends it; `apply_to()`'s `left_out_stats`), `talent.gd` (extends ToolkitBundle; group, tier, exclusive, requirements, `replaces_passive_stats`, validation), `talent_requirement.gd` (the class; nothing reads counters yet), `ChampionData.talents`, attaching a loadout in `_attach_champion()` (from a test export until T4), the passive slot's talent lines, `SandboxTalents`; `res://scenes/tests/talents_test.tscn` + `scripts/tests/talents_test.gd`. Built 2026-09-30, see CHANGELOG.md.
   **Done means:** a test talent of each piece kind (modifier, StatScaling, rule, FLAG, EVENT) attaches and detaches exactly by its source id; validation catches each broken rule (unscoped modifier, another ability's scope, any REPLACE, ABILITY_USES or an augment in PASSIVE, `replaces_passive_stats` outside PASSIVE or naming a stat the passive lacks); a test PASSIVE talent that replaces, one that adds, and one that does both each leave the passive as they say and the slot shows it; Unbroken and the champions test behave exactly as before the refactor; an empty loadout changes nothing; every existing test passes.
2. **T2 – The Knight's set, part 1: tier 1 and the data-only tier 2s.** The 10 tier 1 talents; Twin Lunge, Executioner (and `judgement.gd`'s 0 s stun skip), Battle Trance, Stalwart; the list in `knight.tres` (ChampionData); `SandboxAbilities.demo_charges` off in `sandbox.tscn` (its +1 Lunge charge would hide Twin Lunge's). Built 2026-09-30, see CHANGELOG.md.
   **Done means:** each talent does what its row says (a check per talent in the talents test); all pass validation; Ryan's play test with `SandboxTalents`: each one is felt, and the tooltips and the passive slot show it.
3. **T3 – The Knight's set, part 2: the six FLAGs.** Whirling and Rending Cleave (with the indicator) and their wave versions in `cleave_wave.gd`, Challenge, Bulwark, Tackle, Shockwave; the six FLAG augment .tres; the talents test's variant check. Built 2026-09-30, see CHANGELOG.md.
   **Done means:** each FLAG plays as its row says and keeps the kit's shared pieces (Cleave's Staggered bonus and heal, Judgement's Fury payoff); Cleave's indicator matches its flag; with Cleave Wave equipped, Whirling Wave and Rending Wave play as their lines say; Ryan's play test: each tier 2 pair feels like two ways to play the ability, not a bigger and a smaller one.
   **T3b – Tooltips say what the ability does now** (Ryan, 2026-09-30, after T3's play test: Bulwark's W still promised the empowered swing). `Talent.ability_description`; `AbilityComponent.set_description_override()` / `remove_description_overrides_from()` / `get_description_override()`; `Ability._fill_template()` uses the override; the talent's own augment lines muted under it; the seven texts; `_ratios_text()` leaves out a 0 scaling term, as its comment always said (Shockwave's "+0% of the target's missing health"). Built 2026-09-30, see CHANGELOG.md.
   **Done means:** with Bulwark, Iron Resolve's tooltip has no "next attack" and shows the shield; every rewritten text resolves its placeholders; removing the talent brings the ability's own text back; Cleave Wave keeps its own text.
4. **T4 – Progress: counters, XP, levels, unlocks, the loadout rules, saving.** `ChampionLeveling` + `champion_leveling_default.tres`, `ChampionProgress`, the `Progress` autoload (with `get_kill_tags()` returning none), `xp_by_unit` (slime 5, elite 40), `track()` from the Player, the loadout read from the record; the HUD level-up and unlock lines. Built 2026-09-30, see CHANGELOG.md.
   **Done means:** a Cleave cast adds 1 Cleave use (not a free cast, not a cancelled cast; a Cleave Wave counts as Cleave); a slime kill adds 1 kill and 5 XP; levels follow the table; requirements unlock and stay unlocked; points, siblings and the tier rule hold; a save and reload keeps everything; tests never write the real save.
5. **T5 – The hub (functional).** `hub.tscn`, `hub.gd`, `TalentScreen`, the debug tools, the pause menu's Back to hub, the hub as the main scene. Built 2026-09-30, see CHANGELOG.md.
   **Done means:** at the hub the Knight's 20 talents show their state and live requirement lines; clicking adds and removes within the rules; Start run plays with exactly that loadout; Back to hub keeps the progress; quitting and relaunching keeps it.

**Milestone T-M – A Knight's talent career** (after T5): from a reset champion, Ryan plays a few real sessions (and the debug tools for the long tail): the first unlock comes within the first run or two; every tier reads as a choice between ways to play; two loadouts make the Knight play differently.
**Done means:** Ryan's play test: the loop reads (what to do to unlock, what's active, why something can't be picked) and the talents change how the Knight plays, not just his numbers. **Passed Ryan's play test (reported 2026-10-03), see CHANGELOG.md.**

## Out of scope
Talents for other champions (written with each champion, under the authoring rule); talent REPLACEs, talent-granted forms, multi-slot REPLACE and keystones (decided no); a respec cost (no currency yet); the polished hub, icons and champion select (UI.md, the art pass); run structure and the clear bonus (DUNGEONS.md); enemy tags (ENEMIES_AI.md); full save slots, cloud saves and save migration (PROGRESSION.md); talents changing the Fury rhythm, the basic attack or the dash (no group).

## Open questions
Answered in the planning interview (Ryan, 2026-09-30):
1. ~~The `TalentRequirement` shape~~: one resource, `kind` (CHAMPION_LEVEL / ABILITY_USES / KILLS) + `amount` + `enemy_tag`, the ability implied by the group; unlocks kept once earned; the tier rule.
2. ~~The XP curve~~: as drafted, all five points at about 29 runs, so the build is online with the whole endgame still ahead.
3. ~~How the hub reads unlock progress~~: everything visible, live counters per requirement, met lines ticked.
4. ~~The authoring rule~~: kind, not magnitude (Rules, Authoring rule).
5. ~~The Knight's set~~: approved as written, with three changes: talents never REPLACE (Cleave's tier 2 and Judgement's area pick became FLAGs: Whirling / Rending Cleave, Shockwave); Iron Resolve's tier 2 gets an offensive pick (Challenge, replacing Stand Firm); Unbroken's tier 2 trades via the new "instead of" hook (Battle Trance, Stalwart).

Claude's proposals (all answered by Ryan, 2026-09-30):
6. ~~A talent FLAG on an item's variant~~: answered (Ryan, 2026-09-30): every variant supports every talent FLAG of the ability it replaces, with its own take (Whirling Wave, Rending Wave); ABILITIES' FLAG rule is unchanged.
7. ~~The "instead of" hook's shape~~: answered (Ryan, 2026-09-30): by stat (`replaces_passive_stats`), modular: replace and add are independent and combine (Rules, Replace and add).
8. ~~The working rules~~: approved (Ryan, 2026-09-30): both are rules.
9. ~~Free casts and recast parts~~: approved (Ryan, 2026-09-30): free casts don't count as uses; a recast sequence is one use.
10. ~~Points per talent~~: approved (Ryan, 2026-09-30): each talent costs 1 point.
11. ~~`Talent extends Passive`~~: answered (Ryan, 2026-09-30): a shared base class both extend (`ToolkitBundle`; Data, ToolkitBundle).
12. ~~Saving~~: approved (Ryan, 2026-09-30): TALENTS saves `user://progress.cfg` until PROGRESSION.md; `ChampionData.champion_level` / `champion_xp` become a new record's starting values (CHAMPIONS.md updated).
13. ~~Names~~: approved (Ryan, 2026-09-30): `Progress` (autoload), `ChampionProgress`, `ChampionLeveling`, `SandboxTalents`, `TalentScreen`, `ToolkitBundle`.
14. ~~`UnitStats.xp_reward` and `Enemy.kill_tags`~~: answered (Ryan, 2026-09-30): wait for ENEMIES_AI.md; until then a temporary `xp_by_unit` table in the leveling .tres, and no kill tags.
15. ~~The hub flow~~: approved (Ryan, 2026-09-30): the hub is the main scene; the pause menu gets Back to hub.
