class_name Prop
extends RigidBody3D
## Movable physics object (chair, box, ball, trash bag...). Host simulates, clients display.

var net_id := 0
var kind := ""
var carryable := true
var carrier: Node3D = null
var hidden_prop := false
var chain_id := -1
var chain_until := 0.0
var thrown_by: Node3D = null
var thrown_until := 0.0
var ghost_until := 0.0
var ghost_team := 0
var ghost_slot := -1
var home := Transform3D.IDENTITY
var world: Node = null


func setup(k: String, size: Vector3, c: Color, m := 2.0, shape := "box") -> void:
	kind = k
	mass = m
	collision_layer = U.L_PROP
	collision_mask = U.M_ALL
	contact_monitor = true
	max_contacts_reported = 3
	var pm := PhysicsMaterial.new()
	pm.friction = 0.7
	pm.bounce = 0.35 if shape == "ball" else 0.15
	physics_material_override = pm
	var cs := CollisionShape3D.new()
	if shape == "ball":
		var s := SphereShape3D.new()
		s.radius = size.x / 2.0
		cs.shape = s
		U.sphere(size.x / 2.0, c, Vector3.ZERO, self, 16)
	else:
		var b := BoxShape3D.new()
		b.size = size
		cs.shape = b
		U.box(size, c, Vector3.ZERO, self)
	add_child(cs)
	body_entered.connect(_on_hit)


func _on_hit(body: Node) -> void:
	if world and world.has_method("on_prop_hit"):
		world.on_prop_hit(self, body)


func is_chained(now: float) -> bool:
	return chain_id > 0 and now < chain_until


func net_state() -> float:
	return 1.0 if hidden_prop else 0.0


func set_hidden(h: bool) -> void:
	hidden_prop = h
	visible = not h
	if Net.is_host():
		freeze = h or carrier != null
		collision_layer = 0 if h else U.L_PROP
