extends Node
## Sandbox only (COMBAT C11 demo): gives the player these reaction rules
## (reaction_shatter.tres: hitting a stunned enemy deals a bonus 30 magic
## hit). Lives in sandbox.tscn, so room_01 and the real game are unchanged.

@export var player_rules: Array[ReactionRule] = []

const SOURCE_ID := &"sandbox_demo"


func _ready() -> void:
	var entities := get_parent().get_node_or_null("Entities")
	if entities == null:
		return
	entities.child_entered_tree.connect(_give_rules)
	for child in entities.get_children():
		_give_rules(child)


func _give_rules(node: Node) -> void:
	var player := node as Player
	if player == null:
		return
	player.remove_reaction_rules_from(SOURCE_ID)   # never twice
	for rule in player_rules:
		player.add_reaction_rule(rule, SOURCE_ID)
