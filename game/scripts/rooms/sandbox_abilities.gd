class_name SandboxAbilities
extends Node
## Sandbox only (ABILITIES demos), all through scoped modifiers under
## &"sandbox_demo", like an item would:
## - AB3: mana costs, so the resource bar, spending and the "not enough
##   resource" cue can be played.
## - AB4: extra charges (Lunge +1: two Lunges back to back).
## - AB5+: test_q puts a test ability on Q (set it in the Inspector).
## - 3D pivot P9: test_w puts one on W (the 3D sandbox's Uppercut).
## - AB13: test_elite_w puts an ability on the elite Elite1's W (the VECTOR
##   wall, test_w_vector_wall.tres).
## - AB15: B blinks the Knight toward the cursor (test_blink, over walls),
##   Shift+B with the blink that stops at walls (test_blink_sight); free
##   casts, no cooldown.
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
## A test ability to put on W instead of Iron Resolve (3D pivot P9: the 3D
## sandbox's Uppercut, res://data/abilities/test_w_uppercut.tres, a
## knock-up). null = the Knight's own W.
@export var test_w: Ability
## An ability to put on the sandbox elite Elite1's W (e.g.
## res://data/abilities/test_w_vector_wall.tres). null = none.
@export var test_elite_w: Ability
## ABILITIES AB15: B casts this blink for free toward the cursor (raw keys,
## read only in this sandbox script; B is unbound elsewhere). null = no key.
@export var test_blink: Ability = preload("res://data/abilities/test_q_blink.tres")
## Shift+B: the blink that stops at walls.
@export var test_blink_sight: Ability = preload("res://data/abilities/test_q_blink_sight.tres")

var _player: Player


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.physical_keycode != KEY_B:
		return
	blink_toward_aim(key.shift_pressed)
	get_viewport().set_input_as_handled()


## AB15: the test blink (or, `stop_at_walls`, the one that stops at walls)
## cast for free by the sandbox's Knight toward his aim. False if there's no
## Knight or it's refused (rooted, stunned, mid-leap).
func blink_toward_aim(stop_at_walls: bool = false) -> bool:
	var ability := test_blink_sight if stop_at_walls else test_blink
	if ability == null or not is_instance_valid(_player) or not _player.is_alive():
		return false
	if not ability.can_cast_custom(_player, null):
		return false
	return _player.abilities.try_cast_free(ability, _player.get_aim_point(), null, SOURCE_ID)


func _ready() -> void:
	var entities := get_parent().get_node_or_null("Entities")
	if entities == null:
		return
	entities.child_entered_tree.connect(_give_costs)
	entities.child_entered_tree.connect(_give_elite_w)
	for child in entities.get_children():
		_give_costs(child)
		_give_elite_w(child)


func _give_elite_w(node: Node) -> void:
	var elite := node as Enemy
	if elite == null or elite.name != &"Elite1" or test_elite_w == null:
		return
	if not elite.is_node_ready():
		await elite.ready   # Unit.abilities is an @onready
	if elite.abilities != null:
		elite.abilities.w = test_elite_w


func _give_costs(node: Node) -> void:
	var player := node as Player
	if player == null:
		return
	if not player.is_node_ready():
		await player.ready   # its StatsComponent is set up in Unit._ready()
	_player = player
	player.stats_component.remove_modifiers_from(SOURCE_ID)   # never twice
	if test_q != null:
		player.abilities.q = test_q
	if test_w != null:
		player.abilities.w = test_w
	if demo_costs:
		for id: StringName in costs:
			player.stats_component.add_modifier(StatModifier.create(&"resource_cost",
				StatModifier.Type.FLAT, costs[id], SOURCE_ID, StringName("ability:" + id)))
	if demo_charges:
		for id: StringName in extra_charges:
			player.stats_component.add_modifier(StatModifier.create(&"max_charges",
				StatModifier.Type.FLAT, float(extra_charges[id]), SOURCE_ID, StringName("ability:" + id)))
