class_name UnitStats
extends Resource
## Base stats for a champion or monster, in League of Legends units.
## Make one .tres per character in res://data/units/ and tweak it in the
## Inspector.
##
## These are base values only; the live values (base + modifiers) come from
## the unit's StatsComponent (STATS.md). Stats added in STATS step 5 default
## to a neutral value (no regen, no armor, no crit...), so a unit only gets
## them when its .tres sets them.

@export_group("Defense")
@export var max_health: float = 600.0
## Health per second.
@export var health_regen: float = 0.0
## Mitigation formula in COMBAT.md.
@export var armor: float = 0.0
@export var magic_resist: float = 0.0
## Reduces crowd control duration, 0-0.8.
@export var tenacity: float = 0.0
## Multiplier on damage after armor / magic_resist (COMBAT C8). 1 = normal;
## reductions are negative PERCENT_MULT modifiers, so they multiply.
@export var incoming_damage: float = 1.0

@export_group("Resource")
## Mana, energy or fury (the type is on the ResourceComponent for now).
## 0 for units without a resource.
@export var max_resource: float = 0.0
## Resource per second.
@export var resource_regen: float = 0.0

@export_group("Attack")
@export var attack_damage: float = 60.0
## Edge-to-edge range, like LoL (melee is usually 125-175, ranged 500-650).
@export var attack_range: float = 175.0
## Attacks per second at 0% bonus attack speed.
@export var base_attack_speed: float = 0.65
## Fraction of each attack spent winding up before the hit lands.
## Moving during the windup cancels the attack.
@export_range(0.05, 0.9) var attack_windup: float = 0.25
## Max attack speed, LoL caps at 2.5.
@export var attack_speed_cap: float = 2.5
## Chance to crit, 0-1.
@export var crit_chance: float = 0.0
## Damage multiplier on a crit. 1.75 for every unit (COMBAT.md); nothing
## changes in play while crit_chance is 0.
@export var crit_damage: float = 1.75
## Fraction of damage dealt healed back, 0-1. Basic attacks only (COMBAT C8).
@export var life_steal: float = 0.0
## "Increased" damage: 0.2 = +20%. Items give it as FLAT modifiers, often
## scoped to hit tags (&"hit:basic_attack") or target tags
## (&"target:stun"). COMBAT C8.
@export var damage_increase: float = 0.0
## Extra damage (a proc hit) on every basic attack and ability hit, x the
## hit's proc_coefficient. COMBAT C8.
@export var on_hit_damage: float = 0.0
## Health per basic attack or ability hit, x proc_coefficient. COMBAT C8.
@export var life_on_hit: float = 0.0
## Resource (mana...) per basic attack or ability hit, x proc_coefficient.
@export var resource_on_hit: float = 0.0

@export_group("Abilities")
## Cooldown reduction, LoL style: cooldown * 100 / (100 + haste).
@export var ability_haste: float = 0.0
@export var ability_power: float = 0.0

@export_group("Movement")
@export var move_speed: float = 345.0
## Used for ranges and clicking on the unit (LoL champions: 65).
@export var gameplay_radius: float = 65.0
## Physical size for collisions and pathing (LoL champions: 35).
@export var pathing_radius: float = 35.0
## Dash charges (STATS.md). Only units with a DashComponent use it.
@export_range(1, 5) var dash_charges: int = 1

@export_group("Loot")
## LoL units (200 = 64 px). LOOT.md.
@export var pickup_radius: float = 0.0
@export var magic_find: float = 0.0
@export var gold_find: float = 0.0
