class_name SandboxBrains
extends Node
## Sandbox only (ENEMIES_AI.md, The tuning toolkit; AI1): the AI tuning
## toolkit's three in-game tools, on raw keys read here (no input action,
## like SandboxLoot's):
##   I            the brain overlay: over each brained enemy its intent and
##                pose, its top three scores, respect, patience, its token
##                (held, waiting, rest), its dodge cooldown, its reaction time
##                and its think's cost; on the floor its range band around its
##                target and, while it holds a token, a line to its target;
##                each pack's home and leash (AI2), and fodder's places in the
##                ring around its target. (The doc's B is the AB15 test blink:
##                Ryan, 2026-10-04.)
##   N            the tuning panel: the brained enemy nearest the cursor is
##                picked (, and . cycle), its twelve sliders show as sliders
##                with the resolved value and the preset's. A change applies
##                at once to it and to every enemy sharing its data (an
##                in-memory override). Its brain switch turns the brain off
##                (the old routine and the naive cast loop) or on.
##   Ctrl+S       (panel open) saves the edited sliders into its behavior
##                preset (the archetype .tres)
##   Ctrl+Shift+S (panel open) saves them as overrides into its EnemyData
##                (a warning past three: kind, not magnitude)
##                Saving works only in a run from the editor, never in an
##                exported build or a test scene; Godot then says the file
##                changed on disk: choose Reload (CLAUDE.md, Known issues).
##   H            the next scenario: all cooldowns ready, none ready, low
##                health (25%), an ally present (a friendly stand-in dummy
##                until ALLIES), a whiff (Judgement spent at nothing), an
##                incoming shot (a test bolt fired at the enemy). Each spawns
##                scenario_enemy (the test brute) 5 m from the Knight, toward
##                the cursor, and sets the Knight's cooldowns, Fury and health
##                through test hooks (the previous scenario's units go).
##                AI2 adds two packs, placed 9 m away toward the cursor and
##                idle until they notice the Knight: a pack of five test
##                brutes (two tokens at a time, the shout, the leash) and a
##                pack of eight slimes (the fodder ring).
## It never touches the player's saves. room_01 has none of this.

const TEXT_COLOR := Color(0.92, 0.92, 0.92)
const HINT_COLOR := Color(0.65, 0.65, 0.7)
const SOURCE_ID := &"sandbox_brains"
const SCENARIOS: Array[StringName] = [&"all_ready", &"none_ready", &"low_health", &"ally", &"whiff", &"incoming_shot", &"pack", &"fodder"]
const SCENARIO_NAMES := {
	&"all_ready": "all cooldowns ready", &"none_ready": "none ready", &"low_health": "low health (25%)",
	&"ally": "an ally present", &"whiff": "a whiff (Judgement spent)", &"incoming_shot": "an incoming shot",
	&"pack": "a pack of five brutes (9 m away, idle)", &"fodder": "a pack of eight slimes (9 m away, idle)",
}
const FRIENDLY_SCENE := preload("res://scenes/enemies/slime.tscn")

## What H spawns (the test brute).
@export var scenario_enemy: PackedScene = preload("res://scenes/enemies/test_brute.tscn")
## How far from the Knight it spawns (px; 160 = 5 m).
@export var scenario_distance_px: float = 160.0
## The test bolt the incoming-shot scenario fires (a free cast from the Knight).
@export var test_bolt: Ability = preload("res://data/abilities/test_q_bolt.tres")
## The overlay is on at the start.
@export var overlay_on: bool = false
## The pack scenarios (AI2): where the pack is placed (px from the Knight;
## 288 = 9 m, outside the members' notice range), its size, and the fodder.
@export var pack_distance_px: float = 288.0
@export var pack_size: int = 5
@export var fodder_scene: PackedScene = preload("res://scenes/enemies/slime.tscn")
@export var fodder_pack_size: int = 8
## How far apart a pack's members stand at home (px).
@export var pack_spread_px: float = 44.0

var _player: Player
var _overlay_layer: CanvasLayer
var _labels: Dictionary = {}   # Enemy -> Label
var _floor: Node2D
var _panel_layer: CanvasLayer
var _panel: PanelContainer
var _panel_title: Label
var _brain_switch: CheckBox
var _rows: Dictionary = {}   # slider -> {slider: HSlider, value: Label}
var _status_label: Label
var _picked: Enemy
var _syncing := false   # the panel's sliders are being set from the data (no edits)
var _edited: Dictionary = {}   # EnemyData -> {slider: true} edited in this panel
var _original_overrides: Dictionary = {}   # EnemyData -> its overrides before any edit
var _scenario := -1
var _scenario_units: Array[Node] = []
var _status: String = ""


func _ready() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 2
	add_child(_overlay_layer)
	_floor = Node2D.new()
	_floor.name = "BrainOverlayFloor"
	_floor.visibility_layer = FloorOverlay.DRAWING_VISIBILITY_BIT   # a floor drawing in 3D; never on screen in 2D
	_floor.draw.connect(_draw_floor)
	get_parent().add_child.call_deferred(_floor)
	var entities := get_parent().get_node_or_null("Entities")
	if entities != null:
		entities.child_entered_tree.connect(_on_entity)
		for child in entities.get_children():
			_on_entity(child)
	set_overlay(overlay_on)


func _on_entity(node: Node) -> void:
	if node is Player:
		_player = node


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_I:
			set_overlay(not is_overlay_on())
		KEY_N:
			set_panel(not is_panel_open())
		KEY_H:
			next_scenario()
		KEY_COMMA:
			if not is_panel_open():
				return
			cycle_pick(-1)
		KEY_PERIOD:
			if not is_panel_open():
				return
			cycle_pick(1)
		KEY_S:
			if not is_panel_open() or not key.ctrl_pressed:
				return
			save_edits(key.shift_pressed)
		_:
			return
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if is_overlay_on():
		_update_overlay()
		_floor.queue_redraw()
	if is_panel_open():
		_update_panel_values()


# --- The overlay (I) ------------------------------------------------------------------

func is_overlay_on() -> bool:
	return _overlay_layer.visible


func set_overlay(on: bool) -> void:
	_overlay_layer.visible = on
	_floor.visible = on
	Brains.debug_draw = on
	if not on:
		for label: Variant in _labels.values():
			if is_instance_valid(label):
				(label as Node).queue_free()
		_labels.clear()


## Every enemy in the scene with a brain.
func get_brained_enemies() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var e := node as Enemy
		if e != null and e.is_alive() and e.get_brain() != null:
			out.append(e)
	return out


## The overlay's text for `enemy` (its brain's state now).
func get_overlay_text(enemy: Enemy) -> String:
	var brain := enemy.get_brain()
	if brain == null:
		return ""
	var intent := String(brain.get_intent())
	if intent == "":
		intent = "return" if enemy.ai == Enemy.AI.RETURN else "idle"
	var pose := brain.get_pose()
	var lines: PackedStringArray = []
	lines.append("%s · %s" % [intent, pose if pose != &"" else "-"])
	var d := brain.get_last_decision()
	if d != null and not d.scores.is_empty():
		var parts: PackedStringArray = []
		for pair: Array in d.get_top_scores(3):
			parts.append("%s %.2f" % [pair[0], pair[1]])
		lines.append("  ".join(parts))
	var s := brain.get_situation()
	var respect := s.respect if s != null else 0.0
	var effective := s.effective_respect if s != null else 0.0
	lines.append("respect %.2f (%.2f)  patience %.2f" % [respect, effective, brain.get_patience()])
	lines.append("token %s  dodge -  react %.2f s  %d µs" % [brain.get_token_state(), brain.behavior.reaction_time, brain.get_think_usec()])
	return "\n".join(lines)


func _update_overlay() -> void:
	var enemies := get_brained_enemies()
	for e: Variant in _labels.keys():
		if not is_instance_valid(e) or not enemies.has(e):
			if is_instance_valid(_labels[e]):
				(_labels[e] as Node).queue_free()
			_labels.erase(e)
	var view := WorldView.of(self)
	for e in enemies:
		var label: Label = _labels.get(e)
		if label == null:
			label = _make_label()
			_overlay_layer.add_child(label)
			_labels[e] = label
		label.text = get_overlay_text(e)
		if view == null or view.screen_overlay == null or view.screen_overlay.camera == null:
			label.visible = false   # no 3D view (the tests): the text is still kept
			continue
		var head := view.screen_overlay.point_over(e, 1.0)
		var camera := view.screen_overlay.camera
		label.visible = not camera.is_position_behind(head)
		label.position = camera.unproject_position(head) - Vector2(label.size.x * 0.5, label.size.y + 12.0)


func _make_label() -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 7)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Floor drawings: each brain's range band around its target (its two edges,
## both radii counted) and, while it holds a token (or commits on a taunt), a
## line to its target; each pack's home (a cross) and leash (a thin circle);
## each fighting fodder's place in the ring (a dot).
func _draw_floor() -> void:
	for e in get_brained_enemies():
		var brain := e.get_brain()
		var target := e.get_brain_target()
		if brain.get_intent() == &"" or target == null:
			continue
		var radii := e.get_gameplay_radius_px() + target.get_gameplay_radius_px()
		var center := _floor.to_local(target.global_position)
		var color := Color(e.model_color, 0.55)
		for edge_units in [brain.behavior.range_band_min, brain.behavior.range_band_max]:
			_floor.draw_arc(center, Units.to_px(edge_units) + radii, 0.0, TAU, 64, color, 1.0)
		if Brains.has_token(e) or brain.is_committing():
			_floor.draw_line(_floor.to_local(e.global_position), center, Color(1, 0.3, 0.2, 0.9), 1.5)
	var packs: Array[Pack] = []
	for e in Brains.get_enemies():
		if not is_instance_valid(e) or not e.is_alive():
			continue
		var pack := e.get_pack()
		if pack != null and not packs.has(pack):
			packs.append(pack)
		var spot := e.get_ring_spot()
		if e.uses_fodder_ring() and spot != Vector2.INF:
			_floor.draw_circle(_floor.to_local(spot), 2.5, Color(e.model_color, 0.8))
	for pack in packs:
		var home := _floor.to_local(pack.get_home())
		var color := Color(0.8, 0.8, 0.85, 0.5) if not pack.is_fighting() else Color(1.0, 0.75, 0.3, 0.6)
		_floor.draw_line(home - Vector2(6, 0), home + Vector2(6, 0), color, 1.0)
		_floor.draw_line(home - Vector2(0, 6), home + Vector2(0, 6), color, 1.0)
		_floor.draw_arc(home, Brains.table.leash_px, 0.0, TAU, 96, color, 1.0)


# --- The tuning panel (N) ----------------------------------------------------------------

func is_panel_open() -> bool:
	return _panel_layer != null and _panel_layer.visible


func set_panel(open: bool) -> void:
	if open and _panel_layer == null:
		_build_panel()
	if _panel_layer != null:
		_panel_layer.visible = open
	if open:
		pick(_nearest_to_cursor())


## The enemy whose sliders the panel shows (null = none).
func get_picked() -> Enemy:
	return _picked if is_instance_valid(_picked) else null


func pick(enemy: Enemy) -> void:
	_picked = enemy
	_sync_panel()


## `,` / `.`: the previous / next brained enemy (by distance to the Knight).
func cycle_pick(step: int) -> void:
	var enemies := _pickable()
	if enemies.is_empty():
		pick(null)
		return
	var index := enemies.find(get_picked())
	pick(enemies[posmod(index + step, enemies.size())] if index >= 0 else enemies[0])


## Sets `slider` on the picked enemy's data (an in-memory override, so every
## enemy sharing its data changes at once) and re-resolves their brains.
func set_slider(slider: StringName, value: float) -> void:
	var enemy := get_picked()
	if enemy == null or enemy.data == null or enemy.data.behavior == null:
		return
	var data := enemy.data
	if not _original_overrides.has(data):
		_original_overrides[data] = data.overrides.duplicate()
	data.overrides[slider] = EnemyBehavior.clamp_slider(slider, value)
	if not _edited.has(data):
		_edited[data] = {}
	_edited[data][slider] = true
	_refresh_brains(data)


## The base value the panel shows for `slider` (its override, else the preset's).
func get_slider_base(enemy: Enemy, slider: StringName) -> float:
	var data := enemy.data
	return float(data.overrides[slider]) if data.overrides.has(slider) else data.behavior.get_slider(slider)


## Saving is possible: a run from the editor, not a test scene.
func can_save() -> bool:
	return OS.has_feature("editor") and not Progress.is_test_scene()


## Ctrl+S (into_data false): the edited sliders go into the behavior preset
## and its .tres is saved; the data's own overrides are back to what its file
## holds. Ctrl+Shift+S (into_data true): they stay overrides and the EnemyData
## .tres is saved. Returns the error code (OK when saved).
func save_edits(into_data: bool) -> Error:
	var enemy := get_picked()
	if enemy == null or enemy.data == null or not _edited.has(enemy.data):
		_status = "Nothing edited to save"
		_sync_panel()
		return ERR_DOES_NOT_EXIST
	if not can_save():
		_status = "Saving works only in a run from the editor"
		_sync_panel()
		return ERR_UNAVAILABLE
	var data := enemy.data
	var err: Error
	if into_data:
		err = ResourceSaver.save(data, data.resource_path)
		_status = "Saved %d override(s) into %s" % [data.overrides.size(), data.resource_path.get_file()]
		if data.overrides.size() > 3:
			_status += " (more than 3: kind, not magnitude)"
			push_warning("%s has %d overrides (at most 3: kind, not magnitude)" % [data.resource_path, data.overrides.size()])
	else:
		var behavior := data.behavior
		var original: Dictionary = _original_overrides.get(data, {})
		for slider: StringName in _edited[data]:
			behavior.set_slider(slider, data.overrides[slider])
			if original.has(slider):
				data.overrides[slider] = original[slider]
			else:
				data.overrides.erase(slider)
		err = ResourceSaver.save(behavior, behavior.resource_path)
		_status = "Saved into %s" % behavior.resource_path.get_file()
		for e in get_brained_enemies():
			if e.data != null and e.data.behavior == behavior:
				_refresh_brains(e.data)
	if err != OK:
		_status = "Save failed (%s)" % error_string(err)
	_edited.erase(data)
	_original_overrides.erase(data)
	_sync_panel()
	return err


func _pickable() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var e := node as Enemy
		if e != null and e.is_alive() and e.data != null and e.data.behavior != null:
			var rules := e.get_rank_rules()
			if rules != null and rules.has_brain:
				out.append(e)
	if is_instance_valid(_player):
		var from := _player.global_position
		out.sort_custom(func(a: Enemy, b: Enemy) -> bool: return a.global_position.distance_to(from) < b.global_position.distance_to(from))
	return out


func _nearest_to_cursor() -> Enemy:
	var enemies := _pickable()
	if enemies.is_empty():
		return null
	var point := _player.get_aim_point() if is_instance_valid(_player) else enemies[0].global_position
	var best: Enemy = enemies[0]
	for e in enemies:
		if e.global_position.distance_to(point) < best.global_position.distance_to(point):
			best = e
	return best


func _refresh_brains(data: EnemyData) -> void:
	for e in get_brained_enemies():
		if e.data == data:
			e.get_brain().resolve_behavior()


func _build_panel() -> void:
	_panel_layer = CanvasLayer.new()
	_panel_layer.layer = 3
	add_child(_panel_layer)
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.offset_left = 6.0
	_panel.offset_top = 66.0
	_panel.custom_minimum_size = Vector2(250, 0)
	_panel_layer.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	_panel.add_child(box)
	_panel_title = _small_label("")
	box.add_child(_panel_title)
	_brain_switch = CheckBox.new()
	_brain_switch.text = "brain on"
	_brain_switch.add_theme_font_size_override("font_size", 8)
	_brain_switch.toggled.connect(_on_brain_switch_toggled)
	box.add_child(_brain_switch)
	for slider: StringName in EnemyBehavior.SLIDERS:
		var row := HBoxContainer.new()
		var name_label := _small_label(String(slider))
		name_label.custom_minimum_size = Vector2(72, 0)
		row.add_child(name_label)
		var s := HSlider.new()
		var limits: Array = EnemyBehavior.LIMITS[slider]
		s.min_value = limits[0]
		s.max_value = limits[1]
		s.step = 10.0 if limits[1] >= 100.0 else 0.01
		s.custom_minimum_size = Vector2(80, 10)
		s.value_changed.connect(_on_slider_value_changed.bind(slider))
		row.add_child(s)
		var value_label := _small_label("")
		value_label.custom_minimum_size = Vector2(90, 0)
		row.add_child(value_label)
		box.add_child(row)
		_rows[slider] = {"slider": s, "value": value_label}
	_status_label = _small_label("")
	_status_label.add_theme_color_override("font_color", HINT_COLOR)
	box.add_child(_status_label)
	box.add_child(_hint_label(", .  pick   Ctrl+S  save into the preset   Ctrl+Shift+S  save as overrides"))


func _small_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _hint_label(text: String) -> Label:
	var label := _small_label(text)
	label.add_theme_color_override("font_color", HINT_COLOR)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## The panel shows the picked enemy's sliders (its base values).
func _sync_panel() -> void:
	if _panel == null:
		return
	var enemy := get_picked()
	_syncing = true
	if enemy == null:
		_panel_title.text = "No brained enemy (N: the one nearest the cursor)"
	else:
		var data := enemy.data
		_panel_title.text = "%s  (%s, %s)  %s" % [data.display_name, EnemyData.Rank.keys()[data.rank].to_lower(),
			data.behavior.resource_path.get_file(), enemy.name]
		_brain_switch.button_pressed = enemy.get_brain() != null
		for slider: StringName in _rows:
			(_rows[slider].slider as HSlider).value = get_slider_base(enemy, slider)
	_syncing = false
	_status_label.text = _status
	_update_panel_values()


## Each row's value text: the resolved value (its brain's) and the preset's.
func _update_panel_values() -> void:
	var enemy := get_picked()
	if enemy == null:
		return
	var brain := enemy.get_brain()
	for slider: StringName in _rows:
		var preset := enemy.data.behavior.get_slider(slider)
		var resolved: float = brain.behavior.get_slider(slider) if brain != null else preset
		var edited: bool = _edited.has(enemy.data) and (_edited[enemy.data] as Dictionary).has(slider)
		(_rows[slider].value as Label).text = "%s%s (preset %s)" % [_num(resolved), " *" if edited else "", _num(preset)]


static func _num(v: float) -> String:
	return str(snappedf(v, 1.0)) if absf(v) >= 100.0 else "%.2f" % v


func _on_slider_value_changed(value: float, slider: StringName) -> void:
	if _syncing:
		return
	set_slider(slider, value)


func _on_brain_switch_toggled(on: bool) -> void:
	if _syncing:
		return
	var enemy := get_picked()
	if enemy != null:
		enemy.set_brain_enabled(on)
		_status = "Brain %s on %s" % ["on" if on else "off (old routine, naive casts)", enemy.name]
		_sync_panel()


# --- Scenarios (H) -------------------------------------------------------------------------

## The scenario now (&"" before the first H).
func get_scenario() -> StringName:
	return SCENARIOS[_scenario] if _scenario >= 0 else &""


func next_scenario() -> StringName:
	run_scenario(SCENARIOS[(_scenario + 1) % SCENARIOS.size()])
	return get_scenario()


## Runs `scenario`: clears the last one's units, sets the Knight up, spawns
## the scenario enemy (or the pack). Returns the spawned enemy (a pack's
## first member; null without a Knight).
func run_scenario(scenario: StringName) -> Enemy:
	_scenario = SCENARIOS.find(scenario)
	clear_scenario()
	if not is_instance_valid(_player) or not _player.is_alive():
		return null
	_set_knight_ready(scenario != &"none_ready")
	match scenario:
		&"none_ready":
			if _player.resource_pool != null:
				_player.resource_pool.try_spend(_player.resource_pool.current)
		&"low_health":
			_player.health.take_damage(_player.health.max_health * 0.75)
		&"whiff":
			_player.abilities.start_cooldown(&"r")   # AI6 reads a real whiff from the cast
		&"ally":
			_spawn_friendly()
	var enemy: Enemy
	match scenario:
		&"pack":
			enemy = _spawn_pack(scenario_enemy, pack_size)
		&"fodder":
			enemy = _spawn_pack(fodder_scene, fodder_pack_size)
		_:
			enemy = _spawn_enemy()
	if scenario == &"incoming_shot" and enemy != null:
		_fire_bolt_at.call_deferred(enemy)
	_status = "Scenario: %s" % SCENARIO_NAMES[scenario]
	print("SandboxBrains: ", _status)
	if is_panel_open():
		pick(enemy)
	return enemy


## Frees what the last scenario spawned.
func clear_scenario() -> void:
	for n in _scenario_units:
		if is_instance_valid(n):
			n.queue_free()
	_scenario_units.clear()


func _set_knight_ready(ready: bool) -> void:
	var abilities := _player.abilities
	for slot in AbilityComponent.SLOTS:
		if abilities.get_ability(slot) == null:
			continue
		if ready:
			for i in abilities.get_max_charges(slot):
				abilities.reset_cooldown(slot)
		else:
			abilities.start_cooldown(slot)
	if ready and _player.resource_pool != null:
		_player.resource_pool.restore(_player.resource_pool.max_resource)
	_player.health.heal(_player.health.max_health)


func _spawn_point(distance_px: float) -> Vector2:
	var dir := (_player.get_aim_point() - _player.global_position)
	dir = dir.normalized() if dir.length() > 1.0 else Vector2.RIGHT
	var want := _player.global_position + dir * distance_px
	return WorldQuery.resolve_valid_position(want, _player.global_position, 20.0)


func _spawn_enemy() -> Enemy:
	if scenario_enemy == null:
		return null
	var enemy := scenario_enemy.instantiate() as Enemy
	enemy.name = "Scenario%s" % enemy.name   # ScenarioTestBrute (the overlay and the panel show it)
	enemy.position = _spawn_point(scenario_distance_px)
	_entities().add_child(enemy, true)   # readable even while the last one is still being freed
	enemy.reset_physics_interpolation()
	_scenario_units.append(enemy)
	return enemy


## A pack (AI2) of `count` instances of `scene`, placed pack_distance_px from
## the Knight toward the cursor (its home), the members around its center
## pack_spread_px apart. Idle until one notices the Knight. Returns its first
## member (null without a scene).
func _spawn_pack(scene: PackedScene, count: int) -> Enemy:
	if scene == null or count <= 0:
		return null
	var pack := Pack.new()
	pack.name = "ScenarioPack"
	var center := _on_floor(_spawn_point(pack_distance_px))
	pack.position = center
	var first: Enemy
	for i in count:
		var enemy := scene.instantiate() as Enemy
		enemy.name = "Scenario%s" % enemy.name
		if i > 0:
			var ring := 1 + floori((i - 1) / 6.0)
			var slot := (i - 1) % 6
			var offset := Vector2.from_angle(TAU * slot / 6.0 + ring * 0.5) * pack_spread_px * ring
			enemy.position = _on_floor(center + offset) - center
		pack.add_child(enemy, true)
		if first == null:
			first = enemy
	_entities().add_child(pack, true)
	for enemy in pack.get_children():
		(enemy as Node2D).reset_physics_interpolation()
	_scenario_units.append(pack)
	return first


## The nearest point of the room's walkable floor (its navigation) to
## `point`, so a pack aimed past a wall still stands where it can walk.
func _on_floor(point: Vector2) -> Vector2:
	var map := get_viewport().world_2d.navigation_map
	if NavigationServer2D.map_get_iteration_id(map) == 0 or NavigationServer2D.map_get_regions(map).is_empty():
		return point
	return NavigationServer2D.map_get_closest_point(map, point)


## A friendly stand-in for the ally until ALLIES: a passive slime on the
## player's team in the group `party` (no kit: it adds nothing to respect).
func _spawn_friendly() -> void:
	var friend := FRIENDLY_SCENE.instantiate() as Enemy
	friend.data = null
	friend.passive = true
	friend.modulate = Color(0.6, 1.0, 0.8)
	friend.name = "FriendlyStandIn"
	friend.position = _player.global_position + Vector2(0, 48)
	_entities().add_child(friend)
	friend.team = Unit.Team.PLAYER
	friend.remove_from_group(&"enemies")
	friend.add_to_group(&"party")
	_scenario_units.append(friend)


func _fire_bolt_at(enemy: Enemy) -> void:
	if is_instance_valid(enemy) and is_instance_valid(_player) and test_bolt != null:
		_player.abilities.try_cast_free(test_bolt, enemy.global_position, null, SOURCE_ID)


func _entities() -> Node:
	var entities := get_parent().get_node_or_null("Entities")
	return entities if entities != null else get_parent()
