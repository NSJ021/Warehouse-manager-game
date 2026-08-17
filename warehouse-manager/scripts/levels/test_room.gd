class_name TestRoom
extends Node3D

## Phase 0 proving ground: an empty room and nothing else.
##
## Owns player spawning. The host decides who exists; [MultiplayerSpawner]
## replicates that decision to everyone. Clients never spawn anyone, including
## themselves — they announce they are ready and wait to be given a body.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

@onready var players: Node3D = $Players
@onready var spawner: MultiplayerSpawner = $PlayerSpawner
@onready var spawn_points: Node3D = $SpawnPoints


func _ready() -> void:
	# Must be assigned on every peer before the first spawn packet arrives,
	# which is why the ready handshake below happens afterwards.
	spawner.spawn_function = _spawn_player

	if Net.is_host():
		Net.player_ready_for_spawn.connect(_on_player_ready_for_spawn)
		Net.player_left.connect(_on_player_left)

	Net.announce_world_ready()


## Runs on every peer with identical data, so every peer builds an identical node.
func _spawn_player(data: Variant) -> Node:
	var info := data as Dictionary
	var player := PLAYER_SCENE.instantiate() as Player
	player.setup(int(info["peer_id"]), str(info["name"]), info["spawn"] as Vector3)
	print("[world] spawned %s for peer %d at %v" % [info["name"], info["peer_id"], info["spawn"]])
	return player


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
