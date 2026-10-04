class_name LootTable
extends Resource
## LOOT's global rules (LOOT.md, Data): the seven rarities, the item bases,
## the random affix pool, the sigil pool and which drop table each enemy uses.
## One file, res://data/loot_tables/loot_table_default.tres, which the Loot
## autoload holds from L2 (`Loot.table`); until then get_default().

const DEFAULT_PATH := "res://data/loot_tables/loot_table_default.tres"
## Item.Rarity's size: every per-rarity list has this many entries.
const RARITY_COUNT := 7

## One per rarity, in Item.Rarity order (validated).
@export var rarities: Array[ItemRarity] = []
## The bases items roll from (at least one per slot).
@export var item_bases: Array[ItemBase] = []
## The random affix pool (Common–Exotic).
@export var affixes: Array[Affix] = []
## The sigil pool (Unique 1, Exotic 2): EVENT augments. Empty until LOOT L4,
## so Unique and Exotic roll without sigils until then.
@export var sigils: Array[AbilityAugment] = []
## Temporary, until ENEMIES_AI.md decides where enemy data lives (the same
## stand-in as ChampionLeveling.xp_by_unit): the dead unit's UnitStats file
## name -> its drop table.
@export var drop_table_by_unit: Dictionary[StringName, DropTable] = {}
## A unit not in drop_table_by_unit.
@export var default_drop_table: DropTable
## Played on collect (L7).
@export var pickup_sound: SoundEvent

static var _default: LootTable


## The default table (loaded once).
static func get_default() -> LootTable:
	if _default == null:
		_default = load(DEFAULT_PATH)
	return _default


func get_rarity(r: Item.Rarity) -> ItemRarity:
	return rarities[r] if r >= 0 and r < rarities.size() else null


func get_base(base_id: StringName) -> ItemBase:
	for base in item_bases:
		if base != null and base.id == base_id:
			return base
	return null


func get_affix(affix_id: StringName) -> Affix:
	for affix in affixes:
		if affix != null and affix.id == affix_id:
			return affix
	return null


func get_sigil(sigil_id: StringName) -> AbilityAugment:
	for sigil in sigils:
		if sigil != null and sigil.id == sigil_id:
			return sigil
	return null


## The bases of `slot` (-1 = every base).
func get_bases_for(slot: int = -1) -> Array[ItemBase]:
	var out: Array[ItemBase] = []
	for base in item_bases:
		if base != null and (slot < 0 or base.slot == slot):
			out.append(base)
	return out


## The pool's affixes that can roll on `slot`.
func get_affixes_for(slot: Item.Slot) -> Array[Affix]:
	var out: Array[Affix] = []
	for affix in affixes:
		if affix != null and affix.slots.has(slot):
			out.append(affix)
	return out


## The drop table for a kill of `unit`: drop_table_by_unit by its UnitStats
## file name, else default_drop_table. (Whether it drops at all, a training
## dummy or another team's kill, is Loot's call, L7.)
func get_drop_table(unit: Unit) -> DropTable:
	if unit != null and unit.stats != null and unit.stats.resource_path != "":
		var key := StringName(unit.stats.resource_path.get_file().get_basename())
		if drop_table_by_unit.has(key):
			return drop_table_by_unit[key]
	return default_drop_table


## Every broken rule (empty = valid): LOOT.md's rules on the ladder, the
## bases, the pool, the sigils and the drop tables.
func get_validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	_check_rarities(errors)
	_check_bases(errors)
	_check_affixes(errors)
	_check_sigils(errors)
	if default_drop_table == null:
		errors.append("no default_drop_table")
	var tables: Array[DropTable] = []
	if default_drop_table != null:
		tables.append(default_drop_table)
	for key: StringName in drop_table_by_unit:
		var table: DropTable = drop_table_by_unit[key]
		if table == null:
			errors.append("drop_table_by_unit['%s'] is empty" % key)
		elif not tables.has(table):
			tables.append(table)
	for table in tables:
		errors.append_array(table.get_validation_errors())
	return errors


func _check_rarities(errors: PackedStringArray) -> void:
	if rarities.size() != RARITY_COUNT:
		errors.append("needs %d rarities, has %d" % [RARITY_COUNT, rarities.size()])
	for i in rarities.size():
		var def := rarities[i]
		if def == null:
			errors.append("rarity %d is empty" % i)
			continue
		if def.rarity != i:
			errors.append("rarity %d is '%s': the rarities must follow Item.Rarity's order" % [i, Item.rarity_to_word(def.rarity)])
		var err := def.get_validation_error()
		if err != "":
			errors.append(err)


func _check_bases(errors: PackedStringArray) -> void:
	var ids := {}
	for base in item_bases:
		if base == null:
			errors.append("an empty item base")
			continue
		var err := base.get_validation_error()
		if err != "":
			errors.append(err)
		if ids.has(base.id):
			errors.append("two item bases with the id '%s'" % base.id)
		ids[base.id] = true
	for slot: int in Item.Slot.values():
		if get_bases_for(slot).is_empty():
			errors.append("no item base for the %s slot" % Item.get_slot_name(slot as Item.Slot))


func _check_affixes(errors: PackedStringArray) -> void:
	var ids := {}
	for affix in affixes:
		if affix == null:
			errors.append("an empty affix in the pool")
			continue
		var err := affix.get_validation_error()
		if err != "":
			errors.append(err)
		if ids.has(affix.id):
			errors.append("two affixes with the id '%s'" % affix.id)
		ids[affix.id] = true
		if affix.slots.is_empty():
			errors.append("affix '%s' rolls on no slot" % affix.id)
		if affix.weight <= 0.0:
			errors.append("affix '%s': weight must be above 0" % affix.id)
	# Every slot must offer as many affixes as the most a rarity rolls, or a
	# Rare there would come up short.
	var most := 0
	for def in rarities:
		if def != null:
			most = maxi(most, def.affix_count)
	for slot: int in Item.Slot.values():
		var count := get_affixes_for(slot as Item.Slot).size()
		if count < most:
			errors.append("the %s slot has %d affixes, fewer than the %d a rarity rolls" % [Item.get_slot_name(slot as Item.Slot), count, most])


func _check_sigils(errors: PackedStringArray) -> void:
	var ids := {}
	for sigil in sigils:
		if sigil == null:
			errors.append("an empty sigil in the pool")
			continue
		var label := "sigil '%s'" % sigil.id
		if not String(sigil.id).begins_with("sigil_"):
			errors.append("%s: its id must start with sigil_" % label)
		if sigil.kind != AbilityAugment.Kind.EVENT:
			errors.append("%s: a sigil is an EVENT augment (it reacts; it never changes an ability)" % label)
		if sigil.scope != &"" and not String(sigil.scope).begins_with("tag:"):
			errors.append("%s: its scope must be empty or tag: (a sigil fits every champion)" % label)
		if sigil.rules.size() != 1 or sigil.rules[0] == null:
			errors.append("%s: holds exactly one reaction rule" % label)
		if ids.has(sigil.id):
			errors.append("two sigils with the id '%s'" % sigil.id)
		ids[sigil.id] = true
	# An empty pool means sigils aren't built yet (Unique and Exotic roll
	# without them); a pool must hold enough for an Exotic's two different ones.
	if not sigils.is_empty():
		var most := 0
		for def in rarities:
			if def != null:
				most = maxi(most, def.sigil_count)
		if sigils.size() < most:
			errors.append("the sigil pool has %d, fewer than the %d a rarity rolls" % [sigils.size(), most])
