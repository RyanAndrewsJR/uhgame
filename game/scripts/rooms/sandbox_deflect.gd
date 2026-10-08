class_name SandboxDeflect
extends Node
## Sandbox only. PROTOTYPE (Ryan, 2026-10-07): the dash-deflect, riposte and
## enemy poise prototype, tested on the Knight. Its flags are off in shipped
## config; this node turns them on while the sandbox runs (never in a test
## scene) and puts back what it found when it leaves, its panel's edits to
## shared data included. Raw keys, read here (no input action, like
## SandboxBrains'):
##   V        the deflect flag (DeflectComponent.deflect_test_enabled) on/off
##   Shift+V  the poise flag (PoiseComponent.poise_test_enabled) on/off
##   M        its tuning panel: every number of the prototype, live (the
##            Knight's DeflectComponent; every enemy's PoiseComponent, new ones
##            too; the poise damage of the Knight's swings, Cleave and
##            Judgement in memory; the TEMP weak-auto lever)
## Readouts (placeholders, drawn over the 3D view; they never decide state):
## a thin poise bar under the health bar of any unit whose meter runs (gold;
## orange draining while broken; grey while immune), and under the Knight's
## health bar his dash charges (the refunded one gold), his deflect streak
## (two pips) and "RIPOSTE" while it's ready. The TEMP weak-auto lever
## (AutoAttackComponent.prototype_unempowered_auto_mult) starts at its export
## here. It never touches the player's saves.

const TEXT_COLOR := Color(0.92, 0.92, 0.92)
const HINT_COLOR := Color(0.65, 0.65, 0.7)
const POISE_COLOR := Color(0.95, 0.82, 0.4)
const BROKEN_COLOR := Color(1.0, 0.45, 0.15)
const IMMUNE_COLOR := Color(0.6, 0.6, 0.66)
const DASH_COLOR := Color(0.5, 0.9, 1.0)
## The panel's slider list height (px): it scrolls, so the panel ends inside
## the 360 px canvas (SandboxBrains' rule).
const SLIDER_LIST_HEIGHT := 176.0
## The swings, Cleave and Judgement whose poise damage the panel edits. Plain
## vars, not consts: a read through a const chain is folded when the script
## compiles, so it would never see the edits.
var _combo_knight: AttackCombo = preload("res://data/combos/combo_knight.tres")
var _cleaves: Array[Ability] = [preload("res://data/abilities/knight_q_cleave.tres"), preload("res://data/abilities/knight_q_cleave_wave.tres")]
var _judgements: Array[Ability] = [preload("res://data/abilities/knight_r_judgement.tres"), preload("res://data/abilities/knight_r_judgement_leap.tres")]
## The enemies with a meter (their EnemyData.poise_max is what the panel's
## poise_max row edits, so new ones spawn with it).
var _poise_data: Array[EnemyData] = [preload("res://data/enemies/enemy_slime_elite.tres"), preload("res://data/enemies/enemy_test_duelist.tres")]
## The DeflectComponent rows: [export, min, max, step].
const DEFLECT_ROWS: Array = [
	["deflect_window", 0.05, 0.30, 0.01], ["chain_window", 0.5, 8.0, 0.1], ["refund_lifetime", 0.5, 6.0, 0.1],
	["deflect_test_charge_recharge", 0.2, 4.0, 0.05], ["riposte_ad_ratio", 0.0, 6.0, 0.1], ["riposte_window", 0.5, 4.0, 0.1],
	["riposte_snap_range", 0.0, 600.0, 10.0], ["deflect_poise_damage_first", 0.0, 100.0, 1.0],
	["deflect_poise_damage_second", 0.0, 100.0, 1.0], ["riposte_poise_damage", 0.0, 100.0, 1.0],
	["deflect_hitstop", 0.0, 0.2, 0.01], ["deflect_shake", 0.0, 6.0, 0.1],
]
## The PoiseComponent rows (every enemy's): [export, min, max, step].
const POISE_ROWS: Array = [
	["poise_regen_delay", 0.0, 6.0, 0.1], ["poise_regen_rate", 0.0, 60.0, 1.0], ["poise_break_time", 0.3, 4.0, 0.1],
	["poise_break_damage_bonus", 0.0, 2.0, 0.05], ["poise_break_immunity", 0.0, 10.0, 0.5],
]

## The deflect flag this sandbox starts with.
@export var deflect_test_enabled: bool = true
## The poise flag this sandbox starts with.
@export var poise_test_enabled: bool = true
## TEMP: the weak-auto lever this sandbox starts with (1.0 = off).
@export_range(0.2, 1.0, 0.05) var prototype_unempowered_auto_mult: float = 0.5
## The readouts are on at the start.
@export var readouts_on: bool = true

var _previous: Array = []   # [deflect flag, poise flag, weak-auto lever] as found
var _readout_layer: CanvasLayer
var _readout: Node2D
var _panel_layer: CanvasLayer
var _deflect_check: CheckBox
var _poise_check: CheckBox
var _rows: Dictionary = {}   # key -> {slider: HSlider, value: Label, getter: Callable, setter: Callable}
var _syncing := false
var _poise_values: Dictionary = {}   # PoiseComponent export -> the panel's value (every enemy, new ones too)
var _originals: Dictionary = {}   # [resource, property] key String -> [resource, property, value] before any edit


func _ready() -> void:
	_previous = [DeflectComponent.deflect_test_enabled, PoiseComponent.poise_test_enabled,
		AutoAttackComponent.prototype_unempowered_auto_mult]
	_readout_layer = CanvasLayer.new()
	_readout_layer.layer = 2
	add_child(_readout_layer)
	_readout = Node2D.new()
	_readout.name = "DeflectReadouts"
	_readout.draw.connect(_draw_readouts)
	_readout_layer.add_child(_readout)
	_readout_layer.visible = readouts_on
	get_tree().node_added.connect(_on_node_added)
	if Progress.is_test_scene():
		return   # a test sets its own
	DeflectComponent.deflect_test_enabled = deflect_test_enabled
	PoiseComponent.poise_test_enabled = poise_test_enabled
	AutoAttackComponent.prototype_unempowered_auto_mult = prototype_unempowered_auto_mult
	print("SandboxDeflect: ", get_status_text(), " (V: deflect, Shift+V: poise, M: the panel)")


func _exit_tree() -> void:
	for entry: Array in _originals.values():   # the shared data the panel edited, as it was
		(entry[0] as Object).set(entry[1], entry[2])
	_originals.clear()
	if _previous.is_empty() or Progress.is_test_scene():
		return
	DeflectComponent.deflect_test_enabled = _previous[0]
	PoiseComponent.poise_test_enabled = _previous[1]
	AutoAttackComponent.prototype_unempowered_auto_mult = _previous[2]


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_V:
			if key.shift_pressed:
				set_poise_enabled(not PoiseComponent.poise_test_enabled)
			else:
				set_deflect_enabled(not DeflectComponent.deflect_test_enabled)
		KEY_M:
			set_panel(not is_panel_open())
		_:
			return
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _readout_layer.visible:
		_readout.queue_redraw()
	if is_panel_open():
		_update_values()


func set_deflect_enabled(on: bool) -> void:
	DeflectComponent.deflect_test_enabled = on
	_sync_checks()
	print("SandboxDeflect: ", get_status_text())


func set_poise_enabled(on: bool) -> void:
	PoiseComponent.poise_test_enabled = on
	_sync_checks()
	print("SandboxDeflect: ", get_status_text())


## One line: the flags and the lever now.
func get_status_text() -> String:
	return "deflect %s, poise %s, weak autos x%.2f" % ["ON" if DeflectComponent.deflect_test_enabled else "off",
		"ON" if PoiseComponent.poise_test_enabled else "off", AutoAttackComponent.prototype_unempowered_auto_mult]


## The Knight the panel tunes and the readouts follow: the tracked player.
func get_knight() -> Player:
	return Progress.get_tracked_player()


# --- The panel (M) ----------------------------------------------------------------

func is_panel_open() -> bool:
	return _panel_layer != null and _panel_layer.visible


func set_panel(open: bool) -> void:
	if open and _panel_layer == null:
		_build_panel()
	if _panel_layer != null:
		_panel_layer.visible = open
	if open:
		_sync_panel()


## The panel's row keys, in order.
func get_row_keys() -> Array[StringName]:
	var keys: Array[StringName] = []
	for key: StringName in _rows:
		keys.append(key)
	return keys


## A row's value now (what its slider shows).
func get_value(key: StringName) -> float:
	var row: Dictionary = _rows.get(key, {})
	return float((row["getter"] as Callable).call()) if not row.is_empty() else 0.0


## Sets a row's value, live (what moving its slider does).
func set_value(key: StringName, value: float) -> void:
	var row: Dictionary = _rows.get(key, {})
	if row.is_empty():
		return
	(row["setter"] as Callable).call(value)
	_sync_panel()


func _build_panel() -> void:
	_panel_layer = CanvasLayer.new()
	_panel_layer.layer = 3
	add_child(_panel_layer)
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -262.0
	panel.offset_right = -6.0
	panel.offset_top = 66.0
	var style := StyleBoxFlat.new()   # opaque: it sits over SandboxLoot's list
	style.bg_color = Color(0.08, 0.08, 0.1, 0.94)
	style.set_content_margin_all(4.0)
	panel.add_theme_stylebox_override("panel", style)
	_panel_layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)
	box.add_child(_small_label("Deflect / poise prototype (M)"))
	_deflect_check = _check_box("deflect (V)", func(on: bool) -> void: set_deflect_enabled(on))
	box.add_child(_deflect_check)
	_poise_check = _check_box("poise (Shift+V)", func(on: bool) -> void: set_poise_enabled(on))
	box.add_child(_poise_check)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, SLIDER_LIST_HEIGHT)
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	_heading(list, "the Knight's deflect")
	for r: Array in DEFLECT_ROWS:
		var p: StringName = StringName(r[0])
		_add_row(list, p, r[1], r[2], r[3], _get_deflect.bind(p), _set_deflect.bind(p))
	_heading(list, "every enemy's poise")
	_add_row(list, &"poise_max", 0.0, 400.0, 5.0, _get_poise_max, _set_poise_max)
	for r: Array in POISE_ROWS:
		var p: StringName = StringName(r[0])
		_add_row(list, p, r[1], r[2], r[3], _get_poise.bind(p), _set_poise.bind(p))
	_heading(list, "poise damage (in memory)")
	_add_row(list, &"swing_poise", 0.0, 30.0, 1.0, func() -> float: return _combo_knight.swings[0].poise_damage, _set_swing_poise)
	_add_row(list, &"cleave_poise", 0.0, 100.0, 1.0, func() -> float: return _cleaves[0].poise_damage, _set_ability_poise.bind(_cleaves))
	_add_row(list, &"judgement_poise", 0.0, 100.0, 1.0, func() -> float: return _judgements[0].poise_damage, _set_ability_poise.bind(_judgements))
	_heading(list, "TEMP")
	_add_row(list, &"weak_autos", 0.2, 1.0, 0.05, func() -> float: return AutoAttackComponent.prototype_unempowered_auto_mult,
		func(v: float) -> void: AutoAttackComponent.prototype_unempowered_auto_mult = v)
	var hint := _small_label("The wheel scrolls. Edits last while the sandbox runs.")
	hint.add_theme_color_override("font_color", HINT_COLOR)
	box.add_child(hint)


func _heading(list: VBoxContainer, text: String) -> void:
	var label := _small_label(text)
	label.add_theme_color_override("font_color", HINT_COLOR)
	list.add_child(label)


func _add_row(list: VBoxContainer, key: StringName, min_value: float, max_value: float, step: float,
		getter: Callable, setter: Callable) -> void:
	var row := HBoxContainer.new()
	var name_label := _small_label(String(key).replace("deflect_", ""))
	name_label.custom_minimum_size = Vector2(118, 0)
	name_label.clip_text = true
	row.add_child(name_label)
	var s := HSlider.new()
	s.min_value = min_value
	s.max_value = max_value
	s.step = step
	s.custom_minimum_size = Vector2(80, 10)
	s.scrollable = false   # the wheel scrolls the list (SandboxBrains' rule)
	s.value_changed.connect(func(v: float) -> void:
		if not _syncing:
			setter.call(v))
	row.add_child(s)
	var value_label := _small_label("")
	value_label.custom_minimum_size = Vector2(40, 0)
	row.add_child(value_label)
	list.add_child(row)
	_rows[key] = {"slider": s, "value": value_label, "getter": getter, "setter": setter}


func _small_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _check_box(text: String, on_toggled: Callable) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.add_theme_font_size_override("font_size", 8)
	box.toggled.connect(func(on: bool) -> void:
		if not _syncing:
			on_toggled.call(on))
	return box


func _sync_panel() -> void:
	if _panel_layer == null:
		return
	_syncing = true
	for key: StringName in _rows:
		(_rows[key].slider as HSlider).value = float((_rows[key]["getter"] as Callable).call())
	_syncing = false
	_sync_checks()
	_update_values()


func _sync_checks() -> void:
	if _deflect_check == null:
		return
	_syncing = true
	_deflect_check.button_pressed = DeflectComponent.deflect_test_enabled
	_poise_check.button_pressed = PoiseComponent.poise_test_enabled
	_syncing = false


func _update_values() -> void:
	for key: StringName in _rows:
		var v := float((_rows[key]["getter"] as Callable).call())
		(_rows[key].value as Label).text = str(snappedf(v, 1.0)) if absf(v) >= 100.0 else "%.2f" % v


# --- What the rows edit -------------------------------------------------------------

func _get_deflect(p: StringName) -> float:
	var knight := get_knight()
	return float(knight.deflect_component.get(p)) if knight != null and knight.deflect_component != null else 0.0


func _set_deflect(value: float, p: StringName) -> void:
	var knight := get_knight()
	if knight != null and knight.deflect_component != null:
		knight.deflect_component.set(p, value)


## Every live enemy's meter (and every new one's, _on_node_added()).
func _get_poise(p: StringName) -> float:
	if _poise_values.has(p):
		return _poise_values[p]
	var probe := PoiseComponent.new()
	var value := float(probe.get(p))
	probe.free()
	return value


func _set_poise(value: float, p: StringName) -> void:
	_poise_values[p] = value
	for poise in _live_poise_components():
		poise.set(p, value)


func _get_poise_max() -> float:
	return _poise_data[0].poise_max


## The size of every meter that has one: the data (new ones spawn with it)
## and the live meters above 0.
func _set_poise_max(value: float) -> void:
	for data in _poise_data:
		_edit(data, &"poise_max", value)
	for poise in _live_poise_components():
		if poise.poise_max > 0.0:
			poise.poise_max = value


func _set_swing_poise(value: float) -> void:
	for swing in _combo_knight.swings:
		_edit(swing, &"poise_damage", value)
	_edit(_combo_knight.dash_strike, &"poise_damage", value)


func _set_ability_poise(value: float, abilities: Array[Ability]) -> void:
	for a in abilities:
		_edit(a, &"poise_damage", value)


## Sets a shared resource's property, remembering what it was (put back on exit).
func _edit(resource: Resource, property: StringName, value: Variant) -> void:
	var key := "%d:%s" % [resource.get_instance_id(), property]
	if not _originals.has(key):
		_originals[key] = [resource, property, resource.get(property)]
	resource.set(property, value)


func _live_poise_components() -> Array[PoiseComponent]:
	var out: Array[PoiseComponent] = []
	for node in get_tree().get_nodes_in_group(&"units"):
		var u := node as Unit
		if u != null and u.poise_component != null:
			out.append(u.poise_component)
	return out


## A new enemy's meter takes the panel's numbers.
func _on_node_added(node: Node) -> void:
	if node is PoiseComponent:
		for p: StringName in _poise_values:
			node.set(p, _poise_values[p])


# --- Readouts -----------------------------------------------------------------------

func is_readouts_on() -> bool:
	return _readout_layer.visible


func set_readouts(on: bool) -> void:
	_readout_layer.visible = on


## Draws over the 3D view, where each unit's health bar is (ScreenOverlay).
func _draw_readouts() -> void:
	var view := WorldView.of(self)
	if view == null or view.screen_overlay == null:
		return
	var overlay := view.screen_overlay
	for node in get_tree().get_nodes_in_group(&"units"):
		var u := node as Unit
		if u == null or not u.is_alive():
			continue
		var bar := overlay.bar_of(u)
		if bar == null or not bar.visible:
			continue
		var below := bar.position + Vector2(0.0, float(bar.get(&"height")) + 2.0)
		var width := float(bar.get(&"width"))
		if u.poise_component != null and u.poise_component.get_max_poise() > 0.0:
			_draw_poise_bar(u.poise_component, below, width)
		if u.deflect_component != null and u == get_knight():
			_draw_knight(u as Player, below)


## A thin bar: poise (gold), the break draining (orange), immune (grey).
func _draw_poise_bar(poise: PoiseComponent, at: Vector2, width: float) -> void:
	var x := at.x - width * 0.5
	var share := poise.get_poise() / maxf(poise.get_max_poise(), 0.001)
	var color := POISE_COLOR
	if poise.is_broken():
		share = poise.get_break_left() / maxf(poise.poise_break_time, 0.001)
		color = BROKEN_COLOR
	elif poise.is_immune():
		color = IMMUNE_COLOR
	_readout.draw_rect(Rect2(x - 1.0, at.y - 1.0, width + 2.0, 4.0), Color(0, 0, 0, 0.85))
	_readout.draw_rect(Rect2(x, at.y, width * clampf(share, 0.0, 1.0), 2.0), color)


## Under the Knight's bar: his dash charges (the refunded one gold), his
## streak (two pips), RIPOSTE while it's ready.
func _draw_knight(knight: Player, at: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var dash := knight.dash
	var n := dash.get_max_charges()
	var y := at.y + 4.0
	for i in n:
		var pos := Vector2(at.x - 14.0 - (n - 1 - i) * 6.0, y)
		var filled := i < dash.get_charges()
		var color := POISE_COLOR if filled and dash.has_refund() and i == dash.get_charges() - 1 else DASH_COLOR
		if filled:
			_readout.draw_circle(pos, 2.0, color)
		else:
			_readout.draw_arc(pos, 2.0, 0.0, TAU, 12, Color(DASH_COLOR, 0.6), 1.0)
	var deflect := knight.deflect_component
	if not deflect.is_active():
		return
	for i in 2:
		var c := Vector2(at.x + 6.0 + i * 7.0, y)
		var diamond := PackedVector2Array([c + Vector2(0, -2.5), c + Vector2(2.5, 0), c + Vector2(0, 2.5), c + Vector2(-2.5, 0)])
		if i < deflect.get_streak():
			_readout.draw_colored_polygon(diamond, Color.WHITE)
		else:
			_readout.draw_polyline(diamond + PackedVector2Array([diamond[0]]), Color(1, 1, 1, 0.5), 1.0)
	if deflect.has_riposte():
		var left := knight.status_component.get_time_left(DeflectComponent.get_riposte_status_id())
		_readout.draw_string(font, Vector2(at.x - 30.0, y + 12.0), "RIPOSTE %.1f" % left, HORIZONTAL_ALIGNMENT_CENTER, 60.0, 8, POISE_COLOR)
