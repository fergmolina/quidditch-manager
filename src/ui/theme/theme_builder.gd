class_name ThemeBuilder
extends RefCounted
## "Manager's office" theme.
## Two surfaces under the frame (desk and card), type scale via theme variations,
## tables with a dark header and zebra rows, heat map for attributes. StyleBoxFlat only.

const WOOD := Color("#2B1D14")
const WOOD_MID := Color("#3D2A1E")
const WOOD_SEL := Color("#4A3424")
const DESK := Color("#E2D3AE")
const CARD := Color("#F7F1E1")
const ZEBRA := Color("#EDE3CA")
const HOVER := Color("#E6D7B2")
const SELECTION := Color("#E9CF86")
const INPUT := Color("#FFFBF0")
const BORDER := Color("#CBB88C")
const BORDER_CONTROL := Color("#8A6428")
const NEWSPAPER := Color("#EEE8D8")
const INK := Color("#2A1E14")
const INK_SOFT := Color("#5C4A36")
const INK_FADED := Color("#7C6A52")
const BRONZE_TEXT := Color("#7A5A26")
const BLUE := Color("#2E4A6B")
const GREEN := Color("#2F5A2A")
const AMBER := Color("#8C5E0A")
const SEALING_WAX := Color("#8E1F1C")
const BRASS := Color("#C9A14A")
const BRASS_BUTTON := Color("#E2C25A")
const GOLD := Color("#D4AF37")
const MENU_TEXT := Color("#E9DDBF")
const MENU_FADED := Color("#9C8B72")
const PARCHMENT := CARD
const PARCHMENT_ALT := ZEBRA
const BRONZE_DARK := BRONZE_TEXT
const BRONZE := BORDER_CONTROL
const NEWSPRINT := NEWSPAPER
const ATTR_LOW_BG := Color("#EDB8A8")
const ATTR_GOOD_BG := Color("#BFD596")
const ATTR_TOP_BG := Color("#2F5A2A")

static var _fonts: Dictionary = {}


static func font(name: String) -> Font:
	if _fonts.has(name):
		return _fonts[name]
	var f: Font
	match name:
		"title":
			f = load("res://assets/fonts/IMFellEnglish-Regular.ttf")
		"title_sc":
			f = load("res://assets/fonts/IMFellEnglishSC-Regular.ttf")
		"title_italic":
			f = load("res://assets/fonts/IMFellEnglish-Italic.ttf")
		"ui_bold":
			f = _spaced("res://assets/fonts/AlegreyaSans-Bold.ttf", 2)
		"ui_medium":
			f = _spaced("res://assets/fonts/AlegreyaSans-Medium.ttf", 2)
		"ui_italic":
			f = load("res://assets/fonts/AlegreyaSans-Italic.ttf")
		"prose":
			f = load("res://assets/fonts/Alegreya-Variable.ttf")
		"gothic":
			f = load("res://assets/fonts/UnifrakturMaguntia-Book.ttf")
		"table":
			var fv := _spaced("res://assets/fonts/AlegreyaSans-Regular.ttf", 1)
			fv.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("tnum"): 1, TextServerManager.get_primary_interface().name_to_tag("lnum"): 1}
			f = fv
		"table_bold":
			var fv2 := _spaced("res://assets/fonts/AlegreyaSans-Bold.ttf", 2)
			fv2.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("tnum"): 1, TextServerManager.get_primary_interface().name_to_tag("lnum"): 1}
			f = fv2
		"label":
			var fv3 := FontVariation.new()
			fv3.base_font = load("res://assets/fonts/AlegreyaSans-Bold.ttf")
			fv3.spacing_glyph = 1
			f = fv3
		_:
			f = _spaced("res://assets/fonts/AlegreyaSans-Regular.ttf", 1)
	f.fallbacks = _fallbacks(name)
	_fonts[name] = f
	return f


## Alegreya Sans has a narrow word space (0.15-0.16 em); at UI sizes, rounded to whole pixels, it all but vanished
## next to digits and colons, more so in Medium and Bold ("Tip2:the squad", "September1993"). A little extra
## space (in pixels) keeps words apart.
static func _spaced(path: String, extra_space: int) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = load(path)
	fv.spacing_space = extra_space
	return fv


## Characters a font lacks are drawn with the next font that has them. IM Fell and UnifrakturMaguntia have no
## Cyrillic, so titles fall back to Alegreya; then the bundled symbols (★ ● ◂ ⏸ …, assets/fonts/fallback/);
## then kanji/hanzi.
static func _fallbacks(name: String) -> Array[Font]:
	var out: Array[Font] = []
	if name.begins_with("title") or name == "gothic":
		out.append(font("prose"))
	out.append(load("res://assets/fonts/fallback/NotoSansSymbols2-Subset.ttf"))
	out.append_array(cjk_fallbacks())
	return out


static var _cjk: SystemFont

## Kanji/hanzi: the game fonts lack them. On desktop, system fonts are used (Mac and Windows ship both); the
## browser has none, so the web build uses the bundled Noto subsets (tools/make_fallback_fonts.py). The Japanese
## or Chinese one goes first depending on the language (the same characters are drawn differently).
static func cjk_fallbacks() -> Array[Font]:
	if Platform.is_web():
		var ja: Font = load("res://assets/fonts/fallback/NotoSansJP-Subset.otf")
		var zh: Font = load("res://assets/fonts/fallback/NotoSansSC-Subset.otf")
		return [ja, zh] if TranslationServer.get_locale().begins_with("ja") else [zh, ja]
	if _cjk == null:
		_cjk = SystemFont.new()
		update_cjk()
	return [_cjk]


static func update_cjk() -> void:
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		update_cjk.call_deferred()
		return
	if Platform.is_web():
		for n in _fonts:
			_fonts[n].fallbacks = _fallbacks(n)
		return
	if _cjk == null:
		return
	var ja := ["Hiragino Sans", "Hiragino Kaku Gothic ProN", "Yu Gothic UI", "Yu Gothic", "Meiryo", "Noto Sans CJK JP"]
	var zh := ["Hiragino Sans GB", "STHeiti", "Heiti SC", "Microsoft YaHei UI", "Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "PingFang SC"]
	var names := ja + zh if TranslationServer.get_locale().begins_with("ja") else zh + ja
	_cjk.font_names = PackedStringArray(names)


## Font size the theme gives a button variation (side menu fitting starts from it).
static func build_font_size(variation: String) -> int:
	return int(round(15 * minf(Settings.text_scale, 1.15))) if variation == "WoodMenu" else int(round(15 * Settings.text_scale))


static func flat(bg: Color, border: Color = Color.TRANSPARENT, border_w: int = 0, radius: int = 4, margin: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


static func empty() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


static var _card_tex: Texture2D


## Parchment card: nine-patch built once with the grain of assets/art/paper_card.png in the centre and the
## edges (tiling seamlessly), rounded corners, a bottom rule and a soft shadow.
static func card(margin: int = 16) -> StyleBox:
	if _card_tex == null:
		_card_tex = _card_texture()
	if _card_tex == null:
		var sb := flat(CARD, BORDER, 0, 4, margin)
		sb.border_width_bottom = 1
		sb.shadow_size = 4
		sb.shadow_offset = Vector2(0, 1)
		sb.shadow_color = Color(WOOD, 0.15)
		return sb
	var st := StyleBoxTexture.new()
	st.texture = _card_tex
	st.set_texture_margin_all(CARD_M)
	st.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	st.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	st.set_expand_margin_all(CARD_SHADOW)
	st.set_content_margin_all(margin)
	return st


## Background desk with tiled paper grain (assets/art/paper_mesa.png).
static func mesa() -> StyleBox:
	if not ResourceLoader.exists("res://assets/art/paper_mesa.png"):
		return flat(DESK, Color.TRANSPARENT, 0, 0, 0)
	var st := StyleBoxTexture.new()
	st.texture = load("res://assets/art/paper_mesa.png")
	st.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	st.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	st.set_content_margin_all(0)
	return st


const CARD_M := 8
const CARD_SHADOW := 3


static func _card_texture() -> Texture2D:
	# Via the imported texture (the loose PNG is not present in the exported game).
	var tex: Texture2D = load("res://assets/art/paper_card.png") if ResourceLoader.exists("res://assets/art/paper_card.png") else null
	if tex == null:
		return null
	var paper := tex.get_image()
	if paper == null:
		return null
	if paper.is_compressed():
		paper.decompress()
	paper.convert(Image.FORMAT_RGBA8)
	var ps := paper.get_width()
	var size := ps + 2 * CARD_M
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r0 := float(CARD_SHADOW)
	var r1 := float(size - CARD_SHADOW)
	var rad := 4.0
	for y in size:
		for x in size:
			var cx := clampf(x + 0.5, r0 + rad, r1 - rad)
			var cy := clampf(y + 0.5, r0 + rad, r1 - rad)
			var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length() - rad
			var c := Color(0, 0, 0, 0)
			var cys := clampf(y - 0.5, r0 + rad, r1 - rad)
			var ds := Vector2(x + 0.5 - cx, y - 0.5 - cys).length() - rad
			if ds < CARD_SHADOW:
				c = Color(WOOD, 0.16 * clampf(1.0 - ds / CARD_SHADOW, 0.0, 1.0))
			if d < 0.5:
				var pc := paper.get_pixel(posmod(x - CARD_M, ps), posmod(y - CARD_M, ps))
				if y >= int(r1) - 1:
					pc = BORDER
				pc.a = clampf(0.5 - d, 0.0, 1.0)
				c = c.blend(pc) if c.a > 0.0 else pc
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func _button_styles(normal: Color, hover: Color, pressed: Color, border: Color, border_w: int = 1, bottom: int = 0, disabled_bg: Color = Color("#E7DDC4"), disabled_border: Color = Color("#CBB88C")) -> Dictionary:
	var n := flat(normal, border, border_w, 4, 8)
	n.content_margin_left = 16
	n.content_margin_right = 16
	if bottom > 0:
		n.border_width_bottom = bottom
	var h := flat(hover, border, border_w, 4, 8)
	h.content_margin_left = 16
	h.content_margin_right = 16
	if bottom > 0:
		h.border_width_bottom = bottom
	var p := flat(pressed, border, border_w, 4, 8)
	p.content_margin_left = 16
	p.content_margin_right = 16
	if bottom > 0:
		p.border_width_top = bottom
	var d := flat(disabled_bg, disabled_border, 1 if disabled_border.a > 0.0 else 0, 4, 8)
	d.content_margin_left = 16
	d.content_margin_right = 16
	var f := flat(hover, BLUE, 2, 4, 8)
	f.content_margin_left = 16
	f.content_margin_right = 16
	return {"normal": n, "hover": h, "pressed": p, "disabled": d, "focus": f}


static func _apply_button(th: Theme, type_name: String, styles: Dictionary, font_color: Color, font_name: String) -> void:
	for k in styles.keys():
		th.set_stylebox(k, type_name, styles[k])
	th.set_color("font_color", type_name, font_color)
	th.set_color("font_hover_color", type_name, font_color)
	th.set_color("font_pressed_color", type_name, font_color)
	th.set_color("font_focus_color", type_name, font_color)
	th.set_color("font_disabled_color", type_name, INK_FADED)
	th.set_font("font", type_name, font(font_name))
	th.set_font_size("font_size", type_name, int(round(15 * Settings.text_scale)))


static func build() -> Theme:
	var th := Theme.new()
	var k: float = Settings.text_scale
	var dense: bool = Settings.density == "compact"
	th.default_font = font("ui")
	th.default_font_size = int(round(15 * k))

	th.set_stylebox("panel", "Panel", card())
	th.set_stylebox("panel", "PanelContainer", card())

	var levels := {
		"H1": ["title", 28, INK], "H2": ["title", 20, INK], "Display": ["title", 40, INK],
		"Caption": ["label", 12, BRONZE_TEXT], "KPI": ["table_bold", 22, INK], "Body": ["ui", 15, INK],
		"BodyMedium": ["ui_medium", 15, INK], "TableText": ["table", 14, INK], "TableBold": ["table_bold", 14, INK],
		"Meta": ["ui", 13, INK_SOFT], "MetaItalic": ["ui_italic", 13, INK_SOFT], "Prose": ["prose", 17, INK],
		"MenuText": ["ui_medium", 15, MENU_TEXT], "MenuCaption": ["label", 12, MENU_FADED],
	}
	for lvl in levels.keys():
		th.set_type_variation(lvl, "Label")
		th.set_font("font", lvl, font(levels[lvl][0]))
		var kk: float = minf(k, 1.15) if lvl.begins_with("Menu") else k
		th.set_font_size("font_size", lvl, int(round(int(levels[lvl][1]) * kk)))
		th.set_color("font_color", lvl, levels[lvl][2])
	th.set_color("font_color", "Label", INK)
	th.set_color("default_color", "RichTextLabel", INK)
	th.set_font("normal_font", "RichTextLabel", font("prose"))
	th.set_font("bold_font", "RichTextLabel", font("ui_bold"))
	th.set_font("italics_font", "RichTextLabel", font("ui_italic"))
	th.set_font_size("normal_font_size", "RichTextLabel", int(round(17 * k)))
	th.set_font_size("bold_font_size", "RichTextLabel", int(round(16 * k)))
	th.set_font_size("italics_font_size", "RichTextLabel", int(round(16 * k)))
	th.set_constant("line_separation", "RichTextLabel", 4)

	_apply_button(th, "Button", _button_styles(Color.TRANSPARENT, ZEBRA, HOVER, BORDER_CONTROL, 1), INK, "ui_medium")
	th.set_type_variation("Primary", "Button")
	_apply_button(th, "Primary", _button_styles(BRASS_BUTTON, Color("#EBCD6A"), BRASS, BORDER_CONTROL, 0, 2), INK, "ui_bold")
	th.set_type_variation("Danger", "Button")
	_apply_button(th, "Danger", _button_styles(SEALING_WAX, Color("#A52622"), Color("#6E1512"), Color("#5E1210"), 0, 0), CARD, "ui_bold")
	th.set_type_variation("Link", "Button")
	var link_hover := StyleBoxFlat.new()
	link_hover.bg_color = Color.TRANSPARENT
	link_hover.border_color = BLUE
	link_hover.border_width_bottom = 1
	link_hover.set_content_margin_all(0)
	link_hover.content_margin_bottom = 1
	var link_plain := StyleBoxEmpty.new()
	link_plain.set_content_margin_all(0)
	link_plain.content_margin_bottom = 1
	_apply_button(th, "Link", {"normal": link_plain, "hover": link_hover, "pressed": link_hover, "disabled": link_plain, "focus": link_plain}, BLUE, "ui_medium")
	th.set_type_variation("Wood", "Button")
	_apply_button(th, "Wood", _button_styles(Color.TRANSPARENT, WOOD_SEL, WOOD_SEL, Color.TRANSPARENT, 0, 0, Color.TRANSPARENT, Color.TRANSPARENT), MENU_TEXT, "ui_medium")
	th.set_color("font_disabled_color", "Wood", MENU_FADED)
	th.set_font_size("font_size", "Wood", int(round(15 * minf(k, 1.15))))
	th.set_type_variation("WoodMenu", "Wood")
	var menu_styles := _button_styles(Color.TRANSPARENT, WOOD_SEL, WOOD_SEL, Color.TRANSPARENT, 0, 0, Color.TRANSPARENT, Color.TRANSPARENT)
	for sk in menu_styles.keys():
		var sb: StyleBox = menu_styles[sk]
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		sb.content_margin_left = 10
		sb.content_margin_right = 8
	_apply_button(th, "WoodMenu", menu_styles, MENU_TEXT, "ui_medium")
	th.set_font_size("font_size", "WoodMenu", int(round(15 * minf(k, 1.15))))
	th.set_color("font_disabled_color", "WoodMenu", MENU_FADED)
	th.set_color("icon_hover_color", "WoodMenu", BRASS)
	th.set_color("icon_pressed_color", "WoodMenu", BRASS)
	th.set_color("icon_disabled_color", "Wood", Color(MENU_FADED, 0.5))
	th.set_color("icon_hover_color", "Wood", BRASS)
	th.set_color("icon_pressed_color", "Wood", BRASS)
	th.set_constant("h_separation", "Button", 6)

	var input_n := flat(INPUT, BORDER_CONTROL, 1, 3, 6)
	input_n.content_margin_left = 10
	input_n.content_margin_right = 10
	var input_f := flat(INPUT, BLUE, 2, 3, 6)
	input_f.content_margin_left = 10
	input_f.content_margin_right = 10
	th.set_stylebox("normal", "LineEdit", input_n)
	th.set_stylebox("focus", "LineEdit", input_f)
	th.set_color("font_color", "LineEdit", INK)
	th.set_color("caret_color", "LineEdit", INK)
	th.set_color("font_placeholder_color", "LineEdit", INK_FADED)
	var input_h := flat(Color("#FFFDF5"), BORDER_CONTROL, 1, 3, 6)
	var input_d := flat(Color("#EFE9DA"), BORDER, 1, 3, 6)
	for sb in [input_h, input_d]:
		sb.content_margin_left = 10
		sb.content_margin_right = 10
	var opt_styles := {"normal": input_n, "hover": input_h, "pressed": input_f, "disabled": input_d, "focus": input_f}
	for st in opt_styles.keys():
		th.set_stylebox(st, "OptionButton", opt_styles[st])
		if st != "focus":
			th.set_stylebox(st + "_mirrored", "OptionButton", opt_styles[st])
	th.set_color("font_color", "OptionButton", INK)
	th.set_color("font_hover_color", "OptionButton", INK)
	th.set_color("font_pressed_color", "OptionButton", INK)
	th.set_color("font_focus_color", "OptionButton", INK)
	th.set_color("font_disabled_color", "OptionButton", INK_FADED)
	th.set_font("font", "OptionButton", font("ui"))
	th.set_stylebox("panel", "PopupMenu", flat(CARD, BORDER_CONTROL, 1, 4, 6))
	th.set_color("font_color", "PopupMenu", INK)
	th.set_color("font_hover_color", "PopupMenu", INK)
	th.set_color("font_separator_color", "PopupMenu", INK_SOFT)
	th.set_stylebox("hover", "PopupMenu", flat(HOVER, Color.TRANSPARENT, 0, 3, 4))
	th.set_color("font_color", "CheckBox", INK)
	th.set_color("font_color", "CheckButton", INK)
	for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		th.set_stylebox(st, "CheckBox", empty())
		th.set_stylebox(st, "CheckButton", empty())
	th.set_color("font_hover_color", "CheckBox", INK)
	th.set_color("font_pressed_color", "CheckBox", INK)
	th.set_color("font_hover_pressed_color", "CheckBox", INK)
	th.set_color("font_focus_color", "CheckBox", INK)

	th.set_stylebox("panel", "Tree", empty())
	th.set_stylebox("focus", "Tree", empty())
	th.set_color("font_color", "Tree", INK)
	for state in ["font_hovered_color", "font_hovered_dimmed_color", "font_hovered_selected_color", "font_selected_color"]:
		th.set_color(state, "Tree", INK)
	th.set_font("font", "Tree", font("table"))
	th.set_font_size("font_size", "Tree", int(round(14 * k)))
	th.set_stylebox("selected", "Tree", flat(SELECTION, Color.TRANSPARENT, 0, 0, 2))
	th.set_stylebox("selected_focus", "Tree", flat(SELECTION, Color.TRANSPARENT, 0, 0, 2))
	th.set_stylebox("hovered", "Tree", flat(HOVER, Color.TRANSPARENT, 0, 0, 2))
	th.set_stylebox("hovered_selected", "Tree", flat(SELECTION, Color.TRANSPARENT, 0, 0, 2))
	th.set_stylebox("hovered_selected_focus", "Tree", flat(SELECTION, Color.TRANSPARENT, 0, 0, 2))
	th.set_stylebox("hovered_dimmed", "Tree", flat(HOVER, Color.TRANSPARENT, 0, 0, 2))
	th.set_stylebox("cursor", "Tree", empty())
	th.set_stylebox("cursor_unfocused", "Tree", empty())
	th.set_stylebox("title_button_normal", "Tree", flat(WOOD_MID, Color.TRANSPARENT, 0, 0, 4))
	th.set_stylebox("title_button_hover", "Tree", flat(WOOD_SEL, Color.TRANSPARENT, 0, 0, 4))
	th.set_stylebox("title_button_pressed", "Tree", flat(WOOD, Color.TRANSPARENT, 0, 0, 4))
	th.set_color("title_button_color", "Tree", CARD)
	th.set_font("title_button_font", "Tree", font("label"))
	th.set_font_size("title_button_font_size", "Tree", int(round(12 * k)))
	th.set_constant("draw_guides", "Tree", 0)
	th.set_constant("v_separation", "Tree", 4 if dense else 8)
	th.set_constant("h_separation", "Tree", 6)
	th.set_constant("inner_item_margin_left", "Tree", 6)
	th.set_constant("inner_item_margin_right", "Tree", 6)
	th.set_color("guide_color", "Tree", Color.TRANSPARENT)

	th.set_stylebox("panel", "ItemList", empty())
	th.set_stylebox("focus", "ItemList", empty())
	th.set_color("font_color", "ItemList", INK)
	th.set_color("font_selected_color", "ItemList", INK)
	th.set_color("font_hovered_color", "ItemList", INK)
	th.set_stylebox("selected", "ItemList", flat(SELECTION, Color.TRANSPARENT, 0, 3, 4))
	th.set_stylebox("selected_focus", "ItemList", flat(SELECTION, Color.TRANSPARENT, 0, 3, 4))
	th.set_stylebox("hovered", "ItemList", flat(HOVER, Color.TRANSPARENT, 0, 3, 4))
	th.set_stylebox("hovered_selected", "ItemList", flat(SELECTION, Color.TRANSPARENT, 0, 3, 4))
	th.set_stylebox("hovered_selected_focus", "ItemList", flat(SELECTION, Color.TRANSPARENT, 0, 3, 4))
	th.set_stylebox("cursor", "ItemList", empty())
	th.set_stylebox("cursor_unfocused", "ItemList", empty())
	th.set_constant("v_separation", "ItemList", 4 if dense else 8)
	th.set_font_size("font_size", "ItemList", int(round(15 * k)))
	th.set_font_size("font_size", "LineEdit", int(round(15 * k)))
	th.set_font_size("font_size", "OptionButton", int(round(15 * k)))
	th.set_font_size("font_size", "PopupMenu", int(round(15 * k)))
	th.set_font_size("font_size", "TabContainer", int(round(15 * k)))
	th.set_font_size("font_size", "TabBar", int(round(15 * k)))
	th.set_font_size("font_size", "CheckBox", int(round(15 * k)))

	th.set_stylebox("panel", "TabContainer", card())
	th.set_stylebox("tab_selected", "TabContainer", _tab(CARD, true))
	th.set_stylebox("tab_unselected", "TabContainer", _tab(DESK, false))
	th.set_stylebox("tab_hovered", "TabContainer", _tab(HOVER, false))
	th.set_color("font_selected_color", "TabContainer", INK)
	th.set_color("font_unselected_color", "TabContainer", INK_SOFT)
	th.set_color("font_hovered_color", "TabContainer", INK)
	th.set_font("font", "TabContainer", font("ui_medium"))
	th.set_stylebox("tab_selected", "TabBar", _tab(CARD, true))
	th.set_stylebox("tab_unselected", "TabBar", _tab(DESK, false))
	th.set_stylebox("tab_hovered", "TabBar", _tab(HOVER, false))
	th.set_color("font_selected_color", "TabBar", INK)
	th.set_color("font_unselected_color", "TabBar", INK_SOFT)
	th.set_color("font_hovered_color", "TabBar", INK)
	th.set_font("font", "TabBar", font("ui_medium"))

	th.set_stylebox("slider", "HSlider", _track(BORDER))
	th.set_stylebox("grabber_area", "HSlider", _track(BRONZE_TEXT))
	th.set_stylebox("grabber_area_highlight", "HSlider", _track(BRONZE_TEXT))
	th.set_icon("grabber", "HSlider", _grabber_icon(false))
	th.set_icon("grabber_highlight", "HSlider", _grabber_icon(true))
	th.set_icon("grabber_disabled", "HSlider", _grabber_icon(false))
	th.set_stylebox("background", "ProgressBar", flat(DESK, Color.TRANSPARENT, 0, 2, 0))
	th.set_stylebox("fill", "ProgressBar", flat(GREEN, Color.TRANSPARENT, 0, 2, 0))
	th.set_color("font_color", "ProgressBar", INK)

	for bar in ["VScrollBar", "HScrollBar"]:
		th.set_stylebox("scroll", bar, flat(Color(BORDER_CONTROL, 0.18), Color.TRANSPARENT, 0, 5, 5))
		th.set_stylebox("scroll_focus", bar, flat(Color(BORDER_CONTROL, 0.18), Color.TRANSPARENT, 0, 5, 5))
		th.set_stylebox("grabber", bar, flat(Color(BRONZE_TEXT, 0.75), Color.TRANSPARENT, 0, 5, 5))
		th.set_stylebox("grabber_highlight", bar, flat(BRONZE_TEXT, Color.TRANSPARENT, 0, 5, 5))
		th.set_stylebox("grabber_pressed", bar, flat(INK, Color.TRANSPARENT, 0, 5, 5))

	th.set_stylebox("panel", "TooltipPanel", flat(WOOD, BRASS, 1, 4, 8))
	th.set_color("font_color", "TooltipLabel", MENU_TEXT)
	th.set_font_size("font_size", "TooltipLabel", int(round(14 * k)))
	var win := flat(CARD, BRASS, 2, 8, 0)
	win.expand_margin_top = 34
	win.expand_margin_left = 2
	win.expand_margin_right = 2
	win.expand_margin_bottom = 2
	win.border_width_top = 34
	win.border_color = Color("#3A2A1C")
	win.shadow_color = Color(0, 0, 0, 0.35)
	win.shadow_size = 12
	th.set_stylebox("embedded_border", "Window", win)
	th.set_stylebox("embedded_unfocused_border", "Window", win)
	th.set_color("title_color", "Window", Color("#F4EFE0"))
	th.set_font("title_font", "Window", font("title"))
	th.set_font_size("title_font_size", "Window", int(round(17 * k)))
	th.set_stylebox("panel", "AcceptDialog", flat(CARD, Color.TRANSPARENT, 0, 0, 14))
	th.set_stylebox("panel", "PopupPanel", flat(CARD, BRASS, 2, 6, 10))
	return th


static func _track(c: Color) -> StyleBoxFlat:
	var sb := flat(c, Color.TRANSPARENT, 0, 2, 0)
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb


static func _tab(bg: Color, selected: bool) -> StyleBoxFlat:
	var sb := flat(bg, BRASS, 0, 0, 8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	if selected:
		sb.border_width_bottom = 2
	return sb


static func _grabber_icon(highlight: bool) -> ImageTexture:
	var size := 16
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size / 2.0 - 0.5, size / 2.0 - 0.5)
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(c)
			if d <= 5.0:
				img.set_pixel(x, y, CARD if not highlight else Color("#FFFDF5"))
			elif d <= 7.0:
				img.set_pixel(x, y, BRONZE_TEXT)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


## Heat map for a 1-20 attribute: {bg, fg, bold}.
static func attr_style(v: float) -> Dictionary:
	if v >= 16.0:
		return {"bg": ATTR_TOP_BG, "fg": CARD, "bold": true}
	if v >= 11.0:
		return {"bg": ATTR_GOOD_BG, "fg": INK, "bold": false}
	if v >= 6.0:
		return {"bg": Color.TRANSPARENT, "fg": INK_SOFT, "bold": false}
	return {"bg": ATTR_LOW_BG, "fg": SEALING_WAX, "bold": false}


## Compatibility: text colour of an attribute.
static func attr_color(v: float) -> Color:
	return attr_style(v)["fg"]


## Semantic colour for a 0-100 bar.
static func bar_color(v: float) -> Color:
	if v >= 75.0:
		return GREEN
	if v >= 50.0:
		return AMBER
	return SEALING_WAX


static func hex(c: String, fallback: Color = BORDER_CONTROL) -> Color:
	if c == null or c == "":
		return fallback
	return Color(c)


static func text_on(bg: Color) -> Color:
	return INK if bg.get_luminance() > 0.5 else CARD


static func icon(name: String) -> Texture2D:
	var path := "res://assets/icons/%s.svg" % name
	if ResourceLoader.exists(path):
		return load(path)
	return null
