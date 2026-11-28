extends Control
class_name ShopUi
## Everything on screen in the shop, in a period look kept out of the way of the antique and the customer:
## - two small plaques at the top (the day and the rent; the stock and the cash);
## - the speech box in dark wood and brass, with a live portrait of whoever is talking (their face, or the porch camera at the door);
## - the appraisal notes, a parchment notebook page: the piece's name, each finding (a tick, a warning or a cross, a title, the detail),
##   the estimate, the asking price, and the two choices;
## - the negotiation card: the asking price and your estimate, your offer with arrows, and the choices;
## - the buttons for what you can do, a strip of controls while you inspect, the loupe, the day title, toasts and the summary.

var game: Node
const SPEECH_TOP := -176.0                 ## where the speech box rests (offsets from the bottom of the screen)
const SPEECH_BOTTOM := -26.0
const SPEECH_W := 720.0
var loupe_at := Vector2.ZERO
var loupe_on := false
var loupe_progress := 0.0
var loupe_hint := ""
var _speech: PanelContainer
var _speech_name: Label
var _speech_text: RichTextLabel
var _hop := HopText.new()                  ## letters typed in one by one, each with a little hop
var _speech_tween: Tween
var _speech_alpha := 1.0                   ## fades the speech box out a little after a customer has gone
var _fade_tween: Tween
var _veil: ColorRect
var cinema := false                        ## the camera is outside for the day's opening or closing shot: no HUD
var _portrait: TextureRect                 ## the speaker's face (or the porch camera)
var _portrait_frame: PanelContainer
var _portrait_view: SubViewport
var _portrait_cam: Camera3D
var _actions: VBoxContainer
var _inspect: PanelContainer
var _notes_title: Label
var _clues: VBoxContainer
var _estimate: Label
var _asking: Label
var _haggle: PanelContainer
var _neg_item: Label
var _neg_line: Label
var _offer_label: Label
var _offer := 0
var _offer_max := 50
var _pips: Array = []                      ## patience as five drawn pips
var _hint: PanelContainer                  ## the controls strip while inspecting
var _summary: Control = null
var _feed_tex: Texture2D = null            ## the porch camera's picture: the portrait while someone is at the door
var _tip: PanelContainer                   ## the guided first customer's tips, top left
var _tip_text: Label
var _title: Label
var _sub: Label
var _toast_t := 0.0
var _toast_text := ""
var _cash_fx: Array = []
var _shown_money := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST     ## the HUD sheet is pixel art: keep its edges crisp
	theme = UiStyle.menu_theme()
	_veil = ColorRect.new()                                 ## black, over the plaques but under every panel: the day's fades
	_veil.color = Color(0, 0, 0, 0)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	_build_speech()
	_actions = VBoxContainer.new()
	_actions.anchor_left = 1.0
	_actions.anchor_right = 1.0
	_actions.anchor_top = 1.0
	_actions.anchor_bottom = 1.0
	_actions.offset_left = -290
	_actions.offset_right = -24
	_actions.offset_top = -176
	_actions.offset_bottom = -26
	_actions.grow_vertical = Control.GROW_DIRECTION_BEGIN     ## more buttons (a buyer's choices) stack upward
	_actions.grow_horizontal = Control.GROW_DIRECTION_BEGIN   ## and a long label widens the column leftward, never off the screen
	_actions.alignment = BoxContainer.ALIGNMENT_END
	_actions.add_theme_constant_override("separation", 8)
	add_child(_actions)
	_build_inspect()
	_build_haggle()
	_build_hint()
	_build_tip()
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

# ---- building ----------------------------------------------------------------------------------------------------------------------------

func _build_speech() -> void:
	_speech = PanelContainer.new()
	_speech.add_theme_stylebox_override("panel", UiStyle.wood_box(12.0))
	_speech.anchor_left = 0.5
	_speech.anchor_right = 0.5
	_speech.anchor_top = 1.0
	_speech.anchor_bottom = 1.0
	_speech.offset_left = -SPEECH_W * 0.5
	_speech.offset_right = SPEECH_W * 0.5
	_speech.offset_top = SPEECH_TOP
	_speech.offset_bottom = SPEECH_BOTTOM
	_speech.visible = false
	add_child(_speech)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	_speech.add_child(h)
	# the portrait: a little window onto the speaker's face, in a brass frame
	_portrait_frame = PanelContainer.new()
	var pf := UiStyle.wood_box(7.0, "dark_square")
	_portrait_frame.add_theme_stylebox_override("panel", pf)
	_portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_portrait_frame)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(104, 104)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait_frame.add_child(_portrait)
	_portrait_view = SubViewport.new()
	_portrait_view.size = Vector2i(128, 128)
	_portrait_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_portrait_view)
	_portrait_cam = Camera3D.new()
	_portrait_cam.fov = 28.0
	_portrait_cam.near = 0.05
	_portrait_view.add_child(_portrait_cam)
	_portrait_cam.current = true
	# the name on its plaque, and the line
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_speech_name = UiStyle.text_label("", 18, UiStyle.AMBER)
	v.add_child(_speech_name)
	_speech_text = RichTextLabel.new()
	_speech_text.bbcode_enabled = true
	_speech_text.fit_content = true
	_speech_text.scroll_active = false
	_speech_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech_text.custom_minimum_size = Vector2(260.0, 0)        ## grows with the box; the box narrows on small screens
	_speech_text.custom_effects = [_hop]
	_speech_text.add_theme_font_override("normal_font", UiStyle.ui_font())
	_speech_text.add_theme_font_size_override("normal_font_size", UiStyle.px(18))
	_speech_text.add_theme_color_override("default_color", UiStyle.CREAM)
	_speech_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_speech_text)

func _card(width: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiStyle.parchment_box(20.0, "parch_tall"))
	p.anchor_left = 1.0
	p.anchor_right = 1.0
	p.offset_left = -width - 24
	p.offset_right = -24
	p.offset_top = 74
	p.visible = false
	add_child(p)
	return p

func _ink(text: String, size: int, col: Color = UiStyle.INK) -> Label:
	var l := UiStyle.text_label(text, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(UiStyle.INK_SOFT, 0.45)
	r.custom_minimum_size = Vector2(0, 2)
	return r

func _build_inspect() -> void:
	_inspect = _card(400)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_inspect.add_child(v)
	v.add_child(_ink("APPRAISAL NOTES", 13, UiStyle.INK_SOFT))
	_notes_title = _ink("", 26)
	v.add_child(_notes_title)
	v.add_child(_rule())
	_clues = VBoxContainer.new()
	_clues.add_theme_constant_override("separation", 8)
	v.add_child(_clues)
	v.add_child(_rule())
	v.add_child(_ink("Estimated value", 13, UiStyle.INK_SOFT))
	_estimate = _ink("", 26)
	v.add_child(_estimate)
	_asking = _ink("", 18, UiStyle.INK_SOFT)
	v.add_child(_asking)
	var offer := Button.new()
	offer.text = "Make an offer"
	UiStyle.style_button(offer, "go", 18)
	offer.pressed.connect(func() -> void: game.start_haggle())
	v.add_child(offer)
	var back := Button.new()
	back.text = "Put it down"
	UiStyle.style_button(back, "paper", 18)
	back.pressed.connect(func() -> void:
		_inspect.visible = false
		game.stop_inspect())
	v.add_child(back)

func _build_haggle() -> void:
	_haggle = _card(380)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_haggle.add_child(v)
	v.add_child(_ink("NEGOTIATION", 13, UiStyle.INK_SOFT))
	_neg_item = _ink("", 26)
	v.add_child(_neg_item)
	_neg_line = _ink("", 13, UiStyle.INK_SOFT)
	v.add_child(_neg_line)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 6)
	var pl := UiStyle.text_label("Patience", 13, UiStyle.INK_SOFT)     ## no wrapping: in a row it would wrap letter by letter
	prow.add_child(pl)
	for k in 5:
		var pip := TextureRect.new()
		pip.texture = UiStyle.ui_tex("pip_full")
		pip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pip.custom_minimum_size = Vector2(18, 18)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		prow.add_child(pip)
		_pips.append(pip)
	v.add_child(prow)
	v.add_child(_rule())
	var yo := _ink("Your offer", 13, UiStyle.INK_SOFT)
	yo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(yo)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	for d: int in [-25, -5]:
		row.add_child(_step_button("arrow_ll" if d == -25 else "arrow_l", d))
	_offer_label = _ink("", 26)
	_offer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_offer_label.custom_minimum_size = Vector2(110, 0)
	row.add_child(_offer_label)
	for d2: int in [5, 25]:
		row.add_child(_step_button("arrow_r" if d2 == 5 else "arrow_rr", d2))
	v.add_child(row)
	var present := Button.new()
	present.text = "Present offer"
	UiStyle.style_button(present, "go", 18)
	present.pressed.connect(func() -> void: game.make_offer(_offer))
	v.add_child(present)
	var take := Button.new()
	take.text = "Pay their price"
	UiStyle.style_button(take, "paper", 18)
	take.pressed.connect(func() -> void: game.accept_ask())
	v.add_child(take)
	var two := HBoxContainer.new()
	two.add_theme_constant_override("separation", 8)
	var again := Button.new()                                ## back to the loupe without losing the haggle: same ask, same patience
	again.text = "Look again"
	UiStyle.style_button(again, "paper", 13)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(func() -> void:
		_haggle.visible = false
		game.start_inspect())
	two.add_child(again)
	var walk := Button.new()
	walk.text = "No thanks"
	UiStyle.style_button(walk, "stop", 13)
	walk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	walk.pressed.connect(func() -> void:
		_haggle.visible = false
		game.decline())
	two.add_child(walk)
	v.add_child(two)

func _step_button(piece: String, d: int) -> Button:
	var b := Button.new()
	UiStyle.style_button(b, piece, 18)                       ## the arrow is drawn on the sheet's button
	b.custom_minimum_size = Vector2(42, 38)
	b.pressed.connect(func() -> void:
		_offer = clampi(_offer + d, 5, _offer_max)
		_offer_label.text = "$%d" % _offer)
	return b

## The controls while inspecting, in one small strip under the piece.
func _build_hint() -> void:
	_hint = PanelContainer.new()
	_hint.add_theme_stylebox_override("panel", UiStyle.wood_box(9.0, "dark_long"))
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = -520                                 ## left of the middle: the notes card takes the right side
	_hint.offset_right = -60
	_hint.offset_top = -214
	_hint.offset_bottom = -184
	_hint.visible = false
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	var l := UiStyle.text_label("Drag: turn    Scroll: zoom    F: flip    R: reset    Click lid or E: open/shut", 13, UiStyle.CREAM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_child(l)

func _build_tip() -> void:
	_tip = PanelContainer.new()
	_tip.add_theme_stylebox_override("panel", UiStyle.parchment_box(14.0))
	_tip.anchor_left = 0.5
	_tip.anchor_right = 0.5
	_tip.offset_left = -600
	_tip.offset_right = -60
	_tip.offset_top = 76
	_tip.visible = false
	add_child(_tip)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	_tip.add_child(h)
	_tip_text = _ink("", 18)
	_tip_text.custom_minimum_size = Vector2(400, 0)
	_tip_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_tip_text)
	var skip := Button.new()
	skip.text = "Skip tips"
	UiStyle.style_button(skip, "paper", 13)
	skip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skip.pressed.connect(func() -> void: game.skip_tutorial())
	h.add_child(skip)

## A tick, a warning or a cross for a finding, drawn (the pixel font has no such symbols).
class Mark extends Control:
	var kind := "good"
	func _init(k: String) -> void:
		kind = k
		custom_minimum_size = Vector2(22, 22)
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := Vector2(11, 11)
		var col: Color = {"good": Color(0.25, 0.5, 0.25), "warn": Color(0.8, 0.5, 0.1), "bad": Color(0.62, 0.18, 0.13)}[kind]
		draw_circle(c, 10.0, col)
		var w := Color(0.97, 0.93, 0.85)
		match kind:
			"good":
				draw_polyline(PackedVector2Array([c + Vector2(-5, 0), c + Vector2(-1, 4), c + Vector2(5, -4)]), w, 2.5, true)
			"warn":
				draw_line(c + Vector2(0, -5), c + Vector2(0, 2), w, 2.5, true)
				draw_circle(c + Vector2(0, 5.5), 1.5, w)
			_:
				draw_line(c + Vector2(-4, -4), c + Vector2(4, 4), w, 2.5, true)
				draw_line(c + Vector2(4, -4), c + Vector2(-4, 4), w, 2.5, true)

# ---- what the game calls -------------------------------------------------------------------------------------------------------------

## A line of speech. The box rises from below the screen with a small overshoot the first time (and gives a little bounce for each new
## line after that); the words are typed in letter by letter, each letter hopping as it lands.
func say(who: String, text: String) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_speech_alpha = 1.0
	_speech_name.text = who.to_upper()
	_speech_text.text = "[hop]" + text.replace("[", "[lb]") + "[/hop]"
	_hop.restart()
	if _speech_tween != null and _speech_tween.is_valid():
		_speech_tween.kill()
	_speech_tween = create_tween().set_parallel(true)
	if not _speech.visible:
		_speech.visible = true
		_speech.offset_top = SPEECH_TOP + 260.0
		_speech.offset_bottom = SPEECH_BOTTOM + 260.0
		_speech.modulate.a = 1.0
		_speech_tween.tween_property(_speech, "offset_top", SPEECH_TOP, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_speech_tween.tween_property(_speech, "offset_bottom", SPEECH_BOTTOM, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_speech.offset_top = SPEECH_TOP + 14.0
		_speech.offset_bottom = SPEECH_BOTTOM + 14.0
		_speech_tween.tween_property(_speech, "offset_top", SPEECH_TOP, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_speech_tween.tween_property(_speech, "offset_bottom", SPEECH_BOTTOM, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## True while a line is still being typed out.
func speaking() -> bool:
	return _speech.visible and not _hop.done(_speech_text.get_total_character_count())

func hide_actions() -> void:
	for c in _actions.get_children():
		c.queue_free()
	_inspect.visible = false
	_haggle.visible = false
	_hint.visible = false

func _action(text: String, cb: Callable, kind: String = "wood") -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	UiStyle.style_button(b, kind, 18)
	b.pressed.connect(cb)
	_actions.add_child(b)

## Someone rang: what you can tell about them (their picture is on the desk monitor, and in the portrait), and the two choices.
func show_door(title: String, look: String, note: String, tex: Texture2D) -> void:
	_feed_tex = tex
	say(title, look + "\n" + note)
	hide_actions()
	_action("Let them in", func() -> void:
		hide_actions()
		game.buzz_in(), "go")
	_action("Turn them away", func() -> void:
		hide_actions()
		game.turn_away(), "stop")

func hide_feed() -> void:
	_feed_tex = null

func show_robbery_actions() -> void:
	hide_actions()
	_action("Hand over the cash", func() -> void:
		hide_actions()
		game.rob_pay(), "wood")
	_action("Hit the alarm", func() -> void:
		hide_actions()
		game.rob_alarm(), "stop")

func show_seller_actions() -> void:
	hide_actions()
	_action("Take a closer look", func() -> void:
		hide_actions()
		game.start_inspect(), "go")
	_action("Make an offer", func() -> void:
		hide_actions()
		game.start_haggle())
	_action("Not interested", func() -> void: game.decline(), "stop")

## A buyer is here: show them one of the pieces they collect (what you paid is beside each), or nothing.
func show_present_choices(choices: Array) -> void:
	hide_actions()
	for st: Dictionary in choices.slice(0, 4):
		var it: Dictionary = st["item"]
		_action("Show the %s ($%d)" % [String(it["name"]).to_lower(), st["paid"]], func() -> void:
			hide_actions()
			game.present(st))
	_action("Nothing for you today", func() -> void:
		hide_actions()
		game._leave("Suit yourself."), "stop")

func show_buyer_actions(price: int) -> void:
	hide_actions()
	_action("Sell for $%d" % price, func() -> void: game.sell_accept(), "go")
	_action("Ask for more", func() -> void: game.sell_push())
	_action("Not for sale", func() -> void: game._leave("Suit yourself."), "stop")

func show_inspect(item: Dictionary) -> void:
	for c in _actions.get_children():
		c.queue_free()
	_haggle.visible = false
	_inspect.visible = true
	_hint.visible = true
	refresh_inspect(item)

## A finding's heading, from what kind of clue it is.
static func _finding_title(c: Dictionary) -> String:
	if c.get("fake", false):
		return "Something's not right"
	if c.get("damage", false):
		return "Damage"
	if String(c["id"]) in Items.MARK_IDS:
		return "Maker's mark"
	return "A good sign"

func refresh_inspect(item: Dictionary) -> void:
	_notes_title.text = String(item["name"])
	for c in _clues.get_children():
		c.queue_free()
	if item["found"].is_empty():
		_clues.add_child(_ink("Nothing found yet. Turn it over; look closely.", 13, UiStyle.INK_SOFT))
	for cl: Dictionary in item["clues"]:
		if not cl["id"] in item["found"]:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(Mark.new("bad" if cl.get("fake", false) else ("warn" if cl.get("damage", false) else "good")))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(_ink(_finding_title(cl), 18))
		var detail := _ink(String(cl["text"]), 13, UiStyle.INK_SOFT)
		detail.custom_minimum_size = Vector2(320, 0)
		col.add_child(detail)
		row.add_child(col)
		_clues.add_child(row)
	var est := Items.estimate(item)
	_estimate.text = "$%d - $%d" % [int(est.x), int(est.y)]
	_asking.text = "Asking price: $%d" % int(game.ask)

func show_haggle(item: Dictionary, ask: int, patience: int) -> void:
	for c in _actions.get_children():
		c.queue_free()
	_inspect.visible = false
	_hint.visible = false
	_haggle.visible = true
	var est := Items.estimate(item)
	_neg_item.text = String(item["name"])
	_neg_line.text = "Asking $%d      Your estimate $%d - $%d" % [ask, int(est.x), int(est.y)]
	for k in _pips.size():
		(_pips[k] as TextureRect).texture = UiStyle.ui_tex("pip_full" if k < patience else "pip_empty")
	_offer_max = int(maxf(ask * 1.2, 50))
	_offer = clampi(roundi(minf(ask * 0.6, est.y) / 5.0) * 5, 5, _offer_max)
	_offer_label.text = "$%d" % _offer

func found_clue(c: Dictionary) -> void:
	toast(("Found: " + String(c["text"])))

func toast(text: String) -> void:
	_toast_text = text
	_toast_t = 3.5

func cash(delta: int) -> void:
	_cash_fx.append([delta, 1.6])

func bell() -> void:
	pass                                                  ## the door bell (sound comes later)

func show_tip(text: String) -> void:
	_tip_text.text = text
	_tip.visible = true

func hide_tip() -> void:
	_tip.visible = false

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
	parts.add_theme_stylebox_override("panel", UiStyle.parchment_box(30.0, "parch_tall"))
	parts.custom_minimum_size = Vector2(560, 0)
	center.add_child(parts)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	parts.add_child(v)
	v.add_child(_ink(t, 34))
	v.add_child(_rule())
	var l := _ink(text, 18)
	l.custom_minimum_size = Vector2(500, 0)
	v.add_child(l)
	var b := Button.new()
	b.text = button
	UiStyle.style_button(b, "go", 18)
	b.pressed.connect(func() -> void:
		center.queue_free()
		cb.call())
	v.add_child(b)
	_summary = center

# ---- every frame: the portrait, the speech box's place, the plaques, the loupe, toasts ---------------------------------------------------

## Leaning in on the piece folds the appraisal notes away to a slim edge at the right of the screen (and fades the speech box back), so
## nothing covers what you are looking at; zoom out, or move the mouse onto the folded edge, and they slide back.
const NOTES_W := 400.0
const NOTES_PEEK := 34.0                   ## how much of the folded card stays on screen
var _fold := 0.0                           ## 0 open .. 1 folded away
func _fold_notes(delta: float) -> void:
	var want := 0.0
	if _inspect.visible and game.state == "inspect":
		want = clampf(inverse_lerp(0.7, 0.55, float(game.zoom)), 0.0, 1.0)
		if want > 0.0 and _inspect.get_global_rect().has_point(get_viewport().get_mouse_position()):
			want = 0.0                                          ## the mouse is on it: you want to read it
	_fold = lerpf(_fold, want, clampf(delta * 8.0, 0.0, 1.0))
	var shift := _fold * (NOTES_W + 24.0 - NOTES_PEEK)
	_inspect.offset_left = -NOTES_W - 24.0 + shift
	_inspect.offset_right = -24.0 + shift
	_inspect.modulate.a = 1.0 - 0.35 * _fold
	_speech.modulate.a = _speech_alpha * (1.0 - 0.65 * _fold)
	_hint.modulate.a = 1.0 - 0.5 * _fold

func _process(delta: float) -> void:
	# the speech box moves left, out from under the notes or negotiation card while one is open, and back when it closes
	# and never runs under the column of buttons on the right: it slides left of them, and narrows if the screen is too small
	var vw := get_viewport_rect().size.x
	var limit := vw - 24.0                                         ## the furthest right its edge may go
	if _actions.get_child_count() > 0:
		limit = minf(vw + _actions.offset_left, _actions.position.x) - 18.0     ## its real left edge, if a long label widened it
	var w := minf(SPEECH_W, limit - 24.0)
	var side := -vw * 0.5 + 24.0 if (_inspect.visible or _haggle.visible) else minf(-w * 0.5, limit - vw * 0.5 - w)
	_speech.offset_left = lerpf(_speech.offset_left, side, clampf(delta * 10.0, 0.0, 1.0))
	_speech.offset_right = _speech.offset_left + w
	_fold_notes(delta)
	_update_portrait()
	_toast_t = maxf(0.0, _toast_t - delta)
	for fx: Array in _cash_fx:
		fx[1] -= delta
	_cash_fx = _cash_fx.filter(func(f: Array) -> bool: return f[1] > 0.0)
	_shown_money = lerpf(_shown_money, float(game.money), clampf(delta * 6.0, 0.0, 1.0))
	queue_redraw()

## The portrait: at the door, the porch camera; at the counter, a little camera on the customer's face; otherwise no portrait.
func _update_portrait() -> void:
	if not _speech.visible:
		_portrait_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	if game.state == "at_door" and _feed_tex != null:
		_portrait.texture = _feed_tex
		_portrait_frame.visible = true
		_portrait_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	var fo: Variant = game.figure
	var f: Node3D = fo as Node3D if is_instance_valid(fo) else null    ## the customer may have just left (freed)
	if f != null and f.global_position.z > -3.9:
		var info: Dictionary = game.visitor.get("info", {})
		var face := f.global_position + Vector3(0, float(info.get("height", 1.7)) * 0.9 - 0.04, 0)
		var eye := face + Vector3(0.12, 0.03, 0.75)
		_portrait_cam.transform = Transform3D(Basis.looking_at(face - eye), eye)
		_portrait_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_portrait.texture = _portrait_view.get_texture()
		_portrait_frame.visible = true
	else:
		_portrait_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_portrait_frame.visible = false

const PLAQUE_H := 44.0

## The baseline that puts a line of text in the middle of a plaque, up and down (a hair high: the plaque's frame is deeper at the bottom).
static func _mid_y(font: Font, r: Rect2, size: int) -> float:
	var fs := UiStyle.px(size)
	return r.position.y + (r.size.y + font.get_ascent(fs) - font.get_descent(fs)) * 0.5 - 1.0
func _plaque(r: Rect2) -> void:
	draw_style_box(UiStyle.wood_box(0.0, "dark_long"), r)

## One of the sheet's icon plaques (calendar, coins, shelf) at the plaques' height; returns its width.
func _icon_plaque(piece: String, at: Vector2) -> float:
	var t := UiStyle.ui_tex(piece)
	var w := t.get_width() * PLAQUE_H / t.get_height()
	draw_texture_rect(t, Rect2(at, Vector2(w, PLAQUE_H)), false)
	return w

## After `delay` seconds the speech box fades away (the customer has gone and nobody is talking).
func fade_speech(delay: float = 2.5) -> void:
	if not _speech.visible:
		return
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_interval(delay)
	_fade_tween.tween_property(self, "_speech_alpha", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	_fade_tween.tween_callback(func() -> void:
		_speech.visible = false
		_speech_alpha = 1.0)

## The screen fades toward black (`a` = 1) or back (`a` = 0) over `secs`.
func veil_to(a: float, secs: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(_veil, "color:a", a, secs).set_trans(Tween.TRANS_SINE)
	return tw

## The opening or closing shot: everything on screen is put away (or the plaques come back).
func set_cinema(on: bool) -> void:
	cinema = on
	if on:
		hide_actions()
		_speech.visible = false
		_tip.visible = false

func _draw() -> void:
	if cinema:
		return
	var size := get_viewport_rect().size
	var font := UiStyle.ui_font()
	# two small plaques: the day and the rent on the left, the stock and the cash on the right
	var rent_left: int = game.RENT_DAY - game.day
	var rent := ("Rent due in %d days" % rent_left) if rent_left > 1 else ("Rent due tomorrow" if rent_left == 1 else "Rent due tonight")
	var day := "DAY %d" % game.day
	var dw := font.get_string_size(day, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.px(18)).x
	var rw := font.get_string_size(rent, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.px(13)).x
	var lw := dw + rw + 18 + 44
	var iw := _icon_plaque("icon_calendar", Vector2(24, 16))
	var left := Rect2(Vector2(24 + iw + 6, 16), Vector2(lw, PLAQUE_H))
	_plaque(left)
	var x0 := left.position.x + (left.size.x - (dw + 18 + rw)) * 0.5
	draw_string(font, Vector2(x0, _mid_y(font, left, 18)), day, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.px(18), UiStyle.AMBER)
	draw_string(font, Vector2(x0 + dw + 18, _mid_y(font, left, 13)), rent, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.px(13), UiStyle.DANGER if rent_left <= 1 else UiStyle.CREAM)
	var shelves := "On the shelves: %d" % game.stock.size()
	var money := "$%d" % int(round(_shown_money))
	var sw := font.get_string_size(shelves, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.px(13)).x
	var mw := font.get_string_size("$00000", HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.px(18)).x
	# right to left: the cash plaque and its coins, then the shelves plaque and its shelf
	var cash_r := Rect2(Vector2(size.x - 24 - (mw + 32), 16), Vector2(mw + 32, PLAQUE_H))
	_plaque(cash_r)
	draw_string(font, Vector2(cash_r.position.x, _mid_y(font, cash_r, 18)), money, HORIZONTAL_ALIGNMENT_CENTER, cash_r.size.x, UiStyle.px(18), UiStyle.MONEY)
	var cw := UiStyle.ui_tex("icon_coins").get_width() * PLAQUE_H / UiStyle.ui_tex("icon_coins").get_height()
	_icon_plaque("icon_coins", Vector2(cash_r.position.x - 6 - cw, 16))
	var shelf_r := Rect2(Vector2(cash_r.position.x - 12 - cw - (sw + 32), 16), Vector2(sw + 32, PLAQUE_H))
	_plaque(shelf_r)
	draw_string(font, Vector2(shelf_r.position.x, _mid_y(font, shelf_r, 13)), shelves, HORIZONTAL_ALIGNMENT_CENTER, shelf_r.size.x, UiStyle.px(13), UiStyle.CREAM)
	var shw := UiStyle.ui_tex("icon_shelf").get_width() * PLAQUE_H / UiStyle.ui_tex("icon_shelf").get_height()
	_icon_plaque("icon_shelf", Vector2(shelf_r.position.x - 6 - shw, 16))
	var right := cash_r
	for fx: Array in _cash_fx:
		var a := clampf(fx[1], 0.0, 1.0)
		var d: int = fx[0]
		draw_string(font, right.position + Vector2(18, 76 + (1.6 - fx[1]) * 20), ("%+d" % d).replace("+", "+$").replace("-", "-$"), HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.px(18), Color(UiStyle.MONEY if d > 0 else UiStyle.DANGER, a))
	# the loupe
	if game.state == "inspect":
		var r := 34.0
		draw_arc(loupe_at, r, 0, TAU, 48, Color(UiStyle.CREAM, 0.85 if loupe_on else 0.35), 2.5, true)
		draw_arc(loupe_at, r + 4, 0, TAU, 48, Color(0, 0, 0, 0.35), 2.0, true)
		draw_line(loupe_at + Vector2(r * 0.7, r * 0.7), loupe_at + Vector2(r * 1.4, r * 1.4), Color(UiStyle.BRASS, 0.95), 5.0, true)
		if loupe_progress > 0.0:
			draw_arc(loupe_at, r - 5, -PI * 0.5, -PI * 0.5 + TAU * clampf(loupe_progress, 0.0, 1.0), 48, UiStyle.AMBER, 4.0, true)
		if loupe_hint != "":
			draw_string(font, loupe_at + Vector2(-40, r + 22), loupe_hint, HORIZONTAL_ALIGNMENT_CENTER, 80, UiStyle.px(13), UiStyle.AMBER)
	# a toast: a slip of paper at the top
	if _toast_t > 0.0:
		var fade := minf(1.0, _toast_t * 2.0)
		var tw := 520.0
		var fs := UiStyle.px(13)
		var ts := font.get_multiline_string_size(_toast_text, HORIZONTAL_ALIGNMENT_CENTER, tw, fs)
		var rr := Rect2(Vector2(size.x * 0.5 - tw * 0.5 - 14, 72), Vector2(tw + 28, ts.y + 18))
		var sb := UiStyle.parchment_box(0.0, "parch_strip")
		sb.modulate_color = Color(1, 1, 1, fade)
		draw_style_box(sb, rr)
		draw_multiline_string(font, Vector2(rr.position.x + 14, rr.position.y + 9 + font.get_ascent(fs)), _toast_text, HORIZONTAL_ALIGNMENT_CENTER, tw, fs, -1, Color(UiStyle.INK, fade))
