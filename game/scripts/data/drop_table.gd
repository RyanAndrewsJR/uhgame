class_name DropTable
extends Resource
## What one kind of kill (or later a chest, a destructible) drops (LOOT.md,
## Drops): the chance of a drop, how many items, and the rarity weights with
## how they grow with depth. Files: res://data/drop_tables/drop_table_<name>.tres.
##
## chance = min(1, item_chance x (1 + chance_per_depth x (depth - 1)))
## weight[r] = rarity_weights[r] x (1 + rarity_growth[r] x (depth - 1))
##             x (1 + magic_find x magic_find_effect[r])

## The chance of a drop at depth 1.
@export_range(0.0, 1.0) var item_chance: float = 0.1
## Added to the chance per depth level past 1, as a fraction of item_chance.
@export var chance_per_depth: float = 0.0
## Items in one drop, each with its own rarity roll.
@export var item_count: int = 1
## One per rarity, in Item.Rarity order, at depth 1.
@export var rarity_weights: Array[float] = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
## One per rarity: how much its weight grows per depth level past 1.
@export var rarity_growth: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]


## The chance of a drop at `depth` (1 = the first; lower counts as 1).
func get_chance(depth: int) -> float:
	return clampf(item_chance * (1.0 + chance_per_depth * (maxi(depth, 1) - 1)), 0.0, 1.0)


## Each rarity's weight at `depth` with `magic_find` (0.5 = +50%; below 0
## counts as 0). `table` gives each rarity's magic_find_effect (null = the
## default LootTable).
func get_weights(depth: int, magic_find: float, table: LootTable = null) -> Array[float]:
	var t := table if table != null else LootTable.get_default()
	var steps := maxi(depth, 1) - 1
	var mf := maxf(magic_find, 0.0)
	var out: Array[float] = []
	for r in mini(rarity_weights.size(), LootTable.RARITY_COUNT):
		var def := t.get_rarity(r as Item.Rarity)
		var effect := def.magic_find_effect if def != null else 0.0
		var growth := rarity_growth[r] if r < rarity_growth.size() else 0.0
		out.append(maxf(rarity_weights[r], 0.0) * (1.0 + growth * steps) * (1.0 + mf * effect))
	return out


## Every problem with it (empty = valid).
func get_validation_errors() -> PackedStringArray:
	var label := "drop table '%s'" % (resource_path.get_file() if resource_path != "" else "(inline)")
	var errors: PackedStringArray = []
	if item_chance < 0.0 or item_chance > 1.0:
		errors.append("%s: item_chance must be 0–1" % label)
	if item_count < 1:
		errors.append("%s: item_count below 1" % label)
	if rarity_weights.size() != LootTable.RARITY_COUNT or rarity_growth.size() != LootTable.RARITY_COUNT:
		errors.append("%s: needs %d rarity weights and %d growths" % [label, LootTable.RARITY_COUNT, LootTable.RARITY_COUNT])
	var total := 0.0
	for w in rarity_weights:
		if w < 0.0:
			errors.append("%s: a rarity weight below 0" % label)
		total += maxf(w, 0.0)
	if total <= 0.0:
		errors.append("%s: its rarity weights sum to 0" % label)
	for g in rarity_growth:
		if g < 0.0:
			errors.append("%s: a rarity growth below 0" % label)
	return errors
