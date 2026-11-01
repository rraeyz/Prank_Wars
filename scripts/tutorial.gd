extends Node
## Interactive tutorial (~1 minute) on top of sandbox mode. Each step shows one instruction and
## waits for the player to actually do it; a glowing marker shows where to go.

var world: Node
var step := 0
var _panel: PanelContainer
var _text: Label
var _marker: Node3D
var _bot: Avatar
var _t := 0.0
var _start_pos := Vector3.ZERO

# [text key, marker position or null]
const STEPS := [
	["tut_move", Vector3(3.0, 0, -2.0)],
	["tut_jump", null],
	["tut_dive", null],
	["tut_place", null],
	["tut_slip", null],
	["tut_task", "plant_a"],
	["tut_bucket", Vector3(-1.0, 0, 6.0)],
	["tut_watch", Vector3(-1.0, 0, 6.0)],
	["tut_flour", null],
	["tut_done", null],
]


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.offset_left = -360
	_panel.offset_right = 360
	_panel.offset_top = 150
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.15, 0.88)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(14)
	sb.border_color = Color("ffe14d")
	sb.set_border_width_all(3)
	_panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(_panel)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.add_theme_font_size_override("font_size", 22)
	_panel.add_child(_text)
	_marker = Node3D.new()
	world.add_child(_marker)
	var ring := U.cyl(0.6, 0.05, Color(1.0, 0.88, 0.3, 0.7), Vector3(0, 0.05, 0), _marker)
	ring.material_override = U.mat(Color(1.0, 0.88, 0.3, 0.7), 0.5, 0.0, true)
	var arrow := U.cyl(0.18, 0.4, Color("ffe14d"), Vector3(0, 1.6, 0), _marker, 0.0)
	arrow.rotation.x = PI
	arrow.material_override = U.mat(Color("ffe14d"), 0.5, 0.0, true)
	# the bot waits outside until the bucket lesson
	for s in world.avatars:
		var a: Avatar = world.avatars[s]
		if a.is_bot:
			_bot = a
			a.park()
	world.tasks = [{"id": "plants", "step": 0, "done": false}]
	_enter(0)


func _enter(i: int) -> void:
	step = i
	_t = 0.0
	var me: Avatar = world.local_avatar()
	if me:
		_start_pos = me.global_position
	var row: Array = STEPS[i]
	_text.text = "%s  %d/%d\n%s" % [I18n.t("tutorial"), i + 1, STEPS.size(), I18n.t(row[0])]
	var m = row[1]
	if m is String and world.house.spots.has(m):
		m = world.house.spots[m]["pos"]
	_marker.visible = m is Vector3
	if m is Vector3:
		_marker.global_position = Vector3(m.x, 0, m.z)
	if row[0] == "tut_watch" and _bot:
		_bot.respawn(Vector3(-1.0, 0.8, 13.5))
		_bot.perk = ""
	Sfx.play("task")


func _process(delta: float) -> void:
	_t += delta
	_marker.rotation.y += delta * 2.0
	_marker.position.y = sin(_t * 4.0) * 0.08
	if world.phase != "sandbox":
		return
	if _done_now():
		if step + 1 < STEPS.size():
			_enter(step + 1)
		elif not bool(Config.settings.get("tutorial_done", false)):
			Config.settings["tutorial_done"] = true
			Config.save_settings()


## Does the current step's goal hold right now?
func _done_now() -> bool:
	var me: Avatar = world.local_avatar()
	if me == null:
		return false
	var p := me.global_position
	match STEPS[step][0]:
		"tut_move":
			return U.dist_xz(p, STEPS[0][1]) < 1.3
		"tut_jump":
			return p.y > 1.35 and not me.down
		"tut_dive":
			return me.down and me.self_knock
		"tut_place":
			return _has_prank("banana")
		"tut_slip":
			return me.down and not me.self_knock and _t > 0.3
		"tut_task":
			for t in world.tasks:
				if t["id"] == "plants" and int(t["step"]) > 0:
					return true
			return false
		"tut_bucket":
			for id in world.pranks:
				if world.pranks[id].type == "bucket" and world.pranks[id].socket == "front":
					return true
			return false
		"tut_watch":
			return _bot != null and (Config.now < _bot.slow_until or _t > 25.0)
		"tut_flour":
			for id in world.pranks:
				if world.pranks[id].type == "flour" and world.pranks[id].used:
					return true
			return false
	return false


func _has_prank(type: String) -> bool:
	for id in world.pranks:
		if world.pranks[id].type == type:
			return true
	return false
