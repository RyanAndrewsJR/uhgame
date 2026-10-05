extends Ability
## Test caster W - Guard (ENEMIES_AI AI3): a shield on itself, shield_amount
## for shield_duration (a status_shield copy), with a ring. Its only AI use is
## `defend` with the rule THREATENED: it goes up when the caster sees an
## attack coming at it (after its reaction time), never "just because"
## (ENEMIES_AI.md, Intents). Baiting it out first opens the caster. Not part
## of any kit.

const STATUS_SHIELD: StatusEffect = preload("res://data/statuses/status_shield.tres")

## The damage it absorbs.
@export var shield_amount: float = 150.0
## How long it lasts unbroken, s.
@export var shield_duration: float = 3.0


func execute(caster: Unit, _ctx: CastContext) -> void:
	if caster.status_component == null:
		return
	var shield: StatusEffect = STATUS_SHIELD.duplicate()
	shield.shield_amount = shield_amount
	shield.duration = shield_duration
	caster.status_component.apply_status(shield, caster)
	VFX.ring(caster.get_parent(), caster.global_position, 8.0, 30.0, icon_color, 0.35)
