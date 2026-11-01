extends Node
## Map editor (sandbox without bots): decorate one of the base maps with furniture, ramps, walls and toys.
## Left click place · Right click / G remove · X rotate · Q/R or wheel pick item. Saved as JSON in user://maps/.

const DIR := "user://maps"

var world: Node
var types: Array = House.ITEM_TYPES.keys()
var sel := 0
var yaw := 0.0
var nodes: Array = []  # parallel to Config.custom_items
var _ghost: MeshInstance3D
var _name: LineEdit
var _info: Label
var _next_id := 900000


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 110)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.15, 0.85)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var title := Label.new()
	title.text = I18n.t("editor")
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("ffe14d"))
	v.add_child(title)
	var base := OptionButton.new()
	for m in House.MAPS:
		base.add_item(I18n.t("map_" + m))
	base.selected = House.MAPS.find(Config.map)
	base.item_selected.connect(func(i): Config.map = House.MAPS[i]; Net.start_editor())
	v.add_child(base)
	_name = LineEdit.new()
	_name.text = Config.custom_name if Config.custom_name != "" else "my_house"
	_name.max_length = 24
	v.add_child(_name)
	var row := HBoxContainer.new()
	v.add_child(row)
	for b in [["save", _save], ["clear", _clear], ["test_map", _test]]:
		var btn := Button.new()
		btn.text = I18n.t(b[0])
		btn.pressed.connect(b[1])
		row.add_child(btn)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 15)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(300, 0)
	v.add_child(_info)
	_ghost = MeshInstance3D.new()
	_ghost.mesh = BoxMesh.new()
	world.add_child(_ghost)
	nodes = world.house.custom_nodes.duplicate()
	_refresh_info()


static func clean_name(n: String) -> String:
	var out := ""
	for c in n.strip_edges().to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_" or c == "-":
			out += c
	return out.substr(0, 24)


func _refresh_info() -> void:
	var t: String = types[sel]
	_info.text = "%s: %s   (%d / %d)\n%s" % [I18n.t("item"), I18n.t("it_" + t), Config.custom_items.size(), House.MAX_ITEMS, I18n.t("editor_help")]


func _pointer() -> Vector3:
	var cam: Camera3D = world.cam
	var mp := world.get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mp)
	var dir := cam.project_ray_normal(mp)
	if absf(dir.y) < 0.01:
		return Vector3.INF
	var p := from + dir * (-from.y / dir.y)
	return p if world.house.inside(p, 0.3) else Vector3.INF


func _process(_d: float) -> void:
	var p := _pointer()
	_ghost.visible = p != Vector3.INF
	if _ghost.visible:
		var size: Vector3 = House.ITEM_TYPES[types[sel]][0]
		(_ghost.mesh as BoxMesh).size = size
		_ghost.global_position = p + Vector3(0, size.y / 2.0, 0)
		_ghost.rotation.y = yaw
		var ok: bool = Config.custom_items.size() < House.MAX_ITEMS
		_ghost.material_override = U.mat(Color(0.3, 1.0, 0.4, 0.4) if ok else Color(1, 0.3, 0.2, 0.4), 0.5, 0.0, true)


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("next_item"):
		sel = (sel + 1) % types.size()
		_refresh_info()
	elif e.is_action_pressed("prev_item"):
		sel = (sel - 1 + types.size()) % types.size()
		_refresh_info()
	elif e.is_action_pressed("rotate_item"):
		yaw = fposmod(yaw + PI / 4.0, TAU)
	elif e.is_action_pressed("action"):
		var p := _pointer()
		if p != Vector3.INF:
			add_item(types[sel], p, yaw)
	elif e.is_action_pressed("ghost"):
		var p2 := _pointer()
		if p2 != Vector3.INF:
			remove_near(p2)


func add_item(type: String, p: Vector3, y: float) -> bool:
	if Config.custom_items.size() >= House.MAX_ITEMS or not House.ITEM_TYPES.has(type):
		return false
	var n: Node3D = world.house.build_item(type, Vector3(p.x, 0, p.z), y)
	if n is Prop:
		n.world = world
		n.net_id = _next_id
		_next_id += 1
		world.register_entity(n.net_id, n)
	Config.custom_items.append([type, p.x, p.z, y])
	nodes.append(n)
	Sfx.play("place")
	_refresh_info()
	return true


func remove_near(p: Vector3) -> bool:
	var best := -1
	var bd := 1.5
	for i in nodes.size():
		var n: Node3D = nodes[i]
		var d := U.dist_xz(n.global_position, p)
		if d < bd:
			bd = d
			best = i
	if best < 0:
		return false
	var n2: Node3D = nodes[best]
	if n2 is Prop:
		world.entities.erase(n2.net_id)
		world.house.props.erase(n2)
	n2.queue_free()
	nodes.remove_at(best)
	Config.custom_items.remove_at(best)
	Sfx.play("pop")
	_refresh_info()
	return true


func _clear() -> void:
	while nodes.size() > 0:
		remove_near(nodes[0].global_position)


func _save() -> void:
	var n := clean_name(_name.text)
	if n == "":
		n = "my_house"
	_name.text = n
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(DIR.path_join(n + ".json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"base": Config.map, "items": Config.custom_items}))
		f.close()
		Config.custom_name = n
		world.hud.toast(I18n.t("map_saved", [n]))


## Try it right away: a bot match on this layout.
func _test() -> void:
	_save()
	var items := Config.custom_items.duplicate(true)
	var n := Config.custom_name
	Net.start_practice()
	Config.custom_items = items
	Config.custom_name = n
	Net.start_match()


static func list_maps() -> Array:
	var out := []
	var d := DirAccess.open(DIR)
	if d:
		for f in d.get_files():
			if f.ends_with(".json"):
				out.append(f.get_basename())
	out.sort()
	return out


## Returns {"base", "items"} or {} if the file is missing / broken.
static func load_map(n: String) -> Dictionary:
	var path := DIR.path_join(clean_name(n) + ".json")
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary):
		return {}
	var base := str(data.get("base", "house"))
	return {"base": base if base in House.MAPS else "house", "items": data.get("items", [])}
