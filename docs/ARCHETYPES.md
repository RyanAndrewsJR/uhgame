# ARCHETYPES.md: Archetypes Shared by Champions and Enemies, Strings, the Beat, Perilous Attacks, Duel Pressure, and the Assassin's Deflect and Poise
<!-- Written 2026-10-07 from Ryan's fifteen decisions (his interview with his design advisor, the same day). Docs only: nothing here is built beyond the deflect prototype (CHANGELOG.md, Combat, PROTOTYPE). Ryan answered its 17 open questions the same day, and its edits to five other docs (Edits to other docs) were applied the same day. -->

**Read when:** the task involves an archetype (Assassin, Mage, Skirmisher, Bruiser, Duelist; Basic for fodder) on a champion or an enemy; deflecting (the deflect window, the refund, the streak, the jab, the riposte, being rebuffed); the poise meter and its break; an enemy's string and the beat; perilous attacks and their icon; duel pressure; weak basic attacks; which archetypes each rank may have; a boss's scripted events; the Knight's deflect test version and its removal.
**Depends on:** VISION.md (Pillar 1, decision priorities), CONVENTIONS.md, DECISIONS.md (the 2026-10-07 rows in Conventions, Combat and Enemies), COMBAT.md (hits, statuses, damage bands, diminishing returns), MOVEMENT.md (Dash), ABILITIES.md (Empowers, `recovery_time`), CHAMPIONS.md (the Knight, Korsavil), ENEMIES_AI.md (the brain, ranks and roles, tells and poses, attack tokens, combo plans, "Poise: no flinch", the poise hook, bosses).
**Used by:** CHAMPIONS (each champion's archetype layer), ENEMIES_AI (archetypes in place of roles, strings, perilous attacks, duel pressure), COMBAT (deflects, poise, rebuffed, the beat), MOVEMENT (the Assassin's dash), DUNGEONS (which archetypes a roster may hold), UI (the perilous icon, the poise meter), AUDIO (hooks).
**Status:** written 2026-10-07. Ryan's fifteen decisions (2026-10-07, with his design advisor) are MUST, cited **D1–D15** below; the decisions settled before them (DECISIONS.md, 2026-10-07) are MUST too. **Only the Assassin layer is locked** (D2): the Mage, Skirmisher, Bruiser and Duelist layers are placeholders that give only their window source and string shape, with the advisor's proposals kept as *(proposed, placeholder)*. Claude's picks are *(proposed)*; Ryan can overrule any. **Ryan answered all 17 open questions the same day** (Open questions; DECISIONS.md, Archetypes), and those answers are MUST too. The edits CONVENTIONS, ENEMIES_AI, CHAMPIONS, COMBAT and MOVEMENT needed (Edits to other docs) were approved and applied the same day; the docs in "Also" get theirs with their own steps. **AR1a (the melee strings) passed 2026-10-08; AR1b (the Mage volley) and the mix built 2026-10-08; AR2 (perilous attacks) built 2026-10-08 with R0's quirk fixed**, awaiting Ryan's play test (Build order). Units: League units, 100 u = 1 m = 32 px.

## How to read this doc
As in ENEMIES_AI.md: MUST (Ryan's; never changed without asking him), TARGET (every number: a start value for the play tests), *(proposed)* (Claude's pick; Ryan can overrule it).

## Player experience
As Korsavil you walk up to an elite. It crouches, its blade goes back, and half a second later the first hit comes: you dash into it. A clang, the hit is gone, your dash is already back, and you're still at its side. The second hit comes on the same rhythm; you dash again and the riposte is yours. One swing tears off a sixth of its health. If it were an Assassin, the gold bar under its health would fill and break, and it would stand there open, taking half again as much. Another time an enemy Assassin raises its blade across its body with a glint as you close in: swing into that and you're rebuffed, your swing thrown back and its riposte coming, so you wait out its stance and punish its cooldown. A red icon flashes over a brute's head: perilous. As Korsavil you deflect it for the full riposte at once; as the Knight you dash through it. Swinging without your kit barely scratches an elite; your kit is what kills.

## References
- **Sekiro: Shadows Die Twice.** Take: posture that fills up to a break (D1), the player's own posture recovered by deflecting (D3b), a deflect that rings and opens the enemy, perilous attacks announced by a glyph (D5), enemies that string hits so deflects come in pairs, weak sword chip next to big openings (D12). Don't take: one-hit deathblows (the riposte and the break are big damage and a window, not a kill), deflect as the only defence (the dash stays a dodge for everyone).
- **Hades.** Take: the dash always answers (non-Assassins dodge perilous attacks with the dash's i-frames); elite variants of the same enemy (D13). Don't take: bullet-hell density.
- **League of Legends.** Take: champion archetypes as play styles (assassin, mage, bruiser, skirmisher, duelist); Fiora's Riposte (W), the model for the Duelist's counter stance (placeholder). Don't take: the class list as a balance tool.
- **Hi-Fi Rush, Bayonetta's Witch Time** (the Skirmisher's Tempo, placeholder); **Gears of War's active reload** (the Mage's release, placeholder); **Sekiro's mini-bosses** (one archetype per boss with a perilous layer, D13).

## Current code
- **The deflect prototype** (DECISIONS.md, Combat, 2026-10-07; CHANGELOG.md, Combat, PROTOTYPE: slices A–C and the follow-up). Every piece sits behind a flag that is off in shipped config:
  - `DeflectComponent` (`res://scripts/components/deflect_component.gd`; a node on `player.tscn`, so every champion; `Unit.deflect_component`), behind the static flag `deflect_test_enabled`:
    - the window opens when the unit's dash starts (`DashComponent.dash_started`) and lasts `deflect_window` 0.15 s, a timer of its own beside the i-frames;
    - `try_deflect(ctx)`, called first in `Unit.on_hit()`, blocks a `deflectable` hit from an enemy (`ctx.deflected`, `ctx.blocked`: no damage, knockback, statuses, on-hit or post-hit i-frames);
    - the streak counts deflects. The first refunds the dash charge (`DashComponent.add_refund_charge()`, `refund_lifetime` 3 s) and deals 25 poise damage to the attacker. The second deals 50 and gives the riposte (`empower_riposte`: +3.0 AD ratio and +40 poise damage on the next swing that hits; it lasts `riposte_window` 1.5 s, and its swing snaps toward the attacker up to `riposte_snap_range` 300 u);
    - the streak ends on a dash that deflects nothing, `chain_window` 4 s after the last deflect, or once the riposte is given;
    - `streak_persists` (off by default; Ryan's follow-up under test, on in the sandbox): no chain window, a plain dash keeps the streak, the riposte waits for a landed swing with no time limit;
    - while the flag is on, the dash recharges in `deflect_test_charge_recharge` 1.5 s (the dash's own is 0.35 s);
    - the feel exports: a 0.08 s hitstop, a 1.5 shake, a flash on the attacker's model, a ring while the riposte is ready, empty VFX and sound slots;
    - `open_window()` is public, but no enemy calls it: enemies have no DashComponent.
  - `PoiseComponent` (`res://scripts/components/poise_component.gd`; a node on `slime.tscn`, so every enemy; `Unit.poise_component`), behind the static flag `poise_test_enabled`:
    - `poise_max` from `EnemyData.poise_max` at spawn: the elite slime and the test duelist 100, every other enemy 0, the player none;
    - it **drains** from full: `take_poise_damage()` from a hit's `HitContext.poise_damage` once the hit gets through (`HitPipeline.apply_poise_damage()`), or from a deflect; it fills back at 15 a second after 3 s;
    - at 0, `status_poise_broken` (1.8 s; tags `poise_broken`, `debuff`; not `cc`, so no tenacity, no diminishing returns and no cleanse; it blocks moving, attacking, casting and dashing and cuts a cast or windup; `incoming_damage` ×1.5), then full again and immune for 4 s;
    - it isn't the boss poise hook (`RankRules.poise`, `StatusComponent.poise`, built off in ENEMIES_AI AI-D3).
  - `DashComponent` gained `add_refund_charge()`, `has_refund()`, `get_refund_left()` and `get_recharge_time()`. Every dash is 400 u (128 px) over 0.18 s, with `dash_charges` charges (1 by default) recharging in 0.35 s.
  - Data: `deflectable` on `Ability` and on `AutoAttackComponent` (a League-style attack); set on the test brute's basic attack, the elite slime's slam and the test duelist's strike and finisher; the Big hit's purple `telegraph_color` marks the non-deflectable test attack. `poise_damage` on `Ability` (Cleave and Cleave Wave 20, Judgement and its leap 40) and on `AttackSwing` (the Knight's three swings and his dash-strike, 4 each). `StatusEffect.empower_poise_damage`. `HitContext.deflectable`, `deflected`, `poise_damage`.
  - Events: `hit_deflected(attacker, defender, ctx)`, `deflect_streak_changed(unit, streak)`, `riposte_ready(unit)`, `poise_changed(unit, value, maximum)`, `poise_broken(unit)`.
  - The TEMP lever `AutoAttackComponent.prototype_unempowered_auto_mult` (1.0 = off; the sandbox starts it at 0.5) scales only the Knight's unempowered swings (`_is_prototype_weak_auto()` checks that the tracked player is the Knight).
  - `SandboxDeflect` (`res://scripts/rooms/sandbox_deflect.gd`, in both sandboxes): V the deflect flag, Shift+V the poise flag, M the tuning panel (every number live, the "deflects bank" checkbox); readouts (a poise bar under any unit with a running meter, the Knight's dash charges with the refunded one in gold, two streak pips, "RIPOSTE"); everything put back on exit.
  - Tests: `deflect_test` (146 checks, plus 9 for the follow-up).
- **How enemies attack today:** a League-style basic attack (`AutoAttackComponent` with `combo` null: chase, a windup from `UnitStats.attack_windup`, the hit). A commit (`EnemyBrain._start_commit()`) holds its `crouch` tell for `tell_time` (0.3 s), then attacks until `commit_hits` (2) basic attacks land, its first cast ends or `commit_max_time` (4 s) passes; a skirmisher's commit ends at its first landed hit. Its tokens go when the commit ends (`token_hold_time` 4 s at most; a combo plan keeps them to its end, `plan_max_time` 6 s). There were no strings, no beat and no perilous attacks; combo mode (`AttackCombo`, `try_swing()`) was only the player's. *(Since AR1a, 2026-10-08: the test brute, skirmisher and duelist and the elite slime commit into strings through `run_string()`, combo mode's swing code; since AR1b the test casters commit into their volley, a RANGED string. Strings and the beat.)* `AttackCombo.AttackStyle.RANGED` exists as data, but `AutoAttackComponent` never reads it.
- **Patience's pressure** (`EnemyAITable`): + `idle_pressure` 0.5 while the target has done nothing (no move, swing, dash or cast) for `idle_time` 1.5 s; + `low_pressure` 0.5 below `low_health` 0.4. Nothing reads the damage the player deals.
- **The archetype words in code:**
  - `ChampionData.champion_class` (`StringName`): `&"bruiser"` on the Knight, `&"assassin"` on Korsavil; only tests read it.
  - `EnemyBehavior.Role` (`BRUTE`, `SKIRMISHER`, `CASTER`; stored as 0, 1, 2 in the presets): read in 8 places in `enemy_brain.gd`, by `SituationContext.role` and in 10 places in `enemies_test.gd`. Presets `enemy_behavior_brute.tres`, `enemy_behavior_skirmisher.tres`, `enemy_behavior_caster.tres`. The test duelist uses the brute preset.
  - `EnemyData.duelist`, read by `EnemyAITable.get_think_rate_for()`, the enemies test (9 places) and the deflect test.
  - `EnemyAITable.caster_poke_score` and `caster_spacing_px`. "Caster" also means any unit casting an ability (`PartySnapshot`'s projectiles carry a `caster`), one more reason the role becomes Mage.
- **Korsavil's dashes:** her passive carries a FLAT +1 `dash_charges` (`data/champions/korsavil.tres`): two dashes.
- **Rooms:** `Main` builds one room per scene (`layout.build_sim()`); nothing signals leaving a room yet (DUNGEONS' traversal between spaces isn't built).
- **Deflectable shapes today:** the elite slime's slam (`slime_elite_q_slam.tres`) and the test duelist's finisher (`test_duelist_r_finisher.tres`) both run `slime/slam.gd`, a circle placed "where the target stood": areas placed at the player, marked deflectable.
- **The Champion Kit Board** (`docs/champion_board/`, v2) already uses the five archetypes and Basic, with Tank, Marksman and Support kept as Legacy (DECISIONS.md, General, 2026-10-07).

## Goal / feel
Sekiro inside League-style kits (Ryan, 2026-10-07): readable rhythm, a payoff for reading it, and openings the kit cashes in. Every number is TARGET.

| What | Number | Source |
|---|---|---|
| Archetypes | Assassin, Mage, Skirmisher, Bruiser, Duelist; fodder's is **Basic** (fodder stays a rank) | MUST (2026-10-07) |
| Locked layers | Assassin only; the other four are placeholders | D2 |
| The beat | 0.5 s from a deflectable hit's tell to its hit | D8 |
| An opener's tell | 0.6 s or more (a string's first hit) | Ryan's telegraph rule |
| A later hit's wind-up | 0.25 s or more | Ryan's telegraph rule, D6 |
| Hit-to-hit spacing in a string | Assassin 0.4 s, Skirmisher 0.35 s, Mage bolts 0.45 s, Duelist 0.5 s, Bruiser 0.9 s | D8 |
| String lengths | Basic none; Bruiser 2–3 heavy hits; Skirmisher 2–3 fast hits, then its reset; Mage a 3-bolt volley; Duelist 4–5 hits; Assassin 3–4 fast hits. Regulars the low end, elites the full range, bosses +1 | approved 2026-10-07; D8 |
| The player's deflect window | 0.2 s from the dash's start (was 0.15) | D8 |
| The Assassin's dash | one charge, 25% longer: 500 u (160 px, up from 128) over 0.18 s; recharge 1.2 s (tuned 0.8–1.5 in AR5); the Knight's stays 0.35 s | D8, D11; Ryan (Open questions 5) |
| The refund | one charge, kept 3 s; the dash recharges in 1.5 s while testing (the prototype) | D8 |
| The jab | after one deflect, the next swing +1.0 AD ratio, snapping up to 1.5 m; it ends the streak | D8; Ryan (Open questions 17) |
| The riposte | +3.0 AD ratio plus 12% of the target's max health (a boss's 4%); banked until a swing lands; snaps 3 m (6 m after a projectile deflect) | D7, D8 |
| The banked streak | no chain window; expires 10 s after the last deflect and clears on leaving the room | Ryan (Open questions 4) |
| Poise (Assassin units only) | enemies: regular 60, elite 100, boss 160; Korsavil 100. Fills up to a break | D1, D3, D3b, D8 |
| The break | enemies 1.5 s (regular), 1.8 s (elite), 1.4 s (boss) at ×1.5 damage taken; Korsavil 1.0 s at ×1.25; then 4 s immune | D3b, D8 |
| Decay | 15 a second after 3 s with no poise hit; ×0.5 below 40% health (×0.5 is D1's proposed number) | D1 |
| The enemy Riposte Stance | a 0.5 s window, 6 s cooldown, 0.6 s recovery if it deflects nothing | D4 |
| Rebuffed | a champion: the swing cancelled, a 0.4 s attack lock (only attacking), the combo back to swing 1, no damage; an enemy whose perilous attack is deflected: 1.0 s, attacking, casting and dashing blocked | D4, D5; Ryan (Open questions 8) |
| An enemy's riposte | its next hit ×2 for 1 s: +1.0 AD ratio on its next basic attack hit only, never a perilous hit | D4; Ryan (Open questions 16) |
| Perilous attacks | 35–40% of the player's max health (no kill protection); attacker-centered, always deflectable; an icon for 0.4 s at the windup's start, the windup 0.9 s or more (about 0.5 s after the icon); elites 1 (cooldown 12–15 s), bosses 2–3 across their phases (10 s), regulars none; none in a fight's first 6 s; one live at a time (two with a boss) | D5 |
| Duel pressure | +0.1 `aggression` per deflect, capped at +0.3, until the brain resets; no damage dealt for 4 s: patience fills ×1.25, after 8 s ×1.5, stacking with today's pressure; patience never fills more than ×2 as fast as it would without its boosts | D8, D10; Ryan (Open questions 10) |
| Weak basic attacks | an unempowered swing deals 50% of today's damage (per champion, in data); empowered swings unchanged; not enemies. A player who only swings kills an elite at least 2× slower than one using the kit | D12 |

**The cadence it's built for** (D8): an elite Assassin's string. Its first hit lands 0.5 s after its wind-up starts: deflected, the dash refunded. Its second lands at 0.9 s (0.4 s later): deflected, the riposte given. The riposte swing lands at about 1.0 s. A deflect pair now fits inside one string instead of waiting on enemies that rarely attack (the play test's complaint, with "the timing felt inconsistent").

## Core rules

### The grammar: read, commit, payoff (MUST: the layers add, never replace; the three words *(proposed)*)
Every archetype, champion or enemy, plays in the same three steps:
1. **Read:** the attacker shows what's coming: its tell (body language, ENEMIES_AI's Tells), the beat, a perilous icon. A defender, player or brain, reads only what's on screen: no input reading (ENEMIES_AI's fair knowledge; D10).
2. **Commit:** the attacker spends something it can't take back: a string on its token, a perilous move on its cooldown, a stance, a dash.
3. **Payoff:** the defender who read it right gets the attacker's **window**, a moment to punish it. Each archetype has one window source (below), and every champion has an answer to each (VISION.md's "no unanswerable enemy").

These layers **add to an enemy's kit and AI uses and never replace or gate them** (MUST, 2026-10-07): an enemy still uses its abilities the way its archetype wants.

**Window sources by archetype:**

| Archetype | An enemy's window (what the player punishes) | A champion's layer (what empowers its basic attacks: D12) | Status |
|---|---|---|---|
| Assassin | the deflect pair (the refund, the riposte) and the poise break; its Riposte Stance's cooldown and 0.6 s whiff recovery | the deflect-dash, the refund, the jab, the riposte, the poise meter | **locked** (D3, D3b, D4, D11) |
| Skirmisher | the hop-out reset (about 1 s); a root or pin breaks it | Tempo *(proposed, placeholder)* | placeholder |
| Mage | its volley, a visible channel that crowd control (never damage) interrupts into a 1.2 s backlash *(proposed, placeholder)* | charge and release *(proposed, placeholder)*; its marks (D12) | placeholder |
| Bruiser | a heavy hit's recovery of 1.0–1.4 s, opened by dodging it, not by deflecting it *(proposed, placeholder)* | Brace *(proposed, placeholder)*; the Knight's Iron Resolve and Fury payoffs (D12) | placeholder |
| Duelist | *(proposed)* the recovery after its string's last hit and after its finisher (`recovery_time`: the test duelist's 1.2 s) | a counter stance *(proposed, placeholder)* | placeholder |
| Basic | none (fodder dies fast) | (no champion is Basic) | MUST |

### Strings and the beat (MUST: the shapes approved 2026-10-07; D6, D7, D8)
- **A string:** once committed, an enemy attacks in a chain of basic attack swings, an `AttackCombo` like the player's combo, its rhythm the swings' timings (DECISIONS.md, Enemies, 2026-10-07). "String" is the enemy's word: "combo" stays the player's basic attack chain and "combo plan" an enemy's chain of abilities (CONVENTIONS).
- **Shape by archetype** (approved): Basic none; Bruiser 2–3 heavy hits; Skirmisher 2–3 fast hits, then its reset; Mage a 3-bolt volley; Duelist 4–5 hits, the most pressure; Assassin 3–4 fast hits.
- **Length by rank** (D8): regulars the low end, elites the full range, bosses +1. A Bruiser string is 2 hits on a regular, 2–3 on an elite, 2–4 on a boss.
- **Spacing** (D8): Assassin 0.4 s, Skirmisher 0.35 s, Mage bolts 0.45 s, Duelist 0.5 s, Bruiser 0.9 s, hit to hit.
- **The beat** (D8): every deflectable hit lands 0.5 s after its tell. How it fits with the spacing (Claude's reading, confirmed by Ryan: Open questions 2):
  - a string's **first hit**: the commit's tell pose (`tell_time`, 0.3 s), then its wind-up; the hit lands on the beat, 0.5 s after the wind-up starts. It reads for 0.8 s in all, so it keeps Ryan's opener rule (0.6 s or more; D6);
  - its **later hits** come at the archetype's spacing, each with a visible wind-up of at least 0.25 s (D6, which calls this "on the shared beat"), so an Assassin can deflect each one;
  - a **lone** deflectable hit (a perilous attack, a deflectable ability outside a string) lands on the beat after its own tell; a perilous attack's tell is its icon (Perilous attacks).
  - This matches D8's worked cadence: a deflect at 0.5 s, the next hit at about 0.9 s, the riposte at about 1.0 s.
- **Every string hit is deflectable** (D6). A Mage's bolts only when marked (D7, below).
- **The AI** (D6):
  - Patience fills, the enemy commits, a string runs. With no combo plan active, a commit is a string. Inside a plan, a string is a **step kind** (crowd control, string, finisher). Plans stay the ability layer, strings the basic-attack layer.
  - **Tokens:** the enemy holds its attack tokens for the whole string, at the normal cost (regular 1, elite 2), and lets them go on the last hit's recovery, a stun, a poise break or its death.
  - **Respect sets the length:** high respect cuts the string to 2 hits; low respect, or its target at low health, lets it run its full length or extend. *(proposed numbers)* Effective respect 0.6 or more: 2 hits. 0.3 or less, or the target below the table's `low_health` (40%): its full length, and an elite or boss extends it by one hit at a chance equal to its `aggression`. In between: a length rolled in its rank's range.
  - **A deflect never ends a string** (D10), so the second deflect can come.
- **Found while building AR1a** (2026-10-08; every rule *(proposed)*; CHANGELOG.md, Archetypes, AR1a):
  - **The commit's two layers:** "plans stay the ability layer, strings the basic-attack layer" (D6). So a cast the commit's decision picks (AI1's damage and gap-closer uses) still goes first, until the string's first swing: a gap-closer gets it there and the string follows; a damage cast's end ends the commit, as in AI1. Once the string swings, nothing cuts into it (no cast) and its end ends the commit. An enemy with no string keeps AI1's commit.
  - **The mix** (Ryan, 2026-10-08, after AR1a's play test: "a mix of A and B", A the cast first, B the string first and the cast as its finisher): a commit with a damage cast ready rolls once, the first time that cast could go before its string. Under `string_then_cast_chance` (0.5 *(proposed)*) its string comes first and the cast its decision picks then follows as its finisher, with its token kept for it; the commit ends with the finisher's cast, or when none starts within `string_finisher_wait` (0.3 s *(proposed)*) of the string's end. Otherwise the cast goes first and ends the commit (AI1's). A gap-closer always goes first, and with no cast ready it's the string alone.
  - **R0's quirk, fixed** (2026-10-08; Ryan: "fix the quirk first then AR2"; DECISIONS.md, Archetypes): a commit starts its string only once the string's first swing is in reach (or the mix put the string first); until then it closes in on foot (`AutoAttackComponent.approach_for_string()`, the string's own chase). So a damage cast that comes into reach on the way still gets the mix (A: it goes, B: it waits as the finisher), and a string, once started, is never cut by a damage cast; a gap-closer still may (the target walked away again). Before, the string itself walked in and the cast cut it before its first swing (a string started for nothing, R0's recordings). Cutting nothing at all (the first try) took string enemies' damage casts away from range.
  - **A string that swings is committed** (found in AR1b): while it swings, the brain makes no new decision, so a poke scoring higher, a threat to defend from or low health takes nothing back. Only a stun, a poise break, its token or its target lost end it. (The test caster's poke at 0.6 against its commit's 0.65, with ±15% jitter, cut its volley before this.)
  - **Once it swings, a string runs to its end** (the commit can't be taken back): a dodge doesn't end it either, only a stun, a poise break, death or its target turning untargetable or dying. Each swing aims at the target where it stands at that swing's start, with the melee step and pull (up to its `lunge_max_px`). A stun or break breaks the commit off (patience kept, the token gone); its target gone ends it.
  - **Its timings are fixed reads:** attack speed doesn't change a string (its `AttackCombo.speed_scale` only), so the beat and the spacing hold, and the TEMP enemy attack speed multiplier (the sandbox's ×1.5) leaves strings alone.
  - **The beat comes from the table at run time** (`EnemyAITable.beat`): the first swing winds up for the beat and keeps its own recovery (`duration − windup`), so the spacing doesn't move with the beat. The test strings also author their first wind-up as 0.5 s, and the test checks the two match.
  - **Past its last swing, a hit repeats the last swing** (an elite's or a boss's extra hits), so the authored spacing must hold from the last swing to itself too (the test checks it).
  - **Its length range lives on the string:** its short end is `AttackCombo.string_hits_min` (a regular's length) and its full length is its swings' count (an elite's top). `RankRules.string_full_range` (elite, boss) and `string_extra_hits` (a boss's 1) pick the range, and the table's `string_short_hits` (2) is high respect's cut. The `Archetype` resource's string fields (AR3) become authoring targets the test checks the strings against, as `string_spacing` is.
  - **Its hits:** reach and arc × (1 − `enemy_hit_forgiveness`), as a League-style attack; no hit feel (the player's hits only); no `melee` tag (enemy `attack_tags` wait on ENEMIES_AI's proposal 9); at most the chip band per hit (5% of the Knight's health), so no floor telegraph is owed.
  - **A plan's STRING step** is never a plan's opener (it never fits). `plan_max_time` doesn't cut a running string; its token's hold is stretched to the string's end.
- **Mage volleys are the Mage's string** (D7): 3 bolts on one token, 0.45 s apart (Ryan: Open questions 3), the first with the 0.6 s tell, the later ones at the spacing (D7's "on the beat": Open questions 2). Assassins deflect only bolts marked deflectable: aimed, single-target bolts, never area orbs or beams. A deflected bolt is absorbed; reflecting it is a later reward (Later / not now). *(Built AR1b, 2026-10-08: Mage, The volley as built.)*
- **Basic has no string:** fodder keeps its League-style chip (COMBAT.md, the swarm chip band).

### Perilous attacks (MUST: D5; DECISIONS.md, Enemies, 2026-10-07)
- **An extra layer on top of an enemy's abilities**, for every archetype but Basic: an **elite** has one perilous move (cooldown 12–15 s), a **boss** 2–3 across its phases (cooldown 10 s), a **regular** none.
- **Damage:** 35–40% of the player's max health (the Knight's 650: 228–260; Korsavil's 500: 175–200). **No kill protection:** D5's "60% kill-protection rule" is dropped (Ryan, Open questions 1), so COMBAT's "no kill protection" (Ryan, 2026-10-05) stands.
- **Attacker-centered, always deflectable** (Ryan, Open questions 7): a perilous move is always deflectable, so its shape comes from the attacker's body (a cone, a slam around itself, its own dash), never an area placed at the player.
- **The icon:** over the model for 0.4 s from the start of the windup; the total windup is at least 0.9 s, so the hit lands about 0.5 s after the icon goes, on the beat. It's the one icon over a head (DECISIONS.md, 2026-10-07: icons for perilous attacks only; every other tell stays body language).
- **Pacing:** none in a fight's first 6 s; one live at a time across the whole enemy side (two with a boss).
- **The answers:**
  - An Assassin deflects it, and **deflecting a perilous attack counts as two deflects**: it goes straight to the riposte, and the attacker is rebuffed for 1.0 s.
  - Every other champion dodges it with the dash's i-frames. Only Assassins can deflect (D5, intended).
- A perilous hit is always a heavy hit (ENEMIES_AI, Odds: at least 10% of the target's max health), so the one-heavy-hit window holds while enemies press.
- *(proposed)* `Ability.perilous` marks one. The enemies test checks every perilous ability: deflectable and attacker-centered, its windup 0.9 s or more, its damage in the band, its cooldown, and each rank's count.
- **Found while building AR2** (2026-10-08; every rule *(proposed)*; CHANGELOG.md, Archetypes, AR2):
  - **Live** is from the cast's start (`Events.perilous_started`, which `AbilityComponent` emits for any unit) to its cast's end (the brain's `Brains.end_perilous()`, or Brains sees it no longer casts it). Every enemy's perilous cast counts, a brainless one's too; only brains are held back by the gate.
  - **A fight's start** is the first tick an enemy with data fights (aggroed, not passive, alive) after none did; the quiet time counts from there, and the fight ends once none fights.
  - **Where the brain checks the gate:** as it gathers a perilous use (before it asks the ability for a plan) and again before it casts one (its decision's, a plan's step). A plan's perilous step waits inside its window, as for a heavy hit.
  - **A perilous deflect from a fresh streak** still gives the refund (it's the first of its two), and the attacker takes the second deflect's poise damage (the prototype's numbers).
  - **Rebuffed needs no brain code:** `status_rebuffed_perilous` blocks attacking, so `Enemy.is_cc_blocked()` reads it as a stun: its string is cut, its commit breaks off, Brains takes its token.
  - **The two moves:** the slam and the finisher become SELF casts of the shockwave's script (its circle on its caster), keeping their radius (72 px, 80 px): 0.9 s, 240 damage (36.9% of the Knight's 650), cooldown 12 s. They keep their `cast_range` (250 u, 300 u): the naive loop's reach, about the circle's (the brain reads the circle itself). The slam's AI use is authored now (R0: it was the default one). `snare_first`'s finisher lands about 1.35 s after the snare, after the 1 s root, so it can be dashed; the plan takes 61.5% of the Knight's health (60 + 100 + 240).
  - **Not built:** the icon's sound sting (AUDIO's slot comes with its step). The icon is a Label on `ScreenOverlay` with the glyph (Windows falls back to a system font for it).

### Duel pressure (MUST: D8, D10; DECISIONS.md, Enemies, 2026-10-07)
- Respect and patience stay as they are. On top of them:
  - **each deflect of an enemy's hit raises that enemy's `aggression` by 0.1**, up to +0.3 (D8);
  - **while the player deals no damage for 4 s, enemies' patience fills ×1.25; after 8 s, ×1.5** (D8).
- A deflect doesn't end the enemy's string (D10).
- **The AI never reads the button press** (D10; ENEMIES_AI's fair knowledge). Only the two rules above are approved; extra respect for a ready deflect and treating the 1.5 s recharge as an opening are not (Later / not now).
- **How long and how much** (Ryan, Open questions 10):
  - the aggression bonus belongs to the enemy, against its current target, and lasts until its brain resets (a new target, the leash, the walk home);
  - the passivity multiplier stacks with patience's existing pressure (idle, low health, the odds: ENEMIES_AI, The standoff), since "did nothing" and "dealt no damage" are different reads;
  - **a ×2 cap overall:** patience's boosts together (its pressure, the passivity multiplier, and the aggression bonus's share of (0.5 + `aggression`)) never make it fill more than twice as fast as it would without them. Today's pressure alone tops out at exactly ×2 (1 + 0.5 idle + 0.5 for low health or the odds), so the cap changes nothing that exists, and duel pressure adds nothing once an enemy's pressure is full.
- *(proposed)* "Damage dealt" is a hit from that champion that got through (not blocked, not deflected); Brains keeps the last time per champion.

### Weak basic attacks (MUST: D12)
- **Every champion's unempowered basic attack deals 50% of today's damage,** tuned per champion in data: the TEMP lever becomes a per-champion stat. Empowered swings are unchanged, and so is the resource basic attacks give on landing (the Knight's 8 Fury a hit).
- **What empowers them is each archetype's layer:** the Assassin's riposte, jab and (Korsavil's) Vanish; the Skirmisher's Tempo; the Bruiser's Iron Resolve and Fury payoffs (the Knight); the Mage's marks.
- **Not enemies:** their basic attacks are their damage.
- **The check** (a rotation simulation in the tests): a player who only swings takes at least twice as long to kill an elite as one who uses the kit.

### Rank × archetype (MUST: D13)

| Rank | Archetypes |
|---|---|
| T0 fodder | Basic only, always |
| T1 regular | Bruiser, Skirmisher, Mage; Assassins rarely (at most 1 per room), from dungeon 3 on; no Duelists |
| T2 elite | all five; the Duelist is the showcase |
| T3 boss | all five: one archetype per boss, plus its perilous layer, plus scripted events that give it its extra layer |

- **Scripted boss events** (Ryan's addition, D13): data entries in `BossPlan` (timed or phase-triggered events), not a script per boss, consistent with ENEMIES_AI I10 ("data, not a script per boss"). Built with the boss director (ENEMIES_AI AI6). Data: `BossEvent` below.
  - **What an event may give** (Ryan, Open questions 13): another archetype's layer for a phase (a Bruiser boss with a Riposte Stance in its last phase); an arena change, telegraphed at least 1.0 s; adds, within the spawn budget (ENEMIES_AI's cap of about 20 moving enemies).
  - **Its limits:** one event runs at a time; none starts while a perilous attack is live; every event stays answerable (VISION.md's "no unanswerable enemy").
- References: Hades' elite variants, Sekiro's mini-bosses.

### Bosses and poise (MUST: D9)
- The boss poise hook (crowd control a boss refuses fills a boss meter; `RankRules.poise`, built off in AI-D3) **stays built and off**.
- A boss has a poise meter only if its archetype is Assassin (160).
- Every other boss is opened by its `BossPlan`'s existing windows (whiffs and the punish rules, the 1.5 s phase transitions) and keeps its 40% tenacity and diminishing returns. No new boss meter.

### Parked: tank and marksman (D14)
No archetype for now. A tank would be a Bruiser; a marksman a Skirmisher (kiting) or a Mage (spell shots). Revisit when all nine champions are designed, and only if the roster has a gap.

## The archetypes

### Assassin (locked: D3, D3b, D4, D7, D8, D11)
Deflect and poise are the Assassin's mechanic, for champions and enemies alike (DECISIONS.md, Combat, 2026-10-07). **Only Assassin units carry a poise meter** (D3).

#### The champion's layer (every Assassin; Korsavil first)
- **One dash, 25% longer** (D8, D11): 500 u (160 px) over the dash's 0.18 s; one charge; its i-frames as every dash. **It recharges in 1.2 s** (Ryan, Open questions 5; tuned between 0.8 and 1.5 s in AR5): well above the Knight's 0.35 s, which he keeps, or a whiffed dash would cost nothing.
- **The deflect window** (D8): 0.2 s from the dash's start, a timer of its own beside the i-frames. A deflectable hit from an enemy inside it is deflected: blocked whole (no damage, knockback, statuses, on-hit or post-hit i-frames), checked before the i-frames (as built).
- **What she can deflect:** a hit its data marks deflectable: every string hit (D6), every perilous attack (D5), aimed single-target bolts (D7), and the enemy abilities their author marks. **The author decides by origin** (Ryan, Open questions 7):
  - **deflectable:** a shape centered on the attacker's body: a melee cone, a slam around itself, its own dash through her, an aimed bolt;
  - **never deflectable:** an area placed at her position: an orb, a pool, a beam;
  - so the elite slime's slam and the test duelist's finisher (circles placed at the target today) are retuned to attacker-centered shapes (AR2), and the enemies test checks every deflectable or perilous enemy ability's origin.
- **The refund** (as built, D8): the first deflect of a streak gives the dash charge back for 3 s; any dash spends it; unused, it's taken back and the normal recharge runs.
- **The streak:** +1 for each deflect.
  - **The jab** (D8, new): after one deflect, the next basic attack swing that hits gets +1.0 AD ratio, and the jab ends the streak. Waiting for the second deflect gives the full riposte instead (a second deflect replaces the jab with the riposte). The jab's swing snaps toward the attacker up to 1.5 m, half the riposte's, so it doesn't whiff after a long dash (Ryan, Open questions 17; tuned in AR5).
  - **The riposte** (D7, D8): the second deflect, or one deflect of a perilous attack, gives the riposte. The next swing that hits gets +3.0 AD ratio plus 12% of the target's max health (4% on a boss). It snaps toward the attacker up to 3 m, or 6 m when the deflect was of a projectile (casters stand 5.5–8 m away); past that it stays banked until she closes in. It banks until a swing lands.
  - **The streak ends** once the riposte is given, or when a swing uses the jab (the one line the jab adds to the streak rule).
  - **Banking stays** (`streak_persists`, Ryan's follow-up; Ryan, Open questions 4): no chain window, and a plain dash keeps the streak. **But it expires 10 s after the last deflect, and it clears when she leaves the room**, so an old streak can't surprise her later. *(Claude's reading)* The jab or riposte it banked goes with it. Nothing signals leaving a room yet (Current code): the clear hooks into DUNGEONS' traversal between spaces when that's built; until then, the 10 s expiry.
  - *(proposed)* A swing that's deflected or rebuffed doesn't land, so it keeps the jab or the riposte (a swing that hits nothing keeps its empowers: ABILITIES.md, Empowers).
- **Energy** (Korsavil; D11): a deflect costs no Energy; a successful one gives +10; the cost of a whiff is the recharge.
- **Her poise meter** (D3b; Sekiro's player posture, which deflecting recovers): 0–100, filled by:
  - a hit she takes: by the hit's share of her max health (an 8% hit adds 8); a heavy hit (ENEMIES_AI's: 10% of max health or more) ×1.5 (Ryan, Open questions 9);
  - a perilous hit that lands: a flat 40, in place of the share rule (Ryan, Open questions 9);
  - being rebuffed by an enemy Assassin's deflect: 25;
  - **her own successful deflect drains 15.**
  - **Decay:** 15 a second after 3 s with no poise hit, ×0.5 below 40% health (D1).
  - **Her break** at 100: 1.0 s (not the enemies' 1.8 s), ×1.25 damage taken, then 4 s immune (D3b). It blocks moving, attacking, casting and dashing, as the prototype's status does.
- **Her kit keeps** Blades and Inevitable Demise in her passive, and Q's damage reduction and move speed (D11). **The deflect-dash isn't her passive's but the archetype's** (D11), so her passive's +1 `dash_charges` goes.
- What it adds up to *(examples, the numbers above)*: Korsavil's riposte on a swing 1 (0.9 AD) at 60 AD is 234 plus 12% of the target's max health. The Knight's on the test duelist (2800 health, 30 armor) would be 256 + 336 = 592 before armor, 455 taken (16% of its health; as built 197, 7%). Her jab on swing 1: 1.9 AD (114), against 27 for an unempowered swing at 50%.

#### The enemy's layer
- **A poise meter sized by rank** (D8): regular 60, elite 100, boss 160. It fills from:
  - the poise damage riding the party's hits (`poise_damage` on swings and abilities). **Any champion's hits can carry it** (Ryan, Open questions 6), so a non-Assassin can break an enemy Assassin and nothing is unanswerable; only the meter is Assassin-only. The Knight's chips (4 a swing, Cleave 20, Judgement 40) stay, tuned in AR6;
  - the player's deflects (D3b): 25 the first, 50 the second, 40 on the riposte's hit.
  - **Decay** as Korsavil's: 15 a second after 3 s, ×0.5 below 40% health (D1).
  - **Its break** at full (D8): 1.5 s for a regular, 1.8 s for an elite, 1.4 s for a boss, at ×1.5 damage taken, then 4 s immune. It cuts a cast or a windup, ends its string and lets its token go (D6).
  - *(proposed reading)* Its own successful deflect drains 15 from its meter, "the same loop" as hers (D3b).
  - Worked: an elite (100) breaks on a deflect pair (75) plus the riposte's 40; a regular (60) on the second deflect (75); a boss (160) needs the pair, the riposte and 45 more.
- **The Riposte Stance** (D4): an ability, not a dash. It opens the enemy's deflect window for 0.5 s; cooldown 6 s; a readable pose (the blade across the body, plus a glint); a 0.6 s recovery if it deflects nothing.
  - **Why a stance:** the brain's 0.3–0.45 s reaction can't answer a 0.15 s swing, so the stance is committed ahead. The player gets past it by baiting it out and punishing its cooldown.
  - **What it deflects** (D4): the player's melee basic attacks and single-target melee abilities. Never projectiles, area hits, damage over time or ultimates.
    - *(proposed)* As data: every melee combo swing is deflectable (`AttackSwing.deflectable`, true by default), and a champion's ability is deflectable only when marked (`Ability.deflectable`), which the champions test allows only on an ability tagged `melee` and none of `area`, `cone`, `line`, `projectile`, `dot`, `ultimate`.
    - Today that's the Knight's swings and dash-strike, and none of his abilities (Cleave is an area, Lunge a dash through a line, Judgement an ultimate); Korsavil's swings, and none of her abilities.
  - **One hit per stance** (Ryan, Open questions 11): it ends at its first deflect, so a string can't be unbeatable, and its riposte comes at once.
  - **Its AI** (D4): it's used when the player closes in: a gap-closer just used, or inside 3 m. *(proposed)* An `AIUse` with the intent `defend`: one use with `TARGET_DISTANCE` under 300 u, one with the gap-closer read (Brains' last gap-closer, AI-D1); each seen after its reaction time, like any read; no token.
- **Rebuffing the player** (D4): when an enemy Assassin deflects a champion's attack, the champion is **rebuffed**: that swing is cancelled, attacking is locked for 0.4 s, the combo goes back to swing 1, and the champion takes no damage. The enemy gets its **riposte**: its next hit ×2, for 1 s.
  - **The enemy's riposte** (Ryan, Open questions 16) is its own `empower_riposte`: +1.0 AD ratio on its next basic attack hit only, lasting 1 s. **It never applies to a perilous hit** (that would reach 70–80% of max health): a perilous attack is an ability, and the riposte is a basic attack empower. *(proposed)* It swings at once: its string's first swing with the 0.25 s follow-up wind-up, deflectable, so Korsavil can turn it around.
  - A rebuffed Korsavil's meter takes 25 (D3b).
- **Its dashes stay abilities** (D4): enemy dashes are dash abilities in data, through `MovementComponent.dash()`. A **slip** (a short dash ability) may open the same deflect window for 0.2 s. No enemy DashComponent.
- **Its string:** 3–4 fast hits, 0.4 s apart (approved; D8).
- **Ranks:** elites and bosses; regulars rarely (at most 1 per room), from dungeon 3 on (D13).

#### Rebuffed (D4, D5; the blocks: Ryan, Open questions 8)
- `status_rebuffed` (tags `rebuffed`, `debuff`): blocks attacking; 0.4 s on a champion (D4). Applied with the swing's cancel (`cancel_swing()`, the combo reset).
- `status_rebuffed_perilous` (tags `rebuffed`, `debuff`): blocks attacking, casting and dashing; 1.0 s on an enemy whose perilous attack was deflected (D5). It cuts the enemy's cast, ends its string and lets its token go.
- Neither is tagged `cc`, so tenacity, diminishing returns and cleanses don't touch them (as `poise_broken`). Not "staggered": that's the Knight's Lunge mark (CHAMPIONS.md, Status: Staggered).

#### The test enemy Assassin *(proposed; the advisor's note; AR3)*
- **Why:** under D3 and D11, once the Knight's test version goes (AR6), nothing in the game has a meter Korsavil can break. It comes first.
- `enemy_test_assassin.tres` (and `data/units/test_assassin.tres`, `scenes/enemies/test_assassin.tscn`): rank ELITE, archetype Assassin (a new preset, `enemy_behavior_assassin.tres`: a skirmisher's band and dive with the stance's use), poise 100 (the elite's), a capsule in a dark violet `model_color`.
- **Its string:** 3–4 fast hits at 0.4 s spacing.
- **Its kit** (an elite's 3–5): Q the Riposte Stance; E a gap-closer (the library's flurry *(proposed)*); R its perilous move (the library's charge, marked perilous, about 37% of the Knight's health *(proposed)*); W a slip if the step has room, else later.
- **Stats** *(proposed)*: between the elite slime's 900 and the duelist's 2800 health: 1400 health, 20 armor, 40 AD, 380 move speed, 150 u range.

#### The Knight's test version (D3, D11)
- The Knight is a Bruiser: **in the end he has no deflect and no poise.**
- Until then he stays the prototype's test bed. His deflect goes only after Korsavil's Assassin layer (AR5) is built and Ryan passes it, with his OK and in the same chain of commits (AR6). It's **disabled, not deleted**.
- The non-Assassin poise values go with it: the elite slime's `poise_max` 100 (it's a Bruiser) and the test duelist's (a Duelist). The Knight's chips (4, 20, 40) stay and get tuned then (Ryan, Open questions 6).

### Skirmisher (placeholder: D2)
- **An enemy's window:** the hop-out reset (about 1 s: AI3's reset hop); a root or a pin breaks it. **Its string:** 2–3 fast hits at 0.35 s, then the reset.
- *(proposed, placeholder)* **A champion's layer: Tempo**, up to 3 stacks. A basic attack cancelled by a step on the beat (±0.1 s), or a graze through an attack (a 0.25 s window, no riposte), adds one; 3 stacks empower the next ability. (Hi-Fi Rush; Bayonetta's Witch Time.)

### Mage (placeholder: D2, D7)
- **An enemy's window:** *(proposed, placeholder)* its volley is a visible channel; crowd control (never damage) interrupts it into a 1.2 s **backlash**. **Its string:** the 3-bolt volley (Strings).
- *(proposed, placeholder)* **A champion's layer:** charge and release; a release in the last 0.15 s gives +25% (Gears of War's active reload). Its marks empower its basic attacks (D12).
- **The volley as built** (AR1b, 2026-10-08; each rule *(proposed)* unless D7 says it):
  - **It's a RANGED string** (`combo_test_caster.tres`): 3 swings, its short end 3 (D7: a 3-bolt volley; a boss's up to 4, and one more at low respect, as every string). Each release (the swing's hit moment) fires one bolt (`Projectile.fire_swing()`), aimed at its target where it stands then (no lead: the player sidesteps it). The first release comes on the beat after the commit's tell; the next two follow 0.45 s apart (D7).
  - **A bolt:** 750 u/s, 950 u from the Mage's center, 30 u wide (a narrow, aimed, single-target bolt; the poke bolt is 50 u). It stops at walls and on the first unit it meets. It's a basic attack hit (1.5 AD; the test casters' 14 AD makes 21, 3% of the Knight's health), physical, tagged `projectile`, with no hit feel and no push. Deflectable (D7: an aimed single-target bolt); a deflected bolt is absorbed (D7). With its Mage freed in flight, it still hits for the damage at fire, with no source and no crit, as an ability's projectile does.
  - **It's fired from where the Mage stands:** a volley walks in only until its target is within its bolts' range (less `enemy_hit_forgiveness`) and in sight, never into melee. From its band's far edge (800 u) it's already in range. A wall between them in range: it waits.
  - **The Mage commits into it:** the caster preset's commit weight goes from 0 (AI3: "a caster never commits") to 1, since D7 makes the volley the Mage's string and a string is a commit. It needs its token (a regular 1, an elite 2), held for the volley. A caster-role enemy that commits needs a ranged string (the enemies test checks), or its commit would walk it into melee.
  - Not yet: the backlash (the placeholder window above) and reflecting a deflected bolt (Later / not now). The riposte's 6 m projectile snap is AR5.

### Bruiser (placeholder: D2)
- **An enemy's window:** *(proposed, placeholder)* a heavy hit's recovery of 1.0–1.4 s, opened by dodging it, not by deflecting it. **Its string:** 2–3 heavy hits at 0.9 s.
- *(proposed, placeholder)* **A champion's layer: Brace:** while holding block it takes −50% and banks half the blocked damage, up to 20% of max health, released as a slam.
- **The Knight is a Bruiser.** Iron Resolve and his Fury payoffs are what empower his basic attacks (D12). Brace isn't in his kit, and nothing in his kit changes for it now.

### Duelist (placeholder: D2)
- **An enemy's window:** *(proposed)* the recovery after its string's last hit and after its finisher (the test duelist's 1.2 s `recovery_time`): the longest string earns the longest opening. **Its string:** 4–5 hits at 0.5 s, the most pressure.
- *(proposed, placeholder)* **A champion's layer:** a counter stance ability (0.4 s) that answers one melee hit with a 1.5× AD strike: damage instead of poise (Fiora's Riposte).
- **The test duelist is a Duelist** (D3): no meter in the end (AR6).

### Basic (fodder)
Fodder only, always (D13). No string, no perilous attack, no meter: its League-style chip stays (COMBAT.md, the swarm chip band).

## Data (Resources) *(proposed unless marked built)*

### Archetype (`res://scripts/data/archetype.gd`; `res://data/archetypes/archetype_<id>.tres`)
One per archetype: what every unit of it shares, so the layer isn't copied into each champion's or enemy's data (D11: the deflect-dash belongs to the archetype, not a passive). Looked up by id (`Archetype.of(id)`): a champion's id is its `ChampionData.champion_class`, renamed `archetype` in AR8 with the old name kept as an alias (Ryan, Open questions 14); an enemy's comes from its behavior's role (`basic` for fodder).

| Field | Type | Assassin | Notes |
|---|---|---|---|
| `id`, `display_name` | `StringName`, `String` | `&"assassin"`, "Assassin" | `assassin`, `mage`, `skirmisher`, `bruiser`, `duelist`, `basic` |
| `string_hits_min`, `string_hits_max` | `int` | 3, 4 | the approved shape: regulars the minimum, elites the range, bosses the maximum + 1 |
| `string_spacing` | `float` | 0.4 | the authoring target: the enemies test checks every string's hit-to-hit times against it (±0.05 s) |
| `deflects` | `bool` | true | a unit of this archetype has a running deflect window (its DeflectComponent): in place of the prototype's flag |
| `dash_distance_scale` | `float` | 1.25 | champions: × the dash's `dash_distance` (400 u → 500 u) |
| `dash_recharge_time` | `float` | 1.2 | champions: the dash's `charge_recharge_time` (−1 = the dash's own: the Knight's 0.35 s); tuned 0.8–1.5 in AR5 (Ryan) |
| `deflect_window` | `float` | 0.2 | a dash's window |
| `poise_meter` | `bool` | true | a unit of this archetype has a running poise meter |
| `poise_rules` | `PoiseRules` | `poise_rules_assassin.tres` | |
| `layer` | `ToolkitBundle` | null | anything else the archetype gives a champion at load, under `&"archetype_<id>"` (a placeholder layer later) |

### PoiseRules (`res://scripts/data/poise_rules.gd`; `res://data/poise_rules/poise_rules_<name>.tres`)
Mirrors `CrowdControlRules`: the meter's numbers in one file. `decay_delay` 3, `decay_rate` 15, `low_health` 0.4, `low_health_decay_scale` 0.5, `break_damage_bonus` 0.5, `break_immunity` 4. Champions: `champion_max` 100, `champion_break_time` 1.0, `champion_break_damage_bonus` 0.25, `hit_fill_scale` 100 (a hit's share of max health × it), `heavy_hit_scale` 1.5, `perilous_fill` 40, `rebuffed_fill` 25, `own_deflect_drain` 15. The deflect's poise damage to the attacker (25, 50, 40) stays on `DeflectComponent` (built).

### On existing data

| Where | Addition | Default | Notes |
|---|---|---|---|
| `ChampionData` | `archetype: StringName` | | AR8: `champion_class` renamed, the old name kept as an alias (Ryan, Open questions 14) |
| `EnemyData` | `attack_string: AttackCombo` | null | its string; null = no string (fodder; an enemy not yet given one keeps today's commit). *Built AR1a* |
| `AttackCombo` | `string_hits_min: int` (group "String (enemies)") | 0 | *(proposed; built AR1a)* a string's short end (a regular's length); 0 = its swings' count; its full length is its swings' count. `get_string_hits_min()` |
| `EnemyData` | `thinks_like_boss: bool` | false | **D15:** `duelist` renamed; `duelist` stays readable as an alias until the tests pass, then goes with Ryan's OK |
| `EnemyData` | `poise_max` (built, prototype) | 0 → −1 | from AR3: −1 = its rank's (`RankRules.poise_meter_max`) when its archetype has a meter; 0 = none; above 0 = that size |
| `EnemyBehavior.Role` | `DUELIST`, `ASSASSIN` appended | | stored as 3 and 4, so the presets' 0–2 keep their meaning; the rename pass (AR8) makes `BRUTE` `BRUISER` and `CASTER` `MAGE` |
| presets | `enemy_behavior_assassin.tres` (AR3), `enemy_behavior_duelist.tres` (AR8) | | the test duelist moves to the Duelist preset in AR8 |
| `RankRules` | `perilous_max: int` | 0 | fodder 0, regular 0, elite 1, boss 3; the enemies test checks every EnemyData |
| `RankRules` | `poise_meter_max`, `poise_break_time` | 0 | 0 / 60 / 100 / 160 and 0 / 1.5 / 1.8 / 1.4; read only for an archetype with `poise_meter`. Not the hook `RankRules.poise` (built, off: D9) |
| `RankRules` | `string_extra_hits: int` | 0 | a boss 1 (D8). *Built AR1a* |
| `RankRules` | `string_full_range: bool` | false | *(proposed; built AR1a)* elite and boss true: a string's full range, and one more hit at low respect at its `aggression`'s chance; false (fodder, regular): its short end |
| `EnemyAITable` | *(the mix: Ryan, 2026-10-08; built)* `string_then_cast_chance` 0.5, `string_finisher_wait` 0.3 *(proposed numbers)*; `beat` 0.5; `string_respect_short` 0.6, `string_respect_full` 0.3 (*built AR1a*, with *(proposed)* `string_short_hits` 2: high respect's cut); `perilous_quiet_time` 6, `perilous_live_max` 1, `perilous_live_max_boss` 2; `duel_aggression_step` 0.1, `duel_aggression_cap` 0.3; `duel_passive_times` [4, 8], `duel_passive_mults` [1.25, 1.5]; `patience_boost_cap` 2.0; `riposte_stance_range` 300 | | live in the N panel like the table's other numbers |
| `ComboStep` | `kind: ComboStep.Kind` (`ABILITY`, `STRING`) | `ABILITY` | a string as a plan's step (D6); a `STRING` step ignores `slot` and is never the opener. *Built AR1a* |
| `BossPlan`, `BossPhase` | `events: Array[BossEvent]` | `[]` | scripted boss events (D13; AI6) |
| `BossEvent` (inline) | `trigger` (`PHASE_START`, `TIME`, `HEALTH_BELOW`), `time`, `health_below`, `once: bool`; what it gives: `ability: Ability` (cast with its telegraph, as its own move), `bundle: ToolkitBundle` (another archetype's layer for the rest of the phase: a status, a form, a granted ability), `arena_change` (a world state or hazard, telegraphed at least 1.0 s: `arena_telegraph_time`), `adds: Array[PackedScene]` (spawn-in, within the spawn budget) | | data, not a script per boss (ENEMIES_AI I10). The director runs one event at a time and starts none while a perilous attack is live (Ryan, Open questions 13) |
| `Ability` | `perilous: bool` | false | a perilous attack (D5): the icon, the counts, the rebuff on a deflect |
| `Ability` | `deflectable`, `poise_damage` (built, prototype) | false, 0 | the authoring rule per side: an enemy's by origin (attacker-centered, never placed at the player: Assassin, What she can deflect); a champion's only melee single-target (What it deflects) |
| `AttackSwing` | `deflectable: bool` | true | every swing of a string, and every melee combo swing (D4, D6); a ranged champion's combo sets it false (D4: never projectiles); a Mage volley's bolt true when it's aimed and single-target (D7). *Built AR1a* (into every swing's hit; only a deflect window reads it) |
| `AttackSwing` | `poise_damage` (built, prototype) | 0 | |
| `AttackSwing` | group "Ranged": `projectile_speed` 750, `projectile_range` 950, `projectile_width` 30 (LoL units), `projectile_color` | | *(proposed; built AR1b)* a RANGED string's shot, read only by an enemy's RANGED string (a champion's ranged basic attack is designed later) |
| `Projectile` | `fire_swing(caster, swing, origin, direction)`; `swing`, `tint` | | *(proposed; built AR1b)* a swing's shot: a basic attack hit, tagged `projectile`, deflectable by its swing's mark |
| `StatusEffect` | `empower_target_health_ratio: float` | 0 | an empower's share of the target's max health, into the hit's base damage (the riposte's 0.12); `empower_boss_health_ratio` (−1 = the same) for a boss's 0.04 |
| `StatusEffect` | `empower_poise_damage` (built, prototype) | 0 | |
| stat registry | `unempowered_attack_damage` | 1.0 | D12: × the damage of a basic attack swing that carries no empower; every champion's UnitStats sets it (0.5 to start); enemies keep 1.0. Replaces the TEMP lever |
| statuses | `status_rebuffed.tres`, `status_rebuffed_perilous.tres`; runtime `empower_jab` | | Rebuffed; the jab (+1.0 AD ratio, used up by the next swing that hits) |
| `PoseSet` | poses `riposte_stance`, `rebuffed` (and `slip` with the slip) | | View |
| Events | `perilous_started(unit, ability)` | | the icon, a sound, tests; the rest ride the built deflect and poise events and `status_applied` |

### Test and sandbox data
- `enemy_test_assassin.tres`, `data/units/test_assassin.tres`, `scenes/enemies/test_assassin.tscn`, its abilities `test_assassin_<slot>_<name>.tres` (AR3). In SandboxBrains' Shift+H list.
- Strings for the test enemies (AR1): `combo_test_brute.tres` (Bruiser: 2–3 heavy hits at 0.9 s), `combo_test_skirmisher.tres` (2–3 at 0.35 s), `combo_test_caster.tres` (the volley at 0.45 s, a RANGED combo), `combo_test_duelist.tres` (4–5 at 0.5 s); the elite slime keeps its slam and gets the Bruiser's.
- `SandboxDeflect`'s panel gets the jab, the riposte's health share and its projectile snap (AR5), the meter's direction and decay (AR3), and the duel pressure rows (AR7).

### Names checked against CONVENTIONS.md (Ryan accepted every proposal, 2026-10-07: Open questions 14)
| Name | Check | Proposal |
|---|---|---|
| **archetype** | CONVENTIONS calls a champion's class its "archetype" (`champion_class`: bruiser, diver, rogue, assassin, tank, marksman, mage) | the shared word for champions and enemies (decided 2026-10-07); `champion_class` holds the archetype id and is renamed `archetype` in AR8, the old name kept as an alias (Ryan); an enemy's **role** becomes its archetype |
| **Basic** | "basic attack" is a design term | always "the Basic archetype" or "Basic (fodder's archetype)", never "a basic" |
| **string** | free in design text; `String` is GDScript's type | code says `attack_string`, never a bare `string` identifier |
| **the beat** | ENEMIES_AI's `mixup` uses "a held beat" (0.4–0.8 s), and the brain overlay prints "beat 0.5 s" | keep "the beat" for the timing; call mixup's "a held pause" in the docs and the overlay (the rename pass): Open questions 14 |
| **perilous attack**, `perilous` | free | Sekiro's word |
| **rebuffed**, `status_rebuffed` | free; "staggered" is the Knight's | as above |
| **Riposte Stance** | ALLIES' vocabulary has **stance** (the ally's aggressive / balanced / support) | an ability's display name only, like Iron Resolve; the general term is a **deflect ability** (the Riposte Stance, a slip) |
| **riposte**, `empower_riposte` | built in the prototype, not yet in CONVENTIONS | the payoff of a deflect pair, for champions and enemies |
| **jab**, `empower_jab` | free | the payoff of a single deflect |
| **streak**, **refund** | built in the prototype | |
| **deflect**, **deflect window**, **deflectable** | built; MOVEMENT's Target feel says other units are "never steered/deflected" (pushed aside) | MOVEMENT's line becomes "never steered or pushed aside" |
| **poise**, **poise meter**, **break** | AI-D3's vocabulary has **poise** for the boss hook (`RankRules.poise`, `StatusComponent.poise`, the reason `POISE`) | **poise** means the Assassin's meter; the hook keeps its code names and is "the poise hook (off)" in text |
| **duel pressure** | "pressure" is a boss's phase and patience's push (`idle_pressure`); "press" is the odds' | always "duel pressure" in full |
| **window** (an archetype's) | "the window" is diminishing returns' (AI-D3), "punish window" a boss's | always qualified: "the Assassin's window", "a deflect window", "the backlash" |
| **Tempo** (Skirmisher, placeholder) | a boss's **tempo** (pressure and breather) | rename when the layer is designed |
| **counter stance** (Duelist, placeholder) | ALLIES' **stance** | rename when the layer is designed |
| **slip**, **backlash**, **Brace**, **volley** | free | |
| `thinks_like_boss` | free | Ryan's (D15) |
| **weak basic attacks**, `unempowered_attack_damage` | Ryan's "autos"; CONVENTIONS says "basic attack" | the rule's name in text; the stat's name |

## Architecture / contracts *(proposed; each step reads the code first)*
- **`DeflectComponent`** (built; extended):
  - `is_active()` reads the unit's archetype (`deflects`) instead of the static flag. The flag stays for the Knight's test version until AR6, then turns it off for him; the code isn't deleted (D11).
  - `open_window(duration := -1.0)`: a dash passes the archetype's 0.2 s; the Riposte Stance 0.5 s; a slip 0.2 s.
  - The jab (`empower_jab`, +1.0 AD ratio, banked; its snap `jab_snap_range` 150 u), the riposte's health share (the new empower field), the 6 m projectile snap (`riposte_projectile_snap_range` 600 u; a deflected projectile is absorbed), +10 resource on a deflect (`resource_on_deflect`), a perilous deflect counting as two.
  - Banking keeps `streak_persists` (no dash ends the streak) but gains `streak_expiry` (10 s after the last deflect: the streak and its banked jab or riposte end), and a clear on a room change once one exists (DUNGEONS).
  - **On an enemy** (a deflect ability opens it): a deflected champion's swing is cancelled (`AutoAttackComponent.cancel_swing()`, the combo reset), the champion gets `status_rebuffed` (0.4 s), and the enemy gets its own riposte (+1.0 AD ratio, 1 s). The champion's own meter takes `rebuffed_fill`.
  - The deflecting unit's own meter drains `own_deflect_drain`.
- **`PoiseComponent`** (built; extended):
  - **Fills to a break** (D1): it starts at 0, poise damage raises it, it breaks at `poise_max`, then it's empty and immune for 4 s. Decay replaces regen, with the low-health scale.
  - `is_active()` reads the archetype (`poise_meter`); `poise_max` and the break time come from the rank (enemies) or the rules (champions).
  - **On a champion:** it listens to the champion's own `damaged` signal for the share rule, the heavy and perilous rules, and to its deflects and rebuffs.
  - Its node goes on `player.tscn` too (it does nothing for an archetype without the meter).
- **`DashComponent`:** the archetype's `dash_distance_scale` and `dash_recharge_time` (1.2 s) at load; the refund as built; the Knight keeps his 0.35 s.
- **`AutoAttackComponent`:**
  - **Strings:** an enemy's string runs on combo mode's swing code (the windup, the melee step and assist, `AttackSwing` timings), switched on for the string only through `run_string(target)`, so League-style attacks stay for everything else (holds, cornered slaps, fodder). A RANGED string fires a projectile per swing (built here: `AttackStyle.RANGED` is data only today).
  - `AttackSwing.deflectable` into the hit.
  - The TEMP lever becomes the stat `unempowered_attack_damage` (D12; the lever and its sandbox row go with Ryan's OK).
- **`EnemyBrain`:**
  - A commit with no plan runs its string (`attack_string`), keeping its token to the last hit's recovery; respect sets the length; a deflect doesn't end it.
  - A plan's `STRING` step runs the string as a step.
  - The Riposte Stance through its `defend` uses.
  - The perilous gate (below).
  - Duel pressure: the aggression bonus on its resolved sliders (cleared on reset) and the passivity multiplier in its patience fill (`get_patience_rate()`), the boosts together capped at `patience_boost_cap` (×2).
  - Plus the overlay's lines: the string, its next hit, the meter, the duel pressure.
- **`Brains`:**
  - `can_start_perilous(unit)`: false in a fight's first 6 s or with one already live (two with a boss); `note_perilous()` / `end_perilous()`.
  - `get_time_since_damage_dealt(champion)`, kept from `Events.unit_damaged`.
- **`BossDirector`** (ENEMIES_AI AI6): runs `BossEvent`s one at a time, never while a perilous attack is live (`Brains`' gate), with an arena change's telegraph of at least 1.0 s and adds through spawn-in under the spawn budget.
- **`HitPipeline` / `Unit.on_hit()`:** the deflect hook stays first (built); `ctx.perilous` from the ability; the champion's meter fill after the damage.
- **Loading:** `Player._apply_champion()` and `Enemy._apply_enemy_data()` look up the archetype, set the dash, the deflect and the meter, and attach its `layer` under `&"archetype_<id>"`.
- **Events:** `perilous_started` (new); the built `hit_deflected`, `deflect_streak_changed`, `riposte_ready`, `poise_changed` and `poise_broken` serve every unit.

## View
The view never changes gameplay state (3D.md). Every look below is a placeholder until the art pass, on hooks that exist (`PoseSet`, `ScreenOverlay`, `VFX`, `UnitView`).
- **The perilous icon:** a red glyph over the model's head for 0.4 s from the windup's start (Sekiro's 危 as a placeholder), drawn by `ScreenOverlay` at the head's screen point, driven by `Events.perilous_started`, with a sound sting (AUDIO hook). It's the only icon over a head in the game (DECISIONS.md, Enemies, 2026-10-07).
- **The Riposte Stance pose** (`riposte_stance`): the blade across the body (a clip later; the capsule: lean back 5°, squash 0.95, a steel-blue rim) and a glint at its start (a white flash VFX, `glint_vfx` on the ability), held for the 0.5 s window; then `recover` (built in AI-D1) through a whiff's 0.6 s.
- **The rebuffed pose** (`rebuffed`): thrown back (lean back 20°, stretch 1.05, a white rim flash) for the status's time; on a champion, a recoil clip hook on `UnitView` (empty until art).
- **Korsavil's meter on the HUD:** a thin bar under her health bar (functional, as CH6's HUD): gold filling toward the break, orange draining while broken, grey while immune. UI.md polishes it.
- **Enemy Assassins' meters:** a thin bar under their health bar (`ScreenOverlay`), as `SandboxDeflect`'s readout draws today; only on units with a meter; on a boss, its bar.
- **Strings:** each swing's wind-up shows (the capsule's windup squash per swing; clips later), so the beat is visible as body language.
- **Built:** the deflect's feel (a 0.08 s hitstop, a 1.5 shake, the attacker's flash), the riposte ring, the poise break's stun stars.
- **`debug_draw`:** the deflect window as a ring at the feet (`DeflectComponent`), the next string hit's time in the brain overlay.

## Build order (proposed; one step per request; each ends with Ryan's play test)
Every step: Ryan runs `git status` first; with the Knight picked the game plays as before unless the step says otherwise (his abilities, talents, enemies chasing, the HUD); an enemy with no string or archetype data plays exactly as before; every suite green (the counts in CHANGELOG.md); this doc keeps one line per built step. Step ids AR1–AR8 and AR-M (free: no doc uses "AR").

**Changed from the suggested order:** the weak basic attacks stat moves up from last to AR4, before Korsavil's Assassin layer. The TEMP lever weakens only the Knight's swings (`_is_prototype_weak_auto()` checks for the Knight), so without the stat, Korsavil's jab and riposte would be play tested against her full-strength swings. The rest keeps the suggested order.

1. **AR1 – Strings, the beat and token holding.** `EnemyData.attack_string`, combo mode driven by the brain (`run_string()`), RANGED strings (the volley), `AttackSwing.deflectable`, the test enemies' strings, a commit that runs its string (respect sets its length, a deflect doesn't end it), the token held to the last hit's recovery, `ComboStep.Kind.STRING`, the table's numbers, the enemies test's spacing and beat checks.
   **Done means:** each test enemy commits into its string at its archetype's rhythm (the brute's two heavy hits, the skirmisher's quick two and its hop, the caster's three bolts); a string's first hit lands 0.5 s after its wind-up and reads for at least 0.6 s; with the Knight's test deflect on (V), a deflect pair fits inside one string and the riposte lands at about 1.0 s; a string is 2 hits against a full kit and longer against a spent one; two regulars or one elite at a time, as before. **Tests:** spacing per archetype (±0.05 s); the beat; respect's lengths; the token held to the end and freed on a stun, a break, a death; a deflect not ending the string; a plan's string step.
   **Split in two (Ryan, 2026-10-08):** **AR1a**, the melee strings (everything above but the caster's bolts: `run_string()`, the test brute's, skirmisher's and duelist's strings and the elite slime's Bruiser one, the commit, the token, respect, `ComboStep.Kind.STRING`), then **AR1b**, the Mage volley (RANGED strings: a projectile per swing, the test casters' 3 bolts at 0.45 s, aimed single-target bolts deflectable).
   - **AR1a built 2026-10-08, passed the same day** (Ryan's play test), see CHANGELOG.md; the rules found while building it are under Strings and the beat. Its follow-up, the mix (Ryan, 2026-10-08), built with AR1b.
   - **AR1b built 2026-10-08** (awaiting Ryan's play test), see CHANGELOG.md; the volley as built is under Mage, the rule it found (a swinging string makes no new decision) under Strings and the beat.
2. **AR2 – Perilous attacks and their icon.** `Ability.perilous`, `RankRules.perilous_max`, the Brains gate (first 6 s, one live, two with a boss), `Events.perilous_started`, the icon on `ScreenOverlay`, `status_rebuffed_perilous`, a perilous deflect counting as two (the Knight's test deflect: straight to the riposte, the attacker rebuffed 1.0 s), the elites' first perilous moves: the test duelist's finisher and the elite slime's slam, **retuned to attacker-centered shapes** (a circle around its own body, as the shockwave's; Ryan, Open questions 7), at 0.9 s and 35–40%; the enemies test's origin check. **The duelist's `snare_first` plan is retuned with it:** its finisher at a 0.9 s windup lands after the 1 s root ends (today about t = 0.8, inside it), and at 35–40% the whole plan would take about 60–65% of the Knight's health (today 55%).
   **Done means:** the icon shows 0.4 s at the windup's start and the hit comes about 0.5 s after it; both slams now land around the attacker, not where you stood; never two at once from regulars and elites, never in the first 6 s; the Knight dashes through it; with the test deflect on, one deflect gives the riposte and the attacker stands rebuffed for 1.0 s. **Tests:** the gate; the counts per rank; the windup floor; the damage band; every deflectable or perilous enemy ability attacker-centered; the double deflect; the rebuffed status not counted as crowd control.
   - **AR2 built 2026-10-08** (awaiting Ryan's play test), see CHANGELOG.md; the rules found while building it are under Perilous attacks. Built with it (Ryan: "fix the quirk first then AR2"): R0's quirk fixed (Strings and the beat).
3. **AR3 – The test enemy Assassin.** The meter flipped to fill up to a break (D1) with decay and its low-health scale, `PoiseRules`, the rank sizes and break times, the `Archetype` resource (Assassin first; its `poise_meter` and `deflects` read in place of the flags for enemies); the Riposte Stance (a deflect ability: `open_window(0.5)`, its pose and glint, the whiff recovery), rebuffing the champion (`status_rebuffed`, the enemy's riposte), `Role.ASSASSIN` and `enemy_behavior_assassin.tres`, the test Assassin with its string, its gap-closer and its perilous move; the slip if there's room.
   **Done means:** the test Assassin raises its stance when you close in or gap-close; swinging into it rebuffs you (the swing gone, 0.4 s without attacking, combo back to swing 1, its riposte coming); baiting the stance and punishing its cooldown works; with the Knight's test deflect, a deflect pair plus the riposte breaks its meter (100: 75 + 40) and it stands broken 1.8 s; the elite slime's and the duelist's test meters fill the same new way. **Tests:** the meter's direction, decay and low-health scale; the break and immunity; the stance's window, one deflect, the whiff recovery; what it deflects (swings yes; Cleave, Lunge, Judgement no); the rebuff; its AI uses.
4. **AR4 – Weak basic attacks for every champion.** The stat `unempowered_attack_damage` (0.5 on the Knight's and Korsavil's UnitStats), the TEMP lever and its sandbox row retired with Ryan's OK, the rotation simulation.
   **Done means:** both champions' plain swings deal half; Iron Resolve's swing, the riposte and the jab are full; Fury per hit unchanged; enemies unchanged. **Tests:** the stat on each champion; empowered swings untouched; the rotation simulation (only swings ≥ 2× slower to kill the elite slime and the test duelist than the kit).
5. **AR5 – The Assassin layer on Korsavil.** The archetype at load (her one dash at 500 u recharging in 1.2 s, tuned between 0.8 and 1.5 s; the 0.2 s window; the refund), her passive's +1 `dash_charges` removed, the jab and its 1.5 m snap, the streak's 10 s expiry, the riposte's health share and its 6 m projectile snap, +10 Energy on a deflect, her meter (the share, heavy and perilous rules, the rebuff's 25, her deflect's drain) and its HUD bar, her break (1.0 s, ×1.25), being rebuffed by the test Assassin.
   **Done means:** as Korsavil you have one longer dash; a deflect refunds it and gives 10 Energy; swinging after one deflect jabs, waiting gives the riposte; the riposte takes 12% of the target's max health on top; you break the test Assassin and it breaks you if you eat its strings; as the Knight nothing changes (his test deflect still on V). **Tests:** her dash, its charge and its recharge; the window; the jab, its snap and the streak's end; the 10 s expiry taking the banked jab or riposte; the riposte's numbers (4% on a boss); the projectile snap and banking; her meter's fills, drain, decay and break; Energy.
6. **AR6 – The Knight's test version goes** (with Ryan's OK, in the same chain of commits as AR5's pass). The Knight's deflect off by archetype (disabled, not deleted), the non-Assassin poise values (the elite slime's and the duelist's `poise_max` 100) to 0, `SandboxDeflect` retuned to the Assassin's numbers, the Knight's chips kept and tuned (Ryan, Open questions 6: the Knight can still break an enemy Assassin).
   **Done means:** the Knight dashes as before (i-frames, no deflect, 0.35 s recharge); only Assassins show a meter; Korsavil's AR5 play still holds. **Tests:** the deflect test reads Korsavil; the Knight never deflects; no non-Assassin meter.
7. **AR7 – Duel pressure.** The aggression step and cap per enemy (cleared on reset), the passivity multipliers stacking with today's pressure, the ×2 cap on patience's boosts, Brains' damage-dealt clock, the overlay line, the panel rows.
   **Done means:** deflecting an enemy's strings makes it come faster (up to +0.3); standing back without hitting anyone makes every enemy commit sooner (×1.25 after 4 s, ×1.5 after 8 s), never more than twice as fast as without its boosts. **Tests:** the step and cap; the clear on reset; the 4 s and 8 s multipliers; the ×2 cap (an idle, low-health target with a passive player and three deflects); today's patience numbers unchanged without duel pressure; nothing read from the button press.
8. **AR8 – The rename pass and the archetype words in code.** `Role.BRUTE` → `BRUISER`, `CASTER` → `MAGE` (the stored ints unchanged), `DUELIST` and `enemy_behavior_duelist.tres` (the test duelist moved to it), the presets' file names, `caster_poke_score` and `caster_spacing_px`, `SituationContext.role`, the enemies test's and the brain overlay's words, `EnemyData.duelist` → `thinks_like_boss` with the alias (removed with Ryan's OK once the tests pass: D15), `ChampionData.champion_class` → `archetype` with the alias (Ryan, Open questions 14), mixup's "beat" → "held pause" in the overlay; `Archetype` files for all six. File by file, with Ryan's OK on the list first (CLAUDE.md: renames only with a reason; this one is decided).
   **Done means:** nothing plays differently; every suite green; the overlay and the panel say Bruiser, Mage, Duelist, Assassin.

**Milestone AR-M – the duel** (after AR8): Korsavil against the test Assassin, the test duelist and a mixed pack with strings and an elite's perilous move; then the Knight against the same with dashes only.
**Done means:** Ryan's play test: deflects come often enough to learn the beat; the pair, the riposte and the break feel like Sekiro; the Knight still wins by reading and dodging; nothing is unanswerable.

**The order of work** (Ryan, Open questions 15): AI-D3's play test → AR1–AR3 → AR4–AR6 → Korsavil's K3–K6 and K-M → AR7–AR8 → AR-M (the duel) → DUNGEONS' slice (D0–D9 and D-M, the vertical slice), with ENEMIES_AI AI7 before D1, AI5 before D3, AI6 before D4, and AI-M after AI7 without dodging (Open questions 18) → ENEMIES_AI AI4 (dodging) and AI8 (the later roles). The scripted boss events (`BossEvent`) go with ENEMIES_AI AI6 (the boss director).

## Edits to other docs (approved; applied 2026-10-07 to ENEMIES_AI, CHAMPIONS, COMBAT, CONVENTIONS and MOVEMENT)
### ENEMIES_AI.md
- **Header** (Read when, Status): point to ARCHETYPES.md for archetypes, strings, perilous attacks and duel pressure.
- **Goal / feel:** "Roles at first" → archetypes (Basic, Bruiser, Skirmisher, Mage, Duelist, Assassin; D13's ranks); "Enemy telegraphs" adds the beat (0.5 s) and the string's later hits (0.25 s); "The tell before a commit" notes the string's first hit reads 0.6 s or more in all; new rows for strings, perilous attacks and duel pressure; "Abilities per enemy: elites (and duelists)" → "(and thinks-like-boss elites)".
- **Rules, Roles, ranks and ability counts:** the role table becomes the archetype table; the "Skirmisher / assassin" row splits into Skirmisher and Assassin; "Any ranged enemy counts as a caster" → Mage; rank × archetype (D13); the later roles: a perched sniper is a Mage or a Skirmisher, support and summoner are Mages, decided at AI8 (Ryan, Open questions 12).
- **Kits:** "A duelist … `EnemyData.duelist`" → `thinks_like_boss` (D15); the word Duelist now names the archetype.
- **Intents and what an ability is for:** a deflect ability's `defend` uses (the Riposte Stance's rules).
- **Respect:** high respect cuts a string to 2 hits; low respect or a low target runs it full or extends it (D6).
- **The standoff:** duel pressure's passivity multipliers, stacking with `idle_pressure`, `low_pressure` and the odds' push (D8), and the ×2 cap on patience's boosts together (Ryan).
- **Combos, Combo plans and Where a plan lives in the brain:** a string as a step kind (`ComboStep.Kind.STRING`); a commit with no plan runs a string (D6).
- **The telegraph rule for combos:** every deflectable hit on the beat (D8).
- **Being combo'd, No kill protection:** stands as written (Ryan dropped D5's 60% rule: Open questions 1); no edit.
- **Enemies being combo'd, the poise hook:** stays built and off (D9); strike "A later `PoiseComponent` fills a meter from those and breaks the boss" (superseded: a boss gets the meter only as an Assassin); "a boss with poise will show its meter on the boss bar" applies to an Assassin boss only.
- **The test duelist:** the Duelist archetype; `duelist` → `thinks_like_boss`; its `poise_max` 100 goes in AR6; its finisher, retuned from a circle at its target to one around its own body, as its perilous move (AR2); its string (AR1).
- **Tells:** the perilous icon (the icon question parked for AI-M is answered: icons for perilous attacks only); the poses `riposte_stance` and `rebuffed`; the pose table by archetype instead of role.
- **Groups: attack tokens:** a token held for the whole string, freed on the last hit's recovery, a stun, a poise break or death (D6).
- **Poise: no flinch:** the poise meter on Assassins only (D3); "no flinch from ordinary hits" stands; the elite slime and the duelist lose their test meters (AR6).
- **Bosses: the director:** scripted events in `BossPlan` (D13): another archetype's layer for a phase, arena changes telegraphed 1.0 s or more, adds within the spawn budget; one at a time, none while a perilous attack is live, every one answerable (Ryan); a non-Assassin boss is opened by its plan's windows, no new meter (D9).
- **Scaling:** rank × archetype (D13).
- **Data:** `EnemyData` (`attack_string`, `thinks_like_boss`, `poise_max`'s −1), `EnemyBehavior.Role` (the values, the presets), `RankRules` (`perilous_max`, `poise_meter_max`, `poise_break_time`, `string_extra_hits`), `ComboStep.kind`, `BossPlan` and `BossPhase` (`events`, `BossEvent`), `PoseSet` (the poses), `EnemyAITable` (the new numbers), the vocabulary rows (role → archetype; **duelist** retired for the flag).
- **Architecture:** `EnemyBrain` (strings, the stance's use, the perilous gate, duel pressure) and `Brains` (the perilous gate, the damage-dealt clock).
- **Build order:** one line on the order of work (Ryan): ARCHETYPES AR1–AR8 and AR-M, then DUNGEONS' slice with AI7 before D1, AI5 before D3, AI6 before D4 and AI-M after AI7 without dodging, then AI4 and AI8; I11's "AI8 before DUNGEONS' slice" struck through where it appears (Rules, Roles: the later roles; Build order, AI8; Open questions, Interview I11); AI6 adds the scripted boss events; AI-M's dodging checks move to a short play test after AI4.
- **Open questions:** mixup's "held beat" becomes "a held pause" (accepted); the later roles' archetypes (answered: decided at AI8).

### CHAMPIONS.md
- **Rules, What a champion is:** a champion has an archetype (`champion_class` holds its id until AR8 renames it `archetype`, the old name an alias: Assassin, Mage, Skirmisher, Bruiser, Duelist), whose layer attaches at load (ARCHETYPES.md); diver, rogue, tank and marksman go (D14 parks the last two).
- **Rules, Passives:** an archetype's layer isn't the champion's passive (D11).
- **The Knight, Identity:** a Bruiser; in the end no deflect and no poise (D3); his placeholder layer (Brace) changes nothing in his kit now; his test version and its removal (AR6).
- **The Knight, Fury and the sheets:** weak basic attacks (×0.5 unempowered, D12); Iron Resolve's swing and the Fury payoffs are his empowers.
- **Korsavil, Player experience:** "two dashes" → one longer dash that deflects.
- **Korsavil, Identity:** "`dash_charges` stays 1 there: the second dash is the passive's" → one dash from the archetype (500 u, recharging in 1.2 s), the 0.2 s window, the refund, the jab's 1.5 m snap, the banked streak's 10 s expiry, her poise meter.
- **Korsavil, Passive:** part 1, "Two dashes", struck through (superseded 2026-10-07: D11); the tooltip loses "You have two dashes."
- **Korsavil, Energy:** a deflect costs nothing; a successful one +10 (D11).
- **Korsavil, The numbers:** "Passive: two dashes" → "one dash (the Assassin's)".
- **Korsavil, ChampionData:** `passive` "the `dash_charges` modifier and the two detonation rules" → the two detonation rules.
- **Korsavil, Build order:** a line for AR5 (the Assassin layer) beside K3–K6.
- **Open questions (Korsavil):** the riposte and the Vanish empowers on one swing (both add, as empowers do: confirm); her meter's HUD bar.

### COMBAT.md
- **Rules, Basic attack:** weak basic attacks (every champion; `unempowered_attack_damage`; not enemies; D12); "a click becomes a swing" unchanged.
- **Rules, Hits:** a deflect comes before invulnerability in `Unit.on_hit()` (built); what's deflectable, per side (D4, D7; an enemy's by origin: Ryan); perilous hits; the riposte and the jab as empowers (an enemy's riposte only on its basic attack hit, never a perilous hit).
- **Rules, Enemies:** strings and the beat (D6, D8); perilous attacks (D5; attacker-centered); "Two kinds of threat" gains the perilous layer; the elite slime's slam becomes attacker-centered (AR2).
- **Rules, Status effects:** `status_poise_broken` and the rebuffed statuses (not `cc`); the poise meter (Assassins only, fills to a break: D1, D3); "Bosses later fill a poise meter instead" struck (D9).
- **Rules, Status effects, Combos against the player:** "no kill protection" stands (Ryan dropped D5's 60% rule); no edit.
- **Numbers:** the deflect window 0.2 s, the beat 0.5 s, the spacing table, the perilous band ("perilous: 35–40%, the icon 0.4 s, the windup 0.9 s or more") under the enemy damage bands, the poise and break numbers, the riposte and the jab; "dash-strike (… other champions by class)" → by archetype.
- **Current code:** `DeflectComponent`, `PoiseComponent` and the prototype's fields (none of it is in COMBAT.md yet).
- **Data:** `HitContext` (`deflectable`, `deflected`, `poise_damage`, built; `perilous`), `AttackSwing` (`poise_damage`, built; `deflectable`), Fields on Ability (`deflectable`, `poise_damage`, built; `perilous`), `StatusEffect` (`empower_poise_damage`, built; the empower's health share).
- **Architecture:** the deflect hook first in `Unit.on_hit()`; `HitPipeline.apply_poise_damage()`.
- **Build order:** one line for the prototype (CHANGELOG.md, Combat, PROTOTYPE) and one pointing to ARCHETYPES AR1–AR8.
- **Open questions, Weapons:** "its class limits which weapons it can wield … bruiser weapons are heavier, diver and rogue weapons snappier" → its archetype.

### CONVENTIONS.md
- **Vocabulary:** "Champion class" → **Archetype** (shared by champions and enemies: Assassin, Mage, Skirmisher, Bruiser, Duelist; fodder's Basic; `champion_class` holds the id until AR8 renames it `archetype`, the old name an alias); an enemy's **role** becomes its archetype (fodder stays a rank); diver, rogue, tank and marksman go.
- **Vocabulary, new terms:** deflect, deflect window, deflectable, deflect ability (the Riposte Stance, a slip), streak, refund, jab, riposte, rebuffed, poise (the Assassin's meter; the AI-D3 hook stays "the poise hook"), break, string, the beat, spacing, perilous attack, duel pressure, an archetype's window (always qualified), weak basic attacks, thinks like a boss; **duelist** (AI3c's flag word) retired.
- **Standard ability tags:** the status tags `poise_broken`, `rebuffed`; the hit tag `perilous`.
- **Reserved names:** the prototype's built names (`DeflectComponent`, `PoiseComponent`, `SandboxDeflect`, `status_poise_broken`, `empower_riposte`, the five Events, `HitContext.deflectable` / `deflected` / `poise_damage`, `Ability.deflectable` / `poise_damage`, `AttackSwing.poise_damage`, `StatusEffect.empower_poise_damage`); the planned ones (`Archetype`, `PoiseRules`, `status_rebuffed`, `status_rebuffed_perilous`, `empower_jab`, `Ability.perilous`, `AttackSwing.deflectable`, `EnemyData.attack_string`, `thinks_like_boss`, `ComboStep.Kind.STRING`, `BossEvent`, `Events.perilous_started`, `unempowered_attack_damage`, `Role.DUELIST` / `ASSASSIN` / `BRUISER` / `MAGE`, the presets, the test Assassin's files, the poses); the ENEMIES_AI row's `EnemyData.duelist` → `thinks_like_boss`.

### MOVEMENT.md
- **Target feel:** "Other units: the player collides but is never steered/deflected" → "never steered or pushed aside" ("deflect" is the Assassin's now).
- **Dash:** an Assassin's dash opens the deflect window (0.2 s from its start, beside the i-frames) and is 25% longer (500 u, 160 px); one charge plus the refund (3 s), recharging in 1.2 s (tuned 0.8–1.5; the Knight keeps 0.35 s); the test recharge while the prototype's flag is on (built); Korsavil's second charge goes (D11).
- **Input buffering and cancels:** a rebuffed champion's 0.4 s attack lock: an attack press during it is buffered and fires when it ends *(proposed)*; dashing and moving stay allowed.
- **Current code:** `DashComponent`'s prototype additions (the refund, `get_recharge_time()`).

### Also (not in the five named; listed so nothing is lost)
- **CLAUDE.md:** a Docs index row for ARCHETYPES.md (added 2026-10-07 with the edits). The Next line's order of work was updated with Ryan's answers (2026-10-07).
- **ABILITIES.md:** Empowers (the jab, the riposte, the health share); deflect abilities as a cast pattern; `Ability.perilous` and `deflectable`.
- **ALLIES.md:** an AI-driven Assassin (the ally) deflects only through its own dash, timed by its brain from what's on screen; its archetype at the hub.
- **DUNGEONS.md:** rosters follow rank × archetype (at most 1 Assassin regular per room, from dungeon 3 on; no regular Duelists); the slice comes after AR-M, with ENEMIES_AI AI7 before D1, AI5 before D3 and AI6 before D4, and AI4 and AI8 after it (Ryan); its traversal between spaces should signal a room change (the banked streak clears on it); boss arenas take `BossEvent` arena changes and adds.
- **STATS.md:** the stat `unempowered_attack_damage` in its list and the registry (with AR4).
- **3D.md** (View, the pose hooks): "enemy brains show every decision as body language, never as an icon" needs the perilous icon's exception (with AR2).
- **AUDIO.md:** the deflect's clang, the perilous sting, the rebuffed and break sounds (the slots exist on the components).
- **UI.md** (when written): the perilous icon, the poise meter on the HUD and the boss bar.

## Later / not now
- **Rejected for the AI** (D10): extra respect for a ready deflect; treating the 1.5 s recharge as an opening.
- **Reflecting a deflected bolt** (D7: a later reward; today it's absorbed).
- **Tank and marksman** (D14).
- **The four placeholder layers** (Tempo, charge and release, Brace, the counter stance): designed and built when a champion of that archetype is.
- **A boss poise meter** for non-Assassin bosses (D9: no).
- **Deleting** the Knight's deflect code (after AR6 works, with Ryan's OK).

## Open questions
### Answered (Ryan, 2026-10-07: all 17, the same day; DECISIONS.md, Archetypes)
1. ~~**Kill protection (a conflict):** D5's "60% kill-protection rule" against the recorded "no kill protection".~~ **Dropped:** no kill protection; COMBAT's rule stands.
2. ~~**The beat and the spacing.**~~ **Claude's reading is right:** the 0.5 s beat belongs to a string's first hit and to any lone hit; later hits follow the spacing with wind-ups of at least 0.25 s.
3. ~~**The Mage's spacing:** about 0.4 s or 0.45 s?~~ **0.45 s.**
4. ~~**The banked streak:** final?~~ **Kept,** with a 10 s expiry and a clear on leaving the room, so an old streak can't surprise the player later.
5. ~~**The Assassin's normal dash recharge.**~~ **1.2 s to start, tuned between 0.8 and 1.5 s in AR5:** well above the Knight's 0.35 s, or a whiffed dash would cost nothing. The Knight keeps 0.35 s.
6. ~~**The Knight's chips.**~~ **They stay:** any champion's hits can carry poise damage, so a non-Assassin can break an enemy Assassin and nothing is unanswerable; only the meter is Assassin-only. Tuned in AR6.
7. ~~**Placed areas on the player's side.**~~ **Decided by origin:** attacker-centered melee shapes (a cone, a slam around its body) are deflectable; areas placed at the player (orbs, pools, beams) aren't. A perilous move is always deflectable, so it's always attacker-centered. The duelist's finisher and the elite slime's slam are retuned to match (AR2).
8. ~~**Rebuffed's blocks.**~~ **As proposed:** a champion gets an attack lock only; an enemy's 1.0 s also blocks casting and dashing.
9. ~~**Korsavil's meter readings.**~~ **Approved:** a heavy hit counts ×1.5; a landed perilous hit adds a flat 40.
10. ~~**Duel pressure.**~~ **The bonus lasts until the brain resets; the passivity multiplier stacks with the existing pressure; patience never fills more than ×2 as fast** (Duel pressure gives the cap's exact reading).
11. ~~**The Riposte Stance.**~~ **One hit per stance, then it ends,** so a string can't be unbeatable.
12. ~~**The later roles.**~~ **Approved:** a sniper is a Mage or a Skirmisher; support and summoner are Mages; decided at AI8.
13. ~~**A boss's extra layer.**~~ **All three, with limits:** another archetype's layer for a phase, arena changes telegraphed at least 1.0 s, adds within the spawn budget; one event at a time, none while a perilous attack is live, every event answerable.
14. ~~**Words.**~~ **Every proposal accepted** (Names checked against CONVENTIONS.md); `champion_class` is renamed `archetype` in AR8, the old name kept as an alias.
15. ~~**Where AR1–AR8 go.**~~ **AR1–AR3 after AI-D3's play test, AR4–AR6 before K3, AR7–AR8 after K-M, then AR-M (the duel), then the vertical slice, then AI4** (Build order, The order of work).
16. ~~**The enemy's riposte.**~~ **+1.0 AD ratio on its next basic attack hit only;** never on a perilous hit (that would reach 70–80% of max health).
17. ~~**The jab's snap.**~~ **A short snap: 1.5 m,** half the riposte's, so a single-deflect jab doesn't whiff after a long dash; tuned in AR5.

### Answered later (found while recording the answers, 2026-10-07)
18. ~~**AI4 after the slice, against ENEMIES_AI I11 (a conflict).** I11 puts AI8 before DUNGEONS' slice, and AI-M after AI4–AI7: do AI5–AI8 still come before the slice?~~ **Answered (Ryan, 2026-10-07, accepting Claude's recommendation):** only AI4 and AI8 move after the slice. AI5–AI7 come before it, each just ahead of the DUNGEONS step that needs it (AI7 before D1, AI5 before D3, AI6 before D4), and AI-M runs after AI7 without dodging (dodging gets a short play test of its own after AI4). AI8 after the slice reverses I11: with archetypes the slice shows five archetypes plus Basic, and the later roles are behaviors inside Mage or Skirmisher. (DUNGEONS' slice also needs the P-spike and WORLD_INTERACTION's unscheduled pieces first.)

### Open (found applying the edits, 2026-10-07)
19. **"Archetype" already has a meaning in ENEMIES_AI (a naming conflict this doc's name check missed).** The enemy ability library calls its reusable abilities "archetypes": the Kits table's "Archetype" column, the files `data/abilities/enemy/enemy_<archetype>.tres`, "it adds no new archetype", "a library archetype, break free". The applied edits left those uses alone. Claude's proposal: the library's entries become **templates** (they already are "templates" elsewhere: "the starter archetypes … as shared scripts and templates"), so "archetype" means only this doc's; the file names don't change (`enemy_charge.tres` etc.), only the docs' word and the pattern's placeholder (`enemy_<template>.tres`).
