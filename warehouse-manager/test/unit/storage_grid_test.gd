extends SceneTree

## Unit layer: the cell arithmetic every rack, every placement, and every
## Phase 2 size class uses (ADR 18), plus (02-05) the occupancy DECISIONS that
## moved into StorageGrid so a bare --script run could prove them for real
## rather than reimplement them (see _check_occupancy_rules' own comment).
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
	_check_sizes(grid)
	_check_large_partner_cell(grid)
	_check_yaw_and_pair_centre(grid)
	_check_mint_offset_clears_uprights(grid)
	_check_occupancy_rules(grid)
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


# ----------------------------------------------------------- Phase 2 sizes

## capacity_for_size / cells_for_size (ADR 18) - the two DIFFERENT questions
## a Large's "capacity" invites conflating, per storage_grid.gd's own doc
## comment.
func _check_sizes(grid: GDScript) -> void:
	print("[unit] Phase 2 size classes (ADR 25) - SIZE_* ordinals and capacity/footprint")

	_expect(grid.SIZE_SMALL == 0, "SIZE_SMALL matches CargoCatalogue.Size.SMALL's own ordinal (got %d)" % grid.SIZE_SMALL)
	_expect(grid.SIZE_MEDIUM == 1, "SIZE_MEDIUM matches CargoCatalogue.Size.MEDIUM's own ordinal (got %d)" % grid.SIZE_MEDIUM)
	_expect(grid.SIZE_LARGE == 2, "SIZE_LARGE matches CargoCatalogue.Size.LARGE's own ordinal (got %d)" % grid.SIZE_LARGE)

	_expect(grid.capacity_for_size(grid.SIZE_SMALL) == grid.SMALLS_PER_CELL, "8 Smalls fit in one cell")
	_expect(grid.capacity_for_size(grid.SIZE_MEDIUM) == 1, "1 Medium fits in one cell")
	_expect(grid.capacity_for_size(grid.SIZE_LARGE) == 1, "1 Large fits in the cell it is anchored to")

	_expect(grid.cells_for_size(grid.SIZE_SMALL) == 1, "a Small takes 1 cell")
	_expect(grid.cells_for_size(grid.SIZE_MEDIUM) == 1, "a Medium takes 1 cell")
	_expect(grid.cells_for_size(grid.SIZE_LARGE) == 2, "a Large takes 2 cells")


## large_partner_cell (ADR 25 (d)) - both orientations, every one of the 12
## cells, checked for validity, its own inverse, sharing a level, and
## differing in exactly one axis.
func _check_large_partner_cell(grid: GDScript) -> void:
	print("[unit] StorageGrid.large_partner_cell (ADR 25 (d))")

	_expect(grid.RACK_COLUMNS == 2, "large_partner_cell's 1-n trick depends on RACK_COLUMNS == 2 (got %d)" % grid.RACK_COLUMNS)
	_expect(grid.RACK_DEPTH == 2, "large_partner_cell's 1-n trick depends on RACK_DEPTH == 2 (got %d)" % grid.RACK_DEPTH)

	var orientations := [grid.Orientation.SIDE_BY_SIDE, grid.Orientation.FRONT_TO_BACK]
	for cell in range(grid.cell_count()):
		for orientation in orientations:
			var partner: int = grid.large_partner_cell(cell, orientation)
			_expect(
				partner >= 0 and partner < grid.cell_count(),
				"cell %d orientation %d partner %d is a valid cell index" % [cell, orientation, partner],
			)

			var back: int = grid.large_partner_cell(partner, orientation)
			_expect(
				back == cell,
				"large_partner_cell is its own inverse: cell %d -> %d -> %d" % [cell, partner, back],
			)

			var cell_coords: Vector3i = grid.cell_coords(cell)
			var partner_coords: Vector3i = grid.cell_coords(partner)
			_expect(
				cell_coords.z == partner_coords.z,
				"cell %d and its partner %d share a level (got %d and %d)" % [cell, partner, cell_coords.z, partner_coords.z],
			)

			var column_differs := cell_coords.x != partner_coords.x
			var depth_differs := cell_coords.y != partner_coords.y
			_expect(
				column_differs != depth_differs,
				"cell %d and partner %d differ in exactly one of column or depth (column_differs=%s depth_differs=%s)" % [cell, partner, column_differs, depth_differs],
			)


## large_yaw and pair_centre - the turn and the midpoint a Large's own body
## and visual both need.
func _check_yaw_and_pair_centre(grid: GDScript) -> void:
	print("[unit] large_yaw / pair_centre")

	_expect(is_equal_approx(grid.large_yaw(grid.Orientation.SIDE_BY_SIDE), 0.0), "side-by-side needs no turn")
	_expect(is_equal_approx(grid.large_yaw(grid.Orientation.FRONT_TO_BACK), PI / 2.0), "front-to-back is a quarter turn")

	var samples := [0, 3, 5, 9]
	for anchor in samples:
		for orientation in [grid.Orientation.SIDE_BY_SIDE, grid.Orientation.FRONT_TO_BACK]:
			var partner: int = grid.large_partner_cell(anchor, orientation)
			var expected: Vector3 = (grid.cell_centre(anchor) + grid.cell_centre(partner)) / 2.0
			var got: Vector3 = grid.pair_centre(anchor, partner)
			_expect(
				_v3_eq(got, expected),
				"pair_centre(%d, %d) sits exactly halfway (got %s, want %s)" % [anchor, partner, got, expected],
			)


## mint_offset (ADR 24) - the real geometry from rack.tscn, measured
## independently of the implementation: four corner uprights, 0.1 m square,
## centred at (0.05,0.05), (1.95,0.05), (0.05,1.95), (1.95,1.95). A body's
## footprint must miss every one of the four, computed as a real 2D box
## overlap rather than a per-axis heuristic - a side-by-side Large, for
## instance, DOES span the full upright-bearing x range and can only clear
## by being out of the upright's z range instead, which a naive per-axis
## check would get backwards.
const _UPRIGHT_CORNERS := [
	Vector2(0.05, 0.05), Vector2(1.95, 0.05), Vector2(0.05, 1.95), Vector2(1.95, 1.95),
]
const _UPRIGHT_SIZE := 0.1

func _check_mint_offset_clears_uprights(grid: GDScript) -> void:
	print("[unit] mint_offset clears the corner uprights (ADR 24)")

	# Small: never shifts, and never needs to - the plan's own explicit
	# "returns Vector3.ZERO" rule.
	_expect(
		grid.mint_offset(grid.SIZE_SMALL, grid.Orientation.SIDE_BY_SIDE, 0) == Vector3.ZERO,
		"a Small's mint_offset is always zero",
	)

	# Medium: every one of the 12 cells is a corner cell at this rack's 2x2
	# horizontal footprint (ADR 18 fixes RACK_COLUMNS == RACK_DEPTH == 2), so
	# all twelve are worth checking, not just the four distinct horizontal
	# positions - a per-level bug would hide behind checking level 0 alone.
	for cell in range(grid.cell_count()):
		var centre: Vector3 = grid.cell_centre(cell)
		var offset: Vector3 = grid.mint_offset(grid.SIZE_MEDIUM, grid.Orientation.SIDE_BY_SIDE, cell)
		var mint: Vector3 = centre + offset
		_assert_clears_uprights(mint, 1.0, 1.0, "Medium at cell %d" % cell)

	# Large, both orientations, every anchor cell.
	for cell in range(grid.cell_count()):
		for orientation in [grid.Orientation.SIDE_BY_SIDE, grid.Orientation.FRONT_TO_BACK]:
			var partner: int = grid.large_partner_cell(cell, orientation)
			var pair_centre: Vector3 = grid.pair_centre(cell, partner)
			var offset: Vector3 = grid.mint_offset(grid.SIZE_LARGE, orientation, cell)
			var mint: Vector3 = pair_centre + offset
			var full_x: bool = (orientation == grid.Orientation.SIDE_BY_SIDE)
			var extent_x: float = 2.0 if full_x else 1.0
			var extent_z: float = 1.0 if full_x else 2.0
			_assert_clears_uprights(
				mint, extent_x, extent_z,
				"Large (orientation %d) anchored at cell %d" % [orientation, cell],
			)


func _assert_clears_uprights(mint: Vector3, extent_x: float, extent_z: float, label: String) -> void:
	var half_x := extent_x * 0.5
	var half_z := extent_z * 0.5
	var min_x := mint.x - half_x
	var max_x := mint.x + half_x
	var min_z := mint.z - half_z
	var max_z := mint.z + half_z
	var half_upright := _UPRIGHT_SIZE * 0.5

	for corner in _UPRIGHT_CORNERS:
		var ux0: float = corner.x - half_upright
		var ux1: float = corner.x + half_upright
		var uz0: float = corner.y - half_upright
		var uz1: float = corner.y + half_upright
		var overlaps := not (max_x <= ux0 or min_x >= ux1 or max_z <= uz0 or min_z >= uz1)
		_expect(
			not overlaps,
			"%s clears the upright at %s (footprint x[%.2f,%.2f] z[%.2f,%.2f] vs upright x[%.2f,%.2f] z[%.2f,%.2f])" % [
				label, corner, min_x, max_x, min_z, max_z, ux0, ux1, uz0, uz1,
			],
		)


# --------------------------------------------------------- occupancy rules

## ADR 18/25's occupancy rules, proven directly against the real
## [code]StorageGrid.cell_can_accept[/code] / [code]StorageGrid.cell_apply_record_update[/code]
## (moved there OUT of Rack during this plan, precisely because reimplementing
## them here would have been a second copy free to silently disagree with the
## real one - see rack.gd's own class doc for the same reasoning stated from
## the production side). [Rack] itself is a Node3D and cannot be exercised in
## a bare --script run - see test/README.md's own rule - so everything ELSE
## this plan decided (a Large's two cells, LIFO order surviving whole
## records, in-place editing) is modelled here as plain dictionaries shaped
## exactly like Rack's own per-cell entries, which is what Rack itself builds
## and mutates. 02-06's integration scenario is what proves Rack agrees over
## the real wire.
func _check_occupancy_rules(grid: GDScript) -> void:
	print("[unit] cell occupancy rules (ADR 18/25 (a)/(d))")

	var small: int = grid.SIZE_SMALL
	var medium: int = grid.SIZE_MEDIUM

	# Eight Smalls of one category, then the ninth refused.
	var cell := _fresh_cell()
	for i in grid.SMALLS_PER_CELL:
		_expect(
			grid.cell_can_accept(cell, &"textiles", small),
			"cell accepts Small %d of 8 (textiles)" % i,
		)
		_fill_small(cell, &"textiles", i)
	_expect(
		not grid.cell_can_accept(cell, &"textiles", small),
		"a full cell (8 Smalls) refuses a 9th",
	)

	# A cell with one Small refuses a Medium.
	var one_small := _fresh_cell()
	_fill_small(one_small, &"textiles", 0)
	_expect(
		not grid.cell_can_accept(one_small, &"textiles", medium),
		"a cell holding one Small refuses a Medium (ADR 18's packing sting)",
	)

	# A cell with a Medium refuses a Small, and a second Medium.
	var one_medium := _fresh_cell()
	_fill_medium(one_medium, &"masonry")
	_expect(
		not grid.cell_can_accept(one_medium, &"masonry", small),
		"a cell holding a Medium refuses a Small",
	)
	_expect(
		not grid.cell_can_accept(one_medium, &"masonry", medium),
		"a cell holding a Medium refuses a second Medium",
	)

	# Atomicity: a second category is refused at any size.
	_expect(
		not grid.cell_can_accept(one_small, &"novelty", small),
		"a cell refuses a different category, at Small size",
	)
	_expect(
		not grid.cell_can_accept(one_medium, &"novelty", medium),
		"a cell refuses a different category, at Medium size",
	)

	# Two different variants of the SAME category are accepted (ADR 25 (a)) -
	# cell_can_accept only ever looks at category, never variant, so this is
	# already true by construction; asserted anyway because it is exactly the
	# rule someone would tighten by accident.
	var mixed_variants := _fresh_cell()
	_fill_small(mixed_variants, &"textiles", 0, &"bath_towels")
	_expect(
		grid.cell_can_accept(mixed_variants, &"textiles", small),
		"a cell accepts a second Small of the SAME category but a DIFFERENT variant",
	)

	_check_large_occupancy(grid)
	_check_lifo_by_record(grid)
	_check_apply_record_update(grid)
	_check_apply_record_update_large(grid)


## "A Large refuses when either half is occupied, for both orientations" and
## "placing a Large marks both halves occupied and clearing either half
## empties both" - modelled directly (Rack itself cannot be instantiated
## here), since add_large/remove_large's own logic is a handful of literal
## field assignments, not a decision worth its own StorageGrid function.
func _check_large_occupancy(grid: GDScript) -> void:
	print("[unit] a Large is one record across two self-describing cells")

	for orientation in [grid.Orientation.SIDE_BY_SIDE, grid.Orientation.FRONT_TO_BACK]:
		var empty_a := _fresh_cell()
		var empty_b := _fresh_cell()
		_expect(
			_cell_is_empty(empty_a) and _cell_is_empty(empty_b),
			"two fresh cells both start empty (orientation %d)" % orientation,
		)

		var occupied_a := _fresh_cell()
		_fill_small(occupied_a, &"masonry", 0)
		_expect(
			not (_cell_is_empty(occupied_a) and _cell_is_empty(empty_b)),
			"a Large refuses when its anchor half is occupied (orientation %d)" % orientation,
		)

		var occupied_b := _fresh_cell()
		_fill_small(occupied_b, &"masonry", 0)
		_expect(
			not (_cell_is_empty(empty_a) and _cell_is_empty(occupied_b)),
			"a Large refuses when its partner half is occupied (orientation %d)" % orientation,
		)

	for orientation in [grid.Orientation.SIDE_BY_SIDE, grid.Orientation.FRONT_TO_BACK]:
		var anchor := _fresh_cell()
		var partner := _fresh_cell()
		var record := _fresh_record(99, &"machine_parts", &"assorted_cogs", grid.SIZE_LARGE)
		_place_large(anchor, partner, record, orientation)

		_expect(not _cell_is_empty(anchor), "placing a Large occupies its anchor half (orientation %d)" % orientation)
		_expect(not _cell_is_empty(partner), "placing a Large occupies its partner half too (orientation %d)" % orientation)
		_expect(
			int((anchor["items"] as Array)[0]["id"]) == int((partner["items"] as Array)[0]["id"]),
			"both halves carry the SAME record id (orientation %d)" % orientation,
		)

		# Clearing via the PARTNER half - the harder direction, since the
		# anchor is where the record was written.
		_clear_large(partner, anchor)
		_expect(_cell_is_empty(anchor), "clearing the partner half empties the anchor too (orientation %d)" % orientation)
		_expect(_cell_is_empty(partner), "clearing the partner half empties itself (orientation %d)" % orientation)


## "Eight Smalls in, eight out, in exact reverse order, checked by record id" -
## proves records survive the stack rather than just counts matching.
func _check_lifo_by_record(grid: GDScript) -> void:
	print("[unit] LIFO survives whole records, not just counts")

	var cell := _fresh_cell()
	var fill_order: Array[int] = []
	for i in grid.SMALLS_PER_CELL:
		_fill_small(cell, &"tinned", 100 + i)
		fill_order.append(100 + i)

	var remove_order: Array[int] = []
	var items := cell["items"] as Array
	while not items.is_empty():
		var record: Dictionary = items.pop_back()
		remove_order.append(int(record["id"]))

	var expected := fill_order.duplicate()
	expected.reverse()
	_expect(
		remove_order == expected,
		"eight Smalls come out in exact reverse of fill order (got %s, want %s)" % [remove_order, expected],
	)


## "A record already in a cell can be edited in place" and the two refusal
## rules - against the REAL StorageGrid.cell_apply_record_update, not a
## reimplementation.
func _check_apply_record_update(grid: GDScript) -> void:
	print("[unit] apply_record_update edits a record already in a cell, in place")

	var cell := _fresh_cell()
	_fill_small(cell, &"glassware", 10, &"wine_glasses_nice")
	_fill_small(cell, &"glassware", 11, &"wine_glasses_hotel")
	_fill_small(cell, &"glassware", 12, &"novelty_snowglobes")

	var ok: bool = grid.cell_apply_record_update(cell, null, 11, {"store_until_day": 7})
	_expect(ok, "editing crate_11's store_until_day reports success")

	var items := cell["items"] as Array
	_expect(int(items[1]["store_until_day"]) == 7, "crate_11's own field actually changed")
	_expect(int(items[0]["store_until_day"]) == 1, "crate_10 is untouched")
	_expect(int(items[2]["store_until_day"]) == 1, "crate_12 is untouched")
	_expect(
		int(items[0]["id"]) == 10 and items[0]["variant"] == &"wine_glasses_nice",
		"crate_10's other fields are untouched",
	)

	var missing_id: bool = grid.cell_apply_record_update(cell, null, 999, {"store_until_day": 3})
	_expect(not missing_id, "updating an id the cell does not hold changes nothing and reports failure")
	_expect(int(items[1]["store_until_day"]) == 7, "the failed update on a missing id left the real record untouched")

	var bad_key: bool = grid.cell_apply_record_update(cell, null, 11, {"totally_made_up_field": 1})
	_expect(not bad_key, "updating an unknown field is refused rather than silently stored")
	_expect(not items[1].has("totally_made_up_field"), "the unknown field was never written")
	_expect(int(items[1]["store_until_day"]) == 7, "a refused update leaves every real field untouched too")


## "Editing either half of a Large changes both, and reading the record back
## from the partner returns the edited value" - the assertion that makes
## apply_record_update safe for a caller that does not know a Large exists.
func _check_apply_record_update_large(grid: GDScript) -> void:
	print("[unit] editing either half of a Large edits both")

	var anchor := _fresh_cell()
	var partner := _fresh_cell()
	var record := _fresh_record(55, &"white_goods", &"mini_fridges", grid.SIZE_LARGE)
	_place_large(anchor, partner, record, grid.Orientation.SIDE_BY_SIDE)

	# Editing through the ANCHOR half - the partner's own copy must pick it up.
	var ok_a: bool = grid.cell_apply_record_update(anchor, partner, 55, {"store_until_day": 9})
	_expect(ok_a, "editing crate_55 via the anchor half reports success")
	_expect(
		int((partner["items"] as Array)[0]["store_until_day"]) == 9,
		"the partner's own copy picked up the anchor's edit",
	)

	# Editing through the PARTNER half - the harder direction, since callers
	# naturally think of the anchor as "the" record.
	var ok_b: bool = grid.cell_apply_record_update(partner, anchor, 55, {"store_until_day": 14})
	_expect(ok_b, "editing crate_55 via the partner half reports success")
	_expect(
		int((anchor["items"] as Array)[0]["store_until_day"]) == 14,
		"the anchor's own copy picked up the partner's edit",
	)


# ------------------------------------------------------ occupancy helpers
#
# A plain dictionary shaped exactly like one entry of Rack's own _cells array
# - see rack.gd's class doc for the authoritative shape. Building and mutating
# these directly (rather than through Rack, which cannot exist here) is
# "arrange", not "the logic under test" - the logic under test is
# StorageGrid.cell_can_accept / cell_apply_record_update, both called for
# real above.

func _fresh_cell() -> Dictionary:
	return {"category": &"", "items": [], "size": 0, "partner": -1, "anchor": false, "orientation": 0}


func _cell_is_empty(cell: Dictionary) -> bool:
	return (cell["items"] as Array).is_empty()


## A CargoRecord.to_dict()-shaped dictionary, hand-built rather than by
## loading CargoRecord itself, so this file keeps the same zero-dependency
## posture StorageGrid's own doc comment insists on.
func _fresh_record(id: int, category: StringName, variant: StringName, size: int) -> Dictionary:
	return {
		"id": id,
		"category": category,
		"variant": variant,
		"size": size,
		"fragility": 0,
		"mass": 5.0,
		"declared_value": 10.0,
		"store_until_day": 1,
		"owner": &"test_client",
		"condition_actual": 0,
		"condition_apparent": 0,
		"drag_distance": 0.0,
	}


func _fill_small(cell: Dictionary, category: StringName, id: int, variant: StringName = &"") -> void:
	var record := _fresh_record(id, category, variant, 0)
	var items := cell["items"] as Array
	if items.is_empty():
		cell["category"] = category
		cell["size"] = 0
	items.append(record)


func _fill_medium(cell: Dictionary, category: StringName) -> void:
	cell["category"] = category
	cell["size"] = 1
	(cell["items"] as Array).append(_fresh_record(0, category, &"", 1))


func _place_large(anchor: Dictionary, partner: Dictionary, record: Dictionary, orientation: int) -> void:
	anchor["category"] = record["category"]
	anchor["items"] = [record.duplicate(true)]
	anchor["size"] = record["size"]
	anchor["partner"] = 1
	anchor["anchor"] = true
	anchor["orientation"] = orientation

	partner["category"] = record["category"]
	partner["items"] = [record.duplicate(true)]
	partner["size"] = record["size"]
	partner["partner"] = 0
	partner["anchor"] = false
	partner["orientation"] = orientation


func _clear_large(cell: Dictionary, other: Dictionary) -> void:
	for target in [cell, other]:
		target["category"] = &""
		target["items"] = []
		target["size"] = 0
		target["partner"] = -1
		target["anchor"] = false


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
