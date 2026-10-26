class_name UI
extends RefCounted
## Control builders. Every screen is built in code.

const ROW_H := 26


## Text using a level of the type scale: H1, H2, Display, Rotulo, KPI, Cuerpo, CuerpoMedio, Tabla, TablaBold, Meta,
## MetaItalic, Prosa, MenuTexto, MenuRotulo.
static func text(level: String, s: String, color: Variant = null) -> Label:
	var l := Label.new()
	l.text = s.to_upper() if level == "Caption" or level == "MenuCaption" else s
	l.theme_type_variation = level
	if color != null:
		l.add_theme_color_override("font_color", color)
	return l


## Compatibility: label with an explicit font and size (13 px minimum).
static func label(s: String, font_name: String = "ui", size: int = 15, color: Color = ThemeBuilder.INK) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", ThemeBuilder.font(font_name))
	l.add_theme_font_size_override("font_size", Settings.px(maxi(size, 13)))
	l.add_theme_color_override("font_color", color)
	return l


static func title(s: String, size: int = 28) -> Label:
	var l := text("H1", s)
	if size != 28:
		l.add_theme_font_size_override("font_size", Settings.px(maxi(size, 20)))
	return l


static func h2(s: String) -> Label:
	return text("H2", s)


## Section label inside a card (uppercase, bronze).
static func subtitle(s: String) -> Label:
	return text("Caption", s)


static func meta(s: String) -> Label:
	return text("Meta", s)


static func kpi(value: String, caption: String) -> VBoxContainer:
	var v := vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vl := text("KPI", value)
	vl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vl.tooltip_text = value
	vl.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(vl)
	var cl := text("Caption", caption)
	cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cl.tooltip_text = caption
	cl.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(cl)
	return v


static func rule() -> Control:
	var c := ColorRect.new()
	c.color = ThemeBuilder.BORDER
	c.custom_minimum_size = Vector2(0, 1)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func gap(h: int = 8) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


static func spacer(h: bool = true) -> Control:
	var c := Control.new()
	if h:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return v


static func hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return h


## Card: the only box allowed on the desk.
static func panel(margin: int = 16) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# PanelContainer stops mouse events by default, which kept the mouse wheel from reaching the ScrollContainer of
	# screens built from cards (Players, Club, Competitions…): pass them on.
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_theme_stylebox_override("panel", ThemeBuilder.card(margin))
	return p


static func card(margin: int = 16) -> PanelContainer:
	return panel(margin)


static func wood_panel(margin: int = 8) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", ThemeBuilder.flat(ThemeBuilder.WOOD, Color.TRANSPARENT, 0, 0, margin))
	return p


static func button(s: String, cb: Callable = Callable(), primary: bool = false) -> Button:
	var b := Button.new()
	b.text = s
	b.custom_minimum_size = Vector2(0, 32)
	b.pressed.connect(func(): Sfx.play("click", -10.0))
	if cb.is_valid():
		b.pressed.connect(cb)
	if primary:
		b.theme_type_variation = "Primary"
	return b


static func primary(s: String, cb: Callable) -> Button:
	return button(s, cb, true)


static func link(s: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = s
	b.theme_type_variation = "Link"
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


## Danger button (sealing wax): irreversible actions.
static func seal_button(s: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = s
	b.custom_minimum_size = Vector2(0, 32)
	b.theme_type_variation = "Danger"
	b.pressed.connect(cb)
	return b


static func icon_button(icon_name: String, cb: Callable, tooltip: String = "") -> Button:
	var b := Button.new()
	b.theme_type_variation = "Wood"
	b.icon = ThemeBuilder.icon(icon_name)
	b.custom_minimum_size = Vector2(32, 32)
	b.add_theme_constant_override("icon_max_width", 18)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.tooltip_text = tooltip
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


## Vertical stripe with the club's two colours.
static func club_stripe(club: Club, height: int = 18) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	for key in ["primary", "secondary"]:
		var c := ColorRect.new()
		c.color = ThemeBuilder.hex(str(club.colors.get(key, "#888888")))
		c.custom_minimum_size = Vector2(4, height)
		h.add_child(c)
	return h


## Club heraldic crest (Crest): a shield in its colours with the canon charge.
static func crest(club: Club, size: int = 40) -> Control:
	var c := Crest.new()
	c.custom_minimum_size = Vector2(size, int(size * 1.15))
	c.set_club(club)
	if club != null:
		make_team_clickable(c, club.id)
	return c


## Image if it exists in assets/<dir>/<id>.(png|jpg); null otherwise.
static func image_for(dir: String, id: String) -> Texture2D:
	for ext in ["png", "jpg"]:
		var path := "res://assets/%s/%s.%s" % [dir, id, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return null


## Portrait: deterministic procedural face (Face) with robes in the club colours, the same for every player;
## characters from the books carry their fixed features in `Player.look`.
static func portrait(p: Player, club: Club, size: int) -> Control:
	var pc := ThemeBuilder.hex(str(club.colors.get("primary", "#888"))) if club else ThemeBuilder.BORDER_CONTROL
	var sc := ThemeBuilder.hex(str(club.colors.get("secondary", "#ddd"))) if club else ThemeBuilder.BRASS
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", ThemeBuilder.flat(pc, sc, 2, 4, 2))
	frame.custom_minimum_size = Vector2(size, int(size * 1.25))
	var face := Face.new()
	face.custom_minimum_size = Vector2(size - 4, int(size * 1.25) - 4)
	var region := club.region_id if club else ""
	if Game.loader != null and Game.loader.countries.has(p.nationality):
		region = str(Game.loader.countries[p.nationality].get("region_id", region))
	face.setup(p, club, region, Game.world.today if Game.world != null else 0)
	frame.add_child(face)
	return frame


## Country flag (assets/flags/<country_id>.png); empty if there is none.
static func flag(country_id: String, height: int = 14) -> Control:
	var tex := image_for("flags", country_id)
	var tr := TextureRect.new()
	if tex == null:
		tr.custom_minimum_size = Vector2(0, 0)
		return tr
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(int(height * 1.6), height)
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return tr


## Table with a dark header, zebra rows and click-to-sort. columns: [{title, width, align, expand, tooltip}]
static func table(columns: Array, min_height: int = 200) -> Tree:
	var t := Tree.new()
	t.columns = columns.size()
	t.column_titles_visible = true
	t.hide_root = true
	t.select_mode = Tree.SELECT_ROW
	t.auto_tooltip = false
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_EXPAND_FILL
	t.custom_minimum_size = Vector2(0, min_height)
	t.set_meta("columns", columns)
	t.set_meta("sort_col", -1)
	t.set_meta("sort_desc", true)
	for i in columns.size():
		var c: Dictionary = columns[i]
		t.set_column_title(i, str(c.get("title", "")).to_upper())
		t.set_column_expand(i, bool(c.get("expand", false)))
		var title_w := int(ceil(ThemeBuilder.font("label").get_string_size(str(c.get("title", "")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(12 * Settings.text_scale))).x)) + 10
		t.set_column_custom_minimum_width(i, maxi(Settings.px(int(c.get("width", 60))), title_w))
		if c.has("tooltip"):
			t.set_column_title_tooltip_text(i, str(c["tooltip"]))
		var al := str(c.get("align", "left"))
		t.set_column_title_alignment(i, HORIZONTAL_ALIGNMENT_RIGHT if al == "right" else (HORIZONTAL_ALIGNMENT_CENTER if al == "center" else HORIZONTAL_ALIGNMENT_LEFT))
	t.create_item()
	t.column_title_clicked.connect(func(col: int, _btn: int): _sort_by(t, col))
	# Right click selects the row too (the player menu opens on it), so the button of the last press (and its frame)
	# is remembered for rmb_selected. The gui_input signal runs before the Tree's own input handling, so it is set by
	# the time item_selected fires.
	t.allow_rmb_select = true
	t.set_meta("last_button", 0)
	t.gui_input.connect(func(ev: InputEvent):
		var mb := ev as InputEventMouseButton
		if mb != null and mb.pressed and (mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT):
			t.set_meta("last_button", mb.button_index)
			t.set_meta("press_frame", Engine.get_process_frames())
		elif ev is InputEventKey:
			t.set_meta("last_button", 0))
	t.item_mouse_selected.connect(func(pos: Vector2, btn: int): _on_table_click(t, pos, btn))
	_link_hover(t)
	return t


## The table's current selection was made with the right button (it opens the player menu): screens that act on
## item_selected (place a player, open a row) ignore it. Only right after the press: a selection the screen makes
## later in code (a refresh after a menu action re-selecting its row) is not the right click's.
static func rmb_selected(t: Tree) -> bool:
	return int(t.get_meta("last_button", 0)) == MOUSE_BUTTON_RIGHT and Engine.get_process_frames() - int(t.get_meta("press_frame", -10)) <= 1


static func _link_hover(t: Tree) -> void:
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.add_child(overlay)
	t.set_meta("hover_link", [])
	t.draw.connect(overlay.queue_redraw)
	t.resized.connect(func(): overlay.size = t.size)
	t.gui_input.connect(func(ev: InputEvent):
		if (ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]) or ev is InputEventPanGesture:
			t.set_meta("hover_link", [])
			t.mouse_default_cursor_shape = Control.CURSOR_ARROW
			overlay.queue_redraw()
			return
		if not (ev is InputEventMouseMotion):
			return
		var cur := _link_at(t, (ev as InputEventMouseMotion).position)
		if cur != t.get_meta("hover_link", []):
			t.set_meta("hover_link", cur)
			t.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not cur.is_empty() else Control.CURSOR_ARROW
			overlay.queue_redraw())
	t.mouse_exited.connect(func():
		t.set_meta("hover_link", [])
		t.mouse_default_cursor_shape = Control.CURSOR_ARROW
		overlay.queue_redraw())
	overlay.draw.connect(func():
		var hl: Array = t.get_meta("hover_link", [])
		if hl.is_empty() or not is_instance_valid(hl[0]):
			return
		var mp := t.get_local_mouse_position()
		if not Rect2(Vector2.ZERO, t.size).has_point(mp):
			return
		hl = _link_at(t, mp)
		if hl.is_empty():
			return
		var it: TreeItem = hl[0]
		var col: int = hl[1]
		var text := it.get_text(col)
		if text == "":
			return
		var rect := t.get_item_area_rect(it, col)
		var f: Font = it.get_custom_font(col) if it.get_custom_font(col) != null else t.get_theme_font("font")
		var fs: int = t.get_theme_font_size("font_size")
		var tw: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var lk: Array = (it.get_meta("links") as Dictionary)[col]
		var ul_w: float = f.get_string_size(str(lk[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if lk.size() > 2 else tw
		var margin := float(t.get_theme_constant("inner_item_margin_left"))
		# First column: the Tree keeps item_margin per level before the text (the fold-arrow space), top-level rows
		# included even with the root hidden.
		if col == 0:
			var depth := 1
			var up := it.get_parent()
			while up != null and up != t.get_root():
				depth += 1
				up = up.get_parent()
			margin += float(t.get_theme_constant("item_margin")) * depth
		else:
			# Every other column starts after the Tree's h_separation.
			margin += float(t.get_theme_constant("h_separation"))
		var icon_w := 0.0
		if it.get_icon(col) != null:
			icon_w = float(it.get_icon_max_width(col) if it.get_icon_max_width(col) > 0 else it.get_icon(col).get_width()) + float(t.get_theme_constant("icon_h_separation"))
		var x0 := rect.position.x + margin + icon_w
		match it.get_text_alignment(col):
			HORIZONTAL_ALIGNMENT_RIGHT:
				x0 = rect.end.x - float(t.get_theme_constant("inner_item_margin_right")) - tw
			HORIZONTAL_ALIGNMENT_CENTER:
				x0 = rect.position.x + icon_w + (rect.size.x - icon_w - tw) / 2.0
		var x1 := minf(x0 + ul_w, rect.end.x - 2.0)
		var y := rect.position.y + (rect.size.y + f.get_ascent(fs) - f.get_descent(fs)) / 2.0 + 2.0
		# get_custom_color() is opaque black when the cell has none.
		var c: Color = it.get_custom_color(col) if it.get_custom_color(col) != Color() else ThemeBuilder.BLUE
		overlay.draw_line(Vector2(x0, y), Vector2(x1, y), c, 1.0))


static func _link_at(t: Tree, pos: Vector2) -> Array:
	var it := t.get_item_at_position(pos)
	if it != null and it.has_meta("links"):
		var col := t.get_column_at_position(pos)
		if col >= 0 and (it.get_meta("links") as Dictionary).has(col):
			return [it, col]
	return []


## Makes a table exactly as tall as its rows once it has been laid out, so short tables never hide their last row
## behind an inner scroll bar (row heights depend on icons, fonts and density, which a fixed formula misses). Its own
## vertical scroll is off (the Tree then also asks for its rows' height), so the mouse wheel over it scrolls the page.
## It grows again after a refresh that adds rows (never shrinks below the caller's minimum).
static func fit_rows(t: Tree) -> void:
	t.scroll_vertical_enabled = false
	if t.has_meta("fit_rows"):
		return
	t.set_meta("fit_rows", true)
	var fit := func():
		if not is_instance_valid(t) or t.get_root() == null:
			return
		var last: TreeItem = t.get_root().get_child(t.get_root().get_child_count() - 1) if t.get_root().get_child_count() > 0 else null
		if last == null:
			return
		var bottom := t.get_item_area_rect(last).end.y + float(t.get_scroll().y) + 6.0
		if bottom > t.custom_minimum_size.y:
			t.custom_minimum_size.y = bottom
	t.draw.connect(fit)


static var _swatch: ImageTexture = null


## 6×16 white texture to tint with set_icon_modulate (colour stripe in a cell).
static func swatch() -> ImageTexture:
	if _swatch == null:
		var img := Image.create(6, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_swatch = ImageTexture.create_from_image(img)
	return _swatch


## Cell with the club crest (or the colour stripe if it has no crest).
static func club_cell(it: TreeItem, col: int, club: Club) -> void:
	if club == null:
		return
	team_cell(it, col, club.id)
	var tex := Crest.icon_for(club)
	if tex != null:
		it.set_icon(col, tex)
		it.set_icon_max_width(col, 20)
		return
	it.set_icon(col, swatch())
	it.set_icon_modulate(col, ThemeBuilder.hex(str(club.colors.get("primary", "#888888"))))
	it.set_icon_max_width(col, 6)


## Navigation for links (set by main.gd): func(screen, params).
static var router: Callable
## Right click on a player (tables, names, links): a small menu with "View profile" and the profile's actions
## (main._player_menu).
static var player_menu: Callable


## Linked cell: link colour, and clicking it opens the profile (see `table`).
static func link_cell(it: TreeItem, col: int, screen: String, params: Dictionary) -> void:
	var links: Dictionary = it.get_meta("links", {})
	links[col] = [screen, params]
	it.set_meta("links", links)
	it.set_custom_color(col, ThemeBuilder.BLUE)


## For a link cell whose text carries more than the name ("Name (Club) · 8.4"): the hover underline covers only
## `part`, the start of the text.
static func link_underline(it: TreeItem, col: int, part: String) -> void:
	var links: Dictionary = it.get_meta("links", {})
	if links.has(col) and it.get_text(col).begins_with(part):
		links[col] = [links[col][0], links[col][1], part]
		it.set_meta("links", links)


static func player_cell(it: TreeItem, col: int, player_id: String) -> void:
	if player_id != "" and Game.world != null and Game.world.player(player_id) != null:
		link_cell(it, col, "player", {"player_id": player_id})


## Club, house (hs_*) or national team (nt_*).
static func team_cell(it: TreeItem, col: int, team_id: String) -> void:
	if team_id == "" or Game.world == null:
		return
	if not (Game.world.clubs.has(team_id) or Game.world.national_teams.has(team_id) or Game.world.houses.has(team_id)):
		return
	if team_id.begins_with("nt_"):
		link_cell(it, col, "national", {"nt_id": team_id})
	else:
		link_cell(it, col, "club", {"club_id": team_id})


static func _on_table_click(t: Tree, pos: Vector2, button: int) -> void:
	var it := t.get_item_at_position(pos)
	if it == null or not it.has_meta("links"):
		return
	var col := t.get_column_at_position(pos)
	var links: Dictionary = it.get_meta("links")
	if button == MOUSE_BUTTON_RIGHT:
		if player_menu.is_valid():
			for c in ([col] + links.keys()):
				if links.has(c) and str(links[c][0]) == "player":
					player_menu.call(str(links[c][1].get("player_id", "")))
					return
		return
	if button != MOUSE_BUTTON_LEFT or not router.is_valid():
		return
	if links.has(col):
		router.call(str(links[col][0]), links[col][1])


## Makes any control (name, crest) clickable to open a team or player profile.
static func make_team_clickable(c: Control, team_id: String) -> void:
	if team_id == "" or Game.world == null or not (Game.world.clubs.has(team_id) or Game.world.national_teams.has(team_id) or Game.world.houses.has(team_id)):
		return
	_clickable(c, "national" if team_id.begins_with("nt_") else "club", {"nt_id": team_id} if team_id.begins_with("nt_") else {"club_id": team_id})


static func make_player_clickable(c: Control, player_id: String) -> void:
	if player_id != "" and Game.world != null and Game.world.player(player_id) != null:
		_clickable(c, "player", {"player_id": player_id})


static func _clickable(c: Control, screen: String, params: Dictionary) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if c is Label:
		var lbl := c as Label
		lbl.mouse_entered.connect(func(): lbl.set_meta("hovered", true); lbl.queue_redraw())
		lbl.mouse_exited.connect(func(): lbl.set_meta("hovered", false); lbl.queue_redraw())
		lbl.draw.connect(func():
			if not bool(lbl.get_meta("hovered", false)) or lbl.get_line_count() == 0:
				return
			var f: Font = lbl.get_theme_font("font")
			var fs: int = lbl.get_theme_font_size("font_size")
			var tw: float = minf(f.get_string_size(lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, lbl.size.x)
			var x0 := 0.0
			if lbl.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
				x0 = lbl.size.x - tw
			elif lbl.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
				x0 = (lbl.size.x - tw) / 2.0
			var y := (lbl.size.y + f.get_height(fs)) / 2.0 - f.get_descent(fs) + 2.0
			lbl.draw_line(Vector2(x0, y), Vector2(x0 + tw, y), lbl.get_theme_color("font_color"), 1.0))
	c.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and router.is_valid():
			router.call(screen, params)
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT and screen == "player" and player_menu.is_valid():
			player_menu.call(str(params.get("player_id", ""))))


## Why a player cannot be fielded by his club: injury, ban or international duty (Player.is_available).
static func unavailable_text(p: Player) -> String:
	if p.injury_days > 0:
		return Game.t("ui.injured_days") % p.injury_days
	if p.suspension_matches > 0:
		return Game.t("ui.suspended") % p.suspension_matches
	if p.on_duty():
		return Game.t("ui.on_duty") % [Game.world.team_name(p.duty_team), p.duty_days]
	return ""


## The website's bug/idea form (server /feedback) with the version and platform prefilled: in the browser build the
## page's own origin, on desktop `application/config/site_url` (https). Empty when neither is known: no link.
static func feedback_url() -> String:
	var base := str(ProjectSettings.get_setting("application/config/site_url", ""))
	if OS.has_feature("web"):
		var origin = JavaScriptBridge.eval("location.origin")
		if origin is String and origin.begins_with("http"):
			base = origin
	if not base.begins_with("http"):
		return ""
	var context := "v%s, %s" % [str(ProjectSettings.get_setting("application/config/version", "")), OS.get_name()]
	return "%s/feedback?kind=bug&context=%s" % [base.trim_suffix("/"), context.uri_encode()]


## The "About" block (title screen dialog and Settings): version, a link to the source code (when the project has
## `application/config/repository_url`), and the fan-project notice with the licences. `width` fixes the notice's
## wrap width (needed in a dialog, which otherwise sizes a wrapping label for zero width and grows very tall).
static func about_box(width: int = 0) -> VBoxContainer:
	var v := vbox(6)
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	v.add_child(text("BodyMedium", "Quidditch Manager %s" % version if version != "" else "Quidditch Manager"))
	var repo := str(ProjectSettings.get_setting("application/config/repository_url", ""))
	if repo.begins_with("https://"):
		var l := link(TranslationServer.translate("ui.about.source"), func(): OS.shell_open(repo))
		l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		l.tooltip_text = repo
		v.add_child(l)
	var feedback := feedback_url()
	if feedback != "":
		var fl := link(TranslationServer.translate("ui.about.feedback"), func(): OS.shell_open(feedback))
		fl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		fl.tooltip_text = feedback.get_slice("?", 0)
		v.add_child(fl)
	var note := text("Body", TranslationServer.translate("ui.settings.about_text"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if width > 0:
		note.custom_minimum_size.x = width
	v.add_child(note)
	return v


## Standalone link (outside tables) to a player or team profile.
static func player_link(player_id: String, text: String) -> Button:
	var b := link(text, func(): if router.is_valid(): router.call("player", {"player_id": player_id}))
	b.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT and player_menu.is_valid():
			player_menu.call(player_id))
	return b


static func team_link(team_id: String, text: String) -> Button:
	var screen := "national" if team_id.begins_with("nt_") else "club"
	var params := {"nt_id": team_id} if team_id.begins_with("nt_") else {"club_id": team_id}
	return link(text, func(): if router.is_valid(): router.call(screen, params))


## Card wrapping a table (tables never sit loose on the desk).
static func table_card(t: Tree) -> PanelContainer:
	var p := panel(8)
	p.size_flags_vertical = t.size_flags_vertical
	p.add_child(t)
	return p


static func row(t: Tree, values: Array, meta = null, colors: Array = []) -> TreeItem:
	var it := t.create_item(t.get_root())
	it.custom_minimum_height = Settings.row_height()
	for i in values.size():
		it.set_text(i, str(values[i]))
		if i < colors.size() and colors[i] != null:
			it.set_custom_color(i, colors[i])
		it.set_text_alignment(i, t.get_column_title_alignment(i))
	if meta != null:
		it.set_metadata(0, meta)
	_zebra_item(t, it)
	if int(t.get_meta("sort_col", -1)) >= 0 and not t.has_meta("resort_due"):
		t.set_meta("resort_due", true)
		if_alive(t, func(tt: Tree): _resort(tt)).call_deferred()
	return it


## Attribute cell with a heat map. known: 2 exact, 1 range, 0 unknown.
static func attr_cell(it: TreeItem, col: int, value: float, known: int = 2, range_text: String = "") -> void:
	it.set_text_alignment(col, HORIZONTAL_ALIGNMENT_CENTER)
	if known < 2:
		it.set_text(col, range_text if (known == 1 and range_text != "") else "?")
		it.set_custom_color(col, ThemeBuilder.INK_SOFT)
		it.set_custom_font(col, ThemeBuilder.font("ui_italic"))
		return
	var st := ThemeBuilder.attr_style(value)
	it.set_text(col, str(int(floor(value))))
	it.set_custom_color(col, st["fg"])
	if st["bold"]:
		it.set_custom_font(col, ThemeBuilder.font("table_bold"))
	if st["bg"].a > 0.0:
		it.set_custom_bg_color(col, st["bg"])


## Non-selectable label row (grouping).
static func group_row(t: Tree, s: String) -> TreeItem:
	var it := t.create_item(t.get_root())
	it.custom_minimum_height = 22
	var col := 0
	for i in t.columns:
		if t.is_column_expanding(i):
			col = i
			break
	it.set_text(col, s.to_upper())
	for i in t.columns:
		it.set_selectable(i, false)
		it.set_custom_bg_color(i, ThemeBuilder.DESK)
	it.set_custom_font(col, ThemeBuilder.font("label"))
	it.set_custom_font_size(col, 12)
	it.set_custom_color(col, ThemeBuilder.BRONZE_TEXT)
	it.set_text_alignment(col, HORIZONTAL_ALIGNMENT_LEFT)
	return it


static func _zebra_item(t: Tree, it: TreeItem) -> void:
	var root := t.get_root()
	var i: int = 0 if root.get_first_child() == it else root.get_meta("zebra_n", 0)
	root.set_meta("zebra_n", i + 1 if it.get_metadata(0) != null else i)
	if i % 2 == 1:
		for c in t.columns:
			if it.get_custom_bg_color(c) == Color(0, 0, 0, 0):
				it.set_custom_bg_color(c, ThemeBuilder.ZEBRA)


static func _sort_by(t: Tree, col: int) -> void:
	var prev: int = t.get_meta("sort_col", -1)
	var desc: bool = t.get_meta("sort_desc", true)
	desc = (not desc) if prev == col else true
	t.set_meta("sort_col", col)
	t.set_meta("sort_desc", desc)
	_apply_sort(t, col, desc)


static func _resort(t: Tree) -> void:
	t.remove_meta("resort_due")
	var col: int = t.get_meta("sort_col", -1)
	if col >= 0 and col < t.columns and t.get_root() != null:
		_apply_sort(t, col, bool(t.get_meta("sort_desc", true)))


static func _apply_sort(t: Tree, col: int, desc: bool) -> void:
	var rows := []
	var cur := t.get_root().get_first_child()
	while cur != null:
		var nxt := cur.get_next()
		if cur.get_metadata(0) != null:
			rows.append(cur)
		else:
			cur.free()
		cur = nxt
	# Equal keys keep the order the rows had (Godot's sort is not stable): sorting the inbox by sender leaves each
	# sender's owls by date.
	var order := {}
	for i in rows.size():
		order[rows[i]] = i
	rows.sort_custom(func(a: TreeItem, b: TreeItem):
		var ka: Dictionary = a.get_meta("sort_keys", {})
		var kb: Dictionary = b.get_meta("sort_keys", {})
		if ka.has(col) and kb.has(col) and float(ka[col]) != float(kb[col]):
			return float(ka[col]) > float(kb[col]) if desc else float(ka[col]) < float(kb[col])
		var sa := a.get_text(col)
		var sb := b.get_text(col)
		var na := _num(sa)
		var nb := _num(sb)
		if not is_nan(na) and not is_nan(nb):
			if na != nb:
				return na > nb if desc else na < nb
		else:
			var cmp := sa.naturalnocasecmp_to(sb)
			if cmp != 0:
				return cmp > 0 if desc else cmp < 0
		return int(order[a]) < int(order[b]))
	for i in rows.size():
		var r: TreeItem = rows[i]
		if i > 0:
			r.move_after(rows[i - 1])
		for c in t.columns:
			var bg := r.get_custom_bg_color(c)
			if bg == ThemeBuilder.ZEBRA or bg == Color(0, 0, 0, 0):
				if i % 2 == 1:
					r.set_custom_bg_color(c, ThemeBuilder.ZEBRA)
				else:
					r.clear_custom_bg_color(c)
	if not rows.is_empty():
		rows[0].move_before(t.get_root().get_first_child())
	t.get_root().set_meta("zebra_n", rows.size())
	for i in t.columns:
		var base := str(t.get_meta("columns")[i].get("title", "")).to_upper()
		t.set_column_title(i, base + (("  ▼" if desc else "  ▲") if i == col else ""))


static var _re_thousands: RegEx = null
static var _re_duration: RegEx = null


static func _num(s: String) -> float:
	var clean := s.strip_edges()
	if clean != "" and clean.replace("★", "").replace("☆", "") == "":
		return float(clean.count("★"))
	if _re_thousands == null:
		_re_thousands = RegEx.create_from_string("(?<=\\d)[.,\u00a0\u202f ](?=\\d{3}(?!\\d))")
		_re_duration = RegEx.create_from_string("^(\\d+)h\\s*(\\d+)")
	clean = _re_thousands.sub(clean, "", true)
	clean = clean.replace("G", "").replace("%", "").replace("'", "").strip_edges()
	var dm := _re_duration.search(clean)
	if dm != null:
		return float(int(dm.get_string(1)) * 60 + int(dm.get_string(2)))
	clean = clean.replace(",", ".")
	if clean.is_valid_float() or clean.is_valid_int():
		return float(clean)
	if clean.length() > 0 and (clean[0] >= "0" and clean[0] <= "9"):
		var num := ""
		for ch in clean:
			if (ch >= "0" and ch <= "9") or ch == ".":
				num += ch
			else:
				break
		if num.is_valid_float():
			return float(num)
	return NAN


## Semantic progress bar with a number.
static func bar(value: float, width: int = 90, with_number: bool = true, color: Variant = null) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var pb := ProgressBar.new()
	pb.min_value = 0
	pb.max_value = 100
	pb.value = value
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(width, 8)
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.add_theme_stylebox_override("fill", ThemeBuilder.flat(color if color != null else ThemeBuilder.bar_color(value), Color.TRANSPARENT, 0, 2, 0))
	h.add_child(pb)
	if with_number:
		var l := text("TableText", str(int(value)))
		l.custom_minimum_size = Vector2(28, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(l)
	return h


## Drawn segments (broom: 0-5).
static func segments(n: int, total: int = 5, color: Color = ThemeBuilder.BRONZE_TEXT) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	for i in total:
		var c := PanelContainer.new()
		c.custom_minimum_size = Vector2(12, 8)
		c.add_theme_stylebox_override("panel", ThemeBuilder.flat(color if i < n else ThemeBuilder.BORDER, Color.TRANSPARENT, 0, 1, 0))
		h.add_child(c)
	return h


## Drawn stars (0-5): golden circles, no reliance on glyphs.
static func stars(n: int, total: int = 5) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	for i in total:
		var c := PanelContainer.new()
		c.custom_minimum_size = Vector2(12, 12)
		c.add_theme_stylebox_override("panel", ThemeBuilder.flat(ThemeBuilder.GOLD if i < n else ThemeBuilder.BORDER, ThemeBuilder.BRONZE_TEXT if i < n else Color.TRANSPARENT, 1, 6, 0))
		h.add_child(c)
	return h


## Form: five small squares (win green, draw amber, loss sealing-wax red; grey if no data).
static func form_boxes(results: Array) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	for i in 5:
		var c := PanelContainer.new()
		c.custom_minimum_size = Vector2(10, 10)
		var col := ThemeBuilder.BORDER
		if i < results.size():
			var r = results[i]
			if r is String:
				col = ThemeBuilder.GREEN if r == "w" else (ThemeBuilder.AMBER if r == "d" else ThemeBuilder.SEALING_WAX)
			else:
				var v := float(r)
				col = ThemeBuilder.GREEN if v >= 7.0 else (ThemeBuilder.AMBER if v >= 5.5 else ThemeBuilder.SEALING_WAX)
		c.add_theme_stylebox_override("panel", ThemeBuilder.flat(col, Color.TRANSPARENT, 0, 2, 0))
		h.add_child(c)
	return h


## Badge: small pill (position, status).
static func badge(s: String, fill: Color, text_color: Color = ThemeBuilder.INK, outline: bool = false) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", ThemeBuilder.flat(Color.TRANSPARENT if outline else fill, fill if outline else Color.TRANSPARENT, 1 if outline else 0, 9, 0))
	p.custom_minimum_size = Vector2(0, 18)
	var l := label(s, "label", 12, fill if outline else text_color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 7)
	m.add_theme_constant_override("margin_right", 7)
	m.add_child(l)
	p.add_child(m)
	return p


static func attr_text(v: float) -> String:
	return str(int(floor(v)))


static func form_dots(form: Array) -> String:
	var s := ""
	for f in form:
		var v := float(f)
		s += "●" if v >= 7.0 else ("◐" if v >= 5.5 else "○")
	return s


static func form_dots_from_results(results: Array) -> String:
	var s := ""
	for r in results:
		s += "●" if r == "w" else ("◐" if r == "d" else "○")
	return s


static func condition_text(c: float) -> String:
	return "%d%%" % int(c)


static func morale_key(m: float) -> String:
	if m >= 85.0:
		return "ui.morale.superb"
	if m >= 70.0:
		return "ui.morale.good"
	if m >= 55.0:
		return "ui.morale.ok"
	if m >= 40.0:
		return "ui.morale.low"
	if m >= 25.0:
		return "ui.morale.poor"
	return "ui.morale.awful"


## Rich text with links made by Say.link: a click opens the player, club or national-team page; the link
## under the mouse is underlined (hyperlink look, like table links) and the cursor becomes a hand.
static func rich_links(bbcode: String) -> RichTextLabel:
	var r := rich(bbcode)
	r.meta_underlined = false
	r.meta_clicked.connect(func(meta):
		var m := str(meta)
		var sep := m.find(":")
		if sep < 0 or not router.is_valid():
			return
		var kind := m.left(sep)
		var id := m.substr(sep + 1)
		if kind == "player":
			router.call("player", {"player_id": id})
		elif kind == "club":
			router.call("club", {"club_id": id})
		elif kind == "nt":
			router.call("national", {"nt_id": id})
	)
	r.meta_hover_started.connect(func(meta):
		r.set_meta("hover_link", str(meta))
		var open := "[url=%s]" % str(meta)
		var parts := bbcode.split(open)
		var t := parts[0]
		for i in range(1, parts.size()):
			var close := parts[i].find("[/url]")
			t += open + "[u]" + parts[i].left(close) + "[/u]" + parts[i].substr(close)
		r.text = t)
	r.meta_hover_ended.connect(func(_meta):
		r.set_meta("hover_link", "")
		r.text = bbcode)
	r.gui_input.connect(func(ev: InputEvent):
		var hl := str(r.get_meta("hover_link", ""))
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT and hl.begins_with("player:") and player_menu.is_valid():
			player_menu.call(hl.substr(7)))
	return r


## rich_links in a given font, size and colour (headings and headlines that must look like their Label version).
static func rich_links_styled(bbcode: String, font_name: String, size: int, color: Color = ThemeBuilder.INK) -> RichTextLabel:
	var r := rich_links(bbcode)
	r.add_theme_font_override("normal_font", ThemeBuilder.font(font_name))
	r.add_theme_font_size_override("normal_font_size", int(round(size * Settings.text_scale)))
	r.add_theme_color_override("default_color", color)
	return r


static func rich(s: String = "") -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.text = s
	return r


## Room kept to the right of a scroll()'s content for its vertical scrollbar.
const SCROLL_GUTTER := 14


static func scroll(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var gutter := MarginContainer.new()
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.size_flags_vertical = child.size_flags_vertical
	gutter.mouse_filter = Control.MOUSE_FILTER_PASS
	gutter.add_theme_constant_override("margin_right", SCROLL_GUTTER)
	gutter.add_child(child)
	s.add_child(gutter)
	return s


## Option list sized to its longest item and at least `min_width` wide (so a short list still fills its slot).
static func option(items: Array, selected_id: Variant, cb: Callable, min_width: float = 0.0) -> OptionButton:
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(0, 32)
	var sel := -1
	for i in items.size():
		if items[i][0] == null:
			o.add_separator(str(items[i][1]))
			continue
		var idx := o.item_count
		o.add_item(str(items[i][1]), idx)
		o.set_item_metadata(idx, items[i][0])
		if sel < 0 and items[i][0] == selected_id:
			sel = idx
	if sel < 0:
		for i in o.item_count:
			if not o.is_item_separator(i):
				sel = i
				break
	o.select(maxi(sel, 0))
	o.item_selected.connect(func(idx): cb.call(o.get_item_metadata(idx)))
	var longest := 0.0
	var f := ThemeBuilder.font("ui")
	var fs := int(round(15 * Settings.text_scale))
	for i in o.item_count:
		longest = maxf(longest, f.get_string_size(o.get_item_text(i), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	o.custom_minimum_size.x = maxf(maxf(o.custom_minimum_size.x, ceilf(longest) + 52.0), min_width)
	return o


## Group of a competition for the grouped pickers (Competitions, History): "domestic" (leagues, national cups,
## pre-season friendlies), "continental", "international" (World Cup, national-team friendlies) or "schools". Works
## from the id alone, since History keeps the ids of competitions that no longer exist.
static func competition_group(comp_id: String) -> String:
	if comp_id.begins_with("comp_school_") or comp_id.begins_with("comp_house_world"):
		return "schools"
	if comp_id.begins_with("comp_world_cup") or comp_id.begins_with("comp_nt_friendlies"):
		return "international"
	if comp_id.begins_with("comp_european_cup") or comp_id.begins_with("comp_cont_"):
		return "continental"
	return "domestic"


## Slider for a setting of the game (training, tactics): moving it marks the game unsaved (Game.mark_dirty) unless
## `dirties` is false (app preferences such as the volume).
static func slider(value: float, cb: Callable, min_v: float = 1.0, max_v: float = 20.0, dirties: bool = true) -> HSlider:
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = 1.0
	s.value = value
	s.custom_minimum_size = Vector2(140, 20)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.scrollable = false
	s.value_changed.connect(cb)
	if dirties:
		s.value_changed.connect(func(_v: float): Game.mark_dirty())
	return s


static func slider_word(v: float, low: String, mid: String, high: String) -> String:
	if v <= 6.0:
		return low
	if v >= 15.0:
		return high
	return mid


## Segmented tabs: calls cb(index).
static func tabs(names: Array, selected: int, cb: Callable) -> TabBar:
	var tb := TabBar.new()
	tb.clip_tabs = false
	for n in names:
		tb.add_tab(str(n))
	tb.current_tab = selected
	tb.tab_changed.connect(cb)
	return tb


## Confirmation dialog with "Cancel" on the right (Godot on macOS puts it on the left).
static func cancel_right(dlg: ConfirmationDialog) -> void:
	var ok := dlg.get_ok_button()
	var cancel := dlg.get_cancel_button()
	var box := ok.get_parent()
	if box == null or cancel.get_parent() != box:
		return
	var i_ok := ok.get_index()
	var i_cancel := cancel.get_index()
	if i_cancel < i_ok:
		box.move_child(cancel, i_ok)
		box.move_child(ok, i_cancel)


## A callable that runs `fn(obj)` (or `fn(obj, arg)` when the caller passes one) only while `obj` still exists, for
## work that runs later: a deferred call, a save confirmation. A lambda whose captured object was freed errors when
## called, so the object travels through a weak reference instead of a capture.
static func if_alive(obj: Object, fn: Callable) -> Callable:
	var ref: WeakRef = weakref(obj)
	return func(arg = null):
		var o: Object = ref.get_ref()
		if o == null:
			return
		if fn.get_argument_count() > 1:
			fn.call(o, arg)
		else:
			fn.call(o)


static func pos_short(pos: String) -> String:
	var k := "pos.short." + pos
	var s := str(TranslationServer.translate(k))
	return pos if s == k else s


## An untranslated key comes back as itself, one element, so a locale without the standalone list falls back to `ui.months`.
static func month_names() -> PackedStringArray:
	var months := Game.t("ui.months_standalone").split(",")
	if months.size() < 12:
		months = Game.t("ui.months").split(",")
	return months
