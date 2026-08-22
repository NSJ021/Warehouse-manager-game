class_name DockDoor
extends Node3D

## The roller door: commerce's own half of ADR 25 (f). Derives its own
## position from the day clock's replicated phase, exactly the way
## [GoodsZone] derives its contents from cargo transforms [Crate] already
## replicates — see that class's own doc comment for the same reasoning
## applied the other way round. [b]No spawner, no synchronizer, and no remote
## procedure call anywhere in this file.[/b] If a door's position ever needs
## to be on the wire, something upstream has stopped being replicated, and
## that is the bug to fix, not this file.
##
## [b]Governs commerce, not people.[/b] Trucks and clients live by this door;
## a player never has to. `test_room.tscn` carries a second, permanent,
## doorless opening in a different wall — the personnel gap — for exactly
## the reason ADR 25 (f) states plainly: locking a player out of their own
## warehouse is a punishment this game has never chosen to make anywhere
## else, and a door that traps someone is a bug report, not a mechanic. This
## file has no opinion about that gap; it exists purely as level geometry.
##
## Resolves [DayClock] lazily by group at the moment of use, never cached in
## `_ready()` — the same reason [method Rack._on_impact] gives for doing the
## same with [code]CarryAuthority[/code]: a cached reference can be null on
## the first frame on some peers, depending on sibling initialisation order.

## How wide the opening is. Exported so a level can size it; `test_room.tscn`
## cuts its north wall to match this default exactly (a 3.0 m gap centred on
## `GoodsIn`'s own x).
@export var door_width := 3.0
## How tall the slab is — matches `test_room.tscn`'s own wall height (4.0 m)
## by default, so a closed door reads as an unbroken wall rather than leaving
## a permanent gap above it.
@export var door_height := 4.0
## Seconds for a full open-to-closed (or reverse) travel. Long enough to read
## as a real door moving, short enough that "the door is opening" is never
## the bottleneck on a morning.
@export var travel_seconds := 2.5

## The scene bakes [member Slab]'s [CollisionShape3D] and [MeshInstance3D] to
## match these two exports' own defaults. Retuning [member door_width] or
## [member door_height] in the inspector moves the open/closed math below but
## does NOT resize the baked shape or mesh to match — a one-line follow-up
## for whoever tunes this in play, not done here because this level has
## exactly one door and Phase 6 rebuilds the art anyway.

@onready var _slab: AnimatableBody3D = $Slab
@onready var _klaxon: AudioStreamPlayer3D = $Klaxon
@onready var _path_sensor: Area3D = $PathSensor

## The slab's own local Y when the door is shut — half [member door_height],
## so a [member door_height]-tall slab exactly fills the opening from the
## floor up.
var _closed_y := 0.0
## The slab's own local Y when fully open — [member _closed_y] plus a whole
## [member door_height], so the slab clears the opening exactly rather than
## leaving a sliver of itself still in the doorway.
var _open_y := 0.0
## What [method _find_clock] last reported [method DayClock.is_open] as —
## the edge this file wakes blocking cargo on, not "is open" itself, so the
## wake happens once, right as a close begins, rather than every frame the
## door is shut.
var _was_open := false


func _ready() -> void:
	add_to_group("dock_doors")
	_closed_y = door_height / 2.0
	_open_y = _closed_y + door_height
	_slab.position.y = _closed_y

	# Host-only, the same split Crate.PushSensor and Rack.ImpactSensor both
	# already use — a client running detection it never reads is pure waste.
	if not Net.is_host():
		_path_sensor.monitoring = false


func _physics_process(delta: float) -> void:
	var clock := _find_clock()
	if clock == null:
		return

	# Lazily connected rather than cached in _ready() (see class doc) — the
	# is_connected guard is the same idiom CarryAuthority.request_grab uses
	# for a crate's own signals, so repeatedly finding the same clock never
	# double-connects.
	if not clock.doors_closing.is_connected(_on_doors_closing):
		clock.doors_closing.connect(_on_doors_closing)

	var open_now := clock.is_open()
	if Net.is_host() and _was_open and not open_now:
		_wake_blocking_cargo()
	_was_open = open_now

	# Lerped toward a target every frame rather than driven by a Tween — a
	# late joiner arriving mid-SHIFT must snap toward open immediately, and a
	# Tween started from an assumed closed state would animate from the
	# wrong place. Moving toward a target is self-correcting for free: every
	# peer's own door converges on the truth from wherever it happens to be.
	var target_y := _open_y if open_now else _closed_y
	var step := (door_height / maxf(travel_seconds, 0.01)) * delta
	_slab.position.y = move_toward(_slab.position.y, target_y, step)


## Run on every peer, from the signal each peer's own [DayClock] emits
## locally (see that class's own doc comment on why a client derives this
## rather than waiting for a round trip). An audio cue is presentation, so no
## RPC — and per ADR 25 (f), audio is never the only channel: the HUD
## (`main.gd`) carries the same warning as on-screen text, because a klaxon
## nobody happens to be near must never be the only warning that the door is
## closing.
func _on_doors_closing(_seconds_left: float) -> void:
	_klaxon.play()


## Host-only, called the instant [method DayClock.is_open] flips true→false —
## see [member _was_open]. A settled crate is [constant
## RigidBody3D.FREEZE_MODE_STATIC] (ADR 17), and an [AnimatableBody3D] cannot
## displace one — it would drive straight through instead of shoving it clear
## (measured in `test/api/engine_assumptions.gd`). Waking it first is what
## makes the door push it out for real rather than clipping through it.
func _wake_blocking_cargo() -> void:
	for body in _path_sensor.get_overlapping_bodies():
		var crate := body as Crate
		if crate != null:
			crate.wake()


func _find_clock() -> DayClock:
	return get_tree().get_first_node_in_group("day_clock") as DayClock
