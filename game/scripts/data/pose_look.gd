class_name PoseLook
extends Resource
## One pose's look (ENEMIES_AI.md, Tells and PoseSet; AI1): a capsule look now
## (a lean, a squash, a rim pulse) and a model's clip later (the art pass).
## Inline in a PoseSet. View data: it never changes gameplay state.

## A model's clip for this pose (empty = none; capsules ignore it).
@export var clip: StringName = &""
## Degrees the body leans, + toward the target, − away.
@export_range(-45.0, 45.0) var lean_deg: float = 0.0
## Height scale (1 = none; 0.8 squashes down, 1.1 stretches up); the width
## goes the other way.
@export_range(0.5, 1.5) var squash: float = 1.0
## The rim's color over the model (the hit flash's overlay, tinted); alpha 0
## = none.
@export var rim_color: Color = Color(1, 1, 1, 0)
## The rim pulses this many times a second (0 = steady).
@export_range(0.0, 10.0) var pulse_hz: float = 0.0


static func make(p_lean_deg: float, p_squash: float = 1.0, p_rim_color: Color = Color(1, 1, 1, 0), p_pulse_hz: float = 0.0) -> PoseLook:
	var look := PoseLook.new()
	look.lean_deg = p_lean_deg
	look.squash = p_squash
	look.rim_color = p_rim_color
	look.pulse_hz = p_pulse_hz
	return look
