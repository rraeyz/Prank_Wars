extends Node
## Optional Steam layer (autoload "SteamNet"). Works only when the GodotSteam GDExtension is present
## (CI adds it to the Windows build) and the Steam client is running. Otherwise the game uses ENet.
## Flow: host -> createLobby -> SteamMultiplayerPeer.create_host; friends join via invite/overlay
## -> joinLobby -> create_client(lobby owner). App id 480 (Spacewar) until we have our own.

signal status(text: String)

const APP_ID := 480
const LOBBY_FRIENDS_ONLY := 1

var steam: Object = null
var ready_ok := false
var lobby_id := 0
var _want_host := false


func _ready() -> void:
	if not Engine.has_singleton("Steam") or DisplayServer.get_name() == "headless":
		return
	steam = Engine.get_singleton("Steam")
	# steam_appid.txt next to the exe wins (CI writes 480 now; put the real app id there later)
	var app_id := APP_ID
	var f := OS.get_executable_path().get_base_dir().path_join("steam_appid.txt")
	if FileAccess.file_exists(f):
		app_id = FileAccess.get_file_as_string(f).strip_edges().to_int()
	var r = steam.steamInitEx(app_id, false)
	ready_ok = r is Dictionary and int(r.get("status", 1)) == 0
	if not ready_ok:
		push_warning("Steam init failed: %s" % str(r))
		return
	steam.lobby_created.connect(_on_lobby_created)
	steam.lobby_joined.connect(_on_lobby_joined)
	steam.join_requested.connect(_on_join_requested)
	var pname := str(steam.getPersonaName())
	if pname != "":
		Config.settings["name"] = pname.substr(0, 16)
	# launched from a friend's invite: "+connect_lobby <id>"
	var args := OS.get_cmdline_args()
	for i in args.size() - 1:
		if args[i] == "+connect_lobby":
			join_lobby(int(args[i + 1]))


func available() -> bool:
	return ready_ok


func _process(_d: float) -> void:
	if ready_ok:
		steam.run_callbacks()


func host_lobby() -> void:
	if not ready_ok:
		return
	Net.leave()
	_want_host = true
	steam.createLobby(LOBBY_FRIENDS_ONLY, Config.MAX_PLAYERS)
	status.emit(I18n.t("connecting"))


func invite() -> void:
	if ready_ok and lobby_id != 0:
		steam.activateGameOverlayInviteDialog(lobby_id)


func join_lobby(id: int) -> void:
	if not ready_ok:
		return
	Net.leave()
	_want_host = false
	steam.joinLobby(id)
	status.emit(I18n.t("connecting"))


func leave() -> void:
	if ready_ok and lobby_id != 0:
		steam.leaveLobby(lobby_id)
		steam.setRichPresence("connect", "")
	lobby_id = 0


func _on_lobby_created(result: int, id: int) -> void:
	if result != 1:
		status.emit(I18n.t("host_failed"))
		return
	lobby_id = id
	steam.setLobbyData(id, "game", "prank_wars")
	steam.setRichPresence("connect", "+connect_lobby %d" % id)
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	var err: int = peer.create_host(0)
	if err != OK:
		status.emit(I18n.t("host_failed"))
		return
	Net.use_peer(peer, "host")
	invite()


func _on_lobby_joined(id: int, _perm: int, _locked: bool, response: int) -> void:
	if _want_host:
		return
	if response != 1:
		status.emit(I18n.t("conn_failed"))
		return
	lobby_id = id
	var owner_id: int = steam.getLobbyOwner(id)
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	var err: int = peer.create_client(owner_id, 0)
	if err != OK:
		status.emit(I18n.t("conn_failed"))
		return
	Net.use_peer(peer, "client")


func _on_join_requested(id: int, _friend: int) -> void:
	join_lobby(id)
