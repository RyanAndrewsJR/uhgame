extends Passive
## Korsavil v2's passive (CHAMPIONS.md, Korsavil v2, Passive; built in K3).
## Its pieces are data: the unit rule reaction_korsavil_demise (swing 4's hit
## gives 2 stacks of Inevitable Demise, status_demise, once every 5 s) and the
## statuses it applies. This script is the one-off the rules can't do: it
## watches his Demise count and acts when it crosses a line from below.
## - 4 or more: the empowered auto (empower_demise; it spends no stacks).
## - 6: Q's sweep window (sweep_status; K5, null until then).
## The Passive resource is shared by every unit loaded from the ChampionData,
## so the per-unit state (the count last seen, the connection) lives on the
## unit as meta, never on this resource.

## His stacks (status_demise).
@export var demise_status: StatusEffect
## Applied when the stacks go from under empower_at to empower_at or more.
@export var empower_status: StatusEffect
@export var empower_at: int = 4
## K5: applied when the stacks reach sweep_at. null = nothing (until K5).
@export var sweep_status: StatusEffect
@export var sweep_at: int = 6

const SEEN_META := &"korsavil_demise_seen"
const CALLABLE_META := &"korsavil_demise_watch"


func _on_added(unit: Unit, _source_id: StringName) -> void:
	if unit.status_component == null or demise_status == null:
		return
	if unit.has_meta(CALLABLE_META):
		return   # already watching (attached twice under another id)
	unit.set_meta(SEEN_META, unit.status_component.get_stacks(demise_status.id))
	var watch := _on_status_changed.bind(unit)
	unit.set_meta(CALLABLE_META, watch)
	unit.status_component.status_applied.connect(watch)
	unit.status_component.status_removed.connect(watch)


func _on_removed(unit: Unit, _source_id: StringName) -> void:
	if unit.status_component != null and unit.has_meta(CALLABLE_META):
		var watch: Callable = unit.get_meta(CALLABLE_META)
		if unit.status_component.status_applied.is_connected(watch):
			unit.status_component.status_applied.disconnect(watch)
		if unit.status_component.status_removed.is_connected(watch):
			unit.status_component.status_removed.disconnect(watch)
		# What the passive gave goes with it: the unit is restored exactly.
		for status in [demise_status, empower_status, sweep_status]:
			if status != null:
				unit.status_component.remove_status((status as StatusEffect).id)
	unit.remove_meta(CALLABLE_META)
	unit.remove_meta(SEEN_META)


func _on_status_changed(effect: StatusEffect, unit: Unit) -> void:
	if effect == null or demise_status == null or effect.id != demise_status.id:
		return
	if not is_instance_valid(unit) or unit.status_component == null:
		return
	var now := unit.status_component.get_stacks(demise_status.id)
	var before: int = unit.get_meta(SEEN_META, 0)
	unit.set_meta(SEEN_META, now)
	if empower_status != null and before < empower_at and now >= empower_at:
		unit.status_component.apply_status(empower_status, unit)
	if sweep_status != null and before < sweep_at and now >= sweep_at:
		unit.status_component.apply_status(sweep_status, unit)
