class_name Cupboard
extends Node3D
## Furniture that can be opened (fridge, cabinet, wardrobe...). Front faces local +Z.
## Can hold one container prank. Opening is host-driven and mirrored to clients via World fx.

var cup_name := ""
var size := Vector3.ONE
var is_open := false
var prank: Node = null
var _door: Node3D
var _t := 0.0
var _open_until := 0.0


func setup(n: String, sz: Vector3, body_color: Color, door_color: Color) -> void:
	cup_name = n
	size = sz
	U.solid(self, sz, Vector3(0, sz.y / 2.0, 0), body_color)
	_door = Node3D.new()
	_door.position = Vector3(-sz.x / 2.0, 0, sz.z / 2.0 + 0.03)
	add_child(_door)
	U.box(Vector3(sz.x - 0.04, sz.y - 0.06, 0.05), door_color, Vector3(sz.x / 2.0, sz.y / 2.0, 0), _door)
	U.box(Vector3(0.05, 0.25, 0.05), Color("777777"), Vector3(sz.x - 0.12, sz.y / 2.0, 0.05), _door)


func front_point() -> Vector3:
	return global_transform * Vector3(0, 0, size.z / 2.0 + 0.55)


func inside_point() -> Vector3:
	return global_transform * Vector3(0, size.y * 0.5, 0)


func open() -> void:
	is_open = true
	_open_until = Time.get_ticks_msec() * 0.001 + 2.5


func _process(delta: float) -> void:
	if is_open and Time.get_ticks_msec() * 0.001 > _open_until:
		is_open = false
	_t = lerpf(_t, 1.0 if is_open else 0.0, minf(1.0, delta * 10.0))
	_door.rotation.y = -_t * 1.9
