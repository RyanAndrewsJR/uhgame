extends Node
## Sandbox only (ABILITIES AB3 demo): gives the player's abilities mana costs
## through scoped resource_cost modifiers (source &"sandbox_demo"), so the
## resource bar, spending and the "not enough resource" cue can be played.
## The Knight's real costs are CHAMPIONS.md's; room_01 has none of this.

const SOURCE_ID := &"sandbox_demo"

## Off: the abilities stay free, as in room_01.
@export var demo_costs: bool = true
## Ability id -> cost (the Knight's mana: 300, 6/s regen). Numbers inside
## ABILITIES.md's placeholder range (30-80).
@export var costs: Dictionary[StringName, float] = {
	&"knight_cleave": 30.0,
	&"knight_iron_resolve": 40.0,
	&"knight_lunge": 50.0,
	&"knight_judgement": 80.0,
}


func _ready() -> void:
	var entities := get_parent().get_node_or_null("Entities")
	if entities == null:
		return
	entities.child_entered_tree.connect(_give_costs)
	for child in entities.get_children():
		_give_costs(child)


func _give_costs(node: Node) -> void:
	var player := node as Player
	if player == null or not demo_costs:
		return
	if not player.is_node_ready():
		await player.ready   # its StatsComponent is set up in Unit._ready()
	player.stats_component.remove_modifiers_from(SOURCE_ID)   # never twice
	for id: StringName in costs:
		player.stats_component.add_modifier(StatModifier.create(&"resource_cost",
			StatModifier.Type.FLAT, costs[id], SOURCE_ID, StringName("ability:" + id)))
