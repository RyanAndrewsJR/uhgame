extends Ability
## Knight W - Iron Resolve: a burst of movement speed, and your next
## auto-attack within a few seconds deals bonus damage and slows.
## (base_damage / ad_ratio are the bonus damage on the empowered attack.)
## Toolkit pieces (ABILITIES AB11): the speed is a haste status on the Knight
## (status "iron_resolve"); the bonus is a basic attack empower status
## ("empower_iron_resolve": the bonus snapshotted at cast, used up by the next
## swing that hits, added to every enemy it hits so it crits with the swing)
## whose empower_statuses carry the slow ("iron_resolve_slow"). The numbers
## stay here, so the tooltip reads them. Its per-enemy feel and VFX are its
## own, through AutoAttackComponent.set_empower_on_hit().

const STATUS_HASTE: StatusEffect = preload("res://data/statuses/status_haste.tres")
const STATUS_SLOW: StatusEffect = preload("res://data/statuses/status_slow.tres")

@export var move_speed_bonus: float = 0.35
@export var move_speed_duration: float = 2.0
@export var empower_window: float = 4.0
@export var slow_amount: float = 0.4
@export var slow_duration: float = 1.5


func execute(caster: Unit, _ctx: CastContext) -> void:
	var statuses := caster.status_component
	if statuses == null:
		return
	statuses.apply_status(_speed_status(STATUS_HASTE, &"iron_resolve", move_speed_bonus, move_speed_duration), caster)

	var empower := StatusEffect.new()
	empower.id = AutoAttackComponent.get_empower_status_id(&"iron_resolve")
	empower.display_name = "iron_resolve"
	empower.tags = [&"empower", &"buff"]
	empower.duration = empower_window
	empower.stack_rule = StatusEffect.StackRule.REFRESH   # recasting replaces it
	empower.empower_consumed_by = StatusEffect.EmpowerTrigger.BASIC_ATTACK_HIT
	empower.empower_base_damage = get_damage(caster)   # snapshotted at cast
	empower.empower_statuses = [_speed_status(STATUS_SLOW, &"iron_resolve_slow", -slow_amount, slow_duration)]
	if not statuses.apply_status(empower, caster):
		return

	var col := icon_color
	var on_hit := func(target: Unit) -> void:
		VFX.impact(target.get_parent(), target.global_position, Color(col, 0.9), 50.0, 0.25)
		VFX.ring(target.get_parent(), target.global_position, 6.0, 26.0, col, 0.3)
		GameFeel.shake(2.5)
		GameFeel.hitstop(0.04)
	caster.attack.set_empower_on_hit(empower.id, on_hit)
	VFX.ring(caster.get_parent(), caster.global_position, 8.0, 30.0, icon_color, 0.35)
	var empower_id := empower.id
	VFX.aura(caster, icon_color, func() -> bool: return statuses.has_status(empower_id), empower_window + 0.1)


## A move speed status from `template` (status_haste / status_slow: their
## tags, sounds and VFX): `percent` move_speed PERCENT_ADD for `duration` s,
## refreshed by a recast. The same status MovementComponent's speed wrapper
## builds, so the numbers and ids are unchanged.
func _speed_status(template: StatusEffect, id: StringName, percent: float, duration: float) -> StatusEffect:
	var effect: StatusEffect = template.duplicate()
	effect.id = id
	effect.display_name = String(id)
	effect.duration = duration
	effect.stack_rule = StatusEffect.StackRule.REFRESH
	var mods: Array[StatModifier] = [StatModifier.create(&"move_speed", StatModifier.Type.PERCENT_ADD, percent, &"")]
	effect.modifiers = mods
	return effect
