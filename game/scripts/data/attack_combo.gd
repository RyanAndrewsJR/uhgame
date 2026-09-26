class_name AttackCombo
extends Resource
## A basic attack combo: the swings in order (the last one is the finisher)
## and when it resets (COMBAT.md, Data). Set it on AutoAttackComponent.combo;
## null there keeps the League-style attack (enemies).

@export var swings: Array[AttackSwing] = []
## Seconds without attacking, counted from the end of a swing, before the
## next attack starts again from the first swing.
@export var combo_reset_time: float = 0.6
## The stronger swing for an attack right after a dash (COMBAT C12). null =
## dash-strikes use the normal next swing.
@export var dash_strike: AttackSwing
## Player attacks hit a bit beyond what they show: reach and arc x (1 + this).
@export_range(0.0, 0.2) var hit_forgiveness: float = 0.10
