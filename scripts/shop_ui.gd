extends Control
class_name ShopUi
## Everything on screen in the shop: the top bar (day, money, rent), what the customer says, the buttons for what you can do, the inspection panel
## (how to look, the clues you have found, your estimate), the haggle panel, the loupe under the mouse, the day title and the end-of-day summary.

var game: Node
var loupe_at := Vector2.ZERO
var loupe_on := false
var loupe_progress := 0.0
var loupe_hint := ""
var _speech_name: Label
var _speech_text: Label
var _speech: PanelContainer
var _actions: VBoxContainer
var _inspect: PanelContainer
var _clues: VBoxContainer
var _estimate: Label
var _haggle: PanelContainer
var _ask_label: Label
var _offer_label: Label
var _slider: HSlider
var _patience: Label
var _summary: Control = null
var _feed: PanelContainer                  ## the porch camera: who is at the door
var _feed_tex: TextureRect
var _feed_note: Label
var _title: Label
var _sub: Label
var _toast_t := 0.0
var _toast_text := ""
var _cash_fx: Array = []
var _shown_money := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiStyle.menu_theme()
	_speech = PanelContainer.new()
	_speech.add_theme_stylebox_override("panel", UiStyle.panel_box(UiStyle.PANEL, 10, UiStyle.EDGE, 16.0))
	_speech.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_speech.custom_minimum_size = Vector2(620, 0)
	_speech.position = Vector2(-310, -190)
	_speech.anchor_left = 0.5
	_speech.anchor_right = 0.5
	_speech.anchor_top = 1.0
	_speech.anchor_bottom = 1.0
	_speech.offset_left = -330
	_speech.offset_right = 330
	_speech.offset_top = -180
	_speech.offset_bottom = -30
	_speech.visible = false
	add_child(_speech)
	var sv := VBoxContainer.new()
	_speech.add_child(sv)
	_speech_name = UiStyle.text_label("", 15, UiStyle.AMBER)
	_speech_name.add_theme_font_override("font", UiStyle.ui_bold())
	sv.add_child(_speech_name)
	_speech_text = UiStyle.text_label("", 18, UiStyle.CREAM)
	_speech_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech_text.custom_minimum_size = Vector2(620, 0)
	sv.add_child(_speech_text)
	_actions = VBoxContainer.new()
	_actions.anchor_left = 1.0
	_actions.anchor_right = 1.0
	_actions.anchor_top = 1.0
	_actions.anchor_bottom = 1.0
	_actions.offset_left = -270
	_actions.offset_right = -24
	_actions.offset_top = -200
	_actions.offset_bottom = -30
	_actions.alignment = BoxContainer.ALIGNMENT_END
	_actions.add_theme_constant_override("separation", 8)
	add_child(_actions)
	_build_inspect()
	_build_haggle()
	_build_feed()
	_title = UiStyle.title_label("", 64, UiStyle.CREAM)
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.offset_left = -400
	_title.offset_right = 400
	_title.offset_top = -80
	_title.offset_bottom = 0
	_title.modulate.a = 0.0
	add_child(_title)
	_sub = UiStyle.text_label("", 20, UiStyle.AMBER)
	_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.offset_left = -400
	_sub.offset_right = 400
	_sub.offset_top = 0
	_sub.offset_bottom = 40
	_sub.modulate.a = 0.0
	add_child(_sub)

func _panel_right(width: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiStyle.panel_box(UiStyle.PANEL, 10, UiStyle.EDGE, 18.0))
	p.anchor_left = 1.0
	p.anchor_right = 1.0
	p.offset_left = -width - 24
	p.offset_right = -24
	p.offset_top = 80
	p.visible = false
	add_child(p)
	return p

func _build_feed() -> void:
	_feed = PanelContainer.new()
	_feed.add_theme_stylebox_override("panel", UiStyle.panel_box(UiStyle.PANEL, 10, UiStyle.EDGE, 14.0))
	_feed.position = Vector2(24, 80)
	_feed.visible = false
	add_child(_feed)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_feed.add_child(v)
	var head := HBoxContainer.new()
	var rec := UiStyle.text_label("● REC", 12, UiStyle.DANGER)
	head.add_child(rec)
	head.add_child(UiStyle.text_label("   PORCH CAMERA", 12, UiStyle.AMBER_DIM))
	v.add_child(head)
	_feed_tex = TextureRect.new()
	_feed_tex.custom_minimum_size = Vector2(384, 288)
	_feed_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_feed_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	v.add_child(_feed_tex)
	_feed_note = UiStyle.text_label("", 15, UiStyle.CREAM)
	_feed_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feed_note.custom_minimum_size = Vector2(384, 0)
	v.add_child(_feed_note)

## Someone rang: the porch camera, what you can tell about them, and the two buttons.
func show_door(title: String, look: String, note: String, tex: Texture2D) -> void:
	_feed_tex.texture = tex
	_feed_note.text = note
	_feed.visible = true
	say(title, look)
	hide_actions()
	_action("Buzz them in", func() -> void:
		hide_actions()
		_feed.visible = false
		game.buzz_in())
	_action("Not today", func() -> void:
		hide_actions()
		_feed.visible = false
		game.turn_away())

func show_robbery_actions() -> void:
	hide_actions()
	_action("Hand over the cash", func() -> void:
		hide_actions()
		game.rob_pay())
	_action("Hit the alarm", func() -> void:
		hide_actions()
		game.rob_alarm())

func _build_inspect() -> void:
	_inspect = _panel_right(330)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_inspect.add_child(v)
	v.add_child(UiStyle.title_label("Inspect", 28))
	var how := UiStyle.text_label("Drag to turn it, or use the buttons (keys A D W S, F to turn over, R to reset). Scroll to look closer. Rest the loupe on anything that catches your eye.", 14, UiStyle.MUTED)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size = Vector2(290, 0)
	v.add_child(how)
	var grid := GridContainer.new()                     ## turn it without dragging: quarter turns, turn it over, put it back as it was
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for b: Array in [["Tip up", "tip_up"], ["Turn over", "flip"], ["Tip down", "tip_down"], ["Turn left", "left"], ["Reset", "reset"], ["Turn right", "right"]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(94, 34)
		btn.add_theme_font_size_override("font_size", 14)
		var how_turn: String = b[1]
		btn.pressed.connect(func() -> void: game.turn_item(how_turn))
		grid.add_child(btn)
	v.add_child(grid)
	v.add_child(UiStyle.text_label("WHAT YOU HAVE FOUND", 12, UiStyle.AMBER_DIM))
	_clues = VBoxContainer.new()
	_clues.add_theme_constant_override("separation", 6)
	v.add_child(_clues)
	v.add_child(UiStyle.text_label("YOUR ESTIMATE", 12, UiStyle.AMBER_DIM))
	_estimate = UiStyle.text_label("", 22, UiStyle.MONEY)
	_estimate.add_theme_font_override("font", UiStyle.ui_bold())
	v.add_child(_estimate)
	var offer := Button.new()
	offer.text = "Make an offer"
	offer.pressed.connect(func() -> void: game.start_haggle())
	v.add_child(offer)
	var back := Button.new()
	back.text = "Put it down"
	back.pressed.connect(func() -> void:
		_inspect.visible = false
		game.stop_inspect())
	v.add_child(back)

func _build_haggle() -> void:
	_haggle = _panel_right(330)
	_haggle.offset_top = 80
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_haggle.add_child(v)
	v.add_child(UiStyle.title_label("Haggle", 28))
	_ask_label = UiStyle.text_label("", 20, UiStyle.CREAM)
	v.add_child(_ask_label)
	_patience = UiStyle.text_label("", 14, UiStyle.MUTED)
	v.add_child(_patience)
	v.add_child(UiStyle.text_label("YOUR OFFER", 12, UiStyle.AMBER_DIM))
	_offer_label = UiStyle.text_label("", 30, UiStyle.MONEY)
	_offer_label.add_theme_font_override("font", UiStyle.ui_bold())
	v.add_child(_offer_label)
	_slider = HSlider.new()
	_slider.step = 5
	_slider.min_value = 5
	_slider.custom_minimum_size = Vector2(290, 24)
	_slider.value_changed.connect(func(x: float) -> void: _offer_label.text = "$%d" % int(x))
	v.add_child(_slider)
	var row := HBoxContainer.new()
	for d: int in [-25, -5, 5, 25]:
		var b := Button.new()
		b.text = ("%+d" % d)
		b.custom_minimum_size = Vector2(64, 36)
		b.pressed.connect(func() -> void: _slider.value += d)
		row.add_child(b)
	v.add_child(row)
	var offer := Button.new()
	offer.text = "Offer"
	offer.pressed.connect(func() -> void: game.make_offer(int(_slider.value)))
	v.add_child(offer)
	var take := Button.new()
	take.text = "Pay their price"
	take.pressed.connect(func() -> void: game.accept_ask())
	v.add_child(take)
	var walk := Button.new()
	walk.text = "No thanks"
	walk.pressed.connect(func() -> void:
		_haggle.visible = false
		game.decline())
	v.add_child(walk)

# ---- what the game calls -------------------------------------------------------------------------------------------------------------

func say(who: String, text: String) -> void:
	_speech.visible = true
	_speech_name.text = who.to_upper()
	_speech_text.text = text
	_speech.modulate.a = 0.0
	create_tween().tween_property(_speech, "modulate:a", 1.0, 0.25)

func hide_actions() -> void:
	for c in _actions.get_children():
		c.queue_free()
	_inspect.visible = false
	_haggle.visible = false

func _action(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 19)
	b.pressed.connect(cb)
	_actions.add_child(b)

func show_seller_actions() -> void:
	hide_actions()
	_action("Take a closer look", func() -> void:
		hide_actions()
		game.start_inspect())
	_action("Make an offer", func() -> void:
		hide_actions()
		game.start_haggle())
	_action("Not interested", func() -> void: game.decline())

func show_buyer_actions(price: int) -> void:
	hide_actions()
	_action("Sell for $%d" % price, func() -> void: game.sell_accept())
	_action("Ask for more", func() -> void: game.sell_push())
	_action("Not for sale", func() -> void: game._leave("Suit yourself."))

func show_inspect(item: Dictionary) -> void:
	_haggle.visible = false
	_inspect.visible = true
	refresh_inspect(item)

func refresh_inspect(item: Dictionary) -> void:
	for c in _clues.get_children():
		c.queue_free()
	if item["found"].is_empty():
		_clues.add_child(UiStyle.text_label("Nothing yet.", 15, UiStyle.MUTED))
	for cl: Dictionary in item["clues"]:
		if cl["id"] in item["found"]:
			var col := UiStyle.DANGER if cl.get("fake", false) or cl.get("damage", false) else UiStyle.MONEY
			var l := UiStyle.text_label("• " + String(cl["text"]), 15, col)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(290, 0)
			_clues.add_child(l)
	var est := Items.estimate(item)
	_estimate.text = "$%d to $%d" % [int(est.x), int(est.y)]

func show_haggle(item: Dictionary, ask: int, patience: int) -> void:
	_inspect.visible = false
	_haggle.visible = true
	var est := Items.estimate(item)
	_ask_label.text = "They ask $%d\nYou think: $%d to $%d" % [ask, int(est.x), int(est.y)]
	_patience.text = "Patience: " + "●".repeat(maxi(patience, 0)) + "○".repeat(maxi(0, 5 - patience))
	_slider.max_value = maxf(ask * 1.2, 50)
	_slider.value = roundi(minf(ask * 0.6, est.y) / 5.0) * 5
	_offer_label.text = "$%d" % int(_slider.value)

func found_clue(c: Dictionary) -> void:
	toast(("Found: " + String(c["text"])))

func toast(text: String) -> void:
	_toast_text = text
	_toast_t = 3.5

func cash(delta: int) -> void:
	_cash_fx.append([delta, 1.6])

func bell() -> void:
	pass                                                  ## the door bell (sound comes later)

func show_day_title(t: String, sub: String) -> void:
	_title.text = t
	_sub.text = sub
	var tw := create_tween()
	tw.tween_property(_title, "modulate:a", 1.0, 0.5)
	tw.parallel().tween_property(_sub, "modulate:a", 1.0, 0.5)
	tw.tween_interval(1.4)
	tw.tween_property(_title, "modulate:a", 0.0, 0.6)
	tw.parallel().tween_property(_sub, "modulate:a", 0.0, 0.6)

func show_summary(t: String, text: String, button: String, cb: Callable) -> void:
	hide_actions()
	_speech.visible = false
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var parts := PanelContainer.new()
	parts.add_theme_stylebox_override("panel", UiStyle.panel_box(UiStyle.PANEL_SOLID, 12, UiStyle.EDGE, 28.0))
	parts.custom_minimum_size = Vector2(520, 0)
	center.add_child(parts)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	parts.add_child(v)
	v.add_child(UiStyle.title_label(t, 34))
	var l := UiStyle.text_label(text, 17, UiStyle.CREAM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(460, 0)
	v.add_child(l)
	var b := Button.new()
	b.text = button
	b.custom_minimum_size = Vector2(0, 46)
	b.pressed.connect(func() -> void:
		center.queue_free()
		cb.call())
	v.add_child(b)
	_summary = center

# ---- drawing: top bar, loupe, toasts --------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_toast_t = maxf(0.0, _toast_t - delta)
	for fx: Array in _cash_fx:
		fx[1] -= delta
	_cash_fx = _cash_fx.filter(func(f: Array) -> bool: return f[1] > 0.0)
	_shown_money = lerpf(_shown_money, float(game.money), clampf(delta * 6.0, 0.0, 1.0))
	queue_redraw()

func _draw() -> void:
	var size := get_viewport_rect().size
	var font := UiStyle.ui_font()
	var bold := UiStyle.ui_bold()
	# top bar
	var bar := Rect2(Vector2(20, 16), Vector2(size.x - 40, 48))
	UiStyle.draw_panel(self, bar)
	draw_string(UiStyle.title_font(), bar.position + Vector2(18, 33), "Second Hand", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiStyle.AMBER)
	draw_string(bold, bar.position + Vector2(200, 31), "DAY %d" % game.day, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UiStyle.CREAM)
	var rent_left: int = game.RENT_DAY - game.day
	draw_string(font, bar.position + Vector2(290, 31), ("Rent $%d due in %d days" % [game.RENT, rent_left]) if rent_left > 0 else ("Rent $%d due tonight" % game.RENT), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiStyle.DANGER if rent_left <= 1 else UiStyle.MUTED)
	draw_string(font, bar.position + Vector2(bar.size.x - 380, 31), "On the shelves: %d" % game.stock.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiStyle.MUTED)
	UiStyle.icon(self, "coin", bar.position + Vector2(bar.size.x - 150, 25), 20, Color(0.95, 0.8, 0.35))
	draw_string(bold, bar.position + Vector2(bar.size.x - 132, 32), "$%d" % int(round(_shown_money)), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiStyle.MONEY)
	for fx: Array in _cash_fx:
		var a := clampf(fx[1], 0.0, 1.0)
		var d: int = fx[0]
		draw_string(bold, bar.position + Vector2(bar.size.x - 132, 60 + (1.6 - fx[1]) * 20), ("%+d" % d).replace("+", "+$").replace("-", "-$"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(UiStyle.MONEY if d > 0 else UiStyle.DANGER, a))
	# the loupe
	if game.state == "inspect":
		var r := 34.0
		draw_arc(loupe_at, r, 0, TAU, 48, Color(UiStyle.CREAM, 0.85 if loupe_on else 0.35), 2.5, true)
		draw_arc(loupe_at, r + 4, 0, TAU, 48, Color(0, 0, 0, 0.35), 2.0, true)
		draw_line(loupe_at + Vector2(r * 0.7, r * 0.7), loupe_at + Vector2(r * 1.4, r * 1.4), Color(UiStyle.AMBER, 0.9), 5.0, true)
		if loupe_progress > 0.0:
			draw_arc(loupe_at, r - 5, -PI * 0.5, -PI * 0.5 + TAU * clampf(loupe_progress, 0.0, 1.0), 48, UiStyle.AMBER, 4.0, true)
		if loupe_hint != "":
			draw_string(font, loupe_at + Vector2(-40, r + 22), loupe_hint, HORIZONTAL_ALIGNMENT_CENTER, 80, 14, UiStyle.AMBER)
	if _toast_t > 0.0:
		var fade := minf(1.0, _toast_t * 2.0)
		var tw := 560.0
		var ts := font.get_multiline_string_size(_toast_text, HORIZONTAL_ALIGNMENT_CENTER, tw, 16)
		var rr := Rect2(Vector2(size.x * 0.5 - tw * 0.5 - 14, 80), Vector2(tw + 28, ts.y + 18))
		UiStyle.draw_panel(self, rr, Color(0.06, 0.07, 0.09, 0.8 * fade), 10.0, Color(UiStyle.AMBER, 0.4 * fade))
		draw_multiline_string(font, Vector2(rr.position.x + 14, rr.position.y + 9 + font.get_ascent(16)), _toast_text, HORIZONTAL_ALIGNMENT_CENTER, tw, 16, -1, Color(UiStyle.CREAM, fade))
