extends Control
## Main frame: wooden top bar with a club-colour stripe, grouped side menu with icons,
## footer with the next match, primary Continue button with a shortcut, toasts.

const SCREENS := {
	"new_game": "res://src/ui/screens/new_game_screen.gd",
	"inbox": "res://src/ui/screens/inbox_screen.gd",
	"squad": "res://src/ui/screens/squad_screen.gd",
	"player": "res://src/ui/screens/player_screen.gd",
	"lineup": "res://src/ui/screens/lineup_screen.gd",
	"match": "res://src/ui/screens/match_screen.gd",
	"table": "res://src/ui/screens/table_screen.gd",
	"calendar": "res://src/ui/screens/calendar_screen.gd",
	"training": "res://src/ui/screens/training_screen.gd",
	"market": "res://src/ui/screens/market_screen.gd",
	"finances": "res://src/ui/screens/finances_screen.gd",
	"board": "res://src/ui/screens/board_screen.gd",
	"manager": "res://src/ui/screens/manager_screen.gd",
	"compare": "res://src/ui/screens/compare_screen.gd",
	"staff": "res://src/ui/screens/staff_screen.gd",
	"news": "res://src/ui/screens/news_screen.gd",
	"club": "res://src/ui/screens/club_screen.gd",
	"history": "res://src/ui/screens/history_screen.gd",
	"saves": "res://src/ui/screens/saves_screen.gd",
	"competitions": "res://src/ui/screens/competitions_screen.gd",
	"scouting": "res://src/ui/screens/scouting_screen.gd",
	"schools": "res://src/ui/screens/schools_screen.gd",
	"settings": "res://src/ui/screens/settings_screen.gd",
	"encyclopedia": "res://src/ui/screens/encyclopedia_screen.gd",
	"national": "res://src/ui/screens/national_screen.gd",
	"national_tactics": "res://src/ui/screens/lineup_screen.gd",
	"crests_debug": "res://src/ui/screens/crests_debug_screen.gd",
	"faces_debug": "res://src/ui/screens/faces_debug_screen.gd",
	"post_match": "res://src/ui/screens/post_match_screen.gd",
	"press": "res://src/ui/screens/press_screen.gd",
	"title": "res://src/ui/screens/title_screen.gd",
	"players": "res://src/ui/screens/players_screen.gd",
	"national_teams": "res://src/ui/screens/national_teams_screen.gd",
}

## Menu groups: [label, [[id, key, icon], ...]]
const MENU := [
	["ui.menu.group.office", [["inbox", "ui.menu.inbox", "envelope"], ["news", "ui.menu.news", "newspaper"]]],
	["ui.menu.group.team", [["squad", "ui.menu.squad", "users-three"], ["lineup", "ui.menu.lineup", "target"], ["training", "ui.menu.training", "barbell"]]],
	["ui.menu.group.competition", [["table", "ui.menu.table", "list-numbers"], ["calendar", "ui.menu.calendar", "calendar-blank"], ["competitions", "ui.menu.competitions", "trophy"], ["players", "ui.menu.players", "magnifying-glass"], ["national_teams", "ui.menu.national_teams", "flag"], ["national", "ui.menu.national", "flag"]]],
	["ui.menu.group.market", [["market", "ui.menu.market", "arrows-left-right"], ["scouting", "ui.menu.scouting", "binoculars"], ["schools", "ui.menu.schools", "graduation-cap"]]],
	["ui.menu.group.club", [["finances", "ui.menu.finances", "coins"], ["staff", "ui.staff.title", "users-three"], ["board", "ui.menu.board", "bank"], ["manager", "ui.menu.manager", "crown"], ["club", "ui.menu.club", "info"], ["history", "ui.menu.history", "clock-counter-clockwise"], ["encyclopedia", "ui.menu.encyclopedia", "book-open"]]],
]
const UNEMPLOYED_SCREENS := ["inbox", "news", "competitions", "players", "national_teams", "market", "history", "saves", "settings", "encyclopedia", "manager", "national"]
## Screens that belong to a side-menu entry without being one (highlight, breadcrumb and help of that entry).
const MENU_ALIAS := {"national_tactics": "national"}
## Hogwarts mode: no finances, market, scouting or board (a house does not sign players or pay wages).
const SCHOOL_HIDDEN := ["market", "scouting", "finances", "board", "club", "staff", "manager"]

var top_bar: PanelContainer
var club_line: HBoxContainer
var crest_slot: HBoxContainer
var club_label: Label
var crumb_label: Label
var date_label: Label
var balance_label: Label
var save_btn: Button
var owl_btn: Button
var holiday_btn: Button
var help_btn: Button
var settings_btn: Button
var continue_btn: Button
var back_btn: Button
var fwd_btn: Button
var side: PanelContainer
var side_box: VBoxContainer
var menu_box: VBoxContainer
var next_box: VBoxContainer
var content: MarginContainer
var toast_box: VBoxContainer
var current: UIScreen = null
var current_id: String = ""
var history: Array = []
var hist_pos: int = -1
var _menu_buttons: Dictionary = {}
var _screen_world := 0
var _known_world := 0
var _unsaved := false:
	set(v):
		if v != _unsaved:
			Platform.set_leave_guard(v)
		_unsaved = v
var _change_gen := 0
## The world the last world_changed announced. A signal for another instance is a load or a new game, not a change to
## save; it may reach us before or after go() has built the first screen for it (a loader thread emits deferred).
var _announced_world := 0


var loading: LoadingOverlay
var busy := false
## An action picked in the right-click player menu, run by the player screen once it opens ({player_id, key}).
var pending_player_action := {}


## Runs `work` on a thread behind the animated loading overlay (creating or loading a save, finishing a match);
## returns whatever `work` returns. The screen stays blocked meanwhile.
func run_blocking(text: String, work: Callable) -> Variant:
	busy = true
	if not Platform.has_threads():
		# Web: no threads, so the work freezes the game's drawing until it ends. The page shows its own animated
		# card instead (Platform.show_busy: CSS keeps moving on the browser's compositor); the frames below let the
		# browser paint it before the work starts.
		Platform.show_busy(text)
		for i in 3:
			await get_tree().process_frame
		var direct = work.call()
		Platform.hide_busy()
		busy = false
		return direct
	loading.begin(text)
	await get_tree().process_frame
	await get_tree().process_frame
	var th := Thread.new()
	th.start(work)
	while th.is_alive():
		await get_tree().process_frame
	var res = th.wait_to_finish()
	loading.end()
	busy = false
	return res


func _debug_injure() -> void:
	var me := Game.my_club()
	var p: Player = Game.world.player(str(me.lineup.get("K", "")))
	if p != null:
		p.injury_days = 20
	_refresh_bars()


func _debug_holiday() -> void:
	await _go_on_holiday(45)


func _debug_loading() -> void:
	loading.begin(tr("ui.loading.advancing"))
	loading.set_detail(Game.date_text(Game.world.today) if Game.has_game() else "")


func _ready() -> void:
	loading = LoadingOverlay.new()
	add_child(loading)
	# A bound method, not a lambda: Godot 4.7.2 on macOS aborts at exit when a GDScript lambda is still held in a
	# static var (recursive_mutex lock failed, exit 134).
	UI.router = go
	UI.player_menu = _player_menu
	theme = ThemeBuilder.build()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Sfx.setup(self)
	get_tree().auto_accept_quit = false
	_known_world = _world_id()
	_announced_world = _known_world
	_build()
	Game.world_changed.connect(_on_world_changed)
	Game.dirtied.connect(_on_dirtied)
	get_viewport().size_changed.connect(func(): _fit_menu.call_deferred())
	if Game.has_game():
		go("inbox")
	else:
		go("title")
	_handle_cmdline()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = ThemeBuilder.WOOD
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 0)
	add_child(v)

	top_bar = PanelContainer.new()
	top_bar.add_theme_stylebox_override("panel", ThemeBuilder.flat(ThemeBuilder.WOOD_MID, Color.TRANSPARENT, 0, 0, 6))
	top_bar.custom_minimum_size = Vector2(0, 44)
	var tb := UI.hbox(8)
	back_btn = UI.icon_button("caret-left", _back, tr("ui.back"))
	fwd_btn = UI.icon_button("caret-right", _forward, "")
	tb.add_child(back_btn)
	tb.add_child(fwd_btn)
	crest_slot = HBoxContainer.new()
	tb.add_child(crest_slot)
	club_label = UI.label("", "title", 22, ThemeBuilder.MENU_TEXT)
	tb.add_child(club_label)
	crumb_label = UI.label("", "ui", 14, ThemeBuilder.MENU_FADED)
	tb.add_child(crumb_label)
	tb.add_child(UI.spacer())
	date_label = UI.label("", "ui_medium", 15, ThemeBuilder.MENU_TEXT)
	tb.add_child(date_label)
	balance_label = UI.label("", "table_bold", 15, ThemeBuilder.BRASS)
	tb.add_child(balance_label)
	save_btn = UI.icon_button("floppy-disk", open_save_dialog, tr("ui.menu.saves"))
	tb.add_child(save_btn)
	owl_btn = UI.icon_button("envelope", func(): go("inbox"), tr("ui.menu.inbox"))
	tb.add_child(owl_btn)
	holiday_btn = UI.icon_button("calendar-blank", _holiday_dialog, tr("ui.holiday.title"))
	tb.add_child(holiday_btn)
	help_btn = UI.icon_button("info", _show_help, tr("ui.help.button"))
	tb.add_child(help_btn)
	settings_btn = UI.icon_button("gear-six", func(): go("settings"), tr("ui.menu.settings"))
	tb.add_child(settings_btn)
	continue_btn = UI.button(tr("ui.continue"), _continue, true)
	continue_btn.custom_minimum_size = Vector2(170, 32)
	continue_btn.tooltip_text = tr("ui.continue_hint")
	continue_btn.focus_mode = Control.FOCUS_NONE
	tb.add_child(continue_btn)
	top_bar.add_child(tb)
	v.add_child(top_bar)
	club_line = HBoxContainer.new()
	club_line.add_theme_constant_override("separation", 0)
	club_line.custom_minimum_size = Vector2(0, 3)
	v.add_child(club_line)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	v.add_child(body)

	side = UI.wood_panel(8)
	side.custom_minimum_size = Vector2(200, 0)
	side_box = UI.vbox(4)
	side_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_box = UI.vbox(2)
	var msc := ScrollContainer.new()
	msc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	msc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	msc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	msc.add_child(menu_box)
	side_box.add_child(msc)
	next_box = UI.vbox(2)
	side_box.add_child(next_box)
	side.add_child(side_box)
	body.add_child(side)

	var mesa := PanelContainer.new()
	mesa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mesa.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mesa.add_theme_stylebox_override("panel", ThemeBuilder.mesa())
	mesa.clip_contents = true
	content = MarginContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		content.add_theme_constant_override(m, 16)
	mesa.add_child(content)
	body.add_child(mesa)

	toast_box = UI.vbox(6)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	toast_box.position = Vector2(size.x - 380, 56)
	toast_box.custom_minimum_size = Vector2(360, 0)
	add_child(toast_box)
	_rebuild_menu()


func _rebuild_menu() -> void:
	for c in menu_box.get_children():
		menu_box.remove_child(c)
		c.queue_free()
	_menu_buttons.clear()
	for c in next_box.get_children():
		next_box.remove_child(c)
		c.queue_free()
	side.visible = _in_game_screen() and current_id != "match"
	if not _in_game_screen():
		return
	var unemployed := Game.my_club() == null
	var unread := Inbox.unread_count(Game.world)
	var school := Game.world.is_school_mode()
	for group in MENU:
		var any := false
		for entry in group[1]:
			if (not unemployed or UNEMPLOYED_SCREENS.has(entry[0])) and not (school and SCHOOL_HIDDEN.has(entry[0])):
				any = true
		if not any:
			continue
		var rm := MarginContainer.new()
		rm.add_theme_constant_override("margin_top", 5)
		rm.add_theme_constant_override("margin_left", 8)
		var gname: String = tr(str(group[0]))
		if school and str(group[0]) == "ui.menu.group.market":
			gname = tr("ui.menu.schools")
		rm.add_child(UI.text("MenuCaption", gname))
		menu_box.add_child(rm)
		for entry in group[1]:
			if unemployed and not UNEMPLOYED_SCREENS.has(entry[0]):
				continue
			if school and SCHOOL_HIDDEN.has(entry[0]):
				continue
			if entry[0] == "national" and str(Game.world.manager.get("national_team_id", "")) == "":
				continue
			var b := Button.new()
			b.theme_type_variation = "WoodMenu"
			b.text = tr(str(entry[1])) + ((" (%d)" % unread) if (entry[0] == "inbox" and unread > 0) else "")
			b.icon = ThemeBuilder.icon(str(entry[2]))
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 16)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.focus_mode = Control.FOCUS_NONE
			var sid: String = str(entry[0])
			if sid == "national":
				b.pressed.connect(func(): go("national", {"nt_id": str(Game.world.manager.get("national_team_id", ""))}))
			elif sid == "saves":
				b.pressed.connect(open_save_dialog)
			else:
				b.pressed.connect(func(): go(sid))
			menu_box.add_child(b)
			_menu_buttons[sid] = b
	_highlight_menu()
	_fit_menu.call_deferred()
	var club := Game.my_club()
	if club == null:
		next_box.add_child(UI.text("MenuCaption", tr("ui.unemployed")))
		var ul := UI.label(tr("ui.unemployed_note"), "ui", 13, ThemeBuilder.MENU_TEXT)
		ul.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		next_box.add_child(ul)
		return
	var f := _next_fixture(club)
	next_box.add_child(UI.text("MenuCaption", tr("ui.next_match_label")))
	if Game.engine.pending_match != null:
		next_box.add_child(UI.label(tr("ui.match_in_progress"), "ui_medium", 14, ThemeBuilder.BRASS))
	elif f.is_empty():
		next_box.add_child(UI.label(tr("ui.no_match"), "ui", 14, ThemeBuilder.MENU_TEXT))
	else:
		var rival: String = str(f["away_id"]) if str(f["home_id"]) == club.id else str(f["home_id"])
		var h := UI.hbox(6)
		var rc: Club = Game.world.club(rival)
		if rc != null:
			h.add_child(UI.club_stripe(rc, 16))
		var nl := UI.label(Game.world.team_name(rival), "ui_medium", 14, ThemeBuilder.MENU_TEXT)
		nl.clip_text = true
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nl)
		next_box.add_child(h)
		next_box.add_child(UI.label(Game.date_text(int(f["day"])), "ui", 13, ThemeBuilder.MENU_FADED))
		next_box.add_child(UI.label(Game.venue_text(f), "ui", 13, ThemeBuilder.MENU_FADED))


func _fit_menu() -> void:
	if not side.visible or menu_box.get_child_count() == 0:
		return
	await get_tree().process_frame
	var avail: float = side_box.size.y - next_box.get_combined_minimum_size().y - side_box.get_theme_constant("separation") - 4.0
	var k := 1.0
	while k >= 0.6:
		_scale_menu(k)
		if menu_box.get_combined_minimum_size().y <= avail:
			return
		k -= 0.05


func _scale_menu(k: float) -> void:
	var base: int = ThemeBuilder.build_font_size("WoodMenu")
	for c in menu_box.get_children():
		if c is Button:
			c.add_theme_font_size_override("font_size", maxi(9, int(round(base * k))))
			c.add_theme_constant_override("icon_max_width", maxi(10, int(round(16 * k))))
		elif c is MarginContainer:
			c.add_theme_constant_override("margin_top", int(round(5 * k)))
			for lbl in c.get_children():
				if lbl is Label:
					lbl.add_theme_font_size_override("font_size", maxi(8, int(round(12 * minf(Settings.text_scale, 1.15) * k))))


func _next_fixture(club: Club) -> Dictionary:
	var f := Game.league().next_fixture_of(club.id, Game.world.today) if Game.league() != null else {}
	for cup in Game.world.competitions.values():
		if ["cup", "friendly", "national_cup", "cont_groups", "cont_knockout", "house_world"].has(cup.type) and cup.has_team(club.id):
			var cf: Dictionary = cup.next_fixture_of(club.id, Game.world.today)
			if not cf.is_empty() and (f.is_empty() or int(cf["day"]) < int(f["day"])):
				f = cf
	return f


func _menu_id() -> String:
	return str(MENU_ALIAS.get(current_id, current_id))


func _highlight_menu() -> void:
	for sid in _menu_buttons.keys():
		var b: Button = _menu_buttons[sid]
		if sid == _menu_id():
			var sb := ThemeBuilder.flat(ThemeBuilder.WOOD_SEL, ThemeBuilder.BRASS, 0, 4, 8)
			sb.border_width_left = 3
			sb.content_margin_top = 3
			sb.content_margin_bottom = 3
			sb.content_margin_left = 10
			sb.content_margin_right = 8
			b.add_theme_stylebox_override("normal", sb)
			b.add_theme_stylebox_override("hover", sb)
			b.add_theme_font_override("font", ThemeBuilder.font("ui_bold"))
		else:
			b.remove_theme_stylebox_override("normal")
			b.remove_theme_stylebox_override("hover")
			b.remove_theme_font_override("font")


func go(screen_id: String, p: Dictionary = {}, record: bool = true) -> void:
	if busy:
		return
	if _match_locked() and screen_id != "match" and screen_id != "post_match":
		toast(tr("ui.match.locked"), "info", "info")
		return
	if not SCREENS.has(screen_id):
		push_error("unknown screen: " + screen_id)
		return
	var script: GDScript = load(SCREENS[screen_id])
	if script == null:
		push_error("screen script not found: " + str(SCREENS[screen_id]))
		return
	if record:
		_remember_state()
	if Game.engine != null:
		Game.engine.settle_owls()
	if current != null:
		content.remove_child(current)
		current.queue_free()
	_check_world()
	current = script.new()
	current_id = screen_id
	_screen_world = _world_id()
	content.add_child(current)
	current.setup(self, p)
	Sfx.music(screen_id != "match")
	Sfx.ambient(screen_id == "match")
	if record:
		history = history.slice(0, hist_pos + 1)
		history.append({"id": screen_id, "params": p})
		hist_pos = history.size() - 1
	_rebuild_menu()
	_refresh_bars()
	_update_nav_buttons()


func _update_nav_buttons() -> void:
	back_btn.disabled = hist_pos <= 0 or _match_locked()
	fwd_btn.disabled = hist_pos >= history.size() - 1 or _match_locked()


func _world_id() -> int:
	return Game.world.get_instance_id() if Game.world != null else 0


func _check_world() -> void:
	var wid := _world_id()
	if wid == _known_world:
		return
	_known_world = wid
	history.clear()
	hist_pos = -1
	_unsaved = false
	_change_gen += 1
	_update_nav_buttons()


func _match_locked() -> bool:
	return current_id == "match" and current != null and current.get("sim") != null and not bool(current.get("finished"))


func refresh_current() -> void:
	if Game.engine != null:
		Game.engine.settle_owls()
	if current != null and (_world_id() == _screen_world or PRE_GAME_SCREENS.has(current_id)):
		current.refresh()
	_refresh_bars()
	_rebuild_menu()


func _player_menu(player_id: String) -> void:
	if busy or Game.world == null or Game.world.player(player_id) == null:
		return
	# Opened on the press, the release would land on the menu: wait for it first.
	while Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		await get_tree().process_frame
	var old := get_node_or_null("PlayerMenu")
	if old != null:
		old.queue_free()
	var pm := PopupMenu.new()
	pm.name = "PlayerMenu"
	var actions: Array = PlayerScreenActions.for_player(player_id)
	pm.add_item(tr("ui.view_profile"), 0)
	if not actions.is_empty():
		pm.add_separator(tr("ui.actions"))
		for i in actions.size():
			pm.add_item(str(actions[i][1]), i + 1)
	pm.id_pressed.connect(func(id: int):
		if id > 0:
			pending_player_action = {"player_id": player_id, "key": str(actions[id - 1][0])}
		go("player", {"player_id": player_id}))
	pm.popup_hide.connect(pm.queue_free)
	add_child(pm)
	var at := Vector2i(get_viewport().get_mouse_position())
	await get_tree().process_frame
	if is_instance_valid(pm):
		pm.popup(Rect2i(at, Vector2i.ZERO))


func _remember_state() -> void:
	if current == null or hist_pos < 0 or hist_pos >= history.size() or str(history[hist_pos]["id"]) != current_id:
		return
	var state: Dictionary = current.nav_state() if current is UIScreen else {}
	if current_id == "inbox":
		var sel = current.get("selected_id")
		if sel != null and int(sel) >= 0:
			state["selected"] = int(sel)
	if state.is_empty():
		return
	var hp: Dictionary = history[hist_pos]["params"].duplicate()
	hp.merge(state, true)
	history[hist_pos]["params"] = hp


func _back() -> void:
	if busy:
		return
	if hist_pos > 0:
		_remember_state()
		hist_pos -= 1
		var h: Dictionary = history[hist_pos]
		go(h["id"], h["params"], false)


func _forward() -> void:
	if busy:
		return
	if hist_pos < history.size() - 1:
		_remember_state()
		hist_pos += 1
		var h: Dictionary = history[hist_pos]
		go(h["id"], h["params"], false)


const PRE_GAME_SCREENS := ["title", "new_game"]


func _in_game_screen() -> bool:
	return Game.has_game() and not PRE_GAME_SCREENS.has(current_id)


func _refresh_bars() -> void:
	for c in crest_slot.get_children():
		crest_slot.remove_child(c)
		c.queue_free()
	for c in club_line.get_children():
		club_line.remove_child(c)
		c.queue_free()
	if not _in_game_screen():
		club_label.text = tr("ui.app_title")
		crumb_label.text = ""
		date_label.text = ""
		balance_label.text = ""
		continue_btn.visible = false
		owl_btn.visible = false
		save_btn.visible = false
		holiday_btn.visible = false
		_line_colors(ThemeBuilder.BRASS, ThemeBuilder.BRASS)
		return
	var club := Game.my_club()
	continue_btn.visible = true
	owl_btn.visible = true
	holiday_btn.visible = true
	holiday_btn.disabled = _match_locked()
	save_btn.visible = true
	date_label.text = Game.date_text(Game.world.today)
	var crumb := ""
	for group in MENU:
		for entry in group[1]:
			if entry[0] == _menu_id():
				crumb = "· " + tr(str(entry[1]))
	crumb_label.text = crumb
	if club == null:
		club_label.text = tr("ui.unemployed")
		balance_label.text = ""
		_line_colors(ThemeBuilder.BRASS, ThemeBuilder.BRASS)
	else:
		club_label.text = club.name
		balance_label.text = "" if Game.world.is_school_mode() else Game.galleons(club.balance)
		crest_slot.add_child(UI.crest(club, 28))
		_line_colors(ThemeBuilder.hex(str(club.colors.get("primary", "#888"))), ThemeBuilder.hex(str(club.colors.get("secondary", "#ddd"))))
	var pend := Inbox.blocking_count(Game.world)
	continue_btn.disabled = _match_locked()
	owl_btn.disabled = _match_locked()
	save_btn.disabled = _match_locked()
	if Game.engine.pending_match != null:
		continue_btn.text = tr("ui.go_to_match") if current_id != "match" else (tr("ui.match.finish_short") if not _match_locked() else tr("ui.match.in_progress"))
	elif not Game.engine.human_fixture_today().is_empty():
		var tf: Dictionary = Game.engine.human_fixture_today()["fixture"]
		var rival: String = str(tf["away_id"]) if str(tf["home_id"]) == club.id else str(tf["home_id"])
		continue_btn.text = (tr("ui.continue_to_match") % Game.world.team_short(rival)) if not Game.engine.lineup_blocked() else tr("ui.fix_lineup")
	elif pend > 0:
		continue_btn.text = Game.tn("ui.answer_messages_n", pend)
	else:
		var nf := _next_fixture(club) if club != null else {}
		if not nf.is_empty() and int(nf["day"]) - Game.world.today <= CONTINUE_DAYS:
			var rv: String = str(nf["away_id"]) if str(nf["home_id"]) == club.id else str(nf["home_id"])
			continue_btn.text = tr("ui.continue_to_match") % Game.world.team_short(rv)
		else:
			continue_btn.text = tr("ui.continue")


func _line_colors(a: Color, b: Color) -> void:
	for col in [a, b]:
		var r := ColorRect.new()
		r.color = col
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.custom_minimum_size = Vector2(0, 3)
		club_line.add_child(r)


## Days each "Continue" advances (it stops earlier for a match or an urgent owl).
const CONTINUE_DAYS := 3
## Milliseconds of world work per frame while advancing (GameEngine.step_day): long enough to get through a day
## in a few frames, short enough for the loading overlay to keep animating at 60 fps.
const STEP_BUDGET_MS := 12


func _go_to_match() -> void:
	var fid := str(Game.engine.pending_match.fixture.get("id", "")) if Game.engine.pending_match != null else ""
	var pre: Dictionary = Game.world.settings.get("pre_press", {})
	if fid != "" and str(pre.get("fixture_id", "")) == fid and Inbox.find(Game.world, Inbox.PRE_PRESS, fid) != null:
		go("press", {"pre_fixture": fid, "comp_id": str(pre.get("comp_id", ""))})
		return
	go("match")


func _continue() -> void:
	if not Game.has_game():
		return
	if Game.engine.pending_match != null:
		if current_id == "match" and current.has_method("finish_match"):
			current.finish_match()
		else:
			_go_to_match()
		return
	Game.engine.settle_owls()
	var urgent := Inbox.blocking(Game.world)
	if urgent != null:
		go("inbox", {"selected": urgent.id})
		return
	if busy:
		return
	if not Game.engine.human_fixture_today().is_empty() and Game.engine.lineup_blocked():
		toast(tr("ui.lineup_blocked_toast"), "warning", "warning")
		go("lineup")
		return
	var before := Inbox.open_count(Game.world)
	var first_new := Inbox.newest_id(Game.world) + 1
	busy = true
	loading.begin(tr("ui.loading.advancing"))
	var r := {"stopped": false, "reason": ""}
	for i in CONTINUE_DAYS:
		r = await _advance_day_stepped()
		loading.set_detail(Game.date_text(Game.world.today))
		if r["stopped"]:
			break
		await get_tree().process_frame
	Game.after_advance(r)
	loading.end()
	busy = false
	var waiting := Inbox.open_count(Game.world)
	if waiting > before:
		toast(Game.tn("ui.owls_waiting", waiting))
	if r["reason"] == "match":
		_go_to_match()
	elif r["reason"] == "lineup":
		toast(tr("ui.lineup_blocked_toast"), "warning", "warning")
		go("lineup")
	else:
		go("inbox", _landing(first_new))


func _holiday_dialog() -> void:
	if not Game.has_game() or busy or Game.engine.pending_match != null:
		return
	Game.engine.settle_owls()
	var urgent := Inbox.blocking(Game.world)
	if urgent != null:
		toast(tr("ui.holiday.urgent_first"), "warning", "warning")
		go("inbox", {"selected": urgent.id})
		return
	var dlg := AcceptDialog.new()
	dlg.title = tr("ui.holiday.title")
	dlg.ok_button_text = tr("ui.close")
	var v := UI.vbox(8)
	v.custom_minimum_size = Vector2(380, 0)
	var club := Game.my_club()
	var note := UI.text("Body", tr("ui.holiday.note") if club != null else tr("ui.holiday.note_unemployed"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A wrapped label measures its height at the width it has: given it now, the dialog isn't sized for one word
	# per line (a tall, mostly empty panel).
	note.custom_minimum_size = Vector2(380, 0)
	note.size = Vector2(380, 0)
	v.add_child(note)
	var season_end := WDate.from_ymd(Game.world.season + 1, 6, 30) - Game.world.today
	var opts := [[7, tr("ui.holiday.week")], [14, tr("ui.holiday.two_weeks")], [30, tr("ui.holiday.month")], [maxi(season_end, 1), tr("ui.holiday.season")]]
	var nf := _next_fixture(club) if club != null else {}
	if not nf.is_empty() and int(nf["day"]) - Game.world.today > 1:
		opts.push_front([int(nf["day"]) - Game.world.today - 1, tr("ui.holiday.next_match") % Game.date_text(int(nf["day"]))])
	for opt in opts:
		var days: int = opt[0]
		v.add_child(UI.button(str(opt[1]), func(): dlg.hide(); dlg.queue_free(); _go_on_holiday(days)))
	dlg.add_child(v)
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.reset_size()
	dlg.popup_centered()
	await get_tree().process_frame
	if is_instance_valid(dlg) and dlg.visible:
		dlg.reset_size()
		dlg.position = (Vector2i(get_viewport_rect().size) - dlg.size) / 2


func _go_on_holiday(days: int) -> void:
	busy = true
	loading.begin(tr("ui.holiday.away"))
	var first_new := Inbox.newest_id(Game.world) + 1
	var e := Game.engine
	var w := Game.world
	e.auto_fix_lineup = true
	var played := [0, 0, 0]
	var r := {"stopped": false, "reason": ""}
	var back_early := false
	var was_unemployed := w.manager_unemployed
	for i in days:
		r = await _advance_day_stepped()
		while r["reason"] == "match" or e.pending_match != null:
			var res: MatchResult = e.complete_pending_match()
			if res != null and w.my_club() != null:
				var mine_home := res.home_id == w.player_club_id
				var ms := res.score_home if mine_home else res.score_away
				var ts := res.score_away if mine_home else res.score_home
				if res.home_id == w.player_club_id or res.away_id == w.player_club_id:
					played[0 if ms > ts else (1 if ms == ts else 2)] += 1
			r = {"stopped": false, "reason": ""}
		if r["reason"] == "message" or (w.manager_unemployed and not was_unemployed):
			back_early = true
			break
		loading.set_detail(Game.date_text(w.today))
		Game.autosave()
		if i % 2 == 0:
			await get_tree().process_frame
	e.auto_fix_lineup = false
	Game.after_advance({"stopped": false, "reason": ""})
	loading.end()
	busy = false
	toast(tr("ui.holiday.back") % [played[0], played[1], played[2]] + (" " + tr("ui.holiday.back_early") if back_early else ""), "check-circle", "ok")
	go("inbox", _landing(first_new))


func _advance_day_stepped() -> Dictionary:
	while not Game.engine.advance_day_slice(STEP_BUDGET_MS):
		await get_tree().process_frame
	return Game.engine.day_result()


## Closes the manager's match: the rest of the world's matchday and the end of the day (weekly and monthly work when
## it falls on one), in slices of STEP_BUDGET_MS with the loading overlay animating. The caller decides the next screen.
func finish_match_stepped() -> void:
	busy = true
	loading.begin(tr("ui.loading.finishing"))
	while not Game.engine.complete_pending_match_slice(STEP_BUDGET_MS):
		await get_tree().process_frame
	loading.end()
	busy = false


## The inbox screen after an advance: the first blocking owl, else the newest owl if it arrived during the advance.
func _landing(first_new: int) -> Dictionary:
	var urgent := Inbox.blocking(Game.world)
	if urgent != null:
		return {"selected": urgent.id}
	if Inbox.newest_id(Game.world) >= first_new:
		return {"selected": Inbox.newest_id(Game.world)}
	return {}


## The mouse's side buttons go back and forward through the screens, like the arrows in the top bar. Handled in
## _input so no control under the pointer swallows them first.
func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_XBUTTON1:
		_back()
		get_viewport().set_input_as_handled()
	elif mb.button_index == MOUSE_BUTTON_XBUTTON2:
		_forward()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if busy and k.keycode != KEY_F1:
			get_viewport().set_input_as_handled()
			return
		if k.keycode == KEY_SPACE and Game.has_game() and current_id != "match" and not busy and not (get_viewport().gui_get_focus_owner() is LineEdit):
			_continue()
			get_viewport().set_input_as_handled()
		# Cmd+S too: in the browser on a Mac the player reaches for Cmd, and Ctrl alone would ignore it.
		elif k.keycode == KEY_S and (k.ctrl_pressed or k.meta_pressed) and Game.has_game():
			_quick_save()
			get_viewport().set_input_as_handled()
		elif k.keycode == KEY_F1:
			_show_help()
			get_viewport().set_input_as_handled()
		elif k.keycode == KEY_LEFT and k.alt_pressed:
			_back()
		elif k.keycode == KEY_RIGHT and k.alt_pressed:
			_forward()


## A change to the current world marks it unsaved; another instance is a load or a new game. The screen is refreshed
## unless the shell is busy (the caller navigates when its work ends) or go() already built it for this new world.
func _on_world_changed() -> void:
	var wid := _world_id()
	var replaced := wid != _announced_world
	_announced_world = wid
	_check_world()
	if not replaced and Game.has_game():
		_unsaved = true
		_change_gen += 1
	if Game.has_game():
		if Game.engine != null:
			Game.engine.settle_owls()
		Game.autosave_after_match(busy)
	if busy or (replaced and current != null and _screen_world == wid):
		return
	refresh_current()


func _on_dirtied() -> void:
	if not Game.has_game():
		return
	_unsaved = true
	_change_gen += 1


func _quick_save() -> void:
	if busy or not Game.has_game():
		return
	save_and_confirm()


## Saves the game as `save_as` ("" = the current save) and only says so once it is true. Every way of saving goes
## through here, with one rule: not while a match is being played (the save would hold the pre-match state); the
## player is told instead, or they would believe the game was saved. In the browser the save reaches the disk
## seconds after it is written (Platform.confirm_saved): "Saving…" shows first, and "Game saved." and the end of
## the leave guard wait for it. Returns the result of the write; `on_done(confirmed)` runs only if that was OK.
func save_and_confirm(save_as: String = "", on_done: Callable = Callable()) -> Error:
	if _match_locked():
		toast(tr("ui.save_after_match"), "x-circle", "error")
		return ERR_BUSY
	var err := Game.save_game(save_as)
	if err == ERR_INVALID_PARAMETER:
		toast(tr("ui.saves.bad_name"), "x-circle", "error")
		return err
	if err == ERR_ALREADY_EXISTS:
		toast(tr("ui.saves.other_career"), "x-circle", "error")
		return err
	if err != OK:
		toast(tr("ui.save_failed"), "x-circle", "error")
		return err
	if Platform.is_web():
		toast(tr("ui.saving"), "floppy-disk", "ok")
	var gen := _change_gen
	Platform.confirm_saved(SaveManager.last_saved_dir, SaveManager.last_saved_at, SaveManager.last_save_id, func(ok: bool):
		if ok:
			if gen == _change_gen:
				_unsaved = false
			toast(tr("ui.saved"))
		else:
			toast(tr("ui.save_unconfirmed"), "warning", "warning")
		if on_done.is_valid():
			on_done.call(ok))
	return OK


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST:
		return
	if not Game.has_game() or not _unsaved or busy:
		get_tree().quit()
		return
	_confirm_quit()


func _confirm_quit() -> void:
	if get_node_or_null("QuitDialog") != null:
		return
	var dlg := ConfirmationDialog.new()
	dlg.name = "QuitDialog"
	dlg.title = tr("ui.quit.title")
	dlg.dialog_autowrap = true
	dlg.min_size = Vector2i(460, 0)
	var can_save := not _match_locked()
	dlg.dialog_text = tr("ui.quit.body") if can_save else tr("ui.quit.body_match")
	dlg.ok_button_text = tr("ui.quit.save_quit") if can_save else tr("ui.quit.discard")
	dlg.cancel_button_text = tr("ui.cancel")
	if can_save:
		dlg.add_button(tr("ui.quit.discard"), true, "discard")
		dlg.custom_action.connect(func(action: StringName):
			if action == &"discard":
				get_tree().quit())
	dlg.confirmed.connect(func():
		if not can_save:
			get_tree().quit()
			return
		var close := UI.if_alive(dlg, func(d: Node): d.queue_free())
		var on_saved := func(ok: bool):
			if ok:
				get_tree().quit()
			else:
				close.call()
		if save_and_confirm("", on_saved) != OK:
			dlg.queue_free())
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	UI.cancel_right(dlg)
	dlg.popup_centered()


## Rebuilds the theme with the current preferences and returns to the screen (text size, density, language).
func apply_settings() -> void:
	Settings.save_settings()
	theme = ThemeBuilder.build()
	continue_btn.text = tr("ui.continue")
	continue_btn.tooltip_text = tr("ui.continue_hint")
	help_btn.tooltip_text = tr("ui.help.button")
	back_btn.tooltip_text = tr("ui.back")
	save_btn.tooltip_text = tr("ui.menu.saves")
	owl_btn.tooltip_text = tr("ui.menu.inbox")
	holiday_btn.tooltip_text = tr("ui.holiday.title")
	settings_btn.tooltip_text = tr("ui.menu.settings")
	var h: Dictionary = history[hist_pos] if hist_pos >= 0 and hist_pos < history.size() else {"id": current_id, "params": current.params if current != null else {}}
	go(h["id"], h["params"], false)


func _show_help() -> void:
	var key := "ui.help." + _menu_id()
	var body := tr(key) if tr(key) != key else tr("ui.help.generic")
	var name := ""
	for group in MENU:
		for entry in group[1]:
			if entry[0] == _menu_id():
				name = tr(str(entry[1]))
	var dlg := AcceptDialog.new()
	dlg.title = tr("ui.help.title") % (name if name != "" else tr("ui.app_title"))
	dlg.dialog_text = body + ("\n\n" + tr("ui.help.generic") if body != tr("ui.help.generic") else "")
	dlg.dialog_autowrap = true
	dlg.min_size = Vector2i(560, 0)
	dlg.ok_button_text = tr("ui.ok")
	add_child(dlg)
	dlg.popup_centered()
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)


## Brief notice at the top right (3 s).
func toast(text: String, icon_name: String = "check-circle", kind: String = "ok") -> void:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", ThemeBuilder.flat(ThemeBuilder.WOOD, ThemeBuilder.BRASS if kind == "ok" else ThemeBuilder.SEALING_WAX, 1, 4, 10))
	var h := UI.hbox(8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := TextureRect.new()
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.texture = ThemeBuilder.icon(icon_name)
	ic.custom_minimum_size = Vector2(18, 18)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.modulate = ThemeBuilder.BRASS if kind == "ok" else Color("#E8A09C")
	h.add_child(ic)
	var l := UI.label(text, "ui_medium", 14, ThemeBuilder.MENU_TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	p.add_child(h)
	toast_box.add_child(p)
	toast_box.position = Vector2(size.x - 380, 56)
	var t := get_tree().create_timer(3.0)
	t.timeout.connect(func():
		if is_instance_valid(p):
			toast_box.remove_child(p)
			p.queue_free())


## Developer command-line options (after `--`), mainly for screenshots and automated checks:
##   --autostart <club_id> [--seed N]  start a new game with that club (default seed 7)
##   --lang <code>                     UI language for this run only (not saved to settings)
##   --tour <dir>                      run the UI tour (UITour) and quit; see ui_tour.gd
##   --advance N [--play-match]        advance N days (urgent owls auto-resolved); stop at a match unless
##                                     --play-match is given
##   --advance2 N                      advance N days through the engine, stopping where it stops
##   --nt <id> / --view <mode>         accept a national-team job / set the match view
##   --screen <id> [--player id] [--a id --b id] [--competition id] [--club id] [--school id] [--tab N]
##                [--nt-id id]         open that screen with those parameters (national / national_tactics:
##                                     the manager's national team unless --nt-id names another)
##   --ticks N / --finish / --press    step the match N ticks / finish it / open the press conference
##   --main-call <fn> / --call <fn>    call a method on main / on the current screen
##   --scroll N                        scroll every ScrollContainer on the screen to N
##   --weather / --film / --until      match-viewer captures (see the comments below)
##   --shot <path.png> [--wait N]      save a screenshot after N frames (default 4) and quit
func _handle_cmdline() -> void:
	var raw := OS.get_cmdline_user_args()
	var args := {}
	var i := 0
	while i < raw.size():
		if raw[i].begins_with("--") and i + 1 < raw.size() and not raw[i + 1].begins_with("--"):
			args[raw[i].trim_prefix("--")] = raw[i + 1]
			i += 2
		else:
			if raw[i].begins_with("--"):
				args[raw[i].trim_prefix("--")] = "true"
			i += 1
	if args.is_empty():
		return
	if args.has("lang"):
		Settings.language = str(args["lang"])
		TranslationServer.set_locale(Settings.language)
		ThemeBuilder.update_cjk()
	if args.has("autostart"):
		Game.new_game(str(args["autostart"]), "Manager", "eng", int(args.get("seed", "7")))
		if args.has("lang"):
			Game.world.settings["language"] = Settings.language
			TranslationServer.set_locale(Settings.language)
			ThemeBuilder.update_cjk()
	if args.has("load"):
		if not await run_blocking(tr("ui.loading.load"), func(): return Game.load_game(str(args["load"]))):
			printerr("--load: no loadable save in slot ", str(args["load"]))
			get_tree().quit(1)
			return
		go("inbox")
	if args.has("tour"):
		if not Game.has_game():
			Game.new_game(str(args.get("autostart", "club_puddlemere_united")), "Manager", "eng", 7)
		await UITour.new(self, str(args["tour"])).run()
		get_tree().quit()
		return
	if args.has("advance"):
		Game.engine.auto_fix_lineup = true
		for k in int(args["advance"]):
			Inbox.close_blocking(Game.world)
			var r := Game.advance_one_day()
			if r["reason"] == "match":
				if args.has("play-match"):
					Game.engine.complete_pending_match()
				else:
					break
		Game.engine.auto_fix_lineup = false
	if args.has("nt") and Game.has_game():
		Game.engine.accept_national_job(str(args["nt"]))
	if args.has("view") and Game.has_game():
		Game.world.settings["match_view"] = str(args["view"])
	if args.has("screen"):
		var p := {}
		if args.has("player"):
			p["player_id"] = str(args["player"])
		if args.has("a"):
			p["a"] = str(args["a"])
			p["b"] = str(args.get("b", ""))
		if args.has("competition"):
			p["competition_id"] = str(args["competition"])
		if args.has("club"):
			p["club_id"] = str(args["club"])
		if args.has("school"):
			p["school_id"] = str(args["school"])
		if args.has("tab"):
			p["tab"] = int(args["tab"])
		if ["national", "national_tactics"].has(str(args["screen"])):
			p["nt_id"] = str(args.get("nt-id", Game.world.manager.get("national_team_id", "")))
		go(str(args["screen"]), p)
	if args.has("ticks") and current != null and current.has_method("debug_step"):
		current.debug_step(int(args["ticks"]))
	if args.has("finish") and Game.engine.pending_match != null:
		Game.engine.complete_pending_match()
		go("post_match")
	if args.has("press") and Game.engine.last_match != null:
		go("press", {"fixture_id": str(Game.engine.last_match.fixture["id"])})
	if args.has("main-call") and has_method(str(args["main-call"])):
		call(str(args["main-call"]))
	if args.has("advance2"):
		for k in int(args["advance2"]):
			var r2 := Game.engine.advance_day()
			if r2["stopped"]:
				break
		_refresh_bars()
		refresh_current()
	if args.has("call") and current != null and current.has_method(str(args["call"])):
		await get_tree().process_frame
		current.call(str(args["call"]))
	if args.has("scroll") and current != null:
		await get_tree().process_frame
		await get_tree().process_frame
		for sc in current.find_children("*", "ScrollContainer", true, false):
			sc.scroll_vertical = int(args["scroll"])
	# --weather snow|rain|storm|fog|wind: forces the weather of the current match (2D screenshots only).
	if args.has("weather") and current != null and current.get("sim") != null:
		current.sim.weather = str(args["weather"])
	# --film N --gap F: runs the match (2D viewer) and saves N screenshots every F frames (shot_0.png, shot_1.png…).
	if args.has("film") and current != null and current.get("pitch") != null:
		if current.has_method("_play"):
			current._play()
		if args.has("speed"):
			current.speed = clampi(int(args["speed"]), 0, 3)
		var base := str(args.get("shot", "user://film.png")).get_basename()
		for n in int(args["film"]):
			for fi in int(args.get("gap", "20")):
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("%s_%d.png" % [base, n])
		print("film saved")
		get_tree().quit()
		return
	# --until goal|catch: runs the match (2D viewer) until that play's animation and takes the screenshot there.
	if args.has("until") and current != null and current.get("pitch") != null:
		if args.has("noreplay"):
			Game.world.settings["match_replays"] = false
		if args.has("speed"):
			current.speed = clampi(int(args["speed"]), 0, 3)
		if current.has_method("_play"):
			current._play()
		var want := str(args["until"])
		var at := float(args.get("at", "1.2"))
		for fi in 60000:
			await get_tree().process_frame
			var pa: Dictionary = current.pitch._anim
			if not pa.is_empty() and str(pa.get("kind", "")) == want and float(pa.get("t", 0.0)) >= at:
				break
		var img := get_viewport().get_texture().get_image()
		img.save_png(str(args.get("shot", "user://anim.png")))
		print("screenshot saved to ", str(args.get("shot", "")))
		get_tree().quit()
		return
	if args.has("shot"):
		_take_shot(str(args["shot"]), int(args.get("wait", "4")))


func _take_shot(path: String, frames: int = 4) -> void:
	for i in frames:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("screenshot saved to ", path)
	get_tree().quit()


## Gives the player a saved game as a `.qmsave` file (a download in the browser).
func export_save(dir_name: String) -> void:
	var bytes := SaveManager.export_file(dir_name)
	if bytes.is_empty():
		toast(tr("ui.save_failed"), "x-circle", "error")
		return
	Platform.offer_file(self, bytes, "%s.%s" % [dir_name.validate_filename(), Platform.SAVE_EXT])


## Asks for a `.qmsave` file and adds it to the saved games; `on_imported(dir_name)` runs if it was valid.
func import_save(on_imported: Callable) -> void:
	Platform.pick_file(self, func(bytes: PackedByteArray):
		var dir_name := SaveManager.import_file(bytes)
		if dir_name == "":
			toast(tr("ui.saves.import_failed"), "x-circle", "error")
			return
		toast(tr("ui.saves.imported") % dir_name)
		on_imported.call(dir_name))


## The row of file buttons under a list of saves: export the selected one, import one from a file. In the browser
## a note reminds the player that saves only live in this browser until they export them.
func save_file_buttons(list: ItemList, on_imported: Callable) -> Control:
	var v := UI.vbox(6)
	var h := UI.hbox(8)
	h.add_child(UI.button(tr("ui.saves.export"), func():
		var sel := list.get_selected_items()
		if not sel.is_empty():
			export_save(str(list.get_item_metadata(sel[0])))))
	h.add_child(UI.button(tr("ui.saves.import"), func(): import_save(on_imported)))
	v.add_child(h)
	if Platform.is_web():
		v.add_child(UI.text("MetaItalic", tr("ui.saves.web_note")))
	return v


## Save / load in a popup window (not a game screen): name + save, a list to load from,
## and back to the main menu.
func open_save_dialog() -> void:
	if not Game.has_game():
		return
	var dlg := AcceptDialog.new()
	dlg.title = tr("ui.menu.saves")
	dlg.ok_button_text = tr("ui.close")
	var v := UI.vbox(8)
	v.custom_minimum_size = Vector2(520, 0)
	v.add_child(UI.text("Caption", tr("ui.saves.name")))
	var h := UI.hbox(8)
	var name_edit := LineEdit.new()
	name_edit.text = Game.save_name
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(name_edit)
	var msg := UI.text("MetaItalic", "")
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(0, 200)
	var fill := func():
		list.clear()
		for m in SaveManager.list_saves():
			var idx := list.add_item(Game.save_label(m))
			list.set_item_metadata(idx, m.get("dir", ""))
	h.add_child(UI.primary(tr("ui.save"), func():
		var typed := name_edit.text.strip_edges()
		if typed == "":
			msg.text = tr("ui.saves.bad_name")
			return
		msg.text = tr("ui.saving")
		var saved_text := tr("ui.saved")
		var unconfirmed_text := tr("ui.save_unconfirmed")
		var err := save_and_confirm(typed, UI.if_alive(msg, func(ml: Label, ok: bool): ml.text = saved_text if ok else unconfirmed_text))
		if err == OK:
			name_edit.text = Game.save_name
		elif err == ERR_INVALID_PARAMETER:
			msg.text = tr("ui.saves.bad_name")
		elif err == ERR_ALREADY_EXISTS:
			msg.text = tr("ui.saves.other_career")
		else:
			msg.text = tr("ui.save_after_match") if err == ERR_BUSY else tr("ui.save_failed")
		fill.call()))
	v.add_child(h)
	v.add_child(msg)
	v.add_child(UI.rule())
	v.add_child(UI.text("Caption", tr("ui.saves.existing")))
	fill.call()
	v.add_child(list)
	v.add_child(save_file_buttons(list, func(_n): fill.call()))
	var bh := UI.hbox(8)
	var load_it := func(sname: String):
		dlg.hide()
		if await run_blocking(tr("ui.loading.load"), func(): return Game.load_game(sname)):
			dlg.queue_free()
			go("inbox")
		else:
			toast(tr("ui.saves.load_failed"), "x-circle", "error")
			dlg.popup_centered()
	bh.add_child(UI.button(tr("ui.new_game.load_btn"), func():
		var sel := list.get_selected_items()
		if sel.is_empty():
			return
		var sname := str(list.get_item_metadata(sel[0]))
		confirm_unsaved(dlg, tr("ui.saves.load_ask"), tr("ui.saves.unsaved_body"), tr("ui.saves.load_discard"), func(): load_it.call(sname))))
	bh.add_child(UI.spacer())
	var leave := func():
		dlg.hide()
		dlg.queue_free()
		Game.close_game()
		go("title")
	bh.add_child(UI.button(tr("ui.saves.main_menu"), func():
		confirm_unsaved(dlg, tr("ui.saves.main_menu_ask"), tr("ui.quit.body"), tr("ui.quit.discard"), leave)))
	v.add_child(bh)
	dlg.add_child(v)
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered()


## Runs `on_go` at once if nothing is unsaved; otherwise asks first (progress not saved, or not confirmed yet in the
## browser), as when closing the window. The question is a child of `parent` (a dialog: it is the window in front,
## and it goes with it).
func confirm_unsaved(parent: Node, title: String, body: String, ok_text: String, on_go: Callable) -> void:
	if not _unsaved:
		on_go.call()
		return
	var ask := ConfirmationDialog.new()
	ask.title = title
	ask.dialog_text = body
	ask.dialog_autowrap = true
	ask.min_size = Vector2i(460, 0)
	ask.ok_button_text = ok_text
	ask.cancel_button_text = tr("ui.cancel")
	ask.confirmed.connect(func():
		ask.queue_free()
		on_go.call())
	ask.canceled.connect(ask.queue_free)
	parent.add_child(ask)
	UI.cancel_right(ask)
	ask.popup_centered()


## The match is over: the top bar and navigation are enabled again.
func on_match_finished() -> void:
	_refresh_bars()
	back_btn.disabled = hist_pos <= 0
	fwd_btn.disabled = hist_pos >= history.size() - 1
