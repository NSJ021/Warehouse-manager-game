class_name NetTransport
extends RefCounted

## Abstract base for a network transport.
##
## A transport's only job is to turn a "host" or "join" request into a
## configured [MultiplayerPeer]. Everything above this line — [Net], the world,
## the player — is transport-agnostic, so swapping ENet for Steam P2P is a
## matter of instancing a different subclass.
##
## Results arrive by signal rather than return value because Steam is
## asynchronous: creating a lobby is a round trip to Valve's servers. ENet is
## synchronous and simply emits immediately.

## Emitted once the peer is configured and ready to be handed to the SceneTree.
signal peer_ready(peer: MultiplayerPeer)

## Emitted when the transport could not produce a peer. [param reason] is
## player-facing text.
signal failed(reason: String)

## Open a session for up to [param max_players] total participants (host included).
func host(max_players: int) -> void:
	push_error("NetTransport.host() is abstract — use a subclass")


## Join a session. [param address] is transport-specific: an IP for ENet, a
## lobby ID for Steam.
func join(address: String) -> void:
	push_error("NetTransport.join() is abstract — use a subclass")


## Called every frame while a session is active. Transports that need to pump
## their own callbacks override this.
func poll() -> void:
	pass


## Tear down any transport-level state. Called on leaving a session.
func close() -> void:
	pass


## Short human-readable name, used in logs and the debug overlay.
func describe() -> String:
	return "none"


## What [method join] expects, shown in the lobby UI.
func address_hint() -> String:
	return ""
