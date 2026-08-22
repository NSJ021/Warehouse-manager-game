class_name StorageGrid
extends RefCounted

## Pure cell arithmetic for one rack (ADR 18). No nodes, no state, no
## networking - every function here is static and takes exactly what it
## needs, so it unit-tests in isolation and gets reused unchanged by every
## rack, by placement, and by Phase 2's size classes.
##
## The unit of storage is a 1.0 m cell, not an item. A cell is atomic - one
## category of cargo at a time (ADR 25 (a) finally names what "kind" always
## meant) - and retrieval is last-in-first-out, which is what makes
## badly-ordered stock physically painful to reach rather than merely
## inconvenient. Eight Smalls tile a cell as a 2x2x2 lattice; a Medium fills a
## whole cell; a Large spans two adjacent cells - see [enum Orientation],
## [method large_partner_cell] and [method mint_offset] for that shape (ADR 25
## (d), landed 02-05).
##
## A rack is 2 columns wide x 2 cells deep x 3 levels high - 12 cells, 96
## Smalls, 12 Mediums, or 6 Larges. A solo player reaches level 0 only (GDD
## §6.1), so the top two levels are two-player work; the co-op incentive
## lives in this geometry, not in a rule bolted on top of it.

const CELL_SIZE := 1.0     # one storage cell, cubed
const SMALL_SIZE := 0.5    # a Small crate, cubed
const SMALLS_PER_CELL := 8 # 2 x 2 x 2

const RACK_COLUMNS := 2    # cells across -> 2.0 m wide
const RACK_DEPTH := 2      # cells deep   -> 2.0 m deep
const RACK_LEVELS := 3     # cells high   -> 3.0 m tall
const CELLS_PER_RACK := RACK_COLUMNS * RACK_DEPTH * RACK_LEVELS  # 12

const _CELLS_PER_LEVEL := RACK_COLUMNS * RACK_DEPTH  # 4, one level's worth

## Phase 2's three size classes (ADR 25), as raw ints matching
## [code]CargoCatalogue.Size[/code]'s own declaration order (SMALL=0,
## MEDIUM=1, LARGE=2) rather than a reference to that enum - this file stays
## dependency-free, the same reasoning [code]CargoRecord.cells()[/code]'s own
## "2 == LARGE" comment already follows, because it has to load standalone in
## a bare [code]--script[/code] unit test with nothing else resolved on the
## class path.
const SIZE_SMALL := 0
const SIZE_MEDIUM := 1
const SIZE_LARGE := 2

## A Large spans two adjacent cells (ADR 18/25 (d)), and which two depends on
## how it is turned: [constant SIDE_BY_SIDE] flips the rack's own column -
## the way you would naturally see two crates side by side on a shelf, and
## [constant FRONT_TO_BACK] flips the depth instead - the turn that makes a
## wall rack's otherwise permanently-blocked back row (ADR 24) reachable by a
## Large end-on.
enum Orientation { SIDE_BY_SIDE, FRONT_TO_BACK }

## ADR 24, ratified at the Phase 1 gate: the rack's frame does not move, so a
## body too big to clear a corner upright at a cell's bare centre has to mint
## somewhere else instead - see [method mint_offset].
const UPRIGHT_SIZE := 0.1     ## The corner uprights themselves, 0.1 m square.
const MINT_CLEARANCE := 0.12  ## UPRIGHT_SIZE plus a 0.02 m margin.


static func cell_count() -> int:
	return CELLS_PER_RACK


## Rack-local (column, depth, level) for a cell index - not world axes; see
## [method cell_centre] for where these become an actual position.
##
## Packing: index = level * (COLUMNS * DEPTH) + depth * COLUMNS + column.
## Every downstream plan depends on this exact formula, so it is written down
## once here rather than re-derived at each call site.
static func cell_coords(index: int) -> Vector3i:
	@warning_ignore("integer_division")
	var level := index / _CELLS_PER_LEVEL
	var remainder := index % _CELLS_PER_LEVEL
	@warning_ignore("integer_division")
	var depth := remainder / RACK_COLUMNS
	var column := remainder % RACK_COLUMNS
	return Vector3i(column, depth, level)


## Inverse of [method cell_coords]. Takes the same (column, depth, level)
## triple back to a single index.
static func cell_index_from_coords(coords: Vector3i) -> int:
	return coords.z * _CELLS_PER_LEVEL + coords.y * RACK_COLUMNS + coords.x


## Rack-local centre of a cell, origin at the rack's own transform, cell 0 at
## the near-bottom corner. Column -> x (right), level -> y (up), depth -> z
## (into the rack) - the one place the column/depth/level order in
## [method cell_coords] gets mapped onto Godot's actual x/y/z.
static func cell_centre(index: int) -> Vector3:
	var coords := cell_coords(index)
	return Vector3(
		(coords.x + 0.5) * CELL_SIZE,
		(coords.z + 0.5) * CELL_SIZE,
		(coords.y + 0.5) * CELL_SIZE,
	)


## The cell containing a rack-local position, or -1 if it is outside the
## rack. Cells are half-open on every axis - [n * CELL_SIZE, (n + 1) *
## CELL_SIZE) - so a point exactly on an internal seam belongs to the higher
## cell, and a point exactly on the rack's own outer boundary is outside,
## never the last cell rounding up to claim it.
static func cell_index_at(local_position: Vector3) -> int:
	var column := int(floor(local_position.x / CELL_SIZE))
	var level := int(floor(local_position.y / CELL_SIZE))
	var depth := int(floor(local_position.z / CELL_SIZE))

	if column < 0 or column >= RACK_COLUMNS:
		return -1
	if depth < 0 or depth >= RACK_DEPTH:
		return -1
	if level < 0 or level >= RACK_LEVELS:
		return -1

	return cell_index_from_coords(Vector3i(column, depth, level))


## Offset of one Small position from its own cell's centre - the 2x2x2
## lattice ADR 18 fixes at 8 per cell. sub_index runs 0..7; bit 0 picks x,
## bit 1 picks y, bit 2 picks z, so every combination lands on a distinct
## corner and the eight tile the cell with no gap and no overlap.
static func small_offset(sub_index: int) -> Vector3:
	var sx := sub_index & 1
	var sy := (sub_index >> 1) & 1
	var sz := (sub_index >> 2) & 1
	return Vector3(
		(sx - 0.5) * SMALL_SIZE,
		(sy - 0.5) * SMALL_SIZE,
		(sz - 0.5) * SMALL_SIZE,
	)


## Where an item of [param size] sits within its own cell - [method
## small_offset]'s 2x2x2 sub-lattice for a Small, or dead centre
## ([constant Vector3.ZERO]) for a Medium or a Large, neither of which has a
## sub-lattice to speak of. One entry point so callers stop branching on size
## themselves.
static func item_offset(size: int, sub_index: int) -> Vector3:
	if size == SIZE_SMALL:
		return small_offset(sub_index)
	return Vector3.ZERO


## How many items of [param size] fit in ONE cell - 8 Smalls, 1 Medium, 1
## Large (ADR 18). Distinct from [method cells_for_size]: a Large's capacity
## here is 1 (one Large fits in the cell it is anchored to), not the number
## of cells it spans - conflating the two is how a Large ends up thought of
## as "capacity 0.5", which is backwards.
static func capacity_for_size(size: int) -> int:
	if size == SIZE_SMALL:
		return SMALLS_PER_CELL
	return 1


## How many cells one item of [param size] occupies - 1 for Small and
## Medium, 2 for Large (ADR 18/25 (d)). See [method capacity_for_size] for
## the question this is deliberately NOT answering.
static func cells_for_size(size: int) -> int:
	return 2 if size == SIZE_LARGE else 1


## The other cell a Large anchored at [param anchor_index] also occupies,
## given [param orientation]. [constant Orientation.SIDE_BY_SIDE] flips the
## column (mirrors across the rack's own x); [constant Orientation.FRONT_TO_BACK]
## flips the depth (mirrors across z).
##
## The `1 - n` trick below is only correct because ADR 18 fixes both
## [constant RACK_COLUMNS] and [constant RACK_DEPTH] at exactly 2 - flipping
## "the other of two" is the same as `1 - n` only when there are exactly two.
## A future wider bay would need real reflection arithmetic instead of this
## shortcut, so the assumption is asserted in the unit test
## ([code]RACK_COLUMNS == 2 and RACK_DEPTH == 2[/code]) rather than guarded
## here - a rack that silently computed a partner cell off the end of a wider
## bay would be a much worse failure than a loud unit-test break.
##
## Deliberately no bounds check on [param anchor_index] here - the guard is
## that unit assertion, not a runtime clamp.
static func large_partner_cell(anchor_index: int, orientation: int) -> int:
	var coords := cell_coords(anchor_index)
	if orientation == Orientation.SIDE_BY_SIDE:
		return cell_index_from_coords(Vector3i(1 - coords.x, coords.y, coords.z))
	return cell_index_from_coords(Vector3i(coords.x, 1 - coords.y, coords.z))


## The midpoint between two cells' own centres - where a Large's body and its
## visual both sit, straddling the seam between [param anchor_index] and
## [param partner_index].
static func pair_centre(anchor_index: int, partner_index: int) -> Vector3:
	return cell_centre(anchor_index).lerp(cell_centre(partner_index), 0.5)


## How far a Large's own local +X axis (its fixed 2 m dimension, ADR 25 (d))
## must be turned to lie along whichever pair of cells [param orientation]
## spans. [method cell_centre] maps column -> x and depth -> z, so a
## SIDE_BY_SIDE pair (two columns) already lies along local X with no turn
## needed; a FRONT_TO_BACK pair (two depths) lies along Z instead, a quarter
## turn away.
static func large_yaw(orientation: int) -> float:
	return PI / 2.0 if orientation == Orientation.FRONT_TO_BACK else 0.0


## How far off a cell's own centre a body of [param size] must mint to clear
## the corner uprights (ADR 24) rather than spawn intersecting them. A
## corner cell's own centre lands exactly [constant UPRIGHT_SIZE] inside the
## upright there on both horizontal axes - invisible for a Small (0.5 m,
## clears with room to spare, which is why this never came up before Phase
## 2) and real for a Medium (1.0 m) or a Large (2.0 m along one axis). Every
## cell in this rack is a "corner" cell horizontally, because ADR 18 fixes
## [constant RACK_COLUMNS] and [constant RACK_DEPTH] at exactly 2 each.
##
## Rule, stated so it survives a rewrite: shift toward the rack's own
## horizontal centre by [constant MINT_CLEARANCE], on each horizontal axis
## the body does NOT already span the rack's full 2 m. A body spanning the
## full width has no room to move on that axis and does not need to - both
## its ends sit at an upright either way, and the shift on the OTHER axis is
## what clears them both. Worked cases:
##   - Medium in cell (0,0): +0.12 on x AND z -> footprint x[0.12,1.12],
##     z[0.12,1.12]. Clear of every upright band (each [0,0.1] or [1.9,2.0]).
##   - Side-by-side Large (spans x 0-2): shift on Z ONLY -> z[0.12,1.12]
##     (front pair) or z[0.88,1.88] (back pair). Clear.
##   - Front-to-back Large (spans z 0-2): shift on X ONLY, by the same
##     reasoning with the axes swapped.
##   - Small: [constant Vector3.ZERO] - it already clears (see above), and
##     shifting it would break every existing Small-lattice assertion for no
##     reason.
##
## This pushes a Medium or Large into a NEIGHBOURING cell's airspace on the
## shifted axis or axes. Harmless: racked items have no collision (ADR 14),
## so the only thing it can ever overlap is another body in transit, which
## the solver already handles like any other cargo interaction.
static func mint_offset(size: int, orientation: int, anchor_index: int) -> Vector3:
	if size == SIZE_SMALL:
		return Vector3.ZERO

	var spans_full_x := size == SIZE_LARGE and orientation == Orientation.SIDE_BY_SIDE
	var spans_full_z := size == SIZE_LARGE and orientation == Orientation.FRONT_TO_BACK

	var coords := cell_coords(anchor_index)
	var toward_centre_x := 1.0 if coords.x == 0 else -1.0
	var toward_centre_z := 1.0 if coords.y == 0 else -1.0

	return Vector3(
		0.0 if spans_full_x else toward_centre_x * MINT_CLEARANCE,
		0.0,
		0.0 if spans_full_z else toward_centre_z * MINT_CLEARANCE,
	)


# A Large spans two adjacent cells (ADR 18) rather than sitting inside one -
# StorageGrid.large_partner_cell (above) resolves the second cell, and
# [Rack] (02-05) stores both halves. This comment used to say that shape was
# unbuilt; it is not any more.


## The position LIFO fill takes next, given how many of a cell's 8 slots are
## already occupied. Positions fill in index order - 0 first - purely so that
## removal (below) can be the exact reverse with no bookkeeping beyond a
## count. -1 once the cell is full.
static func next_fill_index(occupied_count: int) -> int:
	if occupied_count < 0 or occupied_count >= SMALLS_PER_CELL:
		return -1
	return occupied_count


## The position LIFO retrieval takes next - the most recently filled one.
## Exact inverse of [method next_fill_index]: fill to N, then remove from
## N + 1, and it hands back the position fill just used. -1 once the cell is
## empty.
static func next_remove_index(occupied_count: int) -> int:
	if occupied_count <= 0 or occupied_count > SMALLS_PER_CELL:
		return -1
	return occupied_count - 1


# ---------------------------------------------------------------- occupancy
#
# Pure occupancy rules, moved here out of Rack (02-05) rather than tested
# twice: Rack is a Node3D and cannot be exercised in a bare --script run, so
# a unit test that wanted to prove these rules either reimplemented them (a
# second copy that can silently drift from the real one) or called them here
# directly. Both functions below operate on a plain dictionary shaped exactly
# like one entry of Rack's own [code]_cells[/code] array - {"category":
# StringName, "items": Array, "size": int, ...} - so they work identically
# whether the dictionary in hand is a real rack cell or one built purely for
# a test.

## The append-only "is there room for one more of [param category] / [param
## size] in [param cell]" question - SMALL and MEDIUM only. A LARGE is a
## different, two-cell question with no meaning here; see [Rack]'s own
## [code]can_accept_large[/code].
static func cell_can_accept(cell: Dictionary, category: StringName, size: int) -> bool:
	var items := cell["items"] as Array
	if items.is_empty():
		return true
	if size == SIZE_MEDIUM:
		# A Medium never fits an occupied cell, however little the cell
		# holds - ADR 18's packing sting working exactly as designed.
		return false
	if size != SIZE_SMALL:
		return false
	if cell["category"] != category:
		return false
	if int(cell["size"]) != SIZE_SMALL:
		return false
	return items.size() < capacity_for_size(SIZE_SMALL)


## Applies [param changes] to the record matching [param crate_id] inside
## [param cell]'s own "items" stack, and - when [param partner] is not
## [code]null[/code] - the same crate's copy there too (a Large's two
## self-describing halves, ADR 25 (d); the caller is responsible for
## resolving which dictionary that is before calling this). Validates BEFORE
## mutating anything: an unknown id, or a change naming a field the stored
## record does not already have, both change nothing and return
## [code]false[/code]. Pure - the caller ([Rack]) owns deciding whether and
## how to report the refusal; this function only reports pass or fail.
static func cell_apply_record_update(cell: Dictionary, partner, crate_id: int, changes: Dictionary) -> bool:
	var items := cell["items"] as Array
	var index := -1
	for i in items.size():
		if int((items[i] as Dictionary).get("id", -1)) == crate_id:
			index = i
			break
	if index == -1:
		return false

	var record := items[index] as Dictionary
	for key in changes:
		if not record.has(key):
			return false

	for key in changes:
		record[key] = changes[key]

	if partner != null:
		var partner_items := (partner as Dictionary)["items"] as Array
		for i in partner_items.size():
			if int((partner_items[i] as Dictionary).get("id", -1)) == crate_id:
				partner_items[i] = record.duplicate(true)

	return true
