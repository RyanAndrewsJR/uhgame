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
## STACK only.
@export var max_stacks: int = 1

@export_group("Stats")
## Added while active (under get_source_id()), once per stack. Slows and
## hastes are move_speed PERCENT_ADD modifiers.
@export var modifiers: Array[StatModifier] = []

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

@export_group("Visuals")
## Instanced as a child of the unit while the status is active. Visuals only.
@export var vfx: PackedScene


## The source id its StatModifiers use: &"status_<id>" (CONVENTIONS.md).
func get_source_id() -> StringName:
	return StringName("status_" + id)


## Crowd control: tenacity shortens it.
func is_cc() -> bool:
	return tags.has(&"cc")


func is_dot() -> bool:
	return tick_interval > 0.0 and (tick_damage > 0.0 or tick_ad_ratio > 0.0)
