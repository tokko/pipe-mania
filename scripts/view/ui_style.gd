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


static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BTN_MIN
	b.add_theme_font_size_override("font_size", 30)
	return b


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


## Top inset (in viewport pixels) for a display cutout/notch; 0 when there is none or headless.
static func safe_top() -> int:
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return 0
	var inset := DisplayServer.get_display_safe_area().position.y
	if inset <= 0:
		return 0
	return int(inset * 1280.0 / win.y)
