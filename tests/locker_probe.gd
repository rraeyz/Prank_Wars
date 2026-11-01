extends Node
## --lockerprobe[=poseidon]: opens the locker with a sample look (for screenshots).
func _ready():
	await get_tree().create_timer(1.0).timeout
	var m = get_node("/root/Main").menu
	Config.settings["look"] = {"hat": "hat_propeller", "outfit": "outfit_overalls", "shoes": "shoes_flippers", "skin": "skin_none",
		"eyes": "eyes_sleepy", "brows": "brows_thick", "mouth": "mouth_mustache", "hand": "hand_duck"}
	Config.settings["xp"] = 2000
	m.show_screen("locker")
	if str(get_node("/root/Main").args.get("lockerprobe", "")) == "poseidon":
		m._try_on(Cosmetics.store_defs()[107] + ["eyes_big", "brows_uni"])
	else:
		m._refresh_locker()
