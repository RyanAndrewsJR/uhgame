extends CanvasLayer
## Heads-up display: the health readout ("HP current / max" text in the
## Hearts row), the enemy counter, the info line, centered messages, the
## ability and resource bars (setup_abilities()), the progress line (TALENTS
## T4) and the loot lines (LOOT L7, from Loot.item_picked_up).

## The health text's color at 0 health; it fades to white at full.
const HEART_FULL := Color(0.9, 0.2, 0.25)

@onready var hearts: HBoxContainer = $Margin/Top/Hearts
@onready var enemy_label: Label = $Margin/Top/EnemyLabel
@onready var message: Label = $Message
@onready var info_label: Label = $InfoLabel


const AbilityBar := preload("res://scripts/ui/ability_bar.gd")
const ResourceBar := preload("res://scripts/ui/resource_bar.gd")
const PassiveSlot := preload("res://scripts/ui/passive_slot.gd")


## The ability bar, under it the resource bar if the player has a resource
## pool (ABILITIES.md, HUD feedback), and left of it the passive slot if the
## player's champion has a passive (CHAMPIONS CH6).
func setup_abilities(player: Player) -> void:
	var bar := Control.new()
	bar.set_script(AbilityBar)
	bar.name = "AbilityBar"
	bar.set("abilities", player.abilities)
	bar.set("player", player)
	add_child(bar)
	if player.resource_pool != null:
		var resource_bar := Control.new()
		resource_bar.set_script(ResourceBar)
		resource_bar.name = "ResourceBar"
		resource_bar.set("pool", player.resource_pool)
		resource_bar.set("abilities", player.abilities)
		add_child(resource_bar)
	if player.champion != null and player.champion.passive != null:
		var passive_slot := Control.new()
		passive_slot.set_script(PassiveSlot)
		passive_slot.name = "PassiveSlot"
		passive_slot.set("player", player)
		add_child(passive_slot)


func set_info(text: String) -> void:
	info_label.text = text


func _ready() -> void:
	message.visible = false
	Progress.champion_leveled_up.connect(_on_progress_champion_leveled_up)
	Progress.talent_unlocked.connect(_on_progress_talent_unlocked)
	Loot.item_picked_up.connect(_on_loot_item_picked_up)


## How long a progress line stays (seconds), then it fades.
const PROGRESS_LINE_TIME := 2.0

var _progress_line: Label
var _progress_tween: Tween


## A short line under the top bar (TALENTS T4: a level gained, a talent
## unlocked), shown for PROGRESS_LINE_TIME s. Functional only (UI.md later).
func show_progress_line(text: String) -> void:
	if _progress_line == null:
		_progress_line = Label.new()
		_progress_line.name = "ProgressLine"
		_progress_line.add_theme_font_size_override("font_size", 9)
		_progress_line.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		_progress_line.add_theme_color_override("font_outline_color", Color.BLACK)
		_progress_line.add_theme_constant_override("outline_size", 3)
		_progress_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_progress_line.anchor_left = 0.0
		_progress_line.anchor_right = 1.0
		_progress_line.offset_top = 22.0
		add_child(_progress_line)
	# A second line while one shows: the new one goes underneath.
	if _progress_line.visible and _progress_line.modulate.a > 0.0 and _progress_line.text != "":
		_progress_line.text += "\n" + text
	else:
		_progress_line.text = text
	_progress_line.visible = true
	_progress_line.modulate.a = 1.0
	if _progress_tween != null:
		_progress_tween.kill()
	_progress_tween = create_tween()
	_progress_tween.tween_interval(PROGRESS_LINE_TIME)
	_progress_tween.tween_property(_progress_line, "modulate:a", 0.0, 0.3)
	_progress_tween.tween_callback(func() -> void: _progress_line.text = "")


## The progress line's text now ("" = none; tests read it).
func get_progress_line() -> String:
	return _progress_line.text if _progress_line != null else ""


## How long a loot line stays (seconds), then it fades.
const LOOT_LINE_TIME := 2.0
## At most this many loot lines at once; a new one pushes the oldest out.
const LOOT_LINE_MAX := 6

var _loot_lines: VBoxContainer


## A line in the item's rarity color for each pickup (LOOT L7: "Rare: Iron
## Helm", "Legendary: Tidebreaker"), centered above the ability bar, for
## LOOT_LINE_TIME s, then it fades. A new line goes under those still
## showing. Functional only (UI.md later).
func show_loot_line(text: String, color: Color) -> void:
	if _loot_lines == null:
		_loot_lines = VBoxContainer.new()
		_loot_lines.name = "LootLines"
		_loot_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_loot_lines.alignment = BoxContainer.ALIGNMENT_END
		_loot_lines.add_theme_constant_override("separation", 0)
		_loot_lines.anchor_left = 0.5
		_loot_lines.anchor_right = 0.5
		_loot_lines.anchor_top = 1.0
		_loot_lines.anchor_bottom = 1.0
		_loot_lines.offset_left = -130.0
		_loot_lines.offset_right = 130.0
		_loot_lines.offset_top = -48.0
		_loot_lines.offset_bottom = -48.0   # 10 px over the ability bar (its top at -38)
		_loot_lines.grow_vertical = Control.GROW_DIRECTION_BEGIN   # grows upward
		add_child(_loot_lines)
	var shown := _live_loot_lines()
	while shown.size() >= LOOT_LINE_MAX:
		var oldest: Label = shown.pop_front()
		_loot_lines.remove_child(oldest)
		oldest.queue_free()
	var line := Label.new()
	line.text = text
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_font_size_override("font_size", 9)
	line.add_theme_color_override("font_color", color)
	line.add_theme_color_override("font_outline_color", Color.BLACK)
	line.add_theme_constant_override("outline_size", 3)
	_loot_lines.add_child(line)
	var tween := line.create_tween()
	tween.tween_interval(LOOT_LINE_TIME)
	tween.tween_property(line, "modulate:a", 0.0, 0.3)
	tween.tween_callback(line.queue_free)


## The loot lines showing now, oldest first (tests read them).
func get_loot_lines() -> PackedStringArray:
	var out: PackedStringArray = []
	for line in _live_loot_lines():
		out.append(line.text)
	return out


## The color of the loot line reading `text` (null if none shows it).
func get_loot_line_color(text: String) -> Variant:
	for line in _live_loot_lines():
		if line.text == text:
			return line.get_theme_color(&"font_color")
	return null


func _live_loot_lines() -> Array[Label]:
	var out: Array[Label] = []
	if _loot_lines != null:
		for child in _loot_lines.get_children():
			if child is Label and not child.is_queued_for_deletion():
				out.append(child)
	return out


func _on_loot_item_picked_up(_champion_id: StringName, item: Item) -> void:
	var def := Loot.table.get_rarity(item.rarity)
	show_loot_line("%s: %s" % [def.display_name if def != null else "?", item.get_display_name()], item.get_color(Loot.table))


func _on_progress_champion_leveled_up(champion_id: StringName, level: int) -> void:
	var champion := Progress.get_champion(champion_id)
	if champion == null:
		return
	var leveling := champion.get_leveling()
	var points := leveling.get_talent_points(level) - leveling.get_talent_points(level - 1)
	var text := "%s reached level %d" % [champion.display_name, level]
	if points > 0:
		text += ": +%d talent point%s" % [points, "" if points == 1 else "s"]
	show_progress_line(text)


func _on_progress_talent_unlocked(champion_id: StringName, talent_id: StringName) -> void:
	var champion := Progress.get_champion(champion_id)
	var talent := champion.get_talent(talent_id) if champion != null else null
	if talent != null:
		show_progress_line("Talent unlocked: %s" % talent.display_name)


func set_health(current: float, maximum: float) -> void:
	for c in hearts.get_children():
		if not c is Label:
			c.queue_free()
	var label: Label = hearts.get_node_or_null("HP")
	if label == null:
		label = Label.new()
		label.name = "HP"
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 3)
		hearts.add_child(label)
	label.text = "HP %d / %d" % [ceili(current), roundi(maximum)]
	label.add_theme_color_override("font_color", HEART_FULL.lerp(Color(1, 1, 1), clampf(current / maximum, 0, 1)))


func set_enemies_left(count: int) -> void:
	enemy_label.text = "Enemies: %d" % count


func show_message(text: String) -> void:
	message.text = text
	message.visible = true
	message.modulate.a = 0.0
	create_tween().tween_property(message, "modulate:a", 1.0, 0.3)
