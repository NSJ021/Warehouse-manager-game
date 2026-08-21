class_name TestRoom
extends Node3D

## Phase 0 proving ground: an empty room and a row of crates.
##
## Owns all spawning, players and cargo alike. The host decides what exists;
## [MultiplayerSpawner] replicates that decision to everyone. Clients never spawn
## anything, including themselves — they announce they are ready and wait.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const CRATE_SCENE := preload("res://scenes/goods/crate.tscn")

## A handful of crates sit in a row near the spawn points, because that is what
## hand-testing wants — crates in a far corner are a walk away every single time.
const CRATE_ROW_LIMIT := 12
const CRATE_ROW_ORIGIN := Vector3(-2.5, 0.6, -6.0)
const CRATE_ROW_SPACING := 1.0
## How many crates the first row holds before [method _crate_position] moves
## on to [constant CRATE_ROW2_ORIGIN]. Also what every integration scenario's
## own crate-name table assumes (crate_0..crate_5 sit in this row, referenced
## by name — see storage_session.gd and carry_session.gd's own allocation
## comments) — do not change this without checking both.
const CRATE_ROW_SIZE := 6
## The gate playtest protocol needs 9+ crates on hand (a full cell of 8
## Smalls plus one still in hand, 2026-08-21) — raised to 12, a second row
## rather than one row of 12. Extending the first row out along x instead
## would have run it straight through things the integration suite depends
## on: rack_wall's own approach corridor (its aimable cells sit at
## x=7.0/8.0, and storage_session.gd stands a player at their z+2.0=-6.5 to
## reach them) and the same file's drag-avoidance detour, which sweeps
## z=-3.0 clear across the room's x range.
##
## z=-9.0, not simply "the next row back" at -7.5: carry_session.gd's own
## CLIENT_STAND_OFFSET_Z (-1.2) stands a player at z=-7.2 to grab a row-1
## crate from the north side, and that capsule's own 0.4 m radius reaches
## z=-7.6 — a row at -7.5 would have sat the new crates' own half-extent
## (0.25) directly inside that stand point. -9.0 clears it by over a metre
## (row-2 crates span z=[-9.25,-8.75]) and still leaves 0.75 m to the north
## wall's inner face (z=-10.0). Same x=-2.5..2.5 as the first row, which is
## nowhere near either rack (x=6.5) or either zone (x=-7).
const CRATE_ROW2_ORIGIN := Vector3(-2.5, 0.6, -9.0)

## Beyond that it becomes a grid filling the floor, wrapping into layers above
## once the floor is full. 0.7 spacing against a 0.5 crate leaves a gap, so
## nothing starts the run already overlapping.
const CRATE_GRID_ORIGIN := Vector3(-8.4, 0.35, -8.4)
const CRATE_GRID_SPACING := 0.7
const CRATE_GRID_COLUMNS := 24
const CRATE_GRID_ROWS := 24
const CRATE_LAYER_HEIGHT := 0.6
## Above this, the per-crate spawn log is noise rather than information.
const CRATE_LOG_LIMIT := 12

## Starting cargo. Exported so the physics budget stress test can turn one knob
## instead of a second mechanism being invented for it. The first twelve sit in
## two rows of six (see CRATE_ROW_SIZE / CRATE_ROW2_ORIGIN), which is what
## hand-testing — now including the gate's full-cell-plus-one protocol — wants.
@export var crate_count := 12

## Host-only. The next id [method spawn_crate_at] mints — one counter shared
## with the starting batch below, so ids never collide and are never reused.
## A recycled id would be indistinguishable from a stale reference on a
## client once the original crate despawned (a racked crate freed and later
## re-minted must never come back wearing the same name as something a peer
## still remembers).
var _next_crate_id := 0

@onready var players: Node3D = $Players
@onready var spawner: MultiplayerSpawner = $PlayerSpawner
@onready var spawn_points: Node3D = $SpawnPoints
@onready var crates: Node3D = $Crates
@onready var crate_spawner: MultiplayerSpawner = $CrateSpawner


func _ready() -> void:
	# Must be assigned on every peer before the first spawn packet arrives,
	# which is why the ready handshake below happens afterwards.
	spawner.spawn_function = _spawn_player
	crate_spawner.spawn_function = _spawn_crate

	# CarryAuthority finds a crate minter by group rather than by name, so it
	# never has to name TestRoom or any other level script (it is not
	# level-specific — see its class doc). Every level that wants retrieval
	# to work joins this group; a level that does not simply never grants one.
	add_to_group("crate_source")

	if Net.is_host():
		Net.player_ready_for_spawn.connect(_on_player_ready_for_spawn)
		Net.player_left.connect(_on_player_left)
		_spawn_crates()

	Net.announce_world_ready()


## Runs on every peer with identical data, so every peer builds an identical node.
func _spawn_player(data: Variant) -> Node:
	var info := data as Dictionary
	var player := PLAYER_SCENE.instantiate() as Player
	player.setup(int(info["peer_id"]), str(info["name"]), info["spawn"] as Vector3)
	print("[world] spawned %s for peer %d at %v" % [info["name"], info["peer_id"], info["spawn"]])
	return player


## Runs on every peer with identical data, same contract as [method _spawn_player].
func _spawn_crate(data: Variant) -> Node:
	var info := data as Dictionary
	var crate := CRATE_SCENE.instantiate() as Crate
	crate.setup(int(info["id"]), info["spawn"] as Vector3)
	if crate_count <= CRATE_LOG_LIMIT:
		print("[world] spawned crate %d at %v" % [info["id"], info["spawn"]])
	return crate


## Host-only, and deliberately before the ready handshake: the crates exist
## before anyone has a body to bump into them with.
func _spawn_crates() -> void:
	for i in crate_count:
		crate_spawner.spawn({"id": _mint_crate_id(), "spawn": _crate_position(i)})
	if crate_count > CRATE_LOG_LIMIT:
		print("[world] spawned %d crates" % crate_count)


func _mint_crate_id() -> int:
	var minted := _next_crate_id
	_next_crate_id += 1
	return minted


## Host-only. Mints a crate with an id no live crate holds and spawns it at
## [param spawn_position]. Retrieval (01-04) and shedding (01-07) both need to
## turn stored occupancy data back into a real crate, and both need an id
## guaranteed not to collide with one already in play.
func spawn_crate_at(spawn_position: Vector3) -> Crate:
	if not Net.is_host():
		return null
	return crate_spawner.spawn({"id": _mint_crate_id(), "spawn": spawn_position}) as Crate


## Deterministic on purpose: the same index always lands in the same place, so a
## stress run is repeatable and two runs are comparable.
func _crate_position(index: int) -> Vector3:
	if crate_count <= CRATE_ROW_LIMIT:
		if index < CRATE_ROW_SIZE:
			return CRATE_ROW_ORIGIN + Vector3(float(index) * CRATE_ROW_SPACING, 0.0, 0.0)
		var row2_index := index - CRATE_ROW_SIZE
		return CRATE_ROW2_ORIGIN + Vector3(float(row2_index) * CRATE_ROW_SPACING, 0.0, 0.0)

	var per_layer := CRATE_GRID_COLUMNS * CRATE_GRID_ROWS
	var layer := index / per_layer
	var within := index % per_layer
	return CRATE_GRID_ORIGIN + Vector3(
		float(within % CRATE_GRID_COLUMNS) * CRATE_GRID_SPACING,
		float(layer) * CRATE_LAYER_HEIGHT,
		float(within / CRATE_GRID_COLUMNS) * CRATE_GRID_SPACING,
	)


func _on_player_ready_for_spawn(peer_id: int, player_name: String) -> void:
	if players.has_node(str(peer_id)):
		return
	spawner.spawn({
		"peer_id": peer_id,
		"name": player_name,
		"spawn": _next_spawn_position(),
	})


func _on_player_left(peer_id: int) -> void:
	var body := players.get_node_or_null(str(peer_id))
	if body != null:
		body.queue_free()


func _next_spawn_position() -> Vector3:
	var count := spawn_points.get_child_count()
	if count == 0:
		return Vector3.ZERO
	var marker := spawn_points.get_child(players.get_child_count() % count) as Node3D
	return marker.position
