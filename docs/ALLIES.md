# ALLIES.md: The AI Ally, Controllers, Teams, Downed and Revive, Party Scaling
<!-- Written 2026-10-03 from Ryan's idea and his interview answers (the same day). A plan: nothing is built. -->

**Read when:** the task involves the AI ally (a second champion fighting beside the player), the controller abstraction (player input, an enemy brain or an ally brain driving a Unit), teams and targeting a teammate, how enemies pick between two champions (stickiness, threat, taunt, stealth), downed and revive, party scaling, the ally's gear, talents and XP, an ability's AI (`get_ai_plan()`), stances, the ally's HUD, or picking an ally at the hub.
**Depends on:** CLAUDE.md, VISION.md (Game structure, Meta-progression, Player fantasy), CONVENTIONS.md, STATS.md (StatModifier, scopes), ABILITIES.md (AbilityComponent, the cast flow, `get_ai_vector()`, untargetable, augments), COMBAT.md (`Unit.on_hit()`, statuses, invulnerability, damage numbers), CHAMPIONS.md (ChampionData, loading a champion), TALENTS.md (`Progress`, `ChampionProgress`, `ChampionLeveling`, the loadout rules, counters), LOOT.md (inventories, `EquipmentComponent`, drops, named items), MOVEMENT.md (the input map, PlayerInput, the dash), 3D.md (views, the screen pick, floor drawings), COMPANIONS.md (companions don't count for party scaling), ENEMIES_AI.md (Tier B: shared perception, movement and target picks; not written yet).
**Used by:** ENEMIES_AI (the target-pick rules with two champions, the controller contract, party scaling at spawn), DUNGEONS (checkpoints revive everyone, a wipe, room changes), UI (the hub's two-champion pick, the ally HUD, lending gear), NARRATIVE (pair banter), PROGRESSION (one save), every later champion (ally-aware kits, an AI method per ability), AUDIO (hooks).
**Status:** interview done 2026-10-03. Ryan's idea and his decisions (2026-10-03) and his interview answers (the same day) are MUST. Items marked *(proposed)* are Claude's picks Ryan hasn't answered; each is also in Open questions. Nothing is built. **Order of work:** Ryan builds one more champion (ranged/support, mana, a heal or shield on another unit; the ally-target pieces come with it) → ENEMIES_AI Tier B → ALLIES AL1–AL7 → milestone AL-M → an optimization and cleanup pass over all AI. Companions are a separate system, later.

## How to read this doc
Same as COMPANIONS.md: MUST (never change without asking Ryan), TARGET (start value and allowed range), FREE (your call; tiebreaker: VISION.md's decision priorities). Every number is a TARGET placeholder until the play tests.

## Player experience
At the hub you pick the Knight, then a second champion to fight beside you: a ranged support with a shield it can put on you. In the dungeon it walks a couple of steps behind you. Enemies go for whoever is closest, so you step in front to keep a brute off your support. It doesn't swap targets back and forth, and a taunt pulls it onto you for sure. As the elite's slam telegraph fills, a shield lands on you; your support sidesteps the slam a beat late and takes a little chip damage. It isn't perfect, but it's good. When it falls, it lies on the floor where nothing can touch it. You fight your way over and stand by it for two and a half seconds, still swinging, and it gets up. When you fall, you have ten seconds, and it comes for you. One key cycles its stance: aggressive, balanced, support. Every legendary that drops might be yours or its own. You lend it your spare rings and boots, and they're still yours when the run ends. Its talents are its own, and it reaches them by level, as fast as you'd learn them by use.

## References
- **League of Legends.** Take: champion pairs whose kits combine (a carry and a support, two fighters diving together); ally-targeted heals and shields with a self-cast fallback; taunt as crowd control (Rammus, Shen). Don't take: pings and orders to the AI, aggro you can't read.
- **Diablo 3 followers.** Take: a companion you gear from your own drops; monsters tougher per extra player (party scaling: more health, not more monsters); a follower a bit weaker than you. Don't take: a follower whose kit barely matters.
- **Dragon's Dogma pawns.** Take: an AI fighter with a real kit that reads the fight and is good but not perfect; inclinations (a behavior leaning, not orders) as the model for stances. Don't take: per-order commands (go, wait, help).
- **Baldur's Gate 3 companions.** Take: a downed companion helped back up by standing over them; a companion with personality who banters with you (NARRATIVE.md). Don't take: controlling the ally turn by turn.

## Principles
1. **The player is the star.** The ally is a bit weaker than you (it deals 20% less damage), human-ish rather than perfect, and you only steer it through stances. Your execution decides the fight (VISION.md, Player fantasy; Pillar 1).
2. **A champion is a champion.** The ally is a champion of the roster, the same ChampionData, abilities, passive, talents toolkit, gear hooks and hit pipeline as when you play it. The only thing an ally adds to a kit is each ability's AI method (One set of rules for every Unit: ABILITIES principle 6, COMBAT principle 7).
3. **One unit, any controller.** Player input, the enemy brain and the ally brain drive a Unit through the same intents. It's groundwork for co-op later; co-op itself is out of scope (VISION.md, Scope).
4. **Shared perception and movement, separate decisions.** Sight, pathing, steering and the target-pick rules are shared (ENEMIES_AI Tier B). Enemies and allies decide differently.
5. **Solo stays a full game.** The ally is optional. Every ally-aware talent and item also works when you're alone. With no ally chosen, the game plays exactly as today.
6. **A champion's progress powers only its own kit.** The ally uses its own level-paced talents and its own legendaries, plus generic gear you lend it for the run. Nothing moves between inventories, and ally play never unlocks talents for play (VISION.md's no-shared-power rule; see Open questions for the wording).
7. **Readable over clever.** Enemies pick targets by simple rules you can see (nearest, sticky, threat, taunt, stealth). The ally's own telegraphs and indicators don't show; its VFX do (Ryan: some VFX chaos is accepted).
8. **Tuning is data.** Party scaling, the ally's power, revive and follow numbers, stance weights and the think rate live in .tres files.

## Current code
- **Teams exist.** `Unit.Team { PLAYER, ENEMY }` and `@export var team` (`unit.gd`, default ENEMY). `Player._ready()` sets PLAYER and joins the group `player`; `Enemy._ready()` sets ENEMY and joins `enemies`. `Unit.is_enemy_of(other)` is "a different team". `AbilityUtil.enemies_of()`, `enemies_of_team()`, `along_segment_of_team()` and `Projectile.team` already pick hits by team, so a second PLAYER-team unit is never hit by the player's swings, abilities or projectiles. `Progress` counts a kill only when the dead unit is on another team.
- **Enemies know one player.** `Enemy._physics_process()` takes `get_tree().get_first_node_in_group("player")` as `_player`, and every AI state reads it: `_can_see_player()`, the chase, `_try_cast_ability()` (it aims every ability at `_player`), `_chase_untargetable()`. A second champion would be ignored. ENEMIES_AI Tier B replaces this with a target pick (Rules, How enemies pick a target).
- **Per-ability AI already has one hook.** `Ability.get_ai_vector(caster, target)` (ABILITIES AB13) lets a VECTOR ability tell the enemy AI where to lay its line. This doc grows that into one AI method per ability (Rules, An AI method per ability).
- **The player unit mixes the champion and the human.** `Player` (`player.gd`) loads the champion (`_apply_champion()`, `_attach_champion()`: stats, slots, combo, sounds, resource rhythm, modifiers, passive, the talent loadout from `Progress`; the gear from LOOT L2 and the companion from COMPANIONS CO2 are planned there too) and also owns the human's side: `_unhandled_input` (Q/W/E/R, Esc), `get_aim_point()` (the mouse, or the floor pick with a view; every aim in `player.gd` goes through it since 3D P5), `request_cast()` / `request_charge()`, `cast_ability()` (target forgiveness), the indicators in `_draw()`, `Progress.track()`. `PlayerInput` (its child) reads WASD, dash and attack and owns the input buffer. The HUD and the camera bind to the node in the group `player`.
- **Collision:** `player.tscn` is on layer 2 with mask 1095 (layers 1, 2, 3, 7, 11), so two champion units would block each other. Slimes (layer 3) mask 1095 too, so enemies are blocked by champions.
- **Death:** `HealthComponent` emits `died` at 0; `Unit._on_died()` cancels the attack, interrupts the cast and clears statuses; `main.gd` shows "You died – press Backspace to restart". There's no downed state. LOOT L5 plans an `undying` rule in `Unit.on_hit()` (a hit never takes the last 1 health); nothing is built.
- Nothing about allies, controllers, stances, revive or party scaling exists.

## Goal / feel
| What | Number (TARGET) | Why |
|---|---|---|
| Party size | 2 champions (you and one ally); no duplicates in v1 | Ryan |
| The ally's damage | −20% (`outgoing_damage` PERCENT_MULT −0.2) | Ryan: a bit weaker, you stay the star |
| Party scaling, per extra champion | enemies +60% health and +15% damage; elites and bosses +80% health; counts unchanged | Ryan: tougher, not more |
| Enemy target switch | only when another champion is 25% closer and 1.5 m (48 px) closer, for 0.5 s straight | Ryan: sticky with a margin |
| Revive | stand within 1.5 m (48 px) for 2.5 s; up at 30% health, 1 s invulnerable | Ryan |
| The player's bleed-out | 10 s | Ryan |
| The ally's bleed-out | none: down until revived or the next checkpoint | Ryan |
| Ally talent levels | tier 1 at champion level 3 (about 1.6 runs), tier 2 at level 9 (about 16 runs) | Ryan: the learn-by-use pace (TALENTS.md) |
| Follow spot | 2 m (64 px) behind you, 1 m (32 px) to the side, outside a fight | *(proposed)* |
| Catch-up teleport | beyond 12 m (384 px), or no path to you | *(proposed)* |
| Thinking | 5 thinks a second per brain, staggered; under 0.3 ms per think | Ryan: a few times a second, measured; the numbers *(proposed)* |
| Reaction to a telegraph | about 0.3 s (0.25–0.35); dodges about 80% of the telegraphs that cover it (0.7–0.9) | Ryan: good, but human; the numbers *(proposed)* |

## Rules
### What an ally is (MUST; Ryan 2026-10-03)
- Before a run, at the hub, the player picks their champion and **one other champion of the roster** to fight beside them as an **ally**, driven by an AI. It uses the same abilities as when you play it. None is allowed: the run is then exactly today's.
- **No duplicates in v1:** the ally can't be the champion you're playing.
- An ally opens up kits that work on another unit (heals, shields, buffs, crowd control that protects a teammate) and **party combos**: kits that set each other up (a rogue and a mage, two fighters diving together).
- **No friendly fire:** nothing the player or the ally does hurts or pushes the other. Hits already go by team (Current code); this also holds for reaction-rule damage, knockback and hazards a party member makes *(proposed: a hazard with a source never hurts its source's team; WORLD_INTERACTION.md's Hazard spec)*.
- **No collision between the player and the ally:** they walk and dash through each other. Enemies still collide with both. *(proposed)* Done by dropping layer 2 from the champion units' masks (`player.tscn` 1095 → 1093), so both stay on layer 2, which enemies mask; a one-value replace (Open questions).
- **The ally catches up:** past a set range from the player it teleports next to you (Following and catch-up).
- **It can be revived** (Downed and revive).
- **A party** is the champions in the run: the player's and its ally. Companions are not part of it and never count (COMPANIONS.md: a companion isn't a Unit).

### Teams and targeting a teammate (MUST: smart cast, the solo rule, built with the second champion; Ryan 2026-10-03)
- **Teammate:** a unit on the same team, other than the unit itself (the player's champion and its ally, each to the other). **Ally** names the AI champion; a heal "on a teammate" works both ways, so the ally can heal you with the same ability.
- An ability says which side it targets, `Ability.target_team` *(proposed name)*: `ENEMY` (the default, every ability today), `TEAMMATE`, `TEAMMATE_OR_SELF`. It matters for UNIT abilities and for the shape queries an ability script runs (an area shield on teammates).
- **Smart cast** (Ryan, 2026-10-03; League's self-cast fallback): for an ability that targets a teammate, the cursor over the teammate's model picks it (the 3D screen pick that picks enemies today, P5, extended to teammates for such an ability; without a view, `target_forgiveness` around the cursor). Otherwise the cast goes to the caster if the ability allows it (`TEAMMATE_OR_SELF`), else it fails with "no target". An enemy ability looks only at enemies and a teammate ability only at teammates, so the two never compete under the cursor.
- **The toolkit pieces** (`target_team`, smart cast on a teammate, teammate shape queries in `AbilityUtil`, conditions reading a teammate as the cast's target) are **built with the second champion**, before any AI, and tested on a friendly training dummy in the sandbox (Ryan, 2026-10-03). So its heal or shield works on another unit from its first day. ALLIES then adds the AI ally on top.
- **The solo rule** (Ryan, 2026-10-03): an ally-aware talent or item always does something when you play alone ("shields you **and** your ally", never "shields your ally"). It never sits dead without an ally. This joins TALENTS' authoring rule and LOOT's named items (Open questions, for other docs).

### How enemies pick a target (MUST: the rules; Ryan 2026-10-03. ENEMIES_AI Tier B builds them)
Enemies **target the nearest party member unless something overrides it**. With one champion this is today's behavior.
1. **Candidates:** the living party members it could aggro on (in sight within its detect range, or one that hit it). A downed, untargetable or stealthed unit is never picked.
2. **Taunt wins:** while the enemy carries a taunt status, its target is that status's source, if that source is still a candidate.
3. **Otherwise the nearest, weighted by threat:** effective distance = edge distance ÷ the candidate's `threat` stat (default 1). A champion with 1.5 threat counts as a third closer.
4. **Sticky with a margin:** the enemy keeps its current target until another candidate's effective distance is at least 25% shorter **and** at least 48 px (1.5 m) shorter, without a break, for 0.5 s. It never switches during a windup or a cast. It drops its target at once when the target goes down, turns untargetable or stealthed, dies or leaves the leash.
- The numbers (`switch_ratio` 0.25, `switch_px` 48, `switch_hold_time` 0.5) are data in Tier B's resource.
- **Threat** (a new stat, `threat`, default 1, min 0.1, max 10) *(proposed name and limits)*: "enemies prefer you" from a talent, an item or a passive is just a modifier on it. No aggro table: nobody tracks damage or healing done.
- **Taunt:** `status_taunt.tres` (tags `cc`, `taunt`, `debuff`); its source is the taunter. Being `cc`, tenacity shortens it, unstoppable refuses it and a `cc` cleanse removes it. A kit applies a copy with its own duration.
- **Stealth:** `status_stealth.tres` (tags `stealth`, `buff`): the unit is never picked as a new target. *(proposed)* An enemy already on it drops it at its next pick.
- "Everyone can tank": whoever stands closest draws the hits, and any kit or item can lean on it (threat, taunt, stealth). No champion has to be a tank.

### Downed and revive (MUST; Ryan 2026-10-03)
- **Going down:** a hit that would kill a party member while its teammate is up (neither dead nor downed) leaves it at 1 health (the same cap as LOOT's `undying`), and it goes **downed**: `status_downed` (tags `downed`, `untargetable`; blocks moving, attacking, casting and dashing; duration −1; never `cc`, `cleansable` false) plus the invulnerability id `&"downed"`. That blocks every hit, DoT ticks included, which untargetable alone lets through. Going down clears the unit's other statuses (as death does) and interrupts its cast and swing. `Events.unit_downed(unit, ctx)` fires; `unit_died` doesn't. With no teammate up, the hit kills as today.
- **The ally** stays downed until it's revived or the party reaches the next checkpoint. There's no bleed-out.
- **The player** goes downed for **10 s** (the bleed-out). The ally can revive you in that time. If the time runs out, or both of you are down, it's death as today: back to the last checkpoint, and the ally respawns with you (DUNGEONS.md; until checkpoints exist, the room restart). While downed you can't move or act, and the camera stays on you.
- **Reviving:** a teammate who is up stands within **1.5 m (48 px)** of the downed unit (feet to feet) for **2.5 s** of game time in total. Inside the ring the reviver can still swing, cast and dash. Leaving the ring pauses the progress (it's kept), and taking hits doesn't cancel it. Two revivers don't stack (there's only one teammate in v1).
- **Getting up:** at **30%** of max health (through `Unit.heal()`, so a green number shows) with **1 s** of invulnerability (`&"revived"`), so it doesn't drop again at once. `Events.unit_revived(unit, reviver)`. *(proposed)* The ally gets the same 1 s as the player.
- **Everyone revives at the next checkpoint** (Ryan): reaching one revives a downed ally at full health; a respawn after a wipe brings both back full.
- **Enemies drop a downed target at once** (rule 4 above). It stays where it fell; a downed ally never teleports.
- Data in `AllyTable` (Data): `revive_radius_px` 48, `revive_time` 2.5, `revive_health_ratio` 0.3, `revive_invulnerable_time` 1.0, `player_bleed_out_time` 10.

### XP, talents and gear (MUST; Ryan 2026-10-03)
- **XP is shared, not split:** a kill credited to either party member gives **both** champions its full XP, each into its own record (TALENTS' `xp_by_unit` today, ENEMIES_AI's replacement later). A downed champion still gets it.
- **Counters stay the player's:** TALENTS' ability uses and kills count only the player's own casts and kills (`Progress.track()` stays on the human's champion). The ally's casts and kills never count toward any counter, its own champion's included. So ally play can never unlock a talent for play.
- **The ally's talents** (Ryan, interview round 1):
  - A **separate ally loadout** per champion (`ChampionProgress.ally_loadout`), set at the hub. Its rules are the play loadout's (points from the champion level, one exclusive sibling, the tier rule; respec free).
  - As an ally, a talent is **available** once the champion level reaches its tier's **ally level** (`ChampionLeveling.ally_tier_levels`: tier 1 at level 3, tier 2 at level 9: the same pace as learning by use), or once it's unlocked by play.
  - Ally availability is **never an unlock**: playing that champion still needs the talent's own requirements.
  - Talents marked ally-available stay ally-available even if a retune raises the ally level. *(proposed: like TALENTS' kept unlocks; a loadout over the points is trimmed at load with a warning, TALENTS' rule)*
- **Gear** (Ryan, interview round 1; LOOT.md amended):
  - **Every drop goes to the player.** You equip the ally.
  - **Generic gear (Common to Exotic) is lent** from your inventory: it stays yours, only one of you can wear an item at a time, and the ally's set is remembered per champion pair (`ChampionInventory.ally_gear`). *(proposed)* Equipping a lent item on yourself takes it back from the ally (and the other way around), mid-run included, like any swap.
  - **The ally's Legendary and Artifact items come from its own inventory.** They're its own named items, from runs where you played it or from its share of named drops.
  - **A named drop is for either champion of the party, 50/50.** The total legendary rate per run stays the same and is split between the two. The ally's named items go straight into its own inventory (saved), and the HUD line names whose they are. *(proposed)* If the picked champion has no named item of that rarity, the roll goes to the other champion, then to an Exotic (LOOT's fallback).
  - Magic find is the killer's (LOOT's rule); the ally's comes from its gear.
  - LOOT's rules hold for the ally: a live swap never heals, augments are read at cast start, a named item can only be equipped on its own champion.

### Party scaling (MUST shape, Ryan 2026-10-03; numbers TARGET)
- **Tougher, not more:** with an ally along, enemies get more health and hit harder. Enemy counts stay the same, so fights stay readable ("methodical", VISION Pillar 1; VISION Open question 7).
- Per extra champion: regular enemies `max_health` PERCENT_MULT +0.6, elites and bosses +0.8, every enemy `outgoing_damage` PERCENT_MULT +0.15, all under the source `&"party_scaling"`. They're applied when the enemy spawns, so they never heal or refill anything mid-fight.
- **Party size is the number of champions who started the run** *(proposed)*: a downed ally still counts. Companions never count (Ryan).
- Which enemies are elites or bosses: their tier from ENEMIES_AI.md. Depth scaling (STATS.md's proposed `dungeon_scaling`) stacks with it.
- **The ally's power:** the ally deals 20% less damage (`outgoing_damage` PERCENT_MULT −0.2, source `&"ally_power"`), and takes normal damage. It's a list of modifiers in data, so its shape can change without code.

### Following and catch-up (MUST: teleport past a range, Ryan 2026-10-03; numbers *(proposed)*)
- Outside a fight the ally walks to a **follow spot**: 2 m (64 px) behind the player's last walking direction and 1 m (32 px) to the side. It paths there (`MovementComponent.move_to()`, NavigationServer2D) and steers around enemies like any unit. Inside a fight its stance sets how far it may stray (Stances).
- **Teleport:** beyond 12 m (384 px) from the player, or with no path to them, it teleports to a free spot near the player (behind them, on floor it can stand on, out of walls), calls `reset_physics_interpolation()` (CLAUDE.md, teleports) and plays a puff. Never while downed and never mid-cast: it waits until the cast ends.
- At a room change it comes along and appears next to the player (DUNGEONS.md decides how rooms change).

### Controllers: one unit, any controller (MUST shape, Ryan 2026-10-03; names *(proposed)*)
- A **controller** is what drives a unit: the human's input, an enemy brain or an ally brain. Each Unit has exactly one. It produces the same intents the human's input does today: a move direction (or a point to path to), an aim point, and presses (attack, dash, a slot press and release). The unit's components carry them out exactly as for the human: the input buffer's rules, cancels, cast styles, the cast flow.
- **Perception and movement are shared** (ENEMIES_AI Tier B): sight (the `Sight` ray on layer 1), pathing, steering, the target-pick rules. **Decisions are not:** enemies and allies have their own decision layers (the brains).
- **Groundwork for co-op:** a second human would be one more `PlayerInput` on another device driving one more champion unit. Co-op itself (two cameras or a shared one, two HUDs, devices) is out of scope.
- ENEMIES_AI Tier B comes first and builds the enemy brain, so it's the first controller other than the human's. ENEMIES_AI.md should adopt this contract. If it settles on another shape, AL1 follows Tier B's.

### An AI method per ability (MUST: per ability, in the ability's own script; Ryan 2026-10-03)
- **Each ability's script carries its own AI** (Ryan, rounds 3 and 5: per-ability scripts, not data hints, living next to `execute()` and the indicator). A virtual on `Ability`, `get_ai_plan(caster, sense) -> CastPlan` *(proposed name)*, answers "my best use right now, and how good is it?". It returns where to aim (point, direction, target, a VECTOR's start and direction, the charge to release at), the plan's **intents** (`damage`, `heal`, `shield`, `buff`, `cc`, `engage`, `escape`) and a **value**, or null when there's no good use now. `sense` is Tier B's perception of the fight around the caster.
- **It reads what the cast will read:** the caster's active flags (`AbilityComponent.get_flags()`) and the ability's own shape query, the same way `draw_indicator()` follows the flags today (TALENTS.md: Cleave's indicator). So Whirling Cleave's plan looks for enemies all around, Rending Cleave's for one far target in a narrow cone, Tackle's for the first enemy in the path. A REPLACE variant (Cleave Wave, Lunge's return, Judgement's leap) is its own script and brings its own plan.
- **Brains decide, abilities propose.** The ally brain weighs each ready slot's plan by its stance (Stances) and picks one; the enemy brain (Tier B) uses the same method with its own priorities. `get_ai_vector()` stays and is used by the default plan of a VECTOR ability (wrapped, not replaced).
- **A shared default** in the `Ability` base class covers test abilities and simple casts (a damage ability aimed at the best enemy in its own range). Every ability in a champion's kit, its REPLACE variants and its named items' variants overrides it (the allies test checks the list, as the talents test checks variants).
- **Scoring helpers** in `AbilityUtil` (damage as a share of the targets' health, health restored as a share of what's missing, crowd-control seconds on targets) keep every script's values comparable.
- Only castable slots are asked: `get_fail_reason()` empty (cooldown, cost, conditions), as `enemy.gd` does today.

### Stances (MUST: the only command, one key cycles them mid-run; Ryan 2026-10-03; the definitions *(proposed)*)
- Three stances: **aggressive**, **balanced** and **support**. They're the only command: no "go here", no "attack that".
- **One key cycles them during a run**: a new input action, `ally_stance` *(proposed: V, which is unbound)*, with a short callout over the ally and the stance on the ally HUD. The starting stance is picked at the hub, per player champion.
- A stance is data (`AllyStance`): how far the ally may stray from you, which enemy it prefers and a weight per intent.

| | Aggressive | Balanced (default) | Support |
|---|---|---|---|
| Stays within | 8 m of you | 5 m | 3 m, between you and the enemies' far side |
| Prefers | elites, then whatever is nearest it | what's hitting you, then what you're hitting, then the nearest | what's hitting you |
| Intent weights | damage 1.5, engage 1.5, cc 1, heal and shield 0.7, escape 0.7 | all 1 | heal and shield 1.5, cc 1.3, buff 1.3, damage 0.7, engage 0.5 |

- In every stance, reviving a downed teammate comes first, and a telegraph covering the ally is dodged first (Brain).

### The ally brain (MUST: good but human, thinks a few times a second; Ryan 2026-10-03; numbers *(proposed)*)
- **Good, but human** (Ryan, round 3; Dragon's Dogma's pawns): it reacts to an enemy telegraph after about 0.3 s, dodges the big telegraphs that cover it about 80% of the time (with the dash, out of the shape, toward you), sometimes eats chip damage, and uses its abilities well but not frame-perfectly (a random 0.1–0.25 s delay before a planned cast).
- **Thinking:** 5 thinks a second per brain (every 12 physics ticks at 60 Hz), staggered so two brains never think on the same tick. A few urgent events wake it on the next tick: a telegraph that covers it, a teammate going down, its own health falling below 30%. Movement, steering and pressing a swing when its target is in reach run every tick (they're cheap). Every step measures the think cost against a 0.3 ms budget per think and the 5.6 ms frame at 180 Hz.
- **Each think, in order:** (1) a downed teammate: go and revive it; (2) a telegraph covering it: dodge (after the reaction time, at the dodge chance); (3) the plans of its ready slots, weighed by the stance, cast the best one above a threshold; (4) its target (the stance's preference): swing when in reach, else close in, or keep its range for a RANGED combo; (5) no fight: the follow spot.
- **Combos come from the plans:** Cleave's plan values Staggered enemies higher, so an ally Knight cleaves what your Lunge staggered, and a support's shield plan values a teammate under an enemy telegraph. No pair is scripted by name.
- **Its own floor drawings never show in play:** no indicators and no cast telegraphs, only its VFX (Ryan). `AllyBrain.debug_draw` shows them, with its plans, its target and its follow spot.

## Data (Resources)
Names are *(proposed)* and checked against CONVENTIONS.md (reserved names, vocabulary); they go into CONVENTIONS when Ryan approves them. Resource scripts in `res://scripts/data/`.

### AllyTable (`ally_table.gd`; `res://data/ally_tables/ally_table_default.tres`)
The global ally rules, held by `Allies.table` (the pattern of `LootTable` and `CompanionTable`).

| Field | Type | Value |
|---|---|---|
| `follow_back_px`, `follow_side_px` | `float` | 64, 32 |
| `teleport_px` | `float` | 384 |
| `revive_radius_px`, `revive_time` | `float` | 48, 2.5 |
| `revive_health_ratio`, `revive_invulnerable_time` | `float` | 0.3, 1.0 |
| `player_bleed_out_time` | `float` | 10 |
| `think_rate` | `float` | 5 (thinks per second) |
| `reaction_time`, `dodge_chance` | `float` | 0.3, 0.8 |
| `cast_delay_min`, `cast_delay_max` | `float` | 0.1, 0.25 |
| `cast_value_threshold` | `float` | the lowest weighted value worth a cast (tuned in AL6) |
| `ally_modifiers` | `Array[StatModifier]` | `outgoing_damage` PERCENT_MULT −0.2; source `&"ally_power"` |
| `stances` | `Array[AllyStance]` | aggressive, balanced, support |
| `default_stance` | `StringName` | `&"balanced"` |
| `party_scaling` | `PartyScaling` | inline |

### AllyStance (`ally_stance.gd`; inline, three in the table)
`id` (`&"aggressive"`), `display_name`, `stay_within_px`, `prefers` (`AllyStance.Prefers`: `ITS_OWN_PICK`, `THREATS_TO_TEAMMATE`, `TEAMMATE_TARGET`; a list in order), `intent_weights: Dictionary` (intent → float; a missing intent counts 1).

### PartyScaling (`party_scaling.gd`; inline)
`health_per_extra` 0.6, `elite_health_per_extra` 0.8, `damage_per_extra` 0.15. Method `apply_to(enemy: Unit, party_size: int)`: the modifiers under `&"party_scaling"` (none at party size 1). DUNGEONS.md may later give a dungeon its own.

### Additions to existing data
| Where | Addition | Default | Notes |
|---|---|---|---|
| stat registry, `UnitStats` | `threat` | 1 (min 0.1, max 10) | effective distance = distance ÷ threat in target picks |
| stat registry, `UnitStats` | `outgoing_damage` | 1 (min 0) | a "more" multiplier on a unit's hit damage after `damage_increase` (stage 3), before crit; mirrors `incoming_damage`. The ally's −20% and party scaling's +15% |
| `Ability` | `target_team: Ability.TargetTeam` | `ENEMY` | `ENEMY`, `TEAMMATE`, `TEAMMATE_OR_SELF`; built with the second champion |
| `Ability` | virtual `get_ai_plan(caster, sense) -> CastPlan` | the shared default | AL4 |
| `ChampionLeveling` | `ally_tier_levels: Array[int]` | `[3, 9]` | index 0 = tier 1 |
| `ChampionProgress` | `ally_loadout: Array[StringName]` | `[]` | this champion's loadout as an ally |
| `ChampionProgress` | `ally_id: StringName`, `ally_stance: StringName` | `&""`, `&"balanced"` | the ally this champion takes along, and its starting stance |
| `ChampionInventory` | `ally_gear: Dictionary` | `{}` | ally champion id → equipment slot → [owner, uid]; owner `lent` = an item of this inventory, `own` = an item of the ally's own inventory (its named items) |
| statuses | `status_downed.tres`, `status_taunt.tres`, `status_stealth.tres` | | tags above (Rules) |
| Events | `unit_downed(unit, ctx)`, `unit_revived(unit, reviver)` | | reserved names |
| input map | `ally_stance` | V | |
| group | `party` | | every champion unit of the run (the player's joins it too); the HUD and camera keep reading `player` |
| `DamageNumberStyle` | `teammate_damage_color` | a muted red | damage the ally takes, so your own red stays yours *(proposed)* |

### CastPlan (RefCounted, `res://scripts/abilities/cast_plan.gd`)
One proposed cast: `ability`, `slot`, `point`, `direction`, `target: Unit`, `vector_start`, `vector_direction`, `charge` (0–1, CHARGE_UP), `intents: Array[StringName]`, `value: float`, `reason: String` (for `debug_draw`).

### Test and sandbox data
- A friendly training dummy (a unit on team PLAYER that stands still), from the second champion's step.
- `SandboxAllies` (`res://scripts/rooms/sandbox_allies.gd`, in `sandbox.tscn`): spawns the chosen ally next to the Knight, cycles the ally's champion (keys FREE), downs the ally or the player on a key (to test revives), and shows the brain's state. It never changes the save, like `SandboxCompanions`.

## Architecture / contracts
### Allies (autoload, `res://scripts/autoload/allies.gd`)
- Registered after `Progress`, `Loot` and `Companions`, before `Audio` (which stays last).
- `table: AllyTable`; `get_party() -> Array[Unit]` (the `party` group), `get_party_size()`, `get_ally() -> Unit`, `is_party_member(unit)`; `get_chosen_ally(champion) -> ChampionData` and `set_chosen_ally(champion, ally)` (the record's `ally_id`; refuses the same champion); `get_ally_talent_fail_reason(talent, champion) -> String` (TalentScreen's ally mode).
- On `SceneTree.node_added` for an enemy (or Tier B's spawn hook, whichever exists): `table.party_scaling.apply_to(enemy, get_party_size())`.
- It saves nothing itself: choices go into the progress record (`Progress`), lent gear into the inventory record (`Loot`).

### UnitController (`res://scripts/units/unit_controller.gd`) and the ally unit
- `UnitController` (Node, a child of the Unit): `get_unit()`, virtual `get_aim_point() -> Vector2`, `get_move_direction()`, `is_human() -> bool`, and the calls it makes: the unit's existing commands (`request_cast()`, `request_charge()` and their release, `AutoAttackComponent.try_swing()`, `DashComponent.try_dash()`, `MovementComponent.set_input_direction()` / `move_to()`).
- `PlayerInput` becomes the human's controller (it extends `UnitController`; its behavior doesn't change).
- **The ally is a `Player` node** *(proposed)* (`player.tscn`, its champion loaded by `_apply_champion()` / `_attach_champion()` like yours) whose controller is an `AllyBrain` (`res://scripts/allies/ally_brain.gd`, extends `UnitController`) instead of `PlayerInput`. Every champion system (passive, talents, gear, the dash, the combo) works for it with no second copy. It isn't a deeper subclass of Player (CLAUDE.md: champions are data).
- **What only the human's unit does** (`Player.is_human_controlled()`, true when its controller says so): read `_unhandled_input`, Esc and the pause; take the mouse or the floor pick as its aim; draw indicators; be the camera's and the HUD's target; join the group `player`; `Progress.track()`; attach a companion. For the ally, `get_aim_point()` returns the brain's aim, and its loadout comes from `ally_loadout`, its gear from the player's `ally_gear` set.
- `Main` spawns the ally next to the player's spawn when the player's champion has an `ally_id` (the hub sets it; `SandboxAllies` in the sandbox), on team PLAYER, in the group `party`, with `AllyTable.ally_modifiers` under `ally_power`.

### ReviveComponent (`res://scripts/components/revive_component.gd`, a child of `player.tscn`)
- `can_go_down() -> bool` (a teammate is up), `go_down(ctx)`, `is_downed()`, `get_revive_progress()` (0–1), `get_bleed_out_left()` (the player only; −1 for the ally), `revive(reviver)`. Signals `downed`, `revived`.
- `Unit.on_hit()` step 3 (COMBAT.md): a killing hit on a unit whose `ReviveComponent.can_go_down()` is true is capped at current − 1 (LOOT's `undying` cap), and `go_down(ctx)` runs after the hit's events. The planned `undying` rule and this share the cap.
- Each physics tick (game time) while downed: if a teammate who is up stands within `revive_radius_px`, progress += delta ÷ `revive_time`; at 1, `revive()`. The player's bleed-out counts down meanwhile; at 0, or if no teammate is up, the unit dies (`HealthComponent` to 0, as today).

### Progress, Loot and the hub (additions)
- `Progress`: on `Events.unit_died` with the kill credited to a party member, XP goes to every party member's record (each its full amount; level-up lines for the ally too: "<champion> reached level 4"). Counters, unlocks and `track()` stay the human's.
- `Loot`: a kill credited to a party member drops (LOOT's rule widened from "the tracked player"); generic items go into the player's inventory; a named roll picks the party champion 50/50 and goes into that champion's inventory. `EquipmentComponent` on the ally equips its `ally_gear` set at load; `can_equip()` gains "worn by your ally" / "worn by you" as a move, not a refusal.
- `TalentScreen` gets an ally mode: the ally's loadout, with "Ally: champion level 9 (now 6)" or "Unlocked by play" lines.

### HUD and the hub (functional, no art; CHAMPIONS CH6's spirit)
- **The ally HUD:** a small panel at the left edge: the ally's name, health and resource bars, its four ability cooldown squares, its stance, and, when it's downed, the revive progress. An arrow at the screen's edge points to the ally while it's off screen (red while downed).
- **While you're downed:** a 10 s bleed-out ring around you and the revive progress.
- **The hub:** an "Ally" row (none, or a champion other than yours), the ally's talent screen, and the starting stance. Lending gear goes through `SandboxLoot` (a key equips the highlighted item on the ally) until UI.md builds the real screens.

## View
- The ally is a Unit, so it gets a `UnitView` through the generic view mechanism (3D.md), with its champion's `model_scene`. Its health bar on `ScreenOverlay` uses the friendly color (the 2D bar already colors by team).
- *(proposed)* A faint ring in the team color under the ally (a floor drawing), so it reads apart from enemies when VFX get busy.
- **Its own floor drawings stay off canvas layer 3** (no indicators, no cast telegraphs) unless `AllyBrain.debug_draw` is on. Its cast and impact VFX show as usual.
- **Downed:** the model plays a `downed` clip (a `UnitView` export, like its other base clips) and lies still; a ring on the floor fills with the revive progress; the player's bleed-out ring drains. A teleport plays a puff at both ends (WorldView already snaps a view whose sim node moved more than 64 px in a tick).
- The camera follows the player only.

## Audio hooks
Audio hooks: see AUDIO.md. To add when built (synthesized placeholders until real files): going down, a revive loop while the progress fills, getting up, the stance-cycle click, the teleport puff. *(proposed)* The ally's combat sounds a little quieter than yours. Pair banter and voice lines are NARRATIVE.md's and AUDIO.md's.

## How each edge case is handled
| Edge case | Handling |
|---|---|
| No ally chosen | Nothing changes: party size 1, no scaling, no downed state; the game plays exactly as today |
| The ally is the champion you're playing | Not allowed in v1 (`set_chosen_ally()` refuses; the hub doesn't offer it) |
| Your swing, ability, projectile or knockback reaches the ally | Nothing: hits go by team. The same for the ally's on you |
| You walk or dash into the ally | You pass through each other; enemies still collide with both |
| Two champions at about the same distance from an enemy | It keeps its target until the other is 25% and 1.5 m closer for 0.5 s straight; never mid-windup or mid-cast |
| A taunt from a downed or untargetable unit | Ignored: the taunter isn't a candidate, so the normal pick runs |
| The ally goes down | Enemies drop it at once; it stays down, untouchable, where it fell, until revived or a checkpoint |
| A DoT on a unit as it goes down | Cleared with its other statuses; the `downed` invulnerability blocks any tick |
| `undying` (Oathbound Plate) and a killing hit | Undying holds it at 1; it doesn't go down |
| You go down | 10 s; the ally comes to revive you (first in every stance); time out → death and the checkpoint |
| Both down in the same frame, or one goes down while the other is | A wipe: death as today, both back at the checkpoint, full health |
| The reviver goes down mid-revive | It's no longer up, so the progress pauses; with both down, a wipe |
| Hit while reviving | The progress keeps going; leaving the ring pauses it |
| You run more than 12 m from a downed ally | It doesn't teleport; you walk back to revive it, or it's revived at the next checkpoint |
| The ally more than 12 m away and casting | It teleports when the cast ends |
| A kill by the ally | Both champions get the XP; no counter moves; a drop as for your kills |
| A kill while you're downed | You still get its XP |
| A named drop for a champion with none of that rarity | The other party champion's, then an Exotic |
| Equipping a lent item on yourself | It moves from the ally to you (a swap; no heal) |
| Ally Cleave casts | Never counted toward the Knight's Cleave uses |
| A retune raises an ally talent level | Talents already ally-available stay so *(proposed)*; a loadout over the points is trimmed at load with a warning |
| An ally-aware talent with no ally | It still works on you (the solo rule) |
| Smart cast with the cursor on the ally and on an enemy | Each ability looks only at its own side: a heal takes the ally, a strike the enemy |
| The ally mid-cast when its target dies | The cast plays out as for anyone (ABILITIES.md); the next think picks again |
| Party scaling while the ally is down | Unchanged: party size is who started the run *(proposed)* |
| Enemies spawned mid-room | Scaled at spawn |
| A companion | Never counts for party scaling; it follows the player's champion only *(proposed)* |
| Tests | Saving off in a test scene (`Progress.is_test_scene()`); the brain's random numbers come from a seedable `rng` |

## Build order (one step per request)
**Before AL1:** the second champion with the ally-target pieces (Teams and targeting a teammate); ENEMIES_AI Tier B (shared perception, movement, the target pick, the enemy brain; ideally on the controller contract); LOOT L2 (`EquipmentComponent`, inventories) for the gear rules; TALENTS T4 (built).
Every step: the Knight's abilities, talents, enemies chasing and the HUD still work, and with no ally chosen the game plays exactly as before. Build logs go in CHANGELOG.md (an Allies section); this doc keeps one line per built step.

1. **AL1 – Controller and team.** `UnitController`, `PlayerInput` as the human's controller, `Player.is_human_controlled()` and the human-only paths gated, a stub `AllyBrain` (stands still), the ally spawned as a `Player` node on team PLAYER (`Main`, `SandboxAllies`), the group `party`, the `Allies` autoload, no player–ally collision, no friendly fire (hits, projectiles, reaction damage, hazards with a source), enemies picking between two champions by the rules (stickiness, `threat`, `status_taunt`, `status_stealth`) through Tier B's pick; `res://scenes/tests/allies_test.tscn` + `scripts/tests/allies_test.gd`.
   **Done means:** you play exactly as before through `PlayerInput` (every suite green, unchanged); a scripted test controller walks, swings, dashes and casts each Knight ability through the same intents; nothing of yours touches the ally and you walk through each other; with two champions side by side an enemy doesn't flip-flop, switches only past the margin, follows a taunt and ignores a stealthed champion; with no ally every suite is unchanged.
2. **AL2 – The ally champion: talents, gear, XP, scaling.** The ally loaded with its `ally_loadout` (`ally_tier_levels`, ally availability) and its `ally_gear` set (lent and own named items), `ally_power` (`outgoing_damage`), shared XP, counters kept to the player, named drops 50/50 into the right inventory, lending (one wearer, remembered per pair, moved by equipping), `PartyScaling` at spawn, the `threat` and `outgoing_damage` stats.
   **Done means:** a slime killed by either gives 5 XP to both records and moves no counter for the ally; over seeded rolls named drops split about 50/50 and the ally's land in its inventory; a lent item can't be worn by both and comes back with the run's end still in your inventory; the ally's talents follow the ally levels and never unlock for play; enemies get +60% / +80% health and +15% damage with an ally, nothing alone; the ally deals 20% less; with no ally every suite is unchanged.
3. **AL3 – Following, catch-up and revive.** The follow spot and pathing, the teleport (no slide), `ReviveComponent`, `status_downed`, `unit_downed` / `unit_revived`, the ring revive both ways, the player's bleed-out, the wipe, getting up with invulnerability, the downed and revive rings and the `downed` clip in the view. The brain still only follows and revives.
   **Done means:** the ally trails you, catches up through a door with a puff and no slide, never teleports while downed; it goes down instead of dying while you're up, enemies drop it, you revive it in 2.5 s inside the ring while swinging (leaving pauses, hits don't cancel), it gets up at 30% with 1 s invulnerable; downed, you get 10 s and the ally revives you; time out or both down → the room restart (checkpoint later); Ryan's play test in the sandbox.
4. **AL4 – An AI method per ability.** `CastPlan`, `Ability.get_ai_plan()` and its default, the scoring helpers, a plan in every Knight ability (Cleave with Whirling and Rending, Iron Resolve with Challenge and Bulwark, Lunge with Tackle and Twin Lunge, Judgement with Executioner and Shockwave), Cleave Wave, Lunge's return and Judgement's leap (as LOOT builds them), and the second champion's kit; a simple brain that casts its best plan; the allies test's override check.
   **Done means:** in fixed test scenes each ability's plan aims where its effect lands best (the most enemies in Cleave's cone, Whirling's circle when surrounded, Judgement on the low-health elite, a shield on the teammate under a telegraph); a flag changes the plan; every kit ability and variant overrides the default; Ryan's play test: the ally uses its kit sensibly.
5. **AL5 – Stances.** `AllyStance` (three in the table), the `ally_stance` action on V (editor steps), the callout, the stance on the ally HUD's line, the hub's starting stance in the record.
   **Done means:** V cycles the stance mid-run and it shows; support stays close and holds its heals and shields for you; aggressive goes for elites; balanced fights what's on you; Ryan's play test: each stance plays differently.
6. **AL6 – The full brain.** Target choice by stance, dodging telegraphs (reaction time, dodge chance, the dash), the cast delay, keeping range for a RANGED combo, combos falling out of the plans, revive first, the think loop with urgent wake-ups, `debug_draw`; the think cost measured.
   **Done means:** the ally dodges most big telegraphs a beat late, eats some chip damage, uses Lunge → Cleave on what you staggered (and you on what it staggered), revives you under pressure; each think stays under 0.3 ms and the sandbox fight under the 180 Hz frame budget (measured; CHANGELOG.md); Ryan's play test: it feels like a good human, not a bot.
7. **AL7 – UI.** The hub's Ally row (no duplicates), the ally's talent screen, the starting stance, the ally HUD panel, the off-screen arrow, the downed screen state, lending in `SandboxLoot`. Functional placeholders; UI.md polishes them.
   **Done means:** at the hub you pick an ally and its talents and stance, and Start run takes it along; the HUD shows its health, cooldowns, stance and revive progress; you can find it off screen; quitting and relaunching keeps the choice, its loadout and its lent set.

**Milestone AL-M – A run with an ally** (after AL7): Ryan plays a few runs with each pair (the Knight with the second champion, and the other way round): the pair reads, enemies stay dangerous, the ally helps without carrying, the revives are moments, enemies never flip-flop, and nothing new breaks movement or clarity.
**Done means:** Ryan's play test. Then the optimization and cleanup pass over all AI (Ryan: after all AI is built).

## Out of scope
Real co-op (a second human), more than one ally, duplicates, commands beyond stances; the second champion's kit itself (CHAMPIONS.md); enemy behaviors and tiers (ENEMIES_AI.md); checkpoints and room changes (DUNGEONS.md); pair banter and voice (NARRATIVE.md, AUDIO.md); the polished hub, champion select, inventory and HUD (UI.md); one save (PROGRESSION.md); the optimization pass (after all AI).

## Open questions
Claude's proposals still open (written in above as *(proposed)*; Ryan can overrule any):
1. **The ally is a `Player` node** driven by an `AllyBrain`, with `player.gd`'s human-only paths gated by `is_human_controlled()`, rather than a new Unit subclass with the champion loading pulled out of Player. It touches working `player.gd` code (the change policy: ask first).
2. **No player–ally collision** by dropping layer 2 from the champion units' masks (`player.tscn` 1095 → 1093): a one-value replace.
3. **Names:** `UnitController`, `AllyBrain`, `Allies` (autoload), `AllyTable`, `AllyStance`, `PartyScaling`, `CastPlan`, `ReviveComponent`, `SandboxAllies`; `get_ai_plan()`; `Ability.target_team` (`TargetTeam`: `ENEMY`, `TEAMMATE`, `TEAMMATE_OR_SELF`); stats `threat` and `outgoing_damage`; statuses `status_downed`, `status_taunt`, `status_stealth` (tags `downed`, `taunt`, `stealth`); events `unit_downed`, `unit_revived`; input `ally_stance` (V); group `party`; source ids `ally_power`, `party_scaling`; invulnerability ids `downed`, `revived`. Vocabulary: **ally**, **teammate**, **party**, **controller**, **brain**, **stance**, **downed**, **revive**, **bleed-out**, **wipe**, **threat**, **taunt**, **stealth**, **lend**, **plan**.
4. **The stance table** (ranges, preferences, weights).
5. **Following:** 2 m behind and 1 m aside; teleport past 12 m or with no path, never while downed or mid-cast.
6. **The brain's numbers:** 5 thinks a second, under 0.3 ms each, urgent wake-ups; reaction 0.3 s, dodge chance 0.8, a 0.1–0.25 s cast delay.
7. **The ally's 1 s invulnerability** on getting up, like yours.
8. **Equipping a lent item on yourself takes it back** from the ally (a move, not a refusal).
9. **Stealth also drops a current target** at the enemy's next pick.
10. **A named roll with no item for the picked champion** goes to the other, then to an Exotic.
11. **Party size is who started the run** (a downed ally still counts for scaling).
12. **Hazards a party member makes never hurt its team.**
13. **The look and sound:** a faint team-colored ring under the ally, its damage taken in a muted red, its sounds a little quieter, an off-screen arrow.
14. **Companions:** only the player's champion takes one; its bond follows the player's XP, so the ally's kills count for bond too.
15. **Ally talent availability is kept** after a retune raises an ally level (TALENTS' kept-unlocks rule, applied here).
16. **VISION's wording** for Principle 6 (see the reply's conflict list): "a champion's progress powers only that champion's own kit, played or as an ally; lent gear is lent for the run and never moves".

For other docs (nothing proposed beyond the above):
- **ENEMIES_AI.md (Tier B):** the target pick with candidates from the party, stickiness, threat, taunt and stealth; aggro on any party member; dropping a downed target; adopting the controller contract; an enemy's AI asking its abilities' `get_ai_plan()`; the tier that party scaling reads; telegraphs the ally's perception can read.
- **DUNGEONS.md:** checkpoints revive everyone; a wipe; a downed ally across a room change; party scaling per dungeon.
- **UI.md:** the polished two-champion pick, the ally HUD, the lending screen.
- **NARRATIVE.md:** pair banter (Hades-style reactive lines, BG3-style banter between champions).
- **PROGRESSION.md:** `ally_id`, `ally_stance`, `ally_loadout` and `ally_gear` fold into the one save.
