class_name CarryAuthority
extends Node

## Host-side referee for who is holding what — and, from 01-04, what is
## racked where.
##
## Clients never grant themselves a hold, and they never rack or unrack
## anything unilaterally either: they ask, the host decides, and the host
## tells the asker (ADR 7). That round trip is the deliberate cost of
## touching anything in this game — movement is free, cargo is not.
##
## Lives in its own script rather than in the level, because every level needs
## exactly this and none of it is level-specific. Pure logic, no node tree of
## its own, so it is a plain script rather than a scene (ADR 12).
##
## Placing a crate does not replicate the racked item itself. The three
## broadcasts below carry a handful of bytes — (rack, cell, crate id) — and
## every peer derives identical local state (Rack._rebuild_cell_visuals) from
## that alone, against the 93–115 kb/s ADR 14 measured for loose cargo.
## Reintroducing per-item replication for racked stock would silently reopen
## exactly the cost grid storage exists to avoid.

## How close the hold point must be to grab. Generous, because the ray has
## already established the player is looking straight at it.
const GRAB_REACH := 2.5
## How close a placement or retrieval must be to the cell it targets. Just
## past GrabRay's 2.5 m target_position, deliberately: a genuine aim can
## therefore never fail this check. It exists to reject a forged or stale
## request from a client, not to gate normal play — do not "tune" it.
const PLACE_REACH := 2.6
## How many frames [method _hold_granted] will wait for a just-retrieved
## crate's spawn packet to land before giving up. [method request_retrieve]
## sends the spawn ahead of the grant on the same reliable channel, so under
## an ordinary grab the crate already exists and this loop never runs — it
## exists only for the theoretical case where a client processes its own
## spawn a frame late.
const GRANT_RESOLVE_FRAMES := 60

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
		Net.player_ready_for_spawn.connect(_on_player_ready_for_spawn)


## [param want_drag] is what the player asked for by pressing drag rather than
## interact. The host may overrule it either way — cargo too heavy to lift is
## dragged whether or not it was asked for, and a second holder always lifts.
@rpc("any_peer", "call_local", "reliable")
func request_grab(crate_name: String, want_drag: bool) -> void:
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
	if not crate.add_holder(peer_id, holder, want_drag):
		return

	_held[peer_id] = crate
	if not crate.hold_broken.is_connected(_on_hold_broken):
		crate.hold_broken.connect(_on_hold_broken)
	if not crate.hold_mode_changed.is_connected(_on_hold_mode_changed):
		crate.hold_mode_changed.connect(_on_hold_mode_changed)
	var mode := crate.hold_mode()
	print("[carry] peer %d %s %s (%d holding)" % [
		peer_id, "dragged" if mode == Crate.HoldMode.DRAG else "grabbed",
		crate_name, crate.holder_count(),
	])
	_answer_grant(peer_id, crate_name, mode)


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


## Store a held crate into a rack cell. Validated in order: the sender is
## actually holding something; a dragged crate may only reach the floor row
## (ADR 19, see the note below); the rack and cell resolve; the cell has room
## for this kind (ADR 18); the holder is actually close enough. Any failure
## returns silently — the idiom this whole file uses, a client that disagrees
## with the host simply does not get what it asked for.
@rpc("any_peer", "call_local", "reliable")
func request_place(rack_name: String, cell_index: int) -> void:
	if not Net.is_host():
		return

	var peer_id := _sender_id()
	var crate := _held.get(peer_id) as Crate
	if crate == null:
		return

	# ADR 19: a dragged crate's hold point is taken from the capsule's yaw,
	# not the camera, so a lone player physically cannot lift it to a high
	# shelf. Read host-side, so a client cannot forge its way past this —
	# without it, a solo dragger could fill the top row from the floor,
	# deleting the entire two-player carry incentive (GDD §6.1). Two holders
	# always carry, so a promoted drag reaches here as HoldMode.CARRY and
	# needs no special case.
	var dragging := crate.hold_mode() == Crate.HoldMode.DRAG

	var rack := _rack_for(rack_name)
	if rack == null:
		return
	if cell_index < 0 or cell_index >= StorageGrid.cell_count():
		return
	# StorageGrid.cell_coords() returns (column, depth, level) — .z is level,
	# not .y (see the coordinate-order note on that method). Floor is level 0.
	if dragging and StorageGrid.cell_coords(cell_index).z != 0:
		return
	if not rack.can_accept(cell_index, crate.kind):
		return

	var holder := _player_for(peer_id)
	if holder == null:
		return
	if holder.camera_pivot.global_position.distance_to(rack.cell_to_global_position(cell_index)) > PLACE_REACH:
		return

	var crate_id := crate.id
	var from_position := crate.global_position

	# Release every holder, not just the asker — a crate can be held by two
	# players (ADR 13 / GDD §6.1), and placing it takes it from both. _held
	# is copied by .keys() into a fresh Array, so erasing mid-loop is safe.
	for id in _held.keys():
		if _held[id] == crate:
			crate.remove_holder(id)
			_held.erase(id)
			_answer_revoke(id)

	# The "remove from simulation" step ADR 14 requires, proven by 01-01's
	# despawn probe: a racked item is freed outright, never merely left inert
	# in the tree. A paused-in-place body would still cost the ~40 µs/frame
	# per-crate figure ADR 14 measured, whether or not it ever moves again —
	# do not "improve" this into pausing the body instead of freeing it.
	crate.queue_free()
	_cell_filled.rpc(rack_name, cell_index, crate_id, from_position)
	print("[carry] peer %d racked crate_%d into %s cell %d" % [peer_id, crate_id, rack_name, cell_index])


## Take a stored crate back into the sender's hands — the mirror of
## [method request_place], not a special case. Validated: the sender is
## holding nothing; the rack and cell resolve; the cell is occupied; the
## holder is close enough. The crate is spawned before the grant is sent, so
## the spawn packet is queued ahead of it on the same reliable channel — it
## never sits loose for a frame and never falls out of the rack in front of
## the player. Retrieval always grants a normal carry (see the ADR 19 note on
## [method request_place]); do not change that to preserve whatever hold mode
## put the crate away.
@rpc("any_peer", "call_local", "reliable")
func request_retrieve(rack_name: String, cell_index: int) -> void:
	if not Net.is_host():
		return

	var peer_id := _sender_id()
	if _held.has(peer_id):
		return

	var rack := _rack_for(rack_name)
	if rack == null:
		return
	if cell_index < 0 or cell_index >= StorageGrid.cell_count():
		return
	if rack.is_cell_empty(cell_index):
		return

	var holder := _player_for(peer_id)
	if holder == null:
		return
	if holder.camera_pivot.global_position.distance_to(rack.cell_to_global_position(cell_index)) > PLACE_REACH:
		return

	var source := _crate_source()
	if source == null:
		return

	_cell_cleared.rpc(rack_name, cell_index)
	var crate := source.spawn_crate_at(rack.cell_to_global_position(cell_index)) as Crate
	if crate == null:
		return

	crate.add_holder(peer_id, holder)
	_held[peer_id] = crate
	if not crate.hold_broken.is_connected(_on_hold_broken):
		crate.hold_broken.connect(_on_hold_broken)
	if not crate.hold_mode_changed.is_connected(_on_hold_mode_changed):
		crate.hold_mode_changed.connect(_on_hold_mode_changed)
	print("[carry] peer %d retrieved crate_%d from %s cell %d" % [peer_id, crate.id, rack_name, cell_index])
	_answer_grant(peer_id, crate.name, crate.hold_mode())


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


## Racks are resolved by group, then by name — a handful of static fixtures,
## looked up once per interaction rather than a hot path. This deliberately
## differs from the players_path / crates_path exports above: racks are
## numerous static fixtures, and a group means dropping a rack into a level
## needs no scene wiring. Rack node names are protocol (ADR 12) — this lookup
## is what makes that true.
func _rack_for(rack_name: String) -> Rack:
	for node in get_tree().get_nodes_in_group("racks"):
		if node.name == rack_name:
			return node as Rack
	return null


## Crates are minted through the level, not through a spawner this file owns.
## Typed as Node and duck-checked with has_method, because this class is not
## level-specific (see the class doc) and must not name TestRoom or any other
## level script directly.
func _crate_source() -> Node:
	var source := get_tree().get_first_node_in_group("crate_source")
	if source == null or not source.has_method("spawn_crate_at"):
		return null
	return source


## Host-side. Delivers the verdict to the asker, whether or not that is the host.
func _answer_grant(peer_id: int, crate_name: String, mode: Crate.HoldMode) -> void:
	if peer_id == 1:
		_hold_granted(crate_name, mode)
	else:
		_hold_granted.rpc_id(peer_id, crate_name, mode)


func _answer_revoke(peer_id: int) -> void:
	if peer_id == 1:
		_hold_revoked()
	else:
		_hold_revoked.rpc_id(peer_id)


## Host-side. Tells a holder their hold changed under them — someone grabbed the
## other end of what they were dragging, or let go of what they were carrying.
func _answer_mode(peer_id: int, mode: Crate.HoldMode) -> void:
	if peer_id == 1:
		_hold_mode_set(mode)
	else:
		_hold_mode_set.rpc_id(peer_id, mode)


## Resolves the crate by name and hands it to the local carrier. Under an
## ordinary grab the crate already exists and the wait below never runs; it
## exists only in case a retrieve grant's node lookup lands a frame before
## this client has actually processed the matching spawn. Without it,
## resolving null here would silently look like a refused grab.
@rpc("authority", "reliable")
func _hold_granted(crate_name: String, mode: Crate.HoldMode) -> void:
	var carrier := _local_carrier()
	if carrier == null:
		return
	var crate := crates.get_node_or_null(crate_name) as Crate
	var waited := 0
	while crate == null and waited < GRANT_RESOLVE_FRAMES:
		await get_tree().process_frame
		crate = crates.get_node_or_null(crate_name) as Crate
		waited += 1
	carrier.on_hold_granted(crate, mode)


@rpc("authority", "reliable")
func _hold_revoked() -> void:
	var carrier := _local_carrier()
	if carrier != null:
		carrier.on_hold_released()


@rpc("authority", "reliable")
func _hold_mode_set(mode: Crate.HoldMode) -> void:
	var carrier := _local_carrier()
	if carrier != null:
		carrier.on_hold_mode_changed(mode)


## Host tells everyone a cell's new contents. call_local so the host's own copy
## goes through the identical code path as every client — same shape as
## Net._sync_roster. Contains no logic beyond the null guard: the rack owns
## the state, this referee owns only the decision.
@rpc("authority", "call_local", "reliable")
func _cell_filled(rack_name: String, cell_index: int, crate_id: int, from_position: Vector3) -> void:
	var rack := _rack_for(rack_name)
	if rack != null:
		rack.apply_cell_filled(cell_index, crate_id, from_position)


@rpc("authority", "call_local", "reliable")
func _cell_cleared(rack_name: String, cell_index: int) -> void:
	var rack := _rack_for(rack_name)
	if rack != null:
		rack.apply_cell_cleared(cell_index)


## Sent only to a late joiner (see [method _on_player_ready_for_spawn]), never
## call_local — the host's own racks are already correct, having made every
## decision that put them in that state.
@rpc("authority", "reliable")
func _rack_snapshot(rack_name: String, occupancy: Array) -> void:
	var rack := _rack_for(rack_name)
	if rack != null:
		rack.apply_occupancy_snapshot(occupancy)


func _on_hold_broken(peer_id: int) -> void:
	_held.erase(peer_id)
	_answer_revoke(peer_id)


func _on_hold_mode_changed(peer_id: int, mode: Crate.HoldMode) -> void:
	_answer_mode(peer_id, mode)


func _on_player_left(peer_id: int) -> void:
	var crate := _held.get(peer_id) as Crate
	if crate != null:
		crate.remove_holder(peer_id)
	_held.erase(peer_id)


## A late joiner's own racks start empty — MultiplayerSpawner only replicates
## nodes that exist in the scene tree, and racked items are deliberately not
## nodes with a synchronizer (see the class doc). Without this, "every peer
## agrees which cell holds which crate" would only be true for peers present
## at the moment a placement happened, which is not what that guarantee means.
func _on_player_ready_for_spawn(peer_id: int, _player_name: String) -> void:
	if peer_id == 1:
		return
	for node in get_tree().get_nodes_in_group("racks"):
		var rack := node as Rack
		if rack != null and not rack.is_empty():
			_rack_snapshot.rpc_id(peer_id, rack.name, rack.occupancy_snapshot())
