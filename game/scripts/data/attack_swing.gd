class_name AttackSwing
extends Resource
## One swing of a basic attack combo (COMBAT.md, Data). Timings are at base
## attack speed; AutoAttackComponent divides them by the combo speed
## (attack_speed / base attack speed).

## Seconds from the click to the hit.
@export var windup: float = 0.08
## Seconds the whole swing lasts (windup + recovery). The attacker is rooted
## for all of it.
@export var duration: float = 0.3
## Damage as a fraction of attack_damage.
@export var ad_ratio: float = 1.0
## Reach as a multiple of the attacker's attack_range stat, measured from the
## attacker's feet to the target's edge.
@export var reach_multiplier: float = 1.0
## Width of the swing, in degrees (centered on the aim).
@export var arc_deg: float = 110.0
## Push distance in px, over knockback_duration (knockback curve).
@export var knockback_px: float = 6.0
@export var knockback_duration: float = 0.1
## Hit feel tier (COMBAT C3): LIGHT for normal swings, HEAVY for finishers.
@export var feel: HitContext.Feel = HitContext.Feel.LIGHT
## Forward step at the hit, in px (dash-strike, COMBAT C12). 0 = none.
@export var lunge_px: float = 0.0
## Scales on-hit chances and effects (COMBAT C8).
@export var proc_coefficient: float = 1.0
