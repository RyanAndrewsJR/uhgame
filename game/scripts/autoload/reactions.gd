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


func _ready() -> void:
	_load_world_rules()
	Events.unit_hit.connect(_on_unit_hit)
	Events.unit_died.connect(_on_unit_died)
	Events.status_applied.connect(_on_status_applied)


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


# --- Events -------------------------------------------------------------------

func _on_unit_hit(ctx: HitContext) -> void:
	var affected := ctx.target as Unit
	if affected == null:
		return
	var chance_scale := ctx.proc_coefficient
	_fire(ReactionRule.Trigger.HIT, affected, ctx.source, ctx.target_tags, ctx.tags, [], chance_scale, ctx)


func _on_unit_died(unit: Unit, ctx: HitContext) -> void:
	var killer: Unit = ctx.source if ctx != null else null
	var tags: Array[StringName] = ctx.target_tags if ctx != null else ([] as Array[StringName])
	var hit_tags: Array[StringName] = ctx.tags if ctx != null else ([] as Array[StringName])
	_fire(ReactionRule.Trigger.UNIT_DIED, unit, killer, tags, hit_tags, [], 1.0, ctx)


func _on_status_applied(unit: Unit, status: StatusEffect) -> void:
	var applier: Unit = null
	if unit.status_component != null:
		applier = unit.status_component.get_source(status.id)
	_fire(ReactionRule.Trigger.STATUS_APPLIED, unit, applier, unit.get_status_tags(), [], status.tags, 1.0, status)


# --- Matching -----------------------------------------------------------------

## Every rule that answers this event: world rules, the affected unit's rules
## with owner_role AFFECTED, the other unit's rules with owner_role SOURCE.
## Each fires with its owner (or, for a world rule, the other unit) as source.
func _fire(trigger: ReactionRule.Trigger, affected: Unit, other: Unit, unit_tags: Array[StringName],
		hit_tags: Array[StringName], status_tags: Array, chance_scale: float, trigger_ctx: RefCounted) -> void:
	if not is_instance_valid(other):
		other = null
	var candidates: Array = []   # [rule, owner or null]
	for e: Array in _world_rules.duplicate():
		candidates.append([e[0], null])
	if is_instance_valid(affected):
		for rule in affected.get_reaction_rules():
			if rule.owner_role == ReactionRule.OwnerRole.AFFECTED:
				candidates.append([rule, affected])
	if other != null:
		for rule in other.get_reaction_rules():
			if rule.owner_role == ReactionRule.OwnerRole.SOURCE:
				candidates.append([rule, other])
	var depth := _depth
	for c: Array in candidates:
		var rule: ReactionRule = c[0]
		if rule.trigger != trigger or not rule.allows_chain_depth(depth):
			continue
		if not _has_all(hit_tags, rule.required_hit_tags) or not _has_all(unit_tags, rule.required_unit_tags) \
				or not _has_all(status_tags, rule.required_status_tags):
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
		for effect in rule.effects:
			if effect != null and is_instance_valid(target):
				effect.apply(target, source if is_instance_valid(source) else null, trigger_ctx)
		_depth = depth


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
