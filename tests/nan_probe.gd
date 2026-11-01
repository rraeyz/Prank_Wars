extends Node
func _physics_process(_d):
	for n in get_tree().root.find_children("*", "Node3D", true, false):
		var t: Transform3D = n.global_transform
		if not (t.origin.is_finite() and t.basis.x.is_finite() and t.basis.y.is_finite() and t.basis.z.is_finite()):
			print("NAN: ", n.get_path(), " ", t)
			set_process(false)
			return
var _acc := 0.0
func _process(d):
	_acc += d
	if _acc > 0.5:
		_acc = 0.0
		var w = get_tree().root.get_node_or_null("Main/World")
		if w: printerr("T ", Config.now, " ", w.phase, " pranks=", w.pranks.size())
