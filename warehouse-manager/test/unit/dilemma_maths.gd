extends SceneTree

## Unit layer: the condition model and the dilemma maths.
##
## This layer sat empty and reserved until now, on the stated grounds that
## nothing in the project was pure enough to be worth it — the risk was all in
## networked physics, which unit tests are worst at. [CargoCondition] and
## [Dilemma] are the first things that genuinely are: no nodes, no autoloads, no
## networking, just numbers. So this is not a green-suite-for-its-own-sake layer;
## it is here because the pillar of the game is now arithmetic, and arithmetic is
## exactly what a unit test is for.
##
## Two kinds of check, and the second is the one that matters:
##
##   1. **Mechanics.** The tape gun moves apparent condition one tier, damage
##      drags apparent back down, detection is zero when honest, and every
##      weighting is monotonic in the direction it claims to be.
##
##   2. **The design property.** GDD §6.5 only works if there is no dominant
##      strategy — if the right answer changes with the situation. That is a
##      claim about the *shape* of the numbers, not about any one of them, and it
##      is the thing most likely to be quietly broken by a later balance tweak.
##      So it is asserted directly: sweep a grid of situations and require that
##      each of the three choices actually wins somewhere, and that the specific
##      flips the design promises are real.
##
## No GUT. The suite already has a working `--script` runner idiom and adding a
## framework to run pure arithmetic would be more moving parts than the tests.
##
## Run via tools/run-tests.ps1. Exits 0 on pass, 1 on any failure.

var _failures: Array[String] = []
var _checked := 0


func _initialize() -> void:
	_check_condition_mechanics()
	_check_detection_shape()
	_check_no_dominant_strategy()
	_check_promised_flips()
	_report()


# ------------------------------------------------------- condition

func _check_condition_mechanics() -> void:
	print("[unit] condition and the tape gun")

	var item := CargoCondition.new(CargoCondition.Tier.DAMAGED)
	_expect(item.actual == CargoCondition.Tier.DAMAGED, "damage starts where it was set")
	_expect(item.apparent == CargoCondition.Tier.DAMAGED, "apparent starts equal to actual")
	_expect(item.patch_depth() == 0, "an untaped item is telling the truth")
	_expect(item.is_honest(), "and reports itself honest")
	_expect(item.needs_a_decision(), "a damaged item forces the fork")

	_expect(item.apply_tape(), "tape applies to a damaged item")
	_expect(item.apparent == CargoCondition.Tier.SCUFFED, "one application hides exactly one tier")
	_expect(item.patch_depth() == 1, "and the lie is now one tier deep")
	_expect(not item.is_honest(), "a taped item is no longer honest")
	_expect(item.actual == CargoCondition.Tier.DAMAGED, "taping never repairs the real condition")

	_expect(item.apply_tape(), "tape applies again")
	_expect(item.apparent == CargoCondition.Tier.PRISTINE, "two applications reach Pristine")
	_expect(item.patch_depth() == 2, "hiding a two-tier lie")
	_expect(not item.apply_tape(), "there is nothing left to hide at Pristine")
	_expect(item.apparent == CargoCondition.Tier.PRISTINE, "and tape cannot go below it")

	# The rule that stops the tape gun being a permanent licence: fresh damage is
	# visible damage, so it drags the lie back into the open.
	item.worsen(1)
	_expect(item.actual == CargoCondition.Tier.DESTROYED, "damage on top of damage worsens it")
	_expect(
		item.apparent == CargoCondition.Tier.DESTROYED,
		"new damage drags apparent back down - a patch is not a licence to keep dropping it",
	)
	_expect(item.patch_depth() == 0, "so the lie is undone and has to be re-told")

	item.worsen(5)
	_expect(item.actual == CargoCondition.Tier.DESTROYED, "condition bottoms out at Destroyed")

	var fine := CargoCondition.new()
	_expect(not fine.needs_a_decision(), "a pristine item never reaches the fork")
	_expect(not fine.apply_tape(), "and there is nothing to tape")


# ------------------------------------------------------- detection

func _check_detection_shape() -> void:
	print("[unit] the detection roll")

	_expect(
		is_equal_approx(Dilemma.detection_chance(0, 500.0, 0.5), 0.0),
		"an honest handover cannot be 'detected' at all",
	)

	# Monotonic in all three inputs, each checked with the other two held still.
	# A balance tweak that accidentally inverts one of these would otherwise be
	# invisible until it made the game feel wrong for reasons nobody could name.
	var shallow := Dilemma.detection_chance(1, 500.0, 0.0)
	var mid := Dilemma.detection_chance(2, 500.0, 0.0)
	var deep := Dilemma.detection_chance(3, 500.0, 0.0)
	_expect(shallow < mid and mid < deep, "deeper lies are caught more often (%.2f < %.2f < %.2f)" % [shallow, mid, deep])
	_expect(
		deep - mid > mid - shallow,
		"and the curve accelerates, so deep lies are not merely a bit worse",
	)

	_expect(
		Dilemma.detection_chance(1, 2000.0, 0.0) > Dilemma.detection_chance(1, 10.0, 0.0),
		"expensive cargo gets looked at more closely",
	)
	_expect(
		Dilemma.detection_chance(1, 500.0, 1.0) > Dilemma.detection_chance(1, 500.0, 0.0),
		"a suspicious client catches more",
	)
	_expect(
		Dilemma.detection_chance(1, 500.0, 1.0) - Dilemma.detection_chance(1, 500.0, 0.0)
			> Dilemma.detection_chance(1, 2000.0, 0.0) - Dilemma.detection_chance(1, 0.0, 0.0),
		"suspicion outweighs value - it is the consequence that has to bite hardest",
	)

	var worst := Dilemma.detection_chance(3, 100000.0, 1.0)
	_expect(worst <= Dilemma.DETECTION_CEILING, "even the worst case leaves a sliver of luck (%.2f)" % worst)
	_expect(worst > 0.9, "but only a sliver (%.2f)" % worst)
	_expect(
		Dilemma.detection_chance(1, 0.0, 0.0) >= Dilemma.DETECTION_FLOOR,
		"and the safest lie is never a certainty either",
	)

	# Clamping, so an absurd item value cannot make detection certain on its own.
	_expect(
		is_equal_approx(
			Dilemma.detection_chance(1, Dilemma.VALUE_REFERENCE, 0.0),
			Dilemma.detection_chance(1, Dilemma.VALUE_REFERENCE * 50.0, 0.0),
		),
		"value scrutiny stops growing past the reference value",
	)

	# Getting caught over something precious costs more reputation.
	_expect(
		Dilemma.caught_rep_penalty(2000.0) < Dilemma.caught_rep_penalty(50.0),
		"being caught lying about valuable cargo hurts more (both negative)",
	)


# ----------------------------------------------- the design property

## The claim under test: there is no dominant strategy.
##
## Swept rather than spot-checked, because "patch is never the answer" is exactly
## the kind of breakage a well-meaning balance tweak introduces, and a handful of
## hand-picked cases would happily miss it.
func _check_no_dominant_strategy() -> void:
	print("[unit] no dominant strategy across the situation space")

	var wins := {Dilemma.Choice.PATCH: 0, Dilemma.Choice.CONFESS: 0, Dilemma.Choice.COMP: 0}
	var cases := 0

	for value in [50.0, 250.0, 800.0, 2000.0]:
		for depth in [1, 2, 3]:
			for suspicion in [0.0, 0.35, 0.7, 1.0]:
				for days in [0, 3, 10, 25]:
					# Like-for-like replacement: the honest comparison, since
					# comping with something cheaper is a different decision.
					var best: Dilemma.Choice = Dilemma.best_choice(value, depth, suspicion, days, value)
					wins[best] += 1
					cases += 1

	print("[unit]      (%d situations: patch %d, confess %d, comp %d)" % [
		cases, wins[Dilemma.Choice.PATCH], wins[Dilemma.Choice.CONFESS], wins[Dilemma.Choice.COMP],
	])

	_expect(wins[Dilemma.Choice.PATCH] > 0, "patching is the right call somewhere")
	_expect(wins[Dilemma.Choice.CONFESS] > 0, "confessing is the right call somewhere")
	_expect(wins[Dilemma.Choice.COMP] > 0, "comping is the right call somewhere")

	# None of them may be a near-universal answer either. A choice that wins 90%
	# of situations is a dominant strategy wearing a disguise.
	for choice in wins:
		var share := float(wins[choice]) / float(cases)
		_expect(
			share < 0.75,
			"choice %d wins %.0f%% of situations, which is not domination" % [choice, share * 100.0],
		)

	# The sweep above weights every situation equally, which play does not. Most
	# damage in a real session is a single scuff — a crate put down too hard —
	# so the one-tier slice is where the fork actually fires most often, and it
	# is the slice to watch when real balance data arrives. Checked separately
	# because a uniform sweep can look healthy while the common case is settled.
	var shallow := {Dilemma.Choice.PATCH: 0, Dilemma.Choice.CONFESS: 0, Dilemma.Choice.COMP: 0}
	var shallow_cases := 0
	for value in [50.0, 250.0, 800.0, 2000.0]:
		for suspicion in [0.0, 0.35, 0.7, 1.0]:
			for days in [0, 3, 10, 25]:
				shallow[Dilemma.best_choice(value, 1, suspicion, days, value)] += 1
				shallow_cases += 1

	print("[unit]      (%d one-tier situations: patch %d, confess %d, comp %d)" % [
		shallow_cases, shallow[Dilemma.Choice.PATCH],
		shallow[Dilemma.Choice.CONFESS], shallow[Dilemma.Choice.COMP],
	])
	for choice in shallow:
		_expect(
			shallow[choice] > 0,
			"choice %d is still live for ordinary one-tier damage" % choice,
		)


## The specific reversals the design promises. These are the ones a player should
## be able to feel, so they are named rather than left to the sweep.
func _check_promised_flips() -> void:
	print("[unit] the promised reversals")

	# 1. The lease clock. Same item, same damage, opposite answer.
	var late := Dilemma.best_choice(500.0, 1, 0.0, 0, 500.0)
	var early := Dilemma.best_choice(500.0, 1, 0.0, 25, 500.0)
	_expect(
		late == Dilemma.Choice.PATCH,
		"on the last day reputation is worthless, so a shallow patch is the play",
	)
	_expect(
		early != Dilemma.Choice.PATCH,
		"early in a long lease the same patch is the wrong call",
	)

	# 2. Suspicion is the ratchet that stops patch-everything being a strategy.
	var clean := Dilemma.patch_expected_value(500.0, 1, 0.0, 8)
	var burned := Dilemma.patch_expected_value(500.0, 1, 0.8, 8)
	_expect(burned < clean, "patching is worth less to a client you have already burned")
	_expect(
		Dilemma.best_choice(500.0, 1, 0.9, 8, 500.0) != Dilemma.Choice.PATCH,
		"and past a point, patching for them is simply off the table",
	)

	# 3. Depth. A shallow lie is a gamble; a deep one is not a plan.
	_expect(
		Dilemma.patch_expected_value(500.0, 1, 0.0, 5)
			> Dilemma.patch_expected_value(500.0, 3, 0.0, 5),
		"hiding three tiers is worth much less than hiding one",
	)
	_expect(
		Dilemma.best_choice(500.0, 3, 0.0, 5, 500.0) != Dilemma.Choice.PATCH,
		"passing a destroyed item off as pristine is never the *sensible* move",
	)

	# 4. ...but it must stay possible, because the desperate hail-mary is a story.
	#    Expected value says no; a player who needs the full fee tonight says yes.
	#    The gap between those two is the drama, so the payout has to still be there.
	var desperate := Dilemma.detection_chance(3, 500.0, 0.0)
	_expect(desperate < 1.0, "a three-tier lie can still come off (%.0f%% caught)" % (desperate * 100.0))
	_expect(
		Dilemma.confess_expected_value(500.0, 0) < 500.0,
		"and confessing genuinely cannot cover what patching pays, or there is no fork",
	)

	# 5. Confessing walks suspicion back down, which makes owning up on something
	#    cheap a real tactic rather than pure loss.
	_expect(Dilemma.CONFESS_SUSPICION < 0.0, "confessing reduces suspicion")
	_expect(
		absf(Dilemma.CONFESS_SUSPICION) < Dilemma.CAUGHT_SUSPICION,
		"but more slowly than getting caught raises it, so the ratchet still tightens",
	)

	# 6. Comping is the reputation play, and worthless once the lease is over.
	_expect(
		Dilemma.comp_expected_value(500.0, 500.0, 25) > Dilemma.comp_expected_value(500.0, 500.0, 0),
		"comping is worth far more early in a lease than late",
	)
	_expect(
		is_equal_approx(Dilemma.comp_expected_value(500.0, 500.0, 0), 0.0),
		"and on the final day a like-for-like comp is pure loss",
	)


# --------------------------------------------------------- helpers

func _expect(condition: bool, label: String) -> void:
	_checked += 1
	if condition:
		print("[unit] ok   %s" % label)
		return
	_failures.append(label)
	print("[unit] FAIL %s" % label)


func _report() -> void:
	if _failures.is_empty():
		print("[unit] PASS - %d checks on the condition and dilemma maths" % _checked)
		quit(0)
		return
	print("[unit] FAIL - %d of %d checks failed" % [_failures.size(), _checked])
	for failure in _failures:
		print("[unit]      %s" % failure)
	quit(1)
