class_name Carrier
extends Node

## The local player's hands. Asks the host to pick cargo up and put it down, and
## decides nothing itself (ADR 7).
##
## Only the peer that owns this capsule takes input here. Everyone else's carrier
## is inert — their holds arrive as replicated state on the crate instead.

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


## Grab whatever we are aiming at, or put down what we are holding.
##
## [param want_drag] asks the host for a drag rather than a carry. It is a
## request: the host drags anything too heavy to lift whether or not it was
## asked, and a second holder lifts regardless. Either key puts down what you are
## already holding, so a drag never traps you in the wrong mode.
##
## Public so the integration harness drives exactly the path a keypress does. A
## test that called the referee directly would pass with a completely broken aim
## ray — which is precisely the bug that shipped and had to be found by hand.
func try_toggle_hold(want_drag := false) -> void:
	var referee := _authority()
	if referee == null:
		return

	if _held != null:
		if Net.is_host():
			referee.request_release()
		else:
			referee.request_release.rpc_id(1)
		return

	var crate := _aimed_crate()
	if crate == null:
		return
	if Net.is_host():
		referee.request_grab(crate.name, want_drag)
	else:
		referee.request_grab.rpc_id(1, crate.name, want_drag)


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


func _aimed_crate() -> Crate:
	_ray.force_raycast_update()
	if not _ray.is_colliding():
		return null
	return _ray.get_collider() as Crate


func _authority() -> CarryAuthority:
	return get_tree().get_first_node_in_group("carry_authority") as CarryAuthority
