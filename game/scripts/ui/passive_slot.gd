extends Control
## The champion's passive on the HUD (CHAMPIONS CH6, functional only): a slot
## the size of an ability slot, left of Q, with the passive's initials in its
## icon_color and, on hover, a tooltip in the ability tooltip's style: the
## name, the description and one "Now:" line per StatScaling with its current
## value (Unbroken: "Now: +18% attack damage"). Placeholder look; the art pass
## and UI.md replace it. Added by hud.gd's setup_abilities() only when the
## player's champion has a passive.

const AbilityBar := preload("res://scripts/ui/ability_bar.gd")
const SLOT := AbilityBar.SLOT
const GAP := AbilityBar.GAP
const TOOLTIP_WIDTH := 220.0

var player: Player

var _hover: bool = false
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(SLOT, SLOT)
	size = custom_minimum_size
	# Left of the ability bar (4 slots and 3 gaps, centered), one gap away.
	var bar_half := (SLOT * 4 + GAP * 3) * 0.5
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -bar_half - GAP - SLOT
	offset_right = -bar_half - GAP
	offset_top = -SLOT - 8
	offset_bottom = -8


func get_passive() -> Passive:
	if player == null or not is_instance_valid(player) or player.champion == null:
		return null
	return player.champion.passive


## True while the mouse is over the slot (the tooltip shows).
func is_hovered() -> bool:
	return _hover


## The tooltip's text lines before wrapping: the name, the description, one
## "Now:" line per stat scaling the passive has attached (one a talent replaces
## shows none), then per active PASSIVE talent (TALENTS T1): its name, a
## "Replaces <passive>'s <stat>" line per replaced stat, and a "Now:" line per
## scaling it adds. So the slot never shows a bonus the champion doesn't have.
## Tests read it.
func get_tooltip_lines() -> PackedStringArray:
	var out := PackedStringArray()
	var passive := get_passive()
	if passive == null:
		return out
	out.append(passive.display_name)
	out.append(passive.description)
	var left_out := player.get_left_out_passive_stats()
	for s in passive.stat_scalings:
		if s != null and s.modifier != null and not left_out.has(s.modifier.stat):
			out.append("Now: %s" % _scaling_text(s))
	for talent in player.get_active_talents():
		if talent.group != Talent.Group.PASSIVE:
			continue
		out.append("%s (talent)" % talent.display_name)
		for stat in talent.replaces_passive_stats:
			out.append("Replaces %s's %s" % [passive.display_name, _stat_name(stat)])
		for s in talent.stat_scalings:
			if s != null and s.modifier != null:
				out.append("Now: %s" % _scaling_text(s))
	return out


func _scaling_text(s: StatScaling) -> String:
	var value := s.get_value(player)
	var stat_name := _stat_name(s.modifier.stat)
	if s.modifier.type == StatModifier.Type.FLAT:
		return "%+d %s" % [roundi(value), stat_name]
	return "%+d%% %s" % [roundi(value * 100.0), stat_name]


## The registry's display name in lower case ("attack damage"), else the id.
func _stat_name(stat: StringName) -> String:
	var def := player.stats_component.registry.get_definition(stat) if player.stats_component else null
	if def != null and def.display_name != "":
		return def.display_name.to_lower()
	return String(stat)


func _process(_delta: float) -> void:
	_hover = Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position())
	queue_redraw()


func _draw() -> void:
	var passive := get_passive()
	if passive == null:
		return
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect.grow(1), Color(0, 0, 0, 0.8))
	draw_rect(rect, passive.icon_color.darkened(0.55))
	draw_rect(rect.grow(-3), passive.icon_color.darkened(0.25))
	draw_string(_font, Vector2(0, SLOT * 0.62), _initials(passive.display_name),
		HORIZONTAL_ALIGNMENT_CENTER, SLOT, 11, Color(1, 1, 1, 0.95))
	draw_rect(rect, Color(1, 1, 1, 0.25), false, 1.0)
	if _hover:
		_draw_tooltip(passive)


func _draw_tooltip(passive: Passive) -> void:
	var lines := get_tooltip_lines()
	var body := PackedStringArray()
	body.append_array(_wrap(lines[1], TOOLTIP_WIDTH - 12, 8))
	var now_lines := lines.slice(2)
	var h := 30.0 + (body.size() + now_lines.size()) * 10.0
	var x := maxf(-position.x + 4, 0.0)
	var rect := Rect2(x, -h - 6, TOOLTIP_WIDTH, h)
	draw_rect(rect, Color(0.05, 0.05, 0.08, 0.95))
	draw_rect(rect, Color(passive.icon_color, 0.8), false, 1.0)
	draw_string(_font, rect.position + Vector2(6, 12), "%s  [Passive]" % lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, passive.icon_color.lightened(0.3))
	draw_string(_font, rect.position + Vector2(6, 22), "Always active", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.75, 0.75, 0.8))
	var y := 34.0
	for line in body:
		draw_string(_font, rect.position + Vector2(6, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.9))
		y += 10.0
	for line in now_lines:
		# "Now:" lines gold; a talent's name and its "Replaces" lines pale blue.
		var color := Color(1, 0.85, 0.4) if line.begins_with("Now:") else Color(0.6, 0.8, 1.0)
		draw_string(_font, rect.position + Vector2(6, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color)
		y += 10.0


func _initials(name_text: String) -> String:
	var out := ""
	for word in name_text.split(" ", false):
		out += word.substr(0, 1).to_upper()
	return out.substr(0, 2)


func _wrap(text: String, max_w: float, font_size: int) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in text.split(" ", false):
		var test := word if line == "" else line + " " + word
		if _font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_w and line != "":
			out.append(line)
			line = word
		else:
			line = test
	if line != "":
		out.append(line)
	return out
