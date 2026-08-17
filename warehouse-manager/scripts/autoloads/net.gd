extends Node

## Session authority and transport plumbing. Autoloaded as `Net`.
##
## Owns exactly one thing: whether we are in a session, who is in it, and which
## transport is carrying it. It does not know about players, crates or the
## world — the world listens to its signals.
##
## Authority model (see the ADR on client-authoritative characters): the host is
## authoritative over every rigid body and every held-item decision. Each client
## is authoritative over its own character capsule only.

enum TransportKind {
	ENET, ## Development transport. Four instances on one machine.
	STEAM, ## Shipping transport. One player per machine.
}

## Total participants including the host. The lease is a four-person job.
const MAX_PLAYERS := 4

## Local peer is now in a session. [param as_host] distinguishes the two roles.
signal session_started(as_host: bool)
## Session has fully torn down, for any reason.
signal session_ended()
## Could not start or stay in a session. [param reason] is player-facing.
signal session_failed(reason: String)
## Host-side only: this peer has the world loaded and wants a body.
signal player_ready_for_spawn(peer_id: int, player_name: String)
## Host-side only: this peer has gone.
signal player_left(peer_id: int)
## The name roster changed on any peer. For UI.
signal roster_changed()

## peer_id -> display name. Mirrored to every peer by the host.
var players: Dictionary = {}
var local_player_name := "Player"

var _transport: NetTransport = null
var _is_host := false
var _in_session := false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(_delta: float) -> void:
	if _transport != null:
		_transport.poll()


## Open a session as host. [param port] of 0 means the transport's default; the
## integration harness passes its own so it can never collide with a live game.
func host_session(kind: TransportKind, port: int = 0) -> void:
	if _in_session:
		push_warning("Already in a session — leave first")
		return
	_bind_transport(kind, port)
	_is_host = true
	_transport.host(MAX_PLAYERS)


## Join an existing session. [param address] is an IP for ENet, a lobby ID for Steam.
func join_session(kind: TransportKind, address: String, port: int = 0) -> void:
	if _in_session:
		push_warning("Already in a session — leave first")
		return
	_bind_transport(kind, port)
	_is_host = false
	_transport.join(address)


## Tear down the session on this peer. On the host this ends it for everyone —
## host migration is deliberately not supported.
func leave_session() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	if _transport != null:
		_transport.close()
		_transport = null
	players.clear()
	_is_host = false
	_in_session = false
	roster_changed.emit()
	session_ended.emit()


## Called by the world once it has finished loading locally, so the host knows
## this peer can safely receive spawns. Without this handshake the host can spawn
## a body into a peer that has no world to put it in.
func announce_world_ready() -> void:
	_request_spawn.rpc_id(1, local_player_name)


func is_host() -> bool:
	return _is_host


func in_session() -> bool:
	return _in_session


func local_id() -> int:
	if multiplayer.multiplayer_peer == null:
		return 0
	return multiplayer.get_unique_id()


func transport_name() -> String:
	if _transport == null:
		return "offline"
	return _transport.describe()


## The active transport, for UI that needs transport-specific detail such as the
## Steam lobby ID to read out to a friend.
func get_transport() -> NetTransport:
	return _transport


func _bind_transport(kind: TransportKind, port: int = 0) -> void:
	match kind:
		TransportKind.STEAM:
			# Steam lobbies are not addressed by port, so it is ignored here.
			_transport = SteamTransport.new()
		_:
			_transport = ENetTransport.new(port if port > 0 else ENetTransport.DEFAULT_PORT)
	_transport.peer_ready.connect(_on_peer_ready)
	_transport.failed.connect(_on_transport_failed)


func _on_peer_ready(peer: MultiplayerPeer) -> void:
	multiplayer.multiplayer_peer = peer
	if _is_host:
		# The host is live the moment the socket is open; there is nothing to wait for.
		_in_session = true
		print("[net] hosting over %s" % _transport.describe())
		session_started.emit(true)


func _on_transport_failed(reason: String) -> void:
	push_error("Transport failed: %s" % reason)
	leave_session()
	session_failed.emit(reason)


func _on_connected_to_server() -> void:
	_in_session = true
	session_started.emit(false)


func _on_connection_failed() -> void:
	leave_session()
	session_failed.emit("Could not connect to the host")


func _on_server_disconnected() -> void:
	leave_session()
	session_failed.emit("The host closed the session")


func _on_peer_connected(_peer_id: int) -> void:
	# Deliberately empty. A connected peer is not yet a player — it becomes one
	# when it reports its world is loaded, via _request_spawn.
	pass


func _on_peer_disconnected(peer_id: int) -> void:
	if not _is_host:
		return
	players.erase(peer_id)
	player_left.emit(peer_id)
	_sync_roster.rpc(players)


@rpc("any_peer", "call_local", "reliable")
func _request_spawn(player_name: String) -> void:
	if not _is_host:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id == 0:
		peer_id = 1 # A local call from the host itself.
	players[peer_id] = player_name
	print("[net] peer %d (%s) is ready for a body" % [peer_id, player_name])
	_sync_roster.rpc(players)
	player_ready_for_spawn.emit(peer_id, player_name)


@rpc("authority", "call_local", "reliable")
func _sync_roster(roster: Dictionary) -> void:
	players = roster.duplicate()
	roster_changed.emit()
