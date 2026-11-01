extends Node
func _ready():
	await get_tree().create_timer(1.0).timeout
	var m = get_node("/root/Main").menu
	Config.settings["look"] = {"hat": "hat_propeller", "outfit": "outfit_overalls", "shoes": "shoes_flippers", "skin": "skin_none"}
	Config.settings["xp"] = 2000
	m.show_screen("locker")
	m._refresh_locker()
