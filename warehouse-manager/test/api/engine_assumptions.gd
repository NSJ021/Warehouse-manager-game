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


func _initialize() -> void:
	_check_engine_apis()
	_check_engine_behaviours()
	_check_godotsteam()
	_check_decided_invariants()
	_build_aim_scene()


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	_check_aim_behaviour()
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


## Storage slots are aim targets, not detectors. Phase 1 plans to raycast against
## Area3D slot volumes with monitoring and monitorable both OFF, so that 150-odd
## slots cost nothing in collision detection while still being aimable at.
##
## Measured before relying on it: hittability is independent of both flags. If a
## future engine version ever couples them, every slot silently starts paying for
## detection it never reads, and aiming would keep working — so nothing would look
## wrong. That is exactly the kind of regression worth an assertion.
func _build_aim_scene() -> void:
	var world := Node3D.new()
	get_root().add_child(world)

	var x := 0.0
	for case in [
		["slot area is aimable with monitoring ON", true, true],
		["slot area is aimable with monitoring OFF", false, true],
		["slot area is aimable with monitoring AND monitorable OFF", false, false],
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
	print("[api] aiming at storage slots")
	_expect_properties("RayCast3D", ["collide_with_areas", "collide_with_bodies"])
	for entry in _aim_cases:
		var ray: RayCast3D = entry[1]
		ray.force_raycast_update()
		var hit: bool = ray.is_colliding() and ray.get_collider() == entry[2]
		_expect(hit, entry[0])


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

	_expect_methods("CharacterBody3D", ["move_and_slide", "is_on_floor"])
	_expect_properties("CharacterBody3D", ["velocity", "collision_layer", "collision_mask"])


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

	# ADR 16: the grid module is 0.5 m and grid-critical geometry matches it
	# EXACTLY. Getting this wrong is a snapping problem, not a visual one.
	var shape := crate.get_node("Collision").shape as BoxShape3D
	_expect(
		shape != null and shape.size.is_equal_approx(Vector3(0.5, 0.5, 0.5)),
		"ADR 16 - the crate is exactly 0.5 m on the grid module (got %s)" % (shape.size if shape else "no shape"),
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
	crate.free()

	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	if player_scene == null:
		_fail("the player scene will not load, so its invariants cannot be checked")
		return
	var player := player_scene.instantiate()
	_expect(player.collision_layer == 2, "players are on the players layer (got %d)" % player.collision_layer)
	_expect(player.collision_mask == 3, "players collide with world and players, NOT cargo (got %d)" % player.collision_mask)

	var ray := player.get_node("CameraPivot/GrabRay") as RayCast3D
	_expect(ray != null and ray.collision_mask == 4, "the grab ray still looks for cargo only")
	_expect(
		ray != null and ray.hit_from_inside,
		"the grab ray still reports crates it starts inside - players walk through cargo",
	)
	player.free()

	# Two is the two-player carry ceiling, expressed in the data shape.
	#
	# Read through the constant map rather than as `Crate.MAX_HOLDERS`. A static
	# reference makes this script compile-depend on crate.gd, which needs the Net
	# autoload — and autoloads are not registered in a `--script` run, so the whole
	# file failed to compile *after* reporting a pass. Loading at runtime is what
	# the smoke layer does, for the same reason.
	var crate_script := load("res://scripts/goods/crate.gd") as GDScript
	var constants: Dictionary = crate_script.get_script_constant_map() if crate_script != null else {}
	_expect(
		int(constants.get("MAX_HOLDERS", -1)) == 2,
		"two holders remains the carry ceiling (got %s)" % constants.get("MAX_HOLDERS", "missing"),
	)


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
