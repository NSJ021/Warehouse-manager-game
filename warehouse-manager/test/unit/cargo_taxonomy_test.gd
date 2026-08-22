extends SceneTree

## Unit layer: STORE-07's round-trip crate record, and the ~10-category
## taxonomy ADR 25 ratifies (clauses (a)-(c)).
##
## Follows test/unit/storage_grid_test.gd's own precedent exactly: run once
## against a project with neither scripts/goods/cargo_record.gd nor
## scripts/goods/cargo_catalogue.gd, and watch it fail by NAMING the missing
## file rather than throwing a parse error about an unknown type - see the
## load() guards below, which is why this file loads those two with load()
## rather than a static class_name reference to either. CargoCondition and
## Dilemma already exist (built in Phase 1, no autoload dependency) and are
## referenced statically, exactly as test/unit/dilemma_maths.gd already does -
## only the two classes THIS plan introduces need the load()-and-name-the-gap
## treatment.
##
## Two kinds of check. Arithmetic - a category has a fragility, a mass, a
## plaque label. And design properties - the taxonomy actually contains the
## deception ADR 25 (c) promises (heavy Smalls, light fragiles, an
## always-drag Large, a sometimes-carryable Medium), and value stays inside
## Dilemma's own detection ceiling. The second half is the one a later
## balance tweak can break silently, so it is asserted directly rather than
## left to inspection - exactly dilemma_maths.gd's own "no dominant strategy"
## precedent, applied to a different pillar of the same design.
##
## Run via tools/run-tests.ps1. Exits 0 on pass, 1 on any failure.

const CARGO_RECORD_PATH := "res://scripts/goods/cargo_record.gd"
const CARGO_CATALOGUE_PATH := "res://scripts/goods/cargo_catalogue.gd"
const CRATE_SCRIPT_PATH := "res://scripts/goods/crate.gd"

## Contract span the value sweep is bounded to. ADR 25 ships 10-day-scale
## scripted days; a 30-day lease's higher-value cargo mix overflows Dilemma's
## VALUE_REFERENCE ceiling and is recorded as a Phase 4 finding rather than
## fixed here by lowering densities ADR 20 already calibrated - see
## CargoCatalogue.declared_value()'s own doc comment.
const MAX_SWEEP_CONTRACT_DAYS := 10

## CargoCatalogue.Size's fixed ordinals (ADR 18: exactly three size classes,
## GDScript enums number from 0 in declaration order). Used as plain ints
## here, the same way cargo_record.gd's own `cells()` does, rather than
## reaching into the loaded script's enum - see that method's doc comment.
const SIZE_SMALL := 0
const SIZE_MEDIUM := 1
const SIZE_LARGE := 2

const _WIRE_SAFE_TYPES := [TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME, TYPE_BOOL]

var _failures: Array[String] = []
var _checked := 0

var _record_script: GDScript
var _catalogue_script: GDScript


func _initialize() -> void:
	_record_script = load(CARGO_RECORD_PATH) as GDScript
	_catalogue_script = load(CARGO_CATALOGUE_PATH) as GDScript

	if _record_script == null:
		print("[unit] FAIL cargo_record.gd not found at %s - has it been written yet?" % CARGO_RECORD_PATH)
		_failures.append("cargo_record.gd not found")
	if _catalogue_script == null:
		print("[unit] FAIL cargo_catalogue.gd not found at %s - has the editor rescanned the class cache?" % CARGO_CATALOGUE_PATH)
		_failures.append("cargo_catalogue.gd not found")

	if _record_script != null:
		_check_round_trip()
	if _catalogue_script != null:
		_check_catalogue_arithmetic()
	if _record_script != null and _catalogue_script != null:
		_check_mint_uses_record()
		_check_design_properties()

	_report()


# ----------------------------------------------------- STORE-07 round trip

func _check_round_trip() -> void:
	print("[unit] STORE-07 - the round trip")

	var record = _record_script.new()
	record.id = 42
	record.category = &"glassware"
	record.variant = &"wine_glasses_hotel"
	record.size = SIZE_LARGE
	record.fragility = 3
	record.mass = 30.5
	record.declared_value = 472.5
	record.store_until_day = 7
	record.owner = &"the_ritz"
	record.drag_distance = 3.25

	var condition := CargoCondition.new(CargoCondition.Tier.DAMAGED)
	condition.apply_tape()
	record.set_condition(condition)
	_expect(
		record.condition_actual != record.condition_apparent,
		"the record under test really is mid-patch before it is even round-tripped",
	)

	var data: Dictionary = record.to_dict()
	_check_wire_safe(data, "a populated record")

	var restored = _record_script.from_dict(data)

	_expect(restored.id == record.id, "id survives (got %s, want %s)" % [restored.id, record.id])
	_expect(restored.category == record.category, "category survives (got %s, want %s)" % [restored.category, record.category])
	_expect(restored.variant == record.variant, "variant survives (got %s, want %s)" % [restored.variant, record.variant])
	_expect(restored.size == record.size, "size survives (got %s, want %s)" % [restored.size, record.size])
	_expect(restored.fragility == record.fragility, "fragility survives (got %s, want %s)" % [restored.fragility, record.fragility])
	_expect(is_equal_approx(restored.mass, record.mass), "mass survives (got %s, want %s)" % [restored.mass, record.mass])
	_expect(
		is_equal_approx(restored.declared_value, record.declared_value),
		"declared_value survives (got %s, want %s)" % [restored.declared_value, record.declared_value],
	)
	_expect(
		restored.store_until_day == record.store_until_day,
		"store_until_day survives (got %s, want %s)" % [restored.store_until_day, record.store_until_day],
	)
	_expect(restored.owner == record.owner, "owner survives (got %s, want %s)" % [restored.owner, record.owner])
	_expect(
		is_equal_approx(restored.drag_distance, record.drag_distance),
		"drag_distance survives (got %s, want %s)" % [restored.drag_distance, record.drag_distance],
	)
	_expect(
		restored.condition_actual == record.condition_actual,
		"condition_actual survives (got %s, want %s)" % [restored.condition_actual, record.condition_actual],
	)
	_expect(
		restored.condition_apparent == record.condition_apparent,
		"condition_apparent survives (got %s, want %s)" % [restored.condition_apparent, record.condition_apparent],
	)
	_expect(
		restored.condition_actual != restored.condition_apparent,
		"the round trip preserves the LIE itself, not just the two numbers separately - GOODS-05",
	)

	# A crate that has had nothing happen to it is not a special case.
	var blank = _record_script.new()
	var blank_data: Dictionary = blank.to_dict()
	_check_wire_safe(blank_data, "a default-constructed record")
	var blank_restored = _record_script.from_dict(blank_data)
	_expect(blank_restored.id == blank.id, "a default record's id survives (got %s)" % blank_restored.id)
	_expect(blank_restored.category == blank.category, "a default record's category survives (got %s)" % blank_restored.category)
	_expect(
		blank_restored.condition_actual == blank.condition_actual,
		"a default record's condition survives (got %s)" % blank_restored.condition_actual,
	)

	_expect(
		blank.to_dict().keys() == record.to_dict().keys(),
		"a default record and a fully-populated one emit the same field set",
	)


func _check_wire_safe(data: Dictionary, label: String) -> void:
	for key in data.keys():
		var value = data[key]
		_expect(
			typeof(value) in _WIRE_SAFE_TYPES,
			"%s: field '%s' is a wire-safe type (got %s)" % [label, key, type_string(typeof(value))],
		)


# ---------------------------------------------------- catalogue arithmetic

func _check_catalogue_arithmetic() -> void:
	print("[unit] the category table - arithmetic")

	var categories: Array = _catalogue_script.categories()
	_expect(categories.size() >= 8, "there are around ten categories (got %d)" % categories.size())

	for category in categories:
		var fragility: int = _catalogue_script.fragility_for(category)
		_expect(fragility >= 0 and fragility <= 3, "%s's fragility is 0..3 (got %d)" % [category, fragility])

		var sizes: Array = _catalogue_script.available_sizes(category)
		_expect(sizes.size() >= 1, "%s declares at least one available size" % category)
		for size in sizes:
			var mass: float = _catalogue_script.mass_for(category, size)
			_expect(mass > 0.0, "%s size %d has a positive mass (got %s)" % [category, size, mass])

		var plaque: String = _catalogue_script.plaque_label_for(category)
		_expect(not plaque.is_empty(), "%s has a non-empty plaque label" % category)

		var variants: Array = _catalogue_script.variants(category)
		_expect(variants.size() >= 3, "%s has at least three variants (got %d)" % [category, variants.size()])

		var seen_names: Dictionary = {}
		for variant in variants:
			var vname: String = _catalogue_script.variant_name(category, variant)
			_expect(not vname.is_empty(), "%s's variant %s has a display name" % [category, variant])
			_expect(
				not seen_names.has(vname),
				"%s's variant names are unique within the category (dupe: %s)" % [category, vname],
			)
			seen_names[vname] = true


# --------------------------------------------- catalogue mints a real record

func _check_mint_uses_record() -> void:
	print("[unit] CargoCatalogue.mint() builds a real CargoRecord")

	var categories: Array = _catalogue_script.categories()
	if categories.is_empty():
		_expect(false, "there is at least one category to mint from")
		return
	var category: StringName = categories[0]
	var variants: Array = _catalogue_script.variants(category)
	var variant: StringName = variants[0]
	var sizes: Array = _catalogue_script.available_sizes(category)
	var size: int = sizes[0]

	var minted = _catalogue_script.mint(category, variant, size, 5, &"test_client", 3, 99)
	_expect(minted.id == 99, "mint() stamps the crate id (got %s)" % minted.id)
	_expect(minted.category == category, "mint() stamps the category (got %s)" % minted.category)
	_expect(minted.variant == variant, "mint() stamps the variant (got %s)" % minted.variant)
	_expect(minted.size == size, "mint() stamps the size (got %s)" % minted.size)
	_expect(minted.store_until_day == 5, "mint() stamps the store-until day (got %s)" % minted.store_until_day)
	_expect(minted.owner == &"test_client", "mint() stamps the owner (got %s)" % minted.owner)
	_expect(
		is_equal_approx(minted.mass, _catalogue_script.mass_for(category, size)),
		"mint() looks up the category's mass for this size",
	)
	_expect(
		is_equal_approx(minted.declared_value, _catalogue_script.declared_value(category, size, 3)),
		"mint() computes declared_value the same way declared_value() would",
	)
	_expect(
		minted.condition_actual == CargoCondition.Tier.PRISTINE,
		"a freshly minted crate starts Pristine (got %s)" % minted.condition_actual,
	)
	_expect(
		minted.condition_actual == minted.condition_apparent,
		"a freshly minted crate starts honest - actual and apparent agree",
	)


# --------------------------------------------------------- design properties

func _check_design_properties() -> void:
	print("[unit] design properties - the half that catches a silent regression")

	var crate_script := load(CRATE_SCRIPT_PATH) as GDScript
	var crate_constants: Dictionary = crate_script.get_script_constant_map() if crate_script != null else {}
	var solo_limit := float(crate_constants.get("SOLO_CARRY_MASS_LIMIT", -1.0))
	_expect(solo_limit > 0.0, "Crate.SOLO_CARRY_MASS_LIMIT resolved from the real constant (got %s)" % solo_limit)

	var categories: Array = _catalogue_script.categories()

	_check_small_deception(categories, solo_limit)
	_check_large_always_heavy(categories, solo_limit)
	_check_medium_weight_decides(categories, solo_limit)
	_check_value_ceiling(categories)
	_check_dodgy_category(categories)
	_check_fragility_value_independence(categories)


## ADR 25 (c): deception exists both ways. At least two categories have a
## Small heavier than the solo-lift limit, and at least three have one under
## half of it. The spread is asserted, not any one category's number, so
## retuning a mass does not fail this - flattening the taxonomy does.
func _check_small_deception(categories: Array, solo_limit: float) -> void:
	var heavy_count := 0
	var light_count := 0
	var half_limit := solo_limit * 0.5
	for category in categories:
		var sizes: Array = _catalogue_script.available_sizes(category)
		if not (SIZE_SMALL in sizes):
			continue
		var mass: float = _catalogue_script.mass_for(category, SIZE_SMALL)
		if mass > solo_limit:
			heavy_count += 1
		if mass < half_limit:
			light_count += 1
	_expect(
		heavy_count >= 2,
		"at least two categories have a Small heavier than the solo-lift limit (got %d)" % heavy_count,
	)
	_expect(
		light_count >= 3,
		"at least three categories have a Small under half the solo-lift limit (got %d)" % light_count,
	)


## ADR 25 (c): "Every Large exceeds the solo-lift limit, always" - ADR 19's
## own revisit, finally checkable. Also the mass-cap trap from this plan's own
## context block: a Large has to stay under ~110 kg or the hold spring's sag
## (mass * gravity / stiffness, at stiffness 2400) stops reading as heavy and
## starts reading as broken.
func _check_large_always_heavy(categories: Array, solo_limit: float) -> void:
	var large_count := 0
	var all_heavy := true
	for category in categories:
		var sizes: Array = _catalogue_script.available_sizes(category)
		if not (SIZE_LARGE in sizes):
			continue
		large_count += 1
		var mass: float = _catalogue_script.mass_for(category, SIZE_LARGE)
		if mass <= solo_limit:
			all_heavy = false
		var sag := mass * 9.8 / 2400.0
		_expect(
			mass < 110.0,
			"%s's Large stays under ~110kg so hold-spring sag stays under ~0.5m (mass %s -> sag %.3fm)" % [category, mass, sag],
		)
	_expect(large_count > 0, "at least one category has a Large size to check")
	_expect(all_heavy, "every Large exceeds the solo-lift limit (ADR 19's revisit, ADR 25 (c))")


## ADR 25 (c): "a Medium is decided by weight, not by size." At least one
## Medium is solo-carryable and at least one is not - unlike Large, this is
## deliberately NOT uniform.
func _check_medium_weight_decides(categories: Array, solo_limit: float) -> void:
	var solo_ok := 0
	var solo_blocked := 0
	for category in categories:
		var sizes: Array = _catalogue_script.available_sizes(category)
		if not (SIZE_MEDIUM in sizes):
			continue
		var mass: float = _catalogue_script.mass_for(category, SIZE_MEDIUM)
		if mass > solo_limit:
			solo_blocked += 1
		else:
			solo_ok += 1
	_expect(solo_ok >= 1, "at least one Medium is solo-carryable - weight decides, not size (ADR 25 (c))")
	_expect(solo_blocked >= 1, "at least one Medium is not solo-carryable")


## ADR 20's VALUE_REFERENCE is a real ceiling, not a style guide: past it the
## detection curve's value term saturates and stops discriminating. Bounded at
## MAX_SWEEP_CONTRACT_DAYS (10) deliberately - see that constant's own comment
## for the recorded 30-day overflow finding.
func _check_value_ceiling(categories: Array) -> void:
	var value_reference: float = Dilemma.VALUE_REFERENCE
	for category in categories:
		for size in _catalogue_script.available_sizes(category):
			for days in range(1, MAX_SWEEP_CONTRACT_DAYS + 1):
				var value: float = _catalogue_script.declared_value(category, size, days)
				_expect(
					value > 0.0 and value <= value_reference,
					"%s size %d over %d days stays in (0, %s] (got %s)" % [category, size, days, value_reference, value],
				)


## ADR 25 (b): dodgy goods are a self-labelled category. The comedy of the
## names is not machine-checkable (and pretending otherwise would make a
## brittle test) - only that the flag exists and the category has variants.
func _check_dodgy_category(categories: Array) -> void:
	var dodgy_found := false
	for category in categories:
		if _catalogue_script.is_dodgy(category):
			dodgy_found = true
			var variants: Array = _catalogue_script.variants(category)
			_expect(variants.size() >= 3, "the dodgy category %s has variants of its own" % category)
	_expect(dodgy_found, "at least one category is flagged dodgy (ADR 25 (b))")


## Without this, "expensive = fragile" collapses the portfolio decision GDD
## §6.1 is built on into one variable.
func _check_fragility_value_independence(categories: Array) -> void:
	var max_fragility := -1
	var max_density := -1.0
	for category in categories:
		max_fragility = maxi(max_fragility, _catalogue_script.fragility_for(category))
		max_density = maxf(max_density, _catalogue_script.density_for(category))

	var most_fragile_is_most_valuable := false
	var high_value_low_fragility_found := false
	for category in categories:
		var fragility: int = _catalogue_script.fragility_for(category)
		var density: float = _catalogue_script.density_for(category)
		if fragility == max_fragility and is_equal_approx(density, max_density):
			most_fragile_is_most_valuable = true
		if is_equal_approx(density, max_density) and fragility < max_fragility:
			high_value_low_fragility_found = true

	_expect(not most_fragile_is_most_valuable, "the most fragile category is not also the most valuable")
	_expect(
		high_value_low_fragility_found,
		"at least one high-value category has lower fragility than the ceiling - breaks 'expensive = fragile'",
	)


# --------------------------------------------------------------- helpers

func _expect(condition: bool, label: String) -> void:
	_checked += 1
	if condition:
		print("[unit] ok   %s" % label)
		return
	_failures.append(label)
	print("[unit] FAIL %s" % label)


func _report() -> void:
	if _failures.is_empty():
		print("[unit] PASS - %d checks on the cargo taxonomy and round-trip record" % _checked)
		quit(0)
		return
	print("[unit] FAIL - %d of %d checks failed" % [_failures.size(), _checked])
	for failure in _failures:
		print("[unit]      %s" % failure)
	quit(1)
