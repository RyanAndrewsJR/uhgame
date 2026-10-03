class_name DamageNumberStyle
extends Resource
## How damage numbers look (COMBAT.md, Damage numbers). One style in use:
## res://data/damage_number_styles/damage_number_style_default.tres.

@export_group("Size")
## Damage at or above each threshold uses the matching font size. Steps of
## 10x (a log scale), so late-game numbers don't all hit the biggest size.
@export var size_thresholds: PackedFloat32Array = PackedFloat32Array([0.0, 100.0, 1000.0])
@export var font_sizes: PackedInt32Array = PackedInt32Array([10, 12, 14])

@export_group("Crit")
## Crits are this many font sizes bigger.
@export var crit_size_bonus: int = 3
## The crit font (COMBAT.md, Open questions). null = the normal font until
## the asset exists.
@export var crit_font: Font
@export var crit_outline_color: Color = Color(0.45, 0.12, 0.0)
## Added after a crit's number.
@export var crit_suffix: String = "!"

@export_group("Damage over time")
@export var dot_font_size: int = 8
## DoT ticks on the same target within this many seconds add up into one
## number.
@export var dot_merge_window: float = 0.3

@export_group("Colors")
@export var physical_color: Color = Color(1.0, 0.72, 0.35)
@export var magic_color: Color = Color(0.55, 0.7, 1.0)
@export var true_color: Color = Color(1.0, 1.0, 1.0)
## Damage the player takes, whatever its type.
@export var player_damage_color: Color = Color(1.0, 0.3, 0.28)
@export var heal_color: Color = Color(0.4, 1.0, 0.45)
## Damage a shield absorbed (COMBAT C10), shown as its own number.
@export var shield_color: Color = Color(0.78, 0.84, 0.92)
@export var outline_color: Color = Color.BLACK
@export var outline_size: int = 3

@export_group("Motion")
@export var rise_px: float = 12.0
## Seconds from the hit until the number is gone (it fades over the second
## half).
@export var lifetime: float = 0.6
## The number pops in at this scale and shrinks to 1 over 0.1 s.
@export var pop_scale: float = 1.35
## Random sideways spread, px.
@export var spread_px: float = 6.0
## A unit's new number starts this much higher than its previous one while
## that one still shows (its `lifetime`), px, so hits in a row read as a
## column instead of a pile (Ryan, 2026-10-03).
@export var stack_step_px: float = 11.0
## How many numbers stack up before the next starts at the bottom again.
@export var stack_levels: int = 4


## The font size for a normal hit of `amount`.
func get_font_size(amount: float) -> int:
	var size := font_sizes[0] if not font_sizes.is_empty() else 10
	for i in mini(size_thresholds.size(), font_sizes.size()):
		if amount >= size_thresholds[i]:
			size = font_sizes[i]
	return size


func get_damage_type_color(type: HitContext.DamageType) -> Color:
	match type:
		HitContext.DamageType.MAGIC:
			return magic_color
		HitContext.DamageType.TRUE:
			return true_color
	return physical_color
