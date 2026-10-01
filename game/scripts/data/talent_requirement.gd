class_name TalentRequirement
extends Resource
## One thing a talent needs before it unlocks (TALENTS.md, Unlocking). A
## talent's requirements all must be met (AND); once they are, the talent stays
## unlocked. Reads a champion's lifetime counters, never fight state: it is
## not a Condition, and the two never mix. Inline in the talent's .tres.
##
## Built in TALENTS T1 (the data, its labels, validation); get_current() and
## is_met() read a ChampionProgress (T4).

enum Kind {
	## The champion level is at least `amount`.
	CHAMPION_LEVEL,
	## The talent's own group's ability has been used at least `amount` times.
	## No ability field on purpose: a requirement can't point at another group.
	## Invalid in the PASSIVE group.
	ABILITY_USES,
	## At least `amount` kills; with `enemy_tag`, only enemies with that kill tag.
	KILLS,
}

@export var kind: Kind = Kind.CHAMPION_LEVEL
## The level, uses or kills needed.
@export var amount: int = 1
## KILLS only: count only enemies with this kill tag (empty = every kill).
@export var enemy_tag: StringName = &""


## The counter this requirement reads, now: the champion level, the group
## ability's uses (0 in PASSIVE) or the kills (by tag if set).
func get_current(progress: ChampionProgress, talent: Talent, champion: ChampionData) -> int:
	if progress == null:
		return 0
	match kind:
		Kind.CHAMPION_LEVEL:
			return progress.level
		Kind.ABILITY_USES:
			var ability := talent.get_group_ability(champion) if talent != null else null
			return progress.get_ability_uses(ability.id) if ability != null else 0
		Kind.KILLS:
			return progress.get_kills(enemy_tag)
	return 0


func is_met(progress: ChampionProgress, talent: Talent, champion: ChampionData) -> bool:
	return get_current(progress, talent, champion) >= amount


## What the hub shows before the counts ("Cleave casts", "Champion level").
func get_label(talent: Talent, champion: ChampionData) -> String:
	match kind:
		Kind.CHAMPION_LEVEL:
			return "Champion level"
		Kind.ABILITY_USES:
			var ability := talent.get_group_ability(champion) if talent != null else null
			var ability_name := ability.display_name if ability != null and ability.display_name != "" else "Ability"
			return "%s casts" % ability_name
		Kind.KILLS:
			return "Kills" if enemy_tag == &"" else "%s kills" % String(enemy_tag).capitalize()
	return "?"


## Why this requirement can't sit on `talent` ("" = fine).
func get_validation_error(talent: Talent) -> String:
	if amount < 0:
		return "a requirement's amount is negative (%d)" % amount
	if kind == Kind.ABILITY_USES and talent.group == Talent.Group.PASSIVE:
		return "ABILITY_USES in the PASSIVE group (a passive has no ability to count)"
	if kind != Kind.KILLS and enemy_tag != &"":
		return "enemy_tag is set on a %s requirement (KILLS only)" % Kind.keys()[kind]
	return ""
