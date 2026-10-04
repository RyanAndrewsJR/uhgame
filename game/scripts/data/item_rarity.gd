class_name ItemRarity
extends Resource
## One rung of the rarity ladder (LOOT.md, Rarities), inline in the
## LootTable: how many affixes it rolls and how high, its sigils, whether
## it's a named rarity, how magic find touches its weight, its color.
## COMPANIONS reads the names, colors and bands from the same entries.

@export var rarity: Item.Rarity = Item.Rarity.COMMON
@export var display_name: String = ""
@export var color: Color = Color.WHITE
## Random affixes (Common–Exotic); 0 for a named rarity (its list is fixed).
@export var affix_count: int = 0
## The band: a roll r lands at lerp(roll_min, roll_max, r) of an affix's
## range. Equal ends = no random draw (Artifact: 1.0 / 1.0, always the max).
@export_range(0.0, 1.0) var roll_min: float = 0.0
@export_range(0.0, 1.0) var roll_max: float = 1.0
## Unique 1, Exotic 2 (always different), else 0.
@export var sigil_count: int = 0
## Legendary, Artifact: rolled as one of the champion's named items (L5).
@export var is_named: bool = false
## x magic find on this rarity's drop weight (0 for Common; Diablo 2's
## smaller effect on the top tiers).
@export var magic_find_effect: float = 1.0
## Played when a pickup of this rarity lands (L7); null = silent.
@export var drop_sound: SoundEvent


## True when the band has equal ends: no random number is drawn.
func has_fixed_roll() -> bool:
	return is_equal_approx(roll_min, roll_max)


## "" when it can be used, else what's wrong.
func get_validation_error() -> String:
	var label := "rarity '%s'" % Item.rarity_to_word(rarity)
	if roll_min < 0.0 or roll_max > 1.0 or roll_min > roll_max:
		return "%s: its band (%s–%s) must sit inside 0–1, low end first" % [label, roll_min, roll_max]
	if affix_count < 0 or sigil_count < 0:
		return "%s: a count below 0" % label
	if is_named and (affix_count != 0 or sigil_count != 0):
		return "%s: a named rarity's affixes and augment are its named item's" % label
	if magic_find_effect < 0.0:
		return "%s: magic_find_effect below 0" % label
	return ""
