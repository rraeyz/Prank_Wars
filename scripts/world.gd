class_name World
extends Node3D
## The match: house, avatars, pranks, round flow, interactions, netcode, replay.
## Host runs the simulation and rules; clients send input and display snapshots.

var house: House
var scoring := Scoring.new()
var timeline := Timeline.new()
var avatars := {}  # slot -> Avatar
var entities := {}  # net id -> Node3D
var pranks := {}  # id -> Prank
var bots := {}  # slot -> Bot
var cam: CameraRig
var hud: Node
var rng := RandomNumberGenerator.new()
var show_names := true
var headless := false

# synced match state
var phase := "none"
var round_i := 0
var trapper_team := 0
var tasks: Array = []  # [{"id", "step", "done"}]
var budget := [Config.BUDGET, Config.BUDGET]
var scores := [0, 0]
var round_scores := [0, 0]
var phase_end_local := 0.0  # Time (seconds) when the phase ends, local clock
var phase_dur := 0.0

# host-only
var _phase_end := 0.0
var _next_prank_id := 1000
var _net_accum := 0.0
var _tick := 0
var _last_sent := {}
var _interact := {}  # slot -> {"key", "t"}
var _prompts := {}  # slot -> [label, progress]
var _chain_victims := {}  # chain id -> [slots]
var _alarm_fails := 0
var _sandbox_log: Array = []
var sandbox := false
var chaos := false

# replay / client display
var replaying := false
var replay := {}
var render_t := 0.0
var _splat_root: Node3D
var _ents: Node3D
var _ghost: Node3D
var _ghost_ring: MeshInstance3D
var _ghost_label: Label3D
var selected := 0  # index in Config.enabled_pranks()
var local_prompt := ["", 0.0]
var _pending_remote := {}
var _clock := 0.0
var _sun: DirectionalLight3D
var _env: Environment
var modifier := ""  # this round's house rule
var rush := false  # "Mom's coming home!" final seconds
var reveal_until := 0.0  # local clock: sniffed traps stay visible until then
var reveal_pos := Vector3.ZERO
var _reveal_local_ready := 0.0
var _reveal_ready := {}  # host: slot -> Config.now
var _taunt_cd := {}
var _quake_at := 0.0
var _stats := {}  # host: slot -> {stat: value}
var awards: Array = []
var comeback_leader := -1
var _event := ""
var _event_at := 0.0
var cat_zoom_until := 0.0
var _cat_turn_at := 0.0
var _cat_dir := Vector3.FORWARD
var _powerup_at := 0.0
var _in_acc := 0.0
var _mouse_mode := false
var _last_mv := Vector2.ZERO
var _last_inter := false


func _ready() -> void:
	name = "World"
	headless = DisplayServer.get_name() == "headless"
	Config.now = 0.0
	house = House.new()
	house.name = "House"
	add_child(house)
	house.build(Config.map)
	_ents = Node3D.new()
	_ents.name = "Ents"
	add_child(_ents)
	_splat_root = Node3D.new()
	_splat_root.name = "Splats"
	add_child(_splat_root)
	for i in house.props.size():
		var p: Prop = house.props[i]
		p.net_id = 100 + i
		p.world = self
		_make_client_body(p)
		register_entity(p.net_id, p)
	_lights()
	for n in house.doors:
		house.doors[n].opened.connect(_on_door_opened.bind(house.doors[n]))
	for pid in Net.players:
		_spawn_avatar(pid)
	cam = CameraRig.new()
	cam.world = self
	add_child(cam)
	var hud_script := load("res://scripts/hud.gd")
	hud = hud_script.new()
	hud.world = self
	add_child(hud)
	_build_ghost()
	Net.players_changed.connect(_on_players_changed)
	sandbox = Config.sandbox
	chaos = Config.mode == "chaos" and not sandbox
	if Net.is_host():
		if sandbox:
			_host_start_sandbox()
			if Config.tutorial:
				var tut: Node = load("res://scripts/tutorial.gd").new()
				tut.world = self
				add_child(tut)
		else:
			_host_start_round(0)


func _lights() -> void:
	var sun := Config.make_sun()
	_sun = sun
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Config.make_env()
	env.environment = e
	add_child(env)
	_env = e
	Config.visuals_changed.connect(func(): Config.apply_env(e))


func _make_client_body(b: RigidBody3D) -> void:
	if Net.is_host():
		return
	b.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	b.freeze = true
	b.collision_layer = 0
	b.collision_mask = 0
	b.contact_monitor = false


func entity_root() -> Node3D:
	return _ents


func register_entity(id: int, n: Node3D) -> void:
	entities[id] = n
	if n is RigidBody3D and n != null:
		_make_client_body(n)


func _spawn_avatar(pid: int) -> Avatar:
	var info: Dictionary = Net.players[pid]
	var a := Avatar.new()
	var slot := int(info["slot"])
	_ents.add_child(a)
	a.setup(self, info, slot, pid)
	a.global_position = Vector3(slot, 0.8, 10)
	avatars[slot] = a
	register_entity(slot, a)
	if Net.is_host() and bool(info["bot"]):
		bots[slot] = Bot.new(self, a)
	return a


func _on_door_opened(opener: Node3D, d: HouseDoor) -> void:
	if not Net.is_host() or not (opener is Avatar):
		return
	for id in pranks:
		var p: Prank = pranks[id]
		if p.socket == d.door_name and p.def["trigger"] == "door" and hits(opener, p.team):
			p.fire(opener)


func _on_players_changed() -> void:
	if not Net.is_host():
		return
	# a human left mid-match: a bot takes over their bean
	for slot in avatars:
		var a: Avatar = avatars[slot]
		if not a.is_bot and not Net.players.has(a.peer_id):
			a.is_bot = true
			a.pname += " (bot)"
			bots[slot] = Bot.new(self, a)


# ------------------------------------------------------------------ queries

func local_slot() -> int:
	var me = Net.players.get(Net.my_id())
	return int(me["slot"]) if me else -1


func local_avatar() -> Avatar:
	return avatars.get(local_slot())


func local_team() -> int:
	var me = Net.players.get(Net.my_id())
	return int(me["team"]) if me else -1


func local_is_trapper() -> bool:
	return chaos or local_team() == trapper_team


func local_sees_pranks(prank_team: int) -> bool:
	return replaying or local_team() == prank_team or phase in ["score", "end"]


func local_view_target() -> Node3D:
	var a := local_avatar()
	if a and a.visible:
		return a
	return cam.spectate_target() if cam else null


func is_runner(a: Avatar) -> bool:
	return sandbox or chaos or a.team != trapper_team


func runner_avatars() -> Array:
	var r := []
	for s in avatars:
		var a: Avatar = avatars[s]
		if a.team != trapper_team:
			r.append(a)
	return r


func avatars_near(p: Vector3, r: float, runners_only: bool, prank_team := -1) -> Array:
	var out := []
	for s in avatars:
		var a: Avatar = avatars[s]
		if not a.active or (runners_only and not is_runner(a)):
			continue
		if chaos and prank_team >= 0 and a.team == prank_team:
			continue
		if U.dist_xz(a.global_position, p) <= r and absf(a.global_position.y - p.y) < 3.0:
			out.append(a)
	return out


func building() -> bool:
	return phase == "setup" or phase == "sandbox" or phase == "chaos"


## Phases where pranks are live and chores count.
func live() -> bool:
	return phase == "run" or phase == "sandbox" or phase == "chaos"


## Can a prank of `prank_team` hurt this bean? In chaos mode only the other team.
func hits(a: Avatar, prank_team: int) -> bool:
	return a.active and is_runner(a) and not (chaos and a.team == prank_team)


## Team that owns a chain (the scorer of the next link).
func chain_team(ch: int) -> int:
	var c = scoring.chains.get(ch)
	return int(c["team"]) if c else trapper_team


func ui_blocking() -> bool:
	return hud != null and hud.has_method("is_blocking") and hud.is_blocking()


func time_left() -> float:
	return maxf(0.0, phase_end_local - _clock)


func replay_focus() -> Node3D:
	return avatars.get(int(replay.get("focus", -1)))


func remote_pranks(team: int) -> Array:
	var r := []
	var ids := pranks.keys()
	ids.sort()
	for id in ids:
		var p: Prank = pranks[id]
		if p.team == team and p.def["trigger"] == "remote" and not p.used and not p.disarmed:
			r.append(p)
	return r


# ------------------------------------------------------------------ main loop

func _process(delta: float) -> void:
	_clock += delta
	if replaying:
		_replay_step(delta)
	elif not Net.is_host():
		_client_interpolate(delta)
	_local_input()
	_update_ghost()


func _physics_process(delta: float) -> void:
	if not Net.is_host():
		return
	Config.now += delta
	if replaying:
		_host_phase_tick()
		return
	for s in bots:
		bots[s].tick(delta)
	_host_interactions(delta)
	for id in pranks:
		pranks[id].host_tick(delta)
	_host_safety()
	_host_phase_tick()
	_net_accum += delta
	if _net_accum >= 1.0 / Config.NET_RATE:
		_net_accum = 0.0
		_send_snapshot()


# ------------------------------------------------------------------ local input

func _local_input() -> void:
	var me := local_avatar()
	if me == null:
		return
	var blocked := ui_blocking()
	var mv := Vector2.ZERO if blocked else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var inter := false if blocked else Input.is_action_pressed("interact")
	if not me.visible:
		mv = Vector2.ZERO
	if Net.is_host():
		if not me.is_bot:
			me.in_move = mv
			me.in_interact = inter
	else:
		# throttle to ~30 Hz, but send changes at once
		_in_acc += get_process_delta_time()
		if _in_acc >= 1.0 / 30.0 or mv != _last_mv or inter != _last_inter:
			_in_acc = 0.0
			_last_mv = mv
			_last_inter = inter
			c_input.rpc_id(1, mv, inter)
	if blocked:
		return
	if Input.is_action_just_pressed("jump"):
		_send_action("jump", [])
	if Input.is_action_just_pressed("taunt") and me.visible:
		_send_action("taunt", [])
	if Input.is_action_just_pressed("reveal") and (phase == "run" and not local_is_trapper() or phase == "chaos") and reveal_wait_local() <= 0.0:
		_reveal_local_ready = _clock + reveal_cooldown(me)
		_send_action("reveal", [])
	if Input.is_action_just_pressed("dive"):
		_send_action("dive", [])
	var list := Config.enabled_pranks()
	if building() and local_is_trapper():
		if Input.is_action_just_pressed("next_item"):
			selected = (selected + 1) % list.size()
			Sfx.play("click")
		if Input.is_action_just_pressed("prev_item"):
			selected = (selected - 1 + list.size()) % list.size()
			Sfx.play("click")
		for i in range(1, 10):
			if Input.is_action_just_pressed("slot_%d" % i) and i - 1 < list.size():
				selected = i - 1
	if Input.is_action_just_pressed("action"):
		if building() and local_is_trapper() and me.visible:
			var pl := local_placement(list[selected])
			if pl["ok"]:
				_send_action("place", [list[selected], pl["pos"], pl["yaw"], pl["socket"]])
			else:
				hud.toast(I18n.t(pl.get("reason", "cant_place")))
				Sfx.play("tick")
		elif me.visible:
			_send_action("throw", [])
	if phase == "run" and local_is_trapper() and not me.visible and (Input.is_action_just_pressed("ghost") or Input.is_action_just_pressed("interact")):
		if ghost_wait_local() <= 0.0:
			_send_action("ghost", [_ghost_point()])
			_ghost_local_ready = _clock + Config.GHOST_COOLDOWN * (0.5 if me.perk == "haunter" else 1.0)
	if phase == "run" and local_is_trapper():
		var rl := remote_pranks(local_team())
		for i in range(1, 10):
			if Input.is_action_just_pressed("slot_%d" % i) and i - 1 < rl.size():
				_send_action("remote", [rl[i - 1].id])
		if Input.is_action_just_pressed("action") and rl.size() > 0:
			var pick: Prank = rl[0]
			if _mouse_mode and cam:
				var mp := get_viewport().get_mouse_position()
				var bd := 140.0
				for rp in rl:
					var sp := cam.unproject_position(rp.global_position)
					if sp.distance_to(mp) < bd:
						bd = sp.distance_to(mp)
						pick = rp
			_send_action("remote", [pick.id])
	if Input.is_action_just_pressed("cam_next"):
		cam.cycle()
	if phase == "chaos" and Input.is_action_just_pressed("trigger_all"):
		_send_action("remote_all", [])
	if phase == "sandbox":
		if Input.is_action_just_pressed("trigger_all"):
			_send_action("remote_all", [])
		if Input.is_action_just_pressed("rearm"):
			_send_action("rearm", [])
		if Input.is_action_just_pressed("clear_all"):
			_send_action("clear", [])


func _send_action(kind: String, args: Array) -> void:
	if Net.is_host():
		_host_action(local_slot(), kind, args)
	else:
		c_action.rpc_id(1, kind, args)


@rpc("any_peer", "unreliable_ordered")
func c_input(mv: Vector2, inter: bool) -> void:
	var a := _sender_avatar()
	if a:
		a.in_move = mv.limit_length(1.0)
		a.in_interact = inter


@rpc("any_peer", "reliable")
func c_action(kind: String, args: Array) -> void:
	var a := _sender_avatar()
	if a:
		_host_action(a.slot, kind, args)


func _sender_avatar() -> Avatar:
	if not Net.is_host():
		return null
	var info = Net.players.get(multiplayer.get_remote_sender_id())
	if info == null:
		return null
	return avatars.get(int(info["slot"]))


func _host_action(slot: int, kind: String, args: Array) -> void:
	var a: Avatar = avatars.get(slot)
	if a == null:
		return
	if not a.active:
		# parked trappers (watching the chores) can still fire remote pranks and haunt
		if a.team == trapper_team and args.size() == 1:
			if kind == "remote" and args[0] is int:
				remote_trigger(a.team, args[0])
			elif kind == "ghost" and args[0] is Vector3:
				ghost_action(slot, args[0])
		return
	match kind:
		"jump":
			a.jump()
		"dive":
			if phase != "replay":
				a.dive()
		"throw":
			if a.carrying and not _is_task_item_locked(a.carrying):
				a.throw_carry()
				fx_all("sfx", ["whoosh", a.global_position])
		"place":
			# untrusted client data: check every type before use
			if args.size() == 4 and args[0] is String and args[1] is Vector3 and (args[2] is float or args[2] is int) and args[3] is String:
				host_place(slot, args[0], args[1], float(args[2]), args[3])
		"remote":
			if args.size() == 1 and args[0] is int and a.team == trapper_team:
				remote_trigger(a.team, args[0])
		"taunt":
			if _taunt_cd.get(slot, 0.0) <= Config.now:
				_taunt_cd[slot] = Config.now + 1.5
				fx_all("taunt", [slot])
		"reveal":
			if live() and is_runner(a) and _reveal_ready.get(slot, 0.0) <= Config.now:
				_reveal_ready[slot] = Config.now + reveal_cooldown(a)
				if a.peer_id == Net.my_id():
					s_reveal(a.global_position)
				elif not a.is_bot and Net.mode == "host":
					s_reveal.rpc_id(a.peer_id, a.global_position)
				fx_all("burst", [a.global_position + Vector3(0, 0.3, 0), "sniff", Color.WHITE])
				fx_all("sfx", ["uhoh", a.global_position])
		"remote_all", "rearm", "clear":
			if phase == "sandbox":
				_sandbox_action(kind)
			elif phase == "chaos" and kind == "remote_all":
				for p in remote_pranks(a.team):
					p.fire(null)


func _is_task_item_locked(_p: Prop) -> bool:
	return false


# ------------------------------------------------------------------ placement

## Where would `type` go for an avatar at `origin` facing `fwd`? Shared by ghost preview, host and bots.
func placement_for(type: String, origin: Vector3, fwd: Vector3) -> Dictionary:
	var def: Dictionary = Config.PRANKS[type]
	fwd = U.flat_xz(fwd).normalized()
	if fwd.length() < 0.1:
		fwd = Vector3.FORWARD
	var res := {"ok": false, "pos": origin, "yaw": atan2(-fwd.x, -fwd.z), "socket": "", "reason": "cant_place"}
	match def["place"]:
		"floor", "surface":
			var p := origin + fwd * 1.0
			var hit := _ray_down(p)
			if hit.is_empty():
				return res
			var floor_only: bool = def["place"] == "floor"
			if floor_only and not hit["collider"].is_in_group("floor"):
				return res
			p = hit["position"]
			if floor_only:
				p.y = 0.0
			if not house.inside(p, 0.25):
				return res
			for id in pranks:
				var o: Prank = pranks[id]
				if o.def["place"] in ["floor", "surface"] and U.dist_xz(o.position, p) < 0.7:
					return res
			res["pos"] = p
			res["ok"] = true
		"ceiling":
			var p2 := origin + fwd * 0.6
			if not house.inside(p2, 0.4):
				return res
			res["pos"] = Vector3(p2.x, 2.55, p2.z)
			res["ok"] = true
			for id in pranks:
				var o2: Prank = pranks[id]
				if o2.def["place"] == "ceiling" and U.dist_xz(o2.position, p2) < 1.0:
					res["ok"] = false
		"door":
			var best: HouseDoor = null
			var bd := 2.2
			for n in house.doors:
				var d: HouseDoor = house.doors[n]
				var dd := U.dist_xz(d.global_position, origin)
				if dd < bd and not _socket_used(n):
					bd = dd
					best = d
			if best:
				res["pos"] = best.bucket_slot.global_position
				res["yaw"] = best.rotation.y
				res["socket"] = best.door_name
				res["ok"] = true
		"container":
			var bc: Cupboard = null
			var bcd := 1.7
			for n in house.cupboards:
				var c: Cupboard = house.cupboards[n]
				var cd := U.dist_xz(c.front_point(), origin)
				if cd < bcd and not _socket_used(n):
					bcd = cd
					bc = c
			if bc:
				res["pos"] = bc.inside_point()
				res["yaw"] = bc.rotation.y
				res["socket"] = bc.cup_name
				res["ok"] = true
		"task":
			var bs := ""
			var bsd := 1.9
			for n in house.spots:
				if not _is_hold_spot(n) or _socket_used(n):
					continue
				var sp: Dictionary = house.spots[n]
				var sd := U.dist_xz(sp["pos"], origin)
				if sd < bsd:
					bsd = sd
					bs = n
			if bs != "":
				res["pos"] = house.spots[bs]["pos"] + Vector3(0, 0.05, 0)
				res["socket"] = bs
				res["ok"] = true
	return res


func _is_hold_spot(n: String) -> bool:
	for t in Config.TASKS:
		for st in Config.TASKS[t]:
			if st["type"] == "hold" and st["at"] == n:
				return true
	return false


func _socket_used(n: String) -> bool:
	for id in pranks:
		if pranks[id].socket == n:
			return true
	return false


func _ray_down(p: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 2.45, p.z), Vector3(p.x, -0.5, p.z), U.L_WORLD)
	return space.intersect_ray(q)


## Host-side validation of a requested placement. Sockets must exist, match the prank's kind and be free;
## free placements must be finite, inside the house, on the right kind of surface and not too close to others.
func canonical_placement(type: String, pos: Vector3, socket: String) -> Dictionary:
	var bad := {"ok": false, "pos": Vector3.ZERO, "yaw": 0.0}
	if not Config.PRANKS.has(type) or not pos.is_finite():
		return bad
	var place: String = Config.PRANKS[type]["place"]
	if socket != "" and _socket_used(socket):
		return bad
	match place:
		"door":
			if not house.doors.has(socket):
				return bad
			var d: HouseDoor = house.doors[socket]
			return {"ok": true, "pos": d.bucket_slot.global_position, "yaw": d.rotation.y}
		"container":
			if not house.cupboards.has(socket):
				return bad
			var c: Cupboard = house.cupboards[socket]
			return {"ok": true, "pos": c.inside_point(), "yaw": c.rotation.y}
		"task":
			if not house.spots.has(socket) or not _is_hold_spot(socket):
				return bad
			return {"ok": true, "pos": house.spots[socket]["pos"] + Vector3(0, 0.05, 0), "yaw": 0.0}
	if socket != "" or not house.inside(pos, 0.2):
		return bad
	var p := pos
	if place == "ceiling":
		p.y = 2.55
	else:
		var hit := _ray_down(p)
		if hit.is_empty() or (place == "floor" and not hit["collider"].is_in_group("floor")):
			return bad
		p = hit["position"]
		if place == "floor":
			p.y = 0.0
	for id in pranks:
		var o: Prank = pranks[id]
		if o.def["place"] == place and U.dist_xz(o.position, p) < 0.6:
			return bad
	return {"ok": true, "pos": p, "yaw": 0.0}


func host_place(slot: int, type: String, pos: Vector3, yaw: float, socket: String) -> bool:
	var a: Avatar = avatars.get(slot)
	if a == null or not building() or (a.team != trapper_team and not chaos) or not Config.PRANKS.has(type):
		return false
	if not type in Config.enabled_pranks():
		return false
	var cost: int = Config.PRANKS[type]["cost"]
	if phase == "sandbox":
		cost = 0
	if budget[a.team] < cost:
		_toast_to(a, "no_budget")
		return false
	# never trust the client position: rebuild it from the host's own house data
	var canon := canonical_placement(type, pos, socket)
	if not canon["ok"] or U.dist_xz(a.global_position, canon["pos"]) > 7.0:
		return false
	pos = canon["pos"]
	if socket != "":
		yaw = canon["yaw"]
	budget[a.team] -= cost
	var pid := _next_prank_id
	_next_prank_id += 1
	if Net.mode == "host":
		s_spawn_prank.rpc(pid, type, a.team, pos, yaw, socket)
	s_spawn_prank(pid, type, a.team, pos, yaw, socket)
	pranks[pid].owner_slot = slot
	if a.perk == "master":
		fx_all("prank", [pid, "master"])
	if phase == "sandbox":
		pranks[pid].arm()
		_sandbox_log.append([type, a.team, pos, yaw, socket])
	elif phase == "chaos":
		pranks[pid].arm()
	_sync_state()
	return true


@rpc("authority", "reliable")
func s_spawn_prank(pid: int, type: String, team: int, pos: Vector3, yaw: float, socket: String) -> void:
	if pranks.has(pid):
		return
	var p := Prank.new()
	_ents.add_child(p)
	p.global_position = pos
	p.rotation.y = yaw
	p.setup(self, pid, type, team, socket)
	pranks[pid] = p
	if house.cupboards.has(socket):
		house.cupboards[socket].prank = p
	if not headless and local_team() == team:
		Sfx.play("place", pos)
		Fx.burst(self, pos, "sparkle")


func remote_trigger(team: int, pid: int) -> void:
	if not live():
		return
	var p: Prank = pranks.get(pid)
	if p and p.team == team and p.def["trigger"] == "remote":
		p.fire(null)


# ------------------------------------------------------------------ scoring hooks (host)

## Registers a prank hit and returns the chain id to tag the victim with.
## The umbrella eats one prank: no points, no effect (effects check victim.immune()).
func _absorbed(victim: Avatar) -> bool:
	if victim.immune():
		return true
	if victim.steady > 0:
		victim.steady -= 1
		victim.immune_until = Config.now + 0.4
		fx_all("burst", [victim.global_position + Vector3(0, 1.0, 0), "sparkle", Color.WHITE])
		feed_all("feed_steady", [victim.pname], victim.team)
		return true
	if victim.shield_until > Config.now:
		victim.shield_until = 0.0
		victim.immune_until = Config.now + 0.4
		fx_all("sfx", ["pop", victim.global_position])
		fx_all("burst", [victim.global_position + Vector3(0, 1.2, 0), "sparkle", Color.WHITE])
		feed_all("feed_shield", [victim.pname], victim.team)
		return true
	return false


func prank_hit(p: Prank, victim: Avatar, cause: Node3D) -> int:
	if _absorbed(victim):
		return -1
	var ch := -1
	if cause is Avatar and (cause as Avatar).is_chained():
		ch = (cause as Avatar).chain_id
	elif cause is Prop and (cause as Prop).is_chained(Config.now):
		ch = (cause as Prop).chain_id
	elif victim.is_chained():
		ch = victim.chain_id
	var r := scoring.prank_hit(ch, p.team, p.type, victim.pname, Config.now)
	stat(p.owner_slot, "trap", r["delta"])
	if not _chain_victims.has(r["chain"]):
		_chain_victims[r["chain"]] = []
	_chain_victims[r["chain"]].append(victim.slot)
	victim.set_chain(r["chain"], Config.now + 2.5)
	feed_all("feed_prank", ["@p_" + p.type, victim.pname, r["delta"]], p.team)
	if r["links"] >= 2:
		feed_all("chain", [r["links"], Scoring.chain_value(r["links"])], p.team, true)
	_sync_state()
	return r["chain"]


func on_bump(knocked: Avatar, other: Avatar) -> void:
	## A flying bean knocked over another bean. Counts as a chain link if the flyer was pranked.
	var v := knocked.pre_vel
	var ch := -1
	var bt := chain_team(knocked.chain_id)
	if live() and knocked.is_chained() and hits(other, bt) and not _absorbed(other):
		var r := scoring.prank_hit(knocked.chain_id, bt, "bump", other.pname, Config.now)
		ch = r["chain"]
		if not _chain_victims.has(ch):
			_chain_victims[ch] = []
		_chain_victims[ch].append(other.slot)
		feed_all("feed_prank", ["@p_bump", other.pname, r["delta"]], bt)
		if r["links"] >= 2:
			feed_all("chain", [r["links"], Scoring.chain_value(r["links"])], bt, true)
		_sync_state()
	other.knock(U.flat_xz(v) * 0.6 + Vector3.UP * 3.5, Vector3(randf_range(-8, 8), 0, randf_range(-8, 8)), 1.6, ch)
	fx_all("sfx", ["thud", other.global_position])


func on_prop_hit(p: Prop, body: Node) -> void:
	if not Net.is_host() or not (body is Avatar):
		return
	var a: Avatar = body
	if not a.active or a.is_knocked():
		return
	var now := Config.now
	var spd := p.linear_velocity.length()
	if p.kind == "vacuum":
		for id in pranks:
			if pranks[id].vac == p:
				if live() and hits(a, pranks[id].team):
					pranks[id].vacuum_bump(a)
		return
	if p.kind == "marble":
		var mt := chain_team(p.chain_id)
		if live() and hits(a, mt) and spd > 1.2 and p.is_chained(now) and not _absorbed(a):
			var r := scoring.prank_hit(p.chain_id, mt, "marbles", a.pname, now)
			_chain_victims.get_or_add(r["chain"], []).append(a.slot)
			p.chain_id = r["chain"]
			feed_all("feed_prank", ["@p_marbles", a.pname, r["delta"]], mt)
			if r["links"] >= 2:
				feed_all("chain", [r["links"], Scoring.chain_value(r["links"])], mt, true)
			var d := a.move_dir()
			a.knock(d * 5.0 + Vector3.UP * 3.0, d.cross(Vector3.UP) * 11.0, 1.8, r["chain"])
			fx_all("sfx", ["slip", a.global_position])
			_sync_state()
		return
	if now < p.ghost_until and phase == "run" and is_runner(a) and spd > 3.0:
		p.ghost_until = 0.0
		var gch: int = _ghost_hit(p.ghost_team, a, p.ghost_slot)
		a.knock(p.linear_velocity * 0.5 + Vector3.UP * 3.0, Vector3(randf_range(-8, 8), 0, randf_range(-8, 8)), 1.5, gch)
		p.chain_id = gch
		p.chain_until = now + 2.0
		fx_all("sfx", ["thud", a.global_position])
		return
	if spd < 5.0:
		return
	var pt := chain_team(p.chain_id)
	if p.is_chained(now) and live() and hits(a, pt) and not _absorbed(a):
		var r2 := scoring.prank_hit(p.chain_id, pt, "bump", a.pname, now)
		_chain_victims.get_or_add(r2["chain"], []).append(a.slot)
		feed_all("feed_prank", ["@p_bump", a.pname, r2["delta"]], pt)
		a.knock(p.linear_velocity * 0.5 + Vector3.UP * 3.0, Vector3(randf_range(-8, 8), 0, randf_range(-8, 8)), 1.5, r2["chain"])
		_sync_state()
	elif now < p.thrown_until and p.thrown_by != a:
		a.knock(p.linear_velocity * 0.5 + Vector3.UP * 3.0, Vector3(randf_range(-8, 8), 0, randf_range(-8, 8)), 1.3)
		fx_all("sfx", ["thud", a.global_position])


func blind(a: Avatar, kind: String, dur: float) -> void:
	if not a.immune():
		fx_all("blind", [a.slot, kind, dur])


func add_mess(a: Avatar, amount: float, c: Color, kind: String) -> void:
	if a.immune():
		return
	stat(a.slot, "mess", amount)
	fx_all("mess", [a.slot, amount, c, kind])


func alarm_failed(p: Prank) -> void:
	scoring.bonus(p.team, Config.ALARM_POINTS, "alarm", Config.now)
	feed_all("feed_alarm_fail", [Config.ALARM_POINTS], p.team)
	_sync_state()


func _toast_to(a: Avatar, key: String) -> void:
	if a.is_bot:
		return
	if a.peer_id == Net.my_id():
		hud.toast(I18n.t(key))
	elif Net.mode == "host":
		s_toast.rpc_id(a.peer_id, key)


@rpc("authority", "reliable")
func s_toast(key: String) -> void:
	hud.toast(I18n.t(key))


# ------------------------------------------------------------------ interactions (host)

func _task_targets() -> Array:
	## Current step of each unfinished task -> [{"task", "type", "at", "pos", "radius", "time"}]
	var out := []
	for t in tasks:
		if t["done"]:
			continue
		var st: Dictionary = Config.TASKS[t["id"]][t["step"]]
		var e := {"task": t["id"], "type": st["type"], "at": st["at"], "time": float(st.get("time", 0.3))}
		match st["type"]:
			"hold", "deliver":
				var sp: Dictionary = house.spots[st["at"]]
				e["pos"] = sp["pos"]
				e["radius"] = sp["radius"]
			"open":
				var c: Cupboard = house.cupboards[st["at"]]
				e["pos"] = c.front_point()
				e["radius"] = 1.3
			"pickup":
				var pr := _prop_of_kind(st["at"])
				if pr == null:
					continue
				e["pos"] = pr.global_position
				e["radius"] = 1.4
				e["prop"] = pr
		out.append(e)
	return out


func _prop_of_kind(k: String) -> Prop:
	for p in house.props:
		if p.kind == k:
			return p
	return null


## Best thing this avatar can do with E right now -> {"key", "label", "time", "do": Callable} or {}.
func _best_interaction(a: Avatar) -> Dictionary:
	var pos := a.global_position
	if live() and is_runner(a):
		for pu in house.props:
			if pu.kind in Config.POWERUPS and not pu.hidden_prop and U.dist_xz(pu.global_position, pos) < 1.3:
				return {"key": "pu%d" % pu.net_id, "label": I18n.t("act_grab") + ": " + I18n.t("pu_" + pu.kind), "time": 0.15, "do": _take_powerup.bind(a, pu)}
	if live() and is_runner(a):
		for id in pranks:
			var p: Prank = pranks[id]
			if p.used or p.disarmed or not p.armed or (chaos and p.team == a.team):
				continue
			if not (p.def["reveal"] or p.ringing):
				continue
			if p.type == "alarm" and not p.ringing:
				continue
			if p.type == "cake":
				if U.dist_xz(p.net_pos(), pos) < 1.3:
					return {"key": "cake%d" % id, "label": I18n.t("eat_cake", [Config.CAKE_BONUS]), "time": 1.0, "do": p.fire.bind(a)}
				continue
			if U.dist_xz(p.net_pos(), pos) < 1.3:
				return {"key": "disarm%d" % id, "label": I18n.t("act_disarm") + ": " + I18n.t("p_" + p.type), "time": 1.2,
					"do": _do_disarm.bind(a, p)}
		for e in _task_targets():
			if e["type"] == "deliver":
				continue
			if U.dist_xz(e["pos"], pos) > e["radius"]:
				continue
			if e["type"] == "pickup" and a.carrying:
				continue
			var lbl := I18n.t("s_" + str(e["at"]))
			return {"key": "task_%s_%s" % [e["task"], e["at"]], "label": lbl, "time": e["time"],
				"do": _do_task_step.bind(a, e)}
	if live() and is_runner(a) and cat_zoom_until > Config.now:
		var cat := _prop_of_kind("cat")
		if U.dist_xz(cat.global_position, pos) < 1.3:
			return {"key": "cat", "label": I18n.t("catch_cat"), "time": 0.25, "do": _catch_cat.bind(a)}
	if phase in ["setup", "run", "intro", "sandbox", "chaos"] and not a.carrying:
		var best: Prop = null
		var bd := 1.3
		for p in house.props:
			if not p.carryable or p.carrier or p.hidden_prop:
				continue
			var d := U.dist_xz(p.global_position, pos)
			if d < bd and absf(p.global_position.y - pos.y) < 1.5:
				bd = d
				best = p
		if best:
			return {"key": "grab%d" % best.net_id, "label": I18n.t("act_grab"), "time": 0.15, "do": _do_grab.bind(a, best)}
	return {}


func _host_interactions(delta: float) -> void:
	for s in avatars:
		var a: Avatar = avatars[s]
		var best := {}
		if a.can_act():
			best = _best_interaction(a)
		var st: Dictionary = _interact.get(s, {"key": "", "t": 0.0})
		if best.is_empty() or not a.in_interact:
			st = {"key": "" if best.is_empty() else best["key"], "t": 0.0}
		else:
			if st["key"] != best["key"]:
				st = {"key": best["key"], "t": 0.0}
			st["t"] += delta * (1.55 if a.perk == "quick_hands" and str(best["key"]).begins_with("task") else 1.0)
			if st["t"] >= best["time"]:
				best["do"].call()
				st = {"key": "", "t": 0.0}
		_interact[s] = st
		a.interacting = a.in_interact and not best.is_empty()
		var prompt := ["", 0.0]
		if not best.is_empty():
			prompt = [best["label"], clampf(st["t"] / maxf(best["time"], 0.01), 0.0, 1.0)]
		_send_prompt(a, prompt)
		# deliveries happen automatically
		if a.carrying and live() and is_runner(a):
			for e in _task_targets():
				if e["type"] == "deliver" and U.dist_xz(e["pos"], a.global_position) < e["radius"]:
					var item_kind: String = Config.TASKS[e["task"]][0]["at"]
					if a.carrying.kind == item_kind:
						var it := a.carrying
						a.drop_carry()
						it.set_hidden(true)
						_advance_task(e["task"], a)


func _send_prompt(a: Avatar, prompt: Array) -> void:
	if a.is_bot:
		return
	var last: Array = _prompts.get(a.slot, ["", -1.0])
	if last[0] == prompt[0] and absf(last[1] - prompt[1]) < 0.05:
		return
	_prompts[a.slot] = prompt
	if a.peer_id == Net.my_id():
		local_prompt = prompt
	elif Net.mode == "host":
		s_prompt.rpc_id(a.peer_id, prompt[0], prompt[1])


@rpc("authority", "unreliable_ordered")
func s_prompt(label: String, progress: float) -> void:
	local_prompt = [label, progress]


func _do_disarm(a: Avatar, p: Prank) -> void:
	if p.disarmed or p.used:
		return
	p.disarm()
	scoring.disarmed(a.team, p.type, Config.now)
	stat(a.slot, "disarms", 1)
	feed_all("feed_disarm", [a.pname, "@p_" + p.type, Config.DISARM_POINTS * scoring.mult], a.team)
	fx_all("prank", [p.id, "disarmed"])
	_sync_state()


func _do_grab(a: Avatar, p: Prop) -> void:
	a.pick_up(p)
	fx_all("sfx", ["pop", a.global_position])
	# picking up a pickup-step item completes that step
	if live() and is_runner(a):
		for e in _task_targets():
			if e["type"] == "pickup" and e.get("prop") == p:
				_advance_task(e["task"], a)


func _do_task_step(a: Avatar, e: Dictionary) -> void:
	match e["type"]:
		"hold":
			for id in pranks:
				var p: Prank = pranks[id]
				if p.socket == e["at"] and p.type == "fake_remote" and p.armed and not p.used:
					p.fire(a)
					return
			fx_all("task_fx", [str(e["at"]), e["pos"]])
			_advance_task(e["task"], a)
		"open":
			var c: Cupboard = house.cupboards[e["at"]]
			open_cupboard(c, a)
			_advance_task(e["task"], a)
		"pickup":
			if e.has("prop"):
				_do_grab(a, e["prop"])


func open_cupboard(c: Cupboard, a: Avatar) -> void:
	fx_all("cup_open", [c.cup_name])
	if c.prank and is_instance_valid(c.prank):
		var p: Prank = c.prank
		if p.armed and not p.used and hits(a, p.team):
			p.fire(a)


func _advance_task(task_id: String, a: Avatar) -> void:
	for t in tasks:
		if t["id"] != task_id or t["done"]:
			continue
		t["step"] += 1
		if t["step"] >= Config.TASKS[task_id].size():
			t["done"] = true
			var tp := scoring.task_done(a.team, task_id, Config.now)
			stat(a.slot, "tasks", 1)
			feed_all("feed_task", ["@t_" + task_id, tp], a.team)
			fx_all("sfx", ["task", a.global_position])
			fx_all("burst", [a.global_position + Vector3(0, 1, 0), "sparkle", Color.WHITE])
		else:
			fx_all("sfx", ["click", a.global_position])
		_sync_state()
		return


func _host_safety() -> void:
	for s in avatars:
		var a: Avatar = avatars[s]
		if a.active and (a.global_position.y < -4.0 or a.global_position.y > 12.0):
			var sp: Vector3 = house.spawn_house[s % 8] if a.team == trapper_team and phase == "setup" else house.spawn_garden[s % 8]
			a.respawn(sp)
	for p in house.props:
		if not p.hidden_prop and p.carrier == null and p.global_position.y < -4.0:
			p.global_transform = p.home
			p.linear_velocity = Vector3.ZERO


# ------------------------------------------------------------------ round flow (host)

func _host_start_round(i: int) -> void:
	round_i = i
	trapper_team = i % 2
	scoring.start_round()
	_chain_victims.clear()
	var picked: Array = _pick_tasks()
	# first round is always plain so new players learn the basics
	var mod := ""
	if Config.rule_choice in Config.MODIFIERS:
		mod = Config.rule_choice
	elif Config.rule_choice == "random" and Config.house_rules and i > 0:
		mod = Config.MODIFIERS[rng.randi() % Config.MODIFIERS.size()]
	if Net.mode == "host":
		s_round_reset.rpc(i, trapper_team, picked, mod)
	s_round_reset(i, trapper_team, picked, mod)
	scoring.mult = 2 if mod == "double" else 1
	for s in avatars:
		avatars[s].gravity_scale = 0.8 if mod == "moon" else 2.2
	for p in house.props:
		p.gravity_scale = 0.3 if mod == "moon" else 1.0
	for s in avatars:
		var a: Avatar = avatars[s]
		var idx: int = s % 8
		if chaos:
			a.respawn(house.spawn_garden[idx] + Vector3(-3.0 if a.team == 0 else 3.0, 0, 0))
		else:
			a.respawn(house.spawn_house[idx] if a.team == trapper_team else house.spawn_garden[idx])
	for p in house.props:
		p.carrier = null
		p.set_hidden(false)
		p.freeze = false
		p.global_transform = p.home
		p.linear_velocity = Vector3.ZERO
		p.angular_velocity = Vector3.ZERO
		p.chain_id = -1
	_assign_perks()
	_prop_of_kind("pizza").set_hidden(true)
	for k in Config.POWERUPS:
		_prop_of_kind(k).set_hidden(true)
	_powerup_at = 0.0
	for s in bots:
		bots[s].on_round_start()
	_set_phase("intro", Config.intro_time)


@rpc("authority", "reliable")
func s_round_reset(i: int, ttm: int, picked: Array, mod: String) -> void:
	cat_zoom_until = 0.0
	twitch_at = 0.0
	_event = ""
	modifier = mod if mod in Config.MODIFIERS else ""
	rush = false
	reveal_until = 0.0
	_reveal_local_ready = 0.0
	if _sun:
		var dark := modifier == "blackout"
		_sun.light_energy = 0.05 if dark else 1.25
		_env.ambient_light_energy = 0.08 if dark else 1.0
		_env.background_mode = Environment.BG_COLOR if dark else Environment.BG_SKY
		_env.background_color = Color("10142a")
	round_i = i
	trapper_team = ttm
	replaying = false
	Sfx.pitch_scale = 1.0
	tasks = []
	for k in picked:
		tasks.append({"id": k, "step": 0, "done": false})
	budget = [Config.BUDGET, Config.BUDGET]
	for id in pranks.keys():
		var p: Prank = pranks[id]
		for m in p.marbles:
			entities.erase(m.net_id)
			m.queue_free()
		if p.vac:
			entities.erase(p.vac.net_id)
			p.vac.queue_free()
		p.queue_free()
	pranks.clear()
	for c in house.cupboards:
		house.cupboards[c].prank = null
	timeline.clear()
	_last_sent.clear()
	render_t = 0.0


func _pick_tasks() -> Array:
	var keys := house.task_ids().filter(func(k): return not k in Config.EVENT_TASKS)
	for k in range(keys.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var tmp = keys[k]
		keys[k] = keys[j]
		keys[j] = tmp
	return keys.slice(0, Config.tasks_per_round())


func _sync_tasks_new() -> void:
	tasks = []
	for k in _pick_tasks():
		tasks.append({"id": k, "step": 0, "done": false})
	for p in house.props:
		if p.hidden_prop and p.kind in ["trash_bag", "laundry"]:
			p.set_hidden(false)
			p.global_transform = p.home
	_sync_state()


func _host_start_sandbox() -> void:
	trapper_team = 0
	var picked := _pick_tasks()
	s_round_reset(0, 0, picked, "")
	for s in avatars:
		var a: Avatar = avatars[s]
		a.respawn(house.spawn_house[s % 8] if a.team == 0 else house.spawn_garden[s % 8])
	budget = [999, 999]
	_set_phase("sandbox", 1.0e9)


func _sandbox_action(kind: String) -> void:
	match kind:
		"remote_all":
			for p in remote_pranks(0) + remote_pranks(1):
				p.fire(null)
		"rearm", "clear":
			var saved := _sandbox_log.duplicate()
			if Net.mode == "host":
				s_round_reset.rpc(0, 0, tasks.map(func(t): return t["id"]), "")
			s_round_reset(0, 0, tasks.map(func(t): return t["id"]), "")
			_sandbox_log.clear()
			budget = [999, 999]
			for s in avatars:
				avatars[s].mess = 0.0
			for p in house.props:
				p.carrier = null
				p.set_hidden(false)
				p.freeze = false
				p.global_transform = p.home
				p.linear_velocity = Vector3.ZERO
			if kind == "rearm":
				for e in saved:
					var pid := _next_prank_id
					_next_prank_id += 1
					if Net.mode == "host":
						s_spawn_prank.rpc(pid, e[0], e[1], e[2], e[3], e[4])
					s_spawn_prank(pid, e[0], e[1], e[2], e[3], e[4])
					pranks[pid].arm()
					_sandbox_log.append(e)
			fx_all("sfx", ["disarm", Vector3.ZERO])
	_sync_state()


func _set_phase(p: String, dur: float) -> void:
	_phase_end = Config.now + dur
	if Net.mode == "host":
		s_phase.rpc(p, dur)
	s_phase(p, dur)
	_sync_state()


@rpc("authority", "reliable")
func s_phase(p: String, dur: float) -> void:
	var prev := phase
	phase = p
	phase_dur = dur
	phase_end_local = _clock + dur
	var front: HouseDoor = house.doors["front"]
	front.locked = p in ["intro", "setup"] and not chaos
	house.set_front_locked(front.locked)
	if p == "chaos":
		Sfx.play("go")
	if p == "run":
		# replays only show the chores: start recording fresh so long setups can't push run frames out
		timeline.clear()
		_last_sent.clear()
		Sfx.play("go")
		if cam:
			cam.spectate_idx = 1
	if p == "setup" and prev != "setup":
		Sfx.play("tick")
	if hud:
		hud.on_phase(p)


func _host_phase_tick() -> void:
	var now := Config.now
	match phase:
		"chaos":
			_chaos_tick(now)
		"sandbox":
			var done_all := tasks.size() > 0
			for t in tasks:
				if not t["done"]:
					done_all = false
			if done_all:
				_sync_tasks_new()
			return
		"run":
			var all_done := tasks.size() > 0
			for t in tasks:
				if not t["done"]:
					all_done = false
			if all_done and now < _phase_end - 1.0:
				_phase_end = now + 1.0
			elif not rush and _phase_end - now <= minf(Config.RUSH_TIME, Config.run_time * 0.25) and _phase_end - now > 3.0:
				scoring.mult *= 2
				fx_all("rush", [])
			if _event != "" and now >= _event_at:
				_start_event(_event)
				_event = ""
			if cat_zoom_until > now:
				_cat_tick()
			_powerup_tick(now)
			_twitch_tick(now)
			if modifier == "quake" and now >= _quake_at:
				_quake_at = now + rng.randf_range(14.0, 22.0)
				if now - _run_start > 8.0:
					_quake()
	if now < _phase_end:
		return
	match phase:
		"intro":
			if chaos:
				_start_chaos()
			else:
				for s in bots:
					bots[s].on_setup()
				_set_phase("setup", Config.setup_time * Config.time_scale())
		"chaos":
			_end_chaos()
		"setup":
			_start_run()
		"run":
			_end_run()
		"replay":
			_end_replay_host()
			_set_phase("score", Config.score_time)
		"score":
			if round_i + 1 < Config.rounds:
				_host_start_round(round_i + 1)
			else:
				var aw := compute_awards()
				if Net.mode == "host":
					s_awards.rpc(aw)
				s_awards(aw)
				_set_phase("end", 9999.0)
				fx_all("sfx", ["win", Vector3.ZERO])


func _start_run() -> void:
	_run_start = Config.now
	_quake_at = Config.now + 12.0
	# one surprise per round (or none): runaway cat or pizza delivery
	var roll := rng.randf()
	_event = "cat" if roll < 0.4 else ("pizza" if roll < 0.75 else "")
	_event_at = Config.now + Config.run_time * rng.randf_range(0.3, 0.55)
	for id in pranks:
		pranks[id].arm()
	for s in avatars:
		var a: Avatar = avatars[s]
		if a.team == trapper_team:
			a.park()
	_set_phase("run", Config.run_time * Config.time_scale())


func _end_run() -> void:
	for id in pranks:
		pranks[id].armed = false
	var mess := []
	for a in runner_avatars():
		mess.append(a.mess)
	var mp := scoring.mess_points(trapper_team, mess, Config.now)
	if mp > 0:
		feed_all("feed_mess", [mp], trapper_team)
	_end_run_replay()


func _end_run_replay() -> void:
	_sync_state()
	var best := scoring.best_chain()
	if best.is_empty() or timeline.frames.size() < 4:
		_set_phase("score", Config.score_time)
		return
	var t0: float = maxf(float(best["t0"]) - 2.0, timeline.first_t())
	var t1: float = minf(float(best["t1"]) + 2.5, timeline.latest_t())
	var speed := clampf((t1 - t0) / Config.replay_time, 0.4, 2.0)
	var vict: Array = _chain_victims.get(best["id"], [])
	var focus: int = vict[0] if vict.size() > 0 else -1
	var title := "%s  x%d  +%d" % [I18n.t("best_prank"), best["links"].size(), best["points"]]
	if Net.mode == "host":
		s_replay.rpc(t0, t1, speed, focus, best["links"].size(), int(best["points"]))
	s_replay(t0, t1, speed, focus, best["links"].size(), int(best["points"]))
	_set_phase("replay", (t1 - t0) / speed + 0.6)


# ------------------------------------------------------------------ replay (all peers)

@rpc("authority", "reliable")
func s_replay(t0: float, t1: float, speed: float, focus: int, links: int, pts: int) -> void:
	replaying = true
	replay = {"t0": t0, "t1": t1, "speed": speed, "focus": focus, "t": t0, "links": links, "pts": pts}
	timeline.rewind()
	if Net.is_host():
		for id in entities:
			var e = entities[id]
			if e is RigidBody3D:
				e.freeze = true
	for id in pranks:
		pranks[id].reset_visual()
	Sfx.pitch_scale = 0.7
	if hud:
		hud.on_replay(true, links, pts)


func _replay_step(delta: float) -> void:
	var prev: float = replay["t"]
	replay["t"] = minf(prev + delta * float(replay["speed"]), float(replay["t1"]))
	_apply_sample(timeline.sample(replay["t"]))
	for ev in timeline.events_between(prev, replay["t"]):
		_apply_fx(ev["kind"], ev["args"], true)


func _end_replay_host() -> void:
	if Net.mode == "host":
		s_end_replay.rpc()
	s_end_replay()


@rpc("authority", "reliable")
func s_end_replay() -> void:
	replaying = false
	Sfx.pitch_scale = 1.0
	if hud:
		hud.on_replay(false, 0, 0)


# ------------------------------------------------------------------ netcode

func _ent_state(e: Node3D) -> float:
	if e is Avatar:
		return float((e as Avatar).net_flags())
	if e is Prop:
		return (e as Prop).net_state()
	return 0.0


func _send_snapshot() -> void:
	_tick += 1
	var d := PackedFloat32Array()
	for id in entities:
		var e: Node3D = entities[id]
		if not is_instance_valid(e):
			continue
		var p := e.global_position
		var q := e.global_transform.basis.get_rotation_quaternion()
		var st := _ent_state(e)
		var last = _last_sent.get(id)
		var force: bool = (_tick + int(id)) % 20 == 0
		if not force and last != null and last[0].distance_squared_to(p) < 0.000004 \
				and absf(last[1].dot(q)) > 0.99999 and last[2] == st:
			continue
		_last_sent[id] = [p, q, st]
		d.append_array([id, p.x, p.y, p.z, q.x, q.y, q.z, q.w, st])
	timeline.push(Config.now, d)
	if Net.mode == "host":
		s_snapshot.rpc(Config.now, d)


@rpc("authority", "unreliable_ordered")
func s_snapshot(t: float, d: PackedFloat32Array) -> void:
	timeline.push(t, d)


func _client_interpolate(delta: float) -> void:
	if timeline.frames.is_empty():
		return
	var target := timeline.latest_t() - Config.INTERP_DELAY
	render_t += delta
	if absf(render_t - target) > 0.3:
		render_t = target
	else:
		render_t = lerpf(render_t, target, 0.1)
	_apply_sample(timeline.sample(render_t))
	# own bean: much fresher sample (one net tick behind the newest) so controls feel snappier
	var me := local_avatar()
	if me:
		var s := timeline.sample_one(me.slot, timeline.latest_t() - 1.0 / Config.NET_RATE)
		if not s.is_empty():
			me.global_transform = Transform3D(Basis(s[1]), s[0])
			me.flags = int(s[2])


func _apply_sample(s: Dictionary) -> void:
	for id in s:
		var e = entities.get(id)
		if e == null or not is_instance_valid(e):
			continue
		var v: Array = s[id]
		e.global_transform = Transform3D(Basis(v[1]), v[0])
		if e is Avatar:
			e.flags = int(v[2])
		elif e is Prop:
			e.visible = (int(v[2]) & 1) == 0


## Host: broadcast an effect (and record it for replays).
func fx_all(kind: String, args: Array) -> void:
	if not Net.is_host():
		return
	if Net.mode == "host":
		s_fx.rpc(Config.now, kind, args)
	s_fx(Config.now, kind, args)


@rpc("authority", "reliable")
func s_fx(t: float, kind: String, args: Array) -> void:
	if not replaying:
		timeline.add_event(t, kind, args)
	_apply_fx(kind, args, false)


func _apply_fx(kind: String, args: Array, in_replay: bool) -> void:
	match kind:
		"yell":
			var a: Avatar = avatars.get(int(args[0]))
			if a:
				Sfx.play("yell", a.global_position, -4.0, 0.85 + (a.slot % 4) * 0.12)
				Sfx.play("grunt", a.global_position, 0.0, 0.9 + (a.slot % 4) * 0.1)
				if not headless:
					Fx.burst(self, a.global_position, "dust")
		"sfx":
			Sfx.play(str(args[0]), args[1])
		"burst":
			if not headless:
				Fx.burst(self, args[0], str(args[1]), args[2])
		"prank":
			var p: Prank = pranks.get(int(args[0]))
			if p == null:
				return
			match str(args[1]):
				"trigger":
					p.used = p.used or p.type != "oil"
					p.play_trigger()
					if not headless:
						_prank_particles(p)
					if not in_replay and cam:
						cam.shake(0.6)
				"ring_on":
					p.ringing = true
					Sfx.play("alarm", p.global_position, 4.0)
					if hud and not in_replay:
						hud.toast(I18n.t("alarm_ring"))
				"ring_off":
					p.ringing = false
				"master":
					p.masterful = true
				"disarmed":
					p.disarmed = true
					p.ringing = false
					Sfx.play("disarm", p.global_position)
		"mess":
			if in_replay:
				return
			var a2: Avatar = avatars.get(int(args[0]))
			if a2:
				a2.add_mess(float(args[1]), args[2], str(args[3]))
		"blind":
			if not in_replay and int(args[0]) == local_slot() and hud:
				hud.blind(str(args[1]), float(args[2]))
		"splats":
			if in_replay or headless:
				return
			var c: Vector3 = args[0]
			for i in 9:
				var o := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * float(args[2])
				Fx.splat(_splat_root, c + o, args[1], randf_range(0.15, 0.45))
			while _splat_root.get_child_count() > 160:
				_splat_root.get_child(0).free()
		"taunt":
			var ta: Avatar = avatars.get(int(args[0]))
			if ta:
				ta.taunt_until = Time.get_ticks_msec() * 0.001 + 1.3
				Sfx.play("go", ta.global_position, -4.0, 1.3 + (ta.slot % 3) * 0.15)
		"rush":
			rush = true
			if not in_replay:
				Sfx.play("alarm", null, 0.0, 0.8)
				if hud:
					hud.popup(I18n.t("rush"), Color("ff4d6d"))
				if cam:
					cam.shake(0.8)
		"event":
			if not in_replay and hud:
				hud.popup(I18n.t("ev_" + str(args[0])), Color("ffd166"))
				Sfx.play("meow" if args[0] == "cat" else "doorbell", null, 2.0)
		"quake":
			if not in_replay:
				Sfx.play("thud", null, 4.0, 0.5)
				Sfx.play("thud", null, 4.0, 0.4)
				if hud:
					hud.toast(I18n.t("quake"))
			if cam:
				cam.shake(2.0)
		"task_fx":
			if in_replay or headless:
				return
			_task_fx(str(args[0]), args[1])
		"cup_open":
			var cup: Cupboard = house.cupboards.get(str(args[0]))
			if cup:
				cup.open()
				Sfx.play("door", cup.global_position, -3.0)


func _prank_particles(p: Prank) -> void:
	var at := p.global_position
	match p.type:
		"bucket":
			Fx.burst(self, at, "water")
		"paint", "fake_remote":
			Fx.burst(self, at + Vector3(0, 0.3, 0), "paint", p.team_color())
		"flour":
			Fx.burst(self, Vector3(at.x, 1.0, at.z), "flour")
			Sfx.play("flour", at)
		"confetti":
			Fx.burst(self, at + Vector3(0, 0.4, 0), "confetti")
		"whoopee":
			Fx.burst(self, at + Vector3(0, 0.3, 0), "fart")
		"cake":
			Fx.burst(self, at + Vector3(0, 0.3, 0), "paint", Color("ffc2d4"))
		_:
			Fx.burst(self, at + Vector3(0, 0.2, 0), "dust")


## Host: feed line for everyone. Args starting with "@" are translated on each client.
func feed_all(key: String, args: Array, team: int, big := false) -> void:
	if key == "chain" and Net.is_host():
		for s in avatars:
			if avatars[s].team == team:
				if int(args[0]) == 2:
					achieve(s, "+chains")
				if int(args[0]) >= 3:
					achieve(s, "CHAIN_3")
				if int(args[0]) >= 5:
					achieve(s, "CHAIN_5")
	if Net.mode == "host":
		s_feed.rpc(key, args, team, big)
	s_feed(key, args, team, big)


@rpc("authority", "reliable")
func s_feed(key: String, args: Array, team: int, big: bool) -> void:
	var a2 := []
	for x in args:
		if x is String and x.begins_with("@"):
			a2.append(I18n.t(x.substr(1)))
		else:
			a2.append(x)
	var text := I18n.t(key, a2)
	if hud:
		if big:
			# chain announcer: the bigger the chain, the louder the title
			if key == "chain" and a2.size() > 0:
				var n: int = int(a2[0])
				text = I18n.t("ann_%d" % clampi(n, 2, 5)) + "\n" + text
				if cam:
					cam.shake(0.4 + 0.3 * n)
				Sfx.play("win" if n >= 4 else "chain", null, 0.0, 1.0 + 0.1 * n)
			else:
				Sfx.play("chain")
			hud.popup(text, Config.TEAM_COLORS[team])
		else:
			hud.feed(text, Config.TEAM_COLORS[team])


func _sync_state() -> void:
	if not Net.is_host():
		return
	scores = scoring.totals.duplicate()
	round_scores = scoring.round_pts.duplicate()
	if Net.mode == "host":
		s_state.rpc(scores, round_scores, budget, tasks)


@rpc("authority", "reliable")
func s_state(sc: Array, rs: Array, b: Array, t: Array) -> void:
	scores = sc
	round_scores = rs
	budget = b
	tasks = t


# ------------------------------------------------------------------ ghost preview

func _build_ghost() -> void:
	_ghost = Node3D.new()
	add_child(_ghost)
	_ghost_ring = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.45
	cm.bottom_radius = 0.45
	cm.height = 0.04
	_ghost_ring.mesh = cm
	_ghost.add_child(_ghost_ring)
	_ghost_label = U.label3d("", 36, Color.WHITE, Vector3(0, 0.6, 0), _ghost)
	_ghost.visible = false


## Mouse users place where they point (within reach); keyboard/gamepad users place in front of the bean.
func local_placement(type: String) -> Dictionary:
	var me := local_avatar()
	var fwd := -me.global_transform.basis.z
	if _mouse_mode and cam and not headless:
		var mp := get_viewport().get_mouse_position()
		var from := cam.project_ray_origin(mp)
		var dir := cam.project_ray_normal(mp)
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * 60.0, U.L_WORLD)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			var p: Vector3 = hit["position"]
			var to := U.flat_xz(p - me.global_position)
			if to.length() > 5.5:
				to = to.normalized() * 5.5
			if to.length() > 0.2:
				fwd = to.normalized()
			var origin := me.global_position + to - fwd * (0.6 if Config.PRANKS[type]["place"] == "ceiling" else 1.0)
			return placement_for(type, origin, fwd)
	return placement_for(type, me.global_position, fwd)


var _ghost_local_ready := 0.0


## Client-side estimate of the haunt cooldown (host is authoritative).
func ghost_wait_local() -> float:
	if Net.is_host():
		return ghost_wait(local_slot())
	var me := local_avatar()
	var k := 0.5 if me and me.perk == "haunter" else 1.0
	var start := phase_end_local - phase_dur + Config.GHOST_DELAY * k
	return maxf(0.0, maxf(start, _ghost_local_ready) - _clock)


## Where a watching trapper is pointing: mouse on the floor, or the camera focus.
func _ghost_point() -> Vector3:
	if _mouse_mode and cam and not headless:
		var mp := get_viewport().get_mouse_position()
		var from := cam.project_ray_origin(mp)
		var dir := cam.project_ray_normal(mp)
		if absf(dir.y) > 0.01:
			var t := -from.y / dir.y
			if t > 0.0:
				return from + dir * t
	return cam.focus if cam else Vector3.ZERO


func _input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		_mouse_mode = true
	elif e is InputEventJoypadButton or (e is InputEventJoypadMotion and absf(e.axis_value) > 0.5):
		_mouse_mode = false


func _update_ghost() -> void:
	var me := local_avatar()
	if me == null or not building() or not local_is_trapper() or not me.visible:
		_ghost.visible = false
		return
	var type: String = Config.enabled_pranks()[selected]
	var pl := local_placement(type)
	_ghost.visible = true
	_ghost.global_position = pl["pos"] + Vector3(0, 0.03, 0)
	var ok: bool = pl["ok"] and budget[local_team()] >= int(Config.PRANKS[type]["cost"])
	_ghost_ring.material_override = U.mat(Color(0.2, 1.0, 0.4, 0.5) if ok else Color(1.0, 0.25, 0.2, 0.5), 0.5, 0.0, true)
	_ghost_label.text = "%s (%d)" % [I18n.t("p_" + type), Config.PRANKS[type]["cost"]]


# ------------------------------------------------------------------ bot helpers

func bot_targets() -> Array:
	return _task_targets()


## Random affordable prank plan for a trapper team. Each entry: {"type", "pos", "yaw", "socket", "stand"}.
func bot_make_plan(team: int, max_cost: int) -> Array:
	var plan := []
	var left := max_cost
	var types := Config.enabled_pranks()
	var targets := _task_targets()
	var tries := 0
	var used_sockets := {}
	while left > 0 and tries < 60:
		tries += 1
		var t: String = types[rng.randi() % types.size()]
		var def: Dictionary = Config.PRANKS[t]
		if int(def["cost"]) > left:
			continue
		var e := {}
		match def["place"]:
			"floor", "surface", "ceiling":
				var anchor: Vector3
				if rng.randf() < 0.6 and targets.size() > 0:
					anchor = targets[rng.randi() % targets.size()]["pos"]
				else:
					var dn: Array = house.doors.keys()
					var d: HouseDoor = house.doors[dn[rng.randi() % dn.size()]]
					anchor = d.global_position + (Vector3(0, 0, 1) if d.horizontal else Vector3(1, 0, 0)) * (1.0 if rng.randf() < 0.5 else -1.0)
				var p := U.flat_xz(anchor) + Vector3(rng.randf_range(-0.9, 0.9), 0, rng.randf_range(-0.9, 0.9))
				var stand := p + Vector3(0, 0, 1.0)
				var pl := placement_for(t, stand, Vector3.FORWARD)
				if not pl["ok"]:
					continue
				var clash := false
				for o in plan:
					if o["pos"].distance_to(pl["pos"]) < 0.9:
						clash = true
				if clash:
					continue
				e = {"type": t, "pos": pl["pos"], "yaw": pl["yaw"], "socket": "", "stand": stand}
			"door":
				var order: Array = ["front"] + house.doors.keys().filter(func(n): return n != "front")
				for n in order:
					if not used_sockets.has(n) and not _socket_used(n) and rng.randf() < 0.6:
						var d2: HouseDoor = house.doors[n]
						var off := Vector3(0, 0, -0.9) if d2.horizontal else Vector3(0.9, 0, 0)
						e = {"type": t, "pos": d2.bucket_slot.global_position, "yaw": d2.rotation.y, "socket": n, "stand": d2.global_position + off}
						break
			"container":
				var names := []
				for tg in targets:
					if tg["type"] == "open":
						names.append(tg["at"])
				if names.is_empty() or rng.randf() < 0.3:
					names = house.cupboards.keys()
				var n2: String = names[rng.randi() % names.size()]
				if not used_sockets.has(n2) and not _socket_used(n2):
					var c: Cupboard = house.cupboards[n2]
					e = {"type": t, "pos": c.inside_point(), "yaw": c.rotation.y, "socket": n2, "stand": c.front_point()}
			"task":
				var holds := []
				for tg in targets:
					if tg["type"] == "hold":
						holds.append(tg["at"])
				if holds.size() > 0:
					var n3: String = holds[rng.randi() % holds.size()]
					if not used_sockets.has(n3) and not _socket_used(n3):
						var sp: Dictionary = house.spots[n3]
						e = {"type": t, "pos": sp["pos"] + Vector3(0, 0.05, 0), "yaw": 0.0, "socket": n3, "stand": sp["pos"]}
		if e.is_empty():
			continue
		if e["socket"] != "":
			used_sockets[e["socket"]] = true
		plan.append(e)
		left -= int(def["cost"])
	return plan


# ------------------------------------------------------------------ ghosts (trappers during chores)

var _ghost_ready := {}
var _run_start := 0.0  # slot -> Config.now when the next haunt is allowed


## How many seconds until this trapper can haunt again (0 = ready). Host-side truth.
func ghost_wait(slot: int) -> float:
	var a: Avatar = avatars.get(slot)
	var haunter: bool = a != null and a.perk == "haunter"
	var start: float = _run_start + Config.GHOST_DELAY * (0.5 if haunter else 1.0)
	return maxf(0.0, maxf(start, float(_ghost_ready.get(slot, 0.0))) - Config.now)


## A parked trapper flings the nearest object at the nearest runner (or spooks a runner if nothing is near).
func ghost_action(slot: int, point: Vector3) -> bool:
	var a: Avatar = avatars.get(slot)
	if a == null or a.active or a.team != trapper_team or phase != "run" or not point.is_finite():
		return false
	if ghost_wait(slot) > 0.0:
		return false
	point.y = 0.0
	var best: Prop = null
	var bd := 3.5
	for p in house.props:
		if p.hidden_prop or p.carrier or p.freeze:
			continue
		var d := U.dist_xz(p.global_position, point)
		if d < bd:
			bd = d
			best = p
	var origin := best.global_position if best else point
	var target: Avatar = null
	var td := 8.0 if best else 3.0
	for r in runner_avatars():
		if not r.active:
			continue
		var d2 := U.dist_xz(r.global_position, origin)
		if d2 < td:
			td = d2
			target = r
	if target == null:
		_toast_to(a, "ghost_none")
		return false
	_ghost_ready[slot] = Config.now + Config.GHOST_COOLDOWN * (0.5 if a.perk == "haunter" else 1.0)
	if best:
		var dir := U.flat_xz(target.global_position - best.global_position).normalized()
		best.linear_velocity = dir * 11.0 + Vector3.UP * 3.5
		best.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		best.ghost_until = Config.now + 2.0
		best.ghost_team = a.team
		best.ghost_slot = slot
		fx_all("burst", [best.global_position, "ghost", Color("b98cff")])
	else:
		var ch: int = _ghost_hit(a.team, target, slot)
		target.panic(1.0, ch)
		fx_all("burst", [target.global_position + Vector3(0, 1, 0), "ghost", Color("b98cff")])
	fx_all("sfx", ["whoosh", origin])
	return true


func _ghost_hit(team: int, victim: Avatar, ghost_slot := -1) -> int:
	if _absorbed(victim):
		return -1
	var r := scoring.prank_hit(victim.chain_id if victim.is_chained() else -1, team, "ghost", victim.pname, Config.now)
	stat(ghost_slot, "ghost", 1)
	_chain_victims.get_or_add(r["chain"], []).append(victim.slot)
	victim.set_chain(r["chain"], Config.now + 2.5)
	feed_all("feed_prank", ["@p_ghost", victim.pname, r["delta"]], team)
	if r["links"] >= 2:
		feed_all("chain", [r["links"], Scoring.chain_value(r["links"])], team, true)
	_sync_state()
	return r["chain"]


# ------------------------------------------------------------------ rules, sniffing, stats

## Host: the house shakes. Loose objects jump, some runners lose their footing.
func _quake() -> void:
	for p in house.props:
		if p.hidden_prop or p.carrier or p.freeze:
			continue
		p.linear_velocity += Vector3(rng.randf_range(-3, 3), rng.randf_range(2.0, 4.0), rng.randf_range(-3, 3))
	for a in runner_avatars():
		if a.active and a.can_act() and rng.randf() < 0.4:
			a.knock(Vector3(rng.randf_range(-3, 3), 3.0, rng.randf_range(-3, 3)), Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6)), 1.2)
	fx_all("quake", [])


@rpc("authority", "reliable")
func s_reveal(pos: Vector3) -> void:
	reveal_pos = pos
	reveal_until = _clock + 3.5


func reveal_wait_local() -> float:
	return maxf(0.0, _reveal_local_ready - _clock)


## Is a prank at `p` currently sniffed out by the local runner?
func sniffed(p: Vector3) -> bool:
	return _clock < reveal_until and U.dist_xz(p, reveal_pos) <= Config.REVEAL_RADIUS


func stat(slot: int, key: String, v: float) -> void:
	if not Net.is_host() or not live():
		return
	var d: Dictionary = _stats.get_or_add(slot, {})
	d[key] = float(d.get(key, 0.0)) + v
	match key:
		"trap":
			if v > 0:
				achieve(slot, "FIRST_PRANK")
				achieve(slot, "+hits")
		"ghost":
			achieve(slot, "GHOSTLY")
			achieve(slot, "+ghosts")
		"disarms", "tasks":
			achieve(slot, "+" + key)


## End-of-match awards: the top player in each funny category.
func compute_awards() -> Array:
	var out := []
	for key in ["falls", "mess", "trap", "ghost", "tasks", "disarms"]:
		var best := -1
		var bv := 0.0
		for slot in _stats:
			var v: float = _stats[slot].get(key, 0.0)
			if v > bv:
				bv = v
				best = slot
		if best >= 0 and avatars.has(best):
			out.append([key, avatars[best].pname, int(round(bv))])
	return out


@rpc("authority", "reliable")
func s_awards(list: Array) -> void:
	awards = list
	if hud:
		hud.show_awards(list)


# ------------------------------------------------------------------ round events (host)

func _start_event(kind: String) -> void:
	match kind:
		"cat":
			cat_zoom_until = Config.now + 18.0
			fx_all("event", ["cat"])
		"pizza":
			var pz := _prop_of_kind("pizza")
			pz.global_transform = pz.home
			pz.linear_velocity = Vector3.ZERO
			pz.set_hidden(false)
			tasks.append({"id": "pizza", "step": 0, "done": false})
			fx_all("event", ["pizza"])
			_sync_state()


## Zoomies: the cat sprints in random directions and sets off traps it runs over.
func _cat_tick() -> void:
	var cat := _prop_of_kind("cat")
	var now := Config.now
	var hv := Vector3(cat.linear_velocity.x, 0, cat.linear_velocity.z)
	if now > _cat_turn_at or hv.length() < 0.5:
		_cat_turn_at = now + rng.randf_range(0.6, 1.4)
		var a := rng.randf() * TAU
		_cat_dir = Vector3(cos(a), 0, sin(a))
	cat.linear_velocity = Vector3(_cat_dir.x * 4.5, cat.linear_velocity.y, _cat_dir.z * 4.5)
	cat.rotation.y = atan2(-_cat_dir.x, -_cat_dir.z)
	if rng.randf() < 0.01:
		fx_all("sfx", ["meow", cat.global_position])


## The cat ran over a floor trap: whoever is standing close gets it, otherwise the trap is wasted.
func cat_trigger(p: Prank) -> void:
	var vs := avatars_near(p.global_position, 1.6, true)
	if vs.size() > 0:
		p.fire(vs[0])
		return
	p.used = true
	fx_all("prank", [p.id, "trigger"])
	feed_all("feed_cat_wasted", ["@p_" + p.type], p.team)


func _catch_cat(a: Avatar) -> void:
	if cat_zoom_until <= Config.now:
		return
	cat_zoom_until = 0.0
	var cat := _prop_of_kind("cat")
	cat.linear_velocity = Vector3.ZERO
	scoring.bonus(a.team, Config.CAT_BONUS * scoring.mult, "cat", Config.now)
	achieve(a.slot, "CAT_HERDER")
	achieve(a.slot, "+cats")
	feed_all("feed_cat_caught", [a.pname, Config.CAT_BONUS * scoring.mult], a.team)
	fx_all("sfx", ["meow", cat.global_position])
	_sync_state()


# ------------------------------------------------------------------ chaos mode (no turns: everyone traps and runs)

var _budget_tick := 0.0


func _start_chaos() -> void:
	_run_start = Config.now
	_quake_at = Config.now + 12.0
	budget = [Config.CHAOS_START_BUDGET, Config.CHAOS_START_BUDGET]
	_apply_budget_perks()
	timeline.clear()
	var roll := rng.randf()
	_event = "cat" if roll < 0.45 else ("pizza" if roll < 0.9 else "")
	_event_at = Config.now + Config.chaos_time() * rng.randf_range(0.3, 0.6)
	_set_phase("chaos", Config.chaos_time())


func _chaos_tick(now: float) -> void:
	if now >= _budget_tick:
		_budget_tick = now + Config.CHAOS_BUDGET_EVERY
		for t in 2:
			budget[t] = mini(budget[t] + 1, Config.BUDGET)
		_sync_state()
	var done_all := tasks.size() > 0
	for t in tasks:
		if not t["done"]:
			done_all = false
	if done_all:
		_sync_tasks_new()
	if modifier == "quake" and now >= _quake_at:
		_quake_at = now + rng.randf_range(14.0, 22.0)
		_quake()
	if _event != "" and now >= _event_at:
		_start_event(_event)
		_event = ""
	if cat_zoom_until > now:
		_cat_tick()
	_powerup_tick(now)
	_twitch_tick(now)
	if not rush and _phase_end - now <= minf(Config.RUSH_TIME, Config.chaos_time() * 0.25) and _phase_end - now > 3.0:
		scoring.mult *= 2
		fx_all("rush", [])


## Chaos ends: each team scores the mess on the other team, then replay + final scores.
func _end_chaos() -> void:
	for id in pranks:
		pranks[id].armed = false
	for t in 2:
		var mess := []
		for s in avatars:
			if avatars[s].team != t:
				mess.append(avatars[s].mess)
		var mp := scoring.mess_points(t, mess, Config.now)
		if mp > 0:
			feed_all("feed_mess", [mp], t)
	_end_run_replay()


# ------------------------------------------------------------------ power-ups (host)

## Every ~30 s a random power-up appears in a random room (one of each kind at most).
func _powerup_tick(now: float) -> void:
	if _powerup_at == 0.0:
		_powerup_at = now + rng.randf_range(15.0, 25.0)
	if now < _powerup_at:
		return
	_powerup_at = now + rng.randf_range(25.0, 35.0)
	var kind: String = Config.POWERUPS[rng.randi() % Config.POWERUPS.size()]
	var pu := _prop_of_kind(kind)
	if not pu.hidden_prop:
		return
	var rooms: Array = house.rooms.keys().filter(func(r): return r != "garden")
	var c: Vector3 = house._nav_centers[rooms[rng.randi() % rooms.size()]]
	pu.global_transform = Transform3D(Basis.IDENTITY, c + Vector3(rng.randf_range(-0.6, 0.6), 0.4, rng.randf_range(-0.6, 0.6)))
	pu.linear_velocity = Vector3.ZERO
	pu.set_hidden(false)
	fx_all("burst", [pu.global_position, "sparkle", Color.WHITE])
	fx_all("sfx", ["ding_pu", pu.global_position])


func _take_powerup(a: Avatar, pu: Prop) -> void:
	if pu.hidden_prop:
		return
	pu.set_hidden(true)
	match pu.kind:
		"umbrella":
			a.shield_until = Config.now + 25.0
		"coffee":
			a.fast_until = Config.now + 10.0
	feed_all("feed_powerup", [a.pname, "@pu_" + pu.kind], a.team)
	fx_all("sfx", ["task", a.global_position])


## Small visual payoff when a hold-chore finishes (water, a sandwich appears, papers fly...).
func _task_fx(at: String, pos: Vector3) -> void:
	match at:
		"shower", "plant_a", "plant_b", "aquarium":
			Fx.burst(self, pos + Vector3(0, 1.4 if at == "shower" else 0.9, 0), "water")
			Sfx.play("splash", pos, -8.0, 1.4)
		"counter":
			var sw := Node3D.new()
			sw.position = pos + Vector3(randf_range(-0.3, 0.3), 0.05, -0.35)
			_splat_root.add_child(sw)
			U.box(Vector3(0.24, 0.05, 0.2), Color("f5c26b"), Vector3.ZERO, sw)
			U.box(Vector3(0.25, 0.03, 0.21), Color("7cb342"), Vector3(0, 0.04, 0), sw)
			U.box(Vector3(0.24, 0.05, 0.2), Color("f5c26b"), Vector3(0, 0.08, 0), sw)
		"coffee_machine":
			U.cyl(0.06, 0.1, Color.WHITE, pos + Vector3(randf_range(-0.2, 0.2), 0.08, -0.2), _splat_root)
			Fx.burst(self, pos + Vector3(0, 0.4, -0.3), "flour")
		"copier", "whiteboard", "boss_desk":
			Fx.burst(self, pos + Vector3(0, 1.0, 0), "confetti")
		"bed":
			Fx.burst(self, pos + Vector3(0, 0.6, 0), "flour")
		_:
			Fx.burst(self, pos + Vector3(0, 0.8, 0), "sparkle")


# ------------------------------------------------------------------ perks + comeback (host)

func reveal_cooldown(a: Avatar) -> float:
	return Config.REVEAL_COOLDOWN * (0.5 if a and a.perk == "nose" else 1.0)


## Everyone gets one random perk for their role this round; a team far behind gets a boost, the leader a handicap.
func _assign_perks() -> void:
	var perks := {}
	for s in avatars:
		var a: Avatar = avatars[s]
		var pool: Array = Config.RUNNER_PERKS + Config.TRAPPER_PERKS if chaos else (Config.TRAPPER_PERKS if a.team == trapper_team else Config.RUNNER_PERKS)
		a.perk = pool[rng.randi() % pool.size()]
		a.steady = 1 if a.perk == "steady" else 0
		perks[s] = a.perk
	var diff: int = scoring.totals[0] - scoring.totals[1]
	var leader := -1
	if round_i > 0 and absi(diff) >= Config.CATCHUP_DIFF:
		leader = 0 if diff > 0 else 1
	if Net.mode == "host":
		s_perks.rpc(perks, leader)
	s_perks(perks, leader)
	_apply_budget_perks()
	if leader >= 0 and not chaos:
		var trailing := 1 - leader
		if trapper_team == leader:
			budget[leader] = maxi(6, budget[leader] - 3)
		else:
			budget[trailing] += 3
		for s in avatars:
			var av: Avatar = avatars[s]
			if av.team == trailing and av.team != trapper_team:
				av.steady += 1
	_sync_state()


func _apply_budget_perks() -> void:
	for s in avatars:
		var a: Avatar = avatars[s]
		if a.perk == "budget" and (chaos or a.team == trapper_team):
			budget[a.team] += 3


@rpc("authority", "reliable")
func s_perks(perks: Dictionary, leader: int) -> void:
	for s in perks:
		var a: Avatar = avatars.get(int(s))
		if a:
			a.perk = str(perks[s])
	comeback_leader = leader


# ------------------------------------------------------------------ Twitch mode (host only)

var twitch_at := 0.0  # Config.now of the next viewer-vote result


func _twitch_tick(now: float) -> void:
	if not Twitch.active():
		return
	if twitch_at == 0.0:
		twitch_at = now + Config.TWITCH_WINDOW
		Twitch.take_winner()  # votes from before the chores don't count
		return
	if now < twitch_at:
		return
	twitch_at = now + Config.TWITCH_WINDOW
	var win := Twitch.take_winner()
	if not win.is_empty():
		twitch_effect(str(win["effect"]), int(win["votes"]))


## Viewers' pick hits the streamer (the host's own bean) if it's on the floor, otherwise a random runner.
func twitch_effect(eff: String, n: int) -> void:
	var target: Avatar = local_avatar()
	if target == null or not target.active:
		var rs := runner_avatars().filter(func(r): return r.active)
		target = rs[rng.randi() % rs.size()] if rs.size() > 0 else null
	match eff:
		"quake":
			_quake()
		"cat":
			_start_event("cat")
		_:
			if target == null:
				return
			var d := target.move_dir()
			match eff:
				"banana":
					target.knock(d * 6.0 + Vector3.UP * 4.5, d.cross(Vector3.UP) * 12.0, 2.0)
					fx_all("sfx", ["slip", target.global_position])
				"flour":
					target.knock(Vector3.UP * 2.5, Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4)), 1.3)
					add_mess(target, 30.0, Color.WHITE, "flour")
					blind(target, "flour", 2.0)
					fx_all("burst", [target.global_position + Vector3(0, 1, 0), "flour", Color.WHITE])
				"confetti":
					target.knock(Vector3.UP * 3.0, Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6)), 1.2)
					blind(target, "confetti", 2.0)
					fx_all("burst", [target.global_position + Vector3(0, 0.6, 0), "confetti", Color.WHITE])
				"fart":
					target.panic(1.5, -1)
					fx_all("sfx", ["fart", target.global_position])
					fx_all("burst", [target.global_position, "fart", Color.WHITE])
	feed_all("feed_twitch", ["@tw_" + eff, n, target.pname if target else "-"], 1 - (target.team if target else 0), true)


# ------------------------------------------------------------------ achievements (each player's own machine keeps them)

## Host tells a player's machine about an achievement ("+key" = bump a lifetime counter).
func achieve(slot: int, id: String) -> void:
	var a: Avatar = avatars.get(slot)
	if a == null or a.is_bot or sandbox:
		return
	if a.peer_id == Net.my_id():
		s_ach(id)
	elif Net.mode == "host":
		s_ach.rpc_id(a.peer_id, id)


@rpc("authority", "reliable")
func s_ach(id: String) -> void:
	if id.begins_with("+"):
		Config.add_count(id.substr(1))
	else:
		Config.unlock_ach(id)
