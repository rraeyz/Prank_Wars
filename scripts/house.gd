class_name House
extends Node3D
## Builds the single-story house + garden from code. Deterministic, so every peer builds the same thing.
## Coordinates: X east, Z south. Camera looks north (-Z). House interior x -8..8, z -6..6; garden south.

const H := 2.6
const T := 0.2
const DOOR_W := 1.3
const DOOR_H := 2.15
var RECT := Rect2(-8, -6, 16, 12)  # interior; the mansion is bigger
var GARDEN := Rect2(-11, 6, 22, 10)

const C_WALL := Color("f6efe3")
const C_WALL_TOP := Color("8a6f5a")
const C_DOOR := Color("b5835a")
const C_WOOD := Color("c8955f")
const C_DARK_WOOD := Color("8b5a3c")
const C_WHITE := Color("f2f2f2")

var walls: Array = []  # {"nodes": [MeshInstance3D], "mat", "x0", "x1", "z", "a"}
var doors := {}
var cupboards := {}
var spots := {}  # name -> {"pos": Vector3, "radius": float, "node": Node3D}
var props: Array = []
var roof: Node3D
var rooms := {
	"kitchen": Rect2(-8, -6, 7, 6), "living": Rect2(-1, -6, 9, 6), "bath": Rect2(-8, 0, 5, 6),
	"hall": Rect2(-3, 0, 4, 6), "bed": Rect2(1, 0, 7, 6), "garden": GARDEN,
}
var nav_pts: Array = []  # Vector3
var nav_room: Array = []  # String
var nav_adj := {}  # idx -> Array[idx]
var spawn_garden: Array = []
var spawn_house: Array = []
var _front_block: StaticBody3D
var map := "house"
var custom_nodes: Array = []
var lights: Array = []  # warm room lights (switched off by the Blackout rule)
const ART := [Color("e76f51"), Color("2a9d8f"), Color("e9c46a"), Color("264653"), Color("f4a261"), Color("8ecae6"), Color("b5838d")]
const MAPS := ["house", "office", "school", "wedding", "mansion"]
const MAP_SIZE := {"house": "medium", "office": "medium", "school": "medium", "wedding": "medium", "mansion": "large"}
var _nav_centers := {"kitchen": Vector3(-3.4, 0, -3.0), "living": Vector3(1.6, 0, -2.6),
	"bath": Vector3(-5.3, 0, 2.8), "hall": Vector3(-1.0, 0, 3.0), "bed": Vector3(3.6, 0, 2.6)}


## Builds the chosen map. Every map shares the outer shell (16x12, front door at x=-1) and the garden.
func build(map_name := "house", custom: Array = []) -> void:
	map = map_name if map_name in MAPS else "house"
	if map == "mansion":
		RECT = Rect2(-12, -10, 24, 16)
		GARDEN = Rect2(-15, 6, 30, 10)
		rooms = {"kitchen": Rect2(-12, -10, 8, 7), "dining": Rect2(-4, -10, 8, 7), "library": Rect2(4, -10, 8, 7),
			"bath": Rect2(-12, -3, 6, 9), "hall": Rect2(-6, -3, 6, 9), "living": Rect2(0, -3, 6, 9), "bed": Rect2(6, -3, 6, 9),
			"garden": GARDEN}
		_nav_centers = {"kitchen": Vector3(-6.5, 0, -5.5), "dining": Vector3(0, 0, -4.3), "library": Vector3(6.0, 0, -6.0),
			"bath": Vector3(-9.0, 0, 1.5), "hall": Vector3(-3.0, 0, 1.5), "living": Vector3(5.0, 0, 0.3), "bed": Vector3(8.0, 0, 1.0)}
		_floors({"kitchen": Color("e6cf9f"), "dining": Color("b5835a"), "library": Color("7b5e57"), "bath": Color("8fc9d6"),
			"hall": Color("bf9c78"), "living": Color("c08f5e"), "bed": Color("b9a3dc")})
		_mansion_walls()
		_mansion_furniture()
	elif map == "wedding":
		rooms = {"banquet": Rect2(-8, -6, 11, 7), "kitchen": Rect2(3, -6, 5, 6), "bride": Rect2(3, 0, 5, 6),
			"restroom": Rect2(-8, 1, 5, 5), "foyer": Rect2(-3, 1, 6, 5), "garden": GARDEN}
		_nav_centers = {"banquet": Vector3(-2.0, 0, -2.0), "kitchen": Vector3(5.0, 0, -1.2), "bride": Vector3(5.0, 0, 2.6),
			"restroom": Vector3(-5.5, 0, 2.6), "foyer": Vector3(0.0, 0, 3.5)}
		_floors({"banquet": Color("e8d9c0"), "kitchen": Color("dfe7ee"), "bride": Color("f2c4d6"),
			"restroom": Color("9fd3dc"), "foyer": Color("c9b79c")})
		_wedding_walls()
		_wedding_furniture()
	elif map == "school":
		rooms = {"classroom": Rect2(-8, -6, 8, 6), "gym": Rect2(0, -6, 8, 6), "teachers": Rect2(-8, 0, 5, 6),
			"corridor": Rect2(-3, 0, 6, 6), "cafeteria": Rect2(3, 0, 5, 6), "garden": GARDEN}
		_nav_centers = {"classroom": Vector3(-4.0, 0, -0.9), "gym": Vector3(3.5, 0, -2.8), "teachers": Vector3(-5.5, 0, 3.0),
			"corridor": Vector3(0.0, 0, 3.0), "cafeteria": Vector3(5.5, 0, 3.2)}
		_floors({"classroom": Color("d8c9a8"), "gym": Color("d9a05b"), "teachers": Color("9fb3c8"),
			"corridor": Color("cfd8dc"), "cafeteria": Color("f2d39b")})
		_school_walls()
		_school_furniture()
	elif map == "office":
		rooms = {"open_office": Rect2(-8, -6, 11, 7), "break": Rect2(3, -6, 5, 6), "meeting": Rect2(3, 0, 5, 6),
			"boss": Rect2(-8, 1, 5, 5), "lobby": Rect2(-3, 1, 6, 5), "garden": GARDEN}
		_nav_centers = {"open_office": Vector3(-2.0, 0, -3.0), "break": Vector3(4.2, 0, -2.6),
			"meeting": Vector3(4.0, 0, 1.2), "boss": Vector3(-5.0, 0, 2.8), "lobby": Vector3(-0.5, 0, 3.5)}
		_floors({"open_office": Color("9fb3c8"), "break": Color("e6cf9f"), "meeting": Color("b7c4a3"),
			"boss": Color("8c5a3c"), "lobby": Color("d8d2c4")})
		_office_walls()
		_office_furniture()
	else:
		_floors({"kitchen": Color("e6cf9f"), "living": Color("c08f5e"), "bath": Color("8fc9d6"),
			"hall": Color("bf9c78"), "bed": Color("b9a3dc")})
		_house_decor()
		_walls()
		_furniture()
	for it in sanitize_items(custom, RECT):
		custom_nodes.append(build_item(it[0], Vector3(it[1], 0, it[2]), it[3]))
	_garden()
	_roof()
	_room_lights()
	_nav()
	_front_block = U.invisible_wall(self, Vector3(DOOR_W + 0.2, 3.0, 0.3), Vector3(-1.0, 1.5, 6.0))
	for i in 8:
		spawn_garden.append(Vector3(-4.5 + (i % 4) * 2.0, 0.8, 10.5 + (i / 4) * 1.8))
		spawn_house.append(Vector3(-2.2 + (i % 4) * 0.9, 0.8, 2.2 + (i / 4) * 1.6))


func _ceiling() -> void:
	U.invisible_wall(self, Vector3(RECT.size.x + 0.4, 0.4, RECT.size.y + 0.4), Vector3(RECT.get_center().x, 3.1, RECT.get_center().y))


func set_front_locked(l: bool) -> void:
	if _front_block:
		_front_block.collision_layer = U.L_WORLD if l else 0


## Chores that exist on this map.
func task_ids() -> Array:
	var out := []
	for t in Config.TASKS:
		var ok := true
		for st in Config.TASKS[t]:
			var at: String = st["at"]
			if not (spots.has(at) or cupboards.has(at) or props.any(func(p): return p.kind == at)):
				ok = false
		if ok:
			out.append(t)
	return out


func room_of(p: Vector3) -> String:
	for r in rooms:
		if r != "garden" and rooms[r].has_point(Vector2(p.x, p.z)):
			return r
	return "garden" if GARDEN.grow(2.0).has_point(Vector2(p.x, p.z)) else "out"


func inside(p: Vector3, margin := 0.0) -> bool:
	return RECT.grow(-margin).has_point(Vector2(p.x, p.z))


# ------------------------------------------------------------------ floors

func _floors(cols: Dictionary) -> void:
	var fl := StaticBody3D.new()
	fl.collision_layer = U.L_WORLD
	fl.add_to_group("floor")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(60, 1, 60)
	cs.shape = bs
	cs.position = Vector3(0, -0.5, 4)
	fl.add_child(cs)
	add_child(fl)
	var grass := U.box(Vector3(60, 0.1, 60), Color("5fb345"), Vector3(0, -0.06, 4), self)
	grass.name = "Grass"
	grass.material_override = _textured(Color("5fb345"), _noise_tex(0.08), Vector3(18, 18, 1))
	var floor_tex := _noise_tex(0.02, true)
	for r in cols:
		var rc: Rect2 = rooms[r]
		var f := U.box(Vector3(rc.size.x, 0.04, rc.size.y), cols[r], Vector3(rc.get_center().x, 0.0, rc.get_center().y), self)
		f.material_override = _textured(cols[r], floor_tex, Vector3(rc.size.x / 3.0, rc.size.y / 3.0, 1))
	_windows()


static var _tex_cache := {}


## Soft procedural noise so floors and grass aren't flat colors (no image files needed).
func _noise_tex(freq: float, planks := false, lo := 0.82) -> Texture2D:
	var key := "%f%s%f" % [freq, planks, lo]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var n := FastNoiseLite.new()
	n.frequency = freq
	n.seed = 7
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.noise = n
	if planks:
		n.fractal_octaves = 2
		t.width = 64
		t.height = 512
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(lo, lo, lo), Color(1, 1, 1)])
	t.color_ramp = g
	_tex_cache[key] = t
	return t


func _textured(c: Color, tex: Texture2D, scale: Vector3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.albedo_texture = tex
	m.uv1_scale = scale
	m.roughness = 0.85
	return m


## Windows on the inside faces of the outer walls the camera can see (north, west, east).
func _windows() -> void:
	var glass := Color(0.62, 0.84, 1.0)
	var frame := Color("fdfdfd")
	var x := RECT.position.x + 2.0
	while x < RECT.end.x - 1.5:
		var win := Node3D.new()
		win.position = Vector3(x, 1.45, RECT.position.y + T / 2.0 + 0.02)
		add_child(win)
		U.box(Vector3(1.2, 0.9, 0.04), frame, Vector3.ZERO, win)
		U.box(Vector3(1.05, 0.75, 0.05), glass, Vector3(0, 0, 0.01), win)
		U.box(Vector3(0.04, 0.75, 0.06), frame, Vector3(0, 0, 0.02), win)
		x += 4.0
	for side in [-1.0, 1.0]:
		var z := RECT.position.y + 2.0
		while z < 5.0:
			var w2 := Node3D.new()
			var wx: float = (RECT.position.x + T / 2.0 + 0.02) if side < 0.0 else (RECT.end.x - T / 2.0 - 0.02)
			w2.position = Vector3(wx, 1.45, z)
			w2.rotation.y = PI / 2.0
			add_child(w2)
			U.box(Vector3(1.2, 0.9, 0.04), frame, Vector3.ZERO, w2)
			U.box(Vector3(1.05, 0.75, 0.05), glass, Vector3(0, 0, 0.01 * side), w2)
			z += 4.0


func _house_decor() -> void:
	# kitchen + bath tile checker accents
	for i in 12:
		var x := -7.5 + (i % 6) * 1.2
		var z := -5.5 + (i / 6) * 1.2 + (0.6 if i % 2 == 0 else 0.0)
		U.box(Vector3(0.6, 0.045, 0.6), Color("f4ead2"), Vector3(x, 0.0, z), self)
	# rugs
	U.box(Vector3(3.2, 0.05, 2.2), Color("e86f5a"), Vector3(3.5, 0.0, -2.6), self)
	U.box(Vector3(1.4, 0.05, 3.6), Color("6a8fd8"), Vector3(-1.0, 0.0, 3.2), self)
	U.box(Vector3(2.4, 0.05, 1.6), Color("f0c84a"), Vector3(4.3, 0.0, 3.5), self)


# ------------------------------------------------------------------ walls

func _walls() -> void:
	_wall_x(-6.0, -8.0, 8.0, [])
	_wall_x(6.0, -8.0, 8.0, [-1.0], ["front"])
	_wall_x(0.0, -8.0, 8.0, [-2.0, 0.3], ["hall_kitchen", "hall_living"])
	_wall_z(-8.0, -6.0, 6.0, [])
	_wall_z(8.0, -6.0, 6.0, [])
	_wall_z(-1.0, -6.0, 0.0, [-3.0], ["kitchen_living"])
	_wall_z(-3.0, 0.0, 6.0, [3.0], ["hall_bath"])
	_wall_z(1.0, 0.0, 6.0, [3.0], ["hall_bed"])
	# invisible ceiling keeps launched players inside
	_ceiling()


func _wall_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = C_WALL
	m.roughness = 0.9
	m.albedo_texture = _noise_tex(0.2, false, 0.95)  # faint plaster
	m.uv1_triplanar = true
	return m


## Wall decoration with its own material, so the camera fade can make it see-through with its wall.
func _deco(size: Vector3, pos: Vector3, c: Color, parent: Node, nodes: Array) -> MeshInstance3D:
	var mi := U.box(size, c, pos, parent)
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	mi.material_override = m
	nodes.append(mi)
	return mi


func _door_frame(p: Vector3, horiz: bool, nodes: Array) -> void:
	var c := Color("8a6f5a")
	var th := T + 0.07
	for sd in [-1.0, 1.0]:
		var off: float = (DOOR_W / 2.0 + 0.04) * sd
		if horiz:
			_deco(Vector3(0.08, DOOR_H, th), p + Vector3(off, DOOR_H / 2.0, 0), c, self, nodes)
		else:
			_deco(Vector3(th, DOOR_H, 0.08), p + Vector3(0, DOOR_H / 2.0, off), c, self, nodes)
	_deco(Vector3(DOOR_W + 0.16, 0.08, th) if horiz else Vector3(th, 0.08, DOOR_W + 0.16), p + Vector3(0, DOOR_H + 0.04, 0), c, self, nodes)


## A framed little landscape on both faces of an interior wall.
func _painting(p: Vector3, horiz: bool, nodes: Array) -> void:
	var k := int(absf(p.x * 7.0 + p.z * 13.0))
	for sd in [-1.0, 1.0]:
		var n := Vector3(0, 0, sd) if horiz else Vector3(sd, 0, 0)
		var q: Vector3 = p + n * (T / 2.0 + 0.02)
		var flip := func(v: Vector3) -> Vector3: return v if horiz else Vector3(v.z, v.y, v.x)
		var j := k + (1 if sd > 0.0 else 0)
		_deco(flip.call(Vector3(0.82, 0.62, 0.03)), q, Color("5d4037"), self, nodes)
		_deco(flip.call(Vector3(0.7, 0.5, 0.03)), q + n * 0.006, ART[j % ART.size()].lightened(0.35), self, nodes)
		_deco(flip.call(Vector3(0.7, 0.2, 0.03)), q + n * 0.012 + Vector3(0, -0.15, 0), ART[(j + 3) % ART.size()], self, nodes)
		_deco(flip.call(Vector3(0.12, 0.12, 0.03)), q + n * 0.012 + flip.call(Vector3(0.18, 0.1, 0)), Color("ffe066"), self, nodes)


func _room_lights() -> void:
	for r in rooms:
		if r == "garden":
			continue
		var rc: Rect2 = rooms[r]
		var l := OmniLight3D.new()
		l.position = Vector3(rc.get_center().x, 2.35, rc.get_center().y)
		l.light_color = Color(1.0, 0.86, 0.7)
		l.light_energy = 0.55
		l.omni_range = maxf(rc.size.x, rc.size.y) * 0.8
		l.shadow_enabled = false
		add_child(l)
		lights.append(l)


func _wall_piece(size: Vector3, pos: Vector3, m: StandardMaterial3D, nodes: Array) -> void:
	var sb := U.solid(self, size, pos, C_WALL)
	var mi: MeshInstance3D = sb.get_child(1)
	mi.material_override = m
	nodes.append(mi)
	var cap := U.box(Vector3(size.x + 0.01, 0.05, size.z + 0.01), C_WALL_TOP, Vector3(0, size.y / 2.0, 0), sb)
	var cm := StandardMaterial3D.new()
	cm.albedo_color = C_WALL_TOP
	cap.material_override = cm
	nodes.append(cap)
	if size.y > 1.0:  # skirting board
		var grow := Vector3(0.04 if size.x <= T + 0.01 else 0.0, 0.0, 0.04 if size.z <= T + 0.01 else 0.0)
		_deco(Vector3(size.x, 0.12, size.z) + grow, Vector3(0, -size.y / 2.0 + 0.06, 0), Color("b08968"), sb, nodes)


func _segments(a0: float, a1: float, gaps: Array) -> Array:
	var segs := []
	var cur := a0
	var sorted := gaps.duplicate()
	sorted.sort()
	for g in sorted:
		segs.append([cur, g - DOOR_W / 2.0])
		cur = g + DOOR_W / 2.0
	segs.append([cur, a1])
	return segs


func _wall_x(z: float, x0: float, x1: float, door_xs: Array, names: Array = []) -> void:
	var m := _wall_mat()
	var nodes := []
	var interior := z > RECT.position.y + 0.1 and z < RECT.end.y - 0.1
	for s in _segments(x0 - T / 2.0, x1 + T / 2.0, door_xs):
		var l: float = s[1] - s[0]
		if l > 0.01:
			_wall_piece(Vector3(l, H, T), Vector3((s[0] + s[1]) / 2.0, H / 2.0, z), m, nodes)
		if interior and l > 2.4 and int(absf(s[0] * 3.0 + z)) % 3 != 0:
			_painting(Vector3((s[0] + s[1]) / 2.0, 1.55, z), true, nodes)
	for i in door_xs.size():
		_wall_piece(Vector3(DOOR_W, H - DOOR_H, T), Vector3(door_xs[i], (H + DOOR_H) / 2.0, z), m, nodes)
		_door_frame(Vector3(door_xs[i], 0, z), true, nodes)
		if i < names.size():
			_door(names[i], Vector3(door_xs[i], 0, z), true)
	walls.append({"nodes": nodes, "mat": m, "x0": x0, "x1": x1, "z": z, "a": 1.0})


func _wall_z(x: float, z0: float, z1: float, door_zs: Array, names: Array = []) -> void:
	var m := _wall_mat()
	var nodes := []
	var interior := x > RECT.position.x + 0.1 and x < RECT.end.x - 0.1
	for s in _segments(z0 + T / 2.0, z1 - T / 2.0, door_zs):
		var l: float = s[1] - s[0]
		if l > 0.01:
			_wall_piece(Vector3(T, H, l), Vector3(x, H / 2.0, (s[0] + s[1]) / 2.0), m, nodes)
		if interior and l > 2.4 and int(absf(s[0] * 3.0 + x)) % 3 != 0:
			_painting(Vector3(x, 1.55, (s[0] + s[1]) / 2.0), false, nodes)
	for i in door_zs.size():
		_wall_piece(Vector3(T, H - DOOR_H, DOOR_W), Vector3(x, (H + DOOR_H) / 2.0, door_zs[i]), m, nodes)
		_door_frame(Vector3(x, 0, door_zs[i]), false, nodes)
		if i < names.size():
			_door(names[i], Vector3(x, 0, door_zs[i]), false)


func _door(n: String, pos: Vector3, horiz: bool) -> void:
	var d := HouseDoor.new()
	d.name = "Door_" + n
	d.position = pos
	add_child(d)
	d.setup(n, DOOR_W, horiz, C_DOOR)
	doors[n] = d


## Fades E-W walls that sit between the camera (south) and the target.
func update_fade(target: Vector3, delta: float, force_roof := false) -> void:
	var in_house := inside(target, -0.5)
	for w in walls:
		var want := 1.0
		if in_house and w["z"] > target.z + 0.05 and w["z"] < target.z + 7.5 \
				and target.x > w["x0"] - 2.0 and target.x < w["x1"] + 2.0:
			want = 0.18
		var a: float = lerpf(w["a"], want, minf(1.0, delta * 8.0))
		if absf(a - w["a"]) > 0.001:
			w["a"] = a
			for n in w["nodes"]:
				var m: StandardMaterial3D = n.material_override
				m.albedo_color.a = a
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if a < 0.98 else BaseMaterial3D.TRANSPARENCY_DISABLED
	if roof:
		roof.visible = force_roof or not inside(target, -0.6)


# ------------------------------------------------------------------ furniture

func _cupboard(n: String, size: Vector3, pos: Vector3, yaw: float, body: Color, door: Color) -> Cupboard:
	var c := Cupboard.new()
	c.name = "Cup_" + n
	c.position = pos
	c.rotation.y = yaw
	add_child(c)
	c.setup(n, size, body, door)
	cupboards[n] = c
	return c


func _spot(n: String, pos: Vector3, radius := 1.4) -> Node3D:
	var s := Node3D.new()
	s.name = "Spot_" + n
	s.position = pos
	add_child(s)
	spots[n] = {"pos": pos, "radius": radius, "node": s}
	return s


func _prop(k: String, size: Vector3, pos: Vector3, c: Color, m := 2.0, shape := "box", carry := true) -> Prop:
	var p := Prop.new()
	p.name = "Prop_%d_%s" % [props.size(), k]
	p.position = pos
	add_child(p)
	p.setup(k, size, c, m, shape)
	p.carryable = carry
	p.home = p.transform
	props.append(p)
	return p


func _furniture() -> void:
	# --- kitchen (NW) ---
	_cupboard("fridge", Vector3(0.9, 1.9, 0.75), Vector3(-7.35, 0, -5.5), 0.0, Color("e9eef2"), Color("dfe7ee"))
	U.solid(self, Vector3(2.8, 0.92, 0.7), Vector3(-5.3, 0.46, -5.6), Color("c9d6df"))
	U.box(Vector3(2.85, 0.06, 0.75), Color("f7f7f7"), Vector3(-5.3, 0.95, -5.58), self)
	_spot("counter", Vector3(-5.3, 0.95, -5.1), 1.3)
	U.box(Vector3(0.45, 0.04, 0.3), C_WOOD, Vector3(-5.3, 1.0, -5.55), self)  # cutting board
	U.box(Vector3(0.22, 0.08, 0.2), Color("f5c26b"), Vector3(-5.3, 1.06, -5.55), self)  # bread
	_cupboard("cat_cabinet", Vector3(1.0, 0.92, 0.7), Vector3(-3.3, 0, -5.6), 0.0, Color("c9d6df"), Color("8fb3c9"))
	_cupboard("kitchen_drawer", Vector3(1.0, 0.92, 0.7), Vector3(-2.2, 0, -5.6), 0.0, Color("c9d6df"), Color("8fb3c9"))
	U.solid(self, Vector3(1.5, 0.08, 1.0), Vector3(-5.3, 0.78, -2.6), C_WOOD)
	for lx in [-0.65, 0.65]:
		for lz in [-0.4, 0.4]:
			U.box(Vector3(0.08, 0.74, 0.08), C_DARK_WOOD, Vector3(-5.3 + lx, 0.37, -2.6 + lz), self)
	U.invisible_wall(self, Vector3(1.4, 0.74, 0.9), Vector3(-5.3, 0.37, -2.6))
	_prop("chair", Vector3(0.45, 0.9, 0.45), Vector3(-5.3, 0.5, -1.6), Color("e8a45c"), 3.0)
	_prop("chair", Vector3(0.45, 0.9, 0.45), Vector3(-6.4, 0.5, -2.6), Color("e8a45c"), 3.0)
	_prop("trash_bag", Vector3(0.5, 0.6, 0.5), Vector3(-7.3, 0.35, -1.0), Color("2f3a33"), 2.0)
	# --- living (NE) ---
	U.solid(self, Vector3(2.8, 0.45, 0.95), Vector3(3.5, 0.22, -5.4), Color("5b7fc4"))
	U.solid(self, Vector3(2.8, 0.55, 0.25), Vector3(3.5, 0.72, -5.78), Color("4d6db0"))
	U.solid(self, Vector3(0.25, 0.65, 0.95), Vector3(2.0, 0.32, -5.4), Color("4d6db0"))
	U.solid(self, Vector3(0.25, 0.65, 0.95), Vector3(5.0, 0.32, -5.4), Color("4d6db0"))
	_spot("remote_spot", Vector3(3.5, 0.5, -5.1), 1.4)
	var remote := U.box(Vector3(0.12, 0.05, 0.3), Color("222222"), Vector3(3.6, 0.48, -5.2), self)
	remote.name = "TVRemote"
	_prop("cushion", Vector3(0.55, 0.2, 0.55), Vector3(2.7, 0.6, -5.3), Color("ffd166"), 0.6)
	_prop("cushion", Vector3(0.55, 0.2, 0.55), Vector3(4.3, 0.6, -5.3), Color("ef476f"), 0.6)
	U.solid(self, Vector3(1.3, 0.42, 0.7), Vector3(3.5, 0.21, -2.6), C_WOOD)
	_cupboard("tv_stand", Vector3(2.0, 0.55, 0.5), Vector3(3.5, 0, -0.4), PI, C_DARK_WOOD, C_WOOD)
	U.box(Vector3(1.7, 0.95, 0.08), Color("1d1d22"), Vector3(3.5, 1.05, -0.35), self)
	U.box(Vector3(1.55, 0.82, 0.02), Color("2a3f6b"), Vector3(3.5, 1.05, -0.4), self)
	U.solid(self, Vector3(1.0, 0.5, 1.0), Vector3(6.9, 0.25, -2.6), Color("e07a5f"))
	U.solid(self, Vector3(0.25, 0.6, 1.0), Vector3(7.45, 0.75, -2.6), Color("c8634a"))
	_cupboard("shelf", Vector3(1.3, 1.8, 0.45), Vector3(0.2, 0, -5.72), 0.0, C_DARK_WOOD, C_WOOD)
	_plant("plant_a", Vector3(7.35, 0, -5.35))
	# --- bathroom (SW) ---
	U.box(Vector3(1.4, 0.08, 1.4), Color("ffffff"), Vector3(-7.2, 0.04, 5.2), self)
	U.box(Vector3(0.04, 2.0, 1.4), Color(0.7, 0.9, 1.0, 0.35), Vector3(-6.5, 1.0, 5.2), self)
	U.cyl(0.05, 0.4, Color("aaaaaa"), Vector3(-7.75, 2.0, 5.2), self)
	U.cyl(0.15, 0.06, Color("cccccc"), Vector3(-7.6, 2.15, 5.2), self)
	_spot("shower", Vector3(-7.2, 0.0, 5.2), 1.0)
	U.solid(self, Vector3(0.5, 0.45, 0.65), Vector3(-3.8, 0.22, 5.55), C_WHITE)
	U.solid(self, Vector3(0.5, 0.5, 0.18), Vector3(-3.8, 0.7, 5.85), C_WHITE)
	_cupboard("bath_cabinet", Vector3(1.1, 0.85, 0.55), Vector3(-5.5, 0, 0.4), 0.0, C_WHITE, Color("9fd3dc"))
	_prop("laundry", Vector3(0.6, 0.45, 0.45), Vector3(-7.2, 0.3, 1.0), Color("d9b38c"), 1.5)
	# --- hallway ---
	_spot("cat_bowl", Vector3(0.35, 0.0, 1.0), 1.3)
	U.cyl(0.2, 0.08, Color("e63946"), Vector3(0.35, 0.04, 1.0), self, 0.24)
	_cat(Vector3(0.6, 0, 0.55))
	_cupboard("hall_cabinet", Vector3(1.0, 0.9, 0.45), Vector3(-2.35, 0, 5.65), PI, C_DARK_WOOD, C_WOOD)
	# --- bedroom (SE) ---
	U.solid(self, Vector3(2.3, 0.45, 1.6), Vector3(6.8, 0.22, 3.6), C_DARK_WOOD)
	U.box(Vector3(2.0, 0.18, 1.55), Color("f4f1ea"), Vector3(6.65, 0.53, 3.6), self)
	var blanket := U.box(Vector3(1.4, 0.06, 1.62), Color("7fb3d5"), Vector3(6.2, 0.62, 3.6), self)
	blanket.rotation.z = 0.12
	U.box(Vector3(0.4, 0.16, 1.0), C_WHITE, Vector3(7.65, 0.65, 3.6), self)
	U.solid(self, Vector3(0.15, 0.9, 1.6), Vector3(7.95, 0.45, 3.6), C_DARK_WOOD)
	_spot("bed", Vector3(6.8, 0.5, 3.6), 1.9)
	_cupboard("wardrobe", Vector3(1.5, 2.0, 0.6), Vector3(2.4, 0, 0.4), 0.0, Color("a0785a"), Color("c49a74"))
	_cupboard("nightstand", Vector3(0.55, 0.55, 0.5), Vector3(7.5, 0, 5.6), PI, C_DARK_WOOD, C_WOOD)
	_plant("plant_b", Vector3(7.4, 0, 0.55))


func _plant(n: String, pos: Vector3) -> void:
	U.solid(self, Vector3(0.45, 0.45, 0.45), pos + Vector3(0, 0.22, 0), Color("c46b3e"))
	U.sphere(0.4, Color("3fa34d"), pos + Vector3(0, 0.75, 0), self)
	U.sphere(0.28, Color("58c45f"), pos + Vector3(0.15, 1.0, 0.1), self)
	_spot(n, pos, 1.3)


## The cat is a physics prop so the "runaway cat" event can make it zoom around the house.
func _cat(pos: Vector3) -> void:
	var col := Color("f4a259")
	var cp := _prop("cat", Vector3(0.3, 0.5, 0.5), pos + Vector3(0, 0.26, 0), col, 1.5, "box", false)
	cp.get_child(0).visible = false
	cp.axis_lock_angular_x = true
	cp.axis_lock_angular_z = true
	var c := Node3D.new()
	c.position = Vector3(0, -0.26, 0)
	cp.add_child(c)
	U.box(Vector3(0.3, 0.25, 0.45), col, Vector3(0, 0.15, 0), c)
	U.box(Vector3(0.26, 0.24, 0.24), col, Vector3(0, 0.38, -0.22), c)
	U.box(Vector3(0.07, 0.1, 0.05), col, Vector3(-0.08, 0.53, -0.22), c)
	U.box(Vector3(0.07, 0.1, 0.05), col, Vector3(0.08, 0.53, -0.22), c)
	var tail := U.box(Vector3(0.05, 0.05, 0.3), col, Vector3(0, 0.25, 0.32), c)
	tail.rotation.x = -0.6
	U.sphere(0.03, Color.BLACK, Vector3(-0.06, 0.42, -0.35), c)
	U.sphere(0.03, Color.BLACK, Vector3(0.06, 0.42, -0.35), c)


# ------------------------------------------------------------------ garden

func _garden() -> void:
	var g := GARDEN
	var fc := Color("f2e9dc")
	# fence (visual low) + invisible tall boundary
	for side in [[Vector3(g.get_center().x, 0, g.end.y), Vector3(g.size.x, 0, 0.1)],
			[Vector3(g.position.x, 0, g.get_center().y), Vector3(0.1, 0, g.size.y)],
			[Vector3(g.end.x, 0, g.get_center().y), Vector3(0.1, 0, g.size.y)]]:
		var c: Vector3 = side[0]
		var s: Vector3 = side[1]
		U.box(Vector3(maxf(s.x, 0.1), 0.7, maxf(s.z, 0.1)), fc, c + Vector3(0, 0.35, 0), self)
		U.invisible_wall(self, Vector3(maxf(s.x, 0.3), 6, maxf(s.z, 0.3)), c + Vector3(0, 3, 0))
	var side_w := RECT.position.x - GARDEN.position.x + 0.2
	U.invisible_wall(self, Vector3(side_w, 6, 0.3), Vector3(GARDEN.position.x + side_w / 2.0, 3, 6.0))
	U.invisible_wall(self, Vector3(side_w, 6, 0.3), Vector3(GARDEN.end.x - side_w / 2.0, 3, 6.0))
	U.invisible_wall(self, Vector3(RECT.size.x + 0.4, 2, 0.3), Vector3(RECT.get_center().x, 3.9, 6.0))
	# path to the front door
	U.box(Vector3(1.4, 0.05, 4.0), Color("cdb79e"), Vector3(-1.0, 0.0, 8.1), self)
	# trash bin
	U.solid(self, Vector3(0.8, 1.0, 0.8), Vector3(7.0, 0.5, 10.0), Color("2d8a4e"))
	U.box(Vector3(0.85, 0.08, 0.85), Color("23703f"), Vector3(7.0, 1.04, 10.0), self)
	_spot("trash_bin", Vector3(7.0, 0, 10.0), 1.5)
	# clothesline
	for x in [-8.0, -5.0]:
		U.solid(self, Vector3(0.1, 1.9, 0.1), Vector3(x, 0.95, 11.0), Color("8d99ae"))
	U.box(Vector3(3.0, 0.02, 0.02), Color("eeeeee"), Vector3(-6.5, 1.8, 11.0), self)
	_spot("clothesline", Vector3(-6.5, 0, 11.0), 1.8)
	# flowers and bushes
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 26:
		var x := rng.randf_range(GARDEN.position.x + 0.7, GARDEN.end.x - 0.7)
		var z := rng.randf_range(6.6, 15.4)
		if absf(x + 1.0) < 1.4 or (x > 5.5 and x < 8.5 and z < 11.5) or (x < -4.5 and z > 10 and z < 12):
			continue
		if i % 3 == 0:
			U.sphere(rng.randf_range(0.35, 0.55), Color("3f9e3a"), Vector3(x, 0.2, z), self, 10)
		else:
			U.cyl(0.02, 0.3, Color("2e7d32"), Vector3(x, 0.15, z), self)
			U.sphere(0.09, Color.from_hsv(rng.randf(), 0.6, 1.0), Vector3(x, 0.32, z), self, 8)
	# tree
	U.solid(self, Vector3(0.4, 2.0, 0.4), Vector3(8.5, 1.0, 14.0), C_DARK_WOOD)
	U.sphere(1.3, Color("4caf50"), Vector3(8.5, 2.6, 14.0), self)
	# pizza for the "delivery" event (hidden until the doorbell rings)
	var pz := _prop("pizza", Vector3(0.5, 0.08, 0.5), Vector3(-0.2, 0.1, 7.3), Color("e9a23b"), 0.5)
	U.cyl(0.21, 0.02, Color("d94a2b"), Vector3(0, 0.05, 0), pz)
	for i in 4:
		U.sphere(0.04, Color("8b1e1e"), Vector3(cos(i * 1.6) * 0.12, 0.07, sin(i * 1.6) * 0.12), pz, 6)
	# power-ups (hidden until spawned during chores)
	var um := _prop("umbrella", Vector3(0.5, 0.5, 0.5), Vector3(-8.0, 0.4, 14.0), Color("ff5d8f"), 0.5, "box", false)
	um.get_child(0).visible = false
	var cn := U.sphere(0.3, Color("ff5d8f"), Vector3(0, 0.1, 0), um, 10)
	cn.scale = Vector3(1, 0.4, 1)
	U.cyl(0.02, 0.4, Color("333333"), Vector3(0, -0.1, 0), um)
	var cf := _prop("coffee", Vector3(0.3, 0.35, 0.3), Vector3(-7.0, 0.4, 14.0), Color("6f4e37"), 0.4, "box", false)
	cf.get_child(0).visible = false
	U.cyl(0.13, 0.3, Color.WHITE, Vector3.ZERO, cf, 0.16)
	U.cyl(0.165, 0.05, Color("6f4e37"), Vector3(0, 0.16, 0), cf)
	# toys for warm-up
	_prop("ball", Vector3(0.8, 0.8, 0.8), Vector3(2.0, 0.5, 12.0), Color("ff4d6d"), 0.8, "ball")
	_prop("ball", Vector3(0.6, 0.6, 0.6), Vector3(-3.0, 0.5, 13.5), Color("4dd2ff"), 0.6, "ball")
	_prop("box", Vector3(0.6, 0.6, 0.6), Vector3(4.0, 0.35, 13.0), Color("d4a373"), 1.5)
	_prop("box", Vector3(0.6, 0.6, 0.6), Vector3(4.0, 1.0, 13.0), Color("d4a373"), 1.5)
	_prop("box", Vector3(0.6, 0.6, 0.6), Vector3(4.7, 0.35, 13.0), Color("d4a373"), 1.5)


func _roof() -> void:
	roof = Node3D.new()
	roof.name = "Roof"
	add_child(roof)
	var rc := Color("c4553a")
	var cx := RECT.get_center().x
	var cz := RECT.get_center().y
	var half := RECT.size.y / 2.0
	var w := RECT.size.x + 1.2
	var a := U.box(Vector3(w, 0.25, half + 1.0), rc, Vector3(cx, 3.55, cz - half / 2.0 - 0.1), roof)
	a.rotation.x = 0.32
	var b := U.box(Vector3(w, 0.25, half + 1.0), rc, Vector3(cx, 3.55, cz + half / 2.0 + 0.1), roof)
	b.rotation.x = -0.32
	U.box(Vector3(w + 0.2, 0.2, 0.4), Color("9e3f2b"), Vector3(cx, 3.6 + half * 0.17, cz), roof)
	U.box(Vector3(0.6, 1.2, 0.6), Color("8d6e63"), Vector3(4.5, 4.6, -1.5), roof)


# ------------------------------------------------------------------ navigation (bots)

func _nav() -> void:
	var centers := _nav_centers.duplicate()
	centers["garden"] = Vector3(-1.0, 0, 9.5)
	for r in centers:
		_nav_add(centers[r])
	_nav_add(Vector3(5.0, 0, 9.5))
	_nav_add(Vector3(-5.0, 0, 9.8))
	for n in doors:
		var d: HouseDoor = doors[n]
		var off := Vector3(0, 0, 0.9) if d.horizontal else Vector3(0.9, 0, 0)
		var a := _nav_add(d.position - off)
		var b := _nav_add(d.position + off)
		_nav_link(a, b)
	for i in nav_pts.size():
		for j in range(i + 1, nav_pts.size()):
			if nav_room[i] == nav_room[j] and nav_room[i] != "out":
				_nav_link(i, j)


func _nav_add(p: Vector3) -> int:
	nav_pts.append(p)
	nav_room.append(room_of(p))
	nav_adj[nav_pts.size() - 1] = []
	return nav_pts.size() - 1


func _nav_link(a: int, b: int) -> void:
	nav_adj[a].append(b)
	nav_adj[b].append(a)


func _nearest_node(p: Vector3, room: String) -> int:
	var best := -1
	var bd := 1e9
	for i in nav_pts.size():
		if nav_room[i] != room:
			continue
		var d := U.dist_xz(p, nav_pts[i])
		if d < bd:
			bd = d
			best = i
	return best


## Waypoints from a to b (ends with b). Straight line when in the same room.
func path(a: Vector3, b: Vector3) -> Array:
	var ra := room_of(a)
	var rb := room_of(b)
	if ra == rb or ra == "out" or rb == "out":
		return [b]
	var s := _nearest_node(a, ra)
	var goal_room := rb
	if s < 0:
		return [b]
	# Dijkstra (graph is tiny)
	var dist := {s: 0.0}
	var prev := {}
	var open := [s]
	var found := -1
	while open.size() > 0:
		var bi := 0
		for k in open.size():
			if dist[open[k]] < dist[open[bi]]:
				bi = k
		var u: int = open[bi]
		open.remove_at(bi)
		if nav_room[u] == goal_room:
			found = u
			break
		for v in nav_adj[u]:
			var nd: float = dist[u] + nav_pts[u].distance_to(nav_pts[v])
			if not dist.has(v) or nd < dist[v]:
				dist[v] = nd
				prev[v] = u
				if not open.has(v):
					open.append(v)
	if found < 0:
		return [b]
	var out := [b]
	var c := found
	while true:
		out.push_front(nav_pts[c])
		if not prev.has(c):
			break
		c = prev[c]
	return out


# ------------------------------------------------------------------ office map

func _office_walls() -> void:
	_wall_x(-6.0, -8.0, 8.0, [])
	_wall_x(6.0, -8.0, 8.0, [-1.0], ["front"])
	_wall_x(1.0, -8.0, 3.0, [0.0], ["lobby_office"])
	_wall_x(0.0, 3.0, 8.0, [5.5], ["break_meeting"])
	_wall_z(-8.0, -6.0, 6.0, [])
	_wall_z(8.0, -6.0, 6.0, [])
	_wall_z(3.0, -6.0, 6.0, [-3.0, 3.0], ["office_break", "lobby_meeting"])
	_wall_z(-3.0, 1.0, 6.0, [3.5], ["lobby_boss"])
	_ceiling()


func _office_furniture() -> void:
	var grey := Color("c9ced6")
	var blue := Color("4f6d9a")
	# --- open office: two rows of cubicles with low partitions ---
	for x in [-6.5, -3.5, -0.5]:
		for z in [-4.5, -1.5]:
			U.solid(self, Vector3(1.6, 0.06, 0.8), Vector3(x, 0.75, z), Color("e9dcc3"))
			U.invisible_wall(self, Vector3(1.5, 0.72, 0.7), Vector3(x, 0.36, z))
			U.box(Vector3(0.55, 0.35, 0.05), Color("1d1d22"), Vector3(x, 1.0, z - 0.25), self)
			U.solid(self, Vector3(1.7, 1.25, 0.08), Vector3(x, 0.62, z - 0.48), Color("7a8fb0"))
			_prop("chair", Vector3(0.45, 0.8, 0.45), Vector3(x + 0.2, 0.45, z + 0.75), blue, 3.0)
	_cupboard("file_cabinet", Vector3(0.9, 1.3, 0.6), Vector3(2.4, 0, -5.6), 0.0, grey, Color("aab4c2"))
	_cupboard("supply_closet", Vector3(1.0, 2.0, 0.6), Vector3(-7.4, 0, -5.6), 0.0, Color("a0785a"), Color("c49a74"))
	_plant("plant_a", Vector3(2.4, 0, 0.4))
	_prop("trash_bag", Vector3(0.5, 0.6, 0.5), Vector3(-7.4, 0.35, 0.3), Color("2f3a33"), 2.0)
	_prop("box", Vector3(0.5, 0.4, 0.5), Vector3(1.6, 0.25, -5.4), Color("d4a373"), 1.5)
	# --- break room ---
	_cupboard("fridge", Vector3(0.9, 1.9, 0.75), Vector3(7.45, 0, -5.5), 0.0, Color("e9eef2"), Color("dfe7ee"))
	U.solid(self, Vector3(2.6, 0.92, 0.7), Vector3(5.6, 0.46, -5.6), Color("c9d6df"))
	U.box(Vector3(2.65, 0.06, 0.75), Color("f7f7f7"), Vector3(5.6, 0.95, -5.58), self)
	_spot("counter", Vector3(5.9, 0.95, -5.1), 1.3)
	U.box(Vector3(0.4, 0.45, 0.35), Color("3a3a3a"), Vector3(4.8, 1.2, -5.6), self)
	U.cyl(0.06, 0.1, Color("ffffff"), Vector3(4.8, 1.03, -5.35), self)
	_spot("coffee_machine", Vector3(4.8, 1.0, -5.1), 1.3)
	_cupboard("coffee_cabinet", Vector3(0.9, 0.92, 0.7), Vector3(3.65, 0, -5.6), 0.0, Color("c9d6df"), Color("8fb3c9"))
	U.solid(self, Vector3(2.6, 0.45, 0.9), Vector3(5.5, 0.22, -2.0), Color("e07a5f"))
	U.solid(self, Vector3(2.6, 0.5, 0.25), Vector3(5.5, 0.7, -1.6), Color("c8634a"))
	_spot("remote_spot", Vector3(5.5, 0.5, -2.3), 1.4)
	U.box(Vector3(0.12, 0.05, 0.3), Color("222222"), Vector3(5.6, 0.47, -2.1), self)
	_cupboard("tv_stand", Vector3(2.0, 0.55, 0.5), Vector3(5.5, 0, -3.6), 0.0, C_DARK_WOOD, C_WOOD)
	U.box(Vector3(1.7, 0.95, 0.08), Color("1d1d22"), Vector3(5.5, 1.05, -3.7), self)
	_prop("cushion", Vector3(0.55, 0.2, 0.55), Vector3(4.6, 0.6, -2.1), Color("ffd166"), 0.6)
	# --- meeting room ---
	U.solid(self, Vector3(2.6, 0.08, 1.2), Vector3(5.5, 0.76, 3.2), Color("6d4c41"))
	U.invisible_wall(self, Vector3(2.5, 0.72, 1.1), Vector3(5.5, 0.36, 3.2))
	for cx in [4.6, 5.5, 6.4]:
		_prop("chair", Vector3(0.45, 0.8, 0.45), Vector3(cx, 0.45, 2.2), blue, 3.0)
	U.box(Vector3(0.06, 1.0, 2.0), Color.WHITE, Vector3(7.88, 1.3, 3.2), self)
	U.box(Vector3(0.07, 0.06, 2.05), Color("888888"), Vector3(7.88, 0.78, 3.2), self)
	_spot("whiteboard", Vector3(7.3, 0.0, 3.2), 1.3)
	# --- boss office ---
	U.solid(self, Vector3(2.2, 0.8, 0.9), Vector3(-5.5, 0.4, 4.6), C_DARK_WOOD)
	_spot("boss_desk", Vector3(-5.5, 0.8, 3.9), 1.4)
	U.box(Vector3(0.7, 0.9, 0.7), Color("2b2d42"), Vector3(-5.5, 0.45, 5.4), self)
	_cupboard("boss_drawer", Vector3(0.9, 0.8, 0.5), Vector3(-7.5, 0, 3.3), PI / 2.0, C_DARK_WOOD, C_WOOD)
	_cupboard("fish_food", Vector3(0.8, 0.9, 0.45), Vector3(-6.0, 0, 5.7), PI, C_WOOD, C_DARK_WOOD)
	U.solid(self, Vector3(1.0, 0.5, 0.5), Vector3(-3.8, 0.25, 1.5), C_DARK_WOOD)
	U.box(Vector3(1.0, 0.6, 0.5), Color(0.4, 0.75, 1.0, 0.55), Vector3(-3.8, 0.8, 1.5), self)
	U.sphere(0.08, Color("ff8c00"), Vector3(-3.9, 0.8, 1.5), self, 8)
	_spot("aquarium", Vector3(-3.8, 0.0, 2.3), 1.2)
	_plant("plant_b", Vector3(-7.4, 0, 1.6))
	# --- lobby ---
	U.solid(self, Vector3(0.9, 1.1, 0.7), Vector3(2.3, 0.55, 5.5), Color("d9d9d9"))
	U.box(Vector3(0.7, 0.08, 0.5), Color("555555"), Vector3(2.3, 1.12, 5.5), self)
	_spot("copier", Vector3(2.3, 0.0, 4.7), 1.3)
	_prop("report", Vector3(0.35, 0.08, 0.45), Vector3(1.3, 0.85, 2.0), Color.WHITE, 0.4)
	U.solid(self, Vector3(1.6, 0.8, 0.6), Vector3(1.2, 0.4, 2.0), Color("8d6e63"))
	_cat(Vector3(-2.4, 0, 5.3))


# ------------------------------------------------------------------ school map

func _school_walls() -> void:
	_wall_x(-6.0, -8.0, 8.0, [])
	_wall_x(6.0, -8.0, 8.0, [-1.0], ["front"])
	_wall_x(0.0, -8.0, 8.0, [-2.0, 1.5], ["corridor_class", "corridor_gym"])
	_wall_z(-8.0, -6.0, 6.0, [])
	_wall_z(8.0, -6.0, 6.0, [])
	_wall_z(0.0, -6.0, 0.0, [-3.0], ["class_gym"])
	_wall_z(-3.0, 0.0, 6.0, [3.0], ["corridor_teachers"])
	_wall_z(3.0, 0.0, 6.0, [3.0], ["corridor_cafe"])
	_ceiling()


func _school_furniture() -> void:
	var green := Color("2f4f3a")
	# --- classroom: blackboard, teacher's desk, rows of little desks ---
	U.box(Vector3(2.8, 1.1, 0.06), Color("8b5a3c"), Vector3(-4.5, 1.5, -5.87), self)
	U.box(Vector3(2.6, 0.95, 0.07), green, Vector3(-4.5, 1.5, -5.85), self)
	U.box(Vector3(0.9, 0.04, 0.05), Color.WHITE, Vector3(-4.9, 1.75, -5.81), self)  # chalk scribble
	U.box(Vector3(0.6, 0.04, 0.05), Color.WHITE, Vector3(-4.1, 1.45, -5.81), self)
	_spot("blackboard", Vector3(-4.5, 0.0, -5.1), 1.3)
	U.solid(self, Vector3(1.6, 0.8, 0.8), Vector3(-1.4, 0.4, -4.9), C_DARK_WOOD)
	U.box(Vector3(0.25, 0.2, 0.25), Color("e63946"), Vector3(-1.0, 0.9, -4.9), self)  # apple for the teacher
	_spot("teacher_desk", Vector3(-1.4, 0.8, -4.1), 1.4)
	for x in [-6.2, -4.6, -3.0]:
		for z in [-3.4, -1.9]:
			U.solid(self, Vector3(0.9, 0.06, 0.6), Vector3(x, 0.7, z), Color("e9dcc3"))
			U.invisible_wall(self, Vector3(0.85, 0.66, 0.55), Vector3(x, 0.33, z))
			_prop("chair", Vector3(0.4, 0.75, 0.4), Vector3(x, 0.42, z + 0.55), Color("4f8fc0"), 3.0)
	# --- gym: hoop, mats, the basketball ---
	for lx in [2.0, 6.0]:
		U.box(Vector3(0.06, 0.05, 5.6), Color.WHITE, Vector3(lx, 0.03, -3.0), self)
	U.solid(self, Vector3(0.15, 2.6, 0.15), Vector3(7.85, 1.3, -3.0), Color("555555"))
	U.box(Vector3(0.06, 0.75, 1.1), Color.WHITE, Vector3(7.75, 2.3, -3.0), self)
	U.cyl(0.25, 0.04, Color("ff6d00"), Vector3(7.45, 2.05, -3.0), self)
	_spot("hoop", Vector3(7.0, 0.0, -3.0), 1.4)
	_prop("basketball", Vector3(0.3, 0.3, 0.3), Vector3(2.5, 0.3, -1.4), Color("ff7f2a"), 0.4, "ball")
	U.box(Vector3(2.0, 0.15, 1.2), Color("3f6fd8"), Vector3(3.6, 0.07, -5.1), self)
	_spot("gym_mat", Vector3(3.6, 0.15, -5.1), 1.4)
	U.solid(self, Vector3(2.0, 0.45, 0.4), Vector3(5.6, 0.22, -0.5), C_WOOD)
	_prop("ball", Vector3(0.25, 0.25, 0.25), Vector3(5.2, 0.7, -0.5), Color("ffffff"), 0.3, "ball")
	# --- teachers' lounge: coffee + copier ---
	U.solid(self, Vector3(0.7, 0.92, 1.4), Vector3(-7.6, 0.46, 1.6), Color("c9d6df"))
	U.box(Vector3(0.35, 0.45, 0.4), Color("3a3a3a"), Vector3(-7.6, 1.2, 1.3), self)
	_spot("coffee_machine", Vector3(-7.0, 1.0, 1.3), 1.3)
	_cupboard("coffee_cabinet", Vector3(0.9, 0.92, 0.7), Vector3(-7.6, 0, 3.0), PI / 2.0, Color("c9d6df"), Color("8fb3c9"))
	U.solid(self, Vector3(0.9, 1.1, 0.7), Vector3(-4.0, 0.55, 5.55), Color("d9d9d9"))
	U.box(Vector3(0.7, 0.08, 0.5), Color("555555"), Vector3(-4.0, 1.12, 5.55), self)
	_spot("copier", Vector3(-4.0, 0.0, 4.75), 1.3)
	U.solid(self, Vector3(1.2, 0.08, 0.8), Vector3(-5.6, 0.76, 3.6), C_WOOD)
	U.invisible_wall(self, Vector3(1.1, 0.72, 0.7), Vector3(-5.6, 0.36, 3.6))
	_prop("cushion", Vector3(0.5, 0.2, 0.5), Vector3(-5.6, 0.95, 3.6), Color("ffd166"), 0.6)
	_plant("plant_a", Vector3(-7.4, 0, 5.4))
	# --- corridor: lockers, homework, bin bag ---
	_cupboard("school_locker", Vector3(0.9, 1.9, 0.5), Vector3(-2.65, 0, 1.1), PI / 2.0, Color("3f8f6f"), Color("5fbf8f"))
	for z in [4.6, 5.4]:
		U.solid(self, Vector3(0.5, 1.9, 0.75), Vector3(-2.65, 0.95, z), Color("5fbf8f"))
		U.solid(self, Vector3(0.5, 1.9, 0.75), Vector3(2.65, 0.95, z), Color("e07a5f"))
	U.solid(self, Vector3(0.45, 0.45, 1.2), Vector3(2.55, 0.22, 1.0), C_WOOD)
	_prop("homework", Vector3(0.35, 0.08, 0.45), Vector3(2.55, 0.55, 1.0), Color("f5f0dc"), 0.4)
	_prop("trash_bag", Vector3(0.5, 0.6, 0.5), Vector3(-2.0, 0.35, 5.5), Color("2f3a33"), 2.0)
	# --- cafeteria: fridge, serving counter, long tables ---
	_cupboard("fridge", Vector3(0.9, 1.9, 0.75), Vector3(7.45, 0, 0.6), -PI / 2.0, Color("e9eef2"), Color("dfe7ee"))
	U.solid(self, Vector3(0.7, 0.92, 2.4), Vector3(7.6, 0.46, 2.8), Color("c9d6df"))
	U.box(Vector3(0.75, 0.06, 2.45), Color("f7f7f7"), Vector3(7.6, 0.95, 2.8), self)
	_spot("counter", Vector3(7.0, 0.95, 2.8), 1.3)
	for z in [1.8, 4.4]:
		U.solid(self, Vector3(2.2, 0.08, 0.9), Vector3(5.0, 0.76, z), Color("e07a5f"))
		U.invisible_wall(self, Vector3(2.1, 0.72, 0.8), Vector3(5.0, 0.36, z))
		_prop("chair", Vector3(0.4, 0.75, 0.4), Vector3(4.4, 0.42, z + 0.75), Color("ffd166"), 3.0)
	_plant("plant_b", Vector3(7.4, 0, 5.4))
	_cat(Vector3(4.0, 0, 5.4))


# ------------------------------------------------------------------ wedding hall map

func _wedding_walls() -> void:
	_wall_x(-6.0, -8.0, 8.0, [])
	_wall_x(6.0, -8.0, 8.0, [-1.0], ["front"])
	_wall_x(1.0, -8.0, 3.0, [-1.0], ["banquet_foyer"])
	_wall_x(0.0, 3.0, 8.0, [5.5], ["kitchen_bride"])
	_wall_z(-8.0, -6.0, 6.0, [])
	_wall_z(8.0, -6.0, 6.0, [])
	_wall_z(3.0, -6.0, 6.0, [-3.0, 3.0], ["banquet_kitchen", "foyer_bride"])
	_wall_z(-3.0, 1.0, 6.0, [3.5], ["foyer_restroom"])
	_ceiling()


func _round_table(pos: Vector3, cloth: Color) -> void:
	U.cyl(0.62, 0.06, cloth, pos + Vector3(0, 0.76, 0), self)
	U.cyl(0.63, 0.5, cloth, pos + Vector3(0, 0.5, 0), self)
	U.invisible_wall(self, Vector3(1.0, 0.74, 1.0), pos + Vector3(0, 0.37, 0))
	U.cyl(0.07, 0.25, Color("f7f7f7"), pos + Vector3(0, 0.92, 0), self)
	U.sphere(0.13, Color("ff8fab"), pos + Vector3(0, 1.1, 0), self)
	for k in 2:
		var off := Vector3(0.95, 0, 0) if k == 0 else Vector3(-0.95, 0, 0)
		_prop("chair", Vector3(0.42, 0.85, 0.42), pos + off + Vector3(0, 0.45, 0), Color("f0e6d2"), 3.0)


func _wedding_furniture() -> void:
	var gold := Color("e0b84f")
	# --- banquet hall: head table, cake, dance floor + disco ball, DJ ---
	U.solid(self, Vector3(3.0, 0.08, 0.8), Vector3(-5.5, 0.78, -5.4), Color.WHITE)
	U.solid(self, Vector3(3.0, 0.74, 0.75), Vector3(-5.5, 0.37, -5.4), Color("f4ecf7"))
	U.box(Vector3(3.0, 0.12, 0.05), gold, Vector3(-5.5, 0.6, -5.0), self)
	_spot("head_table", Vector3(-5.5, 0.8, -4.6), 1.4)
	U.cyl(0.45, 0.76, Color.WHITE, Vector3(0.6, 0.38, -5.2), self)
	U.invisible_wall(self, Vector3(0.8, 0.76, 0.8), Vector3(0.6, 0.38, -5.2))
	U.cyl(0.32, 0.22, Color("fff3e0"), Vector3(0.6, 0.87, -5.2), self)
	U.cyl(0.24, 0.2, Color("fff3e0"), Vector3(0.6, 1.08, -5.2), self)
	U.cyl(0.16, 0.18, Color("fff3e0"), Vector3(0.6, 1.27, -5.2), self)
	U.sphere(0.07, Color("e63946"), Vector3(0.6, 1.4, -5.2), self)
	_spot("wedding_cake", Vector3(0.6, 0.8, -4.5), 1.3)
	var tiles := [Color("ff4d6d"), Color("4cc9f0"), Color("ffd166"), Color("9b5de5")]
	for i in 16:
		U.box(Vector3(0.78, 0.05, 0.78), tiles[(i + i / 4) % 4], Vector3(-3.2 + (i % 4) * 0.8, 0.0, -3.2 + (i / 4) * 0.8), self)
	_spot("dance_floor", Vector3(-2.0, 0.0, -2.0), 1.6)
	U.box(Vector3(0.02, 0.4, 0.02), Color("888888"), Vector3(-2.0, 2.4, -2.0), self)
	var disco := U.sphere(0.25, Color("dfe6ee"), Vector3(-2.0, 2.1, -2.0), self)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color("dfe6ee")
	dm.metallic = 0.9
	dm.roughness = 0.15
	disco.material_override = dm
	U.solid(self, Vector3(0.6, 1.0, 1.4), Vector3(2.55, 0.5, -0.6), Color("2b2d42"))
	U.box(Vector3(0.5, 0.06, 0.4), Color("4cc9f0"), Vector3(2.5, 1.03, -0.8), self)
	U.solid(self, Vector3(0.45, 1.1, 0.45), Vector3(2.6, 0.55, -1.8), Color("1d1d22"))
	_spot("dj_booth", Vector3(1.9, 0.0, -0.6), 1.3)
	_round_table(Vector3(-6.6, 0, -2.6), Color.WHITE)
	_round_table(Vector3(-6.6, 0, -0.2), Color("fde2e4"))
	# --- kitchen ---
	_cupboard("fridge", Vector3(0.9, 1.9, 0.75), Vector3(7.45, 0, -5.5), 0.0, Color("e9eef2"), Color("dfe7ee"))
	U.solid(self, Vector3(2.6, 0.92, 0.7), Vector3(5.6, 0.46, -5.6), Color("c9d6df"))
	U.box(Vector3(2.65, 0.06, 0.75), Color("f7f7f7"), Vector3(5.6, 0.95, -5.58), self)
	_spot("counter", Vector3(5.9, 0.95, -5.1), 1.3)
	_cupboard("drinks_cooler", Vector3(0.9, 0.92, 0.7), Vector3(3.65, 0, -5.6), 0.0, Color("c9d6df"), Color("8fb3c9"))
	U.solid(self, Vector3(1.4, 0.9, 0.7), Vector3(5.6, 0.45, -2.6), Color("b0bec5"))
	for k in 3:
		U.cyl(0.12, 0.18, Color("fff3e0"), Vector3(5.1 + k * 0.5, 0.99, -2.6), self)
	_prop("trash_bag", Vector3(0.5, 0.6, 0.5), Vector3(7.4, 0.35, -0.6), Color("2f3a33"), 2.0)
	# --- bride's room ---
	U.solid(self, Vector3(0.5, 0.8, 1.2), Vector3(7.65, 0.4, 3.2), Color("f6f0e6"))
	U.box(Vector3(0.05, 1.3, 0.9), Color(0.8, 0.92, 1.0), Vector3(7.88, 1.5, 3.2), self)
	U.box(Vector3(0.06, 1.42, 1.02), gold, Vector3(7.9, 1.5, 3.2), self)
	_spot("bride_mirror", Vector3(7.0, 0.8, 3.2), 1.4)
	U.solid(self, Vector3(2.0, 0.45, 0.8), Vector3(5.6, 0.22, 5.5), Color("ff8fab"))
	U.solid(self, Vector3(2.0, 0.5, 0.2), Vector3(5.6, 0.7, 5.85), Color("f26b8f"))
	U.cyl(0.32, 1.1, Color.WHITE, Vector3(4.0, 0.55, 5.3), self, 0.12)  # wedding dress on a stand
	U.sphere(0.16, Color.WHITE, Vector3(4.0, 1.2, 5.3), self)
	_cupboard("wardrobe", Vector3(1.4, 2.0, 0.6), Vector3(7.5, 0, 1.0), -PI / 2.0, Color("a0785a"), Color("c49a74"))
	_plant("plant_b", Vector3(7.4, 0, 5.4))
	# --- foyer: gift table, bouquet, welcome sign ---
	U.solid(self, Vector3(1.2, 0.8, 0.6), Vector3(2.2, 0.4, 5.5), Color.WHITE)
	for k in 3:
		U.box(Vector3(0.28, 0.24, 0.28), [Color("4cc9f0"), Color("ffd166"), Color("ff4d6d")][k], Vector3(1.8 + k * 0.38, 0.93, 5.6), self)
	_prop("bouquet", Vector3(0.3, 0.3, 0.3), Vector3(-2.2, 0.95, 1.7), Color("ff8fab"), 0.4, "ball")
	U.solid(self, Vector3(0.9, 0.8, 0.5), Vector3(-2.2, 0.4, 1.7), C_WOOD)
	U.box(Vector3(0.8, 1.0, 0.05), Color("fff3e0"), Vector3(1.2, 1.1, 1.25), self)
	U.box(Vector3(0.6, 0.06, 0.06), gold, Vector3(1.2, 1.3, 1.22), self)
	_plant("plant_a", Vector3(-2.4, 0, 5.4))
	_cat(Vector3(0.8, 0, 5.3))
	# --- restroom ---
	U.solid(self, Vector3(0.6, 0.9, 2.2), Vector3(-7.65, 0.45, 2.6), Color("e0e0e0"))
	U.box(Vector3(0.05, 0.8, 2.0), Color(0.8, 0.92, 1.0), Vector3(-7.88, 1.5, 2.6), self)
	for x in [-6.6, -5.2]:
		U.solid(self, Vector3(0.08, 1.8, 1.4), Vector3(x, 0.9, 5.3), Color("9fb3c8"))
	_cupboard("towel_cabinet", Vector3(0.9, 1.2, 0.5), Vector3(-4.0, 0, 1.4), 0.0, C_WHITE, Color("9fd3dc"))


# ------------------------------------------------------------------ mansion map (large)

func _mansion_walls() -> void:
	_wall_x(-10.0, -12.0, 12.0, [])
	_wall_x(6.0, -12.0, 12.0, [-1.0], ["front"])
	_wall_x(-3.0, -12.0, 12.0, [-5.0, -2.0, 2.0, 5.0], ["hall_kitchen", "hall_dining", "living_dining", "living_library"])
	_wall_z(-12.0, -10.0, 6.0, [])
	_wall_z(12.0, -10.0, 6.0, [])
	_wall_z(-4.0, -10.0, -3.0, [-6.5], ["kitchen_dining"])
	_wall_z(4.0, -10.0, -3.0, [-6.5], ["dining_library"])
	_wall_z(-6.0, -3.0, 6.0, [1.5], ["bath_hall"])
	_wall_z(0.0, -3.0, 6.0, [1.5], ["hall_living"])
	_wall_z(6.0, -3.0, 6.0, [1.5], ["living_bed"])
	_ceiling()


func _mansion_furniture() -> void:
	# kitchen
	_cupboard("fridge", Vector3(0.9, 1.9, 0.75), Vector3(-11.35, 0, -9.5), 0.0, Color("e9eef2"), Color("dfe7ee"))
	U.solid(self, Vector3(2.8, 0.92, 0.7), Vector3(-9.3, 0.46, -9.6), Color("c9d6df"))
	U.box(Vector3(2.85, 0.06, 0.75), Color("f7f7f7"), Vector3(-9.3, 0.95, -9.58), self)
	_spot("counter", Vector3(-9.3, 0.95, -9.1), 1.3)
	_cupboard("cat_cabinet", Vector3(1.0, 0.92, 0.7), Vector3(-7.3, 0, -9.6), 0.0, Color("c9d6df"), Color("8fb3c9"))
	_cupboard("kitchen_drawer", Vector3(1.0, 0.92, 0.7), Vector3(-6.2, 0, -9.6), 0.0, Color("c9d6df"), Color("8fb3c9"))
	U.solid(self, Vector3(1.6, 0.08, 1.0), Vector3(-9.0, 0.78, -6.2), C_WOOD)
	U.invisible_wall(self, Vector3(1.5, 0.74, 0.9), Vector3(-9.0, 0.37, -6.2))
	_prop("chair", Vector3(0.45, 0.9, 0.45), Vector3(-9.0, 0.5, -5.2), Color("e8a45c"), 3.0)
	_prop("trash_bag", Vector3(0.5, 0.6, 0.5), Vector3(-11.3, 0.35, -4.0), Color("2f3a33"), 2.0)
	# dining room
	U.solid(self, Vector3(4.0, 0.08, 1.4), Vector3(0, 0.78, -6.5), C_DARK_WOOD)
	U.invisible_wall(self, Vector3(3.9, 0.74, 1.3), Vector3(0, 0.37, -6.5))
	for cx in [-1.4, 0.0, 1.4]:
		_prop("chair", Vector3(0.45, 0.9, 0.45), Vector3(cx, 0.5, -5.4), Color("a0785a"), 3.0)
	for k in 3:
		U.cyl(0.18, 0.02, Color.WHITE, Vector3(-1.2 + k * 1.2, 0.83, -6.5), self)
	_spot("dining_table", Vector3(0, 0.8, -5.6), 1.5)
	_cupboard("china", Vector3(1.6, 1.8, 0.5), Vector3(0, 0, -9.65), 0.0, Color("8d6e63"), Color("d7ccc8"))
	# library
	_cupboard("bookcase", Vector3(2.0, 2.0, 0.5), Vector3(8.0, 0, -9.65), 0.0, Color("5d4037"), Color("8d6e63"))
	for k in 6:
		U.box(Vector3(0.12, 0.35, 0.3), Color.from_hsv(k * 0.15, 0.6, 0.8), Vector3(7.3 + k * 0.28, 2.15, -9.65), self)
	_spot("library_shelf", Vector3(8.0, 0.0, -9.0), 1.5)
	U.solid(self, Vector3(2.4, 0.9, 1.3), Vector3(8.5, 0.45, -6.0), Color("2e7d32"))
	U.solid(self, Vector3(1.0, 0.5, 1.0), Vector3(5.2, 0.25, -4.2), Color("6d4c41"))
	_plant("plant_a", Vector3(11.3, 0, -9.3))
	_prop("ball", Vector3(0.25, 0.25, 0.25), Vector3(8.2, 1.1, -6.0), Color("ffffff"), 0.3, "ball")
	# bathroom
	U.box(Vector3(1.4, 0.08, 1.4), Color("ffffff"), Vector3(-11.2, 0.04, 5.2), self)
	U.box(Vector3(0.04, 2.0, 1.4), Color(0.7, 0.9, 1.0, 0.35), Vector3(-10.5, 1.0, 5.2), self)
	_spot("shower", Vector3(-11.2, 0.0, 5.2), 1.0)
	U.solid(self, Vector3(0.5, 0.45, 0.65), Vector3(-7.0, 0.22, 5.55), C_WHITE)
	_cupboard("bath_cabinet", Vector3(1.1, 0.85, 0.55), Vector3(-9.5, 0, -2.6), 0.0, C_WHITE, Color("9fd3dc"))
	_prop("laundry", Vector3(0.6, 0.45, 0.45), Vector3(-11.2, 0.3, -1.6), Color("d9b38c"), 1.5)
	# hall
	_spot("cat_bowl", Vector3(-1.0, 0.0, -2.0), 1.3)
	U.cyl(0.2, 0.08, Color("e63946"), Vector3(-1.0, 0.04, -2.0), self, 0.24)
	_cat(Vector3(-0.7, 0, -2.5))
	_cupboard("hall_cabinet", Vector3(1.0, 0.9, 0.45), Vector3(-4.5, 0, 5.65), PI, C_DARK_WOOD, C_WOOD)
	U.box(Vector3(1.4, 0.05, 5.0), Color("6a8fd8"), Vector3(-3.0, 0.0, 2.0), self)
	# living room
	_cupboard("tv_stand", Vector3(2.0, 0.55, 0.5), Vector3(3.0, 0, -2.6), 0.0, C_DARK_WOOD, C_WOOD)
	U.box(Vector3(1.7, 0.95, 0.08), Color("1d1d22"), Vector3(3.0, 1.05, -2.75), self)
	U.solid(self, Vector3(2.6, 0.45, 0.95), Vector3(3.0, 0.22, 1.6), Color("5b7fc4"))
	U.solid(self, Vector3(2.6, 0.55, 0.25), Vector3(3.0, 0.72, 2.0), Color("4d6db0"))
	_spot("remote_spot", Vector3(3.0, 0.5, 1.3), 1.4)
	U.box(Vector3(0.12, 0.05, 0.3), Color("222222"), Vector3(3.1, 0.48, 1.4), self)
	U.solid(self, Vector3(1.3, 0.42, 0.7), Vector3(3.0, 0.21, -0.6), C_WOOD)
	_prop("cushion", Vector3(0.55, 0.2, 0.55), Vector3(2.2, 0.6, 1.5), Color("ffd166"), 0.6)
	_plant("plant_b", Vector3(5.4, 0, 5.4))
	# bedroom
	U.solid(self, Vector3(2.3, 0.45, 1.6), Vector3(10.8, 0.22, 2.5), C_DARK_WOOD)
	U.box(Vector3(2.0, 0.18, 1.55), Color("f4f1ea"), Vector3(10.65, 0.53, 2.5), self)
	_spot("bed", Vector3(10.8, 0.5, 2.5), 1.9)
	_cupboard("wardrobe", Vector3(1.5, 2.0, 0.6), Vector3(8.0, 0, -2.6), 0.0, Color("a0785a"), Color("c49a74"))
	_cupboard("nightstand", Vector3(0.55, 0.55, 0.5), Vector3(11.5, 0, 5.6), PI, C_DARK_WOOD, C_WOOD)


# ------------------------------------------------------------------ custom items (map editor)

## type -> [size, color, movable prop?]
const ITEM_TYPES := {
	"crate": [Vector3(0.8, 0.8, 0.8), Color("d4a373"), true],
	"big_crate": [Vector3(1.3, 1.3, 1.3), Color("b5835a"), false],
	"table": [Vector3(1.6, 0.8, 0.9), Color("c8955f"), false],
	"sofa": [Vector3(2.2, 0.8, 0.9), Color("e07a5f"), false],
	"shelf": [Vector3(1.4, 1.8, 0.5), Color("8b5a3c"), false],
	"wall": [Vector3(2.0, 2.2, 0.2), Color("f6efe3"), false],
	"ramp": [Vector3(1.2, 0.15, 2.6), Color("9fb3c8"), false],
	"plant": [Vector3(0.5, 1.2, 0.5), Color("3fa34d"), false],
	"ball": [Vector3(0.9, 0.9, 0.9), Color("ff4d6d"), true],
	"chair": [Vector3(0.45, 0.9, 0.45), Color("e8a45c"), true],
}
const MAX_ITEMS := 120


## Network / file input: keep known types, finite numbers, inside the house, capped count.
static func sanitize_items(items, rect: Rect2) -> Array:
	var out := []
	if not (items is Array):
		return out
	for it in items:
		if out.size() >= MAX_ITEMS:
			break
		if not (it is Array) or it.size() != 4 or not ITEM_TYPES.has(str(it[0])):
			continue
		var x := float(it[1])
		var z := float(it[2])
		var yaw := float(it[3])
		if not (is_finite(x) and is_finite(z) and is_finite(yaw)) or not rect.grow(-0.3).has_point(Vector2(x, z)):
			continue
		out.append([str(it[0]), x, z, fposmod(yaw, TAU)])
	return out


## Builds one editor item (static furniture or a movable prop). Returns the root node.
func build_item(type: String, pos: Vector3, yaw: float) -> Node3D:
	var d: Array = ITEM_TYPES[type]
	var size: Vector3 = d[0]
	var c: Color = d[1]
	if d[2]:
		var p := _prop(type, size, pos + Vector3(0, size.y / 2.0 + 0.05, 0), c, 2.0, "ball" if type == "ball" else "box")
		p.rotation.y = yaw
		p.home = p.transform
		return p
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	add_child(root)
	match type:
		"ramp":
			var sb := U.solid(root, size, Vector3(0, 0.45, 0), c)
			sb.rotation.x = -0.36
		"plant":
			U.solid(root, Vector3(0.45, 0.45, 0.45), Vector3(0, 0.22, 0), Color("c46b3e"))
			U.sphere(0.42, c, Vector3(0, 0.78, 0), root)
		"table":
			U.solid(root, Vector3(size.x, 0.08, size.z), Vector3(0, 0.78, 0), c)
			U.invisible_wall(root, Vector3(size.x - 0.1, 0.74, size.z - 0.1), Vector3(0, 0.37, 0))
		_:
			U.solid(root, size, Vector3(0, size.y / 2.0, 0), c)
	return root
