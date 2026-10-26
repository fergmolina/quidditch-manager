extends SceneTree
## Regression tests for the match engine (the rule checks of docs/design/03 §12: determinism, no substitutions,
## long matches that end) and for the game layer (world, engine, market, saves, data and builds).
## Run: godot --headless --path . -s tests/run_tests.gd
## Exits with code 1 if any of them fails.

const TEST_SAVES_DIR := "user://test_saves"
var failures := 0
var passed := 0
var loader := SimLoader.new()


func check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failures += 1
		print("  FAILED: ", msg)


func _init() -> void:
	SaveManager.saves_dir = TEST_SAVES_DIR
	_rm_tree(TEST_SAVES_DIR)
	loader.load_all("1993-94")
	test_determinism()
	test_rules_no_substitution()
	test_snitch_ends_match_and_scores()
	test_seeker_instruction_ahead_by()
	test_time_cap_world_cup_groups()
	test_canon_teams_load()
	test_interventions_apply_at_stoppage()
	test_long_matches_end()
	test_step_api()
	test_world_human_season()
	test_loans()
	test_negotiation()
	test_national_job()
	test_schools_and_book_events()
	test_canon_cup_champion_reads_book_events()
	test_house_manager()
	test_competition_formats()
	test_time_cap_competition()
	test_world_full()
	test_contracts_and_sackings()
	test_contract_negotiation()
	test_happiness()
	test_fm_features()
	test_loans_options_friendlies()
	test_long_match_regime_forced()
	test_protect_beaters_shield()
	test_mentality_has_effect()
	test_fouls_seen_blatching_and_keeper_attack()
	test_penalty_counts_as_conceded()
	test_night_pause_applies_queued_tactics()
	test_human_timeout_ai_reorganizes()
	test_minutes_stop_when_out()
	test_broom_affects_dive()
	test_veteran_decline_personality_and_position()
	test_medical_level_scales()
	test_world_dates_and_league_calendar()
	test_world_canon_and_pack_isolation()
	test_world_houses_and_staff()
	test_world_knockouts_and_names()
	test_nt_pick_squad_is_seven_of_the_nationality()
	test_world_cup_finals_seeded_for_national_page()
	test_rival_house_view_keeps_own_house_cache()
	test_school_year_seven_is_graduating()
	test_suspension_is_served()
	test_open_day_survives_reload_and_job_change()
	test_lineup_day_closes_after_resign_and_reload()
	test_job_change_with_match_pending()
	test_continental_draw_pots()
	test_european_cup_keeps_champions()
	test_nt_late_hire_not_reviewed()
	test_clubless_players_age()
	test_engine_short_house_plays()
	test_engine_left_club_no_offer()
	test_engine_ultimatum_stale()
	test_engine_rollover_prize_and_late_arrival()
	test_engine_national_switch_and_sack()
	test_engine_canon_players_and_prospects()
	test_pre_contract_signing_fee_paid()
	test_installments_take_full_fee_off_budget()
	test_stale_agent_owl_voids_deal()
	test_stale_incoming_offer_is_void()
	test_transfer_clears_pre_contract()
	test_objective_top_half_13()
	test_package_value_does_not_create_rows()
	test_talk_cooldown_and_no_sharpness()
	test_promise_across_rollover()
	test_press_draw_with_catch()
	test_awards_include_departed_players()
	test_awards_credit_released_players_club()
	test_award_news_without_league_club()
	test_press_new_in_charge_counts_spell_matches()
	test_keeper_depth_blocks_loans_and_sales()
	test_staff_severance_expired_contract()
	test_matchdays_played_by_matches()
	test_prune_pending_offers()
	test_session_text_params()
	test_say_round_trip()
	test_inbox_kinds_answer()
	test_inbox_access_fenced()
	test_inbox_records()
	test_save_import_hardening()
	test_team_talk_cap()
	test_pre_press_questions_survive_save()
	test_vacancy_marker_changes_per_vacancy()
	test_playtest_fixes_regressions()
	test_translation_sources_in_sync()
	test_about_text_version()
	test_export_presets_ship_licenses()
	test_fonts_cover_translations()
	test_season_report()
	test_save_slots_per_career()
	test_match_uses_squad_condition()
	test_post_match_condition_floor()
	test_swap_needs_both_players()
	test_inbox_accept_respects_embargo()
	test_swap_respects_women_only_seller()
	test_short_lineup_keeps_roles()
	test_day_stepper_matches_advance_day()
	test_match_events_carry_play_context()
	test_international_duty()
	test_save_load_round_trip_simulates_alike()
	test_world_generation_is_deterministic()
	test_platform_js_source()
	_rm_tree(TEST_SAVES_DIR)
	print("\n%d passed, %d failed" % [passed, failures])
	quit(1 if failures > 0 else 0)


func _rm_tree(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	d.include_hidden = true
	for n in d.get_directories():
		_rm_tree(path.path_join(n))
	for n in d.get_files():
		d.remove(n)
	DirAccess.remove_absolute(path)


func _sim() -> MatchSim:
	return MatchSim.new(loader.rules, loader.params)


func test_determinism() -> void:
	print("determinism")
	var a := SimLoader.synthetic_team("A", 12.0)
	var b := SimLoader.synthetic_team("B", 13.0)
	var r1 := _sim().run(a, b, 123)
	var r2 := _sim().run(a, b, 123)
	check(r1.score_home == r2.score_home and r1.score_away == r2.score_away, "same score with the same seed")
	check(r1.duration_ticks == r2.duration_ticks, "same duration with the same seed")
	check(r1.events.size() == r2.events.size(), "same number of events")
	var same := true
	for i in r1.events.size():
		if r1.events[i].type != r2.events[i].type or r1.events[i].tick != r2.events[i].tick or r1.events[i].player_id != r2.events[i].player_id:
			same = false
			break
	check(same, "log identical event by event")
	var r3 := _sim().run(a, b, 124)
	check(r3.rng_calls != r1.rng_calls or r3.score_home != r1.score_home or r3.duration_ticks != r1.duration_ticks, "another seed gives another match")


func test_rules_no_substitution() -> void:
	print("rule 5: no substitutions; a sent-off player does not come back")
	var a := SimLoader.synthetic_team("A", 12.0, {"hard_play": 20})
	var b := SimLoader.synthetic_team("B", 12.0, {"hard_play": 20})
	for p in a.players + b.players:
		p.hidden["dirtiness"] = 20.0
		p.hidden["injury_proneness"] = 20.0
	var saw_injury := false
	var saw_send_off := false
	var ok := true
	for seed in range(1, 40):
		var r := _sim().run(a, b, seed)
		var out: Dictionary = {}
		for e in r.events:
			if e.type == "injury":
				saw_injury = true
				out[e.player_id] = e.tick
			if e.type == "send_off":
				saw_send_off = true
				out[e.player_id] = e.tick
			if out.has(e.player_id) and e.tick > out[e.player_id] and e.type in ["goal", "pass", "advance", "save", "snitch_caught", "snitch_sighted", "bludger_hit"] and e.player_id != "":
				if e.type == "bludger_hit":
					continue
				ok = false
		check(r.events.size() > 0, "there are events")
	check(saw_injury, "with maximum proneness there are injuries")
	check(ok, "no player out of the match acts again")
	print("  send-offs seen in 40 matches: %s" % saw_send_off)


func test_snitch_ends_match_and_scores() -> void:
	print("snitch: 150 points and end of match")
	var a := SimLoader.synthetic_team("A", 12.0)
	var b := SimLoader.synthetic_team("B", 12.0)
	var caught := 0
	for seed in range(1, 30):
		var r := _sim().run(a, b, seed)
		if r.end_reason == MatchResult.EndReason.SNITCH:
			caught += 1
			var last := r.events[r.events.size() - 2]
			check(last.type == "snitch_caught", "the second-to-last event is the catch")
			var catcher_score := r.score_home if r.snitch_team_id == r.home_id else r.score_away
			check(catcher_score >= 150, "the catching side gets 150")
			check((r.score_home % 10) == 0 and (r.score_away % 10) == 0, "scores are multiples of 10")
	check(caught >= 25, "most matches end with a catch (%d/29)" % caught)


func test_seeker_instruction_ahead_by() -> void:
	print("seeker instruction: only when ahead by +X")
	var a := SimLoader.synthetic_team("A", 12.0, {"seeker_catch": "ahead_by", "seeker_ahead_by": 100})
	a.is_human = true
	var b := SimLoader.synthetic_team("B", 12.0, {"seeker_catch": "always"})
	var violations := 0
	var a_catches := 0
	for seed in range(1, 60):
		var r := _sim().run(a, b, seed)
		if r.snitch_team_id == "A":
			a_catches += 1
			var a_before := (r.score_home if r.home_id == "A" else r.score_away) - 150
			var b_score := r.score_away if r.home_id == "A" else r.score_home
			if a_before - b_score < 100:
				violations += 1
	check(violations == 0, "A never catches unless ahead by +100 (violations: %d)" % violations)
	check(a_catches < 30, "A catches less than B because it holds off (%d)" % a_catches)


func test_time_cap_world_cup_groups() -> void:
	print("4-hour cap (World Cup group stage)")
	var rules := loader.rules.duplicate(true)
	rules["time_cap_minutes"] = 240
	var params := loader.params.duplicate(true)
	params["snitch"]["sight_base_per_tick"] = 0.0
	var a := SimLoader.synthetic_team("A", 12.0)
	var b := SimLoader.synthetic_team("B", 12.0)
	var r := MatchSim.new(rules, params).run(a, b, 5)
	check(r.end_reason == MatchResult.EndReason.TIME_CAP, "ends by time cap")
	check(r.duration_minutes() <= 240.1, "lasts 240 minutes")
	check(r.snitch_team_id == "", "no catch")


func test_canon_teams_load() -> void:
	print("loading the 13 canon clubs")
	var ids := loader.club_ids()
	check(ids.size() >= 13, "at least 13 canon clubs (%d)" % ids.size())
	for cid in ids:
		var t := loader.build_team(cid)
		check(t.players.size() == 7, "%s has 7 starters" % cid)
		check(t.by_position("K").size() == 1 and t.by_position("C").size() == 3 and t.by_position("B").size() == 2 and t.by_position("S").size() == 1, "%s has 1K 3C 2B 1S" % cid)
		check(t.captain != null, "%s has a captain" % cid)
	var harpies := loader.build_team("club_holyhead_harpies")
	var has_gwenog := false
	for p in harpies.players:
		if p.id == "player_gwenog_jones":
			has_gwenog = true
	check(has_gwenog, "Gwenog Jones plays for the Harpies")
	check(harpies.captain != null and harpies.captain.id == "player_gwenog_jones", "Gwenog is captain")
	var r := _sim().run(loader.build_team("club_puddlemere_united"), loader.build_team("club_chudley_cannons"), 11)
	check(r.events.size() > 20, "a match between canon clubs produces events")


func test_interventions_apply_at_stoppage() -> void:
	print("manager interventions apply at the next stoppage")
	var a := SimLoader.synthetic_team("A", 12.0)
	a.is_human = true
	var b := SimLoader.synthetic_team("B", 12.0)
	var iv := [{"clock_s": 600, "team_id": "A", "tactics": {"mentality": 18, "seeker_catch": "ahead_by", "seeker_ahead_by": 30}}]
	var r := _sim().run(a, b, 21, iv)
	var change_tick := -1
	for e in r.events:
		if e.type == "tactics_change":
			change_tick = e.tick
	check(change_tick > 0 and change_tick * 5 >= 600, "there was a tactic change after minute 10 (tick %d)" % change_tick)
	check(int(r.final_tactics_home.get("mentality", 0)) == 18, "the tactic was applied in the match")
	check(int(a.tactics["mentality"]) == 10, "the team's base tactic does not change")


func test_long_matches_end() -> void:
	print("long matches end")
	var params := loader.params.duplicate(true)
	params["snitch"]["wild_snitch_chance"] = 1.0
	var a := SimLoader.synthetic_team("A", 12.0)
	var b := SimLoader.synthetic_team("B", 12.0)
	var longest := 0.0
	var saw_long := false
	for seed in range(1, 12):
		var r := MatchSim.new(loader.rules, params).run(a, b, seed)
		longest = maxf(longest, r.duration_minutes())
		check(r.end_reason in [MatchResult.EndReason.SNITCH, MatchResult.EndReason.MUTUAL_END], "ends by catch or agreement (%s)" % r.end_reason)
		for e in r.events:
			if e.type == "long_match_regime":
				saw_long = true
	check(longest < 48 * 60, "none reaches the hard cap (%.0f min)" % longest)
	print("  longest match: %.1f hours; long regime seen: %s" % [longest / 60.0, saw_long])


func test_step_api() -> void:
	print("step API: step() produces the same match as run()")
	var a := SimLoader.synthetic_team("A", 12.0)
	var b := SimLoader.synthetic_team("B", 12.0)
	var r1 := _sim().run(a, b, 77)
	var sim := _sim()
	sim.begin(a, b, 77)
	var steps := 0
	var got := 0
	while not sim.is_over():
		var evs := sim.step(50, 4)
		got += evs.size()
		steps += 1
	var r2 := sim.finish()
	check(r1.score_home == r2.score_home and r1.score_away == r2.score_away and r1.duration_ticks == r2.duration_ticks, "same result when stepping")
	check(got + 1 == r2.events.size(), "step returns every event except the throw-off (%d)" % got)
	check(steps > 5, "it stopped at several stoppages (%d)" % steps)
	var sim2 := _sim()
	a.is_human = true
	sim2.begin(a, b, 78)
	sim2.step(200, MatchEvent.Importance.NEVER_STOP)
	sim2.queue_tactics(a, {"mentality": 17})
	sim2.request_timeout(a)
	var saw_timeout := false
	for e in sim2.result.events:
		if e.type == "timeout" and e.team_id == "A":
			saw_timeout = true
	check(saw_timeout, "the requested time-out is granted")
	while not sim2.is_over():
		sim2.step(500, MatchEvent.Importance.NEVER_STOP)
	var r3 := sim2.finish()
	check(int(r3.final_tactics_home.get("mentality", 0)) == 17, "the queued tactic was applied during the time-out")
	a.is_human = false


func test_world_human_season() -> void:
	print("world: a full season with a human club")
	var w := WorldGenerator.new(loader).generate(3)
	w.player_club_id = "club_holyhead_harpies"
	w.my_club().manager_is_human = true
	var engine := GameEngine.new(loader, w)
	check(w.clubs.size() >= 13, "at least 13 clubs")
	check(w.players.size() >= 13 * 14, "at least 14 players per club (%d)" % w.players.size())
	for p in w.squad_of("club_holyhead_harpies"):
		check(p.gender == SimPlayer.Gender.F, "the Harpies only have witches (%s)" % p.name())
	check(engine._lineup_valid(w.my_club()), "valid initial lineup")
	var season := w.season
	var days := 0
	var matches := 0
	var stops_msg := 0
	while w.season == season and days < 400:
		var r := engine.advance_day()
		days += 1
		if r["reason"] == "match":
			matches += 1
			var ctx := engine.pending_match
			var sim: MatchSim = ctx.sim
			sim.step(300, MatchEvent.Importance.NEVER_STOP)
			sim.queue_tactics(ctx.home if ctx.home.is_human else ctx.away, {"mentality": 15})
			engine.complete_pending_match()
		if Inbox.open_count(w) > 0:
			stops_msg += 1
			for d in w.decisions.values():
				Inbox.close(w, d)
	check(w.season == season + 1, "the season ended (%d days)" % days)
	var cup_champs := 0
	for h in w.history:
		if str(h["competition_id"]).begins_with("comp_national_cup_") and int(h["season"]) == season and str(h["champion_id"]) != "":
			cup_champs += 1
	check(cup_champs == w.leagues().size(), "every league had its cup with a champion (%d of %d)" % [cup_champs, w.leagues().size()])
	var cont_champs := 0
	for h in w.history:
		if str(h["competition_id"]).begins_with("comp_cont_") and str(h["champion_id"]) != "":
			cont_champs += 1
	check(cont_champs == GameEngine.CONTINENTAL.size(), "every continental cup had a champion (%d of %d)" % [cont_champs, GameEngine.CONTINENTAL.size()])
	var booked := {}
	var clashes := 0
	for c in w.competitions.values():
		for fx in c.fixtures:
			if c.season != season:
				continue
			for k in ["home_id", "away_id"]:
				var key := "%s@%d" % [fx[k], int(fx["day"])]
				if booked.has(key):
					clashes += 1
				booked[key] = true
	check(clashes == 0, "no club with two matches on the same day (%d clashes)" % clashes)
	var cup_matches := 0
	var my_cup: Competition = w.competitions.get("comp_national_cup_british_irish_league_%d" % season)
	if my_cup != null:
		for fx in my_cup.fixtures:
			if fx["home_id"] == "club_holyhead_harpies" or fx["away_id"] == "club_holyhead_harpies":
				cup_matches += 1
	matches -= cup_matches
	check(cup_matches >= 1, "the human club played the cup (%d matches)" % cup_matches)
	var comp: Competition = w.competitions.values()[0]
	check(comp.is_finished() == false and comp.season == season + 1, "new calendar generated")
	check(not w.history.is_empty() and int(w.history[0]["season"]) == season, "history recorded")
	check(w.inbox.size() > 10, "the inbox received messages (%d)" % w.inbox.size())
	var kinds := {}
	for a in w.awards:
		kinds[str(a["kind"])] = true
	check(kinds.has("wronski") and kinds.has("top_scorer") and kinds.has("dangerous_dai") and kinds.has("team_of_season"), "end-of-season awards given (%s)" % str(kinds.keys()))
	check(w.news.size() >= 30, "the Prophet published editions (%d)" % w.news.size())
	var me := w.club("club_holyhead_harpies")
	check(me.season_summary.has(str(season)), "season summary for the human club")
	if w.manager_unemployed:
		check(not me.manager_is_human and w.player_club_id == "", "the sacking leaves the manager without a club")
		w.player_club_id = me.id
		w.manager_unemployed = false
		me.manager_is_human = true
	var ok_squad := w.squad_of(me.id).size() >= 7
	check(ok_squad, "the human club keeps a squad (%d)" % w.squad_of(me.id).size())
	for i in 60:
		var r := engine.advance_day()
		if r["reason"] == "match":
			engine.complete_pending_match()
		for d in w.decisions.values():
			Inbox.close(w, d)
	check(SaveManager.save(w, "_test_human") == OK, "save ok")
	var w2 := SaveManager.load("_test_human")
	check(w2 != null and w2.today == w.today and w2.players.size() == w.players.size() and w2.player_club_id == w.player_club_id, "load ok")
	check(w2.my_club().lineup == w.my_club().lineup, "the lineup survives saving")
	var e2 := GameEngine.new(loader, w2)
	for i in 45:
		var ra := engine.advance_day()
		var rb := e2.advance_day()
		if ra["reason"] == "match":
			engine.complete_pending_match()
		if rb["reason"] == "match":
			e2.complete_pending_match()
		for d in w.decisions.values():
			Inbox.close(w, d)
		for d in w2.decisions.values():
			Inbox.close(w2, d)
	var sa: Array = w.competitions.values()[0].standings()
	var sb: Array = w2.competitions.values()[0].standings()
	var same := sa.size() == sb.size()
	for i in sa.size():
		if not same:
			break
		if sa[i]["club_id"] != sb[i]["club_id"] or sa[i]["pts"] != sb[i]["pts"]:
			same = false
	check(same, "same table 45 days after loading")
	var pid: String = w.squad_of(w.player_club_id)[0].id
	check(w.player(pid) != null and w2.player(pid) != null and absf(w.player(pid).condition - w2.player(pid).condition) < 0.001 and absf(w.player(pid).ca() - w2.player(pid).ca()) < 0.001, "same player (condition and CA) after loading")
	var file := SaveManager.export_file("_test_human")
	check(file.size() > 1000, "a save exports to a file")
	var imported := SaveManager.import_file(file)
	var imported2 := SaveManager.import_file(file)
	check(imported != "" and imported2 != "" and imported != imported2, "importing twice makes two saves, never overwrites")
	var w3 := SaveManager.load(imported)
	var w_saved := SaveManager.load("_test_human")
	check(w3 != null and w3.today == w_saved.today and w3.players.size() == w_saved.players.size() and w3.player_club_id == w_saved.player_club_id, "an imported save loads the same world")
	check(SaveManager.import_file(PackedByteArray([1, 2, 3])) == "" and SaveManager.import_file("not a zip".to_utf8_buffer()) == "", "garbage is not imported")
	SaveManager.delete_save(imported)
	SaveManager.delete_save(imported2)
	SaveManager.delete_save("_test_human")


func test_loans() -> void:
	print("loans: request, offer, return at season end and save")
	var w := WorldGenerator.new(loader).generate(11)
	w.player_club_id = "club_puddlemere_united"
	w.my_club().manager_is_human = true
	var engine := GameEngine.new(loader, w)
	var me := w.my_club()
	var target: Player = null
	for p in w.players_sorted():
		var c: Club = w.clubs.get(p.club_id)
		if c != null and not c.manager_is_human and p.squad == Player.Squad.RESERVE and p.position == "C" and p.gender != SimPlayer.Gender.F and p.age(w.today) < 27:
			target = p
			break
	check(target != null, "there is a loan candidate")
	var owner_id := target.club_id
	var before := w.squad_of(me.id).size()
	var r := MarketActions.request_loan(w, target)
	check(bool(r["ok"]), "the loan is agreed (%s)" % str(r["key"]))
	check(target.club_id == me.id and target.is_on_loan() and target.loan.owner_id == owner_id, "the loanee plays for the human club and remembers its owner")
	check(w.squad_of(me.id).size() == before + 1 and not w.squad_of(owner_id).has(target), "per-club indexes updated")
	check(not MarketActions.make_offer(w, target, 100)["ok"], "a loanee cannot be bought")
	check(not MarketActions.renew_contract(w, target, 50, 2)["ok"], "a loanee cannot be renewed")
	var mine: Player = null
	for p in w.squad_of(me.id, [Player.Squad.RESERVE]):
		if not p.is_on_loan() and (mine == null or (p.position == "C" and mine.position != "C")):
			mine = p
	check(mine != null, "there is a reserve of ours to offer")
	MarketActions.toggle_loan_list(w, mine)
	check(mine.loan_listed and not mine.transfer_listed, "offered on loan (excludes sale)")
	var offered: Array = [mine]
	for p in w.squad_of(me.id, [Player.Squad.RESERVE]):
		if p != mine and not p.is_on_loan() and not p.loan_listed:
			MarketActions.toggle_loan_list(w, p)
			offered.append(p)
	me.lineup = WorldGenerator.best_lineup(w, me.id)
	me.lineup["C"][0] = target.id
	check(engine._lineup_valid(me) and Economy.lineup_has(me, target.id), "the loanee is a starter")
	var season := w.season
	var days := 0
	var seen_offered_loan := false
	while w.season == season and days < 400:
		var rr := engine.advance_day()
		days += 1
		for op in offered:
			if op.is_on_loan():
				seen_offered_loan = true
		if rr["reason"] == "match":
			engine.complete_pending_match()
		for d in w.decisions.values():
			Inbox.close(w, d)
	check(w.season == season + 1, "the season went by")
	check(not target.is_on_loan() and target.club_id != me.id, "the loanee left the human club at season end (returns to its owner, who may sell him)")
	check(not Economy.lineup_has(me, target.id) and engine._lineup_valid(me), "the lineup is rebuilt without the returned loanee")
	var saw_loan := false
	var mine_loaned := false
	for t in w.transfers:
		if bool(t.get("loan", false)):
			saw_loan = true
			if str(t["from_id"]) == me.id:
				mine_loaned = true
	check(saw_loan, "loans are kept in the transfer log")
	check(mine_loaned or seen_offered_loan, "an AI club took one of the offered reserves on loan")
	check(offered.all(func(p): return not p.is_on_loan() and (p.club_id == me.id or p.squad == Player.Squad.FREE)), "the offered reserves came back at season end")
	var p2: Player = null
	for p in w.players_sorted():
		var c: Club = w.clubs.get(p.club_id)
		if c != null and not c.manager_is_human and p.squad == Player.Squad.RESERVE and p.position == "B" and p.gender != SimPlayer.Gender.F and not p.is_on_loan():
			p2 = p
			break
	check(p2 != null, "there is a Beater to loan for the save check")
	if p2 != null:
		var owner2 := p2.club_id
		Economy.execute_loan(w, p2, me.id)
		check(p2.is_on_loan() and p2.loan.owner_id == owner2, "the Beater is on loan")
		check(SaveManager.save(w, "_test_loan") == OK, "save with a loan ok")
		var w2 := SaveManager.load("_test_loan")
		check(w2 != null and w2.player(p2.id).is_on_loan() and w2.player(p2.id).loan.owner_id == owner2 and w2.player(p2.id).club_id == me.id, "the loan survives saving")
		SaveManager.delete_save("_test_loan")


func test_negotiation() -> void:
	print("market: counter-offer, agent, haggling and swap")
	var w := WorldGenerator.new(loader).generate(13)
	w.player_club_id = "club_puddlemere_united"
	var me := w.my_club()
	me.manager_is_human = true
	me.balance = 50000
	me.transfer_budget = 50000
	var engine := GameEngine.new(loader, w)
	var target: Player = null
	for c in w.clubs_sorted():
		if c.id == me.id or c.manager_is_human:
			continue
		for q in w.squad_of(c.id, [Player.Squad.FIRST]):
			if q.position == "C" and not q.is_captain and q.gender != SimPlayer.Gender.F:
				target = q
				break
		if target != null:
			break
	var ask := Economy.asking_price(w, target)
	var r := MarketActions.make_offer(w, target, int(ask * 0.7))
	check(bool(r["ok"]), "offer sent")
	check(ask <= me.balance and ask <= me.transfer_budget, "the full asking price is affordable (%d)" % ask)
	check(str(MarketActions.make_offer(w, target, ask)["key"]) == "ui.market.offer_pending", "the offer cannot be duplicated")
	var countered := false
	for i in 6:
		engine.advance_day()
		for d in Inbox.open_of(w, Inbox.COUNTER):
			countered = true
			check(d.choices[0].verb == MarketActions.ACCEPT_COUNTER, "the counter-offer comes with answers")
			Inbox.choose(w, engine, d.owl_id, 0)
		if countered:
			break
	var offer := {}
	for o in w.pending_offers:
		if str(o["player_id"]) == target.id:
			offer = o
	check(countered or str(offer.get("status", "")) == "rejected" or str(offer.get("status", "")) == "accepted", "the AI answered the low offer (%s)" % str(offer.get("status", "")))
	if countered:
		check(str(offer["status"]) == "accepted" and int(offer["fee"]) >= int(ask * 0.7), "after paying the asking price, the club accepts")
		var asked := Inbox.open_of(w, Inbox.TERMS)
		if not asked.is_empty():
			var deal := MarketActions.find_offer(w, int(asked[0].key))
			var terms: Dictionary = deal.get("terms", {})
			check(int(terms.get("bonus", 0)) > 0 and int(terms.get("wage", 0)) > 0, "the agent's terms are on the offer")
			var before := me.balance
			Inbox.choose(w, engine, asked[0].owl_id, 0)
			check(target.club_id == me.id, "the player signed")
			check(me.balance == before - int(deal["fee"]) - int(terms["bonus"]), "transfer fee and bonus were paid")
			check(Inbox.find(w, Inbox.TERMS, asked[0].key) == null, "signing closes the agent's owl")
	var mine: Player = w.squad_of(me.id, [Player.Squad.RESERVE])[0]
	var t2: Player = null
	for c in w.clubs_sorted():
		if c.id == me.id:
			continue
		for q in w.squad_of(c.id, [Player.Squad.RESERVE]):
			if q.gender != SimPlayer.Gender.F and not q.is_on_loan():
				t2 = q
				break
		if t2 != null:
			break
	var r2 := MarketActions.make_swap_offer(w, t2, mine, 200)
	check(bool(r2["ok"]), "swap proposal sent")
	var found := false
	for o in w.pending_offers:
		if str(o["player_id"]) == t2.id and str(o.get("swap_player_id", "")) == mine.id:
			found = true
	check(found, "the offer records the offered player")


func test_national_job() -> void:
	print("national team: federation offer, own seven and managed match")
	var w := WorldGenerator.new(loader).generate(21)
	w.player_club_id = "club_puddlemere_united"
	w.my_club().manager_is_human = true
	w.manager["reputation"] = 1500
	w.manager["nationality"] = "eng"
	w.manager["seasons"] = 0
	check(not Career.nt_eligible(w, "nt_eng"), "with no seasons managed the federation does not offer the job")
	w.manager["seasons"] = 3
	check(Career.nt_eligible(w, "nt_eng"), "with reputation and experience, it does")
	var engine := GameEngine.new(loader, w)
	var offered := ""
	while WDate.month(w.today) != 10 or WDate.day_of_month(w.today) < 15:
		var r := engine.advance_day()
		if r["reason"] == "match":
			engine.complete_pending_match()
		for d in Inbox.open_of(w, Inbox.NT_JOB):
			offered = d.key
			Inbox.choose(w, engine, d.owl_id, 0)
		for d in w.decisions.values():
			Inbox.close(w, d)
		if offered != "" and WDate.month(w.today) == 8:
			break
	check(offered != "", "the federation offered the job (%s)" % offered)
	if offered == "":
		return
	var nt: Dictionary = w.national_teams[offered]
	check(bool(nt.get("human", false)) and NationalTeams.lineup_valid(w, nt, nt["lineup"]), "national team with a valid seven picked")
	check(engine._is_human(offered), "the national team's matches belong to the human")
	var pool := w.players_of_nationality(str(nt["country_id"]))
	var alt: Player = null
	for p in pool:
		if p.position == "C" and not nt["lineup"]["C"].has(p.id) and p.is_available():
			alt = p
			break
	if alt != null:
		nt["lineup"]["C"][0] = alt.id
	var played_nt := false
	var days := 0
	var conf_before: float = float(w.my_club().board.get("confidence", 60.0))
	var played_today := 0
	while not played_nt and days < 120:
		var r := engine.advance_day()
		days += 1
		if r["reason"] == "match":
			var f: Dictionary = engine.pending_match.fixture
			if str(f["home_id"]) == offered or str(f["away_id"]) == offered:
				conf_before = float(w.my_club().board.get("confidence", 60.0))
				var t: SimTeam = engine.pending_match.home if str(f["home_id"]) == offered else engine.pending_match.away
				check(t.is_human, "the national team's side is marked as human")
				var has_alt := false
				for sp in t.players:
					if alt != null and sp.id == alt.id:
						has_alt = true
				check(alt == null or has_alt or not alt.is_available(), "the seven picked by the human is used in the match")
				played_nt = true
			engine.complete_pending_match()
			if played_nt:
				check(absf(float(w.my_club().board.get("confidence", 60.0)) - conf_before) < 0.001, "a national-team match does not affect the club board's confidence")
				if engine.pending_match != null:
					var f2: Dictionary = engine.pending_match.fixture
					check(int(f2["day"]) == w.today and not bool(f2.get("played", false)) and (engine._is_human(str(f2["home_id"])) or engine._is_human(str(f2["away_id"]))), "the human's second match on the same day stays pending")
					engine.complete_pending_match()
		for d in w.decisions.values():
			Inbox.close(w, d)
	check(played_nt, "a national-team match was played (%d days)" % days)
	var unplayed := 0
	for comp in w.leagues():
		for f in comp.fixtures:
			if int(f["day"]) < w.today and not bool(f.get("played", false)) and (str(f["home_id"]) == w.player_club_id or str(f["away_id"]) == w.player_club_id):
				unplayed += 1
	check(unplayed == 0, "no club matches lost to national-team clashes (%d)" % unplayed)


func test_canon_cup_champion_reads_book_events() -> void:
	print("canon cup champion: the audit's House Cup exception comes from the cup_champion events, not the cup's name")
	check(Schools.canon_cup_champion(loader.events, "comp_school_hogwarts_1993") == "hs_hogwarts_gryffindor", "the 1993-94 Hogwarts cup is Gryffindor's by the book [PoA 15]")
	check(Schools.canon_cup_champion(loader.events, "comp_school_hogwarts_1994") == "", "no book champion for a cup without a cup_champion event")
	var without := loader.events.filter(func(e): return not (str(e.get("kind", "")) == "cup_champion" and int(e.get("season", -1)) == 1993))
	check(Schools.canon_cup_champion(without, "comp_school_hogwarts_1993") == "", "dropping the 1993 cup_champion event drops the exception")


func test_schools_and_book_events() -> void:
	print("schools and book events: Hogwarts 1993-94, Wood to Puddlemere, 1994 World Cup final")
	var w := WorldGenerator.new(loader).generate(5)
	check(Schools.students_of(w, "school_hogwarts").size() >= 30, "Hogwarts has students (%d)" % Schools.students_of(w, "school_hogwarts").size())
	check(w.competitions.has("comp_school_hogwarts_1993") and w.competitions["comp_school_hogwarts_1993"].fixtures.size() == 6, "House Cup with 6 matches")
	check(w.players_of_nationality("eng").all(func(p): return p.squad != Player.Squad.SCHOOL), "students are not picked for national teams")
	var n_cups := 0
	for cid in w.competitions.keys():
		if str(cid).begins_with("comp_school_") and str(cid).ends_with("_1993"):
			n_cups += 1
	check(w.houses.size() == 44 and n_cups == 11, "eleven schools with four houses and their cup (%d houses, %d cups)" % [w.houses.size(), n_cups])
	check(Schools.students_of(w, "school_wollemi", "Thylacine").size() >= 7, "invented houses have a full team")
	var engine := GameEngine.new(loader, w)
	var season := w.season
	var days := 0
	while w.season == season and days < 400:
		days += 1
		var r := engine.advance_day()
		if r["reason"] == "match":
			engine.complete_pending_match()
	check(w.season == season + 1, "the 1993-94 season ends (%d days)" % days)
	var hp: Player = w.player("student_harry_potter")
	check(hp != null and str(hp.broom["model_id"]) == "broom_firebolt", "Harry has the Firebolt from February 1994")
	check(hp != null and int(hp.stats_for(1993).get("catches", 0)) >= 2, "Harry caught the snitch against Ravenclaw and Slytherin (%d)" % int(hp.stats_for(1993).get("catches", 0)))
	var champ := ""
	for h in w.history:
		if str(h["competition_id"]) == "comp_school_hogwarts_1993":
			champ = str(h["champion_id"])
	check(champ == "hs_hogwarts_gryffindor", "Gryffindor wins the 1993-94 cup (%s)" % champ)
	var hw: Competition = w.competitions.get("comp_house_world_1994")
	check(hw != null and hw.club_ids.size() == 11 and hw.club_ids.has("hs_hogwarts_gryffindor"), "1994 House World Cup with the eleven champions (Gryffindor included)")
	var hw_champ := ""
	for h in w.history:
		if str(h["competition_id"]) == "comp_house_world_1994":
			hw_champ = str(h["champion_id"])
	check(hw != null and hw.is_finished() and Schools.is_house(hw_champ) and int(w.houses[hw_champ].get("world_cups", 0)) == 1, "the House World Cup ends before graduation (%s)" % hw_champ)
	check(hw != null and hw.display_name().contains("1994"), "House World Cup name: %s" % (hw.display_name() if hw != null else ""))
	var wood: Player = w.player("student_oliver_wood")
	check(wood != null and wood.club_id == "club_puddlemere_united", "Wood signs for Puddlemere United")
	check(not w.competitions.has("comp_school_hogwarts_1994"), "no Quidditch Cup at Hogwarts in 1994-95 (Triwizard Tournament)")
	check(w.competitions.has("comp_school_ilvermorny_1994"), "Ilvermorny does play its cup in 1994-95")
	days = 0
	while WDate.month(w.today) != 9 and days < 120:
		days += 1
		var r := engine.advance_day()
		if r["reason"] == "match":
			engine.complete_pending_match()
	check(WDate.month(w.today) == 9, "September 1994 is reached (%d days)" % days)
	var fc: Competition = w.competitions.get("comp_world_cup_1994_final")
	check(fc != null, "the 1994 World Cup knockout exists")
	if fc == null:
		return
	var ok_final := false
	var lost_before := []
	for f in fc.fixtures:
		if str(f.get("stage", "")) == "final":
			ok_final = str(f["home_id"]) == "nt_irl" and str(f["away_id"]) == "nt_bul" and int(f["score_home"]) == 170 and int(f["score_away"]) == 160 and str(f.get("snitch_player_id", "")) == "player_nt_bul_viktor_krum"
		elif bool(f.get("played", false)):
			for nt in ["nt_irl", "nt_bul"]:
				var home: bool = str(f["home_id"]) == nt
				if home or str(f["away_id"]) == nt:
					var mine: int = int(f["score_home"]) if home else int(f["score_away"])
					var theirs: int = int(f["score_away"]) if home else int(f["score_home"])
					if mine < theirs:
						lost_before.append("%s %s" % [nt, str(f.get("stage", ""))])
	check(ok_final, "1994 World Cup final: Ireland 170–160 Bulgaria, Krum catches the snitch")
	check(lost_before.is_empty(), "Ireland and Bulgaria lose no knockout tie before the final (%s)" % str(lost_before))
	w.settings["book_events"] = false
	check(engine._school_cup_skips(1994).is_empty(), "without book events the cup is not suspended")


func test_house_manager() -> void:
	print("Hogwarts mode: manage Gryffindor for a season, no Cup in 1994-95, save and load")
	var w := WorldGenerator.new(loader).generate(5)
	w.player_club_id = "hs_hogwarts_gryffindor"
	w.houses["hs_hogwarts_gryffindor"]["human"] = true
	w.manager = {"name": "Test", "nationality": "eng", "reputation": 1000, "career": []}
	var me := w.my_club()
	me.manager_is_human = true
	me.lineup = Schools.best_lineup(w, me.id)
	check(w.is_school_mode() and me.name == "Gryffindor" and w.squad_of(me.id).size() >= 7, "the house is the human team (%d students)" % w.squad_of(me.id).size())
	check(Schools.human_lineup_valid(w, me.id, me.lineup) and me.lineup["S"] == "student_harry_potter", "the automatic lineup is valid and Harry is the seeker")
	var engine := GameEngine.new(loader, w)
	var season := w.season
	var human_matches := 0
	var days := 0
	while w.season == season and days < 400:
		var r := engine.advance_day()
		days += 1
		if r["reason"] == "match":
			while engine.pending_match != null:
				var ctx := engine.pending_match
				if ctx.comp_id == "comp_school_hogwarts_1993" and (ctx.home.is_human or ctx.away.is_human):
					human_matches += 1
				engine.complete_pending_match()
		for d in w.decisions.values():
			Inbox.close(w, d)
	check(w.season == season + 1, "the season ended (%d days)" % days)
	check(human_matches == 3, "the house played its 3 Cup matches (%d)" % human_matches)
	var champ := ""
	for h in w.history:
		if str(h["competition_id"]) == "comp_school_hogwarts_1993":
			champ = str(h["champion_id"])
	check(champ != "", "the 1993-94 House Cup has a champion (%s)" % champ)
	var reviewed := false
	for m in w.inbox:
		if m.subject.key == "msg.house_season_end.subject":
			reviewed = true
	check(reviewed, "the head of house reviewed the school year")
	check(not w.houses[me.id].get("tryouts", {}).is_empty() or w.squad_of(me.id).size() >= 7, "the rollover opened tryouts for the manager's house")
	Schools.settle_tryouts(w, me.id)
	check(w.player_club_id == "hs_hogwarts_gryffindor" and w.squad_of(me.id).size() >= 7, "still in charge of the house with new students")
	check(w.league_of(me.id) == null, "no Cup in 1994-95 (Triwizard Tournament)")
	check(SaveManager.save(w, "_test_house") == OK, "save ok")
	var w2 := SaveManager.load("_test_house")
	check(w2 != null and w2.is_school_mode() and w2.my_club() != null and w2.my_club().manager_is_human, "the loaded game is still in Hogwarts mode")
	check(w2 != null and w2.my_club().lineup.size() == me.lineup.size(), "the house lineup is kept")
	SaveManager.delete_save("_test_house")


func test_competition_formats() -> void:
	print("formats: World Cup groups (2 + bonus) and knockout with replay")
	var c := Competition.new()
	c.id = "t"
	c.type = Competition.Type.WC_GROUPS
	c.format = {"table": "wins_bonus"}
	c.groups = {"A": ["nt_a", "nt_b", "nt_c", "nt_d"]}
	c.club_ids = ["nt_a", "nt_b", "nt_c", "nt_d"]
	var rng := SimRng.new(1)
	c.build_group_fixtures(rng, [100, 110, 120, 130, 140, 150])
	check(c.fixtures.size() == 12, "double round-robin group of 4: 12 matches (%d)" % c.fixtures.size())
	var played := 0
	for f in c.fixtures:
		if played == 0 and f["home_id"] == "nt_a":
			f["played"] = true; f["score_home"] = 320; f["score_away"] = 160; f["snitch_team_id"] = "nt_a"; f["duration_s"] = 3600
			played += 1
		elif played == 1 and f["home_id"] == "nt_b" and f["away_id"] != "nt_a":
			f["played"] = true; f["score_home"] = 220; f["score_away"] = 160; f["snitch_team_id"] = "nt_b"; f["duration_s"] = 7200
			played += 1
	var st := c.group_standings("A")
	check(st[0]["club_id"] == "nt_a" and int(st[0]["pts"]) == 7, "win by more than 150 = 7 points (%s %d)" % [st[0]["club_id"], int(st[0]["pts"])])
	check(st[1]["club_id"] == "nt_b" and int(st[1]["pts"]) == 3, "win by more than 50 = 3 points")
	var k := Competition.new()
	k.id = "k"
	k.type = Competition.Type.CUP
	k.build_bracket(rng, 1995, ["c1", "c2", "c3", "c4"], [200, 220], false)
	check(k.fixtures.size() == 2 and str(k.fixtures[0].get("stage", "")) == "sf", "bracket of 4: 2 semi-finals")
	k.fixtures[0]["played"] = true; k.fixtures[0]["score_home"] = 150; k.fixtures[0]["score_away"] = 150
	var info := k.advance_bracket(rng, 200)
	check(info["replay"] == true and k.fixtures.size() == 3 and bool(k.fixtures[2].get("is_replay", false)), "draw → replay scheduled")
	k.fixtures[2]["played"] = true; k.fixtures[2]["score_home"] = 200; k.fixtures[2]["score_away"] = 50
	k.fixtures[1]["played"] = true; k.fixtures[1]["score_home"] = 170; k.fixtures[1]["score_away"] = 30
	info = k.advance_bracket(rng, 205)
	check(info["new_round"] == true, "round complete → final created")
	var final_fx: Dictionary = k.fixtures[k.fixtures.size() - 1]
	check(str(final_fx.get("stage", "")) == "final" and [final_fx["home_id"], final_fx["away_id"]].has("c4") and [final_fx["home_id"], final_fx["away_id"]].has("c2"), "final c4 vs c2")
	final_fx["played"] = true; final_fx["score_home"] = 300; final_fx["score_away"] = 100
	info = k.advance_bracket(rng, 221)
	check(info["finished"] and k.champion_id == str(final_fx["home_id"]), "champion decided")


func test_time_cap_competition() -> void:
	print("competition with a 4-hour cap ends on goals")
	var w := WorldGenerator.new(loader).generate(5)
	var engine := GameEngine.new(loader, w)
	var comp := Competition.new()
	comp.id = "cap"
	comp.type = Competition.Type.WC_GROUPS
	comp.format = {"table": "wins_bonus", "time_cap_minutes": 240}
	var rules := engine._rules_for(comp)
	check(int(rules.get("time_cap_minutes", 0)) == 240, "match rules with a cap")
	var params := loader.params.duplicate(true)
	params["snitch"]["sight_base_per_tick"] = 0.0
	var a := SimLoader.synthetic_team("A", 12.0)
	var b := SimLoader.synthetic_team("B", 12.0)
	var r := MatchSim.new(rules, params).run(a, b, 3)
	check(r.end_reason == MatchResult.EndReason.TIME_CAP and r.duration_minutes() <= 240.1, "ends at 4 hours with no catch")


func test_world_full() -> void:
	print("full world: leagues, national teams, 1994 World Cup")
	var w := WorldGenerator.new(loader).generate(9)
	var leagues := w.leagues()
	check(leagues.size() >= 10, "at least 10 leagues (%d)" % leagues.size())
	var short := 0
	for comp in leagues:
		for cid in comp.club_ids:
			var pos := {"K": 0, "C": 0, "B": 0, "S": 0}
			for p in w.squad_of(cid):
				pos[p.position] += 1
			if pos["K"] < 1 or pos["C"] < 3 or pos["B"] < 2 or pos["S"] < 1:
				short += 1
	check(short == 0, "every club has a full squad (short: %d)" % short)
	check(w.national_teams.size() >= 40, "at least 40 national teams (%d)" % w.national_teams.size())
	var can_field := 0
	for nt_id in w.national_teams.keys():
		var t := NationalTeams.sim_team(w, nt_id, loader.brooms)
		if t.players.size() == 7:
			can_field += 1
	check(can_field == w.national_teams.size(), "every national team can field 7 (%d/%d)" % [can_field, w.national_teams.size()])
	var wc: Competition = w.competitions.get("comp_world_cup_1994_groups")
	check(wc != null and wc.groups.size() == 16, "16 groups in the 1994 World Cup")
	var played := 0
	for f in wc.fixtures:
		if bool(f.get("played", false)):
			played += 1
	check(played >= 32 and played < wc.fixtures.size(), "1992-93 groups preloaded (%d played of %d)" % [played, wc.fixtures.size()])
	var abroad := 0
	for p in w.players.values():
		if p.squad == Player.Squad.ABROAD:
			abroad += 1
	check(abroad >= 300, "'abroad' player pool (%d)" % abroad)
	check(w.free_agents().size() == 0, "'abroad' players are not free agents")


func test_contracts_and_sackings() -> void:
	print("termination (payoff and mutual consent) and AI sackings")
	var w := WorldGenerator.new(loader).generate(12)
	w.player_club_id = "club_puddlemere_united"
	var me := w.my_club()
	me.manager_is_human = true
	w.manager = {"name": "Test", "nationality": "eng", "reputation": 3000, "career": []}
	var engine := GameEngine.new(loader, w)
	var starter: Player = w.player(str(me.lineup["K"]))
	starter.morale = 80.0
	if starter.age(w.today) < 32:
		check(not bool(MarketActions.mutual_terms(w, starter)["ok"]), "a happy starter does not accept mutual termination")
	var bench: Player = null
	for q in w.squad_of(me.id, [Player.Squad.RESERVE]):
		if not Economy.lineup_has(me, q.id) and MarketActions.remaining_wages(w, q) > 0:
			bench = q
			break
	check(bench != null, "there is a substitute under contract")
	if bench != null:
		bench.transfer_listed = true
		var terms := MarketActions.mutual_terms(w, bench)
		check(bool(terms["ok"]) and int(terms["cost"]) < int(terms["remaining"]) and int(terms["cost"]) > 0, "mutual termination costs less than the remaining contract")
		var before := me.balance
		check(MarketActions.terminate_contract(w, bench, int(terms["cost"])), "mutual termination done")
		check(me.balance == before - int(terms["cost"]) and bench.club_id == "" and bench.squad == Player.Squad.FREE, "the agreed amount is paid and the player becomes free")
	var other: Player = null
	for q in w.squad_of(me.id, [Player.Squad.RESERVE, Player.Squad.YOUTH]):
		if MarketActions.remaining_wages(w, q) > 0:
			other = q
			break
	if other != null:
		var cost := MarketActions.remaining_wages(w, other)
		var b2 := me.balance
		MarketActions.terminate_contract(w, other, cost)
		check(me.balance == b2 - cost, "terminating pays the whole remaining contract")
	var ai: Club = w.club("club_chudley_cannons")
	var old := ai.manager_name
	for k in 10:
		engine._ai_sack(ai)
	check(ai.manager_name != "" and ai.history.get("managers", []).size() == 10 and str(ai.history["managers"][0]["name"]) == old, "the sacking changes the manager and is recorded in the club history")
	check(engine.vacancies().has(ai), "the sacking opens a vacancy")
	me.manager_is_human = false
	w.player_club_id = ""
	w.manager_unemployed = true
	w.manager["reputation"] = 200
	var before_offers := w.inbox.filter(func(m): return m.subject.key == "msg.job_offer.subject").size()
	engine._job_offers(1, false)
	var after_offers := w.inbox.filter(func(m): return m.subject.key == "msg.job_offer.subject").size()
	check(after_offers == before_offers + 1, "an unemployed manager at the reputation floor still gets a job offer")


func test_contract_negotiation() -> void:
	print("contracts: negotiation, counter-offer, breakdown, pre-contract, bonuses and raise")
	var w := WorldGenerator.new(loader).generate(13)
	w.player_club_id = "club_puddlemere_united"
	var me := w.my_club()
	me.manager_is_human = true
	me.balance = 100000
	var p: Player = w.player(str(me.lineup["S"]))
	var low := Contracts.default_terms(w, p, me, "renew")
	low["wage_weekly"] = maxi(1, int(low["wage_weekly"] * 0.5))
	var r := Contracts.propose(w, p, me, low, "renew", 0)
	check(not bool(r["accept"]) and not bool(r["final"]), "an offer at half gets a counter-offer")
	var r2 := Contracts.propose(w, p, me, r["counter"], "renew", 1)
	check(bool(r2["accept"]), "accepting the counter-offer closes the deal")
	var low_role := Contracts.default_terms(w, p, me, "renew")
	low_role["role"] = "reserve"
	var need_more := Contracts.required_value(w, p, me, low_role, "renew") > Contracts.required_value(w, p, me, Contracts.default_terms(w, p, me, "renew"), "renew")
	check(need_more, "offering a smaller role than requested demands a higher wage")
	var q: Player = w.player(str(me.lineup["K"]))
	var bad := Contracts.default_terms(w, q, me, "renew")
	bad["wage_weekly"] = 1
	Contracts.propose(w, q, me, bad, "renew", 0)
	Contracts.propose(w, q, me, bad, "renew", 1)
	var r3 := Contracts.propose(w, q, me, bad, "renew", 2)
	check(bool(r3["final"]) and q.talks_blocked_until > w.today, "three rejections and no negotiating for a month")
	var t: Dictionary = r2["counter"].duplicate()
	t["bonus_goal"] = 5
	t["yearly_rise_pct"] = 10
	check(bool(Contracts.sign(w, p, me, t, "renew")["ok"]) and int(p.contract["bonus_goal"]) == 5, "the renewal keeps the bonuses")
	var wage0 := int(p.contract["wage_weekly"])
	Contracts.yearly_rises(w)
	check(int(p.contract["wage_weekly"]) > wage0, "the yearly raise increases the wage")
	var b0 := me.balance
	Contracts.match_bonuses(w, me, {p.id: {"goals": 3}})
	check(me.balance == b0 - 15, "the goal bonus is paid")
	w.today = WDate.from_ymd(w.season + 1, 2, 1)
	var target: Player = null
	for c in w.clubs_sorted():
		if c.manager_is_human or (me.is_women_only()):
			continue
		for x in w.squad_of(c.id, [Player.Squad.FIRST, Player.Squad.RESERVE]):
			if not x.is_on_loan():
				x.contract["end_day"] = WDate.from_ymd(w.season + 1, 6, 30)
				target = x
				break
		if target != null:
			break
	check(Contracts.pre_contract_allowed(w, target, me), "in February a pre-contract can be offered to a player whose contract is ending")
	check(bool(Contracts.sign(w, target, me, Contracts.default_terms(w, target, me, "pre"), "pre")["ok"]), "pre-contract signed")
	Contracts.execute_pre_contracts(w)
	check(target.club_id == me.id and target.pre_contract == null, "at season end he arrives for free")


func test_happiness() -> void:
	print("happiness: a starter without minutes complains; promise, list and ignore")
	var w := WorldGenerator.new(loader).generate(14)
	w.player_club_id = "club_puddlemere_united"
	var me := w.my_club()
	me.manager_is_human = true
	var bench: Player = null
	for q in w.squad_of(me.id, [Player.Squad.FIRST, Player.Squad.RESERVE]):
		if not Economy.lineup_has(me, q.id):
			bench = q
			break
	bench.contract["role"] = "star"
	bench.contract["end_day"] = w.today + 100
	var before := w.inbox.size()
	for k in 12:
		w.today += 7
		Happiness.weekly(w, me)
	var complained := false
	for m in w.inbox.slice(0, w.inbox.size() - before + 1):
		if m.subject.key == "msg.complaint.subject":
			complained = true
	for m in w.inbox:
		if m.subject.key == "msg.complaint.subject":
			complained = true
	check(complained, "a star without minutes and an expiring contract asks to talk")
	check(Happiness.main_worry(bench) != "", "the profile shows the cause of the unhappiness")
	Happiness.answer(w, bench, "complaint_ignore")
	check(Happiness.answer(w, bench, "complaint_ignore") == "ui.complaint.wants_out" and bench.transfer_listed, "ignore him twice and he asks for a transfer")


func test_fm_features() -> void:
	print("FM 07: instalments, fans, records, staff, scouts, familiarity, monthly awards, ledger, career")
	var w := WorldGenerator.new(loader).generate(15)
	w.player_club_id = "club_puddlemere_united"
	var me := w.my_club()
	me.manager_is_human = true
	w.manager = {"name": "Test", "nationality": "eng", "reputation": 2000, "career": [{"club_id": me.id, "from": w.season}]}
	var engine := GameEngine.new(loader, w)
	var seller: Club = w.club("club_chudley_cannons")
	var b0 := me.balance
	var s0 := seller.balance
	var deferred := MarketActions.schedule_installments(w, me.id, seller.id, 3000, 3, "X")
	check(deferred == 2000 and w.pending_payments.size() == 1, "a transfer in 3 instalments defers two thirds")
	MarketActions.process_installments(w)
	MarketActions.process_installments(w)
	check(w.pending_payments.is_empty() and me.balance == b0 - 2000 and seller.balance == s0 + 2000, "instalments are paid monthly and then closed")
	check(not me.ledger.is_empty(), "the ledger records the human club's transactions")
	var m0 := Fans.mood(me)
	Fans.after_match(me, 300, 100)
	check(Fans.mood(me) > m0 and Fans.gate_factor(me) > 1.0, "a thrashing pleases the fans and raises the gate")
	Records.seed_canon(w)
	check(float(w.records["fastest_catch"]["value"]) == 3.5, "Plumpton's canon record (3.5 s)")
	Staff.ensure_pool(w, loader, w.rng(), me.region_id)
	var cands := Staff.candidates(w, "mediwizard")
	check(cands.size() == Staff.POOL_PER_ROLE, "there are candidates per role")
	me.balance = 100000
	var low: Dictionary = cands[-1]
	check(bool(Staff.hire(w, me, low)["ok"]) and str(me.staff["mediwizard"]["name"]) == str(low["name"]), "hire a mediwizard")
	check(bool(Staff.fire(w, me, "mediwizard")["ok"]) and not me.staff.has("mediwizard"), "fire him")
	var target: Player = w.squad_of("club_montrose_magpies")[0]
	me.scouts = [{"name": "S", "region_id": me.region_id, "quality": 3, "wage_monthly": 60}]
	check(Scouting.request(w, me, target) == "ui.scout.requested", "request a report")
	w.today = int(me.scout_reports[target.id]["due"])
	Scouting.daily(w, me, w.rng())
	check(me.scout_reports[target.id].has("ca_est"), "the report arrives with an estimate")
	me.tactics["chaser_formation"] = "porskoff"
	var f0 := me.familiarity_of("porskoff")
	engine._update_familiarity(me, "tactics")
	check(me.familiarity_of("porskoff") > f0, "familiarity with the formation in use rises")
	var lg := w.league_of(me.id)
	for q in w.squad_of(me.id).slice(0, 3):
		q.month_ratings = [8.0, 8.5]
	engine._monthly_awards()
	var got := false
	for a in w.monthly_awards:
		if str(a["competition_id"]) == lg.id and str(a["kind"]) == "player_month":
			got = true
	check(got, "player of the month awarded")
	engine.resign()
	check(w.manager_unemployed and str(w.manager["career"][0].get("reason", "")) == "resigned", "resigning is recorded in the history")
	engine._ai_sack(seller)
	check(engine.vacancies().has(seller) and engine.apply_for(seller.id), "apply for a vacancy")


func test_loans_options_friendlies() -> void:
	print("loan with purchase option, sell-on clause and national-team friendlies")
	var w := WorldGenerator.new(loader).generate(16)
	w.player_club_id = "club_puddlemere_united"
	var me := w.my_club()
	me.manager_is_human = true
	me.balance = 200000
	var engine := GameEngine.new(loader, w)
	var target: Player = null
	for c in w.clubs_sorted():
		if c.manager_is_human or c.is_women_only():
			continue
		for q in w.squad_of(c.id, [Player.Squad.RESERVE]):
			if q.gender != SimPlayer.Gender.F or not me.is_women_only():
				if Economy.ai_accepts_loan(w, c, q):
					target = q
					break
		if target != null:
			break
	check(target != null, "there is a loanable reserve")
	if target != null:
		var owner_id := target.club_id
		var ask := Economy.asking_price(w, target)
		check(str(MarketActions.request_loan(w, target, maxi(1, ask / 2))["key"]) == "ui.market.option_too_low", "an option below the price is rejected")
		me.transfer_budget = maxi(me.transfer_budget, ask)
		var r := MarketActions.request_loan(w, target, ask)
		check(bool(r["ok"]), "the loan with an option at the asking price is agreed (%s)" % str(r["key"]))
		if bool(r["ok"]):
			check(target.is_on_loan() and target.loan.buy_option == ask, "the loan keeps the purchase option")
			var ob: int = w.club(owner_id).balance
			check(MarketActions.exercise_option(w, target) and target.club_id == me.id and not target.is_on_loan() and w.club(owner_id).balance == ob + ask, "exercising the option: he becomes ours and the owner gets paid")
	var mine: Player = w.squad_of(me.id, [Player.Squad.RESERVE])[0]
	var buyer: Club = w.club("club_chudley_cannons")
	MarketActions._ask_bid(w, mine, buyer, 1000, true)
	var bid: Inbox.Decision = Inbox.open_of(w, Inbox.BID).back()
	check(bid.choices[1].verb == MarketActions.SELL_WITH_SELL_ON, "a first bid offers a sell-on variant")
	Inbox.choose(w, engine, bid.owl_id, 1)
	check(mine.club_id == buyer.id and int(mine.sell_on.get("pct", 0)) == 20, "sale with a sell-on percentage")
	var b0 := me.balance
	Economy.execute_transfer(w, mine, "club_montrose_magpies", 2000, 20, 2)
	check(me.balance == b0 + 400 and mine.sell_on.is_empty(), "when he is resold we get 20%")
	var ntid: String = w.national_team_ids_sorted()[0]
	w.manager["national_team_id"] = ntid
	engine._create_nt_friendlies(1994)
	var comp: Competition = w.competitions.get("comp_nt_friendlies_%s_1994" % ntid)
	check(comp != null and comp.fixtures.size() == 3, "three national-team friendlies in a season without a World Cup")
	engine._create_nt_friendlies(1993)
	check(not w.competitions.has("comp_nt_friendlies_%s_1993" % ntid), "no friendlies if that season has World Cup groups")


func test_long_match_regime_forced() -> void:
	print("long matches: the long regime, the night pause and the agreed end are reached")
	var rules := loader.rules.duplicate(true)
	rules["long_match_hours"] = 1
	rules["night_pause_after_hours"] = 2
	rules["time_cap_minutes"] = null
	var params := loader.params.duplicate(true)
	params["snitch"]["sight_base_per_tick"] = 0.0
	params["mutual_end"]["min_hours"] = 3
	params["mutual_end"]["avg_condition_below"] = 101.0
	params["mutual_end"]["lead_beyond_snitch_margin"] = -100000
	var a := SimLoader.synthetic_team("A", 12.0)
	var b := SimLoader.synthetic_team("B", 12.0)
	var r := MatchSim.new(rules, params).run(a, b, 6)
	var order: Array = []
	for e in r.events:
		if e.type in ["long_match_regime", "night_pause"] and not order.has(e.type):
			order.append(e.type)
	check(order == ["long_match_regime", "night_pause"], "the long regime starts, then the night pause (%s)" % str(order))
	check(r.end_reason == MatchResult.EndReason.MUTUAL_END and absf(r.duration_minutes() - 180.0) < 1.0, "the captains agree to end it at 3 h (%s, %.0f min)" % [r.end_reason, r.duration_minutes()])
	var c := SimLoader.synthetic_team("C", 12.0)
	var d := SimLoader.synthetic_team("D", 12.0)
	for t in [c, d]:
		for i in range(t.players.size() - 1, -1, -1):
			if t.players[i].position == "S":
				t.players.remove_at(i)
		t.invalidate()
	var r2 := MatchSim.new(loader.rules, loader.params).run(c, d, 6)
	check(r2.end_reason == MatchResult.EndReason.MUTUAL_END and r2.duration_minutes() <= float(loader.params["mutual_end"]["no_seekers_end_minutes"]) + 0.1, "without Seekers the match ends by agreement (%s, %.0f min)" % [r2.end_reason, r2.duration_minutes()])


func test_protect_beaters_shield() -> void:
	print("beaters: protecting our Seeker shields him from a Seeker hunt")
	var hunter := SimLoader.synthetic_team("B", 12.0, {"beater_instruction": "hunt_seeker"})
	var hits := {}
	var deflects_ok := true
	var deflects := 0
	for instr in ["nearest", "protect_seeker"]:
		var a := SimLoader.synthetic_team("A", 12.0, {"beater_instruction": instr})
		var sid: String = a.by_position("S", false)[0].id
		var n := 0
		for seed in range(1, 41):
			var r := MatchSim.new(loader.rules, loader.params).run(a, hunter, seed)
			n += int(r.player_stats[sid].get("bludger_hits_taken", 0))
			for e in r.events:
				if e.type == "bludger_deflect":
					deflects += 1
					if e.team_id != "A" or e.other_player_id != sid:
						deflects_ok = false
		hits[instr] = n
	check(hits["protect_seeker"] < hits["nearest"] * 0.8, "protect_seeker cuts the hits on our Seeker (%d vs %d)" % [hits["protect_seeker"], hits["nearest"]])
	check(deflects > 0 and deflects_ok, "deflections are by the protecting team, shielding its Seeker (%d)" % deflects)


func test_mentality_has_effect() -> void:
	print("mentality: an attacking mentality opens the game up")
	var goals := {}
	for m in [3, 17]:
		var a := SimLoader.synthetic_team("A", 12.0, {"mentality": m})
		var b := SimLoader.synthetic_team("B", 12.0, {"mentality": m})
		var g := 0
		var mins := 0.0
		for seed in range(1, 61):
			var r := MatchSim.new(loader.rules, loader.params).run(a, b, seed)
			g += int(r.home_stats.get("goals", 0)) + int(r.away_stats.get("goals", 0))
			mins += r.duration_minutes()
		goals[m] = g / maxf(mins / 60.0, 0.01)
	check(goals[17] > goals[3] * 1.04, "more goals per hour with attacking mentality (%.2f vs %.2f)" % [goals[17], goals[3]])


func test_fouls_seen_blatching_and_keeper_attack() -> void:
	print("fouls: unseen blatchings do not count; an illegal attack on the Keeper is always a foul")
	var params := loader.params.duplicate(true)
	params["fouls"]["base_chance_on_contact"] = 50.0
	params["fouls"]["referee_sees_base"] = 0.0
	var a := SimLoader.synthetic_team("A", 12.0)
	var b := SimLoader.synthetic_team("B", 12.0)
	var sim := MatchSim.new(loader.rules, params)
	sim.begin(a, b, 9)
	var off: SimPlayer = a.chasers()[0]
	var victim: SimPlayer = b.chasers()[0]
	var fouls := 0
	for i in 200:
		if sim._foul(off, a, victim, b, "contact"):
			fouls += 1
	check(fouls > 100 and off.blatching_count == 0 and not off.sent_off, "no unseen blatching counts towards a send-off (%d fouls)" % fouls)
	var all_fouls := true
	for i in 50:
		if not sim._foul(a.beaters()[0], a, b.keeper(), b, "keeper_attack"):
			all_fouls = false
	check(all_fouls, "keeper_attack always returns a foul")


func test_penalty_counts_as_conceded() -> void:
	print("penalties: a penalty goal counts as conceded by the Keeper")
	var params := loader.params.duplicate(true)
	params["fouls"]["penalty_success_base"] = 50.0
	var a := SimLoader.synthetic_team("A", 12.0)
	var b := SimLoader.synthetic_team("B", 12.0)
	var sim := MatchSim.new(loader.rules, params)
	sim.begin(a, b, 3)
	for i in 10:
		sim._penalty(a, b)
	var scored := int(a.stats.get("penalties_scored", 0))
	check(scored > 0 and int(b.keeper().stats.get("goals_conceded", 0)) == scored, "Keeper concedes every penalty goal (%d)" % scored)
	check(int(b.keeper().stats.get("saves", 0)) == 10 - scored, "the rest are saves")


func test_night_pause_applies_queued_tactics() -> void:
	print("long matches: queued tactics apply at the night pause")
	var params := loader.params.duplicate(true)
	params["quaffle"]["action_chance_per_tick"] = 0.0
	params["bludgers"]["event_chance_per_tick"] = 0.0
	params["snitch"]["sight_base_per_tick"] = 0.0
	var a := SimLoader.synthetic_team("A", 12.0)
	a.is_human = true
	var b := SimLoader.synthetic_team("B", 12.0)
	var sim := MatchSim.new(loader.rules, params)
	sim.begin(a, b, 4)
	sim.next_night_pause_h = 0.001
	sim.queue_tactics(a, {"seeker_catch": "if_wins"})
	sim.step(1, MatchEvent.Importance.NEVER_STOP)
	var saw_pause := false
	var saw_change := false
	for e in sim.result.events:
		saw_pause = saw_pause or e.type == "night_pause"
		saw_change = saw_change or (e.type == "tactics_change" and e.team_id == "A")
	check(saw_pause and saw_change, "the change is logged at the night pause")
	check(str(a.tactics.get("seeker_catch", "")) == "if_wins", "and it is in force")


func test_human_timeout_ai_reorganizes() -> void:
	print("time-outs: the AI opponent reorganizes at a human time-out")
	var reacted := 0
	for seed in range(1, 9):
		var a := SimLoader.synthetic_team("A", 12.0)
		a.is_human = true
		var b := SimLoader.synthetic_team("B", 12.0)
		var sim := MatchSim.new(loader.rules, loader.params)
		sim.begin(a, b, seed)
		sim.step(30, MatchEvent.Importance.NEVER_STOP)
		if sim.is_over():
			continue
		sim.queue_tactics(a, {"chaser_formation": "porskoff"})
		sim.request_timeout(a)
		if SimTactics.defence_of(b.tactics) == SimTactics.counter_to("porskoff"):
			reacted += 1
		sim.finish()
	check(reacted >= 3, "the AI answers the Porskoff with man-marking at the time-out (%d of 8)" % reacted)


func test_minutes_stop_when_out() -> void:
	print("minutes: an injured player is credited only the time played")
	var a := SimLoader.synthetic_team("A", 12.0)
	var b := SimLoader.synthetic_team("B", 12.0)
	var sim := MatchSim.new(loader.rules, loader.params)
	sim.begin(a, b, 12)
	sim.step(120, MatchEvent.Importance.NEVER_STOP)
	var victim: SimPlayer = a.beaters()[0]
	var out_min: int = sim.clock_s / 60
	sim._injure(victim, a, "bludger")
	while not sim.is_over():
		sim.step(500, MatchEvent.Importance.NEVER_STOP)
	var r := sim.finish()
	check(int(r.player_stats[victim.id]["minutes"]) == out_min, "injured at minute %d: %d minutes" % [out_min, int(r.player_stats[victim.id]["minutes"])])
	var full_ok := true
	for sp in a.players + b.players:
		if sp.out_clock_s < 0 and int(r.player_stats[sp.id]["minutes"]) != r.duration_s / 60:
			full_ok = false
	check(full_ok, "the players still on at the end are credited the whole match")


func test_broom_affects_dive() -> void:
	print("brooms: the broom's acceleration feeds the dive")
	var fast := SimPlayer.new()
	var slow := SimPlayer.new()
	for p in [fast, slow]:
		p.attrs = {"dive": 12.0}
	fast.broom = {"acceleration": 20.0}
	slow.broom = {"acceleration": 4.0}
	check(fast.fly("dive") > slow.fly("dive") + 5.0, "a better broom dives better (%.1f vs %.1f)" % [fast.fly("dive"), slow.fly("dive")])


func _veteran(age: int, position: String, prof: float, det: float) -> Player:
	var p := Player.new()
	p.position = position
	p.birth_day = WDate.from_ymd(1994 - age, 1, 1)
	for k in Player.ATTR_KEYS:
		p.attrs[k] = 12.0
	p.attrs["determination"] = det
	p.hidden["professionalism"] = prof
	p.pa = 200.0
	return p


func test_veteran_decline_personality_and_position() -> void:
	print("progression: professionals and Keepers decline more slowly")
	var w := World.new()
	w.today = WDate.from_ymd(1994, 6, 1)
	var club := Club.new()
	var pro := _veteran(32, "C", 19.0, 19.0)
	var lazy := _veteran(32, "C", 3.0, 3.0)
	var keeper := _veteran(35, "K", 10.0, 10.0)
	var seeker := _veteran(35, "S", 10.0, 10.0)
	var rng := SimRng.new(5)
	for i in 52:
		for p in [pro, lazy, keeper, seeker]:
			Progression.weekly(p, w, club, rng, 0)
	check(pro.ca() > lazy.ca() + 1.0, "the professional loses less (%.1f vs %.1f)" % [pro.ca(), lazy.ca()])
	check(float(pro.attrs["speed"]) > 10.0, "a 32-year-old professional keeps his Speed (%.1f)" % float(pro.attrs["speed"]))
	check(float(keeper.attrs["reflexes"]) > float(seeker.attrs["reflexes"]), "a Keeper's physique holds up better than a Seeker's")
	check(float(seeker.attrs["speed"]) > 8.0, "a 35-year-old does not collapse in one year (%.1f)" % float(seeker.attrs["speed"]))


func test_medical_level_scales() -> void:
	print("medical: every level shortens injuries")
	var days := {}
	for lvl in [1, 3, 5]:
		var rng := SimRng.new(77)
		var total := 0
		for i in 300:
			var p := Player.new()
			p.injury_days = 30
			var d := 0
			while p.injury_days > 0 and d < 100:
				Progression.daily(p, rng, lvl)
				d += 1
			total += d
		days[lvl] = total
	check(days[5] < days[3] and days[3] < days[1], "level 5 < 3 < 1 (%d, %d, %d days)" % [days[5], days[3], days[1]])
	var p1 := Player.new()
	var p5 := Player.new()
	p1.condition = 40.0
	p5.condition = 40.0
	Progression.daily(p1, SimRng.new(1), 1)
	Progression.daily(p5, SimRng.new(1), 5)
	check(p5.condition > p1.condition, "and recovers condition faster")


func test_world_dates_and_league_calendar() -> void:
	print("world: pre-1970 dates and league calendar")
	for s in ["1968-06-15", "1965-12-31", "1969-12-31", "1970-01-01", "1959-03-01"]:
		check(WDate.to_iso(WDate.from_string(s)) == s, "date %s round-trips (%s)" % [s, WDate.to_iso(WDate.from_string(s))])
	var w := WorldGenerator.new(loader).generate(5)
	var bil: Competition = w.competitions["comp_british_irish_league"]
	var pairs := {}
	for f in bil.fixtures:
		var pk := "%s|%s" % [f["home_id"], f["away_id"]]
		pairs[pk] = int(pairs.get(pk, 0)) + 1
	var in_window := 0
	var late := 0
	for c in w.competitions.values():
		if c.type != Competition.Type.LEAGUE:
			continue
		var window := WorldGenerator.national_window(c.season)
		for f in c.fixtures:
			if window.has(int(f["day"])):
				in_window += 1
			if int(f["day"]) >= WDate.from_ymd(c.season + 1, 7, 1):
				late += 1
	check(in_window == 0, "no league match while called-up squads are away (%d)" % in_window)
	check(late == 0, "every league match before the season ends on 1 July (%d)" % late)
	for md in GameEngine.PRESEASON_FRIENDLY_DATES:
		check(not GameEngine.WC_FINAL_STAGE_DATES.has(md), "the pre-season friendly of %d/%d is not a World Cup final-stage date" % [md[1], md[0]])
	var ok_pairs := true
	for ca in bil.club_ids:
		for cb in bil.club_ids:
			if ca != cb and int(pairs.get("%s|%s" % [ca, cb], 0)) != 1:
				ok_pairs = false
	check(ok_pairs, "each pair meets once at home and once away")
	var max_run := 0
	for cid in bil.club_ids:
		var run := 0
		var last := ""
		for f in bil.fixtures:
			if f["home_id"] != cid and f["away_id"] != cid:
				continue
			var ha := "H" if f["home_id"] == cid else "A"
			run = run + 1 if ha == last else 1
			last = ha
			max_run = maxi(max_run, run)
	check(max_run <= 4, "no club plays more than 4 home or away league matches in a row (%d)" % max_run)
	var total := 0
	for key in w._by_club.keys():
		total += w._by_club[key].size()
	check(total == w.players.size(), "player index and dictionary agree (%d vs %d)" % [total, w.players.size()])


func test_world_canon_and_pack_isolation() -> void:
	print("world: canon titles, Hogwarts data, pack isolation, abroad pool")
	var w := WorldGenerator.new(loader).generate(5)
	check(int(w.national_teams["nt_bra"]["world_cup_titles"]) == 5 and int(w.national_teams["nt_can"]["world_cup_titles"]) == 1 and int(w.national_teams["nt_aus"]["world_cup_titles"]) == 1, "canon World Cup titles are not double-counted")
	check(not w.national_teams.has("nt_tra") or int(w.national_teams["nt_tra"]["world_cup_titles"]) == 1, "Transylvania keeps its 1473 title")
	var has_1982 := false
	for h in w.history:
		if str(h.get("competition_id", "")) == "comp_world_cup_1982_final":
			has_1982 = true
	check(not has_1982, "1982 (champion unknown) is not written into the history")
	var girls := 0
	for p in Schools.students_of(w, "school_hogwarts", "Ravenclaw"):
		if p.gender == SimPlayer.Gender.F and p.id != "student_cho_chang":
			girls += 1
	check(girls == 0, "1993-94 Ravenclaw: Cho is the only girl (%d others)" % girls)
	var davies: Player = w.player("student_roger_davies")
	check(davies != null and Schools.school_year(davies, w) == 5, "Roger Davies is a 5th year in 1993-94")
	check(w.player("student_ron_weasley") == null and w.player("student_ginny_weasley") == null, "Ron and Ginny are not on the 1993-94 Gryffindor team")  # [OotP]
	var today0 := w.today
	w.today = WDate.from_ymd(1995, 7, 1)
	Schools._canon_joiners(w, loader, "school_hogwarts", 1995)
	var ron: Player = w.player("student_ron_weasley")
	var ginny: Player = w.player("student_ginny_weasley")
	check(ron != null and ron.position == "K" and ginny != null and ginny.house == "Gryffindor", "Ron and Ginny join Gryffindor at the 1995 rollover")
	w.remove_player("student_ron_weasley")
	w.remove_player("student_ginny_weasley")
	w.today = today0
	var by_tier := {}
	for p in w.players.values():
		if p.squad == Player.Squad.ABROAD and p.source == "filler":
			var tier := str(w.national_teams.get("nt_" + p.nationality, {}).get("tier", "weak"))
			if not by_tier.has(tier):
				by_tier[tier] = []
			by_tier[tier].append(p.ca())
	for tier in by_tier.keys():
		var arr: Array = by_tier[tier]
		arr.sort()
		var med: float = float(arr[arr.size() / 2])
		var rv: Array = NationalTeams.TIER_CA[tier]
		var mid: float = (float(rv[0]) + float(rv[1])) / 2.0
		check(absf(med - mid) <= 6.0, "abroad pool of %s nations sits on its tier target (median %.0f, target %.0f)" % [tier, med, mid])
	var cid0 := str(loader.club_ids()[0])
	var before := int(w.clubs[cid0].history.get("league_titles", 0))
	w.clubs[cid0].history["league_titles"] = before + 50
	var fac0 := int(w.clubs[cid0].facilities.get("training", 0))
	w.clubs[cid0].facilities["training"] = fac0 + 1
	var w2 := WorldGenerator.new(loader).generate(5)
	check(int(w2.clubs[cid0].history.get("league_titles", 0)) == before, "a game's club history does not leak into the next new game")
	check(int(w2.clubs[cid0].facilities.get("training", 0)) == fac0, "facility upgrades do not leak into the pack or the next new game")


func test_world_houses_and_staff() -> void:
	print("world: house views, school fallback lineup, vacant staff")
	var w := WorldGenerator.new(loader).generate(5)
	var ced: Player = w.player("student_cedric_diggory")
	check(ced != null, "Cedric Diggory is at Hogwarts")
	if ced != null:
		ced.injury_days = 10
		var t := Schools.sim_team(w, "hs_hogwarts_hufflepuff", loader.brooms)
		var seekers := 0
		for sp in t.players:
			if sp.position == "S":
				seekers += 1
		check(t.players.size() == 7 and seekers == 1, "a house without its Seeker fields a substitute as Seeker (%d players, %d Seekers)" % [t.players.size(), seekers])
		ced.injury_days = 0
	w.player_club_id = "hs_hogwarts_gryffindor"
	w.houses["hs_hogwarts_gryffindor"]["human"] = true
	w.manager = {"name": "Test", "nationality": "eng", "reputation": 1000, "career": []}
	var me := w.my_club()
	me.manager_is_human = true
	me.lineup = Schools.best_lineup(w, me.id)
	me.tactics["mentality"] = 17
	var rival := w.team_club("hs_hogwarts_slytherin")
	check(rival != null and rival.id == "hs_hogwarts_slytherin" and not rival.manager_is_human and rival.manager_name == "", "a rival house is a transient view with no human manager")
	check(w.my_club() == me and int(w.my_club().tactics["mentality"]) == 17 and w.my_club().lineup.size() == 4, "viewing a rival house keeps the player's house, lineup and tactics")
	check(me.country_id == "sco" and me.region_id == "british_isles", "Hogwarts houses carry their school's country and region")
	var ilv := w.team_club("hs_ilvermorny_thunderbird")
	check(ilv != null and ilv.region_id == "usa", "an Ilvermorny house is in the USA region")
	check(ilv != null and ilv.staff_level("assistant") == 2, "houses keep the school's level-2 support")
	var hd: Dictionary = w.houses["hs_hogwarts_gryffindor"]
	hd["human"] = false
	hd.erase("lineup")
	w.player_club_id = str(loader.club_ids()[0])
	w.to_dict()
	check(not w.houses["hs_hogwarts_gryffindor"].has("lineup"), "after leaving the house a save does not write its old lineup back")
	var c0: Club = w.clubs[str(loader.club_ids()[0])]
	c0.staff.erase("assistant")
	check(c0.staff_level("assistant") == 0, "a vacant staff role counts as level 0")


func test_world_knockouts_and_names() -> void:
	print("world: replay ids, neutral European Cup, seeding tiebreak, friendlies name, short national squad")
	var ko := Competition.new()
	ko.id = "ko"
	ko.type = Competition.Type.NATIONAL_CUP
	var krng := SimRng.new(3)
	ko.build_bracket(krng, 1995, ["club_a", "club_b"], [200], false)
	for i in 3:
		var fx: Dictionary = ko.fixtures[ko.fixtures.size() - 1]
		fx["played"] = true
		fx["score_home"] = 100
		fx["score_away"] = 100
		ko.advance_bracket(krng, int(fx["day"]))
	var ids := {}
	for fx2 in ko.fixtures:
		ids[str(fx2["id"])] = true
	check(ko.fixtures.size() == 4 and ids.size() == 4, "replays get their own fixture ids (%d fixtures, %d ids)" % [ko.fixtures.size(), ids.size()])
	var ec := Competition.new()
	ec.id = "comp_european_cup_1995"
	ec.type = Competition.Type.CUP
	ec.venues = ["venue.bodmin"]
	ec.build_bracket(SimRng.new(1), 1995, ["club_a", "club_b", "club_c", "club_d"], [200, 220], false)
	check(str(ec.fixtures[0].get("venue", "")) == "venue.bodmin", "European Cup ties are played at a neutral venue")
	var g := Competition.new()
	g.id = "g"
	g.type = Competition.Type.WC_GROUPS
	g.format = {"table": "wins_bonus"}
	g.groups = {"A": ["nt_a", "nt_b"], "B": ["nt_c", "nt_d"]}
	g.club_ids = ["nt_a", "nt_b", "nt_c", "nt_d"]
	g.fixtures = [
		{"id": "1", "round": 1, "day": 1, "home_id": "nt_a", "away_id": "nt_b", "played": true, "score_home": 200, "score_away": 100, "snitch_team_id": "nt_a", "duration_s": 7200},
		{"id": "2", "round": 1, "day": 1, "home_id": "nt_c", "away_id": "nt_d", "played": true, "score_home": 200, "score_away": 100, "snitch_team_id": "nt_c", "duration_s": 1800},
	]
	check(g.group_winners() == ["nt_c", "nt_a"], "group winners level on points and catches are seeded by the faster catch")
	var fr := Competition.new()
	fr.id = "comp_nt_friendlies_nt_eng_1995"
	fr.name = "Amistosos internacionales 1995-96"
	fr.name_en = "International friendlies 1995-96"
	var prev := TranslationServer.get_locale()
	TranslationServer.set_locale("de")
	var shown := fr.display_name()
	TranslationServer.set_locale(prev)
	check(not shown.begins_with("Amistosos") and shown.contains("1995-96"), "national-team friendlies are not shown in Spanish in German (%s)" % shown)
	var w := WorldGenerator.new(loader).generate(5)
	var keep := {"K": 1, "C": 2, "B": 2, "S": 1}
	for p in w.players_of_nationality("lux"):
		if int(keep.get(p.position, 0)) > 0:
			keep[p.position] = int(keep[p.position]) - 1
			p.injury_days = 0
			p.suspension_matches = 0
		else:
			p.injury_days = 30
	var t := NationalTeams.sim_team(w, "nt_lux", loader.brooms)
	var seekers := 0
	for sp in t.players:
		if sp.position == "S":
			seekers += 1
	check(t.players.size() == 6 and seekers == 1, "a national team with six available players keeps its Seeker (%d players, %d Seekers)" % [t.players.size(), seekers])


func test_nt_pick_squad_is_seven_of_the_nationality() -> void:
	print("national teams: the federation's seven are seven available players of the nationality")
	var w := WorldGenerator.new(loader).generate(5)
	var nt: Dictionary = w.national_teams.get("nt_irl", w.national_teams.values()[0])
	var l := NationalTeams.pick_squad(w, nt)
	var ids: Array = [l["K"]] + l["C"] + l["B"] + [l["S"]]
	check(ids.size() == 7, "pick_squad: seven slots")
	var seen := {}
	for pid in ids:
		var p: Player = w.players.get(str(pid))
		check(p != null, "pick_squad: every slot filled (%s)" % str(pid))
		if p == null:
			continue
		check(p.nationality == str(nt["country_id"]), "pick_squad: %s is of the nationality" % p.id)
		check(p.is_available(), "pick_squad: %s is available" % p.id)
		check(not seen.has(p.id), "pick_squad: %s picked once" % p.id)
		seen[p.id] = true
	check(NationalTeams.lineup_valid(w, nt, l), "pick_squad: the federation's seven is a valid lineup")
	check(not nt.has("lineup") or nt.get("lineup", {}).is_empty(), "pick_squad does not write the nt dictionary")


func test_world_cup_finals_seeded_for_national_page() -> void:
	print("national teams: canon World Cup finals are in the history")
	var w := WorldGenerator.new(loader).generate(5)
	for h in loader.world_cup_history.get("past", []):
		if str(h.get("champion", "")) == "":
			continue
		var cid := "comp_world_cup_%d_final" % int(h["year"])
		var found := false
		for e in w.history:
			if str(e["competition_id"]) == cid and str(e["champion_id"]) == "nt_" + str(h["champion"]):
				found = true
				check(str(e.get("runner_up_id", "")) == ("nt_" + str(h["runner_up"]) if str(h.get("runner_up", "")) != "" else ""), "WC %d: runner-up seeded" % int(h["year"]))
		check(found, "WC %d final in the history (national page record)" % int(h["year"]))
	var titles := 0
	for e in w.history:
		if str(e["competition_id"]).ends_with("_final") and str(e["competition_id"]).begins_with("comp_world_cup_") and str(e["champion_id"]) == "nt_can":
			titles += 1
	if w.national_teams.has("nt_can"):
		check(int(w.national_teams["nt_can"].get("world_cup_titles", 0)) == titles, "Canada: titles counter matches the finals won in the history")


func test_rival_house_view_keeps_own_house_cache() -> void:
	print("schools: viewing a rival house keeps the manager's own house")
	var w := WorldGenerator.new(loader).generate(7)
	var hids: Array = w.houses.keys()
	hids.sort()
	check(hids.size() >= 2, "houses exist")
	if hids.size() < 2:
		return
	w.player_club_id = str(hids[0])
	w.houses[hids[0]]["human"] = true
	w.manager = {"name": "Tester"}
	var mine := w.my_club()
	mine.tactics = SimTactics.defaults()
	mine.tactics["tempo"] = 19
	mine.lineup = {"K": "marker", "C": [], "B": [], "S": ""}
	var rival := w.house_club_view(str(hids[1]))
	check(rival != null and rival.id == str(hids[1]), "rival house view built")
	check(rival != null and rival.manager_name != "Tester", "rival house view is not managed by the human")
	check(w.my_club() == mine, "own house cache survives viewing a rival house")
	check(int(w.my_club().tactics.get("tempo", 0)) == 19 and str(w.my_club().lineup.get("K", "")) == "marker", "own house lineup and tactics survive")


func test_school_year_seven_is_graduating() -> void:
	print("schools screen: the graduating flag matches the rollover cut-off")
	var w := WorldGenerator.new(loader).generate(7)
	var cutoff := WDate.from_ymd(w.season + 1, 8, 31)
	var n := 0
	var bad := 0
	for p in Schools.students_of(w, "school_hogwarts"):
		n += 1
		if (Schools.school_year(p, w) >= Schools.FINAL_YEAR) != (p.age(cutoff) >= Schools.GRAD_AGE):
			bad += 1
	check(n > 0 and bad == 0, "school year 7 is exactly who graduates at rollover (%d of %d differ)" % [bad, n])


func test_suspension_is_served() -> void:
	print("engine: a red-card ban is served by the team's next fixture")
	var w := WorldGenerator.new(loader).generate(3)
	w.player_club_id = "club_holyhead_harpies"
	w.my_club().manager_is_human = true
	var engine := GameEngine.new(loader, w)
	var cid := "club_puddlemere_united"
	var banned: Player = w.squad_of(cid)[0]
	banned.suspension_matches = 1
	check(not banned.is_available(), "a suspended player is unavailable")
	var lg := w.league_of(cid)
	var count_played := func() -> int:
		var n := 0
		for f in lg.fixtures:
			if bool(f.get("played", false)) and (f["home_id"] == cid or f["away_id"] == cid):
				n += 1
		return n
	var played: int = count_played.call()
	var now := played
	var days := 0
	while now == played and days < 120:
		var r := engine.advance_day()
		if r["reason"] == "match":
			engine.complete_pending_match()
		for d in w.decisions.values():
			Inbox.close(w, d)
		days += 1
		now = count_played.call()
	check(now > played, "the club played its next league fixture (%d days)" % days)
	check(banned.suspension_matches == 0, "the ban was served (%d left)" % banned.suspension_matches)


func test_open_day_survives_reload_and_job_change() -> void:
	print("engine: an open match day is resumed after a reload and after a job change")
	var w := WorldGenerator.new(loader).generate(3)
	w.player_club_id = "club_holyhead_harpies"
	w.my_club().manager_is_human = true
	var engine := GameEngine.new(loader, w)
	var r := {"reason": ""}
	var days := 0
	while r["reason"] != "match" and days < 90:
		r = engine.advance_day()
		for d in w.decisions.values():
			Inbox.close(w, d)
		days += 1
	check(r["reason"] == "match", "reached a match day")
	if r["reason"] != "match":
		return
	var day := w.today
	var fx: Dictionary = engine.pending_match.fixture
	var engine2 := GameEngine.new(loader, w)
	var r2 := engine2.advance_day()
	check(r2["reason"] == "match" and w.today == day and engine2.pending_match != null, "after a reload the same day's match is rebuilt")
	engine2.pending_match = null
	w.my_club().manager_is_human = false
	w.player_club_id = "club_montrose_magpies"
	w.my_club().manager_is_human = true
	var r3 := engine2.advance_day()
	check(bool(fx.get("played", false)), "the old club's held-back fixture was played")
	check(w.today == day and (r3["reason"] != "match" or engine2.pending_match.fixture != fx), "the day is finished, not skipped (%s)" % r3["reason"])


func test_lineup_day_closes_after_resign_and_reload() -> void:
	print("engine: a match day stopped over the lineup closes after resigning, saving and reloading")
	var g = load("res://src/game/game_session.gd").new()
	g.loader = loader
	var prev_locale := TranslationServer.get_locale()
	g.new_game("club_puddlemere_united", "Test", "GB", 7)
	var w: World = g.world
	w.player(str(w.my_club().lineup.get("K", ""))).injury_days = 60
	var r := {"reason": ""}
	var days := 0
	while r["reason"] != "lineup" and days < 30:
		r = g.advance_one_day()
		for d in w.decisions.values():
			Inbox.close(w, d)
		days += 1
	var fx: Dictionary = g.engine.human_fixture_today().get("fixture", {})
	check(r["reason"] == "lineup" and not fx.is_empty(), "the advance stops over the lineup on a match day (%s)" % r["reason"])
	if fx.is_empty():
		TranslationServer.set_locale(prev_locale)
		g.free()
		return
	var day := w.today
	var fid := str(fx["id"])
	g.engine.resign()
	var slot := "qmtest_lineup_day_resign"
	var loaded: bool = g.save_game(slot) == OK and g.load_game(slot)
	SaveManager.delete_save(slot)
	check(loaded and g.world != w and g.world.today == day, "the career saves and reloads on the open day")
	var r2: Dictionary = g.advance_one_day()
	var f2 := {}
	for c in g.world.competitions.values():
		for f in c.fixtures:
			if str(f["id"]) == fid:
				f2 = f
	check(bool(f2.get("played", false)), "the old club's held-back fixture is played after the reload")
	check(g.world.today == day and g.engine.last_step == "close:result", "the open day closes without moving the calendar (%s, %s)" % [r2["reason"], g.engine.last_step])
	for d in g.world.decisions.values():
		Inbox.close(g.world, d)
	g.advance_one_day()
	check(g.world.today == day + 1, "the next advance moves the calendar one day")
	TranslationServer.set_locale(prev_locale)
	g.free()


func test_job_change_with_match_pending() -> void:
	print("engine: a job change with the manager's match pending plays every fixture of the day and closes it once")
	for take_nt in [true, false]:
		var w := WorldGenerator.new(loader).generate(7)
		w.player_club_id = "club_puddlemere_united"
		w.my_club().manager_is_human = true
		var engine := GameEngine.new(loader, w)
		var club_fx := {}
		var days := 0
		while club_fx.is_empty() and days < 60:
			for c in w.competitions.values():
				for f in c.fixtures_on(w.today + 1):
					if f["home_id"] == w.player_club_id or f["away_id"] == w.player_club_id:
						club_fx = f
			if club_fx.is_empty():
				engine.advance_day()
				Inbox.close_blocking(w)
				days += 1
		var nt_fx := {}
		for f in w.competitions["comp_world_cup_1994_groups"].fixtures:
			if not bool(f.get("played", false)):
				nt_fx = f
				break
		check(not club_fx.is_empty() and not nt_fx.is_empty(), "found the club's next match and a national fixture")
		if club_fx.is_empty() or nt_fx.is_empty():
			return
		var day := w.today + 1
		nt_fx["day"] = day
		engine.accept_national_job(str(nt_fx["home_id"]))
		var r := engine.advance_day()
		check(r["reason"] == "match" and engine.pending_match != null and engine.pending_match.fixture == club_fx, "the club match is pending on the day the national team also plays (%s)" % r["reason"])
		if engine.pending_match == null:
			return
		if take_nt:
			var other := ""
			for ntid in w.national_teams.keys():
				if ntid != str(nt_fx["home_id"]) and ntid != str(nt_fx["away_id"]):
					other = ntid
					break
			engine.accept_national_job(other)
			check(engine.pending_match != null, "the club match stays the manager's after taking another national team")
			engine.complete_pending_match()
			check(bool(nt_fx.get("played", false)), "the national fixture the manager left is played before the day closes")
		else:
			engine.accept_job("club_montrose_magpies")
			check(engine.pending_match == null, "the old club's match is no longer the manager's to play")
			r = engine.advance_day()
			check(bool(club_fx.get("played", false)) and w.today == day, "the AI plays the old club's match on the same day")
			check(r["reason"] == "match" and engine.pending_match != null and engine.pending_match.fixture == nt_fx, "the national match is still the manager's (%s)" % r["reason"])
			engine.complete_pending_match()
		Inbox.close_blocking(w)
		engine.advance_day()
		check(w.today == day + 1, "the next advance opens the next day: the match day closed once (take_nt=%s)" % take_nt)


func test_continental_draw_pots() -> void:
	print("engine: continental cup groups are drawn from pots")
	var w := WorldGenerator.new(loader).generate(5)
	var engine := GameEngine.new(loader, w)
	var y := w.season
	var gid := "comp_cont_bowman_wright_%d_groups" % (y + 1)
	var seen_a := {}
	for k in 4:
		w.competitions.erase(gid)
		w.rng_state += 17
		engine._create_continental_cups(y)
		var comp: Competition = w.competitions.get(gid)
		check(comp != null, "the Bowman Wright groups exist")
		if comp == null:
			return
		var ids: Array = comp.club_ids.duplicate()
		ids.sort_custom(func(a, b): return w.club(a).reputation > w.club(b).reputation if w.club(a).reputation != w.club(b).reputation else a < b)
		var n: int = comp.groups.size()
		var ok := true
		for g in comp.groups.keys():
			var members: Array = comp.groups[g]
			var pots := {}
			for m in members:
				pots[ids.find(m) / n] = true
			if members.size() != 4 or pots.size() != 4:
				ok = false
		check(ok, "every group has four clubs, one from each pot")
		var a: Array = comp.groups["A"].duplicate()
		a.sort()
		seen_a[",".join(a)] = true
	check(seen_a.size() > 1, "group A changes between draws (%d different)" % seen_a.size())


func test_european_cup_keeps_champions() -> void:
	print("engine: every European league champion is in the European Cup")
	var w := WorldGenerator.new(loader).generate(5)
	var engine := GameEngine.new(loader, w)
	var year := w.season + 2
	engine._create_european_cup(year)
	var comp: Competition = w.competitions.get("comp_european_cup_%d" % year)
	check(comp != null and comp.club_ids.size() == 16, "16 clubs drawn")
	if comp == null:
		return
	for lg in w.leagues():
		if not GameEngine.EUROPEAN_REGIONS.has(lg.region_id):
			continue
		var st: Array = []
		for h in w.history:
			if h["competition_id"] == lg.id and int(h["season"]) == w.season - 1:
				st = h["table"]
				break
		if st.is_empty():
			st = lg.standings()
		if st.size() >= 2:
			check(comp.has_team(str(st[0]["club_id"])), "%s champion qualifies" % lg.id)
	var wdays := {}
	for f in comp.fixtures:
		wdays[WDate.weekday(int(f["day"]))] = true
	check(wdays.size() == 1 and wdays.has(Time.WEEKDAY_TUESDAY), "European Cup rounds are on Tuesdays")


func test_nt_late_hire_not_reviewed() -> void:
	print("engine: a national coach hired after the groups is not sacked for them")
	var w := WorldGenerator.new(loader).generate(5)
	var engine := GameEngine.new(loader, w)
	var ntid: String = w.national_team_ids_sorted()[0]
	engine.accept_national_job(ntid)
	w.manager["nt_hired_day"] = WDate.from_ymd(1998, 8, 16)
	engine._national_review(1998)
	check(str(w.manager.get("national_team_id", "")) == ntid, "hired on 16 August, still in the job on 2 September")
	w.manager["nt_hired_day"] = WDate.from_ymd(1996, 9, 1)
	engine._national_review(1998)
	check(str(w.manager.get("national_team_id", "")) == "", "hired before the groups and out in them: sacked")


func test_clubless_players_age() -> void:
	print("engine: abroad players age and develop")
	var w := WorldGenerator.new(loader).generate(5)
	var engine := GameEngine.new(loader, w)
	var old: Player = null
	for p in w.club_players(""):
		if p.squad == Player.Squad.ABROAD and p.age(w.today) >= 31 and (old == null or p.age(w.today) > old.age(w.today)):
			old = p
	check(old != null, "there is a veteran abroad")
	if old == null:
		return
	var ca0 := old.ca()
	var sharp0 := old.sharpness
	for k in 20:
		w.today += 7
		engine._develop_clubless()
	check(old.ca() < ca0, "a 31+ abroad player declines (%.1f -> %.1f)" % [ca0, old.ca()])
	check(old.sharpness == sharp0, "abroad players keep their match sharpness")


func test_engine_short_house_plays() -> void:
	print("Hogwarts mode: a house that cannot field seven still plays (no endless 'lineup' stop)")
	var w := WorldGenerator.new(loader).generate(5)
	w.player_club_id = "hs_hogwarts_gryffindor"
	w.houses["hs_hogwarts_gryffindor"]["human"] = true
	w.manager = {"name": "Test", "nationality": "eng", "reputation": 1000, "career": []}
	var me := w.my_club()
	me.manager_is_human = true
	me.lineup = Schools.best_lineup(w, me.id)
	var far := WDate.from_ymd(w.season + 1, 6, 30)
	for pid in ["student_harry_potter", "student_fred_weasley", "student_george_weasley"]:
		var bp: Player = w.player(pid)
		if bp != null:
			bp.ban_until = far
	var engine := GameEngine.new(loader, w)
	engine.auto_fix_lineup = false
	var lg := w.league_of(me.id)
	var first_day := -1
	if lg != null:
		for f in lg.fixtures:
			if (str(f["home_id"]) == me.id or str(f["away_id"]) == me.id) and (first_day < 0 or int(f["day"]) < first_day):
				first_day = int(f["day"])
	check(first_day > w.today, "the house has a Cup match ahead")
	var blocked := false
	var guard := 0
	while w.today <= first_day and guard < 400:
		guard += 1
		var r := engine.advance_day()
		if r["reason"] == "lineup":
			blocked = true
			break
		if r["reason"] == "match":
			while engine.pending_match != null:
				engine.complete_pending_match()
		for d in w.decisions.values():
			Inbox.close(w, d)
	check(not blocked and w.today > first_day, "the short house plays its match day instead of stopping on the lineup")


func test_engine_left_club_no_offer() -> void:
	print("engine: the club that sacks the manager (or that they leave) does not offer the job straight back")
	var w := WorldGenerator.new(loader).generate(32)
	w.player_club_id = "club_puddlemere_united"
	var me := w.my_club()
	me.manager_is_human = true
	w.manager = {"name": "Test", "nationality": "eng", "reputation": 5000, "career": [{"club_id": me.id, "from": w.season}]}
	var engine := GameEngine.new(loader, w)
	var offers_from := func(cid: String) -> int:
		return 1 if Inbox.find(w, Inbox.JOB, cid) != null else 0
	me.board["confidence"] = 10.0
	engine._sack_human(me)
	check(offers_from.call(me.id) == 0, "no offer from the club that has just sacked the manager")
	check(float(me.board.get("confidence", 0.0)) == 55.0 and int(me.board.get("manager_since", -1)) == w.today, "the club's board starts afresh with the new AI manager")
	engine._ai_sack(me)
	check(offers_from.call(me.id) == 0 and not engine.vacancies().has(me), "nor through a later vacancy at that club")
	var other: Club = w.club("club_appleby_arrows")
	engine.accept_job(other.id)
	engine.resign()
	check(offers_from.call(other.id) == 0, "no offer from the club the manager has just resigned from")


func test_engine_ultimatum_stale() -> void:
	print("engine: a board ultimatum left over from an earlier season is dropped, not enforced")
	var w := WorldGenerator.new(loader).generate(31)
	w.player_club_id = "club_puddlemere_united"
	var me := w.my_club()
	me.manager_is_human = true
	w.manager = {"name": "Test", "nationality": "eng", "reputation": 1500, "career": [{"club_id": me.id, "from": w.season}]}
	var engine := GameEngine.new(loader, w)
	me.board["ultimatum"] = {"played": 99, "wins": 0}
	engine._board_ultimatum_check(me)
	check(not me.board.has("ultimatum") and w.player_club_id == me.id, "a stale ultimatum is erased and the manager keeps the job")


func test_engine_rollover_prize_and_late_arrival() -> void:
	print("engine: league prizes follow the pack; a June arrival is not credited with the season")
	var w := WorldGenerator.new(loader).generate(33)
	var bri: Competition = w.competitions["comp_british_irish_league"]
	var champ_id := str(bri.standings()[0]["club_id"])
	w.player_club_id = champ_id
	var me := w.my_club()
	me.manager_is_human = true
	w.manager = {"name": "Test", "nationality": "eng", "reputation": 1500, "seasons": 0, "titles": 0, "career": [{"club_id": champ_id, "from": w.season + 1, "from_day": w.today}]}
	var engine := GameEngine.new(loader, w)
	w.today = WDate.from_ymd(w.season + 1, 7, 1)
	engine._season_rollover()
	var key := "%04d-07" % WDate.year(w.today)
	var month: Dictionary = me.ledger.get(key, {})
	check(int(month.get("prizes", 0)) == int(bri.prizes.get("galleons_champion", -1)), "the league champion gets the pack's prize (%s)" % str(month))
	check(int(w.manager["seasons"]) == 0 and int(w.manager["titles"]) == 0 and int(w.manager["reputation"]) == 1500 and w.player_club_id == champ_id, "a manager who arrived after the season gets no season, title or reputation for it")


func test_engine_national_switch_and_sack() -> void:
	print("engine: an older national-team offer releases the team in charge; a sacking closes the spell")
	var w := WorldGenerator.new(loader).generate(34)
	w.player_club_id = "club_puddlemere_united"
	w.my_club().manager_is_human = true
	w.manager = {"name": "Test", "nationality": "eng", "reputation": 3000, "seasons": 5, "career": []}
	var engine := GameEngine.new(loader, w)
	engine.accept_national_job("nt_wal")
	engine.accept_national_job("nt_sco")
	check(not bool(w.national_teams["nt_wal"].get("human", false)) and bool(w.national_teams["nt_sco"].get("human", false)) and str(w.manager["national_team_id"]) == "nt_sco", "the previous national team goes back to the federation")
	var open := 0
	for e in w.manager["career"]:
		if not e.has("to"):
			open += 1
	check(open == 1, "only the current national-team spell stays open")
	engine._national_review(1998)
	var closed := false
	for e in w.manager["career"]:
		if str(e.get("club_id", "")) == "nt_sco" and str(e.get("reason", "")) == "sacked":
			closed = true
	check(str(w.manager.get("national_team_id", "")) == "" and closed, "the federation's sacking closes the national-team spell")


func test_engine_canon_players_and_prospects() -> void:
	print("engine: Krum is kept for the 2014 final; AI clubs keep their prospects; a house left without a captain gets one")
	var w := WorldGenerator.new(loader).generate(35)
	var engine := GameEngine.new(loader, w)
	var krum: Player = null
	for p in w.players.values():
		if p.last_name == "Krum" and p.nationality == "bul":
			krum = p
	check(krum != null and engine._book_event_players().has(krum.id), "Krum is protected from retirement while a book event still names him")
	var ai: Club = w.club("club_chudley_cannons")
	var youths := w.squad_of(ai.id, [Player.Squad.YOUTH])
	check(not youths.is_empty(), "the Cannons have a youth squad")
	if not youths.is_empty():
		var youth: Player = youths[0]
		youth.pa = 190.0
		check(engine._ai_wants_renewal(ai, youth), "an AI club renews a high-potential youth whatever his current ability")
	for p in Schools.students_of(w, "school_hogwarts", "Gryffindor"):
		if p.is_captain:
			w.remove_player(p.id)
			break
	engine._house_tryouts({"school_hogwarts|Gryffindor": true})
	var caps := 0
	for p in Schools.students_of(w, "school_hogwarts", "Gryffindor"):
		if p.is_captain:
			caps += 1
	check(caps == 1, "after a departure the house has exactly one captain (%d)" % caps)


func _ai_player(w: World, squads: Array) -> Player:
	for c in w.clubs_sorted():
		if c.manager_is_human or c.is_women_only():
			continue
		for x in w.squad_of(c.id, squads):
			if not x.is_on_loan():
				return x
	return null


func test_pre_contract_signing_fee_paid() -> void:
	print("market: the pre-contract signing fee is paid when the player arrives")
	var w := WorldGenerator.new(loader).generate(21)
	w.player_club_id = "club_puddlemere_united"
	var me := w.my_club()
	me.manager_is_human = true
	me.balance = 50000
	w.today = WDate.from_ymd(w.season + 1, 2, 1)
	var target := _ai_player(w, [Player.Squad.FIRST, Player.Squad.RESERVE])
	check(target != null, "there is a pre-contract target")
	if target == null:
		return
	target.contract["end_day"] = WDate.from_ymd(w.season + 1, 6, 30)
	var t := Contracts.default_terms(w, target, me, "pre")
	t["signing_fee"] = 700
	var b0 := me.balance
	check(bool(Contracts.sign(w, target, me, t, "pre")["ok"]) and me.balance == b0, "pre-contract signed; nothing is paid yet")
	check(target.clone().pre_contract.signing_fee == 700, "the deferred fee survives a save")
	Contracts.execute_pre_contracts(w)
	check(target.club_id == me.id and me.balance == b0 - 700, "on arrival the signing fee is paid (%d)" % (b0 - me.balance))


func test_installments_take_full_fee_off_budget() -> void:
	print("market: a purchase in instalments takes the whole fee off the transfer budget")
	var w := WorldGenerator.new(loader).generate(22)
	w.player_club_id = "club_puddlemere_united"
	var me := w.my_club()
	me.manager_is_human = true
	me.balance = 50000
	me.transfer_budget = 10000
	var target := _ai_player(w, [Player.Squad.RESERVE])
	check(target != null, "there is a reserve to buy")
	if target == null:
		return
	var t := Contracts.default_terms(w, target, me, "transfer", 3000)
	t["signing_fee"] = 0
	var b0 := me.balance
	var r := Contracts.sign(w, target, me, t, "transfer", 3000, "", 3)
	check(bool(r["ok"]) and target.club_id == me.id, "signed in three instalments")
	check(me.transfer_budget == 7000, "the budget drops by the full fee (%d)" % me.transfer_budget)
	check(me.balance == b0 - 1000 and int(w.transfers[0]["fee"]) == 3000, "only the first instalment is paid now; the record keeps the full fee")


func test_stale_agent_owl_voids_deal() -> void:
	print("market: an accepted bid is checked again when signing")
	var w := WorldGenerator.new(loader).generate(23)
	w.player_club_id = "club_puddlemere_united"
	var me := w.my_club()
	me.manager_is_human = true
	me.balance = 50000
	var target := _ai_player(w, [Player.Squad.RESERVE])
	check(target != null, "there is a reserve to bid for")
	if target == null:
		return
	var borrower: Club = null
	for c in w.clubs_sorted():
		if not c.manager_is_human and c.id != target.club_id and not c.is_women_only():
			borrower = c
			break
	var offer := _inject_accepted_offer(w, target, "", 500)
	Economy.execute_loan(w, target, borrower.id)
	var b0 := me.balance
	var bb := borrower.balance
	MarketActions._answer_terms(w, offer, MarketActions.SIGN)
	check(target.club_id == borrower.id and target.is_on_loan(), "the loaned-out player does not join us")
	check(me.balance == b0 and borrower.balance == bb, "no money changes hands")
	check(w.inbox[0].subject.key == "msg.deal_off.subject", "the manager is told the deal is off")


func test_stale_incoming_offer_is_void() -> void:
	print("market: an old incoming offer cannot sell a player the club no longer owns")
	var w := WorldGenerator.new(loader).generate(24)
	w.player_club_id = "club_puddlemere_united"
	var me := w.my_club()
	me.manager_is_human = true
	var engine := GameEngine.new(loader, w)
	var mine: Player = w.squad_of(me.id, [Player.Squad.RESERVE])[0]
	var a: Club = w.club("club_chudley_cannons")
	var b: Club = w.club("club_montrose_magpies")
	a.balance = 100000
	b.balance = 100000
	_sell_by_bid(w, engine, mine, b, 800)
	check(mine.club_id == b.id, "sold to the first bidder")
	var a0 := a.balance
	var me0 := me.balance
	_sell_by_bid(w, engine, mine, a, 1000, true)
	check(mine.club_id == b.id and a.balance == a0 and me.balance == me0 and mine.sell_on.is_empty(), "the stale owl does nothing")
	var harpies: Club = w.club("club_holyhead_harpies")
	var wizard: Player = null
	for q in w.squad_of(me.id, [Player.Squad.FIRST, Player.Squad.RESERVE]):
		if q.gender != SimPlayer.Gender.F and not q.is_on_loan():
			wizard = q
			break
	check(wizard != null and harpies != null, "there is a wizard to offer the Harpies")
	if wizard != null and harpies != null:
		harpies.balance = 100000
		_sell_by_bid(w, engine, wizard, harpies, 500)
		check(wizard.club_id == me.id, "the Harpies cannot buy a wizard")


func test_transfer_clears_pre_contract() -> void:
	print("market: a player sold to a third club no longer leaves on his pre-contract")
	var w := WorldGenerator.new(loader).generate(25)
	var p: Player = w.squad_of("club_chudley_cannons", [Player.Squad.FIRST])[0]
	p.pre_contract = Player.PreContract.new("club_montrose_magpies", {"wage_weekly": 20, "years": 2}, w.today)
	Economy.execute_transfer(w, p, "club_wimbourne_wasps", 500, 30, 3)
	Contracts.execute_pre_contracts(w)
	check(p.club_id == "club_wimbourne_wasps" and p.pre_contract == null, "he stays at the club that paid for him")


func test_objective_top_half_13() -> void:
	print("board: top half of 13 is 7th")
	var w := WorldGenerator.new(loader).generate(26)
	var c: Club = w.club("club_puddlemere_united")
	c.board["objective"] = "top_half"
	var n: int = w.league_of(c.id).club_ids.size()
	check(Economy.objective_pos(w, c) == (n + 1) / 2, "top half rounds up (%d clubs -> %d)" % [n, Economy.objective_pos(w, c)])
	check(n != 13 or Economy.objective_pos(w, c) == 7, "7th of 13")


func test_package_value_does_not_create_rows() -> void:
	print("contracts: valuing a package does not write stats")
	var w := WorldGenerator.new(loader).generate(27)
	w.player_club_id = "club_puddlemere_united"
	var me := w.my_club()
	var p: Player = w.squad_of(me.id, [Player.Squad.FIRST])[0]
	p.season_stats.erase(str(w.season - 1))
	Contracts.package_value(w, p, Contracts.default_terms(w, p, me, "renew"))
	check(not p.season_stats.has(str(w.season - 1)), "no empty row for last season")


func test_talk_cooldown_and_no_sharpness() -> void:
	print("press: one talk a week, and words don't sharpen anyone")
	var w := WorldGenerator.new(loader).generate(28)
	w.player_club_id = "club_puddlemere_united"
	var me := w.my_club()
	me.manager_is_human = true
	var p: Player = w.squad_of(me.id, [Player.Squad.FIRST])[0]
	p.morale = 50.0
	p.sharpness = 40.0
	Press.talk(w, p, "praise")
	var m1 := p.morale
	check(Press.talk(w, p, "demand") == "talk.player.too_soon" and p.morale == m1 and p.sharpness == 40.0, "a second talk the same week has no effect")
	w.today += 7
	Press.talk(w, p, "demand")
	check(p.sharpness == 40.0, "demand never raises sharpness")


func test_promise_across_rollover() -> void:
	print("press: a promise kept in May is still kept after 1 July")
	var w := WorldGenerator.new(loader).generate(29)
	w.player_club_id = "club_puddlemere_united"
	var me := w.my_club()
	me.manager_is_human = true
	var p: Player = w.squad_of(me.id, [Player.Squad.FIRST])[0]
	p.morale = 50.0
	p.season_stats[str(w.season)] = {"apps": 18}
	w.today = WDate.from_ymd(w.season + 1, 5, 20)
	check(Press.talk(w, p, "promise") == "talk.player.promise_ok", "promise made")
	if p.promise.is_empty():
		return
	p.season_stats[str(w.season)]["apps"] = 21
	w.season += 1
	w.today = int(p.promise["until"]) + 1
	var m0 := p.morale
	Press.check_promises(w)
	check(p.promise.is_empty() and p.morale > m0 and not p.transfer_listed, "three appearances before the rollover keep the promise")


func test_press_draw_with_catch() -> void:
	print("press: a 150-150 draw with our catch is a draw")
	var w := WorldGenerator.new(loader).generate(30)
	w.player_club_id = "club_puddlemere_united"
	var me := w.my_club()
	me.manager_is_human = true
	var r := MatchResult.new()
	r.home_id = me.id
	r.away_id = "club_chudley_cannons"
	r.score_home = 150
	r.score_away = 150
	r.snitch_team_id = me.id
	var qs := Press.questions(w, r, me.id, null)
	check(not qs.is_empty() and str(qs[0]["key"]) == "draw", "the first question is about the draw")


func test_awards_include_departed_players() -> void:
	print("awards: a player sold abroad mid-season is still a candidate")
	var w := WorldGenerator.new(loader).generate(31)
	var comp: Competition = w.league_of("club_puddlemere_united")
	var p: Player = w.squad_of("club_puddlemere_united", [Player.Squad.FIRST])[0]
	var abroad: Club = null
	for c in w.clubs_sorted():
		if not comp.club_ids.has(c.id) and not c.is_women_only():
			abroad = c
			break
	p.comp_stats[Player.comp_key(w.season, comp.id)] = {"apps": 12, "goals": 999, "catches": 0, "saves": 0, "rating_sum": 84.0, "minutes": 0, "fouls": 0, "hits": 0, "feints": 0, "injuries": 0}
	Economy.execute_transfer(w, p, abroad.id, 100, 20, 2)
	var scorer := {}
	for a in Awards.season_awards(w, comp, w.season):
		if str(a["kind"]) == "top_scorer":
			scorer = a
	check(str(scorer.get("player_id", "")) == p.id, "the departed top scorer wins")
	check(str(scorer.get("club_id", "")) == "club_puddlemere_united", "credited to the league club he played for")


func test_awards_credit_released_players_club() -> void:
	print("awards: a player released mid-season is credited to the club he played for")
	var w := WorldGenerator.new(loader).generate(31)
	var me: Club = w.club("club_puddlemere_united")
	var comp: Competition = w.league_of(me.id)
	var p: Player = w.squad_of(me.id, [Player.Squad.FIRST])[0]
	p.comp_stats[Player.comp_key(w.season, comp.id)] = {"apps": 12, "goals": 999, "catches": 0, "saves": 0, "rating_sum": 84.0, "minutes": 0, "fouls": 0, "hits": 0, "feints": 0, "injuries": 0}
	MarketActions.release_player(w, p)
	check(p.club_id == "" and p.squad == Player.Squad.FREE, "the player is a free agent")
	check(w.transfers.any(World.is_release) and Economy.moved_this_season(w).is_empty(), "the release is logged and does not count as a move")
	var scorer := {}
	for a in Awards.season_awards(w, comp, w.season):
		if str(a["kind"]) == "top_scorer":
			scorer = a
	check(str(scorer.get("player_id", "")) == p.id, "the released top scorer wins")
	check(str(scorer.get("club_id", "")) == me.id, "credited to the club that released him")


func test_award_news_without_league_club() -> void:
	print("awards: a winner with no league club this season gets the award news line without a club")
	var w := WorldGenerator.new(loader).generate(31)
	w.player_club_id = "club_puddlemere_united"
	var me := w.my_club()
	me.manager_is_human = true
	w.manager = {"name": "Test", "nationality": "eng", "reputation": 1500, "seasons": 0, "titles": 0, "career": [{"club_id": me.id, "from": w.season, "from_day": w.today}]}
	var comp: Competition = w.league_of(me.id)
	var squad := w.squad_of(me.id, [Player.Squad.FIRST])
	var p: Player = squad[0]
	var q: Player = squad[1]
	for c in w.clubs_sorted():
		if not comp.club_ids.has(c.id) and not c.is_women_only():
			p.club_id = c.id
			break
	p.comp_stats[Player.comp_key(w.season, comp.id)] = {"apps": 12, "goals": 999, "catches": 0, "saves": 0, "rating_sum": 84.0, "minutes": 0, "fouls": 0, "hits": 0, "feints": 0, "injuries": 0}
	q.comp_stats[Player.comp_key(w.season, comp.id)] = {"apps": 12, "goals": 0, "catches": 9, "saves": 0, "rating_sum": 120.0, "minutes": 0, "fouls": 0, "hits": 0, "feints": 0, "injuries": 0}
	var engine := GameEngine.new(loader, w)
	w.today = WDate.from_ymd(w.season + 1, 7, 1)
	engine._season_rollover()
	var award := {}
	for a in w.awards:
		if str(a.get("kind", "")) == "top_scorer" and str(a.get("competition_id", "")) == comp.id:
			award = a
			break
	check(str(award.get("player_id", "")) == p.id and str(award.get("club_id", "x")) == "", "the top scorer moved with no transfer row has no league club (%s)" % str(award))
	var mine := 0
	var mine_with_club := 0
	var others := 0
	var items: Array = w.news_buffer.duplicate()
	items.append_array(w.news)
	for it in items:
		var key := str(it.get("key", ""))
		if key != "news.award" and key != "news.award_no_club":
			continue
		if str(it["args"]["player"][1]) != p.id:
			others += 1
		elif key == "news.award_no_club" and not it["args"].has("club"):
			mine += 1
		else:
			mine_with_club += 1
	var won := w.awards.filter(func(a): return str(a.get("player_id", "")) == p.id and str(a.get("competition_id", "")) == comp.id).size()
	check(mine == won and won > 0 and mine_with_club == 0, "each award of the club-less winner gets its line, with no club (%d of %d, %d)" % [mine, won, mine_with_club])
	check(others > 0, "the other winners still get their line with the club (%d)" % others)


func test_press_new_in_charge_counts_spell_matches() -> void:
	print("press: 'new in charge' lasts the spell's first official matches, friendlies aside")
	var w := WorldGenerator.new(loader).generate(35)
	w.player_club_id = "club_puddlemere_united"
	var me := w.my_club()
	me.manager_is_human = true
	w.manager = {"name": "Test", "nationality": "eng", "reputation": 1500, "seasons": 0, "titles": 0, "career": [{"club_id": me.id, "from": w.season}]}
	var engine := GameEngine.new(loader, w)
	check(Press._new_in_charge(w, me.id, 3), "new in charge before any match")
	var official := 0
	var friendlies := 0
	var days := 0
	while official < 3 and days < 200:
		var r := engine.advance_day()
		days += 1
		if r["reason"] == "match":
			engine.complete_pending_match()
		for d in w.decisions.values():
			Inbox.close(w, d)
		official = 0
		friendlies = 0
		for c in w.competitions.values():
			for f in c.fixtures:
				if bool(f.get("played", false)) and (str(f["home_id"]) == me.id or str(f["away_id"]) == me.id):
					if c.type == Competition.Type.FRIENDLY:
						friendlies += 1
					else:
						official += 1
	var spell: Dictionary = w.manager["career"][-1]
	check(int(spell.get("official_matches", -1)) == official and official >= 3, "the spell counts its official matches (%d of %d)" % [int(spell.get("official_matches", -1)), official])
	check(friendlies > 0, "friendlies were played and not counted (%d)" % friendlies)
	check(not Press._new_in_charge(w, me.id, 3) and Press._new_in_charge(w, me.id, official + 1), "no longer new after three official matches")
	var other := ""
	for c in w.clubs_sorted():
		if c.id != me.id and c.league_id == me.league_id and not c.is_women_only():
			other = c.id
			break
	engine.accept_job(other)
	check(Press._new_in_charge(w, other, 3) and int(w.manager["career"][-1].get("official_matches", 0)) == 0, "a new spell starts its own count")


func test_keeper_depth_blocks_loans_and_sales() -> void:
	print("market: a club with two Keepers neither sells nor lends one; with three it can")
	var w := WorldGenerator.new(loader).generate(36)
	var owner: Club = null
	var backup: Player = null
	for c in w.clubs_sorted():
		var ks := w.squad_of(c.id, Player.Squad.SENIOR).filter(func(q): return q.position == "K" and not q.is_captain and not q.is_on_loan())
		if ks.size() == 2 and w.squad_of(c.id, Player.Squad.SENIOR).filter(func(q): return q.position == "K").size() == 2:
			owner = c
			backup = ks[1]
			break
	check(owner != null, "a club with exactly two Keepers")
	if owner == null:
		return
	check(not Economy.seller_can_release(w, backup) and not Economy.ai_accepts_loan(w, owner, backup), "its second Keeper is neither sold nor lent")
	var borrower: Club = null
	for c in w.clubs_sorted():
		if c.id != owner.id and not c.is_women_only() and w.club_players(c.id).size() < 16 and w.squad_of(c.id, Player.Squad.SENIOR).filter(func(q): return q.position == "K").size() <= 2:
			borrower = c
			break
	backup.loan_listed = true
	var empty := {"K": [] as Array[Player], "C": [] as Array[Player], "B": [] as Array[Player], "S": [] as Array[Player]}
	var loans := {"K": [backup] as Array[Player], "C": [] as Array[Player], "B": [] as Array[Player], "S": [] as Array[Player]}
	for i in 20:
		Economy.ai_transfer_club(w, SimRng.new(i), [], {"pool": empty, "loan_pool": loans}, borrower)
	check(backup.club_id == owner.id and not backup.is_on_loan(), "an AI club short of Keepers does not borrow the owner's second one")
	var third: Player = null
	for p in w.players_sorted():
		if p.position == "K" and p.club_id != owner.id and p.club_id != "" and not p.is_on_loan():
			third = p
			break
	w.move_player(third, owner.id, Player.Squad.RESERVE)
	check(Economy.seller_can_release(w, backup), "with a third Keeper one can go")


func test_staff_severance_expired_contract() -> void:
	print("staff: an expired contract rolls on; firing still costs 10 weeks")
	var w := WorldGenerator.new(loader).generate(32)
	var c: Club = w.club("club_puddlemere_united")
	c.staff["mediwizard"] = {"name": "Test", "level": 2, "wage": 10, "contract_end": w.today - 30}
	check(Staff.severance(w, c, "mediwizard") == 100, "ten weeks of wages")
	check(Staff.contract_end_shown(w, c.staff["mediwizard"]) == 0, "the past date is not shown")


func test_matchdays_played_by_matches() -> void:
	print("news: matchday = matches played, not the highest round")
	var comp := Competition.new()
	comp.fixtures = [
		{"id": "f1", "round": 3, "day": 10, "home_id": "a", "away_id": "b", "played": true},
		{"id": "f2", "round": 1, "day": 20, "home_id": "c", "away_id": "d", "played": false},
	]
	check(NewsGenerator.matchdays_played(comp) == 1, "one match played is matchday 1")


func test_prune_pending_offers() -> void:
	print("market: old closed offers are pruned")
	var w := WorldGenerator.new(loader).generate(33)
	w.player_club_id = "club_puddlemere_united"
	w.my_club().manager_is_human = true
	var engine := GameEngine.new(loader, w)
	while WDate.day_of_month(w.today) == 15:
		w.today += 1
	w.pending_offers = [
		{"id": 1, "day": w.today - 100, "resolve_day": w.today - 100, "player_id": "x", "from_id": "club_puddlemere_united", "to_id": "club_chudley_cannons", "fee": 1, "status": "rejected", "direction": "out"},
		{"id": 2, "day": w.today - 10, "resolve_day": w.today - 10, "player_id": "x", "from_id": "club_puddlemere_united", "to_id": "club_chudley_cannons", "fee": 1, "status": "rejected", "direction": "out"},
		{"id": 3, "day": w.today - 100, "resolve_day": w.today + 5, "player_id": "x", "from_id": "club_puddlemere_united", "to_id": "club_chudley_cannons", "fee": 1, "status": "pending", "direction": "out"},
	]
	MarketActions.process_pending(w, engine)
	var ids: Array = w.pending_offers.map(func(o): return int(o["id"]))
	check(ids.size() == 2 and ids.has(2) and ids.has(3), "the 100-day-old rejected offer is gone (%s)" % str(ids))


func test_session_text_params() -> void:
	print("session: ground venues, whole numbers in live text, and stored news after a save")
	var w := WorldGenerator.new(loader).generate(5)
	var gs = load("res://src/game/game_session.gd").new()
	gs.world = w
	var c: Club = w.clubs.values()[0]
	check(gs.venue_text({"venue": "ground:" + c.id}) == Grounds.name_of(c) and Grounds.name_of(c) != "", "a ground: venue names the ground")
	check(gs.t("{sh}|{x}", {"sh": 170.0, "x": 2.5}) == "170|2.5", "whole floats render as ints, fractions stay")
	Inbox.tell(w, &"from.board", "msg.welcome.subject", "msg.welcome.body", {"balance": Say.money(12000)})
	w.news.push_front({"day": w.today, "edition": 1, "items": [NewsGenerator.item("news.match.result", 4, {"sh": Say.num(170), "sa": Say.num(20), "venue": Say.venue("ground:" + c.id)})]})
	var owl_before := Say.render(w.inbox[0].body)
	var news_before := Say.Phrase.from_dict(w.news[0]["items"][0])
	check(SaveManager.save(w, "_test_params") == OK, "save with stored text ok")
	check(not FileAccess.file_exists(SaveManager.save_dir("_test_params").path_join("world.json.gz.tmp")), "no temp file left after saving")
	var w2 := SaveManager.load("_test_params")
	check(w2 != null, "load ok")
	if w2 != null:
		gs.world = w2
		check(Say.render(w2.inbox[0].body) == owl_before and owl_before.contains(gs.galleons(12000)), "the owl reads the same after loading, money with its unit")
		var news_after := Say.Phrase.from_dict(w2.news[0]["items"][0])
		check(news_after.signature() == news_before.signature(), "news items hash the same after loading")
		check(Say.render(news_after).contains(Grounds.name_of(c)) and not Say.render(news_after).contains(".0"), "scores show no .0 after loading")
	SaveManager.delete_save("_test_params")
	gs.free()


func test_say_round_trip() -> void:
	print("say: stored text renders the same after a save, with whole numbers at every depth")
	var w := WorldGenerator.new(loader).generate(5)
	var gs = load("res://src/game/game_session.gd").new()
	gs.world = w
	var c: Club = w.clubs.values()[0]
	var p: Player = w.club_players(c.id)[0]
	var lg := w.league_of(c.id)
	var inner := Say.phrase("{name} ({detail})", {"name": Say.player(p), "detail": Say.money(1200)})
	var ph := Say.phrase("{n}|{g}|{k}|{e}|{c}|{v}|{l}|{s}|{d}|{x}|{t}", {"n": Say.num(170), "g": Say.money(12000),
		"k": Say.key("pos.K"), "e": Say.club(c), "c": Say.comp(lg.id), "v": Say.venue("ground:" + c.id),
		"l": Say.list([Say.num(3), inner.as_arg(), Say.team(w, c.id)]), "s": Say.season(1994), "d": Say.duration(7500),
		"x": Say.plain("pos.K @g:5"), "t": inner.as_arg()})
	var fresh := Say.render(ph)
	check(fresh.begins_with("170|%s|%s|%s|%s|%s|" % [gs.galleons(12000), TranslationServer.translate("pos.K"), c.name, lg.display_name(), Grounds.name_of(c)]), "every constructor renders its value (%s)" % fresh)
	check(fresh.contains("|1994-95|") and fresh.contains("|pos.K @g:5|"), "seasons render as years and plain text is never decoded")
	check(fresh.contains("3%s%s (%s)" % [NewsGenerator.list_sep(), p.name(), gs.galleons(1200)]), "list items and nested phrases render in place")
	w.settings["say_test"] = ph.to_dict()
	check(SaveManager.save(w, "_test_say") == OK, "a world holding a phrase saves")
	var w2 := SaveManager.load("_test_say")
	check(w2 != null, "and loads")
	if w2 != null:
		gs.world = w2
		var back := Say.Phrase.from_dict(w2.settings["say_test"])
		check(Say.render(back) == fresh, "the loaded phrase renders like the fresh one (%s)" % Say.render(back))
		check(not Say.render(back).contains(".0"), "whole numbers show no .0 at any depth")
		check(back.signature() == ph.signature(), "the signature is the same after loading")
		check(Say.render(back, true).contains("[url=club:%s]" % c.id) and Say.render(back, true).contains("[url=player:%s]" % p.id), "entities link by id, nested ones too")
	check(Say.Phrase.from_dict({"key": "{a}", "args": {"a": ["zz", 1]}}).signature() != "", "an unreadable stored value does not crash")
	SaveManager.delete_save("_test_say")
	gs.free()


## Every kind in Inbox.KINDS, asked about its record the way its producer asks, answers every choice it offers: no
## answer falls through to Reply.unhandled. The table below is the KINDS list's other half (record and verbs).
func test_inbox_kinds_answer() -> void:
	print("inbox: every question kind is answered by its domain")
	var w := WorldGenerator.new(loader).generate(41)
	w.player_club_id = "club_puddlemere_united"
	var me := w.my_club()
	me.manager_is_human = true
	me.balance = 500000
	me.transfer_budget = 500000
	w.manager = {"name": "Test", "nationality": "eng", "reputation": 3000, "career": [{"club_id": me.id, "from": w.season}]}
	var engine := GameEngine.new(loader, w)
	var gs = load("res://src/game/game_session.gd").new()
	gs.world = w
	var mine: Player = w.squad_of(me.id, [Player.Squad.RESERVE])[0]
	var buyer: Club = w.club("club_chudley_cannons")
	var target := _ai_player(w, [Player.Squad.RESERVE])
	var other: Club = w.club("club_appleby_arrows")
	var go := func(label: String, to: StringName) -> Inbox.Choice: return Inbox.Choice.go(label, to)
	var asks := {
		Inbox.BID: func() -> Inbox.Decision:
			MarketActions._ask_bid(w, mine, buyer, 1000, true)
			return Inbox.open_of(w, Inbox.BID).back(),
		Inbox.COUNTER: func() -> Inbox.Decision:
			var o := _inject_accepted_offer(w, target, "", 500)
			o["status"] = "countered"
			o["counter"] = 600
			return Inbox.ask(w, Inbox.Decision.new(Inbox.COUNTER, str(o["id"]), [Inbox.Choice.new(MarketActions.ACCEPT_COUNTER, "ui.action.accept_counter"),
				Inbox.Choice.new(MarketActions.COUNTER_AGAIN, "ui.action.counter_again"), Inbox.Choice.new(MarketActions.WITHDRAW_OFFER, "ui.action.withdraw", {}, Inbox.BACK)]), &"from.club_secretary", "msg.offer_countered.subject", "msg.offer_countered.body"),
		Inbox.TERMS: func() -> Inbox.Decision:
			var o := _inject_accepted_offer(w, target, "", 500)
			return Inbox.ask(w, Inbox.Decision.new(Inbox.TERMS, str(o["id"]), [Inbox.Choice.new(MarketActions.SIGN, "ui.action.sign"), Inbox.Choice.new(MarketActions.NEGOTIATE, "ui.action.negotiate"),
				Inbox.Choice.new(MarketActions.COUNTER_TERMS, "ui.action.contract_counter"), Inbox.Choice.new(MarketActions.WITHDRAW_TERMS, "ui.action.withdraw", {}, Inbox.BACK)]), &"from.agent", "msg.agent_terms.subject", "msg.agent_terms.body"),
		Inbox.LOAN_OPTION: func() -> Inbox.Decision:
			return Inbox.ask(w, Inbox.Decision.new(Inbox.LOAN_OPTION, mine.id, [Inbox.Choice.new(MarketActions.EXERCISE_OPTION, "ui.action.exercise_option"), Inbox.Choice.new(MarketActions.DECLINE_OPTION, "ui.action.decline_option", {}, Inbox.BACK)]), &"from.club_secretary", "msg.loan_option.subject", "msg.loan_option.body"),
		Inbox.JOB: func() -> Inbox.Decision:
			engine._post_job_offer(other)
			return Inbox.find(w, Inbox.JOB, other.id),
		Inbox.NT_JOB: func() -> Inbox.Decision:
			return Inbox.ask(w, Inbox.Decision.new(Inbox.NT_JOB, "nt_eng", [Inbox.Choice.new(GameEngine.ACCEPT_NT_JOB, "ui.action.accept_nt"), Inbox.Choice.new(GameEngine.REJECT_NT_JOB, "ui.action.reject", {}, Inbox.BACK)]), &"from.federation", "msg.nt_offer.subject", "msg.nt_offer.body"),
		Inbox.SPONSOR: func() -> Inbox.Decision:
			engine._sponsor_offers(me)
			return Inbox.find(w, Inbox.SPONSOR, me.id),
		Inbox.CONTRACTS: func() -> Inbox.Decision:
			engine._ask_contract_review(me, [mine], "jan")
			return Inbox.find(w, Inbox.CONTRACTS, "jan"),
		Inbox.TRYOUTS: func() -> Inbox.Decision:
			return Inbox.ask(w, Inbox.Decision.new(Inbox.TRYOUTS, "hs_hogwarts_gryffindor", [Inbox.Choice.new(Schools.HOLD_TRYOUTS, "ui.tryouts.hold"), Inbox.Choice.new(Schools.LEAVE_TO_CAPTAIN, "ui.tryouts.leave_to_captain", {}, Inbox.PLAIN)]), &"from.head_of_house", "msg.tryouts.subject", "msg.tryouts.body"),
		Inbox.COMPLAINT: func() -> Inbox.Decision:
			Happiness._complain(w, mine)
			return Inbox.find(w, Inbox.COMPLAINT, mine.id),
		Inbox.PRE_PRESS: func() -> Inbox.Decision:
			return Inbox.ask(w, Inbox.Decision.new(Inbox.PRE_PRESS, "fx", [go.call("ui.press.go_pre", &"press")]), &"from.prophet", "msg.pre_press.subject", "msg.pre_press.body"),
		Inbox.LINEUP: func() -> Inbox.Decision:
			return Inbox.ask(w, Inbox.Decision.new(Inbox.LINEUP, "fx", [go.call("ui.action.fix_lineup", &"lineup")]).blocking(), &"from.assistant", "msg.lineup_blocked.subject", "msg.lineup_blocked.body"),
		Inbox.ACK: func() -> Inbox.Decision:
			return Inbox.ask(w, Inbox.Decision.new(Inbox.ACK, "", [go.call("ui.view_profile", &"player"), Inbox.Choice.ok()]).blocking(), &"from.board", "msg.ultimatum.subject", "msg.ultimatum.body"),
	}
	check(asks.keys().size() == Inbox.KINDS.size() and Inbox.KINDS.all(func(k): return asks.has(k)), "the test asks every kind in KINDS")
	for kind in Inbox.KINDS:
		var first: Inbox.Decision = asks[kind].call()
		check(first != null and first.kind == kind, "%s is asked" % kind)
		if first == null:
			continue
		for i in first.choices.size():
			var d: Inbox.Decision = first if i == 0 else asks[kind].call()
			if d == null or d.choices.size() <= i:
				check(false, "%s can be asked again for choice %d" % [kind, i])
				continue
			var c := d.choices[i]
			var r := Inbox.choose(w, engine, d.owl_id, i, c.verb != GameEngine.ACCEPT_JOB)
			var unhandled := not r.settles and not r.changed and r.go == &"" and r.dialog == &"" and r.confirm == null
			check(not unhandled, "%s answers %s" % [kind, c.verb])
			if r.settles:
				check(Inbox.find(w, kind, d.key) == null or d.key == "" or Inbox.find(w, kind, d.key) != d, "%s %s closes its question" % [kind, c.verb])
			Inbox.close(w, d)
	gs.free()


## Owl state is reached through Inbox only, and stored text through Say only: no file of src/ outside the allowed
## ones touches World.inbox, the old encodings, or a Say value's packed form.
func test_inbox_access_fenced() -> void:
	print("inbox: owls and stored text are reached through Inbox and Say only")
	var rules := [
		["[\\w)\\]]\\.inbox\\b(?![.\"\\w])", ["src/game/inbox.gd", "src/world/world.gd"]],
		["\\b(unresolved_messages|post_message|link_entities|param_text|t_variant|is_key_value|_whole_numbers_in_texts)\\b", []],
		["\"@g:|\"@t:|\"@comp:", []],
		["\\._packed\\b|\\._args\\b", ["src/game/say.gd"]],
		["\\{[^{}]*Say\\.[^{}]*\"\\w+_ids?\": [^{}]*\\}", []],
	]
	var hits: Array = []
	for path in _gd_files("res://src"):
		var rel: String = str(path).trim_prefix("res://")
		var lines := FileAccess.get_file_as_string(str(path)).split("\n")
		for rule in rules:
			if rule[1].has(rel):
				continue
			var re := RegEx.create_from_string(rule[0])
			for i in lines.size():
				if not lines[i].strip_edges().begins_with("#") and re.search(lines[i]) != null:
					hits.append("%s:%d" % [rel, i + 1])
	check(hits.is_empty(), "no owl or stored-text access outside Inbox and Say (%s)" % ", ".join(hits.slice(0, 8)))


func _gd_files(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_gd_files(dir.path_join(sub)))
	return out


## The records that used to live in owls: each survives what used to lose it (the cap, "Delete read", a save) and
## each question closes from its record.
func test_inbox_records() -> void:
	print("inbox: questions live in world records, survive the cap, Delete read and a save, and close from them")
	var w := WorldGenerator.new(loader).generate(42)
	w.player_club_id = "club_puddlemere_united"
	var me := w.my_club()
	me.manager_is_human = true
	w.manager = {"name": "Test", "nationality": "eng", "reputation": 3000, "career": [{"club_id": me.id, "from": w.season}]}
	var engine := GameEngine.new(loader, w)
	var gs = load("res://src/game/game_session.gd").new()
	gs.world = w
	var mine: Player = w.squad_of(me.id, [Player.Squad.RESERVE])[0]
	var buyer: Club = w.club("club_chudley_cannons")
	MarketActions._ask_bid(w, mine, buyer, 1000, true)
	var bid: Inbox.Decision = Inbox.open_of(w, Inbox.BID).back()
	var offer := MarketActions.find_offer(w, int(bid.key))
	check(str(offer.get("direction", "")) == "in" and str(offer.get("status", "")) == "offered" and int(offer["fee"]) == 1000, "an incoming bid is a pending_offers entry")
	check(bid.deadline == w.today + GameEngine.OFFER_DAYS, "it can be answered for OFFER_DAYS")
	for i in Inbox.CAP + 10:
		Inbox.tell(w, &"from.board", "msg.ultimatum_met.subject", "msg.ultimatum_met.body", {}, Inbox.QUIET)
	check(w.inbox.size() == Inbox.CAP and Inbox.view(w, bid.owl_id, false) != null, "the cap drops old notices, never an open question")
	Inbox.mark_all_read(w)
	Inbox.delete_read(w)
	check(w.inbox.size() == 1 and Inbox.find(w, Inbox.BID, bid.key) == bid, "Delete read keeps the open question")
	engine._ask_contract_review(me, [mine], "jan")
	var review := Inbox.find(w, Inbox.CONTRACTS, "jan")
	check(review != null and Inbox.blocking(w) != null and Inbox.blocking(w).id == review.owl_id, "the contract review blocks the day")
	check(SaveManager.save(w, "_test_inbox") == OK, "a world with open questions saves")
	var w2 := SaveManager.load("_test_inbox")
	check(w2 != null and w2.decisions.size() == w.decisions.size(), "and loads with its questions")
	if w2 != null:
		var b2 := Inbox.find(w2, Inbox.BID, bid.key)
		check(b2 != null and typeof(b2.deadline) == TYPE_INT and b2.deadline == bid.deadline and Inbox.blocking(w2) != null, "deadlines are ints and blocking survives the save")
		gs.world = w2
		check(Inbox.view(w2, b2.owl_id, true).body == Inbox.view(w, bid.owl_id, true).body, "the owl reads the same after loading")
		gs.world = w
	Inbox.choose(w, engine, review.owl_id, 1)
	check(int(mine.contract.get("let_go_season", -1)) == w.season and Inbox.blocking(w) == null, "Let them go is written on the player's contract and ends the block")
	Inbox.mark_all_read(w)
	Inbox.delete_read(w)
	check(int(mine.contract.get("let_go_season", -1)) == w.season, "Delete read cannot change the decision")
	w.today = bid.deadline + 1
	Inbox.sweep(w)
	check(Inbox.find(w, Inbox.BID, bid.key) == null, "the bid lapses the day after its deadline")
	MarketActions._ask_bid(w, mine, buyer, 900, true)
	var bid2: Inbox.Decision = Inbox.open_of(w, Inbox.BID).back()
	MarketActions.release_player(w, mine)
	check(Inbox.find(w, Inbox.BID, bid2.key) == null and str(MarketActions.find_offer(w, int(bid2.key))["status"]) == "void", "a bid for a player who left closes from its record")
	var tq := Inbox.ask(w, Inbox.Decision.new(Inbox.TRYOUTS, "hs_x", [Inbox.Choice.ok()]).blocking(), &"from.head_of_house", "msg.tryouts.subject", "msg.tryouts.body")
	Inbox.snooze(w, tq, w.today + 3)
	check(Inbox.blocking(w) == null, "a snoozed question does not block")
	w.today += 3
	check(Inbox.blocking(w) != null and Inbox.blocking(w).id == tq.owl_id, "it blocks again on its day, for the engine and the screen alike")
	var again := Inbox.ask(w, Inbox.Decision.new(Inbox.TRYOUTS, "hs_x", [Inbox.Choice.ok()]).blocking(), &"from.head_of_house", "msg.tryouts.subject", "msg.tryouts.body")
	check(again == tq and Inbox.open_of(w, Inbox.TRYOUTS).size() == 1, "asking again restates the open question")
	SaveManager.delete_save("_test_inbox")
	gs.free()


func _session_qmsave(meta: Dictionary, world_text: String) -> PackedByteArray:
	var gz := "user://_test_world_part.gz"
	var gf := FileAccess.open_compressed(gz, FileAccess.WRITE, FileAccess.COMPRESSION_GZIP)
	gf.store_string(world_text)
	gf.close()
	var world_bytes := FileAccess.get_file_as_bytes(gz)
	DirAccess.remove_absolute(gz)
	var path := "user://_test_build.qmsave"
	var zip := ZIPPacker.new()
	zip.open(path)
	zip.start_file("meta.json")
	zip.write_file(JSON.stringify(meta).to_utf8_buffer())
	zip.close_file()
	zip.start_file("world.json.gz")
	zip.write_file(world_bytes)
	zip.close_file()
	zip.close()
	var out := FileAccess.get_file_as_bytes(path)
	DirAccess.remove_absolute(path)
	return out


func test_save_import_hardening() -> void:
	print("save files: autosave names, malformed worlds, size caps")
	var w := WorldGenerator.new(loader).generate(6)
	check(SaveManager.save(w, "_test_src") == OK, "save ok")
	var rf := FileAccess.open_compressed(SaveManager.save_dir("_test_src").path_join("world.json.gz"), FileAccess.READ, FileAccess.COMPRESSION_GZIP)
	var world_text := rf.get_as_text()
	rf.close()
	SaveManager.delete_save("_test_src")
	var auto := _session_qmsave({"name": "autosave_1", "schema": World.SCHEMA_VERSION, "club_name": "Test Club Imported"}, world_text)
	var a1 := SaveManager.import_file(auto)
	var a2 := SaveManager.import_file(auto)
	check(a1 != "" and a2 != "" and a1 != a2, "an exported autosave imports twice (%s, %s)" % [a1, a2])
	check(not a1.to_lower().begins_with("autosave_") and not a2.to_lower().begins_with("autosave_"), "an imported autosave never lands in an autosave slot")
	check(a1 != "" and SaveManager.load(a1) != null, "the imported autosave loads")
	if a1 != "":
		SaveManager.delete_save(a1)
	if a2 != "":
		SaveManager.delete_save(a2)
	check(SaveManager.is_autosave_slot("autosave_2") and not SaveManager.is_autosave_slot("autosave_1 (2)"), "only the two exact slots are autosaves")
	var bad := _session_qmsave({"name": "Broken", "schema": World.SCHEMA_VERSION}, '{"schema": %d, "clubs": {"x": {}}, "players": {}, "competitions": {}}' % World.SCHEMA_VERSION)
	check(SaveManager.import_file(bad) == "", "a world whose clubs have no id is not imported")
	var bad2 := _session_qmsave({"name": "Broken", "schema": World.SCHEMA_VERSION}, '{"schema": %d, "clubs": {}, "players": {}, "competitions": {}, "owls": []}' % World.SCHEMA_VERSION)
	check(SaveManager.import_file(bad2) == "", "a world with a mistyped inbox is not imported")
	var schema_tag := '"schema":%d' % World.SCHEMA_VERSION
	check(world_text.contains(schema_tag), "the saved world carries its schema version")
	var newer := _session_qmsave({"name": "Future", "schema": World.SCHEMA_VERSION}, world_text.replace(schema_tag, '"schema":%d' % (World.SCHEMA_VERSION + 1)))
	check(SaveManager.import_file(newer) == "", "a world with a newer schema is not imported even if its meta says otherwise")
	var older_text := world_text.replace(schema_tag, '"schema":%d' % (World.SCHEMA_VERSION - 1))
	var older := _session_qmsave({"name": "Past", "schema": World.SCHEMA_VERSION}, older_text)
	check(SaveManager.import_file(older) == "", "a world with an older schema is not imported either")
	var older_meta := _session_qmsave({"name": "Past", "schema": World.SCHEMA_VERSION - 1}, world_text)
	check(SaveManager.import_file(older_meta) == "", "a meta.json with an older schema is not imported")
	var old_dir := SaveManager.save_dir("_test_old_schema")
	DirAccess.make_dir_recursive_absolute(old_dir)
	var of := FileAccess.open_compressed(old_dir.path_join("world.json.gz"), FileAccess.WRITE, FileAccess.COMPRESSION_GZIP)
	of.store_string(older_text)
	of.close()
	check(SaveManager.load("_test_old_schema") == null, "a saved game with an older schema does not load")
	SaveManager.delete_save("_test_old_schema")
	var big := PackedByteArray()
	big.resize(SaveManager.MAX_IMPORT_BYTES + 1)
	check(SaveManager.import_file(big) == "", "an oversized file is not imported")
	var reserved := _session_qmsave({"name": "CON", "schema": World.SCHEMA_VERSION, "club_name": ""}, world_text)
	var r := SaveManager.import_file(reserved)
	check(r != "" and r.to_upper() != "CON", "a Windows-reserved name is replaced (%s)" % r)
	if r != "":
		SaveManager.delete_save(r)


func test_team_talk_cap() -> void:
	print("team talks: all the talks of a match together move attributes at most 4 %")
	var t := SimLoader.synthetic_team("A", 12.0)
	var base := {}
	for sp in t.players:
		base[sp.id] = sp.attrs.duplicate()
	for i in 20:
		var before := {}
		for sp in t.players:
			before[sp.id] = sp.attrs.duplicate()
		TeamTalk.apply(t, "encourage", -60, false, 1000 + i)
		TeamTalk.cap_effect(t, before)
	var ok := true
	var moved := false
	for sp in t.players:
		for k in sp.attrs.keys():
			var b0 := float(base[sp.id][k])
			var v := float(sp.attrs[k])
			if b0 > 0.0 and (v > b0 * 1.0401 or v < b0 * 0.9599):
				ok = false
			if absf(v - b0) > 0.0001:
				moved = true
	check(ok, "20 encouraging talks stay within 4 % of the pre-talk attributes")
	check(moved, "the talks still have an effect")


func test_pre_press_questions_survive_save() -> void:
	print("press: pre-match questions stored in settings survive a JSON save")
	var w := WorldGenerator.new(loader).generate(8)
	w.player_club_id = "club_puddlemere_united"
	var me := w.my_club()
	var lg := w.league_of(me.id)
	var fx: Dictionary = {}
	for f in lg.fixtures:
		if str(f["home_id"]) == me.id or str(f["away_id"]) == me.id:
			fx = f
			break
	var qs := Press.pre_questions(w, me.id, fx, lg)
	var back = JSON.parse_string(JSON.stringify({"press_progress": {"fixture": str(fx.get("id", "")), "pre": true, "idx": 1, "qs": qs}}))
	var pr: Dictionary = back["press_progress"]
	check(not qs.is_empty() and pr["qs"] is Array and (pr["qs"] as Array).size() == qs.size(), "every question is stored")
	check(int(pr["idx"]) == 1 and bool(pr["pre"]), "progress index and kind survive")
	check(not qs.is_empty() and Press.apply_pre(w, pr["qs"][0], "humble") == "press.effect.pre_humble", "a stored question can still be answered")


func test_vacancy_marker_changes_per_vacancy() -> void:
	print("manager screen: one application per vacancy")
	var w := WorldGenerator.new(loader).generate(14)
	w.player_club_id = "club_puddlemere_united"
	var me := w.my_club()
	me.manager_is_human = true
	w.manager = {"name": "Test", "nationality": "eng", "reputation": 1000, "career": [{"club_id": me.id, "from": w.season}]}
	var engine := GameEngine.new(loader, w)
	var other: Club = w.club("club_chudley_cannons")
	engine._ai_sack(other)
	var d1 := int(other.history["managers"][-1]["until"])
	check(engine.vacancies().has(other) and d1 == w.today, "a sacking opens a vacancy dated today")
	w.today += 90
	engine._ai_sack(other)
	var d2 := int(other.history["managers"][-1]["until"])
	check(d2 != d1 and engine.vacancies().has(other), "a later sacking is a new vacancy with a new marker")


func test_playtest_fixes_regressions() -> void:
	print("playtest fixes: objectives by league size, contract years, pre-contracts, one owl per job, former names")
	var w := WorldGenerator.new(loader).generate(17)
	w.player_club_id = "club_puddlemere_united"
	var me := w.my_club()
	me.manager_is_human = true
	w.manager = {"name": "Test", "nationality": "eng", "reputation": 1500, "career": [{"club_id": me.id, "from": w.season}]}
	var engine := GameEngine.new(loader, w)
	var lg := w.league_of(me.id)
	var all_ids: Array = lg.club_ids.duplicate()
	check(all_ids.size() >= 13, "the British and Irish League has 13 clubs (%d)" % all_ids.size())
	var expect := {9: {"title": 1, "top_half": 5, "mid_table": 6, "avoid_last": 8}, 13: {"title": 1, "top_half": 7, "mid_table": 9, "avoid_last": 12}}
	for n in expect.keys():
		lg.club_ids = all_ids.slice(0, n)
		for obj in expect[n].keys():
			me.board["objective"] = obj
			check(Economy.objective_pos(w, me) == int(expect[n][obj]), "objective '%s' in a %d-club league is position %d (%d)" % [obj, n, int(expect[n][obj]), Economy.objective_pos(w, me)])
	lg.club_ids = all_ids
	var today0 := w.today
	w.today = WDate.from_ymd(w.season + 1, 5, 31)
	check(Contracts.end_day_for(w, 2) == WDate.from_ymd(w.season + 2, 6, 30), "a 2-year deal signed on 31 May ends two seasons on")
	w.today = WDate.from_ymd(w.season + 1, 6, 30)
	check(Contracts.end_day_for(w, 2) == WDate.from_ymd(w.season + 3, 6, 30), "signed on 30 June it counts from the next season")
	w.today = today0
	var p: Player = w.player(str(me.lineup["S"]))
	p.pre_contract = Player.PreContract.new("club_montrose_magpies", {"wage_weekly": 20, "years": 2}, w.today)
	var terms := Contracts.default_terms(w, p, me, "renew")
	terms["wage_weekly"] = int(terms["wage_weekly"]) * 3
	check(str(Contracts.evaluate(w, p, me, terms, "renew")["reason"]) == "ui.contract.has_pre_contract", "a renewal is refused to a player with a pre-contract")
	check(str(Contracts.sign(w, p, me, terms, "renew")["key"]) == "ui.contract.has_pre_contract", "and cannot be signed")
	p.pre_contract = null
	var cannons: Club = w.club("club_chudley_cannons")
	engine._post_job_offer(cannons)
	engine._post_job_offer(cannons)
	var owls := Inbox.open_of(w, Inbox.JOB).filter(func(d): return d.key == cannons.id).size()
	check(owls == 1, "two calls from the same club make one job owl (%d)" % owls)
	var gone: Player = w.squad_of("club_montrose_magpies")[0]
	var gid := gone.id
	var gname := gone.name()
	w.remove_player(gid)
	check(w.player(gid) == null and str(w.former_names.get(gid, "")) == gname, "a removed player's name is kept in former_names")
	var gs = load("res://src/game/game_session.gd").new()
	gs.world = w
	check(gs.player_name(gid) == gname, "the name still shows (%s)" % gs.player_name(gid))
	check(Say.text(Say.comp(lg.id)) == lg.display_name() and lg.display_name() != "", "a stored competition shows its name")
	check(Say.text(Say.key("award.wronski")) == str(TranslationServer.translate("award.wronski")), "a stored key is translated")
	gs.free()


func test_translation_sources_in_sync() -> void:
	print("translations: strings.csv, locale/tr/<lang>.csv and source.csv agree")
	var read := func(path: String) -> Array:
		var out: Array = []
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			return out
		while not f.eof_reached():
			var row := f.get_csv_line()
			if row.size() > 1 or (row.size() == 1 and row[0] != ""):
				out.append(row)
		return out
	var rows: Array = read.call("res://locale/strings.csv")
	check(rows.size() > 1, "strings.csv readable")
	if rows.size() <= 1:
		return
	var hdr: PackedStringArray = rows[0]
	var strings := {}
	for i in range(1, rows.size()):
		strings[rows[i][0]] = rows[i]
	var bad: Array = []
	var src: Array = read.call("res://locale/tr/source.csv")
	check(src.size() == rows.size(), "source.csv has the same keys as strings.csv (%d vs %d rows)" % [src.size(), rows.size()])
	for i in range(1, src.size()):
		var r: PackedStringArray = src[i]
		if r.size() < 3 or not strings.has(r[0]) or strings[r[0]][1] != r[1] or strings[r[0]][2] != r[2]:
			bad.append("source:" + r[0])
	for lang in ["de", "fr", "it", "pt_BR", "nl", "ru", "ja", "zh_CN"]:
		var col := hdr.find(lang)
		var tr_rows: Array = read.call("res://locale/tr/%s.csv" % lang)
		check(col > 0 and tr_rows.size() > 1, "strings.csv has a %s column and locale/tr/%s.csv is readable" % [lang, lang])
		for i in range(1, tr_rows.size()):
			var r: PackedStringArray = tr_rows[i]
			if r.size() == 2 and r[1].strip_edges() != "" and strings.has(r[0]) and strings[r[0]][col] != r[1]:
				bad.append("%s:%s" % [lang, r[0]])
	check(bad.is_empty(), "strings.csv, locale/tr/<lang>.csv and source.csv agree (%d differ: %s)" % [bad.size(), str(bad.slice(0, 10))])


func test_about_text_version() -> void:
	print("about: one version (project.godot) that matches every export preset; no version written in the texts")
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	check(version != "", "project.godot has application/config/version")
	var cfg := ConfigFile.new()
	check(cfg.load("res://export_presets.cfg") == OK, "export_presets.cfg parses")
	for sec in cfg.get_sections():
		if sec.ends_with(".options") and cfg.has_section_key(sec, "application/version"):
			check(str(cfg.get_value(sec, "application/version")) == version, "%s version is %s" % [sec, version])
		for key in ["application/file_version", "application/product_version"]:
			if sec.ends_with(".options") and cfg.has_section_key(sec, key):
				check(str(cfg.get_value(sec, key)) == version + ".0", "%s %s is %s.0" % [sec, key, version])
	var f := FileAccess.open("res://locale/strings.csv", FileAccess.READ)
	f.get_csv_line()
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() > 1 and row[0] == "ui.settings.about_text":
			for i in range(1, row.size()):
				check(not row[i].contains(version), "the about text no longer repeats the version (%d)" % i)

func test_export_presets_ship_licenses() -> void:
	print("export presets: licences shipped, translator sources left out, web keyboard")
	var cfg := ConfigFile.new()
	check(cfg.load("res://export_presets.cfg") == OK, "export_presets.cfg parses")
	for i in 3:
		var sec := "preset.%d" % i
		var inc := str(cfg.get_value(sec, "include_filter", "")).split(",")
		var exc := str(cfg.get_value(sec, "exclude_filter", "")).split(",")
		for pat in ["data/*", "LICENSE", "ATTRIBUTION.md", "assets/fonts/*.txt", "assets/icons/*.txt"]:
			check(inc.has(pat), "%s includes %s" % [cfg.get_value(sec, "name", sec), pat])
		check(not exc.has("*.md") and not exc.has("ATTRIBUTION.md"), "%s does not exclude ATTRIBUTION.md" % sec)
		check(exc.has("locale/tr/*"), "%s leaves the translator CSVs out" % sec)
	for path in ["res://LICENSE", "res://ATTRIBUTION.md", "res://assets/icons/LICENSE-phosphor.txt", "res://assets/fonts/fallback/OFL-Noto.txt"]:
		check(FileAccess.file_exists(path), "%s exists" % path)
	check(cfg.get_value("preset.2", "platform", "") == "Web", "preset 2 is the web build")
	check(cfg.get_value("preset.2.options", "html/experimental_virtual_keyboard", false) == true, "web build opens the virtual keyboard")
	check(str(cfg.get_value("preset.0.options", "application/copyright", "")).begins_with("Non-commercial"), "English copyright on macOS")
	check(cfg.get_value("preset.0.options", "application/copyright_localized", {}) is Dictionary, "copyright_localized is a dictionary")


## The browser build has no system fonts: every character the game can show must be in a bundled font.
func test_fonts_cover_translations() -> void:
	print("fonts: every character of the translations, data and source strings is in a bundled font")
	var fonts: Array[Font] = []
	for path in ["res://assets/fonts/AlegreyaSans-Regular.ttf", "res://assets/fonts/fallback/NotoSansSymbols2-Subset.ttf",
			"res://assets/fonts/fallback/NotoSansJP-Subset.otf", "res://assets/fonts/fallback/NotoSansSC-Subset.otf"]:
		fonts.append(load(path))
	var chars := {}
	var non_ascii := RegEx.create_from_string("[^\\x{00}-\\x{7F}]+")
	var collect := func(text: String, where: String) -> void:
		for m in non_ascii.search_all(text):
			for ch in m.get_string():
				if not chars.has(ch):
					chars[ch] = where
	var f := FileAccess.open("res://locale/strings.csv", FileAccess.READ)
	f.get_csv_line()
	while not f.eof_reached():
		var row := f.get_csv_line()
		for i in range(1, row.size()):
			collect.call(row[i], row[0])
	for path in _files_under("res://data", ".json"):
		collect.call(FileAccess.get_file_as_string(path), path)
	var literal := RegEx.create_from_string("\"([^\"\\\\]*(?:\\\\.[^\"\\\\]*)*)\"")
	for path in _files_under("res://src", ".gd"):
		for m in literal.search_all(FileAccess.get_file_as_string(path)):
			collect.call(m.get_string(1), path)
	check(chars.size() > 100, "characters collected from translations, data and sources (%d)" % chars.size())
	var missing := {}
	for ch in chars.keys():
		var code: int = str(ch).unicode_at(0)
		if code == 0x200B:
			continue
		if not fonts.any(func(fo: Font): return fo.has_char(code)):
			missing[ch] = chars[ch]
	check(missing.is_empty(), "every character shown is in a bundled font (missing: %s)" % str(missing))


func _files_under(dir_path: String, ext: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var fname := d.get_next()
	while fname != "":
		if d.current_is_dir():
			if not fname.begins_with("."):
				out.append_array(_files_under(dir_path.path_join(fname), ext))
		elif fname.ends_with(ext):
			out.append(dir_path.path_join(fname))
		fname = d.get_next()
	d.list_dir_end()
	out.sort()
	return out


func test_season_report() -> void:
	print("session: the season summary for the ranking fits data/shared/season_report.schema.json")
	var schema: Dictionary = SimLoader.load_json(SimLoader.SHARED + "/season_report.schema.json")
	var w := WorldGenerator.new(loader).generate(5)
	w.player_club_id = "club_puddlemere_united"
	w.my_club().manager_is_human = true
	w.career_id = "0123456789abcdef"
	w.manager = {"name": "Test", "reputation": 1640, "titles": 1, "seasons": 1, "career": []}
	w.today = WDate.from_ymd(1994, 7, 1)
	var gs = load("res://src/game/game_session.gd").new()
	gs.world = w
	var r: Dictionary = gs.season_report(1993)
	var errs := _schema_errors(schema, r)
	check(errs.is_empty(), "the report fits the schema: %s %s" % [errs, JSON.stringify(r)])
	check(r["season"] == 1993 and r["reported_on"] == "1994-07-01" and r["reputation"] == 1640 and r["mode"] == "club" and r["titles"] == 1 and r["seasons"] == 1 and str(r["club_name"]) == "Puddlemere United", "season report values: %s" % JSON.stringify(r))
	w.player_club_id = ""
	var jobless: Dictionary = gs.season_report(1993)
	check(jobless["club_id"] == null and _schema_errors(schema, jobless).is_empty(), "without a club the report carries null ids, which the schema allows")
	var broken := r.duplicate()
	broken["career_id"] = "XYZ"
	broken["season"] = 1980
	broken.erase("reputation")
	broken["mode"] = "county"
	check(_schema_errors(schema, broken).size() == 4, "the checker catches a bad id, an early season, a missing key and an unknown mode: %s" % [_schema_errors(schema, broken)])
	check(int(schema["properties"]["season"]["minimum"]) == int(Career.RULES["first_season"]), "the schema's first season is career_rules.json's")
	check(Career.REP_MAX == 5000 and Career.START_REP_MAX == 1700, "career_rules.json: reputation 5000 at most, 1700 at most to start")
	Career.set_reputation(w, 99999)
	check(int(w.manager["reputation"]) == Career.REP_MAX, "reputation is clamped to the shared maximum")
	gs.report_finished_season()
	check(not w.manager.has("reported_season"), "desktop builds report nothing")
	gs.free()


## The subset of JSON Schema data/shared/season_report.schema.json uses: type (one or several), required,
## properties, enum, pattern, minLength, maxLength, minimum and maximum. A whole float counts as an integer, as it
## does once serialized.
func _schema_errors(schema: Dictionary, v: Variant, path: String = "$") -> Array[String]:
	var errs: Array[String] = []
	if schema.has("type"):
		var types: Array = schema["type"] if schema["type"] is Array else [schema["type"]]
		var fits := {"null": v == null, "string": v is String, "integer": v is int or (v is float and v == floor(v)), "number": v is int or v is float, "boolean": v is bool, "object": v is Dictionary, "array": v is Array}
		if not types.any(func(t): return bool(fits.get(str(t), false))):
			errs.append("%s: %s is not %s" % [path, type_string(typeof(v)), types])
			return errs
	if v == null:
		return errs
	if schema.has("enum") and not (v in schema["enum"]):
		errs.append("%s: %s is not one of %s" % [path, v, schema["enum"]])
	if v is String:
		if schema.has("pattern") and RegEx.create_from_string(str(schema["pattern"])).search(v) == null:
			errs.append("%s: '%s' does not match %s" % [path, v, schema["pattern"]])
		if schema.has("minLength") and v.length() < int(schema["minLength"]):
			errs.append("%s: shorter than %d" % [path, int(schema["minLength"])])
		if schema.has("maxLength") and v.length() > int(schema["maxLength"]):
			errs.append("%s: longer than %d" % [path, int(schema["maxLength"])])
	if v is int or v is float:
		if schema.has("minimum") and v < schema["minimum"]:
			errs.append("%s: %s is below %s" % [path, v, schema["minimum"]])
		if schema.has("maximum") and v > schema["maximum"]:
			errs.append("%s: %s is above %s" % [path, v, schema["maximum"]])
	if v is Dictionary:
		for k in schema.get("required", []):
			if not v.has(k):
				errs.append("%s: missing %s" % [path, k])
		var props: Dictionary = schema.get("properties", {})
		for k in props:
			if v.has(k):
				errs.append_array(_schema_errors(props[k], v[k], path + "." + str(k)))
	return errs


func test_save_slots_per_career() -> void:
	print("saves: two careers with the same club never share a slot")
	var g = load("res://src/game/game_session.gd").new()
	g.loader = loader
	var prev_locale := TranslationServer.get_locale()
	var club := "club_holyhead_harpies"
	var made: Array = []
	g.new_game(club, "A", "GB", 902)
	var id_a: String = g.world.career_id
	var slot_a: String = g.save_name
	check(slot_a.begins_with("harpies"), "slot derived from the club (%s)" % slot_a)
	check(str(g.world.manager.get("save_slot", "")) == slot_a, "the chosen slot is kept in the world")
	check(g.save_game() == OK, "career A saves")
	made.append(slot_a)
	check(SaveManager.slot_career_id(slot_a) == id_a, "meta.json carries the career id")
	g.new_game(club, "B", "GB", 903)
	var id_b: String = g.world.career_id
	var slot_b: String = g.save_name
	check(id_a != id_b, "two careers, two ids")
	check(slot_b != slot_a and slot_b.begins_with("harpies"), "career B gets its own slot (%s)" % slot_b)
	check(g.save_game() == OK, "career B saves")
	made.append(slot_b)
	check(SaveManager.load(slot_a).manager["name"] == "A" and SaveManager.load(slot_b).manager["name"] == "B", "each slot loads its own manager")
	check(SaveManager.free_slot_for("harpies", id_a) == slot_a and SaveManager.free_slot_for("harpies", id_b) == slot_b, "free_slot_for returns a career's own slot")
	var third := SaveManager.free_slot_for("harpies", "someone_else")
	check(third != slot_a and third != slot_b and third.begins_with("harpies_"), "a third career would get a free slot (%s)" % third)
	check(g.save_game(slot_a) == ERR_ALREADY_EXISTS and g.save_name == slot_b, "a typed name of another career is refused")
	check(g.save_game(slot_b) == OK, "typing your own slot saves")
	check(g.save_game("autosave_1") == ERR_INVALID_PARAMETER, "autosave names are still refused")
	g.new_game(club, "C", "GB", 904)
	var slot_c: String = g.save_name
	var w_c: World = g.world
	g.new_game(club, "D", "GB", 905)
	check(g.save_name == slot_c, "two games started without saving take the same slot")
	check(g.save_game() == OK, "career D saves")
	var slot_d: String = g.save_name
	made.append(slot_d)
	g.world = w_c
	g.save_name = slot_c
	check(g.save_game() == OK, "career C saves")
	check(g.save_name != slot_d and SaveManager.load(slot_d).manager["name"] == "D", "C moved to %s instead of overwriting D" % g.save_name)
	made.append(g.save_name)
	check(str(g.world.manager.get("save_slot", "")) == g.save_name, "the slot C moved to is the one it remembers")
	g.new_game("", "E", "GB", 906)
	check(g.save_name.begins_with("career_e") and g.save_game() == OK, "a clubless career gets its own slot (%s)" % g.save_name)
	made.append(g.save_name)
	if not g.load_game(slot_b):
		check(false, "career B loads")
		_save_slots_done(g, made, prev_locale)
		return
	check(g.save_name == slot_b and g.world.career_id == id_b, "loading a manual slot keeps it")
	var auto_slot: String = SaveManager.AUTOSAVE_SLOTS[0]
	var auto_ok := SaveManager.save(g.world, auto_slot) == OK
	g.world = null
	var loaded: bool = auto_ok and g.load_game(auto_slot)
	SaveManager.delete_save(auto_slot)
	check(loaded, "B autosaves and the autosave loads")
	if loaded:
		check(g.save_name == slot_b, "after loading an autosave, manual saves go back to the career's slot (%s)" % g.save_name)
	elif not g.load_game(slot_b):
		_save_slots_done(g, made, prev_locale)
		return
	var other_club := "club_montrose_magpies"
	g.engine.accept_job(other_club)
	g.save_name = g.manual_slot()
	check(g.save_name == slot_b, "a job change does not move the career (%s)" % g.save_name)
	check(g.save_game() == OK and SaveManager.load(slot_b).player_club_id == other_club, "and saves to the same slot")
	g.world.manager.erase("save_slot")
	var derived: String = g.manual_slot()
	check(derived.begins_with("magpies"), "without a remembered slot the club gives one (%s)" % derived)
	check(not made.has(derived) and str(g.world.manager.get("save_slot", "")) == derived, "and it is remembered")
	_save_slots_done(g, made, prev_locale)
	check(SaveManager.slot_career_id(slot_a) == "" and SaveManager.slot_career_id(slot_b) == "", "test slots removed")


func _save_slots_done(g, made: Array, prev_locale: String) -> void:
	for s in made:
		SaveManager.delete_save(s)
	TranslationServer.set_locale(prev_locale)
	g.free()


func test_match_uses_squad_condition() -> void:
	print("match: squad condition reaches the match (J02)")
	var w := WorldGenerator.new(loader).generate(321)
	var engine := GameEngine.new(loader, w)
	var lg: Competition = w.leagues()[0]
	var home_id: String = lg.club_ids[0]
	var away_id: String = lg.club_ids[1]
	var set_cond := func(club_id: String, c: float) -> void:
		for p in w.squad_of(club_id):
			p.condition = c
	var sig := func(r: MatchResult) -> String:
		return "%d-%d %d %d %d" % [r.score_home, r.score_away, r.duration_ticks, r.events.size(), r.rng_calls]
	var run := func(seed_value: int) -> MatchResult:
		return MatchSim.new(loader.rules, loader.params).run(engine.sim_team_for(home_id), engine.sim_team_for(away_id), seed_value)
	set_cond.call(home_id, 100.0)
	set_cond.call(away_id, 100.0)
	var fresh1: MatchResult = run.call(412)
	var fresh2: MatchResult = run.call(412)
	check(sig.call(fresh1) == sig.call(fresh2), "fresh squad: same match with the same seed")
	set_cond.call(home_id, 5.0)
	var tired1: MatchResult = run.call(412)
	var tired2: MatchResult = run.call(412)
	check(sig.call(tired1) == sig.call(tired2), "tired squad: same match with the same seed")
	check(sig.call(tired1) != sig.call(fresh1), "a squad at 5 % condition plays a different match than a fresh one")
	var home := engine.sim_team_for(home_id)
	var away := engine.sim_team_for(away_id)
	var sim := MatchSim.new(loader.rules, loader.params)
	sim.begin(home, away, 412)
	check(absf(home.players[0].condition - 5.0) < 0.01, "kick-off condition 5 for a Player at 5 (%.1f)" % home.players[0].condition)
	check(absf(away.players[0].condition - 100.0) < 0.01, "kick-off condition 100 for a fresh Player (%.1f)" % away.players[0].condition)
	check(absf(home.players[0].start_condition - 5.0) < 0.01, "start_condition carried from the Player")
	var synth := SimLoader.synthetic_team("A", 12.0)
	synth.reset_for_match(0.55)
	check(absf(synth.players[0].condition - 100.0) < 0.01, "synthetic players still start at 100")
	var fresh_pts := 0
	var tired_pts := 0
	for s in range(400, 430):
		set_cond.call(home_id, 100.0)
		fresh_pts += (run.call(s) as MatchResult).score_home
		set_cond.call(home_id, 5.0)
		tired_pts += (run.call(s) as MatchResult).score_home
	check(tired_pts < fresh_pts * 0.8, "a squad at 5 %% scores clearly less over 30 seeds (%d vs %d)" % [tired_pts, fresh_pts])


## An accepted bid of the manager's club for `target`, with the agent's terms on it, as _contract_stage leaves it.
func _inject_accepted_offer(w: World, target: Player, swap_id: String, fee: int) -> Dictionary:
	var me := w.my_club()
	var o := {"id": w.next_offer_id, "day": w.today, "resolve_day": w.today, "player_id": target.id, "from_id": me.id, "to_id": target.club_id,
		"fee": fee, "wage": 20, "status": "accepted", "direction": "out", "rounds": 0, "swap_player_id": swap_id, "installments": 1,
		"terms": {"wage": 20, "bonus": 0, "years": 3}}
	w.next_offer_id += 1
	w.pending_offers.append(o)
	return o


## An AI club's bid for the manager's `p`, answered with "sell" (or the sell-on variant) through the inbox.
func _sell_by_bid(w: World, engine: GameEngine, p: Player, buyer: Club, fee: int, sell_on: bool = false) -> void:
	MarketActions._ask_bid(w, p, buyer, fee, true)
	Inbox.choose(w, engine, Inbox.open_of(w, Inbox.BID).back().owl_id, 1 if sell_on else 0)


func _my_wizard(w: World) -> Player:
	for q in w.squad_of(w.my_club().id, [Player.Squad.RESERVE, Player.Squad.FIRST]):
		if q.gender != SimPlayer.Gender.F and not q.is_on_loan():
			return q
	return null


func test_post_match_condition_floor() -> void:
	print("match: nobody leaves a match under POST_MATCH_CONDITION_FLOOR")
	var w := WorldGenerator.new(loader).generate(321)
	var e := GameEngine.new(loader, w)
	var lg: Competition = w.leagues()[0]
	w.player_club_id = lg.club_ids[0]
	w.clubs[w.player_club_id].manager_is_human = true
	e.auto_fix_lineup = true
	for i in 400:
		if e.pending_match != null:
			break
		e.advance_day()
	check(e.pending_match != null, "the human club reaches a match")
	if e.pending_match == null:
		return
	for side in ["home", "away"]:
		for sp in e.pending_match.get(side).players:
			sp.start_condition = GameEngine.POST_MATCH_CONDITION_FLOOR + 1.0
			sp.condition = sp.start_condition
	var f: Dictionary = e.pending_match.fixture
	e.complete_pending_match()
	var lowest := 100.0
	var below := 0
	for cid in [str(f["home_id"]), str(f["away_id"])]:
		for p in w.squad_of(cid):
			lowest = minf(lowest, p.condition)
			if p.condition < GameEngine.POST_MATCH_CONDITION_FLOOR - 0.001:
				below += 1
	check(below == 0, "nobody is under the floor after the match (%d)" % below)
	check(absf(lowest - GameEngine.POST_MATCH_CONDITION_FLOOR) < 0.01, "the most drained player sits on the floor (%.1f)" % lowest)


func test_swap_needs_both_players() -> void:
	print("market: a swap closes only with both players still in place")
	var w := WorldGenerator.new(loader).generate(36)
	w.player_club_id = "club_puddlemere_united"
	var me := w.my_club()
	me.manager_is_human = true
	me.balance = 50000
	me.transfer_budget = 50000
	var target := _ai_player(w, [Player.Squad.RESERVE])
	var seller: Club = w.club(target.club_id)
	var mine := _my_wizard(w)
	var third: Club = null
	for c in w.clubs_sorted():
		if not c.manager_is_human and not c.is_women_only() and c.id != seller.id:
			third = c
			break
	check(target != null and mine != null and third != null, "there are a target, a swap player and a third club")
	if target == null or mine == null or third == null:
		return
	var o := _inject_accepted_offer(w, target, mine.id, 500)
	Economy.execute_transfer(w, mine, third.id, 0, 10, 2)
	var me0 := me.balance
	var s0 := seller.balance
	var inbox0 := w.inbox.size()
	MarketActions._answer_terms(w, o, MarketActions.SIGN)
	check(target.club_id == seller.id and mine.club_id == third.id, "inbox: nobody moves")
	check(me.balance == me0 and seller.balance == s0, "inbox: no money changes hands")
	check(str(o["status"]) == "void" and w.inbox.size() == inbox0 + 1 and w.inbox[0].subject.key == "msg.deal_off.subject", "inbox: the offer is void and the manager is told")
	var o2 := _inject_accepted_offer(w, target, mine.id, 500)
	var t := Contracts.default_terms(w, target, me, "transfer", 500)
	t["signing_fee"] = 0
	var r := Contracts.sign(w, target, me, t, "transfer", 500, mine.id, 1)
	check(not bool(r["ok"]) and str(r["key"]) == "ui.market.deal_off", "dialog: the deal is off (%s)" % str(r["key"]))
	check(target.club_id == seller.id and mine.club_id == third.id and me.balance == me0 and seller.balance == s0 and w.pending_payments.is_empty(), "dialog: nobody moves, no cash, no instalments")
	check(str(o2["status"]) == "void", "dialog: the offer is void")
	var mine2 := _my_wizard(w)
	Economy.execute_loan(w, mine2, third.id)
	var o3 := _inject_accepted_offer(w, target, mine2.id, 500)
	MarketActions._answer_terms(w, o3, MarketActions.SIGN)
	check(target.club_id == seller.id and mine2.is_on_loan() and str(o3["status"]) == "void", "a swap player out on loan voids the deal")
	var mine3 := _my_wizard(w)
	var target2: Player = null
	for c in w.clubs_sorted():
		if c.manager_is_human or c.is_women_only() or c.id == seller.id:
			continue
		for x in w.squad_of(c.id, [Player.Squad.RESERVE]):
			if not x.is_on_loan():
				target2 = x
				break
		if target2 != null:
			break
	check(bool(MarketActions.make_swap_offer(w, target2, mine3, 100)["ok"]), "a pending swap bid is sent")
	Economy.execute_transfer(w, mine3, third.id, 0, 10, 2)
	var engine := GameEngine.new(loader, w)
	for i in 4:
		engine.advance_day()
	var st := ""
	for po in w.pending_offers:
		if str(po["player_id"]) == target2.id:
			st = str(po["status"])
	check(st == "void", "the pending swap bid lapses when our player leaves (%s)" % st)
	var mine4 := _my_wizard(w)
	var o4 := _inject_accepted_offer(w, target, mine4.id, 500)
	var me1 := me.balance
	MarketActions._answer_terms(w, o4, MarketActions.SIGN)
	check(target.club_id == me.id and mine4.club_id == seller.id and me.balance == me1 - 500, "a valid swap moves both players and the cash")


func test_inbox_accept_respects_embargo() -> void:
	print("market: the inbox Sign button respects the transfer embargo")
	var w := WorldGenerator.new(loader).generate(37)
	w.player_club_id = "club_puddlemere_united"
	var me := w.my_club()
	me.manager_is_human = true
	me.balance = 50000
	me.transfer_budget = 50000
	var target := _ai_player(w, [Player.Squad.RESERVE])
	check(target != null, "there is a reserve to bid for")
	if target == null:
		return
	var seller: Club = w.club(target.club_id)
	var o := _inject_accepted_offer(w, target, "", 500)
	me.board["embargo"] = true
	var me0 := me.balance
	var s0 := seller.balance
	var b0 := me.transfer_budget
	MarketActions._answer_terms(w, o, MarketActions.SIGN)
	check(target.club_id == seller.id, "the player does not join under the embargo")
	check(me.balance == me0 and seller.balance == s0 and me.transfer_budget == b0, "no money moves")
	check(str(o["status"]) == "accepted" and w.inbox[0].subject.key == "msg.embargo_blocks.subject", "the offer stays accepted and the manager is told")
	var t := Contracts.default_terms(w, target, me, "transfer", 500)
	t["signing_fee"] = 0
	var r := Contracts.sign(w, target, me, t, "transfer", 500, "", 1)
	check(str(r["key"]) == "ui.market.embargo" and target.club_id == seller.id and str(o["status"]) == "accepted", "dialog: embargo (%s)" % str(r["key"]))
	me.board["embargo"] = false
	MarketActions._answer_terms(w, o, MarketActions.SIGN)
	check(target.club_id == me.id and me.balance == me0 - 500 and str(o["status"]) == "signed", "with the embargo lifted the deal closes")


func test_swap_respects_women_only_seller() -> void:
	print("market: the Harpies never take a wizard in a swap")
	var w := WorldGenerator.new(loader).generate(38)
	w.player_club_id = "club_puddlemere_united"
	var me := w.my_club()
	me.manager_is_human = true
	me.balance = 50000
	me.transfer_budget = 50000
	var harpies: Club = w.club("club_holyhead_harpies")
	var target: Player = null
	for q in w.squad_of(harpies.id, [Player.Squad.RESERVE, Player.Squad.FIRST]):
		if not q.is_on_loan():
			target = q
			break
	var wizard := _my_wizard(w)
	check(target != null and wizard != null and harpies.is_women_only(), "there are a Harpy to bid for and a wizard to offer")
	if target == null or wizard == null:
		return
	var n0 := w.pending_offers.size()
	var r := MarketActions.make_swap_offer(w, target, wizard, 100)
	check(not bool(r["ok"]) and str(r["key"]) == "ui.market.harpies_only_witches", "the swap offer is refused (%s)" % str(r["key"]))
	check(w.pending_offers.size() == n0, "no bid is recorded")
	var witch: Player = null
	for q in w.squad_of(me.id, [Player.Squad.RESERVE, Player.Squad.FIRST]):
		if q.gender == SimPlayer.Gender.F and not q.is_on_loan():
			witch = q
			break
	if witch != null:
		check(bool(MarketActions.make_swap_offer(w, target, witch, 100)["ok"]), "a witch can be offered to the Harpies")
	var o := _inject_accepted_offer(w, target, wizard.id, 500)
	var me0 := me.balance
	var h0 := harpies.balance
	MarketActions._answer_terms(w, o, MarketActions.SIGN)
	check(target.club_id == harpies.id and wizard.club_id == me.id and me.balance == me0 and harpies.balance == h0, "inbox: nobody moves, no cash")
	check(str(o["status"]) == "void" and w.inbox[0].subject.key == "msg.deal_off.subject", "inbox: the offer is void and the manager is told")
	var o2 := _inject_accepted_offer(w, target, wizard.id, 500)
	var t := Contracts.default_terms(w, target, me, "transfer", 500)
	t["signing_fee"] = 0
	var r2 := Contracts.sign(w, target, me, t, "transfer", 500, wizard.id, 1)
	check(not bool(r2["ok"]) and str(r2["key"]) == "ui.market.harpies_only_witches", "dialog: refused for the Harpies (%s)" % str(r2["key"]))
	check(target.club_id == harpies.id and wizard.club_id == me.id and me.balance == me0 and str(o2["status"]) == "void", "dialog: nobody moves, the offer is void")


func test_short_lineup_keeps_roles() -> void:
	print("engine: a short lineup (a Chaser injured, no bench) keeps the Beaters as Beaters and the Seeker as Seeker")
	var w := WorldGenerator.new(loader).generate(5)
	var engine := GameEngine.new(loader, w)
	var club: Club = w.club("club_puddlemere_united")
	check(club != null, "Puddlemere exists")
	var keep := {"K": 1, "C": 3, "B": 2, "S": 1}
	var kept: Array = []
	for p in w.squad_of(club.id):
		if int(keep.get(p.position, 0)) > 0:
			keep[p.position] -= 1
			kept.append(p)
		else:
			p.injury_days = 30
	check(kept.size() == 7, "seven fit players kept (%d)" % kept.size())
	for p in kept:
		if p.position == "C":
			p.injury_days = 30
			break
	var t := engine.sim_team_for(club.id)
	check(t.players.size() == 6, "six players take the field (%d)" % t.players.size())
	var by_slot := {"K": 0, "C": 0, "B": 0, "S": 0}
	var shifted := 0
	for sp in t.players:
		by_slot[sp.position] = int(by_slot.get(sp.position, 0)) + 1
		if w.player(sp.id).position != sp.position:
			shifted += 1
	check(by_slot["K"] == 1 and by_slot["C"] == 2 and by_slot["B"] == 2 and by_slot["S"] == 1, "slots K1 C2 B2 S1 (%s)" % str(by_slot))
	check(shifted == 0, "nobody plays out of their lineup slot (%d shifted)" % shifted)
	check(t.seeker() != null and w.player(t.seeker().id).position == "S", "team.seeker() is the real Seeker")


func _complete_stepped(e: GameEngine) -> MatchResult:
	while not e.complete_pending_match_slice(1):
		pass
	return e.last_match.result


func test_day_stepper_matches_advance_day() -> void:
	print("engine: begin_day/step_day(1) and the stepped match close give the same world as advance_day/complete_pending_match")
	for human in [false, true]:
		var worlds: Array = []
		var engines: Array = []
		for i in 2:
			var w := WorldGenerator.new(loader).generate(11)
			if human:
				w.player_club_id = "club_puddlemere_united"
				w.my_club().manager_is_human = true
			worlds.append(w)
			engines.append(GameEngine.new(loader, w))
		var wa: World = worlds[0]
		var wb: World = worlds[1]
		var ea: GameEngine = engines[0]
		var eb: GameEngine = engines[1]
		var target := WDate.from_ymd(1993, 8, 24)
		while wa.today < target:
			for e in [ea, eb]:
				if e.advance_day()["reason"] == "match":
					e.complete_pending_match()
		check(hash(var_to_bytes(wa.to_dict())) == hash(var_to_bytes(wb.to_dict())), "same world before diverging (human=%s)" % human)
		var same_results := true
		var close_matches := 0
		ea.prof["matches"] = 0
		var end := WDate.from_ymd(1993, 10, 8)
		while wa.today < end:
			var ra := ea.advance_day()
			eb.begin_day()
			while not eb.step_day(1):
				pass
			var rb := eb.day_result()
			if ra != rb:
				same_results = false
			if ra["reason"] == "match":
				var ro := ea.complete_pending_match()
				if WDate.weekday(wa.today) == Time.WEEKDAY_MONDAY or WDate.day_of_month(wa.today) == 1:
					close_matches += 1
				if rb["reason"] == "match":
					var rn := _complete_stepped(eb)
					if ro.score_home != rn.score_home or ro.score_away != rn.score_away:
						same_results = false
			elif rb["reason"] == "match":
				_complete_stepped(eb)
		check(same_results, "same day and match results (human=%s)" % human)
		check(hash(var_to_bytes(wa.to_dict())) == hash(var_to_bytes(wb.to_dict())), "same world after the split days (human=%s)" % human)
		check(int(ea.prof["matches"]) > 0, "AI matches were played in the window (%d)" % int(ea.prof["matches"]))
		if human:
			check(close_matches > 0, "a human match fell on a Monday or a 1st, so the stepped close did real work (%d)" % close_matches)


func test_match_events_carry_play_context() -> void:
	print("2D viewer: events carry the play context and the match is unchanged")
	var a := SimLoader.synthetic_team("A", 12.0)
	var b := SimLoader.synthetic_team("B", 13.0)
	var r := _sim().run(a, b, 123)
	check(r.score_home == 180 and r.score_away == 100, "seed 123 still ends 180-100 (%d-%d)" % [r.score_home, r.score_away])
	check(r.duration_ticks == 715, "seed 123 still lasts 715 ticks (%d)" % r.duration_ticks)
	check(r.events.size() == 310, "seed 123 still logs 310 events (%d)" % r.events.size())
	check(r.rng_calls == 4285, "seed 123 still draws 4285 random numbers (%d)" % r.rng_calls)
	var r77 := _sim().run(SimLoader.synthetic_team("A", 12.0), SimLoader.synthetic_team("B", 13.0), 77)
	check(r77.score_home == 150 and r77.score_away == 340 and r77.duration_ticks == 1661 and r77.events.size() == 784, "seed 77 still gives 150-340 in 1661 ticks with 784 events")
	var team_of: Dictionary = {}
	var pos_of: Dictionary = {}
	for p in a.players:
		team_of[p.id] = "A"
		pos_of[p.id] = p.position
	for p in b.players:
		team_of[p.id] = "B"
		pos_of[p.id] = p.position
	var passes := 0
	var passes_ok := true
	var saves := 0
	var saves_ok := true
	var restarts := 0
	var restarts_ok := true
	var turnovers := 0
	var turnovers_ok := true
	for e in r.events + r77.events:
		match e.type:
			"pass":
				passes += 1
				if e.player_id == "" or e.other_player_id == "" or e.player_id == e.other_player_id \
						or team_of.get(e.player_id, "") != e.team_id or team_of.get(e.other_player_id, "") != e.team_id \
						or pos_of.get(e.other_player_id, "") != "C":
					passes_ok = false
			"save", "penalty_saved":
				saves += 1
				if pos_of.get(e.player_id, "") != "K" or team_of.get(e.player_id, "") != e.team_id or e.other_player_id == "" or team_of.get(e.other_player_id, "") == e.team_id:
					saves_ok = false
			"turnover":
				turnovers += 1
				if e.other_player_id != "" and team_of.get(e.other_player_id, "") == e.team_id:
					turnovers_ok = false
		if e.type in ["goal", "penalty_goal", "save", "penalty_saved", "goal_annulled"]:
			restarts += 1
			var conceding: String = e.team_id if e.type in ["save", "penalty_saved"] else ("B" if e.team_id == "A" else "A")
			var to := str(e.params.get("restart_to", ""))
			var kind := str(e.params.get("restart", ""))
			if kind != "keeper" and kind != "no_chasers":
				restarts_ok = false
			elif kind == "keeper" and (pos_of.get(to, "") != "C" or team_of.get(to, "") != conceding):
				restarts_ok = false
			elif kind == "no_chasers" and to != "" and team_of.get(to, "") == conceding:
				restarts_ok = false
	check(passes > 50 and passes_ok, "every pass names passer and receiver (%d passes)" % passes)
	check(saves > 20 and saves_ok, "every save names the Keeper and the shooter (%d saves)" % saves)
	check(restarts > 30 and restarts_ok, "every goal and save names the Chaser who restarts (%d restarts)" % restarts)
	check(turnovers > 30 and turnovers_ok, "turnovers name who lost the Quaffle (%d turnovers)" % turnovers)
	var misses := 0
	var misses_ok := true
	for e in r.events:
		if e.type == "miss":
			misses += 1
			var kind := str(e.params.get("restart", ""))
			var to := str(e.params.get("restart_to", ""))
			if kind == "attack":
				if to != e.player_id:
					misses_ok = false
			elif kind == "keeper":
				if team_of.get(to, "") == e.team_id or pos_of.get(to, "") != "C":
					misses_ok = false
			elif kind != "no_chasers":
				misses_ok = false
	check(misses > 0 and misses_ok, "misses say who picks the ball up (%d misses)" % misses)
	var d: Dictionary = r.events[0].to_dict()
	check(d.has("t") and d.has("p2") and d.has("params") and d.has("key"), "to_dict keeps its keys")


func test_international_duty() -> void:
	print("national teams: a call-up takes the player away from his club until the day after the match")
	var w := WorldGenerator.new(loader).generate(321)
	var e := GameEngine.new(loader, w)
	var dates := WorldGenerator.national_dates(w.season)
	var match_day: int = int(dates[0])
	check(match_day > w.today, "the first international date is ahead of the start (%d > %d)" % [match_day, w.today])
	var call_day := match_day - GameEngine.CALL_UP_DAYS
	while w.today < call_day - 1:
		e.advance_day()
		if e.pending_match != null:
			e.complete_pending_match()
	var before := 0
	for p in w.players.values():
		if p.on_duty():
			before += 1
	check(before == 0, "nobody is on duty the day before the call-up (%d)" % before)
	e.advance_day()
	var away: Array = []
	for p in w.players.values():
		if p.on_duty():
			away.append(p)
	check(away.size() >= 14, "at least two squads are called up on the call-up day (%d players)" % away.size())
	var ok_days := true
	var ok_fit := true
	var ok_team := true
	for p in away:
		if p.duty_days != GameEngine.CALL_UP_DAYS + 2:
			ok_days = false
		if p.is_available() or not p.is_fit():
			ok_fit = false
		if not p.duty_team.begins_with("nt_") or not w.national_teams.has(p.duty_team):
			ok_team = false
	check(ok_days, "duty lasts until the day after the match (CALL_UP_DAYS + 2)")
	check(ok_fit, "a player on duty is fit but not available to his club")
	check(ok_team, "duty_team names an existing national team")
	var sample: Player = away[0]
	var fielded_by_nt := false
	for pair in NationalTeams.lineup_slots(NationalTeams.call_up_squad(w, w.national_teams[sample.duty_team])):
		if str(pair[0]) == sample.id:
			fielded_by_nt = true
	check(fielded_by_nt, "the national team's seven includes the player on duty")
	var club_player: Player = null
	for p in away:
		if p.club_id != "" and w.clubs.has(p.club_id):
			club_player = p
			break
	if club_player != null:
		var ids: Array = []
		for pair in NationalTeams.lineup_slots(WorldGenerator.best_lineup(w, club_player.club_id)):
			ids.append(str(pair[0]))
		check(not ids.has(club_player.id), "the club's best line-up leaves out the player on duty")
	var owl_ok := true
	if club_player != null:
		var inbox_n := w.inbox.size()
		w.player_club_id = club_player.club_id
		w.clubs[club_player.club_id].manager_is_human = true
		w.manager["career"] = [{"club_id": club_player.club_id, "from": w.season}]
		club_player.duty_days = 0
		club_player.duty_team = ""
		e.advance_day()
		if e.pending_match != null:
			e.complete_pending_match()
		var found := false
		for m in w.inbox:
			if m.subject.key == "msg.duty_call.subject":
				found = true
		owl_ok = found and w.inbox.size() > inbox_n
		check(owl_ok, "the manager's club gets a call-up owl")
	var d := club_player.to_dict() if club_player != null else sample.to_dict()
	var back := Player.from_dict(d)
	check(back.duty_days == (club_player if club_player != null else sample).duty_days and back.duty_team == (club_player if club_player != null else sample).duty_team, "duty survives to_dict/from_dict")
	check(Player.from_dict({"id": "x", "name": "X"}).duty_days == 0, "an old save without duty fields loads with none")
	while w.today <= match_day + 1:
		e.advance_day()
		if e.pending_match != null:
			e.complete_pending_match()
	var still := 0
	for p in w.players.values():
		if p.on_duty():
			still += 1
	check(still == 0, "the day after the match nobody is on duty any more (%d)" % still)


func test_save_load_round_trip_simulates_alike() -> void:
	print("saves: a loaded world simulates the same days as the world it was saved from")
	var a := WorldGenerator.new(loader).generate(777)
	var ea := GameEngine.new(loader, a)
	for i in 3:
		ea.advance_day()
		if ea.pending_match != null:
			ea.complete_pending_match()
	var slot := "_test_round_trip_%d" % (Time.get_ticks_usec() % 100000)
	check(SaveManager.save(a, slot) == OK, "the world saves")
	var b := SaveManager.load(slot)
	SaveManager.delete_save(slot)
	check(b != null, "the world loads back")
	if b == null:
		return
	# Compared as JSON (both sides through the same parse), so an int that came back as a float does not count.
	var canon := func(w: World) -> String:
		return JSON.stringify(JSON.parse_string(JSON.stringify(w.to_dict(), "", true, true)), "", true, true)
	check(canon.call(a) == canon.call(b), "the loaded world equals the saved one, float for float")
	var eb := GameEngine.new(loader, b)
	for i in 12:
		ea.advance_day()
		if ea.pending_match != null:
			ea.complete_pending_match()
		eb.advance_day()
		if eb.pending_match != null:
			eb.complete_pending_match()
	check(canon.call(a) == canon.call(b), "twelve days later both worlds are still identical")


func test_world_generation_is_deterministic() -> void:
	print("world generation: the same seed gives the same world, and the New Game preview shows its clubs")
	var gen := WorldGenerator.new(loader)
	var a := gen.generate(4242)
	var b := gen.generate(4242)
	var ja := JSON.stringify(a.to_dict(), "", true, true)
	check(ja == JSON.stringify(b.to_dict(), "", true, true), "two worlds generated from seed 4242 are identical")
	var preview := gen.preview_clubs(4242)
	var shown := func(w: World) -> String:
		var rows: Array = []
		for c in w.clubs_sorted():
			rows.append([c.id, c.name, c.city, c.colors, c.founded, c.league_id])
		return JSON.stringify(rows)
	check(shown.call(preview) == shown.call(a), "the preview's clubs are the generated world's clubs")


func test_platform_js_source() -> void:
	print("platform: a page call JSON-encodes every argument once")
	var args := ["O'Neil \"the\" </script>\n", 3, true, JSON.stringify({"season": 1994})]
	var src := Platform._js_source("text, n, on, body", "return text;", args)
	var head := "(function (text, n, on, body) {return text;})("
	check(src.begins_with(head) and src.ends_with(");"), "the call wraps the body in a function of the params (%s)" % src)
	var back = JSON.parse_string("[" + src.substr(head.length(), src.length() - head.length() - 2) + "]")
	check(back is Array and back.size() == 4 and back[0] == args[0] and back[1] == 3 and back[2] == true and back[3] == args[3], "each argument comes back as the value passed, the JSON body as a string (%s)" % str(back))
