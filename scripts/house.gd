class_name House
extends Node3D
## Builds the single-story house + garden from code. Deterministic, so every peer builds the same thing.
## Coordinates: X east, Z south. Camera looks north (-Z). House interior x -8..8, z -6..6; garden south.

const H := 2.6
const T := 0.2
const DOOR_W := 1.3
const DOOR_H := 2.15
const RECT := Rect2(-8, -6, 16, 12)
const GARDEN := Rect2(-11, 6, 22, 10)

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


func build() -> void:
	_floors()
	_walls()
	_furniture()
	_garden()
	_roof()
	_nav()
	_front_block = U.invisible_wall(self, Vector3(DOOR_W + 0.2, 3.0, 0.3), Vector3(-1.0, 1.5, 6.0))
	for i in 8:
		spawn_garden.append(Vector3(-4.5 + (i % 4) * 2.0, 0.8, 10.5 + (i / 4) * 1.8))
		spawn_house.append(Vector3(-2.2 + (i % 4) * 0.9, 0.8, 2.2 + (i / 4) * 1.6))


func set_front_locked(l: bool) -> void:
	if _front_block:
		_front_block.collision_layer = U.L_WORLD if l else 0


func room_of(p: Vector3) -> String:
	for r in ["kitchen", "living", "bath", "hall", "bed"]:
		if rooms[r].has_point(Vector2(p.x, p.z)):
			return r
	return "garden" if GARDEN.grow(2.0).has_point(Vector2(p.x, p.z)) else "out"


func inside(p: Vector3, margin := 0.0) -> bool:
	return RECT.grow(-margin).has_point(Vector2(p.x, p.z))


# ------------------------------------------------------------------ floors

func _floors() -> void:
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
	var cols := {"kitchen": Color("e6cf9f"), "living": Color("c08f5e"), "bath": Color("8fc9d6"),
		"hall": Color("bf9c78"), "bed": Color("b9a3dc")}
	for r in cols:
		var rc: Rect2 = rooms[r]
		U.box(Vector3(rc.size.x, 0.04, rc.size.y), cols[r], Vector3(rc.get_center().x, 0.0, rc.get_center().y), self)
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
	U.invisible_wall(self, Vector3(16.4, 0.4, 12.4), Vector3(0, 3.1, 0))


func _wall_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = C_WALL
	m.roughness = 0.9
	return m


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
	for s in _segments(x0 - T / 2.0, x1 + T / 2.0, door_xs):
		var l: float = s[1] - s[0]
		if l > 0.01:
			_wall_piece(Vector3(l, H, T), Vector3((s[0] + s[1]) / 2.0, H / 2.0, z), m, nodes)
	for i in door_xs.size():
		_wall_piece(Vector3(DOOR_W, H - DOOR_H, T), Vector3(door_xs[i], (H + DOOR_H) / 2.0, z), m, nodes)
		if i < names.size():
			_door(names[i], Vector3(door_xs[i], 0, z), true)
	walls.append({"nodes": nodes, "mat": m, "x0": x0, "x1": x1, "z": z, "a": 1.0})


func _wall_z(x: float, z0: float, z1: float, door_zs: Array, names: Array = []) -> void:
	var m := _wall_mat()
	var nodes := []
	for s in _segments(z0 + T / 2.0, z1 - T / 2.0, door_zs):
		var l: float = s[1] - s[0]
		if l > 0.01:
			_wall_piece(Vector3(T, H, l), Vector3(x, H / 2.0, (s[0] + s[1]) / 2.0), m, nodes)
	for i in door_zs.size():
		_wall_piece(Vector3(T, H - DOOR_H, DOOR_W), Vector3(x, (H + DOOR_H) / 2.0, door_zs[i]), m, nodes)
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
	_cupboard("bath_cabinet", Vector3(1.1, 0.85, 0.55), Vector3(-5.5, 0, 0.4), PI, C_WHITE, Color("9fd3dc"))
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
	_cupboard("wardrobe", Vector3(1.5, 2.0, 0.6), Vector3(2.4, 0, 0.4), PI, Color("a0785a"), Color("c49a74"))
	_cupboard("nightstand", Vector3(0.55, 0.55, 0.5), Vector3(7.5, 0, 5.6), PI, C_DARK_WOOD, C_WOOD)
	_plant("plant_b", Vector3(7.4, 0, 0.55))


func _plant(n: String, pos: Vector3) -> void:
	U.solid(self, Vector3(0.45, 0.45, 0.45), pos + Vector3(0, 0.22, 0), Color("c46b3e"))
	U.sphere(0.4, Color("3fa34d"), pos + Vector3(0, 0.75, 0), self)
	U.sphere(0.28, Color("58c45f"), pos + Vector3(0.15, 1.0, 0.1), self)
	_spot(n, pos, 1.3)


func _cat(pos: Vector3) -> void:
	var c := Node3D.new()
	c.position = pos
	c.name = "Cat"
	add_child(c)
	var col := Color("f4a259")
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
	U.invisible_wall(self, Vector3(3.2, 6, 0.3), Vector3(-9.6, 3, 6.0))
	U.invisible_wall(self, Vector3(3.2, 6, 0.3), Vector3(9.6, 3, 6.0))
	U.invisible_wall(self, Vector3(16.4, 2, 0.3), Vector3(0, 3.9, 6.0))
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
		var x := rng.randf_range(-10.3, 10.3)
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
	var a := U.box(Vector3(17.2, 0.25, 7.0), rc, Vector3(0, 3.55, -3.1), roof)
	a.rotation.x = 0.32
	var b := U.box(Vector3(17.2, 0.25, 7.0), rc, Vector3(0, 3.55, 3.1), roof)
	b.rotation.x = -0.32
	U.box(Vector3(17.4, 0.2, 0.4), Color("9e3f2b"), Vector3(0, 4.62, 0), roof)
	U.box(Vector3(0.6, 1.2, 0.6), Color("8d6e63"), Vector3(4.5, 4.6, -1.5), roof)


# ------------------------------------------------------------------ navigation (bots)

func _nav() -> void:
	var centers := {"kitchen": Vector3(-3.4, 0, -3.0), "living": Vector3(1.6, 0, -2.6),
		"bath": Vector3(-5.3, 0, 2.8), "hall": Vector3(-1.0, 0, 3.0), "bed": Vector3(3.6, 0, 2.6),
		"garden": Vector3(-1.0, 0, 9.5)}
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
