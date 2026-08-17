extends SceneTree

## Smoke layer: does the project still load at all?
##
## Loads every scene under res://scenes/, which forces every attached script to
## parse and every ext_resource path to resolve, then instances each one so
## @onready node paths and exported defaults are exercised too.
##
## Deliberately does no networking, so it can never fight a live play session for
## a port, and it is the fastest way to catch the two mistakes that have actually
## happened here: a moved file leaving a stale path, and a new class_name being
## invisible until the editor rescans.
##
## Run via tools/run-tests.ps1. Exits 0 on pass, 1 on any failure.

const SCENE_ROOT := "res://scenes"

var _failures: Array[String] = []
var _checked := 0


func _initialize() -> void:
	var paths := _find_scenes(SCENE_ROOT)
	paths.sort()

	if paths.is_empty():
		_fail("found no scenes under %s at all — wrong path?" % SCENE_ROOT)

	for path in paths:
		_check(path)

	print("")
	if _failures.is_empty():
		print("[smoke] PASS — %d scenes loaded and instanced" % _checked)
		quit(0)
		return

	print("[smoke] FAIL — %d of %d scenes broken" % [_failures.size(), _checked])
	for line in _failures:
		print("  %s" % line)
	quit(1)


func _check(path: String) -> void:
	_checked += 1

	var packed := load(path) as PackedScene
	if packed == null:
		_fail("%s — did not load as a PackedScene" % path)
		return

	# Instancing is the half that catches broken node paths, which a plain load
	# will happily let through.
	var instance := packed.instantiate()
	if instance == null:
		_fail("%s — loaded but would not instance" % path)
		return

	print("[smoke] ok  %-42s root=%s (%s)" % [path, instance.name, instance.get_class()])
	instance.free()


func _fail(message: String) -> void:
	_failures.append(message)


func _find_scenes(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		_fail("could not open %s" % dir_path)
		return found

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			found.append_array(_find_scenes(full))
		elif entry.ends_with(".tscn"):
			found.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return found
