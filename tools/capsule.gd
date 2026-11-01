extends Node
## Steam store/library art from one staged prank moment, all sizes rendered on the same frame.
##   godot --path . --rendering-driver vulkan -- --capsule=OUTDIR
## Sizes follow Steamworks' graphical asset list (header, small, main, vertical, library capsule/hero/logo).

const SIZES := {
	"header_capsule": [Vector2i(920, 430), true],
	"small_capsule": [Vector2i(462, 174), true],
	"main_capsule": [Vector2i(1232, 706), true],
	"vertical_capsule": [Vector2i(748, 896), true],
	"library_capsule": [Vector2i(600, 900), true],
	"library_hero": [Vector2i(3840, 1240), false],
}
const LOOK := Vector3(2.4, 0.9, -2.7)

var out := "user://capsule"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	Net.start_sandbox_with(2)
	Net.start_match()
	await get_tree().create_timer(1.5).timeout
	var w = get_node("/root/Main").world
	w.show_names = false
	w.hud.visible = false
	w._ghost.visible = false
	var avs: Array = w.avatars.values()
	var me: Avatar = w.local_avatar()
	me.respawn(Vector3(0.6, 0.8, -1.4))
	var others := avs.filter(func(a): return a != me)
	others[0].respawn(Vector3(1.6, 0.8, -2.6))
	others[1].respawn(Vector3(3.6, 0.8, -3.3))
	w.host_place(me.slot, "spring", Vector3(1.6, 0, -2.6), 0.0, "")
	w.host_place(me.slot, "banana", Vector3(3.6, 0, -3.3), 0.0, "")
	w.host_place(me.slot, "confetti", Vector3(4.5, 0, -2.0), 0.0, "")
	w.host_place(me.slot, "flour", Vector3(2.6, 2.55, -3.0), 0.0, "")
	await get_tree().create_timer(0.3).timeout
	for id in w.pranks:
		var p: Prank = w.pranks[id]
		if p.type in ["confetti", "flour"]:
			p.fire(null)
		elif p.type == "spring":
			p.fire(others[0])
		elif p.type == "banana":
			p.fire(others[1])
	await get_tree().create_timer(0.35).timeout
	w.set_process(false)
	w.cam.set_process(false)
	w.house.update_fade(LOOK, 10.0)
	var vps := {}
	for n in SIZES:
		vps[n] = _viewport(SIZES[n][0], SIZES[n][1])
	vps["library_logo"] = _logo_viewport(Vector2i(1280, 720))
	for i in 3:
		await RenderingServer.frame_post_draw
	for n in vps:
		var img: Image = vps[n].get_texture().get_image()
		img.save_png(out.path_join(n + ".png"))
		print("saved ", n)
	get_tree().quit()


func _viewport(size: Vector2i, title: bool) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var aspect := float(size.x) / size.y
	var cam := Camera3D.new()
	cam.fov = 48.0 if aspect < 1.2 else 40.0
	vp.add_child(cam)
	# taller images: pull back and look a bit higher so the title sits above the action
	var back := 1.0 + (0.45 if aspect < 1.2 else 0.0) + (0.25 if title else 0.0)
	cam.position = LOOK + Vector3(3.6, 3.4, 5.4) * back
	cam.look_at(LOOK + Vector3(0, 0.55 if title else 0.0, 0) * back, Vector3.UP)
	cam.current = true
	if title:
		var l := _title(size.y * (0.2 if aspect > 2.0 else (0.11 if aspect < 1.2 else 0.17)))
		l.size = Vector2(size.x, size.y * 0.42)
		l.position = Vector2(0, size.y * 0.02)
		vp.add_child(l)
	return vp


func _logo_viewport(size: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var l := _title(size.y * 0.3)
	l.size = Vector2(size)
	vp.add_child(l)
	return vp


func _title(px: float) -> Label:
	var l := Label.new()
	l.text = "PRANK WARS"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", int(px))
	l.add_theme_color_override("font_color", Color("ffe14d"))
	l.add_theme_color_override("font_outline_color", Color("1a1423"))
	l.add_theme_constant_override("outline_size", int(px * 0.2))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("shadow_offset_y", int(px * 0.06))
	return l
