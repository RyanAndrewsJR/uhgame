extends Node2D
## Test-only presentation hook scene (ABILITIES AB14, abilities_test.gd):
## packed into a PackedScene in code and set as a cast_vfx / impact_vfx /
## swing_vfx. Each spawned copy joins GROUP and keeps what setup() got, so
## the test can count the spawns and check their arguments, position and
## rotation. The test frees them.

const GROUP := &"ab14_hook_probe"

## setup()'s arguments: [caster or attacker, CastContext / HitContext / AttackSwing].
var args: Array = []


func _enter_tree() -> void:
	add_to_group(GROUP)


func setup(a: Variant = null, b: Variant = null) -> void:
	args = [a, b]
