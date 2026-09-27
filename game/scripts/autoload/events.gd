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
