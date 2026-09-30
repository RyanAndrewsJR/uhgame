class_name AttackSwing
extends Resource
## One swing of a basic attack combo (COMBAT.md, Data). Timings are at base
## attack speed; AutoAttackComponent divides them by the combo speed
## (attack_speed / base attack speed).

## Seconds from the click to the hit.
@export var windup: float = 0.08
## Seconds the whole swing lasts (windup + recovery). The attacker is rooted
## for all of it.
@export var duration: float = 0.3
## Damage as a fraction of attack_damage.
@export var ad_ratio: float = 1.0
## Reach as a multiple of the attacker's attack_range stat, measured from the
## attacker's feet to the target's edge.
@export var reach_multiplier: float = 1.0
## Width of the swing, in degrees (centered on the aim).
@export var arc_deg: float = 110.0
## Push distance in px, over knockback_duration (knockback curve).
@export var knockback_px: float = 6.0
@export var knockback_duration: float = 0.1
## Hit feel tier (COMBAT C3): LIGHT for normal swings, HEAVY for finishers.
@export var feel: HitContext.Feel = HitContext.Feel.LIGHT
## Melee combos: the swing's base step forward along its aim, in px, during
## its windup (COMBAT.md, Melee basic attacks). 0 = none. Ranged combos
## ignore it.
@export var lunge_px: float = 6.0
## Melee combos: the longest step toward an aimed enemy (target pull), px.
@export var lunge_max_px: float = 24.0
## Scales on-hit chances and effects (COMBAT C8).
@export var proc_coefficient: float = 1.0
## Seconds after this swing ends before the next swing can start: a breather,
## e.g. after a finisher (Hades' sword). 0 = none. Only attacking waits:
## moving, dashing and abilities don't. A click during it fires when it ends.
## Divided by the combo speed like every swing timing.
@export var pause_after: float = 0.0

@export_group("Sounds")
## At swing start, whiffs included (AUDIO.md). null = silent.
@export var swing_sound: SoundEvent
## On landing, once per swing however many it hits (through
## HitContext.hit_sound). null = HitFeel's sound for the hit's tier.
@export var hit_sound: SoundEvent
## Multiplies the pitch of both sounds (the combo pitches up: 1.00, 1.04).
@export_range(0.5, 2.0) var sound_pitch: float = 1.0

@export_group("Presentation")
## ABILITIES AB14 presentation hooks, the swing's side of an ability's
## cast_vfx / impact_vfx / cast_anim; empty until the art pass. VFX only.
## Timed by the swing's own speed (attack_speed x speed_scale), never cast speed.
## At swing start (whiffs included), at the attacker's feet, rotated to the
## swing's aim; setup(attacker, swing) on its root if it has one. null = nothing.
@export var swing_vfx: PackedScene
## On each enemy whose hit got through, rotated attacker -> enemy;
## setup(attacker, hit) on its root if it has one. null = nothing.
@export var impact_vfx: PackedScene
## An animation on the attacker's Body/AnimationPlayer, positioned each tick
## to the swing's progress x its length. Empty, no such player or no such
## animation = nothing.
@export var swing_anim: StringName = &""
