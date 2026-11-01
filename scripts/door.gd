class_name HouseDoor
extends Node3D
## Doorway with a swinging panel. Opening is computed locally on every peer from avatar positions
## (visual only, no collision). The host listens to `opened` to fire door pranks.

signal opened(avatar: Node3D)

var door_name := ""
var width := 1.3
var horizontal := true  # true: wall runs along X
var is_open := false
var locked := false
var hinge: Node3D
var _angle := 0.0
var _target := 0.0
var _close_at := 0.0
var bucket_slot: Node3D  # where a bucket sits (top of the door)


func setup(n: String, w: float, horiz: bool, color: Color) -> void:
	door_name = n
	width = w
	horizontal = horiz
	if not horiz:
		rotation.y = PI / 2.0
	hinge = Node3D.new()
	hinge.position = Vector3(-w / 2.0 + 0.05, 0, 0)
	add_child(hinge)
	var panel := U.box(Vector3(w - 0.12, 2.05, 0.07), color, Vector3((w - 0.12) / 2.0, 1.03, 0), hinge)
	U.sphere(0.05, Color("d4a017"), Vector3(w - 0.3, 1.0, 0.07), hinge)
	U.sphere(0.05, Color("d4a017"), Vector3(w - 0.3, 1.0, -0.07), hinge)
	panel.name = "Panel"
	bucket_slot = Node3D.new()
	bucket_slot.position = Vector3(0, 2.15, 0.12)
	add_child(bucket_slot)


## Is a world point inside the doorway trigger box?
func contains(p: Vector3) -> bool:
	var l := to_local(p)
	return absf(l.x) < width / 2.0 + 0.15 and absf(l.z) < 0.75 and l.y < 2.2


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	var opener: Node3D = null
	for a in get_tree().get_nodes_in_group("avatars"):
		if a.visible and contains(a.global_position):
			opener = a
			break
	if opener and not locked:
		_close_at = now + 0.8
		if not is_open:
			is_open = true
			var side := to_local(opener.global_position).z
			_target = -1.75 if side > 0.0 else 1.75
			opened.emit(opener)
	elif is_open and now > _close_at:
		is_open = false
		_target = 0.0
	_angle = lerpf(_angle, _target, minf(1.0, delta * 9.0))
	hinge.rotation.y = _angle
