extends Node
## Global signal bus, autoloaded as Events (CONVENTIONS.md, Events at every
## seam). Systems announce what happened here; reactions listen here.
## Only reserved names (CONVENTIONS.md). Local signals (Unit.died,
## Unit.damaged...) stay; these are for cross-system listeners.
## status_applied / status_removed come with StatusComponent (COMBAT C9).

## Every hit that got through (not blocked by i-frames), even for 0 damage.
@warning_ignore("unused_signal")
signal unit_hit(ctx: HitContext)
## A hit that dealt damage (ctx.taken_damage > 0).
@warning_ignore("unused_signal")
signal unit_damaged(ctx: HitContext)
## A unit died from a hit. Kill credit: ctx.source.
@warning_ignore("unused_signal")
signal unit_died(unit: Unit, ctx: HitContext)
