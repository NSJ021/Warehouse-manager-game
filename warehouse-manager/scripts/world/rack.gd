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
@onready var _cell_highlight: MeshInstance3D = $CellHighlight


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
func show_highlight(cell_index: int, state: Highlight) -> void:
	if state == Highlight.NONE or cell_index < 0 or cell_index >= StorageGrid.cell_count():
		hide_highlight()
		return

	_cell_highlight.position = cell_to_local_position(cell_index)
	var colour := highlight_actionable if state == Highlight.ACTIONABLE else highlight_blocked
	var material := _cell_highlight.material_override as StandardMaterial3D
	material.albedo_color = Color(colour.r, colour.g, colour.b, material.albedo_color.a)
	material.emission = colour
	_cell_highlight.visible = true


func hide_highlight() -> void:
	_cell_highlight.visible = false


# ---------------------------------------------------------------- occupancy

func occupied_count(cell: int) -> int:
	return _ids(cell).size()


## The crate id on top of the cell's stack, -1 when empty. An id rather than a
## kind, both so "occupied" and "empty" are one comparison apart, and so LIFO
## order is something a caller outside this file can actually check.
##
## -1 rather than 0: crate ids are minted from 0 (see
## [code]TestRoom._next_crate_id[/code]), so 0 is a real crate, not "nothing
## here". StorageGrid's own convention for "no answer" is -1 — this follows it.
func occupant(cell: int) -> int:
	var ids := _ids(cell)
	return ids.back() if not ids.is_empty() else -1


func cell_kind(cell: int) -> StringName:
	return _cells[cell]["kind"]


func is_cell_empty(cell: int) -> bool:
	return occupied_count(cell) == 0


## True when every cell is empty. Late-joiner sync (01-04) reads this to skip
## sending a snapshot for a rack that has nothing in it yet.
func is_empty() -> bool:
	for cell in _cells:
		if not (cell["ids"] as Array).is_empty():
			return false
	return true


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
# host-authoritative RPC calls on every peer, host included via call_local.
# They own the state change *and* the visual it produces: a fly-in tween and
# a thud for a placement (01-06), an instant removal for a retrieval. Nothing
# outside this file should call the inner pair.

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


## Pops the top id and returns it — LIFO — or -1 if the cell was already
## empty. See the note on [method occupant] for why -1 rather than 0.
func remove_from_cell(cell: int) -> int:
	var data := _cells[cell]
	var ids := data["ids"] as Array
	if ids.is_empty():
		return -1
	var crate_id: int = ids.pop_back()
	if ids.is_empty():
		data["kind"] = &""
	return crate_id


## Wraps [method add_to_cell] and grows that cell's visuals by exactly the one
## item that just arrived — the others, already in place, are untouched.
## Phase 1's only kind is [constant Crate.KIND_SMALL] — fixed here rather than
## taken as a parameter, because there is nothing else to pass yet (see the
## class doc). [param from_position] is where the crate travelled from; see
## [method _spawn_cell_visual] for what [constant Vector3.ZERO] means there.
func apply_cell_filled(cell: int, crate_id: int, from_position: Vector3) -> void:
	var sub_index := add_to_cell(cell, Crate.KIND_SMALL, crate_id)
	if sub_index == -1:
		return
	_spawn_cell_visual(cell, sub_index, from_position)


## Wraps [method remove_from_cell] and frees exactly the one visual that was
## on top. LIFO means it is always the highest sub-index this cell currently
## holds, so nothing below it needs to move or even be looked at.
func apply_cell_cleared(cell: int) -> void:
	var top_index := occupied_count(cell) - 1
	remove_from_cell(cell)
	if top_index >= 0:
		_free_cell_visual(cell, top_index)


## Replaces this rack's occupancy wholesale and rebuilds every cell's visuals
## from it, instantly and silently — the late-joiner path (01-04). A peer that
## was not present for earlier placements has to be brought up to date in one
## shot rather than by replaying every [method apply_cell_filled] since the
## rack was last empty, which is exactly the case [method _spawn_cell_visual]'s
## [constant Vector3.ZERO] sentinel exists for: this rack's *existing* contents
## should appear, not fly in from the world origin with a thud each. Duplicated
## on the way in for the same reason [method occupancy_snapshot] duplicates on
## the way out: this rack's state must not alias the dictionary the caller
## handed over.
func apply_occupancy_snapshot(snapshot: Array) -> void:
	for cell in snapshot.size():
		var data := snapshot[cell] as Dictionary
		_cells[cell] = {
			"kind": data.get("kind", &""),
			"ids": (data.get("ids", []) as Array).duplicate(),
		}
		_clear_cell_visuals(cell)
		var ids := _ids(cell)
		for i in ids.size():
			_spawn_cell_visual(cell, i, Vector3.ZERO)


# ---------------------------------------------------------------- visuals

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
func _spawn_cell_visual(cell: int, sub_index: int, from_position: Vector3) -> void:
	var item := RACKED_ITEM_SCENE.instantiate() as Node3D
	item.name = "Cell%d_Item%d" % [cell, sub_index]
	var target := StorageGrid.cell_centre(cell) + StorageGrid.small_offset(sub_index)

	if from_position == Vector3.ZERO:
		item.position = target
		_racked_items.add_child(item)
		return

	# Both ends of the travel are in the rack's own local space — mixing a
	# global start with a local target is a bug that only shows up once a
	# rack is rotated. Neither fixture in test_room.tscn is rotated today,
	# so this would pass silently without the local conversion above.
	item.position = to_local(from_position)
	_racked_items.add_child(item)

	var sound := item.get_node_or_null("PlaceSound") as AudioStreamPlayer3D
	if sound != null:
		sound.play()

	# bind_node ties the tween's lifetime to the item: apply_cell_cleared can
	# free this same node before the travel finishes (a cell filled and
	# immediately retrieved again), and without this the tween would go on
	# trying to write "position" on a freed instance next frame.
	var tween := create_tween().bind_node(item)
	tween.set_parallel(true)
	tween.tween_property(item, "position", target, snap_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	item.scale = Vector3(1.06, 1.06, 1.06)
	tween.tween_property(item, "scale", Vector3.ONE, snap_time) \
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


func _ids(cell: int) -> Array:
	return _cells[cell]["ids"] as Array
