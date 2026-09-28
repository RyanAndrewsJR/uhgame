class_name ModifyCooldownGameplayEffect
extends GameplayEffect
## Changes the cooldowns of the target's matching slots (ABILITIES AB8): League
## kill resets, Diablo "cooldown reduced when…". Only a running cooldown
## (recharge) changes: while a recast window is open (the cooldown hasn't
## started) it does nothing.

enum Mode {
	REDUCE_SECONDS,  ## Takes `amount` seconds off the time left.
	REDUCE_PERCENT,  ## Takes `amount` (0.25 = 25%) of the time left.
	RESET,           ## Finishes the current recharge: +1 charge (with 1 charge: ready).
}

## Which slots: &"ability:<id>" / &"tag:<tag>" (matched against each slot's
## ability), or &"" for every slot.
@export var ability_scope: StringName = &""
@export var mode: Mode = Mode.REDUCE_SECONDS
## Seconds (REDUCE_SECONDS) or a fraction of the time left (REDUCE_PERCENT).
@export var amount: float = 1.0


func apply(target: Unit, _source: Unit, _trigger_ctx: RefCounted) -> void:
	if not is_instance_valid(target) or target.abilities == null:
		return
	var abilities := target.abilities
	for slot in abilities.get_slots_matching(ability_scope):
		match mode:
			Mode.REDUCE_SECONDS:
				abilities.reduce_cooldown(slot, amount)
			Mode.REDUCE_PERCENT:
				abilities.reduce_cooldown_percent(slot, amount)
			Mode.RESET:
				abilities.reset_cooldown(slot)
