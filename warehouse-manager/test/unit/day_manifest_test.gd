extends SceneTree

## Unit layer: [DayManifest] and [DaySchedule] — ADR 25 (e)/(f)'s scripted day.
##
## Follows test/unit/storage_grid_test.gd and cargo_taxonomy_test.gd's own
## precedent exactly: run once against a project with neither
## scripts/goods/day_manifest.gd nor scripts/goods/day_schedule.gd, and watch
## it fail by NAMING the missing file rather than throwing a parse error about
## an unknown type — the load() guards below are why this file loads those two
## with load() rather than a static class_name reference to either.
## CargoCatalogue and StorageGrid already exist (Phase 1/02-02, no autoload
## dependency) and are referenced statically, the same distinction
## cargo_taxonomy_test.gd already draws for CargoCondition/Dilemma.
##
## Two kinds of check, same split as every other file in this layer:
## arithmetic (a manifest round-trips, a row names a legal category/size,
## a date lands strictly after today) and design properties — determinism,
## and the three delivery caps genuinely holding across a real sweep rather
## than at one hand-picked day. The second half is what a later balance
## retune could break silently, so it is asserted directly.
##
## Run via tools/run-tests.ps1. Exits 0 on pass, 1 on any failure.

const DAY_MANIFEST_PATH := "res://scripts/goods/day_manifest.gd"
const DAY_SCHEDULE_PATH := "res://scripts/goods/day_schedule.gd"

## Matches the guard's own instruction: swept across days 1-30, several seeds.
const SWEEP_DAYS := 30
const SWEEP_SEEDS := [1, 7, 1337, 90210]
## A realistic crew range — never more than ADR 6's four-player ceiling.
const SWEEP_CREW_SIZES := [1, 2, 4]

var _failures: Array[String] = []
var _checked := 0

var _manifest_script: GDScript
var _schedule_script: GDScript


func _initialize() -> void:
	_manifest_script = load(DAY_MANIFEST_PATH) as GDScript
	_schedule_script = load(DAY_SCHEDULE_PATH) as GDScript

	if _manifest_script == null:
		print("[unit] FAIL day_manifest.gd not found at %s - has it been written yet?" % DAY_MANIFEST_PATH)
		_failures.append("day_manifest.gd not found")
	if _schedule_script == null:
		print("[unit] FAIL day_schedule.gd not found at %s - has the editor rescanned the class cache?" % DAY_SCHEDULE_PATH)
		_failures.append("day_schedule.gd not found")

	if _manifest_script != null and _schedule_script != null:
		_check_row_shape()
		_check_determinism()
		_check_days_differ()
		_check_crew_scaling()
		_check_locked_rows_consume_budget()
		_check_locked_rows_overflow()
		_check_cap_sweep()
		_check_due_and_overdue_boundaries()
		_check_round_trip()

	_report()


# ------------------------------------------------------- arithmetic / shape

## Every row names a category CargoCatalogue actually has, and a size that
## category actually offers (white_goods has no Small — a row asking for one
## would spawn nothing and the day would silently under-deliver), and a
## store_until_day strictly after the day it was authored on (a same-morning
## collection is not a contract, it is a bug).
func _check_row_shape() -> void:
	print("[unit] a scripted day - every row names a legal category/size/date")

	for day in range(1, SWEEP_DAYS + 1):
		var manifest = _schedule_script.manifest_for(day, [], SWEEP_SEEDS[0], 2)
		for row in (manifest.deliveries as Array):
			var r := row as Dictionary
			var category: StringName = r["category"]
			var size: int = int(r["size"])
			_expect(
				category in _catalogue_categories(),
				"day %d: row names a real category (got %s)" % [day, category],
			)
			_expect(
				size in _catalogue_sizes(category),
				"day %d: %s's row asks for a size the catalogue actually offers (got %d)" % [day, category, size],
			)
			_expect(
				int(r["store_until_day"]) > day,
				"day %d: store_until_day (%d) is strictly after today" % [day, int(r["store_until_day"])],
			)
			_expect(
				int(r["count"]) > 0,
				"day %d: a kept row always has a positive count (got %d)" % [day, int(r["count"])],
			)


# --------------------------------------------------------------- determinism

## manifest_for is deterministic: the same (day, locked_rows, seed, crew_size)
## gives an identical manifest, compared via to_dict() - not merely "the same
## number of rows."
func _check_determinism() -> void:
	print("[unit] manifest_for is deterministic")

	var a = _schedule_script.manifest_for(5, [], 42, 2)
	var b = _schedule_script.manifest_for(5, [], 42, 2)
	_expect(
		(a.to_dict() as Dictionary) == (b.to_dict() as Dictionary),
		"the same (day, seed, locked_rows, crew_size) reproduces the same manifest byte for byte",
	)

	var locked := [_row(&"masonry", &"reclaimed_brick", 0, 3, 8, &"acme_traders")]
	var c = _schedule_script.manifest_for(5, locked, 42, 2)
	var d = _schedule_script.manifest_for(5, locked, 42, 2)
	_expect(
		(c.to_dict() as Dictionary) == (d.to_dict() as Dictionary),
		"determinism holds with locked rows present too",
	)


## Different days give different manifests - or the "schedule" is a constant,
## which would defeat the entire point of a scripted day.
func _check_days_differ() -> void:
	print("[unit] different days give different manifests")

	var seen: Dictionary = {}
	var any_different := false
	for day in range(1, 11):
		var manifest = _schedule_script.manifest_for(day, [], 99, 2)
		var key := JSON.stringify(manifest.to_dict())
		if not seen.is_empty() and not seen.has(key):
			any_different = true
		seen[key] = true
	_expect(any_different, "at least one of ten consecutive days differs from the others")


## ADR 25 (f): every cap scales with crew size. Same (day, seed, locked_rows)
## across crew sizes can only ever authorize MORE crates at a larger crew,
## never fewer, since the exact same randomly-authored rows are clamped
## against a looser cap - and at least one day must actually show a
## difference, or the scaling would be dead code.
func _check_crew_scaling() -> void:
	print("[unit] the delivery caps scale with crew size")

	var any_scaled := false
	for day in range(1, SWEEP_DAYS + 1):
		var solo = _schedule_script.manifest_for(day, [], 555, 1)
		var full_crew = _schedule_script.manifest_for(day, [], 555, 4)
		_expect(
			full_crew.total_crates() >= solo.total_crates(),
			"day %d: a 4-player day is never smaller than a solo day for the same seed (solo %d, 4p %d)" % [
				day, solo.total_crates(), full_crew.total_crates(),
			],
		)
		if full_crew.total_crates() > solo.total_crates():
			any_scaled = true
	_expect(any_scaled, "at least one swept day is actually bigger at full crew than solo")


# ---------------------------------------------------------- locked rows

## A locked row is not optional (ADR 25 (e)): it always appears in the output,
## and it always consumes the same ROWS_PER_DAY budget a scripted row would -
## a manifest with N locked rows has room for at most ROWS_PER_DAY - N
## scripted ones.
func _check_locked_rows_consume_budget() -> void:
	print("[unit] locked rows always appear and always consume the row budget")

	var rows_per_day: int = _schedule_script.ROWS_PER_DAY
	for locked_count in range(0, rows_per_day + 1):
		var locked: Array = []
		for i in locked_count:
			locked.append(_row(&"tinned", &"tinned_soup", 0, 1, 8 + i, &"kemp_and_sons"))

		var manifest = _schedule_script.manifest_for(9, locked, 7, 2)
		_expect(
			manifest.locked_rows.size() == locked_count,
			"%d locked rows in means %d locked rows out (got %d)" % [locked_count, locked_count, manifest.locked_rows.size()],
		)
		_expect(
			manifest.deliveries.size() <= rows_per_day - locked_count,
			"with %d locked rows, at most %d scripted rows remain (got %d)" % [
				locked_count, rows_per_day - locked_count, manifest.deliveries.size(),
			],
		)


## ADR 25 (e)'s own death-spiral case, named rather than left to be
## discovered: owing more redeliveries than a day can hold. They fill the day
## entirely (every row slot is a locked one, zero scripted content) and the
## excess is recorded as deferred rather than silently vanishing.
func _check_locked_rows_overflow() -> void:
	print("[unit] locked rows exceeding the day's budget fill it and defer the rest")

	var rows_per_day: int = _schedule_script.ROWS_PER_DAY
	var overflow_by := 3
	var locked: Array = []
	for i in (rows_per_day + overflow_by):
		locked.append(_row(&"powders", &"cement_mix", 0, 2, 10 + i, &"riverside_wholesale"))

	var manifest = _schedule_script.manifest_for(4, locked, 3, 2)
	_expect(
		manifest.locked_rows.size() == rows_per_day,
		"locked rows fill the day entirely when there are more than it can hold (got %d, want %d)" % [
			manifest.locked_rows.size(), rows_per_day,
		],
	)
	_expect(
		manifest.deliveries.is_empty(),
		"a day fully owed to locked rows has zero scripted content (got %d rows)" % manifest.deliveries.size(),
	)
	_expect(
		manifest.locked_rows_deferred.size() == overflow_by,
		"the excess is deferred, not dropped (got %d, want %d)" % [manifest.locked_rows_deferred.size(), overflow_by],
	)


# ------------------------------------------------------------------ the caps

## The guard this plan exists to satisfy: all three caps hold for every day
## 1-30 across several seeds, each axis checked SEPARATELY - a sweep that only
## checked the total would pass a day of nothing but Larges, which is
## precisely the day that cannot fit in the building. Caps are read from
## DaySchedule's own DEFAULT_*_CAP_PER_PLAYER constants rather than
## hard-coded, so retuning them at the 02-11 gate cannot turn this sweep red.
func _check_cap_sweep() -> void:
	print("[unit] all three delivery caps hold - days 1-%d, %d seeds" % [SWEEP_DAYS, SWEEP_SEEDS.size()])

	var body_per_player: float = _schedule_script.DEFAULT_BODY_CAP_PER_PLAYER
	var cell_per_player: float = _schedule_script.DEFAULT_CELL_EQUIVALENT_CAP_PER_PLAYER
	var large_per_player: float = _schedule_script.DEFAULT_LARGE_CAP_PER_PLAYER
	var medium_per_player: float = _schedule_script.DEFAULT_MEDIUM_CAP_PER_PLAYER

	var swept := 0
	for seed_value in SWEEP_SEEDS:
		for crew_size in SWEEP_CREW_SIZES:
			var body_cap := int(round(body_per_player * crew_size))
			var cell_cap := cell_per_player * float(crew_size)
			var large_cap := int(round(large_per_player * crew_size))
			var medium_cap := int(round(medium_per_player * crew_size))

			for day in range(1, SWEEP_DAYS + 1):
				swept += 1
				var manifest = _schedule_script.manifest_for(day, [], seed_value, crew_size)
				var rows: Array = manifest.all_rows()

				var bodies := 0
				var cells := 0.0
				var larges := 0
				var mediums := 0
				for row in rows:
					var r := row as Dictionary
					var size := int(r["size"])
					var count := int(r["count"])
					bodies += count
					cells += _cell_equivalent(size) * float(count)
					if size == _size_large():
						larges += count
					elif size == _size_medium():
						mediums += count

				_expect(
					bodies <= body_cap,
					"seed %d crew %d day %d: body count within cap (got %d, cap %d)" % [seed_value, crew_size, day, bodies, body_cap],
				)
				_expect(
					cells <= cell_cap + 0.0001,
					"seed %d crew %d day %d: cell-equivalents within cap (got %.3f, cap %.3f)" % [seed_value, crew_size, day, cells, cell_cap],
				)
				_expect(
					larges <= large_cap,
					"seed %d crew %d day %d: Large count within its own composition cap (got %d, cap %d)" % [seed_value, crew_size, day, larges, large_cap],
				)
				_expect(
					mediums <= medium_cap,
					"seed %d crew %d day %d: Medium count within its own composition cap (got %d, cap %d)" % [seed_value, crew_size, day, mediums, medium_cap],
				)
	print("[unit]      swept %d (seed, crew, day) combinations" % swept)


# --------------------------------------------------------- due / overdue

## The boundary rule that makes a missed collection un-forgettable: due on
## the exact day, still due the day after, overdue only strictly after.
func _check_due_and_overdue_boundaries() -> void:
	print("[unit] due_today / overdue - boundary behaviour")

	var records: Array = [
		{"store_until_day": 5}, ## due exactly today
		{"store_until_day": 3}, ## missed two days ago - still due, not forgotten
		{"store_until_day": 6}, ## due tomorrow - not yet
	]

	var due: Array = _manifest_script.due_today(records, 5)
	_expect(due.size() == 2, "due_today(day=5) includes the exact-day and the already-missed row (got %d)" % due.size())

	var overdue: Array = _manifest_script.overdue(records, 5)
	_expect(overdue.size() == 1, "overdue(day=5) is strictly-late only, not the exact-day row too (got %d)" % overdue.size())
	_expect(
		int((overdue[0] as Dictionary)["store_until_day"]) == 3,
		"the one overdue record is the one actually missed two days ago",
	)

	var due_tomorrow: Array = _manifest_script.due_today(records, 6)
	_expect(due_tomorrow.size() == 3, "by day 6 every record above is due (got %d)" % due_tomorrow.size())


# ------------------------------------------------------------- round trip

## to_dict() / from_dict() round-trips a manifest with locked rows intact -
## the shape that crosses day_clock.gd's own @rpc unchanged.
func _check_round_trip() -> void:
	print("[unit] DayManifest.to_dict() / from_dict() round-trips locked rows intact")

	var manifest = _manifest_script.new()
	manifest.day = 12
	manifest.deliveries = [_row(&"glassware", &"wine_glasses_nice", 0, 4, 15, &"acme_traders")]
	manifest.locked_rows = [_row(&"masonry", &"breeze_blocks", 1, 2, 13, &"kemp_and_sons")]
	manifest.locked_rows_deferred = [_row(&"powders", &"cement_mix", 0, 1, 14, &"riverside_wholesale")]
	manifest.binding_cap = "cell_equivalent"

	var data: Dictionary = manifest.to_dict()
	for key in data.keys():
		var value = data[key]
		_expect(
			typeof(value) in [TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME, TYPE_BOOL, TYPE_ARRAY],
			"to_dict()'s field '%s' is a wire-safe type (got %s)" % [key, type_string(typeof(value))],
		)

	var restored = _manifest_script.from_dict(data)
	_expect(restored.day == manifest.day, "day survives (got %s, want %s)" % [restored.day, manifest.day])
	_expect(
		(restored.deliveries as Array) == (manifest.deliveries as Array),
		"deliveries survive intact",
	)
	_expect(
		(restored.locked_rows as Array) == (manifest.locked_rows as Array),
		"locked_rows survive intact",
	)
	_expect(
		(restored.locked_rows_deferred as Array) == (manifest.locked_rows_deferred as Array),
		"locked_rows_deferred survives intact",
	)
	_expect(
		restored.binding_cap == manifest.binding_cap,
		"binding_cap survives (got %s, want %s)" % [restored.binding_cap, manifest.binding_cap],
	)
	_expect(
		restored.total_crates() == manifest.total_crates(),
		"total_crates() agrees before and after the round trip",
	)


# ------------------------------------------------------------------- helpers

func _row(category: StringName, variant: StringName, size: int, count: int, store_until_day: int, owner: StringName) -> Dictionary:
	return {
		"category": category, "variant": variant, "size": size, "count": count,
		"store_until_day": store_until_day, "owner": owner,
	}


func _catalogue_categories() -> Array[StringName]:
	return CargoCatalogue.categories()


func _catalogue_sizes(category: StringName) -> Array[int]:
	return CargoCatalogue.available_sizes(category)


func _cell_equivalent(size: int) -> float:
	if size == _size_large():
		return 2.0
	if size == _size_medium():
		return 1.0
	return 1.0 / float(StorageGrid.SMALLS_PER_CELL)


## CargoCatalogue.Size's fixed ordinals (ADR 18: exactly three size classes,
## declaration order SMALL/MEDIUM/LARGE) - used as plain ints the same way
## cargo_taxonomy_test.gd's own SIZE_* constants do, rather than reaching into
## the enum directly, since this file otherwise has no reason to import it.
func _size_medium() -> int:
	return 1


func _size_large() -> int:
	return 2


func _expect(condition: bool, label: String) -> void:
	_checked += 1
	if condition:
		print("[unit] ok   %s" % label)
		return
	_failures.append(label)
	print("[unit] FAIL %s" % label)


func _report() -> void:
	if _failures.is_empty():
		print("[unit] PASS - %d checks on the scripted day and its manifest" % _checked)
		quit(0)
		return
	print("[unit] FAIL - %d of %d checks failed" % [_failures.size(), _checked])
	for failure in _failures:
		print("[unit]      %s" % failure)
	quit(1)
