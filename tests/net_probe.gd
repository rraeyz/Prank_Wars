extends Node
## Used by tests/net_test.sh: logs network state and walks the local bean during the run phase.

var role := ""
var _t := 0.0
var _acc := 0.0
var phases := {}
var start_z := INF
var min_z := INF


func _process(d: float) -> void:
	_t += d
	var w = get_node_or_null("/root/Main/World")
	if w == null:
		return
	phases[w.phase] = true
	var me = w.local_avatar()
	if me == null:
		return
	if w.phase == "run" and role == "client":
		Input.action_press("move_up")
		if start_z == INF:
			start_z = me.global_position.z
		min_z = minf(min_z, me.global_position.z)
	else:
		Input.action_release("move_up")
	_acc += d
	if _acc >= 1.0:
		_acc = 0.0
		var other = w.avatars.get(2)
		print("NET %s t=%.0f phase=%s frames=%d me=%s slot2=%s score=%s" % [role, _t, w.phase, w.timeline.frames.size(),
			me.global_position.snapped(Vector3(0.1, 0.1, 0.1)), other.global_position.snapped(Vector3(0.1, 0.1, 0.1)) if other else "-", w.scores])


func _exit_tree() -> void:
	print("NETRESULT %s phases=%s moved=%.1f" % [role, ",".join(PackedStringArray(phases.keys())), (start_z - min_z) if start_z != INF else 0.0])
