extends Node

## The physics budget stress test.
##
## Answers one question: **how many rigid bodies survive across four networked
## peers?** That number is not a curiosity — it silently constrains floor clutter,
## how violently a rack may shed, and how many items a day can involve. Designing
## any of those before knowing it is guessing.
##
## Runs in every peer, told apart by `--role=`. Each peer waits for the expected
## roster, lets the pile settle, then samples for a fixed wall-clock window and
## prints one machine-readable line.
##
## What it measures, and why each one:
##
##   phys_ms    Physics step cost. The host's is the one that matters — it
##              simulates every body. A client's should stay near zero, because
##              its crates are frozen.
##   proc_ms    Per-frame script cost. On a client this is the puppet smoothing,
##              which is O(crates) every frame and is the cost people forget.
##   sent_kbps  Real bytes off the host's socket, from ENetConnection's own
##              counter rather than an estimate. Bandwidth, not physics, is the
##              suspected binding constraint.
##   active     Bodies Jolt considers awake. The gap between this and the crate
##              count in settled mode is how much sleeping saves.
##
## Two modes, and the difference between them is the real finding:
##
##   settled    Sleeping allowed. Steady state — a tidy warehouse.
##   awake      Nothing sleeps. This is the honest worst case, and it is the case
##              that matters: a *held* crate never sleeps by definition, and
##              neither does a rack mid-collapse.

const WORLD_SCENE := preload("res://scenes/levels/test_room.tscn")

## Its own port, distinct from both the game and the integration suite.
const STRESS_PORT := 27098
const CONNECT_TIMEOUT_MS := 30000

var _role := "host"
var _crates := 6
var _mode := "settled"
var _expected_peers := 1
var _warmup_ms := 2000
var _sample_ms := 4000

## Diagnostic only: kills client-side puppet smoothing outright, to attribute how
## much of a client's frame time is actually spent on it rather than guessing.
var _no_smoothing := false

var _world: Node = null


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			_role = arg.trim_prefix("--role=")
		elif arg.begins_with("--crates="):
			_crates = arg.trim_prefix("--crates=").to_int()
		elif arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--peers="):
			_expected_peers = arg.trim_prefix("--peers=").to_int()
		elif arg.begins_with("--warmup-ms="):
			_warmup_ms = arg.trim_prefix("--warmup-ms=").to_int()
		elif arg.begins_with("--sample-ms="):
			_sample_ms = arg.trim_prefix("--sample-ms=").to_int()
		elif arg == "--no-smoothing":
			_no_smoothing = true

	Net.session_started.connect(_on_session_started)
	Net.session_failed.connect(func(reason: String) -> void:
		print("[stress] ABORT %s: %s" % [_role, reason])
		get_tree().quit(1))

	if _role == "host":
		Net.local_player_name = "HOST"
		Net.host_session(Net.TransportKind.ENET, STRESS_PORT)
	else:
		Net.local_player_name = _role.to_upper()
		Net.join_session(Net.TransportKind.ENET, "127.0.0.1", STRESS_PORT)

	_run()


func _on_session_started(as_host: bool) -> void:
	if _world != null:
		return
	_world = WORLD_SCENE.instantiate()
	# Set before the node enters the tree, so _ready spawns the right number.
	if as_host:
		_world.crate_count = _crates
	add_child(_world)
	if as_host:
		print("[stress] READY-TO-ACCEPT")


func _run() -> void:
	if not await _wait_for(func() -> bool: return Net.in_session()):
		return _abort("never entered a session")
	if not await _wait_for(func() -> bool: return _world != null):
		return _abort("world never loaded")
	if not await _wait_for(func() -> bool: return Net.players.size() >= _expected_peers):
		return _abort("only %d of %d peers arrived" % [Net.players.size(), _expected_peers])
	if not await _wait_for(func() -> bool: return _crate_node_count() == _crates):
		return _abort("only %d of %d crates replicated" % [_crate_node_count(), _crates])

	if _no_smoothing:
		for child in _crates_parent().get_children():
			child.set_process(false)
		print("[stress] diagnostic: client puppet smoothing disabled")

	if _mode == "awake":
		# A held crate never sleeps, and neither does a rack mid-collapse. Forcing
		# every body awake is the deterministic way to measure that worst case
		# without needing four humans to pick things up.
		for child in _crates_parent().get_children():
			var crate := child as Crate
			if crate != null:
				crate.can_sleep = false
				crate.sleeping = false

	# Sampled across the warm-up too, while the pile is still falling and every
	# body is definitely moving. If this is still zero afterwards, the monitor is
	# not populated by this physics backend rather than the bodies being idle -
	# worth knowing, because a confident zero is worse than a blank.
	var peak_active := 0.0
	var settle_deadline := Time.get_ticks_msec() + _warmup_ms
	while Time.get_ticks_msec() < settle_deadline:
		peak_active = maxf(peak_active, Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))
		await get_tree().process_frame

	_reset_network_counter()

	# Sampling window. Averaged over frames rather than sampled once, because a
	# single reading catches whatever the frame happened to be doing.
	var frames := 0
	var phys_total := 0.0
	var proc_total := 0.0
	var active_total := 0.0
	var pairs_total := 0.0
	var deadline := Time.get_ticks_msec() + _sample_ms
	while Time.get_ticks_msec() < deadline:
		frames += 1
		phys_total += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		proc_total += Performance.get_monitor(Performance.TIME_PROCESS)
		active_total += Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
		pairs_total += Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)
		await get_tree().process_frame

	var divisor := maxf(float(frames), 1.0)
	print("[stress] RESULT role=%s mode=%s crates=%d peers=%d phys_ms=%.3f proc_ms=%.3f fps=%.0f active=%.0f peak_active=%.0f pairs=%.0f sent_kbps=%.1f nodes=%d" % [
		_role, _mode, _crates, Net.players.size(),
		phys_total / divisor * 1000.0,
		proc_total / divisor * 1000.0,
		Performance.get_monitor(Performance.TIME_FPS),
		active_total / divisor,
		peak_active,
		pairs_total / divisor,
		_sent_kbps(),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
	])

	# The host must outlive the clients. It starts first and therefore finishes
	# first, and quitting closes the session out from under them - which is why
	# every client reported "the host closed the session" instead of a result.
	if _role == "host" and _expected_peers > 1:
		var leave_deadline := Time.get_ticks_msec() + CONNECT_TIMEOUT_MS
		while Net.players.size() > 1 and Time.get_ticks_msec() < leave_deadline:
			await get_tree().process_frame

	get_tree().quit(0)


func _abort(why: String) -> void:
	print("[stress] ABORT %s crates=%d mode=%s: %s" % [_role, _crates, _mode, why])
	get_tree().quit(1)


func _wait_for(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + CONNECT_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await get_tree().process_frame
	return false


func _hold_for(duration_ms: int) -> void:
	var deadline := Time.get_ticks_msec() + duration_ms
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


## Reads and clears, so the next read covers only the sampling window.
func _reset_network_counter() -> void:
	var connection := _enet_host()
	if connection != null:
		connection.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)


func _sent_kbps() -> float:
	var connection := _enet_host()
	if connection == null:
		return 0.0
	var bytes := connection.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)
	return bytes / 1024.0 / (float(_sample_ms) / 1000.0)


func _enet_host() -> ENetConnection:
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer == null:
		return null
	return peer.get_host()


func _crates_parent() -> Node:
	if _world == null:
		return null
	return _world.get_node_or_null("Crates")


func _crate_node_count() -> int:
	var parent := _crates_parent()
	if parent == null:
		return -1
	return parent.get_child_count()
