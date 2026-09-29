extends CanvasLayer
## Heads-up display: the health readout ("HP current / max" text in the
## Hearts row), the enemy counter, the info line, centered messages, and the
## ability and resource bars (setup_abilities()).

## The health text's color at 0 health; it fades to white at full.
const HEART_FULL := Color(0.9, 0.2, 0.25)

@onready var hearts: HBoxContainer = $Margin/Top/Hearts
@onready var enemy_label: Label = $Margin/Top/EnemyLabel
@onready var message: Label = $Message
@onready var info_label: Label = $InfoLabel


const AbilityBar := preload("res://scripts/ui/ability_bar.gd")
const ResourceBar := preload("res://scripts/ui/resource_bar.gd")


## The ability bar, and under it the resource bar if the player has a
## resource pool (ABILITIES.md, HUD feedback).
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


func set_info(text: String) -> void:
	info_label.text = text


func _ready() -> void:
	message.visible = false


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
