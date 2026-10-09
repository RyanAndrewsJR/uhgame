class_name PoiseRules
extends Resource
## The poise meter's numbers in one file (ARCHETYPES.md, Data: PoiseRules;
## D1, D3b, D8), the way CrowdControlRules holds diminishing returns'. Since
## AR3a the meter fills up to a break (PoiseComponent): poise damage raises
## it, at its maximum the unit breaks, and after decay_delay s with no poise
## hit it decays back toward 0. A meter's size and its break time come from
## its rank (RankRules.poise_meter_max, poise_break_time) or its EnemyData.
## An archetype with a meter names its file (Archetype.poise_rules); the
## prototype's meters (the elite slime's and the test duelist's, until AR6)
## read poise_rules_assassin.tres too. Files:
## res://data/poise_rules/poise_rules_<name>.tres. The champion's numbers
## (her meter's fills, her break) come with AR5.

## Seconds with no poise hit before it starts to decay.
@export_range(0.0, 30.0, 0.1) var decay_delay: float = 3.0
## Poise per second it loses while it decays.
@export_range(0.0, 200.0, 1.0) var decay_rate: float = 15.0
## Below this share of its max health it decays slower (D1).
@export_range(0.0, 1.0, 0.05) var low_health: float = 0.4
## × decay_rate below low_health (D1's proposed 0.5: half as fast).
@export_range(0.0, 2.0, 0.05) var low_health_decay_scale: float = 0.5
## Extra damage taken while broken: 0.5 = ×1.5 (an incoming_damage
## PERCENT_MULT on its status_poise_broken copy).
@export_range(0.0, 3.0, 0.05) var break_damage_bonus: float = 0.5
## Seconds after a break during which poise damage does nothing.
@export_range(0.0, 30.0, 0.5) var break_immunity: float = 4.0
