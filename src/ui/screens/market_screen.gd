extends UIScreen
## Market: search players from other clubs and free agents; ongoing offers.

var table: Tree
var pos_filter := "all"
var scope := "free"
var region_filter := "all"
var _configured := false
var offers: RichTextLabel
const PAGE := 120
var page_size := PAGE
var found_label: Label
var more_btn: Button


func build() -> void:
	var club := Game.my_club()
	header(T("ui.menu.market"), Game.galleons(club.balance) if club != null else "")
	if not _configured:
		_configured = true
		scope = "all"
		region_filter = club.region_id if club != null else "all"
	var bar := UI.hbox(10)
	bar.add_child(UI.option([["free", T("ui.market.free_agents")], ["listed", T("ui.market.listed")], ["loan", T("ui.market.loans")], ["shortlist", T("ui.market.shortlist")], ["all", T("ui.market.all_players")]], scope, func(v): scope = v; page_size = PAGE; refresh()))
	bar.add_child(UI.option([["all", T("ui.filter.all")], ["K", T("pos.K")], ["C", T("pos.C")], ["B", T("pos.B")], ["S", T("pos.S")]], pos_filter, func(v): pos_filter = v; page_size = PAGE; refresh()))
	var ritems := [["all", T("ui.filter.all_regions")]]
	var rids := Game.loader.regions.keys()
	rids.sort()
	for rid in rids:
		var reg: Dictionary = Game.loader.regions[rid]
		if str(reg.get("league_id", "")) == "":
			continue
		ritems.append([rid, Loc.region(reg, rid)])
	bar.add_child(UI.option(ritems, region_filter, func(v): region_filter = str(v); page_size = PAGE; refresh()))
	bar.add_child(UI.spacer())
	found_label = UI.text("Meta", "")
	bar.add_child(found_label)
	root.add_child(bar)
	table = UI.table([
		{"title": T("ui.col.name"), "width": 190, "expand": true}, {"title": T("ui.col.pos"), "width": 36, "align": "center"}, {"title": T("ui.col.age"), "width": 36, "align": "right"},
		{"title": T("ui.col.club"), "width": 170}, {"title": T("ui.ca_stars"), "width": 90}, {"title": T("ui.col.value"), "width": 80, "align": "right"}, {"title": T("ui.asking"), "width": 80, "align": "right"}, {"title": T("ui.col.wage"), "width": 50, "align": "right"},
	], 360)
	table.item_activated.connect(func(): var it := table.get_selected(); if it: go("player", {"player_id": str(it.get_metadata(0))}))
	root.add_child(UI.table_card(table))
	more_btn = UI.button("", func(): page_size += PAGE; refresh())
	more_btn.visible = false
	root.add_child(more_btn)
	var op := UI.panel(8)
	offers = UI.rich("")
	offers.meta_clicked.connect(_on_offer_link)
	op.add_child(offers)
	root.add_child(op)


func refresh() -> void:
	table.clear()
	table.create_item()
	var w := Game.world
	var rows: Array[Player] = []
	for p in w.players.values():
		if w.player_club_id != "" and p.club_id == w.player_club_id:
			continue
		if p.squad in Player.Squad.AWAY_FROM_CLUBS:
			continue
		if pos_filter != "all" and p.position != pos_filter:
			continue
		var is_free: bool = p.club_id == "" or p.squad == Player.Squad.FREE
		if region_filter != "all":
			var reg := Game.loader.region_of_country(p.nationality)
			if p.club_id != "" and w.clubs.has(p.club_id):
				reg = w.clubs[p.club_id].region_id
			if reg != region_filter:
				continue
		if scope == "free" and not is_free:
			continue
		if scope == "listed" and not p.transfer_listed:
			continue
		if scope == "shortlist" and not w.shortlist.has(p.id):
			continue
		if scope == "loan":
			var owner: Club = w.clubs.get(p.club_id)
			if p.club_id == "" or p.is_on_loan() or owner == null or owner.manager_is_human:
				continue
			if not (p.loan_listed or (p.squad in Player.Squad.DEVELOPING and p.age(w.today) <= 24)):
				continue
		rows.append(p)
	var ca := {}
	for p in rows:
		ca[p.id] = p.ca()
	rows.sort_custom(func(a, b): return ca[a.id] > ca[b.id])
	if rows.is_empty():
		UI.group_row(table, T("ui.market.no_results"))
	var shown := mini(rows.size(), page_size)
	found_label.text = T("ui.market.found") % [rows.size(), shown] if rows.size() > 0 else ""
	more_btn.visible = rows.size() > shown
	if more_btn.visible:
		more_btn.text = T("ui.explorer.show_more") % (rows.size() - shown)
	for p in rows.slice(0, shown):
		var is_free: bool = p.club_id == "" or p.squad == Player.Squad.FREE
		var club_txt: String = T("ui.free_agent") if is_free else Game.club_name(p.club_id)
		if p.is_on_loan():
			club_txt += " (%s)" % T("ui.loan_badge")
		var lvl := Game.knowledge_level(p)
		var mrow := UI.row(table, [p.name(), UI.pos_short(p.position), p.age(w.today), club_txt, (_stars(ca[p.id]) if lvl >= 1 else "?"), Game.galleons(p.market_value(w.today)) if lvl >= 1 else "?", ("—" if is_free else Game.galleons(Economy.asking_price(w, p))), int(p.contract.get("wage_weekly", 0))], p.id)
		UI.player_cell(mrow, 0, p.id)
		UI.team_cell(mrow, 3, p.club_id)
	var txt := ""
	var me := Game.my_club()
	if me != null:
		var bill := 0
		for q in w.squad_of(me.id):
			bill += int(q.contract.get("wage_weekly", 0))
		txt += T("ui.market.budgets") % [Game.galleons(me.transfer_budget), Game.galleons(bill), Game.galleons(me.wage_budget_weekly)] + "\n"
		if bool(me.board.get("embargo", false)):
			txt += "[color=#%s][b]%s[/b][/color]\n" % [ThemeBuilder.SEALING_WAX.to_html(false), T("ui.market.embargo")]
		txt += "\n"
	txt += "[b]%s[/b]\n" % T("ui.market.pending_offers")
	var any := false
	for o in w.pending_offers:
		if str(o["status"]) != "pending":
			continue
		any = true
		txt += "• %s → %s: %s (%s)\n" % [_url("player", str(o["player_id"]), Game.player_name(str(o["player_id"]))), _url("team", str(o["to_id"]), Game.club_name(str(o["to_id"]))), Game.galleons(int(o["fee"])), Game.date_text(int(o["resolve_day"]))]
	if not any:
		txt += T("ui.market.no_offers")
	offers.text = txt


func _stars(ca: float) -> String:
	var n := clampi(int(round(ca / 36.0)), 1, 5)
	return "★".repeat(n) + "☆".repeat(5 - n)


func _url(kind: String, id: String, text: String) -> String:
	var w := Game.world
	var ok := w.player(id) != null if kind == "player" else (w.clubs.has(id) or w.houses.has(id) or w.national_teams.has(id))
	var safe := text.replace("[", "(").replace("]", ")")
	return "[url=%s:%s]%s[/url]" % [kind, id, safe] if ok and id != "" else safe


func _on_offer_link(meta: Variant) -> void:
	var m := str(meta)
	var kind := m.get_slice(":", 0)
	var id := m.substr(kind.length() + 1)
	if kind == "player":
		go("player", {"player_id": id})
	elif id.begins_with("nt_"):
		go("national", {"nt_id": id})
	else:
		go("club", {"club_id": id})
