extends Ability
## Test ability (ABILITIES AB7, champion "test"): fires a bolt (the shared
## Projectile) along the aim. Stops on the first enemy (projectile_pierce 0)
## and at walls. Used by abilities_test and, through SandboxAbilities.test_q,
## in the sandbox. Not part of any kit.


func execute(caster: Unit, ctx: CastContext) -> void:
	Projectile.fire(caster, self, ctx, caster.global_position, ctx.direction)
