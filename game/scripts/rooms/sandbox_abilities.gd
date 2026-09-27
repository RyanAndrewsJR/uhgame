extends Node
## Sandbox only (ABILITIES demos), all through scoped modifiers under
## &"sandbox_demo", like an item would:
## - AB3: mana costs, so the resource bar, spending and the "not enough
##   resource" cue can be played.
## - AB4: extra charges (Lunge +1: two Lunges back to back).
## - AB5+: test_q puts a test ability on Q (set it in the Inspector).
## The Knight's real numbers are CHAMPIONS.md's; room_01 has none of this.

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
## Off: every ability has its own max_charges (1), as in room_01.
@export var demo_charges: bool = true
## Ability id -> extra charges.
@export var extra_charges: Dictionary[StringName, int] = {
	&"knight_lunge": 1,
}
## A test ability to put on Q instead of Cleave (e.g.
## res://data/abilities/test_q_triple_step.tres). null = the Knight's own Q.
@export var test_q: Ability


func _ready() -> void:
	var entities := get_parent().get_node_or_null("Entities")
	if entities == null:
		return
	entities.child_entered_tree.connect(_give_costs)
	for child in entities.get_children():
		_give_costs(child)


func _give_costs(node: Node) -> void:
	var player := node as Player
	if player == null:
		return
	if not player.is_node_ready():
		await player.ready   # its StatsComponent is set up in Unit._ready()
	player.stats_component.remove_modifiers_from(SOURCE_ID)   # never twice
	if test_q != null:
		player.abilities.q = test_q
	if demo_costs:
		for id: StringName in costs:
			player.stats_component.add_modifier(StatModifier.create(&"resource_cost",
				StatModifier.Type.FLAT, costs[id], SOURCE_ID, StringName("ability:" + id)))
	if demo_charges:
		for id: StringName in extra_charges:
			player.stats_component.add_modifier(StatModifier.create(&"max_charges",
				StatModifier.Type.FLAT, float(extra_charges[id]), SOURCE_ID, StringName("ability:" + id)))
