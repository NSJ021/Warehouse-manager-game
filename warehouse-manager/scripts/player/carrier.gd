class_name Carrier
extends Node

## The local player's hands. Asks the host to pick cargo up and put it down, and
## decides nothing itself (ADR 7).
##
## Only the peer that owns this capsule takes input here. Everyone else's carrier
## is inert — their holds arrive as replicated state on the crate instead.

var _held: Crate = null

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


## Grab whatever we are aiming at, or put down what we are holding.
##
## Public so the integration harness drives exactly the path a keypress does. A
## test that called the referee directly would pass with a completely broken aim
## ray — which is precisely the bug that shipped and had to be found by hand.
func try_toggle_hold() -> void:
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
		referee.request_grab(crate.name)
	else:
		referee.request_grab.rpc_id(1, crate.name)


## Called by the host's referee once it has decided. Not a request — a verdict.
func on_hold_granted(crate: Crate) -> void:
	_held = crate
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


func held_crate() -> Crate:
	return _held


func _aimed_crate() -> Crate:
	_ray.force_raycast_update()
	if not _ray.is_colliding():
		return null
	return _ray.get_collider() as Crate


func _authority() -> CarryAuthority:
	return get_tree().get_first_node_in_group("carry_authority") as CarryAuthority
