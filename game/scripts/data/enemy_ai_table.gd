class_name EnemyAITable
extends Resource
## The enemy AI's global rules (ENEMIES_AI.md, EnemyAITable; AI1), held by
## Brains.table (the pattern of LootTable): the ranks, the think rate, the
## respect and patience numbers, the tell, the hold's movement and the
## scores. res://data/enemy_ai_tables/enemy_ai_table_default.tres.
## Every number is a TARGET until the play tests. AI2 added the groups'
## numbers (tokens, the fodder ring, the alert, the leash) and the target
## pick's; AI3b the duel's (cautious, spending, crowded, smell blood, the
## walk read for aim lead), AI3c the odds' (strength, the press, the heavy
## hit) and the think budget, AI-D1 the combos' reads (crowding, the opening)
## and the major tags, AI-D2 the combo plans' (the token's plan time, the
## odds drop, mixup's beat, the whiff time, the blind read); dodging's comes
## with AI4.

## The four ranks (fodder, regular, elite, boss), each a RankRules.
@export var ranks: Array[RankRules] = []

@export_group("Thinking")
## Thinks a second per brain, staggered over the physics ticks.
@export var think_rate: float = 10.0
## An intent holds at least this long (s) unless something urgent breaks it:
## until then it scores intent_hold_bonus more (no flip-flopping).
@export var min_intent_time: float = 0.4
@export var intent_hold_bonus: float = 0.15
## A decision that starts an attack (commit; later punish, finish) holds its
## pose this long (s) before the move (Ryan, I7). On top of the ability's
## own telegraph.
@export var tell_time: float = 0.3
## No reaction is ever faster than this (s), whatever the rank, faction or
## difficulty tier (Ryan, I4).
@export var reaction_floor: float = 0.2
## Each intent's base score (0–1) when the situation allows it, before the
## behavior's intent weights and the jitter (ENEMIES_AI.md, Scoring).
@export var intent_scores: Dictionary[StringName, float] = {
	&"hold": 0.3, &"poke": 0.5, &"commit": 0.65,
	&"defend": 0.9, &"escape": 0.75, &"retreat": 0.7,
	&"peel": 0.9,
}
## A caster's poke scores this instead (it pokes the whole time).
@export var caster_poke_score: float = 0.6

@export_group("Respect")
## An ability's derived respect value by its role tag (Ryan, I2).
@export var respect_by_role: Dictionary[StringName, float] = {
	&"ultimate": 4.0, &"core": 2.0, &"mobility": 2.0, &"defensive": 1.5,
	&"generator": 1.0, &"companion": 0.0,
}
## Added when its data applies a crowd control status (a stun, a slow).
@export var respect_cc_bonus: float = 1.0
## The other champion's ready kit counts this much while it's up and within
## ally_respect_range_px of the enemy (Ryan, I2: half, within 10 m).
@export var ally_respect_weight: float = 0.5
@export var ally_respect_range_px: float = 320.0

@export_group("Patience")
## Patience fills each second by (1 − patience_respect_cut × effective
## respect) ÷ patience_time × (0.5 + aggression) × pressure: with everything
## up it still fills at a quarter of its speed (the floor).
@export_range(0.0, 1.0) var patience_respect_cut: float = 0.75
## Pressure: + idle_pressure while the target has done nothing (no move,
## swing, dash or cast) for idle_time s; + low_pressure while it's below
## low_health of its health.
@export var idle_time: float = 1.5
@export var idle_pressure: float = 0.5
@export_range(0.0, 1.0) var low_health: float = 0.4
@export var low_pressure: float = 0.5

@export_group("Commit")
## A commit ends after this many landed basic attacks, after its first cast,
## or after commit_max_time s; patience empties then.
@export var commit_hits: int = 2
@export var commit_max_time: float = 4.0
## After its own commit a melee enemy walks back out to its band for up to
## this long (s); otherwise, when its target comes inside its band, it holds
## its ground and swings back once the target is in its reach.
@export var back_off_time: float = 2.0

@export_group("Holding")
## The hold's path is re-planned at most this often (s).
@export var hold_replan_time: float = 0.25
## How far along the circle around its target each re-plan aims (px).
@export var strafe_step_px: float = 40.0
## It turns its strafe around after this long (s; random between, jittered).
@export var strafe_turn_min: float = 2.0
@export var strafe_turn_max: float = 4.0

@export_group("Attack tokens")
## Tokens in each champion's pool by difficulty tier 1–5 (Ryan, I3): 2 at
## tiers 1–3, 3 at tiers 4–5. A regular holds 1, an elite 2
## (RankRules.token_cost); fodder and bosses need none.
@export var tokens_per_target: Array[int] = [2, 2, 2, 3, 3]
## A holder keeps its token for at most this long (s; its commit ends then
## too), then can't ask again for token_rest_time s, so attackers rotate
## (Ryan, I3). A holder that's stunned or rooted rests too.
@export var token_hold_time: float = 4.0
@export var token_rest_time: float = 1.5

@export_group("Fodder")
## Pack thinks a second: fodder's places in the ring around its target.
@export var pack_think_rate: float = 5.0
## The gap between two fodder in the ring around their target (px, edge to
## edge; Ryan, I6: about 0.6 m).
@export var fodder_ring_spacing_px: float = 19.0
## The ring sits this share of the fodder's reach out from its target's edge
## (inside its reach, so it hits from its place).
@export_range(0.1, 1.0) var fodder_ring_reach_share: float = 0.5
## A fodder this close to its place in the ring (px) attacks from there;
## farther, it walks to it first (then it keeps attacking from where it
## stands while its target is in its reach).
@export var fodder_ring_tolerance_px: float = 6.0

@export_group("Target pick")
## ALLIES' target pick ("Tier B's resource"): an enemy switches to another
## champion only when its effective distance (edge distance ÷ threat) is
## switch_ratio shorter and switch_px shorter than its target's, without a
## break, for switch_hold_time s.
@export var switch_ratio: float = 0.25
@export var switch_px: float = 48.0
@export var switch_hold_time: float = 0.5

@export_group("Alert and leash")
## The shout (Ryan, I5): the rest of the pack wakes alert_delay s after its
## first member notices, and so do the packs within alert_radius_px (edge to
## edge) that have the shouter in sight.
@export var alert_radius_px: float = 192.0
@export var alert_delay: float = 0.4
## The `alert` pose shows this long when an enemy wakes (its look).
@export var alert_pose_time: float = 0.4
## The shout's sound, at the enemy that noticed (with its pose; never audio only).
@export var alert_sound: SoundEvent
## The leash, from the pack's home (Ryan, I5): its targets all farther than
## leash_px (12 m) from home, or none reachable for leash_out_of_reach_time s.
@export var leash_px: float = 384.0
@export var leash_out_of_reach_time: float = 6.0
## Walking home: return_speed_ratio × its move speed, new aggro ignored for
## return_ignore_time s; once home it heals to full over recover_time s.
@export var return_speed_ratio: float = 1.3
@export var return_ignore_time: float = 2.0
@export var recover_time: float = 1.5
## An enemy checks its path to its target at most this often (s): out of
## reach, a holder lets its token go and the pack's leash timer runs.
@export var reach_check_time: float = 0.5

@export_group("Casters and skirmishers")
## A caster caught (its target inside its band's minimum) with no escape
## ability ready walks away for up to this long (s), escape_step_px at a time;
## out of time, blocked, slowed or rooted it's cornered: it squares up and
## fights for cornered_time (s) and doesn't run meanwhile, swinging at its
## target within cornered_reach_ratio × its reach (Cornered casters).
@export var escape_walk_time: float = 2.0
@export var escape_step_px: float = 64.0
@export var cornered_time: float = 3.0
@export var cornered_reach_ratio: float = 1.5
## A caster holds behind or beside its melee packmates: its nearest one within
## this angle (degrees) of the line to its target counts as cover; and it keeps
## caster_spacing_px (2 m) from other casters (Movement and positioning).
@export var cover_angle_deg: float = 45.0
@export var caster_spacing_px: float = 64.0
## A skirmisher's commit ends at its first landed hit, or reset_time (s) after
## it got to its target; then it hops reset_hop_px back over reset_hop_time
## (s), keeps reset_patience of its patience and walks out to its band
## (Low health: role-based, the skirmisher's hit and reset).
@export var reset_time: float = 1.5
@export var reset_hop_px: float = 64.0
@export var reset_hop_time: float = 0.2
@export_range(0.0, 1.0) var reset_patience: float = 0.5

@export_group("Duels and odds (AI3b)")
## Confidence: once it has spent its key ability it's cautious for this long
## (s; or until the key is ready again): its patience fills × (1 −
## cautious_patience_cut × confidence), and its commit's end walks it out to
## its band's far edge.
@export var cautious_time: float = 3.0
@export_range(0.0, 1.0) var cautious_patience_cut: float = 0.5
## Spending the key ability: outside a right moment it rolls spend_eagerness
## once every spend_roll_time s while it holds the key (a pass frees it until
## the next roll). One right moment: its key's area covering at least
## spend_min_champions champions.
@export var spend_roll_time: float = 2.0
@export var spend_min_champions: int = 2
## A crowded episode ends once its target has stayed this far (px) outside
## its crowded range for crowded_clear_time s.
@export var crowded_clear_time: float = 1.0
@export var crowded_clear_px: float = 16.0
## Smell blood: below its finish_threshold of the target's health, its commit
## (and later finish) score × smell_blood_mult, never above smell_blood_cap
## (so defend, dodge and return still win).
@export var smell_blood_mult: float = 1.3
@export var smell_blood_cap: float = 0.89
## Aim lead: the target's walk is its average velocity over this long (s),
## counted only since its last dash or push.
@export var walk_velocity_time: float = 0.2

@export_group("Odds (AI3c)")
## Strength: the sum over living units of their weight × their health ratio.
## An enemy weighs its rank's (Ryan's start: fodder 0.25, regular 1, elite 2,
## boss 4); a champion champion_strength × its `threat` (Ryan: 1.5); a downed
## one 0.
@export var rank_strength: Dictionary[EnemyData.Rank, float] = {
	EnemyData.Rank.FODDER: 0.25, EnemyData.Rank.REGULAR: 1.0,
	EnemyData.Rank.ELITE: 2.0, EnemyData.Rank.BOSS: 4.0,
}
@export var champion_strength: float = 1.5
## The press = clamp(odds − odds_threshold, 0, 1), the odds being the enemy
## side's strength ÷ the party's. While it's above 0 the enemies press: less
## respect (× (1 − nerve × press)), patience's push odds_pressure × press
## (shared with low health's: the larger), odds_token_bonus more tokens in each
## champion's pool (never past tokens_per_target_cap), the weakest champion
## picked. Bosses don't press (the director owns their tempo).
@export var odds_threshold: float = 1.5
@export var odds_pressure: float = 0.5
@export var odds_token_bonus: int = 1
@export var tokens_per_target_cap: int = 4
## While pressing, the target pick compares effective distance × (1 −
## weakest_pick_weight + weakest_pick_weight × the champion's health ratio):
## at 0.5, (0.5 + 0.5 × health), so a champion at half health counts a
## quarter closer.
@export_range(0.0, 1.0) var weakest_pick_weight: float = 0.5
## One heavy hit at a time, while pressing: no more than one heavy hit (an
## ability hit worth heavy_hit_share of the target's max health by the
## enemy's own numbers) may land on one champion inside heavy_hit_window s
## (Ryan: 0.8, widened from 0.3; 10%). Basic attacks never count.
@export var heavy_hit_window: float = 0.8
@export_range(0.0, 1.0) var heavy_hit_share: float = 0.1
## The think budget: thinks a second over every awake brain. Past it, every
## brain's rate scales down evenly, never under think_rate_floor (a brain
## whose own rate is lower keeps its own).
@export var think_budget: float = 200.0
@export var think_rate_floor: float = 5.0

@export_group("Combos (AI-D1)")
## The attacks a THREATENED use rule's &"major" filter counts (ENEMIES_AI.md,
## Intents): an ability carrying any of these tags (charge_up also matches a
## CHARGE_UP cast style). AI6's whiff rule reads the same list.
@export var major_tags: Array[StringName] = [&"ultimate", &"charge_up", &"dash", &"leap"]
## Crowding (ENEMIES_AI.md, Two reads): how hard its target pushes an enemy,
## the sum (clamped to 1) of: near (1 inside its crowded range, falling to 0
## at its band's minimum), closing (the target's walk toward it ÷
## crowding_closing_full, while within its band's far edge), gap_closer (in
## the last crowding_recent_time s the target dashed or cast an ability that
## moves it, ending inside its band's minimum) and hits (the party's hits on
## it in the last crowding_hit_window s ÷ crowding_hits_full), each × its
## weight. `cc` is read only by the ally (AI-D4: a crowd control on the
## player).
@export var crowding_weights: Dictionary[StringName, float] = {
	&"near": 0.6, &"closing": 0.15, &"gap_closer": 0.3, &"hits": 0.3, &"cc": 0.4,
}
## LoL units a second (400: about the Knight's walk).
@export var crowding_closing_full: float = 400.0
@export var crowding_recent_time: float = 1.0
@export var crowding_hit_window: float = 3.0
@export var crowding_hits_full: int = 3
## The opening: how open its target is to its crowd control and burst, the
## sum (clamped to 1) of: escapes_down (the target's mobility and defensive
## abilities on cooldown, as a share of their respect value), cc_by_other (a
## crowd control from another unit with at least opening_cc_min_left s left),
## recovering (its punish window open: 0 until AI6), committed (casting: a
## cast time, a channel, a held charge-up) and cornered (a wall or a ledge
## within cornered_check_px behind it, seen from the enemy), each × its
## weight. A cast and a crowd control count once its reaction time has
## passed; cooldowns are read at once.
@export var opening_weights: Dictionary[StringName, float] = {
	&"escapes_down": 0.5, &"cc_by_other": 0.5, &"recovering": 0.4, &"committed": 0.4, &"cornered": 0.2,
}
@export var opening_cc_min_left: float = 0.5
@export var cornered_check_px: float = 48.0

@export_group("Combo plans (AI-D2)")
## A commit running a plan keeps its token until the plan ends, up to this
## (s; in place of token_hold_time).
@export var plan_max_time: float = 6.0
## A plan ends when the odds fall below (1 − this) × their value when it
## started (a packmate died, the ally came in).
@export_range(0.0, 1.0) var plan_odds_drop: float = 0.33
## mixup's held beat with one plan fitting (s).
@export var mixup_delay_min: float = 0.4
@export var mixup_delay_max: float = 0.8
## A plan step misses when none of its hits lands on the target within this
## long after its cast ended (a projectile: after its flight past the target;
## a dash: after the dash). Punish's whiff rule (AI6), read on its own cast.
@export var whiff_time: float = 0.3
## The blind read (Ryan, 2026-10-07): an enemy prefers to wait for its opener
## to land, but goes on without it when its target can't answer: its health
## below the enemy's finish_threshold (low_health), none of its mobility or
## defensive abilities ready (escapes_down), an ultimate of its on cooldown
## (ultimate_down), or a crowd control on it with time left (held). Each read
## can be switched off here. On the blind read a missed step carries on, a
## plan may open without its `opener`, and its follow-ups may be cast outside
## a plan.
@export var blind_reads: Dictionary[StringName, bool] = {
	&"low_health": true, &"escapes_down": true, &"ultimate_down": true, &"held": true,
}

@export_group("Strings (ARCHETYPES AR1a)")
## The beat (D8): a string's first hit lands this long after its wind-up
## starts (after the commit's tell_time pose: 0.8 s to read in all, the
## opener's rule of 0.6 s or more). Its later hits follow its swings' timings.
@export var beat: float = 0.5
## Respect sets a string's length (D6): effective respect at or above
## string_respect_short cuts it to string_short_hits; at or below
## string_respect_full (or its target under low_health) it runs its full
## length, and an elite or boss may add one; in between its length is rolled
## in its rank's range (EnemyBrain.get_string_length()).
@export_range(0.0, 1.0) var string_respect_short: float = 0.6
@export_range(0.0, 1.0) var string_respect_full: float = 0.3
@export var string_short_hits: int = 2

## Derived respect values, cached per ability (they read only data).
var _respect_cache: Dictionary = {}
## applies_cc() per ability, cached (AI-D2).
var _cc_cache: Dictionary = {}


## The rules of `rank`, or null.
func get_rank_rules(rank: EnemyData.Rank) -> RankRules:
	for r in ranks:
		if r != null and r.rank == rank:
			return r
	return null


## The tokens in one champion's pool at difficulty tier `tier` (1–5,
## clamped to the list).
func get_tokens_per_target(tier: int) -> int:
	if tokens_per_target.is_empty():
		return 0
	return tokens_per_target[clampi(tier, 1, tokens_per_target.size()) - 1]


## An enemy's weight in its side's strength by `rank` (0 when the table has
## none).
func get_rank_strength(rank: EnemyData.Rank) -> float:
	return rank_strength.get(rank, 0.0)


## Thinks a second for a brain with `data` (AI3c): its rank's think_rate (−1 =
## think_rate), a duelist elite the boss's. Before the budget's scaling.
func get_think_rate_for(data: EnemyData) -> float:
	if data == null:
		return think_rate
	var rank := data.rank
	if data.duelist and rank == EnemyData.Rank.ELITE:
		rank = EnemyData.Rank.BOSS
	var rules := get_rank_rules(rank)
	if rules == null or rules.think_rate < 0.0:
		return think_rate
	return rules.think_rate


## Base score of `intent` (0 when the table has none).
func get_intent_score(intent: StringName) -> float:
	return intent_scores.get(intent, 0.0)


## An ability's respect value (ENEMIES_AI.md, Respect; Ryan, I2): its
## authored `respect_value`, or (−1) the derived one: its role tag's value,
## plus respect_cc_bonus when its data applies a crowd control status. Only
## data the HUD shows matters, never damage numbers.
func get_respect_value(ability: Ability) -> float:
	if ability == null:
		return 0.0
	if ability.respect_value >= 0.0:
		return ability.respect_value
	if _respect_cache.has(ability):
		return _respect_cache[ability]
	# A companion's command has the planned `companion` tag as its role
	# (COMPANIONS.md), not yet one of Ability.ROLE_TAGS.
	var role := &"companion" if ability.tags.has(&"companion") else ability.get_role()
	var value: float = respect_by_role.get(role, 0.0)
	if value > 0.0 and applies_cc(ability):
		value += respect_cc_bonus
	_respect_cache[ability] = value
	return value


## applies_cc() through a cache (AI-D2: the combo plans ask every think; it
## walks the ability's property list).
func ability_applies_cc(ability: Ability) -> bool:
	if ability == null:
		return false
	if not _cc_cache.has(ability):
		_cc_cache[ability] = applies_cc(ability)
	return _cc_cache[ability]


## True when the ability's data applies a status tagged `cc`: a StatusEffect
## (or a list of them) among its exports or its conditional bonuses' target
## statuses, or a `stun_duration` param above 0 (a stun its script applies).
static func applies_cc(ability: Ability) -> bool:
	if ability.has_param(&"stun_duration") and ability.get_base_param(&"stun_duration") > 0.0:
		return true
	for p in ability.get_property_list():
		if not (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		if _is_cc(ability.get(p.name)):
			return true
	for bonus in ability.conditional_bonuses:
		if bonus != null and _is_cc(bonus.target_statuses):
			return true
	return false


static func _is_cc(value: Variant) -> bool:
	if value is StatusEffect:
		return (value as StatusEffect).tags.has(&"cc")
	if value is Array:
		for v: Variant in value:
			if v is StatusEffect and (v as StatusEffect).tags.has(&"cc"):
				return true
	return false
