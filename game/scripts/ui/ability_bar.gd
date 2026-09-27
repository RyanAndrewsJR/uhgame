extends Control
## LoL-style ability bar: Q W E R slots with cooldown sweep, seconds left,
## "being aimed" highlight and a tooltip on hover. Fail cues (ABILITIES.md,
## HUD feedback): a red flash when a press fails "not ready", a grey tint
## while the player can't cast (stunned, silenced), a blue tint while a
## slot's cost can't be paid (the resource bar flashes on the failed press).

const SLOT := 30.0
const GAP := 4.0
## Seconds a "not ready" / "silenced" flash lasts on a slot.
const FAIL_FLASH_TIME := 0.2

var abilities: AbilityComponent
var player: Player

var _hover: int = -1
var _font: Font
var _fail_flash: Dictionary = {}   # slot -> seconds left


func _ready() -> void:
	if abilities != null:
		abilities.cast_failed.connect(_on_abilities_cast_failed)
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	var w := SLOT * 4 + GAP * 3
	custom_minimum_size = Vector2(w, SLOT)
	size = custom_minimum_size
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -w * 0.5
	offset_right = w * 0.5
	offset_top = -SLOT - 8
	offset_bottom = -8


## True while `slot` shows a fail flash (for tests).
func is_flashing(slot: StringName) -> bool:
	return _fail_flash.get(slot, 0.0) > 0.0


func _on_abilities_cast_failed(slot: StringName, reason: String) -> void:
	if reason == AbilityComponent.FAIL_NOT_READY or reason == AbilityComponent.FAIL_SILENCED:
		_fail_flash[slot] = FAIL_FLASH_TIME


func _process(delta: float) -> void:
	for s: StringName in _fail_flash:
		_fail_flash[s] = maxf(_fail_flash[s] - delta, 0.0)
	var m := get_local_mouse_position()
	_hover = -1
	if Rect2(Vector2.ZERO, size).has_point(m):
		_hover = clampi(int(m.x / (SLOT + GAP)), 0, 3)
	queue_redraw()


func _draw() -> void:
	if abilities == null or not is_instance_valid(abilities):
		return
	for i in 4:
		var slot: StringName = AbilityComponent.SLOTS[i]
		var ability := abilities.get_ability(slot)
		var rect := Rect2(i * (SLOT + GAP), 0, SLOT, SLOT)
		draw_rect(rect.grow(1), Color(0, 0, 0, 0.8))
		if ability == null:
			draw_rect(rect, Color(0.15, 0.15, 0.18))
			continue
		# Icon placeholder: colored tile with the ability's initials.
		draw_rect(rect, Color(ability.icon_color.darkened(0.55)))
		draw_rect(rect.grow(-3), Color(ability.icon_color.darkened(0.25)))
		var frac := abilities.get_cooldown_fraction(slot)
		var charges := abilities.get_charges(slot)
		var max_charges := abilities.get_max_charges(slot)
		if charges > 0:
			var initials := _initials(ability.display_name)
			draw_string(_font, rect.position + Vector2(0, SLOT * 0.62), initials,
				HORIZONTAL_ALIGNMENT_CENTER, SLOT, 11, Color(1, 1, 1, 0.95))
			if frac > 0.0:
				# A charge is recharging while others are stored: a thin bar
				# along the bottom fills up as it comes back.
				draw_rect(Rect2(rect.position + Vector2(0, SLOT - 2), Vector2(SLOT * (1.0 - frac), 2)), Color(1, 1, 1, 0.7))
		else:
			# Cooldown sweep (dark overlay shrinking from the top) + seconds.
			draw_rect(Rect2(rect.position, Vector2(SLOT, SLOT * frac)), Color(0, 0, 0, 0.7))
			var left := abilities.get_cooldown_left(slot)
			var txt := "%.1f" % left if left < 1.0 else str(ceili(left))
			draw_string(_font, rect.position + Vector2(0, SLOT * 0.62), txt,
				HORIZONTAL_ALIGNMENT_CENTER, SLOT, 12, Color(1, 1, 1))
		if max_charges > 1 or charges > 1:
			# Stored charges, bottom right (only for abilities with charges).
			draw_string(_font, rect.position + Vector2(0, SLOT - 3), str(charges),
				HORIZONTAL_ALIGNMENT_RIGHT, SLOT - 2, 9, Color(1, 1, 1))

		# Can't cast right now: grey while stunned or silenced, blue while
		# the cost can't be paid.
		if player and player.is_cast_blocked():
			draw_rect(rect, Color(0.5, 0.5, 0.55, 0.55))
		elif not abilities.can_afford(slot):
			draw_rect(rect, Color(0.15, 0.3, 0.9, 0.45))
		var flash: float = _fail_flash.get(slot, 0.0)
		if flash > 0.0:
			draw_rect(rect, Color(1, 0.2, 0.2, 0.6 * flash / FAIL_FLASH_TIME))

		# Border: gold when aiming, bright when casting, else subtle.
		var border := Color(1, 1, 1, 0.25)
		if player and player.aiming_slot == slot:
			border = Color(1, 0.85, 0.3)
		elif abilities.casting_slot == slot:
			border = Color(1, 1, 1, 0.9)
		draw_rect(rect, border, false, 1.0)

		# Key label.
		draw_string(_font, rect.position + Vector2(2, 9), String(slot).to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.85))

	if _hover >= 0:
		_draw_tooltip(_hover)


func _draw_tooltip(i: int) -> void:
	var slot: StringName = AbilityComponent.SLOTS[i]
	var ability := abilities.get_ability(slot)
	if ability == null:
		return
	var w := 220.0
	# The description is a template filled with the real numbers (ABILITIES AB2).
	var lines := _wrap(ability.get_tooltip_plain(abilities.unit), w - 12, 8)
	var h := 30.0 + lines.size() * 10.0
	var x := clampf(i * (SLOT + GAP) + SLOT * 0.5 - w * 0.5, -position.x + 4, get_viewport_rect().size.x - position.x - w - 4)
	var rect := Rect2(x, -h - 6, w, h)
	draw_rect(rect, Color(0.05, 0.05, 0.08, 0.95))
	draw_rect(rect, Color(ability.icon_color, 0.8), false, 1.0)
	var title := "%s  [%s]" % [ability.display_name, String(slot).to_upper()]
	draw_string(_font, rect.position + Vector2(6, 12), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ability.icon_color)
	var cd := abilities.get_cooldown_duration(ability)
	var cost := abilities.get_cost(ability)
	var cost_text := "   Cost %s" % _num(cost) if cost > 0.0 else ""
	var max_charges := abilities.get_max_charges(slot)
	var charges_text := "   %d charges" % max_charges if max_charges > 1 else ""
	draw_string(_font, rect.position + Vector2(6, 22), "Cooldown %ss%s%s%s" % [_num(cd), cost_text, charges_text, "   Auto reset" if ability.resets_auto_attack else ""],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.75, 0.75, 0.8))
	for li in lines.size():
		draw_string(_font, rect.position + Vector2(6, 34 + li * 10), lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.9))


func _initials(name_text: String) -> String:
	var out := ""
	for word in name_text.split(" ", false):
		out += word.substr(0, 1).to_upper()
	return out.substr(0, 2)


func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


func _wrap(text: String, max_w: float, font_size: int) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in text.split(" ", false):
		var test := word if line == "" else line + " " + word
		if _font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_w and line != "":
			out.append(line)
			line = word
		else:
			line = test
	if line != "":
		out.append(line)
	return out
