extends Node
## Global signal bus, autoloaded as Events (CONVENTIONS.md, Events at every
## seam). Systems announce what happened here; reactions listen here.
## Only reserved names (CONVENTIONS.md). Local signals (Unit.died,
## Unit.damaged...) stay; these are for cross-system listeners.

## Every hit that got through (not blocked by i-frames), even for 0 damage.
@warning_ignore("unused_signal")
signal unit_hit(ctx: HitContext)
## A hit that dealt damage (ctx.taken_damage > 0).
@warning_ignore("unused_signal")
signal unit_damaged(ctx: HitContext)
## A unit died from a hit. Kill credit: ctx.source.
@warning_ignore("unused_signal")
signal unit_died(unit: Unit, ctx: HitContext)
## A status effect was applied to a unit, or re-applied (refreshed or
## stacked). StatusComponent re-emits its own signal here (COMBAT C9).
@warning_ignore("unused_signal")
signal status_applied(unit: Unit, status: StatusEffect)
## A status effect ended on a unit (ran out, removed, or the unit died).
@warning_ignore("unused_signal")
signal status_removed(unit: Unit, status: StatusEffect)
## An ability's effect started (ABILITIES AB8): after the cast time for
## INSTANT and CHANNEL, after the release windup for CHARGE_UP, at each recast
## part's effect, and when a free cast runs. Never for a cast that was
## cancelled or interrupted before its effect. Reaction rules' ABILITY_CAST.
@warning_ignore("unused_signal")
signal ability_cast(unit: Unit, ability: Ability, ctx: CastContext)
## An item was put on a unit (LOOT L2, EquipmentComponent): its modifiers and
## augments are on it, under item.get_source_id(). The inventory's save listens.
@warning_ignore("unused_signal")
signal item_equipped(unit: Unit, item: Item)
## An item was taken off a unit: everything it gave is gone.
@warning_ignore("unused_signal")
signal item_unequipped(unit: Unit, item: Item)
