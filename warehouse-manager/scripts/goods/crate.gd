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
## A hold is either a [b]carry[/b] or a [b]drag[/b], and the difference is which
## spring runs — see [enum HoldMode]. Drag is a mode rather than a parallel
## system on purpose: it reuses the referee, the break distance and the same
## never-parented rule, so there is one way to be holding something.
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
## The host has changed what an existing hold *is* — a solo drag became a
## two-player carry because a mate grabbed on, or fell back to a drag when they
## let go. Sent per holder, because the dragger's own machine applies the drag
## speed penalty and movement is client-authoritative (ADR 7). Without this, a
## player whose drag got promoted would keep walking at 40% for no visible reason.
signal hold_mode_changed(peer_id: int, mode: HoldMode)

## What a hold does to a crate.
##
## [b]CARRY[/b] lifts it to the holder's eyeline. [b]DRAG[/b] leaves it on the
## floor and hauls it along (GDD §6.1) — the solo answer to cargo too heavy to
## pick up, and deliberately worse in every way except that it is always possible.
enum HoldMode { CARRY, DRAG }

## Two is the ceiling by design — two-player carry, not four (GDD §6.1).
const MAX_HOLDERS := 2
## Above this, one player cannot get a crate off the floor and is given a drag
## whether they asked for one or not. Two players can always lift.
##
## Provisional, and keyed off [member RigidBody3D.mass] alone: size classes do not
## exist yet. ADR 18 fixes the crate [i]dimensions[/i] (Small 0.5 m, Medium 1.0 m,
## Large 2.0 × 1.0 × 1.0) but says nothing about their masses, so there is no
## Large to calibrate against. Revisit when there is — the intent is that Large is
## the only thing a solo player cannot lift.
const SOLO_CARRY_MASS_LIMIT := 30.0
## How fast a client puppet catches up to the host's last known transform.
const PUPPET_SMOOTHING := 20.0
## Once a puppet is this close to the host's last word on where it is, there is
## nothing left to smooth. About 3 mm, and a hair off perfectly aligned.
const PUPPET_EPSILON_SQ := 0.00001
const PUPPET_ALIGNED_DOT := 0.99995
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

@export_group("Drag")
## How far in front of the dragger the crate trails, measured on the floor plane.
@export var drag_reach := 1.25
## Deliberately softer than the carry spring. A dragged crate is meant to lag,
## slew and catch rather than track you (GDD §6.1: "snags, catches on corners").
@export var drag_stiffness := 900.0
@export var drag_damping := 260.0
@export var max_drag_force := 4000.0
## Let go of sooner than a carry — this is a grip on a corner, not a hug. Wider
## than [member drag_reach] so simply walking never sheds it.
@export var drag_break_distance := 2.6
## What a dragger's own machine multiplies its walk speed by (GDD §6.1 says ~40%).
## Read by [Player], which is the only thing that can apply it: movement is
## client-authoritative, so the host cannot slow anyone down.
@export_range(0.1, 1.0, 0.05) var drag_speed_scale := 0.4

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
## Who is holding this, replicated so clients can tell the truth about it — the
## host-only dictionary below is invisible to them, so without these a client's
## HUD would report a two-player carry as carrying alone. Two fields rather than
## an array because two is the cap, so the shape encodes the rule. 0 means empty.
var sync_holder_a := 0
var sync_holder_b := 0

## Metres this crate has been hauled along the floor, accumulated by the host
## while dragged. Phase 3 turns distance dragged into scuffing (GDD §6.1); it is
## recorded now because it costs one multiply per frame on cargo that is already
## awake, and it means the damage model arrives to find data already flowing
## rather than needing a new hook cut into the physics.
var drag_distance := 0.0

## peer_id -> the holding [Player]. Host-only, and never replicated: a node
## reference means nothing on another machine.
var _holders: Dictionary = {}
## Host-only. What the current hold is, kept so a change can be spotted and
## announced rather than recomputed by everyone every frame.
var _hold_mode := HoldMode.CARRY
## Host-only. peer_id -> whether that holder asked to drag rather than carry.
##
## Per holder rather than one flag for the crate, and the distinction is not
## academic: A drags a crate, B grabs the other end to help, A lets go. One flag
## would leave B — who asked to carry — dragging it. Kept per peer so the
## survivor's own request decides, not whoever happened to grab first.
var _drag_requests: Dictionary = {}

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


func _physics_process(delta: float) -> void:
	_apply_shoves()
	if not _holders.is_empty():
		_apply_hold_forces(delta)
	sync_position = global_position
	sync_basis = global_transform.basis.get_rotation_quaternion()

	var ids := _holders.keys()
	sync_holder_a = int(ids[0]) if ids.size() > 0 else 0
	sync_holder_b = int(ids[1]) if ids.size() > 1 else 0


func _process(delta: float) -> void:
	# Measured, not guessed: smoothing every crate every frame cost a client about
	# 6 ms per frame at 100 crates - over a third of a 60 Hz budget, before
	# anything is drawn - and most of those crates were sitting perfectly still.
	#
	# So: while the host is still sending updates, ease toward them. Once it goes
	# quiet, converge and then stop entirely. Settled cargo costs two comparisons
	# instead of a lerp, a slerp and a transform write into the physics server.
	# Keyed on being *already there* rather than on the host having gone quiet. An
	# earlier version waited for updates to stop arriving, which never happened:
	# at a 20 Hz sync there are only a handful of frames between messages, so the
	# idle counter never reached its threshold and this saved nothing at all.
	var current := global_transform.basis.get_rotation_quaternion()
	if global_position.distance_squared_to(sync_position) < PUPPET_EPSILON_SQ \
			and absf(current.dot(sync_basis)) > PUPPET_ALIGNED_DOT:
		return

	var weight := clampf(PUPPET_SMOOTHING * delta, 0.0, 1.0)
	var eased_position := global_position.lerp(sync_position, weight)
	var eased_basis := current.slerp(sync_basis, weight)
	global_transform = Transform3D(Basis(eased_basis), eased_position)


## Host-only. Returns false if this crate is full or the peer already has it.
##
## [param want_drag] is a request, not an instruction — mass can force a drag on
## someone who asked to carry, and a second holder overrides both.
func add_holder(peer_id: int, holder: Player, want_drag := false) -> bool:
	if _holders.size() >= MAX_HOLDERS or _holders.has(peer_id):
		return false
	_holders[peer_id] = holder
	_drag_requests[peer_id] = want_drag
	# A held body is awake by definition — letting it sleep would strand it in
	# mid-air the moment the spring settled, and would let a dragged crate go to
	# sleep under the hand hauling it.
	can_sleep = false
	_refresh_hold_mode()
	return true


## Host-only.
func remove_holder(peer_id: int) -> void:
	_holders.erase(peer_id)
	_drag_requests.erase(peer_id)
	if _holders.is_empty():
		can_sleep = true
		return
	# Someone is still on it. Two-player carry dropping back to one holder may
	# mean the survivor can no longer lift it, so the mode is re-decided rather
	# than assumed to be unchanged.
	_refresh_hold_mode()


## Host-only truth about what this hold currently is.
func hold_mode() -> HoldMode:
	return _hold_mode


## Host-only. Two holders always carry, so a mate walking over and grabbing a
## dragged crate lifts it off the floor — and letting go drops it back to a drag.
## That falls out of re-deciding here rather than needing its own code path.
func _refresh_hold_mode() -> void:
	var resolved := HoldMode.CARRY
	if _holders.size() == 1:
		var only := int(_holders.keys()[0])
		if bool(_drag_requests.get(only, false)) or mass > SOLO_CARRY_MASS_LIMIT:
			resolved = HoldMode.DRAG
	if resolved == _hold_mode:
		return
	_hold_mode = resolved
	for id in _holders:
		hold_mode_changed.emit(int(id), resolved)


## Correct on every peer, host or client, because it reads the replicated fields
## rather than the host-only dictionary.
func holder_count() -> int:
	var count := 0
	if sync_holder_a != 0:
		count += 1
	if sync_holder_b != 0:
		count += 1
	return count


## Host-only truth, used by the physics. Clients should ask [method holder_count].
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


func _apply_hold_forces(delta: float) -> void:
	if _hold_mode == HoldMode.DRAG:
		_apply_drag_forces(delta)
	else:
		_apply_carry_forces()


## Solo drag. Hauls the crate along the floor instead of lifting it.
##
## The spring acts [i]only on the floor plane[/i]. Gravity is left to hold the
## crate down, so nothing ever pushes it upward and it is never lifted — which is
## the entire difference between dragging a thing and carrying it low. It also
## makes it catch on anything it cannot slide over for free, rather than needing a
## snagging system, because there is no vertical force to lift it over a lip.
##
## No alignment torque either. A carried crate is held square so its label stays
## readable (Phase 2); a dragged one is supposed to slew about and scrape.
##
## Aimed from the capsule's yaw rather than the camera, so looking up at a rack
## does not haul the crate off the floor — and so a solo dragger physically cannot
## rack anything above floor level, which is the incentive the whole two-player
## carry trade rests on (GDD §6.1).
func _apply_drag_forces(delta: float) -> void:
	var id := int(_holders.keys()[0])
	var holder := _holders[id] as Player
	if holder == null or not holder.is_inside_tree():
		_break_hold(id)
		return

	var forward := -holder.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < MIN_ALIGN_ANGLE:
		return

	var hold_point := holder.global_position + forward.normalized() * drag_reach
	var to_target := hold_point - global_position
	# Judged flat, because a crate on the floor is always below the hip the reach
	# is measured from. Counting that constant drop would shed the hold instantly.
	to_target.y = 0.0
	if to_target.length() > drag_break_distance:
		_break_hold(id)
		return

	var flat_velocity := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var force := to_target * drag_stiffness - flat_velocity * drag_damping
	apply_central_force(force.limit_length(max_drag_force))

	# Phase 3's scuff input. The crate's own travel, not the dragger's, so hauling
	# against a wall that stops it dead does not accrue damage it never took.
	drag_distance += flat_velocity.length() * delta


func _apply_carry_forces() -> void:
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
