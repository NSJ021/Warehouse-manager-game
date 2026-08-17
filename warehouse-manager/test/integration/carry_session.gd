extends Node

## Integration layer: two real processes, real ENet, real RPCs.
##
## This is the layer that matters, because the risky parts of this game — host
## authority, held-item handoff, two-player carry — are exactly what unit tests
## are worst at. A green unit suite would prove almost nothing about whether
## Phase 0 works.
##
## Design rules it follows, learned the hard way:
##
## - **It drives the real path.** Grabs go through [method Carrier.try_toggle_hold],
##   which raycasts and then asks the host, exactly as pressing E does. An earlier
##   version of this idea would have called the referee directly — and would have
##   passed while the aim ray was completely broken, which is a bug that actually
##   shipped here.
## - **It uses the production world.** It instances the real level rather than a
##   bespoke test scene, so it cannot pass against wiring the game does not use.
## - **It waits on state, never on time.** Every step is "poll until true or give
##   up", with a wall-clock deadline from [method Time.get_ticks_msec]. Frame
##   counts are useless here: headless runs uncapped, so `--quit-after` and any
##   fixed frame budget are meaningless as timeouts.
## - **It has its own port**, so running the suite can never fight a live session.
##
## Both processes run this same scene, told apart by `--role=`. They synchronise
## on replicated state rather than on sleeps: the client waits until it can see
## the host holding the crate, and so on.

const WORLD_SCENE := preload("res://scenes/levels/test_room.tscn")

## Deliberately not 27015 — the suite must never collide with someone playing.
const TEST_PORT := 27099
const STEP_TIMEOUT_MS := 15000
const CRATE_NAME := "crate_0"
const EXPECTED_PLAYERS := 2
const EXPECTED_CRATES := 6
## Cargo rests at about y=0.25 on the floor and hangs near y=0.9 when carried, so
## this separates "picked up" from "sat there" with room to spare.
const LIFT_MIN_Y := 0.55

## Where each role stands to reach crate_0, which spawns at (-2.5, 0.6, -6.0).
## Either side of it, facing in, close enough to be inside GRAB_REACH.
const HOST_STAND := Vector3(-2.5, 0.1, -4.4)
const CLIENT_STAND := Vector3(-2.5, 0.1, -6.8)

var _role := "host"
var _world: Node = null
var _steps_passed := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			_role = arg.trim_prefix("--role=")

	print("[test] role=%s port=%d" % [_role, TEST_PORT])

	Net.session_started.connect(_on_session_started)
	Net.session_failed.connect(_on_session_failed)

	if _role == "host":
		Net.local_player_name = "HOST"
		Net.host_session(Net.TransportKind.ENET, TEST_PORT)
	else:
		Net.local_player_name = "CLIENT"
		Net.join_session(Net.TransportKind.ENET, "127.0.0.1", TEST_PORT)

	_run()


func _on_session_started(as_host: bool) -> void:
	if _world != null:
		return
	_world = WORLD_SCENE.instantiate()
	add_child(_world)
	if as_host:
		# The runner waits for this before starting the client, so the client can
		# never race a host that is not listening yet.
		print("[test] READY-TO-ACCEPT")


func _on_session_failed(reason: String) -> void:
	_fail("session", reason)
	_finish(false)


func _run() -> void:
	if not await _until("session up", func() -> bool: return Net.in_session()):
		return _finish(false)
	if not await _until("world loaded", func() -> bool: return _world != null):
		return _finish(false)
	if not await _until("both peers in roster", func() -> bool:
			return Net.players.size() == EXPECTED_PLAYERS):
		return _finish(false)
	if not await _until("all %d crates replicated" % EXPECTED_CRATES, func() -> bool:
			return _crates() != null and _crates().get_child_count() == EXPECTED_CRATES):
		return _finish(false)
	if not await _until("own body spawned", func() -> bool: return _me() != null):
		return _finish(false)

	var crate := _crate()
	if crate == null:
		_fail("find %s" % CRATE_NAME, "not present under Crates")
		return _finish(false)

	if _role == "host":
		await _run_host(crate)
	else:
		await _run_client(crate)


func _run_host(crate: Crate) -> void:
	_take(HOST_STAND, crate)
	if not await _until("host holds it", func() -> bool: return crate.holder_count() == 1):
		return _finish(false)

	# The client is watching for exactly this, and grabs once it sees it.
	if not await _until("SECOND holder joins (two-player carry)", func() -> bool:
			return crate.holder_count() == 2):
		return _finish(false)
	if not await _until("crate is lifted off the floor", func() -> bool:
			return crate.global_position.y > LIFT_MIN_Y):
		return _finish(false)

	# Letting go with someone else still holding is the handoff.
	var carrier: Carrier = _me().get_node("Carrier")
	carrier.try_toggle_hold()
	if not await _until("handoff leaves one holder", func() -> bool:
			return crate.holder_count() == 1):
		return _finish(false)
	if not await _until("still held after handoff", func() -> bool:
			return crate.global_position.y > LIFT_MIN_Y):
		return _finish(false)
	if not await _until("all holders released", func() -> bool:
			return crate.holder_count() == 0):
		return _finish(false)

	_finish(true)


func _run_client(crate: Crate) -> void:
	if not await _until("host grabbed first", func() -> bool: return crate.holder_count() == 1):
		return _finish(false)

	_take(CLIENT_STAND, crate)
	if not await _until("client joined the carry", func() -> bool:
			return crate.holder_count() == 2):
		return _finish(false)
	# Asserted on the client too: proves the lift replicated, not just that the
	# host believes it happened.
	if not await _until("client sees it lifted", func() -> bool:
			return crate.global_position.y > LIFT_MIN_Y):
		return _finish(false)

	if not await _until("host handed off", func() -> bool: return crate.holder_count() == 1):
		return _finish(false)

	var carrier: Carrier = _me().get_node("Carrier")
	carrier.try_toggle_hold()
	if not await _until("client released", func() -> bool: return crate.holder_count() == 0):
		return _finish(false)

	_finish(true)


## Stand next to the crate, look at it, and press the equivalent of E.
##
## Retried rather than done once, because the host judges reach from this peer's
## *replicated* position, which eases toward the teleport over a few frames. A
## fixed wait would be a flake waiting to happen; retrying until the state changes
## is deterministic in outcome.
func _take(stand: Vector3, crate: Crate) -> void:
	var me := _me()
	me.teleport_to(stand)
	me.aim_at(crate.global_position)
	var carrier: Carrier = me.get_node("Carrier")

	var deadline := Time.get_ticks_msec() + STEP_TIMEOUT_MS
	var attempts := 0
	while Time.get_ticks_msec() < deadline:
		# The carrier's own held crate is the right signal on both roles: it is set
		# by the host's grant coming back. is_held_by reads the host-only
		# dictionary, so a client would never see its own success.
		if carrier.held_crate() != null:
			break
		me.aim_at(crate.global_position)
		carrier.try_toggle_hold()
		attempts += 1
		for _i in 6:
			await get_tree().process_frame
	print("[test]      (grab requested, attempts=%d)" % attempts)

	# Now look level, which is what a player does the moment they have hold of
	# something. Keeping the aim pointed down at where the crate was on the floor
	# leaves the hold point near the floor too, so the crate never actually rises
	# and every "is it lifted" assertion becomes a coin toss.
	var level := Vector3(crate.global_position.x, me.camera.global_position.y, crate.global_position.z)
	me.aim_at(level)


func _until(label: String, predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + STEP_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			_pass(label)
			return true
		await get_tree().process_frame
	_fail(label, "timed out after %d ms" % STEP_TIMEOUT_MS)
	return false


func _pass(label: String) -> void:
	_steps_passed += 1
	print("[test] ok   %s" % label)


func _fail(label: String, why: String) -> void:
	print("[test] FAIL %s — %s" % [label, why])
	_report_state()


## Printed on failure only, and this is the "useful diff": enough state to tell
## which side disagreed without rerunning anything.
func _report_state() -> void:
	var crate := _crate()
	print("[test] state role=%s local_id=%d roster=%d crates=%d" % [
		_role,
		Net.local_id(),
		Net.players.size(),
		_crates().get_child_count() if _crates() != null else -1,
	])
	if crate != null:
		print("[test] state %s holders=%d (a=%d b=%d) pos=%v" % [
			CRATE_NAME, crate.holder_count(), crate.sync_holder_a, crate.sync_holder_b,
			crate.global_position,
		])
	var me := _me()
	if me != null:
		print("[test] state me pos=%v" % me.global_position)


func _finish(passed: bool) -> void:
	print("[test] RESULT=%s role=%s steps_passed=%d" % [
		"PASS" if passed else "FAIL", _role, _steps_passed,
	])
	get_tree().quit(0 if passed else 1)


func _crates() -> Node:
	if _world == null:
		return null
	return _world.get_node_or_null("Crates")


func _crate() -> Crate:
	var crates := _crates()
	if crates == null:
		return null
	return crates.get_node_or_null(CRATE_NAME) as Crate


func _me() -> Player:
	if _world == null:
		return null
	return _world.get_node_or_null("Players/%d" % Net.local_id()) as Player
