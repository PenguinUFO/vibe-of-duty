class_name UiTheme
extends RefCounted
## The game's look, made entirely in code (no image assets): the palette, the font weights and the styles of every
## control. Settings merges it into the default theme at startup, so menus, the HUD and dialogs all pick it up, CanvasLayers
## included. Scripts use the palette constants and the type variations below instead of their own colours and sizes:
##   Label: "Title" (game name), "Subtitle", "PanelTitle" (a panel's header), "Heading" (a section), "Hint" (dim notes),
##          "HudLabel" (outlined text over the 3D view)
##   Button: "BigButton" (main and pause menu)
##   PanelContainer: "HudPlate" (a dark plate under HUD text), "FeedEntry" / "FeedEntryMine" (kill feed lines)
## The few icons controls need (toggle switch, slider grabber) are painted into small images here.

const GAME_FONT := "res://assets/fonts/science-gothic/Science-Gothic-Variable-Fixed.ttf"

# Black and warm greys; the signal red marks focus, danger and the player's own lines, olive marks "good"
# (Palette, Docs/AUTHOR.md).
const BG := Palette.GREY_0
const PANEL := Color(Palette.GREY_1, 0.95)
const SURFACE := Color(Palette.GREY_2, 0.92)
const SURFACE_HOVER := Color(Palette.GREY_3, 0.96)
const SURFACE_PRESSED := Color(0.3, 0.09, 0.03, 0.96)
const FIELD := Color(0.03, 0.028, 0.026, 0.9)
const TEXT := Palette.PALE
const TEXT_DIM := Palette.GREY_6
const ACCENT := Palette.SIGNAL
const ACCENT_DIM := Color(0.5, 0.13, 0.04)
const DANGER := Palette.SIGNAL
const GOOD := Color(0.6, 0.67, 0.36)  # Palette.OLIVE, lightened to read as text
const HIGHLIGHT := Color(1.0, 0.36, 0.2)  # the player's own lines (kill feed, scoreboard): Palette.SIGNAL, lightened for text
const HUD_PLATE := Color(0.02, 0.018, 0.016, 0.62)

const CHAMFER := 8  # cut-off corners (top-left and bottom-right) of buttons and panels
const FONT_SIZE := 16

static var _bold: FontVariation
static var _heavy: FontVariation


## The game font at a heavier weight (HUD numbers, buttons, headings).
static func bold_font() -> Font:
	if _bold == null:
		_bold = _variation(700, 100)
	return _bold


## The game font, heaviest and wide (titles, big HUD numbers).
static func heavy_font() -> Font:
	if _heavy == null:
		_heavy = _variation(850, 135)
	return _heavy


static func build() -> Theme:
	var t := Theme.new()
	var base := load(GAME_FONT) as Font
	if base:
		t.default_font = base
	t.default_font_size = FONT_SIZE

	_label(t)
	_buttons(t)
	_fields(t)
	_containers(t)
	_popups(t)
	return t


## A fade-and-grow entrance for a panel or dialog (not for a container's child: containers reset its scale).
static func pop_in(control: Control, delay := 0.0) -> void:
	control.modulate.a = 0.0
	await control.get_tree().process_frame  # its size is known once laid out
	if not is_instance_valid(control):
		return
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2(0.96, 0.96)
	var tween := control.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, 0.16).set_delay(delay)
	tween.tween_property(control, "scale", Vector2.ONE, 0.22).set_delay(delay)


## Fades a container's children in one after another.
static func stagger_in(container: Control, step := 0.035, delay := 0.0) -> void:
	var i := 0
	for child in container.get_children():
		if not (child is CanvasItem and (child as CanvasItem).visible):
			continue
		var item := child as CanvasItem
		item.modulate.a = 0.0
		item.create_tween().tween_property(item, "modulate:a", 1.0, 0.2).set_delay(delay + step * i)
		i += 1


## A flat box with the two cut corners.
static func box(bg: Color, chamfer := CHAMFER, margin_h := 14.0, margin_v := 8.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_detail = 1  # a one-segment "rounding" is a straight cut
	s.corner_radius_top_left = chamfer
	s.corner_radius_bottom_right = chamfer
	s.content_margin_left = margin_h
	s.content_margin_right = margin_h
	s.content_margin_top = margin_v
	s.content_margin_bottom = margin_v
	return s


static func _variation(weight: int, width: int) -> FontVariation:
	var ts := TextServerManager.get_primary_interface()
	var f := FontVariation.new()
	f.base_font = load(GAME_FONT) as Font
	f.variation_opentype = {ts.name_to_tag("weight"): weight, ts.name_to_tag("width"): width}
	return f


static func _label(t: Theme) -> void:
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))

	t.set_type_variation("Title", "Label")
	t.set_font("font", "Title", heavy_font())
	t.set_font_size("font_size", "Title", 64)
	t.set_color("font_color", "Title", ACCENT)
	t.set_color("font_shadow_color", "Title", Color(0, 0, 0, 0.55))
	t.set_constant("shadow_offset_x", "Title", 3)
	t.set_constant("shadow_offset_y", "Title", 4)

	t.set_type_variation("Subtitle", "Label")
	t.set_font("font", "Subtitle", bold_font())
	t.set_font_size("font_size", "Subtitle", 22)
	t.set_color("font_color", "Subtitle", TEXT_DIM)

	t.set_type_variation("PanelTitle", "Label")
	t.set_font("font", "PanelTitle", heavy_font())
	t.set_font_size("font_size", "PanelTitle", 26)
	t.set_color("font_color", "PanelTitle", TEXT)

	t.set_type_variation("Heading", "Label")
	t.set_font("font", "Heading", bold_font())
	t.set_font_size("font_size", "Heading", 19)
	t.set_color("font_color", "Heading", ACCENT)

	t.set_type_variation("Hint", "Label")
	t.set_font_size("font_size", "Hint", 15)
	t.set_color("font_color", "Hint", TEXT_DIM)

	t.set_type_variation("HudLabel", "Label")
	t.set_font("font", "HudLabel", bold_font())
	t.set_color("font_outline_color", "HudLabel", Color(0, 0, 0, 0.85))
	t.set_constant("outline_size", "HudLabel", 6)

	t.set_color("font_color", "TooltipLabel", TEXT)


static func _buttons(t: Theme) -> void:
	# Normal: a dim accent stripe on the left; hover: a brighter, wider stripe and the text nudged right.
	var normal := box(SURFACE)
	normal.border_width_left = 3
	normal.border_color = ACCENT_DIM
	var hover := box(SURFACE_HOVER)
	hover.border_width_left = 6
	hover.border_color = ACCENT
	var pressed := box(SURFACE_PRESSED)
	pressed.border_width_left = 6
	pressed.border_color = ACCENT
	var disabled := box(Color(SURFACE, 0.45))
	disabled.border_width_left = 3
	disabled.border_color = Color(TEXT_DIM, 0.3)
	var focus := box(Color(0, 0, 0, 0))
	focus.draw_center = false
	focus.set_border_width_all(2)
	focus.border_color = ACCENT
	for type in ["Button", "OptionButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, hover)
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, focus)
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_focus_color", type, TEXT)
		t.set_color("font_pressed_color", type, ACCENT)
		t.set_color("font_hover_pressed_color", type, ACCENT)
		t.set_color("font_disabled_color", type, Color(TEXT_DIM, 0.5))
	for state in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(state + "_mirrored", "OptionButton", t.get_stylebox(state, "OptionButton"))
	t.set_font("font", "Button", bold_font())
	t.set_font("font", "OptionButton", load(GAME_FONT) as Font)
	t.set_constant("arrow_margin", "OptionButton", 10)

	# Main / pause menu buttons: bigger, with more room for the hover nudge.
	t.set_type_variation("BigButton", "Button")
	t.set_font_size("font_size", "BigButton", 22)
	var big := {"normal": normal, "hover": hover, "pressed": pressed, "hover_pressed": hover, "disabled": disabled}
	for state in big:
		var s := (big[state] as StyleBoxFlat).duplicate() as StyleBoxFlat
		s.content_margin_left = 30.0 if state.begins_with("hover") or state == "pressed" else 20.0
		s.content_margin_top = 11.0
		s.content_margin_bottom = 11.0
		t.set_stylebox(state, "BigButton", s)

	# Toggles: no box, only a hover tint; the switch is painted.
	var flat := box(Color(0, 0, 0, 0), CHAMFER, 6.0, 6.0)
	var flat_hover := box(Color(1, 1, 1, 0.05), CHAMFER, 6.0, 6.0)
	for type in ["CheckButton", "CheckBox"]:
		for state in ["normal", "pressed", "disabled"]:
			t.set_stylebox(state, type, flat)
		for state in ["hover", "hover_pressed"]:
			t.set_stylebox(state, type, flat_hover)
		t.set_stylebox("focus", type, focus)
		t.set_font("font", type, load(GAME_FONT) as Font)
		for c in ["font_color", "font_focus_color", "font_pressed_color"]:
			t.set_color(c, type, TEXT)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_hover_pressed_color", type, Color.WHITE)
		t.set_color("font_disabled_color", type, Color(TEXT_DIM, 0.5))
	t.set_constant("h_separation", "CheckBox", 10)
	t.set_icon("checked", "CheckBox", _check_icon(true, false))
	t.set_icon("unchecked", "CheckBox", _check_icon(false, false))
	t.set_icon("checked_disabled", "CheckBox", _check_icon(true, true))
	t.set_icon("unchecked_disabled", "CheckBox", _check_icon(false, true))
	var on := _toggle_icon(true, false)
	var off := _toggle_icon(false, false)
	var on_dis := _toggle_icon(true, true)
	var off_dis := _toggle_icon(false, true)
	for suffix in ["", "_mirrored"]:
		t.set_icon("checked" + suffix, "CheckButton", on)
		t.set_icon("unchecked" + suffix, "CheckButton", off)
		t.set_icon("checked_disabled" + suffix, "CheckButton", on_dis)
		t.set_icon("unchecked_disabled" + suffix, "CheckButton", off_dis)


static func _fields(t: Theme) -> void:
	var field := box(FIELD, 0, 10.0, 7.0)
	field.border_width_bottom = 2
	field.border_color = Color(TEXT_DIM, 0.45)
	var field_focus := box(Color(0, 0, 0, 0), 0)
	field_focus.draw_center = false
	field_focus.border_width_bottom = 2
	field_focus.border_color = ACCENT
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field_focus)
	t.set_stylebox("read_only", "LineEdit", field)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Color(TEXT_DIM, 0.6))
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_color("selection_color", "LineEdit", Color(ACCENT, 0.35))
	t.set_color("font_selected_color", "LineEdit", Color.WHITE)
	t.set_constant("caret_width", "LineEdit", 2)

	# Sliders: a thin track, filled with the accent up to the grabber.
	var track := StyleBoxFlat.new()
	track.bg_color = SURFACE_HOVER
	track.content_margin_top = 3.0
	track.content_margin_bottom = 3.0
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = ACCENT_DIM
	var fill_hot := track.duplicate() as StyleBoxFlat
	fill_hot.bg_color = ACCENT
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill_hot)
	t.set_icon("grabber", "HSlider", _grabber_icon(ACCENT))
	t.set_icon("grabber_highlight", "HSlider", _grabber_icon(Color.WHITE))
	t.set_icon("grabber_disabled", "HSlider", _grabber_icon(TEXT_DIM))


static func _containers(t: Theme) -> void:
	var panel := box(PANEL, 14, 26.0, 22.0)
	panel.border_width_top = 3
	panel.border_color = ACCENT
	panel.shadow_color = Color(0, 0, 0, 0.45)
	panel.shadow_size = 18
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 10)

	t.set_type_variation("HudPlate", "PanelContainer")
	t.set_stylebox("panel", "HudPlate", box(HUD_PLATE, CHAMFER, 16.0, 6.0))
	t.set_type_variation("FeedEntry", "PanelContainer")
	t.set_stylebox("panel", "FeedEntry", box(HUD_PLATE, 5, 10.0, 3.0))
	t.set_type_variation("FeedEntryMine", "PanelContainer")
	var mine := box(Color(0.2, 0.05, 0.02, 0.72), 5, 10.0, 3.0)
	mine.border_width_left = 3
	mine.border_color = ACCENT
	t.set_stylebox("panel", "FeedEntryMine", mine)

	# "Дополнительно" and similar folded sections.
	var title := box(SURFACE, CHAMFER, 12.0, 6.0)
	var title_hover := box(SURFACE_HOVER, CHAMFER, 12.0, 6.0)
	t.set_stylebox("title_panel", "FoldableContainer", title)
	t.set_stylebox("title_collapsed_panel", "FoldableContainer", title)
	t.set_stylebox("title_hover_panel", "FoldableContainer", title_hover)
	t.set_stylebox("title_collapsed_hover_panel", "FoldableContainer", title_hover)
	var body := StyleBoxEmpty.new()
	body.content_margin_top = 10.0
	t.set_stylebox("panel", "FoldableContainer", body)
	t.set_color("font_color", "FoldableContainer", TEXT)
	t.set_color("collapsed_font_color", "FoldableContainer", TEXT_DIM)
	t.set_color("hover_font_color", "FoldableContainer", ACCENT)

	var scroll := StyleBoxFlat.new()
	scroll.bg_color = Color(SURFACE, 0.5)
	scroll.content_margin_left = 3.0
	scroll.content_margin_right = 3.0
	var grab := scroll.duplicate() as StyleBoxFlat
	grab.bg_color = TEXT_DIM
	var grab_hot := scroll.duplicate() as StyleBoxFlat
	grab_hot.bg_color = ACCENT
	t.set_stylebox("scroll", "VScrollBar", scroll)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab_hot)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab_hot)


static func _popups(t: Theme) -> void:
	var popup := box(Color(PANEL, 0.98), CHAMFER, 6.0, 6.0)
	popup.set_border_width_all(1)
	popup.border_color = Color(ACCENT, 0.5)
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_stylebox("hover", "PopupMenu", box(Color(ACCENT, 0.22), 4, 8.0, 4.0))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_constant("v_separation", "PopupMenu", 8)
	t.set_font("font", "PopupMenu", load(GAME_FONT) as Font)
	var tip := box(Color(PANEL, 0.97), 4, 10.0, 6.0)
	tip.set_border_width_all(1)
	tip.border_color = Color(ACCENT, 0.5)
	t.set_stylebox("panel", "TooltipPanel", tip)


## Paints an icon pixel by pixel: `paint` takes the pixel centre and returns its colour.
static func _paint(w: int, h: int, paint: Callable) -> ImageTexture:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			img.set_pixel(x, y, paint.call(Vector2(x + 0.5, y + 0.5)))
	return ImageTexture.create_from_image(img)


## Anti-aliased coverage of a shape from its signed distance (negative inside).
static func _cover(d: float) -> float:
	return clampf(0.5 - d, 0.0, 1.0)


## `top` drawn over `under` with `amount` (0..1) coverage.
static func _over(under: Color, top: Color, amount: float) -> Color:
	var a := top.a * amount
	var out_a := a + under.a * (1.0 - a)
	if out_a <= 0.0:
		return Color(0, 0, 0, 0)
	var rgb := (Vector3(top.r, top.g, top.b) * a + Vector3(under.r, under.g, under.b) * under.a * (1.0 - a)) / out_a
	return Color(rgb.x, rgb.y, rgb.z, out_a)


## The CheckButton switch: a pill track with a round knob, left when off, right (on the accent) when on.
static func _toggle_icon(on: bool, disabled: bool) -> ImageTexture:
	var w := 46
	var h := 24
	var y := h * 0.5
	var track_color := ACCENT if on else Color(TEXT_DIM, 0.35)
	var knob_color := Color.WHITE if on else TEXT
	if disabled:
		track_color.a *= 0.4
		knob_color.a *= 0.4
	var knob_x := w - 12.0 if on else 12.0
	return _paint(w, h, func(p: Vector2) -> Color:
		var on_line := Vector2(clampf(p.x, 12.0, w - 12.0), y)
		var c := _over(Color(0, 0, 0, 0), track_color, _cover(p.distance_to(on_line) - 10.0))
		return _over(c, knob_color, _cover(p.distance_to(Vector2(knob_x, y)) - 7.0)))


## The CheckBox box: an outlined square, filled with the accent and a check mark when checked.
static func _check_icon(checked: bool, disabled: bool) -> ImageTexture:
	var s := 20
	var centre := Vector2(s, s) * 0.5
	var fade := 0.4 if disabled else 1.0
	return _paint(s, s, func(p: Vector2) -> Color:
		var q := (p - centre).abs() - Vector2(8.0, 8.0)
		var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)  # square, edge at 8 px
		var c := Color(0, 0, 0, 0)
		if checked:
			c = _over(c, Color(ACCENT, fade), _cover(d))
			var tick := minf(_segment_distance(p, Vector2(5.5, 10.0), Vector2(8.5, 13.5)),
					_segment_distance(p, Vector2(8.5, 13.5), Vector2(14.5, 6.5)))
			return _over(c, Color(BG, fade), _cover(tick - 1.3))
		c = _over(c, Color(FIELD, fade), _cover(d))
		# A 2 px outline just inside the edge.
		return _over(c, Color(TEXT_DIM, fade), _cover(absf(d + 1.0) - 1.0)))


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


## The slider grabber: a filled circle with a dark centre.
static func _grabber_icon(color: Color) -> ImageTexture:
	var s := 20
	var centre := Vector2(s, s) * 0.5
	return _paint(s, s, func(p: Vector2) -> Color:
		var d := p.distance_to(centre)
		var c := _over(Color(0, 0, 0, 0), Color(0, 0, 0, 0.5), _cover(d - 9.0))
		c = _over(c, color, _cover(d - 8.0))
		return _over(c, BG, _cover(d - 3.0)))
