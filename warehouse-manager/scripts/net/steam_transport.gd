class_name SteamTransport
extends NetTransport

## Shipping transport: Steam P2P via GodotSteam's [SteamMultiplayerPeer].
##
## Hosting creates a Steam lobby and binds the peer to it; joining enters the
## lobby and connects to its owner. GodotSteam does the socket work — see
## host_with_lobby() / connect_to_lobby() in the GodotSteam docs.
##
## Note this transport can only ever be tested with one player per machine:
## Steam permits a single logged-in client per PC. Four-player testing happens
## on [ENetTransport]; this path is validated two-up across two machines.

## Valve's Spacewar test app. Replace with the real app ID once the Steam page
## exists — steam_appid.txt in the project root must match.
const DEV_APP_ID := 480

## k_EChatRoomEnterResponseSuccess — GodotSteam re-exports Valve's value.
const LOBBY_ENTER_SUCCESS := 1

var _lobby_id := 0
var _steam_ready := false


func host(max_players: int) -> void:
	if not _ensure_steam():
		return
	if not Steam.lobby_created.is_connected(_on_lobby_created):
		Steam.lobby_created.connect(_on_lobby_created, CONNECT_ONE_SHOT)
	# Friends-only keeps dev lobbies off the public list. Revisit before launch.
	Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, max_players)


func join(address: String) -> void:
	if not _ensure_steam():
		return
	var lobby_id := address.strip_edges().to_int()
	if lobby_id == 0:
		failed.emit("'%s' is not a Steam lobby ID" % address)
		return
	if not Steam.lobby_joined.is_connected(_on_lobby_joined):
		Steam.lobby_joined.connect(_on_lobby_joined, CONNECT_ONE_SHOT)
	Steam.joinLobby(lobby_id)


func poll() -> void:
	if _steam_ready:
		Steam.run_callbacks()


func close() -> void:
	if _lobby_id != 0:
		Steam.leaveLobby(_lobby_id)
		_lobby_id = 0


func describe() -> String:
	if _lobby_id != 0:
		return "Steam lobby %d" % _lobby_id
	return "Steam P2P"


func address_hint() -> String:
	return "Steam lobby ID"


## The host's lobby ID, so it can be read out and passed to the other player.
func get_lobby_id() -> int:
	return _lobby_id


func _ensure_steam() -> bool:
	if _steam_ready:
		return true
	var result: Dictionary = Steam.steamInitEx(DEV_APP_ID, true)
	if int(result.get("status", 1)) != 0:
		failed.emit("Steam did not initialise: %s" % result.get("verbal", "unknown error"))
		return false
	_steam_ready = true
	return true


func _on_lobby_created(connect_result: int, lobby_id: int) -> void:
	if connect_result != 1:
		failed.emit("Steam refused to create a lobby (result %d)" % connect_result)
		return
	_lobby_id = lobby_id
	var peer := SteamMultiplayerPeer.new()
	var err := peer.host_with_lobby(lobby_id)
	if err != OK:
		failed.emit("Could not host on lobby %d (error %d)" % [lobby_id, err])
		return
	peer_ready.emit(peer)


func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != LOBBY_ENTER_SUCCESS:
		failed.emit("Could not enter lobby %d (response %d)" % [lobby_id, response])
		return
	_lobby_id = lobby_id
	var peer := SteamMultiplayerPeer.new()
	var err := peer.connect_to_lobby(lobby_id)
	if err != OK:
		failed.emit("Could not connect to lobby %d (error %d)" % [lobby_id, err])
		return
	peer_ready.emit(peer)
