extends Node

## Entry point. Owns the menu, loads the world once a session exists, and
## handles mouse capture.
##
## Launch arguments let one keystroke start a four-instance test:
##   --host              host over ENet
##   --join[=address]    join over ENet, default 127.0.0.1
##   --steam             use the Steam transport instead of ENet
##   --name=NAME         display name above the character
##   --port=N            override the ENet port, so a second session can run
##                       alongside a live one without fighting for it
##   --day-length=N      override the day clock's day_length_seconds (02-03),
##                       so a hand-test can run a 60-second day without
##                       editing the scene. Host-only; ignored on a client.
## Set these per instance under Debug > Customize Run Instances.

const WORLD_SCENE := preload("res://scenes/levels/test_room.tscn")

## On screen during a session. Cheap to read while testing, and it means devlog
## footage shows the controls without a caption being added afterwards.
const CONTROLS: Array[String] = [
	"WASD move   ·   Shift sprint   ·   Space jump",
	"E  grab / drop a crate   —   one each, so drop before you take another",
	"F  drag it along the floor instead — slow, and it never leaves the ground",
	"R  rotate a held Large before racking it — which two cells it will take",
	"walk into a crate to shove it",
	"two players can hold the SAME crate — that's the two-player carry",
	"grab the other end of a dragged crate and it lifts",
	"N  call it a night early (host only) — skips straight to the midnight boundary",
	"Esc releases the mouse, click to recapture",
]

var _world: Node = null
## Set from --day-length=N, applied to the clock the moment a session starts
## hosting. -1 means "no override, use the scene's own default."
var _day_length_override := -1.0

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
	elif event.is_action_pressed("call_it_a_night"):
		_request_call_it_a_night()


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
		elif arg.begins_with("--day-length="):
			_day_length_override = arg.trim_prefix("--day-length=").to_float()

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

	# The *game* wants a day; a *headless integration scenario* instances
	# test_room.tscn directly, without going through main.tscn, so it gets a
	# room with an idle clock unless it asks (02-06's own scenario calls
	# begin_run() itself, with a short day length). This one call is what
	# keeps carry_session.gd and storage_session.gd untouched — do not move
	# it, and do not have TestRoom call begin_run() on its own.
	if Net.is_host():
		var clock := _day_clock()
		if clock != null:
			if _day_length_override > 0.0:
				clock.day_length_seconds = _day_length_override
			clock.begin_run()


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

	var day_line := _day_line()
	if not day_line.is_empty():
		lines.append(day_line)
	var delivery_line := _delivery_line()
	if not delivery_line.is_empty():
		lines.append(delivery_line)
	lines.append(_carry_line())
	lines.append("")
	lines.append_array(CONTROLS)
	hud_label.text = "\n".join(lines)


## The day/phase/countdown line (02-03). Load-bearing, not decoration: ADR 25
## (f) fixes information asymmetry must live on the screen, never in audio
## alone, so this text carries the same klaxon warning DockDoor's audio does
## — a player with their sound off, or a mate talking over it, still sees the
## door is about to close. Do not move this into an audio-only cue later.
func _day_line() -> String:
	var clock := _day_clock()
	if clock == null:
		return ""

	var left := clock.seconds_left_in_phase()
	var minutes := int(left) / 60
	var seconds := int(left) % 60
	var countdown := "%d:%02d" % [minutes, seconds]

	if clock.phase() == DayClock.Phase.SHIFT and left <= clock.klaxon_warning_seconds:
		return "Day %d  ·  %s  ·  DOORS CLOSING IN %s" % [clock.current_day(), clock.phase_name(), countdown]
	return "Day %d  ·  %s  ·  %s left" % [clock.current_day(), clock.phase_name(), countdown]


## 02-07's own line — not decoration. ADR 25 (f) fixes information asymmetry
## must live on the screen, never only in audio, and "what is due out today"
## is exactly the information a player needs and has no other way to see in
## Phase 2 (no phone, no offer sheet yet — those are Phase 4). Blank before
## the first delivery, same as [method _day_line]'s own guard.
##
## [b]Deviation from this plan's own `files_modified` list, worth recording:[/b]
## the plan's own Task 2 text asks for exactly this HUD line in `main.gd`,
## but `main.gd` is not named in the plan's frontmatter — an omission, not a
## scope choice; fixed here rather than left for a later plan to rediscover
## the same gap.
func _delivery_line() -> String:
	var clock := _day_clock()
	if clock == null or clock.manifest() == null:
		return ""
	return "in: %d  ·  out: %d" % [clock.delivered_today_count(), clock.due_today_count()]


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


## Found by group, not cached — the same reason DockDoor and CarryAuthority
## both resolve their own lookups lazily rather than in _ready(): a
## cached reference taken before the world scene has finished entering the
## tree can be null on some peers.
func _day_clock() -> DayClock:
	if _world == null:
		return null
	return _world.get_tree().get_first_node_in_group("day_clock") as DayClock


## The clock is host-gated internally (ADR 21's host-decides precedent), so
## every player may press the key, but only the host's press does anything —
## the HUD's own CONTROLS line says so, rather than leaving a client to wonder
## why nothing happened.
func _request_call_it_a_night() -> void:
	var clock := _day_clock()
	if clock == null:
		return
	if Net.is_host():
		clock.request_call_it_a_night()
	else:
		clock.request_call_it_a_night.rpc_id(1)
