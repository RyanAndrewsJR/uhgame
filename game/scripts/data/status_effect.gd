class_name StatusEffect
extends Resource
## One status effect (COMBAT.md, Status effects): any timed state on a unit.
## Buffs, debuffs and crowd control are all StatusEffects; crowd control is
## a status tagged &"cc". One .tres per status in res://data/statuses/
## (status_<name>.tres). A StatusComponent applies them.

## What re-applying a status that is already on the unit does.
enum StackRule {
	REFRESH_LONGER,  ## Keeps the longer remaining time (the stun).
	REFRESH,         ## Replaces it: the new numbers, source and full duration.
	STACK,           ## Adds a stack (up to max_stacks), each with its own time. At max, the stack closest to running out restarts.
	IGNORE,          ## Nothing happens while it's active.
	STACK_SHARED,    ## Adds a stack (up to max_stacks) and restarts the one timer every stack shares; they end together (CHAMPIONS K2: Inevitable Demise). At max it only restarts it.
}

## What uses up an empower (ABILITIES AB10). NONE = not an empower.
enum EmpowerTrigger {
	NONE,
	BASIC_ATTACK_HIT,  ## The next basic attack swing that hits anything.
	ABILITY_CAST,      ## The next ability cast (started by the player or the AI; not a free cast) matching empower_scope.
}

## &"stun". Its StatModifiers use the source id &"status_stun"
## (get_source_id()), and its move / attack locks use the id itself.
@export var id: StringName = &""
@export var display_name: String = ""
## &"cc", &"stun", &"root", &"silence", &"slow", &"haste", &"buff",
## &"debuff", &"dot"... &"target:<tag>" damage bonuses read them (COMBAT C8).
@export var tags: Array[StringName] = []
## Seconds. -1 = until removed. Tenacity shortens it for &"cc" statuses.
@export var duration: float = 1.0
@export var stack_rule: StackRule = StackRule.REFRESH_LONGER
## STACK and STACK_SHARED only.
@export var max_stacks: int = 1
## True: tenacity doesn't shorten it, though it's cc (3D.md, Airborne: a
## knock-up keeps its arc; League's rule).
@export var ignores_tenacity: bool = false
## False: a cleanse and gaining unstoppable don't end it
## (StatusComponent.remove_statuses_with_tags() skips it; airborne, Ryan
## 2026-10-01). Unstoppable still refuses a new one if it's cc.
@export var cleansable: bool = true

@export_group("Stats")
## Added while active (under get_source_id()), once per stack. Slows and
## hastes are move_speed PERCENT_ADD modifiers.
@export var modifiers: Array[StatModifier] = []
## StatScaling resources added to the unit while active, under
## get_source_id() (once, not per stack; CHAMPIONS K2): a value that follows
## an input such as another status's stack count (`self_status_stacks`), like
## Korsavil's orbit following her Blades. Refreshed when the unit's health or
## statuses change. Typed as Resource for the preload cycle (reaction_rules).
@export var stat_scalings: Array[Resource] = []

@export_group("Rules")
## Unit rules (ReactionRule resources) the unit has while this status is
## active, under get_source_id() (ABILITIES AB8): a buff, a passive's state or
## an empower can bring its own "when X, do Y". Typed as Resource on purpose:
## MovementComponent preloads status .tres files while scripts compile, and a
## ReactionRule type here would pull GameplayEffect and Unit into that cycle.
@export var reaction_rules: Array[Resource] = []

@export_group("Augments")
## AbilityAugment resources on the unit's AbilityComponent while this status is
## active, under get_source_id() (ABILITIES AB9). A form is a status tagged
## &"form" whose REPLACE augments swap several slots at once; applying one
## removes any other form. Typed as Resource for the same preload cycle as
## reaction_rules.
@export var augments: Array[Resource] = []

@export_group("Empower")
## "Your next attack / next ability" (ABILITIES AB10). Tag it &"empower" too.
## Used up (removed) by the first swing that hits anything, or by the next
## matching cast's effect start; its bonus goes into every hit of that swing
## or cast (so it crits with the hit).
@export var empower_consumed_by: EmpowerTrigger = EmpowerTrigger.NONE
## ABILITY_CAST only: &"" = any ability; &"ability:<id>" / &"tag:<tag>".
@export var empower_scope: StringName = &""
@export var empower_base_damage: float = 0.0
## Of the attacker's attack_damage at the hit.
@export var empower_ad_ratio: float = 0.0
## Applied to every enemy the swing or cast hits (through HitContext.statuses).
## StatusEffect resources, typed as Resource: a typed array of its own class
## made the script reference itself (a leak reported at exit).
@export var empower_statuses: Array[Resource] = []

@export_group("Blocks")
@export var blocks_move: bool = false
## Also cancels an attack windup or a combo swing when applied.
@export var blocks_attack: bool = false
## Can't start casts; a cast whose cast time ends while it's active is interrupted.
@export var blocks_cast: bool = false
@export var blocks_dash: bool = false

@export_group("Damage over time")
## Seconds between ticks. 0 = no damage over time. The first tick comes one
## interval after it's applied.
@export var tick_interval: float = 0.0
@export var tick_damage: float = 0.0
## Fraction of the applier's attack_damage, snapshotted when applied.
@export var tick_ad_ratio: float = 0.0
@export var tick_damage_type: HitContext.DamageType = HitContext.DamageType.MAGIC
## Empty: a tick deals its snapshot x the stacks. Otherwise entry n - 1 is the
## multiplier at n stacks instead (the last entry past the end), so a DoT can
## step by tiers (CHAMPIONS K2: Demise's 0 / 0.5 / 0.5 / 0.8 ...). A tick
## whose multiplier is 0 deals nothing and isn't a hit.
@export var tick_by_stacks: Array[float] = []

@export_group("Shield")
## Damage it absorbs before health (after armor and incoming_damage), per
## application (each stack has its own). 0 = not a shield. A shield ends when
## it's used up. COMBAT C10.
@export var shield_amount: float = 0.0

@export_group("Visuals")
## Instanced as a child of the unit while the status is active. Visuals only.
@export var vfx: PackedScene

@export_group("Sounds")
## On every application, refresh and new stack included (AUDIO.md).
@export var apply_sound: SoundEvent
## When it ends while the unit is alive (ran out, removed, a shield used up).
## Silent when the unit dies.
@export var expire_sound: SoundEvent
## Plays while the status is active: one loop per unit, however many stacks.
@export var loop_sound: SoundEvent


## The source id its StatModifiers use: &"status_<id>" (CONVENTIONS.md).
func get_source_id() -> StringName:
	return StringName("status_" + id)


## Crowd control: tenacity shortens it.
func is_cc() -> bool:
	return tags.has(&"cc")


## An empower (ABILITIES AB10): something uses it up.
func is_empower() -> bool:
	return empower_consumed_by != EmpowerTrigger.NONE


## A form (ABILITIES AB9): one at a time per unit.
func is_form() -> bool:
	return tags.has(&"form")


func is_shield() -> bool:
	return shield_amount > 0.0


func is_dot() -> bool:
	return tick_interval > 0.0 and (tick_damage > 0.0 or tick_ad_ratio > 0.0)
