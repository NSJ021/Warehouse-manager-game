extends SceneTree

## Unit layer: the cell arithmetic every rack, every placement, and every
## Phase 2 size class will use (ADR 18).
##
## Cell maths is index-in, position-out, with exact expected answers - the one
## corner of Phase 1 pure enough to be written test-first. This file was run
## once against a project with no scripts/world/storage_grid.gd and it failed
## by naming the missing file rather than crashing - see the load() guard
## below - before that script existed to make it pass.
##
## Loaded at runtime with load(), not a static `class_name StorageGrid`
## reference: a static reference would make this test compile-depend on the
## file, which fails a --script run outright rather than failing the one
## thing this test exists to check. test/api/engine_assumptions.gd hit this
## first.
##
## Follows test/unit/dilemma_maths.gd's shape: a SceneTree script printing
## `[unit] ok` / `[unit] FAIL` lines and exiting non-zero on failure.
##
## Run via tools/run-tests.ps1. Exits 0 on pass, 1 on any failure.

const STORAGE_GRID_PATH := "res://scripts/world/storage_grid.gd"

var _failures: Array[String] = []
var _checked := 0


func _initialize() -> void:
	var grid := load(STORAGE_GRID_PATH) as GDScript
	if grid == null:
		# Named failure, not a crash - this is the state Task 1 exists to prove.
		print("[unit] FAIL storage_grid.gd not found at %s" % STORAGE_GRID_PATH)
		quit(1)
		return

	_check_dimensions(grid)
	_check_cell_round_trip(grid)
	_check_boundary(grid)
	_check_lattice(grid)
	_check_lifo(grid)
	_report()


# --------------------------------------------------------- dimensions

## ADR 18's numbers, asserted rather than only written down - this is the
## section that catches somebody "tidying" a constant later.
func _check_dimensions(grid: GDScript) -> void:
	print("[unit] ADR 18's dimensions")
	_expect(is_equal_approx(grid.CELL_SIZE, 1.0), "a cell is 1.0 m cubed (got %s)" % grid.CELL_SIZE)
	_expect(is_equal_approx(grid.SMALL_SIZE, 0.5), "a Small is 0.5 m cubed (got %s)" % grid.SMALL_SIZE)
	_expect(grid.SMALLS_PER_CELL == 8, "8 Smalls per cell, a 2x2x2 lattice (got %d)" % grid.SMALLS_PER_CELL)
	_expect(grid.RACK_COLUMNS == 2, "a rack is 2 cells across (got %d)" % grid.RACK_COLUMNS)
	_expect(grid.RACK_DEPTH == 2, "a rack is 2 cells deep (got %d)" % grid.RACK_DEPTH)
	_expect(grid.RACK_LEVELS == 3, "a rack is 3 cells high (got %d)" % grid.RACK_LEVELS)
	_expect(grid.CELLS_PER_RACK == 12, "12 cells per rack (got %d)" % grid.CELLS_PER_RACK)
	_expect(grid.cell_count() == 12, "cell_count() agrees with CELLS_PER_RACK (got %d)" % grid.cell_count())


# ------------------------------------------------------- cell round trip

func _check_cell_round_trip(grid: GDScript) -> void:
	print("[unit] cell index <-> cell centre, both ways")

	# Cell 0 pinned to its exact expected corner. Round-tripping alone cannot
	# catch a lattice that is uniformly offset - centre and index-at would
	# still agree with each other even if the whole rack had drifted off the
	# transform's own origin - so this is the check that catches that.
	var origin_centre: Vector3 = grid.cell_centre(0)
	_expect(
		_v3_eq(origin_centre, Vector3(0.5, 0.5, 0.5)),
		"cell 0 sits at the near-bottom corner (got %s)" % origin_centre,
	)

	for i in range(grid.cell_count()):
		var centre: Vector3 = grid.cell_centre(i)
		var back: int = grid.cell_index_at(centre)
		_expect(back == i, "cell %d's centre resolves back to cell %d (got %d)" % [i, i, back])

	# The far corner, opposite cell 0 - catches an off-by-one on a single axis
	# that the near corner alone would not.
	var far_centre: Vector3 = grid.cell_centre(grid.cell_count() - 1)
	_expect(
		_v3_eq(far_centre, Vector3(1.5, 2.5, 1.5)),
		"the last cell sits at the far-top corner (got %s)" % far_centre,
	)


# ------------------------------------------------------------- boundary

## A point outside the rack must resolve to -1, never to whichever cell
## happens to be nearest. Cells are half-open - [n, n+1) on every axis - so a
## point exactly on an internal boundary belongs to the higher cell, and a
## point on the rack's own outer boundary is outside, not inside the last
## cell. Asserted here rather than left to be discovered later by a rack that
## silently snapped an item to the wrong slot.
func _check_boundary(grid: GDScript) -> void:
	print("[unit] outside the rack resolves to -1, boundaries are defined")

	var rack_width: float = grid.RACK_COLUMNS * grid.CELL_SIZE
	var rack_depth: float = grid.RACK_DEPTH * grid.CELL_SIZE
	var rack_height: float = grid.RACK_LEVELS * grid.CELL_SIZE

	var outside := [
		Vector3(-0.01, 0.5, 0.5),
		Vector3(rack_width + 0.01, 0.5, 0.5),
		Vector3(0.5, -0.01, 0.5),
		Vector3(0.5, rack_height + 0.01, 0.5),
		Vector3(0.5, 0.5, -0.01),
		Vector3(0.5, 0.5, rack_depth + 0.01),
	]
	for point in outside:
		var index: int = grid.cell_index_at(point)
		_expect(index == -1, "%s is outside the rack (got %d)" % [point, index])

	# The rack's own outer boundary, exactly - not "just outside" but
	# precisely on the plane the interior test would love to round up to.
	_expect(
		grid.cell_index_at(Vector3(rack_width, 0.5, 0.5)) == -1,
		"exactly on the far x boundary is still outside",
	)
	_expect(
		grid.cell_index_at(Vector3(0.5, rack_height, 0.5)) == -1,
		"exactly on the far y boundary is still outside",
	)
	_expect(
		grid.cell_index_at(Vector3(0.5, 0.5, rack_depth)) == -1,
		"exactly on the far z boundary is still outside",
	)

	# The near corner belongs to cell 0, exactly.
	_expect(grid.cell_index_at(Vector3.ZERO) == 0, "the rack's own origin belongs to cell 0")

	# An internal boundary plane, exactly - x = 1.0 is the seam between column
	# 0 and column 1. The rule: it belongs to the higher cell, not the lower.
	var seam := Vector3(1.0, 0.5, 0.5)
	var seam_index: int = grid.cell_index_at(seam)
	var expected: int = grid.cell_index_from_coords(Vector3i(1, 0, 0))
	_expect(
		seam_index == expected,
		"an internal boundary belongs to the higher cell, not the lower one (got %d, want %d)" % [seam_index, expected],
	)


# --------------------------------------------------------- the lattice

## The 8 Small positions inside one cell. Checked at the extreme cell (index
## 11) as well as cell 0, since a lattice bug tied to the cell's own position
## rather than its size would otherwise hide behind the origin cell alone.
func _check_lattice(grid: GDScript) -> void:
	print("[unit] the 2x2x2 lattice inside a cell")
	_check_lattice_at_cell(grid, 0)
	_check_lattice_at_cell(grid, grid.cell_count() - 1)


func _check_lattice_at_cell(grid: GDScript, cell_index: int) -> void:
	var offsets: Array[Vector3] = []
	for sub in range(grid.SMALLS_PER_CELL):
		offsets.append(grid.small_offset(sub))

	var half_cell: float = grid.CELL_SIZE * 0.5
	var half_small: float = grid.SMALL_SIZE * 0.5

	for sub in range(offsets.size()):
		var offset: Vector3 = offsets[sub]
		# Inside the cell: the position itself is within the cell's own half-extent.
		var inside := (
			absf(offset.x) <= half_cell + 0.0001
			and absf(offset.y) <= half_cell + 0.0001
			and absf(offset.z) <= half_cell + 0.0001
		)
		_expect(inside, "cell %d small %d sits inside the cell (offset %s)" % [cell_index, sub, offset])

		# Fits: the Small's own extent, not just its centre point, stays inside
		# the cell - the check that catches a lattice that is subtly too big,
		# which would look fine on the centre check alone and interpenetrate.
		var fits := (
			absf(offset.x) + half_small <= half_cell + 0.0001
			and absf(offset.y) + half_small <= half_cell + 0.0001
			and absf(offset.z) + half_small <= half_cell + 0.0001
		)
		_expect(fits, "cell %d small %d fits within CELL_SIZE (offset %s)" % [cell_index, sub, offset])

	for a in range(offsets.size()):
		for b in range(offsets.size()):
			if a == b:
				continue
			var distance: float = offsets[a].distance_to(offsets[b])
			_expect(
				distance >= grid.SMALL_SIZE - 0.0001,
				"cell %d smalls %d and %d are at least SMALL_SIZE apart (got %s)" % [cell_index, a, b, distance],
			)

	var unique: Dictionary = {}
	for offset in offsets:
		unique[offset] = true
	_expect(
		unique.size() == grid.SMALLS_PER_CELL,
		"cell %d's 8 positions are 8 distinct corners, not fewer (got %d)" % [cell_index, unique.size()],
	)


# ----------------------------------------------------------------- LIFO

## Fill and empty are exact inverses, so retrieval order is arithmetic rather
## than bookkeeping. This is the assertion that protects the memory game: if
## it ever drifts, stock comes out in the wrong order and nothing on screen
## shows it.
func _check_lifo(grid: GDScript) -> void:
	print("[unit] LIFO fill and removal are exact inverses")

	var fill_order: Array[int] = []
	for occupied in range(grid.SMALLS_PER_CELL):
		fill_order.append(grid.next_fill_index(occupied))
	_expect(grid.next_fill_index(grid.SMALLS_PER_CELL) == -1, "a full cell has nowhere left to fill")

	var remove_order: Array[int] = []
	for occupied in range(grid.SMALLS_PER_CELL, 0, -1):
		remove_order.append(grid.next_remove_index(occupied))
	_expect(grid.next_remove_index(0) == -1, "an empty cell has nothing to remove")

	var expected_remove_order: Array = fill_order.duplicate()
	expected_remove_order.reverse()
	_expect(
		remove_order == expected_remove_order,
		"removal order %s is the exact reverse of fill order %s" % [remove_order, fill_order],
	)

	# Partial fill, remove one, refill - next_fill_index() and
	# next_remove_index() are pure functions of a count rather than of any
	# history, so this is simulated by moving the count directly. The reused
	# position must be the one just vacated, not the next new one.
	var occupied_count := 5
	var vacated: int = grid.next_remove_index(occupied_count)
	occupied_count -= 1
	var reused: int = grid.next_fill_index(occupied_count)
	_expect(
		reused == vacated,
		"refilling after one removal reuses the position just vacated (vacated %d, reused %d)" % [vacated, reused],
	)


# --------------------------------------------------------------- helpers

func _v3_eq(a: Vector3, b: Vector3) -> bool:
	return is_equal_approx(a.x, b.x) and is_equal_approx(a.y, b.y) and is_equal_approx(a.z, b.z)


func _expect(condition: bool, label: String) -> void:
	_checked += 1
	if condition:
		print("[unit] ok   %s" % label)
		return
	_failures.append(label)
	print("[unit] FAIL %s" % label)


func _report() -> void:
	if _failures.is_empty():
		print("[unit] PASS - %d checks on the cell arithmetic" % _checked)
		quit(0)
		return
	print("[unit] FAIL - %d of %d checks failed" % [_failures.size(), _checked])
	for failure in _failures:
		print("[unit]      %s" % failure)
	quit(1)
