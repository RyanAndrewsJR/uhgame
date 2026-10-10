extends Ability
## The Riposte Stance (ARCHETYPES.md, Assassin: The enemy's layer; D4; built
## in ARCHETYPES AR3b): an enemy Assassin's deflect ability. Cast on itself
## with no cast time, it holds its stance (the blade across the body: the
## pose riposte_stance, Enemy.get_pose()) and opens its DeflectComponent's
## window for window_time s, standing still. A champion's deflectable hit
## inside it (a melee swing; never a projectile, an area, a DoT or an
## ultimate: DeflectComponent.try_deflect() reads HitContext.deflectable) is
## deflected. One hit per stance: the window closes, the champion is rebuffed
## and the riposte swings at once (DeflectComponent). A stun, a break or
## anything else that blocks casting closes it early. If it deflected
## nothing, its recovery follows (recovery_time: the player's opening); after
## a deflect, none (get_cast_recovery_time()).
## Its AI use (data): defend when its target closes in (Condition
## TARGET_CLOSED_IN), no token. Placeholders: the glint at its start
## (glint_vfx; null = a quick ring in glint_color), the pose
## (pose_set_default.tres).

## The move lock it holds while its window is open.
const STANCE_LOCK := &"riposte_stance"
## The cast's input that says it deflected (CastContext.set_input()).
const DEFLECTED_INPUT := &"deflected"

## Seconds its deflect window stays open.
@export var window_time: float = 0.5

@export_group("Presentation")
## At its start (VFX.spawn_scene(): setup(caster)); null = a ring in glint_color.
@export var glint_vfx: PackedScene
@export var glint_color: Color = Color(1, 1, 1, 1)


func execute(caster: Unit, ctx: CastContext) -> void:
	var deflect := caster.deflect_component
	if deflect == null or not deflect.is_active():
		return
	deflect.open_window(window_time)
	caster.movement.add_move_lock(STANCE_LOCK)
	caster.movement.stop()
	_play_glint(caster)
	var tree := caster.get_tree()
	while deflect.is_window_open():
		if caster.is_cast_blocked():
			deflect.close_window()   # a stun or a break cuts it short
			break
		await tree.physics_frame
		if not is_instance_valid(caster):
			return
	caster.movement.remove_move_lock(STANCE_LOCK)
	if deflect.get_window_deflects() > 0:
		ctx.set_input(DEFLECTED_INPUT, 1.0)


## No recovery after a deflect (its riposte swings at once); recovery_time
## after a whiff.
func get_cast_recovery_time(caster: Unit, ctx: CastContext) -> float:
	if ctx != null and ctx.get_input(DEFLECTED_INPUT) > 0.0:
		return 0.0
	return super(caster, ctx)


func _play_glint(caster: Unit) -> void:
	if glint_vfx != null:
		VFX.spawn_scene(glint_vfx, caster, caster.global_position, 0.0, [caster])
	elif glint_color.a > 0.0:
		VFX.ring(caster.get_parent(), caster.global_position, 6.0, 22.0, glint_color, 0.2)
