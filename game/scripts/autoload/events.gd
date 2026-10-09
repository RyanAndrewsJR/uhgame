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
## A crowd control diminishing returns counts (a stun, a root...; not a slow
## or a knock-up) took on `unit` (COMBAT.md, Status effects; ENEMIES_AI
## AI-D3): its duration after tenacity and diminishing returns, and its step
## (0 full, 1 halved). StatusComponent re-emits its own signal here.
@warning_ignore("unused_signal")
signal cc_applied(unit: Unit, source: Unit, status: StatusEffect, duration: float, dr_step: int)
## One was refused (AI-D3), with the reason (StatusComponent's &"immune",
## &"unstoppable", &"poise"; &"refused_by_tag" reserved) and the duration it
## would have had after tenacity. For an "Immune" text or a sound.
@warning_ignore("unused_signal")
signal cc_refused(unit: Unit, source: Unit, status: StatusEffect, reason: StringName, duration: float)
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
## A pack was woken by a shout (ENEMIES_AI AI2): one of its members noticed
## `target` (or a member of a pack nearby did, in sight of it). Its members
## wake EnemyAITable.alert_delay s later. `pack` is a Pack (an enemy placed on
## its own has a pack of one).
@warning_ignore("unused_signal")
signal pack_alerted(pack: Node, target: Unit)
## An enemy started a combo plan on `target` (ENEMIES_AI AI-D2): its opener
## comes after its tell. For an audio sting, the overlay and, later, the HUD.
@warning_ignore("unused_signal")
signal combo_plan_started(unit: Unit, target: Unit, plan: ComboPlan)
## Its plan ended, with `reason`: &"done", &"missed" (a step missed and it
## didn't carry on), &"window" (a step couldn't start in time), &"interrupted"
## (its cast cut, it was crowd-controlled, or something urgent came first),
## &"token_lost", &"target_lost", &"low_health", &"odds". The follow-through
## decides next.
@warning_ignore("unused_signal")
signal combo_plan_ended(unit: Unit, target: Unit, plan: ComboPlan, reason: StringName)
## PROTOTYPE (deflect, 2026-10-07; DeflectComponent): `defender`'s dash
## deflected `attacker`'s hit (ctx.deflected; attacker null for the
## environment). Nothing of the hit happened.
@warning_ignore("unused_signal")
signal hit_deflected(attacker: Unit, defender: Unit, ctx: HitContext)
## PROTOTYPE (deflect): `unit`'s deflects in a row changed (0 when it ends or
## after the riposte is given).
@warning_ignore("unused_signal")
signal deflect_streak_changed(unit: Unit, streak: int)
## PROTOTYPE (deflect): `unit`'s second deflect in a row gave it the riposte
## (its next basic attack that hits).
@warning_ignore("unused_signal")
signal riposte_ready(unit: Unit)
## `unit`'s poise changed (PoiseComponent; since ARCHETYPES AR3a it fills up to
## a break: poise damage, decaying, full at the break, empty after it).
@warning_ignore("unused_signal")
signal poise_changed(unit: Unit, value: float, maximum: float)
## `unit`'s poise reached its maximum: it's poise-broken (status_poise_broken).
@warning_ignore("unused_signal")
signal poise_broken(unit: Unit)
## ARCHETYPES AR2: `unit` started casting a perilous attack (Ability.perilous;
## AbilityComponent, at its windup's start): the icon over its head
## (ScreenOverlay), Brains' perilous gate (one live at a time), tests.
@warning_ignore("unused_signal")
signal perilous_started(unit: Unit, ability: Ability)
