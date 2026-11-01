extends Node
func _ready():
	var w = null
	while w == null:
		await get_tree().create_timer(0.3).timeout
		w = get_node_or_null("/root/Main/World")
	await get_tree().create_timer(0.3).timeout
	for c in w.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("editor.gd"):
			for i in 5:
				c.add_item("wall", Vector3(-6 + i * 1.0, 0, -1.5 - i * 0.5), 0.4)
			c.add_item("ramp", Vector3(3, 0, 2.5), 0.0)
			c.add_item("big_crate", Vector3(-1.5, 0, 2.0), 0.3)
			c.add_item("ball", Vector3(0.5, 0, 3.5), 0.0)
