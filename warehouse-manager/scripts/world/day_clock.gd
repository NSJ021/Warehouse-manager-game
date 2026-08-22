class_name DayClock
extends Node

## The day loop's clock (GDD §5, ADR 25 (f)). Host-authoritative, replicated,
## and level-scoped — a node found by group exactly like [CarryAuthority] and
## [Rack], never an autoload. `docs/project-structure.md`'s autoload-avoidance
## ladder names this exact temptation ahead of time: the clock is per-run
## state reachable from the level, not global infrastructure in the shape
## [code]Net[/code] is, and an autoload would silently break the `--script`
## unit runner for any pure module that ever touched it.
##
## [b]Inert until told to start.[/b] A fresh [DayClock] sits in [constant
## Phase.IDLE] and does nothing at all — no signal fires, [member sync_elapsed]
## never advances — until [method begin_run] is called on the host. This is
## the single most important fact about this file: `test_room.tscn` carries a
## [DayClock] so a human playing the game gets a day, but `TestRoom` itself
## never calls [method begin_run] — only `main.gd` does, once a session is up.
## Both `test/integration/carry_session.gd` and `storage_session.gd` instance
## `test_room.tscn` directly, without going through `main.tscn`, so they get a
## room with a dead clock unless they ask for one — which neither does. If a
## future change ever makes those two scenarios fail in a way that looks like
## a door closing or a day rolling over mid-assertion, the fix is restoring
## this inertness, not adjusting the tests.
##
## [b]Phases[/b] (GDD §5's MORNING → SHIFT → CLOSE loop, split one step
## finer):
## - [constant Phase.IDLE] — no run in progress, and nothing here does
##   anything (see above).
## - [constant Phase.MORNING] — the door going up and the truck arriving.
##   02-06 fills in the truck dump; this file only owns the timing.
## - [constant Phase.SHIFT] — open hours. Most of the day happens here.
## - [constant Phase.AFTER_HOURS] — door down, tidy-up time, and
##   deliberately skippable: the host can call it a night early and go
##   straight to the midnight boundary (ADR 21's host-decides-unilaterally
##   precedent, unchanged).
## - [constant Phase.MIDNIGHT] — the ceremony boundary. A pause, not a
##   duration, and per ADR 25 (f) it is the day boundary and the v1 join
##   window, and it [i]will be[/i] the save point once saving is built —
##   Phase 5 (the run) owns that, and this phase builds no persistence of any
##   kind. 02-09 replaces the short auto-advance this file does today with a
##   real summary the host dismisses; say so again at [method
##   advance_to_next_day].
enum Phase { IDLE, MORNING, SHIFT, AFTER_HOURS, MIDNIGHT }

## RUN-02 bounds this 360–600 (a day runs in 6–10 minutes) — see
## `test/api/engine_assumptions.gd`'s invariants section, which pins the
## BOUND, not this value. ADR 25 (f) deliberately does not fix a number: NJ
## has not agreed one, and lease arithmetic (10 or 30 days × this, ADR 8) is
## the real constraint. 480 (8 minutes) is a starting guess, not a decision.
@export var day_length_seconds := 480.0
## The truck-dump ceremony's own window (02-06 fills the ceremony in; this
## file only owns the clock). At least 20s so a delivery has room to spread
## across it rather than reading as a single dump (`engine_assumptions.gd`
## pins this bound too).
@export var morning_seconds := 30.0
## ADR 25 (f): roughly two-thirds of the day is open trading (morning +
## shift), the rest after-hours tidy-up with the door shut to new business.
@export_range(0.4, 0.9, 0.01) var open_fraction := 0.667
## How long before the door starts closing the klaxon sounds and the HUD's
## text warning appears — ADR 25 (f): a warning that only exists in audio is
## never enough, so this same number drives [signal doors_closing]'s payload,
## which both the door's klaxon (`dock_door.gd`) and the HUD (`main.gd`) key
## off, rather than each guessing independently.
@export var klaxon_warning_seconds := 20.0
## How long [constant Phase.MIDNIGHT] lingers before automatically calling
## [method advance_to_next_day]. A placeholder ceremony's own length — 02-09
## replaces the auto-advance with a real summary the host dismisses, at which
## point this export stops being read at all.
@export var ceremony_seconds := 5.0

## Lets a hand-test or an integration scenario pin the day (ADR 25 (f) — the
## host generates the manifest; determinism is what makes a test repeatable,
## not what keeps two real peers agreeing — see [method _post_manifest]'s own
## doc comment for that distinction).
@export var run_seed := 0
## The morning delivery's three capacity axes (ADR 25 (f)). `@export` vars
## HERE, not on [DaySchedule] itself, even though the plan this file was
## built from asks for the reverse — confirmed, not assumed, with a
## throwaway probe script: `@export` cannot be applied to a static variable,
## and [DaySchedule] is deliberately all-static. See that file's own class
## doc for the full reasoning; the short version is that this is also the
## one place in the scene a future Phase 4 event (a second truck) could reach
## in and widen a day's budget at runtime, which a `const` would foreclose
## for nothing. Untuned starting guesses, exactly [member day_length_seconds]'s
## own standing — settled in play at the 02-11 gate, not decided here.
@export var body_cap_per_player := DaySchedule.DEFAULT_BODY_CAP_PER_PLAYER
@export var cell_equivalent_cap_per_player := DaySchedule.DEFAULT_CELL_EQUIVALENT_CAP_PER_PLAYER
@export var large_cap_per_player := DaySchedule.DEFAULT_LARGE_CAP_PER_PLAYER
@export var medium_cap_per_player := DaySchedule.DEFAULT_MEDIUM_CAP_PER_PLAYER

## Replicated state, written only by the host. A [MultiplayerSynchronizer]
## rather than a targeted RPC — see the class doc's own note on why this is
## the opposite shape from a rack's occupancy broadcast: a clock is a
## continuously broadcast scalar, so the very next tick corrects any peer
## that missed the last one, including a late joiner, at no extra code. No
## late-joiner RPC exists here and none should be added.
var sync_day := 1
var sync_phase: Phase = Phase.IDLE
var sync_elapsed := 0.0

## Client-only. What [method _watch_client] last saw [member sync_phase] be,
## so a change is detected exactly once rather than every frame it stays
## changed.
var _last_known_phase: Phase = Phase.IDLE
## Whether [signal doors_closing] has already fired for the current SHIFT —
## reset in [method _enter_phase] (host) and in [method _watch_client]
## (client), one flag per peer's own instance.
var _warned_this_phase := false

## This peer's own copy of today's manifest (ADR 25 (e)/(f)). Populated only
## by [method _manifest_posted], never built independently on a client — the
## host decides, no vote (ADR 21), and two independently-seeded generators
## would be exactly the failure determinism alone cannot catch, since it
## only proves a bug reproduces, not that two peers agree. Null until the
## first MORNING this run reaches, or until a late joiner's own catch-up
## (see [method _on_player_ready_for_spawn]) lands.
var today: DayManifest = null

## Written only by 02-10, at door-down, for whatever a missed collection
## owes tomorrow (ADR 25 (e): "redelivery's cost is a locked row on
## tomorrow's manifest"). This file only READS it, in [method _post_manifest].
## Left inert here on purpose — 02-10 adds a behaviour to an existing schema
## rather than needing to invent one.
var _carried_locked_rows: Array = []

## Cached the moment [member today] is set (see [method census]'s own doc
## comment for why a per-frame re-scan would buy nothing this phase) —
## correct for the WHOLE day, not just the moment it was computed, because
## nothing in Phase 2 removes a delivered crate mid-day (Goods OUT only
## detects; GoodsZone's own class doc says nothing economic happens to a
## crate there until Phase 4).
var _due_today_count := 0

## Past tense, per house style. What 02-06 and 02-09 hook, so neither needs
## to poll this file's state.
signal phase_changed(phase: Phase, day: int)
## [constant Phase.MORNING] entered — 02-06's truck dump listens here.
signal day_started(day: int)
## The klaxon window opened, [param seconds_left] until the door shuts.
signal doors_closing(seconds_left: float)
## [constant Phase.SHIFT] ended — 02-09's collection check listens here.
signal doors_closed(day: int)
## The ceremony boundary reached, for [param day] — the day that just ended.
signal midnight_reached(day: int)

## Set once here rather than left to whatever [member Node.multiplayer]'s
## implicit authority would be, the same reason [method Crate._enter_tree]
## does — this is what makes the synchronizer's root authority the host.
func _enter_tree() -> void:
	set_multiplayer_authority(1)


func _ready() -> void:
	# Found by group, not by path or an exported NodePath — 02-07's truck dump
	# and 02-09's collection check both need to reach this without knowing
	# where in a level's tree it lives, the same reason CarryAuthority and
	# Rack are both group-found rather than wired by hand.
	add_to_group("day_clock")
	if Net.is_host():
		Net.player_ready_for_spawn.connect(_on_player_ready_for_spawn)


## Runs on every peer. The host branch is the only one that ever mutates
## [member sync_elapsed] or [member sync_day] — the actual simulation. The
## client branch derives the same signals from the replicated [member
## sync_phase] alone, the same "derive it locally from replicated state"
## trick [method Crate._process] uses for [member Crate.sync_settled] — a
## client needs [signal doors_closed] to fire locally so its own door
## animates and its own HUD updates without a round trip.
func _process(delta: float) -> void:
	if Net.is_host():
		_advance_host(delta)
	else:
		_watch_client()


## Host-only. [param starting_day] lets a level or a save (Phase 5) choose
## where the count begins; Phase 2 always calls this with the default.
## Refuses silently if a run is already in progress — the idiom this
## codebase uses everywhere a request could be malformed or late.
func begin_run(starting_day := 1) -> void:
	if not Net.is_host():
		return
	if sync_phase != Phase.IDLE:
		return
	sync_day = starting_day
	_enter_phase(Phase.MORNING)


func current_day() -> int:
	return sync_day


func phase() -> Phase:
	return sync_phase


## This peer's own copy of today's manifest — see [member today]'s own doc
## comment. Null before the first MORNING.
func manifest() -> DayManifest:
	return today


## How many crates today's manifest called for, in total — the HUD's `in:`
## line (`main.gd`).
func delivered_today_count() -> int:
	if today == null:
		return 0
	return today.total_crates()


## How many crates currently in the building are due out today or earlier —
## the HUD's `out:` line. Cached once per day; see [member _due_today_count]'s
## own doc comment for why that is both cheap and correct here.
func due_today_count() -> int:
	return _due_today_count


## Every cargo record currently in the building, as wire-safe Dictionaries
## ([method CargoRecord.to_dict]'s own shape) — loose crates, walked through
## the level's own crate container, and racked records, walked through every
## rack's own [method Rack.occupancy_snapshot]. 02-10 needs this for the
## door-down check; this file needs it for [member _due_today_count].
##
## Resolved via the existing "crate_source" group, duck-typed exactly the
## way [code]CarryAuthority._crate_source()[/code] already is — this class is
## not level-specific, and must not name [TestRoom] or any other level
## script directly.
##
## [b]A zone's own contents are not summed a second time here.[/b] Goods
## IN/OUT only ever observe loose crates that the crate-container walk below
## already visits — [GoodsZone]'s own class doc: "a zone cannot see racked
## stock," and it mints nothing of its own — so adding a zone's [method
## GoodsZone.contents] on top would double-count whatever it currently holds.
##
## Callable on any peer, not gated to the host, because it only reads state
## every peer already has replicated (loose crates via [MultiplayerSpawner],
## racked records via the same broadcast a late joiner's own rack snapshot
## uses) — the same "derive it locally, don't ask the host" shape
## [GoodsZone] itself already relies on. 02-10's own use of this, to decide
## whether the door may close, is what actually needs to run host-side; that
## is a property of WHERE it is called from, not of this function.
func census() -> Array:
	var records: Array = []

	var source := get_tree().get_first_node_in_group("crate_source")
	if source != null and source.has_method("crate_container"):
		var container: Node = source.crate_container()
		if container != null:
			for child in container.get_children():
				var crate := child as Crate
				if crate != null and crate.record != null:
					records.append(crate.record.to_dict())

	for node in get_tree().get_nodes_in_group("racks"):
		var rack := node as Rack
		if rack == null:
			continue
		for cell in rack.occupancy_snapshot():
			for item in (cell as Dictionary).get("items", []):
				records.append((item as Dictionary).duplicate(true))

	return records


func seconds_left_in_phase() -> float:
	return maxf(0.0, _phase_duration(sync_phase) - sync_elapsed)


## MORNING or SHIFT — the two phases the door is up for.
func is_open() -> bool:
	return sync_phase == Phase.MORNING or sync_phase == Phase.SHIFT


## For the HUD. Not [method Phase] itself stringified — GDScript's default
## enum-to-string is the constant's own name with underscores, and
## "AFTER_HOURS" reads worse on a HUD than "AFTER-HOURS" does.
func phase_name() -> String:
	match sync_phase:
		Phase.IDLE:
			return "IDLE"
		Phase.MORNING:
			return "MORNING"
		Phase.SHIFT:
			return "SHIFT"
		Phase.AFTER_HOURS:
			return "AFTER-HOURS"
		Phase.MIDNIGHT:
			return "MIDNIGHT"
		_:
			return "?"


## Host-gated: ADR 21's precedent is the host decides, no vote, so a
## non-host caller is ignored outright rather than tallied as one vote among
## several. Only valid during [constant Phase.AFTER_HOURS] — the door is
## already shut to new business, so nothing about tonight's takings changes
## by ending the tidy-up early. Printed rather than push_warning'd, matching
## every other [code][carry][/code]-style line in this codebase: a player
## working out what just happened should find it in the log.
@rpc("any_peer", "call_local", "reliable")
func request_call_it_a_night() -> void:
	if not Net.is_host():
		return
	if sync_phase != Phase.AFTER_HOURS:
		return
	print("[day] peer %d called it a night early on day %d" % [_sender_id(), sync_day])
	_enter_phase(Phase.MIDNIGHT)


## Host-only. [constant Phase.MIDNIGHT] → [constant Phase.MORNING], with
## [member sync_day] incremented. In Phase 2 this file calls itself, once
## [member ceremony_seconds] has passed in [constant Phase.MIDNIGHT] — 02-09
## replaces that automatic call with a real summary the host dismisses by
## hand, at which point [member ceremony_seconds] stops being read. Anything
## that wants to advance the day early (a save load, a scripted test) can
## still call this directly; it does not require having reached MIDNIGHT
## first, matching [method begin_run]'s own "no gate beyond host + phase"
## shape.
func advance_to_next_day() -> void:
	if not Net.is_host():
		return
	sync_day += 1
	_enter_phase(Phase.MORNING)


func _advance_host(delta: float) -> void:
	if sync_phase == Phase.IDLE:
		return
	sync_elapsed += delta
	match sync_phase:
		Phase.MORNING:
			if sync_elapsed >= morning_seconds:
				_enter_phase(Phase.SHIFT)
		Phase.SHIFT:
			_maybe_emit_klaxon_warning()
			if sync_elapsed >= _shift_seconds():
				_enter_phase(Phase.AFTER_HOURS)
		Phase.AFTER_HOURS:
			if sync_elapsed >= _after_hours_seconds():
				_enter_phase(Phase.MIDNIGHT)
		Phase.MIDNIGHT:
			if sync_elapsed >= ceremony_seconds:
				advance_to_next_day()


## Client-only. Detects a phase change purely from the replicated field and
## emits exactly what the host emitted at the moment it made that change —
## never re-derives new_phase itself, since [member sync_phase] IS the
## decision, already made. [signal doors_closing] is not a phase transition
## (it fires partway through SHIFT), so it is checked every frame here too,
## against the client's own [member _warned_this_phase] flag rather than the
## host's — two flags, one per peer's own instance, exactly as they should
## be: this is presentation state, not something that needs to agree byte
## for byte the instant it changes.
func _watch_client() -> void:
	if sync_phase != _last_known_phase:
		_last_known_phase = sync_phase
		_warned_this_phase = false
		# Same wording as the host's own [method _enter_phase] print — a
		# client's log should read the same story the host's does, proof this
		# peer agrees rather than merely a claim that it should.
		print("[day] day %d -> %s" % [sync_day, phase_name()])
		_emit_phase_entry_signal(sync_phase)
		phase_changed.emit(sync_phase, sync_day)
	_maybe_emit_klaxon_warning()


## Shared by both [method _advance_host] (via [method _enter_phase]) and
## [method _watch_client] — the one place that decides which signal a given
## phase's entry means, so the host's authoritative transition and a
## client's derived one can never name a different signal for the same
## change.
func _emit_phase_entry_signal(entered: Phase) -> void:
	match entered:
		Phase.MORNING:
			day_started.emit(sync_day)
		Phase.AFTER_HOURS:
			doors_closed.emit(sync_day)
		Phase.MIDNIGHT:
			midnight_reached.emit(sync_day)


## Host-only. The one place [member sync_phase] is actually written —
## [member sync_elapsed] always resets with it, so a phase's own elapsed time
## never leaks into the next one.
func _enter_phase(new_phase: Phase) -> void:
	sync_phase = new_phase
	sync_elapsed = 0.0
	_warned_this_phase = false
	# Printed rather than push_warning'd, matching every other [code][carry][/code]-
	# style line in this codebase: a player working out what day it is should
	# find the answer in the log, not just on a HUD they might not be looking at.
	print("[day] day %d -> %s" % [sync_day, phase_name()])
	if new_phase == Phase.MORNING:
		_post_manifest()
	_emit_phase_entry_signal(new_phase)
	phase_changed.emit(new_phase, sync_day)


## Host-only (only ever called from [method _enter_phase], which only the
## host's own [method _advance_host] / [method begin_run] / [method
## advance_to_next_day] reach). Builds the day's manifest and broadcasts it —
## clients never generate their own; ADR 21's "the host decides, no vote"
## precedent, applied to the day rather than the checkout split. `call_local`
## means this peer's own [member today] is set by the exact same code path
## every other peer's is — the same shape [code]Net._sync_roster[/code] and
## [code]CarryAuthority._cell_filled[/code] both already use, so there is no
## separate "the host's own copy" special case to keep in sync.
##
## Determinism ([DaySchedule]'s own [param seed_value]/[param day] seeding)
## is NOT what keeps two real peers agreeing here — it only makes a test
## repeatable and a bug reproducible. What keeps two peers agreeing is this
## broadcast: the host generates exactly once, and every peer's [member
## today] is a copy of that one result, never a second independent roll.
func _post_manifest() -> void:
	var crew_size := Net.players.size()
	var built := DaySchedule.manifest_for(
		sync_day, _carried_locked_rows, run_seed, crew_size,
		body_cap_per_player, cell_equivalent_cap_per_player,
		large_cap_per_player, medium_cap_per_player,
	)
	_manifest_posted.rpc(built.to_dict())


## Broadcast only — see [method _post_manifest]'s own doc comment. Also sent
## as a targeted late-joiner catch-up by [method _on_player_ready_for_spawn].
@rpc("authority", "call_local", "reliable")
func _manifest_posted(data: Dictionary) -> void:
	today = DayManifest.from_dict(data)
	_due_today_count = DayManifest.due_today(census(), sync_day).size()


## A late joiner needs today's manifest too. [member sync_day]/[member
## sync_phase]/[member sync_elapsed] cover themselves via the continuously
## broadcast [MultiplayerSynchronizer] — the very next tick corrects a peer
## that missed the last one, including a late joiner, at no extra code (see
## this file's own class doc). A manifest cannot use that trick: it is event
## state decided once, not a scalar recomputed every tick, so a peer that
## was not there for [method _post_manifest]'s own broadcast needs an
## explicit catch-up — the same reason [code]CarryAuthority._on_player_ready_for_spawn[/code]
## sends a late joiner its own rack snapshot instead of trusting the
## synchronizer to eventually cover it.
func _on_player_ready_for_spawn(peer_id: int, _player_name: String) -> void:
	if peer_id == 1 or today == null:
		return
	_manifest_posted.rpc_id(peer_id, today.to_dict())


## Fires [signal doors_closing] once per SHIFT, the moment the countdown
## crosses [member klaxon_warning_seconds] — guarded by [member
## _warned_this_phase] rather than an exact equality check, since neither
## delta-time accumulation (host) nor a 5 Hz replication tick (client) will
## ever land on the threshold exactly.
func _maybe_emit_klaxon_warning() -> void:
	if sync_phase != Phase.SHIFT or _warned_this_phase:
		return
	var left := seconds_left_in_phase()
	if left <= klaxon_warning_seconds:
		_warned_this_phase = true
		doors_closing.emit(left)


## Derived from [member day_length_seconds], [member morning_seconds] and
## [member open_fraction] rather than exported separately, so the three
## numbers can never contradict each other (the same reasoning
## [code]CarryAuthority.PLACE_REACH[/code]'s own doc comment documents its
## derivation for). Open hours (morning + shift) are day_length_seconds ×
## open_fraction; shift is whatever of that window is left once the
## morning ceremony's own slice is subtracted.
func _shift_seconds() -> float:
	return maxf(0.0, day_length_seconds * open_fraction - morning_seconds)


## Everything the day has left once open hours are accounted for:
## day_length_seconds × (1 − open_fraction).
func _after_hours_seconds() -> float:
	return maxf(0.0, day_length_seconds * (1.0 - open_fraction))


func _phase_duration(p: Phase) -> float:
	match p:
		Phase.MORNING:
			return morning_seconds
		Phase.SHIFT:
			return _shift_seconds()
		Phase.AFTER_HOURS:
			return _after_hours_seconds()
		Phase.MIDNIGHT:
			return ceremony_seconds
		_:
			return 0.0


func _sender_id() -> int:
	var id := multiplayer.get_remote_sender_id()
	# 0 means the host called this on itself rather than over the wire —
	# the same convention CarryAuthority._sender_id() follows.
	return 1 if id == 0 else id
