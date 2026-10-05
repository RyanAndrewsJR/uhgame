extends Ability
## Korsavil Q, Bladesinger (CHAMPIONS.md and ABILITIES.md, Korsavil; built in
## CHAMPIONS K2).
## Part 0, the orbit: status_bladesinger on her for 6 s (= the recast window).
## While it lasts she gains one Blade (status_blade) each second of game time,
## the first at 1 s: a one-off here, read from the orbit's own clock (its time
## left), so hitstop and the pause hold it like any status timer. The orbit's
## StatScalings follow her Blades (5% less damage taken and 5% more movement
## speed per Blade held, `self_status_stacks`); Blades past 4 are lost.
## Part 1, the recast (at least 1 Blade: a recast condition in the data):
## every held Blade flies at the aim as a spread. How many fly and how hard
## each hits (80 / 90 / 100 / 110% AD at 1 / 2 / 3 / 4) follow the named input
## `blades` = Blades held ÷ 4, set here before the Blades are spent, through
## ChargeScaling entries in the data (a conditional bonus on SELF_HAS_STATUS
## would be checked at each hit, after they're spent). The recast spends every
## Blade and ends the orbit. Each Blade that hits adds an Inevitable Demise
## stack (a conditional bonus with no conditions). If all 4 hit, she becomes
## an Umbral Stalker for 10 s (its REPLACE of R comes in K5).

## Her orbit (status_bladesinger).
@export var orbit_status: StatusEffect
## One Blade (status_blade; its max_stacks is the most she holds).
@export var blade_status: StatusEffect
## Umbral Stalker (status_umbral_stalker): all the recast's Blades hit.
@export var stalker_status: StatusEffect
## Seconds of orbit per Blade gained.
@export var blade_interval: float = 1.0
## How many of the recast's Blades must hit for Umbral Stalker (all four).
@export var stalker_hits: int = 4


func execute(caster: Unit, ctx: CastContext) -> void:
	if caster.status_component == null or orbit_status == null or blade_status == null:
		return
	if ctx.part == 0:
		if caster.status_component.apply_status(orbit_status, caster):
			_gain_blades(caster)   # runs alongside the orbit: not awaited
	else:
		_hurl_blades(caster, ctx)


## One Blade each blade_interval of the orbit, read from its time left, until
## it ends (the recast, its 6 s, death).
func _gain_blades(caster: Unit) -> void:
	var given := 0
	while _orbiting(caster):
		var elapsed := orbit_status.duration - caster.status_component.get_time_left(orbit_status.id)
		var due := floori((elapsed + StatusComponent.EPSILON) / maxf(blade_interval, 0.01))
		while given < due:
			given += 1
			caster.status_component.apply_status(blade_status, caster)
		await caster.get_tree().physics_frame


func _orbiting(caster: Unit) -> bool:
	return is_instance_valid(caster) and caster.is_inside_tree() and caster.is_alive() \
		and caster.status_component.has_status(orbit_status.id)


## The recast: every held Blade at the aim, then the Blades and the orbit end.
func _hurl_blades(caster: Unit, ctx: CastContext) -> void:
	var sc := caster.status_component
	var held := sc.get_stacks(blade_status.id)
	if held <= 0:
		return   # a free cast skips the recast condition: nothing to throw
	ctx.set_input(&"blades", float(held) / float(maxi(blade_status.max_stacks, 1)))
	sc.remove_status(blade_status.id)
	sc.remove_status(orbit_status.id)
	var blades := Projectile.fire(caster, self, ctx, caster.global_position, ctx.direction)
	if stalker_status != null and held >= stalker_hits:
		_watch_for_stalker(caster, ctx, blades)


## Counts the hits of this recast that get through (one per Blade at most:
## pierce 0); when all stalker_hits have hit, Umbral Stalker goes on her.
func _watch_for_stalker(caster: Unit, ctx: CastContext, blades: Array[Projectile]) -> void:
	var hits := [0]   # an Array: a lambda captures locals by value
	var on_hit := func(hit: HitContext) -> void:
		if hit.cast == ctx and hit.source == caster and not hit.blocked:
			hits[0] += 1
	Events.unit_hit.connect(on_hit)
	var tree := caster.get_tree()
	while hits[0] < stalker_hits and blades.any(func(b) -> bool: return is_instance_valid(b)):   # untyped: b may be freed
		await tree.physics_frame
	Events.unit_hit.disconnect(on_hit)
	if hits[0] >= stalker_hits and is_instance_valid(caster) and caster.is_alive() and caster.status_component != null:
		caster.status_component.apply_status(stalker_status, caster)
