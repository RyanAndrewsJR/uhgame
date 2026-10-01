class_name Talent
extends ToolkitBundle
## One talent (TALENTS.md): a per-champion choice set at the hub that reshapes
## one of the champion's abilities or its passive. The same bundle a passive is
## (ToolkitBundle), attached under talent_<id>. Files:
## res://data/talents/talent_<champion>_<name>.tres, listed in
## ChampionData.talents.
##
## Groups are islands: a Q / W / E / R talent's pieces are all scoped to its
## group's ability, a PASSIVE talent's to the passive's theme, and no talent
## ever carries a REPLACE. get_validation_errors() enforces it; the Player
## skips a talent that fails it.

enum Group { Q, W, E, R, PASSIVE }

const GROUP_SLOTS := {Group.Q: &"q", Group.W: &"w", Group.E: &"e", Group.R: &"r"}

## <champion>_<name> (&"knight_long_reach"). Source id: talent_<id>.
@export var id: StringName = &""
## Which ability (or the passive) it belongs to and may touch.
@export var group: Group = Group.Q
## Its depth in the group: 1, 2, ... A tier N talent needs a tier N - 1 talent
## of its group in the loadout (the tier rule; enforced by the loadout, T4).
@export_range(1, 9) var tier: int = 1
## Excludes its siblings (same group and tier) from the loadout.
@export var exclusive: bool = true
## All must be met to unlock; empty = unlocked from the start.
@export var requirements: Array[TalentRequirement] = []
## PASSIVE only (Replace and add): while this talent is active, the champion's
## passive attaches without its own modifiers and StatScalings on these stats.
## The talent's own pieces always attach. Empty = add only.
@export var replaces_passive_stats: Array[StringName] = []
## Q / W / E / R only (TALENTS T3b): while this talent is active, its group's
## ability shows this tooltip template instead of its own description (the
## same {placeholders}), and this talent's own augment lines are left out (the
## text already says it). For talents that change what the ability does, so
## the tooltip never describes a part the talent traded away. Empty = the
## ability's own text.
@export_multiline var ability_description: String = ""


## Puts ability_description on the group's ability (the slot's own ability:
## a REPLACE variant keeps its text).
func _on_added(unit: Unit, source_id: StringName) -> void:
	if ability_description == "" or group == Group.PASSIVE or unit.abilities == null:
		return
	var ability := unit.abilities.get_base_ability(get_group_slot())
	if ability != null:
		unit.abilities.set_description_override(ability.id, ability_description, source_id)


func _on_removed(unit: Unit, source_id: StringName) -> void:
	if unit.abilities != null:
		unit.abilities.remove_description_overrides_from(source_id)


## The source id its pieces go under: talent_<id>.
func get_source_id() -> StringName:
	return StringName("talent_%s" % id)


## The ability slot of its group (&"q"...), or &"" for PASSIVE.
func get_group_slot() -> StringName:
	return GROUP_SLOTS.get(group, &"")


## The ability its group is about, from the champion's slots (null for PASSIVE).
func get_group_ability(champion: ChampionData) -> Ability:
	if champion == null:
		return null
	match group:
		Group.Q:
			return champion.q
		Group.W:
			return champion.w
		Group.E:
			return champion.e
		Group.R:
			return champion.r
	return null


## Siblings: same group and tier (not the talent itself).
func is_sibling_of(other: Talent) -> bool:
	return other != null and other != self and other.group == group and other.tier == tier


## Every broken rule (TALENTS.md, What a talent can change); empty = valid.
func get_validation_errors(champion: ChampionData) -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"":
		errors.append("no id")
	if champion == null:
		errors.append("no champion to check against")
		return errors
	for req in requirements:
		if req == null:
			errors.append("an empty requirement")
			continue
		var req_error := req.get_validation_error(self)
		if req_error != "":
			errors.append(req_error)
	if group == Group.PASSIVE:
		_validate_passive(champion, errors)
	else:
		_validate_ability(champion, errors)
	return errors


func _validate_ability(champion: ChampionData, errors: PackedStringArray) -> void:
	var ability := get_group_ability(champion)
	if ability == null:
		errors.append("the champion has no ability in its group's slot (%s)" % get_group_slot())
		return
	var scope := StringName("ability:%s" % ability.id)
	for mod in modifiers:
		if mod != null and mod.scope != scope:
			errors.append("modifier on %s is scoped '%s', not '%s'" % [mod.stat, mod.scope, scope])
	for scaling in stat_scalings:
		if scaling == null or scaling.modifier == null:
			errors.append("a StatScaling without a modifier")
		elif scaling.modifier.scope != scope:
			errors.append("StatScaling on %s is scoped '%s', not '%s'" % [scaling.modifier.stat, scaling.modifier.scope, scope])
	for rule_res in reaction_rules:
		var rule := rule_res as ReactionRule
		if rule != null and rule.required_ability_scope != scope:
			errors.append("reaction rule '%s' has required_ability_scope '%s', not '%s'" % [rule.id, rule.required_ability_scope, scope])
	for aug_res in augments:
		var aug := aug_res as AbilityAugment
		if aug == null:
			continue
		if aug.kind == AbilityAugment.Kind.REPLACE:
			errors.append("augment '%s' is a REPLACE (talents never replace; items do)" % aug.id)
		if aug.scope != scope:
			errors.append("augment '%s' is scoped '%s', not '%s'" % [aug.id, aug.scope, scope])
		if aug.kind == AbilityAugment.Kind.FLAG and not ability.supported_flags.has(aug.id):
			errors.append("FLAG '%s' isn't in %s's supported_flags" % [aug.id, ability.id])
		if aug.kind == AbilityAugment.Kind.EVENT:
			for rule in aug.rules:
				if rule != null and rule.required_ability_scope != &"" and rule.required_ability_scope != scope:
					errors.append("augment '%s' rule '%s' is scoped '%s', not '%s'" % [aug.id, rule.id, rule.required_ability_scope, scope])
	if not statuses.is_empty():
		errors.append("always-on statuses in a %s talent (they aren't about one ability)" % Group.keys()[group])
	if not replaces_passive_stats.is_empty():
		errors.append("replaces_passive_stats outside the PASSIVE group")


func _validate_passive(champion: ChampionData, errors: PackedStringArray) -> void:
	if champion.passive == null:
		errors.append("a PASSIVE talent on a champion with no passive")
		return
	for mod in modifiers:
		if mod != null and _reaches_abilities(mod.scope):
			errors.append("modifier on %s is scoped '%s' (a PASSIVE talent can't reach into Q/W/E/R)" % [mod.stat, mod.scope])
	for scaling in stat_scalings:
		if scaling == null or scaling.modifier == null:
			errors.append("a StatScaling without a modifier")
		elif _reaches_abilities(scaling.modifier.scope):
			errors.append("StatScaling on %s is scoped '%s' (a PASSIVE talent can't reach into Q/W/E/R)" % [scaling.modifier.stat, scaling.modifier.scope])
	for rule_res in reaction_rules:
		var rule := rule_res as ReactionRule
		if rule != null and rule.required_ability_scope != &"":
			errors.append("reaction rule '%s' is scoped to '%s' (a PASSIVE talent can't reach into Q/W/E/R)" % [rule.id, rule.required_ability_scope])
	if not augments.is_empty():
		errors.append("augments in a PASSIVE talent (augments change abilities)")
	if ability_description != "":
		errors.append("ability_description in a PASSIVE talent (the passive's text is its own)")
	var passive_stats := champion.passive.get_stats()
	for stat in replaces_passive_stats:
		if not passive_stats.has(stat):
			errors.append("replaces '%s', which the passive doesn't have" % stat)


static func _reaches_abilities(scope: StringName) -> bool:
	var s := String(scope)
	return s.begins_with("ability:") or s.begins_with("tag:")
