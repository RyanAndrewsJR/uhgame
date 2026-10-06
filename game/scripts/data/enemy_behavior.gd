class_name EnemyBehavior
extends Resource
## An archetype preset per role (ENEMIES_AI.md, The tuning toolkit and Data;
## Ryan, I1 and I9): DUNGEONS' "shared behavior". Its kind (the role, intent
## weights, low-health response, tokens, its pose set) and the twelve sliders
## (the range band is one slider with two ends), each an @export_range with
## its limits. Files: res://data/enemy_behaviors/enemy_behavior_<role>.tres.
## An enemy carries only a few overrides on top (EnemyData.overrides; kind,
## not magnitude). Fodder needs none (it has no brain).
## AI3b (Duels and odds) added four sliders (confidence, crowded_commit,
## aim_lead, spend_eagerness: sixteen in all) and crowded_range (kind).
## The brain reads a resolved copy (resolve()): the preset's values or the
## enemy's overrides, times its rank's, faction's, difficulty tier's and elite
## modifiers' BrainAdjust multipliers, each clamped to its limits.

enum Role { BRUTE, SKIRMISHER, CASTER }   ## later SUPPORT, SUMMONER, SNIPER (AI8)
enum LowHealth { FIGHT_ON, FALL_BACK, HIT_AND_RESET }

## The slider fields, in the panel's order (the band's two ends are one slider).
const SLIDERS: Array[StringName] = [&"aggression", &"respect_weight", &"patience_time",
	&"range_band_min", &"range_band_max", &"reaction_time", &"dodge_skill", &"dodge_cooldown",
	&"punish_greed", &"finish_threshold", &"pressure_time", &"breather_time", &"jitter",
	&"confidence", &"crowded_commit", &"aim_lead", &"spend_eagerness"]
## Each slider's limits [min, max], as its @export_range says (floats, not a
## Vector2: a Vector2 holds 32-bit floats, and 0.2 would clamp to 0.2000000030).
const LIMITS := {
	&"aggression": [0.0, 1.0],
	&"respect_weight": [0.0, 2.0],
	&"patience_time": [0.5, 10.0],
	&"range_band_min": [0.0, 1500.0],
	&"range_band_max": [0.0, 1500.0],
	&"reaction_time": [0.2, 1.0],
	&"dodge_skill": [0.0, 1.0],
	&"dodge_cooldown": [1.0, 15.0],
	&"punish_greed": [0.0, 1.0],
	&"finish_threshold": [0.0, 0.6],
	&"pressure_time": [3.0, 30.0],
	&"breather_time": [1.0, 15.0],
	&"jitter": [0.0, 0.5],
	&"confidence": [0.0, 1.0],
	&"crowded_commit": [0.0, 1.0],
	&"aim_lead": [0.0, 1.0],
	&"spend_eagerness": [0.0, 1.0],
}

@export_group("Kind")
@export var role: Role = Role.BRUTE
## Intent -> weight: multiplies that intent's score (a missing intent counts
## 1; ALLIES' AllyStance pattern).
@export var intent_weights: Dictionary[StringName, float] = {}
@export var low_health: LowHealth = LowHealth.FIGHT_ON
## Below this share of its health a FALL_BACK enemy falls back (AI3).
@export_range(0.0, 1.0) var retreat_health: float = 0.35
## Commits, punishes and finishes take an attack token (AI2).
@export var uses_tokens: bool = true
## Its tells (poses); null = the enemy's own set or pose_set_default.tres.
@export var pose_set: PoseSet
## Its target inside this (LoL units, edge to edge) is in its face: a crowded
## episode (AI3b; Ryan, 2026-10-04: its own value, brute and skirmisher 200).
## −1 = its range band's minimum (casters).
@export var crowded_range: float = 200.0

@export_group("Sliders")
## How much danger it shrugs off: patience fills × (0.5 + aggression).
@export_range(0.0, 1.0) var aggression: float = 0.5
## How much what's ready on the party holds it back (0 = ignores it).
@export_range(0.0, 2.0) var respect_weight: float = 1.0
## Seconds to fill patience with nothing ready on the party (up to 4× longer
## with everything up).
@export_range(0.5, 10.0) var patience_time: float = 3.0
## Where it likes to stand from its target, LoL units edge to edge (min).
@export_range(0.0, 1500.0) var range_band_min: float = 350.0
## ... (max).
@export_range(0.0, 1500.0) var range_band_max: float = 500.0
## Delay before it reacts to anything new (an attack, a whiff, an opening);
## this preset's is the elite's (a regular's is × 1.3, a boss's × 0.85).
@export_range(0.2, 1.0) var reaction_time: float = 0.35
## Chance to try a sidestep out of a dodgeable attack (elites and bosses; AI4).
@export_range(0.0, 1.0) var dodge_skill: float = 0.4
## Seconds between dodges (AI4).
@export_range(1.0, 15.0) var dodge_cooldown: float = 6.0
## The chance it takes a whiff's opening, one roll per window (AI6).
@export_range(0.0, 1.0) var punish_greed: float = 0.6
## The target's health share below which `finish` opens (AI6).
@export_range(0.0, 0.6) var finish_threshold: float = 0.3
## A boss's pressure phase, seconds (AI6).
@export_range(3.0, 30.0) var pressure_time: float = 12.0
## A boss's breather, seconds (AI6).
@export_range(1.0, 15.0) var breather_time: float = 5.0
## Randomness: ± this share on scores and timings.
@export_range(0.0, 0.5) var jitter: float = 0.15
## How much its own ready key ability emboldens it: effective respect ×
## (1 − confidence × its own kit ready); once the key is spent it turns
## cautious (a slower refill, a walk out to its band's far edge) (AI3b).
@export_range(0.0, 1.0) var confidence: float = 0.5
## The chance it goes all in when its target is in its face and it has an
## answer; one roll per crowded episode (AI3b).
@export_range(0.0, 1.0) var crowded_commit: float = 0.6
## How far its aimed abilities lead a walking target: 0 = where it stands,
## 1 = where it will be when the hit lands (AI3b).
@export_range(0.0, 1.0) var aim_lead: float = 0.0
## How freely it fires its key ability: 0 = it holds it for the right moment,
## 1 = on cooldown; a roll every spend_roll_time s in between (AI3b).
@export_range(0.0, 1.0) var spend_eagerness: float = 0.4


func get_slider(slider: StringName) -> float:
	return float(get(slider))


func set_slider(slider: StringName, value: float) -> void:
	set(slider, clamp_slider(slider, value))


func get_intent_weight(intent: StringName) -> float:
	return intent_weights.get(intent, 1.0)


## Its crowded range (LoL units, edge to edge): crowded_range, or its band's
## minimum when that's −1.
func get_crowded_range() -> float:
	return range_band_min if crowded_range < 0.0 else crowded_range


static func clamp_slider(slider: StringName, value: float) -> float:
	var limits: Array = LIMITS.get(slider, [-INF, INF])
	return clampf(value, limits[0], limits[1])


## The copy a brain reads: each slider from `overrides` (slider -> value) or
## this preset, times every adjust's multiplier, clamped to its limits. The
## band's ends stay in order (max at least min). The kind is shared, not
## copied (the panel's changes to it show at once).
func resolve(overrides: Dictionary, adjusts: Array[BrainAdjust]) -> EnemyBehavior:
	var copy: EnemyBehavior = duplicate()
	for slider: StringName in SLIDERS:
		var value: float = float(overrides[slider]) if overrides.has(slider) else get_slider(slider)
		for adjust in adjusts:
			if adjust != null:
				value *= adjust.get_multiplier(slider)
		copy.set(slider, clamp_slider(slider, value))
	copy.range_band_max = maxf(copy.range_band_max, copy.range_band_min)
	return copy
