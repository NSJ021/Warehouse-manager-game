extends Node

## Integration layer: the storage round trip, across two real processes.
##
## Sibling to carry_session.gd rather than folded into it — carry's
## choreography is already a full linear script, and storage is a different
## scenario entirely. Follows the same design rules as that file (see its own
## doc comment for the reasoning): drives the real keypress path through
## [method Carrier.try_toggle_hold], instances the real test_room.tscn rather
## than a bespoke scene, waits on state rather than time, and has its own
## port so it can never fight carry_session's 27099 or a live game's 27015.
##
## ⚠ A few of this scenario's exact numbers do not survive being simulated
## step by step the way the plan first wrote them — filling a cell to eight
## and then asserting it empty two steps later, or an occupancy of 1 sitting
## alongside a crate count that only matches a completely different point in
## the sequence. Every *property* the plan names is still proven below —
## place, a cell taking more than one, a full cell refusing without a drop, a
## dragged crate refused above the floor row, LIFO order, and the body budget
## — the exact figures are just derived from what this sequence actually
## does rather than copied from the plan text. See 01-04-SUMMARY.md for the
## specifics that changed.
##
## Two peers, host-leads/client-follows and back again, entirely through
## replicated state:
##   1. Host racks crate_0 into CELL_A. Client waits for the occupancy to
##      change and checks its own copy — the real proof of "the body left the
##      world on every peer", not just the host's say-so.
##   2. Client racks crate_1 into the SAME cell. Host waits and checks back —
##      proves a cell holds more than one (ADR 18), not one-slot-per-cell.
##   3. Host tops CELL_B up to capacity through the referee's own broadcast
##      RPC directly, with synthetic ids that were never real crates. This is
##      setup, not the thing under test, but it travels over the same wire a
##      real placement does, so both peers agree it is full.
##   4. Client grabs a loose crate and is refused by the full cell — proven on
##      the real keypress path, and proven it does not silently become a
##      drop.
##   5. Client drags a different crate and is refused by CELL_A, which is not
##      floor level (ADR 19) — a carried crate can reach it (steps 1 and 2
##      just did); a dragged one physically cannot.
##   6. Host retrieves twice from CELL_A with empty hands between each. The
##      rack's own bookkeeping (rack.occupant()) pops in the exact reverse of
##      the order the two ids went in — the mechanic ADR 18 exists for. Proven
##      through that bookkeeping rather than through the id of whatever crate
##      ends up in the retriever's hands, because request_retrieve always
##      mints a fresh body — the placed one was freed outright, ADR 14, so
##      nothing kept the original in reserve to hand back. The cell ends
##      empty, which the client independently confirms on its own copy.

const WORLD_SCENE := preload("res://scenes/levels/test_room.tscn")

## Deliberately neither carry_session's 27099 nor a live game's 27015.
const TEST_PORT := 27097
const STEP_TIMEOUT_MS := 15000
const EXPECTED_PLAYERS := 2
const EXPECTED_CRATES := 6

## The rack this session racks into and retrieves from. Node name is protocol
## (ADR 12) — must match the level's actual Racks/rack_wall exactly.
const RACK_PATH := "Racks/rack_wall"
## Both level 1 (StorageGrid.cell_coords(i).z == 1, not floor) — deliberately
## not level 0, so a real carried placement into either one is itself a small
## proof that "a carried crate can reach any cell" (a dragged one cannot
## reach either).
##
## ⚠ Both also depth=1 (StorageGrid.cell_coords(i).y == 1), and that part is
## not a free choice. A rack's CellSensor volumes are permanent aim targets,
## present whether or not their cell holds anything, and rack_wall is backed
## directly onto the room's north wall — so the only side a player can ever
## stand on is the depth=1 (south-facing) row's own side. Aiming at a
## depth=0 cell from there means the ray has to pass through the depth=1
## cell directly in front of it first, and an Area3D blocks a raycast
## regardless of its monitoring flags, so a depth=0 cell on this particular
## rack is permanently unaimable no matter what it holds. Discovered by this
## scenario timing out solid on cell 5 (depth 0) before this was cell 7.
const CELL_A := 7
const CELL_B := 6

## How far past the cell centre a player stands to interact with it, along Z.
##
## Derived, not guessed. At 1.3 m the held crate (riding 1.15 m in front of
## the camera) would sit inside the rack's own deck, breaking the hold for
## reasons that look like a physics bug rather than a bad stand position. At
## 2.0 m the held crate clears the deck face, the camera sits about 2.05 m
## from the cell centre — inside both the 2.5 m GrabRay and the referee's
## 2.6 m PLACE_REACH — and aiming at rack.cell_to_global_position(i) resolves
## back to cell i. If an assertion below ever fails, re-check this first.
const RACK_STAND_OFFSET_Z := 2.0
## Two different lateral offsets so host and client never occupy the exact
## same point when both are near the rack in the same window — the same
## reason carry_session gives its two roles different Z offsets around the
## crate they share.
const HOST_LATERAL := 0.4
const CLIENT_LATERAL := -0.4
## How far along Z a player stands from the crate row to grab a loose crate.
const GRAB_STAND_OFFSET_Z := 1.5
const STAND_HEIGHT := 0.1
## How long the host waits, after its own last network-relevant action,
## before quitting. get_tree().quit() does not flush a pending reliable send
## first, so finishing immediately after issuing one can tear the peer down
## before it actually reaches the client -- see the call site.
const EXIT_SETTLE_MS := 500

## Crate name allocation within this scenario's own world (a separate process
## pair from carry_session, so its own crate counter starts at 0 too — these
## names do not collide with carry_session's table).
const CRATE_HOST_NAME := "crate_0"
const CRATE_CLIENT_NAME := "crate_1"
const CRATE_FULL_ATTEMPT_NAME := "crate_2"
const CRATE_DRAG_ATTEMPT_NAME := "crate_3"

## Ids for CELL_B's synthetic fill. Far outside the range TestRoom ever
## mints (0..5 for six starting crates), so they can never collide with, or
## be mistaken for, a real crate.
const FILLER_ID_START := 9000
const FILLER_COUNT := 8

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

	var rack := _rack()
	if rack == null:
		_fail("find %s" % RACK_PATH, "not present under the world")
		return _finish(false)

	if _role == "host":
		await _run_host(rack)
	else:
		await _run_client(rack)


# --------------------------------------------------------------- host role

func _run_host(rack: Rack) -> void:
	# --- 1: host racks crate_0 into CELL_A. ---
	var crate_host := _crate_named(CRATE_HOST_NAME)
	if crate_host == null:
		_fail("find %s" % CRATE_HOST_NAME, "not present under Crates")
		return _finish(false)

	await _grab(crate_host)
	if not await _until("host holds %s" % CRATE_HOST_NAME, func() -> bool:
			return crate_host.holder_count() == 1):
		return _finish(false)
	# Captured now, not read off crate_host later: placing it frees the body
	# (ADR 14), and crate_host itself becomes a freed reference the instant
	# that happens. crate.id survives; the node does not.
	var crate_host_id := crate_host.id

	await _place(rack, CELL_A, HOST_LATERAL)
	if not await _until("crate_0 racked into cell %d" % CELL_A, func() -> bool:
			return rack.occupant(CELL_A) != -1):
		return _finish(false)
	# queue_free() defers the actual removal rather than doing it inline, so
	# polled rather than checked once — a check landing in the gap between
	# "the cell shows it" and "the node is actually gone" would read as a
	# real failure for a race that was never one.
	if not await _until("the body left the world on the host too", func() -> bool:
			return _crates().get_child_count() == EXPECTED_CRATES - 1):
		return _finish(false)
	_expect_now(
		rack.get_node_or_null("RackedItems/Cell%d_Item0" % CELL_A) != null,
		"cell %d shows its racked visual on the host" % CELL_A,
	)
	if not await _wait_for_settle(rack, CELL_A, 0):
		return _finish(false)

	# --- 2: client racks crate_1 into the same cell. Wait, then check back. ---
	if not await _until("client racked a second crate into cell %d" % CELL_A, func() -> bool:
			return rack.occupied_count(CELL_A) == 2):
		return _finish(false)
	if not await _until("both bodies left the world", func() -> bool:
			return _crates().get_child_count() == EXPECTED_CRATES - 2):
		return _finish(false)
	# The client's own placement, landing on the host's copy — proves the
	# tween converges for a non-host-initiated placement too, not just the
	# host's own.
	if not await _wait_for_settle(rack, CELL_A, 1):
		return _finish(false)
	# Captured now, while cell A's stack is known to hold exactly these two
	# and nothing else touches it before step 6 -- this is the id the LIFO
	# check at the end proves comes back out first, without this script
	# needing its own reference to whatever crate the client happened to grab.
	var crate_client_id := rack.occupant(CELL_A)

	# --- 3: fill CELL_B to capacity through the referee's own broadcast. ---
	# This is setup, not the thing under test, so it skips eight real
	# grab-and-place round trips — but it goes out over the same _cell_filled
	# RPC a real placement uses, so the client's own copy is genuinely full,
	# not merely asserted so on the host's say-so.
	var authority := _authority()
	if authority == null:
		_fail("find CarryAuthority", "not present under the world")
		return _finish(false)
	var before_budget := _crates().get_child_count()
	for i in FILLER_COUNT:
		authority._cell_filled.rpc(rack.name, CELL_B, FILLER_ID_START + i, rack.cell_to_global_position(CELL_B))
	_expect_now(
		rack.occupied_count(CELL_B) == FILLER_COUNT,
		"cell %d holds all %d synthetic fillers on the host" % [CELL_B, FILLER_COUNT],
	)
	# The budget line: eight items now stored, at the cost of zero rigid
	# bodies -- Crates.get_child_count() has not moved, because none of these
	# were ever real crates in the first place. Printed as a [test] line so a
	# human reading the log sees the number, because it is the criterion most
	# likely to regress invisibly.
	print("[test]      budget: %d crates in the world, %d items in cell %d" % [
		_crates().get_child_count(), rack.occupied_count(CELL_B), CELL_B,
	])
	_expect_now(
		_crates().get_child_count() == before_budget,
		"storing 8 items spent zero bodies (%d before, %d after)" % [before_budget, _crates().get_child_count()],
	)
	# Unlike the placements above, nothing here ever calls queue_free() -- the
	# fillers were never real crate bodies -- so this one is safe to check
	# immediately rather than poll for.

	# --- 4: wait for the client to grab the full-cell attempt crate, and
	# confirm the refusal from the host's own authoritative truth, not the
	# client's say-so. A tight window starting right at the grab, because the
	# client releases this crate once its own check passes and moves on. ---
	var crate_full_attempt := _crate_named(CRATE_FULL_ATTEMPT_NAME)
	if crate_full_attempt == null:
		_fail("find %s" % CRATE_FULL_ATTEMPT_NAME, "not present under Crates")
		return _finish(false)
	if not await _until("client grabbed %s" % CRATE_FULL_ATTEMPT_NAME, func() -> bool:
			return crate_full_attempt.holder_count() == 1):
		return _finish(false)
	if not await _stays(
			"refused on the host's own truth: %s stays held, cell %d stays full" % [CRATE_FULL_ATTEMPT_NAME, CELL_B],
			func() -> bool:
				return (crate_full_attempt.holder_count() == 1
						and rack.occupied_count(CELL_B) == FILLER_COUNT)):
		return _finish(false)

	# --- 5: same shape, for the drag attempt against cell A (ADR 19). ---
	var crate_drag_attempt := _crate_named(CRATE_DRAG_ATTEMPT_NAME)
	if crate_drag_attempt == null:
		_fail("find %s" % CRATE_DRAG_ATTEMPT_NAME, "not present under Crates")
		return _finish(false)
	if not await _until("client is dragging %s" % CRATE_DRAG_ATTEMPT_NAME, func() -> bool:
			return (crate_drag_attempt.holder_count() == 1
					and crate_drag_attempt.hold_mode() == Crate.HoldMode.DRAG)):
		return _finish(false)
	if not await _stays(
			"ADR 19 on the host's own truth: %s stays dragged, cell %d untouched" % [CRATE_DRAG_ATTEMPT_NAME, CELL_A],
			func() -> bool:
				return (crate_drag_attempt.holder_count() == 1
						and crate_drag_attempt.hold_mode() == Crate.HoldMode.DRAG
						and rack.occupied_count(CELL_A) == 2)):
		return _finish(false)

	# The host's own stays window above is not proof the client's matching
	# window (which starts later -- the client still has to walk and press
	# three times first) has finished too. Without this, step 6 emptying
	# CELL_A can race the client's own read of occupied_count(CELL_A) == 2
	# mid-check -- exactly what happened before this wait was added. The
	# client drops crate_3 once its own check passes, so that release is the
	# signal step 6 is safe to start.
	if not await _until("client finished with %s" % CRATE_DRAG_ATTEMPT_NAME, func() -> bool:
			return crate_drag_attempt.holder_count() == 0):
		return _finish(false)

	# --- 6: retrieve twice from CELL_A with empty hands between each. ---
	#
	# LIFO is proven through the rack's own bookkeeping (rack.occupant()),
	# not through the id of whatever crate ends up in the retriever's hands:
	# request_retrieve always mints a brand new Crate body -- the one that
	# was placed was freed outright (ADR 14), nothing kept it in reserve --
	# so the physical crate that comes back has a fresh id unrelated to
	# which stored id was actually popped.
	_expect_now(
		rack.occupant(CELL_A) == crate_client_id,
		"LIFO: the most recently placed id (%d) is on top before the first retrieve (got %d)" % [crate_client_id, rack.occupant(CELL_A)],
	)
	var first := await _retrieve(rack, CELL_A, HOST_LATERAL)
	if first == null:
		_fail("first retrieve from cell %d" % CELL_A, "never granted")
		return _finish(false)
	_expect_now(
		rack.occupant(CELL_A) == crate_host_id,
		"LIFO: the first-placed id (%d) is what's left after popping the top one (got %d)" % [crate_host_id, rack.occupant(CELL_A)],
	)
	await _release_held()

	var second := await _retrieve(rack, CELL_A, HOST_LATERAL)
	if second == null:
		_fail("second retrieve from cell %d" % CELL_A, "never granted")
		return _finish(false)

	_expect_now(rack.is_cell_empty(CELL_A), "cell %d is empty after both retrievals" % CELL_A)
	# get_node_or_null() still finds a queue_free()'d node until the deferred
	# removal actually runs, same as Crates.get_child_count() above -- polled
	# for the same reason.
	if not await _until("cell %d's racked visual is gone" % CELL_A, func() -> bool:
			return rack.get_node_or_null("RackedItems/Cell%d_Item0" % CELL_A) == null):
		return _finish(false)
	if not await _until("every original crate id is a body again", func() -> bool:
			return _crates().get_child_count() == EXPECTED_CRATES):
		return _finish(false)

	# The host's own view of the second retrieve is already correct here --
	# call_local applies its own broadcast synchronously -- but the CLIENT's
	# matching "cell is empty" check depends on the _cell_cleared RPC this
	# retrieve just sent actually reaching the wire before quit() tears the
	# peer down. get_tree().quit() does not wait for a pending reliable send
	# to flush, so finishing immediately here raced the packet out from
	# under itself the first time this scenario was run to a clean pass.
	# Real wall time, not frames, for the same reason SPAWN_SETTLE_MS in
	# carry_session.gd is: headless runs uncapped, so a frame count buys no
	# fixed amount of real time for the network to actually do anything.
	var settle_deadline := Time.get_ticks_msec() + EXIT_SETTLE_MS
	while Time.get_ticks_msec() < settle_deadline:
		await get_tree().process_frame

	_finish(true)


# ------------------------------------------------------------- client role

func _run_client(rack: Rack) -> void:
	# --- 1: wait for the host to rack crate_0, then check our own copy. ---
	if not await _until("host racked crate_0 into cell %d" % CELL_A, func() -> bool:
			return rack.occupied_count(CELL_A) == 1):
		return _finish(false)
	# Polled, not checked once: queue_free() replicates its own despawn as a
	# separate message from the _cell_filled broadcast, so there is no
	# ordering guarantee between "the cell shows it" and "the body is
	# actually gone on this peer" landing in the same polled frame.
	if not await _until("the client's own view already lost the body too", func() -> bool:
			return _crates().get_child_count() == EXPECTED_CRATES - 1):
		return _finish(false)
	_expect_now(
		rack.get_node_or_null("RackedItems/Cell%d_Item0" % CELL_A) != null,
		"the client's own view shows cell %d's racked visual" % CELL_A,
	)
	if not await _wait_for_settle(rack, CELL_A, 0):
		return _finish(false)

	# --- 2: client racks crate_1 into the same cell. ---
	var crate_client := _crate_named(CRATE_CLIENT_NAME)
	if crate_client == null:
		_fail("find %s" % CRATE_CLIENT_NAME, "not present under Crates")
		return _finish(false)

	await _grab(crate_client)
	if not await _until("client holds %s" % CRATE_CLIENT_NAME, func() -> bool:
			return crate_client.holder_count() == 1):
		return _finish(false)

	await _place(rack, CELL_A, CLIENT_LATERAL)
	if not await _until("cell %d now holds two" % CELL_A, func() -> bool:
			return rack.occupied_count(CELL_A) == 2):
		return _finish(false)
	if not await _until("both bodies are gone from the client's own view too", func() -> bool:
			return _crates().get_child_count() == EXPECTED_CRATES - 2):
		return _finish(false)
	# This is the client's own placement, checked on the client's own copy --
	# the non-host-initiated case, on the peer that actually asked for it.
	if not await _wait_for_settle(rack, CELL_A, 1):
		return _finish(false)

	# --- 3: wait for the host to fill CELL_B. ---
	if not await _until("cell %d filled to capacity" % CELL_B, func() -> bool:
			return rack.occupied_count(CELL_B) == FILLER_COUNT):
		return _finish(false)

	# --- 4: attempt to place a loose crate into the full cell. Refused. ---
	var crate_full_attempt := _crate_named(CRATE_FULL_ATTEMPT_NAME)
	if crate_full_attempt == null:
		_fail("find %s" % CRATE_FULL_ATTEMPT_NAME, "not present under Crates")
		return _finish(false)

	await _grab(crate_full_attempt)
	if not await _until("client holds %s" % CRATE_FULL_ATTEMPT_NAME, func() -> bool:
			return crate_full_attempt.holder_count() == 1):
		return _finish(false)

	var carrier: Carrier = _me().get_node("Carrier")
	await _attempt_place(rack, CELL_B, CLIENT_LATERAL)
	if not await _stays("refused: still holding %s, cell %d still full" % [CRATE_FULL_ATTEMPT_NAME, CELL_B],
			func() -> bool:
				return (carrier.held_crate() == crate_full_attempt
						and rack.occupied_count(CELL_B) == FILLER_COUNT)):
		return _finish(false)

	# Hands free again before the next grab -- request_grab refuses outright
	# while already holding something, so the refused crate has to go down
	# (an ordinary drop, unchanged from Phase 0) before crate_3 can be picked
	# up. The host's own check above already ran and finished by this point.
	await _release_held()

	# --- 5: drag a different crate, attempt cell A (not floor level). Refused. ---
	var crate_drag_attempt := _crate_named(CRATE_DRAG_ATTEMPT_NAME)
	if crate_drag_attempt == null:
		_fail("find %s" % CRATE_DRAG_ATTEMPT_NAME, "not present under Crates")
		return _finish(false)

	await _grab(crate_drag_attempt, true)
	if not await _until("client is dragging %s" % CRATE_DRAG_ATTEMPT_NAME, func() -> bool:
			return carrier.is_dragging()):
		return _finish(false)

	await _attempt_place(rack, CELL_A, CLIENT_LATERAL)
	if not await _stays(
			"ADR 19: still dragging %s, cell %d untouched" % [CRATE_DRAG_ATTEMPT_NAME, CELL_A],
			func() -> bool:
				return (carrier.is_dragging() and carrier.held_crate() == crate_drag_attempt
						and rack.occupied_count(CELL_A) == 2)):
		return _finish(false)

	# Drop it -- this is the host's signal that step 6 (which empties cell A)
	# is safe to start. Without it, the host's own matching check (which
	# finishes sooner, since it has no walk-and-press-three-times of its own
	# to do first) can start retrieving from cell A while this check is
	# still reading it, which is exactly what happened before this existed.
	await _release_held()

	# --- 6: wait for the host to empty cell A via two retrievals. ---
	if not await _until("cell %d is empty" % CELL_A, func() -> bool: return rack.is_cell_empty(CELL_A)):
		return _finish(false)
	# Polled, not checked once: the same deferred-queue_free race as the
	# Crates.get_child_count() checks above. get_node_or_null() still finds a
	# node between queue_free() being called and the removal actually
	# running, so a check landing in that gap reads as a real failure for a
	# race that was never one — this one did exactly that the first time this
	# scenario passed everything else.
	if not await _until("the client's own view shows cell %d's visual gone" % CELL_A, func() -> bool:
			return rack.get_node_or_null("RackedItems/Cell%d_Item0" % CELL_A) == null):
		return _finish(false)
	if not await _until("the client's own view has every crate id back as a body", func() -> bool:
			return _crates().get_child_count() == EXPECTED_CRATES):
		return _finish(false)

	_finish(true)


# -------------------------------------------------------------- action helpers

## Teleport to the crate's row and press until it is ours.
func _grab(crate: Crate, want_drag := false) -> void:
	var me := _me()
	var carrier: Carrier = me.get_node("Carrier")
	me.teleport_to(Vector3(crate.global_position.x, STAND_HEIGHT, crate.global_position.z + GRAB_STAND_OFFSET_Z))

	var deadline := Time.get_ticks_msec() + STEP_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if carrier.held_crate() == crate:
			break
		me.aim_at(crate.global_position)
		carrier.try_toggle_hold(want_drag)
		for _i in 6:
			await get_tree().process_frame

	# Look level afterward, the same reason carry_session does: keeping the
	# aim pointed down at the floor leaves later reach checks a coin toss.
	var level := Vector3(crate.global_position.x, me.camera.global_position.y, crate.global_position.z)
	me.aim_at(level)


## A held crate does not teleport with its holder — it has to physically fly
## to the new hold point every physics frame — so [method _walk_to] closes
## ground in small steps rather than one jump, whether or not anything is
## currently held. Paced by [b]wall-clock time[/b], not a frame count:
## headless Godot runs uncapped, so idle frames can fire far faster than the
## fixed 60 Hz physics tick, and a frame count between steps was measured to
## buy almost no real physics time for the spring to catch up — the very
## first walk in this scenario silently dropped its crate for exactly that
## reason before this was paced by the clock instead.
##
## Kept at or below the in-game drag speed penalty (40% of the 4.2 m/s walk
## speed, so ~1.68 m/s — GDD §6.1) rather than any faster carry speed: the
## drag spring is deliberately softer than the carry one (900 vs 2400
## stiffness) and a walk paced for carry snapped the drag hold mid-transit
## the first time this scenario tried to walk a dragged crate to a cell.
const WALK_SPEED_MPS := 1.5
## How often, in real time, the walk advances the hold point. Small and
## clock-paced, so several physics ticks land inside every step.
const WALK_TICK_MS := 50


## Move the local player toward [param destination] at [constant WALK_SPEED_MPS],
## paced by real elapsed time. See the constants' own doc for why.
func _walk_to(destination: Vector3) -> void:
	var me := _me()
	var start := me.global_position
	var distance := start.distance_to(destination)
	if distance < 0.01:
		return
	var duration_ms := int(ceil((distance / WALK_SPEED_MPS) * 1000.0))
	var start_time := Time.get_ticks_msec()
	var deadline := start_time + duration_ms
	while Time.get_ticks_msec() < deadline:
		var elapsed := Time.get_ticks_msec() - start_time
		var t := clampf(float(elapsed) / float(duration_ms), 0.0, 1.0)
		me.teleport_to(start.lerp(destination, t))
		var tick_deadline := Time.get_ticks_msec() + WALK_TICK_MS
		while Time.get_ticks_msec() < tick_deadline:
			await get_tree().process_frame
	me.teleport_to(destination)


## Walk to a cell and aim at its centre. Shared by every cell interaction.
func _approach_cell(rack: Rack, cell_index: int, lateral: float) -> Vector3:
	var me := _me()
	var target := rack.cell_to_global_position(cell_index)
	await _walk_to(Vector3(target.x + lateral, STAND_HEIGHT, target.z + RACK_STAND_OFFSET_Z))
	me.aim_at(target)
	return target


## Press until whatever we were holding is no longer in our hands — a
## successful placement. Only for cases the caller expects to succeed; a
## refusal would spin this to its timeout, which is what [method _attempt_place]
## is for instead.
func _place(rack: Rack, cell_index: int, lateral: float) -> void:
	var me := _me()
	var carrier: Carrier = me.get_node("Carrier")
	var target := await _approach_cell(rack, cell_index, lateral)

	var deadline := Time.get_ticks_msec() + STEP_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if carrier.held_crate() == null:
			return
		me.aim_at(target)
		carrier.try_toggle_hold()
		for _i in 6:
			await get_tree().process_frame


## A handful of presses at a cell expected to refuse. Deliberately bounded
## rather than looped to success — success here would be the bug.
func _attempt_place(rack: Rack, cell_index: int, lateral: float) -> void:
	var me := _me()
	var carrier: Carrier = me.get_node("Carrier")
	var target := await _approach_cell(rack, cell_index, lateral)

	for _i in 3:
		me.aim_at(target)
		carrier.try_toggle_hold()
		for _j in 6:
			await get_tree().process_frame


## Press until a crate lands in our (previously empty) hands, and return it.
func _retrieve(rack: Rack, cell_index: int, lateral: float) -> Crate:
	var me := _me()
	var carrier: Carrier = me.get_node("Carrier")
	var target := await _approach_cell(rack, cell_index, lateral)

	var deadline := Time.get_ticks_msec() + STEP_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if carrier.held_crate() != null:
			return carrier.held_crate()
		me.aim_at(target)
		carrier.try_toggle_hold()
		for _i in 6:
			await get_tree().process_frame
	return null


## Off to the side of both cells' approach corridor (which sits within about
## a metre of x=7.6-8.8, z=-6.5 for this rack), so a crate dropped here never
## ends up in the path of a later raycast at either one -- but close, not
## across the room: WALK_SPEED_MPS is deliberately slow (it has to stay under
## what the drag spring can follow), and this point is visited twice for
## every retrieve-then-release pair. A far corner turned that into two
## multi-second walks per release and made the LIFO retrievals alone take
## longer than the other peer's own wait budget for seeing the result.
const PARK_POINT := Vector3(4.0, STAND_HEIGHT, -6.5)


## Walk clear, look somewhere that is neither cargo nor a rack cell, and press
## until our hands are empty — the ordinary Phase 0 release. Walking away
## first (rather than dropping on the spot) is what stops a dropped crate
## from later sitting in the ray's path the next time this rack is aimed at.
func _release_held() -> void:
	var me := _me()
	var carrier: Carrier = me.get_node("Carrier")
	if carrier.held_crate() == null:
		return
	await _walk_to(PARK_POINT)
	me.aim_at(me.camera.global_position + Vector3(0.0, 5.0, 0.0))

	var deadline := Time.get_ticks_msec() + STEP_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if carrier.held_crate() == null:
			return
		carrier.try_toggle_hold()
		for _i in 6:
			await get_tree().process_frame


## Polls until the visual at rack/cell_index/sub_index has actually arrived at
## its resting position — the one thing about 01-06's travel-and-settle
## animation a test can genuinely prove. A tween that starts and never
## arrives is the classic tween bug, and it would leave an item visibly
## floating in the aisle on some peers and not others.
##
## Not the bare cell centre: eight Smalls tile a cell as a 2x2x2 lattice
## (StorageGrid.small_offset), so [param sub_index]'s actual target is offset
## from [method Rack.cell_to_local_position] — exactly what
## [code]Rack._spawn_cell_visual[/code] tweens toward.
func _wait_for_settle(rack: Rack, cell_index: int, sub_index: int) -> bool:
	var visual := rack.get_node_or_null("RackedItems/Cell%d_Item%d" % [cell_index, sub_index])
	if visual == null:
		_fail("the placed item settles exactly in its cell", "no visual node Cell%d_Item%d" % [cell_index, sub_index])
		return false
	var target := rack.cell_to_local_position(cell_index) + StorageGrid.small_offset(sub_index)
	return await _until("the placed item settles exactly in its cell", func() -> bool:
			return visual.position.is_equal_approx(target))


func _until(label: String, predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + STEP_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			_pass(label)
			return true
		await get_tree().process_frame
	_fail(label, "timed out after %d ms" % STEP_TIMEOUT_MS)
	return false


## Assert something stays true for a window, rather than merely becoming true
## once — needed for every refusal here, since "still holding it" is trivially
## true in the first frame regardless of whether the refusal actually worked.
func _stays(label: String, predicate: Callable, window_ms := 500) -> bool:
	var deadline := Time.get_ticks_msec() + window_ms
	while Time.get_ticks_msec() < deadline:
		if not predicate.call():
			_fail(label, "stopped being true before the window closed")
			return false
		await get_tree().process_frame
	_pass(label)
	return true


func _expect_now(condition: bool, label: String) -> void:
	if condition:
		_pass(label)
		return
	_fail(label, "expected true, was false")


func _pass(label: String) -> void:
	_steps_passed += 1
	print("[test] ok   %s" % label)


func _fail(label: String, why: String) -> void:
	print("[test] FAIL %s — %s" % [label, why])
	_report_state()


## Printed on failure only: enough state to tell which side disagreed, and
## with what the rack believed, without rerunning anything.
func _report_state() -> void:
	print("[test] state role=%s local_id=%d roster=%d crates=%d" % [
		_role, Net.local_id(), Net.players.size(),
		_crates().get_child_count() if _crates() != null else -1,
	])
	var rack := _rack()
	if rack != null:
		var occ_a := rack.occupied_count(CELL_A)
		var occ_b := rack.occupied_count(CELL_B)
		var visuals := rack.get_node_or_null("RackedItems")
		print("[test] state cell_a=%d/8 cell_b=%d/8 racked_visuals=%d" % [
			occ_a, occ_b, visuals.get_child_count() if visuals != null else -1,
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


func _crate_named(crate_name: String) -> Crate:
	var crates := _crates()
	if crates == null:
		return null
	return crates.get_node_or_null(crate_name) as Crate


func _rack() -> Rack:
	if _world == null:
		return null
	return _world.get_node_or_null(RACK_PATH) as Rack


func _authority() -> CarryAuthority:
	if _world == null:
		return null
	return _world.get_node_or_null("CarryAuthority") as CarryAuthority


func _me() -> Player:
	if _world == null:
		return null
	return _world.get_node_or_null("Players/%d" % Net.local_id()) as Player
