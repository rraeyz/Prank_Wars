class_name U
extends RefCounted
## Small mesh/material helpers. Everything visual is built from primitives (no external models).

const L_WORLD := 1
const L_PLAYER := 2
const L_PROP := 4
const M_ALL := 7
const M_TRIGGER := 6

static var _mats := {}


static func mat(c: Color, rough := 0.85, metal := 0.0, unshaded := false) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%s" % [c.to_html(), rough, metal, unshaded]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[key] = m
	return m


static var _outline: StandardMaterial3D


## Inverted-hull outline for a cartoon look (works on the Compatibility renderer).
static func outline(m: StandardMaterial3D, amount := 0.025) -> StandardMaterial3D:
	var o := StandardMaterial3D.new()
	o.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	o.albedo_color = Color(0.1, 0.07, 0.12)
	o.cull_mode = BaseMaterial3D.CULL_FRONT
	o.grow = true
	o.grow_amount = amount
	m.next_pass = o
	return m


static func box(size: Vector3, c: Color, pos := Vector3.ZERO, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(c)
	mi.position = pos
	if parent:
		parent.add_child(mi)
	return mi


static func sphere(r: float, c: Color, pos := Vector3.ZERO, parent: Node = null, segs := 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = segs
	sm.rings = maxi(segs / 2, 4)
	mi.mesh = sm
	mi.material_override = mat(c)
	mi.position = pos
	if parent:
		parent.add_child(mi)
	return mi


static func cyl(r: float, h: float, c: Color, pos := Vector3.ZERO, parent: Node = null, top_r := -1.0, segs := 14) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r if top_r < 0.0 else top_r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = segs
	mi.mesh = cm
	mi.material_override = mat(c)
	mi.position = pos
	if parent:
		parent.add_child(mi)
	return mi


static func capsule(r: float, h: float, c: Color, pos := Vector3.ZERO, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = h
	cm.radial_segments = 12
	cm.rings = 4
	mi.mesh = cm
	mi.material_override = mat(c)
	mi.position = pos
	if parent:
		parent.add_child(mi)
	return mi


## Static collidable box (mesh + collision). pos is the box center.
static func solid(parent: Node, size: Vector3, pos: Vector3, c: Color, yaw := 0.0, group := "") -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = L_WORLD
	sb.collision_mask = 0
	sb.position = pos
	sb.rotation.y = yaw
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	box(size, c, Vector3.ZERO, sb)
	if group != "":
		sb.add_to_group(group)
	parent.add_child(sb)
	return sb


static func invisible_wall(parent: Node, size: Vector3, pos: Vector3) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = L_WORLD
	sb.collision_mask = 0
	sb.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	parent.add_child(sb)
	return sb


static func label3d(text: String, size := 48, c := Color.WHITE, pos := Vector3.ZERO, parent: Node = null) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.modulate = c
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.006
	l.position = pos
	if parent:
		parent.add_child(l)
	return l


static func flat_xz(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func dist_xz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
