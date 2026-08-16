class_name ENetTransport
extends NetTransport

## Development transport: plain UDP over ENet.
##
## This exists because Steam P2P allows exactly one Steam client per machine,
## which caps a local test at two players across two PCs. Phase 0 has to prove
## four-player handoff races, so the day-to-day test loop runs four instances
## on one machine over loopback. See the ADR on development transport.

const DEFAULT_PORT := 27015

var _port := DEFAULT_PORT


func _init(port: int = DEFAULT_PORT) -> void:
	_port = port


func host(max_players: int) -> void:
	var peer := ENetMultiplayerPeer.new()
	# create_server counts *clients*, not total participants — the host is implicit.
	var err := peer.create_server(_port, max_players - 1)
	if err != OK:
		failed.emit("Could not open port %d — is another instance already hosting? (error %d)" % [_port, err])
		return
	peer_ready.emit(peer)


func join(address: String) -> void:
	var target := address.strip_edges()
	if target.is_empty():
		target = "127.0.0.1"
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(target, _port)
	if err != OK:
		failed.emit("Could not reach %s:%d (error %d)" % [target, _port, err])
		return
	peer_ready.emit(peer)


func describe() -> String:
	return "ENet :%d" % _port


func address_hint() -> String:
	return "IP address (blank = 127.0.0.1)"
