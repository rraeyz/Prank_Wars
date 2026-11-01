extends CanvasLayer
## In-game HUD, built in code. Reads state from World every frame.

var world: Node
var _root: Control
var _score_l: Label
var _score_r: Label
var _phase: Label
var _timer: Label
var _sub: Label
var _tasks: VBoxContainer
var _prompt: Label
var _bar: ProgressBar
var _palette: HBoxContainer
var _budget: Label
var _feed: VBoxContainer
var _popup: Label
var _toast: Label
var _help: Label
var _remote: Label
var _blind: ColorRect
var _confetti: Control
var _replay_banner: Control
var _replay_title: Label
var _summary: PanelContainer
var _summary_text: Label
var _end: PanelContainer
var _end_text: Label
var _end_lobby: Button
var _pause: PanelContainer
var _popup_t := 0.0
var _toast_t := 0.0
var _blind_t := 0.0
var _blind_max := 1.0
var _last_sec := -1
var _tip: Label
var _awards: Label
var _rule: Label
var _tip_t := 0.0


func _ready() -> void:
	layer = 5
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_blind = ColorRect.new()
	_blind.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blind.color = Color(1, 1, 1, 0)
	_root.add_child(_blind)
	_confetti = Control.new()
	_confetti.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confetti.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_confetti)

	# top bar
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 10
	top.offset_left = 20
	top.offset_right = -20
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top)
	_score_l = _lbl("0", 44, Config.TEAM_COLORS[0])
	_score_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_score_l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(_score_l)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(mid)
	_phase = _lbl("", 26, Color.WHITE)
	_phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_phase)
	_timer = _lbl("", 40, Color("ffe14d"))
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_timer)
	_sub = _lbl("", 18, Color(1, 1, 1, 0.9))
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_sub)
	_rule = _lbl("", 18, Color("ffb3e6"))
	_rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_rule)
	_tip = _lbl("", 17, Color("bfe9ff"))
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_tip.offset_left = -330
	_tip.offset_right = 330
	_tip.offset_top = 182
	_tip.offset_bottom = 232
	_root.add_child(_tip)
	_score_r = _lbl("0", 44, Config.TEAM_COLORS[1])
	_score_r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_score_r.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(_score_r)

	# tasks (left)
	_tasks = VBoxContainer.new()
	_tasks.position = Vector2(20, 120)
	_tasks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_tasks)

	# feed (right)
	_feed = VBoxContainer.new()
	_feed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_feed.offset_left = -420
	_feed.offset_top = 120
	_feed.offset_right = -20
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_feed)

	# remote list (right bottom)
	_remote = _lbl("", 20, Color.WHITE)
	_remote.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_remote.offset_left = -520
	_remote.offset_top = -220
	_remote.offset_right = -20
	_remote.offset_bottom = -60
	_remote.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_root.add_child(_remote)

	# popup + toast (center)
	_popup = _lbl("", 50, Color("ffe14d"))
	_popup.set_anchors_preset(Control.PRESET_CENTER)
	_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_popup.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_popup.offset_left = -520
	_popup.offset_right = 520
	_popup.offset_top = -230
	_popup.offset_bottom = -70
	_popup.pivot_offset = Vector2(520, 80)
	_root.add_child(_popup)
	_toast = _lbl("", 26, Color.WHITE)
	_toast.set_anchors_preset(Control.PRESET_CENTER)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.offset_left = -500
	_toast.offset_right = 500
	_toast.offset_top = 80
	_toast.offset_bottom = 120
	_root.add_child(_toast)

	# bottom: prompt, palette, help
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -190
	bottom.offset_bottom = -10
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bottom)
	_prompt = _lbl("", 24, Color.WHITE)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_prompt)
	var bc := CenterContainer.new()
	bc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(bc)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(260, 14)
	_bar.show_percentage = false
	_bar.max_value = 1.0
	bc.add_child(_bar)
	_budget = _lbl("", 22, Color("ffe14d"))
	_budget.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_budget)
	var pc := CenterContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(pc)
	_palette = HBoxContainer.new()
	_palette.add_theme_constant_override("separation", 4)
	pc.add_child(_palette)
	_help = _lbl("", 16, Color(1, 1, 1, 0.75))
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_help)

	# replay
	_replay_banner = Control.new()
	_replay_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_replay_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_replay_banner.visible = false
	_root.add_child(_replay_banner)
	for side in [0, 1]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 0.85)
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if side == 0 else Control.PRESET_BOTTOM_WIDE)
		if side == 0:
			bar.offset_bottom = 70
		else:
			bar.offset_top = -70
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_replay_banner.add_child(bar)
	_replay_title = _lbl("", 34, Color("ff4d6d"))
	_replay_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_replay_title.offset_top = 14
	_replay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_replay_banner.add_child(_replay_title)
	var wm := _lbl("PRANK WARS", 30, Color("ffe14d"))
	wm.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	wm.offset_left = -420
	wm.offset_top = -62
	wm.offset_right = -24
	wm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_replay_banner.add_child(wm)
	var wl := _lbl(I18n.t("wishlist"), 16, Color.WHITE)
	wl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	wl.offset_left = -420
	wl.offset_top = -28
	wl.offset_right = -24
	wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_replay_banner.add_child(wl)

	# round summary / end
	_summary = _panel()
	_summary_text = _lbl("", 26, Color.WHITE)
	_summary_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.add_child(_summary_text)
	_end = _panel()
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 14)
	_end.add_child(ev)
	_end_text = _lbl("", 40, Color("ffe14d"))
	_end_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev.add_child(_end_text)
	_awards = _lbl("", 20, Color.WHITE)
	_awards.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev.add_child(_awards)
	_end_lobby = _btn(I18n.t("back_to_lobby"), func(): Net.back_to_lobby())
	ev.add_child(_end_lobby)
	ev.add_child(_btn(I18n.t("to_menu"), func(): get_tree().root.get_node("Main").to_menu()))

	# pause
	_pause = _panel()
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 12)
	_pause.add_child(pv)
	pv.add_child(_lbl("PRANK WARS", 36, Color("ffe14d")))
	pv.add_child(_btn(I18n.t("resume"), func(): _pause.visible = false))
	for k in ["master", "music", "sfx"]:
		var row := HBoxContainer.new()
		row.add_child(_lbl(I18n.t(k), 18, Color.WHITE))
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = float(Config.settings[k])
		sl.custom_minimum_size = Vector2(200, 20)
		sl.value_changed.connect(func(v): Config.settings[k] = v; Config.save_settings())
		row.add_child(sl)
		pv.add_child(row)
	pv.add_child(_btn(I18n.t("to_menu"), func(): get_tree().root.get_node("Main").to_menu()))


func _lbl(t: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", maxi(4, size / 5))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _btn(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", 22)
	b.custom_minimum_size = Vector2(280, 46)
	b.pressed.connect(func(): Sfx.play("click"); cb.call())
	return b


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.15, 0.88)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(28)
	sb.border_color = Color("ffe14d")
	sb.set_border_width_all(3)
	p.add_theme_stylebox_override("panel", sb)
	p.visible = false
	_root.add_child(p)
	return p


func _focus_in(root: Node) -> void:
	for c in root.find_children("*", "BaseButton", true, false):
		if c.is_visible_in_tree():
			c.grab_focus.call_deferred()
			return


func is_blocking() -> bool:
	return _pause.visible or _end.visible


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("menu"):
		_pause.visible = not _pause.visible
		if _pause.visible:
			_focus_in(_pause)
	if e.is_action_pressed("screenshot"):
		DirAccess.make_dir_recursive_absolute("user://screenshots")
		var path := "user://screenshots/prankwars_%s.png" % Time.get_datetime_string_from_system().replace(":", "-")
		get_viewport().get_texture().get_image().save_png(path)
		toast(I18n.t("shot_saved", [ProjectSettings.globalize_path(path)]))


# ------------------------------------------------------------------ events from World

func on_phase(p: String) -> void:
	_summary.visible = p == "score"
	_end.visible = p == "end"
	if p == "score":
		var rs: Array = world.round_scores
		_summary_text.text = "%s\n\n%s  +%d\n%s  +%d\n\n%d  —  %d" % [I18n.t("phase_score"),
			I18n.t("team_0"), rs[0], I18n.t("team_1"), rs[1], world.scores[0], world.scores[1]]
	if p == "end":
		var sc: Array = world.scores
		var w := -1 if sc[0] == sc[1] else (0 if sc[0] > sc[1] else 1)
		_end_text.text = (I18n.t("draw") if w < 0 else I18n.t("winner", [I18n.t("team_%d" % w)])) + "\n%d — %d" % [sc[0], sc[1]]
		if w >= 0:
			_end_text.add_theme_color_override("font_color", Config.TEAM_COLORS[w])
		_end_lobby.visible = Net.is_host()
		_focus_in.call_deferred(_end)
		Sfx.play("win")
	if p == "intro":
		var txt := I18n.t("round_n", [world.round_i + 1, Config.rounds]) + "\n" + I18n.t("intro_trap", [I18n.t("team_%d" % world.trapper_team)])
		if world.modifier != "":
			txt += "\n" + I18n.t("rule") + ": " + I18n.t("m_" + world.modifier) + " — " + I18n.t("md_" + world.modifier)
		popup(txt, Config.TEAM_COLORS[world.trapper_team])
	if p == "setup":
		popup(I18n.t("you_trap") if world.local_is_trapper() else I18n.t("you_run"), Color.WHITE)
	if p == "run":
		popup(I18n.t("runners_enter"), Color("ffe14d"))


func show_awards(list: Array) -> void:
	var t := ""
	for a in list:
		t += "%s:  %s  (%d)\n" % [I18n.t("aw_" + str(a[0])), a[1], a[2]]
	_awards.text = t


func on_replay(on: bool, links: int, pts: int) -> void:
	_replay_banner.visible = on
	_replay_title.text = "%s  —  %s x%d  +%d" % [I18n.t("phase_replay"), I18n.t("best_prank"), links, pts]


func feed(text: String, c: Color) -> void:
	var l := _lbl(text, 20, c.lightened(0.25))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.set_meta("t", 6.0)
	_feed.add_child(l)
	while _feed.get_child_count() > 7:
		_feed.get_child(0).free()


func popup(text: String, c: Color) -> void:
	_popup.text = text
	_popup.add_theme_color_override("font_color", c)
	_popup_t = 2.2


func toast(text: String) -> void:
	_toast.text = text
	_toast_t = 2.0


func blind(kind: String, dur: float) -> void:
	_blind_t = dur
	_blind_max = dur
	if kind == "flour":
		_blind.color = Color(1, 1, 1, 0.95)
	else:
		_blind.color = Color(1, 1, 1, 0)
		for i in 60:
			var r := ColorRect.new()
			r.color = Color.from_hsv(randf(), 0.8, 1.0)
			r.size = Vector2(randf_range(14, 40), randf_range(8, 18))
			r.position = Vector2(randf() * _root.size.x, randf() * _root.size.y)
			r.rotation = randf() * TAU
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_confetti.add_child(r)


# ------------------------------------------------------------------ per frame

func _process(delta: float) -> void:
	if world == null:
		return
	var rp: bool = world.replaying
	_tasks.visible = not rp
	_feed.visible = not rp
	_score_l.visible = not rp
	_score_r.visible = not rp
	_phase.visible = not rp
	_sub.visible = not rp
	var sc: Array = world.scores
	_score_l.text = "%s\n%d" % [I18n.t("team_0"), sc[0]]
	_score_r.text = "%s\n%d" % [I18n.t("team_1"), sc[1]]
	_score_l.add_theme_font_size_override("font_size", 30)
	_score_r.add_theme_font_size_override("font_size", 30)
	var p: String = world.phase
	_phase.text = I18n.t("phase_" + p) if p != "none" else ""
	var tl: float = world.time_left()
	_timer.text = "" if p in ["end", "none", "replay", "sandbox"] else "%d" % ceili(tl)
	if p in ["setup", "run"] and tl <= 5.0 and tl > 0.0 and ceili(tl) != _last_sec:
		_last_sec = ceili(tl)
		Sfx.play("tick")
	_sub.visible = _sub.visible and p != "sandbox"
	_sub.text = I18n.t("round_n", [world.round_i + 1, Config.rounds]) + "   ·   " + I18n.t("team_%d" % world.trapper_team) + " ⚑"
	# rotating tips (more of them in the first round)
	_tip_t += delta
	var tip_key := ""
	if p == "setup":
		tip_key = "tips_trap" if world.local_is_trapper() else "tips_warm"
	elif p == "run" and not world.local_is_trapper():
		tip_key = "tips_run"
	elif p == "sandbox":
		tip_key = "tips_trap"
	_tip.visible = tip_key != "" and not rp and (world.round_i < 2 or p == "sandbox")
	if _tip.visible:
		_tip.text = I18n.tip(tip_key, int(_tip_t / 7.0))
	# tasks
	var tasks: Array = world.tasks
	while _tasks.get_child_count() < tasks.size() + 1:
		_tasks.add_child(_lbl("", 20, Color.WHITE))
	while _tasks.get_child_count() > tasks.size() + 1:
		_tasks.get_child(_tasks.get_child_count() - 1).free()
	(_tasks.get_child(0) as Label).text = I18n.t("tasks") + ":"
	for i in tasks.size():
		var t: Dictionary = tasks[i]
		var l: Label = _tasks.get_child(i + 1)
		var steps: int = Config.TASKS[t["id"]].size()
		var mark := "✔ " if t["done"] else ("◐ " if t["step"] > 0 else "○ ")
		l.text = mark + I18n.t("t_" + str(t["id"])) + ("" if steps < 2 or t["done"] else "  (%d/%d)" % [t["step"], steps])
		l.add_theme_color_override("font_color", Color("7CFC9A") if t["done"] else Color.WHITE)
	# prompt
	var pr: Array = world.local_prompt
	var me: Avatar = world.local_avatar()
	var show_prompt: bool = pr[0] != "" and me != null and me.visible
	_prompt.text = ("[E] " + str(pr[0])) if show_prompt else ""
	_bar.visible = show_prompt and float(pr[1]) > 0.0
	_bar.value = float(pr[1])
	# palette
	var trapper_setup: bool = world.building() and world.local_is_trapper()
	_palette.visible = trapper_setup
	_budget.visible = trapper_setup
	if trapper_setup:
		_budget.text = "%s: %d / %d" % [I18n.t("budget"), world.budget[world.local_team()], Config.BUDGET]
		if p == "sandbox":
			_budget.text = I18n.t("budget") + ": ∞"
		_update_palette()
	# remote list
	var rtext := ""
	if (p == "run" and world.local_is_trapper()) or p == "sandbox":
		var rl: Array = world.remote_pranks(world.local_team())
		for i in rl.size():
			rtext += "[%d] %s\n" % [i + 1, I18n.t("p_" + rl[i].type)]
	if p == "run" and world.local_is_trapper() and me != null and not me.visible:
		var gw: float = world.ghost_wait_local()
		rtext += (I18n.t("ghost_ready") if gw <= 0.0 else I18n.t("ghost_wait", [ceili(gw)])) + "\n"
	if p == "run" and not world.local_is_trapper() and me != null and me.visible:
		var rw: float = world.reveal_wait_local()
		rtext += (I18n.t("sniff_ready") if rw <= 0.0 else I18n.t("sniff_wait", [ceili(rw)])) + "\n"
	_remote.text = rtext
	_rule.text = (I18n.t("rule") + ": " + I18n.t("m_" + world.modifier)) if world.modifier != "" else ""
	if world.rush and p == "run":
		_rule.text = I18n.t("rush_short") + ("   ·   " + _rule.text if _rule.text != "" else "")
	# help
	var h := ""
	match p:
		"setup":
			h = I18n.t("setup_help") + "   " + I18n.t("run_help_runner") if world.local_is_trapper() else I18n.t("warmup_help")
		"run":
			h = I18n.t("run_help_trapper") if world.local_is_trapper() else I18n.t("run_help_runner")
		"sandbox":
			h = I18n.t("sandbox_help")
	_help.text = h
	# timers
	if _popup_t > 0.0:
		_popup_t -= delta
		var k := clampf(_popup_t / 2.2, 0.0, 1.0)
		var s := 1.0 + 0.25 * pow(maxf(0.0, (k - 0.85) / 0.15), 2.0)
		_popup.scale = Vector2(s, s)
		_popup.modulate.a = clampf(_popup_t * 2.0, 0.0, 1.0)
	else:
		_popup.text = ""
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t * 2.0, 0.0, 1.0)
	else:
		_toast.text = ""
	if _blind_t > 0.0:
		_blind_t -= delta
		var a := clampf(_blind_t / _blind_max, 0.0, 1.0)
		if _blind.color.a > 0.0 or _confetti.get_child_count() == 0:
			_blind.color.a = 0.95 * a
		_confetti.modulate.a = a
		if _blind_t <= 0.0:
			_blind.color.a = 0.0
			for c in _confetti.get_children():
				c.queue_free()
	for l in _feed.get_children():
		var tt: float = l.get_meta("t") - delta
		l.set_meta("t", tt)
		l.modulate.a = clampf(tt, 0.0, 1.0)
		if tt <= 0.0:
			l.queue_free()


func _update_palette() -> void:
	var list: Array = Config.enabled_pranks()
	if _palette.get_child_count() != list.size():
		for c in _palette.get_children():
			c.free()
		for i in list.size():
			var pc := PanelContainer.new()
			var v := VBoxContainer.new()
			pc.add_child(v)
			var n := _lbl("", 14, Color.WHITE)
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			n.custom_minimum_size = Vector2(74, 0)
			v.add_child(n)
			var c2 := _lbl("", 13, Color("ffe14d"))
			c2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(c2)
			pc.custom_minimum_size = Vector2(78, 48)
			_palette.add_child(pc)
	var budget: int = world.budget[world.local_team()]
	# only 12 cards fit on screen: slide the window with the selection
	var first := clampi(world.selected - 6, 0, maxi(0, list.size() - 12))
	for i in list.size():
		var pc: PanelContainer = _palette.get_child(i)
		pc.visible = i >= first and i < first + 12
		var t: String = list[i]
		var def: Dictionary = Config.PRANKS[t]
		var v: VBoxContainer = pc.get_child(0)
		(v.get_child(0) as Label).text = I18n.t("p_" + t)
		var sel_i: bool = i == world.selected
		(v.get_child(1) as Label).text = ("%d ●" % def["cost"]) + ((" " + I18n.t("tr_remote")) if def["trigger"] == "remote" else "")
		if sel_i:
			_budget.text += "     ▶ %s: %s" % [I18n.t("p_" + t), I18n.t("pl_" + def["place"])]
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(4)
		var sel: bool = i == world.selected
		sb.bg_color = Color(0.95, 0.55, 0.15, 0.95) if sel else Color(0.1, 0.1, 0.2, 0.75)
		if int(def["cost"]) > budget:
			sb.bg_color = sb.bg_color.darkened(0.6)
		if sel:
			sb.set_border_width_all(3)
			sb.border_color = Color.WHITE
		pc.add_theme_stylebox_override("panel", sb)
		(v.get_child(0) as Label).add_theme_font_size_override("font_size", 14 if sel else 13)
