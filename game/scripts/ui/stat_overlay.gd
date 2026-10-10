class_name StatOverlay
extends CanvasLayer
## STATS step 7: the F3 debug overlay (Main adds it in debug builds). It shows
## one unit's stats, the tracked champion's unless Shift+F3 picked another:
## every registered stat with its base (UnitStats or the registry default,
## plus growth), its final value (get_stat()) and each modifier on it with
## its source. A final value the formula alone doesn't give says why (a
## clamp, an integer stat's rounding, move_speed's strongest slow and soft
## caps). Then every scoped modifier (an ability's param, or a stat that
## counts only for some hits: STATS.md, Scoped modifiers) with its scope and
## source. F3 (the action debug_stat_overlay) shows and hides it; Shift+F3
## while it shows reads the unit under the cursor, or the champion again over
## nothing. It only reads: it never changes a stat. It works while paused.

const ACTION := &"debug_stat_overlay"
const TEXT_COLOR := Color(0.92, 0.92, 0.92)
const HINT_COLOR := Color(0.65, 0.65, 0.7)
const UP_COLOR := Color(0.55, 0.95, 0.55)
const DOWN_COLOR := Color(1.0, 0.55, 0.45)
const FONT_SIZE := 8
const PANEL_WIDTH := 250.0
## The list scrolls inside this height (px), so the panel ends above the
## ability bar in the 360 px canvas.
const LIST_HEIGHT := 236.0

## Seconds between refreshes while it shows.
@export var refresh_interval: float = 0.25

var _title: Label
var _body: RichTextLabel
var _pinned: Unit = null
var _refresh_left := 0.0
var _text := ""   # the body as plain text, as last built


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(ACTION):
		return
	var key := event as InputEventKey
	if key != null and key.shift_pressed and is_open():
		pin(_unit_under_cursor())
	else:
		set_open(not is_open())
	get_viewport().set_input_as_handled()


func is_open() -> bool:
	return visible


func set_open(open: bool) -> void:
	visible = open
	if open:
		refresh()


## Reads `unit` from now on; null (or a unit that's gone) reads the tracked
## champion again.
func pin(unit: Unit) -> void:
	_pinned = unit
	refresh()


## The unit it reads now: the pinned one, else the tracked champion (null
## with neither).
func get_unit() -> Unit:
	if is_instance_valid(_pinned):
		return _pinned
	return Progress.get_tracked_player()


## The panel's title as last built ("Stats: Knight").
func get_title() -> String:
	return _title.text


## The body as plain text, as last built (what the panel shows, without
## colors or columns).
func get_text() -> String:
	return _text


## Rebuilds the panel from the unit's StatsComponent now.
func refresh() -> void:
	_refresh_left = refresh_interval
	var unit := get_unit()
	if unit == null or unit.stats_component == null:
		_title.text = "Stats: no unit"
		_body.text = ""
		_text = ""
		return
	var stats := unit.stats_component
	_title.text = "Stats: %s" % get_unit_label(unit)
	_body.text = get_bbcode(stats)
	_text = get_plain_text(stats)


# --- What it reads (static, so the stats test reads it without a unit) -------------

## One row per registered stat of `stats`, in the registry's order: {key,
## base, final, formula (the formula's value before clamps and rounding),
## mods (the unscoped modifiers on it, in the order added), note (why final
## isn't the formula's value; "" when it is)}.
static func get_rows(stats: StatsComponent) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var mods := stats.get_modifiers()
	for key in stats.registry.get_keys():
		var def := stats.registry.get_definition(key)
		var base := stats.get_base_value(key)
		var flat := 0.0
		var percent_add := 0.0
		var percent_mult := 1.0
		var own: Array[StatModifier] = []
		for mod in mods:
			if mod.stat != key or mod.is_scoped():
				continue
			own.append(mod)
			match mod.type:
				StatModifier.Type.FLAT:
					flat += mod.value
				StatModifier.Type.PERCENT_ADD:
					percent_add += mod.value
				StatModifier.Type.PERCENT_MULT:
					percent_mult *= 1.0 + mod.value
		var formula := (base + flat) * (1.0 + percent_add) * percent_mult
		var final := stats.get_stat(key)
		rows.append({"key": key, "base": base, "final": final, "formula": formula, "mods": own,
			"note": get_note(stats, def, formula, final)})
	return rows


## Every scoped modifier on `stats`, in the order added: an ability param's
## (scope ability:<id> or tag:<tag>) or a stat's that counts only for some
## hits (hit:<tag>, target:<tag>).
static func get_scoped_modifiers(stats: StatsComponent) -> Array[StatModifier]:
	var out: Array[StatModifier] = []
	for mod in stats.get_modifiers():
		if mod.is_scoped():
			out.append(mod)
	return out


## Why a stat's final value isn't its formula's: "" when it is; else the
## clamp to its limits (or its per-unit max field), an integer stat's
## rounding, or move_speed's own rules (only the strongest slow counts, then
## the soft caps), each with the formula's value.
static func get_note(stats: StatsComponent, def: StatDefinition, formula: float, final: float) -> String:
	if absf(formula - final) < 0.0005:
		return ""
	if def.key == &"move_speed":
		return "strongest slow, soft caps (formula %s)" % _format_number(formula)
	var low := def.min_value if def.has_min else -INF
	var high := def.max_value if def.has_max else INF
	if def.max_field != &"" and stats.base_stats != null:
		var field: Variant = stats.base_stats.get(def.max_field)
		if field != null:
			high = float(field)
	if absf(clampf(formula, low, high) - formula) >= 0.0005:
		return "clamped (formula %s)" % _format_number(formula)
	if def.is_integer:
		return "rounded (formula %s)" % _format_number(formula)
	return "formula %s" % _format_number(formula)


## A modifier's amount as the overlay shows it: FLAT in its stat's format
## ("+12", "+10%"), PERCENT_ADD "+20% inc" (increased), PERCENT_MULT
## "x1.20 more". `def` is null for an ability param (a plain number).
static func format_modifier(mod: StatModifier, def: StatDefinition) -> String:
	match mod.type:
		StatModifier.Type.PERCENT_ADD:
			return "%s%s%% inc" % ["+" if mod.value >= 0.0 else "-", _format_number(absf(mod.value) * 100.0)]
		StatModifier.Type.PERCENT_MULT:
			return "x%.2f more" % (1.0 + mod.value)
	var amount := absf(mod.value)
	var text := format_stat(def, amount) if def != null and not def.is_integer else _format_number(amount)
	return ("+" if mod.value >= 0.0 else "-") + text


## A stat's value as the overlay shows it, shorter than
## StatDefinition.format_value() (no ".0"): NUMBER "64" / "133.2", an integer
## stat "2", PERCENT "25%", DECIMAL "0.70", PER_SECOND "1.5/s".
static func format_stat(def: StatDefinition, value: float) -> String:
	match def.format:
		StatDefinition.Format.PERCENT:
			return _format_number(value * 100.0) + "%"
		StatDefinition.Format.DECIMAL:
			return "%.2f" % value
		StatDefinition.Format.PER_SECOND:
			return _format_number(value) + "/s"
	if def.is_integer:
		return str(roundi(value))
	return _format_number(value)


## The body as plain text: a line per stat ("attack_damage  base 64  final
## 76.8", its note in brackets), a line per modifier under it ("  source
## amount"), then the scoped ones ("stat amount @ scope (source)").
static func get_plain_text(stats: StatsComponent) -> String:
	var lines: PackedStringArray = []
	for row in get_rows(stats):
		var def := stats.registry.get_definition(row.key)
		var line := "%s  base %s  final %s" % [row.key, format_stat(def, row.base), format_stat(def, row.final)]
		var note: String = row.note
		if note != "":
			line += "  (%s)" % note
		lines.append(line)
		for mod: StatModifier in row.mods:
			lines.append("  %s %s" % [mod.source_id, format_modifier(mod, def)])
	var scoped := get_scoped_modifiers(stats)
	if not scoped.is_empty():
		lines.append("Scoped:")
		for mod in scoped:
			lines.append(_scoped_line(stats, mod))
	return "\n".join(lines)


## The body as the panel shows it: a three-column table (stat or source,
## base or amount, final; a final above its base green, below it red), then
## the scoped modifiers as lines.
static func get_bbcode(stats: StatsComponent) -> String:
	var hint := HINT_COLOR.to_html(false)
	var s := "[table=3][cell][color=#%s]stat[/color][/cell][cell][color=#%s]base  [/color][/cell][cell][color=#%s]final[/color][/cell]" % [hint, hint, hint]
	for row in get_rows(stats):
		var def := stats.registry.get_definition(row.key)
		var base: float = row.base
		var final: float = row.final
		var color := TEXT_COLOR
		if final > base + 0.0005:
			color = UP_COLOR
		elif final < base - 0.0005:
			color = DOWN_COLOR
		s += "[cell]%s  [/cell][cell]%s  [/cell][cell][color=#%s]%s[/color][/cell]" % [row.key, format_stat(def, base), color.to_html(false), format_stat(def, final)]
		for mod: StatModifier in row.mods:
			s += "[cell][color=#%s]  %s[/color][/cell][cell]%s  [/cell][cell][/cell]" % [hint, mod.source_id, format_modifier(mod, def)]
		var note: String = row.note
		if note != "":
			s += "[cell][color=#%s]  %s[/color][/cell][cell][/cell][cell][/cell]" % [hint, note]
	s += "[/table]"
	var scoped := get_scoped_modifiers(stats)
	if not scoped.is_empty():
		s += "\n[color=#%s]Scoped (only the abilities or hits they name):[/color]" % hint
		for mod in scoped:
			s += "\n" + _scoped_line(stats, mod)
	return s


## A unit's name for the title: its champion's or its enemy data's display
## name, else its node's name.
static func get_unit_label(unit: Unit) -> String:
	var champion: Variant = unit.get(&"champion")
	if champion is ChampionData and (champion as ChampionData).display_name != "":
		return (champion as ChampionData).display_name
	var enemy := unit as Enemy
	if enemy != null and enemy.data != null and enemy.data.display_name != "":
		return enemy.data.display_name
	return String(unit.name)


static func _scoped_line(stats: StatsComponent, mod: StatModifier) -> String:
	var def: StatDefinition = stats.registry.get_definition(mod.stat) if stats.registry.has_stat(mod.stat) else null
	return "%s %s @ %s (%s)" % [mod.stat, format_modifier(mod, def), mod.scope, mod.source_id]


## A number with at most two decimals and no trailing ".0" (64, 133.2, 2.25).
static func _format_number(value: float) -> String:
	var rounded := snappedf(value, 0.01)
	if is_equal_approx(rounded, roundf(rounded)):
		return str(roundi(rounded))
	return str(rounded)


func _unit_under_cursor() -> Unit:
	var view := WorldView.of(self)
	if view == null:
		return null
	return view.unit_under_cursor(func(u: Unit) -> bool: return u.stats_component != null)


func _build() -> void:
	var panel := PanelContainer.new()
	panel.offset_left = 6.0
	panel.offset_top = 42.0   # under the HUD's info line (it ends at 38)
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS   # clicks over it still reach the game
	var style := StyleBoxFlat.new()   # opaque: it sits over the sandbox's left-hand lines
	style.bg_color = Color(0.08, 0.08, 0.1, 0.98)
	style.set_content_margin_all(4.0)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(box)
	_title = _label("Stats", TEXT_COLOR)
	box.add_child(_title)
	box.add_child(_label("F3 hides it. Shift+F3: the unit under the cursor.", HINT_COLOR))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(PANEL_WIDTH, LIST_HEIGHT)
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(scroll)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.mouse_filter = Control.MOUSE_FILTER_PASS
	_body.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_body.add_theme_color_override("default_color", TEXT_COLOR)
	scroll.add_child(_body)


func _label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
