class_name CargoCatalogue
extends RefCounted

## The category/variant table ADR 25 (a)-(c) ratifies: roughly ten mechanical
## categories, each carrying a weight band, a fragility rating, a value
## density and a plaque label, with many comedy-only variants underneath
## each. This is what ADR 18 has been calling a "kind" all along — cell
## atomicity keys off [member category], not below it.
##
## [b]A plain static table, not [code].tres[/code] Resources.[/b] A custom
## [Resource] subclass is the idiomatic Godot answer, and
## [code]docs/project-structure.md[/code] reserves [code]resources/goods/[/code]
## for exactly this — but a [code].tres[/code] file needs both the editor's
## class cache and the importer before a headless test can load it, and this
## table is small and hand-authored, so that cost buys nothing today. Two of
## the three standing constraints in [code].planning/STATE.md[/code] (the
## class-cache rescan, the import pass) for zero benefit while it stays this
## size. Phase 6's art pass will want a real per-variant decal asset, and
## that is the natural moment to revisit this — the shape below is already
## Resource-compatible (one dictionary per category, matching what a
## [code].tres[/code]'s exported fields would hold), so that revisit is a
## port, not a redesign.
##
## Pure logic, deliberately, following [CargoCondition], [Dilemma] and
## [CargoRecord]'s own precedent: no nodes, no autoloads, no networking, so
## this loads and runs in a bare [code]--script[/code] test.
##
## All-static. Nothing here needs an instance; the table is looked up by
## category name, not by object identity.

## ADR 18's three size classes, fixed dimensions: Small is 0.5 m cubed (8 per
## cell), Medium is 1.0 m cubed (one cell), Large is 2.0 x 1.0 x 1.0 m (two
## cells). GDScript enums number from 0 in declaration order, and that
## ordering is depended on elsewhere (see [method CargoRecord.cells] and this
## test file's own SIZE_SMALL/SIZE_LARGE constants) — do not reorder these.
enum Size { SMALL, MEDIUM, LARGE }

## `density x cells x contract_days`, from `tools/economy-scenarios.js`'s own
## settlement figure — see [method declared_value]'s doc comment for the
## full reasoning and the recorded 30-day overflow finding.
const SETTLEMENT_MULTIPLIER := 1.35

## Lazily built and cached — see [method _table]. The table itself is
## hand-authored data, not derived from anything, so there is nothing to
## invalidate the cache for.
static var _table_cache: Dictionary = {}


# ------------------------------------------------------------- lookups

static func categories() -> Array[StringName]:
	var result: Array[StringName] = []
	for key in _table().keys():
		result.append(key)
	return result


## The row itself. Callers should prefer the narrower accessors below where
## one exists; this is the escape hatch for anything that isn't.
static func category_data(category: StringName) -> Dictionary:
	return _table().get(category, {})


static func available_sizes(category: StringName) -> Array[int]:
	var sizes: Dictionary = category_data(category).get("sizes", {})
	var result: Array[int] = []
	for size_key in sizes.keys():
		result.append(int(size_key))
	result.sort()
	return result


static func mass_for(category: StringName, size: int) -> float:
	var sizes: Dictionary = category_data(category).get("sizes", {})
	return float(sizes.get(size, 0.0))


static func fragility_for(category: StringName) -> int:
	return int(category_data(category).get("fragility", 0))


static func density_for(category: StringName) -> float:
	return float(category_data(category).get("density", 0.0))


static func plaque_label_for(category: StringName) -> String:
	return String(category_data(category).get("plaque", ""))


## ADR 25 (b): dodgy goods are a self-labelled category, not a system. This
## flag is the entire mechanic — there is no contraband detection anywhere
## else, deliberately.
static func is_dodgy(category: StringName) -> bool:
	return bool(category_data(category).get("dodgy", false))


static func variants(category: StringName) -> Array[StringName]:
	var row_variants: Dictionary = category_data(category).get("variants", {})
	var result: Array[StringName] = []
	for key in row_variants.keys():
		result.append(key)
	return result


static func variant_name(category: StringName, variant: StringName) -> String:
	var row_variants: Dictionary = category_data(category).get("variants", {})
	return String(row_variants.get(variant, ""))


## Greybox art per ADR 25 — one flat tint per category is what 02-04's crate
## scenes read to tell a mixed delivery apart at a glance. Hero models with
## real per-variant decals are an explicit Phase 6 deferral.
static func decal_tint(category: StringName) -> Color:
	return category_data(category).get("tint", Color.WHITE)


## Footprint cells: 1 for Small and Medium, 2 for Large. The one place this
## is defined — [method CargoRecord.cells] mirrors it with a raw int rather
## than calling here, to keep that file dependency-free (see its own doc
## comment), so if this ever changes, that copy needs updating too.
static func cells_for(size: int) -> int:
	return 2 if size == Size.LARGE else 1


## `density x cells x contract_days x SETTLEMENT_MULTIPLIER` — the settlement
## formula from `tools/economy-scenarios.js`, applied per crate rather than
## per invoice.
##
## [b]ADR 20's VALUE_REFERENCE (2000) is a real ceiling, not a style guide.[/b]
## Past it, [Dilemma]'s detection curve saturates and stops discriminating
## between an expensive crate and a very expensive one. A precious Large over
## a 10-day contract is `70 * 2 * 10 * 1.35 = £1890` — inside. Over 30 days it
## is `70 * 2 * 30 * 1.35 = £5670` — outside. ADR 25 ships 10-day-scale
## scripted days, so `cargo_taxonomy_test.gd` bounds its sweep at 10 days and
## this is recorded as a **Phase 4 finding** for the 30-day case, rather than
## "fixed" by lowering the densities below — that would unbalance the whole
## dilemma sweep against numbers ADR 20 already calibrated.
static func declared_value(category: StringName, size: int, contract_days: int) -> float:
	return density_for(category) * float(cells_for(size)) * float(contract_days) * SETTLEMENT_MULTIPLIER


## The one place a [CargoRecord] is built from a catalogue row, so nothing
## downstream assembles one by hand and forgets a field. 02-06's truck dump
## calls this.
static func mint(
	category: StringName,
	variant: StringName,
	size: int,
	store_until_day: int,
	owner: StringName,
	contract_days: int,
	crate_id: int,
) -> CargoRecord:
	var record := CargoRecord.new()
	record.id = crate_id
	record.category = category
	record.variant = variant
	record.size = size
	record.fragility = fragility_for(category)
	record.mass = mass_for(category, size)
	record.declared_value = declared_value(category, size, contract_days)
	record.store_until_day = store_until_day
	record.owner = owner
	return record


# ------------------------------------------------------------- the table

## Built once, on first use, and cached — not a `const`, because the row data
## nests nested `Dictionary`/`Color` literals keyed by `Size` enum values, and
## building it as an ordinary runtime statement sidesteps any question about
## how far GDScript's constant-folding reaches into nested structures. Since
## nothing here is ever mutated after being built, a static-var cache is as
## good as a constant would have been.
static func _table() -> Dictionary:
	if _table_cache.is_empty():
		_table_cache = _build_table()
	return _table_cache


## Roughly ten categories, chosen to cover every design property this
## plan's own test sweeps for — the reasoning behind each row, not just the
## numbers, so a future balance pass knows what it would be changing:
##
## - [b]masonry[/b] and [b]machine_parts[/b] carry the "heavy Small" half of
##   ADR 25 (c)'s deception (34 kg and 32 kg — both over Crate's 30 kg solo
##   limit), while [b]textiles[/b], [b]novelty[/b], [b]glassware[/b] and
##   [b]dodgy[/b] carry the light half (all comfortably under half that
##   limit) — proving weight is not correlated with size or, for glassware,
##   with fragility either.
## - Every category with a Large size sits under ~110 kg, the ceiling this
##   plan's context block derives from hold-spring sag at the current
##   [code]hold_stiffness[/code] (2400) — [b]machine_parts[/b] is the
##   heaviest at 108 kg, deliberately close to that ceiling rather than
##   nowhere near it.
## - [b]masonry[/b]'s Medium (68 kg) is solidly two-handed; [b]textiles[/b]',
##   [b]novelty[/b]'s and [b]dodgy[/b]'s Mediums are not — ADR 25 (c)'s
##   "weight decides, not size" needs both to exist.
## - [b]glassware[/b] (fragility 3, density 35) and [b]ceramics[/b]
##   (fragility 3, density 35) are the most fragile pair, deliberately NOT
##   also the most valuable; [b]electronics[/b] and [b]dodgy[/b] (density 70,
##   fragility 2) are the most valuable pair, deliberately not the most
##   fragile — breaking "expensive = fragile" is the whole point of ADR 25
##   (c) applied to the portfolio decision (GDD §6.1).
## - [b]white_goods[/b] has no Small at all — a category that is only ever
##   two-handed or dragged, never a quick solo grab.
## - [b]dodgy[/b] is ADR 25 (b)'s self-labelled category: no contraband
##   mechanic, just names that protest too much.
static func _build_table() -> Dictionary:
	var t := {}

	t[&"masonry"] = {
		"fragility": 0,
		"density": 8.0,
		"dodgy": false,
		"plaque": "MASONRY",
		"tint": Color(0.55, 0.35, 0.28),
		"sizes": {Size.SMALL: 34.0, Size.MEDIUM: 68.0, Size.LARGE: 104.0},
		"variants": {
			&"reclaimed_brick": "Reclaimed Victorian Brick",
			&"breeze_blocks": "Breeze Blocks",
			&"ornamental_gravel": "Ornamental Gravel",
		},
	}

	t[&"tinned"] = {
		"fragility": 0,
		"density": 12.0,
		"dodgy": false,
		"plaque": "TINNED GOODS",
		"tint": Color(0.65, 0.65, 0.7),
		"sizes": {Size.SMALL: 24.0, Size.MEDIUM: 52.0},
		"variants": {
			&"tinned_peaches": "Tinned Peaches",
			&"tinned_soup": "Tinned Soup (Assorted)",
			&"baked_beans": "Value Baked Beans",
		},
	}

	t[&"textiles"] = {
		"fragility": 1,
		"density": 18.0,
		"dodgy": false,
		"plaque": "TEXTILES",
		"tint": Color(0.75, 0.45, 0.55),
		"sizes": {Size.SMALL: 5.0, Size.MEDIUM: 17.0, Size.LARGE: 46.0},
		"variants": {
			&"bath_towels": "Bath Towels",
			&"novelty_bunting": "Novelty Bunting",
			&"job_lot_bedsheets": "Job Lot Bedsheets",
		},
	}

	t[&"powders"] = {
		"fragility": 1,
		"density": 18.0,
		"dodgy": false,
		"plaque": "POWDERS",
		"tint": Color(0.85, 0.8, 0.65),
		"sizes": {Size.SMALL: 20.0, Size.MEDIUM: 48.0, Size.LARGE: 92.0},
		"variants": {
			&"plaster_of_paris": "Plaster of Paris",
			&"self_raising_flour": "Self-Raising Flour",
			&"cement_mix": "Cement Mix",
		},
	}

	t[&"machine_parts"] = {
		"fragility": 1,
		"density": 18.0,
		"dodgy": false,
		"plaque": "MACHINE PARTS",
		"tint": Color(0.35, 0.4, 0.45),
		# 32, not 30, deliberately — level with Crate.SOLO_CARRY_MASS_LIMIT
		# would be ambiguous (the referee's own check is `mass >` the limit,
		# never `>=`); this has to read as genuinely over.
		"sizes": {Size.SMALL: 32.0, Size.MEDIUM: 64.0, Size.LARGE: 108.0},
		"variants": {
			&"assorted_cogs": "Assorted Cogs",
			&"reconditioned_pistons": "Reconditioned Pistons",
			&"spare_widgets": "Spare Widgets (Unlabelled)",
		},
	}

	t[&"ceramics"] = {
		"fragility": 3,
		"density": 35.0,
		"dodgy": false,
		"plaque": "CERAMICS",
		"tint": Color(0.9, 0.85, 0.8),
		"sizes": {Size.SMALL: 12.0, Size.MEDIUM: 38.0, Size.LARGE: 74.0},
		"variants": {
			&"porcelain_ducks": "Porcelain Ducks",
			&"porcelain_badgers": "Porcelain Badgers",
			&"commemorative_mugs": "Commemorative Mugs",
		},
	}

	t[&"glassware"] = {
		"fragility": 3,
		"density": 35.0,
		"dodgy": false,
		"plaque": "GLASSWARE",
		"tint": Color(0.6, 0.85, 0.85),
		"sizes": {Size.SMALL: 8.0, Size.MEDIUM: 30.0},
		"variants": {
			&"wine_glasses_nice": "Wine Glasses (Nice)",
			&"wine_glasses_hotel": "Wine Glasses (Hotel)",
			&"novelty_snowglobes": "Novelty Snowglobes",
		},
	}

	t[&"electronics"] = {
		"fragility": 2,
		"density": 70.0,
		"dodgy": false,
		"plaque": "ELECTRONICS",
		"tint": Color(0.2, 0.55, 0.35),
		"sizes": {Size.SMALL: 9.0, Size.MEDIUM: 32.0},
		"variants": {
			&"refurbished_laptops": "Refurbished Laptops",
			&"assorted_cables": "Assorted Cables",
			&"used_games_consoles": "Slightly Used Games Consoles",
		},
	}

	t[&"white_goods"] = {
		"fragility": 2,
		"density": 18.0,
		"dodgy": false,
		"plaque": "WHITE GOODS",
		"tint": Color(0.92, 0.92, 0.92),
		"sizes": {Size.MEDIUM: 55.0, Size.LARGE: 96.0},
		"variants": {
			&"tumble_dryers": "Tumble Dryers",
			&"mini_fridges": "Mini Fridges",
			&"dehumidifiers": "Dehumidifiers (Ex-Display)",
		},
	}

	t[&"novelty"] = {
		"fragility": 2,
		"density": 12.0,
		"dodgy": false,
		"plaque": "NOVELTY",
		"tint": Color(0.95, 0.55, 0.15),
		"sizes": {Size.SMALL: 6.0, Size.MEDIUM: 20.0, Size.LARGE: 48.0},
		"variants": {
			&"garden_gnomes": "Garden Gnomes",
			&"inflatable_flamingos": "Inflatable Flamingos",
			&"novelty_traffic_cones": "Novelty Traffic Cones",
		},
	}

	# ADR 25 (b): self-labelled, not a system. The misspelling in
	# "Definately Legal Tobacco" is DELIBERATE — it is the joke, and catching
	# it is not the point. Do not "fix" it.
	t[&"dodgy"] = {
		"fragility": 2,
		"density": 70.0,
		"dodgy": true,
		"plaque": "DODGY GOODS",
		"tint": Color(0.5, 0.15, 0.15),
		"sizes": {Size.SMALL: 7.0, Size.MEDIUM: 26.0},
		"variants": {
			&"baby_talcum_powder": "100% Baby Talcum Powder",
			&"legal_tobacco": "Definately Legal Tobacco",
			&"used_fivers": "Bundles of Used Fivers",
		},
	}

	return t
