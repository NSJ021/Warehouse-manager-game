extends Node

## Integration layer: the day loop, across two real processes.
##
## Sibling to carry_session.gd and storage_session.gd — same shape
## (`--role=host` / `--role=client`, the real test_room.tscn, its own port,
## waits on state rather than time, prints both sides' state on failure) —
## but a different scenario entirely: this one is the first and only thing
## that ever calls [method DayClock.begin_run]. `test_room.gd` connects to
## it directly (host-only), so nothing here has to poke the level's own
## spawning; this scenario just watches and asserts.
##
## [b]This scenario owns the day loop; 02-10 extends it with the door-down
## half.[/b] Say so here so the split is obvious to whoever opens this file
## next.
##
## Both `carry_session.gd` and `storage_session.gd` instance `test_room.tscn`
## with a dead clock, deliberately (`day_clock.gd`'s own class doc). This
## scenario is the one place that clock actually runs — with a SHORT day
## (`DAY_LENGTH_SECONDS`/`MORNING_SECONDS`, a pinned `GOODS_RUN_SEED`) set on
## the instanced level's [DayClock] BEFORE it is added to the tree, the same
## trick that lets this scenario have a day while the other two do not.
## Pinning the seed is what turns the assertions below into concrete numbers
## rather than ranges — see [method _expected_manifest]'s own doc comment.
##
## Asserts, in order:
##   1. Session up, both peers in the roster, world loaded, all of TestRoom's
##      starting batch replicated, own body spawned — the same preamble
##      shape every scenario in this suite already has.
##   2. The host calls [method DayClock.begin_run]. BOTH peers independently
##      reach [constant DayClock.Phase.MORNING] and day 1.
##   3. BOTH peers hold a manifest whose [code]to_dict()[/code] matches what
##      [DaySchedule] would deterministically author for the same pinned
##      inputs — see [method _expected_manifest]'s own doc comment for why
##      this, by itself, is not a complete proof that the client RECEIVED
##      rather than generated one, and what closes that gap.
##   4. The delivery arrives: the CLIENT's own loose-crate count rises by
##      exactly the manifest's [method DayManifest.total_crates], and the
##      newly arrived crates' own records — grouped by (category, size,
##      store_until_day), never by name — match the manifest's own rows
##      exactly. Proven on the client's own copy, which is really a check
##      that the spawn-data channel (02-04) carries a manifest-authored
##      record correctly cross-peer, not merely that SOME crates arrived.
##   5. Every delivered crate sits inside GoodsIn — reuses 01-05's own zone
##      check, which already proves both peers agree about a zone's contents.
##   6. The clock advances to SHIFT on both peers, and the door is OPEN on
##      both — read from [DockDoor]'s own slab position, not the clock, so
##      this proves the door derives itself correctly from replicated state
##      rather than being told to open.
##   7. AFTER_HOURS: a CLIENT's own [method DayClock.request_call_it_a_night]
##      is proven to do nothing (a [code]_stays[/code] window on the host),
##      THEN the host's own call is proven to work — both reach
##      [constant DayClock.Phase.MIDNIGHT], then [member DayClock.sync_day]
##      becomes 2 on both.
##
## [b]Crate-name allocation is different here from every other scenario in
## this suite.[/b] `carry_session.gd` and `storage_session.gd` both claim
## specific `crate_N` names because their crates are static fixtures, minted
## once at world load and never again. This is the first scenario where
## crates are minted DURING the run (the truck dump) rather than only at
## startup — so this file must never assume a delivered crate's name; it
## diffs the crate container's own children before and after the dump and
## identifies what arrived by RECORD CONTENTS, not by id. This scenario does
## get its own fresh id space (its own process pair, its own world, ids from
## 0), exactly as `storage_session` is fresh relative to `carry_session` —
## that part is unchanged; only "which name is which crate" is not assumable.

const WORLD_SCENE := preload("res://scenes/levels/test_room.tscn")

## Deliberately none of `carry_session`'s 27099, `storage_session`'s 27097, a
## live game's 27015, or the stress test's own.
const TEST_PORT := 27095

const STEP_TIMEOUT_MS := 20000
const EXPECTED_PLAYERS := 2
## TestRoom's own starting batch (`test_room.gd`'s `crate_count`) — untouched
## by this scenario, same default every other scenario in this suite uses.
const EXPECTED_STARTING_CRATES := 17

## Short enough that the whole loop (MORNING -> SHIFT -> AFTER_HOURS ->
## MIDNIGHT -> day 2) fits comfortably inside this suite's own per-run
## budget, long enough that the truck dump still visibly spreads rather than
## reading as instantaneous. `open_fraction` and `ceremony_seconds` are left
## at DayClock's own defaults — nothing here needs them retuned too.
const DAY_LENGTH_SECONDS := 20.0
const MORNING_SECONDS := 4.0
## Pinned so every assertion below compares against a concrete, reproducible
## manifest rather than a range — see [method _expected_manifest]'s own doc
## comment.
const GOODS_RUN_SEED := 4242

## How long the host waits, after its own last network-relevant action,
## before quitting — see `storage_session.gd`'s own identical constant for
## why (`get_tree().quit()` does not flush a pending reliable send first).
const EXIT_SETTLE_MS := 500
## How long the host holds its own [code]_stays[/code] window proving a
## client's [method DayClock.request_call_it_a_night] did nothing, before
## making its OWN real call — long enough that the client's own (ignored)
## attempt has certainly already landed and been rejected.
const IGNORED_CALL_WINDOW_MS := 1200

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


## The short day is pinned on the instanced level's own [DayClock] HERE,
## before [method Node.add_child] — the same "configure the export, then add
## it to the tree" ordering `day_clock.gd`'s own class doc names as the
## trick that lets this scenario have a day while `carry_session.gd` and
## `storage_session.gd` do not (neither of those ever touches this clock's
## exports, so it stays at [constant DayClock.Phase.IDLE] for them, exactly
## as intended).
func _on_session_started(as_host: bool) -> void:
	if _world != null:
		return
	_world = WORLD_SCENE.instantiate()
	var clock := _world.get_node("DayClock") as DayClock
	clock.day_length_seconds = DAY_LENGTH_SECONDS
	clock.morning_seconds = MORNING_SECONDS
	clock.run_seed = GOODS_RUN_SEED
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
	if not await _until("all %d starting crates replicated" % EXPECTED_STARTING_CRATES, func() -> bool:
			return _crates() != null and _crates().get_child_count() == EXPECTED_STARTING_CRATES):
		return _finish(false)
	if not await _until("own body spawned", func() -> bool: return _me() != null):
		return _finish(false)

	var clock := _clock()
	if clock == null:
		_fail("find DayClock", "not present under the world")
		return _finish(false)

	if _role == "host":
		await _run_host(clock)
	else:
		await _run_client(clock)


# --------------------------------------------------------------- host role

func _run_host(clock: DayClock) -> void:
	# --- 2: begin the run. Both peers reach MORNING, day 1. ---
	var before_dump_crate_names := _crate_name_set()
	clock.begin_run()
	if not await _until("host: phase is MORNING", func() -> bool:
			return clock.phase() == DayClock.Phase.MORNING):
		return _finish(false)
	_expect_now(clock.current_day() == 1, "host: day is 1")

	# --- 3: the manifest matches what DaySchedule would deterministically
	# author for these pinned inputs. ---
	if not await _until("host: manifest posted", func() -> bool:
			return clock.manifest() != null):
		return _finish(false)
	var expected := _expected_manifest()
	_expect_now(
		(clock.manifest().to_dict() as Dictionary) == expected,
		"host: manifest matches DaySchedule.manifest_for's own deterministic output",
	)

	# --- 4/5: the delivery arrives, matches the manifest's rows, and lands
	# inside GoodsIn. Proven on the HOST here; step 4's own doc comment
	# explains why the client's copy is the one that actually matters, and
	# the client asserts the same shape independently in _run_client. ---
	var total := clock.manifest().total_crates()
	if not await _until("host: delivery arrived (%d crates)" % total, func() -> bool:
			return _crates().get_child_count() == EXPECTED_STARTING_CRATES + total):
		return _finish(false)
	_expect_now(
		_group_rows(clock.manifest().all_rows()) == _group_delivered_crates(before_dump_crate_names),
		"host: delivered crates match the manifest's rows (category, size, store_until_day, count)",
	)

	var goods_in := _goods_in()
	if not await _until("host: every delivered crate is inside GoodsIn", func() -> bool:
			return goods_in.count() == total):
		return _finish(false)

	# --- 6: SHIFT, and the door is open. ---
	if not await _until("host: phase is SHIFT", func() -> bool:
			return clock.phase() == DayClock.Phase.SHIFT):
		return _finish(false)
	var slab := _dock_door_slab()
	if not await _until("host: the dock door is open (slab position, not the clock)", func() -> bool:
			return slab.position.y > _dock_door().door_height):
		return _finish(false)

	# --- 7: AFTER_HOURS. A client's own request is proven to do nothing
	# BEFORE the host's own real call — see IGNORED_CALL_WINDOW_MS's own doc
	# comment for why the ordering matters. ---
	if not await _until("host: phase is AFTER_HOURS", func() -> bool:
			return clock.phase() == DayClock.Phase.AFTER_HOURS):
		return _finish(false)
	if not await _stays(
			"host: a client's own request_call_it_a_night does nothing (ADR 21 - host decides, no vote)",
			func() -> bool: return clock.phase() == DayClock.Phase.AFTER_HOURS,
			IGNORED_CALL_WINDOW_MS):
		return _finish(false)

	clock.request_call_it_a_night()
	if not await _until("host: the host's own call reaches MIDNIGHT", func() -> bool:
			return clock.phase() == DayClock.Phase.MIDNIGHT):
		return _finish(false)
	if not await _until("host: the day rolls to 2", func() -> bool:
			return clock.current_day() == 2):
		return _finish(false)

	await get_tree().create_timer(float(EXIT_SETTLE_MS) / 1000.0).timeout
	_finish(true)


# ------------------------------------------------------------- client role

func _run_client(clock: DayClock) -> void:
	var before_dump_crate_names := _crate_name_set()

	# --- 2: both peers reach MORNING, day 1 - derived from replicated state,
	# never generated locally (the client never calls begin_run() itself). ---
	if not await _until("client: phase is MORNING", func() -> bool:
			return clock.phase() == DayClock.Phase.MORNING):
		return _finish(false)
	_expect_now(clock.current_day() == 1, "client: day is 1")

	# --- 3: the manifest this peer RECEIVED matches what DaySchedule would
	# deterministically author. See _expected_manifest's own doc comment for
	# why this needs the negative-control check in this plan's own
	# verification instructions to be a complete proof, and why that check
	# is a one-time manual step rather than committed code. ---
	if not await _until("client: manifest received", func() -> bool:
			return clock.manifest() != null):
		return _finish(false)
	var expected := _expected_manifest()
	_expect_now(
		(clock.manifest().to_dict() as Dictionary) == expected,
		"client: manifest matches DaySchedule.manifest_for's own deterministic output",
	)

	# --- 4/5: the delivery arrived on THIS peer's own copy, matches the
	# manifest's rows, and lands inside GoodsIn. This is the assertion that
	# would catch a broken spawn-data channel — 02-04's own record-carrying
	# crate data, proven cross-peer for the first time by a scenario where
	# crates are minted DURING the run rather than only at startup. ---
	var total := clock.manifest().total_crates()
	if not await _until("client: delivery arrived (%d crates)" % total, func() -> bool:
			return _crates().get_child_count() == EXPECTED_STARTING_CRATES + total):
		return _finish(false)
	_expect_now(
		_group_rows(clock.manifest().all_rows()) == _group_delivered_crates(before_dump_crate_names),
		"client: delivered crates match the manifest's rows (category, size, store_until_day, count) - on the CLIENT's own copies",
	)

	var goods_in := _goods_in()
	if not await _until("client: every delivered crate is inside GoodsIn", func() -> bool:
			return goods_in.count() == total):
		return _finish(false)

	# --- 6: SHIFT, door open - the client's OWN DockDoor instance, not the
	# host's, proving it derives itself locally from replicated phase. ---
	if not await _until("client: phase is SHIFT", func() -> bool:
			return clock.phase() == DayClock.Phase.SHIFT):
		return _finish(false)
	var slab := _dock_door_slab()
	if not await _until("client: the dock door is open (slab position, not the clock)", func() -> bool:
			return slab.position.y > _dock_door().door_height):
		return _finish(false)

	# --- 7: AFTER_HOURS. This peer's own request is the one under test - it
	# must reach the host (over the real wire) and do nothing. ---
	if not await _until("client: phase is AFTER_HOURS", func() -> bool:
			return clock.phase() == DayClock.Phase.AFTER_HOURS):
		return _finish(false)
	print("[test] client: calling request_call_it_a_night - this must be ignored")
	clock.request_call_it_a_night.rpc_id(1)
	if not await _stays(
			"client: my own request_call_it_a_night does nothing (ADR 21 - host decides, no vote)",
			func() -> bool: return clock.phase() == DayClock.Phase.AFTER_HOURS,
			IGNORED_CALL_WINDOW_MS):
		return _finish(false)

	if not await _until("client: the host's own call reaches MIDNIGHT", func() -> bool:
			return clock.phase() == DayClock.Phase.MIDNIGHT):
		return _finish(false)
	if not await _until("client: the day rolls to 2", func() -> bool:
			return clock.current_day() == 2):
		return _finish(false)

	_finish(true)


# -------------------------------------------------------------- the expected manifest

## What [DaySchedule] deterministically authors for THIS scenario's own
## pinned inputs — day 1, [constant GOODS_RUN_SEED], no locked rows (a fresh
## clock's own [code]_carried_locked_rows[/code] starts empty), crew size
## [constant EXPECTED_PLAYERS], and every cap left at its DEFAULT
## (`DayClock`'s own exports are untouched by this scenario).
##
## [b]Computed independently here, never read off either peer's own
## [DayClock][/b] — each peer runs this exact same pure function locally and
## compares it against what its own clock actually holds. That is a REAL
## cross-process assertion (both processes, running identical code, agree
## the manifest matches a known, deterministically-recomputed shape) — but
## on its own it is not a COMPLETE proof that the client received the
## manifest rather than generating an identical one itself, because
## determinism means a client that (incorrectly) called
## [method DaySchedule.manifest_for] with these same inputs would ALSO pass
## this exact check. This plan's own verification instructions close that
## gap with a one-time MANUAL negative control instead of permanent test
## code: temporarily make the client generate its own manifest, confirm this
## assertion goes red, then revert — proving the assertion is at least
## capable of failing, which a check that always passes silently would not.
func _expected_manifest() -> Dictionary:
	return DaySchedule.manifest_for(1, [], GOODS_RUN_SEED, EXPECTED_PLAYERS).to_dict()


# ------------------------------------------------------------------ grouping

## `"category|size|store_until_day"` — the shape a delivered crate and a
## manifest row are compared by, deliberately never by name or id (see this
## file's own class doc on why: this is the first scenario where crates are
## minted during the run rather than only at startup).
func _row_shape_key(category: StringName, size: int, store_until_day: int) -> String:
	return "%s|%d|%d" % [category, size, store_until_day]


func _group_rows(rows: Array) -> Dictionary:
	var grouped: Dictionary = {}
	for row in rows:
		var r := row as Dictionary
		var key := _row_shape_key(StringName(r["category"]), int(r["size"]), int(r["store_until_day"]))
		grouped[key] = int(grouped.get(key, 0)) + int(r["count"])
	return grouped


## Every crate currently in the container whose NAME was not present in
## [param before_names] — the truck dump's own arrivals, identified by what
## changed rather than by any assumed id.
func _group_delivered_crates(before_names: Dictionary) -> Dictionary:
	var grouped: Dictionary = {}
	for child in _crates().get_children():
		if before_names.has(child.name):
			continue
		var crate := child as Crate
		if crate == null or crate.record == null:
			continue
		var key := _row_shape_key(crate.record.category, crate.record.size, crate.record.store_until_day)
		grouped[key] = int(grouped.get(key, 0)) + 1
	return grouped


func _crate_name_set() -> Dictionary:
	var names: Dictionary = {}
	for child in _crates().get_children():
		names[child.name] = true
	return names


# --------------------------------------------------------------------- helpers

func _until(label: String, predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + STEP_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			_pass(label)
			return true
		await get_tree().process_frame
	_fail(label, "timed out after %d ms" % STEP_TIMEOUT_MS)
	return false


## Assert something stays true for a window, rather than merely becoming
## true once — needed for both "nothing happened" checks in step 7.
func _stays(label: String, predicate: Callable, window_ms: int) -> bool:
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


## Printed on failure only: enough state to tell which side disagreed
## without rerunning anything.
func _report_state() -> void:
	print("[test] state role=%s local_id=%d roster=%d crates=%d" % [
		_role, Net.local_id(), Net.players.size(),
		_crates().get_child_count() if _crates() != null else -1,
	])
	var clock := _clock()
	if clock != null:
		print("[test] state day=%d phase=%s manifest=%s" % [
			clock.current_day(), clock.phase_name(),
			"null" if clock.manifest() == null else str(clock.manifest().to_dict()),
		])
	var goods_in := _goods_in()
	if goods_in != null:
		print("[test] state goods_in_count=%d" % goods_in.count())
	var slab := _dock_door_slab()
	if slab != null:
		print("[test] state dock_door_slab_y=%.3f" % slab.position.y)


## Silence any still-playing audio before quitting — the same fix
## `storage_session.gd` needed (a racking thud outliving the tree), applied
## here even though nothing in this scenario racks anything: a settling
## crate (there are several) plays no audio of its own today, but this keeps
## the same defensive shutdown shape every scenario in this suite follows.
func _silence_audio() -> void:
	_stop_players_under(get_tree().root)


func _stop_players_under(node: Node) -> void:
	if node is AudioStreamPlayer3D or node is AudioStreamPlayer:
		node.stop()
	for child: Node in node.get_children():
		_stop_players_under(child)


func _finish(passed: bool) -> void:
	print("[test] RESULT=%s role=%s steps_passed=%d" % [
		"PASS" if passed else "FAIL", _role, _steps_passed,
	])
	_silence_audio()
	for _i in 12:
		await get_tree().process_frame
	_silence_audio()
	get_tree().quit(0 if passed else 1)


func _crates() -> Node:
	if _world == null:
		return null
	return _world.get_node_or_null("Crates")


func _clock() -> DayClock:
	return get_tree().get_first_node_in_group("day_clock") as DayClock


func _dock_door() -> DockDoor:
	if _world == null:
		return null
	return _world.get_node_or_null("Geometry/DockDoor") as DockDoor


func _dock_door_slab() -> Node3D:
	var door := _dock_door()
	if door == null:
		return null
	return door.get_node_or_null("Slab") as Node3D


func _goods_in() -> GoodsZone:
	if _world == null:
		return null
	return _world.get_node_or_null("Zones/GoodsIn") as GoodsZone


func _me() -> Player:
	if _world == null:
		return null
	return _world.get_node_or_null("Players/%d" % Net.local_id()) as Player
