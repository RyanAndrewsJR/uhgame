# CONVENTIONS.md: Naming, Vocabulary & Extension Patterns

**Read when:** creating any new class, script, Resource, .tres, signal, autoload, tag, input action, or collision layer, or when adding an interaction between systems.
**Why:** so every system uses the same names and plugs together the same way. A new mechanic (e.g. "knockback into oil stuns") should mostly be new data, not new code spread across files.

## Naming (matches the existing code; don't rename existing things)
| Thing | Rule | Examples |
|---|---|---|
| Class | PascalCase, `class_name` on every reusable script | `Unit`, `AbilityComponent` |
| Component node | ends in `Component`. Exceptions: `Hitbox`, `Hurtbox` (Area2D), `PlayerInput` (reads input), `SurfaceTags` (data only) | `HealthComponent`, `StatusComponent` |
| Data Resource | a plain noun for what it is; `Data` suffix only for bundles of other resources | `UnitStats`, `Ability`, `StatModifier`, `ChampionData` |
| Per-event object | `<Thing>Context` (RefCounted) | `CastContext` (exists), `HitContext`, `ImpactContext` |
| Script file | snake_case of the class | `health_component.gd` |
| Ability script | `scripts/abilities/<champion>/<ability>.gd` | `knight/lunge.gd` |
| Ability .tres | `<champion>_<slot>_<ability>.tres` (the filename keeps the slot) | `knight_e_lunge.tres` |
| Ability `id` | `<champion>_<ability>`, no slot, so ids survive slot swaps | `&"knight_lunge"` |
| Other .tres | `<kind>_<name>.tres` in `data/<kind>s/` | `status_stun.tres`, `item_grapplers_gauntlet.tres`, `affix_fire_damage.tres`, `reaction_wall_slam.tres` |
| Signal | past tense, or `_started` / `_finished` / `_cancelled` / `_failed` / `_changed`; typed args | `died`, `cast_started`, `health_changed` |
| Global event (on `Events`) | `<subject>_<past verb>` | `unit_hit`, `unit_impacted`, `status_applied` |
| Query method | `get_`, `is_` / `has_` / `can_` (bool) | `get_move_speed()`, `can_cast()` |
| Command method | `apply_`, `set_`; `add_` / `remove_` pairs that take an id; `try_` returns false on failure | `add_move_lock(id)`, `try_cast()` |
| Callback others call | `on_<event>` | `on_hit(ctx: HitContext)`, `on_interact()` |
| Signal handler | `_on_<emitter>_<signal>` | `_on_hurtbox_hurt` |
| Ids and tags | `StringName`, snake_case | `&"iron_resolve_slow"`, `&"fire"` |
| Source id (new code) | `<kind>_<name>`, for modifier and status source ids | `&"item_4821"`, `&"status_burning"`, `&"hazard_oil"` |
| Move lock, speed modifier, invulnerability ids | name their owner (not `<kind>_<name>`). Existing ids don't change. | `&"dash"`, `&"iron_resolve_slow"` |
| Constant / enum | `UPPER_SNAKE`; enum type PascalCase | `Targeting.SELF`, `Team.PLAYER` |
| Units | pixels get a `_px` suffix; LoL units have no suffix; times are seconds (`_duration`, `_time`, `cooldown`) | `radius_px`, `cast_range` |

## Vocabulary (use these words, not synonyms)
- **Unit**: anything using `Unit` (champions, enemies, summons). Not "entity", "actor", or "character".
- **Champion**: a playable kit. **Enemy**: a hostile Unit (**elite**, **boss** are enemy tiers).
- **Ability**: a castable action in a slot. **Passive**: always-on champion behavior. **Augment**: an item-granted change to an ability's behavior.
- **Basic attack**: the design term. The code keeps `AutoAttackComponent`.
- **Hit**: one application of damage/effects to a unit, described by a `HitContext`.
- **Damage type**: `PHYSICAL`, `MAGIC`, `TRUE`.
- **Raw damage**: a hit's damage before mitigation. **Damage taken**: after mitigation and the `incoming_damage` stat (`HitContext.taken_damage`). "Damage taken" is never a stat name.
- **Stat modifier**: a change to a number (STATS.md).
- **Resource**: in design text, mana/energy/fury. In code the node is a `ResourceComponent` and the variable on Unit is `resource_pool`, so it isn't confused with Godot's `Resource`.
- **Status effect**: any timed state on a unit. **Buff** = positive, **debuff** = negative. **Crowd control (CC)** = status effects tagged `cc` (stun, slow, root, silence). There's one system for all of them, not separate buff and debuff systems.
- **Displacement**: any forced movement (dash, knockback, pull). **Knockback**: displacement caused by a hit. **Impact**: a displacement colliding with a wall or unit.
- **Surface**: a wall or solid body with `SurfaceTags`. **Hazard**: an area on the floor with tags that affects units in it (oil, fire, spikes, ice).
- **Interactable** (F key or ability-reactive object), **Pickup** (loot on the ground).
- **Item**, **item base**, **affix**, **rarity** (LOOT.md). **Room**, **run**, **dungeon** (DUNGEONS.md).
- **Swing**: one hit of the basic attack combo (windup, hit, recovery). **Combo**: the chain of swings; **finisher**: its last swing. A swing that hits nothing **whiffs**. Melee swings have a **swing step** (`lunge_px`), a **target pull** toward the **aimed enemy**, and an **aim snap** (COMBAT.md, Melee basic attacks).
- **Telegraph**: the floor shape that warns of an enemy attack and fills up until the hit.
- **Proc**: a hit caused by another hit (on-hit damage, reaction damage). It's tagged `proc` and never triggers on-hit.
- **VFX** means visuals only. It never changes gameplay state.

If you need a new term, add it here first.

## Extension patterns
### 1. Tags plus rules, not if-chains
Anything that can take part in an interaction carries tags:
- abilities (`tags`)
- hits (`HitContext.tags`)
- surfaces (`SurfaceTags`)
- hazards
- units (their active status effects add tags like `oiled`, `burning`, `displaced`)

Cross-system interactions are **`ReactionRule`** Resources: *trigger* + *required tags* → list of **`GameplayEffect`**s.
Planned triggers *(spec in COMBAT.md, ReactionRule; list also in WORLD_INTERACTION.md)*: `IMPACT`, `HIT`, `HAZARD_ENTERED`, `HAZARD_EXITED`, `STATUS_APPLIED`, `UNIT_DIED`, `HAZARD_OVERLAP` (hazard meets hazard, e.g. fire + oil).
Adding an interaction should mean adding a `.tres`. Code changes are only needed for a new trigger type or a new GameplayEffect type.

### 2. Context objects at every seam
Pass one context object, not long argument lists, so new fields can be added without changing signatures:
- `CastContext` (exists)
- `HitContext`: source, target, ability (nullable: null for basic attacks, hazards and knockback), amount, damage type, tags, knockback, effects to apply
- `ImpactContext`: unit, velocity, impact speed, collider, surface tags, who caused the displacement

### 3. Events at every seam
Systems announce what happened on the `Events` autoload, and reactions listen there. Reserved names:
- `unit_hit(ctx: HitContext)`, `unit_damaged(ctx)`, `unit_died(unit, ctx)`
- `unit_impacted(ctx: ImpactContext)`
- `status_applied(unit, status)`, `status_removed(unit, status)`
- `hazard_entered(unit, hazard)`, `hazard_exited(unit, hazard)`
- `ability_cast(unit, ability, ctx: CastContext)`
- `item_equipped(unit, item)`, `item_unequipped(unit, item)`

Existing local signals (`died`, `damaged`, `cast_started`...) stay. New code re-emits them on Events where cross-system listeners need them.

### 4. Components own their state
Other code uses a component's public methods, never its internal variables. Anything added through an `add_` method has an id so it can be removed exactly.

### 5. Existing code gets wrapped, not replaced
Example: when `StatusComponent` arrives, `Unit.apply_stun()` and `add_speed_modifier()` keep working as thin wrappers that create `status_stun` / slow statuses.

## Reserved names (planned; specified in the doc named)
| Name | What | Doc |
|---|---|---|
| `Events` | global signal bus autoload | here |
| `WorldQuery`, `SurfaceTags` | spatial queries, surface tags | WORLD_INTERACTION.md |
| `Settings`, `PauseMenu` | the player's own options autoload (saved to `user://settings.cfg`) and the Esc pause menu that edits them (both exist) | MOVEMENT.md (Dash) until UI.md |
| `StatsComponent`, `StatModifier`, `StatDefinition`, `StatRegistry`, `ResourceComponent`, `ChampionData` | stats (the first four exist) | STATS.md |
| `HitContext`, `DamageType` (enum `HitContext.DamageType`), `ImpactContext`, `HitPipeline` | the hit pipeline | COMBAT.md |
| `AttackSwing`, `AttackCombo` | basic attack combo data | COMBAT.md |
| `HitFeel` | hit feel per tier (hitstop, shake, flash) | COMBAT.md |
| `Telegraph` | enemy attack floor warning (VFX) | COMBAT.md |
| `StatusEffect` (Resource), `StatusComponent` | buffs, debuffs, CC | COMBAT.md |
| `ReactionRule`, `GameplayEffect` (+ subclasses like `ApplyStatusGameplayEffect`) | cross-system interactions | COMBAT.md |
| `Hazard` | floor areas with tags | WORLD_INTERACTION.md |
| `AbilityAugment` | item-driven ability behavior | ABILITIES.md |

## Worked example: "knocking an enemy into a wall or oil stuns or debuffs it"
With these patterns in place, this request is:
1. **One-time code** (if it doesn't exist yet): `MovementComponent` detects collisions during a displacement and emits `Events.unit_impacted(ImpactContext)`.
2. **Oil**: a `Hazard` scene tagged `oil`. Entering it applies `status_oiled` (tag `oiled`).
3. **Data only**:
   - `reaction_wall_slam.tres`: trigger `IMPACT`, surface tag `wall_slam`, min impact speed 200 px/s → apply `status_stun` for 1.0 s
   - `reaction_knocked_into_oil.tres`: trigger `HAZARD_ENTERED`, hazard tag `oil`, unit tag `displaced` → apply `status_slicked` for 3 s
4. **No ability changes.** Every ability or item that causes knockback gets this behavior automatically.

The prompt would be: *"Read CONVENTIONS.md and COMBAT.md. Add wall-slam stun and knocked-into-oil slick as reaction rules."*

## Testing
- `res://scenes/sandbox_main.tscn` (open it, press F6) runs `main.tscn` with `res://scenes/rooms/sandbox.tscn` as the room. What's in it now (walls, corners, corridors, dash-length markers, three passive training dummies, two slimes) is listed in MOVEMENT.md, Testing.
- Pits, hazards and grappleable walls get added to the sandbox with their systems (DECISIONS.md, Testing). Every new mechanic adds whatever it needs to test there.
- Script-level test scenes live in `res://scenes/tests/` with their scripts in `res://scripts/tests/` (e.g. `stats_test.tscn`, F6). They print PASS/FAIL per check and a total; run headless, they quit with the failure count as the exit code.
- Every new system has a `debug_draw` toggle.
- The F3 stat overlay is planned (STATS.md step 7), not built. It will need a new input action when it's built (none exists yet).

## Open questions
- Reaction triggers: specified in COMBAT.md (ReactionRule); `HIT`, `UNIT_DIED` and `STATUS_APPLIED` are built first (COMBAT C11).
