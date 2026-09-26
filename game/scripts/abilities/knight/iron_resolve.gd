extends Ability
## Knight W - Iron Resolve: a burst of movement speed, and your next
## auto-attack within a few seconds deals bonus damage and slows.
## (base_damage / ad_ratio are the bonus damage on the empowered attack.)

@export var move_speed_bonus: float = 0.35
@export var move_speed_duration: float = 2.0
@export var empower_window: float = 4.0
@export var slow_amount: float = 0.4
@export var slow_duration: float = 1.5


func execute(caster: Unit, _ctx: CastContext) -> void:
	caster.movement.add_speed_modifier(&"iron_resolve", 0.0, move_speed_bonus, move_speed_duration)
	var slow := slow_amount
	var slow_time := slow_duration
	var col := icon_color
	var on_hit := func(target: Unit) -> void:
		target.movement.add_speed_modifier(&"iron_resolve_slow", 0.0, -slow, slow_time)
		VFX.impact(target.get_parent(), target.global_position, Color(col, 0.9), 50.0, 0.25)
		VFX.ring(target.get_parent(), target.global_position, 6.0, 26.0, col, 0.3)
		GameFeel.shake(2.5)
		GameFeel.hitstop(0.04)
	caster.attack.add_next_attack_modifier(&"iron_resolve", get_damage(caster), on_hit, empower_window)
	VFX.ring(caster.get_parent(), caster.global_position, 8.0, 30.0, icon_color, 0.35)
	VFX.aura(caster, icon_color, func() -> bool: return caster.attack.has_next_attack_modifier(&"iron_resolve"), empower_window + 0.1)
