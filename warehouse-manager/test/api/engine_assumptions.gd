extends SceneTree

## API layer: are the assumptions this project is built on still true?
##
## Foundation #4 — "check, never assume" — was the only foundation with no
## enforcement behind it. This is the enforcement.
##
## Every check here was originally a throwaway probe: written, run once, deleted.
## Six of them in a single day, verifying things like whether a RayCast3D reports
## a shape it starts inside, or whether Jolt populates the physics monitors, or
## what GodotSteam's init signature actually is. Deleting them meant the next
## session re-derived the same facts, and meant a Godot or GodotSteam upgrade
## would break those assumptions **silently** — the worst way to find out.
##
## So the probes live here now. The point is not that these APIs are fragile; it
## is that when one of them changes, this fails on the day it changes and names
## the assumption, instead of surfacing later as inexplicable behaviour.
##
## Three sections:
##   1. Engine APIs the code calls, including behaviours where the *shape* of the
##      answer matters and not merely that the method exists.
##   2. GodotSteam, checked by argument count too, because the transport is
##      rarely exercised and a changed signature fails on its first line.
##   3. Invariants that ADRs fixed. Code drifting from a decision is exactly as
##      bad as code drifting from a spec, and nothing else checks it.
##
## Run via tools/run-tests.ps1. Exits 0 on pass, 1 on any failure.

var _failures: Array[String] = []
var _checked := 0

## Physics-dependent checks cannot run in _initialize — the server needs a few
## frames before a raycast returns anything meaningful.
var _frames := 0
var _aim_cases: Array = []

## 01-09 (ADR 17): a settled crate freezes to FREEZE_MODE_STATIC and joins the
## world layer, and three behaviours hold that decision up — all measured
## before ADR 17 was written, not assumed, and named individually below
## rather than folded into one boolean so a failure says which one broke.
var _settled_body: RigidBody3D
var _settled_body_start: Vector3
var _settled_walker: CharacterBody3D
var _settled_zone: Area3D
var _settled_sensor_body: RigidBody3D
var _settled_sensor_area: Area3D
var _settled_sensor_walker: CharacterBody3D

## 02-03: the dock door rests on an AnimatableBody3D displacing a dynamic
## RigidBody3D for real, and NOT displacing a frozen FREEZE_MODE_STATIC one —
## the second half is exactly why the door has to wake a settled crate before
## it can push it (Crate.wake / DockDoor._wake_blocking_cargo).
var _door_slab_dynamic: AnimatableBody3D
var _door_dynamic_body: RigidBody3D
var _door_dynamic_start: Vector3
var _door_slab_static: AnimatableBody3D
var _door_static_body: RigidBody3D
var _door_static_start: Vector3


func _initialize() -> void:
	_check_engine_apis()
	_check_engine_behaviours()
	_check_godotsteam()
	_check_decided_invariants()
	_build_aim_scene()
	_build_settle_scene()
	_build_door_scene()


func _physics_process(_delta: float) -> bool:
	_frames += 1
	# The force/impulse in _apply_settle_forces() needs a physics step to
	# have any chance of moving something — applied once the server has a
	# physics space to receive it (frame 3, the same gate everything else
	# below needs anyway), then given three more frames before anything
	# checks whether it worked. The door slabs are driven the same way, on
	# the same frame, for the same reason.
	if _frames == 3:
		_apply_settle_forces()
		_apply_door_forces()
	if _frames < 6:
		return false
	_check_aim_behaviour()
	_check_settle_behaviour()
	_check_door_behaviour()
	_report()
	return true


func _report() -> void:
	print("")
	if _failures.is_empty():
		print("[api] PASS - %d assumptions still hold" % _checked)
		quit(0)
		return

	print("[api] FAIL - %d of %d assumptions broken" % [_failures.size(), _checked])
	for line in _failures:
		print("  %s" % line)
	print("")
	print("  An assumption breaking is usually an engine or addon upgrade.")
	print("  Find what replaced it before changing any game code.")
	quit(1)


## Storage cells are aim targets, not detectors. Phase 1 plans to raycast against
## Area3D cell volumes with monitoring and monitorable both OFF, so that a rack full of
## cells costs nothing in collision detection while still being aimable at.
##
## Measured before relying on it: hittability is independent of both flags. If a
## future engine version ever couples them, every cell silently starts paying for
## detection it never reads, and aiming would keep working — so nothing would look
## wrong. That is exactly the kind of regression worth an assertion.
func _build_aim_scene() -> void:
	var world := Node3D.new()
	get_root().add_child(world)

	var x := 0.0
	for case in [
		["cell area is aimable with monitoring ON", true, true],
		["cell area is aimable with monitoring OFF", false, true],
		["cell area is aimable with monitoring AND monitorable OFF", false, false],
	]:
		var area := Area3D.new()
		area.collision_layer = 8
		area.collision_mask = 0
		area.monitoring = case[1]
		area.monitorable = case[2]
		area.position = Vector3(x, 0.0, 0.0)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.5, 0.5, 0.5)
		shape.shape = box
		area.add_child(shape)
		world.add_child(area)

		var ray := RayCast3D.new()
		ray.position = Vector3(x, 0.0, 2.0)
		ray.target_position = Vector3(0.0, 0.0, -3.0)
		ray.collision_mask = 8
		ray.collide_with_areas = true
		ray.collide_with_bodies = false
		world.add_child(ray)

		_aim_cases.append([case[0], ray, area])
		x += 3.0


func _check_aim_behaviour() -> void:
	print("[api] aiming at storage cells")
	_expect_properties("RayCast3D", ["collide_with_areas", "collide_with_bodies"])
	for entry in _aim_cases:
		var ray: RayCast3D = entry[1]
		ray.force_raycast_update()
		var hit: bool = ray.is_colliding() and ray.get_collider() == entry[2]
		_expect(hit, entry[0])


## Settled cargo (ADR 17, 01-09) rests on four behaviours, none of them
## specific to [Crate] — built from plain engine nodes here so a failure
## points at the engine, not at anything this project wrote.
func _build_settle_scene() -> void:
	var world := Node3D.new()
	get_root().add_child(world)

	# 1 & 2: a frozen static body blocks a CharacterBody3D sharing its mask,
	# and cannot itself be displaced by a force or an impulse.
	_settled_body = RigidBody3D.new()
	_settled_body.collision_layer = 1  # world - the bit a settled crate gains
	_settled_body.collision_mask = 0
	_settled_body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	_settled_body.freeze = true
	_settled_body.position = Vector3(20.0, 0.0, 0.0)
	var body_shape := CollisionShape3D.new()
	var body_box := BoxShape3D.new()
	body_box.size = Vector3(0.5, 0.5, 0.5)
	body_shape.shape = body_box
	_settled_body.add_child(body_shape)
	world.add_child(_settled_body)
	# world sits at the origin with no rotation, so this equals global_position
	# — read as the literal rather than via global_position here, because the
	# body has no physics space to query yet on the very frame it is added
	# (Jolt is explicit about this: apply_central_impulse/_force both need
	# one, and this build step runs before the frame gate below gives the
	# server a chance to create it).
	_settled_body_start = Vector3(20.0, 0.0, 0.0)

	_settled_walker = CharacterBody3D.new()
	_settled_walker.collision_layer = 2
	_settled_walker.collision_mask = 1
	_settled_walker.position = Vector3(19.0, 0.0, 0.0)
	var walker_shape := CollisionShape3D.new()
	var walker_capsule := CapsuleShape3D.new()
	walker_capsule.radius = 0.3
	walker_capsule.height = 1.8
	walker_shape.shape = walker_capsule
	_settled_walker.add_child(walker_shape)
	world.add_child(_settled_walker)

	# 3: an Area3D that is NOT a child of the frozen body still sees it as an
	# overlapping body - what lets a Goods zone (a level fixture, not a child
	# of any crate) detect stock that has settled and sat there all day, the
	# 01-05 <-> 01-09 interaction flagged in STATE.md.
	_settled_zone = Area3D.new()
	_settled_zone.collision_layer = 0
	_settled_zone.collision_mask = 1
	_settled_zone.monitoring = true
	_settled_zone.monitorable = false
	_settled_zone.position = Vector3(20.0, 0.0, 0.0)
	var zone_shape := CollisionShape3D.new()
	var zone_box := BoxShape3D.new()
	zone_box.size = Vector3(2.0, 2.0, 2.0)
	zone_shape.shape = zone_box
	_settled_zone.add_child(zone_shape)
	world.add_child(_settled_zone)

	# 4: an Area3D CHILD of a frozen body still reports overlapping bodies -
	# the exact shape of the crate's own PushSensor, and what lets a settled
	# crate always be woken by a shove.
	_settled_sensor_body = RigidBody3D.new()
	_settled_sensor_body.collision_layer = 1
	_settled_sensor_body.collision_mask = 0
	_settled_sensor_body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	_settled_sensor_body.freeze = true
	_settled_sensor_body.position = Vector3(24.0, 0.0, 0.0)
	var sensor_body_shape := CollisionShape3D.new()
	var sensor_body_box := BoxShape3D.new()
	sensor_body_box.size = Vector3(0.5, 0.5, 0.5)
	sensor_body_shape.shape = sensor_body_box
	_settled_sensor_body.add_child(sensor_body_shape)

	_settled_sensor_area = Area3D.new()
	_settled_sensor_area.collision_layer = 0
	_settled_sensor_area.collision_mask = 2
	_settled_sensor_area.monitoring = true
	_settled_sensor_area.monitorable = false
	var sensor_area_shape := CollisionShape3D.new()
	var sensor_area_box := BoxShape3D.new()
	sensor_area_box.size = Vector3(0.62, 0.62, 0.62)
	sensor_area_shape.shape = sensor_area_box
	_settled_sensor_area.add_child(sensor_area_shape)
	_settled_sensor_body.add_child(_settled_sensor_area)
	world.add_child(_settled_sensor_body)

	_settled_sensor_walker = CharacterBody3D.new()
	_settled_sensor_walker.collision_layer = 2
	_settled_sensor_walker.collision_mask = 0
	_settled_sensor_walker.position = Vector3(24.0, 0.0, 0.0)
	var sensor_walker_shape := CollisionShape3D.new()
	var sensor_walker_capsule := CapsuleShape3D.new()
	sensor_walker_capsule.radius = 0.3
	sensor_walker_capsule.height = 1.8
	sensor_walker_shape.shape = sensor_walker_capsule
	_settled_sensor_walker.add_child(sensor_walker_shape)
	world.add_child(_settled_sensor_walker)


## A real force and a real impulse, thrown at the frozen body once it has a
## physics space to receive them. [method _check_settle_behaviour] checks a
## few frames later whether either one moved it at all.
func _apply_settle_forces() -> void:
	_settled_body.apply_central_impulse(Vector3(500.0, 0.0, 0.0))
	_settled_body.apply_central_force(Vector3(5000.0, 0.0, 0.0))


func _check_settle_behaviour() -> void:
	print("[api] settled cargo (ADR 17)")

	var collision := _settled_walker.move_and_collide(Vector3(2.0, 0.0, 0.0))
	_expect(
		collision != null and collision.get_collider() == _settled_body,
		"a frozen FREEZE_MODE_STATIC RigidBody3D blocks a CharacterBody3D sharing its mask",
	)

	_expect(
		_settled_body.global_position.distance_to(_settled_body_start) < 0.001,
		"a frozen static body cannot be displaced by a force or an impulse",
	)

	_expect(
		_settled_zone.get_overlapping_bodies().has(_settled_body),
		"an Area3D that is not a child of a frozen body still reports it overlapping " +
		"(what lets a Goods zone see settled stock)",
	)

	_expect(
		_settled_sensor_area.get_overlapping_bodies().has(_settled_sensor_walker),
		"an Area3D child of a frozen body still reports overlapping bodies " +
		"(what lets a settled crate always be woken)",
	)


## 02-03: the dock door's whole design rests on an AnimatableBody3D pushing a
## dynamic RigidBody3D for real, and doing nothing at all to a frozen
## FREEZE_MODE_STATIC one. Two independent slab/target pairs rather than one
## reused slab, so each half of the assertion gets a clean, unambiguous start
## position instead of racing the other's result.
func _build_door_scene() -> void:
	var world := Node3D.new()
	get_root().add_child(world)

	_door_slab_dynamic = AnimatableBody3D.new()
	_door_slab_dynamic.sync_to_physics = true
	_door_slab_dynamic.collision_layer = 1
	_door_slab_dynamic.collision_mask = 0
	_door_slab_dynamic.position = Vector3(30.0, 0.0, 0.0)
	var slab_dynamic_shape := CollisionShape3D.new()
	var slab_dynamic_box := BoxShape3D.new()
	slab_dynamic_box.size = Vector3(1.0, 1.0, 1.0)
	slab_dynamic_shape.shape = slab_dynamic_box
	_door_slab_dynamic.add_child(slab_dynamic_shape)
	world.add_child(_door_slab_dynamic)

	_door_dynamic_body = RigidBody3D.new()
	_door_dynamic_body.collision_layer = 4
	_door_dynamic_body.collision_mask = 5
	_door_dynamic_body.position = Vector3(32.0, 0.0, 0.0)
	var dyn_shape := CollisionShape3D.new()
	var dyn_box := BoxShape3D.new()
	dyn_box.size = Vector3(0.5, 0.5, 0.5)
	dyn_shape.shape = dyn_box
	_door_dynamic_body.add_child(dyn_shape)
	world.add_child(_door_dynamic_body)
	_door_dynamic_start = _door_dynamic_body.position

	_door_slab_static = AnimatableBody3D.new()
	_door_slab_static.sync_to_physics = true
	_door_slab_static.collision_layer = 1
	_door_slab_static.collision_mask = 0
	_door_slab_static.position = Vector3(40.0, 0.0, 0.0)
	var slab_static_shape := CollisionShape3D.new()
	var slab_static_box := BoxShape3D.new()
	slab_static_box.size = Vector3(1.0, 1.0, 1.0)
	slab_static_shape.shape = slab_static_box
	_door_slab_static.add_child(slab_static_shape)
	world.add_child(_door_slab_static)

	_door_static_body = RigidBody3D.new()
	_door_static_body.collision_layer = 4
	_door_static_body.collision_mask = 5
	_door_static_body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	_door_static_body.freeze = true
	_door_static_body.position = Vector3(42.0, 0.0, 0.0)
	var static_shape := CollisionShape3D.new()
	var static_box := BoxShape3D.new()
	static_box.size = Vector3(0.5, 0.5, 0.5)
	static_shape.shape = static_box
	_door_static_body.add_child(static_shape)
	world.add_child(_door_static_body)
	_door_static_start = _door_static_body.position


## Jumps both slabs directly onto their own target body's position — a huge,
## deliberate overlap, so [member RigidBody3D.sync_to_physics]'s implicit
## velocity (derived from the transform delta between physics ticks) is
## unambiguous rather than borderline. Same timing as [method
## _apply_settle_forces]: applied once the server has a physics space to
## receive it, then given three more frames before anything checks.
func _apply_door_forces() -> void:
	_door_slab_dynamic.position = _door_dynamic_body.position
	_door_slab_static.position = _door_static_body.position


func _check_door_behaviour() -> void:
	print("[api] AnimatableBody3D vs the dock door (02-03)")

	_expect(
		_door_dynamic_body.global_position.distance_to(_door_dynamic_start) > 0.05,
		"an AnimatableBody3D moved into a dynamic RigidBody3D displaces it",
	)
	_expect(
		_door_static_body.global_position.distance_to(_door_static_start) < 0.001,
		"an AnimatableBody3D moved into a frozen FREEZE_MODE_STATIC RigidBody3D does not displace it " +
		"(why the door has to wake a settled crate before it can push it)",
	)


# --------------------------------------------------------------- section 1

func _check_engine_apis() -> void:
	print("[api] engine methods and properties")

	# Cargo is a force-driven rigid body (ADR 13) and the host clamps what it
	# applies, so all of these are load-bearing rather than incidental.
	_expect_methods("RigidBody3D", [
		"apply_central_force", "apply_torque", "apply_central_impulse",
	])
	_expect_properties("RigidBody3D", [
		"freeze", "freeze_mode", "mass", "linear_velocity", "angular_velocity",
		"can_sleep", "sleeping", "continuous_cd", "gravity_scale",
	])
	_expect_constant("RigidBody3D", "FREEZE_MODE_KINEMATIC")

	# hit_from_inside is not a nicety: players pass through cargo, so the grab ray
	# routinely starts inside the crate it is trying to pick up.
	_expect_properties("RayCast3D", ["hit_from_inside", "collision_mask", "target_position"])
	_expect_methods("RayCast3D", [
		"force_raycast_update", "is_colliding", "get_collider",
		"add_exception", "remove_exception",
	])

	# The shove sensor detects capsules its own body deliberately cannot collide with.
	_expect_methods("Area3D", ["get_overlapping_bodies"])
	_expect_properties("Area3D", ["monitoring", "monitorable"])

	# replication_interval is what cut host upstream 16x (ADR 14).
	_expect_properties("MultiplayerSynchronizer", ["replication_interval", "replication_config"])
	_expect_properties("MultiplayerSpawner", ["spawn_path"])
	_expect_methods("MultiplayerSpawner", ["spawn"])

	# Real measured bytes for the physics budget, rather than an estimate.
	_expect_constant("ENetConnection", "HOST_TOTAL_SENT_DATA")
	_expect_methods("ENetConnection", ["pop_statistic"])
	_expect_methods("ENetMultiplayerPeer", ["get_host", "create_server", "create_client"])

	# rpc_id's peer argument, pinned because getting it wrong is invisible.
	#
	# 0 is broadcast, and any POSITIVE value targets one peer. Godot 3's
	# "negative means everyone except this peer" form does NOT exist in Godot
	# 4 -- there is no exclude form at all, and you must loop
	# multiplayer.get_peers() and skip the id yourself.
	#
	# This is asserted because of how it fails rather than how likely it is.
	# rpc_id(-1, ...) does not raise where you wrote it: the engine drops the
	# call with "Attempt to call RPC with unknown peer ID: -1" into stderr,
	# the host's own state stays perfectly correct, and the symptom surfaces
	# as a TIMEOUT in whichever client assertion was waiting on the state
	# that never arrived -- potentially dozens of steps away. It cost about
	# ninety minutes on 02-06 for exactly that reason.
	_expect(
		MultiplayerPeer.TARGET_PEER_BROADCAST == 0,
		"rpc_id(0) is broadcast; there is no negative 'all except' peer id in Godot 4",
	)

	_expect_methods("CharacterBody3D", ["move_and_slide", "is_on_floor"])
	_expect_properties("CharacterBody3D", ["velocity", "collision_layer", "collision_mask"])

	# The dock door (02-03) drives its slab by moving this every frame.
	_expect_properties("AnimatableBody3D", ["sync_to_physics"])


# --------------------------------------------------------------- section 2

func _check_engine_behaviours() -> void:
	print("[api] engine behaviours")

	# The alignment torque builds a target basis from a flattened forward vector.
	var forward := Vector3(0.7, 0.0, -0.7).normalized()
	var looked := Basis.looking_at(forward, Vector3.UP)
	_expect(
		(-looked.z).is_equal_approx(forward),
		"Basis.looking_at still points -Z at its target",
	)

	# Rotation error is taken as axis-angle, and the negate-when-w-is-negative
	# guard is what keeps it taking the short way round. If quaternion sign
	# conventions ever change, the crate would spin the long way to align.
	var from := Basis.IDENTITY.get_rotation_quaternion()
	var to := Basis(Vector3.UP, deg_to_rad(270.0)).get_rotation_quaternion()
	var error := (to * from.inverse()).normalized()
	if error.w < 0.0:
		error = -error
	_expect(
		is_equal_approx(rad_to_deg(error.get_angle()), 90.0),
		"a 270-degree error still resolves to 90 the short way (got %.1f)" % rad_to_deg(error.get_angle()),
	)

	# Force and torque clamps depend on this doing nothing when already short.
	_expect(
		Vector3(9000.0, 0.0, 0.0).limit_length(4000.0).is_equal_approx(Vector3(4000.0, 0.0, 0.0)),
		"Vector3.limit_length still clamps",
	)

	# Not an assumption we rely on - an assumption we deliberately DO NOT rely on.
	# These monitors read zero under Jolt even while bodies are visibly falling, so
	# the stress harness ignores them. If they ever start working, that is worth
	# knowing, because they would be better than what we use instead.
	_expect_constant("Performance", "TIME_PHYSICS_PROCESS")
	_expect_constant("Performance", "PHYSICS_3D_ACTIVE_OBJECTS")

	_expect(
		Engine.physics_ticks_per_second == 60,
		"physics still ticks at 60 Hz - the spring damping maths assumes it",
	)


# --------------------------------------------------------------- section 3

func _check_godotsteam() -> void:
	print("[api] GodotSteam")

	if not Engine.has_singleton("Steam"):
		_fail("the Steam singleton is missing entirely - the GDExtension did not load")
		return

	var steam := Engine.get_singleton("Steam")

	# Argument counts matter here. The Steam transport runs rarely, so a changed
	# signature would fail on its first line, on a second machine, in the middle
	# of a validation run.
	_expect_signature(steam, "steamInitEx", 2)
	_expect_signature(steam, "createLobby", 2)
	_expect_signature(steam, "joinLobby", 1)
	_expect_signature(steam, "leaveLobby", 1)
	_expect_signature(steam, "run_callbacks", 0)
	_expect_signature(steam, "setGlobalConfigValueInt32", 2)
	_expect_signature(steam, "setGlobalConfigValueFloat", 2)

	# The transport connects to both of these, and a changed argument list would
	# silently never fire the handler.
	_expect_signal(steam, "lobby_created", 2)
	_expect_signal(steam, "lobby_joined", 4)

	for constant in [
		"LOBBY_TYPE_PUBLIC", "LOBBY_TYPE_FRIENDS_ONLY",
		"LOBBY_TYPE_INVISIBLE", "LOBBY_TYPE_PRIVATE",
		"NETWORKING_CONFIG_FAKE_PACKET_LAG_SEND", "NETWORKING_CONFIG_FAKE_PACKET_LAG_RECV",
		"NETWORKING_CONFIG_FAKE_PACKET_LOSS_SEND", "NETWORKING_CONFIG_FAKE_PACKET_LOSS_RECV",
	]:
		_expect_constant("Steam", constant)

	_expect_methods("SteamMultiplayerPeer", ["host_with_lobby", "connect_to_lobby"])


# --------------------------------------------------------------- section 4

func _check_decided_invariants() -> void:
	print("[api] invariants fixed by decisions")

	var crate_scene := load("res://scenes/goods/crate.tscn") as PackedScene
	if crate_scene == null:
		_fail("the crate scene will not load, so its invariants cannot be checked")
		return
	var crate := crate_scene.instantiate()

	# ADR 18: a Small is exactly a 0.5 m cube, eight to a 1.0 m cell. Grid-critical
	# geometry matches EXACTLY — getting this wrong is a snapping problem, not a
	# visual one. (ADR 16 set the same number for the superseded 0.5 m module; the
	# figure survived the supersession, the reasoning behind it did not.)
	var shape := crate.get_node("Collision").shape as BoxShape3D
	_expect(
		shape != null and shape.size.is_equal_approx(Vector3(0.5, 0.5, 0.5)),
		"ADR 18 - a Small crate is exactly 0.5 m, 8 to a cell (got %s)" % (shape.size if shape else "no shape"),
	)

	# ADR 14: 20 Hz on-change replication is what took host upstream from
	# 1497 kb/s to 93. Reverting it would not fail anything else.
	var sync := crate.get_node("Synchronizer") as MultiplayerSynchronizer
	_expect(
		sync != null and is_equal_approx(sync.replication_interval, 0.05),
		"ADR 14 - cargo still replicates at 20 Hz (got %s)" % (sync.replication_interval if sync else "no synchronizer"),
	)

	# Players deliberately do not share a mask with cargo. Undoing this brings
	# back the bulldozing: a puppet capsule shoving cargo with unlimited force.
	_expect(crate.collision_layer == 4, "cargo is on the cargo layer (got %d)" % crate.collision_layer)
	_expect(crate.collision_mask == 5, "cargo collides with world and cargo only (got %d)" % crate.collision_mask)

	# Phase 1: rack cell aim-volumes get their own physics layer rather than
	# joining cargo, so a rack full of cells never enters a shove or a carry
	# check. A NAME is worth asserting on its own, separately from the layer
	# existing: an unnamed layer is an anonymous bit in a .tscn, and the next
	# person to add a layer picks the same one rather than reading this far.
	_expect(str(ProjectSettings.get_setting("layer_names/3d_physics/layer_4", "")) == "storage",
			"physics layer 4 is named 'storage' - rack cell sensors live there")

	# GDD 6.1: solo drag runs at about 40% of walking pace. That penalty is the
	# entire reason two-player carry is worth organising, so it is a balance
	# number rather than a feel one - tune it knowingly, not by drift.
	_expect(
		is_equal_approx(crate.drag_speed_scale, 0.4),
		"GDD 6.1 - dragging still costs ~60%% of your speed (got %s)" % crate.drag_speed_scale,
	)
	# A Small must stay light enough for one person to lift, or the size classes
	# stop meaning anything: drag is meant to be the answer to Large, not to
	# everything. Checked as a relationship rather than two loose numbers, so
	# raising crate mass fails here instead of silently making Smalls undraggable.
	var crate_script := load("res://scripts/goods/crate.gd") as GDScript
	var constants: Dictionary = crate_script.get_script_constant_map() if crate_script != null else {}
	var solo_limit := float(constants.get("SOLO_CARRY_MASS_LIMIT", -1.0))
	_expect(
		solo_limit > 0.0 and crate.mass < solo_limit,
		"a Small is light enough to carry solo (mass %s vs limit %s)" % [crate.mass, solo_limit],
	)
	crate.free()

	# ADR 18: Medium and Large exist from 02-04, both inherited scenes sharing
	# crate.gd rather than duplicating it (see crate_medium.tscn's own
	# editor_description for why). Checked here for the same reason the Small
	# above is: a drifted dimension is a snapping problem, not a visual one.
	var medium_scene := load("res://scenes/goods/crate_medium.tscn") as PackedScene
	if medium_scene == null:
		_fail("the crate_medium scene will not load, so its invariants cannot be checked")
	else:
		var medium := medium_scene.instantiate()
		var medium_shape := medium.get_node("Collision").shape as BoxShape3D
		_expect(
			medium_shape != null and medium_shape.size.is_equal_approx(Vector3(1, 1, 1)),
			"ADR 18 - a Medium is exactly 1.0 m, one whole cell (got %s)" % (medium_shape.size if medium_shape else "no shape"),
		)
		var medium_mesh := (medium.get_node("BodyMesh") as MeshInstance3D).mesh as BoxMesh
		_expect(
			medium_mesh != null and medium_mesh.size.is_equal_approx(Vector3(1, 1, 1)),
			"ADR 18 - a Medium's mesh matches its collision, 1.0 m (got %s)" % (medium_mesh.size if medium_mesh else "no mesh"),
		)
		_expect(medium.mass > 0.0, "a Medium's fallback mass (pre-setup()) is positive (got %s)" % medium.mass)
		_expect(medium.collision_layer == 4, "a Medium is on the cargo layer (got %d)" % medium.collision_layer)
		_expect(medium.collision_mask == 5, "a Medium collides with world and cargo only (got %d)" % medium.collision_mask)
		var medium_sensor := (medium.get_node("PushSensor/SensorShape") as CollisionShape3D).shape as BoxShape3D
		_expect(
			medium_shape != null and medium_sensor != null
				and medium_sensor.size.x > medium_shape.size.x
				and medium_sensor.size.y > medium_shape.size.y
				and medium_sensor.size.z > medium_shape.size.z,
			"a Medium's PushSensor is strictly larger than its own body on every axis (body %s, sensor %s)" % [
				medium_shape.size if medium_shape else "?", medium_sensor.size if medium_sensor else "?",
			],
		)
		medium.free()

	var large_scene := load("res://scenes/goods/crate_large.tscn") as PackedScene
	if large_scene == null:
		_fail("the crate_large scene will not load, so its invariants cannot be checked")
	else:
		var large := large_scene.instantiate()
		var large_shape := large.get_node("Collision").shape as BoxShape3D
		_expect(
			large_shape != null and large_shape.size.is_equal_approx(Vector3(2, 1, 1)),
			"ADR 18 - a Large is exactly 2.0 x 1.0 x 1.0 m (got %s)" % (large_shape.size if large_shape else "no shape"),
		)
		# ADR 25 (d): the 2 m axis is local X - the convention 02-05 and 02-07
		# both rotate against, so it earns its own assertion rather than only
		# a comment in the scene.
		_expect(
			large_shape != null and is_equal_approx(large_shape.size.x, 2.0),
			"ADR 25 (d) - a Large's 2 m axis is local X (got %s)" % (large_shape.size if large_shape else "no shape"),
		)
		var large_mesh := (large.get_node("BodyMesh") as MeshInstance3D).mesh as BoxMesh
		_expect(
			large_mesh != null and large_mesh.size.is_equal_approx(Vector3(2, 1, 1)),
			"ADR 18 - a Large's mesh matches its collision, 2.0 x 1.0 x 1.0 (got %s)" % (large_mesh.size if large_mesh else "no mesh"),
		)
		# Belt and braces on top of 02-02's own catalogue assertion: the
		# catalogue guarantees every REAL Large record is heavy enough, and
		# this guarantees the SCENE's own fallback is too, so a Large spawned
		# without a record (there is no such caller today) could still never
		# be lifted.
		_expect(
			solo_limit > 0.0 and large.mass > solo_limit,
			"ADR 25 (c) - every Large exceeds the solo-lift limit, even the un-setup() scene fallback (mass %s vs limit %s)" % [large.mass, solo_limit],
		)
		_expect(large.collision_layer == 4, "a Large is on the cargo layer (got %d)" % large.collision_layer)
		_expect(large.collision_mask == 5, "a Large collides with world and cargo only (got %d)" % large.collision_mask)
		var large_sensor := (large.get_node("PushSensor/SensorShape") as CollisionShape3D).shape as BoxShape3D
		_expect(
			large_shape != null and large_sensor != null
				and large_sensor.size.x > large_shape.size.x
				and large_sensor.size.y > large_shape.size.y
				and large_sensor.size.z > large_shape.size.z,
			"a Large's PushSensor is strictly larger than its own body on every axis (body %s, sensor %s)" % [
				large_shape.size if large_shape else "?", large_sensor.size if large_sensor else "?",
			],
		)
		large.free()

	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	if player_scene == null:
		_fail("the player scene will not load, so its invariants cannot be checked")
		return
	var player := player_scene.instantiate()
	_expect(player.collision_layer == 2, "players are on the players layer (got %d)" % player.collision_layer)
	_expect(player.collision_mask == 3, "players collide with world and players, NOT cargo (got %d)" % player.collision_mask)

	var ray := player.get_node("CameraPivot/GrabRay") as RayCast3D
	# 12 = 4 (cargo) | 8 (storage): the grab ray looks for cargo AND rack cell
	# sensors from 01-04 onward, one ray resolving either kind of target.
	_expect(
		ray != null and ray.collision_mask == 12,
		"the grab ray looks for cargo and rack cell sensors (got %s)" % (ray.collision_mask if ray else "no ray"),
	)
	_expect(ray != null and ray.collide_with_areas, "the grab ray still sees Area3D cell volumes")
	_expect(
		ray != null and ray.hit_from_inside,
		"the grab ray still reports crates it starts inside - players walk through cargo",
	)
	# Wave 7 gate ruling, 2026-08-21 (NJ, after it came up in two separate gate
	# sessions): the whole reach chain read too long in play, shortened
	# 2.5 -> 2.0 m. GRAB_REACH and PLACE_REACH in carry_authority.gd move with
	# this number — see PLACE_REACH's own doc comment for the re-derived
	# arithmetic.
	_expect(
		ray != null and ray.target_position.is_equal_approx(Vector3(0.0, 0.0, -2.0)),
		"the grab ray reaches 2.0 m, not the original 2.5 (got %s)" % (ray.target_position if ray else "no ray"),
	)
	player.free()

	# 01-04: the rack's cell sensors are the aim target for storage, and the
	# aim code (Carrier._aim) resolves one via exactly one get_parent() call
	# on whatever Area3D the ray hit.
	var rack_scene := load("res://scenes/world/rack.tscn") as PackedScene
	if rack_scene == null:
		_fail("the rack scene will not load, so its invariants cannot be checked")
	else:
		var rack := rack_scene.instantiate()
		var sensor := rack.get_node_or_null("CellSensor0") as Area3D
		_expect(
			sensor != null and sensor.get_parent() == rack,
			"CellSensor0 is a direct child of the rack root (Carrier._aim does one get_parent())",
		)
		_expect(
			sensor != null and sensor.collision_layer == 8,
			"rack cell sensors are on the storage layer (got %s)" % (sensor.collision_layer if sensor else "no sensor"),
		)
		_expect(
			sensor != null and not sensor.monitoring and not sensor.monitorable,
			"rack cell sensors have monitoring and monitorable both off - " +
			"raycast hittability was measured independent of both, so 150+ " +
			"cell volumes cost nothing in overlap detection",
		)
		_expect(
			rack.get_node_or_null("RackedItems") != null,
			"the rack has a RackedItems container for its derived visuals",
		)

		# 01-06: the aim highlight has to exist on every rack, and start off -
		# a rack that ships with a cell permanently glowing is exactly the
		# kind of thing a headless run would never notice on its own.
		var highlight := rack.get_node_or_null("CellHighlight") as MeshInstance3D
		_expect(highlight != null, "the rack has a CellHighlight for aim feedback (01-06)")
		_expect(
			highlight != null and not highlight.visible,
			"the rack's CellHighlight starts hidden (got visible=%s)" % (highlight.visible if highlight else "no node"),
		)
		rack.free()

	# 01-04: a racked item must stay a bare mesh (ADR 14) - this is the
	# assertion that stops it quietly growing a body and reopening the cost a
	# rack of 96 Smalls as rigid bodies would be.
	var racked_item_scene := load("res://scenes/goods/racked_item.tscn") as PackedScene
	if racked_item_scene == null:
		_fail("the racked item scene will not load, so its invariants cannot be checked")
	else:
		var racked_item := racked_item_scene.instantiate()
		var has_collision := false
		for child in racked_item.get_children():
			if child is CollisionShape3D:
				has_collision = true
		_expect(not has_collision, "a racked item still has no CollisionShape3D of its own")
		var mesh := (racked_item as MeshInstance3D).mesh as BoxMesh
		_expect(
			mesh != null and mesh.size.is_equal_approx(Vector3(0.5, 0.5, 0.5)),
			"ADR 18 - a racked item's box is exactly 0.5 m, matching the Small it represents (got %s)" % (mesh.size if mesh else "no mesh"),
		)

		# 01-06: a silent placeholder is the exact failure this plan exists to
		# prevent, and nothing else would ever look at it - a scene missing
		# its stream would still load, instance and play a placement with no
		# sound, and nothing would say why.
		var place_sound := racked_item.get_node_or_null("PlaceSound") as AudioStreamPlayer3D
		_expect(place_sound != null, "a racked item has a PlaceSound for its placement thud (01-06)")
		_expect(
			place_sound != null and place_sound.stream != null,
			"the PlaceSound's stream is not null (got %s)" % (place_sound.stream if place_sound else "no player"),
		)
		racked_item.free()

	# Two is the two-player carry ceiling, expressed in the data shape.
	#
	# Read through the constant map rather than as `Crate.MAX_HOLDERS`. A static
	# reference makes this script compile-depend on crate.gd, which needs the Net
	# autoload — and autoloads are not registered in a `--script` run, so the whole
	# file failed to compile *after* reporting a pass. Loading at runtime is what
	# the smoke layer does, for the same reason.
	_expect(
		int(constants.get("MAX_HOLDERS", -1)) == 2,
		"two holders remains the carry ceiling (got %s)" % constants.get("MAX_HOLDERS", "missing"),
	)

	# 02-03 / RUN-02: the day clock's own bounds, not its value — ADR 25 (f)
	# deliberately leaves day_length_seconds unagreed, so pinning today's
	# default would fail the moment NJ tunes it in play, which is the
	# opposite of what this section is for.
	var clock_scene := load("res://scenes/world/day_clock.tscn") as PackedScene
	if clock_scene == null:
		_fail("the day clock scene will not load, so its invariants cannot be checked")
	else:
		var clock := clock_scene.instantiate()
		_expect(
			clock.day_length_seconds >= 360.0 and clock.day_length_seconds <= 600.0,
			"RUN-02 - a day runs in 6-10 minutes (got %s)" % clock.day_length_seconds,
		)
		_expect(
			clock.open_fraction >= 0.5 and clock.open_fraction <= 0.8,
			"ADR 25 (f) - roughly two-thirds of the day is open trading (got %s)" % clock.open_fraction,
		)
		_expect(
			clock.morning_seconds >= 20.0,
			"the morning ceremony (02-06) needs at least 20s to spread a delivery across (got %s)" % clock.morning_seconds,
		)
		clock.free()


# --------------------------------------------------------------- helpers

func _expect(condition: bool, label: String) -> void:
	_checked += 1
	if condition:
		print("[api] ok   %s" % label)
		return
	_fail(label)


func _fail(label: String) -> void:
	print("[api] FAIL %s" % label)
	_failures.append(label)


## Both of these pass `no_inheritance = false` deliberately. The question being
## asked is "can the code call this on an instance", and an inherited member
## answers yes — collision_layer lives on CollisionObject3D, not on
## CharacterBody3D, and excluding it reported a break that was not real.
func _expect_methods(cls: String, methods: Array) -> void:
	for method in methods:
		_expect(ClassDB.class_has_method(cls, method, false), "%s.%s()" % [cls, method])


func _expect_properties(cls: String, properties: Array) -> void:
	var found := {}
	for entry in ClassDB.class_get_property_list(cls, false):
		found[entry["name"]] = true
	for property in properties:
		_expect(found.has(property), "%s.%s" % [cls, property])


func _expect_constant(cls: String, constant: String) -> void:
	_expect(ClassDB.class_has_integer_constant(cls, constant), "%s.%s" % [cls, constant])


func _expect_signature(object: Object, method: String, arg_count: int) -> void:
	for entry in object.get_method_list():
		if entry["name"] == method:
			var actual: int = (entry["args"] as Array).size()
			_expect(actual == arg_count, "Steam.%s() takes %d args (got %d)" % [method, arg_count, actual])
			return
	_expect(false, "Steam.%s() exists" % method)


func _expect_signal(object: Object, signal_name: String, arg_count: int) -> void:
	for entry in object.get_signal_list():
		if entry["name"] == signal_name:
			var actual: int = (entry["args"] as Array).size()
			_expect(actual == arg_count, "Steam signal %s has %d args (got %d)" % [signal_name, arg_count, actual])
			return
	_expect(false, "Steam signal %s exists" % signal_name)
