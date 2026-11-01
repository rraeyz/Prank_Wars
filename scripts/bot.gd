class_name Bot
extends RefCounted
## Simple host-side AI. Runners walk the waypoint graph to chores (and into traps);
## trappers place a random affordable plan and fire remote pranks when someone is close.

var world: Node
var a: Avatar
var rng := RandomNumberGenerator.new()
var plan: Array = []
var path: Array = []
var goal := Vector3.INF
var goal_key := ""
var _repath_at := 0.0
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _strafe_until := 0.0
var _strafe := Vector3.ZERO
var _disarm_roll := {}
var _avoid_roll := {}
var _remote_at := {}
var _wander_at := 0.0
var _dive_cd := 0.0
var _place_try := 0.0


func _init(w: Node, av: Avatar) -> void:
	world = w
	a = av
	rng.seed = av.slot * 7919 + 13


func on_round_start() -> void:
	plan.clear()
	path.clear()
	goal = Vector3.INF
	goal_key = ""
	_disarm_roll.clear()
	_avoid_roll.clear()
	_remote_at.clear()


func on_setup() -> void:
	if a.team == world.trapper_team:
		# split the budget between bot trappers; humans on the team keep a share too
		var mates := 0
		var bot_mates := 0
		for s in world.avatars:
			var o: Avatar = world.avatars[s]
			if o.team == a.team:
				mates += 1
				if o.is_bot:
					bot_mates += 1
		var share := int(floor(float(Config.BUDGET) / maxf(1.0, float(mates))))
		if bot_mates == mates:
			share = int(floor(float(Config.BUDGET) / maxf(1.0, float(bot_mates))))
		plan = world.bot_make_plan(a.team, share)
		if OS.has_environment("PW_DEBUG"):
			print("bot %s plan %d items share %d" % [a.pname, plan.size(), share])


func tick(delta: float) -> void:
	a.in_interact = false
	a.in_move = Vector2.ZERO
	var now := Config.now
	match world.phase:
		"setup":
			if a.team == world.trapper_team:
				_trapper_setup(now)
			else:
				_warmup(now)
		"run":
			if a.team == world.trapper_team:
				_trapper_run(now)
			else:
				_runner(now, delta)
		"sandbox":
			if a.team != world.trapper_team:
				_runner(now, delta)
		"intro":
			pass
	if not a.can_act():
		return


func _go(target: Vector3, key: String, now: float) -> bool:
	## Steers toward target via the nav graph. Returns true when arrived.
	if key != goal_key or now > _repath_at:
		goal_key = key
		goal = target
		path = world.house.path(a.global_position, target)
		_repath_at = now + 2.0
	if path.is_empty():
		return true
	var wp: Vector3 = path[0]
	var to := U.flat_xz(wp - a.global_position)
	var arrive := 0.55 if path.size() > 1 else 0.35
	if to.length() < arrive:
		path.pop_front()
		return path.is_empty()
	var dir := to.normalized()
	if world.phase == "run" and a.team != world.trapper_team:
		dir = _avoid_traps(dir)
	# unstick
	if now < _strafe_until:
		dir = (dir + _strafe).normalized()
	_stuck_t += 1.0 / 60.0
	if _stuck_t > 0.8:
		if a.global_position.distance_to(_last_pos) < 0.25:
			a.jump()
			_strafe = Vector3(-dir.z, 0, dir.x) * (1.0 if rng.randf() < 0.5 else -1.0)
			_strafe_until = now + 0.6
			_repath_at = 0.0
		_last_pos = a.global_position
		_stuck_t = 0.0
	a.in_move = Vector2(dir.x, dir.z)
	return false


## Runner bots notice some visible floor traps right in front of them and sidestep (others they walk right into).
func _avoid_traps(dir: Vector3) -> Vector3:
	var pos := a.global_position
	for id in world.pranks:
		var p: Prank = world.pranks[id]
		if p.used or p.disarmed or not p.armed or not p.def["reveal"] or p.def["place"] != "floor":
			continue
		var to := U.flat_xz(p.global_position - pos)
		var d := to.length()
		if d > 1.8 or d < 0.05 or to.normalized().dot(dir) < 0.6:
			continue
		if not _avoid_roll.has(id):
			_avoid_roll[id] = rng.randf() < 0.45
		if _avoid_roll[id]:
			var side := Vector3(-dir.z, 0, dir.x)
			if side.dot(to) > 0.0:
				side = -side
			return (dir * 0.4 + side).normalized()
	return dir


func _trapper_setup(now: float) -> void:
	if plan.is_empty():
		_wander(now, true)
		return
	var e: Dictionary = plan[0]
	var stand: Vector3 = e["stand"]
	if _go(stand, "place%d" % plan.size(), now) or U.dist_xz(a.global_position, stand) < 0.6:
		if now > _place_try:
			_place_try = now + 0.4
			var ok: bool = world.host_place(a.slot, e["type"], e["pos"], e["yaw"], e["socket"])
			if OS.has_environment("PW_DEBUG"):
				print("bot %s place %s at %s socket=%s ok=%s dist=%.1f" % [a.pname, e["type"], e["pos"], e["socket"], ok, U.dist_xz(a.global_position, e["pos"])])
			plan.pop_front()


func _trapper_run(now: float) -> void:
	# haunt: when a runner walks past something throwable
	if world.ghost_wait(a.slot) <= 0.0 and rng.randf() < 0.05:
		for p in world.house.props:
			if p.hidden_prop or p.carrier or p.freeze:
				continue
			if world.avatars_near(p.global_position, 3.0, true).size() > 0:
				world.ghost_action(a.slot, p.global_position)
				break
	for p in world.remote_pranks(a.team):
		if _remote_at.has(p.id):
			if now >= _remote_at[p.id]:
				world.remote_trigger(a.team, p.id)
			continue
		var r := 2.0 if p.type == "flour" else 2.6
		if world.avatars_near(Vector3(p.global_position.x, 0, p.global_position.z), r, true).size() > 0:
			_remote_at[p.id] = now + rng.randf_range(0.15, 0.6)


func _runner(now: float, _delta: float) -> void:
	if not a.can_act():
		return
	# ringing alarm or visible prank nearby: maybe disarm
	for id in world.pranks:
		var p: Prank = world.pranks[id]
		if p.used or p.disarmed or not p.armed:
			continue
		var visible_to_me: bool = p.ringing or (p.def["reveal"] and p.type != "alarm")
		if not visible_to_me:
			continue
		var d := U.dist_xz(p.net_pos(), a.global_position)
		var near := 12.0 if p.ringing else 2.2
		if d < near:
			if not _disarm_roll.has(id):
				_disarm_roll[id] = p.ringing or (rng.randf() < 0.3 and not world.sandbox)
			if _disarm_roll[id]:
				if d < 1.0:
					a.in_interact = true
					return
				_go(p.net_pos(), "disarm%d" % id, now)
				return
	# chase the runaway cat if it's close
	if world.cat_zoom_until > now:
		var cat: Prop = world._prop_of_kind("cat")
		var cd := U.dist_xz(cat.global_position, a.global_position)
		if cd < 4.0:
			if cd < 1.0:
				a.in_interact = true
				return
			var to := U.flat_xz(cat.global_position - a.global_position).normalized()
			a.in_move = Vector2(to.x, to.z)
			return
	var targets: Array = world.bot_targets()
	if a.carrying:
		for e in targets:
			if e["type"] == "deliver":
				_go(e["pos"], "deliver" + e["task"], now)
				return
	var best = null
	var bd := 1e9
	var idx := 0
	for e in targets:
		if e["type"] == "deliver":
			continue
		var d2 := U.dist_xz(e["pos"], a.global_position) + float((idx + a.slot) % 3) * 2.5
		idx += 1
		if d2 < bd:
			bd = d2
			best = e
	if best == null:
		_wander(now, true)
		return
	var key := "task_%s_%s" % [best["task"], best["at"]]
	if U.dist_xz(best["pos"], a.global_position) < float(best["radius"]) * 0.75:
		a.in_interact = true
		return
	_go(best["pos"], key, now)


func _warmup(now: float) -> void:
	if not a.can_act():
		return
	if rng.randf() < 0.002:
		world._host_action(a.slot, "taunt", [])
	_dive_cd -= 1.0 / 60.0
	for s in world.avatars:
		var o: Avatar = world.avatars[s]
		if o != a and o.active and U.dist_xz(o.global_position, a.global_position) < 2.2 and _dive_cd <= 0.0 and rng.randf() < 0.02:
			a.facing = atan2(-(o.global_position.x - a.global_position.x), -(o.global_position.z - a.global_position.z))
			a.dive()
			_dive_cd = 4.0
			return
	_wander(now, false)


func _wander(now: float, inside: bool) -> void:
	if now > _wander_at or goal == Vector3.INF:
		_wander_at = now + rng.randf_range(2.0, 5.0)
		if inside:
			var rooms := ["kitchen", "living", "bath", "hall", "bed"]
			var r: Rect2 = world.house.rooms[rooms[rng.randi() % rooms.size()]]
			goal = Vector3(r.get_center().x, 0, r.get_center().y)
		else:
			goal = Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(8, 14))
		goal_key = ""
	if _go(goal, "wander", now):
		a.in_move = Vector2.ZERO
