class_name BrainAdjust
extends Resource
## One multiplier per brain slider (ENEMIES_AI.md, Scaling; AI1), 1 =
## unchanged, and a token bonus. Ranks (in the EnemyAITable's RankRules),
## factions (`brain_adjust_faction_<name>.tres`, AI7), difficulty tiers
## (DifficultyTier.brain_adjust, DUNGEONS.md) and elite modifiers (AI5) each
## hold one; an enemy's sliders at spawn are its preset's values (or its own
## overrides) times every adjust that applies, clamped to the slider's limits
## (EnemyBehavior.resolve()). The range band's multiplier moves both ends.

@export var aggression: float = 1.0
@export var respect_weight: float = 1.0
@export var patience_time: float = 1.0
@export var range_band: float = 1.0
@export var reaction_time: float = 1.0
@export var dodge_skill: float = 1.0
@export var dodge_cooldown: float = 1.0
@export var punish_greed: float = 1.0
@export var finish_threshold: float = 1.0
@export var pressure_time: float = 1.0
@export var breather_time: float = 1.0
@export var jitter: float = 1.0
## AI3b's sliders (Duels and odds).
@export var confidence: float = 1.0
@export var crowded_commit: float = 1.0
@export var aim_lead: float = 1.0
@export var spend_eagerness: float = 1.0
## AI3c's (Odds).
@export var nerve: float = 1.0
## AI-D1's (Combos).
@export var peel_threshold: float = 1.0
@export var opening_bar: float = 1.0
## AI-D2's (Combos: combo plans).
@export var follow_through: float = 1.0
@export var combo_greed: float = 1.0
@export var mixup: float = 1.0
## Attack tokens added to each target's pool (difficulty tiers; AI2).
@export var token_bonus: int = 0


## The multiplier for `slider` (an EnemyBehavior.SLIDERS name; the band's two
## ends share `range_band`).
func get_multiplier(slider: StringName) -> float:
	if slider == &"range_band_min" or slider == &"range_band_max":
		return range_band
	var value: Variant = get(slider)
	return float(value) if value != null else 1.0
