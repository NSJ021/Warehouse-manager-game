class_name Carrier
extends Node

## The local player's hands. Asks the host to pick cargo up, put it down, rack
## it, or take it back out, and decides nothing itself (ADR 7).
##
## Only the peer that owns this capsule takes input here. Everyone else's carrier
## is inert — their holds arrive as replicated state on the crate instead.

## What one aim resolves to: either a loose crate, or a rack cell (occupied
## or not) — never both. [member cell_index] is only meaningful when
## [member rack] is set.
class AimResult:
	var crate: Crate = null
	var rack: Rack = null
	var cell_index := -1

## How far past a raycast's own collision point to nudge before resolving a
## cell from it. Not cosmetic: a ray's collision point sits exactly ON the
## surface it hit, by definition — and for the outermost reachable row of any
## rack, that surface exactly coincides with the rack's own outer boundary.
## StorageGrid.cell_index_at()'s half-open rule deliberately excludes that
## boundary (built for resolving where a body's *centre* sits, where "exactly
## on the surface" should read as outside) — so an un-nudged point resolves
## every straight-on aim at a rack to -1, unconditionally, for every rack.
## Small next to a 1 m cell; found by 01-04's integration test timing out
## solid rather than by reasoning about it in advance.
const CELL_RESOLVE_NUDGE := 0.01

## Cargo's own collision layer (project.godot layer_3, "cargo") — see
## [member Crate.collision_layer]. Used to run a cargo-only raycast ahead of
## the combined one below.
const CARGO_LAYER_MASK := 4

var _held: Crate = null
## What the host says this hold is. Only meaningful while [member _held] is set.
## The host owns this decision and can change it mid-carry, so it is stored rather
## than recomputed — a client guessing from mass would disagree the moment a mate
## grabbed the other end.
var _hold_mode := Crate.HoldMode.CARRY
## The rack currently showing a highlight because of this carrier's aim, or
## null. Tracked so a highlight can be hidden the instant the aim leaves it —
## without this, walking away from a rack strands a lit cell behind you.
var _highlighted_rack: Rack = null

@onready var _player: Player = get_parent() as Player
@onready var _ray: RayCast3D = get_node("../CameraPivot/GrabRay")


func _ready() -> void:
	if not _player.is_multiplayer_authority():
		set_process_unhandled_input(false)
		# Aim feedback is local-only presentation (01-06): only the peer whose
		# hands these are should pay for a raycast every frame. Everyone
		# else's copy of this node does nothing at all.
		set_process(false)
		return
	# So the HUD can find whose hands these are without knowing the level layout.
	add_to_group("local_carrier")
	# The ray starts inside our own capsule, so it has to be told to ignore it.
	_ray.add_exception(_player)


## Paints the cell we are aiming at, if any, using the exact same aim query
## and branch rules [method try_toggle_hold] acts on — see
## [method _highlight_state] for the table both follow. Local-only: see the
## class doc and [method Rack.show_highlight] for why this is never
## replicated.
func _process(_delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_hide_current_highlight()
		return

	var aim := _aim()
	if aim.rack != _highlighted_rack:
		_hide_current_highlight()

	if aim.rack == null:
		return

	aim.rack.show_highlight(aim.cell_index, _highlight_state(aim))
	_highlighted_rack = aim.rack


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event.is_action_pressed("interact"):
		try_toggle_hold()
	elif event.is_action_pressed("drag"):
		try_toggle_hold(true)


## Grab whatever we are aiming at, store what we are holding into a rack cell,
## take a cell's contents into our hands, or put down what we are already
## holding. One keypress, six possible outcomes — see the branch table on
## [method _resolve_action] for the full table this follows.
##
## [param want_drag] asks the host for a drag rather than a carry when
## grabbing loose cargo. It is a request: the host drags anything too heavy
## to lift whether or not it was asked, and a second holder lifts regardless.
## Placing and retrieving ignore it — there is nothing to negotiate about a
## rack cell.
##
## Public so the integration harness drives exactly the path a keypress does. A
## test that called the referee directly would pass with a completely broken aim
## ray — which is precisely the bug that shipped and had to be found by hand.
func try_toggle_hold(want_drag := false) -> void:
	var referee := _authority()
	if referee == null:
		return

	var aim := _aim()

	if _held != null:
		if aim.rack != null:
			_try_place(referee, aim)
		else:
			# Holding | anything else -> release, unchanged from Phase 0.
			if Net.is_host():
				referee.request_release()
			else:
				referee.request_release.rpc_id(1)
		return

	if aim.crate != null:
		# No hold | a loose Crate -> grab.
		if Net.is_host():
			referee.request_grab(aim.crate.name, want_drag)
		else:
			referee.request_grab.rpc_id(1, aim.crate.name, want_drag)
		return

	if aim.rack != null and not aim.rack.is_cell_empty(aim.cell_index):
		# No hold | cell holding anything -> retrieve.
		if Net.is_host():
			referee.request_retrieve(aim.rack.name, aim.cell_index)
		else:
			referee.request_retrieve.rpc_id(1, aim.rack.name, aim.cell_index)
	# No hold | empty cell / nothing -> do nothing.


## Holding something and aiming at a rack cell. Two rows of a branch table
## live here — both "refuse, do not drop" — extracted into
## [method _placement_allowed] so [method try_toggle_hold]'s actual press and
## [method _highlight_state]'s prediction of it are the exact same function
## call rather than two hand-written copies of the same rule (02-06; see that
## method's own doc comment for why this stopped being optional):
##
## - **Full or wrong-category cell.** A player pressing E while pointing at a
##   full cell is trying to store something, and dropping their crate on the
##   floor would be the least helpful possible response. To drop deliberately,
##   look away from the rack. Plan 01-06 makes this legible with a red
##   highlight; the intent is recorded here so the two plans agree.
## - **⚠ Dragging above floor level (ADR 19).** Added 2026-08-19, after this
##   plan was first written, and not decoration: 01-06 copies this table
##   verbatim to decide the cell highlight, so leaving this row out would let
##   a dragging player see a top-row cell painted invitingly and then have the
##   host silently refuse the placement anyway. This is a local pre-check —
##   feedback, not authority. The host re-validates everything in
##   request_place and simply refuses if this client ever disagrees with it.
func _try_place(referee: CarryAuthority, aim: AimResult) -> void:
	if not _placement_allowed(aim):
		return

	if Net.is_host():
		referee.request_place(aim.rack.name, aim.cell_index)
	else:
		referee.request_place.rpc_id(1, aim.rack.name, aim.cell_index)


## Whether placing [member _held] into [param aim]'s cell would succeed —
## the single predicate [method _try_place] acts on and [method
## _highlight_state] paints, so the two can never quietly drift apart (the
## exact failure the 01-06 audit found once, before this extraction existed).
## Only meaningful while [member _held] is set; callers with an empty hand
## have nothing to place and should not call this.
##
## - Floor level is level 0 — [method StorageGrid.cell_coords] returns
##   (column, depth, level), so it is [code].z[/code], not [code].y[/code],
##   that means level.
## - [code].size[/code] travels alongside [code].kind[/code] (02-05):
##   [method Rack.can_accept] grew a third argument so a Medium is never
##   silently treated as a Small. A Large still cannot reach this function at
##   all — nothing here chooses an orientation or calls
##   [method Rack.can_accept_large] (02-07/02-08).
func _placement_allowed(aim: AimResult) -> bool:
	var floor_level := StorageGrid.cell_coords(aim.cell_index).z == 0
	if is_dragging() and not floor_level:
		return false
	return aim.rack.can_accept(aim.cell_index, _held.kind, _held.size)


## What [method _process] should paint for the cell [param aim] is currently
## resolved to — [method _placement_allowed] itself, expressed as "what to
## show" instead of "what to do". Only called with [param aim].rack already
## non-null.
func _highlight_state(aim: AimResult) -> Rack.Highlight:
	# Guards the same out-of-range case show_highlight() itself guards -
	# belt and braces, since Array's negative-index wraparound would
	# otherwise read the wrong cell's occupancy instead of failing loudly.
	if aim.cell_index < 0 or aim.cell_index >= StorageGrid.cell_count():
		return Rack.Highlight.NONE

	if _held != null:
		return Rack.Highlight.ACTIONABLE if _placement_allowed(aim) else Rack.Highlight.BLOCKED

	if aim.rack.is_cell_empty(aim.cell_index):
		# Empty and no hold: nothing would happen either way. Painting every
		# empty cell in a rack while simply walking past it would be noise,
		# not feedback.
		return Rack.Highlight.NONE
	return Rack.Highlight.ACTIONABLE


## Hides whatever rack [member _highlighted_rack] currently is, if any, and
## forgets it. Called whenever the aim moves to a different rack (including
## none at all) so a highlight is never left glowing behind the player.
func _hide_current_highlight() -> void:
	if _highlighted_rack != null:
		_highlighted_rack.hide_highlight()
		_highlighted_rack = null


## Called by the host's referee once it has decided. Not a request — a verdict.
func on_hold_granted(crate: Crate, mode := Crate.HoldMode.CARRY) -> void:
	_held = crate
	_hold_mode = mode
	if crate != null:
		# What you are holding rides directly in front of the camera, so without
		# this the ray only ever hits your own crate and you can never aim at
		# anything past it. Harmless while E just drops it; fatal in Phase 1,
		# where you have to aim at a rack slot with a crate in your hands.
		_ray.add_exception(crate)


func on_hold_released() -> void:
	if _held != null:
		_ray.remove_exception(_held)
	_held = null
	_hold_mode = Crate.HoldMode.CARRY


## The host has changed what this hold is without us asking — someone grabbed the
## other end of what we were dragging, or let go of what we were carrying.
func on_hold_mode_changed(mode: Crate.HoldMode) -> void:
	_hold_mode = mode


func held_crate() -> Crate:
	return _held


## Whether this player is hauling something along the floor rather than carrying
## it. Read by [Player] to apply the drag speed penalty, which has to happen here
## because movement is client-authoritative and the host cannot slow anyone down.
func is_dragging() -> bool:
	return _held != null and _hold_mode == Crate.HoldMode.DRAG


## What to multiply walk speed by right now. 1.0 unless dragging. Taken from the
## crate rather than a constant so the penalty stays tunable in the inspector
## alongside every other feel value.
func speed_scale() -> float:
	return _held.drag_speed_scale if is_dragging() else 1.0


## One raycast, two kinds of target — plus, when empty-handed, a second
## cargo-only probe run first. Replaces the old crate-only
## [code]_aimed_crate()[/code]: there is only ever one thing a player can be
## aiming at, so a second ray for storage would duplicate the exception
## bookkeeping above for no benefit.
##
## ⚠ The empty-handed cargo probe is load-bearing, not an optimisation. A
## loose crate that has come to rest [i]inside[/i] a rack's [code]CellSensor[/code]
## volume (a shed lands there; found live twice at the wave 7 gate,
## 2026-08-21) is otherwise permanently unaimable: the combined ray below hits
## the sensor's own surface — an [Area3D] — before it ever reaches the
## crate's physical box behind it, resolves to that cell, finds the cell's
## data empty, and [method try_toggle_hold] does nothing. Supply conservation
## does not save it either — [member Crate._recover] only fires below the
## world, and this crate never left it. The cargo-only probe ignores the
## storage layer entirely, so it sees straight through the sensor to the
## crate behind it.
func _aim() -> AimResult:
	var result := AimResult.new()

	if _held == null:
		var loose_crate := _aim_loose_crate()
		if loose_crate != null:
			result.crate = loose_crate
			return result

	_ray.force_raycast_update()
	if not _ray.is_colliding():
		return result

	var collider := _ray.get_collider()
	var as_crate := collider as Crate
	if as_crate != null:
		result.crate = as_crate
		return result

	# A RayCast3D that hits an Area3D returns the area, never its parent — so
	# CellSensor being a direct child of the rack root is what makes this one
	# get_parent() resolve to the Rack (see rack.tscn's CellSensor0 for the
	# same note from the other side).
	var rack := (collider as Node).get_parent() as Rack
	if rack == null:
		return result
	result.rack = rack

	# Nudged past the surface before resolving — see CELL_RESOLVE_NUDGE.
	var hit := _ray.get_collision_point()
	var into := (hit - _ray.global_position).normalized() * CELL_RESOLVE_NUDGE
	result.cell_index = rack.cell_at_point(hit + into)
	return result


## The cargo-only probe [method _aim] runs before the combined ray, and only
## while empty-handed — holding something must still resolve cells first, or
## a loose crate sitting in front of a rack face would hijack a placement aim
## (see [method _aim]'s own doc comment). Same origin and length as
## [member _ray]'s own [member RayCast3D.target_position], but queried
## directly against the physics space with [constant CARGO_LAYER_MASK] rather
## than through the RayCast3D node, so the storage layer never enters into it
## at all — the sensor is not merely deprioritised, it is invisible to this
## query.
func _aim_loose_crate() -> Crate:
	var space_state := _player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		_ray.global_position, _ray.to_global(_ray.target_position))
	query.collision_mask = CARGO_LAYER_MASK
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.hit_from_inside = true
	query.exclude = [_player.get_rid()]

	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	return hit.get("collider") as Crate


func _authority() -> CarryAuthority:
	return get_tree().get_first_node_in_group("carry_authority") as CarryAuthority
