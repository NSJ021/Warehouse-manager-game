class_name Crate
extends RigidBody3D

## Physics cargo. The host simulates it; every client sees a frozen kinematic
## puppet eased toward the host's replicated transform.
##
## Held crates are force-driven and never parented (ADR 13). The host pulls the
## body toward a hold point in front of each holder with a spring-damper, so the
## crate keeps colliding with the world for real, sags under its own weight, and
## renders its own latency as mass rather than as error. Throwing falls out of
## this for free — momentum is real, so swinging and releasing lobs it.
##
## Only the host runs [method _physics_process]. If clients simulated locally
## they would fight the host and drift, so they are frozen and posed from
## [member sync_position] / [member sync_basis] instead.
##
## Every tuning value below is exported rather than constant so it can be dialled
## in the inspector while the game runs. Two things to know when you do:
## the Remote tree edits one crate, not all of them — handy for A/B, surprising
## otherwise — and remote edits are live-only, so write the number down before
## you quit or it dies with the process. Changing the default here changes every
## crate.

## The host has taken this crate off a holder because it strayed past
## [member break_distance], or because the holder vanished mid-carry.
signal hold_broken(peer_id: int)

## Two is the ceiling by design — two-player carry, not four (GDD §6.1).
const MAX_HOLDERS := 2
## How fast a client puppet catches up to the host's last known transform.
const PUPPET_SMOOTHING := 20.0
## Below this, a rotation error is noise, and asking a near-identity quaternion
## for its axis divides by roughly zero.
const MIN_ALIGN_ANGLE := 0.001

@export_group("Hold")
## Stiffness against crate mass sets the sag, and the sag is deliberate feedback
## about weight (ADR 13) — not a bug to tune out. sag = mass × gravity /
## stiffness, so at mass 12 this gives roughly 4.9 cm of hang.
@export var hold_stiffness := 2400.0
## Critical damping is 2 × √(stiffness × mass) ≈ 339 here, so this is deliberately
## *over*-damped at about 1.35×. That is what reads as heavy: an over-damped
## spring resists being yanked about but never bobs, where an under-damped one
## bounces and reads as floaty. Raise this for more weight, not the stiffness.
@export var hold_damping := 460.0
## A safety net, not a limiter — a spring whose force outruns the solver is how
## this becomes a jitter bug. At full stretch the spring alone asks for
## stiffness × break_distance, so keep this comfortably above that.
@export var max_hold_force := 10000.0
## How far in front of the holder's eyeline the crate rides, and how far below it.
@export var hold_reach := 1.15
@export var hold_drop := -0.15
## Walk into a wall with a crate and you lose it. Measured from the true hold
## point rather than the lag-compensated one, so it means "how far is this from
## my hands" and does not fire merely because someone is sprinting.
@export var break_distance := 2.2
## Cancels the lag a damped spring has at constant speed, which is
## damping × velocity / stiffness — about 1.2 m at a sprint. Uncompensated, the
## crate settles that far behind the hold point, which puts it inside the holder
## and stores the energy that later launches it across the room. 1.0 cancels it
## exactly; 0.0 restores the old behaviour if the trailing is wanted.
@export_range(0.0, 1.0, 0.05) var lag_compensation := 1.0

@export_group("Alignment")
## Keeps the crate upright and facing the holder, so labels stay readable once
## there are labels to read (Phase 2).
@export var align_stiffness := 45.0
@export var align_damping := 9.0
@export var max_align_torque := 180.0

@export_group("Shoving")
## Cargo sits on a collision mask players do not share, so a capsule never
## touches a crate directly — without that, a puppet capsule (whose position is
## written rather than simulated) resolves the overlap with unlimited force and
## bulldozes cargo at walking pace, while the host's own capsule is simply
## blocked. Measured: 3.39 m of launch versus 0.01 m. The host applies this
## clamped force instead, so every player shoves identically (ADR 7).
@export var shove_force := 90.0
@export var max_shove_force := 700.0
## Below this you are leaning on it, not shoving it.
@export var min_shove_speed := 0.4

## Replicated by the MultiplayerSynchronizer. Written only by the host.
var sync_position := Vector3.ZERO
var sync_basis := Quaternion.IDENTITY

## peer_id -> the holding [Player]. Host-only, and never replicated: a node
## reference means nothing on another machine.
var _holders: Dictionary = {}

@onready var _push_sensor: Area3D = $PushSensor


func _enter_tree() -> void:
	# Cargo is host-owned, always. Clients ask; the host decides (ADR 7).
	set_multiplayer_authority(1)


func _ready() -> void:
	if Net.is_host():
		set_process(false)
		return
	# Only the host acts on overlaps, so every client was paying for detection it
	# never reads — which multiplies by crate count in the stress test.
	_push_sensor.monitoring = false
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	_apply_shoves()
	if not _holders.is_empty():
		_apply_hold_forces()
	sync_position = global_position
	sync_basis = global_transform.basis.get_rotation_quaternion()


func _process(delta: float) -> void:
	var weight := clampf(PUPPET_SMOOTHING * delta, 0.0, 1.0)
	var eased_position := global_position.lerp(sync_position, weight)
	var eased_basis := global_transform.basis.get_rotation_quaternion().slerp(sync_basis, weight)
	global_transform = Transform3D(Basis(eased_basis), eased_position)


## Host-only. Returns false if this crate is full or the peer already has it.
func add_holder(peer_id: int, holder: Player) -> bool:
	if _holders.size() >= MAX_HOLDERS or _holders.has(peer_id):
		return false
	_holders[peer_id] = holder
	# A held body is awake by definition — letting it sleep would strand it in
	# mid-air the moment the spring settled.
	can_sleep = false
	return true


## Host-only.
func remove_holder(peer_id: int) -> void:
	_holders.erase(peer_id)
	if _holders.is_empty():
		can_sleep = true


func holder_count() -> int:
	return _holders.size()


func is_held_by(peer_id: int) -> bool:
	return _holders.has(peer_id)


## Called on every peer by the spawner before the node enters the tree.
func setup(id: int, spawn_point: Vector3) -> void:
	# Deterministic on every machine: this name is how peers agree which crate is
	# which, so it is protocol rather than decoration (ADR 12). Do not rename it
	# for cosmetic reasons — it would fail on remote peers only, and silently.
	name = "crate_%d" % id
	position = spawn_point
	sync_position = spawn_point


## Host-only. Walking into cargo shoves it, at a force the host controls.
func _apply_shoves() -> void:
	for body in _push_sensor.get_overlapping_bodies():
		var player := body as Player
		if player == null:
			continue
		# Never shove what you are carrying. Without this the holder's own capsule
		# pushes their crate away from them for as long as they walk forward.
		if is_held_by(player.peer_id):
			continue

		var toward := global_position - player.global_position
		toward.y = 0.0
		if toward.length_squared() < 0.0001:
			continue
		toward = toward.normalized()

		# Read off the replicated value rather than the physics engine: a puppet
		# capsule has no velocity of its own on this machine.
		var closing := player.sync_velocity.dot(toward)
		if closing < min_shove_speed:
			continue

		# A crate asleep on the floor will not wake for an applied force alone.
		sleeping = false
		apply_central_force((toward * closing * shove_force).limit_length(max_shove_force))


func _apply_hold_forces() -> void:
	var hold_point := Vector3.ZERO
	var holder_velocity := Vector3.ZERO
	var facing := Vector3.ZERO

	for id in _holders:
		var holder := _holders[id] as Player
		if holder == null or not holder.is_inside_tree():
			# The holder left mid-carry and its body is already gone.
			_break_hold(int(id))
			return
		var eyes := holder.camera_pivot.global_transform
		hold_point += eyes * Vector3(0.0, hold_drop, -hold_reach)
		holder_velocity += holder.sync_velocity
		facing += -eyes.basis.z

	var count := _holders.size()
	hold_point /= float(count)
	holder_velocity /= float(count)

	# Two holders are steadier, not twice as violent (ADR 13).
	var damping := hold_damping * (1.0 + 0.5 * float(count - 1))

	# Aim ahead by exactly the lag the damper will introduce, so the crate ends up
	# at the hold point rather than trailing behind it into the holder.
	var target := hold_point + holder_velocity * (damping / hold_stiffness) * lag_compensation

	# Break against the real hold point, not the compensated one — otherwise
	# simply running would look like the crate had been dragged away.
	if hold_point.distance_to(global_position) > break_distance:
		for id in _holders.keys():
			_break_hold(int(id))
		return

	var force := (target - global_position) * hold_stiffness - linear_velocity * damping
	apply_central_force(force.limit_length(max_hold_force))
	_apply_alignment_torque(facing)


func _apply_alignment_torque(facing: Vector3) -> void:
	# Flattened, so the crate stays upright however far the holder looks up or down.
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

	var torque := axis * angle * align_stiffness - angular_velocity * align_damping
	apply_torque(torque.limit_length(max_align_torque))


func _break_hold(peer_id: int) -> void:
	remove_holder(peer_id)
	hold_broken.emit(peer_id)
