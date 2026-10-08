# ENEMIES_AI.md: Enemy Brains, Roles, Groups, Dodging, Tells, Elites, Bosses and the Tuning Toolkit
<!-- Written 2026-10-03 from Ryan's decisions (his interview with the advisor, the same day). AI1–AI3 built and passed 2026-10-04 (CHANGELOG.md); the rest is a plan. Duels and odds (Ryan's design addition, 2026-10-04, docs only) added as AI3b–AI3d; AI3d built 2026-10-04, AI3b 2026-10-05, AI3c 2026-10-05 (passed the same day). Combos, crowd control and the test duelist (Ryan's design addition, 2026-10-05, docs only) added as AI-D1–AI-D4; AI-D1 built 2026-10-06, AI-D2 2026-10-07 (both passed 2026-10-07), AI-D3 2026-10-07. -->

**Read when:** the task involves how enemies decide (the brain, the situation, intents, respect, patience), enemy roles and ranks (fodder, brute, skirmisher, caster; regular, elite, boss), what an enemy ability is for (its AI uses), what enemies know about the party, attack tokens, packs (alert, leash), losing a stealthed target (the search), fear (fleeing), enemy dodging, enemy tells (poses), elite modifiers, the boss director (phases, pressure and breather, punish, finish, reset), spawning (packs, ambushes, spawn-in), how factions and difficulty tiers scale brains, where enemy data lives (`EnemyData`, the roster: XP, kill tags, drops), the AI's performance (think rate, sleeping), the AI tuning toolkit (sliders, the brain overlay, the live tuning panel, the scenario spawner), or combos (combo plans, peel and setup, crowding and the opening, the follow-through, crowd control's diminishing returns, the combo budget, the test duelist).
**Depends on:** CLAUDE.md, VISION.md (Pillar 1, decision priorities, Open question 7), CONVENTIONS.md, ABILITIES.md (AbilityComponent and the cast flow, `Condition`, `get_ai_vector()`, telegraphs, cast progress, untargetable), COMBAT.md (damage bands, telegraph rules, hit forgiveness, statuses, CC and tenacity), ALLIES.md (`UnitController`, the target-pick rules, `threat`, taunt, stealth, `get_ai_plan()` and `CastPlan`, party scaling), DUNGEONS.md (rosters on shared behaviors, packs and arenas, content slots, difficulty tiers and elite modifier counts, bosses and their reset), 3D.md (views and `UnitView`, perches and `can_reach()`, ledges and navmesh islands, the sleep distance and the P-spike), WORLD_INTERACTION.md (WorldQuery, Hazards, kill credit), COMPANIONS.md (enemies never see companions; drops), TALENTS.md (kill counters and XP; the kind-not-magnitude rule), LOOT.md (drop tables), MOVEMENT.md (MovementComponent, soft caps), STATS.md, AUDIO.md (hooks).
**Used by:** ALLIES (the shared perception, the controller base, `CastPlan`, the target pick; the ally brain reuses the toolkit), DUNGEONS (the roster format, faction presets, spawn kinds, elite modifiers, difficulty tier hooks, the boss reset), COMBAT and ABILITIES (intent tags, use rules, enemy telegraph and dodge rules), TALENTS, LOOT and COMPANIONS (enemy XP, kill tags, drop tables and kindling move onto `EnemyData`), 3D (pose hooks, the perched sniper), UI (the boss bar, elite modifier names), AUDIO (hooks), NARRATIVE (bestiary entries by kill tag).
**Status:** written 2026-10-03. Ryan's decisions (his interview with the advisor, 2026-10-03) are MUST, recorded in DECISIONS.md (Enemies). **The interview is done:** Ryan answered all eleven open items (I1–I11) in three rounds the same day, each as Claude proposed; his answers are MUST, marked I1–I11 in the sections below and listed under Open questions, Interview. Items still marked *(proposed)* are Claude's picks Ryan hasn't answered; each is also in Open questions. **AI1 built and passed 2026-10-04** (see CHANGELOG.md; Ryan started it before ALLIES' second champion, and approved its names). **AI2 built and passed 2026-10-04.** **AI3 built and passed 2026-10-04.** **AI3d built and passed 2026-10-04** (before AI3b and AI3c, Ryan's call). **AI3b built and passed 2026-10-05** (before Korsavil's K3, Ryan's call). **AI3c built and passed 2026-10-05** (right after AI3b and a warnings cleanup, Ryan's call). **AI-D1 built 2026-10-06, passed 2026-10-07** (right after AI3c, Ryan's call), then the duelist's tuning pass (passed 2026-10-07). **AI-D2 built and passed 2026-10-07.** **AI-D3 built and passed 2026-10-07** (diminishing returns on crowd control). AI4–AI8 and AI-M aren't started. **Korsavil** (CHAMPIONS.md) is built right after AI3d's play test, before AI3b and AI3c (Ryan, 2026-10-04); her step K6 builds this doc's fear and search. ALLIES.md calls this doc's first steps "Tier B": they are AI1 and AI2 here. **Duels and odds** (Ryan's design addition, 2026-10-04, docs only): smarter single enemies, since most fights are one or two champions against at most 5–7 enemies: confidence, spending the key ability, the crowded response, smell blood, odds, think rates by rank, five more sliders, kit sizes and the enemy ability library, boss passives (Kits; Duels and odds; build steps AI3b–AI3d). Ryan answered its questions the same day in three rounds (Open questions, Open from Duels and odds). **Combos, crowd control and the test duelist** (Ryan's design addition, 2026-10-05, docs only): a test duelist with a real kit (one crowd control, one defensive, two damage), its crowd control used to peel or to set up, combo plans with any opener, the follow-through after a plan, diminishing returns on crowd control (no combo budget: cooldowns are the limit), the ally on the same planner, and enemies being combo'd (Combos, crowd control and the test duelist; build steps AI-D1–AI-D4, after AI3c). Ryan answered its questions the same day in four short rounds (Open questions, Open from Combos).

## How to read this doc
Same as ALLIES.md: MUST (never change without asking Ryan), TARGET (start value and allowed range), FREE (your call; tiebreaker: VISION.md's decision priorities). Every number is a TARGET placeholder until the play tests; the performance budget is measured in AI1, never guessed. Enemy names in examples (a brute, a thrall caster) are illustrations, not launch content.

## Player experience
You come into a crypt hall at difficulty tier 1. Three thralls shuffle at you and chip away; you cut them down. Behind them a brute steps forward and stops just outside your reach, circling, because your Lunge and Judgement are both up. You Lunge into a thrall to clear it. The brute sees Lunge go on cooldown, crouches low and leans in, and charges; you dash its slam and punish it. At the back a caster throws bolts the whole time. When you close in it blinks away; the next time its blink is down, so it stops, squares up and slaps at you, weak and slow. You caught it. Only two of the hall's bigger enemies ever swing at you at once; the rest circle and wait their turn. In the side room an elite sidesteps your Cleave Wave a beat after you throw it; you throw another to bait the dodge, then Judgement it while its dodge is down (a point-and-click ultimate can't be sidestepped). At the end of the wing the boss presses you for a while, then backs off and lobs slow orbs: your moment to heal and set up. You whiff your Judgement, its arm draws back, and it lunges across the arena at you; you dash it. Below a third of your health it goes for the kill with a huge, slow slam; you dash through it and win. Every time it beat you, you saw why.

## References
- **League of Legends.** Take: respecting cooldowns (you don't walk into a full-kit enemy; you go in when its key abilities are down); baiting (spending a cheap ability to draw a commit); spacing at the edge of a threat range; point-and-click abilities that can't be sidestepped and skillshots that can; jungle camps that walk home and heal when pulled too far. Don't take: perfect reactions, last-hitting.
- **Diablo III and IV.** Take: packs that wake together; elites with rolled modifiers that change how a fight plays (teleporter, shielding, vampiric, volatile on death); fodder that swarms and chips; a roster per region. Don't take: stat-check elites with nothing to read.
- **Hades.** Take: every enemy attack readable from its body before its telegraph; bosses with phases and a tempo you learn; a dash that always answers. Don't take: bullet-hell density.
- **Doom (2016) and the Batman Arkham games.** Take: attack tokens: only a few enemies may attack at once, the rest posture, so a crowd stays readable. Don't take: enemies that politely wait forever.
- **Dark Souls and Elden Ring bosses.** Take: punishing a whiffed big attack. Don't take: input reading (reacting to the key press itself): enemies here react only to what shows on screen, after a reaction time.

## Principles
1. **Enemies exist to test the player** (Ryan). Fights are tactical and methodical, like League: you can't run up and face-tank while spamming abilities. Enemies read your cooldowns, keep their spacing, defend against what's coming, dodge what can be dodged and punish mistakes (VISION.md, Pillar 1).
2. **Readable and beatable.** Every smart decision shows on the enemy's body before it acts (Tells), and every one has an answer: baiting, CC, walls, wide areas, timing. "No unanswerable enemy" stays a design check (3D.md, Terrain and height 3; decision priorities 2 and 3).
3. **Fair knowledge.** Enemies know what your HUD shows and what's on screen, nothing else: no gear, no hidden stats, no input reading. Companions are invisible to them.
4. **One pipeline, one condition system, one controller contract.** Enemies act through AbilityComponent, AutoAttackComponent and MovementComponent, gate their abilities with the shared `Condition`, and drive their unit as a `UnitController` (ALLIES.md). Abilities propose (`get_ai_plan()`), brains decide (ALLIES' rule). No second copy of any of them.
5. **The decision is a pure function** of a `SituationContext` and a seeded random number generator, so every behavior is tested headlessly.
6. **Kind, not magnitude** (TALENTS.md's authoring rule, applied to enemies): an enemy's identity comes from its role, its abilities and what they're for, and its twist, never from small slider differences. Archetype presets carry the sliders; an enemy overrides only a few.
7. **The ladder is the budget.** Fodder has no brain; brains think about 10 times a second, staggered; one shared read of the party per tick; far enemies sleep. The budget is measured (AI1), never guessed.
8. **Fights never stall.** Patience always fills; every enemy comes eventually.
9. **Tuning is where the time goes**, so the toolkit (sliders, the brain overlay, live tuning, scenarios) is built first (AI1), and every tunable is an `@export` in a .tres.
10. **Few enemies, each one smart** (Ryan, 2026-10-04). Most fights are one or two champions (the player and the ally) against rarely more than 5–7 enemies, so each enemy's decisions are the whole fight. It reads its own kit as well as yours (confidence), answers you in its face, smells blood, and presses when the odds are on its side, always inside the fairness limits: tokens, telegraphs, one heavy hit at a time (Duels and odds).
11. **Combos read and have answers** (Ryan, 2026-10-05). An enemy with a real kit chains its abilities by plan: any opener, its crowd control only one option. It uses that crowd control to make space or to set up, and after a combo decides whether to reset or stay on you. Every chain opens with a telegraphed, dodgeable opener. Its cooldowns are its only limit (Ryan: "if their abilities are off cool down they can use it whenever they please"), and diminishing returns keep crowd control from chaining forever (Combos, crowd control and the test duelist).

## Current code
- `Enemy` (`res://scripts/enemies/enemy.gd`, extends `Unit`; team ENEMY, group `enemies`): a three-state machine (`AI.IDLE`, `WANDER`, `AGGRO`) in `_physics_process`. IDLE waits 0.8–2 s and WANDER walks up to `wander_distance` (60 px) from `_home`; both switch to AGGRO when `_can_see_player()` passes (the first node in the group `player`, targetable, within `detect_range` 450 u edge to edge, and the `Sight` RayCast2D, mask 1, clear). A hit from the player aggroes it too (`_on_damaged`). In AGGRO: past `leash_range` (800 u from the player, edge distance) it stops where it stands and goes IDLE (no walk home, no heal); an untargetable player is chased without attacking (`_chase_untargetable()`, ABILITIES AB10); otherwise `_try_cast_ability()`, then `attack.attack(_player)`. `passive` makes a training dummy. Its random numbers come from the global `randf()`, unseeded.
- **The naive cast loop** (`_try_cast_ability()`; COMBAT C5, ABILITIES AB12 and AB13): every tick in AGGRO it walks slots q, w, e, r and casts the first ready ability (`get_fail_reason()` empty, after `set_aim_hint()` at the player) whose `cast_range` reaches the player's center, with the player in sight, at the player's position (`get_ai_vector()` for a VECTOR ability). Never mid-windup. **This is what the brain replaces** (DECISIONS.md, Combat, C5: "ENEMIES_AI.md replaces it").
- `AutoAttackComponent` in LoL mode (enemies): chases a target, winds up with a move lock, hits through `HitPipeline` (tagged `basic_attack`, not `melee`), `enemy_hit_forgiveness` 0.10 (reach × 0.9), a whiff if the target left reach by the hit, a push. League-style attacks have no presentation hooks yet (COMBAT.md, AttackSwing).
- `MovementComponent.move_to()` (NavigationServer2D pathing and steering), `displace()`, `dash()`; slimes keep the LoL soft-cap thresholds as scene overrides (MOVEMENT.md; "enemy speeds get retuned in ENEMIES_AI.md").
- **Enemies today:** `slime.tscn` (`slime.tres`: 280 health, 22 damage, 110 range, 0.7 attack speed, 285 move speed, gameplay radius 55 u) and `slime_elite.tscn` (inherits it; `slime_elite.tres`: 900 health, 30 damage, 260 move speed; an AbilityComponent with the slam, `slime_elite_q_slam.tres`: POINT, 250 u range, 0.65 s cast with its telegraph, a 72 px circle, 100 PHYSICAL, 4 s cooldown). The sandbox holds two slimes, one elite and three passive dummies. In 3D they're placeholder capsules (`UnitView`, `model_color`) with no clips: a capsule squashes during a windup or cast and stretches on the hit.
- **Stand-ins waiting for this doc,** each keyed by the dead unit's UnitStats file name: enemy XP (`ChampionLeveling.xp_by_unit`, TALENTS.md), kill tags (`Progress.get_kill_tags()` returns none, TALENTS.md), drop tables (`LootTable.drop_table_by_unit`, LOOT.md), kindling (`kindling_by_unit`, COMPANIONS.md, planned).
- **What exists to build on:** `Condition` and `get_fail_reason()` with an aim hint (AB12); `get_ai_vector()` and `try_cast_vector()` (AB13); cast progress and `Telegraph.set_progress()` (AB14); `AbilityUtil`'s shape queries and `can_reach()` (3D P9); `WorldQuery.has_line_of_sight()`; statuses (stun, slow, untargetable, unstoppable); `Events` (`unit_hit`, `unit_died`, `ability_cast`...); `Reactions`; `UnitView`'s presentation hooks.
- **Measured:** 50 extra slimes take 10–12 ms of physics step in today's game (3D pivot P0a), against a 5.6 ms frame at Ryan's 180 Hz. That cost is the enemy sim's, so this doc's (DECISIONS.md, 3D view).
- Nothing about brains, roles, ranks, tokens, packs, alerts, leashing home, dodging, tells, elite modifiers, bosses or factions exists.
- **Since AI1 (built 2026-10-04, CHANGELOG.md):** the data (EnemyData, EnemyBehavior, BrainAdjust, RankRules, EnemyAITable, AIUse, PoseSet), the `Brains` autoload, `UnitController`, `EnemyBrain` with hold, commit and poke, respect and patience, `CastPlan` and the default `get_ai_plan()`, the `RESPECT` condition kind, the brute's tells on capsules, `SandboxBrains` (I, N, H), `ScriptedController` and `enemies_test`. The slimes and the test brute are on data: the slime is fodder (no brain, as before), **the elite slime is an elite brute with a brain everywhere, room_01 included** (Ryan, 2026-10-04). The bullets above describe the code before AI1; the naive loop and the old routine still run for an enemy with no data or its brain switched off.
- **Since AI3 (built 2026-10-04, CHANGELOG.md):** the skirmisher and caster presets and the test skirmisher (a leap and a stab), test caster (a bolt and a blink away) and elite test caster (plus a Guard shield). Brains see the party's casts in progress (`Ability.get_effect_area()`), charge-ups and projectiles in flight, after their reaction time (`SituationContext.incoming`, the `THREATENED` kind); the intents `defend`, `escape` (cornered when it can't), `retreat` (a caster falling back, a skirmisher's reset); casters hold behind their melee.
- **Since AI3d (built 2026-10-04, CHANGELOG.md):** the enemy ability library (14 templates in `res://data/abilities/enemy/`; new scripts in `res://scripts/abilities/enemy/`: the cleave arc, the dash strike, the shockwave, hop away), `status_root.tres`, `Telegraph.cone()`, the rank caps by Ryan's table (`RankRules.min_abilities`), and full kits: the test brute (smash, cleave arc, charge), the test skirmisher (leap, stab, flurry), the test caster (bolt, lobbed orb, blink away), the elite test caster (plus guard and snare), the elite slime (slam, shockwave, big hit).
- **Since AI3b (passed 2026-10-05, CHANGELOG.md):** the duel. Each brain finds its key ability and reads its own kit (confidence), turns cautious after spending the key, holds the key for a right moment (`spend_eagerness`), reacts to its target in its face with one roll per crowded episode (all in, or Ryan's mix of backing up once or standing), smells blood below its finish threshold, and leads a walking target with its aimed abilities (`aim_lead`; Brains reads each champion's walk). Four sliders (sixteen in all) and `crowded_range` in the presets; the overlay's duel lines; the panel's slider list scrolls.
- **Since AI3c (built 2026-10-05, CHANGELOG.md):** the odds. Brains reads each side's strength once a tick (`get_odds()`: the enemy side's rank weights and the party's 1.5 × `threat`, each × its health); past 1.5 the enemies press (bosses never): effective respect × (1 − `nerve` × press), patience's push shared with low health's, one more token in each pool (under the cap), the weakest champion picked (`Enemy.get_pick_distance()`), one heavy hit at a time on each champion (Brains' landing times), and the `press` pose. Each rank thinks at its own rate (a regular 10, an elite 15, a boss and a duelist elite 25 a second), scaled down evenly past `think_budget`. `nerve` (seventeen sliders) and `EnemyData.duelist`; the overlay's odds line and think rate; H's tenth scenario, the odds (three test brutes and the elite slime).
- **Since AI-D1 (built 2026-10-06, passed 2026-10-07, CHANGELOG.md):** combos' two reads and the test duelist. `ComboPlanner` (`scripts/units/combo_planner.gd`) reads crowding (the target near, closing, gap-closing in, hitting it; Brains keeps the party's hits on each enemy and each champion's last gap-closer) and the opening (escapes down, crowd control by another, committed, cornered). Crowding at `peel_threshold` starts the crowded episode for every enemy; a failed all-in roll peels (a `peel` use: the cast, then the kiting step); an enemy with an `opener`-role ability sets up at `opening_bar` (patience full at once, the commit opening with its best opener). `Ability.recovery_time` (the `recover` pose) and `Ability.combo_roles`; the condition kinds `CROWDING`, `OPENING`, `TARGET_ESCAPES_READY`, `TARGET_CORNERED` and THREATENED's tag filter (`major_tags`); two sliders (nineteen in all); the test duelist (Shift+H) and H's eleventh scenario, escapes down.
- **Since AI-D2 (built and passed 2026-10-07, CHANGELOG.md):** combo plans. `ComboPlan` and `ComboStep` (`scripts/data/`), `EnemyData.combo_plans` (the duelist's three); `ComboPlanner.get_blind_reason()`, `pick_plan()`, `next_step()`, `get_lean()`, `wants_stay()`, `can_crowd_control()`; the plan runs inside `commit` (its token kept up to `plan_max_time`), then the follow-through stays or resets; the sliders `follow_through`, `combo_greed`, `mixup` (twenty-two); the table's `plan_max_time`, `plan_odds_drop`, `mixup_delay_min`/`_max`, `whiff_time`, `blind_reads`; `Events.combo_plan_started` / `combo_plan_ended`; the snapshot's ultimates; the overlay's plan, `after:`, `missed:` and `blind:` lines.
- **Since AI-D3 (built 2026-10-07, CHANGELOG.md):** diminishing returns on crowd control, COMBAT's rule in `StatusComponent` (`cc_diminishing`, `cc_rules`: `CrowdControlRules`, `crowd_control_rules_default.tres`): a second stun, root, silence or fear within 4 s of the first is halved after tenacity, a third is refused and the unit gets `status_cc_immune` (3 s, a ring at its feet); `RankRules.cc_diminishing` (fodder off) and `poise` (the hook, off) given at spawn; `Events.cc_applied` / `cc_refused`. Brains read the immunity through the ring's tag (`target_cc_immune`, AI-D2's no-waste rule), never the halving.
- **Since AI2 (built 2026-10-04, CHANGELOG.md):** every enemy with data plays the pack rules (Ryan, 2026-10-04). It's in a `Pack` (its parent, or a pack of one), notices any party member in sight through WorldQuery (with a path to it), shouts, picks its target by ALLIES' rules, and leashes home with its pack, where it heals. Brained enemies commit on attack tokens. Fodder takes its place in the ring around its target. The `threat` stat exists. An enemy with no data keeps the old routine (the player only, the 800 u leash, the `Sight` ray).

## Goal / feel
| What | Number (TARGET) | Why |
|---|---|---|
| Roles at first | fodder, brute, skirmisher, caster | Ryan (MUST) |
| Abilities per enemy | fodder none (its basic attack); regulars 2–3; elites (and duelists) 3–5; bosses 4–6 plus a passive | Ryan (MUST). Was fodder 0, regulars 1–2, elites 3, a boss by phase (2026-10-03); Ryan's "3 to 5 across the board, no passives, bosses DO have passives" (2026-10-04), reconciled by his pick of Claude's table (Kits) |
| Big attackers on you at once | about 1–2: a pool of 2 attack tokens per champion (3 at difficulty tiers 4–5); a regular holds 1, an elite 2; fodder never needs one | Ryan (MUST shape; the counts I3) |
| Thinking | about 10 thinks a second per brain, staggered; fodder none. By rank since 2026-10-04: regular 10, elite 15, boss 20–30, under a total budget (Performance) | Ryan (MUST shape); the cost measured in AI1; the rates by rank Ryan (2026-10-04) |
| Pressing (odds) | when the enemy side's strength passes 1.5 × the party's: less respect, faster patience, one more attack token per champion (capped), the weakest champion picked | Ryan (2026-10-04); the numbers TARGET |
| Heavy hits on one champion | while enemies press, at most one within 0.8 s (a heavy hit: at least 10% of the target's max health), unless a boss plan scripts it | Ryan (2026-10-04; his 0.3 s widened by him, since the post-hit i-frames already cover 0.3 s) |
| Enemy telegraphs | at least 0.6 s on every enemy ability, unless it's faster than the reaction time on purpose and low damage; **a combo's follow-up may be fast** (an ability whose combo roles hold no `opener`: at least 0.25 s) | Ryan (2026-10-04; the follow-ups 2026-10-07, the tuning pass: "only the opener needs a long, readable telegraph") |
| Combos | an enemy with a real kit chains abilities by plan; any opener (its crowd control is one option); the opener telegraphed at least 0.6 s and dodgeable; it prefers to wait for its opener to land, but goes on without it when you can't answer (the blind read: you're held, low, your escapes or your ultimate down) | Ryan (2026-10-05; the blind read 2026-10-07); the details *(proposed)* |
| Crowd control on one unit | a second within 4 s lasts half as long; a third is refused and the unit is immune for 3 s (fodder takes full crowd control; bosses build poise, later) | Ryan (2026-10-05: every unit; the numbers as proposed, TARGET) |
| Combo limits | none beyond cooldowns: no lockout cap, no damage cap, no kill protection | Ryan (2026-10-05: "if their abilities are off cool down they can use it whenever they please") |
| Reaction time | regulars about 0.45 s, elites 0.35 s, bosses 0.3 s; never under 0.2 s; higher difficulty tiers sharpen it | Ryan (I4) |
| Dodging | elites and bosses only; they try 40–60% of the dodgeable attacks that cover them; cooldown 4–6 s | Ryan (MUST: who; the numbers I4) |
| A melee hold while your kit is up | patience fills in 2–4 s with nothing up, at worst 4× slower with everything up (a brute: 12 s) | *(proposed)*; Ryan: they always come eventually |
| The tell before a commit | 0.3 s of body language before the move, on top of the ability's own telegraph | *(proposed)* |
| Pack alert | packmates join 0.4 s after the first one notices; other packs within 6 m (600 u) that see it too | Ryan (I5) |
| Leash | 12 m (1200 u, 384 px) from the pack's home, or 6 s without reaching you; it walks home 30% faster and heals to full over 1.5 s | Ryan (I5) |
| Fodder | surrounds its target in a ring, about 0.6 m apart | Ryan (I6) |
| Boss phases | 3 by default (at 100%, 66% and 33% health; mini-bosses 1–2), 1.5 s telegraphed transitions | Ryan (I10) |
| Boss tempo | pressure 12 s, breather 5 s (higher difficulty tiers shorten the breather) | *(proposed)* |
| Boss finisher | opens below 30% of the target's health | *(proposed)*, Ryan's example |
| Punish and finish attacks | telegraphed at least 0.6 s; one dash (4 m) leaves the shape from anywhere inside it | Ryan (MUST: a dash always answers); numbers *(proposed)* |
| Frame budget | 5.6 ms at 180 Hz; the AI's share measured in AI1 | 3D.md |

## Rules
### Roles, ranks and ability counts (MUST; Ryan 2026-10-03)
- **Rank** *(proposed word; Open questions)* is an enemy's place on the ladder: **fodder**, **regular**, **elite**, **boss**. Rank sets the base: fodder has no brain, regulars some, elites the full one, bosses the most (a director on top). CONVENTIONS.md calls elite and boss "enemy tiers"; "rank" keeps "tier" for a talent's depth and the difficulty tier, which are already two meanings. There are no ability ranks (ABILITIES.md), so the word is free.
- **T0–T3** (Ryan's shorthand, 2026-10-07): T0 fodder, T1 regular, T2 elite, T3 boss. The docs keep the rank names ("tier" stays the difficulty tier's). **How much each must be respected** (Ryan): T1 is fairly basic, but a swarm of them can deal serious damage, above all once a T2 or T3 has you crowd-controlled or you play your kit carelessly; T1 must be respected and T2 far more: it will definitely punish, and its damage and combos can really mess you up; T3 most of all.
- **Role** is what an enemy does in a fight, one per enemy:

| Role | Plays like | Abilities | Low health |
|---|---|---|---|
| Fodder | swarms and chips with its basic attack; no real brain (cheap) | none | fights to the death |
| Brute (melee) | holds at the edge of your reach while your kit is up, commits when it isn't; heavy, telegraphed hits | 1–2; an elite 3 | fights to the death |
| Skirmisher / assassin (fast melee) | circles, dives in with a gap-closer, hits and resets out | 1–2 (one is a gap-closer); an elite 3 | hits and resets |
| Caster (ranged, artillery) | keeps its range and pokes the whole time, defends against what's coming at it, escapes or fights when caught | 1–2; an elite 3 | falls back toward packmates |

- Any ranged enemy counts as a caster for these numbers (Ryan). *(2026-10-04, Ryan: the counts are now regulars 2–3 and elites 3–5: Kits.)* Fodder is a rank and a role at once: a fodder enemy is always the fodder role, and no other rank is.
- **Later, on the same toolkit** (Ryan: the data model leaves room for them now; built in AI8, right after the milestone and before DUNGEONS' slice, so the slice's rosters can use all seven roles: Ryan, I11): **support** (heals, shields or buffs other enemies; falls back like a caster), **summoner** (makes adds through spawn-in), **perched sniper** (stands on a perch under 3D.md's rules: the `elevated` tag, its dead zone, targets through `AbilityUtil.can_reach()`, and every champion keeps an answer).
- A **mini-boss** (DUNGEONS.md) is rank boss with a lighter plan: one or two phases (Ryan, I10).
- Champions are data, never subclasses of Player (CLAUDE.md); likewise every enemy is an `Enemy` with data. Roles and ranks are data read by one brain class, never subclasses.

### Kits: ability counts, the enemy ability library, passives (Ryan, 2026-10-04; the details *(proposed)*)
- **Ryan:** "enemies will have 3 to 5 abilities across the board; no passives; bosses DO have passives."
- **Reconciled** (Ryan, 2026-10-04) with the ladder above (his MUST of 2026-10-03: fodder none, regulars 1–2, elites 3): he picked Claude's table below. `RankRules.max_abilities` (built in AI1: 0, 2, 3, any; checked by the enemies test) becomes 0, 3, 5, 6, with `min_abilities` 0, 2, 3, 4 (the test warns below them), when AI3d builds the library; until then the built caps stand. The table:

| Rank | Abilities | Passive |
|---|---|---|
| Fodder | none (its basic attack) | none |
| Regular | 2–3 | none |
| Elite (and a duelist) | 3–5 | none; its elite modifiers are the passive-like layer |
| Boss | 4–6 (a phase's form can swap some) | one (Bosses, Boss passives) |

- **A duelist** (Ryan, 2026-10-04) is an elite flagged `EnemyData.duelist` *(proposed name)*: rank elite in everything (2 tokens, 20% tenacity, 3–5 abilities, no passive), but it thinks at the boss's rate (25 a second): a single strong enemy built for a 1v1. Not a new rank.
- **No passives below boss:** an enemy's identity is its abilities and what they're for. Elite modifiers stay the passive-like layer for non-bosses (Ryan). **`EnemyData.twist` stays as it is** (Ryan, 2026-10-04; a `ToolkitBundle`, a field since AI1, set on no enemy yet): it may hold stat shapes, unit reaction rules and statuses.
- **The enemy ability library** (Ryan's idea): about 12–15 reusable abilities, mixed into kits with different numbers, so no kit is authored from scratch. Each is a shared script with a template .tres; an enemy's ability is its own .tres on a library script, as the test skirmisher's stab already runs the slam's script. *(proposed)* Scripts in `res://scripts/abilities/enemy/`, templates `res://data/abilities/enemy/enemy_<archetype>.tres`; an enemy's copies keep CONVENTIONS' names (`<enemy>_<slot>_<name>.tres`).
- **Every enemy ability telegraphs at least 0.6 s** (the dash-answerable minimum: Bosses), unless it's faster than the reaction time on purpose and low damage (COMBAT's chip band, 2–5% of the target's max health). An ability with no damage (a blink, a shield) needs none. **A combo's follow-up may be fast** (Ryan, 2026-10-07: "only the opener needs a long, readable telegraph"): an ability whose combo roles hold no `opener` telegraphs at least 0.25 s (Combos, the telegraph rule for combos; the enemies test checks both floors).
- **The starter list** *(proposed; archetypes, not content; numbers TARGET; the telegraph runs from the cast's start to the hit)*:

| Archetype | Role tag | Shape | Telegraph | `ai_uses` hint | Today |
|---|---|---|---|---|---|
| Smash | `core` | a 2 m circle at the target | 0.7 s | `damage` | the test brute's smash |
| Cleave arc | `core` | a 120° cone, 2.5 m | 0.6 s | `damage`; `zone` with two champions in it | |
| Charge | `mobility` | a 6 m line, 1.2 m wide | 0.8 s | `gap_close` | |
| Shockwave | `core` | a 3 m circle round itself, knocking away 1.5 m | 0.6 s | `cc` (its crowded answer) | |
| Leap | `mobility` | a 1.5 m landing circle beside the target | 0.5 s cast + 0.4 s flight | `gap_close` | the test skirmisher's leap |
| Stab | `core` | a 0.8 m circle in front | 0.35 s (chip band) | `damage` | the test skirmisher's stab |
| Hop away | `mobility` | itself, 3 m straight back | none (no damage) | `escape`; a skirmisher's reset | |
| Flurry | `core` | a 4 m dash line through the target, 1 m wide | 0.6 s | `damage`, `punish` | |
| Bolt | `core` | a 9.5 m skillshot, 0.5 m wide | 0.4 s + travel (chip band) | `poke` | the test caster's bolt |
| Lobbed orb | `core` | a 1.5 m circle at a point | 1.0 s | `poke`, `zone` | |
| Snare | `core` | a skillshot that roots for 1 s | 0.6 s + travel | `cc` (a caster's crowded answer) | |
| Blink away | `mobility` | itself, up to 4.5 m | none | `escape` | the test caster's blink |
| Guard | `defensive` | a shield on itself | none | `defend` with `THREATENED` | the elite test caster's guard |
| Pool | `core` | a 2 m circle that lingers 4 s | 0.8 s | `zone` | waits for WORLD_INTERACTION's Hazards |
| Big hit | `ultimate` | a circle up to 3.5 m in radius, or a band up to 3.5 m wide (dash-answerable) | 1.0 s | `damage`, `punish`, `finish` | an elite's or a boss's key ability |

- *(Built AI3d, 2026-10-04; found while building)* **The library as built:**
  - **Templates:** `res://data/abilities/enemy/enemy_<archetype>.tres`, one per row above but the pool (it waits for WORLD_INTERACTION's Hazards): 14. An enemy's kit holds its own copies (`<enemy>_<slot>_<name>.tres`, CONVENTIONS), on the same scripts.
  - **Scripts:** the new ones are in `res://scripts/abilities/enemy/`: `cleave_arc.gd` (a cone out to its cast range, `Telegraph.cone()`), `dash_strike.gd` (the charge and the flurry: a band toward its target, `overshoot_px` past where it stood, at most `length_px`, cut at a wall or a ledge; a ghosted dash hitting each champion on the band once), `shockwave.gd` (the slam's circle on itself; its plan needs its target inside), `hop_away.gd` (a dash straight away from its target). The archetypes that already had a script keep it where it is (not moved: the change policy): the smash, stab, lobbed orb and big hit run `slime/slam.gd`; the bolt and the snare `test/bolt.gd`; the leap `test_skirmisher/leap.gd`; blink away and guard `test_caster/`.
  - **The snare** is the bolt with an always-on conditional bonus putting `status_root.tres` (new: 1 s, `cc`, `root`, `debuff`, blocks moving and dashing) on what it hits, so its respect counts the crowd control (+1) with no new code.
  - **Weights pick within a kit** (ties go to the earlier slot): the cleave arc 1.1 over the smash, the flurry 1.1 over the stab, the shockwave 1.1 and the big hit 1.3 over the slam, the snare 1.1 over the bolt, the charge 0.9 (a damage use in range wins over it).
  - **The big hit reaches 350 u,** past the shockwave's circle (about 107 px with the Knight's size), so an elite walking in opens with its key ability instead of the shockwave.
  - **Kit numbers (Ryan's answers):** the stab is 30 damage (35 broke the telegraph rule: under 0.6 s only in the chip band, 32.5 of the Knight's 650); a kit's `cc`, `punish` and `finish` uses wait for AI3b and AI6, so each such ability carries a `damage`, `poke` or `gap_close` use too.
  - **Slots:** enemies keep the four slots (q, w, e, r) until bosses need more (AI6; Ryan): the elite cap of 5 can't be reached yet.

### The brain (MUST shape; Ryan 2026-10-03)
- Every enemy above fodder has a **brain** (`EnemyBrain`, a `UnitController`: ALLIES.md, Controllers). Each think it:
  1. **perceives:** the shared party snapshot (`Brains`, below) and its own state;
  2. **builds the situation:** a `SituationContext`, pure data (CONVENTIONS' context-object pattern): its target, distances, what's ready on the party, respect, patience, the attacks coming at it, its token, its packmates, its home and leash, its own cooldowns and health;
  3. **scores its options and picks an intent** (Intents, below);
  4. **acts** through AbilityComponent, AutoAttackComponent and MovementComponent, with the calls `enemy.gd` makes today (`set_aim_hint()`, `try_cast()`, `try_cast_vector()`, the charge-up path, `attack.attack()`, `movement.move_to()`).
- **The decision is a pure function:** `EnemyBrain.decide(situation, behavior, rng) -> BrainDecision`, static, reading nothing else. A test builds a situation by hand and checks the intent; the brain node builds the real situation and carries the decision out.
- **The naive cast loop is disabled, not deleted** (Ryan; the change policy): `Enemy.naive_casting` (export, default true) gates `_try_cast_ability()`, and an enemy whose brain runs never calls it. It's deleted after the milestone passes, with Ryan's OK.
- **The brain switch** (built AI1): `Enemy.brain_enabled` (export, default true; the tuning panel's checkbox switches it while playing). Off, an enemy with data plays the old routine and the naive loop, as one with no data does.
- **Noticing stayed the old routine's in AI1:** idle, wander, sight within `detect_range`, a hit, and today's leash (800 u from the player). The brain drives the enemy only while it's aggroed (`Enemy.is_brain_active()`), and wakes on the tick after it aggroes. *(Built AI2)* For every enemy with data (Ryan, 2026-10-04), the pack rules replace the noticing and the leash (Aggro, packs and the leash); an enemy with no data keeps the old routine.
- **Fodder has no brain:** it keeps `enemy.gd`'s own routine (idle, wander, aggro, chase, attack) without casting, plus its pack's group decisions (Groups).
- *(proposed; built AI1)* **No flip-flopping:** an intent holds for at least `min_intent_time` (0.4 s) unless an urgent event breaks it (an attack to dodge, its token lost, its target gone, a stun). The current intent scores +0.15 (`intent_hold_bonus`) until then.

### Intents and what an ability is for (MUST: intent tags and use rules as data; Ryan 2026-10-03)
- **An intent** is what the brain is doing this moment *(proposed names)*:

| Intent | Means | Who |
|---|---|---|
| `hold` | stand in its range band, circling, facing the target | melee roles while patience fills |
| `poke` | cast a poke from range | casters all the time; melee with a poke while holding |
| `commit` | go in and attack: a gap-closer if it has one, then its hits | melee roles at full patience, holding a token |
| `defend` | raise a defense against an attack coming at it | anyone with a `defend` ability |
| `dodge` | sidestep out of a dodgeable shape | elites and bosses |
| `escape` | reset distance: an escape ability, or walking away | casters, skirmishers |
| `retreat` | fall back toward packmates, or out to its band after a hit | casters and supports at low health; skirmishers after a hit |
| `punish` | attack a whiff, sized to the window | bosses; regulars and elites holding a token |
| `finish` | go for the kill on a low target | bosses; anyone with a `finish` ability |
| `return` | walk home after a leash | everyone, fodder too |
| `peel` *(Combos, proposed)* | cast a crowd control to make space when crowded, then step back to its band | anyone with a `peel` use |

- **Each ability carries what it's for, as data:** `Ability.ai_uses`, a list of `AIUse` *(proposed names)*. Each use has an **intent tag**, **use rules** (a list of the shared `Condition`s, all of which must pass) and a weight. The intent tags: `poke`, `gap_close`, `escape`, `defend`, `punish`, `finish`, `zone`, plus ALLIES' effect tags `damage`, `heal`, `shield`, `buff` and `cc`.
  - **Casters don't cast a shield "just because":** a shield's only use is `defend`, with the rule `THREATENED` ("a projectile, a charge-up or a cast is aimed at me").
  - **The brain asks for the ability the moment calls for, not whatever is ready:** `commit` looks at `gap_close` uses (out of reach) and `damage` uses (in reach), `poke` at `poke` uses, `hold` at `poke` and `zone`, `defend` at `defend`, `escape` at `escape`, `punish` at `punish` (else `damage`), `finish` at `finish`.
  - An ability with no `ai_uses` counts as one `damage` use with no rules, so today's elite slam keeps working.
  - *(Combos, 2026-10-05, proposed; AI-D1)* One more intent tag, `peel`: cast to make space when the enemy is crowded (Peel and setup). A crowd control's other use, setting up a combo, is recorded on its combo plan, not as an `AIUse`.
- **Abilities propose, brains decide** (ALLIES.md, An AI method per ability). For each castable ability with a passing use for the chosen intent, the brain asks its `get_ai_plan(caster, situation)` (where to aim, how good) and takes the best plan value × the use's weight. **The data says what for and when; the script says how and how good.** One list of intent tags serves both brains: the ally brain's stance weighs them (ALLIES' `engage` becomes `gap_close`).
- **Three new `Condition` kinds** for use rules *(proposed; ABILITIES.md, Conditions)*:
  - `THREATENED`: an attack coming at self (Perception) lands within `value` seconds (0 = any time);
  - `TARGET_WHIFFED`: the target's punish window is open and at least `value` seconds long (Punish);
  - `RESPECT`: the situation's respect compared with `value` (0–1) by `comparison`. *(Built AI1)* It reads the party's respect before the enemy's `respect_weight` slider (the same for every enemy, so a use rule means the same on any enemy); the slider shapes the enemy's patience and choices.
  They read the `SituationContext`, passed as a new optional last argument (`Condition.is_met(self_unit, target, cast, situation)`). Without one (a cast condition, a reaction rule) they're false, even negated. *(AI1 built `RESPECT` and the argument; AI3 built `THREATENED` (`SituationContext.is_threatened()`); TARGET_WHIFFED comes in AI6.)* The other kinds work unchanged in use rules: `TARGET_DISTANCE` for a poke's range, `TARGET_HEALTH_PERCENT` for a finisher, `SELF_HEALTH_PERCENT` for an escape, `ENEMIES_IN_RANGE` for a zone (champions are the enemy's enemies), `TARGET_HAS_STATUS` with `cc` to hit a stunned target. One condition system (ABILITIES.md).
- *(Combos, 2026-10-05, proposed; AI-D1)* **Four more situation kinds,** for use rules and combo plans: `CROWDING` and `OPENING` (the situation's crowding or opening, 0–1, compared with `value`), `TARGET_ESCAPES_READY` (at least `count` of the target's `mobility` and `defensive` abilities ready, as the HUD shows them) and `TARGET_CORNERED` (a wall or a ledge just behind the target, seen from self). **`THREATENED` gains a filter:** with `status_tag` set, it counts only attacks whose ability carries that tag; `major` means any of `major_tags` (an ultimate, a charge-up, a dash, a leap).

### Knowledge: what enemies know (MUST; Ryan 2026-10-03)
- **Exactly what the HUD shows, for the player and the ally:** each ability ready or on cooldown, the time left, and current health. *(proposed reading)* "Ready" is what the HUD shows as usable: a charge available and the cost payable (the sweep and the blue tint), not the ability's conditions. The ally's are what ALLIES' ally panel shows.
- **What's on screen:** positions, a cast or charge-up in progress and where it's aimed, projectiles in flight, statuses with a look. Enemies see these as a person would, after a reaction time.
  - *(Built AI3)* An attack is "coming at" an enemy when it covers it. That is a party cast whose effect hasn't started and whose `get_effect_area()` covers the enemy (a point-and-click on it included: Ryan, 2026-10-04), with its cast time left. Or a charge-up held aimed through it, with its release windup at the soonest. Or a projectile whose path will cross it before it runs out, with its travel time.
  - The enemy perceives each attack once its reaction time has passed since it first saw it (at a think); Brains wakes it then (`wake_at()`).
  - Enemies' own attacks aren't threats to them.
- **Reaction time is for reacting to the party only** (Ryan, 2026-10-04): an attack coming, a whiff, an opening, a champion stepping in (Crowded). An enemy's own follow-ups and planned sequences never wait for it: a commit's hit after its gap-closer, a skirmisher's hop after its hit, a boss pattern's next attack. The drive runs the next step on the tick the previous one ends, not at the next think. (The doc implied it through `reaction_time`'s "anything new"; now it's a rule.)
- **Nothing hidden:** no gear, no hidden stats, no talent loadout, no input reading (an enemy reacts to the cast it sees, never to the key press). The values a brain gives abilities never read the champion's stats (Respect).
- **Companions are invisible to enemies:** never in the snapshot, never a target (they aren't Units: COMPANIONS.md), and the command's slot doesn't count toward respect.
- A later opt-in "habit reading" for bosses (learning what this player tends to do) is out of scope.

### Respect (MUST: the rule; Ryan 2026-10-03. The value and the ally's weight: Ryan, I2. The formula's other weights TARGET)
- **Respect** (0–1) sums the value of what's **ready** on the player and the ally (damage, CC, gap-closers; ultimates weigh most). **High respect:** melee holds, circles or pokes. **Low respect** (big cooldowns spent, the player low): it commits. This is the "don't rush in when everything is up" rule, and it makes **baiting intended play**: spend a cheap ability to lure a dive.
- **An ability's value** (`respect_value`), **derived by default with an authored override** (Ryan, I2):
  - derived from data the HUD shows: its role tag (`ultimate` 4, `core` 2, `mobility` 2, `defensive` 1.5, `generator` 1, `companion` 0), +1 if its data applies a `cc`-tagged status (a stun, a slow). **"Its data"** (found building AI1): a `StatusEffect` (or a list of them) among the ability's exports or its conditional bonuses' target statuses, or a `stun_duration` param above 0 (`EnemyAITable.applies_cc()`). A status only its script applies isn't seen (Iron Resolve's empowered slow lives in its script: 1.5, as the example below counts it); an ability like that gets an authored `respect_value` when it matters;
  - authored: `Ability.respect_value` (−1 = derived), for the outliers (an ultimate that's only a buff, a tiny poke tagged `core`);
  - never from damage numbers: those come from the champion's stats and gear (Knowledge);
  - why both: authored-only means every new ability needs a number before an enemy reacts to it; derived-only misreads a few. The brief named it `threat_value`; it's `respect_value` here because ALLIES' `threat` is the stat that makes enemies prefer a champion.
- **The formula** (its weights in `EnemyAITable`; the ally's half weight within 10 m is Ryan's I2, the rest TARGET):
  - a champion's **kit ready** = the value of its ready slots ÷ the value of all four (Q, W, E, R), 0–1;
  - its **share** = kit ready × (0.5 + 0.5 × its health ratio): a low champion is respected less;
  - **respect** = the target's share + `ally_respect_weight` (0.5) × the other champion's share (only while it's up and within 10 m of the enemy), clamped to 0–1;
  - the brain uses respect × its `respect_weight` slider, clamped to 0–1 (the **effective respect**).
- The Knight with everything up: Cleave 2 + Iron Resolve 1.5 + Lunge 2 + Judgement 4 + 1 (its stun) = 10.5. With Lunge and Judgement down, kit ready = 3.5 ÷ 10.5 = 0.33; at half health his share is 0.25.

### The standoff: patience and pokes (MUST; Ryan 2026-10-03)
- **Ranged enemies poke the whole time,** from their range band, with no token.
- **Melee enemies hold or circle while a patience meter fills.** Respect sets how fast it fills; when it's full they **commit, one at a time** (an attack token: Groups). **They always come eventually,** so a fight never stalls. **Pressure rises** when the player idles or is low.
- *(proposed; built AI1)* Patience (0–1) fills each second by (1 − 0.75 × effective respect) ÷ `patience_time` × (0.5 + `aggression`) × pressure. Pressure is 1, +0.5 while the target has done nothing (no move, swing, dash or cast) for 1.5 s, +0.5 while it's below 40% health. So with everything up it still fills at a quarter of its speed: a brute (`patience_time` 3 s, aggression 0.5) comes in 12 s at the latest. A commit empties it; a skirmisher's reset leaves it at half.
- *(proposed)* An enemy with full patience but no token keeps holding, first in the token queue (Groups).
- **Holding:** a spot in its range band around the target (Movement and positioning), strafing one way and turning after 2–4 s (jittered), facing the target, in its hold pose (Tells). *(Built AI1; found while building)* It keeps a **hold distance** (edge to edge): its distance when the hold starts, kept in the band; from farther than the band it closes to the band's far edge; when the target walks away it follows, back into the band. Each re-plan aims at the circle of that distance (without it, strafing along chords spiraled the brute into the Knight).
- *(Built AI1; proposed)* **When the target walks in on a holding melee enemy, it doesn't run:** it holds its ground at that distance and swings its basic attack once the target is in its reach (no abilities: those are a commit's). Otherwise a hold would be a slow chase the player always wins.
- *(Built AI1; proposed)* **A commit** shows its tell (0.3 s, standing still), then goes in: its basic attack (chasing) and its `damage` uses, plus its `gap_close` uses while out of its reach. It **ends** after its first cast ends, after 2 landed basic attacks (`commit_hits`), or after 4 s (`commit_max_time`, the tell included); patience empties then, and a melee enemy **walks back out to its band** for up to 2 s (`back_off_time`) before it holds its ground again. AI2's token is held for the same commit.
- *(Combos; AI-D2; a change to the built rule for enemies with plans, approved by Ryan 2026-10-05)* **A commit with a combo plan** ends when its plan ends, then the follow-through decides between a reset and staying on the target (Combos, crowd control and the test duelist). A commit with no plan ends by the rule above.

### Duels and odds (MUST: the rules, Ryan 2026-10-04; built in AI3b–AI3c; the details *(proposed)*, numbers TARGET)
- **Why** (Ryan): most fights are 1v1 or 2v1 (the player and the ally), rarely more than 5–7 enemies, so an individual enemy must be smarter and stronger, and its decisions are the whole fight. Everything here is data and sliders, tested as scenarios like the rest of the brain.
- **Effective respect, every term** (AI1's respect × `respect_weight`, plus two factors that are 1 at their sliders' 0, so an enemy with `confidence` and `nerve` at 0 reads respect as today):
  effective respect = clamp(respect × `respect_weight` × (1 − `confidence` × own_ready_share) × (1 − `nerve` × press), 0, 1)
- **Patience's pressure, every term:** 1, +0.5 while the target idles, + the larger of the target's low health (+0.5 below 40%) and the odds (`odds_pressure` × press). Low health and the odds both count the target's health, so they share one push instead of adding two.

#### Confidence: its own key ability
- **Its key ability:** its `ultimate`-role ability, else its ability with the highest `respect_value` (derived from its role tag as a champion's is, or authored). A tie goes to the earlier slot (q, w, e, r); an authored `respect_value` breaks one. Today: the test brute's smash, the test skirmisher's leap, the test casters' bolt.
- **While its key ability is ready** it reads its own kit the way it reads yours: `own_ready_share` = the `respect_value` of its ready slots ÷ that of all its slots (0–1); with the key on cooldown it's 0. Effective respect drops by `confidence` × that share, so a brute with its smash ready walks in sooner.
- **Cautious:** once it has spent its key ability (cast it, landed or not) or whiffed it (none of its hits landed on a champion within `whiff_time`, 0.3 s: Punish's whiff rule, read on its own cast), it turns cautious for `cautious_time` (3 s) or until the key is ready again, whichever comes first. Its patience fills × (1 − `cautious_patience_cut` (0.5) × `confidence`), and when its commit ends it walks back out to its band's far edge, not just into the band (`retreat`, the `step_back` pose). **That stretch is the player's opening:** the body shows it, and so does the overlay.
- *(Built AI3b, 2026-10-05; found while building)* **The keys today:** the test brute's smash, the test skirmisher's leap, the regular test caster's bolt, but **the elite test caster's snare** (core 2 + 1 for its root = 3, the highest: AI3d gave it the snare) and the elite slime's big hit (its ultimate). **Cautious** starts when its key's cast ends with its cooldown running (a cast cut short and refunded doesn't count), and the walk to the far edge happens only at `confidence` above 0; the cautious state itself shows at any confidence (the overlay).
- **Not counted twice with punish and whiffs:** Punish's whiffs are a champion's; confidence reads only the enemy's own key. Your whiffed ultimate lowers respect (it's on cooldown) and may open a punish; the enemy's confidence doesn't move. An enemy whose key ability carries its `punish` use spends it on the punish and turns cautious after: one moment, two sides. The punish roll (`punish_greed`) never reads respect, so confidence never makes a punish likelier. A skirmisher's reset already walks it out; being cautious only slows its refill.

#### Spending the key ability: `spend_eagerness`
- At 1 it fires its key ability whenever a use passes (today's behavior: on cooldown). At 0 it holds it for **the right moment:** its target crowd-controlled, a punish window open, the target below `finish_threshold`, every `defensive` ability of the target on cooldown, being crowded (it's an answer), or a plan worth at least `spend_value_bar` (0.8: two champions in its area).
- Outside the right moment it rolls `spend_eagerness` once every `spend_roll_time` (2 s) while it holds the key; a pass fires it.
- Only the key's `damage`, `cc` and `zone` uses are held. **A `poke` is never held** (ranged enemies poke the whole time: MUST), nor a `defend`, `escape` or `gap_close` use.
- Its key held and ready still counts for confidence: it walks in with its big hit in its pocket.
- *(Built AI3b, 2026-10-05; found while building)*
  - **"A plan worth at least `spend_value_bar`"** couldn't work: the shared default plan's value is always 1, so every plan would pass. The right moment reads the key's planned area instead: it covers at least `spend_min_champions` (2) champions.
  - **"Every defensive on cooldown"** needs at least one: a target with no `defensive` ability never makes it (else it would always be a right moment).
  - **A punish window** joins the right moments with AI6's whiff read.
  - **A pass frees the key until the next roll** (2 s later); its key going down (cast) resets the clock, so it rolls again as soon as the key is back.

#### Crowded: in its face (Ryan: "if I'm in their face they should back up rightfully if they have no abilities, but if they do, they should have the option to all in")
- **Crowded** = its target inside `crowded_range` (LoL units, edge to edge): **its own value in the preset** (Ryan, 2026-10-04): brute 200, skirmisher 200, caster its band's minimum (550). Not the band's minimum for melee: a melee band's minimum (350) sits just outside the Knight's reach, so a brute would back off every time he stepped toward it.
- **One episode, one roll each:** an episode starts when its target comes inside, seen after its reaction time (it's reacting to you), and ends once the target has stayed outside `crowded_range` + 0.5 m for `crowded_clear_time` (1 s), or when its all-in or kiting step ends. Each roll below happens once per episode, never per think.
- **In order:**
  1. **Cornered** (AI3): the cornered stand wins.
  2. **Escape** (AI3): a caster, or any role with a passing `escape` use, escapes.
  3. **An answer ready:** it rolls `crowded_commit` once. **Pass: all in.** A melee role's patience fills at once and it commits (its tell first; its token as usual, so with none free it holds its ground and swings, AI1's rule, first in the queue). A caster casts its answer (no token, like a `defend`), then carries on with its escape rules. **Fail:** step 4.
  4. **No answer, or the roll failed: a mix, rolled** (Ryan, 2026-10-04: "both stand and swing, and back up once, then stand. it should be a mix ... it can be rolled randomly"). One roll per episode:
     - **back up once** (the **kiting step**): it walks back out toward its band (`retreat`, the `step_back` pose) for up to `back_off_time` (2 s), then stands; if you follow it in, it holds its ground and swings (AI1's rule), so a hold never becomes a chase you always win;
     - **or stand and swing** at once (AI1's rule as built).
     - *(proposed)* The chance to back up is 1 − `aggression` (brute 50%, skirmisher 30%), so no eighteenth slider: an enemy that shrugs off danger stands more often.
- **An answer** is derived; there's no new tag. ABILITIES.md checked: role tags are Diablo's categories, used by modifiers and respect, and say nothing about what the AI does; the intent tags do. An answer is a ready, castable ability with a passing use for:
  - `cc`: a knock-away is authored as a `cc` use (pushing you off it is crowd control, League's rule); an ability whose data applies a `cc` status counts too (`EnemyAITable.applies_cc()`);
  - `escape` (step 2 takes it first);
  - `damage`, `zone`, `punish` or `finish`, when its plan reaches the target from where it stands now: a close-range burst. A `poke` isn't an answer; it's for range.
  - A held key ability answers: being crowded is a right moment.
- **This changes AI1's built rule** ("walked in on, it holds its ground and swings"): Ryan chose the mix (2026-10-04), so AI1's rule stays as one of the two outcomes and the kiting step is the other.
- *(Built AI3b, 2026-10-05; found while building)*
  - **Only you start an episode:** never while it commits, nor while it walks back out after a commit. Its own dive brings it into your face, and without this every commit would roll an episode.
  - **An episode ends only when you've stayed out** (1 s, 0.5 m past the range), not when its all-in or its kiting step ends. Otherwise standing your ground would roll again after every kiting step, and "back up once" would become a chase you always win.
  - **A caster's all-in isn't built:** inside its band's minimum (its crowded range) escape always wins first (step 2), so it can't happen yet. It comes with a role that has no escape rule (AI8).
  - **All in** fills its patience at once; the commit then asks for its token as any commit does. **The kiting step** is a `retreat` (`step_back`) toward its band for `back_off_time` (2 s), during which it doesn't swing.
- *(Combos; AI-D1; a change to this design, approved by Ryan 2026-10-05)* **The episode starts when crowding passes `peel_threshold`** (a 0–1 read in which being inside `crowded_range` is the biggest term: at the role starts it's enough alone, so the episode starts where it does here), and **a failed all-in roll peels first** when a `peel` use passes, before the mix (Combos, Peel and setup). An enemy with no `peel` use plays this section as written.

#### Smell blood: the target low
- Below `finish_threshold` (0.3) of the target's health, respect's health term already lowers respect (the share × (0.5 + 0.5 × health)), and patience's low-health push (+0.5 below 40%) already speeds it up. **Smell blood adds:** its `commit` and `finish` scores × `smell_blood_mult` (1.3), never above 0.89, so `defend`, `dodge` and `return` still win (commit 0.65 → 0.85: it beats `escape`, `retreat` and a skirmisher's reset).
- **A panic button still counts:** below the threshold, the target's ready `defensive` abilities (a shield, invulnerability, a heal) keep their full respect value, with no health cut, so an enemy stays wary while your panic button is up. The Knight at 20% with Iron Resolve ready: its 1.5 counts whole.
- **The overlap** (Ryan asked): respect's health term (smooth, at any health), the low-health push (below 40%) and smell blood (below 30%) all point the same way, and the odds count health too. **Nothing is removed.** Smell blood adds no third push on patience: it changes the choice (scores), and the panic-button rule pulls the other way; the odds and low health share one push. If Ryan wants a single low-health lever, the 40% push could fold into smell blood (his call).
- **This changes AI1's built respect below 30%** (a ready defensive counts whole). Approved by Ryan (2026-10-04) for AI3b.
- *(Built AI3b, 2026-10-05)* The threshold is each enemy's own `finish_threshold`, so the shared snapshot carries each champion's ready values (all, and the `defensive` ones), and each brain works out the share it reads (`PartySnapshot.get_share_for()`). `finish` comes with AI6, so smell blood lifts `commit` only for now.

#### Odds: outnumbered or outpowered (Ryan: "if I'm outnumbered and/or outpowered they should really try to commit to trying to kill me")
- **Odds** = the enemy side's strength ÷ the party's. **Strength** = the sum over living units of rank weight × health ratio. Rank weights (`EnemyAITable.rank_strength`; Ryan's start, tuned in the overlay): fodder 0.25, regular 1, elite 2, boss 4. A champion weighs `champion_strength` (1.5: Ryan, 2026-10-04) × its `threat`. Against a full-health Knight, then: a lone elite (1.33) or two regulars don't press, three regulars do (2.0, press 0.5), an elite and three fodder a little (1.83); the Knight at 30% against one regular, 2.22 (at 1, a lone elite already pressed). The enemy side is every enemy with data fighting the party (awake, not walking home). A downed champion counts 0; companions never count.
- **One shared read per tick,** like the party snapshot (`Brains.get_odds()`).
- **The press** = clamp(odds − `odds_threshold` (1.5), 0, 1). While it's above 0, enemies press:
  - effective respect × (1 − `nerve` × press);
  - patience's push: `odds_pressure` (0.5) × press, one push shared with the target's low health (the larger);
  - each champion's attack-token pool gains `odds_token_bonus` (1): never more than +1, and never above `tokens_per_target_cap` (4);
  - every enemy's target pick favors the weakest living champion: effective distance × (0.5 + 0.5 × its health ratio), on top of ALLIES' ÷ `threat`. The sticky rules hold (the 25% and 1.5 m margin for 0.5 s, never mid-windup), taunt still wins, stealth and downed still drop it. With one champion nothing changes.
- **Bosses don't press:** the director owns their tempo. A boss counts in its side's strength, so its adds press.
- **Fairness limits:**
  - **The token cap holds:** +1 at most, never past the hard cap.
  - **One heavy hit at a time:** while enemies press, no more than one heavy hit may land on one champion inside `heavy_hit_window`, unless a boss plan scripts it. Brains keeps each champion's predicted landing times for heavy hits started on it (the cast time left, plus a projectile's travel); a brain doesn't start a heavy ability whose hit would land inside another's window (its use fails that think, so it holds or swings).
    - **Heavy** (Ryan, 2026-10-04): an enemy ability hit worth at least 10% of the target's max health by the enemy's own numbers (`heavy_hit_share`; COMBAT's elite band starts at 12%). Basic attacks and chip pokes never count.
    - **The window is 0.8 s** (Ryan, 2026-10-04, widened from 0.3 s): the player's post-hit i-frames (0.3 s, COMBAT.md) already block any second hit inside 0.3 s, so 0.3 s would have changed nothing; 0.8 s leaves about a reaction time to answer the second hit. COMBAT needs no hook.
    - **Only while pressing** (Ryan, 2026-10-04: always-on not approved): outside a press, two token holders may still land heavy hits together, as AI2 allows.
  - **The press shows:** a pose (`press`: its hold or stalk pose becomes a lean in 10° with an amber rim pulsing at 1 Hz) and the overlay's odds line.
- **The mirror** (morale: losing units break or go desperate) is a later idea only (Later sliders and ideas).
- *(Built AI3c, 2026-10-05; found while building)*
  - **The enemy side** is every enemy with data that's aggroed, not passive and not walking home. With no champion up, the odds are infinite (a full press); with nobody on either side they're 0.
  - **One read a tick** (`Brains.get_odds()`, cached by physics frame like the snapshot): a change inside a tick (a death, the threshold) shows on the next one.
  - **The weakest pick's factor is data:** `EnemyAITable.weakest_pick_weight` (0.5): × (1 − w + w × health), Claude's (0.5 + 0.5 × health). `Enemy.get_pick_distance()` feeds both the pick and ALLIES' margin, so the margin holds.
  - **"+1 at most" holds whatever the data says:** the bonus is clamped to 0–1, and a pool already at the cap (or past it) stays.
  - **A heavy hit is noted when its cast starts** (`Brains.note_heavy_hit()`), with or without a press, so a press that starts while it's on its way sees it. A cast cut short takes its note back. It lands its cast time after the start, plus a projectile's flight to its target. Its champion is the plan's target, else its brain's (a cast around itself). The check runs when the brain gathers its uses (the use fails that think) and again as it casts, in case another heavy hit was started in between.
  - **"Unless a boss plan scripts it"** is `can_land_heavy_hit(…, scripted)`; nothing passes it until the boss director (AI6).
  - **A boss's situation reads a press of 0** and its pick never changes; a boss still counts in its side's strength, so its adds press.
  - **The `press` pose** replaces hold and stalk for every brained role below boss, casters included; cornered still wins.
  - **The sandbox's own enemies count:** its two slimes and the elite slime (2.5) against the full-health Knight (1.5) are odds of 1.67, a light press (0.17) while all three fight him.

#### Aim lead: `aim_lead`
- At 0 it aims where the target stands (the default plan today: no leading). At 1 it leads its walk fully: the aim point moves by the target's velocity × the time until the hit (the cast time left, plus a projectile's travel) × `aim_lead`, kept within the ability's range, on floor and in sight.
- **Fair:** the velocity is its walk (what's on screen over the last 0.2 s), never a dash's. A target that stops, turns or dashes walks out of a led shot, as COMBAT.md's "can be walked out of" asks.
- For casters and ranged roles; a melee role's POINT ability may lead a little (the skirmisher's leap).
- **This changes the built default plan** (AI1: "no leading") once a preset's `aim_lead` is above 0. Approved by Ryan (2026-10-04) with the presets' starts, for AI3b.
- *(Built AI3b, 2026-10-05; found while building)*
  - **Which aims lead:** POINT and DIRECTION aims, in the shared default plan (`Ability.get_led_point()`). A VECTOR line and a point-and-click aren't led. The skirmisher's leap lands beside the led point.
  - **The time to the hit** is the cast time plus a projectile's flight to the point (worked out twice, since the flight depends on the point). The commit's tell isn't counted.
  - **Kept within its range** along the same line. Past its range the shot falls short, so a caster leads best from inside its range: the test that proves it puts the caster 4 m off the walk.
  - **A point in a wall or out of sight** falls back to where the target stands.
  - **The walk** is Brains' read of each champion (`Brains.get_walk_velocity()`): its average over 0.2 s, counted only since its last dash, push, leap or blink (a move of over 24 px in one tick). Zero while it dashes or is pushed.

### Combos, crowd control and the test duelist (MUST: the brief, Ryan 2026-10-05; built in AI-D1–AI-D4; the details *(proposed)*, numbers TARGET)
- **Why** (Ryan): enemies are easy to brute-force because their kits are thin. A test enemy with a real kit proves the brain: four abilities (one crowd control, one defensive, two damage). It uses its crowd control for two different reasons. A combo doesn't have to start with it: any opener will do, and the crowd control is one option. After a combo it decides whether to back off or keep going. The same reasoning serves the ally, and giving and taking combos gets fair rules.
- **Built on Duels and odds** (AI3b–AI3c): the crowded episode, confidence and the key ability, `spend_eagerness`, the odds and `nerve`, the `duelist` flag and think rates by rank. So AI-D comes after AI3c.
- **Only enemies that opt in change:** an enemy reads the opening and sets up only if it has combo plans, and peels only if one of its abilities has a `peel` use. Today none has either (the test duelist is the first), so every built enemy plays as Duels and odds has it, except one thing for all of them: crowding starts the crowded episode, so a Lunge in or a string of hits at the edge can start it a little sooner (approved by Ryan, 2026-10-05).

#### Two reads: crowding and the opening
Two 0–1 values the brain works out each think from the situation. Their weights are data in `EnemyAITable`. Neither reads anything the HUD and the screen don't show.
- **Crowding** is the brief's "pressure on me". The word "pressure" already means patience's push and a boss's phase, so this read gets its own name. It measures how hard the target is pushing this enemy: the sum, clamped to 1, of (`crowding_weights`):
  - **near** (0.6): 1 inside its `crowded_range`, falling to 0 at its band's minimum (a melee role: 200 → 350 u; a caster's two are the same, so it's 1 or 0);
  - **closing** (0.15): the target's walk toward it ÷ 400 u/s (`crowding_closing_full`), while the target is within its band's far edge;
  - **gap-closer** (0.3): in the last 1 s (`crowding_recent_time`), the target dashed or cast an ability that moves it (`moves_caster()`: a dash, a leap, a blink), and it ended inside this enemy's band's minimum;
  - **hits** (0.3): the party's hits landed on it in the last 3 s (`crowding_hit_window`) ÷ 3 (`crowding_hits_full`).
  - At the role starts (`peel_threshold` 0.6 or lower), the target inside `crowded_range` is enough on its own, so the crowded episode starts where Duels and odds put it. The other terms bring it forward only when the target is already near: a Lunge into its face, a string of hits at the edge.
- **The opening** measures how open the target is right now to this enemy's crowd control and burst: the sum, clamped to 1, of (`opening_weights`):
  - **escapes down** (0.5): the target's `mobility` and `defensive` abilities on cooldown, as a share of their `respect_value`. For the Knight with Lunge and Iron Resolve both down it's 1; with one down, about half. The dash isn't counted: it isn't on the HUD and it recharges in 0.35 s. That's why an opener must always be dodgeable (Being combo'd);
  - **crowd-controlled by someone else** (0.5): a `cc` status from another unit on the target, with at least 0.5 s left (`opening_cc_min_left`);
  - **recovering** (0.4): its punish window is open (Punish). This needs AI6's whiff read, so it's 0 until then;
  - **committed** (0.4): the target is casting (a cast time, a channel such as Judgement, a held charge-up);
  - **cornered** (0.2): a wall or a ledge within 1.5 m (`cornered_check_px`, 48) behind the target, seen from this enemy (a `WorldQuery` ray).
  - **A token is a gate, not a weight:** with none free for it, it waits first in the queue, as full patience does.
- **The same standard as respect:** both read cooldowns the player sees on their own HUD, and what happens on screen. Neither reads the keys being pressed. Cooldowns are state, read at once as respect reads them. A cast, a whiff or a crowd control landing are things the enemy reacts to, so they count once its reaction time has passed.
- **Not respect twice:** respect asks "how dangerous is it to go in?" (everything ready counts, ultimates most). The opening asks "can it get away from what I'm about to do?". Escapes going down lower respect too, so patience also fills faster. The opening is what lets an enemy with a plan go in at once.

#### Peel and setup: the two uses of a crowd control
Both are use rules on the same ability, never new abilities.
- **Peel** (defensive): crowding passes `peel_threshold`, and the enemy uses its crowd control to make space. It casts it, then takes the kiting step back to its band (`retreat`, the `step_back` pose). The ability carries a `peel` use (the new intent tag), with its own rules on top, such as the target within its range. A peel needs no token, like a `defend`.
- **It's the crowded episode, not a second mechanism:** Duels and odds' episode now starts when crowding passes `peel_threshold` instead of at `crowded_range` alone. Its order stays:
  1. **Cornered:** the cornered stand wins.
  2. **Escape:** a caster, or any role with a passing `escape` use, escapes.
  3. **An answer ready:** one `crowded_commit` roll.
     - **Pass: all in.** A melee role commits at once with its best combo plan, which may open with the crowd control. A caster casts its answer, as AI3b has it.
     - **Fail: peel,** when a `peel` use passes.
  4. **Otherwise the mix:** back up once, or stand and swing.
  - So a peel is the crowded response with a crowd control as its answer: one episode, one roll, the same reaction time, the same `crowded_clear_time`. A caster's all-in was already a peel in all but name (cast its answer, then escape).
- **Setup** (opening): the opening passes `opening_bar` while crowding is under `peel_threshold`. Its patience fills at once and it commits (its tell first, its token as usual) with a combo plan. **The crowd control's setup use is simply the plan that opens with it:** recorded on the plan, not as an `AIUse`. A plan can open with the crowd control, a gap-closing strike or a poke, or have no crowd control at all.
- **Choosing:**
  - **pressured** (crowding at `peel_threshold` or more): the crowded episode, all in or peel, decided by one roll;
  - **unpressured, with an opening:** setup;
  - **neither:** poke or hold, as today.
- *(Built AI-D1, 2026-10-06; found while building)*
  - **Who reads what:** every brained enemy works out both reads each think (they're cheap), but only an enemy with an `opener`-role ability (`Ability.combo_roles`, brought forward from AI-D2 for this) sets up, and the overlay shows the opening only for it. From AI-D2 the gate is its combo plans.
  - **A setup in AI-D1** opens with the best use of its opener-role slots among `cc`, `damage`, `gap_close` and `poke` (plan value × weight; a tie goes to the earlier slot, so the duelist's snare on Q beats its strike on E). That opener's end doesn't end the commit (as a gap-closer's doesn't); after it the commit plays as AI1's (its hits, its first other cast ends it). A setup also starts on the think a commit ended.
  - **The peel follows the roll's order:** only after a failed all-in roll, so a `peel` use with no answer beside it falls to the mix (author a `cc` use with it). A rolled peel that can no longer be cast (its target walked out of its range) takes the kiting step without it.
  - **The episode ends** once crowding is below `peel_threshold` and the target has stayed `crowded_clear_px` outside `crowded_range` for `crowded_clear_time` (a string of hits can keep it on).
  - **Walking in brings the episode a little forward for every enemy:** the closing term (0.15 at 400 u/s) plus near reaches 0.6 about 0.35 m outside a brute's 2 m when the Knight walks straight in at full speed. Standing or teleported (the tests), it starts at 2 m as before.
  - **The inputs:** a push is never a gap-closer (Brains notes one when a champion's dash, or an ability that moves it, ends); DoT ticks aren't hits; a target with no `mobility` or `defensive` abilities has no escapes down (0); a crowd control with no end counts as plenty left; the cornered check sweeps the walls' and ledges' layers past the target.
- **`mixup`** (promoted from the later list, for this use only; approved by Ryan, 2026-10-05): the chance a setup doesn't go the way the read says. With two plans that fit, it takes the runner-up. With one, it holds a beat (0.4–0.8 s, `mixup_delay_min` / `_max`) before starting. `crowded_commit` already rolls the pressured choice, so the player can't solve either one in two fights. Feints and delayed swings stay on the later list; the same slider gains them then.

#### Combo plans
- **A `ComboPlan`** (a Resource, in `EnemyData.combo_plans`) is a list of ordered steps plus when it fits:
  - `steps`: each a `ComboStep`, made of:
    - its ability, by `slot`;
    - its **timing:**
      - `AFTER_LANDED`: as the previous step's hit lands;
      - `AFTER_ENDED`: as the previous cast ends, landed or not;
      - `AFTER_DELAY`: `delay` seconds after the previous step ends;
      - `ON_STATUS`: when the target carries a status tagged `status_tag`, such as `root`;
    - its **window:** the step must start within this long of its trigger, else the plan ends (1 s);
    - `optional`: skipped, not ended, when its ability can't be cast or has no plan.
  - `conditions`: the shared `Condition`s, all of which must pass when the plan starts (read like use rules, with the situation);
  - `weight` (1) among the plans that fit;
  - `min_difficulty_tier` (1): harder plans at higher tiers (Scaling's "attack patterns gated by tier").
- **Combo roles** (`Ability.combo_roles`, a list: an ability may hold several):
  - `opener`: may be a plan's first step;
  - `extender`: a middle step;
  - `finisher`: a last step. The word means what it means for the basic attack combo: the last, heavy hit.
  - The brief's other two roles are already intent tags, so they live there: **peel** is the `peel` use, **guard** the `defend` use. One place says what an ability is for.
- **Picking a plan:** at a setup, and at any commit by an enemy with plans (a crowded all-in included), the brain looks at the plans that fit. A plan fits when:
  - its tier is reached and its conditions pass;
  - its first step's ability can be cast and its `get_ai_plan()` gives a plan;
  - every step that isn't optional has its ability ready.
  It takes the highest weight × the opener's plan value (× jitter, then `mixup`). **A plan whose opener is unavailable is simply not chosen; the enemy never waits for an ability.** With no plan fitting, the commit plays as AI1's.
- **No blind finishers:** a `finisher` step starts only if the plan's opener landed, it carried on after a miss, or the blind read passes (below).
- **A missed step ends the plan** unless a `combo_greed` roll passes. A step misses when none of its hits or statuses land on the target within `whiff_time` after its cast ended (a projectile: by its end); this is Punish's whiff rule, read on its own cast. The enemy rolls `combo_greed` once: a pass carries on, a finisher included (a blind finisher, the brute's swing-through). **The blind read carries it on without a roll** (below).
  - The brief put the blind finisher under `spend_eagerness` "as for a brute", but the brute has the lowest start of the three presets (0.4). `combo_greed` is the knob for it: the later list's `combo_commitment`, under the brief's name (approved by Ryan, 2026-10-05).
- **Its own steps never wait for its reaction time** (Knowledge). Only the first step reacts to the player, with its tell first. Each next step starts on the tick its trigger comes, with no tell.
- **The blind read** (Ryan, 2026-10-07: "they don't HAVE to wait for their opener to land to commit to a combo. They can do it if they see that my health is low or my peel or ult is on cooldown ... They would just prefer to wait"). An enemy waits for a step to land before the next (`AFTER_LANDED`), but goes on without it when its target can't answer: it's held by a crowd control, its health is below the enemy's `finish_threshold`, none of its mobility or defensive abilities is ready, or one of its ultimates is on cooldown (`EnemyAITable.blind_reads`, each switchable; `ComboPlanner.get_blind_reason()`). On the blind read a missed step carries on with no `combo_greed` roll, a finisher may follow a missed opener, a **blind plan** (one whose first step has no `opener` role, so no long telegraph) fits, and the enemy may cast its follow-ups outside a plan. Without it, an enemy with plans keeps its follow-ups for them (its commits swing and use its other uses).
- **A plan ends** after its last step's effect, or at once when:
  - a step missed and the `combo_greed` roll failed;
  - the enemy was interrupted or crowd-controlled (a cast cut, `is_cc_blocked()`);
  - its token was lost (Brains took it back);
  - its target turned untargetable or changed;
  - its target turned CC-immune with a crowd-control step still to come (an optional one is skipped instead);
  - its health fell under its `retreat_health` (`FALL_BACK` roles; brutes fight on);
  - the odds turned: they fell below two thirds of their value when it started (`plan_odds_drop`, 0.33). For example, a packmate died or the ally came in.
  Then the follow-through decides.
- **Its token:** a commit with a plan keeps its token until the plan ends, up to `plan_max_time` (6 s) in place of `token_hold_time` (4 s), then rests as usual. The duelist's longest plan takes about 3.6 s, which can pass 4 s with a long snare flight.
- **Urgent intents** (`defend`, `dodge`) can end a plan between steps, never mid-cast.

#### After the plan: reset or stay (the follow-through)
- When a plan ends, the enemy picks one of two:
  - **reset:** the commit ends. Patience empties (a skirmisher keeps half) and it walks back out to its band, or to the far edge while cautious;
  - **stay** on the target: a new commit at once, its tell first (0.3 s, `crouch`), with its basic attack and any `damage` use, or another plan if one fits, on the same token.
  - The brief's word was "press", but "press" is already the odds' press. "Stay" is used here; either word can change.
- **No special mode:** it falls out of reads the brain already has.
  - **The lean** = (1 − effective respect) × (0.5 + 0.5 × its own health ratio) × (0.5 + 0.5 × its own kit ready).
  - **Effective respect** is Duels and odds' (the target's kit ready and health, confidence, the odds and `nerve`).
  - **Its own kit ready** is the share of its slots' `respect_value` ready now: confidence's read, but not zeroed while its key is down.
  - **It stays** when lean ≥ 1 − `follow_through`. So at `follow_through` 1 it always stays, and at 0 it always resets.
  - **It always resets** when its token is gone.
- **Worked example:** the test duelist, with `follow_through` 0.6, so it stays at a lean of 0.4 or more.
  - Its kit's values: snare 3, guard 1.5, strike 2, finisher 4, so 10.5 in all. The Knight's kit is 10.5 too (Respect). The duelist is at 90% health: × 0.95.
  - **Its plan done, the Knight's kit up.** The snare, strike and finisher are on cooldown, the guard ready: its own kit is 1.5 ÷ 10.5 = 0.14, a factor of 0.57. The Knight at 60% with everything ready: respect = 1.0 × 0.8 = 0.8. Lean = 0.2 × 0.95 × 0.57 = 0.11: **reset.**
  - **Its plan done, the Knight's kit spent too.** Only Cleave is ready: respect = 2 ÷ 10.5 × 0.8 = 0.15. Lean = 0.85 × 0.95 × 0.57 = 0.46: **stay.** It keeps swinging while he has nothing to punish it with.
  - **Its plan cut short after the opener landed** (the strike's window ran out), with the strike and finisher still ready. Its own kit is (2 + 1.5 + 4) ÷ 10.5 = 0.71, a factor of 0.86. Its key is ready, so confidence cuts respect: × (1 − 0.5 × 0.71) = 0.64. The Knight at 60% with Lunge and Iron Resolve ready (Judgement down): respect = 0.52 × 0.8 = 0.42, effective 0.27. Lean = 0.73 × 0.95 × 0.86 = 0.6: **stay.**
  - **The first case, while pressing.** With the duelist and a regular against the Knight, the odds are 2, so the press is 0.5; at `nerve` 0.6 effective respect is × 0.7, so 0.8 becomes 0.56. Lean = 0.24: still a **reset.** At `follow_through` 0.8 it would stay.

#### Where a plan lives in the brain
- **Inside `commit`, as its progress** (the brain already keeps "its commit's progress"), not as an intent of its own. Tokens, the tell, the no-flip-flop hold, `is_cc_blocked()` breaking a commit off, the token's release and the walk back out all hang on `commit` already. A separate intent would copy them all and need its own score against `commit`. A plan is how a commit is carried out.
- **`decide()` stays pure.** When it decides to commit, it picks the plan (`BrainDecision.combo_plan`, with the first step's `CastPlan`). It reads a running plan's progress from the situation: the step, what landed, its damage so far. The drive runs the steps, each on the tick its trigger comes.
- **A commit without a plan is unchanged** (AI1: it ends after its first cast, 2 landed swings or 4 s).
- `punish` and `finish` (AI6) and the boss director's patterns may run plans the same way; that's AI6's call.
- *(Built AI-D2, 2026-10-07; found while building)*
  - **A plan is picked only in a commit's tell** (a new commit, or a stay's): never after it, so an opener always has its tell. An opener that can't start within its window after the tell (its target walked out of reach) ends the plan (`window`) with no follow-through; the commit plays as AI1's.
  - **A step can't start mid-cast or mid-dash:** when the strike's hit lands during its dash, the finisher starts as the dash ends (at most 0.15 s later). A basic attack's windup is cut for a step (refunded).
  - **Landing is a hit through `Events.unit_hit`** (a hit the post-hit i-frames block didn't land). A step's miss time is its cast's end, plus its travel (a projectile's flight past the target, at most its range; a dash's `dash_time`), plus `whiff_time`.
  - **A stay's tell waits out a recovery:** the `recover` pose shows first (the finisher's 1.2 s), then the tell.
  - **Something urgent between steps** (a `defend`) ends the plan (`interrupted`) and breaks the commit off (patience kept), with no follow-through.
  - **A plan's key isn't held:** `spend_eagerness` holds a key's damage uses outside plans; a plan's finisher is its key, cast in the plan.
  - **While enemies press,** the one-heavy-hit window still spaces a plan's heavy steps (0.8 s apart on one champion; tests switch the press off).
  - **The odds drop** compares with the odds when the plan started.

#### Being combo'd: the rules (every unit; Ryan, 2026-10-05)
- **No combo budget: cooldowns are the limit** (Ryan: "if their abilities are off cool down they can use it whenever they please"). An enemy may chain whatever it has ready; nothing caps how long a combo locks the player out or how much it deals. What still holds: every enemy ability's telegraph (at least 0.6 s, or the chip band; a follow-up at least 0.25 s), the dodgeable opener (below), attack tokens, the one-heavy-hit window while enemies press (Duels and odds), and diminishing returns on crowd control.
  - *(Not adopted, kept for the record: Claude's proposal was at most 1.2 s locked out in any 3 s, a root counting half, and at most 30% of max health from a regular's combo, 45% from an elite's.)*
- **Diminishing returns on crowd control: one rule for every unit** (Ryan; the numbers as proposed, TARGET). A second crowd control on the same unit within `dr_window` (4 s) of the first lasts half as long. A third is refused, and the unit is immune to crowd control for `dr_immune_time` (3 s); then the count starts over.
  - **What counts:** `cc` statuses that block something (moving, attacking, casting or dashing: a stun, a root, a silence, fear). Slows don't count, and nor does a status that `ignores_tenacity` (a knock-up keeps its arc's shape).
  - **The order:** the duration × (1 − tenacity) × the step's factor.
  - *Built AI-D3 (2026-10-07; rules found building):* the window runs from the first crowd control (a second at 3.5 s is halved, one at 4.1 s starts a new count); the refused third starts the count over, so the first after the immunity takes in full. The immunity refuses only what counts: a slow still takes and a knock-up keeps its arc. A unit's own crowd control on itself (a channel's self-root) is outside the rule, and a crowd control refused by unstoppable or poise, or an IGNORE re-application, doesn't count. A `cc_immune` status from anything (a later "immune" buff) refuses the same way. Death starts the count over.
  - **Who:** the player, the ally, regulars and elites alike, so the Knight's own stuns on one enemy are halved too (Judgement, then Lunge's stun augment within 4 s). Fodder takes full crowd control: it never lives long enough for it to matter (`RankRules.cc_diminishing` off). Bosses use poise (later: below) once it exists, and this rule until then.
  - **It shows:** the immunity is a status (`status_cc_immune`, tags `cc_immune` and `buff`) with a ring at the feet, the same on every unit. It's a status look like the stun's stars, not an icon over the head (Tells).
  - It's COMBAT's rule, in StatusComponent, so it's one place for everyone (COMBAT.md, Status effects).
- **The telegraph rule for combos:**
  - **The opener** keeps the dash-answerable telegraph (at least 0.6 s) and must be dodgeable: a skillshot or a placed area (POINT, DIRECTION, VECTOR, or an area round itself), never UNIT-targeted.
  - **Later steps may be fast** (Ryan, 2026-10-07, the tuning pass: "only the opener needs a long, readable telegraph"; *replaces* the proposal that they be fast only while the plan's own crowd control still held the target): a follow-up (combo roles without `opener`) telegraphs at least 0.25 s. The test duelist's strike (0.3 s) and finisher (0.35 s) are follow-ups.
  - So the fair answer is to dodge the opener, or to have an answer ready. A blind plan (no `opener` first) runs only on the blind read: when its target can't answer anyway. The enemies test checks every plan's opener and both telegraph floors.
- **No kill protection** (Ryan): a combo may take the player from any health to dead. Telegraphs and the dodgeable opener are the answer; revisit at AI-M if deaths feel cheap.
- **Crowd control on the player at first** (Ryan): a root (up to 1 s; `status_root`) and a short stun (up to 0.5 s), each only from a dodgeable, telegraphed ability. **Later:** slows from enemies, silence, fear, knock-ups (3D.md: enemies don't knock up the player in v1), pulls, taunt.

#### The player's counterplay (checked 2026-10-05 in CHAMPIONS.md and ABILITIES.md)
- **The Knight has no crowd-control break and no unstoppable moment.** Iron Resolve is a haste and an empowered swing with a slow. Unbroken is attack damage. Judgement stuns.
- **Rooted** ("roots are roots", Ryan: ABILITIES.md, Roots), he can swing, Cleave (its knockback pushes the attacker off), Iron Resolve and Judgement. He can't Lunge, dash, leap or blink. **Stunned,** he can do nothing.
- **Tenacity:** the Knight has none. It comes from gear (`affix_tenacity`, 4–15%, on helms and boots; Oathbound Plate) and the Stalwart talent (up to +30% at low health).
- **Korsavil** (designed): her W Vanish doesn't move her, so she can cast it while rooted, and the enemies on her lose her.
- **No new Knight tool now** (Ryan, 2026-10-05; Claude's proposal). The dodgeable opener and diminishing returns carry it: a root lets him fight back where he stands, and only a stun is a real lockout. Revisit at AI-M with the low-health judgment call. *(The options not picked: Iron Resolve also breaking roots and slows, or base tenacity on the Knight.)*

#### Ally parity (ALLIES.md; built with ALLIES AL6)
- **One shared planner, not a copy:** `ComboPlanner` (`res://scripts/units/combo_planner.gd`, beside `UnitController`). Like `decide()`, it's static and pure, over a `SituationContext`. It holds:
  - `get_crowding(situation, weights)` and `get_opening(situation, weights)`;
  - `pick_plan(plans, situation, sliders, rng)` and `get_lean(situation)`;
  - the step and end rules.
  The enemy brain and `AllyBrain` call the same functions. The ally's situation is its own (ALLIES: "filled with the ally's goals").
- **What differs for the ally:**
  - its target pick (ALLIES' stance preferences and `threat`, not the enemy pick);
  - its sliders, which live with its stance (below);
  - no tokens;
  - the player is a teammate it must not get in the way of.
- **Its plans** (approved by Ryan, 2026-10-05): a champion's own sequences (the Knight's Lunge → Cleave) may be `ChampionData.combo_plans`, read only when an AI drives that champion. Party combos (your crowd control, its payoff) stay unscripted. They fall out of the opening read, as ALLIES' "combos come from the plans" has it.
- **It never wastes crowd control.** The planner's rule, for both brains: no crowd-control step on a target that is CC-immune, or already held by a crowd control with more time left than the step's cast time. The ally adds its teammate's cast in progress: it holds its crowd control on a target under the player's channel (Judgement's stun is coming, and diminishing returns would halve it).
  - It never uses a crowd control that damage breaks on a target the player is chaining. None exists yet (no sleep, no charm); the rule waits for one.
- **Follow-up** (approved by Ryan, 2026-10-05): a target the player just crowd-controlled is an opening at once, with no reaction wait: a teammate's crowd control counts as its own. It still has ALLIES' 0.1–0.25 s cast delay, so it's quick but not frame-perfect. The ally commits its payoff.
- **Peel for the player:** the same crowding read with the player as "me". It counts the enemies near and closing on the player, gap-closers into the player and the hits the player took, plus one term only the ally uses: a crowd control on the player (`crowding_weights.cc`, 0.4). Past its stance's `peel_threshold` it peels for you, with one of:
  - its own crowd control on the attacker;
  - a shield or a cleanse on you (`shield` and `heal` uses aimed at a teammate);
  - switching to the attacker (ALLIES' `THREATS_TO_TEAMMATE`).
- **Its sliders live with its stances,** not in the enemy table. `AllyStance` gains `peel_threshold`, `opening_bar`, `follow_through`, `combo_greed` and `mixup` (support peels early, aggressive stays on), and `AllyTable` the reads' weights (ALLIES.md, Data).
- Companions stay invisible to enemies, and out of both reads.

#### Enemies being combo'd (the player delivering combos)
- **By rank:**
  - fodder takes full crowd control (no diminishing returns);
  - regulars take it with diminishing returns;
  - elites also have their 20% tenacity (Poise);
  - **bosses** will not get stunned and build a **poise** meter instead: **later** (Ryan, 2026-10-05). Only the data hook is designed now (below).
- **The poise hook** (designed; its refusal built in AI-D3, off for every rank):
  - `RankRules.poise` (bool; on for bosses when it's built). A unit with it refuses `cc` statuses and fires `Events.cc_refused(unit, source, status, reason, duration)` with the reason `POISE` and the duration it would have had. *Built AI-D3:* `RankRules.poise` gives `StatusComponent.poise` at spawn; it refuses what diminishing returns counts (not a slow) and doesn't count it.
  - A later `PoiseComponent` fills a meter from those and breaks the boss when it's full: a long, real stun the director plans around.
  - Until then a boss takes crowd control with its 40% tenacity and diminishing returns.
- **A CC-immune tell:** the immunity ring (Being combo'd) shows on every unit, so the player sees when a crowd control would be wasted. A boss with poise will show its meter on the boss bar instead.
- **Enemy counterplay when combo'd:**
  - **Guard:** a `defend` shield, as the test duelist's (The test duelist). A counter-strike stance was proposed for it; Ryan picked the plain shield (2026-10-05), so a counter guard is a later archetype if a kit wants one.
  - **A defensive against a big ability aimed at it:** a `defend` use with `THREATENED` filtered by `status_tag` `major` (Intents).
  - **A break-out for elites,** only on enemies that have one. A library archetype, **break free** *(proposed)*: it can be cast while crowd-controlled (`Ability.castable_while_cc`), cleanses `cc` from itself and makes it unstoppable for 0.5 s. It's a `defend` use with `SELF_HAS_STATUS` `cc`, after its reaction time. A crowd-controlled brain otherwise rests (AI2), so this is the one cast it can make. Built with AI5 (an elite modifier can carry it).
  - **No flinch from damage** (I8): unchanged.

#### Feedback hooks (events only; VFX and audio never decide state, COMBAT's rule)
- `Events.cc_applied(unit, source, status, duration, dr_step)`: a crowd control took, with its duration after tenacity and diminishing returns, and its step (0 full, 1 halved). For the HUD, VFX, audio and tests.
- `Events.cc_refused(unit, source, status, reason)`: a crowd control was refused, with one of the reasons `IMMUNE` (diminishing returns), `UNSTOPPABLE`, `REFUSED_BY_TAG` (a boss's fear) and, later, `POISE`. For an "Immune" text or a sound.
- `Events.combo_plan_started(unit, target, plan)` and `combo_plan_ended(unit, target, plan, reason)`, with the reasons `DONE`, `MISSED`, `INTERRUPTED`, `TOKEN_LOST`, `TARGET_LOST`, `LOW_HEALTH`, `ODDS`: for an audio sting, the overlay and, later, the HUD.
- The immunity rides `status_applied` / `status_removed` (`status_cc_immune`).
- *Built AI-D3 (2026-10-07):* the events tell about the crowd control diminishing returns counts (a stun, a root, a silence, fear), not a slow or a knock-up; `cc_refused` also carries the duration it would have had after tenacity (`cc_refused(unit, source, status, reason, duration)`: the poise hook's "the duration it would have had" needed it). The reasons are `StatusComponent.IMMUNE`, `UNSTOPPABLE`, `POISE` and the reserved `REFUSED_BY_TAG` (`&"immune"`...). Nothing listens yet: an "Immune" text and a sound come with UI.md and AUDIO.
- The HUD isn't designed here (UI.md).

#### The test duelist (a sandbox enemy: a placeholder capsule and poses, no art)
- **Ryan's brief:** four abilities, one crowd control, one defensive, two damage. It's built from the enemy ability library: AI3d made the snare, the charge, the big hit and the guard as templates, so it adds no new archetype (Ryan picked the library's guard, 2026-10-05). The numbers are from the doc's elite values (the elite slime, COMBAT's elite band); Ryan approved them as proposed (2026-10-05), TARGET, tuned live in the panel.
- **`enemy_test_duelist.tres`:**
  - **Rank and role:** rank ELITE with `duelist` on, so it thinks at the boss's rate (25 a second: Kits; the brief's 20 sits inside Ryan's 20–30). Role brute (`enemy_behavior_brute.tres`), so it fights to the death.
  - **Tokens and tenacity:** an elite's: it holds 2 tokens, a champion's whole pool at tier 1, and has 20% tenacity.
  - **Stats** (`data/units/test_duelist.tres`): 1000 health; 30 attack damage (the chip band: 4.6% of the Knight's 650); 0.8 attack speed; 320 move speed; 150 u range; gameplay radius 55.
  - **Look:** a capsule in a steel blue `model_color`.
  - **Overrides** (at most three): `crowded_commit` 0.4 (it peels more often than it goes all in), `combo_greed` 0.2 (it rarely swings blind), `mixup` 0.3.
  - *(Built AI-D1, 2026-10-06)* As above, with `crowded_commit` its one override until `combo_greed` and `mixup` exist (AI-D2). **The snare has no line on the floor:** it's the library's snare (the bolt's script), whose tell is its 0.7 s cast (the capsule's windup squash), as the elite caster's has been since AI3d. A floor line for enemy bolts would be a small change to the shared bolt script (Open questions). The strike's band is 6 m long (`length_px` 192: 5 m to its target, 1 m past) and its `cast_range` is the charge's 600 u: at 500 u (5 m) it couldn't open from its band's far edge (500 u edge to edge is about 620 u center to center), so a setup with the snare down waited for patience.
- **Its kit** (`test_duelist_<slot>_<name>.tres`, copies of the templates):

| Slot | Ability | From | Numbers | Uses | Combo roles | Respect |
|---|---|---|---|---|---|---|
| Q | snare (the crowd control) | `enemy_snare` (the bolt with an always-on root) | a 0.7 s cast with its line telegraph, 750 u, 700 u/s, 60 wide, 20 magic, roots 1 s, 10 s | `peel` (the target within 400 u); `cc` (an answer when crowded) | opener, extender | 3 (core 2, +1 for its root) |
| W | guard (the defensive) | `enemy_guard` (the library's guard: a shield on itself; Ryan picked it over a counter-strike stance, 2026-10-05) | a 250 shield for 2 s, no cast time, 8 s | `defend` (`THREATENED` within 1 s by a `major` ability); `defend` (`SELF_HEALTH_PERCENT` below 0.4 and `CROWDING` at least 0.6) | none | 1.5 (defensive) |
| E | strike (damage one) | `enemy_charge` (the dash strike) | a 0.7 s cast with its band, 5 m long (160 px) plus 1 m past, 1.2 m wide, 60 physical, a 16 px push, 7 s | `gap_close` (weight 0.9); `damage` (in reach) | opener, extender | 2 (mobility) |
| R | finisher (damage two) | `enemy_big_hit` (the slam's script) | a 1.0 s cast, a 2.5 m circle (80 px) at the target, 300 u, 130 physical (20%: the elite band's top), a 32 px push, **a 1.2 s recovery** (the new `Ability.recovery_time`), 12 s; role tag `ultimate`, so it's its key ability | `damage` (weight 1.3); `punish`; `finish` | finisher | 4 (ultimate) |

- **Its plans** (`EnemyData.combo_plans`):

| Plan | Steps | Fits when | Weight |
|---|---|---|---|
| `snare_first` | snare → strike (`AFTER_LANDED`) → finisher (`AFTER_LANDED`) | all the target's escapes are down (`TARGET_ESCAPES_READY` below 1), and the target isn't crowd-controlled already (`TARGET_HAS_STATUS` `cc`, negated) or cornered (`TARGET_CORNERED`, negated). With AI6: and it isn't recovering (`TARGET_WHIFFED`, negated) | 1.0 |
| `strike_first` | strike → snare (`AFTER_LANDED`; the crowd control as an extender) → finisher (`AFTER_LANDED`) | its snare is ready (every step is needed) | 0.8 |
| `strike_finish` | strike → finisher (`AFTER_LANDED`) | always: with the snare on cooldown or spent on a peel, it's the plan left | 0.6 |

  - **The timing of `snare_first`:**
    - **Opening:** its tell (0.3 s), then the snare's 0.7 s cast and its flight. The root lands at t = 0.
    - **The strike** starts at once and hits at about t = 0.85 (0.7 s cast + 0.15 s of dash). The 1 s root holds the Knight, unless diminishing returns halved it.
    - **The finisher** starts as the strike lands and hits at about t = 1.9. The root ended at t = 1.0, so there's about 0.9 s to leave a 2.5 m circle: dash-answerable.
    - **Its damage:** 20 + 60 + 130 = 210, or 32% of the Knight's 650 (COMBAT's elite band is 12–20% per hit).
  - **`strike_first`'s snare** is cast at short range against a Knight who isn't held, so it's dodgeable. If it misses, the plan ends (or carries on blind at `combo_greed` 0.2).
  - *(Built AI-D2, 2026-10-07, on the tuning pass's numbers: DECISIONS.md, 2026-10-07)* The kit table above is AI-D1's; the tuning pass made it 2800 health, 30 armor, 36 attack damage, the snare 60 (9.2%), the strike a 0.3 s follow-up of 100 (15.4%, roles `extender` only), the finisher 0.35 s and 195 (30%). Its overrides are nine (the tuning pass's seven, `combo_greed` 0.2 and `mixup` 0.3), past kind-not-magnitude's three. So **`strike_first` and `strike_finish` are blind plans** (their strike has no `opener` role): they fit only on the blind read, which his escapes down, his Judgement down, him held or low each pass. **`snare_first` now:** the root lands at t = 0; the strike starts that tick and lands about t = 0.35–0.45 (its 0.3 s cast, then its dash); the finisher starts as it lands (or as the dash ends) and lands about t = 0.8, inside the 1 s root: 355 damage, 55% of the Knight's 650 (measured in the enemies test).
- **Poses:** the brute's set, plus:
  - `crouch` before a plan's opener (the commit's tell);
  - `guard` while its W is up (a bright white rim pulse; the caster's look);
  - `step_back` after a peel;
  - `recover` *(new, proposed: slumped back 10°, squashed to 0.9, no rim)*, held through the finisher's recovery, so the player's opening shows;
  - `press` while pressing (Odds).
- **Scenarios** (`SandboxBrains`: Shift+H gains the duelist; H's scenarios apply):
  - **Lunge and Iron Resolve down:** it sets up `snare_first` (the overlay shows the opening and the plan).
  - **Everything ready:** it holds. Walk into it: it peels (snare, then a step back) or goes all in (about 40%; 55% since the tuning pass).
  - **Only Lunge spent:** an opening of about 0.3 (2 of the escapes' 3.5, × 0.5): it waits for patience.
  - **The Knight against a wall:** `strike_first` (cornered).
  - **Its snare on cooldown** (H spends it): `strike_finish`.
  - **Judgement aimed at it:** it raises its guard.
  - **The Knight at 25%:** smell blood, its finisher held for the finish.
  - **A whiff** (Judgement at nothing; after AI6): recovering, so `strike_first`.
- **Tests:** Build order, AI-D1 and AI-D2.

### Dodging (MUST: beatable, elites and bosses only; Ryan 2026-10-03)
- **Elites and bosses only.** Fodder and regulars never dodge.
- A smart enemy **sidesteps out of a telegraphed or charged shape after a reaction delay**, with a **dodge cooldown**. It **can't dodge while casting, stunned, rooted or airborne** (anything that blocks moving or dashing).
- **It's beaten by** baiting the dodge (its cooldown opens the real attack), CC, wide areas it can't leave in time, charge-ups (it dodges the aim it sees while you hold; you follow it and release), and layered attacks.
- **Reaction time, dodge skill and dodge cooldown are sliders.**
- *(proposed)* **How:** each attack coming at it is rolled once against `dodge_skill`, `reaction_time` after the enemy first sees it. On a pass it sidesteps: a `MovementComponent.dash()` (not ghosted) of `dodge_distance_px` (64 px, 2 m) over `dodge_time` (0.2 s), to the side that leaves the shape soonest, onto floor it can stand on (`WorldQuery.is_point_free()`), never off a ledge or (once pits exist) into a pit. It only tries when it can be out before the hit (time left ≥ `dodge_time`, and that side clears the shape). The cooldown starts with the attempt; a failed roll is final for that attack.
- **Which player abilities can be dodged, and why** (Ryan, I4): an enemy can only dodge what a person could see coming in time.
  - **Dodgeable:** skillshot projectiles, by their travel time (Cleave Wave flies 900 u/s, about 0.8 s to its full 7 m); charge-ups, while held and in their release windup; VECTOR lines in their release windup; POINT or area casts whose cast time leaves room after the reaction (none in the Knight's kit today).
  - **Never dodged:** UNIT-targeted abilities (point-and-click, League's rule: Judgement); anything faster than reaction plus sidestep (Cleave's 0.2 s, Lunge's 0.05 s, the combo's swings); the dash.
  - So the Knight beats a dodger up close and with his ultimate, and dodging matters most against ranged kits (the second champion, ALLIES.md).
- **The numbers** (Ryan, I4): reaction about 0.45 s for regulars, 0.35 s for elites and 0.3 s for bosses, and never under 0.2 s whatever the rank, faction or difficulty tier; elites try 40–60% of the dodgeable attacks that cover them, with a 4–6 s cooldown; higher difficulty tiers sharpen both (Scaling).
- COMBAT.md's "Don't take: random dodge or block chance" means a hit that silently misses. This is different: `dodge_skill` is the chance to **try** a visible sidestep, and every hit keeps its rules.

### Tells: body language only (MUST: no icons over heads; Ryan's call 2026-10-03)
- **Every smart decision shows as a pose or an animation change** before it happens: raising a shield, stepping back, crouching to dive, drawing back before a punish. **No icons over the head** (Ryan, against the advisor's icon suggestion).
- **The tell comes first** (Ryan, I7): a decision that starts an attack (`commit`, `punish`, `finish`) holds its pose for `tell_time` (0.3 s) before the move, on top of the ability's own telegraph. Reactions (`dodge`, `defend`) are their own look and need no lead.
- **The risk** (flagged, revisited at the milestone): poses can be hard to read in a crowded fight at the 3D camera's distance, and today's enemies are capsules with no clips. **Ryan decides at the milestone's play test (AI-M)** whether a small icon is needed after all (Ryan, I7: the crowded fights there are the real test).
- **Cheap hooks that work on capsules** (Ryan, I7; View): a **lean** toward or away from the target, a **crouch squash**, a **rim or color pulse** (the hit flash's overlay, tinted), and a **distinct windup** (a stretch back). Each pose has one capsule look now and a clip later.
- **The minimum pose set per role** (Ryan, I7; the angles and colors TARGET):

| Who | Poses |
|---|---|
| Fodder | none of its own (the windup squash it has) |
| Brute | `hold` (upright, leaning back 5°), `crouch` (before a commit: squash to 0.8, lean in 15°), `draw_back` (before a punish: lean back 15°, stretch to 1.1, an orange rim pulse) |
| Skirmisher | `stalk` (circling, leaning in 10°), `crouch` (before a dive), `recoil` (the reset: lean back 20° as it hops out) |
| Caster | `hold` (upright), `guard` (defend: a bright white rim pulse), `step_back` (escaping on foot: lean back 15°), `cornered` (squares up: lean in 10°, a red rim) |
| Elite (extra) | `sidestep` (the dodge: squash, then the hop) |
| Boss (extra) | `pressure` (upright, a slow rim pulse), `breather` (slumped back, no pulse), `draw_back`, `finish` (a longer, bigger draw back) |
| Everyone | `alert` (a short stretch up when it notices you), `return` (walking home, leaning back) |

- *(Duels and odds, proposed)* `step_back` for every role (the crowded kiting step, the cautious walk out), `press` for every brained role below boss (pressing: Odds), and a boss's `passive` (Boss passives).
- *(Combos, proposed)* `recover` for any enemy with a `recovery_time` ability (slumped back 10°, squashed to 0.9, no rim, held through the recovery: the player's opening shows); a peel ends in `step_back`; a stay after a plan shows `crouch` again (its tell). The test duelist uses the brute's set plus `guard`, `step_back` and `recover`.

### Groups: attack tokens (MUST: smart enemies only; Ryan 2026-10-03)
- **Fodder swarms freely and chips** (COMBAT.md, Enemies): no tokens. **It surrounds** (Ryan, I6): its pack spreads its fodder in a ring around their target, about 0.6 m apart, instead of stacking on one spot (Diablo's zombies), and a wounded fodder behaves exactly the same (it fights to the death).
- **Brutes, skirmishers, casters and elites use attack tokens:** about **1–2 big attackers at a time**; the rest circle or poke. **Ranged enemies stay behind or beside the melee** (Movement and positioning).
- **The token count scales with difficulty tier and party size** (ALLIES.md's hook). Companions don't count.
- **A holder that's stunned, dead or out of reach releases its token**, and **timeouts** keep anything from deadlocking.
- **Pools** (Ryan, I3): each party member has its own pool of tokens, so a second champion brings a second pool (the party-size hook). A pool's size comes from the difficulty tier (`EnemyAITable.tokens_per_target`: 2 at tiers 1–3, 3 at tiers 4–5, plus a tier's `token_bonus`). A regular holds 1, an elite 2: two regulars or one elite at once. Bosses use none (the director).
- *(proposed)* **What needs a token:** `commit`, and `punish` and `finish` for any enemy below boss. `poke`, `hold`, `defend`, `dodge`, `escape`, `retreat` and `return` never do.
- *(Combos; AI-D2; approved by Ryan 2026-10-05)* A `peel` needs no token. A commit running a combo plan (a setup) needs one as any commit does, and keeps it until the plan ends, up to `plan_max_time` (6 s) instead of `token_hold_time` (4 s).
- **The queue** (the 4 s rotation: Ryan, I3; the rest *(proposed)*): the highest patience asks first, ties to the nearest. A holder keeps its token until its commit ends, for at most `token_hold_time` (4 s); then it can't ask again for `token_rest_time` (1.5 s), so attackers rotate. "Stunned" means any status that blocks moving or attacking; "out of reach" means no path to the target, or a melee holder against an `elevated` target it can't hit (`can_reach()`).
- Fodder in the same fight attacks freely: five thralls and a brute means the brute on a token and the thralls chipping.
- *(Built AI2)* **How tokens run:**
  - A brain at full patience asks each think (`Brains.request_token()`) and holds until it gets them. A request lapses if it isn't renewed within 2.5 thinks.
  - The first in the queue waits until enough tokens are free, and the ones behind it wait too, so an elite isn't starved by regulars.
  - It lets them go:
    - when its commit ends (then it rests `token_rest_time`);
    - when it decides not to commit after all (no rest);
    - when its target is out of reach;
    - when its target changes, or its brain resets.
  - Brains takes them back each tick:
    - from a dead holder, at once;
    - when the target dies or turns untargetable;
    - when the holder is stunned, rooted or anything else that blocks moving or attacking (`Enemy.is_cc_blocked()`; it rests, its commit breaks off, its patience stays);
    - after `token_hold_time` (it rests, its commit ends).
- *(Built AI2; proposed)* **A taunted brain commits on its taunter** without patience or a token, its tell first. The commit ends when the taunt does.
- *(Built AI2; found while building)* **The fodder ring, in detail:**
  - **One ring per target**, over every pack (Brains, `pack_think_rate`), so two packs' fodder never stack.
  - **Fixed places:** as many as fit, neighbors at least 0.6 m apart edge to edge, spread evenly from an angle kept while the ring lasts (the first fodder's). The nearest fodder take the first ring, the rest the next ones out. Each takes the free place nearest it (`Pack.get_ring_spots()`), so the places move with the target without turning.
    - Centering the places on the fodder's mean angle, the first version, turned every place as they walked.
  - **At half its reach** (`fodder_ring_reach_share` 0.5). At 0.7, a slime's 12 px push on its hit took the Knight out of its own reach each time.
  - **At its place** (within `fodder_ring_tolerance_px`, 6 px), it attacks and keeps hitting from where it stands until its target leaves its reach, then walks to its place again. *(AI3)* It steps back to its place once its target drifts past 0.85 of its reach: at the very edge, other fodder's pushes made every swing whiff.
  - **Blocked** short of its place for 1 s with its target in reach, it settles there.
  - **Crowded:** standing within half the spacing of another, the one farther from its place walks to it.
  - **Far round the ring:** a place more than 50° away is walked to round the outside of the ring. A straight path through its target and the settled fodder got stuck.
  - **Its first moment:** before its first place (up to one pack think) it chases as before.
  - **An outer ring's** fodder waits at its place, out of reach.

### Cornered casters (MUST; Ryan 2026-10-03)
- A caster **uses an escape ability if it has one** to reset distance. **Otherwise it stops running and fights at close range with a weaker, slower option.** Catching it is a reward, not an endless chase. **CC and walls beat kiting.**
- *(Built AI3; found while building)* **How it plays:**
  - **The walk away:** it keeps its own clock from its start until it gets away, is cornered or leaves the fight, whatever it does meanwhile (a shield, a poke). A walk under way holds against other intents (the no-flip-flop bonus).
  - **Cornered:** it stands its ground. It swings once its target is within 1.5 × its reach (a step in, never away); otherwise it stands and pokes.
  - **Its escape blink** aims straight away from its target, or ±35° or ±70° where that lands farther, and needs at least 1.5 m of gain.
  - **A caster never commits:** its preset's commit weight is 0.
  - **It notices from 850 u** (the test casters' `detect_range`): from the default 450 u it would always notice inside its own band's minimum and flee at once.
  - *(AI3d; found while building)* **Its escape ability ends a walk under way:** a walk that started while the blink couldn't be cast (mid-cast, say) and then the blink went off kept its old clock, so the next walk was cornered early (1.43 s). A walk after an escape ability now gets its own 2 s.
- *(proposed)* Inside its band's minimum: an `escape` use if one passes; else it walks away (at its own move speed, slower than a champion's) for up to 2 s. It stops when that runs out, when a wall or a ledge blocks the way back, or when it's slowed or rooted: **cornered**. Cornered, it squares up (`cornered` pose) and fights with its basic attack, authored as its weak, slow close option, plus any poke; it doesn't run again for 3 s.

### Aggro, packs and the leash (MUST; Ryan 2026-10-03)
- **A pack wakes on proximity or sight**, and **nearby packmates join** (a shout, a short delay). A pack is a scene of enemies placed together (DUNGEONS.md).
- **The leash:** if the player gets far enough away, the pack **gives up, walks back to its spot and recovers** (Diablo-style).
- **The default target is the nearest,** unless taunt, stealth or another rule says otherwise: ALLIES.md's target pick (the nearest by edge distance ÷ `threat`, sticky with a margin, taunt wins, a stealthed champion is never picked, a downed one is dropped at once). This doc builds it (AI2).
- **Sight stays on layer 1,** so ledges don't block it. It moves from each enemy's `Sight` RayCast2D to `WorldQuery.has_line_of_sight()` (WORLD_INTERACTION.md). *(Built AI2 for every enemy with data; one with no data keeps its `Sight` ray.)*
- **Waking** (Ryan, I5): a member wakes when a party member is within its `detect_range` (450 u, edge to edge) and in sight, or hits it. It **shouts**: the rest of its pack wakes `alert_delay` (0.4 s) later, and so do the members of other packs within `alert_radius` (6 m) of it that have it in sight. The shout has a look (the `alert` pose) and a sound.
- **The leash is measured from the pack's home** (its placed center), not from the enemy (Ryan, I5): when its target is more than `leash_px` (12 m) from home, or no party member has been in reach of the pack for 6 s, the pack gives up (`return`). It walks home 30% faster and once home heals to full over 1.5 s (League's jungle camps). *(proposed)* On the way it ignores new aggro for 2 s, its statuses clear at home, and a hit doesn't turn it around unless the attacker stands inside the leash.
- Arena and boss enemies never leash (their doors are sealed: DUNGEONS.md).
- Today's leash (800 u from the player, stopping where it stands) is replaced for packs: a replace of working code, asked first in AI2. *(Answered: Ryan, 2026-10-04: for every enemy with data, a lone one being a pack of one; the old noticing and leash stay for an enemy with no data.)*
- *(Built AI2; found while building)* **The details:**
  - **What it knows:** an enemy's candidates are the party members it knows (noticed, hit by, or alerted to by a shout), not only those in sight now; while fighting, it also learns of any it sees within `detect_range`.
  - **Its own target:** each member picks its own by ALLIES' rules (`Enemy._update_pick()`, every think).
  - **An untargetable target:** if that's its only one, it's kept and chased, not attacked (AB10); with another candidate, it switches at once.
  - **Sight never wakes an enemy on a champion it has no path to** *(proposed)*. Otherwise a pack below an unreachable perch would wake, give up after 6 s, walk home, and wake again every ~8 s. A hit from there still wakes it, and the leash then sends it home to heal (League's camps).
  - **"In reach of the pack"** (the 6 s rule) means a member's path gets it within its reach of its target (`Enemy.is_target_reachable()`, checked at most every 0.5 s; with no navigation to judge by, always).
  - **The leash at once:** the pack gives up when none of its fighting members knows a living party member inside the leash, so a dead or far champion sends it home.
  - **One shout:** a member woken by a shout doesn't shout on, so no chain wakes a floor. The shout's sound and the `alert` pose (0.4 s) play at the member that noticed.
  - **On the way home:** it ignores sight for `return_ignore_time`, and afterwards notices only party members inside the leash. A hit turns it around only from inside the leash.
  - **Home:** the statuses others put on it clear, and it heals to full over `recover_time`, then idles.
  - **Each member walks back to its own placed spot;** the leash is measured from the pack's home.

### Losing a stealthed target: the search (MUST: Ryan, 2026-10-04, from Korsavil's Vanish; planned, not built; the details *(proposed)*)
- **Enemies chasing a champion that turns stealthed lose it and search:** a simulated look-around at its last known spot (not a real vision cone), then they go back (Ryan; CHAMPIONS.md, Korsavil). Today (AI2, built) they only drop it: the pick can't choose a stealthed unit, and with nobody else to pick, a pack walks home after 6 s with nothing in reach.
- *(proposed)* **The details:**
  - **Who searches:** every enemy with data whose target was dropped for turning stealthed and that has no other candidate (a candidate is picked at once instead, as today). Its token is released as for any drop. An enemy with no data keeps today's behavior.
  - **What it does:** it walks to the spot where its target was when it was dropped (at its normal speed), then looks around there for **3 s** (`search_time`, in `EnemyAITable`; Korsavil's open question 9): a slow turn and a step or two (a `search` pose). The look-around is never sight: it can't find a stealthed champion.
  - **It ends** when the 3 s are up (it goes back: a pack walks home and recovers as on a leash; an arena or boss enemy never leaves, so it holds where it is); when the champion's stealth ends where it can notice her (the usual waking rule: within `detect_range` and in sight), and the pick takes her again; or when a hit wakes it (the usual rules: from inside the leash).
  - **A pack:** each member searches the spot its own target was last at; the shout isn't repeated.
  - `memory_time` (Later sliders) is the later knob on this; `search_time` is its first, fixed form.
- **Built with Korsavil** (her K6, CHAMPIONS.md, Build order). Tests: a dummy turning stealthed sends its chaser to the spot for 3 s, then home; its stealth ending in sight during the search brings the chase back; a second candidate is picked instead of searching.

### Low health: role-based (MUST; Ryan 2026-10-03)
- **Fodder and brutes fight to the death.**
- **Casters and supports fall back toward packmates:** *(proposed)* below `retreat_health` (35%) they move behind the nearest living melee packmate (else away from the target) and keep poking.
- **Skirmishers hit and reset:** *(proposed)* after a commit's first landed hit (or 1.5 s), they retreat out to their band and hold again.
- *(Built AI3; found while building)* **Details:**
  - **What ends a skirmisher's commit:** any landed hit counts, its gap-closer's included. The 1.5 s runs from when it got to its target (its gap-closer done, or in reach).
  - **Its reset:** a 2 m hop straight back (a quick dash, not through anyone), keeping half its patience, then a walk out to its band for 2 s (`retreat`, the `recoil` pose).
  - **How often it dives:** with half its patience kept, a 2 s `patience_time` and 0.8 respect weight, it dives every couple of seconds even with the kit up while the target stands still (TARGET; the sliders tune it).
  - **A caster falling back** goes to just behind its nearest melee packmate as seen from its target, and keeps poking.
  - **Any gap-closer's cast** (a use with `gap_close`) never ends a commit by itself, for any role: it only got it there.

### Poise: no flinch (Ryan, I8 2026-10-03)
- **A hit never interrupts a smart enemy's cast.** Only a status that blocks casting (a stun, a silence) does, as today (COMBAT.md; League's rule). CC stays the answer to big casts and to dodgers.
- **Tenacity by rank:** elites take 20% shorter crowd control, bosses 40% (the `tenacity` stat, given at spawn by their rank: `RankRules.tenacity` 0.2 and 0.4, a FLAT modifier under `&"enemy_rank"`). Fodder and regulars have none. A knock-up still ignores tenacity (`ignores_tenacity`, 3D.md).
- Knockback is untouched: bosses get `knockback_resistance` 1 when that stat is built (WORLD_INTERACTION.md, Knockback).
- *(Combos; Ryan, 2026-10-05)* **Diminishing returns** on crowd control for every unit but fodder, and **poise** for bosses later (a meter that crowd control fills instead of stunning; only the data hook now): Combos, crowd control and the test duelist (Being combo'd; Enemies being combo'd). Until poise exists, a boss keeps its 40% tenacity and takes diminishing returns.

### Fear: fleeing (MUST: Ryan, 2026-10-04, from Korsavil's Umbral Stalker; planned, not built; the details *(proposed)*)
- **A feared enemy runs away from the fear's source and can't act; fear is crowd control (tenacity applies); bosses ignore it** (Ryan). The status is COMBAT.md's (`status_fear`, Status effects, Fear); the flee and the brain's part are this doc's.
- *(proposed)* **The details:**
  - **The brain rests** while `status_fear` is on, as under `is_cc_blocked()`: its token released, a commit broken off, its patience kept; it doesn't think a new intent.
  - **The flee:** it walks away from the fear's source at its own move speed, along its navigation (re-pathed at each think toward a point straight away from the source), and stops where it can't go farther (cornered). A stun or root on it wins (it can't move until that ends, then flees for what's left).
  - **After:** it picks its target again at once (the usual pick) and resumes.
  - **Tenacity:** elites take 20% shorter (1.5 s → 1.2 s); fodder and regulars the full time.
  - **Bosses refuse it:** `RankRules` gives every boss a permanent status tagged `boss` at spawn (as it gives tenacity), and `status_fear`'s `refused_by_tags` lists `boss` (COMBAT.md). Unstoppable refuses it anyway (a boss's phase change).
  - Enemies don't fear the player in v1, as with knock-ups.
- **Built with Korsavil** (her K6, CHAMPIONS.md, Build order). Tests: a feared brute walks away for 1.5 s and doesn't attack or cast, then picks again; an elite's lasts 1.2 s; a boss and an unstoppable enemy refuse it; a cornered one stops at the wall.

### Movement and positioning (proposed)
- **The range band** (a slider, LoL units, edge to edge) is where an enemy likes to stand from its target while it holds or pokes. Melee bands sit just outside the target's reach (the Knight's swing reach 175 u plus his aim help's 125 u = 300 u), so holding never feeds his aim help.
- **Ranged behind or beside melee:** a caster scores spots in its band by how many melee packmates stand between it and the target (or within 45° of that line), and keeps 2 m from other casters. *(Built AI3, simpler)* While it holds, a caster strafes round its target only to get its nearest melee packmate within 45° of its line to the target (cover) and to keep 2 m from other casters; otherwise it stands at its hold distance (`EnemyBrain.get_caster_strafe()`).
- **Spacing:** brained enemies keep 1 m apart while holding *(proposed)*. Fodder surrounds its target in a ring, about 0.6 m apart (Ryan, I6; Groups).
- Paths use `MovementComponent.move_to()` (NavigationServer2D), re-planned at most every 0.25 s. A target on a navmesh island (a perch: 3D.md) is reached by its walk-up route if one exists; otherwise melee holds at the nearest reachable spot and releases its token, and the pack's ranged members poke: no unanswerable player either.
- *(Built AI1)* **Facing:** while its brain runs, an enemy's view faces its target, even while it strafes (`Enemy.get_face_point()`, read by `UnitView`); otherwise it faces its walk, as before.

### Spawning (MUST: placed packs and ambushes, Ryan 2026-10-03; spawn-in confirmed and waves deferred, Ryan 2026-10-04)
- **Placed packs:** enemies placed in a space (a pack scene through a content slot or a marker: DUNGEONS.md), idle until they notice you.
- **Ambushes:** enemies emerge from hidden spots, or on a trigger (the party entering an area, a world state such as a chest opened). *(proposed)* They emerge after a floor telegraph (0.6 s) at each spot and aggro at once on the nearest party member. In DUNGEONS.md an ambush is the scene of an EVENT content slot.
- **Spawn-in** (confirmed by Ryan, 2026-10-04): DUNGEONS.md's sealed arenas and boss rooms depend on enemies that spawn in with a telegraph and instant aggro, so **spawn-in is a basic kind**: an arena's enemies appear together, once, when it seals. **Arena waves and mid-fight reinforcements stay deferred** (Ryan): not built, and not in any build step until he reopens them.
- Every spawn gets party scaling, the difficulty tier and its elite modifiers at spawn (ALLIES.md, DUNGEONS.md), so nothing heals or refills mid-fight.

### Elite modifiers (MUST: data that changes behavior; Ryan 2026-10-03)
- An elite **rolls a few modifiers from a pool authored per dungeon** (faster, shielded, teleporting, vampiric, volatile on death...). **The count is set by the difficulty tier** (DUNGEONS.md: 1, 2, 2, 3, 3). **Modifiers are data and change behavior, not only numbers.** This doc defines the format; DUNGEONS.md says how many.
- *(proposed)* An `EliteModifier` is a `ToolkitBundle` (TALENTS.md's bundle that Passive and Talent share: stat modifiers, stat scalings, unit reaction rules, statuses, augments, applied to any Unit under a source id), under the source `&"elite_modifier_<id>"`, plus: an ability put in a free slot with its `ai_uses` (a blink used to `gap_close` and to `escape`), a `BrainAdjust` (faster reactions), a look (an aura scene), `excludes` (modifiers it can't roll with), a weight and a minimum difficulty tier. A shield that comes back is a status; "on hit" and "on death" are unit reaction rules.
- Rolled at spawn from the run's seed (rerolled each run: DUNGEONS.md I3), never two that exclude each other.
- *(proposed)* A first pool to build: **Fast** (+25% move speed, reaction × 0.85), **Shielded** (a shield of 25% of its max health that comes back 6 s after it breaks), **Teleporting** (a 6 m blink with an 8 s cooldown, telegraphed 0.4 s at both ends, used to `gap_close` and `escape`; needs `MovementComponent.blink()`, specified in ABILITIES.md, Blinks, and built in AB15; *(proposed)* with `through_walls` off, so it never blinks where its target can't follow), **Vampiric** (`life_steal` 0.25: its hits heal it), **Volatile** (on death a 3 m circle telegraphed for 1 s, then elite-band damage; needs an area GameplayEffect, which COMBAT.md says comes later).
- *(proposed)* Its modifier names show under its health bar (identity, Diablo's way; not a decision tell). Open questions.

### Bosses: the director (MUST; Ryan 2026-10-03)
- **Phases by health, plus a tempo cycle: a pressure phase, then a breather.**
  - **Pressure:** the boss attacks.
  - **The breather:** the boss retreats to range, recovers its tempo, and pokes or zones with lower-damage attacks, so you can heal, reposition and set up an opening, and the next pressure is readable. Its length is a slider, and higher difficulty tiers shorten it. **It isn't a scripted damage window.**
- **Punish:** when the player spends a major ability (an ultimate, a charge-up, a long dash) and misses, or is in that ability's recovery, the boss opens a punish window and commits an attack sized to it (all-in, or a chase with a big ability). It's telegraphed, and **a dash always answers it**. It can only punish something the player actually did.
- **Finish:** when the player is low, the boss goes for the kill with a telegraphed, dash-answerable attack. The low-health threshold is a slider (30% *(proposed)*).
- **A boss knows the ally's cooldowns too** (Knowledge).
- **Bosses reset on a death** (DUNGEONS.md I8): the director resets cleanly.
- **How** (Ryan, I10):
  - **Three phases by default,** starting at 100%, 66% and 33% of max health (a mini-boss has one or two). A `BossPlan` lists them as data, not a script per boss: each phase may swap the boss's abilities (a `form` status of REPLACE augments: ABILITIES.md, Forms), its intent weights and its pressure and breather times.
  - **A phase change** is a 1.5 s telegraphed transition during which the boss is unstoppable but not invulnerable.
  - Pressure lasts `pressure_time`, the breather `breather_time`. *(proposed)* During a breather only `poke` and `zone` uses are allowed, from the far edge of its band.
  - **Sizing a punish:** each `punish` use states the window it needs through `TARGET_WHIFFED`'s value. Under 0.8 s, its fastest telegraphed hit; 0.8–1.5 s, a gap-closer into a hit; over 1.5 s, its all-in. *(proposed)* A punish can cut a breather short, never a phase change.
  - *(proposed)* **Dash-answerable** means a punish or finish attack is telegraphed for at least 0.6 s and its shape can be left by one dash (4 m in 0.18 s) from anywhere inside it: a circle at most 3.5 m in radius, a band at most 3.5 m wide.
  - *(proposed)* **The reset** (`BossDirector.reset()`): full health, phase 1, the tempo at pressure's start, every cooldown ready, statuses and forms cleared, its home position, its windows and memory cleared, its arena told. Nothing from the failed attempt survives.
- **Boss passives** (Ryan, 2026-10-04: "bosses DO have passives"; the details *(proposed)*, built in AI6):
  - A boss has one passive: a `Passive` (CHAMPIONS.md's resource, a `ToolkitBundle`) on `BossPlan.passive`, under `&"boss_passive_<id>"`. A phase may swap it (`BossPhase.passive`; null keeps the plan's). The reset removes it and puts phase 1's back.
  - **It must read** (Ryan: a readable tell on the HUD or the boss's pose):
    - its state shows on the boss bar as the player's passive shows on the HUD (CHAMPIONS CH6: its initials in its `icon_color`, a stack count or timer, its tooltip). A slot on the boss bar isn't an icon over a head, so it keeps Ryan's tells rule;
    - its always-on part shows as an aura on the boss (`BossPlan.passive_aura`, a scene);
    - when it fires, the boss flashes its `passive` pose (a short rim pulse in the passive's `icon_color`).
  - Elite modifiers remain the passive-like layer for everyone below boss (Kits).

### Punish: what counts as a whiff (MUST: only what the player did; Ryan 2026-10-03. The details *(proposed)*)
- A **major ability** has the role `ultimate`, the style `charge_up`, or the tag `dash` or `leap` (`EnemyAITable.major_tags`).
- **A whiff:** its effect started (`Events.ability_cast`) and none of its hits landed on an enemy within 0.3 s (a projectile: by the time it ends). **Its recovery:** while that champion is still casting it, or still moving in its own dash or leap after the effect started.
- **The window** opens at the whiff (or at the recovery's start) and lasts the recovery left plus 0.6 s (the time to turn around and act); the situation carries its size and age. Enemies notice it after their reaction time.
- Regulars and elites can punish too, with a token and a `punish` use; `punish_greed` sets how readily.
- Baiting with a cheap ability isn't a whiff (it isn't major): it lowers respect instead, which is how a bait draws a dive.

### Scaling: ladder × faction × difficulty tier (MUST; Ryan 2026-10-03)
- **Rank sets the base** (fodder none, regulars some, elites full, bosses most). **Each dungeon's faction adds a personality preset** (vampires cunning and evasive, constructs relentless and blunt). **Higher difficulty tiers turn sliders up** (faster reactions, better dodges, shorter patience, more tokens, more elite modifiers). **The ladder is also the performance budget.**
- *(proposed)* An enemy's sliders at spawn: its behavior preset's values with its own overrides in their place, × its rank's adjust × its faction's adjust × the difficulty tier's adjust × each elite modifier's adjust, each clamped to the slider's limits. A `BrainAdjust` holds one multiplier per slider (1 = unchanged).

| Rank adjust *(proposed)* | Fodder | Regular | Elite | Boss |
|---|---|---|---|---|
| Brain | none | yes | yes | yes, plus the director |
| Dodges | never | never | yes | yes |
| Token cost (I3) | none (swarms) | 1 | 2 | none (the director) |
| Tenacity (I8) | 0 | 0 | 0.2 | 0.4 |
| Sliders | — | reaction × 1.3, jitter × 1.5, punish greed × 0.5 | × 1 | reaction × 0.85, jitter × 0.7 |
| Thinks a second (Ryan, 2026-10-04; AI3c) | none | 10 | 15 (a duelist 25) | 25 (Ryan's range 20–30) |

| Difficulty tier adjust *(proposed)* | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Reaction time | × 1 | × 0.95 | × 0.9 | × 0.85 | × 0.8 (never under 0.2 s) |
| Patience time | × 1 | × 0.9 | × 0.8 | × 0.7 | × 0.6 |
| Dodge skill | × 1 | × 1 | × 1.15 | × 1.3 | × 1.4 |
| Dodge cooldown | × 1 | × 1 | × 0.9 | × 0.85 | × 0.7 |
| Breather time | × 1 | × 0.9 | × 0.8 | × 0.7 | × 0.6 |
| Tokens per target (Ryan, I3) | 2 | 2 | 2 | 3 | 3 |
| Elite modifiers (DUNGEONS.md) | 1 | 2 | 2 | 3 | 3 |

- *(proposed)* Faction examples: **vampires** (dodge skill × 1.3, reaction × 0.9, aggression × 0.8: cunning, evasive), **constructs** (patience × 0.6, respect weight × 0.6, dodge skill × 0: relentless, blunt).
- Health and damage scaling stay ALLIES' and DUNGEONS' (`&"party_scaling"`, `&"difficulty_tier"`), applied at spawn as they say.

### Performance (MUST shape; Ryan 2026-10-03. The numbers measured in AI1)
- Brains think **about 10 times a second, staggered** (an even share of them each physics tick); **one shared read of the player and the ally per tick**, not per enemy; **fodder has no brain** and its packs decide as groups; units beyond **the sleep distance sleep** (3D.md, the P-spike).
- **The first build step measures the sim's crowd cost with the new brain,** and this doc then states a **measured budget** (enemies awake per room, brains thinking per tick, the AI's milliseconds per frame). No number is set before that.
- *(proposed)* What AI1 measures, headless and windowed at 180 Hz in the sandbox: the physics step and the think cost (mean and 99th percentile) with 10, 25 and 50 fodder plus 0, 5 and 10 brutes; each think in microseconds; and how much of P0a's 10–12 ms is movement (pathing, steering, `move_and_slide()`) rather than deciding. If the crowd alone breaks the frame, AI1 reports it and Ryan picks the fix (fewer awake enemies, cheaper fodder movement, or the optimization pass ALLIES.md puts after all AI).
- **The budget (measured in AI1, 2026-10-04;** the sandbox, the editor build, Ryan's machine and 180 Hz screen, the Knight standing; details in CHANGELOG.md**):**
  - **Brains are cheap.** A think costs about 56 µs alone, plus the shared party read once per tick (about 60 µs); in the sandbox's fights a think averages 130–230 µs (p99 under 0.45 ms). 10 brutes thinking 10 times a second cost **0.27 ms per physics tick** (about 0.09 ms per frame at 180 Hz). Brains thinking per tick: about 2 for 10 brains, and 20 brains would still be under 0.6 ms.
  - **Crowd movement is the cost.** Physics-step scripts, chasing fodder: 10 add 0.7 ms, 25 add about 5 ms, 50 add 16.4 ms (it grows faster than the count). Standing still, 50 cost 2.2 ms. Chasing without steering (avoidance off), 50 cost 6.2 ms: **steering is about 60% of the movement cost.** A brute costs about as much as 2–4 fodder (mostly its movement; its brain is about 0.03 ms of it).
  - **The frame at 180 Hz holds** (mean 5.56 ms) up to about **20 awake enemies: 10 fodder + 10 brutes** (p99 11.9 ms: an occasional missed frame on the physics tick) **or 25 fodder alone** (p99 13 ms). 25 fodder + 10 brutes falls to about 100 fps; **50 chasing fodder break the game** (the physics step can't keep up: 6–7 fps), so P0a's 10–12 ms was the crowd's movement, not deciding.
  - **So until a fix:** a fight wakes **at most about 20 enemies** that move (any mix of brained and fodder; brains themselves aren't the limit). **The fix is Ryan's pick** (Open questions): fewer awake enemies, cheaper fodder movement (no steering for fodder, the ring spacing doing its job), or the optimization pass ALLIES.md puts after all AI.
  - **Ryan's pick (2026-10-04, starting AI2): the cap.** A fight wakes at most about 20 moving enemies; DUNGEONS' packs, arenas and the sleep distance plan around it. No code changed for it; the optimization pass after all AI may lift it.
- **Think rate by rank** (Ryan, 2026-10-04; built in AI3c with the next measurement; the budget *(proposed)*):
  - Each rank thinks at its own rate (`RankRules.think_rate`): fodder none, regular 10, elite 15, boss 25 a second (Ryan's range for bosses and duelists: 20–30); a duelist elite thinks at the boss's rate (Kits). Still staggered. The table's `think_rate` stays as the default for a rank without one (additive: nothing is removed).
  - **A budget caps the total** (`EnemyAITable.think_budget`: thinks a second over every awake brain). 200, from AI1's measure: a think in a fight costs about 165 µs, so 200 a second is about 0.55 ms per physics tick. Past it, every brain's rate scales down evenly, never under `think_rate_floor` (5). Under the 20-enemy cap a boss, 2 elites and 6 regulars think 115 times a second.
  - AI3c measures it again, with the odds read added.
  - Reaction times don't change (0.45 / 0.35 / 0.3 s, never under 0.2 s), and apply only to reacting to the party (Knowledge).
  - *(Built AI3c, 2026-10-05; found while building)* **The schedule:** each brain thinks every (physics ticks a second ÷ its rate) ticks, a fraction kept (25 a second at 60 Hz is 2.4 ticks: ticks 0, 3, 5, 8, 10, 12...), from its slot inside its first period. At 10 a second that's AI1's schedule tick for tick. Urgent wakes come on top, as before. **The budget counts awake brains** (aggroed, not passive); an idle brain keeps its rank's rate (its think returns at once). A brain whose own rate is under the floor keeps its own.
  - **Measured again (AI3c, 2026-10-05; headless, the editor's debug build, Ryan's machine; the sandbox's new odds scenario, the five-brute pack and the mixed pack, 10–15 s each, the Knight standing invulnerable):**
    - **A think in a fight now costs 410–480 µs** on average (p99 0.8–0.9 ms, the longest 1.2 ms), up from AI1's 130–230 µs: AI3's perception, AI3d's full kits (a plan per ability) and AI3b's duel all run each think.
    - **The odds read costs 42–56 µs a tick** (p99 under 0.1 ms), about the party snapshot's cost.
    - **The odds scenario** (three brutes, two elite slimes: the scenario's and the sandbox's own) asks 45 thinks a second: about 0.32 ms a physics tick with the read.
    - **So the budget's 200 a second is about 1.5 ms a tick at today's cost,** not 0.55 ms (that assumed AI1's 165 µs). Under the 20-enemy cap, a boss, 2 elites and 6 regulars (115 a second) would cost about 0.9 ms a tick. **Ryan's answer (2026-10-05): keep 200; elites (of any role: casters, duelists, brutes) and bosses are exempt** (`RankRules.think_budget_exempt`): they always think at their full rate, their thinks come off the budget first, and the regulars share what's left (never under the floor). Bosses' and elites' sharpness never pays for a big fight's frame time; the regulars do, then the optimization pass after all AI.

### The tuning toolkit (MUST: built first; Ryan 2026-10-03)
1. **A brain Resource with sliders,** every tunable an `@export` in the inspector. **Archetype presets and faction presets are Resources;** each enemy carries only a few overrides (kind, not magnitude). **The slider list** (Ryan, I1: all twelve, in one preset per role; bosses read pressure, breather and finisher, the others ignore them), with each role preset's starting value (TARGET):

| Slider | What it does | Brute | Skirmisher | Caster | Limits |
|---|---|---|---|---|---|
| `aggression` | how much danger it shrugs off: speeds its patience (× 0.5 + aggression) | 0.5 | 0.7 | 0.3 | 0–1 |
| `respect_weight` | how much what's ready on the party holds it back (0 = ignores it) | 1.0 | 0.8 | 1.2 | 0–2 |
| `patience_time` | seconds to fill patience with nothing ready on the party (with everything up, up to 4× longer) | 3 | 2 | 4 | 0.5–10 |
| `range_band` | where it likes to stand from its target, min–max (LoL units, edge to edge) | 350–500 | 400–600 | 550–800 | 0–1500 |
| `reaction_time` | delay before it reacts to anything new: an attack, a whiff, an opening (the preset is the elite's; a regular's is × 1.3, a boss's × 0.85: Scaling) | 0.35 | 0.3 | 0.35 | 0.2–1.0 |
| `dodge_skill` | chance to try a sidestep out of a dodgeable attack (elites and bosses only) | 0.4 | 0.6 | 0.5 | 0–1 |
| `dodge_cooldown` | seconds between dodges | 6 | 4 | 5 | 1–15 |
| `punish_greed` | the chance it takes a whiff's opening (one roll per window; 0 = never punishes) | 0.6 | 0.8 | 0.4 | 0–1 |
| `finish_threshold` | the target's health share below which `finish` opens (a `finish` use's own rules come on top) | 0.3 | 0.3 | 0.3 | 0–0.6 |
| `pressure_time` | a boss's pressure phase, seconds | 12 | 12 | 12 | 3–30 |
| `breather_time` | a boss's breather, seconds (difficulty tiers shorten it) | 5 | 5 | 5 | 1–15 |
| `jitter` | randomness: ± this share on scores and timings, so a group never moves in lockstep | 0.15 | 0.2 | 0.15 | 0–0.5 |
| `confidence` | how much its own ready key ability emboldens it (effective respect × (1 − confidence × its own kit ready)), and how cautious it turns once it's spent | 0.5 | 0.6 | 0.3 | 0–1 |
| `crowded_commit` | the chance it goes all in when you're in its face and it has an answer (one roll per episode; otherwise it backs up once or stands) | 0.6 | 0.4 | 0.2 | 0–1 |
| `aim_lead` | how far its aimed abilities lead a walking target: 0 = where you stand, 1 = where you'll be | 0 | 0.3 | 0.5 | 0–1 |
| `spend_eagerness` | how freely it fires its key ability: 0 = holds it for the right moment, 1 = fires it on cooldown | 0.4 | 0.7 | 0.8 | 0–1 |
| `nerve` | how hard it presses when the odds are on its side: effective respect × (1 − nerve × the press) | 0.6 | 0.8 | 0.4 | 0–1 |
| `peel_threshold` | how crowded it must be before it reacts (the crowded episode: all in or peel); lower reacts sooner | 0.6 | 0.6 | 0.5 | 0.1–1 |
| `opening_bar` | how open the target must be before it sets up a combo plan (enemies with plans only) | 0.5 | 0.4 | 0.6 | 0–1 |
| `follow_through` | after a plan: 0 = always resets, 1 = always stays on the target | 0.6 | 0.2 | 0 | 0–1 |
| `combo_greed` | the chance it carries on after a plan step misses (0 = the plan ends: no blind finishers) | 0.6 | 0.3 | 0.1 | 0–1 |
| `mixup` | the chance a setup takes its runner-up plan (or holds a beat), so it can't be read in two fights | 0.15 | 0.3 | 0.2 | 0–0.5 |

   Twelve sliders (the range band is one, with two ends). The rest of a preset is **kind**, not magnitude: the role, its intent weights, its low-health response, its retreat health, whether it uses tokens, its pose set.
   **Five more** (Ryan, 2026-10-04; Duels and odds), **seventeen in all:** `confidence`, `crowded_commit`, `aim_lead` and `spend_eagerness` (built in AI3b, 2026-10-05; the panel's slider list scrolls since: sixteen rows don't fit the 360 px canvas), `nerve` (built in AI3c, 2026-10-05; the panel's seventeenth row). Their role starts are TARGET. At `confidence`, `aim_lead` and `nerve` 0, `crowded_commit` 0 and `spend_eagerness` 1 an enemy plays as AI3 shipped, except for the crowded mix (backing up once or standing). The starts above change the test enemies; Ryan approved them for their steps (2026-10-04). `crowded_range` is kind, not a slider (Data). Each new slider's scenario test and overlay line:
   - `confidence`. **Test:** the same party state with the test brute's smash ready, then on cooldown: patience fills faster while it's ready; after its smash (landed or whiffed) it's cautious for 3 s, refilling slower and walking out to its band's far edge; at 0 neither changes. **Overlay:** `conf 0.5 × own 1.0 (key: smash ready)`, or `cautious 2.1 s`.
   - `crowded_commit`. **Test:** the Knight with Judgement ready steps inside its crowded range. With its smash ready, 1,000 seeded episodes go all in at about `crowded_commit`'s rate, one roll each; with the smash down it backs up once in about 1 − `aggression` of the episodes and otherwise stands and swings, one roll each. **Overlay:** `crowded: all in (0.31 < 0.6)`, `crowded: back up (no answer)`, or `crowded: stand (no answer)`.
   - `aim_lead`. **Test:** a target walking sideways at a steady speed: at 0 the bolt lands behind it, at 1 on it. A target that stops as the cast starts: at 1 the bolt lands ahead of it (walked out of). A dash is never led. **Overlay:** `lead 0.5 (+1.2 m)`.
   - `spend_eagerness`. **Test:** at 0 the key is held until a right moment (the target stunned, or below 30%), then fires at once; at 1 it fires on cooldown; at 0.5 about half the 2 s rolls fire; a poke is never held. **Overlay:** `key: held (next roll 1.4 s)`, or `key: free`.
   - `nerve`. **Test:** odds past the threshold: effective respect × (1 − nerve × press), the pool +1, the weakest champion picked; at 0 respect is unchanged (the pool and the pick still change: they're the group's). **Overlay:** `odds 2.1, press 0.6 (nerve 0.6)`. *(Built AI3c: the overlay prints one decimal, `odds 0.7` with no press.)*
   **Five more** (Ryan's Combos brief, 2026-10-05; the meanings of `combo_greed` and `mixup` approved by Ryan the same day; every start TARGET), **twenty-two in all,** near the twenty the brief asked for: `peel_threshold` and `opening_bar` (built in AI-D1), `follow_through`, `combo_greed` and `mixup` (AI-D2). They act only for an enemy with a `peel` use or combo plans (none today; the test duelist first), except `peel_threshold`, which starts every crowded episode: at the role starts the target inside `crowded_range` is enough on its own, as before. Each one's scenario test and overlay line:
   - `peel_threshold`. **Test:** the test duelist with its snare ready and `crowded_commit` at 0: the Knight stepping inside its crowded range draws a peel (the snare, then a step back to its band) in every episode; 1 m outside it with nothing else, no episode; Lunging in to 2.75 m (near 0.5 × 0.6 = 0.3, plus the gap-closer's 0.3) starts one at 0.6 but not at 0.7; an enemy with no `peel` use falls to the mix, as in AI3b. **Overlay:** `crowding 0.66 ≥ 0.6: peel (snare)`. *(Built AI-D1, 2026-10-06: the overlay reads `crowding 0.66 ≥ 0.60 (near 0.60): peel (Snare)`; the Lunge case is tested with its gap-closer noted where the Knight stands.)*
   - `opening_bar`. **Test:** the Knight with Lunge and Iron Resolve down (escapes down: 0.5) draws `snare_first` at a bar of 0.5 but not at 0.6; with them up, it holds while patience fills; an enemy with no plans never reads the opening. **Overlay:** `opening 0.5 ≥ 0.5 (escapes 0.5): snare_first`. *(Built AI-D1, 2026-10-06: until AI-D2 an enemy with an `opener`-role ability reads the opening and sets up with its best opener, so the test checks the duelist's snare first at 0.5 and nothing at 0.6; the overlay reads `opening 0.50 ≥ 0.50 (escapes 0.50): setup (Snare)`.)*
   - `follow_through`. **Test:** the worked example's cases at 0.6 (reset, stay, stay, reset); at 0 always a reset, at 1 always a stay; a lost token always resets. **Overlay:** `after: stay (lean 0.60 ≥ 0.40)`.
   - `combo_greed`. **Test:** a dodged opener over 1,000 seeded plans carries on in about `combo_greed` of them; at 0, never, and never a finisher after a missed opener. **Overlay:** `missed: carry on (0.12 < 0.2)` or `missed: end`.
   - `mixup`. **Test:** with two plans fitting, over 1,000 seeded setups the runner-up is taken in about `mixup` of them; with one plan, a held beat of 0.4–0.8 s instead. **Overlay:** `plan: strike_first (runner-up)`.
   - *(Built AI-D2, 2026-10-07)* The three as above, at those starts (the duelist: `combo_greed` 0.2 and `mixup` 0.3 as overrides). The overlay reads `plan: snare_first 2/3 (Strike)` (with `runner-up` or `beat 0.5 s`), then for 2 s `plan: snare_first done, after: stay (lean 0.57 ≥ 0.40)`; `missed: carry on (0.12 < 0.20)`, `missed: carry on (blind: escapes down)` or `missed: end (0.31 ≥ 0.20)`; `blind: escapes down`; a setup's opening line ends `: setup snare_first (Snare)`. The blind read carries a miss on with no roll (Ryan, 2026-10-07).
2. **An in-game brain overlay** in the sandbox: per enemy, its state, chosen intent, why (its top scores), respect, patience, whether it holds a token, its dodge cooldown and its reaction timer.
3. **A live tuning panel** in the sandbox: pick an enemy, drag its sliders, watch it change while you play, and save back to its .tres.
4. **A scenario spawner:** preset situations (all cooldowns ready, none ready, low health, an ally present) and a scripted dummy player for the headless tests.
- *(Built AI1)* All three in-game tools live on one sandbox node, `SandboxBrains` (Architecture), on raw keys like `SandboxLoot`'s: **I** the overlay (B was taken: the AB15 test blink; Ryan, 2026-10-04), **N** the panel, **H** the scenarios (AI2 added two packs).

### Later sliders and ideas (Ryan, 2026-10-04: named only, not designed)
- `bait_susceptibility`: how readily a cheap ability spent as bait draws its commit (today respect alone decides).
- `mixup`: feints and timing changes, such as a tell that doesn't follow through or a delayed swing. *(Combos, 2026-10-05: promoted for one use, the runner-up plan at a setup; the feints and delayed swings stay here.)*
- `combo_commitment`: whether it finishes a string after you dodge its first hit, or cancels it. *(Combos, 2026-10-05: designed as `combo_greed`, the brief's name.)*
- `memory_time`: how long it remembers its target after stealth or lost sight (today AI2 keeps a known champion while it fights, and ALLIES drops a stealthed one at once). Since 2026-10-04 the search (Losing a stealthed target) is its first, fixed form: `search_time` 3 s *(proposed)*.
- `strafe_bias`: which way and for how long it circles while it holds (today 2–4 s, jittered).
- `adaptation`: it changes a pattern after the player counters it three times.
- `anti_repeat`: a boss never uses the same attack three times in a row.
- A telegraph-length multiplier per difficulty tier (on `DifficultyTier`; `BrainAdjust` holds no telegraph today).
- Pack leader and follower settings, and focus fire versus spread (the odds' weakest pick is a first focus rule).
- Boss phase triggers by health: already in (`BossPhase.health_below`, I10); later, triggers other than health.
- Morale, the mirror of odds: losing units break or go desperate.

### Testing (MUST: scenarios in the headless suites; Ryan 2026-10-03)
- The brain is a pure function, so scenarios are tested in the headless suites, with no view and a seeded random number generator: a player with an ultimate ready at 5 m means a brute holds; the ultimate spent means it dives; a projectile aimed at a caster means `defend`; a dodge only after the reaction delay and never on cooldown; `punish` only after a real whiff; token counts and release; the leash and the pack alert; a boss reset. Each step's list is in Build order.
- *(proposed)* Two levels: **decision tests** (a hand-built `SituationContext` into `EnemyBrain.decide()`, thousands of seeded runs where a number matters) and **integration tests** (a real enemy and a champion driven by a `ScriptedController` in a test scene, physics frames stepped).
- The new suite (`enemies_test`) joins the baseline: every suite green after each step, the counts in CHANGELOG.md.
- TEMP (2026-10-04): a temporary test multiplier on enemy auto attack speed (`AutoAttackComponent.enemy_attack_speed_test_mult`, off by default; DECISIONS.md, Testing), not a rule.

## Data (Resources)
**The format** (Ryan, I9): an `EnemyBehavior` per role (the twelve sliders and its kind), an `EnemyData` per enemy (loaded like a ChampionData), an `EnemyRoster` per dungeon (its enemies, its faction preset, its elite modifier pool). Every other name is *(proposed)* and checked against CONVENTIONS.md (reserved names, vocabulary); names go into CONVENTIONS when Ryan approves them. Resource scripts in `res://scripts/data/`; runtime scripts in `res://scripts/enemies/`.

### EnemyData (`enemy_data.gd`; `res://data/enemies/enemy_<name>.tres`)
One kind of enemy: DUNGEONS' "a shared behavior plus its own data". `Enemy.data` points at it and `Enemy._apply_enemy_data()` loads it when the enemy is ready, the way `Player._apply_champion()` loads a ChampionData. An enemy with no `data` plays exactly as today.
*(AI1 built `id` through `pose_set`, plus `detect_range`. Its stats and look replace the scene's before the Unit sets itself up; its abilities need an AbilityComponent in the scene (a warning without one). `attack_tags` waits for Ryan's answer to proposal 9, `boss_plan` comes in AI6, and the reward fields in AI7.)*

| Field | Type | Notes |
|---|---|---|
| `id`, `display_name` | `StringName`, `String` | `&"crypt_thrall"` |
| `rank` | `EnemyData.Rank` | `FODDER`, `REGULAR`, `ELITE`, `BOSS` |
| `behavior` | `EnemyBehavior` | its role preset; null for fodder (the fodder routine) |
| `overrides` | `Dictionary` (StringName → float) | a slider's value in place of the preset's; at most 3 (the test warns past that). The range band's ends are `range_band_min` and `range_band_max` |
| `stats` | `UnitStats` | as today |
| `abilities` | `Array[EnemyAbilitySlot]` | its abilities by slot, each with a minimum difficulty tier (the new attack patterns a tier adds) |
| `attack_tags` | `Array[StringName]` | added to its basic attack's hit tags; `melee` for melee roles, so an `elevated` champion is out of its reach (3D.md) |
| `twist` | `ToolkitBundle` | what makes it this enemy (stat modifiers, unit reaction rules, statuses), under `&"enemy_<id>"`; TALENTS' shared bundle |
| `model_scene`, `model_color` | `PackedScene`, `Color` | its look; empty = a capsule in `model_color` |
| `pose_set` | `PoseSet` | its tells; null = `pose_set_default.tres` |
| `boss_plan` | `BossPlan` | rank BOSS only |
| `detect_range` | `float` | LoL units, edge to edge (450) |
| `duelist` | `bool` | *(built AI3c; Ryan, 2026-10-04; the name proposed)* rank ELITE only: it thinks at the boss's rate (Kits; `EnemyAITable.get_think_rate_for()`); false |
| `combo_plans` | `Array[ComboPlan]` | *(Combos, proposed; AI-D2)* its plans; empty = it never reads the opening or sets up (Combo plans) |
| `xp` | `int` | champion XP per kill; replaces `ChampionLeveling.xp_by_unit` (AI7) |
| `kill_tags` | `Array[StringName]` | TALENTS' kills by tag, quest counters, the bestiary; replaces `Progress.get_kill_tags()`'s none (AI7) |
| `drop_table` | `DropTable` | replaces `LootTable.drop_table_by_unit`; null = the regular or elite table by rank (AI7) |
| `kindling_chance`, `kindling_amount` | `float`, `int` | replaces COMPANIONS' `kindling_by_unit` (AI7) |
| `companion_drop_chance` | `float` | −1 = the companion table's rate for its rank (COMPANIONS: elites 3%) |

### EnemyAbilitySlot (`enemy_ability_slot.gd`; inline in EnemyData)
`slot: StringName` (`&"q"`, `&"w"`, `&"e"`, `&"r"`), `ability: Ability`, `min_difficulty_tier: int` (1). Below its tier the slot stays empty.

### EnemyBehavior (`enemy_behavior.gd`; `res://data/enemy_behaviors/enemy_behavior_<role>.tres`)
DUNGEONS' "shared behavior": one archetype preset per role (`brute`, `skirmisher`, `caster`; later `support`, `summoner`, `sniper`). Fodder needs none.

| Group | Field | Type | Notes |
|---|---|---|---|
| Kind | `role` | `EnemyBehavior.Role` | `BRUTE`, `SKIRMISHER`, `CASTER`; later `SUPPORT`, `SUMMONER`, `SNIPER` |
| Kind | `intent_weights` | `Dictionary` (StringName → float) | per intent; a missing intent counts 1 (ALLIES' `AllyStance` pattern) |
| Kind | `low_health` | `EnemyBehavior.LowHealth` | `FIGHT_ON`, `FALL_BACK`, `HIT_AND_RESET` |
| Kind | `retreat_health` | `float` | 0.35 (`FALL_BACK` only) |
| Kind | `uses_tokens` | `bool` | true |
| Kind | `pose_set` | `PoseSet` | *(added AI1)* the role's tells; null = the enemy's own, else `pose_set_default.tres` (looked up: EnemyData's, the behavior's, the default) |
| Kind | `crowded_range` | `float` | *(built AI3b; its own value: Ryan, 2026-10-04; `get_crowded_range()` reads −1 as the band's minimum)* LoL units, edge to edge; −1 = the band's minimum. Brute 200, skirmisher 200, caster −1 (Crowded) |
| Sliders | the twelve | | The tuning toolkit: each an `@export_range` with its limits (`EnemyBehavior.LIMITS`). `resolve(overrides, adjusts)` makes the copy a brain reads. Seventeen from AI3b–AI3c (Duels and odds); twenty-two from AI-D1–AI-D2 (Combos) |

*(Built AI1: `enemy_behavior_brute.tres` with the brute column. AI3: `enemy_behavior_skirmisher.tres` (HIT_AND_RESET) and `enemy_behavior_caster.tres` (FALL_BACK at 35%, `intent_weights` commit 0) with their columns.)*

### BrainAdjust (`brain_adjust.gd`; `res://data/brain_adjusts/brain_adjust_<name>.tres`)
One multiplier per slider (default 1) and `token_bonus: int` (0). Used by ranks (in the table), factions (`brain_adjust_faction_<name>.tres`), difficulty tiers (`DifficultyTier.brain_adjust`, DUNGEONS.md) and elite modifiers.

### EnemyRoster (`enemy_roster.gd`; `res://data/enemy_rosters/enemy_roster_<dungeon>.tres`)
The type of DUNGEONS' `DungeonData.roster`: `enemies: Array[EnemyData]`, `faction_name: String`, `faction: BrainAdjust` (the personality preset), `elite_modifiers: Array[EliteModifier]` (the dungeon's pool). Pools place scenes of the roster's enemies; the validator warns about a pool entry holding an enemy outside the roster *(proposed)*. The format: Ryan, I9.

### EliteModifier (`elite_modifier.gd`; `res://data/elite_modifiers/elite_modifier_<name>.tres`)
Extends `ToolkitBundle` (`display_name`, `description`, `modifiers`, `stat_scalings`, `reaction_rules` as unit rules, `statuses`, `augments`; `apply_to(unit, source_id)` / `remove_from()`), and adds `id`, `ability: Ability` (into the first free slot; none free = skipped, with a warning), `brain_adjust: BrainAdjust`, `vfx: PackedScene` (its look), `excludes: Array[StringName]`, `weight: float` (1), `min_difficulty_tier: int` (1). Source `&"elite_modifier_<id>"`.

### BossPlan and BossPhase (`boss_plan.gd`, `boss_phase.gd`; inline in the EnemyData, or `res://data/boss_plans/boss_plan_<name>.tres`)
- `BossPlan`: `phases: Array[BossPhase]`, `transition_time` (1.5), `transition_ability: Ability` (cast at a phase change; its telegraph is the warning).
- `BossPhase` (inline): `health_below` (1.0 for the first), `form: StatusEffect` (a `form` status of REPLACE augments; null = its base slots), `intent_weights` (in place of the behavior's; empty = unchanged), `pressure_time`, `breather_time` (−1 = the sliders').
- *(Boss passives, proposed; AI6)* `BossPlan.passive: Passive` and `passive_aura: PackedScene`; `BossPhase.passive: Passive` (null = keep the plan's).

### AIUse (`ai_use.gd`; inline on an Ability)
`intent: StringName` (`poke`, `gap_close`, `escape`, `defend`, `punish`, `finish`, `zone`, `damage`, `heal`, `shield`, `buff`, `cc`; *(Combos; built AI-D1)* `peel`), `conditions: Array[Condition]` (all must pass; the situation is passed in), `weight: float` (1).

### ComboPlan and ComboStep (`combo_plan.gd`, `combo_step.gd`; inline in the EnemyData or ChampionData) *(Combos, proposed; AI-D2)*
- `ComboPlan`: `id: StringName` (`&"snare_first"`), `steps: Array[ComboStep]`, `conditions: Array[Condition]` (all must pass when it starts; the situation is passed in), `weight: float` (1), `min_difficulty_tier: int` (1).
- `ComboStep` (inline): `slot: StringName` (`&"q"`...), `timing: ComboStep.Timing` (`AFTER_LANDED`, `AFTER_ENDED`, `AFTER_DELAY`, `ON_STATUS`), `delay: float` (0; `AFTER_DELAY`), `status_tag: StringName` (`ON_STATUS`), `window: float` (1.0), `optional: bool` (false).
- Checked by the enemies test: every plan's first step holds an `opener`-role ability that telegraphs at least 0.6 s and isn't UNIT-targeted; every slot named exists in its EnemyData.

### PoseSet (`pose_set.gd`; `res://data/pose_sets/pose_set_<name>.tres`; view data)
`poses: Dictionary` (pose → `PoseLook`). `PoseLook` (inline): `clip: StringName` (a model's clip; empty = none), `lean_deg` (+ toward the target), `squash` (height scale, 1 = none), `rim_color` (alpha 0 = none), `pulse_hz` (0 = steady). `pose_set_default.tres` gives every pose of the minimum set its capsule look.

### EnemyAITable (`enemy_ai_table.gd`; `res://data/enemy_ai_tables/enemy_ai_table_default.tres`)
The global rules, held by `Brains.table` (the pattern of `LootTable`, `AllyTable` and `CompanionTable`).

| Field | Type | Value |
|---|---|---|
| `ranks` | `Array[RankRules]` | four (below) |
| `think_rate`, `pack_think_rate` | `float` | 10, 5 (per second) |
| `fodder_ring_spacing_px` | `float` | 19 (0.6 m between fodder in the ring around their target; I6) |
| `fodder_ring_reach_share`, `fodder_ring_tolerance_px` | `float` | *(added AI2)* 0.5 (the ring at half the fodder's reach), 6 (at its place within this) |
| `min_intent_time`, `tell_time`, `reaction_floor` | `float` | 0.4, 0.3, 0.2 |
| `switch_ratio`, `switch_px`, `switch_hold_time` | `float` | 0.25, 48, 0.5: ALLIES' target pick ("Tier B's resource") |
| `alert_radius_px`, `alert_delay` | `float` | 192, 0.4 |
| `alert_pose_time`, `alert_sound` | `float`, `SoundEvent` | *(added AI2)* 0.4, `sound_enemy_alert.tres` (the shout's look and sound) |
| `leash_px`, `leash_out_of_reach_time` | `float` | 384, 6 |
| `return_speed_ratio`, `return_ignore_time`, `recover_time` | `float` | 1.3, 2, 1.5 |
| `reach_check_time` | `float` | *(added AI2)* 0.5 (a path to its target checked at most this often) |
| `tokens_per_target` | `Array[int]` | by difficulty tier: 2, 2, 2, 3, 3 |
| `token_hold_time`, `token_rest_time` | `float` | 4, 1.5 |
| `respect_by_role` | `Dictionary` (StringName → float) | `ultimate` 4, `core` 2, `mobility` 2, `defensive` 1.5, `generator` 1, `companion` 0 |
| `respect_cc_bonus` | `float` | 1 |
| `ally_respect_weight`, `ally_respect_range_px` | `float` | 0.5, 320 |
| `idle_time`, `idle_pressure`, `low_health`, `low_pressure` | `float` | 1.5, 0.5, 0.4, 0.5 |
| `major_tags` | `Array[StringName]` | `ultimate`, `charge_up`, `dash`, `leap` *(built AI-D1, in the Combos group: THREATENED's `major` filter; `charge_up` also matches a CHARGE_UP cast style; AI6's whiff rule reads it too)* |
| `whiff_time`, `punish_turn_time` | `float` | 0.3, 0.6 |
| `dodge_distance_px`, `dodge_time` | `float` | 64, 0.2 |
| `ambush_telegraph_time`, `spawn_in_telegraph_time` | `float` | 0.6, 0.8 |
| `sleep_distance_px` | `float` | 0 (never) until the P-spike measures it |
| `intent_scores`, `caster_poke_score`, `intent_hold_bonus` | `Dictionary`, `float`, `float` | *(added AI1)* each intent's base score (Scoring: hold 0.3, poke 0.5, commit 0.65; the later intents with their steps; AI-D1: peel 0.9), 0.6, 0.15 |
| `patience_respect_cut` | `float` | *(added AI1)* 0.75: the patience formula's respect cut |
| `commit_hits`, `commit_max_time`, `back_off_time` | `int`, `float`, `float` | *(added AI1)* 2, 4, 2: a commit's end and the walk back out (The standoff) |
| `hold_replan_time`, `strafe_step_px`, `strafe_turn_min`, `strafe_turn_max` | `float` | *(added AI1)* 0.25, 40, 2, 4: the hold's movement |
| `cautious_time`, `cautious_patience_cut` | `float` | *(built AI3b)* 3, 0.5 (Confidence) |
| `spend_roll_time`, `spend_min_champions` | `float`, `int` | *(built AI3b)* 2, 2 (Spending the key ability: `spend_value_bar` became the area count, found while building) |
| `walk_velocity_time` | `float` | *(added AI3b)* 0.2 (aim lead: the walk read over this long) |
| `crowded_clear_time`, `crowded_clear_px` | `float` | *(built AI3b)* 1, 16 (an episode ends after this long this far outside) |
| `smell_blood_mult`, `smell_blood_cap` | `float` | *(built AI3b)* 1.3, 0.89 |
| `rank_strength`, `champion_strength` | `Dictionary[EnemyData.Rank, float]`, `float` | *(built AI3c; Ryan, 2026-10-04)* fodder 0.25, regular 1, elite 2, boss 4; 1.5 (`get_rank_strength()`) |
| `odds_threshold`, `odds_pressure` | `float` | *(built AI3c)* 1.5 (Ryan), 0.5 *(proposed)* |
| `odds_token_bonus`, `tokens_per_target_cap` | `int` | *(built AI3c)* 1 (Ryan; clamped to 0–1: "+1 at most"), 4 *(proposed)* |
| `weakest_pick_weight` | `float` | *(added AI3c)* 0.5: while pressing the pick compares effective distance × (1 − w + w × health) |
| `heavy_hit_window`, `heavy_hit_share` | `float` | *(built AI3c; Ryan, 2026-10-04)* 0.8 (widened from his 0.3), 0.1; only while pressing |
| `think_budget`, `think_rate_floor` | `float` | *(built AI3c, proposed)* 200, 5 (thinks a second; 200 is about 1.5 ms a tick at today's think cost: Performance; Ryan kept 200, 2026-10-05, with elites and bosses exempt, their thinks taken off the top) |
| `crowding_weights` | `Dictionary` (StringName → float) | *(Combos; built AI-D1, proposed)* `near` 0.6, `closing` 0.15, `gap_closer` 0.3, `hits` 0.3 (and `cc` 0.4, read only by the ally) |
| `crowding_closing_full`, `crowding_recent_time`, `crowding_hit_window`, `crowding_hits_full` | `float`, `float`, `float`, `int` | *(Combos; built AI-D1, proposed)* 400 (u/s), 1, 3, 3 |
| `opening_weights` | `Dictionary` (StringName → float) | *(Combos; built AI-D1, proposed)* `escapes_down` 0.5, `cc_by_other` 0.5, `recovering` 0.4, `committed` 0.4, `cornered` 0.2 |
| `opening_cc_min_left`, `cornered_check_px` | `float` | *(Combos; built AI-D1, proposed)* 0.5, 48 (1.5 m) |
| `plan_max_time`, `plan_odds_drop` | `float` | *(Combos, AI-D2, proposed)* 6, 0.33 |
| `mixup_delay_min`, `mixup_delay_max` | `float` | *(Combos, AI-D2, proposed)* 0.4, 0.8 |

*(AI1 built the ranks, `think_rate`, `min_intent_time`, `tell_time`, `reaction_floor`, the respect and patience rows and the added rows. AI2 built `pack_think_rate`, the fodder ring, the switch, alert, leash, return and token rows, and its added rows; each later row comes with its step.)*

### RankRules (`rank_rules.gd`; inline in the table)
`rank`, `has_brain` (fodder false), `can_dodge` (elites and bosses), `token_cost` (regular 1, elite 2; 0 = no tokens), `tenacity` (elite 0.2, boss 0.4; a FLAT `tenacity` modifier at spawn under `&"enemy_rank"`), `max_abilities` (0, 2, 3, −1 = any; the enemies test checks every EnemyData), `brain_adjust: BrainAdjust`. *(Duels and odds)* `think_rate` (*built AI3c*: 0, 10, 15, 25; −1 = the table's; a duelist elite takes the boss's) and `think_budget_exempt` (*built 2026-10-05, Ryan*: elite and boss true: always their full rate), and in AI3d `max_abilities` 0, 3, 5, 6 with `min_abilities` 0, 2, 3, 4 (Ryan's kit answer: Kits; *built AI3d*: the enemies test warns below the minimum, as for overrides). *(Combos, AI-D3; Ryan 2026-10-05)* `cc_diminishing` (fodder false, the rest true: given to the unit's StatusComponent at spawn), `poise` (false; the hook for bosses, built later: Enemies being combo'd).

### Additions to existing data
| Where | Addition | Default | Notes |
|---|---|---|---|
| `Ability` | `ai_uses: Array[AIUse]` | `[]` | empty = one `damage` use with no rules |
| `Ability` | `respect_value: float` | −1 | −1 = derived (Respect) |
| `Ability` | virtual `get_effect_area(caster, ctx) -> Dictionary` | from its tags and params | where the cast will land: `{kind: &"circle" / &"cone" / &"segment" / &"none", ...}` in px; perception reads it for party casts, and the ally brain for enemy casts. Kit abilities override it when the default misreads them. *(Built AI3: the kinds none, unit, circle, cone, segment; `Ability.covers_unit()`; Cleave, Lunge and Judgement Leap override it)* |
| `Ability` | virtual `get_ai_plan(caster, situation) -> CastPlan` | ALLIES' shared default | built in AI1 (ALLIES AL4 adds the Knight's); `situation` is ALLIES' `sense` |
| `Condition.Kind` | `THREATENED`, `TARGET_WHIFFED`, `RESPECT` | | appended; read the situation |
| `Condition.is_met()`, `all_met()`, `first_failed()` | an optional last argument `situation: SituationContext` | null | the three new kinds read it; the old kinds ignore it |
| `Enemy` | `data: EnemyData`, `naive_casting: bool`, `get_brain()`, `get_pose()`, `get_pose_progress()` | null, true | |
| `DifficultyTier` (DUNGEONS.md) | `brain_adjust: BrainAdjust` | | the tier's slider adjust and token bonus |
| `DungeonData` (DUNGEONS.md) | `roster: EnemyRoster` | | the type DUNGEONS left to this doc |
| Events | `pack_alerted(pack, target)`, `boss_phase_changed(boss, phase_index)`, `boss_reset(boss)` | | reserved names |
| Vocabulary | **rank**, **role**, **brain**, **situation**, **intent**, **use rule**, **respect**, **patience**, **attack token**, **tell**, **pose**, **pack**, **alert**, **leash**, **whiff**, **punish window**, **pressure**, **breather**, **director**, **faction**, **spawn-in**, **ambush** | | for CONVENTIONS.md, on approval |
| Vocabulary *(Duels and odds, proposed)* | **duelist** (Ryan's word), **key ability**, **cautious**, **crowded** (an **episode**), **answer**, **all in**, **kiting step**, **smell blood**, **strength**, **odds**, **press**, **heavy hit**, **enemy ability library** | | for CONVENTIONS.md, on approval; "press" sits beside "pressure" (patience's push, a boss's phase): Open questions |
| `Ability` *(Combos, proposed)* | `combo_roles: Array[StringName]` | `[]` | `opener`, `extender`, `finisher` (AI-D2; *built AI-D1*, ahead of it: a setup opens with an `opener`-role ability) |
| `Ability` *(Combos, proposed)* | `recovery_time: float` | 0 | after its effect the caster can't move, attack or cast for this long (locks `&"recovery"`): a finisher's long recovery, the player's opening (AI-D1; *built*: `AbilityComponent.is_recovering()`, `get_recovery_left()`, `RECOVERY_LOCK`; a free cast isn't blocked; `cast_finished` comes at the effect's end, the recovery after it) |
| `Ability` *(Combos, proposed)* | `castable_while_cc: bool` | false | it can be cast while crowd-controlled (break free; AI5) |
| `Condition.Kind` *(Combos, proposed)* | `CROWDING`, `OPENING`, `TARGET_ESCAPES_READY`, `TARGET_CORNERED` | | appended; read the situation (AI-D1; *built*: 10–13, `TARGET_ESCAPES_READY` reads `count`). `THREATENED` reads `status_tag` as the incoming ability's tag (`major` = any of `major_tags`) |
| `StatusComponent` *(Combos; COMBAT.md; built AI-D3 2026-10-07)* | diminishing returns for counted `cc` statuses; `cc_diminishing: bool`, `cc_rules: CrowdControlRules`, `poise: bool` (the hook) | true, the default rules, false | AI-D3; `status_cc_immune.tres` (tags `cc_immune`, `buff`; a ring at the feet), `crowd_control_rules_default.tres` |
| `ChampionData`, `AllyStance`, `AllyTable` *(Combos, proposed; ALLIES.md)* | `combo_plans`; the five planner sliders per stance; the reads' weights | | AI-D4, with ALLIES AL6 |
| Events *(Combos, proposed)* | `cc_applied(unit, source, status, duration, dr_step)`, `cc_refused(unit, source, status, reason)`, `combo_plan_started(unit, target, plan)`, `combo_plan_ended(unit, target, plan, reason)` | | reserved names on approval (Feedback hooks) |
| Vocabulary *(Combos, proposed)* | **combo plan** (an enemy's or an AI-driven champion's planned chain of abilities; not the basic attack combo), **step**, **opener**, **extender**, **finisher** (as the combo's: the last, heavy hit), **combo role**, **peel**, **setup**, **crowding**, **the opening**, **follow-through** (**reset** or **stay**: Ryan, 2026-10-05), **diminishing returns**, **poise** (later) | | for CONVENTIONS.md, on approval; "combo" already means the basic attack chain (CONVENTIONS), and "role" means an enemy's role and an ability's role tag: Open questions |

### Test and sandbox data
- `enemy_slime.tres` (fodder) and `enemy_slime_elite.tres` (an elite brute with the slam), set on today's scenes in AI1, so the slimes keep their look and numbers.
- Test enemies, capsules in their own colors: `enemy_test_brute.tres` (a telegraphed smash), `enemy_test_skirmisher.tres` (a gap-closer leap and a stab), `enemy_test_caster.tres` (a poke bolt, a `defend` shield, an `escape` blink), their elite versions, and `enemy_test_boss.tres` with a three-phase plan. Their abilities follow CONVENTIONS' file names (`test_brute_q_smash.tres`...).
- `SandboxBrains` in `sandbox.tscn` and `sandbox_3d.tscn`, and a brain corner in the sandbox to fight them in.
- `ScriptedController` (`res://scripts/tests/scripted_controller.gd`): a `UnitController` that plays a list of steps (walk to, cast a slot at, swing, wait) on a champion unit; ALLIES AL1's scripted test controller is the same class. *(Built AI1: `play(steps)`, each step a Dictionary `{op = walk_to / cast / swing / wait, ...}`; a walk is a `move_to()` order, which a Player's PlayerInput leaves alone in a test.)*
- *(Built AI1)* `enemy_test_brute.tres` (a regular brute: 600 health, chip-band 26 basic attacks, 300 move speed; `test_brute_q_smash.tres`: the slam's script, POINT, 250 range, a 0.7 s telegraph, a 64 px circle, 80 damage, 5 s cooldown) in `scenes/enemies/test_brute.tscn`, and the slimes' data. A test scene needs a navigation region: without one, `MovementComponent.move_to()` heads for the world's origin (`map_get_closest_point()` with no regions), which once dragged the test brute through the Knight.
- *(Built AI3; the kits split by the rank caps: Ryan, 2026-10-04)*
  - **`enemy_test_skirmisher.tres`** (a regular skirmisher: 450 health, 24 damage, 345 move speed) with two abilities:
    - `test_skirmisher_q_leap.tres` (`scripts/abilities/test_skirmisher/leap.gd`): a real leap (Ryan, 2026-10-04). A 0.5 s cast filling a 48 px landing circle beside its target, then a 0.4 s leap over everything and 45 damage on landing; 600 range, 6 s, `gap_close`.
    - `test_skirmisher_w_stab.tres`: the slam's script, a 26 px circle, 0.35 s, 35 damage, 3 s.
  - **`enemy_test_caster.tres`** (a regular caster: 380 health, a slow 14-damage slap as its close option, 300 move speed, notices from 850 u) with two abilities:
    - `test_caster_q_bolt.tres`: the test bolt's script, 0.4 s, 950 range, 750 u/s, 30 magic damage, 2.5 s, `poke`.
    - `test_caster_e_blink.tres` (`scripts/abilities/test_caster/escape_blink.gd`): 0.15 s, 450 range, stops at walls, 10 s, `escape`.
  - **`enemy_test_caster_elite.tres`**: the same, elite, plus `test_caster_w_guard.tres` (`scripts/abilities/test_caster/guard.gd`): a 150 shield for 3 s, 8 s, `defend` with THREATENED within 1 s.
  - **Scenes:** `scenes/enemies/test_skirmisher.tscn`, `test_caster.tscn`, `test_caster_elite.tscn`.
  - **Later:** the elite skirmisher comes with dodging (AI4).
- *(Built AI3d: full kits from the library; Ryan, 2026-10-04)* The test brute: smash, cleave arc (`test_brute_w_cleave_arc.tres`), charge (`test_brute_e_charge.tres`). The test skirmisher: leap, stab (30 damage now), flurry (`test_skirmisher_e_flurry.tres`). The test caster: bolt, lobbed orb (`test_caster_w_lobbed_orb.tres`), blink away. The elite test caster: bolt, guard, blink away, snare (`test_caster_r_snare.tres`). The elite slime: slam, shockwave (`slime_elite_w_shockwave.tres`), big hit (`slime_elite_e_big_hit.tres`). The elite slime is placed only in the two sandboxes (room_01 has slimes only).
- *(Combos, proposed; AI-D1–AI-D2)* **`enemy_test_duelist.tres`** (an elite brute flagged `duelist`; `data/units/test_duelist.tres`) in `scenes/enemies/test_duelist.tscn`, with `test_duelist_q_snare.tres`, `test_duelist_w_guard.tres` (the library's guard: Ryan, 2026-10-05), `test_duelist_e_strike.tres` and `test_duelist_r_finisher.tres`, and its three plans (The test duelist). Shift+H's cycle gains it.
- *(Built AI-D1, 2026-10-06)* The duelist as above in `scenes/enemies/test_duelist.tscn` (a steel blue capsule); its plans come with AI-D2.

## Architecture / contracts
### Brains (autoload, `res://scripts/autoload/brains.gd`) *(built AI1: the table, the generator, the schedule, the shared read; AI2: the enemies with data, tokens, the shout, the fodder ring; whiffs AI6, sleep AI7)*
- Registered after `Progress` and `Loot` (and the planned `Companions`, `Allies` and `Dungeons`), before `Audio` (which stays last).
- *(Built AI1)* `get_time()` (game time), `get_think_period()`, `get_brains()`, `wake(brain)`, `get_party()` (the groups `player` and `party`, each once), `get_idle_time(unit)` (tracked every tick while brains exist), `difficulty_tier` (1; the stand-in until DUNGEONS D8: which ability slots exist), and the measuring hooks `get_think_stats()` / `reset_think_stats()` / `get_snapshot_builds()`. *(AI3: `wake_at(brain, time)`: a think at a game time, for an attack seen coming once the reaction time has passed; the snapshot carries the projectiles in flight.)*
- `table: EnemyAITable`; `rng: RandomNumberGenerator` (seedable; each brain draws its own stream from it).
- **The think schedule:** `register(brain)` / `unregister(brain)`. Each physics tick, in game time (hitstop slows it, the pause stops it), it lets the brains due on that tick think: each brain gets a fixed tick slot, so at 60 Hz and 10 thinks a second a sixth of them think on each tick. **Urgent wake-ups:** a new attack coming at a brain, its token lost, its target gone, a stun ending: that brain thinks on the next tick.
- **The shared read:** `get_snapshot() -> PartySnapshot`, built at most once per physics tick, the first time a brain asks.
- **Tokens:** `request_token(enemy, target) -> bool`, `release_token(enemy)`, `get_token_holders(target)`; the queue and timeouts of Groups. *(Built AI2, plus `request_token()`'s `patience`, `release_token()`'s `rest`, `get_tokens_per_target()`, `get_token_cost()`, `get_tokens_free()`, `get_token_target()`, `has_token()`, `is_waiting_for_token()`, `get_token_rest_left()`; releases each tick.)*
- **Whiffs:** listens to `Events.ability_cast` and `Events.unit_hit` for party members' major abilities and keeps each champion's punish window (Punish).
- **Packs and sleep:** packs register; `is_asleep(unit)` once sleeping exists. *(Built AI2: each enemy with data registers itself (`register_enemy()`, `get_enemies()`); a `Pack` doesn't. `shout(shouter, target)` and the alerts' delivery; the fodder ring (`get_pack_think_period()`, one ring per target with its kept angle, the crowding check). `get_party()` is read once per tick.)*
- `debug_draw`.

### UnitController (`res://scripts/units/unit_controller.gd`)
ALLIES.md's contract, built here first (AI1) because the enemy brain is the first controller other than the human's: a Node child of the Unit with `get_unit()`, virtual `get_aim_point()`, `get_move_direction()`, `is_human()`. ALLIES AL1 makes `PlayerInput` one and adds `AllyBrain`.

### EnemyBrain (`res://scripts/enemies/enemy_brain.gd`, extends `UnitController`)
- A child of the Enemy, added by `_apply_enemy_data()` for ranks with a brain.
- `think()`: `build_situation()` → `decide()` → `act(decision)`. Static `decide(situation, behavior, rng) -> BrainDecision`. *(Built AI1)* `decide()`'s `behavior` is the brain's resolved copy (the preset with the enemy's overrides and every adjust), and it reads the role from it. Brains calls `think()` on its tick (true when it thought); `Enemy` calls `drive(delta)` every physics tick while its brain runs (the act step: movement, the swing, the decision's cast). Static `get_patience_rate(situation, behavior, table)`. `build_situation()` gathers only the uses the brain could pick now (poke and zone always; damage and gap_close while a commit is possible): asking abilities for plans is most of a think.
- **What it keeps between thinks:** patience, the intent and when it started, the attacks it has seen and when, its dodge cooldown, its token, its commit's progress, its cornered time, its pose and when it started.
- **Every tick** (cheap): carries out the current intent's movement and presses (steering, a swing when the target is in reach), as ALLIES' ally brain does.
- Queries for the view and the overlay: `get_intent()`, `get_pose()`, `get_pose_progress()`, `get_last_decision()`. Signals `intent_changed(intent)`, `pose_changed(pose)`, `dodged()`. *(Built AI1: those but `dodged()` (AI4), plus `get_situation()`, `get_patience()`, `is_committing()`, `get_tell_left()`, `get_think_usec()`, `get_face_point()`, `resolve_behavior()` (the panel's live change). AI2: `get_token_state()`.)*
- *(Built AI3)* Perception in the think:
  - `_perceive()` fills `incoming`, with the reaction delay and `Brains.wake_at()`.
  - `_gather_uses()` also gathers `defend` (something coming) and `escape` (target inside the band's minimum).
  - `decide()` scores defend, escape and retreat; an attack coming breaks the no-flip-flop bonus.
  - The drive gains the escape walk (`_drive_escape()`, `_corner()`), the cornered stand, the fall-back (`_drive_fall_back()`) and a caster's strafe.
  - The skirmisher's commit end and reset hop; a gap-closer's cast doesn't end a commit.
  - Static `wants_escape()`, `get_intent_pose()` (poses by role), `get_projectile_time_to_hit()`, `get_caster_strafe()`, `get_fall_back_spot()`, `is_caster()`; queries `is_cornered()`, `is_escaping()`, `is_resetting()`.
- *(Duels and odds; built AI3b, 2026-10-05)* It also keeps its key slot, its cautious time, its crowded episode and that episode's roll, and its spend roll's clock; `decide()` reads them from the situation, and the drive runs the all-in, the kiting step and the walk out to the band's far edge. Static and pure: `find_key_slot()`, `get_own_ready_share()`, `get_effective_respect()`, `roll_crowded()` (one episode's roll: {result, roll, answer}), `get_right_moment()`; queries `get_key_slot()`, `is_cautious()`, `get_cautious_left()`, `is_key_held()`, `get_spend_roll_left()`, `is_crowded()`, `get_crowded_roll()`, `get_crowded_roll_value()`, `had_crowded_answer()`, `is_walking_out()`, `get_last_lead_px()`.
- *(Duels and odds; built AI3c, 2026-10-05)* Its situation carries the odds and the press (0 for a boss); `get_effective_respect()` multiplies in (1 − `nerve` × press), `get_patience_rate()` shares one push between low health and the odds, `get_intent_pose()` takes `pressing` (hold and stalk become `press`). A heavy use is refused while another heavy hit lands within the window (`_heavy_hit_allowed()`, at gather and at cast) and noted when it starts. Static: `is_heavy_hit()`, `get_time_to_land()`; queries `get_base_think_rate()` (its rank's, a duelist elite the boss's), `get_think_rate()` (after the budget), `is_awake()`, `is_pressing()`; `scheduled_thinks` counts its scheduled thinks (tests).
- *(Combos, proposed; AI-D1–AI-D2)* It also keeps its running plan (the plan, the step, when its trigger came, what landed, its damage on the target so far, its `combo_greed` roll) and its follow-through; `decide()` reads them from the situation. The drive runs the peel (the cast, then the kiting step) and each plan step on the tick its trigger comes, never at the next think.
- *(Built AI-D1, 2026-10-06)* It keeps its opener slots, its setup (`setup_count`, `get_setup_slot()`, `is_setting_up()`, `is_setup_commit()`), its peel (`peel_count`, `is_peeling()`, `get_peel_slot()`) and what it has seen of the opening (a crowd control or a cast counts once its reaction time has passed). Static `find_opener_slots()`; `roll_crowded()` returns `peel`; queries `get_opener_slots()`, `is_in_ability_recovery()` (not `Enemy.is_recovering()`, the walk home's heal). The drive holds still for the peel's cast and through a recovery (the `recover` pose).
- *(Built AI2)* Tokens in the think: a lost token breaks a commit off or ends it (`_check_token_lost()`), full patience asks (`_ask_token()`), a decision other than `commit` lets a held token go; `_end_commit()` releases with the rest, `_reset()` without.
- `debug_draw`: its range band, home and leash, a line to its target while it holds a token, its dodge direction. *(AI1: the sandbox overlay draws them (I), as `Brains.debug_draw`; the band and the commit line so far.)*

### SituationContext (RefCounted, `res://scripts/enemies/situation_context.gd`)
Pure data, filled by `EnemyBrain.build_situation()` or by a test:
- **Self:** rank, role, position, health ratio, its castable slots with their `ai_uses`, casting or not, what blocks it (stunned, rooted, airborne), dodge cooldown left, patience, current intent and its age, token held, home and distance to it, cornered time left.
- **Target:** the pick (ALLIES' rules), its position, edge distance, health ratio, kit ready, whether the enemy can reach it (path, `can_reach()`), in sight, its idle time, its punish window (size and age), whether it's casting.
- **The party:** respect (and each champion's share), the number of champions, tokens free on the target.
- **Incoming attacks:** a list of `{source, ability, kind (CAST, CHARGE_UP, PROJECTILE), area, time_to_hit, age, dodgeable}`, each aimed at or covering self.
- **Packmates:** count, roles, positions of melee packmates, token holders.
- The live nodes (`target_unit`, `self_unit`) ride along for the act step only; `decide()` never reads them.
- *(Built AI3)* `incoming` ({source, ability, kind, area, time_to_hit, age, dodgeable}) and `is_threatened(within)`, `cornered`, `escaping`, `resetting`.
- *(Built AI2)* `needs_token` (false in a hand-built situation), `has_token`, `waiting_for_token`, `tokens_free`, `taunted`, `home_position`, `home_distance_px`; `target_reachable` from the path.
- *(Duels and odds)* `key_slot`, `key_ready`, `own_ready_share`, `cautious_left`, `right_moment`, `crowded` and `crowded_roll` (none, all in, back up, stand), `answers`, `target_defensive_ready`, `odds`, `press`; the target's walking velocity (for `aim_lead`). *(Built AI3b, 2026-10-05: `key_slot`, `key_ready`, `own_ready_share`, `cautious_left`, `right_moment` and `right_moment_reason`, `held_slot` (its held key: `get_best_use()` leaves out that slot's damage, cc and zone uses), `crowded`, `crowded_roll`, `walking_out`, `target_walk_velocity`, `aim_lead`, `target_cc`, `target_defensives` and `target_defensives_ready`, `key_area_champions`, the smell blood numbers; `has_answer()` in place of an `answers` list. *Built AI3c, 2026-10-05:* `odds` and `press` (0 for a boss).)*
- *(Combos, proposed)* `crowding` and `opening` (each with its terms, for the overlay), `own_kit_ready`, `target_escapes_ready`, `target_cornered`, `target_cc_left` and `target_cc_source`, `target_cc_immune`, `peel_uses`, the running plan's progress, `plans` (its `ComboPlan`s). `crowded_roll` gains `peel`.
- *(Built AI-D1, 2026-10-06)* `crowding` and `crowding_terms` with their inputs (`crowded_range_px`, `band_min_px`, `band_max_px`, `target_closing_px`, `target_gap_closer_in`, `recent_hits`, and the table's two numbers), `opening` and `opening_terms` with theirs (`target_escapes`, `target_escapes_ready`, `target_escapes_down`, `target_cc_left`, `target_cc_source`, `target_committed`, `target_recovering` (false until AI6), `target_cornered`, `opening_cc_min_left`), `major_tags` (`is_threatened(within, tag)`, `ability_has_tag()`), `opener_slots`, `setup`, `setup_opener`, `peel_pending`; `get_best_use()` takes an optional slot filter and `get_opener_use()` reads the openers. `own_kit_ready`, `target_cc_immune`, the plan and `plans` come with AI-D2 and AI-D3.

### PartySnapshot (RefCounted, `res://scripts/enemies/party_snapshot.gd`)
Per champion (the `party` group from ALLIES; the `player` until then): the unit, position, health ratio, up or downed, targetable, stealthed, `threat`, each slot's ability, ready, cooldown left and value, kit ready, its respect share, its cast in progress (ability, area, time to the effect), its punish window, its idle time. Plus the party's projectiles in flight (area, time to each point). Companions never appear. *(Built AI3: each member's `cast` (`read_cast()`: its ability, context, kind, area, time left) and `projectiles` (every projectile in flight: position, direction, speed, range left, width, team); the brain works out which reach it.)* *(Built AI3b, 2026-10-05: `total_value`, `ready_value`, `ready_defensive_value`, `defensives`, `defensives_ready` (the panic-button rule and the right moments) and `walk_velocity` (aim lead); `get_share_for()` reads a share with an enemy's own finish threshold.)* *(Combos, proposed)* Each member's crowd control (time left, source, tags), its CC immunity, and its recent gap-closers (when, where they ended). *(Built AI-D1: `escapes`, `escapes_ready`, `escape_value`, `escape_ready_value` (its `mobility` and `defensive` slots), `ccs` (`read_ccs()`: each `cc` status's id, source, time left, key) and `gap_closer`; CC immunity with AI-D3.)*

### BrainDecision (RefCounted)
`intent`, `plan: CastPlan` (null = no cast), `move_to: Vector2`, `pose`, `scores: Dictionary` (intent → score: the overlay's "why"), `reason: String`. *(Combos, proposed; AI-D2)* `combo_plan: ComboPlan` (the plan a new commit runs; null = none).

### Scoring (proposed; FREE inside these rules)
Each think, every intent the situation allows gets a score from 0 to 1, × the behavior's intent weight, × (1 ± `jitter`, seeded); the highest wins, with the current intent's +0.15 until `min_intent_time`. In short:
- `return`: 1.1 while the leash is broken (it beats everything).
- `dodge`: 1.0 when a dodgeable attack covers it, seen at least `reaction_time` ago, its roll passed, its dodge ready, nothing blocking it.
- `defend`: 0.9 when a `defend` use passes (it's `THREATENED`).
- `finish`: 0.85 when the target is below `finish_threshold` and a `finish` use passes, with a token if it needs one.
- `punish`: 0.8 when the window is at least `reaction_time` old, its one roll against `punish_greed` passed and a use passes, with a token if it needs one.
- `escape`: 0.75 inside its band's minimum, for casters and any role with an `escape` use.
- `retreat`: 0.7 below `retreat_health` (`FALL_BACK`), or a skirmisher's reset.
- `commit`: 0.65 at full patience with a token; 0 without one.
- `poke`: 0.5 when a `poke` use passes (casters 0.6).
- `hold`: 0.3, always there.
- *(Duels and odds, proposed)* Smell blood: below `finish_threshold`, `commit` and `finish` × 1.3, never above 0.89. Crowded: an all-in is a `commit` (its patience filled at once); the kiting step is a `retreat`.
- *(Combos, proposed)* `peel`: 0.9 on the think a crowded episode's roll picks it (like `defend`: it answers something already happening), then the kiting step's `retreat`. A setup is a `commit` (its patience filled at once, as an all-in is). A running plan holds `commit` (+ `intent_hold_bonus` throughout); only `return`, `dodge` and `defend` can beat it, between steps.
- *(Built AI-D1)* `peel` scores 0.9 while its episode's peel is still to cast (scored after `defend`, so a tie keeps `defend`). A setup is a `commit` whose first cast is its opener (`BrainDecision.setup`).

### ComboPlanner (`res://scripts/units/combo_planner.gd`) *(Combos, proposed; AI-D1–AI-D2)*
- Static and pure, like `decide()`; shared by `EnemyBrain` and ALLIES' `AllyBrain` (one code path, not a copy). Beside `UnitController` because both controllers use it.
- `get_crowding(situation, weights) -> float`, `get_opening(situation, weights) -> float` (each also fills its terms for the overlay); `pick_plan(plans, situation, sliders, rng) -> ComboPlan` (fit, weight × the opener's plan value, jitter, `mixup`); `next_step(plan, progress, situation)` (the step due, or why the plan ends); `get_lean(situation) -> float` and `wants_stay(situation, sliders) -> bool` (the follow-through); `can_crowd_control(situation, step)` (the no-waste rule).
- The weights and sliders come in as arguments: `EnemyAITable` and the resolved `EnemyBehavior` for an enemy; `AllyTable` and the `AllyStance` for the ally.
- *(Built AI-D1, 2026-10-06)* `get_crowding(situation, weights, terms)` and `get_opening(situation, weights, terms)` (the situation carries their inputs and the table's numbers, copied in, so the arguments stay the weights), `get_near()`, `get_biggest_term()` (the overlay). The rest comes with AI-D2.

### CastPlan and get_ai_plan() (ALLIES.md's, built here first)
ALLIES' `CastPlan` (`res://scripts/abilities/cast_plan.gd`) and `Ability.get_ai_plan(caster, situation)` with the shared default are built in AI1, since the brain needs aims. The default aims at the target where it stands now (no leading: an enemy's shot can be walked out of, COMBAT.md), wraps `get_ai_vector()` for a VECTOR ability, and copies the intents of the ability's passing `ai_uses` into the plan's `intents`. Enemy abilities override it where they need to (AI3); ALLIES AL4 adds the Knight's.

### Enemy (additive changes to `enemy.gd`)
- `data: EnemyData` (export; null = exactly today). `_apply_enemy_data()` when ready: stats, abilities by difficulty tier, the twist, the model, attack tags, and the brain for ranks with one.
- In `_physics_process`, while a brain runs the fodder routine stands down; `_try_cast_ability()` runs only with `naive_casting` and no brain.
- The fodder routine gains its pack's alert and leash (AI2) and takes its target from the shared pick.
- `_can_see_player()` moves to `WorldQuery.has_line_of_sight()`; the `Sight` node stays until Ryan OKs removing it.
- `get_pose()` and `get_pose_progress()` (the brain's, or empty).
- *(Built AI1)* `brain_enabled` and `set_brain_enabled()` (the brain switch), `get_brain()`, `is_brain_active()`, `get_brain_target()` (the player until AI2's pick), `get_rank_rules()`, `get_pose_set()`, `get_face_point()`; the rank's tenacity goes on at spawn under `&"enemy_rank"`. `attack_tags` aren't applied yet (proposal 9).
- *(Built AI2)* An enemy with data joins its pack and plays `_physics_process_pack()`:
  - `AI.RETURN` (appended).
  - Noticing through WorldQuery with a path (`_notice()`), `_wake()` and the shout, `alert(target)`, hits (`_on_damaged_pack()`).
  - The pick (`_update_pick()`, `can_pick()`, `is_inside_leash()`, `get_effective_distance()`, static `is_better_target()`, `get_taunter()`).
  - Fodder's ring (`_drive_fodder()`, `uses_fodder_ring()`, `set_ring_spot()`, `get_ring_spot()`).
  - The walk home and recovery (`start_return()`, `is_recovering()`; +30% move speed under `&"enemy_return"`).
  - Queries: `get_target()` (`get_brain_target()` reads it), `get_pack()`, `get_pack_home()`, `get_home()`, `get_known()`, `is_target_reachable()`, `has_target_in_reach()`, `knows_party_inside_leash()`, `is_cc_blocked()`.
  - `get_pose()` gives `alert` as it wakes and `return` on the way home (fodder too).
  - With its brain switched off it fights by the old routine (the chase, the naive loop) on its pick. `_can_see_player()` and the `Sight` node stay for an enemy with no data.

### Pack (`res://scripts/enemies/pack.gd`; the root of a pack scene) *(built AI2)*
- A Node2D whose Enemy children are the pack. `home` = its position when placed. An enemy placed on its own is a pack of one (its own position is home).
- The shout (`alert(target)`, `Events.pack_alerted`), the leash and the walk home, and the fodder members' group think (their spots around the target, `pack_think_rate` times a second).
- *(As built)*
  - Members register themselves (`add_member()`, `get_members()`). An enemy with data placed on its own adds a `Pack` as its own child (its pack of one).
  - The home is lazy (`get_home()`: its position the first time anything asks).
  - The leash check runs in its `_physics_process()` and calls `give_up()`; `is_fighting()`, `get_time_out_of_reach()`.
  - The shout is `Brains.shout()` (it spans packs), and `Events.pack_alerted(pack, target)` fires for each pack it wakes.
  - The fodder ring runs per target in Brains; only the pure placement, `get_ring_spots()`, is here.
  - No arena flag yet (AI7: arena and boss enemies never leash).
- *(Built AI3b, 2026-10-05)* Brains reads each champion's walk every tick while brains exist (`get_walk_velocity()`: over `walk_velocity_time`, since its last dash, push, leap or blink) and passes it in the snapshot.
- *(Duels and odds; built AI3c, 2026-10-05)* Brains also gains: `get_odds()` (each side's strength, the odds, the press; once per tick, cached by physics frame; `compute_odds()` is its pure part, `get_press()` and `get_odds_usec()` read it), each champion's heavy-hit landing times (`note_heavy_hit(enemy, target, land_time)`, `can_land_heavy_hit(target, land_time, scripted)`, `clear_heavy_hits(enemy)` when a cast is cut short), the pool's +1 while pressing (`get_tokens_per_target()`), and the schedule by rank under `think_budget` (`get_think_rate(brain)`, `get_think_scale()`, `get_think_demand()`; each brain's `next_think_tick`). `Enemy.get_pick_distance()` holds the weakest pick.
- *(Combos, proposed; AI-D1–AI-D2)* Brains also gains: the party's hits on each enemy with data over the last 3 s and the champions' recent gap-closers (crowding's terms); and, with AI6's whiff read, the opening's `recovering` term.
- *(Built AI-D1, 2026-10-06)* `get_recent_hits(enemy, window)` (the party's hits through `Events.unit_hit`, DoT ticks left out), `get_last_gap_closer(unit)` and `note_gap_closer()` (a champion's dash, through its `DashComponent`, or an ability that moves it, through `Events.ability_cast`, noted where and when it stops moving; a push alone never is), read every tick while brains exist; the snapshot carries each champion's.

### BossDirector (`res://scripts/enemies/boss_director.gd`; a child of a boss) *(proposed)*
- Reads `EnemyData.boss_plan`. Owns the phase, the tempo (pressure, breather), when `punish` and `finish` may open, and hands its brain the phase's intent weights and the intents allowed now.
- `reset()` (the boss's reset, called by DUNGEONS' arena on a death); `Events.boss_phase_changed`, `Events.boss_reset`.

### Ambush and spawn-in *(proposed)*
- **`Ambush`** (`res://scripts/enemies/ambush.gd`, `scenes/enemies/ambush.tscn`): a sim node placed with a marker. It holds its members (`members: Array[PackedScene]` and a spot for each), and its trigger: a region the party enters (a Hazard-style area with no status: WORLD_INTERACTION.md) and/or `trigger_when: Array[Condition]` (a world state, DUNGEONS.md). Triggered, it draws a telegraph at each spot for `ambush_telegraph_time`, then the members appear as one pack, awake, aggroed on the nearest party member. Leaving before it triggers leaves it waiting.
- **`EnemySpawner.spawn_in(scene, position, parent, telegraph_time) -> Enemy`** (static, `res://scripts/enemies/enemy_spawner.gd`): a floor telegraph, then the enemy, awake with instant aggro, scaled at spawn. DUNGEONS' arenas call it; summoners will.

### Sleep (with the P-spike's distance)
A unit farther than `sleep_distance_px` from every party member stops its physics, its brain and its view's sync, and wakes when one comes inside that distance less a margin (so it doesn't flicker); its pack wakes together. The sleep distance sits beyond the alert distances (3D.md, Wing scale).

### Rewards
`Progress`, `Loot` and `Companions` read XP, kill tags, the drop table and kindling from the dead enemy's `EnemyData` when it has one, else from their stand-in tables, which stay until AI7 moves every enemy onto data.

### SandboxBrains (`res://scripts/rooms/sandbox_brains.gd`; in `sandbox.tscn` and `sandbox_3d.tscn`) *(built AI1)*
- **I** toggles **the brain overlay** (B is the AB15 test blink; Ryan, 2026-10-04): over each brained enemy (screen text): its intent and pose, its top three scores, respect (and the effective respect), patience, its token (held, waiting or none), its dodge cooldown, its reaction time and its think's cost; on the floor (debug drawings): its band, home and leash, token lines. *(AI1 shows "-" for the token and the dodge, and draws the band around its target and a line while it commits.)*
- **N** opens **the tuning panel:** the brained enemy nearest the cursor is picked (`,` and `.` cycle), and its twelve sliders show as sliders (the mouse drags them; the click also swings the Knight, as any click does) with the resolved value and the preset's. A change applies at once to it and to every enemy sharing its data (an in-memory override until saved). **Ctrl+S** saves into its behavior preset (the archetype .tres); **Ctrl+Shift+S** saves an override into its `EnemyData` (a warning past three). Saving works only in a run from the editor (`OS.has_feature("editor")`), never in an exported build or a test scene. After a save, Godot reports the file changed on disk: choose Reload (CLAUDE.md, Known issues). *(Built AI1)* Its **brain** checkbox switches the picked enemy's brain off (the old routine and the naive loop) and on.
- *(Built AI3)*
  - **Shift+H** cycles the test enemy the scenarios spawn (the brute, the skirmisher, the caster, the elite caster), and the running scenario spawns it again.
  - **H** gains a mixed pack (a brute, a skirmisher, an elite caster, three slimes).
  - The incoming shot waits until the enemy is fighting, so its reaction shows.
  - The overlay adds its threats (how many, the next one's time) and cornered, escaping or resetting.
- *(Built AI3b, 2026-10-05)* The overlay's duel lines (`get_duel_text()`: `conf 0.5 × own 1.00 (key: Smash ready)` or `cautious 2.1 s`, `key: held (next roll 1.4 s)` or `key: free (crowded)`, `crowded: all in (0.31 < 0.60)` or `crowded: back up (no answer)`, `lead 0.5 (+1.2 m)`). The panel's sixteen slider rows scroll (11 show: `SLIDER_LIST_HEIGHT`), so the panel ends inside the 360 px canvas; it ran 14 px past it already with AI1's twelve and the TEMP row. *(Built AI3c, 2026-10-05)* The odds line (`odds 0.7`, or `odds 2.1, press 0.6 (nerve 0.6)` while pressing, or `odds 2.1 (a boss doesn't press)`) and the token line's think rate (`10/s`); the panel's seventeen rows; H's tenth scenario, the odds: three test brutes and the elite slime, 9 m away and idle (a full press against the full-health Knight that eases as they fall).
- *(Combos, proposed; AI-D1–AI-D2)* Shift+H's cycle gains the test duelist. The overlay adds crowding and the opening (with their biggest terms), the peel, the running plan (its name, step and what landed; why it ended) and the follow-through's lean; the panel shows the five new sliders.
- *(Built AI-D1, 2026-10-06)* Shift+H's fifth enemy, the test duelist; H's eleventh scenario, escapes down (Lunge and Iron Resolve spent, the rest ready); the overlay's combo lines (`get_combo_text()`: `crowding 0.66 ≥ 0.60 (near 0.60): peel (Snare)`, `opening 0.50 ≥ 0.50 (escapes 0.50): setup (Snare)` for an enemy with an opener, `recover 0.8 s`); the panel's nineteen sliders (twenty rows). The plan, its step and the lean come with AI-D2.
- **H** cycles **the scenarios:** all cooldowns ready, none ready, low health (25%), an ally present (a friendly stand-in dummy until ALLIES), a whiff (Judgement spent at nothing), an incoming shot (a test bolt fired at the picked enemy). *(Built AI2)* Then two packs, placed 9 m away toward the cursor on the walkable floor and idle until they notice the Knight: five test brutes (tokens, the shout, the leash) and eight slimes (the ring). The overlay shows each brain's token (held, waiting, rest, or none needed) and draws each pack's home and leash, token lines and fodder's places. Each spawns the chosen test enemy 5 m away and sets the Knight's cooldowns and health through test hooks. *(Built AI1: it spawns the test brute toward the cursor; the hooks are `AbilityComponent.start_cooldown()` / `reset_cooldown()`, the Fury pool and the health component; the whiff only starts Judgement's cooldown until AI6 reads whiffs.)*
- It never touches the player's saves.

## View
- **Every enemy is a Unit with a `UnitView`** (3D.md): a capsule in `model_color`, or `EnemyData.model_scene`. Clips, once enemies have models, come from the base clip names on `UnitView` and the pose set.
- **Pose hooks** *(proposed; built in AI1 with the brute's poses)*: each tick `UnitView` reads `Enemy.get_pose()` and `get_pose_progress()` and the enemy's `PoseSet`, and blends to that pose's look over 0.08 s (*built:* `UnitView.pose_blend_time`; the rim is a second channel, `rim`, of `flash_overlay.gdshader`, brightest at the silhouette's edge; a model's clip comes with the art pass). On a capsule: the lean (a tilt about its base, toward or away from the target), the squash (height down, width up), the rim pulse (the hit flash's additive overlay gets a second, tinted channel; the hit flash wins while it plays). On a model: the pose's clip. The view never changes gameplay state; poses come from the sim (the brain), the way cast progress does.
- The windup squash a capsule already plays during a cast stays. `crouch` differs from it by its lean and by holding before the move.
- **Floor drawings:** enemy ability telegraphs as today (COMBAT.md); the ambush and spawn-in telegraphs (`Telegraph.circle()`). No floor drawing marks a decision: tells are body language. The overlay's drawings show only with B or `debug_draw`.
- **Screen overlay:** health bars as today; *(proposed)* an elite's modifier names under its bar; a functional boss bar at the top of the screen until UI.md. No icons over heads (Ryan).
- **Sleeping** units' views stop syncing once sleeping exists.

## Audio hooks
Audio hooks: see AUDIO.md. To add when built (synthesized placeholders until real files): the alert bark (with its `alert` pose), wind-ups for enemy attacks without a telegraph, whiffs, the dodge's whoosh, a shield going up (`defend`), the pack's walk home, a boss's phase change, its pressure roar and its breather, the punish and finish wind-ups (with their telegraphs). Never audio-only (DECISIONS.md, Audio): each has a pose or a telegraph.

## How each edge case is handled
| Edge case | Handling |
|---|---|
| An enemy with no `EnemyData` | Exactly today's behavior (the fodder routine, the naive cast loop) |
| The target turns untargetable | ABILITIES AB10's rule: no new aggro; an aggroed enemy keeps chasing without attacking; a token holder releases its token |
| The target goes downed or stealthed | Dropped at once (ALLIES.md); the next pick runs; its token pool's holders release |
| The target turns stealthed, with no other candidate *(planned with Korsavil)* | It searches her last known spot for 3 s *(proposed)*, then goes back (Losing a stealthed target) |
| Feared *(planned with Korsavil)* | The brain rests, the enemy walks away from the source and can't act; a boss refuses it (Fear) |
| A taunt | ALLIES' rule: the taunter is the target while it's a candidate; the taunted enemy needs no token for it *(proposed)* |
| A token holder is stunned, rooted or knocked up | It releases its token at once and asks again after `token_rest_time` |
| A token holder dies | Its token frees the same tick |
| Every token held by enemies that can't reach | They release after the out-of-reach check; the next in the queue asks |
| The champion stands on a perch | Melee walks its route up if one exists; otherwise holds below without a token while the pack's ranged members poke |
| A champion it has no path to *(built AI2; proposed)* | Sight doesn't wake it; a hit does; after 6 s with nothing in reach the pack walks home and heals, and sight doesn't wake it again |
| Two packs' fodder (or lone fodder) on one target *(built AI2)* | One ring around the target for all of them |
| A pack built in code, then moved into place *(built AI2)* | Its home (and each member's spot) is taken at its first tick, after the move |
| Two attacks coming at an elite at once | Each is rolled once; the dodge cooldown means it dodges at most one (layered attacks beat it) |
| An attack too fast to leave | It doesn't try (time left under `dodge_time`); `defend` may still answer |
| Casting when an attack comes | It can't dodge; its cast plays out |
| A stun during a tell | The tell and its intent end; it picks again after the stun |
| A dodge toward a wall, a ledge or a pit | That side isn't free, so it takes the other; neither free = no dodge |
| A cheap ability spent as bait | Not a whiff; it lowers respect, which can draw a commit (intended) |
| A major ability that hits a destructible but no enemy | A whiff (it hit no enemy unit) |
| A boss's punish against a champion with no dash charge | Still dash-answerable by design: the dash recharges in 0.35 s, and the shape can be walked out of during a 0.6 s telegraph from its center at the Knight's speed (3.75 m/s: 2.25 m) *(proposed check)* |
| Pressure ends mid-attack | The attack plays out; the breather starts after it |
| A phase threshold crossed mid-breather | The phase change wins at once |
| Dying to a boss | `BossDirector.reset()` (DUNGEONS I8): full health, phase 1, home, cooldowns ready |
| The pack leashes while one member casts | The cast plays out, then it walks home |
| A packmate is hit while the pack walks home | It keeps walking unless the attacker stands inside the leash |
| An arena or boss enemy | Never leashes (sealed doors) |
| An ambush the party walks away from | It waits; nothing spawns until its trigger |
| A shout through a wall | Its own pack wakes anyway; other packs need sight of the shouter |
| Hitstop or the pause | Thinks run in game time: hitstop slows them, the pause stops them |
| An enemy asleep when a projectile hits it | A hit wakes it and its pack |
| A companion | Invisible: never in the snapshot or a target; its command's damage is its champion's, so a hit from it aggroes like the champion's |
| A slot with no ability below its difficulty tier | Empty; the brain never sees it |
| An elite modifier's ability with no free slot | Skipped, with a warning (the validator flags such a pool) |
| More than three overrides on an EnemyData | They apply; the test warns (kind, not magnitude) |
| Crowded with its escape ready *(Duels and odds)* | Escape wins (a caster blinks away); no roll |
| Crowded while cornered | The cornered stand; no roll |
| Crowded again right after an episode | The episode lasts until you've stayed out 1 s; a new episode rolls again |
| Two heavy hits timed on one champion | While enemies press, the second waits until its landing clears the first's 0.8 s window (a boss plan's scripted pattern is exempt); outside a press both may land, as AI2 allows |
| A boss fight with adds | The boss never presses (the director); it counts in its side's strength, so its adds can |
| The ally downed | It counts 0 in the party's strength, so the odds rise |
| Two abilities tied for its key | The earlier slot; an authored `respect_value` breaks the tie |
| A brained enemy with no abilities | No key ability: confidence and spending do nothing; crowded, it rolls the mix (no answer): back up once or stand |
| A poke while it holds its key | Never held (casters poke the whole time) |
| Its opener is dodged *(Combos)* | The plan ends, then the follow-through decides; at `combo_greed` it carries on once (a blind finisher); never a finisher after a missed opener at 0 |
| Its crowd control on cooldown, or spent on a peel *(Combos)* | Plans that need it don't fit; it opens with its strike (`strike_finish`) and never waits for the crowd control |
| No plan fits at a commit *(Combos)* | AI1's commit (its first cast, 2 landed swings or 4 s) |
| The target turns CC-immune mid-plan *(Combos)* | An optional crowd-control step is skipped; a needed one ends the plan |
| A plan longer than the token's 4 s *(Combos)* | It keeps the token to the plan's end, up to `plan_max_time` (6 s) |
| Two enemies' crowd control on one champion *(Combos)* | The second within 4 s lasts half as long; a third is refused and the champion is immune for 3 s (the ring). Nothing else caps a chain: cooldowns are the limit (Ryan) |
| A crowd control on a target already held *(Combos)* | No enemy or ally starts one while the hold left is longer than its cast time (it would be halved, or wasted) |
| The player channels Judgement on an enemy *(Combos)* | The ally holds its crowd control on that enemy; the enemy may still guard (a `major` ability aimed at it) |
| Fodder crowd-controlled twice *(Combos)* | Full duration both times (no diminishing returns) |
| A boss crowd-controlled *(Combos)* | Until poise exists: its 40% tenacity and diminishing returns |
| Crowded while a plan runs *(Combos)* | The plan holds the commit; no episode starts until it ends |
| Tests | No view; `Brains.rng` seeded; saving off (`Progress.is_test_scene()`); the panel never saves in a test scene |

## Build order (proposed; one step per request; each ends with Ryan's play test)
**Before AI1:** nothing in the code blocks it. Where it goes in the order of work is Ryan's call (Open questions): CLAUDE.md has LOOT L4 next, ALLIES.md puts the second champion before "Tier B" (AI1–AI2), and DUNGEONS.md wants AI1–AI2 before its D1. Dodging (AI4) is best tested against a ranged kit with skillshots. *(Answered: Ryan started AI1 on 2026-10-04, before the second champion.)*
Every step: Ryan runs `git status` first; the Knight's abilities, talents, enemies chasing and the HUD still work; an enemy with no `EnemyData` plays exactly as before; the new `enemies_test` suite joins the baseline (every suite green, the counts in CHANGELOG.md under an Enemies AI section); this doc keeps one line per built step.

1. **AI1 – The tooling and the brain skeleton.** `EnemyData` (the slimes and the test brute on data), `EnemyBehavior` with the twelve sliders, `BrainAdjust`, `RankRules` (with tenacity by rank), `EnemyAITable`, the `Brains` autoload (the staggered schedule, the shared snapshot), `UnitController`, `EnemyBrain` with `SituationContext` and `BrainDecision`, the intents `hold`, `commit` and `poke` for the brute, respect (derived values, `respect_value`) and patience, `AIUse` and `Ability.ai_uses`, `CastPlan` and the default `get_ai_plan()`, the `RESPECT` condition kind and the situation argument, the `tell_time` lead, the brute's poses (`PoseSet`, UnitView's pose hooks), `Enemy.naive_casting` (the naive loop off behind it), `SandboxBrains` (I, N with saving, H), `ScriptedController`, `enemies_test`. **The measured performance budget** (Performance), written into this doc. **Built 2026-10-04 (see CHANGELOG.md); passed Ryan's play test 2026-10-04.**
   **Done means:** with the brute and everything up, it holds and circles at 350–500 u; after Lunge and Judgement go down it crouches and dives; its hold always ends within 12 s (4 × its 3 s `patience_time`); dragging a slider changes it live and saving writes the .tres; the scenarios load; with the brain off the elite slime casts as before. **Tests:** an ultimate ready at 5 m → `hold`; spent → `commit`; respect from known kits; patience's fill and its floor; the same seed → the same decisions; ranks' ability counts; the naive loop gated. **Play test:** Ryan fights the test brute.
2. **AI2 – Groups (tokens, packs, alert, leash).** Token pools per target (`tokens_per_target`, rank costs, the queue, release on stun, death, out of reach, timeouts), `Pack` (home, the shout, the walk home and recovery), the fodder group think (the ring around the target, 0.6 m apart), ALLIES' target pick (nearest by `threat`, sticky with the margin, taunt, stealth, downed; tested on a second PLAYER-team dummy), sight through `WorldQuery`, the old leash replaced for packs (asked first). **Built 2026-10-04 (see CHANGELOG.md); passed Ryan's play test 2026-10-04.** Ryan's answers first: the performance fix is the cap (Performance), the pack rules for every enemy with data, ALLIES' `threat` and status tags approved (AI2 registers `threat`).
   **Done means:** five test brutes never put more than two on you at tier 1, and they rotate; a stunned holder frees its token at once; one pack member noticing wakes its pack 0.4 s later; walking 12 m away sends them home to heal; fodder surrounds you with no tokens. **Tests:** token counts and release, timeouts, pack alert (through walls for packmates, sight for other packs), the leash and recovery, the target pick's margin, taunt and stealth. **Play test:** a pack fight in the sandbox.
3. **AI3 – Skirmisher and caster.** Range bands and positioning (ranged behind or beside melee), `poke`, `defend` (incoming attacks, `get_effect_area()`, the `THREATENED` kind), `escape` or fight (cornered), role-based retreat, the skirmisher's dive and reset, the test skirmisher and caster with their plans, their poses. **Built 2026-10-04 (see CHANGELOG.md); passed Ryan's play test 2026-10-04.** Ryan's answers first: a regular test caster (bolt, blink) and an elite one (plus the shield), the elite skirmisher waiting for AI4; the shield reads anything it sees coming, Judgement included; the skirmisher's gap-closer a real leap; AI2's two rules kept.
   **Done means:** the caster pokes from 550–800 u, shields only when something is aimed at it, blinks away when caught and squares up when its blink is down; the skirmisher dives when respect drops and hops out after its hit. **Tests:** a projectile aimed at a caster → `defend`; nothing aimed → no shield; cornered → basic attacks, no running for 3 s; low health → behind a melee packmate. **Play test:** a mixed pack.

*Duels and odds (Ryan's design addition, 2026-10-04): three steps after AI3, numbered so AI1–AI3 and AI4–AI8 keep their numbers (proposed placement; each ends with Ryan's play test).*

3b. **AI3b – The duel: confidence, spending, crowded, smell blood, aim lead.** The key ability and `own_ready_share`, cautious, `spend_eagerness` (the right moments and the roll), the crowded episode (answers, `crowded_commit`, the mix of backing up once or standing, `crowded_range`), smell blood (the scores; a ready defensive counted whole below the threshold), `aim_lead` in the default plan; the four sliders in the presets and the panel; the overlay lines; `step_back` for every role. **Changes to built behavior, approved by Ryan (2026-10-04):** AI1's walked-in rule becomes one side of the crowded mix (the other: back up once); AI1's respect below 30% counts a ready defensive whole; the presets' new starts change how the test enemies play (a brute bolder with its smash up, the caster's bolt led). **Built and passed 2026-10-05, before Korsavil's K3 (Ryan's call; see CHANGELOG.md).**
   **Done means:** with Judgement ready in its face, a brute with its smash up sometimes goes all in, and otherwise either steps back once and then stands, or stands and swings at once; with its smash spent it backs off and holds longer; at 20% with Iron Resolve up it's warier than with it down; the caster's bolt hits a Knight walking a straight line and misses one who turns. **Tests:** a player with an ultimate ready at 5 m (it holds, as in AI1) and in its face, with the enemy having an answer and not having one; its key spent versus ready (patience, cautious, the same seed giving the same rolls); one all-in roll and one mix roll per episode (backing up at about 1 − `aggression`); escape and cornered still win; the player at 20% with and without a shield ready; a poke never held; aim lead against walking, stopping and dashing targets. **Play test:** Ryan duels the test brute, the skirmisher and the elite caster.
3c. **AI3c – Odds, and think rates by rank** (AI2's token code reopened). The strength read and `get_odds()`, the press (respect × `nerve`, the shared patience push, +1 token under the cap, the weakest pick), the heavy-hit window while pressing (Brains' landing times; 0.8 s, heavy at 10% of max health), the `press` pose and the overlay's odds line, `nerve`, the `duelist` flag; `RankRules.think_rate` and `think_budget`, measured again with the odds read added. Outside a press nothing built changes (Ryan kept AI2's heavy-hit behavior there). **Built 2026-10-05, right after AI3b and a warnings cleanup (Ryan's call; see CHANGELOG.md); passed Ryan's play test 2026-10-05.** Think rates by rank change elites (15 a second, from 10) everywhere; the press changes any fight past the odds (AI2's five brutes: a third token).
   **Done means:** alone against three test brutes and an elite you feel them press (a third attacker, quicker commits, the amber lean); against one brute nothing changes; with the ally down they turn on you; while they press, never two heavy hits within 0.8 s. **Tests:** the odds in a 1v1, a 3v1 and an elite plus fodder against the player and the ally (each side's strength worked out by hand, a champion at 1.5); the pool +1 and never past the cap; the weakest pick with the margin, taunt and stealth; a heavy-hit stacking case refused while pressing (a boss plan's allowed, and outside a press allowed as in AI2); a duelist thinking at the boss's rate; thinks per rank over 10 s, the budget's scaling, reaction times unchanged, a gap-closer's follow-up never waiting a reaction time. **Play test:** a 1v1, a 3v1 and a mixed pack.
3d. **AI3d – The enemy ability library, part 1, and full kits** (Ryan's kit answer: Kits). The starter archetypes that need nothing new (all but the pool, which waits for WORLD_INTERACTION's Hazards) as shared scripts and templates; the test enemies re-kitted to the new counts; `RankRules`' caps; the telegraph rule checked by the enemies test. It could come before AI3b, so AI3b's play test has full kits (Ryan's call). **Built 2026-10-04, first of the three (Ryan started it; see CHANGELOG.md); passed Ryan's play test 2026-10-04.** Ryan's answers first: the elite slime re-kitted (slam, shockwave, big hit), more enemy slots with bosses (AI6), the test kits as proposed, the stab at 30.
   **Done means:** the test brute, skirmisher and casters fight with full kits built from the library, none authored from scratch. **Tests:** every library ability telegraphs at least 0.6 s unless it's in the chip band and faster than the reaction time on purpose; each rank's ability count in its band; each archetype's `ai_uses` pass where they should. **Play test:** the mixed pack with full kits.

*Combos, crowd control and the test duelist (Ryan's design addition, 2026-10-05): four steps after AI3c (proposed placement; each ends with Ryan's play test). They're named AI-D1 to AI-D4, not D1–D4, because DUNGEONS.md already has D0–D9. AI-D1 needs AI3b's crowded episode and AI3c's `duelist` flag; AI-D4 waits for ALLIES AL6.*

D1. **AI-D1 – The test duelist, crowding and the opening (no plans yet).** The duelist (its EnemyData, stats and scene; its four abilities as library copies, the guard a plain shield (Ryan); `Ability.recovery_time` and the `recover` pose; Shift+H). `ComboPlanner`'s two reads. Crowding starting the crowded episode, the peel and the `peel` intent tag. The opening and the setup: in this step a setup is a commit that opens with its best `opener`-role ability, and plans come next. The condition kinds `CROWDING`, `OPENING`, `TARGET_ESCAPES_READY`, `TARGET_CORNERED` and THREATENED's tag filter. `peel_threshold` and `opening_bar` in the presets and the panel, with their overlay lines. **Changes to designed behavior (approved by Ryan, 2026-10-05):** AI3b's episode starts from crowding (inside `crowded_range` still enough on its own), and a failed all-in roll peels first when a `peel` use passes. **Built 2026-10-06 (passed 2026-10-07), right after AI3c (Ryan's call; see CHANGELOG.md); awaiting Ryan's play test.**
   **Done means:** crowd the duelist and it snares you and steps back (or goes all in); spend Lunge and Iron Resolve and it comes at you snare first; aim Judgement at it and it guards; its finisher's recovery is a window you can punish. **Tests:** crowding's terms and its start (inside the crowded range, a Lunge in to 2.75 m, a string of hits); a peel in every episode at `crowded_commit` 0; the opening's terms (escapes, crowd control by another, committed, cornered); a setup at the bar and not below; an enemy with no `peel` use or opener plays AI3b's episode unchanged; THREATENED filtered by `major` (Judgement aimed at it yes, a Cleave no); `recovery_time` locks moving, attacking and casting; the shield's two `defend` uses (a `major` ability aimed at it; low health while crowded). **Play test:** Ryan duels the duelist.
D2. **AI-D2 – Combo plans and the follow-through.** `ComboPlan`, `ComboStep`, `combo_roles`, the duelist's three plans; picking a plan (fit, weight, `mixup`); the step timings and windows; the ends; no blind finishers and `combo_greed`; the token kept to the plan's end (`plan_max_time`); the follow-through (the lean, `follow_through`); `Events.combo_plan_started` / `combo_plan_ended`; `follow_through`, `combo_greed` and `mixup` in the presets and the panel; the overlay's plan and lean lines; the enemies test's opener check.
   **Done means:** the duelist opens with its snare when your escapes are down and with its strike otherwise, never waits for its snare, finishes only after a landed opener, and after a plan backs off when your kit is up and stays on you when it's spent. **Tests:** pressure high leads to a peel and pressure low with the target's escapes down to a setup (from AI-D1, now with the plan); an opener that misses ends the plan; no finisher after a missed opener at `combo_greed` 0, and a carry-on at its rate; with its crowd control on cooldown (or spent on a peel) it still opens with the strike and finishes; a plan with no crowd control works end to end; the follow-through resets when its kit is spent and the player's is ready, and stays when it's the other way round (the worked example's four cases); the plan's own steps never wait a reaction time; the token kept to the plan's end and never past 6 s; `mixup`'s runner-up rate; each end reason. **Play test:** Ryan duels the duelist again, then the mixed pack with it.
   *Built 2026-10-07 (CHANGELOG.md).* With Ryan's blind read (2026-10-07), "with its strike otherwise" holds only on the blind read (your escapes or your ultimate down, you held or low); with your kit up and you healthy it waits for its snare and keeps its follow-ups. **Passed 2026-10-07** (Ryan).
D3. **AI-D3 – Diminishing returns on crowd control.** Diminishing returns in StatusComponent (every unit, fodder off through `RankRules.cc_diminishing`; `CrowdControlRules`; COMBAT.md), `status_cc_immune` and its ring, `Events.cc_applied` and `cc_refused` (with `POISE` reserved for later), `RankRules.poise` (the hook, off), the crowd control types allowed on the player (a root up to 1 s, a stun up to 0.5 s; the enemies test checks every enemy ability that applies one). No combo budget and no kill protection (Ryan, 2026-10-05: cooldowns are the limit). **A change for every unit** (Ryan): a second crowd control within 4 s is halved, the Knight's on enemies included.
   **Done means:** rooted twice in 4 s, the second root is half as long; a third doesn't take, and a ring shows you're immune for 3 s; the same on enemies (Judgement, then a stun from Lunge, on an elite); fodder takes every stun in full. **Tests:** a second crowd control within the window halved, a third refused and the unit immune, the count starting over after the immunity; tenacity first, then diminishing returns; slows and knock-ups not counted; fodder taking full durations; a boss taking diminishing returns with its 40% tenacity (poise is later); the events' payloads and reasons; the existing suites' crowd control checks (any that crowd-control one unit twice within 4 s change their expectations, listed when built). **Play test:** the duelist and the elite caster together.
   *Built 2026-10-07 (CHANGELOG.md); passed Ryan's play test the same day.* The only crowd control enemies put on the player today is the three snares' 1 s root. The existing checks that crowd-controlled one unit again and again (combat's C9 re-stun, abilities' AB15 roots) now switch diminishing returns off for their stretch; the rule's own checks are combat_test's and enemies_test's AI-D3 sections.
D4. **AI-D4 – Ally parity** (with ALLIES AL6, after AL1–AL5). `AllyBrain` calls `ComboPlanner` (the reads and the plans); `AllyStance`'s five sliders and `AllyTable`'s weights; `ChampionData.combo_plans` (the Knight's Lunge → Cleave); the no-waste rules, the follow-up and the peel for the player.
   **Done means:** the ally holds its crowd control on what you've just stunned and hits it instead, follows your crowd control with its payoff, and peels an enemy off you when you're swarmed. **Tests:** the ally holds its crowd control on a target the player already crowd-controlled (and on one under Judgement's channel) and follows up on one the player just crowd-controlled (no reaction wait, the cast delay kept); the peel from the player's crowding; the stance's sliders; nothing read from the enemy table. **Play test:** with the ally (ALLIES AL6's).

4. **AI4 – Dodging.** The sidestep (elites and bosses), the reaction delay, one roll per attack, the dodge cooldown, never while casting or crowd-controlled, the free-side check, the `sidestep` pose; which party abilities are dodgeable (Dodging).
   **Done means:** an elite sidesteps a Cleave Wave thrown from range a beat late, never twice inside its cooldown, never a Judgement; a stunned or casting elite takes the hit. **Tests:** no dodge before the reaction time; none on cooldown; none while casting, stunned, rooted or airborne; never into a wall or off a ledge; fodder and regulars never dodge. **Play test:** baiting and beating a dodging elite.
5. **AI5 – Elite modifiers.** `EliteModifier`, the roster's pool, the count by difficulty tier (a sandbox key stands in for the tier until DUNGEONS D8), the first pool (Fast, Shielded, Teleporting with `blink()`, Vampiric, Volatile with its area effect), excludes, the names under the bar.
   **Done means:** elites roll the right count with no excluded pairs; each modifier changes how the fight plays. **Tests:** seeded rolls, counts per tier, excludes, sources removed exactly, the blink's use rules. **Play test:** each modifier on the test brute.
6. **AI6 – The boss director.** `BossPlan`, `BossPhase`, phases and transitions, the pressure and breather tempo, `punish` (whiffs, `TARGET_WHIFFED`, window sizing), `finish`, the knowledge of the ally's cooldowns, `reset()`, the test boss and its arena corner.
   **Done means:** the boss's tempo reads; a whiffed Judgement draws a telegraphed punish a dash answers; below 30% it goes for a telegraphed finisher; dying resets it cleanly. **Tests:** no punish without a real whiff (a landed ultimate opens nothing); window sizes pick the right attack; phase thresholds; the breather allows only pokes and zones; reset restores everything. **Play test:** the test boss.
   *(Ryan, 2026-10-04)* It also builds **boss passives:** `BossPlan.passive` and `passive_aura`, `BossPhase.passive`, the passive on the boss bar and the `passive` pose (Bosses). **Tests:** the passive applies under its source, swaps by phase, and is removed and put back by the reset; its state shows on the boss bar.
7. **AI7 – Faction and tier hooks, ambushes and spawn-in, sleep, enemy data for rewards.** `EnemyRoster` with its faction preset and pool, `DifficultyTier.brain_adjust` (or its stand-in until DUNGEONS D8), `Ambush`, `EnemySpawner.spawn_in()`, sleeping (with the P-spike's distance), XP, kill tags, drop tables and kindling read from `EnemyData` (the stand-ins retired with Ryan's OK).
   **Done means:** the same pack plays differently under two factions and harder at tier 5; an ambush emerges with its telegraph and aggro; far packs sleep and wake together; kills give XP, tags and drops from data. **Tests:** the adjust chain, ambush triggers, spawn-in aggro, sleep and wake, the rewards matching the old tables. **Play test:** a faction pair at two tiers.

**Milestone AI-M – Real fights** (after AI7): Ryan plays the sandbox's brain corner and a test room of mixed packs, an elite and the test boss at tiers 1 and 5. **It also covers:** the open judgment call in CLAUDE.md (do the Knight's low-health rewards feel like real risk or too safe, now that real enemies can stress them?), the tells question (are poses enough at the camera's distance, or is a small icon needed after all?), and then deleting the naive cast loop with Ryan's OK.
**Done means:** Ryan's play test: fights are tactical, enemies are dangerous but readable, every loss was readable, nothing stalls, and the frame holds.

8. **AI8 – The later roles** (Ryan, I11: right after the milestone, before DUNGEONS' slice). **Support** (heals, shields or buffs other enemies through `heal`, `shield` and `buff` uses aimed at a packmate; falls back like a caster), **summoner** (makes adds through `EnemySpawner.spawn_in()`, its adds counting against a cap), **perched sniper** (a ranged role on a perch: `elevated`, its dead zone, targets through `can_reach()`, every perch noting its answers: 3D.md). Each is a new `EnemyBehavior` and test enemies on the same brain; no new brain code beyond what a role's intents need.
   **Done means:** each plays its role in a mixed pack and has an answer every champion can use (a support's heal can be interrupted by CC or punished by focusing it; a summoner's adds stop when it dies; a sniper can be reached, pulled or outranged). **Tests:** each role's intents in decision tests; the adds cap; the sniper's dead zone and the melee rule. **Play test:** Ryan fights each.

## Out of scope
Arena waves and mid-fight reinforcements (deferred; Spawning); habit reading for bosses; enemies knocking up the player (3D.md: only telegraphed boss attacks are candidates, later); the AI ally's own decisions (ALLIES.md); the launch rosters, factions and bosses themselves (content, with DUNGEONS' slice); enemy models and clips (the art pass); the polished boss bar (UI.md); the optimization and cleanup pass over all AI (after ALLIES, as ALLIES.md says).

## Open questions
### Interview (Ryan, three rounds, 2026-10-03: all answered, each as Claude proposed)
1. ~~**I1 – The slider list:** which sliders, what each does, and the default ranges per role.~~ Answered: **all twelve**, in one preset per role (bosses read pressure, breather and finisher; the others ignore them); each enemy overrides at most three. The role starts stay TARGET (Tuning toolkit).
2. ~~**I2 – The respect formula:** authored ability value vs derived, and how heavily the ally's abilities count.~~ Answered: **derived with an authored override** (the role tag, +1 for crowd control; `respect_value` overrides), and **the ally's ready kit counts half** while it's within 10 m (Respect).
3. ~~**I3 – Token counts** by rank, difficulty tier and party size.~~ Answered: **2 per champion, 3 at difficulty tiers 4–5;** a regular holds 1, an elite 2; an ally brings its own pool; holders rotate after 4 s (Groups).
4. ~~**I4 – Reaction time and dodge numbers per rank,** and which abilities enemies may dodge.~~ Answered: **reaction 0.45 s for regulars, 0.35 s for elites, 0.3 s for bosses, never under 0.2 s;** elites try 40–60% of dodgeable attacks with a 4–6 s cooldown; higher tiers sharpen both; **dodgeable:** skillshots, charge-ups, VECTOR lines, slow areas; **never:** point-and-click (Judgement) and fast casts (Cleave, Lunge, swings) (Dodging).
5. ~~**I5 – Pack alert radius and delay, the leash distance, the recovery after a leash.**~~ Answered: **the pack wakes 0.4 s after its first member notices;** other packs within 6 m that see it join; **the leash at 12 m from home** (or 6 s without reaching you); **home 30% faster, healed to full over 1.5 s** (Aggro, packs and the leash).
6. ~~**I6 – The fodder swarm:** spacing or flocking rules, and how a wounded fodder behaves.~~ Answered: **fodder surrounds its target in a ring about 0.6 m apart** instead of stacking; **a wounded fodder behaves the same** (Groups).
7. ~~**I7 – The pose set per role** for the capsule placeholders, and when to decide on an icon.~~ Answered: **the proposed set** (lean, squash, rim or color pulse, windup stretch; 0.3 s of pose before an attack), and **the icon question is judged at AI-M**, in its crowded fights (Tells).
8. ~~**I8 – Poise or flinch for elites and bosses.**~~ Answered: **no flinch: hits never interrupt a cast; CC does,** as today; **tenacity 20% for elites, 40% for bosses** (Poise).
9. ~~**I9 – The behavior preset and roster-entry format** DUNGEONS.md requires.~~ Answered: **as proposed:** `EnemyBehavior` per role, `EnemyData` per enemy (loaded like ChampionData), `EnemyRoster` per dungeon with its faction preset and elite modifier pool (Data).
10. ~~**I10 – Boss phases:** how many, how they're authored, how a punish window is sized.~~ Answered: **three phases by default** (100%, 66%, 33%; mini-bosses 1–2) **as data entries** (a form, weights, tempo), a **1.5 s telegraphed transition** (unstoppable, not invulnerable); **a punish by its window:** under 0.8 s the fastest hit, 0.8–1.5 s a gap-closer into a hit, over 1.5 s the all-in (Bosses).
11. ~~**I11 – When support, summoner and sniper are built.**~~ Answered: **AI8, right after the milestone,** before DUNGEONS' slice (Build order).

### Open after AI1 (Ryan's call)
- ~~**The performance fix**~~ Answered (Ryan, 2026-10-04, starting AI2): **(a), the cap** of about 20 moving enemies per fight (Performance). The question as asked (found in AI1, 2026-10-04; Performance, The budget): crowd movement, mostly steering, breaks the 180 Hz frame past about 20 moving enemies, and 50 chasing fodder break the game. Ryan picks: (a) **fewer awake enemies** (a cap of about 20 per fight until later; DUNGEONS' pack sizes and the sleep distance plan around it), (b) **cheaper fodder movement** (fodder without avoidance steering, kept apart by the fodder ring of AI2: about 60% of their cost; Claude's pick, to build with AI2), or (c) **the optimization pass** ALLIES.md puts after all AI (and live with the cap until then).

### Open from Duels and odds (2026-10-04; Ryan's call, asked in short rounds)
1. ~~**Kit sizes:** does "3 to 5 abilities across the board" include fodder and regulars? And what's a **duelist**?~~ Answered (Ryan, 2026-10-04): **Claude's table** (fodder none, regulars 2–3, elites 3–5, bosses 4–6 plus a passive); **a duelist is an elite flagged `duelist`** that thinks at the boss's rate (Kits).
2. ~~**No passives and `EnemyData.twist`:** stat shapes only below boss, or retire it?~~ Answered (Ryan, 2026-10-04): **keep it as it is** (Kits).
3. ~~**The odds:** the champion's weight, the rank weights and the threshold.~~ Answered (Ryan, 2026-10-04): **a champion weighs 1.5** × its `threat` (at 1 a lone elite pressed a full-health Knight); **the rank weights (0.25, 1, 2, 4) and the threshold (1.5) stay** (Odds).
4. ~~**`crowded_range`:** its own value or the band's minimum.~~ Answered (Ryan, 2026-10-04): **its own value** (melee 200 u, casters their band's minimum) (Crowded).
5. ~~**The heavy hit:** what counts, and the window.~~ Answered (Ryan, 2026-10-04): **at least 10% of the target's max health; the window 0.8 s** (0.3 s was the post-hit i-frames already) (Odds).
6. ~~**Changes to built rules,** with their steps.~~ Answered (Ryan, 2026-10-04): **approved:** a ready defensive counted whole below 30% (AI3b); the new sliders' role starts, `aim_lead` included (AI3b). **Not approved:** the heavy-hit rule always on (it runs only while pressing). **Changed:** the crowded kiting step isn't "first": with no answer, a roll picks between backing up once and standing and swinging (Ryan: "it should be a mix"); *(proposed)* the chance to back up is 1 − `aggression`.

### Open from AI3c (2026-10-05; answered by Ryan the same day)
1. ~~**The think budget at today's think cost** (Performance, measured in AI3c): a think in a fight costs 410–480 µs now (AI1: 130–230 µs), so `think_budget` 200 a second is about 1.5 ms a physics tick, not the 0.55 ms it was sized for. Keep 200 (it only bites past about 15 elites' worth of brains), or lower it to about 75 (0.55 ms), or leave it for the optimization pass after all AI (ALLIES.md). Claude's lean: keep 200 until real rooms are built under the 20-enemy cap, then measure a full fight windowed.~~ Answered (Ryan, 2026-10-05): **keep 200; elites and bosses are exempt** (Performance, Think rate by rank). Asked first: an optimization sweep after all AI would help the whole game (crowd movement is the biggest cost, then the think), and cutting the budget would only slow regulars in fights bigger than any built yet.

### Open from Combos (2026-10-05; Ryan's call, asked in short rounds: all answered the same day, in four rounds)
1. ~~**The Knight's answer to crowd control:** he has no CC-break and no unstoppable moment (rooted he can swing, Cleave, Iron Resolve and Judgement; stunned, nothing).~~ Answered: **no new tool now** (Claude's proposal); revisit at AI-M. Not picked: Iron Resolve breaking roots and slows; base tenacity.
2. ~~**Kill protection,** yes or no, and its threshold (60%).~~ Answered: **no.** Telegraphs and the dodgeable opener are the answer; revisit at AI-M if deaths feel cheap.
3. ~~**The combo budget's numbers:** 1.2 s locked out in any 3 s (a root counts half); 30% of max health from a regular's combo, 45% from an elite's.~~ Answered: **no budget at all.** Ryan: "if their abilities are off cool down they can use it whenever they please." Cooldowns are the limit.
4. ~~**The crowd control types on the player at first.**~~ Answered: **a root (up to 1 s) and a short stun (up to 0.5 s)**, each from a telegraphed, dodgeable ability; the rest later.
5. ~~**Diminishing returns:** who it applies to.~~ Answered: **every unit** (fodder full; bosses until poise), the numbers as proposed (a second within 4 s halved, a third refused and 3 s immune, a ring).
6. ~~**Boss poise:** now or later.~~ Answered: **later** (only the hook now; bosses keep 40% tenacity plus diminishing returns).
7. ~~**The duelist's defensive:** a counter-strike guard or a plain shield.~~ Answered: **a plain shield** (the library's guard). ~~**Its numbers.**~~ Answered: **as proposed** (TARGET; it thinks 25 a second).
8. ~~**Changes to designed or built rules.**~~ Answered: **all approved:** the crowded episode started by crowding and a failed all-in roll peeling first (AI3b, designed; Ryan asked whether these were new: they were all new proposals); a commit with a plan ending with the plan and keeping its token up to 6 s (AI1, AI2, built; only enemies with plans); `mixup` promoted for one use and `combo_commitment` designed as `combo_greed`; the ally's own plans on `ChampionData` and its follow-up with no reaction wait (ALLIES).
9. ~~**Names.**~~ Answered: **"stay"** for the follow-through's other choice (the odds keep "press"). Still to approve with CONVENTIONS: "crowding", "combo plan" beside the basic attack combo, `combo_roles` (with peel and guard as intent tags), the other names (Data, Vocabulary).

### Claude's other proposals (written in above as *(proposed)*; Ryan can overrule any)
1. ~~**Names**~~ Answered (Ryan, 2026-10-04, starting AI1): **all approved as proposed**, the word **rank** included (CONVENTIONS.md updated). The list: (`EnemyData`, `EnemyBehavior` and `EnemyRoster` approved as the format in I9): `EnemyAbilitySlot`, `BrainAdjust`, `EliteModifier`, `BossPlan`, `BossPhase`, `AIUse`, `PoseSet`, `PoseLook`, `EnemyAITable`, `RankRules`, `Brains` (autoload), `EnemyBrain`, `SituationContext`, `PartySnapshot`, `BrainDecision`, `Pack`, `BossDirector`, `Ambush`, `EnemySpawner`, `SandboxBrains`, `ScriptedController`; `Ability.ai_uses`, `respect_value`, `get_effect_area()`; `Condition.Kind.THREATENED`, `TARGET_WHIFFED`, `RESPECT`; `Enemy.data`, `naive_casting`; the Events `pack_alerted`, `boss_phase_changed`, `boss_reset`; the source ids `elite_modifier_<id>`, `enemy_<id>`; the intents and intent tags; the word **rank** for the ladder (CONVENTIONS calls elite and boss "enemy tiers").
2. ~~**The tell lead** (0.3 s of pose before an attack decision) and the pose looks.~~ Answered in I7.
3. **One intent for at least 0.4 s** (no flip-flopping).
4. **Scoring** numbers (Architecture, Scoring).
5. **The whiff rule:** major = ultimate, charge-up, dash or leap; a whiff = no enemy hit within 0.3 s; the window = the recovery left + 0.6 s.
6. **Dash-answerable** = a telegraph of at least 0.6 s and a shape one dash (4 m) can leave from anywhere inside.
7. **Rank and difficulty tier adjust tables** and the two faction examples.
8. **The first elite modifier pool** (Fast, Shielded, Teleporting, Vampiric, Volatile) and names under the bar (identity, not a tell; does that sit with "no icons"?).
9. **Melee enemy basic attacks tagged `melee`** (`EnemyData.attack_tags`), so a perched champion is out of a brute's reach (3D.md asked).
10. **A caster's basic attack is its weak close option** when cornered.
11. **`ScriptedController`** shared with ALLIES AL1.
12. **The tuning panel saves** to the preset (Ctrl+S) or as an override (Ctrl+Shift+S), only in an editor run.
13. **Ranged roles' regular attacks:** basic attacks in COMBAT's chip band; telegraphed abilities in the elite band's lower part. No new band (COMBAT.md's bands stay unchanged).
14. ~~*(Built AI2)* **A taunted brain commits on its taunter** without patience or a token (the doc said only "needs no token").~~ Kept (Ryan, 2026-10-04, starting AI3).
15. ~~*(Built AI2)* **Sight never wakes an enemy on a champion it has no path to;** a hit does, and the 6 s leash then sends it home to heal (no wake, leash, wake loop under a perch).~~ Kept (Ryan, 2026-10-04, starting AI3).
16. *(Built AI2)* **The fodder ring's mechanics:** at half the fodder's reach, fixed places per target, a fodder hitting from where it stands until its target leaves its reach, the blocked, crowded and round-the-outside rules (Groups).
17. *(Built AI3)* **Casters notice from 850 u** (their `detect_range`), beyond their band's far edge; **an attack coming breaks the no-flip-flop bonus** (the doc's urgent event), so a shield is never held back by a poke just started; **a walk away holds** (its own clock, its bonus); **cornered, a caster swings within 1.5 × its reach** and otherwise stands and pokes.
18. *(Built AI3)* **The skirmisher's numbers:** a 2 m hop at its reset, half its patience kept. With its 2 s patience it dives every couple of seconds even with the kit up while the target stands still: the play test says whether that's right (the sliders tune it live).
19. *(Built AI3)* **A settled fodder keeps swinging only while its target is within 0.85 of its reach**, else it steps back to its place. At the edge, other fodder's pushes made every swing whiff (one slime landed nothing for 4 s).
20. *(Duels and odds)* **The key ability:** its `ultimate`, else its highest `respect_value`, ties to the earlier slot; `own_ready_share` read like a champion's kit ready, 0 while the key is down; **cautious** for 3 s (or until the key is ready), patience × (1 − 0.5 × confidence), the walk out to the band's far edge.
21. *(Duels and odds)* **The right moments** for a held key (crowd control, a punish window, the target below the finish threshold, its defensives down, crowded, a plan worth 0.8) and one roll every 2 s; a poke is never held.
22. *(Duels and odds)* **An answer is derived from the intent tags** (`cc`, `escape`, or a damaging use that reaches now), with no new tag; a knock-away is authored as a `cc` use.
23. *(Duels and odds)* **The crowded order** (cornered, escape, the all-in roll, then Ryan's mix of backing up or standing, its chance 1 − `aggression`), one roll each per episode, the episode ending 1 s after the target leaves by 0.5 m, a caster's all-in as casting its answer.
24. *(Duels and odds)* **Smell blood as scores** (× 1.3, capped at 0.89) and **one shared push** for low health and the odds (the larger), instead of more pushes on patience.
25. *(Duels and odds; built AI3c)* **The press:** `odds_pressure` 0.5, the token cap 4, the weakest pick's factor (0.5 + 0.5 × health), bosses never pressing, the `press` pose (a 10° lean, an amber 1 Hz rim). The word "press" sits beside "pressure" (patience's push and a boss's phase); another word is fine.
26. *(Duels and odds; built AI3c; Ryan kept 200 with elites and bosses exempt, 2026-10-05)* **The think budget:** 200 thinks a second (about 0.55 ms per physics tick at AI1's measure), scaled down evenly past it, never under 5 a second.
27. *(Duels and odds)* **The library's paths and starter list** (Kits), and **AI3d** for it (before or after AI3b). *(Built AI3d first, Ryan's call; the scripts that already existed stay where they are.)*
29. *(Built AI3d)* **Weights order a kit** (the key ability's 1.3 down to a gap-closer's 0.9), **the big hit's 350 u reach** so it opens before the shockwave, **a damage, poke or gap-closer use beside every `cc`, `punish` or `finish` use** until AI3b and AI6 read them, and **the snare as the bolt with an always-on root** (Kits).
30. *(Built AI3d)* **An escape ability ends a walk under way** (Cornered casters): the next walk gets its own 2 s.
28. *(Duels and odds)* **Boss passives' tells:** the boss bar like the HUD's passive slot, an aura, the `passive` pose; `BossPlan.passive`, `BossPhase.passive`.
31. *(Combos; built AI-D1, 2026-10-06)* **Claude's readings while building:** until AI-D2's plans, an enemy sets up only with an `opener`-role ability (`combo_roles` came a step early); a setup's opener doesn't end the commit; a `peel` use needs an answer beside it (the roll's order); walking straight in starts a brute's episode about 0.35 m outside its 2 m (the closing term), for every enemy; a push is never a gap-closer and DoT ticks aren't hits. **And a question:** the duelist's snare (the library's) has no line on the floor, only its 0.7 s windup; should enemy bolts draw one (a small change to the shared bolt script)?
31. *(Korsavil, 2026-10-04)* **The search:** 3 s of looking around (`search_time` in `EnemyAITable`), only with no other candidate, a `search` pose, then home as on a leash (arena and boss enemies hold); a stealth ending in its sight brings the chase back; enemies with no data keep today's drop (Losing a stealthed target).
32. *(Korsavil, 2026-10-04)* **Fear:** the brain rests as under `is_cc_blocked()`, the flee re-paths at each think straight away from the source and stops when cornered, a stun or root wins, the pick runs again at once after; bosses refuse it through a permanent `boss` status from `RankRules` and fear's `refused_by_tags` (Fear).
33. *(Combos, 2026-10-05)* **The two reads:** crowding's terms and weights (near 0.6, closing 0.15, a gap-closer 0.3, hits 0.3) and the opening's (escapes down 0.5, crowd control by another 0.5, recovering 0.4, committed 0.4, cornered 0.2), the token as a gate; the dash never counted as an escape (it's not on the HUD), which is why openers must be dodgeable.
34. *(Combos)* **One mechanism:** crowding starts the crowded episode; a failed all-in roll peels when a `peel` use passes, else the mix. Only enemies with a `peel` use or combo plans change. *(Approved by Ryan, 2026-10-05.)*
35. *(Combos)* **Combo plans:** the step timings (after landed, after ended, after a delay, on a status), a 1 s window, optional steps, the ends (a miss, an interrupt, the token, the target, low health, the odds down by a third), the token kept up to 6 s, urgent intents only between steps.
36. *(Combos)* **The follow-through's lean:** (1 − effective respect) × (0.5 + 0.5 × its health) × (0.5 + 0.5 × its own kit ready), staying at lean ≥ 1 − `follow_through`.
37. *(Combos)* **The five sliders' meanings and starts:** `combo_greed` as the chance to carry on after a missed step (the brief named it without a meaning; the brute's swing-through is it, not `spend_eagerness`); `mixup` as the runner-up plan or a held beat. *(The two meanings approved by Ryan, 2026-10-05; the starts stay TARGET.)*
38. *(Combos)* ~~**Diminishing returns' numbers** (4 s, half, then 3 s immune; slows and knock-ups not counted; fodder exempt) and **the immunity's ring**~~ (approved by Ryan with the rule, 2026-10-05). Still a proposal: **`Ability.recovery_time`** (no recovery field exists).
39. *(Combos)* **The test duelist's numbers, plans and overrides** (The test duelist), its think rate the boss's 25 (Kits), not the brief's 20. *(The numbers approved by Ryan, 2026-10-05; the guard a plain shield.)*
40. *(Combos)* **Break free** (an elite's break-out, castable while crowd-controlled) as a library archetype built with AI5, and **the poise hook** (`RankRules.poise`, `Events.cc_refused` with `POISE`).

### Open from AI-D2 (2026-10-07; Ryan's call)
41. **The duelist's nine overrides** (the tuning pass's seven, `combo_greed` and `mixup`): past kind-not-magnitude's three (the enemies test warns). If they stay, a duelist preset of its own (`enemy_behavior_duelist.tres`) would hold them.
42. **The blind read's reach:** an ultimate on cooldown alone lets it go blind, so after the Knight's first Judgement (30 s) the duelist may open with its fast strike for most of a fight. Each read can be switched off in the table (`blind_reads`); revisit after the play test.
43. ~~**The tuning panel's sliders take the mouse wheel** (Godot's `Slider.scrollable`): scrolling the panel's list nudged the brute preset that the AI-D1 commit saved (restored 2026-10-07, Ryan).~~ Fixed in AI-D3 (Ryan's OK, 2026-10-07): `scrollable = false` on its rows and the TEMP row.

### Open from AI-D3 (2026-10-07; Ryan's call)
44. **What brains know about diminishing returns** (Claude's reading of "knowledge limited to the HUD"): they see the immunity (its ring: `target_cc_immune`), not that your next crowd control would be halved, so an enemy's snare right after another's lands a 0.5 s root and its combo's strike (about 0.85 s in) can miss. If enemies should read the halving too, it's one more situation field (`StatusComponent.get_dr_step()`).
45. **Two elites on one champion share his two attack tokens** (AI2: an elite costs 2): with the duelist and the elite caster together, one attacks at a time. In three of six 2-minute smoke runs (one of them on HEAD, so it isn't AI-D3's) the duelist held them in its commit at his feet with no ability casts for 30 s and more, while the caster waited for a token without casting. Worth watching in the play test; the token rules are AI2's.
46. **Outside a plan, the no-waste rule doesn't hold back crowd control** (AI-D2 checks it for a plan's steps only): an enemy's plain `cc` or `peel` use can still throw its snare into the ring. Today the elite caster's snare and the duelist's (its `cc` and `peel` uses) can; one condition on those uses (or a shared rule in the use gathering) would stop it.

### Conflicts and notes for Ryan (found 2026-10-03)
- **Found building AI3b (2026-10-05; details in Duels and odds):**
  - **Episodes:**
    - Its own commit brought it into your face, so an episode starts only when you come in (not while it commits or walks back out).
    - An episode ends only once you've stayed out: "ends when its all-in or kiting step ends" would roll again after each kiting step and turn "back up once" into a chase.
  - **`spend_value_bar`** can't work against the default plan's fixed value of 1: the right moment counts champions in the key's area instead (`spend_min_champions`).
  - **"Every defensive on cooldown"** needs one to exist.
  - **A caster's crowded all-in can't happen yet** (escape always wins inside its band), so it isn't built.
  - **The elite test caster's key is its snare,** not its bolt (the doc's "Today" list predated AI3d).
  - **Aim lead clamped by range** falls short: a caster leads well only inside its range.
  - **The tuning panel already ran 14 px past the 360 px canvas** before AI3b; its slider list scrolls now.
  - **Older tests pin AI3b's sliders** (`_pin_ai3()`): with confidence the test brute comes in after 4.8 s with its smash up, not 12 s, so AI1's 12 s floor and AI3's stalk are checked with AI3's values.
- **Found writing Combos (2026-10-05):**
  - **"The v2 additions"** in the brief are this doc's **Duels and odds**: confidence, crowded, smell blood, odds and `nerve`, think rates by rank, the five sliders. They're designed but AI3b and AI3c aren't built, so AI-D comes after them.
  - **"Pressure on me"** would give "pressure" a third meaning (patience's push, a boss's phase), so the read is **crowding**. The follow-through's **"press"** is already the odds' press, so it's **stay**.
  - **"Combo"** means the basic attack chain in CONVENTIONS, so the new thing is a **combo plan**. Its **finisher** means what the combo's finisher means (the last, heavy hit). "Role" now has three uses (an enemy's role, an ability's role tag, a combo role), so "combo role" is always said in full.
  - **The brief's five combo roles:** peel and guard are already what intent tags say (`peel`, new, and `defend`), so `combo_roles` holds opener, extender and finisher only.
  - **`combo_greed`** is named in the brief but not defined. The blind finisher was put under `spend_eagerness` "as for a brute", but the brute has the lowest `spend_eagerness` of the presets (0.4). So `combo_greed` carries it: the later list's `combo_commitment`.
  - **"The duelist rank: think rate 20":** Ryan made the duelist an elite flagged `duelist` that thinks at the boss's rate (25 a second; his range 20–30), not a rank. The doc keeps his.
  - **"The first entries of the shared library":** the library exists (AI3d), so the duelist is built from its templates, with no new archetype (Ryan picked the library's guard over a counter-strike stance).
  - **The `answer` tag:** Duels and odds decided answers are derived (no new tag). The duelist's snare counts as one through its `cc` use and its root.
  - **"A root lets you cast and dash-cancel":** Ryan's roots rule (ABILITIES.md, Roots) blocks the dash under a root. Rooted, the player can still swing and cast anything that doesn't move them, so a root is a softer lockout than a stun.
  - **Fodder:** the brief's section 3 puts diminishing returns on every unit, its section 5 gives fodder full crowd control. Fodder is exempt.
  - **The CC-immune "icon":** no icons over heads (Tells), so it's a ring at the feet, a status look like the stun's stars.
  - **Kill protection** would have added nothing for one enemy's combo under the proposed damage cap (45%, below the 60% it protected). Ryan dropped both: no budget, no kill protection.
  - **D1–D4** clash with DUNGEONS.md's D0–D9, so the steps are AI-D1–AI-D4.
  - **ALLIES' "combos come from the plans; no pair scripted by name":** party combos stay unscripted; only a champion's own sequences may be combo plans, read when an AI drives it.
  - **The ally's follow-up "with no reaction check"** goes past ALLIES' 0.3 s reaction; it keeps ALLIES' 0.1–0.25 s cast delay, so it isn't frame-perfect.
  - **The opening's "recovering" term** needs AI6's whiff read (0 until then); the duelist's `snare_first` gains its `TARGET_WHIFFED` rule with AI6.
  - **A plan can outlast the token's 4 s,** so a plan keeps it up to 6 s.
  - **No ability has a recovery** (end lag) today, so the finisher's long recovery needs `Ability.recovery_time`.
  - **"Later steps may be fast"** against the 0.6 s rule (AI3d's telegraph test): allowed only while the plan's own crowd control still holds the target. Nothing uses it yet, so the library's test stays as built.
- ~~**Arena spawn-in vs waves:** DUNGEONS.md proposes arena waves (`ArenaWave`, `next_wave_at`); Ryan didn't pick waves or reinforcements. This doc keeps spawn-in (one group at the seal) and defers waves; DUNGEONS' wave proposal is marked waiting on Ryan.~~ Answered (Ryan, 2026-10-04): spawn-in confirmed (one group at the seal); waves and reinforcements stay deferred. DUNGEONS.md updated.
- **Data intents vs ALLIES' script-only AI:** ALLIES' decision ("one AI method per ability ... replaces the brief's data hints") and this brief's data intent tags both stand: the data says what for and when, the script says how and how good. ALLIES' `engage` intent is renamed `gap_close`, and `get_ai_plan()`'s `sense` is the `SituationContext`.
- ~~**"Rank" vs "enemy tier":** CONVENTIONS.md's vocabulary calls elite and boss enemy tiers; this doc proposes "rank". CONVENTIONS isn't edited until Ryan picks.~~ Answered (Ryan, 2026-10-04): "rank"; CONVENTIONS.md updated.
- **Found building AI1 (2026-10-04):** the doc's **B** for the overlay was already the sandbox's AB15 test blink; Ryan picked **I**. Putting the slimes on data gives the elite slime a brain in room_01 too (Ryan: yes, everywhere); combat_test's C5 and abilities_test's AB13 and cleanup-pass checks of the naive loop now spawn the elite with no data.
- **Found building AI3d (2026-10-04):**
  - **The elite slime isn't in room_01:** it's placed only in the two sandboxes (room_01 has slimes only, and never had an elite), so AI1's "room_01 included" and the AI3d question's "room_01's elite gets harder" were wrong; the re-kit changes the sandboxes only.
  - **The escape walk's clock:** a blink after a walk had started (the first catch landed mid-cast, the new lobbed orb's 1 s) left the walk's old clock running. Fixed: an escape ability ends the walk (Cornered casters).
  - **Five brutes push the Knight about:** with the charge and the cleave arc, their knockbacks could carry him past a brute's 12 m leash within the 15 s token test, and it walked home. The test holds him unstoppable now, as the fodder ring's does; the leash is tested on its own.
  - **The big hit's reach:** at 300 u it was inside the shockwave's circle, so the elite slime always opened with the shockwave; 350 u.
  - **Four slots:** AbilityComponent has q, w, e and r; the elite cap of 5 and the boss cap of 6 wait for AI6's slots (Ryan).
  - **view_test's swing-arc guard** counts every `VFX.slash()` call: the cleave arc's is the sixth, through `VFX.drawing_origin()` like the others.
- **Found writing Duels and odds (2026-10-04):**
  - **Ability counts:** Ryan's "3 to 5 across the board" against his ladder (fodder none, regulars 1–2, elites 3) and the built `RankRules.max_abilities`. Answered: Claude's table; the caps change in AI3d.
  - **"Duelist"** wasn't a rank or a role in this doc. Answered: an elite flagged `duelist`.
  - **"No passives"** against `EnemyData.twist`, a bundle that can hold unit reaction rules and statuses. Answered: the twist stays as it is.
  - **The crowded kiting step** against AI1's built "walked in on, it holds its ground and swings". Answered: a mix, rolled per episode (back up once, or stand and swing).
  - **A caster never commits** (AI3, its commit weight 0): its all-in is casting its answer, not a commit, so nothing built changes for casters (the test casters' only answer is their blink, and escape wins).
  - **Aim lead** against the default plan's "no leading" (AI1, from COMBAT's "can be walked out of"): at 0 it's today's aim, and a lead still loses to a turn, a stop or a dash. Answered: approved with the presets' starts.
  - **Low health counted four ways** (respect's health term, the 40% push, smell blood, the odds' health ratios): nothing removed; smell blood is scores only, and the odds and low health share one push.
  - **The heavy-hit window (0.3 s)** equals the player's post-hit i-frames (COMBAT.md), which already block a second hit inside 0.3 s: as written the rule changes nothing today, and COMBAT needs no hook. Answered: widened to 0.8 s, only while pressing.
  - **The champion's weight:** at Ryan's start (1 × `threat`), a lone elite (2) against a full-health Knight was at odds 2 and pressed. Answered: 1.5.
  - **"Boss phase triggers by health"** (Ryan's later list) is already designed (I10, `BossPhase.health_below`).
  - **Vocabulary:** "press" beside "pressure" (Claude's proposal 25).
- **Found building AI3 (2026-10-04):**
  - **The caster's numbers:** a regular can have at most 2 abilities, but the doc gave the test caster 3. Ryan split it: a regular test caster with the bolt and the blink, and an elite one with the shield added.
  - **Detection:** at the default 450 u a caster always noticed inside its own band's minimum and fled at once; casters notice from 850 u.
  - **Escaping on foot:** jitter let a poke beat escape for one think, and that restarted the 2 s walk each time, so the caster was never cornered. The walk now keeps its clock.
  - **A missed gap-closer:** its cast ending ended a brute's commit at once (AI1's "first cast ends it"). A gap-closer's cast no longer counts.
  - **Your camera at 30 m** (on purpose, 2026-10-04) moved view_test's camera numbers; they're updated.
- **Found building AI2 (2026-10-04):**
  - The doc gave the fodder ring to each pack; it runs per target over every pack (two packs' fodder would otherwise stack).
  - Centering the ring on the fodder's mean angle turned the places as they walked; the places are fixed per target instead.
  - At 0.7 of a slime's reach, its own 12 px push took the Knight out of its reach after every hit; the ring is at half.
  - Waking by sight on an unreachable champion looped (wake, leash after 6 s, wake again); sight now needs a path.
  - The sandbox's packs aimed past a wall stood off the walkable floor; they're snapped to it.
- **Where elite modifiers are defined:** COMBAT.md's Out of scope and CONVENTIONS.md's vocabulary point to DUNGEONS.md; DUNGEONS.md says ENEMIES_AI defines them. Now: the format here, the count in DUNGEONS. COMBAT's pointer is fixed; CONVENTIONS' too (2026-10-04, with the names).
- **"Random dodge" in COMBAT's references:** a visible sidestep with a chance to try is not a hit that silently misses (Dodging).
- **Think rates:** the ally brain thinks 5 times a second (ALLIES.md), enemy brains about 10; both are data and both are measured.
- ~~**The order of work:** ALLIES.md's order (the second champion → Tier B → ALLIES) and CLAUDE.md's Next (LOOT L4) don't place AI1 yet.~~ Answered (Ryan, 2026-10-04): AI1 now, before the second champion; ALLIES.md's order notes it.
- **VISION.md, Open question 7** (big fights vs methodical): answered by this doc's groups (fodder swarms, smart enemies take turns on tokens); VISION.md isn't edited here.
- **The stand-ins in TALENTS.md and LOOT.md** (`xp_by_unit`, `get_kill_tags()`, `drop_table_by_unit`) retire in AI7; their docs get the pointer when Ryan OKs it (COMPANIONS.md's is applied).

### For other docs
- **ALLIES.md** (applied 2026-10-03): Tier B is AI1–AI2; `UnitController`, `CastPlan` and the default `get_ai_plan()` are built in AI1; the shared intent tags; the target pick's numbers in `EnemyAITable`; tokens per champion as the party-size hook; the ally brain may reuse the toolkit (the situation, the overlay, the panel).
- **DUNGEONS.md** (applied 2026-10-03): `EnemyRoster` as `DungeonData.roster`; faction presets; `DifficultyTier.brain_adjust`; elite modifiers' format here; ambushes and spawn-in; waves deferred; `BossDirector.reset()`.
- **ABILITIES.md, COMBAT.md** (applied 2026-10-03): `ai_uses`, `respect_value`, `get_effect_area()`, the three condition kinds; enemy roles in the threat kinds; dodge and tell rules; bands unchanged.
- **WORLD_INTERACTION.md** (applied): ambush triggers; `Sight` into WorldQuery in AI2. **COMPANIONS.md** (applied): drops from `EnemyData`. **3D.md** (applied): pose hooks; the perched sniper; enemy attacks' `melee` tag.
- **Duels and odds** (applied 2026-10-04): ABILITIES.md (answers from the intent tags, enemy abilities' `respect_value` and the key ability, the enemy ability library, `aim_lead` in the default plan, heavy hits); ALLIES.md (the target pick under odds, the party's strength); COMBAT.md unchanged (the post-hit i-frames already cover the heavy-hit window). CONVENTIONS.md gets the new words on approval.
- **Combos** (applied 2026-10-05): ABILITIES.md (`combo_roles`, the `peel` intent tag, `recovery_time`, the new condition kinds, crowd control on the player, the events), COMBAT.md (diminishing returns, the immunity ring, the events; no combo budget and no kill protection: Ryan), ALLIES.md (the shared planner, the ally's rules and sliders), CHAMPIONS.md (the Knight's counterplay findings). CONVENTIONS.md gets the new words on approval.
- **Korsavil** (CHAMPIONS.md, designed 2026-10-04; applied the same day): the search and fear come from her kit (this doc's two new sections); ALLIES.md (stealth dropped at once, the search, stealth ending on acting *(proposed)*), COMBAT.md (`status_fear`, `refused_by_tags`) and CONVENTIONS.md (the words search and fear, the `boss` tag) updated with them.
- **CONVENTIONS.md** (applied 2026-10-04, Ryan approved the names): the names AI1 built and the word "rank"; the later steps' names go in as they're built. **TALENTS.md, LOOT.md** (on approval): their stand-ins retire in AI7. **VISION.md** (on approval): Open question 7 answered. **AUDIO.md**: the hooks above join its "later, per system" list when built.
