class_name GameplayEffect
extends Resource
## One thing a ReactionRule does (COMBAT.md, ReactionRule and GameplayEffect).
## Subclasses override apply(). There's no "play sound" effect: a rule makes
## a sound only through what it creates (AUDIO.md).


## Applies the effect to `target`. `source` gets the credit (a unit rule's
## owner, or the event's other unit for world rules; may be null).
## `trigger_ctx` is what triggered the rule: the HitContext for HIT and
## UNIT_DIED, the StatusEffect for STATUS_APPLIED, the CastContext for
## ABILITY_CAST (ABILITIES AB8).
func apply(_target: Unit, _source: Unit, _trigger_ctx: RefCounted) -> void:
	pass
