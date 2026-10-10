class_name ThreatPalette
extends Resource
## EXPERIMENT (FEEL2, Slice C; Ryan with his combat advisor, 2026-10-09): the
## colors of enemy threat as data: the floor telegraph's threat color and the
## perilous glyph's look. Three files in res://data/threat_palettes/
## (threat_palette_today.tres is today, exactly); SandboxFeel switches them
## (F7). Presentation only: no telegraph's timing or shape changes, and a
## telegraph an ability tints itself (not the threat color) keeps its tint.
## While `active` is null (shipped config) everything uses today's built-in
## values: Telegraph.THREAT_COLOR and ScreenOverlay's perilous_icon_* exports.

## The palette in use, or null: today's built-ins.
static var active: ThreatPalette = null

## For the console and the sandbox's line.
@export var display_name: String = "today"

@export_group("Floor telegraph")
## Replaces Telegraph.THREAT_COLOR on every telegraph drawn in it.
@export var threat_color: Color = Color(1.0, 0.35, 0.15)

@export_group("Perilous glyph")
@export var glyph_color: Color = Color(0.95, 0.12, 0.1, 1.0)
@export var glyph_outline_color: Color = Color(0, 0, 0, 1)
@export_range(0, 16) var glyph_outline_size: int = 4
## Pulses per second while it shows (0 = steady, today). The alpha goes
## from full down to glyph_pulse_min_alpha and back, starting full.
@export var glyph_pulse_hz: float = 0.0
@export_range(0.0, 1.0, 0.05) var glyph_pulse_min_alpha: float = 0.6


## The pulse's alpha `t` seconds after the glyph appeared (1 = full).
func get_glyph_alpha(t: float) -> float:
	if glyph_pulse_hz <= 0.0:
		return 1.0
	return lerpf(glyph_pulse_min_alpha, 1.0, 0.5 + 0.5 * cos(TAU * glyph_pulse_hz * t))
