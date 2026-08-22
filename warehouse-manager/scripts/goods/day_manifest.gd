class_name DayManifest
extends RefCounted

## One day's cargo (ADR 25 (e)/(f)): a batch of delivery rows the truck dumps,
## a batch of locked rows a missed collection owes, and the two pure functions
## that decide what is due out. Pure — no nodes, no `get_tree()`, no `Net` —
## following [CargoRecord]/[CargoCatalogue]'s own precedent, since this needs
## to load in a bare `--script` unit test and cross an `@rpc` unchanged
## (`day_clock.gd` broadcasts [method to_dict]'s output; clients never build
## their own manifest — ADR 21's "the host decides" applied to the day).
##
## [b]Phase 2 ships scripted days; Phase 4 replaces the author, not the
## contract.[/b] [DaySchedule] is what Phase 4's offer sheet swaps out — this
## file's own shape (a manifest is rows, rows are batches, collections are
## derived) is deliberately what both producers emit, so nothing downstream
## notices the swap.
##
## A [b]delivery row[/b] is a batch of identical crates —
## `{category, variant, size, count, store_until_day, owner}` — because that
## is how a truck actually arrives, and because it keeps a manifest readable
## as a list a human could post on a wall (GDD §5: "Manifest posted").
##
## A [b]locked row[/b] is the same shape, but it is not optional: ADR 25 (e)'s
## whole cost of a missed collection is that a redelivery is a locked row on
## tomorrow's manifest, spending the same [constant DaySchedule.ROWS_PER_DAY]
## budget a scripted row would have used. That is the entire Phase 2 cost of
## being late, and it needs no economy behind it — see [DaySchedule]'s own
## class doc for how a day is actually authored around that constraint.

## Absolute in-game day this manifest was authored for.
var day := 1
## Array[Dictionary] — scripted rows, [DaySchedule]'s own content.
var deliveries: Array = []
## Array[Dictionary] — rows that fit inside today's row budget, ahead of any
## scripted content ([method DaySchedule.manifest_for] fills these first).
var locked_rows: Array = []
## Array[Dictionary] — locked rows that did NOT fit [constant DaySchedule.ROWS_PER_DAY]
## once [member locked_rows] filled it. ADR 25 (e)'s own "owing more
## redeliveries than a day can hold" case, named explicitly here rather than
## silently dropped: whoever owns tomorrow's [DayClock._carried_locked_rows]
## (02-10) reads this to know what still has to carry again. Not itself part
## of any Phase 2 requirement's literal field list — added because "decide
## what happens [when locked rows exceed the budget] and assert it" (this
## plan's own unit-test instruction) has nowhere else to be observed from.
var locked_rows_deferred: Array = []
## Which cap trimmed [member deliveries] first ("body", "cell_equivalent",
## "large", "medium"), or "" if nothing needed trimming. [DaySchedule]'s own
## "clamp late, not early" rule makes a small day silent unless something
## records WHY it was small — this is that record.
var binding_cap := ""


## Wire-safe: every row is already primitives-only (see [DaySchedule]'s own
## row-building comment), so [code]Array.duplicate(true)[/code] is enough —
## no per-field reassembly the way [method CargoRecord.to_dict] needs, because
## a row has no class of its own to lose on the trip.
func to_dict() -> Dictionary:
	return {
		"day": day,
		"deliveries": (deliveries as Array).duplicate(true),
		"locked_rows": (locked_rows as Array).duplicate(true),
		"locked_rows_deferred": (locked_rows_deferred as Array).duplicate(true),
		"binding_cap": binding_cap,
	}


## Inverse of [method to_dict]. Reads every field with a default, matching
## [method CargoRecord.from_dict]'s own tolerance for a dictionary an older
## build wrote without a field a newer one added.
static func from_dict(data: Dictionary) -> DayManifest:
	var manifest := DayManifest.new()
	manifest.day = int(data.get("day", 1))
	manifest.deliveries = (data.get("deliveries", []) as Array).duplicate(true)
	manifest.locked_rows = (data.get("locked_rows", []) as Array).duplicate(true)
	manifest.locked_rows_deferred = (data.get("locked_rows_deferred", []) as Array).duplicate(true)
	manifest.binding_cap = String(data.get("binding_cap", ""))
	return manifest


## The sum of every row's count, locked and scripted alike — what
## `test_room.gd`'s truck dump actually spawns, and what the integration
## suite asserts the crate count rises by.
func total_crates() -> int:
	var total := 0
	for row in deliveries:
		total += int((row as Dictionary).get("count", 0))
	for row in locked_rows:
		total += int((row as Dictionary).get("count", 0))
	return total


## Locked rows first, then scripted — the order the truck actually dumps them
## in, and the order [DaySchedule] itself authors locked rows ahead of
## scripted ones (ADR 25 (e): a redelivery is owed before anything new is).
func all_rows() -> Array:
	return locked_rows + deliveries


## Collections are derived, not scripted (this plan's own objective): given
## every cargo record currently in the building ([method DayClock.census]'s
## own shape — an Array of wire-safe Dictionaries, whether the record came
## from a loose crate or a racked cell), return those due today or earlier.
## `<=`, not `==` — a crate missed yesterday is still due today rather than
## quietly falling off the list, which is what stops a missed collection from
## becoming forgotten stock.
static func due_today(records: Array, day: int) -> Array:
	var result: Array = []
	for record in records:
		if int((record as Dictionary).get("store_until_day", 0)) <= day:
			result.append(record)
	return result


## The strictly-late subset of [method due_today] — what a client is actually
## late for, and what 02-10's demurrage tally charges against (ADR 25 (e)).
## Deliberately the same boundary [method CargoRecord.is_overdue] already
## fixes (`current_day > store_until_day`) — restated here rather than
## reused, because this operates on the plain Dictionary shape
## [method DayClock.census] produces once per day, not on a live
## [CargoRecord] object per crate; the two must never quietly diverge, which
## is why both comments name the same rule rather than each inventing its own.
static func overdue(records: Array, day: int) -> Array:
	var result: Array = []
	for record in records:
		if int((record as Dictionary).get("store_until_day", 0)) < day:
			result.append(record)
	return result
