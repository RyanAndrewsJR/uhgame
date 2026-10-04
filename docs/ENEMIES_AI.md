# ENEMIES_AI.md: Enemy Brains, Roles, Groups, Dodging, Tells, Elites, Bosses and the Tuning Toolkit
<!-- Written 2026-10-03 from Ryan's decisions (his interview with the advisor, the same day). A plan: nothing is built. -->

**Read when:** the task involves how enemies decide (the brain, the situation, intents, respect, patience), enemy roles and ranks (fodder, brute, skirmisher, caster; regular, elite, boss), what an enemy ability is for (its AI uses), what enemies know about the party, attack tokens, packs (alert, leash), enemy dodging, enemy tells (poses), elite modifiers, the boss director (phases, pressure and breather, punish, finish, reset), spawning (packs, ambushes, spawn-in), how factions and difficulty tiers scale brains, where enemy data lives (`EnemyData`, the roster: XP, kill tags, drops), the AI's performance (think rate, sleeping), or the AI tuning toolkit (sliders, the brain overlay, the live tuning panel, the scenario spawner).
**Depends on:** CLAUDE.md, VISION.md (Pillar 1, decision priorities, Open question 7), CONVENTIONS.md, ABILITIES.md (AbilityComponent and the cast flow, `Condition`, `get_ai_vector()`, telegraphs, cast progress, untargetable), COMBAT.md (damage bands, telegraph rules, hit forgiveness, statuses, CC and tenacity), ALLIES.md (`UnitController`, the target-pick rules, `threat`, taunt, stealth, `get_ai_plan()` and `CastPlan`, party scaling), DUNGEONS.md (rosters on shared behaviors, packs and arenas, content slots, difficulty tiers and elite modifier counts, bosses and their reset), 3D.md (views and `UnitView`, perches and `can_reach()`, ledges and navmesh islands, the sleep distance and the P-spike), WORLD_INTERACTION.md (WorldQuery, Hazards, kill credit), COMPANIONS.md (enemies never see companions; drops), TALENTS.md (kill counters and XP; the kind-not-magnitude rule), LOOT.md (drop tables), MOVEMENT.md (MovementComponent, soft caps), STATS.md, AUDIO.md (hooks).
**Used by:** ALLIES (the shared perception, the controller base, `CastPlan`, the target pick; the ally brain reuses the toolkit), DUNGEONS (the roster format, faction presets, spawn kinds, elite modifiers, difficulty tier hooks, the boss reset), COMBAT and ABILITIES (intent tags, use rules, enemy telegraph and dodge rules), TALENTS, LOOT and COMPANIONS (enemy XP, kill tags, drop tables and kindling move onto `EnemyData`), 3D (pose hooks, the perched sniper), UI (the boss bar, elite modifier names), AUDIO (hooks), NARRATIVE (bestiary entries by kill tag).
**Status:** written 2026-10-03. Ryan's decisions (his interview with the advisor, 2026-10-03) are MUST, recorded in DECISIONS.md (Enemies). **The interview is done:** Ryan answered all eleven open items (I1–I11) in three rounds the same day, each as Claude proposed; his answers are MUST, marked I1–I11 in the sections below and listed under Open questions, Interview. Items still marked *(proposed)* are Claude's picks Ryan hasn't answered; each is also in Open questions. Nothing is built. ALLIES.md calls this doc's first steps "Tier B": they are AI1 and AI2 here.

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

## Goal / feel
| What | Number (TARGET) | Why |
|---|---|---|
| Roles at first | fodder, brute, skirmisher, caster | Ryan (MUST) |
| Abilities per enemy | fodder 0; regular melee or ranged 1–2; elite 3; a boss by phase | Ryan (MUST) |
| Big attackers on you at once | about 1–2: a pool of 2 attack tokens per champion (3 at difficulty tiers 4–5); a regular holds 1, an elite 2; fodder never needs one | Ryan (MUST shape; the counts I3) |
| Thinking | about 10 thinks a second per brain, staggered; fodder none | Ryan (MUST shape); the cost measured in AI1 |
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
- **Role** is what an enemy does in a fight, one per enemy:

| Role | Plays like | Abilities | Low health |
|---|---|---|---|
| Fodder | swarms and chips with its basic attack; no real brain (cheap) | none | fights to the death |
| Brute (melee) | holds at the edge of your reach while your kit is up, commits when it isn't; heavy, telegraphed hits | 1–2; an elite 3 | fights to the death |
| Skirmisher / assassin (fast melee) | circles, dives in with a gap-closer, hits and resets out | 1–2 (one is a gap-closer); an elite 3 | hits and resets |
| Caster (ranged, artillery) | keeps its range and pokes the whole time, defends against what's coming at it, escapes or fights when caught | 1–2; an elite 3 | falls back toward packmates |

- Any ranged enemy counts as a caster for these numbers (Ryan). Fodder is a rank and a role at once: a fodder enemy is always the fodder role, and no other rank is.
- **Later, on the same toolkit** (Ryan: the data model leaves room for them now; built in AI8, right after the milestone and before DUNGEONS' slice, so the slice's rosters can use all seven roles: Ryan, I11): **support** (heals, shields or buffs other enemies; falls back like a caster), **summoner** (makes adds through spawn-in), **perched sniper** (stands on a perch under 3D.md's rules: the `elevated` tag, its dead zone, targets through `AbilityUtil.can_reach()`, and every champion keeps an answer).
- A **mini-boss** (DUNGEONS.md) is rank boss with a lighter plan: one or two phases (Ryan, I10).
- Champions are data, never subclasses of Player (CLAUDE.md); likewise every enemy is an `Enemy` with data. Roles and ranks are data read by one brain class, never subclasses.

### The brain (MUST shape; Ryan 2026-10-03)
- Every enemy above fodder has a **brain** (`EnemyBrain`, a `UnitController`: ALLIES.md, Controllers). Each think it:
  1. **perceives:** the shared party snapshot (`Brains`, below) and its own state;
  2. **builds the situation:** a `SituationContext`, pure data (CONVENTIONS' context-object pattern): its target, distances, what's ready on the party, respect, patience, the attacks coming at it, its token, its packmates, its home and leash, its own cooldowns and health;
  3. **scores its options and picks an intent** (Intents, below);
  4. **acts** through AbilityComponent, AutoAttackComponent and MovementComponent, with the calls `enemy.gd` makes today (`set_aim_hint()`, `try_cast()`, `try_cast_vector()`, the charge-up path, `attack.attack()`, `movement.move_to()`).
- **The decision is a pure function:** `EnemyBrain.decide(situation, behavior, rng) -> BrainDecision`, static, reading nothing else. A test builds a situation by hand and checks the intent; the brain node builds the real situation and carries the decision out.
- **The naive cast loop is disabled, not deleted** (Ryan; the change policy): `Enemy.naive_casting` (export, default true) gates `_try_cast_ability()`, and an enemy whose brain runs never calls it. It's deleted after the milestone passes, with Ryan's OK.
- **Fodder has no brain:** it keeps `enemy.gd`'s own routine (idle, wander, aggro, chase, attack) without casting, plus its pack's group decisions (Groups).
- *(proposed)* **No flip-flopping:** an intent holds for at least `min_intent_time` (0.4 s) unless an urgent event breaks it (an attack to dodge, its token lost, its target gone, a stun). The current intent scores +0.15 until then.

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

- **Each ability carries what it's for, as data:** `Ability.ai_uses`, a list of `AIUse` *(proposed names)*. Each use has an **intent tag**, **use rules** (a list of the shared `Condition`s, all of which must pass) and a weight. The intent tags: `poke`, `gap_close`, `escape`, `defend`, `punish`, `finish`, `zone`, plus ALLIES' effect tags `damage`, `heal`, `shield`, `buff` and `cc`.
  - **Casters don't cast a shield "just because":** a shield's only use is `defend`, with the rule `THREATENED` ("a projectile, a charge-up or a cast is aimed at me").
  - **The brain asks for the ability the moment calls for, not whatever is ready:** `commit` looks at `gap_close` uses (out of reach) and `damage` uses (in reach), `poke` at `poke` uses, `hold` at `poke` and `zone`, `defend` at `defend`, `escape` at `escape`, `punish` at `punish` (else `damage`), `finish` at `finish`.
  - An ability with no `ai_uses` counts as one `damage` use with no rules, so today's elite slam keeps working.
- **Abilities propose, brains decide** (ALLIES.md, An AI method per ability). For each castable ability with a passing use for the chosen intent, the brain asks its `get_ai_plan(caster, situation)` (where to aim, how good) and takes the best plan value × the use's weight. **The data says what for and when; the script says how and how good.** One list of intent tags serves both brains: the ally brain's stance weighs them (ALLIES' `engage` becomes `gap_close`).
- **Three new `Condition` kinds** for use rules *(proposed; ABILITIES.md, Conditions)*:
  - `THREATENED`: an attack coming at self (Perception) lands within `value` seconds (0 = any time);
  - `TARGET_WHIFFED`: the target's punish window is open and at least `value` seconds long (Punish);
  - `RESPECT`: the situation's respect compared with `value` (0–1) by `comparison`.
  They read the `SituationContext`, passed as a new optional last argument (`Condition.is_met(self_unit, target, cast, situation)`). Without one (a cast condition, a reaction rule) they're false. The other kinds work unchanged in use rules: `TARGET_DISTANCE` for a poke's range, `TARGET_HEALTH_PERCENT` for a finisher, `SELF_HEALTH_PERCENT` for an escape, `ENEMIES_IN_RANGE` for a zone (champions are the enemy's enemies), `TARGET_HAS_STATUS` with `cc` to hit a stunned target. One condition system (ABILITIES.md).

### Knowledge: what enemies know (MUST; Ryan 2026-10-03)
- **Exactly what the HUD shows, for the player and the ally:** each ability ready or on cooldown, the time left, and current health. *(proposed reading)* "Ready" is what the HUD shows as usable: a charge available and the cost payable (the sweep and the blue tint), not the ability's conditions. The ally's are what ALLIES' ally panel shows.
- **What's on screen:** positions, a cast or charge-up in progress and where it's aimed, projectiles in flight, statuses with a look. Enemies see these as a person would, after a reaction time.
- **Nothing hidden:** no gear, no hidden stats, no talent loadout, no input reading (an enemy reacts to the cast it sees, never to the key press). The values a brain gives abilities never read the champion's stats (Respect).
- **Companions are invisible to enemies:** never in the snapshot, never a target (they aren't Units: COMPANIONS.md), and the command's slot doesn't count toward respect.
- A later opt-in "habit reading" for bosses (learning what this player tends to do) is out of scope.

### Respect (MUST: the rule; Ryan 2026-10-03. The value and the ally's weight: Ryan, I2. The formula's other weights TARGET)
- **Respect** (0–1) sums the value of what's **ready** on the player and the ally (damage, CC, gap-closers; ultimates weigh most). **High respect:** melee holds, circles or pokes. **Low respect** (big cooldowns spent, the player low): it commits. This is the "don't rush in when everything is up" rule, and it makes **baiting intended play**: spend a cheap ability to lure a dive.
- **An ability's value** (`respect_value`), **derived by default with an authored override** (Ryan, I2):
  - derived from data the HUD shows: its role tag (`ultimate` 4, `core` 2, `mobility` 2, `defensive` 1.5, `generator` 1, `companion` 0), +1 if its data applies a `cc`-tagged status (a stun, a slow);
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
- *(proposed)* Patience (0–1) fills each second by (1 − 0.75 × effective respect) ÷ `patience_time` × (0.5 + `aggression`) × pressure. Pressure is 1, +0.5 while the target has done nothing (no move, swing or cast) for 1.5 s, +0.5 while it's below 40% health. So with everything up it still fills at a quarter of its speed: a brute (`patience_time` 3 s, aggression 0.5) comes in 12 s at the latest. A commit empties it; a skirmisher's reset leaves it at half.
- *(proposed)* An enemy with full patience but no token keeps holding, first in the token queue (Groups).
- **Holding:** a spot in its range band around the target (Movement and positioning), strafing one way and turning after 2–4 s (jittered), facing the target, in its hold pose (Tells).

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

### Groups: attack tokens (MUST: smart enemies only; Ryan 2026-10-03)
- **Fodder swarms freely and chips** (COMBAT.md, Enemies): no tokens. **It surrounds** (Ryan, I6): its pack spreads its fodder in a ring around their target, about 0.6 m apart, instead of stacking on one spot (Diablo's zombies), and a wounded fodder behaves exactly the same (it fights to the death).
- **Brutes, skirmishers, casters and elites use attack tokens:** about **1–2 big attackers at a time**; the rest circle or poke. **Ranged enemies stay behind or beside the melee** (Movement and positioning).
- **The token count scales with difficulty tier and party size** (ALLIES.md's hook). Companions don't count.
- **A holder that's stunned, dead or out of reach releases its token**, and **timeouts** keep anything from deadlocking.
- **Pools** (Ryan, I3): each party member has its own pool of tokens, so a second champion brings a second pool (the party-size hook). A pool's size comes from the difficulty tier (`EnemyAITable.tokens_per_target`: 2 at tiers 1–3, 3 at tiers 4–5, plus a tier's `token_bonus`). A regular holds 1, an elite 2: two regulars or one elite at once. Bosses use none (the director).
- *(proposed)* **What needs a token:** `commit`, and `punish` and `finish` for any enemy below boss. `poke`, `hold`, `defend`, `dodge`, `escape`, `retreat` and `return` never do.
- **The queue** (the 4 s rotation: Ryan, I3; the rest *(proposed)*): the highest patience asks first, ties to the nearest. A holder keeps its token until its commit ends, for at most `token_hold_time` (4 s); then it can't ask again for `token_rest_time` (1.5 s), so attackers rotate. "Stunned" means any status that blocks moving or attacking; "out of reach" means no path to the target, or a melee holder against an `elevated` target it can't hit (`can_reach()`).
- Fodder in the same fight attacks freely: five thralls and a brute means the brute on a token and the thralls chipping.

### Cornered casters (MUST; Ryan 2026-10-03)
- A caster **uses an escape ability if it has one** to reset distance. **Otherwise it stops running and fights at close range with a weaker, slower option.** Catching it is a reward, not an endless chase. **CC and walls beat kiting.**
- *(proposed)* Inside its band's minimum: an `escape` use if one passes; else it walks away (at its own move speed, slower than a champion's) for up to 2 s. It stops when that runs out, when a wall or a ledge blocks the way back, or when it's slowed or rooted: **cornered**. Cornered, it squares up (`cornered` pose) and fights with its basic attack, authored as its weak, slow close option, plus any poke; it doesn't run again for 3 s.

### Aggro, packs and the leash (MUST; Ryan 2026-10-03)
- **A pack wakes on proximity or sight**, and **nearby packmates join** (a shout, a short delay). A pack is a scene of enemies placed together (DUNGEONS.md).
- **The leash:** if the player gets far enough away, the pack **gives up, walks back to its spot and recovers** (Diablo-style).
- **The default target is the nearest,** unless taunt, stealth or another rule says otherwise: ALLIES.md's target pick (the nearest by edge distance ÷ `threat`, sticky with a margin, taunt wins, a stealthed champion is never picked, a downed one is dropped at once). This doc builds it (AI2).
- **Sight stays on layer 1,** so ledges don't block it. It moves from each enemy's `Sight` RayCast2D to `WorldQuery.has_line_of_sight()` (WORLD_INTERACTION.md).
- **Waking** (Ryan, I5): a member wakes when a party member is within its `detect_range` (450 u, edge to edge) and in sight, or hits it. It **shouts**: the rest of its pack wakes `alert_delay` (0.4 s) later, and so do the members of other packs within `alert_radius` (6 m) of it that have it in sight. The shout has a look (the `alert` pose) and a sound.
- **The leash is measured from the pack's home** (its placed center), not from the enemy (Ryan, I5): when its target is more than `leash_px` (12 m) from home, or no party member has been in reach of the pack for 6 s, the pack gives up (`return`). It walks home 30% faster and once home heals to full over 1.5 s (League's jungle camps). *(proposed)* On the way it ignores new aggro for 2 s, its statuses clear at home, and a hit doesn't turn it around unless the attacker stands inside the leash.
- Arena and boss enemies never leash (their doors are sealed: DUNGEONS.md).
- Today's leash (800 u from the player, stopping where it stands) is replaced for packs: a replace of working code, asked first in AI2.

### Low health: role-based (MUST; Ryan 2026-10-03)
- **Fodder and brutes fight to the death.**
- **Casters and supports fall back toward packmates:** *(proposed)* below `retreat_health` (35%) they move behind the nearest living melee packmate (else away from the target) and keep poking.
- **Skirmishers hit and reset:** *(proposed)* after a commit's first landed hit (or 1.5 s), they retreat out to their band and hold again.

### Poise: no flinch (Ryan, I8 2026-10-03)
- **A hit never interrupts a smart enemy's cast.** Only a status that blocks casting (a stun, a silence) does, as today (COMBAT.md; League's rule). CC stays the answer to big casts and to dodgers.
- **Tenacity by rank:** elites take 20% shorter crowd control, bosses 40% (the `tenacity` stat, given at spawn by their rank: `RankRules.tenacity` 0.2 and 0.4, a FLAT modifier under `&"enemy_rank"`). Fodder and regulars have none. A knock-up still ignores tenacity (`ignores_tenacity`, 3D.md).
- Knockback is untouched: bosses get `knockback_resistance` 1 when that stat is built (WORLD_INTERACTION.md, Knockback).

### Movement and positioning (proposed)
- **The range band** (a slider, LoL units, edge to edge) is where an enemy likes to stand from its target while it holds or pokes. Melee bands sit just outside the target's reach (the Knight's swing reach 175 u plus his aim help's 125 u = 300 u), so holding never feeds his aim help.
- **Ranged behind or beside melee:** a caster scores spots in its band by how many melee packmates stand between it and the target (or within 45° of that line), and keeps 2 m from other casters.
- **Spacing:** brained enemies keep 1 m apart while holding *(proposed)*. Fodder surrounds its target in a ring, about 0.6 m apart (Ryan, I6; Groups).
- Paths use `MovementComponent.move_to()` (NavigationServer2D), re-planned at most every 0.25 s. A target on a navmesh island (a perch: 3D.md) is reached by its walk-up route if one exists; otherwise melee holds at the nearest reachable spot and releases its token, and the pack's ranged members poke: no unanswerable player either.

### Spawning (MUST: placed packs and ambushes; Ryan 2026-10-03. Spawn-in kept, to confirm)
- **Placed packs:** enemies placed in a space (a pack scene through a content slot or a marker: DUNGEONS.md), idle until they notice you.
- **Ambushes:** enemies emerge from hidden spots, or on a trigger (the party entering an area, a world state such as a chest opened). *(proposed)* They emerge after a floor telegraph (0.6 s) at each spot and aggro at once on the nearest party member. In DUNGEONS.md an ambush is the scene of an EVENT content slot.
- **Spawn-in (kept; flagged for Ryan):** DUNGEONS.md's sealed arenas and boss rooms depend on enemies that spawn in with a telegraph and instant aggro. Ryan didn't pick arena waves or reinforcements, so this doc keeps **spawn-in as a basic kind** (an arena's enemies appear together, once, when it seals) and **defers waves and mid-fight reinforcements**.
- Every spawn gets party scaling, the difficulty tier and its elite modifiers at spawn (ALLIES.md, DUNGEONS.md), so nothing heals or refills mid-fight.

### Elite modifiers (MUST: data that changes behavior; Ryan 2026-10-03)
- An elite **rolls a few modifiers from a pool authored per dungeon** (faster, shielded, teleporting, vampiric, volatile on death...). **The count is set by the difficulty tier** (DUNGEONS.md: 1, 2, 2, 3, 3). **Modifiers are data and change behavior, not only numbers.** This doc defines the format; DUNGEONS.md says how many.
- *(proposed)* An `EliteModifier` is a `ToolkitBundle` (TALENTS.md's bundle that Passive and Talent share: stat modifiers, stat scalings, unit reaction rules, statuses, augments, applied to any Unit under a source id), under the source `&"elite_modifier_<id>"`, plus: an ability put in a free slot with its `ai_uses` (a blink used to `gap_close` and to `escape`), a `BrainAdjust` (faster reactions), a look (an aura scene), `excludes` (modifiers it can't roll with), a weight and a minimum difficulty tier. A shield that comes back is a status; "on hit" and "on death" are unit reaction rules.
- Rolled at spawn from the run's seed (rerolled each run: DUNGEONS.md I3), never two that exclude each other.
- *(proposed)* A first pool to build: **Fast** (+25% move speed, reaction × 0.85), **Shielded** (a shield of 25% of its max health that comes back 6 s after it breaks), **Teleporting** (a 6 m blink with an 8 s cooldown, telegraphed 0.4 s at both ends, used to `gap_close` and `escape`; needs `MovementComponent.blink()`), **Vampiric** (`life_steal` 0.25: its hits heal it), **Volatile** (on death a 3 m circle telegraphed for 1 s, then elite-band damage; needs an area GameplayEffect, which COMBAT.md says comes later).
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
- **The budget:** *not set; written here by AI1 from its measurements.*

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

   Twelve sliders (the range band is one, with two ends). The rest of a preset is **kind**, not magnitude: the role, its intent weights, its low-health response, its retreat health, whether it uses tokens, its pose set.
2. **An in-game brain overlay** in the sandbox: per enemy, its state, chosen intent, why (its top scores), respect, patience, whether it holds a token, its dodge cooldown and its reaction timer.
3. **A live tuning panel** in the sandbox: pick an enemy, drag its sliders, watch it change while you play, and save back to its .tres.
4. **A scenario spawner:** preset situations (all cooldowns ready, none ready, low health, an ally present) and a scripted dummy player for the headless tests.
- *(proposed)* All three in-game tools live on one sandbox node, `SandboxBrains` (Architecture), on raw keys like `SandboxLoot`'s: **B** the overlay, **N** the panel, **H** the scenarios.

### Testing (MUST: scenarios in the headless suites; Ryan 2026-10-03)
- The brain is a pure function, so scenarios are tested in the headless suites, with no view and a seeded random number generator: a player with an ultimate ready at 5 m means a brute holds; the ultimate spent means it dives; a projectile aimed at a caster means `defend`; a dodge only after the reaction delay and never on cooldown; `punish` only after a real whiff; token counts and release; the leash and the pack alert; a boss reset. Each step's list is in Build order.
- *(proposed)* Two levels: **decision tests** (a hand-built `SituationContext` into `EnemyBrain.decide()`, thousands of seeded runs where a number matters) and **integration tests** (a real enemy and a champion driven by a `ScriptedController` in a test scene, physics frames stepped).
- The new suite (`enemies_test`) joins the baseline: every suite green after each step, the counts in CHANGELOG.md.

## Data (Resources)
**The format** (Ryan, I9): an `EnemyBehavior` per role (the twelve sliders and its kind), an `EnemyData` per enemy (loaded like a ChampionData), an `EnemyRoster` per dungeon (its enemies, its faction preset, its elite modifier pool). Every other name is *(proposed)* and checked against CONVENTIONS.md (reserved names, vocabulary); names go into CONVENTIONS when Ryan approves them. Resource scripts in `res://scripts/data/`; runtime scripts in `res://scripts/enemies/`.

### EnemyData (`enemy_data.gd`; `res://data/enemies/enemy_<name>.tres`)
One kind of enemy: DUNGEONS' "a shared behavior plus its own data". `Enemy.data` points at it and `Enemy._apply_enemy_data()` loads it when the enemy is ready, the way `Player._apply_champion()` loads a ChampionData. An enemy with no `data` plays exactly as today.

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
| Sliders | the twelve | | The tuning toolkit: each an `@export_range` with its limits |

### BrainAdjust (`brain_adjust.gd`; `res://data/brain_adjusts/brain_adjust_<name>.tres`)
One multiplier per slider (default 1) and `token_bonus: int` (0). Used by ranks (in the table), factions (`brain_adjust_faction_<name>.tres`), difficulty tiers (`DifficultyTier.brain_adjust`, DUNGEONS.md) and elite modifiers.

### EnemyRoster (`enemy_roster.gd`; `res://data/enemy_rosters/enemy_roster_<dungeon>.tres`)
The type of DUNGEONS' `DungeonData.roster`: `enemies: Array[EnemyData]`, `faction_name: String`, `faction: BrainAdjust` (the personality preset), `elite_modifiers: Array[EliteModifier]` (the dungeon's pool). Pools place scenes of the roster's enemies; the validator warns about a pool entry holding an enemy outside the roster *(proposed)*. The format: Ryan, I9.

### EliteModifier (`elite_modifier.gd`; `res://data/elite_modifiers/elite_modifier_<name>.tres`)
Extends `ToolkitBundle` (`display_name`, `description`, `modifiers`, `stat_scalings`, `reaction_rules` as unit rules, `statuses`, `augments`; `apply_to(unit, source_id)` / `remove_from()`), and adds `id`, `ability: Ability` (into the first free slot; none free = skipped, with a warning), `brain_adjust: BrainAdjust`, `vfx: PackedScene` (its look), `excludes: Array[StringName]`, `weight: float` (1), `min_difficulty_tier: int` (1). Source `&"elite_modifier_<id>"`.

### BossPlan and BossPhase (`boss_plan.gd`, `boss_phase.gd`; inline in the EnemyData, or `res://data/boss_plans/boss_plan_<name>.tres`)
- `BossPlan`: `phases: Array[BossPhase]`, `transition_time` (1.5), `transition_ability: Ability` (cast at a phase change; its telegraph is the warning).
- `BossPhase` (inline): `health_below` (1.0 for the first), `form: StatusEffect` (a `form` status of REPLACE augments; null = its base slots), `intent_weights` (in place of the behavior's; empty = unchanged), `pressure_time`, `breather_time` (−1 = the sliders').

### AIUse (`ai_use.gd`; inline on an Ability)
`intent: StringName` (`poke`, `gap_close`, `escape`, `defend`, `punish`, `finish`, `zone`, `damage`, `heal`, `shield`, `buff`, `cc`), `conditions: Array[Condition]` (all must pass; the situation is passed in), `weight: float` (1).

### PoseSet (`pose_set.gd`; `res://data/pose_sets/pose_set_<name>.tres`; view data)
`poses: Dictionary` (pose → `PoseLook`). `PoseLook` (inline): `clip: StringName` (a model's clip; empty = none), `lean_deg` (+ toward the target), `squash` (height scale, 1 = none), `rim_color` (alpha 0 = none), `pulse_hz` (0 = steady). `pose_set_default.tres` gives every pose of the minimum set its capsule look.

### EnemyAITable (`enemy_ai_table.gd`; `res://data/enemy_ai_tables/enemy_ai_table_default.tres`)
The global rules, held by `Brains.table` (the pattern of `LootTable`, `AllyTable` and `CompanionTable`).

| Field | Type | Value |
|---|---|---|
| `ranks` | `Array[RankRules]` | four (below) |
| `think_rate`, `pack_think_rate` | `float` | 10, 5 (per second) |
| `fodder_ring_spacing_px` | `float` | 19 (0.6 m between fodder in the ring around their target; I6) |
| `min_intent_time`, `tell_time`, `reaction_floor` | `float` | 0.4, 0.3, 0.2 |
| `switch_ratio`, `switch_px`, `switch_hold_time` | `float` | 0.25, 48, 0.5: ALLIES' target pick ("Tier B's resource") |
| `alert_radius_px`, `alert_delay` | `float` | 192, 0.4 |
| `leash_px`, `leash_out_of_reach_time` | `float` | 384, 6 |
| `return_speed_ratio`, `return_ignore_time`, `recover_time` | `float` | 1.3, 2, 1.5 |
| `tokens_per_target` | `Array[int]` | by difficulty tier: 2, 2, 2, 3, 3 |
| `token_hold_time`, `token_rest_time` | `float` | 4, 1.5 |
| `respect_by_role` | `Dictionary` (StringName → float) | `ultimate` 4, `core` 2, `mobility` 2, `defensive` 1.5, `generator` 1, `companion` 0 |
| `respect_cc_bonus` | `float` | 1 |
| `ally_respect_weight`, `ally_respect_range_px` | `float` | 0.5, 320 |
| `idle_time`, `idle_pressure`, `low_health`, `low_pressure` | `float` | 1.5, 0.5, 0.4, 0.5 |
| `major_tags` | `Array[StringName]` | `ultimate`, `charge_up`, `dash`, `leap` |
| `whiff_time`, `punish_turn_time` | `float` | 0.3, 0.6 |
| `dodge_distance_px`, `dodge_time` | `float` | 64, 0.2 |
| `ambush_telegraph_time`, `spawn_in_telegraph_time` | `float` | 0.6, 0.8 |
| `sleep_distance_px` | `float` | 0 (never) until the P-spike measures it |

### RankRules (`rank_rules.gd`; inline in the table)
`rank`, `has_brain` (fodder false), `can_dodge` (elites and bosses), `token_cost` (regular 1, elite 2; 0 = no tokens), `tenacity` (elite 0.2, boss 0.4; a FLAT `tenacity` modifier at spawn under `&"enemy_rank"`), `max_abilities` (0, 2, 3, −1 = any; the enemies test checks every EnemyData), `brain_adjust: BrainAdjust`.

### Additions to existing data
| Where | Addition | Default | Notes |
|---|---|---|---|
| `Ability` | `ai_uses: Array[AIUse]` | `[]` | empty = one `damage` use with no rules |
| `Ability` | `respect_value: float` | −1 | −1 = derived (Respect) |
| `Ability` | virtual `get_effect_area(caster, ctx) -> Dictionary` | from its tags and params | where the cast will land: `{kind: &"circle" / &"cone" / &"segment" / &"none", ...}` in px; perception reads it for party casts, and the ally brain for enemy casts. Kit abilities override it when the default misreads them |
| `Ability` | virtual `get_ai_plan(caster, situation) -> CastPlan` | ALLIES' shared default | built in AI1 (ALLIES AL4 adds the Knight's); `situation` is ALLIES' `sense` |
| `Condition.Kind` | `THREATENED`, `TARGET_WHIFFED`, `RESPECT` | | appended; read the situation |
| `Condition.is_met()`, `all_met()`, `first_failed()` | an optional last argument `situation: SituationContext` | null | the three new kinds read it; the old kinds ignore it |
| `Enemy` | `data: EnemyData`, `naive_casting: bool`, `get_brain()`, `get_pose()`, `get_pose_progress()` | null, true | |
| `DifficultyTier` (DUNGEONS.md) | `brain_adjust: BrainAdjust` | | the tier's slider adjust and token bonus |
| `DungeonData` (DUNGEONS.md) | `roster: EnemyRoster` | | the type DUNGEONS left to this doc |
| Events | `pack_alerted(pack, target)`, `boss_phase_changed(boss, phase_index)`, `boss_reset(boss)` | | reserved names |
| Vocabulary | **rank**, **role**, **brain**, **situation**, **intent**, **use rule**, **respect**, **patience**, **attack token**, **tell**, **pose**, **pack**, **alert**, **leash**, **whiff**, **punish window**, **pressure**, **breather**, **director**, **faction**, **spawn-in**, **ambush** | | for CONVENTIONS.md, on approval |

### Test and sandbox data
- `enemy_slime.tres` (fodder) and `enemy_slime_elite.tres` (an elite brute with the slam), set on today's scenes in AI1, so the slimes keep their look and numbers.
- Test enemies, capsules in their own colors: `enemy_test_brute.tres` (a telegraphed smash), `enemy_test_skirmisher.tres` (a gap-closer leap and a stab), `enemy_test_caster.tres` (a poke bolt, a `defend` shield, an `escape` blink), their elite versions, and `enemy_test_boss.tres` with a three-phase plan. Their abilities follow CONVENTIONS' file names (`test_brute_q_smash.tres`...).
- `SandboxBrains` in `sandbox.tscn` and `sandbox_3d.tscn`, and a brain corner in the sandbox to fight them in.
- `ScriptedController` (`res://scripts/tests/scripted_controller.gd`): a `UnitController` that plays a list of steps (walk to, cast a slot at, swing, wait) on a champion unit; ALLIES AL1's scripted test controller is the same class.

## Architecture / contracts
### Brains (autoload, `res://scripts/autoload/brains.gd`) *(proposed)*
- Registered after `Progress` and `Loot` (and the planned `Companions`, `Allies` and `Dungeons`), before `Audio` (which stays last).
- `table: EnemyAITable`; `rng: RandomNumberGenerator` (seedable; each brain draws its own stream from it).
- **The think schedule:** `register(brain)` / `unregister(brain)`. Each physics tick, in game time (hitstop slows it, the pause stops it), it lets the brains due on that tick think: each brain gets a fixed tick slot, so at 60 Hz and 10 thinks a second a sixth of them think on each tick. **Urgent wake-ups:** a new attack coming at a brain, its token lost, its target gone, a stun ending: that brain thinks on the next tick.
- **The shared read:** `get_snapshot() -> PartySnapshot`, built at most once per physics tick, the first time a brain asks.
- **Tokens:** `request_token(enemy, target) -> bool`, `release_token(enemy)`, `get_token_holders(target)`; the queue and timeouts of Groups.
- **Whiffs:** listens to `Events.ability_cast` and `Events.unit_hit` for party members' major abilities and keeps each champion's punish window (Punish).
- **Packs and sleep:** packs register; `is_asleep(unit)` once sleeping exists.
- `debug_draw`.

### UnitController (`res://scripts/units/unit_controller.gd`)
ALLIES.md's contract, built here first (AI1) because the enemy brain is the first controller other than the human's: a Node child of the Unit with `get_unit()`, virtual `get_aim_point()`, `get_move_direction()`, `is_human()`. ALLIES AL1 makes `PlayerInput` one and adds `AllyBrain`.

### EnemyBrain (`res://scripts/enemies/enemy_brain.gd`, extends `UnitController`)
- A child of the Enemy, added by `_apply_enemy_data()` for ranks with a brain.
- `think()`: `build_situation()` → `decide()` → `act(decision)`. Static `decide(situation, behavior, rng) -> BrainDecision`.
- **What it keeps between thinks:** patience, the intent and when it started, the attacks it has seen and when, its dodge cooldown, its token, its commit's progress, its cornered time, its pose and when it started.
- **Every tick** (cheap): carries out the current intent's movement and presses (steering, a swing when the target is in reach), as ALLIES' ally brain does.
- Queries for the view and the overlay: `get_intent()`, `get_pose()`, `get_pose_progress()`, `get_last_decision()`. Signals `intent_changed(intent)`, `pose_changed(pose)`, `dodged()`.
- `debug_draw`: its range band, home and leash, a line to its target while it holds a token, its dodge direction.

### SituationContext (RefCounted, `res://scripts/enemies/situation_context.gd`)
Pure data, filled by `EnemyBrain.build_situation()` or by a test:
- **Self:** rank, role, position, health ratio, its castable slots with their `ai_uses`, casting or not, what blocks it (stunned, rooted, airborne), dodge cooldown left, patience, current intent and its age, token held, home and distance to it, cornered time left.
- **Target:** the pick (ALLIES' rules), its position, edge distance, health ratio, kit ready, whether the enemy can reach it (path, `can_reach()`), in sight, its idle time, its punish window (size and age), whether it's casting.
- **The party:** respect (and each champion's share), the number of champions, tokens free on the target.
- **Incoming attacks:** a list of `{source, ability, kind (CAST, CHARGE_UP, PROJECTILE), area, time_to_hit, age, dodgeable}`, each aimed at or covering self.
- **Packmates:** count, roles, positions of melee packmates, token holders.
- The live nodes (`target_unit`, `self_unit`) ride along for the act step only; `decide()` never reads them.

### PartySnapshot (RefCounted, `res://scripts/enemies/party_snapshot.gd`)
Per champion (the `party` group from ALLIES; the `player` until then): the unit, position, health ratio, up or downed, targetable, stealthed, `threat`, each slot's ability, ready, cooldown left and value, kit ready, its respect share, its cast in progress (ability, area, time to the effect), its punish window, its idle time. Plus the party's projectiles in flight (area, time to each point). Companions never appear.

### BrainDecision (RefCounted)
`intent`, `plan: CastPlan` (null = no cast), `move_to: Vector2`, `pose`, `scores: Dictionary` (intent → score: the overlay's "why"), `reason: String`.

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

### CastPlan and get_ai_plan() (ALLIES.md's, built here first)
ALLIES' `CastPlan` (`res://scripts/abilities/cast_plan.gd`) and `Ability.get_ai_plan(caster, situation)` with the shared default are built in AI1, since the brain needs aims. The default aims at the target where it stands now (no leading: an enemy's shot can be walked out of, COMBAT.md), wraps `get_ai_vector()` for a VECTOR ability, and copies the intents of the ability's passing `ai_uses` into the plan's `intents`. Enemy abilities override it where they need to (AI3); ALLIES AL4 adds the Knight's.

### Enemy (additive changes to `enemy.gd`)
- `data: EnemyData` (export; null = exactly today). `_apply_enemy_data()` when ready: stats, abilities by difficulty tier, the twist, the model, attack tags, and the brain for ranks with one.
- In `_physics_process`, while a brain runs the fodder routine stands down; `_try_cast_ability()` runs only with `naive_casting` and no brain.
- The fodder routine gains its pack's alert and leash (AI2) and takes its target from the shared pick.
- `_can_see_player()` moves to `WorldQuery.has_line_of_sight()`; the `Sight` node stays until Ryan OKs removing it.
- `get_pose()` and `get_pose_progress()` (the brain's, or empty).

### Pack (`res://scripts/enemies/pack.gd`; the root of a pack scene) *(proposed)*
- A Node2D whose Enemy children are the pack. `home` = its position when placed. An enemy placed on its own is a pack of one (its own position is home).
- The shout (`alert(target)`, `Events.pack_alerted`), the leash and the walk home, and the fodder members' group think (their spots around the target, `pack_think_rate` times a second).

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

### SandboxBrains (`res://scripts/rooms/sandbox_brains.gd`; in `sandbox.tscn` and `sandbox_3d.tscn`) *(proposed)*
- **B** toggles **the brain overlay:** over each brained enemy (ScreenOverlay text): its intent and pose, its top three scores, respect, patience, its token (held, waiting or none), its dodge cooldown and its reaction timer; on the floor (debug drawings): its band, home and leash, token lines.
- **N** opens **the tuning panel:** the brained enemy nearest the cursor is picked (`,` and `.` cycle), and its twelve sliders show as bars with the resolved value and the preset's. A change applies at once to it and to every enemy sharing its data. **Ctrl+S** saves into its behavior preset (the archetype .tres); **Ctrl+Shift+S** saves an override into its `EnemyData` (a warning past three). Saving works only in a run from the editor (`OS.has_feature("editor")`), never in an exported build or a test scene. After a save, Godot reports the file changed on disk: choose Reload (CLAUDE.md, Known issues).
- **H** cycles **the scenarios:** all cooldowns ready, none ready, low health (25%), an ally present (a friendly stand-in dummy until ALLIES), a whiff (Judgement spent at nothing), an incoming shot (a test bolt fired at the picked enemy). Each spawns the chosen test enemy 5 m away and sets the Knight's cooldowns and health through test hooks.
- It never touches the player's saves.

## View
- **Every enemy is a Unit with a `UnitView`** (3D.md): a capsule in `model_color`, or `EnemyData.model_scene`. Clips, once enemies have models, come from the base clip names on `UnitView` and the pose set.
- **Pose hooks** *(proposed; built in AI1 with the brute's poses)*: each tick `UnitView` reads `Enemy.get_pose()` and `get_pose_progress()` and the enemy's `PoseSet`, and blends to that pose's look over 0.08 s. On a capsule: the lean (a tilt about its base, toward or away from the target), the squash (height down, width up), the rim pulse (the hit flash's additive overlay gets a second, tinted channel; the hit flash wins while it plays). On a model: the pose's clip. The view never changes gameplay state; poses come from the sim (the brain), the way cast progress does.
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
| A taunt | ALLIES' rule: the taunter is the target while it's a candidate; the taunted enemy needs no token for it *(proposed)* |
| A token holder is stunned, rooted or knocked up | It releases its token at once and asks again after `token_rest_time` |
| A token holder dies | Its token frees the same tick |
| Every token held by enemies that can't reach | They release after the out-of-reach check; the next in the queue asks |
| The champion stands on a perch | Melee walks its route up if one exists; otherwise holds below without a token while the pack's ranged members poke |
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
| Tests | No view; `Brains.rng` seeded; saving off (`Progress.is_test_scene()`); the panel never saves in a test scene |

## Build order (proposed; one step per request; each ends with Ryan's play test)
**Before AI1:** nothing in the code blocks it. Where it goes in the order of work is Ryan's call (Open questions): CLAUDE.md has LOOT L4 next, ALLIES.md puts the second champion before "Tier B" (AI1–AI2), and DUNGEONS.md wants AI1–AI2 before its D1. Dodging (AI4) is best tested against a ranged kit with skillshots.
Every step: Ryan runs `git status` first; the Knight's abilities, talents, enemies chasing and the HUD still work; an enemy with no `EnemyData` plays exactly as before; the new `enemies_test` suite joins the baseline (every suite green, the counts in CHANGELOG.md under an Enemies AI section); this doc keeps one line per built step.

1. **AI1 – The tooling and the brain skeleton.** `EnemyData` (the slimes and the test brute on data), `EnemyBehavior` with the twelve sliders, `BrainAdjust`, `RankRules` (with tenacity by rank), `EnemyAITable`, the `Brains` autoload (the staggered schedule, the shared snapshot), `UnitController`, `EnemyBrain` with `SituationContext` and `BrainDecision`, the intents `hold`, `commit` and `poke` for the brute, respect (derived values, `respect_value`) and patience, `AIUse` and `Ability.ai_uses`, `CastPlan` and the default `get_ai_plan()`, the `RESPECT` condition kind and the situation argument, the `tell_time` lead, the brute's poses (`PoseSet`, UnitView's pose hooks), `Enemy.naive_casting` (the naive loop off behind it), `SandboxBrains` (B, N with saving, H), `ScriptedController`, `enemies_test`. **The measured performance budget** (Performance), written into this doc.
   **Done means:** with the brute and everything up, it holds and circles at 350–500 u; after Lunge and Judgement go down it crouches and dives; its hold always ends within 12 s (4 × its 3 s `patience_time`); dragging a slider changes it live and saving writes the .tres; the scenarios load; with the brain off the elite slime casts as before. **Tests:** an ultimate ready at 5 m → `hold`; spent → `commit`; respect from known kits; patience's fill and its floor; the same seed → the same decisions; ranks' ability counts; the naive loop gated. **Play test:** Ryan fights the test brute.
2. **AI2 – Groups (tokens, packs, alert, leash).** Token pools per target (`tokens_per_target`, rank costs, the queue, release on stun, death, out of reach, timeouts), `Pack` (home, the shout, the walk home and recovery), the fodder group think (the ring around the target, 0.6 m apart), ALLIES' target pick (nearest by `threat`, sticky with the margin, taunt, stealth, downed; tested on a second PLAYER-team dummy), sight through `WorldQuery`, the old leash replaced for packs (asked first).
   **Done means:** five test brutes never put more than two on you at tier 1, and they rotate; a stunned holder frees its token at once; one pack member noticing wakes its pack 0.4 s later; walking 12 m away sends them home to heal; fodder surrounds you with no tokens. **Tests:** token counts and release, timeouts, pack alert (through walls for packmates, sight for other packs), the leash and recovery, the target pick's margin, taunt and stealth. **Play test:** a pack fight in the sandbox.
3. **AI3 – Skirmisher and caster.** Range bands and positioning (ranged behind or beside melee), `poke`, `defend` (incoming attacks, `get_effect_area()`, the `THREATENED` kind), `escape` or fight (cornered), role-based retreat, the skirmisher's dive and reset, the test skirmisher and caster with their plans, their poses.
   **Done means:** the caster pokes from 550–800 u, shields only when something is aimed at it, blinks away when caught and squares up when its blink is down; the skirmisher dives when respect drops and hops out after its hit. **Tests:** a projectile aimed at a caster → `defend`; nothing aimed → no shield; cornered → basic attacks, no running for 3 s; low health → behind a melee packmate. **Play test:** a mixed pack.
4. **AI4 – Dodging.** The sidestep (elites and bosses), the reaction delay, one roll per attack, the dodge cooldown, never while casting or crowd-controlled, the free-side check, the `sidestep` pose; which party abilities are dodgeable (Dodging).
   **Done means:** an elite sidesteps a Cleave Wave thrown from range a beat late, never twice inside its cooldown, never a Judgement; a stunned or casting elite takes the hit. **Tests:** no dodge before the reaction time; none on cooldown; none while casting, stunned, rooted or airborne; never into a wall or off a ledge; fodder and regulars never dodge. **Play test:** baiting and beating a dodging elite.
5. **AI5 – Elite modifiers.** `EliteModifier`, the roster's pool, the count by difficulty tier (a sandbox key stands in for the tier until DUNGEONS D8), the first pool (Fast, Shielded, Teleporting with `blink()`, Vampiric, Volatile with its area effect), excludes, the names under the bar.
   **Done means:** elites roll the right count with no excluded pairs; each modifier changes how the fight plays. **Tests:** seeded rolls, counts per tier, excludes, sources removed exactly, the blink's use rules. **Play test:** each modifier on the test brute.
6. **AI6 – The boss director.** `BossPlan`, `BossPhase`, phases and transitions, the pressure and breather tempo, `punish` (whiffs, `TARGET_WHIFFED`, window sizing), `finish`, the knowledge of the ally's cooldowns, `reset()`, the test boss and its arena corner.
   **Done means:** the boss's tempo reads; a whiffed Judgement draws a telegraphed punish a dash answers; below 30% it goes for a telegraphed finisher; dying resets it cleanly. **Tests:** no punish without a real whiff (a landed ultimate opens nothing); window sizes pick the right attack; phase thresholds; the breather allows only pokes and zones; reset restores everything. **Play test:** the test boss.
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

### Claude's other proposals (written in above as *(proposed)*; Ryan can overrule any)
1. **Names** (`EnemyData`, `EnemyBehavior` and `EnemyRoster` approved as the format in I9; the rest open): `EnemyAbilitySlot`, `BrainAdjust`, `EliteModifier`, `BossPlan`, `BossPhase`, `AIUse`, `PoseSet`, `PoseLook`, `EnemyAITable`, `RankRules`, `Brains` (autoload), `EnemyBrain`, `SituationContext`, `PartySnapshot`, `BrainDecision`, `Pack`, `BossDirector`, `Ambush`, `EnemySpawner`, `SandboxBrains`, `ScriptedController`; `Ability.ai_uses`, `respect_value`, `get_effect_area()`; `Condition.Kind.THREATENED`, `TARGET_WHIFFED`, `RESPECT`; `Enemy.data`, `naive_casting`; the Events `pack_alerted`, `boss_phase_changed`, `boss_reset`; the source ids `elite_modifier_<id>`, `enemy_<id>`; the intents and intent tags; the word **rank** for the ladder (CONVENTIONS calls elite and boss "enemy tiers").
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

### Conflicts and notes for Ryan (found 2026-10-03)
- **Arena spawn-in vs waves:** DUNGEONS.md proposes arena waves (`ArenaWave`, `next_wave_at`); Ryan didn't pick waves or reinforcements. This doc keeps spawn-in (one group at the seal) and defers waves; DUNGEONS' wave proposal is marked waiting on Ryan.
- **Data intents vs ALLIES' script-only AI:** ALLIES' decision ("one AI method per ability ... replaces the brief's data hints") and this brief's data intent tags both stand: the data says what for and when, the script says how and how good. ALLIES' `engage` intent is renamed `gap_close`, and `get_ai_plan()`'s `sense` is the `SituationContext`.
- **"Rank" vs "enemy tier":** CONVENTIONS.md's vocabulary calls elite and boss enemy tiers; this doc proposes "rank". CONVENTIONS isn't edited until Ryan picks.
- **Where elite modifiers are defined:** COMBAT.md's Out of scope and CONVENTIONS.md's vocabulary point to DUNGEONS.md; DUNGEONS.md says ENEMIES_AI defines them. Now: the format here, the count in DUNGEONS. COMBAT's pointer is fixed; CONVENTIONS' waits for the names.
- **"Random dodge" in COMBAT's references:** a visible sidestep with a chance to try is not a hit that silently misses (Dodging).
- **Think rates:** the ally brain thinks 5 times a second (ALLIES.md), enemy brains about 10; both are data and both are measured.
- **The order of work:** ALLIES.md's order (the second champion → Tier B → ALLIES) and CLAUDE.md's Next (LOOT L4) don't place AI1 yet.
- **VISION.md, Open question 7** (big fights vs methodical): answered by this doc's groups (fodder swarms, smart enemies take turns on tokens); VISION.md isn't edited here.
- **The stand-ins in TALENTS.md and LOOT.md** (`xp_by_unit`, `get_kill_tags()`, `drop_table_by_unit`) retire in AI7; their docs get the pointer when Ryan OKs it (COMPANIONS.md's is applied).

### For other docs
- **ALLIES.md** (applied 2026-10-03): Tier B is AI1–AI2; `UnitController`, `CastPlan` and the default `get_ai_plan()` are built in AI1; the shared intent tags; the target pick's numbers in `EnemyAITable`; tokens per champion as the party-size hook; the ally brain may reuse the toolkit (the situation, the overlay, the panel).
- **DUNGEONS.md** (applied 2026-10-03): `EnemyRoster` as `DungeonData.roster`; faction presets; `DifficultyTier.brain_adjust`; elite modifiers' format here; ambushes and spawn-in; waves deferred; `BossDirector.reset()`.
- **ABILITIES.md, COMBAT.md** (applied 2026-10-03): `ai_uses`, `respect_value`, `get_effect_area()`, the three condition kinds; enemy roles in the threat kinds; dodge and tell rules; bands unchanged.
- **WORLD_INTERACTION.md** (applied): ambush triggers; `Sight` into WorldQuery in AI2. **COMPANIONS.md** (applied): drops from `EnemyData`. **3D.md** (applied): pose hooks; the perched sniper; enemy attacks' `melee` tag.
- **CONVENTIONS.md** (on approval): the names and words above. **TALENTS.md, LOOT.md** (on approval): their stand-ins retire in AI7. **VISION.md** (on approval): Open question 7 answered. **AUDIO.md**: the hooks above join its "later, per system" list when built.
