class_name FeelPreset
extends Resource
## FEEL2 (Slice B; Ryan with his combat advisor, 2026-10-09): one blind A/B
## option set for the shake, the player's turning and being hit. Data only;
## apply() writes it into the live look and feel. Three files in
## res://data/feel_presets/: feel_preset_today.tres is the feel before FEEL2
## shipped, feel_preset_hit_taken.tres (preset 3) the shipped feel since
## 2026-10-09 (Ryan's pick). SandboxFeel cycles them blind (F10) for later
## rounds. Presentation only: none of these changes a gameplay number.

## For the console's mapping (Shift+F10); never shown on screen.
@export var display_name: String = "today"

@export_group("Shake (F1)")
## CameraLook.shake_decay_px: the shake's size drops this much a second.
@export var shake_decay_px: float = 30.0
## CameraLook.shake_after_hitstop: the shake starts when the hitstop ends.
@export var shake_after_hitstop: bool = false
## CameraLook.shake_directional: a shake with a direction leans along it.
@export var shake_directional: bool = false

@export_group("Turning (F2)")
## The tracked player's model turn rate (UnitView.player_turn_rate); enemies
## keep their own (20).
@export var player_turn_rate: float = 20.0

@export_group("Being hit (F3)")
## HitFeel.hit_taken_feel_enabled and its two numbers.
@export var hit_taken_feel_enabled: bool = false
@export var taken_hitstop: float = 0.06
@export var taken_shake: float = 2.5


## Writes this preset into `look`, `feel` and UnitView's player turn rate.
func apply(look: CameraLook, feel: HitFeel) -> void:
	look.shake_decay_px = shake_decay_px
	look.shake_after_hitstop = shake_after_hitstop
	look.shake_directional = shake_directional
	UnitView.player_turn_rate = player_turn_rate
	feel.hit_taken_feel_enabled = hit_taken_feel_enabled
	feel.taken_hitstop = taken_hitstop
	feel.taken_shake = taken_shake


## The values in use now, as a preset (to put them back later). A player turn
## rate below 0 (none set) reads as itself, so restore() puts that back too.
static func capture(look: CameraLook, feel: HitFeel) -> FeelPreset:
	var p := FeelPreset.new()
	p.display_name = "captured"
	p.shake_decay_px = look.shake_decay_px
	p.shake_after_hitstop = look.shake_after_hitstop
	p.shake_directional = look.shake_directional
	p.player_turn_rate = UnitView.player_turn_rate
	p.hit_taken_feel_enabled = feel.hit_taken_feel_enabled
	p.taken_hitstop = feel.taken_hitstop
	p.taken_shake = feel.taken_shake
	return p


## Every value, in order (tests compare presets with it).
func to_array() -> Array:
	return [shake_decay_px, shake_after_hitstop, shake_directional, player_turn_rate,
		hit_taken_feel_enabled, taken_hitstop, taken_shake]
