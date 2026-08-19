extends Node

## Entry point. Owns the menu, loads the world once a session exists, and
## handles mouse capture.
##
## Launch arguments let one keystroke start a four-instance test:
##   --host            host over ENet
##   --join[=address]  join over ENet, default 127.0.0.1
##   --steam           use the Steam transport instead of ENet
##   --name=NAME       display name above the character
##   --port=N          override the ENet port, so a second session can run
##                     alongside a live one without fighting for it
## Set these per instance under Debug > Customize Run Instances.

const WORLD_SCENE := preload("res://scenes/levels/test_room.tscn")

## On screen during a session. Cheap to read while testing, and it means devlog
## footage shows the controls without a caption being added afterwards.
const CONTROLS: Array[String] = [
	"WASD move   ·   Shift sprint   ·   Space jump",
	"E  grab / drop a crate   —   one each, so drop before you take another",
	"F  drag it along the floor instead — slow, and it never leaves the ground",
	"walk into a crate to shove it",
	"two players can hold the SAME crate — that's the two-player carry",
	"grab the other end of a dragged crate and it lifts",
	"Esc releases the mouse, click to recapture",
]

var _world: Node = null

@onready var menu: Control = $UI/Menu
@onready var address_field: LineEdit = $UI/Menu/Panel/Layout/AddressField
@onready var status_label: Label = $UI/Menu/Panel/Layout/Status
@onready var hud_label: Label = $UI/HUD/Info


func _ready() -> void:
	Net.session_started.connect(_on_session_started)
	Net.session_failed.connect(_on_session_failed)
	Net.session_ended.connect(_on_session_ended)
	Net.roster_changed.connect(_refresh_hud)

	$UI/Menu/Panel/Layout/HostENet.pressed.connect(_on_host_enet_pressed)
	$UI/Menu/Panel/Layout/JoinENet.pressed.connect(_on_join_enet_pressed)
	$UI/Menu/Panel/Layout/HostSteam.pressed.connect(_on_host_steam_pressed)
	$UI/Menu/Panel/Layout/JoinSteam.pressed.connect(_on_join_steam_pressed)

	_apply_launch_arguments()


func _process(_delta: float) -> void:
	if Net.in_session():
		_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if _world == null:
		return
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _apply_launch_arguments() -> void:
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	var kind := Net.TransportKind.ENET
	var wants_host := false
	var wants_join := false
	var address := ""
	var port := 0

	for arg in args:
		if arg == "--steam":
			kind = Net.TransportKind.STEAM
		elif arg == "--host":
			wants_host = true
		elif arg == "--join":
			wants_join = true
		elif arg.begins_with("--join="):
			wants_join = true
			address = arg.trim_prefix("--join=")
		elif arg.begins_with("--name="):
			Net.local_player_name = arg.trim_prefix("--name=")
		elif arg.begins_with("--port="):
			port = arg.trim_prefix("--port=").to_int()

	if wants_host:
		Net.local_player_name = Net.local_player_name if Net.local_player_name != "Player" else "Host"
		_set_status("Hosting over %s..." % ("Steam" if kind == Net.TransportKind.STEAM else "ENet"))
		Net.host_session(kind, port)
	elif wants_join:
		_set_status("Connecting...")
		Net.join_session(kind, address, port)


func _on_host_enet_pressed() -> void:
	_set_status("Opening session...")
	Net.host_session(Net.TransportKind.ENET)


func _on_join_enet_pressed() -> void:
	_set_status("Connecting...")
	Net.join_session(Net.TransportKind.ENET, address_field.text)


func _on_host_steam_pressed() -> void:
	_set_status("Creating Steam lobby...")
	Net.host_session(Net.TransportKind.STEAM)


func _on_join_steam_pressed() -> void:
	_set_status("Joining Steam lobby...")
	Net.join_session(Net.TransportKind.STEAM, address_field.text)


func _on_session_started(_as_host: bool) -> void:
	if _world != null:
		return
	_world = WORLD_SCENE.instantiate()
	$WorldRoot.add_child(_world)
	menu.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_session_failed(reason: String) -> void:
	_set_status(reason)


func _on_session_ended() -> void:
	if _world != null:
		_world.queue_free()
		_world = null
	menu.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _set_status(text: String) -> void:
	status_label.text = text


func _refresh_hud() -> void:
	if not Net.in_session():
		hud_label.text = ""
		return
	var role := "HOST" if Net.is_host() else "CLIENT"
	var lines := [
		"%s  id %d  |  %s" % [role, Net.local_id(), Net.transport_name()],
		"players: %d/%d" % [Net.players.size(), Net.MAX_PLAYERS],
	]
	var transport := Net.get_transport()
	if transport is SteamTransport:
		var lobby_id := (transport as SteamTransport).get_lobby_id()
		if lobby_id != 0:
			lines.append("lobby: %d" % lobby_id)

	lines.append(_carry_line())
	lines.append("")
	lines.append_array(CONTROLS)
	hud_label.text = "\n".join(lines)


## Reads the local player's hands via a group, so the HUD needs to know nothing
## about how a level arranges its nodes.
func _carry_line() -> String:
	var carrier := get_tree().get_first_node_in_group("local_carrier") as Carrier
	if carrier == null:
		return "hands: —"
	var crate := carrier.held_crate()
	if crate == null:
		return "hands: empty"
	# Spelled out rather than counted. "(2 carrying)" was read as two crates
	# rather than two people, which is exactly the wrong thing to be vague about.
	if crate.holder_count() > 1:
		return "hands: %s   ·   TWO-PLAYER CARRY" % crate.name
	return "hands: %s   ·   carrying alone" % crate.name
