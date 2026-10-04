class_name ItemBase
extends Resource
## An item base (LOOT.md): what kind of item it is, the equipment slot it
## goes in, and its implicits (fixed modifiers every item of this base has,
## whatever its rarity). Files: res://data/item_bases/item_base_<name>.tres.

@export var id: StringName = &""
@export var display_name: String = ""
@export var slot: Item.Slot = Item.Slot.WEAPON
## Fixed, never rolled; copied onto the wearer under the item's source id.
## Never `ability:`-scoped (a base fits every champion).
@export var implicits: Array[StatModifier] = []
## Its share of the rolls among the bases of its slot.
@export var drop_weight: float = 1.0


## "" when it can be used, else what's wrong.
func get_validation_error() -> String:
	if id == &"":
		return "an item base has no id"
	if drop_weight < 0.0:
		return "item base '%s': drop_weight below 0" % id
	for mod in implicits:
		if mod == null:
			return "item base '%s': an empty implicit" % id
		var err := Affix.get_modifier_error(mod.stat, mod.scope, "item base '%s'" % id)
		if err != "":
			return err
	return ""
