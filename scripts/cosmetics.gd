class_name Cosmetics
extends RefCounted
## Cosmetic catalog (hats, outfits, shoes, full skins), unlock rules and the code that dresses a bean.
## Unlock: "free" | "level:N" (XP level) | "ach:ID" (achievement) | "matches:N" (matches played)
##   | "steam:ITEMDEF" (bought in the Steam item store; several items sharing one def form a set).
## Item defs for Steam live in steam/itemdefs.json (upload in Steamworks > Inventory Service).

const SLOTS := ["hat", "outfit", "shoes", "skin", "hand", "eyes", "brows", "mouth"]

const ITEMS := {
	"hat_none": ["hat", "free"], "hat_party": ["hat", "free"], "hat_cap": ["hat", "free"],
	"hat_chef": ["hat", "level:2"], "hat_propeller": ["hat", "level:4"], "hat_horns": ["hat", "level:6"],
	"hat_crown": ["hat", "steam:101"],
	"outfit_none": ["outfit", "free"], "outfit_stripes": ["outfit", "free"], "outfit_overalls": ["outfit", "level:3"],
	"outfit_hoodie": ["outfit", "level:5"], "outfit_tuxedo": ["outfit", "steam:102"], "outfit_hero": ["outfit", "steam:103"],
	"shoes_default": ["shoes", "free"], "shoes_sneakers": ["shoes", "level:2"], "shoes_boots": ["shoes", "level:4"],
	"shoes_flippers": ["shoes", "level:7"], "shoes_gold": ["shoes", "steam:104"],
	"skin_none": ["skin", "free"], "skin_pumpkin": ["skin", "level:8"], "skin_ghost": ["skin", "level:10"],
	"skin_dino": ["skin", "steam:105"], "skin_robot": ["skin", "steam:106"],
	"hat_beanie": ["hat", "matches:3"], "hat_halo": ["hat", "ach:GHOSTLY"],
	"outfit_apron": ["outfit", "ach:CHORE_MASTER"], "skin_alien": ["skin", "matches:25"],
	"hand_none": ["hand", "free"], "hand_spatula": ["hand", "level:3"], "hand_duck": ["hand", "ach:FIRST_PRANK"],
	"hand_balloon": ["hand", "matches:5"], "hand_plunger": ["hand", "ach:CHAIN_3"],
	"eyes_round": ["eyes", "free"], "eyes_big": ["eyes", "free"], "eyes_sleepy": ["eyes", "free"],
	"eyes_tiny": ["eyes", "level:3"], "eyes_lashes": ["eyes", "ach:WINNER"],
	"brows_normal": ["brows", "free"], "brows_thick": ["brows", "free"], "brows_thin": ["brows", "free"],
	"brows_none": ["brows", "level:2"], "brows_uni": ["brows", "matches:10"],
	"mouth_line": ["mouth", "free"], "mouth_wide": ["mouth", "free"], "mouth_buck": ["mouth", "level:4"],
	"mouth_mustache": ["mouth", "ach:BOMB_SQUAD"], "mouth_tongue": ["mouth", "matches:15"],
	# Poseidon set: one purchase, four pieces
	"hat_poseidon": ["hat", "steam:107"], "outfit_poseidon": ["outfit", "steam:107"],
	"shoes_poseidon": ["shoes", "steam:107"], "hand_trident": ["hand", "steam:107"],
}

## Paid sets shown in the store (Steam item def -> name key); single paid items use their own name.
const SETS := {107: "set_poseidon"}

const DEFAULT := {"hat": "hat_party", "outfit": "outfit_none", "shoes": "shoes_default", "skin": "skin_none",
	"hand": "hand_none", "eyes": "eyes_round", "brows": "brows_normal", "mouth": "mouth_line"}


static func items_for(slot: String) -> Array:
	return ITEMS.keys().filter(func(k): return ITEMS[k][0] == slot)


static func unlock_of(id: String) -> String:
	return str(ITEMS[id][1]) if ITEMS.has(id) else "free"


static func steam_def(id: String) -> int:
	var u := unlock_of(id)
	return u.substr(6).to_int() if u.begins_with("steam:") else 0


## Can the local player use this item?
static func owned(id: String, level: int, steam_owned: Dictionary) -> bool:
	var u := unlock_of(id)
	if u == "free":
		return true
	if u.begins_with("level:"):
		return level >= u.substr(6).to_int()
	if u.begins_with("ach:"):
		var got = Config.settings.get("ach", {})
		return got is Dictionary and got.has(u.substr(4))
	if u.begins_with("matches:"):
		var c = Config.settings.get("counts", {})
		return c is Dictionary and int(c.get("matches", 0)) >= u.substr(8).to_int()
	return steam_owned.has(steam_def(id))


## Every paid Steam item def -> the item ids it unlocks (store screen).
static func store_defs() -> Dictionary:
	var out := {}
	for id in ITEMS:
		var d := steam_def(id)
		if d > 0:
			if not out.has(d):
				out[d] = []
			out[d].append(id)
	return out


## Network input: keep only known ids in the right slot.
static func sanitize(look) -> Dictionary:
	var out := DEFAULT.duplicate()
	if look is Dictionary:
		for slot in SLOTS:
			var id := str(look.get(slot, ""))
			if ITEMS.has(id) and ITEMS[id][0] == slot:
				out[slot] = id
	return out


static func random_look(rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	for slot in SLOTS:
		var free: Array = items_for(slot).filter(func(k): return unlock_of(k) == "free" or unlock_of(k).begins_with("level"))
		out[slot] = free[rng.randi() % free.size()] if not slot in ["skin", "hand"] or rng.randf() < 0.3 else DEFAULT[slot]
	return out


# ------------------------------------------------------------------ dressing

static func apply(a: Node, look: Dictionary) -> void:
	_skin(a, str(look.get("skin", "skin_none")))
	_hat(a, str(look.get("hat", "hat_none")))
	_outfit(a, str(look.get("outfit", "outfit_none")))
	_shoes(a, str(look.get("shoes", "shoes_default")))
	_hand(a, str(look.get("hand", "hand_none")))
	_eyes(a, str(look.get("eyes", "eyes_round")))
	_brows(a, str(look.get("brows", "brows_normal")))
	_mouth(a, str(look.get("mouth", "mouth_line")))


static func _skin(a: Node, id: String) -> void:
	var m: StandardMaterial3D = a._mat
	match id:
		"skin_dino":
			a.color = Color("4caf50")
			for k in 3:
				var sp := U.cyl(0.09, 0.18, Color("ffb703"), Vector3(0, 0.2 - k * 0.28, 0.33 + k * 0.02), a.body_root, 0.0)
				sp.rotation.x = 0.5
			var tail := U.capsule(0.11, 0.6, Color("4caf50"), Vector3(0, -0.55, 0.42), a.body_root)
			tail.rotation.x = 1.1
		"skin_robot":
			a.color = Color("9aa5b1")
			m.metallic = 0.7
			m.roughness = 0.3
			U.cyl(0.02, 0.25, Color("555555"), Vector3(0, 0.5, 0), a._head)
			U.sphere(0.06, Color("ff3b30"), Vector3(0, 0.64, 0), a._head, 8)
		"skin_ghost":
			a.color = Color(0.95, 0.95, 1.0)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			for f in a._feet:
				f.visible = false
		"skin_alien":
			a.color = Color("7ed957")
			for sx in [-1.0, 1.0]:
				var ant := U.cyl(0.018, 0.3, Color("4caf50"), Vector3(0.12 * sx, 0.5, 0), a._head)
				ant.rotation.z = -0.3 * sx
				U.sphere(0.05, Color("e9ff70"), Vector3(0.17 * sx, 0.65, 0), a._head, 8)
		"skin_pumpkin":
			a.color = Color("ff8c1a")
			U.cyl(0.04, 0.15, Color("3e7b27"), Vector3(0, 0.45, 0), a._head)
			for k in 3:
				U.box(Vector3(0.08, 0.06, 0.02), Color("2b1a00"), Vector3(-0.1 + k * 0.1, -0.12, -0.39), a._head)
		_:
			return
	m.albedo_color = Color(a.color, 0.55) if id == "skin_ghost" else a.color
	m.albedo_texture = null
	a._skin_mat.albedo_color = m.albedo_color
	a._skin_base = m.albedo_color
	if id == "skin_ghost":
		a._skin_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	a._hair.visible = false


static func _hat(a: Node, id: String) -> void:
	var h := Node3D.new()
	h.position = Vector3(0, 0.4, 0)
	a._head.add_child(h)
	match id:
		"hat_party":
			var c := U.cyl(0.14, 0.34, Color("ff4d6d"), Vector3(0, 0.12, 0), h, 0.0)
			c.rotation.z = 0.15
			U.sphere(0.05, Color("ffe14d"), Vector3(-0.03, 0.3, 0), h, 8)
		"hat_crown":
			U.cyl(0.2, 0.1, Color("ffd60a"), Vector3(0, 0.02, 0), h, 0.22)
			for k in 5:
				var ang := TAU * k / 5.0
				U.cyl(0.035, 0.1, Color("ffd60a"), Vector3(cos(ang) * 0.17, 0.11, sin(ang) * 0.17), h, 0.0)
		"hat_cap":
			var s := U.sphere(0.27, Color("3a86ff"), Vector3(0, -0.04, 0), h, 12)
			s.scale = Vector3(1, 0.55, 1)
			U.box(Vector3(0.3, 0.02, 0.22), Color("3a86ff"), Vector3(0, -0.06, -0.3), h)
		"hat_chef":
			U.cyl(0.18, 0.12, Color.WHITE, Vector3(0, 0.0, 0), h)
			U.sphere(0.22, Color.WHITE, Vector3(0, 0.16, 0), h, 10)
		"hat_propeller":
			var s2 := U.sphere(0.25, Color("ff9f1c"), Vector3(0, -0.04, 0), h, 12)
			s2.scale = Vector3(1, 0.5, 1)
			U.cyl(0.015, 0.12, Color("333333"), Vector3(0, 0.1, 0), h)
			var spin := Node3D.new()
			spin.position = Vector3(0, 0.16, 0)
			h.add_child(spin)
			U.box(Vector3(0.45, 0.01, 0.06), Color("2ec4b6"), Vector3.ZERO, spin)
			U.box(Vector3(0.06, 0.01, 0.45), Color("e71d36"), Vector3.ZERO, spin)
			a._prop_spin = spin
		"hat_beanie":
			var bn := U.sphere(0.3, Color("e63946"), Vector3(0, -0.06, 0), h, 12)
			bn.scale = Vector3(1, 0.62, 1)
			U.sphere(0.07, Color.WHITE, Vector3(0, 0.15, 0), h, 8)
		"hat_halo":
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.17
			tm.outer_radius = 0.22
			ring.mesh = tm
			ring.material_override = U.mat(Color("fff3a0"))
			(ring.material_override as StandardMaterial3D).emission_enabled = true
			(ring.material_override as StandardMaterial3D).emission = Color("fff3a0")
			ring.position = Vector3(0, 0.2, 0)
			h.add_child(ring)
		"hat_poseidon":
			var gold := Color("ffc93c")
			U.cyl(0.24, 0.08, gold, Vector3(0, -0.02, 0), h, 0.25)
			for k in 7:
				var ang := TAU * k / 7.0
				var tall := 0.28 if k % 2 == 0 else 0.18
				U.cyl(0.035, tall, gold, Vector3(cos(ang) * 0.22, tall / 2.0, sin(ang) * 0.22), h, 0.0)
			U.sphere(0.04, Color("2ec4b6"), Vector3(0, 0.03, -0.25), h, 8)
		"hat_horns":
			for sx in [-1.0, 1.0]:
				var hn := U.cyl(0.05, 0.18, Color("e63946"), Vector3(0.15 * sx, 0.04, 0), h, 0.0)
				hn.rotation.z = -0.4 * sx


static func _outfit(a: Node, id: String) -> void:
	var b: Node3D = a.body_root
	match id:
		"outfit_stripes":
			for k in 3:
				U.cyl(0.345, 0.06, Color.WHITE, Vector3(0, -0.12 - k * 0.15, 0), b)
		"outfit_overalls":
			U.capsule(0.38, 0.6, Color("3a5ba0"), Vector3(0, -0.42, 0), b)
			for sx in [-1.0, 1.0]:
				U.box(Vector3(0.06, 0.35, 0.7), Color("3a5ba0"), Vector3(0.14 * sx, -0.08, 0), b)
		"outfit_hoodie":
			U.capsule(0.35, 0.8, Color("7b2cbf"), Vector3(0, -0.28, 0), b)
			var hood := U.sphere(0.3, Color("6a1fb0"), Vector3(0, 0.2, 0.22), b, 10)
			hood.scale = Vector3(1.1, 0.8, 0.6)
		"outfit_tuxedo":
			U.capsule(0.35, 0.8, Color("1d1d22"), Vector3(0, -0.28, 0), b)
			U.box(Vector3(0.2, 0.5, 0.05), Color.WHITE, Vector3(0, -0.2, -0.345), b)
			U.box(Vector3(0.18, 0.06, 0.05), Color("d00000"), Vector3(0, 0.02, -0.37), b)
		"outfit_apron":
			U.box(Vector3(0.42, 0.55, 0.04), Color("fefae0"), Vector3(0, -0.3, -0.36), b)
			U.box(Vector3(0.2, 0.12, 0.03), Color("ff8fab"), Vector3(0, -0.36, -0.385), b)
		"outfit_poseidon":
			U.capsule(0.41, 1.0, Color("1b9aaa"), Vector3(0, -0.36, 0), b)
			var sash := U.box(Vector3(0.12, 0.85, 0.84), Color("ffc93c"), Vector3(0, -0.2, 0), b)
			sash.rotation.z = 0.6
			U.cyl(0.42, 0.07, Color("ffc93c"), Vector3(0, -0.42, 0), b)
			U.sphere(0.07, Color("ffafcc"), Vector3(0, -0.42, -0.42), b, 8)  # shell buckle
			# big white beard
			var beard := U.sphere(0.24, Color("f1f1f1"), Vector3(0, -0.25, -0.24), a._head, 10)
			beard.scale = Vector3(1.05, 1.2, 0.7)
		"outfit_hero":
			var cape := U.box(Vector3(0.6, 0.95, 0.04), Color("d00000"), Vector3(0, -0.3, 0.38), b)
			cape.rotation.x = 0.12
			var emblem := U.cyl(0.1, 0.02, Color("ffd60a"), Vector3(0, -0.1, -0.35), b)
			emblem.rotation.x = PI / 2.0


static func _shoes(a: Node, id: String) -> void:
	for f in a._feet:
		var mi: MeshInstance3D = f
		match id:
			"shoes_sneakers":
				mi.material_override = U.mat(Color.WHITE)
				U.box(Vector3(0.19, 0.03, 0.2), Color("e63946"), Vector3(0, 0.03, 0), mi)
			"shoes_boots":
				mi.material_override = U.mat(Color("6d4c41"))
				mi.scale = Vector3(1.1, 2.2, 1.0)
			"shoes_flippers":
				mi.material_override = U.mat(Color("2ec4b6"))
				mi.scale = Vector3(1.7, 0.6, 2.2)
			"shoes_poseidon":
				mi.material_override = U.mat(Color("b07d3a"))
				U.box(Vector3(0.22, 0.03, 0.06), Color("ffc93c"), Vector3(0, 0.07, 0.05), mi)
			"shoes_gold":
				mi.material_override = U.mat(Color("ffd60a"), 0.2, 0.9)


## Something held in the left hand (follows the arm swing).
static func _hand(a: Node, id: String) -> void:
	if id == "hand_none":
		return
	var h := Node3D.new()
	h.position = Vector3(0, -0.46, 0)
	a._arms[0].add_child(h)
	match id:
		"hand_spatula":
			U.cyl(0.025, 0.4, Color("8b5a3c"), Vector3(0, 0.12, -0.05), h)
			U.box(Vector3(0.16, 0.02, 0.2), Color("adb5bd"), Vector3(0, 0.36, -0.12), h)
		"hand_duck":
			U.sphere(0.12, Color("ffd60a"), Vector3(0, 0.06, -0.14), h, 10)
			U.sphere(0.08, Color("ffd60a"), Vector3(0, 0.18, -0.2), h, 8)
			U.box(Vector3(0.06, 0.03, 0.07), Color("ff7b00"), Vector3(0, 0.17, -0.29), h)
		"hand_balloon":
			U.cyl(0.006, 0.9, Color.WHITE, Vector3(0, 0.45, 0), h)
			var bal := U.sphere(0.22, Color("ff4d6d"), Vector3(0, 1.05, 0), h, 12)
			bal.scale = Vector3(1, 1.15, 1)
		"hand_plunger":
			U.cyl(0.025, 0.5, Color("c8955f"), Vector3(0, 0.15, -0.05), h)
			U.cyl(0.12, 0.1, Color("d00000"), Vector3(0, 0.42, -0.05), h, 0.05)
		"hand_trident":
			var gold := Color("ffc93c")
			var m := U.mat(gold, 0.25, 0.85)
			U.cyl(0.03, 1.7, gold, Vector3(0, 0.45, -0.06), h).material_override = m
			U.cyl(0.05, 0.06, gold, Vector3(0, 1.3, -0.06), h).material_override = m
			U.box(Vector3(0.34, 0.04, 0.04), gold, Vector3(0, 1.34, -0.06), h).material_override = m
			for k in 3:
				var px := -0.15 + k * 0.15
				U.cyl(0.022, 0.32, gold, Vector3(px, 1.5, -0.06), h, 0.0).material_override = m


## Face shape items keep working with the mood animation (Avatar._update_face multiplies them in).
static func _eyes(a: Node, id: String) -> void:
	match id:
		"eyes_big":
			a._eye_shape = Vector3(1.25, 1.25, 1.25)
			a._pupil_z = -0.49
		"eyes_tiny":
			a._eye_shape = Vector3(0.7, 0.7, 0.7)
			a._pupil_z = -0.43
			for p in a._pupils:
				p.scale = Vector3(0.75, 0.75, 0.75)
		"eyes_sleepy":
			for e in a._eyes:
				var lid := U.sphere(0.137, Color.WHITE, Vector3(0, 0.07, -0.005), e, 12)  # covers the top half of the pupil
				lid.scale = Vector3(1.05, 0.5, 1.05)
				lid.material_override = a._skin_mat
		"eyes_lashes":
			for i in 2:
				var sx := -1.0 if i == 0 else 1.0
				for k in 3:
					var l := U.box(Vector3(0.02, 0.07, 0.02), Color("111111"), Vector3((0.03 + k * 0.035) * sx, 0.13, -0.06), a._eyes[i])
					l.rotation.z = -0.4 * sx * (k + 1) / 3.0


static func _brows(a: Node, id: String) -> void:
	for i in 2:
		var sx := -1.0 if i == 0 else 1.0
		var b: Node3D = a._brows[i]
		var mesh: Node3D = b.get_child(0)
		match id:
			"brows_thick":
				mesh.scale = Vector3(1.25, 1.9, 1.3)
			"brows_thin":
				mesh.scale = Vector3(0.95, 0.5, 0.7)
			"brows_none":
				b.visible = false
			"brows_uni":
				mesh.scale = Vector3(1.6, 1.4, 1.0)
				mesh.position.x = -0.045 * sx


static func _mouth(a: Node, id: String) -> void:
	match id:
		"mouth_wide":
			a._mouth_shape = Vector3(1.0, 1.6, 1.0)  # the capsule lies on its side: local y is the width
		"mouth_buck":
			a._teeth_always = true
			a._teeth.scale = Vector3(1.0, 2.2, 1.0)
		"mouth_mustache":
			for sx in [-1.0, 1.0]:
				var m := U.capsule(0.035, 0.16, Color("4a2c1a"), Vector3(0.07 * sx, -0.08, -0.43), a._head)
				m.rotation.z = PI / 2.0 + 0.35 * sx
		"mouth_tongue":
			var t := U.capsule(0.035, 0.1, Color("ff6b8b"), Vector3(0.03, -0.18, -0.42), a._head)
			t.rotation.x = 0.4
