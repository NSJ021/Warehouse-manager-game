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
## test can see it.

const RACKED_ITEM_SCENE := preload("res://scenes/goods/racked_item.tscn")

## One entry per cell: `{ "kind": StringName, "ids": Array[int] }`. `ids` is a
## stack, last in first out, so [method occupied_count] is just its size and
## the two can never disagree. `kind` is `&""` when the cell is empty.
##
## Phase 1 has exactly one cargo size ([constant Crate.KIND_SMALL]), but the
## shape already records a kind as well as a count so Phase 2's Medium and
## Large can arrive without reshaping this file. Nothing here builds toward
## them yet.
var _cells: Array[Dictionary] = []

@onready var _racked_items: Node3D = $RackedItems


func _ready() -> void:
	_cells.resize(StorageGrid.cell_count())
	for i in _cells.size():
		_cells[i] = { "kind": &"", "ids": [] }
	add_to_group("racks")


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


## Global position of one Small's own sub-position within a cell — the single
## place [method StorageGrid.cell_centre] and [method StorageGrid.small_offset]
## are combined, so no caller repeats the sum.
func small_global_position(cell: int, sub_index: int) -> Vector3:
	var local_position := StorageGrid.cell_centre(cell) + StorageGrid.small_offset(sub_index)
	return global_transform * local_position


# ---------------------------------------------------------------- occupancy

func occupied_count(cell: int) -> int:
	return _ids(cell).size()


## The crate id on top of the cell's stack, 0 when empty. An id rather than a
## kind, both so "occupied" and "empty" are one comparison apart, and so LIFO
## order is something a caller outside this file can actually check.
func occupant(cell: int) -> int:
	var ids := _ids(cell)
	return ids.back() if not ids.is_empty() else 0


func cell_kind(cell: int) -> StringName:
	return _cells[cell]["kind"]


func is_cell_empty(cell: int) -> bool:
	return occupied_count(cell) == 0


## 01-07's shed reads this. The top level is the one nothing reaches except by
## having been racked up there in the first place.
func occupied_cells_in_top_row() -> Array[int]:
	var top_level := StorageGrid.RACK_LEVELS - 1
	var found: Array[int] = []
	for cell in _cells.size():
		if StorageGrid.cell_coords(cell).z == top_level and not is_cell_empty(cell):
			found.append(cell)
	return found


## The whole rack's state in one value, so a late joiner can be brought up to
## date — without this, "every peer agrees" would only be true for peers
## present at the moment a cell last changed. Duplicated on the way out, so a
## caller mutating what it was handed cannot mutate this rack's real state.
func occupancy_snapshot() -> Array:
	var snapshot: Array = []
	for cell in _cells:
		snapshot.append({ "kind": cell["kind"], "ids": (cell["ids"] as Array).duplicate() })
	return snapshot


# ---------------------------------------------------------------- mutation
#
# add_to_cell / remove_from_cell are the state change. apply_cell_filled /
# apply_cell_cleared are the broadcast entry points — what 01-04's
# host-authoritative RPC calls on every peer, host included via call_local,
# and what 01-06 later extends with a tween. They own the state change *and*
# the visual rebuild. Nothing outside this file should call the inner pair.

## False when the cell is full, and false when it already holds a different
## kind — that second clause is atomicity (ADR 18), the rule that makes
## spending a cell on the wrong thing sting.
func can_accept(cell: int, kind: StringName) -> bool:
	var data := _cells[cell]
	var ids := data["ids"] as Array
	if ids.size() >= StorageGrid.SMALLS_PER_CELL:
		return false
	if not ids.is_empty() and data["kind"] != kind:
		return false
	return true


## Pushes the id, returns the sub-position filled ([method StorageGrid.next_fill_index]),
## or -1 if the cell has no room. Does not itself enforce atomicity — callers
## check [method can_accept] first; that is where the rule lives.
func add_to_cell(cell: int, kind: StringName, crate_id: int) -> int:
	var data := _cells[cell]
	var ids := data["ids"] as Array
	var sub_index := StorageGrid.next_fill_index(ids.size())
	if sub_index == -1:
		return -1
	if ids.is_empty():
		data["kind"] = kind
	ids.append(crate_id)
	return sub_index


## Pops the top id and returns it — LIFO — or 0 if the cell was already empty.
func remove_from_cell(cell: int) -> int:
	var data := _cells[cell]
	var ids := data["ids"] as Array
	if ids.is_empty():
		return 0
	var crate_id: int = ids.pop_back()
	if ids.is_empty():
		data["kind"] = &""
	return crate_id


## Wraps [method add_to_cell] and rebuilds that cell's visuals. Phase 1's only
## kind is [constant Crate.KIND_SMALL] — fixed here rather than taken as a
## parameter, because there is nothing else to pass yet (see the class doc).
## [param from_position] is where the crate came from, carried so 01-06 can
## animate the travel; this file stores nothing from it.
func apply_cell_filled(cell: int, crate_id: int, _from_position: Vector3) -> void:
	add_to_cell(cell, Crate.KIND_SMALL, crate_id)
	_rebuild_cell_visuals(cell)


## Wraps [method remove_from_cell] and rebuilds that cell's visuals.
func apply_cell_cleared(cell: int) -> void:
	remove_from_cell(cell)
	_rebuild_cell_visuals(cell)


# ---------------------------------------------------------------- visuals

## Derived, never replicated (see class doc). Every peer runs this from its
## own copy of the occupancy state, so the meshes are a consequence of that
## state rather than a second copy of it that can disagree.
func _rebuild_cell_visuals(cell: int) -> void:
	_clear_cell_visuals(cell)
	var ids := _ids(cell)
	for i in ids.size():
		var item := RACKED_ITEM_SCENE.instantiate() as Node3D
		item.name = "Cell%d_Item%d" % [cell, i]
		item.position = StorageGrid.cell_centre(cell) + StorageGrid.small_offset(i)
		_racked_items.add_child(item)


func _clear_cell_visuals(cell: int) -> void:
	var prefix := "Cell%d_Item" % cell
	for child in _racked_items.get_children():
		if String(child.name).begins_with(prefix):
			child.queue_free()


func _ids(cell: int) -> Array:
	return _cells[cell]["ids"] as Array
