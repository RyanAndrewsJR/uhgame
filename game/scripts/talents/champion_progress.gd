class_name ChampionProgress
extends RefCounted
## One champion's live progress (TALENTS.md): level and XP, the lifetime
## counters (ability uses, kills, kills by tag), the talents unlocked (kept
## once earned) and the loadout. Held by the Progress autoload, one per
## champion id, saved in user://progress.cfg (one ConfigFile section per
## champion). Pure data and rules: it never touches a unit.

var champion_id: StringName = &""
var level: int = 1
## XP toward the next level (not total XP), as on ChampionData.
var xp: int = 0
## Ability id -> casts (a REPLACE variant counts for the ability it replaces).
var ability_uses: Dictionary = {}
var kills: int = 0
## Kill tag -> kills.
var kills_by_tag: Dictionary = {}
var unlocked: Array[StringName] = []
var loadout: Array[StringName] = []


## A fresh record from the ChampionData's starting values (level 1, 0 XP).
static func create(champion: ChampionData) -> ChampionProgress:
	var p := ChampionProgress.new()
	p.champion_id = champion.id
	p.level = maxi(champion.champion_level, 1)
	p.xp = maxi(champion.champion_xp, 0)
	return p


# --- Counters and XP -----------------------------------------------------------

func get_ability_uses(ability_id: StringName) -> int:
	return ability_uses.get(ability_id, 0)


func add_ability_use(ability_id: StringName) -> void:
	ability_uses[ability_id] = get_ability_uses(ability_id) + 1


func add_kill(tags: Array[StringName]) -> void:
	kills += 1
	for tag in tags:
		kills_by_tag[tag] = kills_by_tag.get(tag, 0) + 1


func get_kills(tag: StringName = &"") -> int:
	return kills if tag == &"" else kills_by_tag.get(tag, 0)


## Adds XP and gains every level it pays for (several at once if needed).
## At the max level the XP keeps adding up and grants nothing. Returns the
## levels gained.
func add_xp(amount: int, leveling: ChampionLeveling) -> int:
	if amount <= 0:
		return 0
	xp += amount
	var gained := 0
	while level < leveling.get_max_level() and xp >= leveling.get_xp_to_next(level):
		xp -= leveling.get_xp_to_next(level)
		level += 1
		gained += 1
	return gained


# --- Unlocks --------------------------------------------------------------------

func is_unlocked(talent_id: StringName) -> bool:
	return unlocked.has(talent_id)


## Records every talent whose requirements are all met now. Unlocks are kept:
## a talent never locks again. Returns the newly unlocked ids.
func refresh_unlocks(champion: ChampionData) -> Array[StringName]:
	var fresh: Array[StringName] = []
	for t in champion.talents:
		if t == null or is_unlocked(t.id):
			continue
		var met := true
		for req in t.requirements:
			if req != null and not req.is_met(self, t, champion):
				met = false
				break
		if met:
			unlocked.append(t.id)
			fresh.append(t.id)
	return fresh


# --- The loadout -----------------------------------------------------------------

func get_talent_points(leveling: ChampionLeveling) -> int:
	return leveling.get_talent_points(level)


## Each talent costs 1 point (Ryan, 2026-09-30).
func get_points_used() -> int:
	return loadout.size()


## Why `talent` can't go into the loadout now ("" = it can): "locked",
## "no points", "needs tier <n>" (the tier rule). An exclusive sibling isn't a
## reason: add_to_loadout() swaps it out.
func get_loadout_fail_reason(talent: Talent, champion: ChampionData, leveling: ChampionLeveling) -> String:
	if talent == null:
		return "locked"
	if loadout.has(talent.id):
		return ""
	if not is_unlocked(talent.id):
		return "locked"
	if talent.tier > 1 and not _has_tier(champion, talent.group, talent.tier - 1):
		return "needs tier %d" % (talent.tier - 1)
	var freed := 1 if _exclusive_sibling_in_loadout(talent, champion) != null else 0
	if get_points_used() - freed >= get_talent_points(leveling):
		return "no points"
	return ""


## Puts `talent` in the loadout, taking an exclusive sibling out first.
## False (nothing changes) if get_loadout_fail_reason() isn't "".
func add_to_loadout(talent: Talent, champion: ChampionData, leveling: ChampionLeveling) -> bool:
	if talent == null or loadout.has(talent.id) or get_loadout_fail_reason(talent, champion, leveling) != "":
		return false
	var sibling := _exclusive_sibling_in_loadout(talent, champion)
	if sibling != null:
		loadout.erase(sibling.id)
	loadout.append(talent.id)
	return true


## Takes a talent out, and with it every deeper talent of its group that no
## longer has a talent in the tier above it (the tier rule).
func remove_from_loadout(talent_id: StringName, champion: ChampionData) -> void:
	if not loadout.has(talent_id):
		return
	loadout.erase(talent_id)
	_drop_orphans(champion)


## Respec: free (Ryan, 2026-09-30).
func clear_loadout() -> void:
	loadout.clear()


## Fixes a loadout the data no longer allows (a saved one after a retune), in
## order: unknown ids, locked talents, a second exclusive sibling, a tier
## without the tier above it, then anything past the points (from the end).
## Returns one warning per change.
func sanitize_loadout(champion: ChampionData, leveling: ChampionLeveling) -> PackedStringArray:
	var warnings := PackedStringArray()
	var kept: Array[StringName] = []
	for id in loadout:
		var t := champion.get_talent(id)
		if t == null:
			warnings.append("'%s' isn't one of %s's talents" % [id, champion.id])
		elif not is_unlocked(id):
			warnings.append("'%s' is locked" % id)
		elif kept.has(id):
			warnings.append("'%s' is listed twice" % id)
		elif kept.any(func(k: StringName) -> bool: return t.exclusive and t.is_sibling_of(champion.get_talent(k))):
			warnings.append("'%s' is an exclusive sibling of a talent earlier in the loadout" % id)
		else:
			kept.append(id)
	loadout = kept
	var before := loadout.duplicate()
	_drop_orphans(champion)
	for id in before:
		if not loadout.has(id):
			warnings.append("'%s' lost the talent in the tier above it" % id)
	var points := get_talent_points(leveling)
	while loadout.size() > points:
		warnings.append("'%s' is over the %d talent point(s)" % [loadout[-1], points])
		loadout.remove_at(loadout.size() - 1)
		_drop_orphans(champion)
	return warnings


func _has_tier(champion: ChampionData, group: Talent.Group, tier: int) -> bool:
	for id in loadout:
		var t := champion.get_talent(id)
		if t != null and t.group == group and t.tier == tier:
			return true
	return false


func _exclusive_sibling_in_loadout(talent: Talent, champion: ChampionData) -> Talent:
	for id in loadout:
		var other := champion.get_talent(id)
		if other != null and talent.is_sibling_of(other) and (talent.exclusive or other.exclusive):
			return other
	return null


## Drops talents whose tier above isn't in the loadout, until none are left.
func _drop_orphans(champion: ChampionData) -> void:
	var changed := true
	while changed:
		changed = false
		for id in loadout.duplicate():
			var t := champion.get_talent(id)
			if t != null and t.tier > 1 and not _has_tier(champion, t.group, t.tier - 1):
				loadout.erase(id)
				changed = true


# --- Saving ------------------------------------------------------------------------

## Writes this record as one section of `cfg` (its champion id).
func write_to(cfg: ConfigFile) -> void:
	var section := String(champion_id)
	cfg.set_value(section, "level", level)
	cfg.set_value(section, "xp", xp)
	cfg.set_value(section, "ability_uses", _string_keys(ability_uses))
	cfg.set_value(section, "kills", kills)
	cfg.set_value(section, "kills_by_tag", _string_keys(kills_by_tag))
	cfg.set_value(section, "unlocked", _strings(unlocked))
	cfg.set_value(section, "loadout", _strings(loadout))


## The record saved in `cfg` for `champion`, or null if it has none.
static func read_from(cfg: ConfigFile, champion: ChampionData) -> ChampionProgress:
	var section := String(champion.id)
	if not cfg.has_section(section):
		return null
	var p := ChampionProgress.new()
	p.champion_id = champion.id
	p.level = maxi(int(cfg.get_value(section, "level", 1)), 1)
	p.xp = maxi(int(cfg.get_value(section, "xp", 0)), 0)
	p.ability_uses = _name_keys(cfg.get_value(section, "ability_uses", {}))
	p.kills = maxi(int(cfg.get_value(section, "kills", 0)), 0)
	p.kills_by_tag = _name_keys(cfg.get_value(section, "kills_by_tag", {}))
	p.unlocked = _names(cfg.get_value(section, "unlocked", []))
	p.loadout = _names(cfg.get_value(section, "loadout", []))
	return p


static func _string_keys(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[String(k)] = int(d[k])
	return out


static func _name_keys(v: Variant) -> Dictionary:
	var out := {}
	if v is Dictionary:
		for k in v:
			out[StringName(str(k))] = int(v[k])
	return out


static func _strings(a: Array[StringName]) -> PackedStringArray:
	var out := PackedStringArray()
	for s in a:
		out.append(String(s))
	return out


static func _names(v: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if v is Array or v is PackedStringArray:
		for s in v:
			out.append(StringName(str(s)))
	return out
