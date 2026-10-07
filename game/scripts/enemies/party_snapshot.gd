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
## AI3 added the casts in progress and the projectiles in flight (what's on
## screen: enemies see them as a person would, after their reaction time);
## AI3b the values behind the share (for the panic-button rule), its
## defensives and its walk (aim lead); AI-D1 its escapes, its crowd control
## and its last gap-closer (the opening and crowding); AI6 adds the punish
## window.

## One entry per champion: {unit, position, health_ratio, up, targetable,
## kit_ready, share, idle_time, casting, slots: {slot: {ability, ready,
## cooldown_left, value}}, cast}. `cast` (AI3) is its cast in progress, {} when
## none: {ability, ctx, kind (&"cast" / &"charge_up"), area
## (Ability.get_effect_area()), time_left (s to its effect), key (one per
## cast)}. AI3b: total_value, ready_value, ready_defensive_value (its ready
## slots' with the `defensive` role), defensives and defensives_ready (how
## many), walk_velocity (px/s; Brains.get_walk_velocity()). AI-D1: escapes and
## escapes_ready (its `mobility` and `defensive` abilities: how many, how many
## ready), escape_value and escape_ready_value (their respect values), ccs
## (each `cc` status on it: {id, source, left (s; −1 = until removed), key}),
## gap_closer (Brains.get_last_gap_closer(): {at, position} or {}).
var members: Array[Dictionary] = []
## Every projectile in flight (AI3): {node, caster, ability, team, position,
## direction, speed_px, range_left_px, half_width_px, key}.
var projectiles: Array[Dictionary] = []
## The physics frame it was built on.
var frame: int = -1


## The entry of `unit`, or {} when it isn't a party member.
func get_member(unit: Node) -> Dictionary:
	for m in members:
		if m.unit == unit:
			return m
	return {}


## Builds the read of `units` (living Units) against `table`'s respect values;
## `idle` holds each unit's idle seconds (Brains tracks them every tick);
## `projectile_nodes` the projectiles in flight (the group Projectile.GROUP);
## `walk` each unit's walk velocity (AI3b); `gap_closers` each unit's last
## gap-closer (AI-D1).
static func build(units: Array[Unit], table: EnemyAITable, idle: Dictionary, p_frame: int, projectile_nodes: Array = [], walk: Dictionary = {},
		gap_closers: Dictionary = {}) -> PartySnapshot:
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
			"up": u.is_alive() and not (u.status_component != null and u.status_component.has_tag(&"downed")),   # AI2: a downed champion isn't up (ALLIES)
			"targetable": u.is_targetable(),
			"idle_time": float(idle.get(u, 0.0)),
			"casting": u.abilities != null and u.abilities.casting,
			"slots": {},
		}
		var total := 0.0
		var ready := 0.0
		var ready_defensive := 0.0
		var defensives := 0
		var defensives_ready := 0
		var escapes := 0
		var escapes_ready := 0
		var escape_value := 0.0
		var escape_ready_value := 0.0
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
				var defensive := ability.tags.has(&"defensive")
				defensives += int(defensive)
				var escape := defensive or ability.tags.has(&"mobility")   # AI-D1: the opening's escapes
				escapes += int(escape)
				if escape:
					escape_value += value
				if is_ready:
					ready += value
					if defensive:
						ready_defensive += value
						defensives_ready += 1
					if escape:
						escapes_ready += 1
						escape_ready_value += value
		m.kit_ready = ready / total if total > 0.0 else 0.0
		m.share = get_share(m.kit_ready, m.health_ratio) if m.up else 0.0
		m.total_value = total
		m.ready_value = ready
		m.ready_defensive_value = ready_defensive
		m.defensives = defensives
		m.defensives_ready = defensives_ready
		m.walk_velocity = walk.get(u, Vector2.ZERO)
		m.cast = read_cast(u)
		m.escapes = escapes
		m.escapes_ready = escapes_ready
		m.escape_value = escape_value
		m.escape_ready_value = escape_ready_value
		m.ccs = read_ccs(u)
		m.gap_closer = gap_closers.get(u, {})
		snap.members.append(m)
	for node in projectile_nodes:
		var p := node as Projectile
		if p == null or not is_instance_valid(p) or not p.is_inside_tree():
			continue
		snap.projectiles.append({
			"node": p, "caster": p.caster if is_instance_valid(p.caster) else null, "ability": p.ability, "team": p.team,
			"position": p.global_position, "direction": p.direction, "speed_px": p.speed_px,
			"range_left_px": p.get_range_left(), "half_width_px": p.half_width_px,
			"key": "projectile:%d" % p.get_instance_id(),
		})
	return snap


## `u`'s cast in progress as enemies see it (AI3; see `members`), or {}: a cast
## whose effect hasn't started (its area from its context), or a charge-up
## held (its area where it would fire now; its time left is its release
## windup at the soonest).
static func read_cast(u: Unit) -> Dictionary:
	if u.abilities == null or not u.abilities.casting:
		return {}
	var ability := u.abilities.get_cast_ability()
	if ability == null:
		return {}
	var ctx := u.abilities.get_cast_context()
	if ctx != null:
		if ctx.progress >= 1.0:
			return {}   # its effect started: nothing coming any more
		return {"ability": ability, "ctx": ctx, "kind": &"cast", "area": ability.get_effect_area(u, ctx),
			"time_left": u.abilities.get_cast_time_left(), "key": "cast:%d" % ctx.get_instance_id()}
	var aim := u.abilities.get_charge_aim()
	if aim == Vector2.INF:
		return {}
	var held := CastContext.new()
	held.ability = ability
	held.point = aim
	var to_aim := aim - u.global_position
	held.direction = to_aim.normalized() if to_aim.length() > 0.01 else Vector2.RIGHT
	return {"ability": ability, "ctx": held, "kind": &"charge_up", "area": ability.get_effect_area(u, held),
		"time_left": ability.cast_time, "key": "charge:%d" % u.get_instance_id()}


## `u`'s crowd control as enemies see it (AI-D1): each status tagged `cc` on
## it, {id, source (null = none or freed), left (s; −1 = until removed), key
## (one per status while it stays on)}.
static func read_ccs(u: Unit) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var sc := u.status_component
	if sc == null or not sc.has_tag(&"cc"):
		return out
	for id in sc.get_status_ids():
		var effect := sc.get_status(id)
		if effect == null or not effect.tags.has(&"cc"):
			continue
		out.append({"id": id, "source": sc.get_source(id), "left": sc.get_time_left(id),
			"key": "cc:%d:%s" % [u.get_instance_id(), id]})
	return out


## A champion's respect share: its kit ready × (0.5 + 0.5 × its health
## ratio), so a low champion is respected less (ENEMIES_AI.md, Respect).
static func get_share(kit_ready: float, health_ratio: float) -> float:
	return kit_ready * (0.5 + 0.5 * clampf(health_ratio, 0.0, 1.0))


## A member's share as an enemy whose finish threshold is `finish_threshold`
## reads it (AI3b, Smell blood: a panic button still counts): below the
## threshold its ready defensive abilities keep their full value, with no
## health cut; the rest is get_share()'s. At or above it, the member's share.
static func get_share_for(m: Dictionary, finish_threshold: float) -> float:
	if not m.get("up", false):
		return 0.0
	var health: float = m.health_ratio
	var total: float = m.get("total_value", 0.0)
	if health >= finish_threshold or total <= 0.0:
		return m.share
	var defensive: float = m.get("ready_defensive_value", 0.0)
	var other: float = float(m.get("ready_value", 0.0)) - defensive
	return (other * (0.5 + 0.5 * clampf(health, 0.0, 1.0)) + defensive) / total


## The party's respect for an enemy whose target has `target_share`: plus
## `ally_weight` × each other champion's share in `other_shares` (only those
## up and close to that enemy), clamped 0–1.
static func combine_respect(target_share: float, other_shares: Array[float], ally_weight: float) -> float:
	var total := target_share
	for s in other_shares:
		total += ally_weight * s
	return clampf(total, 0.0, 1.0)
