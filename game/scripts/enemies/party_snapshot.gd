class_name PartySnapshot
extends RefCounted
## One shared read of the party per physics tick (ENEMIES_AI.md, PartySnapshot
## and Performance; AI1), built by Brains the first time a brain asks in a
## tick, never per enemy. Only what the HUD and the screen show (Knowledge):
## each champion's health, which abilities are ready (a charge and the cost
## payable: the HUD's sweep and blue tint, not the conditions), its respect
## share, its idle time. Companions never appear (they aren't Units).
## The party: the groups `player` and `party` (ALLIES adds `party`; until then
## the player, and the sandbox's friendly stand-in).
## AI3 adds casts in progress and projectiles in flight; AI6 the punish window.

## One entry per champion: {unit, position, health_ratio, up, targetable,
## kit_ready, share, idle_time, casting, slots: {slot: {ability, ready,
## cooldown_left, value}}}.
var members: Array[Dictionary] = []
## The physics frame it was built on.
var frame: int = -1


## The entry of `unit`, or {} when it isn't a party member.
func get_member(unit: Node) -> Dictionary:
	for m in members:
		if m.unit == unit:
			return m
	return {}


## Builds the read of `units` (living Units) against `table`'s respect values;
## `idle` holds each unit's idle seconds (Brains tracks them every tick).
static func build(units: Array[Unit], table: EnemyAITable, idle: Dictionary, p_frame: int) -> PartySnapshot:
	var snap := PartySnapshot.new()
	snap.frame = p_frame
	for u in units:
		if not is_instance_valid(u):
			continue
		var max_health := u.health.max_health
		var m := {
			"unit": u,
			"position": u.global_position,
			"health_ratio": u.health.current / max_health if max_health > 0.0 else 0.0,
			"up": u.is_alive(),
			"targetable": u.is_targetable(),
			"idle_time": float(idle.get(u, 0.0)),
			"casting": u.abilities != null and u.abilities.casting,
			"slots": {},
		}
		var total := 0.0
		var ready := 0.0
		if u.abilities != null:
			for slot in AbilityComponent.SLOTS:
				var ability := u.abilities.get_ability(slot)
				if ability == null:
					continue
				var value := table.get_respect_value(ability)
				var is_ready := u.abilities.is_ready(slot) and u.abilities.can_afford(slot)
				m.slots[slot] = {"ability": ability, "ready": is_ready,
					"cooldown_left": u.abilities.get_cooldown_left(slot), "value": value}
				total += value
				if is_ready:
					ready += value
		m.kit_ready = ready / total if total > 0.0 else 0.0
		m.share = get_share(m.kit_ready, m.health_ratio) if m.up else 0.0
		snap.members.append(m)
	return snap


## A champion's respect share: its kit ready × (0.5 + 0.5 × its health
## ratio), so a low champion is respected less (ENEMIES_AI.md, Respect).
static func get_share(kit_ready: float, health_ratio: float) -> float:
	return kit_ready * (0.5 + 0.5 * clampf(health_ratio, 0.0, 1.0))


## The party's respect for an enemy whose target has `target_share`: plus
## `ally_weight` × each other champion's share in `other_shares` (only those
## up and close to that enemy), clamped 0–1.
static func combine_respect(target_share: float, other_shares: Array[float], ally_weight: float) -> float:
	var total := target_share
	for s in other_shares:
		total += ally_weight * s
	return clampf(total, 0.0, 1.0)
