class_name Archetype
extends Resource
## One archetype (ARCHETYPES.md, Data: Archetype; built AR3a, 2026-10-08):
## what every unit of it shares, champion or enemy, so its layer isn't copied
## into each one's data (D11: the deflect-dash is the archetype's, not a
## passive's). Looked up by id (of()): a champion's is its
## ChampionData.champion_class (renamed archetype in AR8); an enemy's comes
## from its rank and behavior (EnemyData.get_archetype_id(): basic for
## fodder). Only the Assassin's file exists until AR8 (all six then); an id
## with no file gives null, and a unit with no archetype has none of its
## layer (no meter, no deflect).
## Read so far: poise_meter and poise_rules (an enemy's PoiseComponent at
## spawn, AR3a). deflects (AR3b), the string fields (AR3b's authoring check),
## the dash and the window (AR5) and layer come with their steps.
## Files: res://data/archetypes/archetype_<id>.tres.

const DIRECTORY := "res://data/archetypes/"

static var _cache: Dictionary = {}   # id -> Archetype, or null when it has no file

## &"assassin", &"mage", &"skirmisher", &"bruiser", &"duelist", &"basic".
@export var id: StringName = &""
@export var display_name: String = ""

@export_group("String")
## The approved shape (D8): a regular's string has the minimum, an elite's
## the range, a boss's the maximum + 1. Authoring targets the enemies test
## checks an enemy's string against (AR3b).
@export var string_hits_min: int = 0
@export var string_hits_max: int = 0
## Hit-to-hit seconds (the test's ±0.05 s).
@export var string_spacing: float = 0.0

@export_group("Deflect")
## A unit of it has a running deflect window (its DeflectComponent), in place
## of the prototype's flag (AR3b for enemies, AR5 for champions).
@export var deflects: bool = false
## Champions: × the dash's dash_distance (the Assassin's 400 u -> 500 u).
@export var dash_distance_scale: float = 1.0
## Champions: the dash's recharge (s); −1 = the dash's own (the Knight's 0.35).
@export var dash_recharge_time: float = -1.0
## A dash's deflect window (s).
@export var deflect_window: float = 0.2

@export_group("Poise")
## A unit of it has a running poise meter (PoiseComponent), with the
## prototype's flag off: an enemy's is its rank's size unless its EnemyData
## says otherwise (EnemyData.poise_max).
@export var poise_meter: bool = false
## Its meter's numbers; null = poise_rules_assassin.tres.
@export var poise_rules: PoiseRules

## Anything else it gives a champion at load, under &"archetype_<id>"
## (a placeholder layer later). null = none.
@export var layer: ToolkitBundle


## The archetype with this id, or null (no file: no layer). Loaded once.
static func of(archetype_id: StringName) -> Archetype:
	if archetype_id == &"":
		return null
	if _cache.has(archetype_id):
		return _cache[archetype_id]
	var path := DIRECTORY + "archetype_" + String(archetype_id) + ".tres"
	var found: Archetype = load(path) as Archetype if ResourceLoader.exists(path) else null
	_cache[archetype_id] = found
	return found


## The source id its layer goes under.
func get_source_id() -> StringName:
	return StringName("archetype_" + String(id))
