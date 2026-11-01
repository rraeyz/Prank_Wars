extends Node
## Test bodies. Loaded by run_tests.gd after autoloads exist.

var passes := 0
var fails := 0
var only := ""


func check(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
		print("  ok   ", msg)
	else:
		fails += 1
		print("  FAIL ", msg)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	_run.call_deferred()


func _run() -> void:
	print("== unit tests")
	test_scoring()
	test_timeline()
	test_house()
	test_sample_one()
	test_i18n()
	print("== integration tests")
	for t in ["banana", "combo", "bucket", "paint_fridge", "spring", "task_flow", "disarm", "bump_chain", "placement", "sandbox", "ghost", "security", "rules", "rush", "sniff", "awards", "full_match"]:
		if only != "" and only != t:
			continue
		print("-- ", t)
		await _dispatch(t)
		await _teardown()
	print("\n%d passed, %d failed" % [passes, fails])
	print("TESTS PASSED" if fails == 0 else "TESTS FAILED")
	get_tree().quit(0 if fails == 0 else 1)


func _dispatch(t: String) -> void:
	match t:
		"banana": await it_banana()
		"combo": await it_combo()
		"bucket": await it_bucket()
		"paint_fridge": await it_paint_fridge()
		"spring": await it_spring()
		"task_flow": await it_task_flow()
		"disarm": await it_disarm()
		"bump_chain": await it_bump_chain()
		"placement": await it_placement()
		"sandbox": await it_sandbox()
		"ghost": await it_ghost()
		"security": await it_security()
		"rules": await it_rules()
		"rush": await it_rush()
		"sniff": await it_sniff()
		"awards": await it_awards()
		"full_match": await it_full_match()


# ------------------------------------------------------------------ unit

func test_scoring() -> void:
	check(Scoring.chain_value(1) == 10 and Scoring.chain_value(2) == 20 and Scoring.chain_value(3) == 40 and Scoring.chain_value(4) == 80, "chain values 10/20/40/80")
	var s := Scoring.new()
	s.start_round()
	var r1 := s.prank_hit(-1, 0, "banana", "A", 1.0)
	check(r1["links"] == 1 and r1["delta"] == 10, "first hit = 10")
	var r2 := s.prank_hit(r1["chain"], 0, "bump", "B", 2.0)
	var r3 := s.prank_hit(r1["chain"], 0, "bucket", "B", 3.0)
	var r4 := s.prank_hit(r1["chain"], 0, "marbles", "C", 4.0)
	check(r2["delta"] == 10 and r3["delta"] == 20 and r4["delta"] == 40, "chain deltas 10/20/40")
	check(s.totals[0] == 80, "4-link chain = 80 total (report example)")
	var other := s.prank_hit(-1, 0, "banana", "D", 5.0)
	check(other["chain"] != r1["chain"] and s.totals[0] == 90, "new chain starts separately")
	var wrong_team := s.prank_hit(r1["chain"], 1, "banana", "E", 6.0)
	check(wrong_team["links"] == 1, "chain of another team is not extended")
	var best := s.best_chain()
	check(best["id"] == r1["chain"] and best["links"].size() == 4 and best["t0"] == 1.0 and best["t1"] == 4.0, "best chain picked")
	check(s.task_done(1, "shower", 7.0) == 15 and s.totals[1] == 25, "task +15")
	check(s.disarmed(1, "banana", 8.0) == 10 and s.totals[1] == 35, "disarm +10")
	var mp := s.mess_points(0, [100.0, 40.0, 0.0, 250.0], 9.0)
	check(mp == 60, "mess points: (100+40+0+100)/4 = 60 (got %d)" % mp)
	check(s.round_pts[0] == 150, "round points tracked")
	s.start_round()
	check(s.round_pts[0] == 0 and s.totals[0] == 150 and s.chains.is_empty(), "round reset keeps totals")
	check(s.winner() == 0, "winner")


func test_timeline() -> void:
	var tl := Timeline.new()
	tl.push(1.0, PackedFloat32Array([5, 0, 0, 0, 0, 0, 0, 1, 0, 7, 1, 1, 1, 0, 0, 0, 1, 3]))
	tl.push(2.0, PackedFloat32Array([5, 10, 0, 0, 0, 0, 0, 1, 1]))
	tl.push(1.5, PackedFloat32Array([5, 99, 0, 0, 0, 0, 0, 1, 1]))  # out of order: dropped
	check(tl.frames.size() == 2, "out-of-order frame dropped")
	var s := tl.sample(1.5)
	check(s.has(5) and absf(s[5][0].x - 5.0) < 0.01, "interpolates x halfway (got %s)" % str(s[5][0]))
	check(s.has(7) and s[7][0] == Vector3(1, 1, 1) and int(s[7][2]) == 3, "absent entity keeps last state")
	var s2 := tl.sample(0.5)
	check(s2.is_empty(), "before first frame -> nothing")
	var s3 := tl.sample(5.0)
	check(absf(s3[5][0].x - 10.0) < 0.01, "after last frame holds last")
	tl.push(2.05, PackedFloat32Array([5, 30, 0, 0, 0, 0, 0, 1, 1]))
	var s4 := tl.sample(2.025)
	check(s4[5][0].x == 30.0, "teleport (>4m) is not smeared")
	tl.add_event(1.2, "sfx", ["pop"])
	check(tl.events_between(1.0, 1.3).size() == 1 and tl.events_between(1.3, 2.0).is_empty(), "events window")


func test_house() -> void:
	var h := House.new()
	get_tree().root.add_child(h)
	h.build()
	check(h.doors.size() == 6, "6 doors")
	check(h.cupboards.has("fridge") and h.cupboards.has("cat_cabinet"), "task cupboards exist")
	for t in Config.TASKS:
		for st in Config.TASKS[t]:
			var at: String = st["at"]
			var ok: bool = h.spots.has(at) or h.cupboards.has(at)
			if st["type"] == "pickup":
				ok = false
				for p in h.props:
					if p.kind == at:
						ok = true
			check(ok, "task %s step target '%s' exists" % [t, at])
	var p: Array = h.path(Vector3(-1, 0, 10), Vector3(-5.3, 0, -5.1))
	check(p.size() >= 3 and p[-1] == Vector3(-5.3, 0, -5.1), "garden -> kitchen path has waypoints (%d)" % p.size())
	var through_front := false
	for w in p:
		if absf(w.x + 1.0) < 0.01 and absf(w.z - 7.0) < 0.2:
			through_front = true
	check(through_front, "path goes through the front door")
	check(h.room_of(Vector3(3, 0, -3)) == "living" and h.room_of(Vector3(-5, 0, 3)) == "bath" and h.room_of(Vector3(0, 0, 10)) == "garden", "room_of")
	h.free()


# ------------------------------------------------------------------ integration helpers

var w: World


func _make_world(players: Dictionary, sandbox := false) -> void:
	Net.leave()
	Config.sandbox = sandbox
	Net.mode = "practice"
	Net.players = players
	Config.intro_time = 0.5
	Config.setup_time = 5.0
	Config.run_time = 15.0
	Config.score_time = 1.0
	Config.replay_time = 3.0
	Config.rounds = 2
	w = World.new()
	get_tree().root.add_child(w)
	await _frames(3)


func _teardown() -> void:
	if w:
		w.queue_free()
		w = null
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _seconds(s: float) -> void:
	await _frames(int(s * 60.0))


func _p(n: String, team: int, slot: int, bot := false) -> Dictionary:
	return {"name": n, "team": team, "color": slot - 1, "bot": bot, "slot": slot}


func _two_players() -> Dictionary:
	# slot 1 = trapper (team 0), slot 2/3 = runners (team 1). Not bots: the test drives them.
	return {1: _p("Trap", 0, 1), 2: _p("Run", 1, 2), 3: _p("Run2", 1, 3)}


## Forces the run phase with the given pranks placed (type, pos, socket).
func _setup_run(list: Array) -> void:
	w._set_phase("setup", 999.0)
	for e in list:
		var pid: int = w._next_prank_id
		w._next_prank_id += 1
		w.s_spawn_prank(pid, e[0], 0, e[1], 0.0, e[2] if e.size() > 2 else "")
	w._start_run()
	w._phase_end = Config.now + 999.0
	await _frames(2)


func _runner(slot: int) -> Avatar:
	return w.avatars[slot]


func _walk(a: Avatar, dir: Vector2, secs: float) -> void:
	for i in int(secs * 60.0):
		a.in_move = dir
		await get_tree().physics_frame
	a.in_move = Vector2.ZERO


# ------------------------------------------------------------------ integration tests

func it_banana() -> void:
	await _make_world(_two_players())
	await _setup_run([["banana", Vector3(3, 0, 2), ""]])
	var a := _runner(2)
	a.respawn(Vector3(3, 0.8, 4.5))
	_runner(3).respawn(Vector3(6.5, 0.8, 1.5))
	await _frames(10)
	var was_down := false
	for i in 120:
		a.in_move = Vector2(0, -1)
		await get_tree().physics_frame
		if a.down:
			was_down = true
	check(was_down, "runner slipped on banana (ragdoll)")
	check(w.scoring.totals[0] == 10, "trapper +10 (got %d)" % w.scoring.totals[0])
	var p: Prank = w.pranks.values()[0]
	check(p.used, "banana used up")
	await _seconds(3.5)
	check(not a.is_knocked(), "runner stood back up by itself")


func it_combo() -> void:
	await _make_world(_two_players())
	await _setup_run([["tape", Vector3(3, 0, 3), ""], ["flour", Vector3(3, 2.55, 3), ""]])
	var a := _runner(2)
	a.respawn(Vector3(3, 0.8, 4.6))
	_runner(3).respawn(Vector3(6.5, 0.8, 5))
	await _walk(a, Vector2(0, -1), 0.8)
	check(Config.now < a.stuck_until, "runner stuck on tape")
	var flour: Prank = null
	for id in w.pranks:
		if w.pranks[id].type == "flour":
			flour = w.pranks[id]
	w.remote_trigger(0, flour.id)
	await _frames(5)
	check(flour.used, "flour fired remotely")
	check(w.scoring.totals[0] == 20, "tape + flour on same victim = 2-link chain = 20 (got %d)" % w.scoring.totals[0])
	check(a.mess > 0.0, "victim got floured (mess %.0f)" % a.mess)
	var best := w.scoring.best_chain()
	check(best["links"].size() == 2, "best chain has 2 links")


func it_bucket() -> void:
	await _make_world(_two_players())
	var door: HouseDoor = w.house.doors["hall_bed"]
	await _setup_run([["bucket", door.bucket_slot.global_position, "hall_bed"]])
	var a := _runner(2)
	a.respawn(Vector3(-0.5, 0.8, 3.0))
	_runner(3).respawn(Vector3(-2, 0.8, 5))
	await _frames(5)
	await _walk(a, Vector2(1, 0), 1.5)
	check(w.scoring.totals[0] == 10, "bucket over door hit (+10, got %d)" % w.scoring.totals[0])
	check(Config.now < a.slow_until, "runner is wet and slowed")


func it_paint_fridge() -> void:
	await _make_world(_two_players())
	w.tasks = [{"id": "sandwich", "step": 0, "done": false}]
	var fridge: Cupboard = w.house.cupboards["fridge"]
	await _setup_run([["paint", fridge.inside_point(), "fridge"]])
	var a := _runner(2)
	_runner(3).respawn(Vector3(5, 0.8, 4))
	a.respawn(fridge.front_point() + Vector3(0, 0.8, 0.2))
	await _frames(10)
	a.in_interact = true
	await _seconds(1.0)
	a.in_interact = false
	check(w.scoring.totals[0] >= 10, "paint bomb in fridge fired on open (got %d)" % w.scoring.totals[0])
	check(a.mess >= 40.0, "runner covered in paint (%.0f)" % a.mess)
	check(w.tasks[0]["step"] == 1, "fridge step of sandwich advanced")


func it_spring() -> void:
	await _make_world(_two_players())
	await _setup_run([["spring", Vector3(4, 0, -3), ""]])
	var a := _runner(2)
	a.respawn(Vector3(4, 0.8, -1.5))
	_runner(3).respawn(Vector3(6.5, 0.8, 4))
	await _frames(5)
	var max_y := 0.0
	for i in 90:
		a.in_move = Vector2(0, -1)
		await get_tree().physics_frame
		max_y = maxf(max_y, a.global_position.y)
	check(max_y > 2.0, "spring launched runner (max y %.1f)" % max_y)
	check(max_y < 3.2, "invisible ceiling kept runner inside")
	check(w.scoring.totals[0] == 10, "spring +10")


func it_task_flow() -> void:
	await _make_world(_two_players())
	w.tasks = [{"id": "trash", "step": 0, "done": false}, {"id": "shower", "step": 0, "done": false}]
	await _setup_run([])
	var a := _runner(2)
	_runner(3).respawn(Vector3(-7.2, 0.8, 5.2))
	var bag: Prop = w._prop_of_kind("trash_bag")
	a.respawn(bag.global_position + Vector3(0.6, 0.5, 0))
	await _frames(10)
	a.in_interact = true
	await _seconds(0.5)
	a.in_interact = false
	check(a.carrying == bag, "picked up the trash bag")
	check(w.tasks[0]["step"] == 1, "pickup step done")
	a.respawn(Vector3(6.2, 0.8, 10.0))
	a.carrying = bag
	bag.carrier = a
	bag.freeze = true
	await _frames(10)
	check(w.tasks[0]["done"], "trash delivered -> task done")
	var r3 := _runner(3)
	r3.in_interact = true
	await _seconds(3.5)
	check(w.tasks[1]["done"], "shower hold task done")
	check(w.scoring.totals[1] == 30, "runners +30 for two chores (got %d)" % w.scoring.totals[1])


func it_disarm() -> void:
	await _make_world(_two_players())
	await _setup_run([["banana", Vector3(3, 0, 2), ""]])
	var a := _runner(2)
	_runner(3).respawn(Vector3(6.5, 0.8, 5))
	a.respawn(Vector3(3, 0.8, 2.9))
	await _frames(10)
	a.in_interact = true
	await _seconds(1.6)
	a.in_interact = false
	var p: Prank = w.pranks.values()[0]
	check(p.disarmed, "banana disarmed")
	check(w.scoring.totals[1] == 10, "runner team +10 for disarm")
	await _walk(a, Vector2(0, -1), 1.0)
	check(w.scoring.totals[0] == 0 and not a.down, "disarmed banana does nothing")


func it_bump_chain() -> void:
	await _make_world(_two_players())
	await _setup_run([["banana", Vector3(3, 0, 3), ""]])
	var a := _runner(2)
	var b := _runner(3)
	a.respawn(Vector3(3, 0.8, 3.0))
	b.respawn(Vector3(3, 0.8, 1.7))
	await _frames(3)
	var p: Prank = w.pranks.values()[0]
	p.fire(a)  # banana throws the runner forward (-Z) into the teammate
	for i in 60:
		await get_tree().physics_frame
		if b.down:
			break
	check(b.down, "flying runner knocked over a teammate")
	check(w.scoring.totals[0] == 20, "banana -> bump = 2-link chain = 20 (got %d)" % w.scoring.totals[0])


func it_placement() -> void:
	await _make_world(_two_players())
	w._set_phase("setup", 999.0)
	var t := _runner(1)
	t.respawn(Vector3(-1, 0.8, 3))
	await _frames(3)
	var pl: Dictionary = w.placement_for("banana", Vector3(-1, 0.8, 3), Vector3.FORWARD)
	check(pl["ok"] and pl["pos"].y == 0.0, "banana on hallway floor ok")
	check(w.host_place(1, "banana", pl["pos"], 0.0, ""), "host accepts placement")
	check(w.budget[0] == Config.BUDGET - 1, "budget charged")
	check(not w.host_place(1, "banana", pl["pos"] + Vector3(0.1, 0, 0), 0.0, ""), "too close to another prank -> rejected")
	var dpl: Dictionary = w.placement_for("bucket", Vector3(-1, 0.8, 3.6), Vector3.FORWARD)
	check(dpl["ok"] and dpl["socket"] != "", "bucket snaps to a door (%s)" % dpl["socket"])
	var cpl: Dictionary = w.placement_for("paint", w.house.cupboards["hall_cabinet"].front_point(), Vector3.FORWARD)
	check(cpl["ok"] and cpl["socket"] == "hall_cabinet", "paint goes into the hall cabinet")
	var far: Dictionary = w.placement_for("banana", Vector3(0, 0.8, 12), Vector3.FORWARD)
	check(not far["ok"], "can't place in the garden")
	w.budget[0] = 1
	check(not w.host_place(1, "spring", Vector3(-1, 0, 1.5), 0.0, ""), "not enough budget -> rejected")
	check(not w.host_place(2, "banana", Vector3(-2, 0, 4), 0.0, ""), "runner can't place")


func it_sandbox() -> void:
	await _make_world({5: _p("Me", 0, 1), -1: _p("B1", 1, 2, true)}, true)
	check(w.phase == "sandbox", "sandbox phase")
	var me := _runner(1)
	me.respawn(Vector3(3, 0.8, -1.5))
	await _frames(5)
	check(w.host_place(1, "banana", Vector3(3, 0, -3), 0.0, ""), "free placement in sandbox")
	check(w.budget[0] == 999, "no budget cost")
	await _walk(me, Vector2(0, -1), 1.0)
	check(w.scoring.totals[0] == 10, "you can prank yourself in sandbox (got %d)" % w.scoring.totals[0])
	w._sandbox_action("rearm")
	await _frames(3)
	var p: Prank = w.pranks.values()[0]
	check(w.pranks.size() == 1 and p.armed and not p.used, "re-arm restores the traps")
	w._sandbox_action("clear")
	check(w.pranks.is_empty(), "clear removes traps")
	Config.sandbox = false


func it_full_match() -> void:
	# 2v2 all bots, 2 rounds, quick timers: must reach the end without errors.
	var players := {-1: _p("B1", 0, 1, true), -2: _p("B2", 0, 2, true), -3: _p("B3", 1, 3, true), -4: _p("B4", 1, 4, true)}
	await _make_world(players)
	Config.setup_time = 30.0
	Config.run_time = 50.0
	var phases := {}
	var placed := 0
	var t := 0
	while w.phase != "end" and t < 60 * 60 * 5:
		await get_tree().physics_frame
		t += 1
		phases[w.phase] = true
		placed = maxi(placed, w.pranks.size())
	check(w.phase == "end", "bot match reached the end (%.0fs sim)" % (t / 60.0))
	check(phases.has("setup") and phases.has("run") and phases.has("score"), "went through setup/run/score")
	check(placed >= 3, "bots placed pranks (%d)" % placed)
	var total: int = w.scoring.totals[0] + w.scoring.totals[1]
	check(total > 0, "points were scored (%d - %d)" % [w.scoring.totals[0], w.scoring.totals[1]])
	print("     replay seen: ", phases.has("replay"), "  score ", w.scoring.totals)


func test_sample_one() -> void:
	var tl := Timeline.new()
	tl.push(1.0, PackedFloat32Array([5, 0, 0, 0, 0, 0, 0, 1, 0]))
	tl.push(2.0, PackedFloat32Array([6, 9, 9, 9, 0, 0, 0, 1, 0]))
	tl.push(3.0, PackedFloat32Array([5, 10, 0, 0, 0, 0, 0, 1, 2]))
	var s: Array = tl.sample_one(5, 2.0)
	check(s.size() == 3 and absf(s[0].x - 5.0) < 0.01, "sample_one interpolates across frames missing the entity (%s)" % str(s))
	check(tl.sample_one(5, 9.0)[0].x == 10.0 and tl.sample_one(7, 2.0).is_empty(), "sample_one holds last / unknown id empty")


func test_i18n() -> void:
	var keep: String = I18n.lang
	for l in I18n.ALL_LANGS:
		I18n.set_lang(l)
		check(I18n.t("p_banana") != "p_banana" and I18n.t("chain", [3, 40]).find("40") >= 0, "lang %s: strings + format args" % l)
		check(I18n.t("feed_disarm", ["A", "B", 10]).find("10") >= 0 and I18n.t("winner", ["X"]).find("X") >= 0, "lang %s: feed formats" % l)
	I18n.set_lang("xx")
	check(I18n.lang == "en", "unknown language falls back to English")
	I18n.set_lang(keep)


func it_ghost() -> void:
	await _make_world(_two_players())
	await _setup_run([])
	var trapper := _runner(1)
	check(not trapper.active, "trapper is parked (watching) during chores")
	var r := _runner(2)
	_runner(3).respawn(Vector3(6.5, 0.8, 5))
	r.respawn(Vector3(-5.3, 0.8, -0.6))
	await _frames(5)
	check(not w.ghost_action(1, Vector3(-5.3, 0, -1.6)), "ghost not ready right after chores start")
	w._run_start -= Config.GHOST_DELAY
	var ok: bool = w.ghost_action(1, Vector3(-5.3, 0, -1.6))
	check(ok, "ghost flings the chair after the delay")
	var hit := false
	for i in 90:
		await get_tree().physics_frame
		if r.down:
			hit = true
			break
	check(hit, "flung object knocked the runner")
	check(w.scoring.totals[0] >= 10, "ghost hit scores for the trappers (got %d)" % w.scoring.totals[0])
	check(not w.ghost_action(1, Vector3(-5.3, 0, -1.6)), "cooldown blocks a second haunt")
	check(not w.ghost_action(2, Vector3(-5.3, 0, -1.6)), "runners can't haunt")


func it_security() -> void:
	await _make_world(_two_players())
	w._set_phase("setup", 999.0)
	var t := _runner(1)
	t.respawn(Vector3(-1, 0.8, 3))
	await _frames(3)
	check(not w.host_place(1, "banana", Vector3(NAN, 0, 0), 0.0, ""), "NaN position rejected")
	check(not w.host_place(1, "banana", Vector3(-1, 0, 2), 0.0, "fridge"), "floor prank can't claim a cupboard socket")
	check(not w.host_place(1, "paint", Vector3(-1, 0, 2), 0.0, "front"), "container prank can't go on a door")
	check(not w.host_place(1, "paint", Vector3(-1, 0, 2), 0.0, "no_such_socket"), "unknown socket rejected")
	check(w.host_place(1, "bucket", Vector3(99, 99, 99), 0.0, "hall_bath"), "door socket accepted with any client pos...")
	var b: Prank = w.pranks.values()[0]
	check(b.global_position.distance_to(w.house.doors["hall_bath"].bucket_slot.global_position) < 0.01, "...but placed at the real door position")
	w._host_action(1, "place", [123, "x", "y", 5])
	w._host_action(1, "remote", ["boom"])
	w._host_action(1, "ghost", [42])
	check(w.pranks.size() == 1, "malformed client actions are ignored")
	Net.in_match = true
	var team_before: int = Net.players[2]["team"]
	Net._switch_team(2)
	check(Net.players[2]["team"] == team_before, "can't switch teams mid-match")
	Net.in_match = false



func it_rules() -> void:
	await _make_world(_two_players())
	check(w.modifier == "", "round 1 has no house rule")
	Config.house_rules = true
	w._host_start_round(1)
	await _frames(2)
	check(w.modifier in Config.MODIFIERS, "round 2 gets a house rule (%s)" % w.modifier)
	for m in Config.MODIFIERS:
		w.s_round_reset(1, 1, ["shower"], m)
		await _frames(2)
	w.s_round_reset(1, 1, ["shower"], "hacked_rule")
	check(w.modifier == "", "unknown rule from the network is ignored")
	# double points rule doubles a prank hit
	w._host_start_round(1)
	w.s_round_reset(1, 1, ["shower"], "double")
	w.scoring.mult = 2
	await _setup_run([["banana", Vector3(3, 0, 2), ""]])
	var r := _runner(1)
	r.respawn(Vector3(3, 0.8, 3.2))
	_runner(3).respawn(Vector3(6.5, 0.8, 5))
	w.trapper_team = 1
	_runner(2).park()
	var before: int = w.scoring.totals[0]
	var p: Prank = w.pranks.values()[0]
	p.team = 0
	w.trapper_team = 0
	r.team = 1
	p.fire(r)
	check(w.scoring.totals[0] - before == 20, "double points: banana = 20 (got %d)" % (w.scoring.totals[0] - before))
	# quake knocks things around without errors
	w.modifier = "quake"
	w._quake()
	await _frames(10)
	check(true, "quake ran")


func it_rush() -> void:
	await _make_world(_two_players())
	w.tasks = [{"id": "shower", "step": 0, "done": false}, {"id": "bed", "step": 0, "done": false}]
	Config.run_time = 150.0
	await _setup_run([])
	w._phase_end = Config.now + Config.RUSH_TIME - 1.0
	await _frames(3)
	check(w.rush and w.scoring.mult == 2, "final 30 s: mom's coming home, points x2")
	var r := _runner(3)
	r.respawn(Vector3(-7.2, 0.8, 5.2))
	_runner(2).respawn(Vector3(6.5, 0.8, 5))
	await _frames(5)
	r.in_interact = true
	await _seconds(3.5)
	check(w.scoring.totals[1] == 30, "chore during the rush = 30 (got %d)" % w.scoring.totals[1])
	w._host_start_round(1)
	check(not w.rush and w.scoring.mult == 1, "rush resets next round")


func it_sniff() -> void:
	await _make_world({5: _p("Trap", 0, 1), 6: _p("Run", 1, 2), 3: _p("Run2", 1, 3)})
	var fridge: Cupboard = w.house.cupboards["fridge"]
	await _setup_run([["paint", fridge.inside_point(), "fridge"]])
	var r := _runner(2)
	r.respawn(fridge.front_point() + Vector3(0, 0.8, 1.0))
	await _frames(3)
	w._host_action(2, "reveal", [])
	check(float(w._reveal_ready.get(2, 0.0)) > Config.now, "sniff starts its cooldown")
	w._host_action(2, "reveal", [])
	w.s_reveal(r.global_position)
	check(w.sniffed(fridge.global_position), "the paint bomb in the fridge is sniffed out")
	check(not w.sniffed(Vector3(7, 0, 5)), "far traps are not")
	w._host_action(1, "reveal", [])
	check(not w._reveal_ready.has(1), "trappers can't sniff")
	w._host_action(2, "taunt", [])
	w._host_action(2, "taunt", [])
	check(float(w._taunt_cd.get(2, 0.0)) > Config.now, "taunt has a cooldown")


func it_awards() -> void:
	await _make_world(_two_players())
	await _setup_run([["banana", Vector3(3, 0, 2), ""], ["bucket", w.house.doors["hall_bed"].bucket_slot.global_position, "hall_bed"]])
	for id in w.pranks:
		w.pranks[id].owner_slot = 1
	var r := _runner(2)
	r.respawn(Vector3(3, 0.8, 3.2))
	_runner(3).respawn(Vector3(6.5, 0.8, 5))
	await _frames(3)
	w.pranks.values()[0].fire(r)
	await _frames(3)
	var aw: Array = w.compute_awards()
	var keys := aw.map(func(x): return x[0])
	check("falls" in keys and "trap" in keys, "awards: falls + trap master (%s)" % str(keys))
	for x in aw:
		if x[0] == "falls":
			check(x[1] == "Run", "banana victim award goes to the runner")
		if x[0] == "trap":
			check(x[1] == "Trap" and x[2] == 10, "trap master gets the prank points")
	w.s_awards(aw)
	check(w.awards.size() == aw.size(), "awards reach the HUD")
