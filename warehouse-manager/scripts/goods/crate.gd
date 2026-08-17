class_name Crate
extends RigidBody3D

## Physics cargo. The host simulates it; every client sees a frozen kinematic
## puppet eased toward the host's replicated transform.
##
## Held crates are force-driven and never parented (ADR 13). The host pulls the
## body toward a hold point in front of each holder with a spring-damper, so the
## crate keeps colliding with the world for real, sags under its own weight, and
## renders its own latency as mass rather than as error.
##
## Only the host runs [method _physics_process]. If clients simulated locally
## they would fight the host and drift, so they are frozen and posed from
## [member sync_position] / [member sync_basis] instead.

## The host has taken this crate off a holder because it was dragged past
## [constant BREAK_DISTANCE], or because the holder vanished mid-carry.
signal hold_broken(peer_id: int)

## Pull toward the hold point. Stiffness against crate mass is what sets the
## sag, and the sag is deliberate feedback about weight (ADR 13) — it is not a
## bug to be tuned out.
const HOLD_STIFFNESS := 1500.0
const HOLD_DAMPING := 250.0
## Load-bearing rather than a nicety: a spring whose force outruns the solver is
## exactly how this becomes a jitter bug.
const MAX_HOLD_FORCE := 4000.0
## Keeps the crate upright and facing the holder, so labels stay readable once
## there are labels to read (Phase 2).
const ALIGN_STIFFNESS := 45.0
const ALIGN_DAMPING := 9.0
const MAX_ALIGN_TORQUE := 180.0
## Walk into a wall with a crate and you lose it.
const BREAK_DISTANCE := 2.0
## Two holders are steadier, not twice as violent (ADR 13).
const EXTRA_HOLDER_DAMPING := 0.5
## Two is the ceiling by design — two-player carry, not four (GDD §6.1).
const MAX_HOLDERS := 2
## How fast a client puppet catches up to the host's last known transform.
const PUPPET_SMOOTHING := 20.0
## Below this the rotation error is noise, and asking a near-identity quaternion
## for its axis divides by roughly zero.
const MIN_ALIGN_ANGLE := 0.001

## Replicated by the MultiplayerSynchronizer. Written only by the host.
var sync_position := Vector3.ZERO
var sync_basis := Quaternion.IDENTITY

## peer_id -> that holder's hold-point node. Host-only, and never replicated: a
## node reference means nothing on another machine.
var _hold_targets: Dictionary = {}


func _enter_tree() -> void:
	# Cargo is host-owned, always. Clients ask; the host decides (ADR 7).
	set_multiplayer_authority(1)


func _ready() -> void:
	if Net.is_host():
		set_process(false)
		return
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if not _hold_targets.is_empty():
		_apply_hold_forces()
	sync_position = global_position
	sync_basis = global_transform.basis.get_rotation_quaternion()


func _process(delta: float) -> void:
	var weight := clampf(PUPPET_SMOOTHING * delta, 0.0, 1.0)
	var eased_position := global_position.lerp(sync_position, weight)
	var eased_basis := global_transform.basis.get_rotation_quaternion().slerp(sync_basis, weight)
	global_transform = Transform3D(Basis(eased_basis), eased_position)


## Host-only. Returns false if this crate is full or the peer already has it.
func add_holder(peer_id: int, hold_target: Node3D) -> bool:
	if _hold_targets.size() >= MAX_HOLDERS or _hold_targets.has(peer_id):
		return false
	_hold_targets[peer_id] = hold_target
	# A held body is awake by definition — letting it sleep would strand it in
	# mid-air the moment the spring settled.
	can_sleep = false
	return true


## Host-only.
func remove_holder(peer_id: int) -> void:
	_hold_targets.erase(peer_id)
	if _hold_targets.is_empty():
		can_sleep = true


func holder_count() -> int:
	return _hold_targets.size()


func is_held_by(peer_id: int) -> bool:
	return _hold_targets.has(peer_id)


## Called on every peer by the spawner before the node enters the tree.
func setup(id: int, spawn_point: Vector3) -> void:
	# Deterministic on every machine: this name is how peers agree which crate is
	# which, so it is protocol rather than decoration (ADR 12). Do not rename it
	# for cosmetic reasons — it would fail on remote peers only, and silently.
	name = "crate_%d" % id
	position = spawn_point
	sync_position = spawn_point


func _apply_hold_forces() -> void:
	var target := Vector3.ZERO
	var facing := Vector3.ZERO
	for id in _hold_targets:
		var node := _hold_targets[id] as Node3D
		if node == null or not node.is_inside_tree():
			# The holder left mid-carry and its body is already gone.
			_break_hold(int(id))
			return
		target += node.global_position
		facing += -node.global_transform.basis.z

	var count := _hold_targets.size()
	target /= float(count)

	var to_target := target - global_position
	if to_target.length() > BREAK_DISTANCE:
		for id in _hold_targets.keys():
			_break_hold(int(id))
		return

	var damping := HOLD_DAMPING * (1.0 + EXTRA_HOLDER_DAMPING * float(count - 1))
	var force := to_target * HOLD_STIFFNESS - linear_velocity * damping
	apply_central_force(force.limit_length(MAX_HOLD_FORCE))
	_apply_alignment_torque(facing)


func _apply_alignment_torque(facing: Vector3) -> void:
	# Flattened, so the crate stays upright however far the holder is looking up
	# or down.
	facing.y = 0.0
	if facing.length_squared() < MIN_ALIGN_ANGLE:
		return

	var desired := Basis.looking_at(facing.normalized(), Vector3.UP).get_rotation_quaternion()
	var current := global_transform.basis.get_rotation_quaternion()
	var error := (desired * current.inverse()).normalized()
	if error.w < 0.0:
		# Take the short way round.
		error = -error

	var angle := error.get_angle()
	var axis := Vector3.ZERO
	if angle > MIN_ALIGN_ANGLE:
		axis = error.get_axis()

	var torque := axis * angle * ALIGN_STIFFNESS - angular_velocity * ALIGN_DAMPING
	apply_torque(torque.limit_length(MAX_ALIGN_TORQUE))


func _break_hold(peer_id: int) -> void:
	remove_holder(peer_id)
	hold_broken.emit(peer_id)
