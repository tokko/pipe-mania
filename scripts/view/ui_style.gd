extends RefCounted
## Shared UI style for the menu / run-over / leaderboard / settings / splash screens. One place for
## the brand palette + a >=44dp button factory so the 5 new screens don't drift (a code helper, not
## a .tres — matches this project's all-code view convention). Pipe/board colors stay in tile.gd.

const BG := Color(0.12, 0.14, 0.16)     # #1F232A — dark board background
const BRASS := Color(0.85, 0.72, 0.40)  # #D9B766 — signature accent
const TEXT := Color(0.92, 0.92, 0.95)

const BTN_MIN := Vector2(180, 64)  # comfortable touch target at the 720x1280 viewport


static func title(text: String, size: int = 64) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", BRASS)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func label(text: String, size: int = 30) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func button(text: String, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BTN_MIN
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", BG if primary else TEXT)
	b.add_theme_color_override("font_hover_color", BG if primary else TEXT)
	b.add_theme_color_override("font_pressed_color", BG if primary else TEXT)
	b.add_theme_color_override("font_focus_color", BG if primary else TEXT)
	b.add_theme_stylebox_override("normal", _button_box(primary, 0.0))
	b.add_theme_stylebox_override("hover", _button_box(primary, 0.08))
	b.add_theme_stylebox_override("pressed", _button_box(primary, -0.08))
	b.add_theme_stylebox_override("focus", _button_box(primary, 0.08))
	return b


static func _button_box(primary: bool, shade: float) -> StyleBoxFlat:
	var fill := BRASS if primary else Color(0.18, 0.20, 0.23)
	if shade > 0.0:
		fill = fill.lightened(shade)
	elif shade < 0.0:
		fill = fill.darkened(-shade)
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = BRASS if primary else Color(0.38, 0.40, 0.44)
	box.set_border_width_all(2)
	box.set_corner_radius_all(12)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box


static func card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_box())
	return panel


static func _card_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.09, 0.11, 0.13)
	box.border_color = Color(0.48, 0.40, 0.24)
	box.set_border_width_all(2)
	box.set_corner_radius_all(24)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	box.shadow_size = 18
	box.shadow_offset = Vector2(0, 8)
	return box


## A full-rect opaque modal backdrop that also swallows pointer events (so taps can't fall through
## to the board / a screen beneath).
static func backdrop() -> ColorRect:
	var r := ColorRect.new()
	r.color = BG
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	return r


## A centered VBox inside a full-rect container. Adds the container to `parent`, returns the VBox.
## (Centered content sits inside the safe area on notched phones for free.)
static func centered_column(parent: Node) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 24)
	center.add_child(vb)
	parent.add_child(center)
	return vb


## A padded, dark raised card centered inside the parent. Adds the full-rect container to `parent`.
static func centered_card(parent: Node) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel := card()
	panel.custom_minimum_size = Vector2(420, 0)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 24)
	margin.add_child(column)
	panel.add_child(margin)
	center.add_child(panel)
	parent.add_child(center)
	return column


## Top inset (in viewport pixels) for a display cutout/notch; 0 when there is none or headless.
static func safe_top() -> int:
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return 0
	var inset := DisplayServer.get_display_safe_area().position.y
	if inset <= 0:
		return 0
	return int(inset * 1280.0 / win.y)


## Bottom inset (in viewport pixels) for gesture navigation / display cutouts; 0 when there is none or headless.
static func safe_bottom() -> int:
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return 0
	var safe_area := DisplayServer.get_display_safe_area()
	var inset := win.y - (safe_area.position.y + safe_area.size.y)
	if inset <= 0:
		return 0
	return int(inset * 1280.0 / win.y)
