class_name CarryAuthority
extends Node

## Host-side referee for who is holding what.
##
## Clients never grant themselves a hold: they ask, the host decides, and the
## host tells the asker (ADR 7). That round trip is the deliberate cost of
## touching anything in this game — movement is free, cargo is not.
##
## Lives in its own script rather than in the level, because every level needs
## exactly this and none of it is level-specific. Pure logic, no node tree of
## its own, so it is a plain script rather than a scene (ADR 12).

## How close the hold point must be to grab. Generous, because the ray has
## already established the player is looking straight at it.
const GRAB_REACH := 2.5

@export var players_path: NodePath
@export var crates_path: NodePath

## peer_id -> Crate. Host-only.
var _held: Dictionary = {}

@onready var players: Node3D = get_node(players_path)
@onready var crates: Node3D = get_node(crates_path)


func _ready() -> void:
	# Carriers find their referee by group rather than by path, so this survives
	# the level tree being rearranged.
	add_to_group("carry_authority")
	if Net.is_host():
		Net.player_left.connect(_on_player_left)


@rpc("any_peer", "call_local", "reliable")
func request_grab(crate_name: String) -> void:
	if not Net.is_host():
		return

	var peer_id := _sender_id()
	if _held.has(peer_id):
		return

	var crate := crates.get_node_or_null(crate_name) as Crate
	if crate == null:
		return

	var holder := _player_for(peer_id)
	if holder == null:
		return
	if holder.camera_pivot.global_position.distance_to(crate.global_position) > GRAB_REACH:
		return
	if not crate.add_holder(peer_id, holder):
		return

	_held[peer_id] = crate
	if not crate.hold_broken.is_connected(_on_hold_broken):
		crate.hold_broken.connect(_on_hold_broken)
	print("[carry] peer %d grabbed %s (%d holding)" % [peer_id, crate_name, crate.holder_count()])
	_answer_grant(peer_id, crate_name)


@rpc("any_peer", "call_local", "reliable")
func request_release() -> void:
	if not Net.is_host():
		return

	var peer_id := _sender_id()
	var crate := _held.get(peer_id) as Crate
	if crate == null:
		return

	crate.remove_holder(peer_id)
	_held.erase(peer_id)
	print("[carry] peer %d released %s" % [peer_id, crate.name])
	_answer_revoke(peer_id)


func _sender_id() -> int:
	var id := multiplayer.get_remote_sender_id()
	# 0 means the host called this on itself rather than over the wire.
	return 1 if id == 0 else id


## The crate works out its own hold geometry from the holder's eyeline, so the
## host owns that maths and it cannot desync — a per-client offset node could be
## edited on one machine and silently disagree with the host.
func _player_for(peer_id: int) -> Player:
	# Player bodies are named after their owning peer — that naming is protocol
	# (ADR 12), and this lookup is one of the things relying on it.
	return players.get_node_or_null(str(peer_id)) as Player


func _local_carrier() -> Carrier:
	var body := players.get_node_or_null(str(multiplayer.get_unique_id()))
	if body == null:
		return null
	return body.get_node_or_null("Carrier") as Carrier


## Host-side. Delivers the verdict to the asker, whether or not that is the host.
func _answer_grant(peer_id: int, crate_name: String) -> void:
	if peer_id == 1:
		_hold_granted(crate_name)
	else:
		_hold_granted.rpc_id(peer_id, crate_name)


func _answer_revoke(peer_id: int) -> void:
	if peer_id == 1:
		_hold_revoked()
	else:
		_hold_revoked.rpc_id(peer_id)


@rpc("authority", "reliable")
func _hold_granted(crate_name: String) -> void:
	var carrier := _local_carrier()
	if carrier != null:
		carrier.on_hold_granted(crates.get_node_or_null(crate_name) as Crate)


@rpc("authority", "reliable")
func _hold_revoked() -> void:
	var carrier := _local_carrier()
	if carrier != null:
		carrier.on_hold_released()


func _on_hold_broken(peer_id: int) -> void:
	_held.erase(peer_id)
	_answer_revoke(peer_id)


func _on_player_left(peer_id: int) -> void:
	var crate := _held.get(peer_id) as Crate
	if crate != null:
		crate.remove_holder(peer_id)
	_held.erase(peer_id)
