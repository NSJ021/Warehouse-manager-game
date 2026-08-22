class_name DaySchedule
extends RefCounted

## The scripted-day author (ADR 25 (e)/(f)) — Phase 4's offer sheet replaces
## this file, not [DayManifest]'s own shape. Pure and all-static: no nodes, no
## `get_tree()`, no `Net` — see [DayManifest]'s own class doc for why that
## matters (a bare `--script` unit test, and a value that has to cross an
## `@rpc` unchanged).
##
## [b]Deliberately does NOT read [code]Net.players.size()[/code] itself.[/b]
## `docs/project-structure.md`'s autoload-avoidance ladder is why: a pure
## module reaching into an autoload cannot load in a bare `--script` run at
## all (the exact trap `test/api/engine_assumptions.gd`'s own README section
## names). [method manifest_for] takes [param crew_size] as a plain int
## instead — [code]DayClock[/code] (which already touches `Net` everywhere
## else in this codebase) is the one place that reads the real roster size
## and passes it in.
##
## [b]A genuine deviation from this plan's own literal text, verified rather
## than assumed:[/b] the plan asks for the three delivery caps to be
## `@export` vars on this file. Tried directly — `@export static var
## body_cap := 60` — and the engine's own parser refuses it outright:
## [code]Parse Error: Annotation "@export" cannot be applied to a static
## variable.[/code] (confirmed with a throwaway probe script, run and
## deleted, the same "check, never assume" rule this project holds itself
## to elsewhere). `@export` only ever means "an instance property the
## inspector can edit," and this file has no instance for one to live on — it
## is all static by design, per the plan's own instruction, so the two
## requirements are mutually exclusive as written.
##
## The fix keeps both of the REASONS the plan gives for wanting `@export`
## rather than `const` — inspector-tunable at the 02-11 gate, and mutable at
## runtime by a future Phase 4 event (a second truck) without a new system —
## by moving the actual exported values onto [DayClock] (already a `Node` in
## the scene, already carrying [member DayClock.day_length_seconds] as the
## exact same kind of "ADR fixes the rule, not the number" tunable). This
## file keeps the `DEFAULT_*_CAP` constants below as the one named source of
## truth for what "untuned" means — [DayClock]'s own exports default to
## these, and `test/unit/day_manifest_test.gd`'s sweep reads them from here
## rather than copying the numbers, so retuning [DayClock]'s exports in the
## editor cannot silently desync from what the test believes the defaults are.

## A shape, not a balance number — four rows is "a manifest posted on a
## wall reads as a handful of decisions," independent of whatever the caps
## below are tuned to.
const ROWS_PER_DAY := 4

## Untuned defaults for the three delivery caps (ADR 25 (f)) — see this
## file's own class doc for why these are consts here and `@export` vars on
## [DayClock] instead of on this file. Every one is PER PLAYER; [method
## manifest_for] multiplies by [param crew_size] itself, so a solo run and a
## four-player run are never asked to clear the same day.
##
## Starting guesses, not decisions — exactly [member DayClock.day_length_seconds]'s
## own standing, and settled the same way: at the 02-11 gate, in play, against
## the four feel criteria ADR 25 (f) names (worthy, deliberate, achievable,
## earning your pay), not by reasoning about them here.
##
## [b]Guards ADR 14's ~150-body envelope, size-blind[/b] — a Large costs the
## solver the same ~40 microseconds per frame as a Small, awake or asleep
## (01-09's re-measurement). 6/player keeps a 4-player day's ~24 new bodies
## (atop whatever floor stock already exists) far under that ceiling even
## before anything has settled static.
const DEFAULT_BODY_CAP_PER_PLAYER := 6
## A DIFFERENT axis from the body cap, and the one that decides whether a day
## physically fits the building — [code]storage_grid.gd[/code]'s own
## `SMALLS_PER_CELL` (8) is what makes a Small ⅛ of a cell, a Medium a whole
## one, and a Large two: a 16x spread the body cap alone cannot see (ADR 18's
## own "fees price volume, not items" precedent, applied to a delivery cap
## rather than a storage fee).
const DEFAULT_CELL_EQUIVALENT_CAP_PER_PLAYER := 2.0
## Per-size composition limits — NJ's own addition, independent of the other
## two: nothing about a body cap or a cell-equivalent cap alone rules out an
## absurd delivery that is technically legal by both (every Large is a
## two-person job; a day authored as nothing but Larges would be legal under
## the other two axes and still undoable).
const DEFAULT_LARGE_CAP_PER_PLAYER := 1
const DEFAULT_MEDIUM_CAP_PER_PLAYER := 2

## How far out a store-until date lands, in days — ADR 25 (e)'s "there is
## stock due soon and stock due later at any moment," the spread GDD §6.3's
## memory game depends on existing at all.
const MIN_STORE_OFFSET := 2
const MAX_STORE_OFFSET := 5

## A scripted row's own batch size, before any cap trims it down. Wide enough
## that a handful of rows can plausibly fill a day on their own; the caps
## below are what actually decide how much of that survives.
const MIN_ROW_COUNT := 2
const MAX_ROW_COUNT := 10

## Days at or under this lean toward single-size, low-fragility rows — a
## GENTLE tilt (this plan's own words), not a curve to be tuned: Phase 4 owns
## real difficulty, and anything elaborate here is thrown away the moment it
## lands.
const EARLY_DAY_THRESHOLD := 3
## How many different (category, size) rolls [method _author_row] tries
## before giving up and returning a trivially-legal fallback row rather than
## silently authoring nothing for a whole row slot.
const MAX_CATEGORY_ATTEMPTS := 6

## Manifest-only flavour — WHO a row is destined for. Phase 4 gives clients
## real personalities (GDD §6.6); this is a placeholder pool so
## [member CargoRecord.owner] is never blank on a scripted day.
const OWNER_POOL: Array[StringName] = [
	&"acme_traders", &"riverside_wholesale", &"kemp_and_sons", &"colinvale_imports",
]


## The one entry point. Locked rows are placed first and always consume the
## row budget ([constant ROWS_PER_DAY]) — the harsher, and correct, reading
## of ADR 25 (e): a redelivery added ON TOP of a full day's scripted content
## would cost nothing, and the entire lateness consequence would evaporate.
## Whatever does not fit is recorded on [member DayManifest.locked_rows_deferred]
## rather than silently dropped.
##
## Scripted rows are then authored freely (see [method _author_row] — no cap
## awareness at that point) and clamped against all three caps AFTERWARD, in
## [method _clamp_to_caps]. Clamping late rather than early is what makes the
## ceiling a hard guarantee rather than an approximation of one: an early-cap
## generator has to reason about every axis at once while still choosing
## content, and can plausibly under-fill one axis while still tripping
## another; a late clamp only ever has to ask "does the day I already built
## fit," which is a much smaller question to get right. Locked rows are never
## trimmed by this pass — they are a fixed obligation for the day, decided
## before any cap is even computed.
##
## [param seed_value] and [param day] together seed a fresh
## [RandomNumberGenerator] — never the global RNG, which is unseeded and
## would differ machine to machine — so the same three inputs plus the same
## [param crew_size] and the same cap overrides always produce a
## byte-identical manifest (`to_dict()` compared). That determinism is what
## makes a test repeatable and a bug reproducible; it is not what keeps two
## real peers agreeing — the host generating once and broadcasting the
## result is (see `day_clock.gd`'s own class doc for why both exist).
static func manifest_for(
		day: int,
		locked_rows: Array,
		seed_value: int,
		crew_size: int,
		body_cap_per_player := DEFAULT_BODY_CAP_PER_PLAYER,
		cell_equivalent_cap_per_player := DEFAULT_CELL_EQUIVALENT_CAP_PER_PLAYER,
		large_cap_per_player := DEFAULT_LARGE_CAP_PER_PLAYER,
		medium_cap_per_player := DEFAULT_MEDIUM_CAP_PER_PLAYER,
) -> DayManifest:
	var manifest := DayManifest.new()
	manifest.day = day

	var effective_crew := maxi(crew_size, 1)
	var body_cap := int(round(body_cap_per_player * effective_crew))
	var cell_cap := cell_equivalent_cap_per_player * float(effective_crew)
	var large_cap := int(round(large_cap_per_player * effective_crew))
	var medium_cap := int(round(medium_cap_per_player * effective_crew))

	var fit := mini(locked_rows.size(), ROWS_PER_DAY)
	manifest.locked_rows = (locked_rows.slice(0, fit) as Array).duplicate(true)
	manifest.locked_rows_deferred = (locked_rows.slice(fit, locked_rows.size()) as Array).duplicate(true)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, day])

	var scripted: Array = []
	var remaining_rows := ROWS_PER_DAY - manifest.locked_rows.size()
	for _i in remaining_rows:
		scripted.append(_author_row(rng, day))
	manifest.deliveries = scripted

	manifest.binding_cap = _clamp_to_caps(manifest, body_cap, cell_cap, large_cap, medium_cap)
	return manifest


## Cell-equivalents per single item of [param size] — ⅛ Small, 1 Medium, 2
## Large ([code]storage_grid.gd[/code]'s own `SMALLS_PER_CELL`, ADR 18).
static func _cell_equivalent_for_size(size: int) -> float:
	if size == CargoCatalogue.Size.LARGE:
		return 2.0
	if size == CargoCatalogue.Size.MEDIUM:
		return 1.0
	return 1.0 / float(StorageGrid.SMALLS_PER_CELL)


static func _row_body_count(rows: Array) -> int:
	var total := 0
	for row in rows:
		total += int((row as Dictionary).get("count", 0))
	return total


static func _row_cell_equivalents(rows: Array) -> float:
	var total := 0.0
	for row in rows:
		var r := row as Dictionary
		total += _cell_equivalent_for_size(int(r.get("size", 0))) * float(r.get("count", 0))
	return total


static func _row_size_count(rows: Array, size: int) -> int:
	var total := 0
	for row in rows:
		var r := row as Dictionary
		if int(r.get("size", -1)) == size:
			total += int(r.get("count", 0))
	return total


## One row, freely authored — no cap awareness; see [method manifest_for]'s
## own doc comment for why that is deliberate. Retries a handful of
## (category, size) picks under the early-day tilt before falling back to a
## trivially-legal row, so a run of bad luck on the RNG can never silently
## author nothing for a whole row slot.
static func _author_row(rng: RandomNumberGenerator, day: int) -> Dictionary:
	var categories := CargoCatalogue.categories()
	var early_day := day <= EARLY_DAY_THRESHOLD

	for _attempt in MAX_CATEGORY_ATTEMPTS:
		var category: StringName = categories[rng.randi_range(0, categories.size() - 1)]
		# Early days lean away from the most fragile categories — a GENTLE
		# tilt (70% skip chance, not a hard ban), matching this file's own
		# class doc on why nothing here is meant to be a tuned curve.
		if early_day and CargoCatalogue.fragility_for(category) >= 2 and rng.randf() < 0.7:
			continue

		var sizes := CargoCatalogue.available_sizes(category)
		if early_day:
			var filtered: Array[int] = []
			for available_size in sizes:
				if available_size == CargoCatalogue.Size.SMALL or rng.randf() < 0.4:
					filtered.append(available_size)
			if not filtered.is_empty():
				sizes = filtered

		var size: int = sizes[rng.randi_range(0, sizes.size() - 1)]
		var variants := CargoCatalogue.variants(category)
		var variant: StringName = variants[rng.randi_range(0, variants.size() - 1)]
		var count := rng.randi_range(MIN_ROW_COUNT, MAX_ROW_COUNT)
		var owner: StringName = OWNER_POOL[rng.randi_range(0, OWNER_POOL.size() - 1)]
		var store_until_day := day + rng.randi_range(MIN_STORE_OFFSET, MAX_STORE_OFFSET)

		return {
			"category": category,
			"variant": variant,
			"size": size,
			"count": count,
			"store_until_day": store_until_day,
			"owner": owner,
		}

	# Every attempt got filtered out by the early-day tilt — astronomically
	# unlikely (it needs several unlucky rolls in a row), but returning null
	# here would silently shrink the day for a reason nobody authored.
	# Falls back to the catalogue's own first category/variant/size instead.
	var fallback_category: StringName = categories[0]
	return {
		"category": fallback_category,
		"variant": CargoCatalogue.variants(fallback_category)[0],
		"size": CargoCatalogue.available_sizes(fallback_category)[0],
		"count": MIN_ROW_COUNT,
		"store_until_day": day + MIN_STORE_OFFSET,
		"owner": OWNER_POOL[0],
	}


## The late clamp — see [method manifest_for]'s own doc comment for why this
## runs after authoring rather than during it. Only ever trims
## [member DayManifest.deliveries]; locked rows are a fixed obligation and are
## never touched here (see this method's own doc comment above). Walks rows
## in the order they were authored, shrinking (never growing) a row's own
## `count` to whatever the tightest-binding remaining axis allows, dropping a
## row outright once it would allow zero. Returns the name of whichever axis
## bound FIRST, across the whole manifest — "" if nothing needed trimming —
## because "why is today small" needs a real answer, not just a smaller day.
static func _clamp_to_caps(manifest: DayManifest, body_cap: int, cell_cap: float, large_cap: int, medium_cap: int) -> String:
	var bodies := _row_body_count(manifest.locked_rows)
	var cells := _row_cell_equivalents(manifest.locked_rows)
	var larges := _row_size_count(manifest.locked_rows, CargoCatalogue.Size.LARGE)
	var mediums := _row_size_count(manifest.locked_rows, CargoCatalogue.Size.MEDIUM)

	var binding := ""
	var kept: Array = []
	for row in manifest.deliveries:
		var size := int((row as Dictionary).get("size", 0))
		var count := int((row as Dictionary).get("count", 0))
		var per_unit_cells := _cell_equivalent_for_size(size)

		var allowed := count
		var reason := ""

		var by_body := body_cap - bodies
		if by_body < allowed:
			allowed = by_body
			reason = "body"

		var by_cell := allowed
		if per_unit_cells > 0.0:
			by_cell = int(floor((cell_cap - cells) / per_unit_cells))
		if by_cell < allowed:
			allowed = by_cell
			reason = "cell_equivalent"

		if size == CargoCatalogue.Size.LARGE:
			var by_large := large_cap - larges
			if by_large < allowed:
				allowed = by_large
				reason = "large"
		elif size == CargoCatalogue.Size.MEDIUM:
			var by_medium := medium_cap - mediums
			if by_medium < allowed:
				allowed = by_medium
				reason = "medium"

		allowed = maxi(allowed, 0)
		if allowed < count and binding.is_empty():
			binding = reason
		if allowed <= 0:
			continue

		row["count"] = allowed
		kept.append(row)
		bodies += allowed
		cells += per_unit_cells * float(allowed)
		if size == CargoCatalogue.Size.LARGE:
			larges += allowed
		elif size == CargoCatalogue.Size.MEDIUM:
			mediums += allowed

	manifest.deliveries = kept
	return binding
