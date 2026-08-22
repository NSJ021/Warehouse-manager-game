class_name CargoRecord
extends RefCounted

## STORE-07's shape: every field a crate carries that must survive being
## racked and retrieved, in one place.
##
## A record is a [b]snapshot of one specific crate[/b], not a live lookup into
## [CargoCatalogue]. [member fragility], [member mass], [member size] and
## [member declared_value] are copied in at mint time rather than looked up
## from [member category] on demand, and that is deliberate rather than lazy:
## a record is what got sold, sitting in a rack, mid-run. If it looked its own
## numbers up live, retuning the catalogue mid-run would silently rewrite the
## value of stock already sold to a client — a save-compatibility bug before
## saves even exist, and an unfair one in play regardless. Phase 4 will also
## want per-contract value and per-crate variation that a live lookup could
## never express. So: copy in once, keep forever.
##
## Pure logic, deliberately, following [CargoCondition] and [Dilemma]'s own
## precedent: no nodes, no [code]get_tree()[/code], no [code]Net[/code] — a
## script with a [code]class_name[/code] that touches an autoload cannot be
## loaded in a bare [code]--script[/code] run at all, silently, and this one
## needs to be (`test/unit/cargo_taxonomy_test.gd`).
##
## [b]Wire-safe by construction.[/b] [method to_dict] only ever emits
## [code]int[/code], [code]float[/code], [code]String[/code],
## [code]StringName[/code] and [code]bool[/code] values — this dictionary
## travels through an [code]@rpc[/code] in 02-05, and a dictionary holding a
## [RefCounted] does not survive that trip.

## Never reused. -1 means unassigned, matching [member Crate.id]'s existing
## convention. Written by the level's minter.
var id := -1

## This is ADR 18's "kind" (finally defined, ADR 25 (a)): atomicity keys off
## it, unchanged. Written by [CargoCatalogue] at mint time.
var category := &""

## Comedy only — a manifest name and a crate decal, never a mechanic (ADR 25
## (a)). Written by [CargoCatalogue] at mint time.
var variant := &""

## [code]CargoCatalogue.Size[/code] (SMALL/MEDIUM/LARGE), stored as a plain
## int rather than typed against that enum so this file keeps zero
## dependencies of its own — see the class comment on why a record has to
## stand alone. Written by [CargoCatalogue] at mint time.
var size := 0

## 0–3 (GOODS-02). Denormalised from the category onto this specific crate —
## see the class comment for why. Written by [CargoCatalogue] at mint time.
var fragility := 0

## Kilograms. Denormalised from the category — see the class comment.
## Written by [CargoCatalogue] at mint time.
var mass := 0.0

## Pounds, stamped at delivery. Written by the day's manifest.
var declared_value := 0.0

## Absolute in-game day. A [b]contract[/b] property, not a kind property (ADR
## 25 (e)) — there is no independent spoilage timer, so this is a deadline,
## never a degradation clock. Written by the day's manifest.
var store_until_day := 0

## The client id this crate is destined for. Phase 4 gives it a personality;
## this record just carries it. Written by the day's manifest.
var owner := &""

## [code]CargoCondition.Tier[/code]. Inert until Phase 3 — see [method
## condition] / [method set_condition] for how a real [CargoCondition]
## round-trips through these two ints.
var condition_actual := CargoCondition.Tier.PRISTINE
## Diverges from [member condition_actual] once patched (GOODS-05) — the
## single most important thing not to lose on a round trip, since the gap
## between the two [i]is[/i] the tape-gun mechanic. Inert until Phase 3.
var condition_apparent := CargoCondition.Tier.PRISTINE

## Metres this crate has been hauled while dragged, accumulated host-side by
## [code]Crate._apply_drag_forces[/code]. Phase 3's scuff input — carrying it
## through a rack trip means racking cannot launder a crate's drag history.
var drag_distance := 0.0


## Wire-safe dictionary. See the class comment — every value is an
## [code]int[/code], [code]float[/code], [code]String[/code],
## [code]StringName[/code] or [code]bool[/code], nothing else.
func to_dict() -> Dictionary:
	return {
		"id": id,
		"category": category,
		"variant": variant,
		"size": size,
		"fragility": fragility,
		"mass": mass,
		"declared_value": declared_value,
		"store_until_day": store_until_day,
		"owner": owner,
		"condition_actual": condition_actual,
		"condition_apparent": condition_apparent,
		"drag_distance": drag_distance,
	}


## Inverse of [method to_dict]. Reads every field with [code]Dictionary.get[/code]
## and a default rather than indexing directly, so a dictionary written by an
## older build — missing a field a later one added — restores the rest rather
## than crashing. Cheap now, and impossible to retrofit once saves exist.
static func from_dict(data: Dictionary) -> CargoRecord:
	var record := CargoRecord.new()
	record.id = int(data.get("id", -1))
	record.category = StringName(data.get("category", &""))
	record.variant = StringName(data.get("variant", &""))
	record.size = int(data.get("size", 0))
	record.fragility = int(data.get("fragility", 0))
	record.mass = float(data.get("mass", 0.0))
	record.declared_value = float(data.get("declared_value", 0.0))
	record.store_until_day = int(data.get("store_until_day", 0))
	record.owner = StringName(data.get("owner", &""))
	record.condition_actual = int(data.get("condition_actual", CargoCondition.Tier.PRISTINE))
	record.condition_apparent = int(data.get("condition_apparent", CargoCondition.Tier.PRISTINE))
	record.drag_distance = float(data.get("drag_distance", 0.0))
	return record


## A deep copy. Every field here is a value type (int/float/String/StringName),
## so a plain field-for-field copy already cannot alias the original — but the
## method exists anyway, named and called explicitly, because 01-03's own
## precedent (`occupancy_snapshot` / `apply_occupancy_snapshot`) is that a
## rack's cell data is never handed out or taken in by reference. [Rack] will
## hold records in cell data; follow that precedent rather than re-reason it.
func duplicate_record() -> CargoRecord:
	var copy := CargoRecord.new()
	copy.id = id
	copy.category = category
	copy.variant = variant
	copy.size = size
	copy.fragility = fragility
	copy.mass = mass
	copy.declared_value = declared_value
	copy.store_until_day = store_until_day
	copy.owner = owner
	copy.condition_actual = condition_actual
	copy.condition_apparent = condition_apparent
	copy.drag_distance = drag_distance
	return copy


## Builds a real [CargoCondition] from this record's two ints. Phase 3 wires
## damage to this and finds it already flowing, the same way [member
## drag_distance] already is.
func condition() -> CargoCondition:
	var c := CargoCondition.new(condition_actual as CargoCondition.Tier)
	c.apparent = condition_apparent as CargoCondition.Tier
	return c


## Writes a [CargoCondition] back down onto this record's two ints.
func set_condition(c: CargoCondition) -> void:
	condition_actual = c.actual
	condition_apparent = c.apparent


## Footprint cells, for storage-fee and rack-occupancy purposes: 1 for Small
## and Medium, 2 for Large (2 == [code]CargoCatalogue.Size.LARGE[/code] — the
## raw int is used rather than the enum to keep this file dependency-free, see
## the class comment). One place, so nothing downstream re-derives it.
##
## Not the same axis as a fee-purposes fraction — a Small is 1/8 of a cell for
## billing (ADR 18), but a full cell for footprint purposes. This is the
## footprint number; ECON-04 owns the billing fraction.
func cells() -> int:
	return 2 if size == 2 else 1


## What a plaque shows for this crate's own line: the category, humanised
## (e.g. [code]&"white_goods"[/code] -> "White Goods"), never the variant — a
## cell is atomic by category (ADR 25 (a)), so that is what the plaque names.
## How many crates of that category share a cell is aggregated by the caller
## (02-08), since a single record only knows about itself.
func describe_short() -> String:
	var words := String(category).split("_")
	for i in words.size():
		if words[i].length() > 0:
			words[i] = words[i][0].to_upper() + words[i].substr(1)
	return " ".join(words)


## Whether this crate's collection window has passed (ADR 25 (e) — "you're
## late"). One place, so the plaque colour (02-08), the door-down check and
## the demurrage tally (02-09) all agree on what "past due" means.
func is_overdue(current_day: int) -> bool:
	return current_day > store_until_day
