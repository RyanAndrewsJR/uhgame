class_name TalentScreen
extends HBoxContainer
## The hub's talent list (TALENTS T5, functional only: UI.md and the art pass
## replace it). Five columns, Q, W, E, R and the passive, each headed by its
## ability's (or the passive's) name, its tiers top to bottom. Every talent is
## shown, locked or not, as a button:
##   ACTIVE    in the loadout (gold). Click: take it out.
##   AVAILABLE unlocked and can go in. Click: put it in (an exclusive sibling
##             swaps out).
##   LOCKED    grey; one line per requirement with its live count, met ones
##             marked "met".
##   BLOCKED   unlocked, but the tier rule or the points stop it; the reason.
## Every change goes through Progress (the record's rules, then a save). The
## description shows in the hub's detail line on hover (talent_hovered): the
## 640x360 screen can't fit twenty descriptions.

signal talent_hovered(talent: Talent)
signal loadout_changed

const COLUMN_WIDTH := 124.0
const FONT_SIZE := 8
const COLOR_ACTIVE := Color(1.0, 0.85, 0.35)
const COLOR_AVAILABLE := Color(1, 1, 1)
const COLOR_LOCKED := Color(0.55, 0.55, 0.6)
const COLOR_BLOCKED := Color(0.85, 0.6, 0.5)

var champion: ChampionData

var _buttons: Dictionary = {}   # talent id -> Button


## Builds the columns for `p_champion` and fills them.
func setup(p_champion: ChampionData) -> void:
	champion = p_champion
	for child in get_children():
		child.queue_free()
	_buttons.clear()
	add_theme_constant_override("separation", 3)
	for group in [Talent.Group.Q, Talent.Group.W, Talent.Group.E, Talent.Group.R, Talent.Group.PASSIVE]:
		add_child(_build_column(group))
	refresh()


## Re-reads the record: every button's state and lines.
func refresh() -> void:
	if champion == null:
		return
	for id: StringName in _buttons:
		var button: Button = _buttons[id]
		var lines := get_lines(id)
		button.text = "\n".join(lines)
		var color: Color = {
			"active": COLOR_ACTIVE, "available": COLOR_AVAILABLE,
			"locked": COLOR_LOCKED, "blocked": COLOR_BLOCKED,
		}[get_state(id)]
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(key, color)


## "active", "available", "locked" or "blocked".
func get_state(talent_id: StringName) -> String:
	var record := Progress.get_progress(champion)
	if record.loadout.has(talent_id):
		return "active"
	if not record.is_unlocked(talent_id):
		return "locked"
	var reason := record.get_loadout_fail_reason(champion.get_talent(talent_id), champion, champion.get_leveling())
	return "available" if reason == "" else "blocked"


## The button's lines: the name and its state tag, then the requirement lines
## (locked) or the reason (blocked).
func get_lines(talent_id: StringName) -> PackedStringArray:
	var t := champion.get_talent(talent_id)
	var record := Progress.get_progress(champion)
	var lines := PackedStringArray()
	match get_state(talent_id):
		"active":
			lines.append("%s  [ON]" % t.display_name)
		"available":
			lines.append(t.display_name)
		"locked":
			lines.append("%s  [LOCKED]" % t.display_name)
			for req in t.requirements:
				if req == null:
					continue
				var line := "%s %d / %d" % [req.get_label(t, champion), mini(req.get_current(record, t, champion), req.amount), req.amount]
				lines.append(line + (" — met" if req.is_met(record, t, champion) else ""))
		"blocked":
			lines.append("%s  [BLOCKED]" % t.display_name)
			lines.append(_reason_text(t, record.get_loadout_fail_reason(t, champion, champion.get_leveling())))
	return lines


## Clicks a talent: out if active, in if available (an exclusive sibling
## swaps out). Returns whether the loadout changed.
func press(talent_id: StringName) -> bool:
	var changed := false
	match get_state(talent_id):
		"active":
			Progress.remove_from_loadout(champion, talent_id)
			changed = true
		"available":
			changed = Progress.add_to_loadout(champion, champion.get_talent(talent_id))
	if changed:
		refresh()
		loadout_changed.emit()
	return changed


func _build_column(group: Talent.Group) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
	column.add_theme_constant_override("separation", 2)
	column.add_child(_label("%s  %s" % [Talent.Group.keys()[group], _group_name(group)], 9, Color(0.9, 0.9, 1.0)))
	var talents := champion.talents.filter(func(t: Talent) -> bool: return t != null and t.group == group)
	talents.sort_custom(func(a: Talent, b: Talent) -> bool: return a.tier < b.tier)
	var tier := 0
	for t: Talent in talents:
		if t.tier != tier:
			tier = t.tier
			column.add_child(_label("Tier %d — pick one" % tier if t.exclusive else "Tier %d" % tier, 7, Color(0.7, 0.7, 0.75)))
		var button := Button.new()
		button.name = String(t.id)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", FONT_SIZE)
		button.pressed.connect(press.bind(t.id))
		button.mouse_entered.connect(func() -> void: talent_hovered.emit(t))
		column.add_child(button)
		_buttons[t.id] = button
	return column


func _group_name(group: Talent.Group) -> String:
	if group == Talent.Group.PASSIVE:
		return champion.passive.display_name if champion.passive != null else "Passive"
	var probe := Talent.new()
	probe.group = group
	var ability := probe.get_group_ability(champion)
	return ability.display_name if ability != null else "?"


func _reason_text(t: Talent, reason: String) -> String:
	if reason == "no points":
		return "No talent points left"
	if reason.begins_with("needs tier"):
		return "Needs a tier %d %s talent" % [t.tier - 1, _group_name(t.group)]
	return reason


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
