class_name CargoCondition
extends RefCounted

## What state a piece of cargo is in, and what state it [i]looks[/i] like.
##
## The gap between those two is the game (GDD §6.5). Every item carries a real
## condition and an apparent one; they start equal, and the tape gun moves only
## the apparent one. Everything the dilemma does downstream is a consequence of
## how far apart they have been pushed.
##
## Pure logic, deliberately. No nodes, no autoloads, no networking — so it can be
## unit-tested in a bare `--script` run, and so the host can evaluate it without
## a scene. A script that touches an autoload cannot be loaded that way at all.
##
## Damage itself (drop height × fragility, collision velocity, rack collapse,
## spoilage) is Phase 3 and lives elsewhere. This is only the bookkeeping of what
## condition means and what a tape gun does to it.

## Ordered worst-ascending, so a plain integer comparison means what it reads
## like and the tier doubles as the number of tape applications needed to hide it.
enum Tier { PRISTINE = 0, SCUFFED = 1, DAMAGED = 2, DESTROYED = 3 }

const WORST := Tier.DESTROYED

## What each tier is called at handover, and in the log lines during testing.
const TIER_NAMES: Array[String] = ["Pristine", "Scuffed", "Damaged", "Destroyed"]

## What the item is really in. Only ever gets worse, and only Phase 3's damage
## sources move it.
var actual := Tier.PRISTINE
## What a customer sees. Raised — toward Pristine — one tier per tape application.
var apparent := Tier.PRISTINE


func _init(starting := Tier.PRISTINE) -> void:
	actual = starting
	apparent = starting


## Worsen the real condition, and drag the apparent one down with it.
##
## Apparent follows actual downward because fresh damage is visible damage: a
## patched box that gets dropped again looks dropped again. Without this you
## could tape an item once and then damage it freely behind the same lie, which
## makes the tape gun a permanent licence instead of a gamble.
func worsen(by := 1) -> void:
	if by <= 0:
		return
	actual = mini(actual + by, WORST) as Tier
	apparent = maxi(apparent, actual) as Tier


## Hide one tier of damage. Returns false if there was nothing left to hide.
##
## One tier per application is the whole rule (GDD §6.5) — a Destroyed item is
## three applications away from looking Pristine, and each one deepens the lie
## that [Dilemma] is going to price.
func apply_tape() -> bool:
	if apparent == Tier.PRISTINE:
		return false
	apparent = (apparent - 1) as Tier
	return true


## How many tiers of damage are currently being concealed. 0 is honest.
##
## This is the single number the detection roll runs on, which is why apparent is
## clamped never to be better than... nothing, actually: it is free to be better
## than actual, and that gap *is* the lie. It can never be worse than actual,
## because there is no way to make an item look more damaged than it is and no
## reason to want to.
func patch_depth() -> int:
	return maxi(actual - apparent, 0)


func is_honest() -> bool:
	return patch_depth() == 0


## True when this item is below Pristine and therefore forces the choice. An item
## that arrives undamaged never reaches the fork at all.
func needs_a_decision() -> bool:
	return actual != Tier.PRISTINE


func actual_name() -> String:
	return TIER_NAMES[actual]


func apparent_name() -> String:
	return TIER_NAMES[apparent]


func describe() -> String:
	if is_honest():
		return actual_name()
	return "%s (looks %s)" % [actual_name(), apparent_name()]
