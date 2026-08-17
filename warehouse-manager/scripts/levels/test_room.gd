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
## instead of a second mechanism being invented for it. The first six sit in a
## row, which is what Phase 0 hand-testing wants.
@export var crate_count := 6

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
		crate_spawner.spawn({"id": i, "spawn": _crate_position(i)})
	if crate_count > CRATE_LOG_LIMIT:
		print("[world] spawned %d crates" % crate_count)


## Deterministic on purpose: the same index always lands in the same place, so a
## stress run is repeatable and two runs are comparable.
func _crate_position(index: int) -> Vector3:
	if crate_count <= CRATE_ROW_LIMIT:
		return CRATE_ROW_ORIGIN + Vector3(float(index) * CRATE_ROW_SPACING, 0.0, 0.0)

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
