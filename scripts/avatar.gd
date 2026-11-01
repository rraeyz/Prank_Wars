class_name Avatar
extends RigidBody3D
## Player character: a big-headed bean. Upright = we steer velocity and force the basis upright.
## Knocked = free rigid body tumbling (the "ragdoll"), then it stands back up by itself.
## The host simulates; clients only display (frozen kinematic, transform from snapshots).

const SPEED := 5.6
const JUMP_V := 7.5
const HALF_H := 0.7

enum F { KNOCKED = 1, STUCK = 2, WET = 4, CARRY = 8, PANIC = 16, HAT = 32, HIDDEN = 64, ACT = 128, SHIELD = 256, FAST = 512 }

var world: Node
var slot := 0
var peer_id := 0
var pname := ""
var team := 0
var color := Color.WHITE
var is_bot := false
var active := true

# host-side input + state
var in_move := Vector2.ZERO
var in_interact := false
var want_jump := false
var facing := 0.0
var knocked_until := 0.0
var down := false
var recover_until := 0.0
var self_knock := false
var stuck_until := 0.0
var slow_until := 0.0
var hat_until := 0.0
var panic_until := 0.0
var panic_dir := Vector3.ZERO
var slide_until := 0.0
var slide_vel := Vector3.ZERO
var chain_id := -1
var chain_until := 0.0
var carrying: Prop = null
var grounded := false
var mess := 0.0
var shield_until := 0.0  # umbrella power-up: blocks the next prank
var immune_until := 0.0  # set for a moment when the umbrella absorbs a hit
var fast_until := 0.0  # coffee power-up
var perk := ""  # this round's perk
var steady := 0  # "steady feet" perk / comeback bonus: absorbs the next prank
var interacting := false
var _bump_cd := {}
var _air_time := 0.0
var pre_vel := Vector3.ZERO  # velocity before the latest physics step (contacts report post-impact velocity)

# display
var flags := 0
var body_root: Node3D
var _mat: StandardMaterial3D
var _arms: Array = []
var _feet: Array = []
var _pupils: Array = []
var _splats: Node3D
var _hat: Node3D
var _tape: Node3D
var _label: Label3D
var _prev_pos := Vector3.ZERO
var _vel_disp := Vector3.ZERO
var _anim := 0.0
var _pupil_off := [Vector3.ZERO, Vector3.ZERO]
var _pupil_v := [Vector3.ZERO, Vector3.ZERO]
var _mess_color := Color.WHITE
var _flour := 0.0
var _stars: Node3D
var _head: Node3D
var _lamp: OmniLight3D
var _umbrella: Node3D
var taunt_until := 0.0  # local clock (Time) for the dance
var _dizzy := 0.0


var look := {}
var _prop_spin: Node3D


func setup(w: Node, info: Dictionary, s: int, pid: int) -> void:
	look = Cosmetics.sanitize(info.get("look", {}))
	world = w
	slot = s
	peer_id = pid
	pname = str(info["name"])
	team = int(info["team"])
	is_bot = bool(info["bot"])
	color = Config.PLAYER_COLORS[int(info["color"]) % Config.PLAYER_COLORS.size()]
	name = "Avatar_%d" % slot
	add_to_group("avatars")
	mass = 1.0
	gravity_scale = 2.2
	can_sleep = false
	continuous_cd = true
	collision_layer = U.L_PLAYER
	collision_mask = U.M_ALL
	var pm := PhysicsMaterial.new()
	pm.friction = 0.35
	pm.bounce = 0.25
	physics_material_override = pm
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = HALF_H * 2.0
	cs.shape = cap
	add_child(cs)
	_build_visual()
	if Net.is_host():
		custom_integrator = true
		contact_monitor = true
		max_contacts_reported = 4
		body_entered.connect(_on_body_entered)
	else:
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true
		collision_layer = 0
		collision_mask = 0


func _build_visual() -> void:
	body_root = Node3D.new()
	add_child(body_root)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = color
	_mat.roughness = 0.6
	U.outline(_mat, 0.03)
	var torso := U.capsule(0.31, 0.95, color, Vector3(0, -0.22, 0), body_root)
	torso.material_override = _mat
	# head pivot: eyes, mouth, hat and stars ride on it so the "big heads" rule can scale it
	_head = Node3D.new()
	_head.position = Vector3(0, 0.32, 0)
	body_root.add_child(_head)
	var head := U.sphere(0.4, color, Vector3.ZERO, _head, 18)
	head.material_override = _mat
	for sx in [-1.0, 1.0]:
		U.sphere(0.12, Color.WHITE, Vector3(0.15 * sx, 0.10, -0.31), _head)
		var pupil := U.sphere(0.06, Color("111111"), Vector3(0.15 * sx, 0.10, -0.41), _head)
		_pupils.append(pupil)
		var arm := Node3D.new()
		arm.position = Vector3(0.33 * sx, -0.12, 0)
		body_root.add_child(arm)
		var am := U.capsule(0.08, 0.5, color.darkened(0.15), Vector3(0, -0.22, 0), arm)
		am.name = "Arm"
		U.sphere(0.1, Color("fff1e0"), Vector3(0, -0.47, 0), arm)
		_arms.append(arm)
		var foot := U.box(Vector3(0.18, 0.1, 0.28), Color("333344"), Vector3(0.15 * sx, -0.66, -0.04), body_root)
		_feet.append(foot)
	U.box(Vector3(0.16, 0.035, 0.02), Color("111111"), Vector3(0, -0.10, -0.39), _head)  # mouth
	_splats = Node3D.new()
	body_root.add_child(_splats)
	_hat = Node3D.new()
	_hat.position = Vector3(0, 0.30, 0)
	_head.add_child(_hat)
	var b := U.cyl(0.3, 0.42, Color("8fa3b8"), Vector3(0, 0, 0), _hat, 0.24)
	b.rotation.x = PI
	_hat.visible = false
	_tape = Node3D.new()
	add_child(_tape)
	U.box(Vector3(0.9, 0.02, 0.18), Color("c0c0c0"), Vector3(0, -HALF_H + 0.01, 0), _tape)
	U.box(Vector3(0.18, 0.02, 0.9), Color("c0c0c0"), Vector3(0, -HALF_H + 0.01, 0), _tape)
	_tape.top_level = true
	_tape.visible = false
	_label = U.label3d(pname, 40, color.lightened(0.3), Vector3(0, 1.05, 0), self)
	_stars = Node3D.new()
	_stars.position = Vector3(0, 0.53, 0)
	_head.add_child(_stars)
	Cosmetics.apply(self, look)
	_umbrella = Node3D.new()
	_umbrella.position = Vector3(0, 1.05, 0)
	add_child(_umbrella)
	var canopy := U.sphere(0.6, Color("ff5d8f"), Vector3.ZERO, _umbrella, 10)
	canopy.scale = Vector3(1, 0.35, 1)
	U.cyl(0.02, 0.6, Color("333333"), Vector3(0, -0.3, 0), _umbrella)
	_umbrella.visible = false
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(0, 0.9, 0)
	_lamp.omni_range = 5.5
	_lamp.light_energy = 1.6
	_lamp.light_color = Color("ffe9b0")
	_lamp.visible = false
	add_child(_lamp)
	for i in 3:
		var a := TAU * i / 3.0
		U.sphere(0.07, Color("ffe14d"), Vector3(cos(a) * 0.32, 0, sin(a) * 0.32), _stars, 6)
	_stars.visible = false


# ---------------------------------------------------------------- host simulation

func can_act() -> bool:
	return active and not down and Config.now >= recover_until


func is_knocked() -> bool:
	return down or Config.now < recover_until


func is_chained() -> bool:
	return chain_id > 0 and Config.now < chain_until


func set_chain(c: int, until: float) -> void:
	if c > 0:
		chain_id = c
		chain_until = maxf(chain_until if chain_id == c else 0.0, until)


func forward() -> Vector3:
	return Vector3(-sin(facing), 0, -cos(facing))


func move_dir() -> Vector3:
	var hv := Vector3(linear_velocity.x, 0, linear_velocity.z)
	return hv.normalized() if hv.length() > 0.8 else forward()


func immune() -> bool:
	return Config.now < immune_until


func knock(vel: Vector3, spin: Vector3, dur: float, chain := -1, by_self := false) -> void:
	if not active or (not by_self and immune()):
		return
	var now := Config.now
	knocked_until = maxf(knocked_until if down else 0.0, now + dur)
	down = true
	recover_until = 0.0
	self_knock = by_self
	linear_velocity = vel
	angular_velocity = spin
	if chain > 0:
		set_chain(chain, knocked_until + 1.0)
	drop_carry()
	if not by_self and world:
		world.fx_all("yell", [slot])
		world.stat(slot, "falls", 1)


func panic(dur: float, chain: int) -> void:
	if immune():
		return
	panic_until = Config.now + dur
	var a := randf() * TAU
	panic_dir = Vector3(cos(a), 0, sin(a))
	linear_velocity.y = 6.0
	set_chain(chain, panic_until + 1.0)


func stick(dur: float, chain: int) -> void:
	if immune():
		return
	stuck_until = Config.now + dur
	set_chain(chain, stuck_until + 1.0)


func wet(dur: float, chain: int) -> void:
	if immune():
		return
	slow_until = Config.now + dur
	hat_until = Config.now + dur
	set_chain(chain, slow_until + 0.5)


func jump() -> void:
	want_jump = true


func dive() -> void:
	if not can_act() or Config.now < stuck_until:
		return
	var f := forward()
	knock(f * 7.5 + Vector3.UP * 3.5, f.cross(Vector3.UP) * -9.0, 1.0, -1, true)
	if world:
		world.fx_all("sfx", ["whoosh", global_position])


func drop_carry() -> void:
	if carrying:
		var p := carrying
		carrying = null
		p.carrier = null
		p.freeze = false
		p.linear_velocity = linear_velocity + Vector3(randf_range(-1, 1), 2.0, randf_range(-1, 1))


func throw_carry() -> void:
	if carrying:
		var p := carrying
		drop_carry()
		p.linear_velocity = forward() * 9.0 + Vector3.UP * 4.0
		p.thrown_by = self
		p.thrown_until = Config.now + 1.5


func pick_up(p: Prop) -> void:
	if carrying or p.carrier:
		return
	carrying = p
	p.carrier = self
	p.freeze = true


func park() -> void:
	## Hide (trapper spectating during chores).
	active = false
	drop_carry()
	freeze = true
	collision_layer = 0
	global_position = Vector3(0, -30, 0)


func respawn(pos: Vector3) -> void:
	active = true
	drop_carry()
	knocked_until = 0.0
	down = false
	recover_until = 0.0
	stuck_until = 0.0
	slow_until = 0.0
	hat_until = 0.0
	panic_until = 0.0
	slide_until = 0.0
	chain_id = -1
	mess = 0.0
	shield_until = 0.0
	fast_until = 0.0
	immune_until = 0.0
	facing = 0.0
	if Net.is_host():
		collision_layer = U.L_PLAYER
		freeze = false
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
	global_transform = Transform3D(Basis.IDENTITY, pos)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not active:
		return
	var now := Config.now
	var dt := state.step
	# custom_integrator skips the engine's gravity: apply it ourselves (includes gravity_scale)
	state.linear_velocity += state.total_gravity * dt
	# remember the fastest recent velocity (contacts are reported a step after the impact)
	if state.linear_velocity.length() >= pre_vel.length() * 0.8:
		pre_vel = state.linear_velocity
	else:
		pre_vel *= 0.8
	var pos := state.transform.origin
	var q := PhysicsRayQueryParameters3D.create(pos, pos + Vector3(0, -HALF_H - 0.12, 0), U.L_WORLD | U.L_PROP | U.L_PLAYER, [get_rid()])
	grounded = not state.get_space_state().intersect_ray(q).is_empty()
	if carrying:
		carrying.global_transform = Transform3D(Basis(Vector3.UP, facing), pos + Vector3(0, 1.25, 0))
	if down:
		if now < slide_until:
			var slv := state.linear_velocity
			slv.x = slide_vel.x
			slv.z = slide_vel.z
			state.linear_velocity = slv
			slide_vel *= 0.985
		# stand up once slowed down (or after a while)
		if now >= knocked_until and (state.linear_velocity.length() < 3.0 or now > knocked_until + 1.2):
			down = false
			recover_until = now + 0.4
			state.linear_velocity = Vector3(0, 3.0, 0)
		return
	var up_basis := Basis(Vector3.UP, facing)
	if now < recover_until:
		var cur := state.transform.basis.orthonormalized()
		state.transform = Transform3D(cur.slerp(up_basis, minf(1.0, dt * 12.0)), pos)
		state.angular_velocity = Vector3.ZERO
		return
	recover_until = 0.0
	# upright control
	var dir := Vector3(in_move.x, 0, in_move.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	if now < panic_until:
		dir = panic_dir
	if now < stuck_until:
		dir = Vector3.ZERO
	var spd := SPEED
	var rule: String = world.modifier if world else ""
	if rule == "turbo":
		spd *= 1.45
	if now < fast_until:
		spd *= 1.35
	if perk == "sprinter":
		spd *= 1.12
	if world and world.rush and world.is_runner(self):
		spd *= 1.15
	if now < slow_until:
		spd *= 0.45
	if carrying:
		spd *= 0.85
	var lv := state.linear_velocity
	var target := dir * spd
	var accel := (6.0 if rule == "ice" else 45.0) if grounded else 14.0
	var h := Vector2(lv.x, lv.z).move_toward(Vector2(target.x, target.z), accel * dt)
	lv.x = h.x
	lv.z = h.y
	if want_jump:
		want_jump = false
		if grounded and now >= stuck_until:
			lv.y = JUMP_V
	state.linear_velocity = lv
	if dir.length() > 0.1:
		facing = lerp_angle(facing, atan2(-dir.x, -dir.z), minf(1.0, dt * 14.0))
	state.transform = Transform3D(Basis(Vector3.UP, facing), pos)
	state.angular_velocity = Vector3.ZERO


func _on_body_entered(other: Node) -> void:
	if not world or not active:
		return
	var now := Config.now
	var spd := maxf(linear_velocity.length(), pre_vel.length())
	if other is Avatar:
		var o: Avatar = other
		if is_knocked() and not o.is_knocked() and o.active and spd > 4.0:
			if _bump_cd.get(o.slot, 0.0) > now:
				return
			_bump_cd[o.slot] = now + 1.5
			world.on_bump(self, o)
	elif other is Prop:
		var p: Prop = other
		if is_knocked() and is_chained() and spd > 3.0 and not p.freeze:
			p.chain_id = chain_id
			p.chain_until = now + 3.0


func net_flags() -> int:
	var now := Config.now
	var f := 0
	if is_knocked():
		f |= F.KNOCKED
	if now < stuck_until:
		f |= F.STUCK
	if now < slow_until:
		f |= F.WET
	if carrying:
		f |= F.CARRY
	if now < panic_until:
		f |= F.PANIC
	if now < hat_until:
		f |= F.HAT
	if not active:
		f |= F.HIDDEN
	if interacting:
		f |= F.ACT
	if now < shield_until:
		f |= F.SHIELD
	if now < fast_until:
		f |= F.FAST
	return f


# ---------------------------------------------------------------- display (all peers)

func add_mess(amount: float, c: Color, kind: String) -> void:
	mess = clampf(mess + amount, 0.0, 100.0)
	if kind == "flour":
		_flour = clampf(_flour + amount / 60.0, 0.0, 0.85)
	var n := int(clampf(amount / 6.0, 1.0, 8.0))
	for i in n:
		if _splats.get_child_count() > 40:
			_splats.get_child(0).free()
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.6, 1.0), randf_range(-1, 1)).normalized()
		var s := U.sphere(randf_range(0.08, 0.17), c, Vector3(0, 0.05, 0) + dir * 0.38, _splats, 8)
		s.scale = Vector3(1, 1, 0.35)
		s.look_at_from_position(s.position, s.position + dir * 2.0, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
	_mess_color = c


func _process(delta: float) -> void:
	if Net.is_host():
		flags = net_flags()
	visible = (flags & F.HIDDEN) == 0
	if not visible:
		return
	_anim += delta
	var p := global_position
	var v := (p - _prev_pos) / maxf(delta, 0.001)
	_prev_pos = p
	if v.length() > 30.0:
		v = Vector3.ZERO
	_vel_disp = _vel_disp.lerp(v, minf(1.0, delta * 10.0))
	var spd := Vector2(_vel_disp.x, _vel_disp.z).length()
	var knocked := (flags & F.KNOCKED) != 0
	var t := _anim
	for i in 2:
		var arm: Node3D = _arms[i]
		var sx := -1.0 if i == 0 else 1.0
		var rx := 0.0
		var rz := 0.15 * sx
		if knocked or (flags & F.PANIC) != 0:
			rx = -2.6 + sin(t * 23.0 + i * 2.0) * 0.7
			rz = (0.6 + sin(t * 17.0 + i) * 0.4) * sx
		elif (flags & F.CARRY) != 0:
			rx = -2.9
		elif (flags & F.STUCK) != 0:
			rx = -1.2 + sin(t * 14.0 + i * PI) * 0.8
			rz = 0.5 * sx
		elif (flags & F.ACT) != 0:
			rx = -1.3 + sin(t * 18.0 + i * PI) * 0.35
		else:
			var sw := clampf(spd / Avatar.SPEED, 0.0, 1.0)
			rx = sin(t * 11.0 + i * PI) * 0.9 * sw
			rz = (0.12 + 0.05 * sin(t * 2.0)) * sx
		arm.rotation.x = lerp_angle(arm.rotation.x, rx, minf(1.0, delta * 14.0))
		arm.rotation.z = lerp_angle(arm.rotation.z, rz, minf(1.0, delta * 14.0))
		var foot: MeshInstance3D = _feet[i]
		var fw := clampf(spd / Avatar.SPEED, 0.0, 1.0)
		foot.position.z = -0.04 + sin(t * 11.0 + i * PI) * 0.18 * fw
		foot.position.y = -0.66 + maxf(0.0, cos(t * 11.0 + i * PI)) * 0.08 * fw
	# googly pupils: spring toward a velocity-driven offset
	for i in 2:
		var target := Vector3(clampf(-_vel_disp.x * 0.01, -0.05, 0.05), clampf(-_vel_disp.y * 0.01, -0.05, 0.05), 0)
		if knocked:
			target = Vector3(sin(t * 20.0 + i * 3.0), cos(t * 16.0 + i), 0) * 0.05
		var dt := minf(delta, 1.0 / 30.0)
		_pupil_v[i] = (_pupil_v[i] + (target - _pupil_off[i]) * 300.0 * dt).limit_length(3.0) * 0.85
		_pupil_off[i] = (_pupil_off[i] + _pupil_v[i] * dt).limit_length(0.08)
		var base := Vector3(0.15 * (-1.0 if i == 0 else 1.0), 0.10, -0.41)
		_pupils[i].position = base + _pupil_off[i].limit_length(0.06)
	var rule: String = world.modifier if world else ""
	var hs := 1.75 if rule == "bighead" else 1.0
	_head.scale = _head.scale.lerp(Vector3(hs, hs, hs), minf(1.0, delta * 6.0))
	_lamp.visible = rule == "blackout"
	var now_t := Time.get_ticks_msec() * 0.001
	if now_t < taunt_until and not knocked:
		var k := taunt_until - now_t
		body_root.position.y = absf(sin(k * 14.0)) * 0.25
		body_root.rotation.y = sin(k * 9.0) * 0.6
		for i in 2:
			_arms[i].rotation.x = -2.8 + sin(k * 20.0 + i * PI) * 0.5
			_arms[i].rotation.z = (0.9 if i == 1 else -0.9)
	else:
		body_root.position.y = 0.0
		body_root.rotation.y = 0.0
	_dizzy = 1.2 if knocked else maxf(0.0, _dizzy - delta)
	_stars.visible = _dizzy > 0.0 and not knocked
	if _stars.visible:
		_stars.rotation.y += delta * 9.0
		_stars.global_rotation.x = 0.0
		_stars.global_rotation.z = 0.0
	_hat.visible = (flags & F.HAT) != 0
	_umbrella.visible = (flags & F.SHIELD) != 0
	if _umbrella.visible:
		_umbrella.global_rotation = Vector3.ZERO
	if (flags & F.FAST) != 0 and fmod(_anim, 0.12) < delta:
		Fx.burst(self.get_parent(), global_position - Vector3(0, 0.6, 0), "dust")
	if _prop_spin:
		_prop_spin.rotation.y += delta * (6.0 + _vel_disp.length() * 4.0)
	_tape.visible = (flags & F.STUCK) != 0
	if _tape.visible:
		_tape.global_position = Vector3(p.x, maxf(p.y - HALF_H, 0.0) + HALF_H, p.z)
	var c := color
	if mess > 0.0:
		c = c.lerp(_mess_color, clampf(mess / 160.0, 0.0, 0.45))
	c = c.lerp(Color.WHITE, _flour)
	if (flags & F.WET) != 0:
		c = c.darkened(0.25)
	_mat.albedo_color = c
	_label.visible = world == null or world.show_names
