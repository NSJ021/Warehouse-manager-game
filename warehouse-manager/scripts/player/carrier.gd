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

var _held: Crate = null
## What the host says this hold is. Only meaningful while [member _held] is set.
## The host owns this decision and can change it mid-carry, so it is stored rather
## than recomputed — a client guessing from mass would disagree the moment a mate
## grabbed the other end.
var _hold_mode := Crate.HoldMode.CARRY

@onready var _player: Player = get_parent() as Player
@onready var _ray: RayCast3D = get_node("../CameraPivot/GrabRay")


func _ready() -> void:
	if not _player.is_multiplayer_authority():
		set_process_unhandled_input(false)
		return
	# So the HUD can find whose hands these are without knowing the level layout.
	add_to_group("local_carrier")
	# The ray starts inside our own capsule, so it has to be told to ignore it.
	_ray.add_exception(_player)


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


## Holding something and aiming at a rack cell. Two rows of the branch table
## live here, both "refuse, do not drop":
##
## - **Full or wrong-kind cell.** A player pressing E while pointing at a full
##   cell is trying to store something, and dropping their crate on the floor
##   would be the least helpful possible response. To drop deliberately, look
##   away from the rack. Plan 01-06 makes this legible with a red highlight;
##   the intent is recorded here so the two plans agree.
## - **⚠ Dragging above floor level (ADR 19).** Added 2026-08-19, after this
##   plan was first written, and not decoration: 01-06 copies this table
##   verbatim to decide the cell highlight, so leaving this row out would let
##   a dragging player see a top-row cell painted invitingly and then have the
##   host silently refuse the placement anyway. This is a local pre-check —
##   feedback, not authority. The host re-validates everything in
##   request_place and simply refuses if this client ever disagrees with it.
func _try_place(referee: CarryAuthority, aim: AimResult) -> void:
	# crate.hold_mode() is readable locally on the held crate, so this costs
	# nothing extra to ask. Floor level is level 0 — StorageGrid.cell_coords()
	# returns (column, depth, level), so it is .z, not .y, that means level.
	var floor_level := StorageGrid.cell_coords(aim.cell_index).z == 0
	if is_dragging() and not floor_level:
		return
	if not aim.rack.can_accept(aim.cell_index, _held.kind):
		return

	if Net.is_host():
		referee.request_place(aim.rack.name, aim.cell_index)
	else:
		referee.request_place.rpc_id(1, aim.rack.name, aim.cell_index)


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


## One raycast, two kinds of target. Replaces the old crate-only
## [code]_aimed_crate()[/code]: there is only ever one thing a player can be
## aiming at, so a second ray for storage would duplicate the exception
## bookkeeping above for no benefit.
func _aim() -> AimResult:
	var result := AimResult.new()
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
	result.cell_index = rack.cell_at_point(_ray.get_collision_point())
	return result


func _authority() -> CarryAuthority:
	return get_tree().get_first_node_in_group("carry_authority") as CarryAuthority
