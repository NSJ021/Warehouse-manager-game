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

## Lobby visibility by name, so it can be changed on the day with a launch flag
## rather than an edit and a re-export. Friends-only is the default and the right
## answer for dev, but it requires both Steam accounts to actually be friends —
## and a *new* Steam account cannot add friends until it has spent money, which is
## exactly the sort of thing that derails a two-machine test at the worst moment.
## `--lobby=public` sidesteps it.
const LOBBY_TYPES := {
	"public": Steam.LOBBY_TYPE_PUBLIC,
	"friends": Steam.LOBBY_TYPE_FRIENDS_ONLY,
	"invisible": Steam.LOBBY_TYPE_INVISIBLE,
	"private": Steam.LOBBY_TYPE_PRIVATE,
}

var _lobby_id := 0
var _steam_ready := false


func host(max_players: int) -> void:
	if not _ensure_steam():
		return
	if not Steam.lobby_created.is_connected(_on_lobby_created):
		Steam.lobby_created.connect(_on_lobby_created, CONNECT_ONE_SHOT)
	var kind := _arg_value("--lobby=", "friends")
	var lobby_type: int = LOBBY_TYPES.get(kind, Steam.LOBBY_TYPE_FRIENDS_ONLY)
	print("[net] creating a %s Steam lobby for %d" % [kind, max_players])
	Steam.createLobby(lobby_type, max_players)


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
	# embed_callbacks stays true, and [method poll] also pumps them. The redundancy
	# is deliberate for now: this path has never been executed, and belt-and-braces
	# callback pumping is the wrong thing to be clever about on a first run. Tidy to
	# one or the other once Steam is proven end to end.
	var result: Dictionary = Steam.steamInitEx(DEV_APP_ID, true)
	if int(result.get("status", 1)) != 0:
		failed.emit("Steam did not initialise: %s" % result.get("verbal", "unknown error"))
		return false
	_steam_ready = true
	_apply_network_simulation()
	return true


## Valve's own network simulator, which is a better test than a real connection
## because it is repeatable and dial-able.
##
## Two machines on one LAN connect to each other more or less directly, so a
## same-network Steam test measures about a millisecond and proves nothing about
## how the game feels over the internet. This injects the latency instead:
##
##     --fake-lag=40      40 ms each way, so an 80 ms round trip
##     --fake-loss=1.5    1.5% of packets dropped, each way
##
## Applied globally, so it affects every connection this process makes.
func _apply_network_simulation() -> void:
	var lag_ms := _arg_value("--fake-lag=", "0").to_int()
	var loss_pct := _arg_value("--fake-loss=", "0").to_float()
	if lag_ms <= 0 and loss_pct <= 0.0:
		return

	Steam.setGlobalConfigValueInt32(Steam.NETWORKING_CONFIG_FAKE_PACKET_LAG_SEND, lag_ms)
	Steam.setGlobalConfigValueInt32(Steam.NETWORKING_CONFIG_FAKE_PACKET_LAG_RECV, lag_ms)
	Steam.setGlobalConfigValueFloat(Steam.NETWORKING_CONFIG_FAKE_PACKET_LOSS_SEND, loss_pct)
	Steam.setGlobalConfigValueFloat(Steam.NETWORKING_CONFIG_FAKE_PACKET_LOSS_RECV, loss_pct)
	print("[net] simulating %d ms each way (%d ms round trip) and %.1f%% packet loss" % [
		lag_ms, lag_ms * 2, loss_pct,
	])


func _arg_value(prefix: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return fallback


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
