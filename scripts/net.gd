extends Node
## Connection + lobby (autoload "Net"). Host-authoritative: the host owns the player list.
## players: peer_id -> {name, team, color, bot, slot}. Bots use negative ids and only exist on the host.

signal players_changed
signal connected_ok
signal connection_failed
signal server_gone
signal match_begin(cfg: Dictionary)
signal lobby_return

var players := {}
var mode := "none"  # none | practice | host | client
var _next_bot := -1


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
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	mode = "none"


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
	_register.rpc_id(1, str(Config.settings["name"]))
	connected_ok.emit()


func _on_peer_connected(id: int) -> void:
	if is_host():
		_sync.rpc_id(id, players)


func _on_peer_disconnected(id: int) -> void:
	if is_host() and players.has(id):
		players.erase(id)
		_broadcast()


@rpc("any_peer", "reliable")
func _register(pname: String) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	pname = pname.strip_edges().substr(0, 16)
	if pname == "":
		pname = "Player"
	_add_player(id, pname, false)
	_broadcast()


@rpc("authority", "reliable")
func _sync(p: Dictionary) -> void:
	players = p
	players_changed.emit()


func _broadcast() -> void:
	players_changed.emit()
	if mode == "host":
		_sync.rpc(players)


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
	players[id] = {"name": pname, "team": team, "color": (slot - 1) % Config.PLAYER_COLORS.size(), "bot": bot, "slot": slot}


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
	if players.has(id):
		players[id]["team"] = 1 - int(players[id]["team"])
		_broadcast()


func can_start() -> bool:
	var c := _team_counts()
	return c[0] > 0 and c[1] > 0


func start_match() -> void:
	if not is_host() or not can_start():
		return
	var cfg := {"rounds": Config.rounds, "seed": randi(), "demo": Config.demo_mode,
		"setup": Config.setup_time, "run": Config.run_time}
	if mode == "host":
		_begin.rpc(players, cfg)
	_begin(players, cfg)


@rpc("authority", "reliable")
func _begin(p: Dictionary, cfg: Dictionary) -> void:
	players = p
	Config.rounds = int(cfg["rounds"])
	Config.demo_mode = bool(cfg["demo"])
	Config.setup_time = float(cfg["setup"])
	Config.run_time = float(cfg["run"])
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
