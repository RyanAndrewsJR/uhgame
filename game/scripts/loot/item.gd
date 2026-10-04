class_name Item
extends RefCounted
## One rolled item (LOOT.md): a base, a rarity, its affixes' rolls and, on a
## Unique or Exotic, its sigils. Items aren't Resources: they're rolled at
## runtime (ItemRoller) and saved as Dictionaries (to_dict()), never as .tres.
##
## The roll is saved, not the value: each affix keeps a 0–1 roll and its value
## is recomputed from the current data (Affix.get_value() inside the rarity's
## band), so a retune of an affix range or a band reaches every item already
## owned. LOOT L1; named items (Legendary / Artifact) come in L5, the sigil
## names in L4.

enum Slot { WEAPON, HELM, CHEST, GLOVES, BOOTS, RING, AMULET }
enum Rarity { COMMON, UNCOMMON, RARE, UNIQUE, EXOTIC, LEGENDARY, ARTIFACT }

## A roll is kept to this many decimals, so it survives the inventory's text
## save exactly: Godot writes a raw randf() value (float32) and some 17-digit
## doubles to text inexactly, but reads a 4-decimal number back to the same
## double (measured in LOOT L1: 0 mismatches in 200,000).
const ROLL_DECIMALS := 4

## Unique inside one champion's inventory (it hands them out, LOOT L2);
## 0 until the item is added to one.
var uid: int = 0
var rarity: Rarity = Rarity.COMMON
var base: ItemBase
## [Affix, roll] pairs; the roll is 0–1 inside the rarity's band.
var affix_rolls: Array = []
## Unique 1, Exotic 2 (always different): EVENT augments from LootTable.sigils.
var sigils: Array[AbilityAugment] = []


## The source id its modifiers and augments go on a unit under.
func get_source_id() -> StringName:
	return StringName("item_%d" % uid)


func get_slot() -> Slot:
	return base.slot if base != null else Slot.WEAPON


## The base's name. (L4 adds " of <suffixes>" for an item's sigils.)
func get_display_name() -> String:
	return base.display_name if base != null else "?"


func get_color(table: LootTable) -> Color:
	var def := table.get_rarity(rarity)
	return def.color if def != null else Color.WHITE


## The value of the `index`-th affix: its roll placed inside the rarity's band
## of the affix's range, rounded to its step.
func get_affix_value(index: int, table: LootTable) -> float:
	var def := table.get_rarity(rarity)
	var affix: Affix = affix_rolls[index][0]
	return affix.get_value(def.roll_min, def.roll_max, affix_rolls[index][1])


## The implicits (copies) and the affixes' modifiers, all under get_source_id().
func get_modifiers(table: LootTable) -> Array[StatModifier]:
	var out: Array[StatModifier] = []
	var source := get_source_id()
	if base != null:
		for mod in base.implicits:
			if mod != null:
				var copy: StatModifier = mod.duplicate()
				copy.source_id = source
				out.append(copy)
	for i in affix_rolls.size():
		var affix: Affix = affix_rolls[i][0]
		out.append(affix.make_modifier(get_affix_value(i, table), source))
	return out


## The augments it gives its wearer: its sigils (L5 adds a named item's augment).
func get_augments() -> Array[AbilityAugment]:
	var out: Array[AbilityAugment] = []
	out.append_array(sigils)
	return out


## The champion it belongs to; &"" = any champion (every rolled Common–Exotic).
func get_champion_id() -> StringName:
	return &""


## Name, rarity and slot, the implicits, the affixes, the sigils.
func get_tooltip_lines(table: LootTable) -> PackedStringArray:
	var lines: PackedStringArray = []
	var def := table.get_rarity(rarity)
	lines.append(get_display_name())
	lines.append("%s %s" % [def.display_name if def != null else "?", get_slot_name(get_slot())])
	if base != null:
		for mod in base.implicits:
			if mod != null:
				lines.append(Affix.describe(mod.stat, mod.type, mod.value))
	for i in affix_rolls.size():
		lines.append((affix_rolls[i][0] as Affix).get_line(get_affix_value(i, table)))
	for sigil in sigils:
		lines.append(sigil.get_tooltip_line())
	return lines


## What the inventory save keeps (LOOT.md, Inventory and saving): ids and
## rolls, never values.
func to_dict() -> Dictionary:
	var affixes: Array = []
	for pair in affix_rolls:
		affixes.append([String((pair[0] as Affix).id), float(pair[1])])
	var sigil_ids: Array = []
	for sigil in sigils:
		sigil_ids.append(String(sigil.id))
	return {
		"uid": uid,
		"base": String(base.id) if base != null else "",
		"rarity": rarity_to_word(rarity),
		"affixes": affixes,
		"sigils": sigil_ids,
	}


## The item `d` describes, or null when its base or rarity is unknown (the
## inventory keeps such an entry raw, L2). An unknown affix or sigil id drops
## that line only, with a warning. Rolls are clamped to 0–1.
static func from_dict(d: Dictionary, table: LootTable) -> Item:
	var base_res := table.get_base(StringName(str(d.get("base", ""))))
	var r := word_to_rarity(str(d.get("rarity", "")))
	if base_res == null or r < 0:
		return null
	var item := Item.new()
	item.uid = int(d.get("uid", 0))
	item.rarity = r as Rarity
	item.base = base_res
	var affixes: Variant = d.get("affixes", [])
	if affixes is Array:
		for pair: Variant in affixes:
			if not (pair is Array) or (pair as Array).size() < 2:
				push_warning("Item %d: an unreadable affix entry; dropped" % item.uid)
				continue
			var affix := table.get_affix(StringName(str(pair[0])))
			if affix == null:
				push_warning("Item %d: unknown affix '%s'; dropped" % [item.uid, pair[0]])
				continue
			item.affix_rolls.append([affix, quantize_roll(float(pair[1]))])
	var sigil_ids: Variant = d.get("sigils", [])
	if sigil_ids is Array:
		for id: Variant in sigil_ids:
			var sigil := table.get_sigil(StringName(str(id)))
			if sigil == null:
				push_warning("Item %d: unknown sigil '%s'; dropped" % [item.uid, id])
				continue
			item.sigils.append(sigil)
	return item


## `roll` clamped to 0–1 and kept to ROLL_DECIMALS (the double a short
## decimal reads back as).
static func quantize_roll(roll: float) -> float:
	return (("%." + str(ROLL_DECIMALS) + "f") % clampf(roll, 0.0, 1.0)).to_float()


## "common", "uncommon"... (saved as a word, so reordering the enum never
## breaks a save).
static func rarity_to_word(r: Rarity) -> String:
	return String(Rarity.keys()[r]).to_lower()


## The rarity a saved word names, or -1.
static func word_to_rarity(word: String) -> int:
	return Rarity.keys().find(word.to_upper())


## "Weapon", "Helm"...
static func get_slot_name(slot: Slot) -> String:
	return String(Slot.keys()[slot]).capitalize()
