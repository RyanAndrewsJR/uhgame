class_name AttackCombo
extends Resource
## A basic attack combo: the swings in order (the last one is the finisher)
## and when it resets (COMBAT.md, Data). Set it on AutoAttackComponent.combo;
## null there keeps the League-style attack (enemies).

## MELEE: every swing steps forward and pulls toward an aimed enemy, with an
## aim snap (COMBAT.md, Melee basic attacks). RANGED: none of that (ranged
## basic attacks are designed later).
enum AttackStyle { MELEE, RANGED }

@export var attack_style: AttackStyle = AttackStyle.MELEE

@export var swings: Array[AttackSwing] = []
## Seconds without attacking, counted from the end of a swing, before the
## next attack starts again from the first swing.
@export var combo_reset_time: float = 0.6
## The stronger swing for an attack right after a dash (COMBAT C12). null =
## dash-strikes use the normal next swing.
@export var dash_strike: AttackSwing
## Player attacks hit a bit beyond what they show: reach and arc x (1 + this).
@export_range(0.0, 0.2) var hit_forgiveness: float = 0.10

@export_group("Melee assist")
## An enemy counts as aimed at if its edge is within the swing's reach plus
## this many px of the attacker's feet...
@export_range(0.0, 64.0) var assist_range_bonus_px: float = 40.0
## ...and within this many degrees of the aim.
@export_range(0.0, 45.0) var assist_angle_deg: float = 35.0
## The swing's aim turns toward the aimed enemy by up to this many degrees.
@export_range(0.0, 30.0) var assist_snap_deg: float = 20.0
## The pull steps until the aimed enemy's edge is this fraction of the reach
## away (capped by the swing's lunge_max_px).
@export_range(0.5, 0.9) var stop_at_reach_fraction: float = 0.7

@export_group("Recovery")
## After a swing's hit, moving ends the rest of its root (melee and ranged).
## The next swing still waits for the swing's full duration.
@export var walk_cancels_recovery: bool = true
## Seconds after the hit before moving can end the root.
@export_range(0.0, 0.2) var recovery_move_cancel_after: float = 0.1
