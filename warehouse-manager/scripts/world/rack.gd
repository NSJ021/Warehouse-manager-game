class_name Rack
extends Node3D

## A rack: 12 cells of storage (ADR 18). Geometry is [StorageGrid]'s job; this
## file owns *state* — what each cell currently holds — and derives its
## visuals from that state independently on every peer, so the meshes are a
## consequence of occupancy rather than a second copy of it that can disagree.
##
## Racked cargo must cost nothing (ADR 14): a rack holding 96 Smalls as rigid
## bodies would be two-thirds of the whole physics budget standing still. A
## racked item is therefore a bare mesh with no body, no collision and no
## synchronizer — see [code]scenes/goods/racked_item.tscn[/code].
##
## Registered by group ("racks"), not by exported path, so dropping a rack
## into a level needs no scene wiring. [member Node.name] is protocol
## (ADR 12) — 01-04 resolves a specific rack over the wire by group and name,
## so renaming one is a netcode change, not a tidy-up.
##
## All cell arithmetic belongs to [StorageGrid]. If a line here multiplies by
## a cell dimension, it is in the wrong file — move it there, where a unit
## test can see it. That now includes the occupancy DECISION rules too, not
## only the arithmetic: [method can_accept] and [method apply_record_update]
## delegate to [method StorageGrid.cell_can_accept] and
## [method StorageGrid.cell_apply_record_update] rather than deciding those
## questions here — [Rack] is a [Node3D] and cannot be exercised in a bare
## [code]--script[/code] unit test, so a rule that only lived here could only
## ever be reimplemented in a test, never actually proven against (02-05).
##
## [b]No RPC annotation lives in this file, and none may be added.[/b] Every
## method here is called [code]apply_*[/code] deliberately: it applies a
## decision already made, it never broadcasts one. The RPC wrapper that calls
## these on every peer belongs in [code]carry_authority.gd[/code] (02-06 for
## the new record/orientation-carrying broadcasts this plan adds) — 02-09's
## own verification greps this file for the RPC annotation and expects zero,
## so that literal string is deliberately not spelled out even in this
## comment.

const RACKED_ITEM_SCENE := preload("res://scenes/goods/racked_item.tscn")

## What [method show_highlight] paints on [member _cell_highlight]. Not two
## states but three: an aim that will be refused has to look different from
## an aim the game has not noticed, or a dragging player standing under a
## shelf they cannot reach gets no signal that the refusal is deliberate.
enum Highlight { NONE, ACTIONABLE, BLOCKED }

## Colours for the two visible states. Exported, not constant, so they can be
## judged and retuned in play rather than guessed once here.
@export var highlight_actionable := Color(0.35, 0.85, 0.45)
@export var highlight_blocked := Color(0.85, 0.30, 0.30)

## How long a placed item takes to travel from where it was picked up to its
## cell (01-06). Long enough to read as a movement, short enough to stay
## responsive — exported because this is exactly the kind of number that gets
## judged with a crate in hand, not derived from anything.
@export var snap_time := 0.16

## ADR 24's rack-presentation inset (ratified at the Phase 1 gate), applied as
## a NODE scale on top of each size's own base scale (see [method _base_scale])
## rather than a mesh change — shrinks the visual inside its cell envelope so
## it clears the decks (vertical) and, for a Medium or Large, the corner
## uprights it would otherwise clip (horizontal), the same clearance problem
## [method StorageGrid.mint_offset] solves for the physical body, solved here
## for the VISUAL by shrinking rather than shifting (a shifted mesh would sit
## off-centre on its own future pallet, Phase 6). Both numbers are exported so
## Phase 6 can retune them in play — the RULE (racked items sit inset, not
## flush) is ADR 24's and fixed; only these two numbers are provisional.
@export_range(0.5, 1.0, 0.01) var vertical_inset_scale := 0.78
@export_range(0.5, 1.0, 0.01) var horizontal_inset_scale := 0.9

## How fast an incoming crate has to be moving, on the host's own
## [member RigidBody3D.linear_velocity], to shed the top row (01-07, STORE-05).
## Below this you bumped it; above, you hit it — ADR 4 wants racks stable, not
## fragile, so this is a threshold for recklessness, not ambient noise.
##
## ⚠ CORRECTED 2026-08-22 — the original reasoning here was arithmetically
## wrong and is preserved as a warning rather than quietly deleted. It claimed
## "4.0 sits above the player's own 4.2 m/s walk speed". It does not; 4.0 is
## BELOW 4.2. The real argument was always about the hold spring, not the walk
## speed: a *carried* crate trails its holder rather than matching them, so
## ordinary carrying is expected to stay under the threshold. That claim is
## still untested.
##
## ⚠ It was also silent about SPRINT_SPEED (6.4 m/s), and Crate.lag_compensation
## is explicitly built to CANCEL steady-state lag — so a steady sprint-carry
## should converge the crate toward its holder's speed, well over this gate.
## Sprint-carrying a crate into a rack corner may therefore shed it. Unverified
## either way; the gate is to measure the crate's real velocity at the sensor
## during a sprint carry before this number moves. See docs/test-coverage.md.
##
## Separately: this is a pure SPEED test with no mass term. It was a momentum
## proxy while every crate weighed 12 kg, and stopped being one when ADR 25
## gave crates real masses (5 kg to 108 kg). Nothing asserts it at all.
##
## What it comfortably cannot reach is a solo
## drag: ADR 19's drag spring tops out near 1.7 m/s (softer stiffness, and the
## floor-plane-only force never gets to add a vertical throw), so a dragged
## crate can never shed a rack by itself, no matter how hard the corner is
## cut. That is correct — two-player carry is the only way to hit something
## hard enough to matter — but it is a conscious call, not a coincidence, and
## the wave 7 gate should see this comment before either number moves.
## Confirmed with a thrown crate only; a human check with one actually in
## hand is still owed (01-08).
@export var shed_impact_speed := 4.0
## Seconds between sheds. Without it, one crate settling and bouncing once
## inside the sensor would fire the referee repeatedly for what is really one
## impact.
@export var shed_cooldown := 1.5

## How long a just-minted crate is immune to shedding this rack, milliseconds.
## [method CarryAuthority.request_retrieve] and [method
## CarryAuthority.shed_top_row] both spawn a fresh [Crate] at a cell's own
## centre — which sits inside [member _impact_sensor]'s volume by
## construction, since the sensor exists to catch cargo riding at shelf
## height — and the hold spring (a retrieval) or the launch impulse (a shed)
## can then accelerate that brand-new body past [member shed_impact_speed]
## while it is still overlapping the sensor it was born inside, shedding the
## row it was just taken from, or a shed crate re-triggering the sensor a
## second time. [member Crate.age_ms] is checked against this before
## anything else in [method _on_impact] — deliberately not folded into
## [member shed_cooldown], which throttles repeated *impacts on the rack*;
## this throttles one specific crate's own first moment of life instead, and
## the two are unrelated (found live at the wave 7 gate, 2026-08-21:
## retrieving from a loaded top row sheds the row it was retrieved from).
## 700 ms comfortably clears both the retrieval grant round trip and a shed's
## own initial impulse decaying, without being long enough to blind the
## sensor to a genuine swing into the rack moments later.
const MINT_GRACE_MS := 700

@onready var _impact_sensor: Area3D = $ImpactSensor
## Far enough in the past that the very first real impact is never blocked by
## a cooldown that never actually happened.
var _last_shed_ms := -1000000

## One entry per cell index 0..11:
## [codeblock]
## {
##   "category": StringName,  # &"" when empty. ADR 18/25 atomicity keys off
##                             # this alone - a category IS what ADR 18 has
##                             # always meant by "kind" (ADR 25 (a)).
##   "items":    Array,        # LIFO stack of CargoRecord dictionaries.
##                             # Newest last. A Medium or Large cell holds
##                             # exactly one entry; a Small cell holds up to 8.
##   "size":     int,          # CargoCatalogue.Size of everything in this
##                             # cell. Cells are atomic by category AND
##                             # homogeneous by size - eight Smalls or one
##                             # Medium, never a mixture. Meaningless (0) while
##                             # "items" is empty.
##   "partner":  int,          # -1 normally. The OTHER half's cell index for
##                             # a Large; both halves point at each other.
##   "anchor":   bool,         # true on the half this Large's record and
##                             # visual belong to; false on the other half.
##   "orientation": int,       # StorageGrid.Orientation. Meaningful only when
##                             # "partner" != -1.
## }
## [/codeblock]
##
## [b]Both halves of a Large hold their OWN duplicated copy of the same
## record[/b], rather than one half holding it and the other holding a link.
## A self-describing cell means [method occupancy_snapshot] needs no special
## case, a late joiner can render either half with no link to resolve first,
## and either half can answer "what is in me" — which matters because a
## player will aim at whichever half they can see. The cost is that the pair
## must always be mutated TOGETHER: contained entirely by routing every Large
## mutation through exactly [method add_large], [method remove_large] and
## [method apply_record_update] — nothing else ever writes "partner" /
## "anchor" / "orientation", and a rack holding half a Large (one side
## occupied, its partner empty or pointing elsewhere) is an invariant
## violation with no legal way to reach it.
##
## This replaces the Phase 1 shape ([code]{"kind": StringName, "ids": Array[int]}[/code])
## outright: that shape was honest about Phase 1 and wrong the moment a
## record carried more than a bare kind — see 02-05-SUMMARY.md for the full
## reasoning and the methods that had to be re-decided against it.
var _cells: Array[Dictionary] = []

@onready var _racked_items: Node3D = $RackedItems
@onready var _cell_highlight: MeshInstance3D = $CellHighlight


func _ready() -> void:
	_cells.resize(StorageGrid.cell_count())
	for i in _cells.size():
		_cells[i] = _empty_cell()
	add_to_group("racks")

	# Only the host acts on impacts, same split as Crate's own PushSensor - a
	# client running detection it never reads is pure waste, and that waste
	# multiplies by rack count the same way it did by crate count in the
	# physics budget measurement (ADR 14).
	if not Net.is_host():
		_impact_sensor.monitoring = false
		return
	_impact_sensor.body_entered.connect(_on_impact)


func _empty_cell() -> Dictionary:
	return {
		"category": &"",
		"items": [],
		"size": 0,
		"partner": -1,
		"anchor": false,
		"orientation": 0,
	}


# ------------------------------------------------------------------ impact

## Host-only, connected in [method _ready]. [param body] is whatever
## physically entered [member _impact_sensor] - checked for actually being
## cargo before anything else, since mask 4 also lets a [i]held[/i] crate
## trigger this (see [member _impact_sensor]'s own description for why that
## is deliberate) and nothing guarantees an overlapping body is a [Crate].
##
## No replication trick is needed here, unlike [method Crate._apply_shoves],
## which has to read a player's [i]replicated[/i] velocity because a puppet
## capsule runs no physics of its own. A crate - held or loose - is always
## simulated for real on the host, so [member RigidBody3D.linear_velocity] is
## ground truth right here. Do not "fix" this into reading a synced velocity
## instead; that is solving a problem this code does not have.
func _on_impact(body: Node3D) -> void:
	var crate := body as Crate
	if crate == null:
		return
	# See MINT_GRACE_MS: a crate this young was minted at a cell centre inside
	# this very sensor and has not had a chance to leave it yet.
	if crate.age_ms() < MINT_GRACE_MS:
		return
	if crate.linear_velocity.length() < shed_impact_speed:
		return
	var now := Time.get_ticks_msec()
	if now - _last_shed_ms < int(shed_cooldown * 1000.0):
		return
	if is_empty():
		return

	_last_shed_ms = now

	# Resolved at the moment of impact, not cached in _ready(): sidesteps any
	# question of which node enters the "carry_authority" group first, the
	# same lazy lookup Carrier._authority() already uses. Do not "optimise"
	# this into a stored reference - it would be null on the first frame on
	# some peers.
	var referee := get_tree().get_first_node_in_group("carry_authority")
	if referee != null and referee.has_method("shed_top_row"):
		referee.shed_top_row(self)


# ---------------------------------------------------------------- geometry

## Rack-local centre of a cell. Delegates entirely to [StorageGrid] — see the
## coordinate-order note on [method StorageGrid.cell_coords] before touching
## this.
func cell_to_local_position(cell: int) -> Vector3:
	return StorageGrid.cell_centre(cell)


func cell_to_global_position(cell: int) -> Vector3:
	return global_transform * cell_to_local_position(cell)


## The cell containing [param world_point], or -1 when it is outside this rack.
func cell_at_point(world_point: Vector3) -> int:
	return StorageGrid.cell_index_at(to_local(world_point))


## Global position of one item's own sub-position within a cell — renamed
## from [code]small_global_position[/code] (01-03/01-06): that name was a lie
## for two of the three sizes the moment Medium and Large existed. Grepped at
## zero external callers before this rename (02-05).
func item_global_position(cell: int, sub_index: int, size: int) -> Vector3:
	var local_position := StorageGrid.cell_centre(cell) + StorageGrid.item_offset(size, sub_index)
	return global_transform * local_position


## Global position of a Large's own pair centre — the other half of [method
## item_global_position] for the one size that spans two cells instead of
## sitting inside one.
func large_global_position(anchor: int, partner: int) -> Vector3:
	return global_transform * StorageGrid.pair_centre(anchor, partner)


## Where [param size] actually mints, in global space — a cell (or, for a
## Large, a pair's) centre plus [method StorageGrid.mint_offset]'s clearance
## shift (ADR 24). The one caller-facing entry point for the clearance rule,
## so 02-06's [code]request_retrieve[/code] calls this rather than
## reimplementing the offset math itself.
func mint_position(cell: int, size: int, orientation: int) -> Vector3:
	if size == CargoCatalogue.Size.LARGE:
		var partner := StorageGrid.large_partner_cell(cell, orientation)
		var local_position := StorageGrid.pair_centre(cell, partner) + StorageGrid.mint_offset(size, orientation, cell)
		return global_transform * local_position

	var local_position := StorageGrid.cell_centre(cell) + StorageGrid.mint_offset(size, orientation, cell)
	return global_transform * local_position


# ----------------------------------------------------------------- feedback
#
# Purely local presentation (01-06). Driven every frame from Carrier._process,
# using the exact same aim query the keypress itself uses, so what this paints
# and what a press actually does can never diverge. Never replicated: this
# sits on a node every peer *can* see, which is exactly the kind of thing
# that invites someone to wire up a MultiplayerSynchronizer for it - don't.
# A highlight is a question one player is asking the rack, not a fact every
# peer needs to agree on.

## Moves [member _cell_highlight] onto [param cell_index] and colours it for
## [param state]. [constant Highlight.NONE], or an out-of-range index, hides
## it instead - callers do not need their own branch for "nothing to show".
##
## [param footprint_cells] is new (02-08), interim scaffolding for a Large's
## two-cell aim — [code]## Interim (02-08) — 02-09 replaces this with the
## ghost preview[/code]. Empty (the default) or a single entry: behave
## exactly as before this plan — position at [param cell_index]'s own centre,
## scale reset to [constant Vector3.ONE] (its own implicit value before this
## plan) — so nothing about Small or Medium placement changes. Exactly two
## entries: position at the pair's own centre
## ([method StorageGrid.pair_centre]) and stretch [member _cell_highlight]'s
## NODE scale (never [member MeshInstance3D.mesh] itself, the same "scale the
## node, not the mesh" rule [method _base_scale]'s own doc comment states for
## racked visuals) along whichever horizontal axis the two cells differ on,
## so the box spans the full two-cell footprint edge to edge rather than
## floating at its midpoint the size of one cell. Scale is reset in EVERY
## branch, not only the two-cell one — this node is reused frame to frame, so
## a stretch left over from a Large aim would otherwise silently stick around
## the next time this same highlight paints a single Small/Medium cell.
func show_highlight(cell_index: int, state: Highlight, footprint_cells: Array[int] = []) -> void:
	if state == Highlight.NONE or cell_index < 0 or cell_index >= StorageGrid.cell_count():
		hide_highlight()
		return

	var colour := highlight_actionable if state == Highlight.ACTIONABLE else highlight_blocked
	var material := _cell_highlight.material_override as StandardMaterial3D
	material.albedo_color = Color(colour.r, colour.g, colour.b, material.albedo_color.a)
	material.emission = colour

	if footprint_cells.size() == 2:
		var coords_a := StorageGrid.cell_coords(footprint_cells[0])
		var coords_b := StorageGrid.cell_coords(footprint_cells[1])
		_cell_highlight.position = StorageGrid.pair_centre(footprint_cells[0], footprint_cells[1])
		# The full two-cell footprint spans exactly 2 x CELL_SIZE, edge to
		# edge, along whichever axis the pair differs on - column (world/local
		# x) for a SIDE_BY_SIDE pair, depth (world/local z) for FRONT_TO_BACK.
		# Read off the mesh's OWN fixed size rather than a duplicated magic
		# number, so this never silently drifts from whatever BoxMesh_highlight
		# is actually set to in rack.tscn.
		var base_size: float = (_cell_highlight.mesh as BoxMesh).size.x
		var span := 2.0 * StorageGrid.CELL_SIZE / base_size
		if coords_a.x != coords_b.x:
			_cell_highlight.scale = Vector3(span, 1.0, 1.0)
		else:
			_cell_highlight.scale = Vector3(1.0, 1.0, span)
	else:
		_cell_highlight.position = cell_to_local_position(cell_index)
		_cell_highlight.scale = Vector3.ONE

	_cell_highlight.visible = true


func hide_highlight() -> void:
	_cell_highlight.visible = false


# ---------------------------------------------------------------- occupancy

func occupied_count(cell: int) -> int:
	return _items(cell).size()


## The crate id on top of the cell's stack, -1 when empty — the top RECORD's
## own "id" field now, rather than a bare id stack (02-05's shape change; the
## contract itself is unchanged from 01-03).
##
## -1 rather than 0: crate ids are minted from 0 (see
## [code]TestRoom._next_crate_id[/code]), so 0 is a real crate, not "nothing
## here". StorageGrid's own convention for "no answer" is -1 — this follows it.
func occupant(cell: int) -> int:
	var items := _items(cell)
	if items.is_empty():
		return -1
	return int((items.back() as Dictionary).get("id", -1))


## The top record itself, duplicated so a caller cannot mutate this rack's own
## state by editing what it was handed — the same discipline
## [method occupancy_snapshot] already follows. [code]{}[/code] when the cell
## is empty.
func occupant_record(cell: int) -> Dictionary:
	var items := _items(cell)
	if items.is_empty():
		return {}
	return (items.back() as Dictionary).duplicate(true)


func cell_kind(cell: int) -> StringName:
	return _cells[cell]["category"]


## The [enum StorageGrid.Orientation] a Large stored at [param cell] was
## actually placed with — the accessor [method CarryAuthority.request_retrieve]
## and [method CarryAuthority.shed_top_row] need (02-08) so a retrieval or a
## shed re-mints at the SAME orientation that was chosen at placement, rather
## than hard-coding [constant StorageGrid.Orientation.SIDE_BY_SIDE]. Only
## meaningful when [param cell] holds a Large — [code]0[/code]
## ([constant StorageGrid.Orientation.SIDE_BY_SIDE]) for anything else, which
## is also harmless: nothing reads this for a Small or a Medium.
func cell_orientation(cell: int) -> int:
	return int(_cells[cell].get("orientation", 0))


func is_cell_empty(cell: int) -> bool:
	return occupied_count(cell) == 0


## True when every cell is empty. Late-joiner sync (01-04) reads this to skip
## sending a snapshot for a rack that has nothing in it yet.
func is_empty() -> bool:
	for cell in _cells:
		if not (cell["items"] as Array).is_empty():
			return false
	return true


## 01-07's shed reads this. The top level is the one nothing reaches except by
## having been racked up there in the first place.
##
## A Large's own two halves both sit in the top row for a FRONT_TO_BACK Large
## anchored there — this returns the ANCHOR only, never both, or a shed would
## spawn the same Large twice: [method CarryAuthority.shed_top_row] spawns one
## crate per returned cell (01-07), and Crate._recover's whole supply-conservation
## point depends on nothing ever minting a duplicate.
func occupied_cells_in_top_row() -> Array[int]:
	var top_level := StorageGrid.RACK_LEVELS - 1
	var found: Array[int] = []
	for cell in _cells.size():
		if StorageGrid.cell_coords(cell).z != top_level:
			continue
		if is_cell_empty(cell):
			continue
		var data := _cells[cell]
		if int(data.get("partner", -1)) != -1 and not bool(data.get("anchor", false)):
			continue
		found.append(cell)
	return found


## The whole rack's state in one value, so a late joiner can be brought up to
## date — without this, "every peer agrees" would only be true for peers
## present at the moment a cell last changed. Every record travels in full,
## not as a bare id (02-05): a late joiner needs the whole record to render a
## correct size and, from Phase 3, a correct apparent condition. This is a
## ONE-TIME, per-join cost — unlike the 20 Hz replication ADR 14 measured for
## loose cargo — so its size is not a bandwidth concern the way a per-frame
## channel would be; do not "optimise" it back down to an id list later on
## that basis, because the whole point of carrying full records is that an id
## alone is not enough once a cell holds more than a kind.
##
## Duplicated on the way out, so a caller mutating what it was handed cannot
## mutate this rack's real state.
##
## Measured (02-06, [code]var_to_bytes[/code] on a synthetic worst case): a
## fully loaded rack — 12 cells x 8 Smalls, the maximum this shape allows —
## serialises to ~38.8 KB; 12 cells of one Medium each (the least crowded
## "full" rack) is ~6.5 KB. A one-time, per-join cost, not the per-frame
## channel ADR 14's own bandwidth budget governs — see this method's own
## class-doc paragraph above for why that distinction matters.
func occupancy_snapshot() -> Array:
	var snapshot: Array = []
	for cell in _cells:
		var items: Array = []
		for item in (cell["items"] as Array):
			items.append((item as Dictionary).duplicate(true))
		snapshot.append({
			"category": cell["category"],
			"items": items,
			"size": cell["size"],
			"partner": cell["partner"],
			"anchor": cell["anchor"],
			"orientation": cell["orientation"],
		})
	return snapshot


## Replaces this rack's occupancy wholesale and rebuilds every cell's visuals
## from it, instantly and silently — the late-joiner path (01-04). A peer that
## was not present for earlier placements has to be brought up to date in one
## shot rather than by replaying every [method apply_cell_filled] since the
## rack was last empty, which is exactly the case [method _spawn_cell_visual]'s
## [constant Vector3.ZERO] sentinel exists for: this rack's *existing* contents
## should appear, not fly in from the world origin with a thud each. A Large's
## visual belongs to its anchor half alone (see [method _spawn_large_visual]) —
## the non-anchor half rebuilds its data but spawns nothing. Duplicated on the
## way in for the same reason [method occupancy_snapshot] duplicates on the
## way out: this rack's state must not alias the dictionary the caller handed
## over.
func apply_occupancy_snapshot(snapshot: Array) -> void:
	for cell in snapshot.size():
		var data := snapshot[cell] as Dictionary
		var items: Array = []
		for item in (data.get("items", []) as Array):
			items.append((item as Dictionary).duplicate(true))

		_cells[cell] = {
			"category": data.get("category", &""),
			"items": items,
			"size": int(data.get("size", 0)),
			"partner": int(data.get("partner", -1)),
			"anchor": bool(data.get("anchor", false)),
			"orientation": int(data.get("orientation", 0)),
		}
		_clear_cell_visuals(cell)

		if items.is_empty():
			continue

		var partner := int(data.get("partner", -1))
		if partner != -1:
			if bool(data.get("anchor", false)):
				_spawn_large_visual(cell, partner, int(data.get("orientation", 0)), Vector3.ZERO)
			# The non-anchor half owns no visual of its own - see
			# _spawn_large_visual's own doc comment.
			continue

		var size := int(data.get("size", 0))
		for i in items.size():
			_spawn_cell_visual(cell, i, size, Vector3.ZERO)


# ---------------------------------------------------------------- mutation
#
# add_to_cell / remove_from_cell / add_large / remove_large are the state
# change. apply_cell_filled / apply_cell_cleared are the broadcast entry
# points — what CarryAuthority's host-authoritative RPCs call on every peer,
# host included via call_local. They own the state change *and* the visual it
# produces: a fly-in tween and a thud for a placement (01-06), an instant
# removal for a retrieval. Nothing outside this file should call the inner
# functions directly.

## False when [param cell] cannot take one more item of [param category] /
## [param size] — full, or already holding something else (ADR 18/25's
## atomicity, now at CATEGORY level, ADR 25 (a)). Handles SMALL and MEDIUM by
## delegating the actual decision to [method StorageGrid.cell_can_accept]; a
## LARGE is a different question with a different shape (two cells, not one)
## answered by [method can_accept_large] instead of an overloaded meaning of
## "accept" here.
func can_accept(cell: int, category: StringName, size: int) -> bool:
	if size == CargoCatalogue.Size.LARGE:
		print("[rack] can_accept() called with a LARGE — use can_accept_large() instead")
		return false
	return StorageGrid.cell_can_accept(_cells[cell], category, size)


## The Large-shaped question [method can_accept] deliberately does not
## answer: a Large needs BOTH [param cell] and its
## [method StorageGrid.large_partner_cell] (given [param orientation])
## entirely empty — there is no atomicity question to ask beyond that,
## because a Large never shares a cell with anything else by construction
## (ADR 18/25 (d)). [param category] is accepted purely for signature
## symmetry with [method can_accept] and is not itself used — a fully-empty
## pair needs no category check.
func can_accept_large(cell: int, _category: StringName, orientation: int) -> bool:
	var partner := StorageGrid.large_partner_cell(cell, orientation)
	return is_cell_empty(cell) and is_cell_empty(partner)


## Pushes [param record] (a wire-safe dictionary, [method CargoRecord.to_dict]'s
## own shape) onto [param cell]'s stack and returns the sub-index it landed at
## ([method StorageGrid.next_fill_index] for a Small, always 0 for a Medium —
## a Large never comes through here, see [method add_large]), or -1 if the
## cell has no room. Does not itself enforce atomicity or capacity — [method
## can_accept] is where that rule lives (01-03's own split, unchanged).
## [param record] is duplicated on the way in so this cell's copy cannot be
## mutated by whatever the caller does with its own copy afterwards — the
## same discipline [method occupancy_snapshot] already follows.
func add_to_cell(cell: int, record: Dictionary) -> int:
	var data := _cells[cell]
	var items := data["items"] as Array
	var size := int(record.get("size", CargoCatalogue.Size.SMALL))

	var sub_index := 0
	if size == CargoCatalogue.Size.SMALL:
		sub_index = StorageGrid.next_fill_index(items.size())
		if sub_index == -1:
			return -1

	if items.is_empty():
		data["category"] = record.get("category", &"")
		data["size"] = size

	items.append((record as Dictionary).duplicate(true))
	return sub_index


## Pops the top record — LIFO — and returns it, or [code]{}[/code] if the
## cell was already empty. The empty sentinel is now [code]{}[/code] rather
## than 01-03's [code]-1[/code]: that convention was about IDS, and a record
## is not one. Delegates to [method remove_large] when [param cell] is half
## of a Large — a Large is never partly removed (see that method's own doc
## comment).
func remove_from_cell(cell: int) -> Dictionary:
	var data := _cells[cell]
	if int(data.get("partner", -1)) != -1:
		return remove_large(cell)

	var items := data["items"] as Array
	if items.is_empty():
		return {}
	var record: Dictionary = items.pop_back()
	if items.is_empty():
		data["category"] = &""
		data["size"] = 0
	return record


## The only place [param anchor]/[param partner]'s "partner" / "anchor" /
## "orientation" fields are ever written. Both halves get their OWN
## duplicated copy of [param record] (see the class doc's shape note): a
## self-describing cell means a late joiner or a future plaque can read
## either half with no link to resolve first, at the cost that every
## mutation has to keep both copies identical — contained entirely by
## routing every Large mutation through this function and
## [method remove_large] / [method apply_record_update], never touching a
## Large's own two dictionaries any other way.
func add_large(anchor: int, partner: int, record: Dictionary, orientation: int) -> void:
	var category: StringName = record.get("category", &"")
	_cells[anchor] = {
		"category": category,
		"items": [(record as Dictionary).duplicate(true)],
		"size": CargoCatalogue.Size.LARGE,
		"partner": partner,
		"anchor": true,
		"orientation": orientation,
	}
	_cells[partner] = {
		"category": category,
		"items": [(record as Dictionary).duplicate(true)],
		"size": CargoCatalogue.Size.LARGE,
		"partner": anchor,
		"anchor": false,
		"orientation": orientation,
	}


## Accepts EITHER half — resolves the true anchor from [param cell]'s own
## "partner" / "anchor" fields, returns the record, and empties both. A rack
## holding half a Large is an invariant violation with no legal way to reach
## it: every path that clears one half of a pair comes through here, never
## through [method remove_from_cell]'s plain branch.
func remove_large(cell: int) -> Dictionary:
	var data := _cells[cell]
	var partner := int(data.get("partner", -1))
	if partner == -1:
		return {}

	var anchor_cell := cell if bool(data.get("anchor", false)) else partner
	var other_cell := partner if bool(data.get("anchor", false)) else cell

	var anchor_items := _cells[anchor_cell]["items"] as Array
	var record: Dictionary = anchor_items[0] if not anchor_items.is_empty() else {}

	_cells[anchor_cell] = _empty_cell()
	_cells[other_cell] = _empty_cell()
	return record


## Wraps [method add_to_cell] / [method add_large] and grows that cell's
## visuals by exactly the one item that just arrived — the others, already
## in place, are untouched.
##
## [param record] is a [method CargoRecord.to_dict]-shaped Dictionary and
## [param orientation] a [enum StorageGrid.Orientation] int for anything but
## a Small (which ignores orientation entirely) — this function delegates to
## [method add_large] when [param record]'s own "size" field is LARGE
## (resolving the partner cell from [param cell] and [param orientation]
## itself, so no caller computes that arithmetic twice), otherwise to
## [method add_to_cell]. [param from_position] is where the crate travelled
## from; see [method _spawn_cell_visual] for what [constant Vector3.ZERO]
## means there.
##
## [b]Deliberately no static type on [param record] / [param orientation][/b],
## unlike every other typed parameter in this file. This plan (02-05) changes
## what this function is handed — a full record and an orientation, where
## 01-03/02-04 passed a bare crate id and a kind — but it does NOT update
## [code]CarryAuthority._cell_filled[/code]'s own call site; that is 02-06's
## job (see 02-05-SUMMARY.md for the full list of what is left broken and
## why). Godot's static analyzer checks a call's argument TYPES against a
## STATICALLY TYPED callee at PARSE time, not merely at the moment the call
## runs — confirmed empirically, not assumed, while writing this plan. If
## these two parameters carried a static type, the stale call
## ([code]rack.apply_cell_filled(cell_index, crate_id, kind, from_position)[/code],
## passing an [code]int[/code] and a [code]StringName[/code] where a
## [code]Dictionary[/code] and an [code]int[/code] are now expected) would
## fail to PARSE at all, taking the whole of [code]carry_authority.gd[/code]
## — and every scene that uses it — down with it. That would make
## [code]smoke[/code] fail on a broken scene, not what this plan intends: a
## clean, isolated RUNTIME error the moment the stale call actually fires,
## confined to [code]integration[/code]. Leaving these two untyped keeps
## [code]carry_authority.gd[/code] loading correctly until 02-06 fixes the
## call site for real.
func apply_cell_filled(cell: int, record, orientation, from_position: Vector3) -> void:
	var size := int((record as Dictionary).get("size", CargoCatalogue.Size.SMALL))

	if size == CargoCatalogue.Size.LARGE:
		var partner := StorageGrid.large_partner_cell(cell, int(orientation))
		add_large(cell, partner, record, int(orientation))
		_spawn_large_visual(cell, partner, int(orientation), from_position)
		return

	var sub_index := add_to_cell(cell, record)
	if sub_index == -1:
		return
	_spawn_cell_visual(cell, sub_index, size, from_position)


## Wraps [method remove_from_cell] and frees exactly the one visual that was
## on top — or, when [param cell] is half of a Large, both halves and the one
## visual a Large ever has (see [method remove_large] and
## [method _spawn_large_visual]: a Large's visual is owned by its anchor cell
## alone). LIFO means a Small's freed visual is always the highest sub-index
## this cell currently holds, so nothing below it needs to move or even be
## looked at.
func apply_cell_cleared(cell: int) -> void:
	var data := _cells[cell]
	if int(data.get("partner", -1)) != -1:
		var anchor_cell := cell if bool(data.get("anchor", false)) else int(data["partner"])
		remove_large(cell)
		_free_cell_visual(anchor_cell, 0)
		return

	var top_index := (data["items"] as Array).size() - 1
	remove_from_cell(cell)
	if top_index >= 0:
		_free_cell_visual(cell, top_index)


## The write-through editor for a record already sitting in a cell — it
## exists because once a crate is racked its [Crate] is gone (plain
## [code]queue_free()[/code], 01-03) and this cell's stored dictionary is the
## only copy of its state left. Anything that later needs to change a field
## of racked stock — 02-10 bumps a missed collection's [code]store_until_day[/code]
## to tomorrow; Phase 3 will want the same door for condition — has nowhere
## else to write.
##
## LOCAL ONLY: no RPC annotation, no broadcast (see the class doc on why that
## literal string is never spelled out here, even to say there are none of
## them). The broadcast wrapper every peer actually calls is 02-06's, in
## [code]carry_authority.gd[/code], beside [code]_cell_filled[/code] /
## [code]_cell_cleared[/code].
##
## The actual decision — find by id, refuse an unknown key, write the
## partner too — is [method StorageGrid.cell_apply_record_update]'s (moved
## there in this plan; see that method's own doc comment for why). This
## function only resolves which dictionaries to hand it and reports the
## refusal reason: [code]print()[/code] rather than [code]push_warning()[/code]
## (test/README.md's zero-tolerance rule — anything a test needs to trigger
## cannot warn).
func apply_record_update(cell: int, crate_id: int, changes: Dictionary) -> bool:
	var data := _cells[cell]
	var partner_index := int(data.get("partner", -1))
	var partner_data = _cells[partner_index] if partner_index != -1 else null

	if not StorageGrid.cell_apply_record_update(data, partner_data, crate_id, changes):
		if not _cell_has_id(data, crate_id):
			print("[rack] apply_record_update: cell %d does not hold crate_%d — no change" % [cell, crate_id])
		else:
			print("[rack] apply_record_update: an unknown field in %s was refused for crate_%d — no change" % [changes, crate_id])
		return false

	_refresh_cell_visual(cell)
	return true


func _cell_has_id(data: Dictionary, crate_id: int) -> bool:
	for item in (data["items"] as Array):
		if int((item as Dictionary).get("id", -1)) == crate_id:
			return true
	return false


## The "this cell's contents changed" hook [method apply_record_update]
## routes through, matching the class doc's promise that a change refreshes
## whatever is derived from a cell's contents. A no-op today — nothing this
## file draws depends on any field a record update can touch (size cannot
## change through this function; only fields like [code]store_until_day[/code]
## can, and nothing renders those yet) — but named and called consistently so
## 02-09's plaque only has to fill this in, not go hunting for where "a cell
## changed" is decided.
func _refresh_cell_visual(_cell: int) -> void:
	pass


# ---------------------------------------------------------------- visuals

## Base mesh is 0.5 m cubed (ADR 18, [code]racked_item.tscn[/code]) — scaling
## the NODE rather than the mesh is what keeps the api layer's "the mesh
## itself is 0.5 m" assertion true regardless of what is racked (do not "fix"
## the mesh instead). 1x1x1 = Small, 2x2x2 = Medium (1.0 m cubed), 4x2x2 =
## Large (2.0 x 1.0 x 1.0 m, its 2 m axis along local X per ADR 25 (d)).
func _base_scale(size: int) -> Vector3:
	match size:
		CargoCatalogue.Size.MEDIUM:
			return Vector3(2.0, 2.0, 2.0)
		CargoCatalogue.Size.LARGE:
			return Vector3(4.0, 2.0, 2.0)
		_:
			return Vector3.ONE


## [method _base_scale] with ADR 24's inset applied — see
## [member vertical_inset_scale] / [member horizontal_inset_scale]'s own doc
## comments.
func _inset_scale(size: int) -> Vector3:
	var base := _base_scale(size)
	return Vector3(
		base.x * horizontal_inset_scale,
		base.y * vertical_inset_scale,
		base.z * horizontal_inset_scale,
	)


## Derived, never replicated (see class doc). Every peer runs this from its
## own copy of the occupancy state, so the meshes are a consequence of that
## state rather than a second copy of it that can disagree.
##
## [param from_position] is rack-local-agnostic (a world position) on
## purpose — the crate it describes was picked up somewhere in the world, not
## somewhere in this rack. [constant Vector3.ZERO] is the late-joiner sentinel:
## a real placement's [param from_position] is wherever the crate physically
## was, which in practice is never the exact world origin, so this is not the
## bare zero-check it looks like — see [method apply_occupancy_snapshot].
func _spawn_cell_visual(cell: int, sub_index: int, size: int, from_position: Vector3) -> void:
	var item := RACKED_ITEM_SCENE.instantiate() as Node3D
	item.name = "Cell%d_Item%d" % [cell, sub_index]
	var target := StorageGrid.cell_centre(cell) + StorageGrid.item_offset(size, sub_index)
	var settled_scale := _inset_scale(size)

	if from_position == Vector3.ZERO:
		item.position = target
		item.scale = settled_scale
		_racked_items.add_child(item)
		return

	# Both ends of the travel are in the rack's own local space — mixing a
	# global start with a local target is a bug that only shows up once a
	# rack is rotated. Neither fixture in test_room.tscn is rotated today,
	# so this would pass silently without the local conversion below.
	item.position = to_local(from_position)
	item.scale = settled_scale * 1.06
	_racked_items.add_child(item)

	var sound := item.get_node_or_null("PlaceSound") as AudioStreamPlayer3D
	if sound != null:
		sound.play()

	# bind_node ties the tween's lifetime to the item: apply_cell_cleared can
	# free this same node before the travel finishes (a cell filled and
	# immediately retrieved again), and without this the tween would go on
	# trying to write "position"/"scale" on a freed instance next frame.
	var tween := create_tween().bind_node(item)
	tween.set_parallel(true)
	tween.tween_property(item, "position", target, snap_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Animates FROM base_scale * 1.06 TO base_scale, not from a bare
	# Vector3(1.06,1.06,1.06) to Vector3.ONE as 01-06 originally wrote it —
	# with a base scale that is no longer always Vector3.ONE (a Medium or
	# Large), the old numbers would have snapped the item to roughly a
	# quarter of its real size mid-flight, which reads as a rendering glitch
	# rather than the bug it actually is. Called out here so nobody
	# "fixes" this back to the literal constants.
	tween.tween_property(item, "scale", settled_scale, snap_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## A Large's visual spawns ONCE, owned by [param anchor] alone — [method
## apply_cell_cleared] frees it from there too, which is why a Large's own
## [code]Cell%d_Item%d[/code] name always uses the anchor's cell index, never
## the partner's; the partner half owns data but no visual node at all.
func _spawn_large_visual(anchor: int, partner: int, orientation: int, from_position: Vector3) -> void:
	var item := RACKED_ITEM_SCENE.instantiate() as Node3D
	item.name = "Cell%d_Item0" % anchor
	var target := StorageGrid.pair_centre(anchor, partner)
	var yaw := StorageGrid.large_yaw(orientation)
	var settled_scale := _inset_scale(CargoCatalogue.Size.LARGE)

	if from_position == Vector3.ZERO:
		item.position = target
		item.rotation.y = yaw
		item.scale = settled_scale
		_racked_items.add_child(item)
		return

	item.position = to_local(from_position)
	item.rotation.y = yaw
	item.scale = settled_scale * 1.06
	_racked_items.add_child(item)

	var sound := item.get_node_or_null("PlaceSound") as AudioStreamPlayer3D
	if sound != null:
		sound.play()

	var tween := create_tween().bind_node(item)
	tween.set_parallel(true)
	tween.tween_property(item, "position", target, snap_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "scale", settled_scale, snap_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _free_cell_visual(cell: int, sub_index: int) -> void:
	var node := _racked_items.get_node_or_null("Cell%d_Item%d" % [cell, sub_index])
	if node != null:
		node.queue_free()


func _clear_cell_visuals(cell: int) -> void:
	var prefix := "Cell%d_Item" % cell
	for child in _racked_items.get_children():
		if String(child.name).begins_with(prefix):
			child.queue_free()


func _items(cell: int) -> Array:
	return _cells[cell]["items"] as Array
