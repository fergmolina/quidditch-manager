class_name PlayerScreenActions
extends RefCounted
## What the manager can do with a player right now, as [key, label] pairs: the "Actions" menu of the profile and the
## right-click player menu list these, and PlayerScreen._run_action carries each key out.


static func for_player(player_id: String) -> Array:
	var w := Game.world
	var p: Player = w.player(player_id)
	if p == null:
		return []
	var actions := []
	var shortlist := ["shortlist", Game.t("ui.action.shortlist_off") if w.shortlist.has(p.id) else Game.t("ui.action.shortlist_on")]
	if p.squad == Player.Squad.SCHOOL:
		if w.is_school_mode() and Schools.house_id(p.school_id, p.house) == w.player_club_id:
			actions = [["talk", Game.t("ui.action.talk")], ["make_captain", Game.t("ui.action.make_captain")]]
		elif not w.is_school_mode():
			actions = [shortlist]
			if Contracts.graduate_offer_allowed(w, p, Game.my_club()):
				actions.append(["graduate_offer", Game.t("ui.action.graduate_offer")])
	elif w.is_school_mode():
		pass
	elif p.club_id == w.player_club_id and w.player_club_id != "":
		if p.is_on_loan():
			actions = [["loan_end", Game.t("ui.action.loan_end")]]
		else:
			actions = [["transfer_list", Game.t("ui.action.transfer_list_off") if p.transfer_listed else Game.t("ui.action.transfer_list_on")],
				["loan_list", Game.t("ui.action.loan_list_off") if p.loan_listed else Game.t("ui.action.loan_list_on")],
				["loan_list_option", Game.t("ui.action.loan_list_option") % Game.galleons(Economy.asking_price(w, p))],
				["talk", Game.t("ui.action.talk")]]
			if p.pre_contract == null:
				actions.append(["renew", Game.t("ui.action.renew")])
			actions.append_array([["make_captain", Game.t("ui.action.make_captain")], ["release", Game.t("ui.action.release")], ["mutual", Game.t("ui.action.mutual")]])
	elif loaned_out(w, p):
		if p.pre_contract == null:
			actions.append(["renew", Game.t("ui.action.renew")])
		actions.append(["loan_recall", Game.t("ui.action.loan_recall")])
	elif p.club_id == "" and p.squad == Player.Squad.FREE and w.player_club_id != "":
		actions = [["negotiate", Game.t("ui.action.negotiate")]]
	elif w.player_club_id != "" and p.squad != Player.Squad.ABROAD and not p.is_on_loan():
		actions.append(["negotiate_menu", Game.t("ui.action.negotiate_menu")])
		actions.append(["scout_report", Game.t("ui.action.scout_report")])
		actions.append(shortlist)
	if p.squad != Player.Squad.ABROAD:
		var other: Player = w.player(Game.compare_player_id) if Game.compare_player_id != "" and Game.compare_player_id != p.id else null
		if other != null:
			actions.append(["compare_with", Game.t("ui.action.compare_with") % other.name()])
		if Game.compare_player_id != p.id:
			actions.append(["compare_mark", Game.t("ui.action.compare_mark")])
		else:
			actions.append(["compare_unmark", Game.t("ui.action.compare_unmark")])
	return actions


## The player is out on loan from the manager's club.
static func loaned_out(w: World, p: Player) -> bool:
	return p.is_on_loan() and w.player_club_id != "" and p.loan.owner_id == w.player_club_id
