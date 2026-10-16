class_name KillFeed
extends VBoxContainer
## The kill feed (top right; Foundations: KILL FEED, mockup 09): one plate per death, newest at the bottom, at most
## [constant MAX_LINES] lines, each staying [code]feed_time_ms[/code] (the theme's "Hud" type) and then fading out.
## A line reads "Killer [weapon] [headshot] Victim": the names in their team's UI colour (yours blue, the enemy's
## red), the weapon's icon from [UiIcons] by [member WeaponData.id] (M7's rendered [member WeaponData.kill_icon] while the
## slot is empty, then the weapon's name) and the headshot mark after it. A death without a killer (the bomb, a fall)
## has no killer name: the cause's icon in the alert colour, then the victim. Your own kill is a solid INK plate with
## a TEXT frame, your death one with an ENEMY frame; every other line is the ink plate at 72%.
##
## It only shows what [method add_kill] is told; [RoundHud] feeds it from [signal RoundManager.character_killed].
## The look is all roles of the UI theme ([code]HudFeedPlate[/code], [code]HudFeedPlateYou[/code],
## [code]HudFeedPlateDeath[/code], [code]HudSmallLabel[/code]); a team's colour is the palette's UI colour for it.

## The most lines shown at once; a new kill pushes the oldest one out.
const MAX_LINES := 5
## Seconds a line then takes to fade out.
const FADE_TIME := 0.5
## Between killer and victim when there is no weapon to show.
const KILL_SEPARATOR := ">"
## After the weapon when the killing bullet hit the head and the headshot icon's slot is empty.
const HEADSHOT_TEXT := "HS"
## The theme types that hold the HUD's sizes and the palette's colours.
const THEME_TYPE := &"Hud"
const PALETTE_TYPE := &"Palette"
## The roles of a line's plate: a kill between others, your kill, your death.
const PLATE_NORMAL := &"HudFeedPlate"
const PLATE_KILL := &"HudFeedPlateYou"
const PLATE_DEATH := &"HudFeedPlateDeath"
## A bot's callout (v0.2, D-232): a plain plate with a team-coloured edge at its left, so it never reads as a kill.
const PLATE_CALL := &"HudFeedPlateCall"
## At most this many callout lines show; the older one dims (the designer's "max 2 callout lines").
const MAX_CALLOUTS := 2
## The meta key that marks a callout line.
const CALLOUT_META := &"callout"
## How much the older callout line is dimmed.
const OLDER_CALLOUT_ALPHA := 0.6
const HEADSHOT_SLOT := &"headshot"

var _ui_scale: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Adds a line for a death. [param killer] may be null (and a character that killed itself counts as no killer):
## then the line shows [param cause]'s icon (an icon slot such as "bomb", in the alert colour) and the victim, or just
## the victim. [param weapon] is what killed the victim, for its icon.
func add_kill(victim: Character, killer: Character, headshot: bool, weapon: WeaponData = null, cause: StringName = &"") -> void:
	var has_killer := killer != null and killer != victim
	var plate_role := PLATE_NORMAL
	if victim.is_local_player():
		plate_role = PLATE_DEATH
	elif has_killer and killer.is_local_player():
		plate_role = PLATE_KILL
	var line := PanelContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.size_flags_horizontal = Control.SIZE_SHRINK_END
	line.theme_type_variation = plate_role
	line.custom_minimum_size.y = get_theme_constant(&"feed_height", THEME_TYPE)
	# In the tree first: the theme is looked up through the parents.
	add_child(line)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.theme_type_variation = &"HudRowIcon"
	line.add_child(row)
	if has_killer:
		row.add_child(_make_label("Killer", String(killer.name), _team_color(killer.team)))
		_add_weapon(row, weapon)
	elif cause != &"":
		_add_icon(row, "Cause", cause, &"alert")
	if headshot:
		if not _add_icon(row, "Headshot", HEADSHOT_SLOT, &"text"):
			row.add_child(_make_label("Headshot", HEADSHOT_TEXT, get_theme_color(&"alert", PALETTE_TYPE)))
	row.add_child(_make_label("Victim", String(victim.name), _team_color(victim.team)))
	UiScale.apply_tree(line, _ui_scale)
	while get_child_count() > MAX_LINES:
		_remove_line(get_child(0))
	# The tween belongs to the line, so it ends with it when the line is pushed out, and a pause stops it.
	var tween := line.create_tween()
	tween.tween_interval(get_lifetime())
	tween.tween_property(line, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(_remove_line.bind(line))


## Adds a line for a callout of [param caller] ("Bot3  ENEMY NEAR A"): its name in its team's colour, [param text] in the
## text colour, a [param edge]-coloured bar at the left. Keeps at most [constant MAX_CALLOUTS] of them, the older one dimmed.
func add_callout(caller: Character, text: String) -> void:
	var line := PanelContainer.new()
	line.set_meta(CALLOUT_META, true)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.size_flags_horizontal = Control.SIZE_SHRINK_END
	line.theme_type_variation = PLATE_CALL
	line.custom_minimum_size.y = get_theme_constant(&"feed_height", THEME_TYPE)
	add_child(line)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.theme_type_variation = &"HudRowIcon"
	line.add_child(row)
	var edge := ColorRect.new()
	edge.name = "Edge"
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.custom_minimum_size.x = get_theme_constant(&"callout_edge", THEME_TYPE)
	edge.color = _team_color(caller.team)
	row.add_child(edge)
	row.add_child(_make_label("Caller", String(caller.name), _team_color(caller.team)))
	row.add_child(_make_label("Text", text, get_theme_color(&"text", PALETTE_TYPE)))
	UiScale.apply_tree(line, _ui_scale)
	var callouts := get_children().filter(func(child: Node) -> bool: return child.has_meta(CALLOUT_META))
	while callouts.size() > MAX_CALLOUTS:
		_remove_line(callouts.pop_front())
	for older in callouts.slice(0, callouts.size() - 1):
		(older as Control).modulate.a = OLDER_CALLOUT_ALPHA
	var tween := line.create_tween()
	tween.tween_interval(get_lifetime())
	tween.tween_property(line, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(_remove_line.bind(line))


## Removes every line at once.
func clear() -> void:
	for line in get_children():
		_remove_line(line)


## How many lines are showing right now.
func get_line_count() -> int:
	return get_child_count()


## Seconds a line stays fully visible (before it fades), from the theme.
func get_lifetime() -> float:
	return get_theme_constant(&"feed_time_ms", THEME_TYPE) / 1000.0


## Scales the lines already there and the ones added later (1.0 = the 720-pixel design).
func set_ui_scale(factor: float) -> void:
	_ui_scale = factor
	UiScale.apply_tree(self, factor)
	for rect: TextureRect in find_children("*", "TextureRect", true, false):
		UiIcons.fit_rect(rect, factor)


## The weapon between the names: its icon, else its rendered icon, else its name; ">" without a weapon.
func _add_weapon(row: HBoxContainer, weapon: WeaponData) -> void:
	if weapon == null:
		row.add_child(_make_label("Separator", KILL_SEPARATOR, get_theme_color(&"text_dim", PALETTE_TYPE)))
		return
	if weapon.id != &"" and _add_icon(row, "Weapon", weapon.id, &"text"):
		return
	if weapon.kill_icon != null:
		var rect := UiIcons.make_rect(weapon.kill_icon, get_theme_color(&"text", PALETTE_TYPE), _ui_scale)
		rect.name = "Weapon"
		row.add_child(rect)
		return
	row.add_child(_make_label("Weapon", weapon.display_name, get_theme_color(&"text", PALETTE_TYPE)))


## Adds the icon of [param slot], tinted with the palette's [param tint]; false (nothing added) while the slot is empty.
func _add_icon(row: HBoxContainer, icon_name: String, slot: StringName, tint: StringName) -> bool:
	var texture := UiIcons.get_icon(self, slot)
	if texture == null:
		return false
	var rect := UiIcons.make_rect(texture, get_theme_color(tint, PALETTE_TYPE), _ui_scale)
	rect.name = icon_name
	row.add_child(rect)
	return true


func _make_label(label_name: String, text: String, color: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.theme_type_variation = &"HudSmallLabel"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	return label


## The UI colour of [param team]: friendly for the viewer's team, enemy for the other (the
## colour-blind scheme's, D-210, when it is on).
func _team_color(team: int) -> Color:
	return Teams.ui_color_for(team)


func _remove_line(line: Node) -> void:
	if line.get_parent() == self:
		remove_child(line)
	line.queue_free()
