class_name ItemRoller
## Rolls items (LOOT.md, Drops): a rarity from a drop table at a depth with
## magic find, then a base, its affixes and their rolls, and a Unique's or
## Exotic's sigils. Every random choice takes the caller's
## RandomNumberGenerator, so a seeded rng gives the same items every time
## (tests; COMPANIONS' rolls reuse roll_rarity()). A band with equal ends
## (the Artifact's) draws nothing.
## LOOT L1. Named items (Legendary / Artifact) come in L5; until then, and for
## a champion with none of the rolled rarity, the item is an Exotic.


## A rarity rolled from `drop_table`'s weights at `depth` with `magic_find`.
## `table` gives each rarity's magic find effect (null = the default).
static func roll_rarity(drop_table: DropTable, depth: int, magic_find: float, rng: RandomNumberGenerator, table: LootTable = null) -> Item.Rarity:
	var t := table if table != null else LootTable.get_default()
	var index := pick_weighted(drop_table.get_weights(depth, magic_find, t), rng)
	return maxi(index, 0) as Item.Rarity


## One item of `rarity` (its uid 0 until an inventory adds it), from `slot`'s
## bases (-1 = any slot). `_champion` picks a named item from L5.
static func roll_item(rarity: Item.Rarity, _champion: ChampionData, table: LootTable, rng: RandomNumberGenerator, slot: int = -1) -> Item:
	var t := table if table != null else LootTable.get_default()
	var r := rarity
	var def := t.get_rarity(r)
	if def != null and def.is_named:
		# L5 picks one of the champion's named items here.
		r = Item.Rarity.EXOTIC
		def = t.get_rarity(r)
	var bases := t.get_bases_for(slot)
	if def == null or bases.is_empty():
		push_error("ItemRoller: no rarity '%s' or no base for slot %d" % [Item.rarity_to_word(r), slot])
		return null
	var item := Item.new()
	item.rarity = r
	var base_weights: Array[float] = []
	for base in bases:
		base_weights.append(base.drop_weight)
	item.base = bases[maxi(pick_weighted(base_weights, rng), 0)]
	# Affixes the slot allows, weighted, never the same one twice.
	var pool := t.get_affixes_for(item.base.slot)
	for n in def.affix_count:
		if pool.is_empty():
			break
		var weights: Array[float] = []
		for affix in pool:
			weights.append(affix.weight)
		var k := maxi(pick_weighted(weights, rng), 0)
		item.affix_rolls.append([pool[k], roll_in_band(def, rng)])
		pool.remove_at(k)
	# Sigils, never the same one twice.
	var sigil_pool: Array[AbilityAugment] = []
	for sigil in t.sigils:
		if sigil != null:
			sigil_pool.append(sigil)
	for n in def.sigil_count:
		if sigil_pool.is_empty():
			break
		var k := rng.randi_range(0, sigil_pool.size() - 1)
		item.sigils.append(sigil_pool[k])
		sigil_pool.remove_at(k)
	return item


## What one kill (or chest) gives: nothing, or `drop_table.item_count` items,
## each with its own rarity roll.
static func roll_drop(drop_table: DropTable, depth: int, magic_find: float, champion: ChampionData, table: LootTable, rng: RandomNumberGenerator) -> Array[Item]:
	var t := table if table != null else LootTable.get_default()
	var out: Array[Item] = []
	var chance := drop_table.get_chance(depth)
	# randf() can return exactly 1.0, so a sure drop doesn't roll.
	if chance <= 0.0 or (chance < 1.0 and rng.randf() >= chance):
		return out
	for n in maxi(drop_table.item_count, 1):
		var item := roll_item(roll_rarity(drop_table, depth, magic_find, rng, t), champion, t, rng)
		if item != null:
			out.append(item)
	return out


## An affix's roll (0–1) for `def`: random (kept to Item.ROLL_DECIMALS, so it
## saves exactly), or 1.0 with no draw when the band's ends are equal (an
## Artifact's affixes are always their maximum).
static func roll_in_band(def: ItemRarity, rng: RandomNumberGenerator) -> float:
	return 1.0 if def.has_fixed_roll() else Item.quantize_roll(rng.randf())


## The index picked with these weights (one draw), or -1 when they sum to 0.
static func pick_weighted(weights: Array[float], rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for w in weights:
		total += maxf(w, 0.0)
	if total <= 0.0:
		return -1
	var x := rng.randf() * total
	var last := -1
	for i in weights.size():
		var w := maxf(weights[i], 0.0)
		if w <= 0.0:
			continue
		last = i
		if x < w:
			return i
		x -= w
	return last   # x landed on the total itself (randf() returned 1.0)
