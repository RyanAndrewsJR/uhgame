class_name ToolkitBundle
extends Resource
## A bundle of toolkit pieces attached to a unit under one source id, and
## removed by it, exactly as an item or an augment source attaches its pieces.
## The shared base of Passive (CHAMPIONS.md, Passives) and Talent (TALENTS.md);
## moved out of passive.gd in TALENTS T1 (Ryan, 2026-09-30) with the same
## field names, so every .tres that held a Passive loads unchanged.
##
## For anything truly one-off, extend a subclass and override _on_added() /
## _on_removed().

## The tooltip (where it shows is UI.md's).
@export var display_name: String = ""
@export_multiline var description: String = ""
## The HUD's placeholder slot color (CHAMPIONS CH6; the art pass gives it an icon).
@export var icon_color: Color = Color(0.6, 0.6, 0.65)
## Added under the bundle's source id (copies; the originals are untouched).
@export var modifiers: Array[StatModifier] = []
## Stat modifiers that follow an input (Unit.add_stat_scaling()).
@export var stat_scalings: Array[StatScaling] = []
## Unit rules (ReactionRule). Typed as Resource like StatusEffect.reaction_rules,
## to stay out of the preload cycle.
@export var reaction_rules: Array[Resource] = []
## StatusEffects applied from the unit itself; a bundle's status has
## duration -1 (until removed).
@export var statuses: Array[Resource] = []
## AbilityAugments added to the AbilityComponent.
@export var augments: Array[Resource] = []


## Attaches every piece to `unit` under `source_id`. Modifiers and
## StatScalings on a stat listed in `left_out_stats` aren't added (TALENTS.md,
## Replace and add: a talent replacing the passive's own bonus on that stat).
## The default leaves nothing out.
func apply_to(unit: Unit, source_id: StringName, left_out_stats: Array[StringName] = []) -> void:
	var copies: Array[StatModifier] = []
	for mod in modifiers:
		if mod != null and not left_out_stats.has(mod.stat):
			var copy: StatModifier = mod.duplicate()
			copy.source_id = source_id
			copies.append(copy)
	if not copies.is_empty():
		unit.stats_component.add_modifiers(copies)
	for scaling in stat_scalings:
		if scaling != null and scaling.modifier != null and left_out_stats.has(scaling.modifier.stat):
			continue
		unit.add_stat_scaling(scaling, source_id)
	for rule in reaction_rules:
		unit.add_reaction_rule(rule as ReactionRule, source_id)
	if not statuses.is_empty():
		if unit.status_component == null:
			push_error("'%s': %s has no StatusComponent, its statuses are skipped" % [display_name, unit.name])
		else:
			for status in statuses:
				unit.status_component.apply_status(status as StatusEffect, unit)
	if not augments.is_empty():
		if unit.abilities == null:
			push_error("'%s': %s has no AbilityComponent, its augments are skipped" % [display_name, unit.name])
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


## The stats this bundle's own modifiers and StatScalings change.
func get_stats() -> Array[StringName]:
	var out: Array[StringName] = []
	for mod in modifiers:
		if mod != null and not out.has(mod.stat):
			out.append(mod.stat)
	for scaling in stat_scalings:
		if scaling != null and scaling.modifier != null and not out.has(scaling.modifier.stat):
			out.append(scaling.modifier.stat)
	return out


## Override for a one-off script; runs after the pieces are attached.
func _on_added(_unit: Unit, _source_id: StringName) -> void:
	pass


## Override for a one-off script; runs after the pieces are removed.
func _on_removed(_unit: Unit, _source_id: StringName) -> void:
	pass
