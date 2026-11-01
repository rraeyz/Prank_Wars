extends Node
## Optional Steam layer (autoload "SteamNet"). Works only when the GodotSteam GDExtension is present
## (CI adds it to the Windows build) and the Steam client is running. Otherwise the game uses ENet.
## Flow: host -> createLobby -> SteamMultiplayerPeer.create_host; friends join via invite/overlay
## -> joinLobby -> create_client(lobby owner). App id 480 (Spacewar) until we have our own.

signal status(text: String)
signal lobbies_found(list: Array)  # [{"id", "name", "players", "mode", "map"}]

const APP_ID := 480
const LOBBY_FRIENDS_ONLY := 1
const LOBBY_PUBLIC := 2
var _public := false

var steam: Object = null
var ready_ok := false
var lobby_id := 0
var owned_items := {}  # Steam inventory item definition -> true
const PLAYTIME_GENERATOR := 900  # itemdef of the playtime drop generator (steam/itemdefs.json)
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
	if steam.has_signal("inventory_result_ready"):
		steam.inventory_result_ready.connect(_on_inventory)
		steam.getAllItems()
	steam.lobby_created.connect(_on_lobby_created)
	if steam.has_signal("lobby_match_list"):
		steam.lobby_match_list.connect(_on_lobby_list)
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


func host_lobby(public := false) -> void:
	if not ready_ok:
		return
	Net.leave()
	_want_host = true
	_public = public
	steam.createLobby(LOBBY_PUBLIC if public else LOBBY_FRIENDS_ONLY, Config.MAX_PLAYERS)
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
	steam.setLobbyData(id, "name", str(Config.settings["name"]) + "'s room")
	steam.setLobbyData(id, "ver", Config.VERSION)
	update_lobby_info()
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


# ------------------------------------------------------------------ inventory (cosmetics store, playtime drops)

func _on_inventory(result: int, handle: int) -> void:
	if result != 1 or not steam.has_method("getResultItems"):
		return
	for it in steam.getResultItems(handle):
		if it is Dictionary and it.has("item_definition"):
			owned_items[int(it["item_definition"])] = true
	if steam.has_method("destroyResult"):
		steam.destroyResult(handle)


## Opens the Steam overlay checkout for one item (price is set in Steamworks).
func purchase(itemdef: int) -> void:
	if ready_ok and itemdef > 0 and steam.has_method("startPurchase"):
		steam.startPurchase([itemdef], [1])


## Called after a match: Steam decides if a free playtime item drops.
func playtime_drop() -> void:
	if ready_ok and steam.has_method("triggerItemDrop"):
		steam.triggerItemDrop(PLAYTIME_GENERATOR)


# ------------------------------------------------------------------ public rooms (Steam matchmaking, no server cost)

## Ask Steam for open Prank Wars rooms anywhere in the world.
func find_lobbies() -> void:
	if not ready_ok:
		return
	if steam.has_method("addRequestLobbyListStringFilter"):
		steam.addRequestLobbyListStringFilter("game", "prank_wars", 0)
	if steam.has_method("addRequestLobbyListDistanceFilter"):
		steam.addRequestLobbyListDistanceFilter(3)
	steam.requestLobbyList()
	status.emit(I18n.t("searching"))


func _on_lobby_list(ids: Array) -> void:
	var out := []
	for id in ids:
		if str(steam.getLobbyData(id, "ver")) != Config.VERSION:
			continue  # different game version: can't play together
		out.append({"id": id, "name": str(steam.getLobbyData(id, "name")).substr(0, 32), "players": int(steam.getNumLobbyMembers(id)),
			"mode": str(steam.getLobbyData(id, "mode")), "map": str(steam.getLobbyData(id, "map")), "busy": str(steam.getLobbyData(id, "busy")) == "1"})
	lobbies_found.emit(out)


## Host: keep the room card in the browser up to date; hide full / in-progress rooms.
func update_lobby_info() -> void:
	if not ready_ok or lobby_id == 0 or not Net.is_host():
		return
	steam.setLobbyData(lobby_id, "mode", Config.mode)
	steam.setLobbyData(lobby_id, "map", Config.map)
	steam.setLobbyData(lobby_id, "busy", "1" if Net.in_match else "0")
	if steam.has_method("setLobbyJoinable"):
		steam.setLobbyJoinable(lobby_id, not Net.in_match and Net.players.size() < Config.MAX_PLAYERS)
