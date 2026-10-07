class_name AIUse
extends Resource
## What an ability is for, for the AI (ENEMIES_AI.md, Intents; AI1): one
## intent tag, its use rules (the shared Conditions, all of which must pass;
## the brain's SituationContext is passed in) and a weight. Inline on an
## Ability (Ability.ai_uses). An ability with none counts as one `damage` use
## with no rules (Ability.get_ai_uses()).
## The data says what for and when; the ability's get_ai_plan() says how and
## how good (ALLIES.md, An AI method per ability).

## The intent tags, one list for the enemy and the ally brains: the moment
## tags, then the effect tags (ENEMIES_AI.md, Intents; ALLIES' `engage` is
## `gap_close`). AI-D1 appends `peel`: cast to make space when crowded, then
## step back (a crowd control's other use, the setup, is a combo plan's).
const INTENT_TAGS: Array[StringName] = [&"poke", &"gap_close", &"escape", &"defend", &"punish",
	&"finish", &"zone", &"damage", &"heal", &"shield", &"buff", &"cc", &"peel"]

## One of INTENT_TAGS.
@export var intent: StringName = &"damage"
## The use rules: all must pass (an empty list passes). The situation kinds
## (RESPECT) read the brain's SituationContext.
@export var conditions: Array[Condition] = []
## Multiplies the plan's value when the brain weighs this use (1 = as is).
@export var weight: float = 1.0


## The use rules pass for `self_unit` against `target` in `situation`.
func passes(self_unit: Unit, target: Unit, situation: SituationContext) -> bool:
	return Condition.all_met(conditions, self_unit, target, null, situation)


## A use with `intent`, no rules and weight 1 (code-built; tests and defaults).
static func make(p_intent: StringName, p_conditions: Array[Condition] = [], p_weight: float = 1.0) -> AIUse:
	var use := AIUse.new()
	use.intent = p_intent
	use.conditions = p_conditions
	use.weight = p_weight
	return use
