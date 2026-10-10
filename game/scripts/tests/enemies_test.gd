extends Node2D
## ENEMIES_AI.md step AI1 test: open res://scenes/tests/enemies_test.tscn and
## press F6. The tooling and the brain skeleton:
## - data: the AI table and its four ranks (tenacity, ability counts, the
##   rank adjusts), the brute preset's twelve sliders, every EnemyData (its
##   ability count under its rank's, at most three overrides: a warning), the
##   default pose set, the slimes on data with today's numbers;
## - EnemyBehavior.resolve(): overrides, adjusts, limits;
## - respect: each ability's derived value (role tag, +1 for crowd control),
##   the authored override, the Knight's kit (10.5), kit ready and share from
##   the shared snapshot, the ally's half weight within 10 m;
## - the RESPECT condition kind and the situation argument;
## - patience: its fill, its floor, pressure;
## - decide(): an ultimate ready at 5 m holds, spent it commits, a poke, the
##   no-flip-flop bonus, intent weights, the same seed giving the same
##   decisions (thousands of seeded runs);
## - the default get_ai_plan() and Ability.ai_uses;
## - the think schedule (staggered, urgent wakes, one snapshot per tick);
## - enemies on data (brains by rank, tenacity, difficulty tier slots, the
##   brain switch, the naive cast loop gated);
## - the test brute against the Knight: it holds in its band with his kit up,
##   crouches for the tell and commits once Lunge and Judgement are down, and
##   its hold always ends within 12 s;
## - ScriptedController; SandboxBrains (the overlay's text, the scenarios,
##   the panel's live change, no saving in a test scene).
## Step AI2, groups:
## - the table's group numbers and the threat stat; the fodder ring's places
##   (Pack.get_ring_spots()); decide() with tokens and a taunt;
## - attack tokens: costs by rank, a pool per champion by difficulty tier,
##   the queue (patience, then the nearest), the rest, the timeout, a stunned
##   or dead holder, a dead target;
## - noticing through WorldQuery (any party member); the shout (the pack 0.4 s
##   later, through walls; other packs within 6 m in sight; no chain);
## - ALLIES' target pick: nearest, sticky with the margin, threat, stealth,
##   taunt, downed, an untargetable target chased;
## - the leash (12 m from home, or 6 s with nothing in reach), the walk home
##   (faster, ignoring sight, a hit only from inside the leash) and recovery;
## - a stunned holder; five test brutes never more than two on the Knight,
##   rotating; fodder in a ring around him with no tokens; the pack scenarios.
## Step AI3, the skirmisher and the caster:
## - the presets, the test enemies and their kits, the table's numbers; the
##   THREATENED kind; Ability.get_effect_area() for the Knight's kit and the
##   defaults; decide() with defend, escape, cornered, retreat, poses by role;
## - the elite caster holding 550–800 u and poking, shielding only when a bolt
##   or Judgement comes at it (after its reaction time), blinking away when
##   caught, walking away with its blink down, then cornered: squared up,
##   swinging, not running for 3 s; falling back behind its brute at low
##   health; the skirmisher stalking, leaping in when the kit drops, hitting,
##   hopping out and resetting; a missed gap-closer keeping the commit going;
##   Shift+H and the mixed pack.
## Step AI3d, the enemy ability library and full kits:
## - the 14 templates (a shared script each, one role tag, their uses); every
##   enemy ability telegraphed at least 0.6 s unless it's a quick chip hit;
##   the test enemies' and the elite slime's kits from the library, inside
##   their rank's band; the root status; respect values;
## - the new archetypes' plans and effect areas (cleave arc, charge,
##   shockwave, hop away), and their casts hitting what the telegraph shows;
##   the snare's root;
## - the brains using the kits: the brute charges in, the elite slime opens
##   with its big hit, the elite caster snares.
## Step AI3b, the duel (Duels and odds):
## - the four sliders, crowded range, the table's numbers; the key ability
##   (ultimate, else the highest respect value, ties to the earlier slot) and
##   its own kit read; effective respect and patience with confidence; a real
##   brute spending its smash turns cautious and walks out to its band's far
##   edge (not at confidence 0);
## - spending: a held key's damage, cc and zone uses left out (never a poke
##   or a gap-closer), the right moments, the roll's rate (one per 2 s), a
##   real brute holding its smash until the Knight is low;
## - crowded: one seeded roll per episode (all in at about crowded_commit
##   with an answer, else backing up at about 1 − aggression), cornered and
##   escape first; a real brute's episode after its reaction time, all in,
##   backing up once, standing, the episode ending 1 s after he leaves;
## - smell blood's scores and the panic-button share; aim lead's point, the
##   default plan, Brains' walk read (zero while dashing), a real bolt hitting
##   a walking Knight only when led; the overlay's duel lines; step_back.
## Step AI3c, the odds and think rates by rank (Duels and odds):
## - nerve, the table's numbers, the ranks' think rates, duelist, the press
##   pose; each side's strength by hand (a 1v1, a 3v1, an elite and fodder,
##   against the Knight and the ally, the ally downed, the Knight at 30%);
## - the press's rules (respect × (1 − nerve × press), one shared push, the
##   press pose); the pool +1 and never past the cap; the weakest pick with
##   the margin, taunt, stealth and a boss's; one heavy hit at a time (Brains'
##   landing times, a real brain's smash refused, scripted and outside a
##   press allowed); thinks per rank over 10 s and the budget's scaling,
##   reaction times unchanged, a gap-closer's follow-up never waiting a
##   reaction time; three brutes and an elite pressing (a third attacker, the
##   press pose, never two heavy hits within 0.8 s), one brute changing
##   nothing, the ally down; the overlay's odds line and think rate.
## Step AI-D1, the test duelist, crowding and the opening (Combos):
## - the two sliders, the table's weights and numbers, the `peel` intent tag,
##   the four condition kinds, the recover pose, the duelist's data and kit
##   (library copies, respect 10.5, combo roles, the finisher's recovery);
## - crowding's terms by hand (inside, a Lunge in to 2.75 m, 1 m outside,
##   closing, a string of hits) and Brains' reads (a real Lunge is a
##   gap-closer, a push isn't; the party's hits, DoT ticks not counted); the
##   opening's terms by hand and a real brain's read (escapes, a crowd control
##   by another after its reaction time, committed, cornered);
## - the roll: a peel in every episode at crowded_commit 0, all in at its
##   rate, no peel use = AI3b's mix; THREATENED's major filter (Judgement yes,
##   Cleave no); the guard's two defend uses;
## - a real duelist: the episode from crowding (inside, not 1 m out, a Lunge
##   in at 0.6 but not 0.7, a string of hits), the peel (the snare, then a
##   step back), the setup (escapes down: snare first without waiting for
##   patience; not below the bar; the strike when the snare is down; none for
##   an enemy with no opener), the finisher's recovery (still, no swing, no
##   cast, the recover pose), its guard against Judgement (not Cleave) and
##   when low and crowded; SandboxBrains (Shift+H, escapes down, the overlay's
##   combo lines, the panel's nineteen rows).
## Tests of older rules pin AI3b's sliders (and AI3c's nerve) to their AI3
## values (_pin_ai3()); AI2's five brutes play with the press off (_no_press()).
## ARCHETYPES AR1a, strings (ARCHETYPES.md, Strings and the beat):
## - the table's beat and respect numbers, the ranks' lengths, the new
##   fields' defaults; every test string's shape, its first wind-up the beat,
##   later wind-ups 0.25 s or more, its spacing ±0.05 s (the repeated last
##   swing too), deflectable swings in the chip band; the casters have none
##   yet (AR1b); the AI3 skirmisher checks run on a copy with no string;
## - get_string_length() by respect, a low target and rank (pure, seeded);
## - run_string() on passive enemies: the first hit on the beat (or any
##   opener), the spacing, the end, no League-style windup; cut short by a
##   stun, cancel(), death and its target turning untargetable; refused in
##   combo mode, under a lock, for 0 hits or no string; a deflect pair inside
##   one string (the Knight's test deflect) not ending it;
## - real brains: a brute's commit into its string (the tell, the beat, its
##   2 hits, its token held to the end), the elite slime's 3–4; the token
##   freed on a stun (patience kept), a poise break and death; a deflect not
##   ending a brain's string; the skirmisher's leap, string and reset; a
##   plan's STRING step after the duelist's snare; a string opener never
##   fitting; the overlay's string line;
## - the mix (Ryan, 2026-10-08): at string_then_cast_chance 1 the string
##   first and a ready damage cast after it as its finisher, at 0 the cast
##   first (the older checks run at 0, AI1's commit).
## ARCHETYPES AR1b, the Mage's volley (RANGED strings):
## - its data (3 bolts at 0.45 s; the casters carry it; the caster preset
##   commits, weight 1; a committing caster-role enemy needs a ranged
##   string); a passive caster's volley (on the beat, one bolt a release,
##   basic attack hits tagged projectile after their flight, the end before
##   the last bolt lands); walking in only to its range; a deflect pair on
##   its bolts (absorbed); Projectile.fire_swing() (the swing's numbers, a
##   wall, a freed attacker's snapshot); real casters committing into it from
##   their band, their token held, a poke scoring higher mid-volley taking
##   nothing back.
## ARCHETYPES AR3b, the test Assassin (its stance's deflect, the rebuff, its
## riposte and its meter: deflect_test): Role.ASSASSIN and its preset, its
## data, kit and string against its archetype's shape, the stance's data and
## use, the table's range, its scene, the poses; a real one raising its
## stance when the Knight closes in (after its reaction time, no token),
## recovering after a whiff, not again on its cooldown; the read's rules.
## TEMP, the enemy attack speed test multiplier (DECISIONS.md, Testing): off
## by default; at x1.0 every number is today's exactly; at x1.5 with keep DPS
## the same damage per second over 10 s, more swings, the windup floor; the
## player and the ally untouched; its limits; SandboxBrains' row and reset.
## Brains.rng is seeded. Prints PASS/FAIL per check, then a total. Run
## headless and it quits with the number of failures as the exit code.

const KNIGHT: ChampionData = preload("res://data/champions/knight.tres")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const SLIME_SCENE: PackedScene = preload("res://scenes/enemies/slime.tscn")
const ELITE_SCENE: PackedScene = preload("res://scenes/enemies/slime_elite.tscn")
const BRUTE_SCENE: PackedScene = preload("res://scenes/enemies/test_brute.tscn")
const BRUTE_BEHAVIOR: EnemyBehavior = preload("res://data/enemy_behaviors/enemy_behavior_brute.tres")
const BRUTE_DATA: EnemyData = preload("res://data/enemies/enemy_test_brute.tres")
const SLIME_DATA: EnemyData = preload("res://data/enemies/enemy_slime.tres")
const ELITE_DATA: EnemyData = preload("res://data/enemies/enemy_slime_elite.tres")
const POSE_SET: PoseSet = preload("res://data/pose_sets/pose_set_default.tres")
const CLEAVE: Ability = preload("res://data/abilities/knight_q_cleave.tres")
const IRON_RESOLVE: Ability = preload("res://data/abilities/knight_w_iron_resolve.tres")
const LUNGE: Ability = preload("res://data/abilities/knight_e_lunge.tres")
const JUDGEMENT: Ability = preload("res://data/abilities/knight_r_judgement.tres")
const SMASH: Ability = preload("res://data/abilities/test_brute_q_smash.tres")
const SLAM: Ability = preload("res://data/abilities/slime_elite_q_slam.tres")
const VECTOR_WALL: Ability = preload("res://data/abilities/test_w_vector_wall.tres")
const STATUS_SLOW: StatusEffect = preload("res://data/statuses/status_slow.tres")
const ENEMY_DATA_DIR := "res://data/enemies/"
# AI3
const SKIRMISHER_SCENE: PackedScene = preload("res://scenes/enemies/test_skirmisher.tscn")
const CASTER_SCENE: PackedScene = preload("res://scenes/enemies/test_caster.tscn")
const CASTER_ELITE_SCENE: PackedScene = preload("res://scenes/enemies/test_caster_elite.tscn")
const SKIRMISHER_BEHAVIOR: EnemyBehavior = preload("res://data/enemy_behaviors/enemy_behavior_skirmisher.tres")
const CASTER_BEHAVIOR: EnemyBehavior = preload("res://data/enemy_behaviors/enemy_behavior_caster.tres")
const SKIRMISHER_DATA: EnemyData = preload("res://data/enemies/enemy_test_skirmisher.tres")
const CASTER_DATA: EnemyData = preload("res://data/enemies/enemy_test_caster.tres")
const CASTER_ELITE_DATA: EnemyData = preload("res://data/enemies/enemy_test_caster_elite.tres")
const LEAP: Ability = preload("res://data/abilities/test_skirmisher_q_leap.tres")
const STAB: Ability = preload("res://data/abilities/test_skirmisher_w_stab.tres")
const CASTER_BOLT: Ability = preload("res://data/abilities/test_caster_q_bolt.tres")
const GUARD: Ability = preload("res://data/abilities/test_caster_w_guard.tres")
const ESCAPE_BLINK: Ability = preload("res://data/abilities/test_caster_e_blink.tres")
const TEST_BOLT: Ability = preload("res://data/abilities/test_q_bolt.tres")
const JUDGEMENT_LEAP: Ability = preload("res://data/abilities/knight_r_judgement_leap.tres")
# AI3d
const LIBRARY_DIR := "res://data/abilities/enemy/"
## The library's archetypes (ENEMIES_AI.md, Kits; the pool waits for
## WORLD_INTERACTION's Hazards): each template's script, role tag and the
## intents of its uses.
const LIBRARY := {
	"smash": ["res://scripts/abilities/slime/slam.gd", &"core", [&"damage"]],
	"cleave_arc": ["res://scripts/abilities/enemy/cleave_arc.gd", &"core", [&"damage", &"zone"]],
	"charge": ["res://scripts/abilities/enemy/dash_strike.gd", &"mobility", [&"gap_close"]],
	"shockwave": ["res://scripts/abilities/enemy/shockwave.gd", &"core", [&"damage", &"cc"]],
	"leap": ["res://scripts/abilities/test_skirmisher/leap.gd", &"mobility", [&"gap_close"]],
	"stab": ["res://scripts/abilities/slime/slam.gd", &"core", [&"damage"]],
	"hop_away": ["res://scripts/abilities/enemy/hop_away.gd", &"mobility", [&"escape"]],
	"flurry": ["res://scripts/abilities/enemy/dash_strike.gd", &"core", [&"damage", &"punish"]],
	"bolt": ["res://scripts/abilities/test/bolt.gd", &"core", [&"poke"]],
	"lobbed_orb": ["res://scripts/abilities/slime/slam.gd", &"core", [&"poke", &"zone"]],
	"snare": ["res://scripts/abilities/test/bolt.gd", &"core", [&"poke", &"cc"]],
	"blink_away": ["res://scripts/abilities/test_caster/escape_blink.gd", &"mobility", [&"escape"]],
	"guard": ["res://scripts/abilities/test_caster/guard.gd", &"defensive", [&"defend"]],
	"big_hit": ["res://scripts/abilities/slime/slam.gd", &"ultimate", [&"damage", &"punish", &"finish"]],
}
const HOP: Ability = preload("res://data/abilities/enemy/enemy_hop_away.tres")
const STATUS_ROOT: StatusEffect = preload("res://data/statuses/status_root.tres")
## Every enemy ability's telegraph is at least this long (ENEMIES_AI.md, Kits)...
const TELEGRAPH_MIN := 0.6
## ...unless it's in COMBAT's chip band: at most this share of the target's
## max health (the Knight's 650: 32.5).
const CHIP_SHARE := 0.05
## A follow-up (combo roles, none of them `opener`) may be faster, down to
## this (Ryan's tuning pass, 2026-10-07: only the opener needs the long
## telegraph; the 0.25 s windup floor of the TEMP attack speed test).
const FOLLOW_UP_MIN := 0.25
## Where the fights happen, away from the origin.
const ARENA := Vector2(3000, 0)
# AI-D1
const DUELIST_SCENE: PackedScene = preload("res://scenes/enemies/test_duelist.tscn")
# ARCHETYPES AR3b
const ASSASSIN_SCENE: PackedScene = preload("res://scenes/enemies/test_assassin.tscn")
const ASSASSIN_DATA: EnemyData = preload("res://data/enemies/enemy_test_assassin.tres")
const ASSASSIN_BEHAVIOR: EnemyBehavior = preload("res://data/enemy_behaviors/enemy_behavior_assassin.tres")
const DUELIST_DATA: EnemyData = preload("res://data/enemies/enemy_test_duelist.tres")
const D_SNARE: Ability = preload("res://data/abilities/test_duelist_q_snare.tres")
const D_GUARD: Ability = preload("res://data/abilities/test_duelist_w_guard.tres")
const D_STRIKE: Ability = preload("res://data/abilities/test_duelist_e_strike.tres")
const D_FINISHER: Ability = preload("res://data/abilities/test_duelist_r_finisher.tres")
const CHARGED_LINE: Ability = preload("res://data/abilities/test_q_charged_line.tres")

@onready var entities: Node2D = $Entities

var knight: Player
var _passed: int = 0
var _failed: int = 0
var _odds_threshold_saved := -1.0   # _no_press() (AI3c)
var _mix_saved := 0.5   # the table's string_then_cast_chance (pinned to 0 for the older checks)
var _perilous_quiet_saved := 6.0   # the table's perilous_quiet_time (pinned to 0 for the older checks; AR2)


func _ready() -> void:
	print("\n=== Enemies test (ENEMIES_AI AI1–AI3d, AI3b, AI3c, AI-D1, AI-D2, AI-D3; ARCHETYPES AR1a, AR1b, AR2, AR3b) ===")
	Progress.get_progress(KNIGHT)   # the save guards latch off first (a test scene)
	Loot.get_inventory(KNIGHT)
	Brains.rng.seed = 20261004
	_add_navigation()   # move orders path on it (without one they'd head for the origin)
	await _frames(3)
	knight = PLAYER_SCENE.instantiate()
	entities.add_child(knight)
	await get_tree().physics_frame
	_place(knight, ARENA)
	# The older checks see AI1's commit: a damage cast first. The mix (AR1a's
	# follow-up, Ryan 2026-10-08) has its own test.
	_mix_saved = Brains.table.string_then_cast_chance
	Brains.table.string_then_cast_chance = 0.0
	# The older checks see a fight's perilous moves from its start: the perilous
	# gate's quiet time (ARCHETYPES AR2) has its own test.
	_perilous_quiet_saved = Brains.table.perilous_quiet_time
	Brains.table.perilous_quiet_time = 0.0

	_test_table()
	_test_brute_preset()
	_test_enemy_data_files()
	_test_pose_set()
	_test_resolve()
	_test_respect_values()
	await _test_snapshot()
	_test_condition_respect()
	_test_patience()
	_test_decide()
	_test_decide_seeded()
	await _test_cast_plan()
	await _test_enemies_on_data()
	await _test_schedule()
	await _test_naive_gate()
	await _test_brute_holds_then_commits()
	await _test_hold_ends_within_12s()
	await _test_scripted_controller()
	await _test_sandbox_brains()

	# AI2: groups.
	_test_ai2_data()
	_test_ring_spots()
	_test_decide_tokens()
	await _test_tokens()
	await _test_sight()
	await _test_pack_alert()
	await _test_target_pick()
	await _test_leash()
	await _test_unreachable()
	await _test_stunned_holder()
	await _test_five_brutes()
	await _test_fodder_ring()
	await _test_sandbox_packs()

	# AI3: the skirmisher and the caster.
	_test_ai3_data()
	_test_threatened()
	await _test_effect_areas()
	_test_decide_ai3()
	await _test_caster_band_and_poke()
	await _test_caster_defends()
	await _test_caster_escapes()
	await _test_caster_falls_back()
	await _test_skirmisher()
	await _test_skirmisher_miss()
	await _test_gap_closer_commit()
	await _test_sandbox_ai3()

	# AI3d: the enemy ability library and full kits.
	_test_ai3d_library()
	_test_ai3d_telegraph_rule()
	_test_ai3d_kits()
	await _test_ai3d_plans()
	await _test_ai3d_casts()
	await _test_ai3d_brains()

	# AI3b: the duel (Duels and odds).
	_test_ai3b_data()
	await _test_ai3b_key_and_confidence()
	await _test_ai3b_spend()
	await _test_ai3b_crowded()
	await _test_ai3b_own_commit()
	await _test_ai3b_smell_blood()
	await _test_ai3b_aim_lead()
	await _test_ai3b_overlay_and_poses()

	# AI3c: the odds, and think rates by rank.
	_test_ai3c_data()
	await _test_ai3c_odds()
	_test_ai3c_press_rules()
	await _test_ai3c_tokens()
	await _test_ai3c_weakest_pick()
	await _test_ai3c_heavy_hits()
	await _test_ai3c_think_rates()
	await _test_ai3c_follow_up()
	await _test_ai3c_pack_presses()
	await _test_ai3c_overlay()

	# AI-D1: the test duelist, crowding and the opening (Combos).
	_test_aid1_data()
	_test_aid1_crowding()
	await _test_aid1_brains_reads()
	_test_aid1_opening()
	_test_aid1_peel_roll()
	_test_aid1_threatened()
	await _test_aid1_guard_uses()
	await _test_aid1_episode_start()
	await _test_aid1_peel()
	await _test_aid1_brain_opening()
	await _test_aid1_setup()
	await _test_aid1_recovery()
	await _test_aid1_guard()
	await _test_aid1_sandbox()

	# AI-D2: combo plans and the follow-through.
	_test_aid2_data()
	_test_aid2_blind_read()
	_test_aid2_pick_plan()
	_test_aid2_next_step()
	_test_aid2_lean()
	await _test_aid2_snapshot()
	await _test_aid2_snare_first()
	await _test_aid2_missed_opener()
	await _test_aid2_strike_plans()
	await _test_aid2_follow_through()
	await _test_aid2_token()
	await _test_aid2_ends()
	await _test_aid2_sandbox()

	# AI-D3: diminishing returns on crowd control.
	await _test_aid3_rank_rules()
	_test_aid3_enemy_cc()
	await _test_aid3_boss()
	await _test_aid3_brain_sees_the_ring()
	await _test_aid3_panel_scroll()

	# ARCHETYPES AR1a: strings, the beat and token holding.
	_test_ar1a_data()
	_test_ar1a_length()
	await _test_ar1a_timing()
	await _test_ar1a_cut()
	await _test_ar1a_deflect_pair()
	await _test_ar1a_brain_commit()
	await _test_ar1a_token_freed()
	await _test_ar1a_skirmisher()
	await _test_ar1a_plan_step()
	await _test_ar1a_sandbox()
	await _test_ar1a_mix()

	# ARCHETYPES AR1b: the Mage's volley (RANGED strings).
	_test_ar1b_data()
	await _test_ar1b_volley()
	await _test_ar1b_walks_in()
	await _test_ar1b_deflect()
	await _test_ar1b_shot()
	await _test_ar1b_brain()

	# ARCHETYPES AR2: perilous attacks and their icon (the icon: view_test).
	_test_ar2_data()
	await _test_ar2_gate()
	await _test_ar2_brain_gate()
	await _test_ar2_rebuffed()

	# ARCHETYPES AR3b: the test Assassin (its stance's deflect, the rebuff and its meter: deflect_test).
	_test_ar3b_data()
	await _test_ar3b_brain()

	# TEMP: the enemy attack speed test multiplier (DECISIONS.md, Testing).
	await _test_temp_attack_speed()

	Brains.table.string_then_cast_chance = _mix_saved
	Brains.table.perilous_quiet_time = _perilous_quiet_saved
	Audio.stop_all()
	await _frames(120)   # stop_all() leaves the UI bus: let the ultimate-ready pings (reset_cooldown()) finish
	print("=== %d passed, %d failed ===\n" % [_passed, _failed])
	if DisplayServer.get_name() == "headless":
		get_tree().quit(_failed)


# --- Data ---------------------------------------------------------------------------

func _test_table() -> void:
	_section("The AI table and its four ranks")
	var t := Brains.table
	_check("the table loads with four ranks", [t != null, t.ranks.size()], [true, 4])
	var rows: Array = []
	for rank in [EnemyData.Rank.FODDER, EnemyData.Rank.REGULAR, EnemyData.Rank.ELITE, EnemyData.Rank.BOSS]:
		var r := t.get_rank_rules(rank)
		rows.append([r.has_brain, r.can_dodge, r.token_cost, r.tenacity, r.min_abilities, r.max_abilities])
	_check("fodder / regular / elite / boss: brain, dodge, token cost, tenacity (I8), abilities min–max (AI3d, Ryan: Kits)",
		rows, [[false, false, 0, 0.0, 0, 0], [true, false, 1, 0.0, 2, 3], [true, true, 2, 0.2, 3, 5], [true, true, 0, 0.4, 4, 6]])
	var regular := t.get_rank_rules(EnemyData.Rank.REGULAR).brain_adjust
	var boss := t.get_rank_rules(EnemyData.Rank.BOSS).brain_adjust
	_check("the regular's adjust: reaction × 1.3, jitter × 1.5, punish greed × 0.5",
		[regular.reaction_time, regular.jitter, regular.punish_greed, regular.aggression], [1.3, 1.5, 0.5, 1.0])
	_check("the boss's: reaction × 0.85, jitter × 0.7", [boss.reaction_time, boss.jitter, boss.punish_greed], [0.85, 0.7, 1.0])
	_check("the elite's: none (× 1)", t.get_rank_rules(EnemyData.Rank.ELITE).brain_adjust, null)
	_check("think rate 10, min intent 0.4 s, tell 0.3 s, reaction floor 0.2 s",
		[t.think_rate, t.min_intent_time, t.tell_time, t.reaction_floor], [10.0, 0.4, 0.3, 0.2])
	_check("respect by role: ultimate 4, core 2, mobility 2, defensive 1.5, generator 1, companion 0; cc +1",
		[t.respect_by_role[&"ultimate"], t.respect_by_role[&"core"], t.respect_by_role[&"mobility"], t.respect_by_role[&"defensive"],
			t.respect_by_role[&"generator"], t.respect_by_role[&"companion"], t.respect_cc_bonus], [4.0, 2.0, 2.0, 1.5, 1.0, 0.0, 1.0])
	_check("the ally counts half within 10 m (I2)", [t.ally_respect_weight, t.ally_respect_range_px, Units.px_to_m(t.ally_respect_range_px)], [0.5, 320.0, 10.0])
	_check("pressure: idle 1.5 s +0.5, below 40% +0.5", [t.idle_time, t.idle_pressure, t.low_health, t.low_pressure], [1.5, 0.5, 0.4, 0.5])
	_check("the think period at 60 Hz: 6 ticks", Brains.get_think_period(), 6)


func _test_brute_preset() -> void:
	_section("The brute preset: the twelve sliders (I1)")
	var b := BRUTE_BEHAVIOR
	_check("role BRUTE, fights to the death, uses tokens", [b.role, b.low_health, b.uses_tokens], [EnemyBehavior.Role.BRUTE, EnemyBehavior.LowHealth.FIGHT_ON, true])
	var values: Array = []
	for s in EnemyBehavior.SLIDERS:
		values.append(b.get_slider(s))
	_check("aggression .5, respect 1, patience 3, band 350–500, reaction .35, dodge .4 / 6, greed .6, finish .3, pressure 12, breather 5, jitter .15; AI3b: confidence .5, all in .6, lead 0, spend .4; AI3c: nerve .6; AI-D1: peel .6, opening .5; AI-D2: follow-through .6, greed .6, mixup .15",
		values, [0.5, 1.0, 3.0, 350.0, 500.0, 0.35, 0.4, 6.0, 0.6, 0.3, 12.0, 5.0, 0.15, 0.5, 0.6, 0.0, 0.4, 0.6, 0.6, 0.5, 0.6, 0.6, 0.15])
	_check("23 fields, 22 sliders (the band is one, with two ends; AI3b added four, AI3c nerve, AI-D1 peel_threshold and opening_bar, AI-D2 follow_through, combo_greed and mixup)", [EnemyBehavior.SLIDERS.size(), EnemyBehavior.LIMITS.size()], [23, 23])
	var in_limits := true
	for s in EnemyBehavior.SLIDERS:
		var lim: Array = EnemyBehavior.LIMITS[s]
		in_limits = in_limits and b.get_slider(s) >= lim[0] and b.get_slider(s) <= lim[1]
	_check("every value inside its limits", in_limits, true)
	_check("a missing intent weight counts 1", b.get_intent_weight(&"commit"), 1.0)


func _test_enemy_data_files() -> void:
	_section("Every EnemyData: abilities under its rank's count, at most 3 overrides")
	var dir := DirAccess.open(ENEMY_DATA_DIR)
	var files: Array[String] = []
	for f in dir.get_files():
		if f.ends_with(".tres"):
			files.append(f)
	_check("the AI1 enemies exist", files.has("enemy_slime.tres") and files.has("enemy_slime_elite.tres") and files.has("enemy_test_brute.tres"), true)
	var problems: Array[String] = []
	for f in files:
		var data: EnemyData = load(ENEMY_DATA_DIR + f)
		var rules := Brains.table.get_rank_rules(data.rank)
		var count := data.get_abilities_at(5).size()
		if rules.max_abilities >= 0 and count > rules.max_abilities:
			problems.append("%s: %d abilities, rank allows %d" % [f, count, rules.max_abilities])
		if count < rules.min_abilities:   # AI3d (Kits): a warning, as for overrides
			print("  WARN  %s has %d abilities, under its rank's %d" % [f, count, rules.min_abilities])
		if rules.has_brain != (data.behavior != null):
			problems.append("%s: a brain rank needs a behavior, fodder none" % f)
		if data.stats == null or data.id == &"":
			problems.append("%s: no stats or id" % f)
		if data.overrides.size() > 3:
			print("  WARN  %s has %d overrides (at most 3: kind, not magnitude)" % [f, data.overrides.size()])
	_check("no problems in %d files" % files.size(), problems, [])
	_check("the slime: fodder, no behavior, slime.tres, its green",
		[SLIME_DATA.rank, SLIME_DATA.behavior, SLIME_DATA.stats.resource_path, SLIME_DATA.model_color],
		[EnemyData.Rank.FODDER, null, "res://data/units/slime.tres", Color(0.35, 0.85, 0.4, 1)])
	_check("the elite slime: an elite brute with the slam",
		[ELITE_DATA.rank, ELITE_DATA.behavior == BRUTE_BEHAVIOR, ELITE_DATA.get_abilities_at(1).get(&"q") == SLAM, ELITE_DATA.stats.resource_path],
		[EnemyData.Rank.ELITE, true, true, "res://data/units/slime_elite.tres"])
	_check("the test brute: a regular brute with the smash",
		[BRUTE_DATA.rank, BRUTE_DATA.behavior == BRUTE_BEHAVIOR, BRUTE_DATA.get_abilities_at(1).get(&"q") == SMASH, BRUTE_DATA.get_source_id()],
		[EnemyData.Rank.REGULAR, true, true, &"enemy_test_brute"])
	_check("the smash: POINT, 0.7 s telegraph, 250 range, 80 damage (12% of 650: the elite band's lower part)",
		[SMASH.targeting, SMASH.cast_time, SMASH.cast_range, SMASH.base_damage, SMASH.get_role()],
		[Ability.Targeting.POINT, 0.7, 250.0, 80.0, &"core"])


func _test_pose_set() -> void:
	_section("The default pose set (I7)")
	var names := ["hold", "crouch", "draw_back", "stalk", "recoil", "guard", "step_back", "cornered", "sidestep", "pressure", "breather", "finish", "alert", "return"]
	var missing: Array = []
	for n in names:
		if POSE_SET.get_look(StringName(n)) == null:
			missing.append(n)
	_check("every pose of the minimum set has a look", missing, [])
	var hold := POSE_SET.get_look(&"hold")
	var crouch := POSE_SET.get_look(&"crouch")
	var draw_look := POSE_SET.get_look(&"draw_back")
	_check("hold: upright, leaning back 5°", [hold.lean_deg, hold.squash, hold.rim_color.a], [-5.0, 1.0, 0.0])
	_check("crouch: squash 0.8, lean in 15°", [crouch.lean_deg, crouch.squash], [15.0, 0.8])
	_check("draw_back: lean back 15°, stretch 1.1, an orange rim pulse", [draw_look.lean_deg, draw_look.squash, draw_look.rim_color.a > 0.0, draw_look.pulse_hz > 0.0], [-15.0, 1.1, true, true])
	_check("no pose: no look", POSE_SET.get_look(&""), null)


func _test_resolve() -> void:
	_section("EnemyBehavior.resolve(): overrides, adjusts, limits")
	var t := Brains.table
	var regular := t.get_rank_rules(EnemyData.Rank.REGULAR).brain_adjust
	var adjusts: Array[BrainAdjust] = [regular]
	var r := BRUTE_BEHAVIOR.resolve({}, adjusts)
	_check("a regular brute: reaction 0.455, jitter 0.225, greed 0.3, the rest as the preset",
		[snappedf(r.reaction_time, 0.0001), snappedf(r.jitter, 0.0001), snappedf(r.punish_greed, 0.0001), r.patience_time, r.range_band_min], [0.455, 0.225, 0.3, 3.0, 350.0])
	var o := BRUTE_BEHAVIOR.resolve({&"patience_time": 5.0, &"range_band_max": 600.0}, adjusts)
	_check("an override replaces the preset's value", [o.patience_time, o.range_band_max, o.range_band_min], [5.0, 600.0, 350.0])
	var fast := BrainAdjust.new()
	fast.reaction_time = 0.1
	fast.range_band = 2.0
	fast.jitter = 10.0
	var both: Array[BrainAdjust] = [regular, fast]
	var c := BRUTE_BEHAVIOR.resolve({}, both)
	_check("adjusts multiply, then the limits clamp (reaction ≥ 0.2, jitter ≤ 0.5)", [c.reaction_time, c.jitter], [0.2, 0.5])
	_check("the band's multiplier moves both ends", [c.range_band_min, c.range_band_max], [700.0, 1000.0])
	var flipped := BRUTE_BEHAVIOR.resolve({&"range_band_min": 900.0, &"range_band_max": 400.0}, [] as Array[BrainAdjust])
	_check("the band's max stays at least its min", [flipped.range_band_min, flipped.range_band_max], [900.0, 900.0])
	_check("the preset itself is untouched", [BRUTE_BEHAVIOR.reaction_time, BRUTE_BEHAVIOR.patience_time], [0.35, 3.0])
	_check("the kind is shared, not copied", r.intent_weights == BRUTE_BEHAVIOR.intent_weights, true)


func _test_respect_values() -> void:
	_section("Respect values (I2): the role tag, +1 for crowd control, the authored override")
	var t := Brains.table
	_check("the Knight: Cleave 2, Iron Resolve 1.5, Lunge 2, Judgement 4 + 1 (its stun)",
		[t.get_respect_value(CLEAVE), t.get_respect_value(IRON_RESOLVE), t.get_respect_value(LUNGE), t.get_respect_value(JUDGEMENT)], [2.0, 1.5, 2.0, 5.0])
	_check("the whole kit is 10.5", t.get_respect_value(CLEAVE) + t.get_respect_value(IRON_RESOLVE) + t.get_respect_value(LUNGE) + t.get_respect_value(JUDGEMENT), 10.5)
	_check("Judgement's stun is read from its stun_duration; Iron Resolve's slow lives in its script (no +1)",
		[EnemyAITable.applies_cc(JUDGEMENT), EnemyAITable.applies_cc(IRON_RESOLVE), EnemyAITable.applies_cc(CLEAVE)], [true, false, false])
	var authored: Ability = CLEAVE.duplicate()
	authored.respect_value = 0.5
	_check("an authored respect_value wins (−1 = derived)", [t.get_respect_value(authored), CLEAVE.respect_value], [0.5, -1.0])
	var generator := Ability.new()
	generator.tags = [&"generator"]
	var companion := Ability.new()
	companion.tags = [&"companion"]
	_check("a generator 1, a companion's command 0", [t.get_respect_value(generator), t.get_respect_value(companion)], [1.0, 0.0])
	var slows := Ability.new()
	slows.tags = [&"core"]
	var bonus := ConditionalBonus.new()
	bonus.target_statuses = [STATUS_SLOW]
	slows.conditional_bonuses = [bonus]
	_check("a slow among its data's statuses: +1", t.get_respect_value(slows), 3.0)
	_check("no ability: 0", t.get_respect_value(null), 0.0)


func _test_snapshot() -> void:
	_section("The shared snapshot: kit ready, share, the ally's half")
	await _reset_knight()
	var snap := Brains.get_snapshot()
	var m := snap.get_member(knight)
	_check("the Knight is in it; companions never are (not Units)", [not m.is_empty(), snap.members.size()], [true, 1])
	knight.resource_pool.try_spend(knight.resource_pool.current)
	await _frames(1)
	m = Brains.get_snapshot().get_member(knight)
	_check("no Fury: Cleave can't be paid (the HUD's tint), so it isn't ready: 8.5 / 10.5",
		[snappedf(m.kit_ready, 0.0001), m.slots[&"q"].ready], [snappedf(8.5 / 10.5, 0.0001), false])
	knight.resource_pool.restore(1000.0)
	await _frames(1)
	m = Brains.get_snapshot().get_member(knight)
	_check("everything ready: kit 1, share 1 at full health", [m.kit_ready, m.share], [1.0, 1.0])
	knight.abilities.start_cooldown(&"e")
	knight.abilities.start_cooldown(&"r")
	knight.health.take_damage(knight.health.max_health * 0.5)
	await _frames(1)
	m = Brains.get_snapshot().get_member(knight)
	_check("Lunge and Judgement down: kit 3.5 / 10.5; at half health its share is 0.25 (the doc's example)",
		[snappedf(m.kit_ready, 0.0001), snappedf(m.share, 0.0001)], [snappedf(3.5 / 10.5, 0.0001), 0.25])
	_check("PartySnapshot.get_share(): kit × (0.5 + 0.5 × health)", [PartySnapshot.get_share(1.0, 0.0), PartySnapshot.get_share(0.6, 1.0)], [0.5, 0.6])
	var others: Array[float] = [0.6]
	_check("combine_respect(): the target's share + half the ally's, clamped", [PartySnapshot.combine_respect(0.4, others, 0.5),
		PartySnapshot.combine_respect(0.9, [1.0] as Array[float], 0.5), PartySnapshot.combine_respect(0.3, [] as Array[float], 0.5)], [0.7, 1.0, 0.3])
	var builds := Brains.get_snapshot_builds()
	var a := Brains.get_snapshot()
	var b := Brains.get_snapshot()
	_check("one read per tick: asked twice in one tick, built once", [a == b, Brains.get_snapshot_builds() - builds <= 1], [true, true])

	# The ally's half within 10 m, through a brain's situation: a friendly in
	# the group `party` with a kit (a passive slime elite: its slam, core 2).
	await _reset_knight()
	var brute := _spawn(BRUTE_SCENE, knight.global_position + Vector2(170, 0), false)   # aggroed: it has a target
	var friend := ELITE_SCENE.instantiate() as Enemy
	friend.data = null
	friend.passive = true
	entities.add_child(friend)
	_place(friend, knight.global_position + Vector2(170, 100))
	friend.add_to_group(&"party")
	await _frames(2)
	knight.abilities.start_cooldown(&"e")
	knight.abilities.start_cooldown(&"r")
	await _frames(1)
	var near := brute.get_brain().build_situation()
	_place(friend, knight.global_position + Vector2(170 + 400, 0))
	await _frames(1)
	var far := brute.get_brain().build_situation()
	var target_share := snappedf(3.5 / 10.5, 0.0001)
	_check("the ally (share 1) within 10 m adds half; beyond, nothing",
		[snappedf(near.respect, 0.0001), snappedf(far.respect, 0.0001)], [snappedf(3.5 / 10.5 + 0.5, 0.0001), target_share])
	friend.remove_from_group(&"party")
	brute.passive = true
	brute.queue_free()
	friend.queue_free()
	await _frames(2)


func _test_condition_respect() -> void:
	_section("The RESPECT condition kind and the situation argument")
	var s := SituationContext.new()
	s.respect = 0.6
	var at_least := Condition.new()
	at_least.kind = Condition.Kind.RESPECT
	at_least.value = 0.5
	var less := Condition.new()
	less.kind = Condition.Kind.RESPECT
	less.comparison = Condition.Comparison.LESS_THAN
	less.value = 0.5
	var negated := Condition.new()
	negated.kind = Condition.Kind.RESPECT
	negated.value = 0.9
	negated.negate = true
	_check("respect 0.6: ≥ 0.5 true, < 0.5 false, not ≥ 0.9 true",
		[at_least.is_met(knight, null, null, s), less.is_met(knight, null, null, s), negated.is_met(knight, null, null, s)], [true, false, true])
	_check("without a situation it's false, even negated (a cast condition, a reaction rule)",
		[at_least.is_met(knight, null), negated.is_met(knight, null)], [false, false])
	_check("a situation kind, not a target kind", [at_least.is_situation_kind(), at_least.is_target_kind()], [true, false])
	var health := Condition.new()
	health.kind = Condition.Kind.SELF_HEALTH_PERCENT
	health.value = 0.1
	_check("the old kinds ignore the situation", [health.is_met(knight, null, null, s), health.is_met(knight, null)], [true, true])
	var list: Array[Condition] = [health, at_least]
	_check("all_met() and first_failed() pass it on", [Condition.all_met(list, knight, null, null, s), Condition.all_met(list, knight, null),
		Condition.first_failed(list, knight, null) == at_least, Condition.first_failed(list, knight, null, null, s)], [true, false, true, null])
	var use := AIUse.make(&"poke", [less] as Array[Condition])
	s.respect = 0.3
	_check("an AIUse's rules see the situation", [use.passes(knight, null, s), AIUse.make(&"poke").passes(knight, null, null)], [true, true])


func _situation(respect: float, patience: float, intent: StringName = &"hold", intent_age: float = 1.0) -> SituationContext:
	var t := Brains.table
	var s := SituationContext.new()
	s.has_target = true
	s.respect = respect
	s.effective_respect = respect
	s.patience = patience
	s.intent = intent
	s.intent_age = intent_age
	s.target_edge_distance_px = Units.to_px(500.0)   # 5 m
	s.attack_reach_px = Units.to_px(125.0)
	s.min_intent_time = t.min_intent_time
	s.intent_hold_bonus = t.intent_hold_bonus
	s.intent_scores = t.intent_scores
	s.caster_poke_score = t.caster_poke_score
	return s


func _plan(slot: StringName, value: float = 1.0) -> CastPlan:
	var p := CastPlan.new()
	p.slot = slot
	p.value = value
	return p


func _regular_brute() -> EnemyBehavior:
	var adjusts: Array[BrainAdjust] = [Brains.table.get_rank_rules(EnemyData.Rank.REGULAR).brain_adjust]
	return BRUTE_BEHAVIOR.resolve({}, adjusts)


func _test_patience() -> void:
	_section("Patience: its fill, its floor, pressure")
	var t := Brains.table
	var b := BRUTE_BEHAVIOR
	var s := _situation(1.0, 0.0)
	_check("everything up (respect 1): a quarter speed, 1/12 a second: a brute comes in 12 s", EnemyBrain.get_patience_rate(s, b, t), 1.0 / 12.0)
	s.effective_respect = 0.0
	_check("nothing up: 1/3 a second (3 s)", EnemyBrain.get_patience_rate(s, b, t), 1.0 / 3.0)
	s.effective_respect = 1.0
	s.target_idle_time = 2.0
	_check("the target idle 1.5 s: × 1.5", EnemyBrain.get_patience_rate(s, b, t), 1.5 / 12.0)
	s.target_health_ratio = 0.3
	_check("and below 40%: × 2", EnemyBrain.get_patience_rate(s, b, t), 2.0 / 12.0)
	var eager: EnemyBehavior = b.duplicate()
	eager.aggression = 1.0
	s.target_idle_time = 0.0
	s.target_health_ratio = 1.0
	_check("aggression 1: × 1.5", EnemyBrain.get_patience_rate(s, eager, t), 1.5 / 12.0)
	var p := 0.0
	var steps := 0
	s = _situation(1.0, 0.0)
	while p < 1.0 - EnemyBrain.PATIENCE_EPSILON and steps < 1000:
		p = minf(p + EnemyBrain.get_patience_rate(s, b, t) * 0.1, 1.0)
		steps += 1
	_check("filled in 0.1 s steps with everything up: full after 12 s (its floor)", steps, 120)


func _test_decide() -> void:
	_section("decide(): hold, commit, poke")
	var b := _regular_brute()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var holds := 0
	var commits := 0
	for i in 2000:
		var d := EnemyBrain.decide(_situation(1.0, 0.2), b, rng)
		holds += int(d.intent == &"hold")
	for i in 2000:
		var d := EnemyBrain.decide(_situation(0.25, 1.0), b, rng)
		commits += int(d.intent == &"commit")
	_check("an ultimate ready at 5 m (respect 1, patience 0.2): hold, 2,000 times out of 2,000", holds, 2000)
	_check("spent (patience full): commit, 2,000 of 2,000", commits, 2000)
	var going := _situation(0.9, 0.0, &"commit")
	going.committing = true
	_check("a commit under way goes on (patience was emptied at its start)", EnemyBrain.decide(going, b, rng).intent, &"commit")
	var young := _situation(1.0, 1.0, &"hold", 0.1)
	var d2 := EnemyBrain.decide(young, b, rng)
	_check("the current intent scores +0.15 until 0.4 s (no flip-flopping)", d2.scores[&"hold"] >= 0.3 * (1.0 - b.jitter) + 0.15 - 0.0001, true)
	var poke := _situation(1.0, 0.0)
	poke.add_use(&"q", &"poke", _plan(&"q"))
	var d3 := EnemyBrain.decide(poke, b, rng)
	_check("a poke use: poke (0.5) over hold (0.3), with its plan", [d3.intent, d3.plan != null and d3.plan.slot == &"q"], [&"poke", true])
	var caster: EnemyBehavior = b.duplicate()
	caster.role = EnemyBehavior.Role.CASTER
	caster.jitter = 0.0
	_check("a caster's poke scores 0.6", EnemyBrain.decide(poke, caster, rng).scores[&"poke"], 0.6)
	var hits := _situation(0.0, 1.0)
	hits.add_use(&"q", &"damage", _plan(&"q", 0.5))
	hits.add_use(&"e", &"gap_close", _plan(&"e", 0.9))
	var d4 := EnemyBrain.decide(hits, b, rng)
	_check("a commit out of reach takes the best of its damage and gap-closer uses", [d4.intent, d4.plan.slot], [&"commit", &"e"])
	hits.target_edge_distance_px = 10.0
	var d5 := EnemyBrain.decide(hits, b, rng)
	_check("in reach: damage uses only", [d5.intent, d5.plan.slot], [&"commit", &"q"])
	_check("a new commit shows its tell pose (crouch); hold shows hold", [d5.pose, EnemyBrain.decide(_situation(1.0, 0.0), b, rng).pose], [&"crouch", &"hold"])
	var shy: EnemyBehavior = b.duplicate()
	shy.intent_weights = {&"commit": 0.0}
	_check("an intent weight of 0 never commits", EnemyBrain.decide(_situation(0.0, 1.0), shy, rng).intent, &"hold")
	var none := SituationContext.new()
	_check("no target: no intent", EnemyBrain.decide(none, b, rng).intent, &"")
	var unreachable := _situation(0.0, 1.0)
	unreachable.target_reachable = false
	_check("an unreachable target: no commit", EnemyBrain.decide(unreachable, b, rng).intent, &"hold")
	_check("the scores the overlay shows: the top three, best first", EnemyBrain.decide(poke, b, rng).get_top_scores(3).size(), 2)


func _test_decide_seeded() -> void:
	_section("The same seed gives the same decisions")
	var b := _regular_brute()
	var runs: Array = []
	for run in 2:
		var rng := RandomNumberGenerator.new()
		rng.seed = 424242
		var out: Array = []
		for i in 3000:
			var s := _situation(fmod(i * 0.137, 1.0), fmod(i * 0.071, 1.1), [&"hold", &"commit", &"poke"][i % 3], fmod(i * 0.05, 0.8))
			if i % 4 == 0:
				s.add_use(&"q", &"poke", _plan(&"q"))
			var d := EnemyBrain.decide(s, b, rng)
			out.append([d.intent, snappedf(float(d.scores.get(d.intent, 0.0)), 0.000001)])
		runs.append(out)
	_check("3,000 decisions, two runs, one seed: identical", runs[0] == runs[1], true)
	var other := RandomNumberGenerator.new()
	other.seed = 99
	var differs := false
	for i in 50:
		var d := EnemyBrain.decide(_situation(0.5, 0.5), b, other)
		differs = differs or snappedf(float(d.scores[&"hold"]), 0.000001) != runs[0][0][1]
	_check("another seed jitters differently", differs, true)


func _test_cast_plan() -> void:
	_section("The default get_ai_plan() and Ability.ai_uses")
	await _reset_knight()
	var brute := _spawn(BRUTE_SCENE, knight.global_position + Vector2(60, 0), true)
	await _frames(1)
	var s := SituationContext.new()
	s.target_unit = knight
	s.respect = 0.5
	var plan := SMASH.get_ai_plan(brute, s)
	_check("the smash (no ai_uses: one damage use): at the Knight where he stands, value 1",
		[plan != null, plan.point == knight.global_position if plan else false, plan.target == knight if plan else false, plan.intents if plan else [], plan.value if plan else 0.0, plan.is_vector() if plan else true],
		[true, true, true, [&"damage"], 1.0, false])
	_check("get_ai_uses(): the default damage use, no rules", [SMASH.get_ai_uses().size(), SMASH.get_ai_uses()[0].intent, SMASH.get_ai_uses()[0].conditions.size()], [1, &"damage", 0])
	_place(brute, knight.global_position + Vector2(Units.to_px(SMASH.cast_range) + 2.0, 0))
	_check("beyond its cast range (center to center): no plan", SMASH.get_ai_plan(brute, s), null)
	_place(brute, knight.global_position + Vector2(60, 0))
	var wall := _wall_at(knight.global_position + Vector2(30, 0), Vector2(6, 120))
	await _frames(2)
	_check("a wall between: no plan", SMASH.get_ai_plan(brute, s), null)
	wall.queue_free()
	await _frames(2)
	var vector := VECTOR_WALL.get_ai_plan(brute, s)
	var v := VECTOR_WALL.get_ai_vector(brute, knight)
	_check("a VECTOR ability wraps get_ai_vector()", [vector != null, vector.is_vector() if vector else false, vector.vector_start == v.start if vector else false], [true, true, true])
	var rule := Condition.new()
	rule.kind = Condition.Kind.RESPECT
	rule.comparison = Condition.Comparison.LESS_THAN
	rule.value = 0.3
	var picky: Ability = SMASH.duplicate()
	picky.ai_uses = [AIUse.make(&"punish", [rule] as Array[Condition], 2.0)]
	_check("its only use fails (respect 0.5, rule < 0.3): no plan", picky.get_ai_plan(brute, s), null)
	s.respect = 0.2
	var p2 := picky.get_ai_plan(brute, s)
	_check("it passes: the plan carries that use's intent", p2.intents if p2 else [], [&"punish"])
	var self_cast := IRON_RESOLVE.get_ai_plan(brute, s)
	_check("a SELF ability aims at its caster", self_cast.point == brute.global_position if self_cast else false, true)
	_check("no situation: no plan", SMASH.get_ai_plan(brute, null), null)
	brute.queue_free()
	await _frames(2)


func _test_enemies_on_data() -> void:
	_section("Enemies on data: brains by rank, tenacity, slots by difficulty tier, the brain switch")
	await _reset_knight()
	var slime := _spawn(SLIME_SCENE, knight.global_position + Vector2(0, 300), true)
	var elite := _spawn(ELITE_SCENE, knight.global_position + Vector2(0, -300), true)
	var brute := _spawn(BRUTE_SCENE, knight.global_position + Vector2(300, 300), true)
	var bare := ELITE_SCENE.instantiate() as Enemy
	bare.data = null
	bare.passive = true
	entities.add_child(bare)
	_place(bare, knight.global_position + Vector2(-300, 300))
	await _frames(1)
	_check("the slime (fodder): its data, no brain, today's numbers and look",
		[slime.data == SLIME_DATA, slime.get_brain(), slime.health.max_health, slime.model_color, slime.get_rank_rules().has_brain],
		[true, null, 280.0, Color(0.35, 0.85, 0.4, 1), false])
	_check("the elite slime: a brain, its slam on Q, 900 health, tenacity 0.2 under enemy_rank",
		[elite.get_brain() != null, elite.abilities.q == SLAM, elite.health.max_health, elite.stats_component.get_stat(&"tenacity")],
		[true, true, 900.0, 0.2])
	_check("the test brute: a brain, the smash, no tenacity, a regular's reaction (0.455)",
		[brute.get_brain() != null, brute.abilities.q == SMASH, brute.stats_component.get_stat(&"tenacity"), snappedf(brute.get_brain().behavior.reaction_time, 0.0001)],
		[true, true, 0.0, 0.455])
	_check("an enemy with no data: no brain, exactly as before", [bare.get_brain(), bare.abilities.q == SLAM, bare.health.max_health], [null, true, 900.0])
	_check("a training dummy's brain stays inactive", [elite.is_brain_active(), elite.get_pose(), elite.get_face_point()], [false, &"", Vector2.INF])
	_check("the brain is a UnitController child, not human", [elite.get_brain() is UnitController, elite.get_brain().get_unit() == elite, elite.get_brain().is_human()], [true, true, false])
	elite.set_brain_enabled(false)
	await _frames(1)
	_check("switched off: no brain (the old routine)", elite.get_brain(), null)
	elite.set_brain_enabled(true)
	_check("switched on again", elite.get_brain() != null, true)
	var off := BRUTE_SCENE.instantiate() as Enemy
	off.brain_enabled = false
	off.passive = true
	entities.add_child(off)
	_check("brain_enabled off from the start: none", off.get_brain(), null)

	# Slots by difficulty tier.
	var tiered: EnemyData = BRUTE_DATA.duplicate()
	var slot := EnemyAbilitySlot.new()
	slot.slot = &"w"
	slot.ability = VECTOR_WALL
	slot.min_difficulty_tier = 3
	tiered.abilities = [BRUTE_DATA.abilities[0], slot]
	var low := BRUTE_SCENE.instantiate() as Enemy
	low.data = tiered
	low.passive = true
	entities.add_child(low)
	Brains.difficulty_tier = 3
	var high := BRUTE_SCENE.instantiate() as Enemy
	high.data = tiered
	high.passive = true
	entities.add_child(high)
	Brains.difficulty_tier = 1
	_check("a slot with a minimum tier: empty below it, filled at it", [low.abilities.w, high.abilities.w == VECTOR_WALL, low.abilities.q == SMASH], [null, true, true])
	for e in [slime, elite, brute, bare, off, low, high]:
		e.queue_free()
	await _frames(2)


func _test_schedule() -> void:
	_section("The think schedule: staggered, urgent wakes, one snapshot per tick")
	await _reset_knight()
	var spawned: Array[Enemy] = []
	var ring := knight.global_position + Vector2(0, 1000)   # a ring of 12 around a spot the Knight walks to later
	for i in 12:
		spawned.append(_spawn(BRUTE_SCENE, ring + Vector2.from_angle(TAU * i / 12.0) * 170.0, true))
	await _frames(1)
	var counts: Array[int] = [0, 0, 0, 0, 0, 0]
	for e in spawned:
		counts[e.get_brain().think_slot] += 1
	_check("12 brains over 6 tick slots: 2 each", counts, [2, 2, 2, 2, 2, 2] as Array[int])
	var before: Array[int] = []
	for e in spawned:
		before.append(e.get_brain().think_calls)
	await _frames(6)
	var each_once := true
	for i in spawned.size():
		each_once = each_once and spawned[i].get_brain().think_calls - before[i] == 1
	_check("in 6 ticks each brain thinks exactly once", each_once, true)
	var b := spawned[0].get_brain()
	await _frames(1)
	var calls := b.think_calls
	Brains.wake(b)
	await _frames(1)
	_check("wake(): it thinks on the next tick, whatever its slot", b.think_calls - calls >= 1, true)
	knight.resource_pool.restore(1000.0)
	_place(knight, ring)
	for e in spawned:
		e.passive = false   # aggroed brains build situations (and ask for snapshots)
	await _frames(10)
	var active := 0
	for e in spawned:
		active += int(e.is_brain_active())
	_check("all 12 noticed the Knight in their middle", active, 12)
	var builds := Brains.get_snapshot_builds()
	Brains.reset_think_stats()
	await _frames(30)
	var stats := Brains.get_think_stats()
	_check("aggroed: at most one snapshot per tick for 12 brains", Brains.get_snapshot_builds() - builds <= 30, true)
	_check("about 10 thinks a second each: 12 brains × 30 ticks ÷ 6 = 60 (± wakes)", stats.count >= 60 and stats.count <= 72, true)
	print("  INFO  think cost (headless, 12 brutes): mean %.1f µs, p99 %d µs" % [stats.mean_usec, stats.p99_usec])
	for e in spawned:
		e.queue_free()
	await _frames(2)


func _test_naive_gate() -> void:
	_section("The naive cast loop: gated, and kept for an enemy with no brain")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	knight.resource_pool.restore(1000.0)
	var gated := ELITE_SCENE.instantiate() as Enemy
	gated.data = null
	gated.naive_casting = false
	entities.add_child(gated)
	_place(gated, knight.global_position + Vector2(70, 0))
	var slams := [0]
	gated.abilities.cast_started.connect(func(_s: StringName, _a: Ability, _c: CastContext) -> void: slams[0] += 1)
	await _frames(90)
	_check("naive_casting off: it chases and attacks but never casts", slams[0], 0)
	gated.queue_free()
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	knight.resource_pool.restore(1000.0)
	var brained := _spawn(ELITE_SCENE, knight.global_position + Vector2(70, 0), false)
	_pin_ai3(brained)   # an AI1 check: its crowded all-in (AI3b) would slam
	var brained_slams := [0]
	brained.abilities.cast_started.connect(func(_s: StringName, _a: Ability, _c: CastContext) -> void: brained_slams[0] += 1)
	await _frames(90)
	_check("with its brain and the Knight's kit up: no slam (the loop never runs; it holds, or backs up once: AI3b's crowded mix)",
		[brained_slams[0], brained.get_brain().get_intent() in [&"hold", &"retreat"]], [0, true])
	brained.set_brain_enabled(false)
	await _wait_until(func() -> bool: return brained.abilities.casting, 90)
	_check("its brain switched off: it slams as before (the naive loop)", brained.abilities.casting, true)
	brained.passive = true
	brained.attack.cancel()
	brained.queue_free()
	await _frames(60)


## The step's "Done means": the brute holds and circles at 350–500 u while the
## Knight's kit is up, crouches for its tell and dives once Lunge and
## Judgement are down.
func _test_brute_holds_then_commits() -> void:
	_section("The test brute: holds with the kit up, the tell, commits when it's down")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	knight.resource_pool.restore(1000.0)
	var hp := knight.health.current
	var brute := _spawn(BRUTE_SCENE, knight.global_position + Vector2(180, 0), false)
	_pin_ai3(brute)   # AI1's timings: no confidence (AI3b)
	var brain := brute.get_brain()
	var start := brute.global_position
	var band_ok := true
	var held := true
	var min_edge := INF
	for i in 180:
		await get_tree().physics_frame
		knight.resource_pool.restore(1000.0)
		if i > 30:
			var edge := Units.to_units(brute.edge_distance_to(knight))
			min_edge = minf(min_edge, edge)
			band_ok = band_ok and edge >= 330.0 and edge <= 520.0
			held = held and brain.get_intent() == &"hold"
	_check("aggroed with everything up: it holds for 3 s", [brute.ai, held], [Enemy.AI.AGGRO, true])
	_check("in its band (350–500 u, a little slack) the whole time", band_ok, true)
	_check("it circles (it moved) and faces the Knight", [brute.global_position.distance_to(start) > 20.0, brute.get_face_point() == knight.global_position], [true, true])
	_check("its pose is hold; no hit landed", [brute.get_pose(), knight.health.current], [&"hold", hp])
	var patience_before := brain.get_patience()
	_check("its patience filled slowly (respect 1: about a quarter speed)", patience_before > 0.15 and patience_before < 0.6, true)

	knight.abilities.start_cooldown(&"e")
	knight.abilities.start_cooldown(&"r")
	var crouch_at := -1
	var move_at := -1
	var crouch_pos := Vector2.ZERO
	var still := true
	for i in 480:
		await get_tree().physics_frame
		if brute.get_pose() == &"crouch" and crouch_at < 0:
			crouch_at = i
			crouch_pos = brute.global_position
		if crouch_at >= 0 and move_at < 0:
			if brute.get_pose() == &"crouch":
				still = still and brute.global_position.distance_to(crouch_pos) < 1.0
			else:
				move_at = i
		if move_at >= 0 and knight.health.current < hp:
			break
	_check("Lunge and Judgement down: it crouches (its tell) within 4 s", crouch_at >= 0 and crouch_at < 240, true)
	_check("the tell lasts 0.3 s (18 ticks ± 1), standing still", [absi((move_at - crouch_at) - 18) <= 1, still], [true, true])
	_check("then it commits and hits the Knight", [brain.get_intent() == &"commit" or not brain.is_committing(), knight.health.current < hp], [true, true])
	await _wait_until(func() -> bool: return not brain.is_committing(), 300)
	_check("its commit ends; patience empties", [brain.is_committing(), brain.get_patience() < 0.2], [false, true])
	brute.passive = true
	brute.attack.cancel()
	brute.queue_free()
	await _frames(60)


## "Its hold always ends within 12 s (4 × its 3 s patience_time)": everything
## up and no pressure (idle pressure off for this check).
func _test_hold_ends_within_12s() -> void:
	_section("A hold always ends within 12 s")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	var idle_time := Brains.table.idle_time
	Brains.table.idle_time = 1000.0
	knight.resource_pool.restore(1000.0)
	var brute := _spawn(BRUTE_SCENE, knight.global_position + Vector2(180, 0), false)
	_pin_ai3(brute)   # AI1's timings: no confidence (AI3b)
	var brain := brute.get_brain()
	var aggro_at := -1
	var commit_at := -1
	var min_edge := INF
	var max_edge := 0.0
	var hp := knight.health.current
	for i in 900:
		await get_tree().physics_frame
		knight.resource_pool.restore(1000.0)
		if aggro_at < 0 and brain.get_intent() != &"":
			aggro_at = i
		if brain.is_committing():
			commit_at = i
			break
		if aggro_at >= 0 and i - aggro_at > 30:
			var edge := Units.to_units(brute.edge_distance_to(knight))
			min_edge = minf(min_edge, edge)
			max_edge = maxf(max_edge, edge)
	var seconds := float(commit_at - aggro_at) / Engine.physics_ticks_per_second
	_check("it commits after about 12 s, never later (got %.2f s)" % seconds, commit_at > 0 and seconds <= 12.2 and seconds >= 11.5, true)
	_check("circling all that time, it stays in its band (no spiral in; got %d–%d u)" % [roundi(min_edge), roundi(max_edge)],
		[min_edge >= 330.0, max_edge <= 520.0, knight.health.current], [true, true, hp])
	Brains.table.idle_time = idle_time
	brute.passive = true
	brute.attack.cancel()
	brute.queue_free()
	await _frames(30)


func _test_scripted_controller() -> void:
	_section("ScriptedController: walk, wait, cast")
	await _reset_knight()
	knight.resource_pool.restore(1000.0)
	var c := ScriptedController.new()
	knight.add_child(c)
	var to := knight.global_position + Vector2(64, 0)
	var steps: Array[Dictionary] = [
		{"op": &"walk_to", "point": to},
		{"op": &"wait", "time": 0.2},
		{"op": &"cast", "slot": &"w", "point": to},
	]
	c.play(steps)
	_check("a UnitController, not human", [c is UnitController, c.is_human(), c.get_unit() == knight], [true, false, true])
	await _wait_until(func() -> bool: return c.get_step_index() >= 1, 90)
	_check("walk_to: it arrives", knight.global_position.distance_to(to) < 2.0, true)
	await _wait_until(func() -> bool: return c.is_done(), 60)
	_check("then waits and casts W (Iron Resolve on cooldown)", [c.is_done(), knight.abilities.is_ready(&"w")], [true, false])
	c.queue_free()
	await _frames(2)


func _test_sandbox_brains() -> void:
	_section("SandboxBrains: the overlay, the scenarios, the panel (no saving here)")
	await _reset_knight()
	var sb := SandboxBrains.new()
	add_child(sb)
	await _frames(2)
	var brute := sb.run_scenario(&"all_ready")
	await _frames(2)
	_check("all_ready: the test brute 5 m away, the Knight's kit and Fury full",
		[brute != null and brute.data == BRUTE_DATA, absf(brute.global_position.distance_to(knight.global_position) - 160.0) < 2.0,
			knight.abilities.is_ready(&"r"), knight.resource_pool.current > knight.resource_pool.max_resource - 5.0], [true, true, true, true])
	await _wait_until(func() -> bool: return brute.get_brain().get_intent() != &"", 30)
	var text := sb.get_overlay_text(brute)
	_check("the overlay's text: intent and pose, scores, respect, patience", [text.begins_with("hold · hold"), text.contains("respect"), text.contains("patience")], [true, true, true])
	sb.set_overlay(true)
	await _frames(2)
	_check("I: on and off", [sb.is_overlay_on(), Brains.debug_draw], [true, true])
	sb.set_overlay(false)
	brute = sb.run_scenario(&"none_ready")
	await _frames(1)
	var none_ready := true
	for slot in AbilityComponent.SLOTS:
		none_ready = none_ready and not knight.abilities.is_ready(slot)
	_check("none_ready: no slot ready, no Fury, the last scenario's brute gone", [none_ready, knight.resource_pool.current, sb.get_brained_enemies().size()], [true, 0.0, 1])
	sb.run_scenario(&"low_health")
	await _frames(1)
	_check("low_health: the Knight at 25%", snappedf(knight.health.current / knight.health.max_health, 0.01), 0.25)
	sb.run_scenario(&"ally")
	await _frames(1)
	var friends := get_tree().get_nodes_in_group(&"party")
	_check("ally: a friendly stand-in on the player's team in the group party", [friends.size(), (friends[0] as Unit).team if friends.size() > 0 else -1,
		(friends[0] as Node).is_in_group(&"enemies") if friends.size() > 0 else true], [1, Unit.Team.PLAYER, false])
	sb.run_scenario(&"whiff")
	await _frames(1)
	_check("whiff: Judgement spent, the rest ready", [knight.abilities.is_ready(&"r"), knight.abilities.is_ready(&"q")], [false, true])
	var casts: Array = []
	var on_cast := func(u: Unit, a: Ability, _c: CastContext) -> void: casts.append([u, a])
	Events.ability_cast.connect(on_cast)
	brute = sb.run_scenario(&"incoming_shot")
	await _wait_until(func() -> bool: return not casts.is_empty(), 60)   # (AI3: once it's fighting)
	Events.ability_cast.disconnect(on_cast)
	_check("incoming_shot: the Knight fires the test bolt at it (once it's aggroed)", casts.size() == 1 and casts[0][0] == knight and casts[0][1] == sb.test_bolt and brute.ai == Enemy.AI.AGGRO, true)
	_check("H cycles the eleven (AI2 added the two packs, AI3 the mixed one, AI3c the odds, AI-D1 escapes down)", [sb.next_scenario(), sb.next_scenario(), sb.next_scenario(), sb.next_scenario(), sb.next_scenario()], [&"pack", &"fodder", &"mixed", &"odds", &"escapes_down"])

	# The panel: a live change for every enemy sharing the data; no saving here.
	brute = sb.run_scenario(&"all_ready")
	var second := _spawn(BRUTE_SCENE, knight.global_position + Vector2(0, 240), true)
	await _frames(2)
	var original := BRUTE_DATA.overrides.duplicate()
	sb.set_panel(true)
	sb.pick(brute)
	sb.set_slider(&"patience_time", 6.0)
	_check("a slider change applies at once to it and to every enemy sharing its data",
		[brute.get_brain().behavior.patience_time, second.get_brain().behavior.patience_time, BRUTE_BEHAVIOR.patience_time], [6.0, 6.0, 3.0])
	_check("the panel shows its base value", sb.get_slider_base(brute, &"patience_time"), 6.0)
	_check("no saving in a test scene: nothing written", [sb.can_save(), sb.save_edits(false), sb.save_edits(true)], [false, ERR_UNAVAILABLE, ERR_UNAVAILABLE])
	sb.cycle_pick(1)
	_check(", and . cycle the picked enemy", sb.get_picked() == second, true)
	BRUTE_DATA.set(&"overrides", original)
	brute.get_brain().resolve_behavior()
	second.get_brain().resolve_behavior()
	_check("(the test puts the data back)", brute.get_brain().behavior.patience_time, 3.0)
	sb.set_panel(false)
	sb.clear_scenario()
	second.queue_free()
	sb.queue_free()
	await _frames(2)


# --- AI2: groups ----------------------------------------------------------------------------

func _test_ai2_data() -> void:
	_section("AI2 data: tokens, the fodder ring, the pick, the alert, the leash; the threat stat")
	var t := Brains.table
	_check("tokens per champion by tier 1–5: 2, 2, 2, 3, 3 (I3), clamped past 5",
		[t.tokens_per_target, t.get_tokens_per_target(1), t.get_tokens_per_target(4), t.get_tokens_per_target(9)],
		[[2, 2, 2, 3, 3] as Array[int], 2, 3, 3])
	_check("a holder keeps its token at most 4 s, then rests 1.5 s (I3)", [t.token_hold_time, t.token_rest_time], [4.0, 1.5])
	_check("fodder: 5 pack thinks a second, 19 px (0.6 m) apart in the ring (I6), at half its reach",
		[t.pack_think_rate, t.fodder_ring_spacing_px, t.fodder_ring_reach_share], [5.0, 19.0, 0.5])
	_check("the pick: 25% and 1.5 m closer, held 0.5 s (ALLIES)", [t.switch_ratio, t.switch_px, Units.px_to_m(t.switch_px), t.switch_hold_time], [0.25, 48.0, 1.5, 0.5])
	_check("the shout: 6 m, 0.4 s (I5); the alert pose 0.4 s, with a sound",
		[Units.px_to_m(t.alert_radius_px), t.alert_delay, t.alert_pose_time, t.alert_sound != null], [6.0, 0.4, 0.4, true])
	_check("the leash: 12 m from home or 6 s out of reach; home 30% faster, ignoring aggro 2 s, healed over 1.5 s (I5)",
		[Units.px_to_m(t.leash_px), t.leash_out_of_reach_time, t.return_speed_ratio, t.return_ignore_time, t.recover_time], [12.0, 6.0, 1.3, 2.0, 1.5])
	var def := knight.stats_component.registry.get_definition(&"threat")
	_check("the threat stat (ALLIES' name, approved 2026-10-04): default 1, limits 0.1–10; the Knight's is 1",
		[def != null, def.default_value if def else 0.0, def.min_value if def else 0.0, def.max_value if def else 0.0, knight.stats_component.get_stat(&"threat")],
		[true, 1.0, 0.1, 10.0, 1.0])
	_check("the margin (Enemy.is_better_target()): 25% shorter and 48 px shorter, both",
		[Enemy.is_better_target(200.0, 100.0, t), Enemy.is_better_target(200.0, 151.0, t), Enemy.is_better_target(80.0, 50.0, t), Enemy.is_better_target(300.0, 225.0, t)],
		[true, false, false, true])


func _test_ring_spots() -> void:
	_section("The fodder ring (Pack.get_ring_spots()): side by side 0.6 m apart, never stacked (I6)")
	var c := Vector2(100, 100)
	var r := 50.0
	var gap := 2.0 * 10.0 + 19.0   # two members of radius 10, 19 px apart: 39 px center to center
	var three: Array[Vector2] = [c + Vector2.from_angle(0.3) * 200.0, c + Vector2.from_angle(-0.2) * 180.0, c + Vector2.from_angle(0.05) * 220.0]
	var spots := Pack.get_ring_spots(c, three, r, 10.0, 19.0)
	var on_ring := spots.size() == 3
	for s in spots:
		on_ring = on_ring and absf(s.distance_to(c) - r) < 0.01
	_check("three fodder: a place each on the ring", on_ring, true)
	var apart := INF
	for i in 3:
		for j in range(i + 1, 3):
			apart = minf(apart, spots[i].distance_to(spots[j]))
	_check("seven places fit (neighbors ≥ 39 px: 0.6 m edge to edge), spread evenly: 43.4 px apart; theirs differ (got %.2f)" % apart,
		snappedf(apart, 0.01) >= snappedf(2.0 * r * sin(PI / 7.0), 0.01), true)
	_check("the ring's angle is the nearest's (no anchor given): its place is straight in toward the center",
		absf(wrapf((spots[0] - c).angle() - 0.3, -PI, PI)) < 0.0001, true)
	_check("at its place, each keeps it (arrived, nothing changes)", Pack.get_ring_spots(c, spots, r, 10.0, 19.0, 0.3) == spots, true)
	var moved: Array[Vector2] = []
	for s in spots:
		moved.append(s + Vector2(30, -20))
	var shifted := Pack.get_ring_spots(c + Vector2(30, -20), moved, r, 10.0, 19.0, 0.3)
	_check("the target steps aside: the places move with it, without turning",
		shifted[0].is_equal_approx(spots[0] + Vector2(30, -20)) and shifted[1].is_equal_approx(spots[1] + Vector2(30, -20)) and shifted[2].is_equal_approx(spots[2] + Vector2(30, -20)), true)
	var ten: Array[Vector2] = []
	for i in 10:
		ten.append(c + Vector2.from_angle(i * 0.1) * (100.0 + i * 10.0))   # nearest first
	var many := Pack.get_ring_spots(c, ten, r, 10.0, 19.0)
	var inner := 0
	var outer := 0
	var first_seven := true
	for i in 10:
		var d := many[i].distance_to(c)
		if absf(d - r) < 0.01:
			inner += 1
			first_seven = first_seven and i < 7
		elif absf(d - (r + gap)) < 0.01:
			outer += 1
	_check("ten: the seven nearest fill the first ring (as many as fit), the rest the next ring out", [inner, outer, first_seven], [7, 3, true])
	var min_d := INF
	for i in 10:
		for j in range(i + 1, 10):
			min_d = minf(min_d, many[i].distance_to(many[j]))
	_check("no two closer than 39 px (got %.2f)" % min_d, min_d >= gap - 0.01, true)
	var seven: Array[Vector2] = []
	for i in 7:
		seven.append(ten[i])
	var full := Pack.get_ring_spots(c, seven, r, 10.0, 19.0)
	var even := true
	var step := full[0].distance_to(full[1])
	for i in 7:
		var nearest := INF
		for j in 7:
			if i != j:
				nearest = minf(nearest, full[i].distance_to(full[j]))
		even = even and absf(nearest - step) < 0.01
	_check("a full ring spreads evenly", [even, step >= gap], [true, true])


func _test_decide_tokens() -> void:
	_section("decide() with tokens: none held, no commit; held, commit; out of reach, never; a taunt commits")
	var b := _regular_brute()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var s := _situation(0.0, 1.0)
	s.needs_token = true
	_check("patience full but no token: it holds (first in the queue)", EnemyBrain.decide(s, b, rng).intent, &"hold")
	s.has_token = true
	_check("with its token: it commits", EnemyBrain.decide(s, b, rng).intent, &"commit")
	s.target_reachable = false
	_check("out of reach: never commits, token or not", EnemyBrain.decide(s, b, rng).intent, &"hold")
	var taunt := _situation(1.0, 0.0)
	taunt.needs_token = true
	taunt.taunted = true
	_check("taunted, patience empty, no token: it commits on its taunter", EnemyBrain.decide(taunt, b, rng).intent, &"commit")
	_check("a hand-built situation needs no token (AI1's checks hold)", EnemyBrain.decide(_situation(0.0, 1.0), b, rng).intent, &"commit")


func _test_tokens() -> void:
	_section("Attack tokens: a pool per champion, costs by rank, the queue, the rest, releases (I3)")
	await _reset_knight()
	var base := knight.global_position
	var brutes: Array[Enemy] = []
	for i in 5:
		brutes.append(_spawn(BRUTE_SCENE, base + Vector2(200 + i * 60, 600), true))   # passive: they never notice
	var elite := _spawn(ELITE_SCENE, base + Vector2(0, 700), true)
	var slime := _spawn(SLIME_SCENE, base + Vector2(-200, 700), true)
	await _frames(1)
	var a := brutes[0]
	var b := brutes[1]
	var c := brutes[2]
	var d := brutes[3]
	var e := brutes[4]
	_check("costs: a regular 1, an elite 2, fodder none (I3)", [Brains.get_token_cost(a), Brains.get_token_cost(elite), Brains.get_token_cost(slime)], [1, 2, 0])
	_check("tier 1: a pool of 2 on the Knight", [Brains.get_tokens_per_target(), Brains.get_tokens_free(knight)], [2, 2])
	_check("two ask and get one each; the third waits", [Brains.request_token(a, knight), Brains.request_token(b, knight), Brains.request_token(c, knight)], [true, true, false])
	_check("the holders, none free, the third in the queue",
		[Brains.get_token_holders(knight) == ([a, b] as Array[Enemy]), Brains.get_tokens_free(knight), Brains.is_waiting_for_token(c), Brains.request_token(a, knight)], [true, 0, true, true])
	Brains.release_token(a)
	_check("a commit ends: its token frees and it rests 1.5 s",
		[Brains.get_tokens_free(knight), Brains.has_token(a), snappedf(Brains.get_token_rest_left(a), 0.01), Brains.request_token(a, knight)], [1, false, 1.5, false])
	_check("the one waiting gets it", Brains.request_token(c, knight), true)
	_check("full again: d and e wait", [Brains.request_token(d, knight), Brains.request_token(e, knight)], [false, false])
	Brains.release_token(b, false)
	_check("a token frees: e asks first, but d (as patient, nearer) is ahead of it", [Brains.request_token(e, knight), Brains.request_token(d, knight)], [false, true])
	_check("full: b (patience 0.9, nearer) and e (1.0) wait", [Brains.request_token(b, knight, 0.9), Brains.request_token(e, knight, 1.0)], [false, false])
	Brains.release_token(c, false)
	_check("a token frees: the most patient first, whoever is nearer", [Brains.request_token(b, knight, 0.9), Brains.request_token(e, knight, 1.0)], [false, true])
	Brains.difficulty_tier = 4
	_check("tier 4: 3 per champion (one free with two held)", [Brains.get_tokens_per_target(), Brains.get_tokens_free(knight)], [3, 1])
	Brains.difficulty_tier = 1
	Brains.release_token(d, false)
	Brains.release_token(e, false)
	_check("an elite takes 2: the whole pool at tier 1", [Brains.request_token(elite, knight), Brains.get_tokens_free(knight)], [true, 0])
	_check("fodder needs none: it asks and holds nothing", [Brains.request_token(slime, knight), Brains.has_token(slime), Brains.get_tokens_free(knight)], [true, false, 0])
	Brains.release_token(elite, false)
	var hold := Brains.table.token_hold_time
	Brains.table.token_hold_time = 0.25
	Brains.request_token(b, knight)
	await _frames(20)
	_check("held past token_hold_time: Brains takes it back and it rests", [Brains.has_token(b), Brains.get_token_rest_left(b) > 1.0], [false, true])
	Brains.table.token_hold_time = hold
	await _wait_until(func() -> bool: return Brains.get_token_rest_left(b) <= 0.0, 120)
	_check("its rest over, it may ask again", Brains.request_token(b, knight), true)
	b.apply_stun(0.5)
	await _frames(1)
	_check("a holder stunned: its token frees the next tick, and it rests", [Brains.has_token(b), Brains.get_token_rest_left(b) > 1.0], [false, true])
	Brains.request_token(c, knight)
	c.health.take_damage(100000.0)
	_check("a holder dies: its token frees the same tick", [c.is_alive(), Brains.has_token(c), Brains.get_tokens_free(knight)], [false, false, 2])
	var dummy := _friend(base + Vector2(0, -600))
	await _frames(1)
	_check("another champion has its own pool", [Brains.request_token(d, dummy), Brains.get_tokens_free(dummy), Brains.get_tokens_free(knight)], [true, 1, 2])
	dummy.health.take_damage(100000.0)
	await _frames(1)
	_check("its target dies: its pool empties", [Brains.has_token(d), Brains.get_token_holders(dummy).size()], [false, 0])
	for x in [a, b, c, d, e, elite, slime, dummy]:
		if is_instance_valid(x):
			x.queue_free()
	await _frames(2)


func _test_sight() -> void:
	_section("Noticing (AI2): any party member in sight within 450 u, through WorldQuery")
	await _reset_knight()
	var spot := knight.global_position + Vector2(0, -1500)
	var slime := _spawn(SLIME_SCENE, spot, false)
	var wall := _wall_at(spot + Vector2(-60, 0), Vector2(8, 200))
	await _frames(3)
	_place(knight, spot + Vector2(-130, 0))   # 91.6 px edge to edge: in range, behind the wall
	await _frames(20)
	_check("a wall between them: it doesn't notice", slime.ai != Enemy.AI.AGGRO, true)
	wall.queue_free()
	await _frames(5)
	_check("the wall gone: it notices and picks him", [slime.ai, slime.get_target() == knight], [Enemy.AI.AGGRO, true])
	slime.passive = true
	slime.attack.cancel()
	await _reset_knight()
	var other := _spawn(SLIME_SCENE, knight.global_position + Vector2(0, 1500), false)
	await _frames(3)
	var dummy := _friend(other.global_position + Vector2(100, 0))
	await _frames(5)
	_check("any party member: a friendly dummy (team PLAYER, group party) is noticed", [other.ai, other.get_target() == dummy], [Enemy.AI.AGGRO, true])
	for x in [slime, other, dummy]:
		x.queue_free()
	await _frames(2)


## The step's "Done means": one pack member noticing wakes its pack 0.4 s
## later; packmates wake through walls, other packs only with the shouter in
## sight within 6 m; nobody they wake shouts on.
func _test_pack_alert() -> void:
	_section("The shout: the pack wakes 0.4 s after one member notices (I5)")
	await _reset_knight()
	var q := knight.global_position + Vector2(0, 1200)
	var pack := Pack.new()
	pack.name = "TestPack"
	var a := SLIME_SCENE.instantiate() as Enemy
	var b := SLIME_SCENE.instantiate() as Enemy
	var c := SLIME_SCENE.instantiate() as Enemy
	b.position = Vector2(40, 0)
	c.position = Vector2(60, 60)
	pack.add_child(a)
	pack.add_child(b)
	pack.add_child(c)
	entities.add_child(pack)
	_place(pack, q)
	var wall := _wall_at(q + Vector2(40, 32), Vector2(220, 6))   # c behind it: no sight of a, b or the Knight
	var near := _spawn(SLIME_SCENE, q + Vector2(150, -40), false)    # another pack: 6 m of a, in sight
	var walled := _spawn(SLIME_SCENE, q + Vector2(100, 100), false)  # within 6 m of a, behind the wall
	var far := _spawn(SLIME_SCENE, q + Vector2(0, -260), false)      # in sight, past 6 m
	var alerted: Array = []
	var on_alert := func(p: Node, t: Unit) -> void: alerted.append([p, t])
	Events.pack_alerted.connect(on_alert)
	await _frames(3)
	_check("its members and its home", [pack.get_members().size(), a.get_pack() == pack, c.get_pack() == pack, pack.get_home().distance_to(q) < 0.5, near.get_pack() != pack], [3, true, true, true, true])
	_place(knight, q + Vector2(-150, 0))   # only a (111.6 px) notices him
	var woke := {}
	var tick := 0
	var alert_pose := false
	while tick < 60:
		await get_tree().physics_frame
		tick += 1
		for x in [a, b, c, near, walled, far]:
			if not woke.has(x) and x.ai == Enemy.AI.AGGRO:
				woke[x] = tick
				if x == b:
					alert_pose = b.get_pose() == &"alert"
	Events.pack_alerted.disconnect(on_alert)
	var t0: int = woke.get(a, -1)
	var lag := func(x: Enemy) -> int: return woke.get(x, 1000) - t0
	_check("a notices him; it shows its alert pose", [t0 > 0, a.get_known().has(knight)], [true, true])
	_check("its packmates wake 0.4 s later (24 ticks ± 1)", [absi(lag.call(b) - 24) <= 1, absi(lag.call(c) - 24) <= 1], [true, true])
	_check("c woke behind the wall (packmates know), in its alert pose", [woke.has(c), alert_pose], [true, true])
	_check("another pack within 6 m with a in sight wakes with them", absi(lag.call(near) - 24) <= 1, true)
	_check("one within 6 m behind a wall, and one past 6 m, stay asleep (no chain)", [woke.has(walled), woke.has(far)], [false, false])
	_check("Events.pack_alerted: a's pack and the other, on the Knight",
		[alerted.size(), alerted.size() > 0 and alerted[0][0] == pack and alerted[0][1] == knight, alerted.size() > 1 and alerted[1][0] == near.get_pack()], [2, true, true])
	for x in [a, b, c, near, walled, far]:
		x.passive = true
		x.attack.cancel()
	pack.queue_free()
	for x in [near, walled, far]:
		x.queue_free()
	wall.queue_free()
	await _frames(2)


## ALLIES' target pick against a second PLAYER-team dummy: the nearest,
## sticky with the margin, threat, stealth, taunt, downed, and an untargetable
## target chased (AB10).
func _test_target_pick() -> void:
	_section("The target pick (ALLIES): nearest by threat, sticky with the margin, taunt, stealth, downed")
	await _reset_knight()
	var p := knight.global_position + Vector2(-1500, 0)
	var e := _spawn(SLIME_SCENE, p, false)
	e.status_component.apply_status(_tag_status(&"test_root", [&"cc", &"root"] as Array[StringName], true))   # it stays put
	var dummy := _friend(p + Vector2(0, 70))        # 34.8 px edge to edge
	_place(knight, p + Vector2(-150, 0))             # 111.6 px
	await _frames(4)
	_check("it notices both and picks the nearest (the dummy)", [e.ai, e.get_target() == dummy, e.get_known().has(knight)], [Enemy.AI.AGGRO, true, true])
	_place(dummy, p + Vector2(0, 175))               # 139.8 px: the Knight is nearer, not by the margin
	await _frames(45)
	_check("sticky: the Knight a little nearer (111.6 vs 139.8 px) changes nothing", e.get_target() == dummy, true)
	_place(knight, p + Vector2(-120, 0))             # 81.6 px: 25% and 48 px nearer
	await _frames(24)
	var early := e.get_target() == dummy
	await _frames(24)
	_check("past the margin it switches, after 0.5 s (not at 0.4 s)", [early, e.get_target() == knight], [true, true])
	var threat := StatModifier.create(&"threat", StatModifier.Type.FLAT, 4.0, &"test_threat")
	dummy.stats_component.add_modifier(threat)
	await _frames(48)
	_check("threat 5: the dummy at 139.8 px counts as 28 px, and draws it",
		[snappedf(e.get_effective_distance(dummy), 0.1), e.get_target() == dummy], [snappedf((175.0 - 35.2) / 5.0, 0.1), true])
	dummy.stats_component.remove_modifiers_from(&"test_threat")
	var stealth := _tag_status(&"test_stealth", [&"stealth", &"buff"] as Array[StringName])
	dummy.status_component.apply_status(stealth)
	await _frames(2)
	_check("its target stealthed: dropped at its next pick", e.get_target() == knight, true)
	_place(dummy, p + Vector2(0, 60))
	await _frames(45)
	_check("a stealthed dummy right beside it is never picked", e.get_target() == knight, true)
	dummy.status_component.remove_status(stealth.id)
	_place(dummy, p + Vector2(0, 175))
	await _frames(2)
	var taunt := _tag_status(&"test_taunt", [&"cc", &"taunt", &"debuff"] as Array[StringName])
	e.status_component.apply_status(taunt, dummy)
	await _frames(7)
	_check("taunted by the farther dummy: its target at once (the taunt wins)", [e.get_taunter() == dummy, e.get_target() == dummy], [true, true])
	e.status_component.remove_status(taunt.id)
	await _frames(48)
	_check("the taunt over: back to the rules (the Knight is past the margin again)", e.get_target() == knight, true)
	var downed := _tag_status(&"test_downed", [&"downed"] as Array[StringName])
	knight.status_component.apply_status(downed)
	await _frames(2)
	_check("its target downed: dropped at once, the other picked", e.get_target() == dummy, true)
	knight.status_component.remove_status(downed.id)
	dummy.queue_free()
	await _frames(8)
	_check("the dummy gone: the Knight again", e.get_target() == knight, true)
	var untargetable := _tag_status(&"test_untargetable", [&"untargetable"] as Array[StringName])
	knight.status_component.apply_status(untargetable)
	await _frames(10)
	_check("its only target untargetable: kept and chased, not attacked (AB10)", [e.get_target() == knight, e.attack.target], [true, null])
	knight.status_component.remove_status(untargetable.id)
	e.passive = true
	e.attack.cancel()
	e.queue_free()
	await _frames(2)


## The step's "Done means": walking 12 m away sends the pack home to heal.
func _test_leash() -> void:
	_section("The leash: 12 m from home or 6 s out of reach; home 30% faster, healed over 1.5 s (I5)")
	await _reset_knight()
	var home := knight.global_position + Vector2(0, -900)
	var pack := Pack.new()
	pack.name = "LeashPack"
	var s1 := SLIME_SCENE.instantiate() as Enemy
	var s2 := SLIME_SCENE.instantiate() as Enemy
	s2.position = Vector2(40, 0)
	pack.add_child(s1)
	pack.add_child(s2)
	entities.add_child(pack)
	_place(pack, home)
	await _frames(3)
	var s1_home := s1.get_home()
	_place(knight, home + Vector2(-140, 0))
	await _wait_until(func() -> bool: return s1.ai == Enemy.AI.AGGRO and s2.ai == Enemy.AI.AGGRO, 90)
	_check("they notice him and fight; the pack's home is where it was placed",
		[s1.ai, s2.ai, pack.is_fighting(), pack.get_home().distance_to(home) < 0.5, s1_home.distance_to(home) < 0.5], [Enemy.AI.AGGRO, Enemy.AI.AGGRO, true, true, true])
	s1.health.take_damage(150.0)
	var mark := _tag_status(&"test_mark", [&"debuff"] as Array[StringName])
	s1.status_component.apply_status(mark, knight)
	_place(knight, home + Vector2(-352, 0))   # 11 m from home
	await _wait_until(func() -> bool: return s1.global_position.distance_to(home) > 250.0 and s2.global_position.distance_to(home) > 250.0, 480)
	_check("at 11 m from home they keep after him", [s1.ai, s2.ai, s2.global_position.distance_to(home) > 250.0], [Enemy.AI.AGGRO, Enemy.AI.AGGRO, true])
	_place(knight, home + Vector2(-420, 0))   # 13 m: out of the leash
	await _wait_until(func() -> bool: return s1.ai == Enemy.AI.RETURN, 10)
	var mods := s1.stats_component.get_modifiers_from(Enemy.RETURN_SOURCE_ID)
	_check("past 12 m the pack gives up at once and walks home", [s1.ai, s2.ai], [Enemy.AI.RETURN, Enemy.AI.RETURN])
	_check("30% faster, in its return pose, no target", [mods.size(), snappedf(mods[0].value, 0.0001) if mods.size() > 0 else 0.0, s1.get_pose(), s1.get_target()], [1, 0.3, &"return", null])
	s1.take_damage(1.0, knight)
	await _frames(1)
	_check("a hit from outside the leash doesn't turn it around", s1.ai, Enemy.AI.RETURN)
	_place(knight, s2.global_position + (home - s2.global_position).normalized() * 100.0)   # inside the leash, in its sight
	await _frames(20)
	_check("for 2 s it ignores what it sees on the way", s2.ai, Enemy.AI.RETURN)
	_place(knight, home + Vector2(-700, 0))
	await _wait_until(func() -> bool: return s1.is_recovering(), 480)
	_check("home: the status the Knight put on it is gone; it heals", [s1.is_recovering(), s1.status_component.has_status(mark.id), s1.global_position.distance_to(s1_home) < 45.0], [true, false, true])
	var hp0 := s1.health.current
	await _frames(45)
	var hp_mid := s1.health.current
	await _wait_until(func() -> bool: return s1.ai == Enemy.AI.IDLE, 90)
	_check("to full over about 1.5 s (part way at 0.75 s: %d → %d), then it idles at home" % [roundi(hp0), roundi(hp_mid)],
		[hp_mid > hp0 + 30.0 and hp_mid < s1.health.max_health - 20.0, s1.health.current, s1.ai, s1.stats_component.get_modifiers_from(Enemy.RETURN_SOURCE_ID).size()],
		[true, s1.health.max_health, Enemy.AI.IDLE, 0])
	await _wait_until(func() -> bool: return s2.ai == Enemy.AI.IDLE, 120)

	# No target in reach for 6 s (here the Knight stealthed, inside the leash).
	var lone := _spawn(SLIME_SCENE, home + Vector2(600, 0), false)
	await _frames(3)
	_place(knight, lone.global_position + Vector2(-130, 0))
	await _wait_until(func() -> bool: return lone.ai == Enemy.AI.AGGRO, 30)
	var stealth := _tag_status(&"test_stealth", [&"stealth", &"buff"] as Array[StringName])
	knight.status_component.apply_status(stealth)
	var t0 := Brains.get_time()
	await _wait_until(func() -> bool: return lone.ai == Enemy.AI.RETURN, 480)
	var waited := Brains.get_time() - t0
	_check("nothing it can reach for 6 s: home (got %.2f s)" % waited, [lone.ai, waited >= 5.85 and waited <= 6.3], [Enemy.AI.RETURN, true])
	knight.status_component.remove_status(stealth.id)
	for x in [s1, s2, lone]:
		x.passive = true
		x.attack.cancel()
	pack.queue_free()
	lone.queue_free()
	await _frames(2)


## Found building AI2: sight never wakes an enemy on a champion it has no path
## to (a perch with no way up); a hit does, the leash sends it home after 6 s,
## and it doesn't wake again by sight (no wake, leash, wake loop).
func _test_unreachable() -> void:
	_section("A champion it can't reach: not noticed by sight; a hit wakes it, 6 s later it goes home and stays")
	await _reset_knight()
	var edge := ARENA + Vector2(2500, 0)   # the navigation's east edge
	var slime := _spawn(SLIME_SCENE, edge + Vector2(-50, 0), false)
	await _frames(3)
	_place(knight, edge + Vector2(100, 0))   # 111.6 px away, in sight, 100 px off the walkable floor
	await _frames(30)
	_check("in sight within 450 u but unreachable: it doesn't wake", slime.ai != Enemy.AI.AGGRO, true)
	slime.take_damage(1.0, knight)
	await _frames(2)
	_check("a hit wakes it; its target is out of reach", [slime.ai, slime.get_target() == knight, slime.is_target_reachable()], [Enemy.AI.AGGRO, true, false])
	await _wait_until(func() -> bool: return slime.ai == Enemy.AI.RETURN, 420)
	_check("6 s with nothing in reach: home", slime.ai, Enemy.AI.RETURN)
	await _wait_until(func() -> bool: return slime.ai == Enemy.AI.IDLE, 300)
	await _frames(150)
	_check("home and healed, it doesn't wake again on what it can't reach", [slime.ai != Enemy.AI.AGGRO, slime.health.current, slime.get_target()], [true, slime.health.max_health, null])
	slime.passive = true
	slime.queue_free()
	await _frames(2)


## The step's "Done means": a stunned holder frees its token at once.
func _test_stunned_holder() -> void:
	_section("A stunned holder frees its token at once, keeps its patience, and asks again after its rest")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	_spend_kit()
	var brute := _spawn(BRUTE_SCENE, knight.global_position + Vector2(170, 0), false)
	var brain := brute.get_brain()
	await _wait_until(func() -> bool: return Brains.has_token(brute), 400)
	_check("its patience full, it asks, gets its token and commits", [Brains.has_token(brute), brain.is_committing(), brain.get_token_state()], [true, true, "held"])
	brute.apply_stun(1.0)
	await _frames(2)
	_check("stunned: no token, its commit broken off, its patience kept, resting",
		[Brains.has_token(brute), brain.is_committing(), brain.get_patience() > 0.99, Brains.get_token_rest_left(brute) > 1.0, brain.get_token_state()], [false, false, true, true, "rest"])
	await _wait_until(func() -> bool: return Brains.has_token(brute), 300)
	_check("after the stun and its rest it asks again and gets it", Brains.has_token(brute), true)
	brute.passive = true
	brute.attack.cancel()
	brute.queue_free()
	await _frames(30)


## The step's "Done means": five test brutes never put more than two on the
## Knight at tier 1, and they rotate.
func _test_five_brutes() -> void:
	_section("Five test brutes at tier 1: never more than two on the Knight at once, and they rotate")
	_no_press()   # AI2's rule; five brutes press since AI3c (their own test)
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	_spend_kit()
	# The Knight unstoppable, so their hits don't push him about (AB10): since
	# AI3d's kits (the charge, the cleave arc) five brutes' pushes could carry
	# him out of a brute's leash in 15 s, and the leash isn't under test here.
	var steady := _tag_status(&"test_unstoppable", [&"unstoppable"] as Array[StringName])
	knight.status_component.apply_status(steady)
	var brutes: Array[Enemy] = []
	for i in 5:
		brutes.append(_spawn(BRUTE_SCENE, knight.global_position + Vector2.from_angle(TAU * i / 5.0) * 150.0, false))
	var max_holders := 0
	var max_committing := 0
	var stray := 0
	var streak := 0
	var holders_seen := {}
	var hits := [0]
	var on_damaged := func(ctx: HitContext) -> void:
		if ctx.target == knight:
			hits[0] += 1
	Events.unit_damaged.connect(on_damaged)
	var start := Brains.get_time()
	var frames := 0
	while Brains.get_time() - start < 15.0 and frames < 1800:
		await get_tree().physics_frame
		frames += 1
		knight.health.heal(100000.0)
		if frames % 30 == 0:
			_spend_kit()
		var holders := Brains.get_token_holders(knight)
		max_holders = maxi(max_holders, holders.size())
		for h in holders:
			holders_seen[h] = true
		var committing := 0
		var bad := false
		for b in brutes:
			if b.get_brain().is_committing():
				committing += 1
				bad = bad or not Brains.has_token(b)
		max_committing = maxi(max_committing, committing)
		streak = streak + 1 if bad else 0
		if streak > 1:
			stray += 1
	Events.unit_damaged.disconnect(on_damaged)
	knight.status_component.remove_status(steady.id)
	_check("all five aggroed on him", brutes.all(func(b: Enemy) -> bool: return b.ai == Enemy.AI.AGGRO and b.get_target() == knight), true)
	_check("never more than two tokens held, never more than two committing (15 s; got %d / %d)" % [max_holders, max_committing],
		[max_holders, max_committing <= 2], [2, true])
	_check("no commit without its token (beyond a tick's hand-over)", stray, 0)
	_check("they rotate: at least four of the five held a token (got %d); they hit him" % holders_seen.size(), [holders_seen.size() >= 4, hits[0] > 0], [true, true])
	for b in brutes:
		b.passive = true
		b.attack.cancel()
		b.queue_free()
	await _frames(60)
	_restore_press()


## The step's "Done means": fodder surrounds the Knight, with no tokens.
func _test_fodder_ring() -> void:
	_section("Fodder surrounds its target in a ring, 0.6 m apart, with no tokens (I6)")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	# First the ring itself: the Knight unstoppable, so their hits don't push
	# him about (AB10).
	var steady := _tag_status(&"test_unstoppable", [&"unstoppable"] as Array[StringName])
	knight.status_component.apply_status(steady)
	var slimes: Array[Enemy] = []
	for i in 6:
		slimes.append(_spawn(SLIME_SCENE, knight.global_position + Vector2.from_angle(deg_to_rad(-30.0 + i * 12.0)) * 120.0, false))
	# A full ring (six places for six): the last one's place can be on his far
	# side, so it walks around the others; give them up to 7 s.
	var tolerance := Brains.table.fodder_ring_tolerance_px
	var placed := func() -> bool:
		knight.health.heal(100000.0)
		return slimes.all(func(s: Enemy) -> bool: return s.get_ring_spot() != Vector2.INF and s.global_position.distance_to(s.get_ring_spot()) <= tolerance + 1.0)
	var start := Brains.get_time()
	await _wait_until(placed, 420)
	var took := Brains.get_time() - start
	var reach_frames: Array[int] = [0, 0, 0, 0, 0, 0]
	for i in 30:
		await get_tree().physics_frame
		knight.health.heal(100000.0)
		for k in slimes.size():
			reach_frames[k] += int(slimes[k].attack.is_in_range(knight))
	var member_r := slimes[0].get_gameplay_radius_px()
	var radius := knight.get_gameplay_radius_px() + member_r + slimes[0].attack.get_range_px() * Brains.table.fodder_ring_reach_share
	var on_ring := true
	var at_place := true
	var in_reach := true
	var min_d := INF
	for k in slimes.size():
		var s := slimes[k]
		on_ring = on_ring and absf(s.get_ring_spot().distance_to(knight.global_position) - radius) < 0.5
		at_place = at_place and s.global_position.distance_to(s.get_ring_spot()) <= Brains.table.fodder_ring_tolerance_px + 1.0
		in_reach = in_reach and reach_frames[k] == 30
	for i in slimes.size():
		for j in range(i + 1, slimes.size()):
			min_d = minf(min_d, slimes[i].global_position.distance_to(slimes[j].global_position))
	_check("all six have their place in one ring around him (%.1f px, half their reach), stand at it (after %.1f s), and stay in reach (frames of 30: %s)" % [radius, took, reach_frames],
		[on_ring, at_place, in_reach], [true, true, true])
	# Their places are 0.6 m apart edge to edge (a full ring of six: a little
	# more); each stands within the tolerance of its own (6 px).
	_check("side by side, not stacked: about 0.6 m between them, edge to edge (got %.1f px)" % (min_d - 2.0 * member_r),
		min_d >= 2.0 * member_r + Brains.table.fodder_ring_spacing_px - 2.0 * Brains.table.fodder_ring_tolerance_px - 2.0, true)
	_check("no tokens (fodder swarms)", [Brains.get_token_holders(knight).size(), Brains.get_token_cost(slimes[0])], [0, 0])
	# Then the real fight: their hits push him about; each keeps hitting him.
	knight.status_component.remove_status(steady.id)
	var landed: Array[int] = [0, 0, 0, 0, 0, 0]
	for k in slimes.size():
		slimes[k].attack.attack_landed.connect(func(_t: Unit, _d: float) -> void: landed[k] += 1)
	for i in 240:
		await get_tree().physics_frame
		knight.health.heal(100000.0)
	_check("pushed about by their hits for 4 s, every one of them keeps hitting him (hits each: %s)" % [landed], landed.all(func(n: int) -> bool: return n >= 1), true)
	for s in slimes:
		s.passive = true
		s.attack.cancel()
		s.queue_free()
	await _frames(30)


func _test_sandbox_packs() -> void:
	_section("SandboxBrains (AI2): the pack scenarios; the overlay's token")
	await _reset_knight()
	var sb := SandboxBrains.new()
	add_child(sb)
	await _frames(2)
	var first := sb.run_scenario(&"pack")
	await _frames(2)
	var pack: Pack = first.get_pack() if first != null else null
	_check("pack: five test brutes in one Pack 9 m away, idle",
		[pack != null and pack.get_members().size() == 5, first != null and first.data == BRUTE_DATA,
			pack != null and absf(pack.get_home().distance_to(knight.global_position) - 288.0) < 2.0, first != null and first.ai != Enemy.AI.AGGRO],
		[true, true, true, true])
	if pack != null:
		_place(knight, pack.get_home() + Vector2(-90, 0))
		await _wait_until(func() -> bool: return pack.get_members().all(func(m: Enemy) -> bool: return m.ai == Enemy.AI.AGGRO), 90)
		_check("walk up to it: one notices, and the pack wakes", pack.get_members().all(func(m: Enemy) -> bool: return m.ai == Enemy.AI.AGGRO), true)
		await _wait_until(func() -> bool: return first.get_brain().get_intent() != &"", 30)
		_check("the overlay shows its token", sb.get_overlay_text(first).contains("token "), true)
	var slime := sb.run_scenario(&"fodder")
	await _frames(2)
	_check("fodder: eight slimes in one Pack; the brutes' pack gone",
		[slime != null and slime.get_pack().get_members().size() == 8, slime != null and slime.data == SLIME_DATA, not is_instance_valid(pack)], [true, true, true])
	# The fix (Ryan, 2026-10-05): with the panel open, H's fodder picked its first
	# slime (no behavior preset) and the panel's sync broke on it.
	sb.set_panel(true)
	slime = sb.run_scenario(&"fodder")
	var picked_by_h := sb.get_picked()
	await _frames(2)
	sb.pick(slime)
	await _frames(2)
	_check("the panel open: fodder (no behavior preset) picks none, by H or by hand; the panel says so",
		[picked_by_h == null, sb.get_picked() == null, sb.is_pickable(slime), sb._panel_title.text.begins_with("No brained enemy")], [true, true, false, true])
	sb.set_panel(false)
	sb.clear_scenario()
	sb.queue_free()
	await _frames(2)


# --- AI3: the skirmisher and the caster ----------------------------------------------------

func _test_ai3_data() -> void:
	_section("AI3 data: the skirmisher and caster presets, the test enemies, the table's numbers")
	var values: Array = []
	for slider in EnemyBehavior.SLIDERS:
		values.append(SKIRMISHER_BEHAVIOR.get_slider(slider))
	_check("skirmisher: aggression .7, respect .8, patience 2, band 400–600, reaction .3, dodge .6 / 4, greed .8, finish .3, pressure 12, breather 5, jitter .2; AI3b: confidence .6, all in .4, lead .3, spend .7; AI3c: nerve .8; AI-D1: peel .6, opening .4; AI-D2: follow-through .2, greed .3, mixup .3",
		values, [0.7, 0.8, 2.0, 400.0, 600.0, 0.3, 0.6, 4.0, 0.8, 0.3, 12.0, 5.0, 0.2, 0.6, 0.4, 0.3, 0.7, 0.8, 0.6, 0.4, 0.2, 0.3, 0.3])
	_check("its kind: role SKIRMISHER, hits and resets, uses tokens",
		[SKIRMISHER_BEHAVIOR.role, SKIRMISHER_BEHAVIOR.low_health, SKIRMISHER_BEHAVIOR.uses_tokens],
		[EnemyBehavior.Role.SKIRMISHER, EnemyBehavior.LowHealth.HIT_AND_RESET, true])
	values = []
	for slider in EnemyBehavior.SLIDERS:
		values.append(CASTER_BEHAVIOR.get_slider(slider))
	_check("caster: aggression .3, respect 1.2, patience 4, band 550–800, reaction .35, dodge .5 / 5, greed .4, finish .3, pressure 12, breather 5, jitter .15; AI3b: confidence .3, all in .2, lead .5, spend .8; AI3c: nerve .4; AI-D1: peel .5, opening .6; AI-D2: follow-through 0, greed .1, mixup .2",
		values, [0.3, 1.2, 4.0, 550.0, 800.0, 0.35, 0.5, 5.0, 0.4, 0.3, 12.0, 5.0, 0.15, 0.3, 0.2, 0.5, 0.8, 0.4, 0.5, 0.6, 0.0, 0.1, 0.2])
	_check("its kind: role CASTER, falls back below 35%, commits (weight 1: into its volley, ARCHETYPES AR1b; AI3 had 0, never)",
		[CASTER_BEHAVIOR.role, CASTER_BEHAVIOR.low_health, CASTER_BEHAVIOR.retreat_health, CASTER_BEHAVIOR.get_intent_weight(&"commit")],
		[EnemyBehavior.Role.CASTER, EnemyBehavior.LowHealth.FALL_BACK, 0.35, 1.0])
	_check("the test skirmisher (regular): Leap on Q (gap_close, a real leap), Stab on W (damage)",
		[SKIRMISHER_DATA.rank, _slot_ability(SKIRMISHER_DATA, &"q") == LEAP, _slot_ability(SKIRMISHER_DATA, &"w") == STAB, _intents(LEAP), _intents(STAB), LEAP.tags.has(&"leap")],
		[EnemyData.Rank.REGULAR, true, true, [&"gap_close"], [&"damage"], true])
	_check("the test caster (regular): Bolt on Q (poke), Blink away on E (escape); it notices from 850 u",
		[CASTER_DATA.rank, _slot_ability(CASTER_DATA, &"q") == CASTER_BOLT, _slot_ability(CASTER_DATA, &"e") == ESCAPE_BLINK, _intents(CASTER_BOLT), _intents(ESCAPE_BLINK), CASTER_DATA.detect_range],
		[EnemyData.Rank.REGULAR, true, true, [&"poke"], [&"escape"], 850.0])
	var rule: Condition = GUARD.ai_uses[0].conditions[0] if not GUARD.ai_uses.is_empty() and not GUARD.ai_uses[0].conditions.is_empty() else null
	_check("the elite test caster: Bolt, Guard on W (defend, only when THREATENED within 1 s), Blink away (and since AI3d a Snare on R: 4)",
		[CASTER_ELITE_DATA.rank, _slot_ability(CASTER_ELITE_DATA, &"w") == GUARD, _intents(GUARD), rule.kind if rule else -1, rule.value if rule else 0.0, CASTER_ELITE_DATA.abilities.size()],
		[EnemyData.Rank.ELITE, true, [&"defend"], Condition.Kind.THREATENED, 1.0, 4])
	var t := Brains.table
	_check("scores: defend .9, escape .75, retreat .7", [t.get_intent_score(&"defend"), t.get_intent_score(&"escape"), t.get_intent_score(&"retreat")], [0.9, 0.75, 0.7])
	_check("a caught caster walks away 2 s at most, then squares up for 3 s", [t.escape_walk_time, t.cornered_time], [2.0, 3.0])
	_check("casters keep 2 m apart and want cover within 45°", [Units.px_to_m(t.caster_spacing_px), t.cover_angle_deg], [2.0, 45.0])
	_check("the skirmisher's reset: 1.5 s once there, a 2 m hop, half its patience", [t.reset_time, Units.px_to_m(t.reset_hop_px), t.reset_patience], [1.5, 2.0, 0.5])


func _test_threatened() -> void:
	_section("The THREATENED condition kind (AI3)")
	var within_1 := _threat_condition(1.0)
	var within_03 := _threat_condition(0.3)
	var any := _threat_condition(0.0)
	var negated := _threat_condition(1.0)
	negated.negate = true
	var s := SituationContext.new()
	_check("nothing coming: false (negated: true); no situation: false, even negated",
		[within_1.is_met(knight, null, null, s), negated.is_met(knight, null, null, s), within_1.is_met(knight, null), negated.is_met(knight, null)], [false, true, false, false])
	s.incoming.append({"time_to_hit": 0.5})
	_check("an attack landing in 0.5 s: within 1 s yes, within 0.3 s no, any time yes",
		[within_1.is_met(knight, null, null, s), within_03.is_met(knight, null, null, s), any.is_met(knight, null, null, s)], [true, false, true])
	_check("a situation kind", within_1.is_situation_kind(), true)


func _test_effect_areas() -> void:
	_section("Ability.get_effect_area(): what an enemy sees coming at it (AI3)")
	await _reset_knight()
	var origin := knight.global_position
	var near := _spawn(SLIME_SCENE, origin + Vector2(60, 0), true)
	var side := _spawn(SLIME_SCENE, origin + Vector2(0, 200), true)
	var far := _spawn(SLIME_SCENE, origin + Vector2(200, 0), true)
	var beside := _spawn(SLIME_SCENE, origin + Vector2(0, 60), true)   # in reach, 90° off the aim
	await _frames(1)
	var ctx := CastContext.new()
	ctx.point = origin + Vector2(100, 0)
	ctx.direction = Vector2.RIGHT
	ctx.target = near
	var cleave := CLEAVE.get_effect_area(knight, ctx)
	_check("Cleave: its cone, 60° each side, out to its reach; it covers the slime in front, not one beside (in reach, 90° off) or beyond",
		[cleave.kind, snappedf(rad_to_deg(cleave.half_angle), 0.01), Ability.covers_unit(cleave, near), Ability.covers_unit(cleave, beside),
			Ability.covers_unit(cleave, side), Ability.covers_unit(cleave, far)],
		[&"cone", 60.0, true, false, false, false])
	var lunge := LUNGE.get_effect_area(knight, ctx)
	_check("Lunge: the path it will cut", [lunge.kind, lunge.to == ctx.point, Ability.covers_unit(lunge, near), Ability.covers_unit(lunge, side)], [&"segment", true, true, false])
	var judgement := JUDGEMENT.get_effect_area(knight, ctx)
	_check("Judgement: point-and-click on its target only", [judgement.kind, Ability.covers_unit(judgement, near), Ability.covers_unit(judgement, far)], [&"unit", true, false])
	_check("Iron Resolve: on nobody (a buff)", IRON_RESOLVE.get_effect_area(knight, ctx).kind, &"none")
	var leap := JUDGEMENT_LEAP.get_effect_area(knight, ctx)
	_check("Judgement Leap: its landing circle", [leap.kind, snappedf(leap.radius, 0.01)], [&"circle", snappedf(Units.to_px(JUDGEMENT_LEAP.get_param(knight, &"landing_radius")), 0.01)])
	var bolt := TEST_BOLT.get_effect_area(knight, ctx)
	_check("a projectile ability (the default): its line out to its range; it covers the slime in line, not the one beside",
		[bolt.kind, Ability.covers_unit(bolt, far), Ability.covers_unit(bolt, side)], [&"segment", true, false])
	var smash := SMASH.get_effect_area(knight, ctx)
	_check("a script with radius_px (the default): that circle at the point", [smash.kind, smash.center == ctx.point, smash.radius], [&"circle", true, 64.0])
	for x in [near, side, far, beside]:
		x.queue_free()
	await _frames(1)


func _test_decide_ai3() -> void:
	_section("decide() (AI3): defend, escape, cornered, retreat, a caster at commit weight 0 never commits (the preset commits since ARCHETYPES AR1b), poses by role")
	var caster := CASTER_BEHAVIOR.resolve({}, [] as Array[BrainAdjust])
	caster.jitter = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var s := _caster_situation(650.0)
	s.add_use(&"q", &"poke", _plan(&"q"))
	_check("a caster in its band with a poke: it pokes", EnemyBrain.decide(s, caster, rng).intent, &"poke")
	s.add_use(&"w", &"defend", _plan(&"w"))
	var d := EnemyBrain.decide(s, caster, rng)
	_check("something coming at it (a defend use passes): it defends, with Guard, in its guard pose", [d.intent, d.plan.slot if d.plan else &"", d.pose], [&"defend", &"w", &"guard"])
	s = _caster_situation(650.0, &"poke", 0.1)
	s.add_use(&"q", &"poke", _plan(&"q"))
	s.add_use(&"w", &"defend", _plan(&"w"))
	_check("even right after it started poking: an attack coming breaks the hold", EnemyBrain.decide(s, caster, rng).intent, &"defend")
	s = _caster_situation(300.0)
	s.add_use(&"q", &"poke", _plan(&"q"))
	s.add_use(&"e", &"escape", _plan(&"e"))
	d = EnemyBrain.decide(s, caster, rng)
	_check("its target inside its band's minimum: it escapes, with its blink", [d.intent, d.plan.slot if d.plan else &"", d.pose], [&"escape", &"e", &"step_back"])
	s = _caster_situation(300.0)
	s.add_use(&"q", &"poke", _plan(&"q"))
	d = EnemyBrain.decide(s, caster, rng)
	_check("its blink down: it escapes on foot (no plan)", [d.intent, d.plan], [&"escape", null])
	s.cornered = true
	d = EnemyBrain.decide(s, caster, rng)
	_check("cornered: no escape; it pokes, squared up (cornered pose)", [d.intent, d.pose], [&"poke", &"cornered"])
	s = _caster_situation(650.0)
	s.add_use(&"q", &"poke", _plan(&"q"))
	s.health_ratio = 0.3
	d = EnemyBrain.decide(s, caster, rng)
	_check("below 35% health: it falls back, still poking", [d.intent, d.plan.slot if d.plan else &"", d.pose], [&"retreat", &"q", &"step_back"])
	s.health_ratio = 0.5
	_check("at 50%: it pokes", EnemyBrain.decide(s, caster, rng).intent, &"poke")
	s = _caster_situation(650.0)
	s.patience = 1.0
	var shy: EnemyBehavior = caster.duplicate()
	shy.intent_weights = {&"commit": 0.0}
	_check("a caster at commit weight 0 (AI3's preset, before its volley) with full patience and nothing needed: never a commit", EnemyBrain.decide(s, shy, rng).intent, &"hold")
	_check("the caster preset since ARCHETYPES AR1b (weight 1): it commits (into its volley)", EnemyBrain.decide(s, caster, rng).intent, &"commit")
	var brute := _regular_brute()
	brute.jitter = 0.0
	s = _situation(1.0, 0.0)
	s.target_edge_distance_px = Units.to_px(300.0)
	_check("a brute walked in on (inside its band, no escape use): it holds its ground", EnemyBrain.decide(s, brute, rng).intent, &"hold")
	var skirmisher := SKIRMISHER_BEHAVIOR.resolve({}, [] as Array[BrainAdjust])
	skirmisher.jitter = 0.0
	s = _situation(1.0, 0.5)
	d = EnemyBrain.decide(s, skirmisher, rng)
	_check("a skirmisher holding: its stalk pose", [d.intent, d.pose], [&"hold", &"stalk"])
	s.resetting = true
	d = EnemyBrain.decide(s, skirmisher, rng)
	_check("a skirmisher's reset: it retreats, recoiling", [d.intent, d.pose], [&"retreat", &"recoil"])
	_check("the brute's poses are AI1's", [EnemyBrain.get_intent_pose(&"hold", EnemyBehavior.Role.BRUTE), EnemyBrain.get_intent_pose(&"poke", EnemyBehavior.Role.BRUTE), EnemyBrain.get_intent_pose(&"commit", EnemyBehavior.Role.BRUTE)],
		[&"hold", &"hold", &""])


## The step's "Done means": the caster pokes from 550–800 u.
func _test_caster_band_and_poke() -> void:
	_section("The elite caster holds 550–800 u from the Knight and pokes; with nothing aimed at it, no shield")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	knight.resource_pool.restore(1000.0)
	var caster := _spawn(CASTER_ELITE_SCENE, knight.global_position + Vector2(230, 0), false)
	var casts := {}
	caster.abilities.cast_started.connect(func(slot: StringName, _a: Ability, _c: CastContext) -> void: casts[slot] = int(casts.get(slot, 0)) + 1)
	var bolt_hits := [0]
	var on_damaged := func(ctx: HitContext) -> void:
		if ctx.source == caster and ctx.target == knight and not ctx.tags.has(&"basic_attack"):
			bolt_hits[0] += 1
	Events.unit_damaged.connect(on_damaged)
	var in_band := true
	var min_e := INF
	var max_e := 0.0
	for i in 420:
		await get_tree().physics_frame
		knight.health.heal(100000.0)
		knight.resource_pool.restore(1000.0)
		if i >= 120:
			var e := Units.to_units(caster.edge_distance_to(knight))
			min_e = minf(min_e, e)
			max_e = maxf(max_e, e)
			in_band = in_band and e >= 520.0 and e <= 830.0
	Events.unit_damaged.disconnect(on_damaged)
	_check("it holds in its band (550–800 u, a little slack; got %d–%d u)" % [roundi(min_e), roundi(max_e)], [caster.ai, in_band], [Enemy.AI.AGGRO, true])
	_check("it pokes the whole time: bolts cast (%d), and they hit the Knight standing there (%d)" % [int(casts.get(&"q", 0)), bolt_hits[0]],
		[int(casts.get(&"q", 0)) >= 2, bolt_hits[0] >= 1], [true, true])
	_check("nothing aimed at it: no shield, no blink", [int(casts.get(&"w", 0)), int(casts.get(&"e", 0))], [0, 0])
	caster.passive = true
	caster.queue_free()
	await _frames(30)


## The step's "Done means": the caster shields only when something is aimed
## at it (a projectile; and a point-and-click cast: Ryan, 2026-10-04).
func _test_caster_defends() -> void:
	_section("The elite caster shields when it sees an attack coming at it, never otherwise")
	await _reset_knight()
	knight.resource_pool.restore(1000.0)
	var caster := _spawn(CASTER_ELITE_SCENE, knight.global_position + Vector2(240, 0), false)
	var brain := caster.get_brain()
	var guards := [0]
	caster.abilities.cast_started.connect(func(slot: StringName, _a: Ability, _c: CastContext) -> void:
		if slot == &"w":
			guards[0] += 1)
	var poses: Array = []
	brain.pose_changed.connect(func(p: StringName) -> void: poses.append(p))
	await _frames(90)
	_check("settled in its band, nothing aimed at it: no shield", [caster.ai, guards[0]], [Enemy.AI.AGGRO, 0])
	var absorbed := [0.0]
	var on_hit := func(ctx: HitContext) -> void:
		if ctx.target == caster and ctx.source == knight:
			absorbed[0] += ctx.absorbed
	Events.unit_hit.connect(on_hit)
	var fired_at := Brains.get_time()
	knight.abilities.try_cast_free(TEST_BOLT, caster.global_position, null, &"test")
	await _wait_until(func() -> bool: return guards[0] > 0, 90)
	var took := Brains.get_time() - fired_at
	await _frames(45)
	Events.unit_hit.disconnect(on_hit)
	_check("a bolt flying at it: Guard goes up once its reaction time has passed (0.35–0.6 s; got %.2f s), in its guard pose" % took,
		[guards[0], took >= 0.35 and took <= 0.6, poses.has(&"guard")], [1, true, true])
	_check("the shield took the bolt (%.0f absorbed)" % absorbed[0], absorbed[0] > 0.0, true)
	caster.passive = true
	caster.queue_free()
	await _frames(30)

	# Judgement on it (point-and-click, 0.75 s): seen and shielded too.
	await _reset_knight()
	knight.resource_pool.restore(1000.0)
	var second := _spawn(CASTER_ELITE_SCENE, knight.global_position + Vector2(130, 0), false)
	second.abilities.start_cooldown(&"e")   # no blink: it stays in his range
	var second_guards := [0]
	second.abilities.cast_started.connect(func(slot: StringName, _a: Ability, _c: CastContext) -> void:
		if slot == &"w":
			second_guards[0] += 1)
	await _frames(3)
	var judged := knight.abilities.try_cast(&"r", second.global_position, second)
	await _wait_until(func() -> bool: return second_guards[0] > 0 or not knight.abilities.casting, 60)
	_check("Judgement cast on it: it sees it coming and its Guard goes up before it lands", [judged, second_guards[0]], [true, 1])
	second.passive = true
	second.queue_free()
	await _reset_knight()
	await _frames(60)


## The step's "Done means": the caster blinks away when caught and squares up
## when its blink is down.
func _test_caster_escapes() -> void:
	_section("Caught, the caster blinks away; its blink down, it walks away, then squares up and fights (no running for 3 s)")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	knight.resource_pool.restore(1000.0)
	var caster := _spawn(CASTER_SCENE, knight.global_position + Vector2(230, 0), false)
	var brain := caster.get_brain()
	await _frames(60)
	var asked := SituationContext.new()
	asked.has_target = true
	asked.target_unit = knight
	var plan := ESCAPE_BLINK.get_ai_plan(caster, asked)
	var away := (caster.global_position - knight.global_position).normalized()
	_check("its escape plan in the open: straight away from him, the whole blink", [plan != null and plan.intents == ([&"escape"] as Array[StringName]),
		plan != null and rad_to_deg(absf(away.angle_to(plan.point - caster.global_position))) < 1.0], [true, true])
	_place(knight, caster.global_position + Vector2(-50, 0))   # he walked in on it
	await _wait_until(func() -> bool: return not caster.abilities.is_ready(&"e"), 60)
	await _frames(10)
	_check("caught: it blinks away (its blink on cooldown), well out of his reach (got %d u)" % roundi(Units.to_units(caster.edge_distance_to(knight))),
		[caster.abilities.is_ready(&"e"), Units.to_units(caster.edge_distance_to(knight)) > 300.0], [false, true])
	var stick := Vector2(-50, 0)
	_place(knight, caster.global_position + stick)
	var escaped := false
	var walk_pose := false
	var walk_start := caster.global_position
	var walked := 0
	for i in 180:   # he sticks to it
		await get_tree().physics_frame
		escaped = escaped or brain.is_escaping()
		walk_pose = walk_pose or caster.get_pose() == &"step_back"
		if brain.is_cornered():
			break
		walked += 1
		_place(knight, caster.global_position + stick)
	_check("its blink down, caught again: it walks away from him (step_back pose; %d px)" % roundi(caster.global_position.distance_to(walk_start)),
		[escaped, walk_pose, caster.global_position.x > walk_start.x + 60.0], [true, true, true])
	_check("after 2 s on foot it's cornered (after %.2f s): it squares up" % (walked / 60.0), [brain.is_cornered(), caster.get_pose(), absf(walked / 60.0 - 2.0) < 0.2], [true, &"cornered", true])
	var corner_pos := caster.global_position
	var landed := [0]
	caster.attack.attack_landed.connect(func(_t: Unit, _d: float) -> void: landed[0] += 1)
	var ran := false
	for i in 150:   # 2.5 s of its 3
		await get_tree().physics_frame
		knight.health.heal(100000.0)
		ran = ran or brain.is_escaping() or brain.get_intent() == &"escape"
	_check("cornered: it doesn't run (it stays put, %d px), it swings at him (its weak, slow close option)" % roundi(caster.global_position.distance_to(corner_pos)),
		[ran, landed[0] >= 1, caster.global_position.distance_to(corner_pos) < 40.0], [false, true, true])
	caster.passive = true
	caster.attack.cancel()
	caster.queue_free()
	await _frames(30)


## The step's "Done means": low health → behind a melee packmate.
func _test_caster_falls_back() -> void:
	_section("Below 35% health the caster falls back behind its melee packmate and keeps poking")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	knight.resource_pool.restore(1000.0)   # his kit up: the brute holds
	var pack := Pack.new()
	pack.name = "FallBackPack"
	var brute := BRUTE_SCENE.instantiate() as Enemy
	var caster := CASTER_ELITE_SCENE.instantiate() as Enemy
	caster.position = Vector2(60, -80)
	pack.add_child(brute)
	pack.add_child(caster)
	entities.add_child(pack)
	_place(pack, knight.global_position + Vector2(170, 0))
	await _frames(90)
	var mates: Array[Enemy] = [brute]
	var spot := EnemyBrain.get_fall_back_spot(caster, knight, mates, caster.get_brain().behavior)
	var behind := (brute.global_position - knight.global_position).normalized()
	_check("its fall-back spot: straight behind the brute as seen from the Knight, edge to edge plus a little",
		[rad_to_deg(absf(behind.angle_to(spot - knight.global_position))) < 0.5, spot.distance_to(knight.global_position) > brute.global_position.distance_to(knight.global_position)], [true, true])
	caster.health.take_damage(caster.health.max_health * 0.7)
	var bolts := [0]
	caster.abilities.cast_started.connect(func(slot: StringName, _a: Ability, _c: CastContext) -> void:
		if slot == &"q":
			bolts[0] += 1)
	var retreated := false
	for i in 240:
		await get_tree().physics_frame
		knight.health.heal(100000.0)
		knight.resource_pool.restore(1000.0)
		retreated = retreated or caster.get_brain().get_intent() == &"retreat"
	var center := knight.global_position
	var spread := rad_to_deg(absf(angle_difference((brute.global_position - center).angle(), (caster.global_position - center).angle())))
	_check("it falls back (retreat)", retreated, true)
	_check("behind the brute as seen from the Knight (within 45°; got %.0f°), farther than it" % spread,
		[spread <= 45.0, caster.global_position.distance_to(center) > brute.global_position.distance_to(center)], [true, true])
	_check("still poking as it falls back (%d bolts)" % bolts[0], bolts[0] >= 1, true)
	for x in [brute, caster]:
		x.passive = true
		x.attack.cancel()
	pack.queue_free()
	await _frames(30)


## The step's "Done means": the skirmisher dives when respect drops and hops
## out after its hit.
func _test_skirmisher() -> void:
	_section("The skirmisher stalks while the kit is up, leaps in when it drops, hits and hops out (AI3's commit: no string, ARCHETYPES AR1a)")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	knight.resource_pool.restore(1000.0)
	var sk := _spawn_no_string(SKIRMISHER_SCENE, knight.global_position + Vector2(170, 0), false)
	_pin_ai3(sk)   # AI3's stalk: no confidence (AI3b)
	var brain := sk.get_brain()
	var leaps := [0]
	sk.abilities.cast_started.connect(func(slot: StringName, _a: Ability, _c: CastContext) -> void:
		if slot == &"q":
			leaps[0] += 1)
	for i in 120:
		await get_tree().physics_frame
		knight.resource_pool.restore(1000.0)
		knight.health.heal(100000.0)
	_check("his kit up: it holds in its band, stalking, no leap (%d u)" % roundi(Units.to_units(sk.edge_distance_to(knight))),
		[brain.get_intent(), sk.get_pose(), leaps[0], Units.to_units(sk.edge_distance_to(knight)) >= 370.0], [&"hold", &"stalk", 0, true])
	_spend_kit()
	var hp := knight.health.current
	await _wait_until(func() -> bool: return leaps[0] > 0, 360)
	_check("his kit spent: after its crouch it leaps (its gap-closer)", leaps[0], 1)
	await _wait_until(func() -> bool: return brain.is_resetting(), 120)
	var hit_edge := Units.to_units(sk.edge_distance_to(knight))
	_check("its leap landed a hit and its commit ended there: it resets, recoiling, with about half its patience (%.2f)" % brain.get_patience(),
		[knight.health.current < hp, brain.is_resetting(), brain.get_patience() >= 0.5 and brain.get_patience() < 0.7, sk.get_pose()], [true, true, true, &"recoil"])
	var farthest := 0.0
	var reset_intents: Array = []
	for i in 60:
		await get_tree().physics_frame
		farthest = maxf(farthest, Units.to_units(sk.edge_distance_to(knight)))
		if not reset_intents.has(brain.get_intent()):
			reset_intents.append(brain.get_intent())
	_check("it hops out: more than 2 m farther within a second (%d → %d u)" % [roundi(hit_edge), roundi(farthest)], farthest > hit_edge + 200.0, true)
	var out := [farthest]   # (a lambda captures a local by value)
	await _wait_until(func() -> bool:
		out[0] = maxf(out[0], Units.to_units(sk.edge_distance_to(knight)))
		return not brain.is_resetting(), 120)
	_check("and walks back out to its band through its reset (retreat; out to %d u)" % roundi(out[0]), [reset_intents, out[0] >= 380.0], [[&"retreat"], true])
	sk.passive = true
	sk.attack.cancel()
	sk.queue_free()
	await _reset_knight()
	await _frames(30)


## A gap-closer only gets it there: its leap missing (he stepped aside) ends
## nothing; the commit goes on until a hit lands or reset_time runs out.
func _test_skirmisher_miss() -> void:
	_section("The skirmisher's leap misses: its commit goes on (a gap-closer's cast doesn't end it; AI3's commit: no string)")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	_spend_kit()
	var sk := _spawn_no_string(SKIRMISHER_SCENE, knight.global_position + Vector2(170, 0), false)
	_pin_ai3(sk)   # AI3's stalk: no confidence (AI3b)
	var brain := sk.get_brain()
	var leaps := [0]
	sk.abilities.cast_started.connect(func(slot: StringName, _a: Ability, _c: CastContext) -> void:
		if slot == &"q":
			leaps[0] += 1)
	await _wait_until(func() -> bool: return leaps[0] > 0, 360)
	_place(knight, knight.global_position + Vector2(0, 150))   # he steps out of its landing circle
	var hp := knight.health.current
	await _wait_until(func() -> bool: return not sk.abilities.casting and not sk.movement.is_leaping(), 90)
	await _frames(3)
	_check("landed short of him, no hit: still committing (chasing him down)", [knight.health.current == hp, brain.is_committing(), brain.get_intent()], [true, true, &"commit"])
	await _wait_until(func() -> bool: return brain.is_resetting(), 180)
	_check("then it resets (a hit landed, or 1.5 s once it got to him)", brain.is_resetting(), true)
	sk.passive = true
	sk.attack.cancel()
	sk.queue_free()
	await _reset_knight()
	await _frames(30)


## The same rule on a brute (which otherwise ends its commit after its first
## cast): a brute given the leap as a gap-closer keeps committing after it.
func _test_gap_closer_commit() -> void:
	_section("A gap-closer's cast doesn't end a brute's commit either (its first cast after it does)")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	_spend_kit()
	var leaper: EnemyData = BRUTE_DATA.duplicate()
	var slot := EnemyAbilitySlot.new()
	slot.slot = &"w"
	slot.ability = LEAP
	leaper.abilities = [BRUTE_DATA.abilities[0], slot]
	var brute := BRUTE_SCENE.instantiate() as Enemy
	brute.data = leaper
	entities.add_child(brute)
	_place(brute, knight.global_position + Vector2(170, 0))
	var brain := brute.get_brain()
	var leaps := [0]
	brute.abilities.cast_started.connect(func(s: StringName, _a: Ability, _c: CastContext) -> void:
		if s == &"w":
			leaps[0] += 1)
	await _wait_until(func() -> bool: return leaps[0] > 0, 600)
	_place(knight, knight.global_position + Vector2(0, 150))
	await _wait_until(func() -> bool: return not brute.abilities.casting and not brute.movement.is_leaping(), 90)
	await _frames(15)   # two thinks after it landed
	_check("it leapt (%d) and, landed short of him, still commits after two thinks" % leaps[0], [leaps[0], brain.is_committing()], [1, true])
	brute.passive = true
	brute.attack.cancel()
	brute.queue_free()
	await _reset_knight()
	await _frames(30)


func _test_sandbox_ai3() -> void:
	_section("SandboxBrains (AI3): Shift+H picks the test enemy; the mixed pack")
	await _reset_knight()
	var sb := SandboxBrains.new()
	add_child(sb)
	await _frames(2)
	var order: Array = []
	for i in 4:
		order.append(sb.cycle_scenario_enemy().resource_path.get_file())
	_check("Shift+H: brute → skirmisher → caster → elite caster → duelist (AI-D1)", order,
		["test_skirmisher.tscn", "test_caster.tscn", "test_caster_elite.tscn", "test_duelist.tscn"])
	sb.scenario_enemy = CASTER_ELITE_SCENE
	var caster := sb.run_scenario(&"all_ready")
	await _frames(2)
	_check("the scenarios spawn it (the elite caster)", caster != null and caster.data == CASTER_ELITE_DATA, true)
	var first := sb.run_scenario(&"mixed")
	await _frames(2)
	var roles: Array = []
	if first != null:
		for m in first.get_pack().get_members():
			roles.append(String(m.data.id))
	roles.sort()
	_check("mixed: one pack of a brute, a skirmisher, an elite caster and three slimes", roles,
		["slime", "slime", "slime", "test_brute", "test_caster_elite", "test_skirmisher"])
	sb.clear_scenario()
	sb.queue_free()
	await _frames(2)


func _caster_situation(edge_units: float, intent: StringName = &"hold", intent_age: float = 1.0) -> SituationContext:
	var s := _situation(0.5, 0.0, intent, intent_age)
	s.target_edge_distance_px = Units.to_px(edge_units)
	return s


func _threat_condition(within: float) -> Condition:
	var c := Condition.new()
	c.kind = Condition.Kind.THREATENED
	c.value = within
	return c


func _slot_ability(data: EnemyData, slot: StringName) -> Ability:
	for s in data.abilities:
		if s != null and s.slot == slot:
			return s.ability
	return null


func _intents(ability: Ability) -> Array:
	var out: Array = []
	for use in ability.get_ai_uses():
		out.append(use.intent)
	return out


# --- AI3d: the enemy ability library and full kits ---------------------------------------

func _test_ai3d_library() -> void:
	_section("AI3d: the enemy ability library: one template per archetype, each on a shared script")
	var files: Array = []
	for f in DirAccess.open(LIBRARY_DIR).get_files():
		if f.ends_with(".tres"):
			files.append(f.trim_suffix(".tres"))
	files.sort()
	var expected: Array = []
	for k: String in LIBRARY:
		expected.append("enemy_" + k)
	expected.sort()
	_check("14 templates in data/abilities/enemy/ (the pool waits for Hazards)", files, expected)
	var rows: Array = []
	var want: Array = []
	for k: String in LIBRARY:
		var a: Ability = load(LIBRARY_DIR + "enemy_%s.tres" % k)
		var info: Array = LIBRARY[k]
		rows.append([k, a.id, a.get_script().resource_path, a.get_role(), _intents(a)])
		want.append([k, StringName("enemy_" + k), info[0], info[1], info[2]])
	_check("each: its id, its shared script, one role tag, the starter list's uses", rows, want)


## The step's rule (ENEMIES_AI.md, Kits): every enemy ability telegraphs at
## least 0.6 s, unless it's faster than the reaction time on purpose and in
## the chip band.
func _test_ai3d_telegraph_rule() -> void:
	_section("AI3d: every enemy ability telegraphs at least 0.6 s, unless it's a quick chip hit (a combo's follow-up: at least 0.25 s, Ryan's tuning pass)")
	var library: Array = []
	for k: String in LIBRARY:
		library.append(load(LIBRARY_DIR + "enemy_%s.tres" % k))
	_check("every template keeps the rule", _telegraph_breaches(library), [])
	var kits: Array = []
	for f in DirAccess.open(ENEMY_DATA_DIR).get_files():
		if f.ends_with(".tres"):
			kits.append_array((load(ENEMY_DATA_DIR + f) as EnemyData).get_abilities_at(5).values())
	_check("so does every ability of every EnemyData (%d)" % kits.size(), _telegraph_breaches(kits), [])
	_check("the rule can fail: 35 damage in 0.35 s breaks it (chip is 32.5); 30 in 0.35 s doesn't; 120 in 0.6 s doesn't",
		[_telegraph_breaches([_bare_ability(0.35, 35.0)]).size(), _telegraph_breaches([_bare_ability(0.35, 30.0)]).size(),
			_telegraph_breaches([_bare_ability(0.6, 120.0)]).size()], [1, 0, 0])
	_check("a leap's flight counts: 0.5 s cast + 0.4 s flight", _telegraph_time(LEAP), 0.9)
	var follow_up := _bare_ability(0.3, 100.0)
	follow_up.combo_roles = [&"extender"] as Array[StringName]
	var fast_follow_up := _bare_ability(0.2, 100.0)
	fast_follow_up.combo_roles = [&"finisher"] as Array[StringName]
	var fast_opener := _bare_ability(0.3, 100.0)
	fast_opener.combo_roles = [&"opener", &"extender"] as Array[StringName]
	_check("a follow-up (extender or finisher, no opener role) of 100 damage: 0.3 s keeps it, 0.2 s breaks it; an opener at 0.3 s breaks it",
		[_telegraph_breaches([follow_up]).size(), _telegraph_breaches([fast_follow_up]).size(), _telegraph_breaches([fast_opener]).size()], [0, 1, 1])


func _test_ai3d_kits() -> void:
	_section("AI3d: the kits, built from the library (Ryan, 2026-10-04): regulars 2–3, elites 3–5")
	var datas: Array[EnemyData] = [BRUTE_DATA, SKIRMISHER_DATA, CASTER_DATA, CASTER_ELITE_DATA, ELITE_DATA]
	var rows: Array = []
	for data in datas:
		var ids: Array = []
		for slot in AbilityComponent.SLOTS:
			var a := _slot_ability(data, slot)
			ids.append(a.id if a != null else &"")
		rows.append(ids)
	_check("by slot (q, w, e, r): the brute's smash, cleave arc, charge; the skirmisher's leap, stab, flurry; the caster's bolt, orb, blink; the elite caster's bolt, guard, blink, snare; the elite slime's slam, shockwave, big hit",
		rows, [
			[&"test_brute_smash", &"test_brute_cleave_arc", &"test_brute_charge", &""],
			[&"test_skirmisher_leap", &"test_skirmisher_stab", &"test_skirmisher_flurry", &""],
			[&"test_caster_bolt", &"test_caster_lobbed_orb", &"test_caster_blink", &""],
			[&"test_caster_bolt", &"test_caster_guard", &"test_caster_blink", &"test_caster_snare"],
			[&"slime_elite_slam", &"slime_elite_shockwave", &"slime_elite_big_hit", &""]])
	var library_scripts := {}
	for k: String in LIBRARY:
		library_scripts[(LIBRARY[k] as Array)[0]] = true
	var outside: Array = []
	var bands: Array = []
	for data in datas:
		var rules := Brains.table.get_rank_rules(data.rank)
		var abilities: Array = data.get_abilities_at(5).values()
		bands.append(abilities.size() >= rules.min_abilities and abilities.size() <= rules.max_abilities)
		for a: Ability in abilities:
			if not library_scripts.has(a.get_script().resource_path):
				outside.append(a.id)
	_check("none authored from scratch: every one runs a library script", outside, [])
	_check("each kit inside its rank's band", bands, [true, true, true, true, true])
	_check("the stab: 30 damage now, in the chip band (Ryan)", STAB.base_damage, 30.0)
	var t := Brains.table
	var big_hit := _slot_ability(ELITE_DATA, &"e")
	var shockwave := _slot_ability(ELITE_DATA, &"w")
	_check("respect: the big hit 4 (ultimate), the snare 3 (its root counts +1), the shockwave 2 (a push isn't a status), the charge 2, the hop 2",
		[t.get_respect_value(big_hit), t.get_respect_value(_slot_ability(CASTER_ELITE_DATA, &"r")), t.get_respect_value(shockwave),
			t.get_respect_value(_slot_ability(BRUTE_DATA, &"e")), t.get_respect_value(HOP)], [4.0, 3.0, 2.0, 2.0, 2.0])
	_check("the elite slime's weights: big hit 1.3, shockwave 1.1, slam 1 (the big hit first when it's up)",
		[big_hit.ai_uses[0].weight, shockwave.ai_uses[0].weight, SLAM.get_ai_uses()[0].weight], [1.3, 1.1, 1.0])
	_check("status_root: 1 s, tags cc, root, debuff; it blocks moving and dashing, not attacking or casting (roots are roots)",
		[STATUS_ROOT.id, STATUS_ROOT.duration, STATUS_ROOT.tags == ([&"cc", &"root", &"debuff"] as Array[StringName]),
			STATUS_ROOT.blocks_move, STATUS_ROOT.blocks_dash, STATUS_ROOT.blocks_attack, STATUS_ROOT.blocks_cast],
		[&"root", 1.0, true, true, true, false, false])


func _test_ai3d_plans() -> void:
	_section("AI3d: the new archetypes' plans and the areas they show")
	await _reset_knight()
	var home := knight.global_position
	var brute := _spawn(BRUTE_SCENE, home + Vector2(-64, 0), true)
	var slime := _spawn(ELITE_SCENE, home + Vector2(0, -64), true)
	await _frames(2)
	var s := SituationContext.new()
	s.has_target = true
	s.target_unit = knight
	var arc := _slot_ability(BRUTE_DATA, &"w")
	var charge := _slot_ability(BRUTE_DATA, &"e")
	var shockwave := _slot_ability(ELITE_DATA, &"w")
	var alone := arc.get_ai_plan(brute, s)
	var friend := _friend(home + Vector2(0, 40))
	await _frames(2)
	var two := arc.get_ai_plan(brute, s)
	friend.queue_free()
	_place(brute, home + Vector2(-128, 0))
	var arc_far := arc.get_ai_plan(brute, s)
	var charge_near := charge.get_ai_plan(brute, s)
	_place(brute, home + Vector2(-224, 0))
	var charge_far := charge.get_ai_plan(brute, s)
	_check("the cleave arc at 2 m: damage alone, + zone with a second champion beside him; none at 4 m",
		[alone.intents if alone else [], two.intents if two else [], arc_far == null],
		[[&"damage"] as Array[StringName], [&"damage", &"zone"] as Array[StringName], true])
	_check("the charge: a gap-closer at 4 m, none at 7 m (its 6 m range)",
		[charge_near.intents if charge_near else [], charge_far == null], [[&"gap_close"] as Array[StringName], true])
	var wave_near := shockwave.get_ai_plan(slime, s)
	_place(slime, home + Vector2(0, -128))
	var wave_far := shockwave.get_ai_plan(slime, s)
	_check("the shockwave: only with him inside its circle (2 m yes, 4 m no)",
		[wave_near.intents if wave_near else [], wave_far == null], [[&"damage", &"cc"] as Array[StringName], true])
	_place(brute, home + Vector2(-64, 0))
	var hop := HOP.get_ai_plan(brute, s)
	var hop_ok := hop != null and absf(hop.point.distance_to(brute.global_position) - Units.to_px(300.0)) < 0.5 \
		and (hop.point - brute.global_position).normalized().dot(Vector2.LEFT) > 0.999
	_check("hop away: its whole 300 u straight away from him, an escape", [hop_ok, hop.intents if hop else []], [true, [&"escape"] as Array[StringName]])
	# The areas they show (the ally brain will read enemy casts this way).
	var ctx := CastContext.new()
	ctx.direction = Vector2.RIGHT
	ctx.point = brute.global_position + Vector2(160, 0)
	var arc_area := arc.get_effect_area(brute, ctx)
	var charge_area := charge.get_effect_area(brute, ctx)
	var wave_area := shockwave.get_effect_area(slime, ctx)
	_check("areas: the arc a cone from it (60° each side, its 250 u reach); the charge its band to the end; the shockwave a circle on itself; the hop none",
		[arc_area.kind, arc_area.origin == brute.global_position, is_equal_approx(rad_to_deg(arc_area.half_angle), 60.0), is_equal_approx(arc_area.range, Units.to_px(250.0)),
			charge_area.kind, charge_area.to == ctx.point, charge_area.half_width, wave_area.kind, wave_area.center == slime.global_position, wave_area.radius,
			HOP.get_effect_area(brute, ctx).kind],
		[&"cone", true, true, true, &"segment", true, 19.0, &"circle", true, 96.0, &"none"])
	# Where a dash strike ends: past the aim, capped, short of a wall.
	var origin := home + Vector2(0, 700)
	var short: Vector2 = charge.call(&"get_dash_end", origin, origin + Vector2(128, 0))
	var long: Vector2 = charge.call(&"get_dash_end", origin, origin + Vector2(400, 0))
	var wall := _wall_at(origin + Vector2(110, 0), Vector2(20, 200))
	await _frames(2)
	var walled: Vector2 = charge.call(&"get_dash_end", origin, origin + Vector2(128, 0))
	wall.queue_free()
	_check("the charge ends 1 m past the aim (160 of 128 px), at most 6 m (192 px), short of a wall (%.0f px; its face at 100)" % (walled.x - origin.x),
		[roundi(short.x - origin.x), roundi(long.x - origin.x), walled.x - origin.x <= 100.0 and walled.x - origin.x >= 90.0], [160, 192, true])
	brute.queue_free()
	slime.queue_free()
	await _frames(2)


func _test_ai3d_casts() -> void:
	_section("AI3d: the new archetypes hit what their telegraphs show")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	var hits := {}   # "<ability id>><unit instance id>" -> hits
	var count_hit := func(ctx: HitContext) -> void:
		if ctx.ability != null and is_instance_valid(ctx.target):
			var key := "%s>%d" % [ctx.ability.id, ctx.target.get_instance_id()]
			hits[key] = int(hits.get(key, 0)) + 1
	Events.unit_damaged.connect(count_hit)
	var home := knight.global_position
	# The cleave arc: in front he's hit, behind it he isn't.
	var brute := _spawn(BRUTE_SCENE, home + Vector2(-64, 0), true)
	await _frames(2)
	brute.abilities.try_cast(&"w", knight.global_position)
	await _frames(2)
	var cast_ctx := brute.abilities.get_cast_context()
	var tele: Telegraph = cast_ctx.telegraph if cast_ctx != null else null
	_check("the cleave arc's telegraph: a cone toward him, 60° to each side",
		[tele != null, tele != null and is_equal_approx(rad_to_deg(tele.cone_half_angle), 60.0), tele != null and tele.cone_direction.dot(Vector2.RIGHT) > 0.99],
		[true, true, true])
	var before := knight.global_position
	await _wait_until(func() -> bool: return not brute.abilities.casting, 90)
	await _frames(12)   # the push plays out
	_check("in front of it: hit once, pushed (%.0f px)" % knight.global_position.distance_to(before),
		[_hits_of(hits, &"test_brute_cleave_arc", knight), knight.global_position.distance_to(before) > 8.0], [1, true])
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID) and not knight.movement.is_displaced(), 60)
	_place(knight, brute.global_position + Vector2(-64, 0))   # behind it
	brute.abilities.reset_cooldown(&"w")
	await _frames(2)
	brute.abilities.try_cast(&"w", brute.global_position + Vector2(64, 0))
	await _wait_until(func() -> bool: return not brute.abilities.casting, 90)
	await _frames(2)
	_check("behind it: missed", _hits_of(hits, &"test_brute_cleave_arc", knight), 1)
	# The charge: along its band, everyone on it once, nobody beside it.
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	_place(knight, home)
	_place(brute, home + Vector2(-128, 0))
	var on_line := _friend(home + Vector2(-64, 0))
	var beside := _friend(home + Vector2(-64, 70))
	await _frames(2)
	var start := brute.global_position
	brute.abilities.try_cast(&"e", knight.global_position)
	await _frames(2)
	cast_ctx = brute.abilities.get_cast_context()
	tele = cast_ctx.telegraph if cast_ctx != null else null
	_check("the charge's telegraph: a band 38 px wide, 1 m past where he stands (160 px)",
		[tele != null and roundi(tele.line_vector.length()) == 160, tele.width_px if tele else 0.0], [true, 38.0])
	await _wait_until(func() -> bool: return not brute.abilities.casting, 90)
	await _wait_until(func() -> bool: return not brute.movement.is_displaced(), 60)
	await _frames(2)
	_check("it charges along it (%.0f of 160 px): him and the friend on the line hit once each, the one beside it not" % brute.global_position.distance_to(start),
		[absf(brute.global_position.distance_to(start) - 160.0) < 12.0, _hits_of(hits, &"test_brute_charge", knight),
			_hits_of(hits, &"test_brute_charge", on_line), _hits_of(hits, &"test_brute_charge", beside)], [true, 1, 1, 0])
	on_line.queue_free()
	beside.queue_free()
	var root: StatusEffect = STATUS_ROOT.duplicate()
	root.duration = -1.0
	brute.status_component.apply_status(root)
	brute.abilities.reset_cooldown(&"e")
	_check("rooted, it can't charge (a dash: roots are roots)", brute.abilities.get_fail_reason(&"e", knight.global_position) != "", true)
	brute.status_component.remove_status(root.id)
	brute.queue_free()
	# The shockwave: around itself, pushing him away.
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID) and not knight.movement.is_displaced(), 60)
	_place(knight, home)
	var slime := _spawn(ELITE_SCENE, home + Vector2(-64, 0), true)
	await _frames(2)
	var d0 := knight.global_position.distance_to(slime.global_position)
	slime.abilities.try_cast(&"w", slime.global_position)
	await _wait_until(func() -> bool: return not slime.abilities.casting, 90)
	await _frames(15)
	var d1 := knight.global_position.distance_to(slime.global_position)
	_check("the shockwave 2 m from him: hit once, pushed away from it (%.0f to %.0f px)" % [d0, d1],
		[_hits_of(hits, &"slime_elite_shockwave", knight), d1 > d0 + 30.0], [1, true])
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID) and not knight.movement.is_displaced(), 60)
	_place(knight, slime.global_position + Vector2(128, 0))
	slime.abilities.reset_cooldown(&"w")
	await _frames(2)
	slime.abilities.try_cast(&"w", slime.global_position)
	await _wait_until(func() -> bool: return not slime.abilities.casting, 90)
	await _frames(2)
	_check("4 m from him: missed", _hits_of(hits, &"slime_elite_shockwave", knight), 1)
	slime.queue_free()
	# The snare: a skillshot that roots him for 1 s.
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID) and not knight.movement.is_displaced(), 60)
	_place(knight, home)
	var caster := _spawn(CASTER_ELITE_SCENE, home + Vector2(-250, 0), true)
	await _frames(2)
	caster.abilities.try_cast(&"r", knight.global_position)
	await _wait_until(func() -> bool: return knight.status_component.has_tag(&"root"), 240)
	var rooted := knight.status_component.has_tag(&"root")
	var no_dash := knight.is_dash_blocked()
	var t0 := Brains.get_time()
	await _wait_until(func() -> bool: return not knight.status_component.has_tag(&"root"), 120)
	_check("the snare roots him, no dash either, for about 1 s (%.2f s)" % (Brains.get_time() - t0),
		[rooted, no_dash, absf(Brains.get_time() - t0 - 1.0) < 0.15], [true, true, true])
	caster.queue_free()
	# Hop away: a quick dash straight away from him (on a brute, for the test).
	var hopper_data: EnemyData = BRUTE_DATA.duplicate()
	var slot := EnemyAbilitySlot.new()
	slot.slot = &"r"
	slot.ability = HOP
	hopper_data.abilities = [BRUTE_DATA.abilities[0], slot]
	var hopper := BRUTE_SCENE.instantiate() as Enemy
	hopper.data = hopper_data
	hopper.passive = true
	entities.add_child(hopper)
	_place(hopper, home + Vector2(-64, 0))
	await _frames(2)
	var hs := SituationContext.new()
	hs.has_target = true
	hs.target_unit = knight
	var plan := HOP.get_ai_plan(hopper, hs)
	var h0 := hopper.global_position
	hopper.abilities.try_cast(&"r", plan.point)
	await _wait_until(func() -> bool: return not hopper.abilities.casting and not hopper.movement.is_displaced(), 60)
	await _frames(2)
	_check("hop away: 3 m straight away from him (%.0f px)" % hopper.global_position.distance_to(h0),
		[absf(hopper.global_position.distance_to(h0) - Units.to_px(300.0)) < 8.0, (hopper.global_position - h0).normalized().dot(Vector2.LEFT) > 0.99], [true, true])
	hopper.queue_free()
	Events.unit_damaged.disconnect(count_hit)
	await _reset_knight()
	await _frames(30)


## The step's "Done means": the test enemies fight with their full kits.
func _test_ai3d_brains() -> void:
	_section("AI3d: the brains use their kits")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	_spend_kit()
	var brute := _spawn(BRUTE_SCENE, knight.global_position + Vector2(-140, 0), false)
	var brute_casts := {}
	var brute_first := [&""]
	brute.abilities.cast_started.connect(func(s: StringName, _a: Ability, _c: CastContext) -> void:
		brute_casts[s] = int(brute_casts.get(s, 0)) + 1
		if brute_first[0] == &"":
			brute_first[0] = s)
	for i in 900:   # 15 s
		await get_tree().physics_frame
		knight.health.heal(100000.0)
		if i % 30 == 0:
			_spend_kit()
	_check("the test brute, his kit spent: it opens with a charge from its band (got %s), and uses more than one ability in 15 s (%s)" % [brute_first[0], brute_casts.keys()],
		[brute_first[0], brute_casts.size() >= 2], [&"e", true])
	brute.passive = true
	brute.attack.cancel()
	brute.queue_free()
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	_spend_kit()
	var slime := _spawn(ELITE_SCENE, knight.global_position + Vector2(0, -140), false)
	var slime_first := [&""]
	slime.abilities.cast_started.connect(func(s: StringName, _a: Ability, _c: CastContext) -> void:
		if slime_first[0] == &"":
			slime_first[0] = s)
	await _wait_until(func() -> bool:
		knight.health.heal(100000.0)
		return slime_first[0] != &"", 900)
	_check("the elite slime, his kit spent: it opens with its big hit (got %s)" % slime_first[0], slime_first[0], &"e")
	slime.passive = true
	slime.attack.cancel()
	slime.queue_free()
	await _reset_knight()
	var caster := _spawn(CASTER_ELITE_SCENE, knight.global_position + Vector2(-220, 0), false)
	await _wait_until(func() -> bool:
		knight.health.heal(100000.0)
		return knight.status_component.has_tag(&"root"), 720)
	_check("the elite caster, 6 m off: it pokes with its snare and roots him", knight.status_component.has_tag(&"root"), true)
	caster.passive = true
	caster.attack.cancel()
	caster.queue_free()
	await _reset_knight()
	var regular := _spawn(CASTER_SCENE, knight.global_position + Vector2(-220, 0), false)
	var pokes := {}
	regular.abilities.cast_started.connect(func(s: StringName, _a: Ability, _c: CastContext) -> void:
		pokes[s] = int(pokes.get(s, 0)) + 1)
	await _wait_until(func() -> bool:
		knight.health.heal(100000.0)
		return pokes.has(&"q") and pokes.has(&"w"), 720)
	_check("the regular caster, 6 m off: it pokes with its bolt and its lobbed orb (%s)" % pokes, [pokes.has(&"q"), pokes.has(&"w")], [true, true])
	regular.passive = true
	regular.attack.cancel()
	regular.queue_free()
	await _reset_knight()
	await _frames(30)


## An enemy ability's telegraph (ENEMIES_AI.md, Kits): its cast time, plus a
## leap's flight before the hit.
func _telegraph_time(a: Ability) -> float:
	var flight: Variant = a.get(&"leap_time")
	return a.cast_time + (float(flight) if flight is float else 0.0)


## The rule's breaches among `abilities`: a damaging ability telegraphed under
## TELEGRAPH_MIN outside the chip band (CHIP_SHARE of the Knight's max health);
## a follow-up (_is_follow_up()) under FOLLOW_UP_MIN instead.
func _telegraph_breaches(abilities: Array) -> Array:
	var chip := CHIP_SHARE * knight.stats.max_health
	var out: Array = []
	for a: Ability in abilities:
		if a.base_damage <= 0.0:
			continue   # no damage (a blink, a shield): no telegraph needed
		var least := FOLLOW_UP_MIN if _is_follow_up(a) else TELEGRAPH_MIN
		if _telegraph_time(a) < least - 0.0001 and a.base_damage > chip:
			out.append("%s: %.2f s, %d damage" % [a.id, _telegraph_time(a), roundi(a.base_damage)])
	return out


## A combo's follow-up: it has combo roles and none is `opener` (an ability
## with no roles is no combo's, and keeps the full rule).
func _is_follow_up(a: Ability) -> bool:
	return not a.combo_roles.is_empty() and not a.combo_roles.has(&"opener")


func _bare_ability(cast: float, damage: float) -> Ability:
	var a := Ability.new()
	a.id = &"bare"
	a.cast_time = cast
	a.base_damage = damage
	return a


func _hits_of(hits: Dictionary, ability_id: StringName, unit: Node) -> int:
	return int(hits.get("%s>%d" % [ability_id, unit.get_instance_id()], 0))


# --- AI3b: the duel (ENEMIES_AI.md, Duels and odds) ------------------------------------------

## Pins a brain's AI3b sliders to their AI3 values (no confidence or aim lead,
## never all in, its key never held), so a check of an older rule stays about
## that rule. Ryan's crowded mix still plays (backing up once or standing).
func _pin_ai3(e: Enemy) -> void:
	var b := e.get_brain().behavior
	b.confidence = 0.0
	b.crowded_commit = 0.0
	b.aim_lead = 0.0
	b.spend_eagerness = 1.0
	b.nerve = 0.0   # AI3c


## Turns the press off (AI3c) for a check of an older rule with enough enemies
## on the Knight to press; _restore_press() puts the table's threshold back.
func _no_press() -> void:
	if _odds_threshold_saved < 0.0:
		_odds_threshold_saved = Brains.table.odds_threshold
	Brains.table.odds_threshold = 1000.0


func _restore_press() -> void:
	if _odds_threshold_saved >= 0.0:
		Brains.table.odds_threshold = _odds_threshold_saved
		_odds_threshold_saved = -1.0


func _test_ai3b_data() -> void:
	_section("AI3b data: the four sliders, crowded range, the table's numbers, the adjusts")
	var limits: Array = []
	for s: StringName in [&"confidence", &"crowded_commit", &"aim_lead", &"spend_eagerness"]:
		limits.append(EnemyBehavior.LIMITS[s])
	_check("confidence, crowded_commit, aim_lead, spend_eagerness: each 0–1, in the panel's list",
		[limits, EnemyBehavior.SLIDERS.slice(13, 17)], [[[0.0, 1.0], [0.0, 1.0], [0.0, 1.0], [0.0, 1.0]], [&"confidence", &"crowded_commit", &"aim_lead", &"spend_eagerness"]])
	_check("crowded range (Ryan: its own value): brute 200, skirmisher 200, caster −1 = its band's minimum (550)",
		[BRUTE_BEHAVIOR.get_crowded_range(), SKIRMISHER_BEHAVIOR.get_crowded_range(), CASTER_BEHAVIOR.crowded_range, CASTER_BEHAVIOR.get_crowded_range()],
		[200.0, 200.0, -1.0, 550.0])
	var t := Brains.table
	_check("cautious 3 s, patience × (1 − 0.5 × confidence); a spend roll every 2 s; two champions in its area",
		[t.cautious_time, t.cautious_patience_cut, t.spend_roll_time, t.spend_min_champions], [3.0, 0.5, 2.0, 2])
	_check("an episode ends 1 s after its target left by 16 px; smell blood × 1.3, never above 0.89; the walk read over 0.2 s",
		[t.crowded_clear_time, t.crowded_clear_px, t.smell_blood_mult, t.smell_blood_cap, t.walk_velocity_time], [1.0, 16.0, 1.3, 0.89, 0.2])
	var adjust := BrainAdjust.new()
	_check("a BrainAdjust leaves the four at × 1 unless set",
		[adjust.get_multiplier(&"confidence"), adjust.get_multiplier(&"crowded_commit"), adjust.get_multiplier(&"aim_lead"), adjust.get_multiplier(&"spend_eagerness")],
		[1.0, 1.0, 1.0, 1.0])
	var regular := t.get_rank_rules(EnemyData.Rank.REGULAR).brain_adjust
	var r := BRUTE_BEHAVIOR.resolve({&"aim_lead": 0.7}, [regular] as Array[BrainAdjust])
	_check("resolve() carries them, an override included (a regular's adjust leaves them)",
		[r.confidence, r.crowded_commit, r.aim_lead, r.spend_eagerness], [0.5, 0.6, 0.7, 0.4])


## The step's tests: its key spent versus ready (patience, cautious).
func _test_ai3b_key_and_confidence() -> void:
	_section("The key ability and confidence: its own kit, effective respect, patience, cautious")
	var t := Brains.table
	var keys: Array = []
	var spawned: Array[Enemy] = []
	for scene: PackedScene in [BRUTE_SCENE, SKIRMISHER_SCENE, CASTER_SCENE, CASTER_ELITE_SCENE, ELITE_SCENE]:
		var e := _spawn(scene, ARENA + Vector2(-1500, 1500 + 200 * spawned.size()), true)
		spawned.append(e)
		keys.append(EnemyBrain.find_key_slot(e.abilities, t))
	_check("keys: the brute's smash (q: a tie goes to the earlier slot), the skirmisher's leap (q), the caster's bolt (q), the elite caster's snare (r: core 2 + its root), the elite slime's big hit (e: its ultimate)",
		keys, [&"q", &"q", &"q", &"r", &"e"])
	var brute := spawned[0]
	var shares: Array = [roundi(EnemyBrain.get_own_ready_share(brute.abilities, t, &"q") * 10000)]
	brute.abilities.start_cooldown(&"w")
	shares.append(roundi(EnemyBrain.get_own_ready_share(brute.abilities, t, &"q") * 10000))
	brute.abilities.start_cooldown(&"q")
	shares.append(roundi(EnemyBrain.get_own_ready_share(brute.abilities, t, &"q") * 10000))
	_check("the brute's own kit: all ready 1; its cleave arc down 4 ÷ 6; its smash (the key) down 0 (× 10,000)", shares, [10000, 6667, 0])
	for e in spawned:
		e.queue_free()
	var b := BRUTE_BEHAVIOR.resolve({}, [] as Array[BrainAdjust])
	var calm: EnemyBehavior = b.duplicate()
	calm.confidence = 0.0
	var s := _situation(1.0, 0.0)
	s.own_ready_share = 1.0
	_check("everything up on the Knight, its smash ready: effective respect 1 × (1 − 0.5 × 1) = 0.5", EnemyBrain.get_effective_respect(s, b), 0.5)
	_check("at confidence 0: unchanged (1)", EnemyBrain.get_effective_respect(s, calm), 1.0)
	s.effective_respect = EnemyBrain.get_effective_respect(s, b)
	_check("its smash ready: patience fills at 0.625 ÷ 3 a second (full in 4.8 s)", EnemyBrain.get_patience_rate(s, b, t), 0.625 / 3.0)
	s.own_ready_share = 0.0
	s.effective_respect = EnemyBrain.get_effective_respect(s, b)
	_check("its smash down: 1 ÷ 12, as in AI3", EnemyBrain.get_patience_rate(s, b, t), 1.0 / 12.0)
	s.cautious_left = 2.0
	_check("cautious: × (1 − 0.5 × 0.5) = 0.75", EnemyBrain.get_patience_rate(s, b, t), 0.75 / 12.0)
	_check("cautious at confidence 0: unchanged", EnemyBrain.get_patience_rate(s, calm, t), 1.0 / 12.0)

	# A real brute spends its smash: cautious 3 s, then its commit's end walks
	# it out to its band's far edge; at confidence 0 neither.
	for confidence: float in [0.5, 0.0]:
		await _reset_knight()
		await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
		var unstoppable := _tag_status(&"test_unstoppable", [&"unstoppable"])
		knight.status_component.apply_status(unstoppable)
		var rb := _spawn(BRUTE_SCENE, knight.global_position + Vector2(180, 0), false)
		var brain := rb.get_brain()
		brain.behavior.confidence = confidence
		brain.behavior.spend_eagerness = 1.0   # its smash isn't held
		brain.behavior.crowded_commit = 0.0
		rb.abilities.set(&"w", null)   # only its smash: the cleave arc would win on weight
		rb.abilities.set(&"e", null)
		_spend_kit()
		var smash_end := [-1.0]
		rb.abilities.cast_finished.connect(func(slot: StringName, _a: Ability) -> void:
			if slot == &"q" and smash_end[0] < 0.0:
				smash_end[0] = Brains.get_time())
		await _wait_until(func() -> bool: return smash_end[0] >= 0.0, 600)
		await _frames(1)
		var cautious_left := brain.get_cautious_left()
		await _wait_until(func() -> bool: return not brain.is_committing(), 300)
		await _frames(2)
		var walking := brain.is_walking_out()
		var intent := brain.get_intent()
		var pose := rb.get_pose()
		var far := [0.0]
		for i in 120:
			await get_tree().physics_frame
			if brain.is_walking_out():
				far[0] = maxf(far[0], Units.to_units(rb.edge_distance_to(knight)))
		if confidence > 0.0:
			_check("its smash cast (spent): cautious for 3 s (%.2f s left)" % cautious_left, [smash_end[0] >= 0.0, cautious_left > 2.9 and cautious_left <= 3.0], [true, true])
			_check("its commit's end: it walks out (a retreat, step_back) to its band's far edge (500 u; got %d u)" % roundi(far[0]),
				[walking, intent, pose, far[0] >= 470.0 and far[0] <= 540.0], [true, &"retreat", &"step_back", true])
		else:
			_check("at confidence 0: cautious all the same (it's the state), but no walk out to the far edge: AI1's back off", [cautious_left > 2.9, walking, intent == &"retreat"], [true, false, false])
		knight.status_component.remove_status(&"test_unstoppable")
		rb.passive = true
		rb.attack.cancel()
		rb.queue_free()
		await _frames(30)


func _test_ai3b_spend() -> void:
	_section("Spending the key: held for the right moment, one roll every 2 s, a poke never held")
	var b := _regular_brute()
	b.jitter = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var s := _situation(0.0, 1.0)
	s.target_edge_distance_px = 10.0
	s.key_slot = &"q"
	s.add_use(&"q", &"damage", _plan(&"q", 1.0))
	s.add_use(&"w", &"damage", _plan(&"w", 0.5))
	s.held_slot = &"q"
	var d := EnemyBrain.decide(s, b, rng)
	_check("its key held: a commit takes its other damage use", [d.intent, d.plan.slot], [&"commit", &"w"])
	s.held_slot = &""
	_check("free: its key (the better plan)", EnemyBrain.decide(s, b, rng).plan.slot, &"q")
	var p := _situation(1.0, 0.0)
	p.add_use(&"q", &"poke", _plan(&"q"))
	p.held_slot = &"q"
	d = EnemyBrain.decide(p, b, rng)
	_check("a poke is never held (casters poke the whole time)", [d.intent, d.plan.slot], [&"poke", &"q"])
	var g := _situation(0.0, 1.0)
	g.add_use(&"q", &"gap_close", _plan(&"q"))
	g.held_slot = &"q"
	_check("nor a gap-closer", EnemyBrain.decide(g, b, rng).plan.slot, &"q")
	var z := _situation(1.0, 0.0)
	z.add_use(&"q", &"zone", _plan(&"q"))
	z.held_slot = &"q"
	_check("a zone use is (its hold casts nothing)", [EnemyBrain.decide(z, b, rng).intent, EnemyBrain.decide(z, b, rng).plan], [&"hold", null])

	var m := _situation(0.5, 0.0)
	m.target_defensives = 1
	m.target_defensives_ready = 1
	var moments: Array = [EnemyBrain.get_right_moment(m, b)]
	m.target_cc = true
	moments.append(EnemyBrain.get_right_moment(m, b))
	m.target_cc = false
	m.target_health_ratio = 0.25
	moments.append(EnemyBrain.get_right_moment(m, b))
	m.target_health_ratio = 1.0
	m.target_defensives_ready = 0
	moments.append(EnemyBrain.get_right_moment(m, b))
	m.target_defensives = 0
	moments.append(EnemyBrain.get_right_moment(m, b))
	m.crowded = true
	moments.append(EnemyBrain.get_right_moment(m, b))
	m.crowded = false
	m.key_area_champions = 2
	moments.append(EnemyBrain.get_right_moment(m, b))
	_check("right moments: none (full health, Iron Resolve ready); stunned; below 30%; every defensive down; none with no defensive at all; crowded; two champions in its area",
		moments, ["", "crowd-controlled", "low", "defensives down", "", "crowded", "2 in its area"])

	# The roll, on a real brain (its own seeded stream).
	var brute := _spawn(BRUTE_SCENE, ARENA + Vector2(-1500, 1500), true)
	var brain := brute.get_brain()
	var snap := PartySnapshot.new()
	var rates: Array = []
	for eagerness: float in [0.5, 1.0, 0.0]:
		brain.behavior.spend_eagerness = eagerness
		brain.rng.seed = 5
		brain.set("_next_spend_roll", -1.0)
		var frees := 0
		var steady := true
		var now := 1000.0
		for i in 1000:
			var ks := _situation(0.5, 0.0)
			ks.key_slot = &"q"
			ks.key_ready = true
			ks.target_defensives = 1
			ks.target_defensives_ready = 1
			brain.call("_update_spend", ks, snap, now)
			var free := ks.held_slot == &""
			frees += int(free)
			var again := _situation(0.5, 0.0)   # 1.9 s later: the same roll
			again.key_slot = &"q"
			again.key_ready = true
			again.target_defensives = 1
			again.target_defensives_ready = 1
			brain.call("_update_spend", again, snap, now + 1.9)
			steady = steady and (again.held_slot == &"") == free
			now += 2.0
		rates.append(frees)
		if eagerness == 0.5:
			_check("at 0.5 about half the 2 s rolls free it (%d of 1,000), one roll per 2 s" % frees, [absi(frees - 500) <= 50, steady], [true, true])
	_check("at 1 always free (on cooldown, as before AI3b); at 0 always held outside a right moment", [rates[1], rates[2]], [1000, 0])
	var low := _situation(0.5, 0.0)
	low.key_slot = &"q"
	low.key_ready = true
	low.target_health_ratio = 0.25
	brain.call("_update_spend", low, snap, 5000.0)
	_check("at 0, a right moment frees it at once (the target below 30%)", [low.held_slot, low.right_moment, low.right_moment_reason], [&"", true, "low"])
	var down := _situation(0.5, 0.0)
	down.key_slot = &"q"
	down.key_ready = false
	brain.call("_update_spend", down, snap, 5002.0)
	_check("its key down: nothing to hold", down.held_slot, &"")
	brute.queue_free()

	# A real brute at spend 0: no smash while Iron Resolve is up; the Knight at
	# 25% (a right moment), and it smashes.
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	var unstoppable := _tag_status(&"test_unstoppable", [&"unstoppable"])
	knight.status_component.apply_status(unstoppable)
	var rb := _spawn(BRUTE_SCENE, knight.global_position + Vector2(180, 0), false)
	var rbrain := rb.get_brain()
	rbrain.behavior.spend_eagerness = 0.0
	rbrain.behavior.crowded_commit = 0.0
	rb.abilities.set(&"w", null)
	rb.abilities.set(&"e", null)
	var smashes := [0]
	var commits := [0]
	rb.abilities.cast_started.connect(func(slot: StringName, _a: Ability, _c: CastContext) -> void:
		if slot == &"q":
			smashes[0] += 1)
	rbrain.intent_changed.connect(func(intent: StringName) -> void:
		if intent == &"commit":
			commits[0] += 1)
	var max_hp := knight.health.max_health
	var commit_hits := Brains.table.commit_hits
	Brains.table.commit_hits = 1000   # its commits last until their first cast (or 4 s): room for a smash
	for i in 420:
		await get_tree().physics_frame
		_spend_kit()
		knight.abilities.reset_cooldown(&"w")   # Iron Resolve stays ready: no right moment
		knight.health.current = max_hp
	_check("at spend 0 with Iron Resolve up: it commits (%d, each until its first cast) but never smashes in 7 s" % commits[0], [commits[0] >= 1, smashes[0]], [true, 0])
	for i in 420:
		await get_tree().physics_frame
		_spend_kit()
		knight.abilities.reset_cooldown(&"w")
		knight.health.current = max_hp * 0.25
		if smashes[0] > 0:
			break
	_check("the Knight at 25% (a right moment): it smashes", smashes[0] >= 1, true)
	Brains.table.commit_hits = commit_hits
	knight.health.current = max_hp
	knight.status_component.remove_status(&"test_unstoppable")
	rb.passive = true
	rb.attack.cancel()
	rb.queue_free()
	await _frames(30)


## The step's tests: in its face with an answer and without; one roll each;
## escape and cornered still win; the same seed giving the same rolls.
func _test_ai3b_crowded() -> void:
	_section("Crowded: one roll per episode: cornered, escape, all in with an answer, else back up once or stand")
	var b := _regular_brute()
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var all_in := 0
	for i in 1000:
		var s := _situation(1.0, 0.0)
		s.target_edge_distance_px = Units.to_px(80.0)
		s.add_use(&"q", &"damage", _plan(&"q"))
		all_in += int(EnemyBrain.roll_crowded(s, b, rng).result == EnemyBrain.ALL_IN)
	_check("with an answer (its smash in reach): all in in about 60%% of 1,000 episodes (%d)" % all_in, absi(all_in - 600) <= 50, true)
	var back := 0
	var stand := 0
	for i in 1000:
		var s := _situation(1.0, 0.0)
		s.target_edge_distance_px = Units.to_px(80.0)
		var r := EnemyBrain.roll_crowded(s, b, rng)
		back += int(r.result == EnemyBrain.BACK_UP)
		stand += int(r.result == EnemyBrain.STAND)
	_check("no answer: it backs up once in about 1 − aggression (50%%) and otherwise stands (%d / %d)" % [back, stand],
		[absi(back - 500) <= 50, back + stand], [true, 1000])
	var mixed := 0
	var answered := 0
	for i in 1000:
		var s := _situation(1.0, 0.0)
		s.add_use(&"q", &"damage", _plan(&"q"))
		var r := EnemyBrain.roll_crowded(s, b, rng)
		if r.result != EnemyBrain.ALL_IN:
			mixed += 1
			answered += int(r.answer and (r.result == EnemyBrain.BACK_UP or r.result == EnemyBrain.STAND))
	_check("an answer whose roll failed falls to the mix (%d)" % mixed, [mixed > 300, answered], [true, mixed])
	var poke := _situation(1.0, 0.0)
	poke.add_use(&"q", &"poke", _plan(&"q"))
	var cc := _situation(1.0, 0.0)
	cc.add_use(&"w", &"cc", _plan(&"w"))
	_check("a poke isn't an answer; a cc use (the shockwave's knock-away, the snare) is", [poke.has_answer(), cc.has_answer()], [false, true])
	var cornered := _situation(1.0, 0.0)
	cornered.cornered = true
	cornered.add_use(&"q", &"damage", _plan(&"q"))
	var caster := CASTER_BEHAVIOR.resolve({}, [] as Array[BrainAdjust])
	var fleeing := _caster_situation(300.0)
	fleeing.add_use(&"q", &"damage", _plan(&"q"))
	_check("cornered: the cornered stand (no roll); a caster inside its band: escape (no roll)",
		[EnemyBrain.roll_crowded(cornered, b, rng).result, EnemyBrain.roll_crowded(cornered, b, rng).roll,
			EnemyBrain.roll_crowded(fleeing, caster, rng).result], [EnemyBrain.CORNERED, -1.0, EnemyBrain.ESCAPE])
	var runs: Array = []
	for run in 2:
		var seeded := RandomNumberGenerator.new()
		seeded.seed = 777
		var out: Array = []
		for i in 500:
			var s := _situation(1.0, 0.0)
			if i % 2 == 0:
				s.add_use(&"q", &"damage", _plan(&"q"))
			out.append(EnemyBrain.roll_crowded(s, b, seeded).result)
		runs.append(out)
	_check("the same seed gives the same rolls (500 episodes, twice)", runs[0] == runs[1], true)

	# A real test brute in its hold, the Knight stepping into its face (0.8 m).
	var cases := [
		["all in", 1.0, 0.5],    # crowded_commit, aggression
		["back up", 0.0, 0.0],
		["stand", 0.0, 1.0],
	]
	for c: Array in cases:
		await _reset_knight()
		await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
		var unstoppable := _tag_status(&"test_unstoppable", [&"unstoppable"])
		knight.status_component.apply_status(unstoppable)
		var rb := _spawn(BRUTE_SCENE, knight.global_position + Vector2(200, 0), false)
		var brain := rb.get_brain()
		brain.behavior.confidence = 0.0
		brain.behavior.spend_eagerness = 1.0
		brain.behavior.crowded_commit = c[1]
		brain.behavior.aggression = c[2]
		await _wait_until(func() -> bool: return brain.get_intent() == &"hold", 120)
		await _frames(20)
		var away := (knight.global_position - rb.global_position).normalized()
		var radii := knight.get_gameplay_radius_px() + rb.get_gameplay_radius_px()
		_place(knight, rb.global_position + away * (radii + Units.to_px(80.0)))
		var stepped_in := Brains.get_time()
		await _wait_until(func() -> bool: return brain.is_crowded(), 120)
		var took := Brains.get_time() - stepped_in
		var roll := brain.get_crowded_roll()
		var committed := [false]
		var retreated := [false]
		var step_back := [false]
		var max_edge := [0.0]
		for i in 90:
			await get_tree().physics_frame
			committed[0] = committed[0] or brain.is_committing()
			retreated[0] = retreated[0] or brain.get_intent() == &"retreat"
			step_back[0] = step_back[0] or rb.get_pose() == &"step_back"
			max_edge[0] = maxf(max_edge[0], Units.to_units(rb.edge_distance_to(knight)))
		var same := brain.get_crowded_roll() == roll and brain.is_crowded()
		match c[0]:
			"all in":
				_check("the Knight steps inside its 2 m: an episode, after its reaction time (0.455 s as a regular; got %.2f s)" % took,
					[brain.is_crowded(), took >= 0.44 and took <= 0.62], [true, true])
				_check("an answer ready, crowded_commit 1: all in (patience full at once: its tell, then it commits)", [roll, committed[0]], [EnemyBrain.ALL_IN, true])
			"back up":
				_check("no all in, aggression 0: it backs up once (a retreat, step_back) toward its band (got %d u)" % roundi(max_edge[0]),
					[roll, retreated[0], step_back[0], max_edge[0] >= 300.0, committed[0]], [EnemyBrain.BACK_UP, true, true, true, false])
			"stand":
				_check("aggression 1: it stands and swings (AI1's rule: no retreat, no commit)", [roll, retreated[0], committed[0]], [EnemyBrain.STAND, false, false])
		_check("%s: one roll for the episode (the same 1.5 s later, the Knight still near)" % c[0], same or not brain.is_crowded() or roll == EnemyBrain.BACK_UP, true)
		if c[0] == "stand":
			_place(knight, rb.global_position + away * (radii + Units.to_px(400.0)))
			await _frames(50)
			var still_on := brain.is_crowded()
			await _frames(30)
			_check("the Knight 4 m away: the episode lasts 1 s, then ends", [still_on, brain.is_crowded()], [true, false])
		knight.status_component.remove_status(&"test_unstoppable")
		rb.passive = true
		rb.attack.cancel()
		rb.queue_free()
		await _frames(30)


## Found building AI3b: its own commit brings it into the Knight's face, and
## that never starts an episode (nor its walk back out after it).
func _test_ai3b_own_commit() -> void:
	_section("Crowded: only the target coming in starts an episode, never its own commit")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	var unstoppable := _tag_status(&"test_unstoppable", [&"unstoppable"])
	knight.status_component.apply_status(unstoppable)
	var rb := _spawn(BRUTE_SCENE, knight.global_position + Vector2(180, 0), false)
	var brain := rb.get_brain()
	_pin_ai3(rb)
	brain.behavior.aggression = 0.0   # an episode would back it up: easy to see
	_spend_kit()
	var committed := [false]
	var crowded := [false]
	var near := [INF]
	for i in 420:
		await get_tree().physics_frame
		_spend_kit()
		knight.health.heal(100000.0)
		if brain.is_committing():
			committed[0] = true
		if committed[0]:
			near[0] = minf(near[0], Units.to_units(rb.edge_distance_to(knight)))
			crowded[0] = crowded[0] or brain.is_crowded()
	_check("it commits into his face (%d u, inside its 200 u) and walks back out: no episode the whole time" % roundi(near[0]),
		[committed[0], near[0] < 200.0, crowded[0]], [true, true, false])
	knight.status_component.remove_status(&"test_unstoppable")
	rb.passive = true
	rb.attack.cancel()
	rb.queue_free()
	await _frames(30)


## The step's tests: the player at 20% with and without a shield ready.
func _test_ai3b_smell_blood() -> void:
	_section("Smell blood: commit × 1.3 below 30%, capped; a ready defensive counted whole")
	var b := _regular_brute()
	b.jitter = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var s := _situation(0.0, 1.0)
	s.target_health_ratio = 0.25
	var scores: Array = [roundi(EnemyBrain.decide(s, b, rng).scores[&"commit"] * 10000)]
	s.target_health_ratio = 0.5
	scores.append(roundi(EnemyBrain.decide(s, b, rng).scores[&"commit"] * 10000))
	s.target_health_ratio = 0.25
	s.smell_blood_mult = 2.0
	scores.append(roundi(EnemyBrain.decide(s, b, rng).scores[&"commit"] * 10000))
	_check("commit: 0.65 × 1.3 = 0.845 below 30%; 0.65 at 50%; never above 0.89 (× 10,000)", scores, [8450, 6500, 8900])
	s.smell_blood_mult = 1.3
	s.add_use(&"w", &"defend", _plan(&"w"))
	_check("defend (0.9) still wins", EnemyBrain.decide(s, b, rng).intent, &"defend")
	var m := {"up": true, "health_ratio": 0.2, "total_value": 10.5, "ready_value": 1.5, "ready_defensive_value": 1.5}
	m.share = PartySnapshot.get_share(1.5 / 10.5, 0.2)
	var whole := snappedf(PartySnapshot.get_share_for(m, 0.3), 0.0001)
	m.health_ratio = 0.5
	m.share = PartySnapshot.get_share(1.5 / 10.5, 0.5)
	_check("the Knight at 20% with only Iron Resolve ready: its 1.5 counts whole (0.1429, not 0.0857); at 50% the share as before",
		[whole, PartySnapshot.get_share_for(m, 0.3) == m.share], [0.1429, true])
	m.health_ratio = 0.2
	m.ready_defensive_value = 0.0
	m.share = PartySnapshot.get_share(1.5 / 10.5, 0.2)
	_check("with nothing defensive ready the health cut stays", snappedf(PartySnapshot.get_share_for(m, 0.3), 0.0001), 0.0857)
	await _reset_knight()
	_spend_kit()
	knight.abilities.reset_cooldown(&"w")
	knight.health.current = knight.health.max_health * 0.2
	await _frames(2)
	var mm := Brains.get_snapshot().get_member(knight)
	_check("the snapshot: ready 1.5 (Iron Resolve), of it defensive 1.5, total 10.5, one defensive and it's ready",
		[mm.ready_value, mm.ready_defensive_value, mm.total_value, mm.defensives, mm.defensives_ready], [1.5, 1.5, 10.5, 1, 1])
	knight.health.current = knight.health.max_health
	await _reset_knight()


## The step's tests: aim lead against walking, stopping and dashing targets.
func _test_ai3b_aim_lead() -> void:
	_section("Aim lead: a walking target led by the time to the hit; a stop or a dash walks out of it")
	await _reset_knight()
	var caster := _spawn(CASTER_SCENE, knight.global_position + Vector2(0, -200), true)
	await _frames(2)
	var bolt := _slot_ability(CASTER_DATA, &"q")
	var here := knight.global_position
	var walk := Vector2(110, 0)
	var speed_px := Units.to_px(bolt.projectile_speed)
	var p := here
	for i in 2:
		p = here + walk * (bolt.cast_time + caster.global_position.distance_to(p) / speed_px)
	var led := bolt.get_led_point(caster, knight, walk, 1.0)
	_check("lead 0: where he stands; no walk: no lead", [bolt.get_led_point(caster, knight, walk, 0.0) == here, bolt.get_led_point(caster, knight, Vector2.ZERO, 1.0) == here], [true, true])
	_check("lead 1: his walk × (the 0.4 s cast + the bolt's flight) ahead (%.1f px)" % led.distance_to(here), led.distance_to(p) < 0.01, true)
	var half := bolt.get_led_point(caster, knight, walk, 0.5)
	var ratio := half.distance_to(here) / led.distance_to(here)
	_check("lead 0.5: about half as far (%.2f: nearer, so a shorter flight)" % ratio, ratio > 0.4 and ratio < 0.6, true)
	var far := bolt.get_led_point(caster, knight, Vector2(5000, 0), 1.0)
	_check("kept within its range (950 u)", caster.global_position.distance_to(far) <= Units.to_px(bolt.cast_range) + 0.01, true)
	var wall := _wall_at(led, Vector2(40, 40))
	await _frames(2)
	_check("a led point in a wall: where he stands", bolt.get_led_point(caster, knight, walk, 1.0) == here, true)
	wall.queue_free()
	await _frames(2)
	var s := SituationContext.new()
	s.has_target = true
	s.target_unit = knight
	s.target_position = here
	s.aim_lead = 1.0
	s.target_walk_velocity = walk
	var plan := bolt.get_ai_plan(caster, s)
	_check("the default plan aims there, its direction too, and keeps its lead (px)",
		[plan.point.distance_to(led) < 0.01, plan.direction.is_equal_approx((led - caster.global_position).normalized()), plan.lead_px > 30.0], [true, true, true])
	s.aim_lead = 0.0
	_check("aim_lead 0: where he stands (AI1's plan)", [bolt.get_ai_plan(caster, s).point == here, bolt.get_ai_plan(caster, s).lead_px], [true, 0.0])

	# Brains reads his walk: its velocity while he walks, nothing while he dashes.
	var target := here + Vector2(900, 0)
	knight.movement.move_to(target)
	await _frames(30)
	var walking := Brains.get_walk_velocity(knight)
	var speed := Units.to_px(knight.movement.get_move_speed())
	_check("walking: his walk velocity, along his walk (%.0f px/s of %.0f)" % [walking.length(), speed],
		[walking.length() > speed * 0.8 and walking.length() < speed * 1.2, walking.normalized().dot(Vector2.RIGHT) > 0.95], [true, true])
	knight.movement.stop()
	knight.dash.try_dash(Vector2.UP)
	await _frames(3)
	_check("dashing: zero (a dash is never led)", Brains.get_walk_velocity(knight), Vector2.ZERO)
	await _wait_until(func() -> bool: return not knight.movement.is_displaced(), 60)
	await _frames(20)
	_check("standing: zero", Brains.get_walk_velocity(knight).length() < 1.0, true)

	# The caster's bolt, cast at a Knight walking a straight line: led, it hits;
	# unled, it lands behind; led at a Knight who stops as it fires, it misses.
	var results: Array = []
	for lead: float in [1.0, 0.0, -1.0]:   # −1: led, but he stops at the cast
		await _reset_knight()
		await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
		caster.abilities.reset_cooldown(&"q")
		knight.movement.move_to(knight.global_position + Vector2(2000, 0))
		await _frames(30)
		_place(caster, knight.global_position + Vector2(0, -Units.to_px(400.0)))   # 4 m off his path: the lead stays inside its range
		var hit := [false]
		var on_hit := func(ctx: HitContext) -> void:
			if ctx.source == caster and ctx.target == knight and not ctx.blocked:
				hit[0] = true
		Events.unit_hit.connect(on_hit)
		var ls := SituationContext.new()
		ls.has_target = true
		ls.target_unit = knight
		ls.aim_lead = absf(lead)
		ls.target_walk_velocity = Brains.get_walk_velocity(knight)
		var cast_plan := bolt.get_ai_plan(caster, ls)
		caster.abilities.try_cast(&"q", cast_plan.point)
		if lead < 0.0:
			knight.movement.stop()
		await _frames(90)
		Events.unit_hit.disconnect(on_hit)
		knight.movement.stop()
		results.append(hit[0])
	_check("walking a straight line: the led bolt hits, the unled one misses; led, but he stops as it fires: it misses", results, [true, false, false])
	caster.queue_free()
	await _reset_knight()


func _test_ai3b_overlay_and_poses() -> void:
	_section("The overlay's duel lines; step_back for every role")
	var poses: Array = []
	for role in [EnemyBehavior.Role.BRUTE, EnemyBehavior.Role.SKIRMISHER, EnemyBehavior.Role.CASTER]:
		poses.append(EnemyBrain.get_intent_pose(&"retreat", role))
	_check("a walk out (the kiting step, the cautious walk) shows step_back for every role", poses, [&"step_back", &"step_back", &"step_back"])
	var b := _regular_brute()
	b.jitter = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 51
	var s := _situation(1.0, 0.0)
	s.walking_out = true
	var d := EnemyBrain.decide(s, b, rng)
	_check("walking out: a retreat (0.7) over hold, in step_back", [d.intent, d.pose], [&"retreat", &"step_back"])
	var brute := _spawn(BRUTE_SCENE, ARENA + Vector2(-1500, 1500), true)
	var sb := SandboxBrains.new()
	var lines: Array = []
	var brain := brute.get_brain()
	brain.think()   # passive: no situation; the key line reads the abilities
	lines.append(sb.get_duel_text(brute))
	brain.set("_cautious_until", Brains.get_time() + 2.1)
	lines.append(sb.get_duel_text(brute))
	_check("its key line: `key: Smash down` with no fight yet; cautious: `cautious 2.1 s`",
		[lines[0].begins_with("key: Smash down") or lines[0].begins_with("conf"), lines[1].begins_with("cautious 2.1 s")], [true, true])
	brain.set("_cautious_until", -1.0)
	brain.set("_episode", true)
	brain.set("_crowded_roll", EnemyBrain.ALL_IN)
	brain.set("_crowded_roll_value", 0.31)
	brain.set("_crowded_answer", true)
	_check("crowded: `crowded: all in (0.31 < 0.60)`", sb.get_duel_text(brute).contains("crowded: all in (0.31 < 0.60)"), true)
	brain.set("_crowded_roll", EnemyBrain.BACK_UP)
	brain.set("_crowded_answer", false)
	_check("`crowded: back up (no answer)`", sb.get_duel_text(brute).contains("crowded: back up (no answer)"), true)
	brain.set("_episode", false)
	brain.behavior.aim_lead = 0.5
	brain.set("_last_lead_px", 32.0)
	_check("aim lead: `lead 0.5 (+1.0 m)`", sb.get_duel_text(brute).contains("lead 0.5 (+1.0 m)"), true)
	sb.free()
	brute.queue_free()
	await _frames(2)


# --- AI3c: the odds, and think rates by rank (ENEMIES_AI.md, Odds; Performance) ----------------

func _test_ai3c_data() -> void:
	_section("AI3c data: nerve, the table's odds numbers, think rates by rank, duelist, the press pose")
	_check("nerve: 0–1, after AI3b's in the panel's list (AI-D1's two follow); brute .6, skirmisher .8, caster .4",
		[EnemyBehavior.LIMITS[&"nerve"], EnemyBehavior.SLIDERS[17], BRUTE_BEHAVIOR.nerve, SKIRMISHER_BEHAVIOR.nerve, CASTER_BEHAVIOR.nerve],
		[[0.0, 1.0], &"nerve", 0.6, 0.8, 0.4])
	var regular := Brains.table.get_rank_rules(EnemyData.Rank.REGULAR).brain_adjust
	_check("a BrainAdjust leaves nerve at × 1; resolve() carries it, an override included",
		[BrainAdjust.new().get_multiplier(&"nerve"), BRUTE_BEHAVIOR.resolve({&"nerve": 0.2}, [regular] as Array[BrainAdjust]).nerve], [1.0, 0.2])
	var t := Brains.table
	_check("strength: fodder 0.25, regular 1, elite 2, boss 4; a champion 1.5 (Ryan)",
		[t.get_rank_strength(EnemyData.Rank.FODDER), t.get_rank_strength(EnemyData.Rank.REGULAR), t.get_rank_strength(EnemyData.Rank.ELITE),
			t.get_rank_strength(EnemyData.Rank.BOSS), t.champion_strength], [0.25, 1.0, 2.0, 4.0, 1.5])
	_check("the press past 1.5; patience's push 0.5 × press; +1 token, capped at 4; the weakest pick's weight 0.5",
		[t.odds_threshold, t.odds_pressure, t.odds_token_bonus, t.tokens_per_target_cap, t.weakest_pick_weight], [1.5, 0.5, 1, 4, 0.5])
	_check("one heavy hit (10% of max health) per 0.8 s; the think budget 200 a second, never under 5",
		[t.heavy_hit_window, t.heavy_hit_share, t.think_budget, t.think_rate_floor], [0.8, 0.1, 200.0, 5.0])
	var rates: Array = []
	for rank in [EnemyData.Rank.FODDER, EnemyData.Rank.REGULAR, EnemyData.Rank.ELITE, EnemyData.Rank.BOSS]:
		rates.append(t.get_rank_rules(rank).think_rate)
	var duelist: EnemyData = BRUTE_DATA.duplicate()
	duelist.rank = EnemyData.Rank.ELITE
	duelist.duelist = true
	var regular_duelist: EnemyData = BRUTE_DATA.duplicate()
	regular_duelist.duelist = true
	_check("thinks a second by rank: fodder none, regular 10, elite 15, boss 25 (Ryan); a duelist elite the boss's; the flag means nothing below elite",
		[rates, t.get_think_rate_for(BRUTE_DATA), t.get_think_rate_for(ELITE_DATA), t.get_think_rate_for(duelist), t.get_think_rate_for(regular_duelist), BRUTE_DATA.duelist],
		[[0.0, 10.0, 15.0, 25.0], 10.0, 15.0, 25.0, 10.0, false])
	var press := POSE_SET.get_look(&"press")
	_check("the press pose: a 10° lean in, an amber rim pulsing at 1 Hz",
		[press != null and press.lean_deg == 10.0, press != null and press.pulse_hz == 1.0, press != null and press.rim_color.r > 0.9 and press.rim_color.g > 0.5 and press.rim_color.b < 0.4 and press.rim_color.a > 0.0],
		[true, true, true])


## Each side's strength worked out by hand (the step's tests), the enemies
## fighting only for the read (set aggroed and read in one frame).
func _test_ai3c_odds() -> void:
	_section("AI3c odds: a 1v1, a 3v1, an elite and fodder, against the Knight and the ally (by hand)")
	await _reset_knight()
	var threat := knight.stats_component.get_stat(&"threat")
	var far := ARENA + Vector2(-1800, -1800)
	var brutes: Array[Enemy] = []
	for i in 3:
		brutes.append(_spawn(BRUTE_SCENE, far + Vector2(60 * i, 0), true))
	var elite := _spawn(ELITE_SCENE, far + Vector2(0, 120), true)
	var fodder: Array[Enemy] = []
	for i in 3:
		fodder.append(_spawn(SLIME_SCENE, far + Vector2(60 * i, 240), true))
	var friend := _friend(ARENA + Vector2(0, 80))
	await _frames(2)
	var solo: Array[Unit] = [knight]
	var both: Array[Unit] = [knight, friend]
	var ally_threat := friend.stats_component.get_stat(&"threat")
	var one: Array[Enemy] = [brutes[0]]
	var three: Array[Enemy] = brutes.duplicate()
	var mixed: Array[Enemy] = [elite]
	mixed.append_array(fodder)
	var rows: Array = []
	for pair: Array in [[one, solo], [three, solo], [mixed, solo]]:
		var o := _odds_of(pair[0], pair[1])
		rows.append([roundi(float(o.odds) * 1000), roundi(float(o.press) * 1000)])
	_check("against the full-health Knight (threat %.1f: 1.5): one brute 0.67, no press; three 2.0, press 0.5; an elite and three fodder 1.83, press 0.33" % threat,
		rows, [[667, 0], [2000, 500], [1833, 333]])
	rows = []
	for pair: Array in [[three, both], [mixed, both]]:
		var o := _odds_of(pair[0], pair[1])
		rows.append([roundi(float(o.party) * 1000), roundi(float(o.odds) * 1000), roundi(float(o.press) * 1000)])
	_check("the ally beside him (threat %.1f): the party 3.0; three brutes 1.0 and an elite and fodder 0.92: neither presses" % ally_threat,
		rows, [[3000, 1000, 0], [3000, 917, 0]])
	var downed := _tag_status(&"test_downed", [&"downed"] as Array[StringName])
	friend.status_component.apply_status(downed)
	var o_down := _odds_of(three, both)
	friend.status_component.remove_status(downed.id)
	_check("the ally downed counts 0: three brutes press again (2.0, 0.5)", [roundi(float(o_down.odds) * 1000), roundi(float(o_down.press) * 1000)], [2000, 500])
	knight.health.current = knight.health.max_health * 0.3
	var o_low := _odds_of(one, solo)
	knight.health.heal(100000.0)
	elite.health.current = elite.health.max_health * 0.5
	var o_half := _odds_of([elite] as Array[Enemy], solo)
	_check("the Knight at 30% against one regular: 2.22, press 0.72; an elite at half health weighs 1 (0.67)",
		[roundi(float(o_low.odds) * 100), roundi(float(o_low.press) * 100), roundi(float(o_half.odds) * 100)], [222, 72, 67])
	brutes[0].passive = false   # not fighting (idle)
	brutes[1].ai = Enemy.AI.AGGRO   # aggroed but passive (a training dummy)
	brutes[2].passive = false
	brutes[2].ai = Enemy.AI.RETURN   # walking home
	var counted := Brains.compute_odds(solo, three)
	brutes[0].ai = Enemy.AI.AGGRO
	var nobody := Brains.compute_odds([] as Array[Unit], one)
	var empty := Brains.compute_odds([] as Array[Unit], [] as Array[Enemy])
	for e in brutes:
		e.passive = true
		e.ai = Enemy.AI.IDLE
	_check("one not fighting, a passive one and one walking home don't count", float(counted.enemy), 0.0)
	_check("no party up: the odds INF and a full press with an enemy fighting; 0 with nobody", [is_inf(float(nobody.odds)), float(nobody.press), float(empty.odds), float(empty.press)],
		[true, 1.0, 0.0, 0.0])
	var builds := Brains.get_odds_builds()
	Brains.get_odds()
	Brains.get_odds()
	var same_tick := Brains.get_odds_builds() - builds
	await _frames(5)
	_check("one shared read per tick (twice in one tick builds at most one; 5 ticks at most 5)", [same_tick <= 1, Brains.get_odds_builds() - builds <= 6], [true, true])
	for e in brutes + fodder + [elite]:
		e.queue_free()
	friend.queue_free()
	await _frames(2)


## The odds of `enemies` against `party`, the enemies fighting for the read
## only (one frame: nothing moves), then back to passive and idle.
func _odds_of(enemies: Array[Enemy], party: Array[Unit]) -> Dictionary:
	for e in enemies:
		e.passive = false
		e.ai = Enemy.AI.AGGRO
	var o := Brains.compute_odds(party, enemies)
	for e in enemies:
		e.passive = true
		e.ai = Enemy.AI.IDLE
	return o


func _test_ai3c_press_rules() -> void:
	_section("AI3c the press's rules (pure): respect × (1 − nerve × press), the shared push, the press pose")
	var t := Brains.table
	var b := BRUTE_BEHAVIOR.resolve({}, [] as Array[BrainAdjust])
	var calm := b.duplicate() as EnemyBehavior
	calm.nerve = 0.0
	var s := _situation(0.8, 0.0)
	var values: Array = [roundi(EnemyBrain.get_effective_respect(s, b) * 1000)]
	s.press = 0.5
	values.append(roundi(EnemyBrain.get_effective_respect(s, b) * 1000))
	values.append(roundi(EnemyBrain.get_effective_respect(s, calm) * 1000))
	s.press = 1.0
	values.append(roundi(EnemyBrain.get_effective_respect(s, b) * 1000))
	_check("respect 0.8: no press 0.8; press 0.5 at nerve 0.6: × 0.7 = 0.56; at nerve 0 unchanged; press 1: × 0.4 = 0.32",
		values, [800, 560, 800, 320])
	var p := _situation(0.5, 0.0)
	p.effective_respect = 0.5
	p.target_health_ratio = 1.0
	var base := EnemyBrain.get_patience_rate(p, b, t)
	var ratios: Array = []
	for row: Array in [[0.5, 1.0], [1.0, 1.0], [0.0, 0.3], [0.5, 0.3], [1.0, 0.3]]:
		p.press = row[0]
		p.target_health_ratio = row[1]
		ratios.append(roundi(EnemyBrain.get_patience_rate(p, b, t) / base * 100))
	_check("patience's push: press 0.5 → × 1.25, press 1 → × 1.5; low health alone × 1.5; both share one push (the larger): × 1.5, × 1.5",
		ratios, [125, 150, 150, 150, 150])
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var h := _situation(1.0, 0.0)
	h.press = 0.5
	var poses: Array = [EnemyBrain.decide(h, b, rng).pose, EnemyBrain.decide(h, SKIRMISHER_BEHAVIOR, rng).pose]
	h.cornered = true
	poses.append(EnemyBrain.decide(h, CASTER_BEHAVIOR, rng).pose)
	h.cornered = false
	h.press = 0.0
	poses.append(EnemyBrain.decide(h, b, rng).pose)
	_check("pressing, its hold shows `press` (a skirmisher's stalk too); cornered stays cornered; no press, hold",
		poses, [&"press", &"press", &"cornered", &"hold"])


## The pool +1 while pressing, never past the cap (a real fight's odds).
func _test_ai3c_tokens() -> void:
	_section("AI3c the pool: +1 token while three brutes press, never past the cap; one brute changes nothing")
	await _reset_knight()
	var t := Brains.table
	var one := _spawn(BRUTE_SCENE, knight.global_position + Vector2(150, 0), false)
	await _wait_until(func() -> bool: return one.ai == Enemy.AI.AGGRO, 30)
	await _frames(2)
	knight.health.heal(100000.0)
	await _frames(1)
	_check("one test brute on the Knight: odds 0.67, no press, 2 tokens", [roundi(float(Brains.get_odds().odds) * 100), Brains.get_press(), Brains.get_tokens_per_target()], [67, 0.0, 2])
	var more: Array[Enemy] = [one]
	for i in 2:
		more.append(_spawn(BRUTE_SCENE, knight.global_position + Vector2(-150, -80 + 160 * i), false))
	await _wait_until(func() -> bool: return more.all(func(e: Enemy) -> bool: return e.ai == Enemy.AI.AGGRO), 30)
	knight.health.heal(100000.0)
	await _frames(1)
	var press := Brains.get_press()
	_check("three test brutes: press 0.5 (Knight at full health), 3 tokens: a third attacker", [roundi(press * 100), Brains.get_tokens_per_target()], [50, 3])
	Brains.difficulty_tier = 4
	var at_four := Brains.get_tokens_per_target()
	t.tokens_per_target_cap = 3
	var at_cap := Brains.get_tokens_per_target()
	t.tokens_per_target_cap = 4
	Brains.difficulty_tier = 1
	t.odds_token_bonus = 5
	var big_bonus := Brains.get_tokens_per_target()
	t.odds_token_bonus = 1
	_check("tier 4 (3 tokens): 4, the cap; a cap of 3 leaves its 3; a bonus of 5 still adds 1 (+1 at most)", [at_four, at_cap, big_bonus], [4, 3, 3])
	for e in more:
		e.passive = true
		e.attack.cancel()
		e.queue_free()
	await _frames(30)
	_check("they're gone: no press, 2 tokens", [Brains.get_press(), Brains.get_tokens_per_target()], [0.0, 2])


## The weakest pick with the margin, taunt and stealth (a rooted brute: it
## stands, its pick runs).
func _test_ai3c_weakest_pick() -> void:
	_section("AI3c the weakest pick: × (0.5 + 0.5 × health) while pressing, with the margin, taunt and stealth")
	await _reset_knight()
	var t := Brains.table
	var saved := t.odds_threshold
	var spot := ARENA + Vector2(0, 600)
	var brute := _spawn(BRUTE_SCENE, spot, false)
	var root := _tag_status(&"test_root", [&"root"] as Array[StringName], true)
	brute.status_component.apply_status(root)
	_place(knight, spot + Vector2(210, 0))
	var friend := _friend(spot + Vector2(0, 240))
	await _frames(2)
	brute.alert(knight)
	brute.alert(friend)
	t.odds_threshold = 1000.0
	await _frames(12)
	knight.health.heal(100000.0)
	var no_press_target := brute.get_target()
	var plain := [roundi(brute.get_pick_distance(friend)), roundi(brute.get_effective_distance(friend))]
	t.odds_threshold = 0.0   # any fight presses (one brute: odds 0.6)
	friend.health.current = friend.health.max_health * 0.7
	await _frames(45)
	knight.health.heal(100000.0)
	var margin_target := brute.get_target()
	var at_70 := brute.get_pick_distance(friend) / brute.get_effective_distance(friend)
	friend.health.current = friend.health.max_health * 0.1
	await _frames(45)
	knight.health.heal(100000.0)
	var weak_target := brute.get_target()
	var at_10 := brute.get_pick_distance(friend) / brute.get_effective_distance(friend)
	_check("no press: it picks the nearer Knight (the friend's distance unchanged: %s)" % [plain], [no_press_target == knight, plain[0] == plain[1]], [true, true])
	_check("pressing, the friend at 70% counts × 0.85: inside the margin, it stays on the Knight", [margin_target == knight, roundi(at_70 * 100)], [true, 85])
	_check("at 10% it counts × 0.55: past the margin, it turns on the friend (after the hold)", [weak_target == friend, roundi(at_10 * 100)], [true, 55])
	var taunt := _tag_status(&"test_taunt", [&"taunt"] as Array[StringName])
	brute.status_component.apply_status(taunt, knight)
	await _frames(12)
	var taunted_target := brute.get_target()
	brute.status_component.remove_status(taunt.id)
	await _frames(45)
	var back_to_weak := brute.get_target()
	var stealth := _tag_status(&"test_stealth", [&"stealth"] as Array[StringName])
	friend.status_component.apply_status(stealth)
	await _frames(12)
	var stealth_target := brute.get_target()
	friend.status_component.remove_status(stealth.id)
	_check("a taunt still wins (the Knight); untaunted it turns back to the weak friend; the friend stealthed is dropped (the Knight)",
		[taunted_target == knight, back_to_weak == friend, stealth_target == knight], [true, true, true])
	var boss_data: EnemyData = BRUTE_DATA.duplicate()
	boss_data.rank = EnemyData.Rank.BOSS
	var boss := BRUTE_SCENE.instantiate() as Enemy
	boss.data = boss_data
	boss.passive = true
	entities.add_child(boss)
	_place(boss, spot + Vector2(-120, 0))
	await _frames(1)
	_check("a boss's pick never changes (bosses don't press)", is_equal_approx(boss.get_pick_distance(friend), boss.get_effective_distance(friend)), true)
	boss.status_component.apply_status(root)
	boss.passive = false
	boss.alert(knight)
	await _frames(1)
	var boss_s := boss.get_brain().build_situation()
	_check("its situation reads no press while the others press (%.2f)" % Brains.get_press(), [Brains.get_press() > 0.0, boss_s.has_target, boss_s.press], [true, true, 0.0])
	t.odds_threshold = saved
	for e: Node in [brute, friend, boss]:
		e.queue_free()
	await _reset_knight()
	await _frames(10)


func _test_ai3c_heavy_hits() -> void:
	_section("AI3c one heavy hit at a time while pressing: Brains' landing times, a brain's use refused")
	await _reset_knight()
	var t := Brains.table
	var saved := t.odds_threshold
	var spot := ARENA + Vector2(0, -600)
	_place(knight, spot)
	var brute := _spawn(BRUTE_SCENE, spot + Vector2(70, 0), true)
	var other := _spawn(BRUTE_SCENE, spot + Vector2(-400, 0), true)
	await _frames(2)
	var smash := EnemyBrain.is_heavy_hit(SMASH, brute, knight, t)
	var stab := EnemyBrain.is_heavy_hit(STAB, brute, knight, t)
	_check("heavy: the smash (%d = %d%% of the Knight's %d), not the stab (%d)" % [roundi(SMASH.get_damage_against(brute, knight)),
		roundi(SMASH.get_damage_against(brute, knight) / knight.health.max_health * 100), roundi(knight.health.max_health), roundi(STAB.get_damage_against(brute, knight))],
		[smash, stab], [true, false])
	_check("the smash lands its cast time (%.2f s) after it starts" % SMASH.get_param(brute, &"cast_time"),
		EnemyBrain.get_time_to_land(SMASH, brute, knight), SMASH.get_param(brute, &"cast_time"))
	var now := Brains.get_time()
	Brains.note_heavy_hit(other, knight, now + 0.5)
	t.odds_threshold = 1000.0
	var outside := Brains.can_land_heavy_hit(knight, now + 0.6)
	brute.passive = false
	brute.alert(knight)   # a fighting enemy, so the odds can press
	brute.status_component.apply_status(_tag_status(&"test_root", [&"root"] as Array[StringName], true))
	t.odds_threshold = 0.0
	await _frames(1)
	now = Brains.get_time()
	var lands: Array[float] = Brains.get_heavy_hits(knight)
	var at := lands[0] if not lands.is_empty() else now
	var answers := [Brains.can_land_heavy_hit(knight, at + 0.1), Brains.can_land_heavy_hit(knight, at - 0.79), Brains.can_land_heavy_hit(knight, at + 0.81),
		Brains.can_land_heavy_hit(knight, at + 0.1, true), Brains.can_land_heavy_hit(brute, at + 0.1)]
	_check("outside a press: allowed (AI2's rule)", outside, true)
	_check("pressing: 0.1 s and 0.79 s from another, refused; 0.81 s, allowed; a boss plan's (scripted), allowed; on another unit, allowed",
		answers, [false, false, true, true, true])
	# A real brain's smash use: refused while another heavy hit lands inside its window.
	var brain := brute.get_brain()
	brain.set("_patience", 1.0)
	var refused := _has_slot_use(brain.build_situation(), &"q")
	Brains.clear_heavy_hits(other)
	var allowed := _has_slot_use(brain.build_situation(), &"q")
	t.odds_threshold = 1000.0
	await _frames(1)   # the odds are read once a tick
	brain.set("_patience", 1.0)
	Brains.note_heavy_hit(other, knight, Brains.get_time() + _smash_land_time(brute))
	var no_press := _has_slot_use(brain.build_situation(), &"q")
	t.odds_threshold = 0.0
	_check("its smash use: refused inside another's window (it holds or swings); the other's cast cancelled, allowed; no press, allowed",
		[refused, allowed, no_press], [false, true, true])
	t.odds_threshold = saved
	Brains.clear_heavy_hits(other)
	for e in [brute, other]:
		e.passive = true
		e.attack.cancel()
		e.queue_free()
	await _reset_knight()
	await _frames(10)


func _smash_land_time(caster: Enemy) -> float:
	return EnemyBrain.get_time_to_land(SMASH, caster, knight)


func _has_slot_use(s: SituationContext, slot: StringName) -> bool:
	for u in s.uses:
		if u.slot == slot:
			return true
	return false


## Thinks per rank over 10 s (passive enemies: scheduled thinks only), then
## the budget scaling the awake brains' rates.
func _test_ai3c_think_rates() -> void:
	_section("AI3c think rates by rank: a regular 10, an elite 15, a duelist and a boss 25 a second; the budget")
	await _reset_knight()
	var t := Brains.table
	var duelist_data: EnemyData = BRUTE_DATA.duplicate()
	duelist_data.rank = EnemyData.Rank.ELITE
	duelist_data.duelist = true
	var boss_data: EnemyData = BRUTE_DATA.duplicate()
	boss_data.rank = EnemyData.Rank.BOSS
	# Around the Knight 8 m out (their homes inside the leash), passive while counted.
	var ring := func(i: int) -> Vector2: return knight.global_position + Vector2.from_angle(TAU * i / 4.0) * 260.0
	var regular := _spawn(BRUTE_SCENE, ring.call(0), true)
	var elite := _spawn(ELITE_SCENE, ring.call(1), true)
	var made: Array[Enemy] = []
	for d: EnemyData in [duelist_data, boss_data]:
		var e := BRUTE_SCENE.instantiate() as Enemy
		e.data = d
		e.passive = true
		entities.add_child(e)
		_place(e, ring.call(2 + made.size()))
		made.append(e)
	var all: Array[Enemy] = [regular, elite, made[0], made[1]]
	await _frames(1)
	var before: Array[int] = []
	for e in all:
		before.append(e.get_brain().scheduled_thinks)
	var reactions: Array = []
	for e in all:
		reactions.append(e.get_brain().behavior.reaction_time)
	await _frames(600)   # 10 s at 60 Hz
	var counts: Array = []
	for i in all.size():
		counts.append(all[i].get_brain().scheduled_thinks - before[i])
	_check("over 10 s: a regular 100, an elite 150, a duelist elite 250, a boss 250 (got %s)" % [counts],
		[absi(counts[0] - 100) <= 1, absi(counts[1] - 150) <= 1, absi(counts[2] - 250) <= 1, absi(counts[3] - 250) <= 1], [true, true, true, true])
	var expected_reactions := [0.455, 0.35, 0.35, 0.2975]
	var same := true
	for i in reactions.size():
		same = same and absf(float(reactions[i]) - float(expected_reactions[i])) < 0.0005
	_check("reaction times unchanged by the think rate: a regular's 0.455, an elite's 0.35, a duelist's 0.35, a boss's 0.2975 (got %s)" % [reactions], same, true)
	# The budget: awake brains (rooted, out of reach, on the Knight) ask 10 + 15 + 25 + 25 = 75 a second.
	var root := _tag_status(&"test_root", [&"root"] as Array[StringName], true)
	for e in all:
		e.status_component.apply_status(root)
		e.passive = false
		e.alert(knight)
	await _frames(5)
	var demand := Brains.get_think_demand()
	var free_rates: Array = []
	for e in all:
		free_rates.append(roundi(e.get_brain().get_think_rate()))
	var saved_budget := t.think_budget
	t.think_budget = 72.0
	await _frames(2)
	var scaled: Array = []
	for e in all:
		scaled.append(snappedf(e.get_brain().get_think_rate(), 0.01))
	var counts_before: Array[int] = []
	for e in all:
		counts_before.append(e.get_brain().scheduled_thinks)
	await _frames(360)   # 6 s
	var scaled_counts: Array = []
	for i in all.size():
		scaled_counts.append(all[i].get_brain().scheduled_thinks - counts_before[i])
	t.think_budget = 20.0
	await _frames(2)
	var floored: Array = []
	for e in all:
		floored.append(snappedf(e.get_brain().get_think_rate(), 0.01))
	t.think_budget = saved_budget
	_check("four awake brains ask 75 a second, under the budget: each at its own rate", [roundi(demand), free_rates], [75, [10, 15, 25, 25]])
	_check("exempt (Ryan): the elite and boss ranks, so the elite, the duelist elite and the boss; not the regular or fodder",
		[t.get_rank_rules(EnemyData.Rank.FODDER).think_budget_exempt, t.get_rank_rules(EnemyData.Rank.REGULAR).think_budget_exempt,
			t.get_rank_rules(EnemyData.Rank.ELITE).think_budget_exempt, t.get_rank_rules(EnemyData.Rank.BOSS).think_budget_exempt,
			all.map(func(e: Enemy) -> bool: return e.get_brain().is_budget_exempt())],
		[false, false, true, true, [false, true, true, true]])
	_check("a budget of 72: the exempt three's 65 come off the top, the regular gets the 7 left (7, 15, 25, 25)", scaled, [7.0, 15.0, 25.0, 25.0])
	_check("...and over 6 s they think about that often (got %s)" % [scaled_counts],
		[absi(scaled_counts[0] - 42) <= 2, absi(scaled_counts[1] - 90) <= 2, absi(scaled_counts[2] - 150) <= 2, absi(scaled_counts[3] - 150) <= 2], [true, true, true, true])
	_check("a budget of 20, under the exempt three's 65: the regular at the floor of 5, the exempt at their own rates (5, 15, 25, 25)", floored, [5.0, 15.0, 25.0, 25.0])
	for e in all:
		e.passive = true
		e.attack.cancel()
		e.queue_free()
	await _reset_knight()
	await _frames(10)


## A gap-closer's follow-up never waits a reaction time (it isn't a reaction
## to the party): a brute with a leap lands beside the Knight and swings.
func _test_ai3c_follow_up() -> void:
	_section("AI3c a gap-closer's follow-up: the swing starts within a think of landing, not after a reaction time")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	_spend_kit()
	var leaper: EnemyData = BRUTE_DATA.duplicate()
	var slot := EnemyAbilitySlot.new()
	slot.slot = &"w"
	slot.ability = LEAP
	leaper.abilities = [BRUTE_DATA.abilities[0], slot]
	var brute := BRUTE_SCENE.instantiate() as Enemy
	brute.data = leaper
	entities.add_child(brute)
	_place(brute, knight.global_position + Vector2(170, 0))
	_pin_ai3(brute)
	var leaps := [0]
	brute.abilities.cast_started.connect(func(s: StringName, _a: Ability, _c: CastContext) -> void:
		if s == &"w":
			leaps[0] += 1)
	await _wait_until(func() -> bool: return leaps[0] > 0, 600)
	await _wait_until(func() -> bool: return not brute.abilities.casting and not brute.movement.is_leaping(), 90)
	var landed := Brains.get_time()
	await _wait_until(func() -> bool: return brute.attack.is_winding_up() or brute.abilities.casting, 60)
	var follow := Brains.get_time() - landed
	var reaction := brute.get_brain().behavior.reaction_time
	_check("it leapt and swung %.2f s after landing (its reaction time %.2f s)" % [follow, reaction], [leaps[0] >= 1, follow < reaction - 0.1], [true, true])
	brute.passive = true
	brute.attack.cancel()
	brute.queue_free()
	await _reset_knight()
	await _frames(30)


## The step's "Done means": three test brutes and an elite press (a third
## attacker, the amber lean), never two heavy hits within 0.8 s; one brute
## changes nothing; with the ally down they turn on the Knight.
func _test_ai3c_pack_presses() -> void:
	_section("AI3c three test brutes and an elite press: a third attacker, the press pose, one heavy hit at a time")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	_spend_kit()
	var t := Brains.table
	var steady := _tag_status(&"test_unstoppable", [&"unstoppable"] as Array[StringName])
	knight.status_component.apply_status(steady)
	var pack: Array[Enemy] = []
	for i in 3:
		pack.append(_spawn(BRUTE_SCENE, knight.global_position + Vector2.from_angle(TAU * i / 4.0) * 150.0, false))
	pack.append(_spawn(ELITE_SCENE, knight.global_position + Vector2.from_angle(TAU * 0.75) * 150.0, false))
	var heavy: Array = []   # [game time, source, ability]
	var on_damaged := func(ctx: HitContext) -> void:
		if ctx.target == knight and ctx.ability != null and ctx.source is Enemy \
				and EnemyBrain.is_heavy_hit(ctx.ability, ctx.source, knight, t):
			heavy.append([Brains.get_time(), ctx.source, ctx.ability])
	Events.unit_damaged.connect(on_damaged)
	var max_used := 0
	var min_press := 1.0
	var poses := {}
	var frames := 0
	while frames < 900:   # 15 s
		await get_tree().physics_frame
		frames += 1
		knight.health.heal(100000.0)
		if frames % 30 == 0:
			_spend_kit()
		if frames > 30:
			min_press = minf(min_press, Brains.get_press())
		max_used = maxi(max_used, Brains.get_tokens_per_target() - Brains.get_tokens_free(knight))
		for e in pack:
			if e.get_brain() != null:
				poses[e.get_brain().get_pose()] = true
	Events.unit_damaged.disconnect(on_damaged)
	knight.status_component.remove_status(steady.id)
	var min_gap := INF
	var casts := 0
	for i in heavy.size():
		if i > 0 and heavy[i][1] == heavy[i - 1][1] and heavy[i][2] == heavy[i - 1][2] and float(heavy[i][0]) - float(heavy[i - 1][0]) < 0.5:
			continue   # one cast's second hit
		casts += 1
		if i > 0:
			min_gap = minf(min_gap, float(heavy[i][0]) - float(heavy[i - 1][0]))
	_check("they pressed the whole fight (the lowest press %.2f), with 3 tokens in use at once: a third attacker" % min_press, [min_press > 0.0, max_used], [true, 3])
	_check("the press pose showed (poses seen: %s)" % [poses.keys()], poses.has(&"press"), true)
	_check("heavy hits landed (%d casts) and never two within 0.8 s (the closest %.2f s)" % [casts, min_gap], [casts >= 2, min_gap >= t.heavy_hit_window - 0.05], [true, true])
	for e in pack:
		e.passive = true
		e.attack.cancel()
		e.queue_free()
	await _frames(30)
	# One brute: nothing changes.
	await _reset_knight()
	var lone := _spawn(BRUTE_SCENE, knight.global_position + Vector2(150, 0), false)
	await _wait_until(func() -> bool: return lone.get_brain().get_intent() != &"", 60)
	await _frames(6)
	var s := lone.get_brain().get_situation()
	_check("one test brute: no press, its respect as before (× 1), the hold pose, 2 tokens",
		[s.press, is_equal_approx(s.effective_respect, clampf(s.respect * lone.get_brain().behavior.respect_weight * (1.0 - lone.get_brain().behavior.confidence * s.own_ready_share), 0.0, 1.0)),
			lone.get_brain().get_pose(), Brains.get_tokens_per_target()], [0.0, true, &"hold", 2])
	# The ally down: they turn on the Knight.
	var friend := _friend(lone.global_position + Vector2(40, 0))
	lone.alert(friend)
	await _wait_until(func() -> bool:
		friend.health.heal(100000.0)   # its swings mustn't kill the stand-in first
		return lone.get_target() == friend, 60)
	var on_friend := lone.get_target() == friend
	friend.health.heal(100000.0)
	knight.health.heal(100000.0)
	await _frames(1)
	var party_before := float(Brains.get_odds().party)
	var downed := _tag_status(&"test_downed", [&"downed"] as Array[StringName])
	friend.status_component.apply_status(downed)
	await _frames(3)
	_check("the ally nearer, it fights the ally; the ally down, it turns on the Knight and the party's strength drops (%.2f → %.2f)" % [party_before, float(Brains.get_odds().party)],
		[on_friend, lone.get_target() == knight, float(Brains.get_odds().party) < party_before], [true, true, true])
	lone.passive = true
	lone.attack.cancel()
	lone.queue_free()
	friend.queue_free()
	await _reset_knight()
	await _frames(30)


func _test_ai3c_overlay() -> void:
	_section("AI3c the overlay: its odds line, its think rate")
	var t := Brains.table
	var saved := t.odds_threshold
	await _reset_knight()
	var brute := _spawn(BRUTE_SCENE, knight.global_position + Vector2(150, 0), false)
	await _wait_until(func() -> bool: return brute.get_brain().get_intent() != &"", 60)
	var sb := SandboxBrains.new()
	var calm := sb.get_duel_text(brute)
	var token_line := sb.get_overlay_text(brute)
	t.odds_threshold = 0.0
	await _frames(8)
	var pressing := sb.get_duel_text(brute)
	t.odds_threshold = saved
	_check("no press: `odds 0.7`; pressing: `odds 0.7, press 0.7 (nerve 0.6)`; the token line ends in its rate `10/s`",
		[calm.contains("odds 0.7"), pressing.contains("odds 0.7, press 0.7 (nerve 0.6)"), token_line.contains("µs  10/s")], [true, true, true])
	sb.free()
	brute.passive = true
	brute.attack.cancel()
	brute.queue_free()
	await _frames(10)


# --- TEMP: the enemy attack speed test multiplier (DECISIONS.md, Testing) --------------------

func _test_temp_attack_speed() -> void:
	_section("TEMP: the enemy attack speed test multiplier (one switch, off by default)")
	await _reset_knight()
	_check("off by default: x1.0, keep DPS on, the windup floor 0.25 s",
		[AutoAttackComponent.enemy_attack_speed_test_mult, AutoAttackComponent.enemy_attack_test_keep_dps,
			AutoAttackComponent.enemy_attack_test_min_windup], [1.0, true, 0.25])
	# Two attackers on the Knight (a slime: today's windup is 0.25 s, the floor;
	# the caster: 0.6 s), the ally stand-in on a dummy, three bystanders.
	var slime := _spawn(SLIME_SCENE, ARENA, true)
	var caster := _spawn(CASTER_SCENE, ARENA, true)
	var brute := _spawn(BRUTE_SCENE, ARENA + Vector2(0, 400), true)
	var elite := _spawn(ELITE_SCENE, ARENA + Vector2(0, -400), true)
	var bare := SLIME_SCENE.instantiate() as Enemy   # no data: the old routine
	bare.data = null
	bare.passive = true
	entities.add_child(bare)
	_place(bare, ARENA + Vector2(400, 400))
	var friend := _friend(ARENA + Vector2(-400, 400))
	var dummy := _spawn(SLIME_SCENE, ARENA, true)
	await _frames(1)
	_place(slime, ARENA + Vector2(_temp_reach(knight, slime), 0))
	_place(caster, ARENA - Vector2(_temp_reach(knight, caster), 0))
	_place(dummy, friend.global_position + Vector2(_temp_reach(friend, dummy), 0))
	for u: Enemy in [slime, caster, friend]:
		u.attack.hit_knockback_px = 0.0   # the target stays in reach: the rhythm only
	await _frames(2)
	var enemies: Array[Enemy] = [slime, caster, brute, elite, bare]
	_check("the bystanders: brained (the brute, the elite) and with no data", [brute.get_brain() != null, elite.get_brain() != null, bare.data == null], [true, true, true])

	# x1.0: today's numbers, exactly.
	var today := {}
	var exact := true
	for e in enemies:
		var base := e.stats.base_attack_speed
		today[e] = [e.attack.get_attack_speed(), e.attack.get_attack_interval(), e.attack.get_windup_time(), e.attack.make_attack_context(knight).ad_ratio]
		exact = exact and today[e] == [base, 1.0 / base, (1.0 / base) * e.stats.attack_windup, 1.0] \
			and e.attack.get_temp_test_mult() == 1.0 and e.stats_component.get_modifiers_from(AutoAttackComponent.TEMP_TEST_SPEED_SOURCE).is_empty()
	_check("x1.0: every enemy's attack speed, interval, windup and hit are today's exactly (no modifier)", exact, true)
	var knight_today := [knight.attack.get_attack_speed(), knight.attack.get_swing_speed()]
	var friend_today := [friend.attack.get_attack_speed(), friend.attack.get_windup_time(), friend.attack.make_attack_context(dummy).ad_ratio]
	var run_1 := await _temp_run([slime, caster, friend], [knight, knight, dummy], 10.0)
	knight.health.heal(100000.0)
	dummy.health.heal(100000.0)

	# x1.5, keep DPS.
	AutoAttackComponent.enemy_attack_speed_test_mult = 1.5
	await _frames(1)
	var sped := true
	for e in enemies:
		sped = sped and e.attack.get_temp_test_mult() == 1.5 and is_equal_approx(e.attack.get_attack_speed(), e.stats.base_attack_speed * 1.5) \
			and e.stats_component.get_modifiers_from(AutoAttackComponent.TEMP_TEST_SPEED_SOURCE).size() == 1
	_check("x1.5: every enemy-team attacker (fodder, brained, no data) attacks 1.5x as often", sped, true)
	_check("its hits are lighter: ad_ratio 1 / 1.5", slime.attack.make_attack_context(knight).ad_ratio, 1.0 / 1.5)
	_check("the windup floor: the slime's stays 0.25 s (today's; x1.5 alone would give 0.167), the caster's 0.6 s scales to 0.4 s",
		[snappedf(slime.attack.get_windup_time(), 0.0001), snappedf(caster.attack.get_windup_time(), 0.0001)], [0.25, 0.4])
	_check("the player: no modifier, the same attack speed and swing speed",
		[knight.attack.get_temp_test_mult(), knight.attack.get_attack_speed(), knight.attack.get_swing_speed()], [1.0] + knight_today)
	_check("the ally (on the player's team since the frame it spawned): never touched",
		[friend.attack.get_temp_test_mult(), friend.attack.get_attack_speed(), friend.attack.get_windup_time(), friend.attack.make_attack_context(dummy).ad_ratio],
		[1.0] + friend_today)
	var run_15 := await _temp_run([slime, caster, friend], [knight, knight, dummy], 10.0)
	knight.health.heal(100000.0)
	for i in 2:
		var who := ["slime", "caster"][i] as String
		var a: Dictionary = run_1[i]
		var b: Dictionary = run_15[i]
		var ratio := _temp_dps(b.hits) / maxf(_temp_dps(a.hits), 0.001)
		_check("%s: the same damage per second over 10 s, within 2%% (x1.5 / x1.0 = %.4f)" % [who, ratio], absf(ratio - 1.0) <= 0.02, true)
		var rate := _temp_cycle(a.hits) / maxf(_temp_cycle(b.hits), 0.001)
		_check("%s: more swings (%d → %d in 10 s; one every %.1f → %.1f frames)" % [who, a.hits.size(), b.hits.size(), _temp_cycle(a.hits), _temp_cycle(b.hits)],
			b.hits.size() > a.hits.size() and rate > 1.4, true)
	var floor_frames := ceili(0.25 * Engine.physics_ticks_per_second - 0.001)
	var slime_windups := _temp_windup_frames(run_15[0])
	_check("the slime's windups at x1.5: each signalled at 0.25 s or more and lasting %d+ frames (got %s)" % [floor_frames, slime_windups],
		not slime_windups.is_empty() and slime_windups.min() >= floor_frames and (run_15[0].windups as Array).all(func(w: Array) -> bool: return w[1] >= 0.25 - 0.000001), true)
	_check("the caster's windups at x1.5: shorter than at x1.0 (%s → %s frames)" % [_temp_windup_frames(run_1[1]), _temp_windup_frames(run_15[1])],
		_temp_windup_frames(run_15[1]).max() < _temp_windup_frames(run_1[1]).min(), true)
	var f1: Dictionary = run_1[2]
	var f15: Dictionary = run_15[2]
	_check("the ally's swings: the same rhythm and damage at x1.5 as at x1.0",
		[_temp_gaps(f15.hits), f15.hits.map(func(h: Array) -> float: return h[1])],
		[_temp_gaps(f1.hits), f1.hits.map(func(h: Array) -> float: return h[1])])

	# Keep DPS off, a higher floor, the cap of the floor, the limits.
	AutoAttackComponent.enemy_attack_test_keep_dps = false
	_check("keep DPS off: full hits (damage per second rises 1.5x)", slime.attack.make_attack_context(knight).ad_ratio, 1.0)
	AutoAttackComponent.enemy_attack_test_keep_dps = true
	AutoAttackComponent.enemy_attack_test_min_windup = 0.3
	_check("a floor above today's windup never lengthens it (the slime keeps 0.25 s; the caster's 0.4 s is over it)",
		[snappedf(slime.attack.get_windup_time(), 0.0001), snappedf(caster.attack.get_windup_time(), 0.0001)], [0.25, 0.4])
	AutoAttackComponent.enemy_attack_test_min_windup = 0.25
	AutoAttackComponent.enemy_attack_speed_test_mult = 3.0
	await _frames(1)
	_check("x3: the slime's windup holds at 0.25 s; the recovery takes the rest (1 / 2.1 − 0.25 s)",
		[snappedf(slime.attack.get_windup_time(), 0.0001), snappedf(slime.attack.get_attack_interval() - slime.attack.get_windup_time(), 0.0001)],
		[0.25, snappedf(1.0 / 2.1 - 0.25, 0.0001)])
	AutoAttackComponent.enemy_attack_speed_test_mult = 5.0
	await _frames(1)
	var high := slime.attack.get_temp_test_mult()
	AutoAttackComponent.enemy_attack_speed_test_mult = 0.1
	await _frames(1)
	_check("its limits: 0.5 to 3", [high, slime.attack.get_temp_test_mult()], [3.0, 0.5])

	# Back to x1.0: today's numbers again, exactly.
	AutoAttackComponent.enemy_attack_speed_test_mult = 1.0
	await _frames(1)
	var back := true
	for e in enemies:
		back = back and [e.attack.get_attack_speed(), e.attack.get_attack_interval(), e.attack.get_windup_time(), e.attack.make_attack_context(knight).ad_ratio] == today[e] \
			and e.stats_component.get_modifiers_from(AutoAttackComponent.TEMP_TEST_SPEED_SOURCE).is_empty()
	_check("a live change back to x1.0: the modifier gone, every number today's exactly", back, true)

	# SandboxBrains: the sandboxes start at x1.5; never applied in a test scene; the panel's row; put back on leaving.
	var starts: Array = []
	for path in ["res://scenes/rooms/sandbox.tscn", "res://scenes/rooms/sandbox_3d.tscn"]:
		var room := (load(path) as PackedScene).instantiate()
		var node := room.find_child("SandboxBrains", true, false) as SandboxBrains
		starts.append(node.enemy_attack_speed_test_mult if node != null else -1.0)
		room.free()
	var sb := SandboxBrains.new()
	_check("sandbox.tscn and sandbox_3d.tscn start at x1.5; the class default is x1.0", [starts, sb.enemy_attack_speed_test_mult], [[1.5, 1.5], 1.0])
	sb.enemy_attack_speed_test_mult = 1.5
	add_child(sb)
	await _frames(1)
	_check("a test scene never takes the sandbox's starting value", AutoAttackComponent.enemy_attack_speed_test_mult, 1.0)
	sb.set_panel(true)
	sb._temp_slider.value = 1.25
	var from_slider := AutoAttackComponent.enemy_attack_speed_test_mult
	sb._temp_keep_dps.button_pressed = false
	var keep_after := AutoAttackComponent.enemy_attack_test_keep_dps
	sb.set_enemy_attack_test(9.0, true)
	_check("N's TEMP row: the slider and keep DPS set it live; clamped to 3", [from_slider, keep_after, AutoAttackComponent.enemy_attack_speed_test_mult], [1.25, false, 3.0])
	sb.set_panel(false)
	sb.queue_free()
	await _frames(2)
	_check("leaving the sandbox puts it back (x1.0, keep DPS on, the floor 0.25 s)",
		[AutoAttackComponent.enemy_attack_speed_test_mult, AutoAttackComponent.enemy_attack_test_keep_dps,
			AutoAttackComponent.enemy_attack_test_min_windup], [1.0, true, 0.25])

	AutoAttackComponent.enemy_attack_speed_test_mult = 1.0
	AutoAttackComponent.enemy_attack_test_keep_dps = true
	AutoAttackComponent.enemy_attack_test_min_windup = 0.25
	for u: Node in [slime, caster, brute, elite, bare, friend, dummy]:
		u.queue_free()
	await _frames(2)


## TEMP: where `attacker` stands to reach `target` without walking (its
## edge at half its range), px from the target's center.
func _temp_reach(target: Unit, attacker: Unit) -> float:
	return target.get_gameplay_radius_px() + attacker.get_gameplay_radius_px() + attacker.attack.get_range_px() * 0.5


## TEMP: each attacker attacks its target for `seconds` of physics frames.
## Per attacker: {hits: [[frame, damage], ...], windups: [[frame, windup s], ...]}.
func _temp_run(attackers: Array, targets: Array, seconds: float) -> Array:
	var frame := [0]
	var out: Array = []
	var links: Array = []
	for i in attackers.size():
		var a: Unit = attackers[i]
		var entry := {"hits": [], "windups": []}
		out.append(entry)
		var on_landed := func(_t: Unit, damage: float) -> void: (entry.hits as Array).append([frame[0], damage])
		var on_windup := func(_t: Unit, time: float) -> void: (entry.windups as Array).append([frame[0], time])
		a.attack.attack_landed.connect(on_landed)
		a.attack.windup_started.connect(on_windup)
		links.append([a, on_landed, on_windup])
		a.attack.attack(targets[i])
	for f in roundi(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
		frame[0] += 1
	for link: Array in links:
		var a: Unit = link[0]
		a.attack.cancel()
		a.attack.attack_landed.disconnect(link[1])
		a.attack.windup_started.disconnect(link[2])
	return out


## TEMP: damage per second, steady: the damage after the first hit ÷ the time
## from the first hit to the last.
func _temp_dps(hits: Array) -> float:
	if hits.size() < 2:
		return 0.0
	var total := 0.0
	for i in range(1, hits.size()):
		total += float(hits[i][1])
	return total / (float(hits[-1][0] - hits[0][0]) / Engine.physics_ticks_per_second)


## TEMP: frames per swing (first hit to last ÷ the swings between).
func _temp_cycle(hits: Array) -> float:
	return float(hits[-1][0] - hits[0][0]) / (hits.size() - 1) if hits.size() >= 2 else 0.0


## TEMP: the frames between consecutive hits.
func _temp_gaps(hits: Array) -> Array:
	var out: Array = []
	for i in range(1, hits.size()):
		out.append(int(hits[i][0]) - int(hits[i - 1][0]))
	return out


## TEMP: each landed hit's frames since its windup started.
func _temp_windup_frames(entry: Dictionary) -> Array:
	var out: Array = []
	var windups: Array = entry.windups
	var hits: Array = entry.hits
	for i in mini(windups.size(), hits.size()):
		out.append(int(hits[i][0]) - int(windups[i][0]))
	return out


# --- AI-D1: the test duelist, crowding and the opening (Combos) --------------------------

func _test_aid1_data() -> void:
	_section("AI-D1 data: the two sliders, the table's reads, peel, the condition kinds, the recover pose, the duelist")
	_check("peel_threshold 0.1–1 and opening_bar 0–1, after nerve in the panel's list (AI-D2's three come after them)",
		[EnemyBehavior.LIMITS[&"peel_threshold"], EnemyBehavior.LIMITS[&"opening_bar"], EnemyBehavior.SLIDERS.slice(18, 20)],
		[[0.1, 1.0], [0.0, 1.0], [&"peel_threshold", &"opening_bar"]])
	_check("the role starts: brute .6 / .5, skirmisher .6 / .4, caster .5 / .6",
		[BRUTE_BEHAVIOR.peel_threshold, BRUTE_BEHAVIOR.opening_bar, SKIRMISHER_BEHAVIOR.peel_threshold, SKIRMISHER_BEHAVIOR.opening_bar,
			CASTER_BEHAVIOR.peel_threshold, CASTER_BEHAVIOR.opening_bar], [0.6, 0.5, 0.6, 0.4, 0.5, 0.6])
	var regular := Brains.table.get_rank_rules(EnemyData.Rank.REGULAR).brain_adjust
	_check("a BrainAdjust leaves both at × 1; resolve() carries them, an override included",
		[BrainAdjust.new().get_multiplier(&"peel_threshold"), BrainAdjust.new().get_multiplier(&"opening_bar"),
			BRUTE_BEHAVIOR.resolve({&"opening_bar": 0.3}, [regular] as Array[BrainAdjust]).opening_bar,
			BRUTE_BEHAVIOR.resolve({}, [regular] as Array[BrainAdjust]).peel_threshold], [1.0, 1.0, 0.3, 0.6])
	var t := Brains.table
	var cw := t.crowding_weights
	_check("crowding: near .6, closing .15, a gap-closer in .3, hits .3 (the ally's cc .4); closing full at 400 u/s, a gap-closer within 1 s, hits over 3 s ÷ 3",
		[cw[&"near"], cw[&"closing"], cw[&"gap_closer"], cw[&"hits"], cw[&"cc"], t.crowding_closing_full, t.crowding_recent_time, t.crowding_hit_window, t.crowding_hits_full],
		[0.6, 0.15, 0.3, 0.3, 0.4, 400.0, 1.0, 3.0, 3])
	var ow := t.opening_weights
	_check("the opening: escapes .5, cc by another .5, recovering .4, committed .4, cornered .2; a crowd control with 0.5 s left; a wall within 48 px (1.5 m)",
		[ow[&"escapes_down"], ow[&"cc_by_other"], ow[&"recovering"], ow[&"committed"], ow[&"cornered"], t.opening_cc_min_left, t.cornered_check_px, Units.px_to_m(t.cornered_check_px)],
		[0.5, 0.5, 0.4, 0.4, 0.2, 0.5, 48.0, 1.5])
	_check("major tags: ultimate, charge_up, dash, leap; peel scores 0.9 (like defend); `peel` is an intent tag",
		[t.major_tags, t.intent_scores[&"peel"], AIUse.INTENT_TAGS.has(&"peel")], [[&"ultimate", &"charge_up", &"dash", &"leap"], 0.9, true])
	var kinds: Array = []
	for k: Condition.Kind in [Condition.Kind.CROWDING, Condition.Kind.OPENING, Condition.Kind.TARGET_ESCAPES_READY, Condition.Kind.TARGET_CORNERED]:
		var c := Condition.new()
		c.kind = k
		var negated := Condition.new()
		negated.kind = k
		negated.negate = true
		kinds.append([c.is_situation_kind(), c.is_met(knight, knight), negated.is_met(knight, knight)])
	_check("CROWDING, OPENING, TARGET_ESCAPES_READY, TARGET_CORNERED read the situation: without one, false even negated", kinds,
		[[true, false, false], [true, false, false], [true, false, false], [true, false, false]])
	var s := SituationContext.new()
	s.has_target = true
	s.crowding = 0.7
	s.opening = 0.4
	s.target_escapes_ready = 1
	s.target_cornered = true
	var crowd := Condition.new()
	crowd.kind = Condition.Kind.CROWDING
	crowd.value = 0.6
	var open := Condition.new()
	open.kind = Condition.Kind.OPENING
	open.value = 0.5
	var one := Condition.new()
	one.kind = Condition.Kind.TARGET_ESCAPES_READY
	var two := Condition.new()
	two.kind = Condition.Kind.TARGET_ESCAPES_READY
	two.count = 2
	var corner := Condition.new()
	corner.kind = Condition.Kind.TARGET_CORNERED
	_check("with one: crowding 0.7 ≥ 0.6 yes, opening 0.4 ≥ 0.5 no, one escape ready (at least 1 yes, 2 no), cornered yes",
		[crowd.is_met(knight, null, null, s), open.is_met(knight, null, null, s), one.is_met(knight, null, null, s), two.is_met(knight, null, null, s),
			corner.is_met(knight, null, null, s)], [true, false, true, false, true])
	var recover := POSE_SET.get_look(&"recover")
	_check("the recover pose: slumped back 10°, squashed to 0.9, no rim",
		[recover != null, recover.lean_deg if recover != null else 0.0, recover.squash if recover != null else 0.0, recover.rim_color.a if recover != null else -1.0],
		[true, -10.0, 0.9, 0.0])

	var d := DUELIST_DATA
	var slots: Array = []
	for entry in d.abilities:
		slots.append([entry.slot, entry.ability])
	var overrides := {}
	for slider: StringName in d.overrides:
		overrides[slider] = d.overrides[slider]
	_check("the test duelist: an elite brute flagged duelist (25 thinks a second), four abilities on q w e r; its overrides (Ryan's tuning pass, 2026-10-07; AI-D2 combo_greed and mixup): aggression .9, combo_greed .2, confidence .65, crowded_commit .55, mixup .3, opening_bar .4, peel_threshold .5, punish_greed .75, reaction .3",
		[d.rank, d.duelist, d.behavior == BRUTE_BEHAVIOR, t.get_think_rate_for(d), overrides, slots],
		[EnemyData.Rank.ELITE, true, true, 25.0, {&"aggression": 0.9, &"combo_greed": 0.2, &"confidence": 0.65, &"crowded_commit": 0.55, &"mixup": 0.3, &"opening_bar": 0.4,
			&"peel_threshold": 0.5, &"punish_greed": 0.75, &"reaction_time": 0.3}, [[&"q", D_SNARE], [&"w", D_GUARD], [&"e", D_STRIKE], [&"r", D_FINISHER]]])
	var st := d.stats
	_check("its stats (the tuning pass): 2800 health, 30 armor, 36 attack damage (5.5% of the Knight's 650), 0.8 attack speed, 320 move speed, 150 u range, radius 55",
		[st.max_health, st.armor, st.attack_damage, st.base_attack_speed, st.move_speed, st.attack_range, st.gameplay_radius], [2800.0, 30.0, 36.0, 0.8, 320.0, 150.0, 55.0])
	var values := [t.get_respect_value(D_SNARE), t.get_respect_value(D_GUARD), t.get_respect_value(D_STRIKE), t.get_respect_value(D_FINISHER)]
	_check("respect: snare 3 (core 2 + its root), guard 1.5, strike 2, finisher 4: 10.5, the Knight's too",
		[values, values[0] + values[1] + values[2] + values[3]], [[3.0, 1.5, 2.0, 4.0], 10.5])
	_check("its uses: snare peel and cc; guard two defends; strike gap-close and damage; finisher damage, punish, finish",
		[_intents(D_SNARE), _intents(D_GUARD), _intents(D_STRIKE), _intents(D_FINISHER)],
		[[&"peel", &"cc"], [&"defend", &"defend"], [&"gap_close", &"damage"], [&"damage", &"punish", &"finish"]])
	var peel_rule: Condition = D_SNARE.ai_uses[0].conditions[0]
	_check("the snare's peel rule: its target within 400 u", [peel_rule.kind, peel_rule.comparison, peel_rule.value], [Condition.Kind.TARGET_DISTANCE, Condition.Comparison.LESS_THAN, 400.0])
	_check("combo roles: the snare opener + extender, the strike extender (the tuning pass: fast now, so no opener), finisher finisher, guard none; only the finisher recovers (1.2 s)",
		[D_SNARE.combo_roles, D_STRIKE.combo_roles, D_FINISHER.combo_roles, D_GUARD.combo_roles.is_empty(), D_FINISHER.recovery_time, D_SNARE.recovery_time, D_STRIKE.recovery_time],
		[[&"opener", &"extender"], [&"extender"], [&"finisher"], true, 1.2, 0.0, 0.0])
	_check("its opener (the snare) telegraphs 0.7 s and can be dodged (not point-and-click); its strike is fast (Ryan's tuning pass): 0.3 s; its finisher 0.9 s (a perilous move since ARCHETYPES AR2, was 0.35)",
		[D_SNARE.cast_time, D_STRIKE.cast_time, D_FINISHER.cast_time, D_SNARE.targeting != Ability.Targeting.UNIT, D_STRIKE.targeting != Ability.Targeting.UNIT],
		[0.7, 0.3, 0.9, true, true])
	_check("numbers: snare 750 u at 700 u/s, 60 wide, 60 magic (9.2% of 650: under the 10% heavy hit), 10 s; guard 250 for 2 s, 8 s; strike 100 (15.4%), reaching 6 m (the charge's range: from its band's far edge), its band 5 m + 1 m past, 7 s; finisher 240 (36.9%: a perilous move since ARCHETYPES AR2, was 195), an 80 px circle around itself, 12 s",
		[D_SNARE.cast_range, D_SNARE.projectile_speed, D_SNARE.projectile_width, D_SNARE.base_damage, D_SNARE.cooldown,
			D_GUARD.get(&"shield_amount"), D_GUARD.get(&"shield_duration"), D_GUARD.cooldown,
			D_STRIKE.base_damage, D_STRIKE.cast_range, D_STRIKE.get(&"length_px"), D_STRIKE.get(&"overshoot_px"), D_STRIKE.cooldown,
			D_FINISHER.base_damage, D_FINISHER.get(&"radius_px"), D_FINISHER.cooldown],
		[750.0, 700.0, 60.0, 60.0, 10.0, 250.0, 2.0, 8.0, 100.0, 600.0, 192.0, 32.0, 7.0, 240.0, 80.0, 12.0])


## A situation for crowding by hand: a brute's crowded range (200 u) and band
## (350–500 u), its target `edge_units` away.
func _crowd_situation(edge_units: float) -> SituationContext:
	var t := Brains.table
	var s := SituationContext.new()
	s.has_target = true
	s.target_edge_distance_px = Units.to_px(edge_units)
	s.crowded_range_px = Units.to_px(200.0)
	s.band_min_px = Units.to_px(350.0)
	s.band_max_px = Units.to_px(500.0)
	s.crowding_closing_full_px = Units.to_px(t.crowding_closing_full)
	s.crowding_hits_full = t.crowding_hits_full
	return s


func _test_aid1_crowding() -> void:
	_section("Crowding's terms by hand (ComboPlanner.get_crowding()): near, closing, a gap-closer in, hits")
	var w := Brains.table.crowding_weights
	var near: Array = []
	for edge: float in [150.0, 200.0, 275.0, 300.0, 350.0, 450.0]:
		near.append(roundi(ComboPlanner.get_crowding(_crowd_situation(edge), w) * 1000))
	_check("near alone (× 1,000): inside its 200 u 600, at its edge 600, 2.75 m 300, 1 m outside (3 m) 200, its band's minimum 0, past it 0",
		near, [600, 600, 300, 200, 0, 0])
	var s := _crowd_situation(300.0)
	s.target_closing_px = Units.to_px(400.0)
	var walking := ComboPlanner.get_crowding(s, w)
	s.target_closing_px = Units.to_px(200.0)
	var half := ComboPlanner.get_crowding(s, w)
	var far := _crowd_situation(600.0)
	far.target_closing_px = Units.to_px(400.0)
	_check("closing at 3 m: walking in at 400 u/s adds 0.15, at half speed 0.075; beyond its band's far edge nothing",
		[roundi(walking * 1000), roundi(half * 1000), roundi(ComboPlanner.get_crowding(far, w) * 1000)], [350, 275, 0])
	var lunge := _crowd_situation(275.0)
	lunge.target_gap_closer_in = true
	var hits: Array = []
	for n: int in [1, 3, 6]:
		var h := _crowd_situation(250.0)
		h.recent_hits = n
		hits.append(roundi(ComboPlanner.get_crowding(h, w) * 1000))
	_check("a Lunge in to 2.75 m: 0.3 + 0.3 = 0.6; at 2.5 m (near 0.4) one hit 0.5, three 0.7, six still 0.7",
		[roundi(ComboPlanner.get_crowding(lunge, w) * 1000), hits], [600, [500, 700, 700]])
	var all := _crowd_situation(100.0)
	all.target_closing_px = Units.to_px(400.0)
	all.target_gap_closer_in = true
	all.recent_hits = 3
	var terms := {}
	var total := ComboPlanner.get_crowding(all, w, terms)
	_check("everything: 1.35 clamped to 1; its terms near .6, closing .15, gap-closer .3, hits .3; the biggest near",
		[total, terms, ComboPlanner.get_biggest_term(terms)[0]], [1.0, {&"near": 0.6, &"closing": 0.15, &"gap_closer": 0.3, &"hits": 0.3}, &"near"])
	var caster := _crowd_situation(500.0)
	caster.crowded_range_px = Units.to_px(550.0)
	caster.band_min_px = Units.to_px(550.0)
	var out := _crowd_situation(560.0)
	out.crowded_range_px = Units.to_px(550.0)
	out.band_min_px = Units.to_px(550.0)
	_check("a caster (its crowded range its band's minimum): 1 or 0", [roundi(ComboPlanner.get_crowding(caster, w) * 1000), roundi(ComboPlanner.get_crowding(out, w) * 1000)], [600, 0])
	var none := SituationContext.new()
	_check("no target: 0", ComboPlanner.get_crowding(none, w), 0.0)


## A fake hit on `enemy` from `source` (Events.unit_hit), for the hits term.
func _fake_hit(source: Unit, enemy: Unit, tags: Array[StringName] = []) -> void:
	var ctx := HitContext.new()
	ctx.source = source
	ctx.target = enemy
	ctx.tags = tags
	Events.unit_hit.emit(ctx)


func _test_aid1_brains_reads() -> void:
	_section("Brains' reads for crowding: each champion's gap-closer (a real Lunge, not a push), the party's hits on each enemy")
	await _reset_knight()
	var e := _spawn(DUELIST_SCENE, ARENA + Vector2(-1500, -1500), true)   # a brain: Brains reads every tick
	var other := _spawn(BRUTE_SCENE, ARENA + Vector2(-1500, -1300), true)
	await _frames(3)
	knight.resource_pool.restore(1000.0)
	var lunged := knight.abilities.try_cast(&"e", knight.global_position + Vector2(200, 0))
	await _wait_until(func() -> bool: return not knight.abilities.casting and not knight.movement.is_displaced(), 60)
	await _frames(2)
	var gap := Brains.get_last_gap_closer(knight)
	var where: Vector2 = gap.get("position", Vector2.INF)
	_check("a real Lunge: a gap-closer, noted where it ended (%.1f px from him), just now" % where.distance_to(knight.global_position),
		[lunged, not gap.is_empty(), where.distance_to(knight.global_position) < 1.0, Brains.get_time() - float(gap.get("at", -10.0)) < 0.1],
		[true, true, true, true])
	var lunge_at := float(gap.get("at", -1.0))
	await _frames(5)
	knight.movement.displace(Vector2(300, 0), 0.2)
	await _wait_until(func() -> bool: return not knight.movement.is_displaced(), 60)
	await _frames(2)
	_check("a push alone isn't one (the note stays the Lunge's)", float(Brains.get_last_gap_closer(knight).get("at", -1.0)), lunge_at)
	_fake_hit(knight, e)
	_fake_hit(knight, e)
	_fake_hit(knight, e, [&"dot"] as Array[StringName])
	_fake_hit(other, e)
	_fake_hit(knight, other)
	_check("the party's hits on it: two (a DoT tick and a hit from an enemy don't count); its packmate's own one",
		[Brains.get_recent_hits(e), Brains.get_recent_hits(other), Brains.get_recent_hits(e, 0.05)], [2, 1, 2])
	await _frames(190)
	_check("3 s later: none left in the window", Brains.get_recent_hits(e), 0)
	e.queue_free()
	other.queue_free()
	await _frames(2)


func _test_aid1_opening() -> void:
	_section("The opening's terms by hand (ComboPlanner.get_opening()): escapes down, crowd control by another, recovering, committed, cornered")
	var w := Brains.table.opening_weights
	var s := SituationContext.new()
	s.has_target = true
	s.opening_cc_min_left = Brains.table.opening_cc_min_left
	var out: Array = []
	out.append(roundi(ComboPlanner.get_opening(s, w) * 1000))
	s.target_escapes_down = 1.0
	out.append(roundi(ComboPlanner.get_opening(s, w) * 1000))
	s.target_escapes_down = 2.0 / 3.5
	out.append(roundi(ComboPlanner.get_opening(s, w) * 1000))
	s.target_escapes_down = 0.0
	s.target_cc_left = 0.6
	out.append(roundi(ComboPlanner.get_opening(s, w) * 1000))
	s.target_cc_left = 0.4
	out.append(roundi(ComboPlanner.get_opening(s, w) * 1000))
	s.target_cc_left = 0.0
	s.target_committed = true
	out.append(roundi(ComboPlanner.get_opening(s, w) * 1000))
	s.target_committed = false
	s.target_cornered = true
	out.append(roundi(ComboPlanner.get_opening(s, w) * 1000))
	s.target_recovering = true
	out.append(roundi(ComboPlanner.get_opening(s, w) * 1000))
	_check("(× 1,000) nothing 0; Lunge and Iron Resolve down 500; Lunge only (2 of 3.5) 286; crowd control 0.6 s left 500, 0.4 s 0; casting 400; cornered 200; cornered and recovering 600",
		out, [0, 500, 286, 500, 0, 400, 200, 600])
	s.target_escapes_down = 1.0
	s.target_cc_left = 1.0
	s.target_committed = true
	var terms := {}
	_check("everything: clamped to 1; the biggest term escapes (the first of the ties)",
		[ComboPlanner.get_opening(s, w, terms), terms.size(), ComboPlanner.get_biggest_term(terms)[0]], [1.0, 5, &"escapes_down"])


func _test_aid1_peel_roll() -> void:
	_section("The crowded roll (AI-D1): a failed all-in peels when a peel use passes; with none, AI3b's mix")
	var b := DUELIST_DATA.behavior.resolve(DUELIST_DATA.overrides, [] as Array[BrainAdjust])
	_check("the duelist's crowded_commit: 0.55 (its override; the tuning pass, was 0.4)", b.crowded_commit, 0.55)
	b.crowded_commit = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var peels := 0
	for i in 1000:
		var s := _situation(1.0, 0.0)
		s.target_edge_distance_px = Units.to_px(80.0)
		s.add_use(&"q", &"cc", _plan(&"q"))
		s.add_use(&"q", &"peel", _plan(&"q"))
		peels += int(EnemyBrain.roll_crowded(s, b, rng).result == EnemyBrain.PEEL)
	_check("crowded_commit 0, its snare ready (cc and peel): a peel in every one of 1,000 episodes", peels, 1000)
	b.crowded_commit = 0.55
	var all_in := 0
	var peeled := 0
	for i in 1000:
		var s := _situation(1.0, 0.0)
		s.add_use(&"q", &"cc", _plan(&"q"))
		s.add_use(&"q", &"peel", _plan(&"q"))
		var r := EnemyBrain.roll_crowded(s, b, rng)
		all_in += int(r.result == EnemyBrain.ALL_IN)
		peeled += int(r.result == EnemyBrain.PEEL and r.roll >= 0.55)
	_check("crowded_commit 0.55: all in about 55%% (%d), a peel otherwise (its roll the failed one: %d)" % [all_in, peeled],
		[absi(all_in - 550) <= 50, all_in + peeled], [true, 1000])
	var results := {}
	for i in 1000:
		var s := _situation(1.0, 0.0)
		s.add_use(&"q", &"damage", _plan(&"q"))
		var r := EnemyBrain.roll_crowded(s, b, rng)
		results[r.result] = int(results.get(r.result, 0)) + 1
	_check("no peel use: all in, back up or stand, never a peel (AI3b's episode)",
		[results.has(EnemyBrain.PEEL), results.has(EnemyBrain.ALL_IN), results.has(EnemyBrain.BACK_UP), results.has(EnemyBrain.STAND)], [false, true, true, true])
	var only := _situation(1.0, 0.0)
	only.add_use(&"q", &"peel", _plan(&"q"))
	var lone: StringName = EnemyBrain.roll_crowded(only, b, rng).result
	_check("a peel use with no answer beside it: the mix (the order: an answer, then its roll)", lone == EnemyBrain.BACK_UP or lone == EnemyBrain.STAND, true)
	var cornered := _situation(1.0, 0.0)
	cornered.cornered = true
	cornered.add_use(&"q", &"cc", _plan(&"q"))
	cornered.add_use(&"q", &"peel", _plan(&"q"))
	_check("cornered still wins first", EnemyBrain.roll_crowded(cornered, b, rng).result, EnemyBrain.CORNERED)
	var runs: Array = []
	for run in 2:
		var seeded := RandomNumberGenerator.new()
		seeded.seed = 778
		var seq: Array = []
		for i in 300:
			var s := _situation(1.0, 0.0)
			s.add_use(&"q", &"cc", _plan(&"q"))
			if i % 2 == 0:
				s.add_use(&"q", &"peel", _plan(&"q"))
			seq.append(EnemyBrain.roll_crowded(s, b, seeded).result)
		runs.append(seq)
	_check("the same seed gives the same rolls (300 episodes, twice)", runs[0] == runs[1], true)
	var d := _situation(1.0, 0.0)
	d.peel_pending = true
	d.add_use(&"q", &"peel", _plan(&"q"))
	var j := RandomNumberGenerator.new()
	j.seed = 5
	var decided := EnemyBrain.decide(d, b, j)
	_check("decide(): a pending peel scores 0.9 and casts its plan (no token needed)", [decided.intent, decided.plan != null and decided.plan.slot == &"q"], [EnemyBrain.PEEL, true])


func _test_aid1_threatened() -> void:
	_section("THREATENED's tag filter (AI-D1): major = ultimate, charge-up, dash, leap")
	var s := SituationContext.new()
	s.has_target = true
	s.major_tags = Brains.table.major_tags
	s.incoming.append({"ability": JUDGEMENT, "time_to_hit": 0.5})
	var j := [s.is_threatened(1.0, &"major"), s.is_threatened(1.0), s.is_threatened(0.3, &"major")]
	s.incoming.clear()
	s.incoming.append({"ability": CLEAVE, "time_to_hit": 0.5})
	var c := [s.is_threatened(1.0, &"major"), s.is_threatened(1.0), s.is_threatened(1.0, &"core")]
	_check("Judgement coming in 0.5 s: major yes, any attack yes, not within 0.3 s", j, [true, true, false])
	_check("a Cleave: not major; any attack yes; tagged core yes", c, [false, true, true])
	var charge := _bare_ability(1.0, 10.0)
	charge.cast_style = Ability.CastStyle.CHARGE_UP
	var majors := Brains.table.major_tags
	_check("major: Lunge (dash) yes, a charged line (charge_up) yes, a CHARGE_UP cast style yes, the test bolt (core) no",
		[SituationContext.ability_has_tag(LUNGE, &"major", majors), SituationContext.ability_has_tag(CHARGED_LINE, &"major", majors),
			SituationContext.ability_has_tag(charge, &"major", majors), SituationContext.ability_has_tag(TEST_BOLT, &"major", majors)],
		[true, true, true, false])
	var cond := Condition.new()
	cond.kind = Condition.Kind.THREATENED
	cond.value = 1.0
	cond.status_tag = &"major"
	var with_cleave := cond.is_met(knight, null, null, s)
	s.incoming.clear()
	s.incoming.append({"ability": JUDGEMENT, "time_to_hit": 0.5})
	_check("the condition with status_tag major: Judgement yes, a Cleave no", [cond.is_met(knight, null, null, s), with_cleave], [true, false])


func _test_aid1_guard_uses() -> void:
	_section("The duelist's guard: two defend uses (a major ability coming within 1 s; low health while crowded)")
	var e := _spawn(DUELIST_SCENE, ARENA + Vector2(-1500, -1100), true)
	await _frames(2)
	var uses := D_GUARD.get_ai_uses()
	var s := SituationContext.new()
	s.has_target = true
	s.major_tags = Brains.table.major_tags
	var rows: Array = []
	s.incoming.append({"ability": JUDGEMENT, "time_to_hit": 0.6})
	rows.append([uses[0].passes(e, knight, s), uses[1].passes(e, knight, s)])
	s.incoming.clear()
	s.incoming.append({"ability": CLEAVE, "time_to_hit": 0.3})
	rows.append([uses[0].passes(e, knight, s), uses[1].passes(e, knight, s)])
	s.incoming.clear()
	e.health.take_damage(e.health.max_health * 0.7)   # 30%
	s.crowding = 0.7
	rows.append([uses[0].passes(e, knight, s), uses[1].passes(e, knight, s)])
	s.crowding = 0.5
	rows.append([uses[0].passes(e, knight, s), uses[1].passes(e, knight, s)])
	e.health.heal(e.health.max_health * 0.2)   # 50%
	s.crowding = 0.7
	rows.append([uses[0].passes(e, knight, s), uses[1].passes(e, knight, s)])
	_check("[major, low and crowded]: Judgement in 0.6 s [yes, no]; a Cleave [no, no]; at 30% crowding 0.7 [no, yes], 0.5 [no, no]; at 50% crowding 0.7 [no, no]",
		rows, [[true, false], [false, false], [false, true], [false, false], [false, false]])
	e.queue_free()
	await _frames(2)


## A real duelist rooted where it stands, the Knight unstoppable and placed
## `edge_units` from it (edge to edge); returns the duelist.
func _rooted_duelist(edge_units: float) -> Enemy:
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	knight.status_component.apply_status(_tag_status(&"test_unstoppable", [&"unstoppable"]))
	var e := _spawn(DUELIST_SCENE, knight.global_position + Vector2(140, 0), false)
	e.status_component.apply_status(_tag_status(&"test_root", [&"root"], true))
	e.get_brain().behavior.opening_bar = 1.0   # no setup in these
	await _wait_until(func() -> bool: return e.get_brain().get_intent() != &"", 120)
	await _frames(10)
	var away := (knight.global_position - e.global_position).normalized()
	var radii := knight.get_gameplay_radius_px() + e.get_gameplay_radius_px()
	_place(knight, e.global_position + away * (radii + Units.to_px(edge_units)))
	return e


func _free_duelist(e: Enemy) -> void:
	knight.status_component.remove_status(&"test_unstoppable")
	if is_instance_valid(e):
		e.passive = true
		e.attack.cancel()
		e.queue_free()
	await _frames(30)


func _test_aid1_episode_start() -> void:
	_section("Crowding starts the crowded episode (a real duelist, rooted where it stands; its reaction time, 0.3 s since the tuning pass)")
	var cases := [
		["the Knight inside its 2 m (0.8 m)", 80.0, 0.6, false, 0, true],
		["1 m outside it (3 m), nothing else", 300.0, 0.6, false, 0, false],
		["a Lunge in to 2.75 m at peel_threshold 0.6", 275.0, 0.6, true, 0, true],
		["a Lunge in to 2.75 m at 0.7", 275.0, 0.7, true, 0, false],
		["a string of three hits at 2.5 m", 250.0, 0.6, false, 3, true],
	]
	for c: Array in cases:
		var e: Enemy = await _rooted_duelist(c[1])
		var brain := e.get_brain()
		brain.behavior.peel_threshold = c[2]
		if c[3]:
			Brains.note_gap_closer(knight, knight.global_position)
		for i in int(c[4]):
			_fake_hit(knight, e)
		var started := Brains.get_time()
		var peak := [0.0]
		for i in 50:   # 0.83 s: inside the gap-closer's 1 s
			await get_tree().physics_frame
			if brain.get_situation() != null:
				peak[0] = maxf(peak[0], brain.get_situation().crowding)
			if brain.is_crowded():
				break
		var took := Brains.get_time() - started
		if c[5]:
			_check("%s: crowding %.2f ≥ %.1f starts an episode after its reaction time (got %.2f s)" % [c[0], peak[0], c[2], took],
				[brain.is_crowded(), took >= brain.behavior.reaction_time - 0.02 and took <= brain.behavior.reaction_time + 0.15], [true, true])
		else:
			_check("%s: crowding %.2f < %.1f, no episode" % [c[0], peak[0], c[2]], brain.is_crowded(), false)
		if c[0] == "the Knight inside its 2 m (0.8 m)":
			var away := (knight.global_position - e.global_position).normalized()
			_place(knight, e.global_position + away * (knight.get_gameplay_radius_px() + e.get_gameplay_radius_px() + Units.to_px(400.0)))
			await _frames(50)
			var still_on := brain.is_crowded()
			await _frames(30)
			_check("he leaves (4 m): crowding below it, the episode ends 1 s later", [still_on, brain.is_crowded()], [true, false])
		await _free_duelist(e)


func _test_aid1_peel() -> void:
	_section("The peel (a real duelist, crowded_commit 0): the snare at the Knight, then a step back to its band")
	for episode in 2:
		await _reset_knight()
		await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
		knight.status_component.apply_status(_tag_status(&"test_unstoppable", [&"unstoppable"]))
		var e := _spawn(DUELIST_SCENE, knight.global_position + Vector2(160, 0), false)
		var brain := e.get_brain()
		brain.behavior.crowded_commit = 0.0
		brain.behavior.opening_bar = 1.0
		brain.behavior.patience_time = 10.0   # no new commit cuts its step back short (the tuning pass's faster patience)
		await _wait_until(func() -> bool: return brain.get_intent() == &"hold", 120)
		await _frames(10)
		var casts: Array = []
		e.abilities.cast_started.connect(func(slot: StringName, _a: Ability, _c: CastContext) -> void: casts.append(slot))
		var intents := {}
		brain.intent_changed.connect(func(intent: StringName) -> void: intents[intent] = true)
		var overlay := SandboxBrains.new()   # its combo line only (not in the tree)
		var away := (knight.global_position - e.global_position).normalized()
		var radii := knight.get_gameplay_radius_px() + e.get_gameplay_radius_px()
		_place(knight, e.global_position + away * (radii + Units.to_px(80.0)))
		await _wait_until(func() -> bool: return brain.is_crowded(), 60)
		var roll := brain.get_crowded_roll()
		var step_back := [false]
		var max_edge := [0.0]
		var peel_line := [""]
		for i in 150:
			await get_tree().physics_frame
			step_back[0] = step_back[0] or (brain.peel_count > 0 and e.get_pose() == &"step_back")
			if brain.peel_count > 0:
				max_edge[0] = maxf(max_edge[0], Units.to_units(e.edge_distance_to(knight)))
			var text := overlay.get_combo_text(e)
			if peel_line[0] == "" and text.contains(": peel (Snare)"):   # the first: as it peels
				peel_line[0] = text.get_slice("\n", 0)
		overlay.free()
		_check("episode %d: the roll peels; it casts the snare (q) at him, then retreats (step_back) out toward its band (got %d u)" % [episode + 1, roundi(max_edge[0])],
			[roll, casts.slice(0, 1), brain.peel_count, intents.has(EnemyBrain.PEEL), intents.has(&"retreat"), step_back[0], max_edge[0] >= 300.0],
			[EnemyBrain.PEEL, [&"q"], 1, true, true, true, true])
		if episode == 0:
			_check("its overlay line: %s" % peel_line[0], peel_line[0].begins_with("crowding ") and peel_line[0].contains(" ≥ 0.50 (near ") and peel_line[0].ends_with(": peel (Snare)"), true)
		await _free_duelist(e)


func _test_aid1_brain_opening() -> void:
	_section("The opening read by a real brain (a rooted test brute about 4 m away): escapes at once; a crowd control by another and a cast after its reaction time; a wall behind him")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	knight.resource_pool.restore(1000.0)
	var e := _spawn(BRUTE_SCENE, knight.global_position + Vector2(170, 0), false)
	e.status_component.apply_status(_tag_status(&"test_root", [&"root"], true))
	var brain := e.get_brain()
	_pin_ai3(brain.get_unit() as Enemy)
	await _wait_until(func() -> bool: return brain.get_situation() != null and brain.get_situation().has_target, 120)
	await _frames(8)
	var read := func() -> int: return roundi(brain.get_situation().opening * 1000)
	var reads: Array = [read.call(), brain.get_situation().target_escapes_ready]
	knight.abilities.start_cooldown(&"e")
	await _frames(8)
	reads.append(read.call())
	reads.append(brain.get_situation().target_escapes_ready)
	knight.abilities.start_cooldown(&"w")
	await _frames(8)
	reads.append(read.call())
	_check("(× 1,000) all ready 0 (2 escapes ready); Lunge spent 286 (1 ready); Iron Resolve too 500: cooldowns read at once", reads, [0, 2, 286, 1, 500])
	_check("an enemy with no opener never sets up from it", [brain.get_opener_slots().is_empty(), brain.setup_count, brain.get_patience() < 1.0], [true, 0, true])
	_reset_cooldowns()
	knight.resource_pool.restore(1000.0)
	await _frames(8)
	var other := _spawn(SLIME_SCENE, ARENA + Vector2(-1500, 900), true)
	var root: StatusEffect = STATUS_ROOT.duplicate()
	root.duration = 2.0
	knight.status_component.apply_status(root, other)
	await _frames(6)   # 0.1 s: inside its 0.455 s reaction
	var early: int = read.call()
	await _frames(30)
	var seen: int = read.call()
	var source_ok := brain.get_situation().target_cc_source == other
	knight.status_component.remove_status(root.id)
	await _frames(8)
	var own: StatusEffect = STATUS_ROOT.duplicate()
	own.duration = 2.0
	knight.status_component.apply_status(own, e)
	await _frames(36)
	var own_read: int = read.call()
	knight.status_component.remove_status(own.id)
	_check("a root from another unit (2 s): 0 before its reaction time, 500 after (its source kept); its own root: 0",
		[early, seen, source_ok, own_read], [0, 500, true, 0])
	await _frames(8)
	var q_before: Ability = knight.abilities.q
	var long_bolt: Ability = TEST_BOLT.duplicate()
	long_bolt.cast_time = 2.0
	long_bolt.resource_cost = 0.0
	knight.abilities.set(&"q", long_bolt)
	var cast := knight.abilities.try_cast(&"q", knight.global_position + Vector2(0, -200))
	await _frames(6)
	var casting_early: int = read.call()
	await _frames(30)
	var casting_seen: int = read.call()
	knight.abilities.interrupt_cast()
	knight.abilities.set(&"q", q_before)
	_check("the Knight casting (a 2 s cast): 0 before its reaction time, 400 after", [cast, casting_early, casting_seen], [true, 0, 400])
	await _frames(8)
	var away := (knight.global_position - e.global_position).normalized()
	var wall := _wall_at(knight.global_position + away * (knight.get_gameplay_radius_px() + 30.0), Vector2(16, 240))
	await _frames(8)
	var cornered: int = read.call()
	var cornered_flag := brain.get_situation().target_cornered
	wall.queue_free()
	await _frames(8)
	_check("a wall 30 px behind him, seen from it: cornered 200; gone: 0", [cornered_flag, cornered, read.call()], [true, 200, 0])
	e.passive = true
	e.queue_free()
	other.queue_free()
	await _frames(30)


func _test_aid1_setup() -> void:
	_section("The setup (a real duelist about 4 m away; AI-D2: with a plan, mixup and jitter 0): his escapes down fill its patience at once and it opens with its best plan")
	var cases := [
		["Lunge and Iron Resolve down, its bar 0.5: snare_first", true, 0.5, false, &"q", false, &"snare_first"],
		["the same at a bar of 0.6", true, 0.6, false, &"", false, &""],
		["his escapes up", false, 0.5, false, &"", false, &""],
		["escapes down, its snare on cooldown: strike_finish (a blind plan, on the blind read: escapes down)", true, 0.5, true, &"e", false, &"strike_finish"],
		["escapes down, its snare and strike on cooldown: no plan fits (no setup)", true, 0.5, true, &"", true, &""],
	]
	for c: Array in cases:
		await _reset_knight()
		await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
		knight.status_component.apply_status(_tag_status(&"test_unstoppable", [&"unstoppable"]))
		if c[1]:
			knight.abilities.start_cooldown(&"e")
			knight.abilities.start_cooldown(&"w")
		var e := _spawn(DUELIST_SCENE, knight.global_position + Vector2(170, 0), false)
		var brain := e.get_brain()
		brain.behavior.opening_bar = c[2]
		brain.behavior.mixup = 0.0
		brain.behavior.jitter = 0.0
		if c[5]:
			e.abilities.start_cooldown(&"e")
		if c[3]:
			e.abilities.start_cooldown(&"q")
		var plan_ids: Array = []
		e.abilities.cast_started.connect(func(_slot: StringName, _a: Ability, _c: CastContext) -> void: plan_ids.append(brain.get_plan().id if brain.get_plan() != null else &""))
		var casts: Array = []
		e.abilities.cast_started.connect(func(slot: StringName, _a: Ability, _c: CastContext) -> void: casts.append(slot))
		var opener_done := [false]   # its opener's own cast ended (the next step may start on the very next tick)
		e.abilities.cast_finished.connect(func(slot: StringName, _a: Ability) -> void: opener_done[0] = opener_done[0] or slot == c[4])
		var spawned := Brains.get_time()
		var tell := [false]
		for i in 90:
			await get_tree().physics_frame
			tell[0] = tell[0] or (brain.is_setup_commit() and e.get_pose() == &"crouch")
			if not casts.is_empty():
				break
		var took := Brains.get_time() - spawned
		if c[4] != &"":
			_check("%s: it sets up within about a second (got %.2f s; patience alone takes about 5 s): its tell, then %s first, its plan running" % [c[0], took, c[4]],
				[casts.slice(0, 1), brain.setup_count, brain.get_setup_slot(), tell[0], plan_ids.slice(0, 1)], [[c[4]], 1, c[4], true, [c[6]]])
			await _wait_until(func() -> bool: return opener_done[0], 90)
			await _frames(12)   # several thinks: a commit its opener ended would be over by then
			_check("%s: its opener's end doesn't end the commit (still on 0.2 s later)" % c[0], brain.is_committing(), true)
		else:
			_check("%s: no setup in 1.5 s (it holds while patience fills: %.2f)" % [c[0], brain.get_patience()],
				[brain.setup_count, casts.is_empty(), brain.get_patience() < 1.0], [0, true, true])
		await _free_duelist(e)


func _test_aid1_recovery() -> void:
	_section("The finisher's recovery (Ability.recovery_time 1.2 s): no moving, swinging or casting; the recover pose")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	knight.status_component.apply_status(_tag_status(&"test_unstoppable", [&"unstoppable"]))
	var e := _spawn(DUELIST_SCENE, knight.global_position + Vector2(70, 0), true)   # passive: a direct cast
	await _frames(2)
	var cast := e.abilities.try_cast(&"r", knight.global_position)
	await _wait_until(func() -> bool: return not e.abilities.casting, 90)
	var row := [e.abilities.is_recovering(), roundi(e.abilities.get_recovery_left() * 10), e.movement.can_move(), e.abilities.can_cast(&"q"),
		e.abilities.get_fail_reason(&"q"), e.abilities.try_cast(&"q", knight.global_position)]
	_check("right after its effect: recovering 1.2 s; it can't move; it can't cast (busy)", [cast, row], [true, [true, 12, false, false, AbilityComponent.FAIL_BUSY, false]])
	e.attack.attack(knight)
	var wound := [false]
	for i in 30:
		await get_tree().physics_frame
		wound[0] = wound[0] or e.attack.is_winding_up()
	_check("an attack order with him in its reach: no swing during it", wound[0], false)
	await _wait_until(func() -> bool: return not e.abilities.is_recovering(), 90)
	var free_row := [e.movement.can_move(), e.abilities.can_cast(&"q")]
	await _wait_until(func() -> bool: return e.attack.is_winding_up(), 60)
	_check("after it: it moves, casts and swings again", [free_row, e.attack.is_winding_up()], [[true, true], true])
	e.attack.cancel()
	e.queue_free()
	await _frames(10)

	# In a fight: the recover pose, standing still.
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	_spend_kit()
	var f := _spawn(DUELIST_SCENE, knight.global_position + Vector2(150, 0), false)
	_pin_ai3(f)
	f.abilities.set(&"q", null)   # only its finisher
	f.abilities.set(&"w", null)
	f.abilities.set(&"e", null)
	await _wait_until(func() -> bool: return f.abilities.is_recovering(), 480)
	var at := f.global_position
	var seen := [false]
	var still := [true]
	var frames := [0]
	for i in 80:
		await get_tree().physics_frame
		if f.abilities.is_recovering():
			frames[0] += 1
			seen[0] = seen[0] or f.get_pose() == &"recover"
			still[0] = still[0] and f.global_position.distance_to(at) < 0.5
	_check("in a fight, after its finisher: it stands still in the recover pose (%d frames of 72)" % frames[0], [frames[0] >= 70, seen[0], still[0]], [true, true, true])
	await _free_duelist(f)


func _test_aid1_guard() -> void:
	_section("Its guard (a real duelist): up when Judgement is aimed at it, not for a plain bolt; up when it's low and crowded")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	knight.resource_pool.restore(1000.0)
	var e := _spawn(DUELIST_SCENE, knight.global_position + Vector2(130, 0), false)
	e.status_component.apply_status(_tag_status(&"test_root", [&"root"], true))
	var guards := [0]
	e.abilities.cast_started.connect(func(slot: StringName, _a: Ability, _c: CastContext) -> void:
		if slot == &"w":
			guards[0] += 1)
	await _wait_until(func() -> bool: return e.get_brain().get_intent() != &"", 120)
	await _frames(5)
	var judged := knight.abilities.try_cast(&"r", e.global_position, e)
	await _wait_until(func() -> bool: return guards[0] > 0 or not knight.abilities.casting, 60)
	_check("Judgement cast on it (major): its guard goes up before it lands", [judged, guards[0]], [true, 1])
	e.passive = true
	e.queue_free()
	await _reset_knight()
	await _frames(30)

	# A slow plain bolt (core): seen coming, no guard (inside its 450 u notice range).
	var b := _spawn(DUELIST_SCENE, knight.global_position + Vector2(160, 0), false)
	b.status_component.apply_status(_tag_status(&"test_root", [&"root"], true))
	var bolt_guards := [0]
	var saw := [false]
	b.abilities.cast_started.connect(func(slot: StringName, _a: Ability, _c: CastContext) -> void:
		if slot == &"w":
			bolt_guards[0] += 1)
	await _wait_until(func() -> bool: return b.get_brain().get_intent() != &"", 120)
	await _frames(5)
	var slow: Ability = TEST_BOLT.duplicate()
	slow.projectile_speed = 300.0
	slow.cast_time = 0.0
	knight.abilities.try_cast_free(slow, b.global_position, null, &"enemies_test")
	for i in 120:
		await get_tree().physics_frame
		var s := b.get_brain().get_situation()
		saw[0] = saw[0] or (s != null and not s.incoming.is_empty())
	_check("a slow test bolt at it (core, not major): seen coming, no guard", [saw[0], bolt_guards[0]], [true, 0])
	b.passive = true
	b.queue_free()
	await _frames(30)

	# Low and crowded: no snare (no peel), at 30%, the Knight in its face.
	var low: Enemy = await _rooted_duelist(400.0)
	low.abilities.set(&"q", null)
	var low_guards := [0]
	low.abilities.cast_started.connect(func(slot: StringName, _a: Ability, _c: CastContext) -> void:
		if slot == &"w":
			low_guards[0] += 1)
	low.health.take_damage(low.health.max_health * 0.7)
	await _frames(20)
	var calm: int = low_guards[0]
	var away := (knight.global_position - low.global_position).normalized()
	_place(knight, low.global_position + away * (knight.get_gameplay_radius_px() + low.get_gameplay_radius_px() + Units.to_px(80.0)))
	await _wait_until(func() -> bool: return low_guards[0] > 0, 60)
	_check("at 30%% and 4 m away: no guard; the Knight in its face (crowding %.2f): its guard goes up" % low.get_brain().get_situation().crowding,
		[calm, low_guards[0] > 0], [0, true])
	await _free_duelist(low)


func _test_aid1_sandbox() -> void:
	_section("SandboxBrains (AI-D1): Shift+H gains the duelist, escapes down, the overlay's combo lines, the panel's two new sliders")
	await _reset_knight()
	var sb := SandboxBrains.new()
	add_child(sb)
	await _frames(2)
	var order: Array = []
	for i in 6:
		order.append(sb.cycle_scenario_enemy().resource_path.get_file())
	_check("Shift+H: brute → skirmisher → caster → elite caster → duelist → Assassin (ARCHETYPES AR3b) → brute", order,
		["test_skirmisher.tscn", "test_caster.tscn", "test_caster_elite.tscn", "test_duelist.tscn", "test_assassin.tscn", "test_brute.tscn"])
	sb.scenario_enemy = DUELIST_SCENE
	var d := sb.run_scenario(&"escapes_down")
	if d != null and d.get_brain() != null:
		d.get_brain().behavior.mixup = 0.0   # AI-D2: its best plan, every time
		d.get_brain().behavior.jitter = 0.0
	await _frames(2)
	var slots_ready: Array = []
	for slot in AbilityComponent.SLOTS:
		slots_ready.append(knight.abilities.is_ready(slot))
	_check("escapes down (H's eleventh): the duelist; Lunge and Iron Resolve spent, Cleave and Judgement ready",
		[sb.get_scenario(), d != null and d.data == DUELIST_DATA, slots_ready], [&"escapes_down", true, [true, false, false, true]])
	var texts := {}
	for i in 90:
		await get_tree().physics_frame
		if is_instance_valid(d):
			texts[sb.get_combo_text(d)] = true
	var opening_line := [false]
	var setup_line := [false]
	for text: String in texts:
		opening_line[0] = opening_line[0] or text.contains("opening 0.50 ≥ 0.40 (escapes 0.50)")
		setup_line[0] = setup_line[0] or text.contains(": setup snare_first (Snare)")
	var crowding_text := ""
	if is_instance_valid(d):
		var away := (knight.global_position - d.global_position).normalized()
		_place(knight, d.global_position + away * (knight.get_gameplay_radius_px() + d.get_gameplay_radius_px() + Units.to_px(80.0)))
		await _frames(6)
		crowding_text = sb.get_combo_text(d)
	_check("its overlay: `opening 0.50 ≥ 0.40 (escapes 0.50)` (its bar since the tuning pass), then `: setup snare_first (Snare)` as it opens (AI-D2: its plan); the Knight in its face: `crowding 0.60 ≥ 0.50 (near 0.60)` (%s)" % crowding_text.replace("\n", " | "),
		[opening_line[0], setup_line[0], crowding_text.contains("crowding 0.60 ≥ 0.50 (near 0.60)")], [true, true, true])
	sb.scenario_enemy = BRUTE_SCENE
	var brute := sb.run_scenario(&"escapes_down")
	await _frames(20)
	_check("a brute (no opener): no opening line", sb.get_combo_text(brute).contains("opening"), false)
	sb.set_panel(true)
	await _frames(2)
	var rows: Dictionary = sb.get(&"_rows")
	_check("the panel: twenty-three rows (twenty-two sliders; the band's two ends), peel_threshold and opening_bar among them (AI-D2: and follow_through, combo_greed, mixup)",
		[rows.size(), rows.has(&"peel_threshold"), rows.has(&"opening_bar"), rows.has(&"follow_through"), rows.has(&"combo_greed"), rows.has(&"mixup")], [23, true, true, true, true, true])
	sb.set_panel(false)
	sb.clear_scenario()
	sb.queue_free()
	await _reset_knight()
	await _frames(30)


# --- AI-D2: combo plans and the follow-through (ENEMIES_AI.md, Combo plans) --------------------

func _test_aid2_data() -> void:
	_section("AI-D2 data: ComboPlan and ComboStep, the duelist's three plans, the opener check, the sliders, the table, the Events")
	var step := ComboStep.new()
	var plan := ComboPlan.new()
	_check("a step: AFTER_LANDED, a 1 s window, no delay, not optional; a plan: weight 1, from tier 1, no steps (no opener slot)",
		[step.timing, step.window, step.delay, step.optional, plan.weight, plan.min_difficulty_tier, plan.get_opener_slot()],
		[ComboStep.Timing.AFTER_LANDED, 1.0, 0.0, false, 1.0, 1, &""])
	var rows: Array = []
	for p in DUELIST_DATA.combo_plans:
		var slots: Array = []
		var timings: Array = []
		for s in p.steps:
			slots.append(s.slot)
			timings.append(s.timing)
		rows.append([p.id, slots, timings.slice(1), p.weight])
	var landed := ComboStep.Timing.AFTER_LANDED
	_check("the duelist's plans: snare_first (q, e, r; weight 1), strike_first (e, q, r; 0.8), strike_finish (e, r; 0.6); each later step as the one before lands",
		rows, [[&"snare_first", [&"q", &"e", &"r"], [landed, landed], 1.0], [&"strike_first", [&"e", &"q", &"r"], [landed, landed], 0.8],
			[&"strike_finish", [&"e", &"r"], [landed], 0.6]])
	var conds: Array = []
	for c in DUELIST_DATA.combo_plans[0].conditions:
		conds.append([c.kind, c.negate, c.status_tag])
	_check("snare_first fits with all his escapes down, him not held, not cornered; the other two have no conditions",
		[conds, DUELIST_DATA.combo_plans[1].conditions.size(), DUELIST_DATA.combo_plans[2].conditions.size()],
		[[[Condition.Kind.TARGET_ESCAPES_READY, true, &""], [Condition.Kind.TARGET_HAS_STATUS, true, &"cc"], [Condition.Kind.TARGET_CORNERED, true, &""]], 0, 0])
	_check("at the run's tier all three exist (get_plans_at())", DUELIST_DATA.get_plans_at(1).size(), 3)
	var breaches: Array = []
	var blind: Array = []
	for f in DirAccess.open(ENEMY_DATA_DIR).get_files():
		if not f.ends_with(".tres"):
			continue
		var data := load(ENEMY_DATA_DIR + f) as EnemyData
		for p in data.combo_plans:
			for s in p.steps:
				if _slot_ability(data, s.slot) == null:
					breaches.append("%s %s: nothing on %s" % [data.id, p.id, s.slot])
			var opener := _slot_ability(data, p.get_opener_slot())
			if opener == null:
				continue
			if not opener.combo_roles.has(&"opener"):
				blind.append(p.id)
			elif _telegraph_time(opener) < TELEGRAPH_MIN - 0.0001 or opener.targeting == Ability.Targeting.UNIT:
				breaches.append("%s %s: its opener %s" % [data.id, p.id, opener.id])
	_check("the opener check: every plan's steps name abilities it has, every `opener` that opens one telegraphs at least 0.6 s and can be dodged; the rest are blind plans (on the blind read only)",
		[breaches, blind], [[], [&"strike_first", &"strike_finish"]])
	_check("follow_through 0–1, combo_greed 0–1, mixup 0–0.5, last in the panel's list",
		[EnemyBehavior.LIMITS[&"follow_through"], EnemyBehavior.LIMITS[&"combo_greed"], EnemyBehavior.LIMITS[&"mixup"], EnemyBehavior.SLIDERS.slice(20)],
		[[0.0, 1.0], [0.0, 1.0], [0.0, 0.5], [&"follow_through", &"combo_greed", &"mixup"]])
	var adj := BrainAdjust.new()
	_check("starts: brute .6 / .6 / .15, skirmisher .2 / .3 / .3, caster 0 / .1 / .2; the duelist's combo_greed .2 and mixup .3 (overrides); BrainAdjust's three at 1",
		[[BRUTE_BEHAVIOR.follow_through, BRUTE_BEHAVIOR.combo_greed, BRUTE_BEHAVIOR.mixup],
			[SKIRMISHER_BEHAVIOR.follow_through, SKIRMISHER_BEHAVIOR.combo_greed, SKIRMISHER_BEHAVIOR.mixup],
			[CASTER_BEHAVIOR.follow_through, CASTER_BEHAVIOR.combo_greed, CASTER_BEHAVIOR.mixup],
			[DUELIST_DATA.overrides.get(&"combo_greed", -1.0), DUELIST_DATA.overrides.get(&"mixup", -1.0)],
			[adj.follow_through, adj.combo_greed, adj.mixup]],
		[[0.6, 0.6, 0.15], [0.2, 0.3, 0.3], [0.0, 0.1, 0.2], [0.2, 0.3], [1.0, 1.0, 1.0]])
	var t := Brains.table
	var keys: Array = []
	var values: Array = []
	for k: StringName in t.blind_reads:
		keys.append(k)
		values.append(t.blind_reads[k])
	_check("the table: plan_max_time 6 s, plan_odds_drop 0.33, mixup's beat 0.4–0.8 s, whiff_time 0.3 s, the four blind reads on",
		[t.plan_max_time, t.plan_odds_drop, t.mixup_delay_min, t.mixup_delay_max, t.whiff_time, keys, values],
		[6.0, 0.33, 0.4, 0.8, 0.3, [&"low_health", &"escapes_down", &"ultimate_down", &"held"], [true, true, true, true]])
	_check("Events: combo_plan_started, combo_plan_ended", [Events.has_signal("combo_plan_started"), Events.has_signal("combo_plan_ended")], [true, true])


## A plan built in a test: `slots` in order, each later step's timing from
## `timings` (AFTER_LANDED when missing).
func _combo_plan(slots: Array, timings: Array = [], id: StringName = &"test_plan") -> ComboPlan:
	var p := ComboPlan.new()
	p.id = id
	for i in slots.size():
		var st := ComboStep.new()
		st.slot = slots[i]
		if i > 0 and i - 1 < timings.size():
			st.timing = timings[i - 1]
		p.steps.append(st)
	return p


func _blind_situation() -> SituationContext:
	var s := _situation(0.5, 0.0)
	s.blind_reads = Brains.table.blind_reads
	s.target_health_ratio = 0.8
	s.target_escapes = 2
	s.target_escapes_ready = 1
	s.target_ultimates = 1
	s.target_ultimates_ready = 1
	return s


func _test_aid2_blind_read() -> void:
	_section("The blind read (Ryan, 2026-10-07: it doesn't HAVE to wait for its opener to land): held, low, his escapes down, his ultimate down; otherwise none")
	var rows: Array = []
	var s := _blind_situation()
	rows.append(ComboPlanner.get_blind_reason(s, 0.3))
	s = _blind_situation()
	s.target_cc = true
	rows.append(ComboPlanner.get_blind_reason(s, 0.3))
	s = _blind_situation()
	s.target_health_ratio = 0.25
	rows.append(ComboPlanner.get_blind_reason(s, 0.3))
	s = _blind_situation()
	s.target_health_ratio = 0.3
	rows.append(ComboPlanner.get_blind_reason(s, 0.3))
	s = _blind_situation()
	s.target_escapes_ready = 0
	rows.append(ComboPlanner.get_blind_reason(s, 0.3))
	s = _blind_situation()
	s.target_escapes = 0
	s.target_escapes_ready = 0
	rows.append(ComboPlanner.get_blind_reason(s, 0.3))
	s = _blind_situation()
	s.target_ultimates_ready = 0
	rows.append(ComboPlanner.get_blind_reason(s, 0.3))
	s = _blind_situation()
	s.target_cc = true
	s.target_ultimates_ready = 0
	rows.append(ComboPlanner.get_blind_reason(s, 0.3))
	s = _blind_situation()
	s.target_ultimates_ready = 0
	s.blind_reads = {&"low_health": true, &"escapes_down": true, &"ultimate_down": false, &"held": true}
	rows.append(ComboPlanner.get_blind_reason(s, 0.3))
	_check("all up and healthy: none; held; 25% (under its 0.3): low; at 30%: none; escapes 0 of 2: escapes down; no escapes at all: none; Judgement down: ultimate down; held and ult down: held (first); ultimate_down switched off: none",
		rows, [&"", &"held", &"low_health", &"", &"escapes_down", &"", &"ultimate_down", &"held", &""])


func _plan_option(plan: ComboPlan, blind: bool, value: float = 1.0) -> Dictionary:
	return {"plan": plan, "opener": _plan(plan.get_opener_slot(), value), "ready": true, "conditions_ok": true, "cc_ok": true, "blind": blind}


func _test_aid2_pick_plan() -> void:
	_section("Picking a plan (pure): it fits (conditions, ready, an opener plan, no wasted crowd control, a blind plan only on the blind read), then weight × the opener's value, then mixup")
	var plans := DUELIST_DATA.combo_plans
	var b := DUELIST_DATA.behavior.resolve(DUELIST_DATA.overrides, [] as Array[BrainAdjust])
	b.jitter = 0.0
	b.mixup = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var pick_id := func(sc: SituationContext) -> StringName:
		var pick := ComboPlanner.pick_plan(sc, b, rng)
		return (pick.plan as ComboPlan).id if not pick.is_empty() else &""
	var rows: Array = []
	var s := _situation(0.5, 1.0)
	for i in 3:
		s.plan_options.append(_plan_option(plans[i], i > 0))
	rows.append(pick_id.call(s))   # no blind read: the strike plans don't fit
	s.blind_reason = &"escapes_down"
	rows.append(pick_id.call(s))   # all fit: the heaviest
	s.plan_options[0].conditions_ok = false
	rows.append(pick_id.call(s))
	s.plan_options[1].ready = false
	rows.append(pick_id.call(s))
	s.plan_options[2].opener = null
	rows.append(pick_id.call(s))
	s.blind_reason = &""
	s.plan_options[0].conditions_ok = true
	s.plan_options[0].cc_ok = false
	rows.append(pick_id.call(s))
	_check("no blind read: snare_first only; blind: snare_first (weight 1); its conditions failing: strike_first (0.8); that one not ready: strike_finish; its opener with no plan: none; snare_first wasting its snare: none",
		rows, [&"snare_first", &"snare_first", &"strike_first", &"strike_finish", &"", &""])
	s = _situation(0.5, 1.0)
	s.blind_reason = &"escapes_down"
	s.plan_options.append(_plan_option(plans[0], false, 0.5))
	s.plan_options.append(_plan_option(plans[1], true, 1.0))
	_check("weight × the opener's plan value: snare_first 1 × 0.5 < strike_first 0.8 × 1", pick_id.call(s), &"strike_first")
	b.mixup = 0.3
	var runner_ups := 0
	var delays := 0
	var in_range := true
	for i in 1000:
		var two := _situation(0.5, 1.0)
		two.blind_reason = &"escapes_down"
		two.plan_options.append(_plan_option(plans[0], false))
		two.plan_options.append(_plan_option(plans[1], true))
		var pick := ComboPlanner.pick_plan(two, b, rng)
		runner_ups += int(pick.runner_up and (pick.plan as ComboPlan).id == &"strike_first")
		var one := _situation(0.5, 1.0)
		one.mixup_delay_min = Brains.table.mixup_delay_min
		one.mixup_delay_max = Brains.table.mixup_delay_max
		one.plan_options.append(_plan_option(plans[0], false))
		var single := ComboPlanner.pick_plan(one, b, rng)
		if float(single.delay) > 0.0:
			delays += 1
			in_range = in_range and float(single.delay) >= 0.4 - 0.0001 and float(single.delay) <= 0.8 + 0.0001
		in_range = in_range and not single.runner_up
	_check("mixup 0.3 over 1,000 seeded setups: two fitting, the runner-up about 30%% (%d); one fitting, a held beat of 0.4–0.8 s about 30%% (%d), never a runner-up" % [runner_ups, delays],
		[absi(runner_ups - 300) <= 50, absi(delays - 300) <= 50, in_range], [true, true, true])
	b.mixup = 0.0
	var never := 0
	for i in 200:
		var two := _situation(0.5, 1.0)
		two.blind_reason = &"held"
		two.plan_options.append(_plan_option(plans[0], false))
		two.plan_options.append(_plan_option(plans[1], true))
		var pick := ComboPlanner.pick_plan(two, b, rng)
		never += int(pick.runner_up) + int(float(pick.delay) > 0.0)
	_check("mixup 0: never a runner-up or a beat", never, 0)


func _plan_progress(index: int, prev_end: float, landed: float, miss_at: float, opener_landed: bool = true) -> Dictionary:
	return {"index": index, "prev_end": prev_end, "prev_landed": landed, "prev_miss_at": miss_at, "opener_landed": opener_landed,
		"carried": false, "greed": -1.0, "finishers": [2], "target_tags": []}


func _test_aid2_next_step() -> void:
	_section("A plan's steps (pure next_step()): each starts on the tick its trigger comes (no reaction time), prefers to wait for a landing, a miss carries on on the blind read or one combo_greed roll, no blind finisher, a 1 s window")
	var plan := DUELIST_DATA.combo_plans[0]   # snare_first: q, e (as it lands), r (as it lands; the finisher)
	var b := DUELIST_DATA.behavior.resolve(DUELIST_DATA.overrides, [] as Array[BrainAdjust])
	var s := _situation(0.5, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var rows: Array = []
	rows.append(ComboPlanner.next_step(plan, _plan_progress(1, -1.0, -1.0, INF), s, b, 5.0, rng).action)
	rows.append(ComboPlanner.next_step(plan, _plan_progress(1, 5.0, -1.0, 5.5), s, b, 5.2, rng).action)
	var landed := ComboPlanner.next_step(plan, _plan_progress(1, 5.0, 5.3, 5.5), s, b, 5.3, rng)
	rows.append([landed.action, landed.get("trigger", -1.0)])
	rows.append(ComboPlanner.next_step(plan, _plan_progress(1, 5.0, 5.3, 5.5), s, b, 6.35, rng).get("reason", &""))
	var optional_plan := _combo_plan([&"q", &"e", &"r"])
	optional_plan.steps[1].optional = true
	rows.append(ComboPlanner.next_step(optional_plan, _plan_progress(1, 5.0, 5.3, 5.5), s, b, 6.35, rng).action)
	_check("its snare's cast not ended: wait; ended, not landed before its miss time: wait (it prefers to); landed at 5.3: the strike starts at 5.3 (the same tick); 1.05 s after its trigger: the window ends the plan; an optional step is skipped",
		rows, [ComboPlanner.WAIT, ComboPlanner.WAIT, [ComboPlanner.START, 5.3], ComboPlanner.WINDOW, ComboPlanner.SKIP])
	rows = []
	b.combo_greed = 0.0
	var miss := ComboPlanner.next_step(plan, _plan_progress(1, 5.0, -1.0, 5.5), s, b, 5.5, rng)
	rows.append([miss.action, miss.get("reason", &""), miss.has("greed")])
	b.combo_greed = 1.0
	miss = ComboPlanner.next_step(plan, _plan_progress(1, 5.0, -1.0, 5.5), s, b, 5.5, rng)
	rows.append([miss.action, miss.get("carried", false), miss.has("greed")])
	b.combo_greed = 0.0
	s.blind_reason = &"escapes_down"
	miss = ComboPlanner.next_step(plan, _plan_progress(1, 5.0, -1.0, 5.5), s, b, 5.5, rng)
	rows.append([miss.action, miss.get("carried", false), miss.has("greed")])
	_check("its snare missed (nothing by its miss time): at combo_greed 0 the plan ends (missed); at 1 it carries on; at 0 with the blind read (escapes down) it carries on without a roll",
		rows, [[ComboPlanner.END, ComboPlanner.MISSED, true], [ComboPlanner.START, true, true], [ComboPlanner.START, true, false]])
	s.blind_reason = &""
	b.combo_greed = 0.2
	var carried := 0
	var finishers := 0
	for i in 1000:
		var p := _plan_progress(1, 5.0, -1.0, 5.5, false)
		var r := ComboPlanner.next_step(plan, p, s, b, 5.5, rng)
		if r.action == ComboPlanner.START:
			carried += 1
	b.combo_greed = 0.0
	for i in 200:
		var p := _plan_progress(2, 6.0, 6.2, 6.5, false)   # the strike landed, the snare had missed
		finishers += int(ComboPlanner.next_step(plan, p, s, b, 6.2, rng).action == ComboPlanner.START)
	_check("combo_greed 0.2 over 1,000 seeded missed snares: it carries on in about 20%% (%d); at 0, never a finisher after a missed opener (%d of 200)" % [carried, finishers],
		[absi(carried - 200) <= 40, finishers], [true, 0])
	rows = []
	var fin := _plan_progress(2, 6.0, 6.2, 6.5, false)
	fin.carried = true
	rows.append(ComboPlanner.next_step(plan, fin, s, b, 6.2, rng).action)
	rows.append(ComboPlanner.next_step(plan, _plan_progress(2, 6.0, 6.2, 6.5, true), s, b, 6.2, rng).action)
	s.blind_reason = &"low_health"
	rows.append(ComboPlanner.next_step(plan, _plan_progress(2, 6.0, 6.2, 6.5, false), s, b, 6.2, rng).action)
	s.blind_reason = &""
	_check("the finisher after a missed snare: carried on (greed or blind before), it starts; its snare landed, it starts; the blind read now (low), it starts",
		rows, [ComboPlanner.START, ComboPlanner.START, ComboPlanner.START])
	rows = []
	var timed := _combo_plan([&"q", &"e", &"r", &"w"], [ComboStep.Timing.AFTER_ENDED, ComboStep.Timing.AFTER_DELAY, ComboStep.Timing.ON_STATUS])
	timed.steps[2].delay = 0.5
	timed.steps[3].status_tag = &"root"
	rows.append(ComboPlanner.next_step(timed, _plan_progress(1, 5.0, -1.0, 5.5), s, b, 5.0, rng).action)
	rows.append(ComboPlanner.next_step(timed, _plan_progress(2, 5.0, -1.0, 5.5), s, b, 5.3, rng).action)
	rows.append(ComboPlanner.next_step(timed, _plan_progress(2, 5.0, -1.0, 5.5), s, b, 5.5, rng).action)
	var status := _plan_progress(3, 5.0, -1.0, 5.5)
	rows.append(ComboPlanner.next_step(timed, status, s, b, 5.2, rng).action)
	status.target_tags = [&"cc", &"root"]
	rows.append(ComboPlanner.next_step(timed, status, s, b, 5.2, rng).action)
	status.target_tags = []
	rows.append(ComboPlanner.next_step(timed, status, s, b, 6.1, rng).get("reason", &""))
	rows.append(ComboPlanner.next_step(timed, _plan_progress(4, 7.0, -1.0, 7.5), s, b, 7.0, rng).get("reason", &""))
	_check("AFTER_ENDED starts as the cast ends; AFTER_DELAY 0.5 waits until then; ON_STATUS root waits for a root, starts with one, its window runs from the cast's end; past the last step: done",
		rows, [ComboPlanner.START, ComboPlanner.WAIT, ComboPlanner.START, ComboPlanner.WAIT, ComboPlanner.START, ComboPlanner.WINDOW, ComboPlanner.DONE])


func _test_aid2_lean() -> void:
	_section("The follow-through (pure): the lean and the worked example's four cases at follow_through 0.6 (reset, stay, stay, reset); the no-waste rule")
	var b := DUELIST_DATA.behavior.resolve(DUELIST_DATA.overrides, [] as Array[BrainAdjust])
	b.confidence = 0.5
	b.nerve = 0.6
	b.respect_weight = 1.0
	var cases: Array[SituationContext] = []
	for c: Array in [[0.8, 0.0, 0.0, 1.5], [0.15, 0.0, 0.0, 1.5], [0.42, 7.5 / 10.5, 0.0, 7.5], [0.8, 0.0, 0.5, 1.5]]:
		var s := SituationContext.new()
		s.respect = c[0]
		s.own_ready_share = c[1]
		s.press = c[2]
		s.effective_respect = EnemyBrain.get_effective_respect(s, b)
		s.health_ratio = 0.9
		s.own_kit_ready = float(c[3]) / 10.5
		cases.append(s)
	var leans: Array = []
	var stays: Array = []
	for s in cases:
		leans.append(roundi(ComboPlanner.get_lean(s) * 100.0))
		stays.append(ComboPlanner.wants_stay(s, 0.6))
	_check("lean × 100 [its kit spent, his up: 11; both spent: 46; cut short, his Judgement down: 59; the first case pressing: 24]; stays at 0.6",
		[leans, stays], [[11, 46, 59, 24], [false, true, true, false]])
	var rows: Array = []
	for f in [0.0, 1.0]:
		var row: Array = []
		for s in cases:
			row.append(ComboPlanner.wants_stay(s, f))
		rows.append(row)
	var tokenless := cases[1]
	tokenless.needs_token = true
	tokenless.has_token = false
	rows.append(ComboPlanner.wants_stay(tokenless, 1.0))
	_check("follow_through 0: always a reset; 1: always a stay; its token gone: a reset", rows,
		[[false, false, false, false], [true, true, true, true], false])
	var held := SituationContext.new()
	var cc_rows: Array = [ComboPlanner.can_crowd_control(held, 0.7)]
	held.target_held_left = 0.5
	cc_rows.append(ComboPlanner.can_crowd_control(held, 0.7))
	held.target_held_left = 1.0
	cc_rows.append(ComboPlanner.can_crowd_control(held, 0.7))
	held.target_held_left = 0.0
	held.target_cc_immune = true
	cc_rows.append(ComboPlanner.can_crowd_control(held, 0.7))
	_check("the no-waste rule for a 0.7 s crowd control: free, yes; held 0.5 s more, yes; held 1 s more, no; CC-immune, no", cc_rows, [true, true, false, false])


func _test_aid2_snapshot() -> void:
	_section("The snapshot's ultimates (the blind read): the Knight's Judgement")
	await _reset_knight()
	await _frames(2)
	var m := Brains.get_snapshot().get_member(knight)
	var up := [m.get("ultimates", -1), m.get("ultimates_ready", -1)]
	knight.abilities.start_cooldown(&"r")
	await _frames(2)
	m = Brains.get_snapshot().get_member(knight)
	_check("one ultimate, ready; Judgement spent: none ready", [up, [m.get("ultimates", -1), m.get("ultimates_ready", -1)]], [[1, 1], [1, 0]])
	_reset_cooldowns()


## A real duelist 170 px from the Knight, mixup and jitter 0 (its best plan),
## the press off (the heavy-hit window doesn't space its steps); the record of
## its casts, its hits on the Knight and its plans' ends: {casts: [[slot,
## t]], hits: [[ability id, t]], ended: [[plan id, reason]], started: [plan
## ids]}. Free it with _free_plan_duelist().
func _plan_duelist(record: Dictionary) -> Enemy:
	_no_press()
	var e := _spawn(DUELIST_SCENE, knight.global_position + Vector2(170, 0), false)
	var brain := e.get_brain()
	brain.behavior.mixup = 0.0
	brain.behavior.jitter = 0.0
	record.casts = []
	record.hits = []
	record.ended = []
	record.started = []
	e.abilities.cast_started.connect(func(slot: StringName, _a: Ability, _c: CastContext) -> void: (record.casts as Array).append([slot, Brains.get_time()]))
	record.on_hit = func(ctx: HitContext) -> void:
		if ctx.source == e and ctx.target == knight and ctx.ability != null:
			(record.hits as Array).append([ctx.ability.id, Brains.get_time()])
	record.on_start = func(u: Unit, _t: Unit, plan: ComboPlan) -> void:
		if u == e:
			(record.started as Array).append(plan.id)
	record.on_end = func(u: Unit, _t: Unit, plan: ComboPlan, reason: StringName) -> void:
		if u == e:
			(record.ended as Array).append([plan.id, reason])
	Events.unit_hit.connect(record.on_hit)
	Events.combo_plan_started.connect(record.on_start)
	Events.combo_plan_ended.connect(record.on_end)
	return e


func _free_plan_duelist(e: Enemy, record: Dictionary) -> void:
	Events.unit_hit.disconnect(record.on_hit)
	Events.combo_plan_started.disconnect(record.on_start)
	Events.combo_plan_ended.disconnect(record.on_end)
	record.clear()   # its lambdas capture `record`: the cycle would outlive the test (a leak at exit)
	_restore_press()
	await _free_duelist(e)


## The time of the first record row with `key` (a slot or an ability id), −1.
func _first_at(rows: Array, key: StringName) -> float:
	for r: Array in rows:
		if r[0] == key:
			return float(r[1])
	return -1.0


func _test_aid2_snare_first() -> void:
	_section("snare_first, end to end (a real duelist, his escapes down): the snare; the strike on the tick the root lands; the finisher on the tick the strike lands (since ARCHETYPES AR2 a perilous 0.9 s windup: it lands after the 1 s root ends, so it can be dashed); its own steps wait no reaction time")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	knight.abilities.start_cooldown(&"e")
	knight.abilities.start_cooldown(&"w")
	var record := {}
	var e := _plan_duelist(record)
	var brain := e.get_brain()
	await _wait_until(func() -> bool: return not (record.ended as Array).is_empty(), 360)
	var casts: Array = []
	for c: Array in record.casts:
		casts.append(c[0])
	var snare_hit := _first_at(record.hits, D_SNARE.id)
	var strike_cast := _first_at(record.casts, &"e")
	var strike_hit := _first_at(record.hits, D_STRIKE.id)
	var finisher_cast := _first_at(record.casts, &"r")
	var finisher_hit := _first_at(record.hits, D_FINISHER.id)
	var tick := 1.0 / 60.0 + 0.001
	_check("it ran snare_first to its end: started once, done; casts q, e, r; all three landed",
		[record.started, record.ended, casts.slice(0, 3), [snare_hit >= 0.0, strike_hit >= 0.0, finisher_hit >= 0.0]],
		[[&"snare_first"], [[&"snare_first", ComboPlanner.DONE]], [&"q", &"e", &"r"], [true, true, true]])
	var dash: float = D_STRIKE.get(&"dash_time")
	_check("the strike starts on the tick the snare lands (got %.3f s after; its reaction time is %.2f s); the finisher as the strike lands, or as its %.2f s dash ends when the hit came mid-dash (%.3f s; it can't cast while it dashes)" % [strike_cast - snare_hit, brain.behavior.reaction_time, dash, finisher_cast - strike_hit],
		[strike_cast - snare_hit >= -0.0001 and strike_cast - snare_hit <= tick, finisher_cast - strike_hit >= -0.0001 and finisher_cast - strike_hit <= dash + tick], [true, true])
	_check("the finisher (perilous since AR2: 0.9 s) lands after the snare's 1 s root ends, so he could dash it (%.2f s after the snare)" % (finisher_hit - snare_hit), finisher_hit - snare_hit > 1.0, true)
	await _free_plan_duelist(e, record)


func _test_aid2_missed_opener() -> void:
	_section("Its snare dodged (the Knight steps 3 m aside as it's cast): at combo_greed 0 with the blind reads off the plan ends (missed), no finisher; at 1 it carries on; with the blind read (his escapes down) it carries on without a roll")
	var saved := Brains.table.blind_reads
	var off: Dictionary[StringName, bool] = {}
	for c: Array in [[0.0, false, ComboPlanner.MISSED, false, "end"], [1.0, false, ComboPlanner.DONE, true, "carry on (0."], [0.0, true, ComboPlanner.DONE, true, "carry on (blind: escapes down)"]]:
		Brains.table.blind_reads = saved if c[1] else off
		await _reset_knight()
		await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
		knight.abilities.start_cooldown(&"e")
		knight.abilities.start_cooldown(&"w")
		var record := {}
		var e := _plan_duelist(record)
		var brain := e.get_brain()
		brain.behavior.combo_greed = c[0]
		var sidestep := func(slot: StringName, _a: Ability, _c: CastContext) -> void:
			if slot == &"q":
				_place(knight, knight.global_position + Vector2(0, 96))
		e.abilities.cast_started.connect(sidestep)
		await _wait_until(func() -> bool: return not (record.ended as Array).is_empty(), 420)
		var casts: Array = []
		for r: Array in record.casts:
			casts.append(r[0])
		_check("combo_greed %.0f, blind reads %s: the snare missed; ends %s; the finisher cast %s; `missed: %s...`" % [c[0], "on" if c[1] else "off", c[2], c[3], c[4]],
			[_first_at(record.hits, D_SNARE.id) < 0.0, record.ended.slice(0, 1), casts.has(&"r"), brain.get_last_carry().begins_with(c[4])],
			[true, [[&"snare_first", c[2]]], c[3], true])
		await _free_plan_duelist(e, record)
	Brains.table.blind_reads = saved


func _test_aid2_strike_plans() -> void:
	_section("Its snare down: strike_finish (blind: his escapes down) opens with the strike, finishes as it lands, never waits for the snare; his kit up and healthy: no plan fits and it keeps its follow-ups; Judgement down: blind again")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	knight.abilities.start_cooldown(&"e")
	knight.abilities.start_cooldown(&"w")
	var record := {}
	var e := _plan_duelist(record)
	e.abilities.start_cooldown(&"q")
	await _wait_until(func() -> bool: return not (record.ended as Array).is_empty(), 360)
	var casts: Array = []
	for r: Array in record.casts:
		casts.append(r[0])
	_check("strike_finish: the strike, then the finisher as it lands; done", [record.started, casts.slice(0, 2), record.ended],
		[[&"strike_finish"], [&"e", &"r"], [[&"strike_finish", ComboPlanner.DONE]]])
	await _free_plan_duelist(e, record)

	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	knight.resource_pool.restore(1000.0)   # Cleave payable: his whole kit up
	knight.status_component.apply_status(_tag_status(&"test_unstoppable", [&"unstoppable"]))
	record = {}
	e = _plan_duelist(record)
	var brain := e.get_brain()
	brain.behavior.patience_time = 0.5   # it commits soon
	e.abilities.start_cooldown(&"q")
	var committed := [false]
	for i in 300:
		await get_tree().physics_frame
		committed[0] = committed[0] or brain.is_committing()
		knight.resource_pool.restore(1000.0)
	casts = []
	for r: Array in record.casts:
		casts.append(r[0])
	_check("his kit up, healthy, not held: it commits (%s) but runs no plan and casts neither its strike nor its finisher in 5 s (its follow-ups kept; blind read `%s`)" % [committed[0], brain.get_situation().blind_reason],
		[committed[0], brain.plan_count, casts.has(&"e"), casts.has(&"r")], [true, 0, false, false])
	knight.abilities.start_cooldown(&"r")
	await _wait_until(func() -> bool: return not (record.started as Array).is_empty(), 300)
	_check("Judgement spent (ultimate down): blind, so its strike plans fit again (%s)" % [record.started], record.started.slice(0, 1), [&"strike_finish"])
	knight.status_component.remove_status(&"test_unstoppable")
	await _free_plan_duelist(e, record)


func _test_aid2_follow_through() -> void:
	_section("The follow-through, for real: his kit spent, it stays (a new commit at once: its tell, its token kept, held 4 s again); at follow_through 0 it resets (patience 0, the token let go)")
	for stay in [true, false]:
		await _reset_knight()
		await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
		_spend_kit()
		var record := {}
		var e := _plan_duelist(record)
		var brain := e.get_brain()
		if not stay:
			brain.behavior.follow_through = 0.0
		var hold := [0.0]
		var plan_over := func() -> bool:
			if brain.get_plan() != null and hold[0] <= 0.0:
				hold[0] = Brains.get_token_hold_left(e)
			return not (record.ended as Array).is_empty()
		await _wait_until(plan_over, 360)
		var row := [brain.get_last_follow(), brain.is_committing(), Brains.has_token(e)]
		if stay:
			_check("its plan's token held up to plan_max_time (%.2f s left at its start); done, his kit spent (lean %.2f ≥ 0.40): stay, committing, its tell, its token held again for 4 s (%.2f)" % [hold[0], brain.get_last_lean(), Brains.get_token_hold_left(e)],
				[hold[0] > 5.5, row, brain.get_tell_left() > 0.0, Brains.get_token_hold_left(e) > 3.9 and Brains.get_token_hold_left(e) <= 4.0001],
				[true, [&"stay", true, true], true, true])
		else:
			_check("follow_through 0: reset (not committing, patience %.2f, the token let go)" % brain.get_patience(), [row, brain.get_patience()], [[&"reset", false, false], 0.0])
		await _free_plan_duelist(e, record)


func _test_aid2_token() -> void:
	_section("A plan never holds its token past plan_max_time (6 s): a test plan stuck waiting for a status ends there (token lost)")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	knight.abilities.start_cooldown(&"e")
	knight.abilities.start_cooldown(&"w")
	var record := {}
	var e := _plan_duelist(record)
	var stuck := _combo_plan([&"q", &"r"], [ComboStep.Timing.ON_STATUS], &"stuck")
	stuck.steps[1].status_tag = &"never"
	stuck.steps[1].window = 20.0
	var plans: Array[ComboPlan] = [stuck]
	e.get_brain()._plans = plans
	await _wait_until(func() -> bool: return not (record.started as Array).is_empty(), 240)
	var started := Brains.get_time()
	await _wait_until(func() -> bool: return not (record.ended as Array).is_empty(), 480)
	var took := Brains.get_time() - started
	_check("it ended after %.2f s (6 s), its token lost" % took, [record.ended, took >= 5.9 and took <= 6.15], [[[&"stuck", ComboPlanner.TOKEN_LOST]], true])
	await _free_plan_duelist(e, record)


func _test_aid2_ends() -> void:
	_section("A plan's other ends (snare_first, after its snare lands): stunned (interrupted), him untargetable (target lost), the strike out of reach (window), its health under a fall-back role's retreat health (low health), the ally coming in (odds)")
	var saved_leash := Brains.table.leash_px
	Brains.table.leash_px = 5000.0
	for c in [ComboPlanner.INTERRUPTED, ComboPlanner.TARGET_LOST, ComboPlanner.WINDOW, ComboPlanner.LOW_HEALTH, ComboPlanner.ODDS]:
		await _reset_knight()
		await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
		knight.abilities.start_cooldown(&"e")
		knight.abilities.start_cooldown(&"w")
		var record := {}
		var e := _plan_duelist(record)
		var brain := e.get_brain()
		if c == ComboPlanner.LOW_HEALTH:
			brain.behavior.low_health = EnemyBehavior.LowHealth.FALL_BACK
		await _wait_until(func() -> bool: return _first_at(record.hits, D_SNARE.id) >= 0.0, 300)
		var friend: Enemy = null
		if c == ComboPlanner.INTERRUPTED:
			await _wait_until(func() -> bool: return e.abilities.casting, 30)
			e.status_component.apply_status(load("res://data/statuses/status_stun.tres"), knight)
		elif c == ComboPlanner.TARGET_LOST:
			knight.status_component.apply_status(_tag_status(&"test_untargetable", [&"untargetable"]))
		elif c == ComboPlanner.WINDOW:
			await _wait_until(func() -> bool: return not e.abilities.casting, 30)
			_place(knight, e.global_position + (knight.global_position - e.global_position).normalized() * 400.0)
		elif c == ComboPlanner.LOW_HEALTH:
			e.health.take_damage(e.health.max_health * 0.7)
		elif c == ComboPlanner.ODDS:
			friend = _friend(knight.global_position + Vector2(-60, 0))
		await _wait_until(func() -> bool: return not (record.ended as Array).is_empty(), 180)
		_check("%s: the plan ends so" % c, record.ended.slice(0, 1), [[&"snare_first", c]])
		knight.status_component.remove_status(&"test_untargetable")
		if friend != null:
			friend.queue_free()
		await _free_plan_duelist(e, record)
	Brains.table.leash_px = saved_leash


func _test_aid2_sandbox() -> void:
	_section("The overlay's plan lines (AI-D2): the plan under way, its end and the follow-through, the blind read")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	_spend_kit()
	var record := {}
	var e := _plan_duelist(record)
	var overlay := SandboxBrains.new()   # its combo lines only (not in the tree)
	var texts := {}
	for i in 360:
		await get_tree().physics_frame
		for line in overlay.get_combo_text(e).split("\n"):
			texts[line] = true
		if not (record.ended as Array).is_empty() and i > 0:
			for j in 3:
				await get_tree().physics_frame
				for line in overlay.get_combo_text(e).split("\n"):
					texts[line] = true
			break
	overlay.free()
	var running := false
	var after := false
	var blind := false
	for line: String in texts:
		running = running or line.begins_with("plan: snare_first 2/3 (Strike)")
		after = after or (line.begins_with("plan: snare_first done, after: ") and line.contains("(lean "))
		blind = blind or line == "blind: escapes down"
	_check("`plan: snare_first 2/3 (Strike)` while it runs, `plan: snare_first done, after: stay (lean ...)` after it, `blind: escapes down`",
		[running, after, blind], [true, true, true])
	await _free_plan_duelist(e, record)


# --- AI-D3: diminishing returns on crowd control (ENEMIES_AI.md, Being combo'd) ----------------

const STATUS_STUN: StatusEffect = preload("res://data/statuses/status_stun.tres")
## The crowd control an enemy may put on the player at first (Ryan,
## 2026-10-05): a root up to 1 s, a short stun up to 0.5 s.
const PLAYER_CC_MAX := {&"root": 1.0, &"stun": 0.5}


func _test_aid3_rank_rules() -> void:
	_section("AI-D3: diminishing returns by rank (RankRules.cc_diminishing, given at spawn): fodder takes crowd control in full; poise is a hook, off")
	var on: Array = []
	var poise: Array = []
	for rank in [EnemyData.Rank.FODDER, EnemyData.Rank.REGULAR, EnemyData.Rank.ELITE, EnemyData.Rank.BOSS]:
		var rules := Brains.table.get_rank_rules(rank)
		on.append(rules.cc_diminishing)
		poise.append(rules.poise)
	_check("fodder, regular, elite, boss: off, on, on, on; poise off for all four", [on, poise], [[false, true, true, true], [false, false, false, false]])
	var slime := _spawn(SLIME_SCENE, ARENA + Vector2(-200, 400), true)
	var brute := _spawn(BRUTE_SCENE, ARENA + Vector2(0, 400), true)
	var elite := _spawn(ELITE_SCENE, ARENA + Vector2(200, 400), true)
	await _frames(1)
	var spawned: Array = []
	for e: Enemy in [slime, brute, elite]:
		spawned.append([e.status_component.cc_diminishing, e.status_component.poise])
	_check("at spawn: the slime off, the test brute and the elite slime on; no poise", spawned, [[false, false], [true, false], [true, false]])
	for e: Enemy in [slime, brute, elite]:
		e.queue_free()
	await _frames(2)


## The crowd control an ability's data puts on what it hits, as [status,
## duration] pairs: a `cc` StatusEffect (or a list of them) among its
## exports, its conditional bonuses' target statuses, and a `stun_duration`
## param (a stun its script applies). The same places
## EnemyAITable.applies_cc() reads.
func _cc_applied_by(ability: Ability) -> Array:
	var out: Array = []
	if ability.has_param(&"stun_duration") and ability.get_base_param(&"stun_duration") > 0.0:
		out.append([STATUS_STUN, ability.get_base_param(&"stun_duration")])
	for p in ability.get_property_list():
		if not (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var value: Variant = ability.get(p.name)
		var values: Array = value if value is Array else [value]
		for v: Variant in values:
			if v is StatusEffect and (v as StatusEffect).is_cc():
				out.append([v, (v as StatusEffect).duration])
	for bonus in ability.conditional_bonuses:
		if bonus == null:
			continue
		for e in bonus.target_statuses:
			if e != null and e.is_cc():
				out.append([e, e.duration])
	return out


## Breaches of the player's crowd control at first: anything but a root up to
## 1 s or a stun up to 0.5 s (a slow, a silence, a knock-up are later).
func _player_cc_breaches(abilities: Array) -> Array:
	var out: Array = []
	for a: Ability in abilities:
		for pair: Array in _cc_applied_by(a):
			var status: StatusEffect = pair[0]
			var kind := &"root" if status.tags.has(&"root") else (&"stun" if status.tags.has(&"stun") else &"")
			if kind == &"" or float(pair[1]) > float(PLAYER_CC_MAX[kind]) + 0.0001:
				out.append("%s: %s %.2f s" % [a.id, status.id, float(pair[1])])
	return out


func _test_aid3_enemy_cc() -> void:
	_section("AI-D3: the crowd control enemies put on the player at first (Ryan, 2026-10-05): a root up to 1 s, a stun up to 0.5 s; every enemy ability checked")
	var abilities: Array = []
	for k: String in LIBRARY:
		abilities.append(load(LIBRARY_DIR + "enemy_%s.tres" % k))
	for f in DirAccess.open(ENEMY_DATA_DIR).get_files():
		if f.ends_with(".tres"):
			for a: Ability in (load(ENEMY_DATA_DIR + f) as EnemyData).get_abilities_at(5).values():
				if not abilities.has(a):
					abilities.append(a)
	var found: Array = []
	for a: Ability in abilities:
		for pair: Array in _cc_applied_by(a):
			var row := "%s: %s %.2f s" % [a.id, (pair[0] as StatusEffect).id, float(pair[1])]
			if not found.has(row):
				found.append(row)
	found.sort()
	_check("of %d enemy abilities, those with crowd control (%s) keep the limits" % [abilities.size(), ", ".join(found)],
		[found.size() >= 3, _player_cc_breaches(abilities)], [true, []])
	var long_root := _bare_ability(0.7, 0.0)
	var root: StatusEffect = STATUS_ROOT.duplicate()
	root.duration = 1.5
	var bonus := ConditionalBonus.new()
	bonus.target_statuses = [root] as Array[StatusEffect]
	long_root.conditional_bonuses = [bonus] as Array[ConditionalBonus]
	var long_stun := _bare_ability(0.7, 0.0)
	var stun_bonus := ConditionalBonus.new()
	var stun: StatusEffect = STATUS_STUN.duplicate()
	stun.duration = 0.75
	stun_bonus.target_statuses = [stun] as Array[StatusEffect]
	long_stun.conditional_bonuses = [stun_bonus] as Array[ConditionalBonus]
	var slowing := _bare_ability(0.7, 0.0)
	var slow_bonus := ConditionalBonus.new()
	slow_bonus.target_statuses = [STATUS_SLOW] as Array[StatusEffect]
	slowing.conditional_bonuses = [slow_bonus] as Array[ConditionalBonus]
	_check("the check can fail: a 1.5 s root, a 0.75 s stun, a slow each break it; a 1 s root doesn't",
		[_player_cc_breaches([long_root]).size(), _player_cc_breaches([long_stun]).size(), _player_cc_breaches([slowing]).size(),
			_player_cc_breaches([_slot_ability(DUELIST_DATA, &"q")]).size()], [1, 1, 1, 0])


func _test_aid3_boss() -> void:
	_section("AI-D3: a boss, until poise exists: its 40% tenacity, then diminishing returns")
	var data: EnemyData = SLIME_DATA.duplicate()
	data.rank = EnemyData.Rank.BOSS
	var boss := SLIME_SCENE.instantiate() as Enemy
	boss.data = data
	boss.passive = true
	entities.add_child(boss)
	_place(boss, ARENA + Vector2(0, 500))
	await _frames(1)
	var sc := boss.status_component
	var times: Array = []
	for i in 3:
		times.append(sc.apply_status(STATUS_STUN, knight, 1.0))
		times.append(snappedf(sc.get_time_left(&"stun"), 0.001))
		sc.remove_status(&"stun")
	_check("tenacity 0.4, diminishing returns on, no poise; three 1 s stuns: 0.6 s, 0.3 s, refused (immune)",
		[snappedf(boss.stats_component.get_stat(&"tenacity"), 0.001), sc.cc_diminishing, sc.poise, times, sc.has_tag(&"cc_immune")],
		[0.4, true, false, [true, 0.6, true, 0.3, false, 0.0], true])
	boss.queue_free()
	await _frames(2)


func _test_aid3_brain_sees_the_ring() -> void:
	_section("AI-D3: the duelist reads only what the HUD shows: the immunity's ring (no snare thrown into it), not that a root would be halved")
	await _reset_knight()
	var e := _spawn(DUELIST_SCENE, knight.global_position + Vector2(170, 0), true)
	await _frames(1)
	e.status_component.apply_status(STATUS_STUN, null, 10.0)   # it stands still for the checks
	e.passive = false
	e.alert(knight)
	await _frames(1)
	var brain := e.get_brain()
	var sc := knight.status_component
	var rules := CrowdControlRules.new()   # short numbers: no lasting immunity for the later checks
	rules.dr_window = 0.5
	rules.dr_immune_time = 0.3
	rules.immune_status = sc.get_cc_rules().immune_status
	sc.cc_rules = rules
	sc.apply_status(STATUS_ROOT, e)
	sc.remove_status(&"root")
	sc.apply_status(STATUS_ROOT, e)
	sc.remove_status(&"root")
	var halved := brain.build_situation()
	var halved_row := [sc.get_dr_step(), halved.has_target, halved.target_cc_immune, ComboPlanner.can_crowd_control(halved, 0.7)]
	var refused := sc.apply_status(STATUS_ROOT, e)
	var immune := brain.build_situation()
	var immune_row := [refused, immune.target_cc_immune, ComboPlanner.can_crowd_control(immune, 0.7)]
	_check("his next root would be halved: the duelist sees nothing (not immune, its snare allowed); the third refused, the ring on: it sees it and holds its crowd control",
		[halved_row, immune_row], [[2, true, false, true], [false, true, false]])
	await _wait_until(func() -> bool: return not sc.has_tag(&"cc_immune"), 60)
	sc.cc_rules = null
	await _free_duelist(e)


func _test_aid3_panel_scroll() -> void:
	_section("The tuning panel (Ryan, at AI-D3): the mouse wheel scrolls its list and never nudges a slider")
	var sb := SandboxBrains.new()
	add_child(sb)
	await _frames(2)
	sb.set_panel(true)
	await _frames(2)
	var rows: Dictionary = sb.get(&"_rows")
	var wheel: Array = []
	for k: StringName in rows:
		if (rows[k].slider as HSlider).scrollable:
			wheel.append(k)
	var temp: HSlider = sb.get(&"_temp_slider")
	_check("none of its 23 rows' sliders takes the wheel (Slider.scrollable off), nor the TEMP row's",
		[rows.size(), wheel, temp != null and temp.scrollable], [23, [], false])
	sb.set_panel(false)
	sb.queue_free()
	await _frames(2)


# --- ARCHETYPES AR1a: strings, the beat and token holding ------------------------------------

const STRING_BRUTE: AttackCombo = preload("res://data/combos/combo_test_brute.tres")
const STRING_SKIRMISHER: AttackCombo = preload("res://data/combos/combo_test_skirmisher.tres")
const STRING_DUELIST: AttackCombo = preload("res://data/combos/combo_test_duelist.tres")
## Each test string's archetype shape (ARCHETYPES.md, Strings and the beat;
## D8): [its short end, its full length, its spacing hit to hit in s].
const STRING_TARGETS := {
	&"test_brute": [2, 3, 0.9], &"slime_elite": [2, 3, 0.9],   # Bruiser
	&"test_skirmisher": [2, 3, 0.35],                           # Skirmisher
	&"test_caster": [3, 3, 0.45], &"test_caster_elite": [3, 3, 0.45],   # Mage: the volley (AR1b)
	&"test_duelist": [4, 5, 0.5],                               # Duelist
	&"test_assassin": [3, 4, 0.4],                              # Assassin (AR3b)
}
## The authoring tolerance on a string's spacing (s; ARCHETYPES.md, Data).
const STRING_SPACING_TOLERANCE := 0.05


func _test_ar1a_data() -> void:
	_section("AR1a data: the table's beat and respect numbers, the ranks' string lengths, the new fields' defaults; every test string's shape, its first wind-up the beat, later wind-ups 0.25 s or more, its spacing (the last swing repeated too), deflectable swings with no hit feel in the chip band; none on the slime or the casters (AR1b)")
	var t := Brains.table
	_check("the table: the beat 0.5 s; respect at 0.6 or more cuts a string to 2 hits, at 0.3 or less runs it full",
		[t.beat, t.string_respect_short, t.string_respect_full, t.string_short_hits], [0.5, 0.6, 0.3, 2])
	var ranks: Array = []
	for rank in [EnemyData.Rank.FODDER, EnemyData.Rank.REGULAR, EnemyData.Rank.ELITE, EnemyData.Rank.BOSS]:
		var rules := t.get_rank_rules(rank)
		ranks.append([rules.string_full_range, rules.string_extra_hits])
	_check("the ranks (D8): fodder and regulars a string's short end; elites its full range; bosses its full range +1",
		ranks, [[false, 0], [false, 0], [true, 0], [true, 1]])
	var bare := AttackCombo.new()
	for i in 3:
		bare.swings.append(AttackSwing.new())
	var bare_min := bare.get_string_hits_min()
	bare.string_hits_min = 9
	_check("defaults: a plan step is an ABILITY step; a swing is deflectable; a string's short end 0 = all its swings (3), never past them (9 → 3); EnemyData has no string",
		[ComboStep.new().kind, AttackSwing.new().deflectable, bare_min, bare.get_string_hits_min(), EnemyData.new().attack_string],
		[ComboStep.Kind.ABILITY, true, 3, 3, null])
	var chip := CHIP_SHARE * knight.health.max_health
	var found: Array[String] = []
	var breaches: Array[String] = []
	var dir := DirAccess.open(ENEMY_DATA_DIR)
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		var d: EnemyData = load(ENEMY_DATA_DIR + f)
		if d.attack_string == null:
			continue
		found.append(String(d.id))
		var s := d.attack_string
		var shape: Array = STRING_TARGETS.get(d.id, [])
		if shape.is_empty():
			breaches.append("%s: no archetype shape in the test" % d.id)
			continue
		if [s.get_string_hits_min(), s.swings.size()] != [shape[0], shape[1]]:
			breaches.append("%s: %d–%d hits, not %d–%d" % [d.id, s.get_string_hits_min(), s.swings.size(), shape[0], shape[1]])
		if (s.attack_style == AttackCombo.AttackStyle.RANGED) != (d.behavior.role == EnemyBehavior.Role.CASTER):
			breaches.append("%s: a ranged string goes with a Mage (caster role) and only with one" % d.id)
		if not is_equal_approx(s.swings[0].windup, t.beat):
			breaches.append("%s: its first wind-up %.2f s, not the beat" % [d.id, s.swings[0].windup])
		for i in s.swings.size():
			var w := s.swings[i]
			if i > 0 and w.windup < FOLLOW_UP_MIN - 0.0001:
				breaches.append("%s hit %d: a %.2f s wind-up" % [d.id, i + 1, w.windup])
			var after := s.swings[mini(i + 1, s.swings.size() - 1)]
			var gap := (w.duration - w.windup) + w.pause_after + after.windup
			if absf(gap - float(shape[2])) > STRING_SPACING_TOLERANCE + 0.0001:
				breaches.append("%s hit %d → %d: %.2f s apart, not %.2f" % [d.id, i + 1, i + 2, gap, shape[2]])
			if not w.deflectable or w.feel != HitContext.Feel.NONE:
				breaches.append("%s hit %d: deflectable %s, feel %d" % [d.id, i + 1, w.deflectable, w.feel])
			if d.stats.attack_damage * w.ad_ratio > chip + 0.0001:
				breaches.append("%s hit %d: %.0f damage, over the chip band's %.1f" % [d.id, i + 1, d.stats.attack_damage * w.ad_ratio, chip])
	found.sort()
	_check("the test strings: the brute and the elite slime (Bruiser), the skirmisher, the duelist, the casters (AR1b, the volley), the Assassin (AR3b); none on the slime", found,
		["slime_elite", "test_assassin", "test_brute", "test_caster", "test_caster_elite", "test_duelist", "test_skirmisher"] as Array[String])
	_check("each string: Bruiser 2–3 at 0.9 s, Skirmisher 2–3 at 0.35 s, Duelist 4–5 at 0.5 s, Assassin 3–4 at 0.4 s, Mage a 3-bolt volley at 0.45 s (±%.2f s, the repeated last swing too); its first wind-up the beat, later ones %.2f s or more; melee (a Mage's ranged), deflectable, no hit feel, each hit %d%% of the Knight's health or less" % [STRING_SPACING_TOLERANCE, FOLLOW_UP_MIN, roundi(CHIP_SHARE * 100.0)],
		breaches, [] as Array[String])


func _test_ar1a_length() -> void:
	_section("A string's length (EnemyBrain.get_string_length(), pure; D6, D8): high respect 2 hits; low respect or a low target its rank's top, an elite or boss one more at its aggression; in between rolled in its rank's range (a regular: always its short end)")
	var t := Brains.table
	var reg := t.get_rank_rules(EnemyData.Rank.REGULAR)
	var elite := t.get_rank_rules(EnemyData.Rank.ELITE)
	var boss := t.get_rank_rules(EnemyData.Rank.BOSS)
	var calm: EnemyBehavior = BRUTE_BEHAVIOR.duplicate()
	calm.aggression = 0.0
	var wild: EnemyBehavior = BRUTE_BEHAVIOR.duplicate()
	wild.aggression = 1.0
	var stream := RandomNumberGenerator.new()
	stream.seed = 7
	var s := SituationContext.new()
	s.target_health_ratio = 1.0
	var lengths := func(rows: Array) -> Array:
		var out: Array = []
		for r: Array in rows:
			out.append(EnemyBrain.get_string_length(s, r[0], r[1], t, r[2], stream))
		return out
	s.effective_respect = 0.8
	_check("respect 0.8: 2 hits for a regular, an elite and a boss Bruiser, and the elite Duelist (cut from 4–5)",
		lengths.call([[STRING_BRUTE, reg, wild], [STRING_BRUTE, elite, wild], [STRING_BRUTE, boss, wild], [STRING_DUELIST, elite, wild]]), [2, 2, 2, 2])
	s.effective_respect = 0.6
	_check("respect 0.6 (the cut): 2 hits", lengths.call([[STRING_DUELIST, elite, wild]]), [2])
	s.effective_respect = 0.1
	_check("respect 0.1, aggression 0: a regular Bruiser 2, an elite 3, a boss 4; an elite Duelist 5, a boss 6",
		lengths.call([[STRING_BRUTE, reg, calm], [STRING_BRUTE, elite, calm], [STRING_BRUTE, boss, calm], [STRING_DUELIST, elite, calm], [STRING_DUELIST, boss, calm]]),
		[2, 3, 4, 5, 6])
	_check("respect 0.1, aggression 1: an elite or a boss one hit more (a regular never)",
		lengths.call([[STRING_BRUTE, reg, wild], [STRING_BRUTE, elite, wild], [STRING_BRUTE, boss, wild], [STRING_DUELIST, elite, wild]]), [2, 4, 5, 6])
	s.effective_respect = 0.3
	_check("respect 0.3 (the cut): its full length", lengths.call([[STRING_BRUTE, elite, calm]]), [3])
	s.effective_respect = 0.45
	s.target_health_ratio = 0.3
	_check("respect 0.45 with its target at 30% (under the table's 40%): its full length", lengths.call([[STRING_BRUTE, elite, calm], [STRING_DUELIST, elite, calm]]), [3, 5])
	s.target_health_ratio = 1.0
	var rolled := func(attack_string: AttackCombo, rules: RankRules) -> Array:
		var seen := {}
		for i in 300:
			seen[EnemyBrain.get_string_length(s, attack_string, rules, t, wild, stream)] = true
		var keys := seen.keys()
		keys.sort()
		return keys
	_check("respect 0.45: rolled in its rank's range over 300 rolls: a regular Bruiser {2}, an elite {2, 3}, a boss {2, 3, 4}; an elite Duelist {4, 5}",
		[rolled.call(STRING_BRUTE, reg), rolled.call(STRING_BRUTE, elite), rolled.call(STRING_BRUTE, boss), rolled.call(STRING_DUELIST, elite)],
		[[2], [2, 3], [2, 3, 4], [4, 5]])
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 99
	b.seed = 99
	var same := true
	for i in 50:
		same = same and EnemyBrain.get_string_length(s, STRING_DUELIST, boss, t, wild, a) == EnemyBrain.get_string_length(s, STRING_DUELIST, boss, t, wild, b)
	_check("no string 0 hits; no rank rules its short end; the same seed the same lengths",
		[EnemyBrain.get_string_length(s, null, elite, t, wild, stream), EnemyBrain.get_string_length(s, STRING_DUELIST, null, t, wild, stream), same], [0, 4, true])


## A passive `scene` enemy right by the Knight runs `hits` hits of
## `attack_string` at him (its first wind-up `opener`): each swing's start
## [index, time], each hit [index, time, he was in it], League-style windups,
## its end [completed, swung, time], in game time. The Knight is unstoppable
## (no push) and healed after.
func _run_string_at_knight(scene: PackedScene, attack_string: AttackCombo, hits: int, opener: float) -> Dictionary:
	var steady := _tag_status(&"test_unstoppable", [&"unstoppable"] as Array[StringName])
	knight.status_component.apply_status(steady)
	var e := _spawn(scene, knight.global_position + Vector2(52, 0), true)
	await get_tree().physics_frame
	var rec := {"started": [], "landed": [], "ended": [], "league": 0, "wound": false}
	var on_start := func(i: int, _d: Vector2, _s: AttackSwing) -> void: (rec.started as Array).append([i, Brains.get_time()])
	var on_land := func(i: int, targets: Array[Unit]) -> void: (rec.landed as Array).append([i, Brains.get_time(), targets.has(knight)])
	var on_end := func(done: bool, swung: int) -> void: (rec.ended as Array).append([done, swung, Brains.get_time()])
	var on_league := func(_t: Unit, _w: float) -> void: rec.league = int(rec.league) + 1
	e.attack.swing_started.connect(on_start)
	e.attack.swing_landed.connect(on_land)
	e.attack.string_ended.connect(on_end)
	e.attack.windup_started.connect(on_league)
	rec.ok = e.attack.run_string(knight, attack_string, hits, opener)
	rec.hits = e.attack.get_string_hits()
	rec.time_left = e.attack.get_string_time_left()
	await _wait_until(func() -> bool:
		rec.wound = bool(rec.wound) or e.attack.is_winding_up()
		return not (rec.ended as Array).is_empty(), 600)
	e.attack.swing_started.disconnect(on_start)
	e.attack.swing_landed.disconnect(on_land)
	e.attack.string_ended.disconnect(on_end)
	e.attack.windup_started.disconnect(on_league)
	e.queue_free()
	knight.status_component.remove_status(steady.id)
	knight.health.heal(100000.0)
	await _frames(2)
	return rec


## Seconds between rows' times (column 1).
func _gaps(rows: Array) -> Array:
	var out: Array = []
	for i in range(1, rows.size()):
		out.append(snappedf(float(rows[i][1]) - float(rows[i - 1][1]), 0.001))
	return out


func _all_near(values: Array, target: float, tolerance: float) -> bool:
	for v: float in values:
		if absf(v - target) > tolerance + 0.0001:
			return false
	return true


func _test_ar1a_timing() -> void:
	_section("run_string() on a passive enemy at the Knight: its first hit on the beat, then its spacing (a Bruiser's 0.9 s, the last swing repeated past its 3; a Skirmisher's 0.35 s with a 0.7 s opener; a Duelist's 0.5 s), the end at its last swing's end; a wind-up shows as one; no League-style windup")
	await _reset_knight()
	var t := Brains.table
	var tick := 1.0 / 60.0 + 0.001
	for c: Array in [[BRUTE_SCENE, STRING_BRUTE, 4, t.beat, 0.9, "the brute (Bruiser)"], [SKIRMISHER_SCENE, STRING_SKIRMISHER, 3, 0.7, 0.35, "the skirmisher"],
			[DUELIST_SCENE, STRING_DUELIST, 5, t.beat, 0.5, "the duelist"]]:
		var hits: int = c[2]
		var opener: float = c[3]
		var r: Dictionary = await _run_string_at_knight(c[0], c[1], hits, opener)
		var started: Array = r.started
		var landed: Array = r.landed
		var first := float(landed[0][1]) - float(started[0][1]) if not landed.is_empty() and not started.is_empty() else -1.0
		var indexes: Array = []
		var reached := true
		for row: Array in landed:
			indexes.append(row[0])
			reached = reached and bool(row[2])
		var span := float(r.ended[0][2]) - float(started[0][1]) if not (r.ended as Array).is_empty() and not started.is_empty() else -1.0
		_check("%s: it runs %d hits, all swung on him in order, then ends done" % [c[5], hits],
			[r.ok, r.hits, indexes, reached, (r.ended as Array).map(func(row: Array) -> Array: return row.slice(0, 2))],
			[true, hits, range(hits), true, [[true, hits]]])
		_check("%s: its first hit %.2f s after its wind-up starts (got %.3f s); then %.2f s apart (got %s)" % [c[5], opener, first, c[4], _gaps(landed)],
			[absf(first - opener) <= tick, _all_near(_gaps(landed), c[4], STRING_SPACING_TOLERANCE)], [true, true])
		_check("%s: it ends as its last swing ends, its rhythm's %.2f s from its first swing (got %.3f s); it winds up (is_winding_up()); no League-style windup" % [c[5], r.time_left, span],
			[absf(span - float(r.time_left)) <= 2.0 * tick, r.wound, r.league], [true, true, 0])


func _test_ar1a_cut() -> void:
	_section("A string cut short: a stun after its first hit (no swing after), cancel(), its attacker's death, its target turning untargetable; run_string() refused in combo mode, under a lock, for 0 hits or no string; the League-style attack after a string")
	await _reset_knight()
	var t := Brains.table
	var steady := _tag_status(&"test_unstoppable", [&"unstoppable"] as Array[StringName])
	knight.status_component.apply_status(steady)
	var cases := {}
	for how: StringName in [&"stun", &"cancel", &"death", &"untargetable"]:
		var e := _spawn(BRUTE_SCENE, knight.global_position + Vector2(52, 0), true)
		await get_tree().physics_frame
		var rec := {"started": 0, "landed": 0, "ended": []}
		var on_start := func(_i: int, _d: Vector2, _s: AttackSwing) -> void: rec.started = int(rec.started) + 1
		var on_land := func(_i: int, _targets: Array[Unit]) -> void: rec.landed = int(rec.landed) + 1
		var on_end := func(done: bool, count: int) -> void: (rec.ended as Array).append([done, count])
		e.attack.swing_started.connect(on_start)
		e.attack.swing_landed.connect(on_land)
		e.attack.string_ended.connect(on_end)
		e.attack.run_string(knight, STRING_BRUTE, 3, t.beat)
		var cloak := _tag_status(&"test_untargetable", [&"untargetable"] as Array[StringName])
		match how:
			&"stun":
				await _wait_until(func() -> bool: return int(rec.landed) >= 1, 120)
				e.status_component.apply_status(STATUS_STUN, knight)
				cases.refused_stunned = e.attack.run_string(knight, STRING_BRUTE, 3, t.beat)
			&"cancel":
				await _wait_until(func() -> bool: return int(rec.started) >= 1, 60)
				e.attack.cancel()
			&"death":
				await _wait_until(func() -> bool: return int(rec.started) >= 2, 120)
				e.health.take_damage(100000.0)
			&"untargetable":
				await _wait_until(func() -> bool: return int(rec.landed) >= 1, 120)
				knight.status_component.apply_status(cloak)
		var swung := int(rec.started)
		await _frames(60)
		cases[how] = [rec.ended, int(rec.started) == swung, e.attack.is_running_string() if is_instance_valid(e) else false]
		if how == &"untargetable":
			knight.status_component.remove_status(cloak.id)
		if is_instance_valid(e):
			e.attack.swing_started.disconnect(on_start)
			e.attack.swing_landed.disconnect(on_land)
			e.attack.string_ended.disconnect(on_end)
			e.queue_free()
		await _frames(2)
	_check("a stun after its first hit: cut short (1 swung), no swing after it; run_string() refused while stunned",
		[cases[&"stun"], cases.refused_stunned], [[[[false, 1]], true, false], false])
	_check("cancel() in its first wind-up: cut short (1 swung, no hit)", cases[&"cancel"], [[[false, 1]], true, false])
	_check("its death in its second swing: cut short (2 swung)", cases[&"death"], [[[false, 2]], true, false])
	_check("the Knight untargetable after its first hit: cut short", (cases[&"untargetable"][0] as Array).map(func(row: Array) -> bool: return row[0]), [false])
	var brute := _spawn(BRUTE_SCENE, knight.global_position + Vector2(52, 0), true)
	await get_tree().physics_frame
	var empty := AttackCombo.new()
	_check("refused: in combo mode (the Knight), 0 hits, no string, a string with no swings",
		[knight.attack.run_string(brute, STRING_BRUTE, 2, t.beat), brute.attack.run_string(knight, STRING_BRUTE, 0, t.beat),
			brute.attack.run_string(knight, null, 2, t.beat), brute.attack.run_string(knight, empty, 2, t.beat), brute.attack.is_running_string()],
		[false, false, false, false, false])
	var league := [0]
	var on_league := func(_t: Unit, _w: float) -> void: league[0] += 1
	brute.attack.windup_started.connect(on_league)
	brute.attack.run_string(knight, STRING_BRUTE, 2, t.beat)
	await _wait_until(func() -> bool: return not brute.attack.is_running_string(), 240)
	var during: int = league[0]
	brute.attack.attack(knight)
	await _wait_until(func() -> bool: return league[0] > during, 120)
	_check("after a string the League-style attack works again (no League windup during it, one after)", [during, league[0] > during], [0, true])
	brute.attack.windup_started.disconnect(on_league)
	brute.attack.cancel()
	brute.queue_free()
	knight.status_component.remove_status(steady.id)
	await _reset_knight()


func _test_ar1a_deflect_pair() -> void:
	_section("A deflect doesn't end a string (D10): with the Knight's test deflect on, a deflect pair inside one brute string (its first two hits), the riposte his, its third hit still on its rhythm")
	await _reset_knight()
	var t := Brains.table
	var was_on := DeflectComponent.deflect_test_enabled
	DeflectComponent.deflect_test_enabled = true
	var steady := _tag_status(&"test_unstoppable", [&"unstoppable"] as Array[StringName])
	knight.status_component.apply_status(steady)
	var e := _spawn(BRUTE_SCENE, knight.global_position + Vector2(52, 0), true)
	await get_tree().physics_frame
	var rec := {"landed": [], "ended": [], "deflects": []}
	var on_land := func(i: int, _targets: Array[Unit]) -> void: (rec.landed as Array).append([i, Brains.get_time()])
	var on_end := func(done: bool, swung: int) -> void: (rec.ended as Array).append([done, swung])
	var on_deflect := func(attacker: Unit, defender: Unit, _ctx: HitContext) -> void: (rec.deflects as Array).append([attacker == e, defender == knight])
	e.attack.swing_landed.connect(on_land)
	e.attack.string_ended.connect(on_end)
	Events.hit_deflected.connect(on_deflect)
	e.attack.run_string(knight, STRING_BRUTE, 3, t.beat)
	for k in 2:
		await _wait_until(func() -> bool:
			var next := e.attack.get_string_next_hit_in()
			return e.attack.get_string_swung() == k + 1 and next >= 0.0 and next <= 0.1, 180)
		knight.deflect_component.open_window()
		await _wait_until(func() -> bool: return (rec.landed as Array).size() >= k + 1, 60)
	await _wait_until(func() -> bool: return not (rec.ended as Array).is_empty(), 180)
	_check("both deflected (from it, by him); its string ran all 3 hits to its end; the riposte is his",
		[rec.deflects, rec.ended, knight.deflect_component.has_riposte()], [[[true, true], [true, true]], [[true, 3]], true])
	_check("its hits kept their 0.9 s rhythm through the deflects (got %s)" % [_gaps(rec.landed)], _all_near(_gaps(rec.landed), 0.9, STRING_SPACING_TOLERANCE), true)
	e.attack.swing_landed.disconnect(on_land)
	e.attack.string_ended.disconnect(on_end)
	Events.hit_deflected.disconnect(on_deflect)
	e.queue_free()
	knight.status_component.remove_status(DeflectComponent.get_riposte_status_id())
	knight.status_component.remove_status(steady.id)
	DeflectComponent.deflect_test_enabled = was_on
	await _frames(2)
	await _reset_knight()


## A real `scene` enemy `distance_px` (4.4 m) from the Knight, his kit spent (respect 0), its
## own abilities on cooldown, AI3b's confidence pinned: it commits into its
## string. Records each swing's start [index, time, it holds its token] and
## hit [index, time, token], its strings' ends [completed, swung, time], when
## its commit started, League-style windups and casts. `data`: in place of the
## scene's EnemyData.
func _committing_enemy(scene: PackedScene, rec: Dictionary, data: EnemyData = null, distance_px: float = 140.0) -> Enemy:
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	var steady := _tag_status(&"test_unstoppable", [&"unstoppable"] as Array[StringName])
	knight.status_component.apply_status(steady)
	_spend_kit()
	var e := scene.instantiate() as Enemy
	if data != null:
		e.data = data
	entities.add_child(e)
	_place(e, knight.global_position + Vector2(distance_px, 0))
	_pin_ai3(e)
	for slot in AbilityComponent.SLOTS:
		if e.abilities != null and e.abilities.get_ability(slot) != null:
			e.abilities.start_cooldown(slot)
	rec.started = []
	rec.landed = []
	rec.ended = []
	rec.commit_at = -1.0
	rec.league = 0
	rec.casts = 0
	rec.cast_rows = []
	rec.on_start = func(i: int, _d: Vector2, _s: AttackSwing) -> void: (rec.started as Array).append([i, Brains.get_time(), Brains.has_token(e)])
	rec.on_land = func(i: int, _targets: Array[Unit]) -> void: (rec.landed as Array).append([i, Brains.get_time(), Brains.has_token(e)])
	rec.on_end = func(done: bool, swung: int) -> void: (rec.ended as Array).append([done, swung, Brains.get_time()])
	rec.on_intent = func(intent: StringName) -> void:
		if intent == EnemyBrain.COMMIT and float(rec.commit_at) < 0.0:
			rec.commit_at = Brains.get_time()
	rec.on_league = func(_t: Unit, _w: float) -> void: rec.league = int(rec.league) + 1
	rec.on_cast = func(slot: StringName, _a: Ability, _c: CastContext) -> void:
		rec.casts = int(rec.casts) + 1
		(rec.cast_rows as Array).append([slot, Brains.get_time(), Brains.has_token(e)])
	e.attack.swing_started.connect(rec.on_start)
	e.attack.swing_landed.connect(rec.on_land)
	e.attack.string_ended.connect(rec.on_end)
	e.get_brain().intent_changed.connect(rec.on_intent)
	e.attack.windup_started.connect(rec.on_league)
	if e.abilities != null:
		e.abilities.cast_started.connect(rec.on_cast)
	return e


func _free_committing_enemy(e: Enemy, rec: Dictionary) -> void:
	if is_instance_valid(e):
		for pair: Array in [[e.attack.swing_started, rec.on_start], [e.attack.swing_landed, rec.on_land], [e.attack.string_ended, rec.on_end],
				[e.attack.windup_started, rec.on_league]]:
			if (pair[0] as Signal).is_connected(pair[1]):
				(pair[0] as Signal).disconnect(pair[1])
		var brain := e.get_brain()
		if brain != null and is_instance_valid(brain) and brain.intent_changed.is_connected(rec.on_intent):
			brain.intent_changed.disconnect(rec.on_intent)
		if e.abilities != null and e.abilities.cast_started.is_connected(rec.on_cast):
			e.abilities.cast_started.disconnect(rec.on_cast)
		e.passive = true
		e.attack.cancel()
		e.queue_free()
	rec.clear()   # its lambdas capture `rec`: the cycle would outlive the test (a leak at exit)
	knight.status_component.remove_status(&"test_unstoppable")
	await _frames(2)
	await _reset_knight()


func _test_ar1a_brain_commit() -> void:
	_section("A real brute (his kit spent: respect 0) commits into its string: its tell, its first hit on the beat (0.8 s or more from its commit), its second 0.9 s later, a regular's 2 hits; its token held at every swing (with token_hold_time cut to 1.6 s: the string stretches it) and let go at the end; no League-style windup; its abilities ready again after its first swing, no cast until its string ends; then it walks out. The elite slime: its 3–4")
	var t := Brains.table
	var tick := 1.0 / 60.0 + 0.001
	var hold_was := t.token_hold_time
	t.token_hold_time = 1.6   # shorter than its tell, its walk in and its string: the string must stretch its hold
	var rec := {}
	var e := await _committing_enemy(BRUTE_SCENE, rec)
	var brain := e.get_brain()
	await _wait_until(func() -> bool: return not (rec.started as Array).is_empty(), 900)
	for slot in AbilityComponent.SLOTS:
		if e.abilities.get_ability(slot) != null:
			e.abilities.reset_cooldown(slot)   # its smash and cleave arc ready mid-string: they wait
	await _wait_until(func() -> bool: return not (rec.ended as Array).is_empty(), 300)
	var ended_at := Brains.get_time()
	var casts_in_string: int = rec.casts
	t.token_hold_time = hold_was
	await _wait_until(func() -> bool: return not brain.is_committing(), 30)
	var after := [brain.is_committing(), Brains.has_token(e), brain.get_patience() < 0.2, brain.get_intent() != EnemyBrain.COMMIT,
		Brains.get_time() - ended_at <= 3.0 / 60.0 + 0.001]   # its own end, on the next think (not its token's slack running out)
	var started: Array = rec.started
	var landed: Array = rec.landed
	var tell := float(started[0][1]) - float(rec.commit_at) if not started.is_empty() else -1.0
	var first := float(landed[0][1]) - float(started[0][1]) if not landed.is_empty() and not started.is_empty() else -1.0
	_check("one string, a regular's 2 hits, done (last_string_hits 2)", [(rec.ended as Array).map(func(r: Array) -> Array: return r.slice(0, 2)), brain.last_string_hits, brain.string_count], [[[true, 2]], 2, 1])
	_check("its tell first (%.2f s from its commit to its first swing, at least %.2f), its first hit on the beat (%.3f s after its wind-up), so it reads %.2f s from its commit (0.8 or more)" % [tell, t.tell_time, first, tell + first],
		[tell >= t.tell_time - tick, absf(first - t.beat) <= tick, tell + first >= 0.8 - tick], [true, true, true])
	_check("its second hit 0.9 s after its first (got %s)" % [_gaps(landed)], _all_near(_gaps(landed), 0.9, STRING_SPACING_TOLERANCE), true)
	var held := true
	for row: Array in started + landed:
		held = held and bool(row[2])
	_check("its token held at every swing's start and hit; then let go, the commit over, its patience emptied (under 0.2: it refills from 0), its intent no longer commit, within 3 ticks of the end (its next think, not its token's slack: got %.3f s)" % (Brains.get_time() - ended_at),
		[held, after], [true, [false, false, true, true, true]])
	_check("no League-style windup; no cast during it though its abilities were ready again after its first swing", [rec.league, casts_in_string], [0, 0])
	await _free_committing_enemy(e, rec)
	rec = {}
	e = await _committing_enemy(ELITE_SCENE, rec)
	brain = e.get_brain()
	await _wait_until(func() -> bool: return not (rec.ended as Array).is_empty(), 900)
	_check("the elite slime (an elite Bruiser) at respect 0: its full 3 hits, or 4 at its aggression's chance (got %d), done, 0.9 s apart (got %s)" % [brain.last_string_hits, _gaps(rec.landed)],
		[brain.last_string_hits in [3, 4], (rec.ended as Array).map(func(r: Array) -> Array: return r.slice(0, 2)), _all_near(_gaps(rec.landed), 0.9, STRING_SPACING_TOLERANCE)],
		[true, [[true, brain.last_string_hits]], true])
	await _free_committing_enemy(e, rec)


func _test_ar1a_token_freed() -> void:
	_section("A string's token goes on a stun (the commit breaks off, its patience kept), a poise break (the prototype's meter on) and its death; a deflect doesn't end a brain's string either (the commit ends after its last hit)")
	var rec := {}
	var e := await _committing_enemy(BRUTE_SCENE, rec)
	var brain := e.get_brain()
	await _wait_until(func() -> bool: return (rec.landed as Array).size() >= 1, 900)
	var had := Brains.has_token(e)
	e.status_component.apply_status(STATUS_STUN, knight)
	await _frames(3)
	_check("stunned after its first hit: it held its token, then the string is cut, the token gone, the commit broken off with its patience kept",
		[had, e.attack.is_running_string(), Brains.has_token(e), brain.is_committing(), brain.get_patience()], [true, false, false, false, 1.0])
	await _free_committing_enemy(e, rec)
	# With no token, the string's own cut is the only thing that breaks the commit off.
	var tokenless: EnemyData = BRUTE_DATA.duplicate()
	tokenless.behavior = BRUTE_BEHAVIOR.duplicate()
	tokenless.behavior.uses_tokens = false
	rec = {}
	e = await _committing_enemy(BRUTE_SCENE, rec, tokenless)
	brain = e.get_brain()
	await _wait_until(func() -> bool: return (rec.landed as Array).size() >= 1, 900)
	e.status_component.apply_status(STATUS_STUN, knight)
	await _frames(3)
	_check("a brute that takes no token, stunned after its first hit: the string cut and the commit broken off by the cut itself (no token to lose), its patience kept",
		[Brains.get_token_cost(e), e.attack.is_running_string(), brain.get_patience()], [0, false, 1.0])
	await _free_committing_enemy(e, rec)
	var poise_was := PoiseComponent.poise_test_enabled
	PoiseComponent.poise_test_enabled = true
	rec = {}
	e = await _committing_enemy(ELITE_SCENE, rec)
	brain = e.get_brain()
	await _wait_until(func() -> bool: return (rec.started as Array).size() >= 1, 900)
	had = Brains.has_token(e)
	e.poise_component.take_poise_damage(1000.0, knight)
	await _frames(3)
	_check("the elite slime's poise broken in its first swing: it held its token, then the string is cut, the token gone, the commit broken off",
		[had, e.poise_component.is_broken(), e.attack.is_running_string(), Brains.has_token(e), brain.is_committing()], [true, true, false, false, false])
	await _free_committing_enemy(e, rec)
	PoiseComponent.poise_test_enabled = poise_was
	rec = {}
	e = await _committing_enemy(BRUTE_SCENE, rec)
	await _wait_until(func() -> bool: return (rec.started as Array).size() >= 1, 900)
	had = Brains.has_token(e)
	var gone := e   # (freed below: read it before)
	e.health.take_damage(100000.0)
	await _frames(3)
	_check("killed in its first swing: it held its token, then none (Brains frees a dead holder's)", [had, Brains.has_token(gone)], [true, false])
	await _free_committing_enemy(e, rec)
	var was_on := DeflectComponent.deflect_test_enabled
	DeflectComponent.deflect_test_enabled = true
	rec = {}
	e = await _committing_enemy(BRUTE_SCENE, rec)
	brain = e.get_brain()
	await _wait_until(func() -> bool:
		var next := e.attack.get_string_next_hit_in()
		return e.attack.get_string_swung() == 1 and next >= 0.0 and next <= 0.1, 900)
	var deflects := [0]
	var on_deflect := func(attacker: Unit, _d: Unit, _c: HitContext) -> void:
		if attacker == e:
			deflects[0] += 1
	Events.hit_deflected.connect(on_deflect)
	knight.deflect_component.open_window()
	await _wait_until(func() -> bool: return (rec.landed as Array).size() >= 1, 60)
	var committing_after := brain.is_committing() and Brains.has_token(e)
	await _wait_until(func() -> bool: return not (rec.ended as Array).is_empty(), 180)
	_check("its first hit deflected: still committing with its token, its second hit swung, the string done",
		[deflects[0], committing_after, (rec.ended as Array).map(func(r: Array) -> Array: return r.slice(0, 2))], [1, true, [[true, 2]]])
	Events.hit_deflected.disconnect(on_deflect)
	knight.status_component.remove_status(DeflectComponent.get_riposte_status_id())
	DeflectComponent.deflect_test_enabled = was_on
	await _free_committing_enemy(e, rec)


func _test_ar1a_skirmisher() -> void:
	_section("The skirmisher with its string (D6: 2–3 fast hits, then its reset): it leaps in, strings its 2 hits 0.35 s apart, then hops out and resets, recoiling")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	_spend_kit()
	var sk := _spawn(SKIRMISHER_SCENE, knight.global_position + Vector2(170, 0), false)
	_pin_ai3(sk)
	sk.abilities.start_cooldown(&"w")   # its leap only: the stab and the flurry would go first in reach
	sk.abilities.start_cooldown(&"e")
	var brain := sk.get_brain()
	var rec := {"leaps": 0, "landed": [], "ended": [], "reset_at": -1.0}
	var on_cast := func(slot: StringName, _a: Ability, _c: CastContext) -> void:
		if slot == &"q":
			rec.leaps = int(rec.leaps) + 1
	var on_land := func(i: int, _targets: Array[Unit]) -> void: (rec.landed as Array).append([i, Brains.get_time()])
	var on_end := func(done: bool, swung: int) -> void: (rec.ended as Array).append([done, swung, Brains.get_time()])
	sk.abilities.cast_started.connect(on_cast)
	sk.attack.swing_landed.connect(on_land)
	sk.attack.string_ended.connect(on_end)
	await _wait_until(func() -> bool: return brain.is_resetting(), 480)
	var reset_at := Brains.get_time()
	var pose := sk.get_pose()
	var ended: Array = rec.ended
	_check("it leapt once, then its string: 2 hits, done, 0.35 s apart (got %s); then it resets (after the string's end), recoiling" % [_gaps(rec.landed)],
		[rec.leaps, ended.map(func(r: Array) -> Array: return r.slice(0, 2)), _all_near(_gaps(rec.landed), 0.35, STRING_SPACING_TOLERANCE),
			not ended.is_empty() and reset_at >= float(ended[0][2]), pose],
		[1, [[true, 2]], true, true, &"recoil"])
	sk.abilities.cast_started.disconnect(on_cast)
	sk.attack.swing_landed.disconnect(on_land)
	sk.attack.string_ended.disconnect(on_end)
	sk.passive = true
	sk.attack.cancel()
	sk.queue_free()
	await _reset_knight()
	await _frames(30)


func _test_ar1a_plan_step() -> void:
	_section("A plan's STRING step (ComboStep.Kind.STRING): the duelist's snare, then its string as the plan's second step once the snare's cast ends, its token held through it, the plan done when the string ends; a string as a plan's opener never fits")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	knight.abilities.start_cooldown(&"e")   # his escapes down: it sets up (as snare_first's test)
	knight.abilities.start_cooldown(&"w")
	var record := {}
	var e := _plan_duelist(record)
	var brain := e.get_brain()
	var plan := _combo_plan([&"q", &"q"], [ComboStep.Timing.AFTER_ENDED], &"snare_string")
	plan.steps[1].kind = ComboStep.Kind.STRING
	var plans: Array[ComboPlan] = [plan]
	brain._plans = plans
	var rows := {"started": [], "ended": []}
	var on_start := func(i: int, _d: Vector2, _s: AttackSwing) -> void: (rows.started as Array).append([i, Brains.get_time(), brain.get_string_step(), Brains.has_token(e)])
	var on_end := func(done: bool, swung: int) -> void: (rows.ended as Array).append([done, swung])
	e.attack.swing_started.connect(on_start)
	e.attack.string_ended.connect(on_end)
	await _wait_until(func() -> bool: return not (record.ended as Array).is_empty(), 480)
	var casts: Array = []
	for c: Array in record.casts:
		casts.append(c[0])
	var snare_at := _first_at(record.casts, &"q")
	var started: Array = rows.started
	var steps := true
	var tokens := true
	for r: Array in started:
		steps = steps and int(r[2]) == 1
		tokens = tokens and bool(r[3])
	var after_snare := not started.is_empty() and snare_at >= 0.0 and float(started[0][1]) - snare_at >= D_SNARE.cast_time - 0.02
	_check("snare_string ran to its end: started once, done; its one cast the snare (q), none during its string", [record.started, record.ended, casts],
		[[&"snare_string"], [[&"snare_string", ComboPlanner.DONE]], [&"q"]])
	_check("its string as step 2 (every swing), after the snare's %.1f s cast, its token held through it; done with its %d hits" % [D_SNARE.cast_time, brain.last_string_hits],
		[steps, after_snare, tokens, rows.ended], [true, true, true, [[true, brain.last_string_hits]]])
	e.attack.swing_started.disconnect(on_start)
	e.attack.string_ended.disconnect(on_end)
	var opener := _combo_plan([&"q", &"e"], [], &"string_first")
	opener.steps[0].kind = ComboStep.Kind.STRING
	var only: Array[ComboPlan] = [opener]
	brain._plans = only
	await _wait_until(func() -> bool: return not brain.is_committing(), 360)
	var s := brain.build_situation()
	_check("a plan opening with its string never fits (its option isn't ready)", s.plan_options.map(func(o: Dictionary) -> bool: return o.ready), [false])
	await _free_plan_duelist(e, record)


func _test_ar1a_sandbox() -> void:
	_section("The overlay's string line (SandboxBrains): `string 0/2 (closing in)` before its first swing, `string 1/2 (next hit …)` while it swings, nothing after")
	await _reset_knight()
	var steady := _tag_status(&"test_unstoppable", [&"unstoppable"] as Array[StringName])
	knight.status_component.apply_status(steady)
	var e := _spawn(BRUTE_SCENE, knight.global_position + Vector2(150, 0), true)
	await get_tree().physics_frame
	var overlay := SandboxBrains.new()   # its string line only (not in the tree)
	var before := overlay.get_string_text(e)
	e.attack.run_string(knight, STRING_BRUTE, 2, Brains.table.beat)
	var texts := {}
	for i in 240:
		await get_tree().physics_frame
		texts[overlay.get_string_text(e)] = true
		if not e.attack.is_running_string():
			break
	var closing := false
	var first := false
	var second := false
	for line: String in texts:
		closing = closing or line == "string 0/2 (closing in)"
		first = first or line.begins_with("string 1/2 (next hit 0.")
		second = second or line.begins_with("string 2/2")
	_check("nothing before, `closing in`, `string 1/2 (next hit 0.…)`, `string 2/2`, nothing after", [before, closing, first, second, overlay.get_string_text(e)], ["", true, true, true, ""])
	overlay.free()
	e.queue_free()
	knight.status_component.remove_status(steady.id)
	await _frames(2)


func _test_ar1a_mix() -> void:
	_section("The mix (Ryan, 2026-10-08: \"a mix of A and B\"): a real brute with its smash and cleave arc ready rolls once a commit; at string_then_cast_chance 1 its string comes first and a damage cast after it as its finisher, token held, the commit ending with the cast; at 0 the cast goes first and no string swings")
	var t := Brains.table
	var tick := 1.0 / 60.0 + 0.001
	_check("the table: string_then_cast_chance 0.5, string_finisher_wait 0.3 s", [_mix_saved, t.string_finisher_wait], [0.5, 0.3])
	t.string_then_cast_chance = 1.0
	var rec := {}
	var e := await _committing_enemy(BRUTE_SCENE, rec)
	var brain := e.get_brain()
	e.abilities.reset_cooldown(&"q")   # its smash and cleave arc ready; its charge (the gap-closer) stays down
	e.abilities.reset_cooldown(&"w")
	await _wait_until(func() -> bool: return not (rec.ended as Array).is_empty(), 900)
	var ended: Array = rec.ended
	var string_end := float(ended[0][2]) if not ended.is_empty() else INF
	await _wait_until(func() -> bool: return not (rec.cast_rows as Array).is_empty() or not brain.is_committing(), 60)
	var casts: Array = rec.cast_rows
	var during_cast := brain.is_committing()
	await _wait_until(func() -> bool: return not brain.is_committing(), 240)
	var commit_end := Brains.get_time()
	var cast_at := float(casts[0][1]) if not casts.is_empty() else -1.0
	var cast_slot: StringName = casts[0][0] if not casts.is_empty() else &""
	var cast_time := 0.0 if casts.is_empty() else float(e.abilities.get_ability(cast_slot).get_param(e, &"cast_time"))
	_check("1: its string first (2 hits, done, no cast before its end), then its finisher (%s) %.2f s after it (within %.1f s), its token held, inside the commit" % [cast_slot, cast_at - string_end, t.string_finisher_wait],
		[ended.map(func(r: Array) -> Array: return r.slice(0, 2)), cast_at >= string_end, cast_at - string_end <= t.string_finisher_wait + tick,
			cast_slot in [&"q", &"w"], not casts.is_empty() and bool(casts[0][2]), during_cast],
		[[[true, 2]], true, true, true, true, true])
	_check("1: the commit ends with its finisher's cast (%.2f s after it started; its cast %.2f s)" % [commit_end - cast_at, cast_time], commit_end - cast_at >= cast_time - tick, true)
	await _free_committing_enemy(e, rec)
	rec = {}
	e = await _committing_enemy(BRUTE_SCENE, rec, null, 200.0)
	e.abilities.reset_cooldown(&"e")   # only its charge ready (a gap-closer), the Knight out of its reach
	await _wait_until(func() -> bool: return not (rec.cast_rows as Array).is_empty() or not (rec.started as Array).is_empty(), 900)
	var first_cast := float(rec.cast_rows[0][1]) if not (rec.cast_rows as Array).is_empty() else INF
	var first_swing := float(rec.started[0][1]) if not (rec.started as Array).is_empty() else INF
	_check("1, with only its charge ready and him out of reach: the gap-closer (its charge, e) still goes first, its string after", [rec.cast_rows[0][0] if not (rec.cast_rows as Array).is_empty() else &"", first_cast < first_swing], [&"e", true])
	await _free_committing_enemy(e, rec)
	t.string_then_cast_chance = 0.0
	rec = {}
	e = await _committing_enemy(BRUTE_SCENE, rec)
	brain = e.get_brain()
	e.abilities.reset_cooldown(&"q")
	e.abilities.reset_cooldown(&"w")
	await _wait_until(func() -> bool: return not (rec.cast_rows as Array).is_empty(), 900)
	await _wait_until(func() -> bool: return not brain.is_committing(), 240)
	_check("0: its cast went first (%s) and the commit ended with it: no string swing" % [(rec.cast_rows as Array).map(func(r: Array) -> StringName: return r[0])],
		[(rec.cast_rows as Array).size(), (rec.started as Array).size(), brain.is_committing()], [1, 0, false])
	await _free_committing_enemy(e, rec)


# --- ARCHETYPES AR1b: the Mage's volley (RANGED strings) -------------------------------------

const STRING_CASTER: AttackCombo = preload("res://data/combos/combo_test_caster.tres")


func _test_ar1b_data() -> void:
	_section("AR1b data: the volley (combo_test_caster.tres): RANGED, 3 bolts (a regular's and an elite's 3, a boss's up to 4), each 750 u/s, 950 u, 30 u wide; both test casters carry it; the caster preset commits (weight 1, was 0: its volley is its commit); every caster-role enemy that commits has a ranged string")
	var t := Brains.table
	var b0 := STRING_CASTER.swings[0]
	_check("RANGED, 3 swings, its short end 3; a bolt 750 u/s, 950 u, 30 u wide",
		[STRING_CASTER.attack_style, STRING_CASTER.swings.size(), STRING_CASTER.get_string_hits_min(), b0.projectile_speed, b0.projectile_range, b0.projectile_width],
		[AttackCombo.AttackStyle.RANGED, 3, 3, 750.0, 950.0, 30.0])
	var s := SituationContext.new()
	s.target_health_ratio = 1.0
	s.effective_respect = 0.45
	var stream := RandomNumberGenerator.new()
	stream.seed = 11
	var seen := {}
	for i in 200:
		seen[EnemyBrain.get_string_length(s, STRING_CASTER, t.get_rank_rules(EnemyData.Rank.BOSS), t, CASTER_BEHAVIOR, stream)] = true
	var boss := seen.keys()
	boss.sort()
	_check("its lengths at respect 0.45: a regular 3, an elite 3, a boss 3 or 4",
		[EnemyBrain.get_string_length(s, STRING_CASTER, t.get_rank_rules(EnemyData.Rank.REGULAR), t, CASTER_BEHAVIOR, stream),
			EnemyBrain.get_string_length(s, STRING_CASTER, t.get_rank_rules(EnemyData.Rank.ELITE), t, CASTER_BEHAVIOR, stream), boss],
		[3, 3, [3, 4]])
	_check("both test casters carry it; the caster preset's commit weight is 1 (was 0)",
		[CASTER_DATA.attack_string == STRING_CASTER, CASTER_ELITE_DATA.attack_string == STRING_CASTER, CASTER_BEHAVIOR.get_intent_weight(&"commit")], [true, true, 1.0])
	var bad: Array[String] = []
	for f in DirAccess.open(ENEMY_DATA_DIR).get_files():
		if not f.ends_with(".tres"):
			continue
		var d: EnemyData = load(ENEMY_DATA_DIR + f)
		if d.behavior == null or d.behavior.role != EnemyBehavior.Role.CASTER or d.behavior.get_intent_weight(&"commit") <= 0.0:
			continue
		if d.attack_string == null or d.attack_string.attack_style != AttackCombo.AttackStyle.RANGED:
			bad.append(String(d.id))
	_check("every caster-role enemy that commits has a ranged string (or its commit would walk it into melee)", bad, [] as Array[String])


## A passive `scene` enemy `distance_u` LoL units (center to center) from the
## unstoppable Knight runs `hits` hits of its volley at him: each swing's
## start [index, time], each release [index, time, its position], each of its
## hits on him [time, basic_attack, projectile, deflectable, no ability,
## blocked], damage it dealt him, deflects of its bolts, its end [completed,
## swung, time], and its bolts' ids. Free it with _free_volley().
func _volley_at_knight(scene: PackedScene, distance_u: float, rec: Dictionary) -> Enemy:
	var steady := _tag_status(&"test_unstoppable", [&"unstoppable"] as Array[StringName])
	knight.status_component.apply_status(steady)
	var e := _spawn(scene, knight.global_position + Vector2(Units.to_px(distance_u), 0), true)
	await get_tree().physics_frame
	rec.started = []
	rec.released = []
	rec.hits = []
	rec.damage = []
	rec.deflects = []
	rec.ended = []
	rec.shots = {}
	rec.on_start = func(i: int, _d: Vector2, _s: AttackSwing) -> void: (rec.started as Array).append([i, Brains.get_time()])
	rec.on_land = func(i: int, _targets: Array[Unit]) -> void: (rec.released as Array).append([i, Brains.get_time(), e.global_position])
	rec.on_end = func(done: bool, swung: int) -> void: (rec.ended as Array).append([done, swung, Brains.get_time()])
	rec.on_hit = func(ctx: HitContext) -> void:
		if ctx.source == e and ctx.target == knight:
			(rec.hits as Array).append([Brains.get_time(), ctx.has_tag(&"basic_attack"), ctx.has_tag(&"projectile"), ctx.deflectable, ctx.ability == null, ctx.blocked])
	rec.on_damaged = func(ctx: HitContext) -> void:
		if ctx.source == e and ctx.target == knight:
			(rec.damage as Array).append(Brains.get_time())
	rec.on_deflect = func(attacker: Unit, defender: Unit, _ctx: HitContext) -> void:
		if attacker == e and defender == knight:
			(rec.deflects as Array).append(Brains.get_time())
	e.attack.swing_started.connect(rec.on_start)
	e.attack.swing_landed.connect(rec.on_land)
	e.attack.string_ended.connect(rec.on_end)
	Events.unit_hit.connect(rec.on_hit)
	Events.unit_damaged.connect(rec.on_damaged)
	Events.hit_deflected.connect(rec.on_deflect)
	rec.steady = steady.id
	return e


## Its bolts in flight now (noted in rec.shots).
func _volley_shots(e: Enemy, rec: Dictionary) -> Array[Projectile]:
	var out: Array[Projectile] = []
	for n in get_tree().get_nodes_in_group(Projectile.GROUP):
		var p := n as Projectile
		if p != null and p.caster == e and p.swing != null:
			out.append(p)
			(rec.shots as Dictionary)[p.get_instance_id()] = true
	return out


func _free_volley(e: Enemy, rec: Dictionary) -> void:
	if is_instance_valid(e):
		e.attack.swing_started.disconnect(rec.on_start)
		e.attack.swing_landed.disconnect(rec.on_land)
		e.attack.string_ended.disconnect(rec.on_end)
		e.attack.cancel()
		e.queue_free()
	Events.unit_hit.disconnect(rec.on_hit)
	Events.unit_damaged.disconnect(rec.on_damaged)
	Events.hit_deflected.disconnect(rec.on_deflect)
	knight.status_component.remove_status(rec.steady)
	rec.clear()   # its lambdas capture `rec`
	knight.health.heal(100000.0)
	await _frames(2)


func _test_ar1b_volley() -> void:
	_section("A passive test caster 6.5 m from the Knight runs its volley at him: in its bolts' range even from its band's far edge, it stays where it stands, releases on the beat then 0.45 s apart, one bolt a release; each bolt hits him once after its flight (a basic attack, tagged projectile, deflectable, no ability); the volley ends with its last release's recovery, before its last bolt lands")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	var t := Brains.table
	var tick := 1.0 / 60.0 + 0.001
	var rec := {}
	var e := await _volley_at_knight(CASTER_SCENE, 650.0, rec)
	# In reach: center to his edge within the bolt's range less forgiveness. From
	# its band's far edge (edge to edge) that's the band plus its own radius.
	var far := Units.to_px(STRING_CASTER.swings[0].projectile_range) * (1.0 - e.attack.enemy_hit_forgiveness) \
		>= Units.to_px(CASTER_BEHAVIOR.range_band_max) + e.get_gameplay_radius_px()
	var from := e.global_position
	e.attack.run_string(knight, STRING_CASTER, 3, t.beat)
	await _wait_until(func() -> bool:
		_volley_shots(e, rec)
		return (rec.hits as Array).size() >= 3, 300)
	var started: Array = rec.started
	var released: Array = rec.released
	var hits: Array = rec.hits
	var first := float(released[0][1]) - float(started[0][1]) if not released.is_empty() and not started.is_empty() else -1.0
	var flights: Array = []
	for k in mini(released.size(), hits.size()):
		flights.append(snappedf(float(hits[k][0]) - float(released[k][1]), 0.01))
	var moved := 0.0
	for r: Array in released:
		moved = maxf(moved, (r[2] as Vector2).distance_to(from))
	_check("in its bolts' range from its band's far edge too; it didn't move (%.1f px)" % moved, [far, moved < 1.0], [true, true])
	_check("its first release %.2f s after its wind-up (got %.3f s), then 0.45 s apart (got %s); 3 bolts" % [t.beat, first, _gaps(released)],
		[absf(first - t.beat) <= tick, _all_near(_gaps(released), 0.45, STRING_SPACING_TOLERANCE), (rec.shots as Dictionary).size()], [true, true, 3])
	var kinds: Array = hits.map(func(h: Array) -> Array: return h.slice(1, 6))
	_check("3 hits on him, each after its flight (got %s s), each a basic attack, tagged projectile, deflectable, with no ability, not blocked" % [flights],
		[hits.size(), _all_near(flights, 0.85, 0.35), kinds], [3, true, [[true, true, true, true, false], [true, true, true, true, false], [true, true, true, true, false]]])
	var ended: Array = rec.ended
	_check("done with 3 releases, before its last bolt lands (its recovery, not its flight)",
		[ended.map(func(r: Array) -> Array: return r.slice(0, 2)), not ended.is_empty() and not hits.is_empty() and float(ended[0][2]) < float(hits[-1][0])],
		[[[true, 3]], true])
	await _free_volley(e, rec)


func _test_ar1b_walks_in() -> void:
	_section("Out of range (13 m away): its volley walks straight in only until he's in its bolts' range and in sight, then releases from there, far from melee")
	await _reset_knight()
	var rec := {}
	var e := await _volley_at_knight(CASTER_SCENE, 1300.0, rec)
	var start_u := Units.to_units(e.edge_distance_to(knight))
	e.attack.run_string(knight, STRING_CASTER, 3, Brains.table.beat)
	var at_first := [-1.0]
	await _wait_until(func() -> bool:
		if at_first[0] < 0.0 and not (rec.started as Array).is_empty():
			at_first[0] = Units.to_units(e.edge_distance_to(knight))
		return not (rec.released as Array).is_empty(), 600)
	var reach_u := STRING_CASTER.swings[0].projectile_range * (1.0 - e.attack.enemy_hit_forgiveness)
	_check("it walked in from %d u and started its volley at %d u edge to edge: within its bolts' %d u, not under 6 m" % [roundi(start_u), roundi(at_first[0]), roundi(reach_u)],
		[at_first[0] > 0.0 and at_first[0] < start_u, at_first[0] <= reach_u, at_first[0] >= 600.0], [true, true, true])
	await _free_volley(e, rec)
	rec = {}
	e = await _volley_at_knight(CASTER_SCENE, 650.0, rec)
	var wall := _wall_at(e.global_position.lerp(knight.global_position, 0.5), Vector2(16, 400))
	await _frames(2)
	e.movement.add_move_lock(&"test_hold")   # it can't walk round the wall: it waits
	e.attack.run_string(knight, STRING_CASTER, 3, Brains.table.beat)
	await _frames(120)
	_check("a wall between them (in range, out of sight): no swing in 2 s, its volley still waiting", [(rec.started as Array).size(), e.attack.is_running_string()], [0, true])
	e.movement.remove_move_lock(&"test_hold")
	wall.queue_free()
	await _free_volley(e, rec)


func _test_ar1b_deflect() -> void:
	_section("A deflect pair on a volley (the Knight's test deflect, D7): his window open as each of its first two bolts arrives deflects it (absorbed: no damage, the bolt gone), the riposte his; its third bolt hits him; the volley still done")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	var was_on := DeflectComponent.deflect_test_enabled
	DeflectComponent.deflect_test_enabled = true
	var rec := {}
	var e := await _volley_at_knight(CASTER_SCENE, 650.0, rec)
	e.attack.run_string(knight, STRING_CASTER, 3, Brains.table.beat)
	for k in 2:
		await _wait_until(func() -> bool:
			for p in _volley_shots(e, rec):
				var along := (knight.global_position - p.global_position).dot(p.direction) - knight.get_gameplay_radius_px()
				if along / maxf(p.speed_px, 0.01) <= 0.1:
					return true
			return false, 240)
		knight.deflect_component.open_window()
		await _wait_until(func() -> bool: return (rec.deflects as Array).size() >= k + 1, 30)
	await _wait_until(func() -> bool: return (rec.damage as Array).size() >= 1 and not (rec.ended as Array).is_empty(), 180)
	await _frames(30)
	_check("2 bolts deflected (no damage from them, gone), the riposte his; the third hit him; 3 bolts fired; the volley done",
		[(rec.deflects as Array).size(), knight.deflect_component.has_riposte(), (rec.damage as Array).size(), _volley_shots(e, rec).size(), (rec.shots as Dictionary).size(),
			(rec.ended as Array).map(func(r: Array) -> Array: return r.slice(0, 2))],
		[2, true, 1, 0, 3, [[true, 3]]])
	knight.status_component.remove_status(DeflectComponent.get_riposte_status_id())
	DeflectComponent.deflect_test_enabled = was_on
	await _free_volley(e, rec)
	await _reset_knight()


func _test_ar1b_shot() -> void:
	_section("A swing's shot (Projectile.fire_swing()): its speed, range, width and colour are the swing's; a wall stops it; its attacker freed in flight, it still hits with the damage at fire (1.5 × 14 = 21), no source and no crit")
	await _reset_knight()
	await _wait_until(func() -> bool: return not knight.has_invulnerability(Unit.HIT_IFRAMES_ID), 60)
	var bolt := STRING_CASTER.swings[0]
	var rec := {}
	var e := await _volley_at_knight(CASTER_SCENE, 650.0, rec)
	var to := (knight.global_position - e.global_position).normalized()
	var shot := Projectile.fire_swing(e, bolt, e.global_position, to)
	_check("the swing's speed, range, width and colour; one hit; no ability",
		[shot.speed_px, shot.range_px, shot.half_width_px * 2.0, shot.tint, shot.ability, shot.swing == bolt],
		[Units.to_px(750.0), Units.to_px(950.0), Units.to_px(30.0), bolt.projectile_color, null, true])
	await _wait_until(func() -> bool: return not (rec.damage as Array).is_empty(), 120)
	var wall := _wall_at(e.global_position.lerp(knight.global_position, 0.5), Vector2(16, 200))
	await _frames(2)
	var walled := Projectile.fire_swing(e, bolt, e.global_position, to)
	var walled_id := walled.get_instance_id()
	await _wait_until(func() -> bool: return not is_instance_valid(instance_from_id(walled_id)), 120)
	await _frames(60)
	_check("the first shot hit him; the one fired at the wall stopped there (gone, no second hit)", [(rec.damage as Array).size(), is_instance_valid(instance_from_id(walled_id))], [1, false])
	wall.queue_free()
	await _frames(20)   # his post-hit i-frames pass
	var freed_hits := []
	var on_freed := func(ctx: HitContext) -> void:
		if ctx.target == knight and ctx.has_tag(&"projectile") and ctx.source == null:
			freed_hits.append([ctx.base_damage, ctx.can_crit, ctx.has_tag(&"basic_attack")])
	Events.unit_damaged.connect(on_freed)
	Projectile.fire_swing(e, bolt, e.global_position, to)
	await _free_volley(e, rec)   # its attacker freed while the bolt flies
	await _wait_until(func() -> bool: return not freed_hits.is_empty(), 120)
	Events.unit_damaged.disconnect(on_freed)
	_check("its attacker freed in flight: it hits with the 21 damage at fire, no source, no crit, still a basic attack", freed_hits, [[21.0, false, true]])
	await _reset_knight()


func _test_ar1b_brain() -> void:
	_section("A real test caster 6.5 m away (his kit spent) commits into its volley from where it stands: its tell, 3 bolts on the beat then 0.45 s apart, its token (a regular's 1) held through it and let go after; it didn't walk in; its bolts hit him. The elite caster: its 3 (4 at its aggression's chance)")
	var t := Brains.table
	var tick := 1.0 / 60.0 + 0.001
	var rec := {}
	var e := await _committing_enemy(CASTER_SCENE, rec, null, Units.to_px(650.0))
	var brain := e.get_brain()
	var damage := [0]
	var on_damaged := func(ctx: HitContext) -> void:
		if ctx.source == e and ctx.target == knight:
			damage[0] += 1
	Events.unit_damaged.connect(on_damaged)
	await _wait_until(func() -> bool: return not (rec.started as Array).is_empty(), 1200)
	var at_start := e.global_position
	var cost := Brains.get_token_cost(e)
	await _wait_until(func() -> bool: return not (rec.ended as Array).is_empty(), 300)
	var moved := e.global_position.distance_to(at_start)
	await _wait_until(func() -> bool: return not brain.is_committing(), 30)
	var after := [brain.is_committing(), Brains.has_token(e)]
	await _wait_until(func() -> bool: return damage[0] >= 3, 120)
	Events.unit_damaged.disconnect(on_damaged)
	var started: Array = rec.started
	var landed: Array = rec.landed
	var tell := float(started[0][1]) - float(rec.commit_at) if not started.is_empty() else -1.0
	var first := float(landed[0][1]) - float(started[0][1]) if not landed.is_empty() and not started.is_empty() else -1.0
	var held := true
	for row: Array in started + landed:
		held = held and bool(row[2])
	_check("its volley: 3 bolts, done; its tell first (%.2f s), its first on the beat (%.3f s), then 0.45 s apart (got %s); it stood still (%.1f px)" % [tell, first, _gaps(landed), moved],
		[(rec.ended as Array).map(func(r: Array) -> Array: return r.slice(0, 2)), tell >= t.tell_time - tick, absf(first - t.beat) <= tick,
			_all_near(_gaps(landed), 0.45, STRING_SPACING_TOLERANCE), moved < 1.0],
		[[[true, 3]], true, true, true, true])
	var volley_from := float(started[0][1]) if not started.is_empty() else INF
	var volley_to := float((rec.ended as Array)[0][2]) if not (rec.ended as Array).is_empty() else INF
	var casts_in_volley := (rec.cast_rows as Array).filter(func(r: Array) -> bool: return float(r[1]) >= volley_from and float(r[1]) <= volley_to).size()
	_check("its token (cost %d) held at every swing and release, let go after, the commit over; all 3 bolts hit him (%d); no League-style windup, no cast during its volley (its pokes before it: %d)" % [cost, damage[0], (rec.cast_rows as Array).size()],
		[cost, held, after, damage[0], rec.league, casts_in_volley], [1, true, [false, false], 3, 0, 0])
	await _free_committing_enemy(e, rec)
	# A string that swings is committed: its poke ready and scoring far above
	# its commit mid-volley takes nothing back (the brain makes no new decision).
	var poke_was := t.caster_poke_score
	rec = {}
	e = await _committing_enemy(CASTER_SCENE, rec, null, Units.to_px(650.0))
	brain = e.get_brain()
	await _wait_until(func() -> bool: return not (rec.started as Array).is_empty(), 1200)
	e.abilities.reset_cooldown(&"q")
	t.caster_poke_score = 5.0
	await _wait_until(func() -> bool: return not (rec.ended as Array).is_empty(), 300)
	var poked_in := (rec.cast_rows as Array).filter(func(r: Array) -> bool: return float(r[1]) >= float(rec.started[0][1]) and float(r[1]) <= float(rec.ended[0][2])).size()
	t.caster_poke_score = poke_was
	_check("its bolt ready and its poke scoring 5 mid-volley: the volley still runs to its end, no poke inside it",
		[(rec.ended as Array).map(func(r: Array) -> Array: return r.slice(0, 2)), poked_in], [[[true, 3]], 0])
	await _free_committing_enemy(e, rec)
	rec = {}
	e = await _committing_enemy(CASTER_ELITE_SCENE, rec, null, Units.to_px(650.0))
	brain = e.get_brain()
	await _wait_until(func() -> bool: return not (rec.ended as Array).is_empty(), 1200)
	_check("the elite caster at respect 0: its 3 bolts, or 4 at its aggression's chance (got %d), done, 0.45 s apart (got %s)" % [brain.last_string_hits, _gaps(rec.landed)],
		[brain.last_string_hits in [3, 4], (rec.ended as Array).map(func(r: Array) -> Array: return r.slice(0, 2)), _all_near(_gaps(rec.landed), 0.45, STRING_SPACING_TOLERANCE)],
		[true, [[true, brain.last_string_hits]], true])
	await _free_committing_enemy(e, rec)


# --- ARCHETYPES AR2: perilous attacks (ARCHETYPES.md, Perilous attacks; D5) -------------------

const STATUS_REBUFFED_PERILOUS: StatusEffect = preload("res://data/statuses/status_rebuffed_perilous.tres")


func _test_ar2_data() -> void:
	_section("AR2 data: the gate's numbers; perilous_max by rank; the elites' perilous moves (the elite slime's slam, the duelist's finisher) deflectable, around their own bodies, 0.9 s or more, 35–40% of the Knight's health, 12–15 s, heavy hits; each enemy within its rank's count; every deflectable or perilous enemy ability centered on its attacker")
	var t := Brains.table
	_check("the table: perilous_quiet_time 6 s, perilous_live_max 1, perilous_live_max_boss 2", [_perilous_quiet_saved, t.perilous_live_max, t.perilous_live_max_boss], [6.0, 1, 2])
	var maxes: Array[int] = []
	for rank in [EnemyData.Rank.FODDER, EnemyData.Rank.REGULAR, EnemyData.Rank.ELITE, EnemyData.Rank.BOSS]:
		maxes.append(t.get_rank_rules(rank).perilous_max)
	_check("perilous_max: fodder 0, regular 0, elite 1, boss 3", maxes, [0, 0, 1, 3])
	var slam_hit := HitPipeline.from_ability(null, SLAM, null)
	_check("not perilous by default; a perilous ability's hit carries the mark and the tag `perilous`, another's neither",
		[Ability.new().perilous, slam_hit.perilous, slam_hit.has_tag(&"perilous"), HitPipeline.from_ability(null, SMASH, null).perilous], [false, true, true, false])
	var health := knight.health.max_health
	for a: Ability in [SLAM, D_FINISHER]:
		var share := a.base_damage / health
		_check("%s: perilous, deflectable, cast on itself (SELF), windup %.2f s (0.9 or more), %.0f damage = %.1f%% of the Knight's %.0f (35–40%%, no ratios), cooldown %.0f s (12–15), a heavy hit" % [a.id, a.cast_time, a.base_damage, share * 100.0, health, a.cooldown],
			[a.perilous, a.deflectable, a.targeting == Ability.Targeting.SELF, a.cast_time >= 0.9 - 0.0001, share >= 0.35 - 0.0001 and share <= 0.40 + 0.0001,
				a.ad_ratio == 0.0 and a.ap_ratio == 0.0, a.cooldown >= 12.0 - 0.0001 and a.cooldown <= 15.0 + 0.0001, EnemyBrain.is_heavy_hit(a, knight, knight, t)],
			[true, true, true, true, true, true, true, true])
	_check("the slam's AI use is authored (a damage use, weight 1), no longer the default one (R0's finding)",
		[SLAM.ai_uses.size(), SLAM.ai_uses[0].intent if not SLAM.ai_uses.is_empty() else &"", SLAM.get_ai_uses()[0].weight], [1, &"damage", 1.0])
	var dir := DirAccess.open(ENEMY_DATA_DIR)
	var problems: Array[String] = []
	var kits := {}   # every enemy ability: id -> Ability
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		var data: EnemyData = load(ENEMY_DATA_DIR + f)
		var count := 0
		for a: Ability in data.get_abilities_at(5).values():
			kits[a.id] = a
			if a.perilous:
				count += 1
		var allowed := t.get_rank_rules(data.rank).perilous_max
		if count > allowed:
			problems.append("%s: %d perilous, its rank allows %d" % [f, count, allowed])
	_check("every EnemyData within its rank's perilous_max (the elite slime and the duelist 1 each)",
		[problems, ELITE_DATA.get_abilities_at(5).values().filter(func(a: Ability) -> bool: return a.perilous).size(),
			DUELIST_DATA.get_abilities_at(5).values().filter(func(a: Ability) -> bool: return a.perilous).size()], [[] as Array[String], 1, 1])
	for f in DirAccess.open(LIBRARY_DIR).get_files():
		if f.ends_with(".tres"):
			var a: Ability = load(LIBRARY_DIR + f)
			kits[a.id] = a
	var checked: Array[String] = []
	var off: Array[String] = []
	for a: Ability in kits.values():
		if not (a.deflectable or a.perilous):
			continue
		var ctx := CastContext.new()
		ctx.ability = a
		ctx.point = knight.global_position + Vector2(300, 0)   # aimed away: a placed shape would sit there
		ctx.direction = Vector2.RIGHT
		ctx.vector_start = ctx.point
		ctx.vector_direction = Vector2.RIGHT
		var area := a.get_effect_area(knight, ctx)   # the Knight stands in for its caster: only its position is read
		var anchor: Variant = {&"circle": area.get("center"), &"segment": area.get("from"), &"cone": area.get("origin")}.get(area.get("kind", &"none"))
		checked.append(String(a.id))
		if not (anchor is Vector2 and (anchor as Vector2).distance_to(knight.global_position) < 1.0):
			off.append(String(a.id))
	checked.sort()
	_check("every deflectable or perilous enemy ability is centered on its attacker, never placed at the player (%s)" % ", ".join(checked), [off, checked.size() >= 3], [[] as Array[String], true])


func _test_ar2_gate() -> void:
	_section("AR2, Brains' perilous gate: none in a fight's first perilous_quiet_time s (from the first enemy with data fighting); one live at a time (Events.perilous_started to its cast's end), two while a boss fights")
	var t := Brains.table
	await _reset_knight()
	var steady := _tag_status(&"test_unstoppable", [&"unstoppable"] as Array[StringName])
	knight.status_component.apply_status(steady)
	await _wait_until(func() -> bool: return Brains.get_fight_time() < 0.0, 240)
	_check("no enemy with data fighting: no fight (−1), the gate shut", [Brains.get_fight_time(), Brains.can_start_perilous(knight)], [-1.0, false])
	t.perilous_quiet_time = 1.0   # the table's 6 s, shortened for the test's clock
	var elite := _spawn(ELITE_SCENE, knight.global_position + Vector2(200, 0), false)
	_pin_ai3(elite)
	for slot in AbilityComponent.SLOTS:
		elite.abilities.start_cooldown(slot)
	elite.alert(knight)   # aggroed at once (noticing waits on a path check, slow under parallel load)
	await _wait_until(func() -> bool: return Brains.get_fight_time() >= 0.0, 300)
	_check("the fight starts as the elite aggroes; inside the quiet time the gate is shut",
		[Brains.get_fight_time() >= 0.0 and Brains.get_fight_time() < 0.1, Brains.can_start_perilous(elite)], [true, false])
	await _wait_until(func() -> bool: return Brains.get_fight_time() >= 1.0, 120)
	_check("after it the gate opens", Brains.can_start_perilous(elite), true)
	var events: Array = []
	var on_perilous := func(u: Unit, a: Ability) -> void: events.append([u, a])
	Events.perilous_started.connect(on_perilous)
	var duelist := _spawn(DUELIST_SCENE, knight.global_position + Vector2(-420, 0), true)   # passive: it casts only when told
	await _frames(2)
	duelist.abilities.reset_cooldown(&"r")
	var cast := duelist.abilities.try_cast(&"r", duelist.global_position)
	_check("the duelist's finisher cast: Events.perilous_started(it, the finisher); live in Brains; the gate shut for the rest",
		[cast, events.size() == 1 and events[0][0] == duelist and events[0][1] == D_FINISHER, Brains.get_perilous_live().has(duelist), Brains.can_start_perilous(elite)],
		[true, true, true, false])
	await _wait_until(func() -> bool: return not duelist.abilities.casting, 120)
	_check("its cast over (0.9 s): no longer live, the gate open again", [Brains.get_perilous_live().has(duelist), Brains.can_start_perilous(elite)], [false, true])
	var boss_data: EnemyData = BRUTE_DATA.duplicate()
	boss_data.rank = EnemyData.Rank.BOSS
	var boss := BRUTE_SCENE.instantiate() as Enemy
	boss.data = boss_data
	entities.add_child(boss)
	_place(boss, knight.global_position + Vector2(0, 200))
	_pin_ai3(boss)
	for slot in AbilityComponent.SLOTS:
		boss.abilities.start_cooldown(slot)
	boss.alert(knight)
	await _wait_until(func() -> bool: return boss.ai == Enemy.AI.AGGRO, 300)
	await _wait_until(func() -> bool: return not duelist.abilities.is_recovering(), 120)
	duelist.abilities.reset_cooldown(&"r")
	duelist.abilities.try_cast(&"r", duelist.global_position)
	_check("a boss fighting: one live, the gate still open (two may be)", [Brains.get_perilous_live().size(), Brains.can_start_perilous(elite)], [1, true])
	var second := _spawn(DUELIST_SCENE, knight.global_position + Vector2(-420, 120), true)
	await _frames(2)
	second.abilities.reset_cooldown(&"r")
	second.abilities.try_cast(&"r", second.global_position)
	_check("two live (two finishers): shut, even with a boss", [Brains.get_perilous_live().size(), Brains.can_start_perilous(boss)], [2, false])
	Events.perilous_started.disconnect(on_perilous)
	for n: Enemy in [elite, duelist, second, boss]:
		n.passive = true
		n.queue_free()
	await _wait_until(func() -> bool: return Brains.get_fight_time() < 0.0, 60)
	_check("the enemies gone: no fight, nothing live", [Brains.get_fight_time(), Brains.get_perilous_live().size()], [-1.0, 0])
	knight.status_component.remove_status(steady.id)
	t.perilous_quiet_time = 0.0   # the older checks' pin (restored at the end)


func _test_ar2_brain_gate() -> void:
	_section("AR2, a brain and the gate: the elite slime, the Knight inside its slam's circle, gathers its slam only while the gate is open (not in the quiet time, not while another perilous attack is live); it casts it once open; its cast's end tells Brains")
	var t := Brains.table
	t.perilous_quiet_time = 600.0   # shut while it's set up
	var rec := {}
	var e := await _committing_enemy(ELITE_SCENE, rec, null, 60.0)
	var brain := e.get_brain()
	var duelist := _spawn(DUELIST_SCENE, knight.global_position + Vector2(-420, 0), true)   # passive: it casts only when told
	e.alert(knight)
	await _wait_until(func() -> bool: return e.is_brain_active(), 240)
	await _frames(2)
	e.abilities.reset_cooldown(&"q")
	brain.set(&"_patience", 1.0)   # its hits are gathered (a commit possible); no frame passes until the three reads are done
	var shut := _gathered_slots(brain.build_situation())
	t.perilous_quiet_time = 0.0
	var open := _gathered_slots(brain.build_situation())
	duelist.abilities.reset_cooldown(&"r")
	duelist.abilities.try_cast(&"r", duelist.global_position)
	var live := _gathered_slots(brain.build_situation())
	_check("its slam (q) gathered: in the quiet time %s, open %s, with the duelist's finisher live %s" % [shut.has(&"q"), open.has(&"q"), live.has(&"q")],
		[shut.has(&"q"), open.has(&"q"), live.has(&"q")], [false, true, false])
	await _wait_until(func() -> bool: return not duelist.abilities.casting, 120)
	await _wait_until(func() -> bool: return (rec.cast_rows as Array).any(func(r: Array) -> bool: return r[0] == &"q"), 600)
	var cast_q := (rec.cast_rows as Array).any(func(r: Array) -> bool: return r[0] == &"q")
	var live_while := Brains.get_perilous_live().has(e)
	await _wait_until(func() -> bool: return not e.abilities.casting, 120)
	_check("the gate open, it casts the slam (live while it winds up), then it's over (its brain's end_perilous())",
		[cast_q, live_while, Brains.get_perilous_live().has(e)], [true, true, false])
	duelist.passive = true
	duelist.queue_free()
	await _free_committing_enemy(e, rec)
	await _frames(2)


## The slots `s` gathered uses for, in order.
func _gathered_slots(s: SituationContext) -> Array[StringName]:
	var out: Array[StringName] = []
	for u: Dictionary in s.uses:
		if not out.has(u.slot):
			out.append(u.slot)
	return out


func _test_ar2_rebuffed() -> void:
	_section("AR2, rebuffed (status_rebuffed_perilous: its perilous attack was deflected): its string ends, its commit breaks off, its token goes, as a stun's; 1.0 s; diminishing returns don't count it")
	var rec := {}
	var e := await _committing_enemy(BRUTE_SCENE, rec)
	var brain := e.get_brain()
	await _wait_until(func() -> bool: return not (rec.started as Array).is_empty(), 900)
	var had := Brains.has_token(e)
	e.status_component.apply_status(STATUS_REBUFFED_PERILOUS, knight)
	await _frames(3)
	var ended: Array = rec.ended
	_check("in its string with its token, then rebuffed: the string cut, the commit off, no token",
		[had, not ended.is_empty() and not bool(ended[0][0]), brain.is_committing(), Brains.has_token(e)], [true, true, false, false])
	var left := e.status_component.get_time_left(STATUS_REBUFFED_PERILOUS.id)
	_check("...1.0 s of it (%.2f s left after 3 ticks), no diminishing returns step" % left, [left > 0.9 and left <= 1.0, e.status_component.get_dr_count()], [true, 0])
	await _free_committing_enemy(e, rec)


# --- ARCHETYPES AR3b: the test Assassin (ARCHETYPES.md, Assassin: The enemy's layer) -------------

func _test_ar3b_data() -> void:
	_section("AR3b data: Role.ASSASSIN (4) and its preset (a skirmisher's band and sliders); the test Assassin (an elite Assassin: its stats, its kit, its string against its archetype's shape); the Riposte Stance's data and use; the table's riposte_stance_range; the scene's deflect; the two poses")
	_check("Role.ASSASSIN is stored as 4 (3 kept for AR8's DUELIST); its archetype id assassin",
		[EnemyBehavior.Role.ASSASSIN, EnemyBehavior.Role.keys(), ASSASSIN_BEHAVIOR.role, ASSASSIN_BEHAVIOR.get_archetype_id()],
		[4, ["BRUTE", "SKIRMISHER", "CASTER", "ASSASSIN"], EnemyBehavior.Role.ASSASSIN, &"assassin"])
	var same := true
	for s: StringName in EnemyBehavior.SLIDERS:
		same = same and is_equal_approx(ASSASSIN_BEHAVIOR.get_slider(s), SKIRMISHER_BEHAVIOR.get_slider(s))
	_check("enemy_behavior_assassin.tres: the skirmisher's band (4–6 m) and every slider; it fights on at low health (no reset)",
		[same, ASSASSIN_BEHAVIOR.range_band_min, ASSASSIN_BEHAVIOR.range_band_max, ASSASSIN_BEHAVIOR.low_health], [true, 400.0, 600.0, EnemyBehavior.LowHealth.FIGHT_ON])
	var d := ASSASSIN_DATA
	var st := d.stats
	_check("the test Assassin: an elite, its archetype the Assassin (Archetype.of()), its meter its rank's (−1), a dark violet capsule; 1400 health, 20 armor, 40 AD, 150 u reach, 380 move speed",
		[d.id, d.rank, d.behavior == ASSASSIN_BEHAVIOR, d.get_archetype_id(), Archetype.of(d.get_archetype_id()) != null, d.poise_max, d.model_scene == null,
			st.max_health, st.armor, st.attack_damage, st.attack_range, st.move_speed],
		[&"test_assassin", EnemyData.Rank.ELITE, true, &"assassin", true, -1.0, true, 1400.0, 20.0, 40.0, 150.0, 380.0])
	var kit := d.get_abilities_at(5)
	var q: Ability = kit.get(&"q")
	var e_ability: Ability = kit.get(&"e")
	var r: Ability = kit.get(&"r")
	_check("its kit (an elite's 3–5): Q the Riposte Stance, E a gap-closer (the library's flurry), R its perilous move (the library's charge)",
		[kit.size(), q.id if q else &"", e_ability.id if e_ability else &"", r.id if r else &""],
		[3, &"test_assassin_riposte_stance", &"test_assassin_flurry", &"test_assassin_charge"])
	if q == null or e_ability == null or r == null:
		return
	var use: AIUse = q.ai_uses[0] if not q.ai_uses.is_empty() else null
	var cond: Condition = use.conditions[0] if use != null and not use.conditions.is_empty() else null
	_check("the stance: on itself, no cast time, a 0.5 s window, 6 s cooldown, a 0.6 s recovery (after a whiff), no damage, not deflectable; one use, defend when its target closes in (TARGET_CLOSED_IN, a situation read)",
		[q.targeting, q.cast_time, q.get(&"window_time"), q.cooldown, q.recovery_time, q.base_damage, q.deflectable, q.ai_uses.size(),
			use.intent if use else &"", cond.kind if cond else -1, cond.is_situation_kind() if cond else false],
		[Ability.Targeting.SELF, 0.0, 0.5, 6.0, 0.6, 0.0, false, 1, &"defend", Condition.Kind.TARGET_CLOSED_IN, true])
	var intents := func(a: Ability) -> Array: return a.get_ai_uses().map(func(u: AIUse) -> StringName: return u.intent)
	_check("E's uses gap_close, damage, punish; R perilous and deflectable, 0.9 s, 240 damage, 12 s, its uses damage and gap_close",
		[intents.call(e_ability), r.perilous, r.deflectable, r.cast_time, r.base_damage, r.cooldown, intents.call(r)],
		[[&"gap_close", &"damage", &"punish"], true, true, 0.9, 240.0, 12.0, [&"damage", &"gap_close"]])
	var arch := Archetype.of(&"assassin")
	var s := d.attack_string
	var gaps: Array = []
	for i in s.swings.size():
		var w := s.swings[i]
		var after := s.swings[mini(i + 1, s.swings.size() - 1)]
		gaps.append(snappedf((w.duration - w.windup) + w.pause_after + after.windup, 0.001))
	var on_shape := gaps.all(func(g: float) -> bool: return absf(g - arch.string_spacing) <= STRING_SPACING_TOLERANCE + 0.0001)
	_check("its string against its archetype's shape (Archetype: %d–%d hits, %.2f s apart): %d–%d hits, %s s apart" % [arch.string_hits_min, arch.string_hits_max, arch.string_spacing, s.get_string_hits_min(), s.swings.size(), gaps],
		[s.get_string_hits_min(), s.swings.size(), on_shape], [arch.string_hits_min, arch.string_hits_max, true])
	_check("the table: riposte_stance_range 300 u (3 m)", Brains.table.riposte_stance_range, 300.0)
	var scene := ASSASSIN_SCENE.instantiate() as Enemy
	var dc := scene.get_node_or_null(^"DeflectComponent") as DeflectComponent
	var aa := scene.get_node(^"AutoAttackComponent") as AutoAttackComponent
	_check("its scene: a DeflectComponent (its riposte +1.0 AD ratio for 1 s, no snap, no poise damage) and a deflectable basic attack (its riposte swing)",
		[dc != null, dc.riposte_ad_ratio if dc else -1.0, dc.riposte_window if dc else -1.0, dc.riposte_snap_range if dc else -1.0, dc.riposte_poise_damage if dc else -1.0, aa.deflectable],
		[true, 1.0, 1.0, 0.0, 0.0, true])
	scene.free()
	var stance := POSE_SET.get_look(&"riposte_stance")
	var rebuffed := POSE_SET.get_look(&"rebuffed")
	_check("the poses: riposte_stance (lean back 5°, squash 0.95, a steel-blue rim), rebuffed (thrown back 20°, stretched 1.05, a white rim)",
		[stance != null, stance.lean_deg if stance else 0.0, stance.squash if stance else 0.0, rebuffed != null, rebuffed.lean_deg if rebuffed else 0.0, rebuffed.squash if rebuffed else 0.0,
			rebuffed.rim_color if rebuffed else Color()],
		[true, -5.0, 0.95, true, -20.0, 1.05, Color(1, 1, 1, 0.9)])


func _test_ar3b_brain() -> void:
	_section("AR3b, a brain: the test Assassin raises its stance when the Knight closes in (inside 3 m, after its reaction time; not from 4 m; no token), holds it 0.5 s, recovers after a whiff (the recover pose), not again on its cooldown; the read's rules (a gap-closer, never while committing, only for a kit that reads it)")
	await _reset_knight()
	var steady := _tag_status(&"test_unstoppable", [&"unstoppable"] as Array[StringName])
	knight.status_component.apply_status(steady)
	_spend_kit()
	var e := _spawn(ASSASSIN_SCENE, knight.global_position + Vector2(170, 0), false)
	_pin_ai3(e)
	var brain := e.get_brain()
	var intents: Array[StringName] = []
	var on_intent := func(i: StringName) -> void: intents.append(i)
	brain.intent_changed.connect(on_intent)
	var stances: Array = []
	var on_cast := func(slot: StringName, _a: Ability, _c: CastContext) -> void: stances.append([slot, Brains.get_time(), Brains.has_token(e)])
	e.abilities.cast_started.connect(on_cast)
	e.alert(knight)
	var calm := func() -> bool:
		brain.set(&"_patience", 0.0)   # it holds: no commit while the read is checked
		return false
	await _wait_until(func() -> bool: return e.is_brain_active() and not calm.call(), 240)
	for slot in AbilityComponent.SLOTS:
		if e.abilities.get_ability(slot) != null:
			e.abilities.start_cooldown(slot)
	e.abilities.reset_cooldown(&"q")
	_place(e, knight.global_position + Vector2(170, 0))
	await _wait_until(calm, 36)
	var far_edge := e.edge_distance_to(knight)
	_check("from %.1f m (outside 3 m), no stance; the read not started" % (Units.to_units(far_edge) / 100.0),
		[far_edge > Units.to_px(300.0), stances.is_empty(), brain.get(&"_closed_in_since")], [true, true, -1.0])
	var radii := e.get_gameplay_radius_px() + knight.get_gameplay_radius_px()
	_place(knight, e.global_position + Vector2(-(Units.to_px(200.0) + radii), 0))
	var closed_at := Brains.get_time()
	await _wait_until(func() -> bool: return e.deflect_component.is_window_open() or calm.call(), 60)
	var took := Brains.get_time() - closed_at
	var pose := e.get_pose()
	_check("the Knight 2 m away: after its reaction time (%.2f s; 0.3 s or more), defend, its stance (Q) up with no token, in its pose" % took,
		[e.deflect_component.is_window_open(), took >= 0.3 - 0.001 and took <= 0.45, intents.has(EnemyBrain.DEFEND), stances.size(), stances[0][0] if not stances.is_empty() else &"",
			stances[0][2] if not stances.is_empty() else true, pose],
		[true, true, true, 1, &"q", false, &"riposte_stance"])
	await _wait_until(func() -> bool: return not e.deflect_component.is_window_open() or calm.call(), 45)
	await _frames(2)
	_check("nothing comes: after 0.5 s its window shuts and it recovers, still, in the recover pose",
		[e.deflect_component.is_window_open(), brain.is_in_ability_recovery(), e.get_pose()], [false, true, &"recover"])
	await _wait_until(calm, 90)
	_check("the Knight still 2 m away 1.5 s later: no second stance (its 6 s cooldown)", stances.size(), 1)
	brain.intent_changed.disconnect(on_intent)
	e.abilities.cast_started.disconnect(on_cast)

	var perception := brain.get(&"_brain_perception") as BrainPerception
	var read := func(edge_px: float, gap: bool, committing: bool, now: float) -> bool:
		var s := SituationContext.new()
		s.target_edge_distance_px = edge_px
		s.target_gap_closer_in = gap
		s.committing = committing
		perception._read_closed_in(s, now)
		return s.target_closed_in
	brain.set(&"_closed_in_since", -1.0)
	var t0 := Brains.get_time()
	var gap_rows := [read.call(500.0, true, false, t0), read.call(500.0, true, false, t0 + 0.29), read.call(500.0, true, false, t0 + 0.31)]
	var committing: bool = read.call(10.0, false, true, t0 + 0.4)
	var since: float = brain.get(&"_closed_in_since")
	var out: bool = read.call(500.0, false, false, t0 + 0.5)
	_check("the read: a gap-closer of its ended inside its band from 15 m off counts too, once its reaction time has passed (no, no, yes); never while it commits (and it starts over); far and no gap-closer: no",
		[gap_rows, committing, since, out], [[false, false, true], false, -1.0, false])
	e.passive = true
	e.attack.cancel()
	e.queue_free()
	var brute := _spawn(BRUTE_SCENE, knight.global_position + Vector2(-80, 0), false)
	brute.alert(knight)
	await _wait_until(func() -> bool: return brute.is_brain_active(), 240)
	await _frames(30)
	_check("a brute (no use reads it) 1 m from the Knight: it never tracks the read", [brute.get_brain().get(&"_closed_in_since")], [-1.0])
	brute.passive = true
	brute.attack.cancel()
	brute.queue_free()
	knight.status_component.remove_status(&"test_unstoppable")
	await _frames(2)
	await _reset_knight()


# --- Helpers ----------------------------------------------------------------------------

## The Knight's kit all ready again (every charge back).
func _reset_cooldowns() -> void:
	for slot in AbilityComponent.SLOTS:
		for i in knight.abilities.get_max_charges(slot):
			knight.abilities.reset_cooldown(slot)


## The Knight's kit all spent (every slot on cooldown, no Fury): respect 0.
func _spend_kit() -> void:
	for slot in AbilityComponent.SLOTS:
		if knight.abilities.get_ability(slot) != null:
			knight.abilities.start_cooldown(slot)
	if knight.resource_pool != null:
		knight.resource_pool.try_spend(knight.resource_pool.current)


## A friendly dummy (ALLIES' second champion's stand-in): a passive slime with
## no data on the player's team, in the group `party`.
func _friend(pos: Vector2) -> Enemy:
	var f := SLIME_SCENE.instantiate() as Enemy
	f.data = null
	f.passive = true
	entities.add_child(f)
	f.team = Unit.Team.PLAYER
	f.remove_from_group(&"enemies")
	f.add_to_group(&"party")
	_place(f, pos)
	return f


## A status with these tags that lasts until removed (blocks moving with
## `root`).
func _tag_status(id: StringName, tags: Array[StringName], root: bool = false) -> StatusEffect:
	var s := StatusEffect.new()
	s.id = id
	s.tags = tags
	s.duration = -1.0
	s.blocks_move = root
	s.blocks_dash = root
	return s


## One flat walkable rectangle around the arena on the world's navigation map,
## as a room's baked navigation would be.
func _add_navigation() -> void:
	var poly := NavigationPolygon.new()
	var r := Rect2(ARENA - Vector2(2500, 2500), Vector2(5000, 5000))
	poly.vertices = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	poly.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	var region := NavigationRegion2D.new()
	region.navigation_polygon = poly
	add_child(region)


func _spawn(scene: PackedScene, pos: Vector2, passive: bool) -> Enemy:
	var e := scene.instantiate() as Enemy
	e.passive = passive
	entities.add_child(e)
	_place(e, pos)
	return e


## `scene`'s enemy on a copy of its data with no string (ARCHETYPES AR1a: an
## enemy not given one keeps AI1's commit), for checks of the older commit
## rules.
func _spawn_no_string(scene: PackedScene, pos: Vector2, passive: bool) -> Enemy:
	var e := scene.instantiate() as Enemy
	var plain: EnemyData = e.data.duplicate()
	plain.attack_string = null
	e.data = plain
	e.passive = passive
	entities.add_child(e)
	_place(e, pos)
	return e


func _wall_at(pos: Vector2, size: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	wall.add_child(shape)
	add_child(wall)
	wall.global_position = pos
	return wall


func _reset_knight() -> void:
	knight.abilities.interrupt_cast()
	knight.abilities.cancel_pending()
	knight.attack.cancel_swing()
	knight.movement.stop()
	await _wait_until(func() -> bool: return not knight.is_stunned() and not knight.movement.is_displaced(), 120)
	await _frames(2)
	_place(knight, ARENA)
	knight.health.heal(100000.0)
	for slot in AbilityComponent.SLOTS:
		for i in knight.abilities.get_max_charges(slot):
			knight.abilities.reset_cooldown(slot)
	await _frames(1)


func _place(node: Node2D, pos: Vector2) -> void:
	node.global_position = pos
	node.reset_physics_interpolation()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait_until(condition: Callable, max_frames: int) -> void:
	for i in max_frames:
		if condition.call():
			return
		await get_tree().physics_frame


func _section(title: String) -> void:
	print("-- %s" % title)


func _check(label: String, actual: Variant, expected: Variant) -> void:
	var ok: bool
	if actual is float or expected is float:
		ok = is_equal_approx(float(actual), float(expected))
	else:
		ok = actual == expected
	_report(ok, label, "got %s, expected %s" % [actual, expected])


func _report(ok: bool, label: String, detail: String) -> void:
	if ok:
		_passed += 1
		print("  PASS  %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s: %s" % [label, detail])
