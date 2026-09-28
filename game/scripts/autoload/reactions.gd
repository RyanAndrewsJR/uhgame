extends Node
## Reaction rules (COMBAT C11), autoloaded as Reactions. Listens to Events
## (unit_hit, unit_died, status_applied) and fires the ReactionRules that
## match: world rules (every .tres in res://data/reactions/world/, plus
## add_world_rule()) and the unit rules of the two units involved
## (Unit.add_reaction_rule()).
##
## Chains: effects run synchronously, so any event they cause arrives while
## a rule is still applying. That event is one link deeper; a rule fires on
## it only if its chain_limit allows (ReactionRule.MAX_CHAIN = 5 at most).
## Later consequences (a DoT tick from a status a rule applied) start fresh.

const WORLD_RULES_DIR := "res://data/reactions/world/"

## Rolls every rule's chance. Tests seed it.
var rng := RandomNumberGenerator.new()

var _world_rules: Array = []   # [ReactionRule, source_id]
var _depth: int = 0            # chain depth of the event being handled
var _source_id: StringName = &""   # the source id of the rule whose effects are running


func _ready() -> void:
	_load_world_rules()
	Events.unit_hit.connect(_on_unit_hit)
	Events.unit_died.connect(_on_unit_died)
	Events.status_applied.connect(_on_status_applied)
	Events.ability_cast.connect(_on_ability_cast)


# --- World rules --------------------------------------------------------------

## Adds a world rule under `source_id` (a room, a hazard, a run modifier...).
func add_world_rule(rule: ReactionRule, source_id: StringName) -> void:
	if rule != null:
		_world_rules.append([rule, source_id])


func remove_world_rules_from(source_id: StringName) -> void:
	_world_rules = _world_rules.filter(func(e: Array) -> bool: return e[1] != source_id)


func get_world_rules() -> Array[ReactionRule]:
	var result: Array[ReactionRule] = []
	for e: Array in _world_rules:
		result.append(e[0])
	return result


## How many links deep the event being handled is (0 = caused by the game,
## not by a rule).
func get_chain_depth() -> int:
	return _depth


## The source id of the rule whose effects are running (the item, passive,
## augment or status that added it; &"" outside an effect). ABILITIES AB8:
## a free cast records it as CastContext.source_id.
func get_current_source_id() -> StringName:
	return _source_id


## Runs `callable` with the chain depth set to `depth`, then restores it. A
## free cast emits its ability_cast this way, so rules see it one link
## deeper than the reaction that asked for it.
func run_at_depth(depth: int, callable: Callable) -> void:
	var outer := _depth
	_depth = depth
	callable.call()
	_depth = outer


# --- Events -------------------------------------------------------------------

func _on_unit_hit(ctx: HitContext) -> void:
	var affected := ctx.target as Unit
	if affected == null:
		return
	var chance_scale := ctx.proc_coefficient
	_fire(ReactionRule.Trigger.HIT, affected, ctx.source, ctx.target_tags, ctx.tags, [], chance_scale, ctx,
		ctx.ability, ctx.chain_depth)


func _on_unit_died(unit: Unit, ctx: HitContext) -> void:
	var killer: Unit = ctx.source if ctx != null else null
	var tags: Array[StringName] = ctx.target_tags if ctx != null else ([] as Array[StringName])
	var hit_tags: Array[StringName] = ctx.tags if ctx != null else ([] as Array[StringName])
	_fire(ReactionRule.Trigger.UNIT_DIED, unit, killer, tags, hit_tags, [], 1.0, ctx,
		ctx.ability if ctx != null else null, ctx.chain_depth if ctx != null else 0)


func _on_status_applied(unit: Unit, status: StatusEffect) -> void:
	var applier: Unit = null
	if unit.status_component != null:
		applier = unit.status_component.get_source(status.id)
	_fire(ReactionRule.Trigger.STATUS_APPLIED, unit, applier, unit.get_status_tags(), [], status.tags, 1.0, status)


## An ability's effect started (ABILITIES AB8): affected = the cast's target
## (or none), other = the caster.
func _on_ability_cast(unit: Unit, ability: Ability, ctx: CastContext) -> void:
	var target: Unit = ctx.target if ctx != null and is_instance_valid(ctx.target) else null
	var tags: Array[StringName] = target.get_status_tags() if target != null else ([] as Array[StringName])
	_fire(ReactionRule.Trigger.ABILITY_CAST, target, unit, tags, [], [], 1.0, ctx, ability)


# --- Matching -----------------------------------------------------------------

## Every rule that answers this event: world rules, the affected unit's rules
## with owner_role AFFECTED, the other unit's rules with owner_role SOURCE.
## Each fires with its owner (or, for a world rule, the other unit) as source.
## `ability`: the event's ability (for required_ability_scope; AB8).
## `depth_floor`: the chain depth the event itself carries (a free cast's hits,
## AB8); the event counts at the deeper of it and the current depth.
func _fire(trigger: ReactionRule.Trigger, affected: Unit, other: Unit, unit_tags: Array[StringName],
		hit_tags: Array[StringName], status_tags: Array, chance_scale: float, trigger_ctx: RefCounted,
		ability: Ability = null, depth_floor: int = 0) -> void:
	if not is_instance_valid(affected):
		affected = null
	if not is_instance_valid(other):
		other = null
	var candidates: Array = []   # [rule, owner or null, source_id]
	for e: Array in _world_rules.duplicate():
		candidates.append([e[0], null, e[1]])
	if affected != null:
		for e: Array in affected.get_reaction_rule_entries():
			if (e[0] as ReactionRule).owner_role == ReactionRule.OwnerRole.AFFECTED:
				candidates.append([e[0], affected, e[1]])
	if other != null:
		for e: Array in other.get_reaction_rule_entries():
			if (e[0] as ReactionRule).owner_role == ReactionRule.OwnerRole.SOURCE:
				candidates.append([e[0], other, e[1]])
	var outer := _depth
	var outer_source := _source_id
	var depth := maxi(_depth, depth_floor)
	for c: Array in candidates:
		var rule: ReactionRule = c[0]
		if rule.trigger != trigger or not rule.allows_chain_depth(depth):
			continue
		if not _has_all(hit_tags, rule.required_hit_tags) or not _has_all(unit_tags, rule.required_unit_tags) \
				or not _has_all(status_tags, rule.required_status_tags) or not rule.matches_ability(ability):
			continue
		var chance := rule.chance * chance_scale
		if chance <= 0.0 or (chance < 1.0 and rng.randf() >= chance):
			continue
		var owner: Unit = c[1]
		var source: Unit = owner if owner != null else other
		var target: Unit = affected if rule.effect_target == ReactionRule.EffectTarget.AFFECTED else other
		if not is_instance_valid(target):
			continue
		_depth = depth + 1
		_source_id = c[2]
		for effect in rule.effects:
			if effect != null and is_instance_valid(target):
				effect.apply(target, source if is_instance_valid(source) else null, trigger_ctx)
		_depth = outer
		_source_id = outer_source


func _has_all(have: Array, needed: Array[StringName]) -> bool:
	for t in needed:
		if not have.has(t):
			return false
	return true


func _load_world_rules() -> void:
	if not DirAccess.dir_exists_absolute(WORLD_RULES_DIR):
		return
	for file in DirAccess.get_files_at(WORLD_RULES_DIR):
		var path := WORLD_RULES_DIR + file.trim_suffix(".remap")   # exported builds remap .tres
		if not path.ends_with(".tres") and not path.ends_with(".res"):
			continue
		var rule := load(path) as ReactionRule
		if rule != null:
			add_world_rule(rule, &"world")
		else:
			push_error("Reactions: %s is not a ReactionRule" % path)
