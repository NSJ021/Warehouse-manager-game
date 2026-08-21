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
##
## Two scenarios run back to back on different crates. The first is the carry:
## grab, second holder joins, handoff, release. The second is [b]solo drag[/b],
## with the roles swapped so the [i]client[/i] drags — every verdict then has to
## survive a real RPC, where a host-side drag would exercise only the local
## branch, which is the half that cannot break.

const WORLD_SCENE := preload("res://scenes/levels/test_room.tscn")

## Deliberately not 27015 — the suite must never collide with someone playing.
const TEST_PORT := 27099
const STEP_TIMEOUT_MS := 15000
## Crate name allocation across this suite. Keep this table accurate — a plan
## has already twice picked a crate name another scenario already relied on,
## and the second time silently broke a step several lines later rather than
## failing where the mistake actually was.
##
## | Crate   | Claimed by                                              |
## |---------|----------------------------------------------------------|
## | crate_0 | CRATE_NAME - the carry / handoff choreography           |
## | crate_1 | free                                                     |
## | crate_2 | DESPAWN_PROBE_NAME - the queue_free() replication probe |
## | crate_3 | DRAG_CRATE_NAME - solo drag and its promotion (ADR 19)  |
## | crate_4 | ZONE_PROBE_NAME - Goods IN / Goods OUT zone detection   |
## | crate_5 | LOST_CRATE_NAME - supply conservation                   |
const CRATE_NAME := "crate_0"
const EXPECTED_PLAYERS := 2
## TestRoom's own starting batch (test_room.gd's crate_count), raised to 12 for
## the gate playtest protocol (2026-08-21) — two rows of six rather than one
## row of twelve; see CRATE_ROW2_ORIGIN's own doc comment for why. Every
## crate_0..crate_5 name and position the allocation table above depends on is
## unchanged — the second row (crate_6..crate_11) is unclaimed by any step in
## this file.
const EXPECTED_CRATES := 12
## Cargo rests at about y=0.25 on the floor and hangs near y=0.9 when carried, so
## this separates "picked up" from "sat there" with room to spare.
const LIFT_MIN_Y := 0.55

## How far either side of the crate each role stands, along Z.
##
## Derived from where the crate actually is rather than hard-coded, because
## hard-coding it broke the moment the level's cargo layout changed: the stand
## positions stayed put, the crate moved six metres, and every grab silently
## failed the reach check. Approached along Z on purpose — a small crate count
## lays out as a row along X, so nothing sits between the player and the target.
const HOST_STAND_OFFSET_Z := 1.6
const CLIENT_STAND_OFFSET_Z := -1.2
const STAND_HEIGHT := 0.1

## A crate no other assertion in this suite has claimed. See the allocation
## table above.
const DESPAWN_PROBE_NAME := "crate_2"
## How long the initial 6-crate spawn must read as stable before the despawn
## probe is allowed to fire. Real wall time, not frames, on purpose: headless
## runs uncapped, so a frame count buys no fixed amount of real time for the
## initial MultiplayerSpawner sync to a freshly-joined peer to actually land.
const SPAWN_SETTLE_MS := 500
## A second crate, far enough along the row that the first one falling back to the
## floor at the end of the carry scenario cannot interfere with the drag one.
const DRAG_CRATE_NAME := "crate_3"
## A crate no other scenario touches, pushed out of the world to prove it returns.
const LOST_CRATE_NAME := "crate_5"
## The Goods IN / Goods OUT probe. Teleported into GoodsIn by the host and
## then left standing still, so both peers can independently ask their own
## [GoodsZone] whether it agrees.
const ZONE_PROBE_NAME := "crate_4"
const ZONE_PATH := "Zones/GoodsIn"
const ZONE_OUT_PATH := "Zones/GoodsOut"
## Half a Small's height (0.5 m cube, ADR 18). Landing the zone probe here
## rather than at the zone's own floor-level origin keeps it resting on top
## of the floor instead of embedded in it.
const CRATE_REST_HEIGHT := 0.25
## How long a dragged crate must stay on the floor while its dragger stares at the
## ceiling. A carry spring would have hauled it to eye level many times over in
## this window, so it separates "dragged" from "carried low" rather than merely
## observing that a crate on the floor is on the floor.
const FLOOR_HOLD_MS := 600
## How far the dragger steps back to prove the crate is actually being hauled and
## not just sitting where it was left. Well inside the 2.6 m break distance.
const DRAG_STEP_BACK := 0.8
## How far the crate must have followed before the host accepts that it moved.
const DRAG_FOLLOW_MIN := 0.3
## Drag is deliberately slow (GDD §6.1). Asserted on the dragger's own machine,
## because movement is client-authoritative and this is the only place it applies.
const DRAG_SPEED_SCALE := 0.4
## How long to sit on "client released" before trusting it (01-09). [method
## _take]'s own retry loop is deliberately unawaited (see its docstring) and
## keeps a background press pending for up to six frames after the one that
## actually succeeds — normally resolved in well under this margin, but
## headless is uncapped, so six frames is a real wall-clock span that varies
## with whatever else the process is doing, not a fixed handful of
## milliseconds. Moving on to grab a different crate the instant both signals
## in [code]_run_client[/code]'s own wait go true is not late enough to
## guarantee that stale press has already fired and found nothing to do:
## found by the join's own leftover press landing after crate_0 had already
## been let go, and silently re-grabbing it instead of touching crate_3 at
## all. Comfortably above six frames' worst observed span rather than tuned
## to the minimum that happens to pass.
const TAKE_TAIL_SETTLE_MS := 500

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

	## The load-bearing unknown of the whole phase: a racked crate is meant to be
	## FREED, not frozen (ADR 14 / NFR-01) — a client pays ~40 µs/frame merely for
	## a rigid body to exist, awake or asleep, so Phase 1's "static and
	## unreplicated" design only works if MultiplayerSpawner replicates the
	## despawn of a node spawned through a custom spawn_function when the host
	## calls queue_free() on it. The docs describe the mechanism and player
	## disconnects already lean on it, but nobody had ever asserted it for the
	## crate path before this plan. Both roles run the poll below, but only the
	## host frees — asserted on the CLIENT because the host believing a node is
	## gone proves nothing, only the client's own replicated view does. This
	## must stay in the suite forever: an engine upgrade could silently take the
	## guarantee away and nothing else here would notice.
	if _role == "host":
		# The host reaches "all 6 crates replicated" in the same script
		# continuation it learns the client has joined roster, and
		# MultiplayerSpawner's initial sync of already-existing nodes to that
		# new peer is queued in that very same moment. Freeing crate_2
		# immediately would let its despawn RPC ride the same network flush as
		# the tail of that initial sync, so the client's own Crates node could
		# go 5→6→5 inside network processing it never gets a polled frame to
		# observe — "all 6 crates replicated" would then never read true on
		# the client, not because despawn replication is broken, but because
		# the harness raced its own precondition. Real wall time, not frames,
		# on purpose: headless runs uncapped, so a frame count buys no fixed
		# amount of real time for the sync to land. Host-only: the client
		# needs no matching wait, since the despawn poll below already has its
		# own full timeout budget to catch the despawn whenever it lands.
		var settle_deadline := Time.get_ticks_msec() + SPAWN_SETTLE_MS
		while Time.get_ticks_msec() < settle_deadline:
			await get_tree().process_frame

		var despawn_target := _crates().get_node_or_null(DESPAWN_PROBE_NAME)
		if despawn_target == null:
			_fail("find %s" % DESPAWN_PROBE_NAME, "not present under Crates")
			return _finish(false)
		despawn_target.queue_free()
		print("[test]      (host freed %s)" % DESPAWN_PROBE_NAME)
	if not await _until("%s despawned on this peer" % DESPAWN_PROBE_NAME, func() -> bool:
			return _crates().get_node_or_null(DESPAWN_PROBE_NAME) == null and _crates().get_child_count() == EXPECTED_CRATES - 1):
		return _finish(false)

	if not await _check_goods_zones():
		return _finish(false)

	if not await _until("own body spawned", func() -> bool: return _me() != null):
		return _finish(false)

	var crate := _crate()
	if crate == null:
		_fail("find %s" % CRATE_NAME, "not present under Crates")
		return _finish(false)

	print("[test]      (crate_0 is at %v)" % crate.global_position)
	if _role == "host":
		await _run_host(crate)
	else:
		await _run_client(crate)


## Both peers run this before the role split (01-05). The host teleports the
## probe crate into GoodsIn — the same determinism trick [method _take] uses
## on players — and both peers then ask their [i]own[/i] [GoodsZone] whether
## it agrees, rather than only proving the host's opinion.
##
## ⚠ The probe crate is teleported in and then left standing still, which is
## harmless in Phase 1 but not forever: once 01-09 (wave 6) lands, a crate
## left standing still SETTLES — frozen, FREEZE_MODE_STATIC, moved onto the
## world layer (ADR 17) — on the [i]host[/i] too, not only on a client's
## puppet. If [method GoodsZone.count] ever silently drops to 0 once that
## lands, this is why: Area3D overlap has to keep reporting a settled crate,
## because Goods OUT must detect stock that has sat there all day. That is a
## design constraint on [GoodsZone], not a test artefact — report it rather
## than working around it if it turns out not to hold.
func _check_goods_zones() -> bool:
	var goods_in := _world.get_node_or_null(ZONE_PATH) as GoodsZone
	var goods_out := _world.get_node_or_null(ZONE_OUT_PATH) as GoodsZone
	if goods_in == null or goods_out == null:
		_fail("find zones", "%s or %s not present under %s" % [ZONE_PATH, ZONE_OUT_PATH, _world.name])
		return false

	if _role == "host":
		var probe := _crate_named(ZONE_PROBE_NAME)
		if probe == null:
			_fail("find %s" % ZONE_PROBE_NAME, "not present under Crates")
			return false
		# Teleporting a body for determinism - the same trick _take() uses on
		# players. Raised by CRATE_REST_HEIGHT rather than dropped exactly on
		# [member GoodsZone.global_position]: the zone's own origin sits at
		# floor level (y=0), and a Small's centre needs to be at its own
		# half-height to rest on top of the floor rather than embedded in it.
		# Found the hard way: landing it exactly at y=0 half-buries the crate,
		# and because [member RigidBody3D.sleeping] is forced false below, it
		# never settles quietly enough to fall back asleep on its own — it
		# jitters against the floor indefinitely, which is what actually
		# carried it off the level over the course of a full run rather than
		# any zone-detection code being at fault.
		probe.global_position = goods_in.global_position + Vector3(0.0, CRATE_REST_HEIGHT, 0.0)
		probe.linear_velocity = Vector3.ZERO
		probe.angular_velocity = Vector3.ZERO
		probe.sleeping = false

	if not await _until("GoodsIn sees exactly one crate", func() -> bool:
			return goods_in.count() == 1):
		return false
	if not await _until("GoodsIn names the right crate", func() -> bool:
			var found := goods_in.contents()
			return found.size() == 1 and String(found[0].name) == ZONE_PROBE_NAME):
		return false
	# A detector that reports everything is not a detector.
	if not await _until("GoodsOut stays empty", func() -> bool:
			return goods_out.count() == 0):
		return false

	# Host-only: let the probe settle back to rest before the carry scenario
	# starts. It was placed exactly at rest height with zero velocity, so this
	# is normally immediate — but skipping it left a still-awake, still-
	# replicating crate active on the exact frames the carry/handoff sequence
	# runs, which was enough to disturb that scenario's own timing (found
	# 2026-08-20). Nothing here reads [member Crate.sleeping] from a client:
	# clients never simulate cargo (only the host runs [method
	# Crate._physics_process]), so only the host has anything to wait for.
	#
	# ⚠ Checks [member Crate.sync_settled] rather than [member
	# Crate.sleeping] (01-09). Once ADR 17 landed, a still probe FREEZES to
	# FREEZE_MODE_STATIC well before the engine's own sleep timer would ever
	# fire — and a frozen body was measured to never report sleeping=true on
	# its own, so the old sleeping-only wait hung the full 15s timeout every
	# run. sync_settled is in every sense the stronger signal anyway: it is
	# the point past which this crate stops replicating at all, which is the
	# actual property this wait exists to guarantee. sleeping stays as a
	# fallback in case a future tuning change ever raises settle_frames past
	# the engine's own sleep timer, so this crate can rest asleep without
	# ever freezing and still unblock this wait.
	if _role == "host":
		var probe := _crate_named(ZONE_PROBE_NAME)
		if not await _until("zone probe settled", func() -> bool:
				return probe != null and (probe.sync_settled or probe.sleeping)):
			return false
	return true


func _stand_beside(crate: Crate, offset_z: float) -> Vector3:
	return Vector3(crate.global_position.x, STAND_HEIGHT, crate.global_position.z + offset_z)


func _run_host(crate: Crate) -> void:
	await _check_supply_is_conserved()

	_take(_stand_beside(crate, HOST_STAND_OFFSET_Z), crate)
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

	await _run_host_drag()


## Cargo that leaves the world comes back rather than being freed.
##
## This is a supply-conservation check, not a tidiness one. An order needs a real
## number of real crates, and nothing in v1 removes cargo from the warehouse
## except handing it to a client — Destroyed is a condition, not deletion. A crate
## through the floor would therefore be stock that can never be delivered, on a
## clock that keeps running, and freeing it is the one line of tidy-up that would
## make a run unwinnable.
##
## Host-side, because supply conservation is a host-authoritative invariant: the
## host owns every rigid body, so if it agrees the crate is back, it is back.
func _check_supply_is_conserved() -> void:
	var crate := _crate_named(LOST_CRATE_NAME)
	if crate == null:
		_fail("find %s" % LOST_CRATE_NAME, "not present under Crates")
		return _finish(false)

	var before := _crates().get_child_count()
	crate.global_position = Vector3(0.0, Crate.RECOVERY_FLOOR_Y - 5.0, 0.0)

	if not await _until("a crate that fell out of the world came back", func() -> bool:
			return crate.recovery_count > 0):
		return _finish(false)
	if not await _until("and came back above the floor", func() -> bool:
			return crate.global_position.y > Crate.RECOVERY_FLOOR_Y):
		return _finish(false)
	# The assertion that actually matters: recovered, not replaced or freed.
	_expect_now(
		_crates().get_child_count() == before,
		"no crate was lost recovering it (%d before, %d after)" % [
			before, _crates().get_child_count(),
		],
	)


## The host's half of the drag scenario. The client does the dragging, so the
## verdict and every later mode change have to survive an actual RPC — a
## host-side drag would exercise only the local branch, which is the half that
## cannot break.
func _run_host_drag() -> void:
	var crate := _crate_named(DRAG_CRATE_NAME)
	if crate == null:
		_fail("find %s" % DRAG_CRATE_NAME, "not present under Crates")
		return _finish(false)

	var started_z := crate.global_position.z
	if not await _until("client started dragging %s" % DRAG_CRATE_NAME, func() -> bool:
			return crate.holder_count() == 1):
		return _finish(false)

	# Doubles as the handshake. The client runs its own floor assertions and then
	# steps back, so waiting for the crate to have followed it is both a real
	# assertion — a drag hauls cargo along the floor — and proof the client has
	# finished, without either side waiting on a clock.
	if not await _until("dragged crate followed the dragger", func() -> bool:
			return absf(crate.global_position.z - started_z) > DRAG_FOLLOW_MIN):
		return _finish(false)
	if not await _until("host sees it still on the floor", func() -> bool:
			return crate.global_position.y < LIFT_MIN_Y):
		return _finish(false)

	# Grabbing the other end is what promotes a solo drag into a two-player carry.
	_take(_stand_beside(crate, HOST_STAND_OFFSET_Z), crate)
	if not await _until("host joined, making two holders", func() -> bool:
			return crate.holder_count() == 2):
		return _finish(false)
	if not await _until("promotion lifted it off the floor", func() -> bool:
			return crate.global_position.y > LIFT_MIN_Y):
		return _finish(false)

	# The client lets go first and the host waits for it, so the host is the last
	# process standing. The other way round kills the session out from under the
	# client mid-assertion, which reads as a product failure and is not one.
	if not await _until("client let go, leaving the host holding", func() -> bool:
			return crate.holder_count() == 1):
		return _finish(false)
	# Now the host is the sole holder, and it asked to carry. The drag request
	# belonged to the client, so it must not be inherited along with the crate.
	if not await _until("crate stays carried, not inherited as a drag", func() -> bool:
			return crate.hold_mode() == Crate.HoldMode.CARRY):
		return _finish(false)

	var carrier: Carrier = _me().get_node("Carrier")
	carrier.try_toggle_hold()
	if not await _until("host let go of the drag crate", func() -> bool:
			return crate.holder_count() == 0):
		return _finish(false)

	_finish(true)


func _run_client(crate: Crate) -> void:
	if not await _until("host grabbed first", func() -> bool: return crate.holder_count() == 1):
		return _finish(false)

	_take(_stand_beside(crate, CLIENT_STAND_OFFSET_Z), crate)
	if not await _until("client joined the carry", func() -> bool:
			return crate.holder_count() == 2):
		return _finish(false)

	# [constant TAKE_TAIL_SETTLE_MS]'s own margin, as early as it can go: this
	# join's own [method _take] call above is unawaited (see that function's
	# docstring) and can still have one more retry press pending for up to six
	# frames after the press that actually succeeded — headless is uncapped,
	# so six frames is real, variable wall-clock time, not a fixed handful of
	# milliseconds. Placed here rather than only right before the release
	# later in this function so the whole rest of the carry/handoff sequence
	# below (which itself takes real time) is extra margin on top, not the
	# only margin there is. See that constant's own doc for the race this
	# closes: a stale press from this exact loop landing after the crate had
	# already been let go, and silently re-grabbing it.
	var settle_deadline := Time.get_ticks_msec() + TAKE_TAIL_SETTLE_MS
	while Time.get_ticks_msec() < settle_deadline:
		await get_tree().process_frame

	# Asserted on the client too: proves the lift replicated, not just that the
	# host believes it happened.
	if not await _until("client sees it lifted", func() -> bool:
			return crate.global_position.y > LIFT_MIN_Y):
		return _finish(false)

	if not await _until("host handed off", func() -> bool: return crate.holder_count() == 1):
		return _finish(false)

	var carrier: Carrier = _me().get_node("Carrier")
	carrier.try_toggle_hold()
	# Both signals, not just the replicated one (01-09 found the gap). Holder
	# count updates as soon as the HOST's own [method Crate._physics_process]
	# next runs; on_hold_granted's ray exception is only cleared once the
	# separate _hold_revoked RPC actually reaches THIS client, and those two
	# arrivals are not ordered against each other.
	if not await _until("client released", func() -> bool:
			return crate.holder_count() == 0 and carrier.held_crate() == null):
		return _finish(false)

	await _run_client_drag()


## The client's half of the drag scenario, and the side that matters: every
## verdict here crossed the wire.
##
## Three things get proved that a carry cannot prove. The host tells the asker
## what kind of hold it granted. A dragged crate stays on the floor even when the
## dragger looks straight up — which is the mechanical reason a solo player cannot
## rack anything, and the whole incentive behind two-player carry (GDD §6.1). And
## when someone grabs the other end, the promotion reaches the dragger's own
## machine, so their speed penalty lifts.
func _run_client_drag() -> void:
	var crate := _crate_named(DRAG_CRATE_NAME)
	if crate == null:
		_fail("find %s" % DRAG_CRATE_NAME, "not present under Crates")
		return _finish(false)

	var me := _me()
	var carrier: Carrier = me.get_node("Carrier")
	_take(_stand_beside(crate, CLIENT_STAND_OFFSET_Z), crate, true)

	if not await _until("host granted a DRAG, not a carry", func() -> bool:
			return carrier.is_dragging()):
		return _finish(false)
	if not await _until("drag speed penalty applied locally", func() -> bool:
			return is_equal_approx(carrier.speed_scale(), DRAG_SPEED_SCALE)):
		return _finish(false)

	# Look at the ceiling. A carry would haul the crate up to the eyeline; a drag
	# reads the capsule's yaw and ignores pitch entirely, so it must stay put.
	me.aim_at(me.camera.global_position + Vector3(0.0, 4.0, -0.5))
	if not await _stays("stays on the floor while the dragger looks up", func() -> bool:
			return crate.global_position.y < LIFT_MIN_Y):
		return _finish(false)

	# Step back, which the host is waiting to see the crate follow.
	me.teleport_to(me.global_position + Vector3(0.0, 0.0, -DRAG_STEP_BACK))
	if not await _until("crate followed us as we backed away", func() -> bool:
			return crate.global_position.y < LIFT_MIN_Y and carrier.is_dragging()):
		return _finish(false)

	if not await _until("host joined, making two holders", func() -> bool:
			return crate.holder_count() == 2):
		return _finish(false)
	# The assertion this whole scenario exists for: the mode changed on the host
	# and the dragger's own machine was told. Without it a promoted dragger would
	# keep walking at 40% for no reason they could see.
	if not await _until("promotion reached the dragger over the wire", func() -> bool:
			return not carrier.is_dragging()):
		return _finish(false)
	if not await _until("speed penalty lifted with it", func() -> bool:
			return is_equal_approx(carrier.speed_scale(), 1.0)):
		return _finish(false)
	if not await _until("client sees the promoted crate lifted", func() -> bool:
			return crate.global_position.y > LIFT_MIN_Y):
		return _finish(false)

	carrier.try_toggle_hold()
	if not await _until("client released the drag crate", func() -> bool:
			return not carrier.is_dragging() and carrier.held_crate() == null):
		return _finish(false)

	_finish(true)


## Stand next to the crate, look at it, and press the equivalent of E.
##
## Retried rather than done once, because the host judges reach from this peer's
## *replicated* position, which eases toward the teleport over a few frames. A
## fixed wait would be a flake waiting to happen; retrying until the state changes
## is deterministic in outcome.
##
## [b]Deliberately called without `await`.[/b] Every call site fires the
## request synchronously (the loop's first iteration runs before its first
## internal `await`) and then leaves this to keep retrying as a detached
## coroutine while the caller moves on to its own state-based `_until` polls —
## which is what actually decides pass or fail. Tried awaiting every call site
## instead (2026-08-20, in case of an interaction with 01-05's zone probe) and
## it made things worse: serialising all four calls stretched the carry/handoff
## sequence enough to occasionally collapse the two-holder state out of a
## single 20 Hz replication tick before the client ever observed it. Reverted;
## the two things that actually needed fixing were the zone probe embedding
## itself in the floor and never settling (below), and letting it stay awake
## and replicating into the timing-sensitive carry scenario that follows.
func _take(stand: Vector3, crate: Crate, want_drag := false) -> void:
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
		carrier.try_toggle_hold(want_drag)
		attempts += 1
		for _i in 6:
			await get_tree().process_frame
	print("[test]      (%s requested, attempts=%d)" % [
		"drag" if want_drag else "grab", attempts,
	])

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


## Assert something stays true for a window, rather than merely becoming true once.
##
## Needed because the interesting drag assertion is a negative — the crate does
## [i]not[/i] rise — and a crate that is already on the floor satisfies that in the
## first frame whether or not anything is holding it. Holding it across a window
## while the dragger looks up is what makes it evidence.
func _stays(label: String, predicate: Callable, window_ms := FLOOR_HOLD_MS) -> bool:
	var deadline := Time.get_ticks_msec() + window_ms
	while Time.get_ticks_msec() < deadline:
		if not predicate.call():
			_fail(label, "stopped being true after %d ms" % (window_ms - (deadline - Time.get_ticks_msec())))
			return false
		await get_tree().process_frame
	_pass(label)
	return true


## A one-shot assertion for things already true rather than waited for.
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
	if _world != null:
		var goods_in := _world.get_node_or_null(ZONE_PATH) as GoodsZone
		var goods_out := _world.get_node_or_null(ZONE_OUT_PATH) as GoodsZone
		print("[test] state GoodsIn.count=%d GoodsOut.count=%d" % [
			goods_in.count() if goods_in != null else -1,
			goods_out.count() if goods_out != null else -1,
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
	return _crate_named(CRATE_NAME)


func _crate_named(crate_name: String) -> Crate:
	var crates := _crates()
	if crates == null:
		return null
	return crates.get_node_or_null(crate_name) as Crate


func _me() -> Player:
	if _world == null:
		return null
	return _world.get_node_or_null("Players/%d" % Net.local_id()) as Player
