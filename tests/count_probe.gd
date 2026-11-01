extends Node
func _ready():
	await get_tree().create_timer(3.0).timeout
	var n := get_tree().root.find_children("*", "MeshInstance3D", true, false).size()
	var b := get_tree().root.find_children("*", "CollisionObject3D", true, false).size()
	print("MESHES ", n, " BODIES ", b, " NODES ", get_tree().get_node_count())
