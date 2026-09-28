class_name ReactionRule
extends Resource
## A cross-system interaction as data (COMBAT.md, ReactionRule; CONVENTIONS.md,
## Tags plus rules): when `trigger` happens and the required tags match,
## roll `chance`, then apply `effects`. One .tres per rule in
## res://data/reactions/ (reaction_<name>.tres).
##
## Two kinds, the same Resource (COMBAT C11):
## - World rules apply to everyone: every .tres in res://data/reactions/world/
##   (loaded by the Reactions autoload), plus Reactions.add_world_rule().
## - Unit rules belong to one unit (Unit.add_reaction_rule(), from its items,
##   passives or buffs) and fire only for what that unit does
##   (owner_role SOURCE) or suffers (owner_role AFFECTED).
##
## Every event has an affected unit and an other unit:
##   HIT             affected = the unit hit        other = the attacker
##   UNIT_DIED       affected = the unit that died   other = the killer
##   STATUS_APPLIED  affected = the unit that got it other = who applied it
##   ABILITY_CAST    affected = the cast's target    other = the caster

enum Trigger {
	IMPACT,          ## Not built yet (WORLD_INTERACTION.md, impacts).
	HIT,             ## Events.unit_hit: a hit that got through.
	HAZARD_ENTERED,  ## Not built yet (WORLD_INTERACTION.md, hazards).
	HAZARD_EXITED,   ## Not built yet.
	STATUS_APPLIED,  ## Events.status_applied (also refreshes and new stacks).
	UNIT_DIED,       ## Events.unit_died.
	HAZARD_OVERLAP,  ## Not built yet (hazard meets hazard).
	## Events.ability_cast: an ability's effect started (ABILITIES AB8).
	## affected = the cast's target (none for most casts), other = the caster.
	## Added last so saved rules keep their trigger numbers.
	ABILITY_CAST,
}

## Whose event a unit rule answers. Ignored for world rules.
enum OwnerRole {
	SOURCE,    ## The owner is the other unit: "when I hit / kill / apply...".
	AFFECTED,  ## The owner is the affected unit: "when I'm hit / die / get...".
}

## Who the effects are applied to.
enum EffectTarget {
	AFFECTED,  ## The unit hit, the unit that died, the unit that got the status.
	OTHER,     ## The attacker, the killer, the applier.
}

## Hard cap on chain reactions (Ryan, 2026-09-27): no rule fires as the
## 6th link of a chain, whatever its chain_limit says.
const MAX_CHAIN := 5

## For debugging and tests, e.g. &"shatter".
@export var id: StringName = &""
@export var trigger: Trigger = Trigger.HIT

@export_group("Conditions")
## HIT / UNIT_DIED: the hit (the killing hit) must carry all of these.
@export var required_hit_tags: Array[StringName] = []
## The affected unit must have all of these status tags (for HIT and
## UNIT_DIED: its tags just before the hit).
@export var required_unit_tags: Array[StringName] = []
## STATUS_APPLIED: the applied status must carry all of these.
@export var required_status_tags: Array[StringName] = []
## &"" = any. &"ability:<id>" / &"tag:<tag>", matched against the event's
## ability (Ability.get_modifier_scopes()): ABILITY_CAST's ability, HIT's and
## UNIT_DIED's HitContext.ability (no ability never matches). ABILITIES AB8.
@export var required_ability_scope: StringName = &""
## IMPACT (not built yet).
@export var required_surface_tags: Array[StringName] = []
## IMPACT (not built yet).
@export var min_impact_speed_px: float = 0.0
## Unit-state checks (ABILITIES AB12, the shared Condition resource): all
## must pass after the tag filters above and before chance is rolled. Self =
## the unit the effects come from (the rule's owner; for a world rule the
## event's other unit); target = the effect target (effect_target); the cast
## = the trigger's CastContext (ABILITY_CAST), else none.
@export var conditions: Array[Condition] = []
## 0-1. For HIT it's multiplied by the hit's proc_coefficient, so DoT ticks
## and procs (coefficient 0) never trigger HIT rules.
@export_range(0.0, 1.0) var chance: float = 1.0

@export_group("Effects")
@export var effects: Array[GameplayEffect] = []
@export var effect_target: EffectTarget = EffectTarget.AFFECTED
@export var owner_role: OwnerRole = OwnerRole.SOURCE
## How many reactions in a row this rule may take part in (1 = only on
## events the game itself caused, never on one another rule's effects
## caused). Set per champion ability, passive or item; capped at MAX_CHAIN.
@export_range(1, 5) var chain_limit: int = 1


## True if the event's ability matches required_ability_scope.
func matches_ability(ability: Ability) -> bool:
	if required_ability_scope == &"":
		return true
	return ability != null and ability.get_modifier_scopes().has(required_ability_scope)


## True if this rule may fire on an event `depth` links into a chain (0 = not
## caused by a rule).
func allows_chain_depth(depth: int) -> bool:
	return depth < mini(chain_limit, MAX_CHAIN)
