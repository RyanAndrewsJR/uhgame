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
## The passive attaches after Unit._ready() under passive_<id> (CH2). CH3 adds
## the resource rhythm and the champion's own stat modifiers.

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

@export_group("Sounds")
@export var hurt_sound: SoundEvent
@export var death_sound: SoundEvent
@export var low_health_sound: SoundEvent

@export_group("Champion level")
## The champion's own persistent level (VISION.md, Game structure). Only ever
## gates talent points (TALENTS.md); never touches combat stats. Kept in
## memory while the game runs; saving it is PROGRESSION's. Nothing reads it yet.
@export var champion_level: int = 1
## XP earned toward the next level (not total XP), so retuning the curve
## can never take a level away.
@export var champion_xp: int = 0


## The source id the passive's pieces are added under: passive_<id>.
func get_passive_source_id() -> StringName:
	return StringName("passive_%s" % id)
