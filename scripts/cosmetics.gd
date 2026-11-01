class_name Cosmetics
extends RefCounted
## Cosmetic catalog (hats, outfits, shoes, full skins), unlock rules and the code that dresses a bean.
## Unlock: "free" | "level:N" (earned by playing) | "steam:ITEMDEF" (bought in the Steam item store).
## Item defs for Steam live in steam/itemdefs.json (upload in Steamworks > Inventory Service).

const SLOTS := ["hat", "outfit", "shoes", "skin"]

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
}

const DEFAULT := {"hat": "hat_party", "outfit": "outfit_none", "shoes": "shoes_default", "skin": "skin_none"}


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
	return steam_owned.has(steam_def(id))


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
		out[slot] = free[rng.randi() % free.size()] if slot != "skin" or rng.randf() < 0.3 else "skin_none"
	return out


# ------------------------------------------------------------------ dressing

static func apply(a: Node, look: Dictionary) -> void:
	_skin(a, str(look.get("skin", "skin_none")))
	_hat(a, str(look.get("hat", "hat_none")))
	_outfit(a, str(look.get("outfit", "outfit_none")))
	_shoes(a, str(look.get("shoes", "shoes_default")))


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
			"shoes_gold":
				mi.material_override = U.mat(Color("ffd60a"), 0.2, 0.9)
