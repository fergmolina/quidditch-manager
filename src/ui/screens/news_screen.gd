extends UIScreen
## The Daily Prophet: gothic masthead, double rule, full-width lead story
## with large headline, standfirst and drop cap; the rest in three columns. Our own match goes first.

var edition_pick: OptionButton
var page: VBoxContainer
var current := 0
## A drop cap needs a paragraph of a few lines: shorter lead bodies are set plain.
const DROPCAP_MIN_CHARS := 160


func build() -> void:
	var bar := UI.hbox(10)
	bar.add_child(UI.title(T("ui.menu.news")))
	bar.add_child(UI.spacer())
	edition_pick = OptionButton.new()
	edition_pick.custom_minimum_size = Vector2(280, 32)
	edition_pick.item_selected.connect(func(i): current = i; _show(i))
	bar.add_child(edition_pick)
	root.add_child(bar)
	var paper := PanelContainer.new()
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	paper.add_theme_stylebox_override("panel", ThemeBuilder.flat(ThemeBuilder.NEWSPAPER, ThemeBuilder.INK, 1, 0, 22))
	page = UI.vbox(8)
	paper.add_child(UI.scroll(page))
	root.add_child(paper)


func refresh() -> void:
	edition_pick.clear()
	for e in Game.world.news:
		edition_pick.add_item("%s · %s" % [T("ui.news.edition_n", {"n": int(e["edition"])}), Game.date_text(int(e["day"]))])
	if edition_pick.item_count > 0:
		current = clampi(current, 0, edition_pick.item_count - 1)
		edition_pick.select(current)
		_show(current)
	else:
		clear(page)
		page.add_child(UI.text("MetaItalic", T("ui.news.none")))


func _show(i: int) -> void:
	clear(page)
	var e: Dictionary = Game.world.news[i]
	var mh := UI.hbox(14)
	mh.alignment = BoxContainer.ALIGNMENT_CENTER
	var insignia := UI.image_for("art", "prophet")
	if insignia != null:
		var tr := TextureRect.new()
		tr.texture = insignia
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(84, 98)
		mh.add_child(tr)
	var head := UI.label(T("ui.news.masthead"), "gothic", 48)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mh.add_child(head)
	page.add_child(mh)
	var sub := UI.label("%s · %s · %s" % [Game.date_text(int(e["day"])), T("ui.news.edition_n", {"n": int(e["edition"])}), T("ui.news.price")], "ui_italic", 13, ThemeBuilder.INK_SOFT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(sub)
	page.add_child(_ink_rule(2))
	page.add_child(_ink_rule(1))
	var items: Array = e["items"].duplicate()
	if items.is_empty():
		return
	var me := Game.my_club()
	var lead_idx := -1
	var best_imp := -100
	for k in items.size():
		var it: Dictionary = items[k]
		if str(it.get("masthead", "")) != "":
			continue
		var mine: bool = me != null and (str(it["key"]).begins_with("news.match") or str(it["key"]) == "news.derby_preview") and it.get("clubs", []).has(me.id)
		var imp: int = int(it.get("importance", 1)) + (10 if mine else 0) - (20 if str(it["key"]).begins_with("news.filler.") else 0)
		if imp > best_imp:
			best_imp = imp
			lead_idx = k
	if lead_idx >= 0:
		var lead: Dictionary = items[lead_idx]
		items.remove_at(lead_idx)
		page.add_child(_story(lead, true))
	else:
		page.add_child(UI.rich_links_styled(T("ui.news.quiet_lead"), "title", 34))
	page.add_child(_ink_rule(1))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	var vcols: Array = []
	var load: Array = [0, 0, 0]
	for c in 3:
		var v := UI.vbox(10)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vcols.append(v)
		cols.add_child(v)
		if c < 2:
			var sep := ColorRect.new()
			sep.color = Color(ThemeBuilder.INK, 0.35)
			sep.custom_minimum_size = Vector2(1, 0)
			cols.add_child(sep)
	for it in items:
		var shortest := 0
		for c in 3:
			if load[c] < load[shortest]:
				shortest = c
		var story := _story(it, false)
		vcols[shortest].add_child(story)
		vcols[shortest].add_child(_ink_rule(1, 0.25))
		load[shortest] += _text_of(it).length() + 60
	page.add_child(cols)


func _text_of(it: Dictionary) -> String:
	var ph := Say.Phrase.from_dict(it)
	return Say.render(ph, false, hash(ph.signature()))


func _story(it: Dictionary, lead: bool) -> Control:
	var v := UI.vbox(4)
	var txt := _text_of(it)
	var ph := Say.Phrase.from_dict(it)
	var nl := txt.find("\n")
	var headline := txt if nl < 0 else txt.substr(0, nl)
	var body := "" if nl < 0 else txt.substr(nl + 1).strip_edges()
	var key := str(it["key"])
	if lead:
		v.add_child(UI.rich_links_styled(Say.link(headline, ph), "title", 34))
		if body != "":
			var dot := body.find(". ")
			var deck := body if dot < 0 else body.substr(0, dot + 1)
			var rest := "" if dot < 0 else body.substr(dot + 2)
			v.add_child(UI.rich_links_styled(Say.link(deck, ph), "ui_italic", 17, ThemeBuilder.INK_SOFT))
			if rest.length() > DROPCAP_MIN_CHARS:
				# [dropcap] spans the first lines without enlarging the first line box, so link underlines in that
				# line stay right under the text.
				var r := UI.rich_links("[dropcap font_size=40 margins=0,0,6,0]%s[/dropcap]%s" % [rest.left(1).replace("[", "[lb]"), Say.link(rest.substr(1), ph)])
				v.add_child(r)
			elif rest != "":
				v.add_child(UI.rich_links(Say.link(rest, ph)))
	else:
		v.add_child(UI.rich_links_styled(Say.link(headline, ph), "title_sc" if key.begins_with("news.match") else "ui_bold", 18 if key.begins_with("news.match") else 15))
		if body != "":
			var r := UI.rich_links(Say.link(body, ph))
			r.add_theme_font_size_override("normal_font_size", 15)
			v.add_child(r)
	var sig := ""
	if str(it.get("masthead", "")) != "":
		sig = T(str(it["masthead"])).strip_edges()
		if not sig.begins_with("—"):
			sig = "— " + sig
	elif key.begins_with("news.quibbler"):
		sig = T("news.quibbler.signature")
	if sig != "":
		var q := UI.label(sig, "ui_italic", 13, ThemeBuilder.INK_FADED)
		v.add_child(q)
	return v


func _ink_rule(h: int, alpha: float = 1.0) -> Control:
	var c := ColorRect.new()
	c.color = Color(ThemeBuilder.INK, alpha)
	c.custom_minimum_size = Vector2(0, h)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c
