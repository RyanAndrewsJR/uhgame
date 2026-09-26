class_name UnitStats
extends Resource
## Base stats for a champion or monster, in League of Legends units.
## Make one .tres per character in res://data/units/ and tweak it in the
## Inspector.

@export var display_name: String = "Unit"

@export_group("Defense")
@export var max_health: float = 600.0

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

@export_group("Abilities")
## Cooldown reduction, LoL style: cooldown * 100 / (100 + haste).
@export var ability_haste: float = 0.0

@export_group("Movement")
@export var move_speed: float = 345.0
## Used for ranges and clicking on the unit (LoL champions: 65).
@export var gameplay_radius: float = 65.0
## Physical size for collisions and pathing (LoL champions: 35).
@export var pathing_radius: float = 35.0
## Dash charges (STATS.md). Only units with a DashComponent use it.
@export_range(1, 5) var dash_charges: int = 1
