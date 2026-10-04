class_name AbilityAugment
extends Resource
## A change to an ability's behavior, granted by a source (an item, a
## passive, a status) and added / removed by that source's id
## (AbilityComponent.add_augment(augment, source_id)). ABILITIES.md, Augments;
## built in AB8. Files: res://data/augments/augment_<name>.tres.
##
## - FLAG: the ability's script checks it (CastContext.has_flag(id)); the
##   ability must list it in supported_flags.
## - EVENT: extra reaction rules (on cast / hit / kill...) while it's active.
## - REPLACE: the slot casts `replacement` (a variant) instead.
## The same augment id from several sources counts once. Augments are read at
## cast start: removing one mid-cast doesn't change that cast.

enum Kind { FLAG, EVENT, REPLACE }

## e.g. &"lunge_stuns". For FLAG it's the flag the script checks. Two sources
## with the same id are one augment.
@export var id: StringName = &""
@export var kind: Kind = Kind.FLAG
## Which abilities it changes: &"ability:<id>" or &"tag:<tag>" (the scoped
## modifier strings). REPLACE needs an &"ability:<id>" scope.
@export var scope: StringName = &""
## EVENT: added as unit rules on the owner while active (one copy per augment
## id; a rule with an empty required_ability_scope gets `scope`).
@export var rules: Array[ReactionRule] = []
## REPLACE: the variant the slot casts (its variant_of should be the replaced
## ability's id, so the base's scoped modifiers reach it).
@export var replacement: Ability
@export var display_name: String = ""
## The tooltip line ("Lunge stuns for 0.5 s.").
@export_multiline var description: String = ""
## A sigil's part of an item's name (LOOT.md, The sigil pool; LOOT L4):
## "Storms" makes "Iron Helm of Storms". Empty for every other augment.
@export var name_suffix: String = ""


## The source id its EVENT rules are added under on the unit.
func get_rules_source_id() -> StringName:
	return StringName("augment_" + id)


## The tooltip text: description, else the display name, else the id.
func get_tooltip_line() -> String:
	if description != "":
		return description
	return display_name if display_name != "" else String(id)
