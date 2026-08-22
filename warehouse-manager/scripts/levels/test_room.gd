class_name TestRoom
extends Node3D

## Phase 0 proving ground: an empty room and a row of crates.
##
## Owns all spawning, players and cargo alike. The host decides what exists;
## [MultiplayerSpawner] replicates that decision to everyone. Clients never spawn
## anything, including themselves — they announce they are ready and wait.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

## Keyed by [code]CargoCatalogue.Size[/code] — [method _spawn_crate] picks the
## scene from whichever size the record on the wire actually carries. All
## three inherit from crate.tscn (02-04) and share its dozen exported tuning
## values, so a Medium or Large never drifts from a Small for a reason nobody
## can find.
const CRATE_SCENES := {
	CargoCatalogue.Size.SMALL:  preload("res://scenes/goods/crate.tscn"),
	CargoCatalogue.Size.MEDIUM: preload("res://scenes/goods/crate_medium.tscn"),
	CargoCatalogue.Size.LARGE:  preload("res://scenes/goods/crate_large.tscn"),
}

## A handful of crates sit in a row near the spawn points, because that is what
## hand-testing wants — crates in a far corner are a walk away every single time.
##
## Below this, [method _crate_position] uses the named-row layout (two light
## rows plus the mixed heavy row, 02-04); at or above it, [member crate_count]
## has been raised for the physics-budget stress test and every index falls
## through to the floor-filling grid instead — see that method's own branch.
const CRATE_ROW_LIMIT := 17
const CRATE_ROW_ORIGIN := Vector3(-2.5, 0.6, -6.0)
const CRATE_ROW_SPACING := 1.0
## How many crates the first row holds before [method _crate_position] moves
## on to [constant CRATE_ROW2_ORIGIN]. Also what every integration scenario's
## own crate-name table assumes (crate_0..crate_5 sit in this row, referenced
## by name — see storage_session.gd and carry_session.gd's own allocation
## comments) — do not change this without checking both.
const CRATE_ROW_SIZE := 6
## The gate playtest protocol needs 9+ crates on hand (a full cell of 8
## Smalls plus one still in hand, 2026-08-21) — raised to 12, a second row
## rather than one row of 12. Extending the first row out along x instead
## would have run it straight through things the integration suite depends
## on: rack_wall's own approach corridor (its aimable cells sit at
## x=7.0/8.0, and storage_session.gd stands a player at their z+2.0=-6.5 to
## reach them) and the same file's drag-avoidance detour, which sweeps
## z=-3.0 clear across the room's x range.
##
## z=-9.0, not simply "the next row back" at -7.5: carry_session.gd's own
## CLIENT_STAND_OFFSET_Z (-1.2) stands a player at z=-7.2 to grab a row-1
## crate from the north side, and that capsule's own 0.4 m radius reaches
## z=-7.6 — a row at -7.5 would have sat the new crates' own half-extent
## (0.25) directly inside that stand point. -9.0 clears it by over a metre
## (row-2 crates span z=[-9.25,-8.75]) and still leaves 0.75 m to the north
## wall's inner face (z=-10.0). Same x=-2.5..2.5 as the first row, which is
## nowhere near either rack (x=6.5) or either zone (x=-7).
const CRATE_ROW2_ORIGIN := Vector3(-2.5, 0.6, -9.0)

## 02-04: a third row, mixed for size and weight — the deception in one row,
## a heavy Small you cannot lift, a light Medium you can, a heavy Medium you
## cannot, and two Larges (ADR 25 (c)). Neither crate_0..crate_11 (the named
## rows above, claimed by both integration scenarios) nor their positions are
## touched — this is pure addition.
##
## Checked against every corridor and fixture before picking these numbers,
## not assumed: GoodsOut sits at world (-7,0,7), a 3x3 volume spanning
## x=[-8.5,-5.5] z=[5.5,8.5] — HEAVY_ROW_ORIGIN's x=-4.0 clears its x-range by
## 1.5 m with the row's own leftmost edge (a Small's half-extent, x=-4.25)
## adding a further 1.25 m of margin, so nothing in this row can ever spawn
## inside that zone regardless of z. PillarB (4.5,4.5, 1x1 footprint) sits
## 2 m short of this row's z=7.0 in z alone. Both racks (x=6.5, z=-10 and
## z=1) and storage_session.gd's own drag-avoidance detour (z=-3.0, sweeping
## the room's x range) and rack_island's own approach corridor (z~3.5-5.35)
## are all several metres from z=7.0. The row's own rightmost edge (a Large's
## own half-extent, x=7.4 at index 4) stays short of rack_island's
## ImpactSensor x-span (>=6.4) because that sensor's z-span (1.55-2.45) does
## not reach z=7.0 at all — the two footprints are separated in z, not x.
const HEAVY_ROW_ORIGIN := Vector3(-4.0, 0.75, 7.0)
## > 2.0 m, because a Large is 2 m along its own local X (ADR 25 (d)) — with
## this spacing, adjacent crates in the row can never touch even when both
## are Larges oriented the same way.
const HEAVY_ROW_SPACING := 2.6

## (category, size) pairs, in HEAVY_ROW_ORIGIN's own spawn order. masonry's
## Small (34 kg) and Medium (68 kg) are both over Crate.SOLO_CARRY_MASS_LIMIT
## (30) — the same category, so a player who has learned "masonry is heavy"
## reads both correctly at a glance. textiles' Medium (17 kg) is not — the
## same SIZE as masonry's Medium, the opposite answer, which is ADR 25 (c)'s
## whole point: weight decides, not size. The two Larges are different
## categories (machine_parts 108 kg, the heaviest thing this table mints;
## white_goods 96 kg, a category with no Small at all) so the row does not
## read as "the last two are the same thing, twice."
const HEAVY_ROW_ENTRIES := [
	[&"masonry", CargoCatalogue.Size.SMALL],
	[&"textiles", CargoCatalogue.Size.MEDIUM],
	[&"masonry", CargoCatalogue.Size.MEDIUM],
	[&"machine_parts", CargoCatalogue.Size.LARGE],
	[&"white_goods", CargoCatalogue.Size.LARGE],
]

## One entry per crate_0..crate_11, every one a Small comfortably under
## Crate.SOLO_CARRY_MASS_LIMIT (see cargo_catalogue.gd's own table comment for
## the numbers) — these twelve are claimed by name across both integration
## scenarios (grabbed, carried, dragged, racked), so every one must stay
## solo-liftable or those scenarios' carry/drag assertions break.
##
## crate_0 and crate_1 share a category DELIBERATELY, not by oversight:
## storage_session.gd racks both into the same cell through the real place
## path to prove a cell holds more than one item (ADR 18) — which needs the
## same category on both sides, or Rack.can_accept's atomicity check (working
## exactly as intended) refuses the second one as a mismatch. Every other
## entry is free to vary, and does.
const NAMED_ROW_CATEGORIES: Array[StringName] = [
	&"textiles", &"textiles", &"novelty", &"dodgy", &"glassware", &"electronics",
	&"ceramics", &"textiles", &"novelty", &"dodgy", &"glassware", &"electronics",
]

## Placeholders, not manifest data — this room's starting batch predates the
## day's contract entirely (that is 02-06's truck dump). Enough for every
## CargoRecord to be a real, complete record; no meaning is attached to these
## particular numbers yet.
const STARTING_STORE_UNTIL_DAY := 1
const STARTING_OWNER := &"test_client"
const STARTING_CONTRACT_DAYS := 1

## [method spawn_crate_at]'s pre-record compatibility shim (01-04/01-07) mints
## from this category when handed no record data at all. textiles' Small is
## the lightest entry in the whole catalogue, so a retrieved or shed crate
## stays trivially solo-liftable exactly as it always has been.
const DEFAULT_RETRIEVAL_CATEGORY := &"textiles"

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

## --- 02-07: the truck dump (ADR 25 (f)) ---
##
## Belongs here, not in `day_clock.gd`, because [TestRoom] "owns all
## spawning, players and cargo alike" (this file's own class doc) — the
## clock only owns the timing, and fires [signal DayClock.day_started] so a
## level can turn that into cargo however it likes.

## Drop height above the floor, so a delivered crate visibly tumbles apart
## from its neighbours rather than spawning interpenetrating.
const DUMP_DROP_HEIGHT := 1.2
## Kept clear of GoodsIn's own walls, so nothing lands already clipping the
## zone's boundary.
const DUMP_GRID_MARGIN := 0.4
## Wider than a Small needs (0.5 m) so a Medium (1.0 m) mostly clears its
## neighbour too — a Large (2.0 m along one axis) will still overlap at
## this spacing inside GoodsIn's own modest 3x3 footprint, tolerated rather
## than solved: nothing here asserts non-overlap, physics resolves a spawn
## overlap the same way the stress-test grid's own tighter spacing already
## does, and a truck yard genuinely is a tight place. Worth a look at the
## 02-11 gate with a Large actually in a delivery.
const DUMP_GRID_SPACING := 0.8
const DUMP_LAYER_HEIGHT := 0.6
## Kept clear of a standing player's own capsule (its query is horizontal
## only, so a crate landing well above someone's head is not itself
## flagged — [method Crate._update_settle_state] already refuses to settle
## while a player overlaps its push sensor, which prevents the trap; this
## constant is what stops the crate landing on someone's HEAD in the first
## place). Not a hard guarantee — a player who walks under a falling crate
## mid-drop is still possible — see this section's own doc comment on the
## gate check this is meant to invite.
const DUMP_PLAYER_AVOID_RADIUS := 0.9
const DUMP_PLAYER_AVOID_OFFSET := Vector3(0.5, 0.0, 0.0)
## Bounded retries before giving up on dodging a player — never spins
## forever chasing a moving target.
const DUMP_PLAYER_AVOID_ATTEMPTS := 4

## Host-only. Individual crate record dictionaries still owed this morning,
## expanded from the manifest's own rows by [method _on_day_started] — a
## queue rather than a loop, because the whole point is spreading these
## across [member DayClock.morning_seconds] rather than minting them all in
## one frame.
var _dump_queue: Array = []
## Wall-clock milliseconds between two dump spawns — see [method _process]'s
## own doc comment for why this is paced by [code]Time.get_ticks_msec()[/code]
## rather than a frame count.
var _dump_interval_ms := 0
var _dump_next_at_ms := 0
## How many crates this morning's dump has placed so far — drives
## [method _next_dump_position]'s own grid, reset per day.
var _dump_spawn_index := 0

## Starting cargo. Exported so the physics budget stress test can turn one knob
## instead of a second mechanism being invented for it. The first twelve sit in
## two rows of six (see CRATE_ROW_SIZE / CRATE_ROW2_ORIGIN), which is what
## hand-testing — now including the gate's full-cell-plus-one protocol —
## wants; the last five are the mixed heavy row (02-04, HEAVY_ROW_ORIGIN).
@export var crate_count := 17

## Host-only. The next id [method spawn_crate_at] mints — one counter shared
## with the starting batch below, so ids never collide and are never reused.
## A recycled id would be indistinguishable from a stale reference on a
## client once the original crate despawned (a racked crate freed and later
## re-minted must never come back wearing the same name as something a peer
## still remembers).
var _next_crate_id := 0

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

	# CarryAuthority finds a crate minter by group rather than by name, so it
	# never has to name TestRoom or any other level script (it is not
	# level-specific — see its class doc). Every level that wants retrieval
	# to work joins this group; a level that does not simply never grants one.
	add_to_group("crate_source")

	if Net.is_host():
		Net.player_ready_for_spawn.connect(_on_player_ready_for_spawn)
		Net.player_left.connect(_on_player_left)
		_spawn_crates()
		# Resolved once, here, rather than lazily on every use the way
		# DockDoor resolves DayClock — safe specifically because this script
		# sits on the SCENE ROOT, so every descendant (DayClock included) has
		# already had its own _ready() run by the time this line executes
		# (Godot's tree-ready order is bottom-up); DockDoor's own caution is
		# about a node that is itself a sibling-ish descendant, where sibling
		# ready order is not the guarantee this file gets for free.
		var clock := get_tree().get_first_node_in_group("day_clock") as DayClock
		if clock != null:
			clock.day_started.connect(_on_day_started)

	Net.announce_world_ready()


## Duck-typed entry point for anything that needs to walk every loose crate
## without knowing this is [TestRoom] specifically — [code]DayClock.census()[/code]
## reaches in via the existing "crate_source" group rather than a new one,
## the same "not level-specific" contract [code]CarryAuthority._crate_source()[/code]
## already follows for minting.
func crate_container() -> Node3D:
	return crates


## Runs on every peer with identical data, so every peer builds an identical node.
func _spawn_player(data: Variant) -> Node:
	var info := data as Dictionary
	var player := PLAYER_SCENE.instantiate() as Player
	player.setup(int(info["peer_id"]), str(info["name"]), info["spawn"] as Vector3)
	print("[world] spawned %s for peer %d at %v" % [info["name"], info["peer_id"], info["spawn"]])
	return player


## Runs on every peer with identical data, so every peer builds an identical
## node — [param data]["record"] is the wire-safe [method CargoRecord.to_dict]
## output, identical on every peer, so [method Crate.setup] reconstructs an
## identical record everywhere with no extra replication (02-04's whole point).
func _spawn_crate(data: Variant) -> Node:
	var info := data as Dictionary
	var record_data := info["record"] as Dictionary
	var scene: PackedScene = CRATE_SCENES[int(record_data["size"])]
	var crate := scene.instantiate() as Crate
	crate.setup(record_data, info["spawn"] as Vector3)
	if crate_count <= CRATE_LOG_LIMIT:
		print("[world] spawned crate %d at %v" % [record_data["id"], info["spawn"]])
	return crate


## Host-only, and deliberately before the ready handshake: the crates exist
## before anyone has a body to bump into them with.
func _spawn_crates() -> void:
	for i in crate_count:
		crate_spawner.spawn({"record": _mint_starting_record(i), "spawn": _crate_position(i)})
	if crate_count > CRATE_LOG_LIMIT:
		print("[world] spawned %d crates" % crate_count)


func _mint_crate_id() -> int:
	var minted := _next_crate_id
	_next_crate_id += 1
	return minted


## Builds this starting-batch index's [method CargoRecord.to_dict] output.
## Named rows (0..11, or every index once [member crate_count] exceeds
## [constant CRATE_ROW_LIMIT] and the layout falls through to the stress-test
## grid) get a light Small from [constant NAMED_ROW_CATEGORIES]; the mixed
## heavy row (12..16) gets [constant HEAVY_ROW_ENTRIES] — mirrors exactly the
## same branch [method _crate_position] uses, so a record's size always
## matches the layout its own position assumes.
func _mint_starting_record(index: int) -> Dictionary:
	var crate_id := _mint_crate_id()
	if crate_count <= CRATE_ROW_LIMIT and index >= CRATE_ROW_SIZE * 2:
		return _mint_heavy_row_record(index - CRATE_ROW_SIZE * 2, crate_id)
	return _mint_named_row_record(index, crate_id)


## crate_0..crate_11 (or, past [constant CRATE_ROW_LIMIT], every stress-test
## grid crate) — always a Small, cycling through [constant
## NAMED_ROW_CATEGORIES] so the row is not one repeated category.
func _mint_named_row_record(index: int, crate_id: int) -> Dictionary:
	var category: StringName = NAMED_ROW_CATEGORIES[index % NAMED_ROW_CATEGORIES.size()]
	var record := CargoCatalogue.mint(
		category, CargoCatalogue.variants(category)[0], CargoCatalogue.Size.SMALL,
		STARTING_STORE_UNTIL_DAY, STARTING_OWNER, STARTING_CONTRACT_DAYS, crate_id,
	)
	# Asserted here, not merely trusted from the catalogue table: those
	# numbers can change later for balance reasons this file will never see
	# coming, and every crate_0..crate_11 the integration suite claims by name
	# must stay solo-liftable or its carry/drag assertions break. Printed
	# rather than push_warning'd — the suite fails on any engine warning,
	# the same reason Crate._recover() prints instead (see its own comment).
	if record.mass > Crate.SOLO_CARRY_MASS_LIMIT:
		print("[world] ERROR: named-row category %s (mass %.1f) exceeds SOLO_CARRY_MASS_LIMIT (%.1f) — every crate_0..crate_11 must stay solo-liftable" % [
			category, record.mass, Crate.SOLO_CARRY_MASS_LIMIT,
		])
	return record.to_dict()


## crate_12..crate_16 — [constant HEAVY_ROW_ENTRIES]' own (category, size) pair.
func _mint_heavy_row_record(heavy_index: int, crate_id: int) -> Dictionary:
	var entry: Array = HEAVY_ROW_ENTRIES[heavy_index]
	var category: StringName = entry[0]
	var size: int = entry[1]
	var record := CargoCatalogue.mint(
		category, CargoCatalogue.variants(category)[0], size,
		STARTING_STORE_UNTIL_DAY, STARTING_OWNER, STARTING_CONTRACT_DAYS, crate_id,
	)
	return record.to_dict()


## Host-only. Mints a crate with an id no live crate holds and spawns it at
## [param spawn_position]. Retrieval (01-04) and shedding (01-07) both need to
## turn stored occupancy data back into a real crate, and both need an id
## guaranteed not to collide with one already in play.
##
## [param record_data] defaults to empty — a compatibility shim for those same
## 01-04/01-07 callers ([code]CarryAuthority.request_retrieve[/code],
## [code]CarryAuthority.shed_top_row[/code]), which 02-05 replaces with the
## rack's own stored record. Empty mints a fresh default Small through
## [CargoCatalogue] instead, so both callers keep behaving exactly as they did
## before this plan. A non-empty [param record_data] still gets a freshly
## minted id — a retrieval or a shed always spawns a NEW body (the placed one
## was freed outright, ADR 14), so the id has to be fresh even when every
## other field rides along from a real stored record.
func spawn_crate_at(spawn_position: Vector3, record_data := {}) -> Crate:
	if not Net.is_host():
		return null
	var data := record_data.duplicate()
	var crate_id := _mint_crate_id()
	if data.is_empty():
		data = CargoCatalogue.mint(
			DEFAULT_RETRIEVAL_CATEGORY, CargoCatalogue.variants(DEFAULT_RETRIEVAL_CATEGORY)[0],
			CargoCatalogue.Size.SMALL, STARTING_STORE_UNTIL_DAY, STARTING_OWNER,
			STARTING_CONTRACT_DAYS, crate_id,
		).to_dict()
	else:
		data["id"] = crate_id
	return crate_spawner.spawn({"record": data, "spawn": spawn_position}) as Crate


## Deterministic on purpose: the same index always lands in the same place, so a
## stress run is repeatable and two runs are comparable.
func _crate_position(index: int) -> Vector3:
	if crate_count <= CRATE_ROW_LIMIT:
		if index < CRATE_ROW_SIZE:
			return CRATE_ROW_ORIGIN + Vector3(float(index) * CRATE_ROW_SPACING, 0.0, 0.0)
		if index < CRATE_ROW_SIZE * 2:
			var row2_index := index - CRATE_ROW_SIZE
			return CRATE_ROW2_ORIGIN + Vector3(float(row2_index) * CRATE_ROW_SPACING, 0.0, 0.0)
		var heavy_index := index - CRATE_ROW_SIZE * 2
		return HEAVY_ROW_ORIGIN + Vector3(float(heavy_index) * HEAVY_ROW_SPACING, 0.0, 0.0)

	var per_layer := CRATE_GRID_COLUMNS * CRATE_GRID_ROWS
	var layer := index / per_layer
	var within := index % per_layer
	return CRATE_GRID_ORIGIN + Vector3(
		float(within % CRATE_GRID_COLUMNS) * CRATE_GRID_SPACING,
		float(layer) * CRATE_LAYER_HEIGHT,
		float(within / CRATE_GRID_COLUMNS) * CRATE_GRID_SPACING,
	)


## Host-only. Paced by wall-clock time
## ([code]Time.get_ticks_msec()[/code]), never a frame count — headless Godot
## runs uncapped, and a fixed frame count between spawns was measured to buy
## almost no real time in 01-04's own "let physics settle" pause, which
## silently dropped a held item. The same trap would silently turn "spread
## across the morning" into "spawn everything on frame one."
func _process(_delta: float) -> void:
	if not Net.is_host():
		return
	if _dump_queue.is_empty():
		return
	if Time.get_ticks_msec() < _dump_next_at_ms:
		return
	var record_data: Dictionary = _dump_queue.pop_front()
	_spawn_delivery_crate(record_data)
	_dump_next_at_ms = Time.get_ticks_msec() + _dump_interval_ms


## [signal DayClock.day_started] — the one trigger for a dump (ADR 25 (f)).
## Expands the manifest's rows into individual crate records and queues them
## for [method _process] to spread across [member DayClock.morning_seconds].
## Does not poll the phase, and does not re-derive the manifest itself —
## [member DayClock.today] is the single source of truth, already broadcast
## by the time this fires locally on this peer (see that file's own
## [method DayClock._post_manifest] doc comment for why local-before-broadcast
## ordering never matters here: this handler only ever runs host-side, and
## the host set its own [member DayClock.today] before this signal could
## possibly fire).
func _on_day_started(_day: int) -> void:
	if not Net.is_host():
		return
	var clock := get_tree().get_first_node_in_group("day_clock") as DayClock
	if clock == null:
		return
	var manifest := clock.manifest()
	if manifest == null:
		return

	var total := manifest.total_crates()
	_dump_spawn_index = 0
	if total <= 0:
		_dump_queue = []
		return

	_dump_queue = _expand_rows_to_record_dicts(manifest.all_rows(), manifest.day)
	_dump_interval_ms = maxi(1, int(1000.0 * clock.morning_seconds / float(total)))
	_dump_next_at_ms = Time.get_ticks_msec()
	print("[world] today's delivery: %d crates over ~%.0fs" % [total, clock.morning_seconds])


## One [method CargoCatalogue.mint]-built record dictionary per crate a row's
## own `count` calls for — the same "one place a record is assembled" rule
## [code]CargoCatalogue.mint[/code]'s own doc comment states, applied here to
## expanding a BATCH into individuals rather than building one by hand.
func _expand_rows_to_record_dicts(rows: Array, day: int) -> Array:
	var result: Array = []
	for row in rows:
		var r := row as Dictionary
		var category: StringName = StringName(r.get("category", &""))
		var size: int = int(r.get("size", CargoCatalogue.Size.SMALL))
		# Guard against a row naming a size the catalogue doesn't actually
		# offer for that category (white_goods has no Small) — skip and
		# print() rather than silently under-deliver the day. Never
		# push_warning(): the suite fails on any engine warning, the same
		# reason Crate._recover() prints instead of warning.
		if not (size in CargoCatalogue.available_sizes(category)):
			print("[world] ERROR: manifest row names a size the catalogue doesn't offer for %s (size %d) — skipping" % [category, size])
			continue
		var variant: StringName = StringName(r.get("variant", &""))
		var count: int = int(r.get("count", 0))
		var store_until_day: int = int(r.get("store_until_day", day + 1))
		var owner: StringName = StringName(r.get("owner", &""))
		var contract_days := maxi(store_until_day - day, 1)
		for _i in count:
			var crate_id := _mint_crate_id()
			result.append(CargoCatalogue.mint(
				category, variant, size, store_until_day, owner, contract_days, crate_id,
			).to_dict())
	return result


func _spawn_delivery_crate(record_data: Dictionary) -> void:
	var pos := _next_dump_position()
	crate_spawner.spawn({"record": record_data, "spawn": pos})


## The GoodsIn zone specifically — "goods_zone" holds both kinds (01-05), so
## this filters rather than assuming there is only ever one.
func _goods_in_zone() -> GoodsZone:
	for node in get_tree().get_nodes_in_group("goods_zone"):
		var zone := node as GoodsZone
		if zone != null and zone.kind == GoodsZone.Kind.IN:
			return zone
	return null


## Derived from GoodsIn's own collision shape at runtime, never hard-coded
## coordinates — this project has moved a fixture three times already
## because a plan guessed a position instead (01-05's own history). Moving
## the zone moves the dock for free.
func _dump_area() -> Dictionary:
	var zone := _goods_in_zone()
	if zone == null:
		return {}
	var volume := zone.get_node_or_null("Volume") as CollisionShape3D
	if volume == null:
		return {}
	var shape := volume.shape as BoxShape3D
	if shape == null:
		return {}
	var centre: Vector3 = volume.global_transform.origin
	var half: Vector3 = shape.size * 0.5 - Vector3(DUMP_GRID_MARGIN, 0.0, DUMP_GRID_MARGIN)
	return {"centre": centre, "half": half}


## The next crate's landing spot: a grid inside GoodsIn's own footprint,
## wrapping into a layer above once the floor of that footprint is full
## (the same "fill flat, then stack" shape [method _crate_position]'s own
## stress-test grid already uses), then nudged clear of any standing player
## (see [constant DUMP_PLAYER_AVOID_RADIUS]'s own doc comment).
func _next_dump_position() -> Vector3:
	var area := _dump_area()
	if area.is_empty():
		# No GoodsIn zone in this level — should never happen in practice,
		# but a missing dock is not a reason to silently spawn nothing.
		_dump_spawn_index += 1
		return CRATE_ROW_ORIGIN + Vector3(0.0, 1.0, 0.0)

	var centre: Vector3 = area["centre"]
	var half: Vector3 = area["half"]
	var columns := maxi(1, int(floor((half.x * 2.0) / DUMP_GRID_SPACING)))
	var rows := maxi(1, int(floor((half.z * 2.0) / DUMP_GRID_SPACING)))
	var per_layer := columns * rows

	var index := _dump_spawn_index
	_dump_spawn_index += 1

	@warning_ignore("integer_division")
	var layer := index / per_layer
	var within := index % per_layer
	var col := within % columns
	@warning_ignore("integer_division")
	var row := within / columns

	var origin := centre - Vector3(half.x, 0.0, half.z) + Vector3(DUMP_GRID_SPACING * 0.5, 0.0, DUMP_GRID_SPACING * 0.5)
	var pos := origin + Vector3(
		float(col) * DUMP_GRID_SPACING,
		DUMP_DROP_HEIGHT + float(layer) * DUMP_LAYER_HEIGHT,
		float(row) * DUMP_GRID_SPACING,
	)
	return _avoid_player_overlap(pos)


## Nudges a drop point sideways, a bounded number of times, if it is
## currently over a standing player's own capsule — checked in the
## horizontal plane only, since the drop height is well above head level
## regardless. Does not guarantee a player can never walk under a falling
## crate mid-drop; see this file's own "the truck dump" section doc comment
## for the gate check this invites instead.
func _avoid_player_overlap(pos: Vector3) -> Vector3:
	var adjusted := pos
	for _attempt in DUMP_PLAYER_AVOID_ATTEMPTS:
		var blocked := false
		for child in players.get_children():
			var body := child as Node3D
			if body == null:
				continue
			var flat_a := Vector2(adjusted.x, adjusted.z)
			var flat_b := Vector2(body.global_position.x, body.global_position.z)
			if flat_a.distance_to(flat_b) < DUMP_PLAYER_AVOID_RADIUS:
				blocked = true
				break
		if not blocked:
			return adjusted
		adjusted += DUMP_PLAYER_AVOID_OFFSET
	return adjusted


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
