class_name Player
extends CharacterBody3D

## First-person character. Each client is authoritative over its own capsule and
## nothing else — see the ADR on client-authoritative characters.
##
## The authority simulates movement locally with zero input latency and publishes
## the result into [member sync_position] / [member sync_yaw] / [member sync_pitch].
## Every other peer treats this node as a puppet and eases its visible transform
## toward those values, so a dropped packet reads as a slight glide rather than a
## teleport.

const WALK_SPEED := 4.2
const SPRINT_SPEED := 6.4
const JUMP_VELOCITY := 4.5
const ACCELERATION := 12.0
const AIR_ACCELERATION := 3.0
const MOUSE_SENSITIVITY := 0.0022
const PITCH_LIMIT := deg_to_rad(89.0)
## How fast a puppet catches up to the authority's last known state.
const PUPPET_SMOOTHING := 18.0

## Distinct colours so four windows are tellable apart at a glance during testing.
const PLAYER_COLOURS: Array[Color] = [
	Color("e8b64c"), # amber
	Color("4ca8e8"), # blue
	Color("6cc24a"), # green
	Color("e05c5c"), # red
]

## Replicated by the MultiplayerSynchronizer. Written only by the authority.
var sync_position := Vector3.ZERO
var sync_yaw := 0.0
var sync_pitch := 0.0
## Replicated because the host needs it and cannot measure it: a puppet capsule
## runs no physics, so the host reads the owner's own velocity to work out how
## hard a shove into cargo should be.
var sync_velocity := Vector3.ZERO

var peer_id := 1
var player_name := "Player"

var _pitch := 0.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var name_label: Label3D = $NameLabel


func _enter_tree() -> void:
	# The spawner names the node after its owning peer, so every machine derives
	# the same authority without an extra round trip.
	peer_id = name.to_int()
	set_multiplayer_authority(peer_id)


func _ready() -> void:
	var is_mine := is_multiplayer_authority()
	camera.current = is_mine
	name_label.visible = not is_mine

	var colour := PLAYER_COLOURS[abs(peer_id) % PLAYER_COLOURS.size()]
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	body_mesh.material_override = material
	name_label.modulate = colour
	name_label.text = player_name

	if is_mine:
		sync_position = global_position
		sync_yaw = rotation.y
	else:
		# Puppets are posed from replicated state; they must not run their own
		# gravity or collision resolution or they will fight the authority.
		set_physics_process(false)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * MOUSE_SENSITIVITY)
		_pitch = clamp(_pitch - motion.relative.y * MOUSE_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
		camera_pivot.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var can_act := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if can_act and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if can_act else Vector2.ZERO
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed := SPRINT_SPEED if (can_act and Input.is_action_pressed("sprint")) else WALK_SPEED
	var target := direction * speed
	var accel := ACCELERATION if is_on_floor() else AIR_ACCELERATION

	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)

	move_and_slide()

	sync_position = global_position
	sync_yaw = rotation.y
	sync_pitch = _pitch
	sync_velocity = velocity


func _process(delta: float) -> void:
	# Bodies outlive the peer by a frame when a session ends, and asking about
	# authority without a peer is an error rather than a false.
	if not multiplayer.has_multiplayer_peer() or is_multiplayer_authority():
		return
	var weight := clampf(PUPPET_SMOOTHING * delta, 0.0, 1.0)
	global_position = global_position.lerp(sync_position, weight)
	rotation.y = lerp_angle(rotation.y, sync_yaw, weight)
	camera_pivot.rotation.x = lerp_angle(camera_pivot.rotation.x, sync_pitch, weight)


## Place this capsule immediately, skipping the walk. For respawns, day resets,
## and the integration harness putting a player where a crate is.
func teleport_to(point: Vector3) -> void:
	global_position = point
	sync_position = point
	velocity = Vector3.ZERO
	sync_velocity = Vector3.ZERO


## Point the camera at a world position.
##
## Writes the same state a mouse would, which is the whole point: setting
## [member camera_pivot] rotation directly would leave [member sync_pitch] stale,
## so remote peers — including the host, which decides what you can reach — would
## still think this player was looking straight ahead.
func aim_at(point: Vector3) -> void:
	var to_target := point - camera.global_position
	if to_target.length_squared() < 0.0001:
		return
	# Forward is -Z, hence the negated arguments.
	rotation.y = atan2(-to_target.x, -to_target.z)
	_pitch = clampf(asin(to_target.normalized().y), -PITCH_LIMIT, PITCH_LIMIT)
	camera_pivot.rotation.x = _pitch
	sync_yaw = rotation.y
	sync_pitch = _pitch


## Called on every peer by the spawner before the node enters the tree.
func setup(id: int, display_name: String, spawn_point: Vector3) -> void:
	peer_id = id
	player_name = display_name
	name = str(id)
	position = spawn_point
	sync_position = spawn_point
