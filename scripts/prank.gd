class_name Prank
extends Node3D
## One placed prank. Visuals on every peer; trigger logic only on the host (via World helpers).

var id := 0
var type := ""
var team := 0
var world: Node
var def: Dictionary
var socket := ""
var armed := false
var used := false
var disarmed := false
var uses := 0
var ringing := false
var ring_start := 0.0
var ring_end := 0.0
var visual: Node3D
var area: Area3D
var marbles: Array = []
var vac: Prop
var _vac_dir := Vector3.FORWARD
var _vac_turn_at := 0.0
var _vac_stuck := 0.0
var _hit_cd := {}
var _revealed := false
var _anim := -1.0  # trigger animation time
var _fx_parts: Array = []
var _tag: Label3D


func setup(w: Node, pid: int, t: String, tm: int, sock: String) -> void:
	world = w
	id = pid
	type = t
	team = tm
	socket = sock
	def = Config.PRANKS[t]
	name = "Prank_%d_%s" % [pid, t]
	visual = Node3D.new()
	add_child(visual)
	_build_visual()
	if def["trigger"] == "remote":
		_tag = U.label3d("", 56, Color("ffe14d"), Vector3(0, 0.9 if def["place"] != "ceiling" else -0.9, 0), self)
	if Net.is_host() and def["trigger"] == "step":
		area = Area3D.new()
		area.collision_layer = 0
		area.collision_mask = U.M_TRIGGER
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		var r := 0.75
		match type:
			"oil": r = 2.0
			"spring", "tape": r = 0.9
		bs.size = Vector3(r, 0.8, r)
		cs.shape = bs
		cs.position = Vector3(0, 0.4, 0)
		area.add_child(cs)
		add_child(area)
		area.body_entered.connect(_on_step)


func team_color() -> Color:
	return Config.TEAM_COLORS[team]


# ---------------------------------------------------------------- visuals

func _build_visual() -> void:
	var v := visual
	match type:
		"banana":
			var a := U.capsule(0.07, 0.42, Color("ffe14d"), Vector3(0, 0.05, 0), v)
			a.rotation.z = PI / 2.0
			for sx in [-1.0, 1.0]:
				var leaf := U.box(Vector3(0.22, 0.02, 0.09), Color("f7d23a"), Vector3(0.18 * sx, 0.02, 0.05), v)
				leaf.rotation.y = 0.6 * sx
			U.sphere(0.03, Color("5a3b00"), Vector3(0.22, 0.05, 0), v)
		"oil":
			var m := U.box(Vector3(2.0, 0.015, 2.0), Color(0.15, 0.13, 0.05, 0.55), Vector3(0, 0.025, 0), v)
			m.material_override = U.mat(Color(0.2, 0.17, 0.05, 0.55), 0.05, 0.3)
			for i in 4:
				var _t1 := U.sphere(0.12, Color(0.9, 0.8, 0.3, 0.5), Vector3(randf_range(-0.7, 0.7), 0.02, randf_range(-0.7, 0.7)), v)
				_t1.scale = Vector3(1, 0.1, 1)
		"bucket":
			var b := U.cyl(0.24, 0.36, Color("8fa3b8"), Vector3(0, 0.18, 0), v, 0.3)
			b.name = "B"
			U.cyl(0.25, 0.03, Color("4da3ff"), Vector3(0, 0.35, 0), v)
		"paint":
			U.sphere(0.22, team_color(), Vector3(0, 0.25, 0), v)
			U.cyl(0.03, 0.2, Color("333333"), Vector3(0, 0.5, 0), v)
			U.sphere(0.05, Color("ffcc00"), Vector3(0, 0.62, 0), v)
		"flour":
			U.box(Vector3(0.5, 0.6, 0.35), Color("f5f0e1"), Vector3(0, -0.3, 0), v)
			U.box(Vector3(0.52, 0.12, 0.37), Color("c9a66b"), Vector3(0, -0.1, 0), v)
			U.cyl(0.015, 0.4, Color("8d6e63"), Vector3(0, 0.15, 0), v)
		"whoopee":
			var c := U.sphere(0.3, Color("ff6ec7"), Vector3(0, 0.05, 0), v)
			c.scale = Vector3(1, 0.25, 1)
			var _t2 := U.cyl(0.06, 0.12, Color("ff9ad9"), Vector3(0, 0.05, 0.33), v)
			_t2.rotation.x = PI / 2.0
		"glove":
			U.sphere(0.2, Color("e63946"), Vector3(0, 0.3, 0.15), v)
			var _t3 := U.cyl(0.05, 0.3, Color("bbbbbb"), Vector3(0, 0.3, -0.1), v)
			_t3.rotation.x = PI / 2.0
		"tape":
			for i in 3:
				var s := U.box(Vector3(0.8, 0.012, 0.12), Color("c8c8c8"), Vector3(0, 0.015, -0.25 + i * 0.25), v)
				s.rotation.y = randf_range(-0.3, 0.3)
		"spring":
			for i in 5:
				var ring := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 0.22
				tm.outer_radius = 0.28
				ring.mesh = tm
				ring.material_override = U.mat(Color("b0b8c0"), 0.3, 0.8)
				ring.position = Vector3(0, 0.04 + i * 0.05, 0)
				v.add_child(ring)
			var plate := U.cyl(0.38, 0.05, Color("ff4d4d"), Vector3(0, 0.3, 0), v)
			plate.name = "Plate"
		"marbles":
			U.cyl(0.18, 0.3, Color(0.7, 0.9, 1.0, 0.45), Vector3(0, 0.15, 0), v)
			for i in 5:
				U.sphere(0.06, Color.from_hsv(randf(), 0.8, 1.0), Vector3(randf_range(-0.08, 0.08), 0.08 + i * 0.04, randf_range(-0.08, 0.08)), v)
			_make_marbles()
		"confetti":
			var c2 := U.cyl(0.14, 0.45, Color("7b2cbf"), Vector3(0, 0.22, 0), v, 0.2)
			c2.rotation.x = -0.2
			U.cyl(0.21, 0.04, Color("ffd60a"), Vector3(0, 0.45, -0.05), v)
		"alarm":
			U.box(Vector3(0.28, 0.24, 0.14), Color("e63946"), Vector3(0, 0.14, 0), v)
			var _t4 := U.cyl(0.09, 0.02, Color("ffffff"), Vector3(0, 0.15, -0.075), v)
			_t4.rotation.x = PI / 2.0
			U.sphere(0.07, Color("ffd60a"), Vector3(-0.1, 0.3, 0), v)
			U.sphere(0.07, Color("ffd60a"), Vector3(0.1, 0.3, 0), v)
		"fake_remote":
			U.box(Vector3(0.12, 0.05, 0.3), Color("222222"), Vector3(0, 0.03, 0), v)
			U.sphere(0.03, Color("ff2222"), Vector3(0, 0.07, -0.1), v)
		"vacuum":
			_make_vacuum()


func _make_marbles() -> void:
	for k in 16:
		var m := Prop.new()
		m.name = "Marble_%d_%d" % [id, k]
		world.entity_root().add_child(m)
		m.setup("marble", Vector3(0.14, 0.14, 0.14), Color.from_hsv(float(k) / 16.0, 0.75, 1.0), 0.3, "ball")
		m.carryable = false
		m.continuous_cd = true
		m.global_position = global_position + Vector3(0, 0.2 + k * 0.01, 0)
		m.net_id = 100000 + id * 32 + k
		m.world = world
		m.set_hidden(true)
		world.register_entity(m.net_id, m)
		marbles.append(m)


func _make_vacuum() -> void:
	vac = Prop.new()
	vac.name = "Vacuum_%d" % id
	world.entity_root().add_child(vac)
	vac.setup("vacuum", Vector3(0.62, 0.16, 0.62), Color("2b2d42"), 6.0, "box")
	vac.get_child(0).visible = false
	U.cyl(0.33, 0.14, Color("2b2d42"), Vector3.ZERO, vac)
	U.cyl(0.25, 0.03, Color("8d99ae"), Vector3(0, 0.08, 0), vac)
	U.sphere(0.05, Color("00ff88"), Vector3(0, 0.1, -0.22), vac)
	vac.carryable = false
	vac.global_position = global_position + Vector3(0, 0.12, 0)
	vac.net_id = 100000 + id * 32 + 31
	vac.world = world
	vac.axis_lock_angular_x = true
	vac.axis_lock_angular_z = true
	world.register_entity(vac.net_id, vac)


func _process(delta: float) -> void:
	if _anim >= 0.0:
		_anim += delta
		_animate_trigger()
	# visibility: trappers see everything, runners only see revealable pranks up close
	var show := true
	if not world.local_sees_pranks(team):
		show = false
		if ringing:
			show = true
		elif def["reveal"] and not used:
			var me: Node3D = world.local_view_target()
			if me and U.dist_xz(me.global_position, global_position) < 2.6:
				show = true
				if not _revealed:
					_revealed = true
					Sfx.play("uhoh", global_position, -6.0)
		elif used and type in ["banana", "oil", "tape", "spring", "flour", "bucket", "confetti", "whoopee"]:
			show = true
	if type == "vacuum":
		show = true
	visual.visible = show
	if _tag:
		_tag.visible = false
		if (world.phase == "run" or world.phase == "sandbox") and not used and world.local_team() == team and not world.replaying:
			var idx: int = world.remote_pranks(team).find(self)
			if idx >= 0:
				_tag.visible = true
				_tag.text = "[%d]" % (idx + 1)
	if ringing:
		visual.rotation.z = sin(Time.get_ticks_msec() * 0.06) * 0.25
	if disarmed:
		visual.scale = visual.scale.lerp(Vector3(0.6, 0.6, 0.6), minf(1.0, delta * 6.0))


func reset_visual() -> void:
	## Used before replays: put the prank back in its armed look.
	_anim = -1.0
	visual.position = Vector3.ZERO
	visual.rotation = Vector3.ZERO
	visual.scale = Vector3.ONE
	visual.visible = true
	for p in _fx_parts:
		if is_instance_valid(p):
			p.queue_free()
	_fx_parts.clear()


## Client+host: play the trigger animation for this prank.
func play_trigger() -> void:
	_anim = 0.0
	match type:
		"banana":
			Sfx.play("slip", global_position)
		"bucket":
			Sfx.play("splash", global_position)
		"spring":
			Sfx.play("boing", global_position)
		"whoopee":
			Sfx.play("fart", global_position, 3.0)
		"tape":
			Sfx.play("tape", global_position)
		"marbles":
			Sfx.play("marbles", global_position)
		"oil":
			Sfx.play("slip", global_position, 0.0, 0.8)
		"flour":
			Sfx.play("whoosh", global_position)
		"confetti":
			Sfx.play("confetti", global_position)
		"glove":
			Sfx.play("punch", global_position)
		"paint", "fake_remote":
			Sfx.play("paint", global_position)


func _animate_trigger() -> void:
	var a := _anim
	match type:
		"banana":
			visual.position = Vector3(a * 2.5, 2.5 * a - 6.0 * a * a, a * 1.0)
			visual.rotation.z = a * 18.0
			if a > 0.8:
				visual.position.y = maxf(visual.position.y, 0.0)
		"bucket":
			visual.position.y = -a * 6.0
			visual.rotation.x = minf(a * 6.0, PI)
			if a > 0.35:
				visual.visible = false
		"spring":
			var plate := visual.get_node_or_null("Plate")
			if plate:
				plate.position.y = 0.3 + minf(a * 8.0, 0.6) * exp(-a * 2.0) * 1.5
		"flour":
			visual.position.y = -minf(a * a * 25.0, 2.4)
		"glove":
			visual.position.z = minf(a * 12.0, 1.0) * (1.0 - clampf((a - 0.4) * 3.0, 0.0, 1.0))
		"whoopee":
			visual.scale = Vector3(1.0, maxf(0.3, 1.0 - a * 3.0), 1.0)
		"paint", "fake_remote", "confetti":
			if a > 0.05:
				visual.visible = false
	if a > 3.0:
		_anim = -1.0


# ---------------------------------------------------------------- host logic

func arm() -> void:
	armed = true
	if type == "alarm":
		ring_start = Config.now + randf_range(20.0, 40.0)


func _on_step(body: Node) -> void:
	if not armed or used or disarmed:
		return
	if body is Avatar:
		var a: Avatar = body
		if world.is_runner(a) and a.active:
			fire(a)
	elif body is Prop:
		var p: Prop = body
		if (p.is_chained(Config.now) or Config.now < p.thrown_until) and type in ["marbles", "spring"]:
			fire(p)


## Host: trigger the prank. cause is the Avatar/Prop that set it off (null for remote).
func fire(cause: Node3D) -> void:
	if not armed or used or disarmed:
		return
	var now := Config.now
	var victim: Avatar = cause as Avatar
	match type:
		"banana":
			used = true
			var d := victim.move_dir()
			var ch: int = world.prank_hit(self, victim, cause)
			victim.knock(d * 6.0 + Vector3.UP * 4.5, d.cross(Vector3.UP) * 12.0, 2.0, ch)
		"oil":
			if _hit_cd.get(victim.slot, 0.0) > now:
				return
			_hit_cd[victim.slot] = now + 3.0
			uses += 1
			if uses >= 4:
				used = true
			var d2 := victim.move_dir()
			var ch2: int = world.prank_hit(self, victim, cause)
			victim.knock(d2 * 8.5 + Vector3.UP * 1.5, d2.cross(Vector3.UP) * 9.0 + Vector3.UP * 6.0, 2.4, ch2)
			victim.slide_until = now + 1.3
			victim.slide_vel = d2 * 8.5
		"whoopee":
			used = true
			var ch3: int = world.prank_hit(self, victim, cause)
			victim.panic(1.6, ch3)
		"tape":
			used = true
			var ch4: int = world.prank_hit(self, victim, cause)
			victim.stick(3.0, ch4)
		"spring":
			used = true
			var vs: Array = world.avatars_near(global_position, 0.9, true)
			if victim and not vs.has(victim):
				vs.append(victim)
			for v in vs:
				var ch5: int = world.prank_hit(self, v, cause)
				var f: Vector3 = v.forward()
				v.knock(Vector3.UP * 14.0 + f * 3.0 + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)),
					Vector3(randf_range(-10, 10), randf_range(-5, 5), randf_range(-10, 10)), 2.4, ch5)
			if cause is Prop:
				(cause as Prop).linear_velocity = Vector3.UP * 14.0
		"marbles":
			used = true
			var ch6 := -1
			if victim:
				ch6 = world.prank_hit(self, victim, cause)
				var d3 := victim.move_dir()
				victim.knock(d3 * 4.0 + Vector3.UP * 3.5, d3.cross(Vector3.UP) * 10.0, 1.8, ch6)
			elif cause is Prop and (cause as Prop).is_chained(now):
				ch6 = (cause as Prop).chain_id
			for k in marbles.size():
				var m: Prop = marbles[k]
				m.set_hidden(false)
				m.freeze = false
				var ang := TAU * k / marbles.size()
				m.global_position = global_position + Vector3(cos(ang) * 0.2, 0.25, sin(ang) * 0.2)
				m.linear_velocity = Vector3(cos(ang), 0.2, sin(ang)) * randf_range(4.0, 7.0)
				m.chain_id = ch6
				m.chain_until = now + 7.0
		"bucket":
			used = true
			var ch7: int = world.prank_hit(self, victim, cause)
			victim.wet(3.5, ch7)
			world.add_mess(victim, 20.0, Color("6ec6ff"), "water")
		"paint", "fake_remote", "glove":
			used = true
			var center := global_position
			var vs2: Array = world.avatars_near(center, 2.6 if type == "paint" else 1.6, true)
			if victim and not vs2.has(victim):
				vs2.append(victim)
			for v in vs2:
				var ch8: int = world.prank_hit(self, v, cause)
				var away := U.flat_xz(v.global_position - center).normalized()
				if away.length() < 0.1:
					away = -v.forward()
				var power := 13.0 if type == "glove" else 7.0
				v.knock(away * power + Vector3.UP * 4.5, away.cross(Vector3.UP) * -10.0, 2.2 if type == "glove" else 1.8, ch8)
				if type != "glove":
					world.add_mess(v, 40.0, team_color(), "paint")
			if type != "glove":
				world.fx_all("splats", [center, team_color(), 2.4])
		"flour", "confetti":
			used = true
			var floor_p := Vector3(global_position.x, 0.0, global_position.z)
			var r := 2.2 if type == "flour" else 3.0
			for v in world.avatars_near(floor_p, r, true):
				var ch9: int = world.prank_hit(self, v, cause)
				var away2 := U.flat_xz(v.global_position - floor_p).normalized()
				if type == "flour":
					v.knock(Vector3.UP * 2.5 + away2 * 2.0, Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)), 1.3, ch9)
					world.add_mess(v, 35.0, Color.WHITE, "flour")
					world.fx_all("blind", [v.slot, "flour", 2.5])
				else:
					v.knock(Vector3.UP * 3.0 + away2 * 5.0, Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)), 1.2, ch9)
					world.add_mess(v, 10.0, Color.from_hsv(randf(), 0.8, 1.0), "confetti")
					world.fx_all("blind", [v.slot, "confetti", 2.0])
		_:
			return
	world.fx_all("prank", [id, "trigger"])


func host_tick(delta: float) -> void:
	var now := Config.now
	if type == "alarm" and armed and not used and not disarmed:
		if not ringing and ring_start > 0.0 and now >= ring_start:
			ringing = true
			ring_end = now + 25.0
			world.fx_all("prank", [id, "ring_on"])
		elif ringing and now >= ring_end:
			ringing = false
			used = true
			world.alarm_failed(self)
			world.fx_all("prank", [id, "ring_off"])
	if type == "vacuum" and vac and armed and not disarmed:
		if now > _vac_turn_at:
			_vac_turn_at = now + randf_range(2.5, 5.0)
			_vac_dir = _vac_dir.rotated(Vector3.UP, randf_range(-1.6, 1.6))
		var hv := Vector3(vac.linear_velocity.x, 0, vac.linear_velocity.z)
		if hv.length() < 0.4:
			_vac_stuck += delta
			if _vac_stuck > 0.5:
				_vac_stuck = 0.0
				_vac_dir = _vac_dir.rotated(Vector3.UP, randf_range(PI * 0.6, PI * 1.4))
		else:
			_vac_stuck = 0.0
		var target := _vac_dir * 2.0
		vac.linear_velocity = Vector3(target.x, vac.linear_velocity.y, target.z)
		vac.rotation.y = atan2(-_vac_dir.x, -_vac_dir.z)
		if not vac.is_chained(now) and vac.chain_id > 0:
			vac.chain_id = -1


## Host: vacuum body touched a runner.
func vacuum_bump(a: Avatar) -> void:
	var now := Config.now
	if disarmed or not armed or _hit_cd.get(a.slot, 0.0) > now or a.is_knocked():
		return
	_hit_cd[a.slot] = now + 4.0
	var ch: int = world.prank_hit(self, a, vac)
	var d := U.flat_xz(a.global_position - vac.global_position).normalized()
	a.knock(d * 5.0 + Vector3.UP * 3.0, d.cross(Vector3.UP) * -8.0, 1.4, ch)
	vac.chain_id = ch
	vac.chain_until = now + 4.0
	world.fx_all("sfx", ["thud", vac.global_position])


func disarm() -> void:
	disarmed = true
	armed = false
	ringing = false
	if vac:
		vac.linear_velocity = Vector3.ZERO


func net_pos() -> Vector3:
	return vac.global_position if vac else global_position
