extends Node
var t := 0.0
var last := {}
func _physics_process(d):
	t += d
	var w = get_node_or_null("/root/Main/World")
	if w == null or t > 8.0:
		return
	for s in w.avatars:
		var a = w.avatars[s]
		var y: float = a.global_position.y
		if y > 1.6 and not last.get(s, false):
			last[s] = true
			print("UP t=%.2f %s pos=%s vel=%s down=%s ground=%s phase=%s" % [t, a.pname, a.global_position, a.linear_velocity, a.down, a.grounded, w.phase])
		elif y < 1.2:
			last[s] = false
