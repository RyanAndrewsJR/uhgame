class_name Pack
extends Node2D
## A pack (ENEMIES_AI.md, Aggro, packs and the leash; AI2): the root of a pack
## scene, its Enemy children (enemies with data) its members. Its home is
## where it's placed, and the leash is measured from it. An enemy with data
## placed on its own gets a pack of one (Enemy adds it as its own child, and
## its home is the enemy's spot).
## - It wakes together: the member that notices a party member shouts
##   (Brains.shout()); the rest wake EnemyAITable.alert_delay s later.
## - It gives up together (the leash): when none of its fighting members
##   knows a living party member inside leash_px of home, or none has had a
##   target it can reach for leash_out_of_reach_time s; every member walks
##   home (Enemy.start_return()) and heals there.
## - Fodder's ring around its target is per target, over every pack (Brains
##   places it; get_ring_spots() here), so two packs never stack on one spot.
## Arena and boss enemies never leash (AI7, with spawn-in).

var _members: Array[Enemy] = []
var _home := Vector2.ZERO
var _home_set := false
var _fighting := false
var _last_in_reach := 0.0


func add_member(enemy: Enemy) -> void:
	if enemy != null and not _members.has(enemy):
		_members.append(enemy)


func remove_member(enemy: Enemy) -> void:
	_members.erase(enemy)


## Its living members.
func get_members() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in _members:
		if is_instance_valid(e) and e.is_alive():
			out.append(e)
	return out


## Where it was placed (its position the first time anything asks, so a pack
## built in code and moved into place before its first tick is right).
func get_home() -> Vector2:
	if not _home_set:
		_home = global_position
		_home_set = true
	return _home


## True while a member is aggroed.
func is_fighting() -> bool:
	for e in get_members():
		if e.ai == Enemy.AI.AGGRO:
			return true
	return false


## Seconds since one of its fighting members last had a target it can reach
## (0 while not fighting).
func get_time_out_of_reach() -> float:
	return Brains.get_time() - _last_in_reach if _fighting else 0.0


## Every member walks home (the leash).
func give_up() -> void:
	_fighting = false
	for e in get_members():
		e.start_return()


func _physics_process(_delta: float) -> void:
	get_home()
	var fighting: Array[Enemy] = []
	for e in get_members():
		if e.ai == Enemy.AI.AGGRO:
			fighting.append(e)
	if fighting.is_empty():
		_fighting = false
		return
	var now := Brains.get_time()
	if not _fighting:
		_fighting = true
		_last_in_reach = now
	var anyone_inside := false
	for e in fighting:
		if e.has_target_in_reach():
			_last_in_reach = now
		if e.knows_party_inside_leash():
			anyone_inside = true
	if not anyone_inside or now - _last_in_reach >= Brains.table.leash_out_of_reach_time:
		give_up()


## The fodder ring (Ryan, I6): a place for each of `positions` (fodder around
## `center`, nearest first) on rings around it, so none stack. The first ring
## (`radius`, px, center to center) has as many places as fit with neighbors
## at least 2 × member_radius + spacing apart, spread evenly from the angle
## `anchor` (NAN = the nearest's angle); the nearest fodder take the first
## ring, the rest the next rings out, each that gap farther. Each takes the
## free place nearest it (the closest pairs first), so a fodder at its place
## keeps it, the places move with the target without turning, and none walk
## across the ring. Returns the places in the order of `positions`. Pure (the
## tests call it).
static func get_ring_spots(center: Vector2, positions: Array[Vector2], radius: float, member_radius: float,
		spacing: float, anchor: float = NAN) -> Array[Vector2]:
	var spots: Array[Vector2] = []
	spots.resize(positions.size())
	if positions.is_empty():
		return spots
	var gap := maxf(2.0 * member_radius + spacing, 1.0)
	if is_nan(anchor):
		anchor = (positions[0] - center).angle()
	var start := 0
	var ring := 0
	while start < positions.size():
		var r := maxf(radius + ring * gap, gap * 0.5)
		var capacity := maxi(1, floori(TAU / (2.0 * asin(minf(gap / (2.0 * r), 1.0))) + 0.0001))
		var count := mini(capacity, positions.size() - start)
		var places: Array[Vector2] = []
		for k in capacity:
			places.append(center + Vector2.from_angle(anchor + TAU * k / capacity) * r)
		var pairs: Array = []   # [distance², member index, place index]
		for i in count:
			for k in capacity:
				pairs.append([positions[start + i].distance_squared_to(places[k]), start + i, k])
		pairs.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
		var taken := {}
		var placed := {}
		for pair: Array in pairs:
			if placed.has(pair[1]) or taken.has(pair[2]):
				continue
			spots[pair[1]] = places[pair[2]]
			placed[pair[1]] = true
			taken[pair[2]] = true
			if placed.size() == count:
				break
		start += count
		ring += 1
	return spots
