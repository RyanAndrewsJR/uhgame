# CHAMPIONS.md: Champions, Passives, Resource Rhythms and the Knight's Kit

**Read when:** the task involves a champion's data (ChampionData), a passive, a champion's resource type and how it fills and drains (fury, energy, mana), a champion's level/progress field, or any part of the Knight's kit (Unbroken, Fury, Staggered, Cleave's heal, Judgement's Fury payoff) or Korsavil's (designed, not built: Energy, Blades, Inevitable Demise and its detonation, Vanish, Umbral Stalker).
**Depends on:** CLAUDE.md, VISION.md (Game structure: champion level, fixed slots), CONVENTIONS.md, STATS.md (StatsComponent, ResourceComponent, scoped modifiers), COMBAT.md (HitPipeline, statuses, Sustain), ABILITIES.md (the toolkit: conditions, conditional bonuses, named inputs, AB14's cast progress), AUDIO.md (hooks).
**Used by:** TALENTS (per-champion trees gated by the champion level), LOOT (champion-specific items, weapons by class), UI (the hub's champion pick, the passive tooltip, the resource bar), PROGRESSION (saving the champion level), DUNGEONS (respawn rules for the resource; one champion quest line per wing; a champion's class and ability tags matched against a wing's recommendations).
**Status:** champion archetypes and the Assassin layer (the deflect-dash, the refund, the jab, the riposte, the poise meter; weak basic attacks for every champion) are specified in ARCHETYPES.md (2026-10-07), and this doc was synced with it the same day.

## How to read this doc
Same as COMBAT.md and ABILITIES.md: MUST (never change without asking Ryan), TARGET (start value and allowed range), FREE (your call; tiebreaker: VISION.md's decision priorities). Items marked *(proposed)* are Claude's picks from the approved plan that Ryan hasn't answered yet; each one is also in Open questions.

## Player experience
You pick the Knight at the hub. He starts a fight with an empty red bar. Every swing that lands fills it; you spend it on Cleave, or save it for a Judgement that stuns longer and hits harder. Lunge through a pack and the enemies you cut through reel, Staggered; a Cleave into them hits much harder. The lower your health, the harder the Knight hits, and at the brink a Cleave that connects pulls you back: at 10% health one Cleave that hits anything heals over half of what you're missing. Standing back is never safe (no regen, Fury drains out of combat); diving in and landing hits is how the Knight survives.

## References
- League of Legends. Take: one identity per kit (passive + three abilities + an ultimate); Olaf's passive (stronger the more health is missing, smoothly, no breakpoint); Tryndamere and Renekton's fury (built by hitting, drains out of combat, empowers abilities); Lee Sin's Q1 → Q2 (mark, then cash in the mark). Don't take: per-ability ranks leveled mid-run (no ranks: ABILITIES.md, Ability ranks).
- Diablo 4. Take: the Barbarian's Fury as a generator/spender rhythm (basic attacks build it, core skills spend it); "while injured" bonuses. Don't take: skills gated behind stat checks.
- Hades. Take: each weapon/character's kit reading at a glance, and rewarding aggression.

## Principles
1. **Champions are data.** A champion is a `ChampionData` .tres plus ability scripts, never a subclass of Player (CLAUDE.md). A new champion needs no new framework code.
2. **Passives are built from the toolkit.** Stat modifiers, reaction rules, statuses, empowers, augments and (only for one-offs) a script, all under one source id. Nothing new at the framework level, except `StatScaling` (Passives, below), because a passive has no cast to carry a named input.
3. **Fixed slots.** A champion's four abilities stay in their slots (VISION.md, Build variety). Build variety comes from talents (TALENTS.md) and item augments reshaping those abilities.
4. **Sustain is earned.** No champion heals by default (COMBAT.md, Sustain). A kit heal is tied to landing one ability and serves skill expression (pillar 1).
5. **Resources set the rhythm.** A resource type changes how a kit plays (pillar 2): fury rewards staying in the fight; mana and energy (later champions) reward pacing.

## Current code
What exists before CH1 (the rest is Data and Architecture):
- `Player` (`res://scripts/player/player.gd`, `res://scenes/player/player.tscn`) is the Knight: `stats` = `res://data/units/knight.tres` (650 health, 64 AD, 0.7 attack speed, 0.25 crit, 375 move speed, MANA 300 at 6/s as a placeholder); `AbilityComponent` q/w/e/r = `knight_q_cleave.tres`, `knight_w_iron_resolve.tres`, `knight_e_lunge.tres`, `knight_r_judgement.tres`; `AutoAttackComponent.combo` = `res://data/combos/combo_knight.tres`; `ResourceComponent.resource_type` = MANA; `hurt_sound` and `low_health_sound` exports set in the scene (`death_sound` null).
- `ResourceComponent` (`res://scripts/components/resource_component.gd`): `ResourceType` MANA / ENERGY / FURY (a label only), starts full, regen from `resource_regen`, `try_spend()`, `restore()`, `resource_changed`, `depleted`.
- The toolkit this doc uses is built (ABILITIES AB1–AB13): conditions (`TARGET_HAS_STATUS`, `RESOURCE_AT_LEAST`), `ConditionalBonus`, named inputs (`self_missing_health`), `ChargeScaling` with an `input`, `hit_units()`, statuses, unit reaction rules, augments, `HitPipeline.apply_on_hit()`, `Unit.heal()`.
- Nothing about champions, passives, fury rules or the champion level exists yet.

## Rules
### What a champion is (MUST)
- A `ChampionData` resource ties together: identity (id, name, class), a base stats reference (`UnitStats`), a resource type and its rhythm (MANA / ENERGY / FURY / NONE), four ability slots Q / W / E / R (one clear identity per kit: three abilities and an ultimate), the default basic attack combo, a passive, the champion's sounds, and the champion level fields.
- Slots are fixed and never remixed between champions or reassigned by the player. REPLACE augments and forms (ABILITIES.md) still change what's active in a slot; that's part of a build, not a slot choice.
- The champion's combo is its own until weapons change combos: LOOT's weapons (from L1) don't in this build (Ryan, 2026-10-01; LOOT.md, Item slots), and whether a champion's combo will come from its equipped weapon, limited by its class, stays COMBAT.md's open question.
- `champion_class` (the Knight: `bruiser`) is the "class" the COMBAT decisions already use for dash-strike power and which weapons a champion can wield (name approved by Ryan, 2026-09-29). It isn't a role tag: role tags are ability roles (`generator`, `core`...).
- **A champion has an archetype** (ARCHETYPES.md; Ryan, 2026-10-07): Assassin, Mage, Skirmisher, Bruiser or Duelist, the same words enemies use (fodder's Basic is never a champion's). `champion_class` holds its id (the Knight `&"bruiser"`, Korsavil `&"assassin"`) until ARCHETYPES AR8 renames the field `archetype`, the old name kept as an alias (ARCHETYPES.md, Open questions 14). The archetype's layer attaches at load, from its own resource (`Archetype`, under `&"archetype_<id>"` *(proposed, ARCHETYPES.md, Data)*): only the Assassin's is locked (the deflect-dash, the refund, the jab, the riposte, the poise meter); the other four are placeholders. Diver, rogue, tank and marksman are no longer classes (D14 parks tank and marksman). Elsewhere in this doc, "class" means the archetype.

### Champion level (MUST; a hook only)
- Each champion has its own persistent level and progress, separate from every other champion (VISION.md, Game structure): `champion_level` (int, starts 1) and `champion_xp` (int, starts 0: the XP earned toward the next level). Level plus XP-into-level (rather than total XP) means retuning the curve later can never take a level away.
- It only ever gates that champion's talent points (TALENTS.md). It never calls `StatsComponent.set_level()` and never touches combat stats. There is no leveling inside a run.
- Not designed here: the leveling curve, XP sources and rates (TALENTS.md once it exists). Nothing reads the fields yet.
- ~~The fields hold the value while the game runs.~~ Changed 2026-09-30 (Ryan): the fields are a new progress record's starting values; the live level and XP live in TALENTS' `ChampionProgress`, saved to `user://progress.cfg` until PROGRESSION.md (TALENTS.md, Saving). A ChampionData .tres is design data (read-only in an exported build), so it always ships level 1 / 0 XP; saving and loading the player's values from `user://` is PROGRESSION's (or TALENTS') (Ryan, 2026-09-29).

### Ability ranks
- None (decided 2026-09-29; ABILITIES.md, Ability ranks; DECISIONS.md, Game structure). In-run power comes from loot; cross-run power from the champion level and the talent tree.

### Passives (MUST)
- A passive is a `Passive` resource on the ChampionData, attached when the champion loads under the source id `passive_<champion id>` (the Knight: `&"passive_knight"`), exactly as an item or an augment source attaches its pieces, and removable the same way (every piece removed by that source id restores the unit exactly).
- It bundles only toolkit pieces: StatModifiers (StatsComponent), `StatScaling`s (below), unit reaction rules (`Unit.add_reaction_rule()`), statuses applied until removed (conditions and `target:` scopes can read them: unique state is a status), augments (AbilityComponent), empowers (statuses), and an optional script for anything truly one-off (`Passive` subclass hooks).
- **`StatScaling`**: a stat modifier whose value follows a 0–1 input through a curve ("stronger the more health you're missing"). It exists because a passive has no cast: the named inputs (`self_missing_health`...) live on a CastContext and are filled when a cast starts, so a passive can't read them. It's data because several kits and items will want it (Olaf, Tryndamere, Diablo's "while injured"; the data-or-script rule). Only `self_missing_health` is built in for now; more inputs are added when something needs them.
- **An archetype's layer isn't the champion's passive** (ARCHETYPES.md, D11; Ryan, 2026-10-07). What every champion of an archetype shares (the Assassin's deflect-dash, refund, jab, riposte and poise meter) comes from the archetype at load, never from `passive_<champion id>`. A passive holds only what is the champion's own (Korsavil's keeps Blades and Inevitable Demise: the marks and their detonation).

### Resource rhythms (MUST; answers ABILITIES.md's open question: they live here)
- Each resource type's rhythm is ChampionData data applied to the ResourceComponent: whether the pool starts empty, whether it decays out of combat and how fast, plus the stats it already has (`max_resource`, `resource_regen`, `resource_on_hit`).
- "In combat" = the unit dealt or took a hit that got through (`Events.unit_hit`, not blocked; DoT ticks count) within the last `decay_delay` seconds of game time.
- Mana and energy champions get their numbers when the first one is designed.

### Sustain (MUST)
- Cleave's heal (`heal_missing_health_ratio`, CH5b; CH5 built it on `heal_on_hit_ratio`) is a kit mechanic tied to one ability, not the `life_steal` stat, and it doesn't contradict zero baseline sustain (COMBAT.md, Sustain; DECISIONS.md, Combat): no champion gets free healing by default; this one is earned by landing Cleave, and it scales hardest exactly when the player is at risk.
- Every heal goes through the one heal path, `Unit.heal()` (clamped to max health, no overheal, a green number only for what was actually healed). There's no second heal path.

### Dungeon content per champion (DUNGEONS.md; MUST, Ryan 2026-10-03)
- **One champion quest line per wing.** Every champion has one quest line of its own in every wing: "medium-small", about 10–15 minutes, reusing the wing's space (an existing room, a hidden door, a special encounter or a small puzzle; at most a small new alcove), paying out a one-of-a-kind named reward (not the Unique rarity) plus codex entries.
- **A champion ships with its lines.** Quest lines are written only for champions that exist; a champion added later adds one line per existing wing, as an update. The cost per champion: 2–3 lines at the first release (one dungeon of 2–3 wings), about 24 at 8 dungeons of 3 wings; the cap and what one line contains are in DUNGEONS.md (The champion lens).
- **The lens:** the layout, enemies and main quests are the same for every champion; codex entries, NPC dialogue and some scenes have per-champion variants (NARRATIVE.md writes them).
- **Recommendations read the kit:** a wing's "Recommended for" matches a champion's `champion_class` and its four abilities' tags (DUNGEONS.md, Recommended for). *(proposed, DUNGEONS.md)* If a wing ever favors something no class or ability tag says, `ChampionData` gets a `kit_tags` list then. Every champion can clear every wing either way.

## The Knight
A bruiser: heavy swings, dives into packs, gets stronger and harder to kill the closer he is to death. Pillars: skill expression (the Lunge → Cleave combo, low-health risk), build variety (Fury as a generator/spender rhythm), fluid combat.

### Identity
- `id` `&"knight"`, `display_name` "Knight", `champion_class` `&"bruiser"`.
- Stats: `data/units/knight.tres`, unchanged except the resource (Fury, below).
- Combo: `combo_knight.tres` (COMBAT.md), dash-strike 1.5 × AD (the bruiser number COMBAT.md already has).
- Role tags: kept as they are (Ryan, 2026-09-29): Cleave `core` (the spender), Iron Resolve `defensive`, Lunge `mobility`, Judgement `ultimate`. The Knight's generator is his basic attack.
- Walls: no Knight ability ignores walls (Ryan, 2026-09-29).
- Ultimate: cooldown, not a meter (ABILITIES.md). The meter is designed when a champion first uses one.
- Sounds: `hurt_sound` `sound_knight_hurt.tres`, `low_health_sound` `sound_knight_low_health.tres`, `death_sound` none (as today). Audio hooks: see AUDIO.md.
- **Archetype: Bruiser** (ARCHETYPES.md, Bruiser; Ryan, 2026-10-07). **In the end he has no deflect and no poise meter** (D3): deflect and poise are the Assassin's. The Bruiser's champion layer is a placeholder (Brace *(proposed, placeholder)*); nothing in his kit changes for it now. His dash keeps its 0.35 s recharge.
- **His deflect test version** (the prototype: DECISIONS.md, Combat, 2026-10-07; CHANGELOG.md, Combat, PROTOTYPE) stays behind its flag (V in the sandboxes) until Korsavil's Assassin layer (ARCHETYPES AR5) passes Ryan's play test. Then, with Ryan's OK and in the same chain of commits, ARCHETYPES AR6 disables it (not deleted: D11). His poise chips (4 a swing, Cleave 20, Judgement 40) stay, so he can still break an enemy Assassin's meter; tuned in AR6 (ARCHETYPES.md, Open questions 6).

### Passive: Unbroken (name is a placeholder)
- As the Knight's health drops he gains bonus attack damage, smoothly (like Olaf's passive, no hard breakpoint).
- One `StatScaling`: `attack_damage` PERCENT_ADD, full value **+0.40** (TARGET 0.25–0.6), input `self_missing_health`, curve `data/curves/curve_knight_unbroken.tres`: linear from 0 at full health to full at 70% missing (30% health), flat after. So +0% at full health, about +14% at 75%, +28.6% at 50%, +40% at 30% or less. On the Knight's 64 AD: 73 / 82 / 90 AD. It multiplies (base + flat) AD, so AD from items grows with it.
- Armor: none. Unbroken is AD only (Ryan, 2026-09-29). Cleave's heal already carries low-health survival.
- Tooltip: "The lower your health, the harder you hit: up to +40% attack damage at 30% health or less."

### Fury (the Knight's resource)
Built from landing basic attacks, drained out of combat, meant to be spent fast rather than banked. Replaces the MANA 300 / 6/s placeholder.

| Number | Value (TARGET range) | Where |
|---|---|---|
| `max_resource` | 100 (MUST: a 0–100 bar) | `knight.tres` (was 300) |
| `resource_regen` | 0 | `knight.tres` (was 6) |
| Starts | empty | ChampionData `resource_starts_empty` |
| Gain | +8 per enemy hit by a basic attack (5–12), the dash-strike included; abilities build nothing | a `resource_on_hit` FLAT 8 StatModifier scoped `hit:basic_attack`, source `champion_knight` (per enemy hit, and taking damage builds nothing: Ryan, 2026-09-29) |
| Decay delay | 3.0 s out of combat (2–5) | ChampionData `resource_decay_delay` |
| Decay | 20 per second (10–40): full to empty in 5 s | ChampionData `resource_decay_per_second` |
| Cleave cost | 20 (15–30): about one combo's worth single-target | `knight_q_cleave.tres` `resource_cost` |
| Iron Resolve, Lunge, Judgement cost | 0 (Lunge must open a fight from an empty bar; Judgement reads Fury instead) | their .tres |
| Judgement threshold | 60 (50–80) | Judgement's conditional bonus |

Rhythm, single target: the combo is about 3 swings per second, so about 24 Fury per second of landed swings; a pack of three fills the bar in about 1.5 s. Cleave's 3 s cooldown caps how fast Fury can be spent on it, so the rest builds toward Judgement's threshold or decays.

**Weak basic attacks** (ARCHETYPES.md, Weak basic attacks; D12; Ryan, 2026-10-07): from ARCHETYPES AR4 (built 2026-10-09) his unempowered swings deal 50% of today's damage (the per-champion stat `unempowered_attack_damage`, 0.5 on `knight.tres`, replacing the sandbox's TEMP lever). What empowers them is his Bruiser layer (D12): Iron Resolve's empowered swing (full damage) and the Fury payoffs his swings build toward (Cleave, Judgement at 60+), abilities the rule never touches. Fury per hit is unchanged: +8 per enemy a swing hits, weak or not, so the rhythm above holds.

### The combo: Lunge → Staggered → Cleave (the systemic-conditions showcase)
League's Lee Sin Q1 → Q2 pattern, built from AB12's existing pieces; no new condition kind.
- **Lunge** applies Staggered to every enemy it hits, through a `ConditionalBonus` with no conditions (an empty list always passes) whose `target_statuses` = [`status_staggered`] and `description` "Staggers enemies hit for 2s." Data only; free Lunges (the `cleave_casts_lunge` augment) stagger too.
- **Cleave** gets a `ConditionalBonus`: condition `TARGET_HAS_STATUS` `staggered` (min 1 stack), modifiers `base_damage` PERCENT_ADD +0.5 and `ad_ratio` PERCENT_ADD +0.5 (TARGET +30–60%), `description` "+50% damage to Staggered enemies." It's checked per enemy at its hit (`from_ability()` with the unit hit), so a Cleave through a mix hits the Staggered ones harder.
- No larger cone against Staggered targets: indicators show plain values, so a cone that grows with a bonus would break "what you see is what you get" (ABILITIES principle 2).
- Staggered isn't consumed by Cleave; it runs out (Ryan, 2026-09-29). Cleave's 3 s cooldown already prevents a double cash-in.

### Status: Staggered (`res://data/statuses/status_staggered.tres`)
| Field | Value |
|---|---|
| `id` / `display_name` | `&"staggered"` / "Staggered" |
| `tags` | `staggered`, `debuff`. **Not** `cc`: it's a marker, not crowd control, so tenacity doesn't shorten it, unstoppable doesn't refuse it, a `cc` cleanse doesn't remove it and `target:cc` bonuses don't count it |
| `duration` | 2.0 s (TARGET 1.5–3) |
| `stack_rule` | REFRESH (a second Lunge restarts it) |
| `modifiers`, `blocks_*`, DoT, shield, `reaction_rules`, `augments`, empower fields | none |
| `vfx` | a small marker over the enemy (FREE look, e.g. a pale yellow cracked ring; `res://scenes/vfx/staggered_mark.tscn`). It must be readable: the player needs to see who's Staggered (clarity) |
| Dispellable | only by a cleanse naming `debuff` or `staggered` (`RemoveStatusesByTagGameplayEffect`); nothing cleanses enemies today |
| Source | the Knight (whoever landed the Lunge) |
| Audio | Audio hooks: see AUDIO.md |

### Judgement's Fury payoff
- A `ConditionalBonus` on Judgement: condition `RESOURCE_AT_LEAST` 60 (on the Knight); modifiers `stun_duration` FLAT +0.5 (0.75 → 1.25 s), `base_damage` PERCENT_ADD +0.3 and `ad_ratio` PERCENT_ADD +0.3 (TARGET +20–50%); `description` "At 60+ Fury: +30% damage and +0.5s stun, and it consumes your Fury."
- Checked at the effect (AB8 / AB12 rule): the condition reads the Fury when the hit is built, after the channel. Judgement costs nothing, so no cost is taken before the check.
- The empowered Judgement consumes all the Knight's Fury after its hit (Ryan, 2026-09-29): without it, holding 60 would be a free buff, against "spent fast rather than banked". A one-off in `judgement.gd`: before the hit it checks whether an active bonus has a `RESOURCE_AT_LEAST` condition (the same frame and inputs as the hit's own check), and if the hit lands (not blocked) it spends `resource_pool.current`. `judgement.gd`'s `consume_resource_on_bonus` (default true) turns it off without code. A blocked Judgement consumes nothing.
- `judgement.gd` reads `stun_duration` with `get_effect_param()` (CONVENTIONS pattern 6), so the bonus reaches it.
- Retimed (Ryan, 2026-09-29): a **0.75 s channel** (`cast_time`, was 1.5 s; runs on cast progress, ABILITIES AB14) and a **30 s cooldown** (was the 5 s default).

### Cleave's heal
- **Changed (Ryan, 2026-09-30) (CH5b):** Cleave heals a share of the Knight's **missing health**, once per Cleave that hits, not a share of the damage it deals. A single-target Cleave at low health must pull the Knight back, and Cleave isn't a big damage dealer without items. CH5's damage-based field stays built and general (`heal_on_hit_ratio`, 0 on every Knight ability).
- A general field on Ability, `heal_missing_health_ratio` (default 0; a scoped param, so items can raise it): the first hit of a cast that gets through heals the caster for ratio × their missing health at that moment. Once per cast: one enemy or five heal the same. Cleave's full value is **0.55**, shaped by `self_missing_health` (read at the effect start) through a curve: a `ChargeScaling` entry on Cleave with `param` `heal_missing_health_ratio`, `input` `self_missing_health`, `min_fraction` 0, curve `data/curves/curve_knight_cleave_heal.tres`.
- The curve as Ryan tuned it after CH-M (2026-09-30, in the editor; the first CH5b anchors were 0 / 3 / 8 / 15 / 55% at 100 / 75 / 50 / 25 / 10% health):

| Knight's health | Missing (curve x) | Heal % of missing health | Curve y (÷ 0.55) | Healed (650 max) |
|---|---|---|---|---|
| 100% | 0 | 0% | 0 | 0 |
| about 75% | 0.252 | 5.6% | 0.101 | 9 |
| about 53% | 0.473 | 17.9% | 0.326 | 55 |
| 32% | 0.680 | 27.2% | 0.494 | 120 |
| 10% | 0.9 | 55% | 1.0 | 322 (back to about 60%) |
| below 10% | 0.9–1 | 55% | 1.0 (flat) | up to 358 |

Measured with this curve (champions test): 62 at 50% health, 176 at 25%, 322 at 10%. Most points use linear tangents; the one at about 75% health has a free right tangent, so the stretch from 75% to 53% health bends slightly. The champions test reads the ratio and the curve from the data, so tuning them never breaks it (it checks the shape: 0 at full health, within 0–1, never lower as more health is missing).
- No hit, no heal: a Cleave into the air, or one whose every hit is blocked, heals nothing. A killing blow counts as a hit.
- Cleave Wave (the AB-M REPLACE variant) is the same as Cleave here (Ryan, 2026-09-29): the Staggered bonus (CH4) and the heal (on its first projectile hit that gets through) are in its .tres too.

### Knight ability sheets (targets after CH5; ABILITIES.md, Ability spec sheet)
Only the lines that change or matter here; everything else is ABILITIES.md's example and the .tres files.
```
Cleave / Knight / Q / knight_cleave
Role tag / other tags: core (the Fury spender) / area, cone
Cost: 20 Fury      Cooldown: 3 s      Cast time: 0.2 s (cast progress, AB14)
Damage: 80 + 70% AD, PHYSICAL
Conditional bonuses: TARGET_HAS_STATUS staggered → base_damage +50%, ad_ratio +50% (per enemy, at its hit)
Heal: heal_missing_health_ratio 0.55 of missing health, once per cast that hits, scaled by self_missing_health through curve_knight_cleave_heal (min_fraction 0) (CH5b)
Presentation hooks: empty (AB14)
Tooltip template: "Sweep your sword in a wide arc in front of you, dealing {damage} physical damage ({base_damage} {ratios}) and knocking enemies back. Each cast that hits heals you for up to {heal_missing_health_ratio%} of your missing health, more the lower your health." + the bonus line

Iron Resolve / Knight / W / knight_iron_resolve
Unchanged (cost 0, cooldown 8 s, cast time 0). Its empowered swing deals full damage under weak basic attacks (ARCHETYPES AR4, D12).

Lunge / Knight / E / knight_lunge
Cost: 0      Cooldown: 8 s      Cast time: 0.05 s (cast progress, AB14)
Conditional bonuses: (no conditions) → target_statuses status_staggered ("Staggers enemies hit for 2s.")
Supported augment flags: lunge_stuns (unchanged)

Judgement / Knight / R / knight_judgement
Cost: 0 (reads Fury)      Cooldown: 30 s      Cast time: 0.75 s CHANNEL (cast progress, AB14; moving cancels)
Damage: 150 + 100% AD + 20% of the target's missing health, PHYSICAL; stun 0.75 s
Conditional bonuses: RESOURCE_AT_LEAST 60 → base_damage +30%, ad_ratio +30%, stun_duration +0.5 s; then consumes all Fury
```

### Against enemy crowd control (checked 2026-10-05 for ENEMIES_AI.md, Combos)
- **The Knight has no crowd-control break and no unstoppable moment.** Iron Resolve is a haste and an empowered swing with a slow, Unbroken is attack damage, and Judgement stuns.
- **Rooted** (ABILITIES.md, Roots), he can swing, Cleave (its knockback pushes the attacker off), Iron Resolve and Judgement, but can't Lunge or dash. **Stunned,** he can do nothing.
- **Tenacity:** none on the Knight. It comes from gear (`affix_tenacity` on helms and boots, Oathbound Plate) and the Stalwart talent.
- **What answers an enemy's combo:** dodging its opener (always telegraphed and dodgeable) and diminishing returns on crowd control (ENEMIES_AI.md, Being combo'd). There is no combo budget: an enemy's cooldowns are its only limit. **No new Knight tool now** (Ryan, 2026-10-05; Claude's proposal), revisited at ENEMIES_AI's AI-M with the low-health judgment call.
- *(ENEMIES_AI Combos, proposed; with ALLIES AL6)* `ChampionData.combo_plans` (`Array[ComboPlan]`, empty): a champion's own ability chains (the Knight's Lunge → Cleave), read only when an AI drives the champion (the ally). The human never uses them.

## Korsavil
An assassin who gathers Blades, throws them through packs and cashes in what they marked. **Designed 2026-10-04; K1 built and passed the same day** (her data, loading, 3-swing cycle and the hub's pick), **K2 built 2026-10-04 and passed 2026-10-05** (Q Bladesinger, Blades, Inevitable Demise); her build steps are K1–K6 and K-M (Build order, Korsavil), right after Ryan's play test of ENEMIES_AI AI3d (Ryan, 2026-10-04). Ryan's decisions are MUST (Ryan, 2026-10-04); Claude's picks are marked *(proposed)* and listed in Open questions (Korsavil). Her ability sheets are in ABILITIES.md (Korsavil); the toolkit pieces she needs that don't exist yet are in ABILITIES.md, Later toolkit pieces. **She is an Assassin** (ARCHETYPES.md, 2026-10-07): her one dash, the deflect window, the refund, the jab, the riposte and her poise meter are the archetype's layer, not her kit's (Identity, below), built in ARCHETYPES AR5 before her K3. Units: League units, 100 u = 1 m = 32 px.

### Player experience
You pick Korsavil at the hub. She starts every fight with a full yellow bar and one long dash that deflects: dash into an enemy's hit as it lands and it's gone, the dash comes straight back, and a swing then jabs, or a second deflect readies a riposte that tears off a chunk of its health. Q sets Blades spinning around her, one more each second, and the more she holds the faster she moves and the less damage she takes. Her thrown knife (E) ricochets through a pack, and every enemy it cuts gives her another Blade. Recast Q and every Blade flies at the cursor: land all four and her ultimate changes for 10 seconds. Every Blade that lands marks its enemy with Inevitable Demise, damage over time that grows with the marks, and at eight marks her next finisher detonates them. When a fight turns, she Vanishes (W): the enemies on her lose her, and the longer she stays hidden, the harder her next three attacks hit. Her ultimate blinks her onto a target to strike, then lets her blink back out with a heal.

### Identity
- `id` `&"korsavil"`, `display_name` "Korsavil", `champion_class` `&"assassin"` (Ryan, 2026-10-04; in CONVENTIONS' class list since the same day).
- Resource: ENERGY (Ryan, 2026-10-04; Energy, below).
- Stats: `data/units/korsavil.tres` (new), placeholders until the play test (Ryan, 2026-10-04: Claude's placeholders): health **500** (lower than the Knight's 650, in 450–550), AD 60, attack speed 0.7, move speed 390 u (125 px/s), attack range 150 u (48 px, 1.5 m), crit chance 0.25, armor and magic resist 0. `dash_charges` stays 1 there~~: the second dash is the passive's (below)~~ (superseded 2026-10-07: ARCHETYPES.md, Assassin; D11): her one dash is the archetype's (next).
- **Archetype: Assassin** (ARCHETYPES.md, Assassin, The champion's layer; Ryan, 2026-10-07, D3b, D8, D11). `champion_class` `&"assassin"` is her archetype's id. The layer comes from the archetype at load, not from her passive:
  - **one dash, 25% longer:** 500 u (160 px) over the dash's 0.18 s, one charge, its i-frames as every dash; it recharges in 1.2 s (TARGET 0.8–1.5, tuned in AR5; the Knight keeps 0.35 s);
  - **the deflect window:** 0.2 s from the dash's start, beside the i-frames; a hit its data marks deflectable (every string hit, every perilous attack, aimed single-target bolts) is blocked whole;
  - **the refund:** the first deflect of a streak gives the dash charge back for 3 s;
  - **the jab:** after one deflect, her next swing that hits gets +1.0 AD ratio and snaps up to 1.5 m toward the attacker; it ends the streak;
  - **the riposte:** a second deflect (or one of a perilous attack) gives her next swing that hits +3.0 AD ratio plus 12% of the target's max health (4% on a boss); it snaps 3 m (6 m after a projectile deflect) and banks until a swing lands;
  - **the banked streak:** no chain window; it expires 10 s after the last deflect and clears when she leaves the room;
  - **Energy:** a deflect costs none; a successful one gives +10 (Energy, below);
  - **her poise meter** (0–100): a hit fills it by its share of her max health (heavy ×1.5, a landed perilous hit a flat 40), being rebuffed by an enemy Assassin 25; each of her deflects drains 15; it decays 15 a second after 3 s with no poise hit (slower below 40% health). At 100 she breaks: 1.0 s at ×1.25 damage taken, then 4 s immune.
  - The full spec and its edge cases are ARCHETYPES.md's; built in its AR5 (Build order, Korsavil).
- Combo: **two cycles**, both melee (Ryan, 2026-10-04): a 3-swing cycle normally and a 4-swing cycle from Vanish (while she's stealthed and while its empower lasts); **each cycle's last swing is a finisher**, carrying the `finisher` hit tag the detonation reads (Combo: two cycles, below).
- Role tags: E `generator`, R `ultimate` (Ryan, 2026-10-04); Q `core` (it spends the Blades) and W `defensive` *(proposed)*.
- Walls: her blinks go over walls (the blink's default, ABILITIES.md, Blinks); her Blades, knife and half circle don't hit through them *(proposed: no ability of hers `ignores_walls`)*.
- Ultimate: a cooldown (40 s), not a meter.
- Sounds: none yet (her swings use the Knight's swing sounds as placeholders since K1). Audio hooks: see AUDIO.md.

### Combo: two cycles
Ryan, 2026-10-04: her basic attack has two cycles, 3 melee swings and 4, switched by state: the 4-swing cycle from Vanish (while she's stealthed and while its empower lasts), the 3-swing cycle otherwise. Each cycle's last swing is a finisher. The rest is *(proposed)*:
- **Two combos:** `combo_korsavil.tres` (3 swings) on her ChampionData, and `combo_korsavil_vanish.tres` (4 swings) carried by `status_vanish` and both Vanish empowers through a new `StatusEffect.combo_override` (ABILITIES.md, Later toolkit pieces). Both MELEE with the default melee rules (COMBAT.md, Melee basic attacks); the last swing of each has `hit_tags` [`finisher`].
- **A cycle is picked when a chain starts** (at its first swing; this rule and the next approved by Ryan, 2026-10-04): the 4-swing cycle while a status with a `combo_override` is on, else the 3-swing. It then runs to its end even if the state ends inside it. This matters: the empower's third use is the 4-swing cycle's swing 3, so its swing 4, the finisher, still comes. A chain ends at its finisher (and breather), after the reset time (0.6 s) or at a forced reset (a stun, a cancel in a windup).
- **Vanish restarts the chain:** her first swing after casting it is swing 1 of the 4-swing cycle, wherever the old chain was.
- **Numbers** (placeholders, tuned at the play test; reach is her `attack_range`, 150 u):

| Cycle, swing | Windup | Root | Damage | Arc |
|---|---|---|---|---|
| 3-swing: 1 / 2 | 0.06 s | 0.22 s | 0.9 × AD | 90° |
| 3-swing: 3, finisher | 0.08 s | 0.32 s | 1.4 × AD | 120° |
| 4-swing: 1 / 2 / 3 | 0.05 s | 0.20 s | 0.8 / 0.8 / 0.9 × AD | 90° |
| 4-swing: 4, finisher | 0.08 s | 0.32 s | 1.5 × AD | 120° |

  About 0.76 s for the 3-swing cycle and 0.92 s for the 4-swing one (the Knight's 3 swings take 1.0 s before his `speed_scale`), each with a 0.2 s breather after its finisher. Knockback and steps the Knight's light and heavy ones (6 px and 20 px; steps 6 px, the finisher 10 px).
- **One dash-strike for both cycles:** 1.3 × AD (the assassin's number in COMBAT.md's "by class"), the Knight's thrust shape otherwise; it isn't a finisher and keeps her place in the chain (as today).
- **Weak basic attacks** (ARCHETYPES.md, Weak basic attacks; D12; Ryan, 2026-10-07): from ARCHETYPES AR4 (built 2026-10-09) an unempowered swing deals 50% of the numbers above (`unempowered_attack_damage` 0.5 on her UnitStats); her empowers hit full: the jab, the riposte and Vanish's.

### Passive (name TBD)
Three parts, all under the source id `passive_korsavil` (Ryan, 2026-10-04). Since 2026-10-07 two remain (Inevitable Demise and the detonation): part 1's dash is the Assassin archetype's (Identity, Archetype: Assassin; D11).
1. ~~**Two dashes:** `dash_charges` 2 (MOVEMENT.md, Dash: a charge returns every 0.35 s, and every dash carries its i-frames). *(proposed)* A FLAT +1 `dash_charges` StatModifier in the passive's `modifiers`; the alternative is 2 on her UnitStats. Either needs no new code: DashComponent reads the stat, and a raised max recharges up to it (STATS.md, Current code). The difference: from the passive she loads with one charge and gets the second 0.35 s later (the passive attaches after `Unit._ready()`, when DashComponent has taken its starting charges), and a talent or form could take it away; from UnitStats she loads with both.~~ (superseded 2026-10-07: ARCHETYPES.md, Assassin; D11). Her one dash comes from the archetype; the built +1 `dash_charges` modifier is removed in ARCHETYPES AR5.
2. **Inevitable Demise** (`status_inevitable_demise`, below): every Blade that hits an enemy adds one stack: each of Q's recast Blades and each E hit (bounce) that gets through. Its damage over 5 s is a replacing tier: 5 / 8 / 10 / 12% AD at 2 / 4 / 6 / 8 stacks; only the current tier applies, the tiers don't add up. A new Blade restarts the 5 s (Ryan, 2026-10-04). The stacks ride Q's and E's hits (their hit statuses, like Lunge's Staggered); the passive is what cashes them in.
3. **Detonation:** at 8 stacks, her next basic attack finisher (the last swing of either cycle: Combo, above) that hits the enemy consumes its 8 stacks and replaces them with a fresh DoT of 25% AD in total over 5 s (`status_demise_detonation`), and she gains +10% movement speed while it runs, 5 s (`status_detonation_haste`) (Ryan, 2026-10-04). Built as data *(proposed)*, two unit rules in the passive:
   - `reaction_korsavil_detonation`: trigger HIT, `required_hit_tags` [`finisher`] (a swing's hit tag, not built: COMBAT.md's `AttackSwing.hit_tags`, which waits for a champion that needs it; Korsavil is that champion), `conditions` [TARGET_HAS_STATUS `inevitable_demise`, min 8], effect target AFFECTED: `RemoveStatusesByTagGameplayEffect` [`inevitable_demise`], then `ApplyStatusGameplayEffect` `status_demise_detonation`.
   - `reaction_korsavil_detonation_haste`: trigger STATUS_APPLIED, `required_status_tags` [`demise_detonation`], owner SOURCE ("when I apply…"), effect target OTHER (her): `ApplyStatusGameplayEffect` `status_detonation_haste`; `chain_limit` 2, since it fires one link below the first rule. Chaining off the applied DoT (rather than a second HIT rule) keeps the order fixed: a second HIT rule could run after the first had removed the stacks and fail its condition.
   - A finisher that hits several enemies at 8 stacks detonates each of them (one HIT event each).
- Tooltip *(proposed)*: "~~You have two dashes.~~ Your Blades mark enemies with Inevitable Demise, damage over 5 seconds that grows at 2, 4, 6 and 8 marks. At 8 marks your next finisher detonates them into a fresh wound (25% AD over 5 seconds), and you move 10% faster while it bleeds." ("You have two dashes." superseded 2026-10-07: ARCHETYPES.md, Assassin; D11.)

### Energy (Korsavil's resource)
A steady pool, full when a fight starts and refilling on its own: spending is paced by the regen, not built by hitting (Ryan, 2026-10-04). This answers this doc's open item on energy's rhythm (Resource rhythms: mana and energy get their numbers with their first champion; mana stays open).

| Number | Value | Where |
|---|---|---|
| `max_resource` | 100 | `korsavil.tres` (UnitStats) |
| `resource_regen` | 10 per second | `korsavil.tres` |
| Starts | full | ChampionData `resource_starts_empty` false (the default) |
| Decay | none | `resource_decay_per_second` 0 (the default) |
| Costs | Q 25 (its recast 0), W 45, E 15, R 50 (its recast 0) | each ability's `resource_cost`; the recasts' `recast_resource_cost` 0 (the default) |
| During Vanish | +15 per second (25 in all) | `status_vanish`'s `resource_regen` FLAT +15 |
| Deflects | a deflect costs nothing; a successful one gives +10 (a whiffed dash costs only its recharge) | the Assassin archetype (ARCHETYPES.md, Assassin; D11), from AR5 |

Rhythm: from a full bar she can open with Q, E and R (90) and has W 3.5 s later; all four (135) take the bar plus 3.5 s of regen. E (15 every 7 s) is nearly free; W is the cast that empties the bar, and a full Vanish pays it back (Open questions, Korsavil, Balance flags). The HUD bar is yellow (ENERGY; ABILITIES.md, HUD). No ability reads RESOURCE_AT_LEAST, so the bar has no tick.

### Blades
Blades are a count she holds: the stacks of `status_blade` on her, 0–4 (Ryan, 2026-10-04). Her kit's "slash lists" are steps by Blades or stacks held, never ability ranks (there are none: Ability ranks).
- **Gained:** +1 each second while Q's orbit lasts (6 s); +1 per E hit (bounce) that gets through; +2 from W's third empowered attack; +2 from the base R's recast (after its strike landed).
- **Spent:** Q's recast sends every held Blade.
- **Kept:** they stay until spent; they don't vanish when Q's orbit ends. A gain past 4 is lost.
- **Read by:** Q's orbit (damage reduction and speed by Blades held, only while the orbit lasts), Q's recast (how many fly and how hard each hits) and its condition (at least 1 *(proposed)*). Held outside the orbit, Blades give nothing until Q is cast.

### Status: Blade (`res://data/statuses/status_blade.tres`)
| Field | Value |
|---|---|
| `id` / `display_name` | `&"blade"` / "Blade" |
| `tags` | `blade`, `buff` *(proposed: `blade` is what Q's recast condition and the orbit's scalings read)* |
| `duration` | −1: until spent (Ryan, 2026-10-04) |
| `stack_rule` / `max_stacks` | STACK / 4 (Ryan, 2026-10-04). A gain at 4 is lost: as built, a STACK status at max whose stacks all last until removed changes nothing on a new application (checked in `StatusComponent.apply_status()`), though the call still returns true and emits `status_applied` |
| `modifiers`, `blocks_*`, DoT, shield, `reaction_rules`, `augments`, empower fields | none. Blades give nothing by themselves: Q's orbit reads their count (`status_bladesinger`, below) |
| Applied by | Korsavil to herself: Q's orbit (+1 a second), E's hits (+1 each), W's third empowered attack (+2), the base R's recast (+2) |
| Removed by | Q's recast (every Blade, at its effect start); her death (statuses clear) |
| `vfx` | one blade circling her per Blade (FREE look). It must be readable: the player plays around the count (clarity) |
| Audio | Audio hooks: see AUDIO.md |

### Status: Inevitable Demise (`res://data/statuses/status_inevitable_demise.tres`)
| Field | Value |
|---|---|
| `id` / `display_name` | `&"inevitable_demise"` / "Inevitable Demise" |
| `tags` | `inevitable_demise`, `debuff`. **Not** `cc` *(proposed)*: a mark that deals damage, like Staggered a marker: tenacity doesn't shorten it, unstoppable doesn't refuse it |
| `stack_rule` / `max_stacks` | STACK / 8 (Ryan, 2026-10-04): one stack per Blade that hits the enemy |
| `duration` | 5 s, and a new Blade restarts the 5 s (Ryan, 2026-10-04). Every stack shares that one timer and they end together: a new stack rule, `STACK_SHARED` (ABILITIES.md, Later toolkit pieces; Ryan approved it, 2026-10-04). As built, STACK gives each stack its own time and at max restarts only the one closest to running out, so a new Blade wouldn't restart the rest (Open questions, Korsavil 2) |
| Damage | the replacing tier (Ryan, 2026-10-04): the current tier's total over each 5 s it lasts, 5 / 8 / 10 / 12% AD at 2 / 4 / 6 / 8 stacks. Odd counts use the tier below and 1 stack deals nothing, through a stack table on the DoT (Ryan approved, 2026-10-04). *(proposed)* A tick every 0.5 s, PHYSICAL; her AD snapshotted at each new stack (COMBAT.md's DoT rule); a new stack doesn't delay the next tick. As built, a DoT deals its tick × stacks, which can't make these tiers: the stack table is new (ABILITIES.md, Later toolkit pieces: `tick_ad_ratio` 0.01 with [0, 0.5, 0.5, 0.8, 0.8, 1.0, 1.0, 1.2]) |
| Consumed by | the detonation (Passive, above): removed, and `status_demise_detonation` applied in its place |
| `vfx` | a mark over the enemy that shows its count (FREE look, e.g. eight pips that fill). It must be readable: the player needs to see who's at 8 |
| Dispellable | as Staggered: only by a cleanse naming `debuff` or `inevitable_demise`; nothing cleanses enemies today |
| Source | Korsavil (DoT kill credit is hers, COMBAT.md) |
| Audio | Audio hooks: see AUDIO.md |

### Status: Umbral Stalker (`res://data/statuses/status_umbral_stalker.tres`)
| Field | Value |
|---|---|
| `id` / `display_name` | `&"umbral_stalker"` / "Umbral Stalker" |
| `tags` | `form`, `buff` (Ryan, 2026-10-04). As a form, applying it removes any other form on her (one form at a time, ABILITIES.md; she has no other) |
| `duration` | 10 s (Ryan, 2026-10-04) |
| `stack_rule` | REFRESH *(proposed)*: another 4-Blade recast restarts it, and its augment stays on (no slot flicker) |
| `augments` | one REPLACE, `augment_spectral_stalker.tres` *(proposed name)*: scope `ability:korsavil_spectral`, replacement `korsavil_r_spectral_stalker.tres` (id `korsavil_spectral_stalker`, `variant_of` `korsavil_spectral`; Ryan, 2026-10-04) |
| Applied by | Q's recast when all 4 Blades hit (Ryan, 2026-10-04); *(proposed)* counting Blades whose hits got through, on any enemies |
| Consumed by | R's first cast (Ryan, 2026-10-04): at the variant's first part's effect start, with its recast staying the variant's (ABILITIES.md, Korsavil: the Stalker timing; Ryan approved, 2026-10-04) |
| `vfx` | a shadowed look on her (FREE) |
| Audio | Audio hooks: see AUDIO.md |

### Status: Vanish (`res://data/statuses/status_vanish.tres`)
| Field | Value |
|---|---|
| `id` / `display_name` | `&"vanish"` / "Vanish" |
| `tags` | `stealth`, `buff` (Ryan, 2026-10-04): a copy of ALLIES' `status_stealth` (ALLIES AL1 plans that file; whichever comes first creates it). The enemies' target pick already reads the `stealth` tag (ENEMIES_AI AI2, built): a stealthed champion is never picked, and one already picked is dropped |
| `duration` | 5 s (Ryan, 2026-10-04) |
| `stack_rule` | REFRESH *(proposed)* |
| `modifiers` | `resource_regen` FLAT +15 (Ryan, 2026-10-04) |
| Ends early | when she casts an ability, makes a basic attack or dashes (Ryan, 2026-10-04). New: a status that ends when its holder acts (ABILITIES.md, Later toolkit pieces). A dash isn't an ability, and no reaction trigger sees it |
| `combo_override` | `combo_korsavil_vanish.tres`: while it's on, a new chain is her 4-swing cycle (Ryan, 2026-10-04; the field new, Combo: two cycles) |
| When it ends | `vanish.gd` gives the empower for her next 3 basic attacks (ABILITIES.md, Korsavil W) |
| `vfx` | she turns half see-through, like the dash (FREE look): the player still sees her |
| Audio | Audio hooks: see AUDIO.md |

### Other statuses her kit needs *(proposed names)*
| Status | What | Fields |
|---|---|---|
| `status_bladesinger` | Q's orbit | tags `bladesinger`, `buff`; 6 s; REFRESH; two StatScalings on the Blades' count (`incoming_damage` PERCENT_MULT −0.20 and `move_speed` PERCENT_ADD +0.20 at 4 Blades, linear: 5% per Blade). Needs the stack-count input (ABILITIES.md, Later toolkit pieces) |
| `status_demise_detonation` | the detonation's DoT | tags `demise_detonation`, `debuff`; 5 s; REFRESH (a second detonation restarts it with a new snapshot); a tick every 0.5 s, `tick_ad_ratio` 0.025 (25% AD over 10 ticks), PHYSICAL |
| `status_detonation_haste` | her speed while it runs | tags `haste`, `buff`; 5 s; REFRESH (a second detonation restarts it: never +20%); `move_speed` PERCENT_ADD +0.10 |
| `empower_vanish`, `empower_vanish_full` (`status_empower_vanish.tres`, `status_empower_vanish_full.tres`) | W's empower after a short / a full Vanish | tags `empower`, `buff`; BASIC_ATTACK_HIT; 3 uses (new); 5 s; `empower_ad_ratio` 0.10 / 0.15; the full one makes each empowered swing's whole damage TRUE (Ryan, 2026-10-04; `empower_damage_type`, new); both carry the 4-swing cycle (`combo_override`) (ABILITIES.md, Korsavil W) |
| `status_fear` | the Stalker's fear | ABILITIES.md, Later toolkit pieces (the fear status) |

### The numbers
| | Q Bladesinger | W Vanish | E Blade Dance | R Spectral (placeholder name) |
|---|---|---|---|---|
| Role | `core` *(proposed)* | `defensive` *(proposed)* | `generator` | `ultimate` |
| Cost (energy) | 25, its recast 0 | 45 | 15 | 50, its recast 0 |
| Cooldown | 10 s | 12 s | 7 s | 40 s |
| Cast time | 0.25 s, each part | 0.25 s | 0.5 s | 0.25 s, each part |
| Targeting, range | SELF; the Blades fly 6 m (600 u, 192 px) in a 90° spread *(proposed: metres)* | SELF | DIRECTION, 6 m *(proposed)* | UNIT, 11 m (1100 u, 352 px) *(metres proposed)* |
| Damage | each Blade 80 / 90 / 100 / 110% AD at 1 / 2 / 3 / 4 Blades sent | none; then 3 empowered attacks (her 4-swing cycle): +10% AD, or after 4 s or more +15% AD with the whole swing TRUE | 30% AD, +5% per bounce: 30 / 35 / 40 / 45% (4 hits in all) | 60% then 100% AD; the Stalker 20 / 35 / 70% AD, its recast 120% AD |
| Also | a 6 s orbit: per Blade −5% damage taken and +5% movement speed; all 4 hit → Umbral Stalker, 10 s | 5 s stealth, +15 energy a second; the 3rd empowered attack +2 Blades | each hit: +1 Blade, +1 Demise stack | recast (3 s *(proposed)*): blink back, heal max(5% max health, 100), +2 Blades. The Stalker's recast: blink to a point, fear 1.5 s (not bosses), heal max(10% max health, 150) + 5% AD |

Passive: ~~two dashes;~~ Demise 5 / 8 / 10 / 12% AD per 5 s at 2 / 4 / 6 / 8 stacks (max 8); at 8, a finisher detonates: 25% AD over 5 s and +10% movement speed for 5 s. Dash: one dash (the Assassin's: 500 u, recharging in 1.2 s, with the deflect layer; the passive's two dashes superseded 2026-10-07: ARCHETYPES.md, Assassin; D11). Energy: 100, 10 a second, starts full, no decay. Stats (placeholders): health 500, AD 60, attack speed 0.7, move speed 390 u, range 150 u, crit 0.25. Combo: 3 melee swings, 4 from Vanish, a finisher at the end of each.

### ChampionData (`res://data/champions/korsavil.tres`)
| Field | Korsavil |
|---|---|
| `id` | `&"korsavil"` |
| `display_name` | "Korsavil" |
| `champion_class` | `&"assassin"`: her archetype (ARCHETYPES.md); renamed `archetype` in ARCHETYPES AR8, the old name an alias |
| `stats` | `data/units/korsavil.tres` (new): health 500, AD 60, attack speed 0.7, move speed 390, attack range 150, crit 0.25, `max_resource` 100, `resource_regen` 10 (placeholders) |
| `resource_type` | ENERGY |
| `resource_starts_empty` | false (the default) |
| `resource_decay_per_second` / `resource_decay_delay` | 0 / 0 (the defaults) |
| `modifiers` | none |
| `q`, `w`, `e`, `r` | `korsavil_q_bladesinger.tres`, `korsavil_w_vanish.tres`, `korsavil_e_blade_dance.tres`, `korsavil_r_spectral.tres` *(proposed file names)* |
| `combo` | `combo_korsavil.tres` (the 3-swing cycle); the 4-swing cycle `combo_korsavil_vanish.tres` comes from Vanish's statuses *(proposed names)* |
| `passive` | inline, name TBD: ~~the `dash_charges` modifier and~~ the two detonation rules (no script) (the modifier superseded 2026-10-07: ARCHETYPES.md, Assassin; D11; removed in AR5) |
| `hurt_sound`, `death_sound`, `low_health_sound` | none yet |
| `champion_level` / `champion_xp` | 1 / 0 |
| `model_scene` | empty (a placeholder capsule) until a model exists |

### What she waits on
- **Toolkit pieces** (ABILITIES.md, Later toolkit pieces, each *(proposed; built when Korsavil is)*): built in K2: numbers that follow a stack count (Q's orbit, Demise's tiers) and stacks that share one timer (Demise); still to come: the bounce projectile (E), a status that ends when its holder acts (W), an empower with several uses, an empower damage type and a status that swaps the combo (W), the finisher hit tag (the detonation), a recast part's own targeting (R), the fear status (the Stalker), the "higher of" heal (R; a script one-off).
- **Other docs (open dependencies, recorded there 2026-10-04):**
  - **The search** (ENEMIES_AI.md, Losing a stealthed target): enemies chasing her when she Vanishes lose her and search, a simulated look-around at her last known spot (not a real vision cone) for 3 s *(proposed)*, then go back (Ryan, 2026-10-04). A new enemy behavior, not built. Today ALLIES' pick only drops a stealthed target (ENEMIES_AI AI2, built), and a pack with nobody else to pick walks home after 6 s with nothing in reach.
  - **The fear** (COMBAT.md, Status effects, Fear; ENEMIES_AI.md, Fear): the status, the flee and bosses ignoring it. Not built.
  - **Stealth's break rule** (ALLIES.md, How enemies pick a target, Stealth): `status_stealth` ending when its holder acts, as Vanish does *(proposed there)*.
- A model and sounds (a capsule and silence until then).

### Korsavil's kit edge cases
Ability-level cases (Q's recast with 0 Blades, Vanish's own cast, its 5 s expiry, E with no next target, R's recast while rooted, the Stalker revert, fear on an unstoppable enemy) are in ABILITIES.md, Korsavil.

| Edge case | Handling |
|---|---|
| A Blade gained at 4 | Lost (Status: Blade). An E hit still adds its Demise stack. |
| Two of Q's Blades hit one enemy | Two Demise stacks, one per Blade that hits. |
| Demise at 8 and another Blade lands | No 9th stack; the shared 5 s restarts and the snapshot is retaken. |
| A Blade's hit kills the enemy | No stack on the dead (statuses skip a target the hit killed). |
| The detonating finisher kills its target | No detonation and no speed *(proposed)*: a killing hit clears the target's statuses before its HIT event (COMBAT.md, `Unit.on_hit()`, step 3), so the rule's TARGET_HAS_STATUS reads nothing, and a DoT on a dead unit would deal nothing. Nothing carries to another enemy. |
| A finisher at 8 stacks blocked by i-frames | Nothing: a blocked hit fires no HIT event. The stacks wait, their 5 s still running. |
| The detonation's +10% speed and Q's | They add: both are PERCENT_ADD `move_speed` (+10% and up to +20%: +30% in all), then the soft caps (STATS.md, move_speed special rules). A second detonation within 5 s restarts the haste (REFRESH), never +20%. *(proposed)* The haste keeps its 5 s even if the enemy dies before its DoT ends. |
| A detonation on an enemy whose detonation DoT still runs | The new one replaces it (REFRESH: a fresh 25% AD over 5 s, a new snapshot); the old one's undealt part is lost. New Blades build Demise again from 0 meanwhile. |
| The enemy holding Demise turns untargetable | New Blades are blocked (no new stacks); the DoT keeps ticking (untargetable lets DoT ticks through). |
| Korsavil dies | Her statuses clear: the Blades, the orbit, Vanish (no empower: a dead unit takes no status) and Stalker. The DoTs she applied keep ticking on her snapshot, with her kill credit while she exists (COMBAT.md, DoT). |
| Umbral Stalker gained while R's cooldown runs | The slot shows the variant on R's running cooldown (a REPLACE keeps the slot's charges and timer); if Stalker's 10 s end first, it's lost unused. |
| Umbral Stalker gained while the base R's recast window is open | The window keeps the base R's recast (a recast sequence keeps its ability); R's 40 s cooldown starts when it ends, so Stalker usually runs out unused. |

## Data (Resources)
Names checked against CONVENTIONS.md (reserved names, vocabulary).

### ChampionData (Resource, `res://scripts/data/champion_data.gd`; `res://data/champions/<name>.tres`, the Knight's `data/champions/knight.tres`)
Every field defaults to "change nothing"; a Player with no ChampionData keeps using its scene's exports.

| Field | Type | Knight | Maps to (existing) |
|---|---|---|---|
| `id` | `StringName` | `&"knight"` | new; source ids `passive_<id>`, `champion_<id>` |
| `display_name` | `String` | "Knight" | new (`UnitStats.display_name` was deleted) |
| `champion_class` | `StringName` | `&"bruiser"` | new; the archetype's id since 2026-10-07 (ARCHETYPES.md), renamed `archetype` in ARCHETYPES AR8, the old name kept as an alias |
| `stats` | `UnitStats` | `data/units/knight.tres` | `Unit.stats` |
| `resource_type` | `ResourceComponent.ResourceType` | FURY (since CH3; MANA in CH1–CH2) | `ResourceComponent.resource_type`; `NONE` is added last in the enum: the ResourceComponent node is removed at load |
| `resource_starts_empty` | `bool` | true | `ResourceComponent.starts_empty` (CH3) |
| `resource_decay_per_second` | `float` | 20 | `ResourceComponent.decay_per_second` (CH3) |
| `resource_decay_delay` | `float` | 3.0 | `ResourceComponent.decay_delay` (CH3) |
| `modifiers` | `Array[StatModifier]` | `resource_on_hit` +8 scoped `hit:basic_attack` | StatsComponent, source `champion_<id>` (CH3) |
| `q`, `w`, `e`, `r` | `Ability` | the four `knight_*` .tres | `AbilityComponent.q` / `w` / `e` / `r` |
| `combo` | `AttackCombo` | `combo_knight.tres` | `AutoAttackComponent.combo` |
| `passive` | `Passive` | Unbroken (inline) | CH2 |
| `hurt_sound`, `death_sound`, `low_health_sound` | `SoundEvent` | knight hurt, none, knight low health | `Unit.hurt_sound` / `death_sound`, `Player.low_health_sound` (AUDIO.md) |
| `champion_level` | `int` | 1 | new; plain storage, nothing reads it |
| `champion_xp` | `int` | 0 | new; XP toward the next level; plain storage |
| `model_scene` | `PackedScene` | the placeholder KayKit Knight (`art/models/placeholder/kaykit_knight/kaykit_knight.tscn`) | built in 3D pivot P6 (2026-10-03; 3D.md): the champion's rigged 3D model, copied to `Unit.model_scene` at load like the fields above; empty = a placeholder capsule. Champions stay data: a new champion's look is a model file plus this field |

No `growth`: champions don't level their stats (STATS.md, Fill in). Enemies keep per-level growth through `StatsComponent.setup()` (DUNGEONS.md).

Built in CH1: every field except `passive` (CH2), `modifiers` and the three `resource_*` rhythm fields (CH3: they're added with the ResourceComponent fields they map to, so no field sits unused). Export groups: Identity, Stats, Resource, Abilities, Sounds, Champion level.

### Passive (Resource, `res://scripts/data/passive.gd`; inline in the champion's .tres)
From TALENTS T1 (Ryan, 2026-09-30) these fields and methods move to a shared base, `ToolkitBundle` (`res://scripts/data/toolkit_bundle.gd`), that `Passive` and `Talent` both extend; the names below and every .tres stay as they are (TALENTS.md, Data).
| Field | Type | Notes |
|---|---|---|
| `display_name`, `description` | `String` | the tooltip (where it shows is UI.md's) |
| `modifiers` | `Array[StatModifier]` | added under the passive's source id |
| `stat_scalings` | `Array[StatScaling]` | added with `Unit.add_stat_scaling()` |
| `reaction_rules` | `Array[Resource]` (ReactionRule) | unit rules (typed like `StatusEffect.reaction_rules`, to stay out of the preload cycle) |
| `statuses` | `Array[Resource]` (StatusEffect) | applied from the unit itself; a passive's status has `duration` −1 (until removed) |
| `augments` | `Array[Resource]` (AbilityAugment) | added to the AbilityComponent |
Methods: `apply_to(unit, source_id)`, `remove_from(unit, source_id)`; virtual `_on_added(unit, source_id)` / `_on_removed(unit, source_id)` for a subclass script (`res://scripts/abilities/<champion>/<passive>.gd`, next to the kit). Unbroken needs no script.

### StatScaling (Resource, `res://scripts/data/stat_scaling.gd`; inline)
| Field | Type | Notes |
|---|---|---|
| `modifier` | `StatModifier` | the full-strength modifier (its `stat`, `type`, `value`; `scope` allowed; `source_id` ignored: the holder's is used) |
| `input` | `StringName` | `&"self_missing_health"`; since CHAMPIONS K2 also `&"self_status_stacks"` (the holder's stacks of statuses tagged `status_tag` ÷ `max_stacks`, at most 1); an unknown input `push_error`s and counts 0 |
| `curve` | `Curve` | x = the input 0–1, y = the fraction of `value` (0–1); null = linear |
| `status_tag`, `max_stacks` | `StringName`, `int` | K2, for `self_status_stacks` only: the tag counted (`StatusComponent.get_tag_stacks()`) and the count that gives 1 |
`get_value(unit) -> float` = `modifier.value` × curve(input). Since K2 a status can hold StatScalings too (`StatusEffect.stat_scalings`, added under `status_<id>` while it's on), and the unit refreshes them when its statuses change as well as its health.

### ResourceComponent additions (CH3; every default changes nothing)
- `enum ResourceType { MANA, ENERGY, FURY, NONE }` (NONE appended; only ChampionData uses it).
- `starts_empty: bool = false`: `setup()` puts current at 0; a raised max doesn't add to current.
- `decay_per_second: float = 0.0`, `decay_delay: float = 0.0`: out of combat for `decay_delay` seconds, current drops by `decay_per_second` × delta, down to 0. Decay isn't spending, so it never emits `depleted`. A pool uses regen or decay, not both (both work, but nothing designs for it).
- `get_time_since_combat() -> float`, `is_in_combat() -> bool` (hit dealt or taken within `decay_delay`).

### Ability and HitContext additions (CH5)
- `Ability.heal_on_hit_ratio: float = 0.0` (ABILITIES.md, Data).
- `HitContext.heal_on_hit_ratio: float = 0.0` (COMBAT.md, HitContext).
- CH5b: `Ability.heal_missing_health_ratio: float = 0.0`; `HitContext.heal_missing_health_ratio` and `HitContext.cast` (the cast a hit belongs to); `CastContext.missing_health_healed` (set by the first hit that heals).

### Other files
- `res://data/statuses/status_staggered.tres` (+ `res://scenes/vfx/staggered_mark.tscn`, FREE look).
- `res://data/curves/curve_knight_unbroken.tres`, `res://data/curves/curve_knight_cleave_heal.tres`.
- Knight ability .tres changes: Cleave (cost 20, the Staggered bonus, heal ratio and its scaling), Lunge (the Staggered bonus), Judgement (the Fury bonus, cast time 0.75, cooldown 30).

## Architecture / contracts
### Loading a champion (CH1)
- `Player` gets `@export var champion: ChampionData` (null = the scene's own exports, exactly as before). `player.tscn` sets it to `data/champions/knight.tres`; its old exports stay (the same values) until Ryan confirms CH1, then they can be cleared (disable before deleting).
- `Player._ready()`, **before** `super._ready()`: `_apply_champion()` copies `stats`, the four slots, `combo`, the sounds and the resource rhythm onto the nodes (`self.stats`, `abilities.q...`, `attack.combo`, `resource_pool.resource_type` / `starts_empty` / `decay_*`; CH1 copies the type, CH3 adds the rest). Every field is copied as it is, null included: the champion replaces the scene's values, it doesn't merge with them. The children's `_ready()` has already run, but none of them reads these exports there (checked: AbilityComponent and AutoAttackComponent only cache their unit). For NONE, the ResourceComponent node is removed from the Player, queued for freeing and `resource_pool` set to null before `Unit._ready()` wires it. Then `Unit._ready()` sets up stats, health and the pool from the champion's stats as usual.
- `DashComponent.dash_sound` isn't a champion field (it stays on the scene); it moves when a second champion needs its own.
- Code that sets a Player's exports before it enters the tree must set them on the nodes (`get_node("AbilityComponent")`): the `@onready` shortcuts (`abilities`, `attack`) are null until then.
- **After** `super._ready()` (the StatsComponent is set up): the champion's `modifiers` go to StatsComponent under `champion_<id>` (CH3), and the passive attaches (CH2). The hub (later) sets `champion` before the Player enters the tree.
- The champion level fields are never read by the loader.

### The passive (CH2)
- `Passive.apply_to(unit, source_id)`: `stats_component.add_modifiers()` (each a copy with `source_id`), `unit.add_stat_scaling(s, source_id)` for each scaling, `unit.add_reaction_rule(rule, source_id)`, `status_component.apply_status(status, unit)` for each status (its own `duration`, −1 = until removed; its modifiers go under `status_<id>` as usual), `abilities.add_augment(aug, source_id)`, then `_on_added()`. `remove_from()` undoes each by source id (`remove_modifiers_from`, `remove_stat_scalings_from`, `remove_reaction_rules_from`, `remove_status` per status id, `remove_augments_from`), then `_on_removed()`. The same pattern items and SandboxAugments use.
- `Unit.add_stat_scaling(scaling, source_id)` / `remove_stat_scalings_from(source_id)` (mirroring `add_reaction_rule()`): the unit keeps one StatModifier copy per scaling (value `get_value()`, the given source id) in its StatsComponent. On `health_changed` (which also fires when max health changes) it marks the scalings dirty and refreshes them once, deferred to after that physics frame's hits (`call_deferred`): each copy whose value moved is swapped for a new one in a single `StatsComponent.replace_modifiers(old, new)` call (added in CH2: it swaps exact instances, so a passive's plain modifiers under the same source id are untouched, and `stat_changed` fires once per stat, never a dip and a rise). So every hit of one swing or cast sees the same AD, and `stat_changed` fires only when the value moves. Adding or removing a scaling applies at once (not deferred). `Passive.remove_from()` removes the plain modifiers by source id first; the scalings' copies go with them, and `remove_stat_scalings_from()` then only forgets the entries. `StatScaling.read_input()` computes `self_missing_health` itself (1 − health ÷ max health; the same formula as AbilityComponent's named input).
- Unbroken on the F3 overlay (STATS step 7, later) shows as a modifier from `passive_knight`.

### Fury (CH3)
- `HitPipeline.apply_on_hit()` reads `resource_on_hit` with `get_scoped_stat(&"resource_on_hit", get_hit_scopes(ctx))` instead of `get_stat()`, so `hit:` / `target:` scoped modifiers reach it (the same read as `damage_increase`; nothing else changes: no unit had any `resource_on_hit`). The Knight's `champion_knight` modifier (+8, `hit:basic_attack`) makes every enemy a swing hits add 8 × the swing's `proc_coefficient` (1.0).
- `ResourceComponent` connects to `Events.unit_hit` in `_ready()`: a hit that got through whose `source` or `target` is its unit resets `_since_combat` to 0. `_physics_process(delta)` (game time) adds delta to `_since_combat`; regen as before; then, if `decay_per_second` > 0, current > 0 and `_since_combat` ≥ `decay_delay`: current = max(current − decay × delta, 0) and `resource_changed`. As built: the combat clock starts at INF, so a new unit is out of combat until its first hit; a blocked hit never counts. The loader copies the three rhythm fields onto the pool before `Unit._ready()` (so `setup()` starts it empty), then adds `ChampionData.modifiers` as copies under `get_champion_source_id()` (`champion_<id>`) before the passive attaches (`Player._attach_champion()`).
- Costs are the existing `resource_cost` (paid at cast start, refunded on cancel or interrupt, "not enough resource" fails at once and isn't buffered).
- The sandbox's cost demo (`SandboxAbilities.demo_costs`) is turned off in `sandbox.tscn` (its 30 / 40 / 50 / 80 would stack on the real costs and make every slot uncastable at 0 Fury). The demo code stays.
- **HUD implications (notes only; the work belongs to UI.md or its own step):** the bar is red (FURY, since CH3); it starts empty and visibly drains out of combat; a tick mark at the Judgement threshold (60) and a glow while the Knight is at or above it would make the payoff readable; the existing blink on "not enough resource" covers Cleave; R's slot could brighten while the bonus is live.

### Staggered, Cleave, Judgement (CH4)
- All data except two script lines: `judgement.gd` reads `stun_duration` with `get_effect_param(caster, &"stun_duration", ctx, target)`, and consumes the Fury after its hit when `get_active_bonuses(caster, ctx, target)` includes the Fury bonus and the hit landed (`resource_pool.try_spend(resource_pool.current)`).
- Lunge's Staggered rides the hit's statuses (`from_ability()` appends passing bonuses' `target_statuses`), so it's applied after the damage, from the Knight, never to a unit the hit killed, and refused by an untargetable unit (AB10).

### Heal on hit (CH5)
1. `Ability.heal_on_hit_ratio` (export, group "Sustain"). A number `@export` of the Ability base class, so it's a scoped param automatically (`is_base_param()`).
2. Cleave's `.tres`: `heal_on_hit_ratio` 0.55 and a `ChargeScaling` (`param` `heal_on_hit_ratio`, `input` `self_missing_health`, `min_fraction` 0, the curve). `ChargeScaling` already reads any named input (AB12), so no new scaling code.
3. `HitPipeline.from_ability(caster, ability, target, cast)`: with a cast, `ctx.heal_on_hit_ratio = ability.get_effect_param(caster, &"heal_on_hit_ratio", cast, target)` (scoped modifiers, the named-input scaling, conditional bonuses). Without a cast it stays 0 (the old path adds nothing new; every toolkit hit passes its cast).
4. `HitPipeline.apply_on_hit(ctx)`: `heal += ctx.heal_on_hit_ratio × ctx.taken_damage`, next to `life_on_hit` and `life_steal`, so it keeps every on-hit rule (only `basic_attack` / `ability` hits, never `proc` or `dot`, not blocked, the source alive) and goes through `Unit.heal()` with one green number per hit.
5. `self_missing_health` is re-read at the effect start (flow step 10), so a hit taken during Cleave's 0.2 s cast time counts (Ryan, 2026-09-29). This changes when ABILITIES' built-in input is filled, for every ability (ABILITIES.md, Named inputs). One value per cast: every enemy of one Cleave gets the same ratio.
- **CH5b (Ryan, 2026-09-30):** `from_ability()` with a cast also sets `ctx.heal_missing_health_ratio` (`get_effect_param()`, the same scalings) and `ctx.cast`. In `apply_on_hit()`, after the source-alive check: if the ratio > 0, the hit has a cast and `cast.missing_health_healed` is false, it sets the flag and adds ratio × (max health − current) to the same heal as `life_on_hit` / `life_steal` / `heal_on_hit_ratio` (one `Unit.heal()`, one green number). So the first hit of the cast that gets through heals, the rest of that cast don't.

### Readable kit HUD (CH6)
Functional only (Ryan, 2026-09-29): a tester can read their own state during CH-M without being told. No art: placeholder squares and text, as the ability bar has now. The polished HUD and icons stay with the art/VFX pass and UI.md.
- **Already there before CH6** (kept as is): Q/W/E/R hover tooltips (the description with live numbers, cooldown, cost, charges, the conditional bonus lines), the cooldown sweep and seconds left, the red flash on "not ready", grey while a cast condition fails, blue while the cost can't be paid, the resource bar with its current number and its blink, the health number, AD in the top-left info line, the Staggered marker over enemies.
- **The passive slot**: a square the size of an ability slot, left of Q with the same gap (a `PassiveSlot` Control, `res://scripts/ui/passive_slot.gd`, added by `hud.setup_abilities()` only when the player's champion has a passive). It shows the passive's initials in `Passive.icon_color` (a new export, default a neutral grey) and, on hover, a tooltip in the ability tooltip's style: the name, the description, and one "Now:" line per `StatScaling` with its current value from `get_value(unit)` (PERCENT types as a percent: "Now: +18% attack damage"; FLAT as a number).
- **The resource bar's thresholds**: a tick mark at every `RESOURCE_AT_LEAST` value found in the slotted abilities' conditional bonuses and cast conditions (read from the current slot abilities each frame, so a REPLACE variant's own thresholds show), placed at value ÷ max. While the pool is at or above a threshold, the bar gets a bright outline (the "glow"). The Knight: one tick at 60.
- **A live bonus on a slot**: a gold outline on a slot while one of its ability's conditional bonuses passes whose conditions are all about the caster (`SELF_HAS_STATUS`, `SELF_HEALTH_PERCENT`, `RESOURCE_AT_LEAST`; an empty list doesn't count, since it always passes). Bonuses with a target condition (Cleave's Staggered) can't be judged without a target and show nothing on the slot: the Staggered marker covers them. The Knight: R while at 60+ Fury.
- Everything reads existing state every frame (no new signals); nothing here changes gameplay.
- As built (2026-09-30): the passive tooltip opens to the right of the slot (over the ability bar), titled "<name>  [Passive]" with an "Always active" line, the "Now:" lines in gold; the stat name is the registry's `display_name` in lower case; a percent is rounded to a whole number. Unbroken's `icon_color` is a warm orange. Tests read `PassiveSlot.get_tooltip_lines()`, `ResourceBar.get_thresholds()` / `is_glowing()` and `AbilityBar.has_live_bonus()`.


## Audio hooks
See AUDIO.md. Champion sounds (hurt, death, low health) move onto ChampionData in CH1. Fury, Staggered and the heal use existing hooks (the resource bar has no sound; Staggered's apply sound, if any, is a status sound; heals have none) until AUDIO.md adds any.
- *(AUDIO A4: approved 2026-10-04, not built)* A champion's sounds take variants and cues like any other (AUDIO.md, Conditional audio): its hurt, death and low-health sounds on ChampionData, its combo's swings (one sound per combo step, plus `sound_cues` on the swing's progress) and its abilities (cast and hit sounds, `sound_cues` on the cast's progress), its statuses' end sounds by reason (`consume_sound` for an empower used up). A champion's signature state (stacks, an empower) gets its sound by a variant gated on a `Condition`, never by code per sound. The Knight's kit and sounds don't change.

## How each edge case is handled
| Edge case | Handling |
|---|---|
| Staggered runs out between Lunge and Cleave | Cleave's bonus is checked at its hit (AB12), so an expired Staggered gives nothing. The window is wide: a Cleave pressed during Lunge is buffered and fires as Lunge ends, its effect 0.2 s later, leaving about 1.8 s of the 2 s. |
| Cleave hits Staggered and non-Staggered enemies | Checked per enemy: only the Staggered ones get +50%. (The heal doesn't depend on damage since CH5b.) |
| Lunge kills an enemy | No Staggered on the dead (statuses skip a target the hit killed). |
| A free Lunge from the `cleave_casts_lunge` augment | It staggers too (the bonus is on Lunge's .tres). Cleave's own hits resolve first (the free Lunge's hits come after its dash), so that Cleave never gets the bonus from them. |
| Unstoppable or untargetable enemy | Staggered isn't `cc`, so unstoppable doesn't refuse it; untargetable refuses it (statuses from other units, AB10). |
| Cleave's heal on a killing blow | `apply_on_hit()` runs for killing hits, so a killing blow is a hit that heals (once per cast). (Before CH5b the damage-based heal counted overkill, Ryan 2026-09-29; the damage-based field still does.) |
| Healing at max health | A no-op: `Unit.heal()` clamps at max, returns 0 and shows no "+0"; nothing becomes overheal or a shield. At full health there's nothing missing anyway. The heal is once per cast (CH5b), so the other enemies of that Cleave never heal. Tested in CH5 and CH5b (this also tests the existing "heals show no overheal"). |
| Heal from a blocked hit, or while the Knight is dead | None (blocked hits have no on-hit; `apply_on_hit()` stops for a dead source). A blocked first hit doesn't use up the cast's heal: the next hit of that cast that gets through heals. |
| Heal on a shield-absorbed hit | Counts: a hit absorbed by the enemy's shield still got through, so it heals (once per cast). |
| Fury threshold: at cast or at the effect | At the effect (AB8 / AB12): `RESOURCE_AT_LEAST` reads the Fury when Judgement's hit is built, after the channel. It costs nothing, so no cost is taken before the check. |
| Fury drops below 60 during Judgement's channel | No bonus: decay runs only 3 s after the last hit dealt or taken, so a Judgement cast from out of combat can lose it during the channel. The HUD tick (UI.md) makes that readable. |
| Unbroken and Cleave's heal both read missing health | They don't fight: Unbroken refreshes at most once per physics frame, after that frame's hits, so every enemy of one Cleave sees the same AD; the heal's ratio is one value per cast and it heals once. A heal raises health, so Unbroken's AD drops from the next frame. At low health they compound on purpose (more AD and a bigger heal). |
| Max health changes (an item) | `health_changed` fires, so Unbroken re-evaluates; the heal reads the missing health (and its ratio the missing share) from the new max at the next cast. |
| Cleave pressed without 20 Fury | "Not enough resource": the bar blinks, nothing spent, not buffered (AB3). |
| Fury at max | `restore()` does nothing past 100. |
| The passive removed (tests; later a form or talent swap) | `remove_from()` removes every piece by `passive_knight`: AD back exactly. |
| The Knight dies or the room restarts | Today a restart reloads the scene (Fury back to 0). Checkpoint respawns (DUNGEONS.md) *(proposed: Fury resets to 0)*. |
| A champion with resource type NONE | The ResourceComponent is freed at load; no costs, no resource bar (ABILITIES.md). |

## Build order (one step per request)
Every step: the Knight's abilities, enemies chasing and the HUD still work; build logs go in CHANGELOG.md (a Champions section); this doc keeps one line per built step. ABILITIES AB14 (cast progress and presentation hooks) comes first.

1. **CH1 – ChampionData and the Knight's migration.** `champion_data.gd` (every field except `passive`, `modifiers` and the `resource_*` rhythm fields), `ResourceType.NONE`, `data/champions/knight.tres` pointing at the existing files, `Player.champion` and `_apply_champion()`, `player.tscn` set to it, the champion sounds, `champion_level` / `champion_xp`; `res://scenes/tests/champions_test.tscn` + `scripts/tests/champions_test.gd`. Built 2026-09-29, see CHANGELOG.md.
   **Done means:** the game plays exactly as before (the same numbers, slots, combo, sounds); a Player with `champion` null uses its exports; the champions test checks the loaded values against the .tres and that NONE removes the pool; every existing test passes unchanged.
2. **CH2 – The passive framework and Unbroken.** `passive.gd`, `stat_scaling.gd`, `ChampionData.passive`, `Unit.add_stat_scaling()` / `remove_stat_scalings_from()`, the attach after `super._ready()`, Unbroken inline in the Knight's .tres, `curve_knight_unbroken.tres`. Built 2026-09-29, see CHANGELOG.md.
   **Done means:** the Knight's AD is 64 at full health, about 82 at 50%, 90 at 30% and below, following health both ways (damage and a heal); every enemy of one swing or Cleave sees the same AD; removing the passive restores every stat exactly; a test passive with a modifier, a rule, a status and an augment attaches and detaches cleanly.
3. **CH3 – Fury.** `ResourceComponent` (`starts_empty`, decay, combat time), the scoped `resource_on_hit` read in `apply_on_hit()`, `ChampionData.modifiers` and the `resource_*` rhythm fields, the Knight's ChampionData to FURY (and its rhythm), `units/knight.tres` (max 100, regen 0), Cleave's cost 20, `demo_costs` off in `sandbox.tscn`; the stats, abilities and combat tests that pinned 300 mana read the new data instead (DECISIONS, Testing). Built 2026-09-29, see CHANGELOG.md.
   **Done means:** the bar starts empty; each enemy a swing hits adds 8, ability hits add nothing; 3 s after the last hit dealt or taken it drains at 20/s; Cleave below 20 Fury fails with the bar's blink; Lunge, Iron Resolve and Judgement cast from 0.
4. **CH4 – Staggered, the combo and Judgement's payoff.** `status_staggered.tres` and its marker, Lunge's and Cleave's bonuses, Judgement's Fury bonus, its 0.75 s channel and 30 s cooldown, `judgement.gd` (`stun_duration` through `get_effect_param()`; the Fury consumption if approved). Built 2026-09-29, see CHANGELOG.md.
   **Done means:** enemies Lunge cuts through show the marker for 2 s; Cleave hits them for +50% (and others normally); Judgement at 60+ Fury stuns 1.25 s and hits 30% harder (and empties the bar), below 60 it's the plain 0.75 s; tooltips list the bonus lines.
5. **CH5 – Cleave's heal on hit.** `Ability.heal_on_hit_ratio`, `HitContext.heal_on_hit_ratio`, `from_ability()` and `apply_on_hit()`, Cleave's ratio and scaling, `curve_knight_cleave_heal.tres`, the effect-start `self_missing_health` read. Built 2026-09-29, see CHANGELOG.md.
   **Done means:** at full health Cleave heals nothing; at 50% about 8% of its damage per enemy; at 10% about 55%; three enemies heal three times; a killing blow heals; at max health nothing is healed or shown; the heal works with Unbroken without order effects; no other ability heals.
   **CH5b – Cleave's heal from missing health** (Ryan, 2026-09-30). `Ability.heal_missing_health_ratio`, `HitContext.heal_missing_health_ratio` and `.cast`, `CastContext.missing_health_healed`, the once-per-cast heal in `apply_on_hit()`; Cleave and Cleave Wave move their 0.55 and its scaling to the new field (the curve unchanged), their tooltips say "of your missing health". Built 2026-09-30, see CHANGELOG.md.
   **Done means:** one Cleave that hits heals what the curve gives (at first 0 / 26 / 73 / 322 at 100 / 50 / 25 / 10% health), the same into one enemy or three; nothing into the air, through a blocked hit or at max health; a killing blow heals; a hit taken during the cast time counts; the damage-based field still works on a test copy.
6. **CH6 – Readable kit (functional HUD).** `passive_slot.gd` and `Passive.icon_color`, the passive slot in `hud.setup_abilities()`, the resource bar's threshold ticks and glow (`resource_bar.gd`), the live-bonus outline on ability slots (`ability_bar.gd`); HUD checks in the champions test (Architecture, Readable kit HUD). Added at Ryan's request (2026-09-29) so testers can read their own state during CH-M. Built 2026-09-30, see CHANGELOG.md.
   **Done means:** hovering the passive slot shows Unbroken's name, description and its current bonus, which follows health; the Fury bar has a tick at 60 and glows at 60+; R has a gold outline at 60+ Fury and loses it below; with no champion (or no passive, or no thresholds) the HUD is exactly as before; no art.

**Milestone CH-M – the Knight's kit** (after CH6): Passed 2026-09-30 (Ryan's play test; CHANGELOG.md). a play test in the sandbox of the whole loop: build Fury with swings, Lunge through a pack, Cleave the Staggered enemies, Judgement an elite at 60+ Fury, and survive a low-health fight on Cleave's heal.
**Done means:** Ryan's play test: the kit reads at a glance and the numbers feel right (then they stop being placeholders).

### Korsavil (K1–K6, K-M; *(proposed)* steps, Open questions, Korsavil 17)
Placed right after Ryan's play test of ENEMIES_AI AI3d, before AI3b and AI3c (Ryan, 2026-10-04). K1 and K2 passed; then Ryan started ENEMIES_AI AI3b first (2026-10-05), so K3–K6 wait (Claude's proposed order: after AI3c and AI-D1–AI-D3; ENEMIES_AI.md, Build order; Ryan to confirm). **The order since 2026-10-07** (Ryan; ARCHETYPES.md, Build order, The order of work): AI-D3's play test, ARCHETYPES AR1–AR3, then AR4–AR6 (her Assassin layer is AR5, below), then K3–K6 and K-M, then AR7–AR8. Every step: Ryan runs `git status` first; with the Knight picked the game plays exactly as before (his abilities, talents, enemies chasing, the HUD); every suite green; build logs in CHANGELOG.md (the Champions section); this doc keeps one line per built step. Her checks join `champions_test`, the toolkit pieces' checks `abilities_test` and `combat_test`, and K6's `enemies_test`.

1. **K1 – Data, loading, her 3-swing cycle and the champion pick.** `data/units/korsavil.tres` (the placeholders), `data/champions/korsavil.tres` (ENERGY and its rhythm; the passive with the `dash_charges` +1 only), `combo_korsavil.tres` (3 swings and the dash-strike), `AttackSwing.hit_tags` (built here: `finisher` on swing 3; COMBAT.md), her `ChampionLeveling` *(proposed: the Knight's curve)*, empty Q/W/E/R slots (her abilities come in K2–K5); a functional champion pick at the hub (the Knight or Korsavil; its talent screen and inventory follow the pick; Start run and Sandbox start as it; kept for the session, saved later with PROGRESSION.md *(proposed)*; UI.md polishes it).
   **Done means:** at the hub you pick either; as Korsavil you walk at 390 u, swing the 3-swing cycle (swing 3 tagged `finisher`), dash twice, have 500 health and a full yellow bar regenerating at 10 a second; her empty slots, empty talent screen and own inventory cause no errors; with the Knight picked nothing changes.
   Built 2026-10-04 and passed Ryan's play test the same day, see CHANGELOG.md. Her swings use the Knight's swing sounds as placeholders.
   Note (2026-10-07): the passive's +1 `dash_charges` and her second dash go in ARCHETYPES AR5, replaced by the Assassin's one longer dash (D11).
2. **K2 – Q Bladesinger, Blades and Inevitable Demise.** `status_blade`, `status_bladesinger`; the StatScaling input `self_status_stacks`, `StatusEffect.stat_scalings` and the refresh on status changes; `bladesinger.gd` and `korsavil_q_bladesinger.tres` (the `blades` input, the "No Blades" recast condition); `status_inevitable_demise` with `STACK_SHARED` and `tick_by_stacks`; `status_umbral_stalker` applied on 4 hits (its REPLACE comes in K5).
   **Done means:** the orbit gives a Blade a second up to 4, and damage taken and speed follow the count (5% per Blade) only while it lasts; the recast sends every Blade at 80–110% AD each and fails at 0 Blades; Blades stay after the orbit; each Blade that hits adds a Demise stack, dealing 0 / 5 / 5 / 8 / 8 / 10 / 10 / 12% AD per 5 s at 1–8 stacks on one shared 5 s timer that each Blade restarts; 4 hits give Umbral Stalker for 10 s.
   Built 2026-10-04 and passed Ryan's play test 2026-10-05, see CHANGELOG.md. Demise's ticks are under 1, so their numbers carry until they reach 1 (COMBAT.md, Damage numbers; the K2 fix).

**Before K3: ARCHETYPES AR5, her Assassin layer** (Ryan, 2026-10-07; specified, built and logged as ARCHETYPES.md's step, with its own done-means and tests). Her one dash from the archetype (500 u, recharging in 1.2 s, tuned 0.8–1.5), the 0.2 s deflect window, the refund, the jab and its 1.5 m snap, the banked streak's 10 s expiry, the riposte's health share and its 6 m projectile snap, +10 Energy on a deflect, her poise meter, its HUD bar and her break; her passive's +1 `dash_charges` removed. AR4 (weak basic attacks, hers and the Knight's) comes just before it, AR6 (the Knight's test deflect disabled, with Ryan's OK) just after. This doc gets one line when it passes.

3. **K3 – E Blade Dance and the detonation.** The bounce projectile (`projectile_bounces`, `bounce_range`, the `bounce` input, a per-hit callback), `blade_dance.gd`, `korsavil_e_blade_dance.tres`; `status_demise_detonation`, `status_detonation_haste` and the two detonation rules in her passive.
   **Done means:** the knife hits up to 4 enemies at 30 / 35 / 40 / 45% AD, never one twice, and stops with no next enemy; each hit gives a Blade and a Demise stack; a finisher on an 8-stack enemy swaps the stacks for 25% AD over 5 s and gives her +10% speed for 5 s; a killing finisher detonates nothing.
4. **K4 – W Vanish and the 4-swing cycle.** `ends_on_cast` / `ends_on_swing` / `ends_on_dash`, `empower_uses`, `empower_damage_type`, `combo_override` (picked at a chain's start); `status_vanish` (and `status_stealth.tres`, if ALLIES AL1 hasn't made it), `empower_vanish`, `empower_vanish_full`, `combo_korsavil_vanish.tres`, `vanish.gd`, `korsavil_w_vanish.tres`.
   **Done means:** enemies drop her (today's pick); a cast, a swing or a dash ends it, its own cast doesn't; under 4 s, her next 3 swings that hit get +10% AD; 4 s or more (a full 5 s included), +15% AD and the whole swing TRUE; the third gives 2 Blades; her next chain is the 4-swing cycle and reaches its finisher; 25 energy a second while hidden.
5. **K5 – R Spectral and Umbral Stalker.** `Ability.recast_targeting`, `spectral.gd`, `spectral_stalker.gd`, `korsavil_r_spectral.tres`, `korsavil_r_spectral_stalker.tres`, `augment_spectral_stalker` on `status_umbral_stalker`, the "higher of" heals. The Stalker's recast hits without fearing until K6.
   **Done means:** R blinks behind its target and strikes for 60% then 100% AD; within 3 s, and only after a landed strike, the recast pressed anywhere blinks her back, heals max(5% max health, 100) and gives 2 Blades; a rooted press fails with "Rooted"; with Stalker the slot shows the variant: three strikes, a recast that blinks to the aim, hits the half circle for 120% AD and heals max(10% max health, 150) + 5% AD; Stalker goes at the first strike, and its recast survives the REPLACE ending.
6. **K6 – Fear and the search** (COMBAT.md, Status effects, Fear; ENEMIES_AI.md, Fear and Losing a stealthed target). `status_fear`, `refused_by_tags`, the bosses' `boss` status from `RankRules`, the brain's rest and the flee, the search (`search_time`), the Stalker's recast applying fear.
   **Done means:** ENEMIES_AI's fear and search tests pass (a feared brute walks away for 1.5 s without attacking or casting, an elite 1.2 s, a boss and an unstoppable enemy refuse it; an enemy whose target turns stealthed searches its last known spot for 3 s, then goes home, and comes back if her stealth ends in its sight).

**Milestone K-M – Korsavil's kit** (after K6): Ryan's play test in the sandbox against the test enemies and packs: build Blades with Q and E, spend them, detonate an elite, Vanish out and come back in with the 4-swing cycle, R in and out, the Stalker's fear; the balance flags (Open questions, Korsavil) reviewed.
**Done means:** Ryan's play test: the kit reads at a glance and the numbers feel right (then they stop being placeholders).

## Out of scope
The leveling curve, XP sources and talent points (TALENTS.md); saving the champion level (PROGRESSION.md); the hub and champion select (UI.md, NPCS.md); weapons and champion-specific items (LOOT.md); the ultimate meter (here, when a champion uses one); champions other than the Knight and Korsavil; the polished HUD and icons (UI.md and the art pass; CH6 is functional only); voice lines (AUDIO.md).

## Open questions
Claude's proposals from the approved plan (written in above as *(proposed)*; Ryan can overrule any):
1. ~~`champion_class` as the field name~~: answered, yes (Ryan, 2026-09-29).
2. ~~Unbroken: AD only, or armor too~~: answered, AD only (Ryan, 2026-09-29).
3. ~~Fury per enemy hit or per swing; taking damage~~: answered: +8 per enemy a basic attack hits, and taking damage builds nothing (Ryan, 2026-09-29).
4. ~~Does the empowered Judgement consume all Fury~~: answered, yes (Ryan, 2026-09-29).
5. ~~Cleave's heal on overkill~~: answered, the full `taken_damage`, like `life_steal` (Ryan, 2026-09-29).
6. ~~Re-read `self_missing_health` at the effect start~~: answered, yes (Ryan, 2026-09-29).
7. ~~Does Cleave consume Staggered~~: answered, no (Ryan, 2026-09-29).
8. ~~Cleave Wave: no heal and no Staggered bonus, or the same as Cleave~~: answered, the same as Cleave (Ryan, 2026-09-29).
9. ~~Champion level kept in memory~~: answered, yes; saving it is PROGRESSION's (Ryan, 2026-09-29).
10. ~~The Knight's role tags kept, no Knight ability ignores walls~~: answered, yes to both (Ryan, 2026-09-29).

Still open:
- The ultimate meter (Hades-style), when a champion first uses one.
- Fury on checkpoint respawn (DUNGEONS.md; proposed: reset to 0). DUNGEONS.md (2026-10-03) carries the same proposal for a respawn and for a rest at a checkpoint.
- ~~Other resource types' rhythms (energy, mana) with their first champion.~~ Energy answered with Korsavil (Ryan, 2026-10-04): max 100, regen 10/s, starts full, no decay (Korsavil, Energy). Mana still comes with its first champion.
- Unbroken's final name.

Raised by VISION.md's 2026-10-02 update (nothing proposed yet):
- **Champion unlocking:** how many champions at launch, and how a champion gets unlocked (VISION.md, Open question 3). The hub shows only the Knight today.
- **Bio:** where a champion's background and lore live (ChampionData, the codex) and where the player reads it (the hub's champion pick, the codex). With NARRATIVE.md.
- **Voice lines:** which events get one, how often, and whether a champion has lines in story scenes; out of scope here today (AUDIO.md, NARRATIVE.md).
- **The story lens:** each dungeon's story has shared core beats plus a champion lens (VISION.md, Pillar 5). What a champion's lens needs from its data (lines, codex entries, scene variants) is set by NARRATIVE.md. DUNGEONS.md (2026-10-03) fixes its scope: the same layout, enemies and main quests for all; per-champion codex entries, NPC dialogue and some scenes; one quest line per champion per wing (Dungeon content per champion).
- **The champion quest line's "one-of-a-kind named reward"** (DUNGEONS.md, Also open; not the Unique rarity): one of this champion's named items, or a named cosmetic or title?

Korsavil (designed 2026-10-04; Claude's proposals, written in above and in ABILITIES.md, Korsavil, as *(proposed)*; Ryan can overrule any):
1. **The draft's ranges and widths read as metres:** Q's Blades fly 6 m (600 u, 192 px) in a 90° spread (`projectile_spread_deg` 30 between neighbors, so fewer Blades fly closer together), E's throw 6 m, R 11 m (1100 u, 352 px). Also: Q's Blades and E's knife at 1,500 u/s (480 px/s), the toolkit's 60 u width.
2. ~~**Demise's stack lifetime:** 5 s on one timer every stack shares, restarted by each new Blade (a new stack rule, `STACK_SHARED`)~~; ~~odd counts use the tier below (1 stack deals nothing); the tiers through a stack table on the DoT~~: approved (Ryan, 2026-10-04). Still open: a tick every 0.5 s; Demise and the detonation deal PHYSICAL damage; Demise isn't `cc`.
3. **The third empowered attack gives 2 Blades** after a short Vanish as well as a full one. Also: the empower lasts 5 s, and the swing that breaks Vanish is its first use.
4. ~~**TRUE damage on a basic attack:** the bonus as its own TRUE hit~~: answered (Ryan, 2026-10-04): **the whole empowered swing deals TRUE damage**, the swing and its bonus, on each of the 3 empowered swings after a full Vanish (`empower_damage_type` TRUE sets the hit's type). Still open, the reading: "+10% / +15% AD" as bonus damage on the swing (`empower_ad_ratio` 0.10 / 0.15), not +10% to her attack damage stat.
5. **E's bounce count, step and targeting:** ~~"up to 4 bounces" read as 4 hits in all (the first and 3 bounces) at 30 / 35 / 40 / 45% AD, so one full E fills her 4 Blades; every hit gives a Blade and a Demise stack, the first included~~: approved (Ryan, 2026-10-04). Still open: DIRECTION, 6 m; the next bounce goes to the nearest enemy in sight of the one just hit, not hit yet, within 4 m (400 u, 128 px), homing (so it can't be dodged); a bounce whose target dies or turns untargetable ends the knife.
6. **R's heals and recast window:** max(5% max health, 100); the Stalker's read as max(10% max health, 150) + 5% AD on top (the AD part is small: 3 at 64 AD, the Knight's); the window 3 s (the default). Also: she lands just behind the target; 0.15 s between strikes; a recast whose blink a root refuses at its effect still heals and gives its Blades where she stands (as Judgement Leap's landing hits where a refused leap leaves it); the Stalker's recast needs a landed strike too (LAST_PART_HIT, so its heal is earned: Principles 4), blinks to the aim point within 11 m and hits a half circle of 3 m (300 u, 96 px) in front of her along the blink's direction, fearing every enemy it hits; the Stalker's recast gives no Blades (Ryan gave them to the base R's).
7. ~~**The Stalker timing:** Stalker is consumed at the variant's first part's effect start; the recast window that part opens stays the variant's (an open recast sequence keeps the ability that opened it), and the slot shows the base R again when it ends~~: approved (Ryan, 2026-10-04).
8. **Still Ryan's to decide:** ~~the class word~~ (answered: `assassin`, in CONVENTIONS since 2026-10-04), ~~her combo~~ (answered 2026-10-04: two melee cycles, 3 swings and 4 from Vanish, each ending in a finisher; Combo: two cycles), ~~base stats~~ (answered 2026-10-04: Claude's placeholders, health 500), the passive's name, her fantasy line, the R's name ("Spectral" is a placeholder: the draft's name is cut off).
9. **The search's length** (ENEMIES_AI.md's, not built): 3 s of looking around her last known spot.
10. **Q:** role `core`, W role `defensive` (W also tagged `buff`); the orbit ends with the recast (the orbit is the recast window); the recast needs at least 1 Blade (`recast_conditions` SELF_HAS_STATUS `blade` min 1, fail text "No Blades"); "all 4 hit" counts Blades whose hits got through, on any enemies; each Blade deals the step (80–110% AD), so four Blades into one enemy deal 440% AD (the other reading: the step is the volley's total); PHYSICAL.
11. **Movement during casts:** Q and W don't root (she walks at full speed), E walks at 0.6 and a dash cancels it, R roots for its 0.25 s.
12. **What ends Vanish, and when:** a cast at its start (`cast_started`), a swing at its start, a dash at its start; a free cast and taking damage don't; the cast that applied it never does.
13. ~~**The second dash in the passive** (FLAT +1 `dash_charges` under `passive_korsavil`), not 2 on her UnitStats: she loads with one charge and gets the second 0.35 s later.~~ (superseded 2026-10-07: ARCHETYPES.md, Assassin; D11: one dash, the archetype's.)
14. **The detonation:** two unit rules (HIT on the `finisher` tag with TARGET_HAS_STATUS at least 8, then STATUS_APPLIED for the speed); a killing finisher detonates nothing and gives no speed; the speed keeps its own 5 s (REFRESH, never +20%) even if the enemy dies first, and adds to Q's before the soft caps.
15. **Names:** the statuses `status_bladesinger`, `status_demise_detonation`, `status_detonation_haste`, `empower_vanish` / `empower_vanish_full`; `augment_spectral_stalker`; the ability ids and files and the scripts in `scripts/abilities/korsavil/` (ABILITIES.md, Korsavil); the rules `reaction_korsavil_detonation` and `reaction_korsavil_detonation_haste`; the named inputs `blades` and `bounce`; the tags `blade`, `inevitable_demise`, `bladesinger`, `demise_detonation`, `fear` and the hit tag `finisher`; the toolkit fields (ABILITIES.md, Later toolkit pieces).
16. **Her two cycles' details** (Combo: two cycles): ~~a cycle picked at a chain's first swing and run to its end even if Vanish's state ends inside it (so the 4-swing cycle's finisher still comes after the empower's 3 uses); Vanish restarting the chain at the 4-swing cycle's swing 1~~ (approved, Ryan, 2026-10-04); still open: the swing numbers (about 0.76 s and 0.92 s per cycle, 0.2 s breathers, reach 150 u); one dash-strike for both at 1.3 × AD; the two combos as `combo_korsavil.tres` and `combo_korsavil_vanish.tres`, swapped by a status's `combo_override`.
17. **Her build steps** (Build order, Korsavil): K1–K6 and the milestone K-M, their names, order and contents.
18. **The jab or the riposte and Vanish's empowers on one swing** (ARCHETYPES.md, Assassin; Claude's reading, to confirm): they add, as empowers do (a swing reads every basic attack empower on her: ABILITIES.md, Empowers). A riposte swing that also uses an `empower_vanish_full` use gets +3.0 AD ratio, the 12% health share and +15% AD, and since `empower_damage_type` sets the whole hit's type, the riposte's part deals TRUE damage too.
19. **Her poise meter's HUD bar** (ARCHETYPES.md, View; *(proposed)*): a thin bar under her health bar, functional like CH6's HUD: gold filling toward the break, orange while broken, grey while immune. UI.md polishes it.

Balance flags (recorded, not changed; Ryan's call):
- The full 8-stack payoff (25% AD over 5 s) and Demise's top tier (12% AD over 5 s at 8 stacks) are smaller than one E (30% AD, +5% per bounce).
- W costs 45 but returns up to 75 energy (15 a second for 5 s), so a held Vanish is energy-positive.
- The flat heals (100 and 150) are about 20% and 30% of 500 health; the percent side only wins above 2,000 / 1,500 max health.
- W's 12 s cooldown and E's 0.5 s cast time sit outside ABILITIES' 3–10 s and 0.15–0.3 s guides (guides, not rules).
