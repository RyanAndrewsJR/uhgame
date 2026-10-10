class_name SoundTrigger
extends Resource
## One sound placed and timed by data (AUDIO.md, Sound triggers and the
## tuning panel; built in A6a): when (an event, a point of the motion, a
## delay), which (filters on the event, Conditions), where (a place) and how
## (the sound, its volume and pitch, chance, cooldown, every Nth, once per
## frame). Inline in a SoundSheet; SoundTriggers plays it. A filter that
## doesn't apply to the event is ignored (swing_number on a cast...).
## The Player's sounds stay centered (AUDIO.md, Rules), with one exception:
## a HIT_DEALT trigger (the hit landing on an enemy) may use ON_OTHER or
## AT_OTHER (Ryan, 2026-10-10). Enums are stored as ints: append only.

## What it listens for. "Other" is the unit ON_OTHER / AT_OTHER and a
## condition's target use.
enum Event {
	SWING_START,     ## A combo swing starts (whiffs included). Other: the aimed enemy.
	SWING_LANDED,    ## A swing's hit moment with at least one target. Other: the first.
	SWING_WHIFF,     ## A swing's hit moment with none.
	HIT_DEALT,       ## A hit by him got through (not blocked; DoT ticks only with `dot` in hit_tags). Other: the unit hit.
	HIT_TAKEN,       ## A hit on him got through. Other: the source.
	CAST_START,      ## A cast starts (AbilityComponent.cast_started). Other: the cast's target.
	CAST_EFFECT,     ## A cast's effect starts (Events.ability_cast). Other: the cast's target.
	STATUS_GAINED,   ## A status applied to him (every application). Other: its source.
	STATUS_ENDED,    ## A status ended on him (Events.status_ended). Other: its source.
	STACKS_REACHED,  ## His stacks of a status reach `stacks` from below. Other: its source.
	KILL,            ## He killed a unit. Other: the unit killed.
	DIED,            ## He died. Other: the killer.
	DASH,            ## He dashed (DashComponent.dash_started).
	DEFLECT,         ## He deflected a hit (Events.hit_deflected). Other: the attacker.
}

## Where it plays.
enum Place {
	DEFAULT,   ## Today's rule: centered for the Player, else following him.
	ON_SELF,   ## Following him.
	AT_SELF,   ## Where he stood at the event.
	ON_OTHER,  ## Following the other unit (where it stood, if it's freed).
	AT_OTHER,  ## Where the other unit stood at the event.
	AT_AIM,    ## The cast's aim point (cast events; else AT_SELF).
	CENTERED,  ## No position.
}

## STATUS_ENDED's reason filter: ANY, or one StatusEffect.EndReason (+1).
enum EndFilter { ANY, EXPIRED, CONSUMED, CLEANSED, DIED, REMOVED }

## In the panel and the audio log ("Demise 4: empowered hit").
@export var name: String = ""
## Off: it never plays (the panel's toggle).
@export var enabled: bool = true

@export_group("When")
@export var event: Event = Event.HIT_DEALT
## SWING_START and CAST_START only: plays when that swing's or cast's
## progress reaches it (0-1; -1 = at the event). Follows attack speed, cast
## speed and hitstop like the motion; a swing or cast that's cancelled or
## interrupted first never plays it.
@export_range(-1.0, 1.0, 0.01) var at_progress: float = -1.0
## Seconds after the event (or the progress point), real time like every
## sound; it pauses with the tree.
@export_range(0.0, 5.0, 0.01, "or_greater") var delay: float = 0.0

@export_group("Which")
## Swing events: 0 = any, 1-N = that swing of the chain (1-based), -1 = the
## dash-strike.
@export var swing_number: int = 0
## Cast and hit events: that ability (&"" = any).
@export var ability_id: StringName = &""
## A REPLACE variant of ability_id counts as it.
@export var include_variants: bool = true
## Cast events: that recast part (0 = the first cast); -1 = any.
@export var part: int = -1
## Status events: that status (by id) and/or one carrying that tag.
@export var status_id: StringName = &""
@export var status_tag: StringName = &""
## STACKS_REACHED: the count, reached from below (0 = every new stack).
@export var stacks: int = 0
## STATUS_ENDED: why it ended.
@export var end_reason: EndFilter = EndFilter.ANY
## Hit events: every tag must be on the hit.
@export var hit_tags: Array[StringName] = []
## The empower (its status id). Hit events: the hit used it (a swing's
## HitContext.empowers_used, a cast's CastContext.empowers). Swing events: a
## SWING_START that carries it (he holds it and its empower_scope admits the
## swing: a finisher-only empower plays on swing 4 alone; it plays again on
## the next such swing if this one whiffs), a SWING_LANDED whose hits used
## it, never a SWING_WHIFF.
@export var used_empower: StringName = &""
@export var crit_only: bool = false
@export var kill_only: bool = false
## All must pass: self = the sheet's unit, target = the other unit, cast =
## the event's cast (ABILITIES.md, Conditions).
@export var conditions: Array[Condition] = []

@export_group("Where")
@export var place: Place = Place.DEFAULT

@export_group("How")
## null = it does nothing (no error).
@export var sound: SoundEvent
## Added to the SoundEvent's volume_db.
@export var volume_db: float = 0.0
## Multiplies the SoundEvent's pitch_scale.
@export var pitch: float = 1.0
## Rolled on Audio.rng (tests seed it).
@export_range(0.0, 1.0, 0.01) var chance: float = 1.0
## Seconds of real time between plays, per unit.
@export var cooldown: float = 0.0
## Plays on every Nth match (3 = every third), per unit.
@export var every_nth: int = 1
## Once per physics frame per unit: a swing that hits five enemies plays it once.
@export var once_per_frame: bool = true


## The name in the panel and the log: `name`, else the event's.
func get_label() -> String:
	return name if name != "" else String(Event.keys()[event]).to_lower()


## True when its place would sit somewhere for the Player: AUDIO.md's
## exception is a HIT_DEALT at the other unit (the impact); every other place
## on a Player's sheet plays centered.
func is_placed_impact() -> bool:
	return event == Event.HIT_DEALT and (place == Place.ON_OTHER or place == Place.AT_OTHER)
