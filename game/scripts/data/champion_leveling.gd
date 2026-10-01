class_name ChampionLeveling
extends Resource
## The champion level's curve and what it grants (TALENTS.md, Champion level
## and XP): XP to each next level, talent points per level, and (until
## ENEMIES_AI.md decides where enemy data lives) XP per kill. Shared by every
## champion unless a ChampionData names its own. Default file:
## res://data/champion_levelings/champion_leveling_default.tres.
##
## The level only ever gates talent points: it never touches combat stats and
## is never StatsComponent.set_level() (VISION.md, Game structure).

## Index 0 = level 1 -> 2. Its size + 1 is the max level.
@export var xp_to_next: Array[int] = []
## Index 0 = level 1: how many talents can be active at each level.
@export var talent_points: Array[int] = []
## Temporary, until ENEMIES_AI.md: XP per kill, keyed by the dead unit's
## UnitStats file name without the extension (&"slime"). A unit not listed
## gives 0.
@export var xp_by_unit: Dictionary[StringName, int] = {}


func get_max_level() -> int:
	return xp_to_next.size() + 1


## XP from `level` to the next one; 0 at (or past) the max level.
func get_xp_to_next(level: int) -> int:
	var i := maxi(level, 1) - 1
	return xp_to_next[i] if i < xp_to_next.size() else 0


## Talent points at `level` (the last entry past the end; 0 with none).
func get_talent_points(level: int) -> int:
	if talent_points.is_empty():
		return 0
	return talent_points[clampi(level - 1, 0, talent_points.size() - 1)]


## XP for killing `unit`: its UnitStats file name in xp_by_unit, else 0.
func get_kill_xp(unit: Unit) -> int:
	if unit == null or unit.stats == null or unit.stats.resource_path == "":
		return 0
	return xp_by_unit.get(StringName(unit.stats.resource_path.get_file().get_basename()), 0)
