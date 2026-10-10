class_name ChampionData
extends Resource
## One champion (CHAMPIONS.md): identity, base stats, resource type, the four
## fixed ability slots, the default basic attack combo, the champion sounds
## and the champion level. One .tres per champion in res://data/champions/.
##
## Player.champion points at one; Player._apply_champion() copies it onto the
## nodes before Unit._ready(). A Player with no champion keeps its scene's
## own exports. Champions are data, never subclasses of Player.
##
## The passive (CH2) and the champion's own stat modifiers (CH3) attach after
## Unit._ready(), under passive_<id> and champion_<id>.

@export_group("Identity")
## Lowercase id. Source ids built from it: passive_<id>, champion_<id>.
@export var id: StringName = &""
@export var display_name: String = ""
## bruiser, diver, rogue... Decides dash-strike power and (later) which
## weapons the champion can wield. Not a role tag (role tags are ability roles).
@export var champion_class: StringName = &""

@export_group("Stats")
## Base stats (Unit.stats). No growth: champions don't level their stats.
@export var stats: UnitStats

@export_group("Resource")
## NONE removes the ResourceComponent at load (no costs, no resource bar).
@export var resource_type: ResourceComponent.ResourceType = ResourceComponent.ResourceType.MANA
## The rhythm (CHAMPIONS.md, Resource rhythms), copied onto the
## ResourceComponent at load. Starts at 0 instead of full.
@export var resource_starts_empty: bool = false
## Out of combat, the pool drops by this much per second (0 = no decay).
@export var resource_decay_per_second: float = 0.0
## Seconds after the last hit dealt or taken before the decay starts.
@export var resource_decay_delay: float = 0.0

@export_group("Modifiers")
## The champion's own stat modifiers (the Knight: +8 resource_on_hit scoped
## hit:basic_attack), added under get_champion_source_id() at load. Copies are
## added; these stay untouched.
@export var modifiers: Array[StatModifier] = []

@export_group("Abilities")
## Fixed slots: never remixed between champions or reassigned by the player.
@export var q: Ability
@export var w: Ability
@export var e: Ability
@export var r: Ability
## The default basic attack combo (until weapons exist).
@export var combo: AttackCombo

@export_group("Passive")
## Attached at load under get_passive_source_id() (CHAMPIONS.md, Passives).
## null = no passive.
@export var passive: Passive

@export_group("Talents")
## Every talent this champion has (TALENTS.md): the pool the loadout picks
## from. Each is attached under talent_<id> when it's in the loadout.
@export var talents: Array[Talent] = []
## The level curve and talent points (TALENTS T4). null = the shared default.
@export var leveling: ChampionLeveling

@export_group("Loot")
## The champion's named items (LOOT.md, LOOT L5): its Legendary and Artifact
## items. A Legendary or Artifact drop for this champion is one of these;
## with none of the rolled rarity, the drop is an Exotic.
@export var named_items: Array[NamedItem] = []

@export_group("Sounds")
@export var hurt_sound: SoundEvent
@export var death_sound: SoundEvent
@export var low_health_sound: SoundEvent
## Its sound triggers (AUDIO A6a): when, where and how its own sounds play,
## on top of the slots. null = none. The Player watches it at load.
@export var sound_sheet: SoundSheet

@export_group("View")
## The champion's rigged 3D model (3D.md, Data, Models); the Player takes it
## at load (Unit.model_scene). null = a placeholder capsule.
@export var model_scene: PackedScene
## How fast the champion's model turns to its facing (UnitView; exponential,
## per second). 45 since FEEL2 (Ryan, 2026-10-09: preset 3 shipped), so the
## model faces a swing by its hit (98% of the turn at the first swing's hit;
## 81% at enemies' 20). Below 0 = the view's own turn_rate (20). The view
## only; never gameplay.
@export var model_turn_rate: float = 45.0

@export_group("Champion level")
## The champion's own persistent level (VISION.md, Game structure). Only ever
## gates talent points (TALENTS.md); never touches combat stats. Since TALENTS
## T4 this is a new progress record's starting value: the live level and XP
## live in the champion's ChampionProgress (the Progress autoload), saved in
## user://progress.cfg.
@export var champion_level: int = 1
## XP earned toward the next level (not total XP), so retuning the curve
## can never take a level away.
@export var champion_xp: int = 0


## The source id the champion's own modifiers are added under: champion_<id>.
func get_champion_source_id() -> StringName:
	return StringName("champion_%s" % id)


## The source id the passive's pieces are added under: passive_<id>.
func get_passive_source_id() -> StringName:
	return StringName("passive_%s" % id)


const DEFAULT_LEVELING_PATH := "res://data/champion_levelings/champion_leveling_default.tres"


## `leveling`, or the shared default when it's null.
func get_leveling() -> ChampionLeveling:
	return leveling if leveling != null else load(DEFAULT_LEVELING_PATH)


## The talent with this id in `talents`, or null.
func get_talent(talent_id: StringName) -> Talent:
	for t in talents:
		if t != null and t.id == talent_id:
			return t
	return null


## The named item with this id in `named_items`, or null (LOOT L5).
func get_named_item(named_id: StringName) -> NamedItem:
	for n in named_items:
		if n != null and n.id == named_id:
			return n
	return null
