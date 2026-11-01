class_name Fx
extends RefCounted
## Particle bursts and floor splats (CPUParticles3D works on every renderer).


static func burst(parent: Node, pos: Vector3, kind: String, c := Color.WHITE) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.95
	p.position = pos
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	mesh.radial_segments = 6
	mesh.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	mesh.material = m
	p.mesh = mesh
	p.direction = Vector3.UP
	p.gravity = Vector3(0, -9.8, 0)
	p.color = c
	match kind:
		"water":
			p.amount = 50
			p.spread = 70.0
			p.initial_velocity_min = 2.0
			p.initial_velocity_max = 5.0
			p.lifetime = 0.9
			p.color = Color("6ec6ff")
			p.direction = Vector3.DOWN
		"paint":
			p.amount = 70
			p.spread = 90.0
			p.initial_velocity_min = 3.0
			p.initial_velocity_max = 7.0
			p.lifetime = 1.0
			p.scale_amount_min = 1.0
			p.scale_amount_max = 2.0
		"flour":
			p.amount = 70
			p.spread = 180.0
			p.initial_velocity_min = 0.5
			p.initial_velocity_max = 2.5
			p.gravity = Vector3(0, -0.3, 0)
			p.damping_min = 1.0
			p.damping_max = 2.0
			p.lifetime = 2.2
			p.scale_amount_min = 3.0
			p.scale_amount_max = 6.0
			p.color = Color(1, 1, 1, 0.85)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		"fart":
			p.amount = 25
			p.spread = 180.0
			p.initial_velocity_min = 0.3
			p.initial_velocity_max = 1.2
			p.gravity = Vector3(0, 0.4, 0)
			p.lifetime = 1.8
			p.scale_amount_min = 2.0
			p.scale_amount_max = 4.0
			p.color = Color(0.55, 0.8, 0.2, 0.7)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		"confetti":
			p.amount = 90
			p.spread = 40.0
			p.initial_velocity_min = 5.0
			p.initial_velocity_max = 9.0
			p.gravity = Vector3(0, -3.0, 0)
			p.lifetime = 2.5
			p.color_initial_ramp = _rainbow()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.08, 0.01, 0.05)
			bm.material = m
			p.mesh = bm
			p.angular_velocity_min = -400.0
			p.angular_velocity_max = 400.0
		"sparkle":
			p.amount = 24
			p.spread = 180.0
			p.initial_velocity_min = 1.5
			p.initial_velocity_max = 3.0
			p.gravity = Vector3(0, 1.0, 0)
			p.lifetime = 0.8
			p.color = Color("ffe14d")
		_:  # dust
			p.amount = 16
			p.spread = 90.0
			p.initial_velocity_min = 0.5
			p.initial_velocity_max = 1.5
			p.lifetime = 0.6
			p.color = Color(0.85, 0.8, 0.7, 0.8)
	parent.add_child(p)
	p.emitting = true
	var t := p.get_tree().create_timer(p.lifetime + 0.5)
	t.timeout.connect(p.queue_free)


static func _rainbow() -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	g.colors = PackedColorArray([Color("ff4d6d"), Color("ffd60a"), Color("3dd6c2"), Color("4f8bff"), Color("c58bff")])
	return g


static func splat(parent: Node, pos: Vector3, c: Color, r: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.01
	cm.radial_segments = 10
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.3
	mi.material_override = m
	mi.position = Vector3(pos.x, 0.03 + randf() * 0.01, pos.z)
	mi.rotation.y = randf() * TAU
	mi.scale = Vector3(randf_range(0.7, 1.3), 1, randf_range(0.7, 1.3))
	parent.add_child(mi)
	return mi
