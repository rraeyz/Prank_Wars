extends CanvasLayer
## Main menu, lobby and settings screens (built in code).

var main: Node
var _screens := {}
var _name_edit: LineEdit
var _ip_edit: LineEdit
var _status: Label
var _lobby_list: VBoxContainer
var _lobby_info: Label
var _host_box: HBoxContainer
var _start_btn: Button
var _rounds_btn: Button
var _setup_btn: Button
var _run_btn: Button
var _rule_btn: Button
var _mode_btn: Button
var _map_btn: Button
var _invite_btn: Button
var _lobby_chat: Label
var _chat_lines: Array = []


func _ready() -> void:
	layer = 10
	_build_main()
	_build_lobby()
	_build_settings()
	_build_keys()
	var hv := _screen("how")
	hv.add_child(_lbl(I18n.t("how"), 40, Color("ffe14d")))
	var ht := _lbl(I18n.t("how_text"), 18)
	ht.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hv.add_child(ht)
	_btn(I18n.t("back"), func(): show_screen("main"), hv)
	show_screen("main")
	Net.players_changed.connect(_refresh_lobby)
	Net.connected_ok.connect(func(): show_screen("lobby"))
	Net.connection_failed.connect(func(): show_screen("main"); _status.text = I18n.t("conn_failed"))
	Net.server_gone.connect(func(): show_screen("main"); _status.text = I18n.t("disconnected"))
	Net.rejected.connect(func(r): show_screen("main"); _status.text = I18n.t("rej_" + r))


func show_screen(n: String) -> void:
	for k in _screens:
		_screens[k].visible = k == n
	_focus_first.call_deferred(_screens[n])
	if n == "lobby":
		_refresh_lobby()


## Gamepad / keyboard users need a focused button to start navigating.
func _focus_first(root: Node) -> void:
	if not is_instance_valid(root) or not root.visible:
		return
	for c in root.find_children("*", "BaseButton", true, false):
		if c.is_visible_in_tree() and not c.disabled:
			c.grab_focus()
			return


func _screen(n: String) -> VBoxContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.15, 0.82)
	sb.set_corner_radius_all(22)
	sb.set_content_margin_all(30)
	panel.add_theme_stylebox_override("panel", sb)
	cc.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	_screens[n] = cc
	return v


func _lbl(t: String, size: int, c := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", maxi(4, size / 6))
	return l


func _btn(t: String, cb: Callable, parent: Node) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", 22)
	b.custom_minimum_size = Vector2(320, 48)
	b.pressed.connect(func(): Sfx.play("click"); cb.call())
	parent.add_child(b)
	return b


func _build_main() -> void:
	var v := _screen("main")
	v.add_child(_lbl("PRANK WARS" + (" — DEMO" if Config.demo_mode else ""), 72, Color("ffe14d")))
	v.add_child(_lbl(I18n.t("title_sub"), 18))
	var row := HBoxContainer.new()
	row.add_child(_lbl(I18n.t("name") + ":", 20))
	_name_edit = LineEdit.new()
	_name_edit.text = str(Config.settings["name"])
	_name_edit.max_length = 16
	_name_edit.custom_minimum_size = Vector2(240, 40)
	_name_edit.text_changed.connect(func(t): Config.settings["name"] = t; Config.save_settings())
	row.add_child(_name_edit)
	v.add_child(row)
	var hb := _btn("", Callable(), v)
	var upd := func(): hb.text = "%s: %s" % [I18n.t("hat"), I18n.t("hat_" + Config.HATS[int(Config.settings["hat"]) % Config.HATS.size()])]
	upd.call()
	hb.pressed.connect(func(): Config.settings["hat"] = (int(Config.settings["hat"]) + 1) % Config.HATS.size(); Config.save_settings(); upd.call())
	var pb := _btn(I18n.t("practice"), func(): Net.start_practice(); show_screen("lobby"), v)
	pb.add_theme_color_override("font_color", Color("ffe14d"))
	var sbx := _btn(I18n.t("sandbox"), func(): Net.start_sandbox(), v)
	sbx.add_theme_color_override("font_color", Color("ffb3e6"))
	if SteamNet.available():
		var sb := _btn(I18n.t("steam_host"), func(): SteamNet.host_lobby(), v)
		sb.add_theme_color_override("font_color", Color("9ad0ff"))
		SteamNet.status.connect(func(t): _status.text = t)
	_btn(I18n.t("host"), _on_host, v)
	var jr := HBoxContainer.new()
	_ip_edit = LineEdit.new()
	_ip_edit.text = str(Config.settings["last_ip"])
	_ip_edit.placeholder_text = I18n.t("ip")
	_ip_edit.custom_minimum_size = Vector2(190, 44)
	jr.add_child(_ip_edit)
	var jb := Button.new()
	jb.text = I18n.t("join")
	jb.custom_minimum_size = Vector2(124, 44)
	jb.add_theme_font_size_override("font_size", 22)
	jb.pressed.connect(_on_join)
	jr.add_child(jb)
	v.add_child(jr)
	_btn(I18n.t("how"), func(): show_screen("how"), v)
	_btn(I18n.t("settings"), func(): show_screen("settings"), v)
	_btn(I18n.t("quit"), func(): get_tree().quit(), v)
	_status = _lbl("", 16, Color("ff9a9a"))
	v.add_child(_status)
	v.add_child(_lbl("v" + Config.VERSION, 12, Color(1, 1, 1, 0.5)))


func _on_host() -> void:
	var err := Net.host_game()
	if err != OK:
		_status.text = I18n.t("host_failed")
		return
	show_screen("lobby")


func _on_join() -> void:
	var ip := _ip_edit.text.strip_edges()
	if ip == "":
		ip = "127.0.0.1"
	Config.settings["last_ip"] = ip
	Config.save_settings()
	if Net.join_game(ip) != OK:
		_status.text = I18n.t("conn_failed")
		return
	_status.text = I18n.t("connecting")


func _build_lobby() -> void:
	var v := _screen("lobby")
	v.add_child(_lbl(I18n.t("lobby"), 44, Color("ffe14d")))
	_lobby_info = _lbl("", 16, Color(1, 1, 1, 0.8))
	v.add_child(_lobby_info)
	_lobby_list = VBoxContainer.new()
	_lobby_list.custom_minimum_size = Vector2(520, 220)
	v.add_child(_lobby_list)
	_lobby_chat = Label.new()
	_lobby_chat.add_theme_font_size_override("font_size", 15)
	_lobby_chat.custom_minimum_size = Vector2(520, 70)
	_lobby_chat.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_lobby_chat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_lobby_chat)
	var ce := LineEdit.new()
	ce.placeholder_text = I18n.t("chat_hint")
	ce.max_length = Net.CHAT_MAX
	ce.text_submitted.connect(func(t): if t.strip_edges() != "": Net.send_chat(t); ce.text = "")
	v.add_child(ce)
	Net.chat_received.connect(func(n, _tm, t): _chat_lines.append("%s: %s" % [n, t]); _chat_lines = _chat_lines.slice(-4); _lobby_chat.text = "\n".join(_chat_lines))
	_btn(I18n.t("switch_team"), func(): Net.request_switch_team(), v)
	_invite_btn = _btn(I18n.t("invite"), func(): SteamNet.invite(), v)
	_host_box = HBoxContainer.new()
	_host_box.add_theme_constant_override("separation", 8)
	v.add_child(_host_box)
	for t in [0, 1]:
		var b := Button.new()
		b.text = I18n.t("add_bot") + " (" + I18n.t("team_%d" % t).split(" ")[0] + ")"
		b.add_theme_color_override("font_color", Config.TEAM_COLORS[t])
		b.custom_minimum_size = Vector2(170, 42)
		b.pressed.connect(func(): Net.add_bot(t))
		_host_box.add_child(b)
	var rb := Button.new()
	rb.text = I18n.t("remove_bot")
	rb.custom_minimum_size = Vector2(150, 42)
	rb.pressed.connect(func(): Net.remove_bot())
	_host_box.add_child(rb)
	_mode_btn = _btn("", func(): Config.mode = "chaos" if Config.mode == "turns" else "turns"; _changed(), v)
	_map_btn = _btn("", func(): Config.map = House.MAPS[(House.MAPS.find(Config.map) + 1) % House.MAPS.size()]; _changed(), v)
	_rounds_btn = _btn("", _cycle_rounds, v)
	_setup_btn = _btn("", func(): Config.setup_time = _next_of(Config.SETUP_CHOICES, Config.setup_time); _changed(), v)
	_run_btn = _btn("", func(): Config.run_time = _next_of(Config.RUN_CHOICES, Config.run_time); _changed(), v)
	_rule_btn = _btn("", func(): var opts := ["random", "off"] + Config.MODIFIERS; Config.rule_choice = opts[(opts.find(Config.rule_choice) + 1) % opts.size()]; _changed(), v)
	_start_btn = _btn(I18n.t("start"), _on_start, v)
	_start_btn.add_theme_color_override("font_color", Color("7CFC9A"))
	_btn(I18n.t("leave"), func(): Net.leave(); show_screen("main"), v)


func _changed() -> void:
	_refresh_lobby()
	if Net.mode == "host":
		Net._broadcast()


func _next_of(choices: Array, cur: float) -> float:
	var i := choices.find(cur)
	return choices[(i + 1) % choices.size()]


func _cycle_rounds() -> void:
	Config.rounds = 2 if Config.rounds >= 6 else Config.rounds + 2
	_changed()


func _on_start() -> void:
	if not Net.can_start():
		_lobby_info.text = I18n.t("need_both_teams")
		return
	Net.start_match()


func _refresh_lobby() -> void:
	if _lobby_list == null:
		return
	for c in _lobby_list.get_children():
		c.queue_free()
	for t in [0, 1]:
		_lobby_list.add_child(_lbl(I18n.t("team_%d" % t), 22, Config.TEAM_COLORS[t]))
		for id in Net.players:
			var p: Dictionary = Net.players[id]
			if p["team"] != t:
				continue
			var me := " ◀" if id == Net.my_id() else ""
			var l := _lbl("●  " + str(p["name"]) + me, 20, Config.PLAYER_COLORS[int(p["color"]) % 8])
			_lobby_list.add_child(l)
	var host := Net.is_host()
	_host_box.visible = host
	_start_btn.visible = host
	_rounds_btn.visible = host
	_setup_btn.visible = host
	_run_btn.visible = host
	_rule_btn.visible = host
	_mode_btn.visible = host
	_map_btn.visible = host
	_map_btn.text = "%s: %s (%s)" % [I18n.t("map"), I18n.t("map_" + Config.map), I18n.t("size_" + House.MAP_SIZE.get(Config.map, "medium"))]
	_mode_btn.text = "%s: %s" % [I18n.t("mode"), I18n.t("mode_" + Config.mode)]
	_rounds_btn.visible = host and Config.mode == "turns"
	_setup_btn.visible = host and Config.mode == "turns"
	var rname: String = I18n.t("rule_" + Config.rule_choice) if Config.rule_choice in ["random", "off"] else I18n.t("m_" + Config.rule_choice)
	_rule_btn.text = "%s: %s" % [I18n.t("rule"), rname]
	_setup_btn.text = "%s: %d %s" % [I18n.t("phase_setup").capitalize(), Config.setup_time, I18n.t("sec")]
	_run_btn.text = "%s: %d %s" % [I18n.t("phase_run").capitalize(), Config.run_time, I18n.t("sec")]
	_invite_btn.visible = SteamNet.available() and SteamNet.lobby_id != 0
	_rounds_btn.text = "%s: %d   (~%d %s)" % [I18n.t("rounds"), Config.rounds, roundi(Config.match_minutes()), I18n.t("min")]
	if Net.mode == "host" and SteamNet.lobby_id != 0:
		_lobby_info.text = ""
	elif Net.mode == "host":
		_lobby_info.text = I18n.t("host_info", [Net.local_ip(), Config.PORT])
	elif Net.mode == "client":
		_lobby_info.text = I18n.t("waiting_host") + "   ·   %d × (%d + %d %s)  ~%d %s" % [Config.rounds, Config.setup_time, Config.run_time, I18n.t("sec"), roundi(Config.match_minutes()), I18n.t("min")]
	else:
		_lobby_info.text = ""


var _waiting_action := ""
var _key_buttons := {}


func _build_keys() -> void:
	var v := _screen("keys")
	v.add_child(_lbl(I18n.t("controls"), 36, Color("ffe14d")))
	var grid := GridContainer.new()
	grid.columns = 2
	v.add_child(grid)
	for a in Config.REBINDABLE:
		var l := _lbl(I18n.t("a_" + a), 18)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.custom_minimum_size = Vector2(260, 0)
		grid.add_child(l)
		var b := Button.new()
		b.custom_minimum_size = Vector2(170, 34)
		b.text = Config.key_name(a)
		b.pressed.connect(func(): _waiting_action = a; b.text = I18n.t("press_key"))
		grid.add_child(b)
		_key_buttons[a] = b
	_btn(I18n.t("back"), func(): show_screen("settings"), v)


func _input(e: InputEvent) -> void:
	if _waiting_action == "" or not (e is InputEventKey) or not e.pressed:
		return
	if e.physical_keycode != KEY_ESCAPE:
		Config.rebind(_waiting_action, e.physical_keycode)
		Config.save_settings()
	_key_buttons[_waiting_action].text = Config.key_name(_waiting_action)
	_waiting_action = ""
	get_viewport().set_input_as_handled()


func _build_settings() -> void:
	var v := _screen("settings")
	v.add_child(_lbl(I18n.t("settings"), 40, Color("ffe14d")))
	for k in Config.SLIDERS:
		var row := HBoxContainer.new()
		var l := _lbl(I18n.t(k), 20)
		l.custom_minimum_size = Vector2(160, 0)
		row.add_child(l)
		var sl := HSlider.new()
		sl.min_value = Config.SLIDERS[k][0]
		sl.max_value = Config.SLIDERS[k][1]
		sl.step = 0.05
		sl.value = float(Config.settings[k])
		sl.custom_minimum_size = Vector2(260, 24)
		sl.value_changed.connect(func(val): Config.settings[k] = val; Config.save_settings())
		row.add_child(sl)
		v.add_child(row)
	var fs := CheckBox.new()
	fs.text = I18n.t("fullscreen")
	fs.button_pressed = bool(Config.settings["fullscreen"])
	fs.toggled.connect(func(on): Config.settings["fullscreen"] = on; Config.save_settings())
	v.add_child(fs)
	var lr := HBoxContainer.new()
	lr.add_child(_lbl(I18n.t("lang") + ":", 20))
	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(200, 40)
	for i in I18n.ALL_LANGS.size():
		ob.add_item(I18n.LANG_NAMES[i], i)
	ob.selected = maxi(0, I18n.ALL_LANGS.find(I18n.lang))
	ob.item_selected.connect(func(i): var code: String = I18n.ALL_LANGS[i]; Config.settings["lang"] = code; Config.save_settings(); I18n.set_lang(code); main.rebuild_menu())
	lr.add_child(ob)
	v.add_child(lr)
	_btn(I18n.t("controls"), func(): show_screen("keys"), v)
	var cr := _lbl("", 15, Color(1, 1, 1, 0.85))
	cr.visible = false
	_btn(I18n.t("credits"), func(): cr.text = I18n.t("credits_text"); cr.visible = not cr.visible, v)
	v.add_child(cr)
	_btn(I18n.t("back"), func(): show_screen("main"), v)
