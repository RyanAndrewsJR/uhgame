class_name StatModifier
extends Resource
## One change to one number (STATS.md). Items, buffs and passives hand these
## to a StatsComponent under their source_id, and remove_modifiers_from()
## takes back exactly what that source added.
##
## final = (base + sum FLAT) x (1 + sum PERCENT_ADD) x product(1 + PERCENT_MULT)
## then clamped to the stat's min/max (integer stats round after the clamp).

enum Type {
	FLAT,          ## Added to the base.
	PERCENT_ADD,   ## "Increased": all of them are summed. 0.2 = +20%.
	PERCENT_MULT,  ## "More": each one multiplies separately. 0.2 = x1.2.
}

## Stat key from the StatRegistry (&"attack_damage"), or an ability param
## name (&"cooldown") when scope is not empty.
@export var stat: StringName
@export var type: Type = Type.FLAT
@export var value: float = 0.0
## Who added it, <kind>_<name> (&"item_4821", &"status_haste").
@export var source_id: StringName
## &"" = a normal stat, &"ability:knight_lunge" = one ability's param,
## &"tag:projectile" = every ability with that tag (STATS.md step 6).
@export var scope: StringName = &""


static func create(p_stat: StringName, p_type: Type, p_value: float, p_source_id: StringName, p_scope: StringName = &"") -> StatModifier:
	var mod := StatModifier.new()
	mod.stat = p_stat
	mod.type = p_type
	mod.value = p_value
	mod.source_id = p_source_id
	mod.scope = p_scope
	return mod


func is_scoped() -> bool:
	return scope != &""
