extends Node
## Entry point: menu <-> match. Also handles command-line automation flags:
##   --practice  start a bot match at once     --quick   short timers
##   --host / --join=IP  --autostart=N (host starts when N humans joined)
##   --rounds=N  --quit-after=SEC  --shot=FILE@SEC (screenshot)  --name=NAME  --demo

var menu: CanvasLayer
var world: Node3D
var bg: Node3D
var args := {}
var _t := 0.0
var _shots := []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("name"):
		Config.settings["name"] = args["name"]
	if args.has("quick"):
		Config.setup_time = 15.0
		Config.run_time = 25.0
		Config.intro_time = 1.0
		Config.score_time = 2.0
	if args.has("rounds"):
		Config.rounds = int(args["rounds"])
	if args.has("demo") or OS.has_feature("demo"):
		Config.demo_mode = true
	if args.has("shot"):
		for s in str(args["shot"]).split(","):
			var p := s.split("@")
			_shots.append([p[0], float(p[1])])
	if args.has("nettest"):
		var np: Node = load("res://tests/net_probe.gd").new()
		np.role = str(args["nettest"])
		add_child(np)
	if args.has("countprobe"):
		add_child(load("res://tests/count_probe.gd").new())
	if args.has("nanprobe"):
		add_child(load("res://tests/nan_probe.gd").new())
	Net.match_begin.connect(_on_match_begin)
	Net.lobby_return.connect(_on_lobby_return)
	Net.server_gone.connect(to_menu)
	_make_bg()
	rebuild_menu()
	Sfx.play_music()
	if args.has("sandbox"):
		Net.start_sandbox.call_deferred()
	elif args.has("practice"):
		Net.start_practice()
		Net.start_match.call_deferred()
	elif args.has("host"):
		Net.host_game()
		menu.show_screen("lobby")
	elif args.has("join"):
		Net.join_game(str(args["join"]))


func rebuild_menu() -> void:
	if menu:
		menu.queue_free()
	menu = load("res://scripts/menu.gd").new()
	menu.main = self
	add_child(menu)
	menu.visible = world == null


func _make_bg() -> void:
	bg = Node3D.new()
	add_child(bg)
	var h := House.new()
	bg.add_child(h)
	h.build()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.shadow_enabled = true
	bg.add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("9fd8ff")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("fff4e6")
	e.ambient_light_energy = 0.6
	env.environment = e
	bg.add_child(env)
	var cam := Camera3D.new()
	cam.name = "BgCam"
	bg.add_child(cam)
	h.roof.visible = false


func _process(delta: float) -> void:
	_t += delta
	if bg:
		var cam: Camera3D = bg.get_node("BgCam")
		var a := _t * 0.08
		cam.position = Vector3(sin(a) * 17.0, 13.0, cos(a) * 17.0 + 2.0)
		cam.look_at(Vector3(0, 0, 1), Vector3.UP)
	if args.has("autostart") and Net.is_host() and world == null and Net.mode == "host":
		if Net.players.size() >= int(args["autostart"]):
			if not Net.can_start():
				Net.add_bot(1)
			Net.start_match()
	if args.has("quit-after") and _t > float(args["quit-after"]):
		get_tree().quit()
	for s in _shots:
		if _t >= s[1] and s.size() == 2:
			s.append(true)
			var img := get_viewport().get_texture().get_image()
			img.save_png(s[0])
			print("screenshot ", s[0])


func _on_match_begin(_cfg: Dictionary) -> void:
	if world:
		world.queue_free()
	if bg:
		bg.queue_free()
		bg = null
	menu.visible = false
	world = World.new()
	add_child(world)


func _on_lobby_return() -> void:
	_free_world()
	menu.visible = true
	menu.show_screen("lobby")


func _free_world() -> void:
	if world:
		world.queue_free()
		world = null
	Sfx.pitch_scale = 1.0
	if bg == null:
		_make_bg()


func to_menu() -> void:
	Net.leave()
	_free_world()
	menu.visible = true
	menu.show_screen("main")
