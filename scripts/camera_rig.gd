class_name CameraRig
extends Camera3D
## Angled top-down follow camera (looks north). Spectator mode for trappers, close-up for replays.

const OFF := Vector3(0, 9.0, 7.6)
const OFF_REPLAY := Vector3(0, 5.2, 5.0)
const OFF_OVERVIEW := Vector3(0, 19.0, 12.5)

var world: Node
var spectate_idx := 0  # 0 = overview, 1.. = runners
var pan := Vector3.ZERO
var focus := Vector3(0, 0, 3)
var _shake := 0.0
var zoomed := false  # Z: closer camera for precise trap placement


func _ready() -> void:
	fov = 50.0
	far = 120.0
	current = true
	position = focus + OFF


func shake(a: float) -> void:
	_shake = maxf(_shake, a)


func cycle() -> void:
	spectate_idx += 1
	pan = Vector3.ZERO


func spectate_target() -> Node3D:
	var runners: Array = world.runner_avatars()
	if spectate_idx > runners.size():
		spectate_idx = 0
	if spectate_idx == 0 or runners.is_empty():
		return null
	return runners[spectate_idx - 1]


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("zoom") and not world.ui_blocking():
		zoomed = not zoomed
	var off := OFF * (0.55 if zoomed else 1.0)
	var target: Node3D = null
	if world.replaying:
		target = world.replay_focus()
		off = OFF_REPLAY
	else:
		var me: Avatar = world.local_avatar()
		if me and me.visible:
			target = me
		else:
			target = spectate_target()
			var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
			if not world.ui_blocking():
				pan += Vector3(mv.x, 0, mv.y) * delta * 12.0
			if target == null:
				off = OFF_OVERVIEW
				pan = pan.clamp(Vector3(-10, 0, -8), Vector3(10, 0, 10))
	var want := Vector3(0, 0, 1.5) + pan
	if target:
		want = target.global_position + pan
		want.y = 0.0
	focus = focus.lerp(want, minf(1.0, delta * 6.0))
	var desired := focus + off
	position = position.lerp(desired, minf(1.0, delta * 5.0))
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.0)
		position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.3
	look_at(focus + Vector3(0, 0.6, 0), Vector3.UP)
	var peeking: bool = world.phase in ["intro", "setup"] and not world.local_is_trapper() and not world.replaying
	world.house.update_fade(focus, delta, peeking)
