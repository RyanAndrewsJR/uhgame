Read CLAUDE.md, docs/VISION.md, docs/CONVENTIONS.md, docs/DECISIONS.md, docs/MOVEMENT.md, docs/STATS.md and docs/WORLD_INTERACTION.md. Today's task: create docs/COMBAT.md. Docs only, no code.

Part 1 below is the vision half. Put it in the doc as written. Change wording only where it conflicts with the code or another doc, and tell me each time. Part 2 you write from the code. Plan first: show me your Part 2 outline and every conflict you found, and wait for my OK.

=== PART 1 ===

# COMBAT.md: Basic Attacks, Hits, Damage and Status Effects

## How to read this doc
- MUST: rules, names and order of operations. Never change these without asking Ryan.
- TARGET: a starting number and an allowed range. Tune inside the range; ask before going outside it.
- FREE: your call (VFX shapes, colors, implementation details). Tiebreaker: VISION.md's decision priorities.

## Player experience
A fight is a short, readable brawl. You click and the Knight swings toward the cursor almost instantly. Each swing plants you for a moment, just long enough to feel the weight, and a dash is always your way out. Hits land with a white flash, a tiny freeze and a push. Swarms chip at you if you stand still; elites wind up big, clearly telegraphed attacks that really hurt, and dodging them is the skill. Numbers pop off enemies, crits are unmistakable, and packs burst apart. You win by reading the fight and moving well, and your build decides how.

## References
- Hades. Take: a click becomes a swing within ~0.1 s; an aimed 3-hit combo; hit enemies flash white; a micro-freeze on heavy hits; floor telegraphs that fill up before the hit; the dash goes through everything; dash-strikes.
- League of Legends. Take: every ability's indicator shows exactly where it lands; readable cooldowns; one clear identity per kit; physical/magic/true damage; on-hit as a build path; tenacity. Don't take: click-an-enemy targeting, attack-move, last-hitting.
- Diablo. Take: packs that burst apart; damage numbers where crits stand out; conditional damage and on-hit build paths; the screen stays readable in chaos. Don't take: stat-check fights where you stand and trade hits; random dodge or block chance.

## Principles
1. The player's input is the authority. Presses fire now or as soon as allowed (input buffer, MOVEMENT.md). Nothing attacks or moves that the player didn't ask for.
2. Commitment is short, deliberate and readable. Every swing roots briefly; a dash is the way out.
3. Motion has shape: knockback uses the knockback curve (MOVEMENT.md F2).
4. Clarity over flash: the player's position, enemy telegraphs and the player's health are always readable. VFX never change gameplay state.
5. Forgiveness goes to the player: player attack hitboxes are slightly bigger than they look, enemy attack hitboxes slightly smaller.
6. Skill over stat checks: threats can be dodged, and sustain comes from build choices, not a baseline.
7. One set of rules for every Unit: one hit pipeline, one status system.

## Rules (MUST)
### Basic attack
- Left mouse = an aimed basic attack toward the cursor (Hades-style): a 3-hit combo; hit 3 is the finisher.
- Every swing roots the attacker for its duration (see Numbers).
- A dash cancels a swing before its hit lands (windup) or during its recovery. The moment the hit lands can't be cancelled. Cancelling resets the combo.
- Pressing attack during a swing queues the next combo hit (input buffer). The combo resets after combo_reset_time with no attack.
- attack_speed is a combo-speed multiplier for the player (1.0 = base timings; every swing timing is divided by it).
- Dash-strike (proposed): an attack within dash_strike_window after a dash (existing hook) does a stronger variant. Numbers under TARGET.
- attack vs select on left mouse (proposed): attack owns left mouse; select stays dormant (disabled, not deleted).

### Hits
- Every application of damage or effects is one Hit, described by a HitContext. In new code all damage goes through the hit pipeline; existing direct take_damage() calls get wrapped, not rewritten.
- Pipeline order: base → stat scaling (ratios) → conditional damage ("increased" by hit tags) → crit → mitigation (armor / magic_resist) → damage_reduction ("more") → shields → health. "Raw damage" = before mitigation; "damage taken" = after.
- Damage types: PHYSICAL (armor), MAGIC (magic_resist), TRUE (ignores both). Proposed mitigation: damage × 100 / (100 + armor).
- Invulnerability (dash i-frames, post-hit i-frames) blocks the whole hit: damage, knockback, statuses and on-hit.
- Hit tags: basic_attack, ability, proc, dot, crit, the damage type, plus the source ability's tags.
- On-hit: basic attack and ability hits trigger on-hit effects; dot ticks and proc hits never do (loop guard). Each Ability has proc_coefficient (1.0 default, lower for multi-hit or area abilities), which scales on-hit chances and effects. Numbers (on_hit_damage, life_on_hit, resource_on_hit) are stats; behaviors are augments or ReactionRules.
- Events: every hit emits Events.unit_hit(ctx), damage emits unit_damaged(ctx), death emits unit_died(unit, ctx). Reserved names only (CONVENTIONS.md).

### Enemies
- Two kinds of threat: swarms (small chip hits, short or no telegraph) and elites/bosses (big, telegraphed hits). Any enemy attack above the trash damage band has a floor telegraph.
- How fast the player dies is set per enemy, by its damage band (see Numbers).

### Status effects
- One system: StatusComponent plus StatusEffect Resources. Crowd control = statuses tagged cc (stun, root, silence, slow). The existing Unit.apply_stun() and add_speed_modifier() become thin wrappers that create statuses.
- Refresh or stack is decided per StatusEffect (data).
- tenacity shortens crowd control duration; it doesn't affect damage over time.
- DoT kill credit goes to whoever applied the status.

### Sustain
- Every champion starts with zero sustain (health_regen 0). Healing comes only from build choices: abilities, passives and items (life on hit, life steal, regen).

### Damage numbers
- Every hit shows a number above the target.
- Crits use a distinct font (proposed) and are larger.
- DoT ticks use a smaller style and are merged per target over a short window so they don't flood the screen.
- Size grows with the amount, in a few discrete pixel-font steps on a log scale, so late-game numbers don't all hit max size.
- Colors: by damage type (FREE, but readable); damage the player takes is red; healing is green.

## Numbers (TARGET: start, range)
Knight basic attack:
- windup (click to hit): 0.08 s (0.05–0.12)
- root per swing: 0.3 s (0.2–0.35); finisher 0.4 s (0.3–0.5)
- combo_reset_time: 0.6 s (0.4–0.9)
- damage: 1.0 / 1.0 / 1.6 × attack_damage
- reach: 175 u (56 px); arc 110°; finisher arc 140°
- knockback: 6 / 6 / 20 px, using the knockback curve
- dash-strike (proposed): 1.5 × attack_damage, a 16 px lunge

Feel per hit:
- hitstop: light 0.03 s (0–0.05); finisher/heavy 0.06 s (0.04–0.08); kill 0.08 s (0.05–0.10). Overlapping hitstops don't stack: take the longest.
- shake: light 0; heavy 2 px; kill 3 px (0–4)
- hit flash: white, 0.06 s

Player getting hit:
- post-hit i-frames: 0.5 s (0.3–0.8), starting from the first hit in a frame
- knockback on the player: 12 px (0–24); no loss of control beyond the push itself

Enemy damage bands (per hit, as % of the player's max health):
- swarm chip: 2–5%, telegraph 0–0.3 s
- elite: 12–20%, telegraph 0.6–0.9 s
- boss big hit: 25–40%, telegraph 0.9 s or more
- Telegraph: a floor shape that fills up until the hit; one consistent enemy-threat color (FREE which).

Hit forgiveness: player attack hitboxes +10% over their visuals, enemy attack hitboxes −10% (each 0–20%).
Damage numbers: rise 12 px and fade over 0.6 s; 3 size steps.

## Edge cases (MUST: Part 2 says how each is handled)
- Stunned mid-swing: the swing is cancelled with no hit, and the combo resets.
- Hit during i-frames: nothing happens (no damage, knockback, status or on-hit).
- A kill during hitstop; several hits in the same frame; overlapping hitstops (take the longest).
- Two knockbacks at once (proposed: the stronger one wins).
- The target dies before the swing lands (the swing whiffs); the attacker dies mid-swing.
- Attacks don't go through walls (line of sight via WorldQuery once it exists).
- A shield absorbing a hit doesn't stop its knockback.
- DoT ticks can't crit (proposed).

## Out of scope
Items and affixes (LOOT.md); ability costs, recasts and augments (ABILITIES.md); enemy AI beyond one telegraphed attack (ENEMIES_AI.md); elite affixes; pits; controller support.

## Open questions
- Dash-strike behavior and numbers.
- What attack_speed means for enemies (AutoAttackComponent).
- Sustain caps (life steal cap? regen during combat?).
- Healing between rooms (DUNGEONS.md).
- The crit font asset.
- Confirm the armor formula; is penetration needed?

=== PART 2 (you write this, from the code) ===
- Read when / Depends on / Used by.
- Current code: what exists and what's League-era (AutoAttackComponent, Hitbox/Hurtbox, take_damage(), damage_number.gd, GameFeel), and what happens to each (kept, wrapped, dormant).
- Data: the Resources and their fields (HitContext, StatusEffect, ReactionRule, GameplayEffect, the combo data for the basic attack).
- Architecture/contracts: new scripts with res:// paths, public methods, signals, the Events autoload.
- How each edge case above is handled.
- Build order in small steps (one per request), each with "Done means". First milestone: a one-room fight in the sandbox. The Knight attacks with the combo; slimes chip; one elite-style telegraphed attack exists (a stronger slime variant is fine); the player can die and restart.

After my OK:
- Write the doc and add it to the Docs index in CLAUDE.md.
- Add DECISIONS.md rows (Combat) for my decisions: Hades-style aimed 3-hit combo; every swing roots about 0.3 s with a dash as the escape; mixed threat (swarm chip plus telegraphed elites); time-to-death set per enemy through damage bands; zero baseline sustain, with healing only from builds; damage numbers with a crit font, a DoT style and size steps.
- Update Current status.