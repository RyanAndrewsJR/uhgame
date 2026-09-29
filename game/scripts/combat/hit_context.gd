class_name HitContext
extends RefCounted
## One hit: one application of damage and effects to a unit (COMBAT.md).
## The attacker fills in the inputs; the hit pipeline (HitPipeline.resolve()
## and the target's on_hit()) fills in the results.

enum DamageType {
	PHYSICAL,  ## Reduced by armor.
	MAGIC,     ## Reduced by magic_resist.
	TRUE,      ## Ignores both.
}

## Hit feel tier (COMBAT.md, Numbers). A kill upgrades it (COMBAT C3).
enum Feel { NONE, LIGHT, HEAVY }

const DAMAGE_TYPE_TAGS: Array[StringName] = [&"physical", &"magic", &"true"]


## One crit roll shared by every hit of one swing or cast (COMBAT.md, Crits):
## the first hit rolls, the others copy its result, so the swing crits
## everyone or no one and the attacker's PRD counter moves once.
class CritRoll:
	extends RefCounted
	var decided: bool = false
	var is_crit: bool = false

# --- Inputs ---------------------------------------------------------------------

## Who dealt the hit. null = the environment. Kill credit goes here.
var source: Unit
## What was hit: a Unit, or an interactable with on_hit(ctx).
var target: Node
## The ability that caused the hit. null for basic attacks, statuses,
## hazards and knockback.
var ability: Ability
var base_damage: float = 0.0
## Fractions of the source's attack_damage / ability_power added to base_damage.
var ad_ratio: float = 0.0
var ap_ratio: float = 0.0
var damage_type: DamageType = DamageType.PHYSICAL
## basic_attack, ability, proc, dot, crit, the damage type tag, plus the
## ability's tags. add_tag() avoids duplicates.
var tags: Array[StringName] = []
## False for DoT ticks and wrapped take_damage() calls.
var can_crit: bool = true
## Shared by the hits of one swing or cast (HitContext.CritRoll.new()).
## null = this hit rolls on its own.
var crit_roll: CritRoll
## Scales on-hit chances and effects (COMBAT C8).
var proc_coefficient: float = 1.0
## Push distance in px. 0 = no knockback.
var knockback_px: float = 0.0
var knockback_duration: float = 0.1
## null = the target's MovementComponent.knockback_curve.
var knockback_curve: Curve
## The push goes away from this point. INF = the source's position.
var knockback_from: Vector2 = Vector2.INF
## Statuses applied to the target after the damage, from the source
## (COMBAT C9). Blocked hits apply none.
var statuses: Array[StatusEffect] = []
var feel: Feel = Feel.NONE
## Set by take_damage(highlight), empowered hits and projectiles. Since C6
## damage numbers don't read it (size and color come from the hit); kept
## for tests and later UI.
var highlight: bool = false
## The swing's or ability's own hit sound (AUDIO.md); CombatSounds plays it
## once per swing or cast. null = HitFeel's sound for the hit's tier.
var hit_sound: SoundEvent
## Pitch for whichever hit sound plays (the swing's sound_pitch).
var hit_sound_pitch: float = 1.0

# --- Results (filled in by the pipeline) -------------------------------------

## Damage before mitigation.
var raw_damage: float = 0.0
## Damage after mitigation (and incoming_damage, COMBAT C8): "damage taken".
var taken_damage: float = 0.0
## Taken by shields (COMBAT C10).
var absorbed: float = 0.0
## Health actually lost (capped by the health that was left).
var health_lost: float = 0.0
var is_crit: bool = false
## The target's status tags just before the hit (Unit.on_hit fills it in;
## reaction rules read it, since a kill clears the statuses). COMBAT C11.
var target_tags: Array[StringName] = []
## The reaction chain depth this hit counts at (ABILITIES AB8): a free cast's
## hits carry its depth (HitPipeline.from_ability() copies CastContext
## .chain_depth), so a "on hit, also cast" rule can't loop. 0 for every
## ordinary hit.
var chain_depth: int = 0
## Blocked by invulnerability (i-frames) or a dead target: nothing happened.
var blocked: bool = false
## This hit killed the target.
var killed: bool = false


func add_tag(tag: StringName) -> void:
	if not tags.has(tag):
		tags.append(tag)


func has_tag(tag: StringName) -> bool:
	return tags.has(tag)


## &"physical", &"magic" or &"true".
static func get_damage_type_tag(type: DamageType) -> StringName:
	return DAMAGE_TYPE_TAGS[type]
