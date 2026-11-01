extends Node
## Marketing shots: run  godot --path . --resolution 1920x1080 -- --keyart=OUTDIR
## Builds staged moments in sandbox mode and saves PNGs (use a real GPU for best quality).

var out := "user://keyart"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	await get_tree().create_timer(1.5).timeout
	var w = get_node("/root/Main/World")
	w.show_names = false
	var hud: CanvasLayer = w.hud
	var avs: Array = w.avatars.values()
	# everyone is a "runner" in sandbox; place a little chain in the hallway/living room
	var me: Avatar = avs[0]
	me.respawn(Vector3(0.3, 0.8, -1.2))
	for i in range(1, avs.size()):
		avs[i].respawn(Vector3(1.5 + i, 0.8, -2.5 - i * 0.6))
	w.host_place(me.slot, "spring", Vector3(1.6, 0, -2.6), 0.0, "")
	w.host_place(me.slot, "banana", Vector3(3.0, 0, -3.4), 0.0, "")
	w.host_place(me.slot, "confetti", Vector3(4.5, 0, -2.0), 0.0, "")
	w.host_place(me.slot, "flour", Vector3(2.6, 2.55, -3.0), 0.0, "")
	w.host_place(me.slot, "paint", w.house.cupboards["shelf"].inside_point(), 0.0, "shelf")
	await get_tree().create_timer(0.5).timeout
	for id in w.pranks:
		var p: Prank = w.pranks[id]
		if p.type == "spring" and avs.size() > 1:
			p.fire(avs[1])
		if p.type == "confetti" or p.type == "flour":
			p.fire(null)
		if p.type == "paint":
			w.open_cupboard(w.house.cupboards["shelf"], me)
	var cam: Camera3D = w.cam
	cam.set_process(false)
	cam.position = Vector3(6.5, 5.5, 3.5)
	cam.look_at(Vector3(2.2, 0.8, -2.6), Vector3.UP)
	hud.visible = false
	w.set_process(false)
	w._ghost.visible = false
	for k in 4:
		await get_tree().create_timer(0.18).timeout
		_shot("keyart_%d.png" % k)
	hud.visible = true
	w.set_process(true)
	cam.set_process(true)
	await get_tree().create_timer(2.0).timeout
	_shot("gameplay_hud.png")
	get_tree().quit()


func _shot(n: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := out.path_join(n)
	img.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
