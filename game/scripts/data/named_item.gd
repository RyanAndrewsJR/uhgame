class_name NamedItem
extends Resource
## A fixed item with its own name (LOOT.md, Ability augments: Legendary and
## Artifact; LOOT L5): one champion's, with a base, a fixed list of affixes
## (rolled in the Legendary band, or at their maximum for an Artifact), fixed
## modifiers that may be scoped to its own ability, and exactly one ability
## augment (FLAG or REPLACE) on one of its champion's abilities. Files:
## res://data/items/item_<champion>_<name>.tres, listed in
## ChampionData.named_items. A rolled Item points at it (Item.named).
##
## Its affixes ignore the affix pool's slot lists: they're authored for the
## item (Oathbound Plate's tenacity on a chest, the Gloves' crit damage).

## <champion>_<name> (&"knight_tidebreaker").
@export var id: StringName = &""
@export var display_name: String = ""
## Not used yet: whether it carries lore waits for NARRATIVE.md (LOOT.md,
## Open questions). Shown in the tooltip's last line when set.
@export_multiline var flavor: String = ""
## LEGENDARY or ARTIFACT.
@export var rarity: Item.Rarity = Item.Rarity.LEGENDARY
## The champion it belongs to (&"knight"): only it can equip it, and it drops
## only for it.
@export var champion_id: StringName = &""
## The slot and the implicit.
@export var base: ItemBase
## Fixed, in order; each rolled in the rarity's band (an Artifact's band is
## its maximum).
@export var affixes: Array[Affix] = []
## Fixed, not rolled (Chains of Judgement's +50% Judgement range). An
## ability: scope only on its own ability (the augment's scope).
@export var modifiers: Array[StatModifier] = []
## Exactly one: a FLAG or a REPLACE scoped ability:<id> of one of its
## champion's abilities.
@export var augment: AbilityAugment
## Its odds among its champion's named items of its rarity.
@export var drop_weight: float = 1.0


## The ability id its augment changes (from its ability: scope), or &"".
func get_ability_id() -> StringName:
	if augment == null or not String(augment.scope).begins_with("ability:"):
		return &""
	return StringName(String(augment.scope).trim_prefix("ability:"))


## Every broken rule (LOOT.md, Ability augments; empty = valid), checked
## against `champion`: its rarity, champion and base; its affixes and
## modifiers; its augment (FLAG or REPLACE, scoped to one of the champion's
## abilities; a FLAG the ability supports; a REPLACE whose variant replaces
## that ability and supports every talent FLAG of it); and the champion's
## other named items (no two share an id; named items for one ability share
## an item slot).
func get_validation_errors(champion: ChampionData) -> PackedStringArray:
	var errors := PackedStringArray()
	if champion == null:
		errors.append("no champion to check against")
		return errors
	if id == &"" or not String(id).begins_with(String(champion.id) + "_"):
		errors.append("its id '%s' must start with %s_" % [id, champion.id])
	if display_name.strip_edges() == "":
		errors.append("no display_name")
	if rarity != Item.Rarity.LEGENDARY and rarity != Item.Rarity.ARTIFACT:
		errors.append("its rarity must be Legendary or Artifact (is %s)" % Item.rarity_to_word(rarity))
	if champion_id != champion.id:
		errors.append("its champion_id '%s' isn't %s" % [champion_id, champion.id])
	if base == null:
		errors.append("no base")
	if drop_weight <= 0.0:
		errors.append("drop_weight must be above 0")
	_check_affixes(errors)
	var ability := _check_augment(champion, errors)
	_check_modifiers(ability, errors)
	_check_siblings(champion, errors)
	return errors


func _check_affixes(errors: PackedStringArray) -> void:
	var seen := {}
	for affix in affixes:
		if affix == null:
			errors.append("an empty affix")
			continue
		if seen.has(affix.id):
			errors.append("the affix '%s' twice" % affix.id)
		seen[affix.id] = true
		var affix_error := affix.get_validation_error()
		if affix_error != "":
			errors.append(affix_error)


## Checks the augment; returns the ability it changes (null if none).
func _check_augment(champion: ChampionData, errors: PackedStringArray) -> Ability:
	if augment == null:
		errors.append("no augment (a named item has exactly one)")
		return null
	var label := "augment '%s'" % augment.id
	if augment.kind == AbilityAugment.Kind.EVENT:
		errors.append("%s is an EVENT (that's a sigil; a named item's is a FLAG or a REPLACE)" % label)
	var ability_id := get_ability_id()
	var ability: Ability = null
	for a in [champion.q, champion.w, champion.e, champion.r]:
		if a != null and a.id == ability_id:
			ability = a
	if ability == null:
		errors.append("%s is scoped '%s', not ability:<one of %s's abilities>" % [label, augment.scope, champion.id])
		return null
	if augment.kind == AbilityAugment.Kind.FLAG and not ability.supported_flags.has(augment.id):
		errors.append("FLAG '%s' isn't in %s's supported_flags" % [augment.id, ability.id])
	if augment.kind == AbilityAugment.Kind.REPLACE:
		var variant := augment.replacement
		if variant == null:
			errors.append("%s is a REPLACE with no replacement" % label)
		else:
			if variant.variant_of != ability.id:
				errors.append("%s's variant %s has variant_of '%s', not '%s'" % [label, variant.id, variant.variant_of, ability.id])
			for flag in _talent_flags(champion, ability):
				if not variant.supported_flags.has(flag):
					errors.append("%s's variant %s doesn't support the talent FLAG '%s' of %s" % [label, variant.id, flag, ability.id])
	return ability


func _check_modifiers(ability: Ability, errors: PackedStringArray) -> void:
	for mod in modifiers:
		if mod == null:
			errors.append("an empty modifier")
			continue
		var label := "modifier on %s" % mod.stat
		if String(mod.scope).begins_with("ability:"):
			if augment == null or mod.scope != augment.scope:
				errors.append("%s is scoped '%s': an ability: scope only on its own ability" % [label, mod.scope])
			elif ability != null and not Ability.is_base_param(mod.stat) and not ability.has_param(mod.stat):
				errors.append("%s: '%s' isn't a param of %s" % [label, mod.stat, ability.id])
		else:
			var mod_error := Affix.get_modifier_error(mod.stat, mod.scope, label)
			if mod_error != "":
				errors.append(mod_error)


func _check_siblings(champion: ChampionData, errors: PackedStringArray) -> void:
	for other in champion.named_items:
		if other == null or other == self:
			continue
		if other.id == id:
			errors.append("another of %s's named items has the id '%s'" % [champion.id, id])
		var mine := get_ability_id()
		if mine != &"" and other.get_ability_id() == mine and base != null and other.base != null and other.base.slot != base.slot:
			errors.append("%s and %s both change %s but aren't in one item slot (%s, %s)" % [id, other.id, mine,
				Item.get_slot_name(base.slot), Item.get_slot_name(other.base.slot)])


## The FLAG ids the champion's talents put on `ability`.
static func _talent_flags(champion: ChampionData, ability: Ability) -> Array[StringName]:
	var out: Array[StringName] = []
	var scope := StringName("ability:%s" % ability.id)
	for talent in champion.talents:
		if talent == null:
			continue
		for aug_res in talent.augments:
			var aug := aug_res as AbilityAugment
			if aug != null and aug.kind == AbilityAugment.Kind.FLAG and aug.scope == scope and not out.has(aug.id):
				out.append(aug.id)
	return out
