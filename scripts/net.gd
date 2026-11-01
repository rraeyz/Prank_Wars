extends Node
## Connection + lobby (autoload "Net"). Host-authoritative: the host owns the player list.
## players: peer_id -> {name, team, color, bot, slot}. Bots use negative ids and only exist on the host.

signal players_changed
signal connected_ok
signal connection_failed
signal server_gone
signal match_begin(cfg: Dictionary)
signal chat_received(pname: String, team: int, text: String)
signal lobby_return

var players := {}
var mode := "none"  # none | practice | host | client
var _next_bot := -1
var in_match := false
var _chat_next := {}  # peer -> earliest time of the next allowed message
const CHAT_MAX := 100
const QUICK := ["q_1", "q_2", "q_3", "q_4", "q_5", "q_6"]
signal rejected(reason: String)


func is_host() -> bool:
	return multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id()


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): _reset(); connection_failed.emit())
	multiplayer.server_disconnected.connect(func(): _reset(); server_gone.emit())


func _reset() -> void:
	Config.sandbox = false
	Config.tutorial = false
	in_match = false
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	mode = "none"


func start_sandbox() -> void:
	leave()
	mode = "practice"
	Config.sandbox = true
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	_add_player(1, str(Config.settings["name"]), false, 0)
	add_bot(1)
	add_bot(1)
	start_match()


func start_tutorial() -> void:
	start_sandbox_with(1)
	Config.tutorial = true
	start_match()


func start_sandbox_with(bots: int) -> void:
	leave()
	mode = "practice"
	Config.sandbox = true
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	_add_player(1, str(Config.settings["name"]), false, 0)
	for i in bots:
		add_bot(1)


func start_practice() -> void:
	leave()
	mode = "practice"
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	_add_player(1, str(Config.settings["name"]), false)
	add_bot(1)
	add_bot(1)
	add_bot(0)
	players_changed.emit()


func host_game(port := Config.PORT) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, Config.MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = "host"
	players.clear()
	_add_player(1, str(Config.settings["name"]), false)
	players_changed.emit()
	return OK


func join_game(ip: String, port := Config.PORT) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = "client"
	return OK


func use_peer(peer: MultiplayerPeer, m: String) -> void:
	## Used by SteamNet: start hosting / joining over an already created peer.
	multiplayer.multiplayer_peer = peer
	mode = m
	players.clear()
	if m == "host":
		_add_player(1, str(Config.settings["name"]), false)
		players_changed.emit()
		connected_ok.emit()


func leave() -> void:
	if has_node("/root/SteamNet"):
		get_node("/root/SteamNet").leave()
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	_reset()


func _on_connected() -> void:
	_register.rpc_id(1, str(Config.settings["name"]), Cosmetics.sanitize(Config.settings.get("look", {})))
	connected_ok.emit()


func _on_peer_connected(id: int) -> void:
	if is_host():
		_sync.rpc_id(id, players, lobby_cfg())


func _on_peer_disconnected(id: int) -> void:
	if is_host() and players.has(id):
		players.erase(id)
		_broadcast()


@rpc("any_peer", "reliable")
func _register(pname: String, look = {}) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if in_match or players.size() >= Config.MAX_PLAYERS:
		_reject.rpc_id(id, "in_match" if in_match else "full")
		get_tree().create_timer(0.5).timeout.connect(func(): if multiplayer.multiplayer_peer: multiplayer.multiplayer_peer.disconnect_peer(id))
		return
	if players.has(id):
		return
	# names are shown everywhere: keep them short and on one line
	pname = pname.replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges().substr(0, 16)
	if pname == "":
		pname = "Player"
	_add_player(id, pname, false)
	# shortcut: paid items are trusted from the client (cosmetic only); verify with Steam inventory serialization later
	players[id]["look"] = Cosmetics.sanitize(look)
	_broadcast()


@rpc("authority", "reliable")
func _reject(reason: String) -> void:
	rejected.emit(reason)
	leave()


@rpc("authority", "reliable")
func _sync(p: Dictionary, cfg: Dictionary) -> void:
	players = p
	# show the host's match settings in the client lobby
	Config.rounds = clampi(int(cfg.get("rounds", Config.rounds)), 1, 12)
	Config.setup_time = clampf(float(cfg.get("setup", Config.setup_time)), 10.0, 600.0)
	Config.run_time = clampf(float(cfg.get("run", Config.run_time)), 10.0, 600.0)
	var rc := str(cfg.get("rule", "random"))
	Config.rule_choice = rc if rc in ["random", "off"] or rc in Config.MODIFIERS else "random"
	Config.mode = "chaos" if str(cfg.get("mode", "turns")) == "chaos" else "turns"
	Config.map = str(cfg.get("map", "house")) if str(cfg.get("map", "house")) in House.MAPS else "house"
	players_changed.emit()


func lobby_cfg() -> Dictionary:
	return {"rounds": Config.rounds, "setup": Config.setup_time, "run": Config.run_time, "rule": Config.rule_choice, "mode": Config.mode, "map": Config.map}


func _broadcast() -> void:
	players_changed.emit()
	if has_node("/root/SteamNet"):
		get_node("/root/SteamNet").update_lobby_info()
	if mode == "host":
		_sync.rpc(players, lobby_cfg())


func _team_counts() -> Array:
	var c := [0, 0]
	for id in players:
		c[players[id]["team"]] += 1
	return c


func _free_slot() -> int:
	var used := {}
	for id in players:
		used[players[id]["slot"]] = true
	for s in range(1, 32):
		if not used.has(s):
			return s
	return 31


func _add_player(id: int, pname: String, bot: bool, team := -1) -> void:
	if team < 0:
		var c := _team_counts()
		team = 0 if c[0] <= c[1] else 1
	var slot := _free_slot()
	var rng := RandomNumberGenerator.new()
	rng.seed = slot * 31 + 7
	var look := Cosmetics.random_look(rng) if bot else Cosmetics.sanitize(Config.settings.get("look", {}))
	players[id] = {"name": pname, "team": team, "color": (slot - 1) % Config.PLAYER_COLORS.size(), "bot": bot, "slot": slot, "look": look}


func add_bot(team: int) -> void:
	if not is_host() or players.size() >= Config.MAX_PLAYERS:
		return
	var names := ["Bobo", "Lulu", "Tiko", "Mimi", "Zuzu", "Pipo", "Kiki", "Dodo"]
	var id := _next_bot
	_next_bot -= 1
	_add_player(id, names[(-id - 1) % names.size()] + " (bot)", true, team)
	_broadcast()


func remove_bot() -> void:
	if not is_host():
		return
	for id in players:
		if players[id]["bot"]:
			players.erase(id)
			break
	_broadcast()


func request_switch_team() -> void:
	if is_host():
		_switch_team(1)
	else:
		_req_switch.rpc_id(1)


@rpc("any_peer", "reliable")
func _req_switch() -> void:
	if is_host():
		_switch_team(multiplayer.get_remote_sender_id())


func _switch_team(id: int) -> void:
	if players.has(id) and not in_match:
		players[id]["team"] = 1 - int(players[id]["team"])
		_broadcast()


func can_start() -> bool:
	var c := _team_counts()
	return c[0] > 0 and c[1] > 0


func start_match() -> void:
	if not is_host() or not can_start():
		return
	var cfg := {"rounds": Config.rounds, "seed": randi(), "demo": Config.demo_mode, "sandbox": Config.sandbox, "tutorial": Config.tutorial,
		"setup": Config.setup_time, "run": Config.run_time, "rule": Config.rule_choice, "mode": Config.mode, "map": Config.map}
	if mode == "host":
		_begin.rpc(players, cfg)
	_begin(players, cfg)


@rpc("authority", "reliable")
func _begin(p: Dictionary, cfg: Dictionary) -> void:
	players = p
	Config.rounds = clampi(int(cfg["rounds"]), 1, 12)
	Config.demo_mode = bool(cfg["demo"])
	Config.sandbox = bool(cfg.get("sandbox", false))
	Config.tutorial = bool(cfg.get("tutorial", false))
	Config.setup_time = float(cfg["setup"])
	Config.run_time = float(cfg["run"])
	var rc := str(cfg.get("rule", "random"))
	Config.rule_choice = rc if rc in ["random", "off"] or rc in Config.MODIFIERS else "random"
	Config.mode = "chaos" if str(cfg.get("mode", "turns")) == "chaos" else "turns"
	Config.map = str(cfg.get("map", "house")) if str(cfg.get("map", "house")) in House.MAPS else "house"
	if Config.mode == "chaos":
		Config.rounds = 1
	match_begin.emit(cfg)


func back_to_lobby() -> void:
	if not is_host():
		return
	if mode == "host":
		_lobby.rpc()
	_lobby()


@rpc("authority", "reliable")
func _lobby() -> void:
	lobby_return.emit()


func local_ip() -> String:
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("25.") or a.begins_with("100."):
			return a
	return "127.0.0.1"


func player_by_slot(slot: int) -> Dictionary:
	for id in players:
		if players[id]["slot"] == slot:
			return players[id]
	return {}


func peer_of_slot(slot: int) -> int:
	for id in players:
		if players[id]["slot"] == slot:
			return id
	return 0


# ------------------------------------------------------------------ chat (host relays and sanitizes)

## Send a chat line. Quick phrases are sent as "@q_N" and translated on each screen.
func send_chat(text: String) -> void:
	if mode == "client":
		_chat_req.rpc_id(1, text)
	else:
		_relay(my_id(), text)


@rpc("any_peer", "reliable")
func _chat_req(text: String) -> void:
	if is_host():
		_relay(multiplayer.get_remote_sender_id(), text)


func _relay(id: int, text: String) -> void:
	if not players.has(id):
		return
	var now := Time.get_ticks_msec() * 0.001
	if _chat_next.get(id, 0.0) > now:
		return
	_chat_next[id] = now + 0.8
	text = clean_chat(text)
	if text == "" or (text.begins_with("@") and not text.substr(1) in QUICK):
		return
	var p: Dictionary = players[id]
	if mode == "host":
		_chat.rpc(str(p["name"]), int(p["team"]), text)
	_chat(str(p["name"]), int(p["team"]), text)


static func clean_chat(text: String) -> String:
	var out := ""
	for ch in text.substr(0, CHAT_MAX):
		out += " " if ch.unicode_at(0) < 32 else ch
	return out.strip_edges()


@rpc("authority", "reliable")
func _chat(pname: String, team: int, text: String) -> void:
	if text.begins_with("@"):
		text = I18n.t(text.substr(1))
	chat_received.emit(pname, team, text)
