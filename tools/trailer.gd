extends Node
## Trailer footage: plays staged sandbox "beats" on every map with title cards in between.
##   godot --path . --resolution 1920x1080 --fixed-fps 30 --write-movie OUT/raw.avi -- --trailer=OUT
## Writes OUT/trailer_log.json (card/beat times + every knock-down) and OUT/music.wav;
## tools/trailer_edit.py then cuts the best moments into OUT/trailer.mp4.

const FPS := 30.0
var BEAT_LEN := 20.0
const BEATS := [
	{"map": "house", "card": ["Booby-trap the house.", ""]},
	{"map": "school", "card": ["Then watch your friends", "walk right into it."]},
	{"map": "office", "card": ["16 pranks. Chain reactions.", "Every extra link doubles the points."]},
	{"map": "wedding", "card": ["Ghosts, house rules, chaos mode", "and a cat that will not stay put."]},
	{"map": "mansion", "card": ["5 maps + a map editor", "1v1 to 4v4 online · bots · sandbox"]},
]

var out := "user://trailer"
var _frame := 0
var _log := {"fps": FPS, "segments": []}
var _card: CanvasLayer
var _title: Label
var _sub: Label
var _w: Node
var _target: Avatar
var _switch_at := 0.0
var _focus := Vector3.ZERO
var _knocked := {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	_build_card()
	get_node("/root/Main").menu.visible = false
	_run()


func _t() -> float:
	return _frame / FPS


func _process(delta: float) -> void:
	_frame += 1
	if _w == null or not is_instance_valid(_w):
		return
	_camera(delta)
	for a in _w.avatars.values():
		var k: bool = a.is_knocked()
		if k and not _knocked.get(a.slot, false) and _log["segments"][-1]["kind"] == "beat":
			_log["segments"][-1]["hits"].append(_t())
		_knocked[a.slot] = k


func _wait(sec: float) -> void:
	var until := _t() + sec
	while _t() < until:
		await get_tree().process_frame


func _run() -> void:
	await _wait(0.5)
	await _show_card("PRANK WARS", "a party game about pranking your friends", 3.0, true)
	for b in BEATS:
		_card_text(b["card"][0], b["card"][1], false)
		await _fade(1.0, 0.3)
		await _start_beat(b["map"])
		await _wait(2.2)
		await _fade(0.0, 0.4)
		var seg := {"kind": "beat", "map": b["map"], "start": _t(), "hits": []}
		_log["segments"].append(seg)
		await _wait(BEAT_LEN)
		seg["end"] = _t()
	await _show_card("PRANK WARS", "Wishlist now on Steam", 4.0, true)
	_save()
	get_tree().quit()


func _show_card(title: String, sub: String, sec: float, logo: bool) -> void:
	_card_text(title, sub, logo)
	await _fade(1.0, 0.3)
	var seg := {"kind": "card", "start": _t(), "hits": []}
	_log["segments"].append(seg)
	await _wait(sec)
	seg["end"] = _t()


func _start_beat(map_name: String) -> void:
	_w = null
	Config.map = map_name
	Net.start_sandbox_with(3)
	Net.start_match()
	await _wait(1.0)
	_w = get_node("/root/Main").world
	if _w == null:
		push_error("trailer: no world")
		return
	_w.show_names = false
	_w.hud.visible = false
	_w.cam.set_process(false)
	var me: Avatar = _w.local_avatar()
	for e in _w.bot_make_plan(me.team, 45):
		me.respawn(e["stand"] + Vector3(0, 0.8, 0))
		_w.host_place(me.slot, e["type"], e["pos"], e["yaw"], e["socket"])
	me.respawn(Vector3(-9.5, 0.8, 14.5))
	_target = null
	_knocked.clear()


## Follows the bot closest to a live trap (or the one already flying through the air).
func _camera(delta: float) -> void:
	var now := _t()
	if _target == null or (now > _switch_at and not _target.is_knocked()):
		var best: Avatar = null
		var bd := 1e9
		for a in _w.avatars.values():
			if a == _w.local_avatar() or not a.visible:
				continue
			for id in _w.pranks:
				var p: Prank = _w.pranks[id]
				if p.used or p.disarmed:
					continue
				var d := U.dist_xz(a.global_position, p.global_position)
				if d < bd:
					bd = d
					best = a
		if best:
			if best != _target:
				_switch_at = now + 3.0
			_target = best
	var cam: Camera3D = _w.cam
	var want := _target.global_position if _target else Vector3(0, 0, 1)
	want.y = 0.0
	_focus = _focus.lerp(want, minf(1.0, delta * 3.0)) if _focus != Vector3.ZERO else want
	cam.position = cam.position.lerp(_focus + Vector3(1.2, 6.2, 6.0), minf(1.0, delta * 2.5))
	cam.look_at(_focus + Vector3(0, 0.6, 0), Vector3.UP)
	_w.house.update_fade(_focus, delta)


func _build_card() -> void:
	_card = CanvasLayer.new()
	_card.layer = 50
	add_child(_card)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.08, 0.16, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	bg.add_child(box)
	_title = Label.new()
	_sub = Label.new()
	for l in [_title, _sub]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		box.add_child(l)
	_sub.add_theme_font_size_override("font_size", 52)
	_sub.add_theme_constant_override("outline_size", 12)
	_card.visible = false
	bg.modulate.a = 0.0


func _card_text(title: String, sub: String, logo: bool) -> void:
	var vh := float(get_viewport().get_visible_rect().size.y)
	_title.text = title
	_sub.text = sub
	_sub.visible = sub != ""
	_title.add_theme_font_size_override("font_size", int(vh * (0.17 if logo else 0.085)))
	_title.add_theme_constant_override("outline_size", int(vh * (0.03 if logo else 0.016)))
	_title.add_theme_color_override("font_color", Color("ffe14d") if logo else Color.WHITE)
	_sub.add_theme_font_size_override("font_size", int(vh * 0.05))
	_sub.add_theme_color_override("font_color", Color("ffe14d") if not logo else Color.WHITE)


func _fade(to: float, sec: float) -> void:
	var bg: Control = _card.get_child(0)
	_card.visible = true
	var from := bg.modulate.a
	var t0 := _t()
	while _t() < t0 + sec:
		await get_tree().process_frame
		bg.modulate.a = lerpf(from, to, clampf((_t() - t0) / sec, 0.0, 1.0))
	bg.modulate.a = to
	_card.visible = to > 0.0


func _save() -> void:
	var f := FileAccess.open(out.path_join("trailer_log.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(_log, "  "))
	f.close()
	var m: AudioStreamWAV = Sfx._music_stream
	if m:
		m.save_to_wav(out.path_join("music.wav"))
	print("trailer log saved ", ProjectSettings.globalize_path(out))
