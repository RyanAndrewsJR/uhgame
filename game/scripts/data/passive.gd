class_name Passive
extends Resource
## A champion's passive (CHAMPIONS.md, Passives): a bundle of toolkit pieces
## attached under one source id (passive_<champion id>) when the champion
## loads, and removed by it, exactly as an item or an augment source attaches
## its pieces. Inline in the champion's ChampionData.
##
## For anything truly one-off, extend it and override _on_added() /
## _on_removed() (res://scripts/abilities/<champion>/<passive>.gd).

## The tooltip (where it shows is UI.md's).
@export var display_name: String = ""
@export_multiline var description: String = ""
## Added under the passive's source id (copies; the originals are untouched).
@export var modifiers: Array[StatModifier] = []
## Stat modifiers that follow an input (Unit.add_stat_scaling()).
@export var stat_scalings: Array[StatScaling] = []
## Unit rules (ReactionRule). Typed as Resource like StatusEffect.reaction_rules,
## to stay out of the preload cycle.
@export var reaction_rules: Array[Resource] = []
## StatusEffects applied from the unit itself; a passive's status has
## duration -1 (until removed).
@export var statuses: Array[Resource] = []
## AbilityAugments added to the AbilityComponent.
@export var augments: Array[Resource] = []


## Attaches every piece to `unit` under `source_id`.
func apply_to(unit: Unit, source_id: StringName) -> void:
	var copies: Array[StatModifier] = []
	for mod in modifiers:
		if mod != null:
			var copy: StatModifier = mod.duplicate()
			copy.source_id = source_id
			copies.append(copy)
	if not copies.is_empty():
		unit.stats_component.add_modifiers(copies)
	for scaling in stat_scalings:
		unit.add_stat_scaling(scaling, source_id)
	for rule in reaction_rules:
		unit.add_reaction_rule(rule as ReactionRule, source_id)
	if not statuses.is_empty():
		if unit.status_component == null:
			push_error("Passive '%s': %s has no StatusComponent, its statuses are skipped" % [display_name, unit.name])
		else:
			for status in statuses:
				unit.status_component.apply_status(status as StatusEffect, unit)
	if not augments.is_empty():
		if unit.abilities == null:
			push_error("Passive '%s': %s has no AbilityComponent, its augments are skipped" % [display_name, unit.name])
		else:
			for augment in augments:
				unit.abilities.add_augment(augment as AbilityAugment, source_id)
	_on_added(unit, source_id)


## Removes every piece added under `source_id`; the unit is restored exactly.
func remove_from(unit: Unit, source_id: StringName) -> void:
	unit.stats_component.remove_modifiers_from(source_id)
	unit.remove_stat_scalings_from(source_id)
	unit.remove_reaction_rules_from(source_id)
	if unit.status_component != null:
		for status in statuses:
			if status != null:
				unit.status_component.remove_status((status as StatusEffect).id)
	if unit.abilities != null:
		unit.abilities.remove_augments_from(source_id)
	_on_removed(unit, source_id)


## Override for a one-off passive script; runs after the pieces are attached.
func _on_added(_unit: Unit, _source_id: StringName) -> void:
	pass


## Override for a one-off passive script; runs after the pieces are removed.
func _on_removed(_unit: Unit, _source_id: StringName) -> void:
	pass
