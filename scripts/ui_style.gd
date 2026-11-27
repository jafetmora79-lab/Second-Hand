extends RefCounted
class_name UiStyle
## The game's look for everything on screen: the HUD, the main menu, the pause menu and their panels. Warm amber on dark, frosted-glass panels with thin
## warm borders; The Veil's pixel font for all text (assets/fonts/VeilPixel.ttf), at sizes snapped to its pixel grid. Also the small vector icons the
## HUD draws (flame, bowl, boot, log, firewood, coin, plank, furnace, sun, moon, snowflake) so no image files are needed.

const AMBER := Color(0.98, 0.78, 0.42)
const AMBER_DIM := Color(0.78, 0.6, 0.34)
const CREAM := Color(0.98, 0.94, 0.86)
const MUTED := Color(0.72, 0.74, 0.8)
const PANEL := Color(0.06, 0.07, 0.09, 0.72)
const PANEL_SOLID := Color(0.07, 0.075, 0.09, 0.94)
const EDGE := Color(0.98, 0.78, 0.42, 0.28)
const WARM := Color(0.98, 0.52, 0.22)
const FOOD := Color(0.86, 0.68, 0.34)
const STAMINA := Color(0.46, 0.82, 0.6)
const ICE := Color(0.62, 0.82, 1.0)
const MONEY := Color(0.62, 0.92, 0.56)
const DANGER := Color(0.95, 0.42, 0.36)

static var _pixel: FontFile = null

## The Veil's pixel font (assets/fonts/VeilPixel.ttf, square-pixel glyphs on a 13 px em), drawn without smoothing so every pixel stays
## crisp. Characters it lacks (the cent and registered signs, the bullet) fall back to Godot's built-in font.
static func pixel_font() -> FontFile:
	if _pixel == null:
		_pixel = load("res://assets/fonts/VeilPixel.ttf") as FontFile
		_pixel.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_pixel.hinting = TextServer.HINTING_NONE
		_pixel.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_pixel.generate_mipmaps = false
		_pixel.fallbacks = [ThemeDB.fallback_font]
	return _pixel

## A text size snapped to a whole multiple of the pixel font's 13 px em, so it stays crisp: small print 13, text 26, titles 39 and 52.
static func px(size: int) -> int:
	if size <= 15:
		return 13
	if size <= 32:
		return 26
	return 39 if size <= 45 else 52

static func title_font() -> Font:
	return pixel_font()

static func ui_font() -> Font:
	return pixel_font()

static func ui_bold() -> Font:
	return pixel_font()

## A rounded frosted panel.
static func panel_box(bg: Color = PANEL, radius: int = 10, border: Color = EDGE, pad: float = 14.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 8
	sb.anti_aliasing = true
	return sb

## The theme every menu uses: buttons that glow amber on hover, sliders and checkboxes in the same colours.
static func menu_theme() -> Theme:
	var t := Theme.new()
	t.default_font = ui_font()
	t.default_font_size = px(18)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0.04)
	normal.border_color = Color(1, 1, 1, 0.08)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 9
	normal.content_margin_bottom = 9
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.98, 0.78, 0.42, 0.16)
	hover.border_color = Color(0.98, 0.78, 0.42, 0.7)
	hover.border_width_left = 3
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.98, 0.78, 0.42, 0.28)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(1, 1, 1, 0.02)
	var focus := hover.duplicate() as StyleBoxFlat
	focus.bg_color = Color(0, 0, 0, 0)
	for st: Array in [["normal", normal], ["hover", hover], ["pressed", pressed], ["disabled", disabled], ["focus", focus], ["hover_pressed", pressed]]:
		t.set_stylebox(st[0], "Button", st[1])
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", AMBER)
	t.set_color("font_pressed_color", "Button", AMBER)
	t.set_color("font_focus_color", "Button", CREAM)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.3))
	t.set_constant("h_separation", "Button", 12)
	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_color", "CheckButton", CREAM)
	t.set_color("font_hover_color", "CheckButton", AMBER)
	t.set_color("font_pressed_color", "CheckButton", CREAM)
	for st2: String in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		var cb := StyleBoxEmpty.new()
		cb.content_margin_top = 6
		cb.content_margin_bottom = 6
		t.set_stylebox(st2, "CheckButton", cb)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.12)
	track.set_corner_radius_all(3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = AMBER_DIM
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var knob := GradientTexture2D.new()
	var kg := Gradient.new()
	kg.set_color(0, CREAM)
	kg.set_color(1, Color(CREAM, 0.0))
	kg.add_point(0.62, CREAM)
	kg.add_point(0.72, Color(CREAM, 0.0))
	knob.gradient = kg
	knob.fill = GradientTexture2D.FILL_RADIAL
	knob.fill_from = Vector2(0.5, 0.5)
	knob.fill_to = Vector2(1.0, 0.5)
	knob.width = 18
	knob.height = 18
	t.set_icon("grabber", "HSlider", knob)
	t.set_icon("grabber_highlight", "HSlider", knob)
	return t

static func title_label(text: String, size: int, col: Color = AMBER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", title_font())
	l.add_theme_font_size_override("font_size", px(size))
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_constant_override("shadow_offset_x", 0)
	return l

static func text_label(text: String, size: int = 16, col: Color = MUTED) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px(size))
	l.add_theme_color_override("font_color", col)
	return l

# ---- vector icons, drawn on any CanvasItem (c = centre, s = size in px) ----------------------------------------------------------------

static func icon(ci: CanvasItem, kind: String, c: Vector2, s: float, col: Color) -> void:
	match kind:
		"flame":
			var pts := PackedVector2Array()
			for k in 24:
				var a := TAU * k / 24.0
				var r := s * 0.42 * (1.0 - 0.45 * maxf(0.0, -sin(a)))
				var y := sin(a) * r * (1.25 if sin(a) < 0.0 else 0.9)
				pts.append(c + Vector2(cos(a) * r * 0.85, y + s * 0.08))
			pts[18] = c + Vector2(0, -s * 0.52)
			ci.draw_colored_polygon(pts, col)
			ci.draw_circle(c + Vector2(0, s * 0.16), s * 0.16, Color(1.0, 0.92, 0.6, col.a))
		"bowl":
			var pts2 := PackedVector2Array()
			for k in 13:
				var a2 := PI * k / 12.0
				pts2.append(c + Vector2(cos(a2) * s * 0.44, sin(a2) * s * 0.34))
			ci.draw_colored_polygon(pts2, col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.48, -s * 0.04), Vector2(s * 0.96, s * 0.08)), col)
			for k2 in 3:
				var x := (k2 - 1) * s * 0.16
				ci.draw_line(c + Vector2(x, -s * 0.12), c + Vector2(x + s * 0.05, -s * 0.4), Color(col, col.a * 0.7), maxf(1.5, s * 0.06))
		"bolt":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.08, -s * 0.5), c + Vector2(-s * 0.3, s * 0.06), c + Vector2(-s * 0.02, s * 0.06),
				c + Vector2(-s * 0.1, s * 0.5), c + Vector2(s * 0.3, -s * 0.08), c + Vector2(s * 0.02, -s * 0.08)]), col)
		"log":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.4, -s * 0.18), Vector2(s * 0.7, s * 0.36)), col)
			ci.draw_circle(c + Vector2(s * 0.3, 0), s * 0.2, col.lightened(0.25))
			ci.draw_arc(c + Vector2(s * 0.3, 0), s * 0.1, 0, TAU, 12, col.darkened(0.2), maxf(1.0, s * 0.04))
		"firewood":
			for k3 in 3:
				var o := Vector2((k3 - 1) * s * 0.26, (0.12 if k3 != 1 else -0.12) * s)
				ci.draw_colored_polygon(PackedVector2Array([c + o + Vector2(-s * 0.13, s * 0.16), c + o + Vector2(s * 0.13, s * 0.16), c + o + Vector2(0, -s * 0.18)]), col if k3 != 1 else col.lightened(0.2))
		"coin":
			ci.draw_circle(c, s * 0.38, col)
			ci.draw_arc(c, s * 0.28, 0, TAU, 20, col.darkened(0.3), maxf(1.0, s * 0.06))
		"plank":
			for k4 in 2:
				ci.draw_rect(Rect2(c + Vector2(-s * 0.42, -s * 0.2 + k4 * s * 0.24), Vector2(s * 0.84, s * 0.16)), col if k4 == 0 else col.darkened(0.15))
		"furnace":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.32, -s * 0.22), Vector2(s * 0.64, s * 0.62)), col.darkened(0.35))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.08, -s * 0.48), Vector2(s * 0.16, s * 0.28)), col.darkened(0.35))
			icon(ci, "flame", c + Vector2(0, s * 0.12), s * 0.5, col)
		"sun":
			ci.draw_circle(c, s * 0.22, col)
			for k5 in 8:
				var a5 := TAU * k5 / 8.0
				ci.draw_line(c + Vector2(cos(a5), sin(a5)) * s * 0.32, c + Vector2(cos(a5), sin(a5)) * s * 0.46, col, maxf(1.5, s * 0.07))
		"moon":
			ci.draw_circle(c, s * 0.34, col)
			ci.draw_circle(c + Vector2(s * 0.16, -s * 0.1), s * 0.3, Color(0.06, 0.07, 0.09, 1.0))
		"snow":
			for k6 in 3:
				var a6 := PI * k6 / 3.0
				var d := Vector2(cos(a6), sin(a6)) * s * 0.44
				ci.draw_line(c - d, c + d, col, maxf(1.5, s * 0.07))
		"drop":
			ci.draw_circle(c + Vector2(0, s * 0.1), s * 0.26, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.24, s * 0.02), c + Vector2(s * 0.24, s * 0.02), c + Vector2(0, -s * 0.44)]), col)
		"truck":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.45, -s * 0.1), Vector2(s * 0.9, s * 0.3)), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.1, -s * 0.34), Vector2(s * 0.36, s * 0.26)), col)
			ci.draw_circle(c + Vector2(-s * 0.26, s * 0.24), s * 0.13, col.darkened(0.5))
			ci.draw_circle(c + Vector2(s * 0.26, s * 0.24), s * 0.13, col.darkened(0.5))

## A rounded box drawn straight on a CanvasItem (the HUD draws its own panels).
static func draw_panel(ci: CanvasItem, r: Rect2, bg: Color = PANEL, radius: float = 10.0, border: Color = EDGE) -> void:
	var sb := panel_box(bg, int(radius), border, 0.0)
	sb.shadow_size = 0
	ci.draw_style_box(sb, r)

## A key cap with its letter, as in "[E] pick berries". Returns its width.
static func key_cap(ci: CanvasItem, pos: Vector2, key: String, size: int) -> float:
	var f := ui_bold()
	var tw := f.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var w := maxf(tw + size * 0.9, size * 1.6)
	var h := size * 1.5
	var r := Rect2(pos - Vector2(0, h * 0.5), Vector2(w, h))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.92, 0.84, 0.95)
	sb.border_color = Color(0.55, 0.45, 0.32)
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(4)
	ci.draw_style_box(sb, r)
	ci.draw_string(f, Vector2(pos.x + (w - tw) * 0.5, pos.y + size * 0.36), key, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.12, 0.1, 0.08))
	return w
