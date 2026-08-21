class_name StorageGrid
extends RefCounted

## Pure cell arithmetic for one rack (ADR 18). No nodes, no state, no
## networking - every function here is static and takes exactly what it
## needs, so it unit-tests in isolation and gets reused unchanged by every
## rack, by placement, and later by Phase 2's size classes.
##
## The unit of storage is a 1.0 m cell, not an item. A cell is atomic - one
## kind of cargo at a time - and retrieval is last-in-first-out, which is
## what makes badly-ordered stock physically painful to reach rather than
## merely inconvenient. Eight Smalls tile a cell as a 2x2x2 lattice; a Medium
## fills a whole cell; a Large spans two adjacent cells (not modelled here -
## see the note above [method small_offset]).
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

# A Large spans two adjacent cells (ADR 18) rather than sitting inside one, so
# it needs a second cell index and an orientation between them - that is a
# Phase 2 size-class API, and nothing here builds toward it yet.


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
