class_name Item
extends RefCounted
## One rolled item (LOOT.md): a base, a rarity, its affixes' rolls and, on a
## Unique or Exotic, its sigils. Items aren't Resources: they're rolled at
## runtime (ItemRoller) and saved as Dictionaries (to_dict()), never as .tres.
##
## The roll is saved, not the value: each affix keeps a 0–1 roll and its value
## is recomputed from the current data (Affix.get_value() inside the rarity's
## band), so a retune of an affix range or a band reaches every item already
## owned. LOOT L1; the sigil names and tooltip lines L4; named items
## (Legendary / Artifact: `named`) L5.
##
## A named item's base, rarity, affix list, fixed modifiers and augment come
## from its NamedItem; only its affixes' rolls are its own (an Artifact's are
## always 1). It's saved by its named id and read back through its champion.

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
## A Legendary's or Artifact's named item (LOOT L5); null for every rolled
## Common–Exotic.
var named: NamedItem


## The source id its modifiers and augments go on a unit under.
func get_source_id() -> StringName:
	return StringName("item_%d" % uid)


func get_slot() -> Slot:
	return base.slot if base != null else Slot.WEAPON


## The base's name, plus " of " and its sigils' name suffixes (LOOT L4):
## "Iron Helm of Storms", "Band of the Hunt and Ruin". A sigil without a
## suffix adds nothing. A named item: its own name.
func get_display_name() -> String:
	if named != null:
		return named.display_name
	var base_name := base.display_name if base != null else "?"
	var suffixes: PackedStringArray = []
	for sigil in sigils:
		if sigil != null and sigil.name_suffix != "":
			suffixes.append(sigil.name_suffix)
	if suffixes.is_empty():
		return base_name
	var last := suffixes[suffixes.size() - 1]
	suffixes.remove_at(suffixes.size() - 1)
	return "%s of %s" % [base_name, last if suffixes.is_empty() else "%s and %s" % [", ".join(suffixes), last]]


func get_color(table: LootTable) -> Color:
	var def := table.get_rarity(rarity)
	return def.color if def != null else Color.WHITE


## The value of the `index`-th affix: its roll placed inside the rarity's band
## of the affix's range, rounded to its step.
func get_affix_value(index: int, table: LootTable) -> float:
	var def := table.get_rarity(rarity)
	var affix: Affix = affix_rolls[index][0]
	return affix.get_value(def.roll_min, def.roll_max, affix_rolls[index][1])


## The implicits (copies), the affixes' modifiers and a named item's fixed
## modifiers (copies), all under get_source_id().
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
	if named != null:
		for mod in named.modifiers:
			if mod != null:
				var copy: StatModifier = mod.duplicate()
				copy.source_id = source
				out.append(copy)
	return out


## The augments it gives its wearer: its sigils, and a named item's augment.
func get_augments() -> Array[AbilityAugment]:
	var out: Array[AbilityAugment] = []
	out.append_array(sigils)
	if named != null and named.augment != null:
		out.append(named.augment)
	return out


## The champion it belongs to: a named item's; &"" = any champion (every
## rolled Common–Exotic).
func get_champion_id() -> StringName:
	return named.champion_id if named != null else &""


## Name, rarity and slot, the implicits, the affixes, the sigils; a named
## item adds its fixed modifiers, its augment and its flavor (in quotes).
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
	if named != null:
		for mod in named.modifiers:
			if mod != null:
				lines.append(get_named_modifier_line(mod, named.champion_id))
	for augment in get_augments():
		if augment != null:
			lines.append(get_augment_line(augment))
	if named != null and named.flavor.strip_edges() != "":
		lines.append("\"%s\"" % named.flavor.strip_edges())
	return lines


## A sigil's or a named item's augment line: "Storm Strike: <its
## description>" (just the name, or the id, without a description).
static func get_augment_line(augment: AbilityAugment) -> String:
	var label := augment.display_name if augment.display_name != "" else String(augment.id)
	return "%s: %s" % [label, augment.description] if augment.description != "" else label


## A named item's fixed modifier: "+50% Cast Range (Judgement)". An ability:
## scope names the ability (its id without the champion's prefix); another
## scope is shown as it is.
static func get_named_modifier_line(mod: StatModifier, champion_id: StringName) -> String:
	var line := Affix.describe(mod.stat, mod.type, mod.value)
	var scope := String(mod.scope)
	if scope.begins_with("ability:"):
		return "%s (%s)" % [line, scope.trim_prefix("ability:").trim_prefix(String(champion_id) + "_").capitalize()]
	return line if scope == "" else "%s (%s)" % [line, scope]


## What the inventory save keeps (LOOT.md, Inventory and saving): ids and
## rolls, never values.
func to_dict() -> Dictionary:
	var affixes: Array = []
	for pair in affix_rolls:
		affixes.append([String((pair[0] as Affix).id), float(pair[1])])
	var sigil_ids: Array = []
	for sigil in sigils:
		sigil_ids.append(String(sigil.id))
	var d := {
		"uid": uid,
		"base": String(base.id) if base != null else "",
		"rarity": rarity_to_word(rarity),
		"affixes": affixes,
		"sigils": sigil_ids,
	}
	if named != null:
		d["named"] = String(named.id)
	return d


## The item `d` describes, or null when its base or rarity is unknown (the
## inventory keeps such an entry raw, L2). An unknown affix or sigil id drops
## that line only, with a warning. Rolls are clamped to 0–1.
## A named item (a "named" key) needs `champion` and one of its named items
## with that id, else it's null too (kept raw: a data fix brings it back).
static func from_dict(d: Dictionary, table: LootTable, champion: ChampionData = null) -> Item:
	var named_id := str(d.get("named", ""))
	if named_id != "":
		var named_res := champion.get_named_item(StringName(named_id)) if champion != null else null
		return _from_named(d, named_res, table) if named_res != null else null
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


## A named item from its save: its base, rarity and affix list from `named`
## (the data wins), each affix's roll from the save by affix id. An affix the
## save has no roll for gets the band's middle (0.5; warning); a saved affix
## the named item no longer lists is dropped (warning); an Artifact's rolls
## are always 1.
static func _from_named(d: Dictionary, named_res: NamedItem, table: LootTable) -> Item:
	var item := Item.new()
	item.uid = int(d.get("uid", 0))
	item.named = named_res
	item.rarity = named_res.rarity
	item.base = named_res.base
	var saved := {}
	var affixes: Variant = d.get("affixes", [])
	if affixes is Array:
		for pair: Variant in affixes:
			if pair is Array and (pair as Array).size() >= 2:
				saved[StringName(str(pair[0]))] = float(pair[1])
	var def := table.get_rarity(item.rarity)
	var fixed := def != null and def.has_fixed_roll()
	for affix in named_res.affixes:
		if affix == null:
			continue
		var roll := 1.0
		if not fixed:
			if saved.has(affix.id):
				roll = saved[affix.id]
			else:
				roll = 0.5
				push_warning("Item %d (%s): no saved roll for '%s'; the band's middle" % [item.uid, named_res.id, affix.id])
		saved.erase(affix.id)
		item.affix_rolls.append([affix, quantize_roll(roll)])
	for gone: StringName in saved:
		push_warning("Item %d (%s): '%s' isn't one of its affixes any more; dropped" % [item.uid, named_res.id, gone])
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
